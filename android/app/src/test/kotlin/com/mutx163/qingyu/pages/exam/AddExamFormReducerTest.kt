package com.mutx163.qingyu.pages.exam

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.ExamReminderPreset
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 加考试 / 编辑考试表单状态机（`AddExamFormReducer`）的 JVM 单测 —— 批次 F10 的 L0 证据。
 *
 * 期望值全部**对着 Dart 原件人推**得出（`lib/screens/add_exam_screen.dart` 行号写在各用例里），
 * 不是从 Kotlin 实现里抄的。
 */
class AddExamFormReducerTest {

    private val today: LocalDateTime = LocalDateTime.of(2030, 5, 1, 9, 30)

    private fun course(id: String, name: String, teacher: String = "张老师") = Course(
        id = id,
        name = name,
        teacher = teacher,
        location = "A101",
        dayOfWeek = 1,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
        color = "#3366FF",
    )

    private fun existingExam() = Exam(
        id = "exam-1",
        courseId = "c1",
        name = "期中考试",
        dateTime = LocalDateTime.of(2030, 5, 9, 0, 0),
        startTime = "09:00",
        endTime = "11:00",
        location = "B203",
        seatNumber = "17",
        note = "带计算器",
        reminderPreset = ExamReminderPreset.CUSTOM,
        customReminderMinutes = listOf(120, 30),
        createdAt = LocalDateTime.of(2030, 4, 20, 8, 0),
        updatedAt = LocalDateTime.of(2030, 4, 21, 8, 0),
    )

    // ------------------------------------------------------------------
    // 初始值
    // ------------------------------------------------------------------

    @Test
    fun `新建表单默认状态与 Dart 一致`() {
        // Dart `:74-77`：新建默认日期 = 今天 + 7 天，开始 08:30 / 结束 10:30。
        val state = AddExamFormReducer.initial(existing = null, today = today)

        assertFalse(state.isEditing)
        assertEquals("", state.name)
        assertNull(state.selectedCourseId)
        // 新建时 Dart 把日期直接填成「七天后」（`_selectedDate` 非空），但 `_hasSelectedDate`
        // 只在用户真的点过日期后才为 true（`:52`）——所以默认「请选择日期」。
        assertFalse(state.hasSelectedDate)
        assertEquals(LocalDateTime.of(2030, 5, 8, 0, 0), state.selectedDate)
        assertEquals("08:30", state.startTime)
        assertEquals("10:30", state.endTime)
        assertEquals(ExamReminderPreset.DAY_1_AND_HOUR_1, state.reminderPreset)
        assertTrue(state.customReminderMinutes.isEmpty())
    }

    @Test
    fun `编辑态载入既有考试不丢任何字段`() {
        val state = AddExamFormReducer.initialFromExam(existingExam())

        assertTrue(state.isEditing)
        // 表单里存的是**课程 id**（Dart `_selectedCourseId`），不是考试自己的 id。
        assertEquals("c1", state.selectedCourseId)
        assertEquals("期中考试", state.name)
        assertTrue(state.hasSelectedDate)
        assertEquals(LocalDateTime.of(2030, 5, 9, 0, 0), state.selectedDate)
        assertEquals("09:00", state.startTime)
        assertEquals("11:00", state.endTime)
        assertEquals("B203", state.location)
        assertEquals("17", state.seatNumber)
        assertEquals("带计算器", state.note)
        assertEquals(ExamReminderPreset.CUSTOM, state.reminderPreset)
        assertEquals(listOf(120, 30), state.customReminderMinutes)
    }

    // ------------------------------------------------------------------
    // 五道阻断（Dart `:1001-1041`）
    // ------------------------------------------------------------------

    @Test
    fun `名称留空给字段级错误而不是 toast`() {
        val state = AddExamFormReducer.initial(existing = null, today = today)
            .copy(selectedCourseId = "c1", hasSelectedDate = true)

        val result = AddExamFormReducer.validate(state)

        assertEquals(AddExamBlocker.NAME_REQUIRED, result.blocker)
        // Dart 这一条走 `FormField.validator`（字段下方 helper），不是 toast。
        assertEquals("请输入考试名称", result.state.nameError)
        assertNull(result.state.toastMessage)
    }

    @Test
    fun `未选关联课程被挡住`() {
        val state = AddExamFormReducer.initial(existing = null, today = today)
            .copy(name = "期末", hasSelectedDate = true)

        val result = AddExamFormReducer.validate(state)

        assertEquals(AddExamBlocker.COURSE_REQUIRED, result.blocker)
        assertEquals("请选择关联课程", result.state.toastMessage)
        assertNull(result.state.nameError)
    }

