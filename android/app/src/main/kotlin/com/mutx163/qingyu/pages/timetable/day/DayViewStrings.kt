package com.mutx163.qingyu.pages.timetable.day

/**
 * 封装 ARB 键名与中文原文的数据结构，便于单测机械化对拍。
 */
data class ArbText(val key: String, val zh: String) {
    /** 替换模板中的单占位符（`{name}` → [value]）。 */
    fun filled(name: String, value: String): String = zh.replace("{$name}", value)

    /** 替换模板中的多个占位符。 */
    fun filled(vararg pairs: Pair<String, String>): String {
        var result = zh
        for ((name, value) in pairs) {
            result = result.replace("{$name}", value)
        }
        return result
    }
}

/**
 * 日视图 (Day View) 模块用到的全部 ARB 文案与纯格式化函数（`lib/l10n/app_zh.arb`）。
 *
 * **逐字抄录，不许改写**：每一条都在 [DayViewStringsParityTest] 里与 ARB 机械比对，
 * 键缺失或值被改写都会红。
 */
object DayViewStrings {

    // ── 顶部摘要卡与页面导航 ──
    val todayTimetableTitle = ArbText("todayTimetableTitle", "今日课表")
    val backToWeekViewAction = ArbText("backToWeekViewAction", "返回周视图")
    val weekLabel = ArbText("weekLabel", "第 {week} 周")
    val courseCountSummary = ArbText("courseCountSummary", "{count} 门课")
    val scheduleCountSummary = ArbText("scheduleCountSummary", "日程 {count} 项")
    val classStartsAtLabel = ArbText("classStartsAtLabel", "{time} 开始")
    val classEndsAtLabel = ArbText("classEndsAtLabel", "{time} 结束")
    val conflictCountLabel = ArbText("conflictCountLabel", "冲突 {count} 节")
    val nonCurrentWeekLabel = ArbText("nonCurrentWeekLabel", "非本周")
    val dayViewEmptyTitle = ArbText("dayViewEmptyTitle", "暂无课程")

    // ── 课程议程卡与状态徽标 ──
    val ongoingCourseBadge = ArbText("ongoingCourseBadge", "正在上课")
    val conflictLabel = ArbText("conflictLabel", "冲突")
    val suspendedBadgeLabel = ArbText("suspendedBadgeLabel", "停")
    val coupleTimetableLegendTogether = ArbText("coupleTimetableLegendTogether", "一起上课")
    val coupleTimetableLegendPartner = ArbText("coupleTimetableLegendPartner", "TA的课")
    val courseNoteAction = ArbText("courseNoteAction", "备注")
    val courseTaskAction = ArbText("courseTaskAction", "作业")
    val sectionRangeLabel = ArbText("sectionRangeLabel", "第 {startSection}～{endSection} 节")
    val teacherPrefix = ArbText("teacherPrefix", "教师：{value}")
    val locationPrefix = ArbText("locationPrefix", "地点：{value}")
    val unknownTeacher = ArbText("unknownTeacher", "未知教师")
    val unknownLocation = ArbText("unknownLocation", "未知地点")
    val dayAgendaInProgressStatus = ArbText("dayAgendaInProgressStatus", "进行中 · 剩余 {minutes} 分钟")
    val dayAgendaEndingSoonStatus = ArbText("dayAgendaEndingSoonStatus", "快下课了 · 剩余 {minutes} 分钟")

    // ── 日程议程卡 ──
    val scheduleBadgeLabel = ArbText("scheduleBadgeLabel", "日程")
    val crossDayBadgeLabel = ArbText("crossDayBadgeLabel", "跨日")
    val scheduleAgendaInProgressStatus = ArbText("scheduleAgendaInProgressStatus", "进行中 · 剩余 {minutes} 分钟")
    val scheduleAgendaEndingSoonStatus = ArbText("scheduleAgendaEndingSoonStatus", "即将结束 · 剩余 {minutes} 分钟")

    // ── 考试议程卡 ──
    val examBadgeLabel = ArbText("examBadgeLabel", "考试")
    val examCountdownToday = ArbText("examCountdownToday", "今天")
    val examCountdownDays = ArbText("examCountdownDays", "{days} 天后")

    // ── 待办带 ──
    val taskOverdueSection = ArbText("taskOverdueSection", "已逾期")
    val taskCompletedSection = ArbText("taskCompletedSection", "已完成")
    val taskHomeworkDefaultTitle = ArbText("taskHomeworkDefaultTitle", "课程作业")
    val dayTaskBandCountSummary = ArbText("dayTaskBandCountSummary", "作业 {count} 项")
    val dayTaskBandOverdueBadge = ArbText("dayTaskBandOverdueBadge", "逾期 {days} 天")
    val dayTaskBandOverdueMore = ArbText("dayTaskBandOverdueMore", "还有 {count} 项逾期")
    val dayTaskBandEmptyCourses = ArbText("dayTaskBandEmptyCourses", "今天没有课")
    val saveFailed = ArbText("saveFailed", "保存失败")

