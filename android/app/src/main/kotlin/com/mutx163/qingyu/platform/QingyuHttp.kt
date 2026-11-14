package com.mutx163.qingyu.platform

import com.mutx163.qingyu.infra.NetLog
import java.io.IOException
import java.io.InterruptedIOException
import java.net.SocketTimeoutException
import java.util.concurrent.Callable
import java.util.concurrent.ExecutionException
import java.util.concurrent.Executors
import java.util.concurrent.Future
import java.util.concurrent.TimeUnit
import okhttp3.Call
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody

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
 * UA / Accept / 超时全部**逐请求传**：[HttpCallSpec] 里有 `headers`、`connectTimeoutMs`、
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

    /** 竞速并发池：最多 4 路（更新清单 2~3 路，留余量）。 */
    private val racePool = Executors.newFixedThreadPool(4) { runnable ->
        Thread(runnable, "qingyu-http").apply { isDaemon = true }
    }

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
                val raw = response.body?.bytes()
                val size = raw?.size?.toLong()
                if (!response.isSuccessful) {
                    respond(
                        HttpResult(
                            status = response.code,
                            bytes = size,
                            elapsedMs = elapsed(),
                            failure = NetLog.FAILURE_HTTP_STATUS,
                            errorClass = HTTP_STATUS_MARKER,
                            url = spec.url,
                            method = spec.method,
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
                val raw = response.body?.bytes()
                val result = if (!response.isSuccessful) {
                    HttpBinaryResult(
                        status = response.code,
                        bytes = raw?.size?.toLong(),
                        failure = NetLog.FAILURE_HTTP_STATUS,
                        errorClass = HTTP_STATUS_MARKER,
                        url = spec.url,
                        method = spec.method,
                        elapsedMs = elapsed(),
                    )
                } else {
                    HttpBinaryResult(
                        status = response.code,
                        data = raw,
                        bytes = raw?.size?.toLong(),
                        url = spec.url,
                        method = spec.method,
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

    /**
     * 多路竞速：先拿到成功结果的一路胜出，其余**立刻 cancel**（不等满 readTimeout）。
     *
     * 全失败时返回最后完成的那一个失败结果（至少带得出错误类与耗时）。
     */
    fun firstSuccess(specs: List<HttpCallSpec>): HttpResult {
        require(specs.isNotEmpty()) { "firstSuccess requires at least one spec" }
        val calls = ArrayList<Call>(specs.size)
        val lock = Any()
        val futures: List<Future<HttpResult>> = specs.map { spec ->
            racePool.submit(
                Callable {
                    val started = System.nanoTime()
                    fun elapsed(): Long = (System.nanoTime() - started) / 1_000_000
                    val request = runCatching { buildRequest(spec) }.getOrNull()
                    if (request == null) {
                        return@Callable HttpResult(
                            failure = NetLog.FAILURE_NETWORK,
                            errorClass = "BuildRequest",
                            url = spec.url,
                            method = spec.method,
                        )
                    }
                    val call = buildClient(spec).newCall(request)
                    synchronized(lock) { calls += call }
                    try {
                        call.execute().use { response ->
                            val raw = response.body?.bytes()
                            if (!response.isSuccessful) {
                                HttpResult(
                                    status = response.code,
                                    bytes = raw?.size?.toLong(),
                                    elapsedMs = elapsed(),
                                    failure = NetLog.FAILURE_HTTP_STATUS,
                                    errorClass = HTTP_STATUS_MARKER,
                                    url = spec.url,
                                    method = spec.method,
                                )
                            } else {
                                HttpResult(
                                    status = response.code,
                                    body = raw?.toString(Charsets.UTF_8).orEmpty(),
                                    bytes = raw?.size?.toLong(),
                                    elapsedMs = elapsed(),
                                    url = spec.url,
                                    method = spec.method,
                                )
                            }
                        }
                    } catch (error: Exception) {
                        HttpResult(
                            failure = failureOf(error),
                            errorClass = error.javaClass.simpleName,
                            url = spec.url,
                            method = spec.method,
                            elapsedMs = elapsed(),
                        )
                    }
                },
            )
        }
        var lastFailure: HttpResult? = null
        for (future in futures) {
            val result = try {
                future.get()
            } catch (_: ExecutionException) {
                continue
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
                continue
            }
            if (result.isSuccess) {
                // 胜者出现，败者立刻停——这就是 cancel 相对旧 readTimeout 的优势。
                synchronized(lock) { calls.forEach { call -> if (!call.isCanceled()) call.cancel() } }
                record(result)
                return result
            }
            lastFailure = result
        }
        val failure = lastFailure ?: HttpResult(
            failure = NetLog.FAILURE_NETWORK,
            url = specs.first().url,
            method = specs.first().method,
        )
        record(failure)
        return failure
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

    /** 给少数 POST 用；GET 不会用到。 */
    fun jsonBody(json: String): RequestBody = json.toRequestBody(JSON_MEDIA_TYPE)

    // ---------- 内部 ----------

    private const val BUFFER_BYTES: Int = 8 * 1024

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
            spec.readTimeoutMs == DEFAULT_READ_TIMEOUT_MS
        ) {
            client
        } else {
            client.newBuilder()
                .connectTimeout(spec.connectTimeoutMs, TimeUnit.MILLISECONDS)
                .readTimeout(spec.readTimeoutMs, TimeUnit.MILLISECONDS)
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





