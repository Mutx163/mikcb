package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.core.LocationKeyword
import com.mutx163.qingyu.core.LocationKeywordMatchMode
import com.mutx163.qingyu.core.LocationTimeGroup
import com.mutx163.qingyu.core.SectionTime
import java.util.UUID

/**
 * `qingyu_only/<学校目录>/time_schemes.json` 的解析与应用
 * （移植 Dart `lib/domain/warehouse_location_time_schemes.dart`）。
 *
 * ## 为什么要有这份数据
 *
 * 上游教务协议一次导入只能通过 `savePresetTimeSlots` 存**一套**全局作息。学校按校区 /
 * 教学楼公布多套作息时（实测 CQCST 四套、13 节，第 3、4 节差 5~15 分钟），协议表达不了。
 * 往协议里加方法是走不通的（会破坏「脚本能原样回馈上游」），所以学校知识放数据文件。
 *
 * ## 校验口径
 *
 * **不信任仓库里的数据**：镜像可能被投毒、也可能回退到没有该目录的旧版本。整体不可用
 * 抛 [QingyuOnlyTimeSchemesException]（消息是服务消息码）；单条脏数据只丢自己那一条。
 * 校验项与仓库侧 `scripts/validate_qingyu_only.py` 一致：仓库侧拦 CI，App 侧拦线上。
 */

/** 轻屿专属作息数据里的一套作息。 */
data class QingyuOnlyTimeScheme(
    val name: String,
    val keywords: List<LocationKeyword>,
    val sections: List<SectionTime>,
) {
    /** 套不上任何关键词时使用的兜底作息（keywords 为空即兜底）。 */
    val isFallback: Boolean get() = keywords.isEmpty()
}

/** 一个校区下的一组作息（恰好一套兜底 + 若干带关键词的）。 */
data class QingyuOnlyCampus(
    val id: String,
    val name: String,
    val schemes: List<QingyuOnlyTimeScheme>,
)

/** 一份 `time_schemes.json`。 */
data class QingyuOnlyTimeSchemes(val campuses: List<QingyuOnlyCampus>) {

    /** 单校区时无需询问直接用它；多校区交给调用方按脚本的选择反推。 */
    val soleCampus: QingyuOnlyCampus? get() = campuses.singleOrNull()

    /**
     * 用「脚本下发的那套作息」反推用户选的是哪个校区。
     *
     * 专属条目复用的是上游标准脚本，而那份脚本本来就会问「选择学校作息时间表」。App 再问
     * 一次「你在哪个校区？」等于让用户连着回答同一个问题两遍。这里不新增提问，而是拿脚本
     * 给出的节次时间与各套解析后的节次逐节比对：完全相同的那一套就是答案。
     *
     * 同时是自校验的：数据文件与脚本对不上时不猜（返回 null），调用方退回脚本那套全局作息。
     * 命中多套同样返回 null（此时「用户选了哪套」本身没有答案）。
     */
    fun campusForSections(sections: List<SectionTime>): QingyuOnlyCampus? {
        if (sections.isEmpty()) return null
        var matched: QingyuOnlyCampus? = null
        for (campus in campuses) {
            for (scheme in campus.schemes) {
                if (!sameSections(scheme.sections, sections)) continue
                if (matched != null) return null
                matched = campus
            }
        }
        return matched
    }

    private fun sameSections(a: List<SectionTime>, b: List<SectionTime>): Boolean {
        if (a.size != b.size) return false
        for (index in a.indices) {
            if (a[index].startTime != b[index].startTime) return false
            if (a[index].endTime != b[index].endTime) return false
        }
        return true
    }
}

/** 数据不可用时抛出；[code] 是服务消息码（与 Dart 同名）。 */
class QingyuOnlyTimeSchemesException(val code: String) : Exception(code)

/** 纯函数解析器（Dart `QingyuOnlyTimeSchemesLogic`）。 */
object QingyuOnlyTimeSchemesLogic {

    /** 支持的数据版本。将来改格式时旧 App 应当「读不懂就跳过」而不是误读。 */
    const val SUPPORTED_VERSION = 1

