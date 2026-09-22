package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 日历同步的纯逻辑单测：批构成（清空与写入必须同批）+ 权限排队扇出。
 * 真正落库的 ContentProvider 路径不在这里测（需要设备/Robolectric）。
 */
class CalendarSyncLogicTest {

    // ── buildSyncOps：单批 = 1 条清空 + N 条合法插入 ──

    @Test
    fun emptyEventsStillClearsInSameBatch() {
        // 用户把课清光后同步：日历必须被清空，但清空本身就是唯一一步，
        // 不允许再走「先 clear 后另一批」的旧路径（那条路径 insert 失败会丢数据）。
        val ops = buildSyncOps(calendarId = 7L, events = emptyList())
        assertEquals(listOf<SyncOp>(SyncOp.ClearCalendar(7L)), ops)
    }

    @Test
    fun clearAlwaysPrecedesInserts() {
        val ops = buildSyncOps(
            calendarId = 3L,
            events = listOf(
                mapOf("startMs" to 100L, "endMs" to 200L, "title" to "A"),
                mapOf("startMs" to 300L, "endMs" to 400L, "title" to "B"),
            ),
        )
        assertEquals(3, ops.size)
        assertEquals(SyncOp.ClearCalendar(3L), ops.first())
        assertTrue(ops.drop(1).all { it is SyncOp.InsertEvent })
    }

    @Test
    fun invalidEventsAreSkippedNotFatal() {
        // 时间不合法的日程宁缺毋滥：跳过，不让整批失败。
        val ops = buildSyncOps(
            calendarId = 1L,
            events = listOf(
                mapOf("startMs" to 200L, "endMs" to 100L, "title" to "endBeforeStart"),
                mapOf("startMs" to 100L, "endMs" to 100L, "title" to "zeroLength"),
                mapOf("startMs" to null, "endMs" to 200L, "title" to "missingStart"),
                mapOf("startMs" to 100L, "title" to "missingEnd"),
                mapOf("startMs" to "nope", "endMs" to 200L, "title" to "badType"),
                mapOf("startMs" to 100L, "endMs" to 200L, "title" to "ok"),
            ),
        )
        assertEquals(2, ops.size)
        val insert = ops[1] as SyncOp.InsertEvent
        assertEquals("ok", insert.title)
        assertEquals(100L, insert.startMs)
        assertEquals(200L, insert.endMs)
    }

    @Test
    fun insertKeepsNullableFieldsAndNumberCoercion() {
        val ops = buildSyncOps(
            calendarId = 9L,
            events = listOf(
                mapOf(
                    "startMs" to 100.0,
                    "endMs" to 200.9,
                    "title" to null,
                    "location" to "教一 101",
                    "description" to null,
                ),
            ),
        )
        val insert = ops[1] as SyncOp.InsertEvent
        assertEquals(100L, insert.startMs)
        assertEquals(200L, insert.endMs)
        assertEquals("", insert.title)
        assertEquals("教一 101", insert.location)
        assertEquals(null, insert.description)
    }

    // ── PermissionRequestQueue：单弹窗、多等待者扇出 ──

    @Test
    fun firstEnqueueShowsDialogAndSecondPiggybacks() {
        // 旧版单槽 pendingPermissionResult：连点两次会覆盖第一次的 Future，
        // 第一次永挂。现在第二次只是排队，不再弹第二次框。
        val queue = PermissionRequestQueue()
        val got = mutableListOf<Boolean>()

        assertTrue(queue.enqueue { got.add(it) })
        assertTrue(queue.isDialogInFlight)

        assertFalse(queue.enqueue { got.add(it) })
        assertFalse(queue.enqueue { got.add(it) })
        assertEquals(3, queue.waiterCount)

        queue.complete(true)
        assertEquals(listOf(true, true, true), got)
        assertEquals(0, queue.waiterCount)
        assertFalse(queue.isDialogInFlight)
    }

    @Test
    fun completeFanOutToAllWaitersThenAllowsNextDialog() {
        val queue = PermissionRequestQueue()
        val first = mutableListOf<Boolean>()
        val second = mutableListOf<Boolean>()

        queue.enqueue { first.add(it) }
        queue.enqueue { first.add(it) }
        queue.complete(false)
        assertEquals(listOf(false, false), first)

        // 上一轮收束后，下一次申请必须能重新弹框。
        assertTrue(queue.enqueue { second.add(it) })
        queue.complete(true)
        assertEquals(listOf(true), second)
    }

    @Test
    fun hostDestroyedCancelsPendingWaiters() {
        // Activity 销毁时系统对话框一起消失，onRequestPermissionsResult
        // 可能再也不来——必须在这里按未授权收束，否则 Dart 侧 Future 永挂。
        val queue = PermissionRequestQueue()
        val got = mutableListOf<Boolean>()
        queue.enqueue { got.add(it) }
        queue.enqueue { got.add(it) }

        queue.complete(false)

        assertEquals(listOf(false, false), got)
        assertEquals(0, queue.waiterCount)
        assertFalse(queue.isDialogInFlight)
    }

    @Test
    fun emptyCompleteIsNoOpAndResetsFlag() {
        val queue = PermissionRequestQueue()
        queue.complete(true)
        assertFalse(queue.isDialogInFlight)
        assertEquals(0, queue.waiterCount)
        assertTrue(queue.enqueue { })
    }
}
