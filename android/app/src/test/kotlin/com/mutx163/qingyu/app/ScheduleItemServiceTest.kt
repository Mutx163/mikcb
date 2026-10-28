package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.ScheduleDateRule
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.ScheduleRecurrence
import com.mutx163.qingyu.core.TimetableProfile
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/**
 * [ScheduleItemService] / [ScheduleEditDispatcher] / 仓储日程落盘的 JVM 单测。
 *
 * 期望值**人手推导**（不抄实现）：
 * - 2026-11-02 是**周一**（2026-01-01 周四，2026-11-02 与其相差 305 天 ≡ +4 → 周一）。
 *   每周重复日程的下一次发生就是「同星期几的那天」，所以 11-02 起点 → 11-09 是第二次发生。
 * - 单次覆盖行的 id 按 `rootId@yyyy-MM-dd` 构造（Dart `ScheduleItem.buildOccurrenceId`）。
 * - 「改这一次」在根条目上记一条 exception（该日不再自然发生），覆盖行单独存在。
 */
class ScheduleItemServiceTest {

    // ---------- 纯逻辑 ----------

    @Test
    fun normalizeTrimsEmptyTextAndClampsEndBeforeStart() {
        val normalized = ScheduleItemService.normalize(
            item("s1", title = "  晨会  ", location = "   ", note = " 备注 ", start = "2026-11-05", end = "2026-11-01"),
        )
        assertEquals("晨会", normalized.title)
        assertNull("空串地点应变成 null", normalized.location)
        assertEquals("备注", normalized.note)
        // 结束日早于开始日 → 钳到开始日
        assertEquals(LocalDate.of(2026, 11, 5), normalized.endDate.toLocalDate())
    }

    @Test
    fun sortUsesClockOrderNotLexicographic() {
        val nine = item("a", title = "九点", start = "2026-11-02", startTime = "9:00", endTime = "9:30")
        val ten = item("b", title = "十点", start = "2026-11-02", startTime = "10:00", endTime = "10:30")
        val sorted = ScheduleItemService.sort(listOf(ten, nine))
        // 字典序会排成 "10:00" < "9:00"，按分钟序应是 9:00 在前。
        assertEquals(listOf("a", "b"), sorted.map { it.id })
    }

    // ---------- 增删改 ----------

    @Test
    fun addSortsPersistsAndNotifiesOnce() {
        val port = FakePort()
        ScheduleItemService.add(port, item("s1", title = "教研会", start = "2026-11-02"))
        assertEquals(listOf("s1"), port.scheduleItems.map { it.id })
        assertEquals(1, port.persists)
        assertEquals(1, port.notifies)
    }

    @Test
    fun updateSeriesRootDropsSingleOccurrenceOverrides() {
        val root = item("r1", title = "每周例会", start = "2026-11-02", end = "2026-12-31", recurrence = ScheduleRecurrence.WEEKLY)
        val override = item(
            "r1@2026-11-09", title = "改过的一次", start = "2026-11-09",
            recurrence = ScheduleRecurrence.NONE, seriesId = "r1", occurrenceDate = "2026-11-09",
        )
        val port = FakePort(listOf(root, override))

        ScheduleItemService.update(port, root.copy(title = "每周例会（新）"))

        // 改系列根 = 改全部：覆盖行被摘掉，只剩根。
        assertEquals(listOf("r1"), port.scheduleItems.map { it.id })
        assertEquals("每周例会（新）", port.scheduleItems.single().title)
    }

    @Test
    fun updateRollsBackDroppedOverridesOnPersistFailure() {
        val root = item("r1", title = "每周例会", start = "2026-11-02", end = "2026-12-31", recurrence = ScheduleRecurrence.WEEKLY)
        val override = item(
            "r1@2026-11-09", title = "改过的一次", start = "2026-11-09",
            recurrence = ScheduleRecurrence.NONE, seriesId = "r1", occurrenceDate = "2026-11-09",
        )
        val port = FakePort(listOf(root, override)).apply { failPersist = true }

        try {
            ScheduleItemService.update(port, root.copy(title = "x"))
            fail("落盘失败应抛异常")
        } catch (_: IllegalStateException) {
            // 期望
        }
        // 被系列语义连带摘掉的覆盖行必须退回内存。
        assertEquals(listOf("r1", "r1@2026-11-09"), port.scheduleItems.map { it.id }.sorted())
    }

    @Test
    fun deleteRemovesWholeSeriesIncludingOverrides() {
        val root = item("r1", title = "每周例会", start = "2026-11-02", end = "2026-12-31", recurrence = ScheduleRecurrence.WEEKLY)
        val override = item(
            "r1@2026-11-09", title = "改过的一次", start = "2026-11-09",
            recurrence = ScheduleRecurrence.NONE, seriesId = "r1", occurrenceDate = "2026-11-09",
        )
        val port = FakePort(listOf(root, override))

        ScheduleItemService.delete(port, "r1@2026-11-09")

        assertTrue("整系列（连根带覆盖）都应删掉", port.scheduleItems.isEmpty())
    }

