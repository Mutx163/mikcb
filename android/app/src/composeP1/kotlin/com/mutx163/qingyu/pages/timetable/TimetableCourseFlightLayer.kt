package com.mutx163.qingyu.pages.timetable

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.pages.settings.HomeMaterialRenderSpec
import com.mutx163.qingyu.pages.timetable.day.dayAgendaGlassBackdrop
import com.mutx163.qingyu.pages.timetable.day.dayAgendaSurface
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.blur.Backdrop
import top.yukonga.miuix.kmp.theme.MiuixTheme
import kotlin.math.roundToInt

/**
 * 首页「周 → 日」展开的**课程卡逐卡飞行层**（2026-11-03，阶段 B）。
 *
 * 每张卡两端都来自 [CourseFlightMeasureHost] 的实测：
 * - 起点：周网格里那张卡的卡面（随滚动 / 跨周页 pager 变化，算不准）；
 * - 终点：日视图议程里那张卡的卡面（高度随内容变，算不准）。
 *
 * 渲染口径逐项对齐 Flutter `flight_card_body.dart` / `flight_text_metrics.dart`：
 * 矩形与圆角、投影由 [homeViewCourseFlightRect] 等同一条进度插值；文字**不换节点**
 * （同一行从起点锚点连续移到终点锚点，字号连续插值），只在
 * [HOME_VIEW_COURSE_FLIGHT_TEXT_SWITCH_AT] 换文案 —— 这是「不出现三个位置的同一行字」
 * 的关键。卡片多时的档位见 [homeViewCourseFlightTextMode]。
 *
 * 卡面本身不做透明度渐隐（与 Flutter 同一口径：卡面两端都在，渐隐会看到底下另一样东西）；
 * 只有「只起点有 / 只终点有」的行才按区间淡出淡入。
 *
 * ## 已知偏差（P1-8 / P1-11，成本高，按施工单 v2 先记 KDoc）
 *
 * - **P1-8 图标行**：日议程卡里教师/地点/天气/备注带前导图标（`DayAgendaInfoRow` 的 icon），
 *   飞行层只画文字、不画图标；这几行的图标会在落定帧「弹出」。要补需把图标也登记成锚点并插值，
 *   成本高，本轮不做。
 * - **P1-11 时间行**：周卡有 `time` / `timeEnd` 两行（起、止），日卡只有一条 `time`（起 - 止）。
 *   共享 id `time` 在 0.45 切文案，飞行中可能读到「起点一行 → 终点合一」的短暂重影。要彻底消解
 *   需按行拆两套锚点并做 alpha 交叉，成本高，本轮不做。
 */
@Composable
fun TimetableCourseFlightLayer(
    progress: () -> Float,
    host: CourseFlightMeasureHost,
    cardKeys: List<String>,
    origin: Offset,
    material: HomeMaterialRenderSpec?,
    glassBackdrop: Backdrop?,
    modifier: Modifier = Modifier,
) {
    val mode = homeViewCourseFlightTextMode(cardKeys.size)
    Box(modifier = modifier) {
        cardKeys.forEach { key ->
            CourseFlightCard(
                cardKey = key,
                progress = progress,
                host = host,
                origin = origin,
                mode = mode,
                material = material,
                glassBackdrop = glassBackdrop,
            )
        }
    }
}

@Composable
private fun CourseFlightCard(
    cardKey: String,
    progress: () -> Float,
    host: CourseFlightMeasureHost,
    origin: Offset,
    mode: HomeViewCourseFlightTextMode,
    material: HomeMaterialRenderSpec?,
    glassBackdrop: Backdrop?,
) {
    val weekSurface = host.weekSurfaces[cardKey] ?: return
    val daySurface = host.daySurfaces[cardKey] ?: return
    val t = progress().coerceIn(0f, 1f)
    if (t <= 0f || t >= 1f) return

    val start = weekSurface.bounds.toFlightRect(origin)
    val end = daySurface.bounds.toFlightRect(origin)
    val frame = homeViewCourseFlightRect(start, end, t)
    val corner = homeViewCourseFlightCornerDp(t)
    val shape = RoundedCornerShape(corner.dp)
    val shadowAlpha = homeViewCourseFlightShadowAlpha(t)
    val surfaceFill = lerp(weekSurface.fill, daySurface.fill, t)
    val density = LocalDensity.current

    Box(
        modifier = Modifier
            .offset { IntOffset(frame.left.roundToInt(), frame.top.roundToInt()) }
            .size(
                width = with(density) { frame.width.toDp() },
                height = with(density) { frame.height.toDp() },
            )
            .shadow(
                elevation = (4.dp * t),
                shape = shape,
                clip = false,
                ambientColor = Color.Black.copy(alpha = shadowAlpha),
                spotColor = Color.Black.copy(alpha = shadowAlpha),
            )
            .clip(shape)
            .dayAgendaSurface(
                glassBackdrop = dayAgendaGlassBackdrop(material, glassBackdrop),
                shape = shape,
                fill = surfaceFill,
            ),
    ) {
        if (mode == HomeViewCourseFlightTextMode.SURFACE_ONLY) return@Box
        HOME_VIEW_COURSE_FLIGHT_LINE_ORDER.forEach { lineId ->
            if (!homeViewCourseFlightLineVisible(mode, lineId)) return@forEach
            CourseFlightLine(
                lineId = lineId,
                cardKey = cardKey,
                host = host,
                origin = origin,
                progress = t,
            )
        }
    }
}

