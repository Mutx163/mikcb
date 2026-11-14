package com.mutx163.qingyu.platform

import com.mutx163.qingyu.infra.NetLog
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.InterruptedIOException
import java.net.SocketTimeoutException
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import okhttp3.Call
import okhttp3.Callback
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.ResponseBody
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response

/**
 * 全软件网络请求的**统一入口**（2026-11-14 用户决定：所有网络请求都改走 OkHttp）。
 *
 * ## 为什么在 `platform/`，不在 `infra/`
 *
 * `infra/` 是 `scripts/test-kotlin-module.ps1` 的 L0 **共享面**（`$sharedModelDirs` 含 `infra`），
 * 而 L0 的 classpath 只有 junit / hamcrest / kotlin-stdlib（脚本 `:245-250`），**没有 okhttp jar**。
 * 把 `import okhttp3.*` 写进 `infra/`，24 个模块的 L0 会一起 `Unresolved reference`。
 * 所以：**口径与落盘**留在纯 Kotlin 的 `infra/NetLog.kt`（L0 可测），**OkHttp 实现**放这里
 * （`platform/` 不进 L0 共享面，L1/L2 正常编）。移动这条边界之前先读 `OkHttpWeatherHttp.kt` 头注。
 *
 * ## 口径（与 `infra/NetLog` 对齐，别人照抄、不许自造）
 *
 * 每次请求结束都走 [NetLog.record] 记一条，字段固定：
 * `method host path status elapsedMs bytes failure errorClass detail`，`category=network`；
 * `failure` 取 `network / timeout / http_status / not_json / parse / empty / cancelled`。
 * **只写 host + path，query 一律不写**（经纬度、token、WebDAV 用户名都在 query 里）。
 *
 * ## 四条能力（迁移清单里 11 个调用点的实际需求）
 *
 * 1. [getText]：普通/自定义方法，整段文本进内存（清单、JSON、小文件）；
 * 2. [getBytes]：二进制进内存（图片解码、缩略图），不做 UTF-8 解码；
 * 3. [stream]：**流式**读，逐块交给调用方 + 进度回调，返回 [HttpCall] 可 `cancel()`；
 * 4. [firstSuccess]：多路竞速，先成功者胜，**败者立刻 `Call.cancel()`**。
 *
 * ## 一处一个客户端\n *\n * 全局只有 [client] 这一个 OkHttpClient；[buildClient] 用 
ewBuilder() 派生只改超时的副本，\n * 连接池 / dispatcher / 线程池按 OkHttp 契约**与父客户端共享**，不是第二个客户端。\n * 实现方（platform/OkHttp*.kt）一律通过本对象发请求，不许各建一个 OkHttpClient。\n *\n * UA / Accept / 超时全部**逐请求传**：[HttpCallSpec] 里有 `headers`、`connectTimeoutMs`、
 * `readTimeoutMs`；地基只给兜底 UA（[DEFAULT_USER_AGENT]），不写死任何业务头。
 *
 * @see NetLog
 */
object QingyuHttp {

    /** 兜底 UA：调用方没传 `User-Agent` 时用；有自己 UA 的（天气、更新检查）必须自己传。 */
    const val DEFAULT_USER_AGENT: String = "mikcb-android"

    /** 默认连接超时（毫秒）。 */
    const val DEFAULT_CONNECT_TIMEOUT_MS: Long = 10_000L

    /** 默认读取超时（毫秒）。 */
    const val DEFAULT_READ_TIMEOUT_MS: Long = 15_000L

    /** 进程级单例：连接池与线程池共享一份（「统一入口」的意义之一）。 */
    val client: OkHttpClient by lazy {
        OkHttpClient.Builder()
            .connectTimeout(DEFAULT_CONNECT_TIMEOUT_MS, TimeUnit.MILLISECONDS)
            .readTimeout(DEFAULT_READ_TIMEOUT_MS, TimeUnit.MILLISECONDS)
            .followRedirects(true)
            .build()
    }

