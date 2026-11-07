package com.mutx163.qingyu.pages.import.warehouse

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.overlay.OverlayDialog

/**
 * 录制完成后的「是否保存这份导入路径」确认（对齐 Dart
 * `_completeMacroAndPop` / `_stopMacroRecording` 里的 `showAppConfirmDialog`，P1）。
 *
 * 两个入口共用一问，正文按入口区分：
 * - 导入成功自动完成 → `courseImportSaveAutoRecordingMessage`（ lighter 口径，步骤数插值）；
 * - 手动停止录制 → `courseImportSaveRecordingMessage`。
 * 保存 → 构造 `WarehouseMacroRecord` 落盘；取消 → 清状态不留痕（对齐旧版）。
 *
 * ## 弹层纪律
 *
 * 常驻组合、`show` 由宿主的保存询问状态驱动；本层无可空载荷（步骤数恒非空参数），
 * 退场动画期间无塌空面。`OverlayDialog` 显式 16dp insideMargin（S1D 口径）。
 * 文案全取 `WarehouseStrings` 现有键，零新增（六语 ARB 已有）。
 */
@Composable
fun WarehouseMacroSaveRecordingDialog(
    show: Boolean,
    stepCount: Int,
    autoRecord: Boolean,
    onSave: () -> Unit,
    onDiscard: () -> Unit,
) {
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = show,
        title = WarehouseStrings.courseImportSaveRecordingTitle.text,
        summary = if (autoRecord) {
            WarehouseStrings.courseImportSaveAutoRecordingMessage.filled("count", stepCount.toString())
        } else {
            WarehouseStrings.courseImportSaveRecordingMessage.filled("count", stepCount.toString())
        },
        onDismissRequest = onDiscard,
    ) {
        Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            TextButton(
                modifier = Modifier.fillMaxWidth(),
                text = WarehouseStrings.cancelAction.text,
                onClick = onDiscard,
            )
            Button(
                onClick = onSave,
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColorsPrimary(),
            ) {
                Text(text = WarehouseStrings.saveAction.text)
            }
        }
    }
}
