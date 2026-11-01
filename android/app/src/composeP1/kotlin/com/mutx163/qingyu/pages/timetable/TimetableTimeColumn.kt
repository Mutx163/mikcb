package com.mutx163.qingyu.pages.timetable

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.pages.shell.HomeBackgroundModel
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 时间列的几何与字阶刻度（逐条对齐 Dart `timetable_section_time_cell.dart`）。
 *
 * **字阶的已知例外**：这里不跟 `MiuixTheme.textStyles` 走，因为字号**来自设置**
 * （`compactFontSize`，Dart `:43` / `:55` 两处 clamp），不是固定字阶：
 * - 节次号 = `compactFontSize.clamp(8, 11)`；
 * - 起止时间 = `(compactFontSize - 2).clamp(6, 10)`，行高 1.05（Dart `:42-46`）。
 * 走字阶（footnote2 = 11sp）会让 12 节 + 起止时间两行在 34dp 宽的时间列里纵向溢出。
 */
object TimeColumnMetrics {
    /** 节次号字号下限 / 上限（Dart `:55` `compactFontSize.clamp(8.0, 11.0)`）。 */
    const val NUMBER_FONT_MIN_SP = 8f
    const val NUMBER_FONT_MAX_SP = 11f

    /** 起止时间字号下限 / 上限（Dart `:43` `(compactFontSize - 2).clamp(6.0, 10.0)`）。 */
    const val TIME_FONT_MIN_SP = 6f
    const val TIME_FONT_MAX_SP = 10f

    /** 起止时间比节次号小多少（Dart `:43` 的 `- 2`）。 */
    const val TIME_FONT_SHRINK_SP = 2f

    /** 起止时间的行高倍率（Dart `:45` `height: 1.05`，紧凑到不撑高节次格）。 */
    const val TIME_LINE_HEIGHT_RATIO = 1.05f

    /** 次要墨色透明度：浅墨 0.72 / 深墨 0.70（Dart `homePageOverWallpaperMutedInk`）。 */
    const val MUTED_INK_LIGHT_ALPHA = 0.72f
    const val MUTED_INK_DARK_ALPHA = 0.70f

    /** 节次号字号（Dart `:55`）。 */
    fun numberFontSize(compactFontSize: Float): Float =
        compactFontSize.coerceIn(NUMBER_FONT_MIN_SP, NUMBER_FONT_MAX_SP)

    /** 起止时间字号（Dart `:43`）。 */
    fun timeFontSize(compactFontSize: Float): Float =
        (compactFontSize - TIME_FONT_SHRINK_SP).coerceIn(TIME_FONT_MIN_SP, TIME_FONT_MAX_SP)

    /**
     * 「时间列显示」三档是否画开始时间（Dart `:60-62`：
     * `mode != hidden` 才画 `section.startTime`）。
     */
    fun showsStartTime(mode: WeekSectionTimeMode): Boolean =
        when (mode) {
            WeekSectionTimeMode.HIDDEN -> false
            WeekSectionTimeMode.START_ONLY -> true
            WeekSectionTimeMode.START_AND_END -> true
        }

    /**
     * 是否画结束时间（Dart `:63-65`：只有 `startAndEnd` 才画 `section.endTime`）。
     */
    fun showsEndTime(mode: WeekSectionTimeMode): Boolean =
        when (mode) {
            WeekSectionTimeMode.HIDDEN -> false
            WeekSectionTimeMode.START_ONLY -> false
            WeekSectionTimeMode.START_AND_END -> true
        }
}

/**
 * 课表左侧时间列（对应 Flutter `lib/widgets/timetable/timetable_section_time_cell.dart`）。
 *
 * ## 这一版按 Dart 逐条复刻（2026-10-29 重做）
 *
 * 旧版的三处「看着像」，逐条对上 Dart 后修掉：
 * 1. **不读「时间列显示」三档设置**：旧版固定画「开始 + 结束」，Dart 严格按
 *    `SectionTimeDisplayMode` 分三档（`:60-65`）；现在由 [WeekViewStyle.sectionTimeMode] 决定。
 * 2. **字号写死**：旧版用 `footnote1` / `footnote2` 字阶，Dart 用设置里的
 *    `compactFontSize` 并按上下限 clamp（`:43` / `:55`）。
 * 3. **不读时间轴字色**：旧版用 `QingyuTheme.secondaryText`，Dart 读
 *    `timeAxisFontColorLight/Dark`（`:30-40`）；现在读 [WeekViewStyle.timeAxisColorLight] /
 *    [WeekViewStyle.timeAxisColorDark]。
 *
 * 另外**删掉了「当前节次高亮」**：Dart 的时间列没有这个概念（节次号没有高亮分支），
 * 旧版给当前节次换强调色 + 加粗是自造的。节次号一律 `bold` + 时间轴主墨色。
 *
 * ## 与任务书的唯一一处口径分歧（已按 Dart 落地）
 *
 * 任务书里写「结束时间/次要行用同色 85% alpha」。Dart 实际用的是
 * `homePageOverWallpaperMutedInk`（`lib/utils/home_page_background.dart:999-1010`）：
 * **浅墨 0.72 / 深墨 0.70**，按墨色亮度选档，不是 0.85。这里按 Dart 落地；
 * 若要改成 0.85，只改 [TimeColumnMetrics.MUTED_INK_LIGHT_ALPHA] /
 * [TimeColumnMetrics.MUTED_INK_DARK_ALPHA] 两个常量即可。
 *
 * @param sectionCount 节次总数（页面按节高排，与网格同口径）。
 * @param sectionTimes 每节的起止时间，缺项时只画节次号。
 * @param sectionHeight 每节渲染高度，必须与右侧网格完全一致。
 * @param timeColumnWidth 时间列宽（设置里的「窄/宽」两档由页面换算后传入）。
 * @param style 周视图渲染风格（读时间列显示档与时间轴字色）。
 * @param wallpaperLuminance 时间列背后壁纸的平均亮度（Dart `homePageOverWallpaperInk`，
 *   `home_page_background.dart:763-799`）。**null = 没壁纸 / 亮度未知 ⇒ 用设置/主题原色**。
 *   非 null 时：用户挑的字色对比度够就保留，不够就保色相推到够；主题默认色直接翻黑/白。
 *   深壁纸上的时间列以前沿用深色主题字 ⇒ 黑字压黑底看不见（2026-11-01 用户报）。
 */
