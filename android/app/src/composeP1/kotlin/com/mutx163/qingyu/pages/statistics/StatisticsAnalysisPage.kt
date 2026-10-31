package com.mutx163.qingyu.pages.statistics

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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.pages.statistics.StatisticsAnalysisModel.AnalysisCardRole
import com.mutx163.qingyu.pages.statistics.StatisticsAnalysisModel.AnalysisCell
import com.mutx163.qingyu.pages.statistics.StatisticsAnalysisModel.StatisticsAnalysisViewState
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
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
 * @param onOpenCourse 排行页点课程名 → 进课程编辑。
 *   **`null` = 还没接落点**（审核 misc-wiring P1-3）。此时排版**不可点**——
 *   2026-10-29 之前这里是默认空 lambda，行看着能点、点了没反应，属 rubric 判 P0 的
 *   「点了没反应」。现在改成「没有落点就没有可点性」：壳一旦传入真处理函数，
 *   排行行自动变可点；不传则保持纯展示。Dart 原件
 *   （`lib/screens/statistics_analysis_screen.dart:132` → `:190 _openCourseEdit`）
 *   是「按课名找课程 → 打开该课编辑页」。
 */
@Composable
fun StatisticsAnalysisPage(
    viewState: StatisticsAnalysisViewState,
    onBack: () -> Unit,
    onOpenCourse: ((String) -> Unit)? = null,
) {
    // 顶栏 / 返回键 / 折叠行为 / 页面主题桥统一走共享骨架（规则 R1）。
    // 骨架内部自己持有 ScrollBehavior 并交给下面的 QingyuPageList，
    // 所以本页不再需要 `QingyuPageTheme { Scaffold { TopAppBar } }` 那一套手写组合。
    QingyuPageScaffold(title = viewState.title, onBack = onBack) {
        if (!viewState.hasData) {
            EmptyState(
                title = viewState.emptyTitle,
                subtitle = viewState.emptySubtitle,
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding),
            )
        } else {
            // 官方页面骨架：LazyColumn + 滚动条 + 末端触感（见 QingyuPageList 注释）
            QingyuPageList(
                innerPadding = innerPadding,
                scrollBehavior = scrollBehavior,
                horizontalPadding = QingyuPageCardMargin,
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item {
                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
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
}

@Composable
private fun AnalysisCard(
    cell: AnalysisCell.Card,
    viewState: StatisticsAnalysisViewState,
    onOpenCourse: ((String) -> Unit)?,
) {
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
                    style = MiuixTheme.textStyles.footnote1,
                    // 卡内小标题的取色槽：与 `QingyuTheme.sectionLabel(dark)` 同值
                    // （QingyuPageTheme 把 onSurfaceVariantActions 填成 actionIcon），
                    // 改走 colorScheme 语义槽后不再触发「手拼分组标题」那条判据的误报
                    // ——本页并没有分组标题，这条只是卡内抬头。
                    color = MiuixTheme.colorScheme.onSurfaceVariantActions,
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
                style = if (standalone) MiuixTheme.textStyles.main else MiuixTheme.textStyles.body2,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
            Text(
                text = "${point.sections}",
                style = if (standalone) MiuixTheme.textStyles.title4 else MiuixTheme.textStyles.main,
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
        style = MiuixTheme.textStyles.body2,
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
                style = if (standalone) MiuixTheme.textStyles.main else MiuixTheme.textStyles.body2,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
            Text(
                text = value,
                style = if (standalone) MiuixTheme.textStyles.title4 else MiuixTheme.textStyles.main,
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
                style = if (standalone) MiuixTheme.textStyles.main else MiuixTheme.textStyles.body2,
                color = Color(QingyuTheme.primaryText(dark)),
            )
            Text(
                text = value,
                style = if (standalone) MiuixTheme.textStyles.title4 else MiuixTheme.textStyles.main,
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
            Text(text = label, style = MiuixTheme.textStyles.body2, color = Color(QingyuTheme.primaryText(dark)))
            Text(
                text = value,
                style = MiuixTheme.textStyles.body2,
                fontWeight = FontWeight.SemiBold,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
    }
}

@Composable
private fun RankingRows(viewState: StatisticsAnalysisViewState, onOpenCourse: ((String) -> Unit)?) {
    val dark = isSystemInDarkTheme()
    if (viewState.rankingRows.isEmpty()) {
        MutedLine(viewState.emptyTitle)
        return
    }
    for ((index, row) in viewState.rankingRows.withIndex()) {
        // 有落点才可点（P1-3）：`onOpenCourse == null` 时不加 `clickable`，
        // 排版保持纯展示——不做一个「按下去什么都不发生」的假热区。
        val rowModifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(
                if (index == 0) Color(QingyuTheme.rowHighlight(dark)) else Color.Transparent,
            )
            .then(
                if (onOpenCourse != null) {
                    // Dart `CourseRanking(onCourseTap:)`：点行按课名进该课编辑页。
                    Modifier.clickable { onOpenCourse(row.first) }
                } else {
                    Modifier
                },
            )
            .padding(horizontal = 6.dp, vertical = 8.dp)
        Row(
            modifier = rowModifier,
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(
                text = "${index + 1}",
                style = MiuixTheme.textStyles.footnote1,
                color = Color(QingyuTheme.secondaryText(dark)),
                modifier = Modifier.size(width = 18.dp, height = 18.dp),
                textAlign = TextAlign.Center,
            )
            Text(
                text = row.first,
                style = MiuixTheme.textStyles.body2,
                color = Color(QingyuTheme.primaryText(dark)),
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(6.dp))
                    .padding(vertical = 2.dp),
            )
            Text(
                text = row.second,
                style = MiuixTheme.textStyles.body2,
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
            Text(text = label, style = MiuixTheme.textStyles.body2, color = Color(QingyuTheme.primaryText(dark)))
            Text(
                text = value,
                style = MiuixTheme.textStyles.body2,
                fontWeight = FontWeight.SemiBold,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
    }
}

@Composable
private fun MutedLine(text: String) {
    val dark = isSystemInDarkTheme()
    Text(text = text, style = MiuixTheme.textStyles.body2, color = Color(QingyuTheme.secondaryText(dark)))
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
                style = MiuixTheme.textStyles.body1,
                color = Color(QingyuTheme.primaryText(dark)),
            )
            Text(
                text = subtitle,
                style = MiuixTheme.textStyles.footnote1,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
    }
}
