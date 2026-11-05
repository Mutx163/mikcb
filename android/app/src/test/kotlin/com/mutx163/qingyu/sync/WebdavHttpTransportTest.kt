package com.mutx163.qingyu.sync

import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.net.HttpURLConnection
import java.net.InetAddress
import java.net.ProtocolException
import java.net.ServerSocket
import java.net.Socket
import java.net.URL
import java.util.Collections
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import org.junit.AfterClass
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.BeforeClass
import org.junit.Test

/**
 * WebDAV 传输层的**真 HTTP 往返**测试。
 *
 * 假 WebDAV 服务是**手写 HTTP/1.1 的裸 socket 服务器**（[FakeWebdavServer]，只用 `java.net.*`），
 * 断言的是**人推的**线格式：请求方法 / 路径 / 头，响应状态码 / 体 / ETag。
 * 覆盖：正常往返、401、404、空体、连接失败、读超时、重定向（跟随 / 环 / 非 http 目标）、
 * 非 UTF-8 字节、超长响应体、PROPFIND 解析、PUT / MKCOL / DELETE / HEAD / LOCK / UNLOCK。
 *
 * **为什么不用 `com.sun.net.httpserver.HttpServer`**（2026-10-28 踩过，别再改回去）：
 * 它属于 `com.sun.*`，不在 AGP 单测编译平台的 system-modules jar 里（那里只有受支持的 JDK API），
 * 于是 `:app:compileProdDebugUnitTestKotlin`（CI 跑的 `:app:testProdDebugUnitTest` 的编译阶段）
 * 直接报 `Unresolved reference 'sun'`，而 `scripts/test-kotlin-module.ps1`（L0）用完整 JDK 全绿——
 * **L0 绿 ≠ CI 绿**。`java.net.*` 两边都可用，所以这里自己写一个。
 *
 * **确定性约束（2026-11-04，消除 getBytesGivesUpAfterMaxRedirects 偶发 connection_failed）**：
 * 1. 整个类只 bind 一个监听端口（[startSharedServer]），用例之间只 reset handler/请求记录，
 *    不再每个用例 `ServerSocket(0)` bind/close 一次——临时端口被系统回收再分配时，
 *    上一个用例的残留 socket 可能和新监听的端口撞上，表现为随机 `connection_failed`。
 * 2. `handler` 是 `@Volatile`：worker 线程在构造时启动，用例线程随后赋值，JMM 必须给可见性。
 * 3. `close()` 先关 listener、再关已 accept 的连接、最后 join worker，用例结束不留活 socket。
 * 4. 读超时用例用 `CountDownLatch` 卡住 handler，不再 `Thread.sleep(3s)`（异步释放，零空转）。
 * 5. `http.keepAlive=false`：关掉 JDK 按 host:port 复用的连接池，避免复用到指向旧服务器的连接。
 */
class WebdavHttpTransportTest {

    private lateinit var server: FakeWebdavServer

    @Before
    fun setUp() {
        // 整个类共用一个监听端口：不再每个用例 bind/close 一次临时端口，
        // 杜绝「上一个用例的残留 socket 被下一个用例的 ServerSocket(0) 撞上」。
        server = sharedServer
        server.reset()
    }

    private fun transport(
        username: String = "u",
        password: String = "p",
        timeoutMillis: Long = 5_000,
        maxResponseBytes: Long = DEFAULT_MAX_RESPONSE_BYTES,
        maxRedirects: Int = DEFAULT_MAX_REDIRECTS,
    ): WebdavHttpTransport = WebdavHttpTransport(
        endpoint = WebdavEndpoint(server.baseUrl, username, password),
        timeoutMillis = timeoutMillis,
        maxResponseBytes = maxResponseBytes,
        maxRedirects = maxRedirects,
    )

    // ---------- GET 正常往返 ----------

    @Test
    fun getBytesRoundTripSendsMethodPathAndBasicAuth() {
        val payload = byteArrayOf(1, 2, 3, 4, 5)
        server.handler = { exchange, _ -> exchange.respond(200, payload) }

        val result = transport().getBytes("/Apps/qingyu-sync/snapshot.mikcb")

        assertFalse(result.isFailed)
        assertFalse(result.isNotFound)
        assertArrayEquals(payload, result.bytes)
        assertEquals(1, server.requests.size)
        assertEquals("GET", server.requests[0].method)
        assertEquals("/dav/Apps/qingyu-sync/snapshot.mikcb", server.requests[0].path)
        // base64("u:p") = "dTpw"
        assertEquals("Basic dTpw", server.requests[0].authorization)
    }

    @Test
    fun getBytesOmitsAuthorizationWhenCredentialsEmpty() {
        server.handler = { exchange, _ -> exchange.respond(200, byteArrayOf(9)) }

        val result = transport(username = "", password = "").getBytes("/x.mikcb")

        assertArrayEquals(byteArrayOf(9), result.bytes)
        assertNull(server.requests[0].authorization)
    }

    // ---------- GET 失败面 ----------

    @Test
    fun getBytesMaps401ToAuthFailed() {
        server.handler = { exchange, _ ->
            exchange.respond(401, ByteArray(0), mapOf("WWW-Authenticate" to "Basic realm=\"dav\""))
        }

        val result = transport().getBytes("/x.mikcb")

        assertTrue(result.isFailed)
        assertFalse(result.isNotFound)
        assertEquals("auth_failed", result.errorMessage)
    }

    @Test
    fun getBytesMaps404ToNotFound() {
        server.handler = { exchange, _ -> exchange.respond(404, "no such file".toByteArray()) }

        val result = transport().getBytes("/x.mikcb")

        assertFalse(result.isFailed)
        assertTrue(result.isNotFound)
        assertNull(result.errorMessage)
    }

    @Test
    fun getBytesTreatsEmpty200BodyAsNotFound() {
        // Dart getBytesResult 原样：空体当缺失（不是空文件）。
        server.handler = { exchange, _ -> exchange.respond(200, ByteArray(0)) }

        val result = transport().getBytes("/x.mikcb")

        assertFalse(result.isFailed)
        assertTrue(result.isNotFound)
    }

    @Test
    fun getBytesFailsOnConnectionRefused() {
        val deadPort = ServerSocket(0).use { it.localPort }
        val dead = WebdavHttpTransport(
            WebdavEndpoint("http://127.0.0.1:$deadPort/dav/", "", ""),
            timeoutMillis = 5_000,
        )

        val result = dead.getBytes("/x.mikcb")

        assertTrue(result.isFailed)
        assertEquals("connection_failed", result.errorMessage)
    }

