package com.mutx163.qingyu.pages.export

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.transfer.IcsCalendarEvent
import com.mutx163.qingyu.transfer.IcsExportEventKind
import com.mutx163.qingyu.transfer.buildCourseTimedEvent
import com.mutx163.qingyu.transfer.collectCourseEvents
import com.mutx163.qingyu.transfer.compareIcsEvents
import com.mutx163.qingyu.transfer.dartTrim
import com.mutx163.qingyu.transfer.formatIcsCalendarDate
import com.mutx163.qingyu.transfer.formatIcsClock
import com.mutx163.qingyu.transfer.icsDateOnly
import com.mutx163.qingyu.transfer.icsHasText
import com.mutx163.qingyu.transfer.icsIsInRange
import com.mutx163.qingyu.transfer.icsJoinDistinct
import com.mutx163.qingyu.transfer.parseIcsTime
import java.security.MessageDigest
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * ICS 导出的**事件收集层**（F04 补齐的那一层）。
 *
 * ## 为什么要有这个文件
 *
 * 迁到原生之前，`transfer/IcsModel.kt` 只移植了「课程展开」（`collectCourseEvents`）。
 * 页面上的「日历内容」三个勾选框（课程 / 考试 / 日程）里，**只有课程**真的会产出事件；
 * 勾上考试或日程什么都不会发生 —— 而 Dart 侧两种都有自己的收集器
 * （`ics_export_service.dart` 的 `_examEvents` / `_scheduleEvents`）。
 * 少了这一层，「导出」按钮在勾了考试/日程时会给一个**假成功**（导出 0 条事件却照样弹分享）。
 *
 * 本文件负责把 Dart `collectEvents`（`ics_export_service.dart:216-243`）完整搬过来：
 * 收集 → 按 uid 去重（后写覆盖）→ 按 `compareIcsEvents` 排序；
 * 以及「同步到系统日历」要用的载荷转换 [IcsEventCollection.syncPayload]。
 *
 * ## 与 Dart 逐条对齐的口径
 *
 * | 规则 | Dart 出处 | 本文件 |
 * |---|---|---|
 * | 起止区间非法（结束早于开始） | `hasValidDateRange` | 直接返回空结果，不进任何收集器 |
 * | 课程按周次展开 + 节假日过滤 | `_courseEvents` | 复用 `transfer.collectCourseEvents`（已有单测） |
 * | 考试只按日期落区间 | `_examEvents` | [examEvents] |
 * | 日程按 `expandInstances` 逐日展开、同 key 覆盖 | `_scheduleEvents` | [scheduleEvents] |
 * | uid = sha256(profile|kind|sourceId|日期|始|终) | `_buildTimedEvent` | [buildTimedUid] |
 * | 去重键 = uid，`LinkedHashMap` 后写覆盖 | `collectEvents` | [collect] |
 * | 排序：开始 → 结束 → kind → uid | `_compareEvents` | 复用 `transfer.compareIcsEvents` |
 *
 * 全部纯 Kotlin（不碰 Android / Compose），JVM 单测可直接跑。
 */

/** 一个档案里导出需要的内容（Dart `IcsExportRequest.profile` 的裁剪视图）。 */
data class IcsExportSource(
    val profileId: String,
    val profileName: String,
    val courses: List<Course> = emptyList(),
    val exams: List<Exam> = emptyList(),
    val scheduleItems: List<ScheduleItem> = emptyList(),
    /** 学期开始日期；为空时课程算不出日期（与 Dart 同口径：课程事件为空）。 */
    val semesterStartDate: LocalDateTime? = null,
)

/** 收集结果（Dart `IcsCollectedEvents`）：事件 + 被节假日跳过的课程节次数。 */
data class IcsCollectedEvents(
    val events: List<IcsCalendarEvent>,
    val skippedHolidayCourses: Int = 0,
)

object IcsEventCollection {

