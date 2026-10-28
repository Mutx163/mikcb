package com.mutx163.qingyu.pages.statistics.charts

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.statistics.CourseSemesterStat
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Edit
import top.yukonga.miuix.kmp.icon.extended.ExpandLess
import top.yukonga.miuix.kmp.icon.extended.ExpandMore
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 课程排行卡 —— 名次徽章 + 排名条 + 可展开的时间槽明细。
 *
 * 对应 Dart `lib/widgets/statistics/course_ranking.dart`（405 行）。
 *
 * ## 与 Dart 的两处有意差异（都写在这里，免得下一个人以为是漏迁）
 *
 * 1. **名次徽章不画奖杯图标**：Dart 用 `Icons.emoji_events_rounded` 给前三名，
 *    本仓库当前引用的 miuix-icons 0.9.4 里没有奖杯/奖牌类图标；
 *    换成星形会与本 App「收藏」的语义撞车。改为**前三名用金/银/铜三色数字**，
 *    其余用灰数字——信息一样，不误导读法。
 * 2. **多了一根排名条**：Dart 只有数字，横向比较要靠眼睛在数字间来回扫；
 *    这里给每门课一条按「课时 / 榜首课时」比例的细条（[CourseRankingRow.barFraction]），
 *    让"谁多谁少"一眼可见。数值没有新增，只是把已有数字可视化。
 *
 * @param courseRanking 已按课时降序排好的课程学期统计（排序归上游）
 * @param onCourseTap 展开明细里「编辑课程」的点击回调；`null` 时不显示该入口
 */
@Composable
fun CourseRankingCard(
    courseRanking: List<CourseSemesterStat>,
    dark: Boolean,
    modifier: Modifier = Modifier,
    onCourseTap: ((String) -> Unit)? = null,
) {
    val rows = CourseRankingModel.build(courseRanking)
    if (rows.isEmpty()) {
        ChartEmptyCard(
            message = CourseRankingModel.emptyMessage,
            dark = dark,
            modifier = modifier,
        )
        return
    }

    QingyuCard(
        modifier = modifier.fillMaxWidth(),
        insideMargin = PaddingValues(0.dp),
    ) {
        Column {
            rows.forEachIndexed { index, row ->
                if (index > 0) {
                    HorizontalDivider(
                        modifier = Modifier.padding(start = 60.dp),
                        thickness = 1.dp,
                        color = Color(QingyuTheme.dividerLine(dark)),
                    )
                }
                CourseRankingTile(
                    row = row,
                    dark = dark,
                    onEdit = onCourseTap?.let { callback -> { callback(row.name) } },
                )
            }
        }
    }
}

@Composable
private fun CourseRankingTile(
    row: CourseRankingRow,
    dark: Boolean,
    onEdit: (() -> Unit)?,
) {
    var expanded by remember { mutableStateOf(false) }

    Column(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { expanded = !expanded }
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.Top,
        ) {
            RankBadge(rank = row.rank, dark = dark)
            Spacer(Modifier.width(10.dp))
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
                    NatureChip(label = row.natureLabel, isRequired = row.isRequired)
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
                    SlotChips(labels = row.slots.map { it.short }, dark = dark)
                }
                Spacer(Modifier.height(8.dp))
                RankingBar(fraction = row.barFraction, dark = dark)
            }
            Spacer(Modifier.width(8.dp))
            Column(horizontalAlignment = Alignment.End) {
                Text(
                    text = row.totalSections.toString(),
                    style = MiuixTheme.textStyles.body1,
                    color = Color(QingyuTheme.primary(dark = dark)),
                )
                Text(
                    text = ChartsStrings.statisticsSectionsUnit.zh,
                    style = MiuixTheme.textStyles.footnote2,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
            }
            Spacer(Modifier.width(4.dp))
            Icon(
                imageVector = if (expanded) MiuixIcons.ExpandLess else MiuixIcons.ExpandMore,
                contentDescription = null,
                tint = Color(QingyuTheme.actionIcon(dark)),
                modifier = Modifier
                    .padding(top = 2.dp)
                    .size(20.dp),
            )
        }

        if (expanded) {
            Column(modifier = Modifier.padding(start = 62.dp, end = 16.dp, bottom = 12.dp)) {
                for (slot in row.slots) {
                    Text(
                        text = slot.detail,
                        style = MiuixTheme.textStyles.footnote1,
                        color = Color(QingyuTheme.secondaryText(dark)),
                        modifier = Modifier.padding(vertical = 3.dp),
                    )
                }
                if (onEdit != null) {
                    Spacer(Modifier.height(6.dp))
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onEdit() }
                            .padding(vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(
                            imageVector = MiuixIcons.Edit,
                            contentDescription = null,
                            tint = Color(QingyuTheme.actionIcon(dark)),
                            modifier = Modifier.size(16.dp),
                        )
                        Spacer(Modifier.width(8.dp))
                        Text(
                            text = ChartsStrings.editCourseTitle.zh,
                            style = MiuixTheme.textStyles.body2,
                            color = Color(QingyuTheme.primaryText(dark)),
                        )
                    }
                }
            }
        }
    }
}

