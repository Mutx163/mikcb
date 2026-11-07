package com.mutx163.qingyu.pages.statistics

/**
 * 统计 (Statistics) 模块用到的 ARB 文案（`lib/l10n/app_zh.arb`，模板语言 zh）。
 *
 * **逐字抄录，不许改写**：每一条都在 [StatisticsStringsParityTest] 里与 ARB 机械比对，
 * 键缺失或值被改写都会红。要改界面文字，先改 ARB（六份同步）+ 重新生成 `gen-l10n`，
 * 再同步这里。
 *
 * 命名与 ARB 键逐字一致（`statisticsTitle` 等），便于 `grep` 双向核对。
 */
data class ArbText(val key: String, val zh: String) {
    /** 替换模板里的占位符（`{name}` → [value]）。 */
    fun filled(name: String, value: String): String = zh.replace("{$name}", value)

    fun filled(vararg pairs: Pair<String, String>): String {
        var result = zh
        for ((name, value) in pairs) {
            result = result.replace("{$name}", value)
        }
        return result
    }
}

object StatisticsStrings {

    // ── 统计主页 (CourseStatisticsScreen) ──
    val statisticsTitle = ArbText("statisticsTitle", "课程统计")
    val statisticsSettingsTitle = ArbText("statisticsSettingsTitle", "统计设置")
    val statisticsShareLabel = ArbText("statisticsShareLabel", "分享统计")
    val statisticsTabSemester = ArbText("statisticsTabSemester", "学期")
    val statisticsTabWeek = ArbText("statisticsTabWeek", "周")
    val statisticsNoData = ArbText("statisticsNoData", "暂无课程数据")
    val statisticsNoDataHint = ArbText("statisticsNoDataHint", "添加课程后即可查看统计")

    // ── 学期总览 / 分段标题 ──
    val statisticsOverview = ArbText("statisticsOverview", "本周概览")
    val statisticsCourseCount = ArbText("statisticsCourseCount", "课程门数")
    val statisticsSectionCount = ArbText("statisticsSectionCount", "本周课时")
    val statisticsWeeklyCourses = ArbText("statisticsWeeklyCourses", "本周课程")
    val statisticsDailyDistribution = ArbText("statisticsDailyDistribution", "每日课时分布")
    val statisticsNatureRatio = ArbText("statisticsNatureRatio", "必修 / 选修")
    val statisticsCourseList = ArbText("statisticsCourseList", "课程列表")
    val statisticsSectionsUnit = ArbText("statisticsSectionsUnit", "节")
    val statisticsSectionUnit = ArbText("statisticsSectionUnit", "节")
    val statisticsWeekSelector = ArbText("statisticsWeekSelector", "第 {week} 周")

    val statisticsSemesterLabelCourses = ArbText("statisticsSemesterLabelCourses", "门课程")
    val statisticsSemesterLabelSections = ArbText("statisticsSemesterLabelSections", "节课")
    val statisticsSemesterLabelWeeks = ArbText("statisticsSemesterLabelWeeks", "周")
    val statisticsSemesterLabelDayStreak = ArbText("statisticsSemesterLabelDayStreak", "天连续")

    val statisticsAchievementsTitle = ArbText("statisticsAchievementsTitle", "成就徽章")
    val statisticsStoriesTitle = ArbText("statisticsStoriesTitle", "数据故事")

    // ── 深度分析入口组 ──
    val statisticsMoreTitle = ArbText("statisticsMoreTitle", "深度分析")
    val statisticsSessionTitle = ArbText("statisticsSessionTitle", "单节课明细")
    val statisticsTrendTitle = ArbText("statisticsTrendTitle", "每周课时趋势")
    val statisticsTimeUtilTitle = ArbText("statisticsTimeUtilTitle", "时间利用")
    val statisticsVenueTitle = ArbText("statisticsVenueTitle", "教室与教学楼")
    val statisticsTeacherTitle = ArbText("statisticsTeacherTitle", "教师课时排行")
    val statisticsRankingTitle = ArbText("statisticsRankingTitle", "课程排行")
    val statisticsCompareTitle = ArbText("statisticsCompareTitle", "课表对比")

