package com.mutx163.qingyu.core

import java.time.LocalDateTime

/**
 * 周次计算领域服务（移植自 lib/domain/week_calculator.dart，纯逻辑无 IO）。
 *
 * 原实现的教训（注释原文）：
 * - 按**日历日**做加减，而不是按 24 小时的绝对时长——`add(Duration(days: n))`
 *   在实行夏令时的时区里会挪天；`DateTime(y, m, d + n)` 由 Dart 按日历归一。
 *   Kotlin 侧 [LocalDateTime.plusDays] 同为日历归一，语义一致。
 * - `difference().inDays` 数的是**经过的时间**，跨拨快夜 23 小时会被截成 0 天；
 *   所以 daysBetween 用 UTC 日历日差（等价：纯 y/m/d 差值）。
 */
object WeekCalculator {

    /**
     * [from] 到 [to] 的日历日差（同一天为 0，[to] 更早为负）。
     * 对应 Dart `DateTime.utc(to.y,to.m,to.d).difference(DateTime.utc(...)).inDays`。
     */
    fun daysBetween(from: LocalDateTime, to: LocalDateTime): Long {
        val utcFrom = java.time.LocalDate.of(from.year, from.monthValue, from.dayOfMonth)
        val utcTo = java.time.LocalDate.of(to.year, to.monthValue, to.dayOfMonth)
        return java.time.temporal.ChronoUnit.DAYS.between(utcFrom, utcTo)
    }

    /** Dart `WeekCalculator.addDays`：按日历日加，保留时分秒毫秒。 */
    fun addDays(date: LocalDateTime, days: Int): LocalDateTime = date.plusDays(days.toLong())

    /** [date] 归到其所在周的周一 00:00（周一为每周起始日）。 */
    fun startOfWeek(date: LocalDateTime): LocalDateTime {
        val normalizedDate = LocalDateTime.of(
            date.year, date.monthValue, date.dayOfMonth, 0, 0, 0,
        )
        return addDays(normalizedDate, -(normalizedDate.dayOfWeek.value - 1))
    }

    /**
     * [date] 在学期中的周次（从 1 开始），周一为每周起始日。
     * 返回 null 表示 [date] 早于学期开始日期。
     */
    fun getWeekIndex(date: LocalDateTime, semesterStart: LocalDateTime): Long? {
        val diffDays = daysBetween(startOfWeek(semesterStart), startOfWeek(date))
        if (diffDays < 0) return null
        return diffDays / 7 + 1
    }

    /**
     * 教学周次（UI 展示口径，钳制到 [semesterWeekCount]）。
     * 学期未配置返回 [fallback]；开学前一律第 1 周（与 fallback 无关）；
     * 超出学期周数钳到最后一周。
     */
    fun weekForDate(
        date: LocalDateTime,
        semesterStart: LocalDateTime?,
        semesterWeekCount: Int,
        fallback: Int,
    ): Int {
        if (semesterStart == null) return fallback
        val week = getWeekIndex(date, semesterStart) ?: return 1
        if (week > semesterWeekCount) return semesterWeekCount
        return week.toInt()
    }

    /**
     * 真实日历周次，不按 [semesterWeekCount] 钳制（超级岛/小部件口径）。
     * 学期未配置返回 [fallback]；开学前返回 0（避免课程提前显示）。
     */
    fun calendarWeekForDate(
        date: LocalDateTime,
        semesterStart: LocalDateTime?,
        fallback: Int,
    ): Int {
        if (semesterStart == null) return fallback
        val week = getWeekIndex(date, semesterStart) ?: return 0
        return week.toInt()
    }
}
