package com.mutx163.qingyu.pages.import.warehouse

/**
 * 宏进 / 出云同步快照的 warehouse 侧适配（P3 / N5）。
 *
 * 快照桥（[com.mutx163.qingyu.pages.sync.TimetableSnapshotBridge]）在 sync 域，
 * **不能反向 import warehouse**（否则 `-Module pages/sync` 的 L0 编不过），所以它只收
 * `List<Map<String, Any?>>`、只回传原始列表。这里做两件事：
 *
 * 1. `macrosProvider(store)`：给 [com.mutx163.qingyu.pages.sync.CloudSyncController] 的
 *    `warehouseMacrosProvider` 用，产出 `record.toJson()` 列表（Dart `exportAllMacros`
 *    的载荷形状）；
 * 2. `macrosApplier(store)`：给 `warehouseMacrosApplier` 用，把快照里的原始列表
 *    宽松解析成记录后**整库覆盖**本地宏（Dart `importAllMacros` 语义）。
 */
object WarehouseMacroCloudSync {

    /** 上传侧载荷：已存宏按 `toJson()` 编码（键位与 Dart 一致）。 */
    fun macrosProvider(store: WarehouseMacroStore): () -> List<Map<String, Any?>> = {
        store.exportAllMacros().map { it.toJson() }
    }

    /** 恢复侧落库：原始 `warehouse.macros`（可能 null）→ 宽松解析 → 整库覆盖。 */
    fun macrosApplier(store: WarehouseMacroStore): (Any?) -> Unit = { raw ->
        store.importAllMacros(parseSnapshotMacros(raw))
    }

    /**
     * 宽松解析宏条目（Dart `_parseOptionalList`）：非 Map / 解析抛错的整条丢弃。
     *
     * 与 `parseLenient` 同口径：一条坏宏不能炸掉整份课表恢复。
     */
    internal fun parseSnapshotMacros(raw: Any?): List<WarehouseMacroRecord> {
        val list = raw as? List<*> ?: return emptyList()
        val out = ArrayList<WarehouseMacroRecord>(list.size)
        for (item in list) {
            if (item !is Map<*, *>) continue
            try {
                out.add(WarehouseMacroRecord.fromJson(item))
            } catch (_: Exception) {
                // 坏条目丢弃
            }
        }
        return out
    }
}
