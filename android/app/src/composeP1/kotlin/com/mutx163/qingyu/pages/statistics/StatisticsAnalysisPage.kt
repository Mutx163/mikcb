package com.mutx163.qingyu.pages.statistics

import androidx.compose.foundation.background
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.pages.statistics.StatisticsAnalysisModel.AnalysisCardRole
import com.mutx163.qingyu.pages.statistics.StatisticsAnalysisModel.AnalysisCell
import com.mutx163.qingyu.pages.statistics.StatisticsAnalysisModel.StatisticsAnalysisViewState
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.icon.extended.TopDownloads

/**
 * 深度分析二级页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/statistics_analysis_screen.dart`（208 行）。
 *
 * ## 壳子做什么、不做什么
 *
 * Dart 里这一页是「一个壳 + 六个模块分支」。这里把分支决策留在模型层
 * （[StatisticsAnalysisModel.cells]），渲染层只按 [AnalysisCell] 逐格画——
 * 于是「哪个模块摆哪几张卡」在 JVM 单测里被钉住，而不是散在 Compose 的 when 里。
 *
 * ## 卡片内容
 *
 * 六张卡（趋势 / 热力图 / 时间利用 / 教室 / 教师 / 排行 / 对比）各自的完整图表与
 * 明细都是 `lib/widgets/statistics` 目录下的大件，Phase 3 本批不迁这些 widget 文件
 * （台账 §5 P3-E 的写作用域只到 `pages/statistics/`）。因此这里画的是**结构一致的骨架**：
 * 卡片标题 + 该模块的核心读数行。差异记录在认领文件「差异与风险」，不做静默省略。
 *
 * @param viewState 已算好的读数（渲染层不做业务计算）
 * @param onBack 返回
 * @param onOpenCourse 排行页点课程名 → 进课程编辑
 */
