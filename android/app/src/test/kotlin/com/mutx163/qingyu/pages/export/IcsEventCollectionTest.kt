package com.mutx163.qingyu.pages.export

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.ScheduleRecurrence
import com.mutx163.qingyu.transfer.IcsExportEventKind
import com.mutx163.qingyu.transfer.buildCourseUid
import com.mutx163.qingyu.transfer.formatIcsCalendarDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * `pages/export/IcsEventCollection.kt` 的单测（考试 / 日程事件收集 + 同步载荷 + 日历名）。
 *
 * 期望值全部按 Dart 源推出来的（`lib/services/ics_export_service.dart` 的
 * `_examEvents` :345-375 / `_scheduleEvents` :376-430 / `_buildTimedEvent` :443-490 /
 * `collectEvents` :216-243），**不是**从实现里抄的。
 */
class IcsEventCollectionTest {

    private val day = LocalDateTime.of(2026, 3, 5, 0, 0)

    private fun exam(
        id: String = "exam-1",
        name: String = "高等数学期末",
        dateTime: LocalDateTime = LocalDateTime.of(2026, 3, 10, 0, 0),
        startTime: String = "09:00",
        endTime: String = "11:00",
        location: String? = "A101",
        seatNumber: String? = "12",
        note: String? = "带计算器",
    ) = Exam(
        id = id,
        courseId = "course-1",
        name = name,
        dateTime = dateTime,
        startTime = startTime,
        endTime = endTime,
        location = location,
        seatNumber = seatNumber,
        note = note,
        createdAt = day,
        updatedAt = day,
    )

    private fun scheduleItem(
        id: String = "item-1",
        title: String = "组会",
        startDate: LocalDateTime = LocalDateTime.of(2026, 3, 2, 0, 0),
        endDate: LocalDateTime = LocalDateTime.of(2026, 3, 2, 0, 0),
        startTime: String = "14:00",
        endTime: String = "15:00",
        recurrence: ScheduleRecurrence = ScheduleRecurrence.NONE,
        exceptionDates: List<LocalDateTime> = emptyList(),
        seriesId: String? = null,
        occurrenceDate: LocalDateTime? = null,
        location: String? = "B203",
        note: String? = "每周一次",
    ) = ScheduleItem(
        id = id,
        title = title,
        location = location,
        note = note,
        startDate = startDate,
        endDate = endDate,
        startTime = startTime,
        endTime = endTime,
        createdAt = day,
        updatedAt = day,
        recurrence = recurrence,
        exceptionDates = exceptionDates,
        seriesId = seriesId,
        occurrenceDate = occurrenceDate,
    )

    private fun source(
        exams: List<Exam> = emptyList(),
        scheduleItems: List<ScheduleItem> = emptyList(),
        courses: List<Course> = emptyList(),
        semesterStartDate: LocalDateTime? = null,
    ) = IcsExportSource(
        profileId = "profile-1",
        profileName = "主课表",
        courses = courses,
        exams = exams,
        scheduleItems = scheduleItems,
        semesterStartDate = semesterStartDate,
    )

    // ------------------------------------------------------------------
    // 考试（Dart _examEvents）
    // ------------------------------------------------------------------

    @Test
    fun examInsideRange_becomesTimedEventWithSeatAndNote() {
        val result = IcsEventCollection.collect(
            source = source(exams = listOf(exam())),
            kinds = setOf(IcsExportEventKind.EXAM),
            from = LocalDate.of(2026, 3, 1),
            to = LocalDate.of(2026, 3, 31),
        )

        assertEquals(1, result.events.size)
        val event = result.events.single()
        assertEquals(IcsExportEventKind.EXAM, event.kind)
        assertEquals("高等数学期末", event.summary)
        assertEquals("A101", event.location)
        assertEquals(LocalDateTime.of(2026, 3, 10, 9, 0), event.start)
        assertEquals(LocalDateTime.of(2026, 3, 10, 11, 0), event.end)
        // Dart 顺序：note 在前、'Seat: xx' 在后（_examEvents :350-357）。
        assertEquals("带计算器\nSeat: 12", event.description?.replace("\\n", "\n"))
        assertTrue(event.uid.endsWith("@qingyu-timetable.local"))
    }

    @Test
    fun examOutsideRange_isDropped() {
        val result = IcsEventCollection.collect(
            source = source(exams = listOf(exam(dateTime = LocalDateTime.of(2026, 4, 10, 0, 0)))),
            kinds = setOf(IcsExportEventKind.EXAM),
            from = LocalDate.of(2026, 3, 1),
            to = LocalDate.of(2026, 3, 31),
        )
        assertTrue(result.events.isEmpty())
    }

