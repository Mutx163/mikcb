package com.mutx163.qingyu.core

import java.time.LocalDateTime
import java.util.Locale

/**
 * 单节课统计（移植自 lib/domain/course_session_stats.dart，纯逻辑无 IO）。
 *
 * 口径（必须与课表显示一致，否则同一份数据两处对不上）：
 * - 课次 = 课程每一个有效周（isInWeek 口径：含单双周/自定义周次）；
 *   停课周仍列出，但标 [CourseSessionPhase.SUSPENDED]，不计入计划；
 * - 日期只有一条来源：周次 + 星期几 → WeekCalculator（与提醒/导出同源）；
 *   没设开学日期就返回 null，UI 明说「按周次列出」；
 * - 节假日判定由调用方注入（[CourseSessionStatsCalculator.build] 的 isHoliday）。
 */

/** 单次课的阶段判定（course_session_stats.dart:12-30）。 */
enum class CourseSessionPhase {
    /** 已过（结束于今天之前）。 */
    DONE,

    /** 就是今天。 */
    TODAY,

    /** 还没到。 */
    UPCOMING,

    /** 该周停课（suspendedWeeks），不算缺勤也不算已上。 */
    SUSPENDED,

    /** 当天是假期，课表本就不显示。 */
    HOLIDAY,

    /** 没设开学日期，无法锚定到具体某天。 */
    UNDATED,
}

/** 一次具体的课（某门课 × 某一周的那一次）——推导值，不落盘（:36-91）。 */
data class CourseSession(
    val courseId: String,
    val week: Int,
    /** 真实日期；未设开学日期时为 null。 */
    val date: LocalDateTime?,
    val dayOfWeek: Int,
    val startSection: Int,
    val endSection: Int,
    /** 生效作息下的真实钟点（可能为 null：作息模板缺该节）。 */
    val startTime: String?,
    val endTime: String?,
    val location: String,
    val phase: CourseSessionPhase,
    /** 这次课的备注原文（按周保存的 sessionNotes）。 */
    val noteText: String?,
    val hasHomework: Boolean,
    val taskCount: Int,
    val examCount: Int,
    /** 这次课（按真实日期）是否设过单节课提醒。 */
    val hasReminder: Boolean,
) {
    val sectionCount: Int get() = endSection - startSection + 1

    val hasNote: Boolean get() = noteText != null && noteText.trim().isNotEmpty()

    /** 是否算「上过了」：只有确定日期且已过去的正常课。 */
    val isPast: Boolean get() = phase == CourseSessionPhase.DONE

    /**
     * 是否计入「计划/覆盖」口径：停课与假期不算（用户没上课，
     * 那次课有没有备注都不该摊进「记录覆盖率」）。
     */
    val isPlanned: Boolean
        get() = phase != CourseSessionPhase.SUSPENDED && phase != CourseSessionPhase.HOLIDAY
}

