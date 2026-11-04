package com.mutx163.qingyu.pages.statistics

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.pages.statistics.charts.BarChartSpec
import com.mutx163.qingyu.pages.statistics.charts.DailyChartModel
import com.mutx163.qingyu.statistics.Achievement
import com.mutx163.qingyu.statistics.CourseNatureStats
import com.mutx163.qingyu.statistics.CourseStub
import com.mutx163.qingyu.statistics.DailyAverageStats
import com.mutx163.qingyu.statistics.DataStory
import com.mutx163.qingyu.statistics.SemesterProgress
import com.mutx163.qingyu.statistics.SemesterProgressPhase
import com.mutx163.qingyu.statistics.SemesterStats
import com.mutx163.qingyu.statistics.StatisticsService
import com.mutx163.qingyu.statistics.StatsWidgetSnapshotBuilder
import com.mutx163.qingyu.statistics.StoryType
import com.mutx163.qingyu.statistics.WeeklyComparison
import com.mutx163.qingyu.statistics.WeeklyStats
import com.mutx163.qingyu.statistics.TimeUtilizationStats
import java.time.LocalDate
import java.time.LocalDateTime
import java.util.Locale
import kotlin.math.roundToInt

/**
 * 课程统计主页（`lib/screens/course_statistics_screen.dart`）模型层。
 *
 * 职责边界：
 * - **算数不在这里**：学期/周统计、成就、数据故事、进度、周对比全部来自 Phase 2 已迁好的
 *   `com.mutx163.qingyu.statistics.StatisticsService`（本类只负责换装 + 格式化）；
 * - **这里只做屏层的事**：分段选中、选中周回正、顶栏动作开关、入口顺序、
 *   以及各图表件的文案与数值格式化（`**` 加粗标记原样保留，由渲染层解析）。
 */

/** 学期 / 周 双视图分段（对齐屏层 `_semesterView`）。 */
enum class StatisticsTab { SEMESTER, WEEK }

/** 深度分析二级页模块（对齐 `StatisticsAnalysisScreen` 的 `module` 入参）。 */
enum class StatisticsAnalysisModule { TREND, TIME_UTIL, VENUE, TEACHER, RANKING, COMPARE }

/** 入口点击去向：单节课明细是独立页，其余进分析页并带模块。 */
sealed interface StatisticsEntryTarget {
    data object Sessions : StatisticsEntryTarget
    data class Analysis(val module: StatisticsAnalysisModule) : StatisticsEntryTarget
}

/** 深度分析入口行（标题 + 去向）。 */
data class StatisticsAnalysisEntry(
    val title: String,
    val target: StatisticsEntryTarget,
)

/** 总览单格（数字在上、标签在下；首格主题色高亮）。 */
data class StatisticsMetricView(
    val value: String,
    val label: String,
    val highlight: Boolean = false,
)

/** 学期进度卡视图。 */
data class SemesterProgressView(
    val title: String,
    val weekLabel: String,
    val rangeLabel: String?,
    val percent: Double,
    val percentText: String,
    val detailLabel: String,
    val isBeforeStart: Boolean,
    /** 右侧次要事实：有日期时是「今天 M月d日」，估算口径是「按周估算」；开学前整块不渲染。 */
    val factLabel: String?,
    val remainingLabel: String?,
)

/** 较上周差值的语义（渲染层据此取红/绿/次级色）。 */
enum class DeltaTone { UP, DOWN, FLAT }

/** 本周小结卡视图。 */
data class WeeklyComparisonView(
    val title: String,
    val weekLabel: String,
    val weekSectionsValue: String,
    val weekSectionsLabel: String,
    val deltaValue: String,
    val deltaLabel: String,
    val deltaTone: DeltaTone,
    val averageValue: String,
    val averageLabel: String,
    val isFirstWeek: Boolean,
    val newSemesterHint: String?,
)

