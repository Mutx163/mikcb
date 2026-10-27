package com.mutx163.qingyu.pages.statistics.charts

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 统计图表层用到的强调色。
 *
 * 数值逐条抄 `lib/ui/hyperos/hyperos_tokens.dart:125-135`（`HyperosIconColors`）。
 * 这些是**语义色**（蓝=必修、紫=选修、青=最低档、橙=小结…），不是主题种子色，
 * 因此不跟 `QingyuTheme.primary` 走——Dart 侧也是写死的。
 */
object ChartPalette {
    val Blue = Color(0xFF3482FF)
    val Green = Color(0xFF10C550)
    val Orange = Color(0xFFFF6B00)
    val Purple = Color(0xFF8B5CF6)
    val Teal = Color(0xFF14B8A6)
    val Red = Color(0xFFFA382E)
    val Yellow = Color(0xFFF5A623)
    val Indigo = Color(0xFF6366F1)
    val Cyan = Color(0xFF06B6D4)
}

/**
 * 图表卡的图标徽章（Dart `HyperosIconBadge` 的对位件）。
 *
 * 28dp 圆角方块 + 12% 强调色底 + 强调色图标，与 Dart 的 `iconBadgeSize` 一致。
 */
@Composable
fun ChartIconBadge(
    icon: ImageVector,
    accent: Color,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .size(28.dp)
            .clip(RoundedCornerShape(9.dp))
            .background(accent.copy(alpha = 0.14f)),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = accent,
            modifier = Modifier.size(17.dp),
        )
    }
}

