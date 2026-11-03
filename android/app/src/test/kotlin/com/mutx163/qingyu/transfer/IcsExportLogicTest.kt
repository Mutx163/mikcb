package com.mutx163.qingyu.transfer

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseSessionNote
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * ICS 序列化与课程事件收集端口测试。
 * dart 源：lib/services/ics_export_service.dart；
 * 抄录用例：test/services/ics_export_service_test.dart、
 * test/services/ics_export_end_of_day_test.dart。
 */
class IcsExportLogicTest {

    // ------------------------------------------------------------------
    // 序列化（_serializeCalendar，ics_export_service.dart:492-538）
    // ------------------------------------------------------------------

    private fun utcText(local: LocalDateTime): String = formatIcsUtcDateTime(local)

    @Test
    fun serialize_calendar_header_and_crlf() {
        // [Dart抄录] ics_export_service_test.dart:305-319（空 profile 的 VCALENDAR 形态）
        val generatedAt = LocalDateTime.of(2026, 4, 1, 12, 34, 56)
        val content = IcsSerializer.serializeCalendar(
            calendarName = "主课表 2026-03-01 - 2026-04-30",
            fromDate = LocalDateTime.of(2026, 3, 1, 0, 0),
            toDate = LocalDateTime.of(2026, 4, 30, 0, 0),
            generatedAt = generatedAt,
            events = emptyList(),
        )
        assertTrue(content.startsWith("BEGIN:VCALENDAR\r\n"))
        assertTrue(content.contains("VERSION:2.0\r\n"))
        assertTrue(content.endsWith("END:VCALENDAR\r\n"))
        assertFalse(content.contains("BEGIN:VEVENT"))
        // [Dart抄录] :510 —— GENERATED-AT 是头行（DTSTAMP 是事件行，无事件时不存在）
        assertTrue(content.contains("X-MIKCB-GENERATED-AT:${utcText(generatedAt)}"))
        // [Dart推演] 头部行序（ics_export_service.dart:502-512）
        val lines = content.split("\r\n")
        assertEquals(
            listOf(
                "BEGIN:VCALENDAR",
                "PRODID:-//Mutx163//Qingyu Timetable//EN",
                "VERSION:2.0",
                "CALSCALE:GREGORIAN",
                "METHOD:PUBLISH",
                "X-WR-TIMEZONE:UTC",
                "X-MIKCB-SOURCE:Qingyu Timetable",
                "X-MIKCB-GENERATED-AT:${utcText(generatedAt)}",
                "X-MIKCB-DATE-RANGE:2026-03-01/2026-04-30",
                "X-WR-CALNAME:主课表 2026-03-01 - 2026-04-30",
            ),
            lines.subList(0, 10),
        )
    }

    @Test
    fun serialize_event_block_and_text_escaping() {
        // [Dart抄录] ics_export_service_test.dart:233-272
        val event = IcsCalendarEvent(
            uid = "abc123@qingyu-timetable.local",
            kind = IcsExportEventKind.COURSE,
            start = LocalDateTime.of(2026, 3, 2, 8, 0, 0),
            end = LocalDateTime.of(2026, 3, 2, 10, 0, 0),
            summary = "中文,课程;专题\\路径",
            location = "A101,主楼;\\南区",
            // 90 字节中文：确保 DESCRIPTION 行超过 75 字节触发 folding
            // （Dart 原文 List.filled(80, '备注内容')，ics_export_service_test.dart:239）
            description = "第一行\n第二行,备注;\\路径" + "备注内容".repeat(80),
        )
        val content = IcsSerializer.serializeCalendar(
            calendarName = "x",
            fromDate = LocalDateTime.of(2026, 3, 1, 0, 0),
            toDate = LocalDateTime.of(2026, 3, 31, 0, 0),
            generatedAt = LocalDateTime.of(2026, 4, 1, 12, 0, 0),
            events = listOf(event),
        )
        assertTrue(content.endsWith("\r\n"))
        // 除 CRLF 外无裸 \n / \r
        assertFalse(content.replace("\r\n", "").contains("\n"))
        assertFalse(content.replace("\r\n", "").contains("\r"))
        // [Dart抄录] ics_export_service_test.dart:262-265 —— 每行不超过 75 字节
        for (line in content.split("\r\n")) {
            if (line.isNotEmpty()) {
                assertTrue(
                    "line too long: ${line.take(30)}",
                    line.toByteArray(Charsets.UTF_8).size <= 75,
                )
            }
        }
        // 长描述触发折叠：折行必出现，且剥掉引导空格拼回后 DESCRIPTION 与
        // unfold 属性值一致（[Dart推演] 12 前缀 + 90 字节中文必然 > 75）
        val longLines = content.split("\r\n").filter { it.startsWith(" ") }
        assertTrue("期望出现折行续行", longLines.isNotEmpty())
        // fold → unfold 往返：unfold 后的 DESCRIPTION 行应还原出完整转义值
        val unfoldedDescriptionLine = unfoldIcsLines(content)
            .first { it.startsWith("DESCRIPTION:") }
        assertEquals(
            unfoldIcsTest(content)["DESCRIPTION"],
            unfoldedDescriptionLine.removePrefix("DESCRIPTION:"),
        )
        val properties = unfoldIcsTest(content)
        assertEquals("中文\\,课程\\;专题\\\\路径", properties["SUMMARY"])
        assertEquals("A101\\,主楼\\;\\\\南区", properties["LOCATION"])
        assertTrue(properties["DESCRIPTION"]!!.contains("第一行\\n第二行\\,备注\\;\\\\路径"))
        assertEquals("备注内容".repeat(80), properties["DESCRIPTION"]!!.removePrefix("第一行\\n第二行\\,备注\\;\\\\路径"))
        assertEquals("course", properties["X-MIKCB-EVENT-TYPE"])
        assertEquals("abc123@qingyu-timetable.local", properties["UID"])
    }

