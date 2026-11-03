package com.mutx163.qingyu.pages.import.warehouse

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.LinearProgressIndicator
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 宏回放的过程覆盖层与完成弹层（P2 / N11 + N12）。
 *
 * 布局语义逐条对齐 Dart `lib/widgets/warehouse_playback_overlay.dart`：
 * - 播放中：全屏黑 scrim + 转圈 + 「自动导入中……」+ 学校·适配器 + 进度条 +
 *   「步骤 N / M」+「正在……」行（斜体）+ 取消；
 * - **暂停等手动操作：底部卡片、scrim 不拦截触摸**（用户要在网页里填验证码——
 *   Dart 用 `IgnorePointer` + 底部 `HyperosControlCard`，同语义）；
 * - 执行脚本：全屏 scrim + 转圈 + 「回放完成，正在执行导入脚本……」；
 * - 失败：scrim + 卡片（「导入失败」+ 本地化后的原因 + 关闭/重试）。
 *
 * ## 弹层纪律
 *
 * 覆盖层不是对话框：常驻组合、内容按 [WarehousePlaybackUiState] 渲染、hidden 时
 * 根 Box 不出内容（对齐 Dart 的 switch 即时渲染语义）。完成 sheet 是对话框：
 * OverlayDialog 常驻组合 + show 状态驱动 + 显式 16dp insideMargin（S1D）。
 * 文案全取 `WarehouseStrings` / `WarehouseMacroReplayStrings` 现有键，零新增。
 */
@Composable
fun WarehouseMacroPlaybackOverlay(
    uiState: WarehousePlaybackUiState?,
    progress: WarehouseReplayProgress?,
    schoolName: String,
    adapterName: String,
    onCancel: () -> Unit,
    onRetry: () -> Unit,
    onDismiss: () -> Unit,
    onContinueAfterPause: () -> Unit,
) {
    if (uiState == null) return
    when (uiState) {
        WarehousePlaybackUiState.PLAYING -> PlaybackScrim {
            PlayingContent(progress, schoolName, adapterName, onCancel)
        }

        WarehousePlaybackUiState.PAUSED_FOR_INPUT -> PausedBottomCard(progress, onCancel, onContinueAfterPause)

        WarehousePlaybackUiState.EXECUTING_IMPORT -> PlaybackScrim {
            ExecutingContent(schoolName, adapterName)
        }

        WarehousePlaybackUiState.FINISHED -> {
            // 完成态由完成 sheet（独立 OverlayDialog）呈现，覆盖层这里不出内容。
        }

        WarehousePlaybackUiState.ERROR -> PlaybackScrim {
            ErrorCard(progress, onRetry, onDismiss)
        }
    }
}

/** 全屏黑 scrim（播放中 / 执行脚本 / 失败三态共用；空 pointerInput 参与命中即拦截触摸）。 */
@Composable
private fun PlaybackScrim(content: @Composable () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.54f)),
        contentAlignment = Alignment.Center,
    ) {
        content()
    }
}

@Composable
private fun PlayingContent(
    progress: WarehouseReplayProgress?,
    schoolName: String,
    adapterName: String,
    onCancel: () -> Unit,
) {
    Column(
        modifier = Modifier.padding(horizontal = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        CircularProgressIndicator(size = 48.dp, strokeWidth = 3.dp)
        Spacer(modifier = Modifier.height(24.dp))
        Text(
            text = WarehouseMacroReplayStrings.quickImportPlayingTitle.zh,
            style = MiuixTheme.textStyles.title2,
            color = Color.White,
        )
        if (schoolName.isNotEmpty() || adapterName.isNotEmpty()) {
            Spacer(modifier = Modifier.height(6.dp))
            Text(
                text = "$schoolName · $adapterName",
                style = MiuixTheme.textStyles.body2,
                color = Color.White.copy(alpha = 0.7f),
            )
        }
        Spacer(modifier = Modifier.height(20.dp))
        LinearProgressIndicator(
            progress = progress?.progressFraction,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(modifier = Modifier.height(12.dp))
        Text(
            text = WarehouseMacroReplayStrings.quickImportPlaybackStepProgress.filled(
                "current" to ((progress?.currentStepIndex ?: 0) + 1).toString(),
                "total" to (progress?.totalSteps ?: 0).toString(),
            ),
            style = MiuixTheme.textStyles.body2,
            color = Color.White.copy(alpha = 0.7f),
        )
        val statusLabel = progress?.statusLabel.orEmpty()
        if (statusLabel.isNotEmpty()) {
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = statusLabel,
                style = MiuixTheme.textStyles.body2,
                color = Color.White.copy(alpha = 0.7f),
                fontStyle = FontStyle.Italic,
            )
        }
        Spacer(modifier = Modifier.height(32.dp))
        Button(onClick = onCancel, colors = ButtonDefaults.buttonColors()) {
            Text(text = WarehouseMacroReplayStrings.quickImportCancelPlaybackAction.zh)
        }
    }
}

/** 暂停态：底部卡片，**不拦截触摸**（用户要在网页里完成验证码/输入）。 */
@Composable
private fun PausedBottomCard(
    progress: WarehouseReplayProgress?,
    onCancel: () -> Unit,
    onContinueAfterPause: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.Bottom,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(MiuixTheme.colorScheme.surface)
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = WarehouseMacroReplayStrings.quickImportManualInputTitle.zh,
                style = MiuixTheme.textStyles.title3,
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = progress?.pauseReason
                    ?.takeIf { it.isNotEmpty() }
                    ?.let { WarehouseMacroReplayStrings.localize(it) }
                    ?: WarehouseMacroReplayStrings.quickImportManualInputHint.zh,
                style = MiuixTheme.textStyles.body2,
                color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                textAlign = TextAlign.Center,
            )
            Spacer(modifier = Modifier.height(16.dp))
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Button(
                    onClick = onCancel,
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColors(
                        color = MiuixTheme.colorScheme.surfaceVariant,
                        contentColor = MiuixTheme.colorScheme.onSurfaceVariantActions,
                    ),
                ) {
                    Text(text = WarehouseMacroReplayStrings.quickImportCancelImportAction.zh)
                }
                Button(
                    onClick = onContinueAfterPause,
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColorsPrimary(),
                ) {
                    Text(text = WarehouseMacroReplayStrings.quickImportContinueAction.zh)
                }
            }
        }
    }
}

