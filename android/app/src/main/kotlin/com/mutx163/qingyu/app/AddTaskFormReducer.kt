package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.pages.task.AddTaskViewState
import com.mutx163.qingyu.pages.task.TaskCourseOption
import com.mutx163.qingyu.pages.task.TaskFormDefaults
import com.mutx163.qingyu.pages.task.TaskFormLogic
import com.mutx163.qingyu.pages.task.TaskStrings
import java.time.LocalDateTime

/**
 * 作业表单（`AddTaskPage`）的**纯状态机**（Phase 3.5 · 主派工大表 T1 收尾）。
 *
 * ## 为什么需要它
 *
 * T1 的「加作业」动作要「带这门课进作业页」。壳里 `d2.addTask` 原本把
 * `AddTaskViewState(isEditing = false, title = "")` **写死**、所有回调都是空 `{}`：
 * 表单既不能输入也不能保存。只把课程 id 塞进去，用户会看到一个「预选好了但点不动」的死表单
 * ——比不预选更容易误解。所以这里补一层纯状态机：壳持有状态、把回调接到这些函数上。
 *
 * ## 判据出处（逐条对齐 Dart，只读）
 *
 * - 是否抢焦点：`TaskFormDefaults.shouldAutofocusTitle`（`TaskModel.kt:99-103`，
 *   对齐 `lib/domain/day_task_band_logic.dart:TaskFormDefaults`）——**从课程进入不抢焦点**，
 *   否则键盘会遮住半屏；
 * - 默认到期日：`TaskFormDefaults.initialDueDate`（`TaskModel.kt:108-117`）——
 *   编辑沿用原值 / 从课程进入用**那节课的发生日期** / 纯新建用今天；
 * - 是否勾选到期日：Dart `add_task_screen.dart:118-124` 的 `_hasDueDate = _dueDate != null`；
 * - 保存：`TaskFormLogic.buildTask`（`TaskModel.kt:395-422`）——标题 trim 后非空，
 *   课程为空时 `sourceWeek` 一并置空。
 *
 * 本文件不做任何 IO：写库由宿主调 `TimetableCourseService.addTask`。
 */
object AddTaskFormReducer {

    /**
     * 打开表单的初始状态。
     *
     * @param preselectedCourse 从课程操作弹层「作业」进来的那门课；纯新建传 `null`。
     * @param sourceWeek 当前浏览周次（从课程进入时记进 `sourceWeek`）。
     * @param courseOccurrenceDate 那节课的发生日期（`port.dateForCourseOccurrence`）；
     *   拿不到就传 `null`，退回「今天」。
     * @param isEditing 编辑已有作业时为 true（本批只有新建路径，参数留着不改调用点）。
     * @param editingDueDate 编辑态沿用原到期日。
     */
    fun initial(
        preselectedCourse: Course? = null,
        sourceWeek: Int? = null,
        courseOccurrenceDate: LocalDateTime? = null,
        isEditing: Boolean = false,
        editingDueDate: LocalDateTime? = null,
        today: LocalDateTime = LocalDateTime.now(),
    ): AddTaskViewState {
        val dueDate = TaskFormDefaults.initialDueDate(
            editingDueDate = editingDueDate,
            courseOccurrenceDate = courseOccurrenceDate,
            isEditing = isEditing,
            today = today,
        )
        return AddTaskViewState(
            isEditing = isEditing,
            title = "",
            courseId = preselectedCourse?.id,
            sourceWeek = if (preselectedCourse == null) null else sourceWeek?.toLong(),
            selectedCourseName = preselectedCourse?.name ?: TaskStrings.taskNoCourse,
            hasDueDate = dueDate != null,
            dueDate = dueDate,
            dueDateFormatted = TaskFormLogic.formatDate(dueDate),
            shouldAutofocusTitle = TaskFormDefaults.shouldAutofocusTitle(
                isEditing = isEditing,
                hasInitialCourse = preselectedCourse != null,
                hasInitialWeek = courseOccurrenceDate != null,
            ),
        )
    }

    /** 标题变化：顺手清掉上一次的校验提示（用户一开始打字就不该再红着）。 */
    fun withTitle(state: AddTaskViewState, title: String): AddTaskViewState =
        state.copy(title = title, titleError = null)

    fun withNote(state: AddTaskViewState, note: String): AddTaskViewState =
        state.copy(note = note)

    /**
     * 到期日开关（逐字对齐 Dart `add_task_screen.dart:246-253`）：打开时
     * `_dueDate ??= dateOnly(now)`；**关掉时把日期清成 null**。
     *
     * ⚠️ 这里更正过一次：本文件初版只看到 `:248` 的 `_hasDueDate = value;`，据此写成
     * 「关掉只改开关、原日期留着」。核完整块才发现 `:250-252` 明写 `if (!value) _dueDate = null;`
     * ⇒ 关掉就是**清空**（这也是 task-18「清空到期日」的语义出处）。
     */
    fun withHasDueDate(
        state: AddTaskViewState,
        hasDueDate: Boolean,
        today: LocalDateTime = LocalDateTime.now(),
    ): AddTaskViewState = if (hasDueDate) {
        val date = state.dueDate ?: CourseTask.dateOnly(today)
        state.copy(
            hasDueDate = true,
            dueDate = date,
            dueDateFormatted = TaskFormLogic.formatDate(date),
        )
    } else {
        state.copy(
            hasDueDate = false,
            dueDate = null,
            dueDateFormatted = TaskFormLogic.formatDate(null),
        )
    }

