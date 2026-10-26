package com.mutx163.qingyu.transfer

import com.mutx163.qingyu.core.Course
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * ICS 导入解析端口测试。
 * dart 源：lib/services/ics_import_service.dart；
 * 抄录用例：test/services/ics_import_service_test.dart、
 * test/services/ics_text_unescape_test.dart。
 */
class IcsImportParserTest {

    private val now = LocalDateTime.of(2026, 1, 1, 0, 0)

    private fun wakeupEvent(
        summary: String,
        location: String,
        description: String,
        dtstart: String = "20260302T082000",
        dtend: String = "20260302T100000",
        rrule: String = "FREQ=WEEKLY;UNTIL=20260615T160000Z;INTERVAL=1",
    ): String = """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//YZune//WakeUpSchedule//EN
        BEGIN:VEVENT
        SUMMARY:$summary
        DTSTART;TZID=/Asia/Shanghai:$dtstart
        DTEND;TZID=/Asia/Shanghai:$dtend
        RRULE:FREQ=WEEKLY;UNTIL=$rrule
        LOCATION:$location
        DESCRIPTION:$description
        END:VEVENT
        END:VCALENDAR
    """.trimIndent()

    // ------------------------------------------------------------------
    // 基本解析（ics_import_service_test.dart）
    // ------------------------------------------------------------------

    @Test
    fun imports_single_week_event_with_correct_weeks() {
        // [Dart抄录] ics_import_service_test.dart:17-51
        // （基准课 UNTIL=20260308 → 第 1 周；程序设计 0411 → 第 6 周）
        val content = """
            BEGIN:VCALENDAR
            VERSION:2.0
            PRODID:-//YZune//WakeUpSchedule//EN
            BEGIN:VEVENT
            SUMMARY:基准课[16][必修]
            DTSTART;TZID=/Asia/Shanghai:20260302T082000
            DTEND;TZID=/Asia/Shanghai:20260302T100000
            RRULE:FREQ=WEEKLY;UNTIL=20260308T160000Z;INTERVAL=1
            LOCATION:A101 张老师
            DESCRIPTION:第1 - 2节\nA101\n张老师
            END:VEVENT
            BEGIN:VEVENT
            SUMMARY:程序设计技术基础[32][必修]
            DTSTART;TZID=/Asia/Shanghai:20260411T103000
            DTEND;TZID=/Asia/Shanghai:20260411T121000
            RRULE:FREQ=WEEKLY;UNTIL=20260417T160000Z;INTERVAL=1
            LOCATION:A主201 黄群惠
            DESCRIPTION:第3 - 4节\nA主201\n黄群惠
            END:VEVENT
            END:VCALENDAR
        """.trimIndent()

        val result = IcsImportParser.parseWakeUpSchedule(content, now)
        val course = result.courses.single { it.name == "程序设计技术基础" }
        assertEquals(6, course.startWeek)
        assertEquals(6, course.endWeek)
        val base = result.courses.single { it.name == "基准课" }
        assertEquals(1, base.startWeek)
        assertEquals(1, base.endWeek)
        assertEquals("张老师", base.teacher)
        assertEquals("A101", base.location)
        assertEquals(1, base.dayOfWeek)
        assertEquals(1, base.startSection)
        assertEquals(2, base.endSection)
        assertEquals("08:20", base.startTime)
        assertEquals("10:00", base.endTime)
    }

