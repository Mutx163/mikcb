package com.mutx163.qingyu.pages.timetable.day

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.pages.timetable.TimetableDateLogic
import com.mutx163.qingyu.pages.timetable.WeekAgendaLogic
import com.mutx163.qingyu.pages.timetable.WeekGridCourseMapping
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.temporal.ChronoUnit

/**
 * 日视图「某周某天」的完整模型（模型层产物，渲染层只负责画）。
 *
 * 与渲染层 `DayViewPageData` 的分工：本类是**纯 Kotlin**（不 import 任何 Compose 类型），
 * 可以直接在 JVM 单测里跑；渲染层的 `DayViewPageData` 由 [toPageData] 一行转换。
 *
 * ## 为什么要有这一层
 *
 * 2026-10-29 二轮审核确认：日视图的三条数据通道（日程 / 考试 / 待办带）在**壳分支里
 * 从来没被构造过**，`Model` 层却已经写好了 `ScheduleEntry` / `ExamEntry` /
 * `DayTaskBandLogic.resolve`。于是「模型有、页面有、壳没接」——用户看到的是残页。
 *
 * 把装配从壳搬进模型层，壳里只剩一次调用（见报告「壳接线请求」），
 * 而且装配规则本身可以被 JVM 单测钉住（`DayViewDataAssemblerTest`）。
 */
data class DayViewDay(
    val week: Int,
    val dayOfWeek: Int,
    /** 这一天的日历日期；学期开始日未设置时为 null（Dart 同样允许 null）。 */
    val date: LocalDate?,
    val isToday: Boolean,
    val summaryState: DayViewSummaryState,
    val agendaEntries: List<DayAgendaEntry>,
    val taskBandData: DayTaskBandData?,
    /** 课程 id → 本周是否有作业（决定日课卡的作业红点）。 */
    val courseTaskPresence: Map<String, Boolean>,
    /** 议程条目 id → 该条目的天气一行（无数据/未开启时为空）。 */
    val weatherLines: Map<String, String> = emptyMap(),
)

/**
 * 日视图数据装配（唯一实现）。
 *
 * ## 与 Dart 的对应
 *
 * | 这里 | Dart |
 * |---|---|
 * | [build] 的课程筛选 | `domain/day_course_display_logic.dart:getCoursesForDay`（`:194-223`） |
 * | 日程条目 | `timetable_day_view_part.dart:_buildHomeDayDisplayItems`（`:611`） |
 * | 考试条目 | 同上 + `day_view_summary_card.dart:dayExams`（`:48`） |
 * | 待办带 | `timetable_day_view_part.dart:_buildDayTaskBand`（`:620`） |
 * | 摘要卡 | `timetable_day_view_part.dart:480-510` |
 *
 * ## 明确不复刻的两处（写在这里，免得下一个人以为是漏了）
 *
 * 1. **日程的「调课日期规则」**（`ScheduleDateRule`）：Dart 侧由 provider 的
 *    `scheduleOccurrencesForDate` 应用规则；本装配目前只用 `ScheduleItem.occursOn`
 *    （重复/例外日期），不套用整日改期规则。规则生效需要 `scheduleDateRules` 参与，
 *    属日程域，未在本轮接线。
 * 2. **情侣课表叠加**（`buildCoupleDayCourseDisplayItems`）：情侣数据不在
 *    `TimetableSnapshot` 里，属情侣域。
 */
object DayViewDataAssembler {

