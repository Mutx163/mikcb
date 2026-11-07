package com.mutx163.qingyu

/**
 * 一条通知的「chrome 决策」：只决定 `setShowWhen`。
 *
 * ## 为什么没有 chronometer 字段了（2026-11-06 第四轮返工，方案已撤）
 *
 * 上一版让标准通知用系统 chronometer 走字、正文只留静态前缀。复核判**高风险**，
 * 两条硬伤：
 * 1. **悬空句**：前缀单独成句（中文只剩「距上课」、英文只剩 "Starts in "），数字被搬到
 *    `when` 区右上角，话说一半；
 * 2. **架空用户设置**：`chromeFor` 不看 `showCountdown` / `hidePrefixText`，而前缀在这
 *    两项关闭时返回空串 ⇒ 用户明明关掉了倒计时显示，通知里仍会出现倒计时数字。
 *
 * 新方案（对齐发布版真实形态）：**标准通知不走字**，保留原有整句文案计算
 * （`computeRemainingText` 天然尊重 `showCountdown` / `hidePrefixText`），
 * **按分钟重发一次**（文本真变、去抖放行；一小时 60 次 vs 逐秒 3600 次）；
 * **上岛设备**仍逐秒重绘（岛内观感红线）。
 *
 * 所以这里只剩 `showWhen`：岛上 `when` 区不显示，标准通知显示。
 */
internal data class NotificationChrome(
    /** `setShowWhen` 的真实值。 */
    val showWhen: Boolean,
)

internal object LiveUpdateChromePolicy {

    /**
     * @param promotedFormActive 权威判定（见 [PromotedFormPolicy]）：这条通知**实际会不会上岛**
     */
    fun chromeFor(promotedFormActive: Boolean): NotificationChrome =
        NotificationChrome(showWhen = !promotedFormActive)
}