    /** 一次请求的全部参数（不可变；超时、头、方法都从这里取）。 */
    data class HttpCallSpec(
        val url: String,
        val method: String = "GET",
        val headers: Map<String, String> = emptyMap(),
        val body: RequestBody? = null,
        val connectTimeoutMs: Long = DEFAULT_CONNECT_TIMEOUT_MS,
        val readTimeoutMs: Long = DEFAULT_READ_TIMEOUT_MS,
        /** 响应体上限（字节）；0 = 不限。超限按失败收口，**不把超大响应整段读进内存**。 */
        val maxBytes: Long = 0L,
        /**
         * 是否跟随重定向（逐请求）。默认 true；WebDAV 必须传 false——它有一道凭据安全门：
         * 跨 host、https→http 降级的跳转一律不跟随（每跳都会重发 Basic 凭据），所以跳转只许
         * 由调用方自己判 Location 后决定跟不跟。
         */
        val followRedirects: Boolean = true,
        /** 诊断标签（竞速各路的来源，如 `github` / `gitcode`）。 */
        val tag: String? = null,
    )

    /** 文本结果。失败时 [failure] 非 null。 */
    data class HttpResult(
        val status: Int? = null,
        val body: String? = null,
        val bytes: Long? = null,
        val elapsedMs: Long = 0L,
        val failure: String? = null,
        val errorClass: String? = null,
        val url: String = "",
        val method: String = "GET",
        /**
         * 响应头（不强求存在）。给 WebDAV 这类要读 Location / ETag 的调用方用；
         * **不打进网络日志**（日志只写 host+path），因为头里可能有凭据类信息。
         */
        val headers: Map<String, List<String>> = emptyMap(),
    ) {
        val isSuccess: Boolean get() = failure == null && status != null
    }

    /** 二进制结果（图片等）：[data] 原始字节，不做编码转换。 */
    data class HttpBinaryResult(
        val status: Int? = null,
        val data: ByteArray? = null,
        val bytes: Long? = null,
        val elapsedMs: Long = 0L,
        val failure: String? = null,
        val errorClass: String? = null,
        val url: String = "",
        val method: String = "GET",
        /** 响应头（同 [HttpResult.headers]）；不打进网络日志。 */
        val headers: Map<String, List<String>> = emptyMap(),
    ) {
        val isSuccess: Boolean get() = failure == null && status != null
    }

    /** 可取消句柄（流式下载 / 竞速败者用）。 */
    class HttpCall internal constructor(private val call: Call?) {
        fun cancel() {
            call?.cancel()
        }

        val isCanceled: Boolean get() = call?.isCanceled() == true
    }

    /** 普通请求：整段文本进内存。 */
    fun getText(spec: HttpCallSpec): HttpResult {
        val started = System.nanoTime()
        fun elapsed(): Long = (System.nanoTime() - started) / 1_000_000
        val request = runCatching { buildRequest(spec) }.getOrElse { error ->
            return fail(spec, null, null, elapsed(), NetLog.FAILURE_NETWORK, error)
        }
        return try {
            buildClient(spec).newCall(request).execute().use { response ->
                val responseHeaders = response.headers.toMultimap()
                val bounded = response.body?.let { readBounded(it, spec.maxBytes) }
                val raw = bounded?.bytes
                val size = bounded?.readBytes ?: 0L
                if (bounded?.tooLarge == true) {
                    respond(
                        HttpResult(
                            status = response.code,
                            bytes = size,
                            elapsedMs = elapsed(),
                            failure = NetLog.FAILURE_TOO_LARGE,
                            errorClass = MAX_BYTES_MARKER,
                            url = spec.url,
                            method = spec.method,
                            headers = responseHeaders,
                        ),
                    )
                } else if (!response.isSuccessful) {
                    respond(
                        HttpResult(
                            status = response.code,
                            bytes = size,
                            elapsedMs = elapsed(),
                            failure = NetLog.FAILURE_HTTP_STATUS,
                            errorClass = HTTP_STATUS_MARKER,
                            url = spec.url,
                            method = spec.method,
                            headers = responseHeaders,
                        ),
                    )
                } else {
                    respond(
                        HttpResult(
                            status = response.code,
                            body = raw?.toString(Charsets.UTF_8).orEmpty(),
                            bytes = size,
                            elapsedMs = elapsed(),
                            url = spec.url,
                            method = spec.method,
                            headers = responseHeaders,
                        ),
                    )
                }
            }
        } catch (error: Exception) {
            fail(spec, null, null, elapsed(), failureOf(error), error)
        }
    }

