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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.statistics.CourseNatureStats
import com.mutx163.qingyu.statistics.WeeklyComparison
import com.mutx163.qingyu.theme.QingyuTheme
import kotlin.math.roundToInt
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Notes
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 必修 / 选修比例卡 —— 真的画环形图。
 *
 * 对应 Dart `lib/widgets/statistics/nature_ratio.dart`（205 行）。
 *
 * 环由 [DonutRingCanvas] 手绘：环厚 20、孔 28（两侧都有课时），段间缝隙 2°；
 * 单侧为 0 时环收细到 18、孔加大到 32 并把「暂无必修 / 暂无选修」放进中心
 * ——这是 Dart 原注释写明的理由（多语言文案较长，怕压到环上）。
 *
 * 单侧为 0 时还会补一段 12% 透明度的「轨道段」，否则纯色圆会被误读为 100%。
 */
@Composable
fun NatureRatioCard(
    stats: CourseNatureStats,
    dark: Boolean,
    modifier: Modifier = Modifier,
) {
    val geometry = ChartMath.donutGeometry(stats.requiredCount, stats.electiveCount)

    QingyuCard(
        modifier = modifier.fillMaxWidth(),
        insideMargin = PaddingValues(16.dp),
    ) {
        if (!geometry.hasData) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 12.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = ChartsStrings.statisticsNoData.text,
                    style = MiuixTheme.textStyles.body2,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
            }
            return@QingyuCard
        }

        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier.size(100.dp),
                contentAlignment = Alignment.Center,
            ) {
                DonutRingCanvas(
                    requiredCount = stats.requiredCount,
                    electiveCount = stats.electiveCount,
                    modifier = Modifier.size(100.dp),
                )
                val missingLabel = geometry.missingLabel
                if (missingLabel != null) {
                    Text(
                        text = missingLabel,
                        style = MiuixTheme.textStyles.footnote2,
                        textAlign = TextAlign.Center,
                        maxLines = 2,
                        color = Color(QingyuTheme.secondaryText(dark)),
                        modifier = Modifier.padding(horizontal = 6.dp),
                    )
                }
            }
            Spacer(Modifier.width(20.dp))
            Column(modifier = Modifier.weight(1f)) {
                NatureLegendItem(
                    color = ChartPalette.Blue,
                    label = ChartsStrings.courseNatureRequired.text,
                    count = stats.requiredCount,
                    sections = stats.requiredSections,
                    ratio = stats.requiredRatio,
                    dark = dark,
                )
                Spacer(Modifier.height(12.dp))
                NatureLegendItem(
                    color = ChartPalette.Purple,
                    label = ChartsStrings.courseNatureElective.text,
                    count = stats.electiveCount,
                    sections = stats.electiveSections,
                    ratio = stats.electiveRatio,
                    dark = dark,
                )
            }
        }
    }
}

/** 图例一行：色块 + 名称 + `3 门 · 12 节` + 右侧百分比。 */
@Composable
private fun NatureLegendItem(
    color: Color,
    label: String,
    count: Int,
    sections: Int,
    ratio: Double,
    dark: Boolean,
) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(
            modifier = Modifier
                .size(12.dp)
                .clip(RoundedCornerShape(4.dp))
                .background(color),
        )
        Spacer(Modifier.width(8.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = label,
                style = MiuixTheme.textStyles.body1,
                color = Color(QingyuTheme.primaryText(dark)),
            )
            Text(
                text = ChartsStrings.statisticsNatureLegendDetail.filled(
                    "count" to count.toString(),
                    "sections" to sections.toString(),
                ),
                style = MiuixTheme.textStyles.footnote2,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
        Text(
            // 百分比按「本侧 / 两侧合计」算（ratio 已是该口径），四舍五入到整数。
            // 用 roundToInt（ties away from zero）而不是 round().toInt()（ties to even）：
            // 与学期视图的 percentText 和 Dart `(ratio*100).round()` 同口径，
            // 否则 1/8 会在两个页签分别显示 12% / 13%。
            text = "${(ratio * 100).roundToInt()}%",
            style = MiuixTheme.textStyles.body1,
            color = color,
        )
    }
}

