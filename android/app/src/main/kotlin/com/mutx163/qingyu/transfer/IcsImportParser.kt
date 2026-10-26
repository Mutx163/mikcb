package com.mutx163.qingyu.transfer

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.WeekCalculator
import java.time.LocalDateTime

/**
 * ICS 导入解析（移植自 lib/services/ics_import_service.dart 的纯解析部分，
 * 2026-10-26 快照）。
 *
 * 触文件系统/HTTP 的部分（maxFileBytes 预算、文件读取）不移植；
 * `DateTime.now()` 兜底由调用方经 [IcsImportParser.parseWakeUpSchedule]
 * 的 [now] 参数注入（Dart 侧直接调 DateTime.now()，属 IO 时钟）。
 *
 * **时区语义**：Dart 的 `DateTime.utc(...).toLocal()` 是瞬时换算到本机时区；
 * Kotlin 侧用 ZonedDateTime 完成同样的换算。期望值依赖宿主时区的用例
 * （UTC 转本地那条）不在端口测试里抄录，用非 Z 后缀（本地语义）的用例对拍。
 */
object IcsImportParser {

    /** RFC 5545 里值为 TEXT 类型的属性——只有这些需要反转义。 */
    private val ICS_TEXT_PROPERTIES = setOf(
        "SUMMARY", "DESCRIPTION", "LOCATION", "CATEGORIES", "COMMENT",
    )

    /** 导入结果（ics_import_service.dart:4-9）。 */
    data class IcsImportResult(
        val courses: List<Course>,
        val semesterStart: LocalDateTime,
    )

    /**
     * WakeUp 课程表导入主入口（ics_import_service.dart:28-62）。
     * 无事件或全部 DTSTART 解析失败 → 空课程 + [now] 兜底学期开始日。
     */
    fun parseWakeUpSchedule(content: String, now: LocalDateTime): IcsImportResult {
        val events = parseEvents(content)
        if (events.isEmpty()) {
            return IcsImportResult(emptyList(), now)
        }

        val startDates = events.mapNotNull { parseLocalDateTime(it["DTSTART"]) }.sorted()
        if (startDates.isEmpty()) {
            return IcsImportResult(emptyList(), now)
        }

        val semesterStart = WeekCalculator.startOfWeek(startDates.first())
        val rawCourses = mutableListOf<Course>()
        for ((index, event) in events.withIndex()) {
            buildCourseFromEvent(event, semesterStart, index)?.let { rawCourses.add(it) }
        }
        return IcsImportResult(mergeAlternatingWeekCourses(rawCourses), semesterStart)
    }

    /** 事件拆分（ics_import_service.dart:64-119）。 */
    private fun parseEvents(content: String): List<Map<String, String>> {
        val unfoldedLines = unfoldLines(content)
        val events = mutableListOf<Map<String, String>>()
        var currentEvent: LinkedHashMap<String, String>? = null
        var inAlarm = false

        for (rawLine in unfoldedLines) {
            val line = rawLine.trim()
            if (line == "BEGIN:VEVENT") {
                currentEvent = LinkedHashMap()
                inAlarm = false
                continue
            }
            if (line == "END:VEVENT") {
                currentEvent?.let { events.add(it) }
                currentEvent = null
                inAlarm = false
                continue
            }
            if (currentEvent == null) continue
            if (line == "BEGIN:VALARM") {
                inAlarm = true
                continue
            }
            if (line == "END:VALARM") {
                inAlarm = false
                continue
            }
            if (inAlarm || !line.contains(':')) continue

            val separatorIndex = line.indexOf(':')
            val rawKey = line.substring(0, separatorIndex)
            val key = rawKey.split(";").first()
            val value = line.substring(separatorIndex + 1)
            // putIfAbsent：首个同名键胜出（Dart 同口径）。
            currentEvent.putIfAbsent(
                key,
                // 只对文本类属性反转义：DTSTART/RRULE 的值自带冒号与分号，
                // 全局反转义会把它们改坏。
                if (key in ICS_TEXT_PROPERTIES) unescapeIcsText(value) else value,
            )
        }
        return events
    }

    /** 折行还原（ics_import_service.dart:157-172）：空格/Tab 起头的行接回上一行。 */
    fun unfoldLines(content: String): List<String> {
        val normalized = content.replace("\r\n", "\n")
        val lines = normalized.split("\n")
        val unfolded = mutableListOf<String>()
        for (line in lines) {
            if ((line.startsWith(" ") || line.startsWith("\t")) && unfolded.isNotEmpty()) {
                unfolded[unfolded.size - 1] = unfolded[unfolded.size - 1] + line.substring(1)
            } else {
                unfolded.add(line)
            }
        }
        return unfolded
    }

