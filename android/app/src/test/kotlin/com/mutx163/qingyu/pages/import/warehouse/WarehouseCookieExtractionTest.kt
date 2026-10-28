package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * [WarehouseCookieExtraction] 的纯 JVM 单测（L0：
 * `pwsh -File scripts/test-kotlin-module.ps1 -Module "pages/import/warehouse"`）。
 *
 * 期望值来源（**人推**，不是从实现里抄的）：
 * - 域/路径匹配：RFC 6265 §5.1.3（域）/ §5.1.4（路径）；
 * - 过期判据：`Expires` / `Max-Age` 语义，`<= now` 即失效；
 * - 日期→秒：`2026-10-21T07:28:00Z` 的 epoch 秒是**独立算术**推出来的
 *   （2020-01-01 = 18262 天，2026-01-01 = 20454 天，2026-10-21 = 20747 天，
 *   20747×86400 + 07:28:00(26880) = 1792567680）。
 */
class WarehouseCookieExtractionTest {

    // -----------------------------------------------------------------------
    // 1. Set-Cookie 解析（正常 / 畸形 / 缺关键字段）
    // -----------------------------------------------------------------------

    @Test
    fun `解析单条 Set-Cookie 的正常形状与全部属性`() {
        val cookie = parseWarehouseSetCookie(
            "sid=abc123; Path=/xskb; Domain=.jw.school.edu.cn; " +
                "Expires=Wed, 21 Oct 2026 07:28:00 GMT; Secure; HttpOnly",
        )
        assertTrue("正常 Set-Cookie 不该被判成畸形", cookie != null)
        cookie!!
        assertEquals("sid", cookie.name)
        assertEquals("abc123", cookie.value)
        assertEquals("/xskb", cookie.path)
        assertEquals(".jw.school.edu.cn", cookie.domain)
        assertEquals("Expires 应折成 epoch 秒", 1_792_567_680L, cookie.expiresAtEpochSeconds)
        assertTrue(cookie.secure)
        assertTrue(cookie.httpOnly)
    }

    @Test
    fun `值内允许再出现等号且值可为空`() {
        val jwt = parseWarehouseSetCookie("token=a=b=c; Path=/")!!
        assertEquals("token", jwt.name)
        assertEquals("a=b=c", jwt.value)

        val empty = parseWarehouseSetCookie("empty=")!!
        assertEquals("empty", empty.name)
        assertEquals("", empty.value)

        val quoted = parseWarehouseSetCookie("q=\"v w\"")!!
        assertEquals("\"v w\"", quoted.value)
    }

    @Test
    fun `畸形或缺少关键字段的 Set-Cookie 返回 null`() {
        assertNull(parseWarehouseSetCookie(null))
        assertNull(parseWarehouseSetCookie(""))
        assertNull(parseWarehouseSetCookie("   "))
        assertNull("没有等号 → 无名字也无值", parseWarehouseSetCookie("novalue"))
        assertNull("等号在首位 → 没有名字", parseWarehouseSetCookie("=x"))
        assertNull("名字含空白 → 判畸形", parseWarehouseSetCookie("na me=x"))
        assertNull(parseWarehouseSetCookie("; ;"))
        // 仅名字、空值仍是合法 Cookie（HTTP 允许 name= 空值）
        assertEquals("a", parseWarehouseSetCookie("a=")!!.name)
    }

    @Test
    fun `Expires 按 RFC1123 与 RFC850 两种写法都能解析`() {
        assertEquals(1_792_567_680L, parseWarehouseHttpDateEpochSeconds("Wed, 21 Oct 2026 07:28:00 GMT"))
        // 无星期前缀 / 日-月-年用连字符的 RFC 850 变体
        assertEquals(1_792_567_680L, parseWarehouseHttpDateEpochSeconds("21-Oct-2026 07:28:00 GMT"))
        assertNull(parseWarehouseHttpDateEpochSeconds("not a date"))
        assertNull(parseWarehouseHttpDateEpochSeconds(""))
        assertNull(parseWarehouseHttpDateEpochSeconds(null))
        // 非法月/日/时间应被拒
        assertNull(parseWarehouseHttpDateEpochSeconds("Wed, 21 Xxx 2026 07:28:00 GMT"))
    }

