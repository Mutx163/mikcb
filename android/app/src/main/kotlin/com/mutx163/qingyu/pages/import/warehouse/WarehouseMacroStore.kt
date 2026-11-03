package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.core.MiniJson
import java.time.LocalDateTime

/**
 * 宏录制的持久化服务（P1 / N5）。
 *
 * 底层是 [KeyValueStore]（生产实现 `PrefsKeyValueStore`，物理上就是 Dart
 * `shared_preferences` 的同一份文件）。**键名与 Dart 逐字一致**（D1 拍板：同键共读，
 * 迁移期 Flutter 主入口与 Compose 壳互认同一批宏）：
 * - 本体键：`warehouse_macro_record_<schoolId>_<adapterId>`
 * - 索引键：`warehouse_macro_record_index`
 *
 * 对齐 Dart `warehouse_macro_service.dart` 的四个关键行为：
 * 1. **读路径脱敏回写**：重新编码结果与原文不同时写回，但**仅当没丢过步骤**——
 *    否则「解析丢步骤」会被永久落盘（升级 App 也回不来）；
 * 2. **索引 = 目录文件 ∪ 目录外孤儿本体**：覆盖「本体写完、目录写失败」的半途中断；
 *    目录读坏整份从本体重建；
 * 3. **`recordSuccessfulImport` 绝不抛出**：调用点在「导入已成功」之后，任何存储
 *    异常不能把成功翻成失败；
 * 4. 写入后通知同步层（Dart `notifyUserDataChangedForSync`）——Kotlin 侧同步钩子
 *    尚未接线（P3 的 export/importAllMacros 一并接），本期先不引入。
 *
 * 线程约定：方法本身无锁；宿主从 `Dispatchers.IO` 调用（与 [WarehouseImportPrefs] 同口径）。
 */
class WarehouseMacroStore(private val store: KeyValueStore) {

    /** 保存宏录制记录（写本体 + 更新索引）。 */
    fun saveMacro(record: WarehouseMacroRecord) {
        val key = WarehouseMacroRecord.storageKey(record.schoolId, record.adapterId)
        store.putString(key, record.encode())
        addToIndex(record.schoolId, record.adapterId)
    }

