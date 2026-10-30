package com.mutx163.qingyu.pages.sync

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.overlay.OverlayBottomSheet
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 云端备份详情弹层（Dart `showCloudBackupDetailSheet`，
 * `lib/widgets/cloud_backup_detail_sheet.dart`）。
 *
 * ## 为什么需要它
 *
 * 接线前 `f.cloudSync` / `f.backupList` 两条分支点某条备份只会弹一句
 * 「备份详情尚未开放」——**假入口**：用户以为点错了，实际是功能没接。
 * 本层把 Dart 那张表补齐：三行详情（设备 / 来源 / 内容）+ 恢复 + 删除。
 *
 * ## 分工（与同族其它页同一套）
 *
 * - 三行文字与「本机备份不给删」的判据都在 [CloudBackupListLogic.buildDetail]
 *   （纯逻辑、有单测）。本文件**一个判据都不重复**，只把 [CloudBackupDetailView] 画出来。
 * - 恢复 / 删除的副作用（下载落盘、远端 DELETE、刷新列表）在宿主侧
 *   （`CloudSyncController.openBackup` / `deleteBackup`），这里只回调一个动作。
 *
 * ## 文案
 *
 * 无中文字面量：标题与按钮文字全部来自 [SyncStrings]（ARB 逐字对拍）。
 */
@Composable
fun CloudBackupDetailSheet(
    view: CloudBackupDetailView,
    busy: Boolean,
    onDismissRequest: () -> Unit,
    onRestore: () -> Unit,
    onDelete: () -> Unit,
) {
    val dark = isSystemInDarkTheme()

    OverlayBottomSheet(
        show = true,
        title = view.title,
        onDismissRequest = onDismissRequest,
    ) {
        Column(modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp)) {
            DetailLine(view.deviceLine, dark)
            DetailLine(view.sourceLine, dark)
            view.summaryLine?.let { DetailLine(it, dark) }

            Spacer(modifier = Modifier.height(16.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // 「删除」只在 Dart 给的动作里有才画（当前版本备份不可删，见 buildDetail）。
                // 按钮文字用 Dart 的 `l10n.deleteAction`（通用「删除」），不是
                // `cloudBackupDeleteTitle`（那句是确认弹框标题「删除此备份」）。
                if (view.canDelete) {
                    TextButton(
                        text = SyncStrings.deleteAction.zh,
                        onClick = onDelete,
                        enabled = !busy,
                        colors = ButtonDefaults.textButtonColors(),
                        modifier = Modifier.weight(1f),
                    )
                }
                Button(
                    onClick = onRestore,
                    enabled = !busy,
                    colors = ButtonDefaults.buttonColors(),
                    modifier = Modifier.weight(1f),
                ) {
                    Text(SyncStrings.cloudBackupRestoreAction.zh)
                }
            }
        }
    }
}

/** 详情里的一行（标签已经由模型层拼进 [line]，这里只画字）。 */
@Composable
private fun DetailLine(line: String, dark: Boolean) {
    Text(
        text = line,
        style = MiuixTheme.textStyles.body2,
        color = Color(QingyuTheme.secondaryText(dark)),
        modifier = Modifier.padding(vertical = 3.dp),
    )
}
