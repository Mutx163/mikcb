package com.mutx163.qingyu.pages.statistics.charts

/**
 * 统计族**图表层**用到的 ARB 文案（`lib/l10n/app_zh.arb`，模板语言 zh）。
 *
 * 与 `pages/statistics/StatisticsStrings.kt` 同口径：**逐字抄录，不许改写**。
 * 每一条都在 [ChartsStringsParityTest] 里与 ARB 机械比对，键缺失或值被改写都会红。
 * 要改界面文字，先改 ARB（六份同步）+ 重新生成 `gen-l10n`，再同步这里。
 *
 * 为什么图表层单独一份而不复用 `StatisticsStrings`：
 * 本模块（`pages/statistics/charts`）要能独立跑 L0 轻量单测——`test-kotlin-module.ps1`
 * 只把 `pages/<模块>` 与本模块目录放进 classpath，兄弟目录 `pages/statistics` 不在其中。
 * 自带一份让「模型层 + 文案对拍 + 咬合探针」在 0.2 秒内闭合，不被别的泳道半成品阻断。
 */
typealias ChartText = com.mutx163.qingyu.app.ArbText

object ChartsStrings {

    // ── 图表标题 / 轴标 ──
    val statisticsTrendTitle = ChartText("statisticsTrendTitle", "每周课时趋势")
    val statisticsTrendTooltip = ChartText("statisticsTrendTooltip", "第 {week} 周 · {sections} 节")
    val statisticsDailyDistribution = ChartText("statisticsDailyDistribution", "每日课时分布")
    val statisticsHeatmapTitle = ChartText("statisticsHeatmapTitle", "学期热力图")
    val statisticsHeatmapHint = ChartText("statisticsHeatmapHint", "颜色越深，课时越多")

    // ── 通用单位 / 空态 ──
    val statisticsNoData = ChartText("statisticsNoData", "暂无课程数据")
    val statisticsSectionsUnit = ChartText("statisticsSectionsUnit", "节")
    val statisticsSectionUnit = ChartText("statisticsSectionUnit", "节")
    val statisticsWeekSelector = ChartText("statisticsWeekSelector", "第 {week} 周")
    val statisticsWeekCurrentHint = ChartText("statisticsWeekCurrentHint", "本周")

    // ── 课程排行 ──
    val statisticsRankingTitle = ChartText("statisticsRankingTitle", "课程排行")

    // ── 课表对比 ──
    val statisticsCompareTitle = ChartText("statisticsCompareTitle", "课表对比")
    val statisticsCompareActive = ChartText("statisticsCompareActive", "当前课表")
    val statisticsCompareDelta = ChartText("statisticsCompareDelta", "较当前 {delta} 节")
    val statisticsRankingSlotDetail = ChartText("statisticsRankingSlotDetail", "{day} 第 {startSection}～{endSection} 节")
    val statisticsCourseList = ChartText("statisticsCourseList", "课程列表")
    val editCourseTitle = ChartText("editCourseTitle", "编辑课程")
    val sectionRangeLabel = ChartText("sectionRangeLabel", "第 {startSection}～{endSection} 节")

    /** 课次列表里"当天有考试"的角标（`app_zh.arb` 里确有这一条，不是新造文案）。 */
    val examBadgeLabel = ChartText("examBadgeLabel", "考试")

    // ── 必修 / 选修 ──
    val statisticsNatureRatio = ChartText("statisticsNatureRatio", "必修 / 选修")
    val courseNatureRequired = ChartText("courseNatureRequired", "必修")
    val courseNatureElective = ChartText("courseNatureElective", "选修")
    val statisticsNatureLegendDetail = ChartText("statisticsNatureLegendDetail", "{count} 门 · {sections} 节")
    val statisticsNatureNoneRequired = ChartText("statisticsNatureNoneRequired", "暂无必修")
    val statisticsNatureNoneElective = ChartText("statisticsNatureNoneElective", "暂无选修")

