package com.mutx163.qingyu.platform

import com.mutx163.qingyu.weather.WeatherFetchFailure
import com.mutx163.qingyu.weather.WeatherHttp
import com.mutx163.qingyu.weather.WeatherHttpResult
import java.io.IOException
import java.io.InterruptedIOException
import java.util.concurrent.TimeUnit
import okhttp3.OkHttpClient
import okhttp3.Request

/**
 * 天气 HTTP 的真实实现：**OkHttp**（2026-11-14 用户决定：全软件网络请求都改走 OkHttp）。
 *
 * ## 为什么放在 `platform/` 而不是 `weather/`
 *
 * `weather/` 是 `scripts/test-kotlin-module.ps1` 的**共享面**（纯 Kotlin + JVM classpath），
 * 里面出现 `okhttp3` 会让所有模块的 L0 一起编不过。所以接缝 [WeatherHttp] 留在
 * `weather/`（纯接口），真实现放 `platform/`——L0 不编这里，L1/L2 正常编。
 *
 * ## 超时（2026-11-14 放宽）
 *
 * 原来 connect / read 各 10 秒；Android 17 上首次 TLS 握手慢，10 秒足以误判超时。
 * 现在 connect 20 秒、read 30 秒。**超时一定报 `TIMEOUT`**（带耗时），不再默默返回 null。
 *
 * 用户浏览器实测完整 URL 4.2 秒 / 15667 字节可通（2026-11-14），所以正常路径远小于预算；
 * 放宽只影响「真慢」时的等待，不影响正常取数。
 */
class OkHttpWeatherHttp(
    private val client: OkHttpClient = defaultClient(),
) : WeatherHttp {

    override fun get(url: String): String? = getDetailed(url).body

    override fun getDetailed(url: String): WeatherHttpResult {
        val startedNs = System.nanoTime()
        fun elapsed(): Long = (System.nanoTime() - startedNs) / 1_000_000

        val request = try {
            Request.Builder()
                .url(url)
                .header("Accept", "application/json")
                .header("User-Agent", USER_AGENT)
                .build()
        } catch (error: Exception) {
            return WeatherHttpResult(
                failure = WeatherFetchFailure.NETWORK,
                elapsedMs = elapsed(),
                errorClass = error.javaClass.simpleName,
            )
        }

        return try {
            client.newCall(request).execute().use { response ->
                val bytes = response.body?.bytes()
                val bodyBytes = bytes?.size?.toLong()
                if (!response.isSuccessful) {
                    WeatherHttpResult(
                        httpStatus = response.code,
                        failure = WeatherFetchFailure.HTTP_STATUS,
                        elapsedMs = elapsed(),
                        bodyBytes = bodyBytes,
                        errorClass = HTTP_STATUS_MARKER,
                    )
                } else {
                    WeatherHttpResult(
                        body = bytes?.toString(Charsets.UTF_8).orEmpty(),
                        httpStatus = response.code,
                        elapsedMs = elapsed(),
                        bodyBytes = bodyBytes,
                    )
                }
            }
        } catch (error: InterruptedIOException) {
            // SocketTimeoutException 是 InterruptedIOException 的子类：超时与「连不上」必须分开。
            WeatherHttpResult(
                failure = WeatherFetchFailure.TIMEOUT,
                elapsedMs = elapsed(),
                errorClass = error.javaClass.simpleName,
            )
        } catch (error: IOException) {
            WeatherHttpResult(
                failure = WeatherFetchFailure.NETWORK,
                elapsedMs = elapsed(),
                errorClass = error.javaClass.simpleName,
            )
        } catch (error: Exception) {
            WeatherHttpResult(
                failure = WeatherFetchFailure.NETWORK,
                elapsedMs = elapsed(),
                errorClass = error.javaClass.simpleName,
            )
        }
    }

    companion object {
        /** met.no 条款要求可识别 UA；Open-Meteo 也认这个格式（与旧实现一致）。 */
        const val USER_AGENT: String = "mikcb-weather/1.0 (github.com/Mutx163/mikcb)"

        /** 连接超时（秒）：Android 17 首次 TLS 握手慢，10 秒不够。 */
        const val CONNECT_TIMEOUT_SECONDS: Long = 20L

        /** 读取超时（秒）：完整 16 天响应约 16 KB，正常远小于此值。 */
        const val READ_TIMEOUT_SECONDS: Long = 30L

        /** 非 200 时 `errorClass` 的固定标记（区别于网络异常类名）。 */
        const val HTTP_STATUS_MARKER: String = "HTTP"

        fun defaultClient(): OkHttpClient = OkHttpClient.Builder()
            .connectTimeout(CONNECT_TIMEOUT_SECONDS, TimeUnit.SECONDS)
            .readTimeout(READ_TIMEOUT_SECONDS, TimeUnit.SECONDS)
            .followRedirects(true)
            .build()
    }
}
