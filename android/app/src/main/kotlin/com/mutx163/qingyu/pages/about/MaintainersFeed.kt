package com.mutx163.qingyu.pages.about

import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.infra.MaintainerGroup
import com.mutx163.qingyu.infra.WarehouseRepositoryHost
import com.mutx163.qingyu.infra.WarehouseRepositorySource
import com.mutx163.qingyu.infra.buildMaintainerLabel
import com.mutx163.qingyu.infra.buildMirrorCandidateUrls
import com.mutx163.qingyu.infra.decodeMaintainersCache
import com.mutx163.qingyu.infra.defaultMirrorUrlPrefix
import com.mutx163.qingyu.infra.defaultQingyuWarehouseSource
import com.mutx163.qingyu.infra.encodeMaintainersCache
import com.mutx163.qingyu.infra.groupMaintainerLabels
import com.mutx163.qingyu.infra.maintainersCacheKey
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.concurrent.Callable
import java.util.concurrent.Executors

/**
 * 「代码贡献者」页 · 教务导入适配者名单的取数层（2026-10-29 F09 新增）。
 *
 * 移植 `lib/screens/about_screen.dart` 的 `_ContributorsScreenState._fetchMaintainersFromWarehouse`：
 *
 * 1. 读 `index/root_index.yaml`（顶层 `schools:`）拿学校清单；
 * 2. 对每所学校读 `resources/<resource_folder>/adapters.yaml`（顶层 `adapters:`），
 *    收集每个适配项的 `maintainer` 字段，拼成 "`学校名 · 适配器名`"；
 * 3. 按 maintainer 归组 + 组内标签排序 + 组按名排序（[groupMaintainerLabels] 已在
 *    `infra/WarehouseInfra.kt` 里实现并被单测钉住，这里直接复用，不再写第二份）。
 *
 * ## 为什么自己写 YAML 解析
 *
 * 主源码树里**没有**任何 YAML 解析器（`pages/import/warehouse/WarehouseRepositoryModels.kt`
 * 只有数据类，F08 才移植完整仓储服务）。本文件只需要「`key:` 下面一层 `- k: v` 列表」这一小片
 * YAML 子集，因此自带 [yamlListMaps]：**严格照抄** Dart `_parseYamlListMaps` 的口径
 * （tab 当两个空格、`#` 注释、缩进 2 起项 / ≥4 续字段、单双引号去壳、`\n\r\t` 反转义），
 * 并有独立单测；等 F08 的完整解析器落地后，这里应改为复用那份（届时删掉本文件里的解析器）。
 *
 * ## 与 Dart 的三处有意差异
 *
 * 1. **并发**：Dart 用 `Future.wait` 把 222 所学校**同时**打出去；这里用固定大小线程池
 *    （默认 [DEFAULT_PARALLELISM]）——一次性 222 个连接在弱网下只会让系统把大家一起拖慢。
 * 2. **全失败必须报错**：Dart 在「每所学校都抛错」时得到空表，页面显示「当前还没有读取到
 *    适配者信息」，等于把网络故障说成「真的没有适配者」。这里改成
 *    [MaintainersFetchOutcome.Failure]（[REASON_ALL_SCHOOLS_FAILED]），要求上层显示错误并可重试。
 * 3. **缓存时间**：Dart 只存名单、不存时间；F09 的验收要求「不许把上次缓存当成新数据（要标缓存
 *    时间）」，因此额外落一个 [maintainersCacheTimeKey] 时间戳，展示时由
 *    [formatMaintainersCacheTime] 格式化。
 *
 * ## 镜像口径：为什么和鸣谢名单不一样（2026-11-11 R-6）
 *
 * 鸣谢名单（`SupportDonorsFeed`）的候选池只有两条官方直连，KDoc 明写「镜像永不进候选池
 * （名单内容可被镜像整份替换）」；本文件却把镜像放进链里。两条兄弟名单口径不同，理由如下：
 *
 * 1. **两个名单不同仓**：`docs/donors.json` 在 mikcb 主仓（作者手写、随发版走）；
 *    本页读的 `index/root_index.yaml` 与 `resources/<校>/adapters.yaml` 在 qingyu_warehouse 仓。
 * 2. **镜像在仓库域本来就是主链**：仓库域抓这两份索引本来就走镜像族（镜像能决定
 *    「这所学校有没有适配器、装哪个脚本」——比一行维护者名字大得多的信任面）。本页只是把
 *    同一份 `adapters.yaml` 里的 `maintainer` 字段搬到屏幕上：镜像对「谁维护哪所学校」
 *    早已有完全控制权，把它挡在名单链外多挡不住任何风险，只会让国内弱网下整页名单读不到。
 * 3. **donors 那份更保守是另一件事**：`donors.json` 承载「谁捐了多少钱、写了什么留言」这类
 *    社会证明，伪造的杀伤力最高，且它没有「镜像本来就该读这个仓」的先例 ⇒ 双官方直连。
 *
 * 结论：本文件**保留镜像候选**（与仓库索引同链），这条差异是有意的、不是漏改。
 * 若哪天仓库域收紧镜像（例如只认官方直连），本文件必须同批跟着改，不许单边收。
 */
