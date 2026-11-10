package com.mutx163.qingyu.pages.statistics

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.mutx163.qingyu.pages.statistics.charts.WeekStatsView
import com.mutx163.qingyu.pages.timetable.WeekSelectorSheet
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuEmptyState
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.pages.statistics.charts.AchievementModel
import com.mutx163.qingyu.pages.statistics.charts.BarChartCanvas
import com.mutx163.qingyu.pages.statistics.charts.BarEmphasis
import com.mutx163.qingyu.pages.statistics.charts.ChartAxisLabelRow
import com.mutx163.qingyu.pages.statistics.charts.ChartIconBadge
import com.mutx163.qingyu.pages.statistics.charts.ChartLeftAxisLabels
import com.mutx163.qingyu.pages.statistics.charts.ChartPalette
import com.mutx163.qingyu.pages.statistics.charts.DailyChartModel
import com.mutx163.qingyu.pages.statistics.charts.DonutRingCanvas
import com.mutx163.qingyu.pages.statistics.charts.achievementAccentColor
import com.mutx163.qingyu.pages.statistics.charts.achievementIconVector
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.TabRowWithContour
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Community
import top.yukonga.miuix.kmp.icon.extended.Location
import top.yukonga.miuix.kmp.icon.extended.Notes
import top.yukonga.miuix.kmp.icon.extended.Replace
import top.yukonga.miuix.kmp.icon.extended.Report
import top.yukonga.miuix.kmp.icon.extended.Settings
import top.yukonga.miuix.kmp.icon.extended.Share
import top.yukonga.miuix.kmp.icon.extended.Timer
import top.yukonga.miuix.kmp.icon.extended.TopDownloads
import top.yukonga.miuix.kmp.preference.ArrowPreference
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 课程统计主页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/course_statistics_screen.dart`（账单式：学期 / 周 双视图）：
 * - 顶栏：返回 + "课程统计"；**有数据时**才出现设置与分享两个动作；
 * - 学期视图：分段 → 总览四格 → 学期进度 → 本周小结 → 成就徽章 →
 *   （有故事时）数据故事 → 每日课时分布 → 必修/选修 → 深度分析入口组；
 * - 周视图：分段 → 完整周视图（周选择器 + 本周小结 + 每日课时分布 + 必/选修比例 + 时间利用 + 课程明细）；
 * - 成就徽章：点击徽章呼出详情弹层（OverlayBottomSheet）；
 * - 无课程时是空态（图标 + "暂无课程数据" + "添加课程后即可查看统计"）。
 *
 * 数据口径全部来自 [CourseStatisticsViewState]（模型层已算好），这里只画。
 *
 * ## 版式（2026-10-28 按页面样式规则 R1..R6 重排）
 *
 * 原先自己 `Scaffold + TopAppBar + Column + verticalScroll`，并写了 36 处字面量字号
 * 与 4 处写死颜色。现在：顶栏/返回键/折叠行为走 [QingyuPageScaffold]（R1）；
 * 主滚动走 [QingyuPageList]（R2，惰性列表 + 滚动条 + 末端触感）；
 * 卡片走 [QingyuCard]（R3，按压反馈 + 语义圆角）；分组标题走 [QingyuSectionTitle]（R6）。
 *
 * ### 字号映射（R4）
 *
 * 官方字阶只有 11 / 13 / 14 / 16 / 17 / 18 / 20 / 24 / 32 这几档，本页原先用的
 * 10 / 11 / 12 / 13 / 14 / 15 / 16 / 18 / 24 里有几个不在档上，按下表就近落到字阶：
 *
 * | 原值 | 字阶 | 说明 |
 * |---|---|---|
 * | 10 / 11 / 12 | `footnote2`(11) | 卡内说明、轴标签、徽标小字 |
 * | 13 | `footnote1`(13) | 空态提示、无数据文案 |
 * | 14 | `body2`(14) | 正文、图例、故事内容 |
 * | 15 | `main`(17) | 卡片/行标题：Dart 对应 `listTitle` = 17（`hyperos_miuix_spec.dart:80`），
 * 且本仓行标题的既有约定也是 `main` |
 * | 16 | `body1`(16) | 空态标题、徽章星标 |
 * | 18 | `title4`(18) | 中号读数（Dart `metricMedium` = 18） |
 * | 24 | `title2`(24) | 大号读数（Dart `metricLarge` = 24） |
 */
@Composable
fun CourseStatisticsPage(
    viewState: CourseStatisticsViewState,
    onBack: () -> Unit,
    onTabSelected: (Int) -> Unit,
    onOpenSettings: () -> Unit,
    /**
     * 分享统计成果图；`null` = 本端还没有这项能力（当前 Kotlin 侧缺「光栅化 + 系统分享」）。
     *
     * 2026-10-30 质量审核 P0-4：原先壳传 `onOpenShare = {}`，图标照常显示、点了什么都不发生。
     * 按本仓既定口径（`CourseActionSheetModel` 对「单节课提醒」一行同款）：
     * **与其画一个点了没反应的入口，不如诚实地不画**。
     */
    onOpenShare: (() -> Unit)? = null,
    onWeekChanged: (Int) -> Unit,
    onOpenAnalysis: (StatisticsAnalysisModule) -> Unit,
    onOpenSessions: () -> Unit,
    isExporting: Boolean = false,
) {
    val dark = isSystemInDarkTheme()
    var activeAchievementDetail by remember { mutableStateOf<AchievementView?>(null) }
    // 周次选择弹层（2026-11-05 审核修复：复用 timetable 域现成的 [WeekSelectorSheet]，
    // 替换「点一下 +1、到头回 1」的循环——卡片右侧箭头本来就是「展开选周」的语义，
    // 与 Dart `_showPicker`（`week_selector_picker_sheet.dart`）同口径）。
    var showWeekPicker by remember { mutableStateOf(false) }
    // 分段切换时列表会保留滚动位置：学期视图滚到深处再切到周视图，
    // 周视图只剩 1 个 item，会停在中段而不是从头看。切分段就回到顶部。
    val listState = rememberLazyListState()
    LaunchedEffect(viewState.selectedTabIndex) { listState.scrollToItem(0) }

    // 顶栏 / 返回键 / 折叠行为 / 容器底色统一走共享骨架（规则 R1）。
    // Dart 原件 lib/screens/course_statistics_screen.dart:122 走 HyperosSubpage，
    // collapsibleLargeTitle 默认 true ⇒ 用骨架的默认变体（可折叠大标题）。
    QingyuPageScaffold(
        title = viewState.title,
        onBack = onBack,
        actions = {
            if (viewState.showHeaderActions) {
                IconButton(onClick = onOpenSettings) {
                    Icon(
                        imageVector = MiuixIcons.Settings,
                        contentDescription = StatisticsStrings.statisticsSettingsTitle.text,
                        tint = Color(QingyuTheme.actionIcon(dark)),
                    )
                }
                if (onOpenShare != null) {
                    IconButton(onClick = { if (!isExporting) onOpenShare.invoke() }) {
                        Icon(
                            imageVector = MiuixIcons.Share,
                            contentDescription = StatisticsStrings.statisticsShareLabel.text,
                            tint = Color(QingyuTheme.actionIcon(dark)),
                        )
                    }
                }
            }
        },
    ) {
        if (!viewState.hasData) {
            // 空态自己不吃内边距，这里补一层，免得内容钻到顶栏底下。
            // 方案 C09：发布版 `course_statistics_screen.dart:336-345` 走共享构件（17/14）。
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding),
                contentAlignment = Alignment.Center,
            ) {
                QingyuEmptyState(
                    icon = MiuixIcons.Report,
                    title = viewState.emptyTitle,
                    description = viewState.emptyHint,
                )
            }
        } else {
            // 官方页面骨架（规则 R2）：惰性列表 + 右侧滚动条 + 末端触感 + 顶栏折叠联动。
            // 横向 12dp 是卡片外边距；卡内统一 16dp、分组标题也传 16dp 横向，
            // 于是「卡片文字 / 分组标题」左缘都是 12+16=28（官方轴线）。
            QingyuPageList(
                innerPadding = innerPadding,
                state = listState,
                scrollBehavior = scrollBehavior,
                horizontalPadding = QingyuPageCardMargin,
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item(key = "tabs") {
                    // Dart `course_statistics_screen.dart:194-207` 用 HyperosTabRow，
                    // 默认 contour 样式 ⇒ 官方 `TabRowWithContour`（超椭圆轨道 +
                    // 连续滑动指示器 + 「第几个/共几个」语义）。原先手拼 Box+clickable
                    // 属于自研交互，热区也只有约 36dp。
                    TabRowWithContour(
                        tabs = viewState.tabs,
                        selectedTabIndex = viewState.selectedTabIndex,
                        onTabSelected = onTabSelected,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 6.dp),
                    )
                }

                val semester = viewState.semester
                if (viewState.selectedTabIndex == 0 && semester != null) {
                    item(key = "overview") { OverviewCard(metrics = semester.overview, dark = dark) }
                    item(key = "semesterProgress") {
                        SemesterProgressCard(view = semester.progress, dark = dark)
                    }
                    item(key = "weeklyComparison") {
                        WeeklyComparisonCard(view = semester.comparison, dark = dark)
                    }
                    item(key = "achievements") {
                        SectionBlock(StatisticsStrings.statisticsAchievementsTitle.text) {
                            AchievementGrid(
                                achievements = semester.achievements,
                                dark = dark,
                                onAchievementClick = { activeAchievementDetail = it },
                            )
                        }
                    }
                    if (semester.showStoriesSection) {
                        item(key = "stories") {
                            SectionBlock(StatisticsStrings.statisticsStoriesTitle.text) {
                                StoryList(stories = semester.stories, dark = dark)
                            }
                        }
                    }
                    item(key = "dailyDistribution") {
                        SectionBlock(StatisticsStrings.statisticsDailyDistribution.text) {
                            // 与周视图、导出图共用同一套柱图内核：网格按整数节、
                            // 纵轴上限 = 最大均值 + 1、柱宽/圆角/强调档全部同源。
                            val spec = semester.dailyChart
                            if (spec != null && spec.bars.isNotEmpty()) {
                                Row(modifier = Modifier.fillMaxWidth()) {
                                    ChartLeftAxisLabels(
                                        maxY = spec.maxY,
                                        interval = spec.leftInterval,
                                        heightDp = DailyChartModel.AVERAGE_CHART_HEIGHT_DP,
                                        widthDp = DailyChartModel.AVERAGE_LEFT_RESERVE_DP,
                                        dark = dark,
                                    )
                                    Column(modifier = Modifier.weight(1f)) {
                                        BarChartCanvas(
                                            spec = spec,
                                            dark = dark,
                                            chartHeightDp = DailyChartModel.AVERAGE_CHART_HEIGHT_DP,
                                        )
                                        ChartAxisLabelRow(
                                            labels = spec.bars.map { it.label },
                                            dark = dark,
                                            highlightIndex = spec.bars
                                                .indexOfFirst { it.emphasis == BarEmphasis.MAX }
                                                .takeIf { it >= 0 },
                                        )
                                    }
                                }
                            }
                        }
                    }
                    item(key = "natureRatio") {
                        SectionBlock(StatisticsStrings.statisticsNatureRatio.text) {
                            NatureRatioBlock(view = semester.nature, dark = dark)
                        }
                    }
                    item(key = "more") {
                        // 行内是官方 ArrowPreference（自带 16dp 内边距与按压反馈），
                        // 卡片只留 2dp 呼吸位，避免叠成 32dp。
                        SectionBlock(
                            title = StatisticsStrings.statisticsMoreTitle.text,
                            insideMargin = PaddingValues(vertical = 2.dp),
                        ) {
                            AnalysisEntryList(
                                entries = viewState.analysisEntries,
                                onOpenAnalysis = onOpenAnalysis,
                                onOpenSessions = onOpenSessions,
                                dark = dark,
                            )
                        }
                    }
                } else {
                    val week = viewState.week
                    if (week != null) {
                        item(key = "week") {
                            val weeklyStats = week.weeklyStats
                            val comparison = week.comparison
                            if (weeklyStats != null && comparison != null) {
                                WeekStatsView(
                                    stats = weeklyStats,
                                    currentSemesterWeek = viewState.currentWeek,
                                    comparison = comparison,
                                    dark = dark,
                                    timeUtilization = week.timeUtilization,
                                    onWeekSelectorClick = { showWeekPicker = true },
                                )
                            } else {
                                WeekOverviewCard(
                                    week = week,
                                    currentWeek = viewState.currentWeek,
                                    onWeekChanged = onWeekChanged,
                                    dark = dark,
                                )
                            }
                        }
                    }
                }
            }
        }

        AchievementDetailSheet(
            achievement = activeAchievementDetail,
            dark = dark,
            onDismiss = { activeAchievementDetail = null },
        )

        // 周次选择弹层：可选周 = 1..学期总周数（Dart `settings.availableWeeks` 同口径），
        // 「回本周」由弹层内部按 currentSemesterWeek 自行显隐（TimetableWeekPage 同款接线）。
        WeekSelectorSheet(
            show = showWeekPicker,
            availableWeeks = (1..viewState.semesterWeekCount).toList(),
            visibleWeek = viewState.selectedWeek,
            currentSemesterWeek = viewState.currentWeek,
            onDismiss = { showWeekPicker = false },
            onSelect = { week ->
                showWeekPicker = false
                if (week != viewState.selectedWeek) onWeekChanged(week)
            },
        )
    }
}

// ── 分组块（HyperosSettingsBlock = 块头 + 卡片） ──

/**
 * 一个「分组块」：官方 `SmallTitle` 分组标题 + 一张卡片。
 *
 * 标题不再自己拼 `Text(13sp) + padding(start = 4.dp)`——那对不齐官方那条
 * 「页面 0 → Card 12 → Preference 16 = 文字左缘 28」的轴线（规则 R6），
 * 改走 [QingyuSectionTitle]（内部就是官方 `SmallTitle`，自带 28dp 左缘）。
 */
@Composable
private fun SectionBlock(
    title: String,
    insideMargin: PaddingValues = PaddingValues(16.dp),
    content: @Composable () -> Unit,
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        // 列表已统一加 12dp：标题再缩 16dp ⇒ 文字左缘 28，与卡内 16dp 对齐。
        QingyuSectionTitle(
            text = title,
            insideMargin = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
        )
        QingyuCard(modifier = Modifier.fillMaxWidth(), insideMargin = insideMargin) {
            content()
        }
    }
}

// ── 学期总览：四格指标 + 细分隔线 ──

@Composable
private fun OverviewCard(metrics: List<StatisticsMetricView>, dark: Boolean) {
    if (metrics.isEmpty()) return
    QingyuCard(modifier = Modifier.fillMaxWidth(), insideMargin = PaddingValues(16.dp)) {
        Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            metrics.forEachIndexed { index, metric ->
                if (index > 0) {
                    Box(
                        modifier = Modifier
                            .width(1.dp)
                            .height(28.dp)
                            .background(Color(QingyuTheme.dividerLine(dark))),
                    )
                }
                Column(
                    modifier = Modifier.weight(1f),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        text = metric.value,
                        style = MiuixTheme.textStyles.title2.shiftWeight(QingyuWeightDelta.MEDIUM),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        color = if (metric.highlight) {
                            Color(QingyuTheme.primary(dark = dark))
                        } else {
                            Color(QingyuTheme.primaryText(dark))
                        },
                    )
                    Text(
                        text = metric.label,
                        style = MiuixTheme.textStyles.footnote2,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        color = if (metric.highlight) {
                            Color(QingyuTheme.primaryText(dark))
                        } else {
                            Color(QingyuTheme.secondaryText(dark))
                        },
                        modifier = Modifier.padding(top = 5.dp),
                    )
                }
            }
        }
    }
}

// ── 学期进度卡 ──

@Composable
private fun SemesterProgressCard(view: SemesterProgressView, dark: Boolean) {
    val primary = Color(QingyuTheme.primary(dark = dark))
    QingyuCard(modifier = Modifier.fillMaxWidth(), insideMargin = PaddingValues(16.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = view.title,
                style = MiuixTheme.textStyles.main.shiftWeight(QingyuWeightDelta.MEDIUM),
                color = Color(QingyuTheme.primaryText(dark)),
                modifier = Modifier.weight(1f),
            )
            Text(
                text = view.weekLabel,
                style = MiuixTheme.textStyles.main.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                color = primary,
            )
        }
        if (view.rangeLabel != null) {
            Text(
                text = view.rangeLabel,
                style = MiuixTheme.textStyles.footnote2,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                color = Color(QingyuTheme.secondaryText(dark)),
                modifier = Modifier.padding(top = 6.dp),
            )
        }
        // 进度条（Canvas 手绘，避免 fillMaxWidth(0f) 的边界问题）
        val trackColor = Color(QingyuTheme.dividerLine(dark))
        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 12.dp)
                .height(6.dp),
        ) {
            val radius = size.height / 2f
            drawRoundRect(
                color = trackColor,
                size = size,
                cornerRadius = androidx.compose.ui.geometry.CornerRadius(radius),
            )
            val fraction = view.percent.coerceIn(0.0, 1.0).toFloat()
            if (fraction > 0f) {
                drawRoundRect(
                    color = primary,
                    size = Size(size.width * fraction, size.height),
                    cornerRadius = androidx.compose.ui.geometry.CornerRadius(radius),
                )
            }
        }
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 10.dp),
            verticalAlignment = Alignment.Bottom,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = view.percentText,
                    style = MiuixTheme.textStyles.title4.shiftWeight(QingyuWeightDelta.MEDIUM),
                    color = Color(QingyuTheme.primaryText(dark)),
                )
                Text(
                    text = view.detailLabel,
                    style = MiuixTheme.textStyles.footnote2,
                    maxLines = 2,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    modifier = Modifier.padding(top = 2.dp),
                )
            }
            if (view.remainingLabel != null && view.factLabel != null) {
                Column(
                    modifier = Modifier.weight(1f),
                    horizontalAlignment = Alignment.End,
                ) {
                    Text(
                        text = view.remainingLabel,
                        style = MiuixTheme.textStyles.title4.shiftWeight(QingyuWeightDelta.MEDIUM),
                        textAlign = TextAlign.End,
                        color = Color(QingyuTheme.primaryText(dark)),
                    )
                    Text(
                        text = view.factLabel,
                        style = MiuixTheme.textStyles.footnote2,
                        maxLines = 2,
                        textAlign = TextAlign.End,
                        color = Color(QingyuTheme.secondaryText(dark)),
                        modifier = Modifier.padding(top = 2.dp),
                    )
                }
            }
        }
    }
}

// ── 本周小结 ──

@Composable
private fun WeeklyComparisonCard(view: WeeklyComparisonView, dark: Boolean) {
    val deltaColor = when (view.deltaTone) {
        DeltaTone.UP -> Color(QingyuTheme.error(dark))
        DeltaTone.DOWN -> Color(QingyuTheme.success(dark))
        DeltaTone.FLAT -> Color(QingyuTheme.secondaryText(dark))
    }
    QingyuCard(modifier = Modifier.fillMaxWidth(), insideMargin = PaddingValues(16.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = view.title,
                style = MiuixTheme.textStyles.main.shiftWeight(QingyuWeightDelta.MEDIUM),
                color = Color(QingyuTheme.primaryText(dark)),
                modifier = Modifier.weight(1f),
            )
            Text(
                text = view.weekLabel,
                style = MiuixTheme.textStyles.footnote2,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            ComparisonCell(
                value = view.weekSectionsValue,
                label = view.weekSectionsLabel,
                accent = Color(QingyuTheme.primary(dark = dark)),
                labelColor = Color(QingyuTheme.primaryText(dark)),
                alignEnd = false,
                modifier = Modifier.weight(1f),
            )
            ComparisonCell(
                value = view.deltaValue,
                label = view.deltaLabel,
                accent = deltaColor,
                labelColor = Color(QingyuTheme.secondaryText(dark)),
                alignEnd = false,
                modifier = Modifier.weight(1f),
            )
            ComparisonCell(
                value = view.averageValue,
                label = view.averageLabel,
                accent = ChartPalette.Teal,
                labelColor = Color(QingyuTheme.secondaryText(dark)),
                alignEnd = true,
                modifier = Modifier.weight(1f),
            )
        }
        if (view.newSemesterHint != null) {
            Text(
                text = view.newSemesterHint,
                style = MiuixTheme.textStyles.footnote2,
                color = Color(QingyuTheme.secondaryText(dark)),
                modifier = Modifier.padding(top = 8.dp),
            )
        }
    }
}

@Composable
private fun ComparisonCell(
    value: String,
    label: String,
    accent: Color,
    labelColor: Color,
    alignEnd: Boolean,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier, horizontalAlignment = if (alignEnd) Alignment.End else Alignment.Start) {
        Text(
            text = value,
            style = MiuixTheme.textStyles.title2.shiftWeight(QingyuWeightDelta.MEDIUM),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            textAlign = if (alignEnd) TextAlign.End else TextAlign.Start,
            color = accent,
        )
        Text(
            text = label,
            style = MiuixTheme.textStyles.footnote2,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            textAlign = if (alignEnd) TextAlign.End else TextAlign.Start,
            color = labelColor,
            modifier = Modifier.padding(top = 5.dp),
        )
    }
}

// ── 成就徽章（4 列） ──

@Composable
private fun AchievementGrid(
    achievements: List<AchievementView>,
    dark: Boolean,
    onAchievementClick: (AchievementView) -> Unit,
) {
    if (achievements.isEmpty()) return
    val columns = 4
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        achievements.chunked(columns).forEach { rowItems ->
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                rowItems.forEach { item ->
                    AchievementBadge(
                        item = item,
                        dark = dark,
                        onClick = { onAchievementClick(item) },
                        modifier = Modifier.weight(1f),
                    )
                }
                // 补齐末行，保持列宽一致
                repeat(columns - rowItems.size) {
                    Spacer(modifier = Modifier.weight(1f))
                }
            }
        }
    }
}

@Composable
private fun AchievementBadge(
    item: AchievementView,
    dark: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    // Dart `achievement_badge.dart:344-360`：每枚成就按 id 取语义色（橙/绿/紫/黄/
    // 蓝/青/靛/红），锁定态用同一色的淡底 + 描边，而不是全部灰色。
    // 映射与共享徽章层 `AchievementModel.accentOf` 同源。
    val accent = achievementAccentColor(AchievementModel.accentOf(item.id))
    val fill = if (item.isUnlocked) {
        accent
    } else {
        accent.copy(
            alpha = if (dark) AchievementModel.LOCKED_FILL_DARK else AchievementModel.LOCKED_FILL_LIGHT,
        )
    }
    val lockBorder = accent.copy(
        alpha = if (dark) AchievementModel.LOCKED_BORDER_DARK else AchievementModel.LOCKED_BORDER_LIGHT,
    )
    val lockIcon = accent.copy(
        alpha = if (dark) AchievementModel.LOCKED_ICON_DARK else AchievementModel.LOCKED_ICON_LIGHT,
    )
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(8.dp))
            .clickable(onClick = onClick)
            .padding(vertical = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(fill)
                .then(
                    if (item.isUnlocked) {
                        Modifier
                    } else {
                        Modifier.border(
                            width = 1.dp,
                            color = lockBorder,
                            shape = RoundedCornerShape(12.dp),
                        )
                    },
                ),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = achievementIconVector(AchievementModel.iconOf(item.id)),
                contentDescription = null,
                tint = if (item.isUnlocked) Color(QingyuTheme.onAccent(dark)) else lockIcon,
                modifier = Modifier.size(20.dp),
            )
        }
        Text(
            text = item.name,
            style = MiuixTheme.textStyles.footnote2,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.Center,
            color = if (item.isUnlocked) {
                Color(QingyuTheme.primaryText(dark))
            } else {
                Color(QingyuTheme.secondaryText(dark))
            },
            modifier = Modifier.padding(top = 6.dp),
        )
        if (item.progressLabel != null) {
            Text(
                text = item.progressLabel,
                style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.MEDIUM),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.Center,
                color = if (item.isUnlocked) accent else Color(QingyuTheme.secondaryText(dark)),
                modifier = Modifier.padding(top = 2.dp),
            )
        }
    }
}

// ── 数据故事（** 片段加粗） ──

@Composable
private fun StoryList(stories: List<StoryView>, dark: Boolean) {
    Column(modifier = Modifier.fillMaxWidth()) {
        stories.forEachIndexed { index, story ->
            if (index > 0) {
                // 原行间细线删掉（官方 demo 行列表无线），块间用 20dp 间距承接原线上下的 10+10dp。
                Spacer(modifier = Modifier.height(20.dp))
            }
            Text(
                text = story.title,
                style = MiuixTheme.textStyles.footnote2,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
            Text(
                text = boldSegments(story.content),
                style = MiuixTheme.textStyles.body2,
                lineHeight = 19.sp,
                color = Color(QingyuTheme.primaryText(dark)),
                modifier = Modifier.padding(top = 2.dp),
            )
        }
    }
}

/** ARB 正文里的 `**text**` 加粗片段（对齐 Dart `_buildRichContent`）。 */
// 顶层预编译：boldSegments 直接写在 Text(text = …) 的组合路径里，原先每次重组
// 都重新 new 一个 Regex 再全文扫描；正则与输入无关，提为常量只编一次。
private val BOLD_SEGMENT_PATTERN = Regex("""\*\*(.*?)\*\*""")

/** 把 ARB 正文里的 `**text**` 解析成加粗片段（对齐 Dart `_buildRichContent`）。 */
private fun boldSegments(content: String): AnnotatedString = buildAnnotatedString {
    var lastEnd = 0
    for (match in BOLD_SEGMENT_PATTERN.findAll(content)) {
        if (match.range.first > lastEnd) {
            append(content.substring(lastEnd, match.range.first))
        }
        pushStyle(SpanStyle().shiftWeight(QingyuWeightDelta.SEMIBOLD))
        append(match.groupValues[1])
        pop()
        lastEnd = match.range.last + 1
    }
    if (lastEnd < content.length) {
        append(content.substring(lastEnd))
    }
}

// ── 必修 / 选修 ──

@Composable
private fun NatureRatioBlock(view: NatureRatioView, dark: Boolean) {
    if (!view.hasData) {
        Text(
            text = StatisticsStrings.statisticsNoData.text,
            style = MiuixTheme.textStyles.footnote1,
            color = Color(QingyuTheme.secondaryText(dark)),
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 12.dp),
            textAlign = TextAlign.Center,
        )
        return
    }
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        Box(modifier = Modifier.size(100.dp), contentAlignment = Alignment.Center) {
            // 与周视图共用同一个环图内核（环厚 20 / 孔 28、缺失侧 18/32、2° 段间隙，
            // 单侧为 0 时补 12% 占位弧）。不再从格式化后的百分比反解弧角。
            DonutRingCanvas(
                requiredCount = view.requiredCount,
                electiveCount = view.electiveCount,
                modifier = Modifier.size(100.dp),
            )
            if (view.missingLabel != null) {
                Text(
                    text = view.missingLabel,
                    style = MiuixTheme.textStyles.footnote2,
                    textAlign = TextAlign.Center,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    modifier = Modifier
                        .semantics { contentDescription = view.missingLabel }
                        .padding(horizontal = 6.dp),
                )
            }
        }
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            view.legend.forEach { legend ->
                val color = if (legend.isRequired) ChartPalette.Blue else ChartPalette.Purple
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .size(12.dp)
                            .clip(RoundedCornerShape(4.dp))
                            .background(color),
                    )
                    Column(
                        modifier = Modifier
                            .weight(1f)
                            .padding(start = 8.dp),
                    ) {
                        Text(
                            text = legend.label,
                            style = MiuixTheme.textStyles.body2,
                            color = Color(QingyuTheme.primaryText(dark)),
                        )
                        Text(
                            text = legend.detail,
                            style = MiuixTheme.textStyles.footnote2,
                            color = Color(QingyuTheme.secondaryText(dark)),
                        )
                    }
                    Text(
                        text = legend.ratioText,
                        style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                        color = color,
                    )
                }
            }
        }
    }
}

// ── 深度分析入口组 ──

@Composable
private fun AnalysisEntryList(
    entries: List<StatisticsAnalysisEntry>,
    onOpenAnalysis: (StatisticsAnalysisModule) -> Unit,
    onOpenSessions: () -> Unit,
    dark: Boolean,
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        entries.forEachIndexed { index, entry ->
            // Dart 每行是 `HyperosListTile(icon, iconAccent)`：实色图标徽章 +
            // 官方按压反馈。原先手搓 Row + clickable 既丢了七种语义色，也没有
            // 按下反馈；ArrowPreference 自带 16dp 内边距、右箭头与无障碍角色。
            ArrowPreference(
                title = entry.title,
                onClick = {
                    when (val target = entry.target) {
                        is StatisticsEntryTarget.Sessions -> onOpenSessions()
                        is StatisticsEntryTarget.Analysis -> onOpenAnalysis(target.module)
                    }
                },
                startAction = {
                    ChartIconBadge(
                        icon = iconFor(entry.target),
                        accent = accentFor(entry.target),
                        dark = dark,
                    )
                },
            )
        }
    }
}

/** Dart `_buildAnalysisEntries` 的 `iconAccent`：teal / blue / cyan / purple / green / orange / indigo。 */
private fun accentFor(target: StatisticsEntryTarget): Color = when (target) {
    is StatisticsEntryTarget.Sessions -> ChartPalette.Teal
    is StatisticsEntryTarget.Analysis -> when (target.module) {
        StatisticsAnalysisModule.TREND -> ChartPalette.Blue
        StatisticsAnalysisModule.TIME_UTIL -> ChartPalette.Cyan
        StatisticsAnalysisModule.VENUE -> ChartPalette.Purple
        StatisticsAnalysisModule.TEACHER -> ChartPalette.Green
        StatisticsAnalysisModule.RANKING -> ChartPalette.Orange
        StatisticsAnalysisModule.COMPARE -> ChartPalette.Indigo
    }
}

private fun iconFor(target: StatisticsEntryTarget) = when (target) {
    is StatisticsEntryTarget.Sessions -> MiuixIcons.Notes
    is StatisticsEntryTarget.Analysis -> when (target.module) {
        StatisticsAnalysisModule.TREND -> MiuixIcons.Report
        StatisticsAnalysisModule.TIME_UTIL -> MiuixIcons.Timer
        StatisticsAnalysisModule.VENUE -> MiuixIcons.Location
        StatisticsAnalysisModule.TEACHER -> MiuixIcons.Community
        StatisticsAnalysisModule.RANKING -> MiuixIcons.TopDownloads
        StatisticsAnalysisModule.COMPARE -> MiuixIcons.Replace
    }
}

// ── 周视图（简化：仅总量口径，图表件待补） ──

@Composable
private fun WeekOverviewCard(
    week: WeekContent,
    currentWeek: Int,
    onWeekChanged: (Int) -> Unit,
    dark: Boolean,
) {
    QingyuCard(modifier = Modifier.fillMaxWidth(), insideMargin = PaddingValues(16.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = StatisticsStrings.statisticsWeekSelector.filled("week", week.weekNumber.toString()),
                style = MiuixTheme.textStyles.main.shiftWeight(QingyuWeightDelta.MEDIUM),
                color = Color(QingyuTheme.primaryText(dark)),
                modifier = Modifier.weight(1f),
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                if (week.weekNumber > 1) {
                    Text(
                        text = "‹",
                        style = MiuixTheme.textStyles.title4,
                        color = Color(QingyuTheme.primary(dark = dark)),
                        modifier = Modifier
                            .clickable { onWeekChanged(week.weekNumber - 1) }
                            .padding(horizontal = 8.dp),
                    )
                }
                if (week.weekNumber < week.maxWeek) {
                    Text(
                        text = "›",
                        style = MiuixTheme.textStyles.title4,
                        color = Color(QingyuTheme.primary(dark = dark)),
                        modifier = Modifier
                            .clickable { onWeekChanged(week.weekNumber + 1) }
                            .padding(horizontal = 8.dp),
                    )
                }
            }
        }
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            ComparisonCell(
                value = week.courseCount.toString(),
                label = StatisticsStrings.statisticsCourseCount.text,
                accent = Color(QingyuTheme.primaryText(dark)),
                labelColor = Color(QingyuTheme.secondaryText(dark)),
                alignEnd = false,
                modifier = Modifier.weight(1f),
            )
            ComparisonCell(
                value = week.sectionCount.toString(),
                label = StatisticsStrings.statisticsSectionCount.text,
                accent = Color(QingyuTheme.primary(dark = dark)),
                labelColor = Color(QingyuTheme.secondaryText(dark)),
                alignEnd = false,
                modifier = Modifier.weight(1f),
            )
        }
        Text(
            text = StatisticsStrings.statisticsWeekSelector.filled("week", currentWeek.toString()),
            style = MiuixTheme.textStyles.footnote2,
            color = Color(QingyuTheme.secondaryText(dark)),
            modifier = Modifier.padding(top = 8.dp),
        )
    }
}

// 图表语义色统一走 `charts/ChartPrimitives.kt` 的 `ChartPalette` / `ChartMath`：
// 本页原先自己抄过一份 `QingyuIconColors` 常量，和周视图各写一套，
// 于是同一个「必修/选修」在两处会取到不同来源。现在只保留一个出处。

// ── 预览 ──────────────────────────────────────────────────────────────────────
//
// 状态全部由真模型函数算：课程是普通 [com.mutx163.qingyu.core.Course]，装配走
// `CourseStatisticsLogic.buildViewState(...)`（内部又调 `StatisticsService` 算学期/周/成就/
// 数据故事），预览里不手写一份假的读数。
//
// `Course` / `CourseNature` 与 `LocalDate` 用全限定名：本文件的 import 块按预览约定只允许
// 动三行（`Preview` / `QingyuPageTheme` / 总览布局件），不为预览扩大 import 面。

/** 预览基准时刻：2026-11-08（第 8 周）周日 10:00。 */
private val previewStatsNow: java.time.LocalDateTime = java.time.LocalDateTime.of(2026, 11, 8, 10, 0)

/** 预览用课表：五门课、含必修与选修、跨周一到周五。 */
private val previewStatsCourses = listOf(
    previewStatsCourse("高等数学", "张明", "示例大学 A101", 1, 1, 2, "08:00", "09:40"),
    previewStatsCourse("大学物理", "李海", "示例大学 B203", 2, 3, 4, "10:00", "11:40"),
    previewStatsCourse("线性代数", "王蓉", "示例大学 A305", 3, 1, 2, "08:00", "09:40"),
    previewStatsCourse("程序设计", "赵磊", "实验楼 C402", 4, 5, 6, "14:00", "15:40"),
    previewStatsCourse(
        id = "course-art",
        name = "艺术鉴赏",
        teacher = "陈静",
        location = "艺术楼 201",
        dayOfWeek = 5,
        startSection = 7,
        endSection = 8,
        startTime = "16:00",
        endTime = "17:40",
        elective = true,
    ),
)

private fun previewStatsCourse(
    name: String,
    teacher: String,
    location: String,
    dayOfWeek: Int,
    startSection: Int,
    endSection: Int,
    startTime: String,
    endTime: String,
    id: String = "course-$dayOfWeek-$startSection",
    elective: Boolean = false,
) = com.mutx163.qingyu.core.Course(
    id = id,
    name = name,
    teacher = teacher,
    location = location,
    dayOfWeek = dayOfWeek,
    startSection = startSection,
    endSection = endSection,
    startTime = startTime,
    endTime = endTime,
    endWeek = 20,
    courseNature = if (elective) {
        com.mutx163.qingyu.core.CourseNature.ELECTIVE
    } else {
        com.mutx163.qingyu.core.CourseNature.REQUIRED
    },
)

private fun previewStatsState(name: String): CourseStatisticsViewState = when (name) {
    "周视图" -> CourseStatisticsLogic.buildViewState(
        courses = previewStatsCourses,
        currentWeek = 8,
        semesterWeekCount = 20,
        semesterStartDate = java.time.LocalDate.of(2026, 9, 7),
        selectedWeek = 8,
        semesterView = false,
        hasOtherProfiles = true,
        now = previewStatsNow,
        profileName = "默认课表",
    )
    "空课表" -> CourseStatisticsLogic.buildViewState(
        courses = emptyList(),
        currentWeek = 8,
        semesterWeekCount = 20,
        semesterStartDate = java.time.LocalDate.of(2026, 9, 7),
        selectedWeek = 8,
        semesterView = true,
        hasOtherProfiles = false,
        now = previewStatsNow,
    )
    else -> CourseStatisticsLogic.buildViewState(
        courses = previewStatsCourses,
        currentWeek = 8,
        semesterWeekCount = 20,
        semesterStartDate = java.time.LocalDate.of(2026, 9, 7),
        selectedWeek = 8,
        semesterView = true,
        hasOtherProfiles = true,
        now = previewStatsNow,
        profileName = "默认课表",
    )
}

/** 一档预览的公共身体：视图状态 + 外观档位。 */
@Composable
private fun PreviewCourseStatisticsBody(
    state: CourseStatisticsViewState,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        CourseStatisticsPage(
            viewState = state,
            onBack = {},
            onTabSelected = {},
            onOpenSettings = {},
            onOpenShare = {},
            onWeekChanged = {},
            onOpenAnalysis = {},
            onOpenSessions = {},
        )
    }
}

// ── 单档：三态 × 亮色 ─────────────────────────────────────────────────────────

@Suppress("unused")
@Preview(name = "1 学期视图", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewCourseStatisticsSemester() {
    PreviewCourseStatisticsBody(previewStatsState("学期视图"))
}

@Suppress("unused")
@Preview(name = "2 周视图", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewCourseStatisticsWeek() {
    PreviewCourseStatisticsBody(previewStatsState("周视图"))
}

@Suppress("unused")
@Preview(name = "3 空课表", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewCourseStatisticsEmpty() {
    PreviewCourseStatisticsBody(previewStatsState("空课表"))
}

// ── 单档：外观两档（以「学期视图」为基准）────────────────────────────────────

@Suppress("unused")
@Preview(name = "4 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewCourseStatisticsDark() {
    PreviewCourseStatisticsBody(previewStatsState("学期视图"), dark = true)
}

@Suppress("unused")
@Preview(name = "5 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewCourseStatisticsLargeText() {
    PreviewCourseStatisticsBody(previewStatsState("学期视图"), textScale = 1.3f)
}

// ── 整页：1600 高画布，看全 900 档裁掉的后半段（成就 / 故事 / 每日分布）──────────

/**
 * 整页档（2026-11-10，用户点名「900 一屏，后半段在预览里全被裁掉」）。
 *
 * 900 档只画到「周对比」，成就格、故事列表、每日分布柱图都落在画布外；这一档给
 * 1600dp 高画布：Studio 里等比缩小看**整页结构**，切「实际大小」可滚看细节。
 * 原 1~5 档全部保留（1:1 看单块细节用）。
 *
 * 预览名按全仓口径用中文（Chief 2026-11-10 裁决：全仓既有中文名、基线按此登记）：
 * `@Preview(name = …)` 是 IDE 里的标签、**不是屏上文案**，但它会被 `CjkLiteralGateTest`
 * 按**出现次数**计入 composeP1 棘轮，所以本档带来的 +1 条增量已在
 * `cjk-literal-baseline.txt` 登记并注明理由。状态串仍用 ASCII（那是分支逻辑不是文案）：
 * `previewStatsState` 的 else 分支 = 学期视图（内容最全）。
 */
@Suppress("unused")
@Preview(name = "6 整页 1600", showBackground = true, widthDp = 400, heightDp = 1600)
@Composable
private fun PreviewCourseStatisticsFullPage() {
    PreviewCourseStatisticsBody(previewStatsState("semester"))
}

// ── 总览：三态并排，一屏比结构差异 ───────────────────────────────────────────

/**
 * 一屏总览：三种状态横向并排，用来一眼比结构差异（谁多了 / 少了哪一块）。
 *
 * 3 × 400dp = 1200dp，画布给 1200dp；Studio 等比缩小显示，**缩放后字看不清是正常的**
 * ——要看细节点上面 1~5 的单档标签。
 */
@Suppress("unused")
@Preview(name = "0 总览·三态并排", showBackground = true, widthDp = 1200, heightDp = 900)
@Composable
private fun PreviewCourseStatisticsOverview() {
    Row(
        modifier = Modifier.fillMaxSize(),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        for (name in listOf("学期视图", "周视图", "空课表")) {
            Box(Modifier.width(400.dp).fillMaxHeight()) {
                PreviewCourseStatisticsBody(previewStatsState(name))
            }
        }
    }
}