    // ── 学期进度卡 ──
    val statisticsSemesterProgressTitle = ArbText("statisticsSemesterProgressTitle", "学期进度")
    val statisticsSemesterProgressRange = ArbText("statisticsSemesterProgressRange", "学期 {start} - {end}")
    val statisticsSemesterProgressAsOf = ArbText("statisticsSemesterProgressAsOf", "今天 {date}")
    val statisticsSemesterProgressDetail =
        ArbText("statisticsSemesterProgressDetail", "截至第 {week} 周，已上 {done} 节 / 共 {total} 节")
    val statisticsSemesterProgressRemaining = ArbText("statisticsSemesterProgressRemaining", "剩余 {count} 节")
    val statisticsSemesterProgressNotStarted = ArbText("statisticsSemesterProgressNotStarted", "还未开学，尚未上课")
    val statisticsSemesterProgressEstimated = ArbText("statisticsSemesterProgressEstimated", "按周估算")

    // ── 本周小结（周对比卡） ──
    val statisticsComparisonTitle = ArbText("statisticsComparisonTitle", "本周小结")
    val statisticsComparisonLastWeek = ArbText("statisticsComparisonLastWeek", "上周课时")
    val statisticsComparisonAverage = ArbText("statisticsComparisonAverage", "学期周均")
    val statisticsComparisonVsLastWeek = ArbText("statisticsComparisonVsLastWeek", "较上周 {delta} 节")
    val statisticsComparisonVsAverage = ArbText("statisticsComparisonVsAverage", "较周均 {delta} 节")
    val statisticsComparisonNew = ArbText("statisticsComparisonNew", "新学期第一周")

    // ── 必修 / 选修比例 ──
    val courseNatureRequired = ArbText("courseNatureRequired", "必修")
    val courseNatureElective = ArbText("courseNatureElective", "选修")
    val statisticsNatureLegendDetail = ArbText("statisticsNatureLegendDetail", "{count} 门 · {sections} 节")
    val statisticsNatureNoneRequired = ArbText("statisticsNatureNoneRequired", "暂无必修")
    val statisticsNatureNoneElective = ArbText("statisticsNatureNoneElective", "暂无选修")

    // ── 成就徽章 ──
    val statisticsAchievementProgress = ArbText("statisticsAchievementProgress", "{current}/{target}")
    val statisticsAchievementDone = ArbText("statisticsAchievementDone", "已达成")
    val statisticsAchievementLocked = ArbText("statisticsAchievementLocked", "未达成")

