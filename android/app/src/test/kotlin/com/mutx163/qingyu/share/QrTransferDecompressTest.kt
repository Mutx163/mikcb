package com.mutx163.qingyu.share

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.fail
import org.junit.Test
import java.io.ByteArrayOutputStream
import java.util.zip.GZIPOutputStream

/**
 * 有界 gzip 还原端口测试。
 * dart 源：qr_transfer_codec.dart（qrTransferDecompress）；
 * 抄录 test/services/qr_transfer_codec_test.dart「gzip 输出硬上限阻止高压缩比
 * payload 扩张」。期望值人推：256KB 零字节 gzip 体在 1024 预算下拒、足预算下还原。
 */
class QrTransferDecompressTest {

    private fun gzip(raw: ByteArray): ByteArray {
        val out = ByteArrayOutputStream()
        GZIPOutputStream(out).use { it.write(raw) }
        return out.toByteArray()
    }

    @Test fun `足预算还原一致`() {
        val raw = ByteArray(256 * 1024) // 全零，高压缩比。
        val compressed = gzip(raw)
        assertArrayEquals(raw, qrTransferDecompress(compressed, maxOutputBytes = raw.size))
    }

    @Test fun `预算不足拒收并报码`() {
        val raw = ByteArray(256 * 1024)
        val compressed = gzip(raw)
        try {
            qrTransferDecompress(compressed, maxOutputBytes = 1024)
            fail("expected limit")
        } catch (e: QrTransferLimitException) {
            assertEquals("qr_transfer_decompression_output_too_large", e.code)
            assertEquals(1024, e.limit)
        }
    }

    @Test fun `压缩体超限先拒`() {
        val oversized = ByteArray(QrTransferLimits.MAX_COMPRESSED_PAYLOAD_BYTES + 1)
        try {
            qrTransferDecompress(oversized, maxOutputBytes = QrTransferLimits.MAX_RAW_PAYLOAD_BYTES)
            fail("expected limit")
        } catch (e: QrTransferLimitException) {
            assertEquals("qr_transfer_compressed_payload_too_large", e.code)
        }
    }

    @Test fun `非法预算被拒`() {
        val compressed = gzip("hello".toByteArray())
        for (bad in listOf(0, -5, QrTransferLimits.MAX_RAW_PAYLOAD_BYTES + 1)) {
            try {
                qrTransferDecompress(compressed, maxOutputBytes = bad)
                fail("expected limit for $bad")
            } catch (e: QrTransferLimitException) {
                assertEquals("qr_transfer_raw_payload_too_large", e.code)
            }
        }
    }

    @Test fun `垃圾输入报解压失败而非限流码`() {
        try {
            qrTransferDecompress("not gzip at all".toByteArray(), maxOutputBytes = 1024)
            fail("expected decompression failure")
        } catch (e: QrTransferDecompressionException) {
            assertEquals("qr_transfer_decompression_failed", e.code)
        }
        // 空输入同样不是合法 gzip。
        try {
            qrTransferDecompress(ByteArray(0), maxOutputBytes = 1024)
            fail("expected decompression failure")
        } catch (e: QrTransferDecompressionException) {
            assertEquals("qr_transfer_decompression_failed", e.code)
        }
    }

    @Test fun `文本往返一致`() {
        val raw = "二维码容量检查".repeat(20).toByteArray(Charsets.UTF_8)
        val compressed = gzip(raw)
        assertArrayEquals(raw, qrTransferDecompress(compressed, maxOutputBytes = raw.size))
    }
}
