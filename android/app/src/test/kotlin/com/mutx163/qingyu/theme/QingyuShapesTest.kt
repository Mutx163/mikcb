package com.mutx163.qingyu.theme

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 圆角 + 尺寸常量测试。
 *
 * Dart 源：`lib/ui/hyperos/hyperos_miuix_spec.dart`（`HyperosMiuixButton :299-309`、
 * `HyperosMiuixCard :315-319`、`HyperosMiuixDialog :521-539` 等）、
 * `lib/ui/hyperos/hyperos_tokens.dart:40-87`、
 * `lib/ui/hyperos/hyperos_radius.dart:13-56`（钳制公式）。
 *
 * 注意：准备文档 §2.3 把控件圆角写成 10，实读 `HyperosMiuixButton.cornerRadius`
 * 为 16.0（`:302`），此处以实读为准，文档差一处备注。
 */
class QingyuShapesTest {

    @Test fun `设置组与控件圆角常量`() {
        assertEquals(24.0, QingyuShapes.SETTINGS_GROUP_RADIUS, 0.0)
        assertEquals(16.0, QingyuShapes.CONTROL_RADIUS, 0.0)
        assertEquals(40.0, QingyuShapes.CONTROL_MIN_HEIGHT, 0.0)
        assertEquals(58.0, QingyuShapes.CONTROL_MIN_WIDTH, 0.0)
    }

    @Test fun `逐组件圆角常量`() {
        assertEquals(16.0, QingyuShapes.CARD_CORNER, 0.0)
        assertEquals(16.0, QingyuShapes.CARD_GROUP_GAP, 0.0)
        assertEquals(24.0, QingyuShapes.DIALOG_INSIDE_HORIZONTAL, 0.0)
        assertEquals(24.0, QingyuShapes.DIALOG_INSIDE_VERTICAL, 0.0)
        assertEquals(420.0, QingyuShapes.DIALOG_MAX_WIDTH, 0.0)
        assertEquals(32.0, QingyuShapes.DIALOG_MIN_BOTTOM_CORNER, 0.0)
        assertEquals(20.0, QingyuShapes.POPUP_CORNER, 0.0)
        assertEquals(12.0, QingyuShapes.TAB_CORNER, 0.0)
        assertEquals(8.0, QingyuShapes.TAB_CONTOUR_CORNER, 0.0)
        assertEquals(50.0, QingyuShapes.FLOATING_TOOLBAR_CORNER, 0.0)
        assertEquals(40.0, QingyuShapes.ICON_BUTTON_CORNER, 0.0)
        assertEquals(16.0, QingyuShapes.SNACKBAR_CORNER, 0.0)
        assertEquals(0.75, QingyuShapes.DIVIDER_THICKNESS, 0.0)
    }

    @Test fun `行内尺寸常量`() {
        assertEquals(56.0, QingyuShapes.LIST_ROW_MIN_HEIGHT, 0.0)
        assertEquals(72.0, QingyuShapes.LIST_ROW_TWO_LINE_MIN_HEIGHT, 0.0)
        assertEquals(16.0, QingyuShapes.ROW_PADDING_HORIZONTAL, 0.0)
        assertEquals(13.0, QingyuShapes.ROW_PADDING_VERTICAL, 0.0)
        assertEquals(16.0, QingyuShapes.SECTION_LABEL_INSET, 0.0)
        assertEquals(12.0, QingyuShapes.SECTION_GAP, 0.0)
    }

    @Test fun `clamp未知高度原样返回`() {
        assertEquals(24.0, QingyuShapes.clampCornerRadius(24.0, 0.0), 0.0)
        assertEquals(24.0, QingyuShapes.clampCornerRadius(24.0, -5.0), 0.0)
        assertEquals(
            24.0,
            QingyuShapes.clampCornerRadius(24.0, Double.POSITIVE_INFINITY),
            0.0,
        )
    }

    @Test fun `clamp高面保留首选矮面压到上限`() {
        // 高面 200dp：24 < 200/2-6=94，原样。
        assertEquals(24.0, QingyuShapes.clampCornerRadius(24.0, 200.0), 0.0)
        // 矮面 30dp：上限 30/2-6=9，24 被压到 9。
        assertEquals(9.0, QingyuShapes.clampCornerRadius(24.0, 30.0), 0.0)
        // 病态矮面 8dp：上限 ≤0，退到几何极限 4。
        assertEquals(4.0, QingyuShapes.clampCornerRadius(24.0, 8.0), 0.0)
    }

    @Test fun `surfaceRadius短面取控件角高面取组角`() {
        // 短面 50dp（< 75.6）：首选 16，上限 19，原样 16。
        assertEquals(16.0, QingyuShapes.surfaceRadiusForHeight(50.0), 0.0)
        // 高面 200dp：首选 24，原样。
        assertEquals(24.0, QingyuShapes.surfaceRadiusForHeight(200.0), 0.0)
        // 高面可改首选：200dp + 首选 20 → 20。
        assertEquals(20.0, QingyuShapes.surfaceRadiusForHeight(200.0, 20.0), 0.0)
    }

    @Test fun `minHeight与chip`() {
        assertEquals(60.0, QingyuShapes.minHeightForRadius(24.0), 0.0)
        assertEquals(44.0, QingyuShapes.minHeightForRadius(16.0), 0.0)
        assertEquals(0.0, QingyuShapes.chipRadius(0.0), 0.0)
        // 26dp 方块 → 7dp Badge 比例。
        assertEquals(7.0, QingyuShapes.chipRadius(26.0), 1e-9)
    }
}
