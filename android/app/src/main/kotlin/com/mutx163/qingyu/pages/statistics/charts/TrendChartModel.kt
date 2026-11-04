package com.mutx163.qingyu.pages.statistics.charts

import com.mutx163.qingyu.statistics.WeeklyTrendPoint

/**
 * 折线图上的一个数据点（周次 + 该周课时）。
 *
 * 用 `Int` 而非 `Float`：周次与课时都是整数量，保留整数让端点判断
 * （`week <= currentWeek`、`sections == max`）不引入浮点误差。
 */
data class TrendDatum(val week: Int, val sections: Int)

/**
 * 每周课时趋势图的**渲染规格**（供 `TrendChartCard` 直接画，不含任何 Android 类型）。
 *
 * 对应 Dart `lib/widgets/statistics/trend_chart.dart`（182 行，fl_chart 折线图）。
 * 数值全部照抄 Dart 的 fl_chart 配置，出处见各字段注释。
 */
data class TrendChartSpec(
    /** 已过周（`weekNumber <= currentWeek`）：实线 + 面积填充 + 圆点。 */
    val elapsed: List<TrendDatum>,
    /** 未来周（`weekNumber > currentWeek`）：浅色虚线预告，无圆点。 */
    val future: List<TrendDatum>,
    /** 首个周次（横轴左界，= fl_chart 的 minX）。 */
    val minWeek: Int,
    /** 末个周次（横轴右界，= fl_chart 的 maxX）。 */
    val maxWeek: Int,
    /** 数据里的最大课时（未加留白）。 */
    val maxSections: Int,
    /** 纵轴上限 = maxSections + 1。 */
    val maxY: Double,
    /** 纵轴刻度间隔；`null` 表示按 4 档自动。 */
    val leftInterval: Int?,
    /** 需要标出周次文字的槽位（从左到右，元素为 `null` 表示该槽不标）。 */
    val weekLabels: List<Int?>,
    /** 是否画圆点（Dart：`elapsed.length <= 20`）。 */
    val showDots: Boolean,
) {
    val isEmpty: Boolean get() = elapsed.isEmpty() && future.isEmpty()

    /** 图表主体高度：`SizedBox(height: 160)`（`trend_chart.dart:38`）。 */
    val chartHeightDp: Float get() = CHART_HEIGHT_DP

    /** 底部刻度占位：`reservedSize: 26`（`trend_chart.dart:74`）。 */
    val bottomReserveDp: Float get() = BOTTOM_RESERVE_DP

    /** 左侧刻度占位：`reservedSize: 28`（`trend_chart.dart:77`）。 */
    val leftReserveDp: Float get() = LEFT_RESERVE_DP

    companion object {
        const val CHART_HEIGHT_DP = 160f
        const val BOTTOM_RESERVE_DP = 26f
        const val LEFT_RESERVE_DP = 28f

        /** 折线宽：`barWidth: 2.5`（`trend_chart.dart:133`）。 */
        const val LINE_WIDTH_DP = 2.5f

        /** 圆点半径：`FlDotCirclePainter(radius: 3...)`（`trend_chart.dart:139`）。 */
        const val DOT_RADIUS_DP = 3f

        /** 圆点描边宽：`strokeWidth: 1`（`trend_chart.dart:141`）。 */
        const val DOT_STROKE_WIDTH_DP = 1f

        /** 线下面积填充透明度：`alpha: 0.10`（`trend_chart.dart:148`）。 */
        const val AREA_ALPHA = 0.10f

        /** 未来周虚线色透明度：`alpha: 0.45`（`trend_chart.dart:154`）。 */
        const val FUTURE_ALPHA = 0.45f

        /** 虚线节奏：`dashArray: [6, 4]`（`trend_chart.dart:156`）。 */
        const val DASH_ON = 6f
        const val DASH_OFF = 4f

        /** 圆点数量上限：`show: elapsed.length <= 20`（`trend_chart.dart:138`）。 */
        const val DOT_MAX_COUNT = 20

        /** 纵轴自动间隔的门槛：`interval: maxY > 8 ? null : 2`（`trend_chart.dart:83`）。 */
        const val LEFT_AUTO_ABOVE = 8.0
        const val LEFT_MANUAL_INTERVAL = 2
    }
}