    @Test
    fun getBytesFailsOnReadTimeout() {
        // 用 latch 卡住 handler，而不是 Thread.sleep：用例结束立刻释放，
        // 不给下一个用例留下「活着的连接 + 被占用的临时端口」。
        val release = CountDownLatch(1)
        server.handler = { exchange, _ ->
            release.await(5, TimeUnit.SECONDS)
            exchange.respond(200, byteArrayOf(1))
        }

        try {
            val result = transport(timeoutMillis = 400).getBytes("/slow.mikcb")

            assertTrue(result.isFailed)
            assertEquals("connection_timeout", result.errorMessage)
        } finally {
            release.countDown()
            // 2026-11-05：读重试的第二笔（GET /slow.mikcb）由共享 worker 在 countDown
            // **之后**才记账（worker 被 latch 卡住，直到这里才醒）——不等它记完就让位，
            // 这条 stale 请求会漏进下一个用例的日志（实测把 ensureRemoteFolder 的
            // 计数顶成 3）。等齐两笔再收尾，竞态消除。
            val deadline = System.currentTimeMillis() + 2_000
            while (server.requests.size < 2 && System.currentTimeMillis() < deadline) {
                Thread.sleep(10)
            }
        }
    }

    @Test
    fun getBytesRejectsBodyOverLimit() {
        server.handler = { exchange, _ -> exchange.respond(200, ByteArray(200) { 7 }) }

        val result = transport(maxResponseBytes = 64).getBytes("/big.mikcb")

        assertTrue(result.isFailed)
        assertEquals("invalid_response", result.errorMessage)
        assertNull(result.bytes)
    }

    @Test
    fun propfindRejectsBodyCutShortByEarlyDisconnect() {
        // 成员八复核③（裸 socket 路径）：声明的 Content-Length 比实发多 50、提前断开 =
        // 半截 PROPFIND 响应，必须判 truncated → invalid_response。readBounded
        // （HttpURLConnection 路径）的同类破口已排下一轮（复核员口径：契约破口、非必然
        // 脏数据），本用例只钉 raw 路径。判别力关键：**体本身是完整可解析的 XML**——
        // 探针态（truncated=false）解析照样成功、用例才会翻红；发二进制垃圾会让两个
        // 分支都判 invalid_response，探针打不红。
        val fullBody = HISTORY_MULTISTATUS.toByteArray(Charsets.UTF_8)
        server.handler = { exchange, _ ->
            exchange.respond(207, fullBody, mapOf("Content-Length" to "${fullBody.size + 50}"))
        }

        val result = transport().propfind("/Apps/qingyu-sync/history/", depth = 1)

        assertTrue(result.isFailed)
        assertEquals("invalid_response", result.errorMessage)
    }

    @Test
    fun getBytesAcceptsBodyExactlyAtLimit() {
        server.handler = { exchange, _ -> exchange.respond(200, ByteArray(64) { 3 }) }

        val result = transport(maxResponseBytes = 64).getBytes("/exact.mikcb")

        assertFalse(result.isFailed)
        assertEquals(64, result.bytes?.size)
    }

    @Test
    fun getBytesReturnsNonUtf8BodyByteExact() {
        // 0x80..0xFF 不是合法 UTF-8 起始序列；传输层不许解码/重编码，必须逐字节原样。
        val binary = ByteArray(256) { it.toByte() }
        server.handler = { exchange, _ -> exchange.respond(200, binary) }

        val result = transport().getBytes("/binary.mikcb")

        assertFalse(result.isFailed)
        assertArrayEquals(binary, result.bytes)
        assertEquals(256, result.bytes?.size)
    }

    // ---------- 重定向 ----------

    @Test
    fun getBytesFollowsRedirectKeepingMethodAndReturnsFinalBody() {
        server.handler = { exchange, _ ->
            when (exchange.requestURI.path) {
                "/dav/old.mikcb" -> exchange.respond(302, ByteArray(0), mapOf("Location" to "/dav/new.mikcb"))
                "/dav/new.mikcb" -> exchange.respond(200, "payload".toByteArray())
                else -> exchange.respond(404)
            }
        }

        val result = transport().getBytes("/old.mikcb")

        assertFalse(result.isFailed)
        assertArrayEquals("payload".toByteArray(), result.bytes)
        assertEquals(2, server.requests.size)
        assertEquals(listOf("GET", "GET"), server.requests.map { it.method })
        assertEquals("/dav/new.mikcb", server.requests[1].path)
    }

    @Test
    fun getBytesGivesUpAfterMaxRedirects() {
        server.handler = { exchange, _ ->
            when (exchange.requestURI.path) {
                "/dav/loop-a" -> exchange.respond(302, ByteArray(0), mapOf("Location" to "/dav/loop-b"))
                "/dav/loop-b" -> exchange.respond(302, ByteArray(0), mapOf("Location" to "/dav/loop-a"))
                else -> exchange.respond(404)
            }
        }

        val result = transport(maxRedirects = 3).getBytes("/loop-a")

        assertTrue(result.isFailed)
        assertEquals("invalid_response", result.errorMessage)
        // 首次请求 + 3 跳 = 4 次，第 4 次拿到的仍是 302，不再跟随。
        assertEquals(4, server.requests.size)
        assertEquals(
            listOf("/dav/loop-a", "/dav/loop-b", "/dav/loop-a", "/dav/loop-b"),
            server.requests.map { it.path },
        )
    }

    // ---------- 重定向凭据安全门（2026-11-05 成员八复核①） ----------

    /**
     * 凭据安全门的纯函数分支全覆盖：同 origin 放行；跨 host / 跨端口 / https→http
     * 降级 / 非 http(s) 目标一律拦。咬合探针：删掉 [WebdavHttpTransport.executeOnce]
     * 里的 `isCredentialSafeRedirect` 调用 → 下面的跨 origin 集成用例必红。
     */
    @Test
    fun redirectCredentialGateAllowsSameOriginOnly() {
        // 同 host 同 scheme 同端口（常规 302 集合路径规范化）→ 跟随
        assertTrue(isCredentialSafeRedirect("http://nas.local:5005/dav/a", "http://nas.local:5005/dav/b"))
        assertTrue(isCredentialSafeRedirect("https://nas.local/dav/a", "https://nas.local/dav/b"))
        // 跨 host（哪怕 https → https）→ 拦：口令不能去别的域
        assertFalse(isCredentialSafeRedirect("https://nas.local/dav/a", "https://evil.example.com/dav/b"))
        // 同 scheme 换端口 = 可能是同机另一个服务 → 拦
        assertFalse(isCredentialSafeRedirect("http://nas.local:5005/dav/a", "http://nas.local:9090/dav/b"))
        // https → http（同 host）= 降级明文 → 拦
        assertFalse(isCredentialSafeRedirect("https://nas.local/dav/a", "http://nas.local/dav/b"))
        // http → https 同 host = 升级 → 放行（口径 2026-11-05 调整：凭据已在 http 上
        // 暴露过，升级只会更好；真实 force-TLS 服务端的 302 不被打断）
        assertTrue(isCredentialSafeRedirect("http://nas.local/dav/a", "https://nas.local/dav/b"))
        // 升级的伴随端口变化（:8080 → :443）按「scheme 变了」处理，同样放行
        assertTrue(isCredentialSafeRedirect("http://nas.local:8080/dav/a", "https://nas.local/dav/b"))
    }

