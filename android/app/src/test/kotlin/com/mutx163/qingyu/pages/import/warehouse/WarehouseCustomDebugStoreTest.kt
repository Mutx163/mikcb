package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.core.DartTime
import com.mutx163.qingyu.core.MiniJson
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 自定义调试记录本地存储（[WarehouseCustomDebugStore]）单测。
 *
 * 钉四件事：
 * 1. 键名与 JSON 字段逐字对齐 Dart（`warehouse_custom_debug_records` / `importUrl` /
 *    `createdAt` / `updatedAt`）——不一致就会和 Flutter 主入口写成两套互不相认的记录；
 * 2. 保存同 id 是覆盖不是追加，列表按修改时间倒序；
 * 3. 删除真实生效，删不存在的 id 返回 false；
 * 4. 脏数据（整份坏 / 单条坏）不抛错、不拖垮整页。
 */
class WarehouseCustomDebugStoreTest {

    private fun record(
        id: String,
        name: String = "调试记录",
        script: String = "console.log(1)",
        customUrl: String? = "https://jw.example.edu.cn/login",
        updatedAt: Long = 1_700_000_000_000L,
    ) = WarehouseCustomDebugRecord(
        id = id,
        name = name,
        script = script,
        customUrl = customUrl,
        updatedAt = updatedAt,
    )

    @Test
    fun `落盘键名与 JSON 字段与 Dart 逐字一致`() {
        val raw = InMemoryKeyValueStore()
        val store = WarehouseCustomDebugStore(raw)
        val saved = record(id = "rec-1")

        assertTrue(store.save(saved))

        val json = raw.getString("warehouse_custom_debug_records")
        requireNotNull(json)
        val item = (MiniJson.parse(json) as List<*>).single() as Map<*, *>
        assertEquals("rec-1", item["id"])
        assertEquals("调试记录", item["name"])
        assertEquals("https://jw.example.edu.cn/login", item["importUrl"])
        assertEquals("console.log(1)", item["script"])
        assertEquals(
            DartTime.toIso(DartTime.fromEpochMillis(saved.updatedAt)),
            item["updatedAt"],
        )
        // Dart 的模型有 createdAt：Kotlin 模型没有这个字段，写记录时间保证 Dart 能读。
        assertEquals(item["updatedAt"], item["createdAt"])
    }

    @Test
    fun `保存后可读回 按修改时间倒序 同 id 覆盖不重复`() {
        val store = WarehouseCustomDebugStore(InMemoryKeyValueStore())
        store.save(record(id = "a", updatedAt = 100))
        store.save(record(id = "b", updatedAt = 200))
        assertEquals(listOf("b", "a"), store.load().map { it.id })

        store.save(record(id = "a", name = "改过的名字", updatedAt = 300))
        val loaded = store.load()
        assertEquals(listOf("a", "b"), loaded.map { it.id })
        assertEquals(2, loaded.size)
        assertEquals("改过的名字", loaded.first().name)
        assertEquals("https://jw.example.edu.cn/login", loaded.first().customUrl)
    }

    @Test
    fun `删除真实生效 删不存在的 id 返回 false`() {
        val store = WarehouseCustomDebugStore(InMemoryKeyValueStore())
        store.save(record(id = "a"))
        store.save(record(id = "b"))

        assertTrue(store.delete("a"))
        assertEquals(listOf("b"), store.load().map { it.id })
        assertFalse(store.delete("a"))
    }

    @Test
    fun `整份坏数据回空列表 单条坏数据跳过`() {
        val broken = WarehouseCustomDebugStore(
            InMemoryKeyValueStore(mapOf("warehouse_custom_debug_records" to "{not json")),
        )
        assertTrue(broken.load().isEmpty())

        val mixed = WarehouseCustomDebugStore(
            InMemoryKeyValueStore(
                mapOf(
                    "warehouse_custom_debug_records" to (
                        "[{\"id\":\"ok\",\"name\":\"能用\",\"importUrl\":\"\",\"script\":\"s\"," +
                            "\"updatedAt\":\"2026-01-03T04:05:06.000\"}," +
                            "{\"name\":\"没有 id\"}]"
                        ),
                ),
            ),
        )
        val loaded = mixed.load()
        assertEquals(listOf("ok"), loaded.map { it.id })
        assertNull("空 importUrl 要回 null 而不是空串", loaded.single().customUrl)
    }

    @Test
    fun `读得懂 Dart 写的记录`() {
        val store = WarehouseCustomDebugStore(
            InMemoryKeyValueStore(
                mapOf(
                    "warehouse_custom_debug_records" to (
                        "[{\"id\":\"d1\",\"name\":\"Dart 记录\",\"importUrl\":\"https://a.example/\"," +
                            "\"script\":\"s\"," +
                            "\"createdAt\":\"2026-01-02T03:04:05.000\"," +
                            "\"updatedAt\":\"2026-01-03T04:05:06.000\"}]"
                        ),
                ),
            ),
        )
        val rec = store.load().single()
        assertEquals("d1", rec.id)
        assertEquals("https://a.example/", rec.customUrl)
        assertEquals(
            DartTime.toEpochMillis(LocalDateTime.of(2026, 1, 3, 4, 5, 6)),
            rec.updatedAt,
        )
    }

    @Test
    fun `名称或脚本为空拒绝落盘`() {
        val store = WarehouseCustomDebugStore(InMemoryKeyValueStore())
        assertFalse(store.save(record(id = "a", name = "   ")))
        assertFalse(store.save(record(id = "b", script = "  ")))
        assertTrue(store.load().isEmpty())
    }
}