    @Test
    fun imports_continuous_weekly_event_with_correct_end_week() {
        // [Dart抄录] ics_import_service_test.dart:53-74
        // （UNTIL 当天 16:00Z 晚于上课时刻 16:00 本地同刻——边界按绝对时长算）
        val content = """
            BEGIN:VCALENDAR
            VERSION:2.0
            PRODID:-//YZune//WakeUpSchedule//EN
            BEGIN:VEVENT
            SUMMARY:机械制造技术[56][必修]
            DTSTART;TZID=/Asia/Shanghai:20260302T160000
            DTEND;TZID=/Asia/Shanghai:20260302T174000
            RRULE:FREQ=WEEKLY;UNTIL=20260405T160000Z;INTERVAL=1
            LOCATION:A主314 曹老师
            DESCRIPTION:第7 - 8节\nA主314\n曹老师
            END:VEVENT
            END:VCALENDAR
        """.trimIndent()

        val result = IcsImportParser.parseWakeUpSchedule(content, now)
        val course = result.courses.single()
        assertEquals(1, course.startWeek)
        assertEquals(5, course.endWeek)
    }

    @Test
    fun merges_single_week_fragments_into_even_week_course() {
        // [Dart抄录] ics_import_service_test.dart:76-133
        // （0411→第6周、0425→第8周、0509→第10周，奇偶错开的 0328 第4周也并入）
        val content = """
            BEGIN:VCALENDAR
            VERSION:2.0
            PRODID:-//YZune//WakeUpSchedule//EN
            BEGIN:VEVENT
            SUMMARY:基准课[16][必修]
            DTSTART;TZID=/Asia/Shanghai:20260302T082000
            DTEND;TZID=/Asia/Shanghai:20260302T100000
            RRULE:FREQ=WEEKLY;UNTIL=20260308T160000Z;INTERVAL=1
            LOCATION:A101 张老师
            DESCRIPTION:第1 - 2节\nA101\n张老师
            END:VEVENT
            BEGIN:VEVENT
            SUMMARY:程序设计技术基础[32][必修]
            DTSTART;TZID=/Asia/Shanghai:20260328T103000
            DTEND;TZID=/Asia/Shanghai:20260328T121000
            RRULE:FREQ=WEEKLY;UNTIL=20260403T160000Z;INTERVAL=1
            LOCATION:A主201 黄群惠
            DESCRIPTION:第3 - 4节\nA主201\n黄群惠
            END:VEVENT
            BEGIN:VEVENT
            SUMMARY:程序设计技术基础[32][必修]
            DTSTART;TZID=/Asia/Shanghai:20260411T103000
            DTEND;TZID=/Asia/Shanghai:20260411T121000
            RRULE:FREQ=WEEKLY;UNTIL=20260417T160000Z;INTERVAL=1
            LOCATION:A主201 黄群惠
            DESCRIPTION:第3 - 4节\nA主201\n黄群惠
            END:VEVENT
            BEGIN:VEVENT
            SUMMARY:程序设计技术基础[32][必修]
            DTSTART;TZID=/Asia/Shanghai:20260425T103000
            DTEND;TZID=/Asia/Shanghai:20260425T121000
            RRULE:FREQ=WEEKLY;UNTIL=20260501T160000Z;INTERVAL=1
            LOCATION:A主201 黄群惠
            DESCRIPTION:第3 - 4节\nA主201\n黄群惠
            END:VEVENT
            BEGIN:VEVENT
            SUMMARY:程序设计技术基础[32][必修]
            DTSTART;TZID=/Asia/Shanghai:20260509T103000
            DTEND;TZID=/Asia/Shanghai:20260509T121000
            RRULE:FREQ=WEEKLY;UNTIL=20260515T160000Z;INTERVAL=1
            LOCATION:A主201 黄群惠
            DESCRIPTION:第3 - 4节\nA主201\n黄群惠
            END:VEVENT
            END:VCALENDAR
        """.trimIndent()

        val result = IcsImportParser.parseWakeUpSchedule(content, now)
        val course = result.courses.single { it.name == "程序设计技术基础" }
        assertEquals(4, course.startWeek)
        assertEquals(10, course.endWeek)
        assertFalse(course.isOddWeek)
        assertTrue(course.isEvenWeek)
    }

