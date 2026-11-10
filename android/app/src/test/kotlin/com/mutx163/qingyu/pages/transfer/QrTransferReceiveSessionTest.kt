package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.share.QrTransferFrame
import com.mutx163.qingyu.share.QrTransferLimits
import com.mutx163.qingyu.share.QrTransferSessionInfo
import com.mutx163.qingyu.share.camera.BarcodeScanResult
import java.security.MessageDigest
import java.util.Base64
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 接收会话的单测（Phase 3.5 · TQ1）。
 *
 * 每条错误都对着一句**不同**的话，所以这里逐条钉：扫到别人那份数据不能说成校验失败，
 * 校验失败不能说成解压失败，超时也不能说成超限——说错方向，用户就会重试错的东西。
 *
 * 期望值来源：
 * - 进度文案模板 `已接收 {received} 帧 · 已解出 {decoded}/{total}`（ARB 原文）；
 * - 帧文本格式 `QRV2|k|t|payloadLen|rawLen|sha|seed|degree|symbol`（[QrTransferFrame]）；
 * - SHA-256 摘要**在测试里用 `MessageDigest` 独立算一遍**，不复用被测代码的 helper。
 */
class QrTransferReceiveSessionTest {

    // ── 工具 ──────────────────────────────────────────────────────

    /** 一段压缩后大约 4KB 的不可压缩数据：k≈9，足够验证「重复帧不涨进度」。 */
    private fun randomPayload(): ByteArray = kotlin.random.Random(1234).nextBytes(4096)

    private fun infoFor(payload: ByteArray, symbolSize: Int, rawLength: Int): QrTransferSessionInfo {
        val digest = MessageDigest.getInstance("SHA-256").digest(payload)
        return QrTransferSessionInfo(
            sourceSymbolCount = (payload.size + symbolSize - 1) / symbolSize,
            symbolSize = symbolSize,
            payloadLength = payload.size,
            rawLength = rawLength,
            payloadSha256 = Base64.getUrlEncoder().encodeToString(digest),
        )
    }

    /** 用给定会话元信息与载荷造一串合法帧（不经过发送会话，便于构造异常场景）。 */
    private fun framesFor(info: QrTransferSessionInfo, payload: ByteArray, count: Int): List<String> {
        val encoder = QrFountainEncoder(
            sourceData = payload,
            symbolSize = info.symbolSize,
            sampler = QrFountainDegreeSampler(info.sourceSymbolCount),
        )
        return (1..count).map { seed ->
            val symbol = encoder.encode(seed)
            QrTransferFrame(info, symbol.seed, symbol.degree, symbol.bytes).encode()
        }
    }

    /** 改帧文本里某一列（列号见 [QrTransferFrame] 的格式注释）。 */
    private fun tamper(frameText: String, fieldIndex: Int, value: String): String {
        val fields = frameText.split(QrTransferFrame.FIELD_SEPARATOR).toMutableList()
        fields[fieldIndex] = value
        return fields.joinToString(QrTransferFrame.FIELD_SEPARATOR)
    }

    private fun barcode(text: String) = BarcodeScanResult(rawValue = text)

    /** 一直喂到「收齐」或「出错」为止。 */
    private fun feed(
        session: QrTransferReceiveSession,
        frameAt: (Int) -> String,
        maxTicks: Int = 400,
    ): QrTransferScanModel {
        var model = session.model()
        for (tick in 0 until maxTicks) {
            model = session.onBarcode(barcode(frameAt(tick)))
            if (model.error != null || model.isComplete) break
        }
        return model
    }

    // ── 正常路径 ──────────────────────────────────────────────────

    @Test
    fun 发送会话与接收会话端到端互通() {
        val raw = randomPayload()
        val sender = QrTransferSendSession.prepare(raw)
        val receiver = QrTransferReceiveSession()

        val model = feed(receiver, { tick -> sender.frameTextForTick(tick)!! })

        assertNull("正常收齐不该有任何错误", model.error)
        assertTrue("必须收齐", model.isComplete)
        val total = model.totalSymbols
        assertEquals("已解出数量必须等于源符号数", total, model.decodedSymbols)
        assertEquals(
            "进度文案模板必须逐字",
            "已接收 ${model.receivedFrames} 帧 · 已解出 $total/$total",
            model.progressText,
        )
        assertEquals(1f, model.progressFraction, 0.0001f)
        assertFalse("收齐后不该出现「重新开始」抢导入时序", model.showRestart)

        val decoded = receiver.consumeRawPayload()
        assertNotNull("收齐且校验通过后必须能拿到原始字节", decoded)
        assertTrue("原始字节必须逐字节等于发送端入参", raw.contentEquals(decoded))
    }