@Composable
private fun ExecutingContent(schoolName: String, adapterName: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        CircularProgressIndicator(size = 48.dp, strokeWidth = 3.dp)
        Spacer(modifier = Modifier.height(24.dp))
        Text(
            text = WarehouseMacroReplayStrings.quickImportExecutingScriptTitle.zh,
            style = MiuixTheme.textStyles.title2,
            color = Color.White,
            textAlign = TextAlign.Center,
        )
        if (schoolName.isNotEmpty() || adapterName.isNotEmpty()) {
            Spacer(modifier = Modifier.height(6.dp))
            Text(
                text = "$schoolName · $adapterName",
                style = MiuixTheme.textStyles.body2,
                color = Color.White.copy(alpha = 0.7f),
            )
        }
    }
}

@Composable
private fun ErrorCard(
    progress: WarehouseReplayProgress?,
    onRetry: () -> Unit,
    onDismiss: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(MiuixTheme.colorScheme.surface)
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = WarehouseStrings.importFailedStatus.zh,
            style = MiuixTheme.textStyles.title3,
            textAlign = TextAlign.Center,
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = progress?.errorMessage
                ?.takeIf { it.isNotEmpty() }
                ?.let { WarehouseMacroReplayStrings.localize(it) }
                ?: WarehouseMacroReplayStrings.quickImportUnknownError.zh,
            style = MiuixTheme.textStyles.body2,
            color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
            textAlign = TextAlign.Center,
        )
        Spacer(modifier = Modifier.height(20.dp))
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Button(
                onClick = onDismiss,
                modifier = Modifier.weight(1f),
                colors = ButtonDefaults.buttonColors(
                    color = MiuixTheme.colorScheme.surfaceVariant,
                    contentColor = MiuixTheme.colorScheme.onSurfaceVariantActions,
                ),
            ) {
                Text(text = WarehouseMacroReplayStrings.closeAction.zh)
            }
            Button(
                onClick = onRetry,
                modifier = Modifier.weight(1f),
                colors = ButtonDefaults.buttonColorsPrimary(),
            ) {
                Text(text = WarehouseMacroReplayStrings.quickImportRetryAction.zh)
            }
        }
    }
}

/**
 * 快捷导入宏选择器（多宏时弹；单宏直接跑——对齐 Dart 课程导入页的宏选择器口径）。
 * 条目副标题「{适配器} · {N} 步」（`quickImportMacroSteps`）。OverlayDialog 常驻
 * 组合、show 状态驱动、显式 16dp insideMargin（S1D）。
 */
@Composable
fun WarehouseQuickImportPickerDialog(
    show: Boolean,
    records: List<WarehouseMacroRecord>,
    onPick: (WarehouseMacroRecord) -> Unit,
    onDismiss: () -> Unit,
) {
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = show,
        title = WarehouseStrings.selectQuickImportTitle.zh,
        onDismissRequest = onDismiss,
    ) {
        Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            if (records.isEmpty()) {
                Text(
                    text = WarehouseStrings.noSavedQuickImportRecords.zh,
                    style = MiuixTheme.textStyles.body2,
                    color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                )
            }
            for (record in records) {
                TextButton(
                    modifier = Modifier.fillMaxWidth(),
                    text = WarehouseStrings.quickImportMacroSteps.filled(
                        "adapterName" to record.adapterName,
                        "stepCount" to record.steps.size.toString(),
                    ),
                    onClick = { onPick(record) },
                )
            }
            TextButton(
                modifier = Modifier.fillMaxWidth(),
                text = WarehouseStrings.cancelAction.zh,
                onClick = onDismiss,
            )
        }
    }
}

/**
 * 快捷导入完成弹层（Dart `_showQuickImportFinishedSheet` 的 Compose 形态）：
 * 标题「导入完成」+ 正文学校·适配器 + 脚本状态行 + 完成按钮。
 * OverlayDialog 常驻组合、show 状态驱动、显式 16dp insideMargin（S1D）。
 */
@Composable
fun WarehouseQuickImportFinishedDialog(
    show: Boolean,
    schoolName: String,
    adapterName: String,
    scriptStatus: String?,
    onDismiss: () -> Unit,
) {
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = show,
        title = WarehouseStrings.quickImportFinishedTitle.zh,
        summary = "$schoolName · $adapterName",
        onDismissRequest = onDismiss,
    ) {
        Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            if (!scriptStatus.isNullOrEmpty()) {
                Text(
                    text = scriptStatus,
                    style = MiuixTheme.textStyles.body2,
                    color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                )
            }
            Button(
                onClick = onDismiss,
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColorsPrimary(),
            ) {
                Text(text = WarehouseStrings.quickImportDismissAction.zh)
            }
        }
    }
}