    @Test
    fun examWithUnparsableTime_isDropped_sameAsDart() {
        // 任一时钟解析失败 ⇒ 整条丢弃（Dart `_buildTimedEvent` 返回 null）。
        val result = IcsEventCollection.collect(
            source = source(exams = listOf(exam(startTime = "25:00"))),
            kinds = setOf(IcsExportEventKind.EXAM),
            from = LocalDate.of(2026, 3, 1),
            to = LocalDate.of(2026, 3, 31),
        )
        assertTrue(result.events.isEmpty())
    }

    @Test
    fun examEndTime24_rollsToNextMidnight() {
        val result = IcsEventCollection.collect(
            source = source(exams = listOf(exam(startTime = "22:00", endTime = "24:00"))),
            kinds = setOf(IcsExportEventKind.EXAM),
            from = LocalDate.of(2026, 3, 1),
            to = LocalDate.of(2026, 3, 31),
        )
        val event = result.events.single()
        assertEquals(LocalDateTime.of(2026, 3, 10, 22, 0), event.start)
        assertEquals(LocalDateTime.of(2026, 3, 11, 0, 0), event.end)
    }

    // ------------------------------------------------------------------
    // 日程（Dart _scheduleEvents / ScheduleItem.expandInstances）
    // ------------------------------------------------------------------

    @Test
    fun oneOffScheduleInsideRange_becomesEvent() {
        val result = IcsEventCollection.collect(
            source = source(scheduleItems = listOf(scheduleItem())),
            kinds = setOf(IcsExportEventKind.SCHEDULE_ITEM),
            from = LocalDate.of(2026, 3, 1),
            to = LocalDate.of(2026, 3, 31),
        )
        val event = result.events.single()
        assertEquals(IcsExportEventKind.SCHEDULE_ITEM, event.kind)
        assertEquals("组会", event.summary)
        assertEquals("B203", event.location)
        assertEquals(LocalDateTime.of(2026, 3, 2, 14, 0), event.start)
        assertEquals(LocalDateTime.of(2026, 3, 2, 15, 0), event.end)
    }

    @Test
    fun oneOffScheduleOutsideRange_isDropped() {
        val result = IcsEventCollection.collect(
            source = source(
                scheduleItems = listOf(
                    scheduleItem(
                        startDate = LocalDateTime.of(2026, 5, 2, 0, 0),
                        endDate = LocalDateTime.of(2026, 5, 2, 0, 0),
                    ),
                ),
            ),
            kinds = setOf(IcsExportEventKind.SCHEDULE_ITEM),
            from = LocalDate.of(2026, 3, 1),
            to = LocalDate.of(2026, 3, 31),
        )
        assertTrue(result.events.isEmpty())
    }

    @Test
    fun weeklyRecurring_expandsOnlyMatchingWeekdayInsideRange() {
        // 2026-03-02 是周一；周一/周日的复用实例只应出现 03-02、03-09、03-16、03-23、03-30。
        val result = IcsEventCollection.collect(
            source = source(
                scheduleItems = listOf(
                    scheduleItem(
                        startDate = LocalDateTime.of(2026, 3, 2, 0, 0),
                        endDate = LocalDateTime.of(2026, 3, 31, 0, 0),
                        recurrence = ScheduleRecurrence.WEEKLY,
                    ),
                ),
            ),
            kinds = setOf(IcsExportEventKind.SCHEDULE_ITEM),
            from = LocalDate.of(2026, 3, 1),
            to = LocalDate.of(2026, 3, 31),
        )
        assertEquals(5, result.events.size)
        assertEquals(
            listOf(2, 9, 16, 23, 30),
            result.events.map { it.start.dayOfMonth },
        )
        assertTrue(result.events.all { it.start.dayOfWeek.value == 1 })
    }

    @Test
    fun weeklyRecurring_honoursExceptionDates() {
        val result = IcsEventCollection.collect(
            source = source(
                scheduleItems = listOf(
                    scheduleItem(
                        startDate = LocalDateTime.of(2026, 3, 2, 0, 0),
                        endDate = LocalDateTime.of(2026, 3, 31, 0, 0),
                        recurrence = ScheduleRecurrence.WEEKLY,
                        exceptionDates = listOf(LocalDateTime.of(2026, 3, 9, 0, 0)),
                    ),
                ),
            ),
            kinds = setOf(IcsExportEventKind.SCHEDULE_ITEM),
            from = LocalDate.of(2026, 3, 1),
            to = LocalDate.of(2026, 3, 31),
        )
        assertEquals(listOf(2, 16, 23, 30), result.events.map { it.start.dayOfMonth })
    }

