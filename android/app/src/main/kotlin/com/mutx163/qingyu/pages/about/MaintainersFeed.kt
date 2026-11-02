package com.mutx163.qingyu.pages.about

import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.infra.MaintainerGroup
import com.mutx163.qingyu.infra.WarehouseRepositorySource
import com.mutx163.qingyu.infra.buildMaintainerLabel
import com.mutx163.qingyu.infra.decodeMaintainersCache
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
) {

    fun fetch(): MaintainersFetchOutcome {
        val rootUrl = uri(ROOT_INDEX_PATH)
        val rootResponse = runCatching { http.get(rootUrl) }.getOrNull()
            ?: return MaintainersFetchOutcome.Failure(REASON_NETWORK_UNAVAILABLE)
        if (rootResponse.statusCode != 200) {
            // 根索引没有本地缓存可退：304/404/5xx 都只能如实报错。
            return MaintainersFetchOutcome.Failure("http_${rootResponse.statusCode}")
        }
        val rootText = decodeBody(rootUrl, rootResponse)
            ?: return MaintainersFetchOutcome.Failure(REASON_ROOT_INDEX_DECODE_FAILED)
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
        val path = "resources/${school.resourceFolder}/adapters.yaml"
        val url = uri(path)
        val response = runCatching { http.get(url) }.getOrNull()
        if (response == null || response.statusCode != 200) {
            return SchoolFetch(emptyList(), failed = true)
        }
        val text = decodeBody(url, response)
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

    private fun uri(relativePath: String): String = source.buildFileUri(relativePath).toString()

    private fun decodeBody(url: String, response: AboutHttpResponse): String? =
        if (isGitCodeContentsUrl(url)) decodeGitCodeContentsBody(response.body) else response.body

    private data class SchoolFetch(val entries: List<Pair<String, String>>, val failed: Boolean)

    companion object {
        const val ROOT_INDEX_PATH = "index/root_index.yaml"
        const val DEFAULT_PARALLELISM = 6
        const val MAX_PARALLELISM = 8

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