    // ── 本周小结 ──
    val statisticsComparisonTitle = ChartText("statisticsComparisonTitle", "本周小结")
    val statisticsSectionCount = ChartText("statisticsSectionCount", "本周课时")
    val statisticsComparisonLastWeek = ChartText("statisticsComparisonLastWeek", "上周课时")
    val statisticsComparisonAverage = ChartText("statisticsComparisonAverage", "学期周均")
    val statisticsComparisonVsLastWeek = ChartText("statisticsComparisonVsLastWeek", "较上周 {delta} 节")
    val statisticsComparisonVsAverage = ChartText("statisticsComparisonVsAverage", "较周均 {delta} 节")
    val statisticsComparisonNew = ChartText("statisticsComparisonNew", "新学期第一周")

    // ── 学期进度 ──
    val statisticsSemesterProgressTitle = ChartText("statisticsSemesterProgressTitle", "学期进度")
    val statisticsSemesterProgressRange = ChartText("statisticsSemesterProgressRange", "学期 {start} - {end}")
    val statisticsSemesterProgressAsOf = ChartText("statisticsSemesterProgressAsOf", "今天 {date}")
    val statisticsSemesterProgressDetail =
        ChartText("statisticsSemesterProgressDetail", "截至第 {week} 周，已上 {done} 节 / 共 {total} 节")
    val statisticsSemesterProgressRemaining = ChartText("statisticsSemesterProgressRemaining", "剩余 {count} 节")
    val statisticsSemesterProgressNotStarted = ChartText("statisticsSemesterProgressNotStarted", "还未开学，尚未上课")
    val statisticsSemesterProgressEstimated = ChartText("statisticsSemesterProgressEstimated", "按周估算")

    // ── 时间利用 ──
    val statisticsTimeUtilTitle = ChartText("statisticsTimeUtilTitle", "时间利用")
    val statisticsTimeEarliest = ChartText("statisticsTimeEarliest", "最早课")
    val statisticsTimeLatest = ChartText("statisticsTimeLatest", "最晚课")
    val statisticsTimeMorning = ChartText("statisticsTimeMorning", "早间课时")
    val statisticsTimeNoon = ChartText("statisticsTimeNoon", "午间课时")
    val statisticsTimeEvening = ChartText("statisticsTimeEvening", "晚间课时")
    val statisticsTimeWeekend = ChartText("statisticsTimeWeekend", "周末课时")
    val statisticsTimeGap = ChartText("statisticsTimeGap", "最长课间空档")
    val statisticsTimeGapValue = ChartText("statisticsTimeGapValue", "{sections} 节")

    // ── 教室与教学楼 ──
    val statisticsVenueTitle = ChartText("statisticsVenueTitle", "教室与教学楼")
    val statisticsVenueTopRooms = ChartText("statisticsVenueTopRooms", "常去教室")
    val statisticsVenueBuildings = ChartText("statisticsVenueBuildings", "教学楼课时")
    val statisticsVenueVisits = ChartText("statisticsVenueVisits", "{count} 次")

    // ── 教师课时排行 ──
    val statisticsTeacherTitle = ChartText("statisticsTeacherTitle", "教师课时排行")
    val statisticsTeacherCourseCount = ChartText("statisticsTeacherCourseCount", "{count} 门课")

    // ── 总览 ──
    val statisticsOverview = ChartText("statisticsOverview", "本周概览")
    val statisticsCourseCount = ChartText("statisticsCourseCount", "课程门数")
    val statisticsWeeklyCourses = ChartText("statisticsWeeklyCourses", "本周课程")
    val statisticsSemesterLabelCourses = ChartText("statisticsSemesterLabelCourses", "门课程")
    val statisticsSemesterLabelSections = ChartText("statisticsSemesterLabelSections", "节课")
    val statisticsSemesterLabelWeeks = ChartText("statisticsSemesterLabelWeeks", "周")
    val statisticsSemesterLabelDayStreak = ChartText("statisticsSemesterLabelDayStreak", "天连续")

