package com.mutx163.qingyu.pages.sync

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 「升级后请重输网盘密码」一次性提示（云同步 / 情侣两个入口共用）。
 *
 * 只翻 [show]、常驻组合（调用方不要用 `if (show)` 包住本组件）：条件挂载会在置 false
 * 的一瞬把整棵弹层摘出组合，官方退场动画一次都播不出来。样式抄
 * `CloudSyncControllerPage.kt` 的 `SyncConflictChoiceDialog`：整宽竖排两键。
 *
 * 文案由调用方传入：正文只有一处 ARB 键 `webdavPasswordReentryBody`，标题/主按钮/取消
 * 各自复用所在页面既有键，不为一条提示再造整套文案。
 */
@Composable
fun LegacyPasswordReentryDialog(
    show: Boolean,
    title: String,
    body: String,
    connectLabel: String,
    cancelLabel: String,
    onConnect: () -> Unit,
    onDismiss: () -> Unit,
) {
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = show,
        title = title,
        onDismissRequest = onDismiss,
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(
                text = body,
                style = MiuixTheme.textStyles.body2,
                color = Color(QingyuTheme.secondaryText(isSystemInDarkTheme())),
            )
            TextButton(
                text = cancelLabel,
                onClick = onDismiss,
                colors = ButtonDefaults.textButtonColors(),
                modifier = Modifier.fillMaxWidth(),
            )
            Button(
                onClick = onConnect,
                colors = ButtonDefaults.buttonColorsPrimary(),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(text = connectLabel)
            }
        }
    }
}