@Composable
fun TimetableTimeColumn(
    sectionCount: Int = 12,
    sectionTimes: List<SectionTime> = emptyList(),
    sectionHeight: Dp = 64.dp,
    timeColumnWidth: Dp = 34.dp,
    style: WeekViewStyle = WeekViewStyle(),
    wallpaperLuminance: Double? = null,
    modifier: Modifier = Modifier,
) {
    val dark = isSystemInDarkTheme()
    // 墨色来源：用户设置的时间轴字色（Dart `:30-40` 读的两个 hex 键）。
    // 解析失败时回落主题语义槽（Dart 的 `themeFallback`），不写死任何色值。
    // 压在壁纸上时再经 [HomeBackgroundModel.inkOverWallpaperArgb] 做对比度适配。
    val timeAxisInk = Color(
        HomeBackgroundModel.inkOverWallpaperArgb(
            configuredArgb = HomeBackgroundModel.parseHexArgb(
                if (dark) style.timeAxisColorDark else style.timeAxisColorLight,
            ),
            fallbackArgb = MiuixTheme.colorScheme.onSurface.toArgb(),
            wallpaperLuminance = wallpaperLuminance,
        ),
    )
    val mutedInk = timeAxisInk.secondaryInk()

    val showStart = TimeColumnMetrics.showsStartTime(style.sectionTimeMode)
    val showEnd = TimeColumnMetrics.showsEndTime(style.sectionTimeMode)
    val numberFontSize = TimeColumnMetrics.numberFontSize(style.compactFontSize)
    val timeFontSize = TimeColumnMetrics.timeFontSize(style.compactFontSize)
    // Dart `:45` 的 `height: 1.05`：行高跟着字号走，别让两行把节次格撑高。
    val timeLineHeight = timeFontSize * TimeColumnMetrics.TIME_LINE_HEIGHT_RATIO

    Column(
        modifier = modifier.width(timeColumnWidth),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        for (sectionIndex in 1..sectionCount) {
            val sectionTime = sectionTimes.getOrNull(sectionIndex - 1)
            val startTime = sectionTime?.startTime.orEmpty()
            val endTime = sectionTime?.endTime.orEmpty()

            Box(
                modifier = Modifier
                    .width(timeColumnWidth)
                    .height(sectionHeight),
                contentAlignment = Alignment.Center,
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    Text(
                        text = "$sectionIndex",
                        style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.BOLD),
                        fontSize = numberFontSize.sp,
                        color = timeAxisInk,
                        textAlign = TextAlign.Center,
                        maxLines = 1,
                    )
                    if (showStart && startTime.isNotBlank()) {
                        Text(
                            text = startTime,
                            style = MiuixTheme.textStyles.footnote2,
                            fontSize = timeFontSize.sp,
                            lineHeight = timeLineHeight.sp,
                            color = mutedInk,
                            textAlign = TextAlign.Center,
                            maxLines = 1,
                        )
                    }
                    if (showEnd && endTime.isNotBlank()) {
                        Text(
                            text = endTime,
                            style = MiuixTheme.textStyles.footnote2,
                            fontSize = timeFontSize.sp,
                            lineHeight = timeLineHeight.sp,
                            color = mutedInk,
                            textAlign = TextAlign.Center,
                            maxLines = 1,
                        )
                    }
                }
            }
        }
    }
}

/**
 * 由主墨色派生的次要墨色（Dart `homePageOverWallpaperMutedInk`，`home_page_background.dart:999-1010`）。
 *
 * 与星期栏同一口径：浅墨（亮度 > 0.55）压到 0.72、深墨压到 0.70。
 * 与 `TimetableWeekdayHeader.kt` 里的同义函数各留一份，是因为两边都是 file-private
 * 且不想把一条纯配色规则塞进共享文件（那条泳道正在改 `CourseGridCard.kt`）。
 */
private fun Color.secondaryInk(): Color =
    copy(
        alpha = if (luminance() > 0.55f) {
            TimeColumnMetrics.MUTED_INK_LIGHT_ALPHA
        } else {
            TimeColumnMetrics.MUTED_INK_DARK_ALPHA
        },
    )
