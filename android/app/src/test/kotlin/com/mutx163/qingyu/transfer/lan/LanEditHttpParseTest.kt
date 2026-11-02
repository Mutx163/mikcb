package com.mutx163.qingyu.transfer.lan

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 报文层纯逻辑单测（L0，无 socket）：
 * 请求行 / 头部 / 查询串 / 百分号解码 / 同源判定 / 响应字节。
 *
 * 期望值来源：RFC 9110 / 9112 的规则，以及 Dart
 * `lib/services/lan_edit_api_handlers.dart` 里同语义分支的行为（逐条注释标明）。
 */
class LanEditHttpParseTest {

    // -----------------------------------------------------------------------
    // 请求行
    // -----------------------------------------------------------------------

    @Test
    fun `请求行按 RFC 严格解析`() {
        val line = LanEditHttpParse.parseRequestLine("GET /api/v1/health HTTP/1.1")
        assertEquals("GET", line.method)
        assertEquals("/api/v1/health", line.target)
        assertEquals("HTTP/1.1", line.version)

        // HTTP/1.0 也收（老浏览器 / 简单客户端）
        assertEquals("HTTP/1.0", LanEditHttpParse.parseRequestLine("GET / HTTP/1.0").version)
        // absolute-form（代理场景）收
        assertEquals(
            "http://192.168.1.5:8080/api/v1/health",
            LanEditHttpParse.parseRequestLine("GET http://192.168.1.5:8080/api/v1/health HTTP/1.1").target,
        )
    }

    @Test
    fun `畸形请求行一律 400`() {
        val bad = listOf(
            "",                                   // 空行
            "GET",                                // 只有方法
            "GET /x",                             // 缺版本
            "GET /x HTTP/1.1 extra",              // 多一段
            "GET  /x HTTP/1.1",                   // 双空格（走私经典形状）
            " GET /x HTTP/1.1",                   // 前导空格
            "GET /x HTTP/1.1 ",                   // 尾随空格
            "G@T /x HTTP/1.1",                    // 方法不是 token
            "GET x HTTP/1.1",                     // target 不是 / 开头也不是 absolute-form
            "GET * HTTP/1.1",                     // authority/asterisk 形态不收
        )
        for (raw in bad) {
            val error = assertFails(raw) { LanEditHttpParse.parseRequestLine(raw) }
            assertEquals("`$raw` 应回 400", 400, error.failure.status)
        }
    }

    @Test
    fun `未知方法与错误版本给 405 与 505`() {
        assertEquals(
            405,
            assertFails("BREW /x HTTP/1.1") { LanEditHttpParse.parseRequestLine("BREW /x HTTP/1.1") }.failure.status,
        )
        assertEquals(
            505,
            assertFails("GET /x HTTP/9.9") { LanEditHttpParse.parseRequestLine("GET /x HTTP/9.9") }.failure.status,
        )
    }

    // -----------------------------------------------------------------------
    // 头部
    // -----------------------------------------------------------------------

    @Test
    fun `头部名小写化并去掉值两侧空白`() {
        val headers = LanEditHttpParse.parseHeaders(
            listOf("Host: 192.168.1.5:8080", "Content-Type:   application/json  ", "Authorization: Bearer abc"),
        )
        assertEquals("192.168.1.5:8080", headers["host"])
        assertEquals("application/json", headers["content-type"])
        assertEquals("Bearer abc", headers["authorization"])
    }

    @Test
    fun `重复头按 RFC 合并但重复 Content-Length 直接拒`() {
        val headers = LanEditHttpParse.parseHeaders(listOf("Accept: a", "Accept: b"))
        assertEquals("a, b", headers["accept"])

        // 两个长度声明是标准的请求走私形状，必须 400
        val error = assertFails("dup content-length") {
            LanEditHttpParse.parseHeaders(listOf("Content-Length: 5", "Content-Length: 9"))
        }
        assertEquals(LanEditHttpFailure.INVALID_CONTENT_LENGTH, error.failure)
    }