    /**
     * 选定到期日（Dart `add_task_screen.dart:361-364`：`_dueDate = dateOnly(selected)` 且
     * **顺带把开关打开**）。传 `null` 等价于清空，走 [withHasDueDate] 的关闭分支。
     */
    fun withDueDate(
        state: AddTaskViewState,
        dueDate: LocalDateTime?,
    ): AddTaskViewState = if (dueDate == null) {
        withHasDueDate(state, hasDueDate = false)
    } else {
        val date = CourseTask.dateOnly(dueDate)
        state.copy(
            hasDueDate = true,
            dueDate = date,
            dueDateFormatted = TaskFormLogic.formatDate(date),
        )
    }

    fun withCompleted(state: AddTaskViewState, isCompleted: Boolean): AddTaskViewState =
        state.copy(isCompleted = isCompleted)

    /** 选课（`null` = 取消关联）：课程为空时 `sourceWeek` 一并置空（与 `buildTask` 同口径）。 */
    fun withCourse(state: AddTaskViewState, course: Course?): AddTaskViewState =
        state.copy(
            courseId = course?.id,
            sourceWeek = if (course == null) null else state.sourceWeek,
            selectedCourseName = course?.name ?: TaskStrings.taskNoCourse,
        )

    /** 保存前校验：返回错误文案，`null` 表示可以保存。 */
    fun validate(state: AddTaskViewState): String? = TaskFormLogic.validateTitle(state.title)

    // ------------------------------------------------------------------
    // 选课程弹层（判据出处：Dart `add_task_screen.dart:282-347`）
    // ------------------------------------------------------------------

    /** 「无关联课程」这一项的 id（Dart `_noneCourseValue` 的对位件）。 */
    const val NO_COURSE_OPTION_ID = "task.noCourse"

    /**
     * 选课程弹层的候选项（Dart `:287-295`）：
     *
     * - **按课程名分组**（课表里同一门课的每个时段是独立条目，这里一门课只出现一次），
     *   分组按名称**升序**排；
     * - 第一项固定是「无关联课程」（`taskNoCourse`），在未关联任何课程时选中；
     * - 选中判据是「当前绑定课程的**名字**等于这个分组名」（Dart `:314-316`）；
     * - 分组对应的 id 取该组**第一条**课程（Dart `:344` `group.courses.first.id`）。
     */
    fun coursePickerOptions(
        courses: List<Course>,
        selectedCourseId: String?,
    ): List<TaskCourseOption> {
        val boundName = courses.firstOrNull { it.id == selectedCourseId }?.name
        val grouped = courses.groupBy { it.name }.toSortedMap()
        return buildList {
            add(
                TaskCourseOption(
                    id = NO_COURSE_OPTION_ID,
                    label = TaskStrings.taskNoCourse,
                    isSelected = selectedCourseId == null,
                ),
            )
            grouped.forEach { (name, group) ->
                add(
                    TaskCourseOption(
                        id = group.first().id,
                        label = name,
                        isSelected = boundName == name,
                    ),
                )
            }
        }
    }

    /**
     * 用户在选课程弹层点了某一项之后更新状态（逐条对齐 Dart `:330-346`）：
     *
     * - 选「无关联课程」⇒ 清掉 `courseId` 与 `sourceWeek`（`:331-334`）；
     * - 重选**当前已绑定分组**⇒ **什么都不改**（`:336-339`：保留原来的具体课时绑定，
     *   否则每次点开弹层再点一次同名分组都会把用户绑到「第一节课」上去）；
     * - 其它 ⇒ 绑定该分组的第一条课程（`:343-345`）。
     *
     * @param pickedOptionId 选项 id（[NO_COURSE_OPTION_ID] 或某条课程的 id）；
     *   传 `null` 表示用户取消（不改状态）。
     */
    fun applyPickedCourseOption(
        state: AddTaskViewState,
        courses: List<Course>,
        pickedOptionId: String?,
    ): AddTaskViewState {
        if (pickedOptionId == null) return state
        if (pickedOptionId == NO_COURSE_OPTION_ID) return withCourse(state, null)

        val boundName = courses.firstOrNull { it.id == state.courseId }?.name
        val picked = courses.firstOrNull { it.id == pickedOptionId } ?: return state
        if (boundName != null && boundName == picked.name) return state
        return withCourse(state, picked)
    }

    /**
     * 由表单状态构建作业实体（交给宿主 `TimetableCourseService.addTask` 落库）。
     *
     * @throws IllegalArgumentException 标题为空（与 `TaskFormLogic.buildTask` 同口径）。
     */
    fun buildTask(
        state: AddTaskViewState,
        existingTask: CourseTask? = null,
        now: LocalDateTime = LocalDateTime.now(),
    ): CourseTask = TaskFormLogic.buildTask(
        existingTask = existingTask,
        title = state.title,
        note = state.note,
        courseId = state.courseId,
        sourceWeek = state.sourceWeek,
        hasDueDate = state.hasDueDate,
        dueDate = state.dueDate,
        isCompleted = state.isCompleted,
        now = now,
    )
}