    val achievementEarlyBirdName = ArbText("statisticsAchievementEarlyBirdName", "早八战士")
    val achievementEarlyBirdDescription = ArbText("statisticsAchievementEarlyBirdDescription", "有 8:00 的课，真棒")
    val achievementPerfectAttendanceName = ArbText("statisticsAchievementPerfectAttendanceName", "全勤达人")
    val achievementPerfectAttendanceDescription =
        ArbText("statisticsAchievementPerfectAttendanceDescription", "某门课每周都有")
    val achievementWeekendWarriorName = ArbText("statisticsAchievementWeekendWarriorName", "周末战士")
    val achievementWeekendWarriorDescription =
        ArbText("statisticsAchievementWeekendWarriorDescription", "周末有课")
    val achievementClassKingName = ArbText("statisticsAchievementClassKingName", "课王")
    val achievementClassKingDescription = ArbText("statisticsAchievementClassKingDescription", "某天 ≥ 6 节课")
    val achievementScholarName = ArbText("statisticsAchievementScholarName", "学霸")
    val achievementScholarDescription = ArbText("statisticsAchievementScholarDescription", "总课时 ≥ 100")
    val achievementBalancedName = ArbText("statisticsAchievementBalancedName", "均衡大师")
    val achievementBalancedDescription = ArbText("statisticsAchievementBalancedDescription", "每天课时差距 ≤ 2")
    val achievementNightOwlName = ArbText("statisticsAchievementNightOwlName", "夜猫子")
    val achievementNightOwlDescription = ArbText("statisticsAchievementNightOwlDescription", "有 18:00 以后的课")
    val achievementExplorerName = ArbText("statisticsAchievementExplorerName", "教室探索家")
    val achievementExplorerDescription =
        ArbText("statisticsAchievementExplorerDescription", "使用过 ≥ 5 个不同教室")
    val achievementFullDayKingName = ArbText("statisticsAchievementFullDayKingName", "满课日之王")
    val achievementFullDayKingDescription =
        ArbText("statisticsAchievementFullDayKingDescription", "单日 ≥ 8 节课")
    val achievementBuildingHopperName = ArbText("statisticsAchievementBuildingHopperName", "跨楼达人")
    val achievementBuildingHopperDescription =
        ArbText("statisticsAchievementBuildingHopperDescription", "单日跨 ≥ 3 栋教学楼")
    val achievementMorningPersonName = ArbText("statisticsAchievementMorningPersonName", "早起鸟")
    val achievementMorningPersonDescription =
        ArbText("statisticsAchievementMorningPersonDescription", "早间课时占比 ≥ 50%")
    val achievementGapMasterName = ArbText("statisticsAchievementGapMasterName", "时间管理大师")
    val achievementGapMasterDescription =
        ArbText("statisticsAchievementGapMasterDescription", "最长课间空档 ≤ 2 节")

    val statisticsAchievementEarlyBirdDetail =
        ArbText("statisticsAchievementEarlyBirdDetail", "解锁条件：课表中有 08:00 或更早开始的课程。")
    val statisticsAchievementPerfectAttendanceDetail =
        ArbText("statisticsAchievementPerfectAttendanceDetail", "解锁条件：至少一门课程在学期内每周均有课，无停课或跳周。")
    val statisticsAchievementWeekendWarriorDetail =
        ArbText("statisticsAchievementWeekendWarriorDetail", "解锁条件：周六或周日有课。")
    val statisticsAchievementClassKingDetail =
        ArbText("statisticsAchievementClassKingDetail", "解锁条件：某一天排课达到 6 节及以上。")
    val statisticsAchievementScholarDetail =
        ArbText("statisticsAchievementScholarDetail", "解锁条件：学期累计课时达到 100 节。")
    val statisticsAchievementBalancedDetail =
        ArbText("statisticsAchievementBalancedDetail", "解锁条件：每天课时差距不超过 2 节，课表安排均衡。")
    val statisticsAchievementNightOwlDetail =
        ArbText("statisticsAchievementNightOwlDetail", "解锁条件：有 18:00 以后才结束的课。")
    val statisticsAchievementExplorerDetail =
        ArbText("statisticsAchievementExplorerDetail", "解锁条件：使用过 5 个及以上不同的教室。")
    val statisticsAchievementFullDayKingDetail =
        ArbText("statisticsAchievementFullDayKingDetail", "解锁条件：某一天排课达到 8 节及以上，全天满课。")
    val statisticsAchievementBuildingHopperDetail =
        ArbText("statisticsAchievementBuildingHopperDetail", "解锁条件：同一天内去过 3 栋及以上不同的教学楼。")
    val statisticsAchievementMorningPersonDetail =
        ArbText("statisticsAchievementMorningPersonDetail", "解锁条件：12:00 前的课程节数占总节数一半以上。")
    val statisticsAchievementGapMasterDetail =
        ArbText("statisticsAchievementGapMasterDetail", "解锁条件：每天课间最长空档不超过 2 节，时间安排紧凑。")
    val statisticsAchievementDetailConfirm =
        ArbText("statisticsAchievementDetailConfirm", "知道了")

