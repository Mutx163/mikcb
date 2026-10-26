package com.mutx163.qingyu.infra

import java.net.URI
import java.net.URLEncoder

/**
 * 教务适配仓纯逻辑（源：lib/models/warehouse_repository_models.dart、
 * lib/screens/about_screen.dart 的维护者分组与缓存编解码）。
 *
 * 只收录不碰网络/不碰盘的部分：
 * - [WarehouseRepositorySource]：三种 URL 形态解析 + 三种拉取地址构造。
 * - 学校/适配器搜索（[filterWarehouseSchools]、`matchedAdapterNames…`）。
 * - 维护者分组（[groupMaintainerLabels]：trim、跳空、标签排序、按名排序；
 *   标签形态 "`学校名 · 适配器名`"，源自 ContributorsScreen）。
 * - 维护者缓存的 JSON 编解码（损坏/空一律回空表，不抛）。
 *
 * fetchRootIndex/fetchAdaptersIndex、SharedPreferences 读写是 IO，不在本层。
 */

class WarehouseRepositoryException(message: String) : RuntimeException(message)

enum class WarehouseRepositoryHost { GITHUB, GITCODE }

/** 轻屿教务适配仓默认源（GitHub 主仓 + GitCode 命名空间覆盖）。 */
val defaultQingyuWarehouseSource = WarehouseRepositorySource(
    owner = "Mutx163",
    repo = "qingyu_warehouse",
    gitcodeOwner = "mutx",
)

data class WarehouseRepositorySource(
    val owner: String,
    val repo: String,
    val branch: String = "main",
    val host: WarehouseRepositoryHost = WarehouseRepositoryHost.GITHUB,
    val gitcodeOwner: String? = null,
    val gitcodeRepo: String? = null,
) {
    private val gitcodeEffectiveOwner: String get() = gitcodeOwner ?: owner
    private val gitcodeEffectiveRepo: String get() = gitcodeRepo ?: repo

    /** 返回切换宿主后的源（其余字段保持不变）。 */
    fun withHost(newHost: WarehouseRepositoryHost): WarehouseRepositorySource {
        if (newHost == host) {
            return this
        }
        return copy(host = newHost)
    }

    fun buildRawFileUri(relativePath: String): URI {
        val normalized = relativePath.removePrefix("/")
        return URI("https://raw.githubusercontent.com/$owner/$repo/$branch/$normalized")
    }

    /** GitHub 侧原始文件地址：GitCode 主渠道失败时的回退目标。 */
    fun buildGitHubRawFileUri(relativePath: String): URI = buildRawFileUri(relativePath)

    /** GitCode v5 contents API（Gitee 兼容，免令牌可读，返回 base64 JSON）。 */
    fun buildGitCodeContentsUri(relativePath: String): URI {
        val normalized = relativePath.removePrefix("/")
        val encodedPath = normalized.split("/").joinToString("/") { encodePathSegment(it) }
        val ref = URLEncoder.encode(branch, "UTF-8")
        return URI(
            "https://api.gitcode.com/api/v5/repos/" +
                "$gitcodeEffectiveOwner/$gitcodeEffectiveRepo/contents/" +
                "$encodedPath?ref=$ref",
        )
    }

    /** 按宿主返回主拉取地址。 */
    fun buildFileUri(relativePath: String): URI = when (host) {
        WarehouseRepositoryHost.GITHUB -> buildRawFileUri(relativePath)
        WarehouseRepositoryHost.GITCODE -> buildGitCodeContentsUri(relativePath)
    }

    val repositoryUrl: String get() = "https://github.com/$owner/$repo"

    companion object {
        fun fromGitHubUrl(
            url: String,
            branch: String = "main",
            gitcodeOwner: String? = null,
            gitcodeRepo: String? = null,
        ): WarehouseRepositorySource {
            val uri = try {
                URI(url.trim())
            } catch (_: Exception) {
                null
            }
            if (uri == null || (uri.host ?: "").isEmpty()) {
                throw WarehouseRepositoryException("invalid_repository_url")
            }
            val segments = (uri.path ?: "").split("/").filter { it.isNotEmpty() }
            if (uri.host == "github.com") {
                if (segments.size < 2) {
                    throw WarehouseRepositoryException("incomplete_github_repo_url")
                }
                return WarehouseRepositorySource(
                    owner = segments[0],
                    repo = segments[1],
                    branch = branch,
                    gitcodeOwner = gitcodeOwner,
                    gitcodeRepo = gitcodeRepo,
                )
            }
            if (uri.host == "raw.githubusercontent.com") {
                if (segments.size < 3) {
                    throw WarehouseRepositoryException("incomplete_raw_github_url")
                }
                return WarehouseRepositorySource(
                    owner = segments[0],
                    repo = segments[1],
                    branch = segments[2],
                    gitcodeOwner = gitcodeOwner,
                    gitcodeRepo = gitcodeRepo,
                )
            }
            if (uri.host == "gitcode.com" || uri.host == "raw.gitcode.com") {
                if (segments.size < 2) {
                    throw WarehouseRepositoryException("incomplete_github_repo_url")
                }
                return WarehouseRepositorySource(
                    owner = segments[0],
                    repo = segments[1],
                    branch = branch,
                    host = WarehouseRepositoryHost.GITCODE,
                )
            }
            throw WarehouseRepositoryException("github_only_supported")
        }
    }
}

private fun encodePathSegment(segment: String): String =
    URLEncoder.encode(segment, "UTF-8").replace("+", "%20").replace("%7E", "~")

data class WarehouseSchoolEntry(
    val id: String,
    val name: String,
    val initial: String,
    val resourceFolder: String,
)

