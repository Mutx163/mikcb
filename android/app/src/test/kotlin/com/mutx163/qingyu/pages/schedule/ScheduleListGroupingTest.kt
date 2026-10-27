package com.mutx163.qingyu.pages.schedule

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 日程列表分组与排序单元测试（移植 `test/domain/schedule_list_grouping_test.dart`）。
 */
class ScheduleListGroupingTest {

    @Test
    fun `空列表返回各组全空`() {
        val groups = ScheduleListGrouper.group(emptyList(), "2026-10-27")
        assertTrue(groups.isEmpty)
        assertEquals(0, groups.upcoming.size)
        assertEquals(0, groups.past.size)
        assertEquals(0, groups.paused.size)
    }

    @Test
    fun `排除单次覆盖条目（seriesId 非空）`() {
        val root = ScheduleItemData(
            id = "root1",
            title = "每日晨会",
            startDate = "2026-10-20",
            endDate = "2026-11-20",
            startTime = "09:00",
            endTime = "09:30",
            recurrence = ScheduleRecurrence.DAILY,
        )
        val override = ScheduleItemData(
            id = "override1",
            seriesId = "root1",
            title = "每日晨会（改期）",
            startDate = "2026-10-27",
            endDate = "2026-10-27",
            startTime = "10:00",
            endTime = "10:30",
        )

        val groups = ScheduleListGrouper.group(listOf(root, override), "2026-10-27")
        assertEquals(1, groups.upcoming.size)
        assertEquals("root1", groups.upcoming[0].item.id)
    }

    @Test
    fun `已禁用条目归入 paused 组并按日期倒序`() {
        val item1 = ScheduleItemData(
            id = "p1",
            title = "暂停任务1",
            startDate = "2026-10-10",
            endDate = "2026-10-10",
            startTime = "10:00",
            endTime = "11:00",
            enabled = false,
        )
        val item2 = ScheduleItemData(
            id = "p2",
            title = "暂停任务2",
            startDate = "2026-10-25",
            endDate = "2026-10-25",
            startTime = "14:00",
            endTime = "15:00",
            enabled = false,
        )

        val groups = ScheduleListGrouper.group(listOf(item1, item2), "2026-10-27")
        assertEquals(2, groups.paused.size)
        assertEquals("p2", groups.paused[0].item.id)
        assertEquals("p1", groups.paused[1].item.id)
    }

    @Test
    fun `单次日程在今天及之后归入 upcoming，早于今天归入 past`() {
        val pastItem = ScheduleItemData(
            id = "past1",
            title = "昨天的事",
            startDate = "2026-10-26",
            endDate = "2026-10-26",
            startTime = "10:00",
            endTime = "11:00",
        )
        val todayItem = ScheduleItemData(
            id = "today1",
            title = "今天的事",
            startDate = "2026-10-27",
            endDate = "2026-10-27",
            startTime = "14:00",
            endTime = "15:00",
        )
        val futureItem = ScheduleItemData(
            id = "future1",
            title = "明天的项",
            startDate = "2026-10-28",
            endDate = "2026-10-28",
            startTime = "09:00",
            endTime = "10:00",
        )

        val groups = ScheduleListGrouper.group(
            listOf(pastItem, todayItem, futureItem),
            "2026-10-27",
        )

        assertEquals(2, groups.upcoming.size)
        assertEquals("today1", groups.upcoming[0].item.id)
        assertEquals("2026-10-27", groups.upcoming[0].nextDate)
        assertFalse(groups.upcoming[0].ongoing)

        assertEquals("future1", groups.upcoming[1].item.id)
        assertEquals("2026-10-28", groups.upcoming[1].nextDate)

        assertEquals(1, groups.past.size)
        assertEquals("past1", groups.past[0].item.id)
        assertNull(groups.past[0].nextDate)
    }

    @Test
    fun `跨天单次日程跨越今天时标记 ongoing`() {
        val crossDayItem = ScheduleItemData(
            id = "cross1",
            title = "三日研讨会",
            startDate = "2026-10-25",
            endDate = "2026-10-28",
            startTime = "09:00",
            endTime = "17:00",
        )

        val groups = ScheduleListGrouper.group(listOf(crossDayItem), "2026-10-27")
        assertEquals(1, groups.upcoming.size)
        val entry = groups.upcoming[0]
        assertEquals("cross1", entry.item.id)
        assertEquals("2026-10-25", entry.nextDate)
        assertTrue(entry.ongoing)
    }

    @Test
    fun `重复日程正确计算下一次发生日期并跳过异常日期`() {
        // 2026-10-27 是周二
        val weeklyItem = ScheduleItemData(
            id = "weekly1",
            title = "每周二组会",
            startDate = "2026-10-13", // 周二
            endDate = "2026-11-24",
            startTime = "15:00",
            endTime = "16:00",
            recurrence = ScheduleRecurrence.WEEKLY,
            exceptionDates = listOf("2026-10-27"), // 今天被排除
        )

        val groups = ScheduleListGrouper.group(listOf(weeklyItem), "2026-10-27")
        assertEquals(1, groups.upcoming.size)
        // 跳过 10-27，下次应命中下周二 2026-11-03
        assertEquals("2026-11-03", groups.upcoming[0].nextDate)
    }

    @Test
    fun `upcoming 组按下次发生日、开始时间、结束时间升序排列`() {
        val item1 = ScheduleItemData(
            id = "i1",
            title = "A",
            startDate = "2026-10-27",
            endDate = "2026-10-27",
            startTime = "14:00",
            endTime = "15:00",
        )
        val item2 = ScheduleItemData(
            id = "i2",
            title = "B",
            startDate = "2026-10-27",
            endDate = "2026-10-27",
            startTime = "09:00",
            endTime = "10:00",
        )
        val item3 = ScheduleItemData(
            id = "i3",
            title = "C",
            startDate = "2026-10-27",
            endDate = "2026-10-27",
            startTime = "09:00",
            endTime = "09:30",
        )

        val groups = ScheduleListGrouper.group(listOf(item1, item2, item3), "2026-10-27")
        assertEquals(3, groups.upcoming.size)
        assertEquals("i3", groups.upcoming[0].item.id) // 09:00-09:30
        assertEquals("i2", groups.upcoming[1].item.id) // 09:00-10:00
        assertEquals("i1", groups.upcoming[2].item.id) // 14:00-15:00
    }

    @Test
    fun `past 组按结束日期倒序，同日按开始时间倒序`() {
        val item1 = ScheduleItemData(
            id = "p1",
            title = "A",
            startDate = "2026-10-20",
            endDate = "2026-10-20",
            startTime = "09:00",
            endTime = "10:00",
        )
        val item2 = ScheduleItemData(
            id = "p2",
            title = "B",
            startDate = "2026-10-20",
            endDate = "2026-10-20",
            startTime = "15:00",
            endTime = "16:00",
        )
        val item3 = ScheduleItemData(
            id = "p3",
            title = "C",
            startDate = "2026-10-22",
            endDate = "2026-10-22",
            startTime = "10:00",
            endTime = "11:00",
        )

        val groups = ScheduleListGrouper.group(listOf(item1, item2, item3), "2026-10-27")
        assertEquals(3, groups.past.size)
        assertEquals("p3", groups.past[0].item.id) // 10-22
        assertEquals("p2", groups.past[1].item.id) // 10-20 15:00
        assertEquals("p1", groups.past[2].item.id) // 10-20 09:00
    }
}
