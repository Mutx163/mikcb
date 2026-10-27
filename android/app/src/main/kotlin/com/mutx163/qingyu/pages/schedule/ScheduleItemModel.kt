package com.mutx163.qingyu.pages.schedule

import java.time.DayOfWeek
import java.time.LocalDate
import java.time.format.DateTimeFormatter

/**
 * 重复规则枚举（移植 `lib/models/schedule_item.dart` 的 `ScheduleRecurrence`）。
 */
enum class ScheduleRecurrence(val value: String) {
    NONE("none"),
    DAILY("daily"),
    WEEKLY("weekly");

    companion object {
        fun fromValue(raw: Any?): ScheduleRecurrence {
            if (raw is ScheduleRecurrence) return raw
            val str = raw?.toString()?.trim()?.lowercase() ?: return NONE
            return when (str) {
                "daily", "day" -> DAILY
                "weekly", "week" -> WEEKLY
                else -> NONE
            }
        }
    }
}

/**
 * 日程条目数据模型（移植 `lib/models/schedule_item.dart` 的 `ScheduleItem`，纯数据层）。
 *
 * 日期统一采用 `yyyy-MM-dd` 本地日历格式，时刻采用 `HH:mm` 24小时制。
 */
data class ScheduleItemData(
    val id: String,
    val title: String,
    val location: String? = null,
    val note: String? = null,
    val startDate: String,
    val endDate: String = startDate,
    val startTime: String,
    val endTime: String,
    val color: String = "#5B9CF6",
    val createdAt: String = "",
    val updatedAt: String = "",
    val recurrence: ScheduleRecurrence = ScheduleRecurrence.NONE,
    val exceptionDates: List<String> = emptyList(),
    val reminderMinutesBefore: Int? = null,
    val enabled: Boolean = true,
    val seriesId: String? = null,
    val occurrenceDate: String? = null,
) {
    val isRecurring: Boolean
        get() = recurrence != ScheduleRecurrence.NONE

    val isSeriesOverride: Boolean
        get() = seriesId != null

    val seriesRootId: String
        get() = seriesId ?: id

    /**
     * 判断指定日期 [dateIso] 是否命中该日程（移植 `ScheduleItem.occursOn`）。
     */
    fun occursOn(dateIso: String): Boolean {
        if (dateIso in exceptionDates) return false
        if (dateIso < startDate || dateIso > endDate) return false
        return when (recurrence) {
            ScheduleRecurrence.NONE -> true
            ScheduleRecurrence.DAILY -> true
            ScheduleRecurrence.WEEKLY -> {
                val startDayOfWeek = ScheduleDateUtils.dayOfWeek(startDate)
                val targetDayOfWeek = ScheduleDateUtils.dayOfWeek(dateIso)
                startDayOfWeek == targetDayOfWeek
            }
        }
    }
}

/**
 * 日程日期与时间计算纯函数工具集。
 */
object ScheduleDateUtils {

    private val isoDatePattern = Regex("""^\d{4}-\d{2}-\d{2}$""")
    private val formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd")

    fun isValidIsoDate(raw: String?): Boolean {
        if (raw == null || !isoDatePattern.matches(raw.trim())) return false
        return parseDate(raw) != null
    }

    fun parseDate(raw: String?): LocalDate? {
        if (raw == null) return null
        val trimmed = raw.trim()
        if (!isoDatePattern.matches(trimmed)) return null
        val parts = trimmed.split("-")
        val year = parts[0].toIntOrNull() ?: return null
        val month = parts[1].toIntOrNull() ?: return null
        val day = parts[2].toIntOrNull() ?: return null
        return try {
            LocalDate.of(year, month, day)
        } catch (_: Exception) {
            null
        }
    }

    fun formatDate(date: LocalDate): String = date.format(formatter)

    /**
     * 计算该日期的星期几（1 = 周一, ..., 7 = 周日，与 Dart [DateTime.weekday] 一致）。
     */
    fun dayOfWeek(dateIso: String): Int {
        val date = parseDate(dateIso) ?: return 1
        return date.dayOfWeek.value // 1 (Monday) to 7 (Sunday)
    }

    /**
     * 将 `HH:mm` 转换为 0..1439 的分钟数，解析失败返回 0。
     */
    fun parseMinutes(clock: String): Int {
        val parts = clock.trim().split(":")
        if (parts.size != 2) return 0
        val hour = parts[0].toIntOrNull() ?: return 0
        val minute = parts[1].toIntOrNull() ?: return 0
        if (hour < 0 || hour >= 24 || minute < 0 || minute >= 60) return 0
        return hour * 60 + minute
    }

    /**
     * 将 0..1439 分钟数转换为 `HH:mm` 格式。
     */
    fun formatMinutes(totalMinutes: Int): String {
        val clamped = totalMinutes.coerceIn(0, 1439)
        val hour = clamped / 60
        val minute = clamped % 60
        return "%02d:%02d".format(hour, minute)
    }

    /**
     * 按时钟时刻比对两个时间文本（分钟数序，等价 Dart `compareClockText`）。
     */
    fun compareClockText(left: String, right: String): Int {
        val leftMinutes = parseMinutes(left)
        val rightMinutes = parseMinutes(right)
        return leftMinutes.compareTo(rightMinutes)
    }

    /**
     * 是否是跨天的单次日程。
     */
    fun isCrossDayRange(item: ScheduleItemData): Boolean {
        return !item.isRecurring && item.endDate > item.startDate
    }

    fun buildOccurrenceId(sourceItemId: String, occurrenceDate: String): String =
        "$sourceItemId#$occurrenceDate"
}
