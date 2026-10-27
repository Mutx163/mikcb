package com.mutx163.qingyu.pages.timetable.day

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.ScheduleItem
import java.time.LocalDateTime
import java.time.temporal.ChronoUnit
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.max

/**
 * 日视图多源议程条目密封类（课程 / 日程 / 考试三选一）。
 *
 * 对齐 `lib/widgets/timetable/timetable_day_agenda_models.dart:TimetableDayAgendaItem`。
 */
sealed class DayAgendaEntry {
    abstract val id: String
    abstract val startTime: String
    abstract val endTime: String

    val startMinutes: Int? get() = DayAgendaLogic.parseClockMinutes(startTime)
    val endMinutes: Int? get() = DayAgendaLogic.parseClockMinutes(endTime)

    /** 课程议程项 */
    data class CourseEntry(
        val course: Course,
        val isCurrentWeekCourse: Boolean = true,
        val isConflicting: Boolean = false,
        val isCurrentCourse: Boolean = false,
        val isPartnerCourse: Boolean = false,
        override val startTime: String = course.startTime,
        override val endTime: String = course.endTime,
        override val id: String = course.id,
    ) : DayAgendaEntry()

    /** 日程议程项（含跨天按 00:00 / 23:59 剪裁与实例标识） */
    data class ScheduleEntry(
        val scheduleItem: ScheduleItem,
        val occurrenceDate: LocalDateTime? = null,
        val occurrenceId: String? = null,
        val continuesFromPreviousDay: Boolean = false,
        val continuesToNextDay: Boolean = false,
        override val startTime: String = if (continuesFromPreviousDay) "00:00" else scheduleItem.startTime,
        override val endTime: String = if (continuesToNextDay) "23:59" else scheduleItem.endTime,
        override val id: String = occurrenceId ?: scheduleItem.id,
    ) : DayAgendaEntry()

    /** 考试议程项 */
    data class ExamEntry(
        val exam: Exam,
        val linkedCourse: Course? = null,
        val daysUntil: Int = 0,
        override val startTime: String = exam.startTime,
        override val endTime: String = exam.endTime,
        override val id: String = exam.id,
    ) : DayAgendaEntry()
}

/**
 * 议程卡进行中状态与进度信息。
 */
data class DayAgendaProgress(
    val rawProgress: Double,
    val quantizedProgress: Double,
    val remainingMinutes: Int,
    val isEndingSoon: Boolean,
)

/**
 * 日视图议程排序、进度量化与钟点解析纯逻辑。
 *
 * 参照 `lib/domain/clock_order.dart`、`lib/domain/day_agenda_progress.dart` 及
 * `lib/screens/timetable_day_view_part.dart:403-424`。
 */
object DayAgendaLogic {

    /** 进度量化档位数（250 档避免每秒重烤玻璃材质掉帧）。 */
    const val PROGRESS_QUANTIZE_STEPS = 250

    /**
     * 将钟表时间串（"HH:mm" 或 "H:m"）解析为相对当天 00:00 的分钟数。
     *
     * @param time 钟点串（如 "08:30"、"9:00"、"24:00"）
     * @param allowEndOfDay 是否允许 "24:00"（换算为 1440 分钟，表示当天结束）
     * @return 分钟数，非法格式返回 null
     */
    fun parseClockMinutes(time: String?, allowEndOfDay: Boolean = true): Int? {
        val text = time?.trim().orEmpty()
        if (text.isEmpty()) return null

        val parts = text.split(':')
        if (parts.size != 2) return null

        val hour = parts[0].trim().toIntOrNull() ?: return null
        val minute = parts[1].trim().toIntOrNull() ?: return null

        if (minute !in 0..59) return null

        if (allowEndOfDay && hour == 24 && minute == 0) {
            return 24 * 60
        }

        if (hour !in 0..23) return null

        return hour * 60 + minute
    }

