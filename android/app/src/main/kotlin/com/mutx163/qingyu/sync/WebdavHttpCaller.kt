package com.mutx163.qingyu.sync

/**
 * WebDAV 的一次 HTTP 交换（**不含**重定向/重试语义——那些留在 [WebdavHttpTransport]）。
 *
 * 存在的理由（2026-11-14 用户决定：全软件网络请求改走 OkHttp）：
 * `sync/` 是 L0 共享面（classpath 没有 okhttp jar），所以**传输实现不能写在这里**。
 * 这里只留一个纯接口；生产实现是 `platform/OkHttpWebdavHttpCaller`（统一入口 `QingyuHttp`，
 * 逐请求 `followRedirects = false`），测试实现见 `test/.../sync/JdkTestWebdavHttpCaller`
 * （本地 HTTP 服务器用，JDK 裸 socket，仅测试）。
 *
 * ## 为什么重定向不交给实现
 *
 * 每次重定向都会重发 `Authorization: Basic …`。凭据安全门（跨 host 不跟随、
 * `https→http` 降级不跟随、同 host 跟随）必须在**能拿到 `Location` 的上层**判定，
 * 所以实现必须 `followRedirects = false`，把 3xx + `Location` 原样交回
 * [WebdavHttpTransport] 的 [isCredentialSafeRedirect]。
 */
interface WebdavHttpCaller {

    /**
     * 发一次请求（不跟随重定向）。
     *
     * @param method HTTP 方法原文（GET / PROPFIND / MKCOL / LOCK …）
     * @param url 绝对 URL
     * @param headers 请求头（调用方已合并 UA / Authorization / Depth / Content-Type）
     * @param body 请求体；null = 无体
     * @param connectTimeoutMs 连接预算（已按「取小」算好）
     * @param readTimeoutMs 读取预算
     * @param maxResponseBytes 响应体上限（超出必须截断，不返回半截当完整）
     */
    fun exchange(
        method: String,
        url: String,
        headers: Map<String, String>,
        body: ByteArray?,
        connectTimeoutMs: Int,
        readTimeoutMs: Int,
        maxResponseBytes: Long,
    ): WebdavRawExchange
}

/**
 * 一次交换的结果。
 *
 * @param statusCode null = 没拿到响应（[failureKind] 非空）
 * @param truncated true = 响应体超过上限 / 服务端提前断开（调用方判 `invalid_response`）
 * @param failureKind 传输层失败分类；HTTP 状态码（含 404/423）**不算失败**，照常给 status
 */
data class WebdavRawExchange(
    val statusCode: Int?,
    val headers: WebdavResponseHeaders = WebdavResponseHeaders.EMPTY,
    val body: ByteArray = ByteArray(0),
    val truncated: Boolean = false,
    val failureKind: TransportKind? = null,
    val failureMessage: String? = null,
)

/**
 * 生产发送实现的**安装点**（组合根 `ShellWiring` 在进程启动时安装 OkHttp 实现）。
 *
 * 为什么不是构造参数：`pages/sync/WebdavRemoteTransport.kt` 会进 L0 模块编译面，
 * 直接引用 `platform.OkHttpWebdavHttpCaller` 会让 `-Module pages/sync` 报
 * `Unresolved reference`（classpath 没有 okhttp）。所以页面层只拿接口；
 * 具体实现在组合根装进这里，传输层取它。
 *
 * 测试不需要碰它（默认 null = 传输层的 JDK 兼容路径），保证既有 JVM 用例不受影响。
 */
object WebdavHttpCallers {
    @Volatile
    var installed: WebdavHttpCaller? = null
}
