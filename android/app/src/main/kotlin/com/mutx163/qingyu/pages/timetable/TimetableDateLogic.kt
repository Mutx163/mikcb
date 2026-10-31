package com.mutx163.qingyu.pages.timetable

import java.time.LocalDate
import java.time.temporal.ChronoUnit

/**
 * 课表「周次 ↔ 日期」换算（模型层唯一实现）。
 *
 * ## 为什么从渲染层搬出来
 *
 * 2026-10-29 二轮审核发现：`dateForWeekDay` / `currentSemesterWeek` 原本写在
 * `composeP1/…/TimetableWeekPage.kt` 里（渲染层），而 **模型层**（日视图装配器、
 * 考试过期判定）也要用同一套判据。两边各写一份必然漂移——Dart 侧就是唯一实现
 * （`lib/screens/timetable_screen.dart:_dateForWeekDay` /
 * `_resolveCurrentSemesterWeek` 都收敛在 State 上，`flight_agenda_extra_lines.dart`
 * 里那份也只是转发）。
 *
 * 这里放纯函数版本：渲染层的同名函数改为**委托**，行为不变，但只有一份判据。
 *
 * ## 与 Dart 的逐条对应
 *
 * | 这里 | Dart |
 * |---|---|
 * | [dateForWeekDay] | `timetable_weekday_header.dart:_dateForWeekDay`（`:57-75`） |
 * | [currentSemesterWeek] | `timetable_screen.dart:_resolveCurrentSemesterWeek`（`:1392-1420`） |
 */
object TimetableDateLogic {

    /**
     * 某一周某一天对应的日历日期。
     *
     * 学期起始日先**归一化到周一**（`start - (start.dayOfWeek.value - 1)`），
     * 再按「第几周 / 星期几」偏移——Dart 同样先归一化，否则学期从周三开始时
     * 整个网格的日期会整体偏两天。
     *
     * @return 学期起始日未设置 ⇒ `null`（调用方按「日期未知」处理：不写日期文本、
     *   不判「今天」。Dart 同样返回 null）
     */
    fun dateForWeekDay(semesterStart: LocalDate?, week: Int, dayOfWeek: Int): LocalDate? {
        val start = semesterStart ?: return null
        val monday = mondayOf(start)
        return monday.plusDays(((week - 1) * 7 + (dayOfWeek - 1)).toLong())
    }

    /**
     * 按开学日算出的「真实当前周」。
     *
     * 对齐 Dart `_resolveCurrentSemesterWeek`：开学日归一化到周一 →
     * `(今天 - 周一) / 7 + 1`；**越界（< 1 或 > totalWeeks）返回 null**，
     * 调用方据此决定「回本周」浮钮是否出现（学期没配 / 放假中就不出现）。
     */
    fun currentSemesterWeek(semesterStart: LocalDate?, totalWeeks: Int, today: LocalDate): Int? {
        val start = semesterStart ?: return null
        val monday = mondayOf(start)
        val days = ChronoUnit.DAYS.between(monday, today)
        val week = (days / 7).toInt() + 1
        if (week < 1 || week > totalWeeks) return null
        return week
    }

    /**
     * 没有开学日时的**兜底日期**：按「当前查看的周」把星期几映射到今天所在的那一周。
     *
     * Dart `_resolveDisplayDateForWeekDay`（`timetable_day_view_part.dart:340-355`）：
     * 算不出日期时不让日程 / 考试 / 待办整块消失，而是
     * `today + ((week - visibleWeek) * 7 + dayOfWeek - today.weekday)`。
     * 日视图落定后 `visibleWeek == 这一页的 week`，所以对正在看的那一页就是
     * 「今天所在这一周的星期 X」；相邻页（滑动中才挂载）按 [referenceWeek] 偏移。
     *
     * @param referenceWeek 参照周（Dart `_visibleWeek`）。默认取 [week] 本身，
     *   与 Dart「落定页 = 当前查看周」的口径一致。
     */
    fun fallbackDateForViewedWeek(
        week: Int,
        dayOfWeek: Int,
        today: LocalDate,
        referenceWeek: Int = week,
    ): LocalDate {
        val dayDelta = (week - referenceWeek) * 7L + (dayOfWeek - today.dayOfWeek.value)
        return today.plusDays(dayDelta)
    }

    /** 该日期所在周的周一（Dart `start.subtract(Duration(days: start.weekday - 1))`）。 */
    fun mondayOf(date: LocalDate): LocalDate =
        date.minusDays((date.dayOfWeek.value - 1).toLong())
}