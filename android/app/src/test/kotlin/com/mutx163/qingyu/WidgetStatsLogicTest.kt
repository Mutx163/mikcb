package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.BeforeClass
import org.junit.Test
import java.util.TimeZone

class WidgetStatsLogicTest {

    companion object {
        // 日期运算全部基于 Calendar（本地时区），固定 UTC 保证任意机器上结果一致。
        @BeforeClass
        @JvmStatic
        fun setUpTimeZone() {
            TimeZone.setDefault(TimeZone.getTimeZone("UTC"))
        }
    }

    // 1970-01-01 是周四；第一个周一 = 1970-01-05 = epoch day 4。
    // DAY 的倍数在 UTC 下即当天零点，与 calculateSectionsDone 的日界一致。
    private val day = 86_400_000L
    private val monday = 4L * day // 第 1 周周一（epoch day 4）

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
        // 开学日 = 第 1 周周一（epoch day 4）；今天 = 第 3 周周一（day 4 + 14）。
        // 周一课 + 周三课：完整周 1-2 共 8 节；第 3 周周一已上 2 节（周三未到）→ 10。
        val courses = listOf(course(dayOfWeek = 1), course(name = "英语", dayOfWeek = 3))
        val done = WidgetStatsLogic.calculateSectionsDone(
            courses = courses,
            calendarWeek = 3,
            semesterStartDayStartMillis = monday,
            todayDayStartMillis = monday + 14 * day,
            viewWeek = 3,
        )
        assertEquals(10, done)
    }

    @Test
    fun sectionsDoneAnchorsToMondayWhenSemesterStartsMidWeek() {
        // 开学日 = 第 1 周周三（day 4+2）；今天 = 第 2 周周一（day 4+7）。
        // 正确口径：完整周 1..1 = 2 节 + 当前周周一（day 11）已上 2 节 = 4。
        // 旧实现直接锚定周三（week2 = day 13..19），今天 day 11 落在窗口外 → 只算 2。
        val done = WidgetStatsLogic.calculateSectionsDone(
            courses = listOf(course(dayOfWeek = 1)),
            calendarWeek = 2,
            semesterStartDayStartMillis = monday + 2 * day,
            todayDayStartMillis = monday + 7 * day,
            viewWeek = 2,
        )
        assertEquals(4, done)
    }

    @Test
    fun sectionsDoneWednesdayCourseCountsOnItsActualDayMidWeekStart() {
        // 开学日 = 周三（day 4+2），周三课当天（day 4+3 已过周三）就该累计。
        // 旧实现锚定周三，第 1 周的"周三"被算到 day 4+9（下周三）→ 漏计。
        val done = WidgetStatsLogic.calculateSectionsDone(
            courses = listOf(course(dayOfWeek = 3)),
            calendarWeek = 1,
            semesterStartDayStartMillis = monday + 2 * day,
            todayDayStartMillis = monday + 3 * day,
            viewWeek = 1,
        )
        assertEquals(2, done)
    }

    @Test
    fun sectionsDoneBeforeSemesterStartIsZero() {
        val done = WidgetStatsLogic.calculateSectionsDone(
            courses = listOf(course()),
            calendarWeek = 0,
            semesterStartDayStartMillis = monday,
            todayDayStartMillis = monday - day,
            viewWeek = 1,
        )
        assertEquals(0, done)
    }

    @Test
    fun semesterStartMondayMillisNormalizesMidWeekStart() {
        // 周一 → 本身；周三/周日 → 所在周周一；下周一 → 自身
        assertEquals(monday, WidgetStatsLogic.semesterStartMondayMillis(monday))
        assertEquals(monday, WidgetStatsLogic.semesterStartMondayMillis(monday + 2 * day))
        assertEquals(monday, WidgetStatsLogic.semesterStartMondayMillis(monday + 6 * day))
        assertEquals(monday + 7 * day, WidgetStatsLogic.semesterStartMondayMillis(monday + 7 * day))
    }

    @Test
    fun sectionsDoneEndedSemesterClampsToTotal() {
        // calendarWeek 被 clamp 到学期末（如 16），done 不得超过 sectionsTotal。
        val courses = listOf(course(endWeek = 16))
        val total = WidgetStatsLogic.calculateSectionsTotal(courses)
        val done = WidgetStatsLogic.calculateSectionsDone(
            courses = courses,
            calendarWeek = 16,
            semesterStartDayStartMillis = 0L,
            todayDayStartMillis = monday + 200 * day,
            viewWeek = 16,
        )
        assertEquals(total, done)
    }
}
