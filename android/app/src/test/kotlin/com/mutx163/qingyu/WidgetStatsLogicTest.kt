package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.Test

class WidgetStatsLogicTest {

    private fun course(
        name: String = "数学",
        dayOfWeek: Int = 1,
        startSection: Int = 1,
        endSection: Int = 2,
        startWeek: Int = 1,
        endWeek: Int = 16,
        isOddWeek: Boolean = false,
        isEvenWeek: Boolean = false,
        customWeeks: List<Int>? = null,
        suspendedWeeks: List<Int>? = null,
        courseNature: String = "required",
    ) = WidgetSourceCourse(
        id = name,
        name = name,
        shortName = null,
        location = "",
        startTime = "08:00",
        endTime = "09:40",
        dayOfWeek = dayOfWeek,
        startSection = startSection,
        endSection = endSection,
        startWeek = startWeek,
        endWeek = endWeek,
        isOddWeek = isOddWeek,
        isEvenWeek = isEvenWeek,
        customWeeks = customWeeks,
        suspendedWeeks = suspendedWeeks,
        courseNature = courseNature,
    )

    @Test
    fun sectionsTotalCountsScheduledWeeksAndSuspension() {
        // 2 节 × 16 周 = 32
        assertEquals(32, WidgetStatsLogic.calculateSectionsTotal(listOf(course())))
        // 单周课只有 8 个有效周：2 × 8 = 16
        assertEquals(16, WidgetStatsLogic.calculateSectionsTotal(listOf(course(isOddWeek = true))))
        // 自定义周 [1,3]：2 × 2 = 4
        assertEquals(4, WidgetStatsLogic.calculateSectionsTotal(listOf(course(customWeeks = listOf(1, 3)))))
        // 停课不计入计划口径
        assertEquals(30, WidgetStatsLogic.calculateSectionsTotal(listOf(course(suspendedWeeks = listOf(2)))))
    }

    @Test
    fun activeWeeksExcludesSuspension() {
        val c = course()
        assertEquals(3, WidgetStatsLogic.countActiveWeeks(c, 3))
        val suspended = course(suspendedWeeks = listOf(2))
        assertEquals(2, WidgetStatsLogic.countActiveWeeks(suspended, 3))
        assertEquals(0, WidgetStatsLogic.countActiveWeeks(c, 0))
    }

    @Test
    fun longestStreakMirrorsWeeklyPatternCappedAt7() {
        // 周一 + 周二 → 连续 2 天
        assertEquals(2, WidgetStatsLogic.calculateLongestStreak(listOf(course(dayOfWeek = 1), course(name = "英语", dayOfWeek = 2)), 5))
        // 全周排课 → 上限 7
        val all = (1..7).map { course(name = "d$it", dayOfWeek = it) }
        assertEquals(7, WidgetStatsLogic.calculateLongestStreak(all, 5))
        // 当前周之前无有效周 → 0
        assertEquals(0, WidgetStatsLogic.calculateLongestStreak(listOf(course(startWeek = 3)), 2))
    }

    @Test
    fun sectionsDoneWithoutCalendarFallsBackToFullWeeks() {
        val courses = listOf(course())
        // viewWeek=5 → 2 节 × 5 周 = 10
        assertEquals(
            10,
            WidgetStatsLogic.calculateSectionsDone(
                courses = courses,
                calendarWeek = null,
                semesterStartDayStartMillis = null,
                todayDayStartMillis = 0L,
                viewWeek = 5,
            ),
        )
    }

    @Test
    fun sectionsDoneByDateAccumulatesCurrentWeekUpToToday() {
        // 开学日 = 第 1 周周一 = day 0；今天 = 第 3 周周二 = day 15
        val startMillis = 0L
        val todayMillis = 15L * 86_400_000L
        val monday = course(dayOfWeek = 1)   // 2 节/周
        val wednesday = course(name = "英语", dayOfWeek = 3)
        val courses = listOf(monday, wednesday)

        val done = WidgetStatsLogic.calculateSectionsDone(
            courses = courses,
            calendarWeek = 3,
            semesterStartDayStartMillis = startMillis,
            todayDayStartMillis = todayMillis,
            viewWeek = 3,
        )
        // 完整周 1-2：2 门 × 2 节 × 2 周 = 8；第 3 周周二截止只含周一课 2 节 → 10
        assertEquals(10, done)
    }

    @Test
    fun sectionsDoneBeforeSemesterStartIsZero() {
        val done = WidgetStatsLogic.calculateSectionsDone(
            courses = listOf(course()),
            calendarWeek = 0,
            semesterStartDayStartMillis = 100L,
            todayDayStartMillis = 50L,
            viewWeek = 1,
        )
        assertEquals(0, done)
    }
}