    // ── 成就徽章 ──
    val statisticsAchievementsTitle = ChartText("statisticsAchievementsTitle", "成就徽章")
    val statisticsAchievementProgress = ChartText("statisticsAchievementProgress", "{current}/{target}")
    val statisticsAchievementDone = ChartText("statisticsAchievementDone", "已达成")
    val statisticsAchievementLocked = ChartText("statisticsAchievementLocked", "未达成")
    val statisticsAchievementDetailConfirm = ChartText("statisticsAchievementDetailConfirm", "知道了")

    // ── 数据故事 ──
    val statisticsStoriesTitle = ChartText("statisticsStoriesTitle", "数据故事")
    val storyBusiestDayTitle = ChartText("statisticsStoryBusiestDayTitle", "最忙的一天")
    val storyBusiestDayContent = ChartText(
        "statisticsStoryBusiestDayContent",
        "截至第 {week} 周，这学期你最忙的一天是 **{day}**，平均 **{avg}** 节课",
    )
    val storyLightestDayTitle = ChartText("statisticsStoryLightestDayTitle", "最轻松的一天")
    val storyLightestDayContent = ChartText(
        "statisticsStoryLightestDayContent",
        "截至第 {week} 周，你最轻松的一天是 **{day}**，只有 **{avg}** 节课",
    )
    val storyFavoriteRoomTitle = ChartText("statisticsStoryFavoriteRoomTitle", "最常去的教室")
    val storyFavoriteRoomContent = ChartText(
        "statisticsStoryFavoriteRoomContent",
        "截至第 {week} 周，你最常去的教室是 **{room}**，共去了 **{count}** 次",
    )
    val storyBuildingCountTitle = ChartText("statisticsStoryBuildingCountTitle", "教学楼探险")
    val storyBuildingCountContent = ChartText(
        "statisticsStoryBuildingCountContent",
        "截至第 {week} 周，你的课程分布在 **{count}** 栋不同的教学楼",
    )
    val storyTimeRangeTitle = ChartText("statisticsStoryTimeRangeTitle", "时间跨度")
    val storyTimeRangeContent = ChartText(
        "statisticsStoryTimeRangeContent",
        "你最早的课是 **{earliest}**，最晚的课是 **{latest}**",
    )

    // ── 单节课明细（session_*_card） ──
    val statisticsSessionTitle = ChartText("statisticsSessionTitle", "单节课明细")
    val statisticsSessionEmpty = ChartText("statisticsSessionEmpty", "这门课没有排课")
    val statisticsSessionMetricSessions = ChartText("statisticsSessionMetricSessions", "课次")
    val statisticsSessionMetricSections = ChartText("statisticsSessionMetricSections", "课时")
    val statisticsSessionMetricNoted = ChartText("statisticsSessionMetricNoted", "有备注")
    val statisticsSessionMetricDone = ChartText("statisticsSessionMetricDone", "已过")
    val statisticsSessionCoverageReminder = ChartText("statisticsSessionCoverageReminder", "设过提醒")
    val statisticsSessionCoverageNote = ChartText("statisticsSessionCoverageNote", "有备注")
    val statisticsSessionCoverageHomework = ChartText("statisticsSessionCoverageHomework", "有作业")
    val statisticsSessionPhaseUpcoming = ChartText("statisticsSessionPhaseUpcoming", "未到")
    val statisticsSessionPhaseUndated = ChartText("statisticsSessionPhaseUndated", "日期未定")
    val statisticsSessionPhaseToday = ChartText("statisticsSessionPhaseToday", "今天")
    val statisticsSessionPhaseSuspended = ChartText("statisticsSessionPhaseSuspended", "停课")
    val statisticsSessionPhaseHoliday = ChartText("statisticsSessionPhaseHoliday", "假期")
    val statisticsSessionPhaseDone = ChartText("statisticsSessionPhaseDone", "已过")