/** 「单节课」维度的汇总（:94-156）。 */
data class CourseSessionStats(
    val courseName: String,
    val teacher: String,
    /** 全部课次（含停课、假期），按日期/周次排好序。 */
    val sessions: List<CourseSession>,
    /** 计入统计的排课次数（不含停课与假期）。 */
    val plannedSessions: Int,
    /** 是否有真实日期轴（= 设了开学日期）。 */
    val hasCalendar: Boolean,
) {
    val isEmpty: Boolean get() = sessions.isEmpty()

    fun countOf(phase: CourseSessionPhase): Int = sessions.count { it.phase == phase }

    val doneSessions: Int get() = countOf(CourseSessionPhase.DONE)
    val todaySessions: Int get() = countOf(CourseSessionPhase.TODAY)
    val upcomingSessions: Int get() = countOf(CourseSessionPhase.UPCOMING)
    val suspendedSessions: Int get() = countOf(CourseSessionPhase.SUSPENDED)
    val holidaySessions: Int get() = countOf(CourseSessionPhase.HOLIDAY)
    val undatedSessions: Int get() = countOf(CourseSessionPhase.UNDATED)

    /**
     * 已有备注的课次数（分母与 sessions.size 同口径）。
     *
     * 覆盖类统计的分子分母都必须是「全部列出的课次」：停课周不清备注，
     * 「停课周有备注」真实存在。若分母用 plannedSessions 能构造出「3/1」的
     * 自相矛盾；全部课次口径下天然对齐。
     */
    val notedSessions: Int get() = sessions.count { it.hasNote }

    /** 标了「有作业」（含挂了该课该周的作业条目）的课次数。 */
    val homeworkSessions: Int get() = sessions.count { it.hasHomework }

    /** 设过单节课提醒的课次数。 */
    val reminderSessions: Int get() = sessions.count { it.hasReminder }

    /** 已上课时（节）。 */
    val doneSections: Int
        get() = sessions.filter { it.isPast }.sumOf { it.sectionCount }

    /**
     * 计划总课时（节，不含停课与假期）。
     *
     * 必须与 doneSections 同一算法——逐课次累加。不能写成
     * 「每周节数 × plannedSessions」：plannedSessions 按「条目 × 周」计数，
     * 一门课一周两次排课（2+3 节）× 16 周时该式得 5×32=160，实际 5×16=80。
     */
    val plannedSections: Int
        get() = sessions.filter { it.isPlanned }.sumOf { it.sectionCount }
}

/** 单节课统计的计算入口（:167-324）。 */
object CourseSessionStatsCalculator {

    fun build(
        courseName: String,
        courses: List<Course>,
        settings: TimetableSettings,
        tasks: List<CourseTask> = emptyList(),
        exams: List<Exam> = emptyList(),
        now: LocalDateTime,
        isHoliday: ((LocalDateTime) -> Boolean)? = null,
        startTimeResolver: ((Course) -> String?)? = null,
        endTimeResolver: ((Course) -> String?)? = null,
        /** 已设置的单节课提醒键集合，格式 `courseId|yyyy-MM-dd`。 */
        reminderKeys: Set<String> = emptySet(),
    ): CourseSessionStats {
        val semesterStart = settings.semesterStartDate
        val today = LocalDateTime.of(now.year, now.monthValue, now.dayOfMonth, 0, 0)

        // 预分组：任务按「课程|周次」、考试按「课程|日期」各数一遍，
        // 避免在每个 session 上全表扫（O(课次 × 任务数) → O(任务数)）。
        val taskCounts = HashMap<String, Int>()
        for (task in tasks) {
            val week = task.sourceWeek
            val course = task.courseId
            if (course == null || week == null) continue
            val key = "$course|$week"
            taskCounts[key] = (taskCounts[key] ?: 0) + 1
        }
        val examCounts = HashMap<String, Int>()
        for (exam in exams) {
            val dateTime = exam.dateTime
            val key = "${exam.courseId}|${formatDate(dateTime)}"
            examCounts[key] = (examCounts[key] ?: 0) + 1
        }

        val sessions = mutableListOf<CourseSession>()

        for (course in courses) {
            // 每门课只解析一次的量：备注表（normalizedSessionNotesMap 每次重建整个
            // Map）与生效钟点。
            val notes = course.normalizedSessionNotesMap
            val startTime = startTimeResolver?.invoke(course) ?: course.startTime
            val endTime = endTimeResolver?.invoke(course) ?: course.endTime
            for (week in candidateWeeks(course)) {
                val date = courseOccurrenceDate(semesterStart, course, week)
                val suspended = course.isSuspendedInWeek(week)
                val dateKey = date?.let { formatDate(it) }
                val note = notes?.get(week)
                val taskCount = taskCounts["${course.id}|$week"] ?: 0
                val examCount = if (dateKey == null) 0 else examCounts["${course.id}|$dateKey"] ?: 0

                sessions.add(
                    CourseSession(
                        courseId = course.id,
                        week = week,
                        date = date,
                        dayOfWeek = course.dayOfWeek,
                        startSection = course.startSection,
                        endSection = course.endSection,
                        startTime = startTime,
                        endTime = endTime,
                        location = course.location,
                        phase = resolvePhase(
                            suspended = suspended,
                            date = date,
                            today = today,
                            holiday = date != null && (isHoliday?.invoke(date) ?: false),
                        ),
                        noteText = note?.trimmedText,
                        hasHomework = (note?.hasHomework ?: false) || taskCount > 0,
                        taskCount = taskCount,
                        examCount = examCount,
                        hasReminder = dateKey != null && reminderKeys.contains("${course.id}|$dateKey"),
                    ),
                )
            }
        }

        sessions.sortWith { left, right -> compareSessions(left, right) }

        val planned = sessions.count { it.isPlanned }

        return CourseSessionStats(
            courseName = courseName,
            teacher = if (courses.isEmpty()) "" else courses.first().teacher,
            sessions = sessions,
            plannedSessions = planned,
            hasCalendar = semesterStart != null,
        )
    }

