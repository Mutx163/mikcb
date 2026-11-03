package com.mutx163.qingyu.core

import java.time.LocalDateTime
import java.util.Locale

/**
 * 考试模型（移植自 lib/models/exam.dart）。
 *
 * 提醒偏移归一（normalizeReminderOffsets）的历史坑（exam.dart:93-102）：
 * 裸 `as num → toInt()` 让云端写来的 "x" 抛 TypeError、让 0/负数留在列表里，
 * 而考试卡用 `(minutes % 1440) ~/ 60` 算分量，Dart 的 % 恒非负，`-30` 被渲染成
 * 「23 小时 + 30 分钟」——用户看到"会提前提醒"，实际一条通知都不会排。
 */

/** 考试提醒预设（exam.dart:3-40）。 */
enum class ExamReminderPreset(val value: String) {
    NONE("none"),
    MIN_30("min_30"),
    HOUR_1("hour_1"),
    HOUR_1_AND_MIN_30("hour_1_and_min_30"),
    DAY_1("day_1"),
    DAY_1_AND_HOUR_1("day_1_and_hour_1"),
    CUSTOM("custom");

    /** 提醒分钟数列表（custom 返回空——用 customReminderMinutes）。 */
    val reminderMinutes: List<Int>
        get() = when (this) {
            NONE -> emptyList()
            MIN_30 -> listOf(30)
            HOUR_1 -> listOf(60)
            HOUR_1_AND_MIN_30 -> listOf(60, 30)
            DAY_1 -> listOf(1440)
            DAY_1_AND_HOUR_1 -> listOf(1440, 60)
            CUSTOM -> emptyList()
        }

    companion object {
        /** 未知值回落 day1AndHour1（Dart fromValue orElse）。 */
        fun fromValue(value: String?): ExamReminderPreset =
            entries.firstOrNull { it.value == value } ?: DAY_1_AND_HOUR_1
    }
}