    /** 单事件 → Course（ics_import_service.dart:174-292）。 */
    private fun buildCourseFromEvent(
        event: Map<String, String>,
        semesterStart: LocalDateTime,
        index: Int,
    ): Course? {
        val summary = event["SUMMARY"] ?: return null
        val description = event["DESCRIPTION"] ?: return null
        val startDateTime = parseLocalDateTime(event["DTSTART"]) ?: return null
        val endDateTime = parseLocalDateTime(event["DTEND"]) ?: return null

        // `\n` 已在 parseEvents 由 unescapeIcsText 还原成真换行，这里不能再
        // replaceAll 一次（`\\n` 是合法的字面内容）。
        val descriptionLines = description
            .split("\n")
            .map { it.trim() }
            .filter { it.isNotEmpty() }
        if (descriptionLines.isEmpty()) return null

        val sectionMatch = Regex("""第\s*(\d+)\s*-\s*(\d+)\s*节""")
            .find(descriptionLines[0]) ?: return null
        val startSection = sectionMatch.groupValues[1].toIntOrNull() ?: return null
        val endSection = sectionMatch.groupValues[2].toIntOrNull() ?: return null
        val hasStructuredLocation = descriptionLines.size >= 2

        // ICS DESCRIPTION 在第 0 行（节次）之后有两种已知排布：
        //   格式 A：第 1 行=教室、第 2 行=教师（默认）
        //   格式 B：第 1 行=教师、第 2 行=教室
        // 用事件自带的 LOCATION 字段当裁决：哪一行与它互含，哪一行就是教室。
        val rawLocation: String
        val teacher: String
        if (!hasStructuredLocation) {
            rawLocation = event["LOCATION"] ?: ""
            teacher = extractTeacherFromCombinedLocation(rawLocation)
        } else if (descriptionLines.size < 3) {
            // 只有一行附加信息——教室取该行，教师回落 LOCATION 字段。
            rawLocation = descriptionLines[1]
            teacher = extractTeacherFromCombinedLocation(event["LOCATION"] ?: "")
        } else {
            val icsLocation = (event["LOCATION"] ?: "").trim()
            val line1 = descriptionLines[1].trim()
            val line2 = descriptionLines[2].trim()
            val line1MatchesLocation = icsLocation.isNotEmpty() &&
                (line1.contains(icsLocation) || icsLocation.contains(line1))
            val line2MatchesLocation = icsLocation.isNotEmpty() &&
                (line2.contains(icsLocation) || icsLocation.contains(line2))
            if (line2MatchesLocation && !line1MatchesLocation) {
                // 格式 B
                teacher = line1
                rawLocation = line2
            } else {
                // 格式 A（默认）
                rawLocation = line1
                teacher = line2
            }
        }

        val rawStartWeek = weekIndex(startDateTime, semesterStart)
        val rawEndWeek = parseEndWeek(event["RRULE"], semesterStart, startDateTime)
            ?: rawStartWeek
        // 钳到 1..30（与 Course.fromJson 的 normalizeWeeks 同口径）：
        // UNTIL=99991231 这类恶意值会解析出几十万周，把导入过程内存打爆。
        val clamped = Course.normalizeWeeks(rawStartWeek, rawEndWeek)
        val startWeek = clamped.first
        val endWeek = clamped.second
        val weeklyInterval = parseWeeklyInterval(event["RRULE"] ?: "")
        // INTERVAL=2 表示隔周上课；单双周由首周奇偶决定。
        val isBiweekly = weeklyInterval == 2
        val isOddWeek = isBiweekly && startWeek % 2 == 1
        val isEvenWeek = isBiweekly && startWeek % 2 == 0

        return Course(
            id = "ics-${toEpochMilli(startDateTime)}-$index",
            name = cleanSummary(summary),
            teacher = teacher,
            location = if (hasStructuredLocation) {
                rawLocation.trim()
            } else {
                extractLocationFromCombinedField(rawLocation)
            },
            dayOfWeek = startDateTime.dayOfWeek.value,
            startSection = startSection,
            endSection = endSection,
            startTime = formatTime(startDateTime),
            endTime = formatTime(endDateTime),
            startWeek = startWeek,
            endWeek = endWeek,
            isOddWeek = isOddWeek,
            isEvenWeek = isEvenWeek,
        )
    }

    /** 摘要清洗（ics_import_service.dart:294-296）：去 WakeUp 的 `[16][必修]` 尾巴。 */
    fun cleanSummary(summary: String): String =
        summary.replaceFirst(Regex("""\[\d+\]\[[^\]]+\]$"""), "").trim()

