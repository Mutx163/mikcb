package com.mutx163.qingyu

/**
 * 超级岛 / 前台通知的**内容签名去抖**（纯逻辑，无 Android 依赖，可 JVM 直测）。
 *
 * ## 为什么需要它（用户报的真实耗电问题）
 *
 * 用户本机 bugreport：超级岛通知 2 小时发了 **307 条**，其中落到 systemui 真正
 * 触发重绘的只有 13 条，**294 条（95.8%）被判「内容未变」**。也就是绝大多数
 * `NotificationManager.notify()` 是空发 —— 每次都要叫醒系统一遍却什么也没改。
 *
 * 去抖判据：把「这条通知画出来真正依赖的东西」压成一个签名
 * （[NotificationContentSignature]），**和上次发出去的那份逐字段比**，全同就不发。
 *
 * ## 为什么不担心「状态泄漏」
 *
 * 签名只取决于**当前内容本身**，不缓存任何「上一次的课表/城市」状态：
 * - 换课表 / 换城市 / 换课程 ⇒ 正文或关键文本变 ⇒ 签名变 ⇒ 正常发；
 * - 再换回旧内容 ⇒ 签名又变回不同的值 ⇒ 仍会发（不会因为「以前见过」被挡掉）；
 * - 真正的强制重发口子是 [reset]（服务重启 / 配置大改时调用），避免旧签名把新内容挡住。
 */
internal data class NotificationContentSignature(
    /** 正文（`computeRemainingText` 的结果，倒计时/状态文本）。 */
    val remainingText: String,
    /** 超级岛「关键文本」（`shortCriticalText` / 展开态的关键时间）。 */
    val criticalTimeText: String,
    /** 开课快捷按钮的当前状态签名（`BeforeClassQuickActionButtons.toString()`，data class 稳定）。 */
    val quickActionState: String,
    /** 上课进度单位（`ProgressStyle` 的 `progressUnits`；不展示进度时为 -1）。 */
    val progressUnits: Int,
)

internal object NotificationDedupe {

    /**
     * 相对上一次已发出的签名，这一次是否需要发。
     *
     * @param previous 上一次**确实发出去**的签名；`null` = 还没发过（或刚 [reset]）⇒ 必发。
     * @param next 本次要发的签名。
     * @return `true` = 内容有变化（或首次），需要 `notify()`；`false` = 与上次完全一样，跳过。
     */
    fun shouldPost(
        previous: NotificationContentSignature?,
        next: NotificationContentSignature,
    ): Boolean = previous != next
}