    @Test
    fun serialize_blank_location_and_description_omitted() {
        // [Dart推演] _hasText 为 false 时整行不输出（:523-526）
        val event = IcsCalendarEvent(
            uid = "u@x",
            kind = IcsExportEventKind.COURSE,
            start = LocalDateTime.of(2026, 3, 2, 8, 0),
            end = LocalDateTime.of(2026, 3, 2, 9, 0),
            summary = "课",
            location = "   ",
            description = null,
        )
        val content = IcsSerializer.serializeCalendar(
            calendarName = "x",
            fromDate = LocalDateTime.of(2026, 3, 1, 0, 0),
            toDate = LocalDateTime.of(2026, 3, 2, 0, 0),
            generatedAt = LocalDateTime.of(2026, 4, 1, 0, 0),
            events = listOf(event),
        )
        assertFalse(content.contains("LOCATION:"))
        assertFalse(content.contains("DESCRIPTION:"))
    }

    // ------------------------------------------------------------------
    // buildCourseTimedEvent（_buildTimedEvent，ics_export_service.dart:443-490）
    // ------------------------------------------------------------------

    private fun course(
        id: String = "c1",
        name: String = "晚自习",
        dayOfWeek: Int = 1,
        startWeek: Int = 1,
        endWeek: Int = 1,
        isOddWeek: Boolean = false,
        isEvenWeek: Boolean = false,
        startTime: String = "08:00",
        endTime: String = "10:00",
        teacher: String = "张老师",
        location: String = "A101",
        description: String? = null,
        sessionNotes: Map<Int, CourseSessionNote>? = null,
        customWeeks: List<Int>? = null,
    ): Course = Course(
        id = id,
        name = name,
        teacher = teacher,
        location = location,
        dayOfWeek = dayOfWeek,
        startSection = 1,
        endSection = 2,
        startTime = startTime,
        endTime = endTime,
        startWeek = startWeek,
        endWeek = endWeek,
        isOddWeek = isOddWeek,
        isEvenWeek = isEvenWeek,
        customWeeks = customWeeks,
        description = description,
        sessionNotes = sessionNotes,
    )

    @Test
    fun timedEvent_end_of_day_rolls_to_next_midnight() {
        // [Dart抄录] ics_export_end_of_day_test.dart:65-74
        val event = buildCourseTimedEvent(
            profileId = "profile-1",
            course = course(startTime = "22:00", endTime = "24:00"),
            occurrenceDate = LocalDateTime.of(2026, 3, 2, 0, 0),
            week = 1,
        )
        assertNotNull(event)
        assertEquals(LocalDateTime.of(2026, 3, 2, 22, 0), event!!.start)
        assertEquals(LocalDateTime.of(2026, 3, 3, 0, 0), event.end)
    }

    @Test
    fun timedEvent_rejects_silent_normalizing_clocks() {
        // [Dart抄录] ics_export_end_of_day_test.dart:76-85
        assertNull(
            buildCourseTimedEvent(
                "profile-1",
                course(startTime = "22:00", endTime = "24:30"),
                LocalDateTime.of(2026, 3, 2, 0, 0),
                1,
            ),
        )
        assertNull(
            buildCourseTimedEvent(
                "profile-1",
                course(startTime = "22:00", endTime = "25:00"),
                LocalDateTime.of(2026, 3, 2, 0, 0),
                1,
            ),
        )
        // 24:00 当开始时间非法
        assertNull(
            buildCourseTimedEvent(
                "profile-1",
                course(startTime = "24:00", endTime = "24:00"),
                LocalDateTime.of(2026, 3, 2, 0, 0),
                1,
            ),
        )
    }

