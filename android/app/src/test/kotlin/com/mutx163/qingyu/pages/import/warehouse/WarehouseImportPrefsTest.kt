package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * 教务导入本机偏好（[WarehouseImportPrefs]）单测。
 *
 * 钉三件事：
 * 1. **键名与 Dart 逐字一致**（`warehouse_custom_import_url_<id>` / `warehouse_recent_school_ids`）——
 *    不一致就会跟 Flutter 主入口写成两套互不相认的偏好；
 * 2. 空白地址等于清除（Dart `setCustomImportUrl` 的 trim 口径）；
 * 3. 「最近使用」去重、最近在前、有上限。
 */
class WarehouseImportPrefsTest {

    @Test
    fun `自定义地址按 Dart 键名落盘并可读回`() {
        val store = InMemoryKeyValueStore()
        val prefs = WarehouseImportPrefs(store)

        assertNull("没填过必须是 null，不能是空串", prefs.customImportUrl("zf"))

        prefs.putCustomImportUrl("zf", "  https://jw.example.edu.cn/login  ")
        assertEquals("https://jw.example.edu.cn/login", prefs.customImportUrl("zf"))
        // 键名逐字对齐 Dart：warehouse_custom_import_url_<adapterId>
        assertEquals(
            "https://jw.example.edu.cn/login",
            store.getString("warehouse_custom_import_url_zf"),
        )
    }

    @Test
    fun `存空白地址等于清除 清除后读回 null`() {
        val prefs = WarehouseImportPrefs(InMemoryKeyValueStore())
        prefs.putCustomImportUrl("zf", "https://a.example/")
        prefs.putCustomImportUrl("zf", "   ")

        assertNull(prefs.customImportUrl("zf"))

        prefs.putCustomImportUrl("zf", "https://b.example/")
        prefs.clearCustomImportUrl("zf")
        assertNull(prefs.customImportUrl("zf"))
    }

    @Test
    fun `最近使用去重 最近的在前 且有上限`() {
        val store = InMemoryKeyValueStore()
        val prefs = WarehouseImportPrefs(store)

        assertEquals(emptyList<String>(), prefs.recentSchoolIds())

        prefs.recordRecentSchool("a")
        prefs.recordRecentSchool("b")
        assertEquals(listOf("b", "a"), prefs.recentSchoolIds())

        // 重复进入同一所学校不能刷出重复项，但要提到最前
        prefs.recordRecentSchool("a")
        assertEquals(listOf("a", "b"), prefs.recentSchoolIds())

        for (index in 0 until 12) {
            prefs.recordRecentSchool("s$index")
        }
        val ids = prefs.recentSchoolIds()
        assertEquals(WarehouseImportPrefs.MAX_RECENT_SCHOOLS, ids.size)
        assertEquals("s11", ids.first())
        assertEquals("最近使用要留在 Dart 那个键上", ids, store.getStringList("warehouse_recent_school_ids"))
    }

    @Test
    fun `空白学校 id 不入账`() {
        val prefs = WarehouseImportPrefs(InMemoryKeyValueStore())
        prefs.recordRecentSchool("   ")
        assertEquals(emptyList<String>(), prefs.recentSchoolIds())
    }
}