    /**
     * 收集一次导出涉及的全部事件。
     *
     * @param skipHolidayCourses 是否跳过节假日里的**课程**（考试与日程不受影响，Dart 决策）
     * @param isHoliday 节假日判据；`null` 表示拿不到节假日数据 ⇒ 不做过滤（不静默变成「全跳过」）
     */
    fun collect(
        source: IcsExportSource,
        kinds: Set<IcsExportEventKind>,
        from: LocalDate,
        to: LocalDate,
        skipHolidayCourses: Boolean = true,
        isHoliday: ((LocalDate) -> Boolean)? = null,
    ): IcsCollectedEvents {
        // Dart `hasValidDateRange`：结束早于开始直接当「没有事件」，不去各收集器里绕一圈。
        if (to.isBefore(from)) return IcsCollectedEvents(emptyList(), 0)
        val fromDateTime = from.atStartOfDay()
        val toDateTime = to.atStartOfDay()

        val collected = mutableListOf<IcsCalendarEvent>()
        var skippedHolidayCourses = 0

        if (kinds.contains(IcsExportEventKind.COURSE)) {
            val hideOn: ((LocalDateTime) -> Boolean)? =
                if (skipHolidayCourses && isHoliday != null) {
                    { dateTime -> isHoliday(dateTime.toLocalDate()) }
                } else {
                    null
                }
            val courses = collectCourseEvents(
                profileId = source.profileId,
                courses = source.courses,
                semesterStartDate = source.semesterStartDate,
                fromDate = fromDateTime,
                toDate = toDateTime,
                hideOn = hideOn,
            )
            collected.addAll(courses.events)
            skippedHolidayCourses += courses.skippedHolidayCourses
        }
        if (kinds.contains(IcsExportEventKind.EXAM)) {
            collected.addAll(examEvents(source, fromDateTime, toDateTime))
        }
        if (kinds.contains(IcsExportEventKind.SCHEDULE_ITEM)) {
            collected.addAll(scheduleEvents(source, fromDateTime, toDateTime))
        }

        // 去重：同 uid 后写覆盖（Dart `uniqueEvents[event.uid] = event`）。
        val unique = LinkedHashMap<String, IcsCalendarEvent>(collected.size)
        for (event in collected) {
            unique[event.uid] = event
        }
        val sorted = unique.values.sortedWith(Comparator { left, right ->
            compareIcsEvents(left, right)
        })
        return IcsCollectedEvents(events = sorted, skippedHolidayCourses = skippedHolidayCourses)
    }

    /**
     * `.ics` 里的日历名（Dart `_serializeCalendar`：`'${profile.name.trim()} $from - $to'.trim()`）。
     *
     * 序列化器不自己拼这个名字：它在 `transfer/` 包里，拿不到「上课表名」的语境。
     * 拼在 `pages/export/` 这一层，JVM 单测才钉得住（空课表名 → 不能变成前导空格）。
     */
    fun exportCalendarName(profileName: String, from: LocalDate, to: LocalDate): String =
        (
            profileName.trim() + " " +
                formatIcsCalendarDate(from.atStartOfDay()) + " - " +
                formatIcsCalendarDate(to.atStartOfDay())
            ).trim()

    /**
     * 「同步到系统日历」的载荷（Dart 那份 `events` 参数逐键一致）。
     *
     * 键名是 `CalendarSync.buildSyncOps` 的既有契约：
     * `startMs` / `endMs` / `title` / `location` / `description`。时刻换算成
     * **本地时区的 epoch 毫秒**（`CalendarContract` 只认 UTC 毫秒）。
     */
    fun syncPayload(
        events: List<IcsCalendarEvent>,
        zone: ZoneId = ZoneId.systemDefault(),
    ): List<Map<String, Any?>> = events.map { event ->
        linkedMapOf<String, Any?>(
            "startMs" to event.start.atZone(zone).toInstant().toEpochMilli(),
            "endMs" to event.end.atZone(zone).toInstant().toEpochMilli(),
            "title" to event.summary,
            "location" to event.location,
            "description" to event.description,
        )
    }

    // ------------------------------------------------------------------
    // 考试（Dart `_examEvents`：345-375）
    // ------------------------------------------------------------------

    private fun examEvents(
        source: IcsExportSource,
        fromDate: LocalDateTime,
        toDate: LocalDateTime,
    ): List<IcsCalendarEvent> {
        val events = mutableListOf<IcsCalendarEvent>()
        for (exam in source.exams) {
            val occurrenceDate = icsDateOnly(exam.dateTime)
            if (!icsIsInRange(occurrenceDate, fromDate, toDate)) continue
            val descriptionParts = mutableListOf<String>()
            if (icsHasText(exam.note)) descriptionParts.add(dartTrim(exam.note!!))
            if (icsHasText(exam.seatNumber)) {
                descriptionParts.add("Seat: ${dartTrim(exam.seatNumber!!)}")
            }
            buildTimedEvent(
                profileId = source.profileId,
                kind = IcsExportEventKind.EXAM,
                sourceId = exam.id,
                occurrenceDate = occurrenceDate,
                startTime = exam.startTime,
                endTime = exam.endTime,
                summary = exam.name,
                location = exam.location,
                description = icsJoinDistinct(descriptionParts),
            )?.let { events.add(it) }
        }
        return events
    }

