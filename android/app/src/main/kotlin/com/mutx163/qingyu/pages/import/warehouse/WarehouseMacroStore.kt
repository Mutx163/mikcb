package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.core.MiniJson
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * 宏录制记录的**本机持久化**（I2-4；逐字对齐 Dart `lib/services/warehouse_macro_service.dart`）。
 *
 * ## 与 Dart 共享同一份存档
 *
 * 键名逐字一致（`warehouse_macro_record_<schoolId>_<adapterId>` + 索引
 * `warehouse_macro_record_index`），迁移期 Flutter/Compose 两个界面读同一份宏；
 * JSON 形状见 [WarehouseMacroRecord]。
 *
 * ## 索引与本体的一致性口径（Dart 原义，别简化）
 *
 * - 当前目录 = 目录文件 ∪ 目录里漏掉的记录本体：覆盖「本体写完、目录写失败」的中断
 *   （进程被杀/存储异常），宏还在但没进目录时用户两头对不上；
 * - 目录坏了（坏 JSON/不是数组）则整份从本体重建；
 * - 读出出入才把修好的目录写回（只在真有出入时付出解码与一次落盘）；
 * - 读路径的回写只为**脱敏**（洗掉旧记录里存过的密码）：只在「没丢步骤」时写回，
 *   丢步骤的记录原样留在盘上（写回等于把「用户录的宏少了几步」永久存盘）。
 */
class WarehouseMacroStore(private val store: KeyValueStore) {

    /** 保存宏录制记录（本体 + 索引）。 */
    fun saveMacro(record: WarehouseMacroRecord) {
        store.putString(WarehouseMacroRecord.storageKey(record.schoolId, record.adapterId), record.toJsonString())
        addToIndex(record.schoolId, record.adapterId, record.updatedAt)
    }

    /** 读指定学校+适配器的宏；没有/读坏了回 null。 */
    fun getMacro(schoolId: String, adapterId: String): WarehouseMacroRecord? {
        val key = WarehouseMacroRecord.storageKey(schoolId, adapterId)
        val raw = store.getString(key)
        if (raw.isNullOrEmpty()) return null
        val decoded = MiniJson.tryParse(raw) as? Map<*, *> ?: return null
        val record = try {
            WarehouseMacroRecord.fromJson(decoded)
        } catch (_: Exception) {
            return null
        }
        val sanitizedRaw = record.toJsonString()
        if (sanitizedRaw != raw) {
            // 只在没有真丢步骤时才把脱敏结果写回（见文件头口径）。
            val dropped = parseWarehouseMacroStepsWithDiagnostics(decoded["steps"]).droppedStepCount
            if (dropped == 0) {
                store.putString(key, sanitizedRaw)
            }
        }
        return record
    }

    fun hasMacro(schoolId: String, adapterId: String): Boolean =
        store.contains(WarehouseMacroRecord.storageKey(schoolId, adapterId))

    fun deleteMacro(schoolId: String, adapterId: String) {
        store.remove(WarehouseMacroRecord.storageKey(schoolId, adapterId))
        removeFromIndex(schoolId, adapterId)
    }

    /** 全部索引条目（含目录外孤儿本体），按更新时间新的在前。 */
    fun listEntries(): List<WarehouseMacroIndexEntry> {
        val current = currentIndexEntries()
        if (current.shouldPersist) {
            persistIndex(current.entries)
        }
        return current.entries.sortedByDescending { it.updatedAt }
    }

    fun count(): Int = listEntries().size

    private fun addToIndex(schoolId: String, adapterId: String, updatedAt: LocalDateTime) {
        val existing = currentIndexEntries().entries
        val updated = listOf(WarehouseMacroIndexEntry(schoolId, adapterId, updatedAt)) +
            existing.filter { it.schoolId != schoolId || it.adapterId != adapterId }
        persistIndex(updated)
    }

    private fun removeFromIndex(schoolId: String, adapterId: String) {
        val updated = currentIndexEntries().entries
            .filter { it.schoolId != schoolId || it.adapterId != adapterId }
        persistIndex(updated)
    }

