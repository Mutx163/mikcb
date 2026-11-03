package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * I2-4：宏存档（[WarehouseMacroStore] over [InMemoryKeyValueStore]）。
 *
 * 钉住的是 Dart `WarehouseMacroService` 的一致性口径：本体+索引、目录外孤儿自愈、
 * 目录坏了整份重建、读路径只在「没丢步骤」时回写脱敏结果。
 */
class WarehouseMacroStoreTest {

    private fun record(
        schoolId: String = "cqu",
        adapterId: String = "cqu-jwxt",
        steps: List<WarehouseMacroStep> = listOf(WarehouseMacroStep.click("#login")),
        updatedAt: LocalDateTime = LocalDateTime.of(2026, 11, 3, 12, 0),
    ) = WarehouseMacroRecord(
        schoolId = schoolId,
        adapterId = adapterId,
        schoolName = "示例大学",
        adapterName = "教务",
        importUrl = "https://jw.example.edu.cn/",
        schoolResourceFolder = schoolId,
        adapterAssetJsPath = "$adapterId.js",
        steps = steps,
        createdAt = updatedAt,
        updatedAt = updatedAt,
    )

    @Test
    fun `保存后按学校加适配器读回 hasMacro 为真`() {
        val store = WarehouseMacroStore(InMemoryKeyValueStore())
        assertFalse(store.hasMacro("cqu", "cqu-jwxt"))
        store.saveMacro(record())
        assertTrue(store.hasMacro("cqu", "cqu-jwxt"))
        val loaded = store.getMacro("cqu", "cqu-jwxt")
        assertNotNull(loaded)
        assertEquals("cqu", loaded?.schoolId)
        assertEquals(1, loaded?.steps?.size)
    }

    @Test
    fun `删除后本体与索引都不再有`() {
        val store = WarehouseMacroStore(InMemoryKeyValueStore())
        store.saveMacro(record())
        store.deleteMacro("cqu", "cqu-jwxt")
        assertFalse(store.hasMacro("cqu", "cqu-jwxt"))
        assertTrue(store.listEntries().isEmpty())
    }

    @Test
    fun `索引按更新时间新的在前`() {
        val store = WarehouseMacroStore(InMemoryKeyValueStore())
        store.saveMacro(record(adapterId = "old", updatedAt = LocalDateTime.of(2026, 1, 1, 0, 0)))
        store.saveMacro(record(adapterId = "new", updatedAt = LocalDateTime.of(2026, 11, 1, 0, 0)))
        assertEquals(listOf("new", "old"), store.listEntries().map { it.adapterId })
    }

    @Test
    fun `目录外孤儿本体出现在列表并触发索引回写`() {
        val kv = InMemoryKeyValueStore()
        val store = WarehouseMacroStore(kv)
        // 只写本体不进索引：模拟「本体写完、目录写失败」的半途中断。
        val orphan = record(adapterId = "orphan")
        kv.putString(WarehouseMacroRecord.storageKey(orphan.schoolId, orphan.adapterId), orphan.toJsonString())

        val entries = store.listEntries()
        assertEquals(listOf("orphan"), entries.map { it.adapterId })
        // 第二次读时索引已被修好（回写过）：直接从索引出条目。
        assertEquals(listOf("orphan"), store.listEntries().map { it.adapterId })
        assertTrue(kv.getString(WarehouseMacroRecord.INDEX_KEY)?.contains("orphan") == true)
    }

    @Test
    fun `索引坏了整份从本体重建`() {
        val kv = InMemoryKeyValueStore()
        val store = WarehouseMacroStore(kv)
        store.saveMacro(record(adapterId = "a"))
        kv.putString(WarehouseMacroRecord.INDEX_KEY, "{not a list")

        val entries = store.listEntries()
        assertEquals(listOf("a"), entries.map { it.adapterId })
    }

    @Test
    fun `读路径把敏感 fillField 脱敏后写回（没丢步骤时）`() {
        val kv = InMemoryKeyValueStore()
        val store = WarehouseMacroStore(kv)
        // 模拟旧版本写下的「带密码的 fillField」记录。
        val key = WarehouseMacroRecord.storageKey("cqu", "cqu-jwxt")
        kv.putString(
            key,
            """{"schoolId":"cqu","adapterId":"cqu-jwxt","schoolName":"s","adapterName":"a",""" +
                """"importUrl":"https://jw.example.edu.cn/","schoolResourceFolder":"cqu",""" +
                """"adapterAssetJsPath":"cqu.js","steps":[{"type":"fillField","selector":"#pwd","value":"secret","fieldType":"password"}],""" +
                """"dialogResponses":{},"createdAt":"2026-11-03T12:00:00","updatedAt":"2026-11-03T12:00:00","successfulImportCount":0}""",
        )

        val loaded = store.getMacro("cqu", "cqu-jwxt")
        // 读出来的步骤已被修复成 waitForManualInput……
        assertEquals(WarehouseMacroStepType.WAIT_FOR_MANUAL_INPUT, loaded?.steps?.single()?.type)
        // ……且盘上的原件被脱敏回写（密码不再落盘）。
        val raw = kv.getString(key).orEmpty()
        assertFalse(raw.contains("secret"))
        assertTrue(raw.contains("waitForManualInput"))
    }

    @Test
    fun `读坏了的记录回 null 不抛`() {
        val kv = InMemoryKeyValueStore()
        kv.putString(WarehouseMacroRecord.storageKey("cqu", "bad"), "{broken")
        val store = WarehouseMacroStore(kv)
        assertNull(store.getMacro("cqu", "bad"))
    }
}
