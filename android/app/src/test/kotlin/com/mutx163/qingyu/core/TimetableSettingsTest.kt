package com.mutx163.qingyu.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * TimetableSettings 时间/周次核心子集移植测试。
 *
 * 期望值来源：
 * - [Dart抄录]：test/models/semester_date_and_week_count_invariants_test.dart
 *   （如该文件内容与本类有关）、timetable_settings.dart 注释钉住的口径；
 * - [Dart推演]：对照 lib/models/timetable_settings.dart 实现逐行推演；
 * - [人推]：边界值（跨年、闰日、2 月 31 日顺延日）。
 */
class TimetableSettingsTest {

    // ---------- defaults [Dart抄录] ----------

    @Test
    fun defaults_sectionTable() { // [Dart抄录 timetable_settings.dart:945-960]
        val d = TimetableSettings.defaults()
        assertEquals(10, d.sections.size)
        assertEquals("08:00-08:45", d.sections[0].displayText)
        assertEquals("19:55-20:40", d.sections[9].displayText)
        assertEquals(20, d.semesterWeekCount)
        assertNull(d.activeTimeSchemeId)
        assertNull(d.semesterStartDate)
    }

    // ---------- sections 解析口径 [Dart推演 timetable_settings.dart:1312-1333] ----------

    @Test
    fun fromJson_emptySections_fallBackToDefaults() {
        val s = TimetableSettings.fromJson(linkedMapOf("sections" to emptyList<Any?>()))
        assertEquals(TimetableSettings.DEFAULT_SECTIONS, s.sections)
        // 缺键同样回落
        assertEquals(TimetableSettings.DEFAULT_SECTIONS, TimetableSettings.fromJson(linkedMapOf()).sections)
        // sections 非 List → 空表 → 回落
        assertEquals(TimetableSettings.DEFAULT_SECTIONS, TimetableSettings.fromJson(linkedMapOf("sections" to "bad")).sections)
    }

    @Test
    fun fromJson_malformedEntries_positionPreserved() {
        val s = TimetableSettings.fromJson(
            linkedMapOf(
                "sections" to listOf(
                    linkedMapOf<String, Any?>("startTime" to "08:30", "endTime" to "09:15"),
                    "garbage",
                    linkedMapOf<String, Any?>("startTime" to "10:30", "endTime" to "11:15"),
                ),
            ),
        )
        assertEquals(3, s.sections.size)
        assertEquals("08:30", s.sections[0].startTime)
        // 坏条目按内置模板同位补位（第 2 格 = 08:55-09:40）
        assertEquals("08:55", s.sections[1].startTime)
        assertEquals("09:40", s.sections[1].endTime)
        assertEquals("10:30", s.sections[2].startTime)
    }

    @Test
    fun fromJson_allHealed_fallsBackToDefaults() { // [Dart推演] healedCount == size → 整套回落
        val s = TimetableSettings.fromJson(
            linkedMapOf(
                "sections" to listOf("bad1", "bad2"),
            ),
        )
        assertEquals(TimetableSettings.DEFAULT_SECTIONS, s.sections)
    }

    // ---------- semesterWeekCount [Dart推演 _atLeastOneWeek] ----------

    @Test
    fun semesterWeekCount_atLeastOne() {
        assertEquals(20, TimetableSettings.fromJson(linkedMapOf<String, Any?>()).semesterWeekCount)
        assertEquals(12, TimetableSettings.fromJson(linkedMapOf("semesterWeekCount" to 12L)).semesterWeekCount)
        assertEquals(1, TimetableSettings.fromJson(linkedMapOf("semesterWeekCount" to 0L)).semesterWeekCount)
        assertEquals(1, TimetableSettings.fromJson(linkedMapOf("semesterWeekCount" to -5L)).semesterWeekCount)
        assertEquals(20, TimetableSettings.fromJson(linkedMapOf("semesterWeekCount" to "abc")).semesterWeekCount)
        // 数字字符串
        assertEquals(18, TimetableSettings.fromJson(linkedMapOf("semesterWeekCount" to "18")).semesterWeekCount)
    }

    // ---------- semesterStartDate 双键 [Dart抄录 timetable_settings.dart:1003-1059] ----------

    @Test
    fun semesterStartDate_textKeyWins() {
        val s = TimetableSettings.fromJson(
            linkedMapOf(
                "semesterStartDateText" to "2026-09-07",
                // 毫秒故意给错日期（2026-09-06T16:00Z 在 UTC+8 是 09-07 00:00；
                // 给一个不同的值证明文本键优先）
                "semesterStartDate" to 1759190400000L, // 2025-09-30 附近
            ),
        )
        assertEquals("2026-09-07", TimetableSettings.formatSemesterStartDateText(s.semesterStartDate))
    }

