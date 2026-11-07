package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 登录页观察/填充脚本的契约测试。
 *
 * 2026-11-07 用户实报：自动填充只把值写进网页，画面不跟着动，登录框在首屏下方时
 * 用户看不到「已经填好了」。这里钉住「填完把目标输入框滚到视口中间」。
 */
class WarehouseLoginWatcherScriptTest {

    @Test
    fun `自动填充后必须把目标输入框滚到视口中间`() {
        val script = WarehouseLoginWatcherJs.INSTALL_SCRIPT
        assertTrue("必须调用 scrollIntoView", script.contains("scrollIntoView"))
        assertTrue(
            "优先滚密码框：没有密码才退回账号框",
            script.contains("const target = password ? pwd : (username ? account : null)"),
        )
        assertTrue("滚到视口中间，不能只露出边缘", script.contains("block: 'center'"))
        assertTrue("老 WebView 不支持参数对象时要能退回无参调用", script.contains("target.scrollIntoView()"))
    }

    @Test
    fun `自动填充脚本仍然对账号口令做 JSON 转义`() {
        val script = warehouseAutofillLoginScript(
            WarehouseRememberedLogin(username = "学\"生", password = "p\\w"),
        )
        assertTrue("账号里的引号必须被转义", script.contains("\"学\\\"生\""))
        assertTrue("口令里的反斜杠必须被转义", script.contains("\"p\\\\w\""))
    }
}
