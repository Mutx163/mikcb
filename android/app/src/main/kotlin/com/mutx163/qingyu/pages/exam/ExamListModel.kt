package com.mutx163.qingyu.pages.exam

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.ExamReminderPreset
import com.mutx163.qingyu.core.WeekCalculator
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * 考试列表页模型层（纯 Kotlin，不引任何 Compose / Android 类型）。
 *
 * 对应 Flutter `lib/screens/exam_list_screen.dart`（718 行）：
 * - 拆分「未结束 / 已结束」两段并各自排序（:24-28）
 * - 日期串「第 N 周 · 10月27日 周二」（:117-145）
 * - 进行中 / 考前 / 已结束三态（:212-236）
 * - 提醒摘要：预设名，或自定义偏移折叠成「A · B · +N」（:238-273）
 * - 概览卡与列表行的全部可见文案（:276-717）
 *
 * 页面上不做任何计算：渲染层只消费 [ExamListViewState]。
 */

/** 考试相对当前时刻的阶段（`exam_list_screen.dart:_ExamLivePhase`）。 */
enum class ExamLivePhase {
    BEFORE,
    ONGOING,
    AFTER,
}

/** 概览卡（最近一场未结束考试）。 */
data class ExamOverviewView(
    val exam: Exam,
    /** 「考试进行中」/「今天有考试」/「距离考试还有 N 天」/「已结束」。 */
    val statusLabel: String,
    /** 状态用主题色强调（进行中或今天）。 */
    val isEmphasized: Boolean,
    val isLive: Boolean,
    /** 名称去空白；空名回落「考试名称」。 */
    val name: String,
    /** 大号时间行：进行中显示「至 {end}」，否则显示时间区间。 */
    val bigTimeText: String,
    /** 副行时间区间（进行中时补一行完整区间）。 */
    val timeRangeText: String,
    /** 日期 · 考场 · 座位号，两空格夹中点；无内容为 null。 */
    val metaText: String?,
    val reminderEnabled: Boolean,
    /** 「已设提醒  ·  x」或「未设提醒」。 */
    val reminderText: String,
    /** 距考试天数，只在「未开始 / 非今天」时有值（用于右下角倒计时）。 */
    val countdownDays: Int?,
    /** 右上角场次统计：「今日 N 场」优先，其次「共 N 场」，都没有为 null。 */
    val trailingCountText: String?,
)

/** 列表行。 */
data class ExamRowView(
    val exam: Exam,
    /** 关联课程名；无课程为 null。 */
    val courseName: String?,
    /** 课程色 hex；无课程为 null（渲染用默认蓝）。 */
    val accentColorHex: String?,
    val isPast: Boolean,
    val isLive: Boolean,
    val dateLabel: String,
    val timeRangeText: String,
    /** 考场 · 座位号 · 教师，中点连接；无内容为 null。 */
    val metaText: String?,
    /** 提醒摘要；已结束或没设提醒为 null。 */
    val reminderText: String?,
    /** 右上角徽标：「进行中」/「今天」/「N 天后」；不显示为 null。 */
    val countdownBadge: String?,
)

/** 整页视图状态。 */
data class ExamListViewState(
    val isEmpty: Boolean,
    val emptyTitle: String,
    /** 最近一场未结束考试；空列表为 null。 */
    val overview: ExamOverviewView?,
    /** 未结束，按开始时刻正序。 */
    val upcoming: List<ExamRowView>,
    /** 已结束，按开始时刻倒序。 */
    val past: List<ExamRowView>,
    /** 未结束的考试里在今天的有几场。 */
    val todayCount: Int,
)

object ExamListLogic {

    /** 考试是否已过期（`exam.dart:308-324`：now 严格晚于结束时刻）。 */
    fun isExpired(exam: Exam, now: LocalDateTime): Boolean {
        val end = examEndDateTime(exam)
        return now.isAfter(end)
    }

    /** 距离考试还有多少天（按日历日，`exam.dart:326-336`）。 */
    fun daysUntil(exam: Exam, now: LocalDateTime): Int {
        val today = LocalDate.of(now.year, now.monthValue, now.dayOfMonth)
        val examDate = LocalDate.of(exam.dateTime.year, exam.dateTime.monthValue, exam.dateTime.dayOfMonth)
        return java.time.temporal.ChronoUnit.DAYS.between(today, examDate).toInt()
    }

    /** 考试结束的墙上时刻（endTime 解析失败按当天 23:59）。 */
    fun examEndDateTime(exam: Exam): LocalDateTime {
        val (hour, minute) = Exam.parseTimeOfDayParts(
            exam.endTime,
            fallbackHour = 23,
            fallbackMinute = 59,
        )
        return LocalDateTime.of(
            exam.dateTime.year,
            exam.dateTime.monthValue,
            exam.dateTime.dayOfMonth,
            hour,
            minute,
        )
    }

