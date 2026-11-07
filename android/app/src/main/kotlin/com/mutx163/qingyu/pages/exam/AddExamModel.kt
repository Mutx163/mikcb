package com.mutx163.qingyu.pages.exam

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.ExamReminderPreset
import com.mutx163.qingyu.core.WeekCalculator
import java.time.LocalDateTime

/**
 * 添加 / 编辑考试页模型层（纯 Kotlin，不引 Compose / Android）。
 *
 * 对应 Flutter `lib/screens/add_exam_screen.dart`（1290 行）：初始值、时间回落、
 * 保存前的五道阻断、实体组装、自定义提醒的增改去重、日期行文案、周次选日换算。
 * 渲染层只消费 [AddExamViewState] 并回调本对象的方法。
 */

/** 保存被挡住的原因（顺序即 Dart 侧校验顺序）。 */
enum class AddExamBlocker {
    NAME_REQUIRED,
    COURSE_REQUIRED,
    DATE_REQUIRED,
    END_BEFORE_START,
    CUSTOM_REMINDER_EMPTY,
}

/** 添加 / 修改一条自定义提醒的结果。 */
enum class CustomReminderStatus {
    ADDED,
    UNCHANGED,
    INVALID,
    DUPLICATE,
}

data class CustomReminderApply(
    val status: CustomReminderStatus,
    val minutes: List<Int>,
)

/** 自定义提醒选择器的三段初值。 */
data class ReminderPickerParts(
    val days: Int,
    val hours: Int,
    val minutes: Int,
)

/**
 * 表单视图状态。所有字段都是「屏上能直接看到的输入」，
 * 不做派生计算（派生一律走 [AddExamLogic]）。
 */
data class AddExamViewState(
    val isEditing: Boolean,
    val selectedCourseId: String? = null,
    val name: String = "",
    val hasSelectedDate: Boolean = false,
    /** 只取年月日，时分恒为 0。 */
    val selectedDate: LocalDateTime? = null,
    val startTime: String = "08:30",
    val endTime: String = "10:30",
    val location: String = "",
    val seatNumber: String = "",
    val note: String = "",
    val reminderPreset: ExamReminderPreset = ExamReminderPreset.DAY_1_AND_HOUR_1,
    val customReminderMinutes: List<Int> = emptyList(),
    /** 名称字段下方的错误提示（Dart 用 FormField 的 helper 显示，不是 toast）。 */
    val nameError: String? = null,
    /** 保存校验失败要弹的提示；nameError 走字段、其余走这条。 */
    val toastMessage: String? = null,
) {
    /** 选中日期（无选中为 null）。 */
    val dateOnly: LocalDateTime?
        get() = selectedDate?.let {
            LocalDateTime.of(it.year, it.monthValue, it.dayOfMonth, 0, 0)
        }
}

object AddExamLogic {

    /** 时间解析失败时的回落值（Dart `_parseTime` 的兜底）。 */
    const val FALLBACK_TIME = "08:00"

    /** 新建时默认开始 / 结束时间。 */
    const val DEFAULT_START_TIME = "08:30"
    const val DEFAULT_END_TIME = "10:30"

    /** 自定义提醒上限：30 天 23 小时 59 分。 */
    const val MAX_REMINDER_MINUTES = 30 * 1440 + 23 * 60 + 59

    /** 初始化表单（新建 = 七天后 08:30–10:30；编辑 = 读回全部字段）。 */
    fun initialState(existing: Exam?, now: LocalDateTime): AddExamViewState {
        if (existing == null) {
            val defaultDate = WeekCalculator.addDays(
                LocalDateTime.of(now.year, now.monthValue, now.dayOfMonth, 0, 0),
                7,
            )
            return AddExamViewState(
                isEditing = false,
                selectedCourseId = null,
                name = "",
                hasSelectedDate = false,
                selectedDate = defaultDate,
                startTime = DEFAULT_START_TIME,
                endTime = DEFAULT_END_TIME,
                reminderPreset = ExamReminderPreset.DAY_1_AND_HOUR_1,
                customReminderMinutes = emptyList(),
            )
        }
        return AddExamViewState(
            isEditing = true,
            selectedCourseId = existing.courseId,
            name = existing.name,
            hasSelectedDate = true,
            selectedDate = LocalDateTime.of(
                existing.dateTime.year,
                existing.dateTime.monthValue,
                existing.dateTime.dayOfMonth,
                0,
                0,
            ),
            startTime = normalizeTimeOrFallback(existing.startTime),
            endTime = normalizeTimeOrFallback(existing.endTime),
            location = existing.location ?: "",
            seatNumber = existing.seatNumber ?: "",
            note = existing.note ?: "",
            reminderPreset = existing.reminderPreset,
            customReminderMinutes = existing.customReminderMinutes.toList(),
        )
    }

