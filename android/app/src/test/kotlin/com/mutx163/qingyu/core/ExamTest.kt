package com.mutx163.qingyu.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * Exam 模型移植测试。
 *
 * 期望值来源：
 * - [Dart抄录]：test/models/exam_test.dart、test/models/exam_reminder_offsets_normalize_test.dart；
 * - [Dart推演]：对照 lib/models/exam.dart 实现逐行推演；
 * - [人推]：边界值。
 */
class ExamTest {

    private val baseExam = Exam(
        id = "exam-1",
        courseId = "course-1",
        name = "高等数学期末考试",
        dateTime = LocalDateTime.of(2026, 7, 1, 0, 0),
        startTime = "08:30",
        endTime = "10:30",
        location = "A-301",
        seatNumber = "12",
        createdAt = LocalDateTime.of(2026, 4, 1, 0, 0),
        updatedAt = LocalDateTime.of(2026, 4, 1, 0, 0),
    )

    // ---------- ExamReminderPreset [Dart抄录] ----------

    @Test
    fun presetReminderMinutes() { // [Dart抄录]
        assertEquals(listOf(1440, 60), ExamReminderPreset.DAY_1_AND_HOUR_1.reminderMinutes)
        assertTrue(ExamReminderPreset.NONE.reminderMinutes.isEmpty())
        assertTrue(ExamReminderPreset.CUSTOM.reminderMinutes.isEmpty())
        assertEquals(listOf(30), ExamReminderPreset.MIN_30.reminderMinutes)
        assertEquals(listOf(60), ExamReminderPreset.HOUR_1.reminderMinutes)
        assertEquals(listOf(60, 30), ExamReminderPreset.HOUR_1_AND_MIN_30.reminderMinutes)
        assertEquals(listOf(1440), ExamReminderPreset.DAY_1.reminderMinutes)
    }

    @Test
    fun presetFromValue_roundTripsAndDefaults() { // [Dart抄录]
        for (preset in ExamReminderPreset.entries) {
            assertEquals(preset, ExamReminderPreset.fromValue(preset.value))
        }
        assertEquals(ExamReminderPreset.DAY_1_AND_HOUR_1, ExamReminderPreset.fromValue("garbage"))
        assertEquals(ExamReminderPreset.DAY_1_AND_HOUR_1, ExamReminderPreset.fromValue(null))
    }

    // ---------- 序列化契约 [Dart抄录] ----------

    @Test
    fun toJsonFromJsonRoundTrip() { // [Dart抄录]
        val restored = Exam.fromJson(baseExam.toJson())
        assertEquals(baseExam.id, restored.id)
        assertEquals(baseExam.courseId, restored.courseId)
        assertEquals(baseExam.name, restored.name)
        assertEquals(baseExam.startTime, restored.startTime)
        assertEquals(baseExam.endTime, restored.endTime)
        assertEquals(baseExam.location, restored.location)
        assertEquals(baseExam.seatNumber, restored.seatNumber)
        assertEquals(baseExam.reminderPreset, restored.reminderPreset)
        // 键名契约（exam.dart:75-91）
        assertEquals(
            listOf(
                "id", "courseId", "name", "dateTime", "startTime", "endTime",
                "location", "seatNumber", "note", "reminderPreset",
                "customReminderMinutes", "createdAt", "updatedAt",
            ),
            baseExam.toJson().keys.toList(),
        )
    }

    @Test
    fun fromJsonMissingOptionalFields() { // [Dart抄录]
        val exam = Exam.fromJson(
            linkedMapOf(
                "id" to "e1",
                "courseId" to "c1",
                "name" to "Test",
                "dateTime" to "2026-07-01T00:00:00.000",
                "startTime" to "09:00",
                "endTime" to "11:00",
                "createdAt" to "2026-04-01T00:00:00.000",
                "updatedAt" to "2026-04-01T00:00:00.000",
            ),
        )
        assertNull(exam.location)
        assertNull(exam.seatNumber)
        assertNull(exam.note)
        assertEquals(ExamReminderPreset.DAY_1_AND_HOUR_1, exam.reminderPreset)
        assertTrue(exam.customReminderMinutes.isEmpty())
    }

    @Test
    fun fromJsonRequiredMissing_throws() { // [Dart推演 exam.dart:171-177]
        org.junit.Assert.assertThrows(DartFormatException::class.java) {
            Exam.fromJson(linkedMapOf())
        }
        org.junit.Assert.assertThrows(DartFormatException::class.java) {
            Exam.fromJson(linkedMapOf("id" to "e1")) // courseId 缺失
        }
    }

    // ---------- 时间归一 [Dart抄录] ----------

    @Test
    fun fromJsonNormalizesMalformedTimes() { // [Dart抄录]
        val exam = Exam.fromJson(
            linkedMapOf(
                "id" to "exam-1",
                "courseId" to "course-1",
                "name" to "期末",
                "dateTime" to "2026-06-01T00:00:00.000",
                "startTime" to "bad",
                "endTime" to "25:99",
                "createdAt" to "2026-01-01T00:00:00.000",
                "updatedAt" to "2026-01-01T00:00:00.000",
            ),
        )
        assertEquals("08:30", exam.startTime)
        assertEquals("10:30", exam.endTime)
    }

