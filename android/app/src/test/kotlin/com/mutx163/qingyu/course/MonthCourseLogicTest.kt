package com.mutx163.qingyu.course

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.DartTime
import com.mutx163.qingyu.core.TimetableSettings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * MonthCourseLogic 端口测试（族3 · month_view_logic 相关纯函数中课程侧子集）。
 *
 * Dart 源：lib/domain/month_view_logic.dart（554 行）中与课程直接相关的纯函数：
 * monthGridDates / coursesOnDate / rowsInMonth / courseColorHexes。
 * 考试/日程/节假日展开属于 calendar 族（第一团队），本族不碰。
 *
 * 期望值来源：
 * - [Dart抄录]：month_view_logic.dart 注释与既有用例的日期锚点；
 * - [Dart推演]：对照实现逐行推演；
 * - [人推]：独立推的边界值（跨月/空学期/颜色去重）。
 */
class MonthCourseLogicTest {

    private fun course(
        id: String,
        name: String = "数学",
        dayOfWeek: Int = 1,
        startWeek: Int = 1,
        endWeek: Int = 16,
        color: String = "#2196F3",
        suspendedWeeks: List<Int>? = null,
        customWeeks: List<Int>? = null,
    ): Course = Course(
        id = id, name = name, teacher = "t", location = "l",
        dayOfWeek = dayOfWeek, startSection = 1, endSection = 2,
        startTime = "08:00", endTime = "09:40", color = color,
        startWeek = startWeek, endWeek = endWeek,
        suspendedWeeks = suspendedWeeks, customWeeks = customWeeks,
    )

    private fun settings(start: String? = "2026-03-02", weeks: Int = 16): TimetableSettings =
        TimetableSettings.defaults().copy(
            semesterWeekCount = weeks,
            semesterStartDate = start?.let { DartTime.dateTime(it.substring(0, 4).toInt(), it.substring(5, 7).toInt(), it.substring(8, 10).toInt()) },
        )

    @Test
    fun monthGridDates_is42MondayFirst() { // [Dart推演 month_view_logic.dart:220-226 + 人推]
        val dates = MonthCourseLogic.monthGridDates(2026, 10)
        assertEquals(42, dates.size)
        // 2026-10-01 是周四，网格起点应为周一 2026-09-28。
        assertEquals(DartTime.dateTime(2026, 9, 28), dates.first())
        assertEquals(1, dates.first().dayOfWeek.value)
        assertEquals(DartTime.dateTime(2026, 11, 8), dates.last())
    }

    @Test
    fun coursesOnDate_matchesWeekdayAndWeek() { // [Dart推演 month_view_logic.dart:234-254 + 人推]
        // 学期首周周一 2026-03-02（周一）；2026-03-03 是第 1 周周二。
        val tuesday = DartTime.dateTime(2026, 3, 3)
        val courses = listOf(course("c1", dayOfWeek = 2), course("c2", dayOfWeek = 3))
        val hit = MonthCourseLogic.coursesOnDate(courses, tuesday, settings())
        assertEquals(listOf("c1"), hit.map { it.id })
    }

    @Test
    fun coursesOnDate_noSemesterStart_returnsEmpty() { // [人推：空学期]
        val date = DartTime.dateTime(2026, 3, 3)
        assertTrue(MonthCourseLogic.coursesOnDate(listOf(course("c1")), date, TimetableSettings.defaults().copy(semesterStartDate = null)).isEmpty())
    }

    @Test
    fun coursesOnDate_beforeSemester_returnsEmpty() { // [人推：开学前]
        val before = DartTime.dateTime(2026, 2, 20)
        assertTrue(MonthCourseLogic.coursesOnDate(listOf(course("c1")), before, settings()).isEmpty())
    }

    @Test
    fun rowsInMonth_countsLastRowWithCurrentMonth() { // [Dart推演 month_view_logic.dart:126-139 + 人推]
        // 2026-10 网格：前 4 格是 9 月补位，尾行含 11 月补位 → 最后一行仍有本月日期。
        val october = MonthCourseLogic.monthGridDates(2026, 10)
        val flags = october.map { it.monthValue != 10 }
        // flags=false 表示本月；最后一格 11-08 必为补位。
        assertTrue(flags.last())
        // 人推：全补位（异常数据）退回 6 行。
        assertEquals(6, MonthCourseLogic.rowsInMonth(List(42) { true }))
        // 人推：只有首行首格是本月 → 1 行。
        assertEquals(1, MonthCourseLogic.rowsInMonth(listOf(false) + List(41) { true }))
    }

    @Test
    fun courseColorHexes_dedupesTrimsCapsAtThree() { // [Dart推演 month_view_logic.dart:376-385 + 人推]
        val courses = listOf(
            course("a", color = "  #FF0000  "),
            course("b", color = "#FF0000"),
            course("c", color = ""),
            course("d", color = "#00FF00"),
            course("e", color = "#0000FF"),
            course("f", color = "#FFFF00"),
        )
        assertEquals(listOf("#FF0000", "#00FF00", "#0000FF"), MonthCourseLogic.courseColorHexes(courses))
        assertTrue(MonthCourseLogic.courseColorHexes(emptyList()).isEmpty())
    }
}