    // ── 数据故事 ──
    val storyBusiestDayTitle = ArbText("statisticsStoryBusiestDayTitle", "最忙的一天")
    val storyBusiestDayContent = ArbText(
        "statisticsStoryBusiestDayContent",
        "截至第 {week} 周，这学期你最忙的一天是 **{day}**，平均 **{avg}** 节课",
    )
    val storyLightestDayTitle = ArbText("statisticsStoryLightestDayTitle", "最轻松的一天")
    val storyLightestDayContent = ArbText(
        "statisticsStoryLightestDayContent",
        "截至第 {week} 周，你最轻松的一天是 **{day}**，只有 **{avg}** 节课",
    )
    val storyFavoriteRoomTitle = ArbText("statisticsStoryFavoriteRoomTitle", "最常去的教室")
    val storyFavoriteRoomContent = ArbText(
        "statisticsStoryFavoriteRoomContent",
        "截至第 {week} 周，你最常去的教室是 **{room}**，共去了 **{count}** 次",
    )
    val storyBuildingCountTitle = ArbText("statisticsStoryBuildingCountTitle", "教学楼探险")
    val storyBuildingCountContent = ArbText(
        "statisticsStoryBuildingCountContent",
        "截至第 {week} 周，你的课程分布在 **{count}** 栋不同的教学楼",
    )
    val storyTimeRangeTitle = ArbText("statisticsStoryTimeRangeTitle", "时间跨度")
    val storyTimeRangeContent = ArbText(
        "statisticsStoryTimeRangeContent",
        "你最早的课是 **{earliest}**，最晚的课是 **{latest}**",
    )

    // ── 星期名（图表轴 / 故事正文） ──
    val weekdayMon = ArbText("weekdayMon", "周一")
    val weekdayTue = ArbText("weekdayTue", "周二")
    val weekdayWed = ArbText("weekdayWed", "周三")
    val weekdayThu = ArbText("weekdayThu", "周四")
    val weekdayFri = ArbText("weekdayFri", "周五")
    val weekdaySat = ArbText("weekdaySat", "周六")
    val weekdaySun = ArbText("weekdaySun", "周日")

    val weekdayShortMonday = ArbText("weekdayShortMonday", "一")
    val weekdayShortTuesday = ArbText("weekdayShortTuesday", "二")
    val weekdayShortWednesday = ArbText("weekdayShortWednesday", "三")
    val weekdayShortThursday = ArbText("weekdayShortThursday", "四")
    val weekdayShortFriday = ArbText("weekdayShortFriday", "五")
    val weekdayShortSaturday = ArbText("weekdayShortSaturday", "六")
    val weekdayShortSunday = ArbText("weekdayShortSunday", "日")

    // ── 统计设置页（周报推送开关） ──
    val weeklyReportTitle = ArbText("weeklyReportTitle", "本周课程小结")
    val weeklyReportNextFire = ArbText("weeklyReportNextFire", "下次推送 {date} {time}")
    val weeklyReportEnabledHint = ArbText("weeklyReportEnabledHint", "已开启每周周报推送")
    val weeklyReportDisabledHint = ArbText("weeklyReportDisabledHint", "已关闭每周周报推送")
    /**
     * 通知不可达时**拒绝打开**开关的提示（2026-11-05）：不写 settings、不排调度，
     * 直接告诉用户去哪里开。不复用日程那句（`scheduleReminderPermissionMissing` 说的是
     * 「日程仍会保存」，用在周报上就是假话）。
     */
    val weeklyReportPermissionMissing = ArbText(
        "weeklyReportPermissionMissing",
        "通知权限未开启，请到系统设置里允许通知后再开启周报",
    )
    val saveFailed = ArbText("saveFailed", "保存失败")

    /** 星期全名（周一~周日，越界回退到数字字符串，对齐 Dart `_weekdayFullLabel`）。 */
    fun weekdayFull(dayOfWeek: Int): String = when (dayOfWeek) {
        1 -> weekdayMon.zh
        2 -> weekdayTue.zh
        3 -> weekdayWed.zh
        4 -> weekdayThu.zh
        5 -> weekdayFri.zh
        6 -> weekdaySat.zh
        7 -> weekdaySun.zh
        else -> dayOfWeek.toString()
    }

