package com.mutx163.qingyu.pages.schedule

import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.ScheduleRecurrence
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * 日程提醒排程计算层测试。
 *
 * 期望值来源：
 * - `test/services/exam_reminder_service_test.dart` 的 `schedule reminders` 分组；
 * - `test/services/schedule_reminder_sibling_override_test.dart`（同日多例外去重）；
 * - `lib/services/exam_reminder_service.dart:197-361`（buildScheduleFires / activeIds）。
 */
class ScheduleReminderLogicTest {

    private val zone = ZoneId.of("Asia/Shanghai")

    private fun item(
        id: String,
        title: String = "每日自习",
        startDate: LocalDate = LocalDate.of(2026, 7, 10),
        endDate: LocalDate = startDate,
        recurrence: ScheduleRecurrence = ScheduleRecurrence.DAILY,
        reminderMinutes: Long? = 30L,
        enabled: Boolean = true,
        exceptionDates: List<LocalDateTime> = emptyList(),
        seriesId: String? = null,
        occurrenceDate: LocalDateTime? = null,
        startTime: String = "09:00",
        endTime: String = "10:00",
        location: String? = null,
    ) = ScheduleItem(
        id = id,
        title = title,
        location = location,
        startDate = startDate.atStartOfDay(),
        endDate = endDate.atStartOfDay(),
        startTime = startTime,
        endTime = endTime,
        recurrence = recurrence,
        exceptionDates = exceptionDates,
        reminderMinutesBefore = reminderMinutes,
        enabled = enabled,
        seriesId = seriesId,
        occurrenceDate = occurrenceDate,
        createdAt = LocalDateTime.of(2026, 7, 1, 0, 0),
        updatedAt = LocalDateTime.of(2026, 7, 1, 0, 0),
    )

    private fun date(y: Int, m: Int, d: Int): LocalDateTime = LocalDateTime.of(y, m, d, 0, 0)

    @Test
    fun `expands future recurring schedule occurrences`() {
        // [Dart抄录-测试] exam_reminder_service_test.dart:216-230
        val fires = ScheduleReminderLogic.buildFires(
            items = listOf(
                item(id = "schedule-1", endDate = LocalDate.of(2026, 7, 12)),
            ),
            now = LocalDateTime.of(2026, 7, 10, 8, 0),
            zone = zone,
        )

        assertEquals(3, fires.size)
        assertEquals(
            listOf(
                "schedule:schedule-1@2026-07-10",
                "schedule:schedule-1@2026-07-11",
                "schedule:schedule-1@2026-07-12",
            ),
            fires.map { it.scheduleId },
        )
        assertEquals(30, fires.first().offsetMinutes)
        assertEquals("09:00-10:00", fires.first().body)
        assertEquals(
            LocalDateTime.of(2026, 7, 10, 9, 0).atZone(zone).toInstant().toEpochMilli(),
            fires.first().startEpochMillis,
        )
    }

    @Test
    fun `disabled schedule and disabled override do not retain alarms`() {
        // [Dart抄录-测试] exam_reminder_service_test.dart:232-254
        val root = item(
            id = "schedule-1",
            endDate = LocalDate.of(2026, 7, 12),
            exceptionDates = listOf(date(2026, 7, 11)),
        )
        val disabledOverride = item(
            id = "schedule-1@2026-07-11",
            startDate = LocalDate.of(2026, 7, 11),
            recurrence = ScheduleRecurrence.NONE,
            reminderMinutes = null,
            enabled = false,
            seriesId = root.id,
            occurrenceDate = date(2026, 7, 11),
        )
        val items = listOf(root, disabledOverride)
        val now = LocalDateTime.of(2026, 7, 10, 8, 0)

        assertEquals(
            listOf("schedule:schedule-1@2026-07-10", "schedule:schedule-1@2026-07-12"),
            ScheduleReminderLogic.buildFires(items, now = now, zone = zone).map { it.scheduleId },
        )
        assertEquals(
            setOf("schedule:schedule-1@2026-07-10", "schedule:schedule-1@2026-07-12"),
            ScheduleReminderLogic.buildActiveIds(items, now = now),
        )
    }

