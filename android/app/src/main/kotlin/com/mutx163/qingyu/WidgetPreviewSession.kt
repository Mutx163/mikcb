package com.mutx163.qingyu

/**
 * 设置页「效果预览」的渲染会话。
 *
 * 预览复用卡片真实的 [BaseQingyuWidgetProvider.buildRemoteViews]，但有两个输入
 * 在真实下发时由系统给、预览时没有：
 *
 * 1. **格位尺寸**：[TodayWidgetSupport.sizeProfile] 平时读
 *    `AppWidgetManager.getAppWidgetOptions(id)`；预览没有 id，用设置页给的目标 dp 覆盖。
 *    这一点必须一致——`isShort` / `isWide` / `isNarrow` 直接决定字号档与自适应内边距，
 *    尺寸档错了预览就会"看起来差不多、细节全不对"。
 * 2. **明暗**：[TodayWidgetSupport.isDarkMode] 平时按系统 UiModeManager 的当下档算，
 *    因为桌面卡片底色是系统按 drawable-night 解析的。但在 App 内预览时，用户看的是
 *    *应用自己的* 背景色，App 设了「强制深色」而系统是浅色时两者会打架：
 *    预览底色走 override 的 -night 资源、字色却仍按系统浅色算，会出「深底深字」。
 *    所以预览显式透传 App 当前明暗，资源解析与字色判断同源。
 *
 * 用 ThreadLocal 而不是进程级变量：预览渲染在 UI 线程同步走完（拿视图 → 测 → 画 →
 * 编 PNG），不存在跨线程共享；而真实下发走的是正数 appWidgetId，两条路径的线程
 * 也可能重叠（WidgetRefreshWorker），用 ThreadLocal 天然隔离，谁都不会读到别人的档位。
 */
internal object WidgetPreviewSession {

    /**
     * 预览专用 appWidgetId。
     *
     * 取 `INVALID_APPWIDGET_ID`（0）：它不是任何真实卡片，`WidgetBindingStore`
     * 查不到绑定，`HomeWidgetStorage` 也没有它的专属快照，所以预览读出来的是
     * 「跟随当前课表」——和用户刚把卡片放到桌面、还没单独绑定课表时的效果一致。
     */
    const val PREVIEW_APP_WIDGET_ID = 0

    private class Spec(
        val widthDp: Int,
        val heightDp: Int,
        val nightMode: Boolean,
    )

    private val current = ThreadLocal<Spec?>()

    /** 非 null 表示正处在预览会话里；`Pair(宽, 高)`，单位 dp。 */
    val sizeOverride: Pair<Int, Int>?
        get() = current.get()?.let { it.widthDp to it.heightDp }

    /** 非 null 表示正处在预览会话里，取调用方给定的明暗。 */
    val nightModeOverride: Boolean?
        get() = current.get()?.nightMode

    /**
     * 预览里让卡片铺满整个格位，跳过那圈垂直内边距。
     *
     * 桌面上的卡片会留它（`applyAdaptiveVerticalPadding` 给 `widget_root` 加 padding，
     * 子 View `widget_card` 跟着缩进），于是 2×2 的格位是方的、卡片背景却是扁的。
     * 有壁纸衬托时那圈留白很自然，但预览贴在纯色页面上就特别扎眼，
     * 用户会一直觉得「预览是扁的」。
     *
     * 只在**预览会话内**跳过，桌面下发路径的 `current` 为 null，行为完全不变。
     */
    val fillCell: Boolean
        get() = current.get() != null

    fun <T> run(widthDp: Int, heightDp: Int, nightMode: Boolean, block: () -> T): T {
        val previous = current.get()
        current.set(Spec(widthDp, heightDp, nightMode))
        try {
            return block()
        } finally {
            // 恢复而不是清空：预览若要嵌套（例如以后做「一次渲染多张」），
            // 内层退出后外层仍然有效。
            current.set(previous)
        }
    }
}