    // -----------------------------------------------------------------------
    // 2. Max-Age 相对过期（必须配合接收时刻）
    // -----------------------------------------------------------------------

    @Test
    fun `Max-Age 按接收时刻折成绝对过期且优先于 Expires`() {
        val received = 1_000_000L
        assertEquals(
            "Max-Age=3600 → 接收时刻 + 3600",
            received + 3600,
            parseWarehouseSetCookie("s=1; Max-Age=3600", received)!!.expiresAtEpochSeconds,
        )
        assertEquals(
            "Max-Age=0 → 立即过期（等于接收时刻）",
            received,
            parseWarehouseSetCookie("s=1; Max-Age=0", received)!!.expiresAtEpochSeconds,
        )
        assertEquals(
            "Max-Age=-1 → 过去",
            received - 1,
            parseWarehouseSetCookie("s=1; Max-Age=-1", received)!!.expiresAtEpochSeconds,
        )
        assertNull(
            "没有接收时刻就无法把相对时间折成绝对时间 → 按会话 Cookie",
            parseWarehouseSetCookie("s=1; Max-Age=3600")!!.expiresAtEpochSeconds,
        )
        assertEquals(
            "Max-Age 优先于 Expires",
            received + 60,
            parseWarehouseSetCookie(
                "s=1; Max-Age=60; Expires=Wed, 21 Oct 2026 07:28:00 GMT",
                received,
            )!!.expiresAtEpochSeconds,
        )
    }

    // -----------------------------------------------------------------------
    // 3. 快照解析（JSON 数组；空 / 畸形 / 正常多 Cookie）
    // -----------------------------------------------------------------------

    @Test
    fun `空与畸形快照一律得空列表而不抛错`() {
        assertTrue(parseWarehouseCookieSnapshot(null).isEmpty())
        assertTrue(parseWarehouseCookieSnapshot("").isEmpty())
        assertTrue(parseWarehouseCookieSnapshot("   ").isEmpty())
        assertTrue("不是 JSON", parseWarehouseCookieSnapshot("not json").isEmpty())
        assertTrue("顶层是对象不是数组", parseWarehouseCookieSnapshot("""{"name":"a"}""").isEmpty())
        assertTrue("顶层是数字", parseWarehouseCookieSnapshot("123").isEmpty())
        assertTrue(parseWarehouseCookieSnapshot("[]").isEmpty())
    }

    @Test
    fun `快照解析保留顺序并宽容丢弃畸形条目`() {
        val raw = """
            [
              {"name":"JSESSIONID","value":"s1","domain":".school.edu.cn","path":"/","expiresAt":1792567680,"secure":true,"httpOnly":true},
              {"value":"no-name-is-dropped"},
              {"name":"  ","value":"blank-name-dropped"},
              {"name":"csrf","value":"c2","domain":"","path":"","expires":"100","secure":"1","httpOnly":1},
              42
            ]
        """.trimIndent()
        val cookies = parseWarehouseCookieSnapshot(raw)
        assertEquals("只保留两条合法 Cookie", 2, cookies.size)
        assertEquals(listOf("JSESSIONID", "csrf"), cookies.map { it.name })

        val first = cookies[0]
        assertEquals("s1", first.value)
        assertEquals(".school.edu.cn", first.domain)
        assertEquals("/", first.path)
        assertEquals(1_792_567_680L, first.expiresAtEpochSeconds)
        assertTrue(first.secure && first.httpOnly)

        val second = cookies[1]
        assertNull("空域 → 未知域（按 null）", second.domain)
        assertEquals("空路径 → 回退 /", "/", second.path)
        assertEquals("数字字符串过期时间", 100L, second.expiresAtEpochSeconds)
        assertTrue("字符串 \"1\" 视为 true", second.secure)
        assertTrue("数字 1 视为 true", second.httpOnly)
    }

