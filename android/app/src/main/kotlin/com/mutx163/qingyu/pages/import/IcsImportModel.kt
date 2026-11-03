package com.mutx163.qingyu.pages.import

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.DartTime
import com.mutx163.qingyu.core.FormatException
import com.mutx163.qingyu.core.WeekCalculator
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.temporal.ChronoUnit
import java.util.Locale

/**
 * ICS 课表解析模型（P3-G1 · 移植 `lib/services/ics_import_service.dart`，
 * 供 `ics_course_import_screen.dart` 对应的渲染层消费）。
 *
 * WakeUp 风格 ICS：VEVENT 的 DESCRIPTION 前几行是结构化文本
 * （第 X-Y 节 / 地点 / 教师），DTSTART/RRULE 承担周次。纯 Kotlin 无 IO，
 * 期望值在 [IcsImportModelTest] 按 Dart 源手推对拍。
 */
data class IcsImportResult(
    val courses: List<Course>,
    val semesterStart: LocalDateTime,
)

object IcsImportModel {

    /**
     * `.ics` 文件的体积预算（与表格导入同一条 20 MB 上限）。
     * `.ics` 是纯文本，远超真实日历导出的需要。
     */
    const val MAX_FILE_BYTES = 20 * 1024 * 1024

    /** RFC 5545 里值为 TEXT 类型的属性——只有这些需要反转义。 */
    private val ICS_TEXT_PROPERTIES = setOf(
        "SUMMARY", "DESCRIPTION", "LOCATION", "CATEGORIES", "COMMENT",
    )

    private val SECTION_PATTERN = Regex("""第\s*(\d+)\s*-\s*(\d+)\s*节""")
    private val SUMMARY_BADGE_PATTERN = Regex("""\[\d+]\[[^\]]+]$""")
    private val DT_PATTERN = Regex("""^(\d{8})T(\d{4,6})(Z)?$""")
    private val UNTIL_DATETIME_PATTERN = Regex("""UNTIL=(\d{8})T(\d{6})(Z)?""")
    private val UNTIL_DATE_PATTERN = Regex("""UNTIL=(\d{8})""")
    private val INTERVAL_PATTERN = Regex("""INTERVAL=(\d+)""")

    /**
     * 解析 WakeUp 风格 ICS 内容。
     *
     * 学期起点取**最早 DTSTART** 所在周的周一 00:00；任何事件都解析不出时
     * 返回空课表 + [now]（对齐 Dart 的 `DateTime.now()`，注入以便测试）。
     */
    fun parseWakeUpSchedule(content: String, now: LocalDateTime = LocalDateTime.now()): IcsImportResult {
        val events = parseEvents(content)
        if (events.isEmpty()) {
            return IcsImportResult(courses = emptyList(), semesterStart = now)
        }

        val startDates = events
            .mapNotNull { parseLocalDateTime(it["DTSTART"]) }
            .sorted()

        if (startDates.isEmpty()) {
            return IcsImportResult(courses = emptyList(), semesterStart = now)
        }

        val semesterStart = WeekCalculator.startOfWeek(startDates.first())
        val rawCourses = mutableListOf<Course>()

        for ((index, event) in events.withIndex()) {
            val course = buildCourseFromEvent(event, semesterStart, index)
            if (course != null) {
                rawCourses.add(course)
            }
        }

        val courses = mergeAlternatingWeekCourses(rawCourses)
        return IcsImportResult(courses = courses, semesterStart = semesterStart)
    }

