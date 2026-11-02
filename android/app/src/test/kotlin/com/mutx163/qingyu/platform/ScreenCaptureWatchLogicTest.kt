package com.mutx163.qingyu.platform

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 钉住 [screenCaptureSyncAction] 的注册状态机契约与 [isScreenCaptureCallbackSupported]
 * 的能力门槛。组件（`ScreenCaptureWatcher`）只是把这个判定落到 Android 回调上，
 * 判定本身必须是纯函数才能进 JVM 单测（platform/ 不在任何 L0 模块自动收录范围，
 * 跑法见本文件所在域的交付说明：-ExtraSources 喂入干净宿主域）。
 */
class ScreenCaptureWatchLogicTest {

    @Test
    fun registersOnlyWhenWantedAndStarted() {
        assertEquals(
            ScreenCaptureSyncAction.REGISTER,
            screenCaptureSyncAction(wanted = true, started = true, registered = false),
        )
    }

    @Test
    fun doesNotRegisterWhenNotStartedEvenIfWanted() {
        // 官方回调只允许在 STARTED 窗口内注册；抢跑会抛 IllegalStateException。
        assertEquals(
            ScreenCaptureSyncAction.NONE,
            screenCaptureSyncAction(wanted = true, started = false, registered = false),
        )
    }

    @Test
    fun doesNotRegisterWhenNotWantedEvenIfStarted() {
        assertEquals(
            ScreenCaptureSyncAction.NONE,
            screenCaptureSyncAction(wanted = false, started = true, registered = false),
        )
    }

    @Test
    fun unregistersWhenListenerLeavesOrActivityStops() {
        // 调用方明确不想听了：立刻注销（省电 + 给系统明确的隐私信号）。
        assertEquals(
            ScreenCaptureSyncAction.UNREGISTER,
            screenCaptureSyncAction(wanted = false, started = true, registered = true),
        )
        // 进后台也注销：后台截屏不归因到本页面。
        assertEquals(
            ScreenCaptureSyncAction.UNREGISTER,
            screenCaptureSyncAction(wanted = true, started = false, registered = true),
        )
    }

    @Test
    fun isIdempotentWhenStateAlreadyMatches() {
        assertEquals(
            ScreenCaptureSyncAction.NONE,
            screenCaptureSyncAction(wanted = true, started = true, registered = true),
        )
        assertEquals(
            ScreenCaptureSyncAction.NONE,
            screenCaptureSyncAction(wanted = false, started = false, registered = false),
        )
    }

    @Test
    fun supportedExactlyFromAndroid14() {
        assertFalse(isScreenCaptureCallbackSupported(33))
        assertTrue(isScreenCaptureCallbackSupported(34))
        assertTrue(isScreenCaptureCallbackSupported(35))
        assertTrue(isScreenCaptureCallbackSupported(36))
    }
}