/** 成就徽章视图。 */
data class AchievementView(
    val id: String,
    val name: String,
    val description: String,
    val detail: String = "",
    val isUnlocked: Boolean,
    val progressLabel: String?,
    val hasProgress: Boolean = false,
    val progressCurrent: Int? = null,
    val progressTarget: Int? = null,
    val progressRatio: Float = 0f,
    val statusLabel: String = "",
    val confirmLabel: String = StatisticsStrings.statisticsAchievementDetailConfirm.zh,
    val rawAchievement: Achievement? = null,
)

/** 数据故事视图（正文里的 `**` 由渲染层渲染成加粗）。 */
data class StoryView(
    val type: StoryType,
    val title: String,
    val content: String,
)

/** 必修 / 选修图例一行。 */
data class NatureLegendView(
    val label: String,
    val detail: String,
    val ratioText: String,
    val isRequired: Boolean,
)

/** 必修 / 选修环图视图。 */
data class NatureRatioView(
    val hasData: Boolean,
    val legend: List<NatureLegendView>,
    /** 单侧为 0 时环心的缺失提示（两侧都 0 时必修优先）。 */
    val missingLabel: String?,
    /** 必修侧是否有课（环图据此决定画实色弧还是极浅兜底轨道）。 */
    val hasRequired: Boolean = false,
    /** 选修侧是否有课。 */
    val hasElective: Boolean = false,
    /**
     * 两侧门数：环图直接交给共享 `ChartMath.donutSlices` 算弧长。
     * 不再从 `ratioText`（已经四舍五入成整数的显示文案）反解比例——
     * 那会丢精度，还会和共享环图画出不同弧长。
     */
    val requiredCount: Int = 0,
    val electiveCount: Int = 0,
)

/** 学期视图整块内容（按 Dart 屏层顺序装配）。 */
data class SemesterContent(
    val overview: List<StatisticsMetricView>,
    val progress: SemesterProgressView,
    val comparison: WeeklyComparisonView,
    val achievements: List<AchievementView>,
    val stories: List<StoryView>,
    /** 每日课时分布（学期口径）直接带共享图表规格，渲染层不再自己算网格/柱高。 */
    val dailyChart: BarChartSpec?,
    val nature: NatureRatioView,
) {
    /** Dart: `if (stories.isNotEmpty())` 才渲染「数据故事」分组。 */
    val showStoriesSection: Boolean get() = stories.isNotEmpty()
}

/** 周视图（`WeekStatsView`）数据结构：含总量、周次、完整周统计与时间利用指标。 */
data class WeekContent(
    val weekNumber: Int,
    val courseCount: Int,
    val sectionCount: Int,
    val maxWeek: Int,
    val weeklyStats: WeeklyStats? = null,
    val comparison: WeeklyComparison? = null,
    val timeUtilization: TimeUtilizationStats? = null,
)

/** 课程统计主页整页视图状态。 */
data class CourseStatisticsViewState(
    val title: String,
    val tabs: List<String>,
    val selectedTabIndex: Int,
    val hasData: Boolean,
    val emptyTitle: String,
    val emptyHint: String,
    /** Dart: `suffixes: hasData ? [设置, 分享] : const []` */
    val showHeaderActions: Boolean,
    val analysisEntries: List<StatisticsAnalysisEntry>,
    val semester: SemesterContent?,
    val week: WeekContent?,
    val selectedWeek: Int,
    val currentWeek: Int,
    val semesterWeekCount: Int,
    /** 桌面统计小组件快照（Dart 每次 build 幂等同步；null = 无课，跳过推送）。 */
    val widgetSnapshot: StatsWidgetSnapshotBuilder.StatsSnapshot?,
)

object CourseStatisticsLogic {

    private const val DELTA_PLACEHOLDER = "—"

    fun tabLabels(): List<String> = listOf(
        StatisticsStrings.statisticsTabSemester.zh,
        StatisticsStrings.statisticsTabWeek.zh,
    )

    fun selectedTabIndex(semesterView: Boolean): Int = if (semesterView) 0 else 1