    fun parse(decoded: Any?): QingyuOnlyTimeSchemes {
        val root = decoded as? Map<*, *>
            ?: throw QingyuOnlyTimeSchemesException("qingyu_only_time_schemes_format")
        val version = root["version"] as? Number
        if (version == null || version.toInt() != SUPPORTED_VERSION || version.toDouble() != 1.0) {
            throw QingyuOnlyTimeSchemesException("qingyu_only_time_schemes_version")
        }

        val baseline = parseSectionMap(root["sections"], requireContiguousFromOne = true)
            ?: throw QingyuOnlyTimeSchemesException("qingyu_only_time_schemes_baseline_missing")

        val rawCampuses = root["campuses"] as? List<*>
        if (rawCampuses.isNullOrEmpty()) {
            throw QingyuOnlyTimeSchemesException("qingyu_only_time_schemes_campuses_missing")
        }

        val campuses = mutableListOf<QingyuOnlyCampus>()
        val seenCampusIds = mutableSetOf<String>()
        for (raw in rawCampuses) {
            val campus = raw as? Map<*, *> ?: continue
            val name = text(campus["name"])
            if (name.isEmpty()) continue
            // id 只用于去重与日志；为空时用名字兜底，避免整校区被误判成重复。
            val rawId = text(campus["id"])
            val key = rawId.ifEmpty { name }
            if (!seenCampusIds.add(key)) continue
            val schemes = parseSchemes(campus["schemes"], baseline)
            if (schemes.isEmpty()) continue
            // 兜底作息必须恰好一套：没有它则课程时间无处可落，多于一套则「默认用哪套」没有答案。
            if (schemes.count { it.isFallback } != 1) continue
            campuses.add(QingyuOnlyCampus(id = key, name = name, schemes = schemes))
        }

        if (campuses.isEmpty()) {
            throw QingyuOnlyTimeSchemesException("qingyu_only_time_schemes_campuses_empty")
        }
        return QingyuOnlyTimeSchemes(campuses = campuses)
    }

    private fun parseSchemes(
        raw: Any?,
        baseline: Map<Int, SectionTime>,
    ): List<QingyuOnlyTimeScheme> {
        val items = raw as? List<*> ?: return emptyList()
        val schemes = mutableListOf<QingyuOnlyTimeScheme>()
        val seenNames = mutableSetOf<String>()
        for (item in items) {
            val row = item as? Map<*, *> ?: continue
            val name = text(row["name"])
            // 重名会让「兜底是哪一套」变歧义，先到先得。
            if (name.isEmpty() || !seenNames.add(name)) continue
            val sections = resolveSchemeSections(row["overrides"], baseline) ?: continue
            schemes.add(
                QingyuOnlyTimeScheme(
                    name = name,
                    keywords = parseKeywords(row["keywords"]),
                    sections = sections,
                ),
            )
        }
        return schemes
    }

    /**
     * 基线 + 该套的覆盖 → 完整时间表。覆盖只允许改时间，不允许增删节次。
     *
     * 返回 null 表示这套数据不可用，调用方丢掉这一套即可（同校区其余套仍可用）。
     */
    private fun resolveSchemeSections(
        rawOverrides: Any?,
        baseline: Map<Int, SectionTime>,
    ): List<SectionTime>? {
        // 覆盖表天生稀疏 ——「只写与基线不同的节次」正是这个格式存在的理由 ——
        // 所以绝不能要求 1..N 连续（第一版就踩过这个坑，把真实数据砍掉两套）。
        val hasOverrides = rawOverrides is Map<*, *> && rawOverrides.isNotEmpty()
        val overrides = if (hasOverrides) {
            parseSectionMap(rawOverrides, requireContiguousFromOne = false)
        } else {
            null
        }
        // 显式写了覆盖却读不出内容（节次越界、时钟倒退）＝ 数据写错。
        if (hasOverrides && overrides == null) return null
        if (overrides != null) {
            for (index in overrides.keys) {
                if (!baseline.containsKey(index)) return null
            }
        }
        val sections = mutableListOf<SectionTime>()
        for (index in 1..baseline.size) {
            val section = overrides?.get(index) ?: baseline.getValue(index)
            if (sections.isNotEmpty()) {
                // 覆盖后仍要求每一节不早于上一节的结束 —— App 建模板的硬性要求。
                val previousEnd = clockMinutes(sections.last().endTime)
                val start = clockMinutes(section.startTime)
                if (previousEnd == null || start == null || previousEnd > start) return null
            }
            sections.add(section)
        }
        return sections
    }

