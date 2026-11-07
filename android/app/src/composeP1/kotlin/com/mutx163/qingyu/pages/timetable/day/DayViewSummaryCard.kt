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
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.pages.settings.HomeMaterialRenderSpec
import com.mutx163.qingyu.pages.shell.HomeBackgroundModel
import com.mutx163.qingyu.pages.timetable.CourseCardInk
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.CardDefaults
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.blur.Backdrop
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
    /** 材质快照（`SettingsMaterialModel.renderSpecOf`）。null = 老行为（主题实底卡）。 */
    material: HomeMaterialRenderSpec? = null,
    /** 液态档的整页共享背景采样源（见 [dayAgendaSurface]）。 */
    glassBackdrop: Backdrop? = null,
    /**
     * 卡背后壁纸的**星期栏那档**亮度（与摘要卡的星期栏字色同源）：玻璃压壁纸时用它按
     * 卡面有效亮度自动翻黑/白，避免灰字糊在灰玻璃上。null = 没壁纸 / 亮度未知 ⇒ 用主题前景。
     */
    wallpaperLuminance: Double? = null,
    /**
     * 用户自定义的**星期栏字色**（hex，`WeekViewStyle.weekdayFontColorLight/Dark` 同一对键）：
     * 摘要卡墨色本来就与星期栏同一套配色；非空且非默认时优先用它（对比不足再按亮度推）。
     * null = 没接 / 未配置 ⇒ 维持「按明暗自动翻黑/白」。
     */
    weekdayFontColorHex: String? = null,
    /** 该主题档下「星期栏字色」的**内置默认值**（hex）：等于它时视作「没改过」⇒ 按亮度翻黑/白。 */
    weekdayFontColorDefaultHex: String? = null,
    modifier: Modifier = Modifier,
) {
    val dark = isSystemInDarkTheme()

    // ── 摘要卡与下面的议程卡**同材质**（2026-11-01）──
    // Dart `day_view_summary_card.dart:126-133` 记着用户口径：「日视图顶部的日期卡片……
    // 也要跟日视图的课程卡片是一样的材质，选什么就是什么，不要第二种」。
    // 所以这里不另判一档，直接走议程卡那套（[dayAgendaSurfaceAlpha] + [dayAgendaSurface]）。
    val shape = RoundedCornerShape(QingyuCardDefaults.Corner)
    val glass = dayAgendaGlassBackdrop(material, glassBackdrop)
    val fillAlpha = dayAgendaSurfaceAlpha(material, 1f).coerceIn(0.08f, 1f)
    val translucent = glass != null || fillAlpha < 1f

    // ── 摘要卡文字墨色（2026-11-07 按卡面有效亮度重算）──
    // 卡面半透明（玻璃 / 高斯 / 染色 < 1）时：按**卡面有效亮度**
    //（卡底色亮度 × α + 壁纸亮度 × (1−α)，见 `CourseCardInk.compositeLuminanceOverWallpaper`）
    // 在黑 / 白里挑对比度更高的一档 —— 与四张议程卡同一份实现。
    // 旧实现有两处门槛会漏判：①要求 `glass != null`（只认液态档），高斯档 alpha 已经 0.55
    // 却仍用主题前景色；②翻面用写死的 0.20 阈值，分界点附近白给了 ~4% 亮度差。
    // 非半透明档（实色）：按卡底色自身亮度择优（`fallbackArgb`），次级行用其派生 muted。
    // 卡面底色：画法与判墨**共用这一份**，避免一处改了另一处漏（`DayViewTaskBandCard` 同）。
    val cardFill = MiuixTheme.colorScheme.surface
    val inkArgb = if (translucent && wallpaperLuminance != null) {
        CourseCardInk.resolveCardInkOverWallpaper(
            fillArgb = cardFill.toArgb(),
            fillAlpha = fillAlpha,
            wallpaperLuminance = wallpaperLuminance,
            showsWallpaper = true,
            fallbackArgb = QingyuTheme.primaryText(dark),
            // 与星期栏同一套自定义字色：配置了（且不是内置默认值）就优先用它，
            // 只有它在卡面有效亮度上达不到 3:1 时才回自动黑 / 白（与
            // `HomeBackgroundModel.MIN_INK_CONTRAST_RATIO` 同一条达标线）。
            preferredArgb = HomeBackgroundModel.parseInkArgb(weekdayFontColorHex)
                ?.takeIf { it != HomeBackgroundModel.parseInkArgb(weekdayFontColorDefaultHex) },
        )
    } else {
        QingyuTheme.primaryText(dark)
    }
    val summaryInk = Color(inkArgb)
    val summaryMutedInk = Color(HomeBackgroundModel.mutedInkOverWallpaperArgb(inkArgb))

    QingyuCard(
        modifier = modifier
            .fillMaxWidth()
            .then(
                if (translucent) {
                    Modifier.dayAgendaSurface(
                        glassBackdrop = glass,
                        shape = shape,
                        fill = cardFill.copy(alpha = fillAlpha),
                        material = material,
                    )
                } else {
                    Modifier
                },
            ),
        // 卡面自己画（上面那条 modifier），卡片本体的底色让开；不透明档保持官方默认配色。
        colors = if (translucent) {
            CardDefaults.defaultColors(color = Color.Transparent)
        } else {
            CardDefaults.defaultColors()
        },
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
                            color = summaryMutedInk,
                        )
                        Text(
                            text = " · ",
                            style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.MEDIUM),
                            color = summaryMutedInk,
                        )
                    }
                    Text(
                        text = DayViewStrings.weekLabel(state.week),
                        style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.MEDIUM),
                        color = summaryMutedInk,
                    )
                }

                IconButton(
                    onClick = onClose,
                    modifier = Modifier.size(28.dp),
                ) {
                    Icon(
                        imageVector = MiuixIcons.Close,
                        contentDescription = DayViewStrings.backToWeekViewAction.zh,
                        tint = summaryInk,
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
                color = summaryInk,
            )

            Spacer(modifier = Modifier.height(10.dp))

            // ── 统计胶囊区（课程数 / 日程数 / 议程起止时间）──
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                // 主计数胶囊（"4 门课" 或 "日程 2 项" 或 "作业 1 项" 或 "0 门课"）
                SummaryNeutralCapsule(text = state.countLabel, ink = summaryInk, mutedInk = summaryMutedInk)

                // 辅日程计数胶囊（既有课又有日程时展示）
                if (!state.scheduleLabel.isNullOrBlank()) {
                    SummaryNeutralCapsule(text = state.scheduleLabel, ink = summaryInk, mutedInk = summaryMutedInk)
                }

                // 议程时间区间（如 "08:00 开始 · 20:30 结束"）
                if (!state.agendaRangeLabel.isNullOrBlank()) {
                    Text(
                        text = state.agendaRangeLabel,
                        style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.MEDIUM),
                        color = summaryMutedInk,
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
                        SummaryStatusCapsule(chip = chip, dark = dark, mutedInk = summaryMutedInk)
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
    ink: Color,
    mutedInk: Color,
) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(7.dp))
            .background(ink.copy(alpha = 0.10f))
            .padding(horizontal = 8.dp, vertical = 3.dp),
    ) {
        Text(
            text = text,
            style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
            color = mutedInk,
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
    mutedInk: Color,
) {
    val accentColor = when (chip.kind) {
        SummaryChipKind.ONGOING_COURSE -> Color(QingyuTheme.primary(null, dark))
        SummaryChipKind.CONFLICT -> Color(QingyuTheme.error(dark))
        SummaryChipKind.NON_CURRENT_WEEK -> mutedInk
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
