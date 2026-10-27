package com.mutx163.qingyu.pages.exam

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.ExamReminderPreset
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 添加 / 编辑考试页（`lib/screens/add_exam_screen.dart`，1290 行）模型层测试。
 *
 * 期望值从 Dart 源手推：默认值（:61-65）、时间解析回落（:1108-1126）、
 * 保存校验顺序（:1000-1041）、自定义提醒去重与排序（:557-594）、
 * 日期显示串（:328-367）、周次选日的日期换算（:715-728）。
 */
class AddExamModelTest {

    private val now = LocalDateTime.of(2026, 10, 27, 10, 30) // 周二

    private fun course(
        id: String = "c1",
        name: String = "高等数学",
        teacher: String = "张老师",
        location: String = "教学楼 301",
    ): Course = Course(
        id = id,
        name = name,
        teacher = teacher,
        location = location,
        dayOfWeek = 2,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
    )

    private fun existingExam(): Exam = Exam(
        id = "exam-1",
        courseId = "c1",
        name = "期中考试",
        dateTime = LocalDateTime.of(2026, 11, 3, 0, 0),
        startTime = "09:30",
        endTime = "11:30",
        location = "实验楼 201",
        seatNumber = "A12",
        note = "带计算器",
        reminderPreset = ExamReminderPreset.CUSTOM,
        customReminderMinutes = listOf(60, 30),
        createdAt = LocalDateTime.of(2026, 10, 1, 8, 0),
        updatedAt = LocalDateTime.of(2026, 10, 1, 8, 0),
    )

    private fun newState(): AddExamViewState = AddExamLogic.initialState(existing = null, now = now)

    private fun editState(): AddExamViewState = AddExamLogic.initialState(existing = existingExam(), now = now)

    /** 一份「除指定项外都合法」的表单。 */
    private fun validState(): AddExamViewState = newState().copy(
        selectedCourseId = "c1",
        name = "期末考试",
        hasSelectedDate = true,
        selectedDate = LocalDateTime.of(2026, 11, 3, 0, 0),
    )

    // ==========================================================
    // 1. 初始值（add_exam_screen.dart:45-66）
    // ==========================================================

    @Test
    fun `新建默认日期是七天后 时间是八点半到十点半`() {
        val state = newState()
        // now + 7 天 = 2026-11-03，且日期不带时分
        assertEquals(LocalDateTime.of(2026, 11, 3, 0, 0), state.selectedDate)
        assertEquals("08:30", state.startTime)
        assertEquals("10:30", state.endTime)
        // 新建时还没「选过日期」，保存会拦
        assertEquals(false, state.hasSelectedDate)
        assertEquals(ExamReminderPreset.DAY_1_AND_HOUR_1, state.reminderPreset)
        assertTrue(state.customReminderMinutes.isEmpty())
        assertEquals("", state.name)
        assertEquals(false, state.isEditing)
    }

    @Test
    fun `编辑态把考试字段全部读回表单`() {
        val state = editState()
        assertTrue(state.isEditing)
        assertEquals("c1", state.selectedCourseId)
        assertEquals("期中考试", state.name)
        assertEquals(LocalDateTime.of(2026, 11, 3, 0, 0), state.selectedDate)
        assertTrue(state.hasSelectedDate)
        assertEquals("09:30", state.startTime)
        assertEquals("11:30", state.endTime)
        assertEquals("实验楼 201", state.location)
        assertEquals("A12", state.seatNumber)
        assertEquals("带计算器", state.note)
        assertEquals(ExamReminderPreset.CUSTOM, state.reminderPreset)
        assertEquals(listOf(60, 30), state.customReminderMinutes)
    }

