package com.mutx163.qingyu.pages.import

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageTheme

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

// ─────────────────────────────────────────────────────────────────────────────
// IDE 预览（2026-11-08）——只给实现阶段看效果，不进业务路径。
//
// 固定写法（照 `about/ContributorsPage.kt` 的样板抄）：主题包 `QingyuPageTheme(isDark = …)`，
// 字号用 `textScale = …`（不用 `@Preview(fontScale = …)`，后者绕过 appTextScale 口径），
// 宽度 400dp 是本仓折行实测口径。
//
// 本页只有一个数据分支：[IcsImportViewState.isImporting]，它同时换按钮文案、loading 位与禁点，
// 所以三档外观都测它，另补一档「导入中」。
// ─────────────────────────────────────────────────────────────────────────────

/** 一档预览的公共身体：数据状态 + 外观档位。 */
@Composable
private fun PreviewIcsImportPage(
    state: IcsImportViewState,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        IcsImportPage(
            viewState = state,
            onBack = {},
            onChooseFile = {},
        )
    }
}

@Suppress("unused")
@Preview(name = "1 亮色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun IcsImportPagePreviewLight() {
    PreviewIcsImportPage(IcsImportViewState(isImporting = false), dark = false)
}

@Suppress("unused")
@Preview(name = "2 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun IcsImportPagePreviewDark() {
    PreviewIcsImportPage(IcsImportViewState(isImporting = false), dark = true)
}

@Suppress("unused")
@Preview(name = "3 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun IcsImportPagePreviewLargeText() {
    PreviewIcsImportPage(IcsImportViewState(isImporting = false), textScale = 1.3f)
}

@Suppress("unused")
@Preview(name = "4 导入中", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun IcsImportPagePreviewImporting() {
    PreviewIcsImportPage(IcsImportViewState(isImporting = true))
}
