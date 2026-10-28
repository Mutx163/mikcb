package com.mutx163.qingyu.sync

import com.sun.net.httpserver.HttpExchange
import com.sun.net.httpserver.HttpServer
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.InetSocketAddress
import java.net.ProtocolException
import java.net.ServerSocket
import java.net.URL
import java.util.Collections
import java.util.concurrent.Executors
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * WebDAV 传输层的**真 HTTP 往返**测试。
 *
 * 用 JDK 自带的 `com.sun.net.httpserver.HttpServer` 起本地假 WebDAV 服务，
 * 断言的是**人推的**线格式：请求方法 / 路径 / 头，响应状态码 / 体 / ETag。
 * 覆盖：正常往返、401、404、空体、连接失败、读超时、重定向（跟随 / 环 / 非 http 目标）、
 * 非 UTF-8 字节、超长响应体、PROPFIND 解析、PUT / MKCOL / DELETE / HEAD / LOCK / UNLOCK。
 */
class WebdavHttpTransportTest {

    private lateinit var server: FakeWebdavServer

    @Before
    fun setUp() {
        server = FakeWebdavServer()
    }

    @After
    fun tearDown() {
        server.close()
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
        server.handler = { exchange, _ ->
            Thread.sleep(3_000)
            exchange.respond(200, byteArrayOf(1))
        }

        val result = transport(timeoutMillis = 400).getBytes("/slow.mikcb")

        assertTrue(result.isFailed)
        assertEquals("connection_timeout", result.errorMessage)
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
        assertEquals(2, server.requests.size)
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
            exchange.responseHeaders.add("ETag", "W/\"rev-3\"")
            exchange.responseHeaders.add("Content-Length", "4096")
            exchange.sendResponseHeaders(200, -1)
            exchange.responseBody.close()
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

        assertFalse(result.isFailed)
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

        assertFalse(result.isFailed)
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
        // 长度参数 0 ⇒ JDK HttpServer 用 chunked 传输编码；裸 socket 路径必须自己解块。
        server.handler = { exchange, _ ->
            exchange.responseHeaders.add("Content-Type", "application/xml; charset=utf-8")
            exchange.sendResponseHeaders(207, 0)
            exchange.responseBody.use { it.write(HISTORY_MULTISTATUS.toByteArray(Charsets.UTF_8)) }
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
    )

    /**
     * 本地假 WebDAV 服务：请求先记录（含请求体），再交给测试设置的 handler。
     * 线程池是守护线程——漏停也不会把 JVM 挂住。
     */
    private class FakeWebdavServer {
        val requests: MutableList<Recorded> =
            Collections.synchronizedList(mutableListOf<Recorded>())

        var handler: (HttpExchange, Recorded) -> Unit = { exchange, _ -> exchange.respond(404) }

        private val pool = Executors.newFixedThreadPool(4) { runnable ->
            Thread(runnable, "fake-webdav").apply { isDaemon = true }
        }
        private val http: HttpServer = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)

        val baseUrl: String get() = "http://127.0.0.1:${http.address.port}/dav/"

        init {
            http.executor = pool
            http.createContext("/") { exchange ->
                val recorded = Recorded(
                    method = exchange.requestMethod,
                    path = exchange.requestURI.path,
                    authorization = exchange.requestHeaders.getFirst("Authorization"),
                    depth = exchange.requestHeaders.getFirst("Depth"),
                    contentType = exchange.requestHeaders.getFirst("Content-Type"),
                    ifHeader = exchange.requestHeaders.getFirst("If"),
                    lockTokenHeader = exchange.requestHeaders.getFirst("Lock-Token"),
                    timeoutHeader = exchange.requestHeaders.getFirst("Timeout"),
                    body = exchange.requestBody.readBytes(),
                )
                requests.add(recorded)
                try {
                    handler(exchange, recorded)
                } catch (_: Throwable) {
                    try {
                        exchange.respond(500)
                    } catch (_: Throwable) {
                        // 客户端已断开（例如超时用例）：无处可写，忽略。
                    }
                }
            }
            http.start()
        }

        fun close() {
            http.stop(0)
            pool.shutdownNow()
        }
    }

    /**
     * 只会「收一次请求头 → 原样吐一段响应字节 → 关连接」的裸 socket 假服务。
     * 用来造 `com.sun.net.httpserver` 造不出的响应（无 Content-Length、无 chunked）。
     */
    private class RawResponseServer(private val responseText: String) {
        private val socket = ServerSocket(0)

        private val worker = Thread {
            try {
                socket.accept().use { client ->
                    client.soTimeout = 5_000
                    val input = client.getInputStream()
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
                    client.getOutputStream().apply {
                        write(responseText.toByteArray(Charsets.UTF_8))
                        flush()
                    }
                }
            } catch (_: Throwable) {
                // 用例结束时会关 socket，这里静默即可。
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
            try {
                socket.close()
            } catch (_: Throwable) {
                // 已经关了。
            }
        }
    }

    companion object {
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

private fun HttpExchange.respond(
    status: Int,
    body: ByteArray = ByteArray(0),
    headers: Map<String, String> = emptyMap(),
) {
    for ((key, value) in headers) responseHeaders.add(key, value)
    val length = if (body.isEmpty()) -1L else body.size.toLong()
    sendResponseHeaders(status, if (status == 204 || status == 304) -1L else length)
    if (body.isEmpty()) responseBody.close() else responseBody.use { it.write(body) }
}

private fun HttpExchange.respondText(
    status: Int,
    text: String,
    contentType: String = "application/xml; charset=utf-8",
) {
    respond(status, text.toByteArray(Charsets.UTF_8), mapOf("Content-Type" to contentType))
}
