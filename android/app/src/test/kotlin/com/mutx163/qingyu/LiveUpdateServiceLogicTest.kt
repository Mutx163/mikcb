package com.mutx163.qingyu

import android.app.NotificationManager
import android.media.AudioManager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LiveUpdateServiceLogicTest {
    @Test
    fun beforeClassQuickActionRestoresAfterClassEndWhenDue() {
        assertTrue(
            beforeClassQuickActionShouldRestoreAfterClassEnd(
                nowMillis = 1_700_000_000_000L,
                restoreAtMillis = 1_699_999_000_000L,
            )
        )
    }

    @Test
    fun beforeClassQuickActionDoesNotRestoreBeforeClassEnd() {
        assertFalse(
            beforeClassQuickActionShouldRestoreAfterClassEnd(
                nowMillis = 1_699_999_000_000L,
                restoreAtMillis = 1_700_000_000_000L,
            )
        )
    }

    @Test
    fun promotedApi36PlusDoesNotMirrorStatusIntoMiuiFocusHint() {
        assertFalse(
            liveShouldMirrorStatusIntoMiuiFocusHint(
                sdkInt = 36,
                shouldPromote = true,
            )
        )
    }

    @Test
    fun nonPromotedOrOlderBuildsKeepMiuiFocusHint() {
        assertTrue(
            liveShouldMirrorStatusIntoMiuiFocusHint(
                sdkInt = 35,
                shouldPromote = true,
            )
        )
        assertTrue(
            liveShouldMirrorStatusIntoMiuiFocusHint(
                sdkInt = 36,
                shouldPromote = false,
            )
        )
    }

    @Test
    fun quickActionButtonsNoneShowsNothing() {
        assertEquals(
            BeforeClassQuickActionButtons(),
            beforeClassQuickActionButtons(
                action = "none",
                silentCurrentlyActive = true,
                dndCurrentlyActive = true,
            ),
        )
    }

    @Test
    fun quickActionButtonsFlipToCancelWhenModeAlreadyActive() {
        // 静音未开 → 打开静音；已开 → 取消静音
        assertTrue(
            beforeClassQuickActionButtons(
                action = "silent",
                silentCurrentlyActive = false,
                dndCurrentlyActive = false,
            ).silentEnable
        )
        val active = beforeClassQuickActionButtons(
            action = "silent",
            silentCurrentlyActive = true,
            dndCurrentlyActive = false,
        )
        assertTrue(active.silentCancel)
        assertFalse(active.silentEnable)
        assertFalse(active.dndEnable)
        assertFalse(active.dndCancel)
    }

    @Test
    fun quickActionButtonsBothShowsIndependentToggles() {
        // both：静音已被（自动）打开，勿扰未开 → 一个取消按钮 + 一个打开按钮
        val mixed = beforeClassQuickActionButtons(
            action = "both",
            silentCurrentlyActive = true,
            dndCurrentlyActive = false,
        )
        assertTrue(mixed.silentCancel)
        assertFalse(mixed.silentEnable)
        assertTrue(mixed.dndEnable)
        assertFalse(mixed.dndCancel)

        val allActive = beforeClassQuickActionButtons(
            action = "both",
            silentCurrentlyActive = true,
            dndCurrentlyActive = true,
        )
        assertTrue(allActive.silentCancel)
        assertTrue(allActive.dndCancel)
        assertFalse(allActive.silentEnable)
        assertFalse(allActive.dndEnable)
    }

    @Test
    fun quickActionButtonsPriorityOnlyShowsDndSlot() {
        // 「仅允许优先通知」复用 dnd 开关位：它是勿扰的一种档位，不是静音。
        val off = beforeClassQuickActionButtons(
            action = "priority_only",
            silentCurrentlyActive = false,
            dndCurrentlyActive = false,
        )
        assertTrue(off.dndEnable)
        assertFalse(off.dndCancel)
        assertFalse(off.silentEnable)
        assertFalse(off.silentCancel)

        val on = beforeClassQuickActionButtons(
            action = "priority_only",
            silentCurrentlyActive = false,
            dndCurrentlyActive = true,
        )
        assertTrue(on.dndCancel)
        assertFalse(on.dndEnable)
    }

    @Test
    fun restoreIsSkippedWhenUserChangedStateInClass() {
        // 用户课中自己把勿扰关了（想听见闹钟），下课恢复不能替他重新打开：
        // 当前值与本应用写入值不同即视为用户已接管。
        assertTrue(
            quickActionRestoreOwnedByUser(
                appliedState = NotificationManager.INTERRUPTION_FILTER_NONE,
                currentState = NotificationManager.INTERRUPTION_FILTER_ALL,
            )
        )
        assertTrue(
            quickActionRestoreOwnedByUser(
                appliedState = AudioManager.RINGER_MODE_SILENT,
                currentState = AudioManager.RINGER_MODE_VIBRATE,
            )
        )
    }

    @Test
    fun restoreProceedsWhenStateUnchangedOrUnreadable() {
        // 没被用户动过 → 照常恢复
        assertFalse(
            quickActionRestoreOwnedByUser(
                appliedState = NotificationManager.INTERRUPTION_FILTER_NONE,
                currentState = NotificationManager.INTERRUPTION_FILTER_NONE,
            )
        )
        // 读不到系统值：宁可多恢复一次，也不能让手机停在勿扰里
        assertFalse(quickActionRestoreOwnedByUser(appliedState = 1, currentState = null))
        // 旧版本 pending 没有这个键：按「仍是本应用的状态」处理
        assertFalse(quickActionRestoreOwnedByUser(appliedState = null, currentState = 2))
    }

    @Test
    fun ringerSuppressingDndFilters() {
        assertTrue(
            dndFilterSuppressesRinger(NotificationManager.INTERRUPTION_FILTER_NONE)
        )
        assertTrue(
            dndFilterSuppressesRinger(NotificationManager.INTERRUPTION_FILTER_ALARMS)
        )
        assertFalse(
            dndFilterSuppressesRinger(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
        )
        assertFalse(
            dndFilterSuppressesRinger(NotificationManager.INTERRUPTION_FILTER_ALL)
        )
    }

    @Test
    fun quickActionButtonsSignatureTracksStateFlip() {
        val inactive = beforeClassQuickActionButtons(
            action = "do_not_disturb",
            silentCurrentlyActive = false,
            dndCurrentlyActive = false,
        ).toString()
        val active = beforeClassQuickActionButtons(
            action = "do_not_disturb",
            silentCurrentlyActive = false,
            dndCurrentlyActive = true,
        ).toString()
        assertTrue(inactive != active)
    }
}
