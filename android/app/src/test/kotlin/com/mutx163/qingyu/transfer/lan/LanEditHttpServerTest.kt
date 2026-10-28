package com.mutx163.qingyu.transfer.lan

import com.mutx163.qingyu.share.LanEditSession
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.InputStream
import java.net.InetAddress
import java.net.Socket
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * **真 HTTP 往返**测试（L0）：真起 [LanEditHttpServer]、真开 socket、真发请求、真读响应。
 *
 * 为什么值得这么测：这一层的风险全在「socket + 字节流」上——请求行解析、头/体限额、
 * 半途断连、并发连接，单元测试里 mock 掉 socket 就等于什么都没测。
 *
 * 假客户端也用 `java.net.Socket` 自己写：**绝对不能用 `com.sun.net.httpserver`**——
 * 它在 L0 的完整 JDK 里可见、在 Gradle 的 Android 单测编译里不可见，
 * 2026-10-28 已经因此让 CI 红过一次。
 */
class LanEditHttpServerTest {

    private val now = 1_700_000_000_000L

    // -----------------------------------------------------------------------
    // 正常往返
    // -----------------------------------------------------------------------

    @Test
    fun `health 真往返 200 且回 JSON`() {
        withServer { server, port, _ ->
            val raw = exchange(port, "GET /api/v1/health HTTP/1.1\r\nHost: 127.0.0.1:$port\r\n\r\n")
            val response = parseResponse(raw)
            assertEquals(200, response.status)
            assertTrue("必须 JSON", response.header("content-type")!!.startsWith("application/json"))
            assertTrue("一个连接只处理一个请求", response.header("connection") == "close")
            assertTrue(response.body.contains("\"ok\":true"))
        }
    }

    @Test
    fun `握手拿令牌后用令牌读课表 全链路真往返`() {
        val host = FakeLanEditHost()
        host.seed(
            linkedMapOf(
                "id" to "c1",
                "name" to "高等数学",
                "teacher" to "",
                "location" to "",
                "startTime" to "",
                "endTime" to "",
            ),
        )
        val session = session(boundProfileId = "p1")
        withServer(host = host, session = session) { _, port, _ ->
            val verify = parseResponse(
                exchange(
                    port,
                    post(port, "/api/v1/auth/verify", """{"pin":"${session.pin}"}"""),
                ),
            )
            assertEquals(200, verify.status)
            val token = regexValue(verify.body, "token")
            assertEquals(session.token, token)

            val courses = parseResponse(
                exchange(port, "GET /api/v1/courses HTTP/1.1\r\nHost: 127.0.0.1:$port\r\nAuthorization: Bearer $token\r\n\r\n"),
            )
            assertEquals(200, courses.status)
            assertTrue(courses.body.contains("高等数学"))
        }
    }

    // -----------------------------------------------------------------------
    // 状态码矩阵
    // -----------------------------------------------------------------------

    @Test
    fun `400 401 403 404 都在真往返里成立`() {
        val session = session()
        withServer(session = session) { _, port, _ ->
            // 400：畸形请求行
            assertEquals(400, parseResponse(exchange(port, "GET\r\n\r\n")).status)
            // 400：Content-Length 不是数字
            assertEquals(
                400,
                parseResponse(
                    exchange(port, "POST /api/v1/auth/verify HTTP/1.1\r\nHost: h\r\nContent-Length: abc\r\n\r\n"),
                ).status,
            )
            // 401：没有令牌
            assertEquals(401, parseResponse(exchange(port, "GET /api/v1/session HTTP/1.1\r\nHost: h\r\n\r\n")).status)
            // 403：跨源
            assertEquals(
                403,
                parseResponse(
                    exchange(port, "GET /api/v1/health HTTP/1.1\r\nHost: 127.0.0.1\r\nOrigin: http://evil.example\r\n\r\n"),
                ).status,
            )
            // 404：未知路径（带令牌）
            assertEquals(
                404,
                parseResponse(
                    exchange(
                        port,
                        "GET /api/v1/nope HTTP/1.1\r\nHost: h\r\nAuthorization: Bearer ${session.token}\r\n\r\n",
                    ),
                ).status,
            )
            // 204：OPTIONS 预检
            assertEquals(
                204,
                parseResponse(exchange(port, "OPTIONS /api/v1/courses HTTP/1.1\r\nHost: h\r\n\r\n")).status,
            )
        }
    }

