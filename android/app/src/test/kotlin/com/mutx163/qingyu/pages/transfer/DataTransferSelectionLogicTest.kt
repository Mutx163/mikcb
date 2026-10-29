package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.share.TransferScope
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「二维码范围弹窗 / 选课弹层」的纯逻辑（2026-10-29 审核补）。
 *
 * 期望值全部按 Dart 源码手推：
 * - 动作序列：`data_transfer_screen.dart:710-734`（取消 → 本周 → 勾选课程 → 时间模板 → 发送当前）；
 * - 主操作标记：同处 `:730` 的 `isPrimary: true` 只落在最后一个；
 * - 科目聚合：`lib/utils/course_group.dart:24-35`（按 name 分组、保持出现顺序、组员取第一门）；
 * - 整组勾选：`data_transfer_screen.dart:797-811`（全选则清、否则补齐）；
 * - 组行高亮判据：`:793-795` 的「任一课程被勾」。
 */
class DataTransferSelectionLogicTest {

    // ── 二维码范围弹窗 ──────────────────────────────────────────────

    @Test
    fun `范围弹窗是取消加四个范围共五个动作`() {
        val labels = DataTransferLogic.qrScopeDialogActions().map { it.label }
        assertEquals(
            listOf("取消", "分享本周课表", "分享勾选的课程", "分享时间模板", "二维码发送当前课表"),
            labels,
        )
    }

    @Test
    fun `只有取消动作没有范围`() {
        val actions = DataTransferLogic.qrScopeDialogActions()
        assertEquals(1, actions.count { it.scope == null })
        assertEquals("取消", actions.first().label)
        assertEquals(null, actions.first().scope)
    }

    @Test
    fun `最后一个动作是主操作且指向发送当前课表`() {
        val actions = DataTransferLogic.qrScopeDialogActions()
        assertEquals(1, actions.count { it.isPrimary })
        val primary = actions.single { it.isPrimary }
        assertEquals(TransferScope.CURRENT_TIMETABLE, primary.scope)
        assertTrue(actions.last().isPrimary)
    }

    @Test
    fun `范围顺序与 Dart 一致（本周在勾选课程之前）`() {
        val scopes = DataTransferLogic.qrScopeDialogActions().mapNotNull { it.scope }
        assertEquals(
            listOf(
                TransferScope.WEEK_TIMETABLE,
                TransferScope.SELECTED_COURSES,
                TransferScope.TIME_TEMPLATE,
                TransferScope.CURRENT_TIMETABLE,
            ),
            scopes,
        )
    }

    @Test
    fun `只有选课两类范围需要先勾课`() {
        assertTrue(DataTransferLogic.requiresCourseSelection(TransferScope.SELECTED_COURSES))
        assertTrue(DataTransferLogic.requiresCourseSelection(TransferScope.SELECTED_COURSE))
        assertFalse(DataTransferLogic.requiresCourseSelection(TransferScope.CURRENT_TIMETABLE))
        assertFalse(DataTransferLogic.requiresCourseSelection(TransferScope.ALL_DATA))
        assertFalse(DataTransferLogic.requiresCourseSelection(TransferScope.WEEK_TIMETABLE))
        assertFalse(DataTransferLogic.requiresCourseSelection(TransferScope.TIME_TEMPLATE))
    }

    // ── 科目聚合 ────────────────────────────────────────────────────

    @Test
    fun `同名课程聚合成一行并保持出现顺序`() {
        val courses = listOf(
            course(id = "c1", name = "高数", teacher = "张老师", dayOfWeek = 1),
            course(id = "c2", name = "英语", teacher = "李老师", dayOfWeek = 2),
            course(id = "c3", name = "高数", teacher = "张老师", dayOfWeek = 3),
        )
        val groups = DataTransferLogic.courseGroups(courses)
        assertEquals(listOf("高数", "英语"), groups.map { it.name })
        assertEquals(listOf("c1", "c3"), groups.first().courseIds)
        assertEquals(listOf("c2"), groups.last().courseIds)
    }

    @Test
    fun `组长取该组第一门课的老师`() {
        val courses = listOf(
            course(id = "c1", name = "高数", teacher = ""),
            course(id = "c2", name = "高数", teacher = "王老师"),
        )
        val groups = DataTransferLogic.courseGroups(courses)
        assertEquals(1, groups.size)
        // Dart `CourseGroup.teacher => courses.first.teacher`：空老师也照抄，不做回退。
        assertEquals("", groups.single().teacher)
    }

    @Test
    fun `没有课程时没有科目行`() {
        assertTrue(DataTransferLogic.courseGroups(emptyList()).isEmpty())
    }

    // ── 整组勾选 ────────────────────────────────────────────────────

    @Test
    fun `点未全选的组会补齐整组`() {
        val group = TransferCourseGroup("高数", "张老师", listOf("c1", "c3"))
        val selected = DataTransferLogic.toggleCourseGroup(setOf("c1"), group)
        assertEquals(setOf("c1", "c3"), selected)
    }

    @Test
    fun `点已全选的组会整组取消`() {
        val group = TransferCourseGroup("高数", "张老师", listOf("c1", "c3"))
        val selected = DataTransferLogic.toggleCourseGroup(setOf("c1", "c3", "c9"), group)
        assertEquals(setOf("c9"), selected)
    }

    @Test
    fun `空组不会改动选中集合`() {
        val group = TransferCourseGroup("空组", "", emptyList())
        assertEquals(setOf("c1"), DataTransferLogic.toggleCourseGroup(setOf("c1"), group))
    }

    @Test
    fun `组内任一门被勾就算该行已勾选`() {
        val group = TransferCourseGroup("高数", "张老师", listOf("c1", "c3"))
        assertTrue(DataTransferLogic.isCourseGroupSelected(setOf("c3"), group))
        assertFalse(DataTransferLogic.isCourseGroupSelected(setOf("c9"), group))
        assertFalse(DataTransferLogic.isCourseGroupSelected(emptySet(), group))
    }

    // ── 概览真实计数 ────────────────────────────────────────────────

    @Test
    fun `概览的时间模板数用真实值而不是写死的一`() {
        val rows = DataTransferLogic.overviewRows(
            TransferOverviewInput(
                courseCount = 12,
                activeProfileName = "大二上",
                profileCount = 2,
                timeSchemeCount = 3,
                currentWeek = 7,
                semesterStartDate = null,
            ),
        )
        assertTrue(rows.any { it.label == "时间模板" && it.value == "3 套" })
        assertTrue(rows.any { it.label == "当前课表" && it.value == "大二上" })
        assertTrue(rows.any { it.label == "当前周" && it.value == "第 7 周" })
    }

    private fun course(
        id: String,
        name: String,
        teacher: String,
        dayOfWeek: Int = 1,
    ): Course = Course(
        id = id,
        name = name,
        teacher = teacher,
        location = "A101",
        dayOfWeek = dayOfWeek,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
    )
}
