package com.mutx163.qingyu.pages.task

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.CourseTaskSource
import com.mutx163.qingyu.core.MiniJson
import java.io.File
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 任务模块模型层、过滤逻辑、表单规则与 ARB 文案对拍测试。
 */
class TaskModelTest {

    private val baseNow = LocalDateTime.of(2026, 10, 27, 10, 30) // 2026-10-27 是周二
    private val todayDateOnly = LocalDateTime.of(2026, 10, 27, 0, 0)
    private val yesterdayDateOnly = LocalDateTime.of(2026, 10, 26, 0, 0) // 周一
    private val tomorrowDateOnly = LocalDateTime.of(2026, 10, 28, 0, 0) // 周三
    private val sundayThisWeek = LocalDateTime.of(2026, 11, 1, 0, 0) // 周日
    private val nextMonday = LocalDateTime.of(2026, 11, 2, 0, 0) // 下周一
    private val lastSunday = LocalDateTime.of(2026, 10, 25, 0, 0) // 上周日

    private fun testTask(
        id: String,
        title: String = "任务$id",
        courseId: String? = null,
        sourceWeek: Long? = null,
        dueDate: LocalDateTime? = null,
        note: String? = null,
        isCompleted: Boolean = false,
        source: CourseTaskSource = CourseTaskSource.MANUAL,
        isUserEdited: Boolean = false,
    ): CourseTask = CourseTask(
        id = id,
        title = title,
        courseId = courseId,
        sourceWeek = sourceWeek,
        dueDate = dueDate,
        note = note,
        isCompleted = isCompleted,
        source = source,
        isUserEdited = isUserEdited,
        createdAt = baseNow,
        updatedAt = baseNow,
    )

    private fun testCourse(
        id: String,
        name: String,
        dayOfWeek: Int = 1,
        startSection: Int = 1,
        endSection: Int = 2,
    ): Course = Course(
        id = id,
        name = name,
        teacher = "李老师",
        location = "教学楼101",
        dayOfWeek = dayOfWeek,
        startSection = startSection,
        endSection = endSection,
        startTime = "08:00",
        endTime = "09:40",
        startWeek = 1,
        endWeek = 16,
    )

    // ==========================================
    // 1. ARB 逐字对拍测试
    // ==========================================

    private fun arbString(key: String): String {
        val candidates = listOf(
            File("../../lib/l10n/app_zh.arb"),
            File("../lib/l10n/app_zh.arb"),
            File("lib/l10n/app_zh.arb"),
        )
        val file = candidates.firstOrNull { it.isFile }
            ?: error("找不到 lib/l10n/app_zh.arb，当前工作目录=${File(".").absolutePath}")
        @Suppress("UNCHECKED_CAST")
        val json = MiniJson.parse(file.readText(Charsets.UTF_8)) as Map<String, Any?>
        return json[key] as? String ?: error("ARB 缺少键 $key")
    }

