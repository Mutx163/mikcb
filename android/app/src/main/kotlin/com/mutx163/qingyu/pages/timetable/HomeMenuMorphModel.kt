package com.mutx163.qingyu.pages.timetable

/**
 * 首页「更多」按钮 → 菜单面板的**容器变换**几何（纯函数，可走 JVM 单测）。
 *
 * ## 这是什么
 *
 * 「按钮」与「面板」不是两个东西：同一个节点按展开进度 `reveal` 从 40dp 圆钮
 * 长成 200dp 宽的面板。本对象只负责算「这一帧该多宽 / 多高 / 内容缩多少」，
 * 渲染层只把结果交给 `Modifier.size` / `graphicsLayer`，不重复推导。
 *
 * ## 数值口径
 *
 * | 量 | 值 | 理由 |
 * |---|---|---|
 * | 收起态直径 | 40dp | 与顶栏图标的命中尺寸同值，变形起止两帧与按钮严丝合缝 |
 * | 展开态宽度 | 200dp | 与官方弹出层同宽（`ListPopupDefaults.MinWidth`），菜单不会比原来的锚定弹层更窄 |
 * | 圆角 | 24dp | 面板态与 16dp 卡片同一族；40dp 时 24 已被钳到半宽，**自动成为正圆**，所以收起态不需要第二个形状 |
 *
 * ## 为什么允许超出 [0,1]
 *
 * 展开用弹簧，过冲是刻意的（读起来"弹一下"）。所以这里**不把进度钳死**在
 * 0..1：轻微过冲时宽度会略超 200dp、内容略放大，被面板裁掉一点，观感是"长过头
 * 再收回来"。只钳一个安全边界，避免负尺寸。
 */
object HomeMenuMorphModel {

    /** 收起态（= 触发按钮）的直径，dp。 */
    const val TRIGGER_DIAMETER_DP = 40f

    /** 展开态面板宽度，dp。 */
    const val PANEL_WIDTH_DP = 200f

    /** 面板圆角，dp。40dp 宽时会被形状自动钳成正圆。 */
    const val PANEL_CORNER_RADIUS_DP = 24f

    /** 面板玻璃的高斯半径，dp。与顶栏玻璃带 / 底栏玻璃坞同一量级。 */
    const val PANEL_BLUR_DP = 12f

    /** 边缘折射的作用带宽度，dp。 */
    const val PANEL_REFRACTION_BAND_DP = 16f

    /** 边缘折射的最大位移量，dp。 */
    const val PANEL_REFRACTION_AMOUNT_DP = 26f

    /**
     * 玻璃下面那层染色的不透明度。
     *
     * 0 = 全透，文字会被背景吃掉；1 = 实色，玻璃等于没有。0.62 是"能看清字、
     * 又看得出背景在动"的平衡点。
     */
    const val PANEL_GLASS_TINT_ALPHA = 0.62f

    /**
     * 内容开始显形的进度点：`reveal` 低于它时菜单文字完全不画。
     *
     * 0.3 与 [CONTENT_ALPHA_END] 一起给出 0.4 的淡入窗口 —— 容器先长大一截、
     * 内容再浮出来，否则文字会在 40dp 的小圆里挤成一团再展开。
     */
    const val CONTENT_ALPHA_START = 0.3f

    /** 内容完全显形的进度点。 */
    const val CONTENT_ALPHA_END = 0.7f

    /** 弹簧过冲的允许上界（防止布局拿到离谱的尺寸）。 */
    private const val REVEAL_UPPER = 1.2f

    /** 反向过冲的允许下界。 */
    private const val REVEAL_LOWER = -0.2f

    /** 进度归一：只防极端值，保留弹簧过冲。 */
    fun clampReveal(reveal: Float): Float = reveal.coerceIn(REVEAL_LOWER, REVEAL_UPPER)

    /** 这一帧的宽度（dp）。`reveal = 0` ⇒ 触发按钮直径，`reveal = 1` ⇒ 面板宽。 */
    fun widthDp(
        reveal: Float,
        triggerDp: Float = TRIGGER_DIAMETER_DP,
        panelDp: Float = PANEL_WIDTH_DP,
    ): Float = lerp(triggerDp, panelDp, clampReveal(reveal))

    /**
     * 这一帧的高度（px）。
     *
     * [contentHeightPx] 是菜单内容**按满宽**量出来的自然高度；进度为 0 时恒等于
     * 触发按钮直径 —— 所以收起态一定是个正圆，不受菜单有几行影响。
     */
    fun heightPx(
        reveal: Float,
        triggerPx: Float,
        contentHeightPx: Float,
    ): Float = lerp(triggerPx, contentHeightPx, clampReveal(reveal))

    /**
     * 菜单内容的等比缩放。
     *
     * 内容始终按 [panelWidthDp] 排版（不重新 measure，避免逐帧重排），再按
     * `当前宽 / 面板宽` 缩下去 —— 缩放中心在渲染层固定为右上角，与容器右缘对齐。
     */
    fun contentScale(width: Float, panelWidth: Float = PANEL_WIDTH_DP): Float =
        if (panelWidth <= 0f) 1f else (width / panelWidth).coerceIn(0f, 1f)

    /** 菜单内容的透明度：`[CONTENT_ALPHA_START, CONTENT_ALPHA_END]` 之间线性淡入。 */
    fun contentAlpha(reveal: Float): Float {
        val span = CONTENT_ALPHA_END - CONTENT_ALPHA_START
        if (span <= 0f) return if (reveal >= CONTENT_ALPHA_END) 1f else 0f
        return ((reveal - CONTENT_ALPHA_START) / span).coerceIn(0f, 1f)
    }

    private fun lerp(start: Float, stop: Float, fraction: Float): Float =
        start + (stop - start) * fraction
}