    /**
     * 跨 origin 302 端到端：源站 302 到另一台假服务器，门必须拦下——
     * **目标服务器零请求**（凭据根本没离开源站，`Authorization` 无处可送），
     * 结果按失败分类（3xx 原样返回，与跳数耗尽同一条出口）。
     */
    @Test
    fun redirectsToAnotherOriginAreNotFollowedAndLeakNoCredentials() {
        val target = FakeWebdavServer()
        try {
            server.handler = { exchange, _ ->
                exchange.respond(302, ByteArray(0), mapOf("Location" to "${target.baseUrl}evil.mikcb"))
            }

            val result = transport().getBytes("/old.mikcb")

            assertTrue(result.isFailed)
            // 钱断言：目标 origin 一个字节都没收到——凭据根本没出源站。
            assertEquals(0, target.requests.size)
            // 源站只有最初那一笔 GET（带合法 Basic，本就该带）。
            assertEquals(1, server.requests.size)
            assertEquals("Basic dTpw", server.requests[0].authorization)
        } finally {
            target.close()
        }
    }

    @Test
    fun getBytesDoesNotFollowRedirectToNonHttpScheme() {
        server.handler = { exchange, _ ->
            if (exchange.requestURI.path == "/dav/a.mikcb") {
                exchange.respond(301, ByteArray(0), mapOf("Location" to "ftp://example.com/a.mikcb"))
            } else {
                exchange.respond(404)
            }
        }

        val result = transport().getBytes("/a.mikcb")

        assertTrue(result.isFailed)
        assertEquals("invalid_response", result.errorMessage)
        assertEquals(1, server.requests.size)
    }

    // ---------- PROPFIND / listing / ETag ----------

    @Test
    fun propfindSendsDepthAndXmlBodyThenParsesListing() {
        server.handler = { exchange, _ -> exchange.respondText(207, HISTORY_MULTISTATUS) }

        val result = transport().propfind("/Apps/qingyu-sync/history/", depth = 1)

        assertFalse(result.isFailed)
        assertEquals(5, result.resources.size)
        assertEquals("PROPFIND", server.requests[0].method)
        assertEquals("/dav/Apps/qingyu-sync/history/", server.requests[0].path)
        assertEquals("1", server.requests[0].depth)
        assertTrue(String(server.requests[0].body, Charsets.UTF_8).contains("<d:propfind"))
        assertTrue(
            String(server.requests[0].body, Charsets.UTF_8).contains("<d:getetag/>"),
        )
        assertEquals(
            listOf("snapshot-abc-123-dev.mikcb", "备份-2026.mikcb"),
            historyFileNamesFromResources(result.resources),
        )
    }

    @Test
    fun propfindUsesDepthZeroForSingleResource() {
        server.handler = { exchange, _ -> exchange.respondText(207, SINGLE_MULTISTATUS) }

        val result = transport().propfind("/Apps/qingyu-sync/snapshot.mikcb", depth = 0)

        assertFalse(result.isFailed)
        assertEquals(1, result.resources.size)
        assertEquals("0", server.requests[0].depth)
    }

    @Test
    fun propfindMaps404ToNotFoundAnd500ToInvalidResponse() {
        server.handler = { exchange, _ -> exchange.respond(404, ByteArray(0)) }
        val missing = transport().propfind("/Apps/gone/", depth = 1)
        assertTrue(missing.isNotFound)
        assertFalse(missing.isFailed)

        server.handler = { exchange, _ -> exchange.respond(500, "boom".toByteArray()) }
        val broken = transport().propfind("/Apps/x/", depth = 1)
        assertTrue(broken.isFailed)
        assertEquals("invalid_response", broken.errorMessage)
    }

    @Test
    fun propfindFailsCleanlyOnMalformedXml() {
        server.handler = { exchange, _ -> exchange.respondText(207, "<multistatus><response>") }

        val result = transport().propfind("/Apps/x/", depth = 1)

        assertTrue(result.isFailed)
        assertEquals("invalid_response", result.errorMessage)
    }

    @Test
    fun listHistoryBackupFilesKeepsOnlyMikcbFiles() {
        server.handler = { exchange, _ -> exchange.respondText(207, HISTORY_MULTISTATUS) }

        val result = transport().listHistoryBackupFiles("/Apps/qingyu-sync/history/")

        assertFalse(result.isFailed)
        assertFalse(result.isNotFound)
        assertEquals(listOf("snapshot-abc-123-dev.mikcb", "备份-2026.mikcb"), result.fileNames)
    }

    @Test
    fun listHistoryBackupFilesMaps404ToNotFound() {
        server.handler = { exchange, _ -> exchange.respond(404, ByteArray(0)) }

        val result = transport().listHistoryBackupFiles("/Apps/qingyu-sync/history/")

        assertFalse(result.isFailed)
        assertTrue(result.isNotFound)
    }

    @Test
    fun getRemoteEtagReadsNormalizedEtagFromPropfind() {
        server.handler = { exchange, _ -> exchange.respondText(207, SINGLE_MULTISTATUS) }

        val etag = transport().getRemoteEtag("/Apps/qingyu-sync/snapshot.mikcb")

        assertEquals("rev-9", etag)
        assertEquals("PROPFIND", server.requests[0].method)
        assertEquals("0", server.requests[0].depth)
    }

    @Test
    fun getRemoteEtagReturnsNullWhenServerOmitsEtag() {
        server.handler = { exchange, _ -> exchange.respondText(207, MULTISTATUS_WITHOUT_ETAG) }

        assertNull(transport().getRemoteEtag("/Apps/qingyu-sync/snapshot.mikcb"))
    }

    // ---------- PUT / MKCOL / DELETE / HEAD ----------

    @Test
    fun putBytesSendsExactBodyAndReturnsEtag() {
        val payload = "snapshot-body".toByteArray()
        server.handler = { exchange, _ ->
            exchange.respond(201, ByteArray(0), mapOf("ETag" to "\"rev-1\""))
        }

        val result = transport().putBytes("/Apps/qingyu-sync/snapshot.mikcb", payload)

        assertFalse(result.isFailed)
        assertEquals(201, result.statusCode)
        assertEquals("rev-1", result.etag)
        assertEquals("PUT", server.requests[0].method)
        assertEquals("/dav/Apps/qingyu-sync/snapshot.mikcb", server.requests[0].path)
        assertEquals("application/octet-stream", server.requests[0].contentType)
        assertArrayEquals(payload, server.requests[0].body)
    }

