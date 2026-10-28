package com.mutx163.qingyu.pages.task

import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.course.TimetableCoursePort
import com.mutx163.qingyu.course.TimetableCourseService
import java.time.LocalDateTime

/**
 * 任务清单宿主控制器：把仓储（[TimetableCoursePort]）里的 `tasks` / `courses`
 * 接成页面要的 [TaskListViewState]，并把"勾完成 / 删任务"这类写动作落到
 * [TimetableCourseService]。
 *
 * **为什么要有它**：渲染层 [TaskListPage] 只负责画，点了之后"写到哪"由宿主决定；
 * 而 `pages/task/` 此前只有模型层（[TaskModel]）与表单 reducer，**没有把模型接上仓储的装配层**，
 * 所以壳里的 `d2.taskList` 一直喂 `shellSampleTaskViewState()`（空态）＋ 6 个空回调 ⇒ 点了没反应。
 * 本类型即补上这一层（与 `TimetableProfilesController` 同形：控制器持有界面态、只算状态与执行动作，
 * "何时订阅仓储通知"由 Compose 宿主负责）。
 *
 * **纯 Kotlin**：不引 `android.*` / `androidx.compose.*`，JVM 可测。
 * **不做导航**：`onAddTask` / `onEditTask` 属路由跳转，留在壳里；控制器只覆盖写库类动作。
 */
class TaskListController(
    private val port: TimetableCoursePort,
    private val clock: () -> LocalDateTime = { LocalDateTime.now() },
) {
    /** 当前日期筛选（全部 / 今日 / 本周）。对齐 Dart `_TaskDateFilter`。 */
    var dateFilter: TaskDateFilter = TaskDateFilter.ALL
        private set

    /** 当前课程筛选：`null` / [TaskFilterLogic.ALL_COURSES_VALUE] = 全部；[TaskFilterLogic.NONE_COURSE_VALUE] = 无课程；其余为课程名。 */
    var courseFilter: String? = null
        private set

    /** 按当前筛选与时刻构造整页视图状态。宿主应在仓储通知后重算。 */
    fun viewState(now: LocalDateTime = clock()): TaskListViewState =
        TaskFilterLogic.buildTaskListViewState(
            allTasks = port.tasks,
            courses = port.courses,
            dateFilter = dateFilter,
            courseFilter = courseFilter,
            now = now,
        )

    /** 课程筛选弹层的候选项（全部 / 无课程 / 各课程名分组）。 */
    fun courseOptions(): List<TaskCourseOption> {
        val options = ArrayList<TaskCourseOption>(port.courses.size + 2)
        val allSelected = courseFilter == null || courseFilter == TaskFilterLogic.ALL_COURSES_VALUE
        options += TaskCourseOption(TaskFilterLogic.ALL_COURSES_VALUE, TaskStrings.taskAllCourses, allSelected)
        options += TaskCourseOption(
            TaskFilterLogic.NONE_COURSE_VALUE,
            TaskStrings.taskNoCourse,
            courseFilter == TaskFilterLogic.NONE_COURSE_VALUE,
        )
        // 同名课程在筛选里归一组（与 TaskFilterLogic.filterTasks 按 name 匹配一致）。
        port.courses.map { it.name }.distinct().forEach { name ->
            options += TaskCourseOption(name, name, courseFilter == name)
        }
        return options
    }

    fun setDateFilter(filter: TaskDateFilter) {
        dateFilter = filter
    }

    /** 应用课程筛选；传 `null` 或 [TaskFilterLogic.ALL_COURSES_VALUE] 表示"全部"。 */
    fun setCourseFilter(filter: String?) {
        courseFilter = if (filter == null || filter == TaskFilterLogic.ALL_COURSES_VALUE) null else filter
    }

    /** 勾选/取消勾选一条任务（真写库：TimetableCourseService 负责落盘 + 通知）。 */
    fun toggleTask(task: CourseTask) {
        TimetableCourseService.toggleTaskCompleted(port, task.id)
    }

    /** 删除一条任务（真写库）。 */
    fun deleteTask(task: CourseTask) {
        TimetableCourseService.deleteTask(port, task.id)
    }

    /** 新建一条任务（供"加作业"入口在此控制器内闭环时使用）。 */
    fun addTask(task: CourseTask) {
        TimetableCourseService.addTask(port, task)
    }

    /** 改一条任务。 */
    fun updateTask(task: CourseTask) {
        TimetableCourseService.updateTask(port, task)
    }
}
