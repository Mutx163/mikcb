package com.mutx163.qingyu.pages.import

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 随机配色偏好 store 的行为测试（F07 · 2026-10-29）。
 *
 * 钉三件事：
 * 1. **键名与 Dart 逐字一致**（`import_random_color_preferences.dart:11/44/57`）——
 *    键漂了，正式包换 Compose 后读不到用户已在 Flutter 侧设过的偏好；
 * 2. **默认值**：开关默认 **true**、组默认 `all`、文字色默认 false；
 * 3. **未知组 id 原样返回**（兜底成全量色板由 `ImportSharedModel` 负责，不在这里改写）。
 */
class ImportRandomColorStoreTest {

    @Test
    fun `键名与 Dart 逐字一致`() {
        assertEquals("import_random_course_colors_enabled", ImportRandomColorStore.KEY_ENABLED)
        assertEquals("import_random_course_color_group", ImportRandomColorStore.KEY_GROUP)
        assertEquals(
            "import_random_course_text_color_enabled",
            ImportRandomColorStore.KEY_TEXT_COLOR_ENABLED,
        )
    }

    @Test
    fun `盘上什么都没有时用 Dart 的默认值`() {
        val store = ImportRandomColorStore(InMemoryKeyValueStore())
        val prefs = store.snapshot()
        assertTrue("随机配色开关默认开（Dart defaultEnabled = true）", prefs.enabled)
        assertEquals("all", prefs.groupId)
        assertFalse("文字色默认关（Dart defaultTextColorEnabled = false）", prefs.textColorEnabled)
    }

    @Test
    fun `写入后回读同一份`() {
        val disk = InMemoryKeyValueStore()
        val store = ImportRandomColorStore(disk)
        assertTrue(store.setEnabled(false))
        assertTrue(store.setGroupId("ocean"))
        assertTrue(store.setTextColorEnabled(true))

        val prefs = store.snapshot()
        assertFalse(prefs.enabled)
        assertEquals("ocean", prefs.groupId)
        assertTrue(prefs.textColorEnabled)
    }

    @Test
    fun `历史残留的组 id 原样返回`() {
        val store = ImportRandomColorStore(InMemoryKeyValueStore())
        store.setGroupId("no_such_group")
        assertEquals("no_such_group", store.groupId())
        // 色板解析在 ImportSharedModel：未知 id 兜底成全量色板，不静默改成 all。
        assertEquals(
            ImportSharedModel.PRESET_COURSE_COLOR_HEXES,
            ImportSharedModel.courseColorGroupPalette(store.groupId()),
        )
    }

    @Test
    fun `组选项顺序为全部颜色加预设组`() {
        val options = ImportRandomColorStore.GROUP_OPTIONS
        assertEquals("all", options.first())
        assertEquals(options.size, options.toSet().size)
        assertEquals(
            ImportSharedModel.COURSE_COLOR_GROUPS.map { it.first },
            options.drop(1),
        )
        // 每个选项都要有屏上名字（不能有「空选项」）。
        for (option in options) {
            assertTrue("组 $option 没有显示名", ImportRandomColorStore.groupLabel(option).isNotBlank())
        }
    }
}
