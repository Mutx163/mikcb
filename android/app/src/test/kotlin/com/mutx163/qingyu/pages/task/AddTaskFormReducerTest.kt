package com.mutx163.qingyu.pages.task

import com.mutx163.qingyu.app.AddTaskFormReducer
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 作业表单状态机单测（T1 收尾：从课程操作弹层「作业」进来要预选那门课，且表单真的能存）。
 *
 * **这个测试跟被测对象同包**：`AddTaskFormReducer` 已搬到 `pages/task/`，测试原先留在
 * `app/` 是搬家漏（同一批还有 `TaskModel` / `TaskStrings`）。留错位置的实际代价：`pages/task`
 * 的 L0（`-Module pages/task`）收不到它，等于这条测试长期不在最常跑的那条通道上。
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
        // 2026-10-29 复刻审核改的：这一行原先是 `assertEquals("", state.title)`，与 Dart 不符。
        // 真值 `add_task_screen.dart:142-148`：从课程进入时标题预填「那门课那一周的节次备注」，
        // 没有备注则退成 `taskHomeworkDefaultTitle`（课程作业）。本 case 的课程没有备注 ⇒ 兜底值。
        // 三条规则的完整契约见 `pages/task/AddTaskInitialTitleTest.kt`。
        assertEquals(TaskStrings.taskHomeworkDefaultTitle, state.title)
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
    fun `关掉到期日开关会清空日期`() {
        // 更正过的判据：Dart `add_task_screen.dart:246-253` 的 `if (!value) _dueDate = null;`
        // ——关掉开关就是**清空**，不是「留着日期不用」（本文件初版写错过一次）。
        val state = AddTaskFormReducer.initial(today = today)
        val off = AddTaskFormReducer.withHasDueDate(state, false)

        assertFalse(off.hasDueDate)
        assertNull("关掉就是清空", off.dueDate)
        assertNull(
            "不勾就不写",
            AddTaskFormReducer.buildTask(
                AddTaskFormReducer.withTitle(off, "作业"),
                now = today,
            ).dueDate,
        )
    }

    @Test
    fun `重新打开到期日开关时没有日期就用今天`() {
        val cleared = AddTaskFormReducer.withHasDueDate(
            AddTaskFormReducer.initial(today = today),
            false,
        )
        val on = AddTaskFormReducer.withHasDueDate(cleared, true, today = today)

        assertTrue(on.hasDueDate)
        assertEquals(CourseTask.dateOnly(today), on.dueDate)
    }

    // ================================================================
    // 3. task-18：选课程 / 选日期两个子弹层的判据
    // ================================================================

    @Test
    fun `选课程弹层按课名分组升序 首项是无关联课程`() {
        val courses = listOf(
            course("c2", "高等数学"),
            course("c1", "大学物理"),
            course("c3", "高等数学"), // 同名不同时段 ⇒ 同一个分组
        )

        val options = AddTaskFormReducer.coursePickerOptions(courses, selectedCourseId = null)

        assertEquals(
            "首项哨兵 + 其余按名字升序",
            listOf(AddTaskFormReducer.NO_COURSE_OPTION_ID, "大学物理", "高等数学"),
            options.map { it.label }.map { label ->
                if (label == TaskStrings.taskNoCourse) AddTaskFormReducer.NO_COURSE_OPTION_ID else label
            },
        )
        assertEquals(TaskStrings.taskNoCourse, options.first().label)
        assertTrue("未关联课程时首项应选中", options.first().isSelected)
        assertEquals("同名课只出现一次", 3, options.size)
        assertEquals("分组 id 取该组第一条课程", "c2", options[2].id)
    }

    @Test
    fun `选课程弹层的选中态跟着当前绑定课程的名字`() {
        val courses = listOf(
            course("c2", "高等数学"),
            course("c3", "高等数学"),
            course("c1", "大学物理"),
        )

        val options = AddTaskFormReducer.coursePickerOptions(courses, selectedCourseId = "c3")

        val selected = options.filter { it.isSelected }
        assertEquals("只有一组被选中", 1, selected.size)
        assertEquals("高等数学", selected.single().label)
        assertEquals("组内第二条也算选中", "c2", selected.single().id)
    }

    @Test
    fun `选无关联课程会清掉课程与周次`() {
        val state = AddTaskFormReducer.initial(
            preselectedCourse = course("c1", "大学物理"),
            sourceWeek = 3,
            today = today,
        )

        val cleared = AddTaskFormReducer.applyPickedCourseOption(
            state,
            listOf(course("c1", "大学物理")),
            AddTaskFormReducer.NO_COURSE_OPTION_ID,
        )

        assertNull(cleared.courseId)
        assertNull(cleared.sourceWeek)
        assertEquals(TaskStrings.taskNoCourse, cleared.selectedCourseName)
    }

    @Test
    fun `重选当前已绑定分组时保留原来的具体课时绑定`() {
        // Dart `:336-339`：同名分组再点一次**什么都不改**，否则用户每次点开弹层再点一次
        // 就会被悄悄绑到该组「第一节课」上。
        val bound = course("c3", "高等数学")
        val state = AddTaskFormReducer.initial(
            preselectedCourse = bound,
            sourceWeek = 5,
            today = today,
        )
        val courses = listOf(course("c2", "高等数学"), bound)

        val after = AddTaskFormReducer.applyPickedCourseOption(state, courses, "c2")

        assertEquals("绑定的具体课时不许被换掉", "c3", after.courseId)
        assertEquals(5L, after.sourceWeek)
    }

    @Test
    fun `选另一门课时绑定到该组第一条`() {
        val state = AddTaskFormReducer.initial(
            preselectedCourse = course("c1", "大学物理"),
            sourceWeek = 3,
            today = today,
        )
        val courses = listOf(
            course("c1", "大学物理"),
            course("c2", "高等数学"),
            course("c3", "高等数学"),
        )

        val after = AddTaskFormReducer.applyPickedCourseOption(state, courses, "c2")

        assertEquals("c2", after.courseId)
        assertEquals("高等数学", after.selectedCourseName)
        assertEquals("换课不动周次（Dart 只改 _courseId）", 3L, after.sourceWeek)
    }

    @Test
    fun `取消选课程不改状态`() {
        val state = AddTaskFormReducer.initial(
            preselectedCourse = course("c1", "大学物理"),
            sourceWeek = 3,
            today = today,
        )

        assertSame(state, AddTaskFormReducer.applyPickedCourseOption(state, emptyList(), null))
    }

    @Test
    fun `选日期会写回 date-only 并打开开关`() {
        val cleared = AddTaskFormReducer.withHasDueDate(
            AddTaskFormReducer.initial(today = today),
            false,
        )
        val picked = LocalDateTime.of(2026, 12, 5, 21, 45)

        val after = AddTaskFormReducer.withDueDate(cleared, picked)

        assertTrue("Dart :363 顺带把开关打开", after.hasDueDate)
        assertEquals(LocalDateTime.of(2026, 12, 5, 0, 0), after.dueDate)
        assertEquals("2026年12月5日", after.dueDateFormatted)
    }

    @Test
    fun `选日期传 null 等价于清空`() {
        val state = AddTaskFormReducer.initial(today = today)

        val after = AddTaskFormReducer.withDueDate(state, null)

        assertFalse(after.hasDueDate)
        assertNull(after.dueDate)
    }

    @Test
    fun `子弹层用的两个通用按钮文案与 ARB 逐字一致`() {
        // 这两个键写在渲染层文件里（task-18 写作用域不含 TaskStrings.kt），
        // 所以在这里钉住它们与 ARB 的值一致。
        val arb = loadArbZh()
        assertEquals("取消", arb["cancelAction"])
        assertEquals("确认", arb["confirmAction"])
    }

    private fun loadArbZh(): Map<String, String> {
        var dir: java.io.File? = java.io.File("").absoluteFile
        var file: java.io.File? = null
        repeat(8) {
            val candidate = java.io.File(dir, "i18n/app_zh.arb")
            if (candidate.isFile) {
                file = candidate
                return@repeat
            }
            dir = dir?.parentFile
        }
        val arbFile = file ?: error("找不到 i18n/app_zh.arb")
        val parsed = com.mutx163.qingyu.core.MiniJson.parse(arbFile.readText(Charsets.UTF_8))
        val map = LinkedHashMap<String, String>()
        (parsed as Map<*, *>).forEach { (k, v) -> if (k is String && v is String) map[k] = v }
        return map
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
