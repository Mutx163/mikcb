package com.mutx163.qingyu.pages.task

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.CourseTaskSource
import java.time.LocalDateTime
import java.util.UUID

/**
 * 任务日期筛选枚举（对齐 `lib/screens/task_list_screen.dart:_TaskDateFilter`）。
 */
enum class TaskDateFilter {
    ALL,
    TODAY,
    WEEK;

    companion object {
        fun fromIndex(index: Int): TaskDateFilter =
            entries.getOrNull(index) ?: ALL
    }
}

/**
 * 任务列表项展示模型（对应 Dart `_TaskRow` 数据语义）。
 */
data class TaskItemView(
    val id: String,
    val title: String,
    val detailText: String,
    val note: String?,
    val isCompleted: Boolean,
    val isOverdue: Boolean,
    val courseId: String?,
    val hasCourse: Boolean,
    val task: CourseTask,
)

/**
 * 任务分组（已逾期 / 任务清单 / 已完成）。
 */
data class TaskSectionView(
    val title: String,
    val items: List<TaskItemView>,
)

/**
 * 课程筛选选项（全部课程 / 无关联课程 / 课程分组名称）。
 */
data class TaskCourseOption(
    val id: String,
    val label: String,
    val isSelected: Boolean,
)

/**
 * 任务清单页整页视图状态。
 */
data class TaskListViewState(
    val dateFilter: TaskDateFilter,
    val courseFilter: String?,
    val selectedCourseLabel: String,
    val sections: List<TaskSectionView>,
    val emptyTitle: String,
    val undatedHiddenCount: Int,
    val totalTasksCount: Int,
) {
    val isEmpty: Boolean get() = sections.isEmpty() || sections.all { it.items.isEmpty() }
}

/**
 * 添加 / 编辑任务表单视图状态。
 */
data class AddTaskViewState(
    val isEditing: Boolean,
    val title: String,
    val titleError: String? = null,
    val note: String = "",
    val courseId: String? = null,
    val sourceWeek: Long? = null,
    val selectedCourseName: String = TaskStrings.taskNoCourse,
    val hasDueDate: Boolean = false,
    val dueDate: LocalDateTime? = null,
    val dueDateFormatted: String = "",
    val isCompleted: Boolean = false,
    val shouldAutofocusTitle: Boolean = false,
) {
    val canSave: Boolean get() = title.trim().isNotEmpty()
}

/**
 * 表单默认规则（对齐 `lib/domain/day_task_band_logic.dart:TaskFormDefaults`）。
 */
object TaskFormDefaults {
    /**
     * 打开表单时是否弹起键盘聚焦标题框。
     *
     * 只有「纯新建」才抢焦点；从课程进入或编辑已有任务时，抢焦点会遮挡半屏。
     */
    fun shouldAutofocusTitle(
        isEditing: Boolean,
        hasInitialCourse: Boolean,
        hasInitialWeek: Boolean,
    ): Boolean = !isEditing && !hasInitialCourse && !hasInitialWeek

    /**
     * 新建时默认到期日：新建默认今天，从课程进入使用课时发生日期，编辑态沿用原值。
     */
    fun initialDueDate(
        editingDueDate: LocalDateTime?,
        courseOccurrenceDate: LocalDateTime?,
        isEditing: Boolean,
        today: LocalDateTime,
    ): LocalDateTime? {
        if (isEditing) return editingDueDate
        if (courseOccurrenceDate != null) return courseOccurrenceDate
        return CourseTask.dateOnly(today)
    }
}

/**
 * 扩展函数：到期日是否在指定区间内（含两端，按 dateOnly 比较）。
 */
fun CourseTask.isDueBetween(start: LocalDateTime, end: LocalDateTime): Boolean {
    val due = dueDate ?: return false
    val normalizedDue = CourseTask.dateOnly(due)
    val normalizedStart = CourseTask.dateOnly(start)
    val normalizedEnd = CourseTask.dateOnly(end)
    return !normalizedDue.isBefore(normalizedStart) && !normalizedDue.isAfter(normalizedEnd)
}

/**
 * 扩展函数：是否符合「今日」筛选口径（清单页与待办带共用）。
 *
 * 包括今天到期（含已完成）+ 逾期未完成任务。
 */
fun CourseTask.isRelevantToday(today: LocalDateTime): Boolean {
    if (isDueOn(today)) return true
    return isOverdue(now = today)
}

/**
 * 任务过滤与展示组装纯逻辑。
 */
object TaskFilterLogic {
    const val ALL_COURSES_VALUE = "__all__"
    const val NONE_COURSE_VALUE = "__none__"

    /**
     * 计算指定日期所在自然周的周一 00:00 与周日 00:00。
     */
    fun resolveWeekRange(today: LocalDateTime): Pair<LocalDateTime, LocalDateTime> {
        val dateOnlyToday = CourseTask.dateOnly(today)
        val dayOfWeek = dateOnlyToday.dayOfWeek.value // 1 (Mon) .. 7 (Sun)
        val weekStart = dateOnlyToday.minusDays((dayOfWeek - 1).toLong())
        val weekEnd = weekStart.plusDays(6)
        return Pair(weekStart, weekEnd)
    }

