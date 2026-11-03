package com.mutx163.qingyu.core

/**
 * 预览挖洞件的纯几何（零 Android / Compose 依赖，JVM 单测直接覆盖）。
 *
 * 挖洞预览的口径（与外观编辑页 `AppearanceEditorPreviewStage` 同一套）：
 * 真实内容按**内容设计尺寸** 1:1 排版，绘制层按「窗口宽 / 内容宽」的比缩进窗口——
 * 缩放只发生在 `graphicsLayer`，不改子树任何一次 measure/layout。
 *
 * 这里只放算术；Compose 接线在 `components/QingyuPreviewCutout.kt`。
 */
object PreviewCutoutGeometry {

    /**
     * 宽贴合缩放比：窗口宽 / 内容设计宽。
     *
     * 非法输入（非正数、非有限值，如父约束无界时 `maxWidth` 为无穷）一律退 1f——
     * 宁可原尺寸显示，也不按无穷比把内容画没了。
     */
    fun scale(windowWidthPx: Float, contentWidthPx: Float): Float {
        if (!windowWidthPx.isFinite() || !contentWidthPx.isFinite()) return 1f
        if (windowWidthPx <= 0f || contentWidthPx <= 0f) return 1f
        return windowWidthPx / contentWidthPx
    }

    /**
     * 缩放后的内容高：窗口内**可滚动的内容总高**（滚动范围 = 它 − 窗口高）。
     *
     * 非法输入退 0f：范围为零时窗口自然滚不动，与「没有可看的内容」语义一致。
     */
    fun scaledContentHeight(contentHeightPx: Float, scale: Float): Float {
        if (!contentHeightPx.isFinite() || !scale.isFinite()) return 0f
        if (contentHeightPx <= 0f || scale <= 0f) return 0f
        return contentHeightPx * scale
    }
}
