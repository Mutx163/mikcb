package com.mutx163.qingyu.pages.schedule

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * 快捷模板领域逻辑单测（移植 `test/domain/schedule_quick_presets_test.dart`）。
 */
class ScheduleQuickPresetsTest {

    @Test
    fun `包含 10 个预设且每个预设 ID 与标题均非空`() {
        assertEquals(10, kScheduleQuickPresets.size)
        val expectedIds = listOf(
            "groupMeeting", "lecture", "meeting", "defense", "interview",
            "dining", "workout", "study", "clinic", "commute",
        )
        assertEquals(expectedIds, kScheduleQuickPresets.map { it.id })

        for (preset in kScheduleQuickPresets) {
            val title = scheduleQuickPresetTitle(preset.id)
            assertNotNull("预设 ${preset.id} 必须能反查标题", title)
            assertEquals(false, title.isEmpty())
        }
    }

    @Test
    fun `当天能够容纳时长时起止时刻自然推进`() {
        // 09:00 = 540 分钟，时长 60 分钟 → 10:00 = 600 分钟
        val window = resolveSchedulePresetWindow(startMinutes = 540, durationMinutes = 60)
        assertEquals(540, window.startMinutes)
        assertEquals(600, window.endMinutes)
    }

    @Test
    fun `当天容纳不下时整段前移以 23点59分 结束`() {
        // 23:30 = 1410 分钟，时长 60 分钟，超出 1439
        // 前移后：结束落在 1439 (23:59)，开始落在 1439 - 60 = 1379 (22:59)
        val window = resolveSchedulePresetWindow(startMinutes = 1410, durationMinutes = 60)
        assertEquals(1379, window.startMinutes)
        assertEquals(1439, window.endMinutes)
    }

    @Test
    fun `超长时长超出全天时开始时刻截断为 00点00分`() {
        // 时长 2000 分钟（> 1440）
        val window = resolveSchedulePresetWindow(startMinutes = 1000, durationMinutes = 2000)
        assertEquals(0, window.startMinutes)
        assertEquals(1439, window.endMinutes)
    }

    @Test
    fun `非正时长返回原开始时刻作为起止点`() {
        val window = resolveSchedulePresetWindow(startMinutes = 600, durationMinutes = 0)
        assertEquals(600, window.startMinutes)
        assertEquals(600, window.endMinutes)
    }

    @Test
    fun `输入时刻超出有效范围时先钳制到 0到1439`() {
        val windowNegative = resolveSchedulePresetWindow(startMinutes = -10, durationMinutes = 30)
        assertEquals(0, windowNegative.startMinutes)
        assertEquals(30, windowNegative.endMinutes)

        val windowOverflow = resolveSchedulePresetWindow(startMinutes = 2000, durationMinutes = 30)
        assertEquals(1409, windowOverflow.startMinutes)
        assertEquals(1439, windowOverflow.endMinutes)
    }

    @Test
    fun `当前成立模板判定：标题未修改成立，用户修改后掉出选中态`() {
        val applied = "groupMeeting"
        assertEquals("groupMeeting", scheduleQuickPresetActiveId(applied, "组会"))
        assertEquals("groupMeeting", scheduleQuickPresetActiveId(applied, "  组会  "))

        // 用户手改了标题
        assertNull(scheduleQuickPresetActiveId(applied, "与导师研讨开题"))
        assertNull(scheduleQuickPresetActiveId(null, "组会"))
    }
}
