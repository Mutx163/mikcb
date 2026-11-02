package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseSessionNote
import com.mutx163.qingyu.course.TimetableCoursePort
import com.mutx163.qingyu.course.TimetableCourseService
import com.mutx163.qingyu.pages.course.ClassAlarmPlanLogic
import java.time.LocalDate
import java.time.LocalDateTime
import java.util.UUID

/**
 * 课程卡片操作弹层的**动作分派器**（Phase 3.5 · 主派工大表 T1）。
 *
 * ## 它解决什么
 *
 * Dart 点课程卡片弹的是 `lib/widgets/course_action_sheet.dart` 的**操作弹层**：
 * 上方是这节课的信息（时间/教师/地点/备注…），下方 6 个动作——编辑 / 调课 / 停课复课 /
 * 删除 / 加作业 / 单节课提醒（`:876-914`）。Compose 侧此前**一个都没有**，
 * 所以点课程卡片「没反应」。本文件把「点某个动作之后到底发生什么」定下来：
 * 能真写库的**真写**，写不了的**明确报缺口**（[CourseActionOutcome.NotWired]），绝不假成功。
 *
 * ## 分层
 *
 * 本层是**纯逻辑**（无 Android / 无 Compose）：输入「动作 + 课程 + 周次 + 数据端口」，
 * 输出一个结果（导航意图 / 写库回执 / 缺口）。渲染层
 * `composeP1/.../pages/course/CourseActionSheet.kt` 只负责把动作转出来；
 * 壳负责按结果跳页与提示。
 *
 * ## 写入口径（逐条对齐 Dart，行号可查）
 *
 * | 动作 | Dart 出处 | 本层 |
 * |---|---|---|
 * | 删除整门课 | `timetable_course_sheet_actions.dart:188-235` → `deleteCourse(id)` | [deleteCourse] |
 * | 删这一周的课 | `timetable_provider.dart:2756-2827` `_deleteCourseOccurrenceImpl` | [deleteOccurrence] |
 * | 调课 | `timetable_provider.dart:2853-2927` `_rescheduleCourseOccurrenceImpl` | [rescheduleOccurrence] |
 * | 本周停/复课 | `timetable_provider.dart:2336-2360` `_toggleCourseSuspensionImpl` | [toggleSuspensionThisWeek] |
 * | 整门停/复课 | `:79-83` 的 `suspendAllWeeks` / `unsuspendAllWeeks` | [suspendAllWeeks] / [unsuspendAllWeeks] |
 *
 * ## 为什么这些写操作落在宿主层而不是数据层
 *
 * `TimetableCourseService`（task-7 交付）只有 add / update / delete / deleteGroup / updateGroup，
 * **没有** occurrence 级的删与调课、也没有停课一族。本批写作用域是 `app/` + `composeP1/.../course/`，
 * 改不了那个服务，所以按 Dart 的**可观测语义**用既有原语（`Course.activeWeeks` /
 * `sessionNotesExcludingWeek` + `update` / `add` / `delete`）在本层实现。
 * ⚠️ 这几条**应该搬回数据层**（它们不是 UI 逻辑）；等数据层泳道下次动那个服务时一并迁。
 */
enum class CourseAction {
    /** 编辑这门课（带真实课程进编辑页）。 */
    EDIT,

    /** 调课：把这一周的这次课挪到别的周 / 星期 / 节次。 */
    RESCHEDULE,

    /** 停课 / 复课（本周）。 */
    SUSPEND,

    /** 删除整门课。 */
    DELETE,

    /** 只删这一周的这次课。 */
    DELETE_OCCURRENCE,

    /** 加作业（进作业页，带上这门课）。 */
    ADD_TASK,

    /** 给这节课设闹钟。 */
    SET_ALARM,
}

/** 停课作用域（Dart `CourseSuspendMode`，`course_followup_sheets.dart`）。 */
enum class SuspendScope {
    THIS_WEEK,
    ALL_WEEKS,
}