    @Test
    fun `常量文案与ARB逐字一致`() {
        val pairs = listOf(
            "taskListTitle" to TaskStrings.taskListTitle,
            "addTask" to TaskStrings.addTask,
            "editTask" to TaskStrings.editTask,
            "saveTask" to TaskStrings.saveTask,
            "taskTitleLabel" to TaskStrings.taskTitleLabel,
            "taskTitleHint" to TaskStrings.taskTitleHint,
            "taskTitleRequired" to TaskStrings.taskTitleRequired,
            "taskNoteLabel" to TaskStrings.taskNoteLabel,
            "taskNoteHint" to TaskStrings.taskNoteHint,
            "taskDueDateLabel" to TaskStrings.taskDueDateLabel,
            "taskNoDueDate" to TaskStrings.taskNoDueDate,
            "taskDueDateHint" to TaskStrings.taskDueDateHint,
            "taskUndatedHintSubtitle" to TaskStrings.taskUndatedHintSubtitle,
            "taskCourseLabel" to TaskStrings.taskCourseLabel,
            "taskCourseFilter" to TaskStrings.taskCourseFilter,
            "taskAllCourses" to TaskStrings.taskAllCourses,
            "taskNoCourse" to TaskStrings.taskNoCourse,
            "taskAllFilter" to TaskStrings.taskAllFilter,
            "taskTodayFilter" to TaskStrings.taskTodayFilter,
            "taskWeekFilter" to TaskStrings.taskWeekFilter,
            "taskOverdueSection" to TaskStrings.taskOverdueSection,
            "taskCompletedSection" to TaskStrings.taskCompletedSection,
            "taskNoTasks" to TaskStrings.taskNoTasks,
            "taskNoTasksForToday" to TaskStrings.taskNoTasksForToday,
            "taskNoTasksForWeek" to TaskStrings.taskNoTasksForWeek,
            "taskNoTasksForCourse" to TaskStrings.taskNoTasksForCourse,
            "taskDelete" to TaskStrings.taskDelete,
            "taskDeleteConfirm" to TaskStrings.taskDeleteConfirm,
            "taskHomeworkDefaultTitle" to TaskStrings.taskHomeworkDefaultTitle,
            "taskAddFromCourse" to TaskStrings.taskAddFromCourse,
            "taskViewCourse" to TaskStrings.taskViewCourse,
            "taskSaved" to TaskStrings.taskSaved,
            "taskUpdated" to TaskStrings.taskUpdated,
            "taskDeleted" to TaskStrings.taskDeleted,
            "saveFailed" to TaskStrings.saveFailed,
            "cancelAction" to TaskStrings.cancelAction,
            "deleteAction" to TaskStrings.deleteAction,
            "serviceMsgLinkedCourseNotFound" to TaskStrings.serviceMsgLinkedCourseNotFound,
        )

        for ((key, value) in pairs) {
            assertEquals("ARB 键 $key 与 TaskStrings 不一致", arbString(key), value)
        }
    }

    @Test
    fun `带参数文案与ARB格式完全对齐`() {
        assertEquals(
            arbString("taskUndatedHint").replace("{count}", "3"),
            TaskStrings.taskUndatedHint(3),
        )
        assertEquals(
            arbString("weekLabel").replace("{week}", "4"),
            TaskStrings.weekLabel(4),
        )
        assertEquals(
            arbString("dayTaskBandCountSummary").replace("{count}", "5"),
            TaskStrings.dayTaskBandCountSummary(5),
        )
        assertEquals(
            arbString("dayTaskBandOverdueBadge").replace("{days}", "2"),
            TaskStrings.dayTaskBandOverdueBadge(2),
        )
        assertEquals(
            arbString("dayTaskBandOverdueMore").replace("{count}", "6"),
            TaskStrings.dayTaskBandOverdueMore(6),
        )
    }

    // ==========================================
    // 2. 日期过滤与区间判定测试
    // ==========================================

    @Test
    fun `自然周范围计算正确`() {
        // 2026-10-27 (周二) -> 周一 10-26 00:00 至 周日 11-01 00:00
        val (start, end) = TaskFilterLogic.resolveWeekRange(baseNow)
        assertEquals(yesterdayDateOnly, start)
        assertEquals(sundayThisWeek, end)
    }

    @Test
    fun `isDueBetween 区间闭合性判定`() {
        val task = testTask("t1", dueDate = todayDateOnly)
        assertTrue(task.isDueBetween(yesterdayDateOnly, tomorrowDateOnly))
        assertTrue(task.isDueBetween(todayDateOnly, todayDateOnly))
        assertFalse(task.isDueBetween(tomorrowDateOnly, sundayThisWeek))

        val undated = testTask("t2", dueDate = null)
        assertFalse(undated.isDueBetween(yesterdayDateOnly, sundayThisWeek))
    }