    /** 该课程的所有「排课周」：含停课周，排除单双周不匹配的那些（:273-285）。 */
    private fun candidateWeeks(course: Course): List<Int> {
        val custom = course.normalizedCustomWeeks
        if (custom != null) {
            return ArrayList(custom)
        }
        val weeks = mutableListOf<Int>()
        for (week in course.startWeek..course.endWeek) {
            if (course.isInWeek(week)) {
                weeks.add(week)
            }
        }
        return weeks
    }

    /** 阶段优先级（:287-299）：停课 > 无日期 > 假期 > done/today/upcoming。 */
    private fun resolvePhase(
        suspended: Boolean,
        date: LocalDateTime?,
        today: LocalDateTime,
        holiday: Boolean,
    ): CourseSessionPhase = when {
        suspended -> CourseSessionPhase.SUSPENDED
        date == null -> CourseSessionPhase.UNDATED
        holiday -> CourseSessionPhase.HOLIDAY
        date.isBefore(today) -> CourseSessionPhase.DONE
        date == today -> CourseSessionPhase.TODAY
        else -> CourseSessionPhase.UPCOMING
    }

    /** 有日期的按日期排；没日期的排在后面按周次排（:302-318）。 */
    private fun compareSessions(left: CourseSession, right: CourseSession): Int {
        val leftDate = left.date
        val rightDate = right.date
        if (leftDate != null && rightDate != null) {
            val byDate = leftDate.compareTo(rightDate)
            if (byDate != 0) return byDate
        } else if (leftDate != null) {
            return -1
        } else if (rightDate != null) {
            return 1
        }
        val byWeek = left.week.compareTo(right.week)
        if (byWeek != 0) return byWeek
        val byDay = left.dayOfWeek.compareTo(right.dayOfWeek)
        if (byDay != 0) return byDay
        return left.startSection.compareTo(right.startSection)
    }

    private fun formatDate(date: LocalDateTime): String =
        String.format(Locale.ROOT, "%04d-%02d-%02d", date.year, date.monthValue, date.dayOfMonth)
}

/**
 * 课次 → 真实日期的**唯一规则**（:332-345）：
 * 学期首周的周一 + (周-1)×7 + (星期-1)。
 *
 * 与 TimetableCourseService.courseOccurrenceDate 同一算法；两处若分叉，
 * 单节课统计的日期会与提醒、课表对不上。
 */
fun courseOccurrenceDate(
    semesterStart: LocalDateTime?,
    course: Course,
    week: Int,
): LocalDateTime? {
    if (semesterStart == null || week < 1) return null
    val startOfSemesterWeek = WeekCalculator.startOfWeek(semesterStart)
    return WeekCalculator.addDays(
        startOfSemesterWeek,
        (week - 1) * 7 + course.dayOfWeek - 1,
    )
}
