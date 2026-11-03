package com.mutx163.qingyu.pages.timetable

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * 周 pager 外部同步判据（Dart `WeekPagerController.syncWeekPageWithProvider`，:206-274）。
 *
 * 这一组用例锚定的是「换档后当前周游标」的行为：provider 周次变了页面必须跟过去，
 * 但用户手势进行中绝不抢页。
 */
class WeekPagerSyncTest {

    @Test
    fun `外部周次与 pager 页不同时给出目标页`() {
        assertEquals(4, WeekPagerSync.targetPage(externalWeek = 5, pageCount = 20, currentPage = 2, isScrollInProgress = false))
    }

    @Test
    fun `已在目标页不重复跳`() {
        assertNull(WeekPagerSync.targetPage(externalWeek = 5, pageCount = 20, currentPage = 4, isScrollInProgress = false))
    }

    @Test
    fun `手势或动画进行中不抢页`() {
        // Dart `_hasPendingLocalWeekTransition`：本地翻页还没落定时外部周次先记下、不抢。
        assertNull(WeekPagerSync.targetPage(externalWeek = 9, pageCount = 20, currentPage = 2, isScrollInProgress = true))
    }

    @Test
    fun `周次超出总周数被钳到最后一页`() {
        assertEquals(4, WeekPagerSync.targetPage(externalWeek = 99, pageCount = 5, currentPage = 0, isScrollInProgress = false))
    }

    @Test
    fun `周次小于一被钳到第一页`() {
        assertEquals(0, WeekPagerSync.targetPage(externalWeek = 0, pageCount = 5, currentPage = 3, isScrollInProgress = false))
    }

    @Test
    fun `总周数为零时也按一页处理`() {
        // 学期没配总周数时页面仍要有一页；不能除到 0 之外的空 pager。
        assertNull(WeekPagerSync.targetPage(externalWeek = 1, pageCount = 0, currentPage = 0, isScrollInProgress = false))
        assertEquals(0, WeekPagerSync.targetPage(externalWeek = 3, pageCount = 0, currentPage = 1, isScrollInProgress = false))
    }
}