    @Test
    fun putBytesSendsLockTokenAsIfHeader() {
        server.handler = { exchange, _ -> exchange.respond(204, ByteArray(0)) }

        val result = transport().putBytes(
            "/Apps/qingyu-sync/snapshot.mikcb",
            byteArrayOf(1),
            lockToken = "opaquelocktoken:abc",
        )

        assertFalse(result.isFailed)
        assertEquals("(<opaquelocktoken:abc>)", server.requests[0].ifHeader)
    }

    @Test
    fun putBytesMaps401AndReportsNoEtag() {
        server.handler = { exchange, _ -> exchange.respond(401, ByteArray(0)) }

        val result = transport().putBytes("/x.mikcb", byteArrayOf(1))

        assertTrue(result.isFailed)
        assertEquals("auth_failed", result.errorMessage)
        assertEquals(401, result.statusCode)
        assertNull(result.etag)
    }

    @Test
    fun putBytesMaps404ToInvalidResponse() {
        server.handler = { exchange, _ -> exchange.respond(404, ByteArray(0)) }

        val result = transport().putBytes("/missing-parent/x.mikcb", byteArrayOf(1))

        assertTrue(result.isFailed)
        assertEquals("invalid_response", result.errorMessage)
    }

    @Test
    fun mkcolTreats405AsAlreadyExists() {
        server.handler = { exchange, _ -> exchange.respond(405, "already there".toByteArray()) }

        val result = transport().mkcol("/Apps/qingyu-sync/history/")

        assertFalse(result.isFailed)
        assertTrue(result.alreadyExists)
        assertEquals("MKCOL", server.requests[0].method)
        assertEquals("/dav/Apps/qingyu-sync/history/", server.requests[0].path)
    }

    @Test
    fun mkcolReportsFailureOn403() {
        server.handler = { exchange, _ -> exchange.respond(403, ByteArray(0)) }

        val result = transport().mkcol("/Apps/qingyu-sync/")

        assertTrue(result.isFailed)
        assertEquals("access_denied", result.errorMessage)
    }

    @Test
    fun ensureRemoteFolderCreatesEachSegmentInOrder() {
        server.handler = { exchange, _ -> exchange.respond(201, ByteArray(0)) }

        val result = transport().ensureRemoteFolder("/Apps/qingyu-sync/")

        assertFalse(result.isFailed)
        assertEquals(listOf("/dav/Apps/", "/dav/Apps/qingyu-sync/"), server.requests.map { it.path })
        assertEquals(listOf("MKCOL", "MKCOL"), server.requests.map { it.method })
    }

    @Test
    fun ensureRemoteFolderStopsAtFirstHardFailure() {
        server.handler = { exchange, _ ->
            if (exchange.requestURI.path == "/dav/Apps/") {
                exchange.respond(201, ByteArray(0))
            } else {
                exchange.respond(403, ByteArray(0))
            }
        }

        val result = transport().ensureRemoteFolder("/Apps/qingyu-sync/")

        assertTrue(result.isFailed)
        assertEquals("access_denied", result.errorMessage)
        // 只数本用例的两笔 MKCOL：共享假服务器的 worker 是独立线程，前一个用例
        // （读超时 + 重试）的记账与 reset() 之间存在跨用例竞态，直接数 size 会被
        // stale 请求污染成 3（2026-11-05 实测）。写操作不重试由下方
        // writeOperationsAreNotRetriedOnTransportFailure 按路径直接钉死。
        assertEquals(
            listOf("/dav/Apps/", "/dav/Apps/qingyu-sync/"),
            server.requests.filter { it.method == "MKCOL" }.map { it.path },
        )
    }

    /**
     * 「写操作传输失败**不重试**」的直接断言（2026-11-05 审核修复配套）。
     *
     * MKCOL / PUT 在传输层瞬时失败（handler 拖过客户端读超时）后必须**只发一次**：
     * 重发 = 重复建目录 / 重复上传（首次写可能已落盘，只是响应丢了），属数据安全事故。
     * 按请求路径直接计数，不依赖整条日志的 size（对跨用例 stale 免疫）。
     * 咬合探针：把 [WebdavHttpTransport.execute] 的幂等读门放开到 MKCOL/PUT，本用例必红
     * （重试笔会被空闲 worker 立刻记账并回 201，`isFailed` 断言先翻、计数随后翻）。
     *
     * 可观测性设计：handler 对**第一次**请求拖 600ms（> 客户端 400ms 读超时 ⇒ 触发
     * 传输失败），之后立即应答——这样若门被误放开，重试笔（退避 800ms 后到达）会被
     * 空闲的 worker 马上记账并得到 201，结果从「失败」翻成「成功」，探针才真的会红。
     * （latch 挂死 worker 的形态会让重试笔进 backlog 永远不被记账，探针打不红，弃用。）
     */
    @Test
    fun writeOperationsAreNotRetriedOnTransportFailure() {
        val firstRequestHung = AtomicBoolean(true)
        server.handler = { exchange, _ ->
            if (firstRequestHung.getAndSet(false)) {
                // 只拖第一次：客户端 400ms 读超时 < 600ms，必然传输失败。
                Thread.sleep(600)
            }
            exchange.respond(201, ByteArray(0))
        }
        try {
            val mkcolResult = transport(timeoutMillis = 400).mkcol("/Apps/x/")
            assertTrue("写操作（MKCOL）传输失败必须报失败", mkcolResult.isFailed)
            // 观察窗覆盖「退避 800ms + 第二次尝试」的最晚到达时刻：有重试这里必多一笔。
            Thread.sleep(1_500)
            assertEquals(
                "写操作（MKCOL）传输失败不得重发",
                1,
                server.requests.count { it.path == "/dav/Apps/x/" },
            )

            // PUT 阶段：重新挂起第一次请求，同口径再钉一遍（HttpURLConnection 路径）。
            firstRequestHung.set(true)
            val putResult = transport(timeoutMillis = 400).putBytes("/Apps/x.bin", byteArrayOf(1))
            assertTrue("写操作（PUT）传输失败必须报失败", putResult.isFailed)
            Thread.sleep(1_500)
            assertEquals(
                "写操作（PUT）传输失败不得重发",
                1,
                server.requests.count { it.path == "/dav/Apps/x.bin" },
            )
        } finally {
            // handler 的 600ms 拖延可能仍未醒（探针态下已立即应答），给一点收尾余量，
            // 避免尾部响应写进后续用例的连接。
            Thread.sleep(700)
        }
    }

