package com.mutx163.qingyu.pages.statistics.charts

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuSectionGap
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.statistics.TimeUtilizationStats
import com.mutx163.qingyu.statistics.WeeklyComparison
import com.mutx163.qingyu.statistics.WeeklyStats
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.ExpandMore
import top.yukonga.miuix.kmp.icon.extended.Months
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 周统计视图：周选择器 + 本周小结 + 每日分布 + 必修/选修 + 时间利用 + 课程列表。
 *
 * 对应 Dart `lib/widgets/statistics/week_stats_view.dart`（490 行）。
 *
 * ## 与 Dart 的差异
 *
 * 1. Dart 在这个组件里**现算** `WeeklyComparison` 与 `TimeUtilizationStats`
 *    （`StatisticsService.calculateWeeklyComparison` / `calculateTimeUtilization`）。
 *    这里改成由调用方传入——统计服务是纯 Kotlin、已在模型层，视图再算一遍会让
 *    "同一屏两次计算可能不一致"重新出现（Dart 那边其实就有这个隐患）。
 * 2. 周选择器点击后的**周次选择弹窗**（`week_selector_picker_sheet.dart`）
 *    不在本批 22 件里，因此这里只暴露 [onWeekSelectorClick] 回调；不传就不可点。
 *
 * 每日分布柱图用的是周口径（[DailyChartModel.weekSpec]，高 150、刻度占位 26），
 * 与学期口径的学期平均课时图（高 168、占位 28）**不是同一张图**，别混用。
 */
@Composable
fun WeekStatsView(
    stats: WeeklyStats,
    currentSemesterWeek: Int,
    comparison: WeeklyComparison,
    dark: Boolean,
    modifier: Modifier = Modifier,
    timeUtilization: TimeUtilizationStats? = null,
    onWeekSelectorClick: (() -> Unit)? = null,
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(QingyuSectionGap),
    ) {
        WeekSelectorCard(
            week = stats.weekNumber,
            currentSemesterWeek = currentSemesterWeek,
            dark = dark,
            onClick = onWeekSelectorClick,
        )

        WeeklyComparisonCard(
            comparison = comparison,
            currentWeek = stats.weekNumber,
            dark = dark,
        )

        // ── 每日课时分布（周口径柱图，真的画柱） ──
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            QingyuSectionTitle(
                text = ChartsStrings.statisticsDailyDistribution.zh,
                // 页面已统一缩进 12dp；标题再缩 16dp 才能与卡内文字一起落在 28dp 轴线。
                insideMargin = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
            )
            DailyChartCard(
                spec = DailyChartModel.weekSpec(stats.dailyStats),
                dark = dark,
                chartHeightDp = DailyChartModel.WEEK_CHART_HEIGHT_DP,
                leftReserveDp = DailyChartModel.WEEK_LEFT_RESERVE_DP,
            )
        }

        // ── 必修 / 选修（真的画环） ──
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            QingyuSectionTitle(
                text = ChartsStrings.statisticsNatureRatio.zh,
                insideMargin = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
            )
            NatureRatioCard(stats = stats.natureStats, dark = dark)
        }

        if (timeUtilization != null && !timeUtilization.isEmpty) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                QingyuSectionTitle(
                    text = ChartsStrings.statisticsTimeUtilTitle.zh,
                    insideMargin = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                )
                TimeUtilizationCard(stats = timeUtilization, dark = dark)
            }
        }

        val courseRows = WeekStatsModel.buildCourseRows(stats)
        if (courseRows.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                QingyuSectionTitle(
                    text = ChartsStrings.statisticsCourseList.zh,
                    insideMargin = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                )
                WeekCourseListCard(rows = courseRows, dark = dark)
            }
        }
    }
}

/**
 * 周选择器卡：`第 N 周` +（本周时）「本周」胶囊 + 右侧展开箭头。
 *
 * Dart 里字号是 18（`listTitle` 基础上显式抬到 18），这里用字阶的 `title4`（18sp）
 * 表达同一层级——不再写裸 `fontSize`。
 */