    /** 星期短名（一~日，图表横轴，越界返回空串）。 */
    fun weekdayShort(dayOfWeek: Int): String = when (dayOfWeek) {
        1 -> weekdayShortMonday.zh
        2 -> weekdayShortTuesday.zh
        3 -> weekdayShortWednesday.zh
        4 -> weekdayShortThursday.zh
        5 -> weekdayShortFriday.zh
        6 -> weekdayShortSaturday.zh
        7 -> weekdayShortSunday.zh
        else -> ""
    }

    /** 成就名称（对齐 Dart `achievement_badge.dart:_achievementName`，未知 id 原样返回）。 */
    fun achievementName(id: String): String = when (id) {
        "early_bird" -> achievementEarlyBirdName.zh
        "perfect_attendance" -> achievementPerfectAttendanceName.zh
        "weekend_warrior" -> achievementWeekendWarriorName.zh
        "class_king" -> achievementClassKingName.zh
        "scholar" -> achievementScholarName.zh
        "balanced" -> achievementBalancedName.zh
        "night_owl" -> achievementNightOwlName.zh
        "explorer" -> achievementExplorerName.zh
        "full_day_king" -> achievementFullDayKingName.zh
        "building_hopper" -> achievementBuildingHopperName.zh
        "morning_person" -> achievementMorningPersonName.zh
        "gap_master" -> achievementGapMasterName.zh
        else -> id
    }

    /** 成就说明（对齐 Dart `achievement_badge.dart` 详情弹窗口径）。 */
    fun achievementDescription(id: String): String = when (id) {
        "early_bird" -> achievementEarlyBirdDescription.zh
        "perfect_attendance" -> achievementPerfectAttendanceDescription.zh
        "weekend_warrior" -> achievementWeekendWarriorDescription.zh
        "class_king" -> achievementClassKingDescription.zh
        "scholar" -> achievementScholarDescription.zh
        "balanced" -> achievementBalancedDescription.zh
        "night_owl" -> achievementNightOwlDescription.zh
        "explorer" -> achievementExplorerDescription.zh
        "full_day_king" -> achievementFullDayKingDescription.zh
        "building_hopper" -> achievementBuildingHopperDescription.zh
        "morning_person" -> achievementMorningPersonDescription.zh
        "gap_master" -> achievementGapMasterDescription.zh
        else -> id
    }

    /** 成就详细说明（对齐 Dart `achievement_badge.dart` 详情弹窗正文）。 */
    fun achievementDetail(id: String): String = when (id) {
        "early_bird" -> statisticsAchievementEarlyBirdDetail.zh
        "perfect_attendance" -> statisticsAchievementPerfectAttendanceDetail.zh
        "weekend_warrior" -> statisticsAchievementWeekendWarriorDetail.zh
        "class_king" -> statisticsAchievementClassKingDetail.zh
        "scholar" -> statisticsAchievementScholarDetail.zh
        "balanced" -> statisticsAchievementBalancedDetail.zh
        "night_owl" -> statisticsAchievementNightOwlDetail.zh
        "explorer" -> statisticsAchievementExplorerDetail.zh
        "full_day_king" -> statisticsAchievementFullDayKingDetail.zh
        "building_hopper" -> statisticsAchievementBuildingHopperDetail.zh
        "morning_person" -> statisticsAchievementMorningPersonDetail.zh
        "gap_master" -> statisticsAchievementGapMasterDetail.zh
        else -> ""
    }