/** 分派结果：导航意图 / 写库回执 / 明确缺口。 */
sealed interface CourseActionOutcome {

    /** 进编辑页；**带的就是这一门课**（参数透传契约，见测试）。 */
    data class OpenEdit(val course: Course) : CourseActionOutcome

    /** 进作业页；带这门课做预选。 */
    data class OpenAddTask(val course: Course) : CourseActionOutcome

    /** 进调课弹层（目标周/星期/节次的选择属 UI，选完回调 [rescheduleOccurrence]）。 */
    data class OpenReschedule(val course: Course, val week: Int) : CourseActionOutcome

    /** 已删除整门课。 */
    data class DeletedCourse(val courseId: String) : CourseActionOutcome

    /**
     * 已删除这一周的这次课。
     *
     * @param removedWholeCourse 该课只剩这一周 ⇒ 整门课被摘掉（Dart `:2790-2791`）。
     */
    data class DeletedOccurrence(
        val courseId: String,
        val week: Int,
        val removedWholeCourse: Boolean,
    ) : CourseActionOutcome

    /** 已调课（或判定为「无变化」⇒ [changed] 为 false，Dart `:2916-2918`）。 */
    data class Rescheduled(
        val courseId: String,
        val sourceWeek: Int,
        val targetWeek: Int,
        val changed: Boolean,
    ) : CourseActionOutcome

    /** 停课状态已翻转。 */
    data class SuspensionChanged(
        val courseId: String,
        val suspended: Boolean,
        val scope: SuspendScope,
    ) : CourseActionOutcome

    /**
     * **明确缺口**：这个动作在 Compose 侧还没有落点。宿主应当据此提示用户，
     * **不要**假装成功（本仓纪律：不假实现）。
     */
    data class NotWired(val action: CourseAction, val reason: String) : CourseActionOutcome
}

object CourseActionDispatcher {

    /**
     * 分派一个动作。
     *
     * @param course 被操作的课程（**同一个实例**会被原样带进编辑/作业意图）。
     * @param week 用户当前正在看的周次（occurrence 级操作与闹钟都按它定位）。
     * @param port 数据端口（`TimetableRepository` 实现了它）。
     */
    fun dispatch(
        action: CourseAction,
        course: Course,
        week: Int,
        port: TimetableCoursePort,
    ): CourseActionOutcome = when (action) {
        CourseAction.EDIT -> CourseActionOutcome.OpenEdit(course)

        CourseAction.ADD_TASK -> CourseActionOutcome.OpenAddTask(course)

        CourseAction.RESCHEDULE -> if (!course.isInWeek(week)) {
            CourseActionOutcome.NotWired(
                CourseAction.RESCHEDULE,
                "course_not_scheduled_week:${course.id}@$week",
            )
        } else {
            CourseActionOutcome.OpenReschedule(course, week)
        }

        CourseAction.SET_ALARM ->
            // 弹层对这一动作的处理是**开子弹层**（Dart `:852` `onSetAlarm(course)` 直接
            // 开 `class_reminder_sheet`），不走分派器；这条分支只为保住动作词汇表完整，
            // 真有人分派到它时照实报「分派器没有写入落点」，不假装成功。
            CourseActionOutcome.NotWired(
                CourseAction.SET_ALARM,
                "set_alarm_is_sheet_driven_use_ClassAlarmEvent",
            )

        CourseAction.DELETE -> {
            deleteCourse(port, course.id)
            CourseActionOutcome.DeletedCourse(course.id)
        }

        CourseAction.DELETE_OCCURRENCE -> deleteOccurrence(port, course.id, week)

        CourseAction.SUSPEND -> toggleSuspensionThisWeek(port, course.id, week)
    }

    // ------------------------------------------------------------------
    // 写入（可单独调用，弹层里「先选作用域再写」的路径也走这些）
    // ------------------------------------------------------------------

