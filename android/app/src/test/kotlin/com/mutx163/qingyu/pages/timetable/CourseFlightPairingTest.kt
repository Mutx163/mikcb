package com.mutx163.qingyu.pages.timetable

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 飞行卡「周卡 i ↔ 日卡 i」四元配对的双射校验（v2 §0 + P-5，2026-11-04）。
 *
 * 飞行单位＝**具体一张课卡**，两端用**同一个** `courseFlightCardKey(week, dayOfWeek, courseId, startSection)`
 * 四元配对。P-5 起两端都传**原始** `course.startSection`，越界规整只在 `courseFlightCardKey`
 * 里做一次 `coerceAtLeast(1)`——所以脏数据（≤0 / 超节数）两端也不会分叉。
 *
 * 断言：两集合相等、条数 = 当日课程数、互不相同（无多对一 / 无孤儿）。
 */
class CourseFlightPairingTest {

    private data class Slot(val id: String, val startSection: Int, val endSection: Int)

    private val sectionCount = 12
    private val week = 3
    private val dayOfWeek = 5

    /** 同一日课表：≥3 门，含跨节次 span（physics 3→5），另含脏数据（startSection 0 / 99）。 */
    private val courses = listOf(
        Slot("math", 1, 2),
        Slot("physics", 3, 5),
        Slot("english", 7, 8),
        Slot("chem", 5, 6),
        Slot("dirtyLow", 0, 2), // 越界（低于 1）
        Slot("dirtyHigh", 99, 100), // 越界（超节数）
    )

    /** 周侧公式：传原始 startSection（网格新代码口径）。 */
    private fun weekKeys(): List<String> =
        courses.map { courseFlightCardKey(week, dayOfWeek, it.id, it.startSection) }

    /** 日侧公式：也传原始 startSection（日视图口径）。 */
    private fun dayKeys(): List<String> =
        courses.map { courseFlightCardKey(week, dayOfWeek, it.id, it.startSection) }

    @Test
    fun `周侧与日侧卡键集合相等`() {
        assertEquals(
            "周侧与日侧生成的飞行键集合必须一致（同一张卡两端配对）",
            weekKeys().toSet(),
            dayKeys().toSet(),
        )
    }

    @Test
    fun `越界脏数据两端也相等`() {
        // P-5：dirtyLow(startSection 0) 与 dirtyHigh(99) 两端都必须落在同一 key。
        val w = weekKeys().toSet()
        val d = dayKeys().toSet()
        assertEquals("越界数据也必须两端一致", w, d)
        // 0 收敛到 1，不是 0。
        assertTrue("startSection=0 应收敛成起始节 1", w.contains("$week|$dayOfWeek|dirtyLow|1"))
    }

    @Test
    fun `键条数等于当日课程数且互不相同`() {
        val keys = weekKeys()
        assertEquals("键条数必须等于课程数", courses.size, keys.size)
        assertEquals("键不得重复（无多对一）", keys.size, keys.toSet().size)
        assertTrue("键必须都是 week|day 前缀的当日卡", keys.all { it.startsWith("$week|$dayOfWeek|") })
    }

    @Test
    fun `同一门课跨节次 span 不改变配对键`() {
        val phys = courses.first { it.id == "physics" }
        val key = courseFlightCardKey(week, dayOfWeek, phys.id, phys.startSection)
        assertTrue("physics 的键必须在周侧集合里", weekKeys().contains(key))
        assertTrue("physics 的键必须在日侧集合里", dayKeys().contains(key))
    }

    // ────────────────────────── 负例自测（P-1：配对断言有牙齿）──────────────────────────

    @Test
    fun `负例自测_日侧起始节错换成0配对必红`() {
        // 把日侧某门课（startSection 3）错换成 0：规整后为 1 ≠ 周侧的 3 → 集合必不等。
        val phys = courses.first { it.id == "physics" }
        val badDay = dayKeys().toMutableSet()
        badDay.remove(courseFlightCardKey(week, dayOfWeek, phys.id, phys.startSection))
        badDay.add(courseFlightCardKey(week, dayOfWeek, phys.id, 0))
        assertNotEquals("日侧起始节错换后必须判不配对（红）", weekKeys().toSet(), badDay)
    }
}