/** 卡片标题行：图标徽章 + 标题 +（可选）右侧尾注。 */
@Composable
fun ChartCardHeader(
    title: String,
    icon: ImageVector,
    accent: Color,
    dark: Boolean,
    modifier: Modifier = Modifier,
    trailing: String? = null,
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        ChartIconBadge(icon = icon, accent = accent)
        Box(modifier = Modifier.width(10.dp))
        Text(
            text = title,
            style = MiuixTheme.textStyles.body1,
            color = Color(QingyuTheme.primaryText(dark)),
            modifier = Modifier.weight(1f),
        )
        if (trailing != null) {
            Text(
                text = trailing,
                style = MiuixTheme.textStyles.footnote2,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
    }
}

// ══════════════════════ 折线图 ══════════════════════

/**
 * 每周课时趋势（Canvas 手绘折线）。
 *
 * 画法与 Dart fl_chart 配置逐项对应：
 * - 横向网格线（无竖向）：`FlGridData(drawVerticalLine: false)`；
 * - 已过周：主题色实线（2.5dp）+ 线下 10% 面积 + 圆点（≤20 点才画）；
 * - 未来周：次级文字色 45% 虚线（6/4），不画圆点。
 *
 * 平滑曲线与虚线都用模型层的纯函数算（[ChartMath.cubicControls] /
 * [ChartMath.sampleCurve] / [ChartMath.dashPolyline]），这里只负责落笔。
 */
@Composable
fun TrendLineCanvas(
    spec: TrendChartSpec,
    dark: Boolean,
    modifier: Modifier = Modifier,
) {
    val primary = Color(QingyuTheme.primary(dark = dark))
    val gridColor = Color(QingyuTheme.dividerLine(dark))
    val cardColor = Color(QingyuTheme.card(dark))
    val futureColor = Color(QingyuTheme.secondaryText(dark)).copy(alpha = TrendChartSpec.FUTURE_ALPHA)

    val ticks = ChartMath.leftAxisTicks(spec.maxY, spec.leftInterval)

    Canvas(
        modifier = modifier
            .fillMaxWidth()
            .height(spec.chartHeightDp.dp),
    ) {
        val h = size.height
        val w = size.width

        // ① 横向网格线
        for (tick in ticks) {
            val y = ChartMath.mapY(tick.toDouble(), spec.maxY, h)
            drawLine(
                color = gridColor,
                start = Offset(0f, y),
                end = Offset(w, y),
                strokeWidth = 1f,
            )
        }

        // ② 已过周：面积 + 曲线
        val elapsedPoints = spec.elapsed.map { datum ->
            ChartPoint(TrendChartModel.pointX(datum.week, spec.minWeek, spec.weekSlotCount, w), TrendChartModel.pointY(datum.sections, spec.maxY, h))
        }
        if (elapsedPoints.isNotEmpty()) {
            val curve = ChartMath.sampleCurve(elapsedPoints)
            val areaPath = Path().apply {
                moveTo(curve.first().x, h)
                lineTo(curve.first().x, curve.first().y)
                for (p in curve.drop(1)) lineTo(p.x, p.y)
                lineTo(curve.last().x, h)
                close()
            }
            drawPath(areaPath, color = primary.copy(alpha = TrendChartSpec.AREA_ALPHA))
            drawPath(
                path = curvePath(curve),
                color = primary,
                style = Stroke(width = TrendChartSpec.LINE_WIDTH_DP.dp.toPx(), cap = StrokeCap.Round),
            )
            // ③ 圆点（半径 3 + 1dp 卡片色描边，让点从线上"浮"起来）
            if (spec.showDots) {
                val radius = TrendChartSpec.DOT_RADIUS_DP.dp.toPx()
                val stroke = TrendChartSpec.DOT_STROKE_WIDTH_DP.dp.toPx()
                for (p in elapsedPoints) {
                    drawCircle(color = primary, radius = radius, center = Offset(p.x, p.y))
                    drawCircle(
                        color = cardColor,
                        radius = radius,
                        center = Offset(p.x, p.y),
                        style = Stroke(width = stroke),
                    )
                }
            }
        }

        // ④ 未来周：虚线（先按曲线采样，再按 6/4 切段，保证"边弯边虚"）
        if (spec.future.isNotEmpty()) {
            // 未来线从最后一个已过周连过来，视觉上不断线
            val anchor = spec.elapsed.lastOrNull()
            val futurePoints = buildList {
                if (anchor != null) {
                    add(
                        ChartPoint(
                            TrendChartModel.pointX(anchor.week, spec.minWeek, spec.weekSlotCount, w),
                            TrendChartModel.pointY(anchor.sections, spec.maxY, h),
                        ),
                    )
                }
                for (datum in spec.future) {
                    add(
                        ChartPoint(
                            TrendChartModel.pointX(datum.week, spec.minWeek, spec.weekSlotCount, w),
                            TrendChartModel.pointY(datum.sections, spec.maxY, h),
                        ),
                    )
                }
            }
            val sampled = ChartMath.sampleCurve(futurePoints)
            val segments = ChartMath.dashPolyline(
                sampled,
                dash = TrendChartSpec.DASH_ON,
                gap = TrendChartSpec.DASH_OFF,
            )
            val strokeWidth = TrendChartSpec.LINE_WIDTH_DP.dp.toPx()
            for (segment in segments) {
                drawPath(
                    path = curvePath(segment, smooth = false),
                    color = futureColor,
                    style = Stroke(width = strokeWidth, cap = StrokeCap.Round),
                )
            }
        }
    }
}

/** 把采样点连成 Path；[smooth] 为 false 时走折线（虚线已按曲线采样过，无需再平滑）。 */
private fun curvePath(points: List<ChartPoint>, smooth: Boolean = false): Path {
    val path = Path()
    if (points.isEmpty()) return path
    path.moveTo(points.first().x, points.first().y)
    if (smooth) {
        val controls = ChartMath.curveControlPoints(points)
        for (i in controls.indices) {
            val c = controls[i]
            path.cubicTo(c.c1x, c.c1y, c.c2x, c.c2y, points[i + 1].x, points[i + 1].y)
        }
    } else {
        for (p in points.drop(1)) path.lineTo(p.x, p.y)
    }
    return path
}

// ══════════════════════ 柱状图 ══════════════════════

/**
 * 每日课时柱状图（Canvas 手绘）。
 *
 * - 柱子 20dp 宽、顶部 6dp 圆角（窄屏钳到槽宽一半，见 [ChartMath.barWidthPx]）；
 * - 颜色三档：最高=主题色、最低=青、其余=主题色 35%；
 * - 横向网格线同折线图，无竖向线。
 */
@Composable
fun BarChartCanvas(
    spec: BarChartSpec,
    dark: Boolean,
    modifier: Modifier = Modifier,
    chartHeightDp: Float = DailyChartModel.AVERAGE_CHART_HEIGHT_DP,
) {
    val primary = Color(QingyuTheme.primary(dark = dark))
    val gridColor = Color(QingyuTheme.dividerLine(dark))
    val ticks = ChartMath.leftAxisTicks(spec.maxY, spec.leftInterval)

    Canvas(
        modifier = modifier
            .fillMaxWidth()
            .height(chartHeightDp.dp),
    ) {
        val h = size.height
        val w = size.width

        for (tick in ticks) {
            val y = ChartMath.mapY(tick.toDouble(), spec.maxY, h)
            drawLine(
                color = gridColor,
                start = Offset(0f, y),
                end = Offset(w, y),
                strokeWidth = 1f,
            )
        }

        val count = spec.bars.size
        val slot = ChartMath.barSlotWidth(w, count)
        val barWidth = ChartMath.barWidthPx(slot, DailyChartModel.BAR_WIDTH_DP.dp.toPx())
        val radius = CornerRadius(DailyChartModel.BAR_CORNER_DP.dp.toPx())

        spec.bars.forEachIndexed { index, bar ->
            val top = ChartMath.barTopY(bar.value, spec.maxY, h)
            // 0 值不画柱子（画出来会是一条压在轴线上的圆角横条）
            if (bar.value <= 0.0) return@forEachIndexed
            val centerX = ChartMath.barCenterX(index, count, w)
            val color = when (bar.emphasis) {
                BarEmphasis.MAX -> primary
                BarEmphasis.MIN -> ChartPalette.Teal
                BarEmphasis.NORMAL -> primary.copy(alpha = DailyChartModel.NORMAL_BAR_ALPHA)
            }
            drawRoundRect(
                color = color,
                topLeft = Offset(centerX - barWidth / 2f, top),
                size = Size(barWidth, h - top),
                cornerRadius = radius,
            )
        }
    }
}

// ══════════════════════ 热力格 ══════════════════════

/**
 * 学期热力图（Canvas 手绘格子）。
 *
 * 格子 13dp、间距 3dp、圆角 3.5dp；空格用"行高亮"底色而不是主色 0%，
 * 否则空格与卡片底同色，看起来像缺了一块。
 */
@Composable
fun HeatGridCanvas(
    spec: HeatmapSpec,
    dark: Boolean,
    modifier: Modifier = Modifier,
) {
    val base = Color(QingyuTheme.primary(dark = dark))
    val emptyColor = Color(QingyuTheme.rowHighlight(dark))
    val cellSize = HeatmapSpec.CELL_SIZE_DP.dp
    val gap = HeatmapSpec.CELL_GAP_DP.dp

    Canvas(
        modifier = modifier
            .fillMaxWidth()
            .height(HeatmapModel.gridHeight(HeatmapSpec.CELL_SIZE_DP, HeatmapSpec.CELL_GAP_DP).dp),
    ) {
        val cell = cellSize.toPx()
        val cellGap = gap.toPx()
        val radius = CornerRadius(HeatmapSpec.CELL_CORNER_DP.dp.toPx())
        for (day in 0 until 7) {
            val row = spec.levels.getOrNull(day) ?: continue
            val alphas = spec.alphas.getOrNull(day) ?: continue
            for (week in 0 until spec.weekCount) {
                val level = row.getOrNull(week) ?: continue
                val color = if (level <= ChartMath.HEAT_LEVEL_EMPTY) {
                    emptyColor
                } else {
                    base.copy(alpha = alphas.getOrElse(week) { 1f })
                }
                drawRoundRect(
                    color = color,
                    topLeft = Offset(
                        HeatmapModel.cellLeft(week, cell, cellGap),
                        HeatmapModel.cellTop(day, cell, cellGap),
                    ),
                    size = Size(cell, cell),
                    cornerRadius = radius,
                )
            }
        }
    }
}

// ══════════════════════ 环形图 ══════════════════════

/**
 * 必修 / 选修环形图（Canvas 手绘弧）。
 *
 * 半径与孔径来自 [ChartMath.donutGeometry]：两侧都有课时 ring=20/hole=28，
 * 缺一侧时收细到 18 并加大孔到 32，给中心提示文案腾地方（照 Dart 原注释的理由）。
 * 段间缝隙 2° 由 [ChartMath.donutArcs] 在两侧各让出一半。
 */
@Composable
fun DonutRingCanvas(
    requiredCount: Int,
    electiveCount: Int,
    modifier: Modifier = Modifier,
) {
    val geometry = ChartMath.donutGeometry(requiredCount, electiveCount)
    val slices = ChartMath.donutSlices(requiredCount, electiveCount)
    val arcs = ChartMath.donutArcs(slices.map { it.value })

    Canvas(modifier = modifier) {
        // 环带：内缘 = 孔半径，外缘 = 孔 + 环厚（Dart 里是 centerSpaceRadius 与 section radius）。
        // 描边画在环带中线上，粗细 = 环厚，于是内外缘正好落在 28 / 48（正常态）——100dp 盒子里不裁边。
        val hole = geometry.centerRadius.dp.toPx()
        val outer = (geometry.centerRadius + geometry.radius).dp.toPx()
        val midRadius = (hole + outer) / 2f
        val strokeWidth = outer - hole
        val topLeft = Offset(
            size.width / 2f - midRadius,
            size.height / 2f - midRadius,
        )
        val arcSize = Size(midRadius * 2f, midRadius * 2f)

        slices.forEachIndexed { index, slice ->
            val arc = arcs.getOrNull(index) ?: return@forEachIndexed
            if (arc.sweepDegrees <= 0f) return@forEachIndexed
            val color = when (slice.nature) {
                DonutSlice.NatureKind.REQUIRED -> ChartPalette.Blue
                DonutSlice.NatureKind.ELECTIVE -> ChartPalette.Purple
            }
            drawArc(
                color = if (slice.placeholder) color.copy(alpha = 0.12f) else color,
                startAngle = arc.startDegrees,
                sweepAngle = arc.sweepDegrees,
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = Stroke(width = strokeWidth),
            )
        }
    }
}

// ══════════════════════ 轴标签 ══════════════════════

/**
 * 横轴标签行：每个槽位等宽，只有该槽有标签时画字。
 *
 * 与 Canvas 里 [ChartMath.barCenterX] 的槽位中心一致（都是均分 + 居中），
 * 所以柱子和标签天然对齐，不需要测量文本宽度。
 */
@Composable
fun ChartAxisLabelRow(
    labels: List<String?>,
    dark: Boolean,
    modifier: Modifier = Modifier,
    highlightIndex: Int? = null,
    fontSizeSp: Float = 11f,
    topPaddingDp: Float = 6f,
) {
    Row(modifier = modifier.fillMaxWidth()) {
        labels.forEachIndexed { index, label ->
            Text(
                text = label ?: "",
                style = MiuixTheme.textStyles.footnote2,
                fontSize = fontSizeSp.sp,
                textAlign = TextAlign.Center,
                maxLines = 1,
                color = if (index == highlightIndex) {
                    Color(QingyuTheme.primary(dark = dark))
                } else {
                    Color(QingyuTheme.secondaryText(dark))
                },
                modifier = Modifier
                    .weight(1f)
                    .padding(top = topPaddingDp.dp),
            )
        }
    }
}

/**
 * 纵轴上下边界标签（顶部 = 上限、底部 = 0），纵向两端对齐图表高度。
 *
 * 与 Canvas 里的 `mapY` 同口径：值 [maxY] 在顶部、0 在底部。
 */
@Composable
fun ChartLeftAxisLabels(
    maxY: Double,
    heightDp: Float,
    widthDp: Float,
    dark: Boolean,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .width(widthDp.dp)
            .height(heightDp.dp),
        verticalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = maxY.toInt().toString(),
            style = MiuixTheme.textStyles.footnote2,
            color = Color(QingyuTheme.secondaryText(dark)),
        )
        Text(
            text = "0",
            style = MiuixTheme.textStyles.footnote2,
            color = Color(QingyuTheme.secondaryText(dark)),
        )
    }
}
