package com.mutx163.qingyu.transfer.lan

import com.mutx163.qingyu.share.UNKNOWN_LAN_CLIENT_IP
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.IOException
import java.io.InputStream
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.net.SocketException
import java.net.SocketTimeoutException
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.SynchronousQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * 局域网编辑的**真 HTTP 服务端**（能力缺口 B2，P3-G3 域）。
 *
 * 对应 Dart `lib/services/lan_edit_server_service.dart` 里 `HttpServer.bind(...)` 那一段：
 * 绑全部网卡、随机端口、一个连接一个工作线程、按请求分发到 [LanEditApiRouter]。
 *
 * 只用 JDK 自带件（`java.net.ServerSocket` / `Socket`）——**不许加依赖**，
 * 也不能用 `com.sun.net.httpserver`（JDK 私有实现，Gradle 的 Android 单测编译看不到）。
 *
 * 与 Dart 的差异（有意，逐条都有理由）：
 * - **每个连接只处理一个请求**（响应固定 `Connection: close`）。Dart 的 `HttpServer` 带
 *   keep-alive，但那要完整的连接复用状态机（还要处理流水线请求与半关连接），
 *   局域网编辑一次页面加载几个请求，新开连接的开销可以忽略，少一个状态机就少一类走私面。
 * - **不支持 `Transfer-Encoding: chunked`**：明确 400，不半信半疑地读长度。
 * - **静态资源是可选的注入件**（[staticAssets]）：本类自己去读 Flutter asset 需要
 *   `android.content.res.AssetManager`，那会让 `transfer/lan` 不再是纯 Kotlin，
 *   全队 L0 都会丢掉这一整层目录（见 `LanEditStaticAssets` 的说明）。
 *   所以由接线方注入 `LanEditStaticAssets`；**装配漏了它 ⇒ 浏览器打开地址一片空白**
 *   （`/` 落到路由层是 404，而接口前缀下的请求全部正常，很难从现象反推）。
 *
 * 线程模型：1 个接受线程 + 一个有界工作池（上限 [LanEditHttpLimits.MAX_CONCURRENT_REQUESTS]
 * + 少量余量）。池满时新连接直接回 503，而不是无限堆线程——手机扛不住。
 * 全部线程是 daemon，进程退出不会被它们挂住。
 */
