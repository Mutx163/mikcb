package com.mutx163.qingyu.pages.task

import com.mutx163.qingyu.app.AddTaskFormReducer
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseSessionNote
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 作业表单**标题初值**的契约测试（2026-10-29 复刻审核补）。
 *
 * ## 为什么单独钉这一条
 *
 * 真值在 Dart `lib/screens/add_task_screen.dart:142-148`：
 *
 * ```dart
 * _titleController.text = task?.title.isNotEmpty == true
 *     ? task!.title
 *     : (initialCourse?.sessionNoteForWeek(initialWeek ?? 0)?.trimmedText ??
 *           (initialCourse != null ? l10n?.taskHomeworkDefaultTitle ?? 'Homework' : ''));
 * ```
 *
 * 意译成三条规则（顺序有意义）：
 * 1. 从课程加作业 → 用**那门课那一周的节次备注**当标题；
 * 2. 那一周没有备注 → 标题退成「课程作业」；
 * 3. 纯新建 → 空标题。
 *
 * Compose 侧此前一律从空标题开始：用户从课程面板点「作业」进来，Dart 那边标题已填好、
 * 点保存就完；Compose 这边标题空着、保存按钮是灰的 ⇒ 看起来像「点了没反应」。
 * 这类「初值丢了」的 bug 不会让编译失败，也不会让列表页任何测试变红——只有直接断言
 * **初值本身**才抓得到。
 *
 * ## 第 4 例是刻意复刻的"坏味道"
 *
 * 备注对象存在、但文本是空白（只勾了「本节有作业」）时，Dart 的 `?.trimmedText` **不**回落，
 * 标题就是空串。看着像 bug，但改了就是偏离真值，所以钉住它。
 */
class AddTaskInitialTitleTest {

    private val today = LocalDateTime.of(2026, 10, 29, 10, 0)

    @Test
    fun `从课程加作业时 标题预填那一周的节次备注`() {
        val course = course(
            notes = mapOf(3 to CourseSessionNote(text = "  第三章习题  ")),
        )

        val state = AddTaskFormReducer.initial(
            preselectedCourse = course,
            sourceWeek = 3,
            courseOccurrenceDate = LocalDateTime.of(2026, 10, 30, 8, 0),
            today = today,
        )

        assertEquals("第三章习题", state.title)
    }

    @Test
    fun `从课程加作业但那一周没有备注时 标题退成课程作业`() {
        val course = course(notes = mapOf(3 to CourseSessionNote(text = "第三章习题")))

        val state = AddTaskFormReducer.initial(
            preselectedCourse = course,
            // 第 4 周没有备注：只有第 3 周那条。
            sourceWeek = 4,
            courseOccurrenceDate = LocalDateTime.of(2026, 11, 6, 8, 0),
            today = today,
        )

        assertEquals(TaskStrings.taskHomeworkDefaultTitle, state.title)
    }

    @Test
    fun `纯新建时标题为空`() {
        val state = AddTaskFormReducer.initial(today = today)

        assertEquals("", state.title)
    }

    @Test
    fun `备注对象存在但文本空白时不回落（照抄 Dart 的 trimmedText 语义）`() {
        // 只勾了「本节有作业」，没写文字：Dart 的 `?.trimmedText` 返回 ""（不是 null），
        // 所以不会走到「课程作业」兜底。改了就是偏离真值。
        val course = course(
            notes = mapOf(3 to CourseSessionNote(text = "   ", hasHomework = true)),
        )

        val state = AddTaskFormReducer.initial(
            preselectedCourse = course,
            sourceWeek = 3,
            courseOccurrenceDate = LocalDateTime.of(2026, 10, 30, 8, 0),
            today = today,
        )

        assertEquals("", state.title)
    }

    private fun course(notes: Map<Int, CourseSessionNote>?): Course = Course(
        id = "c1",
        name = "高等数学",
        teacher = "张老师",
        location = "三教-101",
        dayOfWeek = 5,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:35",
        startWeek = 1,
        endWeek = 16,
        sessionNotes = notes,
    )
}
