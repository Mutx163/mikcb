package com.mutx163.qingyu.pages.import.warehouse

import java.net.URI
import kotlin.math.min
import kotlin.math.max

/**
 * 适配仓宿主（P1-10，2026-11-11：真源在 `infra/WarehouseInfra`，这里只留别名）。
 */
typealias WarehouseRepositoryHost = com.mutx163.qingyu.infra.WarehouseRepositoryHost

/**
 * 轻屿教务适配仓源定义（P1-10，2026-11-11：真源在 `infra/WarehouseInfra`）。
 *
 * 导入页原先那份副本已删：它自己的 `fromGitHubUrl` 生产与测试零调用（且不支持
 * gitcode.com 域名），行为超集已归真源；`DEFAULT` / `effectiveOwner` / `effectiveRepo`
 * 一并收进真源，所以本包调用点（`WarehouseRepositorySource.DEFAULT` 等）不用改。
 */
typealias WarehouseRepositorySource = com.mutx163.qingyu.infra.WarehouseRepositorySource

/**
 * 学校条目（P1-10：真源在 `infra/WarehouseInfra`，字段已并成导入页超集）。
 */
typealias WarehouseSchoolEntry = com.mutx163.qingyu.infra.WarehouseSchoolEntry

/**
 * 根索引。
 */
data class WarehouseRootIndex(
    val version: Int = 1,
    val schools: List<WarehouseSchoolEntry> = emptyList(),
)

/**
 * 适配器（导入脚本）条目。
 */
data class WarehouseAdapterEntry(
    val id: String,
    val name: String,
    val script: String,
    val description: String = "",
    val category: String = "教务",
    val maintainer: String = "",
    val importUrl: String = "",
    val schoolCode: String = "",
    val parserType: String = "",
    val updated: String = "",
    /**
     * 适配器脚本的 SHA-256（`adapters.yaml` 的 `sha256` 键）。
     *
     * UI 不读它；留着是因为**脚本完整性校验**是导入执行链路的事（脚本从仓库拉下来要验签），
     * 而那一层还没移植到 Kotlin。先把值解析出来，别让下一个接手的会话再去改数据类。
     */
    val sha256: String = "",
) {
    val adapterName: String get() = name.ifEmpty { id }
}

/**
 * 学校适配器列表索引。
 */
data class WarehouseAdaptersIndex(
    val schoolId: String,
    val schoolName: String,
    val adapters: List<WarehouseAdapterEntry> = emptyList(),
)

/**
 * 全局搜索索引里的一个适配器（P1-10：真源在 `infra/WarehouseInfra`，字段本来就同形）。
 */
typealias WarehouseSearchAdapterEntry = com.mutx163.qingyu.infra.WarehouseSearchAdapterEntry

/**
 * 搜索索引里一所学校的适配器清单（P1-10：真源在 `infra/WarehouseInfra`）。
 */
typealias WarehouseSearchSchoolEntry = com.mutx163.qingyu.infra.WarehouseSearchSchoolEntry

/**
 * `index/search_index.yaml` 的解析结果（P1-10：真源在 `infra/WarehouseInfra`）。
 *
 * 学校的 `name` / `initial` / `code` / `province` 不在这份索引里；学校字段的匹配在
 * 本包的 [filterWarehouseSchools] 里做，索引只补「按适配器名」。
 */
typealias WarehouseSearchIndex = com.mutx163.qingyu.infra.WarehouseSearchIndex

/**
 * 解析 `index/search_index.yaml`（发布版 `parseWarehouseSearchIndexYaml` 的逐条移植）。
 *
 * 宽松解析，与 Dart 侧同口径：跳过注释 / 空行 / 不完整条目；`version_id` 缺失记空串；
 * 一所学校没有可用的适配器条目时整条丢弃（它给不出任何搜索命中）。
 *
 * YAML 子集与仓库文件一致：`schools:` 下缩进 2 的 `- id:` 开新学校，
 * 学校块内 `adapters:` 下缩进 2 的 `- adapter_id:` 开新适配器，其余键值对按缩进归位。
 * 不引第三方 YAML 库的理由见 [WarehouseYamlList] 的 KDoc。
 */
