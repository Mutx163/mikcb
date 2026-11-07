package com.mutx163.qingyu

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * [PromotedFormPolicy] 的**行为断言**（JVM 直测，第三轮返工 hy2 点名的「核心改动零行为测试」）。
 *
 * 三档必须覆盖：小米形态（miui.focus.param 上岛不看 SDK）、通知开关关闭、渠道关闭。
 */
class PromotedFormPolicyTest {

    private fun promote(
        stage: String? = "beforeClass",
        shouldPromote: Boolean = true,
        isXiaomiFamily: Boolean = false,
        sdkInt: Int = 36,
        notificationsAllowed: Boolean = true,
        channelEnabled: Boolean = true,
        canPostPromoted: Boolean = true,
    ) = PromotedFormPolicy.isPromotedFormActive(
        stage = stage,
        shouldPromote = shouldPromote,
        isXiaomiFamily = isXiaomiFamily,
        sdkInt = sdkInt,
        notificationsAllowed = notificationsAllowed,
        channelEnabled = channelEnabled,
        canPostPromoted = canPostPromoted,
    )

    @Test
    fun `小米形态 低SDK且系统未授权 仍视为会上岛`() {
        // miui.focus.param 上岛不看 SDK：不看 sdkInt / canPostPromoted。
        assertTrue(
            promote(isXiaomiFamily = true, sdkInt = 30, canPostPromoted = false),
        )
    }

    @Test
    fun `通知总开关关闭 一律不上岛`() {
        assertFalse(promote(notificationsAllowed = false))
        assertFalse(promote(isXiaomiFamily = true, notificationsAllowed = false))
    }

    @Test
    fun `渠道被关 一律不上岛`() {
        assertFalse(promote(channelEnabled = false))
        assertFalse(promote(isXiaomiFamily = true, channelEnabled = false))
    }

    @Test
    fun `非小米 需要SDK36且系统授权`() {
        assertFalse(promote(sdkInt = 35, canPostPromoted = true))
        assertFalse(promote(sdkInt = 36, canPostPromoted = false))
        assertTrue(promote(sdkInt = 36, canPostPromoted = true))
    }

    @Test
    fun `状态栏上课模式或未要求promote 不上岛`() {
        assertFalse(promote(stage = "duringClassStatusBar"))
        assertFalse(promote(shouldPromote = false))
    }
}
