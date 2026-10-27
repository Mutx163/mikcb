package com.mutx163.qingyu.pages.import

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.unit.dp

/**
 * 表格导入页 · Compose 渲染层（P3-G1）。
 *
 * 对应 Flutter `lib/screens/import/spreadsheet_course_import_screen.dart` 的**静态结构**：
 * 引导面板（适用场景三步 + 支持的文件）+ 底部「下载模板（次按钮）→ 选择表格文件（主按钮）」。
 *
 * 解析与导入流程（CSV/xlsx 读取、提醒对话框链、provider 写入）是应用层职责；
 * 解析本体在 [SpreadsheetImportModel]，提醒对话框组件在 [ImportSpreadsheetWarningsDialog]。
 */
data class SpreadsheetImportViewState(
    /** 正在读文件 / 走导入链：选择文件按钮换 loading 形态并禁点（Dart `_isImporting`）。 */
    val isImporting: Boolean = false,
    /** 模板分享进行中：下载模板按钮换 loading 形态并禁点（Dart `_isSharingTemplate`）。 */
    val isSharingTemplate: Boolean = false,
)

@Composable
fun SpreadsheetImportPage(
    viewState: SpreadsheetImportViewState,
    onBack: () -> Unit,
    onDownloadTemplate: () -> Unit,
    onChooseFile: () -> Unit,
) {
    ImportPageScaffold(
        title = ImportStrings.spreadsheetImportTitle.zh,
        onBack = onBack,
        bottomBar = {
            ImportActionButton(
                label = ImportStrings.downloadSpreadsheetTemplateAction.zh,
                onClick = onDownloadTemplate,
                secondary = true,
                loading = viewState.isSharingTemplate,
                enabled = !viewState.isSharingTemplate,
            )
            Spacer(modifier = Modifier.height(10.dp))
            ImportActionButton(
                // Dart: _isImporting ? '${l10n.spreadsheetImportTitle}...' : l10n.chooseSpreadsheetFileAction
                label = if (viewState.isImporting) {
                    "${ImportStrings.spreadsheetImportTitle.zh}..."
                } else {
                    ImportStrings.chooseSpreadsheetFileAction.zh
                },
                onClick = onChooseFile,
                loading = viewState.isImporting,
                enabled = !viewState.isImporting,
            )
        },
    ) { innerPadding, scrollBehavior ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .nestedScroll(scrollBehavior.nestedScrollConnection),
            contentPadding = PaddingValues(
                start = 16.dp,
                end = 16.dp,
                top = innerPadding.calculateTopPadding() + 8.dp,
                bottom = innerPadding.calculateBottomPadding() + 12.dp,
            ),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item(key = "guide") {
                ImportGuidePanel(
                    scenarioIntro = ImportStrings.spreadsheetScenarioIntro.zh,
                    step1Subtitle = ImportStrings.spreadsheetStep1Subtitle.zh,
                    step2Subtitle = ImportStrings.spreadsheetStep2Subtitle.zh,
                    step3Subtitle = ImportStrings.spreadsheetStep3Subtitle.zh,
                    supportedFilesSuffix = ImportStrings.spreadsheetSupportedFilesSuffix.zh,
                )
            }
        }
    }
}
