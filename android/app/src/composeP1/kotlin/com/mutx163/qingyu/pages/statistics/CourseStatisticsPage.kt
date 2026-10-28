package com.mutx163.qingyu.pages.statistics

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.mutx163.qingyu.pages.statistics.charts.WeekStatsView
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.theme.QingyuIconColors
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.icon.extended.Community
import top.yukonga.miuix.kmp.icon.extended.Location
import top.yukonga.miuix.kmp.icon.extended.Notes
import top.yukonga.miuix.kmp.icon.extended.Replace
import top.yukonga.miuix.kmp.icon.extended.Report
import top.yukonga.miuix.kmp.icon.extended.Settings
import top.yukonga.miuix.kmp.icon.extended.Share
import top.yukonga.miuix.kmp.icon.extended.Timer
import top.yukonga.miuix.kmp.icon.extended.TopDownloads
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
    onOpenShare: () -> Unit,
    onWeekChanged: (Int) -> Unit,
    onOpenAnalysis: (StatisticsAnalysisModule) -> Unit,
    onOpenSessions: () -> Unit,
    isExporting: Boolean = false,
) {
    val dark = isSystemInDarkTheme()
    var activeAchievementDetail by remember { mutableStateOf<AchievementView?>(null) }

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
                        contentDescription = StatisticsStrings.statisticsSettingsTitle.zh,
                        tint = Color(QingyuTheme.actionIcon(dark)),
                    )
                }
                IconButton(onClick = { if (!isExporting) onOpenShare() }) {
                    Icon(
                        imageVector = MiuixIcons.Share,
                        contentDescription = StatisticsStrings.statisticsShareLabel.zh,
                        tint = Color(QingyuTheme.actionIcon(dark)),
                    )
                }
            }
        },
    ) {
        if (!viewState.hasData) {
            // 空态自己不吃内边距，这里补一层，免得内容钻到顶栏底下。
            Box(modifier = Modifier.fillMaxSize().padding(innerPadding)) {
                StatisticsEmptyState(
                    title = viewState.emptyTitle,
                    hint = viewState.emptyHint,
                    dark = dark,
                )
            }
        } else {
            // 官方页面骨架（规则 R2）：惰性列表 + 右侧滚动条 + 末端触感 + 顶栏折叠联动。
            // 横向留白交给每个块自己带 QingyuPageCardMargin（12dp），
            // 与分组标题 SmallTitle 自带的 28dp 左缘对齐；不在 contentPadding 里加左右内边距。
            QingyuPageList(
                innerPadding = innerPadding,
                scrollBehavior = scrollBehavior,
                horizontalPadding = QingyuPageCardMargin,
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item(key = "tabs") {
                    StatisticsTabRow(
                        tabs = viewState.tabs,
                        selectedIndex = viewState.selectedTabIndex,
                        onTabSelected = onTabSelected,
                        dark = dark,
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
                        SectionBlock(StatisticsStrings.statisticsAchievementsTitle.zh) {
                            AchievementGrid(
                                achievements = semester.achievements,
                                dark = dark,
                                onAchievementClick = { activeAchievementDetail = it },
                            )
                        }
                    }
                    if (semester.showStoriesSection) {
                        item(key = "stories") {
                            SectionBlock(StatisticsStrings.statisticsStoriesTitle.zh) {
                                StoryList(stories = semester.stories, dark = dark)
                            }
                        }
                    }
                    item(key = "dailyDistribution") {
                        SectionBlock(StatisticsStrings.statisticsDailyDistribution.zh) {
                            DailyBarsChart(view = semester.dailyChart, dark = dark)
                        }
                    }
                    item(key = "natureRatio") {
                        SectionBlock(StatisticsStrings.statisticsNatureRatio.zh) {
                            NatureRatioBlock(view = semester.nature, dark = dark)
                        }
                    }
                    item(key = "more") {
                        SectionBlock(StatisticsStrings.statisticsMoreTitle.zh) {
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
                                    onWeekSelectorClick = {
                                        val nextWeek = if (week.weekNumber >= week.maxWeek) 1 else week.weekNumber + 1
                                        onWeekChanged(nextWeek)
                                    },
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
    }
}

// ── 空态 ──

@Composable
private fun StatisticsEmptyState(title: String, hint: String, dark: Boolean) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = title,
            style = MiuixTheme.textStyles.body1,
            fontWeight = FontWeight.Medium,
            color = Color(QingyuTheme.primaryText(dark)),
            textAlign = TextAlign.Center,
        )
        Text(
            text = hint,
            style = MiuixTheme.textStyles.footnote1,
            color = Color(QingyuTheme.secondaryText(dark)),
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 6.dp),
        )
    }
}

// ── 分段控制器 ──

