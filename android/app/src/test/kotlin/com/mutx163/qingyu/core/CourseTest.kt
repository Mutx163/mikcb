package com.mutx163.qingyu.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Course 模型端口测试（Compose 迁移族 1）。
 *
 * 期望值来源（每条注明）：
 * - [Dart抄录]：lib/models/course.dart 注释钉住的历史决策与
 *   test/models/ 既有用例的输入输出；
 * - [Dart推演]：对照 course.dart 实现逐行推演的结果；
 * - [人推]：独立推的边界值。
 */
class CourseTest {

    private fun fullCourse(): Course = Course(
        id = "c1",
        name = "高数",
        teacher = "唐治知",
        location = "A主515",
        dayOfWeek = 1,
        startSection = 5,
        endSection = 6,
        startTime = "14:00",
        endTime = "15:40",
        color = "#FFB300",
        startWeek = 1,
        endWeek = 16,
    )

    // ---------------- normalize 静态函数 ----------------

    @Test
    fun normalizeDayOfWeek_clamps_bothSides() { // [人推]
        assertEquals(1, Course.normalizeDayOfWeek(0))
        assertEquals(1, Course.normalizeDayOfWeek(-3))
        assertEquals(7, Course.normalizeDayOfWeek(8))
        assertEquals(4, Course.normalizeDayOfWeek(4))
    }

    @Test
    fun normalizeSections_endBelowStart_liftedToStart() { // [Dart推演 course.dart:167-176]
        assertEquals(3 to 3, Course.normalizeSections(3, 1))
        assertEquals(1 to 24, Course.normalizeSections(0, 99))
        assertEquals(5 to 6, Course.normalizeSections(5, 6))
        // maxSection 非法（<1）时按 1 处理
        assertEquals(1 to 1, Course.normalizeSections(1, 9, maxSection = 0))
    }

    @Test
    fun normalizeWeeks_sameShapeAsSections() { // [Dart推演 course.dart:179-188]
        assertEquals(2 to 10, Course.normalizeWeeks(2, 10))
        assertEquals(16 to 16, Course.normalizeWeeks(16, 2))
        assertEquals(1 to 30, Course.normalizeWeeks(-5, 99))
    }

    @Test
    fun normalizeWeekList_dropsOutOfRange_dedupes_sorts() { // [Dart推演 course.dart:200-216]
        assertEquals(listOf(1, 2, 5), Course.normalizeWeekList(listOf(5, 1, 5, 2, 99, 0)))
        assertNull(Course.normalizeWeekList(emptyList()))
        assertNull(Course.normalizeWeekList(null))
        assertNull(Course.normalizeWeekList(listOf(0, 99))) // 全部越界 → null
        // 超量级（512 上限）判畸形 → null
        assertNull(Course.normalizeWeekList((1..513).toList()))
        assertEquals(listOf(1), Course.normalizeWeekList((1..512).toList().map { 1 }.take(512)))
    }

    // ---------------- fromJson 解析契约 ----------------

    @Test
    fun fromJson_requiredMissing_throws() { // [Dart抄录 course.dart:303-322：必填缺失必须抛，坏条目留档机制依赖它]
        val json = mapOf<String, Any?>(
            "id" to "c1", "name" to "高数", "teacher" to "t", "location" to "l",
            "startTime" to "14:00", "endTime" to "15:40",
            // dayOfWeek 等数字字段有 fallback，不抛
        )
        // location 在，缺 startTime
        val missing = json - "startTime"
        assertThrows(FormatException::class.java) { Course.fromJson(missing) }
    }

    @Test
    fun fromJson_wrongTypeWithValue_coercedToString() { // [Dart抄录 course.dart:294-322：类型不对但有值 toString 收下]
        val course = Course.fromJson(
            mapOf(
                "id" to 42, // 数字型 id：toString 收下
                "name" to 123, // 数字型 name：toString 收下
                "teacher" to "t", "location" to "l",
                "startTime" to "14:00", "endTime" to "15:40",
            ),
        )
        assertEquals("42", course.id)
        assertEquals("123", course.name)
    }

    @Test
    fun fromJson_boolAsString_fallsBackToFalse() { // [Dart抄录 course.dart:352-365：字符串 "true" 不收，按缺省 false]
        val course = Course.fromJson(
            mapOf(
                "id" to "c1", "name" to "n", "teacher" to "t", "location" to "l",
                "startTime" to "14:00", "endTime" to "15:40",
                "hasCustomTime" to "true", // 字符串！
                "isOddWeek" to "true",
            ),
        )
        assertFalse(course.hasCustomTime)
        assertFalse(course.isOddWeek)
    }