    @Test
    fun `折叠头与坏头名一律拒`() {
        // obs-fold：以空格/Tab 续行
        assertEquals(
            LanEditHttpFailure.INVALID_HEADER,
            assertFails("obs-fold") { LanEditHttpParse.parseHeaders(listOf("X-A: 1", "  continued")) }.failure,
        )
        assertEquals(
            LanEditHttpFailure.INVALID_HEADER,
            assertFails("no colon") { LanEditHttpParse.parseHeaders(listOf("NoColonHere")) }.failure,
        )
        assertEquals(
            LanEditHttpFailure.INVALID_HEADER,
            assertFails("bad name") { LanEditHttpParse.parseHeaders(listOf("Bad Name: 1")) }.failure,
        )
    }

    @Test
    fun `头部条数与总字节超限分别给 431`() {
        val many = (1..LanEditHttpLimits.MAX_HEADER_COUNT + 5).map { "X-H$it: v" }
        assertEquals(
            LanEditHttpFailure.TOO_MANY_HEADERS,
            assertFails("too many") { LanEditHttpParse.parseHeaders(many) }.failure,
        )

        val huge = listOf("X-Big: " + "a".repeat(LanEditHttpLimits.MAX_HEADER_BYTES))
        assertEquals(
            LanEditHttpFailure.HEADER_TOO_LARGE,
            assertFails("too large") { LanEditHttpParse.parseHeaders(huge) }.failure,
        )
    }

    // -----------------------------------------------------------------------
    // Content-Length
    // -----------------------------------------------------------------------

    @Test
    fun `Content-Length 缺省为零 坏值 负值 超限分别处理`() {
        assertEquals(0L, LanEditHttpParse.requireContentLength(emptyMap()))
        assertEquals(12L, LanEditHttpParse.requireContentLength(mapOf("content-length" to "12")))
        assertEquals(0L, LanEditHttpParse.requireContentLength(mapOf("content-length" to " 0 ")))

        assertEquals(
            LanEditHttpFailure.INVALID_CONTENT_LENGTH,
            assertFails("non numeric") {
                LanEditHttpParse.requireContentLength(mapOf("content-length" to "12x"))
            }.failure,
        )
        assertEquals(
            LanEditHttpFailure.INVALID_CONTENT_LENGTH,
            assertFails("negative") {
                LanEditHttpParse.requireContentLength(mapOf("content-length" to "-1"))
            }.failure,
        )
        // 声明超限要在「读之前」就拒（否则等于让对端决定我们分配多少内存）
        assertEquals(
            LanEditHttpFailure.BODY_TOO_LARGE,
            assertFails("too large") {
                LanEditHttpParse.requireContentLength(
                    mapOf("content-length" to (LanEditHttpLimits.MAX_BODY_BYTES + 1).toString()),
                )
            }.failure,
        )
        // 分块传输不支持：明确 400，不半信半疑地读
        assertEquals(
            LanEditHttpFailure.INVALID_CONTENT_LENGTH,
            assertFails("chunked") {
                LanEditHttpParse.requireContentLength(mapOf("transfer-encoding" to "chunked"))
            }.failure,
        )
    }

    // -----------------------------------------------------------------------
    // target / 查询串
    // -----------------------------------------------------------------------

    @Test
    fun `target 拆分支持查询串 片段与 absolute_form`() {
        assertEquals("/api/v1/courses" to "", LanEditHttpParse.splitTarget("/api/v1/courses"))
        assertEquals("/api/v1/courses" to "a=1&b=2", LanEditHttpParse.splitTarget("/api/v1/courses?a=1&b=2"))
        assertEquals("/x" to "a=1", LanEditHttpParse.splitTarget("/x?a=1#frag"))
        assertEquals("/y" to "", LanEditHttpParse.splitTarget("/y#frag"))
        assertEquals("/api/v1/health" to "", LanEditHttpParse.splitTarget("http://192.168.1.5:8080/api/v1/health"))
        // absolute-form 没有路径时按根路径
        assertEquals("/" to "", LanEditHttpParse.splitTarget("http://192.168.1.5:8080"))
    }