@Composable
private fun CourseFlightLine(
    lineId: String,
    cardKey: String,
    host: CourseFlightMeasureHost,
    origin: Offset,
    progress: Float,
) {
    val week = host.weekTexts["$cardKey|$lineId"]?.toLocal(origin)
    val day = host.dayTexts["$cardKey|$lineId"]?.toLocal(origin)
    val spec = homeViewCourseFlightLine(week, day, progress) ?: return
    val density = LocalDensity.current

    Text(
        text = spec.text,
        style = MiuixTheme.textStyles.footnote1.copy(
            fontSize = spec.fontSizeSp.sp,
            fontWeight = spec.weight,
            // P1-7：行高按两端实测插值；0 = 该行未指定行高，交给默认。
            lineHeight = if (spec.lineHeightSp > 0f) spec.lineHeightSp.sp else TextUnit.Unspecified,
        ),
        color = spec.ink,
        // P1-5/6：行数来自实测锚点（两端按换文案点切换），不再硬编码 name?2:1。
        maxLines = spec.maxLines,
        overflow = TextOverflow.Ellipsis,
        modifier = Modifier
            .offset { IntOffset(spec.left.roundToInt(), spec.top.roundToInt()) }
            .width(with(density) { spec.widthPx.toDp() }),
    )
}

/** 飞行层里一行最终的绘制参数。 */
private data class CourseFlightLineSpec(
    val text: String,
    val left: Float,
    val top: Float,
    val widthPx: Float,
    val fontSizeSp: Float,
    val weight: FontWeight,
    val ink: Color,
    val maxLines: Int,
    val lineHeightSp: Float,
)

/**
 * 同一行在两端锚点上的插值；只有一端时按「只起点 / 只终点」的区间淡出淡入。
 *
 * 这是本文件里唯一的插值入口；纯函数部分（矩形 / 圆角 / 切换点 / 区间）都在
 * `HomeViewCourseFlight.kt` 里，由 JVM 单测钉住。
 */
private fun homeViewCourseFlightLine(
    week: CourseFlightTextAnchor?,
    day: CourseFlightTextAnchor?,
    progress: Float,
): CourseFlightLineSpec? {
    if (week != null && day != null) {
        val t = progress.coerceIn(0f, 1f)
        val useEnd = homeViewCourseFlightUsesEndText(t)
        return CourseFlightLineSpec(
            text = if (useEnd) day.text else week.text,
            left = lerpFloat(week.bounds.left, day.bounds.left, t),
            top = lerpFloat(week.bounds.top, day.bounds.top, t),
            widthPx = lerpFloat(week.bounds.width, day.bounds.width, t),
            fontSizeSp = lerpFloat(week.fontSizeSp, day.fontSizeSp, t),
            weight = if (useEnd) day.weight else week.weight,
            ink = lerp(week.ink, day.ink, t),
            maxLines = homeViewCourseFlightMaxLines(week.maxLines, day.maxLines, useEnd),
            lineHeightSp = homeViewCourseFlightLineHeight(week.lineHeightSp, day.lineHeightSp, t),
        )
    }
    if (week != null) {
        val alpha = homeViewCourseFlightStartOnlyAlpha(progress)
        if (alpha <= 0f) return null
        return CourseFlightLineSpec(
            text = week.text,
            left = week.bounds.left,
            top = week.bounds.top,
            widthPx = week.bounds.width,
            fontSizeSp = week.fontSizeSp,
            weight = week.weight,
            ink = week.ink.fadeTo(alpha),
            maxLines = week.maxLines,
            lineHeightSp = week.lineHeightSp,
        )
    }
    if (day != null) {
        val alpha = homeViewCourseFlightEndOnlyAlpha(progress)
        if (alpha <= 0f) return null
        return CourseFlightLineSpec(
            text = day.text,
            left = day.bounds.left,
            top = day.bounds.top,
            widthPx = day.bounds.width,
            fontSizeSp = day.fontSizeSp,
            weight = day.weight,
            ink = day.ink.fadeTo(alpha),
            maxLines = day.maxLines,
            lineHeightSp = day.lineHeightSp,
        )
    }
    return null
}

private fun Color.fadeTo(alpha: Float): Color = copy(alpha = this.alpha * alpha.coerceIn(0f, 1f))

private fun lerpFloat(a: Float, b: Float, t: Float): Float = a + (b - a) * t

private fun Rect.toFlightRect(origin: Offset): HomeViewFlightRect = HomeViewFlightRect(
    left = left - origin.x,
    top = top - origin.y,
    right = right - origin.x,
    bottom = bottom - origin.y,
)

private fun CourseFlightTextAnchor.toLocal(origin: Offset): CourseFlightTextAnchor = copy(
    bounds = Rect(
        left = bounds.left - origin.x,
        top = bounds.top - origin.y,
        right = bounds.right - origin.x,
        bottom = bounds.bottom - origin.y,
    ),
)
