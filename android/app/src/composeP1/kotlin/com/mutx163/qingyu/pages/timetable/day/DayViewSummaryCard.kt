package com.mutx163.qingyu.pages.timetable.day

import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Close
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 日视图顶部全天概览卡（Day View Summary Card）。
 *
 * 对应 Flutter `lib/widgets/timetable/day_view/day_view_summary_card.dart`：
 * - 顶部日期与周次标题（带关闭返回周视图叉号按钮）
 * - 大字日期标题
 * - 课程/日程/待办三合一统计胶囊
 * - 当前进行状态（正在上课/今日课程已结束）、冲突警告、非本周、考试倒计时高亮
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun DayViewSummaryCard(
    state: DayViewSummaryState,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val dark = isSystemInDarkTheme()

    QingyuCard(
        modifier = modifier.fillMaxWidth(),
        insideMargin = PaddingValues(horizontal = 16.dp, vertical = 14.dp),
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            // ── 顶部栏：今天 · 第几周 + 关闭叉号按钮 ──
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.weight(1f, fill = false),
                ) {
                    if (state.isToday) {
                        Text(
                            text = DayViewStrings.todayTimetableTitle.zh,
                            style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.MEDIUM),
                            color = Color(QingyuTheme.secondaryText(dark)),
                        )
                        Text(
                            text = " · ",
                            style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.MEDIUM),
                            color = Color(QingyuTheme.secondaryText(dark)),
                        )
                    }
                    Text(
                        text = DayViewStrings.weekLabel(state.week),
                        style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.MEDIUM),
                        color = Color(QingyuTheme.secondaryText(dark)),
                    )
                }

                IconButton(
                    onClick = onClose,
                    modifier = Modifier.size(28.dp),
                ) {
                    Icon(
                        imageVector = MiuixIcons.Close,
                        contentDescription = DayViewStrings.backToWeekViewAction.zh,
                        tint = Color(QingyuTheme.actionIcon(dark)),
                        modifier = Modifier.size(16.dp),
                    )
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            // ── 大字日期标题（如 "10月27日 周二"）──
            Text(
                text = state.dateLabel,
                style = MiuixTheme.textStyles.title3,
                lineHeight = 26.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                color = Color(QingyuTheme.primaryText(dark)),
            )

            Spacer(modifier = Modifier.height(10.dp))

            // ── 统计胶囊区（课程数 / 日程数 / 议程起止时间）──
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                // 主计数胶囊（"4 门课" 或 "日程 2 项" 或 "作业 1 项" 或 "0 门课"）
                SummaryNeutralCapsule(text = state.countLabel, dark = dark)

                // 辅日程计数胶囊（既有课又有日程时展示）
                if (!state.scheduleLabel.isNullOrBlank()) {
                    SummaryNeutralCapsule(text = state.scheduleLabel, dark = dark)
                }

                // 议程时间区间（如 "08:00 开始 · 20:30 结束"）
                if (!state.agendaRangeLabel.isNullOrBlank()) {
                    Text(
                        text = state.agendaRangeLabel,
                        style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.MEDIUM),
                        color = Color(QingyuTheme.secondaryText(dark)),
                    )
                }
            }

            // ── 状态胶囊区（正在上课、冲突节数、非本周、考试倒计时等）──
            if (state.statusChips.isNotEmpty()) {
                Spacer(modifier = Modifier.height(10.dp))
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    state.statusChips.forEach { chip ->
                        SummaryStatusCapsule(chip = chip, dark = dark)
                    }
                }
            }
        }
    }
}

/**
 * 摘要卡中性信息胶囊（灰色浅底）。
 */
@Composable
private fun SummaryNeutralCapsule(
    text: String,
    dark: Boolean,
) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(7.dp))
            .background(Color(QingyuTheme.primaryText(dark)).copy(alpha = 0.08f))
            .padding(horizontal = 8.dp, vertical = 3.dp),
    ) {
        Text(
            text = text,
            style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
            color = Color(QingyuTheme.secondaryText(dark)),
        )
    }
}

/**
 * 摘要卡状态胶囊（圆角药丸胶囊，带不同语义高亮色彩）。
 */
@Composable
private fun SummaryStatusCapsule(
    chip: SummaryChip,
    dark: Boolean,
) {
    val accentColor = when (chip.kind) {
        SummaryChipKind.ONGOING_COURSE -> Color(QingyuTheme.primary(null, dark))
        SummaryChipKind.CONFLICT -> Color(QingyuTheme.error(dark))
        SummaryChipKind.NON_CURRENT_WEEK -> Color(QingyuTheme.secondaryText(dark))
        SummaryChipKind.EXAM -> Color(QingyuTheme.error(dark))
    }

    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(999.dp))
            .background(accentColor.copy(alpha = 0.12f))
            .padding(horizontal = 9.dp, vertical = 4.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            // 小圆点装饰指示器
            Box(
                modifier = Modifier
                    .size(5.dp)
                    .clip(CircleShape)
                    .background(accentColor),
            )
            Text(
                text = chip.text,
                style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                color = accentColor,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}