    @Test
    fun `429 在真往返里成立`() {
        val session = session()
        withServer(session = session) { _, port, _ ->
            repeat(LanEditSession.MAX_PIN_ATTEMPTS_PER_IP) {
                assertEquals(
                    401,
                    parseResponse(exchange(port, post(port, "/api/v1/auth/verify", """{"pin":"000000"}"""))).status,
                )
            }
            val limited = parseResponse(exchange(port, post(port, "/api/v1/auth/verify", """{"pin":"000000"}""")))
            assertEquals(429, limited.status)
            assertTrue(limited.body.contains("rate_limited"))
        }
    }

    // -----------------------------------------------------------------------
    // 报文越界
    // -----------------------------------------------------------------------

    @Test
    fun `超长头回 431`() {
        withServer { _, port, _ ->
            val big = "X-Big: " + "a".repeat(LanEditHttpLimits.MAX_HEADER_BYTES + LanEditHttpLimits.MAX_REQUEST_LINE_BYTES)
            val response = parseResponse(exchange(port, "GET / HTTP/1.1\r\nHost: h\r\n$big\r\n\r\n"))
            assertEquals(431, response.status)
        }
    }

    @Test
    fun `声明超长体在读之前就回 413`() {
        withServer { _, port, _ ->
            val declared = LanEditHttpLimits.MAX_BODY_BYTES + 1
            val response = parseResponse(
                exchange(
                    port,
                    "POST /api/v1/auth/verify HTTP/1.1\r\nHost: h\r\nContent-Type: application/json\r\n" +
                        "Content-Length: $declared\r\n\r\n",
                ),
            )
            assertEquals(413, response.status)
        }
    }

    @Test
    fun `分块传输编码明确拒掉`() {
        withServer { _, port, _ ->
            val response = parseResponse(
                exchange(
                    port,
                    "POST /api/v1/auth/verify HTTP/1.1\r\nHost: h\r\nContent-Type: application/json\r\n" +
                        "Transfer-Encoding: chunked\r\n\r\n",
                ),
            )
            assertEquals(400, response.status)
        }
    }

    @Test
    fun `只有 LF 没有 CR 的请求行不认`() {
        withServer { _, port, _ ->
            // 头块没有 CRLFCRLF，连接结束时读头会抛「截断」→ 400
            val response = parseResponse(exchange(port, "GET /api/v1/health HTTP/1.1\nHost: h\n\n"))
            assertEquals(400, response.status)
        }
    }

    // -----------------------------------------------------------------------
    // 断连与并发
    // -----------------------------------------------------------------------

    @Test
    fun `请求体半途断连不打死服务端`() {
        withServer { _, port, _ ->
            // 声明 100 字节只发 10 字节就关掉
            Socket("127.0.0.1", port).use { socket ->
                socket.getOutputStream().write(
                    ("POST /api/v1/auth/verify HTTP/1.1\r\nHost: h\r\nContent-Type: application/json\r\n" +
                        "Content-Length: 100\r\n\r\n{\"pin\":\"1\"").toByteArray(),
                )
                socket.getOutputStream().flush()
            }
            // 服务端必须还能正常服务下一个请求（工作线程没被这个连接带走）
            val next = parseResponse(exchange(port, "GET /api/v1/health HTTP/1.1\r\nHost: h\r\n\r\n"))
            assertEquals(200, next.status)
        }
    }

    @Test
    fun `连接开了不发数据 服务端不会卡住其它连接`() {
        withServer { _, port, _ ->
            val idle = Socket("127.0.0.1", port)
            try {
                // 什么都不发：接受线程已经把它派给工作线程，不能让接受线程卡住
                val healthy = parseResponse(exchange(port, "GET /api/v1/health HTTP/1.1\r\nHost: h\r\n\r\n"))
                assertEquals(200, healthy.status)
            } finally {
                idle.close()
            }
        }
    }

