package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableProfile
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * Phase 3.5 · L4 宿主层纯逻辑单测。
 *
 * 期望值全部**手推**（照 Dart 出处一条条推），不从实现里抄：
 * - `lib/domain/timetable_layout.dart:6-17`（可见天 / 时间列宽）
 * - `lib/models/timetable_settings.dart:754`（节次行高默认 68）
 * - `lib/widgets/timetable/timetable_empty_slot_layer.dart:46,111`（空档加课开关）
 * - `lib/services/storage_service.dart:1645`（首启档案名「默认课表」）
 */
class TimetableHostLogicTest {

    private val baseTime = LocalDateTime.of(2026, 10, 28, 8, 0)

    // ── 1. 可见星期几 ──

    @Test
    fun `隐藏周末时只留周一到周五`() {
        assertEquals(listOf(1, 2, 3, 4, 5), TimetableHostLogic.visibleDayNumbers(hideWeekends = true))
    }

    @Test
    fun `不隐藏周末时是完整七天`() {
        assertEquals(
            listOf(1, 2, 3, 4, 5, 6, 7),
            TimetableHostLogic.visibleDayNumbers(hideWeekends = false),
        )
    }

    // ── 2. 时间列宽 ──

    @Test
    fun `时间列宽窄档 34 宽档 40`() {
        assertEquals(34f, TimetableHostLogic.timeColumnWidthDp(wide = false), 0f)
        assertEquals(40f, TimetableHostLogic.timeColumnWidthDp(wide = true), 0f)
    }

    @Test
    fun `节次行高默认取 Dart 的 68 而不是页面签名占位 64`() {
        assertEquals(68f, TimetableHostLogic.DEFAULT_SECTION_HEIGHT_DP, 0f)
        assertEquals(68f, TimetableHostDisplayPrefs().sectionHeightDp, 0f)
    }

    // ── 3. 空档加课开关 ──

    @Test
    fun `开关开着且有跨度才放行`() {
        assertTrue(
            TimetableHostLogic.shouldAllowEmptySlotAdd(
                longPressToAddCourseEnabled = true,
                span = 1,
            ),
        )
    }

    @Test
    fun `开关关着一律不放行`() {
        assertFalse(
            TimetableHostLogic.shouldAllowEmptySlotAdd(
                longPressToAddCourseEnabled = false,
                span = 1,
            ),
        )
        assertFalse(
            TimetableHostLogic.shouldAllowEmptySlotAdd(
                longPressToAddCourseEnabled = false,
                span = 0,
            ),
        )
    }

    @Test
    fun `跨度为零或负不算空档 开关开着也不放行`() {
        // Dart 判据是 `!enabled || span <= 0`：两个条件都要过。
        assertFalse(
            TimetableHostLogic.shouldAllowEmptySlotAdd(
                longPressToAddCourseEnabled = true,
                span = 0,
            ),
        )
        assertFalse(
            TimetableHostLogic.shouldAllowEmptySlotAdd(
                longPressToAddCourseEnabled = true,
                span = -1,
            ),
        )
    }

    @Test
    fun `空档加课默认关闭`() {
        assertFalse(TimetableHostDisplayPrefs().longPressEmptySlotToAddCourseEnabled)
        assertFalse(TimetableHostDisplayPrefs().hideWeekends)
        assertFalse(TimetableHostDisplayPrefs().wideTimeColumn)
    }

    // ── 4. 档案名 ──

    @Test
    fun `当前档案命中时用它的名字`() {
        val profiles = listOf(profile("a", "课表 A"), profile("b", "课表 B"))
        assertEquals("课表 B", TimetableHostLogic.resolveProfileName(profiles, activeProfileId = "b"))
    }

    @Test
    fun `当前档案名是空白时退到未命名课表`() {
        val profiles = listOf(profile("a", "   "))
        assertEquals(
            TimetableProfile.UNNAMED,
            TimetableHostLogic.resolveProfileName(profiles, activeProfileId = "a"),
        )
    }

    @Test
    fun `当前档案 id 缺失时退到第一份档`() {
        val profiles = listOf(profile("a", "课表 A"), profile("b", "课表 B"))
        assertEquals("课表 A", TimetableHostLogic.resolveProfileName(profiles, activeProfileId = null))
    }

    @Test
    fun `当前档案 id 指向不存在的档时退到第一份档`() {
        val profiles = listOf(profile("a", "课表 A"))
        assertEquals("课表 A", TimetableHostLogic.resolveProfileName(profiles, activeProfileId = "zzz"))
    }

    @Test
    fun `一份档都没有时用首启兜底名`() {
        assertEquals(
            "默认课表",
            TimetableHostLogic.resolveProfileName(emptyList(), activeProfileId = null),
        )
        assertEquals("默认课表", TimetableHostLogic.DEFAULT_PROFILE_NAME)
    }

    // ── 5. 生效作息模板 ──

    @Test
    fun `生效模板命中时用它`() {
        val schemes = listOf(scheme("s1", "模板一"), scheme("s2", "模板二"))
        assertEquals("模板二", TimetableHostLogic.resolveActiveTimeScheme(schemes, "s2")?.name)
    }

    @Test
    fun `生效模板 id 缺失或指向不存在的档时退到第一份`() {
        val schemes = listOf(scheme("s1", "模板一"), scheme("s2", "模板二"))
        assertEquals("模板一", TimetableHostLogic.resolveActiveTimeScheme(schemes, null)?.name)
        assertEquals("模板一", TimetableHostLogic.resolveActiveTimeScheme(schemes, "zzz")?.name)
    }

    @Test
    fun `一份模板都没有时返回 null 让页面回落 settings 节次表`() {
        // 宿主不许自己造节次表：TimetableWeekPage.kt:126-127 会回落到 settings.sections。
        assertNull(TimetableHostLogic.resolveActiveTimeScheme(emptyList(), "s1"))
    }

    // ── 构造工具 ──

    private fun profile(id: String, name: String): TimetableProfile = TimetableProfile(
        id = id,
        name = name,
        currentWeek = 1,
        createdAt = baseTime,
        lastUsedAt = baseTime,
    )

    private fun scheme(id: String, name: String): TimeScheme = TimeScheme(
        id = id,
        name = name,
        sections = listOf(SectionTime("08:00", "08:45")),
        createdAt = baseTime,
        updatedAt = baseTime,
    )
}
