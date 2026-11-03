package com.mutx163.qingyu.pages.timetable

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.ClassReminderEntry
import com.mutx163.qingyu.core.ClassReminderLogic
import com.mutx163.qingyu.core.TimetableSettings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

/**
 * 单节课提醒数据源（`classReminders`）的模型层契约。
 *
 * 期望值全部来自 Dart 真源，不抄 Kotlin 实现：
 * - 条目形状 / 校验 / 丢弃规则：`lib/models/class_reminder.dart:24-100`；
 * - 设置里的读写位置：`lib/models/timetable_settings.dart:615 / :1246 / :1749`；
 * - 增删语义：`lib/services/timetable_reminder_service.dart:42-85`。
 *
 * 这些是统计「设过提醒」与课卡铃铛的唯一数据源：读错一个键，两个页面都跟着错。
 */
class ClassReminderSettingsTest {

    private fun entry(
        courseId: String = "c1",
        date: String = "2026-09-16",
        minuteOfDay: Int = 7 * 60 + 50,
    ) = ClassReminderEntry(courseId = courseId, date = date, minuteOfDay = minuteOfDay)

    // ---------- 条目形状与校验 ----------

    @Test
    fun `合法条目判定与 Dart isValid 一致`() {
        assertTrue(entry().isValid)
        assertTrue(entry(date = "2024-02-29").isValid) // 闰日
        assertFalse(entry(courseId = "  ").isValid)
        assertFalse(entry(date = "2026-9-16").isValid) // 月/日必须两位
        assertFalse(entry(date = "2026-02-31").isValid) // 顺延日不算
        assertFalse(entry(date = "2026-13-01").isValid)
        assertFalse(entry(minuteOfDay = -1).isValid)
        assertFalse(entry(minuteOfDay = 1440).isValid)
    }

    @Test
    fun `匹配键与统计口径逐字一致`() {
        assertEquals("c1|2026-09-16", entry().key)
        assertEquals("classreminder:c1@2026-09-16", entry().id)
        assertEquals(setOf("c1|2026-09-16"), ClassReminderLogic.keysOf(listOf(entry())))
    }

    @Test
    fun `日期格式化补零且与 Dart formatDate 同形`() {
        assertEquals("2026-09-06", ClassReminderEntry.formatDate(LocalDate.of(2026, 9, 6)))
        assertEquals("2026-10-14", ClassReminderEntry.formatDate(LocalDate.of(2026, 10, 14)))
    }

    // ---------- 解析：坏条目逐条丢弃 ----------

    @Test
    fun `fromJson 解析三个键`() {
        val parsed = ClassReminderEntry.fromJson(
            linkedMapOf("courseId" to "c9", "date" to "2026-10-14", "minuteOfDay" to 480),
        )
        assertEquals(entry(courseId = "c9", date = "2026-10-14", minuteOfDay = 480), parsed)
    }

    @Test
    fun `fromJson 非法输入返回 null 而不是抛错`() {
        assertNull(ClassReminderEntry.fromJson(null))
        assertNull(ClassReminderEntry.fromJson("bad"))
        assertNull(ClassReminderEntry.fromJson(linkedMapOf("date" to "2026-10-14", "minuteOfDay" to 480)))
        assertNull(ClassReminderEntry.fromJson(linkedMapOf("courseId" to "c1", "minuteOfDay" to 480)))
        assertNull(ClassReminderEntry.fromJson(linkedMapOf("courseId" to "c1", "date" to "2026-10-14")))
        // 分钟只认 Number：字符串数字按坏值丢弃（Dart `minuteOfDay is! num`）。
        assertNull(
            ClassReminderEntry.fromJson(
                linkedMapOf("courseId" to "c1", "date" to "2026-10-14", "minuteOfDay" to "480"),
            ),
        )
        assertNull(
            ClassReminderEntry.fromJson(
                linkedMapOf("courseId" to "c1", "date" to "2026-02-31", "minuteOfDay" to 480),
            ),
        )
    }

