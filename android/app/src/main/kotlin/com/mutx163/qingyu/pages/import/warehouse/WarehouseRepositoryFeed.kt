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
 * ## 已经补上的三个「没有」（2026-11-05：用户实报「联网页极慢 / 有时出不来 / 挂 VPN 直接失败」）
 *
 * 1. **缓存**：索引落到 `WarehouseRepositoryCache`（原文 + 拉取时刻），宿主先渲染缓存
 *    再后台刷新——发布版 Dart 侧没有这一层，是本侧的补强。
 * 2. **按设置选源**：主地址与镜像前缀由 `WarehouseFetchOptions` 决定（GitCode / 蒲公英渠道
 *    走 GitCode，GitHub 渠道走 raw；`original` 来源不拼镜像）。
 * 3. **候选链快速收敛**：每条候选有自己的超时额度、整条链有总预算、同族镜像
 *    首个传输失败即跳过（见 `WarehouseRepositoryUrls.candidatePlan` 与 `load`）。
 *
 * ## 仍然没有做的事（诚实边界，别当成已完成）
 *
 * - **缓存时间不上屏**：宿主知道手上是缓存还是刚拉的，但页面没有「上次更新于…」这类
 *   文案槽位；要加得先过 ARB（六份 + gen-l10n），不在本轮。
 * - **脚本执行不在本层**：脚本正文由 `loadAdapterScript` 取回（含 SHA-256 校验），
 *   注入 WebView 在 `WarehouseWebLoginHost` 里做。
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

    /**
     * 带**本次超时**的 GET。
     *
     * 候选链上不同族的候选额度不同（主地址给足、镜像给短），而 `HttpURLConnection` 的
     * 超时只能建连接时设——所以要能把额度传下来。默认实现忽略它、退回 [get]：
     * 已经写好的一批假实现（单测里的 `FakeFetch`）不用改一行。
     */
    fun get(url: String, timeoutMillis: Int): WarehouseHttpResponse? = get(url)

    /**
     * 上一次 [get] 的传输层失败类别；没失败过或实现不区分时回
     * [WarehouseTransportFailure.UNKNOWN]。
     *
     * 拉取层只用它做两件事：① 判定「主机不可达」时不再逐个试同族镜像（[isHostUnreachable]）；
     * ② 区分「网整体不通」与「某个候选恰好不行」。**默认 UNKNOWN = 不做任何推断**，
     * 于是旧实现行为不变。
     */
    fun lastTransportFailure(): WarehouseTransportFailure = WarehouseTransportFailure.UNKNOWN
}

/**
 * 传输层失败的类别（只由 [WarehouseFetch] 的真实实现填）。
 *
 * 分成这几档是因为它们的**处置不同**：
 * - [DNS] / [CONNECT_REFUSED]：几乎瞬间返回。整条链上多数主机都这样 ⇒ 是网络/代理本身
 *   不通（用户挂 VPN 断网就是这一类），不该再逐个等超时；
 * - [TIMEOUT]：慢失败。主地址这样是常态（GitHub raw 在部分网络被丢包），
 *   必须继续试镜像，绝不能据此判定全网不通；
 * - [TLS] / [IO]：介于两者之间，按「这一类候选不行」处理。
 */
enum class WarehouseTransportFailure {
    /** 实现不区分失败原因（含所有假实现）。 */
    UNKNOWN,

    /** 域名解析不出来（`UnknownHostException`）。 */
    DNS,

    /** 连接或读取超时（`SocketTimeoutException`）。 */
    TIMEOUT,

    /** 连接被拒（`ConnectException`）。 */
    CONNECT_REFUSED,

    /** TLS 握手 / 证书失败。 */
    TLS,

    /** 其它 IO 异常（含 EOF、连接重置）。 */
    IO,
}

/**
 * 这一类失败是否等于「主机根本到不了」（秒失败）。
 *
 * 只有 DNS 解析不出来与连接被拒算：两者都在几十毫秒内返回，且原因是**出口本身**不通
 * （断网 / 代理把 DNS 或连接拒了），不是「某一台服务不肯干活」——所以四台镜像可以据此判定同族全灭。
 *
 * 超时、TLS、泛 IO **不算**：它们是「这一台不行」，换一台镜像可能就通。
 */
fun WarehouseTransportFailure.isHostUnreachable(): Boolean =
    this == WarehouseTransportFailure.DNS || this == WarehouseTransportFailure.CONNECT_REFUSED

/** 拉取结果：要么拿到模型，要么带一个可上屏分类的错误码。 */
sealed class WarehouseLoad<out T> {