    /**
     * 过滤任务列表。
     *
     * @param tasks 全量任务
     * @param dateFilter 日期筛选（全部/今日/本周）
     * @param courseFilter 课程筛选（null 表示全部，"__none__" 表示无课程，其余为课程名）
     * @param courses 课表所有课程（用于匹配同名课程分组包含的所有 courseId）
     * @param now 当前时间基准
     */
    fun filterTasks(
        tasks: List<CourseTask>,
        dateFilter: TaskDateFilter,
        courseFilter: String?,
        courses: List<Course>,
        now: LocalDateTime = LocalDateTime.now(),
    ): List<CourseTask> {
        val today = CourseTask.dateOnly(now)
        val (weekStart, weekEnd) = resolveWeekRange(today)

        val selectedCourseIds: Set<String>? = when {
            courseFilter == null || courseFilter == ALL_COURSES_VALUE || courseFilter == NONE_COURSE_VALUE -> null
            else -> courses.filter { it.name == courseFilter }.map { it.id }.toSet()
        }

        return tasks.filter { task ->
            if (courseFilter == NONE_COURSE_VALUE && task.courseId != null) {
                return@filter false
            }
            if (selectedCourseIds != null && !selectedCourseIds.contains(task.courseId)) {
                return@filter false
            }
            when (dateFilter) {
                TaskDateFilter.ALL -> true
                TaskDateFilter.TODAY -> task.isRelevantToday(today)
                TaskDateFilter.WEEK -> task.isDueBetween(weekStart, weekEnd)
            }
        }.sortedWith(CourseTask::compareByDueDate)
    }

    /**
     * 统计当前筛选条件下被挡在外部的未完成且未设截止日期的作业条数。
     */
    fun undatedHiddenCount(
        tasks: List<CourseTask>,
        dateFilter: TaskDateFilter,
        courseFilter: String?,
        courses: List<Course>,
    ): Int {
        if (dateFilter == TaskDateFilter.ALL) return 0

        val selectedCourseIds: Set<String>? = when {
            courseFilter == null || courseFilter == ALL_COURSES_VALUE || courseFilter == NONE_COURSE_VALUE -> null
            else -> courses.filter { it.name == courseFilter }.map { it.id }.toSet()
        }

        return tasks.count { task ->
            if (task.dueDate != null || task.isCompleted) {
                false
            } else if (courseFilter == NONE_COURSE_VALUE && task.courseId != null) {
                false
            } else if (selectedCourseIds != null && !selectedCourseIds.contains(task.courseId)) {
                false
            } else {
                true
            }
        }
    }

    /**
     * 空态提示文案。
     */
    fun resolveEmptyTitle(
        noTasksAtAll: Boolean,
        courseFilter: String?,
        dateFilter: TaskDateFilter,
    ): String {
        if (noTasksAtAll) return TaskStrings.taskNoTasks
        if (courseFilter != null && courseFilter != ALL_COURSES_VALUE) {
            return TaskStrings.taskNoTasksForCourse
        }
        return when (dateFilter) {
            TaskDateFilter.ALL -> TaskStrings.taskNoTasks
            TaskDateFilter.TODAY -> TaskStrings.taskNoTasksForToday
            TaskDateFilter.WEEK -> TaskStrings.taskNoTasksForWeek
        }
    }

    /**
     * 组装单行任务展示模型。
     */
    fun buildTaskItemView(
        task: CourseTask,
        course: Course?,
        now: LocalDateTime = LocalDateTime.now(),
    ): TaskItemView {
        val title = task.title.trim().ifEmpty { TaskStrings.taskHomeworkDefaultTitle }
        val detailParts = mutableListOf<String>()

        if (course != null) {
            detailParts.add(course.name)
            if (task.sourceWeek != null) {
                detailParts.add(TaskStrings.weekLabel(task.sourceWeek))
            }
        }

        val dueDateText = task.dueDate?.let {
            "${it.monthValue}月${it.dayOfMonth}日"
        } ?: TaskStrings.taskNoDueDate
        detailParts.add(dueDateText)

        val isOverdue = task.isOverdue(now)

        return TaskItemView(
            id = task.id,
            title = title,
            detailText = detailParts.joinToString(" · "),
            note = task.note?.takeIf { it.isNotBlank() },
            isCompleted = task.isCompleted,
            isOverdue = isOverdue,
            courseId = task.courseId,
            hasCourse = course != null,
            task = task,
        )
    }