    /**
     * 按钟表分钟数比较两个钟点文本，而不是字典序。
     *
     * 避免外来或用户数据中 "9:00" 在字典序下排在 "10:00" 之后。
     * 对齐 `lib/domain/clock_order.dart:compareClockText`：
     * 解析不出来的值排在能解析的值之后；两个都解析不出来时退回字典序。
     */
    fun compareClockText(left: String?, right: String?): Int {
        val a = parseClockMinutes(left, allowEndOfDay = true)
        val b = parseClockMinutes(right, allowEndOfDay = true)

        if (a == null && b == null) {
            return (left.orEmpty()).compareTo(right.orEmpty())
        }
        if (a == null) return 1
        if (b == null) return -1
        return a.compareTo(b)
    }

    /**
     * 进度量化：将 0..1 原始比值折算成 250 档，并 clamp 到 [0.02, 0.98]。
     *
     * 对齐 `lib/domain/day_agenda_progress.dart:quantizeDayAgendaProgress`。
     */
    fun quantizeProgress(raw: Double): Double {
        val stepped = floor(raw * PROGRESS_QUANTIZE_STEPS) / PROGRESS_QUANTIZE_STEPS
        return stepped.coerceIn(0.02, 0.98)
    }

    /**
     * 计算分钟进度比例（0.0 .. 1.0）。
     *
     * 若不在区间内（未开始或已结束），或结束小于等于开始，返回 null。
     */
    fun computeProgressRatio(startMinutes: Int, endMinutes: Int, currentMinutes: Double): Double? {
        if (endMinutes <= startMinutes) return null
        if (currentMinutes < startMinutes || currentMinutes >= endMinutes) return null

        val elapsed = currentMinutes - startMinutes
        val total = endMinutes - startMinutes
        return elapsed / total
    }

    /**
     * 计算剩余分钟数（向上取整，结束时为 0）。
     */
    fun computeRemainingMinutes(endMinutes: Int, currentMinutes: Double): Int {
        if (currentMinutes >= endMinutes) return 0
        return max(0, ceil(endMinutes - currentMinutes).toInt())
    }

    /**
     * 根据钟点串与当前分钟数计算进行中状态与进度。
     */
    fun resolveProgress(startTime: String, endTime: String, currentMinutes: Double): DayAgendaProgress? {
        val start = parseClockMinutes(startTime) ?: return null
        val end = parseClockMinutes(endTime) ?: return null
        val ratio = computeProgressRatio(start, end, currentMinutes) ?: return null
        val remaining = computeRemainingMinutes(end, currentMinutes)
        val quantized = quantizeProgress(ratio)
        return DayAgendaProgress(
            rawProgress = ratio,
            quantizedProgress = quantized,
            remainingMinutes = remaining,
            isEndingSoon = remaining <= 10,
        )
    }

    /**
     * 根据绝对时间计算跨天日程等进度的重载函数。
     */
    fun resolveProgress(start: LocalDateTime, end: LocalDateTime, now: LocalDateTime): DayAgendaProgress? {
        if (!end.isAfter(start)) return null
        if (now.isBefore(start) || !now.isBefore(end)) return null

        val elapsedMillis = ChronoUnit.MILLIS.between(start, now).toDouble()
        val totalMillis = ChronoUnit.MILLIS.between(start, end).toDouble()
        if (totalMillis <= 0.0) return null

        val raw = (elapsedMillis / totalMillis).coerceIn(0.0, 1.0)
        val remainingSeconds = ChronoUnit.SECONDS.between(now, end)
        val remainingMinutes = max(0, ((remainingSeconds + 59) / 60).toInt())
        val quantized = quantizeProgress(raw)

        return DayAgendaProgress(
            rawProgress = raw,
            quantizedProgress = quantized,
            remainingMinutes = remainingMinutes,
            isEndingSoon = remainingMinutes <= 10,
        )
    }

