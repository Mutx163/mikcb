package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.core.DartTime
import com.mutx163.qingyu.core.MiniJson

/**
 * 自定义调试记录的**本地落盘**（8c 补口）。
 *
 * ## 键名与 JSON 形状逐字对齐 Dart
 *
 * 来源 `lib/services/warehouse_import_preferences_service.dart`：
 * - 键 `warehouse_custom_debug_records`（[KEY]），值是 **JSON 数组字符串**；
 * - 每条字段：`id` / `name` / `importUrl` / `script` / `createdAt` / `updatedAt`；
 * - `createdAt` / `updatedAt` 是 `DateTime.toIso8601String()` 的**本地时间**文本
 *   （`yyyy-MM-ddTHH:mm:ss.mmm`，不带时区后缀），由 [DartTime] 负责编解码。
 *
 * 迁移期 Flutter 主入口与 Compose 开发壳会读同一份存档，键名或字段名不一致就会写成
 * 两套互不相认的记录——用户改完切回去发现没了。因此**不另造私有 key**。
 *
 * ## 已知差异（不是笔误）
 *
 * Kotlin 侧 [WarehouseCustomDebugRecord] 只有 `updatedAt`、没有 `createdAt`，
 * 且地址字段叫 `customUrl`。序列化时把 `customUrl` 写进 Dart 的 `importUrl`，
 * `createdAt` 与 `updatedAt` 都写记录时间——Dart 侧读得到、能用；只是「创建时间」
 * 与「最后修改时间」在 Kotlin 里不再分开保存。要真正分开，得给记录模型加字段，
 * 那属于另一个批次（模型文件不在本刀写作用域）。
 *
 * ## 读取容错口径
 *
 * Dart 侧 [getCustomDebugRecords] 是「整份坏 → 空列表，单条坏 → 跳过」。本实现照抄：
 * 解析失败回空列表、非 Map 条目与空 id 条目跳过，绝不因为一条脏记录把整页弄崩。
 */
class WarehouseCustomDebugStore(private val store: KeyValueStore) {

    /** 读取全部记录，按 `updatedAt` 倒序（最近的在前，与 Dart 一致）。 */
    fun load(): List<WarehouseCustomDebugRecord> {
        val raw = store.getString(KEY)?.takeIf { it.isNotBlank() } ?: return emptyList()
        val decoded = MiniJson.tryParse(raw) as? List<*> ?: return emptyList()
        return decoded
            .mapNotNull(::decodeRecord)
            .sortedByDescending { it.updatedAt }
    }

    /**
     * 新增或按 id 覆盖一条记录；校验失败（名称/脚本为空）返回 false 且不落盘。
     *
     * 写完不读回：调用方（宿主）紧接着会 [load] 刷新列表，读回失败会在那里体现。
     */
    fun save(record: WarehouseCustomDebugRecord): Boolean {
        if (record.validate() != null) return false
        val next = (listOf(record) + load().filter { it.id != record.id })
            .sortedByDescending { it.updatedAt }
        store.putString(KEY, MiniJson.encode(next.map(::encodeRecord)))
        return true
    }

    /** 删除一条记录；id 不存在返回 false（调用方据此区分「删掉了」与「本来没有」）。 */
    fun delete(recordId: String): Boolean {
        val current = load()
        val next = current.filter { it.id != recordId }
        if (next.size == current.size) return false
        store.putString(KEY, MiniJson.encode(next.map(::encodeRecord)))
        return true
    }

    private fun encodeRecord(record: WarehouseCustomDebugRecord): Map<String, Any?> {
        val iso = DartTime.toIso(DartTime.fromEpochMillis(record.updatedAt))
        return linkedMapOf(
            "id" to record.id,
            "name" to record.name,
            "importUrl" to record.customUrl.orEmpty(),
            "script" to record.script,
            "createdAt" to iso,
            "updatedAt" to iso,
        )
    }

    private fun decodeRecord(value: Any?): WarehouseCustomDebugRecord? {
        val map = value as? Map<*, *> ?: return null
        val id = (map["id"] as? String)?.trim().orEmpty()
        if (id.isEmpty()) return null
        // Dart 写 `importUrl`；兼容早期原生侧可能落过的 `customUrl`。
        val importUrl = (map["importUrl"] as? String)
            ?: (map["customUrl"] as? String)
        val updatedAt = parseTimestamp(map["updatedAt"])
            ?: parseTimestamp(map["createdAt"])
            ?: 0L
        return WarehouseCustomDebugRecord(
            id = id,
            name = map["name"] as? String ?: "",
            script = map["script"] as? String ?: "",
            customUrl = importUrl?.takeIf { it.isNotBlank() },
            updatedAt = updatedAt,
        )
    }

    /** 兼容 ISO 文本（Dart 本地时间）与早期可能的数字毫秒。 */
    private fun parseTimestamp(value: Any?): Long? {
        val text = when (value) {
            is String -> value.trim()
            is Number -> return value.toLong()
            else -> return null
        }
        if (text.isEmpty()) return null
        val parsed = DartTime.tryParseIso(text) ?: return null
        return DartTime.toEpochMillis(parsed)
    }

    companion object {
        const val KEY = "warehouse_custom_debug_records"
    }
}