    // ------------------------------------------------------------------
    // 日程（Dart `_scheduleEvents`：376-430）
    // ------------------------------------------------------------------

    private fun scheduleEvents(
        source: IcsExportSource,
        fromDate: LocalDateTime,
        toDate: LocalDateTime,
    ): List<IcsCalendarEvent> {
        // key = 系列根 id + 日历日；同一天既有系列实例又有一次性改期时，**后写覆盖**
        // （Dart 用 `isSeriesOverride` 判断谁赢，遍历顺序里改期条目在后面）。
        val occurrences = LinkedHashMap<String, ScheduleOccurrence>()
        for (item in source.scheduleItems) {
            if (item.isRecurring) {
                for (date in expandOccurrenceDates(item, fromDate, toDate)) {
                    val occurrenceDate = if (item.isSeriesOverride) {
                        icsDateOnly(item.occurrenceDate ?: date)
                    } else {
                        date
                    }
                    val key = "${item.seriesRootId}|${formatIcsCalendarDate(occurrenceDate)}"
                    val existing = occurrences[key]
                    if (existing == null || item.isSeriesOverride) {
                        occurrences[key] = ScheduleOccurrence(
                            item = item,
                            eventDate = icsDateOnly(date),
                            endDate = icsDateOnly(date),
                            occurrenceDate = occurrenceDate,
                        )
                    }
                }
                continue
            }

            if (!dateRangesOverlap(item.startDate, item.endDate, fromDate, toDate)) continue
            val occurrenceDate = item.occurrenceDate ?: item.startDate
            val key = "${item.seriesRootId}|${formatIcsCalendarDate(occurrenceDate)}"
            val existing = occurrences[key]
            if (existing == null || item.isSeriesOverride) {
                occurrences[key] = ScheduleOccurrence(
                    item = item,
                    eventDate = item.startDate,
                    endDate = item.endDate,
                    occurrenceDate = occurrenceDate,
                )
            }
        }

        val events = mutableListOf<IcsCalendarEvent>()
        for (occurrence in occurrences.values) {
            val item = occurrence.item
            buildTimedEvent(
                profileId = source.profileId,
                kind = IcsExportEventKind.SCHEDULE_ITEM,
                sourceId = item.seriesRootId,
                occurrenceDate = occurrence.occurrenceDate,
                eventDate = occurrence.eventDate,
                endDate = occurrence.endDate,
                startTime = item.startTime,
                endTime = item.endTime,
                summary = item.title,
                location = item.location,
                description = item.note,
            )?.let { events.add(it) }
        }
        return events
    }

    /** 一次日程实例（Dart `_ScheduleOccurrence`）。 */
    private data class ScheduleOccurrence(
        val item: ScheduleItem,
        val eventDate: LocalDateTime,
        val endDate: LocalDateTime,
        val occurrenceDate: LocalDateTime,
    )

    /**
     * Dart `ScheduleItem.expandInstances`（`schedule_item.dart:377-412`）的日期展开：
     * 从 `max(from, startDate)` 到 `min(to, endDate)` **逐日**扫，命中 `occursOn` 的留下。
     *
     * 逐日扫而不是按重复规则跳步，是 Dart 的原样做法：`exceptionDates`（删单次）与
     * 系列范围两端都靠 `occursOn` 一次判掉，跳步实现会漏掉例外日。
     */
    internal fun expandOccurrenceDates(
        item: ScheduleItem,
        fromDate: LocalDateTime,
        toDate: LocalDateTime,
    ): List<LocalDateTime> {
        val startDay = icsDateOnly(item.startDate).toLocalDate()
        val endDay = icsDateOnly(item.endDate).toLocalDate()
        val firstDay = if (fromDate.toLocalDate().isAfter(startDay)) {
            fromDate.toLocalDate()
        } else {
            startDay
        }
        val lastDay = if (toDate.toLocalDate().isBefore(endDay)) toDate.toLocalDate() else endDay
        if (lastDay.isBefore(firstDay)) return emptyList()

        val occurrences = mutableListOf<LocalDateTime>()
        var current = firstDay
        while (!current.isAfter(lastDay)) {
            val currentDateTime = current.atStartOfDay()
            if (item.occursOn(currentDateTime)) occurrences.add(currentDateTime)
            current = current.plusDays(1)
        }
        return occurrences
    }

