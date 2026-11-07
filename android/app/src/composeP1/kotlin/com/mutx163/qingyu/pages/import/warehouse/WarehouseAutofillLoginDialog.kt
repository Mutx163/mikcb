package com.mutx163.qingyu.pages.import.warehouse

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.overlay.OverlayDialog

/**
 * 「自动填充登录信息」确认弹窗（对齐发布版 `showAppConfirmDialog`）。
 *
 * 旧实现是网页登录页底栏里的一张卡片：只写「已记住账号：X」+ 两个小按钮，
 * 和「执行导入脚本」主按钮抢底部高度。这里改成标准两按钮弹窗：
 * 标题 + 带账号的说明 + 底部「暂不 / 自动填充」。
 */
@Composable
fun WarehouseAutofillLoginDialog(
    show: Boolean,
    username: String,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit,
) {
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = show,
        title = WarehouseStrings.autofillLoginTitle.text,
        summary = WarehouseStrings.autofillLoginMessage.filled("username", username),
        onDismissRequest = onDismiss,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            TextButton(
                modifier = Modifier.weight(1f),
                text = WarehouseStrings.notNowAction.text,
                onClick = onDismiss,
            )
            Button(
                onClick = onConfirm,
                modifier = Modifier.weight(1f),
                colors = ButtonDefaults.buttonColorsPrimary(),
            ) {
                Text(
                    text = WarehouseStrings.autofillAction.text,
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}