    /** 相对当前时刻的阶段（`exam_list_screen.dart:214-236`）。 */
    fun resolveLivePhase(exam: Exam, now: LocalDateTime): ExamLivePhase {
        if (now.isBefore(exam.examStartDateTime)) return ExamLivePhase.BEFORE
        val end = examEndDateTime(exam)
        if (now.isBefore(end) || now.isEqual(end)) return ExamLivePhase.ONGOING
        return ExamLivePhase.AFTER
    }

    /**
     * 日期展示串（`exam_list_screen.dart:117-145`）：
     * 有开学日期且周次 ≥ 1 时前置「第 N 周 · 」，末尾恒带星期名。
     */
    fun formatExamDate(exam: Exam, semesterStart: LocalDateTime?): String {
        val date = exam.dateTime
        val weekday = ExamStrings.weekdayLabel(date.dayOfWeek.value)
        val datePart = "${date.monthValue}月${date.dayOfMonth}日"

        var weekInfo = ""
        if (semesterStart != null) {
            val weekIndex = WeekCalculator.getWeekIndex(date, semesterStart)
            if (weekIndex != null && weekIndex >= 1) {
                weekInfo = ExamStrings.weekLabel.filled("week", weekIndex.toString()) + " · "
            }
        }

        return "$weekInfo$datePart $weekday"
    }

    /**
     * 单个提醒偏移的可读文案（`exam_list_screen.dart:255-273`）。
     *
     * 整天的倍数只说天、整小时的倍数只说小时；其余按「天 + 小时 + 分钟」拆开，
     * 用「 + 」连接（Dart 侧就是 `parts.join(' + ')`，每段都带完整「考前」前缀）。
     */
    fun reminderOffsetLabel(minutes: Int): String {
        if (minutes > 0 && minutes % 1440 == 0) {
            return ExamStrings.examReminderOffsetDays.filled("days", (minutes / 1440).toString())
        }
        if (minutes > 0 && minutes % 60 == 0) {
            return ExamStrings.examReminderOffsetHours.filled("hours", (minutes / 60).toString())
        }
        val days = minutes / 1440
        val hours = (minutes % 1440) / 60
        val remainMinutes = minutes % 60
        if (days > 0 || hours > 0) {
            val parts = mutableListOf<String>()
            if (days > 0) parts.add(ExamStrings.examReminderOffsetDays.filled("days", days.toString()))
            if (hours > 0) parts.add(ExamStrings.examReminderOffsetHours.filled("hours", hours.toString()))
            if (remainMinutes > 0) {
                parts.add(ExamStrings.examReminderOffsetMinutes.filled("minutes", remainMinutes.toString()))
            }
            return parts.joinToString(" + ")
        }
        return ExamStrings.examReminderOffsetMinutes.filled("minutes", minutes.toString())
    }

    /**
     * 提醒摘要（`exam_list_screen.dart:238-253`）：
     * 没提醒 → 「未设提醒」；非自定义预设 → 预设名本身；
     * 自定义 → 最多列两条偏移，多出来的折叠成「+N」，中点连接。
     */
    fun reminderSummary(exam: Exam): String {
        val minutes = exam.effectiveReminderMinutes
        if (minutes.isEmpty()) return ExamStrings.examOverviewReminderOff.zh
        if (exam.reminderPreset != ExamReminderPreset.CUSTOM) {
            return ExamStrings.presetLabel(exam.reminderPreset)
        }
        val labels = minutes.take(2).map { reminderOffsetLabel(it) }.toMutableList()
        if (minutes.size > 2) {
            labels.add("+${minutes.size - 2}")
        }
        return labels.joinToString(" · ")
    }

    /** 组装整页视图状态。 */
    fun buildListViewState(
        exams: List<Exam>,
        courses: List<Course>,
        semesterStart: LocalDateTime?,
        now: LocalDateTime,
    ): ExamListViewState {
        val coursesById = courses.associateBy { it.id }
        val upcomingExams = exams.filter { !isExpired(it, now) }
            .sortedWith { left, right -> compareByStart(left, right) }
        // Dart: `sort((a, b) => Exam.compareByStart(b, a))` —— 倒序看最近结束的
        val pastExams = exams.filter { isExpired(it, now) }
            .sortedWith { left, right -> compareByStart(left, right) }
            .reversed()
        val todayCount = upcomingExams.count { daysUntil(it, now) == 0 }

        val upcomingRows = upcomingExams.map { exam ->
            buildRow(
                exam = exam,
                course = coursesById[exam.courseId],
                isPast = false,
                dateLabel = formatExamDate(exam, semesterStart),
                now = now,
            )
        }
        val pastRows = pastExams.map { exam ->
            buildRow(
                exam = exam,
                course = coursesById[exam.courseId],
                isPast = true,
                dateLabel = formatExamDate(exam, semesterStart),
                now = now,
            )
        }

        val overview = upcomingExams.firstOrNull()?.let { first ->
            buildOverview(
                exam = first,
                todayCount = todayCount,
                upcomingCount = upcomingExams.size,
                dateLabel = formatExamDate(first, semesterStart),
                now = now,
            )
        }

        return ExamListViewState(
            isEmpty = exams.isEmpty(),
            emptyTitle = ExamStrings.noExams.zh,
            overview = overview,
            upcoming = upcomingRows,
            past = pastRows,
            todayCount = todayCount,
        )
    }

