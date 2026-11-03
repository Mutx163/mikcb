package com.mutx163.qingyu.core

import java.time.LocalDateTime
import java.util.Locale

/**
 * 节次时间与时间模板（移植自 lib/models/settings/timetable_settings_live.dart
 * 的 SectionTime 与 lib/models/time_scheme.dart 的 TimeScheme）。
 *
 * ## SectionTime.parseListAligned 为什么必须「坏条目补位而不是跳过」
 *
 * 本课程把 `Course.startSection` 当作节次表的**位置下标**使用
 * （time_scheme_logic 的 sections[startIndex]）：跳过一条坏记录会让它之后
 * 的每一节全部指向相邻后一节的时间（12 节模板丢第 4 节 → 第 4 节起每门课
 * 显示后一节的时间）。补位值优先取 fallbackTemplate 的同位节次（懒取），
 * 越界则留空时间（作息页渲染为 `-`）。
 *
 * ## validateSectionTimes 与 24:00
 *
 * `_clockMinutes` 允许 `24:00`（「当天结束」的合法写法）：hour==24 时 minute
 * 必须为 0，其余 hour 走 0..23。范围守卫缺失时 `25:00-26:00` 这种墙上不存在的
 * 节次也能落库并被应用（历史事故：课表有这一节、时间对不上、永远不通知）。
 */

/** 单节时间（timetable_settings_live.dart:174-244）。 */
data class SectionTime(
    val startTime: String,
    val endTime: String,
) {
    val displayText: String get() = "$startTime-$endTime"

    fun toJson(): Map<String, Any?> = linkedMapOf("startTime" to startTime, "endTime" to endTime)

    companion object {
        const val EMPTY = "empty placeholder section"

        fun fromJson(json: Map<*, *>): SectionTime {
            val rawStart = json["startTime"]
            val rawEnd = json["endTime"]
            if (rawStart !is String || rawStart.trim().isEmpty()) {
                throw DartFormatException("missing section startTime")
            }
            if (rawEnd !is String || rawEnd.trim().isEmpty()) {
                throw DartFormatException("missing section endTime")
            }
            return SectionTime(rawStart, rawEnd)
        }

        /**
         * 逐条解析节次表，坏条目**按位补位**而不是跳过（timetable_settings_live.dart:221-244）。
         *
         * 返回 (sections, healedCount)；healedCount == sections.size 表示整表皆坏
         * （调用方没有位置信息可对齐，只能整套回落内置模板）。
         */
        fun parseListAligned(
            rawSections: List<*>,
            fallbackTemplate: () -> List<SectionTime>,
        ): Pair<List<SectionTime>, Int> {
            val parsed = mutableListOf<SectionTime>()
            var healedCount = 0
            for ((index, item) in rawSections.withIndex()) {
                val section = try {
                    if (item !is Map<*, *>) throw DartFormatException("section entry is not a map")
                    SectionTime.fromJson(item)
                } catch (_: Exception) {
                    healedCount++
                    val template = fallbackTemplate()
                    if (index < template.size) template[index] else SectionTime("", "")
                }
                parsed.add(section)
            }
            return parsed to healedCount
        }
    }
}

