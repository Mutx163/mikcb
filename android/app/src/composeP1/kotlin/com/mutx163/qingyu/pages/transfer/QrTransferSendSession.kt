package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.share.QrTransferCapacity
import com.mutx163.qingyu.share.QrTransferFrame
import com.mutx163.qingyu.share.QrTransferLimitException
import com.mutx163.qingyu.share.QrTransferLimits
import com.mutx163.qingyu.share.QrTransferSessionInfo
import java.io.ByteArrayOutputStream
import java.security.MessageDigest
import java.util.Base64
import java.util.zip.GZIPOutputStream

/**
 * 二维码传输的载荷编解码小件（gzip + SHA-256 摘要）。
 *
 * 发送端与接收端都要用同一套口径：**摘要算在 gzip 之后的载荷上**（Dart
 * `base64Url.encode(sha256.convert(compressedPayload).bytes)`），不是算在原始字节上。
 * 写成一处，免得两端各写一遍然后悄悄对不上。
 */
internal object QrTransferPayloadCodec {

    /** gzip 压缩（Dart `gzip.encode` 的 Kotlin 等价物：`GZIPOutputStream`）。 */
    fun gzipCompress(raw: ByteArray): ByteArray {
        val out = ByteArrayOutputStream(raw.size / 2 + 64)
        GZIPOutputStream(out).use { gzip -> gzip.write(raw) }
        return out.toByteArray()
    }

    /** SHA-256 → base64url（含 `=` 补位，与 Dart `base64Url.encode` 同口径）。 */
    fun sha256Base64Url(bytes: ByteArray): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(bytes)
        return Base64.getUrlEncoder().encodeToString(digest)
    }
}

/**
 * 二维码发送会话（Phase 3.5 · TQ1）——**纯 Kotlin、零 `android.*`**。
 *
 * 对应 Dart `lib/services/qr_transfer/qr_transfer_codec.dart` 的 `QrTransferEncoder.prepare`：
 * 原始字节 → gzip → 按 [QrTransferLimits.pickSymbolSize] 切块 → 资源预算 → 会话元信息 → LT 编码器。
 *
 * ## 它回答发送页要的三个问题
 *
 * 1. **这一拍该显示哪一帧**：[seedAt] / [frameTextForTick]，按 `elapsedMillis / frameIntervalMillis`
 *    算「第几拍」，再由拍号推出 seed；
 * 2. **进度文案要什么数**：[modelAt] 直接给出 `QrTransferSendModel`（已发送帧数 / 约需帧数 / 是否超时）；
 * 3. **能不能发**：[overResourceLimit]（超预算时整页换成上限提示，不再轮播）。
 *
 * ## 为什么「一轮」= `estimatedFrameCount`
 *
 * 接收端要凑够 `k` 个源符号，纯削皮需要约 `1.2k` 帧（`planTransfer` 的估算就是 `(k*12+9)/10`）。
 * 所以一轮正好播 «估算帧数» 那么多帧：**一轮下来大概率够**，不够就自动进第二轮
 * （第二轮用全新 seed，不是重播第一轮——重播相同 seed 对削皮毫无贡献，接收端会当重复帧丢掉）。
 *
 * seed 上限由 [QrTransferLimits.MAX_UNIQUE_SEED_COUNT] 卡住；跑满之后回到第一轮重播
 * （那时还没收到，说明对方根本没对准屏幕，重播至少还能让它「对上」）。
 */