    @Test
    fun `一个连接卡在业务层时另一个连接照样能拿到响应`() {
        val host = FakeLanEditHost()
        val session = session()
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        host.onEnsureInitialized = {
            entered.countDown()
            release.await(5, TimeUnit.SECONDS)
        }
        withServer(host = host, session = session) { _, port, _ ->
            var slowResponse: String? = null
            val slow = Thread {
                slowResponse = exchange(
                    port,
                    "GET /api/v1/courses HTTP/1.1\r\nHost: h\r\nAuthorization: Bearer ${session.token}\r\n\r\n",
                )
            }
            slow.isDaemon = true
            slow.start()
            assertTrue("慢请求应已进入业务层", entered.await(5, TimeUnit.SECONDS))

            // 慢请求还卡着，健康检查必须能立刻返回（证明一连接一线程）
            val fast = parseResponse(exchange(port, "GET /api/v1/health HTTP/1.1\r\nHost: h\r\n\r\n"))
            assertEquals(200, fast.status)

            release.countDown()
            slow.join(5_000)
            assertEquals(200, parseResponse(slowResponse ?: "").status)
        }
    }

    @Test
    fun `两个并发连接各拿各的响应`() {
        withServer { _, port, _ ->
            val a = Socket("127.0.0.1", port)
            val b = Socket("127.0.0.1", port)
            try {
                a.getOutputStream().write("GET /api/v1/health HTTP/1.1\r\nHost: h\r\n\r\n".toByteArray())
                a.getOutputStream().flush()
                b.getOutputStream().write("GET /api/v1/health HTTP/1.1\r\nHost: h\r\n\r\n".toByteArray())
                b.getOutputStream().flush()

                val responseA = parseResponse(readAll(a.getInputStream()))
                val responseB = parseResponse(readAll(b.getInputStream()))
                assertEquals(200, responseA.status)
                assertEquals(200, responseB.status)
                assertTrue(responseA.body.contains("\"ok\":true"))
                assertTrue(responseB.body.contains("\"ok\":true"))
            } finally {
                a.close()
                b.close()
            }
        }
    }

    // -----------------------------------------------------------------------
    // 第二切片：新端点的真往返 + 空闲看门狗
    // -----------------------------------------------------------------------

    @Test
    fun `第二切片端点也走真往返 meta 与批量删除与切档案`() {
        val host = FakeLanEditHost()
        host.seed(course("c1", "高等数学"), course("c2", "大学物理"))
        val session = session(boundProfileId = "p1")
        withServer(host = host, session = session) { _, port, _ ->
            val meta = parseResponse(
                exchange(port, "GET /api/v1/meta HTTP/1.1\r\nHost: h\r\nAuthorization: Bearer ${session.token}\r\n\r\n"),
            )
            assertEquals(200, meta.status)
            assertTrue(meta.body.contains("semesterWeekCount"))

            val deleted = parseResponse(
                exchange(
                    port,
                    post(port, "/api/v1/courses/batch-delete", """{"ids":["c1"],"profileId":"p1"}""", session.token),
                ),
            )
            assertEquals(200, deleted.status)
            assertTrue("实际删掉 1 条：${deleted.body}", deleted.body.contains("\"deletedCount\":1"))

            val switched = parseResponse(
                exchange(port, post(port, "/api/v1/profiles/switch", """{"profileId":"p2"}""", session.token)),
            )
            assertEquals(200, switched.status)
            assertTrue(switched.body.contains("\"profileId\":\"p2\""))
        }
    }

    @Test
    fun `会话过期后看门狗自动停服并按 idle_timeout 留审计`() {
        val expired = AtomicBoolean(false)
        val audit = LanEditAuditRingBuffer(clock = { now })
        val session = session()
        val server = LanEditHttpServer(
            router = LanEditApiRouter(host = FakeLanEditHost(), session = session, audit = audit, clock = { now }),
            bindAddress = InetAddress.getByName("127.0.0.1"),
            audit = audit,
            sessionExpired = { expired.get() },
            idleCheckIntervalMillis = 20,
        )
        val port = server.start()
        try {
            // 还没过期时不能自己停
            Thread.sleep(80)
            assertTrue("会话没过期就不该停", server.isRunning)
            assertEquals(200, parseResponse(exchange(port, "GET /api/v1/health HTTP/1.1\r\nHost: h\r\n\r\n")).status)

            expired.set(true)
            val deadline = System.currentTimeMillis() + 5_000
            while (server.isRunning && System.currentTimeMillis() < deadline) {
                Thread.sleep(20)
            }
            assertFalse("会话过期后看门狗必须停服", server.isRunning)
            assertEquals("idle_timeout", audit.snapshot().last().extras["reason"])
        } finally {
            server.stop("test_cleanup")
        }
    }