    @Test
    fun keeps_full_campus_text_when_description_provides_location() {
        // [Dart抄录] ics_import_service_test.dart:135-159
        val content = wakeupEvent(
            summary = "进阶通用英语(S1110026)",
            location = "奉贤校区 一教C104 白玮玮(讲师)(主讲)",
            description = "第1 - 2节\\n奉贤校区 一教C104\\n白玮玮(讲师)(主讲)",
        )
        val result = IcsImportParser.parseWakeUpSchedule(content, now)
        val course = result.courses.single()
        assertEquals("奉贤校区 一教C104", course.location)
        assertEquals("白玮玮(讲师)(主讲)", course.teacher)
    }

    @Test
    fun returns_empty_result_when_dtstart_unparseable() {
        // [Dart抄录] ics_import_service_test.dart:161-179
        val content = """
            BEGIN:VCALENDAR
            VERSION:2.0
            BEGIN:VEVENT
            SUMMARY:坏课
            DESCRIPTION:第1 - 2节\nA101\n张老师
            DTSTART:invalid
            DTEND:invalid
            END:VEVENT
            END:VCALENDAR
        """.trimIndent()
        val result = IcsImportParser.parseWakeUpSchedule(content, now)
        assertTrue(result.courses.isEmpty())
        assertEquals(now, result.semesterStart)
    }

    @Test
    fun marks_biweekly_interval2_as_odd_weeks() {
        // [Dart抄录] ics_import_service_test.dart:206-231
        val content = """
            BEGIN:VCALENDAR
            VERSION:2.0
            PRODID:-//YZune//WakeUpSchedule//EN
            BEGIN:VEVENT
            SUMMARY:双周实验[16][必修]
            DTSTART;TZID=/Asia/Shanghai:20260302T082000
            DTEND;TZID=/Asia/Shanghai:20260302T100000
            RRULE:FREQ=WEEKLY;UNTIL=20260524T160000Z;INTERVAL=2
            LOCATION:B201 李老师
            DESCRIPTION:第1 - 2节\nB201\n李老师
            END:VEVENT
            END:VCALENDAR
        """.trimIndent()

        val result = IcsImportParser.parseWakeUpSchedule(content, now)
        val course = result.courses.single()
        assertEquals(1, course.startWeek)
        assertTrue(course.isOddWeek)
        assertFalse(course.isEvenWeek)
        assertTrue(course.isInWeek(1))
        assertFalse(course.isInWeek(2))
        assertTrue(course.isInWeek(3))
    }

    @Test
    fun clamps_far_future_until_to_thirty_weeks() {
        // [Dart抄录] ics_import_service_test.dart:233-261
        val content = """
            BEGIN:VCALENDAR
            VERSION:2.0
            PRODID:-//YZune//WakeUpSchedule//EN
            BEGIN:VEVENT
            SUMMARY:恶意长周期[16][教室]
            DTSTART;TZID=/Asia/Shanghai:20260302T082000
            DTEND;TZID=/Asia/Shanghai:20260302T100000
            RRULE:FREQ=WEEKLY;UNTIL=99991231T160000Z;INTERVAL=1
            LOCATION:C301 教学楼
            DESCRIPTION:第1 - 2节\nC301\n教学楼
            END:VEVENT
            END:VCALENDAR
        """.trimIndent()

        val result = IcsImportParser.parseWakeUpSchedule(content, now)
        val course = result.courses.single()
        assertEquals(1, course.startWeek)
        assertTrue(course.endWeek <= 30)
        assertTrue(course.activeWeeks.size <= 30)
        assertTrue(course.hasActiveWeekOnOrAfter(30))
    }

    // ------------------------------------------------------------------
    // 文本反转义（ics_text_unescape_test.dart，走完整解析链）
    // ------------------------------------------------------------------

    @Test
    fun unescape_comma_and_colon_in_course_name() {
        // [Dart抄录] ics_text_unescape_test.dart:32-45
        val result = IcsImportParser.parseWakeUpSchedule(
            wakeupEvent(
                summary = "高等数学\\, 实验[16][必修]",
                location = "教一\\, 202",
                description = "第1 - 2节\\n教一, 202\\n王\\;老师",
            ),
            now,
        )
        val course = result.courses.single()
        assertEquals("高等数学, 实验", course.name)
        assertEquals("教一, 202", course.location)
        assertEquals("王;老师", course.teacher)
    }

