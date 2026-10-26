package com.mutx163.qingyu.course

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseSessionNote
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * CourseDomain 端口测试（族3课表CRUD · 纯逻辑）。
 *
 * Dart 源：lib/domain/course_domain.dart（155 行）。
 * 期望值来源标注：
 * - [Dart抄录]：course_domain.dart 注释与既有 Dart 用例的输入输出；
 * - [Dart推演]：对照实现逐行推演；
 * - [人推]：独立推的边界值（空/极值/非法）。
 */
class CourseDomainTest {

    private fun course(
        id: String,
        name: String = "数学",
        dayOfWeek: Int = 1,
        startSection: Int = 1,
        endSection: Int = 2,
        startWeek: Int = 1,
        endWeek: Int = 16,
        customWeeks: List<Int>? = null,
        suspendedWeeks: List<Int>? = null,
        isOddWeek: Boolean = false,
        isEvenWeek: Boolean = false,
    ): Course = Course(
        id = id,
        name = name,
        teacher = "张老师",
        location = "A101",
        dayOfWeek = dayOfWeek,
        startSection = startSection,
        endSection = endSection,
        startTime = "08:00",
        endTime = "09:40",
        startWeek = startWeek,
        endWeek = endWeek,
        isOddWeek = isOddWeek,
        isEvenWeek = isEvenWeek,
        customWeeks = customWeeks,
        suspendedWeeks = suspendedWeeks,
    )

    // ---------- buildSharedCourseNameKey [人推] ----------

    @Test
    fun sharedKey_trimsAndLowercases() { // [人推]
        assertEquals("math", buildSharedCourseNameKey("  Math "))
        assertEquals("数学", buildSharedCourseNameKey("  数学  "))
        assertEquals("", buildSharedCourseNameKey("   "))
    }

    // ---------- conflict / overlapInWeek [Dart推演+人推] ----------

    @Test
    fun conflict_sameId_neverConflicts() { // [Dart推演 course_domain.dart:14-17]
        val c = course("c1")
        assertFalse(CourseDomain.conflict(c, c))
        assertFalse(CourseDomain.conflict(c, c.copy(dayOfWeek = 2)))
    }

    @Test
    fun overlap_differentDay_noOverlap() { // [人推]
        assertFalse(CourseDomain.overlapInWeek(course("a", dayOfWeek = 1), course("b", dayOfWeek = 2)))
    }

    @Test
    fun overlap_touchingSections_noOverlap_adjacentIsExclusive() { // [人推：区间端点语义]
        // 1-2 与 3-4 不重叠；1-2 与 2-3 重叠（含端点）。
        assertFalse(CourseDomain.overlapInWeek(course("a", startSection = 1, endSection = 2), course("b", startSection = 3, endSection = 4)))
        assertTrue(CourseDomain.overlapInWeek(course("a", startSection = 1, endSection = 2), course("b", startSection = 2, endSection = 3)))
    }

    @Test
    fun overlap_withWeek_respectsSuspension() { // [Dart推演 course_domain.dart:34-36]
        val a = course("a", suspendedWeeks = listOf(3))
        val b = course("b")
        assertFalse(CourseDomain.overlapInWeek(a, b, week = 3))
        assertTrue(CourseDomain.overlapInWeek(a, b, week = 4))
    }

    @Test
    fun overlap_withoutWeek_findsCommonActiveWeek() { // [Dart推演 course_domain.dart:38-48]
        // a 只在 1-2 周，b 只在 5-6 周 → 无共同周。
        val a = course("a", startWeek = 1, endWeek = 2)
        val b = course("b", startWeek = 5, endWeek = 6)
        assertFalse(CourseDomain.overlapInWeek(a, b))
        // b 改到 2-5 周 → 第 2 周共同激活。
        val b2 = course("b", startWeek = 2, endWeek = 5)
        assertTrue(CourseDomain.overlapInWeek(a, b2))
    }

    @Test
    fun weekCandidates_customWinsOverShell() { // [Dart推演 course_domain.dart:70-82]
        val c = course("c", startWeek = 1, endWeek = 16, customWeeks = listOf(3, 3, 20))
        // 20 越界（maxWeek=30 内合法，保留）；外壳 1-16 被忽略。
        assertEquals(setOf(3, 20), CourseDomain.weekCandidates(c))
    }

    @Test
    fun buildConflictMap_pairsBothDirections() { // [人推]
        val a = course("a", startSection = 1, endSection = 2)
        val b = course("b", startSection = 2, endSection = 3)
        val c = course("c", name = "英语", dayOfWeek = 5)
        val map = CourseDomain.buildConflictMap(listOf(a, b, c))
        assertEquals(listOf(b), map["a"])
        assertEquals(listOf(a), map["b"])
        assertNull(map["c"])
    }

    // ---------- applySharedFields [Dart推演] ----------

    @Test
    fun applySharedFields_propagatesSharedButKeepsTeacherLocation() { // [Dart推演 course_domain.dart:88-108]
        val target = course("t", name = "旧名", dayOfWeek = 3, startSection = 3, endSection = 4).copy(
            teacher = "目标老师", location = "目标教室", color = "#000000",
        )
        val source = course("s", name = "数学").copy(
            shortName = "数", color = "#FFB300", textColor = "#FFFFFF",
            description = " 共享简介 ",
        )
        val merged = CourseDomain.applySharedFields(target, source)
        assertEquals("数学", merged.name)
        assertEquals("数", merged.shortName)
        assertEquals("#FFB300", merged.color)
        assertEquals("#FFFFFF", merged.textColor)
        assertEquals("共享简介", merged.description)
        // 按条目保留：
        assertEquals("目标老师", merged.teacher)
        assertEquals("目标教室", merged.location)
        // 非共享字段保留目标值：
        assertEquals(3, merged.dayOfWeek)
    }

    @Test
    fun applySharedFields_descriptionFallsBackToLegacyNote() { // [Dart推演 course_domain.dart:89-99]
        val target = course("t")
        val source = course("s").copy(description = null, note = " 旧备注 ")
        assertEquals("旧备注", CourseDomain.applySharedFields(target, source).description)
        val empty = course("s").copy(description = "  ", note = "  ")
        assertNull(CourseDomain.applySharedFields(target, empty).description)
    }

    // ---------- editCourseClock [Dart抄录] ----------

    @Test
    fun editClock_pinnedKeptWhenSectionsUnchanged() { // [Dart抄录 course_domain.dart:126-154]
        val pinned = course("c", startSection = 1, endSection = 2).copy(
            startTime = "07:00", endTime = "07:40", hasCustomTime = true,
        )
        val kept = CourseDomain.editCourseClock(pinned, 1, 2, "08:00", "08:45")
        assertEquals("07:00", kept.startTime)
        assertEquals("07:40", kept.endTime)
        assertTrue(kept.hasCustomTime)
    }

    @Test
    fun editClock_sectionsMoved_returnsTemplate() { // [Dart抄录]
        val pinned = course("c", startSection = 1, endSection = 2).copy(
            startTime = "07:00", endTime = "07:40", hasCustomTime = true,
        )
        val back = CourseDomain.editCourseClock(pinned, 1, 3, "08:00", "09:40")
        assertEquals("08:00", back.startTime)
        assertEquals("09:40", back.endTime)
        assertFalse(back.hasCustomTime)
    }

    @Test
    fun editClock_noOriginal_returnsTemplate() { // [人推：空/极值]
        val back = CourseDomain.editCourseClock(null, 5, 6, "14:00", "15:40")
        assertEquals("14:00", back.startTime)
        assertFalse(back.hasCustomTime)
    }
}