    /** 删除整门课（Dart `deleteCourse(id)`，服务侧连带摘考试与作业）。 */
    fun deleteCourse(port: TimetableCoursePort, courseId: String) {
        TimetableCourseService.delete(port, courseId)
    }

    /**
     * 删除**某一周**的这次课（Dart `_deleteCourseOccurrenceImpl`，`:2756-2827`）：
     *
     * 1. 找不到课 / 那周本来就没课 ⇒ 抛 `IllegalArgumentException`（Dart 抛 `ArgumentError`）；
     * 2. 从 `activeWeeks` 里去掉这一周，写成 `customWeeks` + 首尾周，并清掉单双周标志
     *    （`:2795-2802`）；
     * 3. 去掉这一周的 `sessionNotes`（`:2801`）；
     * 4. 一周不剩 ⇒ 整门课删掉（`:2790-2791`）。
     */
    fun deleteOccurrence(
        port: TimetableCoursePort,
        courseId: String,
        sourceWeek: Int,
    ): CourseActionOutcome.DeletedOccurrence {
        val course = port.getCourseById(courseId)
            ?: throw IllegalArgumentException("course_not_found_for_delete")
        if (!course.isInWeek(sourceWeek)) {
            throw IllegalArgumentException("course_not_scheduled_week:$sourceWeek")
        }

        val remainingWeeks = course.activeWeeks.filter { it != sourceWeek }.sorted()
        if (remainingWeeks.isEmpty()) {
            TimetableCourseService.delete(port, courseId)
            return CourseActionOutcome.DeletedOccurrence(courseId, sourceWeek, removedWholeCourse = true)
        }

        val updated = course.copy(
            startWeek = remainingWeeks.first(),
            endWeek = remainingWeeks.last(),
            isOddWeek = false,
            isEvenWeek = false,
            customWeeks = remainingWeeks,
            sessionNotes = course.sessionNotesExcludingWeek(sourceWeek),
        )
        TimetableCourseService.update(port, updated, previousSharedName = null)
        return CourseActionOutcome.DeletedOccurrence(courseId, sourceWeek, removedWholeCourse = false)
    }

    /**
     * 调课：把 `sourceWeek` 的这次课挪到目标周/星期/节次（Dart `:2853-2927`）。
     *
     * 语义与 Dart 逐条对齐：
     * - 无变化（目标与现状全等）⇒ **不写**，返回 `changed = false`（`:2909-2918`）；
     * - 原课还剩别的周 ⇒ 原课收缩到剩余周，另**新增一条单周条目**放在目标位置（`:2920-2923` 及后续）；
     * - 原课只剩这一周 ⇒ 就地改（不新增条目）；
     * - 目标位置用**同名前缀**（服务侧会把共享字段广播过去，颜色/简称不会分叉）。
     */
    fun rescheduleOccurrence(
        port: TimetableCoursePort,
        courseId: String,
        sourceWeek: Int,
        targetWeek: Int,
        targetDayOfWeek: Int,
        targetStartSection: Int,
        targetEndSection: Int,
        targetLocation: String? = null,
    ): CourseActionOutcome.Rescheduled {
        val course = port.getCourseById(courseId)
            ?: throw IllegalArgumentException("course_not_found_for_reschedule")
        if (!course.isInWeek(sourceWeek)) {
            throw IllegalArgumentException("course_not_scheduled_week:$sourceWeek")
        }
        val semesterWeekCount = port.semesterWeekCount
        if (targetWeek < 1 || targetWeek > semesterWeekCount) {
            throw IllegalArgumentException("target_week_out_of_range")
        }
        val location = targetLocation?.trim() ?: course.location
        val isNoop = sourceWeek == targetWeek &&
            course.dayOfWeek == targetDayOfWeek &&
            course.startSection == targetStartSection &&
            course.endSection == targetEndSection &&
            course.location == location
        if (isNoop) {
            return CourseActionOutcome.Rescheduled(courseId, sourceWeek, targetWeek, changed = false)
        }

        val remainingWeeks = course.activeWeeks.filter { it != sourceWeek }.sorted()
        if (remainingWeeks.isEmpty()) {
            // 只剩这一周：原地改位置即可（Dart 同分支的等价写法）。
            val moved = course.copy(
                dayOfWeek = targetDayOfWeek,
                startSection = targetStartSection,
                endSection = targetEndSection,
                location = location,
            )
            TimetableCourseService.update(port, moved, previousSharedName = null)
            return CourseActionOutcome.Rescheduled(courseId, sourceWeek, targetWeek, changed = true)
        }

        val shrunk = course.copy(
            startWeek = remainingWeeks.first(),
            endWeek = remainingWeeks.last(),
            isOddWeek = false,
            isEvenWeek = false,
            customWeeks = remainingWeeks,
            sessionNotes = course.sessionNotesExcludingWeek(sourceWeek),
        )
        TimetableCourseService.update(port, shrunk, previousSharedName = null)

        // 目标位置的新条目：新 id、单周、目标星期/节次；共享字段由服务侧广播。
        val moved = course.copy(
            id = UUID.randomUUID().toString(),
            dayOfWeek = targetDayOfWeek,
            startSection = targetStartSection,
            endSection = targetEndSection,
            location = location,
            startWeek = targetWeek,
            endWeek = targetWeek,
            isOddWeek = false,
            isEvenWeek = false,
            customWeeks = listOf(targetWeek),
            sessionNotes = null,
        )
        TimetableCourseService.add(port, moved)
        return CourseActionOutcome.Rescheduled(courseId, sourceWeek, targetWeek, changed = true)
    }