sealed interface MaintainersFetchOutcome {
    data class Success(val groups: List<MaintainerGroup>) : MaintainersFetchOutcome

    data class Failure(val reason: String) : MaintainersFetchOutcome
}

/** 学校清单一行（只留本页用得到的三列）。 */
data class WarehouseSchoolRow(
    val id: String,
    val name: String,
    val resourceFolder: String,
)

/** 适配器清单一行（只留本页用得到的列）。 */
data class WarehouseAdapterRow(
    val adapterId: String,
    val adapterName: String,
    val maintainer: String,
)

/**
 * 解析 `index/root_index.yaml`（顶层 `schools:`）。
 *
 * 过滤口径同 Dart：`id` / `name` / `resource_folder` 任一为空即丢弃该条。
 */
fun parseWarehouseRootIndexYaml(content: String): List<WarehouseSchoolRow> =
    yamlListMaps(content, "schools").mapNotNull { item ->
        val id = item["id"].orEmpty()
        val name = item["name"].orEmpty()
        val folder = item["resource_folder"].orEmpty()
        if (id.isEmpty() || name.isEmpty() || folder.isEmpty()) {
            null
        } else {
            WarehouseSchoolRow(id = id, name = name, resourceFolder = folder)
        }
    }

/**
 * 解析 `resources/<dir>/adapters.yaml`（顶层 `adapters:`）。
 *
 * 过滤口径同 Dart `fetchAdaptersIndex`：`adapter_id` 与 `asset_js_path` 都必须非空。
 */
fun parseWarehouseAdaptersYaml(content: String): List<WarehouseAdapterRow> =
    yamlListMaps(content, "adapters").mapNotNull { item ->
        val id = item["adapter_id"].orEmpty()
        val assetPath = item["asset_js_path"].orEmpty()
        if (id.isEmpty() || assetPath.isEmpty()) {
            null
        } else {
            WarehouseAdapterRow(
                adapterId = id,
                adapterName = item["adapter_name"].orEmpty(),
                maintainer = item["maintainer"].orEmpty(),
            )
        }
    }

/**
 * Dart `_parseYamlListMaps` 的 Kotlin 版（逐条对齐，含怪癖）。
 *
 * 只认一种形态：顶层 `key:` 之下缩进 2 的 `- ` 起项、缩进 ≥4 的 `k: v` 续行；
 * 回到缩进 0 的另一个 `xxx:` 即视为本段结束。不支持的 YAML 特性（块标量、锚点、嵌套列表）
 * 一律按「没读到这个字段」处理——这恰好是这几份索引文件的真实形态。
 */
internal fun yamlListMaps(content: String, topLevelKey: String): List<Map<String, String>> {
    val items = arrayListOf<Map<String, String>>()
    var inTargetSection = false
    var current: MutableMap<String, String>? = null

    for (rawLine in content.split(Regex("\r?\n"))) {
        val normalizedLine = rawLine.replace("\t", "  ")
        val trimmed = normalizedLine.trim()
        if (trimmed.isEmpty() || trimmed.startsWith("#")) {
            continue
        }

        if (!inTargetSection) {
            if (trimmed == "$topLevelKey:") {
                inTargetSection = true
            }
            continue
        }

        val indent = normalizedLine.length - normalizedLine.trimStart().length
        if (indent == 0 && trimmed.endsWith(":")) {
            break
        }

        if (indent == 2 && trimmed.startsWith("- ")) {
            val previous = current
            if (previous != null && previous.isNotEmpty()) {
                items.add(previous)
            }
            current = linkedMapOf()
            val pair = trimmed.substring(2).trim()
            if (pair.isNotEmpty()) {
                parseYamlPair(pair)?.let { (key, value) -> current[key] = value }
            }
            continue
        }

        val active = current
        if (indent >= 4 && active != null) {
            parseYamlPair(trimmed)?.let { (key, value) -> active[key] = value }
        }
    }

    val tail = current
    if (tail != null && tail.isNotEmpty()) {
        items.add(tail)
    }
    return items
}