    @Test
    fun `isRelevantToday 口径严格对齐 Dart 待办带`() {
        // 1. 今天到期未完成 -> true
        val tTodayActive = testTask("t1", dueDate = todayDateOnly, isCompleted = false)
        assertTrue(tTodayActive.isRelevantToday(todayDateOnly))

        // 2. 今天到期已完成 -> true（用户要能回看今天交了没）
        val tTodayDone = testTask("t2", dueDate = todayDateOnly, isCompleted = true)
        assertTrue(tTodayDone.isRelevantToday(todayDateOnly))

        // 3. 逾期未完成（昨天到期） -> true（欠着的待办不能在今日消失）
        val tOverdueActive = testTask("t3", dueDate = yesterdayDateOnly, isCompleted = false)
        assertTrue(tOverdueActive.isRelevantToday(todayDateOnly))

        // 4. 逾期已完成（昨天到期但已勾选） -> false（昨天已做完的不再占用今日行动项）
        val tOverdueDone = testTask("t4", dueDate = yesterdayDateOnly, isCompleted = true)
        assertFalse(tOverdueDone.isRelevantToday(todayDateOnly))

        // 5. 未来到期 -> false
        val tFuture = testTask("t5", dueDate = tomorrowDateOnly, isCompleted = false)
        assertFalse(tFuture.isRelevantToday(todayDateOnly))

        // 6. 无到期日 -> false
        val tUndated = testTask("t6", dueDate = null, isCompleted = false)
        assertFalse(tUndated.isRelevantToday(todayDateOnly))
    }

    @Test
    fun `filterTasks 日期三档筛选`() {
        val tasks = listOf(
            testTask("overdue_active", dueDate = yesterdayDateOnly, isCompleted = false),
            testTask("overdue_done", dueDate = yesterdayDateOnly, isCompleted = true),
            testTask("today_active", dueDate = todayDateOnly, isCompleted = false),
            testTask("today_done", dueDate = todayDateOnly, isCompleted = true),
            testTask("tomorrow_active", dueDate = tomorrowDateOnly, isCompleted = false),
            testTask("next_week", dueDate = nextMonday, isCompleted = false),
            testTask("undated", dueDate = null, isCompleted = false),
        )

        // 全部档：全部收录
        val allFiltered = TaskFilterLogic.filterTasks(tasks, TaskDateFilter.ALL, null, emptyList(), baseNow)
        assertEquals(7, allFiltered.size)

        // 今日档：收录 overdue_active, today_active, today_done
        val todayFiltered = TaskFilterLogic.filterTasks(tasks, TaskDateFilter.TODAY, null, emptyList(), baseNow)
        val todayIds = todayFiltered.map { it.id }.toSet()
        assertEquals(setOf("overdue_active", "today_active", "today_done"), todayIds)

        // 本周档：收录本周内的（10-26 周一 至 11-01 周日）
        val weekFiltered = TaskFilterLogic.filterTasks(tasks, TaskDateFilter.WEEK, null, emptyList(), baseNow)
        val weekIds = weekFiltered.map { it.id }.toSet()
        assertEquals(
            setOf("overdue_active", "overdue_done", "today_active", "today_done", "tomorrow_active"),
            weekIds,
        )
    }

    // ==========================================
    // 3. 课程筛选与分组测试
    // ==========================================

    @Test
    fun `filterTasks 课程筛选逻辑`() {
        val c1 = testCourse("c1", "高等数学")
        val c2 = testCourse("c2", "高等数学") // 同名课程另一时段
        val c3 = testCourse("c3", "大学英语")
        val courses = listOf(c1, c2, c3)

        val t1 = testTask("t1", courseId = "c1")
        val t2 = testTask("t2", courseId = "c2")
        val t3 = testTask("t3", courseId = "c3")
        val t4 = testTask("t4", courseId = null) // 无课程关联
        val allTasks = listOf(t1, t2, t3, t4)

        // 1. 无筛选 / __all__：包含全部
        val allResult = TaskFilterLogic.filterTasks(allTasks, TaskDateFilter.ALL, null, courses, baseNow)
        assertEquals(4, allResult.size)

        // 2. 筛选 __none__：只包含 t4
        val noneResult = TaskFilterLogic.filterTasks(allTasks, TaskDateFilter.ALL, TaskFilterLogic.NONE_COURSE_VALUE, courses, baseNow)
        assertEquals(listOf("t4"), noneResult.map { it.id })

        // 3. 筛选 "高等数学"：同名课程分组包含 c1 和 c2，返回 t1 与 t2
        val mathResult = TaskFilterLogic.filterTasks(allTasks, TaskDateFilter.ALL, "高等数学", courses, baseNow)
        assertEquals(setOf("t1", "t2"), mathResult.map { it.id }.toSet())
    }

    // ==========================================
    // 4. 排序规则验证
    // ==========================================