    /** 全部文案（文案对拍逐条遍历）。 */
    val allTexts: List<ArbText> = listOf(
        statisticsTitle,
        statisticsSettingsTitle,
        statisticsShareLabel,
        statisticsTabSemester,
        statisticsTabWeek,
        statisticsNoData,
        statisticsNoDataHint,
        statisticsOverview,
        statisticsCourseCount,
        statisticsSectionCount,
        statisticsWeeklyCourses,
        statisticsDailyDistribution,
        statisticsNatureRatio,
        statisticsCourseList,
        statisticsSectionsUnit,
        statisticsSectionUnit,
        statisticsWeekSelector,
        statisticsSemesterLabelCourses,
        statisticsSemesterLabelSections,
        statisticsSemesterLabelWeeks,
        statisticsSemesterLabelDayStreak,
        statisticsAchievementsTitle,
        statisticsStoriesTitle,
        statisticsMoreTitle,
        statisticsSessionTitle,
        statisticsTrendTitle,
        statisticsTimeUtilTitle,
        statisticsVenueTitle,
        statisticsTeacherTitle,
        statisticsRankingTitle,
        statisticsCompareTitle,
        statisticsSemesterProgressTitle,
        statisticsSemesterProgressRange,
        statisticsSemesterProgressAsOf,
        statisticsSemesterProgressDetail,
        statisticsSemesterProgressRemaining,
        statisticsSemesterProgressNotStarted,
        statisticsSemesterProgressEstimated,
        statisticsComparisonTitle,
        statisticsComparisonLastWeek,
        statisticsComparisonAverage,
        statisticsComparisonVsLastWeek,
        statisticsComparisonVsAverage,
        statisticsComparisonNew,
        courseNatureRequired,
        courseNatureElective,
        statisticsNatureLegendDetail,
        statisticsNatureNoneRequired,
        statisticsNatureNoneElective,
        statisticsAchievementProgress,
        statisticsAchievementDone,
        statisticsAchievementLocked,
        achievementEarlyBirdName,
        achievementEarlyBirdDescription,
        achievementPerfectAttendanceName,
        achievementPerfectAttendanceDescription,
        achievementWeekendWarriorName,
        achievementWeekendWarriorDescription,
        achievementClassKingName,
        achievementClassKingDescription,
        achievementScholarName,
        achievementScholarDescription,
        achievementBalancedName,
        achievementBalancedDescription,
        achievementNightOwlName,
        achievementNightOwlDescription,
        achievementExplorerName,
        achievementExplorerDescription,
        achievementFullDayKingName,
        achievementFullDayKingDescription,
        achievementBuildingHopperName,
        achievementBuildingHopperDescription,
        achievementMorningPersonName,
        achievementMorningPersonDescription,
        achievementGapMasterName,
        achievementGapMasterDescription,
        statisticsAchievementEarlyBirdDetail,
        statisticsAchievementPerfectAttendanceDetail,
        statisticsAchievementWeekendWarriorDetail,
        statisticsAchievementClassKingDetail,
        statisticsAchievementScholarDetail,
        statisticsAchievementBalancedDetail,
        statisticsAchievementNightOwlDetail,
        statisticsAchievementExplorerDetail,
        statisticsAchievementFullDayKingDetail,
        statisticsAchievementBuildingHopperDetail,
        statisticsAchievementMorningPersonDetail,
        statisticsAchievementGapMasterDetail,
        statisticsAchievementDetailConfirm,
        storyBusiestDayTitle,
        storyBusiestDayContent,
        storyLightestDayTitle,
        storyLightestDayContent,
        storyFavoriteRoomTitle,
        storyFavoriteRoomContent,
        storyBuildingCountTitle,
        storyBuildingCountContent,
        storyTimeRangeTitle,
        storyTimeRangeContent,
        weekdayMon,
        weekdayTue,
        weekdayWed,
        weekdayThu,
        weekdayFri,
        weekdaySat,
        weekdaySun,
        weekdayShortMonday,
        weekdayShortTuesday,
        weekdayShortWednesday,
        weekdayShortThursday,
        weekdayShortFriday,
        weekdayShortSaturday,
        weekdayShortSunday,
        weeklyReportTitle,
        weeklyReportNextFire,
        weeklyReportEnabledHint,
        weeklyReportDisabledHint,
        weeklyReportPermissionMissing,
        saveFailed,
    )
}
