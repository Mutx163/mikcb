package com.mutx163.qingyu.pages.statistics.charts

import androidx.compose.foundation.Canvas
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.statistics.SemesterProgress
import com.mutx163.qingyu.statistics.TeacherStat
import com.mutx163.qingyu.statistics.TimeUtilizationStats
import com.mutx163.qingyu.statistics.VenueStats
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Community
import top.yukonga.miuix.kmp.icon.extended.Location
import top.yukonga.miuix.kmp.icon.extended.Months
import top.yukonga.miuix.kmp.icon.extended.Timer
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 时间利用卡：7 项并列读数（早→晚→早间→午间→晚间→周末→最长空档）。
 *
 * 对应 Dart `lib/widgets/statistics/time_utilization_card.dart`（163 行）。
 *
 * **与 Dart 的差异**：Dart 每行配一个语义图标（太阳 / 月亮 / 早餐 / 床位…），
 * 当前 miuix-icons 0.9.4 没有对应图标，随便换个图标会误导语义；
 * 这里改用一个**语义色圆点**（颜色仍按 Dart 的七色），读数与顺序不变。
 *
 * @param standalone 独立二级页模式：省掉卡内标题（与页面大标题重复），
 *   并把行距与字号抬到正文刻度——Dart 同名参数就是这意思
 */
@Composable
fun TimeUtilizationCard(
    stats: TimeUtilizationStats,
    dark: Boolean,
    modifier: Modifier = Modifier,
    standalone: Boolean = false,
) {
    if (stats.isEmpty) return
    val facts = TimeUtilizationModel.facts(stats)

    QingyuCard(
        modifier = modifier.fillMaxWidth(),
        insideMargin = PaddingValues(16.dp),
    ) {
        Column {
            if (!standalone) {
                ChartCardHeader(
                    title = ChartsStrings.statisticsTimeUtilTitle.text,
                    icon = MiuixIcons.Timer,
                    accent = ChartPalette.Cyan,
                    dark = dark,
                )
                Spacer(Modifier.height(8.dp))
            }
            facts.forEachIndexed { index, fact ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = if (standalone) 12.dp else 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Box(
                        modifier = Modifier
                            .size(if (standalone) 10.dp else 8.dp)
                            .clip(CircleShape)
                            .background(accentColor(fact.accent)),
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(
                        text = fact.label,
                        style = if (standalone) MiuixTheme.textStyles.body1 else MiuixTheme.textStyles.footnote2,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        color = if (standalone) {
                            Color(QingyuTheme.primaryText(dark))
                        } else {
                            Color(QingyuTheme.secondaryText(dark))
                        },
                        modifier = Modifier.weight(1f),
                    )
                    Spacer(Modifier.width(6.dp))
                    Text(
                        text = fact.value,
                        style = if (standalone) MiuixTheme.textStyles.title4 else MiuixTheme.textStyles.body2,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        color = Color(QingyuTheme.primaryText(dark)),
                    )
                }
            }
        }
    }
}

/** 时间利用语义色 → 实际颜色（取值抄 Dart 每行的 `HyperosIconColors.X`）。 */
private fun accentColor(accent: TimeAccent): Color = when (accent) {
    TimeAccent.ORANGE -> ChartPalette.Orange
    TimeAccent.INDIGO -> ChartPalette.Indigo
    TimeAccent.YELLOW -> ChartPalette.Yellow
    TimeAccent.TEAL -> ChartPalette.Teal
    TimeAccent.PURPLE -> ChartPalette.Purple
    TimeAccent.BLUE -> ChartPalette.Blue
    TimeAccent.RED -> ChartPalette.Red
}

/**
 * 教室与教学楼卡：两组横向条形读数（常去教室 / 教学楼课时）。
 *
 * 对应 Dart `lib/widgets/statistics/venue_stats_card.dart`（177 行）。
 * 条形长度 = 本项 / 榜首项，条高 6dp、圆角 3dp（Dart `LinearProgressIndicator(minHeight: 6)`）。
 */
