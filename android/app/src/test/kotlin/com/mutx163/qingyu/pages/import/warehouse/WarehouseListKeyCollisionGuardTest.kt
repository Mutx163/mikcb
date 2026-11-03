package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 教务导入两条列表的「坏数据不崩、该条被跳过」守卫。
 *
 * 背景（2026-11-03 真机闪退）：选校页 / 适配器页的 LazyColumn 都用
 * `items(key = { id })`，同一 id 出现两次 ⇒ `IllegalArgumentException: Key …
 * was already used`，整页闪退。 Flutter 的 ListView 不用 key，同一份坏数据在
 * Flutter 端只是多渲染一行，所以这个洞在迁移前从不暴露。
 *
 * 三个入数口各钉一条「保首次、丢后续」：
 * 1. [schoolsToBeans]：最近使用列表可能带重复 id（云恢复原样直写、不去重）；
 * 2. [parseWarehouseRootIndex]：根索引手写 + CI 合并，可能出重复学校 id；
 * 3. [parseWarehouseAdaptersIndex]：适配器索引同理。
 *
 * 以及最近列表的**类型坏值**：解码失败留档自愈回空表，不照抛炸宿主协程。
 */
class WarehouseListKeyCollisionGuardTest {

    // -------------------------------------------------------------------
    // 1. 最近使用列表带重复 id：★ 组不得出现同一所学校两次
    // -------------------------------------------------------------------

    @Test
    fun `最近使用列表有重复id 学校在列表里只出现一次`() {
        val schools = listOf(
            WarehouseSchoolEntry(id = "BUPT", name = "北京邮电大学", initial = "B", resourceFolder = "BUPT"),
            WarehouseSchoolEntry(id = "zhengfang_jiaowu", name = "正方教务-通用教务", initial = "Z"),
        )
        // 云恢复原样直写可能落下的形状：同一 id 出现多次。
        val beans = schoolsToBeans(schools, listOf("BUPT", "BUPT", "zhengfang_jiaowu", "BUPT"))

        val ids = beans.map { it.school.id }
        assertEquals("坏数据必须被跳过，而不是让整页崩", listOf("BUPT", "zhengfang_jiaowu"), ids)

        // 分组后同一 tag 段内也不得有重复（items(key = school.id) 的直接输入）。
        val sectionedIds = schoolsToSections(beans).flatMap { section -> section.items.map { it.school.id } }
        assertEquals(ids.size, sectionedIds.distinct().size)
    }

    @Test
    fun `最近使用引用不存在的学校 跳过该条不崩`() {
        val schools = listOf(
            WarehouseSchoolEntry(id = "BUPT", name = "北京邮电大学", initial = "B", resourceFolder = "BUPT"),
        )
        val beans = schoolsToBeans(schools, listOf("GHOST_SCHOOL", "BUPT"))
        assertEquals(listOf("BUPT"), beans.map { it.school.id })
    }

    // -------------------------------------------------------------------
    // 2. 根索引重复学校 id：保首次
    // -------------------------------------------------------------------

    @Test
    fun `根索引有重复学校id 解析保首次丢后续`() {
        val yaml = """
            schools:
              - id: "DUP_U"
                name: "重复大学"
                initial: "D"
                resource_folder: "DUP_U"

              - id: "OTHER"
                name: "另一所大学"
                initial: "O"
                resource_folder: "OTHER"

              - id: "DUP_U"
                name: "重复大学（CI 合并出来的第二条）"
                initial: "D"
                resource_folder: "DUP_U"
        """.trimIndent()

        val index = parseWarehouseRootIndex(yaml)

        assertEquals(listOf("DUP_U", "OTHER"), index.schools.map { it.id })
        assertEquals("保的是首次那条", "重复大学", index.schools.first().name)
    }

    // -------------------------------------------------------------------
    // 3. 适配器索引重复 adapter_id：保首次
    // -------------------------------------------------------------------

    @Test
    fun `适配器索引有重复adapter_id 解析保首次丢后续`() {
        val school = WarehouseSchoolEntry(id = "DUP_U", name = "重复大学", initial = "D", resourceFolder = "DUP_U")
        val yaml = """
            adapters:
              - adapter_id: "dup_adapter"
                adapter_name: "首次登记的适配器"
                asset_js_path: "dup_adapter.js"

              - adapter_id: "normal_adapter"
                adapter_name: "正常适配器"
                asset_js_path: "normal.js"

              - adapter_id: "dup_adapter"
                adapter_name: "合并冲突残留的第二条"
                asset_js_path: "dup_adapter_v2.js"
        """.trimIndent()

        val index = parseWarehouseAdaptersIndex(yaml, school)

        assertEquals(listOf("dup_adapter", "normal_adapter"), index.adapters.map { it.id })
        assertEquals("保的是首次那条", "dup_adapter.js", index.adapters.first().script)
    }

    // -------------------------------------------------------------------
    // 4. 最近列表值类型坏掉：留档自愈回空表，不抛
    // -------------------------------------------------------------------

    @Test
    fun `最近列表值解码失败 留档自愈回空表`() {
        val store = InMemoryKeyValueStore()
        val prefs = WarehouseImportPrefs(store)
        // 不是合法的 Flutter StringList 编码（缺 LIST_PREFIX）——旧版本/坏快照可能留下的形状。
        store.putString(WarehouseImportPrefs.RECENT_SCHOOL_IDS_KEY, "not-a-flutter-string-list")

        assertEquals(emptyList<String>(), prefs.recentSchoolIds())

        // 坏值必须留档（与 TimetableStore 同一口径），不是无声消失：主键移除 + 留档在盘。
        assertNull("坏掉的主键要被移除", store.getString(WarehouseImportPrefs.RECENT_SCHOOL_IDS_KEY))
        val backupKeys = store.rawSnapshot().keys.filter { it.contains("warehouse_recent_school_ids_corrupt_backup_") }
        assertTrue("盘上要有一份 _corrupt_backup_ 留档", backupKeys.isNotEmpty())

        // 自愈后页面照常可用：重新记录能正常读写。
        prefs.recordRecentSchool("BUPT")
        assertEquals(listOf("BUPT"), prefs.recentSchoolIds())
    }

    @Test
    fun `最近列表键不存在仍是空表 不是留档`() {
        val store = InMemoryKeyValueStore()
        val prefs = WarehouseImportPrefs(store)

        assertEquals(emptyList<String>(), prefs.recentSchoolIds())
        assertTrue(store.rawSnapshot().isEmpty())
    }
}