data class Exam(
    val id: String,
    val courseId: String,
    val name: String,
    val dateTime: LocalDateTime,
    /** "08:30" 形态，已经 normalizeTimeOfDay 归一。 */
    val startTime: String,
    val endTime: String,
    val location: String? = null,
    val seatNumber: String? = null,
    val note: String? = null,
    val reminderPreset: ExamReminderPreset = ExamReminderPreset.DAY_1_AND_HOUR_1,
    val customReminderMinutes: List<Int> = emptyList(),
    val createdAt: LocalDateTime,
    val updatedAt: LocalDateTime,
) {
    /** 实际的提醒分钟数列表（exam.dart:263-268）。 */
    val effectiveReminderMinutes: List<Int>
        get() = if (reminderPreset == ExamReminderPreset.CUSTOM) {
            customReminderMinutes
        } else {
            reminderPreset.reminderMinutes
        }

    /** 本地墙上时刻的考试开始（dateTime 日期 + startTime）。 */
    val examStartDateTime: LocalDateTime
        get() {
            val (h, m) = parseTimeOfDayParts(startTime)
            return LocalDateTime.of(dateTime.year, dateTime.monthValue, dateTime.dayOfMonth, h, m)
        }

    fun toJson(): Map<String, Any?> = linkedMapOf(
        "id" to id,
        "courseId" to courseId,
        "name" to name,
        "dateTime" to DartTime.toIso(dateTime),
        "startTime" to startTime,
        "endTime" to endTime,
        "location" to location,
        "seatNumber" to seatNumber,
        "note" to note,
        "reminderPreset" to reminderPreset.value,
        "customReminderMinutes" to customReminderMinutes,
        "createdAt" to DartTime.toIso(createdAt),
        "updatedAt" to DartTime.toIso(updatedAt),
    )

    fun toJsonString(): String = MiniJson.encode(toJson())

    companion object {
        /**
         * 归一自定义提醒偏移（exam.dart:103-122）：丢掉非正数与非数值条目，
         * 重复值只留一份（保持先来后到的顺序）。
         */
        fun normalizeReminderOffsets(raw: Any?): List<Int> {
            if (raw !is List<*>) return emptyList()
            val seen = linkedSetOf<Int>()
            for (item in raw) {
                if (item !is Number) continue
                val minutes = item.toInt()
                if (minutes <= 0) continue
                seen.add(minutes)
            }
            return seen.toList()
        }

        /**
         * 自由文本 → `HH:mm`（exam.dart:125-142）。非法回落 [fallback]。
         * 允许 1-2 位小时与分钟（8:5 → 08:05）；hour 0..23、minute 0..59。
         */
        fun normalizeTimeOfDay(raw: String?, fallback: String = "08:30"): String {
            val value = (raw ?: "").trim()
            val m = Regex("""^(\d{1,2}):(\d{1,2})$""").find(value) ?: return fallback
            val hour = m.groupValues[1].toIntOrNull()
            val minute = m.groupValues[2].toIntOrNull()
            if (hour == null || minute == null || hour < 0 || hour > 23 ||
                minute < 0 || minute > 59
            ) {
                return fallback
            }
            return String.format(Locale.ROOT, "%02d:%02d", hour, minute)
        }

        /** 拆分时刻（exam.dart:144-159）；解析失败按 fallback 小时/分钟。 */
        fun parseTimeOfDayParts(
            raw: String,
            fallbackHour: Int = 0,
            fallbackMinute: Int = 0,
        ): Pair<Int, Int> {
            val normalized = normalizeTimeOfDay(
                raw,
                fallback = String.format(Locale.ROOT, "%02d:%02d", fallbackHour, fallbackMinute),
            )
            val parts = normalized.split(":")
            return (parts[0].toIntOrNull() ?: fallbackHour) to
                (parts[1].toIntOrNull() ?: fallbackMinute)
        }

        fun fromJson(json: Map<String, Any?>): Exam {
            val now = LocalDateTime.now()

            fun readRequired(key: String): String {
                val raw = json[key] ?: throw DartFormatException("Exam.$key is missing")
                return if (raw is String) raw else raw.toString()
            }

            fun readStr(key: String, fallback: String = ""): String {
                val raw = json[key]
                if (raw is String) return raw
                return if (raw == null) fallback else raw.toString()
            }

            fun readStrOrNull(key: String): String? {
                val raw = json[key] ?: return null
                return if (raw is String) raw else raw.toString()
            }

            return Exam(
                id = readRequired("id"),
                courseId = readRequired("courseId"),
                name = readStr("name"),
                dateTime = DartTime.tryParseIso(readStr("dateTime")) ?: now,
                startTime = normalizeTimeOfDay(readStrOrNull("startTime")),
                endTime = normalizeTimeOfDay(readStrOrNull("endTime"), fallback = "10:30"),
                location = readStrOrNull("location"),
                seatNumber = readStrOrNull("seatNumber"),
                note = readStrOrNull("note"),
                reminderPreset = ExamReminderPreset.fromValue(readStrOrNull("reminderPreset")),
                customReminderMinutes = normalizeReminderOffsets(json["customReminderMinutes"]),
                createdAt = DartTime.tryParseIso(readStr("createdAt")) ?: now,
                updatedAt = DartTime.tryParseIso(readStr("updatedAt")) ?: now,
            )
        }

        fun fromJsonString(text: String): Exam {
            val decoded = MiniJson.parse(text)
            if (decoded !is Map<*, *>) throw DartFormatException("exam json must be an object")
            @Suppress("UNCHECKED_CAST")
            return fromJson(decoded as Map<String, Any?>)
        }

        /** 稳定的时序排序（exam.dart:283-297）：开始时刻 → 结束时刻 → id。 */
        fun compareByStart(left: Exam, right: Exam): Int {
            val startCompare = left.examStartDateTime.compareTo(right.examStartDateTime)
            if (startCompare != 0) return startCompare
            val leftEnd = dateTimeWithTime(left.dateTime, left.endTime)
            val rightEnd = dateTimeWithTime(right.dateTime, right.endTime)
            val endCompare = leftEnd.compareTo(rightEnd)
            if (endCompare != 0) return endCompare
            return left.id.compareTo(right.id)
        }

        private fun dateTimeWithTime(date: LocalDateTime, rawTime: String): LocalDateTime {
            val (h, m) = parseTimeOfDayParts(rawTime, fallbackHour = 23, fallbackMinute = 59)
            return LocalDateTime.of(date.year, date.monthValue, date.dayOfMonth, h, m)
        }
    }
}
