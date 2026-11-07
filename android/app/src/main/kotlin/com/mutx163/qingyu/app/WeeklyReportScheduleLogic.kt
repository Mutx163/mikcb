package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.statistics.CourseStub
import com.mutx163.qingyu.statistics.StatisticsService
import java.time.DayOfWeek
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * 周报通知的**纯逻辑**：下次触发时刻 + 标题 + 正文（Phase 3.5 · 补齐「周报开关写路径」）。
 *
 * ## 它解决什么
 *
 * Android 侧的 `WeeklyReportScheduler` 只有「持久化入口」：
 * `scheduleNext(context, enabled, fireAtMillis, title, body)`（`:89`）——
 * **它不会自己算**下次什么时候响、通知写什么。Flutter 时代这些值是 Dart 算好后经
 * method channel 传下来的（`MainActivity.kt:1235-1247`）。
 * Compose 侧此前**没有**这层计算 ⇒ 统计设置页的「周报」开关只能接「关」、接不了「开」
 * （伪造 `fireAt`/文案会让用户收到内容错误的周报，比不接更糟）。
 *
 * 本文件把 Dart 那段搬成**可 JVM 直测**的纯逻辑，壳就能把四个参数都算出来。
 *
 * ## 判据出处（逐条对齐 `lib/services/weekly_report_service.dart`，只读）
 *
 * | 本文件 | Dart | 说明 |
 * |---|---|---|
 * | [nextFireAt] | `:23-34` | **每周日 21:00**；若今天就是周日且已过 21:00 ⇒ 顺延一周 |
 * | [buildTitle] | `:36` | `l10n.weeklyReportTitle` |
 * | [buildBody] | `:38-71` | 空课表 ⇒ `weeklyReportBodyEmpty`；否则按本周节数/门数/较上周差值/最忙的一天拼 |
 * | 差值文案 | `:61-63` | `currentWeek <= 1` ⇒ `statisticsComparisonNew`；否则 `delta > 0 ? "+$delta" : "$delta"` |
 * | 星期文案 | `:108-119` | `weekdayShortMonday` … `weekdayShortSunday`；越界退化成数字 |
 *
 * ## 统计数字**不重算**
 *
 * `statistics/StatisticsService` 已交付 `calculate(...)`（本周节数/门数/最忙的一天）与
 * `calculateWeeklyComparison(...)`（较上周差值）⇒ 本文件只**取值 + 拼文案**，
 * 不写第二份统计数学。
 */
object WeeklyReportScheduleLogic {

    /** 推送时刻的小时（Dart `weekly_report_service.dart:20` `_fireHour = 21`）。 */
    const val FIRE_HOUR = 21

    /**
     * 下次触发时刻（本地时间；**若今天已是推送时刻或已过，则顺延一周**）。
     *
     * 逐字对齐 Dart `:23-34`：
     * `daysUntilSunday = (sunday - weekday + 7) % 7`（Dart 里 `sunday == 7`），
     * `fire = 今天 00:00 + daysUntilSunday 天 + 21 小时`，`!fire.isAfter(now)` 就再加 7 天。
     */
    fun nextFireAt(now: LocalDateTime): LocalDateTime {
        val daysUntilSunday = (DayOfWeek.SUNDAY.value - now.dayOfWeek.value + 7) % 7
        var fire = now.toLocalDate().atStartOfDay()
            .plusDays(daysUntilSunday.toLong())
            .withHour(FIRE_HOUR)
        if (!fire.isAfter(now)) {
            fire = fire.plusDays(7)
        }
        return fire
    }

    /** 下次触发时刻的毫秒时间戳（原生 `AlarmManager` 要的形态）。 */
    fun nextFireAtMillis(
        now: LocalDateTime,
        zone: ZoneId = ZoneId.systemDefault(),
    ): Long = nextFireAt(now).atZone(zone).toInstant().toEpochMilli()

    /** 通知标题（Dart `:36`）。 */
    fun buildTitle(): String = WeeklyReportStrings.weeklyReportTitle.text

