package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.share.QrTransferDecompressionException
import com.mutx163.qingyu.share.QrTransferFrame
import com.mutx163.qingyu.share.QrTransferLimitException
import com.mutx163.qingyu.share.QrTransferLimits
import com.mutx163.qingyu.share.QrTransferSessionInfo
import com.mutx163.qingyu.share.camera.BarcodeScanResult
import com.mutx163.qingyu.share.qrTransferDecompress

/**
 * 二维码接收会话（Phase 3.5 · TQ1）——**纯 Kotlin、零 `android.*`**。
 *
 * 它补的是 B6 交付时自己写明的缺口：「扫码结果没有接业务……二维码分帧接收协议、会话匹配、
 * 校验和、进度更新都在 `QrTransferScanModel` 之上，本批没有它」。
 *
 * ## 一条识别结果的完整路径
 *
 * ```
 * QrScanSessionCoordinator.deliverDecoded  ← 权限/节流/去重三关（B5/B6，已交付）
 *   └─ onBarcode(BarcodeScanResult)
 *        ├─ QrTransferFrame.parse          ← 格式/上界校验（main/share，已交付）
 *        ├─ 会话匹配（首帧建会话，之后 info 必须逐字段相同）
 *        ├─ 会话时长 / 帧预算 / 唯一 seed / 邻接边预算（超了就是资源上限）
 *        ├─ 按 seed 去重                   ← 同一张画面被反复识别只算一次
 *        ├─ QrFountainPeelingDecoder.addSymbol（本轮新增：把符号还原成源符号）
 *        └─ 收齐 → 截断到 payloadLength → SHA-256 校验 → [verifiedPayload]
 *                                      └─ consumeRawPayload(): gzip 解压 + 原始长度核对
 * ```
 *
 * ## 为什么「解压」不放在 [onBarcode] 里
 *
 * 与 Dart 同口径：`submitFrame` 只做到「压缩载荷校验通过」，解压另开一个显式步骤。
 * 这样进度条能在收齐的瞬间就停在 100%，而不是卡在最后一步几毫秒（大备份解压可能几十毫秒），
 * 也让「收齐但解压失败」能落到一条**准确**的错误上，而不是笼统的「解码失败」。
 *
 * ## 错误到文案的映射（`QrTransferScanModel.Error` 每一条只对应一种原因）
 *
 * | 触发点 | Error |
 * |---|---|
 * | 已收齐但解出来的数据拿不出（`finish` 里 `decodedData()` 为 null、载荷短于声明） | `DECODE_FAILED` / `CHECKSUM_FAILED` |
 * | 超过 15 分钟会话上限 | `SESSION_EXPIRED` |
 * | 帧数 / 唯一 seed / 邻接边预算超限 | `RESOURCE_LIMIT` |
 * | SHA-256 不符 | `CHECKSUM_FAILED` |
 * | 解压后长度与声明不符 | `RAW_LENGTH_MISMATCH` |
 * | 载荷不是合法 gzip | `DECOMPRESSION_FAILED` |
 *
 * ## 哪些情况**不**判死（2026-11-05 修）
 *
 * | 触发点 | 处理 | 计数 |
 * |---|---|---|
 * | 扫到不是本协议的二维码 | 静默忽略 | [foreignFrameCount] |
 * | 本协议前缀但解析失败（反光/半截码被误读） | 静默忽略 | [brokenFrameCount] |
 * | 会话元信息不符（视野里另有一台发送端） | 静默忽略 | [mismatchedFrameCount] |
 *
 * 这三条以前都会落到一个**终态** `DECODE_FAILED` / `SESSION_MISMATCH`，此后
 * [onBarcode] 把所有后续结果全丢，用户必须点「重新开始」——已收到的帧一起作废。
 * 而现场（桌面、书本、包装、别人手机屏幕）到处是二维码，误扫一次就毁掉几分钟的收集。
 *
 * 发布版是**忽略**它们：`qr_transfer_scan_screen.dart:129-131` 对 `FormatException`
 * 直接 `continue`，`:132-140` 对 `qr_transfer_session_mismatch` 只显示一条提示并继续收，
 * 只有其它 StateError 才 `_stopWithError`。本文件现在与它同口径（Kotlin 侧把提示条换成
 * 计数，UI 若要显示「请对准发送方屏幕」再读计数即可，不必自己重新解析帧文本）。
 *
 * @param nowMillis 时钟（单测注入假时间，不睡觉）
 */
