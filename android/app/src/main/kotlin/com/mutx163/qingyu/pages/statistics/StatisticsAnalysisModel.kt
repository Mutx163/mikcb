package com.mutx163.qingyu.pages.statistics

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.pages.statistics.charts.ChartsStrings
import com.mutx163.qingyu.pages.statistics.charts.CourseRankingModel
import com.mutx163.qingyu.pages.statistics.charts.TeacherStatsModel
import com.mutx163.qingyu.pages.statistics.charts.TimeUtilizationModel
import com.mutx163.qingyu.pages.statistics.charts.VenueStatsModel
import com.mutx163.qingyu.statistics.CourseStub
import com.mutx163.qingyu.statistics.StatisticsService
import com.mutx163.qingyu.statistics.VenueStats

/**
 * 深度分析二级页（`lib/screens/statistics_analysis_screen.dart`，208 行）模型层。
 *
 * ## 这一页在做什么
 *
 * 一个壳子 + 六个模块分支。壳子负责：标题、空态、整页列表；模块负责：取数 + 摆卡片。
 * 所以模型层要回答的只有三件事：
 *
 * 1. **标题**：模块 → ARB 键（Dart `_moduleTitle` 的 switch，逐字对应）；
 * 2. **有没有数据**：`courses.isEmpty` 决定走空态还是走列表（Dart `hasData`）；
 * 3. **这个模块要摆哪几块**：卡片清单与它们之间的分段间距。
 *
 * ## 为什么卡片清单也进模型层
 *
 * 渲染层「不持业务状态、不做业务计算」（BRIEF §2）。「这个模块摆哪几张卡、中间要不要
 * 分段间距」是布局决策但**不是** Compose 决策——它是纯数据，能在 JVM 单测里钉住。
 * 留到渲染层写 `when` 分支，就等于把「六模块各摆什么」这件事从测试网里拿掉了：
 * 将来有人漏掉一个模块的分支，编译照样过。
 */
object StatisticsAnalysisModel {

    /**
     * 模块 → 标题（Dart `statistics_analysis_screen.dart:70-77`）。
     *
     * 注意 [StatisticsAnalysisModule] 定义在已交付的 `CourseStatisticsModel.kt` 里，
     * 本文件**复用**它，绝不重新声明（那会立刻变成同名同包重复声明，见台账 §7.2.1）。
     */
    fun title(module: StatisticsAnalysisModule): String = when (module) {
        StatisticsAnalysisModule.TREND -> StatisticsExtStrings.statisticsTrendTitle.zh
        StatisticsAnalysisModule.TIME_UTIL -> StatisticsExtStrings.statisticsTimeUtilTitle.zh
        StatisticsAnalysisModule.VENUE -> StatisticsExtStrings.statisticsVenueTitle.zh
        StatisticsAnalysisModule.TEACHER -> StatisticsExtStrings.statisticsTeacherTitle.zh
        StatisticsAnalysisModule.RANKING -> StatisticsExtStrings.statisticsRankingTitle.zh
        StatisticsAnalysisModule.COMPARE -> StatisticsExtStrings.statisticsCompareTitle.zh
    }

    /** Dart `hasData = courses.isNotEmpty`：无课走空态，有课走列表。 */
    fun hasData(courseCount: Int): Boolean = courseCount > 0

    /** 整页列表里的一格（卡片或分段间距）。 */
    sealed interface AnalysisCell {
        /** 一张卡片。`standalone` 对应 Dart 里「独立二级页去掉卡内标题、读数放大」的那档。 */
        data class Card(val role: AnalysisCardRole, val standalone: Boolean = false) : AnalysisCell

        /** 分段间距（Dart `HyperosSectionGap()`）。 */
        data object Gap : AnalysisCell
    }

    /** 卡片角色：渲染层按它决定渲染哪张卡，模型层不关心卡片长什么样。 */
    enum class AnalysisCardRole {
        /** 每周课时趋势折线。 */
        TREND_CHART,

        /** 学期热力图。 */
        HEATMAP,

        /** 时间利用（早/午/晚/周末/空档）。 */
        TIME_UTILIZATION,

        /** 教室与教学楼。 */
        VENUE,

        /** 教师课时排行。 */
        TEACHER,

        /** 课程排行（可点进课程编辑）。 */
        RANKING,

        /** 课表对比（当前课表 vs 其它课表）。 */
        PROFILE_COMPARE,
    }