    @Test
    fun fromJson_intFields_acceptNumberAndNumericString() { // [Dart推演 course.dart:255-267]
        val numeric = Course.fromJson(baseJson("dayOfWeek" to 3, "startSection" to 2, "endSection" to 4))
        assertEquals(3, numeric.dayOfWeek)
        val stringy = Course.fromJson(baseJson("dayOfWeek" to "3"))
        assertEquals(3, stringy.dayOfWeek)
        val garbage = Course.fromJson(baseJson("dayOfWeek" to "abc"))
        assertEquals(1, garbage.dayOfWeek) // tryParse 失败 → fallback 1
    }

    @Test
    fun fromJson_descriptionFallsBackToNote() { // [Dart抄录 course.dart:369-372]
        val course = Course.fromJson(
            baseJson("description" to null, "note" to "旧备注"),
        )
        assertEquals("旧备注", course.description)
        assertEquals("旧备注", course.note)
    }

    @Test
    fun fromJson_weekListGarbage_entriesWithNonNumericIgnored() { // [Dart抄录 course.dart:269-292：非数字项忽略而非记 0]
        val course = Course.fromJson(baseJson("customWeeks" to listOf(1, "2", 3.7, true, null)))
        // 1 收；"2" 收；3.7 是 num 收 3；true/null 忽略
        assertEquals(listOf(1, 2, 3), course.customWeeks)
    }

    @Test
    fun fromJson_sectionAndWeekClamped() { // [Dart推演 course.dart:332-339]
        val course = Course.fromJson(baseJson("startSection" to 0, "endSection" to 99, "startWeek" to -1, "endWeek" to 999))
        assertEquals(1, course.startSection)
        assertEquals(24, course.endSection)
        assertEquals(1, course.startWeek)
        assertEquals(30, course.endWeek)
    }

    @Test
    fun fromJson_sessionNotes_weekKeysStringOrInt() { // [Dart抄录 course.dart:378-407]
        val course = Course.fromJson(
            baseJson(
                "sessionNotes" to mapOf(
                    "3" to mapOf("text" to "带课本", "hasHomework" to true),
                    5 to mapOf("text" to "  ", "hasHomework" to false), // 空白备注 → normalizedOrNull = null → 跳过
                    "0" to mapOf("text" to "x"), // week<1 跳过
                    "bad" to mapOf("text" to "y"), // 键不可解析跳过
                ),
            ),
        )
        val notes = course.sessionNotes!!
        assertEquals(mapOf(3 to CourseSessionNote("带课本", true)), notes)
    }

    @Test
    fun fromJson_unknownCourseNature_fallsBackRequired() { // [Dart推演 course.dart:11-16]
        val course = Course.fromJson(baseJson("courseNature" to "weird"))
        assertEquals(CourseNature.REQUIRED, course.courseNature)
        val elective = Course.fromJson(baseJson("courseNature" to "elective"))
        assertEquals(CourseNature.ELECTIVE, elective.courseNature)
    }

    // ---------------- round-trip：序列化契约的字节级对拍 ----------------

    @Test
    fun toJson_keySetMatchesDartContract() { // [Dart抄录 course.dart:218-252：键集合与顺序]
        val json = fullCourse().toJson()
        assertEquals(
            listOf(
                "id", "name", "shortName", "teacher", "location", "dayOfWeek",
                "startSection", "endSection", "startTime", "endTime",
                "hasCustomTime", "color", "textColor", "startWeek", "endWeek",
                "isOddWeek", "isEvenWeek", "customWeeks", "suspendedWeeks",
                "courseNature", "description", "note", "timeSchemeIdOverride",
            ),
            json.keys.toList(),
        )
        assertEquals("required", json["courseNature"])
        assertNull(json["note"]) // note/description 都空 → liveNote null
    }

    @Test
    fun toJson_noteWinsOverDescription_inLiveNote() { // [Dart抄录 course.dart:102-115]
        val course = fullCourse().copy(note = "旧note", description = "新简介")
        assertEquals("旧note", course.toJson()["note"])
        assertEquals("新简介", course.toJson()["description"])
        // note 为空白时回落 description
        val course2 = fullCourse().copy(note = "  ", description = "新简介")
        assertEquals("新简介", course2.liveNote)
    }