    /**
     * 把 `{"3": {startTime, endTime}}` 读成节次序号 → 时间。
     *
     * 返回 null 表示这份数据不可用：序号不是正整数、时钟格式不对、或结束不晚于开始。
     * [requireContiguousFromOne] 只对**基线**为真；覆盖表是稀疏的，不受此限。
     */
    private fun parseSectionMap(
        raw: Any?,
        requireContiguousFromOne: Boolean,
    ): Map<Int, SectionTime>? {
        val map = raw as? Map<*, *> ?: return null
        if (map.isEmpty()) return null
        val byIndex = linkedMapOf<Int, SectionTime>()
        for ((key, value) in map) {
            val index = text(key).toIntOrNull()
            val row = value as? Map<*, *> ?: return null
            if (index == null || index <= 0) return null
            val start = text(row["startTime"])
            val end = text(row["endTime"])
            val startMinutes = clockMinutes(start) ?: return null
            val endMinutes = clockMinutes(end) ?: return null
            if (endMinutes <= startMinutes) return null
            byIndex[index] = SectionTime(startTime = start, endTime = end)
        }
        if (byIndex.isEmpty()) return null
        if (requireContiguousFromOne) {
            val ordered = byIndex.keys.sorted()
            // 节次按位置对齐，缺一节会让「第 3 节」指向错误的时间。
            for (index in ordered.indices) {
                if (ordered[index] != index + 1) return null
            }
        }
        return byIndex
    }

    private fun parseKeywords(raw: Any?): List<LocationKeyword> {
        val items = raw as? List<*> ?: return emptyList()
        val keywords = mutableListOf<LocationKeyword>()
        for (item in items) {
            val row = item as? Map<*, *> ?: continue
            val pattern = text(row["pattern"])
            if (pattern.isEmpty()) continue
            keywords.add(
                LocationKeyword(
                    pattern = pattern,
                    mode = LocationKeywordMatchMode.fromValue(text(row["mode"])),
                ),
            )
        }
        return keywords
    }

    private fun text(raw: Any?): String = raw?.toString()?.trim().orEmpty()

    private fun clockMinutes(value: String): Int? {
        val parts = value.split(":")
        if (parts.size != 2) return null
        val hour = parts[0].toIntOrNull() ?: return null
        val minute = parts[1].toIntOrNull() ?: return null
        if (hour > 23 || minute > 59) return null
        return hour * 60 + minute
    }
}

/**
 * 导入一套专属作息时，现有地点分组与新分组怎么合（Dart `mergeLocationTimeGroupsForImport`）。
 *
 * 三条规则，优先级从高到低：
 *
 * 1. **同名替换**：数据文件提到的组名直接顶掉旧组——重复导入不攒重名组。
 * 2. **他校自动组清除**：来源标记是别的学校的自动分组（教学楼名跨校撞车太常见，
 *    「A栋」谁家都有），留着只会把新校教室错分到旧校的作息上。
 * 3. **其余一律保留**：用户手建的组（无来源标记）与本校旧组。手建组不属于任何一次导入的
 *    清理范围；本校旧组随后会被同名替换或继续生效。
 */
fun mergeLocationTimeGroupsForImport(
    existing: List<LocationTimeGroup>,
    incoming: List<LocationTimeGroup>,
    schoolId: String,
): List<LocationTimeGroup> {
    val replacedNames = incoming.map { it.name }.toSet()
    return buildList {
        for (group in existing) {
            if (replacedNames.contains(group.name)) continue
            if (group.sourceSchoolId != null && group.sourceSchoolId != schoolId) continue
            add(group)
        }
        addAll(incoming)
    }
}

/** 应用专属作息的结果。 */
sealed class QingyuOnlyApplyResult {
    /** 成功套用：写了 N 套模板、M 个分组，并把兜底那套设为当前课表。 */
    data class Applied(
        val campusId: String,
        val schemeCount: Int,
        val groupCount: Int,
    ) : QingyuOnlyApplyResult()

