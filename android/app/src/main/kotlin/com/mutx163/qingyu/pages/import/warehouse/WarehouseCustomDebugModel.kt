package com.mutx163.qingyu.pages.import.warehouse

import java.util.UUID

/**
 * 自定义脚本调试记录。
 */
data class WarehouseCustomDebugRecord(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val script: String,
    val customUrl: String? = null,
    val updatedAt: Long = System.currentTimeMillis(),
) {
    val scriptLength: Int get() = script.length

    fun validate(): String? {
        if (name.trim().isEmpty()) return WarehouseStrings.debugRecordNameRequired.key
        if (script.trim().isEmpty()) return WarehouseStrings.debugScriptRequired.key
        return null
    }
}

/**
 * 自定义调试记录状态管理器。
 */
class WarehouseCustomDebugManager(
    initialRecords: List<WarehouseCustomDebugRecord> = emptyList(),
) {
    private val _records = initialRecords.toMutableList()
    val records: List<WarehouseCustomDebugRecord> get() = _records.toList()

    fun addRecord(record: WarehouseCustomDebugRecord): Boolean {
        if (record.validate() != null) return false
        _records.removeAll { it.id == record.id }
        _records.add(0, record)
        return true
    }

    fun updateRecord(record: WarehouseCustomDebugRecord): Boolean {
        if (record.validate() != null) return false
        val index = _records.indexOfFirst { it.id == record.id }
        if (index >= 0) {
            _records[index] = record
            return true
        }
        return false
    }

    fun deleteRecord(recordId: String): Boolean {
        return _records.removeIf { it.id == recordId }
    }

    fun findById(recordId: String): WarehouseCustomDebugRecord? {
        return _records.find { it.id == recordId }
    }
}