    /**
     * 本周停课 / 复课（Dart `_toggleCourseSuspensionImpl`，`:2336-2360`）：
     * 在 `suspendedWeeks` 里加上 / 去掉这一周；空集合写回 `null`（Dart `:2356-2358`）。
     */
    fun toggleSuspensionThisWeek(
        port: TimetableCoursePort,
        courseId: String,
        week: Int,
    ): CourseActionOutcome.SuspensionChanged {
        val course = port.getCourseById(courseId)
            ?: throw IllegalArgumentException("course_not_found_for_suspend")
        val current = course.suspendedWeeks.orEmpty()
        val nowSuspended = week !in current
        val next = if (nowSuspended) (current + week).sorted() else current.filter { it != week }
        TimetableCourseService.update(
            port,
            course.copy(suspendedWeeks = next.takeIf { it.isNotEmpty() }),
            previousSharedName = null,
        )
        return CourseActionOutcome.SuspensionChanged(courseId, nowSuspended, SuspendScope.THIS_WEEK)
    }

    /** 整门课停课（Dart `suspendAllWeeks`）：所有教学周都进 `suspendedWeeks`。 */
    fun suspendAllWeeks(
        port: TimetableCoursePort,
        courseId: String,
    ): CourseActionOutcome.SuspensionChanged {
        val course = port.getCourseById(courseId)
            ?: throw IllegalArgumentException("course_not_found_for_suspend")
        TimetableCourseService.update(
            port,
            course.copy(suspendedWeeks = course.activeWeeks.sorted()),
            previousSharedName = null,
        )
        return CourseActionOutcome.SuspensionChanged(courseId, true, SuspendScope.ALL_WEEKS)
    }

    /** 整门课复课（Dart `unsuspendAllWeeks`）：清空 `suspendedWeeks`。 */
    fun unsuspendAllWeeks(
        port: TimetableCoursePort,
        courseId: String,
    ): CourseActionOutcome.SuspensionChanged {
        val course = port.getCourseById(courseId)
            ?: throw IllegalArgumentException("course_not_found_for_suspend")
        TimetableCourseService.update(
            port,
            course.copy(suspendedWeeks = null),
            previousSharedName = null,
        )
        return CourseActionOutcome.SuspensionChanged(courseId, false, SuspendScope.ALL_WEEKS)
    }

