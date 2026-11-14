package com.mutx163.qingyu.platform

import com.mutx163.qingyu.pages.about.AboutHttp
import com.mutx163.qingyu.pages.about.AboutHttpResponse

/**
 * `AboutHttp` 的 OkHttp 实现（2026-11-14 全软件网络请求统一入口 [QingyuHttp]）。
 *
 * ## 为什么实现放 `platform/`、接口留在 `pages/about/`
 *
 * `pages/about` 的 L0（`scripts/test-kotlin-module.ps1 -Module pages/about`）只编本域
 * 纯 Kotlin 面，**不编 `platform/`**；而 `platform/` 里的 `import okhttp3` 又不进 L0
 * 共享面（L0 的 classpath 没有 okhttp jar）。所以边界和 `OkHttpHolidayHttp` 完全一致：
 * 接口留域内（可被假件替换、可 JVM 单测），OkHttp 实现在这里（只被 L1/L2 编）。
 *
 * ## 语义与旧 `JdkAboutHttp` 逐条对齐（迁移不许改结论）
 *
 * - **只有传输层失败**（DNS / 连接被拒 / 超时 / TLS）才回 `null`：上层用 `null` 判
 *   「网络不可用」，不能和「服务器回了 404」混成一句「加载失败」；
 * - 非 2xx 也回响应（带状态码、body 留空）——304 / 404 / 429 才判得出来；
 * - 200 按 UTF-8 解 body（GitCode 信封里是中文名单，按 latin1 读会变乱码）；
 * - 超时、UA、Accept 逐请求传，地基只给兜底。
 */
class OkHttpAboutHttp(
    private val timeoutMillis: Long = DEFAULT_TIMEOUT_MS,
    private val userAgent: String = DEFAULT_USER_AGENT,
) : AboutHttp {

    override fun get(url: String): AboutHttpResponse? {
        val result = QingyuHttp.getText(
            QingyuHttp.HttpCallSpec(
                url = url,
                headers = mapOf(
                    "Accept" to ACCEPT,
                    "User-Agent" to userAgent,
                ),
                connectTimeoutMs = timeoutMillis,
                readTimeoutMs = timeoutMillis,
            ),
        )
        // 传输出错时 status 为 null（failure=network/timeout）。这里不许把「超时」当成
        // 「服务器回了个空」——那会让上层把网络问题读成内容问题。
        val status = result.status ?: return null
        return if (status == HTTP_OK) {
            AboutHttpResponse(status, result.body.orEmpty())
        } else {
            // 错误流不读：我们只要状态码。读它会把「半死的镜像」拖成又一次等待。
            AboutHttpResponse(status, "")
        }
    }

    companion object {
        /** 旧 `JdkAboutHttp` 的默认超时（10s 双超时），迁移不改。 */
        const val DEFAULT_TIMEOUT_MS: Long = 10_000L

        /** 与旧实现同值：关于族报的是自己的来源，不和更新检查的 `mikcb-android` 混。 */
        const val DEFAULT_USER_AGENT: String = "mikcb-about"

        private const val ACCEPT = "application/json, text/yaml, text/plain, */*"

        private const val HTTP_OK = 200
    }
}
