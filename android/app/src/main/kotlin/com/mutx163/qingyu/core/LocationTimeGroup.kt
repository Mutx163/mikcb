package com.mutx163.qingyu.core

/**
 * 地点分组模型（移植自 lib/models/location_time_group.dart）与
 * 地点匹配逻辑（移植自 lib/domain/location_time_match_logic.dart）。
 *
 * 匹配归一口径（_normalizeForMatch，与 Dart 逐行等价）：
 * - trim；
 * - 全角 ASCII（0xFF01..0xFF5E）→ 半角（-0xFEE0）；
 * - 全角空格 0x3000、空白（0x20/09/0A/0D）、中点族（0x00B7/0x30FB/0x2022/0x2027/0x2219）全部剔除；
 * - 破折号族（0x2014/0x2013/0xFF0D）→ '-'；全角斜杠 0xFF0F → '/'；
 * - 「（…）」括号内容保留、括号本身剔除（1..12 字）；
 * - 整体 lowerCase。
 */

/** 地点关键词匹配方式（location_time_group.dart:4-17）。 */
enum class LocationKeywordMatchMode(val value: String) {
    PREFIX("prefix"),
    CONTAINS("contains"),
    EXACT("exact");

    companion object {
        /** 未知值回落 prefix（Dart fromValue orElse）。 */
        fun fromValue(raw: String?): LocationKeywordMatchMode =
            entries.firstOrNull { it.value == raw } ?: PREFIX
    }
}

/** 单个地点关键词（location_time_group.dart:21-57）。 */
data class LocationKeyword(
    val pattern: String,
    val mode: LocationKeywordMatchMode = LocationKeywordMatchMode.PREFIX,
) {
    fun toJson(): Map<String, Any?> =
        linkedMapOf("pattern" to pattern, "mode" to mode.value)

    companion object {
        fun fromJson(json: Map<*, *>): LocationKeyword = LocationKeyword(
            pattern = (json["pattern"] as? String ?: "").trim(),
            mode = LocationKeywordMatchMode.fromValue(json["mode"] as? String),
        )
    }
}

/** 地点分组（location_time_group.dart:61-173）。 */
data class LocationTimeGroup(
    val id: String,
    val name: String,
    val timeSchemeId: String,
    val enabled: Boolean = true,
    val priority: Int = 0,
    val keywords: List<LocationKeyword> = emptyList(),
    /** 创建来源的学校 ID；null = 用户手建（或字段引入前的存量数据）。 */
    val sourceSchoolId: String? = null,
) {
    val keywordSummary: String
        get() = if (keywords.isEmpty()) "" else keywords.joinToString(", ") { it.pattern }

    fun toJsonMap(): Map<String, Any?> = linkedMapOf(
        "id" to id,
        "name" to name,
        "timeSchemeId" to timeSchemeId,
        "enabled" to enabled,
        "priority" to priority,
        "keywords" to keywords.map { it.toJson() },
        "sourceSchoolId" to sourceSchoolId,
    )

    fun toJsonString(): String = MiniJson.encode(toJsonMap())

    companion object {
        fun fromJson(json: Map<String, Any?>): LocationTimeGroup {
            val rawKeywords = json["keywords"] as? List<*> ?: emptyList<Any?>()
            val keywords = mutableListOf<LocationKeyword>()
            for (item in rawKeywords) {
                if (item !is Map<*, *>) continue
                val keyword = try {
                    LocationKeyword.fromJson(item)
                } catch (_: Exception) {
                    continue
                }
                if (keyword.pattern.isNotEmpty()) keywords.add(keyword)
            }
            return LocationTimeGroup(
                id = json["id"] as? String ?: "",
                // Dart: (json['name'] as String? ?? '').trim() —— 非 String 会抛，
                // 但 2026-10-19 后 sourceSchoolId 走 toString；name 仍是裸 as String?。
                name = (json["name"] as? String ?: "").trim(),
                timeSchemeId = json["timeSchemeId"] as? String ?: "",
                enabled = json["enabled"] as? Boolean ?: true,
                priority = (json["priority"] as? Number)?.toInt() ?: 0,
                keywords = keywords,
                // 数字型来源校 ID toString 收下，空白 → null（_cleanOptional）。
                sourceSchoolId = cleanOptional(json["sourceSchoolId"]?.toString()),
            )
        }

        fun fromJsonString(text: String): LocationTimeGroup {
            val decoded = MiniJson.parse(text)
            if (decoded !is Map<*, *>) throw DartFormatException("location group json must be an object")
            @Suppress("UNCHECKED_CAST")
            return fromJson(decoded as Map<String, Any?>)
        }

        /** 空白串归一为 null，避免「来源是空串」和「没有来源」并存。 */
        private fun cleanOptional(raw: String?): String? {
            if (raw == null) return null
            val trimmed = raw.trim()
            return trimmed.ifEmpty { null }
        }
    }
}