@Composable
private fun StatisticsTabRow(
    tabs: List<String>,
    selectedIndex: Int,
    onTabSelected: (Int) -> Unit,
    dark: Boolean,
) {
    QingyuCard(modifier = Modifier.fillMaxWidth(), insideMargin = PaddingValues(4.dp)) {
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
            tabs.forEachIndexed { index, label ->
                val isSelected = index == selectedIndex
                val base = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(8.dp))
                Box(
                    // 选中段的底色取「最高级容器」语义槽：原先写死的
                    // 0xFFE5E5EA（亮）/ 0xFF2C2C2E（暗）与该槽位（#E8E8E8 / #2D2D2D）几乎同值，
                    // 换成槽位后深色模式与换主题色都能跟着走（规则 R5）。
                    modifier = if (isSelected) {
                        base.background(MiuixTheme.colorScheme.surfaceContainerHighest)
                    } else {
                        base
                    }
                        .clickable { onTabSelected(index) }
                        .padding(vertical = 8.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = label,
                        style = MiuixTheme.textStyles.body2,
                        fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                        color = if (isSelected) {
                            Color(QingyuTheme.primaryText(dark))
                        } else {
                            Color(QingyuTheme.secondaryText(dark))
                        },
                    )
                }
            }
        }
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
private fun SectionBlock(title: String, content: @Composable () -> Unit) {
    Column(modifier = Modifier.fillMaxWidth()) {
        QingyuSectionTitle(text = title)
        QingyuCard(modifier = Modifier.fillMaxWidth(), insideMargin = PaddingValues(14.dp)) {
            content()
        }
    }
}

// ── 学期总览：四格指标 + 细分隔线 ──

