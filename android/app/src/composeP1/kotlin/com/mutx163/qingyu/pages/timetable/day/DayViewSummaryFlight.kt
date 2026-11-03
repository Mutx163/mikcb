package com.mutx163.qingyu.pages.timetable.day

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.BiasAlignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.pages.settings.HomeMaterialRenderSpec
import com.mutx163.qingyu.pages.timetable.HomeViewFlightRect
import com.mutx163.qingyu.pages.timetable.HomeViewSummaryFlightLine
import com.mutx163.qingyu.pages.timetable.homeViewSummaryCloseAlpha
import com.mutx163.qingyu.pages.timetable.homeViewSummaryDateLine
import com.mutx163.qingyu.pages.timetable.homeViewSummaryFlightCornerDp
import com.mutx163.qingyu.pages.timetable.homeViewSummaryFlightRect
import com.mutx163.qingyu.pages.timetable.homeViewSummaryMetaAlpha
import com.mutx163.qingyu.pages.timetable.homeViewSummarySurfaceAlpha
import com.mutx163.qingyu.pages.timetable.homeViewSummaryWeekdayLine
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.blur.Backdrop
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Close
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 飞行层（可见性门控 + 单颗飞行卡）。
 *
 * 只有这个 Composable 读 [progress]，所以动画期间被重组的作用域**只到这里**；
 * 它上面（周网格 / 日视图 / 星期栏）一帧都不重组。
 *
 * [visible] 是 `dayVisible`（布尔，只在进度跨过 0 时翻一次）；进度 ≥ 0.999 时
 * 本层让位给**真摘要卡**（页面的 draw 守卫在同一个阈值把真卡放出来）。
 */
@Composable
fun DayViewSummaryFlightLayer(
    progress: () -> Float,
    visible: Boolean,
    startCell: HomeViewFlightRect,
    endCell: HomeViewFlightRect,
    weekdayLabel: String,
    cellDateLabel: String,
    titleLabel: String,
    metaLabel: String,
    dark: Boolean,
    material: HomeMaterialRenderSpec?,
    glassBackdrop: Backdrop?,
    modifier: Modifier = Modifier,
) {
    val progressValue = progress()
    if (!visible || progressValue >= 0.999f) return
    DayViewSummaryFlightCard(
        progress = progress,
        startCell = startCell,
        endCell = endCell,
        weekdayLabel = weekdayLabel,
        cellDateLabel = cellDateLabel,
        titleLabel = titleLabel,
        metaLabel = metaLabel,
        dark = dark,
        material = material,
        glassBackdrop = glassBackdrop,
        modifier = modifier,
    )
}

/**
 * 首页「周 → 日」展开时**飞行中的摘要卡**（2026-11-03，阶段 A）。
 *
 * 对齐 Flutter `SummaryFlightCard`（`lib/widgets/timetable/summary_card_flight.dart:480-642`）：
 * 这颗卡从星期栏里选中日那一格（约 50×40）飞到日视图顶部摘要卡的实测位置，
 * 一路长大、文案连续变化；卡片落点由调用方实测后传进来，本文件不写死任何比例。
 *
 * ## 为什么自己画，而不是塞一张缩小的真卡
 *
 * 真摘要卡的文字宽度依赖卡宽（胶囊换行、标题省略）。塞进 50dp 宽的格子会立刻
 * 触发溢出与截断，读起来是一团乱码。Flutter 的结论是同一条（同文件 `:461-465`），
 * 所以这里只画两端都有的那几样（星期名 / 日期标题 / 终点文案 / 关闭叉），
 * 位置、字号、对齐、透明度都按 [progress] 逐项插值。
 *
 * ## 玻璃铁律
 *
 * 卡面走 [dayAgendaSurface]（与真摘要卡**同一个出口**），**全程不进 `alpha`**；
 * `Modifier.alpha` 只包文字与图标（同文件 `:477-479`、`:507`/`:545`/`:574`/`:588`）。
 * 起点 `surfaceAlpha = 0` 时只是**不挂卡面修饰器**，不是把卡面调成半透明——
 * 半透明的玻璃卡会透出后面的星期栏，那不是「没有卡面」。
 */
