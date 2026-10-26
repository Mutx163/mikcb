package com.mutx163.qingyu.share

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/**
 * 传输预算与容量规划端口测试。
 * dart 源：qr_transfer_session.dart（QrTransferLimits）、qr_transfer_codec.dart
 * （pickSymbolSize / _preparePayload / QrTransferDecodeProgress.fraction /
 * QrTransferProtocolPolicy）；抄录 test/services/qr_transfer_codec_test.dart
 * 「编码前预检拒绝超过原始数据上限」「发送端预检按250ms播放间隔限制15分钟会话」。
 * 期望值人推：阈值边界、(k*12+9)/10 帧数公式、预算 code 串。
 */
class QrTransferLimitsTest {

    @Test fun `常量与Dart一致`() {
        assertEquals(8192, QrTransferLimits.MAX_FRAME_TEXT_LENGTH)
        assertEquals(8192, QrTransferLimits.MAX_SOURCE_SYMBOL_COUNT)
        assertEquals(4096, QrTransferLimits.MAX_SYMBOL_SIZE)
        assertEquals(16 * 1024 * 1024, QrTransferLimits.MAX_COMPRESSED_PAYLOAD_BYTES)
        assertEquals(64 * 1024 * 1024, QrTransferLimits.MAX_RAW_PAYLOAD_BYTES)
        assertEquals(32768, QrTransferLimits.MAX_FRAME_COUNT)
        assertEquals(16384, QrTransferLimits.MAX_UNIQUE_SEED_COUNT)
        assertEquals(Int.MAX_VALUE, QrTransferLimits.MAX_SEED)
        assertEquals(100, QrTransferLimits.MAX_DEGREE)
        assertEquals(32, QrTransferLimits.MAX_ADJACENCY_EDGES_PER_SOURCE_SYMBOL)
    }

    @Test fun `会话帧预算3600`() {
        // 15 分钟 / 250ms = 3600（Dart 用例直接钉住该值）。
        assertEquals(250L, QrTransferLimits.FRAME_INTERVAL_MILLIS)
        assertEquals(3600L, QrTransferLimits.maxSessionFrameCount())
    }

    @Test fun `maxDegree钳制`() {
        assertEquals(1, QrTransferLimits.maxDegreeForSourceSymbolCount(1))
        assertEquals(99, QrTransferLimits.maxDegreeForSourceSymbolCount(99))
        assertEquals(100, QrTransferLimits.maxDegreeForSourceSymbolCount(100))
        assertEquals(100, QrTransferLimits.maxDegreeForSourceSymbolCount(8192))
    }

    @Test fun `邻接边预算按32倍缩放并封顶`() {
        assertEquals(32, QrTransferLimits.maxAdjacencyEdgesForSourceSymbolCount(1))
        assertEquals(3200, QrTransferLimits.maxAdjacencyEdgesForSourceSymbolCount(100))
        assertEquals(
            QrTransferLimits.MAX_ADJACENCY_EDGES,
            QrTransferLimits.maxAdjacencyEdgesForSourceSymbolCount(8192),
        )
        assertEquals(
            QrTransferLimits.MAX_ADJACENCY_EDGES,
            QrTransferLimits.maxAdjacencyEdgesForSourceSymbolCount(100000),
        )
    }

    @Test fun `pickSymbolSize阈值`() {
        assertEquals(256, QrTransferLimits.pickSymbolSize(0))
        assertEquals(256, QrTransferLimits.pickSymbolSize(2048))
        assertEquals(512, QrTransferLimits.pickSymbolSize(2049))
        assertEquals(512, QrTransferLimits.pickSymbolSize(16384))
        assertEquals(1024, QrTransferLimits.pickSymbolSize(16385))
        assertEquals(1024, QrTransferLimits.pickSymbolSize(65536))
        assertEquals(2048, QrTransferLimits.pickSymbolSize(65537))
    }

    @Test fun `planTransfer空数据抛IllegalArgumentException`() {
        try {
            QrTransferLimits.planTransfer(compressedLength = 10, rawLength = 0)
            fail("expected IllegalArgumentException")
        } catch (_: IllegalArgumentException) {
            // Dart ArgumentError 对应用。
        }
    }

    @Test fun `planTransfer超原始上限`() {
        try {
            QrTransferLimits.planTransfer(
                compressedLength = 10,
                rawLength = QrTransferLimits.MAX_RAW_PAYLOAD_BYTES + 1,
            )
            fail("expected limit")
        } catch (e: QrTransferLimitException) {
            assertEquals("qr_transfer_raw_payload_too_large", e.code)
            assertEquals(QrTransferLimits.MAX_RAW_PAYLOAD_BYTES + 1, e.actual)
            assertEquals(QrTransferLimits.MAX_RAW_PAYLOAD_BYTES, e.limit)
        }
    }

    @Test fun `planTransfer容量算术`() {
        // 压缩后 3000 字节 → 512 符号 → k=(3000+511)/512=6 → 帧数=(72+9)/10=8。
        val capacity = QrTransferLimits.planTransfer(compressedLength = 3000, rawLength = 9000)
        assertEquals(512, QrTransferLimits.pickSymbolSize(3000))
        assertEquals(6, capacity.sourceSymbolCount)
        assertEquals(8, capacity.estimatedFrameCount)
        assertEquals(9000, capacity.rawLength)
        assertEquals(3000, capacity.compressedLength)
    }

    @Test fun `planTransfer超会话时长预算`() {
        // Dart 用例：((3600*10)/12+1)*2048 随机字节 → 帧数超 3600 → session_duration_exceeded。
        // 等价纯算术：k 需 > 3000（帧数=(k*12+9)/10>3600 → k≥3000）。
        // 取 k=3001（t=2048 时压缩长 ≈ 3001*2048）。
        val compressed = 3001 * 2048
        try {
            QrTransferLimits.planTransfer(compressedLength = compressed, rawLength = compressed)
            fail("expected session duration exceeded")
        } catch (e: QrTransferLimitException) {
            assertEquals("qr_transfer_session_duration_exceeded", e.code)
        }
    }

    @Test fun `progressFraction边界`() {
        assertEquals(1.0, QrTransferDecodeProgress(sourceSymbolCount = 0).fraction, 0.0)
        assertEquals(
            0.5,
            QrTransferDecodeProgress(sourceSymbolCount = 4, decodedSymbols = 2).fraction,
            1e-9,
        )
        // 钳制到 [0,1]。
        assertEquals(
            1.0,
            QrTransferDecodeProgress(sourceSymbolCount = 4, decodedSymbols = 9).fraction,
            0.0,
        )
        assertEquals(
            0.0,
            QrTransferDecodeProgress(sourceSymbolCount = 4, decodedSymbols = -2).fraction,
            0.0,
        )
    }

    @Test fun `协议策略是可信近场明文`() {
        assertEquals("trusted_proximity_plaintext", QrTransferProtocolPolicy.TRUST_MODEL)
        assertTrue(QrTransferProtocolPolicy.REQUIRES_EXPLICIT_IMPORT_CONFIRMATION)
        assertFalse(QrTransferProtocolPolicy.IS_ENCRYPTED)
        assertFalse(QrTransferProtocolPolicy.AUTHENTICATES_SENDER)
    }
}