    // ── 导出 ──
    val statisticsExportTitle = ChartText("statisticsExportTitle", "导出统计")
    val statisticsExportAction = ChartText("statisticsExportAction", "开始导出")
    val statisticsExportSelectModuleHint = ChartText("statisticsExportSelectModuleHint", "请至少选择一个模块")
    val statisticsExportModulesSection = ChartText("statisticsExportModulesSection", "包含模块")
    val statisticsExportModuleOverview = ChartText("statisticsExportModuleOverview", "学期总览")
    val statisticsExportRankingMore = ChartText("statisticsExportRankingMore", "另有 {count} 门课程未展示")
    val statisticsExportBrandTagline = ChartText("statisticsExportBrandTagline", "把课程信息做成系统体验")
    val statisticsShareTitle = ChartText("statisticsShareTitle", "我的学期统计")

    /**
     * 成果图发不出去时的提示（ARB `serviceMsgStatisticsShareFailed`：`分享失败：{detail}`）。
     *
     * 2026-11-05 审核修复：Compose 分享「图发不出 → 降级纯文本」此前是无声的，用户
     * 点的是分享图、收到的是文字面板。发布版三种失败都弹
     * `showAppToast(localizeServiceMessage('statistics_share_failed', detail))`
     * （`statistics_share_service.dart:78-117`），这里补齐同一条提示；`{detail}` 填
     * 降级原因的机器短码（`rasterize_failed` 等，与 Dart 的 `capture_empty` 同性质的
     * 自由文本位，不参与对拍）。降级本身保留：有产物（文本）比没有强。
     */
    val serviceMsgStatisticsShareFailed =
        ChartText("serviceMsgStatisticsShareFailed", "分享失败：{detail}")

    /**
     * 分享正文（ARB `statisticsShareText`：`来自轻屿课表的学期统计`）。
     *
     * Dart 分享的是「图片 + 这段正文」（`statistics_share_service.dart:104-108`）。
     * Compose 侧目前只做**文本分享**（说明见 `StatisticsShareText`），正文就用这一句，
     * 不另造文案。
     */
    val statisticsShareText = ChartText("statisticsShareText", "来自轻屿课表的学期统计")
    val timetableAppName = ChartText("timetableAppName", "轻屿课表")

    // ── 星期名（图表轴 / 排行详情 / 故事正文） ──
    val weekdayMon = ChartText("weekdayMon", "周一")
    val weekdayTue = ChartText("weekdayTue", "周二")
    val weekdayWed = ChartText("weekdayWed", "周三")
    val weekdayThu = ChartText("weekdayThu", "周四")
    val weekdayFri = ChartText("weekdayFri", "周五")
    val weekdaySat = ChartText("weekdaySat", "周六")
    val weekdaySun = ChartText("weekdaySun", "周日")

    val weekdayShortMonday = ChartText("weekdayShortMonday", "一")
    val weekdayShortTuesday = ChartText("weekdayShortTuesday", "二")
    val weekdayShortWednesday = ChartText("weekdayShortWednesday", "三")
    val weekdayShortThursday = ChartText("weekdayShortThursday", "四")
    val weekdayShortFriday = ChartText("weekdayShortFriday", "五")
    val weekdayShortSaturday = ChartText("weekdayShortSaturday", "六")
    val weekdayShortSunday = ChartText("weekdayShortSunday", "日")

    /** 星期全名（周一~周日，越界回退到数字字符串，对齐 Dart `_weekdayFullLabel`）。 */
    fun weekdayFull(dayOfWeek: Int): String = when (dayOfWeek) {
        1 -> weekdayMon.text
        2 -> weekdayTue.text
        3 -> weekdayWed.text
        4 -> weekdayThu.text
        5 -> weekdayFri.text
        6 -> weekdaySat.text
        7 -> weekdaySun.text
        else -> dayOfWeek.toString()
    }