    /**
     * 通知正文（Dart `:38-71`）。
     *
     * @param courses 全量课程（**不筛**：与 Dart 同口径，内部按本周生效课算）。
     * @param currentWeek 当前周；`<= 1` 时差值位置显示「新学期第一周」。
     * @param semesterWeekCount 学期总周数（比较上周时要用）。
     */
    fun buildBody(
        courses: List<Course>,
        currentWeek: Int,
        semesterWeekCount: Int,
    ): String {
        if (courses.isEmpty()) return WeeklyReportStrings.weeklyReportBodyEmpty.text

        val stubs = courses.map { it.toStatisticsStub() }
        val weekStats = StatisticsService.calculate(stubs, currentWeek)
        val comparison = StatisticsService.calculateWeeklyComparison(
            allCourses = stubs,
            currentWeek = currentWeek,
            semesterWeekCount = semesterWeekCount,
        )

        val busiestLabel = weekStats.busiestDay?.let { weekdayShortLabel(it) }.orEmpty()
        val delta = comparison.deltaVsLastWeek
        val deltaLabel = if (currentWeek <= 1) {
            WeeklyReportStrings.statisticsComparisonNew.text
        } else if (delta > 0) {
            "+$delta"
        } else {
            "$delta"
        }

        return WeeklyReportStrings.weeklyReportBody.filled(
            "week" to currentWeek.toString(),
            "sections" to weekStats.totalSections.toString(),
            "courses" to weekStats.totalCourses.toString(),
            "delta" to deltaLabel,
            "busiestDay" to busiestLabel,
        )
    }

    /** 星期简写（Dart `:108-119`；越界退化成数字，与 Dart 一致）。 */
    fun weekdayShortLabel(dayOfWeek: Int): String = when (dayOfWeek) {
        1 -> WeeklyReportStrings.weekdayShortMonday.text
        2 -> WeeklyReportStrings.weekdayShortTuesday.text
        3 -> WeeklyReportStrings.weekdayShortWednesday.text
        4 -> WeeklyReportStrings.weekdayShortThursday.text
        5 -> WeeklyReportStrings.weekdayShortFriday.text
        6 -> WeeklyReportStrings.weekdayShortSaturday.text
        7 -> WeeklyReportStrings.weekdayShortSunday.text
        else -> dayOfWeek.toString()
    }

    /**
     * `core.Course` → 统计口径 `CourseStub` 的机械换装。
     *
     * ⚠️ **这是本仓第三份同样的换装**（另外两份：`pages/statistics/CourseStatisticsModel.kt:655`
     * 与 `StatsWidgetSnapshotBuilder` 内部那份，两者都是 `private`）⇒ 只能各写一份。
     * **建议**：把它提成 `statistics/` 里的公共扩展函数，三处复用；那是别人的文件，我没改。
     */
    private fun Course.toStatisticsStub(): CourseStub = CourseStub(
        name = name,
        teacher = teacher,
        location = location,
        dayOfWeek = dayOfWeek,
        startSection = startSection,
        endSection = endSection,
        startTime = startTime,
        endTime = endTime,
        startWeek = startWeek,
        endWeek = endWeek,
        isOddWeek = isOddWeek,
        isEvenWeek = isEvenWeek,
        customWeeks = customWeeks,
        suspendedWeeks = suspendedWeeks,
        courseNature = courseNature,
    )
}

/** 周报通知用到的 ARB 文案（`lib/l10n/app_zh.arb`，逐字抄录 + 对拍测试）。 */
typealias WeeklyReportArbText = com.mutx163.qingyu.app.ArbText

object WeeklyReportStrings {

    val weeklyReportTitle = WeeklyReportArbText("weeklyReportTitle", "本周课程小结")
    val weeklyReportBodyEmpty = WeeklyReportArbText("weeklyReportBodyEmpty", "本周暂无课程，好好休息吧")
    val weeklyReportBody = WeeklyReportArbText(
        "weeklyReportBody",
        "第 {week} 周 · 共 {sections} 节 · {courses} 门课\n较上周 {delta} 节\n最忙的一天是 {busiestDay}",
    )
    val statisticsComparisonNew = WeeklyReportArbText("statisticsComparisonNew", "新学期第一周")

    val weekdayShortMonday = WeeklyReportArbText("weekdayShortMonday", "一")
    val weekdayShortTuesday = WeeklyReportArbText("weekdayShortTuesday", "二")
    val weekdayShortWednesday = WeeklyReportArbText("weekdayShortWednesday", "三")
    val weekdayShortThursday = WeeklyReportArbText("weekdayShortThursday", "四")
    val weekdayShortFriday = WeeklyReportArbText("weekdayShortFriday", "五")
    val weekdayShortSaturday = WeeklyReportArbText("weekdayShortSaturday", "六")
    val weekdayShortSunday = WeeklyReportArbText("weekdayShortSunday", "日")

    val allTexts: List<WeeklyReportArbText> = listOf(
        weeklyReportTitle,
        weeklyReportBodyEmpty,
        weeklyReportBody,
        statisticsComparisonNew,
        weekdayShortMonday,
        weekdayShortTuesday,
        weekdayShortWednesday,
        weekdayShortThursday,
        weekdayShortFriday,
        weekdayShortSaturday,
        weekdayShortSunday,
    )
}
