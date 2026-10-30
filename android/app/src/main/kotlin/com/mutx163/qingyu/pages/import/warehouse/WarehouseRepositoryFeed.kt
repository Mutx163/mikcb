package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.infra.InfraJson
import com.mutx163.qingyu.infra.defaultMirrorUrlPrefix

/**
 * 适配仓的**拉取层**（移植 Dart `WarehouseRepositoryService` 的 `fetchRootIndex` /
 * `fetchAdaptersIndex`，含候选链与 GitCode 信封解码）。
 *
 * ## 分层（为什么拆成接口 + 纯函数）
 *
 * - [WarehouseFetch]：只负责「GET 一个地址，拿回状态码 + 正文」。真实现见 [WarehouseJdkFetch]，
 *   **不得抛异常**（拿不到就回 `null`），这样「超时 / 连不上」与「服务器回了 404」
 *   在调用方是两件可区分的事。
 * - [WarehouseRepositoryService]：候选链 + 解码 + 解析 + 错误分类。**全部可 JVM 直测**，
 *   测试注入假 [WarehouseFetch] 就能钉住「第几个候选才成功」「全失败报哪个码」。
 *
 * ## 没有做的事（诚实边界，别当成已完成）
 *
 * - **没有缓存**：Dart 侧学校清单/适配器清单会落 SharedPreferences 并标缓存时间；
 *   本层每次进页面都真拉一次。加缓存要连「缓存时间上屏」一起做，属下一刀。
 * - **没有按设置选 GitCode/GitHub**：Dart 侧按「更新下载渠道」偏好决定主地址是 GitCode 还是
 *    GitHub（`WarehouseFetchOptions.preferGitCode`）。Kotlin 侧读那条偏好要接设置模型，
 *   本层只把宿主交给调用方，由调用方决定用哪个 [WarehouseRepositorySource]。
 * - **没有脚本下载/执行**：`asset_js_path` 只落到模型里，脚本还没人取、没人跑。
 */

/** 一次 GET 的结果。[body] 在非 200 时可以是空串（错误流不读，避免半死连接又拖一次超时）。 */
data class WarehouseHttpResponse(
    val statusCode: Int,
    val body: String,
)

/** 「发一次 GET」的能力。实现**不得抛异常**：拿不到就回 `null`。 */
interface WarehouseFetch {
    /** 返回 `null` = 传输层失败（DNS / 连接被拒 / 超时 / TLS 失败），与「服务器回了 4xx」必须能区分。 */
    fun get(url: String): WarehouseHttpResponse?
}

/** 拉取结果：要么拿到模型，要么带一个可上屏分类的错误码。 */
sealed class WarehouseLoad<out T> {

    /**
     * @param url 真正成功的那个候选（排查「镜像是不是在偷偷服务」时要用）。
     * @param attempts 试了几个候选才成功（1 = 主地址直接成功）。
     */
    data class Ok<T>(
        val value: T,
        val url: String,
        val attempts: Int,
    ) : WarehouseLoad<T>()

    /** @param code 见 [WarehouseFeedCodes]；[attempts] = 试过几个候选。 */
    data class Failed(
        val code: String,
        val attempts: Int,
    ) : WarehouseLoad<Nothing>()
}

/**
 * 适配仓只读客户端。
 *
 * 线程约定：本类**只做同步 IO**，调用方负责放到 `Dispatchers.IO`（Compose 宿主里就是这么用的）。
 */
class WarehouseRepositoryService(
    private val fetch: WarehouseFetch,
    val source: WarehouseRepositorySource = WarehouseRepositorySource.DEFAULT,
    private val mirrorUrlPrefix: String? = defaultMirrorUrlPrefix,
) {

    /** 学校清单（`index/root_index.yaml`）。 */
    fun loadRootIndex(): WarehouseLoad<WarehouseRootIndex> =
        load("index/root_index.yaml", ::parseWarehouseRootIndex)

    /** 某所学校的适配器清单（`resources/<resourceFolder>/adapters.yaml`）。 */
    fun loadAdaptersIndex(school: WarehouseSchoolEntry): WarehouseLoad<WarehouseAdaptersIndex> =
        load("resources/${school.resourceFolder}/adapters.yaml") { content ->
            parseWarehouseAdaptersIndex(content, school)
        }

    /** 候选链（公开给单测与日志用；真实拉取走 [load]）。 */
    fun candidateUrlsFor(relativePath: String): List<String> =
        WarehouseRepositoryUrls.candidateUrls(source, relativePath, mirrorUrlPrefix)

    private fun <T> load(relativePath: String, parse: (String) -> T): WarehouseLoad<T> {
        val candidates = candidateUrlsFor(relativePath)
        var attempts = 0
        for (candidate in candidates) {
            attempts += 1
            val response = fetch.get(candidate) ?: continue
            if (response.statusCode != 200) {
                continue
            }
            val body = decodeBody(candidate, response.body) ?: continue
            return try {
                WarehouseLoad.Ok(value = parse(body), url = candidate, attempts = attempts)
            } catch (error: WarehouseFeedException) {
                // 解析失败**不再换候选**：换一个镜像拿到的还是同一份内容形状，
                // 真正的病因是文件格式（或键改名），再试只是把 15 秒超时乘上候选数。
                return WarehouseLoad.Failed(code = error.code, attempts = attempts)
            }
        }
        return WarehouseLoad.Failed(code = fetchFailedCode(), attempts = attempts)
    }

    /** GitCode 主地址回的是 base64 信封，其余候选就是文件原文。坏信封当这次候选失败。 */
    private fun decodeBody(url: String, body: String): String? =
        if (isGitCodeContentsUrl(url)) decodeGitCodeContentsBody(body) else body

    private fun fetchFailedCode(): String =
        if (mirrorUrlPrefix.isNullOrEmpty()) {
            WarehouseFeedCodes.FETCH_FAILED_GITHUB
        } else {
            WarehouseFeedCodes.FETCH_FAILED_MIRROR
        }
}

/** GitCode v5 contents API 的主机名；这条地址回的是 base64 信封。 */
fun isGitCodeContentsUrl(url: String): Boolean =
    runCatching { java.net.URL(url).host == "api.gitcode.com" }.getOrDefault(false)

/**
 * GitCode contents 信封 `{"content":"<base64>","encoding":"base64"}` → 内层原文。
 *
 * 非信封 / `content` 缺失 / base64 坏掉一律回 `null`，由调用方换候选。
 * 用严格解码器（`getDecoder`）：MIME 解码器会把坏 base64 解成空串，那等于把「信封坏了」
 * 当成「内容是空」，最后上屏成「适配仓里一所学校都没有」——错得很难查。
 */
fun decodeGitCodeContentsBody(body: String): String? {
    val envelope = InfraJson.tryParse(body) as? Map<*, *> ?: return null
    val content = envelope["content"] as? String
    if (content.isNullOrEmpty()) {
        return null
    }
    return try {
        val bytes = java.util.Base64.getDecoder().decode(content.replace(Regex("\\s"), ""))
        String(bytes, Charsets.UTF_8)
    } catch (_: Exception) {
        null
    }
}
