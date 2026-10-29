package com.mutx163.qingyu.pages.course

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseSessionNote
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 课程备注弹层模型层（[CourseNoteModel]）的单测。
 *
 * 期望值全部**从 Dart `lib/widgets/course_note_sheet.dart` 手推**，不从实现里抄：
 * - 初值口径：`:70-86`（`description` trim 后非空优先，否则回落 legacy `note`，note 不 trim）；
 * - 本节备注：`:74`（`sessionNoteForWeek(week)?.text`）；
 * - 载荷归一化：`:158-160`（`trim()`，空串 → 清空）；
 * - 副标题：`:214-216`（`课名 · 第N周 · 第A-B节`，两段走 ARB 模板）。
 *
 * 这里钉住的是**口径**，不是像素；渲染层不许再自己算一遍。
 */
class CourseNoteModelTest {

    // ── 初值：课程简介（description 优先，legacy note 回落）──

    @Test
    fun `课程简介优先取 description 并去掉首尾空白`() {
        val course = course(description = "  期末开卷，带计算器  ", note = "老数据里的整门备注")
        assertEquals("期末开卷，带计算器", CourseNoteModel.initialWholeNote(course))
    }

    @Test
    fun `description 只含空白时回落到 legacy note`() {
        val course = course(description = "   ", note = "老数据里的整门备注")
        assertEquals("老数据里的整门备注", CourseNoteModel.initialWholeNote(course))
    }

    @Test
    fun `description 为 null 时回落到 legacy note`() {
        val course = course(description = null, note = "老数据里的整门备注")
        assertEquals("老数据里的整门备注", CourseNoteModel.initialWholeNote(course))
    }

    /**
     * Dart `:79` 的回落支是 `(course.note ?? '')`，**没有 trim**。
     * 这条不是为了美观，而是钉住「与 Dart 一致」——悄悄 trim 会让老数据首行缩进消失。
     */
    @Test
    fun `回落 legacy note 时保持原样不 trim`() {
        val course = course(description = "  ", note = "  首行缩进的老备注  ")
        assertEquals("  首行缩进的老备注  ", CourseNoteModel.initialWholeNote(course))
    }

    @Test
    fun `简介与 legacy note 都没有时是空串`() {
        assertEquals("", CourseNoteModel.initialWholeNote(course(description = null, note = null)))
        assertEquals("", CourseNoteModel.initialWholeNote(null))
    }

    // ── 初值：本节备注 ──

    @Test
    fun `本节备注只取当前周那一条`() {
        val course = course(
            sessionNotes = mapOf(
                3 to CourseSessionNote(text = "第三周带电脑"),
                5 to CourseSessionNote(text = "第五周交报告"),
            ),
        )
        assertEquals("第三周带电脑", CourseNoteModel.initialSessionNote(course, 3))
        assertEquals("第五周交报告", CourseNoteModel.initialSessionNote(course, 5))
        assertEquals("", CourseNoteModel.initialSessionNote(course, 4))
    }

    @Test
    fun `没有备注表时本节备注是空串`() {
        assertEquals("", CourseNoteModel.initialSessionNote(course(), 1))
        assertEquals("", CourseNoteModel.initialSessionNote(null, 1))
    }

    @Test
    fun `initialDraft 同时给出两段初值`() {
        val course = course(
            description = "同名课程共享的简介",
            sessionNotes = mapOf(7 to CourseSessionNote(text = "第七周停课改自习")),
        )
        val draft = CourseNoteModel.initialDraft(course, 7)
        assertEquals("同名课程共享的简介", draft.wholeNote)
        assertEquals("第七周停课改自习", draft.sessionNote)

        val otherWeek = CourseNoteModel.initialDraft(course, 8)
        assertEquals("同名课程共享的简介", otherWeek.wholeNote)
        assertEquals("", otherWeek.sessionNote)
    }

    // ── 保存载荷归一化（trim + 空 → null）──

    @Test
    fun `归一化去掉首尾空白`() {
        assertEquals("带电脑", CourseNoteModel.normalize("  带电脑\n"))
    }

    @Test
    fun `归一化把空串和纯空白都变成 null`() {
        assertNull(CourseNoteModel.normalize(""))
        assertNull(CourseNoteModel.normalize("   "))
        assertNull(CourseNoteModel.normalize("\n\t  \r\n"))
    }

    @Test
    fun `保存载荷两段各自归一化`() {
        val payload = CourseNoteDraft(
            wholeNote = "  简介  ",
            sessionNote = "   ",
        ).savePayload
        assertEquals("简介", payload.wholeNote)
        assertNull(payload.sessionNote)

        val cleared = CourseNoteDraft(wholeNote = "", sessionNote = "本周带 U 盘").savePayload
        assertNull(cleared.wholeNote)
        assertEquals("本周带 U 盘", cleared.sessionNote)

        val bothCleared = CourseNoteDraft(wholeNote = "   ", sessionNote = "").savePayload
        assertNull(bothCleared.wholeNote)
        assertNull(bothCleared.sessionNote)
    }

    // ── 副标题 ──

    @Test
    fun `副标题是课名 中点 第N周 中点 第A到B节`() {
        val course = course(name = "高等数学", startSection = 1, endSection = 2)
        assertEquals("高等数学 · 第 3 周 · 第 1～2 节", CourseNoteModel.subtitle(course, 3))
    }

    @Test
    fun `副标题用课程自己的节次区间`() {
        val course = course(name = "体育", startSection = 5, endSection = 6)
        assertEquals("体育 · 第 12 周 · 第 5～6 节", CourseNoteModel.subtitle(course, 12))
    }

    // ── 只读门控 ──

    @Test
    fun `只读课程不可编辑`() {
        assertTrue(CourseNoteModel.isEditable(readOnly = false))
        assertEquals(false, CourseNoteModel.isEditable(readOnly = true))
    }

    // ── 脚手架 ──

    private fun course(
        id: String = "c1",
        name: String = "高等数学",
        teacher: String = "张老师",
        location: String = "三教-101",
        dayOfWeek: Int = 1,
        startSection: Int = 1,
        endSection: Int = 2,
        startTime: String = "08:00",
        endTime: String = "09:40",
        description: String? = null,
        note: String? = null,
        sessionNotes: Map<Int, CourseSessionNote>? = null,
    ): Course = Course(
        id = id,
        name = name,
        teacher = teacher,
        location = location,
        dayOfWeek = dayOfWeek,
        startSection = startSection,
        endSection = endSection,
        startTime = startTime,
        endTime = endTime,
        description = description,
        note = note,
        sessionNotes = sessionNotes,
    )
}
