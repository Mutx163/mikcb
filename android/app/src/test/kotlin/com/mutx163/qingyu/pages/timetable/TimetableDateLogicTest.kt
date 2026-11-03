package com.mutx163.qingyu.pages.timetable

import java.time.LocalDate
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 日视图「回今日」入口判据（Dart `_canNavigateDayViewToToday`，`timetable_screen.dart:1428-1435`）。
 *
 * 这组用例锚定「跨学期课程过滤」的导航侧：假期 / 学期末、以及今天那个星期被隐藏时不给入口，
 * 否则一点就跳到「上周同一个星期几」。
 */
class TimetableDateLogicTest {

    private val mondayStart = LocalDate.of(2026, 9, 1) // 周二；归一化后周一 = 8-31
    private val weekdays = listOf(1, 2, 3, 4, 5)

    @Test
    fun `学期内的可见星期且不在今天 给入口`() {
        assertTrue(
            TimetableDateLogic.canNavigateToToday(
                isCurrentPageToday = false,
                visibleDays = weekdays,
                semesterStart = mondayStart,
                totalWeeks = 16,
                today = LocalDate.of(2026, 10, 7), // 周三，第 6 周
            ),
        )
    }

    @Test
    fun `当前页就是今天 不给入口`() {
        assertFalse(
            TimetableDateLogic.canNavigateToToday(
                isCurrentPageToday = true,
                visibleDays = weekdays,
                semesterStart = mondayStart,
                totalWeeks = 16,
                today = LocalDate.of(2026, 10, 7),
            ),
        )
    }

    @Test
    fun `今天那个星期被隐藏 不给入口`() {
        // 只显示工作日，今天周六 ⇒ 点「回今日」会落到看不见的那天。
        assertFalse(
            TimetableDateLogic.canNavigateToToday(
                isCurrentPageToday = false,
                visibleDays = weekdays,
                semesterStart = mondayStart,
                totalWeeks = 16,
                today = LocalDate.of(2026, 10, 10), // 周六，第 6 周
            ),
        )
    }

    @Test
    fun `已放假超出学期周数 不给入口`() {
        // 16 周学期最后一天 = 2026-12-20；12-23 已是第 17 周。
        assertFalse(
            TimetableDateLogic.canNavigateToToday(
                isCurrentPageToday = false,
                visibleDays = listOf(1, 2, 3, 4, 5, 6, 7),
                semesterStart = mondayStart,
                totalWeeks = 16,
                today = LocalDate.of(2026, 12, 23),
            ),
        )
    }

    @Test
    fun `没设开学日 不给入口`() {
        assertFalse(
            TimetableDateLogic.canNavigateToToday(
                isCurrentPageToday = false,
                visibleDays = weekdays,
                semesterStart = null,
                totalWeeks = 16,
                today = LocalDate.of(2026, 10, 7),
            ),
        )
    }
}