/** 时间模板（time_scheme.dart:7-84）。 */
data class TimeScheme(
    val id: String,
    val name: String,
    val sections: List<SectionTime>,
    val createdAt: LocalDateTime,
    val updatedAt: LocalDateTime,
) {
    val sectionCount: Int get() = sections.size

    fun toJson(): Map<String, Any?> = linkedMapOf(
        "id" to id,
        "name" to name,
        "sections" to sections.map { it.toJson() },
        "createdAt" to DartTime.toIso(createdAt),
        "updatedAt" to DartTime.toIso(updatedAt),
    )

    fun toJsonString(): String = MiniJson.encode(toJson())

    companion object {
        const val DEFAULT_NAME = "未命名时间模板"

        fun fromJson(json: Map<String, Any?>): TimeScheme {
            val rawId = json["id"]
            if (rawId !is String || rawId.trim().isEmpty()) {
                throw DartFormatException("missing time scheme id")
            }
            val rawSections = json["sections"] as? List<*> ?: emptyList<Any?>()
            // 坏条目按位补空，不能让后面的节次前移（位置下标契约）。
            // 刻意不拿内置默认模板补位——用户自定义作息的空格若填进别校的铃点，
            // 会变成「看着合理其实全错」；留空才能被作息管理页发现。
            val (sections, _) = SectionTime.parseListAligned(rawSections) { emptyList() }
            return TimeScheme(
                id = rawId,
                name = json["name"] as? String ?: DEFAULT_NAME,
                sections = sections,
                createdAt = DartTime.tryParseIso(json["createdAt"] as? String)
                    ?: LocalDateTime.now(),
                updatedAt = DartTime.tryParseIso(json["updatedAt"] as? String)
                    ?: LocalDateTime.now(),
            )
        }

        fun fromJsonString(text: String): TimeScheme {
            val decoded = MiniJson.parse(text)
            if (decoded !is Map<*, *>) throw DartFormatException("time scheme json must be an object")
            @Suppress("UNCHECKED_CAST")
            return fromJson(decoded as Map<String, Any?>)
        }
    }
}

/** 休息覆盖规则（time_scheme.dart:86-94）。 */
data class BreakOverrideRule(
    val afterSection: Int,
    val breakDurationMinutes: Int,
)

/** Dart encodeServiceMessage 的本族子集：`code` 或 `code|key=value|...`。 */
object ServiceMessage {
    const val SEPARATOR = "|"

    fun encode(code: String, args: Map<String, Any?> = emptyMap()): String {
        if (args.isEmpty()) return code
        val parts = mutableListOf(code)
        for ((k, v) in args) parts.add("$k=$v")
        return parts.joinToString(SEPARATOR)
    }
}

/**
 * 节次表校验（time_scheme.dart:96-139）。
 *
 * 整条空（`SectionTime("","")`）是本仓认可的**补位形状**，校验必须放过它；
 * 半空（只填一半）是真错误，走 clockMinutes 抛错。
 */
fun validateSectionTimes(sections: List<SectionTime>): String? {
    if (sections.isEmpty()) {
        return "at_least_one_section_required"
    }
    var previousEndMinutes = -1
    var usableCount = 0
    for ((index, section) in sections.withIndex()) {
        if (section.startTime.trim().isEmpty() && section.endTime.trim().isEmpty()) {
            continue
        }
        val startMinutes = clockMinutes(section.startTime)
        val endMinutes = clockMinutes(section.endTime)
        usableCount++
        if (endMinutes <= startMinutes) {
            return ServiceMessage.encode(
                "section_end_must_after_start",
                linkedMapOf("sectionNumber" to (index + 1)),
            )
        }
        if (previousEndMinutes >= 0 && startMinutes < previousEndMinutes) {
            return ServiceMessage.encode(
                "section_start_before_previous_end",
                linkedMapOf("sectionNumber" to (index + 1)),
            )
        }
        previousEndMinutes = endMinutes
    }
    // 全是占位 = 没有可用的节次表。
    if (usableCount == 0) {
        return "at_least_one_section_required"
    }
    return null
}

/**
 * 单节时间的跨天判定（time_scheme.dart:153-166）。
 *
 * 结束必须**严格**晚于开始；`24:00` 按 1440 计（当天结束）。
 * 解析不出来的串按 0 分钟处理（畸形存量值不在这里猜语义）。
 */
fun isSectionTimeSpanValid(startTime: String, endTime: String): Boolean {
    fun minutesOrZero(value: String): Int =
        try {
            clockMinutes(value)
        } catch (_: Exception) {
            0
        }
    return minutesOrZero(endTime) > minutesOrZero(startTime)
}