    @Test
    fun semesterStartDate_brokenTextReturnsNull_notMillisFallback() { // [Dart抄录] 文本坏 → null 不回落
        val s = TimetableSettings.fromJson(
            linkedMapOf(
                "semesterStartDateText" to "not-a-date",
                "semesterStartDate" to 1750000000000L,
            ),
        )
        assertNull(s.semesterStartDate)
        // 顺延日（2 月 31 日）同样判 null（round-trip 判据）
        val overflow = TimetableSettings.fromJson(
            linkedMapOf(
                "semesterStartDateText" to "2026-02-31",
                "semesterStartDate" to 1750000000000L,
            ),
        )
        assertNull(overflow.semesterStartDate)
        // 月份/日期超界
        assertNull(
            TimetableSettings.fromJson(
                linkedMapOf("semesterStartDateText" to "2026-13-01", "semesterStartDate" to 1750000000000L),
            ).semesterStartDate,
        )
        assertNull(
            TimetableSettings.fromJson(
                linkedMapOf("semesterStartDateText" to "2026-01-32", "semesterStartDate" to 1750000000000L),
            ).semesterStartDate,
        )
    }

    @Test
    fun semesterStartDate_missingTextFallsBackToMillis_normalizedToMidnight() { // [Dart抄录] 毫秒回落归一本地零点
        // 任取一个毫秒值（2026-09-07 10:30 本地）→ 归一 2026-09-07 00:00
        val millis = DartTime.toEpochMillis(DartTime.dateTime(2026, 9, 7, 10, 30))
        val s = TimetableSettings.fromJson(
            linkedMapOf(
                "semesterStartDate" to millis,
            ),
        )
        assertEquals(DartTime.dateTime(2026, 9, 7, 0, 0), s.semesterStartDate)
        // 文本为空串 → null（不回落毫秒！Dart: trimmed.isEmpty → return null）
        val emptyText = TimetableSettings.fromJson(
            linkedMapOf(
                "semesterStartDateText" to "  ",
                "semesterStartDate" to millis,
            ),
        )
        assertNull(emptyText.semesterStartDate)
    }

    @Test
    fun semesterStartDate_neitherKeyNull() {
        assertNull(TimetableSettings.fromJson(linkedMapOf<String, Any?>()).semesterStartDate)
        assertNull(
            TimetableSettings.fromJson(
                linkedMapOf("semesterStartDate" to "garbage"), // 毫秒位非数字
            ).semesterStartDate,
        )
    }

    @Test
    fun semesterStartDate_leapDayValid() { // [人推]
        val s = TimetableSettings.fromJson(linkedMapOf("semesterStartDateText" to "2028-02-29"))
        assertEquals(DartTime.dateTime(2028, 2, 29, 0, 0), s.semesterStartDate)
        // 非闰年 2 月 29 → null
        assertNull(
            TimetableSettings.fromJson(linkedMapOf("semesterStartDateText" to "2026-02-29")).semesterStartDate,
        )
    }

    // ---------- toJson 键名契约 [Dart推演] ----------

    @Test
    fun toJson_keysMatchDartNames() {
        val json = TimetableSettings(
            semesterStartDate = DartTime.dateTime(2026, 9, 7),
        ).toJson()
        assertEquals(
            listOf(
                "sections",
                "activeTimeSchemeId",
                "semesterWeekCount",
                "semesterStartDate",
                "semesterStartDateText",
                "classReminders",
            ),
            json.keys.toList(),
        )
        assertEquals("2026-09-07", json["semesterStartDateText"])
        assertEquals(true, json["semesterStartDate"] is Long)
        assertEquals(emptyList<Any?>(), json["classReminders"])
        assertNull(TimetableSettings().toJson()["semesterStartDate"]?.let { org.junit.Assert.assertNull(it) })
        assertNull(TimetableSettings().toJson()["semesterStartDateText"])
    }

    // ---------- clampCurrentWeekToSettings [Dart抄录 timetable_profile.dart:27-38] ----------

    @Test
    fun clampCurrentWeekToSettings_bounds() {
        val s = TimetableSettings(semesterWeekCount = 12)
        assertEquals(1L, clampCurrentWeekToSettings(0, s))
        assertEquals(1L, clampCurrentWeekToSettings(-3, s))
        assertEquals(6L, clampCurrentWeekToSettings(6, s))
        assertEquals(12L, clampCurrentWeekToSettings(20, s))
        // semesterWeekCount 非法（<1）按 1 钳
        val broken = TimetableSettings(semesterWeekCount = 0)
        assertEquals(1L, clampCurrentWeekToSettings(5, broken))
    }
}