    @Test
    fun `disabled recurring root suppresses all series reminder fires`() {
        // [Dart抄录-测试] exam_reminder_service_test.dart:256-289
        val root = item(
            id = "schedule-1",
            endDate = LocalDate.of(2026, 7, 12),
            enabled = false,
        )
        val enabledOverride = item(
            id = "schedule-1@2026-07-11",
            startDate = LocalDate.of(2026, 7, 11),
            recurrence = ScheduleRecurrence.NONE,
            reminderMinutes = 15L,
            seriesId = root.id,
            occurrenceDate = date(2026, 7, 11),
        )
        val now = LocalDateTime.of(2026, 7, 10, 8, 0)

        assertTrue(ScheduleReminderLogic.buildFires(listOf(root, enabledOverride), now = now, zone = zone).isEmpty())
        assertTrue(ScheduleReminderLogic.buildActiveIds(listOf(root, enabledOverride), now = now).isEmpty())
    }

    @Test
    fun `moved override replaces natural occurrence by displayed date`() {
        // [Dart抄录-测试] exam_reminder_service_test.dart:291-330
        val root = item(
            id = "schedule-1",
            endDate = LocalDate.of(2026, 7, 12),
            exceptionDates = listOf(date(2026, 7, 11)),
        )
        val movedOverride = item(
            id = "schedule-1@2026-07-11",
            title = "移动后的自习",
            startDate = LocalDate.of(2026, 7, 12),
            recurrence = ScheduleRecurrence.NONE,
            reminderMinutes = 45L,
            seriesId = root.id,
            occurrenceDate = date(2026, 7, 11),
        )
        val fires = ScheduleReminderLogic.buildFires(
            items = listOf(root, movedOverride),
            now = LocalDateTime.of(2026, 7, 10, 8, 0),
            zone = zone,
        )

        assertEquals(2, fires.size)
        assertEquals(
            listOf("schedule:schedule-1@2026-07-10", "schedule:schedule-1@2026-07-11"),
            fires.map { it.scheduleId },
        )
        assertEquals("移动后的自习", fires.last().title)
        // 覆盖行被移到 07-12 显示，响点按**显示日**算。
        assertEquals(
            LocalDateTime.of(2026, 7, 12, 9, 0).atZone(zone).toInstant().toEpochMilli(),
            fires.last().startEpochMillis,
        )
    }

    @Test
    fun `skips schedule fire already in the past`() {
        // [Dart抄录-测试] exam_reminder_service_test.dart:332-343
        val fires = ScheduleReminderLogic.buildFires(
            items = listOf(
                item(id = "schedule-1", endDate = LocalDate.of(2026, 7, 12)),
            ),
            now = LocalDateTime.of(2026, 7, 10, 8, 45),
            zone = zone,
        )
        assertEquals(2, fires.size)
        assertEquals(
            LocalDateTime.of(2026, 7, 11, 9, 0).atZone(zone).toInstant().toEpochMilli(),
            fires.first().startEpochMillis,
        )
    }

    @Test
    fun `includePastOffsets keeps overdue fire for the retry channel`() {
        val items = listOf(item(id = "solo", startDate = LocalDate.of(2026, 7, 10), recurrence = ScheduleRecurrence.NONE))
        val now = LocalDateTime.of(2026, 7, 10, 10, 0)

        assertTrue(ScheduleReminderLogic.buildFires(items, now = now, zone = zone).isEmpty())

        val planned = ScheduleReminderLogic.buildFires(items, now = now, zone = zone, includePastOffsets = true)
        assertEquals(1, planned.size)
        assertTrue(
            "schedule:solo#30" in
                ScheduleReminderLogic.buildPlannedFireKeys(items, now = now, zone = zone),
        )
    }

    @Test
    fun `two sibling overrides moved to the same day both get reminders`() {
        // [Dart抄录-测试] schedule_reminder_sibling_override_test.dart
        // 2026-09-01 是周二；weekly 以开始日的星期重复：09-01 / 08 / 15 / 22 / 29。
        val series = item(
            id = "series",
            startDate = LocalDate.of(2026, 9, 1),
            endDate = LocalDate.of(2026, 9, 30),
            recurrence = ScheduleRecurrence.WEEKLY,
            exceptionDates = listOf(date(2026, 9, 1), date(2026, 9, 15)),
        )
        val movedFromSep1 = item(
            id = "ov-a",
            title = "从 09-01 移来",
            startDate = LocalDate.of(2026, 9, 8),
            recurrence = ScheduleRecurrence.NONE,
            seriesId = "series",
            occurrenceDate = date(2026, 9, 1),
        )
        val movedFromSep15 = item(
            id = "ov-b",
            title = "从 09-15 移来",
            startDate = LocalDate.of(2026, 9, 8),
            recurrence = ScheduleRecurrence.NONE,
            seriesId = "series",
            occurrenceDate = date(2026, 9, 15),
        )
        val items = listOf(series, movedFromSep1, movedFromSep15)
        val now = LocalDateTime.of(2026, 9, 1, 0, 30)

        val fires = ScheduleReminderLogic.buildFires(items, now = now, zone = zone)
        val onSep8 = fires.filter { fire ->
            fire.localDate == "2026-09-08"
        }

        assertEquals(setOf("从 09-01 移来", "从 09-15 移来"), onSep8.map { it.title }.toSet())
        // 两个 id 必须互不相同，否则 requestCode 撞车、后写入的闹钟会顶掉前一条。
        assertEquals(2, onSep8.map { it.scheduleId }.toSet().size)
        val activeIds = ScheduleReminderLogic.buildActiveIds(items, now = now)
        assertTrue(activeIds.containsAll(onSep8.map { it.scheduleId }))
    }