    @Test
    fun seriesOverrideWinsOverInstanceOnSameDay() {
        // 系列（周一 03-02 所在的那一周重复）+ 一次性改期条目（seriesId 非空）落在同一天：
        // Dart 用 `isSeriesOverride` 让改期条目覆盖系列实例（_scheduleEvents :390-395）。
        val series = scheduleItem(
            id = "series-1",
            title = "系列组会",
            startDate = LocalDateTime.of(2026, 3, 2, 0, 0),
            endDate = LocalDateTime.of(2026, 3, 2, 0, 0),
            recurrence = ScheduleRecurrence.NONE,
        )
        val override = scheduleItem(
            id = "override-1",
            title = "改期组会",
            startDate = LocalDateTime.of(2026, 3, 2, 0, 0),
            endDate = LocalDateTime.of(2026, 3, 2, 0, 0),
            startTime = "16:00",
            endTime = "17:00",
            seriesId = "series-1",
            occurrenceDate = LocalDateTime.of(2026, 3, 2, 0, 0),
        )
        val result = IcsEventCollection.collect(
            source = source(scheduleItems = listOf(series, override)),
            kinds = setOf(IcsExportEventKind.SCHEDULE_ITEM),
            from = LocalDate.of(2026, 3, 1),
            to = LocalDate.of(2026, 3, 31),
        )
        assertEquals(1, result.events.size)
        assertEquals("改期组会", result.events.single().summary)
        assertEquals(LocalDateTime.of(2026, 3, 2, 16, 0), result.events.single().start)
    }

    // ------------------------------------------------------------------
    // collectEvents 外层规则
    // ------------------------------------------------------------------

    @Test
    fun reversedRange_yieldsNothing() {
        val result = IcsEventCollection.collect(
            source = source(exams = listOf(exam())),
            kinds = setOf(IcsExportEventKind.EXAM),
            from = LocalDate.of(2026, 3, 31),
            to = LocalDate.of(2026, 3, 1),
        )
        assertTrue(result.events.isEmpty())
    }

    @Test
    fun onlySelectedKindsAreCollected() {
        val src = source(exams = listOf(exam()), scheduleItems = listOf(scheduleItem()))
        val examsOnly = IcsEventCollection.collect(
            source = src,
            kinds = setOf(IcsExportEventKind.EXAM),
            from = LocalDate.of(2026, 3, 1),
            to = LocalDate.of(2026, 3, 31),
        )
        assertEquals(listOf(IcsExportEventKind.EXAM), examsOnly.events.map { it.kind })
    }

    @Test
    fun noKindsSelected_yieldsNothing() {
        val result = IcsEventCollection.collect(
            source = source(exams = listOf(exam())),
            kinds = emptySet(),
            from = LocalDate.of(2026, 3, 1),
            to = LocalDate.of(2026, 3, 31),
        )
        assertTrue(result.events.isEmpty())
    }

    @Test
    fun eventsAreSortedByStartTime() {
        val late = exam(id = "late", name = "下午场", dateTime = LocalDateTime.of(2026, 3, 20, 0, 0))
        val early = exam(id = "early", name = "上午场", dateTime = LocalDateTime.of(2026, 3, 10, 0, 0))
        val result = IcsEventCollection.collect(
            source = source(exams = listOf(late, early)),
            kinds = setOf(IcsExportEventKind.EXAM),
            from = LocalDate.of(2026, 3, 1),
            to = LocalDate.of(2026, 3, 31),
        )
        assertEquals(listOf("上午场", "下午场"), result.events.map { it.summary })
    }

    @Test
    fun holidayFilterOnlySkipsCourses_andCountsThem() {
        // 一门周一第 1-2 周都上的课；第 1 周那天标成假期 ⇒ 只少 1 节，考试不受影响。
        val course = Course(
            id = "course-1",
            name = "线性代数",
            teacher = "张老师",
            location = "B101",
            dayOfWeek = 1,
            startSection = 1,
            endSection = 2,
            startTime = "08:00",
            endTime = "09:40",
            startWeek = 1,
            endWeek = 2,
        )
        val result = IcsEventCollection.collect(
            source = source(
                courses = listOf(course),
                exams = listOf(exam(dateTime = LocalDateTime.of(2026, 3, 9, 0, 0))),
                semesterStartDate = LocalDateTime.of(2026, 3, 2, 0, 0),
            ),
            kinds = setOf(IcsExportEventKind.COURSE, IcsExportEventKind.EXAM),
            from = LocalDate.of(2026, 3, 1),
            to = LocalDate.of(2026, 3, 31),
            skipHolidayCourses = true,
            isHoliday = { date -> date == LocalDate.of(2026, 3, 2) },
        )
        assertEquals(1, result.skippedHolidayCourses)
        // 课程剩 03-09 一节；考试那天恰好也是 03-09，仍然照常导出（假期只管课程）。
        assertEquals(1, result.events.count { it.kind == IcsExportEventKind.COURSE })
        assertEquals(1, result.events.count { it.kind == IcsExportEventKind.EXAM })
    }