    /** 二进制请求：不解码、不转字符串（图片 / 缩略图）。 */
    fun getBytes(spec: HttpCallSpec): HttpBinaryResult {
        val started = System.nanoTime()
        fun elapsed(): Long = (System.nanoTime() - started) / 1_000_000
        val request = runCatching { buildRequest(spec) }.getOrElse { error ->
            val result = HttpBinaryResult(
                failure = NetLog.FAILURE_NETWORK,
                errorClass = error.javaClass.simpleName,
                url = spec.url,
                method = spec.method,
                elapsedMs = elapsed(),
            )
            recordBinary(result)
            return result
        }
        return try {
            buildClient(spec).newCall(request).execute().use { response ->
                val responseHeaders = response.headers.toMultimap()
                val bounded = response.body?.let { readBounded(it, spec.maxBytes) }
                val raw = bounded?.bytes
                val result = if (bounded?.tooLarge == true) {
                    HttpBinaryResult(
                        status = response.code,
                        bytes = bounded.readBytes,
                        failure = NetLog.FAILURE_TOO_LARGE,
                        errorClass = MAX_BYTES_MARKER,
                        url = spec.url,
                        method = spec.method,
                        headers = responseHeaders,
                        elapsedMs = elapsed(),
                    )
                } else if (!response.isSuccessful) {
                    HttpBinaryResult(
                        status = response.code,
                        bytes = raw?.size?.toLong(),
                        failure = NetLog.FAILURE_HTTP_STATUS,
                        errorClass = HTTP_STATUS_MARKER,
                        url = spec.url,
                        method = spec.method,
                        headers = responseHeaders,
                        elapsedMs = elapsed(),
                    )
                } else {
                    HttpBinaryResult(
                        status = response.code,
                        data = raw,
                        bytes = raw?.size?.toLong(),
                        url = spec.url,
                        method = spec.method,
                        headers = responseHeaders,
                        elapsedMs = elapsed(),
                    )
                }
                recordBinary(result)
                result
            }
        } catch (error: Exception) {
            val result = HttpBinaryResult(
                failure = failureOf(error),
                errorClass = error.javaClass.simpleName,
                url = spec.url,
                method = spec.method,
                elapsedMs = elapsed(),
            )
            recordBinary(result)
            result
        }
    }

    /**
     * 流式请求：每读一块交给 [onChunk]，[onProgress] 报进度；返回 [HttpCall] 可随时取消。
     *
     * 用于 APK / 壁纸原图这类「不能整块进内存」的下载。
     */
    fun stream(
        spec: HttpCallSpec,
        onChunk: (ByteArray, Int) -> Unit,
        onProgress: (receivedBytes: Long, totalBytes: Long?) -> Unit = { _, _ -> },
    ): Pair<HttpCall, HttpResult> {
        val started = System.nanoTime()
        fun elapsed(): Long = (System.nanoTime() - started) / 1_000_000
        val request = runCatching { buildRequest(spec) }.getOrElse { error ->
            val result = fail(spec, null, 0L, elapsed(), NetLog.FAILURE_NETWORK, error)
            return HttpCall(null) to result
        }
        val call = buildClient(spec).newCall(request)
        var received = 0L
        return try {
            call.execute().use { response ->
                val total = response.body?.contentLength()?.takeIf { it >= 0 }
                if (!response.isSuccessful) {
                    val result = HttpResult(
                        status = response.code,
                        bytes = 0L,
                        elapsedMs = elapsed(),
                        failure = NetLog.FAILURE_HTTP_STATUS,
                        errorClass = HTTP_STATUS_MARKER,
                        url = spec.url,
                        method = spec.method,
                    )
                    record(result)
                    HttpCall(call) to result
                } else {
                    val source = response.body?.byteStream()
                    if (source == null) {
                        HttpCall(call) to fail(
                            spec, response.code, 0L, elapsed(), NetLog.FAILURE_EMPTY, null,
                        )
                    } else {
                        val buffer = ByteArray(BUFFER_BYTES)
                        var read = source.read(buffer)
                        while (read >= 0) {
                            if (read > 0) {
                                onChunk(buffer, read)
                                received += read
                                onProgress(received, total)
                                if (spec.maxBytes > 0L && received > spec.maxBytes) {
                                    call.cancel()
                                    val tooLarge = fail(
                                        spec, response.code, received, elapsed(),
                                        NetLog.FAILURE_TOO_LARGE, null,
                                    )
                                    return HttpCall(call) to tooLarge
                                }
                            }
                            read = source.read(buffer)
                        }
                        val result = HttpResult(
                            status = response.code,
                            bytes = received,
                            elapsedMs = elapsed(),
                            url = spec.url,
                            method = spec.method,
                        )
                        record(result)
                        HttpCall(call) to result
                    }
                }
            }
        } catch (error: Exception) {
            val result = fail(spec, null, received, elapsed(), failureOf(error), error)
            HttpCall(call) to result
        }
    }