    @Test
    fun deleteOccurrenceKeepsSeriesAndAddsException() {
        val root = item("r1", title = "每周例会", start = "2026-11-02", end = "2026-12-31", recurrence = ScheduleRecurrence.WEEKLY)
        val port = FakePort(listOf(root))

        ScheduleItemService.deleteOccurrence(port, "r1", date("2026-11-09"))

        val saved = port.scheduleItems.single()
        assertEquals("r1", saved.id)
        assertTrue("根条目应记一条 exception", saved.exceptionDates.any { it.toLocalDate() == LocalDate.of(2026, 11, 9) })
        assertFalse("删除的那一次不该再自然发生", saved.occursOn(date("2026-11-09")))
        assertTrue("其余周次仍在", saved.occursOn(date("2026-11-16")))
    }

    @Test
    fun deleteOccurrenceOfSingleOneOffDeletesWholeRow() {
        val oneOff = item("o1", title = "一次性", start = "2026-11-02", end = "2026-11-02", recurrence = ScheduleRecurrence.NONE)
        val port = FakePort(listOf(oneOff))

        ScheduleItemService.deleteOccurrence(port, "o1", date("2026-11-02"))

        assertTrue("单日一次性日程删这一次 = 整条消失", port.scheduleItems.isEmpty())
    }

    @Test
    fun updateOccurrenceCreatesOverrideAndExceptionOnRoot() {
        val root = item("r1", title = "每周例会", start = "2026-11-02", end = "2026-12-31", recurrence = ScheduleRecurrence.WEEKLY)
        val port = FakePort(listOf(root))

        val edited = item("ignored", title = "临时改到下午", start = "2026-11-02", startTime = "15:00", endTime = "16:00")
        ScheduleItemService.updateOccurrence(port, "r1", date("2026-11-09"), edited)

        val rootAfter = port.scheduleItems.first { it.id == "r1" }
        assertTrue("根条目记 exception", rootAfter.exceptionDates.any { it.toLocalDate() == LocalDate.of(2026, 11, 9) })

        val override = port.scheduleItems.first { it.id == "r1@2026-11-09" }
        assertEquals("r1", override.seriesId)
        assertEquals(LocalDate.of(2026, 11, 9), override.occurrenceDate!!.toLocalDate())
        // 未显式改日期：这次发生保留原日期，只改钟点
        assertEquals(LocalDate.of(2026, 11, 9), override.startDate.toLocalDate())
        assertEquals("15:00", override.startTime)
        assertEquals(ScheduleRecurrence.NONE, override.recurrence)

        // 只改了这一次：其他周次仍是根条目
        assertTrue("未被改的周次仍按系列发生", rootAfter.occursOn(date("2026-11-16")))
    }

    // ---------- 分派判据 ----------

    @Test
    fun dispatcherSaveRoutesNewToAdd() {
        val port = FakePort()
        ScheduleEditDispatcher.save(port, item("draft_1", title = "新日程", start = "2026-11-02"), isNew = true, isOccurrenceEditing = false, applyToAll = null)
        assertEquals(listOf("draft_1"), port.scheduleItems.map { it.id })
    }

    @Test
    fun dispatcherSaveRoutesOccurrenceOnlyToUpdateOccurrence() {
        val root = item("r1", title = "每周例会", start = "2026-11-02", end = "2026-12-31", recurrence = ScheduleRecurrence.WEEKLY)
        val port = FakePort(listOf(root))
        val draft = item("r1", title = "这一次改", start = "2026-11-02", occurrenceDate = "2026-11-09")

        ScheduleEditDispatcher.save(port, draft, isNew = false, isOccurrenceEditing = true, applyToAll = false)

        assertTrue("应产生覆盖行", port.scheduleItems.any { it.id == "r1@2026-11-09" })
        // 根仍在
        assertTrue(port.scheduleItems.any { it.id == "r1" })
    }

    @Test
    fun dispatcherSaveRoutesApplyToAllToSeriesUpdate() {
        val root = item("r1", title = "每周例会", start = "2026-11-02", end = "2026-12-31", recurrence = ScheduleRecurrence.WEEKLY)
        val override = item(
            "r1@2026-11-09", title = "旧覆盖", start = "2026-11-09",
            recurrence = ScheduleRecurrence.NONE, seriesId = "r1", occurrenceDate = "2026-11-09",
        )
        val port = FakePort(listOf(root, override))
        val draft = item("r1", title = "全部改", start = "2026-11-02", end = "2026-12-31", recurrence = ScheduleRecurrence.WEEKLY, occurrenceDate = "2026-11-09")

        ScheduleEditDispatcher.save(port, draft, isNew = false, isOccurrenceEditing = true, applyToAll = true)

        assertEquals("改全部应摘掉覆盖行", listOf("r1"), port.scheduleItems.map { it.id })
    }