@Composable
private fun WeekSelectorCard(
    week: Int,
    currentSemesterWeek: Int?,
    dark: Boolean,
    onClick: (() -> Unit)?,
) {
    val isCurrent = WeekStatsModel.isCurrentWeek(week, currentSemesterWeek)
    QingyuCard(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = PaddingValues(16.dp),
        onClick = onClick,
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                // 点击与按压缩放交给 QingyuCard 的 onClick（官方 Sink 反馈），
                // 这里不再叠一层 Modifier.clickable，否则会吞掉卡片的手感。
                .padding(vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            ChartIconBadge(
                icon = MiuixIcons.Months,
                accent = Color(QingyuTheme.primary(dark = dark)),
                dark = dark,
            )
            Spacer(Modifier.width(10.dp))
            Text(
                text = WeekStatsModel.weekSelectorLabel(week),
                style = MiuixTheme.textStyles.title4,
                color = Color(QingyuTheme.primaryText(dark)),
                modifier = Modifier.weight(1f),
            )
            if (isCurrent) {
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(6.dp))
                        .background(Color(QingyuTheme.primary(dark = dark)).copy(alpha = 0.12f))
                        .padding(horizontal = 6.dp, vertical = 2.dp),
                ) {
                    Text(
                        text = WeekStatsModel.currentWeekHint,
                        style = MiuixTheme.textStyles.footnote2,
                        color = Color(QingyuTheme.primary(dark = dark)),
                    )
                }
                Spacer(Modifier.width(6.dp))
            }
            Icon(
                imageVector = MiuixIcons.ExpandMore,
                contentDescription = null,
                tint = Color(QingyuTheme.actionIcon(dark)),
                modifier = Modifier.size(22.dp),
            )
        }
    }
}

/** 本周课程列表：一个卡里排多行，行间细分隔线（Dart `HyperosListGroup` 的形态）。 */
@Composable
private fun WeekCourseListCard(
    rows: List<WeekStatsModel.WeekCourseRow>,
    dark: Boolean,
) {
    QingyuCard(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = PaddingValues(0.dp),
    ) {
        Column {
            rows.forEachIndexed { index, row ->
                if (index > 0) {
                    HorizontalDivider(
                        modifier = Modifier.padding(start = 16.dp),
                        thickness = 1.dp,
                        color = Color(QingyuTheme.dividerLine(dark)),
                    )
                }
                WeekCourseTile(row = row, dark = dark)
            }
        }
    }
}

@Composable
private fun WeekCourseTile(row: WeekStatsModel.WeekCourseRow, dark: Boolean) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = row.name,
                    style = MiuixTheme.textStyles.body1,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    color = Color(QingyuTheme.primaryText(dark)),
                    modifier = Modifier.weight(1f),
                )
                Spacer(Modifier.width(6.dp))
                val accent = if (row.isRequired) ChartPalette.Blue else ChartPalette.Purple
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(6.dp))
                        .background(accent.copy(alpha = 0.12f))
                        .padding(horizontal = 6.dp, vertical = 2.dp),
                ) {
                    Text(
                        text = row.natureLabel,
                        style = MiuixTheme.textStyles.footnote2,
                        color = accent,
                    )
                }
            }
            if (row.teacher.isNotEmpty()) {
                Spacer(Modifier.height(2.dp))
                Text(
                    text = row.teacher,
                    style = MiuixTheme.textStyles.footnote2,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
            }
            if (row.slots.isNotEmpty()) {
                Spacer(Modifier.height(6.dp))
                for (chunk in row.slots.map { it.short }.chunked(CourseRankingModel.SLOT_CHIPS_PER_ROW)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        for (label in chunk) {
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(6.dp))
                                    .background(Color(QingyuTheme.rowHighlight(dark)))
                                    .padding(horizontal = 8.dp, vertical = 3.dp),
                            ) {
                                Text(
                                    text = label,
                                    style = MiuixTheme.textStyles.footnote2,
                                    color = Color(QingyuTheme.secondaryText(dark)),
                                )
                            }
                        }
                    }
                    Spacer(Modifier.height(6.dp))
                }
            }
        }
        Spacer(Modifier.width(8.dp))
        Column(horizontalAlignment = Alignment.End) {
            Text(
                text = row.weeklySections.toString(),
                style = MiuixTheme.textStyles.body1,
                color = Color(QingyuTheme.primary(dark = dark)),
            )
            Text(
                text = ChartsStrings.statisticsSectionsUnit.zh,
                style = MiuixTheme.textStyles.footnote2,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
    }
}
