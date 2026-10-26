package com.mutx163.qingyu.infra

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * 更新红点共享登记单测（抄录 test/services/app_update_dot_share_test.dart
 * 的三态语义：没查过 / 查过没有 / 查过有必须可区分）。
 */
class AppUpdateDotShareTest {

    @Before
    fun setUp() {
        AppUpdateDotShare.resetForTesting()
    }

    @Test
    fun `unknown before publish is distinct from published false`() {
        assertFalse(AppUpdateDotShare.isKnown)
        assertFalse(AppUpdateDotShare.hasUpdate)
        AppUpdateDotShare.publish(hasUpdate = false)
        assertTrue(AppUpdateDotShare.isKnown)
        assertFalse(AppUpdateDotShare.hasUpdate)
    }

    @Test
    fun `published true is visible everywhere`() {
        AppUpdateDotShare.publish(hasUpdate = true)
        assertTrue(AppUpdateDotShare.hasUpdate)
    }

    @Test
    fun `republish false clears dot on all pages`() {
        AppUpdateDotShare.publish(hasUpdate = true)
        AppUpdateDotShare.publish(hasUpdate = false)
        assertFalse(AppUpdateDotShare.hasUpdate)
        assertTrue(AppUpdateDotShare.isKnown)
    }

    @Test
    fun `reset clears state`() {
        AppUpdateDotShare.publish(hasUpdate = true)
        AppUpdateDotShare.resetForTesting()
        assertFalse(AppUpdateDotShare.isKnown)
        assertFalse(AppUpdateDotShare.hasUpdate)
    }
}

/**
 * 分析打点桩单测：契约就是「调了无事发生、不抛异常、observers 为空」。
 */
class AppAnalyticsTest {

    @Test
    fun `noop contract`() {
        AppAnalytics.initialize()
        AppAnalytics.logEvent("startup", mapOf("count" to 1))
        AppAnalytics.logEventLater("later")
        assertTrue(AppAnalytics.navigatorObservers().isEmpty())
        assertEquals(0, AppAnalytics.navigatorObservers().size)
    }
}
