package com.mutx163.qingyu.share

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.util.Base64

/**
 * 二维码帧协议端口测试。
 * dart 源：lib/services/qr_transfer/qr_transfer_codec.dart（QrTransferFrame）；
 * 抄录用例：test/services/qr_transfer_codec_test.dart「帧文本可放入二维码且可解析」、
 * 「非法帧与跨会话帧被拒绝」、「恶意帧元数据与哈希字段被安全拒绝」。
 * 期望值按 Dart 判据人推（字段数 9、magic、上下界、sha256=32 字节、符号等长）。
 */
class QrTransferFrameTest {

    private fun sha256b64Of32Zeros(): String = Base64.getUrlEncoder().encodeToString(ByteArray(32))

    private fun validFrame(): QrTransferFrame = QrTransferFrame(
        info = QrTransferSessionInfo(
            sourceSymbolCount = 4,
            symbolSize = 8,
            payloadLength = 30,
            rawLength = 100,
            payloadSha256 = sha256b64Of32Zeros(),
        ),
        seed = 7,
        degree = 2,
        symbolBytes = ByteArray(8) { it.toByte() },
    )

    private fun replaceField(frameText: String, index: Int, value: String): String {
        val fields = frameText.split(QrTransferFrame.FIELD_SEPARATOR).toMutableList()
        fields[index] = value
        return fields.joinToString(QrTransferFrame.FIELD_SEPARATOR)
    }

    private fun assertInvalid(text: String) {
        try {
            QrTransferFrame.parse(text)
        } catch (e: IllegalArgumentException) {
            assertEquals(QrTransferFrame.INVALID_FRAME, e.message)
            return
        }
        fail("expected invalid frame: $text")
    }

    @Test fun `encode往返一致且字段齐全`() {
        val frame = validFrame()
        val text = frame.encode()
        val fields = text.split("|")
        assertEquals(9, fields.size)
        assertEquals("QRV2", fields[0])
        assertEquals("4", fields[1])
        assertEquals("8", fields[2])
        assertEquals("30", fields[3])
        assertEquals("100", fields[4])
        assertEquals(frame.info.payloadSha256, fields[5])
        assertEquals("7", fields[6])
        assertEquals("2", fields[7])

        val parsed = QrTransferFrame.parse(text)
        assertEquals(frame.info, parsed.info)
        assertEquals(7, parsed.seed)
        assertEquals(2, parsed.degree)
        assertArrayEquals(frame.symbolBytes, parsed.symbolBytes)
    }

    @Test fun `帧文本远小于QR版本40上限且首尾空白被容忍`() {
        val frame = validFrame()
        val text = frame.encode()
        assertTrue(text.length < 1500)
        // Dart 先 trim 再解析：首尾空白不算非法。
        val parsed = QrTransferFrame.parse("  \n$text\t ")
        assertEquals(frame.info, parsed.info)
    }

    @Test fun `非法帧被拒绝`() {
        assertInvalid("")
        assertInvalid("   ")
        assertInvalid("not a qr frame")
        assertInvalid("QRV2|bad|frame|0|0|x|0|1|")
        // 字段数不对。
        assertInvalid("QRV2|1|2|3|4|${sha256b64Of32Zeros()}|0|1")
        assertInvalid("QRV2|1|2|3|4|${sha256b64Of32Zeros()}|0|1|AA|extra")
        // magic 不对。
        assertInvalid("QRV3|4|8|30|100|${sha256b64Of32Zeros()}|7|2|AAAAAAAAAAA=")
    }

    @Test fun `非整数与零负元数据被拒绝`() {
        val text = validFrame().encode()
        assertInvalid(replaceField(text, 1, "abc"))
        assertInvalid(replaceField(text, 2, ""))
        assertInvalid(replaceField(text, 3, "1.5"))
        // k/t/payloadLen/rawLen 必须 > 0。
        assertInvalid(replaceField(text, 1, "0"))
        assertInvalid(replaceField(text, 2, "-1"))
        assertInvalid(replaceField(text, 3, "0"))
        assertInvalid(replaceField(text, 4, "0"))
        // seed < 0 或 > maxSeed；degree 必须 > 0。
        assertInvalid(replaceField(text, 6, "-1"))
        assertInvalid(replaceField(text, 6, "2147483648"))
        assertInvalid(replaceField(text, 7, "0"))
        assertInvalid(replaceField(text, 7, "-3"))
    }

