package com.mutx163.qingyu

import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 通知权限等待者的收束（第 31 轮）。
 *
 * `MainActivity` 原先用一根裸字段 `permissionResult` 存 Dart 的
 * `requestNotificationPermission()` 回调：:715 直接覆盖、只有
 * `onRequestPermissionsResult` 会消费，而 `onDestroy`(:240-245) 只收束了
 * `CalendarSync.onHostDestroyed()` —— 那行注释写的正是"等待者若不收束，
 * Dart 侧 Future 会永挂"，通知权限这条同形路径却没有对应处理。
 * 于是两种真实场景会把设置页那一次点击永久挂住：
 * 对话框期间 Activity 被销毁/重建（部分国产 ROM 的旋转/深浅色切换会重建），
 * 或用户在回调到达前又点了一次（旧槽被静默覆盖）。
 *
 * 收进 [PendingResultSlot] 后，"被换掉"与"被取走"都必须把旧等待者交回调用方去回，
 * 本文件钉住这两条。
 */
class PendingResultSlotTest {
    private class RecordingResult : MethodChannel.Result {
        var payload: Any? = null
        var delivered = false
        var error: String? = null

        override fun success(result: Any?) {
            payload = result
            delivered = true
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            error = errorCode
            delivered = true
        }

        override fun notImplemented() {
            error = "not-implemented"
            delivered = true
        }
    }

    @Test
    fun replacingPendingSlotHandsBackThePreviousWaiter() {
        val slot = PendingResultSlot()
        val first = RecordingResult()
        val second = RecordingResult()

        assertNull(slot.replace(first))
        assertTrue(slot.isPending())

        val returned = slot.replace(second)

        assertEquals(
            "换槽必须把上一个等待者交回去回，否则那个 Dart Future 永挂",
            first,
            returned,
        )
        assertTrue(slot.isPending())
    }

    @Test
    fun takeClearsTheSlotSoDestroyCannotReAnswer() {
        val slot = PendingResultSlot()
        val pending = RecordingResult()
        slot.replace(pending)

        val returned = slot.take()
        returned?.success(false)

        assertEquals(false, pending.payload)
        assertTrue(pending.delivered)
        assertNull("取走之后槽必须是空的", slot.take())
        assertFalse(slot.isPending())
    }

    @Test
    fun emptySlotIsSafeToSettleRepeatedly() {
        val slot = PendingResultSlot()

        assertNull(slot.take())
        assertNull(slot.take())
        assertFalse(slot.isPending())
    }
}
