package com.mutx163.qingyu.pages.live

/**
 * 「后台保活」子屏状态（模型层，纯 Kotlin，零 Android 依赖）。
 *
 * 对应 Flutter `lib/screens/live_settings_subpages.dart` 的
 * `_LiveKeepAliveSettingsScreenState`：一个「从最近任务中隐藏应用」开关 + 一条无障碍保活服务行。
 */
data class LiveKeepAliveState(
    /** 「从最近任务中隐藏应用」开关的落库值（Dart `_draft.liveHideFromRecents`）。 */
    val hideFromRecents: Boolean = false,
    /** 无障碍保活服务是否已开启（Dart `_enabled`，由平台侧探测得到）。 */
    val accessibilityEnabled: Boolean = false,
    /** 服务状态是否已探测过一轮；未探测前不猜（见下方 [LivePermissionStatus.UNKNOWN]）。 */
    val accessibilityChecked: Boolean = false,
    /** 「勿扰模式访问权限」是否已授予（Dart `_DoNotDisturbAccessTileState._granted`）。 */
    val doNotDisturbAccessGranted: Boolean = false,
    /** 勿扰权限是否已探测过（Dart `_DoNotDisturbAccessTileState._checked`）。 */
    val doNotDisturbAccessChecked: Boolean = false,
)

/** 权限 / 服务状态的语义色调（渲染层据此选绿 / 橙 / 中性，模型层不碰具体颜色）。 */
enum class LiveStatusTone {
    /** 中性：状态未知，不猜。 */
    NEUTRAL,

    /** 正向：已授权 / 已开启。 */
    POSITIVE,

    /** 警示：未授权 / 未开启。 */
    CAUTION,
}

/**
 * 权限（或服务可用性）的三态判定。
 *
 * **为什么需要 UNKNOWN**：Dart 原注释写明「未探到状态前不猜：宁可显示中性色，
 * 也不要在权限其实已授予时摆一条橙色的『未开启』吓人」。
 */
enum class LivePermissionStatus {
    UNKNOWN,
    GRANTED,
    DENIED,
}

/** 刷新计划：一次初始读取之后，最多再补几次探测、每次间隔多久。 */
data class LiveRefreshPlan(
    val initialProbeCount: Int,
    val retryAttempts: Int,
    val retryDelayMillis: Long,
)

/** 按计划执行后的结果：最终是否开启 + 实际消耗了几次探测。 */
data class LiveRefreshOutcome(
    val enabled: Boolean,
    val probesUsed: Int,
)

/**
 * 「后台保活」子屏纯逻辑（零 IO、确定性，全部有手推期望值的单测）。
 */
object LiveKeepAliveModel {

    /** Dart `_refresh` 的 `for (var i = 0; i < 3 && !enabled; i++)`。 */
    const val REFRESH_RETRY_ATTEMPTS = 3

    /** Dart `Future.delayed(const Duration(milliseconds: 450))`。 */
    const val REFRESH_RETRY_DELAY_MILLIS = 450L

    /**
     * 权限三态：没探测过一律 UNKNOWN，探测过才按 [granted] 分绿 / 橙。
     *
     * 期望值（手推）：
     * - `(checked=false, granted=false)` -> UNKNOWN（不能因为读不到就报「未开启」）
     * - `(checked=false, granted=true)`  -> UNKNOWN（没探测过时 granted 无意义）
     * - `(checked=true,  granted=true)`  -> GRANTED
     * - `(checked=true,  granted=false)` -> DENIED
     */
    fun resolvePermissionStatus(checked: Boolean, granted: Boolean): LivePermissionStatus = when {
        !checked -> LivePermissionStatus.UNKNOWN
        granted -> LivePermissionStatus.GRANTED
        else -> LivePermissionStatus.DENIED
    }

    fun resolveTone(status: LivePermissionStatus): LiveStatusTone = when (status) {
        LivePermissionStatus.UNKNOWN -> LiveStatusTone.NEUTRAL
        LivePermissionStatus.GRANTED -> LiveStatusTone.POSITIVE
        LivePermissionStatus.DENIED -> LiveStatusTone.CAUTION
    }

    /** 服务行色调：只按「是否已开启」分绿 / 橙（Dart `_LiveKeepAliveServiceTile` 无未知态）。 */
    fun resolveServiceTone(enabled: Boolean): LiveStatusTone =
        if (enabled) LiveStatusTone.POSITIVE else LiveStatusTone.CAUTION

