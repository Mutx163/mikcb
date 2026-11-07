package com.mutx163.qingyu.pages.exam

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.ExamReminderPreset
import java.time.LocalDateTime
import java.util.UUID

/**
 * 加考试 / 编辑考试表单的**纯状态机**（批次 F10）。
 *
 * ## 为什么需要它
 *
 * `d3.addExam` 之前是把 `AddExamViewState(isEditing = false)` 写死、**14 个回调全是空 `{}`**
 * 喂给 [AddExamPage] 的：整页是一张静态图，而且 `isEditing` 恒为 false ⇒
 * 「编辑既有考试」这条路**根本不存在**（`d3.examList` 点进去也只会新建）。
 *
 * 照 `pages/task/AddTaskFormReducer.kt` 的现成范式补这一层：宿主（壳）持有
 * [AddExamViewState]，把页面的每个 `onXxx` 接到这里的 `withXxx`，写库交给宿主调
 * `TimetableExamService`。本文件**不做任何 IO**，也没有 Compose / Android 依赖 ⇒ JVM 可测。
 *
 * ## 判据出处（逐条对拍，只读）
 *
 * | 行为 | Dart 出处 | 说明 |
 * |---|---|---|
 * | 初始值 / 编辑载入 | `add_exam_screen.dart:40-70` | 已由 `AddExamLogic.initialState` 实现，这里只转调 |
 * | 选课回填默认名 | `:299-303` | **只在名称为空时**填 `examDefaultName`（已输入过就不覆盖） |
 * | 保存五道阻断 | `:1001-1041` | 名称走字段错误、其余走 toast（[validate]） |
 * | 自定义提醒三态 | `:555-596` | 非法 / 撞已有 ⇒ toast；**改回同一个值静默返回**（UNCHANGED 不弹） |
 * | 切换提醒预设 | `:471-478` | 只改预设，**保留已配的自定义列表**（注释明写 "Keep any existing custom list"） |
 * | 组装实体 | `:1043-1073` | 已由 `AddExamLogic.buildExam` 实现；id 保留原值、空字段转 null |
 *
 * ## 提醒调度为什么不在这里
 *
 * 通知换通道排在 Phase 4（清单 §二 F10 第 4 条）。所以本批只保证
 * **「存得住 + 回显得出来」**：`reminderPreset` / `customReminderMinutes` 原样进实体、
 * 原样读回来；真正的调度落地由通知层那一批负责，这里不假装已经会响。
 */
object AddExamFormReducer {

    /** 打开表单的初始状态：新建（`existing == null`）或编辑既有考试。 */
    fun initial(
        existing: Exam? = null,
        today: LocalDateTime = LocalDateTime.now(),
    ): AddExamViewState = AddExamLogic.initialState(existing, today)

    /** 编辑既有考试：把它的全部字段读回表单（`add_exam_screen.dart:56-70`）。 */
    fun initialFromExam(
        exam: Exam,
        today: LocalDateTime = LocalDateTime.now(),
    ): AddExamViewState = AddExamLogic.initialState(exam, today)

    // ------------------------------------------------------------------
    // 字段更新
    // ------------------------------------------------------------------

    /** 改名：顺手清掉上一次的字段错误与 toast（用户一开始打字就不该再红着）。 */
    fun withName(state: AddExamViewState, name: String): AddExamViewState =
        state.copy(name = name, nameError = null, toastMessage = null)

    /**
     * 选定关联课程（`null` = 清掉选择）。
     *
     * 名称为空时回填默认考试名（`add_exam_screen.dart:299-303`）。
     *
     * ⚠️ 已知一字之差：Dart 判的是 `_nameController.text.isEmpty`（原始文本为空），
     * 而模型层 `AddExamLogic.nameAfterCoursePicked` 用的是 **trim 后**判空
     * （`AddExamModelTest` 已把「只有空格也算空」钉成契约，见用例
     * `nameAfterCoursePicked("   ") == "期末考试"`）。这里**沿用模型口径**，
     * 不另写第二套判据；差异只影响「用户先敲了几个空格再选课」这一种情况。
     */
    fun withCourse(state: AddExamViewState, course: Course?): AddExamViewState =
        state.copy(
            selectedCourseId = course?.id,
            name = AddExamLogic.nameAfterCoursePicked(state.name),
            toastMessage = null,
        )