    /**
     * 选中周回正（Dart `course_statistics_screen.dart:89-91`）：
     * 越界时回到当前周并夹到学期范围内。
     */
    fun resolveSelectedWeek(selectedWeek: Int, currentWeek: Int, semesterWeekCount: Int): Int {
        val safeMax = if (semesterWeekCount < 1) 1 else semesterWeekCount
        return if (selectedWeek < 1 || selectedWeek > safeMax) {
            currentWeek.coerceIn(1, safeMax)
        } else {
            selectedWeek
        }
    }

    /** 深度分析入口组（顺序照抄 Dart `_buildAnalysisEntries`）。 */
    fun analysisEntries(hasOtherProfiles: Boolean): List<StatisticsAnalysisEntry> {
        val entries = mutableListOf(
            StatisticsAnalysisEntry(
                StatisticsStrings.statisticsSessionTitle.zh,
                StatisticsEntryTarget.Sessions,
            ),
            StatisticsAnalysisEntry(
                StatisticsStrings.statisticsTrendTitle.zh,
                StatisticsEntryTarget.Analysis(StatisticsAnalysisModule.TREND),
            ),
            StatisticsAnalysisEntry(
                StatisticsStrings.statisticsTimeUtilTitle.zh,
                StatisticsEntryTarget.Analysis(StatisticsAnalysisModule.TIME_UTIL),
            ),
            StatisticsAnalysisEntry(
                StatisticsStrings.statisticsVenueTitle.zh,
                StatisticsEntryTarget.Analysis(StatisticsAnalysisModule.VENUE),
            ),
            StatisticsAnalysisEntry(
                StatisticsStrings.statisticsTeacherTitle.zh,
                StatisticsEntryTarget.Analysis(StatisticsAnalysisModule.TEACHER),
            ),
            StatisticsAnalysisEntry(
                StatisticsStrings.statisticsRankingTitle.zh,
                StatisticsEntryTarget.Analysis(StatisticsAnalysisModule.RANKING),
            ),
        )
        if (hasOtherProfiles) {
            entries += StatisticsAnalysisEntry(
                StatisticsStrings.statisticsCompareTitle.zh,
                StatisticsEntryTarget.Analysis(StatisticsAnalysisModule.COMPARE),
            )
        }
        return entries
    }

    /** 总览四格（`overview_section.dart`：门数 / 课时 / 周数 / 连续天数，首格高亮）。 */
    fun buildOverview(stats: SemesterStats): List<StatisticsMetricView> {
        if (stats.totalCourses == 0) return emptyList()
        return listOf(
            StatisticsMetricView(
                stats.totalCourses.toString(),
                StatisticsStrings.statisticsSemesterLabelCourses.zh,
                highlight = true,
            ),
            StatisticsMetricView(
                stats.totalSections.toString(),
                StatisticsStrings.statisticsSemesterLabelSections.zh,
            ),
            StatisticsMetricView(
                stats.totalWeeks.toString(),
                StatisticsStrings.statisticsSemesterLabelWeeks.zh,
            ),
            StatisticsMetricView(
                stats.longestStreak.toString(),
                StatisticsStrings.statisticsSemesterLabelDayStreak.zh,
            ),
        )
    }