    @Test
    fun timedEvent_cross_midnight_class_extends_end_date() {
        // [Dart抄录] ics_export_service_test.dart:184-231（跨日日程的语义移植到课程）
        val event = buildCourseTimedEvent(
            profileId = "profile-1",
            course = course(startTime = "23:30", endTime = "01:30"),
            occurrenceDate = LocalDateTime.of(2026, 3, 21, 0, 0),
            week = 1,
        )
        assertNotNull(event)
        assertEquals(LocalDateTime.of(2026, 3, 21, 23, 30), event!!.start)
        assertEquals(LocalDateTime.of(2026, 3, 22, 1, 30), event.end)
    }

    @Test
    fun timedEvent_description_parts_and_session_note() {
        // [Dart推演] descriptionParts 的拼装与去重（:316-325, _joinDistinct）
        val event = buildCourseTimedEvent(
            profileId = "profile-1",
            course = course(
                teacher = "张老师",
                location = "A101",
                description = "课程简介",
                sessionNotes = mapOf(1 to CourseSessionNote(text = "第1周小测", hasHomework = true)),
            ),
            occurrenceDate = LocalDateTime.of(2026, 3, 2, 0, 0),
            week = 1,
        )
        assertNotNull(event)
        val parts = event!!.description!!.split("\n")
        assertEquals(
            listOf("Teacher: 张老师", "Sections: 1-2", "课程简介", "第1周小测", "Homework: yes"),
            parts,
        )
        // 不带 sessionNote 的周没有那两行
        val otherWeek = buildCourseTimedEvent(
            profileId = "profile-1",
            course = course(description = "课程简介"),
            occurrenceDate = LocalDateTime.of(2026, 3, 9, 0, 0),
            week = 2,
        )!!
        assertFalse(otherWeek.description!!.contains("Homework: yes"))
    }

    @Test
    fun timedEvent_uid_is_sha256_of_material_and_hides_ids() {
        // [Dart抄录] ics_export_service_test.dart:274-303（UID 稳定且不泄露课程 id）
        val event = buildCourseTimedEvent(
            profileId = "profile-1",
            course = course(id = "private-course-id", startTime = "08:00", endTime = "10:00"),
            occurrenceDate = LocalDateTime.of(2026, 3, 2, 0, 0),
            week = 1,
        )!!
        // 独立重算 sha256（[人推]）：material 与 Dart :471-478 逐项一致
        val material = "profile-1|course|private-course-id|2026-03-02|08:00:00|10:00:00"
        val digest = java.security.MessageDigest.getInstance("SHA-256")
            .digest(material.toByteArray(Charsets.UTF_8))
        val expectedHex = digest.joinToString("") { "%02x".format(it) }
        assertEquals("$expectedHex@qingyu-timetable.local", event.uid)
        assertFalse(event.uid.contains("private-course-id"))
    }

    // ------------------------------------------------------------------
    // collectCourseEvents（_courseEvents，ics_export_service.dart:284-343）
    // ------------------------------------------------------------------

    @Test
    fun collect_expands_weeks_with_monday_anchor() {
        // [Dart抄录] ics_export_service_test.dart:60-139（2026-03-02 是周一）
        val courses = listOf(
            course(id = "continuous", name = "连续课", endWeek = 4),
            course(
                id = "odd", name = "单周课", dayOfWeek = 2, endWeek = 4,
                isOddWeek = true, startTime = "08:00", endTime = "10:00",
            ),
            course(id = "custom", name = "自定义周课", dayOfWeek = 4, customWeeks = listOf(2, 4)),
        )
        val result = collectCourseEvents(
            profileId = "profile-1",
            courses = courses,
            semesterStartDate = LocalDateTime.of(2026, 3, 2, 0, 0),
            fromDate = LocalDateTime.of(2026, 3, 1, 0, 0),
            toDate = LocalDateTime.of(2026, 4, 30, 0, 0),
        )
        // 连续 4 周 + 单周课第1/3周（周二）+ 自定义第2/4周（周四）= 8
        assertEquals(8, result.events.size)
        assertEquals(0, result.skippedHolidayCourses)
        val summaries = result.events.map { it.summary }
        assertTrue(summaries.containsAll(listOf("连续课", "单周课", "自定义周课")))
        // 连续课第 1 周：2026-03-02 08:00（[Dart抄录] :105-110 的 UTC 换算本地化）
        val first = result.events.first { it.summary == "连续课" && it.start.dayOfMonth == 2 }
        assertEquals(LocalDateTime.of(2026, 3, 2, 8, 0, 0), first.start)
        // 单周课只落在第 1、3 周的周二（03-03、03-17）
        val oddDays = result.events.filter { it.summary == "单周课" }.map { it.start.dayOfMonth }
        assertEquals(listOf(3, 17), oddDays)
        // 自定义周课落在第 2、4 周的周四（03-12、03-26）
        val customDays = result.events.filter { it.summary == "自定义周课" }.map { it.start.dayOfMonth }
        assertEquals(listOf(12, 26), customDays)
    }

