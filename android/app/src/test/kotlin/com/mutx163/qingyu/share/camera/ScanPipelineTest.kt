package com.mutx163.qingyu.share.camera

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class ScanPipelineTest {

    @Test
    fun `未授权时管线不调用解码器直接丢弃`() {
        val clock = TestScanClock(1000L)
        val pipeline = ScanPipeline(
            clock = clock,
            initialHasPermission = false,
        )

        var decoderCalled = false
        val result = pipeline.onFrame {
            decoderCalled = true
            BarcodeScanResult("TEST_BARCODE")
        }

        assertNull(result)
        assertEquals("未授权时不应调用解码算法", false, decoderCalled)
    }

    @Test
    fun `完整链路测试节流解码与去重防抖`() {
        val clock = TestScanClock(1000L)
        val pipeline = ScanPipeline(
            config = ScanPipelineConfig(
                minFrameIntervalMs = 100L,
                dedupWindowMs = 1500L,
                minIntervalBetweenScansMs = 200L,
            ),
            clock = clock,
            initialHasPermission = true,
        )

        // 第 1 帧：解码成功且首次命中，分发
        var decodeCount = 0
        val r1 = pipeline.onFrame {
            decodeCount++
            BarcodeScanResult("QR_TRANSFER_DATA_1")
        }
        assertNotNull(r1)
        assertEquals("QR_TRANSFER_DATA_1", r1?.rawValue)
        assertEquals(1, decodeCount)

        // 第 2 帧（30ms 后）：被节流拦截，decoder 根本不被调用
        clock.advance(30L)
        val r2 = pipeline.onFrame {
            decodeCount++
            BarcodeScanResult("QR_TRANSFER_DATA_1")
        }
        assertNull(r2)
        assertEquals("节流拦截应省去解码计算", 1, decodeCount)

        // 第 3 帧（120ms 后）：节流通过，调用了 decoder，但去重器判定为重复内容，最终返回 null
        clock.advance(90L)
        val r3 = pipeline.onFrame {
            decodeCount++
            BarcodeScanResult("QR_TRANSFER_DATA_1")
        }
        assertNull(r3)
        assertEquals("去重拦截前执行了有效解码", 2, decodeCount)

        // 第 4 帧（1600ms 后）：冷却窗口已过，再次接受
        clock.advance(1600L)
        val r4 = pipeline.onFrame {
            decodeCount++
            BarcodeScanResult("QR_TRANSFER_DATA_1")
        }
        assertNotNull(r4)
        assertEquals("QR_TRANSFER_DATA_1", r4?.rawValue)
        assertEquals(3, decodeCount)
    }
}
