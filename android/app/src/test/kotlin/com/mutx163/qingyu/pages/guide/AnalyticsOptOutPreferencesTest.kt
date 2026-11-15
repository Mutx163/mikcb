package com.mutx163.qingyu.pages.guide

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「错误上报」开关的持久化契约（2026-11-15 用户批准）。
 *
 * 钉住三件事，缺一条开关就是假控件：
 * 1. **缺键默认关闭上报**（`isOptedOut = false`）——老用户升级后不会因缺键突然静默；
 * 2. 写入后读回一致（宿主靠读回校验决定是否把开关拨回去）；
 * 3. 用的是**独立键** `analytics_opt_out`，绝不写 `accepted_privacy_policy`
 *    （那枚键同时是首启门的钥匙，复用会把「关上报」变成「重开隐私门」）。
 */
class AnalyticsOptOutPreferencesTest {

    @Test
    fun `缺键默认未关闭上报`() {
        val prefs = AnalyticsOptOutPreferences(InMemoryKeyValueStore())
        assertFalse("缺键必须默认 false（= 上报开着），否则升级用户会被静默关掉", prefs.isOptedOut())
    }

    @Test
    fun `写入后读回一致且可以关回来`() {
        val store = InMemoryKeyValueStore()
        val prefs = AnalyticsOptOutPreferences(store)

        prefs.setOptedOut(true)
        assertTrue(prefs.isOptedOut())

        prefs.setOptedOut(false)
        assertFalse(prefs.isOptedOut())
    }

    @Test
    fun `只写独立键不碰隐私同意键`() {
        val store = InMemoryKeyValueStore()
        AnalyticsOptOutPreferences(store).setOptedOut(true)

        val physicalKeys = store.rawSnapshot().keys
        assertTrue(
            "盘上应出现 analytics_opt_out（物理键可能带 flutter. 前缀），实际：$physicalKeys",
            physicalKeys.any { it.endsWith(AnalyticsOptOutPreferences.KEY_ANALYTICS_OPT_OUT) },
        )
        assertFalse(
            "不许写 accepted_privacy_policy：那枚键同时是首启门钥匙，复用会重开隐私门",
            physicalKeys.any { it.endsWith("accepted_privacy_policy") },
        )
        assertNotEquals("accepted_privacy_policy", AnalyticsOptOutPreferences.KEY_ANALYTICS_OPT_OUT)
        assertEquals(1, physicalKeys.size)
    }
}