    /** 竞速里的一路成功：带上它的 spec，宿主据此判断「同版本 + 直连渠道」等业务条件。 */
    data class RacedSuccess(val spec: HttpCallSpec, val result: HttpResult)

    /**
     * 竞速结果：[winner] = 首个成功（全失败时是最后一个失败结果）；[successes] = 按**到达顺序**
     * 记录的全部成功，第 0 个就是 winner。
     */
    data class RacedResult(
        val winner: HttpResult?,
        val successes: List<RacedSuccess>,
    ) {
        val hasWinner: Boolean get() = winner?.isSuccess == true
    }

    /**
     * 多路竞速。**用 OkHttp 自己的异步回调**（`enqueue`），不另建线程池——全局就一个
     * [client]（其 dispatcher / 连接池共享），这是「一处一个 OkHttpClient」的硬规矩。
     *
     * 语义由 [lingerMs] 分两段：
     *
     * - [lingerMs] == 0（默认）：赢家一出现**立刻 cancel** 其余路。
     * - [lingerMs] > 0：赢家出现后保留缓冲窗口，跑完的兄弟路按到达顺序收进
     *   [RacedResult.successes]；窗口一到，未完成的立刻 cancel。检查更新靠它：Release 页 HTML
     *   赢家没有 SHA 摘要，要在窗口内等同版本 + 直连渠道的兄弟路补上。
     *
     * **窗口宽度不由地基决定**：这类业务值（如摘要回填窗口）必须由宿主传有名常量，地基默认 0、
     * 也不许写死具体数字——否则「窗口由谁定」没法用守卫钉住。
     *
     * 全失败时 [RacedResult.successes] 为空，[RacedResult.winner] 是最后完成的失败结果。
     */
    fun firstSuccess(specs: List<HttpCallSpec>, lingerMs: Long = 0L): RacedResult {
        require(specs.isNotEmpty()) { "firstSuccess requires at least one spec" }
        val results = arrayOfNulls<HttpResult>(specs.size)
        val arrivals = LinkedBlockingQueue<Int>(specs.size)
        val calls = ArrayList<Call>(specs.size)
        val lock = Any()

        fun recordArrival(index: Int, result: HttpResult) {
            results[index] = result
            arrivals.offer(index)
        }

        specs.forEachIndexed { index, spec ->
            val startedAt = System.nanoTime()
            fun elapsed(): Long = (System.nanoTime() - startedAt) / 1_000_000
            val request = runCatching { buildRequest(spec) }.getOrNull()
            if (request == null) {
                recordArrival(
                    index,
                    HttpResult(
                        failure = NetLog.FAILURE_NETWORK,
                        errorClass = "BuildRequest",
                        url = spec.url,
                        method = spec.method,
                    ),
                )
                return@forEachIndexed
            }
            val call = buildClient(spec).newCall(request)
            synchronized(lock) { calls += call }
            call.enqueue(
                object : Callback {
                    override fun onFailure(call: Call, e: IOException) {
                        recordArrival(
                            index,
                            HttpResult(
                                failure = failureOf(e),
                                errorClass = e.javaClass.simpleName,
                                url = spec.url,
                                method = spec.method,
                                elapsedMs = elapsed(),
                            ),
                        )
                    }

                    override fun onResponse(call: Call, response: Response) {
                        val result = response.use { resp ->
                            val bounded = resp.body?.let { readBounded(it, spec.maxBytes) }
                            val raw = bounded?.bytes
                            if (bounded?.tooLarge == true) {
                                HttpResult(
                                    status = resp.code,
                                    bytes = bounded.readBytes,
                                    elapsedMs = elapsed(),
                                    failure = NetLog.FAILURE_TOO_LARGE,
                                    errorClass = MAX_BYTES_MARKER,
                                    url = spec.url,
                                    method = spec.method,
                                )
                            } else if (!resp.isSuccessful) {
                                HttpResult(
                                    status = resp.code,
                                    bytes = raw?.size?.toLong(),
                                    elapsedMs = elapsed(),
                                    failure = NetLog.FAILURE_HTTP_STATUS,
                                    errorClass = HTTP_STATUS_MARKER,
                                    url = spec.url,
                                    method = spec.method,
                                )
                            } else {
                                HttpResult(
                                    status = resp.code,
                                    body = raw?.toString(Charsets.UTF_8).orEmpty(),
                                    bytes = raw?.size?.toLong(),
                                    elapsedMs = elapsed(),
                                    url = spec.url,
                                    method = spec.method,
                                )
                            }
                        }
                        recordArrival(index, result)
                    }
                },
            )
        }

        val successes = ArrayList<RacedSuccess>(specs.size)
        var winnerIndex = -1
        var remaining = specs.size
        while (remaining-- > 0 && winnerIndex < 0) {
            val index = arrivals.take()
            val result = results[index] ?: continue
            if (result.isSuccess) {
                winnerIndex = index
                successes += RacedSuccess(specs[index], result)
            }
        }

        if (winnerIndex >= 0 && lingerMs > 0L) {
            val deadline = System.nanoTime() + lingerMs * 1_000_000L
            while (true) {
                val left = deadline - System.nanoTime()
                if (left <= 0L) break
                val index = arrivals.poll(left, TimeUnit.NANOSECONDS) ?: break
                val result = results[index] ?: continue
                if (result.isSuccess) successes += RacedSuccess(specs[index], result)
            }
        }

        synchronized(lock) { calls.forEach { call -> if (!call.isCanceled()) call.cancel() } }

        if (winnerIndex < 0) {
            val failure = results.filterNotNull().lastOrNull() ?: HttpResult(
                failure = NetLog.FAILURE_NETWORK,
                url = specs.first().url,
                method = specs.first().method,
            )
            record(failure)
            return RacedResult(winner = failure, successes = emptyList())
        }
        val winnerResult = results[winnerIndex]!!
        record(winnerResult)
        return RacedResult(winner = winnerResult, successes = successes)
    }
    /**
     * 解析失败也要落一条（`failure=parse` / `not_json`，`detail` 里放字段名与行号）。
     *
     * 解析在纯 Kotlin 层做（L0 可测）：`status=none` 就是「传输成功、解析失败」的记号。
     */
    fun recordParseFailure(
        url: String,
        method: String = "GET",
        failure: String = NetLog.FAILURE_PARSE,
        detail: String? = null,
        elapsedMs: Long = 0L,
    ) {
        NetLog.record(
            url = url,
            method = method,
            elapsedMs = elapsedMs,
            failure = failure,
            detail = detail,
        )
    }

