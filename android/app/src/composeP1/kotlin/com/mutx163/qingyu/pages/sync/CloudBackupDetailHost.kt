package com.mutx163.qingyu.pages.sync

import android.widget.Toast
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.theme.QingyuTheme
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 云端备份「详情 → 恢复 / 删除」的**宿主**（2026-10-30 F12 新增）。
 *
 * ## 它替掉了什么
 *
 * 接线前 `f.cloudSync` 与 `f.backupList` 两条分支里各写着一句
 * `Toast("备份详情尚未开放")`：点某条备份只弹一句「尚未开放」——**假入口**
 * （用户以为点错了）。按清单 §二 F12 的要求，这里要么接真、要么把入口去掉；
 * 恢复与删除在 `CloudSyncController` 里本来就有真能力（`openBackup` / `deleteBackup`），
 * 所以选择接真。
 *
 * ## 三块分工（与同族其它页同一套）
 *
 * | 层 | 负责 |
 * |---|---|
 * | `CloudBackupListLogic`（纯逻辑，有单测） | 三行详情文案、删除确认文案、动作集合 |
 * | `SyncResultToasts`（纯逻辑，有单测） | 结果 → 提示文案（成功/失败/是否刷新列表） |
 * | 本文件 | 弹层编排：sheet → 确认框 → 调控制器 → 弹提示 |
 *
 * ## 诚实边界
 *
 * - 恢复走 `controller.openBackup`：**强制以远端为准**下载并落盘（Dart `KEEP_REMOTE`），
 *   没有 Dart 那套「先预览差异、再选合并/覆盖」的二次确认——那需要传输包预览，
 *   归 `f.*` 的传输族（本批不动）。这里的确认只有「点哪个备份」这一次。
 * - 恢复成功后列表会由控制器自己刷新（`openBackup` 内部 `refreshBackups`）。
 * - 真机联网（真 WebDAV 账号）验收归用户；本层只声明编译与 JVM 单测。
 *
 * @param entryId 要展示的备份 id，null = 不展示
 * @param onDismiss 关闭弹层
 */
@Composable
fun CloudBackupDetailHost(
    controller: CloudSyncController,
    entryId: String?,
    onDismiss: () -> Unit,
) {
    if (entryId == null) return

    val entry = controller.backupEntry(entryId) ?: return
    val view = remember(entry, controller.revision) { CloudBackupListLogic.buildDetail(entry) }
    val dark = isSystemInDarkTheme()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var busy by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }
    var confirmRestore by remember { mutableStateOf(false) }

    fun toast(toast: SyncToast) {
        Toast.makeText(context, toast.message, Toast.LENGTH_SHORT).show()
    }

    fun restore() {
        busy = true
        scope.launch {
            val kind = withContext(Dispatchers.IO) { controller.openBackup(entryId) }
            busy = false
            toast(SyncResultToasts.forRestore(kind == SyncResultKind.DOWNLOADED, controller.lastErrorCode))
            onDismiss()
        }
    }

    CloudBackupDetailSheet(
        view = view,
        busy = busy,
        onDismissRequest = { if (!busy) onDismiss() },
        // 恢复是**整份覆盖**且会丢本地未同步修改：先弹二次确认，点「恢复」才真的写回。
        onRestore = { confirmRestore = true },
        onDelete = { confirmDelete = true },
    )

    if (confirmRestore) {
        OverlayDialog(
            insideMargin = DpSize(16.dp, 16.dp),
            show = true,
            title = SyncStrings.cloudBackupRestoreTitle.zh,
            onDismissRequest = { confirmRestore = false },
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(
                    text = SyncStrings.cloudBackupRestoreBody.filled(
                        "time",
                        CloudBackupListLogic.formatEntryTime(entry),
                    ),
                    style = MiuixTheme.textStyles.body2,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    TextButton(
                        text = SyncStrings.cancelAction.zh,
                        onClick = { confirmRestore = false },
                        enabled = !busy,
                        colors = ButtonDefaults.textButtonColors(),
                        modifier = Modifier.weight(1f),
                    )
                    Button(
                        onClick = {
                            confirmRestore = false
                            restore()
                        },
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

    if (confirmDelete) {
        OverlayDialog(
            insideMargin = DpSize(16.dp, 16.dp),
            show = true,
            title = SyncStrings.cloudBackupDeleteTitle.zh,
            onDismissRequest = { confirmDelete = false },
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(
                    text = CloudBackupListLogic.deleteConfirmMessage(entry),
                    style = MiuixTheme.textStyles.body2,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    TextButton(
                        text = SyncStrings.cancelAction.zh,
                        onClick = { confirmDelete = false },
                        enabled = !busy,
                        colors = ButtonDefaults.textButtonColors(),
                        modifier = Modifier.weight(1f),
                    )
                    Button(
                        onClick = {
                            confirmDelete = false
                            busy = true
                            scope.launch {
                                val kind = withContext(Dispatchers.IO) { controller.deleteBackup(entryId) }
                                busy = false
                                toast(SyncResultToasts.forDeleteBackup(kind, controller.lastErrorCode))
                                onDismiss()
                            }
                        },
                        enabled = !busy,
                        // 删除备份是破坏性操作：红底 + onError 字。
                        colors = ButtonDefaults.buttonColors(
                            color = Color(QingyuTheme.error(dark)),
                            contentColor = Color(QingyuTheme.onError(dark)),
                        ),
                        modifier = Modifier.weight(1f),
                    ) {
                        Text(SyncStrings.deleteAction.zh)
                    }
                }
            }
        }
    }
}