    /** 选定日期（`null` = 清空 ⇒ hasSelectedDate 同步置 false，与 `_hasSelectedDate` 同源）。 */
    fun withDate(state: AddExamViewState, date: LocalDateTime?): AddExamViewState =
        if (date == null) {
            state.copy(hasSelectedDate = false, selectedDate = null)
        } else {
            // Dart 存的是 `DateTime(y, m, d)`：只取年月日，时分恒为 0。
            state.copy(
                hasSelectedDate = true,
                selectedDate = LocalDateTime.of(date.year, date.monthValue, date.dayOfMonth, 0, 0),
            )
        }

    /** 开始时间：先过 `AddExamLogic.normalizeTimeOrFallback`，越界值不落进状态。 */
    fun withStartTime(state: AddExamViewState, value: String): AddExamViewState =
        state.copy(startTime = AddExamLogic.normalizeTimeOrFallback(value), toastMessage = null)

    fun withEndTime(state: AddExamViewState, value: String): AddExamViewState =
        state.copy(endTime = AddExamLogic.normalizeTimeOrFallback(value), toastMessage = null)

    fun withLocation(state: AddExamViewState, location: String): AddExamViewState =
        state.copy(location = location)

    fun withSeat(state: AddExamViewState, seat: String): AddExamViewState =
        state.copy(seatNumber = seat)

    fun withNote(state: AddExamViewState, note: String): AddExamViewState =
        state.copy(note = note)

    /** 切换提醒预设：**保留**已配置的自定义列表（Dart `:471-478`）。 */
    fun withReminderPreset(
        state: AddExamViewState,
        preset: ExamReminderPreset,
    ): AddExamViewState = state.copy(reminderPreset = preset, toastMessage = null)

    /**
     * 新增 / 修改一条自定义提醒（Dart `:555-596`）。
     *
     * 四种结果里只有两种上屏：「小于等于 0」与「和别的条目撞了」弹 toast；
     * **改成同一个值（UNCHANGED）静默返回**——Dart 那里就是 `return;`，不发任何提示。
     */
    fun withCustomReminderAdded(
        state: AddExamViewState,
        totalMinutes: Int,
        replacingMinutes: Int?,
    ): AddExamViewState {
        val applied = AddExamLogic.applyCustomReminderOffset(
            current = state.customReminderMinutes,
            totalMinutes = totalMinutes,
            replacingMinutes = replacingMinutes,
        )
        return when (applied.status) {
            CustomReminderStatus.ADDED -> state.copy(
                customReminderMinutes = applied.minutes,
                toastMessage = null,
            )
            CustomReminderStatus.UNCHANGED -> state.copy(toastMessage = null)
            CustomReminderStatus.INVALID -> state.copy(
                toastMessage = ExamStrings.examReminderCustomInvalid.text,
            )
            CustomReminderStatus.DUPLICATE -> state.copy(
                toastMessage = ExamStrings.examReminderCustomAlreadyAdded.text,
            )
        }
    }

    /** 删一条自定义提醒（Dart `:525-531`）：删完仍按降序展示，与新增同口径。 */
    fun withCustomReminderRemoved(
        state: AddExamViewState,
        minutes: Int,
    ): AddExamViewState = state.copy(
        customReminderMinutes = state.customReminderMinutes
            .filterNot { it == minutes }
            .sortedDescending(),
        toastMessage = null,
    )

    // ------------------------------------------------------------------
    // 校验
    // ------------------------------------------------------------------

    /**
     * 保存前校验，返回**贴好错误的状态**（不写库、不判成功）：
     * 名称为空给字段级 `nameError`（Dart 是 `FormField.validator`），其余给 `toastMessage`。
     *
     * 宿主用法：`val checked = validate(form); form = checked; if (checked.blocker == null) { ...写库... }`
     */
    fun validate(state: AddExamViewState): AddExamValidateResult {
        val blocker = AddExamLogic.resolveSaveBlocker(state)
        return when (blocker) {
            null -> AddExamValidateResult(
                state = state.copy(nameError = null, toastMessage = null),
                blocker = null,
            )
            AddExamBlocker.NAME_REQUIRED -> AddExamValidateResult(
                state = state.copy(
                    nameError = ExamStrings.examNameRequired.text,
                    toastMessage = null,
                ),
                blocker = blocker,
            )
            else -> AddExamValidateResult(
                state = state.copy(
                    nameError = null,
                    toastMessage = AddExamLogic.blockerMessage(blocker),
                ),
                blocker = blocker,
            )
        }
    }

