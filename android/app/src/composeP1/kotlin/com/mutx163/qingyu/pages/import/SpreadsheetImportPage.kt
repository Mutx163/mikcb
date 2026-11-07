package com.mutx163.qingyu.pages.import

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList

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
        title = ImportStrings.spreadsheetImportTitle.text,
        onBack = onBack,
        bottomBar = {
            ImportActionButton(
                label = ImportStrings.downloadSpreadsheetTemplateAction.text,
                onClick = onDownloadTemplate,
                secondary = true,
                loading = viewState.isSharingTemplate,
                enabled = !viewState.isSharingTemplate,
            )
            Spacer(modifier = Modifier.height(10.dp))
            ImportActionButton(
                // Dart: _isImporting ? '${l10n.spreadsheetImportTitle}...' : l10n.chooseSpreadsheetFileAction
                label = if (viewState.isImporting) {
                    "${ImportStrings.spreadsheetImportTitle.text}..."
                } else {
                    ImportStrings.chooseSpreadsheetFileAction.text
                },
                onClick = onChooseFile,
                loading = viewState.isImporting,
                enabled = !viewState.isImporting,
            )
        },
    ) { innerPadding, scrollBehavior ->
        // 与 ICS 页同款：页面级滚动走共享套件（三件套 + 滚动条），
        // 横向 12dp 由块自己带（见 docs/reference/compose-page-style-rules.md §三）。
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            contentPadding = PaddingValues(bottom = 12.dp),
        ) {
            item(key = "guide") {
                ImportGuidePanel(
                    scenarioIntro = ImportStrings.spreadsheetScenarioIntro.text,
                    step1Subtitle = ImportStrings.spreadsheetStep1Subtitle.text,
                    step2Subtitle = ImportStrings.spreadsheetStep2Subtitle.text,
                    step3Subtitle = ImportStrings.spreadsheetStep3Subtitle.text,
                    supportedFilesSuffix = ImportStrings.spreadsheetSupportedFilesSuffix.text,
                    modifier = Modifier.padding(horizontal = QingyuPageCardMargin),
                )
            }
        }
    }
}
