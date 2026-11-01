package com.mutx163.qingyu.pages.statistics.charts

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.statistics.Achievement
import com.mutx163.qingyu.statistics.DataStory
import com.mutx163.qingyu.statistics.SemesterStats
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Favorites
import top.yukonga.miuix.kmp.icon.extended.Location
import top.yukonga.miuix.kmp.icon.extended.Months
import top.yukonga.miuix.kmp.icon.extended.Notes
import top.yukonga.miuix.kmp.icon.extended.Ok
import top.yukonga.miuix.kmp.icon.extended.Recent
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 学期总览：单行四指标（门课程 / 节课 / 周 / 天连续），格间 1dp 竖线。
 *
 * 对应 Dart `lib/widgets/statistics/overview_section.dart`（108 行）。
 * 没有课程时整块不渲染（判据在 [OverviewModel.cells]）。
 */
@Composable
fun OverviewSection(
    stats: SemesterStats,
    dark: Boolean,
    modifier: Modifier = Modifier,
) {
    val cells = OverviewModel.cells(stats)
    if (cells.isEmpty()) return
    val dividerColor = Color(QingyuTheme.dividerLine(dark))

    QingyuCard(
        modifier = modifier.fillMaxWidth(),
        insideMargin = PaddingValues(horizontal = 8.dp, vertical = 16.dp),
    ) {
        Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            cells.forEachIndexed { index, cell ->
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
                        text = cell.value,
                        // Dart `metricLarge` = 24sp
                        style = MiuixTheme.textStyles.title2,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        textAlign = TextAlign.Center,
                        color = if (cell.highlight) {
                            Color(QingyuTheme.primary(dark = dark))
                        } else {
                            Color(QingyuTheme.primaryText(dark))
                        },
                    )
                    Spacer(Modifier.height(5.dp))
                    Text(
                        text = cell.label,
                        style = MiuixTheme.textStyles.footnote2,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        textAlign = TextAlign.Center,
                        color = if (cell.highlight) {
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
 * 数据故事列表：每条一行（图标徽章 + 标题 + 富文本正文）。
 *
 * 对应 Dart `lib/widgets/statistics/data_story_card.dart`（187 行）。
 * 正文里的 `**xx**` 由 [DataStoryModel.richSegments] 拆好，这里只按 flag 换字重
 * （加粗段用 SemiBold，与 Dart `w600` 同位）。
 */
@Composable
fun DataStoryList(
    stories: List<DataStory>,
    dark: Boolean,
    modifier: Modifier = Modifier,
) {
    val items = DataStoryModel.items(stories)
    if (items.isEmpty()) return

    QingyuCard(
        modifier = modifier.fillMaxWidth(),
        insideMargin = PaddingValues(0.dp),
    ) {
        Column {
            items.forEachIndexed { index, item ->
                if (index > 0) {
                    HorizontalDivider(
                        modifier = Modifier.padding(start = 52.dp),
                        thickness = 1.dp,
                        color = Color(QingyuTheme.dividerLine(dark)),
                    )
                }
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.Top,
                ) {
                    ChartIconBadge(
                        icon = storyIcon(item.tone),
                        accent = storyToneColor(item.tone, dark),
                    )
                    Spacer(Modifier.width(10.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = item.title,
                            style = MiuixTheme.textStyles.footnote2,
                            color = Color(QingyuTheme.secondaryText(dark)),
                        )
                        Spacer(Modifier.height(2.dp))
                        Text(
                            text = buildAnnotatedString {
                                for (segment in item.segments) {
                                    if (segment.bold) {
                                        pushStyle(SpanStyle().shiftWeight(QingyuWeightDelta.SEMIBOLD))
                                        append(segment.text)
                                        pop()
                                    } else {
                                        append(segment.text)
                                    }
                                }
                            },
                            style = MiuixTheme.textStyles.body1,
                            color = Color(QingyuTheme.primaryText(dark)),
                        )
                    }
                }
            }
        }
    }
}

/** 故事语义色（Dart `_storyAccent`）。 */
private fun storyToneColor(tone: StoryTone, dark: Boolean): Color = when (tone) {
    StoryTone.RED -> ChartPalette.Red
    StoryTone.TEAL -> ChartPalette.Teal
    StoryTone.BLUE -> ChartPalette.Blue
    StoryTone.PURPLE -> ChartPalette.Purple
    StoryTone.ORANGE -> ChartPalette.Orange
}

/**
 * 故事图标：Dart 用的是 Material 的时间/教室/楼层图标，miuix 0.9.4 没有同一套；
 * 这里按语义挑已有的（时间→Recent、教室→Location、跨楼→Months、最忙→Notes、最轻松→Ok），
 * 只求方向一致、不误导。
 */
private fun storyIcon(tone: StoryTone): androidx.compose.ui.graphics.vector.ImageVector = when (tone) {
    StoryTone.RED -> MiuixIcons.Notes
    StoryTone.TEAL -> MiuixIcons.Ok
    StoryTone.BLUE -> MiuixIcons.Location
    StoryTone.PURPLE -> MiuixIcons.Months
    StoryTone.ORANGE -> MiuixIcons.Recent
}

/**
 * 成就徽章网格：每行 4 枚，一枚 = 36dp 圆角勋章 + 名称 + 进度小字。
 *
 * 对应 Dart `lib/widgets/statistics/achievement_badge.dart`（454 行）的 `AchievementBadge`。
 *
 * ## 与 Dart 的两处差异（都写清楚，别当漏迁）
 *
 * 1. **不搬进场动画**（`AnimationController` + `ScaleTransition/FadeTransition`，
 *    每个徽章一个 controller，带 Ticker）。动画属交互层批次，且不影响
 *    「锁没锁、进度多少」这两个真判据。
 * 2. **不内建详情弹窗**：Dart 的 `showAchievementDetailSheet` 依赖 HyperosSheet。
 *    这里改为点击回调 [onAchievementClick]，并把详情内容做成独立可复用组件
 *    [AchievementDetailContent]，交给页面用自己已有的 sheet 承载——
 *    渲染层不擅自决定弹窗形态。
 */
@Composable
fun AchievementBadgeGrid(
    achievements: List<Achievement>,
    dark: Boolean,
    modifier: Modifier = Modifier,
    onAchievementClick: ((Achievement) -> Unit)? = null,
    perRow: Int = 4,
) {
    if (achievements.isEmpty()) return
    val models = achievements.map { AchievementModel.badge(it) }
    val columns = perRow.coerceAtLeast(1)

    QingyuCard(
        modifier = modifier.fillMaxWidth(),
        insideMargin = PaddingValues(16.dp),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
            // 带上原始下标再切行：不能用 indexOf(model) 反查，
            // 两枚徽章的模型完全相同时会取到错的那个 id（点开详情就串了）。
            models.withIndex().chunked(columns).forEach { rowPairs ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    rowPairs.forEach { (sourceIndex, model) ->
                        AchievementMedal(
                            model = model,
                            dark = dark,
                            modifier = Modifier.weight(1f),
                            onClick = onAchievementClick?.let { callback ->
                                { callback(achievements[sourceIndex]) }
                            },
                        )
                    }
                    // 补空位，保证最后一行的徽章不被拉宽
                    repeat(columns - rowPairs.size) {
                        Spacer(Modifier.weight(1f))
                    }
                }
            }
        }
    }
}

@Composable
private fun AchievementMedal(
    model: AchievementBadgeModel,
    dark: Boolean,
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)?,
) {
    val accent = achievementAccentColor(model.accent, dark)
    val fill = if (model.unlocked) {
        accent
    } else {
        accent.copy(
            alpha = if (dark) AchievementModel.LOCKED_FILL_DARK else AchievementModel.LOCKED_FILL_LIGHT,
        )
    }
    val border = accent.copy(
        alpha = if (dark) AchievementModel.LOCKED_BORDER_DARK else AchievementModel.LOCKED_BORDER_LIGHT,
    )
    val iconTint = if (model.unlocked) {
        Color(QingyuTheme.onAccent(dark))
    } else {
        accent.copy(
            alpha = if (dark) AchievementModel.LOCKED_ICON_DARK else AchievementModel.LOCKED_ICON_LIGHT,
        )
    }

    Column(
        modifier = modifier
            .then(if (onClick != null) Modifier.clickable { onClick() } else Modifier)
            .padding(vertical = 2.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(contentAlignment = Alignment.Center) {
            Box(
                modifier = Modifier
                    .size(AchievementModel.MEDAL_SIZE_DP.dp)
                    .clip(RoundedCornerShape(AchievementModel.MEDAL_RADIUS_DP.dp))
                    .background(fill)
                    .then(
                        if (model.unlocked) {
                            Modifier
                        } else {
                            Modifier.border(
                                width = 0.5.dp,
                                color = border,
                                shape = RoundedCornerShape(AchievementModel.MEDAL_RADIUS_DP.dp),
                            )
                        },
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = MiuixIcons.Favorites,
                    contentDescription = null,
                    tint = iconTint,
                    modifier = Modifier.size(20.dp),
                )
            }
            // 锁定角标：右下角 16dp 圆点（Dart `Positioned(right:-3, bottom:-3)`）。
            // 当前 miuix-icons 没有锁图标，用「卡片底 + 描边 + 中央小圆点」表达锁定，
            // 不拿语义无关的图标硬凑（链环、星形都会被读成别的意思）。
            if (!model.unlocked) {
                Box(
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .offset(x = 3.dp, y = 3.dp)
                        .size(16.dp)
                        .clip(CircleShape)
                        .background(Color(QingyuTheme.card(dark)))
                        .border(1.dp, Color(QingyuTheme.dividerLine(dark)), CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    Box(
                        modifier = Modifier
                            .size(6.dp)
                            .clip(CircleShape)
                            .background(Color(QingyuTheme.secondaryText(dark))),
                    )
                }
            }
        }
        Spacer(Modifier.height(6.dp))
        Text(
            text = model.name,
            style = MiuixTheme.textStyles.footnote2,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.Center,
            color = if (model.unlocked) {
                Color(QingyuTheme.primaryText(dark))
            } else {
                Color(QingyuTheme.secondaryText(dark))
            },
        )
        val progress = model.progressLabel
        if (progress != null) {
            Spacer(Modifier.height(2.dp))
            Text(
                text = progress,
                style = MiuixTheme.textStyles.footnote2,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.Center,
                color = if (model.unlocked) {
                    accent
                } else {
                    Color(QingyuTheme.secondaryText(dark)).copy(alpha = 0.8f)
                },
            )
        }
    }
}

/**
 * 成就详情内容（可放进任意 sheet / 对话框）：
 * 名称 + 一句话描述 + 解锁条件 + 进度条。
 *
 * 拆成独立组件而不是内建 sheet，见 [AchievementBadgeGrid] 的差异说明 2。
 */
@Composable
fun AchievementDetailContent(
    achievement: Achievement,
    dark: Boolean,
    modifier: Modifier = Modifier,
) {
    val model = AchievementModel.badge(achievement)
    val accent = achievementAccentColor(model.accent, dark)

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            modifier = Modifier
                .size(56.dp)
                .clip(RoundedCornerShape(18.dp))
                .background(
                    if (model.unlocked) {
                        accent
                    } else {
                        accent.copy(
                            alpha = if (dark) {
                                AchievementModel.LOCKED_FILL_DARK
                            } else {
                                AchievementModel.LOCKED_FILL_LIGHT
                            },
                        )
                    },
                ),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = MiuixIcons.Favorites,
                contentDescription = null,
                tint = if (model.unlocked) Color(QingyuTheme.onAccent(dark)) else accent,
                modifier = Modifier.size(28.dp),
            )
        }
        Spacer(Modifier.height(10.dp))
        Text(
            text = model.name,
            style = MiuixTheme.textStyles.title4,
            color = Color(QingyuTheme.primaryText(dark)),
        )
        if (model.description.isNotEmpty()) {
            Spacer(Modifier.height(4.dp))
            Text(
                text = model.description,
                style = MiuixTheme.textStyles.footnote2,
                textAlign = TextAlign.Center,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
        if (model.detail.isNotEmpty()) {
            Spacer(Modifier.height(12.dp))
            Text(
                text = model.detail,
                style = MiuixTheme.textStyles.footnote1,
                textAlign = TextAlign.Center,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
        Spacer(Modifier.height(14.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = if (model.unlocked) {
                    ChartsStrings.statisticsAchievementDone.zh
                } else {
                    ChartsStrings.statisticsAchievementLocked.zh
                },
                style = MiuixTheme.textStyles.footnote2,
                color = if (model.unlocked) accent else Color(QingyuTheme.secondaryText(dark)),
            )
            val progress = model.progressLabel
            if (progress != null) {
                Text(
                    text = progress,
                    style = MiuixTheme.textStyles.footnote2,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
            }
        }
        Spacer(Modifier.height(8.dp))
        ChartProgressBar(
            fraction = if (model.unlocked) 1.0 else model.progressFraction,
            color = accent,
            dark = dark,
        )
    }
}

/** 成就语义色 → 实际颜色。 */
private fun achievementAccentColor(accent: AchievementAccent, dark: Boolean): Color = when (accent) {
    AchievementAccent.ORANGE -> ChartPalette.Orange
    AchievementAccent.GREEN -> ChartPalette.Green
    AchievementAccent.PURPLE -> ChartPalette.Purple
    AchievementAccent.YELLOW -> ChartPalette.Yellow
    AchievementAccent.BLUE -> ChartPalette.Blue
    AchievementAccent.TEAL -> ChartPalette.Teal
    AchievementAccent.INDIGO -> ChartPalette.Indigo
    AchievementAccent.CYAN -> ChartPalette.Cyan
    AchievementAccent.RED -> ChartPalette.Red
}