object TrendChartModel {

    /**
     * 构建趋势图规格；`trend` 为空时返回 `null`
     * （Dart：`if (trend.isEmpty) return const SizedBox.shrink()`，`trend_chart.dart:22-24`）。
     *
     * @param trend 整学期每周计划课时（上游已按周次升序）
     * @param currentWeek 当前教学周；`week <= currentWeek` 归入实线
     */
    fun build(trend: List<WeeklyTrendPoint>, currentWeek: Int): TrendChartSpec? {
        if (trend.isEmpty()) return null
        val elapsed = trend.filter { it.weekNumber <= currentWeek }
            .map { TrendDatum(it.weekNumber, it.sections) }
        val future = trend.filter { it.weekNumber > currentWeek }
            .map { TrendDatum(it.weekNumber, it.sections) }

        val minWeek = trend.first().weekNumber
        val maxWeek = trend.last().weekNumber
        val maxSections = trend.maxOf { it.sections }
        val interval = ChartMath.trendLabelInterval(maxWeek)

        return TrendChartSpec(
            elapsed = elapsed,
            future = future,
            minWeek = minWeek,
            maxWeek = maxWeek,
            maxSections = maxSections,
            maxY = ChartMath.axisMax(maxSections),
            leftInterval = ChartMath.axisTitleInterval(
                maxSections.toDouble(),
                TrendChartSpec.LEFT_AUTO_ABOVE,
                TrendChartSpec.LEFT_MANUAL_INTERVAL,
            ),
            weekLabels = weekLabels(minWeek, maxWeek, interval),
            showDots = elapsed.size <= TrendChartSpec.DOT_MAX_COUNT,
        )
    }

    /**
     * 哪些周次标数字。
     *
     * Dart 用 fl_chart 的 `interval: _labelInterval(maxWeek)` 布点；fl_chart 的刻度
     * 是**从轴最小值起按 interval 递增**（`minX, minX+I, minX+2I, …`），所以这里
     * 按 `(week - minWeek) % interval == 0` 判断。末周若不是间隔整数倍，Dart 也不标；
     * 不再额外补标（L4 逐页对照时会多出一个 Dart 没有的刻度）。
     *
     * 例：`minWeek=1, maxWeek=20, interval=4` → 1、5、9、13、17。
     */
    fun weekLabels(minWeek: Int, maxWeek: Int, interval: Int): List<Int?> {
        if (maxWeek < minWeek) return emptyList()
        val step = interval.coerceAtLeast(1)
        return (minWeek..maxWeek).map { week ->
            val labelled = week == minWeek || (week - minWeek) % step == 0
            if (labelled) week else null
        }
    }

    /**
     * 折线在画布上的 x。
     *
     * fl_chart 的 `getPixelX` 把 `minX..maxX` **线性铺满**画布可用宽度
     * （`x = (value - minX) / (maxX - minX) * width`），首周贴左边缘、末周贴右边缘，
     * **不是**落在均分槽位的中心。本迁移上一版按 `barCenterX`（槽心）映射，
     * 首末两周各内缩半个槽宽，与 Dart 图对不上；2026-11-03 改为边到边。
     *
     * 只有一个周次时值域退化（`maxX - minX == 0`）：fl_chart 会算出 NaN 路径，
     * 这里退到画布正中（[ChartMath.mapX] 的既有兜底），标签行同口径也是 50%。
     */
    fun pointX(week: Int, minWeek: Int, maxWeek: Int, canvasWidth: Float): Float =
        ChartMath.mapX(week.toDouble(), minWeek.toDouble(), maxWeek.toDouble(), canvasWidth)

    /** 折线在画布上的 y（0 节在底部，`maxY` 在顶部）。 */
    fun pointY(sections: Int, maxY: Double, canvasHeight: Float): Float =
        ChartMath.mapY(sections.toDouble(), maxY, canvasHeight)

    /** 触摸提示文案（Dart `l10n.statisticsTrendTooltip(week, sections)`）。 */
    fun tooltip(week: Int, sections: Int): String =
        ChartsStrings.statisticsTrendTooltip.filled(
            "week" to week.toString(),
            "sections" to sections.toString(),
        )
}
