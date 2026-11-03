package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 宏进 / 出云同步快照的 warehouse 侧适配（P3 / N5）。
 *
 * 快照桥本身在 sync 域（`pages/sync`），L0 的 warehouse 模块不收它，所以这里只钉
 * [WarehouseMacroCloudSync]：载荷形状（Dart `exportAllMacros` 同形）、落库整库覆盖、
 * 坏条目丢弃。桥的「warehouse.macros 键位」由 sync 域的
 * `TimetableSnapshotBridgeMacrosTest` 钉。
 */
class WarehouseMacroCloudSyncTest {

    private fun macro(schoolId: String, adapterId: String): WarehouseMacroRecord {
        val now = LocalDateTime.parse("2026-11-03T09:00:00")
        return WarehouseMacroRecord(
            schoolId = schoolId,
            adapterId = adapterId,
            schoolName = "示例大学",
            adapterName = "教务A",
            importUrl = "http://jw.example.edu.cn/login",
            schoolResourceFolder = schoolId,
            adapterAssetJsPath = "resources/$schoolId/$adapterId.js",
            steps = listOf(WarehouseMacroStep.click("#btn")),
            createdAt = now,
            updatedAt = now,
        )
    }

    @Test
    fun `macrosProvider 产出 Dart 同形载荷`() {
        val store = WarehouseMacroStore(InMemoryKeyValueStore())
        store.saveMacro(macro("s1", "a1"))
        store.saveMacro(macro("s2", "a2"))

        val payload = WarehouseMacroCloudSync.macrosProvider(store)()

        assertEquals(2, payload.size)
        assertEquals(
            "两条都在载荷里（导出按更新时间新→旧，同一时刻不做顺序断言）",
            setOf("s1", "s2"),
            payload.map { it["schoolId"] }.toSet(),
        )
        assertTrue("载荷里必须带步骤（快照恢复靠它回放）", payload[0]["steps"] is List<*>)
    }

    @Test
    fun `macrosApplier 整库覆盖本地 旧宏被删`() {
        val store = WarehouseMacroStore(InMemoryKeyValueStore())
        store.saveMacro(macro("old", "old"))

        WarehouseMacroCloudSync.macrosApplier(store)(listOf(macro("s1", "a1").toJson()))

        assertFalse("旧宏必须被整库覆盖删掉", store.hasMacro("old", "old"))
        assertEquals(macro("s1", "a1"), store.getMacro("s1", "a1"))
    }

    @Test
    fun `macrosApplier 空载荷清空本地宏 与 Dart 一致`() {
        val store = WarehouseMacroStore(InMemoryKeyValueStore())
        store.saveMacro(macro("old", "old"))

        WarehouseMacroCloudSync.macrosApplier(store)(null)

        assertFalse("云端备份没有宏 = 这份备份就是没有宏", store.hasMacro("old", "old"))
        assertTrue(store.getAllMacroEntries().isEmpty())
    }

    @Test
    fun `坏条目丢弃 其余照常解析`() {
        // `fromJson` 本身不抛（步骤解析走诊断、时间戳走纪元兜底），真正会坏的是
        // 载荷里混进非对象项（上游历史导出 / 手改文件）。
        val parsed = WarehouseMacroCloudSync.parseSnapshotMacros(
            listOf("not-a-map", 42, macro("s1", "a1").toJson()),
        )
        assertEquals("非对象项丢弃、好宏保留", 1, parsed.size)
        assertEquals("s1", parsed[0].schoolId)
    }
}
