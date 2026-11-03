package com.mutx163.qingyu.pages.statistics.charts

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.GridView
import top.yukonga.miuix.kmp.icon.extended.Months
import top.yukonga.miuix.kmp.icon.extended.Report
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 每周课时趋势卡 —— 真的画折线。
 *
 * 对应 Dart `lib/widgets/statistics/trend_chart.dart`。折线、线下面积、未来周虚线、
 * 圆点、横向网格线全部走 [TrendLineCanvas]（Compose `Canvas` 手绘），
 * 不是"再摆一行数字"。
 *
 * @param spec 由 [TrendChartModel.build] 算好的规格；`null` 时整卡不渲染
 *   （对齐 Dart `if (trend.isEmpty) return const SizedBox.shrink()`）
 * @param title 标题行文案；传 `null` 就是裸图卡（Dart 原版就是这样，
 *   标题由外层分组给）
 */
@Composable
fun TrendChartCard(
    spec: TrendChartSpec?,
    dark: Boolean,
    modifier: Modifier = Modifier,
    title: String? = null,
) {
    if (spec == null || spec.isEmpty) return

    QingyuCard(
        modifier = modifier.fillMaxWidth(),
        insideMargin = PaddingValues(16.dp),
    ) {
        Column {
            if (title != null) {
                ChartCardHeader(
                    title = title,
                    icon = MiuixIcons.Months,
                    accent = ChartPalette.Indigo,
                    dark = dark,
                )
                Spacer(Modifier.height(12.dp))
            }
            Row {
                ChartLeftAxisLabels(
                    maxY = spec.maxY,
                    heightDp = spec.chartHeightDp,
                    widthDp = spec.leftReserveDp,
                    dark = dark,
                )
                Column(modifier = Modifier.weight(1f)) {
                    TrendLineCanvas(spec = spec, dark = dark)
                    // 折线点位是边到边映射，标签行也按同一口径绝对定位（槽心会让刻度与点错位半个槽）。
                    ChartEdgeAxisLabelRow(
                        labels = spec.weekLabels.map { week -> week?.toString() },
                        dark = dark,
                    )
                }
            }
        }
    }
}

/**
 * 每日课时柱状图卡 —— 真的画柱。
 *
 * 两个口径共用这张卡：学期平均课时（[DailyChartModel.averageSpec]，高 168）与
 * 周视图每日节数（[DailyChartModel.weekSpec]，高 150）。差异由调用方决定传哪个规格。
 *
 * 最高那根柱子的横轴标签用主题色标出来（Dart `fontWeight: isMax ? w500 : w400`
 * 的同位表达——miuix 字阶里没有 w500 的槽位，改用颜色区分）。
 */
@Composable
fun DailyChartCard(
    spec: BarChartSpec?,
    dark: Boolean,
    modifier: Modifier = Modifier,
    chartHeightDp: Float = DailyChartModel.AVERAGE_CHART_HEIGHT_DP,
    leftReserveDp: Float = DailyChartModel.AVERAGE_LEFT_RESERVE_DP,
    title: String? = null,
) {
    if (spec == null || spec.isEmpty) return

    val maxIndex = spec.bars.indexOfFirst { it.emphasis == BarEmphasis.MAX }

    QingyuCard(
        modifier = modifier.fillMaxWidth(),
        insideMargin = PaddingValues(16.dp),
    ) {
        Column {
            if (title != null) {
                ChartCardHeader(
                    title = title,
                    icon = MiuixIcons.Report,
                    accent = ChartPalette.Blue,
                    dark = dark,
                )
                Spacer(Modifier.height(12.dp))
            }
            Row {
                ChartLeftAxisLabels(
                    maxY = spec.maxY,
                    heightDp = chartHeightDp,
                    widthDp = leftReserveDp,
                    dark = dark,
                )
                Column(modifier = Modifier.weight(1f)) {
                    BarChartCanvas(
                        spec = spec,
                        dark = dark,
                        chartHeightDp = chartHeightDp,
                    )
                    ChartAxisLabelRow(
                        labels = spec.bars.map { it.label },
                        dark = dark,
                        highlightIndex = if (maxIndex >= 0) maxIndex else null,
                    )
                }
            }
        }
    }
}

/**
 * 学期热力图卡 —— 真的画格子。
 *
 * 对应 Dart `heatmap_card.dart`：标题行（图标徽章 + 标题 + 右侧浅色提示）+ 周次标签行 +
 * 7 行 × N 列的方格。格子颜色按 [ChartMath.heatLevel] 的四档主色透明度；
 * 未来周先置 0 再算标度，所以未发生的课不会被画成"已经很忙"。
 *
 * 周数多时整块横向滚动（Dart 用的是 `SingleChildScrollView(scrollDirection: horizontal)`）。
 */
