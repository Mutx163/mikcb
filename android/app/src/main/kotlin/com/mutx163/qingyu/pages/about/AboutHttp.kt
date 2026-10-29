package com.mutx163.qingyu.pages.about

import java.net.HttpURLConnection
import java.net.URL

/**
 * 关于族的「GET 一个 URL，拿回状态码 + 文本」接缝（2026-10-29 F09 新增）。
 *
 * ## 为什么在这里再开一个接缝，而不是复用什么
 *
 * 本仓的既有约定是**每个域自带一条 HTTP 接缝**：`calendar/HolidayHttp`、`weather/WeatherHttp`。
 * 它们形状相同（`get(url) -> body?`），但没有公共父类型——因为每个域要判的东西不一样
 * （假日要 304/ETag，天气只要 body，本域要按状态码区分 304/404/500）。
 * 更关键的是 **L0 模块隔离**：`scripts/test-kotlin-module.ps1 -Module "pages/about"` 只收
 * `pages/about/` + 共享纯逻辑目录（`app / core / infra / sync / weather / …`），
 * 把别的域的接缝当公共接口用，会让本模块的单测无故依赖别人的改动。
 * 所以这里按同一条约定办：**接口 + JDK 实现都由本域持有，零新依赖**（只用 [HttpURLConnection]）。
 *
 * ## 测试口径
 *
 * 真实实现 [JdkAboutHttp] 需要真网络，单测一律注入假件；因此本文件里可被单测钉住的
 * 只有「怎么解释状态码 / 怎么解 GitCode 信封」（[isGitCodeContentsUrl]、
 * [decodeGitCodeContentsBody]），真正的 IO 不进 JVM 单测。
 */
data class AboutHttpResponse(val statusCode: Int, val body: String)

/** 「发一次 GET」的能力。实现**不得抛异常**：拿不到就回 `null`。 */
interface AboutHttp {
    /** 返回 null = 传输层失败（DNS / 连接被拒 / 超时 / TLS 失败），与「服务器回了 404」必须能区分。 */
    fun get(url: String): AboutHttpResponse?
}

/**
 * 真实 HTTP 实现：JDK [HttpURLConnection]，零新依赖。
 *
 * - 显式按 UTF-8 读 body（GitCode 信封里是中文名单，按 latin1 读会变乱码）；
 * - 任何异常（含超时）一律回 `null`，不向上抛——上层拿 `null` 判「网络不可用」，
 *   这样「超时」与「404」在结论上不会被混成一句「加载失败」；
 * - 非 2xx 也回响应（带上状态码、body 留空），304 才判得出来。
 */
class JdkAboutHttp(
    private val timeoutMillis: Int = 10_000,
    private val userAgent: String = "mikcb-about",
) : AboutHttp {

    override fun get(url: String): AboutHttpResponse? {
        val connection = try {
            (URL(url).openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = timeoutMillis
                readTimeout = timeoutMillis
                setRequestProperty("Accept", "application/json, text/yaml, text/plain, */*")
                setRequestProperty("User-Agent", userAgent)
                instanceFollowRedirects = true
            }
        } catch (_: Exception) {
            return null
        }
        return try {
            val code = connection.responseCode
            if (code == 200) {
                val bytes = connection.inputStream.use { it.readBytes() }
                AboutHttpResponse(code, String(bytes, Charsets.UTF_8))
            } else {
                // 错误流不读：我们只需要状态码。读它会把「半死的镜像」拖成又一次等待。
                AboutHttpResponse(code, "")
            }
        } catch (_: Exception) {
            null
        } finally {
            connection.disconnect()
        }
    }
}

/** GitCode v5 contents API（Gitee 兼容）的主机名；这条地址回的是 base64 信封。 */
fun isGitCodeContentsUrl(url: String): Boolean =
    runCatching { URL(url).host == "api.gitcode.com" }.getOrDefault(false)

/**
 * GitCode contents 信封 `{"content":"<base64>","encoding":"base64"}` → 内层原文。
 *
 * 非信封、`content` 缺失、base64 坏掉一律回 `null`，由调用方决定「换候选」还是「报错」；
 * 语义与 Dart `SupportCreatorService._decodeGitCodeContentsPayload` /
 * `WarehouseRepositoryService._decodeCandidateBytes` 对齐（先 base64 解、再 UTF-8 解）。
 */
fun decodeGitCodeContentsBody(body: String): String? {
    val decoded = com.mutx163.qingyu.infra.InfraJson.tryParse(body) as? Map<*, *> ?: return null
    val content = decoded["content"] as? String
    if (content.isNullOrEmpty()) {
        return null
    }
    return try {
        // 严格解码器：GitCode 的 content 里可能带换行（先剥空白），但**不许**静默跳过非法字符——
        // MIME 解码器会把坏 base64 解成空串，那等于把「信封坏了」当成「内容是空」。
        val bytes = java.util.Base64.getDecoder().decode(content.replace(Regex("\\s"), ""))
        String(bytes, Charsets.UTF_8)
    } catch (_: Exception) {
        null
    }
}