@Composable
fun VenueStatsCard(
    stats: VenueStats,
    dark: Boolean,
    modifier: Modifier = Modifier,
    standalone: Boolean = false,
) {
    val bars = VenueStatsModel.bars(stats)
    if (bars.isEmpty) return

    QingyuCard(
        modifier = modifier.fillMaxWidth(),
        insideMargin = PaddingValues(16.dp),
    ) {
        Column {
            if (!standalone) {
                ChartCardHeader(
                    title = ChartsStrings.statisticsVenueTitle.text,
                    icon = MiuixIcons.Location,
                    accent = ChartPalette.Purple,
                    dark = dark,
                )
            }
            if (bars.rooms.isNotEmpty()) {
                Spacer(Modifier.height(14.dp))
                Text(
                    text = ChartsStrings.statisticsVenueTopRooms.text,
                    style = MiuixTheme.textStyles.footnote1,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
                Spacer(Modifier.height(8.dp))
                bars.rooms.forEachIndexed { index, row ->
                    if (index > 0) Spacer(Modifier.height(8.dp))
                    HorizontalBarRow(row = row, color = ChartPalette.Blue, dark = dark, standalone = standalone)
                }
            }
            if (bars.buildings.isNotEmpty()) {
                Spacer(Modifier.height(14.dp))
                Text(
                    text = ChartsStrings.statisticsVenueBuildings.text,
                    style = MiuixTheme.textStyles.footnote1,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
                Spacer(Modifier.height(8.dp))
                bars.buildings.forEachIndexed { index, row ->
                    if (index > 0) Spacer(Modifier.height(8.dp))
                    HorizontalBarRow(row = row, color = ChartPalette.Teal, dark = dark, standalone = standalone)
                }
            }
        }
    }
}

/** 一条横条读数：定宽标签 + 圆角进度条 + 定宽读数（列对齐靠定宽，不靠测量）。 */
@Composable
private fun HorizontalBarRow(
    row: BarRowModel,
    color: Color,
    dark: Boolean,
    standalone: Boolean,
) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(
            text = row.label,
            style = MiuixTheme.textStyles.body2,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            color = if (standalone) {
                Color(QingyuTheme.primaryText(dark))
            } else {
                Color(QingyuTheme.secondaryText(dark))
            },
            modifier = Modifier.width(if (standalone) 140.dp else 110.dp),
        )
        Spacer(Modifier.width(10.dp))
        ChartProgressBar(
            fraction = row.fraction,
            color = color,
            dark = dark,
            heightDp = if (standalone) 8.dp else 6.dp,
            modifier = Modifier.weight(1f),
        )
        Spacer(Modifier.width(10.dp))
        Text(
            text = row.value,
            style = MiuixTheme.textStyles.body2,
            textAlign = TextAlign.End,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            color = Color(QingyuTheme.primaryText(dark)),
            modifier = Modifier.width(if (standalone) 72.dp else 64.dp),
        )
    }
}

/**
 * 圆角进度条（Canvas 手绘）：底轨 + 按比例填充。
 *
 * 与 Dart `LinearProgressIndicator(minHeight: 6)` 的观感一致，
 * 但不依赖 Material 组件（本页统一走 miuix + 手绘）。
 */
@Composable
fun ChartProgressBar(
    fraction: Double,
    color: Color,
    dark: Boolean,
    modifier: Modifier = Modifier,
    heightDp: androidx.compose.ui.unit.Dp = 6.dp,
) {
    val trackColor = Color(QingyuTheme.rowHighlight(dark))
    Canvas(
        modifier = modifier
            .fillMaxWidth()
            .height(heightDp),
    ) {
        val radius = CornerRadius(size.height / 2f)
        drawRoundRect(
            color = trackColor,
            topLeft = Offset.Zero,
            size = Size(size.width, size.height),
            cornerRadius = radius,
        )
        val filled = size.width * fraction.toFloat().coerceIn(0f, 1f)
        if (filled > 0f) {
            drawRoundRect(
                color = color,
                topLeft = Offset.Zero,
                size = Size(filled, size.height),
                cornerRadius = radius,
            )
        }
    }
}

/**
 * 教师课时排行卡。
 *
 * 对应 Dart `lib/widgets/statistics/teacher_stats_card.dart`（97 行）：
 * 名次（前三名黄色）+ 教师名 + `N 门课` + `N 节`。名次同样照 Dart 的 `i + 1`。
 */
