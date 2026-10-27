package com.mutx163.qingyu.pages.statistics.charts

import com.mutx163.qingyu.statistics.DailyAverageStats
import com.mutx163.qingyu.statistics.DailyStats

/** 柱状图的一根柱子。 */
data class BarDatum(
    /** 横轴标签（周几短名，一~日）。 */
    val label: String,
    /** 柱高（课时数）。 */
    val value: Double,
    /** 是否达到"最高"档（取整判断在模型层做完，渲染层不再比较浮点）。 */
    val emphasis: BarEmphasis,
)

/**
 * 柱状图的**渲染规格**。
 *
 * 两个调用点共用这一套几何（`daily_chart.dart` 学期平均课时 / `week_stats_view.dart`
 * 周视图每日节数），差异只有「纵轴自动间隔的门槛」与「最高/最低判定口径」，
 * 都已在模型层参数化。
 */
data class BarChartSpec(
    /** 从左到右 7 根柱子。 */
    val bars: List<BarDatum>,
    /** 数据最大值（未加留白），用于纵轴刻度。 */
    val maxValue: Double,
    /** 纵轴上限 = maxValue + 1。 */
    val maxY: Double,
    /** 纵轴刻度间隔；`null` 表示自动（≤4 档）。 */
    val leftInterval: Int?,
) {
    val isEmpty: Boolean get() = bars.isEmpty()
}

object DailyChartModel {

    /**
     * 学期口径：每根柱高是**平均课时**（double），
     * 对应 Dart `daily_chart.dart`（177 行）。
     *
     * 强调档判据见 [ChartMath.dailyBarEmphasis]：最大值不管有没有课都算 MAX，
     * 但若整周无课（`activeDayCount == 0`）则无人强调。
     */
    fun averageSpec(dailyAverages: List<DailyAverageStats>): BarChartSpec? {
        if (dailyAverages.isEmpty()) return null
        val values = dailyAverages.map { it.averageSections }
        val maxAverage = values.maxOrNull() ?: 0.0
        val active = values.filter { it > 0.0 }
        val minAverage = active.minOrNull() ?: 0.0
        return BarChartSpec(
            bars = dailyAverages.map { stat ->
                BarDatum(
                    label = weekdayLabel(stat.dayOfWeek),
                    value = stat.averageSections,
                    emphasis = ChartMath.dailyBarEmphasis(
                        stat.averageSections,
                        maxAverage,
                        minAverage,
                        active.size,
                    ),
                )
            },
            maxValue = maxAverage,
            maxY = ChartMath.axisMax(maxAverage),
            leftInterval = ChartMath.axisTitleInterval(
                maxAverage,
                AVERAGE_AUTO_ABOVE,
                AVERAGE_MANUAL_INTERVAL,
            ),
        )
    }

    /**
     * 周口径：每根柱高是**本周该天的节数**（int），
     * 对应 Dart `week_stats_view.dart:174-355` 的 `_WeekDailyChart`。
     *
     * 与学期口径的两处真实差异（照抄，不要"统一"）：
     * 1. 自动间隔门槛 6（学期口径是 4）；
     * 2. 最高档要求 `value > 0`，且最低档显式排除最高档。
     */
    fun weekSpec(dailyStats: List<DailyStats>): BarChartSpec? {
        if (dailyStats.isEmpty()) return null
        val values = dailyStats.map { it.sectionCount }
        val maxSections = values.maxOrNull() ?: 0
        val active = values.filter { it > 0 }
        val minSections = active.minOrNull() ?: 0
        return BarChartSpec(
            bars = dailyStats.map { stat ->
                BarDatum(
                    label = weekdayLabel(stat.dayOfWeek),
                    value = stat.sectionCount.toDouble(),
                    emphasis = ChartMath.weekBarEmphasis(stat.sectionCount, maxSections, minSections),
                )
            },
            maxValue = maxSections.toDouble(),
            maxY = ChartMath.axisMax(maxSections),
            leftInterval = ChartMath.axisTitleInterval(
                maxSections.toDouble(),
                WEEK_AUTO_ABOVE,
                WEEK_MANUAL_INTERVAL,
            ),
        )
    }

    /** 柱宽 20dp（Dart `width: 20`）；窄屏时钳到槽宽一半，见 [ChartMath.barWidthPx]。 */
    const val BAR_WIDTH_DP = 20f

    /** 柱顶圆角 6dp（Dart `Radius.circular(6)`，只圆上面两角）。 */
    const val BAR_CORNER_DP = 6f

    /** 学期口径图表高度：`SizedBox(height: 168)`（`daily_chart.dart:38`）。 */
    const val AVERAGE_CHART_HEIGHT_DP = 168f

    /** 周口径图表高度：`SizedBox(height: 150)`（`week_stats_view.dart:212`）。 */
    const val WEEK_CHART_HEIGHT_DP = 150f

    /** 学期口径底部刻度占位：`reservedSize: 28`（`daily_chart.dart:99`）。 */
    const val AVERAGE_BOTTOM_RESERVE_DP = 28f

    /** 周口径底部刻度占位：`reservedSize: 26`（`week_stats_view.dart:233`）。 */
    const val WEEK_BOTTOM_RESERVE_DP = 26f

    /** 周口径左侧刻度占位：`reservedSize: 26`。 */
    const val WEEK_LEFT_RESERVE_DP = 26f

    /** 学期口径左侧刻度占位：`reservedSize: 28`。 */
    const val AVERAGE_LEFT_RESERVE_DP = 28f

    /** 非强调柱的主色透明度：`primary.withValues(alpha: 0.35)`。 */
    const val NORMAL_BAR_ALPHA = 0.35f

    /** 学期口径自动间隔门槛：`interval: maxAverage > 4 ? null : 1`（`daily_chart.dart:139`）。 */
    const val AVERAGE_AUTO_ABOVE = 4.0
    const val AVERAGE_MANUAL_INTERVAL = 1

    /** 周口径自动间隔门槛：`interval: maxSections > 6 ? null : 1`（`week_stats_view.dart:271`）。 */
    const val WEEK_AUTO_ABOVE = 6.0
    const val WEEK_MANUAL_INTERVAL = 1

    /** 周几短名（越界返回空串，与 Dart `_weekdayShortLabel` 的 switch 分支同口径）。 */
    fun weekdayLabel(dayOfWeek: Int): String = ChartsStrings.weekdayShort(dayOfWeek)

    /** 触摸提示文案：学期口径保留一位小数（`rod.toY.toStringAsFixed(1)`）。 */
    fun averageTooltip(value: Double): String =
        "${ChartMath.oneDecimal(value)} ${ChartsStrings.statisticsSectionsUnit.zh}"

    /** 触摸提示文案：周口径取整（`rod.toY.toInt()`）。 */
    fun weekTooltip(value: Int): String = "$value ${ChartsStrings.statisticsSectionsUnit.zh}"
}