    @Test
    fun 首帧到达前不显示进度_用0做分母会被夹住() {
        val receiver = QrTransferReceiveSession()
        val model = receiver.model()
        assertNull("头帧还没到，0/0 只会让人困惑", model.progressText)
        assertEquals(0f, model.progressFraction, 0.0001f)
        assertTrue(model.isScanning)
    }

    @Test
    fun 同一帧反复识别只算重复_不涨解出数() {
        val sender = QrTransferSendSession.prepare(randomPayload())
        val receiver = QrTransferReceiveSession()
        val frame = sender.frameTextForTick(0)!!

        val first = receiver.onBarcode(barcode(frame))
        val afterFirst = first.decodedSymbols
        assertFalse("k 远大于 1，一帧不可能收齐", first.isComplete)

        val second = receiver.onBarcode(barcode(frame))
        assertEquals("两次识别都要计入「已接收 N 帧」", 2, second.receivedFrames)
        assertEquals("但重复帧不能带来新的解出符号", afterFirst, second.decodedSymbols)
        assertEquals(1, receiver.duplicateCount)
    }

    @Test
    fun 空识别结果被忽略() {
        val receiver = QrTransferReceiveSession()
        val model = receiver.onBarcode(null)
        assertNull(model.error)
        assertEquals(0, model.receivedFrames)
        assertNull(receiver.sessionInfo)
    }

    // ── 错误映射：一类错一句话 ────────────────────────────────────

    @Test
    fun 不是本协议的二维码静默忽略_不判死会话() {
        // 桌面/书本/包装/别人手机屏幕上到处是二维码：误扫一次不该毁掉整轮收集。
        // 发布版同口径（`qr_transfer_scan_screen.dart:129-131`：FormatException → continue）。
        val receiver = QrTransferReceiveSession()
        val model = receiver.onBarcode(barcode("这不是二维码传输的帧"))

        assertNull("非本协议文本不能置任何终态", model.error)
        assertEquals("不计入「已接收帧」", 0, model.receivedFrames)
        assertNull("更不能建会话", receiver.sessionInfo)
        assertEquals(1, receiver.foreignFrameCount)
        assertEquals(0, receiver.brokenFrameCount)

        // 会话仍然活着：紧接着的正确帧照收不误。
        val sender = QrTransferSendSession.prepare(randomPayload())
        val done = feed(receiver, { tick -> sender.frameTextForTick(tick)!! })
        assertNull(done.error)
        assertTrue("误扫之后必须还能收齐", done.isComplete)
        assertEquals(1, receiver.foreignFrameCount)
    }

    @Test
    fun 本协议前缀但帧坏也不判死_只计数() {
        val receiver = QrTransferReceiveSession()
        // `QRV2|` 开头但字段不全：是「本协议的帧没读清」，不是别人的码。
        val model = receiver.onBarcode(barcode("QRV2|1|256"))

        assertNull("帧坏同样不能置终态", model.error)
        assertEquals(0, model.receivedFrames)
        assertEquals(1, receiver.brokenFrameCount)
        assertEquals(0, receiver.foreignFrameCount)
        assertNull(receiver.sessionInfo)
    }

