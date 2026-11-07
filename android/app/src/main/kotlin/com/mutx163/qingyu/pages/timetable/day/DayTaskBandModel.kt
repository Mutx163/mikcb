package com.mutx163.qingyu.pages.timetable.day

import com.mutx163.qingyu.core.CourseTask
import java.time.LocalDateTime
import java.time.temporal.ChronoUnit

/**
 * 待办带分档类型（对齐 `lib/domain/day_task_band_logic.dart:DayTaskBandKind`）。
 */
enum class DayTaskBandKind {
    /** 到期日已过且未完成（逾期） */
    OVERDUE,

    /** 目标日到期且未完成 */
    TODAY,

    /** 目标日到期且已完成（留在目标日，支持撤回与历史查看） */
    COMPLETED,
}

/**
 * 待办带的一行展示条目。
 */
data class DayTaskBandRow(
    val task: CourseTask,
    val kind: DayTaskBandKind,
    /** 逾期天数；非逾期档为 0 */
    val overdueDays: Int = 0,
)

/**
 * 待办带完整聚合数据：三档行列表 + 逾期折叠信息。
 */
data class DayTaskBandData(
    val overdue: List<DayTaskBandRow>,
    val today: List<DayTaskBandRow>,
    val completed: List<DayTaskBandRow>,
    /** 超出最大展示数后被折叠的逾期条数 */
    val hiddenOverdueCount: Int,
) {
    val isEmpty: Boolean get() = overdue.isEmpty() && today.isEmpty() && completed.isEmpty()
    val isNotEmpty: Boolean get() = !isEmpty

    /** 带子上实际可见的条目数（不含折叠项） */
    val visibleCount: Int get() = overdue.size + today.size + completed.size

    /**
     * 当日需行动项条数：逾期 + 今日到期未完成。
     *
     * 摘要卡胶囊的「N 项作业」用此口径，已完成的不计入。
     */
    val actionableCount: Int get() = overdue.size + today.size

    companion object {
        val EMPTY = DayTaskBandData(
            overdue = emptyList(),
            today = emptyList(),
            completed = emptyList(),
            hiddenOverdueCount = 0,
        )
    }
}

/**
 * 日视图待办带分档、过滤与稳定排序纯逻辑。
 *
 * 对齐 `lib/domain/day_task_band_logic.dart:DayTaskBandLogic`。
 */
object DayTaskBandLogic {

    /** 逾期档最多显示的条数，超出部分折叠成「还有 N 项逾期」 */
    const val MAX_OVERDUE_ROWS = 3

    /**
     * 组装指定目标日期的待办带数据。
     *
     * 取数口径：
     * 1. 无 dueDate 的任务日视图不显示。
     * 2. 已完成的任务只在它自己到期当天展示，其余日期的已完成任务不展示。
     * 3. 逾期任务：截止日早于 targetDate 且未完成。
     * 4. 今日任务：截止日等于 targetDate 且未完成。
     * 5. 未来到期任务：在当前日视图目标日不展示。
     *
     * @param tasks 全量作业列表
     * @param targetDate 日视图当页的目标日期
     */
    fun resolve(
        tasks: List<CourseTask>,
        targetDate: LocalDateTime,
    ): DayTaskBandData {
        val today = CourseTask.dateOnly(targetDate)
        val overdueRows = mutableListOf<DayTaskBandRow>()
        val todayRows = mutableListOf<DayTaskBandRow>()
        val completedRows = mutableListOf<DayTaskBandRow>()

        for (task in tasks) {
            val due = task.dueDate ?: continue
            val dueDay = CourseTask.dateOnly(due)

            if (task.isCompleted) {
                // 已完成的只在它到期当天显示一行，支持回溯与撤销
                if (dueDay == today) {
                    completedRows.add(
                        DayTaskBandRow(task = task, kind = DayTaskBandKind.COMPLETED, overdueDays = 0),
                    )
                }
                continue
            }

            if (dueDay == today) {
                todayRows.add(
                    DayTaskBandRow(task = task, kind = DayTaskBandKind.TODAY, overdueDays = 0),
                )
                continue
            }

            if (dueDay.isBefore(today)) {
                val overdueDays = ChronoUnit.DAYS.between(dueDay.toLocalDate(), today.toLocalDate()).toInt()
                overdueRows.add(
                    DayTaskBandRow(
                        task = task,
                        kind = DayTaskBandKind.OVERDUE,
                        overdueDays = overdueDays,
                    ),
                )
                continue
            }

            // dueDay 在未来：不属于当前目标日的处理范围
        }

        overdueRows.sortWith(::compareOverdue)
        todayRows.sortWith(::compareToday)
        completedRows.sortWith(::compareCompleted)

        val hiddenCount = if (overdueRows.size > MAX_OVERDUE_ROWS) {
            overdueRows.size - MAX_OVERDUE_ROWS
        } else {
            0
        }

        val visibleOverdue = if (hiddenCount > 0) {
            overdueRows.subList(0, MAX_OVERDUE_ROWS)
        } else {
            overdueRows
        }

        return DayTaskBandData(
            overdue = visibleOverdue,
            today = todayRows,
            completed = completedRows,
            hiddenOverdueCount = hiddenCount,
        )
    }