    /** 学期进度卡（`semester_progress_card.dart`）。 */
    fun buildProgress(progress: SemesterProgress): SemesterProgressView {
        val isBeforeStart = progress.phase == SemesterProgressPhase.BEFORE_START
        val hasDates = progress.semesterStartDate != null && progress.semesterEndDate != null

        val rangeLabel = if (hasDates) {
            StatisticsStrings.statisticsSemesterProgressRange.filled(
                "start" to StatisticsDateLabels.yearMonthDay(progress.semesterStartDate.atStartOfDay()),
                "end" to StatisticsDateLabels.yearMonthDay(progress.semesterEndDate.atStartOfDay()),
            )
        } else {
            null
        }

        val detailLabel = if (isBeforeStart) {
            StatisticsStrings.statisticsSemesterProgressNotStarted.zh
        } else {
            StatisticsStrings.statisticsSemesterProgressDetail.filled(
                "week" to progress.weeksElapsed.toString(),
                "done" to progress.sectionsDone.toString(),
                "total" to progress.sectionsTotal.toString(),
            )
        }

        val factLabel = when {
            isBeforeStart -> null
            hasDates && progress.currentDate != null ->
                StatisticsStrings.statisticsSemesterProgressAsOf.filled(
                    "date" to StatisticsDateLabels.monthDay(progress.currentDate.atStartOfDay()),
                )
            else -> StatisticsStrings.statisticsSemesterProgressEstimated.zh
        }

        val remainingLabel = if (isBeforeStart) {
            null
        } else {
            StatisticsStrings.statisticsSemesterProgressRemaining.filled(
                "count" to progress.remainingSections.toString(),
            )
        }

        // 与 SemesterProgressModel 共用同一个钳位入口，别再各自写 coerceIn。
        val ratio = semesterProgressRatio(progress)

        return SemesterProgressView(
            title = StatisticsStrings.statisticsSemesterProgressTitle.zh,
            weekLabel = "${progress.weeksElapsed}/${progress.totalWeeks}",
            rangeLabel = rangeLabel,
            percent = ratio,
            percentText = percentText(ratio),
            detailLabel = detailLabel,
            isBeforeStart = isBeforeStart,
            factLabel = factLabel,
            remainingLabel = remainingLabel,
        )
    }

    /** 本周小结（`weekly_comparison_card.dart`）。 */
    fun buildComparison(comparison: WeeklyComparison, currentWeek: Int): WeeklyComparisonView {
        val isFirstWeek = currentWeek <= 1
        val deltaValue = if (isFirstWeek) DELTA_PLACEHOLDER else deltaText(comparison.deltaVsLastWeek)
        val deltaTone = when {
            isFirstWeek -> DeltaTone.FLAT
            comparison.deltaVsLastWeek > 0 -> DeltaTone.UP
            comparison.deltaVsLastWeek < 0 -> DeltaTone.DOWN
            else -> DeltaTone.FLAT
        }
        return WeeklyComparisonView(
            title = StatisticsStrings.statisticsComparisonTitle.zh,
            weekLabel = StatisticsStrings.statisticsWeekSelector.filled("week", currentWeek.toString()),
            weekSectionsValue = comparison.weekSections.toString(),
            weekSectionsLabel = StatisticsStrings.statisticsSectionCount.zh,
            deltaValue = deltaValue,
            deltaLabel = StatisticsStrings.statisticsComparisonVsLastWeek.filled("delta", deltaValue),
            deltaTone = deltaTone,
            averageValue = oneDecimal(comparison.semesterAverageSections),
            averageLabel = StatisticsStrings.statisticsComparisonAverage.zh,
            isFirstWeek = isFirstWeek,
            newSemesterHint = if (isFirstWeek) StatisticsStrings.statisticsComparisonNew.zh else null,
        )
    }