/** `k: v` 一行；没有 `: ` 分隔或键为空则回 null（Dart `_parseYamlPair`）。 */
private fun parseYamlPair(line: String): Pair<String, String>? {
    val separatorIndex = line.indexOf(": ")
    if (separatorIndex <= 0) {
        return null
    }
    val key = line.substring(0, separatorIndex).trim()
    var value = stripInlineComment(line.substring(separatorIndex + 2).trim())
    if (value.length >= 2 &&
        ((value.startsWith("\"") && value.endsWith("\"")) ||
            (value.startsWith("'") && value.endsWith("'")))
    ) {
        value = value.substring(1, value.length - 1)
    }
    return key to decodeEscapedYamlText(value.trim())
}

/** 去掉引号外的行内注释并右裁剪（Dart `_stripInlineComment`）。 */
private fun stripInlineComment(value: String): String {
    if (value.isEmpty() || !value.contains('#')) {
        return value
    }
    val buffer = StringBuilder()
    var inSingleQuote = false
    var inDoubleQuote = false
    for (char in value) {
        if (char == '\'' && !inDoubleQuote) {
            inSingleQuote = !inSingleQuote
        } else if (char == '"' && !inSingleQuote) {
            inDoubleQuote = !inDoubleQuote
        }
        if (char == '#' && !inSingleQuote && !inDoubleQuote) {
            break
        }
        buffer.append(char)
    }
    return buffer.toString().trimEnd()
}

/** YAML 双引号文本里的 `\n` / `\r` / `\t` 反转义（Dart `_decodeEscapedYamlText`）。 */
private fun decodeEscapedYamlText(value: String): String =
    value.replace("\\n", "\n").replace("\\r", "\r").replace("\\t", "\t")

/**
 * 教务适配者名单取数（[fetch] 才发请求）。
 *
 * [parallelism] 是「同时在飞的学校请求数」，不是线程数上限的语义承诺；
 * 单测里给 1 可以让执行顺序完全确定。
 */
