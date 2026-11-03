package com.mutx163.qingyu.core

import java.time.LocalDateTime
import java.util.Locale

/**
 * 日程条目（移植自 lib/models/schedule_item.dart）。
 *
 * 三条日期键（date/startDate/endDate）一起写，旧 profile/备份 payload 兼容
 * （schedule_item.dart:183-186）。日期一律本地日历日（dateOnly 归一）。
 */
enum class ScheduleRecurrence(val value: String) {
    NONE("none"),
    DAILY("daily"),
    WEEKLY("weekly");

    companion object {
        /**
         * Dart fromValue（schedule_item.dart:19-29）：'daily'/'day' → DAILY、
         * 'weekly'/'week' → WEEKLY，其余（含 null）→ NONE；先 trim 再 lower。
         */
        fun fromValue(raw: Any?): ScheduleRecurrence {
            val value = raw?.toString()?.trim()?.lowercase()
            return when (value) {
                "daily", "day" -> DAILY
                "weekly", "week" -> WEEKLY
                else -> NONE
            }
        }
    }
}

data class ScheduleItem(
    val id: String,
    val title: String,
    val location: String? = null,
    val note: String? = null,
    val startDate: LocalDateTime,
    val endDate: LocalDateTime,
    val startTime: String,
    val endTime: String,
    val color: String = "#5B9CF6",
    val createdAt: LocalDateTime,
    val updatedAt: LocalDateTime,
    val recurrence: ScheduleRecurrence = ScheduleRecurrence.NONE,
    /** 本地日历日去重升序（_normalizeDateList）。 */
    val exceptionDates: List<LocalDateTime> = emptyList(),
    /** 正数才有意义；<=0 与解析失败都是 null（_parseReminderMinutes）。 */
    val reminderMinutesBefore: Long? = null,
    val enabled: Boolean = true,
    /** 仅持久化的一次性改期条目非空（所属系列的 id）。 */
    val seriesId: String? = null,
    /** 系列里被改掉的原日期（override 语义）。 */
    val occurrenceDate: LocalDateTime? = null,
) {
    val isRecurring: Boolean get() = recurrence != ScheduleRecurrence.NONE
    val isSeriesOverride: Boolean get() = seriesId != null
    val seriesRootId: String get() = seriesId ?: id

    fun occursOn(value: LocalDateTime): Boolean {
        val normalizedValue = dateOnly(value)
        if (normalizedValue.isBefore(dateOnly(startDate)) ||
            normalizedValue.isAfter(dateOnly(endDate))
        ) {
            return false
        }
        if (containsDate(exceptionDates, normalizedValue)) return false
        if (isSeriesOverride || recurrence == ScheduleRecurrence.NONE) return true
        return when (recurrence) {
            ScheduleRecurrence.DAILY -> true
            // weekly：星期几相同（java.time dayOfWeek 与 Dart weekday 同为 周一=1）
            ScheduleRecurrence.WEEKLY -> normalizedValue.dayOfWeek == startDate.dayOfWeek
            ScheduleRecurrence.NONE -> true
        }
    }

    fun toJson(): Map<String, Any?> = linkedMapOf(
        "id" to id,
        "title" to title,
        "location" to location,
        "note" to note,
        "date" to DartTime.toIso(dateOnly(startDate)),
        "startDate" to DartTime.toIso(dateOnly(startDate)),
        "endDate" to DartTime.toIso(dateOnly(endDate)),
        "startTime" to startTime,
        "endTime" to endTime,
        "color" to color,
        "createdAt" to DartTime.toIso(createdAt),
        "updatedAt" to DartTime.toIso(updatedAt),
        "recurrence" to recurrence.value,
        "exceptionDates" to exceptionDates.map { formatCalendarDate(it) },
        "seriesId" to seriesId,
        "occurrenceDate" to occurrenceDate?.let { formatCalendarDate(it) },
        "reminderMinutesBefore" to reminderMinutesBefore,
        "enabled" to enabled,
    )

    fun toJsonString(): String = MiniJson.encode(toJson())

    companion object {
        /** 本地零点（schedule_item.dart:454-456）。 */
        fun dateOnly(value: LocalDateTime): LocalDateTime =
            LocalDateTime.of(value.year, value.monthValue, value.dayOfMonth, 0, 0)

        /** `yyyy-MM-dd`（schedule_item.dart:458-464）。 */
        fun formatCalendarDate(value: LocalDateTime): String =
            String.format(Locale.ROOT, "%04d-%02d-%02d", value.year, value.monthValue, value.dayOfMonth)

        /** `seriesId@yyyy-MM-dd`（schedule_item.dart:450-452）。 */
        fun buildOccurrenceId(seriesId: String, date: LocalDateTime): String =
            "$seriesId@${formatCalendarDate(date)}"

        private fun parseReminderMinutes(raw: Any?): Long? {
            val value = when (raw) {
                is Number -> raw.toLong()
                null -> null
                else -> raw.toString().trim().toLongOrNull()
            }
            return if (value != null && value > 0) value else null
        }

        private fun tryParseDate(raw: Any?): LocalDateTime? {
            if (raw is LocalDateTime) return raw
            if (raw == null) return null
            return DartTime.tryParseIso(raw.toString())
        }

        private fun normalizeDateList(dates: List<LocalDateTime>): List<LocalDateTime> {
            val unique = linkedMapOf<String, LocalDateTime>()
            for (date in dates) {
                val normalized = dateOnly(date)
                unique[formatCalendarDate(normalized)] = normalized
            }
            return unique.values.sorted()
        }

        private fun parseDateList(raw: Any?): List<LocalDateTime> {
            if (raw !is List<*>) return emptyList()
            val parsed = mutableListOf<LocalDateTime>()
            for (value in raw) {
                tryParseDate(value)?.let { parsed.add(it) }
            }
            return parsed
        }

        private fun containsDate(dates: List<LocalDateTime>, value: LocalDateTime): Boolean =
            dates.any {
                it.year == value.year && it.monthValue == value.monthValue && it.dayOfMonth == value.dayOfMonth
            }

        /**
         * Dart fromJson（schedule_item.dart:203-273）：id 缺失/空白抛；
         * endDate 缺失回落 startDate；startDate 缺失回落 now；
         * enabled 字符串 'false' 按缺省 true（不猜）。
         */
        fun fromJson(json: Map<String, Any?>): ScheduleItem {
            val now = LocalDateTime.now()

            val rawId = json["id"] ?: throw DartFormatException("ScheduleItem.id is missing")
            val idValue = if (rawId is String) rawId else rawId.toString()
            if (idValue.trim().isEmpty()) throw DartFormatException("ScheduleItem.id is blank")

            fun readStringOrNull(key: String): String? {
                val raw = json[key] ?: return null
                return if (raw is String) raw else raw.toString()
            }

            val legacyDate = tryParseDate(json["date"])
            val parsedStartDate = tryParseDate(json["startDate"])
            val parsedEndDate = tryParseDate(json["endDate"])
            val rawExceptions =
                json["exceptionDates"] ?: json["exceptions"] ?: json["excludedDates"]
            val rawSeriesId = json["seriesId"]?.toString()
            val parsedOccurrenceDate = tryParseDate(json["occurrenceDate"])
            val rawReminder =
                json["reminderMinutesBefore"] ?: json["reminderMinutes"] ?: json["reminder"]

            val resolvedStartDate = dateOnly(parsedStartDate ?: legacyDate ?: now)
            // Dart 构造函数 `_resolveNormalizedEndDate`（schedule_item.dart:468-478）：
            // endDate 早于 startDate 时钳到 startDate，否则 `occursOn` 的区间为空，
            // 且 toJson 会把「end < start」原样写回，与 Dart 的数据越漂越远。
            val resolvedEndCandidate =
                dateOnly(parsedEndDate ?: parsedStartDate ?: legacyDate ?: now)
            val resolvedEndDate =
                if (resolvedEndCandidate.isBefore(resolvedStartDate)) resolvedStartDate
                else resolvedEndCandidate

            return ScheduleItem(
                id = idValue,
                title = readStringOrNull("title") ?: "",
                location = readStringOrNull("location"),
                note = readStringOrNull("note"),
                startDate = resolvedStartDate,
                endDate = resolvedEndDate,
                startTime = readStringOrNull("startTime") ?: "08:00",
                endTime = readStringOrNull("endTime") ?: "09:00",
                color = readStringOrNull("color") ?: "#5B9CF6",
                createdAt = tryParseDate(json["createdAt"]) ?: now,
                updatedAt = tryParseDate(json["updatedAt"]) ?: now,
                recurrence = ScheduleRecurrence.fromValue(
                    json["recurrence"] ?: json["recurrenceRule"] ?: json["repeatRule"]
                        ?: json["repeat"] ?: json["repeatFrequency"],
                ),
                exceptionDates = normalizeDateList(parseDateList(rawExceptions)),
                seriesId = rawSeriesId?.takeIf { it.trim().isNotEmpty() },
                occurrenceDate = parsedOccurrenceDate?.let { dateOnly(it) },
                reminderMinutesBefore = parseReminderMinutes(rawReminder),
                // 字符串 'false' 没有合理真值（不能替用户决定 true/false），按缺省 true。
                enabled = if (json["enabled"] is Boolean) json["enabled"] as Boolean else true,
            )
        }

        fun fromJsonString(text: String): ScheduleItem {
            val decoded = MiniJson.parse(text)
            if (decoded !is Map<*, *>) throw DartFormatException("schedule item json must be an object")
            @Suppress("UNCHECKED_CAST")
            return fromJson(decoded as Map<String, Any?>)
        }
    }
}