    @Test
    fun `未选日期被挡住`() {
        val state = AddExamFormReducer.initial(existing = null, today = today)
            .copy(name = "期末", selectedCourseId = "c1", hasSelectedDate = false)

        val result = AddExamFormReducer.validate(state)

        assertEquals(AddExamBlocker.DATE_REQUIRED, result.blocker)
        assertEquals("请选择考试日期", result.state.toastMessage)
    }

    @Test
    fun `结束时间等于或早于开始时间被挡住`() {
        val base = AddExamFormReducer.initial(existing = null, today = today)
            .copy(name = "期末", selectedCourseId = "c1", hasSelectedDate = true)

        // 倒挂
        assertEquals(
            AddExamBlocker.END_BEFORE_START,
            AddExamFormReducer.validate(base.copy(startTime = "10:00", endTime = "09:00")).blocker,
        )
        // 相等也算非法（Dart `:1028` 是 `endMinutes <= startMinutes`）
        assertEquals(
            AddExamBlocker.END_BEFORE_START,
            AddExamFormReducer.validate(base.copy(startTime = "10:00", endTime = "10:00")).blocker,
        )
        assertEquals(
            "结束时间不能早于开始时间",
            AddExamFormReducer.validate(base.copy(startTime = "10:00", endTime = "09:00")).state.toastMessage,
        )
        // 合法区间不该有任何 toast
        assertNull(AddExamFormReducer.validate(base).state.toastMessage)
    }

    @Test
    fun `选自定义提醒但一条都没加被挡住`() {
        val state = AddExamFormReducer.initial(existing = null, today = today)
            .copy(
                name = "期末",
                selectedCourseId = "c1",
                hasSelectedDate = true,
                reminderPreset = ExamReminderPreset.CUSTOM,
                customReminderMinutes = emptyList(),
            )

        val result = AddExamFormReducer.validate(state)

        assertEquals(AddExamBlocker.CUSTOM_REMINDER_EMPTY, result.blocker)
        assertEquals("请至少选择一个提醒时间", result.state.toastMessage)
    }

    @Test
    fun `全部通过时两个错误槽都清空`() {
        val dirty = AddExamFormReducer.initial(existing = null, today = today)
            .copy(name = "期末", selectedCourseId = "c1", hasSelectedDate = true)
            .copy(nameError = "上一轮的红", toastMessage = "上一轮的 toast")

        val result = AddExamFormReducer.validate(dirty)

        assertNull(result.blocker)
        assertNull(result.state.nameError)
        assertNull(result.state.toastMessage)
    }

    // ------------------------------------------------------------------
    // 字段更新
    // ------------------------------------------------------------------

    @Test
    fun `选课只在名称空着时回填默认考试名`() {
        // Dart `:299-303`：`if (_nameController.text.isEmpty) _nameController.text = examDefaultName;`
        val blank = AddExamFormReducer.initial(existing = null, today = today)
        assertEquals("期末考试", AddExamFormReducer.withCourse(blank, course("c1", "高数")).name)
        assertEquals("c1", AddExamFormReducer.withCourse(blank, course("c1", "高数")).selectedCourseId)

        val named = blank.copy(name = "补考")
        assertEquals("补考", AddExamFormReducer.withCourse(named, course("c1", "高数")).name)

        // 取消关联（`null`）不清名称
        assertEquals("考试", AddExamFormReducer.withCourse(blank.copy(name = "考试"), null).name)
        assertNull(AddExamFormReducer.withCourse(blank.copy(name = "考试"), null).selectedCourseId)
    }

    @Test
    fun `选日期只取年月日且能清空`() {
        val state = AddExamFormReducer.initial(existing = null, today = today)
        val picked = AddExamFormReducer.withDate(state, LocalDateTime.of(2030, 6, 3, 18, 45))

        assertTrue(picked.hasSelectedDate)
        // Dart 存 `DateTime(y, m, d)` ⇒ 时分归零
        assertEquals(LocalDateTime.of(2030, 6, 3, 0, 0), picked.selectedDate)

        val cleared = AddExamFormReducer.withDate(picked, null)
        assertFalse(cleared.hasSelectedDate)
        assertNull(cleared.selectedDate)
    }

    @Test
    fun `非法时间串不落进状态`() {
        val state = AddExamFormReducer.initial(existing = null, today = today)

        // `AddExamLogic.normalizeTimeOrFallback`：越界 / 畸形 → 08:00
        assertEquals("08:00", AddExamFormReducer.withStartTime(state, "25:00").startTime)
        assertEquals("08:00", AddExamFormReducer.withEndTime(state, "不确定").endTime)
        // 合法但没补零 → 归一
        assertEquals("09:05", AddExamFormReducer.withStartTime(state, "9:5").startTime)
    }