    @Test
    fun `compareByDueDate 严格按截止日升序、完成态垫后、标题与id`() {
        val tUndated = testTask("t0", title = "A", dueDate = null)
        val tEarlier = testTask("t1", title = "B", dueDate = yesterdayDateOnly)
        val tLater = testTask("t2", title = "C", dueDate = todayDateOnly)
        val tCompletedEarlier = testTask("t3", title = "B", dueDate = yesterdayDateOnly, isCompleted = true)

        val list = listOf(tUndated, tLater, tEarlier, tCompletedEarlier).sortedWith(CourseTask::compareByDueDate)

        // 顺序应当为：tEarlier (未完成，较早) -> tCompletedEarlier (已完成，较早) -> tLater -> tUndated (无日期垫底)
        assertEquals(listOf("t1", "t3", "t2", "t0"), list.map { it.id })
    }

    // ==========================================
    // 5. 分区分段与视图模型组装测试
    // ==========================================

    @Test
    fun `groupTasksIntoSections 正确划分逾期、待办与已完成三段`() {
        val c1 = testCourse("c1", "高数")
        val coursesById = mapOf("c1" to c1)

        val tOverdue = testTask("t1", title = "作业1", courseId = "c1", sourceWeek = 3, dueDate = yesterdayDateOnly)
        val tActive = testTask("t2", title = "作业2", dueDate = todayDateOnly)
        val tCompleted = testTask("t3", title = "", dueDate = todayDateOnly, isCompleted = true) // 空标题

        val sections = TaskFilterLogic.groupTasksIntoSections(
            listOf(tOverdue, tActive, tCompleted),
            coursesById,
            baseNow,
        )

        assertEquals(3, sections.size)
        assertEquals(TaskStrings.taskOverdueSection, sections[0].title)
        assertEquals(TaskStrings.taskListTitle, sections[1].title)
        assertEquals(TaskStrings.taskCompletedSection, sections[2].title)

        // 检查逾期项展示文本（包含课程、周次、日期）
        val item1 = sections[0].items[0]
        assertEquals("作业1", item1.title)
        assertEquals("高数 · 第 3 周 · 10月26日", item1.detailText)
        assertTrue(item1.isOverdue)
        assertFalse(item1.isCompleted)

        // 检查空标题兜底为 "课程作业"
        val item3 = sections[2].items[0]
        assertEquals(TaskStrings.taskHomeworkDefaultTitle, item3.title)
        assertTrue(item3.isCompleted)
    }

    // ==========================================
    // 6. 无截止日期被隐藏计数测试
    // ==========================================

    @Test
    fun `undatedHiddenCount 准确统计被今日与本周挡在外部的未完成任务`() {
        val tasks = listOf(
            testTask("u1", dueDate = null, isCompleted = false),
            testTask("u2", dueDate = null, isCompleted = true), // 已完成不计入隐藏提示
            testTask("d1", dueDate = todayDateOnly, isCompleted = false),
        )

        // ALL 档下永不显示提示
        assertEquals(0, TaskFilterLogic.undatedHiddenCount(tasks, TaskDateFilter.ALL, null, emptyList()))

        // TODAY 档下应当统计到 1 条 (u1)
        assertEquals(1, TaskFilterLogic.undatedHiddenCount(tasks, TaskDateFilter.TODAY, null, emptyList()))

        // WEEK 档下也是 1 条
        assertEquals(1, TaskFilterLogic.undatedHiddenCount(tasks, TaskDateFilter.WEEK, null, emptyList()))
    }

    // ==========================================
    // 7. 空态提示文案测试
    // ==========================================

    @Test
    fun `resolveEmptyTitle 在不同条件下的正确文案`() {
        // 全量为空
        assertEquals(TaskStrings.taskNoTasks, TaskFilterLogic.resolveEmptyTitle(true, null, TaskDateFilter.ALL))

        // 课程筛选下为空
        assertEquals(TaskStrings.taskNoTasksForCourse, TaskFilterLogic.resolveEmptyTitle(false, "高等数学", TaskDateFilter.ALL))

        // 日期筛选下为空
        assertEquals(TaskStrings.taskNoTasksForToday, TaskFilterLogic.resolveEmptyTitle(false, null, TaskDateFilter.TODAY))
        assertEquals(TaskStrings.taskNoTasksForWeek, TaskFilterLogic.resolveEmptyTitle(false, null, TaskDateFilter.WEEK))
    }

