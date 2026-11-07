package com.mutx163.qingyu

/**
 * 「这条通知实际会不会上岛」的**纯逻辑判据**（零 Android 依赖，可 JVM 直测）。
 *
 * 2026-11-06 第四轮返工抽出来：之前这段判定写在 `LiveUpdateService` 的私有方法里、
 * 调 `Build.VERSION` / `NotificationManager` / `SharedPreferences`，**没有行为测试**，
 * 小米误伤与开关架空都是这样漏过去的。现在输入全部改成参数，三档（小米 / 开关关 /
 * 渠道关）都能直接断言。
 *
 * ## 判据顺序（与项目诊断页 `isActuallyPromotable` 对齐）
 *
 * 1. 状态栏上课模式 / 用户没要求 promote ⇒ 不上岛；
 * 2. 应用级或渠道级通知被关 ⇒ `notify()` 会被系统静默丢弃 ⇒ 不上岛；
 * 3. **小米 / Redmi / POCO**：HyperOS 焦点通知由 `miui.focus.param` 决定，**不看 SDK**
 *    ⇒ 视为会上岛（保守上界：宁可少省电，也不许冻结岛内逐秒文本）；
 * 4. Android 16+ 通用 promoted：`SDK>=36 && 系统授权` 才会上岛。
 */
internal object PromotedFormPolicy {

    fun isPromotedFormActive(
        stage: String?,
        shouldPromote: Boolean,
        isXiaomiFamily: Boolean,
        sdkInt: Int,
        notificationsAllowed: Boolean,
        channelEnabled: Boolean,
        canPostPromoted: Boolean,
    ): Boolean {
        if (stage == "duringClassStatusBar" || !shouldPromote) return false
        if (!notificationsAllowed || !channelEnabled) return false
        // 小米：miui.focus.param 上岛不看 SDK。
        if (isXiaomiFamily) return true
        // Android 16+ 通用 promoted。
        return sdkInt >= 36 && canPostPromoted
    }
}
