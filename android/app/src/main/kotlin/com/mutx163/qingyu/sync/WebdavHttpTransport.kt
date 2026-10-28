package com.mutx163.qingyu.sync

import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.InetSocketAddress
import java.net.MalformedURLException
import java.net.Socket
import java.net.SocketException
import java.net.SocketTimeoutException
import java.net.URI
import java.net.URL
import javax.net.ssl.SSLException
import javax.net.ssl.SSLSocket
import javax.net.ssl.SSLSocketFactory

/**
 * WebDAV 真收发传输层（JDK 内置 [HttpURLConnection]，**零新依赖**）。
 *
 * 为什么是 `HttpURLConnection` 而不是 okhttp：L0 模块单测脚本
 * （`scripts/test-kotlin-module.ps1`）的 classpath 只有 kotlin-stdlib + junit + hamcrest，
 * 引 okhttp 会让这一层在 JVM 上完全无法验证；`HttpURLConnection` 是 JDK 自带的，
 * Android 上也有（minSdk 33，`java.util.Base64` 等同样可用）。
 *
 * 覆盖：PROPFIND（listing / ETag）、PUT、GET、MKCOL、DELETE、HEAD、LOCK、UNLOCK。
 * 失败一律**不抛异常**，按 [WebdavFailures] 的口径返回安全短码——调用方（同步 UI）
 * 拿到的永远是可本地化的码，不是异常原文（异常文本里可能带 URL）。
 *
 * **两条发送路径（2026-10-28 实测发现，必须记住）**：
 * 1. 标准方法（GET/PUT/HEAD/DELETE/OPTIONS…）走 `HttpURLConnection`；
 * 2. WebDAV 扩展方法（PROPFIND/MKCOL/LOCK/UNLOCK）走**手写 HTTP/1.1 的裸 socket**
 *    （[rawSocketAttempt]）——因为 JDK 的 `setRequestMethod` 只放行 7 个标准方法，
 *    发 PROPFIND 会抛 `ProtocolException: Invalid HTTP method`，光靠 `HttpURLConnection`
 *    根本列不了远端目录。两条路径都只用 JDK 自带类，零新依赖。
 *
 * 与 Dart 侧（`lib/services/webdav_client_service.dart` + pub `webdav_plus`）的差异：
 * 1. **重定向自己走**：`instanceFollowRedirects = false`，手动跟随 301/302/303/307/308
 *    最多 [maxRedirects] 跳，**方法不降级**（WebDAV 上 302 常见于集合路径规范化，
 *    把 PUT/PROPFIND 降成 GET 会把写变成读）。跳数用尽后把最后一个 3xx 当失败返回。
 * 2. **响应体上限**：[maxResponseBytes] 超出即判 `invalid_response`，绝不返回半截快照。
 * 3. **超时是硬上限**：`connectTimeout` 与 `readTimeout` 都设为同一个值。
 * 4. **DELETE 404 不算失败**：按幂等语义返回 `notFound = true`（Dart 那边会抛）。
 *
 * 不做的事（诚实清单，别当成已实现）：摘要认证（Digest）、TLS 自签证书信任、
 * 断点续传 / Range、gzip 压缩、代理配置、cookie 会话、并发写冲突的重试。
 */