fun parseWarehouseSearchIndex(content: String): WarehouseSearchIndex {
    var versionId = ""
    val schools = mutableListOf<WarehouseSearchSchoolEntry>()

    var inSchools = false
    var inAdapters = false
    var currentSchoolId: String? = null
    var currentAdapters = mutableListOf<WarehouseSearchAdapterEntry>()
    var currentAdapterId: String? = null
    var currentAdapterName = ""

    fun flushAdapter() {
        val adapterId = currentAdapterId
        if (!adapterId.isNullOrEmpty()) {
            currentAdapters.add(WarehouseSearchAdapterEntry(adapterId, currentAdapterName))
        }
        currentAdapterId = null
        currentAdapterName = ""
    }

    fun flushSchool() {
        flushAdapter()
        val schoolId = currentSchoolId
        if (!schoolId.isNullOrEmpty() && currentAdapters.isNotEmpty()) {
            schools.add(WarehouseSearchSchoolEntry(schoolId, currentAdapters.toList()))
        }
        currentSchoolId = null
        currentAdapters = mutableListOf()
        inAdapters = false
    }

    for (rawLine in content.split("\n")) {
        // 制表符先换成两个空格**再算缩进**（仓库文件手写，混入 tab 时不能把缩进算成 1）。
        val normalizedLine = rawLine.removeSuffix("\r").replace("\t", "  ")
        val trimmed = normalizedLine.trim()
        if (trimmed.isEmpty() || trimmed.startsWith("#")) {
            continue
        }
        val indent = normalizedLine.length - normalizedLine.trimStart().length

        if (indent == 0) {
            val pair = WarehouseYamlList.parsePair(trimmed)
            if (pair != null && pair.first == "version_id") {
                versionId = pair.second
                continue
            }
            if (trimmed == "schools:") {
                inSchools = true
                continue
            }
            if (inSchools) {
                // 下一个顶层键：schools 列表结束。
                flushSchool()
                inSchools = false
            }
            continue
        }
        if (!inSchools) {
            continue
        }

        if (indent == 2 && trimmed.startsWith("- ")) {
            flushSchool()
            val pair = WarehouseYamlList.parsePair(trimmed.substring(2).trim())
            currentSchoolId = if (pair != null && pair.first == "id") pair.second else ""
            continue
        }
        if (currentSchoolId == null) {
            continue
        }

        if (trimmed == "adapters:") {
            inAdapters = true
            continue
        }
        if (!inAdapters) {
            continue
        }

        if (trimmed.startsWith("- ")) {
            flushAdapter()
            val pair = WarehouseYamlList.parsePair(trimmed.substring(2).trim())
            if (pair != null && pair.first == "adapter_id") {
                currentAdapterId = pair.second
            }
            continue
        }
        val pair = WarehouseYamlList.parsePair(trimmed) ?: continue
        if (pair.first == "adapter_name" && currentAdapterId != null) {
            currentAdapterName = pair.second
        }
    }
    flushSchool()
    return WarehouseSearchIndex(versionId = versionId, schools = schools)
}

/**
 * 学校展示 Bean。
 */
data class WarehouseSchoolBean(
    val school: WarehouseSchoolEntry,
    val tag: String,
    val isRecent: Boolean,
)

/**
 * 学校分组 Section。
 */
data class WarehouseSchoolSection(
    val tag: String,
    val items: List<WarehouseSchoolBean>,
)

/**
 * 名称含「通用」的都是通用教务/工具类学校（超星/正方/青果/URP/通用工具）。
 */
fun isGenericWarehouseSchool(name: String): Boolean = name.contains("通用")

/**
 * 学校在列表里的 suspension tag：最近使用 → ★，通用置顶 → 通，
 * 其余按首字母大写（空记 #）。
 */
fun warehouseSchoolTag(
    school: WarehouseSchoolEntry,
    isRecent: Boolean,
): String {
    if (isRecent) return "★"
    if (isGenericWarehouseSchool(school.name)) return "通"
    val normalized = school.initial.trim().uppercase()
    if (normalized.isEmpty()) return "#"
    return normalized
}

fun warehouseSchoolTagRank(tag: String): Int {
    if (tag == "★") return 0
    if (tag == "通") return 1
    if (tag == "#") return 1000
    return 10
}

/**
 * 将学校列表转换为带 Tag 的 Bean 列表。
 */
