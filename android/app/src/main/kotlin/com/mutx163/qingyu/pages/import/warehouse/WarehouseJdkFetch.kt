package com.mutx163.qingyu.pages.import.warehouse

import java.io.IOException
import java.net.ConnectException
import java.net.HttpURLConnection
import java.net.SocketTimeoutException
import java.net.URL
import java.net.UnknownHostException
import javax.net.ssl.SSLException

/**
 * [WarehouseFetch] 的真实现：JDK [HttpURLConnection]，**零新依赖**。
 *
 * ## 为什么本仓每个域各带一条 HTTP 接缝
 *
 * 既有约定见 `pages/about/AboutHttp.kt` 的 KDoc：`calendar/HolidayHttp`、`weather/WeatherHttp`
 * 形状相同但没有公共父类型——因为每个域要判断的东西不同（假日要 ETag/304、天气只要 body、
 * 本域要按状态码在候选链之间切换）。更关键的是 **L0 模块隔离**：
 * `scripts/test-kotlin-module.ps1 -Module "pages/import/warehouse"` 只收本模块 + 共享纯目录，
 * 拿别的域的接缝当公共接口会让本模块单测无故依赖别人的改动。
 *
 * ## 超时为什么现在**按候选**给
 *
 * 2026-11-05 之前这里是写死的 15 秒（与 Dart `mainFetchTimeout` 同值）。但候选链上
 * 主地址、GitHub raw 回退、四个镜像前缀的**期望延迟完全不同**：镜像是代理，健康的
 * 几秒内就回；给它和主站一样的 15s，等于让「镜像半死」把用户多留十几秒。
 * 现在额度由拉取层按族给（见 [WarehouseRepositoryService]），这里是执行方。
 * 无参 [get] 仍用构造时那个 15s，与旧调用点逐字一致。
 *
 * ## 为什么要把失败**分类**（挂 VPN 断网那一类）
 *
 * 「连接失败」在 `HttpURLConnection` 里全是一个 `IOException` 家族，但对用户意义完全不同：
 * DNS 解析不出来 / 连接被拒（几十毫秒就返回）说明**这台设备的网/代理本身不通**；
 * 超时（要等满额度）说明**这一台服务不行、别的不一定**。拉取层靠这个区别决定
 * 「立刻收手并报网不通」还是「继续试镜像」，所以这里必须把 `UnknownHostException`、
 * `SocketTimeoutException`、`ConnectException`、`SSLException` 分开报出去，
 * 而不是像以前那样一律 `null`。
 *
 * 本类**不进 JVM 单测**（要真网络）；可测的部分是「状态码怎么解释」「候选怎么收敛」，
 * 那些在 [WarehouseRepositoryService] 里，测试注入假 [WarehouseFetch] 完成。
 */
class WarehouseJdkFetch(
    private val timeoutMillis: Int = DEFAULT_TIMEOUT_MILLIS,
    private val userAgent: String = "mikcb-warehouse-client",
) : WarehouseFetch {

    /**
     * 上一次 [get] 的失败类别。
     *
     * **线程隔离**：同一个实例可能被两个页面同时使用（列表页与登录页各一个 scope），
     * 共享一个字段会让 A 的 DNS 失败被 B 读成自己的原因。调用约定是「拿到 `null`
     * 之后立刻问」，同一线程上两步之间不会插进别的请求。
     */
    private val lastFailure = ThreadLocal<WarehouseTransportFailure?>()

    override fun lastTransportFailure(): WarehouseTransportFailure =
        lastFailure.get() ?: WarehouseTransportFailure.UNKNOWN

    override fun get(url: String): WarehouseHttpResponse? = get(url, timeoutMillis)

    override fun get(url: String, timeoutMillis: Int): WarehouseHttpResponse? {
        lastFailure.set(null)
        val connection = try {
            (URL(url).openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = timeoutMillis
                readTimeout = timeoutMillis
                setRequestProperty(
                    "Accept",
                    if (isGitCodeContentsUrl(url)) "application/json" else "text/plain, */*",
                )
                setRequestProperty("User-Agent", userAgent)
                instanceFollowRedirects = true
            }
        } catch (error: Exception) {
            // 建连接就炸（坏 URL / 被安全策略拦下）也算传输层失败，但要能分类。
            lastFailure.set(classify(error))
            return null
        }
        return try {
            val code = connection.responseCode
            if (code == 200) {
                // 显式按 UTF-8 读：仓里全是中文学校名，按平台默认编码读会变乱码。
                val bytes = connection.inputStream.use { it.readBytes() }
                WarehouseHttpResponse(code, String(bytes, Charsets.UTF_8))
            } else {
                // 错误流不读：只要状态码。读它会把半死镜像拖成又一次等待。
                WarehouseHttpResponse(code, "")
            }
        } catch (error: Exception) {
            lastFailure.set(classify(error))
            null
        } finally {
            connection.disconnect()
        }
    }

    /**
     * 把异常归到 [WarehouseTransportFailure] 的一档。
     *
     * 会**顺着 cause 链往下找**：`HttpURLConnection` 常把真实原因包一层
     * （`IOException: Unable to resolve host …` 的内层才是 `UnknownHostException`），
     * 只看最外层会把 DNS 失败误判成泛 IO，于是 VPN 断网那种「秒失败」被当成「慢超时」
     * 继续把候选链走完——正是用户看到的「白等」。
     */
    private fun classify(error: Throwable): WarehouseTransportFailure {
        var current: Throwable? = error
        var depth = 0
        while (current != null && depth < MAX_CAUSE_DEPTH) {
            when (current) {
                is UnknownHostException -> return WarehouseTransportFailure.DNS
                is SocketTimeoutException -> return WarehouseTransportFailure.TIMEOUT
                is ConnectException -> return WarehouseTransportFailure.CONNECT_REFUSED
                is SSLException -> return WarehouseTransportFailure.TLS
            }
            current = current.cause
            depth += 1
        }
        return if (error is IOException) WarehouseTransportFailure.IO else WarehouseTransportFailure.UNKNOWN
    }

    companion object {
        /** 默认额度（与 Dart `mainFetchTimeout` 同值）；单条候选可用重载覆写。 */
        const val DEFAULT_TIMEOUT_MILLIS: Int = 15_000

        /** cause 链最多看几层（防自引用异常把这里转成死循环）。 */
        private const val MAX_CAUSE_DEPTH = 8
    }
}
