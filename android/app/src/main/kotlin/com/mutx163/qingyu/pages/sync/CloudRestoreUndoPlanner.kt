package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.sync.canonicalJson
import com.mutx163.qingyu.sync.canonicalize
import com.mutx163.qingyu.sync.computeContentSha256
import com.mutx163.qingyu.sync.decodeSnapshotObject

/**
 * 云端恢复撤销的**纯逻辑**：给定「恢复前 / 恢复后 / 当前」三份快照，算出撤销该写
 * 回哪一份——只回退「仍是恢复后值」的条目，不抹掉恢复之后用户的编辑。
 *
 * ## 为什么不直接整份写回恢复前快照
 *
 * 撤销点是恢复前抓的整份现场；恢复后用户又改了课（加课 / 改时间 / 删档案），
 * 整份写回等于把恢复之后的所有编辑一起抹掉，且没有任何提示。要精确撤销就必须
 * 能回答三个问题：这条数据恢复前是什么、恢复把它写成了什么、现在是什么——
 * 三份现场按 id 比对，判据只有一处（[planUndoPayload]）。
 *
 * ## 与局域网撤销（`LanTransferUndoLogic`）的关系
 *
 * 思路同源（「仍是导入后值才回退」），但**刻意不跨域依赖**：局域网比对的是仓储
 * 平铺集合（Course/CourseTask 等强类型），云端快照是 JSON——档案内嵌课程/任务/
 * 考试/日程，需要两层合并；比对工具用 `sync/` 自己的 canonical JSON（云端快照
 * 本来就归那个域管）。判据逐条对齐 LAN 语义：
 * - 恢复**新增**的：现在值仍等于恢复后值 → 删除；已被用户改动或已缺失 → 不动；
 * - 恢复**修改**的：现在值仍等于恢复后值 → 写回恢复前值；已被改动 → 不动；
 * - 恢复**删除**的：现在仍缺失 → 写回恢复前条目；用户重建过 → 不动；
 * - 用户恢复后新建的条目（三份里只有 current 有）：一律保留。
 *
 * 无 id 的脏条目（解析不出 `id`）无法追踪归属，原样保留、不参与计数。
 */
object CloudRestoreUndoPlanner {

    /** 顶层按 id 合并的集合键。 */
    private val TOP_LIST_KEYS = listOf("profiles", "timeSchemes", "locationTimeGroups", "scheduleDateRules")

    /** 档案（profile）内部按 id 合并的集合键。 */
    private val PROFILE_LIST_KEYS = listOf("courses", "tasks", "scheduleItems", "exams")

    /** 标量键按「仍是恢复后值才回退」口径处理：顶层与档案内各一组。 */
    private val TOP_SCALAR_KEYS = listOf("settings", "activeProfileId")
    private val PROFILE_SCALAR_KEYS = listOf("settings", "currentWeek", "name")

    private data class ListMerge(val items: List<Any?>, val changed: Int)

    /**
     * 撤销要写回的完整快照字节；null = 没有任何需要回退的变更
     * （恢复本身没改动数据，或恢复的改动已被用户全部改过）。
     *
     * 拿不到当前现场（[currentBytes] 为 null，旧路径）或任一份解析失败时，
     * 保守回落「整份写回恢复前快照」（与按 id 比对出现前的行为一致）——
     * 解析失败说明快照异常，此时宁可靠向旧行为也不要猜。
     */
    fun buildUndoBytes(
        point: CloudRestoreUndoPoint,
        currentBytes: ByteArray?,
        exportedAtIso: String,
    ): ByteArray? {
        val afterBytes = point.afterBytes ?: return point.beforeBytes
        if (currentBytes == null) return point.beforeBytes
        val before = tryParse(point.beforeBytes) ?: return point.beforeBytes
        val after = tryParse(afterBytes) ?: return point.beforeBytes
        val current = tryParse(currentBytes) ?: return point.beforeBytes
        return planUndoPayload(before, after, current, exportedAtIso)
            ?.let { MiniJson.encode(it).toByteArray(Charsets.UTF_8) }
    }

    /** 三份 payload → 撤销 payload；null = 无任何需要回退的变更。 */
    fun planUndoPayload(
        before: Map<String, Any?>,
        after: Map<String, Any?>,
        current: Map<String, Any?>,
        exportedAtIso: String,
    ): Map<String, Any?>? {
        var changed = 0
        val out = LinkedHashMap<String, Any?>()

        for (key in TOP_LIST_KEYS) {
            val merged = if (key == "profiles") {
                mergeProfiles(before.list(key), after.list(key), current.list(key))
            } else {
                mergeList(before.list(key), after.list(key), current.list(key))
            }
            out[key] = merged?.items ?: current[key]
            if (merged != null) changed += merged.changed
        }

        for (key in TOP_SCALAR_KEYS) {
            val revert = shouldRevertScalar(before[key], after[key], current[key])
            if (revert) changed++
            out[key] = if (revert) before[key] else current[key]
        }

        if (changed == 0) return null

        // 信封：未知键原样带过（向前兼容），导出时间换成本次撤销时刻，哈希重算。
        for ((key, value) in current) {
            if (key in out || key == "contentSha256" || key == "exportedAt") continue
            out[key] = value
        }
        out["exportedAt"] = exportedAtIso
        out["contentSha256"] = computeContentSha256(out)
        return out
    }

    // ------------------------------------------------------------------
    // 集合合并
    // ------------------------------------------------------------------

