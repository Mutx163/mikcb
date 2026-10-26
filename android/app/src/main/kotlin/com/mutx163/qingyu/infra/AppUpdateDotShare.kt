package com.mutx163.qingyu.infra

/**
 * 「有可用更新」状态的跨页面共享登记（源：lib/utils/app_update_dot_share.dart）。
 *
 * 只登记结果的单向广播：首页查到后 [publish] 一次，其他页面读 [hasUpdate]。
 * 不持有 controller、不触发检查。未查过时 [hasUpdate] 为 false（调用方按
 * 「不画点」处理，避免「别的页面有点、回首页反而没有」的倒挂）。
 *
 * 三态：没查过 / 查过没有 / 查过有，调用方可区分（[isKnown]）。
 */
object AppUpdateDotShare {
    private var hasUpdateValue: Boolean = false
    private var knownValue: Boolean = false

    /** 首页查到结果后登记；[hasUpdate] 为 false 也要登记（置 [_known] 真）。 */
    fun publish(hasUpdate: Boolean) {
        hasUpdateValue = hasUpdate
        knownValue = true
    }

    /** 是否已经查到过结果。 */
    val isKnown: Boolean get() = knownValue

    /** 当前是否有可用更新；未查过时返回 false。 */
    val hasUpdate: Boolean get() = knownValue && hasUpdateValue

    /** 测试用：清空登记，免得上一条用例的值漏到下一条。 */
    fun resetForTesting() {
        hasUpdateValue = false
        knownValue = false
    }
}

/**
 * 应用分析打点（源：lib/services/app_analytics.dart）。
 *
 * Dart 侧是无操作桩（空 observers、空方法体）：保留同名入口以便调用方
 * 移植时不断签；行为契约就是「调了无事发生、不抛异常」。
 */
object AppAnalytics {
    fun navigatorObservers(): List<Any> = emptyList()

    fun initialize() = Unit

    fun logEvent(name: String, parameters: Map<String, Any?> = emptyMap()) = Unit

    fun logEventLater(name: String, parameters: Map<String, Any?> = emptyMap()) = Unit
}