    // ------------------------------------------------------------------
    // 自定义提醒（Dart `:555-596`）
    // ------------------------------------------------------------------

    @Test
    fun `新增自定义提醒按降序落列表`() {
        val state = AddExamFormReducer.initial(existing = null, today = today)
            .copy(reminderPreset = ExamReminderPreset.CUSTOM)

        val afterFirst = AddExamFormReducer.withCustomReminderAdded(
            state = state,
            totalMinutes = 30,
            replacingMinutes = null,
        )
        assertEquals(listOf(30), afterFirst.customReminderMinutes)
        assertNull(afterFirst.toastMessage)

        val afterSecond = AddExamFormReducer.withCustomReminderAdded(
            state = afterFirst,
            totalMinutes = 1440,
            replacingMinutes = null,
        )
        // 降序：1 天在 30 分钟前
        assertEquals(listOf(1440, 30), afterSecond.customReminderMinutes)
    }

    @Test
    fun `重复的提醒时间弹实话且列表不变`() {
        val state = AddExamFormReducer.initial(existing = null, today = today)
            .copy(customReminderMinutes = listOf(60))

        val result = AddExamFormReducer.withCustomReminderAdded(
            state = state,
            totalMinutes = 60,
            replacingMinutes = null,
        )

        assertEquals(listOf(60), result.customReminderMinutes)
        assertEquals("该提醒时间已添加", result.toastMessage)
    }

    @Test
    fun `提醒时间小于等于零弹实话`() {
        val state = AddExamFormReducer.initial(existing = null, today = today)

        val result = AddExamFormReducer.withCustomReminderAdded(
            state = state,
            totalMinutes = 0,
            replacingMinutes = null,
        )

        assertTrue(result.customReminderMinutes.isEmpty())
        assertEquals("请设置大于 0 的提醒时间", result.toastMessage)
    }

    @Test
    fun `改成同一个值静默返回不弹任何提示`() {
        // Dart `:568-572`：`isUnchanged` 时直接 `return;`，一个字都不上屏。
        val state = AddExamFormReducer.initial(existing = null, today = today)
            .copy(customReminderMinutes = listOf(60), toastMessage = "上一轮的 toast")

        val result = AddExamFormReducer.withCustomReminderAdded(
            state = state,
            totalMinutes = 60,
            replacingMinutes = 60,
        )

        assertEquals(listOf(60), result.customReminderMinutes)
        assertNull(result.toastMessage)
    }

    @Test
    fun `编辑一条提醒时替换而非追加`() {
        val state = AddExamFormReducer.initial(existing = null, today = today)
            .copy(customReminderMinutes = listOf(120, 30))

        val result = AddExamFormReducer.withCustomReminderAdded(
            state = state,
            totalMinutes = 90,
            replacingMinutes = 120,
        )

        // 120 被替换成 90，30 原样留着，仍降序
        assertEquals(listOf(90, 30), result.customReminderMinutes)
    }

    @Test
    fun `删除一条提醒`() {
        val state = AddExamFormReducer.initial(existing = null, today = today)
            .copy(customReminderMinutes = listOf(120, 30))

        assertEquals(listOf(30), AddExamFormReducer.withCustomReminderRemoved(state, 120).customReminderMinutes)
        assertEquals(listOf(120, 30), AddExamFormReducer.withCustomReminderRemoved(state, 45).customReminderMinutes)
    }

    // ------------------------------------------------------------------
    // 组装实体（Dart `:1043-1073`）
    // ------------------------------------------------------------------

    @Test
    fun `新建保存用注入 id 且空字段转 null`() {
        val state = AddExamFormReducer.initial(existing = null, today = today).copy(
            name = "  期末考试  ",
            selectedCourseId = "c1",
            hasSelectedDate = true,
            selectedDate = LocalDateTime.of(2030, 6, 3, 0, 0),
            startTime = "9:5",
            endTime = "11:05",
            location = "   ",
            seatNumber = "",
            note = "带笔",
        )

        val exam = AddExamFormReducer.buildExam(
            state = state,
            existing = null,
            now = today,
            newId = "new-id",
        )

        assertEquals("new-id", exam.id)
        // 名称 trim（Dart `_nameController.text.trim()`）
        assertEquals("期末考试", exam.name)
        assertEquals("c1", exam.courseId)
        assertEquals(LocalDateTime.of(2030, 6, 3, 0, 0), exam.dateTime)
        // 时间归一（Dart `_formatTimeOfDay`）
        assertEquals("09:05", exam.startTime)
        assertEquals("11:05", exam.endTime)
        // 三个空串字段转 null（Dart 三个 `trim().isEmpty ? null`）
        assertNull(exam.location)
        assertNull(exam.seatNumber)
        assertEquals("带笔", exam.note)
        assertEquals(today, exam.createdAt)
        assertEquals(today, exam.updatedAt)
    }