class WebdavHttpTransport(
    val endpoint: WebdavEndpoint,
    val timeoutMillis: Long = DEFAULT_OPERATION_TIMEOUT_MILLIS,
    val maxResponseBytes: Long = DEFAULT_MAX_RESPONSE_BYTES,
    val maxRedirects: Int = DEFAULT_MAX_REDIRECTS,
) {

    /** 远端路径 → 可发出的绝对 URL。 */
    fun urlFor(remotePath: String): String = joinWebdavUrl(endpoint.baseUrl, remotePath)

    // ---------- 读 ----------

    /**
     * 连接自检（对根做 PROPFIND depth 0）。
     * @return null 表示可用；否则为安全短码。
     */
    fun testConnection(timeoutMillis: Long = this.timeoutMillis): String? {
        val result = propfind("/", depth = 0, timeoutMillis = timeoutMillis)
        if (result.isFailed) return result.errorMessage ?: "sync_failed"
        if (result.isNotFound) return "invalid_response"
        return null
    }

    /** GET 一个远端文件（Dart `getBytesResult` 口径：空体当缺失）。 */
    fun getBytes(remotePath: String, timeoutMillis: Long = this.timeoutMillis): GetBytesResult {
        val response = execute(WebdavMethod.GET, urlFor(remotePath), null, emptyMap(), timeoutMillis)
        response.failureKind?.let {
            return classifyGetBytesFailure(null, it, response.failureMessage ?: "")
        }
        val status = response.statusCode
            ?: return classifyGetBytesFailure(null, TransportKind.FORMAT, "missing_status")
        if (!isSuccessStatus(status)) {
            return classifyGetBytesFailure(status, null, "")
        }
        if (response.truncated) {
            return GetBytesResult.failed("invalid_response")
        }
        if (response.body.isEmpty()) {
            return GetBytesResult.notFound()
        }
        return GetBytesResult.ok(response.body)
    }

    /** PROPFIND 取资源列表（`Depth: 0` 查单条，`Depth: 1` 查目录一层）。 */
    fun propfind(
        remotePath: String,
        depth: Int = 1,
        timeoutMillis: Long = this.timeoutMillis,
    ): WebdavPropfindResult {
        val headers = mapOf(
            "Depth" to depth.toString(),
            "Content-Type" to "application/xml; charset=utf-8",
        )
        val response = execute(
            WebdavMethod.PROPFIND,
            urlFor(remotePath),
            PROPFIND_REQUEST_BODY.toByteArray(Charsets.UTF_8),
            headers,
            timeoutMillis,
        )
        response.failureKind?.let {
            return WebdavPropfindResult.failed(
                classifyGetBytesFailure(null, it, response.failureMessage ?: "").errorMessage
                    ?: "sync_failed",
            )
        }
        val status = response.statusCode
            ?: return WebdavPropfindResult.failed("invalid_response")
        if (status == 404) return WebdavPropfindResult.notFound()
        if (!isSuccessStatus(status)) {
            val classified = classifyGetBytesFailure(status, null, "")
            return WebdavPropfindResult.failed(classified.errorMessage ?: "invalid_response")
        }
        if (response.truncated) return WebdavPropfindResult.failed("invalid_response")
        return try {
            WebdavPropfindResult.ok(parsePropfindResources(String(response.body, Charsets.UTF_8)))
        } catch (_: Exception) {
            WebdavPropfindResult.failed("invalid_response")
        }
    }

    /** 历史备份目录 listing（Dart `listHistoryBackupFilesResult` 原样）。 */
    fun listHistoryBackupFiles(
        historyRemoteFolder: String,
        timeoutMillis: Long = this.timeoutMillis,
    ): HistoryListResult {
        val result = propfind(historyRemoteFolder, depth = 1, timeoutMillis = timeoutMillis)
        if (result.isFailed) return HistoryListResult.failed(result.errorMessage ?: "sync_failed")
        if (result.isNotFound) return HistoryListResult.notFound()
        return HistoryListResult.ok(historyFileNamesFromResources(result.resources))
    }

    /** 远端 ETag（PROPFIND depth 0；拿不到返回 null，调用方回落内容重读）。 */
    fun getRemoteEtag(remotePath: String, timeoutMillis: Long = this.timeoutMillis): String? {
        val result = propfind(remotePath, depth = 0, timeoutMillis = timeoutMillis)
        if (result.isFailed || result.isNotFound) return null
        val expectedName = webdavResourceName(remotePath)
        val match = result.resources.firstOrNull { it.name == expectedName && it.etag != null }
            ?: result.resources.firstOrNull { it.etag != null }
        return match?.etag
    }

    // ---------- 写 ----------

    /** PUT 一个远端文件（Dart `putBytes` 口径；返回 ETag 供基线比对）。 */
    fun putBytes(
        remotePath: String,
        bytes: ByteArray,
        headers: Map<String, String> = emptyMap(),
        lockToken: String? = null,
        timeoutMillis: Long = this.timeoutMillis,
    ): WebdavWriteResult {
        val requestHeaders = LinkedHashMap<String, String>()
        requestHeaders.putAll(headers)
        if (!lockToken.isNullOrEmpty()) {
            requestHeaders.putIfAbsent("If", lockTokenIfHeader(lockToken))
        }
        requestHeaders.putIfAbsent("Content-Type", "application/octet-stream")
        val response = execute(WebdavMethod.PUT, urlFor(remotePath), bytes, requestHeaders, timeoutMillis)
        response.failureKind?.let {
            return WebdavWriteResult.failed(
                classifyWebdavWriteFailure(null, it, response.failureMessage ?: ""),
                statusCode = null,
            )
        }
        val status = response.statusCode ?: return WebdavWriteResult.failed("invalid_response")
        if (!isSuccessStatus(status)) {
            return WebdavWriteResult.failed(classifyWebdavWriteFailure(status, null, ""), status)
        }
        return WebdavWriteResult.ok(status, normalizeEtag(response.headers.first("ETag")))
    }

    /** MKCOL 建集合；405 / 301 视为「已存在」（Dart `ensureRemoteFolder` 吞掉同义错误）。 */
    fun mkcol(remotePath: String, timeoutMillis: Long = this.timeoutMillis): WebdavWriteResult {
        val response = execute(WebdavMethod.MKCOL, urlFor(remotePath), null, emptyMap(), timeoutMillis)
        response.failureKind?.let {
            return WebdavWriteResult.failed(
                classifyWebdavWriteFailure(null, it, response.failureMessage ?: ""),
                statusCode = null,
            )
        }
        val status = response.statusCode ?: return WebdavWriteResult.failed("invalid_response")
        if (isSuccessStatus(status)) return WebdavWriteResult.ok(status, null)
        if (status == 405 || status == 301) {
            return WebdavWriteResult.ok(status, null, alreadyExists = true)
        }
        return WebdavWriteResult.failed(classifyWebdavWriteFailure(status, null, ""), status)
    }

    /** 逐段建目录（Dart `ensureRemoteFolder` 原样：从 `/` 开始一段段 MKCOL）。 */
    fun ensureRemoteFolder(
        remoteFolder: String,
        timeoutMillis: Long = this.timeoutMillis,
    ): WebdavWriteResult {
        var current = ""
        var lastStatus: Int? = null
        for (segment in remoteFolder.split('/').filter { it.isNotBlank() }) {
            current = "$current/$segment"
            val result = mkcol("$current/", timeoutMillis)
            if (result.isFailed) {
                return WebdavWriteResult.failed(
                    result.errorMessage ?: "sync_failed",
                    result.statusCode,
                )
            }
            lastStatus = result.statusCode
        }
        return WebdavWriteResult.ok(lastStatus ?: 200, null)
    }

    /** DELETE 远端文件；404 按幂等返回 `notFound = true`（不算失败）。 */
    fun deleteRemoteFile(
        remotePath: String,
        timeoutMillis: Long = this.timeoutMillis,
    ): WebdavWriteResult {
        val response = execute(WebdavMethod.DELETE, urlFor(remotePath), null, emptyMap(), timeoutMillis)
        response.failureKind?.let {
            return WebdavWriteResult.failed(
                classifyWebdavWriteFailure(null, it, response.failureMessage ?: ""),
                statusCode = null,
            )
        }
        val status = response.statusCode ?: return WebdavWriteResult.failed("invalid_response")
        if (isSuccessStatus(status)) return WebdavWriteResult.ok(status, null)
        if (status == 404) return WebdavWriteResult.ok(status, null, notFound = true)
        return WebdavWriteResult.failed(classifyWebdavWriteFailure(status, null, ""), status)
    }

    /** HEAD 探测远端文件是否存在 + 长度 + ETag（不发响应体）。 */
    fun head(remotePath: String, timeoutMillis: Long = this.timeoutMillis): WebdavHeadResult {
        val response = execute(WebdavMethod.HEAD, urlFor(remotePath), null, emptyMap(), timeoutMillis)
        response.failureKind?.let {
            return WebdavHeadResult.failed(
                classifyWebdavWriteFailure(null, it, response.failureMessage ?: ""),
                statusCode = null,
            )
        }
        val status = response.statusCode ?: return WebdavHeadResult.failed("invalid_response")
        if (status == 404) return WebdavHeadResult.missing(status)
        if (!isSuccessStatus(status)) {
            return WebdavHeadResult.failed(classifyWebdavWriteFailure(status, null, ""), status)
        }
        return WebdavHeadResult.present(
            statusCode = status,
            contentLength = response.headers.first("Content-Length")?.trim()?.toLongOrNull(),
            etag = normalizeEtag(response.headers.first("ETag")),
        )
    }

    // ---------- 锁 ----------

    /**
     * 尝试取独占写锁（Dart `acquireWriteLock` 原样口径）：
     * 405 / 501 与「明确说不支持锁」的 403 → `unsupported()`，其余失败是硬失败。
     */
    fun acquireWriteLock(
        remotePath: String,
        lockSeconds: Int = 30,
        timeoutMillis: Long = this.timeoutMillis,
    ): LockResult {
        val headers = mapOf(
            "Content-Type" to "application/xml; charset=utf-8",
            "Depth" to "0",
            "Timeout" to "Second-$lockSeconds",
        )
        val response = execute(
            WebdavMethod.LOCK,
            urlFor(remotePath),
            lockRequestBody(lockSeconds).toByteArray(Charsets.UTF_8),
            headers,
            timeoutMillis,
        )
        response.failureKind?.let {
            return LockResult.failed(
                classifyWebdavWriteFailure(null, it, response.failureMessage ?: ""),
            )
        }
        val status = response.statusCode ?: return LockResult.failed("invalid_response")
        if (isSuccessStatus(status)) {
            val token = parseLockToken(response.headers.first("Lock-Token"))
            return if (token == null) LockResult.failed("invalid_response") else LockResult.acquired(token)
        }
        if (status == 405 || status == 501) return LockResult.unsupported()
        if (status == 403 && looksLikeUnsupportedLock(response.bodyText())) return LockResult.unsupported()
        return LockResult.failed(classifyWebdavWriteFailure(status, null, response.bodyText()))
    }

    /** 释放写锁（`Lock-Token: <token>`）。 */
    fun releaseWriteLock(
        remotePath: String,
        lockToken: String,
        timeoutMillis: Long = this.timeoutMillis,
    ): WebdavWriteResult {
        val headers = mapOf("Lock-Token" to "<$lockToken>")
        val response = execute(WebdavMethod.UNLOCK, urlFor(remotePath), null, headers, timeoutMillis)
        response.failureKind?.let {
            return WebdavWriteResult.failed(
                classifyWebdavWriteFailure(null, it, response.failureMessage ?: ""),
                statusCode = null,
            )
        }
        val status = response.statusCode ?: return WebdavWriteResult.failed("invalid_response")
        if (isSuccessStatus(status)) return WebdavWriteResult.ok(status, null)
        return WebdavWriteResult.failed(classifyWebdavWriteFailure(status, null, ""), status)
    }

    // ---------- 内部：一次往返（含手动重定向） ----------

    private fun execute(
        method: WebdavMethod,
        url: String,
        body: ByteArray?,
        headers: Map<String, String>,
        timeoutMillis: Long,
    ): RawResponse {
        var currentUrl = url
        var hops = 0
        while (true) {
            val attempt = attempt(method, currentUrl, body, headers, timeoutMillis)
            if (attempt.failureKind != null) return attempt
            val status = attempt.statusCode
            if (isRedirectStatus(status) && hops < maxRedirects) {
                val target = resolveRedirectUrl(currentUrl, attempt.headers.first("Location"))
                if (target != null) {
                    currentUrl = target
                    hops++
                    continue
                }
            }
            return attempt
        }
    }

    private fun attempt(
        method: WebdavMethod,
        url: String,
        body: ByteArray?,
        headers: Map<String, String>,
        timeoutMillis: Long,
    ): RawResponse = if (method.wire in URL_CONNECTION_METHODS) {
        connectionAttempt(method, url, body, headers, timeoutMillis)
    } else {
        rawSocketAttempt(method, url, body, headers, timeoutMillis)
    }

    /** `HttpURLConnection` 路径（标准方法；JDK 只放行 [URL_CONNECTION_METHODS]）。 */
    private fun connectionAttempt(
        method: WebdavMethod,
        url: String,
        body: ByteArray?,
        headers: Map<String, String>,
        timeoutMillis: Long,
    ): RawResponse {
        var connection: HttpURLConnection? = null
        return try {
            val opened = URL(url).openConnection() as HttpURLConnection
            connection = opened
            opened.requestMethod = method.wire
            opened.instanceFollowRedirects = false
            val bounded = timeoutMillis.coerceIn(1L, Int.MAX_VALUE.toLong()).toInt()
            opened.connectTimeout = bounded
            opened.readTimeout = bounded
            opened.useCaches = false
            opened.setRequestProperty("User-Agent", WEBDAV_USER_AGENT)
            for ((key, value) in headers) {
                opened.setRequestProperty(key, value)
            }
            if (endpoint.username.isNotEmpty() || endpoint.password.isNotEmpty()) {
                opened.setRequestProperty(
                    "Authorization",
                    basicAuthorizationHeader(endpoint.username, endpoint.password),
                )
            }
            if (body != null) {
                opened.doOutput = true
                opened.setFixedLengthStreamingMode(body.size)
                opened.outputStream.use { it.write(body) }
            }
            val status = opened.responseCode
            val responseHeaders = WebdavResponseHeaders.from(opened.headerFields)
            val stream: InputStream? = if (isSuccessStatus(status)) {
                try {
                    opened.inputStream
                } catch (_: IOException) {
                    null
                }
            } else {
                opened.errorStream
            }
            val read = readBounded(stream)
            RawResponse(
                statusCode = status,
                body = read.bytes,
                headers = responseHeaders,
                truncated = read.truncated,
            )
        } catch (error: SocketTimeoutException) {
            RawResponse.failure(TransportKind.TIMEOUT, error.toString())
        } catch (error: SSLException) {
            RawResponse.failure(TransportKind.HANDSHAKE, error.toString())
        } catch (error: MalformedURLException) {
            RawResponse.failure(TransportKind.FORMAT, error.toString())
        } catch (error: SocketException) {
            // ConnectException 是 SocketException 的子类 → connection_failed。
            RawResponse.failure(TransportKind.SOCKET, error.toString())
        } catch (error: IOException) {
            RawResponse.failure(TransportKind.SOCKET, error.toString())
        } finally {
            connection?.disconnect()
        }
    }

    /**
     * 裸 socket 发一次 HTTP/1.1（**WebDAV 扩展方法专用**）。
     *
     * 为什么必须有这条路径：JDK 的 `java.net.HttpURLConnection.setRequestMethod`
     * 只放行 `GET/POST/HEAD/OPTIONS/PUT/DELETE/TRACE`，发 `PROPFIND` 会直接抛
     * `ProtocolException: Invalid HTTP method: PROPFIND`（2026-10-28 实测，
     * 见 `WebdavHttpTransportTest.jdkHttpUrlConnectionRejectsWebdavExtensionMethods`）。
     * 也就是说光靠 `HttpURLConnection` **发不出 PROPFIND / MKCOL / LOCK / UNLOCK**，
     * 云同步与情侣课表就永远列不了远端目录。
     *
     * 这条路径仍然只用 JDK：`Socket` / `SSLSocketFactory`，零新依赖，Android 上同样可用。
     * 只发 `Connection: close`（不做连接复用），响应体按 Content-Length / chunked /
     * 读到 EOF 三种定界读取，超过 [maxResponseBytes] 立即判 `invalid_response`。
     */
    private fun rawSocketAttempt(
        method: WebdavMethod,
        url: String,
        body: ByteArray?,
        headers: Map<String, String>,
        timeoutMillis: Long,
    ): RawResponse {
        val uri = try {
            URI(url)
        } catch (error: Exception) {
            return RawResponse.failure(TransportKind.FORMAT, error.toString())
        }
        val scheme = uri.scheme?.lowercase()
        val host = uri.host
        if (host.isNullOrEmpty() || (scheme != "http" && scheme != "https")) {
            return RawResponse.failure(TransportKind.FORMAT, "unsupported url scheme: $scheme")
        }
        val port = if (uri.port != -1) uri.port else defaultPort(scheme)
        val target = buildString {
            append(uri.rawPath?.takeIf { it.isNotEmpty() } ?: "/")
            uri.rawQuery?.let { append('?').append(it) }
        }
        val bounded = timeoutMillis.coerceIn(1L, Int.MAX_VALUE.toLong()).toInt()
        var socket: Socket? = null
        return try {
            val plain = Socket()
            socket = plain
            plain.tcpNoDelay = true
            plain.connect(InetSocketAddress(host, port), bounded)
            plain.soTimeout = bounded
            val active: Socket = if (scheme == "https") {
                // SSLSocketFactory.getDefault() 的静态签名返回 SocketFactory，需转回 SSL 工厂。
                val factory = SSLSocketFactory.getDefault() as SSLSocketFactory
                val tls = factory.createSocket(plain, host, port, true) as SSLSocket
                tls.startHandshake()
                socket = tls
                tls
            } else {
                plain
            }
            val head = StringBuilder()
                .append(method.wire).append(' ').append(target).append(" HTTP/1.1\r\n")
                .append("Host: ")
                .append(if (port == defaultPort(scheme)) host else "$host:$port")
                .append("\r\n")
                .append("User-Agent: ").append(WEBDAV_USER_AGENT).append("\r\n")
                .append("Accept: */*\r\n")
                .append("Connection: close\r\n")
            for ((key, value) in headers) {
                head.append(key).append(": ").append(value).append("\r\n")
            }
            if (endpoint.username.isNotEmpty() || endpoint.password.isNotEmpty()) {
                head.append("Authorization: ")
                    .append(basicAuthorizationHeader(endpoint.username, endpoint.password))
                    .append("\r\n")
            }
            if (body != null) {
                head.append("Content-Length: ").append(body.size).append("\r\n")
            }
            head.append("\r\n")

            val output = BufferedOutputStream(active.getOutputStream())
            output.write(head.toString().toByteArray(Charsets.ISO_8859_1))
            if (body != null) output.write(body)
            output.flush()

            val input = BufferedInputStream(active.getInputStream())
            val statusLine = readAsciiLine(input)
                ?: return RawResponse.failure(TransportKind.FORMAT, "missing status line")
            val statusCode = parseStatusLine(statusLine)
                ?: return RawResponse.failure(TransportKind.FORMAT, "bad status line: $statusLine")
            val responseHeaders = readRawHeaders(input)
            val read = readRawBody(input, method, statusCode, responseHeaders)
            RawResponse(
                statusCode = statusCode,
                body = read.bytes,
                headers = responseHeaders,
                truncated = read.truncated,
            )
        } catch (error: SocketTimeoutException) {
            RawResponse.failure(TransportKind.TIMEOUT, error.toString())
        } catch (error: SSLException) {
            RawResponse.failure(TransportKind.HANDSHAKE, error.toString())
        } catch (error: SocketException) {
            RawResponse.failure(TransportKind.SOCKET, error.toString())
        } catch (error: IOException) {
            RawResponse.failure(TransportKind.SOCKET, error.toString())
        } finally {
            try {
                socket?.close()
            } catch (_: IOException) {
                // 关闭失败无所谓：这条连接本来就要丢。
            }
        }
    }

    private fun defaultPort(scheme: String?): Int = if (scheme == "https") 443 else 80

    private fun parseStatusLine(line: String): Int? {
        val parts = line.trim().split(' ')
        if (parts.size < 2 || !parts[0].startsWith("HTTP/")) return null
        return parts[1].toIntOrNull()
    }

    /** 读一行 ASCII（到 `\n` 为止，吃掉 `\r`）；EOF 且没读到任何字节时返回 null。 */
    private fun readAsciiLine(input: InputStream): String? {
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

    private fun readRawHeaders(input: InputStream): WebdavResponseHeaders {
        val raw = linkedMapOf<String, MutableList<String>>()
        while (true) {
            val line = readAsciiLine(input) ?: break
            if (line.isEmpty()) break
            val colon = line.indexOf(':')
            if (colon <= 0) continue
            val name = line.substring(0, colon).trim().lowercase()
            val value = line.substring(colon + 1).trim()
            raw.getOrPut(name) { mutableListOf() }.add(value)
        }
        return WebdavResponseHeaders.from(raw)
    }

    private fun readRawBody(
        input: InputStream,
        method: WebdavMethod,
        statusCode: Int,
        headers: WebdavResponseHeaders,
    ): ReadResult {
        if (method == WebdavMethod.HEAD || statusCode == 204 || statusCode == 304) {
            return ReadResult(ByteArray(0), false)
        }
        val transferEncoding = headers.first("Transfer-Encoding")?.lowercase()
        if (transferEncoding != null && transferEncoding.contains("chunked")) {
            return readChunkedBody(input)
        }
        val contentLength = headers.first("Content-Length")?.trim()?.toLongOrNull()
        if (contentLength != null) return readFixedLength(input, contentLength)
        return readUntilEnd(input)
    }

    private fun readFixedLength(input: InputStream, length: Long): ReadResult {
        if (length > maxResponseBytes) return ReadResult(ByteArray(0), true)
        val out = ByteArrayOutputStream(if (length > 0) length.toInt() else 0)
        val buffer = ByteArray(8192)
        var remaining = length
        while (remaining > 0) {
            val want = minOf(remaining, buffer.size.toLong()).toInt()
            val read = input.read(buffer, 0, want)
            if (read < 0) break
            out.write(buffer, 0, read)
            remaining -= read
        }
        return ReadResult(out.toByteArray(), false)
    }

    private fun readUntilEnd(input: InputStream): ReadResult {
        val out = ByteArrayOutputStream()
        val buffer = ByteArray(8192)
        while (true) {
            val read = input.read(buffer)
            if (read < 0) break
            if (out.size().toLong() + read > maxResponseBytes) {
                return ReadResult(out.toByteArray(), true)
            }
            out.write(buffer, 0, read)
        }
        return ReadResult(out.toByteArray(), false)
    }

    private fun readChunkedBody(input: InputStream): ReadResult {
        val out = ByteArrayOutputStream()
        val buffer = ByteArray(8192)
        while (true) {
            val sizeLine = readAsciiLine(input) ?: break
            val size = sizeLine.substringBefore(';').trim().toLongOrNull(16) ?: break
            if (size == 0L) {
                // trailer 段：读到空行为止。
                while (true) {
                    val trailer = readAsciiLine(input) ?: break
                    if (trailer.isEmpty()) break
                }
                break
            }
            if (out.size().toLong() + size > maxResponseBytes) {
                return ReadResult(out.toByteArray(), true)
            }
            var remaining = size
            while (remaining > 0) {
                val want = minOf(remaining, buffer.size.toLong()).toInt()
                val read = input.read(buffer, 0, want)
                if (read < 0) return ReadResult(out.toByteArray(), true)
                out.write(buffer, 0, read)
                remaining -= read
            }
            readAsciiLine(input) // 块尾 CRLF
        }
        return ReadResult(out.toByteArray(), false)
    }

    private class ReadResult(val bytes: ByteArray, val truncated: Boolean)

    /** 读响应体，超过 [maxResponseBytes] 立即停手并标记截断（不返回半截数据）。 */
    private fun readBounded(stream: InputStream?): ReadResult {
        if (stream == null) return ReadResult(ByteArray(0), false)
        stream.use {
            val out = ByteArrayOutputStream()
            val buffer = ByteArray(8192)
            while (true) {
                val read = it.read(buffer)
                if (read < 0) break
                if (out.size().toLong() + read > maxResponseBytes) {
                    return ReadResult(out.toByteArray(), true)
                }
                out.write(buffer, 0, read)
            }
            return ReadResult(out.toByteArray(), false)
        }
    }

    private data class RawResponse(
        val statusCode: Int?,
        val body: ByteArray,
        val headers: WebdavResponseHeaders,
        val truncated: Boolean = false,
        val failureKind: TransportKind? = null,
        val failureMessage: String? = null,
    ) {
        /** 文本化响应体，只用于「是否明确说不支持锁」这类关键词判定。 */
        fun bodyText(): String = String(body, Charsets.UTF_8)

        companion object {
            fun failure(kind: TransportKind, message: String): RawResponse = RawResponse(
                statusCode = null,
                body = ByteArray(0),
                headers = WebdavResponseHeaders.EMPTY,
                failureKind = kind,
                failureMessage = message,
            )
        }
    }
}

/**
 * JDK `java.net.HttpURLConnection.setRequestMethod` 放行的方法（其余一律
 * `ProtocolException: Invalid HTTP method`）。PROPFIND/MKCOL/LOCK/UNLOCK 因此必须走裸 socket。
 */
private val URL_CONNECTION_METHODS: Set<String> =
    setOf("GET", "POST", "HEAD", "OPTIONS", "PUT", "DELETE", "TRACE")

/**
 * 端点（baseUrl + 凭据）。**scheme 门禁在这里**：传输层本身信任已经过门的端点。
 *
 * `from` 供云同步（http 需显式二次确认），`fromCouple` 供情侣课表（http 一律拒绝，
 * 复用 `CoupleWebdavConfig.validatedCoupleWebdavBaseUrl`）。
 */
data class WebdavEndpoint(
    val baseUrl: String,
    val username: String = "",
    val password: String = "",
) {
    companion object {
        /** 云同步端点；scheme 非法或 http 未放行时返回 null（调用方报 `insecure_url_blocked`）。 */
        fun from(
            config: WebdavSyncConfig,
            password: String,
            allowInsecureHttp: Boolean = false,
        ): WebdavEndpoint? = when (inspectWebdavBaseUrlScheme(config.baseUrl)) {
            WebdavBaseUrlScheme.HTTPS -> WebdavEndpoint(config.baseUrl, config.username, password)
            WebdavBaseUrlScheme.INSECURE_HTTP ->
                if (allowInsecureHttp) WebdavEndpoint(config.baseUrl, config.username, password) else null
            WebdavBaseUrlScheme.INVALID -> null
        }

        /** 情侣课表端点；http 一律拒绝（情侣页没有二次确认入口）。 */
        fun fromCouple(config: CoupleWebdavConfig, password: String): WebdavEndpoint? {
            val url = validatedCoupleWebdavBaseUrl(config.baseUrl) ?: return null
            return WebdavEndpoint(url, config.username, password)
        }
    }
}

/** 写操作结果（PUT / MKCOL / DELETE / UNLOCK / ensureRemoteFolder 共用）。 */
data class WebdavWriteResult(
    val isFailed: Boolean,
    val statusCode: Int? = null,
    val etag: String? = null,
    val errorMessage: String? = null,
    /** DELETE 幂等命中（404）。 */
    val notFound: Boolean = false,
    /** MKCOL 命中「已存在」（405 / 301）。 */
    val alreadyExists: Boolean = false,
) {
    companion object {
        fun ok(statusCode: Int, etag: String?, notFound: Boolean = false, alreadyExists: Boolean = false) =
            WebdavWriteResult(
                isFailed = false,
                statusCode = statusCode,
                etag = etag,
                notFound = notFound,
                alreadyExists = alreadyExists,
            )

        fun failed(message: String, statusCode: Int? = null) =
            WebdavWriteResult(isFailed = true, statusCode = statusCode, errorMessage = message)
    }
}

/** HEAD 探测结果。 */
data class WebdavHeadResult(
    val statusCode: Int?,
    val exists: Boolean,
    val contentLength: Long?,
    val etag: String?,
    val isFailed: Boolean,
    val errorMessage: String?,
) {
    companion object {
        fun present(statusCode: Int, contentLength: Long?, etag: String?) =
            WebdavHeadResult(statusCode, true, contentLength, etag, false, null)

        fun missing(statusCode: Int) =
            WebdavHeadResult(statusCode, false, null, null, false, null)

        fun failed(message: String, statusCode: Int? = null) =
            WebdavHeadResult(statusCode, false, null, null, true, message)
    }
}

/** PROPFIND 结果。 */
data class WebdavPropfindResult(
    val resources: List<WebdavResource> = emptyList(),
    val isFailed: Boolean = false,
    val isNotFound: Boolean = false,
    val errorMessage: String? = null,
) {
    companion object {
        fun ok(resources: List<WebdavResource>) = WebdavPropfindResult(resources = resources)
        fun notFound() = WebdavPropfindResult(isNotFound = true)
        fun failed(message: String) = WebdavPropfindResult(isFailed = true, errorMessage = message)
    }
}
