package com.mutx163.qingyu.pages.import

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.unit.dp

/**
 * ICS 日历导入页 · Compose 渲染层（P3-G1）。
 *
 * 对应 Flutter `lib/screens/import/ics_course_import_screen.dart` 的**静态结构**：
 * 引导面板（适用场景三步 + 支持的文件，比表格页多一句「截图请用识图导入」）
 * + 底部整宽「选择 .ics 文件」按钮。
 *
 * 解析与导入流程（选择器、对话框链、provider 写入）是应用层职责——本层只报
 * [IcsImportViewState.isImporting] 的按钮形态，把点击抛给宿主。
 */
data class IcsImportViewState(
    /** 正在读文件 / 走导入链：按钮换 loading 形态并禁点（Dart `_isImporting`）。 */
    val isImporting: Boolean = false,
)

@Composable
fun IcsImportPage(
    viewState: IcsImportViewState,
    onBack: () -> Unit,
    onChooseFile: () -> Unit,
) {
    ImportPageScaffold(
        title = ImportStrings.icsImportTitle.zh,
        onBack = onBack,
        bottomBar = {
            ImportActionButton(
                // Dart: _isImporting ? '${l10n.icsImportTitle}...' : l10n.chooseIcsFileAction
                label = if (viewState.isImporting) {
                    "${ImportStrings.icsImportTitle.zh}..."
                } else {
                    ImportStrings.chooseIcsFileAction.zh
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
                    scenarioIntro = ImportStrings.icsScenarioIntro.zh,
                    step1Subtitle = ImportStrings.icsStep1Subtitle.zh,
                    step2Subtitle = ImportStrings.icsStep2Subtitle.zh,
                    step3Subtitle = ImportStrings.icsStep3Subtitle.zh,
                    supportedFilesSuffix = ImportStrings.supportedFilesSuffix.zh,
                    supportedFilesExtra = ImportStrings.supportedFilesImageHint.zh,
                )
            }
        }
    }
}
