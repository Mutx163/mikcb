package com.mutx163.qingyu.pages.timetable

/**
 * 截屏「分享课表图」提示的纯判定（零 Android 导入，JVM 单测钉住）。
 *
 * 对位 Dart `timetable_screen.dart` 的 `_onScreenshotDetected()`（:939-963）：
 * 检测到截屏后浮一条「要分享干净的课表图吗」胶囊，但有**三道门**，缺一不弹——
 *
 * 1. **设置开关**（Dart `settings.screenshotSharePromptEnabled`，:918）；
 * 2. **本页盖在最上面**（Dart `ModalRoute.of(context)?.isCurrent`，:943）——
 *    去设置页等二级页截屏，跟「分享课表图」的意图对不上；
 * 3. **冷却期**（Dart `_screenshotPromptCooldown` = 6 秒，:187）——连拍截屏不叠提示。
 *
 * 纯函数只回答「这一张截屏要不要弹」；「弹过要记账」由调用方在返回 true 后
 * 把 [nowMillis] 存为上次弹出时刻（Dart :952 同一顺序，先记账再弹）。
 */
object ScreenshotSharePromptGate {

    /**
     * 冷却期：上次弹出后多久内不再弹。
     * Dart `_screenshotPromptCooldown = Duration(seconds: 6)`（`timetable_screen.dart:187`）。
     */
    const val COOLDOWN_MILLIS = 6_000L

    /**
     * 提示本体的自动消失时长。
     * Dart `_screenshotPromptDuration = Duration(seconds: 5)`（`timetable_screen.dart:193`）。
     */
    const val PROMPT_DURATION_MILLIS = 5_000L

    /**
     * 这一张截屏要不要弹提示。
     *
     * @param enabled 设置开关（用户存档 `screenshotSharePromptEnabled`）。
     * @param topMost 提示宿主所在的导航条目此刻是否盖在最上面
     *   （Compose 侧判据：miuix-nav 条目级 `LifecycleOwner` 处于 RESUMED；
     *   被推入页覆盖时是 STARTED）。
     * @param lastPromptAtMillis 上次弹出的时刻（`elapsedRealtime` 口径）；
     *   还从没弹过传 null。
     * @param nowMillis 当前时刻（与 [lastPromptAtMillis] 同一时钟）。
     */
    fun shouldShow(
        enabled: Boolean,
        topMost: Boolean,
        lastPromptAtMillis: Long?,
        nowMillis: Long,
    ): Boolean {
        if (!enabled) return false
        if (!topMost) return false
        val last = lastPromptAtMillis ?: return true
        // Dart :948-951：`now.difference(last) < cooldown` 才拦；正好到点（==）放行。
        return nowMillis - last >= COOLDOWN_MILLIS
    }
}