@Composable
fun TeacherStatsCard(
    stats: List<TeacherStat>,
    dark: Boolean,
    modifier: Modifier = Modifier,
) {
    val rows = TeacherStatsModel.rows(stats)
    if (rows.isEmpty()) return

    QingyuCard(
        modifier = modifier.fillMaxWidth(),
        insideMargin = PaddingValues(0.dp),
    ) {
        Column {
            Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp)) {
                ChartCardHeader(
                    title = ChartsStrings.statisticsTeacherTitle.text,
                    icon = MiuixIcons.Community,
                    accent = ChartPalette.Green,
                    dark = dark,
                )
            }
            rows.forEach { row ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Box(modifier = Modifier.width(24.dp)) {
                        Text(
                            text = row.rank.toString(),
                            style = MiuixTheme.textStyles.body2,
                            color = if (row.topThree) {
                                ChartPalette.Yellow
                            } else {
                                Color(QingyuTheme.secondaryText(dark))
                            },
                        )
                    }
                    Spacer(Modifier.width(10.dp))
                    Text(
                        text = row.name,
                        style = MiuixTheme.textStyles.body1,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        color = Color(QingyuTheme.primaryText(dark)),
                        modifier = Modifier.weight(1f),
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(
                        text = row.courseCountLabel,
                        style = MiuixTheme.textStyles.footnote2,
                        color = Color(QingyuTheme.secondaryText(dark)),
                    )
                    Spacer(Modifier.width(10.dp))
                    Text(
                        text = row.sectionsLabel,
                        style = MiuixTheme.textStyles.body1,
                        color = Color(QingyuTheme.primary(dark = dark)),
                    )
                }
            }
        }
    }
}

/**
 * 学期进度卡：周次比 + 日期范围 + 进度条 + 两格读数。
 *
 * 对应 Dart `lib/widgets/statistics/semester_progress_card.dart`（148 行）。
 * 进度条走 [ChartProgressBar] 手绘；百分比与「剩余 N 节」的文案全部由
 * [SemesterProgressModel] 算好，这里只画。
 */
@Composable
fun SemesterProgressCard(
    progress: SemesterProgress,
    dark: Boolean,
    modifier: Modifier = Modifier,
) {
    val spec = SemesterProgressModel.build(progress)

    QingyuCard(
        modifier = modifier.fillMaxWidth(),
        insideMargin = PaddingValues(16.dp),
    ) {
        Column {
            Row(verticalAlignment = Alignment.CenterVertically) {
                ChartIconBadge(
                    icon = MiuixIcons.Months,
                    accent = Color(QingyuTheme.primary(dark = dark)),
                    dark = dark,
                )
                Spacer(Modifier.width(10.dp))
                Text(
                    text = ChartsStrings.statisticsSemesterProgressTitle.text,
                    style = MiuixTheme.textStyles.body1,
                    color = Color(QingyuTheme.primaryText(dark)),
                    modifier = Modifier.weight(1f),
                )
                Text(
                    text = spec.weekRatioLabel,
                    style = MiuixTheme.textStyles.body1,
                    color = Color(QingyuTheme.primary(dark = dark)),
                )
            }
            if (spec.dateRangeLabel != null) {
                Spacer(Modifier.height(6.dp))
                Text(
                    text = spec.dateRangeLabel,
                    style = MiuixTheme.textStyles.footnote2,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
            }
            Spacer(Modifier.height(12.dp))
            ChartProgressBar(
                fraction = spec.percent,
                color = Color(QingyuTheme.primary(dark = dark)),
                dark = dark,
            )
            Spacer(Modifier.height(10.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.Bottom,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                ProgressFact(
                    value = spec.percentLabel,
                    label = spec.detailLabel,
                    dark = dark,
                    modifier = Modifier.weight(1f),
                )
                if (!spec.beforeStart && spec.sideLabel != null && spec.remainingLabel != null) {
                    ProgressFact(
                        value = spec.remainingLabel,
                        label = spec.sideLabel,
                        dark = dark,
                        alignEnd = true,
                        modifier = Modifier.weight(1f),
                    )
                }
            }
        }
    }
}

/** 进度卡的一格读数：大数字 + 说明。 */
@Composable
private fun ProgressFact(
    value: String,
    label: String,
    dark: Boolean,
    modifier: Modifier = Modifier,
    alignEnd: Boolean = false,
) {
    Column(
        modifier = modifier,
        horizontalAlignment = if (alignEnd) Alignment.End else Alignment.Start,
    ) {
        Text(
            text = value,
            style = MiuixTheme.textStyles.title4,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            color = Color(QingyuTheme.primaryText(dark)),
        )
        Spacer(Modifier.height(2.dp))
        Text(
            text = label,
            style = MiuixTheme.textStyles.footnote2,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            textAlign = if (alignEnd) TextAlign.End else TextAlign.Start,
            color = Color(QingyuTheme.secondaryText(dark)),
        )
    }
}