    /** 单周碎片合并（ics_import_service.dart:298-372）。 */
    private fun mergeAlternatingWeekCourses(courses: List<Course>): List<Course> {
        val grouped = LinkedHashMap<String, MutableList<Course>>()
        for (course in courses) {
            grouped.getOrPut(courseMergeKey(course)) { mutableListOf() }.add(course)
        }

        val mergedCourses = mutableListOf<Course>()
        for (entry in grouped) {
            val mergedFlags = mutableSetOf<String>()
            val group = entry.value.toMutableList()
            group.sortWith { left, right ->
                val weekCompare = left.startWeek.compareTo(right.startWeek)
                if (weekCompare != 0) weekCompare else left.id.compareTo(right.id)
            }

            for (i in group.indices) {
                val current = group[i]
                if (current.id in mergedFlags) continue

                val run = mutableListOf(current)
                for (j in i + 1 until group.size) {
                    val candidate = group[j]
                    if (candidate.id in mergedFlags) continue
                    val previous = run.last()
                    if (!isSingleWeekCourse(previous) || !isSingleWeekCourse(candidate)) break
                    if (candidate.startWeek - previous.startWeek != 2) break
                    if (candidate.startWeek % 2 != current.startWeek % 2) break
                    run.add(candidate)
                }

                if (run.size >= 2 && run.all { isSingleWeekCourse(it) }) {
                    mergedFlags.addAll(run.map { it.id })
                    mergedCourses.add(
                        current.copy(
                            startWeek = run.first().startWeek,
                            endWeek = run.last().endWeek,
                            isOddWeek = run.first().startWeek % 2 == 1,
                            isEvenWeek = run.first().startWeek % 2 == 0,
                        ),
                    )
                    continue
                }

                mergedFlags.add(current.id)
                mergedCourses.add(current)
            }
        }

        mergedCourses.sortWith { left, right ->
            val dayCompare = left.dayOfWeek.compareTo(right.dayOfWeek)
            if (dayCompare != 0) {
                dayCompare
            } else {
                val sectionCompare = left.startSection.compareTo(right.startSection)
                if (sectionCompare != 0) sectionCompare else left.startWeek.compareTo(right.startWeek)
            }
        }
        return mergedCourses
    }

    /** 合并键（ics_import_service.dart:374-387）。 */
    private fun courseMergeKey(course: Course): String = listOf(
        course.name,
        course.teacher,
        course.location,
        course.dayOfWeek.toString(),
        course.startSection.toString(),
        course.endSection.toString(),
        course.startTime,
        course.endTime,
        course.shortName ?: "",
        course.note ?: "",
    ).joinToString("|")

    private fun isSingleWeekCourse(course: Course): Boolean =
        course.startWeek == course.endWeek && !course.isOddWeek && !course.isEvenWeek

    /** 「楼栋 + 教师」合并字段拆出教室（ics_import_service.dart:394-400）。 */
    private fun extractLocationFromCombinedField(location: String): String {
        val parts = location.trim()
            .split(Regex("${ECMASCRIPT_WS}+"))
            .filter { it.isNotEmpty() }
        if (parts.size <= 1) return location.trim()
        return parts.subList(0, parts.size - 1).joinToString(" ")
    }

    /** 「楼栋 + 教师」合并字段取末段当教师（ics_import_service.dart:402-408）。 */
    private fun extractTeacherFromCombinedLocation(location: String): String {
        val parts = location.trim()
            .split(Regex("${ECMASCRIPT_WS}+"))
            .filter { it.isNotEmpty() }
        if (parts.isEmpty()) return ""
        return parts.last()
    }

    /** `20260302T082000` / `…Z` 解析（ics_import_service.dart:410-436）。 */
    fun parseLocalDateTime(value: String?): LocalDateTime? {
        if (value == null) return null
        val m = Regex("""^(\d{8})T(\d{4,6})(Z)?$""").find(value.trim()) ?: return null
        val date = m.groupValues[1]
        val time = m.groupValues[2]
        val year = date.substring(0, 4).toIntOrNull() ?: return null
        val month = date.substring(4, 6).toIntOrNull() ?: return null
        val day = date.substring(6, 8).toIntOrNull() ?: return null
        val hour = time.substring(0, 2).toIntOrNull() ?: return null
        val minute = time.substring(2, 4).toIntOrNull() ?: return null
        val second = if (time.length >= 6) time.substring(4, 6).toIntOrNull() ?: return null else 0
        val isUtc = m.groupValues[3] == "Z"
        return if (isUtc) {
            // Dart DateTime.utc(...) 各字段越界静默顺延（20260231 → 3月3日），
            // LocalDateTime.of 会直接抛异常，必须走 DartTime.dateTime 的日历顺延桥。
            val utcWall = com.mutx163.qingyu.core.DartTime.dateTime(year, month, day, hour, minute, second)
            // Dart DateTime.utc(...).toLocal()：同一瞬间换算到本机时区。
            java.time.ZonedDateTime.of(utcWall, java.time.ZoneId.of("UTC"))
                .withZoneSameInstant(java.time.ZoneId.systemDefault())
                .toLocalDateTime()
        } else {
            com.mutx163.qingyu.core.DartTime.dateTime(year, month, day, hour, minute, second)
        }
    }

