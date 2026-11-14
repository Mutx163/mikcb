package com.mutx163.qingyu.platform

import com.mutx163.qingyu.infra.NetLog
import com.mutx163.qingyu.pages.import.warehouse.WarehouseFetch
import com.mutx163.qingyu.pages.import.warehouse.WarehouseHttpResponse
import com.mutx163.qingyu.pages.import.warehouse.WarehouseTransportFailure
import com.mutx163.qingyu.pages.import.warehouse.isGitCodeContentsUrl

/**
 * [WarehouseFetch] 的真实现：统一入口 [QingyuHttp]（OkHttp）。
 *
 * ## 为什么放在 `platform/`
 *
 * `pages/import/warehouse` 会在 **L0 模块单测**里被整目录编译，而 L0 的 classpath 只有
 * junit / hamcrest / kotlin-stdlib，没有 okhttp jar。接缝 [WarehouseFetch] 留在原处
 * （纯接口，测试注入假件）；真实现放这里，L1/L2 才编。
 *
 * ## 迁移前后行为必须逐条对齐（2026-11-14 换 OkHttp）
 *
 * - **非 200 仍是「服务器回了状态码」，不是传输失败**（`WarehouseRepositoryFeed` 靠状态码
 *   在候选链之间切换）；只有真拿不到响应才返回 null。
 * - **失败分类口径不变**：[WarehouseTransportFailure] 的 DNS / TIMEOUT / CONNECT_REFUSED /
 *   TLS / IO 五档，由 `QingyuHttp.HttpResult.errorClass` 与 `failure` 还原
 *   （旧实现靠顺着异常 cause 链找；OkHttp 直接给真实异常类名，仍保留同类归并）。
 * - **超时按候选传**：`get(url, timeoutMillis)` 用本次额度，不放大。
 * - **登录重定向**：`QingyuHttp` 统一 `followRedirects(true)`，与旧实现的
 *   `instanceFollowRedirects = true` 同口径。
 * - `Accept`：GitCode contents 接口要 JSON，其余按纯文本；`User-Agent` 用本域自己的。
 */
class OkHttpWarehouseFetch(
    private val timeoutMillis: Int = DEFAULT_TIMEOUT_MILLIS,
    private val userAgent: String = DEFAULT_USER_AGENT,
) : WarehouseFetch {

    /**
     * 上一次 [get] 的失败类别（**线程隔离**：同一实例可能被两个页面同时使用，
     * 共享一个字段会让 A 的 DNS 失败被 B 读成自己的原因）。
     */
    private val lastFailure = ThreadLocal<WarehouseTransportFailure?>()

    override fun lastTransportFailure(): WarehouseTransportFailure =
        lastFailure.get() ?: WarehouseTransportFailure.UNKNOWN

    override fun get(url: String): WarehouseHttpResponse? = get(url, timeoutMillis)

    override fun get(url: String, timeoutMillis: Int): WarehouseHttpResponse? {
        lastFailure.set(null)
        val timeout = timeoutMillis.toLong().coerceAtLeast(1L)
        val result = QingyuHttp.getText(
            QingyuHttp.HttpCallSpec(
                url = url,
                method = "GET",
                headers = mapOf(
                    "Accept" to if (isGitCodeContentsUrl(url)) "application/json" else "text/plain, */*",
                    "User-Agent" to userAgent,
                ),
                connectTimeoutMs = timeout,
                readTimeoutMs = timeout,
            ),
        )
        val status = result.status
        if (status == null) {
            lastFailure.set(classify(result.failure, result.errorClass))
            return null
        }
        return if (status == 200) {
            WarehouseHttpResponse(status, result.body.orEmpty())
        } else {
            // 错误流不读：只要状态码（旧实现同口径，读它会把半死镜像拖成又一次等待）。
            WarehouseHttpResponse(status, "")
        }
    }

    /**
     * [QingyuHttp] 的失败档 → [WarehouseTransportFailure]。
     *
     * 取消（`cancelled`）不在本域语义里，归 `IO`：调用方只在「拿不到数据」时看它。
     */
    private fun classify(failure: String?, errorClass: String?): WarehouseTransportFailure = when {
        failure == NetLog.FAILURE_TIMEOUT -> WarehouseTransportFailure.TIMEOUT
        errorClass?.contains("UnknownHost") == true -> WarehouseTransportFailure.DNS
        errorClass?.contains("ConnectException") == true -> WarehouseTransportFailure.CONNECT_REFUSED
        errorClass?.contains("SSL") == true || errorClass?.contains("Handshake") == true ->
            WarehouseTransportFailure.TLS
        failure == null -> WarehouseTransportFailure.UNKNOWN
        else -> WarehouseTransportFailure.IO
    }

    companion object {
        /** 默认额度（与旧实现 `WarehouseJdkFetch.DEFAULT_TIMEOUT_MILLIS` 同值）。 */
        const val DEFAULT_TIMEOUT_MILLIS: Int = 15_000

        /** 本域 UA（适配仓/镜像只认这个，别用天气或更新检查的）。 */
        const val DEFAULT_USER_AGENT: String = "mikcb-warehouse-client"
    }
}
