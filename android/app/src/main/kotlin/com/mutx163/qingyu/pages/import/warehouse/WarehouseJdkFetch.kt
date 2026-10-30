package com.mutx163.qingyu.pages.import.warehouse

import java.net.HttpURLConnection
import java.net.URL

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
 * ## 参数为什么是这两个
 *
 * - **15 秒**：与 Dart `mainFetchTimeout` 同值。适配仓的 `root_index.yaml` 有 200+ 所学校、
 *   `search_index.yaml` 是全量，弱网要给够；同时它**不是**无限等——半死的镜像正是
 *   「学校页一直转圈」那次事故的根因。
 * - **UA `mikcb-warehouse-client`**：与 Dart 逐字一致，方便在仓的访问日志里认出是 App 在拉。
 *
 * 本类**不进 JVM 单测**（要真网络）；它可测的部分只有「状态码怎么解释」——
 * 那部分在 [WarehouseRepositoryService] 里，测试注入假 [WarehouseFetch] 完成。
 */
class WarehouseJdkFetch(
    private val timeoutMillis: Int = 15_000,
    private val userAgent: String = "mikcb-warehouse-client",
) : WarehouseFetch {

    override fun get(url: String): WarehouseHttpResponse? {
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
        } catch (_: Exception) {
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
        } catch (_: Exception) {
            null
        } finally {
            connection.disconnect()
        }
    }
}
