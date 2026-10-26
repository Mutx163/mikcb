package com.mutx163.qingyu.transfer

import com.mutx163.qingyu.core.Course
import java.time.LocalDateTime

/**
 * ICS 事件模型与课程事件收集（移植自 lib/services/ics_export_service.dart 的
 * 纯值与收集逻辑，ics_export_service.dart:11-27、71-89、283-343、443-490、540-554）。
 *
 * **移植边界**：Dart 的 `IcsExportService.collectEvents` 一并收集 exam 与
 * scheduleItem 并支持节假日过滤；本族只拿到 core.Course，因此这里只移植
 * **课程**事件收集，考试/日程/节假日数据模型留给拿到完整 profile 的层。
 * 节假日过滤留了一个 `hideOn` 函数钩子（Dart 侧是 IcsHolidayFilter.hidesCoursesOn）。
 */

/** 导出事件种类（ics_export_service.dart:11-27）。 */
enum class IcsExportEventKind(val value: String) {
    COURSE("course"),
    EXAM("exam"),
    SCHEDULE_ITEM("schedule");

    companion object {
        fun fromValue(value: String?): IcsExportEventKind? =
            entries.firstOrNull { it.value == value }
    }
}

/**
 * 一条课次实例化后的日历事件（ics_export_service.dart:71-89）。
 * [start]/[end] 是本地墙上时刻（Dart `DateTime` 语义）。
 */
data class IcsCalendarEvent(
    val uid: String,
    val kind: IcsExportEventKind,
    val start: LocalDateTime,
    val end: LocalDateTime,
    val summary: String,
    val location: String? = null,
    val description: String? = null,
)

/** 导出侧 `_courseEvents` 的命名 record 返回（ics_export_service.dart:284）。 */
data class CollectedCoursesResult(
    val events: List<IcsCalendarEvent>,
    val skippedHolidayCourses: Int,
)

/** Dart `_mondayOf`（ics_export_service.dart:582-583）。 */
fun icsMondayOf(date: LocalDateTime): LocalDateTime =
    icsAddDays(date, -(date.dayOfWeek.value - 1))

/** Dart `_isInRange`（ics_export_service.dart:603-606）：日期归零后双闭区间。 */
fun icsIsInRange(date: LocalDateTime, from: LocalDateTime, to: LocalDateTime): Boolean {
    val normalized = icsDateOnly(date)
    val f = icsDateOnly(from)
    val t = icsDateOnly(to)
    return !normalized.isBefore(f) && !normalized.isAfter(t)
}

/** Dart `_hasText`（ics_export_service.dart:712）。 */
fun icsHasText(value: String?): Boolean = value != null && dartTrim(value).isNotEmpty()

/** Dart `_joinDistinct`（ics_export_service.dart:714-724）：trim 去重后按 `\n` 拼。 */
fun icsJoinDistinct(values: List<String>): String {
    val seen = LinkedHashSet<String>()
    val result = mutableListOf<String>()
    for (value in values) {
        val normalized = value.trim()
        if (normalized.isNotEmpty() && seen.add(normalized)) {
            result.add(normalized)
        }
    }
    return result.joinToString("\n")
}

/** Dart `_buildTimedEvent` 的 UID 物料与 sha256（ics_export_service.dart:471-479）。 */
fun buildCourseUid(
    profileId: String,
    courseId: String,
    occurrenceDate: LocalDateTime,
    start: LocalDateTime,
    end: LocalDateTime,
): String {
    val uidMaterial = listOf(
        profileId,
        IcsExportEventKind.COURSE.value,
        courseId,
        formatIcsCalendarDate(icsDateOnly(occurrenceDate)),
        formatIcsClock(start),
        formatIcsClock(end),
    ).joinToString("|")
    return sha256Hex(uidMaterial) + "@qingyu-timetable.local"
}

private fun sha256Hex(text: String): String {
    val digest = java.security.MessageDigest.getInstance("SHA-256")
        .digest(text.toByteArray(Charsets.UTF_8))
    val sb = StringBuilder(digest.size * 2)
    for (b in digest) {
        val v = b.toInt() and 0xFF
        sb.append("0123456789abcdef"[v ushr 4])
        sb.append("0123456789abcdef"[v and 0x0F])
    }
    return sb.toString()
}

/**
 * Dart `_buildTimedEvent`（ics_export_service.dart:443-490）的课程子集。
 *
 * - 开始时间不允许 24:00（没有"当天结束"语义）；结束时间 24:00 落到**次日零点**；
 * - 结束不晚于开始 → 结束日期 +1 天（跨夜课，Dart `_addDays(end, 1)`）；
 * - 任一钟点解析失败返回 null（整条事件丢弃，与 Dart 同口径）。
 */
