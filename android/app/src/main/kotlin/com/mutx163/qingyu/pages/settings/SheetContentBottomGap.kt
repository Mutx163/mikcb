package com.mutx163.qingyu.pages.settings

/**
 * 弹层滚动内容的**底部留白判据**（纯函数，JVM 可直接测）。
 *
 * ## 为什么需要一条独立判据
 *
 * 官方弹层（`QingyuSheet` / miuix `OverlayBottomSheet`）在面板外已经做了 `imePadding`：
 * 键盘一弹出，整个面板被抬到键盘上方，面板底边与键盘之间**不再有系统手势区**。
 * 正文若仍按「导航栏高度 + 16dp 呼吸」垫底，就会多出一截 24~48dp 的空白
 *（2026-11-03 用户实报「键盘弹出多一截空白」；套件本身已在 `QingyuSheet` 修过）。
 *
 * 正文侧必须读同一个判据，不能各自写一遍 —— 写两遍就一定会有一处漏掉。
 *
 * ## 口径
 *
 * - 键盘**可见**：只留 [CONTENT_BOTTOM_GAP_DP]；
 * - 键盘**收起**：导航栏高度 + [CONTENT_BOTTOM_GAP_DP]（手势导航与三键导航都按系统给的
 *   实际值算，不写死 24 / 48）。
 */
object SheetContentBottomGap {

    /**
     * 手势区 / 导航栏之外那一截呼吸。
     *
     * = Dart `hyperosMiuixBottomSheetContentBottomGap`（16），与
     * `QingyuSheetDefaults.ContentBottomGap` 同值；这里放一份纯 Kotlin 副本，
     * 是为了让模型层单测不依赖 Compose。
     */
    const val CONTENT_BOTTOM_GAP_DP: Float = 16f

    /**
     * 键盘是否可见。
     *
     * 输入是 `WindowInsets.ime.getBottom(density)` 的像素值：Android 侧 IME inset > 0
     * 即视为弹出（与 `QingyuSheet` 的判据逐字一致）。
     */
    fun isImeVisible(imeBottomPx: Int): Boolean = imeBottomPx > 0

    /**
     * 底部留白（dp）= 呼吸 +（键盘收起时的）导航栏高度。
     *
     * @param imeVisible 键盘是否可见（用 [isImeVisible] 从像素值换算）。
     * @param navigationBarBottomDp `WindowInsets.navigationBars` 的底部高度；手势导航与
     *   三键导航由系统给实际值，这里不区分、也不夹取。
     */
    fun bottomGapDp(imeVisible: Boolean, navigationBarBottomDp: Float): Float =
        CONTENT_BOTTOM_GAP_DP + if (imeVisible) 0f else navigationBarBottomDp
}