    fun buildAchievement(achievement: Achievement): AchievementView {
        // 「越小越好」的成就（空档 ≤ 2）不能把当前空档当分子：未解锁时会出现
        // 「6/2」和满格进度条，和「未达成」自相矛盾。未解锁时宁可不画线性进度，
        // 已解锁仍显示「已达成」。
        val hideInvertedProgress = achievement.isLowerBetterProgress && !achievement.isUnlocked
        val hasProgress = achievement.hasProgress && !hideInvertedProgress
        val progressLabel = if (hasProgress) {
            if (achievement.isUnlocked) {
                StatisticsStrings.statisticsAchievementDone.zh
            } else {
                StatisticsStrings.statisticsAchievementProgress.filled(
                    "current" to (achievement.progressCurrent ?: 0).toString(),
                    "target" to (achievement.progressTarget ?: 0).toString(),
                )
            }
        } else {
            null
        }
        val ratio = if (hasProgress && (achievement.progressTarget ?: 0) > 0) {
            ((achievement.progressCurrent ?: 0).toFloat() / (achievement.progressTarget ?: 1)).coerceIn(0f, 1f)
        } else {
            if (achievement.isUnlocked) 1f else 0f
        }
        val statusLabel = if (achievement.isUnlocked) {
            StatisticsStrings.statisticsAchievementDone.zh
        } else {
            StatisticsStrings.statisticsAchievementLocked.zh
        }
        return AchievementView(
            id = achievement.id,
            name = StatisticsStrings.achievementName(achievement.id),
            description = StatisticsStrings.achievementDescription(achievement.id),
            detail = StatisticsStrings.achievementDetail(achievement.id),
            isUnlocked = achievement.isUnlocked,
            progressLabel = progressLabel,
            hasProgress = hasProgress,
            progressCurrent = if (hasProgress) achievement.progressCurrent else null,
            progressTarget = if (hasProgress) achievement.progressTarget else null,
            progressRatio = ratio,
            statusLabel = statusLabel,
            confirmLabel = StatisticsStrings.statisticsAchievementDetailConfirm.zh,
            rawAchievement = achievement,
        )
    }

    fun buildAchievements(list: List<Achievement>): List<AchievementView> = list.map(::buildAchievement)

    /** 数据故事（`data_story_card.dart`：`**` 标记保留，渲染层变粗体）。 */
    fun buildStory(story: DataStory): StoryView {
        val avg = story.averageSections?.let(::oneDecimal) ?: ""
        val day = story.dayOfWeek?.let { StatisticsStrings.weekdayFull(it) } ?: ""
        val week = (story.weekNumber ?: 0).toString()

        return when (story.type) {
            StoryType.BUSIEST_DAY -> StoryView(
                story.type,
                StatisticsStrings.storyBusiestDayTitle.zh,
                StatisticsStrings.storyBusiestDayContent.filled(
                    "week" to week,
                    "day" to day,
                    "avg" to avg,
                ),
            )
            StoryType.LIGHTEST_DAY -> StoryView(
                story.type,
                StatisticsStrings.storyLightestDayTitle.zh,
                StatisticsStrings.storyLightestDayContent.filled(
                    "week" to week,
                    "day" to day,
                    "avg" to avg,
                ),
            )
            StoryType.FAVORITE_ROOM -> StoryView(
                story.type,
                StatisticsStrings.storyFavoriteRoomTitle.zh,
                StatisticsStrings.storyFavoriteRoomContent.filled(
                    "week" to week,
                    "room" to (story.room ?: ""),
                    "count" to (story.visitCount ?: 0).toString(),
                ),
            )
            StoryType.BUILDING_COUNT -> StoryView(
                story.type,
                StatisticsStrings.storyBuildingCountTitle.zh,
                StatisticsStrings.storyBuildingCountContent.filled(
                    "week" to week,
                    "count" to (story.buildingCount ?: 0).toString(),
                ),
            )
            StoryType.TIME_RANGE -> StoryView(
                story.type,
                StatisticsStrings.storyTimeRangeTitle.zh,
                StatisticsStrings.storyTimeRangeContent.filled(
                    "earliest" to (story.earliestTime ?: ""),
                    "latest" to (story.latestTime ?: ""),
                ),
            )
        }
    }

    fun buildStories(list: List<DataStory>): List<StoryView> = list.map(::buildStory)

    /**
     * 每日课时分布（`daily_chart.dart`：最大高亮、最小次高亮、零课时都不标）。
     *
     * 直接复用共享的 [DailyChartModel.averageSpec]：网格/刻度/柱高/强调档
     * 与周视图、导出图同一套口径（原先这里另算一份，分数均值时刻度会对不上）。
     */
    fun buildDailyChart(dailyAverages: List<DailyAverageStats>): BarChartSpec? =
        DailyChartModel.averageSpec(dailyAverages)