    /** 星期短名（一~日，图表横轴，越界返回空串，对齐 Dart `_weekdayShortLabel`）。 */
    fun weekdayShort(dayOfWeek: Int): String = when (dayOfWeek) {
        1 -> weekdayShortMonday.text
        2 -> weekdayShortTuesday.text
        3 -> weekdayShortWednesday.text
        4 -> weekdayShortThursday.text
        5 -> weekdayShortFriday.text
        6 -> weekdayShortSaturday.text
        7 -> weekdayShortSunday.text
        else -> ""
    }

    /**
     * 成就 id → 名称（Dart `achievement_badge.dart` 的 `_nameOf` 同口径）。
     *
     * 未知 id 原样返回（不抛不崩），与 `StatisticsStrings.achievementName` 一致。
     */
    fun achievementName(id: String): String = when (id) {
        "early_bird" -> "早八战士"
        "perfect_attendance" -> "全勤达人"
        "weekend_warrior" -> "周末战士"
        "class_king" -> "课王"
        "scholar" -> "学霸"
        "balanced" -> "均衡大师"
        "night_owl" -> "夜猫子"
        "explorer" -> "教室探索家"
        "full_day_king" -> "满课日之王"
        "building_hopper" -> "跨楼达人"
        "morning_person" -> "早起鸟"
        "gap_master" -> "时间管理大师"
        else -> id
    }

    /** 成就 id → 解锁条件说明（点开徽章时展示；未知 id 返回空串）。 */
    fun achievementDetail(id: String): String = when (id) {
        "early_bird" -> "解锁条件：课表中有 08:00 或更早开始的课程。"
        "perfect_attendance" -> "解锁条件：至少一门课程在学期内每周均有课，无停课或跳周。"
        "weekend_warrior" -> "解锁条件：周六或周日有课。"
        "class_king" -> "解锁条件：某一天排课达到 6 节及以上。"
        "scholar" -> "解锁条件：学期累计课时达到 100 节。"
        "balanced" -> "解锁条件：每天课时差距不超过 2 节，课表安排均衡。"
        "night_owl" -> "解锁条件：有 18:00 以后才结束的课。"
        "explorer" -> "解锁条件：使用过 5 个及以上不同的教室。"
        "full_day_king" -> "解锁条件：某一天排课达到 8 节及以上，全天满课。"
        "building_hopper" -> "解锁条件：同一天内去过 3 栋及以上不同的教学楼。"
        "morning_person" -> "解锁条件：12:00 前的课程节数占总节数一半以上。"
        "gap_master" -> "解锁条件：每天课间最长空档不超过 2 节，时间安排紧凑。"
        else -> ""
    }

    /** 成就 id → 一句话描述（徽章下方的灰字）。 */
    fun achievementDescription(id: String): String = when (id) {
        "early_bird" -> "有 8:00 的课，真棒"
        "perfect_attendance" -> "某门课每周都有"
        "weekend_warrior" -> "周末有课"
        "class_king" -> "某天 ≥ 6 节课"
        "scholar" -> "总课时 ≥ 100"
        "balanced" -> "每天课时差距 ≤ 2"
        "night_owl" -> "有 18:00 以后的课"
        "explorer" -> "使用过 ≥ 5 个不同教室"
        "full_day_king" -> "单日 ≥ 8 节课"
        "building_hopper" -> "单日跨 ≥ 3 栋教学楼"
        "morning_person" -> "早间课时占比 ≥ 50%"
        "gap_master" -> "最长课间空档 ≤ 2 节"
        else -> ""
    }