class QrTransferReceiveSession(
    private val nowMillis: () -> Long = { System.currentTimeMillis() },
) {

    private var startedAtMillis: Long = nowMillis()

    private var info: QrTransferSessionInfo? = null
    private var decoder: QrFountainPeelingDecoder? = null

    /** 属于本会话的识别次数（含重复帧）——UI 上的「已接收 N 帧」。 */
    private var detectedFrames = 0
    private var duplicateFrames = 0
    private var adjacencyEdges = 0
    private val submittedSeeds = HashSet<Int>()

    /** 看着就不是本协议的识别次数（别的二维码）——用来提示「请对准发送方屏幕」。 */
    private var foreignFrames = 0

    /** 是本协议前缀但解析失败的次数（反光/半张码被误读）——不判死，只计数。 */
    private var brokenFrames = 0

    /** 与本会话元信息不一致的帧数（视野里另有一台发送端）——不判死，只计数。 */
    private var mismatchedFrames = 0

    private var error: QrTransferScanModel.Error? = null

    /** 校验通过的压缩载荷（解压前）。 */
    private var verifiedPayload: ByteArray? = null

    /** 解压 + 长度核对后的原始字节。 */
    private var rawPayload: ByteArray? = null

    /** 会话元信息（收到第一帧后可用）。 */
    val sessionInfo: QrTransferSessionInfo? get() = info

    /** 压缩载荷是否已收齐并通过 SHA-256 校验。 */
    val isVerified: Boolean get() = verifiedPayload != null

    /** 解压后的原始字节；未收齐或解压失败时为 null。 */
    val rawData: ByteArray? get() = rawPayload

    /** 重复帧数（同一 seed 被反复识别）——调试与单测用。 */
    val duplicateCount: Int get() = duplicateFrames

    /** 不是本协议的二维码被扫到的次数（**不参与**进度、不判死）。 */
    val foreignFrameCount: Int get() = foreignFrames

    /** 本协议前缀但解析失败的次数（**不参与**进度、不判死）。 */
    val brokenFrameCount: Int get() = brokenFrames

    /** 与本会话元信息不符的帧数（**不参与**进度、不判死）。 */
    val mismatchedFrameCount: Int get() = mismatchedFrames

    /** 当前该渲染成什么。 */
    fun model(): QrTransferScanModel = QrTransferScanModel(
        receivedFrames = detectedFrames,
        decodedSymbols = decoder?.rank ?: 0,
        totalSymbols = info?.sourceSymbolCount ?: 0,
        error = error,
    )

    /**
     * 提交一条扫码识别结果。
     *
     * @param result B6 协调器放行后的结果（已过权限/节流/去重）；null 忽略
     * @return 最新的页面模型（调用方直接拿去重绘，不必再 [model]）
     */
    fun onBarcode(result: BarcodeScanResult?): QrTransferScanModel {
        if (result == null) return model()
        // 已经失败或已经收齐：后续结果一律不参与，免得把一条终态错误覆盖回「正常」。
        if (error != null || verifiedPayload != null) return model()

        val text = result.rawValue
        val frame = try {
            QrTransferFrame.parse(text)
        } catch (_: IllegalArgumentException) {
            // **不判死**：扫到不是本协议的码（桌面/书本/包装/别人手机屏幕上的 QR 到处都是）
            // 或本协议的帧没读清，都只是「这一条没用」，会话继续收下一帧。
            //
            // 发布版就是这个行为：`qr_transfer_scan_screen.dart:129-131` 把
            // `on FormatException` 直接 `continue`（静默忽略，不落任何终态）。
            // 早前 Kotlin 版把它塌成了 `DECODE_FAILED` 终态，一帧误扫就毁掉整轮收集。
            //
            // 两类分开计数，UI 可据此提示「请对准发送方屏幕」而不必自己再解析一遍文本。
            if (QrTransferFrame.looksLikeFrame(text)) brokenFrames++ else foreignFrames++
            return model()
        }

        // 会话先建立/校验：跨会话的帧即使 seed 相同也必须先报「不是同一份数据」。
        val current = info
        if (current == null) {
            info = frame.info
            decoder = QrFountainPeelingDecoder(
                sourceSymbolCount = frame.info.sourceSymbolCount,
                symbolSize = frame.info.symbolSize,
            )
        } else if (current != frame.info) {
            // 视野里同时有另一台发送端（或发送方中途换了数据）：**也不判死**，只记一笔。
            // 发布版 `qr_transfer_scan_screen.dart:132-140` 对 `qr_transfer_session_mismatch`
            // 只显示一条提示、继续收；真正终态的只有其它 StateError。
            mismatchedFrames++
            return model()
        }

        if (nowMillis() - startedAtMillis > QrTransferLimits.MAX_SESSION_DURATION_MILLIS) {
            fail(QrTransferScanModel.Error.SESSION_EXPIRED)
            return model()
        }

        val activeDecoder = decoder ?: run {
            fail(QrTransferScanModel.Error.DECODE_FAILED)
            return model()
        }

        if (detectedFrames >= QrTransferLimits.MAX_FRAME_COUNT) {
            fail(QrTransferScanModel.Error.RESOURCE_LIMIT)
            return model()
        }
        val isNewSeed = !submittedSeeds.contains(frame.seed)
        if (isNewSeed && submittedSeeds.size >= QrTransferLimits.MAX_UNIQUE_SEED_COUNT) {
            fail(QrTransferScanModel.Error.RESOURCE_LIMIT)
            return model()
        }
        val maxEdges = QrTransferLimits.maxAdjacencyEdgesForSourceSymbolCount(
            frame.info.sourceSymbolCount,
        )
        if (isNewSeed && frame.degree > maxEdges - adjacencyEdges) {
            fail(QrTransferScanModel.Error.RESOURCE_LIMIT)
            return model()
        }

        // 属于本会话的识别结果都计入 detected（含重复帧），UI 靠它显示「已接收 N 帧」。
        detectedFrames++

        if (!submittedSeeds.add(frame.seed)) {
            duplicateFrames++
            return model()
        }
        adjacencyEdges += frame.degree

        activeDecoder.addSymbol(frame.seed, frame.symbolBytes, frame.degree)
        if (activeDecoder.isComplete) finish()
        return model()
    }

    /**
     * 解压并核对原始长度，返回真正的业务字节。
     *
     * 只有 [isVerified] 之后才有意义；调用方应在页面「收齐」那一刻调一次。
     *
     * @return 原始字节；未收齐 / 解压失败 / 长度不符时 null（同时把 [model] 置成对应错误）
     */
    fun consumeRawPayload(): ByteArray? {
        rawPayload?.let { return it }
        val session = info
        val payload = verifiedPayload
        if (session == null || payload == null) return null
        try {
            val raw = qrTransferDecompress(payload, maxOutputBytes = session.rawLength)
            if (raw.size != session.rawLength) {
                fail(QrTransferScanModel.Error.RAW_LENGTH_MISMATCH)
                return null
            }
            rawPayload = raw
            return raw
        } catch (_: QrTransferLimitException) {
            fail(QrTransferScanModel.Error.RESOURCE_LIMIT)
            return null
        } catch (_: QrTransferDecompressionException) {
            fail(QrTransferScanModel.Error.DECOMPRESSION_FAILED)
            return null
        } catch (_: Exception) {
            fail(QrTransferScanModel.Error.DECOMPRESSION_FAILED)
            return null
        }
    }

    /** 重新开始：帧、会话、错误、计时全部清零（页面「重新开始」按钮）。 */
    fun reset() {
        info = null
        decoder = null
        detectedFrames = 0
        duplicateFrames = 0
        adjacencyEdges = 0
        submittedSeeds.clear()
        foreignFrames = 0
        brokenFrames = 0
        mismatchedFrames = 0
        error = null
        verifiedPayload = null
        rawPayload = null
        startedAtMillis = nowMillis()
    }

    /** 收齐 → 截断 → SHA-256。任一步不对就落到对应错误，绝不「收了一半也算完」。 */
    private fun finish() {
        val activeDecoder = decoder ?: return
        val session = info ?: return
        val data = activeDecoder.decodedData()
        if (data == null) {
            fail(QrTransferScanModel.Error.DECODE_FAILED)
            return
        }
        // 解出来的长度是 k×symbolSize（末块补了零），按声明长度截断才是真载荷。
        if (session.payloadLength > data.size) {
            fail(QrTransferScanModel.Error.CHECKSUM_FAILED)
            return
        }
        val payload = data.copyOf(session.payloadLength)
        if (QrTransferPayloadCodec.sha256Base64Url(payload) != session.payloadSha256) {
            fail(QrTransferScanModel.Error.CHECKSUM_FAILED)
            return
        }
        verifiedPayload = payload
    }

    private fun fail(reason: QrTransferScanModel.Error) {
        // 终态：第一条错误说了算。后面的帧可能带着别的原因，但用户只需要一个方向。
        if (error == null) error = reason
    }
}