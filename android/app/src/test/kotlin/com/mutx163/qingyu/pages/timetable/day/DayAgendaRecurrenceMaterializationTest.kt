package com.mutx163.qingyu.pages.timetable.day

import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.ScheduleRecurrence
import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDateTime

/**
 * 重复日程的单次发生不得被误判成跨天。
 *
 * ## 期望值来源（独立于 Kotlin 实现）
 *
 * Dart 侧 `ScheduleItemInstance.materializedItem`（`lib/models/schedule_item.dart:82-87`）：
 * ```dart
 * ScheduleItem get materializedItem {
 *   if (!item.isRecurring) return item;
 *   return item.copyWith(startDate: date, endDate: date);   // 起止日期改写成当天
 * }
 * ```
 * 周/日视图渲染前会先取 `instance.effectiveItem`
 * （`lib/domain/week_grid_agenda_placement.dart:133`），
 * 跨天判定 `continuesFromPreviousDay = item.startDate.isBefore(target)`
 * 用的已是**物化到当天**的日期，故重复日程的单次发生恒不跨天。
 *
 * 用户可见结果：一条「每周组会 09:00-10:00」（锚定 2026-09-01）
 * 在 2026-10-27 那一次，Flutter 显示 **09:00 - 10:00**，不是 00:00 - 23:59。
 *
 * ## 这条 bug 以前为什么没被发现
 *
 * 原 25 例测试覆盖聚合/排序/进度，没有一条测「重复日程在非锚定日长什么样」。
 */
class DayAgendaRecurrenceMaterializationTest {

    private val anchor = LocalDateTime.of(2026, 9, 1, 9, 0)

    /** 每周重复、09:00-10:00、锚定 2026-09-01。 */
    private fun weekly(): ScheduleItem = ScheduleItem(
        id = "s1",
        title = "每周组会",
        location = null,
        note = null,
        startDate = anchor,
        endDate = anchor,
        startTime = "09:00",
        endTime = "10:00",
        color = "#3482FF",
        createdAt = anchor,
        updatedAt = anchor,
        recurrence = ScheduleRecurrence.WEEKLY,
        exceptionDates = emptyList(),
        reminderMinutesBefore = null,
        enabled = true,
    )

    @Test
    fun `重复日程在非锚定日的单次发生保留原始钟点`() {
        val entry = DayAgendaLogic.scheduleEntryForDate(
            item = weekly(),
            targetDate = LocalDateTime.of(2026, 10, 27, 0, 0),
        )
        assertEquals("开始时间不该被跨天剪成 00:00", "09:00", entry.startTime)
        assertEquals("结束时间不该被跨天剪成 23:59", "10:00", entry.endTime)
        assertEquals("不该标记为承接前一天", false, entry.continuesFromPreviousDay)
        assertEquals("不该标记为延续到次日", false, entry.continuesToNextDay)
    }

    @Test
    fun `重复日程在锚定日当天同样正常`() {
        val entry = DayAgendaLogic.scheduleEntryForDate(
            item = weekly(),
            targetDate = LocalDateTime.of(2026, 9, 1, 0, 0),
        )
        assertEquals("09:00", entry.startTime)
        assertEquals("10:00", entry.endTime)
    }

    @Test
    fun `真正的跨天日程仍应被剪裁`() {
        // 对照组：非重复、确实跨天，必须保持既有剪裁行为。
        val multiDay = weekly().copy(
            recurrence = ScheduleRecurrence.NONE,
            startDate = LocalDateTime.of(2026, 10, 26, 22, 0),
            endDate = LocalDateTime.of(2026, 10, 28, 8, 0),
            startTime = "22:00",
            endTime = "08:00",
        )
        val entry = DayAgendaLogic.scheduleEntryForDate(
            item = multiDay,
            targetDate = LocalDateTime.of(2026, 10, 27, 0, 0),
        )
        assertEquals("真跨天的起始应剪成 00:00", "00:00", entry.startTime)
        assertEquals("真跨天的结束应剪成 23:59", "23:59", entry.endTime)
        assertEquals(true, entry.continuesFromPreviousDay)
        assertEquals(true, entry.continuesToNextDay)
    }

    @Test
    fun `非重复的单日日程不受影响`() {
        val single = weekly().copy(
            recurrence = ScheduleRecurrence.NONE,
            startDate = LocalDateTime.of(2026, 10, 27, 9, 0),
            endDate = LocalDateTime.of(2026, 10, 27, 9, 0),
        )
        val entry = DayAgendaLogic.scheduleEntryForDate(
            item = single,
            targetDate = LocalDateTime.of(2026, 10, 27, 0, 0),
        )
        assertEquals("09:00", entry.startTime)
        assertEquals("10:00", entry.endTime)
        assertEquals(false, entry.continuesFromPreviousDay)
        assertEquals(false, entry.continuesToNextDay)
    }
}