    @Test
    fun deleteRemoteFileAccepts204ThenReports404AsNotFound() {
        var deleted = false
        server.handler = { exchange, _ ->
            if (deleted) exchange.respond(404, ByteArray(0)) else exchange.respond(204, ByteArray(0))
        }

        val first = transport().deleteRemoteFile("/Apps/qingyu-sync/history/old.mikcb")
        assertFalse(first.isFailed)
        assertFalse(first.notFound)
        assertEquals(204, first.statusCode)

        deleted = true
        val second = transport().deleteRemoteFile("/Apps/qingyu-sync/history/old.mikcb")
        assertFalse(second.isFailed)
        assertTrue(second.notFound)
        assertEquals("DELETE", server.requests[1].method)
    }

    @Test
    fun headReportsLengthAndEtagFromHeaders() {
        server.handler = { exchange, _ ->
            // HEAD 不发体，但要声明真实的 Content-Length 与 ETag（显式给了夹具就不补默认值）。
            exchange.respond(
                200,
                ByteArray(0),
                mapOf("ETag" to "W/\"rev-3\"", "Content-Length" to "4096"),
            )
        }

        val result = transport().head("/Apps/qingyu-sync/snapshot.mikcb")

        assertFalse(result.isFailed)
        assertTrue(result.exists)
        assertEquals(200, result.statusCode)
        assertEquals(4096L, result.contentLength)
        assertEquals("rev-3", result.etag)
        assertEquals("HEAD", server.requests[0].method)
    }

    @Test
    fun headReportsMissingOn404() {
        server.handler = { exchange, _ -> exchange.respond(404, ByteArray(0)) }

        val result = transport().head("/Apps/qingyu-sync/gone.mikcb")

        assertFalse("head failed: ${result.errorMessage}", result.isFailed)
        assertFalse(result.exists)
        assertEquals(404, result.statusCode)
    }

    // ---------- LOCK / UNLOCK ----------

    @Test
    fun acquireWriteLockParsesLockTokenHeader() {
        server.handler = { exchange, _ ->
            exchange.respond(
                200,
                LOCK_DISCOVERY.toByteArray(),
                mapOf("Lock-Token" to "<opaquelocktoken:xyz-1>"),
            )
        }

        val result = transport().acquireWriteLock("/Apps/qingyu-sync/snapshot.mikcb", lockSeconds = 30)

        assertFalse(result.isFailed)
        assertFalse(result.isUnsupported)
        assertEquals("opaquelocktoken:xyz-1", result.lockToken)
        assertEquals("LOCK", server.requests[0].method)
        assertEquals("0", server.requests[0].depth)
        assertEquals("Second-30", server.requests[0].timeoutHeader)
        assertTrue(String(server.requests[0].body, Charsets.UTF_8).contains("<d:lockinfo"))
    }

    @Test
    fun acquireWriteLockReportsUnsupportedOn501() {
        server.handler = { exchange, _ -> exchange.respond(501, "not implemented".toByteArray()) }

        val result = transport().acquireWriteLock("/Apps/qingyu-sync/snapshot.mikcb")

        assertFalse("lock failed: ${result.errorMessage}", result.isFailed)
        assertTrue(result.isUnsupported)
        assertNull(result.lockToken)
    }

    @Test
    fun acquireWriteLockReportsUnsupportedOn403OnlyWhenServerSaysSo() {
        server.handler = { exchange, _ ->
            exchange.respond(403, "This resource cannot be locked".toByteArray())
        }

        val result = transport().acquireWriteLock("/Apps/qingyu-sync/snapshot.mikcb")

        assertFalse(result.isFailed)
        assertTrue(result.isUnsupported)
    }

    @Test
    fun acquireWriteLockKeepsOpaque403AsHardFailure() {
        server.handler = { exchange, _ -> exchange.respond(403, "Forbidden".toByteArray()) }

        val result = transport().acquireWriteLock("/Apps/qingyu-sync/snapshot.mikcb")

        assertTrue(result.isFailed)
        assertFalse(result.isUnsupported)
        assertEquals("access_denied", result.errorMessage)
    }

    @Test
    fun acquireWriteLockFailsWhen200HasNoLockTokenHeader() {
        server.handler = { exchange, _ -> exchange.respond(200, LOCK_DISCOVERY.toByteArray()) }

        val result = transport().acquireWriteLock("/Apps/qingyu-sync/snapshot.mikcb")

        assertTrue(result.isFailed)
        assertEquals("invalid_response", result.errorMessage)
    }

    @Test
    fun releaseWriteLockSendsLockTokenHeader() {
        server.handler = { exchange, _ -> exchange.respond(204, ByteArray(0)) }

        val result = transport().releaseWriteLock("/Apps/qingyu-sync/snapshot.mikcb", "opaquelocktoken:xyz-1")

        assertFalse(result.isFailed)
        assertEquals("UNLOCK", server.requests[0].method)
        assertEquals("<opaquelocktoken:xyz-1>", server.requests[0].lockTokenHeader)
    }

    // ---------- 页面层适配器的条件写透传（协议互通第 1 段） ----------
    //
    // 证明 `WebdavHttpRemoteTransport.putBytesConditional` 把 If-Match / If-None-Match
    // 与锁 token 原样送到线上（锁 token 包成 `If: (<token>)`），锁的取/放也透传。

    @Test
    fun adapterConditionalPutForwardsConditionHeadersAndLockToken() {
        server.handler = { exchange, _ -> exchange.respond(201, ByteArray(0)) }
        val adapter = com.mutx163.qingyu.pages.sync.WebdavHttpRemoteTransport(transport())

        val result = adapter.putBytesConditional(
            "/Apps/qingyu-sync/snapshot.meta.json",
            byteArrayOf(1, 2),
            headers = mapOf("If-Match" to "etag-7", "If-None-Match" to "*"),
            lockToken = "opaquelocktoken:tok-9",
        )

        assertFalse(result.isFailed)
        assertEquals("PUT", server.requests[0].method)
        assertEquals("etag-7", server.requests[0].allHeaders["if-match"])
        assertEquals("*", server.requests[0].allHeaders["if-none-match"])
        assertEquals("(<opaquelocktoken:tok-9>)", server.requests[0].allHeaders["if"])
    }

    @Test
    fun adapterConditionalPutWithoutConditionsOmitsConditionHeaders() {
        server.handler = { exchange, _ -> exchange.respond(201, ByteArray(0)) }
        val adapter = com.mutx163.qingyu.pages.sync.WebdavHttpRemoteTransport(transport())

        adapter.putBytesConditional("/x", byteArrayOf(1))

        assertFalse(server.requests[0].allHeaders.containsKey("if-match"))
        assertFalse(server.requests[0].allHeaders.containsKey("if-none-match"))
        assertFalse(server.requests[0].allHeaders.containsKey("if"))
    }

