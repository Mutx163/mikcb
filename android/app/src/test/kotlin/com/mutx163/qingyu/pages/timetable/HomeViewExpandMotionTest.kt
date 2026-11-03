package com.mutx163.qingyu.pages.timetable

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 首页「周 ↔ 日」展开窗口的几何契约（2026-11-02）。
 *
 * 这些断言钉的是**观感的几何前提**，不是实现细节：
 * 1. 进度 0 时窗口正好是选中那一列（多一列 / 少一列，展开起点就错了）；
 * 2. 进度 1 时铺满整屏（差 1px 都会在落定帧看到一条边）；
 * 3. 全程左右边界单调（中间反弹一次就会读成「弹一下」）；
 * 4. 隐藏周末时数组下标仍按可见日算（按 1..7 直接取下标会落到错误的列）。
 */
class HomeViewExpandMotionTest {

    private val viewport = 1080f
    private val contentLeft = 24f
    private val contentWidth = 1032f
    private val timeColumn = 102f
    private val days = listOf(1, 2, 3, 4, 5, 6, 7)

    @Test
    fun `进度 0 时窗口正好是选中那一列`() {
        val dayWidth = (contentWidth - timeColumn) / days.size
        val window = homeViewExpandWindow(
            progress = 0f,
            viewportWidth = viewport,
            contentLeft = contentLeft,
            contentWidth = contentWidth,
            timeColumnWidth = timeColumn,
            visibleDays = days,
            selectedDayOfWeek = 4, // 周四
        )
        val expectedLeft = contentLeft + timeColumn + 3 * dayWidth
        assertEquals(expectedLeft, window.left, 0.01f)
        assertEquals(expectedLeft + dayWidth, window.right, 0.01f)
    }

    @Test
    fun `进度 1 时铺满整屏`() {
        val window = homeViewExpandWindow(
            progress = 1f,
            viewportWidth = viewport,
            contentLeft = contentLeft,
            contentWidth = contentWidth,
            timeColumnWidth = timeColumn,
            visibleDays = days,
            selectedDayOfWeek = 1,
        )
        assertEquals(0f, window.left, 0.01f)
        assertEquals(viewport, window.right, 0.01f)
    }

    @Test
    fun `全程左右边界单调`() {
        var lastLeft = Float.MAX_VALUE
        var lastRight = -Float.MAX_VALUE
        for (step in 0..20) {
            val window = homeViewExpandWindow(
                progress = step / 20f,
                viewportWidth = viewport,
                contentLeft = contentLeft,
                contentWidth = contentWidth,
                timeColumnWidth = timeColumn,
                visibleDays = days,
                selectedDayOfWeek = 6,
            )
            assertTrue("left 在 progress=${step / 20f} 反弹了：${window.left}", window.left <= lastLeft + 0.001f)
            assertTrue("right 在 progress=${step / 20f} 反弹了：${window.right}", window.right >= lastRight - 0.001f)
            lastLeft = window.left
            lastRight = window.right
        }
    }

    @Test
    fun `隐藏周末时按可见日下标取列`() {
        val weekdays = listOf(1, 2, 3, 4, 5)
        val dayWidth = (contentWidth - timeColumn) / weekdays.size
        val window = homeViewExpandWindow(
            progress = 0f,
            viewportWidth = viewport,
            contentLeft = contentLeft,
            contentWidth = contentWidth,
            timeColumnWidth = timeColumn,
            visibleDays = weekdays,
            selectedDayOfWeek = 5, // 周五 = 第 5 列（下标 4）
        )
        assertEquals(contentLeft + timeColumn + 4 * dayWidth, window.left, 0.01f)
    }

    @Test
    fun `选中日不在可见日里时退回第一列`() {
        val weekdays = listOf(1, 2, 3, 4, 5)
        val dayWidth = (contentWidth - timeColumn) / weekdays.size
        val window = homeViewExpandWindow(
            progress = 0f,
            viewportWidth = viewport,
            contentLeft = contentLeft,
            contentWidth = contentWidth,
            timeColumnWidth = timeColumn,
            visibleDays = weekdays,
            selectedDayOfWeek = 6, // 周六被隐藏
        )
        assertEquals(contentLeft + timeColumn, window.left, 0.01f)
        assertEquals(contentLeft + timeColumn + dayWidth, window.right, 0.01f)
    }

    @Test
    fun `时长按用户速度缩放且夹在 0_5x 到 2_5x`() {
        assertEquals(210, homeViewExpandDurationMillis(1.0))
        assertEquals(105, homeViewExpandDurationMillis(2.0))
        assertEquals(420, homeViewExpandDurationMillis(0.5))
        // 超出滑杆区间的值按边界算，不能把时长打成 0 或负数。
        assertEquals(420, homeViewExpandDurationMillis(0.1))
        assertEquals(84, homeViewExpandDurationMillis(2.5))
        assertEquals(84, homeViewExpandDurationMillis(9.0))
    }
}
