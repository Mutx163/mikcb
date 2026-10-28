package com.mutx163.qingyu.share.camera

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ScanResultDeduplicatorTest {

    @Test
    fun `首次扫描与同一内容冷却窗口去重`() {
        val clock = TestScanClock(1000L)
        val dedup = ScanResultDeduplicator(
            dedupWindowMs = 1500L,
            minIntervalBetweenScansMs = 250L,
            clock = clock,
        )

        // 第一次扫描：通过
        val d1 = dedup.evaluate("CODE_A")
        assertEquals(DedupDecision.ACCEPT, d1)
        assertEquals("CODE_A", dedup.lastAcceptedValue)

        // 500ms 后重复扫描到 CODE_A：在 1500ms 窗口内，抑制
        clock.advance(500L)
        val d2 = dedup.evaluate("CODE_A")
        assertEquals(DedupDecision.DUPLICATE_IGNORED, d2)

        // 1200ms 后（距离初次扫描 1700ms > 1500ms）：冷却结束，允许再次接受
        clock.advance(1200L)
        val d3 = dedup.evaluate("CODE_A")
        assertEquals(DedupDecision.ACCEPT, d3)

        val stats = dedup.snapshot()
        assertEquals(3L, stats.totalEvaluated)
        assertEquals(2L, stats.totalAccepted)
        assertEquals(1L, stats.totalDuplicatesSuppressed)
    }

    @Test
    fun `不同内容之间的全局防抖间隔`() {
        val clock = TestScanClock(1000L)
        val dedup = ScanResultDeduplicator(
            dedupWindowMs = 1500L,
            minIntervalBetweenScansMs = 250L,
            clock = clock,
        )

        // 扫出 CODE_A
        assertEquals(DedupDecision.ACCEPT, dedup.evaluate("CODE_A"))

        // 仅过了 50ms 扫到 CODE_B：由于全局防抖为 250ms，抑制防抖
        clock.advance(50L)
        assertEquals(DedupDecision.DEBOUNCE_DROPPED, dedup.evaluate("CODE_B"))

        // 过了 250ms（共 300ms > 250ms）：接受 CODE_B
        clock.advance(250L)
        assertEquals(DedupDecision.ACCEPT, dedup.evaluate("CODE_B"))
        assertEquals("CODE_B", dedup.lastAcceptedValue)

        val stats = dedup.snapshot()
        assertEquals(1L, stats.totalDebounceSuppressed)
    }

    @Test
    fun `连续命中确认机制过滤噪点`() {
        val clock = TestScanClock(1000L)
        val dedup = ScanResultDeduplicator(
            dedupWindowMs = 1500L,
            minIntervalBetweenScansMs = 100L,
            consecutiveHitsRequired = 3, // 要求连续 3 帧
            clock = clock,
        )

        // 第 1 帧命中 CODE_X
        assertEquals(DedupDecision.AWAITING_CONFIRMATION, dedup.evaluate("CODE_X"))
        assertNull(dedup.lastAcceptedValue)

        // 偶发噪点帧 CODE_NOISE：打断连续计数
        clock.advance(150L)
        assertEquals(DedupDecision.AWAITING_CONFIRMATION, dedup.evaluate("CODE_NOISE"))

        // 重新命中 CODE_X 第 1 帧
        clock.advance(150L)
        assertEquals(DedupDecision.AWAITING_CONFIRMATION, dedup.evaluate("CODE_X"))

        // CODE_X 第 2 帧
        clock.advance(150L)
        assertEquals(DedupDecision.AWAITING_CONFIRMATION, dedup.evaluate("CODE_X"))

        // CODE_X 第 3 帧：达成连续 3 帧确认，通过！
        clock.advance(150L)
        assertEquals(DedupDecision.ACCEPT, dedup.evaluate("CODE_X"))
        assertEquals("CODE_X", dedup.lastAcceptedValue)
    }

    @Test
    fun `重置后立刻可以再次接受相同内容`() {
        val clock = TestScanClock(1000L)
        val dedup = ScanResultDeduplicator(dedupWindowMs = 1500L, clock = clock)

        assertEquals(DedupDecision.ACCEPT, dedup.evaluate("CODE_A"))

        clock.advance(100L)
        assertEquals(DedupDecision.DUPLICATE_IGNORED, dedup.evaluate("CODE_A"))

        // 业务重置（如重新扫码）
        dedup.reset()
        assertNull(dedup.lastAcceptedValue)

        // 重置后即使在 100ms 内，也能立刻接受
        clock.advance(50L)
        assertEquals(DedupDecision.ACCEPT, dedup.evaluate("CODE_A"))
    }
}