    @Test
    fun 扫到另一份数据只记不匹配_不判死会话() {
        val senderA = QrTransferSendSession.prepare(randomPayload())
        val senderB = QrTransferSendSession.prepare(kotlin.random.Random(99).nextBytes(3000))
        val receiver = QrTransferReceiveSession()

        receiver.onBarcode(barcode(senderA.frameTextForTick(0)!!))
        val model = receiver.onBarcode(barcode(senderB.frameTextForTick(0)!!))

        // 发布版只弹一条提示、继续收（`qr_transfer_scan_screen.dart:132-140`），当前会话不动。
        assertNull("另一份数据不能把会话打死", model.error)
        assertEquals(1, receiver.mismatchedFrameCount)
        assertEquals("会话元信息仍是第一份数据", 1, model.receivedFrames)

        // 回到发送端 A 的屏幕，能继续收齐（B 的帧只是被忽略）。
        val done = feed(receiver, { tick -> senderA.frameTextForTick(tick)!! })
        assertNull(done.error)
        assertTrue("被别的发送端干扰过也必须还能收齐", done.isComplete)
    }

    @Test
    fun 摘要对不上报校验失败() {
        val raw = randomPayload()
        val sender = QrTransferSendSession.prepare(raw)
        // 把每一帧的摘要列换成 32 个零的 base64 —— 长度合法（解析通过），内容必然不符。
        val zeros = Base64.getUrlEncoder().encodeToString(ByteArray(32))
        val receiver = QrTransferReceiveSession()

        val model = feed(receiver, { tick -> tamper(sender.frameTextForTick(tick)!!, 5, zeros) })

        assertEquals(QrTransferScanModel.Error.CHECKSUM_FAILED, model.error)
        assertEquals(TransferStrings.qrTransferChecksumFailed.zh, model.errorMessage)
        assertNull("校验失败不能给出原始字节", receiver.consumeRawPayload())
    }

    @Test
    fun 声明的原始长度与实际不符报长度校验失败() {
        val raw = randomPayload()
        val sender = QrTransferSendSession.prepare(raw)
        val declared = raw.size + 1 // 声明比真实多 1 字节
        val receiver = QrTransferReceiveSession()

        // 先把整个会话收齐（摘要仍然是对的），再解压 —— 长度不符要在解压那一步才暴露。
        val model = feed(receiver, { tick -> tamper(sender.frameTextForTick(tick)!!, 4, declared.toString()) })
        assertNull("收齐这一步本身不会出错", model.error)
        assertTrue(model.isComplete)

        assertNull("长度不符不能返回数据", receiver.consumeRawPayload())
        val afterDecode = receiver.model()
        assertEquals(QrTransferScanModel.Error.RAW_LENGTH_MISMATCH, afterDecode.error)
        assertEquals(TransferStrings.qrTransferRawLengthMismatch.zh, afterDecode.errorMessage)
    }

    @Test
    fun 载荷不是合法gzip报解压失败() {
        // 直接构造：载荷是 64 个不是 gzip 的字节（头两字节 0x01/0x08，不是 gzip 的 0x1f/0x8b），
        // 摘要按它算对 —— 于是「校验过、解压挂」。
        val payload = ByteArray(64) { (it * 7 + 1).toByte() }
        val info = infoFor(payload, symbolSize = 256, rawLength = 100)
        val frames = framesFor(info, payload, count = 4)
        val receiver = QrTransferReceiveSession()

        val model = feed(receiver, { tick -> frames[tick % frames.size] })
        assertTrue("k=1，一帧就收齐", model.isComplete)
        assertNull(receiver.model().error)

        assertNull("不是 gzip 就不能给数据", receiver.consumeRawPayload())
        assertEquals(
            QrTransferScanModel.Error.DECOMPRESSION_FAILED,
            receiver.model().error,
        )
        assertEquals(TransferStrings.qrTransferDecompressionFailed.zh, receiver.model().errorMessage)
    }

    @Test
    fun 超过15分钟会话上限报超时() {
        var now = 1_000_000L
        val receiver = QrTransferReceiveSession(nowMillis = { now })
        val sender = QrTransferSendSession.prepare(randomPayload())

        // 发布版从「第一帧建立起会话」才开始计时（_ensureCodec 里落 _sessionStartedAt）。
        receiver.onBarcode(barcode(sender.frameTextForTick(0)!!))
        now += QrTransferLimits.MAX_SESSION_DURATION_MILLIS + 1
        val model = receiver.onBarcode(barcode(sender.frameTextForTick(1)!!))

        assertEquals(QrTransferScanModel.Error.SESSION_EXPIRED, model.error)
        assertEquals(TransferStrings.qrTransferSessionExpired.zh, model.errorMessage)
    }

