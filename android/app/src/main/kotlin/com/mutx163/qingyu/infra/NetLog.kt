package com.mutx163.qingyu.infra

/**
 * 统一**网络日志**层（2026-11-14 用户决定「所有网络请求都改走 OkHttp」后的调试地基）。
 *
 * ## 解决什么事
 *
 * 以前每个网络接缝各自 `catch → null`，失败只有一句「更新失败」，用户和开发者都看不出
 * 是超时、非 200 还是解析错（天气实报）。这里定一套**唯一字段口径**，所有接缝复用：
 *
 * ```
 * method=GET host=api.open-meteo.com path=/v1/forecast status=200 elapsedMs=4219 bytes=15667 failure=none errorClass= detail=
 * ```
 *
 * ## 脱敏（硬约束，改之前先读）
 *
 * - 只写 `host` + `path`：**query 一律不写**。天气的经纬度、云同步的 token、WebDAV 的用户名
 *   都可能出现在 query 里；写进去就等于把这些搬进应用日志。
 * - 不写请求头、不写响应体、不写账号密码。
 * - `detail` 只放**异常类名 / 字段名 / 行号**，不放异常消息（消息常带完整 URL）。
 *
 * ## 落点
 *
 * [AppLogStore.append]（`infra`，纯 Kotlin）。诊断页「应用日志」按 `category=network`
 * 就能看到；正式包装了也只是一条普通日志，不额外引依赖、不改变网络行为。
 *
 * @see AppLogStore
 */
object NetLog {

    /** 应用日志分类（诊断页按它过滤；ASCII，跨语言可比）。 */
    const val CATEGORY: String = "network"

    /** 四个失败类 + 一个兜底；值写进 `failure=` 字段（小写）。 */
    const val FAILURE_NETWORK: String = "network"
    const val FAILURE_TIMEOUT: String = "timeout"
    const val FAILURE_HTTP_STATUS: String = "http_status"
    const val FAILURE_NOT_JSON: String = "not_json"
    const val FAILURE_PARSE: String = "parse"
    const val FAILURE_EMPTY: String = "empty"

    /**
     * 请求被**主动取消**（不是失败）：多路竞速里的败者、用户离开页面中断的下载。
     *
     * 与 [FAILURE_TIMEOUT] 分开是必要的：超时说明「等不到」，取消说明「我们不要了」；
     * 混成一个值会让日志读不出到底是谁的锅（2026-11-14 定口径时加的第七档）。
     */
    const val FAILURE_CANCELLED: String = "cancelled"

    /** detail 单条上限（字段名 + 行号，不需要更长）。 */
    const val MAX_DETAIL_CHARS: Int = 160

    /**
     * 记一条网络事件。
     *
     * @param url 原始 URL，只取 `host` 与 `path`（query 丢弃）
     * @param method HTTP 方法（GET / PROPFIND …）
     * @param status 响应状态码；没拿到响应为 null
     * @param elapsedMs 从发起到拿到结果的毫秒数（或到失败为止）
     * @param bytes 响应体字节数；没有响应体为 null
     * @param failure 失败分类（[FAILURE_NETWORK] 等）；成功传 null
     * @param errorClass 异常类名（`SocketTimeoutException` 等）；解析失败可为 null
     * @param detail 脱敏后的补充：`field=hourly line=1`、`at=WeatherForecast.kt:216`
     * @return true = 真的写进应用日志
     */
    fun record(
        url: String,
        method: String = "GET",
        status: Int? = null,
        elapsedMs: Long,
        bytes: Long? = null,
        failure: String? = null,
        errorClass: String? = null,
        detail: String? = null,
    ): Boolean {
        if (!AppLogStore.isInitialized()) return false
        val (host, path) = splitHostAndPath(url)
        val fields = buildList {
            add("method=${method.trim().ifEmpty { "GET" }}")
            add("host=$host")
            add("path=$path")
            add("status=${status?.toString() ?: "none"}")
            add("elapsedMs=$elapsedMs")
            add("bytes=${bytes?.toString() ?: "none"}")
            add("failure=${failure ?: "none"}")
            if (!errorClass.isNullOrBlank()) add("errorClass=$errorClass")
            detail
                ?.take(MAX_DETAIL_CHARS)
                ?.takeIf { it.isNotBlank() }
                ?.let { add("detail=$it") }
        }
        return AppLogStore.append(
            level = if (failure == null) LEVEL_INFO else LEVEL_WARN,
            category = CATEGORY,
            message = fields.joinToString(separator = " "),
        )
    }

    /**
     * URL → `(host, path)`：**query 与 fragment 一律丢掉**，解析失败时整串不写（防止把
     * 带 token 的畸形 URL 原样搬进日志）。
     */
    fun splitHostAndPath(url: String): Pair<String, String> {
        val withoutScheme = url.substringAfter("://", missingDelimiterValue = "")
        val hostAndRest = withoutScheme.substringBefore('/')
        if (hostAndHostBlank(hostAndRest)) return "invalid" to "-"
        val host = hostAndRest.substringBefore('?').substringBefore('#')
        val rawPath = withoutScheme.substringAfter('/', missingDelimiterValue = "")
        val path = if (rawPath.isEmpty()) "/" else "/" + rawPath.substringBefore('?').substringBefore('#')
        return host to path
    }

    private fun hostAndHostBlank(host: String): Boolean = host.isBlank()

    private const val LEVEL_INFO: String = "info"
    private const val LEVEL_WARN: String = "warn"
}
