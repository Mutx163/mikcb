package com.mutx163.qingyu

/**
 * 桌面小部件「每分钟心跳」的**纯逻辑判定**（无 Android 依赖，可 JVM 直测）。
 *
 * ## 为什么需要它
 *
 * 用户实测：上课日约 700 次精确唤醒/天，全部来自倒计时重绘。倒计时可见时，
 * 卡片上的「还有 N 分钟」只能靠每分钟重排一次闹钟推进 —— 这是**用户选择**的代价，
 * 不是所有人都需要。
 *
 * 所以刷新档位与「是否显示倒计时」这一个开关绑定：
 * - 关闭（默认）：不排每分钟心跳，卡片只在上课/下课/零点这些边界重绘，
 *   其余靠 15 分钟 WorkManager 兜底 —— 与同类开源课表 App 同档；
 * - 打开：保留每分钟心跳（现状），并在设置项上明示耗电代价。
 *
 * 时间点计算（[TodayWidgetSupport.findNextRefreshAtMillis]）必须走这里，
 * 不许再各自写一份 `showCountdown && state == ...`，否则设置页关掉开关、
 * 闹钟却照排，就又回到「用户没要、电照耗」的老问题。
 */
internal object WidgetRefreshPolicy {

    /** 倒计时可见的两个状态：正在上课、即将上课。 */
    private val COUNTDOWN_STATES = setOf("ongoing", "upcoming")

    /**
     * 是否要排「每 60 秒一次」的心跳刷新。
     *
     * @param showCountdown 用户是否打开「显示倒计时」（默认关闭 = 省电档）。
     * @param state 当前卡片状态（`ongoing` / `upcoming` / 其它）。
     * @return true = 需要每分钟重绘一次；false = 只在边界刷新。
     */
    fun shouldScheduleMinuteHeartbeat(showCountdown: Boolean, state: String): Boolean =
        showCountdown && state in COUNTDOWN_STATES
}
