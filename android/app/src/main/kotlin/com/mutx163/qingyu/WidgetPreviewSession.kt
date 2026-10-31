package com.mutx163.qingyu

import org.json.JSONObject

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
 * 3. **设置 JSON**（2026-10-31 F20-B）：卡片渲染读的是 active profile 内嵌的
 *    `settings`（[TodayWidgetSupport.buildSnapshotFromFlutterState]；
 *    [StatsWidgetSupport.readChrome] 同理）。设置页刚改完、还没落盘同步进 profile 时，
 *    预览就会显示上一档的圆角/背景/显示项——表现为「改了没反应」。所以预览把
 *    **页面上正在编辑的那份设置**随会话传进来，渲染期间覆盖 profile 的 settings。
 *
 * 用 ThreadLocal 而不是进程级变量：预览渲染在一线程里同步走完（拿视图 → 测 → 画 →
 * 编 PNG），不存在跨线程共享；而真实下发走的是正数 appWidgetId，两条路径的线程
 * 也可能重叠（WidgetRefreshWorker），用 ThreadLocal 天然隔离，谁都不会读到别人的档位。
 *
 * ⚠️ 渲染本身可能跑在**非主线程**：Flutter 通道那条路把出图丢进
 * `widgetPreviewExecutor`（`MainActivity`），Compose 侧同样丢进 IO 调度器。
 * 只要 inflate / measure / layout / draw 都在**同一个线程**里完成就成立
 * （View 没 attach 到窗口，不会碰主线程的 ViewRootImpl），ThreadLocal 也正因此才合适。
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
        /** 宿主给的设置 JSON（`timetable_settings` 全量键）；null = 不覆盖。 */
        val settingsJson: String?,
    )

    private val current = ThreadLocal<Spec?>()

    /** 非 null 表示正处在预览会话里；`Pair(宽, 高)`，单位 dp。 */
    val sizeOverride: Pair<Int, Int>?
        get() = current.get()?.let { it.widthDp to it.heightDp }

    /** 非 null 表示正处在预览会话里，取调用方给定的明暗。 */
    val nightModeOverride: Boolean?
        get() = current.get()?.nightMode

    /** 是否正处在预览会话里（真实下发路径为 false）。 */
    val isActive: Boolean
        get() = current.get() != null

    /**
     * 宿主给的设置 JSON 原文；null = 当前没有覆盖（真实下发 / Flutter 通道的旧调用点）。
     *
     * 只给「设置页正在编辑的那份设置」用：它比 profile 里内嵌的 `settings` 新，
     * 也可能含只有设置页才知道的键（圆角、背景、显示项）。
     */
    val settingsJsonOverride: String?
        get() = current.get()?.settingsJson

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

    fun <T> run(
        widthDp: Int,
        heightDp: Int,
        nightMode: Boolean,
        settingsJson: String? = null,
        block: () -> T,
    ): T {
        val previous = current.get()
        // 设置 JSON 允许「继承」而不是被内层清空：预览分两层进会话——
        // 外层 [WidgetPreviewRenderer.render] 带着宿主的设置进来，内层
        // [BaseQingyuWidgetProvider.buildPreviewRemoteViews] 只重复尺寸与明暗、
        // 不传设置。若这里直接把它置 null，覆盖会在真正渲染的那一刻恰好失效。
        current.set(Spec(widthDp, heightDp, nightMode, settingsJson ?: previous?.settingsJson))
        try {
            return block()
        } finally {
            // 恢复而不是清空：预览若要嵌套（例如以后做「一次渲染多张」），
            // 内层退出后外层仍然有效。
            current.set(previous)
        }
    }

    /**
     * 把会话里的设置覆盖**合并**到 [base]（profile 内嵌的 `settings`）上，返回新对象。
     *
     * 为什么是合并而不是整份替换：设置页只序列化「本页 10 组外观键」，而快照构建
     * 还会读 `enableHolidayMarking` / `holidayOverrideEnabled` / `semesterWeekCount`
     * 等别的页面的键。整份替换会把这些一起回落成默认值——预览里今天突然变成
     * 「节假日」或者学期周数跳回 20，都是这条引起的。
     *
     * 返回副本而不是就地改 [base]：`profile` 可能是调用方传进来的 JSONObject
     * （[TodayWidgetSupport.buildSnapshotFromFlutterState] 的 `profileJson` 参数），
     * 就地写会污染调用方的对象，后面再读就是被预览改过的值。
     */
    fun mergedSettings(base: JSONObject?): JSONObject {
        val merged = JSONObject()
        base?.let { copyInto(merged, it) }
        val overrideText = settingsJsonOverride ?: return merged
        val override = runCatching { JSONObject(overrideText) }.getOrNull() ?: return merged
        copyInto(merged, override)
        return merged
    }

    private fun copyInto(target: JSONObject, source: JSONObject) {
        val keys = source.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            // 单个键写失败（例如 JSON 里塞了非法值）不该让整份设置消失：
            // 跳过它、其余键照常覆盖。
            runCatching { target.put(key, source.get(key)) }
        }
    }
}