@Composable
fun DayViewSummaryFlightCard(
    /** 展开进度读取器。**必须在本 Composable 的自身作用域里读**，别在外层算好传值。 */
    progress: () -> Float,
    startCell: HomeViewFlightRect,
    endCell: HomeViewFlightRect,
    weekdayLabel: String,
    cellDateLabel: String,
    titleLabel: String,
    metaLabel: String,
    dark: Boolean,
    material: HomeMaterialRenderSpec?,
    glassBackdrop: Backdrop?,
    modifier: Modifier = Modifier,
) {
    val progressValue = progress().coerceIn(0f, 1f)
    val rect = homeViewSummaryFlightRect(startCell, endCell, progressValue)
    val shape = RoundedCornerShape(homeViewSummaryFlightCornerDp(progressValue).dp)
    val surfaceAlpha = homeViewSummarySurfaceAlpha(progressValue)
    val ink = Color(QingyuTheme.primaryText(dark))
    val muted = Color(QingyuTheme.secondaryText(dark))
    // 与真摘要卡同一档：液态档 + 共享采样层才真采样，否则实底填充。
    val glass = dayAgendaGlassBackdrop(material, glassBackdrop)
    val fillAlpha = dayAgendaSurfaceAlpha(material, 1f).coerceIn(0.08f, 1f) * surfaceAlpha

    val density = LocalDensity.current
    Box(
        modifier = modifier
            .offset(
                x = with(density) { rect.left.toDp() },
                y = with(density) { rect.top.toDp() },
            )
            .requiredSize(
                width = with(density) { rect.width.toDp() },
                height = with(density) { rect.height.toDp() },
            ),
    ) {
        Box(
            modifier = Modifier
                .matchParentSize()
                .then(
                    if (surfaceAlpha > 0.001f) {
                        Modifier.dayAgendaSurface(
                            glassBackdrop = glass,
                            shape = shape,
                            fill = MiuixTheme.colorScheme.surface.copy(alpha = fillAlpha),
                        )
                    } else {
                        // 起点：星期栏那一格根本没有卡面，只有两行字。
                        Modifier
                    },
                )
                // 文字/图标超出卡面时按同一圆角裁掉（Flutter `ClipRRect` 同口径）。
                .clip(shape),
        ) {
            val weekdayLine = homeViewSummaryWeekdayLine(progressValue, weekdayLabel)
            if (weekdayLine.alpha > 0.001f) {
                FlightLine(
                    line = weekdayLine,
                    ink = ink,
                    style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.EXTRABOLD),
                )
            }

            // 终点标题里已经含「周五」，所以后段只留完整标题那一行。
            val dateLine = homeViewSummaryDateLine(progressValue, cellDateLabel, titleLabel)
            FlightLine(
                line = dateLine,
                ink = ink,
                style = MiuixTheme.textStyles.title3,
            )

            val metaAlpha = homeViewSummaryMetaAlpha(progressValue)
            if (metaAlpha > 0.001f) {
                Text(
                    text = metaLabel,
                    // 字号/字阶与真摘要卡逐字同源（`DayViewSummaryCard.kt:110`），不另写字号。
                    style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.MEDIUM),
                    maxLines = 1,
                    overflow = TextOverflow.Clip,
                    color = muted,
                    // 真卡第一行高 28dp（关闭按钮那一行）且文字居中 ⇒ 顶边 ≈ 14 + (28 - 行高)/2。
                    modifier = Modifier
                        .offset(x = 14.dp, y = 18.dp)
                        .alpha(metaAlpha),
                )
            }

            val closeAlpha = homeViewSummaryCloseAlpha(progressValue)
            if (closeAlpha > 0.001f) {
                Icon(
                    imageVector = MiuixIcons.Close,
                    contentDescription = null,
                    tint = muted,
                    // 真卡的叉是 16dp 图标居中在 28dp 按钮里、按钮贴 16dp 内边距 ⇒
                    // 图标左上 ≈ (16 + 6, 14 + 6)。按真卡位置摆，落定那一帧不跳。
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(end = 22.dp, top = 20.dp)
                        .size(16.dp)
                        .alpha(closeAlpha),
                )
            }
        }
    }
}

/**
 * 一行按进度插值的文字：顶边 / 字号 / 水平对齐 / 透明度都来自 [line]。
 *
 * 水平位置用「对齐因子」而不是算好的 left：文字真实宽度只有排版知道，
 * 用估算值在 50dp 的格子里会偏（Flutter 实测 `03/20` 在 8.5sp 下偏 10px）。
 */
@Composable
private fun FlightLine(
    line: HomeViewSummaryFlightLine,
    ink: Color,
    style: androidx.compose.ui.text.TextStyle,
) {
    val bias = line.centerFactor * 2f - 1f
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .offset(y = line.topDp.dp)
            // 两端都留终点内边距，只在中间连续收回：居中时左右对称，靠左时正好落在 14dp。
            .padding(horizontal = 14.dp * line.centerFactor),
        contentAlignment = BiasAlignment(bias, 0f),
    ) {
        Text(
            text = line.text,
            style = style,
            fontSize = line.sizeSp.sp,
            maxLines = 1,
            overflow = TextOverflow.Clip,
            color = ink,
            modifier = Modifier.alpha(line.alpha),
        )
    }
}