    @Test
    fun `single override still suppresses the natural occurrence`() {
        val series = item(
            id = "series",
            startDate = LocalDate.of(2026, 9, 1),
            endDate = LocalDate.of(2026, 9, 30),
            recurrence = ScheduleRecurrence.WEEKLY,
            exceptionDates = listOf(date(2026, 9, 1), date(2026, 9, 15)),
        )
        val movedFromSep1 = item(
            id = "ov-a",
            title = "从 09-01 移来",
            startDate = LocalDate.of(2026, 9, 8),
            recurrence = ScheduleRecurrence.NONE,
            seriesId = "series",
            occurrenceDate = date(2026, 9, 1),
        )
        val fires = ScheduleReminderLogic.buildFires(
            items = listOf(series, movedFromSep1),
            now = LocalDateTime.of(2026, 9, 1, 0, 30),
            zone = zone,
        )
        val onSep8 = fires.filter { it.localDate == "2026-09-08" }
        assertEquals(listOf("从 09-01 移来"), onSep8.map { it.title })
    }

    @Test
    fun `override whose root is absent is still scheduled`() {
        // Dart `_buildScheduleInstances`：rootEnabledById 只含列表里真实存在的根。
        val orphan = item(
            id = "ov-orphan",
            startDate = LocalDate.of(2026, 7, 11),
            recurrence = ScheduleRecurrence.NONE,
            seriesId = "ghost-root",
            occurrenceDate = date(2026, 7, 11),
        )
        val fires = ScheduleReminderLogic.buildFires(
            items = listOf(orphan),
            now = LocalDateTime.of(2026, 7, 10, 8, 0),
            zone = zone,
        )
        assertEquals(listOf("schedule:ghost-root@2026-07-11"), fires.map { it.scheduleId })
    }

    @Test
    fun `no reminder or non positive reminder yields no fire`() {
        val items = listOf(
            item(id = "none", recurrence = ScheduleRecurrence.NONE, reminderMinutes = null),
            item(id = "zero", recurrence = ScheduleRecurrence.NONE, reminderMinutes = 0L),
        )
        assertTrue(
            ScheduleReminderLogic.buildFires(
                items = items,
                now = LocalDateTime.of(2026, 7, 10, 8, 0),
                zone = zone,
            ).isEmpty(),
        )
    }

    @Test
    fun `invalid start time is skipped`() {
        val fires = ScheduleReminderLogic.buildFires(
            items = listOf(
                item(id = "bad", recurrence = ScheduleRecurrence.NONE, startTime = "9点"),
            ),
            now = LocalDateTime.of(2026, 7, 10, 8, 0),
            zone = zone,
        )
        assertTrue(fires.isEmpty())
    }

    @Test
    fun `body appends location when present`() {
        val fires = ScheduleReminderLogic.buildFires(
            items = listOf(
                item(
                    id = "solo",
                    recurrence = ScheduleRecurrence.NONE,
                    location = "  报告厅  ",
                ),
            ),
            now = LocalDateTime.of(2026, 7, 10, 8, 0),
            zone = zone,
        )
        assertEquals("09:00-10:00 · 报告厅", fires.single().body)
    }

    @Test
    fun `request code is stable and namespaced`() {
        val a = ScheduleReminderLogic.stableRequestCode("schedule:a@2026-07-10", 30)
        val b = ScheduleReminderLogic.stableRequestCode("schedule:a@2026-07-10", 30)
        val c = ScheduleReminderLogic.stableRequestCode("schedule:a@2026-07-10", 60)

        assertEquals(a, b)
        assertNotEquals(a, c)
        assertEquals(
            ScheduleReminderLogic.REQUEST_CODE_NAMESPACE,
            a and ScheduleReminderLogic.REQUEST_CODE_NAMESPACE,
        )
    }
}