    /** 有界读取：超限立刻停，绝不把超大响应整段读进内存。 */
    private fun readBounded(body: ResponseBody, maxBytes: Long): BoundedBody {
        val source = body.byteStream()
        val collector = ByteArrayOutputStream()
        val buffer = ByteArray(BUFFER_BYTES)
        var total = 0L
        while (true) {
            val read = source.read(buffer)
            if (read < 0) break
            total += read
            if (maxBytes > 0L && total > maxBytes) {
                return BoundedBody(bytes = null, readBytes = total, tooLarge = true)
            }
            collector.write(buffer, 0, read)
        }
        return BoundedBody(bytes = collector.toByteArray(), readBytes = total, tooLarge = false)
    }

    /** [readBounded] 的结果：超限时 [bytes] 为 null、[readBytes] 是已读到的字节数。 */
    private data class BoundedBody(val bytes: ByteArray?, val readBytes: Long, val tooLarge: Boolean)
    /** 给少数 POST 用；GET 不会用到。 */
    fun jsonBody(json: String): RequestBody = json.toRequestBody(JSON_MEDIA_TYPE)

    // ---------- 内部 ----------

    private const val BUFFER_BYTES: Int = 8 * 1024

    /** 超 [HttpCallSpec.maxBytes] 时 rrorClass 的固定标记。 */
    private const val MAX_BYTES_MARKER: String = "maxBytes"