/**
 * 快速生成节次表（time_scheme.dart:168-237）。任一参数非法即抛
 * DartFormatException（消息与 Dart FormatException.message 逐字一致）。
 */
fun buildQuickSectionTimes(
    morningCount: Int,
    afternoonCount: Int,
    eveningCount: Int,
    morningStartTime: String?,
    afternoonStartTime: String?,
    eveningStartTime: String?,
    classDurationMinutes: Int,
    breakDurationMinutes: Int,
    breakOverrideRules: List<BreakOverrideRule> = emptyList(),
): List<SectionTime> {
    if (classDurationMinutes <= 0) {
        throw DartFormatException("class_duration_must_positive")
    }
    if (breakDurationMinutes < 0) {
        throw DartFormatException("break_duration_must_non_negative")
    }

    val sections = mutableListOf<SectionTime>()
    var sectionNumber = 1
    val overrides = linkedMapOf<Int, Int>()
    for (rule in breakOverrideRules) overrides[rule.afterSection] = rule.breakDurationMinutes

    fun appendPeriod(count: Int, startTime: String?) {
        if (count <= 0) return
        if (startTime.isNullOrEmpty()) {
            throw DartFormatException("period_start_time_required")
        }
        var currentStartMinutes = clockMinutes(startTime)
        repeat(count) {
            val currentEndMinutes = currentStartMinutes + classDurationMinutes
            if (currentEndMinutes > 24 * 60) {
                throw DartFormatException(
                    ServiceMessage.encode(
                        "section_crosses_midnight",
                        linkedMapOf("sectionNumber" to sectionNumber),
                    ),
                )
            }
            sections.add(
                SectionTime(
                    startTime = minutesToClock(currentStartMinutes),
                    endTime = minutesToClock(currentEndMinutes),
                ),
            )
            val breakMinutes = overrides[sectionNumber] ?: breakDurationMinutes
            currentStartMinutes = currentEndMinutes + breakMinutes
            sectionNumber += 1
        }
    }

    appendPeriod(morningCount, morningStartTime)
    appendPeriod(afternoonCount, afternoonStartTime)
    appendPeriod(eveningCount, eveningStartTime)

    if (sections.isEmpty()) {
        throw DartFormatException("at_least_one_period_section")
    }

    validateSectionTimes(sections)?.let { throw DartFormatException(it) }
    return sections
}

/**
 * `_clockMinutes`（time_scheme.dart:239-261）：`HH:mm` → 当天分钟数。
 *
 * - 段数必须为 2、两段都是数字；
 * - minute 0..59；hour 0..23，**24:00 例外放行**（minute 必须为 0）；
 * - 违规抛 DartFormatException("invalid_time_format")。
 */
fun clockMinutes(value: String): Int {
    val parts = value.split(":")
    if (parts.size != 2) {
        throw DartFormatException("invalid_time_format")
    }
    val hour = parts[0].toIntOrNull()
    val minute = parts[1].toIntOrNull()
    if (hour == null || minute == null) {
        throw DartFormatException("invalid_time_format")
    }
    val inRange =
        minute in 0..59 &&
            (if (hour == 24) minute == 0 else hour in 0..23)
    if (!inRange) {
        throw DartFormatException("invalid_time_format")
    }
    return hour * 60 + minute
}

/**
 * `_minutesToClock`（time_scheme.dart:263-277）。1440 必须写成 "24:00"，
 * 不能被 % 1440 回绕成 "00:00"（22:00 起单节 120 分钟的场景靠它存得进去）。
 */
fun minutesToClock(minutes: Int): String {
    if (minutes == 24 * 60) {
        return "24:00"
    }
    val normalized = minutes % (24 * 60)
    val hour = normalized / 60
    val minute = normalized % 60
    return String.format(Locale.ROOT, "%02d:%02d", hour, minute)
}