    // -----------------------------------------------------------------------
    // 4. 过期判定边界
    // -----------------------------------------------------------------------

    @Test
    fun `过期判据是小于等于当前时刻且会话 Cookie 永不过期`() {
        val cookie = WarehouseCookieRecord("s", "v", expiresAtEpochSeconds = 1000L)
        assertFalse("还没到点", isWarehouseCookieExpired(cookie, 999L))
        assertTrue("恰好到点即过期（<= now）", isWarehouseCookieExpired(cookie, 1000L))
        assertTrue("已过点", isWarehouseCookieExpired(cookie, 1001L))

        val session = WarehouseCookieRecord("s", "v", expiresAtEpochSeconds = null)
        assertFalse("会话 Cookie 永不过期", isWarehouseCookieExpired(session, Long.MAX_VALUE))
    }

    // -----------------------------------------------------------------------
    // 5. 域匹配 / 路径匹配（RFC 6265）
    // -----------------------------------------------------------------------

    @Test
    fun `域匹配忽略前导点且要求点边界`() {
        assertTrue(warehouseCookieDomainMatches("jw.school.edu.cn", ".school.edu.cn"))
        assertTrue(warehouseCookieDomainMatches("school.edu.cn", "school.edu.cn"))
        assertTrue("无前导点也应匹配子域", warehouseCookieDomainMatches("jw.school.edu.cn", "school.edu.cn"))
        assertFalse(warehouseCookieDomainMatches("evil.com", "school.edu.cn"))
        assertFalse("notschool 不是点边界", warehouseCookieDomainMatches("notschool.edu.cn", "school.edu.cn"))
        assertTrue("未知域保守放行（null）", warehouseCookieDomainMatches("any.com", null))
        assertTrue("未知域保守放行（空串）", warehouseCookieDomainMatches("any.com", ""))
    }

    @Test
    fun `路径匹配遵循 RFC6265 的前缀与斜杠边界`() {
        assertTrue(warehouseCookiePathMatches("/xskb/list.do", "/xskb"))
        assertTrue(warehouseCookiePathMatches("/xskb", "/xskb"))
        assertFalse("xskb2 不是斜杠边界", warehouseCookiePathMatches("/xskb2", "/xskb"))
        assertTrue(warehouseCookiePathMatches("/anything", "/"))
        assertTrue(warehouseCookiePathMatches("/xskb/y", "/xskb/"))
        assertFalse(warehouseCookiePathMatches("/xsk", "/xskb"))
    }

    // -----------------------------------------------------------------------
    // 6. 按目标 URL 提取
    // -----------------------------------------------------------------------

    private fun sampleCookies(): List<WarehouseCookieRecord> = listOf(
        WarehouseCookieRecord("JSESSIONID", "s1", ".school.edu.cn", "/"),
        WarehouseCookieRecord("stale", "x", ".school.edu.cn", "/", expiresAtEpochSeconds = 1000L),
        WarehouseCookieRecord("OTHER", "o", ".other.com", "/"),
        WarehouseCookieRecord("SECUREONLY", "z", ".school.edu.cn", "/", secure = true),
        WarehouseCookieRecord("XS", "p", ".school.edu.cn", "/xskb"),
    )

    @Test
    fun `https 下提取全部适用的未过期 Cookie 并保持顺序`() {
        val extracted = extractWarehouseCookiesForUrl(
            sampleCookies(),
            "https://jw.school.edu.cn/xskb/list.do",
            nowEpochSeconds = 2000L,
        )
        assertEquals(
            listOf("JSESSIONID", "SECUREONLY", "XS"),
            extracted.map { it.name },
        )
    }

    @Test
    fun `http 下排除 Secure Cookie 且非法地址返回空`() {
        val extracted = extractWarehouseCookiesForUrl(
            sampleCookies(),
            "http://jw.school.edu.cn/xskb/list.do",
            nowEpochSeconds = 2000L,
        )
        assertEquals(listOf("JSESSIONID", "XS"), extracted.map { it.name })

        assertTrue(extractWarehouseCookiesForUrl(sampleCookies(), null, 2000L).isEmpty())
        assertTrue(extractWarehouseCookiesForUrl(sampleCookies(), "not a url", 2000L).isEmpty())
        assertTrue("非 http/https 不提取", extractWarehouseCookiesForUrl(sampleCookies(), "ftp://jw.school.edu.cn/", 2000L).isEmpty())
    }