    /** 0 = 有关联课程（排前面），1 = 无关联（排后面） */
    private fun courseRank(task: CourseTask): Int =
        if (task.courseId.isNullOrBlank()) 1 else 0

    /**
     * 逾期排序：最早到期在前；同到期日有关联课程在前；最后退化至 id。
     */
    private fun compareOverdue(left: DayTaskBandRow, right: DayTaskBandRow): Int {
        val leftDue = left.task.dueDate ?: LocalDateTime.MIN
        val rightDue = right.task.dueDate ?: LocalDateTime.MIN
        val dueCompare = leftDue.compareTo(rightDue)
        if (dueCompare != 0) return dueCompare

        val courseCompare = courseRank(left.task).compareTo(courseRank(right.task))
        if (courseCompare != 0) return courseCompare

        return left.task.id.compareTo(right.task.id)
    }

    /**
     * 今日到期排序：有关联课程在前；同课程按 courseId 聚类；再按创建时间升序；最后退化至 id。
     */
    private fun compareToday(left: DayTaskBandRow, right: DayTaskBandRow): Int {
        val courseCompare = courseRank(left.task).compareTo(courseRank(right.task))
        if (courseCompare != 0) return courseCompare

        val courseIdCompare = (left.task.courseId ?: "").compareTo(right.task.courseId ?: "")
        if (courseIdCompare != 0) return courseIdCompare

        val createdCompare = left.task.createdAt.compareTo(right.task.createdAt)
        if (createdCompare != 0) return createdCompare

        return left.task.id.compareTo(right.task.id)
    }

    /**
     * 已完成排序：按创建时间升序；最后退化至 id。
     */
    private fun compareCompleted(left: DayTaskBandRow, right: DayTaskBandRow): Int {
        val createdCompare = left.task.createdAt.compareTo(right.task.createdAt)
        if (createdCompare != 0) return createdCompare

        return left.task.id.compareTo(right.task.id)
    }

    /**
     * 判断任务是否为空标题需兜底（如 homeworkMark 来源的无标题作业）。
     */
    fun needsDefaultTitle(task: CourseTask): Boolean = task.title.trim().isEmpty()

    /**
     * 解析任务在带上的展示标题（空标题兜底为 "课程作业"）。
     */
    fun resolveDisplayTitle(task: CourseTask): String =
        if (needsDefaultTitle(task)) DayViewStrings.taskHomeworkDefaultTitle.text else task.title.trim()

    /**
     * 清单页与待办带共用的「今日相关」口径：今天到期（含已完成）+ 逾期未完成。
     */
    fun isRelevantToday(task: CourseTask, today: LocalDateTime): Boolean {
        if (task.isDueOn(today)) return true
        return task.isOverdue(now = today)
    }
}