    @Test
    fun adapterAcquireAndReleaseLockRoundTrip() {
        server.handler = { exchange, recorded ->
            if (recorded.method == "LOCK") {
                exchange.respond(200, ByteArray(0), mapOf("Lock-Token" to "<opaquelocktoken:wire-1>"))
            } else {
                exchange.respond(204)
            }
        }
        val adapter = com.mutx163.qingyu.pages.sync.WebdavHttpRemoteTransport(transport())

        val lock = adapter.acquireWriteLock("/Apps/qingyu-sync/")

        assertFalse(lock.isFailed)
        assertFalse(lock.isUnsupported)
        assertEquals("opaquelocktoken:wire-1", lock.lockToken)

        val release = adapter.releaseWriteLock("/Apps/qingyu-sync/", lock.lockToken!!)
        assertFalse(release.isFailed)
        assertEquals("UNLOCK", server.requests[1].method)
        assertEquals("<opaquelocktoken:wire-1>", server.requests[1].lockTokenHeader)
    }

    // ---------- 连接自检 ----------

    @Test
    fun testConnectionReturnsNullWhenRootPropfindSucceeds() {
        server.handler = { exchange, _ -> exchange.respondText(207, HISTORY_MULTISTATUS) }

        assertNull(transport().testConnection())
        assertEquals("/dav/", server.requests[0].path)
        assertEquals("0", server.requests[0].depth)
    }

    @Test
    fun testConnectionReturnsAuthFailedOn401() {
        server.handler = { exchange, _ -> exchange.respond(401, ByteArray(0)) }

        assertEquals("auth_failed", transport().testConnection())
    }

    // ---------- 为什么 WebDAV 扩展方法要走裸 socket ----------

    @Test
    fun jdkHttpUrlConnectionRejectsWebdavExtensionMethods() {
        // 这条钉住「为什么传输层有第二条发送路径」这个平台事实，不是测我们的代码：
        // JDK 的 HttpURLConnection.setRequestMethod 只放行 7 个标准方法，
        // 发 PROPFIND 直接抛 ProtocolException，且 PROPFIND 不在「可自动重试」的方法里。
        val connection = URL(server.baseUrl + "Apps/").openConnection() as HttpURLConnection
        val thrown = try {
            connection.requestMethod = "PROPFIND"
            null
        } catch (error: ProtocolException) {
            error
        } finally {
            connection.disconnect()
        }

        assertTrue("JDK 竟然放行了 PROPFIND：裸 socket 路径的前提变了", thrown != null)
        assertTrue(
            "异常文本变了：${thrown?.message}",
            thrown?.message?.contains("Invalid HTTP method") == true,
        )
    }

    @Test
    fun propfindReadsChunkedResponseBody() {
        // 夹具故意把体切成两块用 chunked 发；裸 socket 路径必须自己解块、拼回完整 XML。
        server.handler = { exchange, _ ->
            exchange.respondChunked(
                207,
                HISTORY_MULTISTATUS.toByteArray(Charsets.UTF_8),
                mapOf("Content-Type" to "application/xml; charset=utf-8"),
            )
        }

        val result = transport().listHistoryBackupFiles("/Apps/qingyu-sync/history/")

        assertFalse(result.isFailed)
        assertEquals(listOf("snapshot-abc-123-dev.mikcb", "备份-2026.mikcb"), result.fileNames)
    }

    @Test
    fun propfindReadsBodyDelimitedByConnectionClose() {
        // 既没有 Content-Length 也没有 chunked（HTTP/1.0 风格）时，只能读到连接关闭。
        val raw = RawResponseServer(
            "HTTP/1.1 207 Multi-Status\r\n" +
                "Content-Type: application/xml\r\n" +
                "\r\n" +
                HISTORY_MULTISTATUS,
        )
        raw.start()
        try {
            val transport = WebdavHttpTransport(WebdavEndpoint(raw.baseUrl, "", ""), timeoutMillis = 5_000)
            val result = transport.listHistoryBackupFiles("/Apps/qingyu-sync/history/")
            assertFalse(result.isFailed)
            assertEquals(listOf("snapshot-abc-123-dev.mikcb", "备份-2026.mikcb"), result.fileNames)
        } finally {
            raw.close()
        }
    }

    // ---------- 夹具 ----------

    private class Recorded(
        val method: String,
        val path: String,
        val authorization: String?,
        val depth: String?,
        val contentType: String?,
        val ifHeader: String?,
        val lockTokenHeader: String?,
        val timeoutHeader: String?,
        val body: ByteArray,
        /** 全量请求头（键小写）；条件写用例断言 `If-Match` / `If-None-Match` 用。 */
        val allHeaders: Map<String, String> = emptyMap(),
    )

    /**
     * 本地假 WebDAV 服务：**手写 HTTP/1.1 的裸 socket 服务器**，只用 `java.net.*`。
     *
     * 一次只服务一条连接（用例都是串行单请求），响应固定 `Connection: close`，
     * 所以不存在「池化连接被复用成死连接」这类夹具假象。
     * 服务线程是守护线程，漏停也不会把 JVM 挂住。
     */
    private class FakeWebdavServer {
        val requests: MutableList<Recorded> =
            Collections.synchronizedList(mutableListOf<Recorded>())

        // worker 在构造时就启动，handler 由用例线程随后赋值：必须保证可见性。
        @Volatile
        var handler: (FakeExchange, Recorded) -> Unit = { exchange, _ -> exchange.respond(404) }

        private val listener = ServerSocket(0, 50, InetAddress.getByName("127.0.0.1"))
        private val lifecycleLock = Any()

        @Volatile
        private var closed = false

        @Volatile
        private var activeClient: Socket? = null

        private val worker = Thread({ acceptLoop() }, "fake-webdav").apply {
            isDaemon = true
            start()
        }

        val baseUrl: String get() = "http://127.0.0.1:${listener.localPort}/dav/"

        fun reset() {
            handler = { exchange, _ -> exchange.respond(404) }
            requests.clear()
        }

        private fun acceptLoop() {
            while (true) {
                val client = try {
                    listener.accept()
                } catch (_: IOException) {
                    return
                }
                synchronized(lifecycleLock) {
                    if (closed) {
                        try {
                            client.close()
                        } catch (_: IOException) {
                            // 已经关了。
                        }
                        return
                    }
                    activeClient = client
                }
                try {
                    serve(client)
                } catch (_: Throwable) {
                    // 客户端提前断开（例如超时用例）：无处可写，忽略。
                } finally {
                    synchronized(lifecycleLock) {
                        if (activeClient === client) activeClient = null
                    }
                    try {
                        client.close()
                    } catch (_: IOException) {
                        // 已经关了。
                    }
                }
            }
        }

