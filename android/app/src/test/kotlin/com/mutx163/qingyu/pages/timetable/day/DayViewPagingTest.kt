package com.mutx163.qingyu.pages.timetable.day

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test

/**
 * 日视图连续分页算式单元测试。
 *
 * 验证目标：
 * 1. `pageFromWeekDay` 与 `weekDayFromPage` 严格互逆。
 * 2. 边界值（第 1 周第 1 天、第 25 周末日、5 列工作日与 7 列全周模式）。
 * 3. 越界星期归一（隐藏周末时选到周六周日回落至周一）。
 * 4. 非法参数抛出防御性异常。
 */
class DayViewPagingTest {

    @Test
    fun `五天与七天模式下分页与周次下标双向严格互逆`() {
        for (visibleCount in listOf(5, 7)) {
            for (week in 1..25) {
                for (dayIndex in 0 until visibleCount) {
                    val page = DayViewPaging.pageFromWeekDay(
                        week = week,
                        dayIndex = dayIndex,
                        visibleDaysCount = visibleCount,
                    )
                    val (roundWeek, roundIndex) = DayViewPaging.weekDayFromPage(
                        page = page,
                        visibleDaysCount = visibleCount,
                    )
                    assertEquals("周次不一致 (week=$week, dayIndex=$dayIndex, count=$visibleCount)", week, roundWeek)
                    assertEquals("下标不一致 (week=$week, dayIndex=$dayIndex, count=$visibleCount)", dayIndex, roundIndex)
                }
            }
        }
    }

    @Test
    fun `首周与跨周典型边界值计算精确`() {
        // 7天模式
        // 第1周周一 (dayIndex=0) -> page 0
        assertEquals(0, DayViewPaging.pageFromWeekDay(1, 0, 7))
        assertEquals(Pair(1, 0), DayViewPaging.weekDayFromPage(0, 7))

        // 第1周末 (dayIndex=6) -> page 6
        assertEquals(6, DayViewPaging.pageFromWeekDay(1, 6, 7))
        assertEquals(Pair(1, 6), DayViewPaging.weekDayFromPage(6, 7))

        // 第2周周一 (dayIndex=0) -> page 7
        assertEquals(7, DayViewPaging.pageFromWeekDay(2, 0, 7))
        assertEquals(Pair(2, 0), DayViewPaging.weekDayFromPage(7, 7))

        // 5天模式
        // 第20周末 (dayIndex=4) -> (20 - 1) * 5 + 4 = 99
        assertEquals(99, DayViewPaging.pageFromWeekDay(20, 4, 5))
        assertEquals(Pair(20, 4), DayViewPaging.weekDayFromPage(99, 5))
    }

    @Test
    fun `越界星期正确归一到首个可见日`() {
        val workdays = listOf(1, 2, 3, 4, 5)

        // 已在列表内：原样返回
        assertEquals(1, DayViewPaging.normalizeDayOfWeek(workdays, 1))
        assertEquals(5, DayViewPaging.normalizeDayOfWeek(workdays, 5))

        // 越界（周末）：回落到第一个可见日（周一）
        assertEquals(1, DayViewPaging.normalizeDayOfWeek(workdays, 6))
        assertEquals(1, DayViewPaging.normalizeDayOfWeek(workdays, 7))

        // 空列表时不崩溃原样返回
        assertEquals(6, DayViewPaging.normalizeDayOfWeek(emptyList(), 6))
    }

    @Test
    fun `全局页号与星期双向互逆且容忍越界输入`() {
        val week7 = listOf(1, 2, 3, 4, 5, 6, 7)
        val week5 = listOf(1, 2, 3, 4, 5)

        // 7天全周：第 3 周周四 (dayOfWeek=4) -> (3 - 1) * 7 + 3 = 17
        val page7 = DayViewPaging.globalPage(week7, week = 3, dayOfWeek = 4)
        assertEquals(17, page7)
        val target7 = DayViewPaging.targetForGlobalPage(week7, page7)
        assertNotNull(target7)
        assertEquals(3, target7!!.week)
        assertEquals(4, target7.dayOfWeek)

        // 5天工作日：周六 (dayOfWeek=6) 归一至周一 (dayOfWeek=1, index=0)
        // 第 2 周周六 -> 第 2 周周一 -> (2 - 1) * 5 + 0 = 5
        val page5 = DayViewPaging.globalPage(week5, week = 2, dayOfWeek = 6)
        assertEquals(5, page5)
        val target5 = DayViewPaging.targetForGlobalPage(week5, page5)
        assertNotNull(target5)
        assertEquals(2, target5!!.week)
        assertEquals(1, target5.dayOfWeek)
    }

    @Test
    fun `空星期列表与负页号安全返回 null`() {
        assertNull(DayViewPaging.targetForGlobalPage(emptyList(), 0))
        assertNull(DayViewPaging.targetForGlobalPage(listOf(1, 2, 3), -1))
    }

    @Test
    fun `非法参数防御性校验抛出异常`() {
        // week < 1
        assertThrows(IllegalArgumentException::class.java) {
            DayViewPaging.pageFromWeekDay(0, 0, 7)
        }

        // visibleDaysCount <= 0
        assertThrows(IllegalArgumentException::class.java) {
            DayViewPaging.pageFromWeekDay(1, 0, 0)
        }
        assertThrows(IllegalArgumentException::class.java) {
            DayViewPaging.weekDayFromPage(0, 0)
        }

        // dayIndex 越界
        assertThrows(IllegalArgumentException::class.java) {
            DayViewPaging.pageFromWeekDay(1, -1, 7)
        }
        assertThrows(IllegalArgumentException::class.java) {
            DayViewPaging.pageFromWeekDay(1, 7, 7)
        }

        // page < 0
        assertThrows(IllegalArgumentException::class.java) {
            DayViewPaging.weekDayFromPage(-1, 7)
        }
    }
}
