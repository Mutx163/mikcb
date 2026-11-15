package com.mutx163.qingyu.pages.guide

import com.mutx163.qingyu.app.KeyValueStore

/**
 * 「错误上报」开关的持久化（2026-11-15 用户批准）。
 *
 * ## 为什么用一枚**独立键**
 *
 * `accepted_privacy_policy` 同时是「同意过隐私」与「首启门已过」的钥匙（只写 `true`、
 * 没有撤回路径）。如果拿它兼做上报开关，一处取值会被两件事同时解释：关上报变成
 * 「重开隐私门」，下次启动会被当成首启。所以这里单开 [KEY_ANALYTICS_OPT_OUT]。
 *
 * ## 语义
 *
 * - **默认 false（= 上报开着）**：与改动前行为一致，老用户升级后不会因缺键突然静默；
 * - 只有用户显式关掉才写 `true`；
 * - 读的是「当前是否被关掉」，所以命名是 OptOut 而不是 Enabled。
 *
 * 生效时机：`UmengApplication` 在**每次进程启动**读它（`initialized` 是进程级静态标志），
 * 所以界面上那句「下次启动生效」是事实，不是兜底措辞。
 */
class AnalyticsOptOutPreferences(private val store: KeyValueStore) {

    /** true = 用户关掉了错误上报（不初始化友盟）。 */
    fun isOptedOut(): Boolean = store.getBool(KEY_ANALYTICS_OPT_OUT, false)

    fun setOptedOut(optedOut: Boolean) {
        store.putBool(KEY_ANALYTICS_OPT_OUT, optedOut)
    }

    companion object {
        /** 独立键，**不许**与 `accepted_privacy_policy` 复用（见类注释）。 */
        const val KEY_ANALYTICS_OPT_OUT = "analytics_opt_out"
    }
}