    @Test
    fun `起始时间按 08 点回落`() {
        // 越界小时：TimeOfDay 断言会炸，Dart 侧专门判了范围（:1116-1123）
        assertEquals("08:00", AddExamLogic.normalizeTimeOrFallback("25:00"))
        assertEquals("08:00", AddExamLogic.normalizeTimeOrFallback("08:60"))
        assertEquals("08:00", AddExamLogic.normalizeTimeOrFallback("abc"))
        assertEquals("08:00", AddExamLogic.normalizeTimeOrFallback(""))
        assertEquals("08:00", AddExamLogic.normalizeTimeOrFallback("08"))
        // 合法值按两位补零
        assertEquals("07:05", AddExamLogic.normalizeTimeOrFallback("7:5"))
        assertEquals("23:59", AddExamLogic.normalizeTimeOrFallback("23:59"))
    }

    // ==========================================================
    // 2. 保存阻断（add_exam_screen.dart:1000-1041）
    // ==========================================================

    @Test
    fun `合法的表单没有阻断项`() {
        assertNull(AddExamLogic.resolveSaveBlocker(validState()))
    }

    @Test
    fun `名称为空先拦`() {
        val state = validState().copy(name = "   ")
        assertEquals(AddExamBlocker.NAME_REQUIRED, AddExamLogic.resolveSaveBlocker(state))
        assertEquals("请输入考试名称", AddExamLogic.blockerMessage(AddExamBlocker.NAME_REQUIRED))
    }

    @Test
    fun `没选课程排第二`() {
        val state = validState().copy(selectedCourseId = null)
        assertEquals(AddExamBlocker.COURSE_REQUIRED, AddExamLogic.resolveSaveBlocker(state))
        assertEquals("请选择关联课程", AddExamLogic.blockerMessage(AddExamBlocker.COURSE_REQUIRED))
        // 空白 id 也算没选
        assertEquals(
            AddExamBlocker.COURSE_REQUIRED,
            AddExamLogic.resolveSaveBlocker(validState().copy(selectedCourseId = "   ")),
        )
    }

    @Test
    fun `没选日期排第三`() {
        val state = validState().copy(hasSelectedDate = false, selectedDate = null)
        assertEquals(AddExamBlocker.DATE_REQUIRED, AddExamLogic.resolveSaveBlocker(state))
        assertEquals("请选择考试日期", AddExamLogic.blockerMessage(AddExamBlocker.DATE_REQUIRED))
    }

    @Test
    fun `结束不晚于开始排第四`() {
        val same = validState().copy(startTime = "10:30", endTime = "10:30")
        assertEquals(AddExamBlocker.END_BEFORE_START, AddExamLogic.resolveSaveBlocker(same))
        val earlier = validState().copy(startTime = "10:30", endTime = "09:00")
        assertEquals(AddExamBlocker.END_BEFORE_START, AddExamLogic.resolveSaveBlocker(earlier))
        assertEquals(
            "结束时间不能早于开始时间",
            AddExamLogic.blockerMessage(AddExamBlocker.END_BEFORE_START),
        )
    }

    @Test
    fun `自定义提醒为空排最后`() {
        val state = validState().copy(
            reminderPreset = ExamReminderPreset.CUSTOM,
            customReminderMinutes = emptyList(),
        )
        assertEquals(AddExamBlocker.CUSTOM_REMINDER_EMPTY, AddExamLogic.resolveSaveBlocker(state))
        assertEquals(
            "请至少选择一个提醒时间",
            AddExamLogic.blockerMessage(AddExamBlocker.CUSTOM_REMINDER_EMPTY),
        )
        // 非自定义预设不查这一条
        val preset = state.copy(reminderPreset = ExamReminderPreset.HOUR_1)
        assertNull(AddExamLogic.resolveSaveBlocker(preset))
    }

    @Test
    fun `阻断按顺序只报第一条`() {
        // 名称、课程、日期、时间全错：只报名称
        val state = AddExamViewState(
            isEditing = false,
            selectedCourseId = null,
            name = "",
            hasSelectedDate = false,
            selectedDate = null,
            startTime = "10:30",
            endTime = "09:00",
            location = "",
            seatNumber = "",
            note = "",
            reminderPreset = ExamReminderPreset.CUSTOM,
            customReminderMinutes = emptyList(),
        )
        assertEquals(AddExamBlocker.NAME_REQUIRED, AddExamLogic.resolveSaveBlocker(state))
    }