    /**
     * 逐行扫描出事件属性表。规则（与 Dart 逐条对齐）：
     * - `BEGIN:VEVENT` 开表、`END:VEVENT` 收表；表外行忽略；
     * - `BEGIN:VALARM`/`END:VALARM` 之间的行全部忽略（闹钟不进事件）；
     * - 第一个 `:` 切键值，键取 `;` 前的参数段（`DTSTART;TZID=..` → `DTSTART`）；
     * - **同名键首见优先**（`putIfAbsent`）；
     * - TEXT 类属性值反转义，其余原样（DTSTART/RRULE 的值本身带冒号分号）。
     */
    private fun parseEvents(content: String): List<Map<String, String>> {
        val unfoldedLines = unfoldLines(content)
        val events = mutableListOf<Map<String, String>>()
        var currentEvent: MutableMap<String, String>? = null
        var inAlarm = false

        for (rawLine in unfoldedLines) {
            val line = rawLine.trim()
            if (line == "BEGIN:VEVENT") {
                currentEvent = mutableMapOf()
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
            currentEvent.putIfAbsent(
                key,
                if (key in ICS_TEXT_PROPERTIES) unescapeIcsText(value) else value,
            )
        }
        return events
    }

    /**
     * 还原 RFC 5545 文本转义。
     *
     * **逐字符扫描而不是 replaceAll 链**：`\\,` 表示「一个字面反斜杠 + 一个普通
     * 逗号」，先替换 `\,` 再替换 `\\` 会把它错解析成「转义反斜杠 + 什么都不剩」。
     * 一趟扫描天然处理正确的优先级。
     */
    fun unescapeIcsText(value: String): String {
        if (!value.contains('\\')) return value
        val buffer = StringBuilder()
        var index = 0
        while (index < value.length) {
            val char = value[index]
            if (char == '\\' && index + 1 < value.length) {
                when (val next = value[index + 1]) {
                    'n', 'N' -> {
                        buffer.append('\n')
                        index += 2
                        continue
                    }
                    ',', ';', ':', '\\' -> {
                        buffer.append(next)
                        index += 2
                        continue
                    }
                }
            }
            buffer.append(char)
            index += 1
        }
        return buffer.toString()
    }

    /** RFC 5545 折行展开：以空格/制表符开头的行拼回上一行（去掉折叠用的首字符）。 */
    private fun unfoldLines(content: String): List<String> {
        val normalized = content.replace("\r\n", "\n")
        val unfolded = mutableListOf<String>()
        for (line in normalized.split("\n")) {
            if ((line.startsWith(" ") || line.startsWith("\t")) && unfolded.isNotEmpty()) {
                unfolded[unfolded.size - 1] = unfolded.last() + line.substring(1)
            } else {
                unfolded.add(line)
            }
        }
        return unfolded
    }

    private fun buildCourseFromEvent(
        event: Map<String, String>,
        semesterStart: LocalDateTime,
        index: Int,
    ): Course? {
        val summary = event["SUMMARY"] ?: return null
        val description = event["DESCRIPTION"] ?: return null
        val startDateTime = parseLocalDateTime(event["DTSTART"]) ?: return null
        val endDateTime = parseLocalDateTime(event["DTEND"]) ?: return null

        // `\n` 已在 parseEvents 里还原成真换行，这里不能二次 replaceAll：
        // 源文件里 `\\n`（字面反斜杠+字母n）是合法内容，二次展开会错。
        val descriptionLines = description
            .split("\n")
            .map { it.trim() }
            .filter { it.isNotEmpty() }
        if (descriptionLines.isEmpty()) return null

        val sectionMatch = SECTION_PATTERN.find(descriptionLines.first()) ?: return null
        val startSection = sectionMatch.groupValues[1].toIntOrNull() ?: return null
        val endSection = sectionMatch.groupValues[2].toIntOrNull() ?: return null
        val hasStructuredLocation = descriptionLines.size >= 2

        // DESCRIPTION 首行之后两种已知行序：
        //   Format A: line[1]=地点, line[2]=教师
        //   Format B: line[1]=教师,   line[2]=地点
        // 用 ICS 独立的 LOCATION 字段做判据：哪行与 LOCATION 互含，哪行是地点。
        val rawLocation: String
        val teacher: String
        if (!hasStructuredLocation) {
            rawLocation = event["LOCATION"] ?: ""
            teacher = extractTeacherFromCombinedLocation(rawLocation)
        } else if (descriptionLines.size < 3) {
            // 只多出一行——教师回落 LOCATION 字段
            rawLocation = descriptionLines[1]
            teacher = extractTeacherFromCombinedLocation(event["LOCATION"] ?: "")
        } else {
            val icsLocation = (event["LOCATION"] ?: "").trim()
            val line1 = descriptionLines[1].trim()
            val line2 = descriptionLines[2].trim()
            val line1MatchesLocation =
                icsLocation.isNotEmpty() &&
                    (line1.contains(icsLocation) || icsLocation.contains(line1))
            val line2MatchesLocation =
                icsLocation.isNotEmpty() &&
                    (line2.contains(icsLocation) || icsLocation.contains(line2))
            if (line2MatchesLocation && !line1MatchesLocation) {
                teacher = line1
                rawLocation = line2
            } else {
                // Format A（默认）：line[1]=地点, line[2]=教师
                rawLocation = line1
                teacher = line2
            }
        }

        val rawStartWeek = weekIndex(startDateTime, semesterStart)
        val rawEndWeek = parseEndWeek(event["RRULE"], semesterStart, startDateTime) ?: rawStartWeek
        // 钳到存储读路径同款 1..30（Course.normalizeWeeks），写入与读回一致；
        // 不钳的话恶意 `UNTIL=99991231` 会推出 ~416k 周撑爆内存。
        val (startWeek, endWeek) = Course.normalizeWeeks(startWeek = rawStartWeek, endWeek = rawEndWeek)
        val weeklyInterval = parseWeeklyInterval(event["RRULE"] ?: "")
        // INTERVAL=2 表示隔周上；按首周奇偶落单双周标志
        val isBiweekly = weeklyInterval == 2
        val isOddWeek = isBiweekly && startWeek % 2 != 0
        val isEvenWeek = isBiweekly && startWeek % 2 == 0

        return Course(
            id = "ics-${DartTime.toEpochMillis(startDateTime)}-$index",
            name = cleanSummary(summary),
            teacher = teacher,
            location = if (hasStructuredLocation) rawLocation.trim() else extractLocationFromCombinedField(rawLocation),
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

    /** 清掉 SUMMARY 尾部的 `[数字][星期]` 徽标（WakeUp 导出会带）。 */
    private fun cleanSummary(summary: String): String =
        summary.replaceFirst(SUMMARY_BADGE_PATTERN, "").trim()

    /**
     * 单双周单周课合并：同键（名/师/地/星期/节次/钟点全同）的单周课，
     * 若逐条间隔恰为 2 周且奇偶一致，合并成一条带单/双周标志的区间课。
     */
    private fun mergeAlternatingWeekCourses(courses: List<Course>): List<Course> {
        val grouped = LinkedHashMap<String, MutableList<Course>>()
        for (course in courses) {
            grouped.getOrPut(courseMergeKey(course)) { mutableListOf() }.add(course)
        }

        val mergedCourses = mutableListOf<Course>()
        for ((_, group) in grouped) {
            val mergedFlags = mutableSetOf<String>()
            val sortedGroup = group.sortedWith(
                compareBy({ it.startWeek }, { it.id }),
            )

            for (i in sortedGroup.indices) {
                val current = sortedGroup[i]
                if (current.id in mergedFlags) continue

                val run = mutableListOf(current)
                for (j in i + 1 until sortedGroup.size) {
                    val candidate = sortedGroup[j]
                    if (candidate.id in mergedFlags) continue
                    val previous = run.last()
                    if (!isSingleWeekCourse(previous) || !isSingleWeekCourse(candidate)) break
                    if (candidate.startWeek - previous.startWeek != 2) break
                    if (candidate.startWeek % 2 != current.startWeek % 2) break
                    run.add(candidate)
                }

                if (run.size >= 2 && run.all(::isSingleWeekCourse)) {
                    mergedFlags.addAll(run.map { it.id })
                    mergedCourses.add(
                        current.copy(
                            startWeek = run.first().startWeek,
                            endWeek = run.last().endWeek,
                            isOddWeek = run.first().startWeek % 2 != 0,
                            isEvenWeek = run.first().startWeek % 2 == 0,
                        ),
                    )
                    continue
                }

                mergedFlags.add(current.id)
                mergedCourses.add(current)
            }
        }

        return mergedCourses.sortedWith(
            compareBy({ it.dayOfWeek }, { it.startSection }, { it.startWeek }),
        )
    }

    /** 合并键：用户可感知字段全同才算同一门课（id/颜色/备注刻意不进键）。 */
    private fun courseMergeKey(course: Course): String =
        listOf(
            course.name,
            course.teacher,
            course.location,
            course.dayOfWeek,
            course.startSection,
            course.endSection,
            course.startTime,
            course.endTime,
            course.shortName ?: "",
            course.note ?: "",
        ).joinToString("|")

    private fun isSingleWeekCourse(course: Course): Boolean =
        course.startWeek == course.endWeek && !course.isOddWeek && !course.isEvenWeek

    /** 组合地点字段「楼栋 教师」：去掉尾段留楼栋。 */
    private fun extractLocationFromCombinedField(location: String): String {
        val parts = location.trim().split(Regex("""\s+""")).filter { it.isNotEmpty() }
        if (parts.size <= 1) return location.trim()
        return parts.subList(0, parts.size - 1).joinToString(" ")
    }

    /** 组合地点字段「楼栋 教师」：尾段是教师。 */
    private fun extractTeacherFromCombinedLocation(location: String): String {
        val parts = location.trim().split(Regex("""\s+""")).filter { it.isNotEmpty() }
        if (parts.isEmpty()) return ""
        return parts.last()
    }

    /** `YYYYMMDDTHHMM(SS)?(Z)?` → 本地墙上时刻；Z 后缀按 UTC→本地换算。 */
    private fun parseLocalDateTime(value: String?): LocalDateTime? {
        if (value == null) return null
        val match = DT_PATTERN.find(value.trim()) ?: return null

        val date = match.groupValues[1]
        val time = match.groupValues[2]
        val year = date.substring(0, 4).toIntOrNull() ?: return null
        val month = date.substring(4, 6).toIntOrNull() ?: return null
        val day = date.substring(6, 8).toIntOrNull() ?: return null
        val hour = time.substring(0, 2).toIntOrNull() ?: return null
        val minute = time.substring(2, 4).toIntOrNull() ?: return null
        val second = if (time.length >= 6) time.substring(4, 6).toIntOrNull() ?: return null else 0

        val naive = try {
            LocalDateTime.of(year, month, day, hour, minute, second)
        } catch (_: Exception) {
            return null
        }
        val isUtc = match.groupValues[3].isNotEmpty()
        return if (isUtc) {
            // Dart: DateTime.utc(...).toLocal()
            naive.atZone(ZoneOffset.UTC)
                .withZoneSameInstant(ZoneId.systemDefault())
                .toLocalDateTime()
        } else {
            naive
        }
    }

    /** RRULE 的 UNTIL → 最后一次实例的周次；UNTIL 缺失/早于开始返回 null。 */
    private fun parseEndWeek(rrule: String?, semesterStart: LocalDateTime, startDateTime: LocalDateTime): Int? {
        if (rrule == null) return null
        val untilDateTime = parseUntilDateTime(rrule) ?: return null

        val intervalWeeks = parseWeeklyInterval(rrule)
        val repeatDays = 7L * (if (intervalWeeks <= 0) 1 else intervalWeeks)
        val difference = ChronoUnit.MICROS.between(startDateTime, untilDateTime)
        if (difference < 0) {
            return weekIndex(startDateTime, semesterStart)
        }

        // 保持**绝对时长**语义而不是日历日：UNTIL 是一个具体时刻，
        // 「最后一次实例」以 `时刻 ≤ UNTIL` 为准（日历日跨度会多算一周）。
        val repeatMicros = repeatDays * 24 * 60 * 60 * 1_000_000
        val occurrenceOffset = difference / repeatMicros
        val lastOccurrence = startDateTime.plusDays(repeatDays * occurrenceOffset)
        return weekIndex(lastOccurrence, semesterStart)
    }

    /** `UNTIL=YYYYMMDDTHHMMSS(Z)?` 优先，回落 `UNTIL=YYYYMMDD`（当天 00:00）。 */
    private fun parseUntilDateTime(rrule: String): LocalDateTime? {
        val dateTimeMatch = UNTIL_DATETIME_PATTERN.find(rrule)
        if (dateTimeMatch != null) {
            val date = dateTimeMatch.groupValues[1]
            val time = dateTimeMatch.groupValues[2]
            val isUtc = dateTimeMatch.groupValues[3] == "Z"
            val naive = try {
                LocalDateTime.of(
                    date.substring(0, 4).toInt(),
                    date.substring(4, 6).toInt(),
                    date.substring(6, 8).toInt(),
                    time.substring(0, 2).toInt(),
                    time.substring(2, 4).toInt(),
                    time.substring(4, 6).toInt(),
                )
            } catch (_: Exception) {
                return null
            }
            return if (isUtc) {
                naive.atZone(ZoneOffset.UTC)
                    .withZoneSameInstant(ZoneId.systemDefault())
                    .toLocalDateTime()
            } else {
                naive
            }
        }

        val dateMatch = UNTIL_DATE_PATTERN.find(rrule) ?: return null
        val date = dateMatch.groupValues[1]
        return try {
            LocalDateTime.of(
                date.substring(0, 4).toInt(),
                date.substring(4, 6).toInt(),
                date.substring(6, 8).toInt(),
                0, 0,
            )
        } catch (_: Exception) {
            null
        }
    }

    /** `INTERVAL=N`；缺失或非法回 1。 */
    private fun parseWeeklyInterval(rrule: String): Int =
        INTERVAL_PATTERN.find(rrule)?.groupValues?.get(1)?.toIntOrNull() ?: 1

    /** [date] 在以 [semesterStart] 为第 1 周的学期里的周次（周一为每周起始）。 */
    private fun weekIndex(date: LocalDateTime, semesterStart: LocalDateTime): Int =
        (WeekCalculator.daysBetween(
            WeekCalculator.startOfWeek(semesterStart),
            WeekCalculator.startOfWeek(date),
        ) / 7 + 1).toInt()

    /** 课程时刻键 `HH:MM`：落盘用，必须 [Locale.ROOT]（本地数字会破坏逐字节对拍）。 */
    private fun formatTime(time: LocalDateTime): String =
        String.format(Locale.ROOT, "%02d:%02d", time.hour, time.minute)
}