    @Test
    fun 首帧到达前不计时_打开页面很久后第一帧仍然有效() {
        // 页面打开后先发呆几十秒/几分钟（还没对准屏幕）不该烧掉 15 分钟额度；
        // 发布版 _sessionStartedAt 是在第一帧让 _ensureCodec 建解码器时写的。
        var now = 1_000_000L
        val receiver = QrTransferReceiveSession(nowMillis = { now })
        val sender = QrTransferSendSession.prepare(randomPayload())

        now += QrTransferLimits.MAX_SESSION_DURATION_MILLIS + 1
        val model = receiver.onBarcode(barcode(sender.frameTextForTick(0)!!))

        assertNull("第一帧到达前不计时，不能一上来就判超时", model.error)
        assertEquals(1, model.receivedFrames)
        assertNotNull(receiver.sessionInfo)
    }

    @Test
    fun 第一条终态错误说了算_后续帧不再改口() {
        // 终态只剩「真资源/真数据问题」这几类（超时、超限、校验失败…）——
        // 非本协议文本与坏帧已经改成忽略（见上面的用例），不再参与这条。
        var now = 1_000_000L
        val receiver = QrTransferReceiveSession(nowMillis = { now })
        val sender = QrTransferSendSession.prepare(randomPayload())

        receiver.onBarcode(barcode(sender.frameTextForTick(0)!!))
        now += QrTransferLimits.MAX_SESSION_DURATION_MILLIS + 1
        receiver.onBarcode(barcode(sender.frameTextForTick(1)!!))
        val model = receiver.onBarcode(barcode(sender.frameTextForTick(2)!!))

        assertEquals(
            "超时之后不该被后续帧「治好」",
            QrTransferScanModel.Error.SESSION_EXPIRED,
            model.error,
        )
    }

    // ── 重新开始 ──────────────────────────────────────────────────

    @Test
    fun 重新开始把帧与错误一起清掉() {
        var now = 1_000_000L
        val sender = QrTransferSendSession.prepare(randomPayload())
        val receiver = QrTransferReceiveSession(nowMillis = { now })
        receiver.onBarcode(barcode("别人的二维码"))
        receiver.onBarcode(barcode("QRV2|1|256"))
        // 外来码/坏帧不建立会话，也就不会起计时；先来一帧有效帧把会话建起来。
        receiver.onBarcode(barcode(sender.frameTextForTick(0)!!))
        now += QrTransferLimits.MAX_SESSION_DURATION_MILLIS + 1
        receiver.onBarcode(barcode(sender.frameTextForTick(1)!!))
        assertEquals(QrTransferScanModel.Error.SESSION_EXPIRED, receiver.model().error)

        receiver.reset()
        val model = receiver.model()
        assertNull("reset 后不能还挂着上一条错误", model.error)
        assertEquals(0, model.receivedFrames)
        assertEquals(0, model.decodedSymbols)
        assertEquals(0, model.totalSymbols)
        assertNull(receiver.sessionInfo)
        assertEquals("外来/坏帧的计数也要清掉", 0, receiver.foreignFrameCount)
        assertEquals(0, receiver.brokenFrameCount)
        assertEquals(0, receiver.mismatchedFrameCount)

        // reset 之后同一份数据能重新收：说明 seed 去重与会话状态都清干净了
        val fresh = feed(receiver, { tick -> sender.frameTextForTick(tick)!! })
        assertTrue(fresh.isComplete)
        assertNull(fresh.error)
    }

    @Test
    fun 重置后新会话可以换一份数据() {
        val first = QrTransferSendSession.prepare(randomPayload())
        val second = QrTransferSendSession.prepare(kotlin.random.Random(4321).nextBytes(2048))
        val receiver = QrTransferReceiveSession()
        receiver.onBarcode(barcode(first.frameTextForTick(0)!!))

        receiver.reset()
        val model = feed(receiver, { tick -> second.frameTextForTick(tick)!! })

        assertNull("reset 之后不该还记着上一份数据", model.error)
        assertTrue(model.isComplete)
        val raw = receiver.consumeRawPayload()
        assertNotNull(raw)
        assertEquals(second.rawLength, raw!!.size)
    }
}