    @Test
    fun dispatcherDeleteRoutesOccurrenceOnlyToDeleteOccurrence() {
        val root = item("r1", title = "每周例会", start = "2026-11-02", end = "2026-12-31", recurrence = ScheduleRecurrence.WEEKLY)
        val port = FakePort(listOf(root))
        val target = item("r1", title = "每周例会", start = "2026-11-02", end = "2026-12-31", recurrence = ScheduleRecurrence.WEEKLY, occurrenceDate = "2026-11-09")

        ScheduleEditDispatcher.delete(port, target, isOccurrenceEditing = true, applyToAll = false)

        assertTrue("根仍在", port.scheduleItems.any { it.id == "r1" })
        val rootAfter = port.scheduleItems.single()
        assertTrue(rootAfter.exceptionDates.any { it.toLocalDate() == LocalDate.of(2026, 11, 9) })
    }

    @Test
    fun dispatcherDeleteRoutesToWholeSeriesByDefault() {
        val root = item("r1", title = "每周例会", start = "2026-11-02", end = "2026-12-31", recurrence = ScheduleRecurrence.WEEKLY)
        val port = FakePort(listOf(root))
        val target = item("r1", title = "每周例会", start = "2026-11-02", end = "2026-12-31", recurrence = ScheduleRecurrence.WEEKLY)

        ScheduleEditDispatcher.delete(port, target, isOccurrenceEditing = false, applyToAll = null)

        assertTrue(port.scheduleItems.isEmpty())
    }

    // ---------- 仓储 / 落盘 ----------

    @Test
    fun repositoryPersistsScheduleItemsIntoProfilesAndReloads() {
        val raw = InMemoryKeyValueStore()
        val repository = TimetableRepository(TimetableStore(raw))

        ScheduleItemService.add(repository, item("s1", title = "教研会议", start = "2026-11-02"))

        assertEquals(listOf("s1"), repository.snapshot.scheduleItems.map { it.id })
        val profilesJson = raw.getString("timetable_profiles")!!
        assertTrue("日程应写进冻结格式的 timetable_profiles", profilesJson.contains("教研会议"))

        // 杀进程重开：重新读盘仍拿得到
        val reloaded = TimetableRepository(TimetableStore(raw))
        assertEquals(listOf("s1"), reloaded.snapshot.scheduleItems.map { it.id })
    }

    @Test
    fun repositoryPersistsScheduleDateRulesAndReloads() {
        val raw = InMemoryKeyValueStore()
        val repository = TimetableRepository(TimetableStore(raw))

        repository.updateScheduleDateRules(
            listOf(ScheduleDateRule("d1", "寒假作息", "scheme-x", "2026-01-15", "2026-02-20", true)),
        )

        assertEquals(1, repository.snapshot.scheduleDateRules.size)
        assertTrue(raw.getString("schedule_date_rules")!!.contains("寒假作息"))

        val reloaded = TimetableRepository(TimetableStore(raw))
        assertEquals(listOf("d1"), reloaded.snapshot.scheduleDateRules.map { it.id })
        assertEquals("scheme-x", reloaded.snapshot.scheduleDateRules.single().timeSchemeId)
    }

    // ---------- helpers ----------

    private fun date(iso: String): LocalDateTime = LocalDateTime.of(LocalDate.parse(iso), LocalTime.MIDNIGHT)

    private fun item(
        id: String,
        title: String = "日程",
        start: String,
        end: String = start,
        startTime: String = "09:00",
        endTime: String = "10:00",
        recurrence: ScheduleRecurrence = ScheduleRecurrence.NONE,
        enabled: Boolean = true,
        exceptionDates: List<LocalDateTime> = emptyList(),
        reminderMinutesBefore: Long? = null,
        seriesId: String? = null,
        occurrenceDate: String? = null,
        location: String? = null,
        note: String? = null,
    ): ScheduleItem = ScheduleItem(
        id = id,
        title = title,
        location = location,
        note = note,
        startDate = date(start),
        endDate = date(end),
        startTime = startTime,
        endTime = endTime,
        color = "#5B9CF6",
        createdAt = date("2026-10-01"),
        updatedAt = date("2026-10-01"),
        recurrence = recurrence,
        exceptionDates = exceptionDates,
        reminderMinutesBefore = reminderMinutesBefore,
        enabled = enabled,
        seriesId = seriesId,
        occurrenceDate = occurrenceDate?.let { date(it) },
    )

    /** 假端口：内存里的日程/档案 + 可数的落盘/通知/初始化次数 + 可切换的落盘失败。 */
    private class FakePort(
        initial: List<ScheduleItem> = emptyList(),
    ) : TimetableScheduleItemPort {
        override var scheduleItems: List<ScheduleItem> = initial
        override var profiles: List<TimetableProfile> = emptyList()
        var initialized = 0
        var persists = 0
        var notifies = 0
        var failPersist = false

        override fun initialize() {
            initialized++
        }

        override fun persistActiveProfileState() {
            persists++
            if (failPersist) throw IllegalStateException("disk full")
        }

        override fun notifyStateChanged() {
            notifies++
        }

        override fun logEvent(name: String, parameters: Map<String, Any>) {}

        override fun syncExamReminders() {}
    }
}