        private fun serve(client: Socket) {
            client.soTimeout = 5_000
            val input = BufferedInputStream(client.getInputStream())
            val output = BufferedOutputStream(client.getOutputStream())
            val requestLine = readLine(input) ?: return
            val parts = requestLine.split(' ')
            if (parts.size < 2) return
            val method = parts[0]
            val path = parts[1].substringBefore('?')
            val headers = linkedMapOf<String, String>()
            while (true) {
                val line = readLine(input) ?: break
                if (line.isEmpty()) break
                val colon = line.indexOf(':')
                if (colon <= 0) continue
                headers[line.substring(0, colon).trim().lowercase()] =
                    line.substring(colon + 1).trim()
            }
            val length = headers["content-length"]?.toIntOrNull() ?: 0
            val body = if (length > 0) {
                val buffer = ByteArray(length)
                var read = 0
                while (read < length) {
                    val count = input.read(buffer, read, length - read)
                    if (count < 0) break
                    read += count
                }
                buffer.copyOf(read)
            } else {
                ByteArray(0)
            }
            val recorded = Recorded(
                method = method,
                path = path,
                authorization = headers["authorization"],
                depth = headers["depth"],
                contentType = headers["content-type"],
                ifHeader = headers["if"],
                lockTokenHeader = headers["lock-token"],
                timeoutHeader = headers["timeout"],
                body = body,
                allHeaders = headers,
            )
            requests.add(recorded)
            val exchange = FakeExchange(output, path)
            try {
                handler(exchange, recorded)
            } catch (_: Throwable) {
                try {
                    exchange.respond(500)
                } catch (_: Throwable) {
                    // 写不进去就算了。
                }
            }
            if (!exchange.sent) {
                try {
                    exchange.respond(500)
                } catch (_: Throwable) {
                    // 同上。
                }
            }
            try {
                output.flush()
            } catch (_: IOException) {
                // 客户端已断开。
            }
        }

        private fun readLine(input: InputStream): String? {
            val out = ByteArrayOutputStream(128)
            var readAny = false
            while (true) {
                val next = input.read()
                if (next < 0) break
                readAny = true
                if (next == '\n'.code) break
                if (next != '\r'.code) out.write(next)
            }
            if (!readAny) return null
            return String(out.toByteArray(), Charsets.ISO_8859_1)
        }

        fun close() {
            // 先关 listener 再关已 accept 的连接，最后 join：
            // 确保用例结束时没有活 socket 继续占着临时端口，
            // 下一个用例的 ServerSocket(0) 不会和残留连接撞上。
            synchronized(lifecycleLock) {
                closed = true
                try {
                    listener.close()
                } catch (_: IOException) {
                    // 已经关了。
                }
                try {
                    activeClient?.close()
                } catch (_: IOException) {
                    // 已经关了。
                }
                activeClient = null
            }
            worker.join(2_000)
        }
    }

    /**
     * 一次请求的「响应端」：handler 通过它写状态码 / 头 / 体。
     * 形状刻意贴近 `HttpExchange`（`requestURI.path`、`respond`、`respondText`），
     * 换夹具时用例基本不用动。
     */
    private class FakeExchange(private val output: OutputStream, path: String) {
        /** 只为让用例写 `exchange.requestURI.path`。 */
        val requestURI = FakeUri(path)

        var sent: Boolean = false
            private set

        fun respond(
            status: Int,
            body: ByteArray = ByteArray(0),
            headers: Map<String, String> = emptyMap(),
        ) {
            val head = StringBuilder()
            head.append("HTTP/1.1 ").append(status).append(' ').append(reasonPhrase(status)).append("\r\n")
            var hasLength = false
            for ((key, value) in headers) {
                head.append(key).append(": ").append(value).append("\r\n")
                if (key.equals("Content-Length", ignoreCase = true)) hasLength = true
            }
            // HEAD 用例要自己声明 Content-Length（4096）却不发体，所以显式给了就不再补。
            if (!hasLength) head.append("Content-Length: ").append(body.size).append("\r\n")
            head.append("Connection: close\r\n\r\n")
            output.write(head.toString().toByteArray(Charsets.ISO_8859_1))
            if (body.isNotEmpty()) output.write(body)
            output.flush()
            sent = true
        }

        fun respondText(
            status: Int,
            text: String,
            contentType: String = "application/xml; charset=utf-8",
        ) {
            respond(status, text.toByteArray(Charsets.UTF_8), mapOf("Content-Type" to contentType))
        }

        /** 强制 `Transfer-Encoding: chunked`，并把体**切成两块**发（防「一次读完」侥幸通过）。 */
        fun respondChunked(
            status: Int,
            body: ByteArray,
            headers: Map<String, String> = emptyMap(),
        ) {
            val head = StringBuilder()
            head.append("HTTP/1.1 ").append(status).append(' ').append(reasonPhrase(status)).append("\r\n")
            for ((key, value) in headers) {
                head.append(key).append(": ").append(value).append("\r\n")
            }
            head.append("Transfer-Encoding: chunked\r\n")
            head.append("Connection: close\r\n\r\n")
            output.write(head.toString().toByteArray(Charsets.ISO_8859_1))
            val split = body.size / 2
            for (chunk in listOf(body.copyOfRange(0, split), body.copyOfRange(split, body.size))) {
                if (chunk.isEmpty()) continue
                output.write((chunk.size.toString(16) + "\r\n").toByteArray(Charsets.ISO_8859_1))
                output.write(chunk)
                output.write("\r\n".toByteArray(Charsets.ISO_8859_1))
            }
            output.write("0\r\n\r\n".toByteArray(Charsets.ISO_8859_1))
            output.flush()
            sent = true
        }
    }

    private class FakeUri(val path: String)

    /**
     * 只会「收一次请求头 → 原样吐一段响应字节 → 关连接」的裸 socket 假服务。
     * 用来造 [FakeWebdavServer] 造不出的响应：既无 Content-Length 也无 chunked
     * （HTTP/1.0 风格），只能靠连接关闭定界。
     */
    private class RawResponseServer(private val responseText: String) {
        private val socket = ServerSocket(0)
        private val lifecycleLock = Any()

        @Volatile
        private var closed = false

        @Volatile
        private var activeClient: Socket? = null

