package com.mutx163.qingyu.pages.transfer

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.pages.export.ExportStrings
import com.mutx163.qingyu.share.TransferApplyMode
import com.mutx163.qingyu.share.TransferScope
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import top.yukonga.miuix.kmp.preference.ArrowPreference
import top.yukonga.miuix.kmp.preference.RadioButtonPreference

/**
 * 数据备份与迁移页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/data_transfer_screen.dart`：
 * 完整导出（当前课表 / 全部数据 / 时间模板）→ 导出日历入口 → 完整导入 →
 * 二维码面对面传输（发送当前 / 发送全部 / 扫码接收）→ 当前可迁移内容概览。
 *
 * 同文件里还包括 `lib/screens/transfer_preview_dialog.dart` 的导入预览弹窗
 * （BRIEF 允许并进本页，不单开渲染文件）。
 *
 * **不持业务状态**：概览行、分享主题、按钮忙碌文案、预览正文都来自
 * [DataTransferViewState] 与 [DataTransferLogic]（模型层）；这里只把回调抛上去。
 */
@Composable
fun DataTransferPage(
    viewState: DataTransferViewState,
    onBack: () -> Unit,
    onExportCurrent: () -> Unit,
    onExportAllData: () -> Unit,
    onExportTimeTemplate: () -> Unit,
    onOpenIcsExport: () -> Unit,
    onChooseFileAndImport: () -> Unit,
    onQrSend: (TransferScope, Set<String>) -> Unit,
    onQrSendAll: () -> Unit,
    onQrScan: () -> Unit,
    onUndo: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    var qrScopeDialogVisible by remember { mutableStateOf(false) }

    Scaffold(containerColor = Color(QingyuTheme.scaffoldBackground(dark))) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .padding(innerPadding),
        ) {
            TopAppBar(
                title = TransferStrings.dataTransferTitle.zh,
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = MiuixIcons.Back,
                            contentDescription = TransferStrings.cancelAction.zh,
                            tint = Color(QingyuTheme.actionIcon(dark)),
                        )
                    }
                },
            )

            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 24.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // ── 1. 完整导出 ──
                item {
                    SectionLabel(TransferStrings.fullExportTitle.zh, dark)
                    Card(modifier = Modifier.fillMaxWidth()) {
                        Text(
                            text = TransferStrings.fullExportSubtitle.zh,
                            fontSize = 13.sp,
                            color = Color(QingyuTheme.secondaryText(dark)),
                        )
                        Spacer(modifier = Modifier.height(10.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Button(
                                onClick = onExportCurrent,
                                enabled = !viewState.isExporting,
                            ) {
                                if (viewState.isExporting) {
                                    CircularProgressIndicator(size = 18.dp)
                                    Spacer(modifier = Modifier.width(6.dp))
                                }
                                Text(viewState.exportCurrentLabel)
                            }
                            TextButton(
                                text = TransferStrings.exportAllData.zh,
                                onClick = onExportAllData,
                                enabled = !viewState.isExporting,
                            )
                        }
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            TextButton(
                                text = TransferStrings.exportTimeTemplate.zh,
                                onClick = onExportTimeTemplate,
                                enabled = !viewState.isExporting && viewState.canExportTimeTemplate,
                            )
                        }
                    }
                }

                // ── 2. 导出日历入口（分组标签删过：组里唯一那行标题就是它） ──
                item {
                    Card(modifier = Modifier.fillMaxWidth()) {
                        ArrowPreference(
                            title = ExportStrings.icsExportSectionTitle.zh,
                            onClick = onOpenIcsExport,
                        )
                    }
                }

                // ── 3. 完整导入 ──
                item {
                    SectionLabel(TransferStrings.fullImportTitle.zh, dark)
                    Card(modifier = Modifier.fillMaxWidth()) {
                        Text(
                            text = TransferStrings.fullImportSubtitle.zh,
                            fontSize = 13.sp,
                            color = Color(QingyuTheme.secondaryText(dark)),
                        )
                        Spacer(modifier = Modifier.height(10.dp))
                        Button(
                            onClick = onChooseFileAndImport,
                            enabled = !viewState.isImporting,
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            if (viewState.isImporting) {
                                CircularProgressIndicator(size = 18.dp)
                                Spacer(modifier = Modifier.width(6.dp))
                            }
                            Text(viewState.importLabel)
                        }
                    }
                }

                // ── 4. 二维码面对面传输 ──
                item {
                    SectionLabel(TransferStrings.qrTransferSectionTitle.zh, dark)
                    Card(modifier = Modifier.fillMaxWidth()) {
                        Text(
                            text = TransferStrings.qrTransferSectionSubtitle.zh,
                            fontSize = 13.sp,
                            color = Color(QingyuTheme.secondaryText(dark)),
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        // 明文警告用错误色：Dart 也是 error 色（data_transfer_screen.dart:120-125）。
                        Text(
                            text = TransferStrings.qrTransferPlaintextWarning.zh,
                            fontSize = 13.sp,
                            color = Color(QingyuTheme.error(dark)),
                        )
                        Spacer(modifier = Modifier.height(12.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            Button(
                                onClick = { qrScopeDialogVisible = true },
                                enabled = !viewState.isExporting,
                            ) {
                                Text(TransferStrings.qrTransferSendCurrent.zh)
                            }
                        }
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            TextButton(
                                text = TransferStrings.qrTransferSendAll.zh,
                                onClick = onQrSendAll,
                                enabled = !viewState.isExporting,
                            )
                            TextButton(
                                text = TransferStrings.qrTransferScanReceive.zh,
                                onClick = onQrScan,
                                enabled = !viewState.isImporting,
                            )
                        }
                    }
                }

                // ── 5. 当前可迁移内容 ──
                item {
                    SectionLabel(TransferStrings.transferOverviewTitle.zh, dark)
                    Card(modifier = Modifier.fillMaxWidth()) {
                        val rows = viewState.overviewRows
                        for (index in rows.indices) {
                            val row = rows[index]
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 5.dp),
                                verticalAlignment = Alignment.Top,
                            ) {
                                Text(
                                    text = row.label,
                                    fontSize = 13.sp,
                                    color = Color(QingyuTheme.secondaryText(dark)),
                                    modifier = Modifier.weight(1f),
                                )
                                Spacer(modifier = Modifier.width(12.dp))
                                Text(
                                    text = row.value,
                                    fontSize = 13.sp,
                                    color = Color(QingyuTheme.secondaryText(dark)),
                                    textAlign = TextAlign.End,
                                    modifier = Modifier.weight(1f),
                                )
                            }
                            if (index != rows.lastIndex) {
                                HorizontalDivider(color = Color(QingyuTheme.dividerLine(dark)))
                            }
                        }
                        HorizontalDivider(color = Color(QingyuTheme.dividerLine(dark)))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.End,
                        ) {
                            TextButton(
                                text = TransferStrings.themeUndo.zh,
                                onClick = onUndo,
                            )
                        }
                    }
                }
            }
        }
    }

    // ── 二维码发送范围选择（Dart `_chooseQrScope`） ──
    OverlayDialog(
        show = qrScopeDialogVisible,
        title = TransferStrings.qrTransferSendCurrent.zh,
        summary = TransferStrings.qrTransferSectionSubtitle.zh,
        onDismissRequest = { qrScopeDialogVisible = false },
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            for (option in DataTransferLogic.qrScopeOptions()) {
                RadioButtonPreference(
                    title = option.label,
                    selected = false,
                    onClick = {
                        qrScopeDialogVisible = false
                        // 需要先勾课程的范围，交给上层打开选课面板（空集合表示由上层再问）。
                        onQrSend(option.scope, emptySet())
                    },
                )
            }
        }
    }
}

/**
 * 导入预览弹窗（`lib/screens/transfer_preview_dialog.dart`）。
 *
 * [content] 为 null 时不展示；选中后回传 [TransferApplyMode]（取消回传 null）。
 */
@Composable
fun TransferPreviewDialog(
    content: TransferPreviewContent?,
    onChoose: (TransferApplyMode?) -> Unit,
) {
    OverlayDialog(
        show = content != null,
        title = content?.title,
        onDismissRequest = { onChoose(null) },
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            Text(
                text = content?.message.orEmpty(),
                fontSize = 13.sp,
                color = Color(QingyuTheme.primaryText(isSystemInDarkTheme())),
            )
            Spacer(modifier = Modifier.height(12.dp))
            for (action in DataTransferLogic.previewActions()) {
                Button(
                    onClick = { onChoose(action.mode) },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(action.label)
                }
                Spacer(modifier = Modifier.height(8.dp))
            }
        }
    }
}

/** 小节标题（Dart `HyperosSectionLabel`）。 */
@Composable
private fun SectionLabel(text: String, dark: Boolean) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = text,
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium,
            color = Color(QingyuTheme.sectionLabel(dark)),
            modifier = Modifier.padding(start = 4.dp, bottom = 6.dp),
        )
    }
}