    /**
     * @param url 真正成功的那个候选（排查「镜像是不是在偷偷服务」时要用）。
     * @param attempts 试了几个候选才成功（1 = 主地址直接成功）。
     * @param raw 成功候选的**原文**（GitCode 信封已解出），给落盘缓存回写用；
     *   `null` = 没带（脚本正文那类不需要缓存）。
     */
    data class Ok<T>(
        val value: T,
        val url: String,
        val attempts: Int,
        val raw: String? = null,
    ) : WarehouseLoad<T>()

    /**
     * @param code 见 [WarehouseFeedCodes]；[attempts] = 试过几个候选。
     * @param transport 这条链上**最后一次能分清原因**的传输层失败（全是
     *   [WarehouseTransportFailure.UNKNOWN] 时就是 UNKNOWN）。渲染层要区分
     *   「网不通 / 超时 / 仓库全挂」靠它，不必再去问 [WarehouseFetch]——
     *   那个答案只在「刚失败的那一瞬」有效（见 `WarehouseJdkFetch.lastTransportFailure`）。
     */
    data class Failed(
        val code: String,
        val attempts: Int,
        val transport: WarehouseTransportFailure = WarehouseTransportFailure.UNKNOWN,
    ) : WarehouseLoad<Nothing>()
}

/**
 * 适配仓只读客户端。
 *
 * 线程约定：本类**只做同步 IO**，调用方负责放到 `Dispatchers.IO`（Compose 宿主里就是这么用的）。
 *
 * ## 候选链的三条收敛规则（2026-11-05：用户实报「加载极慢 / 挂 VPN 直接失败」）
 *
 * 1. **每族不同额度**：主地址 15s、GitHub raw 回退 8s、镜像 6s。镜像只是代理，
 *    健康的会在几秒内回；给它和主站同样的 15s，等于把最坏情况乘上候选数。
 * 2. **整条链总预算**（[DEFAULT_TOTAL_BUDGET_MILLIS]）：每开始一个候选前先看还剩多少，
 *    不够 [MIN_ATTEMPT_BUDGET_MILLIS] 就收手。没有这一条时最坏是「6 个候选 × 15s
 *    = 90 秒白转圈」——这就是「联网页加载极慢」的主因。
 * 3. **同族镜像在「主机不可达」时跳过**：四个镜像前缀是同一条出口上的代理，DNS 解析不出来或
 *    连接被拒时其余三台几乎必然同样不通，逐个各等一个额度纯属白等。**只认这两类秒失败**
 *    （[WarehouseTransportFailure.isHostUnreachable]）——超时 / TLS / 泛 IO 不拉黑同族，
 *    因为四个镜像其实是四台不同的代理，一台半死不等于四台全死，而最坏的那条路
 *    恰恰是「前三个不行、第四个通」。白等的上限由总预算兜，不拿命中率换收敛。
 *    主地址与 raw 回退**各算一族、不参与**跳过——国内网络里「raw 被丢包、
 *    镜像反而通」是常态，不能因为前者失败就放弃后者。
 *
 * 判断「要不要跳过」只看 [WarehouseFetch.lastTransportFailure]：**UNKNOWN 一律不推断**，
 * 于是分不清原因的假实现（单测里的 `FakeFetch`）行为与改动前一致，现有断言不受影响。
 *
 * @param options 用户偏好快照（GitCode / raw + 镜像前缀）；非空时覆盖 [source] / [mirrorUrlPrefix]。
 * @param budgetMillis 整条链的总预算（测试可调小）。
 * @param clockMillis 取当前时刻（测试注入，便于断言「预算用尽就不再试」）。
 */