    @Test
    fun `编辑保存保留原 id 与创建时间`() {
        val existing = existingExam()
        val state = AddExamFormReducer.initialFromExam(existing).copy(name = "期中考试（改）", startTime = "08:00")

        val exam = AddExamFormReducer.buildExam(
            state = state,
            existing = existing,
            now = today,
            newId = "should-be-ignored",
        )

        assertEquals("exam-1", exam.id)
        assertEquals(existing.createdAt, exam.createdAt)
        assertEquals(today, exam.updatedAt)
        assertEquals("期中考试（改）", exam.name)
        assertEquals("08:00", exam.startTime)
        // 自定义提醒原样带过去（本批只保证「存得住、回显得出来」）
        assertEquals(listOf(120, 30), exam.customReminderMinutes)
        assertEquals(ExamReminderPreset.CUSTOM, exam.reminderPreset)
    }

    // ------------------------------------------------------------------
    // 展示派生
    // ------------------------------------------------------------------

    @Test
    fun `日期行文案未选时说请选择日期`() {
        val state = AddExamFormReducer.initial(existing = null, today = today)

        assertEquals(
            "请选择日期",
            AddExamFormReducer.dateDisplay(state, semesterStart = null, semesterWeekCount = 16),
        )
    }

    @Test
    fun `日期行文案带年月日`() {
        val state = AddExamFormReducer.withDate(
            AddExamFormReducer.initial(existing = null, today = today),
            LocalDateTime.of(2030, 6, 3, 0, 0),
        )

        assertEquals(
            "2030-06-03",
            AddExamFormReducer.dateDisplay(state, semesterStart = null, semesterWeekCount = 16),
        )
    }

    @Test
    fun `选中课程能按 id 找回`() {
        val courses = listOf(course("c1", "高数"), course("c2", "英语"))
        val state = AddExamFormReducer.withCourse(
            AddExamFormReducer.initial(existing = null, today = today),
            courses[1],
        )

        assertEquals("英语", AddExamFormReducer.selectedCourse(state, courses)?.name)
        assertNull(AddExamFormReducer.selectedCourse(state.copy(selectedCourseId = "nope"), courses))
        assertFalse(AddExamFormReducer.courseGroupsEmpty(courses))
        assertTrue(AddExamFormReducer.courseGroupsEmpty(emptyList()))
    }

    @Test
    fun `选课候选项按名称分组去重且升序`() {
        val courses = listOf(
            course("c1", "英语", teacher = "李老师"),
            course("c2", "高数", teacher = "张老师"),
            // 同一门课的第二个时段：只能出现一次，且取组内第一条的 id
            course("c3", "高数", teacher = "王老师"),
        )

        val options = AddExamFormReducer.coursePickerOptions(courses, selectedCourseId = "c3")

        // 名称升序 = **字符码位**序（Dart `List.sort()` 对中文同样是 UTF-16 码位序，不是拼音序）：
        // 「英」U+82F1 < 「高」U+9AD8 ⇒ 英语在前。
        assertEquals(listOf("英语", "高数"), options.map { it.title })
        assertEquals("c2", options[1].courseId)
        assertEquals("张老师", options[1].details)
        // 选中的是「高数」这一组（哪怕 id 是组内第二条）
        assertTrue(options[1].selected)
        assertFalse(options[0].selected)
    }

    @Test
    fun `自定义提醒选择器初值默认 60 分钟并可往返`() {
        assertEquals(ReminderPickerParts(days = 0, hours = 1, minutes = 0), AddExamFormReducer.reminderPickerInitial(null))
        assertEquals(
            ReminderPickerParts(days = 1, hours = 1, minutes = 5),
            AddExamFormReducer.reminderPickerInitial(1505),
        )
        assertEquals(1505, AddExamFormReducer.reminderTotal(ReminderPickerParts(days = 1, hours = 1, minutes = 5)))
        assertEquals(0, AddExamFormReducer.reminderTotal(ReminderPickerParts(days = 0, hours = 0, minutes = 0)))
    }
}
