package com.mutx163.qingyu.calendar

import com.mutx163.qingyu.core.ClassAlarmPlanLogic
import com.mutx163.qingyu.core.DartFormatException
import com.mutx163.qingyu.core.DartTime
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.core.minutesToClock
import java.util.Locale
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/**
 * 日期/时刻文本在**非拉丁数字** Locale 下也必须与 Dart 同字节。
 *
 * Dart 的 `toString().padLeft(2,'0')` 永远输出 ASCII；Java 的 `String.format("%02d", …)`
 * 会按默认 Locale 的零字符本地化（实测 `ar-EG`/`fa-IR`/`th-TH-u-nu-thai` 会给出
 * U+0660 系或 U+0E50 系数字）。这些串有的直接**落盘**（`semesterStartDateText`、
 * 假期快照 `dateKey`、日程 occurrenceId），一旦本地化，跨端内容哈希就会误判。
 */
class CalendarLocaleAndYearGuardTest {

    private val original: Locale = Locale.getDefault()

    @After
    fun restoreLocale() {
        Locale.setDefault(original)
    }

    @Test
    fun `非拉丁数字 Locale 下日期与时刻文本仍为 ASCII`() {
        Locale.setDefault(Locale.forLanguageTag("ar-EG"))
        val date = DartTime.dateTime(2026, 10, 1)

        assertEquals("2026-10-01", HolidayData.dateKey(date))
        assertEquals("2026-10-01", ScheduleDateRuleLogic.formatIsoDate(date))
        assertEquals("2026-10-01", ScheduleItem.formatCalendarDate(date))
        assertEquals("2026-10-01", TimetableSettings.formatSemesterStartDateText(date))
        // occurrenceId 会进日程提醒/持久化，必须是 Dart 的 `seriesId@yyyy-MM-dd`。
        assertEquals("s1@2026-10-01", ScheduleItem.buildOccurrenceId("s1", date))
        assertEquals("08:15", ClassAlarmPlanLogic.formatClock(495))
        assertEquals("08:30", minutesToClock(510))

        Locale.setDefault(Locale.forLanguageTag("fa-IR"))
        assertEquals("2026-10-01", HolidayData.dateKey(date))
        assertEquals("08:15", ClassAlarmPlanLogic.formatClock(495))

        Locale.setDefault(Locale.forLanguageTag("th-TH-u-nu-thai"))
        assertEquals("2026-10-01", HolidayData.dateKey(date))
    }

    @Test
    fun `非拉丁数字 Locale 下 JSON 控制字符转义仍是 ASCII 十六进制`() {
        Locale.setDefault(Locale.forLanguageTag("ar-EG"))
        val encoded = MiniJson.encode(linkedMapOf("v" to "a\u0001b"))
        // Dart jsonEncode：\u0001（小写、四位、ASCII）——本地化后会是 U+0660 系数字，
        // 落盘的 JSON 字节与 Dart 不同。
        assertTrue(encoded, encoded.contains("\\u0001"))
        assertTrue("不应出现非 ASCII 十六进制数字：$encoded", encoded.all { it.code < 128 })
    }

    @Test
    fun `年份 0-99 的日期规则解析与 Dart DateTime 构造一致地返回 null`() {
        // Dart `DateTime(y, m, d)` 对 y∈0..99 解释为 1900+y，回读比对 `parsed.year != y`
        // 必然失败 → null。Kotlin 的 LocalDate 会老实造出 0028 年，需要显式对齐。
        assertNull(ScheduleDateRuleLogic.parseIsoDate("0028-02-29"))
        assertNull(ScheduleDateRuleLogic.parseIsoDate("0028-02-28"))
        assertNull(ScheduleDateRuleLogic.parseIsoDate("0099-12-31"))
        assertEquals(
            DartTime.dateTime(1928, 2, 29),
            ScheduleDateRuleLogic.parseIsoDate("1928-02-29"),
        )
        assertEquals(
            DartTime.dateTime(2028, 2, 29),
            ScheduleDateRuleLogic.parseIsoDate("2028-02-29"),
        )
        assertNull("平年 2-29 仍按 Dart 归一后拒绝", ScheduleDateRuleLogic.parseIsoDate("2023-02-29"))
    }

    @Test
    fun `假期快照缺 year 时抛 DartFormatException（与 Dart fromJson 同解）`() {
        try {
            HolidayData.fromJson(linkedMapOf("version" to 1, "entries" to emptyList<Any>()))
            fail("缺 year 必须拒绝")
        } catch (expected: DartFormatException) {
            assertTrue(expected.message!!.contains("missing holiday year"))
        }
    }

    @Test
    fun `闰日边界与跨年周在规则与周次上同解`() {
        // 闰年 2-29 在闭区间内：2024-02-28..2024-03-01 含 2024-02-29。
        val start = DartTime.dateTime(2024, 2, 28)
        val end = DartTime.dateTime(2024, 3, 1)
        assertTrue(
            ScheduleDateRuleLogic.containsDate(DartTime.dateTime(2024, 2, 29), start, end),
        )
        assertTrue(
            ScheduleDateRuleLogic.containsDate(DartTime.dateTime(2024, 3, 1), start, end),
        )

        // 跨年周：2025-12-29（周一）开学的学期，2026-01-05（周一）属于第 2 周。
        assertEquals(
            2L,
            com.mutx163.qingyu.core.WeekCalculator.getWeekIndex(
                date = DartTime.dateTime(2026, 1, 5, 12, 0, 0),
                semesterStart = DartTime.dateTime(2025, 12, 29, 0, 0, 0),
            ),
        )
        // 12-31 与次年 1-1 在同一周内，周号不跳变。
        assertEquals(
            1L,
            com.mutx163.qingyu.core.WeekCalculator.getWeekIndex(
                date = DartTime.dateTime(2026, 1, 1, 12, 0, 0),
                semesterStart = DartTime.dateTime(2025, 12, 29, 0, 0, 0),
            ),
        )
    }
}