    /** 校验结果：贴好错误的状态 + 第一道阻断（`null` 表示可以保存）。 */
    data class AddExamValidateResult(
        val state: AddExamViewState,
        val blocker: AddExamBlocker?,
    )

    // ------------------------------------------------------------------
    // 组装 / 展示派生
    // ------------------------------------------------------------------

    /**
     * 组装写库用的实体（Dart `:1043-1073`）：id 编辑态保留原值、新建态用注入的 [newId]；
     * 空字符串字段转 `null`（Dart 三个 `trim().isEmpty ? null : ...`）。
     *
     * 调用方必须先过 [validate]（日期为空时 `AddExamLogic.buildExam` 会抛 IllegalArgumentException）。
     */
    fun buildExam(
        state: AddExamViewState,
        existing: Exam?,
        now: LocalDateTime = LocalDateTime.now(),
        newId: String = UUID.randomUUID().toString(),
    ): Exam = AddExamLogic.buildExam(state = state, existing = existing, newId = newId, now = now)

    /** 日期行文案（`yyyy-MM-dd` + 学期内补「第 N 周 周X」）。 */
    fun dateDisplay(
        state: AddExamViewState,
        semesterStart: LocalDateTime?,
        semesterWeekCount: Int,
    ): String = AddExamLogic.formatDateDisplay(state, semesterStart, semesterWeekCount)

    /** 当前选中的课程（找不到返回 null，页面副标题会退回「关联课程」提示）。 */
    fun selectedCourse(state: AddExamViewState, courses: List<Course>): Course? =
        state.selectedCourseId?.let { id -> courses.firstOrNull { it.id == id } }

    /** 课表一门课都没有时，关联课程行整行不可点（Dart `onTap: null`）。 */
    fun courseGroupsEmpty(courses: List<Course>): Boolean = courses.isEmpty()

    /**
     * 选课弹层的候选项（Dart `showCourseTemplatePickerSheet(courseGroups:)`）：
     * **按课程名分组、名称升序、一门课只出现一次**，组 id 取该组第一条课程
     * （与 `AddTaskFormReducer.coursePickerOptions` 同口径，但那一份是作业域的类型，这里不跨域 import）。
     */
    fun coursePickerOptions(
        courses: List<Course>,
        selectedCourseId: String?,
    ): List<ExamCourseOption> {
        val grouped = courses.groupBy { it.name.trim() }
            .toSortedMap(compareBy { it.lowercase() })
        return grouped.map { (name, group) ->
            val first = group.first()
            ExamCourseOption(
                courseId = first.id,
                title = name,
                details = first.teacher,
                // 2026-11-02 弹窗审核 P2：Dart 选项行首有课程颜色徽章，颜色随选项一起下发。
                color = first.color,
                selected = selectedCourseId != null &&
                    group.any { it.id == selectedCourseId },
            )
        }
    }

    /** 选课弹层的一行。 */
    data class ExamCourseOption(
        val courseId: String,
        val title: String,
        val details: String,
        /** 该组第一条课程的颜色（hex，如 `#3366FF`）；渲染层画行首徽章用。 */
        val color: String,
        val selected: Boolean,
    )

    /** 自定义提醒选择器的初值（三段）；[minutes] 为 null 表示新增默认 60 分钟。 */
    fun reminderPickerInitial(minutes: Int?): ReminderPickerParts =
        AddExamLogic.decomposeReminderTotal(minutes)

    /** 选择器三段 → 总分钟数。 */
    fun reminderTotal(parts: ReminderPickerParts): Int =
        AddExamLogic.reminderTotalMinutes(parts.days, parts.hours, parts.minutes)
}