    // -----------------------------------------------------------------------
    // 7. 登录态判定
    // -----------------------------------------------------------------------

    @Test
    fun `关键 Cookie 齐全则登录成立并拼出请求头`() {
        val cookies = listOf(
            WarehouseCookieRecord("JSESSIONID", "s1", ".school.edu.cn", "/"),
            WarehouseCookieRecord("csrf", "c2", ".school.edu.cn", "/"),
        )
        val result = evaluateWarehouseLoginState(
            cookies, listOf("JSESSIONID"), "https://jw.school.edu.cn/xskb/list.do", 2000L,
        )
        assertEquals(WarehouseLoginState.LOGGED_IN, result.state)
        assertEquals("JSESSIONID=s1; csrf=c2", result.cookieHeader)
        assertTrue(result.missingRequiredCookieNames.isEmpty())
        assertTrue(result.expiredRequiredCookieNames.isEmpty())
    }

    @Test
    fun `空 Cookie 或缺关键字段判为未登录`() {
        val empty = evaluateWarehouseLoginState(
            emptyList(), listOf("JSESSIONID"), "https://jw.school.edu.cn/xskb/list.do", 2000L,
        )
        assertEquals(WarehouseLoginState.LOGGED_OUT, empty.state)
        assertEquals(listOf("JSESSIONID"), empty.missingRequiredCookieNames)
        assertEquals("", empty.cookieHeader)

        // 关键 Cookie 存在但值为空 → 视同没有
        val blankValue = evaluateWarehouseLoginState(
            listOf(WarehouseCookieRecord("JSESSIONID", "  ", ".school.edu.cn")),
            listOf("JSESSIONID"), "https://jw.school.edu.cn/xskb/list.do", 2000L,
        )
        assertEquals(WarehouseLoginState.LOGGED_OUT, blankValue.state)
        assertEquals(listOf("JSESSIONID"), blankValue.missingRequiredCookieNames)
    }

    @Test
    fun `关键 Cookie 过期判为未登录并单列过期项`() {
        val cookies = listOf(
            WarehouseCookieRecord("JSESSIONID", "s1", ".school.edu.cn", "/", expiresAtEpochSeconds = 1000L),
        )
        val result = evaluateWarehouseLoginState(
            cookies, listOf("JSESSIONID"), "https://jw.school.edu.cn/xskb/list.do", nowEpochSeconds = 2000L,
        )
        assertEquals(WarehouseLoginState.LOGGED_OUT, result.state)
        assertEquals("过期不是真缺", listOf("JSESSIONID"), result.expiredRequiredCookieNames)
        assertTrue(result.missingRequiredCookieNames.isEmpty())
    }

    @Test
    fun `未配置关键 Cookie 名或地址非法判为未知`() {
        val noNames = evaluateWarehouseLoginState(
            sampleCookies(), emptyList(), "https://jw.school.edu.cn/xskb/list.do", 2000L,
        )
        assertEquals(WarehouseLoginState.UNKNOWN, noNames.state)

        val badUrl = evaluateWarehouseLoginState(
            sampleCookies(), listOf("JSESSIONID"), "ftp://jw.school.edu.cn/", 2000L,
        )
        assertEquals(WarehouseLoginState.UNKNOWN, badUrl.state)
    }

    // -----------------------------------------------------------------------
    // 8. 触发课表抓取适配器的判定
    // -----------------------------------------------------------------------

    private fun loggedInCookies(): List<WarehouseCookieRecord> = listOf(
        WarehouseCookieRecord("JSESSIONID", "s1", ".school.edu.cn", "/"),
    )

