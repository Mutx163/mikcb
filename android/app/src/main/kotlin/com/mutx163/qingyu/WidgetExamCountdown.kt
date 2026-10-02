package com.mutx163.qingyu

import java.time.DateTimeException
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit

/**
 * 桌面小组件「还有 N 天考试」的日历日差。
 *
 * 原来就地写在 `TodayWidgetSupport` 里，用两个本地零点的 `Calendar` 相减再除以
 * `86_400_000`：本地时区实行夏令时的那一天只有 23 小时，82 800 000 / 86 400 000
 * 整除后得 **0**，于是「明天的考试」角标显示成「今天考试」。同一条口径在本仓
 * Dart 侧已经是 `DateTime.utc(...).difference(...).inDays`（WeekCalculator
 * 的 `daysBetween`），这里按 `LocalDate` 对齐（minSdk 26，java.time 可直接用）。
 *
 * 顺带把日期串的解析收进来：原来三处 `parts[0].toInt()` 是裸转，畸形日期会在
 * `RemoteViewsFactory` 里抛 NumberFormatException —— 表现不是少一个角标，而是
 * 整个小组件持续「加载失败」。非法输入现在返回 null，调用方按「没有考试」处理。
 */
internal fun widgetExamDaysUntil(
    dateStr: String,
    nowMillis: Long,
    zoneId: ZoneId = ZoneId.systemDefault(),
): Int? {
    val parts = dateStr.split("-")
    if (parts.size != 3) {
        return null
    }
    val year = parts[0].toIntOrNull() ?: return null
    val month = parts[1].toIntOrNull() ?: return null
    val day = parts[2].toIntOrNull() ?: return null
    val examDate = try {
        LocalDate.of(year, month, day)
    } catch (_: DateTimeException) {
        null
    } ?: return null
    val today = Instant.ofEpochMilli(nowMillis).atZone(zoneId).toLocalDate()
    return ChronoUnit.DAYS.between(today, examDate).coerceAtLeast(0L).toInt()
}