    /**
     * 界面上会出现的全部 [ChartText]（ParityTest 遍历用）。
     *
     * 新增文案时**必须**登记在这里，否则对拍测试覆盖不到——这是一条刻意的
     * 「漏登记就红不了」的自我约束：条数下限断言会兜住漏登记的一部分，但新增
     * 之后跑一次对拍仍是最稳的做法。
     */
    val allTexts: List<ChartText> = listOf(
        statisticsTrendTitle, statisticsTrendTooltip, statisticsDailyDistribution,
        statisticsHeatmapTitle, statisticsHeatmapHint,
        statisticsNoData, statisticsSectionsUnit, statisticsSectionUnit,
        statisticsWeekSelector, statisticsWeekCurrentHint,
        statisticsRankingTitle, statisticsRankingSlotDetail, statisticsCourseList,
        editCourseTitle, sectionRangeLabel, examBadgeLabel,
        statisticsCompareTitle, statisticsCompareActive, statisticsCompareDelta,
        statisticsNatureRatio, courseNatureRequired, courseNatureElective,
        statisticsNatureLegendDetail, statisticsNatureNoneRequired, statisticsNatureNoneElective,
        statisticsComparisonTitle, statisticsSectionCount, statisticsComparisonLastWeek,
        statisticsComparisonAverage, statisticsComparisonVsLastWeek,
        statisticsComparisonVsAverage, statisticsComparisonNew,
        statisticsSemesterProgressTitle, statisticsSemesterProgressRange,
        statisticsSemesterProgressAsOf, statisticsSemesterProgressDetail,
        statisticsSemesterProgressRemaining, statisticsSemesterProgressNotStarted,
        statisticsSemesterProgressEstimated,
        statisticsTimeUtilTitle, statisticsTimeEarliest, statisticsTimeLatest,
        statisticsTimeMorning, statisticsTimeNoon, statisticsTimeEvening,
        statisticsTimeWeekend, statisticsTimeGap, statisticsTimeGapValue,
        statisticsVenueTitle, statisticsVenueTopRooms, statisticsVenueBuildings,
        statisticsVenueVisits,
        statisticsTeacherTitle, statisticsTeacherCourseCount,
        statisticsOverview, statisticsCourseCount, statisticsWeeklyCourses,
        statisticsSemesterLabelCourses, statisticsSemesterLabelSections,
        statisticsSemesterLabelWeeks, statisticsSemesterLabelDayStreak,
        statisticsAchievementsTitle, statisticsAchievementProgress,
        statisticsAchievementDone, statisticsAchievementLocked,
        statisticsAchievementDetailConfirm,
        statisticsStoriesTitle, storyBusiestDayTitle, storyBusiestDayContent,
        storyLightestDayTitle, storyLightestDayContent, storyFavoriteRoomTitle,
        storyFavoriteRoomContent, storyBuildingCountTitle, storyBuildingCountContent,
        storyTimeRangeTitle, storyTimeRangeContent,
        statisticsSessionTitle, statisticsSessionEmpty, statisticsSessionMetricSessions,
        statisticsSessionMetricSections, statisticsSessionMetricNoted,
        statisticsSessionMetricDone, statisticsSessionCoverageReminder,
        statisticsSessionCoverageNote, statisticsSessionCoverageHomework,
        statisticsSessionPhaseUpcoming, statisticsSessionPhaseUndated,
        statisticsSessionPhaseToday, statisticsSessionPhaseSuspended,
        statisticsSessionPhaseHoliday, statisticsSessionPhaseDone,
        statisticsExportTitle, statisticsExportAction, statisticsExportSelectModuleHint,
        statisticsExportModulesSection, statisticsExportModuleOverview,
        statisticsExportRankingMore, statisticsExportBrandTagline,
        statisticsShareTitle, statisticsShareText, serviceMsgStatisticsShareFailed, timetableAppName,
        weekdayMon, weekdayTue, weekdayWed, weekdayThu, weekdayFri, weekdaySat, weekdaySun,
        weekdayShortMonday, weekdayShortTuesday, weekdayShortWednesday,
        weekdayShortThursday, weekdayShortFriday, weekdayShortSaturday, weekdayShortSunday,
    )
}