class LanEditHttpServer(
    private val router: LanEditApiRouter,
    private val audit: LanEditAuditSink = LanEditAuditNoop,
    /**
     * 控制台页面与静态资源的来源（2026-10-29 F03 接线补件）。
     *
     * null = 只服务 API（旧行为）。**不传的后果是真机上电脑浏览器打开地址一片空白**：
     * 浏览器请求 `/` 落到路由层就是 404，而接口前缀下的请求全部正常，看起来像「服务器通了但页面没做」。
     * 生产装配见 `composeP1` 的 `LanEditHost`；测试里可以注入假资源。
     */
    private val staticAssets: LanEditStaticAssets? = null,
    private val bindAddress: InetAddress = InetAddress.getByName("0.0.0.0"),
    private val requestedPort: Int = 0,
    /**
     * 空闲判据：返回 true 就自动停服（Dart `LanEditServerService._idleTimer` 的对应物）。
     *
     * **默认就是「会话过期就停」**（`{ router.isSessionExpired }`）——把正确行为设成默认值，
     * 免得接线的人忘了传参数就留下一个永远挂着的套接字。测试里想完全手动控制时显式传 null。
     *
     * 为什么必须有：会话过期后每个请求都会回 401，**授权**是安全的；但套接字会一直挂着、
     * 前台服务通知也一直亮着，用户以为「还在共享中」。
     */
    private val sessionExpired: (() -> Boolean)? = { router.isSessionExpired },
    private val idleCheckIntervalMillis: Long = DEFAULT_IDLE_CHECK_INTERVAL_MILLIS,
) {

    private val running = AtomicBoolean(false)
    private var serverSocket: ServerSocket? = null
    private var acceptThread: Thread? = null
    private var workers: ThreadPoolExecutor? = null
    private var watchdog: Thread? = null

    /** 实际监听端口；未启动为 0。 */
    @Volatile
    var port: Int = 0
        private set

    val isRunning: Boolean get() = running.get()

    /**
     * 绑定并开始接受连接。**端口 0 = 由系统分配**（与 Dart `HttpServer.bind(anyIPv4, 0)` 同）。
     *
     * @return 实际监听端口。
     * @throws IllegalStateException 已经在跑。
     */
    fun start(): Int {
        check(!running.get()) { "LAN edit server is already running" }
        val socket = ServerSocket()
        try {
            socket.reuseAddress = true
            socket.bind(InetSocketAddress(bindAddress, requestedPort), LanEditHttpLimits.BACKLOG)
        } catch (error: IOException) {
            runCatching { socket.close() }
            throw error
        }
        serverSocket = socket
        port = socket.localPort
        running.set(true)

        workers = ThreadPoolExecutor(
            0,
            LanEditHttpLimits.MAX_CONCURRENT_REQUESTS + 4,
            30L,
            TimeUnit.SECONDS,
            SynchronousQueue(),
            { runnable ->
                Thread(runnable, "lan-edit-worker").apply { isDaemon = true }
            },
        )

        acceptThread = Thread({ acceptLoop(socket) }, "lan-edit-accept").apply {
            isDaemon = true
            start()
        }
        if (sessionExpired != null) {
            watchdog = Thread({ idleWatchLoop() }, "lan-edit-idle-watch").apply {
                isDaemon = true
                start()
            }
        }
        audit.info("lan_edit_session_started", "session started", mapOf("port" to port))
        return port
    }

    /**
     * 空闲看门狗：每 [idleCheckIntervalMillis] 查一次会话是否过期，过期就按
     * `idle_timeout` 停服（Dart `_idleTimer` 每 30 秒查一次，间隔同值）。
     */
    private fun idleWatchLoop() {
        val check = sessionExpired ?: return
        while (running.get()) {
            try {
                Thread.sleep(idleCheckIntervalMillis)
            } catch (_: InterruptedException) {
                return
            }
            if (!running.get()) return
            val expired = try {
                check()
            } catch (_: Throwable) {
                false
            }
            if (expired) {
                stop("idle_timeout")
                return
            }
        }
    }

    /** 停服：关监听套接字、放工作池。可重复调用（第二次是空操作）。 */
    fun stop(reason: String = "manual") {
        val wasRunning = running.getAndSet(false)
        val socket = serverSocket
        serverSocket = null
        if (socket != null) {
            runCatching { socket.close() }
        }
        acceptThread?.interrupt()
        acceptThread = null
        // 看门狗可能是「自己」调过来的（会话过期 → stop）：此时别自我 interrupt。
        val watch = watchdog
        watchdog = null
        if (watch != null && watch !== Thread.currentThread()) {
            watch.interrupt()
        }
        workers?.shutdownNow()
        workers = null
        port = 0
        if (wasRunning) {
            audit.info("lan_edit_session_stopped", "session stopped", mapOf("reason" to reason))
        }
    }

    private fun acceptLoop(socket: ServerSocket) {
        while (running.get()) {
            val client = try {
                socket.accept()
            } catch (error: SocketException) {
                // 正常停服路径：close() 会让 accept 抛 SocketException。
                if (running.get()) {
                    audit.info("lan_edit_server_error", "accept failed", mapOf("type" to error::class.simpleName))
                }
                return
            } catch (error: IOException) {
                if (!running.get()) return
                audit.info("lan_edit_server_error", "accept failed", mapOf("type" to error::class.simpleName))
                continue
            }
            try {
                workers?.execute { handleConnection(client) }
            } catch (_: RejectedExecutionException) {
                // 池满：明确回 503 再关，别让对端一直等。
                writeQuietly(client, LanEditHttpResponse.error(503, "too_many_requests", "Too many requests"))
                closeQuietly(client)
            }
        }
    }

    private fun handleConnection(socket: Socket) {
        var entered = false
        try {
            socket.soTimeout = LanEditHttpLimits.SOCKET_IDLE_TIMEOUT_MILLIS
            socket.tcpNoDelay = true
            val input = BufferedInputStream(socket.getInputStream())
            val head = readHead(input)
            val lines = head.split("\r\n")
            val requestLine = LanEditHttpParse.parseRequestLine(lines.firstOrNull().orEmpty())
            val headers = LanEditHttpParse.parseHeaders(lines.drop(1))
            val contentLength = LanEditHttpParse.requireContentLength(headers)
            val body = readBody(input, contentLength)
            val (path, queryString) = LanEditHttpParse.splitTarget(requestLine.target)
            val request = LanEditHttpRequest(
                method = requestLine.method,
                target = requestLine.target,
                path = path,
                query = LanEditHttpParse.parseQuery(queryString),
                headers = headers,
                body = body,
                remoteAddress = socket.inetAddress?.hostAddress ?: UNKNOWN_LAN_CLIENT_IP,
            )
            if (!router.tryEnter()) {
                writeQuietly(
                    socket,
                    LanEditHttpResponse.error(503, "too_many_requests", "Too many requests"),
                )
                return
            }
            entered = true
            // 页面与子资源走静态分发，其余走 API 路由（Dart `_handleRequest` 的同一分支）。
            // 判据抽在 `isStaticAssetRequest` 里并有单测：这条写错会表现成「API 全 404」
            // 或「接口路径被当成页面」，两种都很难从现象反推。
            val response = if (staticAssets != null && isStaticAssetRequest(request.method, request.path)) {
                staticAssets.serve(request.path)
            } else {
                router.route(request)
            }
            writeQuietly(socket, response)
        } catch (error: LanEditHttpException) {
            writeQuietly(
                socket,
                LanEditHttpResponse.error(error.failure.status, error.failure.error, error.failure.error),
            )
        } catch (_: ClientDisconnected) {
            // 对端半途消失（浏览器关标签页 / 手机走出 WiFi）：没有对端可回，安静收摊。
        } catch (_: SocketTimeoutException) {
            writeQuietly(
                socket,
                LanEditHttpResponse.error(
                    LanEditHttpFailure.BODY_TIMEOUT.status,
                    LanEditHttpFailure.BODY_TIMEOUT.error,
                    LanEditHttpFailure.BODY_TIMEOUT.error,
                ),
            )
        } catch (_: IOException) {
            // 读/写失败（连接被重置等）一律安静收摊，不让一个坏连接打死工作线程。
        } catch (error: Throwable) {
            audit.info("lan_edit_server_error", "connection failed", mapOf("type" to error::class.simpleName))
            writeQuietly(socket, LanEditHttpResponse.error(500, "internal_error", "internal_error"))
        } finally {
            if (entered) router.exit()
            closeQuietly(socket)
        }
    }

    /**
     * 读到 `\r\n\r\n` 为止（含）。
     *
     * 严格只认 CRLF：单 LF 结尾是「请求行折叠 / 走私」的常见载体，收下它就得再写一套
     * 归一化规则，不如直接 400。头部总字节超限抛 431。
     */
    private fun readHead(input: InputStream): String {
        val limit = LanEditHttpLimits.MAX_HEADER_BYTES + LanEditHttpLimits.MAX_REQUEST_LINE_BYTES
        val buffer = ByteArray(limit)
        var size = 0
        while (size < limit) {
            val byte = input.read()
            if (byte < 0) {
                throw LanEditHttpException(
                    LanEditHttpFailure.MALFORMED_REQUEST_LINE,
                    if (size == 0) "connection closed before request" else "truncated request head",
                )
            }
            buffer[size++] = byte.toByte()
            if (size >= 4 &&
                buffer[size - 4] == CR && buffer[size - 3] == LF &&
                buffer[size - 2] == CR && buffer[size - 1] == LF
            ) {
                // 丢掉结尾的 CRLFCRLF
                return String(buffer, 0, size - 4, Charsets.UTF_8)
            }
        }
        throw LanEditHttpException(LanEditHttpFailure.HEADER_TOO_LARGE, "$size bytes")
    }

    /**
     * 读请求体：长度由 `Content-Length` 决定，整体受墙钟预算约束。
     *
     * 预算按 Dart `_bodyReadBudget` 取 20 秒——**整个体的预算，不是每块的**：
     * 一个每秒挤一个字节的连接否则能一直占着工作线程。
     */
    private fun readBody(input: InputStream, length: Long): String {
        if (length <= 0) return ""
        if (length > LanEditHttpLimits.MAX_BODY_BYTES) {
            throw LanEditHttpException(LanEditHttpFailure.BODY_TOO_LARGE, "$length bytes")
        }
        val target = length.toInt()
        val buffer = ByteArray(target)
        var read = 0
        val deadline = System.currentTimeMillis() + LanEditHttpLimits.BODY_READ_BUDGET_MILLIS
        while (read < target) {
            if (System.currentTimeMillis() > deadline) {
                throw LanEditHttpException(LanEditHttpFailure.BODY_TIMEOUT, "budget exceeded")
            }
            val chunk = input.read(buffer, read, target - read)
            if (chunk < 0) {
                throw ClientDisconnected("eof after $read/$target bytes")
            }
            read += chunk
        }
        return String(buffer, Charsets.UTF_8)
    }

    private fun writeQuietly(socket: Socket, response: LanEditHttpResponse) {
        try {
            val out = BufferedOutputStream(socket.getOutputStream())
            out.write(response.toByteArray())
            out.flush()
        } catch (_: IOException) {
            // 对端已断开：响应发不出去是正常情况，不是错误。
        }
    }

    private fun closeQuietly(socket: Socket) {
        try {
            socket.close()
        } catch (_: IOException) {
            // 忽略
        }
    }

    /** 对端在请求体读完之前消失（不是服务端错误，不需要响应）。 */
    private class ClientDisconnected(message: String) : RuntimeException(message)

    private companion object {
        const val CR = 13.toByte()
        const val LF = 10.toByte()

        /** 与 Dart `_idleTimer` 的 30 秒一致。 */
        const val DEFAULT_IDLE_CHECK_INTERVAL_MILLIS = 30_000L
    }
}
