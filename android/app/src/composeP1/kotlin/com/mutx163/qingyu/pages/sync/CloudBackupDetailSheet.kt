package com.mutx163.qingyu.pages.sync

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Text
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
    show: Boolean,
    view: CloudBackupDetailView?,
    busy: Boolean,
    onDismissRequest: () -> Unit,
    onRestore: () -> Unit,
    onDelete: () -> Unit,
) {
    val dark = isSystemInDarkTheme()

    // 弹层常驻组合、show 由宿主驱动（2026-11-03 弹层审计）：`show = true` + 宿主条件挂载
    // 时，entryId 置空整棵弹层被移出组合，260ms 退场动画一次都不播。
    // `view` 在退场期间是宿主保留的最后一份非空快照；首次组合（还没打开过）为 null，
    // 此时 show = false、内容不会被看到。
    QingyuSheet(
        show = show,
        title = view?.title,
        onDismissRequest = onDismissRequest,
        // 内容左右自留 4dp（与页面口径的「16 + 4」一致，正文/按钮都不自带横向内边距），
        // 所以框架侧照旧给 16dp：单边合计 20dp，不是 miuix 默认 24 的 28。
        contentPadsHorizontally = false,
    ) {
        val current = view ?: return@QingyuSheet
        Column(modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp)) {
            DetailLine(current.deviceLine, dark)
            DetailLine(current.sourceLine, dark)
            current.summaryLine?.let { DetailLine(it, dark) }

            Spacer(modifier = Modifier.height(16.dp))
            // 动作区对齐 Dart `showCloudBackupDetailSheet`（cloud_backup_ui_helpers.dart:76-94）：
            // 整宽竖排、恢复在前（primary）、删除在后（destructive 红底 + onError），间距 12dp。
            // 原先是半宽并排 Row 且删除在左，与 Dart 的顺序与主次都相反。
            Button(
                onClick = onRestore,
                enabled = !busy,
                colors = ButtonDefaults.buttonColorsPrimary(),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(SyncStrings.cloudBackupRestoreAction.zh)
            }
            // 「删除」只在 Dart 给的动作里有才画（当前版本备份不可删，见 buildDetail）。
            // 按钮文字用 Dart 的 `l10n.deleteAction`（通用「删除」），不是
            // `cloudBackupDeleteTitle`（那句是确认弹框标题「删除此备份」）。
            if (current.canDelete) {
                Spacer(modifier = Modifier.height(12.dp))
                Button(
                    onClick = onDelete,
                    enabled = !busy,
                    // 删除是破坏性操作：红底 + onError 字（Dart destructive 同口径）。
                    colors = ButtonDefaults.buttonColors(
                        color = Color(QingyuTheme.error(dark)),
                        contentColor = Color(QingyuTheme.onError(dark)),
                    ),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(SyncStrings.deleteAction.zh)
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