@Composable
private fun OverviewCard(metrics: List<StatisticsMetricView>, dark: Boolean) {
    if (metrics.isEmpty()) return
    QingyuCard(modifier = Modifier.fillMaxWidth(), insideMargin = PaddingValues(14.dp)) {
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
                        style = MiuixTheme.textStyles.title2,
                        fontWeight = FontWeight.Medium,
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
    QingyuCard(modifier = Modifier.fillMaxWidth(), insideMargin = PaddingValues(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = view.title,
                style = MiuixTheme.textStyles.main,
                fontWeight = FontWeight.Medium,
                color = Color(QingyuTheme.primaryText(dark)),
                modifier = Modifier.weight(1f),
            )
            Text(
                text = view.weekLabel,
                style = MiuixTheme.textStyles.main,
                fontWeight = FontWeight.SemiBold,
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
                    style = MiuixTheme.textStyles.title4,
                    fontWeight = FontWeight.Medium,
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
                        style = MiuixTheme.textStyles.title4,
                        fontWeight = FontWeight.Medium,
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
    QingyuCard(modifier = Modifier.fillMaxWidth(), insideMargin = PaddingValues(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = view.title,
                style = MiuixTheme.textStyles.main,
                fontWeight = FontWeight.Medium,
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
                dark = dark,
                alignEnd = false,
                modifier = Modifier.weight(1f),
            )
            ComparisonCell(
                value = view.deltaValue,
                label = view.deltaLabel,
                accent = deltaColor,
                labelColor = Color(QingyuTheme.secondaryText(dark)),
                dark = dark,
                alignEnd = false,
                modifier = Modifier.weight(1f),
            )
            ComparisonCell(
                value = view.averageValue,
                label = view.averageLabel,
                accent = TealAccent,
                labelColor = Color(QingyuTheme.secondaryText(dark)),
                dark = dark,
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
    dark: Boolean,
    alignEnd: Boolean,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier, horizontalAlignment = if (alignEnd) Alignment.End else Alignment.Start) {
        Text(
            text = value,
            style = MiuixTheme.textStyles.title2,
            fontWeight = FontWeight.Medium,
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
    val accent = if (item.isUnlocked) {
        Color(QingyuTheme.primary(dark = dark))
    } else {
        Color(QingyuTheme.surfaceContainerHighest(dark))
    }
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
                .background(accent),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "★",
                style = MiuixTheme.textStyles.body1,
                color = if (item.isUnlocked) {
                    Color(QingyuTheme.onAccent(dark))
                } else {
                    Color(QingyuTheme.secondaryText(dark))
                },
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
                style = MiuixTheme.textStyles.footnote2,
                fontWeight = FontWeight.Medium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.Center,
                color = if (item.isUnlocked) {
                    Color(QingyuTheme.primary(dark = dark))
                } else {
                    Color(QingyuTheme.secondaryText(dark))
                },
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
                HorizontalDivider(modifier = Modifier.padding(vertical = 10.dp))
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

/** 把 ARB 正文里的 `**text**` 解析成加粗片段（对齐 Dart `_buildRichContent`）。 */
private fun boldSegments(content: String): AnnotatedString = buildAnnotatedString {
    val pattern = Regex("""\*\*(.*?)\*\*""")
    var lastEnd = 0
    for (match in pattern.findAll(content)) {
        if (match.range.first > lastEnd) {
            append(content.substring(lastEnd, match.range.first))
        }
        pushStyle(SpanStyle(fontWeight = FontWeight.SemiBold))
        append(match.groupValues[1])
        pop()
        lastEnd = match.range.last + 1
    }
    if (lastEnd < content.length) {
        append(content.substring(lastEnd))
    }
}

// ── 每日课时分布（Canvas 柱状图） ──

@Composable
private fun DailyBarsChart(view: DailyChartView, dark: Boolean) {
    if (view.bars.isEmpty()) return
    val primary = Color(QingyuTheme.primary(dark = dark))
    val gridColor = Color(QingyuTheme.dividerLine(dark))
    val topLabel = view.maxY.toInt().toString()

    Row(modifier = Modifier.fillMaxWidth()) {
        // 左侧刻度：上界与 0
        Column(
            modifier = Modifier
                .width(24.dp)
                .height(168.dp),
            verticalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(text = topLabel, style = MiuixTheme.textStyles.footnote2, color = Color(QingyuTheme.secondaryText(dark)))
            Text(text = "0", style = MiuixTheme.textStyles.footnote2, color = Color(QingyuTheme.secondaryText(dark)))
        }
        Column(modifier = Modifier.weight(1f)) {
            Canvas(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(168.dp),
            ) {
                val maxY = if (view.maxY <= 0.0) 1f else view.maxY.toFloat()
                // 横向网格线（按整数节数）
                val steps = if (maxY <= 4f) maxY.toInt() else 4
                for (i in 0..steps) {
                    val y = size.height - size.height * (i.toFloat() / steps)
                    drawLine(
                        color = gridColor,
                        start = Offset(0f, y),
                        end = Offset(size.width, y),
                        strokeWidth = 1f,
                    )
                }
                val count = view.bars.size
                val slot = size.width / count
                val barWidth = minOf(20.dp.toPx(), slot * 0.5f)
                view.bars.forEachIndexed { index, bar ->
                    val centerX = slot * index + slot / 2f
                    val barHeight = size.height * (bar.average.toFloat() / maxY)
                    val color = when {
                        bar.isMax -> primary
                        bar.isMin -> TealAccent
                        else -> primary.copy(alpha = 0.35f)
                    }
                    if (barHeight > 0f) {
                        drawRoundRect(
                            color = color,
                            topLeft = Offset(centerX - barWidth / 2f, size.height - barHeight),
                            size = Size(barWidth, barHeight),
                            cornerRadius = androidx.compose.ui.geometry.CornerRadius(6.dp.toPx()),
                        )
                    }
                }
            }
            Row(modifier = Modifier.fillMaxWidth()) {
                view.bars.forEach { bar ->
                    Text(
                        text = bar.label,
                        style = MiuixTheme.textStyles.footnote2,
                        fontWeight = if (bar.isMax) FontWeight.Medium else FontWeight.Normal,
                        textAlign = TextAlign.Center,
                        color = if (bar.isMax) {
                            Color(QingyuTheme.primary(dark = dark))
                        } else {
                            Color(QingyuTheme.secondaryText(dark))
                        },
                        modifier = Modifier
                            .weight(1f)
                            .padding(top = 6.dp),
                    )
                }
            }
        }
    }
}

// ── 必修 / 选修 ──

@Composable
private fun NatureRatioBlock(view: NatureRatioView, dark: Boolean) {
    if (!view.hasData) {
        Text(
            text = StatisticsStrings.statisticsNoData.zh,
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
            NatureDonut(view = view, dark = dark)
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
                val color = if (legend.isRequired) RequiredAccent else ElectiveAccent
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
                        style = MiuixTheme.textStyles.body2,
                        fontWeight = FontWeight.SemiBold,
                        color = color,
                    )
                }
            }
        }
    }
}

@Composable
private fun NatureDonut(view: NatureRatioView, dark: Boolean) {
    val required = view.legend.firstOrNull { it.isRequired }
    val requiredRatio = required?.ratioText?.trimEnd('%')?.toFloatOrNull() ?: 0f
    val hasRequired = view.hasRequired
    val hasElective = view.hasElective

    Canvas(modifier = Modifier.size(100.dp)) {
        val stroke = 10.dp.toPx()
        val inset = stroke / 2f
        val arcSize = Size(size.width - stroke, size.height - stroke)
        val topLeft = Offset(inset, inset)

        // 缺失侧补极浅轨道段，让「空」可见（对齐 Dart 的 0.12 alpha 兜底段）
        if (!hasRequired) {
            drawArc(
                color = RequiredAccent.copy(alpha = 0.12f),
                startAngle = -90f,
                sweepAngle = 360f,
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = Stroke(width = stroke, cap = StrokeCap.Butt),
            )
        }
        if (!hasElective) {
            drawArc(
                color = ElectiveAccent.copy(alpha = 0.12f),
                startAngle = -90f,
                sweepAngle = 360f,
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = Stroke(width = stroke, cap = StrokeCap.Butt),
            )
        }
        if (hasRequired && hasElective) {
            val sweep = 360f * (requiredRatio / 100f)
            drawArc(
                color = RequiredAccent,
                startAngle = -90f,
                sweepAngle = sweep,
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = Stroke(width = stroke, cap = StrokeCap.Butt),
            )
            drawArc(
                color = ElectiveAccent,
                startAngle = -90f + sweep,
                sweepAngle = 360f - sweep,
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = Stroke(width = stroke, cap = StrokeCap.Butt),
            )
        } else if (hasRequired) {
            drawArc(
                color = RequiredAccent,
                startAngle = -90f,
                sweepAngle = 360f,
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = Stroke(width = stroke, cap = StrokeCap.Butt),
            )
        } else if (hasElective) {
            drawArc(
                color = ElectiveAccent,
                startAngle = -90f,
                sweepAngle = 360f,
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = Stroke(width = stroke, cap = StrokeCap.Butt),
            )
        }
        // 暗色下保留一点内圈描边光感
        if (dark) {
            drawCircle(
                color = Color.White.copy(alpha = 0.04f),
                radius = size.minDimension / 2f - stroke,
            )
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
            if (index > 0) {
                HorizontalDivider()
            }
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable {
                        when (val target = entry.target) {
                            is StatisticsEntryTarget.Sessions -> onOpenSessions()
                            is StatisticsEntryTarget.Analysis -> onOpenAnalysis(target.module)
                        }
                    }
                    .padding(vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Icon(
                    imageVector = iconFor(entry.target),
                    contentDescription = null,
                    tint = Color(QingyuTheme.actionIcon(dark)),
                    modifier = Modifier.size(20.dp),
                )
                Text(
                    text = entry.title,
                    style = MiuixTheme.textStyles.main,
                    color = Color(QingyuTheme.primaryText(dark)),
                    modifier = Modifier.weight(1f),
                )
                Icon(
                    imageVector = MiuixIcons.ChevronForward,
                    contentDescription = null,
                    tint = Color(QingyuTheme.actionIcon(dark)),
                    modifier = Modifier.size(18.dp),
                )
            }
        }
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
    QingyuCard(modifier = Modifier.fillMaxWidth(), insideMargin = PaddingValues(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = StatisticsStrings.statisticsWeekSelector.filled("week", week.weekNumber.toString()),
                style = MiuixTheme.textStyles.main,
                fontWeight = FontWeight.Medium,
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
                label = StatisticsStrings.statisticsCourseCount.zh,
                accent = Color(QingyuTheme.primaryText(dark)),
                labelColor = Color(QingyuTheme.secondaryText(dark)),
                dark = dark,
                alignEnd = false,
                modifier = Modifier.weight(1f),
            )
            ComparisonCell(
                value = week.sectionCount.toString(),
                label = StatisticsStrings.statisticsSectionCount.zh,
                accent = Color(QingyuTheme.primary(dark = dark)),
                labelColor = Color(QingyuTheme.secondaryText(dark)),
                dark = dark,
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

// ── 图表配色（Dart `HyperosIconColors` 的语义色） ──
//
// 数值的唯一定义处在 `theme/QingyuPalette.kt` 的 [QingyuIconColors]（`QingyuPaletteTest` 钉着 9 个值）。
// 这里原先自己抄了一份**不同**的 Material 调色板字面量（0xFF26A69A / 0xFF2196F3 / 0xFF9C27B0），
// KDoc 却写着「对齐 Dart HyperosIconColors」——实际与 Dart 的
// 0xFF14B8A6 / 0xFF3482FF / 0xFF8B5CF6 并不一致，属于「两处定义同一色板且值不同」。
// 现在改引用唯一出处：既消掉写死色（规则 R5），也修掉这处值不一致。
//
// 这些是**数据系列语义色**（青=最低档、蓝=必修、紫=选修），亮暗同值、不跟主题种子色走，
// 与 `charts/ChartPrimitives.kt` 的 `ChartPalette` 同一套出处。

/** Dart `HyperosIconColors.teal`（柱状图最低档）。 */
private val TealAccent = Color(QingyuIconColors.TEAL)

/** Dart `HyperosIconColors.blue`（必修）。 */
private val RequiredAccent = Color(QingyuIconColors.BLUE)

/** Dart `HyperosIconColors.purple`（选修）。 */
private val ElectiveAccent = Color(QingyuIconColors.PURPLE)
