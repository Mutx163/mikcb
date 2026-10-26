package com.mutx163.qingyu.statistics

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * CourseStub 周次语义测试（桩，待泳道 A core 模型合入后替换）。
 *
 * 期望值来源标注：
 * - 「Dart 逐行」= 按 lib/models/course.dart 对应行逐行推演；
 * - 「Dart 测试抄录」= test/services/statistics_service_test.dart 的既有用例；
 * - 「人推边界」= 独立推导。
 */
class CourseStubWeekLogicTest {

    private fun course(
        startWeek: Int = 1,
        endWeek: Int = 16,
        isOddWeek: Boolean = false,
        isEvenWeek: Boolean = false,
        customWeeks: List<Int>? = null,
        suspendedWeeks: List<Int>? = null,
        startSection: Int = 1,
        endSection: Int = 2,
    ) = CourseStub(
        name = "课", teacher = "师", location = "教室", dayOfWeek = 1,
        startSection = startSection, endSection = endSection,
        startTime = "08:00", endTime = "09:40",
        startWeek = startWeek, endWeek = endWeek,
        isOddWeek = isOddWeek, isEvenWeek = isEvenWeek,
        customWeeks = customWeeks, suspendedWeeks = suspendedWeeks,
    )

    // ---------- 默认区间（Dart 测试抄录：service_test 第 9-22 行口径） ----------

    @Test
    fun `default course active across 1 to 16`() {
        val c = course()
        assertTrue(c.isActiveInWeek(1))
        assertTrue(c.isActiveInWeek(16))
        assertFalse(c.isActiveInWeek(17))
        assertFalse(c.isActiveInWeek(0))
    }

    @Test
    fun `sectionCount is end minus start plus one`() {
        // Dart 逐行 course.dart:505
        assertEquals(2, course(startSection = 1, endSection = 2).sectionCount)
        assertEquals(1, course(startSection = 9, endSection = 9).sectionCount)
        // 语义如实翻译：end < start 时为负，不做钳制
        assertEquals(0, course(startSection = 5, endSection = 4).sectionCount)
    }

    // ---------- 单双周（Dart 测试抄录：service_test 第 24-55 行） ----------

    @Test
    fun `odd week course active only on odd weeks`() {
        val c = course(endWeek = 4, isOddWeek = true)
        assertTrue(c.isActiveInWeek(1))
        assertFalse(c.isActiveInWeek(2))
        assertTrue(c.isActiveInWeek(3))
        assertFalse(c.isActiveInWeek(4))
    }

    @Test
    fun `even week course active only on even weeks`() {
        // 人推边界（与 isOddWeek 对偶，Dart 逐行 course.dart:614-615）
        val c = course(endWeek = 4, isEvenWeek = true)
        assertFalse(c.isActiveInWeek(1))
        assertTrue(c.isActiveInWeek(2))
        assertFalse(c.isActiveInWeek(3))
        assertTrue(c.isActiveInWeek(4))
    }

    // ---------- 停课周（Dart 测试抄录：service_test 第 136-161 行） ----------

    @Test
    fun `suspended weeks block otherwise active weeks`() {
        val c = course(suspendedWeeks = listOf(3, 5))
        assertTrue(c.isActiveInWeek(2))
        assertFalse(c.isActiveInWeek(3))
        assertFalse(c.isActiveInWeek(5))
        assertTrue(c.isActiveInWeek(4))
    }

    // ---------- customWeeks 覆盖一切（Dart 逐行 course.dart:608-617） ----------

    @Test
    fun `custom weeks override range and parity`() {
        // 人推边界：customWeeks 非空时 startWeek/endWeek/单双周全部失效（course.dart:608-617
        // 只查归一化列表包含，不碰任何其他标志）
        val c = course(startWeek = 2, endWeek = 4, isEvenWeek = true, customWeeks = listOf(1, 20, 31))
        // 31 > maxWeek 30 会被 normalizeWeekList 钳掉
        assertTrue(c.isActiveInWeek(1)) // 区间外但 custom 里有
        assertTrue(c.isActiveInWeek(20)) // 区间外但 custom 里有
        assertFalse(c.isActiveInWeek(31)) // 归一化被钳掉
        assertFalse(c.isActiveInWeek(3)) // 区间内但 custom 没有
        // isEvenWeek=true 也救不了：custom 优先级最高，2 不在 custom 里就是无效
        assertFalse(c.isActiveInWeek(2))
    }

    @Test
    fun `custom weeks take precedence over suspended weeks`() {
        // 人推边界：custom 与 suspended 都给 → isActiveInWeek 先查停课再查 custom
        val c = course(customWeeks = listOf(2, 4), suspendedWeeks = listOf(2))
        assertFalse(c.isActiveInWeek(2)) // custom 命中但被停课挡掉
        assertTrue(c.isActiveInWeek(4))
    }

    // ---------- normalizeWeekList（Dart 逐行 course.dart:200-216） ----------

    @Test
    fun `normalizeWeekList null empty oversized`() {
        assertNull(CourseStub.normalizeWeekList(null))
        assertNull(CourseStub.normalizeWeekList(emptyList()))
        assertNull(CourseStub.normalizeWeekList((1..513).toList())) // > 512 条
    }

    @Test
    fun `normalizeWeekList clamps dedups and sorts`() {
        assertEquals(listOf(1, 2, 30), CourseStub.normalizeWeekList(listOf(30, 0, 2, 2, 1, 99)))
        assertNull(CourseStub.normalizeWeekList(listOf(0, 99, -3))) // 全被钳掉 → null
        assertEquals(listOf(1), CourseStub.normalizeWeekList(listOf(1), maxWeek = 0)) // maxWeek<1 收紧为 1
    }

    @Test
    fun `normalizeWeekList keeps up to 512 entries`() {
        // 人推边界：恰好 512 条仍有效
        val weeks = (1..30).toList() + List(482) { 1 } // 512 条（30 种合法值）
        assertEquals((1..30).toList(), CourseStub.normalizeWeekList(weeks))
    }
}