    /** 必修 / 选修（`nature_ratio.dart`）。 */
    fun buildNature(stats: CourseNatureStats): NatureRatioView {
        val hasData = stats.totalCount > 0
        if (!hasData) {
            return NatureRatioView(hasData = false, legend = emptyList(), missingLabel = null)
        }
        val missingLabel = when {
            stats.requiredCount == 0 -> StatisticsStrings.statisticsNatureNoneRequired.zh
            stats.electiveCount == 0 -> StatisticsStrings.statisticsNatureNoneElective.zh
            else -> null
        }
        return NatureRatioView(
            hasData = true,
            legend = listOf(
                NatureLegendView(
                    label = StatisticsStrings.courseNatureRequired.zh,
                    detail = StatisticsStrings.statisticsNatureLegendDetail.filled(
                        "count" to stats.requiredCount.toString(),
                        "sections" to stats.requiredSections.toString(),
                    ),
                    ratioText = percentText(stats.requiredRatio),
                    isRequired = true,
                ),
                NatureLegendView(
                    label = StatisticsStrings.courseNatureElective.zh,
                    detail = StatisticsStrings.statisticsNatureLegendDetail.filled(
                        "count" to stats.electiveCount.toString(),
                        "sections" to stats.electiveSections.toString(),
                    ),
                    ratioText = percentText(stats.electiveRatio),
                    isRequired = false,
                ),
            ),
            missingLabel = missingLabel,
            hasRequired = stats.requiredCount > 0,
            hasElective = stats.electiveCount > 0,
            requiredCount = stats.requiredCount,
            electiveCount = stats.electiveCount,
        )
    }