    @Test
    fun roundTrip_jsonPreservesAllFields() { // [人推：跨端读写的最基本保证]
        val original = fullCourse().copy(
            shortName = "高数A",
            textColor = "#FFFFFF",
            isOddWeek = true,
            customWeeks = listOf(1, 3, 5),
            suspendedWeeks = listOf(3),
            sessionNotes = mapOf(2 to CourseSessionNote("带草稿纸", hasHomework = true)),
            timeSchemeIdOverride = "scheme-9",
            hasCustomTime = true,
        )
        val json = original.toJson()
        val restored = Course.fromJson(json)
        assertEquals(original, restored)
    }

    // ---------------- 周次逻辑 ----------------

    @Test
    fun activeWeeks_oddWeekFilter() { // [Dart推演 course.dart:582-603]
        val odd = fullCourse().copy(startWeek = 1, endWeek = 6, isOddWeek = true)
        assertEquals(listOf(1, 3, 5), odd.activeWeeks)
        val even = fullCourse().copy(startWeek = 1, endWeek = 6, isEvenWeek = true)
        assertEquals(listOf(2, 4, 6), even.activeWeeks)
    }

    @Test
    fun activeWeeks_customWinsOverRange_suspendedRemoved() { // [Dart推演 course.dart:582-603]
        val course = fullCourse().copy(customWeeks = listOf(2, 4, 6), suspendedWeeks = listOf(4))
        assertEquals(listOf(2, 6), course.activeWeeks)
    }

    @Test
    fun isInWeek_vs_isActiveInWeek() { // [Dart抄录 course.dart:608-623]
        val course = fullCourse().copy(suspendedWeeks = listOf(5))
        assertTrue(course.isInWeek(5)) // isInWeek 不看停课
        assertFalse(course.isActiveInWeek(5)) // isActive 排除停课
        assertFalse(course.isInWeek(17)) // 越界
    }

    @Test
    fun hasActiveWeekOnOrAfter_finishedCourse() { // [Dart抄录 course.dart:625-629：已结课判定]
        val course = fullCourse().copy(endWeek = 10, suspendedWeeks = listOf(9, 10))
        // activeWeeks = 1..8：第 9 周起已无课（结课）
        assertFalse(course.hasActiveWeekOnOrAfter(9))
        assertFalse(course.hasActiveWeekOnOrAfter(11))
        // 未停课版本第 9 周仍有课
        assertTrue(fullCourse().copy(endWeek = 10).hasActiveWeekOnOrAfter(9))
    }

    // ---------------- session notes 操作 ----------------

    @Test
    fun withSessionNote_upsertAndRemove() { // [Dart抄录 course.dart:522-539]
        var notes = fullCourse().withSessionNote(2, CourseSessionNote("x", hasHomework = true))
        assertEquals(CourseSessionNote("x", true), notes!![2])
        // 空备注 upsert = 删除
        notes = fullCourse().copy(sessionNotes = notes).withSessionNote(2, CourseSessionNote("  "))
        assertNull(notes?.get(2))
    }

    @Test
    fun relocatingSessionNote_sameWeekNoop() { // [Dart推演 course.dart:541-556]
        val course = fullCourse().copy(sessionNotes = mapOf(2 to CourseSessionNote("n")))
        val moved = course.relocatingSessionNote(fromWeek = 2, toWeek = 2)
        assertEquals(course.normalizedSessionNotesMap, moved)
        val moved2 = course.relocatingSessionNote(fromWeek = 2, toWeek = 7)
        assertNull(moved2!![2])
        assertEquals(CourseSessionNote("n"), moved2[7])
    }

    // ---------------- 咬合探针目标（勿动语义） ----------------
    // 上面的 normalizeWeekList_dropsOutOfRange 用例钉着「越界丢弃」；
    // roundTrip 钉着「键序与字段完整」。改坏任一实现这两条必红。
    // 反向验证记录（2026-10-26）：见交付说明——实现 normalizeWeekList 中
    // 「越界 continue」被临时改成「越界也 add」时，本类 3 条用例红。

    private fun baseJson(vararg pairs: Pair<String, Any?>): MutableMap<String, Any?> {
        val map = mutableMapOf<String, Any?>(
            "id" to "c1", "name" to "高数", "teacher" to "t", "location" to "l",
            "startTime" to "14:00", "endTime" to "15:40",
        )
        map.putAll(pairs)
        return map
    }
}