fun schoolsToBeans(
    schools: List<WarehouseSchoolEntry>,
    recentSchoolIds: List<String>,
): List<WarehouseSchoolBean> {
    val schoolMap = schools.associateBy { it.id }
    // 最近列表按「首次出现」去重：云端恢复原样直写（Dart restoreRecentSchools 不去重），
    // 盘上可能躺着重复 id；不去重则同一所学校在 ★ 组出现两次，Compose 选校列表
    // items(key = school.id) 首屏组合时抛 IllegalArgumentException 整页闪退。
    val recentOrdered = recentSchoolIds.distinct().mapNotNull { schoolMap[it] }
    val remaining = schools.filter { it.id !in recentSchoolIds }

    val genericRemaining = remaining.filter { isGenericWarehouseSchool(it.name) }
    val normalRemaining = remaining.filter { !isGenericWarehouseSchool(it.name) }

    val beans = mutableListOf<WarehouseSchoolBean>()
    for (school in recentOrdered) {
        beans.add(WarehouseSchoolBean(school, warehouseSchoolTag(school, isRecent = true), isRecent = true))
    }
    for (school in genericRemaining) {
        beans.add(WarehouseSchoolBean(school, warehouseSchoolTag(school, isRecent = false), isRecent = false))
    }
    for (school in normalRemaining) {
        beans.add(WarehouseSchoolBean(school, warehouseSchoolTag(school, isRecent = false), isRecent = false))
    }
    return beans
}

/**
 * 将 Bean 列表按 Tag 分组合并为 Section。
 */
fun schoolsToSections(beans: List<WarehouseSchoolBean>): List<WarehouseSchoolSection> {
    if (beans.isEmpty()) return emptyList()

    val grouped = linkedMapOf<String, MutableList<WarehouseSchoolBean>>()
    for (bean in beans) {
        grouped.getOrPut(bean.tag) { mutableListOf() }.add(bean)
    }

    val sortedTags = grouped.keys.sortedWith { left, right ->
        val rankCompare = warehouseSchoolTagRank(left).compareTo(warehouseSchoolTagRank(right))
        if (rankCompare != 0) rankCompare else left.compareTo(right)
    }

    return sortedTags.map { tag ->
        WarehouseSchoolSection(tag = tag, items = grouped[tag] ?: emptyList())
    }
}

/**
 * 字母条尺寸。
 */
data class WarehouseIndexBarGeometry(
    val itemHeight: Double,
    val height: Double,
    val width: Double,
)

const val WAREHOUSE_INDEX_BAR_MAX_HEIGHT_RATIO = 0.82
const val WAREHOUSE_INDEX_BAR_MIN_ITEM_HEIGHT = 10.0
const val K_INDEX_BAR_ITEM_HEIGHT = 16.0
const val K_INDEX_BAR_WIDTH = 24.0

fun warehouseIndexBarGeometry(
    tagCount: Int,
    availableHeight: Double,
): WarehouseIndexBarGeometry {
    if (tagCount <= 0) {
        return WarehouseIndexBarGeometry(K_INDEX_BAR_ITEM_HEIGHT, 0.0, K_INDEX_BAR_WIDTH)
    }
    val maxHeight = availableHeight * WAREHOUSE_INDEX_BAR_MAX_HEIGHT_RATIO
    val maxItemHeight = maxHeight / tagCount
    val minItemHeight = min(WAREHOUSE_INDEX_BAR_MIN_ITEM_HEIGHT, maxItemHeight)
    val itemHeight = max(minItemHeight, min(maxItemHeight, K_INDEX_BAR_ITEM_HEIGHT))
    return WarehouseIndexBarGeometry(
        itemHeight = itemHeight,
        height = itemHeight * tagCount,
        width = K_INDEX_BAR_WIDTH,
    )
}

/**
 * 网页文档 Key：scheme + host + path（小写，忽略 query/fragment）。
 */
fun warehouseDocumentKey(url: String?): String {
    val trimmed = (url ?: "").trim()
    val uri = runCatching { URI(trimmed) }.getOrNull()
    if (uri == null || uri.scheme.isNullOrEmpty()) {
        return trimmed
    }
    val path = uri.path ?: ""
    return "${uri.scheme}://${uri.host}$path".lowercase()
}

/**
 * 教务导入学校搜索过滤。
 */
fun filterWarehouseSchools(
    schools: List<WarehouseSchoolEntry>,
    query: String,
    adapterMatches: Map<String, List<String>> = emptyMap(),
): List<WarehouseSchoolEntry> {
    val keyword = query.trim().lowercase()
    if (keyword.isEmpty()) return schools

    return schools.filter { school ->
        val fieldMatch = school.name.lowercase().contains(keyword) ||
                school.id.lowercase().contains(keyword) ||
                school.initial.lowercase().contains(keyword) ||
                school.resourceFolder.lowercase().contains(keyword) ||
                school.code.lowercase().contains(keyword) ||
                school.province.lowercase().contains(keyword)
        if (fieldMatch) return@filter true
        adapterMatches[school.id]?.isNotEmpty() ?: false
    }
}