    @Test
    fun `查询串同名取第一个 加号当空格 支持百分号与中文`() {
        val query = LanEditHttpParse.parseQuery("profileId=p1&profileId=p2&q=a+b&cn=%E4%B8%AD%E6%96%87&empty=")
        assertEquals("p1", query["profileId"])
        assertEquals("a b", query["q"])
        assertEquals("中文", query["cn"])
        assertEquals("", query["empty"])
        assertTrue(LanEditHttpParse.parseQuery("").isEmpty())
        assertTrue(LanEditHttpParse.parseQuery("&&&").isEmpty())
    }

    @Test
    fun `百分号解码按 UTF-8 还原且坏序列原样保留`() {
        // 多字节：%E4%B8%AD 是「中」的三个 UTF-8 字节，逐字节当字符会解成三个拉丁字符
        assertEquals("中", LanEditHttpParse.decodePercent("%E4%B8%AD"))
        assertEquals("中文", LanEditHttpParse.decodePercent("%E4%B8%AD%E6%96%87"))
        assertEquals("a b", LanEditHttpParse.decodePercent("a%20b"))
        // 未转义的原字符（输入里直接带中文）也要按 UTF-8 写回
        assertEquals("中/文", LanEditHttpParse.decodePercent("中%2F文"))
        // 坏序列原样保留，不抛异常（裸 % 不该把整个请求打成 400）
        assertEquals("100%", LanEditHttpParse.decodePercent("100%"))
        assertEquals("%ZZ", LanEditHttpParse.decodePercent("%ZZ"))
        assertEquals("50%off", LanEditHttpParse.decodePercent("50%off"))
        // 路径里的 '+' 是字面量，不当空格
        assertEquals("a+b", LanEditHttpParse.decodePercent("a+b"))
        assertEquals("a b", LanEditHttpParse.decodeFormComponent("a+b"))
    }

    // -----------------------------------------------------------------------
    // 同源判定
    // -----------------------------------------------------------------------

    @Test
    fun `同源判定要求 Origin 与 Host 一致且该 host 必须是本机或私网`() {
        // 同网段电脑访问：Origin 就是页面自己的地址，Host 是手机地址——host 相等且是私网
        assertTrue(request(headers = mapOf("origin" to "http://192.168.1.5:8080", "host" to "192.168.1.5:8080")).isSameOrigin)
        // 端口不同但主机相同也算同源（Dart 只比 host，口径不变）
        assertTrue(request(headers = mapOf("origin" to "http://192.168.1.5:9999", "host" to "192.168.1.5:8080")).isSameOrigin)
        // 手机自己开：127.0.0.1 / localhost / 本机内网 IP 全放行
        assertTrue(request(headers = mapOf("origin" to "http://127.0.0.1:8080", "host" to "127.0.0.1:8080")).isSameOrigin)
        assertTrue(request(headers = mapOf("origin" to "http://localhost:8080", "host" to "localhost:8080")).isSameOrigin)
        assertTrue(request(headers = mapOf("origin" to "http://10.0.0.2:8080", "host" to "10.0.0.2")).isSameOrigin)
        assertTrue(request(headers = mapOf("origin" to "http://172.31.255.254", "host" to "172.31.255.254:8080")).isSameOrigin)
        // IPv6 回环（方括号字面量）也放行
        assertTrue(request(headers = mapOf("origin" to "http://[::1]:8080", "host" to "[::1]:8080")).isSameOrigin)
        // 没有 Origin = 原生客户端，放行
        assertTrue(request(headers = mapOf("host" to "192.168.1.5:8080")).isSameOrigin)

        // Origin: null（sandbox iframe / file://）判不出真实来源：一律拒（旧版放行，2026-11-02 收紧）
        assertFalse(request(headers = mapOf("origin" to "null", "host" to "192.168.1.5:8080")).isSameOrigin)
        assertFalse(request(headers = mapOf("origin" to "NULL", "host" to "192.168.1.5:8080")).isSameOrigin)
        // DNS rebinding：恶意页面把自家域名解析到手机 IP，Origin 与 Host 是同一个外来域名——必须拒
        assertFalse(request(headers = mapOf("origin" to "http://evil.example:8080", "host" to "evil.example:8080")).isSameOrigin)
        // 公网 IP 不算「本机 / 局域网私有网段」
        assertFalse(request(headers = mapOf("origin" to "http://8.8.8.8:8080", "host" to "8.8.8.8:8080")).isSameOrigin)
        // 别的站点打内网地址：host 不等，本来就拒
        assertFalse(request(headers = mapOf("origin" to "http://evil.example", "host" to "192.168.1.5:8080")).isSameOrigin)
        // Origin 有但 Host 缺失：拒（判不出来就不放行）
        assertFalse(request(headers = mapOf("origin" to "http://192.168.1.5")).isSameOrigin)
        // Origin 形状坏掉：拒
        assertFalse(request(headers = mapOf("origin" to "http://", "host" to "192.168.1.5:8080")).isSameOrigin)
        // 大小写：host 一律小写化后比较
        assertTrue(request(headers = mapOf("origin" to "http://LOCALHOST:8080", "host" to "localhost:8080")).isSameOrigin)
    }