    /**
     * 装配某一天的日视图数据。
     *
     * @param courses 当前档案的全部课程
     * @param scheduleItems 当前档案的日程
     * @param exams 当前档案的考试
     * @param tasks 当前档案的作业
     * @param settings 课表设置（节次表、学期周数、学期开始日、非本周开关）
     * @param currentWeek 仓储当前周（判「今天」与停课/本周课）
     * @param now 注入时钟（单测用；页面传 `LocalDateTime.now()`）
     * @param showNonCurrentWeekCourses 「显示非本周课程」开关（Dart `timetableShowNonCurrentWeekCourses`）
     * @param weatherOf 可选：给某条议程取天气一行（页面把它指到 `WeatherProvider`）
     */
    fun build(
        week: Int,
        dayOfWeek: Int,
        courses: List<Course>,
        settings: TimetableSettings,
        currentWeek: Int = week,
        scheduleItems: List<ScheduleItem> = emptyList(),
        exams: List<Exam> = emptyList(),
        tasks: List<CourseTask> = emptyList(),
        now: LocalDateTime = LocalDateTime.now(),
        showNonCurrentWeekCourses: Boolean = false,
        weatherOf: ((date: LocalDate?, course: Course) -> String?)? = null,
    ): DayViewDay {
        val today = now.toLocalDate()
        val semesterStart = settings.semesterStartDate?.toLocalDate()
        val date = TimetableDateLogic.dateForWeekDay(semesterStart, week, dayOfWeek)
            ?: TimetableDateLogic.fallbackDateForViewedWeek(week = week, dayOfWeek = dayOfWeek, today = today)
        // Dart `_isSelectedDayToday`（`timetable_day_view_part.dart:326-338`）：
        // 有开学日 ⇒ 算出的日历日 == 今天；没有开学日 ⇒ 退回「同一周内、星期相同」，
        // 并且只认**当前周**（翻到别的周就不算今天）。
        val isToday = if (semesterStart != null) {
            date == today
        } else {
            dayOfWeek == today.dayOfWeek.value && week == currentWeek
        }

        // ── 课程：走模型层唯一筛选口径（含非本周开关 / 停课照常列出 / 排序 / 剪枝）──
        // 剪枝（Dart `buildDayCourseDisplayItems`）：本周有课时，被它压住的非本周课不画，
        // 否则同一个坑位会叠着两门课；这一步收敛在 `WeekGridCourseMapping.visibleDayCourses`，
        // 与周视图同一口径。
        val dayCourses = WeekGridCourseMapping.visibleDayCourses(
            dayCourses = WeekGridCourseMapping.coursesForDay(
                allCourses = courses,
                week = week,
                dayOfWeek = dayOfWeek,
                showNonCurrentWeekCourses = showNonCurrentWeekCourses,
            ),
            week = week,
        )
        val conflicts = WeekGridCourseMapping.conflictMap(courses, week)
        val currentMinutes = now.hour * 60.0 + now.minute + now.second / 60.0

        val courseEntries = dayCourses.map { course ->
            val isCurrent = course.isInWeek(week)
            DayAgendaEntry.CourseEntry(
                course = course,
                isCurrentWeekCourse = isCurrent,
                isConflicting = conflicts[course.id]?.isNotEmpty() == true,
                isCurrentCourse = isToday && DayAgendaLogic.resolveProgress(
                    startTime = course.startTime,
                    endTime = course.endTime,
                    currentMinutes = currentMinutes,
                ) != null,
            )
        }

        // ── 日程：目标日发生的条目（重复日程先物化再判跨天）──
        val scheduleEntries = run {
            val target = date.atStartOfDay()
            scheduleItems
                // Dart `ScheduleItemExpander.instancesForDate` 不按 `enabled` 过滤
                //（`schedule_item.dart:353-368` 的 `occursOn` 只看日期区间 / 例外 / 重复规则），
                // 这里跟它同一口径，避免「Dart 看得到、Compose 看不到」。
                .filter { item -> item.occursOn(target) }
                .map { item ->
                    DayAgendaLogic.scheduleEntryForDate(
                        item = item,
                        targetDate = target,
                        occurrenceId = "${item.seriesRootId}@$date",
                    )
                }
        }

        // ── 考试：同一天且未过期（Dart `dayExams` 过滤 `!isExpired`）──
        val examEntries = exams
            .filter { exam -> CourseTask.dateOnly(exam.dateTime).toLocalDate() == date }
            .filter { exam -> !isExamExpired(exam, now) }
            .sortedBy { it.startTime }
            .map { exam ->
                DayAgendaEntry.ExamEntry(
                    exam = exam,
                    linkedCourse = courses.firstOrNull { it.id == exam.courseId },
                    daysUntil = ChronoUnit.DAYS.between(today, exam.dateTime.toLocalDate()).toInt(),
                )
            }

        val agendaEntries = DayAgendaLogic.sortAgendaEntries(
            courseEntries + scheduleEntries + examEntries,
        )

        // ── 待办带 ──
        val taskBand = DayTaskBandLogic.resolve(tasks, date.atStartOfDay())
            .takeIf { it.isNotEmpty }
        val busyCourseIds = tasks
            .filter { task ->
                // Dart `tasksForCourse(courseId, sourceWeek: week)`（`timetable_course_service.dart:516-529`）：
                // 只认**来源周 == 当前查看周**的作业，且**不过滤已完成**——
                // 作业勾掉了，「这一周有作业」的角标与胶囊加粗仍然保留。
                task.sourceWeek?.toInt() == week
            }
            .mapNotNull { it.courseId }
            .toSet()
        val presence = dayCourses.associate { course -> course.id to (course.id in busyCourseIds) }

        // ── 摘要卡 ──
        val currentCourse = courseEntries.firstOrNull { it.isCurrentCourse }?.course
        val conflictCount = courseEntries.count { it.isConflicting }
        val nonCurrentCount = courseEntries.count { it.isCurrentWeekCourse.not() }
        val examSummaries = examEntries.map { entry ->
            DayExamSummary(
                id = entry.exam.id,
                name = entry.exam.name,
                daysUntil = entry.daysUntil,
                startTime = entry.exam.startTime,
            )
        }
        // Dart `day_view_summary_card.dart:122-123,275-278`：区间取**排序后首条的开始 / 末条的结束**，
        // 不是全体的 min/max（后半段有一节短的晚课时，两者会给出不同的「结束」）。
        val firstStart = agendaEntries.firstOrNull()?.startTime
        val lastEnd = agendaEntries.lastOrNull()?.endTime
        val summary = DayViewSummaryLogic.buildSummaryState(
            week = week,
            dateLabel = dateLabel(date, dayOfWeek),
            isToday = isToday,
            courseCount = courseEntries.size,
            scheduleCount = scheduleEntries.size,
            taskCount = taskBand?.actionableCount ?: 0,
            currentCourseName = currentCourse?.name,
            conflictCount = conflictCount,
            nonCurrentWeekCourseCount = nonCurrentCount,
            exams = examSummaries,
            firstStartTime = firstStart,
            lastEndTime = lastEnd,
        )

        val weatherLines = if (weatherOf == null) {
            emptyMap()
        } else {
            agendaEntries
                .filterIsInstance<DayAgendaEntry.CourseEntry>()
                .mapNotNull { entry -> weatherOf(date, entry.course)?.let { entry.id to it } }
                .toMap()
        }

        return DayViewDay(
            week = week,
            dayOfWeek = dayOfWeek,
            date = date,
            isToday = isToday,
            summaryState = summary,
            agendaEntries = agendaEntries,
            taskBandData = taskBand,
            courseTaskPresence = presence,
            weatherLines = weatherLines,
        )
    }

    /**
     * 摘要卡的大字日期标题。
     *
     * Dart `_formatDayViewSummaryDate`：`DateFormat.MMMd(localeName)` + 星期名 ⇒「10月27日 周二」；
     * 解析不出日期时只给星期（`timetable_day_view_part.dart:488-496`）。
     */
    fun dateLabel(date: LocalDate?, dayOfWeek: Int): String {
        if (date == null) return DayViewStrings.weekdayLabel(dayOfWeek)
        return DayViewStrings.dateWithWeekday(date.monthValue, date.dayOfMonth, dayOfWeek)
    }

    /** 考试是否已过期（Dart `Exam.isExpired`：结束时间早于此刻，结束钟点缺省 23:59）。 */
    fun isExamExpired(exam: Exam, now: LocalDateTime = LocalDateTime.now()): Boolean =
        WeekAgendaLogic.isExamExpired(exam, now)

    /** 分钟数 → `HH:mm`（摘要卡的议程区间文案用）。 */
    private fun clockText(minutes: Int): String =
        String.format(java.util.Locale.ROOT, "%02d:%02d", minutes / 60, minutes % 60)
}