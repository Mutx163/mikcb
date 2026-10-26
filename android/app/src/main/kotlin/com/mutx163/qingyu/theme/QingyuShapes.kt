package com.mutx163.qingyu.theme

/**
 * 圆角与尺寸常量（逐组件搬运，无全局 token）。
 *
 * 选型口径：`docs/plans/2026-10-26-compose-miuix-components.md:23`
 *（圆角无全局 token、逐组件 `cornerRadius`）。
 * Dart 源：`hyperos_miuix_spec.dart`（Button `:299-309`、Card `:315-319`、
 * Dialog `:521-539`、Dropdown `:623`、TabRow `:576-591` 等）+
 * `hyperos_tokens.dart:40-87` + 钳制公式 `hyperos_radius.dart:13-56`。
 *
 * 注意：准备文档 §2.3 把控件圆角写成 10，实读
 * `HyperosMiuixButton.cornerRadius` 为 **16.0**（`:302`），此处以实读为准。
 */
object QingyuShapes {
    /** 设置组卡片（`settingsGroupRadius`，高面 squircle）。 */
    const val SETTINGS_GROUP_RADIUS = 24.0

    /** 紧凑控件（按钮/输入框/嵌套选择器，配 [CONTROL_MIN_HEIGHT] 使侧壁保直）。 */
    const val CONTROL_RADIUS = 16.0
    const val CONTROL_MIN_HEIGHT = 40.0
    const val CONTROL_MIN_WIDTH = 58.0

    const val CARD_CORNER = 16.0
    const val CARD_GROUP_GAP = 16.0

    const val DIALOG_INSIDE_HORIZONTAL = 24.0
    const val DIALOG_INSIDE_VERTICAL = 24.0
    const val DIALOG_MAX_WIDTH = 420.0
    const val DIALOG_MIN_BOTTOM_CORNER = 32.0

    /** 下拉弹层圆角（形状规范，三种材质共用，不随材质变）。 */
    const val POPUP_CORNER = 20.0

    const val TAB_CORNER = 12.0
    const val TAB_CONTOUR_CORNER = 8.0

    const val FLOATING_TOOLBAR_CORNER = 50.0
    const val ICON_BUTTON_CORNER = 40.0

    const val SNACKBAR_CORNER = 16.0
    const val SNACKBAR_ACTION_CORNER = 50.0

    const val DIVIDER_THICKNESS = 0.75

    /** 浮层卡片内容内边距（sheet 上下左右均为 16）。 */
    const val SHEET_INSET = 16.0

    const val LIST_ROW_MIN_HEIGHT = 56.0
    const val LIST_ROW_TWO_LINE_MIN_HEIGHT = 72.0
    const val ROW_PADDING_HORIZONTAL = 16.0
    const val ROW_PADDING_VERTICAL = 13.0

    const val SECTION_LABEL_INSET = 16.0
    const val SECTION_GAP = 12.0

    const val NESTED_HEADER_TITLE = 20.0
    const val NESTED_HEADER_BACK_ICON = 24.0
    const val SEARCH_INPUT_MIN_HEIGHT = 45.0

    const val ICON_BADGE_SIZE = 26.0
    const val ICON_BADGE_RADIUS = 7.0

    /** 钳制后保留的最小平直边（上下弧不连成胶囊）。 */
    const val MIN_STRAIGHT_EDGE = 6.0

    /** 短面阈值（单行 56dp × 1.35 ≈ 75.6）。 */
    const val SHORT_SURFACE_THRESHOLD = 56.0 * 1.35

    /**
     * 钳制 [preferred] 使 `radius < height/2 - minStraightEdge`；
     * 高度未知/非正/非有限时原样返回；病态矮面退到几何极限 `height/2`。
     */
    fun clampCornerRadius(preferred: Double, height: Double): Double {
        if (height <= 0 || !height.isFinite()) return preferred
        val maxRadius = height / 2 - MIN_STRAIGHT_EDGE
        if (maxRadius <= 0) return height / 2
        if (preferred <= maxRadius) return preferred
        return maxRadius
    }

    /**
     * 按实测高度选首选圆角再钳制：短面取控件角、 tall 面取 [preferred]
     *（默认设置组角）。
     */
    fun surfaceRadiusForHeight(height: Double, preferred: Double? = null): Double {
        val tallPreferred = preferred ?: SETTINGS_GROUP_RADIUS
        val chosen =
            if (height > 0 && height < SHORT_SURFACE_THRESHOLD) CONTROL_RADIUS
            else tallPreferred
        return clampCornerRadius(chosen, height)
    }

    /** 容纳 [radius] 而不塌成胶囊的最小高度。 */
    fun minHeightForRadius(radius: Double): Double = radius * 2 + MIN_STRAIGHT_EDGE * 2

    /** 方形徽标圆角（图标 Badge 比例 7/26）。 */
    fun chipRadius(size: Double): Double {
        if (size <= 0) return 0.0
        val proportional = size * ICON_BADGE_RADIUS / ICON_BADGE_SIZE
        return clampCornerRadius(proportional, size)
    }
}
