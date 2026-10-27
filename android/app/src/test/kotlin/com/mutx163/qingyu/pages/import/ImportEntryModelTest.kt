package com.mutx163.qingyu.pages.import

import com.mutx163.qingyu.pages.import.ImportStrings.courseImportTitle
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 导入入口页模型测试（P3-G1 · course_import_entry_screen.dart）。
 *
 * 入口页本身没有业务计算，可测的纯逻辑是：
 * 1. 四种导入方式的清单与顺序（ICS → AI 识图 → 教务系统 → 表格）；
 * 2. 详情页返回值的关单语义（`_openImportPage`：返回 true 才 pop(true)）。
 * 期望值从 Dart 源手推。
 */
class ImportEntryModelTest {

    @Test
    fun `入口清单按 Dart 顺序收录四种导入方式`() {
        val entries = ImportEntryModel.entries
        assertEquals(4, entries.size)
        assertEquals(ImportEntryDestination.ICS, entries[0].destination)
        assertEquals(ImportEntryDestination.AI, entries[1].destination)
        assertEquals(ImportEntryDestination.WAREHOUSE, entries[2].destination)
        assertEquals(ImportEntryDestination.SPREADSHEET, entries[3].destination)
    }

    @Test
    fun `入口标题副标题取自 ImportStrings 的 ARB 键`() {
        val entries = ImportEntryModel.entries
        // Dart: title: l10n.importMethodIcsTitle, subtitle: l10n.importMethodIcsSubtitle …
        assertEquals(ImportStrings.importMethodIcsTitle.zh, entries[0].title)
        assertEquals(ImportStrings.importMethodIcsSubtitle.zh, entries[0].subtitle)
        assertEquals(ImportStrings.importMethodAiTitle.zh, entries[1].title)
        assertEquals(ImportStrings.importMethodAiSubtitle.zh, entries[1].subtitle)
        assertEquals(ImportStrings.importMethodWarehouseTitle.zh, entries[2].title)
        assertEquals(ImportStrings.importMethodWarehouseSubtitle.zh, entries[2].subtitle)
        assertEquals(ImportStrings.importMethodSpreadsheetTitle.zh, entries[3].title)
        assertEquals(ImportStrings.importMethodSpreadsheetSubtitle.zh, entries[3].subtitle)
        // 页面标题
        assertEquals("导入课程", courseImportTitle.zh)
    }

    @Test
    fun `入口行配色槽位对齐 Dart 的 HyperosIconColors`() {
        val entries = ImportEntryModel.entries
        assertEquals("blue", entries[0].accentSlot)
        assertEquals("purple", entries[1].accentSlot)
        assertEquals("green", entries[2].accentSlot)
        assertEquals("orange", entries[3].accentSlot)
    }

    @Test
    fun `详情页返回 true 才向上回传 true 其余一律不关单`() {
        // Dart `_openImportPage`: imported == true → Navigator.pop(true)
        assertTrue(ImportEntryModel.shouldCloseAfterDetailResult(true))
        assertFalse(ImportEntryModel.shouldCloseAfterDetailResult(false))
        assertFalse(ImportEntryModel.shouldCloseAfterDetailResult(null))
    }
}