    @Test
    fun `登录成立脚本就绪时给出可触发的 Ready`() {
        val plan = planWarehouseTimetableFetch(
            adapterId = " school-x ",
            adapterScript = "  return fetch('/xskb/list.do');  ",
            targetUrl = " https://jw.school.edu.cn/xskb/list.do ",
            cookies = loggedInCookies(),
            requiredCookieNames = listOf("JSESSIONID"),
            nowEpochSeconds = 2000L,
        )
        assertTrue(plan.isReady)
        val ready = plan as WarehouseTimetableFetchPlan.Ready
        assertEquals("school-x", ready.adapterId)
        assertEquals("https://jw.school.edu.cn/xskb/list.do", ready.targetUrl)
        assertEquals("JSESSIONID=s1", ready.cookieHeader)
        assertEquals("return fetch('/xskb/list.do');", ready.adapterScript)
    }

    @Test
    fun `未登录时拒绝触发并回报原因`() {
        val plan = planWarehouseTimetableFetch(
            adapterId = "school-x",
            adapterScript = "return 1;",
            targetUrl = "https://jw.school.edu.cn/xskb/list.do",
            cookies = emptyList(),
            requiredCookieNames = listOf("JSESSIONID"),
            nowEpochSeconds = 2000L,
        )
        assertFalse(plan.isReady)
        val blocked = plan as WarehouseTimetableFetchPlan.Blocked
        assertEquals(WarehouseFetchBlockReason.NOT_LOGGED_IN, blocked.reason)
        assertEquals(WarehouseLoginState.LOGGED_OUT, blocked.evaluation?.state)
    }

    @Test
    fun `未配置关键名判为登录态未知并拒绝触发`() {
        val plan = planWarehouseTimetableFetch(
            adapterId = "school-x",
            adapterScript = "return 1;",
            targetUrl = "https://jw.school.edu.cn/xskb/list.do",
            cookies = loggedInCookies(),
            requiredCookieNames = emptyList(),
            nowEpochSeconds = 2000L,
        )
        assertEquals(
            WarehouseFetchBlockReason.LOGIN_STATE_UNKNOWN,
            (plan as WarehouseTimetableFetchPlan.Blocked).reason,
        )
    }

    @Test
    fun `目标地址非法优先于登录态被拦`() {
        for (bad in listOf(null, "", "not a url", "ftp://jw.school.edu.cn/")) {
            val plan = planWarehouseTimetableFetch(
                adapterId = "school-x",
                adapterScript = "return 1;",
                targetUrl = bad,
                cookies = loggedInCookies(),
                requiredCookieNames = listOf("JSESSIONID"),
                nowEpochSeconds = 2000L,
            )
            assertEquals(
                "目标地址问题应先报 NO_TARGET_URL（$bad）",
                WarehouseFetchBlockReason.NO_TARGET_URL,
                (plan as WarehouseTimetableFetchPlan.Blocked).reason,
            )
        }
    }

    @Test
    fun `登录成立但适配器脚本为空时拒绝触发`() {
        val plan = planWarehouseTimetableFetch(
            adapterId = "school-x",
            adapterScript = "   ",
            targetUrl = "https://jw.school.edu.cn/xskb/list.do",
            cookies = loggedInCookies(),
            requiredCookieNames = listOf("JSESSIONID"),
            nowEpochSeconds = 2000L,
        )
        assertEquals(
            WarehouseFetchBlockReason.NO_ADAPTER_SCRIPT,
            (plan as WarehouseTimetableFetchPlan.Blocked).reason,
        )
    }

    @Test
    fun `空 Cookie 全链路从判定到触发都被拦`() {
        val target = "https://jw.school.edu.cn/xskb/list.do"
        val evaluation = evaluateWarehouseLoginState(emptyList(), listOf("JSESSIONID"), target, 2000L)
        assertEquals(WarehouseLoginState.LOGGED_OUT, evaluation.state)

        val plan = planWarehouseTimetableFetch(
            adapterId = "school-x",
            adapterScript = "return 1;",
            targetUrl = target,
            cookies = emptyList(),
            requiredCookieNames = listOf("JSESSIONID"),
            nowEpochSeconds = 2000L,
        )
        assertFalse(plan.isReady)
    }
}
