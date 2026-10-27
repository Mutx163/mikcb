package com.mutx163.qingyu.pages.timetable.month

import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 月视图上半的**日历卡**：卡顶导航行 + 星期表头 / 日期格 + 卡底拉杆。
 *
 * 移植自 `lib/widgets/timetable/month_view/month_calendar_card.dart`（2026-10-27 快照）。
 *
 * ## 月份导航进卡（本轮的核心决定）
 *
 * 用户口径是「顶部的 2026年10月、左右按钮、回今日区域，能不能和下面的日期做一下
 * 整体化」。改造前竖向上并存四种左沿、两种容器（满宽玻璃带 + 浮卡），而导航控制
 * 的正是下面那张卡，读起来像「上面的仪表盘在遥控下面的表格」。
 *
 * 现在卡片内部自上而下是一套：
 *
 * ```text
 * ┌────────────────────────────┐
 * │ ‹      2026年 10月    ›  今天 │  ← 卡内导航行（40）
 * │ 周一  周二  周三 ...          │  ← 星期表头（24）
 * │  28   29   30   1   2 ...    │  ← 4~6 行日期格
 * │            ▬                │  ← 卡底拉杆（26）
 * └────────────────────────────┘
 * ```
 *
 * ## 高度账必须算清（Dart 踩过一次）
 *
 * 卡片总高 = 导航 + 分隔线 + 表格内容 + 拉杆。**算漏任何一段都会溢出**
 *（Dart 2026-10-23 实测：导航搬进卡后只扣了拉杆 → 溢出 41px，正好 40 + 1）。
 * 所以卡内「不属于表格」的高度收成一个常量 [MonthCalendarChrome.CARD_CHROME]，
 * 页面用 `表格高 + CARD_CHROME` 定卡高；面板的布局预算引用同一个常量。
 * **不要在调用方自己拼 40 + 1 + 26。**
 *
 * ## 投影
 *
 * Dart 版给白卡一层 `black @ 6%`、blur 16、offset (0,4) 的柔和投影（白卡压在
 * 彩色壁纸上，没有投影时边界只能靠色差读）。Miuix 的 `Card` 没有投影参数，
 * 这里用 [Modifier.shadow] 补同一档，颜色仍取 [MonthMetrics.CARD_SHADOW_ALPHA]。
 */
@Composable
fun MonthCalendarCard(
    modifier: Modifier = Modifier,
    /** 卡顶导航行（[MonthViewToolbar]）。null = 不画导航行，卡片高度自动少 [MonthCalendarChrome.NAV_HEIGHT]。 */
    navigator: (@Composable () -> Unit)? = null,
    /** 导航行与表格之间的上边距（页面传同一笔账算进高度预算）。 */
    contentTopPadding: Dp = MonthMetrics.CARD_PADDING.dp,
    /** 拉杆颜色：默认按卡面墨色的 hairline 档（与 Dart 一致）。 */
    handleBarColor: Color? = null,
    onDragStart: () -> Unit = {},
    onDragUpdate: (dy: Float) -> Unit = {},
    onDragEnd: (velocityDy: Float) -> Unit = {},
    content: @Composable ColumnScope.() -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val ink = Color(QingyuTheme.primaryText(dark))
    val radius = MonthMetrics.CALENDAR_CARD_RADIUS.dp
    val shape = RoundedCornerShape(radius)
    val shadowColor = Color.Black.copy(alpha = MonthMetrics.CARD_SHADOW_ALPHA.toFloat())

    QingyuCard(
        modifier = modifier
            .fillMaxWidth()
            .shadow(
                elevation = 8.dp,
                shape = shape,
                clip = false,
                ambientColor = shadowColor,
                spotColor = shadowColor,
            ),
        cornerRadius = radius,
        insideMargin = PaddingValues(0.dp),
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            // ── 卡顶导航行：与下面的日历同属一张卡 ──
            if (navigator != null) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(MonthCalendarChrome.NAV_HEIGHT.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    navigator()
                }
                // 导航与表格之间一条极淡的分隔：告诉眼睛「导航在上、表格在下」，
                // 但不切出一块独立区域（用 6% 而不是分割线样式）。
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(MonthCalendarChrome.DIVIDER_HEIGHT.dp)
                        .background(ink.copy(alpha = MonthInk.FILL.toFloat())),
                )
            }

            // ── 表格内容 ──
            // 卡内左右内边距 = gridInnerPadding − cellGap：表头/日期格不能贴到卡片
            // 圆角边缘（Dart 第一版漏了这段，表头直接顶着圆角，读成「内容溢出的
            // 图片被裁了一刀」）。
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(
                        start = (MonthMetrics.GRID_INNER_PADDING - MonthMetrics.CELL_GAP).dp,
                        end = (MonthMetrics.GRID_INNER_PADDING - MonthMetrics.CELL_GAP).dp,
                        top = contentTopPadding,
                    ),
            ) {
                Column(modifier = Modifier.fillMaxWidth()) {
                    content()
                }
            }

            // ── 卡底拉杆：视觉只是 5dp 细条，命中区由 MonthGridHandle 自己撑到 24dp ──
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(MonthCalendarChrome.HANDLE_AREA_HEIGHT.dp),
                contentAlignment = Alignment.Center,
            ) {
                MonthGridHandle(
                    barColor = handleBarColor ?: ink.copy(alpha = MonthInk.HAIRLINE.toFloat()),
                    onDragStart = onDragStart,
                    onDragUpdate = onDragUpdate,
                    onDragEnd = onDragEnd,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }
}

/**
 * 日历卡**不属于表格**的高度账（导航 + 分隔线 + 卡底拉杆）。
 *
 * 两个地方必须引用同一个常量，否则必然溢出：
 * 1. 页面：`卡高 = 表格高 + CARD_CHROME`；
 * 2. 面板布局：`layout(handleHeightDp = CARD_CHROME)` 扣掉这块再算行高。
 */
object MonthCalendarChrome {

    /** 卡顶导航行高度（= 周/日视图星期栏，三个视图顶栏不分家）。 */
    const val NAV_HEIGHT = MonthMetrics.CALENDAR_NAV_HEIGHT

    /** 导航与表格之间的分隔线高度。 */
    const val DIVIDER_HEIGHT = 1.0

    /** 卡底拉杆区高度（视觉只有 5dp 细条，命中区不能是 5dp）。 */
    const val HANDLE_AREA_HEIGHT = MonthMetrics.CALENDAR_HANDLE_HEIGHT

    /** 卡片内部全部「非表格」高度 = 40 + 1 + 26 = 67。 */
    const val CARD_CHROME = NAV_HEIGHT + DIVIDER_HEIGHT + HANDLE_AREA_HEIGHT
}