    // ==========================================
    // 8. 表单规则（焦距、默认到期日、构建、错误映射）测试
    // ==========================================

    @Test
    fun `shouldAutofocusTitle 仅在纯新建时为 true`() {
        // 纯新建 -> 抢焦点
        assertTrue(TaskFormDefaults.shouldAutofocusTitle(isEditing = false, hasInitialCourse = false, hasInitialWeek = false))

        // 从课程加任务 -> 不抢焦点（避免遮挡已预填字段）
        assertFalse(TaskFormDefaults.shouldAutofocusTitle(isEditing = false, hasInitialCourse = true, hasInitialWeek = true))

        // 编辑已有任务 -> 不抢焦点
        assertFalse(TaskFormDefaults.shouldAutofocusTitle(isEditing = true, hasInitialCourse = false, hasInitialWeek = false))
    }

    @Test
    fun `initialDueDate 新建默认为今日，课程进入用课时日期，编辑态保留原值`() {
        val courseDate = LocalDateTime.of(2026, 11, 5, 0, 0)

        // 1. 纯新建 -> 默认今天
        val newDue = TaskFormDefaults.initialDueDate(null, null, isEditing = false, today = baseNow)
        assertEquals(todayDateOnly, newDue)

        // 2. 从课程新建 -> 默认课时发生日期
        val courseDue = TaskFormDefaults.initialDueDate(null, courseDate, isEditing = false, today = baseNow)
        assertEquals(courseDate, courseDue)

        // 3. 编辑已有（原来为 null） -> 保留 null，不强行改为今天
        val editNull = TaskFormDefaults.initialDueDate(null, null, isEditing = true, today = baseNow)
        assertNull(editNull)
    }

    @Test
    fun `validateTitle 标题非空校验`() {
        assertEquals(TaskStrings.taskTitleRequired, TaskFormLogic.validateTitle(""))
        assertEquals(TaskStrings.taskTitleRequired, TaskFormLogic.validateTitle("   "))
        assertNull(TaskFormLogic.validateTitle("写作业"))
    }

    @Test
    fun `buildTask 正确组装实体并处理日期与用户修改标记`() {
        val rawDue = LocalDateTime.of(2026, 10, 27, 18, 45) // 带时分秒

        val task = TaskFormLogic.buildTask(
            existingTask = null,
            title = "  实验报告  ",
            note = "  附录图表  ",
            courseId = "c1",
            sourceWeek = 5,
            hasDueDate = true,
            dueDate = rawDue,
            isCompleted = true,
            now = baseNow,
        )

        assertEquals("实验报告", task.title)
        assertEquals("附录图表", task.note)
        assertEquals("c1", task.courseId)
        assertEquals(5L, task.sourceWeek)
        assertTrue(task.isCompleted)
        // 截止日期自动 dateOnly 归一化
        assertEquals(todayDateOnly, task.dueDate)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `buildTask 标题为空时抛出异常`() {
        TaskFormLogic.buildTask(
            existingTask = null,
            title = "   ",
            note = null,
            courseId = null,
            sourceWeek = null,
            hasDueDate = false,
            dueDate = null,
            isCompleted = false,
            now = baseNow,
        )
    }

    @Test
    fun `mapSaveError 异常映射精确对齐`() {
        assertEquals(
            TaskStrings.serviceMsgLinkedCourseNotFound,
            TaskFilterLogic.mapSaveError(IllegalArgumentException("task_course_not_found")),
        )
        assertEquals(
            TaskStrings.taskTitleRequired,
            TaskFilterLogic.mapSaveError(IllegalArgumentException("task_title_required")),
        )
        assertEquals(
            TaskStrings.taskTitleRequired,
            TaskFilterLogic.mapSaveError(IllegalArgumentException("other_arg_error")),
        )
        assertEquals(
            TaskStrings.saveFailed,
            TaskFilterLogic.mapSaveError(RuntimeException("io failure")),
        )
    }
}