    @Test fun `恶意上界被拒绝`() {
        val text = validFrame().encode()
        // k 超上限。
        assertInvalid(replaceField(text, 1, (QrTransferFrame.MAX_SOURCE_SYMBOL_COUNT + 1).toString()))
        // t 超上限。
        assertInvalid(replaceField(text, 2, (QrTransferFrame.MAX_SYMBOL_SIZE + 1).toString()))
        // payloadLen / rawLen 为 0（Dart 同一条用例覆盖）。
        assertInvalid(replaceField(text, 3, "0"))
        assertInvalid(replaceField(text, 4, "0"))
        // 哈希不是合法 base64url。
        assertInvalid(replaceField(text, 5, "bad-hash"))
        // 哈希长度不是 32 字节（16 字节的也拒）。
        assertInvalid(
            replaceField(text, 5, Base64.getUrlEncoder().encodeToString(ByteArray(16))),
        )
        // degree 超上限（101 > maxDegree=100，且 k=4 下 degree > k 也拒）。
        assertInvalid(replaceField(text, 7, (QrTransferLimits.MAX_DEGREE + 1).toString()))
        // 手工高 degree 帧：k=101,t=1 下 degree=101 虽 ≤k 但 > maxDegree。
        val highDegree = listOf(
            "QRV2", "101", "1", "101", "101",
            sha256b64Of32Zeros(), "0", "101",
            Base64.getUrlEncoder().encodeToString(byteArrayOf(0)),
        ).joinToString("|")
        assertInvalid(highDegree)
        // 超长文本（Dart：frame 重复 maxFrameTextLength 次必超限）。
        assertInvalid(text.repeat(QrTransferFrame.MAX_FRAME_TEXT_LENGTH))
    }

    @Test fun `payload超过k乘t被拒绝`() {
        // k=2,t=8 → 至多 16 字节载荷；报 17 非法。
        val forged = listOf(
            "QRV2", "2", "8", "17", "17",
            sha256b64Of32Zeros(), "0", "1",
            Base64.getUrlEncoder().encodeToString(ByteArray(8)),
        ).joinToString("|")
        assertInvalid(forged)
        // 恰好 16 合法。
        val ok = listOf(
            "QRV2", "2", "8", "16", "16",
            sha256b64Of32Zeros(), "0", "1",
            Base64.getUrlEncoder().encodeToString(ByteArray(8)),
        ).joinToString("|")
        assertEquals(2, QrTransferFrame.parse(ok).info.sourceSymbolCount)
    }

    @Test fun `符号长度必须与t一致`() {
        val text = validFrame().encode()
        // 符号给 7 字节而 t=8。
        assertInvalid(
            replaceField(text, 8, Base64.getUrlEncoder().encodeToString(ByteArray(7))),
        )
        // 符号不是 base64。
        assertInvalid(replaceField(text, 8, "!!!"))
    }

    // ── looksLikeFrame：只看前缀，不校验内容 ──────────────────────

    @Test fun `看起来是本协议帧_只认QRV2前缀`() {
        assertTrue(QrTransferFrame.looksLikeFrame(validFrame().encode()))
        assertTrue("前后空白要忽略", QrTransferFrame.looksLikeFrame("  \nQRV2|1|256|x  "))
        assertTrue("字段不全也算「像是本协议的帧」", QrTransferFrame.looksLikeFrame("QRV2|1|256"))
        assertFalse("没有分隔符不算", QrTransferFrame.looksLikeFrame("QRV2"))
        assertFalse("别的前缀不算", QrTransferFrame.looksLikeFrame("QRV2X|1|2|3|4|5|6|7|8"))
        assertFalse("普通网址不算", QrTransferFrame.looksLikeFrame("https://example.com"))
        assertFalse("空串不算", QrTransferFrame.looksLikeFrame("   "))
        assertFalse("魔数固定大写", QrTransferFrame.looksLikeFrame("qrv2|1|2"))
    }
}