/**
 * 名次徽章：36dp 圆角方块。
 *
 * 1~3 名分别用金 / 银 / 铜三色（Dart 用奖杯图标区分，见文件头差异说明）。
 */
@Composable
private fun RankBadge(rank: Int, dark: Boolean) {
    val secondary = Color(QingyuTheme.secondaryText(dark))
    val (background, foreground) = when (rank) {
        1 -> ChartPalette.Yellow.copy(alpha = 0.18f) to ChartPalette.Yellow
        2 -> secondary.copy(alpha = 0.14f) to secondary
        3 -> ChartPalette.Orange.copy(alpha = 0.16f) to ChartPalette.Orange
        else -> secondary.copy(alpha = 0.10f) to secondary
    }
    Box(
        modifier = Modifier
            .size(36.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(background),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = rank.toString(),
            style = MiuixTheme.textStyles.body1,
            color = foreground,
        )
    }
}

/** 必修 / 选修小胶囊：蓝=必修、紫=选修，底色 12%。 */
@Composable
private fun NatureChip(label: String, isRequired: Boolean) {
    val accent = if (isRequired) ChartPalette.Blue else ChartPalette.Purple
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .background(accent.copy(alpha = 0.12f))
            .padding(horizontal = 6.dp, vertical = 2.dp),
    ) {
        Text(
            text = label,
            style = MiuixTheme.textStyles.footnote2,
            color = accent,
        )
    }
}

/**
 * 时间槽胶囊，每 [CourseRankingModel.SLOT_CHIPS_PER_ROW] 个一行。
 *
 * 为什么不用 `FlowRow`：它在当前 Compose 版本仍需 `@OptIn(ExperimentalLayoutApi)`
 * 且换行时机依赖测量，槽位数固定为 3 时手工分行更可控、也不引入实验 API。
 */
@Composable
private fun SlotChips(labels: List<String>, dark: Boolean) {
    val rows = labels.chunked(CourseRankingModel.SLOT_CHIPS_PER_ROW)
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        for (chunk in rows) {
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
        }
    }
}

/**
 * 排名条：底轨 + 按比例填充的圆头细条（Canvas 手绘，4dp 高）。
 *
 * 比例来自 [CourseRankingRow.barFraction]（课时 / 榜首课时），
 * 榜首自己永远是满格——这是"相对"读法，不是"绝对进度"。
 */
@Composable
private fun RankingBar(fraction: Double, dark: Boolean) {
    val trackColor = Color(QingyuTheme.dividerLine(dark))
    val fillColor = Color(QingyuTheme.primary(dark = dark))
    Canvas(
        modifier = Modifier
            .fillMaxWidth()
            .height(4.dp),
    ) {
        val radius = CornerRadius(size.height / 2f)
        drawRoundRect(
            color = trackColor,
            topLeft = Offset.Zero,
            size = Size(size.width, size.height),
            cornerRadius = radius,
        )
        val filled = (size.width * fraction.toFloat().coerceIn(0f, 1f))
        if (filled > 0f) {
            drawRoundRect(
                color = fillColor,
                topLeft = Offset.Zero,
                size = Size(filled, size.height),
                cornerRadius = radius,
            )
        }
    }
}