/** 匹配结果（location_time_match_logic.dart:4-16）。 */
data class LocationTimeMatchResult(
    val groupId: String,
    val groupName: String,
    val timeSchemeId: String,
    val matchedKeyword: LocationKeyword,
)

/**
 * 一条候选关键词。
 *
 * [normalizedPattern] / [patternLength] 在**构造时算一次**：`match()` 原先在
 * 「候选构造 + 排序比较器 + 命中循环」里反复调 `normalizePattern`，而排序比较器是
 * O(k·log k) 次——等于每门课、每套模板都重算几十次同一个归一化串（2026-11-10 定位
 * 为「时间模板页转圈很久 / 新建模板点确定卡住」的主要开销之一）。归一化结果只取决于
 * 关键词本身，预计算不改变任何匹配结果。
 */
private data class CandidateKeyword(
    val group: LocationTimeGroup,
    val keyword: LocationKeyword,
    val normalizedPattern: String,
    val patternLength: Int,
)

/** 纯地点 → 作息路由（location_time_match_logic.dart:26-263）。 */
object LocationTimeMatchLogic {

    /**
     * 「（…）」括号内容保留、括号剔除（1..12 字）。
     *
     * 提成文件级常量：原先在 [normalizeForMatch] 里**每次调用都 `Regex(...)` 新建**，
     * 而匹配路径（`TimeSchemeLogic.getCourseUsages` → 每门课一次）的调用量级是
     * 「课程数 × 模板数 × 关键词数」，一次索引构建就是上万次正则编译
     * （2026-11-10 定位的根因）。
     */
    private val BRACKETED_CONTENT = Regex("""[（(]([^）)]{1,12})[）)]""")

    /** 归一化缓存容量：地点串在同一份数据里高度重复，几百条足够覆盖。 */
    private const val NORMALIZE_CACHE_LIMIT = 1024

    /**
     * 归一化结果缓存（有界 LRU）。
     *
     * 只影响速度、不改变返回值：命中即返回上次算出的同一个串。加锁是因为调用方既有
     * 后台线程（引用索引 / 拼包），也有主线程（编辑器页）。
     */
    private val normalizeCache = object : java.util.LinkedHashMap<String, String>(64, 0.75f, true) {
        override fun removeEldestEntry(
            eldest: MutableMap.MutableEntry<String, String>?,
        ): Boolean = size > NORMALIZE_CACHE_LIMIT
    }

    fun normalizeLocation(location: String?): String = normalizeForMatch(location)

    fun normalizePattern(pattern: String): String = normalizeForMatch(pattern)

    private fun normalizeForMatch(text: String?): String {
        val raw = (text ?: "").trim()
        if (raw.isEmpty()) return ""
        synchronized(normalizeCache) { normalizeCache[raw] }?.let { return it }
        val buffer = StringBuilder()
        for (unit in raw.codePoints()) {
            when {
                unit in 0xFF01..0xFF5E -> buffer.appendCodePoint(unit - 0xFEE0)
                unit == 0x3000 -> {} // 全角空格：剔除
                unit == 0x20 || unit == 0x09 || unit == 0x0A || unit == 0x0D -> {} // 空白剔除
                unit == 0x00B7 || unit == 0x30FB || unit == 0x2022 ||
                    unit == 0x2027 || unit == 0x2219 -> {} // 中点/圆点剔除
                unit == 0x2014 || unit == 0x2013 || unit == 0xFF0D -> buffer.append('-')
                unit == 0xFF0F -> buffer.append('/')
                else -> buffer.appendCodePoint(unit)
            }
        }
        var normalized = buffer.toString()
        // 「（…）」括号内容保留、括号剔除（1..12 字），与楼栋聚类归一同步。
        normalized = normalized.replace(BRACKETED_CONTENT) { m ->
            m.groupValues[1]
        }
        normalized = normalized.lowercase()
        synchronized(normalizeCache) { normalizeCache[raw] = normalized }
        return normalized
    }

