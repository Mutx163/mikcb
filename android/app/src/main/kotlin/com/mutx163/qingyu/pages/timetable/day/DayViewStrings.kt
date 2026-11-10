package com.mutx163.qingyu.pages.timetable.day

/**
 * 封装 ARB 键名与中文原文的数据结构，便于单测机械化对拍。
 */
typealias ArbText = com.mutx163.qingyu.app.ArbText

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
    /** 底部「回今日」浮钮（Dart `timetable_back_to_today_button.dart:65`）。 */
    val backToTodayAction = ArbText("backToTodayAction", "回今日")

    /**
     * 浮钮屏上可见的**单字「今」**（ARB `timetableBackToTodayShort`）。
     *
     * 用户特意设计的形态（原话「我特意设计的，今字」）：日视图「回今日」与周视图
     * 「回本周」两颗浮钮**都**用它当可见字，胶囊里只放这一个字。
     *
     * 2026-11-09 迁移退化审计曾按「对齐发布版」把可见字改成全称（`backToTodayAction`
     * / `backToCurrentWeekAction`）并加定位图标；2026-11-10 用户报坏后回退——
     * 发布版基准让位于用户对这颗钮的设计意图。`DayViewBackToTodayFabGuardTest`
     * 钉住不许回流。
     *
     * 读屏语义**不是**它：调用点仍把完整动作（「回今日」/「回本周」）传给
     * `contentDescription`，本键只负责屏上那一个字。
     */
    val backToTodayShort = ArbText("timetableBackToTodayShort", "今")
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

    // ── 摘要卡「共同空闲」模块（Dart `timetable_screen.dart:4310-4442`）──
    //
    // 七条键**发布版就已存在**（v2.1.4.1 ARB），Compose 侧一直没人渲染 ⇒ 死键。
    // 本轮把模块补回摘要卡，这七条才第一次上屏。
    val coupleTimetableSharedFreeTitle = ArbText("coupleTimetableSharedFreeTitle", "今日共同空闲")
    val coupleTimetableSharedFreeTitleOtherDay =
        ArbText("coupleTimetableSharedFreeTitleOtherDay", "该日共同空闲")
    val coupleTimetableNoSharedFree = ArbText("coupleTimetableNoSharedFree", "今天没有共同空闲时段")
    val coupleTimetableNoSharedFreeOtherDay =
        ArbText("coupleTimetableNoSharedFreeOtherDay", "该日没有共同空闲时段")
    val coupleTimetableSharedFreeMeta = ArbText("coupleTimetableSharedFreeMeta", "共 {count} 段")
    val coupleTimetableSharedFreeMoreCount =
        ArbText("coupleTimetableSharedFreeMoreCount", "还有 {count} 段")
    val coupleTimetableSharedFreeStaleHint =
        ArbText("coupleTimetableSharedFreeStaleHint", "对方课表可能不是最新")
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

    /**
     * 考场座位号前缀（ARB `examSeatLabel` = 「座位号」）。
     *
     * Dart 用法：`exam_list_screen.dart:320 '${l10n.examSeatLabel} $seat'`。
     * 2026-10-29 二轮审核发现渲染层直接写死了「座位: 」（`DayViewExamCard.kt`），
     * 既绕过 strings 层，文案也与 ARB 不是同一句。
     */
    val examSeatLabel = ArbText("examSeatLabel", "座位号")

    /**
     * 摘要卡大字日期标题（ARB `monthViewAgendaTitle` = 「{month}月{day}日」）。
     *
     * Dart `_formatDayViewSummaryDate` 用 `DateFormat.MMMd(localeName)`，
     * 中文环境下正是「10月27日」这一形态；键复用 month 域同一条，不另拟说法。
     */
    val monthViewAgendaTitle = ArbText("monthViewAgendaTitle", "{month}月{day}日")

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

    /**
     * 摘要卡大字日期标题：「10月27日 周二」。
     *
     * 与 Dart `_formatDayViewSummaryDate`（`timetable_day_view_part.dart:585-591`）
     * 逐字同构：`DateFormat.MMMd` + 空格 + 星期名。
     */
    fun dateWithWeekday(month: Int, day: Int, dayOfWeek: Int): String {
        val datePart = monthViewAgendaTitle.filled(
            "month" to month.toString(),
            "day" to day.toString(),
        )
        val weekday = weekdayLabel(dayOfWeek)
        return if (weekday.isEmpty()) datePart else "$datePart $weekday"
    }

    /** 座位号一行：「座位号 3-12」（Dart `'${l10n.examSeatLabel} $seat'`）。 */
    fun seatLabel(seat: String): String = "${examSeatLabel.text} $seat"

    fun weekdayLabel(dayOfWeek: Int): String = when (dayOfWeek) {
        1 -> weekdayMon.text
        2 -> weekdayTue.text
        3 -> weekdayWed.text
        4 -> weekdayThu.text
        5 -> weekdayFri.text
        6 -> weekdaySat.text
        7 -> weekdaySun.text
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
            coupleTimetableSharedFreeTitle,
            coupleTimetableSharedFreeTitleOtherDay,
            coupleTimetableNoSharedFree,
            coupleTimetableNoSharedFreeOtherDay,
            coupleTimetableSharedFreeMeta,
            coupleTimetableSharedFreeMoreCount,
            coupleTimetableSharedFreeStaleHint,
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
            // 2026-10-31 审核：这两条此前**没进 allTexts** ⇒ 逐字对拍完全漏检
            //（测试只遍历 allTexts）。加进来以后与 ARB 不一致会立刻红。
            examSeatLabel,
            monthViewAgendaTitle,
            backToTodayAction,
            backToTodayShort,
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