    /** 通用按 id 三向合并：返回 null = 这一块没有任何需要回退的变更。 */
    private fun mergeList(
        before: List<Any?>,
        after: List<Any?>,
        current: List<Any?>,
        idKey: String = "id",
    ): ListMerge? {
        val beforeById = indexById(before, idKey)
        val afterById = indexById(after, idKey)
        val currentIds = HashSet<String>()
        val out = ArrayList<Any?>(current.size)
        var changed = 0

        for (item in current) {
            val id = idOf(item, idKey)
            if (id == null) {
                out.add(item)
                continue
            }
            currentIds.add(id)
            val previous = beforeById[id]
            val restored = afterById[id]
            when {
                // 恢复新增：撤掉仍保持原样的那条；用户改过或删过 → 不动。
                previous == null && restored != null ->
                    if (sameJson(restored, item)) changed++ else out.add(item)

                // 恢复修改：只还原仍保持「恢复后」值的那条。
                previous != null && restored != null &&
                    !sameJson(previous, restored) && sameJson(restored, item) -> {
                    changed++
                    out.add(previous)
                }

                // 恢复没改过 / 用户已改过：原样保留。
                else -> out.add(item)
            }
        }

        // 恢复删除的：现在仍缺失才写回；用户重建过（同 id 已存在）不动。
        for (item in before) {
            val id = idOf(item, idKey) ?: continue
            if (afterById[id] == null && id !in currentIds) {
                changed++
                out.add(item)
            }
        }

        return if (changed == 0) null else ListMerge(out, changed)
    }

    /**
     * 档案级三向合并：档案本身按通用判据走，唯有一处特化——「恢复修改过的档案、
     * 用户又动过」时不整档案放弃撤销，而是对档案**内部**（课程/任务/日程/考试 +
     * 名称/设置/当前周）再做一层同样的合并。用户的课表编辑几乎都发生在这里，
     * 不下探这一层，「撤销不抹掉恢复后的编辑」就只对档案级操作成立。
     */
    private fun mergeProfiles(
        before: List<Any?>,
        after: List<Any?>,
        current: List<Any?>,
    ): ListMerge? {
        val beforeById = indexById(before)
        val afterById = indexById(after)
        val currentIds = HashSet<String>()
        val out = ArrayList<Any?>(current.size)
        var changed = 0

        for (item in current) {
            val id = idOf(item)
            if (id == null) {
                out.add(item)
                continue
            }
            currentIds.add(id)
            val previous = beforeById[id]
            val restored = afterById[id]
            when {
                previous == null && restored != null ->
                    if (sameJson(restored, item)) changed++ else out.add(item)

                previous != null && restored != null &&
                    !sameJson(previous, restored) && sameJson(restored, item) -> {
                    changed++
                    out.add(previous)
                }

                previous != null && restored != null &&
                    !sameJson(previous, restored) -> {
                    // 档案被用户动过：内部再比一次，能撤多少撤多少。
                    val merged = mergeProfileFields(
                        before = previous as Map<String, Any?>,
                        after = restored as Map<String, Any?>,
                        current = item as Map<String, Any?>,
                    )
                    if (merged !== item) changed++
                    out.add(merged)
                }

                else -> out.add(item)
            }
        }

        for (item in before) {
            val id = idOf(item) ?: continue
            if (afterById[id] == null && id !in currentIds) {
                changed++
                out.add(item)
            }
        }

        return if (changed == 0) null else ListMerge(out, changed)
    }

    /** 单档案内部合并：四个列表 + 名称/设置/当前周；其余键（id/时间戳等）保留 current。 */
    private fun mergeProfileFields(
        before: Map<String, Any?>,
        after: Map<String, Any?>,
        current: Map<String, Any?>,
    ): Map<String, Any?> {
        val out = LinkedHashMap(current)
        var changed = false
        for (key in PROFILE_LIST_KEYS) {
            val merged = mergeList(before.list(key), after.list(key), current.list(key))
            if (merged != null) {
                out[key] = merged.items
                changed = true
            }
        }
        for (key in PROFILE_SCALAR_KEYS) {
            if (shouldRevertScalar(before[key], after[key], current[key])) {
                out[key] = before[key]
                changed = true
            }
        }
        return if (changed) out else current
    }

    // ------------------------------------------------------------------
    // 判据与工具
    // ------------------------------------------------------------------

    /** 标量回退判据：恢复确实改过它、现在仍是恢复后的值、且回退回去有实际变化。 */
    private fun shouldRevertScalar(beforeValue: Any?, afterValue: Any?, currentValue: Any?): Boolean =
        !sameJson(beforeValue, afterValue) &&
            sameJson(afterValue, currentValue) &&
            !sameJson(beforeValue, currentValue)

    private fun indexById(items: List<Any?>, idKey: String = "id"): Map<String, Any?> {
        val out = LinkedHashMap<String, Any?>()
        for (item in items) {
            val id = idOf(item, idKey) ?: continue
            out[id] = item
        }
        return out
    }

    private fun idOf(item: Any?, idKey: String = "id"): String? =
        (item as? Map<*, *>)?.get(idKey) as? String

    private fun sameJson(left: Any?, right: Any?): Boolean =
        canonicalJson(canonicalize(left)) == canonicalJson(canonicalize(right))

    private fun Map<String, Any?>.list(key: String): List<Any?> = this[key] as? List<Any?> ?: emptyList()

    private fun tryParse(bytes: ByteArray): Map<String, Any?>? = try {
        decodeSnapshotObject(String(bytes, Charsets.UTF_8))
    } catch (_: Exception) {
        null
    }
}