/**
 * 本周小结卡：本周课时 / 较上周 / 学期周均 三格对比。
 *
 * 对应 Dart `lib/widgets/statistics/weekly_comparison_card.dart`（155 行）。
 *
 * 差值配色沿用 Dart 的语义：**课时变多用红、变少用绿、持平用灰**
 *（`up = red` / `down = green`）。这里的红绿不是"好坏"，只是"增减"。
 * 第一周没有上周可比，第二格显示 `—` 并在下方补一句「新学期第一周」。
 */
@Composable
fun WeeklyComparisonCard(
    comparison: WeeklyComparison,
    currentWeek: Int,
    dark: Boolean,
    modifier: Modifier = Modifier,
) {
    val isFirstWeek = currentWeek <= 1
    val primary = Color(QingyuTheme.primary(dark = dark))
    val delta = comparison.deltaVsLastWeek
    val deltaColor = when (ChartMath.deltaTone(delta)) {
        ChartMath.DeltaTone.UP -> ChartPalette.Red
        ChartMath.DeltaTone.DOWN -> ChartPalette.Green
        ChartMath.DeltaTone.FLAT -> Color(QingyuTheme.secondaryText(dark))
    }
    val deltaText = ChartMath.deltaText(delta)

    QingyuCard(
        modifier = modifier.fillMaxWidth(),
        insideMargin = PaddingValues(16.dp),
    ) {
        Column {
            ChartCardHeader(
                title = ChartsStrings.statisticsComparisonTitle.text,
                icon = MiuixIcons.Notes,
                accent = ChartPalette.Orange,
                dark = dark,
                trailing = WeekStatsModel.weekSelectorLabel(currentWeek),
            )
            Spacer(Modifier.height(12.dp))
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                ComparisonCell(
                    value = comparison.weekSections.toString(),
                    label = ChartsStrings.statisticsSectionCount.text,
                    accent = primary,
                    dark = dark,
                    highlight = true,
                    modifier = Modifier.weight(1f),
                )
                ComparisonCell(
                    value = if (isFirstWeek) "—" else deltaText,
                    // Dart `weekly_comparison_card.dart:70-76` 第一周也走
                    // `statisticsComparisonVsLastWeek('—')`（「较上周 — 节」），
                    // 不是另一句「上周课时」。原先两个页签因此显示了不同标签。
                    label = ChartsStrings.statisticsComparisonVsLastWeek.filled(
                        "delta" to if (isFirstWeek) "—" else deltaText,
                    ),
                    accent = if (isFirstWeek) Color(QingyuTheme.secondaryText(dark)) else deltaColor,
                    dark = dark,
                    modifier = Modifier.weight(1f),
                )
                ComparisonCell(
                    value = ChartMath.oneDecimal(comparison.semesterAverageSections),
                    label = ChartsStrings.statisticsComparisonAverage.text,
                    accent = ChartPalette.Teal,
                    dark = dark,
                    alignEnd = true,
                    modifier = Modifier.weight(1f),
                )
            }
            if (isFirstWeek) {
                Spacer(Modifier.height(8.dp))
                Text(
                    text = ChartsStrings.statisticsComparisonNew.text,
                    style = MiuixTheme.textStyles.footnote2,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
            }
        }
    }
}

/** 对比卡的一格：大号数字 + 说明。 */
@Composable
private fun ComparisonCell(
    value: String,
    label: String,
    accent: Color,
    dark: Boolean,
    modifier: Modifier = Modifier,
    highlight: Boolean = false,
    alignEnd: Boolean = false,
) {
    Column(
        modifier = modifier,
        horizontalAlignment = if (alignEnd) Alignment.End else Alignment.Start,
    ) {
        Text(
            text = value,
            // Dart `HyperosTypography.metricLarge` = 24sp（展示级数字）
            style = MiuixTheme.textStyles.title2,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            textAlign = if (alignEnd) TextAlign.End else TextAlign.Start,
            color = accent,
        )
        Spacer(Modifier.height(5.dp))
        Text(
            text = label,
            style = MiuixTheme.textStyles.footnote2,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            textAlign = if (alignEnd) TextAlign.End else TextAlign.Start,
            color = if (highlight) {
                Color(QingyuTheme.primaryText(dark))
            } else {
                Color(QingyuTheme.secondaryText(dark))
            },
        )
    }
}