    @Test
    fun collect_filters_range_and_counts_holiday_skips() {
        // [Dart抄录] ics_export_service_test.dart:141-171（区间过滤）
        // 与 :352-369 / :499-518（节假日跳过计数）
        val courses = listOf(
            course(id = "mon", name = "周一课"),
            course(id = "tue", name = "周二课", dayOfWeek = 2),
        )
        val base = listOf(
            LocalDateTime.of(2026, 3, 1, 0, 0),
            LocalDateTime.of(2026, 3, 7, 0, 0),
        )
        val plain = collectCourseEvents(
            "profile-1", courses, LocalDateTime.of(2026, 3, 2, 0, 0), base[0], base[1],
        )
        assertEquals(2, plain.events.size)
        assertEquals(0, plain.skippedHolidayCourses)
        // 2026-03-02（第1周周一）标记为假期 → 周一课被跳过并计数
        val filtered = collectCourseEvents(
            "profile-1", courses, LocalDateTime.of(2026, 3, 2, 0, 0), base[0], base[1],
            hideOn = { it.dayOfMonth == 2 },
        )
        assertEquals(1, filtered.events.size)
        assertEquals("周二课", filtered.events.single().summary)
        assertEquals(1, filtered.skippedHolidayCourses)
    }

    @Test
    fun collect_null_semester_start_returns_empty() {
        // [Dart抄录] ics_export_service.dart:287-290
        val result = collectCourseEvents(
            "profile-1",
            listOf(course()),
            semesterStartDate = null,
            fromDate = LocalDateTime.of(2026, 3, 1, 0, 0),
            toDate = LocalDateTime.of(2026, 3, 31, 0, 0),
        )
        assertTrue(result.events.isEmpty())
        assertEquals(0, result.skippedHolidayCourses)
    }

    @Test
    fun compare_events_order_start_end_kind_uid() {
        // [Dart抄录] ics_export_service.dart:540-554
        val base = LocalDateTime.of(2026, 3, 2, 8, 0)
        val earlier = IcsCalendarEvent("u1", IcsExportEventKind.COURSE, base, base.plusHours(1), "a")
        val later = IcsCalendarEvent("u2", IcsExportEventKind.COURSE, base.plusHours(1), base.plusHours(2), "b")
        assertTrue(compareIcsEvents(earlier, later) < 0)
        assertTrue(compareIcsEvents(later, earlier) > 0)
        val sameStartEarlyEnd = earlier
        val sameStartLateEnd = IcsCalendarEvent(
            "u2", IcsExportEventKind.COURSE, base, base.plusHours(2), "b",
        )
        assertTrue(compareIcsEvents(sameStartEarlyEnd, sameStartLateEnd) < 0)
        // kind 字符串序 course < schedule < exam？[Dart抄录] 按 kind.value 字典序：
        // "course" < "exam" < "schedule"
        val kindCourse = IcsCalendarEvent("u1", IcsExportEventKind.COURSE, base, base, "a")
        val kindExam = IcsCalendarEvent("u2", IcsExportEventKind.EXAM, base, base, "a")
        assertTrue(compareIcsEvents(kindCourse, kindExam) < 0)
        val kindSchedule = IcsCalendarEvent("u3", IcsExportEventKind.SCHEDULE_ITEM, base, base, "a")
        assertTrue(compareIcsEvents(kindExam, kindSchedule) < 0)
    }

    /** 测试辅助：unfold + 顶层属性抓取（对应 Dart 测试的 _events/_property）。 */
    private fun unfoldIcsTest(content: String): Map<String, String> {
        val unfolded = unfoldIcsLines(content)
        val map = LinkedHashMap<String, String>()
        for (raw in unfolded) {
            val line = raw.trim()
            if (!line.contains(":") || line.startsWith("BEGIN") || line.startsWith("END")) continue
            val idx = line.indexOf(':')
            val key = line.substring(0, idx).split(";").first()
            map.putIfAbsent(key, line.substring(idx + 1))
        }
        return map
    }
}
