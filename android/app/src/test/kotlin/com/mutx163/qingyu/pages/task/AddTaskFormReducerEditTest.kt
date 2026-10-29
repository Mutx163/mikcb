package com.mutx163.qingyu.pages.task

import com.mutx163.qingyu.app.AddTaskFormReducer
import com.mutx163.qingyu.core.CourseTask
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「编辑既有任务」载入逻辑的契约测试（2026-10-28）。
 *
 * 期望值人推（对齐 Dart `add_task_screen.dart:98-125` 的 `widget.task != null` 分支），
 * 不是从实现里抄：编辑态要把原任务的标题 / 备注 / 课程 / 周次 / 到期日 / 完成态**原样带进表单**，
 * 且**不抢键盘焦点**；空标题退回「课程作业」兜底。
 *
 * 这一条是「参数透传」类契约：只断言「载入后拿到了什么字段」，不走 UI——因为
 * `find.byType(AddTaskPage)` 那类断言根本抓不到「编辑时忘了带原值」这种 bug。
 */
class AddTaskFormReducerEditTest {

    private val now: LocalDateTime = LocalDateTime.of(2026, 10, 28, 12, 0)

    @Test
    fun `initialFromTask 载入原任务全部字段（编辑态）`() {
        val due = LocalDateTime.of(2026, 10, 30, 0, 0)
        val task = CourseTask(
            id = "t1",
            title = "复习第三章",
            courseId = null,
            sourceWeek = null,
            dueDate = due,
            note = "把课后题也做了",
            isCompleted = true,
            createdAt = now,
            updatedAt = now,
        )

        val state = AddTaskFormReducer.initialFromTask(task, emptyList())

        assertTrue("编辑态标记", state.isEditing)
        assertEquals("复习第三章", state.title)
        assertEquals("把课后题也做了", state.note)
        assertNull(state.courseId)
        assertEquals(TaskStrings.taskNoCourse, state.selectedCourseName)
        assertTrue("有到期日", state.hasDueDate)
        assertEquals(CourseTask.dateOnly(due), state.dueDate)
        assertEquals(TaskFormLogic.formatDate(due), state.dueDateFormatted)
        assertTrue("完成态沿用", state.isCompleted)
        assertFalse("编辑态不抢焦点", state.shouldAutofocusTitle)
    }

    @Test
    fun `initialFromTask 空标题退回课程作业兜底 且无到期日时开关关闭`() {
        val task = CourseTask(
            id = "t2",
            title = "   ",
            createdAt = now,
            updatedAt = now,
        )

        val state = AddTaskFormReducer.initialFromTask(task, emptyList())

        assertEquals(TaskStrings.taskHomeworkDefaultTitle, state.title)
        assertFalse("无到期日 → 开关关闭", state.hasDueDate)
        assertNull(state.dueDate)
        assertEquals(TaskFormLogic.formatDate(null), state.dueDateFormatted)
        assertFalse(state.isCompleted)
    }
}