    /**
     * 当日多源议程条目比较器（课程 + 日程 + 考试）。
     *
     * 排序规则（对齐 `timetable_day_view_part.dart:403-424`）：
     * 1. 开始时间升序（compareClockText）
     * 2. 结束时间升序（compareClockText）
     * 3. 类型权重升序（Course=0, Schedule=1, Exam=2）
     * 4. id 字典序升序（保证稳定全序）
     */
    fun compareAgendaEntries(left: DayAgendaEntry, right: DayAgendaEntry): Int {
        val startCompare = compareClockText(left.startTime, right.startTime)
        if (startCompare != 0) return startCompare

        val endCompare = compareClockText(left.endTime, right.endTime)
        if (endCompare != 0) return endCompare

        val leftType = when (left) {
            is DayAgendaEntry.CourseEntry -> 0
            is DayAgendaEntry.ScheduleEntry -> 1
            is DayAgendaEntry.ExamEntry -> 2
        }
        val rightType = when (right) {
            is DayAgendaEntry.CourseEntry -> 0
            is DayAgendaEntry.ScheduleEntry -> 1
            is DayAgendaEntry.ExamEntry -> 2
        }
        if (leftType != rightType) return leftType.compareTo(rightType)

        return left.id.compareTo(right.id)
    }

    /**
     * 将议程条目列表按日视图口径稳定排序。
     */
    fun sortAgendaEntries(entries: List<DayAgendaEntry>): List<DayAgendaEntry> =
        entries.sortedWith(::compareAgendaEntries)

    /**
     * 将一个日程条目转换为目标日期的议程条目（处理跨天 00:00/23:59 剪裁）。
     *
     * ## 重复日程必须先「物化」再判跨天
     *
     * 对齐 Dart `ScheduleItemInstance.materializedItem`
     * （`lib/models/schedule_item.dart:82-87`）：
     * ```dart
     * ScheduleItem get materializedItem {
     *   if (!item.isRecurring) return item;
     *   return item.copyWith(startDate: date, endDate: date);
     * }
     * ```
     * 重复日程的 `startDate` / `endDate` 只是**系列锚点**，不是这一次发生的区间；
     * 不物化就会把「锚定 2026-09-01 的每周日程」在 2026-10-27 判成
     * `startDate < 目标日`，于是起点被剪成 00:00、终点被剪成 23:59，
     * 界面显示「全天」而不是 09:00-10:00。
     */
    fun scheduleEntryForDate(
        item: ScheduleItem,
        targetDate: LocalDateTime,
        occurrenceId: String? = null,
    ): DayAgendaEntry.ScheduleEntry {
        val targetDay = CourseTask.dateOnly(targetDate)
        // 重复日程：单次发生的起止日期就是目标日，故不参与跨天判定。
        // 非重复日程：起止日期一律按**日历日**比较（Dart 侧 _normalizeDate 在构造时
        // 就把 startDate/endDate 归一成日期，Kotlin 这里在比较处归一，两种写法都稳）。
        val effectiveStart = if (item.isRecurring) targetDay else CourseTask.dateOnly(item.startDate)
        val effectiveEnd = if (item.isRecurring) targetDay else CourseTask.dateOnly(item.endDate)
        val continuesPrev = effectiveStart.isBefore(targetDay)
        val continuesNext = effectiveEnd.isAfter(targetDay)

        return DayAgendaEntry.ScheduleEntry(
            scheduleItem = item,
            occurrenceDate = targetDate,
            occurrenceId = occurrenceId,
            continuesFromPreviousDay = continuesPrev,
            continuesToNextDay = continuesNext,
            startTime = if (continuesPrev) "00:00" else item.startTime,
            endTime = if (continuesNext) "23:59" else item.endTime,
        )
    }

    /**
     * 判定日程是否跨天。
     */
    fun isCrossDaySchedule(item: ScheduleItem): Boolean =
        item.endDate.toLocalDate().isAfter(item.startDate.toLocalDate())
}