    @Test
    fun normalizeTimeOfDayTable() { // [Dart抄录] 全表
        assertEquals("08:30", Exam.normalizeTimeOfDay("8:30"))
        assertEquals("12:05", Exam.normalizeTimeOfDay("12:5"))
        assertEquals("08:30", Exam.normalizeTimeOfDay("08:30"))
        assertEquals("23:59", Exam.normalizeTimeOfDay("23:59"))
        assertEquals("00:00", Exam.normalizeTimeOfDay("0:00"))
        // hour 24 不合法（考试时刻不是节次表）
        assertEquals("08:30", Exam.normalizeTimeOfDay("24:00"))
        assertEquals("08:30", Exam.normalizeTimeOfDay("12:60"))
        assertEquals("08:30", Exam.normalizeTimeOfDay("abc"))
        assertEquals("08:30", Exam.normalizeTimeOfDay(""))
        assertEquals("08:30", Exam.normalizeTimeOfDay(null))
        assertEquals("10:00", Exam.normalizeTimeOfDay("bad", fallback = "10:00"))
        assertEquals("09:05", Exam.normalizeTimeOfDay("9:5"))
        // 边界：负分钟、两位以上数字
        assertEquals("08:30", Exam.normalizeTimeOfDay("8:-1"))
        assertEquals("08:30", Exam.normalizeTimeOfDay("123:45"))
    }

    // ---------- 自定义提醒偏移归一 [Dart抄录] exam_reminder_offsets_normalize_test.dart ----------

    private fun jsonWith(offsets: List<Any?>): MutableMap<String, Any?> = linkedMapOf(
        "id" to "exam-1",
        "courseId" to "course-1",
        "name" to "期中高数",
        "dateTime" to "2026-11-05T08:30:00",
        "startTime" to "08:30",
        "endTime" to "10:30",
        "location" to "一教 101",
        "reminderPreset" to "custom",
        "customReminderMinutes" to offsets,
    )

    @Test
    fun offsets_nonPositiveDropped() { // [Dart抄录] 修复前 [-30,0,45] 原样留着
        val exam = Exam.fromJson(jsonWith(listOf(-30L, 0L, 45L)))
        assertEquals(listOf(45), exam.customReminderMinutes)
    }

    @Test
    fun offsets_duplicatesKeepFirst() { // [Dart抄录]
        val exam = Exam.fromJson(jsonWith(listOf(60L, 60L, 1440L)))
        assertEquals(listOf(60, 1440), exam.customReminderMinutes)
    }

    @Test
    fun offsets_validOrderPreserved() { // [Dart抄录]
        val exam = Exam.fromJson(jsonWith(listOf(1440L, 120L, 30L)))
        assertEquals(listOf(1440, 120, 30), exam.customReminderMinutes)
    }

    @Test
    fun offsets_nonNumericEntriesSkipped() { // [Dart抄录] "x" 丢、30 收
        val exam = Exam.fromJson(jsonWith(listOf("x", 30L)))
        assertEquals(listOf(30), exam.customReminderMinutes)
    }

    @Test
    fun offsets_roundTripNormalized() { // [Dart抄录]
        val exam = Exam.fromJson(jsonWith(listOf(-10L, 90L)))
        assertEquals(listOf(90), Exam.fromJson(exam.toJson()).customReminderMinutes)
    }

    @Test
    fun offsets_nonListReturnsEmpty() { // [Dart推演 exam.dart:104]
        assertTrue(Exam.normalizeReminderOffsets(null).isEmpty())
        assertTrue(Exam.normalizeReminderOffsets("30").isEmpty())
    }

    // ---------- effectiveReminderMinutes / 排序 [Dart抄录+推演] ----------

    @Test
    fun effectiveReminderMinutes_presetsAndCustom() {
        assertEquals(listOf(1440, 60), baseExam.effectiveReminderMinutes)
        val custom = baseExam.copy(
            reminderPreset = ExamReminderPreset.CUSTOM,
            customReminderMinutes = listOf(30, 10),
        )
        assertEquals(listOf(30, 10), custom.effectiveReminderMinutes)
    }

    @Test
    fun examStartDateTime_andCompareByStart() { // [Dart推演 exam.dart:270-297]
        val morning = baseExam.copy(id = "a", startTime = "08:00")
        val afternoon = baseExam.copy(id = "b", startTime = "14:00")
        assertTrue(Exam.compareByStart(morning, afternoon) < 0)
        assertTrue(Exam.compareByStart(afternoon, morning) > 0)
        // 同开始时刻比结束时刻；同结束比 id
        val sameStartEarlierEnd = baseExam.copy(id = "c", startTime = "08:30", endTime = "09:30")
        assertTrue(Exam.compareByStart(sameStartEarlierEnd, baseExam) < 0)
        // endTime 畸形（解析失败）按 23:59 兜底（_dateTimeWithTime 的 fallback）
        val garbageEnd = baseExam.copy(id = "d", endTime = "bad")
        val realEnd = baseExam.copy(id = "e", endTime = "10:30")
        assertTrue(Exam.compareByStart(garbageEnd, realEnd) > 0)
        // 全同比 id（compareTo 不是 Exam 的 API——Dart 里 Exam 也没有 compareTo，
        // 这里直接钉 compareByStart 的 id 兜底序）
        assertEquals(
            "x".compareTo("y"),
            Exam.compareByStart(baseExam.copy(id = "x"), baseExam.copy(id = "y")),
        )
    }
}