    @Test
    fun `本机与私有网段判定 只认地址字面量不认域名`() {
        // 放行清单：localhost、127/8、10/8、172.16/12、192.168/16、169.254/16、
        // ::1、fc00::/7、fe80::/10、IPv4 映射
        for (host in listOf(
            "localhost", "LOCALHOST",
            "127.0.0.1", "127.255.0.7",
            "10.1.2.3",
            "172.16.0.1", "172.31.255.255",
            "192.168.0.0", "192.168.43.1",
            "169.254.10.20",
            "::1", "[::1]",
            "[FD12::A1]", "[fe80::1]",
            "::ffff:192.168.1.5",
        )) {
            assertTrue("应放行：$host", LanEditOriginPolicy.isLocalOrPrivateHost(host))
        }
        // 一律不认：外来域名、公网 / 越界网段、形状判不准的
        for (host in listOf(
            "evil.example", "",
            "0.0.0.0", "8.8.8.8", "11.0.0.1", "100.64.0.1",
            "172.32.0.1", "172.15.0.1",
            "192.169.0.1", "191.168.0.1",
            "192.168.1", "192.168.1.1.1", "192.168.01.1", "192.168.256.1",
            "abc", "::", "::2", "[fd1::]",
        )) {
            assertFalse("应拒绝：$host", LanEditOriginPolicy.isLocalOrPrivateHost(host))
        }
    }

    @Test
    fun `Bearer 令牌只认 Bearer 前缀`() {
        assertEquals("abc", request(headers = mapOf("authorization" to "Bearer abc")).bearerToken)
        assertEquals("abc", request(headers = mapOf("authorization" to "Bearer   abc  ")).bearerToken)
        assertNull(request(headers = mapOf("authorization" to "Basic abc")).bearerToken)
        assertNull(request(headers = mapOf("authorization" to "bearer abc")).bearerToken)
        assertNull(request().bearerToken)
    }

    @Test
    fun `Content-Type 只取 mime 部分`() {
        assertEquals(
            "application/json",
            request(headers = mapOf("content-type" to "application/json; charset=utf-8")).contentTypeMime,
        )
        assertEquals(
            "application/json",
            request(headers = mapOf("content-type" to "  Application/JSON ")).contentTypeMime,
        )
        assertEquals("", request().contentTypeMime)
    }

    // -----------------------------------------------------------------------
    // 响应字节
    // -----------------------------------------------------------------------

    @Test
    fun `响应序列化带状态行 Content-Length 与 Connection close`() {
        val bytes = LanEditHttpResponse.json(200, linkedMapOf<String, Any?>("ok" to true)).toByteArray()
        val text = bytes.toString(Charsets.UTF_8)
        assertTrue(text.startsWith("HTTP/1.1 200 OK\r\n"))
        assertTrue(text.contains("Content-Type: application/json; charset=utf-8\r\n"))
        assertTrue(text.contains("Cache-Control: no-store\r\n"))
        assertTrue(text.contains("Content-Length: 11\r\n"))
        assertTrue(text.contains("Connection: close\r\n"))
        assertTrue(text.endsWith("\r\n\r\n{\"ok\":true}"))
    }