class WarehouseMaintainersFeed(
    private val http: AboutHttp,
    private val source: WarehouseRepositorySource = defaultQingyuWarehouseSource,
    private val parallelism: Int = DEFAULT_PARALLELISM,
    /**
     * 镜像前缀（重建候选链用）。默认与仓库索引同值；传 `null` = 只走直连。
     *
     * 2026-11-10 联网审计：此前 `uri()` 只构造**一个**地址——`defaultQingyuWarehouseSource`
     * 是 GitHub 宿主，国内网络里 `raw.githubusercontent.com` 被丢包时整份名单直接失败；
     * 现在与仓库索引同链（主地址 → GitCode 宿主时的 GitHub raw 回退 → 镜像）。
     */
    private val mirrorUrlPrefix: String? = defaultMirrorUrlPrefix,
) {

    fun fetch(): MaintainersFetchOutcome {
        val rootFetch = fetchText(ROOT_INDEX_PATH, attemptBudget = MAX_ROOT_INDEX_ATTEMPTS)
        val rootText = rootFetch.text ?: return MaintainersFetchOutcome.Failure(
            when {
                rootFetch.sawDecodeFailure -> REASON_ROOT_INDEX_DECODE_FAILED
                rootFetch.lastStatus != null -> "http_${rootFetch.lastStatus}"
                else -> REASON_NETWORK_UNAVAILABLE
            },
        )
        val schools = parseWarehouseRootIndexYaml(rootText)
        if (schools.isEmpty()) {
            return MaintainersFetchOutcome.Failure(REASON_NO_SCHOOLS)
        }

        val pool = Executors.newFixedThreadPool(parallelism.coerceIn(1, MAX_PARALLELISM))
        val results = try {
            pool.invokeAll(
                schools.map { school -> Callable { fetchSchool(school) } },
            ).map { future -> runCatching { future.get() }.getOrNull() ?: SchoolFetch(emptyList(), failed = true) }
        } finally {
            pool.shutdownNow()
        }

        val entries = results.flatMap { it.entries }
        val failedSchools = results.count { it.failed }
        val groups = groupMaintainerLabels(entries)
        if (groups.isEmpty() && failedSchools > 0) {
            // 全灭 ≠ 没有适配者：宁可报错让用户重试，也不许显示「当前还没有读取到适配者信息」。
            return MaintainersFetchOutcome.Failure(REASON_ALL_SCHOOLS_FAILED)
        }
        return MaintainersFetchOutcome.Success(groups)
    }

    private fun fetchSchool(school: WarehouseSchoolRow): SchoolFetch {
        val text = fetchText("resources/${school.resourceFolder}/adapters.yaml").text
            ?: return SchoolFetch(emptyList(), failed = true)
        val adapters = parseWarehouseAdaptersYaml(text)
        if (adapters.isEmpty()) {
            // Dart `fetchAdaptersIndex` 对空清单抛 warehouse_no_adapters，调用方按「这所学校失败」处理。
            return SchoolFetch(emptyList(), failed = true)
        }
        return SchoolFetch(
            entries = adapters.map { adapter ->
                adapter.maintainer.trim() to buildMaintainerLabel(school.name, adapter.adapterName)
            },
            failed = false,
        )
    }

    /**
     * 按候选链逐个拉取，第一个 200 且能解码的胜出（与仓库索引同一条链、同一套顺序）。
     *
     * 顺序：主地址（GitHub 宿主 = GitHub raw / GitCode 宿主 = GitCode contents API）
     * → GitCode 宿主时的 GitHub raw 回退 → 镜像前缀候选。
     *
     * 为什么在这里重建而不是直接调 `WarehouseRepositoryUrls.candidateUrls`：那个对象住在
     * `pages/import/warehouse`，仓库的「域边界守卫」禁止本域 import 另一页面域的类型
     *（会把本域 L0 的独立编译打破）。顺序语义由 `MaintainerCandidateChainTest` 钉住，
     * 仓库侧由 `WarehouseRepositoryFeedTest` 钉住，两边同一条链。
     */
    private fun candidateUrls(relativePath: String): List<String> {
        val primary = source.buildFileUri(relativePath).toString()
        val githubRaw = source.buildRawFileUri(relativePath).toString()
        val candidates = linkedSetOf(primary)
        if (source.host == WarehouseRepositoryHost.GITCODE) {
            candidates.add(githubRaw)
        }
        if (!mirrorUrlPrefix.isNullOrEmpty()) {
            candidates.addAll(buildMirrorCandidateUrls(githubRaw, mirrorUrlPrefix))
        }
        return candidates.toList()
    }

    private data class CandidateTextFetch(
        val text: String?,
        val lastStatus: Int?,
        val sawDecodeFailure: Boolean = false,
    )

    /**
     * 取一份索引/清单文本：按 [candidateUrls] 顺序试，但**最多试 [attemptBudget] 跳**。
     *
     * 2026-11-11 R-7（评审四建议级）：候选链最长可到 6 跳（主地址 + GitHub raw 回退 +
     * 4 个镜像外壳，去重后仍有 5~6 条），而 [JdkAboutHttp] 每条候选最坏要吃满 10s 超时。
     * 直连丢包时单校最坏 = 5~6 次超时 ≈ 60s，而 222 所学校只能 [parallelism] 路并行 ⇒
     * 一次「读取代码贡献者」能被拖成十几分钟，用户只看到转圈。所以给每次取数一个**跳数总预算**：
     * 根索引 [MAX_ROOT_INDEX_ATTEMPTS] 跳（它失败 = 整页失败，值得多给一跳），
     * 单校 [MAX_SCHOOL_ADAPTER_ATTEMPTS] 跳（失败只少一所学校）。
     *
     * 预算只在失败分支花：主地址 200 时仍然**只发一次**请求，顺序与前缀完全不变。
     * 剩余风险写在 [MAX_SCHOOL_ADAPTER_ATTEMPTS] 上（最坏仍是 2×10s）。
     */
    private fun fetchText(
        relativePath: String,
        attemptBudget: Int = MAX_SCHOOL_ADAPTER_ATTEMPTS,
    ): CandidateTextFetch {
        var lastStatus: Int? = null
        var sawDecodeFailure = false
        for (url in candidateUrls(relativePath).take(attemptBudget.coerceAtLeast(1))) {
            val response = runCatching { http.get(url) }.getOrNull() ?: continue
            if (response.statusCode != 200) {
                lastStatus = response.statusCode
                continue
            }
            val text = decodeBody(url, response)
            if (text == null) {
                sawDecodeFailure = true
                continue
            }
            return CandidateTextFetch(text = text, lastStatus = lastStatus)
        }
        return CandidateTextFetch(text = null, lastStatus = lastStatus, sawDecodeFailure = sawDecodeFailure)
    }

    private fun decodeBody(url: String, response: AboutHttpResponse): String? =
        if (isGitCodeContentsUrl(url)) decodeGitCodeContentsBody(response.body) else response.body

    private data class SchoolFetch(val entries: List<Pair<String, String>>, val failed: Boolean)

    companion object {
        const val ROOT_INDEX_PATH = "index/root_index.yaml"
        const val DEFAULT_PARALLELISM = 6
        const val MAX_PARALLELISM = 8

        /**
         * 根索引一次取数的**请求跳数预算**（2026-11-11 R-7）：主地址 + 两条兜底。
         *
         * 根索引失败 = 整页失败（用户只能重试），所以比单校多给一跳；但它只有一次，
         * 最坏 3×10s = 30s，仍有上界。
         */
        const val MAX_ROOT_INDEX_ATTEMPTS = 3

        /**
         * 单校 `adapters.yaml` 一次取数的**请求跳数预算**（2026-11-11 R-7）：主地址 + 一条兜底。
         *
         * 222 所学校 × 6 跳 × 10s 超时是「读代码贡献者读成十分钟」的根因；压到 2 跳后
         * 主地址 200 时零变化（只发 1 次），丢包时单校最坏 2×10s。
         * 最后一条候选（第 3 个镜像之后的前缀）宁可不再试——那时用户已经在等半分钟了。
         */
        const val MAX_SCHOOL_ADAPTER_ATTEMPTS = 2

        const val REASON_NETWORK_UNAVAILABLE = "network_unreachable"
        const val REASON_ROOT_INDEX_DECODE_FAILED = "root_index_decode_failed"
        const val REASON_NO_SCHOOLS = "warehouse_no_schools_index"
        const val REASON_ALL_SCHOOLS_FAILED = "warehouse_adapters_unreachable"
    }
}