data class WarehouseAdapterEntry(
    val adapterId: String,
    val adapterName: String,
    val category: String,
    val assetJsPath: String,
    val importUrl: String,
    val maintainer: String,
    val description: String,
    val sha256: String = "",
    val timeSchemesFile: String = "",
    val isQingyuOnly: Boolean = false,
) {
    /** 只为「把专属条目并进同一份脚本的标准条目」存在（Dart `copyWith` 同语义）。 */
    fun copyWith(
        sha256: String? = null,
        timeSchemesFile: String? = null,
        isQingyuOnly: Boolean? = null,
    ): WarehouseAdapterEntry = copy(
        sha256 = sha256 ?: this.sha256,
        timeSchemesFile = timeSchemesFile ?: this.timeSchemesFile,
        isQingyuOnly = isQingyuOnly ?: this.isQingyuOnly,
    )
}

data class WarehouseSearchAdapterEntry(val adapterId: String, val adapterName: String)

data class WarehouseSearchSchoolEntry(val id: String, val adapters: List<WarehouseSearchAdapterEntry>) {
    /**
     * 关键词命中的适配器显示名（保持索引顺序；名称为空回退 ID）。
     * 大小写不敏感；适配器 ID 与名称都参与匹配。
     */
    fun matchedAdapterNames(keyword: String): List<String> {
        val normalized = keyword.trim().lowercase()
        if (normalized.isEmpty()) {
            return emptyList()
        }
        val names = arrayListOf<String>()
        for (adapter in adapters) {
            val displayName = if (adapter.adapterName.isNotEmpty()) adapter.adapterName else adapter.adapterId
            if (displayName.lowercase().contains(normalized) ||
                adapter.adapterId.lowercase().contains(normalized)
            ) {
                names.add(displayName)
            }
        }
        return names
    }
}

data class WarehouseSearchIndex(val versionId: String, val schools: List<WarehouseSearchSchoolEntry>) {
    /** 关键词命中的适配器显示名，按学校 id 分组（仅含非空命中）。 */
    fun matchedAdapterNamesBySchool(keyword: String): Map<String, List<String>> {
        val normalized = keyword.trim()
        if (normalized.isEmpty()) {
            return emptyMap()
        }
        val matches = linkedMapOf<String, List<String>>()
        for (school in schools) {
            val names = school.matchedAdapterNames(normalized)
            if (names.isNotEmpty()) {
                matches[school.id] = names
            }
        }
        return matches
    }
}

/**
 * 教务导入学校搜索：命中学校名称/ID/首字母/资源目录，或搜索索引中任一适配器。
 * [adapterMatches] 传空表时行为与仅按学校字段搜索完全一致。
 */
fun filterWarehouseSchools(
    schools: List<WarehouseSchoolEntry>,
    query: String,
    adapterMatches: Map<String, List<String>> = emptyMap(),
): List<WarehouseSchoolEntry> {
    val keyword = query.trim().lowercase()
    if (keyword.isEmpty()) {
        return schools
    }
    return schools.filter { school ->
        val fieldMatch = school.name.lowercase().contains(keyword) ||
            school.id.lowercase().contains(keyword) ||
            school.initial.lowercase().contains(keyword) ||
            school.resourceFolder.lowercase().contains(keyword)
        if (fieldMatch) {
            true
        } else {
            (adapterMatches[school.id]?.isNotEmpty() == true)
        }
    }
}

data class MaintainerGroup(val name: String, val adapterLabels: List<String>)

/** 维护者分组标签形态："`学校名 · 适配器名`"（ContributorsScreen 拼法）。 */
fun buildMaintainerLabel(schoolName: String, adapterName: String): String = "$schoolName · $adapterName"

/**
 * 维护者分组纯核：trim、跳过空白维护者、每组标签排序、组按名排序。
 * 输入为 `(maintainer, label)` 对（IO 拼装在外）。
 */
fun groupMaintainerLabels(entries: List<Pair<String, String>>): List<MaintainerGroup> {
    val groups = linkedMapOf<String, MutableList<String>>()
    for ((maintainer, label) in entries) {
        val name = maintainer.trim()
        if (name.isEmpty()) {
            continue
        }
        groups.getOrPut(name) { arrayListOf() }.add(label)
    }
    return groups.entries
        .map { (name, labels) -> MaintainerGroup(name = name, adapterLabels = labels.sorted()) }
        .sortedBy { it.name }
}

const val maintainersCacheKey = "warehouse_maintainers_cache_v1"

/** 维护者缓存编码（Dart `_writeMaintainersCache` 的 JSON 形态）。 */
fun encodeMaintainersCache(groups: List<MaintainerGroup>): String {
    val items = groups.map { group ->
        linkedMapOf<String, Any?>(
            "name" to group.name,
            "adapterLabels" to group.adapterLabels,
        )
    }
    return InfraJson.encode(items)
}

/**
 * 维护者缓存解码（Dart `_readMaintainersCache`）：null/空/非法/非数组一律回空表；
 * name 为空的条目丢弃；adapterLabels 只收字符串。
 */
fun decodeMaintainersCache(raw: String?): List<MaintainerGroup> {
    if (raw.isNullOrEmpty()) {
        return emptyList()
    }
    val decoded = InfraJson.tryParse(raw)
    if (decoded !is List<*>) {
        return emptyList()
    }
    val result = arrayListOf<MaintainerGroup>()
    for (item in decoded) {
        if (item !is Map<*, *>) {
            continue
        }
        val name = item["name"] as? String ?: ""
        val labels = (item["adapterLabels"] as? List<*>)
            ?.filterIsInstance<String>()
            ?: emptyList()
        if (name.isNotEmpty()) {
            result.add(MaintainerGroup(name = name, adapterLabels = labels))
        }
    }
    return result
}
