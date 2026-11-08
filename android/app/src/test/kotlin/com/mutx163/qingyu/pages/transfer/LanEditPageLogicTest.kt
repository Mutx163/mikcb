package com.mutx163.qingyu.pages.transfer

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * 局域网编辑页纯逻辑测试（快照 → 模型、主按钮意图、复制地址、离开是否停服）。
 *
 * 期望值从 Dart 手推（`lib/screens/lan_edit_screen.dart`）：
 * - 主按钮在起停过程中不响应（`_isStarting` / `_isStopping` 时 `onPressed: null`）；
 * - 复制地址没有地址时直接 return（:255-257）；
 * - 离开页面时看服务上的 `retainAfterLeave`（:137-143）；
 * - 最近活动时间用 `DateFormat.yMd().add_Hms()` 渲染（:270-272）。
 */
class LanEditPageLogicTest {

    private val shanghai: ZoneId = ZoneId.of("Asia/Shanghai")

    // ── 1. 最近活动时间 ──

    @Test
    fun `最近活动时间格式成年月日时分秒`() {
        val millis = LocalDateTime.of(2026, 10, 29, 22, 31, 5)
            .atZone(shanghai)
            .toInstant()
            .toEpochMilli()

        assertEquals("2026/10/29 22:31:05", LanEditPageLogic.formatLastActivity(millis, shanghai))
    }

    @Test
    fun `没有活动时间时模型里保持 null 而不是占位符`() {
        val model = LanEditPageLogic.modelFrom(
            LanEditRuntimeSnapshot(running = true, ipAddress = "192.168.1.5", port = 8080),
            shanghai,
        )
        assertNull(model.lastActivityLine)
    }

    // ── 2. 快照 → 模型 ──

    @Test
    fun `运行中的快照翻译成屏上文字`() {
        val millis = LocalDateTime.of(2026, 10, 29, 8, 5, 0)
            .atZone(shanghai)
            .toInstant()
            .toEpochMilli()
        val model = LanEditPageLogic.modelFrom(
            LanEditRuntimeSnapshot(
                running = true,
                ipAddress = "192.168.1.5",
                port = 8080,
                pin = "123456",
                connectedClients = 2,
                lastActivityAtMillis = millis,
            ),
            shanghai,
        )

        assertEquals("http://192.168.1.5:8080", model.addressText)
        assertEquals("123456", model.pinText)
        assertEquals("8080", model.portText)
        assertEquals("2 台", model.clientsText)
        assertEquals("2026/10/29 08:05:00", model.lastActivityLine)
        assertTrue(model.showSessionBlock)
        assertEquals(TransferExtStrings.lanEditStop.zh, model.primaryActionLabel)
    }

    @Test
    fun `停着的快照不显示会话块且主按钮是开启`() {
        val model = LanEditPageLogic.modelFrom(LanEditRuntimeSnapshot(), shanghai)

        assertFalse(model.running)
        assertFalse(model.showSessionBlock)
        assertEquals(TransferExtStrings.lanEditStart.zh, model.primaryActionLabel)
        // 没 IP 时给的那句提示，不是拼出来的半截地址。
        assertEquals(TransferExtStrings.lanEditAddressUnavailable.zh, model.addressText)
    }

    @Test
    fun `启动失败原因会拼进启动失败一行`() {
        val model = LanEditPageLogic.modelFrom(
            LanEditRuntimeSnapshot(running = false, startFailedReason = "foreground_service_unavailable"),
            shanghai,
        )
        val text = model.startFailedText
        assertTrue(text != null)
        assertTrue(text!!.startsWith(TransferExtStrings.lanEditStartFailed.zh))
        assertTrue(text.contains("foreground_service_unavailable"))
    }

    // ── 3. 复制地址 ──

    @Test
    fun `有地址时复制的就是浏览器能打开的那条`() {
        val model = LanEditModel(running = true, ipAddress = "10.0.0.7", port = 9000)
        assertEquals("http://10.0.0.7:9000", LanEditPageLogic.addressToCopy(model))
    }

    @Test
    fun `没地址时不复制那句提示`() {
        val model = LanEditModel(running = true)
        assertNull(LanEditPageLogic.addressToCopy(model))
    }

    @Test
    fun `只有 IP 没端口时也不复制`() {
        val model = LanEditModel(running = true, ipAddress = "192.168.1.5", port = 0)
        assertNull(LanEditPageLogic.addressToCopy(model))
    }

    // ── 4. 主按钮意图 ──

    @Test
    fun `停止时点一下是开启`() {
        assertEquals(LanEditToggle.START, LanEditPageLogic.toggleIntent(running = false, busy = false))
    }

    @Test
    fun `运行中点一下是停止`() {
        assertEquals(LanEditToggle.STOP, LanEditPageLogic.toggleIntent(running = true, busy = false))
    }

    @Test
    fun `起停过程中点一下什么都不做`() {
        assertEquals(LanEditToggle.NONE, LanEditPageLogic.toggleIntent(running = false, busy = true))
        assertEquals(LanEditToggle.NONE, LanEditPageLogic.toggleIntent(running = true, busy = true))
    }

    // ── 5. 离开页面与落盘键 ──

    @Test
    fun `开关关着时离开页面要停服`() {
        assertTrue(LanEditPageLogic.shouldStopOnLeave(keepAliveWhenLeaving = false))
        assertFalse(LanEditPageLogic.shouldStopOnLeave(keepAliveWhenLeaving = true))
    }
}
