package com.mutx163.qingyu.pages.timetable.day

/**
 * 摘要卡状态标签分类。
 */
enum class SummaryChipKind {
    /** 正在进行的课程 */
    ONGOING_COURSE,

    /** 冲突节数警告 */
    CONFLICT,

    /** 非本周课程提示 */
    NON_CURRENT_WEEK,

    /** 当日考试倒计时 */
    EXAM,
}

/**
 * 摘要卡状态小胶囊描述。
 */
data class SummaryChip(
    val kind: SummaryChipKind,
    val text: String,
)

/**
 * 摘要卡单项考试轻量模型。
 */
data class DayExamSummary(
    val id: String,
    val name: String,
    val daysUntil: Int,
    val startTime: String = "",
)

/**
 * 日视图顶部摘要卡 (Summary Card) 的整卡状态模型。
 *
 * 对齐 `lib/widgets/timetable/day_view/day_view_summary_card.dart`。
 */
data class DayViewSummaryState(
    val week: Int,
    val dateLabel: String,
    val isToday: Boolean,
    /** 主计数文案（例如 "4 门课"、"日程 2 项"、"作业 1 项" 或 "0 门课"） */
    val countLabel: String,
    /** 副日程计数文案（当既有课又有日程时非空，例如 "日程 2 项"） */
    val scheduleLabel: String?,
    /** 当日议程起止时间区间（如 "08:00 开始 · 20:30 结束"） */
    val agendaRangeLabel: String?,
    /** 状态胶囊列表（进行中、冲突、非本周、考试等） */
    val statusChips: List<SummaryChip>,
    val courseCount: Int,
    val scheduleCount: Int,
    val taskCount: Int,
) {
    val hasAgenda: Boolean get() = courseCount > 0 || scheduleCount > 0
}

/**
 * 摘要卡状态纯逻辑构建器。
 */
object DayViewSummaryLogic {

    /**
     * 解析主计数文案。
     *
     * 规则（对齐 `day_view_summary_card.dart:265-271`）：
     * - courseCount > 0 → "{count} 门课"
     * - 否则 scheduleCount > 0 → "日程 {count} 项"
     * - 否则 taskCount > 0 → "作业 {count} 项"（救助只有作业没课的日子）
     * - 否则 → "0 门课"
     */
    fun resolveCountLabel(courseCount: Int, scheduleCount: Int, taskCount: Int): String {
        return when {
            courseCount > 0 -> DayViewStrings.courseCountSummary(courseCount)
            scheduleCount > 0 -> DayViewStrings.scheduleCountSummary(scheduleCount)
            taskCount > 0 -> DayViewStrings.dayTaskBandCountSummary(taskCount)
            else -> DayViewStrings.courseCountSummary(0)
        }
    }

    /**
     * 解析副日程计数文案（仅在同时有课且有日程时显示）。
     */
    fun resolveScheduleLabel(courseCount: Int, scheduleCount: Int): String? {
        return if (scheduleCount > 0 && courseCount > 0) {
            DayViewStrings.scheduleCountSummary(scheduleCount)
        } else {
            null
        }
    }

    /**
     * 解析当日议程起止钟点区间（"{first} 开始 · {last} 结束"）。
     */
    fun resolveAgendaRangeLabel(firstStartTime: String?, lastEndTime: String?): String? {
        if (firstStartTime.isNullOrBlank() || lastEndTime.isNullOrBlank()) {
            return null
        }
        return "${DayViewStrings.classStartsAtLabel(firstStartTime)} · ${DayViewStrings.classEndsAtLabel(lastEndTime)}"
    }

    /**
     * 构建状态胶囊列表。
     */
    fun buildStatusChips(
        currentCourseName: String? = null,
        conflictCount: Int = 0,
        nonCurrentWeekCourseCount: Int = 0,
        exams: List<DayExamSummary> = emptyList(),
    ): List<SummaryChip> {
        val chips = mutableListOf<SummaryChip>()

        if (!currentCourseName.isNullOrBlank()) {
            chips.add(
                SummaryChip(
                    kind = SummaryChipKind.ONGOING_COURSE,
                    text = "${DayViewStrings.ongoingCourseBadge.zh} · $currentCourseName",
                ),
            )
        }

        if (conflictCount > 0) {
            chips.add(
                SummaryChip(
                    kind = SummaryChipKind.CONFLICT,
                    text = DayViewStrings.conflictCountLabel(conflictCount),
                ),
            )
        }

        if (nonCurrentWeekCourseCount > 0) {
            chips.add(
                SummaryChip(
                    kind = SummaryChipKind.NON_CURRENT_WEEK,
                    text = "${DayViewStrings.nonCurrentWeekLabel.zh} ${DayViewStrings.courseCountSummary(nonCurrentWeekCourseCount)}",
                ),
            )
        }

        for (exam in exams) {
            val countdownText = if (exam.daysUntil == 0) {
                DayViewStrings.examCountdownToday.zh
            } else {
                DayViewStrings.examCountdownDays(exam.daysUntil)
            }
            chips.add(
                SummaryChip(
                    kind = SummaryChipKind.EXAM,
                    text = "${exam.name} · $countdownText",
                ),
            )
        }

        return chips
    }

    /**
     * 构建完整的摘要卡状态模型。
     */
    fun buildSummaryState(
        week: Int,
        dateLabel: String,
        isToday: Boolean,
        courseCount: Int,
        scheduleCount: Int,
        taskCount: Int = 0,
        currentCourseName: String? = null,
        conflictCount: Int = 0,
        nonCurrentWeekCourseCount: Int = 0,
        exams: List<DayExamSummary> = emptyList(),
        firstStartTime: String? = null,
        lastEndTime: String? = null,
    ): DayViewSummaryState {
        val countLabel = resolveCountLabel(courseCount, scheduleCount, taskCount)
        val scheduleLabel = resolveScheduleLabel(courseCount, scheduleCount)
        val rangeLabel = resolveAgendaRangeLabel(firstStartTime, lastEndTime)
        val chips = buildStatusChips(
            currentCourseName = currentCourseName,
            conflictCount = conflictCount,
            nonCurrentWeekCourseCount = nonCurrentWeekCourseCount,
            exams = exams,
        )

        return DayViewSummaryState(
            week = week,
            dateLabel = dateLabel,
            isToday = isToday,
            countLabel = countLabel,
            scheduleLabel = scheduleLabel,
            agendaRangeLabel = rangeLabel,
            statusChips = chips,
            courseCount = courseCount,
            scheduleCount = scheduleCount,
            taskCount = taskCount,
        )
    }
}
