package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.core.WeekCalculator
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.YearMonth

/**
 * 「学期设置」子页（`b.semester`）的**行为判据**，纯 Kotlin、零 Android/Compose 依赖。
 *
 * 页面结构（三行 + 行尾取值）由 [SettingsTimetablePage.semesterSpec] 给；本对象只管
 * 「点了会发生什么」——宿主（composeP1 的 `SettingsSemesterHost`）只负责弹层与调仓储，
 * 取舍全在这里，于是 JVM 单测能把 Dart 侧几条**容易漏掉的分支**钉住：
 *
 * | 分支 | Dart 出处 |
 * |---|---|
 * | 日期弹层初值 `已设 ?: 今天`，范围 2020-01-01 ~ 2035-12-31，越界先夹 | `timetable_settings_screen.dart:764-767` + `miuix_date_picker_sheet.dart:23-56` |
 * | 周数弹层范围 1~30，初值先夹 | `lib/widgets/semester_week_count_picker_sheet.dart:9-23` |
 * | 改开学日期后**立刻**按新日期对齐当前周（不是等用户再点一次） | `:788-791` |
 * | 同步当前周：开学前算第 1 周，超出学期周数钳到末周 | `timetable_provider.dart:3224-3252` |
 * | 周数改小后当前周回拨，且**不给**成功提示 | `:859-861` |
 *
 * ## 为什么周次算法不自己写
 *
 * 开学日 → 周次的唯一口径是 [WeekCalculator.getWeekIndex]（Dart `week_calculator.dart:46-53`）：
 * 先把两端归到所在周周一再按**日历日**相减。自己拿两个 `LocalDateTime` 相减会把
 * 跨夏令时的 1 小时算进去，一年里有两周会少算一周——Dart 侧注释记着这个历史事故，
 * 这里直接复用同一份移植。
 */
object SemesterSettingsLogic {

    /** 开学日期行（`_SemesterSettingsScreen` 第一行）。宿主据此区分三条动作。 */
    const val ROW_START_DATE = "timetable.semester.startDate"

    /** 学期周数行（第二行）。 */
    const val ROW_WEEK_COUNT = "timetable.semester.weekCount"

    /** 同步当前周（第三行，`RUN_NOW`）。 */
    const val ROW_SYNC_WEEK = "timetable.semester.syncWeek"

    /** 日期弹层下界（Dart `firstDate: DateTime(2020)`）。 */
    const val FIRST_YEAR = 2020

    /** 日期弹层上界（Dart `lastDate: DateTime(2035, 12, 31)`）。 */
    const val LAST_YEAR = 2035

    /** 周数滚轮下界（`showSemesterWeekCountPickerSheet` 的 `minValue`）。 */
    const val MIN_WEEK_COUNT = 1

    /** 周数滚轮上界（同上 `maxValue`）。 */
    const val MAX_WEEK_COUNT = 30

    /**
     * 日期弹层展开时的选中值：`已设 ?: 今天`，再夹进 2020-01-01 ~ 2035-12-31。
     *
     * Dart 在 `showMiuixDatePickerSheet` 里做同一件事（`:23-33`）：传进来的 `initialDate`
     * 先只取日期部分，再夹到区间内。**不要**因为「用户不可能拖到 2040」就省掉夹取——
     * 存档里完全可能存在 2036 年的开学日（老版本手改、导入的备份）。
     */
    fun pickerInitialDate(startDate: LocalDate?, today: LocalDate): LocalDate =
        clampPickerDate(startDate ?: today)

    /** 把任意日期夹进 [FIRST_YEAR]-01-01 ~ [LAST_YEAR]-12-31。 */
    fun clampPickerDate(date: LocalDate): LocalDate {
        val first = LocalDate.of(FIRST_YEAR, 1, 1)
        val last = LocalDate.of(LAST_YEAR, 12, 31)
        return when {
            date.isBefore(first) -> first
            date.isAfter(last) -> last
            else -> date
        }
    }

    /** 周数滚轮初值：夹进 1~30（Dart `clampedCurrent`）。 */
    fun pickerInitialWeekCount(count: Int): Int =
        count.coerceIn(MIN_WEEK_COUNT, MAX_WEEK_COUNT)

    /** 某年某月有多少天（滚轮里「日」的上界；同时兜住 2 月 30 日这类越界）。 */
    fun daysInMonth(year: Int, month: Int): Int = YearMonth.of(year, month).lengthOfMonth()

    /** 选定日期落盘用的时刻：**本地零点**（开学日是日历日期，不带时分）。 */
    fun startDateTime(date: LocalDate): LocalDateTime = LocalDateTime.of(date, LocalTime.MIDNIGHT)

    /**
     * 「同步当前周」算出来的周次（Dart `_syncCurrentWeekWithSemesterStartImpl`）。
     *
     * - `getWeekIndex` 返回 null（今天早于开学周）⇒ 按第 1 周；
     * - 超过 `semesterWeekCount` ⇒ 钳到末周（Dart 明确**不**自动扩学期周数，
     *   `:3244-3248` 的注释：日历走出末周时不改 semesterWeekCount）；
     * - `semesterWeekCount < 1` ⇒ 上限按 1（`clampCurrentWeekToSettings` 同口径）。
     */
    fun weekForNow(now: LocalDateTime, semesterStart: LocalDateTime, semesterWeekCount: Int): Int {
        val index = WeekCalculator.getWeekIndex(now, semesterStart) ?: return 1
        return clampWeekTo(index.toInt(), semesterWeekCount)
    }

    /** `< 1` 归 1；`> semesterWeekCount` 归末周；周数本身非法（<1）时上限按 1。 */
    fun clampWeekTo(week: Int, semesterWeekCount: Int): Int {
        val upper = if (semesterWeekCount < 1) 1 else semesterWeekCount
        return when {
            week < 1 -> 1
            week > upper -> upper
            else -> week
        }
    }

    /**
     * 周数改小后**当前周**要不要跟着回拨（Dart `:859-861`：`currentWeek > selected` 才回拨）。
     *
     * 返回 null = 不动。注意这里**刻意不给提示**：Dart 那条分支不弹任何 toast
     * （提示只在同步/改日期两条路径上），宿主不要自作主张补一句。
     */
    fun weekToFollowAfterWeekCountChange(currentWeek: Int, newWeekCount: Int): Int? =
        if (currentWeek > newWeekCount) newWeekCount.coerceAtLeast(MIN_WEEK_COUNT) else null

    /**
     * 仓储快照 → 页面输入（`SettingsTimetableState`）。
     *
     * `semesterStartDate` 在页面 state 里是 `Triple(年, 月, 日)`（渲染层要用它拼
     * `yyyy-MM-dd` 行尾），仓储里是 `LocalDateTime?`，转换只在这一处。
     */
    fun stateOf(
        currentWeek: Int,
        semesterWeekCount: Int,
        startDate: LocalDate?,
    ): SettingsTimetableState = SettingsTimetableState(
        currentWeek = currentWeek,
        semesterWeekCount = semesterWeekCount,
        semesterStartDate = startDate?.let { Triple(it.year, it.monthValue, it.dayOfMonth) },
    )
}