    /**
     * 是否显示右侧「去开启」按钮：Dart `if (!enabled) ...`。
     * 已开启时按钮隐藏——它的唯一用途是开启，开着再引去确认弹窗是噪声。
     */
    fun shouldShowEnableButton(accessibilityEnabled: Boolean): Boolean = !accessibilityEnabled

    /**
     * 整行是否可点：Dart `onTap: enabled ? null : onOpenSettings`。
     * 已开启时整行不可点，避免点下去又弹一次「去开启」确认弹窗。
     */
    fun isServiceRowClickable(accessibilityEnabled: Boolean): Boolean = !accessibilityEnabled

    /**
     * 确认弹窗结果是否放行：Dart `if (confirmed != true) return;`。
     * 因此 null（用户点外部 / 返回键关掉）与 false（点取消）都**不放行**。
     */
    fun shouldProceedToSettings(confirmed: Boolean?): Boolean = confirmed == true

    /**
     * 刷新计划：Dart `_refresh(retryIfDisabled = true)` 在「首读未开启」时再补
     * [REFRESH_RETRY_ATTEMPTS] 次、每次间隔 [REFRESH_RETRY_DELAY_MILLIS]；
     * 首读已开启、或 `retryIfDisabled = false` 时不补探测。
     */
    fun buildRefreshPlan(
        accessibilityEnabled: Boolean,
        retryIfDisabled: Boolean,
    ): LiveRefreshPlan {
        val retries = if (!accessibilityEnabled && retryIfDisabled) REFRESH_RETRY_ATTEMPTS else 0
        return LiveRefreshPlan(
            initialProbeCount = 1,
            retryAttempts = retries,
            retryDelayMillis = REFRESH_RETRY_DELAY_MILLIS,
        )
    }

    /**
     * 把一串探测结果（下标 0 = 首读，之后依次为重试）折叠成最终状态。
     *
     * 语义与 Dart 循环逐字对齐：一旦某次读到 true 就停（`i < 3 && !enabled`）；
     * 重试预算用尽仍为 false 才判「未开启」。探测序列提前用完时按实际次数收口。
     *
     * 期望值（手推，`retryIfDisabled = true`）：
     * - `[true]`                    -> enabled=true,  probesUsed=1（首读就开启，不重试）
     * - `[false, true]`             -> enabled=true,  probesUsed=2
     * - `[false, false, false, true]` -> enabled=true, probesUsed=4（预算 3 次刚好用满）
     * - `[false, false, false, false]` -> enabled=false, probesUsed=4（预算用尽仍未开启）
     * - `[false, false]`            -> enabled=false, probesUsed=2（探测序列短于预算，按实际收口）
     * - `[]`                        -> enabled=false, probesUsed=0（没有探测结果）
     *
     * `retryIfDisabled = false` 时只看首读：`[false, true]` -> enabled=false, probesUsed=1。
     */
    fun resolveRefreshOutcome(
        probes: List<Boolean>,
        retryIfDisabled: Boolean,
    ): LiveRefreshOutcome {
        if (probes.isEmpty()) return LiveRefreshOutcome(enabled = false, probesUsed = 0)
        if (probes[0]) return LiveRefreshOutcome(enabled = true, probesUsed = 1)
        if (!retryIfDisabled) return LiveRefreshOutcome(enabled = false, probesUsed = 1)

        val budget = minOf(REFRESH_RETRY_ATTEMPTS, probes.size - 1)
        for (index in 1..budget) {
            if (probes[index]) return LiveRefreshOutcome(enabled = true, probesUsed = index + 1)
        }
        return LiveRefreshOutcome(enabled = false, probesUsed = budget + 1)
    }

    /** 勿扰权限行的状态文案键（渲染层拿去查 [LiveKeepAliveStrings]）。 */
    fun resolveDoNotDisturbStatus(
        checked: Boolean,
        granted: Boolean,
    ): LivePermissionStatus = resolvePermissionStatus(checked, granted)
}

/** 开关状态变异纯函数：翻转「从最近任务中隐藏应用」。 */
fun LiveKeepAliveState.withToggledHideFromRecents(): LiveKeepAliveState =
    copy(hideFromRecents = !hideFromRecents)

/** 探测结果回填：写入服务状态与「已探测」标记。 */
fun LiveKeepAliveState.withAccessibilityProbe(enabled: Boolean): LiveKeepAliveState =
    copy(accessibilityEnabled = enabled, accessibilityChecked = true)

/** 探测结果回填：写入勿扰权限与「已探测」标记。 */
fun LiveKeepAliveState.withDoNotDisturbProbe(granted: Boolean): LiveKeepAliveState =
    copy(doNotDisturbAccessGranted = granted, doNotDisturbAccessChecked = true)