    /**
     * 划分三段（已逾期 / 任务清单 / 已完成）。
     */
    fun groupTasksIntoSections(
        visibleTasks: List<CourseTask>,
        coursesById: Map<String, Course>,
        now: LocalDateTime = LocalDateTime.now(),
    ): List<TaskSectionView> {
        val overdueTasks = visibleTasks.filter { it.isOverdue(now) }
        val completedTasks = visibleTasks.filter { it.isCompleted }
        val activeTasks = visibleTasks.filter { !it.isCompleted && !it.isOverdue(now) }

        val sections = mutableListOf<TaskSectionView>()

        if (overdueTasks.isNotEmpty()) {
            sections.add(
                TaskSectionView(
                    title = TaskStrings.taskOverdueSection,
                    items = overdueTasks.map { buildTaskItemView(it, it.courseId?.let { id -> coursesById[id] }, now) },
                ),
            )
        }
        if (activeTasks.isNotEmpty()) {
            sections.add(
                TaskSectionView(
                    title = TaskStrings.taskListTitle,
                    items = activeTasks.map { buildTaskItemView(it, it.courseId?.let { id -> coursesById[id] }, now) },
                ),
            )
        }
        if (completedTasks.isNotEmpty()) {
            sections.add(
                TaskSectionView(
                    title = TaskStrings.taskCompletedSection,
                    items = completedTasks.map { buildTaskItemView(it, it.courseId?.let { id -> coursesById[id] }, now) },
                ),
            )
        }

        return sections
    }

    /**
     * 构建整页视图状态。
     */
    fun buildTaskListViewState(
        allTasks: List<CourseTask>,
        courses: List<Course>,
        dateFilter: TaskDateFilter = TaskDateFilter.ALL,
        courseFilter: String? = null,
        now: LocalDateTime = LocalDateTime.now(),
    ): TaskListViewState {
        val visibleTasks = filterTasks(allTasks, dateFilter, courseFilter, courses, now)
        val coursesById = courses.associateBy { it.id }
        val sections = groupTasksIntoSections(visibleTasks, coursesById, now)
        val undatedHidden = undatedHiddenCount(allTasks, dateFilter, courseFilter, courses)
        val emptyTitle = resolveEmptyTitle(allTasks.isEmpty(), courseFilter, dateFilter)

        val selectedLabel = when (courseFilter) {
            null, ALL_COURSES_VALUE -> TaskStrings.taskAllCourses
            NONE_COURSE_VALUE -> TaskStrings.taskNoCourse
            else -> courseFilter
        }

        return TaskListViewState(
            dateFilter = dateFilter,
            courseFilter = courseFilter,
            selectedCourseLabel = selectedLabel,
            sections = sections,
            emptyTitle = emptyTitle,
            undatedHiddenCount = undatedHidden,
            totalTasksCount = allTasks.size,
        )
    }

    /**
     * 保存错误映射（对齐 Dart 侧 ArgumentError / Exception 区分）。
     */
    fun mapSaveError(error: Throwable?): String {
        val msg = error?.message
        return when {
            msg == "task_course_not_found" -> TaskStrings.serviceMsgLinkedCourseNotFound
            msg == "task_title_required" -> TaskStrings.taskTitleRequired
            error is IllegalArgumentException -> TaskStrings.taskTitleRequired
            else -> TaskStrings.saveFailed
        }
    }
}

/**
 * 任务表单构建纯函数。
 */
object TaskFormLogic {
    /**
     * 校验任务标题。
     */
    fun validateTitle(title: String): String? {
        return if (title.trim().isEmpty()) TaskStrings.taskTitleRequired else null
    }

    /**
     * 格式化到期日显示（例如 "2026年10月27日"）。
     */
    fun formatDate(dateTime: LocalDateTime?): String {
        if (dateTime == null) return TaskStrings.taskNoDueDate
        return "${dateTime.year}年${dateTime.monthValue}月${dateTime.dayOfMonth}日"
    }

    /**
     * 根据输入状态构建或更新 CourseTask 实体。
     */
    fun buildTask(
        existingTask: CourseTask?,
        title: String,
        note: String?,
        courseId: String?,
        sourceWeek: Long?,
        hasDueDate: Boolean,
        dueDate: LocalDateTime?,
        isCompleted: Boolean,
        now: LocalDateTime = LocalDateTime.now(),
    ): CourseTask {
        val trimmedTitle = title.trim()
        require(trimmedTitle.isNotEmpty()) { "task_title_required" }

        return CourseTask(
            id = existingTask?.id ?: UUID.randomUUID().toString(),
            title = trimmedTitle,
            courseId = courseId,
            sourceWeek = if (courseId == null) null else sourceWeek,
            dueDate = if (hasDueDate && dueDate != null) CourseTask.dateOnly(dueDate) else null,
            note = note?.trim()?.ifEmpty { null },
            isCompleted = isCompleted,
            source = existingTask?.source ?: CourseTaskSource.MANUAL,
            isUserEdited = existingTask?.isUserEdited == true || existingTask != null,
            createdAt = existingTask?.createdAt ?: now,
            updatedAt = now,
        )
    }
}