    // ==========================================================
    // 3. 组装实体（add_exam_screen.dart:1043-1071）
    // ==========================================================

    @Test
    fun `新建时生成新 id 空白字段存 null`() {
        val state = validState().copy(
            name = "  期末考试  ",
            location = "   ",
            seatNumber = " A1 ",
            note = "  ",
        )
        val exam = AddExamLogic.buildExam(state, existing = null, newId = "new-id", now = now)

        assertEquals("new-id", exam.id)
        assertEquals("期末考试", exam.name)
        assertEquals("c1", exam.courseId)
        assertEquals(LocalDateTime.of(2026, 11, 3, 0, 0), exam.dateTime)
        assertEquals("08:30", exam.startTime)
        assertEquals("10:30", exam.endTime)
        assertNull(exam.location)
        assertEquals("A1", exam.seatNumber)
        assertNull(exam.note)
        assertEquals(now, exam.createdAt)
        assertEquals(now, exam.updatedAt)
    }

    @Test
    fun `编辑时保留 id 与创建时间 只动更新时间`() {
        val state = editState().copy(name = "期末补考")
        val exam = AddExamLogic.buildExam(state, existing = existingExam(), newId = "ignored", now = now)

        assertEquals("exam-1", exam.id)
        assertEquals(LocalDateTime.of(2026, 10, 1, 8, 0), exam.createdAt)
        assertEquals(now, exam.updatedAt)
        assertEquals("期末补考", exam.name)
    }

    @Test
    fun `自定义提醒列表原样带进实体`() {
        val state = validState().copy(
            reminderPreset = ExamReminderPreset.CUSTOM,
            customReminderMinutes = listOf(120, 30),
        )
        val exam = AddExamLogic.buildExam(state, existing = null, newId = "x", now = now)
        assertEquals(ExamReminderPreset.CUSTOM, exam.reminderPreset)
        assertEquals(listOf(120, 30), exam.customReminderMinutes)
        assertEquals(listOf(120, 30), exam.effectiveReminderMinutes)
    }

    // ==========================================================
    // 4. 自定义提醒增删（add_exam_screen.dart:519-594）
    // ==========================================================

    @Test
    fun `新增自定义提醒按倒序插入`() {
        val result = AddExamLogic.applyCustomReminderOffset(
            current = listOf(30, 180),
            totalMinutes = 90,
            replacingMinutes = null,
        )
        assertEquals(CustomReminderStatus.ADDED, result.status)
        assertEquals(listOf(180, 90, 30), result.minutes)
    }

    @Test
    fun `修改已有提醒时替换而不是追加`() {
        val result = AddExamLogic.applyCustomReminderOffset(
            current = listOf(180, 30),
            totalMinutes = 60,
            replacingMinutes = 180,
        )
        assertEquals(CustomReminderStatus.ADDED, result.status)
        assertEquals(listOf(60, 30), result.minutes)
    }

    @Test
    fun `改成同一个值算没变`() {
        val result = AddExamLogic.applyCustomReminderOffset(
            current = listOf(60, 30),
            totalMinutes = 60,
            replacingMinutes = 60,
        )
        assertEquals(CustomReminderStatus.UNCHANGED, result.status)
        assertEquals(listOf(60, 30), result.minutes)
    }

    @Test
    fun `和别的条目撞车算重复`() {
        val result = AddExamLogic.applyCustomReminderOffset(
            current = listOf(60, 30),
            totalMinutes = 30,
            replacingMinutes = null,
        )
        assertEquals(CustomReminderStatus.DUPLICATE, result.status)
        assertEquals(listOf(60, 30), result.minutes)
    }

    @Test
    fun `零或负数算非法`() {
        assertEquals(
            CustomReminderStatus.INVALID,
            AddExamLogic.applyCustomReminderOffset(emptyList(), 0, null).status,
        )
        assertEquals(
            CustomReminderStatus.INVALID,
            AddExamLogic.applyCustomReminderOffset(emptyList(), -30, null).status,
        )
    }