    @Test
    fun unescape_newline_still_splits_description() {
        // [Dart抄录] ics_text_unescape_test.dart:47-62
        val result = IcsImportParser.parseWakeUpSchedule(
            wakeupEvent(
                summary = "线性代数[8][必修]",
                location = "B101",
                description = "第3 - 4节\\nB101\\n李老师",
            ),
            now,
        )
        val course = result.courses.single()
        assertEquals("线性代数", course.name)
        assertEquals(3, course.startSection)
        assertEquals(4, course.endSection)
        assertEquals("B101", course.location)
        assertEquals("李老师", course.teacher)
    }

    @Test
    fun unescape_double_backslash_yields_literal_backslash() {
        // [Dart抄录] ics_text_unescape_test.dart:65-76
        val result = IcsImportParser.parseWakeUpSchedule(
            wakeupEvent(
                summary = "编译原理\\\\n实验[8][必修]",
                location = "C\\主楼",
                description = "第5 - 6节\\nC\\主楼\\n周老师",
            ),
            now,
        )
        val course = result.courses.single()
        assertEquals("编译原理\\n实验", course.name)
        assertEquals("C\\主楼", course.location)
    }

    @Test
    fun rrule_values_not_unescaped() {
        // [Dart抄录] ics_text_unescape_test.dart:87-101
        // （UNTIL 的冒号/分号必须保持原样才能解析出第 16 周）
        val result = IcsImportParser.parseWakeUpSchedule(
            wakeupEvent(
                summary = "结构力学[8][必修]",
                location = "D303",
                description = "第7 - 8节\\nD303\\n赵老师",
                rrule = "FREQ=WEEKLY;UNTIL=20260615T160000Z;INTERVAL=1",
            ),
            now,
        )
        val course = result.courses.single()
        assertEquals(1, course.startWeek)
        assertEquals(16, course.endWeek)
    }

    // ------------------------------------------------------------------
    // 纯函数单测（parseLocalDateTime / unfoldLines / cleanSummary）
    // ------------------------------------------------------------------

    @Test
    fun parseLocalDateTime_local_and_malformed() {
        // [Dart推演] 无 Z 后缀按本地墙上时刻
        assertEquals(
            LocalDateTime.of(2026, 3, 2, 8, 20, 0),
            IcsImportParser.parseLocalDateTime("20260302T082000"),
        )
        // [Dart推演] 带秒的 6 位时间
        assertEquals(
            LocalDateTime.of(2026, 3, 2, 8, 20, 30),
            IcsImportParser.parseLocalDateTime("20260302T082030"),
        )
        // [Dart推演] 畸形串
        assertNull(IcsImportParser.parseLocalDateTime("invalid"))
        assertNull(IcsImportParser.parseLocalDateTime("20260302"))
        assertNull(IcsImportParser.parseLocalDateTime(null))
    }

    @Test
    fun unfoldLines_joins_continuation_lines() {
        // [Dart推演] RFC 5545 折行还原：空格/Tab 起头的行剥掉首字符接回上一行
        val unfolded = IcsImportParser.unfoldLines("SUMMARY:高等数学\r\n 数学\n\t实验")
        assertEquals(listOf("SUMMARY:高等数学数学实验"), unfolded)
        // 首行就是折行时没有上一行，保持原样
        val firstContinuation = IcsImportParser.unfoldLines(" A\nB")
        assertEquals(listOf(" A", "B"), firstContinuation)
    }