    /**
     * 自由文本时间 → `HH:mm`（`add_exam_screen.dart:1108-1126`）。
     *
     * Dart 侧特意判了范围：越界值喂给 `TimeOfDay` 会在 debug 下断言崩溃
     * （表现成「点这一项没反应」），导入/旧存档里的时间属于外部字符串。
     */
    fun normalizeTimeOrFallback(value: String): String {
        val parts = value.split(":")
        if (parts.size == 2) {
            val hour = parts[0].trim().toIntOrNull()
            val minute = parts[1].trim().toIntOrNull()
            if (hour != null && minute != null && hour in 0..23 && minute in 0..59) {
                return "%02d:%02d".format(hour, minute)
            }
        }
        return FALLBACK_TIME
    }

    /** `HH:mm` → 当日分钟数；非法按 [FALLBACK_TIME] 计。 */
    fun minutesOfDay(value: String): Int {
        val normalized = normalizeTimeOrFallback(value)
        val parts = normalized.split(":")
        return parts[0].toInt() * 60 + parts[1].toInt()
    }

    /** 保存前的第一道阻断；没有阻断返回 null（`add_exam_screen.dart:1000-1041`）。 */
    fun resolveSaveBlocker(state: AddExamViewState): AddExamBlocker? {
        if (state.name.trim().isEmpty()) return AddExamBlocker.NAME_REQUIRED
        if (state.selectedCourseId.isNullOrBlank()) return AddExamBlocker.COURSE_REQUIRED
        if (!state.hasSelectedDate || state.selectedDate == null) return AddExamBlocker.DATE_REQUIRED
        if (minutesOfDay(state.endTime) <= minutesOfDay(state.startTime)) {
            return AddExamBlocker.END_BEFORE_START
        }
        if (state.reminderPreset == ExamReminderPreset.CUSTOM &&
            state.customReminderMinutes.isEmpty()
        ) {
            return AddExamBlocker.CUSTOM_REMINDER_EMPTY
        }
        return null
    }

    /** 阻断原因对应的提示文案（逐字对齐 ARB）。 */
    fun blockerMessage(blocker: AddExamBlocker): String = when (blocker) {
        AddExamBlocker.NAME_REQUIRED -> ExamStrings.examNameRequired.text
        AddExamBlocker.COURSE_REQUIRED -> ExamStrings.linkCourseRequired.text
        AddExamBlocker.DATE_REQUIRED -> ExamStrings.examDateRequired.text
        AddExamBlocker.END_BEFORE_START -> ExamStrings.examEndTimeBeforeStart.text
        AddExamBlocker.CUSTOM_REMINDER_EMPTY -> ExamStrings.examReminderCustomEmpty.text
    }

    /** 组装考试实体（`add_exam_screen.dart:1043-1071`）。调用前须已通过阻断检查。 */
    fun buildExam(
        state: AddExamViewState,
        existing: Exam?,
        newId: String,
        now: LocalDateTime,
    ): Exam {
        val date = state.dateOnly
            ?: throw IllegalArgumentException("add_exam_date_required")
        return Exam(
            id = existing?.id ?: newId,
            courseId = state.selectedCourseId?.trim().orEmpty(),
            name = state.name.trim(),
            dateTime = date,
            startTime = normalizeTimeOrFallback(state.startTime),
            endTime = normalizeTimeOrFallback(state.endTime),
            location = state.location.trim().ifEmpty { null },
            seatNumber = state.seatNumber.trim().ifEmpty { null },
            note = state.note.trim().ifEmpty { null },
            reminderPreset = state.reminderPreset,
            customReminderMinutes = state.customReminderMinutes.toList(),
            createdAt = existing?.createdAt ?: now,
            updatedAt = now,
        )
    }

    /**
     * 新增 / 修改一条自定义提醒（`add_exam_screen.dart:557-594`）。
     *
     * 四个分支的顺序与 Dart 一致：先非正数、再「改成同一个值」、再撞别的条目、最后才落列表。
     */
    fun applyCustomReminderOffset(
        current: List<Int>,
        totalMinutes: Int,
        replacingMinutes: Int?,
    ): CustomReminderApply {
        if (totalMinutes <= 0) {
            return CustomReminderApply(CustomReminderStatus.INVALID, current)
        }
        if (replacingMinutes != null && totalMinutes == replacingMinutes) {
            return CustomReminderApply(CustomReminderStatus.UNCHANGED, current)
        }
        val collides = current.any { it == totalMinutes && it != replacingMinutes }
        if (collides) {
            return CustomReminderApply(CustomReminderStatus.DUPLICATE, current)
        }
        val next = current.filter { it != replacingMinutes }.toMutableList()
        next.add(totalMinutes)
        next.sortDescending()
        return CustomReminderApply(CustomReminderStatus.ADDED, next)
    }

    /** 展示用偏移列表（远端值，与 Dart `sortedOffsets` 一致）。 */
    fun sortedOffsets(minutes: List<Int>): List<Int> = minutes.sortedDescending()