    @Test
    fun `展示用偏移列表是倒序`() {
        assertEquals(listOf(180, 60, 30), AddExamLogic.sortedOffsets(listOf(30, 180, 60)))
        assertEquals(emptyList<Int>(), AddExamLogic.sortedOffsets(emptyList()))
    }

    // ==========================================================
    // 5. 日期行显示（add_exam_screen.dart:328-367）
    // ==========================================================

    @Test
    fun `没选日期时显示请选择日期`() {
        val state = newState()
        assertEquals(
            "请选择日期",
            AddExamLogic.formatDateDisplay(state, semesterStart = null, semesterWeekCount = 16),
        )
    }

    @Test
    fun `选了日期但没有开学日只显示年月日`() {
        val state = validState()
        assertEquals(
            "2026-11-03",
            AddExamLogic.formatDateDisplay(state, semesterStart = null, semesterWeekCount = 16),
        )
    }

    @Test
    fun `有开学日时补周次与星期`() {
        val state = validState()
        // 开学 2026-09-01（周二）→ 11-03 所在周是第 10 周、周二
        assertEquals(
            "2026-11-03 第 10 周 周二",
            AddExamLogic.formatDateDisplay(
                state,
                semesterStart = LocalDateTime.of(2026, 9, 1, 0, 0),
                semesterWeekCount = 16,
            ),
        )
    }

    @Test
    fun `周次超出学期周数就不显示`() {
        val state = validState()
        assertEquals(
            "2026-11-03",
            AddExamLogic.formatDateDisplay(
                state,
                semesterStart = LocalDateTime.of(2026, 9, 1, 0, 0),
                semesterWeekCount = 9,
            ),
        )
    }

    @Test
    fun `日期早于开学日不显示周次`() {
        val state = validState().copy(selectedDate = LocalDateTime.of(2026, 8, 1, 0, 0))
        assertEquals(
            "2026-08-01",
            AddExamLogic.formatDateDisplay(
                state,
                semesterStart = LocalDateTime.of(2026, 9, 1, 0, 0),
                semesterWeekCount = 16,
            ),
        )
    }

    // ==========================================================
    // 6. 周次选日换算（add_exam_screen.dart:714-728）
    // ==========================================================

    @Test
    fun `第几周第几天换算成日期 以周一为周首`() {
        val semesterStart = LocalDateTime.of(2026, 9, 1, 0, 0) // 周二
        // 第 1 周周一 = 08-31
        assertEquals(
            LocalDateTime.of(2026, 8, 31, 0, 0),
            AddExamLogic.dateForWeekAndDay(semesterStart, week = 1, dayOfWeek = 1),
        )
        // 第 1 周周二 = 09-01（就是开学当天）
        assertEquals(
            LocalDateTime.of(2026, 9, 1, 0, 0),
            AddExamLogic.dateForWeekAndDay(semesterStart, week = 1, dayOfWeek = 2),
        )
        // 第 2 周周三 = 09-09
        assertEquals(
            LocalDateTime.of(2026, 9, 9, 0, 0),
            AddExamLogic.dateForWeekAndDay(semesterStart, week = 2, dayOfWeek = 3),
        )
        // 第 10 周周二 = 11-03
        assertEquals(
            LocalDateTime.of(2026, 11, 3, 0, 0),
            AddExamLogic.dateForWeekAndDay(semesterStart, week = 10, dayOfWeek = 2),
        )
    }

    @Test
    fun `选择器的初始周次取当前日期所在周 越界回落到第一周`() {
        val semesterStart = LocalDateTime.of(2026, 9, 1, 0, 0)
        assertEquals(
            10,
            AddExamLogic.initialWeekForPicker(
                anchor = LocalDateTime.of(2026, 11, 3, 0, 0),
                semesterStart = semesterStart,
                totalWeeks = 16,
            ),
        )
        // 超出学期周数 → 1
        assertEquals(
            1,
            AddExamLogic.initialWeekForPicker(
                anchor = LocalDateTime.of(2026, 11, 3, 0, 0),
                semesterStart = semesterStart,
                totalWeeks = 5,
            ),
        )
        // 早于开学 → 1
        assertEquals(
            1,
            AddExamLogic.initialWeekForPicker(
                anchor = LocalDateTime.of(2026, 8, 1, 0, 0),
                semesterStart = semesterStart,
                totalWeeks = 16,
            ),
        )
    }