@Composable
fun SemesterHeatmapCard(
    spec: HeatmapSpec?,
    dark: Boolean,
    modifier: Modifier = Modifier,
) {
    if (spec == null || spec.isEmpty) return

    val cellSize = HeatmapSpec.CELL_SIZE_DP.dp
    val cellGap = HeatmapSpec.CELL_GAP_DP.dp
    val rowPitch = HeatmapSpec.ROW_PITCH_DP.dp
    val gridWidth = HeatmapModel.gridWidth(
        spec.weekCount,
        HeatmapSpec.CELL_SIZE_DP,
        HeatmapSpec.CELL_GAP_DP,
    ).dp

    QingyuCard(
        modifier = modifier.fillMaxWidth(),
        insideMargin = PaddingValues(16.dp),
    ) {
        Column {
            ChartCardHeader(
                title = ChartsStrings.statisticsHeatmapTitle.zh,
                icon = MiuixIcons.GridView,
                accent = ChartPalette.Indigo,
                dark = dark,
                trailing = ChartsStrings.statisticsHeatmapHint.zh,
            )
            Spacer(Modifier.height(HeatmapSpec.HEADER_TO_GRID_DP.dp))
            Row(modifier = Modifier.horizontalScroll(rememberScrollState())) {
                // 星期标签列：首行留空，与网格的周次标签行同高
                Column(modifier = Modifier.width(HeatmapSpec.LABEL_WIDTH_DP.dp)) {
                    Spacer(Modifier.height(rowPitch))
                    for (day in 0 until 7) {
                        Box(
                            modifier = Modifier
                                .width(HeatmapSpec.LABEL_WIDTH_DP.dp)
                                .height(rowPitch),
                            contentAlignment = Alignment.CenterStart,
                        ) {
                            // 字号**故意**不跟字阶走（规则 R4 的已知例外，2026-10-28 样式债清理时判定）：
                            // 这是热力网格的坐标标签，尺寸由 HeatmapSpec 的几何常量决定
                            // （列宽 LABEL_WIDTH_DP = 22dp、行高 rowPitch、格宽 CELL_SIZE_DP = 13dp），
                            // Dart 侧同样是 10sp（`heatmap_card.dart:98` 的 `copyWith(fontSize: 10)`）。
                            // 抬到字阶最近的一档 footnote2（11sp）会让「周次两位数字」在 13dp 的格子里
                            // 横向溢出裁字；而跟随用户字阶会把整个网格撑变形。故保留几何口径。
                            Text(
                                text = HeatmapModel.weekdayLabel(day),
                                style = MiuixTheme.textStyles.footnote2,
                                fontSize = HeatmapSpec.WEEKDAY_LABEL_SP.sp,
                                color = Color(QingyuTheme.secondaryText(dark)),
                            )
                        }
                    }
                }
                Spacer(Modifier.width(HeatmapSpec.LABEL_TO_GRID_GAP_DP.dp))
                Column {
                    // 周次标签行（每 4 周一个，末列必标）
                    Row(
                        modifier = Modifier.height(rowPitch),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        for (week in 1..spec.weekCount) {
                            Box(
                                modifier = Modifier
                                    .width(cellSize)
                                    .padding(end = cellGap),
                                contentAlignment = Alignment.Center,
                            ) {
                                val label = spec.weekLabels.getOrNull(week - 1)
                                if (label != null) {
                                    // 同上一处：周次标签的字号是几何口径（WEEK_LABEL_SP = 9sp，
                                    // Dart `heatmap_card.dart:98` 同值），格宽只有 CELL_SIZE_DP = 13dp，
                                    // 抬到 footnote2（11sp）后两位数会溢出。规则 R4 的已知例外。
                                    Text(
                                        text = label.toString(),
                                        style = MiuixTheme.textStyles.footnote2,
                                        fontSize = HeatmapSpec.WEEK_LABEL_SP.sp,
                                        textAlign = TextAlign.Center,
                                        color = Color(QingyuTheme.secondaryText(dark)),
                                    )
                                }
                            }
                        }
                    }
                    HeatGridCanvas(
                        spec = spec,
                        dark = dark,
                        modifier = Modifier.width(gridWidth),
                    )
                }
            }
        }
    }
}

/** 空态卡：与 Dart 一致的居中灰字（用于排行等列表为空时）。 */
@Composable
fun ChartEmptyCard(
    message: String,
    dark: Boolean,
    modifier: Modifier = Modifier,
) {
    QingyuCard(
        modifier = modifier.fillMaxWidth(),
        insideMargin = PaddingValues(16.dp),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 24.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = message,
                style = MiuixTheme.textStyles.body2,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
    }
}

/** 卡片内的一行"标签 + 数值"（图表卡里的次要读数，不是图本身）。 */
@Composable
fun ChartMetricRow(
    label: String,
    value: String,
    dark: Boolean,
    accent: Color? = null,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            style = MiuixTheme.textStyles.body2,
            color = Color(QingyuTheme.secondaryText(dark)),
        )
        Text(
            text = value,
            style = MiuixTheme.textStyles.body1,
            color = accent ?: Color(QingyuTheme.primaryText(dark)),
        )
    }
}