    @Test
    fun `204 与 304 不带体也不带 Content-Length`() {
        val bytes = LanEditHttpResponse.empty(204).toByteArray().toString(Charsets.UTF_8)
        assertEquals("HTTP/1.1 204 No Content\r\nConnection: close\r\n\r\n", bytes)
        val notModified = LanEditHttpResponse(status = 304, body = "ignored".toByteArray()).toByteArray()
            .toString(Charsets.UTF_8)
        assertFalse(notModified.contains("Content-Length"))
        assertFalse(notModified.contains("ignored"))
    }

    @Test
    fun `错误响应体形状与 Dart 一致`() {
        val text = LanEditHttpResponse.error(401, "invalid_pin", "Invalid PIN").toByteArray().toString(Charsets.UTF_8)
        assertTrue(text.startsWith("HTTP/1.1 401 Unauthorized\r\n"))
        assertTrue(text.endsWith("""{"error":"invalid_pin","message":"Invalid PIN"}"""))
    }

    @Test
    fun `未知状态码有兜底 reason 且状态行合法`() {
        val text = LanEditHttpResponse.empty(599).toByteArray().toString(Charsets.UTF_8)
        assertTrue(text.startsWith("HTTP/1.1 599 Unknown\r\n"))
        assertEquals("Request Header Fields Too Large", LanEditHttpStatus.reason(431))
        assertEquals("Content Too Large", LanEditHttpStatus.reason(413))
    }

    // -----------------------------------------------------------------------
    // 在飞体预算闸门
    // -----------------------------------------------------------------------

    @Test
    fun `请求体预算闸门 要么全拿要么不动 释放归还且不放大`() {
        val budget = LanEditBodyBudget(maxBytes = 100)
        assertTrue(budget.tryAcquire(60))
        assertEquals(40L, budget.availableBytes())
        // 剩余不足：拒绝且预算一个字节都不动
        assertFalse(budget.tryAcquire(41))
        assertEquals(40L, budget.availableBytes())
        assertTrue(budget.tryAcquire(40))
        assertEquals(0L, budget.availableBytes())
        // 零字节体（GET 等）不占预算
        assertTrue(budget.tryAcquire(0))
        assertEquals(0L, budget.availableBytes())
        // 释放归还；重复释放被钳制回上限
        budget.release(20)
        assertEquals(20L, budget.availableBytes())
        budget.release(1000)
        assertEquals(100L, budget.availableBytes())
    }

    @Test
    fun `请求体预算闸门 初始等于上限且可并发收支`() {
        val budget = LanEditBodyBudget(maxBytes = LanEditHttpLimits.MAX_INFLIGHT_BODY_BYTES)
        assertEquals(LanEditHttpLimits.MAX_INFLIGHT_BODY_BYTES, budget.availableBytes())

        // 并发收支总量守恒：8 个线程各拿 1 MiB 放 1 MiB，循环后预算必须回到满额
        val workers = (1..8).map {
            Thread {
                repeat(50) {
                    if (budget.tryAcquire(1024 * 1024)) {
                        budget.release(1024 * 1024)
                    }
                }
            }.apply { start() }
        }
        workers.forEach { it.join(5_000) }
        assertEquals(LanEditHttpLimits.MAX_INFLIGHT_BODY_BYTES, budget.availableBytes())
    }

    // -----------------------------------------------------------------------
    // 工具
    // -----------------------------------------------------------------------

    private fun request(
        method: String = "GET",
        target: String = "/api/v1/health",
        headers: Map<String, String> = emptyMap(),
        body: String = "",
        remoteAddress: String = "192.168.1.9",
    ): LanEditHttpRequest {
        val (path, queryString) = LanEditHttpParse.splitTarget(target)
        return LanEditHttpRequest(
            method = method,
            target = target,
            path = path,
            query = LanEditHttpParse.parseQuery(queryString),
            headers = headers,
            body = body,
            remoteAddress = remoteAddress,
        )
    }

    private fun assertFails(label: String, block: () -> Unit): LanEditHttpException {
        try {
            block()
        } catch (error: LanEditHttpException) {
            return error
        }
        throw AssertionError("`$label` 应该抛 LanEditHttpException，但没抛")
    }
}
