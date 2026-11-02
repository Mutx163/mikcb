package com.mutx163.qingyu.pages.about

import com.mutx163.qingyu.core.DartTime

/**
 * 支持作者页的纯结构模型（移植 `lib/screens/support_creator_screen.dart` +
 * `lib/services/support_creator_service.dart` 的数据部分，2026-10-26 快照）。
 *
 * ## 分层
 *
 * 与开源许可页同一套约定：本文件在 main 源集、**零 Compose/Miuix 依赖**
 * （main 对全变体编译，import miuix 会让 Flutter 的 prod 包编不过），
 * 只承载「JSON 解析 / 排序」；文案在 `SupportCreatorStrings.kt`，渲染在 composeP1 源集。
 */

/** 一位支持者（Dart `SupportDonorEntry`）。 */
data class SupportDonorEntry(
    val name: String,
    val amount: String? = null,
    val date: String? = null,
    val message: String? = null,
)

/** 鸣谢名单整体（Dart `SupportDonorData`）。 */
data class SupportDonorData(
    val title: String? = null,
    val subtitle: String? = null,
    val subtitleNote: String? = null,
    val updatedAt: String? = null,
    val donors: List<SupportDonorEntry> = emptyList(),
)

/**
 * Dart `SupportDonorData.fromJson` 的纯逻辑部分（去掉网络 IO）：
 *
 * 1. `donors` 只收 Map 元素（Dart `whereType<Map<String,dynamic>>()`）；
 * 2. 每个条目四个字段各自 `trim`，`name` 缺省空串；
 * 3. **name 为空的条目被丢弃**（Dart :59）；
 * 4. 按 [compareDonorDateDesc] 排序（Dart :62）；
 * 5. title/subtitle/subtitleNote/updatedAt 各自 `trim`（可为 null）。
 *
 * ⚠️ 已知口径差：Dart 用 `List.sort`（非稳定排序），Kotlin 的 `sortedWith` 是稳定排序。
 * 两条记录**排序键完全相等**时，Dart 侧的相对顺序本来就不保证，这里以稳定排序为准。
 * 有日期可比的真实数据不受影响（见测试）。
 */
fun parseSupportDonorData(json: Map<String, Any?>): SupportDonorData {
    val donors = (json["donors"] as? List<*>)
        .orEmpty()
        .filterIsInstance<Map<*, *>>()
        .map { raw ->
            @Suppress("UNCHECKED_CAST")
            val map = raw as Map<String, Any?>
            SupportDonorEntry(
                name = (map["name"] as? String)?.trim() ?: "",
                amount = (map["amount"] as? String)?.trim(),
                date = (map["date"] as? String)?.trim(),
                message = (map["message"] as? String)?.trim(),
            )
        }
        .filter { it.name.isNotEmpty() }
        .sortedWith { a, b -> compareDonorDateDesc(a, b) }

    return SupportDonorData(
        title = (json["title"] as? String)?.trim(),
        subtitle = (json["subtitle"] as? String)?.trim(),
        subtitleNote = (json["subtitleNote"] as? String)?.trim(),
        updatedAt = (json["updatedAt"] as? String)?.trim(),
        donors = donors,
    )
}

/**
 * Dart `_compareDonorDateDesc`：**新的在前**。
 *
 * 分三段（顺序即优先级）：
 * 1. 两个日期都能解析 → 按时刻倒序；
 * 2. 只有一个能解析 → 能解析的在前（`-1`/`1`）；
 * 3. 都不能解析 → 拿**原始字符串**倒序比较；只有一个非空则它在前；都空则相等。
 */
fun compareDonorDateDesc(a: SupportDonorEntry, b: SupportDonorEntry): Int {
    val dateA = parseDonorDate(a.date)
    val dateB = parseDonorDate(b.date)
    if (dateA != null && dateB != null) {
        val cmp = dateB.compareTo(dateA)
        if (cmp != 0) return cmp
    } else if (dateA != null) {
        return -1
    } else if (dateB != null) {
        return 1
    } else {
        val rawA = a.date?.trim() ?: ""
        val rawB = b.date?.trim() ?: ""
        if (rawA.isNotEmpty() && rawB.isNotEmpty()) {
            val cmp = rawB.compareTo(rawA)
            if (cmp != 0) return cmp
        } else if (rawA.isNotEmpty()) {
            return -1
        } else if (rawB.isNotEmpty()) {
            return 1
        }
    }
    return 0
}

/** Dart `DateTime.tryParse`：解析不出返回 null（空白串同 null）。 */
private fun parseDonorDate(raw: String?): java.time.LocalDateTime? {
    if (raw == null) return null
    val trimmed = raw.trim()
    if (trimmed.isEmpty()) return null
    return DartTime.tryParseIso(trimmed)
}

/** 支持方式（Dart `_SupportMethod`）。 */
enum class SupportMethod { WECHAT, ALIPAY }