    /** UNTIL → 结束周（ics_import_service.dart:438-466）。 */
    private fun parseEndWeek(
        rrule: String?,
        semesterStart: LocalDateTime,
        startDateTime: LocalDateTime,
    ): Int? {
        if (rrule == null) return null
        val untilDateTime = parseUntilDateTime(rrule) ?: return null
        val intervalWeeks = parseWeeklyInterval(rrule)
        val repeatDays = 7 * (if (intervalWeeks <= 0) 1 else intervalWeeks)
        // Dart difference() 数的是经过的时间（毫秒级绝对时长）。
        val differenceMillis = java.time.Duration.between(startDateTime, untilDateTime).toMillis()
        if (differenceMillis < 0) {
            return weekIndex(startDateTime, semesterStart)
        }
        // 保持**绝对时长**语义而不是日历日：UNTIL 当天早于上课时刻的那次不算
        // （test/services/ics_import_service_test.dart 的三条钉子钉这个边界）。
        val repeatMillis = repeatDays * 24L * 60L * 60L * 1000L
        val occurrenceOffset = differenceMillis / repeatMillis
        val lastOccurrence = startDateTime.plusDays(repeatDays * occurrenceOffset)
        return weekIndex(lastOccurrence, semesterStart)
    }

    /** UNTIL 时刻解析（ics_import_service.dart:468-497）。 */
    private fun parseUntilDateTime(rrule: String): LocalDateTime? {
        val dateTimeMatch = Regex("""UNTIL=(\d{8})T(\d{6})(Z)?""").find(rrule)
        if (dateTimeMatch != null) {
            val date = dateTimeMatch.groupValues[1]
            val time = dateTimeMatch.groupValues[2]
            val isUtc = dateTimeMatch.groupValues[3] == "Z"
            val year = date.substring(0, 4).toInt()
            val month = date.substring(4, 6).toInt()
            val day = date.substring(6, 8).toInt()
            val hour = time.substring(0, 2).toInt()
            val minute = time.substring(2, 4).toInt()
            val second = time.substring(4, 6).toInt()
            return if (isUtc) {
                // 同 parseLocalDateTime：越界字段静默顺延，走 DartTime.dateTime。
                val utcWall = com.mutx163.qingyu.core.DartTime.dateTime(year, month, day, hour, minute, second)
                java.time.ZonedDateTime.of(utcWall, java.time.ZoneId.of("UTC"))
                    .withZoneSameInstant(java.time.ZoneId.systemDefault())
                    .toLocalDateTime()
            } else {
                com.mutx163.qingyu.core.DartTime.dateTime(year, month, day, hour, minute, second)
            }
        }

        val dateMatch = Regex("""UNTIL=(\d{8})""").find(rrule) ?: return null
        val date = dateMatch.groupValues[1]
        return com.mutx163.qingyu.core.DartTime.dateTime(
            date.substring(0, 4).toInt(),
            date.substring(4, 6).toInt(),
            date.substring(6, 8).toInt(),
        )
    }

    /** INTERVAL 解析（ics_import_service.dart:499-502）。 */
    private fun parseWeeklyInterval(rrule: String): Int {
        val match = Regex("""INTERVAL=(\d+)""").find(rrule) ?: return 1
        return match.groupValues[1].toIntOrNull() ?: 1
    }

    /** 周次（ics_import_service.dart:504-510）。 */
    private fun weekIndex(date: LocalDateTime, semesterStart: LocalDateTime): Int {
        val days = WeekCalculator.daysBetween(
            WeekCalculator.startOfWeek(semesterStart),
            WeekCalculator.startOfWeek(date),
        )
        return (days / 7).toInt() + 1
    }

    private fun formatTime(time: LocalDateTime): String = String.format(
        "%02d:%02d", time.hour, time.minute,
    )

    /** LocalDateTime → epoch 毫秒（Dart millisecondsSinceEpoch，本机时区）。 */
    private fun toEpochMilli(value: LocalDateTime): Long =
        value.atZone(java.time.ZoneId.systemDefault()).toInstant().toEpochMilli()
}
