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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
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
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
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

/**
 * 课程统计主页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/course_statistics_screen.dart`（账单式：学期 / 周 双视图）：
 * - 顶栏：返回 + "课程统计"；**有数据时**才出现设置与分享两个动作；
 * - 学期视图：分段 → 总览四格 → 学期进度 → 本周小结 → 成就徽章 →
 *   （有故事时）数据故事 → 每日课时分布 → 必修/选修 → 深度分析入口组；
 * - 周视图：分段 → 选中周总量；
 * - 无课程时是空态（图标 + "暂无课程数据" + "添加课程后即可查看统计"）。
 *
 * 数据口径全部来自 [CourseStatisticsViewState]（模型层已算好），这里只画。
 * 图表用 Compose `Canvas` 手绘（官方 Miuix 无图表组件）。
 *
 * 已知差异（记录在认领文件「差异与风险」）：`week_stats_view.dart`（490 行）
 * 的图表件尚未 1:1 迁移，周视图当前只呈现课程门数与课时总量。
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

    Scaffold(containerColor = Color(QingyuTheme.scaffoldBackground(dark))) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                // 不手写 statusBarsPadding()：miuix Scaffold 的 contentWindowInsets
                // 默认含 systemBars 顶部，TopAppBar 自己也会加 systemBars.only(Top)，
                // 再写一次是第三次叠加，标题会下移一个多状态栏高（2026-10-27）。
                .padding(innerPadding),
        ) {
            TopAppBar(
                title = viewState.title,
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = MiuixIcons.Back,
                            contentDescription = viewState.title,
                            tint = Color(QingyuTheme.actionIcon(dark)),
                        )
                    }
                },
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
            )

            if (!viewState.hasData) {
                StatisticsEmptyState(
                    title = viewState.emptyTitle,
                    hint = viewState.emptyHint,
                    dark = dark,
                )
            } else {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                        .padding(horizontal = 16.dp, vertical = 6.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    StatisticsTabRow(
                        tabs = viewState.tabs,
                        selectedIndex = viewState.selectedTabIndex,
                        onTabSelected = onTabSelected,
                        dark = dark,
                    )

                    val semester = viewState.semester
                    if (viewState.selectedTabIndex == 0 && semester != null) {
                        OverviewCard(metrics = semester.overview, dark = dark)
                        SemesterProgressCard(view = semester.progress, dark = dark)
                        WeeklyComparisonCard(view = semester.comparison, dark = dark)
                        SectionBlock(StatisticsStrings.statisticsAchievementsTitle.zh, dark) {
                            AchievementGrid(achievements = semester.achievements, dark = dark)
                        }
                        if (semester.showStoriesSection) {
                            SectionBlock(StatisticsStrings.statisticsStoriesTitle.zh, dark) {
                                StoryList(stories = semester.stories, dark = dark)
                            }
                        }
                        SectionBlock(StatisticsStrings.statisticsDailyDistribution.zh, dark) {
                            DailyBarsChart(view = semester.dailyChart, dark = dark)
                        }
                        SectionBlock(StatisticsStrings.statisticsNatureRatio.zh, dark) {
                            NatureRatioBlock(view = semester.nature, dark = dark)
                        }
                        SectionBlock(StatisticsStrings.statisticsMoreTitle.zh, dark) {
                            AnalysisEntryList(
                                entries = viewState.analysisEntries,
                                onOpenAnalysis = onOpenAnalysis,
                                onOpenSessions = onOpenSessions,
                                dark = dark,
                            )
                        }
                    } else {
                        val week = viewState.week
                        if (week != null) {
                            WeekOverviewCard(
                                week = week,
                                currentWeek = viewState.currentWeek,
                                onWeekChanged = onWeekChanged,
                                dark = dark,
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(12.dp))
                }
            }
        }
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
            fontSize = 16.sp,
            fontWeight = FontWeight.Medium,
            color = Color(QingyuTheme.primaryText(dark)),
            textAlign = TextAlign.Center,
        )
        Text(
            text = hint,
            fontSize = 13.sp,
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
    Card(modifier = Modifier.fillMaxWidth(), insideMargin = PaddingValues(4.dp)) {
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
            tabs.forEachIndexed { index, label ->
                val isSelected = index == selectedIndex
                val base = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(8.dp))
                Box(
                    modifier = if (isSelected) {
                        base.background(if (dark) Color(0xFF2C2C2E) else Color(0xFFE5E5EA))
                    } else {
                        base
                    }
                        .clickable { onTabSelected(index) }
                        .padding(vertical = 8.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = label,
                        fontSize = 14.sp,
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

@Composable
private fun SectionBlock(title: String, dark: Boolean, content: @Composable () -> Unit) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = title,
            fontSize = 13.sp,
            color = Color(QingyuTheme.sectionLabel(dark)),
            modifier = Modifier.padding(start = 4.dp, bottom = 6.dp),
        )
        Card(modifier = Modifier.fillMaxWidth(), insideMargin = PaddingValues(14.dp)) {
            content()
        }
    }
}

// ── 学期总览：四格指标 + 细分隔线 ──

@Composable
private fun OverviewCard(metrics: List<StatisticsMetricView>, dark: Boolean) {
    if (metrics.isEmpty()) return
    Card(modifier = Modifier.fillMaxWidth(), insideMargin = PaddingValues(14.dp)) {
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
                        fontSize = 24.sp,
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
                        fontSize = 11.sp,
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
    Card(modifier = Modifier.fillMaxWidth(), insideMargin = PaddingValues(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = view.title,
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
                color = Color(QingyuTheme.primaryText(dark)),
                modifier = Modifier.weight(1f),
            )
            Text(
                text = view.weekLabel,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = primary,
            )
        }
        if (view.rangeLabel != null) {
            Text(
                text = view.rangeLabel,
                fontSize = 12.sp,
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
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Medium,
                    color = Color(QingyuTheme.primaryText(dark)),
                )
                Text(
                    text = view.detailLabel,
                    fontSize = 11.sp,
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
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Medium,
                        textAlign = TextAlign.End,
                        color = Color(QingyuTheme.primaryText(dark)),
                    )
                    Text(
                        text = view.factLabel,
                        fontSize = 11.sp,
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
    Card(modifier = Modifier.fillMaxWidth(), insideMargin = PaddingValues(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = view.title,
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
                color = Color(QingyuTheme.primaryText(dark)),
                modifier = Modifier.weight(1f),
            )
            Text(text = view.weekLabel, fontSize = 12.sp, color = Color(QingyuTheme.secondaryText(dark)))
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
                fontSize = 12.sp,
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
            fontSize = 24.sp,
            fontWeight = FontWeight.Medium,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            textAlign = if (alignEnd) TextAlign.End else TextAlign.Start,
            color = accent,
        )
        Text(
            text = label,
            fontSize = 11.sp,
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
private fun AchievementGrid(achievements: List<AchievementView>, dark: Boolean) {
    if (achievements.isEmpty()) return
    val columns = 4
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        achievements.chunked(columns).forEach { rowItems ->
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                rowItems.forEach { item ->
                    AchievementBadge(item = item, dark = dark, modifier = Modifier.weight(1f))
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
private fun AchievementBadge(item: AchievementView, dark: Boolean, modifier: Modifier = Modifier) {
    val accent = if (item.isUnlocked) {
        Color(QingyuTheme.primary(dark = dark))
    } else {
        Color(QingyuTheme.surfaceContainerHighest(dark))
    }
    Column(
        modifier = modifier,
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
                fontSize = 16.sp,
                color = if (item.isUnlocked) {
                    Color(QingyuTheme.onAccent(dark))
                } else {
                    Color(QingyuTheme.secondaryText(dark))
                },
            )
        }
        Text(
            text = item.name,
            fontSize = 11.sp,
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
                fontSize = 10.sp,
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
                fontSize = 12.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
            Text(
                text = boldSegments(story.content),
                fontSize = 14.sp,
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
            Text(text = topLabel, fontSize = 10.sp, color = Color(QingyuTheme.secondaryText(dark)))
            Text(text = "0", fontSize = 10.sp, color = Color(QingyuTheme.secondaryText(dark)))
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
                        fontSize = 10.sp,
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
            fontSize = 13.sp,
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
                    fontSize = 10.sp,
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
                            fontSize = 14.sp,
                            color = Color(QingyuTheme.primaryText(dark)),
                        )
                        Text(
                            text = legend.detail,
                            fontSize = 11.sp,
                            color = Color(QingyuTheme.secondaryText(dark)),
                        )
                    }
                    Text(
                        text = legend.ratioText,
                        fontSize = 14.sp,
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
                    fontSize = 15.sp,
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
    Card(modifier = Modifier.fillMaxWidth(), insideMargin = PaddingValues(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = StatisticsStrings.statisticsWeekSelector.filled("week", week.weekNumber.toString()),
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
                color = Color(QingyuTheme.primaryText(dark)),
                modifier = Modifier.weight(1f),
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                if (week.weekNumber > 1) {
                    Text(
                        text = "‹",
                        fontSize = 18.sp,
                        color = Color(QingyuTheme.primary(dark = dark)),
                        modifier = Modifier
                            .clickable { onWeekChanged(week.weekNumber - 1) }
                            .padding(horizontal = 8.dp),
                    )
                }
                if (week.weekNumber < week.maxWeek) {
                    Text(
                        text = "›",
                        fontSize = 18.sp,
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
            fontSize = 11.sp,
            color = Color(QingyuTheme.secondaryText(dark)),
            modifier = Modifier.padding(top = 8.dp),
        )
    }
}

// ── 图表配色（对齐 Dart `HyperosIconColors` 的语义色） ──

/** Dart `HyperosIconColors.teal`。 */
private val TealAccent = Color(0xFF26A69A)

/** Dart `HyperosIconColors.blue`（必修）。 */
private val RequiredAccent = Color(0xFF2196F3)

/** Dart `HyperosIconColors.purple`（选修）。 */
private val ElectiveAccent = Color(0xFF9C27B0)
