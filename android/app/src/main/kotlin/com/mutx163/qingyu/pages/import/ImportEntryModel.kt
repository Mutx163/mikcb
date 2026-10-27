package com.mutx163.qingyu.pages.import

/**
 * 导入入口页模型（P3-G1 · 移植 `lib/screens/import/course_import_entry_screen.dart`
 * 的数据语义；页面本身是纯导航，可测逻辑只有清单与关单规则）。
 */
enum class ImportEntryDestination {
    ICS,
    AI,
    WAREHOUSE,
    SPREADSHEET,
}

/** 入口清单行（标题/副标题取 ImportStrings 的 ARB 键，accent 槽位对齐 Dart 侧图标配色）。 */
data class ImportEntryItem(
    val destination: ImportEntryDestination,
    val title: String,
    val subtitle: String,
    val accentSlot: String,
)

object ImportEntryModel {

    /**
     * 四种导入方式，顺序与 Dart `HyperosListGroup` 的 children 逐项一致：
     * ICS（蓝）→ AI 识图（紫）→ 教务系统（绿）→ 表格（橙）。
     */
    val entries: List<ImportEntryItem> = listOf(
        ImportEntryItem(
            destination = ImportEntryDestination.ICS,
            title = ImportStrings.importMethodIcsTitle.zh,
            subtitle = ImportStrings.importMethodIcsSubtitle.zh,
            accentSlot = "blue",
        ),
        ImportEntryItem(
            destination = ImportEntryDestination.AI,
            title = ImportStrings.importMethodAiTitle.zh,
            subtitle = ImportStrings.importMethodAiSubtitle.zh,
            accentSlot = "purple",
        ),
        ImportEntryItem(
            destination = ImportEntryDestination.WAREHOUSE,
            title = ImportStrings.importMethodWarehouseTitle.zh,
            subtitle = ImportStrings.importMethodWarehouseSubtitle.zh,
            accentSlot = "green",
        ),
        ImportEntryItem(
            destination = ImportEntryDestination.SPREADSHEET,
            title = ImportStrings.importMethodSpreadsheetTitle.zh,
            subtitle = ImportStrings.importMethodSpreadsheetSubtitle.zh,
            accentSlot = "orange",
        ),
    )

    /**
     * 详情页返回后的关单规则（Dart `_openImportPage`）：详情页 pop(true)
     * 才把 true 回传给入口页的上一级；取消/失败（false / null）不关单。
     */
    fun shouldCloseAfterDetailResult(imported: Boolean?): Boolean = imported == true
}