    /**
     * 加载指定学校 + 适配器的宏录制记录；没有或读坏返回 null（不抛）。
     * 读路径顺手脱敏回写，回写带「没丢过步骤」的闸（见类注释第 1 条）。
     */
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
        val sanitizedRaw = record.encode()
        if (sanitizedRaw != raw) {
            val droppedStepCount = parseWarehouseMacroStepsWithDiagnostics(decoded["steps"]).droppedStepCount
            if (droppedStepCount == 0) {
                store.putString(key, sanitizedRaw)
            }
        }
        return record
    }

    /** 是否存在宏录制记录（直接查本体，与 Dart `hasMacro` 同口径）。 */
    fun hasMacro(schoolId: String, adapterId: String): Boolean =
        store.contains(WarehouseMacroRecord.storageKey(schoolId, adapterId))

    /** 删除宏录制记录（本体 + 索引条目）。 */
    fun deleteMacro(schoolId: String, adapterId: String) {
        store.remove(WarehouseMacroRecord.storageKey(schoolId, adapterId))
        removeFromIndex(schoolId, adapterId)
    }

    /**
     * 导入成功后的记账：累加成功次数并把最新的脚本页地址存回。
     * **绝不抛出**——导入已经成功了，这里出错最多让计数停在旧值（返回 false）。
     */
    fun recordSuccessfulImport(
        schoolId: String,
        adapterId: String,
        scriptPageUrl: String? = null,
    ): Boolean {
        return try {
            val existing = getMacro(schoolId, adapterId) ?: return false
            saveMacro(
                existing.copyWith(
                    successfulImportCount = existing.successfulImportCount + 1,
                    updatedAt = LocalDateTime.now(),
                    scriptPageUrl = scriptPageUrl,
                ),
            )
            true
        } catch (_: Exception) {
            false
        }
    }

    /**
     * 全部宏的索引条目，按更新时间**新→旧**排序。
     * 目录坏了或漏了条目时顺手把修好的目录落盘（下次读不用再扫本体）。
     */
    fun getAllMacroEntries(): List<WarehouseMacroIndexEntry> {
        val (entries, shouldPersist) = currentIndexEntries()
        val sorted = entries.sortedByDescending { it.updatedAt }
        if (shouldPersist) {
            persistIndex(sorted)
        }
        return sorted
    }

    // -----------------------------------------------------------------------
    // 索引
    // -----------------------------------------------------------------------

    /**
     * 解析目录。返回 null 表示**目录读坏了**（坏 JSON、不是数组），与「目录是空的」
     * 必须区分：前者整份从本体重建；后者被当成前者时，下一次保存会把「只剩自己
     * 这一条」的目录写回去，别的宏从此列不出来也导不出去。
     */
    private fun parseIndexEntries(raw: String?): List<WarehouseMacroIndexEntry>? {
        if (raw.isNullOrEmpty()) return emptyList()
        val decoded = MiniJson.tryParse(raw) as? List<*> ?: return null
        val out = ArrayList<WarehouseMacroIndexEntry>()
        for (item in decoded) {
            val map = item as? Map<*, *> ?: continue
            val entry = try {
                WarehouseMacroIndexEntry.fromJson(map)
            } catch (_: Exception) {
                continue
            }
            if (entry.schoolId.isNotEmpty() && entry.adapterId.isNotEmpty()) {
                out.add(entry)
            }
        }
        return out
    }

    /** 从单个记录本体取目录条目；本体读不动返回 null（不删它，只是列不出来）。 */
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

    /** 记录本体的 key 集合。注意 [WarehouseMacroRecord.INDEX_KEY] 也以同一前缀开头，必须排掉。 */
    private fun recordBlobKeys(listed: Set<String>): List<String> =
        store.keys().filter { key ->
            key.startsWith(WarehouseMacroRecord.RECORD_KEY_PREFIX) &&
                key != WarehouseMacroRecord.INDEX_KEY &&
                key !in listed
        }

    /**
     * 当前目录 = 目录文件 ∪ 目录里漏掉的记录本体；目录坏了则整份从本体重建。
     * `shouldPersist` = 这次读出了出入，值得把修好的目录写回去（只在真有出入时
     * 才付出解码与一次落盘）。
     */
    private fun currentIndexEntries(): Pair<List<WarehouseMacroIndexEntry>, Boolean> {
        val parsed = parseIndexEntries(store.getString(WarehouseMacroRecord.INDEX_KEY))
        if (parsed == null) {
            val rebuilt = recordBlobKeys(emptySet())
                .mapNotNull { entryFromRecordBlob(it) }
            return Pair(rebuilt, rebuilt.isNotEmpty())
        }
        val listed = parsed
            .map { WarehouseMacroRecord.storageKey(it.schoolId, it.adapterId) }
            .toSet()
        val orphans = recordBlobKeys(listed).mapNotNull { entryFromRecordBlob(it) }
        return Pair(parsed + orphans, orphans.isNotEmpty())
    }

    private fun addToIndex(schoolId: String, adapterId: String) {
        val existing = currentIndexEntries().first
        val updated = listOf(WarehouseMacroIndexEntry(schoolId, adapterId, LocalDateTime.now())) +
            existing.filter { it.schoolId != schoolId || it.adapterId != adapterId }
        persistIndex(updated)
    }

    private fun removeFromIndex(schoolId: String, adapterId: String) {
        val existing = currentIndexEntries().first
        persistIndex(existing.filter { it.schoolId != schoolId || it.adapterId != adapterId })
    }

    private fun persistIndex(entries: List<WarehouseMacroIndexEntry>) {
        store.putString(
            WarehouseMacroRecord.INDEX_KEY,
            MiniJson.encode(entries.map { it.toJson() }),
        )
    }
}