    /**
     * 日期行文案（`add_exam_screen.dart:328-367`）：
     * 未选 → 「请选择日期」；选了 → `yyyy-MM-dd`，学期内再补「 第 N 周 周X」。
     */
    fun formatDateDisplay(
        state: AddExamViewState,
        semesterStart: LocalDateTime?,
        semesterWeekCount: Int,
    ): String {
        val date = state.selectedDate
        if (!state.hasSelectedDate || date == null) return ExamStrings.examDateHint.text

        val datePart = "%04d-%02d-%02d".format(date.year, date.monthValue, date.dayOfMonth)
        if (semesterStart == null) return datePart

        val weekIndex = WeekCalculator.getWeekIndex(date, semesterStart)
        if (weekIndex == null || weekIndex < 1 || weekIndex > semesterWeekCount) {
            return datePart
        }
        val weekday = ExamStrings.weekdayLabel(date.dayOfWeek.value)
        val weekLabel = ExamStrings.weekLabel.filled("week", weekIndex.toString())
        return "$datePart $weekLabel $weekday"
    }

    /**
     * 第 [week] 周第 [dayOfWeek] 天对应的真实日期（`add_exam_screen.dart:714-728`）。
     * 以周一为每周起始，先把开学日期对齐到所在周的周一。
     */
    fun dateForWeekAndDay(
        semesterStart: LocalDateTime,
        week: Int,
        dayOfWeek: Int,
    ): LocalDateTime {
        val daysToSubtract = (semesterStart.dayOfWeek.value - 1 + 7) % 7
        val alignedStart = WeekCalculator.addDays(semesterStart, -daysToSubtract)
        val dayOffset = (dayOfWeek - 1 + 7) % 7
        return WeekCalculator.addDays(alignedStart, (week - 1) * 7 + dayOffset)
    }

    /** 周次选择器的初始周（越界 / 开学前回落第 1 周）。 */
    fun initialWeekForPicker(
        anchor: LocalDateTime?,
        semesterStart: LocalDateTime,
        totalWeeks: Int,
    ): Int {
        val target = anchor ?: LocalDateTime.now()
        val weekIndex = WeekCalculator.getWeekIndex(target, semesterStart)
        return if (weekIndex != null && weekIndex >= 1 && weekIndex <= totalWeeks) {
            weekIndex.toInt()
        } else {
            1
        }
    }

    /** 该周是不是「本周」（周次列表里的「本周」副标题）。 */
    fun isCurrentWeek(week: Int, semesterStart: LocalDateTime, now: LocalDateTime): Boolean {
        val current = WeekCalculator.getWeekIndex(now, semesterStart) ?: return false
        return current.toInt() == week
    }

    /**
     * 自定义提醒选择器初值（`add_exam_screen.dart:1207-1218`）：
     * 默认 60 分钟，先钳到 [0, MAX_REMINDER_MINUTES] 再拆三段，天封顶 30。
     */
    fun decomposeReminderTotal(initial: Int?): ReminderPickerParts {
        val raw = initial ?: 60
        val clamped = raw.coerceIn(0, MAX_REMINDER_MINUTES)
        var days = clamped / 1440
        val hours = (clamped % 1440) / 60
        val minutes = clamped % 60
        if (days > 30) days = 30
        return ReminderPickerParts(days = days, hours = hours, minutes = minutes)
    }

    /** 选择器三段合成总分钟数。 */
    fun reminderTotalMinutes(days: Int, hours: Int, minutes: Int): Int =
        days * 1440 + hours * 60 + minutes

    /** 关联课程行的副标题（`add_exam_screen.dart:234-238`）。 */
    fun courseDetailsText(selectedCourse: Course?, courseGroupsEmpty: Boolean): String {
        if (selectedCourse != null) {
            return "${selectedCourse.name} · ${selectedCourse.teacher}"
        }
        return if (courseGroupsEmpty) {
            ExamStrings.noCoursesInCurrentProfile.text
        } else {
            ExamStrings.linkCourse.text
        }
    }

    /** 考场输入框的提示（`add_exam_screen.dart:443-454`）。 */
    fun locationHint(selectedCourse: Course?): String {
        if (selectedCourse != null) {
            return "${ExamStrings.sameAsClassroom.text}: ${selectedCourse.location}"
        }
        return ExamStrings.examLocationHint.text
    }

    /** 选完课程后若名称还空着，填入默认考试名（`add_exam_screen.dart:300-302`）。 */
    fun nameAfterCoursePicked(currentName: String): String =
        if (currentName.trim().isEmpty()) ExamStrings.examDefaultName.text else currentName

    /** 提醒设置下拉的选项（枚举顺序 + 预设名）。 */
    fun reminderPresetOptions(): List<Pair<ExamReminderPreset, String>> =
        ExamReminderPreset.entries.map { it to ExamStrings.presetLabel(it) }
}
