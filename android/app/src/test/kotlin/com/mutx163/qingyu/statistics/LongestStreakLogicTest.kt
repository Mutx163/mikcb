package com.mutx163.qingyu.statistics

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

/**
 * 「最长连续上课天数」唯一内核的直测（P1-12，2026-11-11）。
 *
 * 统计页（`StatisticsService`）与桌面统计小组件（`WidgetStatsLogic`）现在都只提供
 * 「本周哪几天有课」的 7 天布尔向量、调用 [LongestStreakLogic.longestStreak]。
 * 这两个入口的行为差异只剩「课程模型 → 向量」这一步，算法口径由本文件钉住。
 */
class LongestStreakLogicTest {

    private fun days(vararg indices: Int): BooleanArray {
        val vector = BooleanArray(LongestStreakLogic.DAYS_IN_WEEK)
        for (index in indices) vector[index - 1] = true
        return vector
    }

    @Test
    fun `整周无课为 0`() {
        assertEquals(0, LongestStreakLogic.longestStreak(BooleanArray(7)))
    }

    @Test
    fun `周一到周五连续为 5`() {
        assertEquals(5, LongestStreakLogic.longestStreak(days(1, 2, 3, 4, 5)))
    }

    @Test
    fun `整周排满上限是 7 不溢出`() {
        assertEquals(7, LongestStreakLogic.longestStreak(days(1, 2, 3, 4, 5, 6, 7)))
    }

    @Test
    fun `跨周边界要接起来 周六周日周一为 3`() {
        assertEquals(3, LongestStreakLogic.longestStreak(days(6, 7, 1)))
    }

    @Test
    fun `周中空一天就断开 周一至周三与周五为 3`() {
        assertEquals(3, LongestStreakLogic.longestStreak(days(1, 2, 3, 5)))
    }

    @Test
    fun `向量长度必须是 7`() {
        assertThrows(IllegalArgumentException::class.java) {
            LongestStreakLogic.longestStreak(BooleanArray(6))
        }
    }
}