    /**
     * 保存「课程简介」与「本节备注」（Dart `course_note_sheet.dart:149-197` 的 `_save`）。
     *
     * ## 三条口径，逐条对齐 Dart
     *
     * 1. **课程简介写共享字段 `description`**：同名课程的其它课次都读它，
     *    所以必须走 [TimetableCourseService.update] —— 它会用 `CourseDomain.applySharedFields`
     *    把共享字段广播给同名的其它条目（Dart 是 `provider.updateCourse` 的同一层语义）。
     * 2. **顺手清掉 legacy `note`**（Dart `note: null`）：两处都留着会出现
     *    「改了一处、另一处还是旧值」的双字段漂移。
     * 3. **`hasHomework` 必须保留原值**：Dart 的注释写得很清楚 —— 用户只改一句备注，
     *    那门课本周的作业标记不能被悄悄清掉（清掉之后 homeworkMark 作业下次重算会消失）。
     *    所以本节备注用 `CourseSessionNote(text = …, hasHomework = 原值).normalizedOrNull`：
     *    文本与作业标记**都空**时才写 `null`（等于删掉这一周的备注）。
     *
     * @param wholeNote 课程简介原文；`trim()` 后为空 ⇒ 写成 `null`。
     * @param sessionNoteText 本节备注原文；`trim()` 后为空且无作业 ⇒ 这一周不再有备注。
     * @return 写库后的课程（服务侧归一过的版本）。
     */
    fun saveCourseNotes(
        port: TimetableCoursePort,
        courseId: String,
        week: Int,
        wholeNote: String?,
        sessionNoteText: String?,
    ): Course {
        val course = port.getCourseById(courseId)
            ?: throw IllegalArgumentException("course_not_found_for_notes")
        val existingHomework = course.sessionNoteForWeek(week)?.hasHomework ?: false
        val sessionNote = CourseSessionNote(
            text = sessionNoteText.orEmpty().trim(),
            hasHomework = existingHomework,
        ).normalizedOrNull
        val whole = wholeNote.orEmpty().trim()
        val updated = course.copy(
            description = whole.ifEmpty { null },
            note = null,
            sessionNotes = course.withSessionNote(week, sessionNote),
        )
        TimetableCourseService.update(port, updated, previousSharedName = null)
        return port.getCourseById(courseId) ?: updated
    }

    /**
     * 「调课」入口该不该可点（Dart `canReschedule`，`course_action_sheet.dart:889-891`：
     * `onPressed: canReschedule ? … : null`）。
     *
     * 判据：这一周**本来就有**这节课。没有的话「把这一次课挪走」无从谈起——
     * Dart 是把按钮置灰，本层把这个判据公开给渲染层，免得渲染层自己写业务规则。
     */
    fun canReschedule(course: Course, week: Int): Boolean = course.isInWeek(week)

    /**
     * 单节课提醒是否应当出现在弹层里（Dart `_isAlarmAvailable`，
     * `course_action_sheet.dart:1145-1167`）：这节课要在**未来**（当天 = 开课前）、
     * 且生效作息下解析得出开始钟点。判据本体在 [ClassAlarmPlanLogic.isAvailable]
     * （纯 Kotlin，JVM 可测）；本方法只是把「日期从哪来」钉在这里——
     * 与 `dateForCourseOccurrence` 同源，不许渲染层另算一份。
     *
     * 写入走系统时钟（`SystemAlarmHelper.fireSetAlarm`，`AlarmClock.ACTION_SET_ALARM`），
     * 系统时钟 App 拥有闹钟，本应用不需要也不存在「应用内 class-alarm 调度器」
     *（Dart 侧现状同此，2026-10 迁移保留）。
     */
    fun isClassAlarmAvailable(
        courseDate: LocalDate?,
        startMinutes: Int?,
        now: LocalDateTime = LocalDateTime.now(),
    ): Boolean = ClassAlarmPlanLogic.isAvailable(
        courseDate = courseDate,
        startMinutes = startMinutes,
        now = now,
    )
}