    /**
     * 模块 → 摆哪几块（Dart `_buildModuleContent` 的六个分支逐条对齐）。
     *
     * @param hasOtherProfiles 除当前课表外是否还有别的课表。Dart 的 COMPARE 分支
     *   只列出 `others`，没有别的课表时列表里只剩「当前课表」一条；入口本身由
     *   统计主页的 `analysisEntries(hasOtherProfiles)` 控制是否显示，这里保留参数
     *   是为了让「只有一条对比项」这种边界在单测里可见，而不是渲染层临时判空。
     */
    fun cells(
        module: StatisticsAnalysisModule,
        hasOtherProfiles: Boolean = true,
    ): List<AnalysisCell> = when (module) {
        // 趋势 = 折线 + 间距 + 热力图（Dart: TrendChart / HyperosSectionGap / SemesterHeatmapCard）
        StatisticsAnalysisModule.TREND -> listOf(
            AnalysisCell.Card(AnalysisCardRole.TREND_CHART),
            AnalysisCell.Gap,
            AnalysisCell.Card(AnalysisCardRole.HEATMAP),
        )

        // 下面四页都是「一张独立卡」，Dart 里 standalone = true 的那档。
        StatisticsAnalysisModule.TIME_UTIL -> listOf(
            AnalysisCell.Card(AnalysisCardRole.TIME_UTILIZATION, standalone = true),
        )
        StatisticsAnalysisModule.VENUE -> listOf(
            AnalysisCell.Card(AnalysisCardRole.VENUE, standalone = true),
        )
        // 教师页在 Dart 里是 `TeacherStatsCard(stats: teachers)`——**没有** standalone 参数，
        // 所以保留卡内标题。别照抄上面两页的 standalone。
        StatisticsAnalysisModule.TEACHER -> listOf(
            AnalysisCell.Card(AnalysisCardRole.TEACHER),
        )
        // 排行页是 `CourseRanking(courseRanking:, onCourseTap:)`——同样**没有** standalone 参数。
        StatisticsAnalysisModule.RANKING -> listOf(
            AnalysisCell.Card(AnalysisCardRole.RANKING),
        )

        // 对比页：只有一张对比卡；没有其它课表时它也照渲染（只剩当前课表一行）。
        StatisticsAnalysisModule.COMPARE -> listOf(
            AnalysisCell.Card(AnalysisCardRole.PROFILE_COMPARE, standalone = !hasOtherProfiles),
        )
    }

    /** 空态两行文案（Dart `HyperosEmptyState(title: statisticsNoData, subtitle: statisticsNoDataHint)`）。 */
    val emptyTitle: String get() = StatisticsExtStrings.statisticsNoData.zh
    val emptySubtitle: String get() = StatisticsExtStrings.statisticsNoDataHint.zh

    /**
     * 整页视图状态：渲染层入参（BRIEF §2 要求「入参是 viewState + 回调」）。
     *
     * 读数全部由调用方（宿主 / 上层模型）算好传进来，本类只做**装配**：
     * 标题、空态、卡片清单，以及各卡片的读数行文本。渲染层因此不碰 `StatisticsService`。
     *
     * 各读数行用 `Pair<String, String>`（左标签 / 右读数）而不是各自的 data class：
     * 这些行是纯展示文本，没有额外语义；六个模块共用一个形状能让渲染层只写一份 Row。
     */
    data class StatisticsAnalysisViewState(
        val title: String,
        val hasData: Boolean,
        val cells: List<AnalysisCell>,

        // ── 趋势页 ──
        val trend: List<com.mutx163.qingyu.statistics.WeeklyTrendPoint> = emptyList(),

        // ── 热力图 ──
        val heatmapMax: Int = 0,
        val heatmapSummary: String = "",

        // ── 时间利用 ──
        val timeUtilRows: List<Pair<String, String>> = emptyList(),

        // ── 教室与教学楼 ──
        val venueRows: List<Pair<String, String>> = emptyList(),

        // ── 教师排行 ──
        val teacherRows: List<Pair<String, String>> = emptyList(),

        // ── 课程排行（第一项是课程名，第二项是课时）──
        val rankingRows: List<Pair<String, String>> = emptyList(),

        // ── 课表对比 ──
        val compareRows: List<Pair<String, String>> = emptyList(),
    ) {
        val emptyTitle: String get() = StatisticsAnalysisModel.emptyTitle
        val emptySubtitle: String get() = StatisticsAnalysisModel.emptySubtitle
    }

