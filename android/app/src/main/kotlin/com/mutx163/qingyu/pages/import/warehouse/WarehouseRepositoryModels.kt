package com.mutx163.qingyu.pages.import.warehouse

import java.net.URI
import kotlin.math.min
import kotlin.math.max

/**
 * 适配仓宿主：GitHub（raw.githubusercontent 直链）或 GitCode（v5 contents API）。
 */
enum class WarehouseRepositoryHost {
    GITHUB,
    GITCODE;

    companion object {
        fun fromString(value: String): WarehouseRepositoryHost = when (value.lowercase()) {
            "gitcode" -> GITCODE
            else -> GITHUB
        }
    }
}

/**
 * 轻屿教务适配仓源定义。
 */
data class WarehouseRepositorySource(
    val owner: String,
    val repo: String,
    val branch: String = "main",
    val host: WarehouseRepositoryHost = WarehouseRepositoryHost.GITHUB,
    val gitcodeOwner: String? = null,
    val gitcodeRepo: String? = null,
) {
    val effectiveOwner: String get() = if (host == WarehouseRepositoryHost.GITCODE) gitcodeOwner ?: owner else owner
    val effectiveRepo: String get() = if (host == WarehouseRepositoryHost.GITCODE) gitcodeRepo ?: repo else repo

    fun withHost(newHost: WarehouseRepositoryHost): WarehouseRepositorySource {
        if (newHost == host) return this
        return copy(host = newHost)
    }

    companion object {
        val DEFAULT = WarehouseRepositorySource(
            owner = "Mutx163",
            repo = "qingyu_warehouse",
            gitcodeOwner = "mutx",
        )

        fun fromGitHubUrl(
            url: String,
            branch: String = "main",
            gitcodeOwner: String? = null,
            gitcodeRepo: String? = null,
        ): WarehouseRepositorySource {
            val trimmed = url.trim()
            val uri = runCatching { URI(trimmed) }.getOrNull()
                ?: throw IllegalArgumentException("invalid_repository_url")
            val hostStr = uri.host ?: throw IllegalArgumentException("invalid_repository_url")

            val segments = (uri.path ?: "").split("/").filter { it.isNotEmpty() }
            if (hostStr == "github.com") {
                if (segments.size < 2) throw IllegalArgumentException("incomplete_github_repo_url")
                return WarehouseRepositorySource(
                    owner = segments[0],
                    repo = segments[1],
                    branch = branch,
                    gitcodeOwner = gitcodeOwner,
                    gitcodeRepo = gitcodeRepo,
                )
            }
            if (hostStr == "raw.githubusercontent.com") {
                if (segments.size < 3) throw IllegalArgumentException("incomplete_raw_github_url")
                return WarehouseRepositorySource(
                    owner = segments[0],
                    repo = segments[1],
                    branch = segments[2],
                    gitcodeOwner = gitcodeOwner,
                    gitcodeRepo = gitcodeRepo,
                )
            }
            throw IllegalArgumentException("unsupported_repository_host")
        }
    }
}

/**
 * 学校条目。
 */
data class WarehouseSchoolEntry(
    val id: String,
    val name: String,
    val initial: String = "",
    val resourceFolder: String = id,
    val category: String = "default",
    val code: String = "",
    val province: String = "",
)

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
 * 全局搜索索引条目。
 */
data class WarehouseSearchAdapterEntry(
    val schoolId: String,
    val schoolName: String,
    val adapterId: String,
    val adapterName: String,
)

data class WarehouseSearchSchoolEntry(
    val id: String,
    val name: String,
    val initial: String = "",
    val code: String = "",
    val province: String = "",
    val adapters: List<WarehouseSearchAdapterEntry> = emptyList(),
)

data class WarehouseSearchIndex(
    val schools: List<WarehouseSearchSchoolEntry> = emptyList(),
    val adapters: List<WarehouseSearchAdapterEntry> = emptyList(),
) {
    fun matchedAdapterNamesBySchool(keyword: String): Map<String, List<String>> {
        val query = keyword.trim().lowercase()
        if (query.isEmpty()) return emptyMap()

        val result = mutableMapOf<String, MutableList<String>>()
        for (adapter in adapters) {
            val nameMatch = adapter.adapterName.lowercase().contains(query)
            val idMatch = adapter.adapterId.lowercase().contains(query)
            if (nameMatch || idMatch) {
                result.getOrPut(adapter.schoolId) { mutableListOf() }.add(adapter.adapterName)
            }
        }
        return result
    }
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
    val recentOrdered = recentSchoolIds.mapNotNull { schoolMap[it] }
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