    /** 有意跳过（数据/脚本对不上、缺兜底）：什么都不改，退回脚本那套全局作息。 */
    data class Skipped(val code: String) : QingyuOnlyApplyResult()

    /** 写盘失败：消息是服务消息码，调用方只记日志、不中断导入。 */
    data class Failed(val code: String) : QingyuOnlyApplyResult()
}

/**
 * 把解析好的专属作息落到既有仓储通道（Dart `_applyQingyuOnlyLocationTimeSchemes`）。
 *
 * 顺序与 Dart 一致：
 * 1. 每套作息按**名字** upsert 成一条时间模板（同名更新，缺则新建）；
 * 2. 带关键词的那几套各建一条地点时间分组（`sourceSchoolId` 标记来源校），
 *    按 [mergeLocationTimeGroupsForImport] 合并进现有分组；
 * 3. 最后把兜底那套设为当前课表。
 *
 * 「缺兜底」时**什么都不改**（只改一半比不改更糟）；写盘失败抛出的异常会转成 [Failed]，
 * 由调用方记日志后继续导入——脚本已下发一套可用作息，退回它比整次导入失败好。
 */
object QingyuOnlyTimeSchemesApplier {

    fun apply(
        repository: TimetableRepository,
        schemes: QingyuOnlyTimeSchemes,
        scriptSections: List<SectionTime>,
        schoolId: String,
        idFactory: () -> String = { UUID.randomUUID().toString() },
    ): QingyuOnlyApplyResult {
        val campus = schemes.campusForSections(scriptSections) ?: schemes.soleCampus
            ?: return QingyuOnlyApplyResult.Skipped("qingyu_only_campus_undetermined")

        return try {
            var fallbackSchemeId: String? = null
            val incoming = mutableListOf<LocationTimeGroup>()
            for (scheme in campus.schemes) {
                val schemeId = upsertTimeScheme(repository, scheme)
                if (scheme.isFallback) {
                    fallbackSchemeId = schemeId
                    continue
                }
                incoming.add(
                    LocationTimeGroup(
                        id = idFactory(),
                        name = scheme.name,
                        timeSchemeId = schemeId,
                        priority = incoming.size,
                        keywords = scheme.keywords,
                        // 来源标记：换校导入时据此清掉他校自动组。手建组不带标记、永不清理。
                        sourceSchoolId = schoolId,
                    ),
                )
            }
            // 解析层已保证每校区恰好一套兜底；走到这里说明数据与代码的约定脱节了。
            if (fallbackSchemeId == null) {
                return QingyuOnlyApplyResult.Skipped("qingyu_only_fallback_missing")
            }

            val merged = mergeLocationTimeGroupsForImport(
                existing = repository.snapshot.locationTimeGroups,
                incoming = incoming,
                schoolId = schoolId,
            )
            repository.updateLocationTimeGroups(merged)
            val applyError = repository.applyTimeScheme(fallbackSchemeId)
            if (applyError != null) {
                return QingyuOnlyApplyResult.Failed(applyError)
            }
            QingyuOnlyApplyResult.Applied(
                campusId = campus.id,
                schemeCount = campus.schemes.size,
                groupCount = incoming.size,
            )
        } catch (error: Exception) {
            QingyuOnlyApplyResult.Failed(error.message ?: "qingyu_only_time_scheme_write_failed")
        }
    }

    /** Dart `_upsertImportedTimeScheme`：同名模板更新节次，没有则新建。 */
    private fun upsertTimeScheme(
        repository: TimetableRepository,
        scheme: QingyuOnlyTimeScheme,
    ): String {
        val existing = repository.snapshot.timeSchemes.firstOrNull { it.name == scheme.name }
        if (existing != null) {
            val error = repository.updateTimeScheme(
                schemeId = existing.id,
                name = existing.name,
                sections = scheme.sections,
            )
            if (error != null) throw QingyuOnlyTimeSchemeWriteException(error)
            return existing.id
        }
        return repository.createTimeScheme(name = scheme.name, sections = scheme.sections).id
    }
}

/** 作息写盘被仓储拒绝（被引用/校验失败）时抛出，消息即上屏码。 */
private class QingyuOnlyTimeSchemeWriteException(code: String) : Exception(code)