    /**
     * 组装视图状态（模块 → 标题 + 卡片清单；读数由调用方填）。
     *
     * 这一层的存在意义是把「标题/空态/卡片清单」三件事一次性定下来，
     * 宿主只需要按模块喂读数，不必在每个调用点重复 `when`。
     */
    fun viewState(
        module: StatisticsAnalysisModule,
        courseCount: Int,
        hasOtherProfiles: Boolean = true,
        trend: List<com.mutx163.qingyu.statistics.WeeklyTrendPoint> = emptyList(),
        heatmapMax: Int = 0,
        heatmapSummary: String = "",
        timeUtilRows: List<Pair<String, String>> = emptyList(),
        venueRows: List<Pair<String, String>> = emptyList(),
        teacherRows: List<Pair<String, String>> = emptyList(),
        rankingRows: List<Pair<String, String>> = emptyList(),
        compareRows: List<Pair<String, String>> = emptyList(),
    ): StatisticsAnalysisViewState = StatisticsAnalysisViewState(
        title = title(module),
        hasData = hasData(courseCount),
        cells = cells(module, hasOtherProfiles),
        trend = trend,
        heatmapMax = heatmapMax,
        heatmapSummary = heatmapSummary,
        timeUtilRows = timeUtilRows,
        venueRows = venueRows,
        teacherRows = teacherRows,
        rankingRows = rankingRows,
        compareRows = compareRows,
    )

    // ────────────────────────────────────────────────────────────────────
    // 快照 → 六张卡的真实读数（纯逻辑，JVM 可测）
    // ────────────────────────────────────────────────────────────────────

    /**
     * 「课表对比」里的一份课表（从 `TimetableProfile` 换装出的纯数据）。
     *
     * 只取对比卡要用的四项：课表名、课程、当前周、学期总周数。
     */
    data class ProfileAnalysisInput(
        val name: String,
        val courses: List<Course>,
        val currentWeek: Int,
        val semesterWeekCount: Int,
    )

    /**
     * 把六张分析卡的**真实读数**一次算好（Dart `statistics_analysis_screen.dart:80-166`
     * 的 `_buildModuleContent` 逐模块对齐，读数全部来自 [StatisticsService]）。
     *
     * 壳（`e.analysis`）只负责把快照换成本函数的入参；页面的 `viewState` 原来只喂了
     * `module` 与 `courseCount`，其余参数全是默认空表 ⇒ 六张卡恒空（P0）。
     *
     * 标签文案全部取自既有 ARB（`ChartsStrings` / `StatisticsExtStrings`），不在这里
     * 新造中文；读数行形状仍是 `(标签, 读数)`，与渲染层 `TimeUtilRows` 等一致。
     *
     * @param courses 活动课表的课程（统计口径用 `CourseStub` 换装）。
     * @param currentWeek 当前周（`< 1` 时按 1 处理，与仓储/统计服务同口径）。
     * @param semesterWeekCount 学期总周数（`< 1` 时按 1 处理）。
     * @param hasOtherProfiles 除活动课表外是否还有别的课表（决定对比卡是否 standalone）。
     * @param activeProfileName 活动课表名；空串时对比卡第一行用 ARB「当前课表」。
     * @param otherProfiles 其余课表（对比页逐份算学期课时）。
     */
    fun analysisViewState(
        module: StatisticsAnalysisModule,
        courses: List<Course>,
        currentWeek: Int,
        semesterWeekCount: Int,
        hasOtherProfiles: Boolean = false,
        activeProfileName: String = "",
        otherProfiles: List<ProfileAnalysisInput> = emptyList(),
    ): StatisticsAnalysisViewState {
        val stubs = courses.map { it.toAnalysisStub() }
        val week = currentWeek.coerceAtLeast(1)
        val weekCount = semesterWeekCount.coerceAtLeast(1)
        return when (module) {
            StatisticsAnalysisModule.TREND -> {
                val trend = StatisticsService.calculateWeeklyTrend(stubs, weekCount)
                val heatmap = StatisticsService.calculateHeatmap(stubs, weekCount)
                viewState(
                    module = module,
                    courseCount = courses.size,
                    hasOtherProfiles = hasOtherProfiles,
                    trend = trend,
                    heatmapMax = heatmap.maxSections,
                    heatmapSummary = if (heatmap.maxSections > 0) {
                        ChartsStrings.statisticsHeatmapHint.zh
                    } else {
                        ""
                    },
                )
            }

            StatisticsAnalysisModule.TIME_UTIL -> {
                val stats = StatisticsService.calculateTimeUtilization(stubs, week)
                viewState(
                    module = module,
                    courseCount = courses.size,
                    hasOtherProfiles = hasOtherProfiles,
                    timeUtilRows = TimeUtilizationModel.facts(stats).map { it.label to it.value },
                )
            }

            StatisticsAnalysisModule.VENUE -> {
                val stats = StatisticsService.calculateVenueStats(stubs, week)
                viewState(
                    module = module,
                    courseCount = courses.size,
                    hasOtherProfiles = hasOtherProfiles,
                    venueRows = venueRowsOf(stats),
                )
            }

            StatisticsAnalysisModule.TEACHER -> {
                val stats = StatisticsService.calculateTeacherStats(stubs, week)
                viewState(
                    module = module,
                    courseCount = courses.size,
                    hasOtherProfiles = hasOtherProfiles,
                    teacherRows = TeacherStatsModel.rows(stats).map { row ->
                        "${row.rank}. ${row.name}" to "${row.courseCountLabel} · ${row.sectionsLabel}"
                    },
                )
            }

            StatisticsAnalysisModule.RANKING -> {
                val semester = StatisticsService.calculateSemester(stubs, week, weekCount)
                val unit = ChartsStrings.statisticsSectionsUnit.zh
                viewState(
                    module = module,
                    courseCount = courses.size,
                    hasOtherProfiles = hasOtherProfiles,
                    rankingRows = CourseRankingModel.build(semester.courseRanking).map { row ->
                        row.name to "${row.totalSections} $unit"
                    },
                )
            }

            StatisticsAnalysisModule.COMPARE -> {
                val activeTotal = StatisticsService
                    .calculateSemester(stubs, week, weekCount)
                    .totalSections
                viewState(
                    module = module,
                    courseCount = courses.size,
                    hasOtherProfiles = hasOtherProfiles,
                    compareRows = compareRowsOf(
                        activeTotal = activeTotal,
                        activeName = activeProfileName,
                        others = otherProfiles,
                    ),
                )
            }
        }
    }

