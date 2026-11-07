package com.mutx163.qingyu.pages.import

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList

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
        title = ImportStrings.icsImportTitle.text,
        onBack = onBack,
        bottomBar = {
            ImportActionButton(
                // Dart: _isImporting ? '${l10n.icsImportTitle}...' : l10n.chooseIcsFileAction
                label = if (viewState.isImporting) {
                    "${ImportStrings.icsImportTitle.text}..."
                } else {
                    ImportStrings.chooseIcsFileAction.text
                },
                onClick = onChooseFile,
                loading = viewState.isImporting,
                enabled = !viewState.isImporting,
            )
        },
    ) { innerPadding, scrollBehavior ->
        // 页面级滚动统一走共享套件：内含官方三件套（末端轻震 + 过度滚动 + 顶栏联动）
        // 与右侧滚动条；横向留白由每个块自己带 QingyuPageCardMargin（12dp），
        // 这样滚动条贴得到屏幕边缘，也与 SmallTitle 的 28dp 轴线对齐。
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            contentPadding = PaddingValues(bottom = 12.dp),
        ) {
            item(key = "guide") {
                ImportGuidePanel(
                    scenarioIntro = ImportStrings.icsScenarioIntro.text,
                    step1Subtitle = ImportStrings.icsStep1Subtitle.text,
                    step2Subtitle = ImportStrings.icsStep2Subtitle.text,
                    step3Subtitle = ImportStrings.icsStep3Subtitle.text,
                    supportedFilesSuffix = ImportStrings.supportedFilesSuffix.text,
                    supportedFilesExtra = ImportStrings.supportedFilesImageHint.text,
                    modifier = Modifier.padding(horizontal = QingyuPageCardMargin),
                )
            }
        }
    }
}