    // ── 星期几 ──
    val weekdayMon = ArbText("weekdayMon", "周一")
    val weekdayTue = ArbText("weekdayTue", "周二")
    val weekdayWed = ArbText("weekdayWed", "周三")
    val weekdayThu = ArbText("weekdayThu", "周四")
    val weekdayFri = ArbText("weekdayFri", "周五")
    val weekdaySat = ArbText("weekdaySat", "周六")
    val weekdaySun = ArbText("weekdaySun", "周日")

    // ── 纯函数格式化 ──

    fun weekLabel(week: Int): String = weekLabel.filled("week", week.toString())

    fun weekdayLabel(dayOfWeek: Int): String = when (dayOfWeek) {
        1 -> weekdayMon.zh
        2 -> weekdayTue.zh
        3 -> weekdayWed.zh
        4 -> weekdayThu.zh
        5 -> weekdayFri.zh
        6 -> weekdaySat.zh
        7 -> weekdaySun.zh
        else -> ""
    }

    fun courseCountSummary(count: Int): String =
        courseCountSummary.filled("count", count.toString())

    fun scheduleCountSummary(count: Int): String =
        scheduleCountSummary.filled("count", count.toString())

    fun classStartsAtLabel(time: String): String =
        classStartsAtLabel.filled("time", time)

    fun classEndsAtLabel(time: String): String =
        classEndsAtLabel.filled("time", time)

    fun conflictCountLabel(count: Int): String =
        conflictCountLabel.filled("count", count.toString())

    fun sectionRangeLabel(startSection: Int, endSection: Int): String =
        sectionRangeLabel.filled("startSection" to startSection.toString(), "endSection" to endSection.toString())

    fun teacherPrefix(value: String): String =
        teacherPrefix.filled("value", value)

    fun locationPrefix(value: String): String =
        locationPrefix.filled("value", value)

    fun dayAgendaInProgressStatus(minutes: Int): String =
        dayAgendaInProgressStatus.filled("minutes", minutes.toString())

    fun dayAgendaEndingSoonStatus(minutes: Int): String =
        dayAgendaEndingSoonStatus.filled("minutes", minutes.toString())

    fun scheduleAgendaInProgressStatus(minutes: Int): String =
        scheduleAgendaInProgressStatus.filled("minutes", minutes.toString())

    fun scheduleAgendaEndingSoonStatus(minutes: Int): String =
        scheduleAgendaEndingSoonStatus.filled("minutes", minutes.toString())

    fun examCountdownDays(days: Int): String =
        examCountdownDays.filled("days", days.toString())

    fun dayTaskBandCountSummary(count: Int): String =
        dayTaskBandCountSummary.filled("count", count.toString())

    fun dayTaskBandOverdueBadge(days: Int): String =
        dayTaskBandOverdueBadge.filled("days", days.toString())

    fun dayTaskBandOverdueMore(count: Int): String =
        dayTaskBandOverdueMore.filled("count", count.toString())

    /** 所有日视图 ARB 条目清单，用于机械化单测逐字对拍。 */
    val allTexts: List<ArbText> by lazy {
        listOf(
            todayTimetableTitle,
            backToWeekViewAction,
            weekLabel,
            courseCountSummary,
            scheduleCountSummary,
            classStartsAtLabel,
            classEndsAtLabel,
            conflictCountLabel,
            nonCurrentWeekLabel,
            dayViewEmptyTitle,
            ongoingCourseBadge,
            conflictLabel,
            suspendedBadgeLabel,
            coupleTimetableLegendTogether,
            coupleTimetableLegendPartner,
            courseNoteAction,
            courseTaskAction,
            sectionRangeLabel,
            teacherPrefix,
            locationPrefix,
            unknownTeacher,
            unknownLocation,
            dayAgendaInProgressStatus,
            dayAgendaEndingSoonStatus,
            scheduleBadgeLabel,
            crossDayBadgeLabel,
            scheduleAgendaInProgressStatus,
            scheduleAgendaEndingSoonStatus,
            examBadgeLabel,
            examCountdownToday,
            examCountdownDays,
            taskOverdueSection,
            taskCompletedSection,
            taskHomeworkDefaultTitle,
            dayTaskBandCountSummary,
            dayTaskBandOverdueBadge,
            dayTaskBandOverdueMore,
            dayTaskBandEmptyCourses,
            saveFailed,
            weekdayMon,
            weekdayTue,
            weekdayWed,
            weekdayThu,
            weekdayFri,
            weekdaySat,
            weekdaySun,
        )
    }
}