    /** 解析目录。**null 表示目录读坏了**（坏 JSON、不是数组），与「目录是空的」必须区分开。 */
    private fun parseIndexEntries(raw: String?): List<WarehouseMacroIndexEntry>? {
        if (raw.isNullOrEmpty()) return emptyList()
        val decoded = MiniJson.tryParse(raw) as? List<*> ?: return null
        return decoded.mapNotNull { entry ->
            (entry as? Map<*, *>)?.let { map ->
                val schoolId = map["schoolId"] as? String ?: ""
                val adapterId = map["adapterId"] as? String ?: ""
                if (schoolId.isEmpty() || adapterId.isEmpty()) {
                    null
                } else {
                    WarehouseMacroIndexEntry(schoolId, adapterId, parseIso(map["updatedAt"] as? String))
                }
            }
        }
    }

    /** 从单个记录本体取目录条目；本体读不动就返回 null（不删它，只是列不出来）。 */
    private fun entryFromRecordBlob(key: String): WarehouseMacroIndexEntry? {
        val raw = store.getString(key)
        if (raw.isNullOrEmpty()) return null
        val decoded = MiniJson.tryParse(raw) as? Map<*, *> ?: return null
        val record = try {
            WarehouseMacroRecord.fromJson(decoded)
        } catch (_: Exception) {
            return null
        }
        if (record.schoolId.isEmpty() || record.adapterId.isEmpty()) return null
        return WarehouseMacroIndexEntry(record.schoolId, record.adapterId, record.updatedAt)
    }

    /** 记录本体的 key 集合。注意 [WarehouseMacroRecord.INDEX_KEY] 同前缀，必须排掉。 */
    private fun recordBlobKeys(listed: Set<String>): List<String> =
        store.keys().filter { key ->
            key.startsWith(WarehouseMacroRecord.RECORD_KEY_PREFIX) &&
                key != WarehouseMacroRecord.INDEX_KEY &&
                key !in listed
        }

    private data class IndexSnapshot(val entries: List<WarehouseMacroIndexEntry>, val shouldPersist: Boolean)

    private fun currentIndexEntries(): IndexSnapshot {
        val parsed = parseIndexEntries(store.getString(WarehouseMacroRecord.INDEX_KEY))
        if (parsed == null) {
            val rebuilt = store.keys()
                .filter { it.startsWith(WarehouseMacroRecord.RECORD_KEY_PREFIX) && it != WarehouseMacroRecord.INDEX_KEY }
                .mapNotNull { entryFromRecordBlob(it) }
            return IndexSnapshot(rebuilt, rebuilt.isNotEmpty())
        }
        val listed = parsed.map { WarehouseMacroRecord.storageKey(it.schoolId, it.adapterId) }.toSet()
        val orphans = recordBlobKeys(listed).mapNotNull { entryFromRecordBlob(it) }
        return IndexSnapshot(parsed + orphans, orphans.isNotEmpty())
    }

    private fun persistIndex(entries: List<WarehouseMacroIndexEntry>) {
        store.putString(
            WarehouseMacroRecord.INDEX_KEY,
            MiniJson.encode(entries.map { it.toJson() }),
        )
    }

    private fun parseIso(text: String?): LocalDateTime =
        text?.let { runCatching { LocalDateTime.parse(it, DateTimeFormatter.ISO_LOCAL_DATE_TIME) }.getOrNull() }
            ?: LocalDateTime.of(1970, 1, 1, 0, 0)
}

/** 宏索引条目（轻量，只存 key 和更新时间）。 */
data class WarehouseMacroIndexEntry(
    val schoolId: String,
    val adapterId: String,
    val updatedAt: LocalDateTime,
) {
    fun toJson(): Map<String, Any?> = linkedMapOf(
        "schoolId" to schoolId,
        "adapterId" to adapterId,
        "updatedAt" to updatedAt.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME),
    )
}
