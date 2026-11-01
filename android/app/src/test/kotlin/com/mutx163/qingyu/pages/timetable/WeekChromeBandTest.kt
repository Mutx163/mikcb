package com.mutx163.qingyu.pages.timetable

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 共享玻璃带上「星期栏显示哪一周」的落定口径（[chromeDisplayedPage]）。
 *
 * 为什么单独测：这条判定被抽走后，界面层只剩一行 `snapshotFlow` 接线。
 * 一旦写成「永远跟 currentPage」，拖动过程中星期栏会来回改字，而编译与其它
 * JVM 单测都不会红 —— 只有这里能抓住。
 */
class WeekChromeBandTest {

    @Test
    fun `停稳后跟随当前页`() {
        assertEquals(
            4,
            chromeDisplayedPage(
                currentPage = 4,
                isScrollInProgress = false,
                previousPage = 1,
            ),
        )
    }

    @Test
    fun `滚动过程中保持上一页`() {
        assertEquals(
            1,
            chromeDisplayedPage(
                currentPage = 4,
                isScrollInProgress = true,
                previousPage = 1,
            ),
        )
    }

    @Test
    fun `拖出去又弹回来时不跳字`() {
        // 拖到第 3 页又弹回第 1 页：中途 currentPage 可能已经变成 2 / 3，
        // 但只要还在滚动就始终显示 1；最后停稳仍显示 1。
        assertEquals(
            1,
            chromeDisplayedPage(currentPage = 2, isScrollInProgress = true, previousPage = 1),
        )
        assertEquals(
            1,
            chromeDisplayedPage(currentPage = 3, isScrollInProgress = true, previousPage = 1),
        )
        assertEquals(
            1,
            chromeDisplayedPage(currentPage = 1, isScrollInProgress = false, previousPage = 1),
        )
    }

    @Test
    fun `首帧与相邻页的落定`() {
        assertEquals(
            0,
            chromeDisplayedPage(currentPage = 0, isScrollInProgress = false, previousPage = 0),
        )
        assertEquals(
            5,
            chromeDisplayedPage(currentPage = 5, isScrollInProgress = false, previousPage = 4),
        )
    }
}
