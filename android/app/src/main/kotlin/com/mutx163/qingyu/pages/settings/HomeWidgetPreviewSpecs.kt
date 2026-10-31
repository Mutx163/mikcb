package com.mutx163.qingyu.pages.settings

/**
 * 桌面小组件「效果预览」轮播里一张卡片的**格位尺寸**。
 *
 * 与 Dart `HomeWidgetPreviewSpec`（`lib/services/home_widget_service.dart:39-57`）一一对应：
 * [targetId] 是 `HomeWidgetPinTarget.value`，[cellWidth] / [cellHeight] 是「横向 / 纵向跨几格」，
 * [widthDp] / [heightDp] 是按当前屏宽换算出的**格位**尺寸（不是卡片背景的可见尺寸）。
 *
 * 为什么要按屏宽换算、而不是直接读 `widget_*_info.xml` 的 `minWidth` / `minHeight`：
 * 那是 Android 4.x 时代的「最小可用尺寸」，现代启动器实际分配的是
 * 「跨几格 × 单格宽 + 格间距」，按 110dp 渲染会整整小一圈，连字号档都会被选错
 * （卡片渲染里的 `isShort` / `isWide` / `isNarrow` 全由宽高决定）。
 */
data class HomeWidgetPreviewSpec(
    val targetId: String,
    val cellWidth: Int,
    val cellHeight: Int,
    val widthDp: Double,
    val heightDp: Double,
)

/**
 * 按屏幕逻辑宽度推算每张预览卡片在桌面上占的格位尺寸。
 *
 * 逐行搬运 Dart `buildHomeWidgetPreviewSpecs`（`lib/services/home_widget_service.dart:96-126`）：
 *
 * - 单格 = (屏宽 − 左右各 20dp 留白 − 8dp ×(4−1)) / 4 列；
 * - 极窄屏兜底：单格不小于 56dp（再小就压到看不出内容）；
 * - 跨 n 格 = n × 单格 + (n−1) × 格间距，横纵同理；
 * - **保留 Double 不取整**——尺寸行显示时才 `round()`（`SettingsHomeWidgetPage.sizeLabel`）。
 *
 * 顺序与 Dart 列表**逐项一致**：今日课程系（含两种横条与宽卡）→ 统计系 → 考试卡；
 * 相邻两张格位接近，左右滑动时大小变化连续，不会忽大忽小。
 * 只影响预览的物理尺寸感，不参与任何渲染判断。
 */
object HomeWidgetPreviewSpecs {

    /** 屏幕左右留白（Dart `_kDesktopSideInsetDp`，`home_widget_service.dart:63`）。 */
    const val DESKTOP_SIDE_INSET_DP = 20.0

    /** 桌面网格格间距（Dart `_kDesktopCellGapDp`，`:64`）。 */
    const val DESKTOP_CELL_GAP_DP = 8.0

    /** 桌面网格列数（Dart `_kDesktopColumns`，`:65`）。 */
    const val DESKTOP_COLUMNS = 4

    /** 极窄屏的单格下限（Dart 的 `rawCell < 56 ? 56.0`，`:104-106`）。 */
    const val MIN_CELL_DP = 56.0

    /**
     * 屏宽（dp）→ 十张卡片的格位尺寸，顺序见类注释。
     *
     * @param screenWidthDp 屏幕**逻辑**宽度（`LocalConfiguration.screenWidthDp` 那一路的值）。
     */
    fun build(screenWidthDp: Double): List<HomeWidgetPreviewSpec> {
        val usable = screenWidthDp - DESKTOP_SIDE_INSET_DP * 2
        val rawCell =
            (usable - DESKTOP_CELL_GAP_DP * (DESKTOP_COLUMNS - 1)) / DESKTOP_COLUMNS
        val cell = if (rawCell < MIN_CELL_DP) MIN_CELL_DP else rawCell

        fun span(cells: Int): Double =
            cells * cell + (cells - 1) * DESKTOP_CELL_GAP_DP

        fun spec(targetId: String, w: Int, h: Int): HomeWidgetPreviewSpec =
            HomeWidgetPreviewSpec(
                targetId = targetId,
                cellWidth = w,
                cellHeight = h,
                widthDp = span(w),
                heightDp = span(h),
            )

        return listOf(
            spec("compact", 2, 2),
            spec("mini_list", 2, 2),
            spec("medium", 2, 4),
            spec("large", 4, 4),
            spec("today_strip", 4, 1),
            spec("today_wide", 4, 2),
            spec("stats_compact", 2, 2),
            spec("stats_medium", 2, 4),
            spec("stats_strip", 4, 1),
            spec("exam_card", 2, 2),
        )
    }
}
