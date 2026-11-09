package com.mutx163.qingyu.pages.timetable.day

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.pages.shell.HomeBackgroundModel
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 日视图「今日无课」极简空态卡片 · Compose 渲染层。
 *
 * 对应 Flutter `lib/widgets/timetable/day_view/day_view_empty_state.dart`：
 * - 居中两行展示：主标题「暂无课程」+ 副标题「第 N 周 · 周几」；
 * - 纯净排版，适配深色与浅色主题，契合 Miuix 极简视觉规范。
 */
@Composable
fun DayViewEmptyState(
    week: Int,
    dayOfWeek: Int? = null,
    /**
     * 空态背后壁纸的平均亮度（Dart `homePageOverWallpaperInk` 的输入，
     * `home_page_background.dart:763-799`）。**null = 没壁纸 / 亮度未知 ⇒ 主题原色**。
     * 深壁纸上的「暂无课程」以前是深色主题字 ⇒ 黑字压黑底看不见（2026-11-01 用户报）。
     */
    wallpaperLuminance: Double? = null,
    /**
     * 没壁纸时文字实际压着的**页底**亮度（自定义页底色优先，缺省主题页底）。
     *
     * 低了这一步就会出现「壁纸/页底是黑的、字也是黑的」：空态只认 [wallpaperLuminance]，
     * 没壁纸时它恒为 null，于是退回主题墨色（亮色主题 `#333`），压在纯黑页底上直接看不见。
     * 四张议程卡从 2026-11-07 起就认这个值，空态一直没接（2026-11-09 用户实报）。
     *
     * 有壁纸但亮度还没量到时这个值由页面**门控成 null**（见 `dayAgendaPageFallbackLuminance`），
     * 不会把页底当成壁纸来判墨。
     */
    pageBackgroundLuminance: Double? = null,
    /**
     * 用户自定义的**星期栏字色**（hex，`WeekViewStyle.weekdayFontColorLight/Dark`）。
     *
     * 空态与星期栏 / 摘要卡用同一组设置（Dart `day_view_empty_state.dart:44-52` 传的就是
     * `settings.weekdayBarFontColorLight/Dark`）。2026-11-09 之前这里写死 `configuredArgb = null`，
     * 于是这组「亮暗两档字色」在空态上完全不生效：改设置、切黑白主题，空态一个字都不变。
     */
    configuredArgbHex: String? = null,
    /**
     * 上面那组设置的**内置默认值**（hex）：等于它时视作「没改过」⇒ 按壁纸亮度翻黑 / 白。
     * null = 没有默认值可比 ⇒ 自定义色永远优先（不走进自动翻面）。
     */
    defaultInkHex: String? = null,
    modifier: Modifier = Modifier,
) {
    val dark = isSystemInDarkTheme()
    // 判墨的底：壁纸优先（真压在照片上），没壁纸用页底（自定义深/浅页底色也能翻对）。
    val backdropLuminance = wallpaperLuminance ?: pageBackgroundLuminance
    val titleArgb = HomeBackgroundModel.inkOverWallpaperArgb(
        configuredArgb = HomeBackgroundModel.parseInkArgb(configuredArgbHex),
        fallbackArgb = QingyuTheme.primaryText(dark),
        wallpaperLuminance = backdropLuminance,
        builtInDefaultArgb = HomeBackgroundModel.parseInkArgb(defaultInkHex),
    )
    val titleColor = Color(titleArgb)
    // 副标题是标题墨压淡一档（Dart `day_view_empty_state.dart:53` 无条件
    // `homePageOverWallpaperMutedInk(titleColor)`）：两行永远同一套冷暖，
    // 自定义字色 / 壁纸翻面时不会出现「主句白了、副句还留着主题灰」。
    val subtitleColor = Color(HomeBackgroundModel.mutedInkOverWallpaperArgb(titleArgb))

    // Dart `day_view_empty_state.dart:64-66`：副标题只有「第 N 周」一条。
    // 2026-10-31 审核：这里曾拼成「第 N 周 · 周X」，而上一行的摘要卡已经写着日期与星期，
    // 屏上等于同一句念两遍；`dayOfWeek` 参数保留只为调用方签名稳定。
    val subtitle = DayViewStrings.weekLabel(week)

    Box(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 32.dp, vertical = 48.dp),
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = DayViewStrings.dayViewEmptyTitle.text,
                style = MiuixTheme.textStyles.main.shiftWeight(QingyuWeightDelta.MEDIUM),
                color = titleColor,
                textAlign = TextAlign.Center,
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = subtitle,
                style = MiuixTheme.textStyles.footnote1,
                color = subtitleColor,
                textAlign = TextAlign.Center,
            )
        }
    }
}
