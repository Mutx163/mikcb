package com.mutx163.qingyu

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Before
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone

/**
 * `addCalendarDays` 的夏令时行为。
 *
 * 单独一个类，不并入 [WidgetStatsLogicTest]：后者在 `@BeforeClass` 里把默认时区
 * 钉成 UTC 以便用固定 epoch 算术断言，在那个前提下夏令时根本无法被观察到。
 */
class WidgetStatsDayBoundaryTest {

    private lateinit var original: TimeZone

    @Before
    fun pinDstTimeZone() {
        original = TimeZone.getDefault()
        // 2026 年 US DST：3 月 8 日开始，11 月 1 日结束。
        TimeZone.setDefault(TimeZone.getTimeZone("America/New_York"))
    }

    @After
    fun restoreTimeZone() {
        TimeZone.setDefault(original)
    }

    // 用 LocalDate 而非 Calendar：Calendar 的月份常量是 0 基（MARCH == 2），
    // 混用会把三月读成四月——这里踩过一次。atZone 由 ZoneId 给，不是 atStartOfDay。
    private fun dayStart(month: java.time.Month, day: Int): Long =
        java.time.LocalDate.of(2026, month, day)
            .atStartOfDay(java.time.ZoneId.systemDefault())
            .toInstant()
            .toEpochMilli()

    private fun ymd(millis: Long): Triple<Int, Int, Int> {
        val cal = Calendar.getInstance().apply { timeInMillis = millis }
        return Triple(
            cal.get(Calendar.YEAR),
            cal.get(Calendar.MONTH) + 1,
            cal.get(Calendar.DAY_OF_MONTH),
        )
    }

    @Test
    fun crossesSpringForwardKeepingMidnightWallClock() {
        val before = dayStart(java.time.Month.MARCH, 7)

        val next = WidgetStatsLogic.addCalendarDays(before, 1)

        // 本条只固定行为：addCalendarDays 把 3-7 零点推到 3-8 零点。
        // 差值恒为 24 小时——DST 切换发生在当天 02:00，两个零点之间并没有少一小时。
        //
        // 那 23 小时/25 小时的风险在「跨天」而非「单日」：一整周里多出或少了
        // 一小时，固定毫秒算术会让周链整体偏移，这由 fallBack 那条覆盖。
        assertEquals(Triple(2026, 3, 8), ymd(next))
    }

    @Test
    fun crossesFallBackKeepingMidnightWallClock() {
        val before = dayStart(java.time.Month.OCTOBER, 31)

        val next = WidgetStatsLogic.addCalendarDays(before, 2)

        assertEquals(Triple(2026, 11, 2), ymd(next))
        // 10-31 → 11-01 那天有 25 小时，所以两天实际是 49 小时而非 48：
        // 固定毫秒算术会少一小时，整条周链从这里开始偏移。
        assertEquals(49L * 3_600_000L, next - before)
    }

    @Test
    fun zeroDaysIsIdentity() {
        val target = dayStart(java.time.Month.MARCH, 7)

        assertEquals(target, WidgetStatsLogic.addCalendarDays(target, 0))
    }

    @Test
    fun aFullWeekStaysOnTheSameWeekday() {
        val monday = dayStart(java.time.Month.MARCH, 2) // 周一，DST 于 3-8 开始

        val nextMonday = WidgetStatsLogic.addCalendarDays(monday, 7)

        assertEquals(Triple(2026, 3, 9), ymd(nextMonday))
        assertEquals(
            Calendar.MONDAY,
            Calendar.getInstance().apply { timeInMillis = nextMonday }
                .get(Calendar.DAY_OF_WEEK),
        )
    }
}