    @Test
    fun `显式传 null 时不启看门狗`() {
        val audit = LanEditAuditRingBuffer(clock = { now })
        val server = LanEditHttpServer(
            router = LanEditApiRouter(host = FakeLanEditHost(), session = session(), audit = audit, clock = { now }),
            bindAddress = InetAddress.getByName("127.0.0.1"),
            audit = audit,
            sessionExpired = null,
        )
        server.start()
        try {
            Thread.sleep(120)
            assertTrue("没有判据就不该自己停", server.isRunning)
            assertEquals(listOf("lan_edit_session_started"), audit.categories())
        } finally {
            server.stop("test_cleanup")
        }
    }

    @Test
    fun `不传判据时默认按会话过期自动停服`() {
        // 默认值就是 `{ router.isSessionExpired }`：接线的人什么都不传也不会留下挂着的套接字
        val session = session(createdAtMillis = now - LanEditSession.MAX_DURATION_MILLIS - 1)
        val audit = LanEditAuditRingBuffer(clock = { now })
        val server = LanEditHttpServer(
            router = LanEditApiRouter(host = FakeLanEditHost(), session = session, audit = audit, clock = { now }),
            bindAddress = InetAddress.getByName("127.0.0.1"),
            audit = audit,
            idleCheckIntervalMillis = 20,
        )
        server.start()
        try {
            val deadline = System.currentTimeMillis() + 5_000
            while (server.isRunning && System.currentTimeMillis() < deadline) {
                Thread.sleep(20)
            }
            assertFalse("会话早已过期，默认就该自动停服", server.isRunning)
            assertEquals("idle_timeout", audit.snapshot().last().extras["reason"])
        } finally {
            server.stop("test_cleanup")
        }
    }

    // -----------------------------------------------------------------------
    // 生命周期
    // -----------------------------------------------------------------------

    @Test
    fun `端口由系统分配 start 返回真实端口 stop 后不再接受连接`() {
        val session = session()
        val server = LanEditHttpServer(
            router = LanEditApiRouter(host = FakeLanEditHost(), session = session, clock = { now }),
            bindAddress = InetAddress.getByName("127.0.0.1"),
            audit = LanEditAuditRingBuffer(clock = { now }),
        )
        val port = server.start()
        try {
            assertTrue("端口必须 > 0", port > 0)
            assertEquals(port, server.port)
            assertTrue(server.isRunning)
            assertEquals(200, parseResponse(exchange(port, "GET /api/v1/health HTTP/1.1\r\nHost: h\r\n\r\n")).status)
        } finally {
            server.stop("test_done")
        }
        assertFalse(server.isRunning)
        assertEquals(0, server.port)
        // 停服后连接必须被拒
        var refused = false
        try {
            Socket("127.0.0.1", port).use { it.getOutputStream().write("GET / HTTP/1.1\r\n\r\n".toByteArray()) }
        } catch (_: IOException) {
            refused = true
        }
        assertTrue("停服后不应还能连上", refused)
    }

    @Test
    fun `起停会留审计且分类串与 Dart 一致`() {
        val audit = LanEditAuditRingBuffer(clock = { now })
        val server = LanEditHttpServer(
            router = LanEditApiRouter(host = FakeLanEditHost(), session = session(), audit = audit, clock = { now }),
            bindAddress = InetAddress.getByName("127.0.0.1"),
            audit = audit,
        )
        server.start()
        server.stop("test_done")
        assertEquals(listOf("lan_edit_session_started", "lan_edit_session_stopped"), audit.categories())
        assertEquals("test_done", audit.snapshot().last().extras["reason"])
        assertTrue("起服要记端口", (audit.snapshot().first().extras["port"] as Int) > 0)
    }

    @Test
    fun `重复 start 直接抛 重复 stop 是空操作`() {
        val server = LanEditHttpServer(
            router = LanEditApiRouter(host = FakeLanEditHost(), session = session(), clock = { now }),
            bindAddress = InetAddress.getByName("127.0.0.1"),
        )
        server.start()
        try {
            var threw = false
            try {
                server.start()
            } catch (_: IllegalStateException) {
                threw = true
            }
            assertTrue("第二次 start 必须抛 IllegalStateException", threw)
        } finally {
            server.stop("first")
        }
        server.stop("second")
        assertFalse(server.isRunning)
    }

