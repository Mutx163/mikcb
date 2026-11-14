package com.mutx163.qingyu.platform

import com.mutx163.qingyu.infra.NetLog
import com.mutx163.qingyu.weather.WeatherFetchFailure
import com.mutx163.qingyu.weather.WeatherHttp
import com.mutx163.qingyu.weather.WeatherHttpResult

/**
 * 天气 HTTP 的真实实现：统一入口 [QingyuHttp]（OkHttp 单例、共享连接池）。
 *
 * ## 架构（2026-11-14 定案）
 *
 * - **不在页面层建 OkHttpClient**，也不自建第二个客户端：全软件只有一个 [QingyuHttp.client]；
 * - 天气只依赖 `WeatherHttp` 接口；本类在 `platform/`（L0 不编），构造点在组合根 `ShellWiring`；
 * - 每次请求的 network 日志由 [QingyuHttp] 统一写（`category=network`），本类不重复记。
 *
 * ## 超时（2026-11-14 放宽）
 *
 * 原来 connect/read 各 10 秒；Android 17 上首次 TLS 握手慢，10 秒足以误判超时。
 * 现在 connect 20 秒、read 30 秒（逐请求传给 [QingyuHttp]）。**超时一定报 `TIMEOUT`**。
 * 用户浏览器实测完整 URL 4.2 秒 / 15667 字节可通，正常路径远小于预算。
 */
class OkHttpWeatherHttp(
    private val connectTimeoutMs: Long = CONNECT_TIMEOUT_MS,
    private val readTimeoutMs: Long = READ_TIMEOUT_MS,
) : WeatherHttp {

    override fun get(url: String): String? = getDetailed(url).body

    override fun getDetailed(url: String): WeatherHttpResult {
        val result = QingyuHttp.getText(
            QingyuHttp.HttpCallSpec(
                url = url,
                method = "GET",
                headers = mapOf(
                    "Accept" to "application/json",
                    "User-Agent" to USER_AGENT,
                ),
                connectTimeoutMs = connectTimeoutMs,
                readTimeoutMs = readTimeoutMs,
            ),
        )
        return WeatherHttpResult(
            body = if (result.status == 200) result.body else null,
            httpStatus = result.status,
            failure = failureOf(result.failure),
            elapsedMs = result.elapsedMs,
            bodyBytes = result.bytes,
            errorClass = result.errorClass,
        )
    }

    /** `QingyuHttp` 的失败档 → 天气域分类（只有这几档会出现在传输层）。 */
    private fun failureOf(failure: String?): WeatherFetchFailure? = when (failure) {
        null -> null
        NetLog.FAILURE_TIMEOUT -> WeatherFetchFailure.TIMEOUT
        NetLog.FAILURE_HTTP_STATUS -> WeatherFetchFailure.HTTP_STATUS
        NetLog.FAILURE_CANCELLED -> WeatherFetchFailure.NETWORK
        else -> WeatherFetchFailure.NETWORK
    }

    companion object {
        /** 可识别 UA（Open-Meteo 与 met.no 的条款都要求；与旧实现一致）。 */
        const val USER_AGENT: String = "mikcb-weather/1.0 (github.com/Mutx163/mikcb)"

        /** 连接超时（毫秒）：Android 17 首次 TLS 握手慢，10 秒不够。 */
        const val CONNECT_TIMEOUT_MS: Long = 20_000L

        /** 读取超时（毫秒）：完整 16 天响应约 16 KB，正常远小于此值。 */
        const val READ_TIMEOUT_MS: Long = 30_000L
    }
}
