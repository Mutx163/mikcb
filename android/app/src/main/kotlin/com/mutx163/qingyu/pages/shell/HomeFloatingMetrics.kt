package com.mutx163.qingyu.pages.shell

/**
 * 首页**浮钮**（周视图「回本周」/ 日视图「回今日」）与**玻璃坞**之间的底部几何。
 *
 * ## 补的是哪一类事故
 *
 * 两颗浮钮原先各自写了一个魔法数（周视图 `72dp`、日视图 `20dp`），都不认识底栏：
 * 玻璃坞药丸的真实占用是「底部内边距（8 + 系统导航栏）**或** 无导航栏时的 36，
 * 再加药丸高 54」—— 手势导航下就是 **86dp**。于是 `72dp` 落在药丸里、`20dp` 更是
 * 贴着屏幕底，两者都被底栏盖住。
 *
 * 判据抄 Dart：`timetable_back_to_current_week_button.dart` 的
 * `max(24, glassDockPillOccupancy + 12) + viewPadding.bottom`、
 * `_backToTodayButtonBottomInset` 的同一式子，以及 `_glassDockContentScrollInset`
 * 的「内容避让 = 药丸占用」。
 *
 * ## 为什么是纯算术
 *
 * 药丸高度来自 [GlassDockGeometry.HeightDp]，底部内边距的来源是
 * `GlassDockNavigationBar` 里那三行；这里做成纯对象，既有单测钉住，也能让
 * **底栏自己**改成调它 —— 一处改，两边跟着变。
 */
object HomeFloatingMetrics {

    /** 浮钮与药丸之间的视觉间隙（Dart `_backToTodayButtonDockGap`，回本周那边同值 12）。 */
    const val DOCK_GAP_DP = 12f

    /** 经典底栏形态下，浮钮距屏幕底部的边距（Dart `_backToTodayButtonClassicMargin`）。 */
    const val CLASSIC_MARGIN_DP = 24f

    /**
     * 玻璃坞药丸的底部内边距。
     *
     * 与 `GlassDockNavigationBar` 的 `padding(bottom = ...)` **逐值同源**：
     * 有系统导航栏内边距时 = 8 + 内边距；没有时（三键 / 无栏设备）= 36。
     */
    fun dockBottomPaddingDp(navigationBarBottomInsetDp: Float): Float =
        if (navigationBarBottomInsetDp > 0f) 8f + navigationBarBottomInsetDp else 36f

    /**
     * 药丸从屏幕底端起的总占用 = 底部内边距 + 药丸高度。
     *
     * **已经含系统导航栏内边距**，所以调用方不要再额外加一次 inset。
     */
    fun dockPillOccupancyDp(navigationBarBottomInsetDp: Float): Float =
        dockBottomPaddingDp(navigationBarBottomInsetDp) + GlassDockGeometry.HeightDp

    /**
     * 浮钮底边距（从屏幕底端起，已含系统内边距）。
     *
     * - 玻璃坞形态 = 药丸占用 + 12（浮在药丸之上）；
     * - 经典形态 = 24 + 系统底内边距（没有坞，只让开系统手势条）。
     */
    fun floatingButtonBottomDp(
        glassDock: Boolean,
        navigationBarBottomInsetDp: Float,
    ): Float = if (glassDock) {
        dockPillOccupancyDp(navigationBarBottomInsetDp) + DOCK_GAP_DP
    } else {
        CLASSIC_MARGIN_DP + navigationBarBottomInsetDp
    }

    /**
     * 可滚动内容的底部避让（从屏幕底端起，已含系统内边距）。
     *
     * 玻璃坞形态下内容要能滚到药丸上方（Dart `_glassDockContentScrollInset`）；
     * 经典形态只让开系统手势条。
     */
    fun contentBottomDp(
        glassDock: Boolean,
        navigationBarBottomInsetDp: Float,
    ): Float = if (glassDock) {
        dockPillOccupancyDp(navigationBarBottomInsetDp)
    } else {
        navigationBarBottomInsetDp
    }

    /**
     * 日视图列表给「回今日」浮钮额外让出的高度：钮高 + 一个视觉间隙。
     *
     * Dart `_backToTodayButtonScrollInset` 把「浮钮顶边 + 间隙」减去坞避让，
     * 再叠在坞避让之上 —— 净效果就是这一条。钮不显示时不要加（不为一颗看不见的
     * 按钮白留空白）。
     *
     * 2026-11-03 钮重做成 miuix 官方 `FloatingActionButton`：默认 60dp（原 38dp
     * 磨砂胶囊），这里跟着钮的真实高度走，否则最后一张卡滚不到钮的上方。
     */
    const val BACK_TO_TODAY_SCROLL_EXTRA_DP = 60f + DOCK_GAP_DP
}
