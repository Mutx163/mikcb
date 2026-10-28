package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * [WidgetRefreshBridge] 的 JVM 单测：用一个可变的假宿主（签名 / 今日课程数 / 当天 epoch day）
 * 驱动两路刺激，断言「刷了几次、为什么刷」。期望值人推，与实现无关。
 *
 * 覆盖的行为契约：
 * 1. 订阅后先 [WidgetRefreshBridge.seedBaseline] → 等值通知不空刷；
 * 2. 内容变更只在签名变化时刷，连续两次等值变更只刷第一次；
 * 3. 内容改回原值也算「变了」，各刷一次（去重只认「相邻相等」）；
 * 4. 定时 tick 同日无课跳过、同日有课刷、跨天无课也刷。
 */
class WidgetRefreshBridgeTest {

    private class FakeHost {
        var signature: String = "sig-1"
        var courseCount: Int = 0
        var day: Long = 100L
        val requests = mutableListOf<WidgetRefreshRequest>()
    }

    private fun bridgeFor(host: FakeHost): WidgetRefreshBridge = WidgetRefreshBridge(
        contentSignature = { host.signature },
        todayCourseCount = { host.courseCount },
        todayEpochDay = { host.day },
        onRefresh = { host.requests += it },
    )

    // ---------- 内容变更路 ----------

    @Test
    fun seededBaselineThenSameSignatureDoesNotRefresh() {
        val host = FakeHost()
        val bridge = bridgeFor(host)
        bridge.seedBaseline()
        bridge.onTimetableChanged() // 签名没变
        assertEquals(0, host.requests.size)
    }

    @Test
    fun changedSignatureRefreshesOnceWithTimetableReason() {
        val host = FakeHost()
        val bridge = bridgeFor(host)
        bridge.seedBaseline()
        host.signature = "sig-2"
        bridge.onTimetableChanged()
        assertEquals(1, host.requests.size)
        assertEquals(WidgetRefreshReason.TIMETABLE_CHANGED, host.requests[0].reason)
        assertEquals("sig-2", host.requests[0].contentSignature)
    }

    @Test
    fun consecutiveEqualChangesDedupedToOneRefresh() {
        val host = FakeHost()
        val bridge = bridgeFor(host)
        bridge.seedBaseline()
        host.signature = "sig-2"
        bridge.onTimetableChanged() // 1
        bridge.onTimetableChanged() // 同签名，去重
        bridge.onTimetableChanged() // 同签名，去重
        assertEquals(1, host.requests.size)
    }

    @Test
    fun changeThenRevertEachCountsAsChange() {
        val host = FakeHost()
        val bridge = bridgeFor(host)
        bridge.seedBaseline() // 基线 sig-1
        host.signature = "sig-2"
        bridge.onTimetableChanged() // 1（变了）
        host.signature = "sig-1"
        bridge.onTimetableChanged() // 2（又变回，仍算变更）
        assertEquals(2, host.requests.size)
    }

    @Test
    fun changeWithoutSeedUsesNullBaselineAndRefreshesOnce() {
        val host = FakeHost()
        val bridge = bridgeFor(host) // 故意不 seedBaseline
        bridge.onTimetableChanged() // 首刷（null 基线）
        bridge.onTimetableChanged() // 同签名，去重
        assertEquals(1, host.requests.size)
        assertEquals(WidgetRefreshReason.TIMETABLE_CHANGED, host.requests[0].reason)
    }

    @Test
    fun contentChangeRefreshesEvenWhenNoClassToday() {
        // 内容变更不看「今天有没有课」——真实数据变了就得刷
        val host = FakeHost()
        host.courseCount = 0
        val bridge = bridgeFor(host)
        bridge.seedBaseline()
        host.signature = "sig-2"
        bridge.onTimetableChanged()
        assertEquals(1, host.requests.size)
    }

    // ---------- 定时 tick 路 ----------

    @Test
    fun timeTickSameDayNoClassSkips() {
        val host = FakeHost()
        val bridge = bridgeFor(host)
        bridge.seedBaseline() // day=100, count=0
        bridge.onTimeTick()
        assertEquals(0, host.requests.size)
    }

    @Test
    fun timeTickSameDayWithClassRefreshesClassToday() {
        val host = FakeHost()
        val bridge = bridgeFor(host)
        bridge.seedBaseline()
        host.courseCount = 3
        bridge.onTimeTick()
        assertEquals(1, host.requests.size)
        assertEquals(WidgetRefreshReason.TIME_TICK_CLASS_TODAY, host.requests[0].reason)
    }

    @Test
    fun timeTickDayChangedNoClassRefreshesDayChanged() {
        val host = FakeHost()
        val bridge = bridgeFor(host)
        bridge.seedBaseline() // day=100, count=0
        host.day = 101L
        bridge.onTimeTick()
        assertEquals(1, host.requests.size)
        assertEquals(WidgetRefreshReason.TIME_TICK_DAY_CHANGED, host.requests[0].reason)
    }

    @Test
    fun timeTickAfterDayChangedThenSameDayNoClassSkipsAgain() {
        val host = FakeHost()
        val bridge = bridgeFor(host)
        bridge.seedBaseline() // day=100
        host.day = 101L
        bridge.onTimeTick() // 跨天刷 1
        bridge.onTimeTick() // 同日无课，跳过
        assertEquals(1, host.requests.size)
    }

    @Test
    fun timeTickUpdatesRefreshDaySoNextSameDayTickIsQuiet() {
        val host = FakeHost()
        host.courseCount = 2
        val bridge = bridgeFor(host)
        bridge.seedBaseline() // day=100, 有课
        host.courseCount = 0
        bridge.onTimeTick() // 同日曾刷过 day=100 → 现在无课且同日 → 跳过
        assertEquals(0, host.requests.size)
        assertTrue(host.requests.isEmpty())
    }
}
