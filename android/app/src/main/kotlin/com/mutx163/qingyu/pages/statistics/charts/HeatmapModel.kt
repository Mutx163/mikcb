package com.mutx163.qingyu.pages.statistics.charts

import com.mutx163.qingyu.statistics.SemesterHeatmap

/**
 * 学期热力图的**渲染规格**（周 × 天课时密度）。
 *
 * 对应 Dart `lib/widgets/statistics/heatmap_card.dart`（157 行）。
 * 尺寸全部照抄 `heatmap_card.dart:22-24`：
 * 格子 13dp、格间距 3dp、星期标签列宽 22dp。
 */
data class HeatmapSpec(
    /** 周数（列数）。 */
    val weekCount: Int,
    /** 7 行 × [weekCount] 列的分级结果（0=无课，1~4=由浅到深）。 */
    val levels: List<List<Int>>,
    /** 对应的主色透明度，与 [levels] 一一对应（行优先，周一在前）。 */
    val alphas: List<List<Float>>,
    /** 每列顶部的周次标签；`null` 表示该列不标。 */
    val weekLabels: List<Int?>,
    /** 裁剪后的单格最大值（配色标度的分母）。 */
    val maxSections: Int,
) {
    val isEmpty: Boolean get() = weekCount < 1 || levels.isEmpty()

    companion object {
        /** 格子边长（`heatmap_card.dart:22` `_cellSize = 13`）。 */
        const val CELL_SIZE_DP = 13f

        /** 格子间距（`heatmap_card.dart:23` `_cellGap = 3`）。 */
        const val CELL_GAP_DP = 3f

        /** 星期标签列宽（`heatmap_card.dart:24` `_labelWidth = 22`）。 */
        const val LABEL_WIDTH_DP = 22f

        /** 标签列与网格之间的间距：`SizedBox(width: 6)`（`heatmap_card.dart:100`）。 */
        const val LABEL_TO_GRID_GAP_DP = 6f

        /** 格子圆角：`BorderRadius.circular(3.5)`（`heatmap_card.dart:132`）。 */
        const val CELL_CORNER_DP = 3.5f

        /** 一行（含行间空隙）的高度：标签列按这个高度排（`heatmap_card.dart:88`）。 */
        const val ROW_PITCH_DP = CELL_SIZE_DP + CELL_GAP_DP

        /** 星期标签字号：`fontSize: 10`（`heatmap_card.dart:94`）。 */
        const val WEEKDAY_LABEL_SP = 10f

        /** 周次标签字号：`fontSize: 9`（`heatmap_card.dart:121`）。 */
        const val WEEK_LABEL_SP = 9f

        /** 卡片标题与网格之间的间距：`SizedBox(height: 12)`（`heatmap_card.dart:82`）。 */
        const val HEADER_TO_GRID_DP = 12f
    }
}

object HeatmapModel {

    /**
     * 构建热力图规格；周数 < 1 时返回 `null`
     * （Dart：`if (heatmap.weekCount < 1) return const SizedBox.shrink()`，`heatmap_card.dart:32-34`）。
     *
     * 未来周（超过 [currentWeek]）先置 0 再算配色标度——所以**翻到第 3 周时，
     * 第 5 周那一列的深色会消失**，这是有意的：未发生的课不该被画成"已经很忙"。
     */
    fun build(heatmap: SemesterHeatmap, currentWeek: Int): HeatmapSpec? {
        if (heatmap.weekCount < 1) return null
        val clipped = heatmap.clippedToWeek(currentWeek)
        val maxSections = clipped.maxSections
        val levels = clipped.rows.map { row ->
            row.map { value -> ChartMath.heatLevel(value, maxSections) }
        }
        val alphas = levels.map { row -> row.map { level -> ChartMath.heatAlpha(level) } }
        return HeatmapSpec(
            weekCount = clipped.weekCount,
            levels = levels,
            alphas = alphas,
            weekLabels = weekLabels(clipped.weekCount),
            maxSections = maxSections,
        )
    }

    /**
     * 每周列顶部是否标周次：`week % 4 == 1` 或最后一列（`heatmap_card.dart:118`）。
     *
     * 下标从 1 开始（第 1 列 = 第 1 周），返回值同样从第 1 周开始。
     */
    fun weekLabels(weekCount: Int): List<Int?> =
        (1..weekCount).map { week ->
            if (ChartMath.heatmapShowWeekLabel(week, weekCount)) week else null
        }

    /** 第 [weekIndex] 列（0 基）的单元格左边缘 x（px）。 */
    fun cellLeft(weekIndex: Int, cellSizePx: Float, gapPx: Float): Float =
        weekIndex * (cellSizePx + gapPx)

    /** 第 [dayIndex] 行（0=周一）的单元格顶部 y（px）。 */
    fun cellTop(dayIndex: Int, cellSizePx: Float, gapPx: Float): Float =
        dayIndex * (cellSizePx + gapPx)

    /** 网格总宽（px）。 */
    fun gridWidth(weekCount: Int, cellSizePx: Float, gapPx: Float): Float =
        if (weekCount <= 0) 0f else weekCount * cellSizePx + (weekCount - 1) * gapPx

    /** 网格总高（px）。 */
    fun gridHeight(cellSizePx: Float, gapPx: Float): Float = 7 * cellSizePx + 6 * gapPx

    /** 星期短名（一~日，越界空串）。 */
    fun weekdayLabel(dayIndex: Int): String = ChartsStrings.weekdayShort(dayIndex + 1)
}