fun buildCourseTimedEvent(
    profileId: String,
    course: Course,
    occurrenceDate: LocalDateTime,
    week: Int,
): IcsCalendarEvent? {
    val startParts = parseIcsTime(course.startTime, allowEndOfDay = false) ?: return null
    val endParts = parseIcsTime(course.endTime, allowEndOfDay = true) ?: return null

    val date = icsDateOnly(occurrenceDate)
    val start = date.withHour(startParts.hour)
        .withMinute(startParts.minute)
        .withSecond(startParts.second)
        .withNano(0)
    var end = date.withHour(endParts.hour % 24)
        .withMinute(endParts.minute)
        .withSecond(endParts.second)
        .withNano(0)
    if (endParts.hour == 24) {
        end = end.plusDays(1)
    }
    if (!end.isAfter(start)) {
        end = end.plusDays(1)
    }

    val sessionNote = course.sessionNoteForWeek(week)
    val descriptionParts = mutableListOf<String>()
    if (dartTrim(course.teacher).isNotEmpty()) descriptionParts.add("Teacher: ${course.teacher}")
    descriptionParts.add("Sections: ${course.startSection}-${course.endSection}")
    course.description?.let { if (dartTrim(it).isNotEmpty()) descriptionParts.add(dartTrim(it)) }
    course.note?.let { if (dartTrim(it).isNotEmpty()) descriptionParts.add(dartTrim(it)) }
    if (sessionNote != null && dartTrim(sessionNote.text).isNotEmpty()) {
        descriptionParts.add(dartTrim(sessionNote.text))
    }
    if (sessionNote?.hasHomework == true) descriptionParts.add("Homework: yes")

    return IcsCalendarEvent(
        uid = buildCourseUid(
            profileId = profileId,
            courseId = course.id,
            occurrenceDate = occurrenceDate,
            start = start,
            end = end,
        ),
        kind = IcsExportEventKind.COURSE,
        start = start,
        end = end,
        summary = course.name,
        location = course.location,
        description = icsJoinDistinct(descriptionParts),
    )
}

/**
 * Dart `_courseEvents`（ics_export_service.dart:284-343）的课程展开。
 *
 * - 学期开始日缺失 → 空结果（Dart 同口径）；
 * - 日期锚定：学期开始日所在周的**周一**为第 1 周周一，第 [week] 周周 [dayOfWeek]
 *   = 周一 + (week-1)*7 + dayOfWeek-1 个日历日；
 * - 周次 <1 跳过；区间外跳过；[hideOn] 返回 true 的日期计入
 *   skippedHolidayCourses（节假日过滤钩子，null = 不过滤）。
 */
fun collectCourseEvents(
    profileId: String,
    courses: List<Course>,
    semesterStartDate: LocalDateTime?,
    fromDate: LocalDateTime,
    toDate: LocalDateTime,
    hideOn: ((LocalDateTime) -> Boolean)? = null,
): CollectedCoursesResult {
    if (semesterStartDate == null) {
        return CollectedCoursesResult(emptyList(), 0)
    }
    val firstMonday = icsMondayOf(icsDateOnly(semesterStartDate))
    val events = mutableListOf<IcsCalendarEvent>()
    var skippedHolidayCourses = 0
    for (course in courses) {
        val dayOfWeek = course.dayOfWeek.coerceIn(1, 7)
        for (week in course.activeWeeks) {
            if (week < 1) continue
            val occurrenceDate = icsAddDays(firstMonday, (week - 1) * 7 + dayOfWeek - 1)
            if (!icsIsInRange(occurrenceDate, fromDate, toDate)) continue
            if (hideOn != null && hideOn(occurrenceDate)) {
                skippedHolidayCourses++
                continue
            }
            buildCourseTimedEvent(profileId, course, occurrenceDate, week)
                ?.let { events.add(it) }
        }
    }
    return CollectedCoursesResult(events, skippedHolidayCourses)
}

/**
 * Dart `_compareEvents`（ics_export_service.dart:540-554）：
 * 开始 → 结束 → kind 字符串 → uid。
 */
fun compareIcsEvents(left: IcsCalendarEvent, right: IcsCalendarEvent): Int {
    val startCompare = left.start.compareTo(right.start)
    if (startCompare != 0) return startCompare
    val endCompare = left.end.compareTo(right.end)
    if (endCompare != 0) return endCompare
    val kindCompare = left.kind.value.compareTo(right.kind.value)
    if (kindCompare != 0) return kindCompare
    return left.uid.compareTo(right.uid)
}
