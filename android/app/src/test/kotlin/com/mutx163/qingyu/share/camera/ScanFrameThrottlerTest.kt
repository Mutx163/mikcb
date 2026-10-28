package com.mutx163.qingyu.share.camera

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TestScanClock(var currentTime: Long = 1000L) : ScanClock {
    override fun currentTimeMillis(): Long = currentTime
    fun advance(ms: Long) { currentTime += ms }
}

class ScanFrameThrottlerTest {

    @Test
    fun `帧率时间窗口节流严格生效`() {
        val clock = TestScanClock(1000L)
        val throttler = ScanFrameThrottler(minIntervalMs = 100L, clock = clock)

        // 第 1 帧到达 (1000ms)：允许处理
        assertTrue("第1帧应当被接收", throttler.beginFrame())
        throttler.endFrame()

        // 第 2 帧到达 (1033ms，模拟 30fps 相机)：距离上一帧仅 33ms，应当被丢弃
        clock.advance(33L)
        assertFalse("33ms后的帧应被节流拦截", throttler.beginFrame())

        // 第 3 帧到达 (1066ms)：距离上一帧 66ms，仍然被丢弃
        clock.advance(33L)
        assertFalse("66ms后的帧应被节流拦截", throttler.beginFrame())

        // 第 4 帧到达 (1100ms)：距离上一帧已满 100ms，应当被允许
        clock.advance(34L)
        assertTrue("100ms后的帧应被接收", throttler.beginFrame())
        throttler.endFrame()

        val stats = throttler.snapshot()
        assertEquals(4L, stats.totalFramesReceived)
        assertEquals(2L, stats.framesProcessed)
        assertEquals(2L, stats.framesDroppedInterval)
        assertEquals(0L, stats.framesDroppedBusy)
        assertEquals(0.5, stats.dropRate, 0.001)
    }

    @Test
    fun `忙碌状态下丢帧策略生效`() {
        val clock = TestScanClock(1000L)
        val throttler = ScanFrameThrottler(
            minIntervalMs = 50L,
            dropPolicy = FrameDropPolicy.DROP_IF_BUSY,
            clock = clock,
        )

        // 第 1 帧开始处理
        assertTrue(throttler.beginFrame())
        assertTrue(throttler.isBusy)

        // 即使时间过了 80ms (> 50ms minInterval)，但第 1 帧还在解算未 endFrame
        clock.advance(80L)
        assertFalse("忙碌时应丢弃新帧", throttler.beginFrame())

        // 第 1 帧处理完成（共耗时 90ms）
        clock.advance(10L)
        throttler.endFrame()
        assertFalse(throttler.isBusy)
        assertEquals(90L, throttler.lastProcessingDurationMs)

        // 第 2 帧到达：此时空闲且已满间隔，应当接收
        clock.advance(60L)
        assertTrue(throttler.beginFrame())
        throttler.endFrame()

        val stats = throttler.snapshot()
        assertEquals(3L, stats.totalFramesReceived)
        assertEquals(2L, stats.framesProcessed)
        assertEquals(1L, stats.framesDroppedBusy)
    }

    @Test
    fun `runBudgeted安全执行块与耗时记录`() {
        val clock = TestScanClock(1000L)
        val throttler = ScanFrameThrottler(minIntervalMs = 100L, clock = clock)

        val result = throttler.runBudgeted {
            clock.advance(25L)
            "DECODED_VALUE"
        }

        assertEquals("DECODED_VALUE", result)
        assertEquals(25L, throttler.lastProcessingDurationMs)
        assertEquals(25L, throttler.totalProcessingTimeMs)
        assertEquals(25.0, throttler.snapshot().averageProcessingTimeMs, 0.001)

        // 紧接着运行：由于未满 100ms，返回 null 且 block 不被执行
        var executed = false
        val skipped = throttler.runBudgeted {
            executed = true
            "ANOTHER"
        }
        assertNull(skipped)
        assertFalse("节流时 block 绝不执行", executed)
    }

    @Test
    fun `重置清空状态与指标`() {
        val clock = TestScanClock(1000L)
        val throttler = ScanFrameThrottler(clock = clock)
        throttler.beginFrame()
        throttler.endFrame()
        assertEquals(1L, throttler.framesProcessed)

        throttler.reset()
        assertEquals(0L, throttler.framesProcessed)
        assertEquals(0L, throttler.totalFramesReceived)
        assertFalse(throttler.isBusy)
    }
}