class WarehouseRepositoryService(
    private val fetch: WarehouseFetch,
    val source: WarehouseRepositorySource = WarehouseRepositorySource.DEFAULT,
    private val mirrorUrlPrefix: String? = defaultMirrorUrlPrefix,
    private val options: WarehouseFetchOptions? = null,
    private val budgetMillis: Long = DEFAULT_TOTAL_BUDGET_MILLIS,
    private val clockMillis: () -> Long = { System.currentTimeMillis() },
) {

    /** 偏好生效后的真实源（`preferGitCode` 时主地址是 GitCode）。 */
    private val effectiveSource: WarehouseRepositorySource =
        if (options != null) options.source(source) else source

    /** 偏好生效后的镜像前缀（`original` 来源 = null = 不拼镜像）。 */
    private val effectiveMirrorUrlPrefix: String? =
        if (options != null) options.mirrorUrlPrefix else mirrorUrlPrefix

    /** 学校清单（`index/root_index.yaml`）。 */
    fun loadRootIndex(): WarehouseLoad<WarehouseRootIndex> =
        load("index/root_index.yaml", ::parseWarehouseRootIndex)

    /** 某所学校的适配器清单（`resources/<resourceFolder>/adapters.yaml`）。 */
    fun loadAdaptersIndex(school: WarehouseSchoolEntry): WarehouseLoad<WarehouseAdaptersIndex> =
        load("resources/${school.resourceFolder}/adapters.yaml") { content ->
            parseWarehouseAdaptersIndex(content, school)
        }

    /**
     * 适配器脚本正文（`resources/<resourceFolder>/<asset_js_path>`）。
     *
     * 与两个索引走**同一条候选链**（GitCode 信封 / GitHub raw 回退 / 镜像），失败码也共用；
     * 额外两道校验：
     * - 正文空白 ⇒ [WarehouseFeedCodes.SCRIPT_EMPTY]（空脚本注入 WebView 只会白等超时）；
     * - 索引声明了 `sha256` ⇒ 正文必须匹配（[verifyWarehouseScriptSha256]），否则
     *   [WarehouseFeedCodes.SCRIPT_CHECKSUM_FAILED]，**不再换候选**——换了也是同一份内容。
     */
    fun loadAdapterScript(
        school: WarehouseSchoolEntry,
        adapter: WarehouseAdapterEntry,
    ): WarehouseLoad<String> {
        val relativePath = warehouseAdapterScriptPath(school, adapter)
        if (relativePath.isEmpty()) {
            return WarehouseLoad.Failed(code = WarehouseFeedCodes.SCRIPT_PATH_MISSING, attempts = 0)
        }
        return load(relativePath) { content ->
            if (content.isBlank()) {
                throw WarehouseFeedException(WarehouseFeedCodes.SCRIPT_EMPTY, adapter.id)
            }
            if (!verifyWarehouseScriptSha256(content.toByteArray(Charsets.UTF_8), adapter.sha256)) {
                throw WarehouseFeedException(WarehouseFeedCodes.SCRIPT_CHECKSUM_FAILED, adapter.id)
            }
            content
        }
    }

    /** 候选链（公开给单测与日志用；真实拉取走 [load]）。 */
    fun candidateUrlsFor(relativePath: String): List<String> =
        WarehouseRepositoryUrls.candidateUrls(effectiveSource, relativePath, effectiveMirrorUrlPrefix)

    /** 带族的候选链（同上，但每条带 [WarehouseCandidateFamily]，收敛规则要用）。 */
    fun candidatePlanFor(relativePath: String): List<WarehouseCandidate> =
        WarehouseRepositoryUrls.candidatePlan(effectiveSource, relativePath, effectiveMirrorUrlPrefix)

    private fun <T> load(relativePath: String, parse: (String) -> T): WarehouseLoad<T> {
        val plan = candidatePlanFor(relativePath)
        val deadline = clockMillis() + budgetMillis
        val skippedFamilies = mutableSetOf<WarehouseCandidateFamily>()
        val attemptedHosts = linkedSetOf<String>()
        var attempts = 0
        var sawHttpStatus = false
        var sawKnownFailure = false
        // 「最后一次能分清原因」的失败：只用于给渲染层交代原因，不参与收敛判断
        // （收敛只看当次候选的失败，见下面 skippedFamilies）。
        var lastKnownFailure = WarehouseTransportFailure.UNKNOWN

        for (candidate in plan) {
            if (candidate.family in skippedFamilies) {
                continue
            }
            // 预算检查放在**发请求之前**：一个已经开始等超时的连接收不回来，
            // 所以最坏情况是「预算 + 最后一个候选自己的额度」，而不是「候选数 × 额度」。
            val remaining = deadline - clockMillis()
            if (remaining < MIN_ATTEMPT_BUDGET_MILLIS) {
                break
            }
            val timeout = minOf(timeoutFor(candidate.family), remaining).toInt()
            attempts += 1
            candidate.hostOrNull()?.let { attemptedHosts.add(it) }

            val response = fetch.get(candidate.url, timeout)
            if (response == null) {
                val failure = fetch.lastTransportFailure()
                if (failure != WarehouseTransportFailure.UNKNOWN) {
                    sawKnownFailure = true
                    lastKnownFailure = failure
                    // 同族跳过只认「主机不可达」这一类（DNS / 连接被拒，几十毫秒就回）：
                    // 它说明**这台设备的网/代理连不出去**，四台镜像走同一条出口，几乎必然同样不通。
                    //
                    // TIMEOUT / TLS / IO 一律**不拉黑**：四个镜像是四台不同的代理，
                    // 一台超时不等于四台全死，最坏情况正是「前三个恰好半死、第四个通」。
                    // 真白等的上限由总预算兜着（见 [DEFAULT_TOTAL_BUDGET_MILLIS]），
                    // 不靠牺牲命中率来收敛。
                    if (candidate.family == WarehouseCandidateFamily.MIRROR &&
                        failure.isHostUnreachable()
                    ) {
                        skippedFamilies.add(WarehouseCandidateFamily.MIRROR)
                    }
                }
                continue
            }
            sawHttpStatus = true
            if (response.statusCode != 200) {
                continue
            }
            val body = decodeBody(candidate.url, response.body) ?: continue
            return try {
                WarehouseLoad.Ok(
                    value = parse(body),
                    url = candidate.url,
                    attempts = attempts,
                    raw = body,
                )
            } catch (error: WarehouseFeedException) {
                // 解析失败**不再换候选**：换一个镜像拿到的还是同一份内容形状，
                // 真正的病因是文件格式（或键改名），再试只是把超时乘上候选数。
                return WarehouseLoad.Failed(code = error.code, attempts = attempts)
            }
        }
        return WarehouseLoad.Failed(
            code = fetchFailedCode(
                sawHttpStatus = sawHttpStatus,
                sawKnownFailure = sawKnownFailure,
                distinctHosts = attemptedHosts.size,
            ),
            attempts = attempts,
            transport = lastKnownFailure,
        )
    }

    /** 每个候选的额度（毫秒）：主地址给足，回退与镜像逐级收紧。 */
    private fun timeoutFor(family: WarehouseCandidateFamily): Long = when (family) {
        WarehouseCandidateFamily.PRIMARY -> PRIMARY_TIMEOUT_MILLIS
        WarehouseCandidateFamily.GITHUB_RAW_FALLBACK -> FALLBACK_TIMEOUT_MILLIS
        WarehouseCandidateFamily.MIRROR -> MIRROR_TIMEOUT_MILLIS
    }

    /** GitCode 主地址回的是 base64 信封，其余候选就是文件原文。坏信封当这次候选失败。 */
    private fun decodeBody(url: String, body: String): String? =
        if (isGitCodeContentsUrl(url)) decodeGitCodeContentsBody(body) else body

    /**
     * 全链失败时的错误码。
     *
     * [WarehouseFeedCodes.NETWORK_UNREACHABLE] 只在**三类证据同时成立**时给出：
     * ① 一个候选都没拿到 HTTP 状态码（全是传输层失败）；② 至少一次失败能分清原因
     * （[WarehouseTransportFailure.UNKNOWN] 不算，否则分不清原因的假实现会改掉旧码）；
     * ③ 试过 ≥2 台不同主机。三者合起来才足以说明「网整体不通」（挂 VPN 断网就是这一类），
     * 而不是「某一台恰好挂了」。
     */
    private fun fetchFailedCode(
        sawHttpStatus: Boolean,
        sawKnownFailure: Boolean,
        distinctHosts: Int,
    ): String {
        if (!sawHttpStatus && sawKnownFailure && distinctHosts >= 2) {
            return WarehouseFeedCodes.NETWORK_UNREACHABLE
        }
        return if (effectiveMirrorUrlPrefix.isNullOrEmpty()) {
            WarehouseFeedCodes.FETCH_FAILED_GITHUB
        } else {
            WarehouseFeedCodes.FETCH_FAILED_MIRROR
        }
    }
}

