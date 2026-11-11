package com.mutx163.qingyu

import com.mutx163.qingyu.statistics.CourseStub
import com.mutx163.qingyu.statistics.StatisticsService
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 统计页与桌面统计小组件的**周有效判定 / 最长连续上课天数**对拍（P1-12 补钉，2026-11-11）。
 *
 * ## 为什么要它
 *
 * 「这一周有没有课」这条判定在两条链路上各有一份实现：
 * - 统计页：`CourseStub.isActiveInWeek` + `StatisticsService.countActiveWeeks`（Stubs 链路）；
 * - 桌面小组件：`WidgetSourceCourse.isInWeek` 系列 + `WidgetStatsLogic.countActiveWeeks`
 *   （TodayWidgetSupport 链路）。
 * 两者的字段语义（单双周 / 自定义周 / 停课周 / 区间）目前**近似**，但一直零钉住；
 * 谁将来只给一侧加规则，两个界面就会给出不同数字。
 *
 * P1-12 只合并了「streak 算法本体」（`statistics/LongestStreakLogic`）；把
 * `countActiveWeeks` 也收进内核（入参传 lambda）是**遗留债**，本波不扩范围——
 * 所以先用这份对拍把两侧钉在一起。
 *
 * 运行面：本文件引用了 `WidgetSourceCourse`（定义在 Android 依赖文件
 * `TodayWidgetSupport.kt` 里），**L0 的纯 JVM 编译面收不到**，由终门禁
 * `:app:testDevDebugUnitTest` 覆盖。
 */
class StatisticsWidgetWeekParityTest {

    // ------------------------------------------------------------ fixtures

    private fun stub(
        dayOfWeek: Int = 1,
        startWeek: Int = 1,
        endWeek: Int = 16,
        isOddWeek: Boolean = false,
        isEvenWeek: Boolean = false,
        customWeeks: List<Int>? = null,
        suspendedWeeks: List<Int>? = null,
    ): CourseStub = CourseStub(
        name = "数学",
        teacher = "",
        location = "",
        dayOfWeek = dayOfWeek,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
        startWeek = startWeek,
        endWeek = endWeek,
        isOddWeek = isOddWeek,
        isEvenWeek = isEvenWeek,
        customWeeks = customWeeks,
        suspendedWeeks = suspendedWeeks,
    )

    private fun widget(
        dayOfWeek: Int = 1,
        startWeek: Int = 1,
        endWeek: Int = 16,
        isOddWeek: Boolean = false,
        isEvenWeek: Boolean = false,
        customWeeks: List<Int>? = null,
        suspendedWeeks: List<Int>? = null,
    ): WidgetSourceCourse = WidgetSourceCourse(
        id = "c1",
        name = "数学",
        shortName = null,
        location = "",
        startTime = "08:00",
        endTime = "09:40",
        dayOfWeek = dayOfWeek,
        startSection = 1,
        endSection = 2,
        startWeek = startWeek,
        endWeek = endWeek,
        isOddWeek = isOddWeek,
        isEvenWeek = isEvenWeek,
        customWeeks = customWeeks,
        suspendedWeeks = suspendedWeeks,
    )

    /** 两条链路的「有效周数」逐周对拍。 */
    private fun assertWeekCountsMatch(name: String, stub: CourseStub, widget: WidgetSourceCourse) {
        for (week in 0..17) {
            assertEquals(
                "$name：第 $week 周的有效周数两链路不一致",
                StatisticsService.countActiveWeeks(stub, week),
                WidgetStatsLogic.countActiveWeeks(widget, week),
            )
        }
    }

    // ------------------------------------------------------------ 周有效判定

    @Test
    fun `区间课程的两条链路有效周数逐周一致`() {
        assertWeekCountsMatch("默认区间 1..16", stub(), widget())
        assertWeekCountsMatch("区间 3..5", stub(startWeek = 3, endWeek = 5), widget(startWeek = 3, endWeek = 5))
    }

    @Test
    fun `单双周与自定义周两链路一致`() {
        assertWeekCountsMatch("单周", stub(isOddWeek = true), widget(isOddWeek = true))
        assertWeekCountsMatch("双周", stub(isEvenWeek = true), widget(isEvenWeek = true))
        assertWeekCountsMatch(
            "自定义周 [1,3,5]",
            stub(customWeeks = listOf(1, 3, 5)),
            widget(customWeeks = listOf(1, 3, 5)),
        )
    }

    @Test
    fun `停课周两链路一致`() {
        assertWeekCountsMatch(
            "停课第 2 周",
            stub(suspendedWeeks = listOf(2)),
            widget(suspendedWeeks = listOf(2)),
        )
        assertWeekCountsMatch(
            "停课 + 单周",
            stub(isOddWeek = true, suspendedWeeks = listOf(3)),
            widget(isOddWeek = true, suspendedWeeks = listOf(3)),
        )
    }

    // ------------------------------------------------------------ 7 天向量 + streak

    @Test
    fun `七天向量逐天一致 单天课两边都算 1 天`() {
        for (day in 1..7) {
            val stubStreak = StatisticsService.calculateSemester(
                allCourses = listOf(stub(dayOfWeek = day)),
                currentWeek = 5,
                semesterWeekCount = 16,
            ).longestStreak
            val widgetStreak = WidgetStatsLogic.calculateLongestStreak(listOf(widget(dayOfWeek = day)), 5)
            assertEquals("第 $day 天单独排课：统计侧应为 1", 1, stubStreak)
            assertEquals("第 $day 天单独排课：小组件侧应为 1", 1, widgetStreak)
            assertEquals("第 $day 天单独排课：两链路 streak 不一致", stubStreak, widgetStreak)
        }
    }

    @Test
    fun `整周排满两链路都是 7`() {
        val stubCourses = (1..7).map { stub(dayOfWeek = it) }
        val widgetCourses = (1..7).map { widget(dayOfWeek = it) }
        val stubStreak = StatisticsService.calculateSemester(
            allCourses = stubCourses,
            currentWeek = 5,
            semesterWeekCount = 16,
        ).longestStreak
        val widgetStreak = WidgetStatsLogic.calculateLongestStreak(widgetCourses, 5)
        assertEquals(7, stubStreak)
        assertEquals(7, widgetStreak)
        assertEquals(stubStreak, widgetStreak)
    }

    @Test
    fun `跨周边界与当前周之后两链路一致`() {
        // 周六 + 周日 + 周一 在 14 天窗口里连成 3。
        val stubCross = listOf(stub(dayOfWeek = 6), stub(dayOfWeek = 7), stub(dayOfWeek = 1))
        val widgetCross = listOf(widget(dayOfWeek = 6), widget(dayOfWeek = 7), widget(dayOfWeek = 1))
        assertEquals(
            3,
            StatisticsService.calculateSemester(stubCross, currentWeek = 5, semesterWeekCount = 16).longestStreak,
        )
        assertEquals(3, WidgetStatsLogic.calculateLongestStreak(widgetCross, 5))

        // 课程从第 3 周才开始：当前第 2 周两侧都该是 0（无有效周 ⇒ 无天数）。
        val stubLate = listOf(stub(dayOfWeek = 1, startWeek = 3))
        val widgetLate = listOf(widget(dayOfWeek = 1, startWeek = 3))
        assertEquals(
            0,
            StatisticsService.calculateSemester(stubLate, currentWeek = 2, semesterWeekCount = 16).longestStreak,
        )
        assertEquals(0, WidgetStatsLogic.calculateLongestStreak(widgetLate, 2))
    }
}