        private val worker = Thread {
            val client = try {
                socket.accept()
            } catch (_: Throwable) {
                return@Thread
            }
            synchronized(lifecycleLock) {
                if (closed) {
                    try {
                        client.close()
                    } catch (_: Throwable) {
                        // 已经关了。
                    }
                    return@Thread
                }
                activeClient = client
            }
            try {
                client.use {
                    it.soTimeout = 5_000
                    val input = it.getInputStream()
                    // 读到请求头结束（\r\n\r\n）即可，请求体由内核缓冲吞掉。
                    var state = 0
                    while (true) {
                        val next = input.read()
                        if (next < 0) break
                        state = when {
                            state == 0 && next == '\r'.code -> 1
                            state == 1 && next == '\n'.code -> 2
                            state == 2 && next == '\r'.code -> 3
                            state == 3 && next == '\n'.code -> 4
                            else -> 0
                        }
                        if (state == 4) break
                    }
                    it.getOutputStream().apply {
                        write(responseText.toByteArray(Charsets.UTF_8))
                        flush()
                    }
                }
            } catch (_: Throwable) {
                // 用例结束时会关 socket，这里静默即可。
            } finally {
                synchronized(lifecycleLock) {
                    if (activeClient === client) activeClient = null
                }
                try {
                    client.close()
                } catch (_: Throwable) {
                    // 已经关了。
                }
            }
        }.apply {
            isDaemon = true
            name = "raw-response-server"
        }

        val baseUrl: String get() = "http://127.0.0.1:${socket.localPort}/dav/"

        fun start() {
            worker.start()
        }

        fun close() {
            // 与 FakeWebdavServer 同理：关 listener + 关活动连接 + join，
            // 不给下一个用例留下占用临时端口的活 socket。
            synchronized(lifecycleLock) {
                closed = true
                try {
                    socket.close()
                } catch (_: Throwable) {
                    // 已经关了。
                }
                try {
                    activeClient?.close()
                } catch (_: Throwable) {
                    // 已经关了。
                }
                activeClient = null
            }
            worker.join(2_000)
        }
    }

    companion object {
        private lateinit var sharedServer: FakeWebdavServer

        @BeforeClass
        @JvmStatic
        fun startSharedServer() {
            // 关闭 JDK 的 HTTP keep-alive 缓存：它按 host:port 复用连接，而本类（以及同 JVM
            // 里的其他测试类）都用临时端口；端口被系统回收再分配后，复用一条指向旧服务器的
            // 连接会得到 reset → connection_failed。本类只需一次性真实往返，关掉池化最稳。
            System.setProperty("http.keepAlive", "false")
            sharedServer = FakeWebdavServer()
        }

        @AfterClass
        @JvmStatic
        fun stopSharedServer() {
            sharedServer.close()
        }

        /** 手写 207：目录本身 + 两个 .mikcb + 一个 .txt + 一个子目录。 */
        private val HISTORY_MULTISTATUS = """
            <?xml version="1.0" encoding="utf-8"?>
            <D:multistatus xmlns:D="DAV:">
              <D:response>
                <D:href>/dav/Apps/qingyu-sync/history/</D:href>
                <D:propstat><D:prop><D:resourcetype><D:collection/></D:resourcetype></D:prop></D:propstat>
              </D:response>
              <D:response>
                <D:href>/dav/Apps/qingyu-sync/history/snapshot-abc-123-dev.mikcb</D:href>
                <D:propstat><D:prop>
                  <D:resourcetype/>
                  <D:getcontentlength>2048</D:getcontentlength>
                  <D:getetag>"rev-7"</D:getetag>
                </D:prop></D:propstat>
              </D:response>
              <D:response>
                <D:href>/dav/Apps/qingyu-sync/history/%E5%A4%87%E4%BB%BD-2026.mikcb</D:href>
                <D:propstat><D:prop>
                  <D:resourcetype/>
                  <D:getcontentlength>16</D:getcontentlength>
                  <D:getetag>W/"rev-8"</D:getetag>
                </D:prop></D:propstat>
              </D:response>
              <D:response>
                <D:href>/dav/Apps/qingyu-sync/history/notes.txt</D:href>
                <D:propstat><D:prop><D:resourcetype/><D:getcontentlength>3</D:getcontentlength></D:prop></D:propstat>
              </D:response>
              <D:response>
                <D:href>/dav/Apps/qingyu-sync/history/archive/</D:href>
                <D:propstat><D:prop><D:resourcetype><D:collection/></D:resourcetype></D:prop></D:propstat>
              </D:response>
            </D:multistatus>
        """.trimIndent()

        private val SINGLE_MULTISTATUS = """
            <?xml version="1.0" encoding="utf-8"?>
            <D:multistatus xmlns:D="DAV:">
              <D:response>
                <D:href>/dav/Apps/qingyu-sync/snapshot.mikcb</D:href>
                <D:propstat><D:prop>
                  <D:resourcetype/>
                  <D:getcontentlength>2048</D:getcontentlength>
                  <D:getetag>"rev-9"</D:getetag>
                </D:prop></D:propstat>
              </D:response>
            </D:multistatus>
        """.trimIndent()

        private val MULTISTATUS_WITHOUT_ETAG = """
            <?xml version="1.0" encoding="utf-8"?>
            <D:multistatus xmlns:D="DAV:">
              <D:response>
                <D:href>/dav/Apps/qingyu-sync/snapshot.mikcb</D:href>
                <D:propstat><D:prop>
                  <D:resourcetype/>
                  <D:getcontentlength>2048</D:getcontentlength>
                </D:prop></D:propstat>
              </D:response>
            </D:multistatus>
        """.trimIndent()

        private val LOCK_DISCOVERY = """
            <?xml version="1.0" encoding="utf-8"?>
            <D:prop xmlns:D="DAV:">
              <D:lockdiscovery><D:activelock>
                <D:locktype><D:write/></D:locktype>
                <D:lockscope><D:exclusive/></D:lockscope>
                <D:timeout>Second-30</D:timeout>
                <D:locktoken><D:href>opaquelocktoken:xyz-1</D:href></D:locktoken>
              </D:activelock></D:lockdiscovery>
            </D:prop>
        """.trimIndent()
    }
}

/** 状态码 → 原因短语（真实服务器都会给；我们的客户端只读状态码，但线格式要像真的）。 */
private fun reasonPhrase(status: Int): String = when (status) {
    200 -> "OK"
    201 -> "Created"
    204 -> "No Content"
    207 -> "Multi-Status"
    301 -> "Moved Permanently"
    302 -> "Found"
    400 -> "Bad Request"
    401 -> "Unauthorized"
    403 -> "Forbidden"
    404 -> "Not Found"
    405 -> "Method Not Allowed"
    409 -> "Conflict"
    412 -> "Precondition Failed"
    423 -> "Locked"
    500 -> "Internal Server Error"
    501 -> "Not Implemented"
    507 -> "Insufficient Storage"
    else -> "Status"
}
