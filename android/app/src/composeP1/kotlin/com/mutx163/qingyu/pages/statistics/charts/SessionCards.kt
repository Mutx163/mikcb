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
import com.mutx163.qingyu.core.CourseSessionStats
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 单节课汇总卡：四格并列读数（课次 / 已过 / 课时 / 有备注），首格主题色。
 *
 * 对应 Dart `lib/widgets/statistics/session_summary_card.dart`（106 行）。
 * 格与格之间是 1dp 竖分隔线（Dart `Container(width: 1, height: 28)`）。
 */
@Composable
fun SessionSummaryCard(
    stats: CourseSessionStats,
    dark: Boolean,
    modifier: Modifier = Modifier,
) {
    if (stats.isEmpty) return
    val metrics = SessionCardsModel.summary(stats)
    val dividerColor = Color(QingyuTheme.dividerLine(dark))

    QingyuCard(
        modifier = modifier.fillMaxWidth(),
        insideMargin = PaddingValues(horizontal = 8.dp, vertical = 16.dp),
    ) {
        Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            metrics.forEachIndexed { index, metric ->
                if (index > 0) {
                    Box(
                        modifier = Modifier
                            .width(1.dp)
                            .height(28.dp)
                            .background(dividerColor),
                    )
                }
                Column(
                    modifier = Modifier.weight(1f),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        text = metric.value,
                        // Dart `metricLarge` = 24sp（展示级数字）
                        style = MiuixTheme.textStyles.title2,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        textAlign = TextAlign.Center,
                        color = if (metric.highlight) {
                            Color(QingyuTheme.primary(dark = dark))
                        } else {
                            Color(QingyuTheme.primaryText(dark))
                        },
                    )
                    Spacer(Modifier.height(5.dp))
                    Text(
                        text = metric.label,
                        style = MiuixTheme.textStyles.footnote2,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        textAlign = TextAlign.Center,
                        color = if (metric.highlight) {
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

/**
 * 记录覆盖卡：这门课有多少次课留下了备注 / 作业 / 提醒。
 *
 * 对应 Dart `lib/widgets/statistics/session_coverage_card.dart`（121 行）。
 * 每行 = 标签 + `count / total` + 6dp 圆角进度条（真的按比例画）。
 *
 * 分母是**全部课次**（含停课与假期）——理由见 [SessionCardsModel] 的 KDoc，
 * 换成计划课次会出现 `3 / 1` 这种超过 100% 的数。
 */
@Composable
fun SessionCoverageCard(
    stats: CourseSessionStats,
    dark: Boolean,
    modifier: Modifier = Modifier,
) {
    if (stats.isEmpty) {
        QingyuCard(
            modifier = modifier.fillMaxWidth(),
            insideMargin = PaddingValues(16.dp),
        ) {
            Text(
                text = SessionCardsModel.emptyMessage,
                style = MiuixTheme.textStyles.body2,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
        return
    }

    val rows = SessionCardsModel.coverage(stats)
    QingyuCard(
        modifier = modifier.fillMaxWidth(),
        insideMargin = PaddingValues(16.dp),
    ) {
        Column {
            rows.forEachIndexed { index, row ->
                if (index > 0) Spacer(Modifier.height(12.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = row.label,
                        style = MiuixTheme.textStyles.body2,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        color = Color(QingyuTheme.primaryText(dark)),
                        modifier = Modifier.weight(1f),
                    )
                    Text(
                        text = row.countLabel,
                        style = MiuixTheme.textStyles.body2,
                        color = Color(QingyuTheme.primaryText(dark)),
                    )
                }
                Spacer(Modifier.height(6.dp))
                ChartProgressBar(
                    fraction = row.fraction,
                    color = sessionToneColor(row.tone, dark),
                    dark = dark,
                )
            }
        }
    }
}

/**
 * 课次列表卡：每次课一行（日期/周次 · 星期、节次 · 钟点 · 教室、状态角标、备注）。
 *
 * 对应 Dart `lib/widgets/statistics/session_list_card.dart`（199 行）。
 * 只**读**已有记录，不提供任何录入入口——这一页的定位是「把已经存在的记录摊开看」。
 */
@Composable
fun SessionListCard(
    stats: CourseSessionStats,
    dark: Boolean,
    modifier: Modifier = Modifier,
) {
    if (stats.isEmpty) {
        QingyuCard(
            modifier = modifier.fillMaxWidth(),
            insideMargin = PaddingValues(16.dp),
        ) {
            Text(
                text = SessionCardsModel.emptyMessage,
                style = MiuixTheme.textStyles.body2,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
        return
    }

    val rows = SessionCardsModel.rows(stats)
    QingyuCard(
        modifier = modifier.fillMaxWidth(),
        insideMargin = PaddingValues(0.dp),
    ) {
        Column {
            rows.forEachIndexed { index, row ->
                Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = row.title,
                            style = MiuixTheme.textStyles.body1,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            color = Color(QingyuTheme.primaryText(dark)),
                            modifier = Modifier.weight(1f),
                        )
                        Spacer(Modifier.width(8.dp))
                        val exam = row.examBadge
                        if (exam != null) {
                            SessionTag(text = exam, color = ChartPalette.Red)
                            Spacer(Modifier.width(6.dp))
                        }
                        SessionTag(
                            text = row.phaseLabel,
                            color = sessionToneColor(row.tone, dark),
                        )
                    }
                    Spacer(Modifier.height(2.dp))
                    Text(
                        text = row.subtitle,
                        style = MiuixTheme.textStyles.footnote2,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        color = Color(QingyuTheme.secondaryText(dark)),
                    )
                    val note = row.noteText
                    if (note != null) {
                        Spacer(Modifier.height(4.dp))
                        Text(
                            text = note,
                            style = MiuixTheme.textStyles.footnote2,
                            maxLines = 2,
                            overflow = TextOverflow.Ellipsis,
                            color = Color(QingyuTheme.primaryText(dark)),
                        )
                    }
                }
            }
        }
    }
}

/** 状态 / 考试角标：12% 底 + 语义色字。 */
@Composable
private fun SessionTag(text: String, color: Color) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .background(color.copy(alpha = 0.12f))
            .padding(horizontal = 6.dp, vertical = 2.dp),
    ) {
        Text(
            text = text,
            style = MiuixTheme.textStyles.footnote2,
            color = color,
        )
    }
}

/** [SessionTone] → 实际颜色（PRIMARY / SECONDARY 走主题槽位，其余走语义色板）。 */
private fun sessionToneColor(tone: SessionTone, dark: Boolean): Color = when (tone) {
    SessionTone.GREEN -> ChartPalette.Green
    SessionTone.PRIMARY -> Color(QingyuTheme.primary(dark = dark))
    SessionTone.BLUE -> ChartPalette.Blue
    SessionTone.ORANGE -> ChartPalette.Orange
    SessionTone.PURPLE -> ChartPalette.Purple
    SessionTone.SECONDARY -> Color(QingyuTheme.secondaryText(dark))
}