    /**
     * 匹配 [location]：长关键词优先，等长按更高 priority，再按组名与
     * pattern 字典序（确定性兜底，与 Dart 同序）。
     */
    fun match(location: String?, groups: List<LocationTimeGroup>): LocationTimeMatchResult? {
        val normalizedLocation = normalizeLocation(location)
        if (normalizedLocation.isEmpty()) return null

        val candidates = mutableListOf<CandidateKeyword>()
        for (group in groups) {
            if (!group.enabled || group.timeSchemeId.isEmpty()) continue
            for (keyword in group.keywords) {
                val pattern = normalizePattern(keyword.pattern)
                if (pattern.isEmpty()) continue
                candidates.add(
                    CandidateKeyword(
                        group = group,
                        keyword = keyword,
                        normalizedPattern = pattern,
                        patternLength = pattern.length,
                    ),
                )
            }
        }
        if (candidates.isEmpty()) return null

        candidates.sortWith { left, right ->
            val lengthCompare = right.patternLength.compareTo(left.patternLength)
            if (lengthCompare != 0) return@sortWith lengthCompare
            val priorityCompare = right.group.priority.compareTo(left.group.priority)
            if (priorityCompare != 0) return@sortWith priorityCompare
            val nameCompare = left.group.name.compareTo(right.group.name)
            if (nameCompare != 0) return@sortWith nameCompare
            left.keyword.pattern.compareTo(right.keyword.pattern)
        }

        for (candidate in candidates) {
            if (matchesMode(normalizedLocation, candidate.normalizedPattern, candidate.keyword.mode)) {
                return LocationTimeMatchResult(
                    groupId = candidate.group.id,
                    groupName = candidate.group.name,
                    timeSchemeId = candidate.group.timeSchemeId,
                    matchedKeyword = candidate.keyword,
                )
            }
        }
        return null
    }

    private fun matchesMode(location: String, pattern: String, mode: LocationKeywordMatchMode): Boolean =
        when (mode) {
            LocationKeywordMatchMode.EXACT -> location == pattern
            LocationKeywordMatchMode.PREFIX -> location.startsWith(pattern)
            LocationKeywordMatchMode.CONTAINS -> location.contains(pattern)
        }

    /** 是否有**启用中**的组绑定 [schemeId]。 */
    fun isSchemeBoundByGroups(groups: List<LocationTimeGroup>, schemeId: String): Boolean =
        groups.any { it.enabled && it.timeSchemeId == schemeId }

    /** 是否有组（启用与否皆算）引用 [schemeId]。 */
    fun isSchemeReferencedByGroups(groups: List<LocationTimeGroup>, schemeId: String): Boolean =
        groups.any { it.timeSchemeId == schemeId }

    /** 除 [excludingGroupId] 外各组持有的归一化 pattern 集合。 */
    fun patternsOwnedByOtherGroups(
        groups: List<LocationTimeGroup>,
        excludingGroupId: String? = null,
    ): Set<String> {
        val owned = linkedSetOf<String>()
        for (group in groups) {
            if (excludingGroupId != null && group.id == excludingGroupId) continue
            for (keyword in group.keywords) {
                val pattern = normalizePattern(keyword.pattern)
                if (pattern.isNotEmpty()) owned.add(pattern)
            }
        }
        return owned
    }

    /** 已有别的组持有 [pattern] 时返回那个组的名字，否则 null。 */
    fun groupNameOwningPattern(
        groups: List<LocationTimeGroup>,
        pattern: String,
        excludingGroupId: String? = null,
    ): String? {
        val normalized = normalizePattern(pattern)
        if (normalized.isEmpty()) return null
        for (group in groups) {
            if (excludingGroupId != null && group.id == excludingGroupId) continue
            for (keyword in group.keywords) {
                if (normalizePattern(keyword.pattern) == normalized) return group.name
            }
        }
        return null
    }

    /** [location] 是否已被其他组的关键词认领（同一教室不能归两个组）。 */
    fun isLocationClaimedByOtherGroups(
        location: String?,
        groups: List<LocationTimeGroup>,
        excludingGroupId: String? = null,
    ): Boolean {
        val others = groups.filter { excludingGroupId == null || it.id != excludingGroupId }
        return match(location, others) != null
    }

    /** 除 [excludingGroupId] 外的所有关键词（覆盖度 UI 用）。 */
    fun keywordsFromOtherGroups(
        groups: List<LocationTimeGroup>,
        excludingGroupId: String? = null,
    ): List<LocationKeyword> {
        val keywords = mutableListOf<LocationKeyword>()
        for (group in groups) {
            if (excludingGroupId != null && group.id == excludingGroupId) continue
            keywords.addAll(group.keywords)
        }
        return keywords
    }
}