/** 候选的主机名（只用于「试过几台不同主机」这条判据；解析不出来就不计）。 */
private fun WarehouseCandidate.hostOrNull(): String? =
    runCatching { java.net.URI(url).host?.lowercase() }.getOrNull()

/**
 * 主地址额度。保留原先的 15s：`root_index.yaml` 有 200+ 所学校、弱网要够——
 * 它只是**一条链里的一条**，真正防白等的是总预算与同族跳过。
 */
private const val PRIMARY_TIMEOUT_MILLIS = 15_000L

/** GitCode 主地址失败后的 GitHub raw 回退额度。 */
private const val FALLBACK_TIMEOUT_MILLIS = 8_000L

/** 镜像额度：代理正常时秒回，6s 不回基本就是半死，没必要等 15s。 */
private const val MIRROR_TIMEOUT_MILLIS = 6_000L

/** 剩余预算低于这个数就不再开新候选（开了也来不及，只是把用户多留几秒）。 */
private const val MIN_ATTEMPT_BUDGET_MILLIS = 800L

/**
 * 整条链的总预算。
 *
 * 取值依据：最坏的真实链路是「主地址超时 15s + raw 超时 8s + 一个镜像超时 6s = 29s」，
 * 32s 让这条路走得完，同时把原来「6 × 15s = 90s」封住。
 */
const val DEFAULT_TOTAL_BUDGET_MILLIS: Long = 32_000L

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