    @Test
    fun `listFromJson 非列表为空表 坏条目不影响其余`() {
        assertEquals(emptyList<ClassReminderEntry>(), ClassReminderEntry.listFromJson(null))
        assertEquals(emptyList<ClassReminderEntry>(), ClassReminderEntry.listFromJson("bad"))

        val parsed = ClassReminderEntry.listFromJson(
            listOf(
                linkedMapOf("courseId" to "c1", "date" to "2026-09-16", "minuteOfDay" to 470),
                "garbage",
                linkedMapOf("courseId" to "c2", "date" to "2026-02-31", "minuteOfDay" to 470),
                linkedMapOf("courseId" to "c3", "date" to "2026-09-17", "minuteOfDay" to 480),
            ),
        )
        assertEquals(listOf("c1", "c3"), parsed.map { it.courseId })
    }

    // ---------- 设置读写 ----------

    @Test
    fun `TimetableSettings 读写 classReminders`() {
        val settings = TimetableSettings(
            semesterWeekCount = 16,
            classReminders = listOf(entry()),
        )
        val json = settings.toJson()
        assertEquals(
            listOf(linkedMapOf("courseId" to "c1", "date" to "2026-09-16", "minuteOfDay" to 470)),
            json["classReminders"],
        )
        assertEquals(settings, TimetableSettings.fromJson(json))
    }

    @Test
    fun `缺键与坏值都是空表 不是拿不到`() {
        assertEquals(emptyList<ClassReminderEntry>(), TimetableSettings.fromJson(linkedMapOf()).classReminders)
        assertEquals(
            emptyList<ClassReminderEntry>(),
            TimetableSettings.fromJson(linkedMapOf("classReminders" to "bad")).classReminders,
        )
        // Dart toJson 恒写这个键（空列表也写），读侧不能把「空表」当成缺键。
        assertEquals(emptyList<Any?>(), TimetableSettings().toJson()["classReminders"])
    }

    @Test
    fun `落盘走既有 timetable_settings 合并写并能读回`() {
        val store = TimetableStore(InMemoryKeyValueStore())
        val reminders = listOf(entry(), entry(courseId = "c2", date = "2026-09-17"))

        store.saveSettings(TimetableSettings(semesterWeekCount = 18, classReminders = reminders))

        // 其它键照常写入，提醒也原样读回——不另造存储 key。
        assertEquals(reminders, store.loadSettings().classReminders)
        assertEquals(18, store.loadSettings().semesterWeekCount)
    }

    // ---------- 增删语义 ----------

    @Test
    fun `upsert 同课同日只留一条并按日期与分钟排序`() {
        val existing = listOf(
            entry(courseId = "c2", date = "2026-09-18", minuteOfDay = 600),
            entry(courseId = "c1", date = "2026-09-16", minuteOfDay = 480),
        )
        val replaced = ClassReminderLogic.upsert(
            existing,
            entry(courseId = "c1", date = "2026-09-16", minuteOfDay = 510),
        )
        assertEquals(2, replaced.size)
        assertEquals(listOf("c1", "c2"), replaced.map { it.courseId })
        assertEquals(510, replaced[0].minuteOfDay)

        val inserted = ClassReminderLogic.upsert(
            existing,
            entry(courseId = "c3", date = "2026-09-15", minuteOfDay = 700),
        )
        assertEquals(listOf("2026-09-15", "2026-09-16", "2026-09-18"), inserted.map { it.date })
    }

    @Test
    fun `remove 只删同课同日且幂等`() {
        val existing = listOf(
            entry(courseId = "c1", date = "2026-09-16"),
            entry(courseId = "c1", date = "2026-09-17"),
            entry(courseId = "c2", date = "2026-09-16"),
        )
        val removed = ClassReminderLogic.remove(existing, courseId = "c1", date = "2026-09-16")
        assertEquals(listOf("c1|2026-09-17", "c2|2026-09-16"), removed.map { it.key })

        // 不存在时静默幂等（Dart `changed = false` 直接返回）。
        assertEquals(removed, ClassReminderLogic.remove(removed, "c1", "2026-09-16"))
    }
}