class QrTransferSendSession private constructor(
    /** 原始字节数；0 表示没有数据可发（空载荷 / 压缩失败）。 */
    val rawLength: Int,
    /** 会话元信息；null = 没有可播的帧。 */
    val info: QrTransferSessionInfo?,
    /** 容量预算；null = 没算出来。 */
    val capacity: QrTransferCapacity?,
    /** 是否触发资源上限（页面此时只显示上限提示）。 */
    val overResourceLimit: Boolean,
    private val encoder: QrFountainEncoder?,
) {

    /** 轮播间隔（毫秒）：由底层常量决定，不在页面里另定一个数。 */
    val frameIntervalMillis: Long get() = QrTransferLimits.FRAME_INTERVAL_MILLIS

    /** 一轮播多少帧（= 估算帧数，至少 1）。 */
    val cycleLength: Int = capacity?.estimatedFrameCount?.coerceAtLeast(1) ?: 1

    /** 是否真的有帧可播。 */
    val hasFrames: Boolean get() = info != null && encoder != null

    /**
     * 第 [tickIndex] 拍用哪个 seed（从 0 起算，单调递增）。
     *
     * 映射：`slot = tick % 一轮帧数`，`pass = (tick / 一轮帧数) % 允许轮数`，
     * `seed = slot + 1 + pass * 一轮帧数`。
     * seed 从 1 起（seed 0 留给「头帧」语义之外的空闲位，与 Dart 发送端一致）。
     */
    fun seedAt(tickIndex: Int): Int {
        if (tickIndex <= 0) return FIRST_SEED
        val perCycle = cycleLength
        val maxPasses = (QrTransferLimits.MAX_UNIQUE_SEED_COUNT / perCycle).coerceAtLeast(1)
        val slot = tickIndex % perCycle
        val pass = (tickIndex / perCycle) % maxPasses
        return slot + FIRST_SEED + pass * perCycle
    }

    /** 指定 seed 的帧文本；没有可播内容时 null。 */
    fun frameTextAt(seed: Int): String? {
        val session = info ?: return null
        val codec = encoder ?: return null
        val symbol = codec.encode(seed)
        return QrTransferFrame(
            info = session,
            seed = symbol.seed,
            degree = symbol.degree,
            symbolBytes = symbol.bytes,
        ).encode()
    }

    /**
     * 第 [tickIndex] 拍的帧文本（带一个极小的缓存）。
     *
     * 为什么要缓存：`QrEncoder` 只吃文本，而合成文本要跑一次 LT 编码
     * （最多 k 次 4KB 的 XOR）。播放是顺序的，缓存最近几拍就够，
     * 用不着把几千帧全预生成在内存里。
     */
    fun frameTextForTick(tickIndex: Int): String? {
        val seed = seedAt(tickIndex)
        tickCache[seed]?.let { return it }
        val text = frameTextAt(seed) ?: return null
        if (tickCache.size >= TICK_CACHE_SIZE) {
            val eldest = tickCache.keys.firstOrNull()
            if (eldest != null) tickCache.remove(eldest)
        }
        tickCache[seed] = text
        return text
    }

    /**
     * 按已用时间给出发送页模型。
     *
     * @param elapsedMillis 会话开始至今的毫秒数（由宿主时钟提供，单测传假时间）
     */
    fun modelAt(elapsedMillis: Long): QrTransferSendModel {
        val elapsed = elapsedMillis.coerceAtLeast(0L)
        if (overResourceLimit) {
            // 超限时 totalFrames 必须给 0：否则页面会同时画出「约需 N 帧」和上限提示，自相矛盾。
            return QrTransferSendModel(elapsedMillis = elapsed, overResourceLimit = true)
        }
        val sent = (elapsed / frameIntervalMillis).coerceAtMost(Int.MAX_VALUE.toLong()).toInt()
        return QrTransferSendModel(
            sentFrames = sent,
            // 没有可播的帧时 totalFrames 必须是 0：否则页面会显示「约需 1 帧」而实际一帧都发不出。
            totalFrames = if (hasFrames) cycleLength else 0,
            elapsedMillis = elapsed,
            expired = elapsed >= QrTransferLimits.MAX_SESSION_DURATION_MILLIS,
        )
    }

    private val tickCache = object : LinkedHashMap<Int, String>(TICK_CACHE_SIZE, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<Int, String>?): Boolean =
            size > TICK_CACHE_SIZE
    }

    companion object {
        /** seed 从 1 起（与 Dart 发送端 `_seed = 0; nextFrame() → 1` 一致）。 */
        const val FIRST_SEED = 1

        private const val TICK_CACHE_SIZE = 4

        /**
         * 准备一次发送。
         *
         * @param rawBytes 要发出去的原始数据（备份 JSON 等）
         */
        fun prepare(rawBytes: ByteArray): QrTransferSendSession {
            if (rawBytes.isEmpty()) {
                return QrTransferSendSession(0, null, null, overResourceLimit = false, encoder = null)
            }
            val compressed = try {
                QrTransferPayloadCodec.gzipCompress(rawBytes)
            } catch (_: Exception) {
                // 压缩失败不该表现为「超限」——它跟数据大小无关。当「没东西可发」处理，
                // 页面照常显示提示行，不会给用户一句误导的上限文案。
                return QrTransferSendSession(0, null, null, overResourceLimit = false, encoder = null)
            }
            val capacity = try {
                QrTransferLimits.planTransfer(compressed.size, rawBytes.size)
            } catch (_: QrTransferLimitException) {
                return QrTransferSendSession(
                    rawLength = rawBytes.size,
                    info = null,
                    capacity = null,
                    overResourceLimit = true,
                    encoder = null,
                )
            }
            val symbolSize = QrTransferLimits.pickSymbolSize(compressed.size)
            val info = QrTransferSessionInfo(
                sourceSymbolCount = capacity.sourceSymbolCount,
                symbolSize = symbolSize,
                payloadLength = compressed.size,
                rawLength = rawBytes.size,
                payloadSha256 = QrTransferPayloadCodec.sha256Base64Url(compressed),
            )
            val encoder = QrFountainEncoder(
                sourceData = compressed,
                symbolSize = symbolSize,
                sampler = QrFountainDegreeSampler(capacity.sourceSymbolCount),
            )
            return QrTransferSendSession(
                rawLength = rawBytes.size,
                info = info,
                capacity = capacity,
                overResourceLimit = false,
                encoder = encoder,
            )
        }
    }
}