    /** 教室与教学楼：两组读数各带一个分组标题（标题文案来自既有 ARB）。 */
    private fun venueRowsOf(stats: VenueStats): List<Pair<String, String>> {
        val bars = VenueStatsModel.bars(stats)
        val rows = mutableListOf<Pair<String, String>>()
        if (bars.rooms.isNotEmpty()) {
            rows.add(ChartsStrings.statisticsVenueTopRooms.zh to "")
            for (row in bars.rooms) rows.add(row.label to row.value)
        }
        if (bars.buildings.isNotEmpty()) {
            rows.add(ChartsStrings.statisticsVenueBuildings.zh to "")
            for (row in bars.buildings) rows.add(row.label to row.value)
        }
        return rows
    }

    /**
     * 课表对比读数：第一行是当前课表（学期总课时），之后每行一份其它课表，
     * 读数是「较当前 ±N 节」（Dart `ProfileCompareEntry.deltaSections`，`isActive` 行为课时）。
     */
    private fun compareRowsOf(
        activeTotal: Int,
        activeName: String,
        others: List<ProfileAnalysisInput>,
    ): List<Pair<String, String>> {
        val unit = ChartsStrings.statisticsSectionsUnit.zh
        val rows = mutableListOf<Pair<String, String>>()
        rows.add(
            (activeName.ifBlank { ChartsStrings.statisticsCompareActive.zh }) to "$activeTotal $unit",
        )
        for (profile in others) {
            val total = StatisticsService.calculateSemester(
                allCourses = profile.courses.map { it.toAnalysisStub() },
                currentWeek = profile.currentWeek.coerceAtLeast(1),
                semesterWeekCount = profile.semesterWeekCount.coerceAtLeast(1),
            ).totalSections
            val delta = total - activeTotal
            val deltaText = if (delta > 0) "+$delta" else delta.toString()
            rows.add(profile.name to ChartsStrings.statisticsCompareDelta.filled("delta", deltaText))
        }
        return rows
    }

    /** `core.Course` → 统计口径 `CourseStub`（与 `CourseStatisticsLogic` 内部那份同口径）。 */
    private fun Course.toAnalysisStub(): CourseStub = CourseStub(
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
}
