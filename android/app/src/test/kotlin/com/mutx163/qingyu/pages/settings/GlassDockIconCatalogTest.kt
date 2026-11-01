package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 图标名清单 [GlassDockIconCatalog] 的守卫测试。
 *
 * 期望值来源：Dart `MiuixExtendedIcons.names`（flutter_miuix
 * `miuix_extended_icons.dart` 的 `_data` 键表）与 `miuix-icons-android:0.9.4` 的
 * `extended` 包类名。两侧各 156 项、逐项对应；这里钉住「数量 / 顺序 / 无重复」，
 * 防止有人手改清单后让 Dart 与 Kotlin 悄悄错位。
 */
class GlassDockIconCatalogTest {

    @Test
    fun `清单是全部 156 个扩展图标`() {
        // Dart `_data` 156 个键；miuix-icons 0.9.4 的 extended 包 156 个类。
        assertEquals(156, GlassDockIconCatalog.names.size)
    }

    @Test
    fun `清单按字母序且没有重复`() {
        val names = GlassDockIconCatalog.names
        // Dart `_data` 的声明顺序即字母序；用户看到的图标位置依赖它，不能重排。
        assertEquals(names.sorted(), names)
        assertEquals(names.size, names.toSet().size)
    }

    @Test
    fun `首尾与几个关键名字都在`() {
        val names = GlassDockIconCatalog.names
        assertEquals("add", names.first())
        assertEquals("zoomOut", names.last())
        assertTrue("home 在 Kotlin 侧是 MiuixIcons.Home，容易漏", "home" in names)
        assertTrue("th31 是数字后缀，首字母大写后是 MiuixIcons.Th31", "th31" in names)
        assertTrue("close2 带数字后缀", "close2" in names)
    }

    @Test
    fun `用真实清单过滤 结果与 Dart 同口径`() {
        val picker = IconPickerState(
            names = GlassDockIconCatalog.names,
            query = "chevron",
        )
        assertEquals(
            listOf("chevronBackward", "chevronForward"),
            SettingsGlassDockIconEditorPage.filteredNames(picker),
        )

        // 不区分大小写：ADD 命中 add / addCircle / addFolder，且保持原始顺序。
        assertEquals(
            listOf("add", "addCircle", "addFolder"),
            SettingsGlassDockIconEditorPage.filteredNames(
                IconPickerState(names = GlassDockIconCatalog.names, query = "ADD"),
            ),
        )
    }

    @Test
    fun `用真实清单排网格 首格仍是默认加号`() {
        val picker = IconPickerState(names = GlassDockIconCatalog.names)
        val rows = SettingsGlassDockIconEditorPage.cells(picker, contentWidthDp = 328.0)
        assertEquals(4, rows.first().size)
        assertEquals(156 + 1, rows.flatten().count { it != null })
        assertEquals("glassDockButtonIconDefault", rows.first().first()!!.labelKey)
        assertTrue(rows.first().first()!!.selected)
    }
}