    @Test
    fun `本周判定`() {
        val semesterStart = LocalDateTime.of(2026, 9, 1, 0, 0)
        assertTrue(AddExamLogic.isCurrentWeek(10, semesterStart, LocalDateTime.of(2026, 11, 3, 12, 0)))
        assertEquals(false, AddExamLogic.isCurrentWeek(9, semesterStart, LocalDateTime.of(2026, 11, 3, 12, 0)))
    }

    // ==========================================================
    // 7. 自定义提醒选择器的初值（add_exam_screen.dart:1207-1218）
    // ==========================================================

    @Test
    fun `选择器初值默认一小时`() {
        val parts = AddExamLogic.decomposeReminderTotal(null)
        assertEquals(0, parts.days)
        assertEquals(1, parts.hours)
        assertEquals(0, parts.minutes)
    }

    @Test
    fun `选择器初值按已有时长拆开`() {
        val parts = AddExamLogic.decomposeReminderTotal(1505) // 1 天 1 小时 5 分
        assertEquals(1, parts.days)
        assertEquals(1, parts.hours)
        assertEquals(5, parts.minutes)
    }

    @Test
    fun `选择器初值天数封顶三十`() {
        val parts = AddExamLogic.decomposeReminderTotal(100 * 1440)
        assertEquals(30, parts.days)
        // 100 天超上限，先被钳到 30d23h59m
        assertEquals(23, parts.hours)
        assertEquals(59, parts.minutes)
    }

    @Test
    fun `选择器总分钟数由三段相加`() {
        assertEquals(1505, AddExamLogic.reminderTotalMinutes(1, 1, 5))
        assertEquals(1440, AddExamLogic.reminderTotalMinutes(1, 0, 0))
        assertEquals(0, AddExamLogic.reminderTotalMinutes(0, 0, 0))
    }

    // ==========================================================
    // 8. 课程与考场文案（add_exam_screen.dart:219-278, 439-455）
    // ==========================================================

    @Test
    fun `没选课程且课表为空时说明没有课程`() {
        assertEquals(
            "当前课表已经没有课程",
            AddExamLogic.courseDetailsText(selectedCourse = null, courseGroupsEmpty = true),
        )
        assertEquals(
            "关联课程",
            AddExamLogic.courseDetailsText(selectedCourse = null, courseGroupsEmpty = false),
        )
    }

    @Test
    fun `选了课程显示课程名与教师`() {
        assertEquals(
            "高等数学 · 张老师",
            AddExamLogic.courseDetailsText(selectedCourse = course(), courseGroupsEmpty = false),
        )
    }

    @Test
    fun `考场提示优先显示上课教室`() {
        assertEquals(
            "同上课教室: 教学楼 301",
            AddExamLogic.locationHint(selectedCourse = course()),
        )
        assertEquals(
            "留空则使用上课教室",
            AddExamLogic.locationHint(selectedCourse = null),
        )
    }

    @Test
    fun `选中课程且名称还空时填入默认考试名`() {
        assertEquals("期末考试", AddExamLogic.nameAfterCoursePicked(currentName = ""))
        assertEquals("期末考试", AddExamLogic.nameAfterCoursePicked(currentName = "   "))
        // 用户已经写了名字就不覆盖
        assertEquals("补考", AddExamLogic.nameAfterCoursePicked(currentName = "补考"))
    }

    @Test
    fun `提醒预设下拉按枚举顺序列出七项`() {
        val options = AddExamLogic.reminderPresetOptions()
        assertEquals(7, options.size)
        assertEquals(ExamReminderPreset.NONE, options.first().first)
        assertEquals("不提醒", options.first().second)
        assertEquals(ExamReminderPreset.CUSTOM, options.last().first)
        assertEquals("自定义", options.last().second)
    }
}
