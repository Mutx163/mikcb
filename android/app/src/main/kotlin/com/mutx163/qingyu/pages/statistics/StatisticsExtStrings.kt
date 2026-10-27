package com.mutx163.qingyu.pages.statistics

/**
 * 统计族**余量两页**用到的 ARB 文案（`lib/l10n/app_zh.arb`，模板语言 zh）。
 *
 * 为什么不并进 `StatisticsStrings.kt`：那份文件是 P3-E 前两页的已交付产物，
 * 被 `StatisticsStringsParityTest` 按条数与内容钉住了。并行开发时改它 =
 * 动别人的验收基线，本批次按台账 §8「后到者改设计避让」新建一份。
 *
 * **逐字抄录，不许改写**：每条都在 [StatisticsExtStringsParityTest] 里与 ARB 机械比对。
 * 键名与 ARB 键逐字一致，便于 `grep` 双向核对。
 */
object StatisticsExtStrings {

    // ── 空态（分析页 / 会话页共用） ──
    val statisticsNoData = ArbText("statisticsNoData", "暂无课程数据")
    val statisticsNoDataHint = ArbText("statisticsNoDataHint", "添加课程后即可查看统计")

    // ── 深度分析二级页：六个模块标题 ──
    // Dart `statistics_analysis_screen.dart:70-77` 的 `_moduleTitle` 逐字对应。
    val statisticsTrendTitle = ArbText("statisticsTrendTitle", "每周课时趋势")
    val statisticsTimeUtilTitle = ArbText("statisticsTimeUtilTitle", "时间利用")
    val statisticsVenueTitle = ArbText("statisticsVenueTitle", "教室与教学楼")
    val statisticsTeacherTitle = ArbText("statisticsTeacherTitle", "教师课时排行")
    val statisticsRankingTitle = ArbText("statisticsRankingTitle", "课程排行")
    val statisticsCompareTitle = ArbText("statisticsCompareTitle", "课表对比")

    // ── 单节课明细页 ──
    val statisticsSessionTitle = ArbText("statisticsSessionTitle", "单节课明细")
    val statisticsSessionCourseLabel = ArbText("statisticsSessionCourseLabel", "课程")
    val statisticsSessionNoCalendarHint =
        ArbText("statisticsSessionNoCalendarHint", "没设开学日期，只能按周次列出")
    val statisticsSessionCoverageTitle = ArbText("statisticsSessionCoverageTitle", "记录覆盖")
    val statisticsSessionCoverageNote = ArbText("statisticsSessionCoverageNote", "有备注")
    val statisticsSessionCoverageHomework = ArbText("statisticsSessionCoverageHomework", "有作业")
    val statisticsSessionCoverageReminder = ArbText("statisticsSessionCoverageReminder", "设过提醒")
    val statisticsSessionListTitle = ArbText("statisticsSessionListTitle", "课次列表")
    val statisticsSessionMetricSessions = ArbText("statisticsSessionMetricSessions", "课次")
    val statisticsSessionMetricDone = ArbText("statisticsSessionMetricDone", "已过")
    val statisticsSessionMetricSections = ArbText("statisticsSessionMetricSections", "课时")
    val statisticsSessionMetricNoted = ArbText("statisticsSessionMetricNoted", "有备注")
    val statisticsSessionEmpty = ArbText("statisticsSessionEmpty", "这门课没有排课")

    // ── 课次阶段标签（`session_list_card.dart:167-172`） ──
    val statisticsSessionPhaseDone = ArbText("statisticsSessionPhaseDone", "已过")
    val statisticsSessionPhaseToday = ArbText("statisticsSessionPhaseToday", "今天")
    val statisticsSessionPhaseUpcoming = ArbText("statisticsSessionPhaseUpcoming", "未到")
    val statisticsSessionPhaseSuspended = ArbText("statisticsSessionPhaseSuspended", "停课")
    val statisticsSessionPhaseHoliday = ArbText("statisticsSessionPhaseHoliday", "假期")
    val statisticsSessionPhaseUndated = ArbText("statisticsSessionPhaseUndated", "日期未定")

    /** 文案对拍用全集：新增文案必须加进这里，否则对拍测试看不见它。 */
    val allTexts: List<ArbText> = listOf(
        statisticsNoData,
        statisticsNoDataHint,
        statisticsTrendTitle,
        statisticsTimeUtilTitle,
        statisticsVenueTitle,
        statisticsTeacherTitle,
        statisticsRankingTitle,
        statisticsCompareTitle,
        statisticsSessionTitle,
        statisticsSessionCourseLabel,
        statisticsSessionNoCalendarHint,
        statisticsSessionCoverageTitle,
        statisticsSessionCoverageNote,
        statisticsSessionCoverageHomework,
        statisticsSessionCoverageReminder,
        statisticsSessionListTitle,
        statisticsSessionMetricSessions,
        statisticsSessionMetricDone,
        statisticsSessionMetricSections,
        statisticsSessionMetricNoted,
        statisticsSessionEmpty,
        statisticsSessionPhaseDone,
        statisticsSessionPhaseToday,
        statisticsSessionPhaseUpcoming,
        statisticsSessionPhaseSuspended,
        statisticsSessionPhaseHoliday,
        statisticsSessionPhaseUndated,
    )
}
