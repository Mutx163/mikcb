package com.mutx163.qingyu.pages.transfer

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 局域网编辑页模型层测试。
 *
 * 期望值从 Dart 源手推（`lib/screens/lan_edit_screen.dart`）：
 * - 访问地址：`ip` 或 `port` 缺一就显示 `lanEditAddressUnavailable`（:349-352）；
 * - 已连接客户端：0 台显示 `lanEditConnectedClientsNone`（「暂无」），否则 `{count} 台`；
 * - 主按钮：`isRunning` 决定 `lanEditStop` / `lanEditStart`（:292-298）；
 * - 最近活动：无活动时整行不出现（不是显示占位符）。
 */
class LanEditModelTest {

    // ── 1. 访问地址 ──

    @Test
    fun `有 IP 和端口时拼出完整地址`() {
        val model = LanEditModel(running = true, ipAddress = "192.168.1.23", port = 8080)
        assertEquals("http://192.168.1.23:8080/", model.addressText)
        assertTrue(model.hasAddress)
    }

    @Test
    fun `有 PIN 时地址带 pin 查询参数_电脑扫码免手输`() {
        // 发布版 lan_edit_screen.dart 把 encodeLanEditUrl(host, port, pin) 同时用于
        // 地址行与二维码；web 端 app.js 读到 ?pin= 会直接 verifyPinAndEnter。
        val model = LanEditModel(
            running = true,
            ipAddress = "192.168.1.23",
            port = 8080,
            pin = "123456",
        )
        assertEquals("http://192.168.1.23:8080/?pin=123456", model.addressText)
        assertEquals(
            "复制地址与二维码必须同源（都带 pin）",
            "http://192.168.1.23:8080/?pin=123456",
            LanEditPageLogic.addressToCopy(model),
        )
    }

    @Test
    fun `PIN 里的特殊字符按 URL 编码_不能拼出坏地址`() {
        val model = LanEditModel(
            running = true,
            ipAddress = "10.0.0.7",
            port = 9000,
            pin = "12 34&56",
        )
        assertEquals("http://10.0.0.7:9000/?pin=12+34%2656", model.addressText)
    }

    @Test
    fun `没有 IP 时显示未检测到局域网 IP 而不是半截地址`() {
        val model = LanEditModel(running = true, ipAddress = null, port = 8080)
        assertEquals("未检测到局域网 IP，请确认已连接 WiFi 或已开启热点", model.addressText)
        assertFalse("没地址就不该允许复制", model.hasAddress)
    }

    @Test
    fun `空串 IP 同样算没有 IP`() {
        val model = LanEditModel(running = true, ipAddress = "   ", port = 8080)
        assertEquals("未检测到局域网 IP，请确认已连接 WiFi 或已开启热点", model.addressText)
        assertFalse(model.hasAddress)
    }

    @Test
    fun `没有端口时也算没地址`() {
        // 端口为 0 / null 时电脑连不上，拼出 http://ip:0 只会让人以为 App 坏了
        assertEquals(
            "未检测到局域网 IP，请确认已连接 WiFi 或已开启热点",
            LanEditModel(ipAddress = "192.168.1.23", port = null).addressText,
        )
        assertEquals(
            "未检测到局域网 IP，请确认已连接 WiFi 或已开启热点",
            LanEditModel(ipAddress = "192.168.1.23", port = 0).addressText,
        )
    }

    // ── 2. 客户端计数 ──

    @Test
    fun `零台显示暂无而不是零台`() {
        assertEquals("暂无", LanEditModel(connectedClients = 0).clientsText)
    }

    @Test
    fun `有客户端时显示台数`() {
        assertEquals("1 台", LanEditModel(connectedClients = 1).clientsText)
        assertEquals("3 台", LanEditModel(connectedClients = 3).clientsText)
    }

    // ── 3. 主按钮 ──

    @Test
    fun `运行中主按钮是停止`() {
        assertEquals("停止", LanEditModel(running = true).primaryActionLabel)
    }

    @Test
    fun `停止时主按钮是开启局域网编辑`() {
        assertEquals("开启局域网编辑", LanEditModel(running = false).primaryActionLabel)
    }

    // ── 4. 最近活动 ──

    @Test
    fun `没有活动时不画这一行`() {
        assertNull(LanEditModel().lastActivityLine)
        assertNull(LanEditModel(lastActivityText = "  ").lastActivityLine)
    }

    @Test
    fun `有活动时给出文本`() {
        assertEquals("刚刚", LanEditModel(lastActivityText = "刚刚").lastActivityLine)
    }

    // ── 5. PIN / 端口空值不显示 ──

    @Test
    fun `没有 PIN 与端口时给空串让渲染层隐藏`() {
        val model = LanEditModel()
        assertEquals("", model.pinText)
        assertEquals("", model.portText)
    }

    @Test
    fun `有 PIN 与端口时给文本`() {
        val model = LanEditModel(port = 8080, pin = "4821")
        assertEquals("4821", model.pinText)
        assertEquals("8080", model.portText)
    }

    // ── 6. 会话信息块何时出现 ──

    @Test
    fun `只有跑起来且有地址时才显示会话块`() {
        assertFalse("没跑起来就不该显示", LanEditModel(running = false, ipAddress = "1.2.3.4", port = 80).showSessionBlock)
        assertFalse("跑起来但没地址也不显示", LanEditModel(running = true, ipAddress = null, port = 80).showSessionBlock)
        assertTrue(LanEditModel(running = true, ipAddress = "1.2.3.4", port = 80).showSessionBlock)
    }

    // ── 7. 启动失败 ──

    @Test
    fun `启动失败时拼出原因`() {
        assertEquals(
            "启动失败：端口被占用",
            LanEditModel(startFailedReason = "端口被占用").startFailedText,
        )
    }

    @Test
    fun `没有失败时不显示`() {
        assertNull(LanEditModel().startFailedText)
        assertNull(LanEditModel(startFailedReason = "  ").startFailedText)
    }

    // ── 8. 文案来自 ARB ──

    @Test
    fun `标题与说明取自 ARB`() {
        val model = LanEditModel()
        assertEquals("局域网编辑", model.title)
        assertEquals("访问地址", model.addressLabel)
        assertEquals("PIN", model.pinLabel)
        assertEquals("端口", model.portLabel)
        assertEquals("复制地址", model.copyAddressLabel)
        assertEquals("地址已复制", model.copiedMessage)
        assertEquals("已连接", model.clientsLabel)
        assertEquals("最近活动", model.lastActivityLabel)
    }
}