    @Test
    fun holidayFilterDisabled_keepsCoursesAndReportsNoSkips() {
        val course = Course(
            id = "course-1",
            name = "线性代数",
            teacher = "张老师",
            location = "B101",
            dayOfWeek = 1,
            startSection = 1,
            endSection = 2,
            startTime = "08:00",
            endTime = "09:40",
            startWeek = 1,
            endWeek = 1,
        )
        val result = IcsEventCollection.collect(
            source = source(
                courses = listOf(course),
                semesterStartDate = LocalDateTime.of(2026, 3, 2, 0, 0),
            ),
            kinds = setOf(IcsExportEventKind.COURSE),
            from = LocalDate.of(2026, 3, 1),
            to = LocalDate.of(2026, 3, 31),
            skipHolidayCourses = false,
            isHoliday = { true },
        )
        assertEquals(0, result.skippedHolidayCourses)
        assertEquals(1, result.events.size)
    }

    // ------------------------------------------------------------------
    // uid 与课程那条实现一致（防两套物料漂移）
    // ------------------------------------------------------------------

    @Test
    fun timedUid_matchesCourseUidFormula() {
        val occurrence = LocalDateTime.of(2026, 3, 2, 0, 0)
        val start = LocalDateTime.of(2026, 3, 2, 8, 0)
        val end = LocalDateTime.of(2026, 3, 2, 9, 40)
        assertEquals(
            buildCourseUid("profile-1", "course-1", occurrence, start, end),
            IcsEventCollection.buildTimedUid(
                profileId = "profile-1",
                kind = IcsExportEventKind.COURSE,
                sourceId = "course-1",
                occurrenceDate = occurrence,
                start = start,
                end = end,
            ),
        )
    }

    @Test
    fun timedUid_differsByKind() {
        val occurrence = LocalDateTime.of(2026, 3, 2, 0, 0)
        val start = LocalDateTime.of(2026, 3, 2, 8, 0)
        val end = LocalDateTime.of(2026, 3, 2, 9, 40)
        assertNotEquals(
            IcsEventCollection.buildTimedUid(
                "p", IcsExportEventKind.EXAM, "x", occurrence, start, end,
            ),
            IcsEventCollection.buildTimedUid(
                "p", IcsExportEventKind.SCHEDULE_ITEM, "x", occurrence, start, end,
            ),
        )
    }

    // ------------------------------------------------------------------
    // 同步载荷 / 日历名
    // ------------------------------------------------------------------

    @Test
    fun syncPayload_usesContractKeysAndEpochMillis() {
        val zone = ZoneId.of("Asia/Shanghai")
        val result = IcsEventCollection.collect(
            source = source(exams = listOf(exam())),
            kinds = setOf(IcsExportEventKind.EXAM),
            from = LocalDate.of(2026, 3, 1),
            to = LocalDate.of(2026, 3, 31),
        )
        val payload = IcsEventCollection.syncPayload(result.events, zone)
        val row = payload.single()
        // CalendarSync.buildSyncOps 只认这五个键。
        assertEquals(
            setOf("startMs", "endMs", "title", "location", "description"),
            row.keys,
        )
        assertEquals("高等数学期末", row["title"])
        assertEquals(
            LocalDateTime.of(2026, 3, 10, 9, 0).atZone(zone).toInstant().toEpochMilli(),
            row["startMs"],
        )
        assertEquals(
            LocalDateTime.of(2026, 3, 10, 11, 0).atZone(zone).toInstant().toEpochMilli(),
            row["endMs"],
        )
    }

    @Test
    fun exportCalendarName_matchesDartComposition() {
        assertEquals(
            "主课表 2026-03-01 - 2026-03-31",
            IcsEventCollection.exportCalendarName(
                " 主课表 ",
                LocalDate.of(2026, 3, 1),
                LocalDate.of(2026, 3, 31),
            ),
        )
    }

    @Test
    fun exportCalendarName_emptyProfileName_hasNoLeadingSpace() {
        val name = IcsEventCollection.exportCalendarName(
            "   ",
            LocalDate.of(2026, 3, 1),
            LocalDate.of(2026, 3, 31),
        )
        assertFalse(name.startsWith(" "))
        assertEquals("2026-03-01 - 2026-03-31", name)
    }

    @Test
    fun exportCalendarName_usesIsoDates() {
        // 防「拿 toIsoDate 之类的方言拼名字」：必须与 ICS 头的 X-MIKCB-DATE-RANGE 同格式。
        val name = IcsEventCollection.exportCalendarName(
            "主课表",
            LocalDate.of(2026, 1, 5),
            LocalDate.of(2026, 2, 28),
        )
        assertTrue(name.contains(formatIcsCalendarDate(LocalDate.of(2026, 1, 5).atStartOfDay())))
        assertTrue(name.contains(formatIcsCalendarDate(LocalDate.of(2026, 2, 28).atStartOfDay())))
    }
}