@Composable
fun StatisticsAnalysisPage(
    viewState: StatisticsAnalysisViewState,
    onBack: () -> Unit,
    onOpenCourse: (String) -> Unit = {},
) {
    val dark = isSystemInDarkTheme()

    QingyuPageTheme {
        Scaffold(
            containerColor = Color(QingyuTheme.scaffoldBackground(dark)),
            topBar = {
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
                )
            },
        ) { innerPadding ->
            if (!viewState.hasData) {
                EmptyState(
                    title = viewState.emptyTitle,
                    subtitle = viewState.emptySubtitle,
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(innerPadding),
                )
            } else {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(innerPadding)
                        .verticalScroll(rememberScrollState())
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    for (cell in viewState.cells) {
                        when (cell) {
                            is AnalysisCell.Gap -> Spacer(Modifier.height(8.dp))
                            is AnalysisCell.Card -> AnalysisCard(
                                cell = cell,
                                viewState = viewState,
                                onOpenCourse = onOpenCourse,
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun AnalysisCard(
    cell: AnalysisCell.Card,
    viewState: StatisticsAnalysisViewState,
    onOpenCourse: (String) -> Unit,
) {
    val dark = isSystemInDarkTheme()

    QingyuCard(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = PaddingValues(vertical = 14.dp, horizontal = 16.dp),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            // standalone = 独立二级页：Dart 里去掉卡内标题、读数放大。
            // 非 standalone 保留卡内小标题（TeacherStatsCard / CourseRanking 的形态）。
            if (!cell.standalone) {
                Text(
                    text = roleTitle(cell.role),
                    fontSize = 13.sp,
                    color = Color(QingyuTheme.sectionLabel(dark)),
                )
            }

            when (cell.role) {
                AnalysisCardRole.TREND_CHART -> TrendRows(viewState, cell.standalone)
                AnalysisCardRole.HEATMAP -> HeatmapRows(viewState)
                AnalysisCardRole.TIME_UTILIZATION -> TimeUtilRows(viewState, cell.standalone)
                AnalysisCardRole.VENUE -> VenueRows(viewState, cell.standalone)
                AnalysisCardRole.TEACHER -> TeacherRows(viewState)
                AnalysisCardRole.RANKING -> RankingRows(viewState, onOpenCourse)
                AnalysisCardRole.PROFILE_COMPARE -> CompareRows(viewState)
            }
        }
    }
}

/** 卡内小标题：非 standalone 卡片的抬头，取该模块的 ARB 标题。 */
@Composable
private fun roleTitle(role: AnalysisCardRole): String = when (role) {
    AnalysisCardRole.TEACHER -> StatisticsExtStrings.statisticsTeacherTitle.zh
    AnalysisCardRole.RANKING -> StatisticsExtStrings.statisticsRankingTitle.zh
    else -> StatisticsExtStrings.statisticsNoData.zh
}

@Composable
private fun TrendRows(viewState: StatisticsAnalysisViewState, standalone: Boolean) {
    val dark = isSystemInDarkTheme()
    if (viewState.trend.isEmpty()) {
        MutedLine(viewState.emptyTitle)
        return
    }
    // 折线本身不在这里画（Dart TrendChart 属 widget 大件，本批不迁），
    // 这里给出每周课时读数行，保证信息不丢。
    for (point in viewState.trend.take(6)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = StatisticsExtStrings.weekLabel.filled("week", point.weekNumber.toString()),
                fontSize = if (standalone) 15.sp else 14.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
            Text(
                text = "${point.sections}",
                fontSize = if (standalone) 18.sp else 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color(QingyuTheme.primaryText(dark)),
            )
        }
    }
}

@Composable
private fun HeatmapRows(viewState: StatisticsAnalysisViewState) {
    val dark = isSystemInDarkTheme()
    if (viewState.heatmapMax <= 0) {
        MutedLine(viewState.emptyTitle)
        return
    }
    Text(
        text = viewState.heatmapSummary,
        fontSize = 14.sp,
        color = Color(QingyuTheme.primaryText(dark)),
    )
}

@Composable
private fun TimeUtilRows(viewState: StatisticsAnalysisViewState, standalone: Boolean) {
    val dark = isSystemInDarkTheme()
    for ((label, value) in viewState.timeUtilRows) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = label,
                fontSize = if (standalone) 15.sp else 14.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
            Text(
                text = value,
                fontSize = if (standalone) 18.sp else 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color(QingyuTheme.primaryText(dark)),
            )
        }
    }
}

@Composable
private fun VenueRows(viewState: StatisticsAnalysisViewState, standalone: Boolean) {
    val dark = isSystemInDarkTheme()
    if (viewState.venueRows.isEmpty()) {
        MutedLine(viewState.emptyTitle)
        return
    }
    for ((label, value) in viewState.venueRows) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = label,
                fontSize = if (standalone) 15.sp else 14.sp,
                color = Color(QingyuTheme.primaryText(dark)),
            )
            Text(
                text = value,
                fontSize = if (standalone) 18.sp else 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
    }
}

@Composable
private fun TeacherRows(viewState: StatisticsAnalysisViewState) {
    val dark = isSystemInDarkTheme()
    if (viewState.teacherRows.isEmpty()) {
        MutedLine(viewState.emptyTitle)
        return
    }
    for ((label, value) in viewState.teacherRows) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(text = label, fontSize = 14.sp, color = Color(QingyuTheme.primaryText(dark)))
            Text(
                text = value,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
    }
}

@Composable
private fun RankingRows(viewState: StatisticsAnalysisViewState, onOpenCourse: (String) -> Unit) {
    val dark = isSystemInDarkTheme()
    if (viewState.rankingRows.isEmpty()) {
        MutedLine(viewState.emptyTitle)
        return
    }
    for ((index, row) in viewState.rankingRows.withIndex()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(10.dp))
                .background(
                    if (index == 0) Color(QingyuTheme.rowHighlight(dark)) else Color.Transparent,
                )
                .padding(horizontal = 6.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(
                text = "${index + 1}",
                fontSize = 13.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
                modifier = Modifier.size(width = 18.dp, height = 18.dp),
                textAlign = TextAlign.Center,
            )
            Text(
                text = row.first,
                fontSize = 15.sp,
                color = Color(QingyuTheme.primaryText(dark)),
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(6.dp))
                    .padding(vertical = 2.dp),
            )
            Text(
                text = row.second,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color(QingyuTheme.primaryText(dark)),
            )
        }
        if (index < viewState.rankingRows.lastIndex) {
            top.yukonga.miuix.kmp.basic.HorizontalDivider(
                modifier = Modifier.padding(start = 28.dp),
                color = Color(QingyuTheme.dividerLine(dark)),
            )
        }
    }
}

@Composable
private fun CompareRows(viewState: StatisticsAnalysisViewState) {
    val dark = isSystemInDarkTheme()
    if (viewState.compareRows.isEmpty()) {
        MutedLine(viewState.emptyTitle)
        return
    }
    for ((label, value) in viewState.compareRows) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(text = label, fontSize = 14.sp, color = Color(QingyuTheme.primaryText(dark)))
            Text(
                text = value,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
    }
}

@Composable
private fun MutedLine(text: String) {
    val dark = isSystemInDarkTheme()
    Text(text = text, fontSize = 14.sp, color = Color(QingyuTheme.secondaryText(dark)))
}

/** 空态（Dart `HyperosEmptyState`：图标 + 标题 + 副标题，整页居中）。 */
@Composable
private fun EmptyState(title: String, subtitle: String, modifier: Modifier = Modifier) {
    val dark = isSystemInDarkTheme()
    Box(modifier = modifier, contentAlignment = Alignment.Center) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Icon(
                imageVector = MiuixIcons.TopDownloads,
                contentDescription = null,
                tint = Color(QingyuTheme.secondaryText(dark)),
                modifier = Modifier.size(40.dp),
            )
            Text(
                text = title,
                fontSize = 16.sp,
                color = Color(QingyuTheme.primaryText(dark)),
            )
            Text(
                text = subtitle,
                fontSize = 13.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
    }
}