    @Test
    fun cleanSummary_strips_wakeup_suffix() {
        // [Dart抄录] ics_import_service.dart:294-296 + 各用例 SUMMARY
        assertEquals("基准课", IcsImportParser.cleanSummary("基准课[16][必修]"))
        // 反斜杠转义由 unescapeIcsText 在更早的解析步骤处理；cleanSummary 只剥
        // [数字][文字] 尾巴，不动正文里的反斜杠（[Dart抄录] 正则逐字对齐）
        assertEquals("高等数学\\, 实验", IcsImportParser.cleanSummary("高等数学\\, 实验[16][必修]"))
        // [人推] 无尾巴的原样（trim 后）
        assertEquals("体育", IcsImportParser.cleanSummary("体育 "))
        // [人推] 尾巴不完整时不剥
        assertEquals("课[16]", IcsImportParser.cleanSummary("课[16]"))
    }

    @Test
    fun semester_start_is_monday_of_first_event_week() {
        // [Dart抄录] ics_import_service_test.dart:181-204（semesterStart = 首事件所在周周一）
        val content = """
            BEGIN:VCALENDAR
            VERSION:2.0
            BEGIN:VEVENT
            SUMMARY:周三课
            DTSTART;TZID=/Asia/Shanghai:20260304T082000
            DTEND;TZID=/Asia/Shanghai:20260304T100000
            RRULE:FREQ=WEEKLY;UNTIL=20260308T160000Z;INTERVAL=1
            LOCATION:A101 张老师
            DESCRIPTION:第1 - 2节\nA101\n张老师
            END:VEVENT
            END:VCALENDAR
        """.trimIndent()
        val result = IcsImportParser.parseWakeUpSchedule(content, now)
        assertEquals(LocalDateTime.of(2026, 3, 2, 0, 0), result.semesterStart)
    }

    // ------------------------------------------------------------------
    // 边界：UNTIL 当天早于上课时刻（绝对时长语义的钉子）
    // ------------------------------------------------------------------

    @Test
    fun until_before_start_time_on_same_day_counts_previous_occurrence() {
        // [Dart推演] 2026-03-02（周一）16:00 上课，UNTIL=20260302T060000Z（比 16:00 早）
        // 差值为负 → 回落 startWeek（ics_import_service.dart:452-454）
        val content = wakeupEvent(
            summary = "早界课",
            location = "A101 张老师",
            description = "第1 - 2节\\nA101\\n张老师",
            dtstart = "20260302T160000",
            dtend = "20260302T174000",
            rrule = "FREQ=WEEKLY;UNTIL=20260302T060000Z;INTERVAL=1",
        )
        val result = IcsImportParser.parseWakeUpSchedule(content, now)
        val course = result.courses.single()
        assertEquals(1, course.startWeek)
        assertEquals(1, course.endWeek)
    }

    @Test
    fun multiple_events_sorted_by_day_section_week() {
        // [Dart抄录] mergeAlternatingWeekCourses 末尾的排序（:360-370）
        val content = """
            BEGIN:VCALENDAR
            VERSION:2.0
            BEGIN:VEVENT
            SUMMARY:周三课[2][必修]
            DTSTART;TZID=/Asia/Shanghai:20260304T082000
            DTEND;TZID=/Asia/Shanghai:20260304T100000
            RRULE:FREQ=WEEKLY;UNTIL=20260308T160000Z;INTERVAL=1
            LOCATION:A 张
            DESCRIPTION:第1 - 2节\nA\n张
            END:VEVENT
            BEGIN:VEVENT
            SUMMARY:周一课[1][必修]
            DTSTART;TZID=/Asia/Shanghai:20260302T082000
            DTEND;TZID=/Asia/Shanghai:20260302T100000
            RRULE:FREQ=WEEKLY;UNTIL=20260308T160000Z;INTERVAL=1
            LOCATION:B 李
            DESCRIPTION:第1 - 2节\nB\n李
            END:VEVENT
            END:VCALENDAR
        """.trimIndent()
        val result = IcsImportParser.parseWakeUpSchedule(content, now)
        assertEquals(listOf("周一课", "周三课"), result.courses.map { it.name })
    }
}
