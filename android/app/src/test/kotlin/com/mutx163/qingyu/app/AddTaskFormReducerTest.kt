package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.pages.task.TaskStrings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 作业表单状态机单测（T1 收尾：从课程操作弹层「作业」进来要预选那门课，且表单真的能存）。
 *
 * 期望值手推，出处：`TaskModel.kt:93-118`（`TaskFormDefaults`）与 `:395-422`（`TaskFormLogic.buildTask`），
 * 以及 Dart `lib/screens/add_task_screen.dart:115-124`（`_dueDate` / `_hasDueDate` 的初始化）。
 */
class AddTaskFormReducerTest {

    private val today = LocalDateTime.of(2026, 10, 28, 15, 30)
    private val occurrenceDate = LocalDateTime.of(2026, 10, 30, 8, 0)

    @Test
    fun `从课程进入时预选那门课 并把周次记进 sourceWeek`() {
        val course = course("c1", "高等数学")

        val state = AddTaskFormReducer.initial(
            preselectedCourse = course,
            sourceWeek = 3,
            courseOccurrenceDate = occurrenceDate,
            today = today,
        )

        assertEquals("c1", state.courseId)
        assertEquals("高等数学", state.selectedCourseName)
        assertEquals(3L, state.sourceWeek)
        assertEquals("", state.title)
        assertFalse("从课程进入不该抢焦点（键盘会遮住半屏）", state.shouldAutofocusTitle)
    }

    @Test
    fun `从课程进入时到期日默认是那节课的发生日期`() {
        val state = AddTaskFormReducer.initial(
            preselectedCourse = course("c1", "高等数学"),
            sourceWeek = 3,
            courseOccurrenceDate = occurrenceDate,
            today = today,
        )

        assertTrue(state.hasDueDate)
        // ⚠️ `TaskFormDefaults.initialDueDate` 对「从课程进入」是**原样返回**发生日期
        // （`TaskModel.kt:115`），只有「今天」那条兜底才过 `CourseTask.dateOnly`
        // ——归一化发生在保存时（`buildTask`），见下面那条用例。
        assertEquals(occurrenceDate, state.dueDate)
        assertEquals("2026年10月30日", state.dueDateFormatted)
    }

    @Test
    fun `纯新建时没有课程 抢焦点 到期日默认今天`() {
        val state = AddTaskFormReducer.initial(today = today)

        assertNull(state.courseId)
        assertNull(state.sourceWeek)
        assertEquals(TaskStrings.taskNoCourse, state.selectedCourseName)
        assertTrue("纯新建才抢焦点", state.shouldAutofocusTitle)
        assertEquals(CourseTask.dateOnly(today), state.dueDate)
        assertTrue(state.hasDueDate)
    }

    @Test
    fun `编辑态不抢焦点 且沿用原到期日`() {
        val original = LocalDateTime.of(2026, 9, 1, 9, 0)
        val state = AddTaskFormReducer.initial(
            isEditing = true,
            editingDueDate = original,
            today = today,
        )

        assertFalse(state.shouldAutofocusTitle)
        // 编辑态原样沿用（`TaskModel.kt:114`），归一化在保存时
        assertEquals(original, state.dueDate)
    }

    @Test
    fun `取消关联课程时 sourceWeek 一并清掉`() {
        val course = course("c1", "高等数学")
        val withCourse = AddTaskFormReducer.initial(
            preselectedCourse = course,
            sourceWeek = 3,
            courseOccurrenceDate = occurrenceDate,
            today = today,
        )

        val cleared = AddTaskFormReducer.withCourse(withCourse, null)
        assertNull(cleared.courseId)
        assertNull(cleared.sourceWeek)
        assertEquals(TaskStrings.taskNoCourse, cleared.selectedCourseName)
    }

    @Test
    fun `保存出来的作业带着那门课与周次`() {
        val course = course("c1", "高等数学")
        var state = AddTaskFormReducer.initial(
            preselectedCourse = course,
            sourceWeek = 3,
            courseOccurrenceDate = occurrenceDate,
            today = today,
        )
        state = AddTaskFormReducer.withTitle(state, "  第三章习题  ")

        val task = AddTaskFormReducer.buildTask(state, now = today)

        assertEquals("第三章习题", task.title)
        assertEquals("c1", task.courseId)
        assertEquals(3L, task.sourceWeek)
        assertEquals(CourseTask.dateOnly(occurrenceDate), task.dueDate)
        assertFalse(task.isCompleted)
    }

    @Test
    fun `标题为空时校验拦下来 且 buildTask 抛错`() {
        val state = AddTaskFormReducer.initial(today = today)

        assertEquals(TaskStrings.taskTitleRequired, AddTaskFormReducer.validate(state))
        assertEquals(
            TaskStrings.taskTitleRequired,
            AddTaskFormReducer.validate(AddTaskFormReducer.withTitle(state, "   ")),
        )
        try {
            AddTaskFormReducer.buildTask(state, now = today)
            error("空标题不该构建出作业")
        } catch (expected: IllegalArgumentException) {
            assertEquals("task_title_required", expected.message)
        }
    }

    @Test
    fun `一开始打字就清掉上一次的校验提示`() {
        val state = AddTaskFormReducer.initial(today = today).copy(titleError = TaskStrings.taskTitleRequired)
        val typed = AddTaskFormReducer.withTitle(state, "作业")

        assertNull(typed.titleError)
        assertEquals("作业", typed.title)
    }

    @Test
    fun `关掉到期日开关时不写 dueDate 但原日期留着`() {
        val state = AddTaskFormReducer.initial(today = today)
        val off = AddTaskFormReducer.withHasDueDate(state, false)

        assertFalse(off.hasDueDate)
        assertEquals("原日期留着（Dart :248 同口径）", CourseTask.dateOnly(today), off.dueDate)
        assertNull("不勾就不写", AddTaskFormReducer.buildTask(
            AddTaskFormReducer.withTitle(off, "作业"),
            now = today,
        ).dueDate)
    }

    private fun course(id: String, name: String): Course = Course(
        id = id,
        name = name,
        teacher = "张老师",
        location = "三教-101",
        dayOfWeek = 5,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:35",
        startWeek = 1,
        endWeek = 16,
    )
}