    /** 组装概览卡（`exam_list_screen.dart:276-483`）。 */
    fun buildOverview(
        exam: Exam,
        todayCount: Int,
        upcomingCount: Int,
        dateLabel: String,
        now: LocalDateTime,
    ): ExamOverviewView {
        val daysUntil = daysUntil(exam, now)
        val livePhase = resolveLivePhase(exam, now)
        val isToday = daysUntil == 0
        val isLive = livePhase == ExamLivePhase.ONGOING

        val statusLabel = when {
            isLive -> ExamStrings.examOverviewInProgress.zh
            livePhase == ExamLivePhase.BEFORE && isToday -> ExamStrings.examToday.zh
            livePhase == ExamLivePhase.BEFORE ->
                ExamStrings.daysUntilExam.filled("days", daysUntil.toString())
            else -> ExamStrings.examPassed.zh
        }

        val name = exam.name.trim().ifEmpty { ExamStrings.examNameLabel.zh }
        val timeRange = ExamStrings.examTimeRange.filled("start" to exam.startTime, "end" to exam.endTime)
        val location = exam.location?.trim()
        val seat = exam.seatNumber?.trim()

        val secondaryBits = mutableListOf<String>()
        secondaryBits.add(dateLabel)
        if (!location.isNullOrEmpty()) secondaryBits.add(location)
        if (!seat.isNullOrEmpty()) {
            secondaryBits.add("${ExamStrings.examSeatLabel.zh} $seat")
        }

        val reminderEnabled = exam.effectiveReminderMinutes.isNotEmpty()
        val reminderLabel = reminderSummary(exam)

        val trailingCountText = when {
            todayCount > 0 -> ExamStrings.examOverviewTodayCount.filled("count", todayCount.toString())
            upcomingCount > 1 -> ExamStrings.examOverviewUpcomingCount.filled("count", upcomingCount.toString())
            else -> null
        }

        return ExamOverviewView(
            exam = exam,
            statusLabel = statusLabel,
            isEmphasized = isLive || isToday,
            isLive = isLive,
            name = name,
            bigTimeText = if (isLive) {
                ExamStrings.examOverviewUntilTime.filled("time", exam.endTime)
            } else {
                timeRange
            },
            timeRangeText = timeRange,
            metaText = secondaryBits.joinToString("  ·  ").ifEmpty { null },
            reminderEnabled = reminderEnabled,
            reminderText = if (reminderEnabled) {
                "${ExamStrings.examOverviewReminderOn.zh}  ·  $reminderLabel"
            } else {
                ExamStrings.examOverviewReminderOff.zh
            },
            countdownDays = if (!isLive && !isToday && daysUntil > 0) daysUntil else null,
            trailingCountText = trailingCountText,
        )
    }

    /** 组装列表行（`exam_list_screen.dart:530-717`）。 */
    fun buildRow(
        exam: Exam,
        course: Course?,
        isPast: Boolean,
        dateLabel: String,
        now: LocalDateTime,
    ): ExamRowView {
        val livePhase = if (isPast) ExamLivePhase.AFTER else resolveLivePhase(exam, now)
        val daysUntil = daysUntil(exam, now)

        val examLocation = exam.location?.trim()
        val location = if (!examLocation.isNullOrEmpty()) examLocation else course?.location?.trim()
        val seat = exam.seatNumber?.trim()
        val teacher = course?.teacher?.trim()

        val metaParts = mutableListOf<String>()
        if (!location.isNullOrEmpty()) metaParts.add(location)
        if (!seat.isNullOrEmpty()) metaParts.add("${ExamStrings.examSeatLabel.zh} $seat")
        if (!teacher.isNullOrEmpty()) metaParts.add(teacher)

        val countdownBadge = if (!isPast) {
            when {
                livePhase == ExamLivePhase.ONGOING -> ExamStrings.examOverviewLiveBadge.zh
                livePhase == ExamLivePhase.BEFORE && daysUntil == 0 -> ExamStrings.examCountdownToday.zh
                livePhase == ExamLivePhase.BEFORE ->
                    ExamStrings.examCountdownDays.filled("days", daysUntil.toString())
                else -> null
            }
        } else {
            null
        }

        val showReminder = !isPast && exam.effectiveReminderMinutes.isNotEmpty()

        return ExamRowView(
            exam = exam,
            courseName = course?.name,
            accentColorHex = course?.color,
            isPast = isPast,
            isLive = livePhase == ExamLivePhase.ONGOING,
            dateLabel = dateLabel,
            timeRangeText = ExamStrings.examTimeRange.filled("start" to exam.startTime, "end" to exam.endTime),
            metaText = metaParts.joinToString(" · ").ifEmpty { null },
            reminderText = if (showReminder) reminderSummary(exam) else null,
            countdownBadge = countdownBadge,
        )
    }

    /** 与 `Exam.compareByStart` 同口径（开始时刻 → 结束时刻 → id）。 */
    fun compareByStart(left: Exam, right: Exam): Int = Exam.compareByStart(left, right)
}