/** 名单缓存的**写入时间**键（Dart 只有名单本体，没有时间；F09 额外落这个）。 */
const val maintainersCacheTimeKey = "warehouse_maintainers_cache_fetched_at_v1"

/** 读名单缓存（损坏 / 缺键一律空表，与 `decodeMaintainersCache` 口径一致）。 */
fun readMaintainersCache(store: KeyValueStore): List<MaintainerGroup> =
    decodeMaintainersCache(store.getString(maintainersCacheKey))

/** 读缓存写入时间（毫秒）。没写过或值非法回 null。 */
fun readMaintainersCacheTime(store: KeyValueStore): Long? =
    store.getLong(maintainersCacheTimeKey, -1L).takeIf { it > 0L }

/** 写名单缓存 + 时间戳（时间戳是「这次真的拉到新数据」的时刻）。 */
fun writeMaintainersCache(store: KeyValueStore, groups: List<MaintainerGroup>, nowMillis: Long) {
    store.putString(maintainersCacheKey, encodeMaintainersCache(groups))
    store.putLong(maintainersCacheTimeKey, nowMillis)
}

/** 缓存时间展示形态（`2026-10-29 22:40`，本地时区）。 */
fun formatMaintainersCacheTime(
    epochMillis: Long,
    zone: ZoneId = ZoneId.systemDefault(),
): String = Instant.ofEpochMilli(epochMillis).atZone(zone).format(CACHE_TIME_FORMATTER)

private val CACHE_TIME_FORMATTER: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm")
