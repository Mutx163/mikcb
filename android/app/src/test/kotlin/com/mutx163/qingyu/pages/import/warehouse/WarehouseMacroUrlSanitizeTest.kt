package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 脚本页 URL 脱敏测试（P1 / N2 前半）。
 *
 * 对拍参照：`lib/models/warehouse_macro_models.dart` 的三个判据函数与
 * `sanitizeWarehouseScriptPageUrl`（只读）。脱敏是隐私承诺：漏一类会话参数就该红。
 */
class WarehouseMacroUrlSanitizeTest {

    // ---------------------------------------------------------------------
    // 一次性参数名判据
    // ---------------------------------------------------------------------

    @Test
    fun `精确名单命中`() {
        listOf(
            "jsessionid", "jsessionId", "JSESSIONID", "ticket", "token",
            "access_token", "refresh_token", "state", "nonce", "timestamp",
            "ts", "t", "random", "rnd", "sid", "sessionid", "sessionId",
        ).forEach { key ->
            assertTrue("精确名单键应命中：$key", isWarehouseVolatileUrlParamKey(key))
        }
    }

    @Test
    fun `子串口径兜住 PHP 与 ASP 的会话名`() {
        assertTrue(isWarehouseVolatileUrlParamKey("PHPSESSID"))
        assertTrue(isWarehouseVolatileUrlParamKey("ASP.NET_SessionId"))
        assertTrue(isWarehouseVolatileUrlParamKey("user_token"))
        assertTrue(isWarehouseVolatileUrlParamKey("loginTicket"))
        assertTrue(isWarehouseVolatileUrlParamKey("userpwd"))
        assertTrue(isWarehouseVolatileUrlParamKey("passwd"))
        assertTrue(isWarehouseVolatileUrlParamKey("password"))
    }

    @Test
    fun `普通业务参数不误伤`() {
        listOf("page", "user", "id", "name", "type", "xh", "gnmkdm").forEach { key ->
            assertFalse("业务键不该命中：$key", isWarehouseVolatileUrlParamKey(key))
        }
    }

    // ---------------------------------------------------------------------
    // sanitize 五类特例
    // ---------------------------------------------------------------------

    @Test
    fun `query 会话参数逐个摘除 其余原样保留`() {
        assertEquals(
            "http://jw.example.edu.cn/login?user=20230001&page=2",
            sanitizeWarehouseScriptPageUrl(
                "http://jw.example.edu.cn/login?jsessionid=ABC123&user=20230001&page=2",
            ),
        )
    }

    @Test
    fun `path 内嵌 jsessionid 段摘除`() {
        assertEquals(
            "http://jw.example.edu.cn/a/b",
            sanitizeWarehouseScriptPageUrl("http://jw.example.edu.cn/a;jsessionid=XYZ/b"),
        )
        // 大小写不敏感
        assertEquals(
            "http://jw.example.edu.cn/a",
            sanitizeWarehouseScriptPageUrl("http://jw.example.edu.cn/a;JSESSIONID=XYZ"),
        )
    }

    @Test
    fun `host 内矩阵参数从第一个分号截断 Dart 特例`() {
        // Dart Uri 会把 `;jsessionid=ABC` 整段并进 host（2026-10 实测）：
        // 域名里不该有 ';'，直接截断，既去掉会话值又保住可导航的地址。
        assertEquals(
            "http://jw.example.edu.cn/xsMain.jsp?x=1",
            sanitizeWarehouseScriptPageUrl(
                "http://jw.example.edu.cn;jsessionid=abc123def/xsMain.jsp?x=1",
            ),
        )
    }

    @Test
    fun `fragment 夹凭据整段丢 纯路由保留`() {
        // OAuth 回调载荷：命中 access_token/state → 整个 fragment 丢
        assertEquals(
            "https://sso.example.cn/cas?code=1",
            sanitizeWarehouseScriptPageUrl(
                "https://sso.example.cn/cas?code=1#access_token=T&state=S",
            ),
        )
        // SPA 纯路由：保留
        assertEquals(
            "https://jw.example.edu.cn/app#/schedule/semester",
            sanitizeWarehouseScriptPageUrl("https://jw.example.edu.cn/app#/schedule/semester"),
        )
    }

    @Test
    fun `userinfo 与端口剥离正确`() {
        assertEquals(
            "http://jw.example.edu.cn:8080/p?k=v",
            sanitizeWarehouseScriptPageUrl("http://user@jw.example.edu.cn:8080/p?t=1&k=v"),
        )
    }

    @Test
    fun `混淆编码的键名按解码值判定`() {
        // jsession%69d 解码后是 jsessionid
        assertEquals(
            "http://jw.example.edu.cn/login?user=x",
            sanitizeWarehouseScriptPageUrl("http://jw.example.edu.cn/login?jsession%69d=1&user=x"),
        )
    }

    @Test
    fun `全部参数被摘干净后不再留问号`() {
        assertEquals(
            "http://jw.example.edu.cn/login",
            sanitizeWarehouseScriptPageUrl("http://jw.example.edu.cn/login?token=1&sid=2"),
        )
    }

    @Test
    fun `不可用地址返回 null`() {
        assertNull(sanitizeWarehouseScriptPageUrl(null))
        assertNull(sanitizeWarehouseScriptPageUrl(""))
        assertNull(sanitizeWarehouseScriptPageUrl("   "))
        assertNull(sanitizeWarehouseScriptPageUrl("jw.example.edu.cn/login"))
        assertNull(sanitizeWarehouseScriptPageUrl("ftp://jw.example.edu.cn/a"))
        assertNull(sanitizeWarehouseScriptPageUrl("http://"))
    }

    // ---------------------------------------------------------------------
    // fragment 判据
    // ---------------------------------------------------------------------

    @Test
    fun `fragment 参数判据边界`() {
        assertTrue(warehouseFragmentCarriesVolatileParam("access_token=abc"))
        assertTrue(warehouseFragmentCarriesVolatileParam("path=1&ticket=x"))
        assertFalse(warehouseFragmentCarriesVolatileParam("schedule/semester"))
        assertFalse(warehouseFragmentCarriesVolatileParam("week=3"))
    }
}