    /** 非 200 时 `errorClass` 的固定标记（与天气实现同口径）。 */
    private const val HTTP_STATUS_MARKER: String = "HTTP"

    private val JSON_MEDIA_TYPE = "application/json; charset=utf-8".toMediaType()

    private fun buildRequest(spec: HttpCallSpec): Request {
        val builder = Request.Builder().url(spec.url)
        spec.headers.forEach { (name, value) -> builder.header(name, value) }
        if (spec.headers.keys.none { it.equals("User-Agent", ignoreCase = true) }) {
            builder.header("User-Agent", DEFAULT_USER_AGENT)
        }
        val hasBody = spec.method != "GET" && spec.method != "HEAD"
        builder.method(spec.method, if (hasBody) spec.body else null)
        return builder.build()
    }

    private fun buildClient(spec: HttpCallSpec): OkHttpClient =
        if (spec.connectTimeoutMs == DEFAULT_CONNECT_TIMEOUT_MS &&
            spec.readTimeoutMs == DEFAULT_READ_TIMEOUT_MS &&
            spec.followRedirects
        ) {
            client
        } else {
            client.newBuilder()
                .connectTimeout(spec.connectTimeoutMs, TimeUnit.MILLISECONDS)
                .readTimeout(spec.readTimeoutMs, TimeUnit.MILLISECONDS)
                .followRedirects(spec.followRedirects)
                .build()
        }

    /** 取消必须先于「通用 IO」判断：`Call.cancel()` 会抛 IOException("Canceled")。 */
    private fun failureOf(error: Throwable): String = when {
        error is SocketTimeoutException || error is InterruptedIOException -> NetLog.FAILURE_TIMEOUT
        error is IOException && error.message?.contains("Canceled", ignoreCase = true) == true ->
            NetLog.FAILURE_CANCELLED
        else -> NetLog.FAILURE_NETWORK
    }

    private fun respond(result: HttpResult): HttpResult {
        record(result)
        return result
    }

    private fun record(result: HttpResult) {
        NetLog.record(
            url = result.url,
            method = result.method,
            status = result.status,
            elapsedMs = result.elapsedMs,
            bytes = result.bytes,
            failure = result.failure,
            errorClass = result.errorClass,
        )
    }

    private fun recordBinary(result: HttpBinaryResult) {
        NetLog.record(
            url = result.url,
            method = result.method,
            status = result.status,
            elapsedMs = result.elapsedMs,
            bytes = result.bytes,
            failure = result.failure,
            errorClass = result.errorClass,
        )
    }

    private fun fail(
        spec: HttpCallSpec,
        status: Int?,
        bytes: Long?,
        elapsedMs: Long,
        failure: String,
        error: Throwable?,
    ): HttpResult {
        val result = HttpResult(
            status = status,
            bytes = bytes,
            elapsedMs = elapsedMs,
            failure = failure,
            errorClass = error?.javaClass?.simpleName,
            url = spec.url,
            method = spec.method,
        )
        record(result)
        return result
    }
}


















