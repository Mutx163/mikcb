package com.mutx163.qingyu.platform

import com.mutx163.qingyu.infra.NetLog
import com.mutx163.qingyu.sync.TransportKind
import com.mutx163.qingyu.sync.WebdavHttpCaller
import com.mutx163.qingyu.sync.WebdavRawExchange
import com.mutx163.qingyu.sync.WebdavResponseHeaders
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody

/**
 * WebDAV 的真实 HTTP 实现：统一入口 [QingyuHttp]（OkHttp 单例）。
 *
 * ## 关键：`followRedirects = false`
 *
 * WebDAV 每次重定向都会重发 `Authorization: Basic …`。凭据安全门
 * （[com.mutx163.qingyu.sync.isCredentialSafeRedirect]）在 [com.mutx163.qingyu.sync.WebdavHttpTransport]
 * 里按 `Location` 逐跳判定，所以这里**必须**让 OkHttp 不自动跟随——否则 302 跨站时
 * 口令已经跟着走了，安全门形同虚设。这条由门禁官的源码守卫钉住。
 *
 * ## HTTP 状态码不是失败
 *
 * `QingyuHttp` 对非 2xx 会给 `failure=http_status` + `status`；WebDAV 需要原样拿到
 * 404 / 423 / 301 等状态码（DELETE 404 = 幂等命中、MKCOL 405 = 已存在），所以这里把
 * 「有状态码」的响应一律当作正常交换返回；只有拿不到响应 / 响应超限才算失败。
 */
class OkHttpWebdavHttpCaller : WebdavHttpCaller {

    override fun exchange(
        method: String,
        url: String,
        headers: Map<String, String>,
        body: ByteArray?,
        connectTimeoutMs: Int,
        readTimeoutMs: Int,
        maxResponseBytes: Long,
    ): WebdavRawExchange {
        val spec = QingyuHttp.HttpCallSpec(
            url = url,
            method = method,
            headers = headers,
            body = body?.toRequestBody(BODY_MEDIA_TYPE),
            connectTimeoutMs = connectTimeoutMs.toLong().coerceAtLeast(1L),
            readTimeoutMs = readTimeoutMs.toLong().coerceAtLeast(1L),
            // 凭据安全门在传输层按 Location 判定，这里不许自动跟随（见类注释）。
            followRedirects = false,
            maxBytes = maxResponseBytes,
        )
        val result = QingyuHttp.getBytes(spec)
        val status = result.status
        val responseHeaders = WebdavResponseHeaders.from(result.headers)
        if (status == null) {
            return WebdavRawExchange(
                statusCode = null,
                headers = WebdavResponseHeaders.EMPTY,
                failureKind = failureKindOf(result.failure, result.errorClass),
                failureMessage = result.errorClass,
            )
        }
        if (result.failure == NetLog.FAILURE_TOO_LARGE) {
            // 超限：不把半截数据当完整响应（传输层据此判 invalid_response）。
            return WebdavRawExchange(
                statusCode = status,
                headers = responseHeaders,
                body = ByteArray(0),
                truncated = true,
                failureKind = TransportKind.FORMAT,
                failureMessage = "response_too_large",
            )
        }
        return WebdavRawExchange(
            statusCode = status,
            headers = responseHeaders,
            body = result.data ?: ByteArray(0),
        )
    }

    private fun failureKindOf(failure: String?, errorClass: String?): TransportKind = when {
        failure == NetLog.FAILURE_TIMEOUT -> TransportKind.TIMEOUT
        errorClass?.contains("SSL") == true || errorClass?.contains("Handshake") == true ->
            TransportKind.HANDSHAKE
        else -> TransportKind.SOCKET
    }

    private companion object {
        /** WebDAV 请求体（PROPFIND 的 XML / PUT 的字节）按二进制转发，不猜文本编码。 */
        val BODY_MEDIA_TYPE = "application/octet-stream".toMediaType()
    }
}