    /**
     * 装配整页视图状态。
     *
     * 与 Dart 屏层一一对应：先回正选中周，再算学期总览/进度/对比/成就/故事/日分布/必修选修，
     * 最后按有无课程决定顶栏动作与内容区。
     *
     * @param now 注入时钟（学期进度卡的「今天」与已上节数按它算）；null = 取真实当前时间。
     *   单测必须传固定值，别让「今天」渗透进期望值（TEST-POLICY「日期老化」）。
     * @param profileName 活动课表名，只进桌面统计小组件快照（Dart
     *   `provider.activeProfile?.name ?? ''`）。默认空串 = 老行为，壳接线时传真名。
     */
    fun buildViewState(
        courses: List<Course>,
        currentWeek: Int,
        semesterWeekCount: Int,
        semesterStartDate: LocalDate?,
        selectedWeek: Int,
        semesterView: Boolean,
        hasOtherProfiles: Boolean,
        now: LocalDateTime? = null,
        profileName: String = "",
    ): CourseStatisticsViewState {
        val resolvedWeek = resolveSelectedWeek(selectedWeek, currentWeek, semesterWeekCount)
        val hasData = courses.isNotEmpty()

        if (!hasData) {
            return CourseStatisticsViewState(
                title = StatisticsStrings.statisticsTitle.zh,
                tabs = tabLabels(),
                selectedTabIndex = selectedTabIndex(semesterView),
                hasData = false,
                emptyTitle = StatisticsStrings.statisticsNoData.zh,
                emptyHint = StatisticsStrings.statisticsNoDataHint.zh,
                showHeaderActions = false,
                analysisEntries = emptyList(),
                semester = null,
                week = null,
                selectedWeek = resolvedWeek,
                currentWeek = currentWeek,
                semesterWeekCount = semesterWeekCount,
                widgetSnapshot = null,
            )
        }

        val stubs = courses.map { it.toStatisticsStub() }
        val semesterStats = StatisticsService.calculateSemester(
            allCourses = stubs,
            currentWeek = currentWeek,
            semesterWeekCount = semesterWeekCount,
        )
        val progress = StatisticsService.calculateSemesterProgress(
            allCourses = stubs,
            currentWeek = currentWeek,
            semesterWeekCount = semesterWeekCount,
            semesterStartDate = semesterStartDate,
            now = now,
        )
        val comparison = StatisticsService.calculateWeeklyComparison(
            allCourses = stubs,
            currentWeek = currentWeek,
            semesterWeekCount = semesterWeekCount,
        )
        val achievements = StatisticsService.calculateAchievements(
            allCourses = stubs,
            currentWeek = currentWeek,
        )
        val stories = StatisticsService.generateDataStories(
            allCourses = stubs,
            currentWeek = currentWeek,
        )
        val weekStats = StatisticsService.calculate(allCourses = stubs, week = resolvedWeek)
        val weekComparison = StatisticsService.calculateWeeklyComparison(
            allCourses = stubs,
            currentWeek = resolvedWeek,
            semesterWeekCount = semesterWeekCount,
        )
        val weekTimeUtil = StatisticsService.calculateTimeUtilization(
            allCourses = stubs,
            currentWeek = resolvedWeek,
        )

        return CourseStatisticsViewState(
            title = StatisticsStrings.statisticsTitle.zh,
            tabs = tabLabels(),
            selectedTabIndex = selectedTabIndex(semesterView),
            hasData = true,
            emptyTitle = StatisticsStrings.statisticsNoData.zh,
            emptyHint = StatisticsStrings.statisticsNoDataHint.zh,
            showHeaderActions = true,
            analysisEntries = analysisEntries(hasOtherProfiles),
            semester = SemesterContent(
                overview = buildOverview(semesterStats),
                progress = buildProgress(progress),
                comparison = buildComparison(comparison, currentWeek),
                achievements = buildAchievements(achievements),
                stories = buildStories(stories),
                dailyChart = buildDailyChart(semesterStats.dailyAverages),
                nature = buildNature(semesterStats.natureStats),
            ),
            week = WeekContent(
                weekNumber = resolvedWeek,
                courseCount = weekStats.totalCourses,
                sectionCount = weekStats.totalSections,
                maxWeek = semesterWeekCount,
                weeklyStats = weekStats,
                comparison = weekComparison,
                timeUtilization = weekTimeUtil,
            ),
            selectedWeek = resolvedWeek,
            currentWeek = currentWeek,
            semesterWeekCount = semesterWeekCount,
            widgetSnapshot = StatsWidgetSnapshotBuilder.fromCourses(
                courses = courses,
                currentWeek = currentWeek,
                semesterWeekCount = semesterWeekCount,
                profileName = profileName,
            ),
        )
    }

    /** `semesterAverageSections.toStringAsFixed(1)` 的等价实现（强制 '.' 小数点为 locale 无关）。 */
    fun oneDecimal(value: Double): String = String.format(Locale.ROOT, "%.1f", value)

    /** Dart `d > 0 ? '+$d' : (d < 0 ? '$d' : '0')`。 */
    fun deltaText(delta: Int): String = when {
        delta > 0 -> "+$delta"
        delta < 0 -> delta.toString()
        else -> "0"
    }

    private fun percentText(ratio: Double): String = "${(ratio * 100).roundToInt()}%"
}

/**
 * `core.Course` → 统计口径 `CourseStub` 的机械换装。
 *
 * 与 `StatsWidgetSnapshotBuilder` 内部那份私有换装同口径（那边是 private，
 * 这里不能复用它）；只取统计实际消费的字段。
 */
private fun Course.toStatisticsStub(): CourseStub = CourseStub(
    name = name,
    teacher = teacher,
    location = location,
    dayOfWeek = dayOfWeek,
    startSection = startSection,
    endSection = endSection,
    startTime = startTime,
    endTime = endTime,
    startWeek = startWeek,
    endWeek = endWeek,
    isOddWeek = isOddWeek,
    isEvenWeek = isEvenWeek,
    customWeeks = customWeeks,
    suspendedWeeks = suspendedWeeks,
    courseNature = courseNature,
)