    /** Dart `_dateRangesOverlap`（日程区间与导出区间是否有交集，日期归零后闭区间）。 */
    internal fun dateRangesOverlap(
        startA: LocalDateTime,
        endA: LocalDateTime,
        startB: LocalDateTime,
        endB: LocalDateTime,
    ): Boolean {
        val aStart = icsDateOnly(startA)
        val aEnd = icsDateOnly(endA)
        val bStart = icsDateOnly(startB)
        val bEnd = icsDateOnly(endB)
        return !aEnd.isBefore(bStart) && !aStart.isAfter(bEnd)
    }

    // ------------------------------------------------------------------
    // 通用事件构造（Dart `_buildTimedEvent`：443-490 的 kind 无关部分）
    // ------------------------------------------------------------------

    /**
     * 由「日期 + 起止钟点」构造一条日历事件。
     *
     * - 开始时间不允许 `24:00`（没有「当天结束」语义，`transfer.parseIcsTime` 会返回 null）；
     * - 结束时间 `24:00` 落到**次日零点**；
     * - 结束不晚于开始 → 结束日期 +1 天（跨夜）；
     * - 任一钟点解析失败返回 null（整条丢弃，与 Dart 同口径）。
     *
     * 课程那条走 `transfer.buildCourseTimedEvent`（已带单测），本函数只服务考试与日程。
     */
    internal fun buildTimedEvent(
        profileId: String,
        kind: IcsExportEventKind,
        sourceId: String,
        occurrenceDate: LocalDateTime,
        startTime: String,
        endTime: String,
        summary: String,
        location: String? = null,
        description: String? = null,
        eventDate: LocalDateTime? = null,
        endDate: LocalDateTime? = null,
    ): IcsCalendarEvent? {
        val startParts = parseIcsTime(startTime) ?: return null
        val endParts = parseIcsTime(endTime, allowEndOfDay = true) ?: return null

        val startDay = icsDateOnly(eventDate ?: occurrenceDate)
        val start = startDay.withHour(startParts.hour)
            .withMinute(startParts.minute)
            .withSecond(startParts.second)
            .withNano(0)

        val endDay = icsDateOnly(endDate ?: startDay)
        // Dart `DateTime(y, m, d, 24, 0, 0)` 自动进位到次日 00:00；Kotlin 的 withHour 会抛，
        // 所以显式进位（只对结束时间合法，开始时间在上面已经排除了 24:00）。
        var end = if (endParts.hour == 24) {
            endDay.plusDays(1).withHour(0).withMinute(endParts.minute)
                .withSecond(endParts.second).withNano(0)
        } else {
            endDay.withHour(endParts.hour).withMinute(endParts.minute)
                .withSecond(endParts.second).withNano(0)
        }
        if (!end.isAfter(start)) {
            end = end.plusDays(1)
        }

        return IcsCalendarEvent(
            uid = buildTimedUid(profileId, kind, sourceId, occurrenceDate, start, end),
            kind = kind,
            start = start,
            end = end,
            summary = summary,
            location = location,
            description = description,
        )
    }

    /**
     * 事件 uid（Dart `_buildTimedEvent`：471-479）：
     * `sha256("profileId|kind|sourceId|occurrenceDate|HH:mm:ss|HH:mm:ss")@qingyu-timetable.local`。
     *
     * 与 `transfer.buildCourseUid` 同一套物料，只是 kind 与 sourceId 由调用方给
     * （课程那条把 kind 钉成 `course`）。两份实现共用同一个后缀常量与同样的字段顺序，
     * 改一处必须同步另一处——`IcsEventCollectionTest` 里钉了两者一致。
     */
    internal fun buildTimedUid(
        profileId: String,
        kind: IcsExportEventKind,
        sourceId: String,
        occurrenceDate: LocalDateTime,
        start: LocalDateTime,
        end: LocalDateTime,
    ): String {
        val material = listOf(
            profileId,
            kind.value,
            sourceId,
            formatIcsCalendarDate(icsDateOnly(occurrenceDate)),
            formatIcsClock(start),
            formatIcsClock(end),
        ).joinToString("|")
        return sha256Hex(material) + "@qingyu-timetable.local"
    }

    private fun sha256Hex(text: String): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(text.toByteArray(Charsets.UTF_8))
        val builder = StringBuilder(digest.size * 2)
        for (byte in digest) {
            val value = byte.toInt() and 0xFF
            builder.append("0123456789abcdef"[value ushr 4])
            builder.append("0123456789abcdef"[value and 0x0F])
        }
        return builder.toString()
    }
}