    // -----------------------------------------------------------------------
    // 工具
    // -----------------------------------------------------------------------

    private fun withServer(
        host: LanEditHost = FakeLanEditHost(),
        session: LanEditSession = session(),
        block: (LanEditHttpServer, Int, LanEditSession) -> Unit,
    ) {
        val server = LanEditHttpServer(
            router = LanEditApiRouter(host = host, session = session, clock = { now }),
            bindAddress = InetAddress.getByName("127.0.0.1"),
        )
        val port = server.start()
        try {
            block(server, port, session)
        } finally {
            server.stop("test_done")
        }
    }

    private fun session(
        pin: String = "123456",
        token: String = "tok-abc",
        boundProfileId: String? = null,
        createdAtMillis: Long = now,
    ): LanEditSession = LanEditSession.forTest(
        pin = pin,
        token = token,
        createdAtMillis = createdAtMillis,
        lastActivityAtMillis = now,
        boundProfileId = boundProfileId,
        clockMillis = { now },
    )

    private fun post(port: Int, path: String, body: String, token: String? = null): String {
        val bytes = body.toByteArray(Charsets.UTF_8)
        val auth = if (token != null) "Authorization: Bearer $token\r\n" else ""
        return "POST $path HTTP/1.1\r\nHost: 127.0.0.1:$port\r\nContent-Type: application/json\r\n" +
            "$auth" + "Content-Length: ${bytes.size}\r\n\r\n$body"
    }

    private fun course(id: String, name: String): Map<String, Any?> = linkedMapOf(
        "id" to id,
        "name" to name,
        "teacher" to "",
        "location" to "",
        "startTime" to "",
        "endTime" to "",
    )

    /** 开一个真 socket，发原始请求文本（发完半关写端），读到 EOF。 */
    private fun exchange(port: Int, request: String): String {
        Socket("127.0.0.1", port).use { socket ->
            socket.soTimeout = 10_000
            socket.getOutputStream().write(request.toByteArray(Charsets.UTF_8))
            socket.getOutputStream().flush()
            // 半关写端：请求发完了。这样「只发了半个头」这类用例能让服务端看到 EOF
            // 并立刻回 400，而不是两边互相等对方的超时。
            socket.shutdownOutput()
            return readAll(socket.getInputStream())
        }
    }

    /**
     * 读到 EOF；**容忍连接被重置**。
     *
     * 服务端在「请求头/体超限」这类错误上会直接回错误响应再关连接，此时它自己的接收缓冲里
     * 还有没读完的输入——按 TCP 语义这一关会发 RST。对端已经收到的字节仍然有效
     * （真实浏览器也是这么处理的），所以这里把 RST 当正常结束，而不是让测试假红。
     */
    private fun readAll(input: InputStream): String {
        val out = ByteArrayOutputStream()
        val buffer = ByteArray(4096)
        try {
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                out.write(buffer, 0, read)
            }
        } catch (_: IOException) {
            // RST：已读到的部分照样用
        }
        return out.toByteArray().toString(Charsets.UTF_8)
    }

    private class ParsedResponse(val status: Int, val headers: Map<String, String>, val body: String) {
        fun header(name: String): String? = headers[name.lowercase()]
    }

    private fun parseResponse(raw: String): ParsedResponse {
        assertTrue("响应必须有头块：${raw.take(80)}", raw.contains("\r\n\r\n"))
        val splitAt = raw.indexOf("\r\n\r\n")
        val head = raw.substring(0, splitAt)
        val body = raw.substring(splitAt + 4)
        val lines = head.split("\r\n")
        val statusLine = lines.first()
        assertTrue("状态行形状不对：$statusLine", statusLine.startsWith("HTTP/1.1 "))
        val status = statusLine.split(' ')[1].toInt()
        val headers = LinkedHashMap<String, String>()
        for (line in lines.drop(1)) {
            val colon = line.indexOf(':')
            if (colon <= 0) continue
            headers[line.substring(0, colon).trim().lowercase()] = line.substring(colon + 1).trim()
        }
        return ParsedResponse(status, headers, body)
    }

    private fun regexValue(json: String, key: String): String {
        val pattern = "\"" + key + "\"\\s*:\\s*\"([^\"]*)\""
        return Regex(pattern).find(json)?.groupValues?.get(1).orEmpty()
    }
}
