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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 课表对比卡：指标做表头、课表做行的平铺表格。
 *
 * 对应 Dart `lib/widgets/statistics/profile_compare_card.dart`（232 行）。
 * 四列定宽（48 / 40 / 64 / 36 dp，间距 8dp）**右对齐**——对比页的核心是
 * 「同一列比大小」，列宽随内容变会让表头与数据错位。
 *
 * 行内还有一条状态行：`第 5 周` +（当前课表）`当前课表` 或（其它）`较当前 +3 节`，
 * 差值用红（变多）/绿（变少）/灰（持平），与本周小结卡同一语义。
 */
@Composable
fun ProfileCompareCard(
    entries: List<ProfileCompareEntry>,
    dark: Boolean,
    modifier: Modifier = Modifier,
) {
    if (entries.isEmpty()) return
    val rows = ProfileCompareModel.rows(entries)
    val headers = ProfileCompareModel.headers()
    val widths = ProfileCompareModel.headerWidths()
    val gap = ProfileCompareModel.COL_GAP_DP.dp

    QingyuCard(
        modifier = modifier.fillMaxWidth(),
        insideMargin = PaddingValues(0.dp),
    ) {
        Column {
            // ── 表头 ──
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 16.dp, end = 16.dp, top = 14.dp, bottom = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(modifier = Modifier.weight(1f))
                headers.forEachIndexed { index, header ->
                    if (index > 0) Spacer(Modifier.width(gap))
                    Text(
                        text = header,
                        style = MiuixTheme.textStyles.footnote2,
                        textAlign = TextAlign.End,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        color = Color(QingyuTheme.secondaryText(dark)),
                        modifier = Modifier.width(widths[index].dp),
                    )
                }
            }

            rows.forEachIndexed { index, row ->
                HorizontalDivider(
                    modifier = Modifier.padding(start = 16.dp),
                    thickness = 1.dp,
                    color = Color(QingyuTheme.dividerLine(dark)),
                )
                ProfileCompareRowView(
                    row = row,
                    widths = widths,
                    gap = gap,
                    dark = dark,
                    isLast = index == rows.lastIndex,
                )
            }
        }
    }
}

@Composable
private fun ProfileCompareRowView(
    row: ProfileCompareRow,
    widths: List<Float>,
    gap: androidx.compose.ui.unit.Dp,
    dark: Boolean,
    isLast: Boolean,
) {
    val primary = Color(QingyuTheme.primary(dark = dark))
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 16.dp, end = 16.dp, top = 12.dp, bottom = if (isLast) 16.dp else 12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            // 状态圆点：当前课表用主题色，其余用次级文字色 40%
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(
                        if (row.isActive) primary else Color(QingyuTheme.secondaryText(dark)).copy(alpha = 0.4f),
                    ),
            )
            Spacer(Modifier.width(10.dp))
            Text(
                text = row.name,
                // 当前课表加粗，其余常规（Dart `w600 / w400`）
                style = MiuixTheme.textStyles.body1.shiftWeight(
                    if (row.isActive) QingyuWeightDelta.SEMIBOLD else 0,
                ),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                color = Color(QingyuTheme.primaryText(dark)),
                modifier = Modifier.weight(1f),
            )
            row.columns.forEachIndexed { index, value ->
                Spacer(Modifier.width(gap))
                Text(
                    text = value,
                    // 第二节数（index == 1）在当前课表时用主题色强调
                    style = MiuixTheme.textStyles.title4,
                    textAlign = TextAlign.End,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    color = if (index == 1 && row.isActive) {
                        primary
                    } else {
                        Color(QingyuTheme.primaryText(dark))
                    },
                    modifier = Modifier.width(widths[index].dp),
                )
            }
        }
        Spacer(Modifier.height(3.dp))
        Row(modifier = Modifier.padding(start = 18.dp)) {
            Text(
                text = row.weekLabel,
                style = MiuixTheme.textStyles.footnote2,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
            val active = row.activeLabel
            val delta = row.deltaLabel
            when {
                active != null -> {
                    Spacer(Modifier.width(6.dp))
                    Text(
                        text = active,
                        style = MiuixTheme.textStyles.footnote2,
                        color = primary,
                    )
                }
                delta != null -> {
                    Spacer(Modifier.width(6.dp))
                    val toneColor = when (row.deltaTone) {
                        ChartMath.DeltaTone.UP -> ChartPalette.Red
                        ChartMath.DeltaTone.DOWN -> ChartPalette.Green
                        else -> Color(QingyuTheme.secondaryText(dark))
                    }
                    Text(
                        text = delta,
                        style = MiuixTheme.textStyles.footnote2,
                        color = toneColor,
                    )
                }
            }
        }
    }
}

/** 课表对比卡的容器：多份课表并排比（Dart `statisticsCompareTitle` 分组）。 */
@Composable
fun ProfileCompareSection(
    entries: List<ProfileCompareEntry>,
    dark: Boolean,
    modifier: Modifier = Modifier,
) {
    if (entries.isEmpty()) return
    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        com.mutx163.qingyu.components.QingyuSectionTitle(text = ChartsStrings.statisticsCompareTitle.text)
        ProfileCompareCard(entries = entries, dark = dark)
    }
}
