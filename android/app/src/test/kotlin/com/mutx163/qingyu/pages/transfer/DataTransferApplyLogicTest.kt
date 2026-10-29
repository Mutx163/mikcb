package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.share.TransferApplyMode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 导入落盘与撤销的纯逻辑（2026-10-29 审核补）。
 *
 * 期望值按 Dart 手推：
 * - 合并语义：`unified_transfer_service.dart:485-507` 的 `mode: merge`（同 id 更新、新增追加、**缺的不删**）；
 * - 全量包合并：Dart 支持逐实体合并，Kotlin 侧明确拒绝并保持数据不动（本批的刻意差异）；
 * - 撤销范围：写入多少就抓多少（见 [DataTransferApplyLogic.undoKindFor]）。
 */
class DataTransferApplyLogicTest {

    // ── 可应用性 ────────────────────────────────────────────────────

    @Test
    fun `单课表包两种模式都可应用`() {
        val plan = singleProfilePlan(courses = listOf(course("a", "高数")))
        assertNull(DataTransferApplyLogic.rejectionCode(plan, TransferApplyMode.OVERWRITE))
        assertNull(DataTransferApplyLogic.rejectionCode(plan, TransferApplyMode.MERGE))
    }

    @Test
    fun `全量包覆盖可用但合并明确拒绝`() {
        val plan = fullBackupPlan(profiles = listOf(profile("p1", "大一上")))
        assertNull(DataTransferApplyLogic.rejectionCode(plan, TransferApplyMode.OVERWRITE))
        assertEquals(
            "full_backup_merge_unsupported",
            DataTransferApplyLogic.rejectionCode(plan, TransferApplyMode.MERGE),
        )
    }

    @Test
    fun `全量包没有档案时覆盖也拒绝`() {
        // 防御式：解析层已挡过空 profiles，但调用方可能直接构造计划。
        val plan = fullBackupPlan(profiles = emptyList())
        assertNull(DataTransferApplyLogic.rejectionCode(plan, TransferApplyMode.OVERWRITE))
        assertFalse(DataTransferApplyLogic.isFullBackupPlan(plan))
    }

    // ── 合并算法 ────────────────────────────────────────────────────

    @Test
    fun `合并时同 id 用包里的值`() {
        val current = listOf(course("a", "高数"), course("b", "英语"))
        val incoming = listOf(course("a", "高数(新)"))
        val merged = DataTransferApplyLogic.mergeCourses(current, incoming)
        assertEquals(listOf("高数(新)", "英语"), merged.map { it.name })
    }

    @Test
    fun `合并时新 id 追加到末尾并保持包里顺序`() {
        val current = listOf(course("a", "高数"))
        val incoming = listOf(course("x", "体育"), course("y", "物理"))
        val merged = DataTransferApplyLogic.mergeCourses(current, incoming)
        assertEquals(listOf("高数", "体育", "物理"), merged.map { it.name })
    }

    @Test
    fun `合并时不删除当前独有的课`() {
        val current = listOf(course("a", "高数"), course("b", "英语"), course("c", "化学"))
        val incoming = listOf(course("a", "高数"))
        val merged = DataTransferApplyLogic.mergeCourses(current, incoming)
        assertEquals(3, merged.size)
        assertTrue(merged.any { it.id == "c" })
    }

    @Test
    fun `包里没有课程时合并等于原样`() {
        val current = listOf(course("a", "高数"))
        assertEquals(current, DataTransferApplyLogic.mergeCourses(current, emptyList()))
    }

    @Test
    fun `合并后同一 id 不重复出现`() {
        val current = listOf(course("a", "高数"))
        val incoming = listOf(course("a", "高数"), course("a", "高数"))
        val merged = DataTransferApplyLogic.mergeCourses(current, incoming)
        assertEquals(1, merged.count { it.id == "a" })
    }

    // ── 超出作息的课 ────────────────────────────────────────────────

    @Test
    fun `超出作息节数的课按节次上限统计`() {
        val courses = listOf(
            course("a", "早八", start = 1, end = 2),
            course("b", "超出", start = 12, end = 14),
            course("c", "节次倒挂", start = 5, end = 3),
        )
        // Dart `TimeSchemeLogic.countCoursesWithoutVisibleRow`：start<1 或 end<start 或 end>节数。
        assertEquals(2, DataTransferApplyLogic.coursesBeyondScheme(courses, sectionCount = 12))
        assertEquals(0, DataTransferApplyLogic.coursesBeyondScheme(courses, sectionCount = 0))
    }

    // ── 撤销快照范围 ────────────────────────────────────────────────

    @Test
    fun `全量包撤销抓整份档案表`() {
        assertEquals(
            TransferUndoScope.FULL_PROFILES,
            DataTransferApplyLogic.undoKindFor(fullBackupPlan(profiles = listOf(profile("p1", "大一上")))),
        )
    }

    @Test
    fun `单课表包撤销只抓当前档案的三块与设置`() {
        assertEquals(
            TransferUndoScope.ACTIVE_PROFILE_CONTENT,
            DataTransferApplyLogic.undoKindFor(singleProfilePlan(courses = listOf(course("a", "高数")))),
        )
    }

    // ── 构造器 ──────────────────────────────────────────────────────

    private fun singleProfilePlan(courses: List<Course>) = TransferImportPlan(
        profiles = emptyList(),
        activeProfileId = "p1",
        courses = courses,
        settings = TimetableSettings.defaults(),
        currentWeek = 3,
        timeSchemes = emptyList(),
        tasks = emptyList(),
        exams = emptyList(),
        scheduleItems = emptyList(),
        scheduleDateRules = emptyList(),
    )

    private fun fullBackupPlan(profiles: List<TimetableProfile>) = TransferImportPlan(
        profiles = profiles,
        activeProfileId = profiles.firstOrNull()?.id,
        courses = emptyList(),
        settings = TimetableSettings.defaults(),
        currentWeek = 1,
        timeSchemes = emptyList(),
        tasks = emptyList(),
        exams = emptyList(),
        scheduleItems = emptyList(),
        scheduleDateRules = emptyList(),
    )

    private fun profile(id: String, name: String) = TimetableProfile(
        id = id,
        name = name,
        currentWeek = 1L,
        createdAt = java.time.LocalDateTime.of(2026, 9, 1, 8, 0),
        lastUsedAt = java.time.LocalDateTime.of(2026, 9, 1, 8, 0),
    )

    private fun course(
        id: String,
        name: String,
        start: Int = 1,
        end: Int = 2,
    ) = Course(
        id = id,
        name = name,
        teacher = "张老师",
        location = "A101",
        dayOfWeek = 1,
        startSection = start,
        endSection = end,
        startTime = "08:00",
        endTime = "09:40",
    )
}
