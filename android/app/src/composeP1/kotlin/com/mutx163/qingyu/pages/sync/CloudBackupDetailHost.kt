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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.pages.transfer.TransferPreviewContent
import com.mutx163.qingyu.pages.transfer.TransferPreviewDialog
import com.mutx163.qingyu.share.TransferApplyMode
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
 * | 本文件 | 弹层编排：sheet → 恢复前差异预览 → 调控制器 → 弹提示 |
 *
 * ## 恢复链（2026-11-03 接上差异预览，对齐 Dart `cloud_backup_list_screen.dart:135-178`）
 *
 * 点「恢复」→ `controller.previewBackupRestore`（IO 线程：下载 + 解析 + 算差异，
 * **不落盘**）→ 弹 `TransferPreviewDialog`（取消 / 覆盖当前课表；快照恒是全量包，
 * 与传输页同口径不摆「合并」）→ 选定后 `applyPreviewedBackupRestore` 走原有
 * `openBackup` 路径落盘（撤销点 / 基线钉哈希 / 刷新列表一处不缺）。
 *
 * ## 诚实边界
 *
 * - 恢复最终走 `controller.openBackup`：**强制以远端为准**整份覆盖落盘
 *   （`TimetableSnapshotBridge.applySnapshot` 没有合并路径，与传输页对全量包
 *   拒绝合并同一条边界）。Dart 的「设为当前版本」二次确认在 Compose 侧由
 *   `applyDownloadedSnapshot` + `markSynced` 一并完成，不单独再弹。
 * - 恢复成功后列表会由控制器自己刷新（`openBackup` 内部 `refreshBackups`）。
 * - 真机联网（真 WebDAV 账号）验收归用户；本层只声明编译与 JVM 单测。
 *
 * @param entryId 要展示的备份 id，null = 不展示（只翻 `show`，弹层本体常驻组合）
 * @param onDismiss 关闭弹层
 */
@Composable
fun CloudBackupDetailHost(
    controller: CloudSyncController,
    entryId: String?,
    onDismiss: () -> Unit,
) {
    // 弹层常驻组合（2026-11-02 弹窗审核 P3）：旧版 `if (entryId == null) return` 会在置
    // null 的一瞬把整棵弹层摘出组合，官方退场动画一次都播不出来。可见性只交给各弹层的
    // `show`；退场期间的标题/正文/动作用 remember 保留的最后一份非空 entry 渲染
    // （先例：pages/diagnostics/MemoryStatsPage.kt:297-320）。
    val entry = entryId?.let { controller.backupEntry(it) }
    var shownEntry by remember { mutableStateOf(entry) }
    if (entry != null) shownEntry = entry
    val activeEntry = shownEntry
    val view = activeEntry?.let { e ->
        remember(e, controller.revision) { CloudBackupListLogic.buildDetail(e) }
    }
    val dark = isSystemInDarkTheme()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var busy by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }
    // 恢复前差异预览：null = 不展示；非空时弹 TransferPreviewDialog。
    var restorePreview by remember { mutableStateOf<CloudBackupRestorePreview?>(null) }

    fun toast(toast: SyncToast) {
        Toast.makeText(context, toast.message, Toast.LENGTH_SHORT).show()
    }

    CloudBackupDetailSheet(
        show = entry != null,
        view = view,
        busy = busy,
        onDismissRequest = { if (!busy) onDismiss() },
        // 恢复是**整份覆盖**且会丢本地未同步修改：先下载算差异预览，用户看过再定。
        onRestore = {
            val id = activeEntry?.id ?: return@CloudBackupDetailSheet
            busy = true
            scope.launch {
                val preview = withContext(Dispatchers.IO) { controller.previewBackupRestore(id) }
                busy = false
                if (preview != null) {
                    restorePreview = preview
                } else {
                    toast(SyncResultToasts.forRestore(false, controller.lastErrorCode))
                }
            }
        },
        onDelete = { confirmDelete = true },
    )

    // 恢复前差异预览弹窗（Dart `showTransferPreviewDialog(title: cloudBackupRestoreTitle)`）：
    // 常驻组合、只翻 `show`；内容走 TransferPreviewDialog 自己的 remember 保底。
    // 取消/点遮罩 = 放弃恢复（不落盘）；选定模式 → 落盘 → toast（成功带「撤销」）。
    TransferPreviewDialog(
        content = restorePreview?.let {
            TransferPreviewContent(
                title = CloudBackupListLogic.restorePreviewTitle(),
                message = it.message,
            )
        },
        canMerge = restorePreview?.canMerge ?: false,
        onChoose = { mode ->
            val preview = restorePreview
            restorePreview = null
            if (mode != null && preview != null) {
                busy = true
                scope.launch {
                    val kind = withContext(Dispatchers.IO) {
                        controller.applyPreviewedBackupRestore(preview, mode)
                    }
                    busy = false
                    toast(
                        SyncResultToasts.forRestore(
                            kind == SyncResultKind.DOWNLOADED,
                            controller.lastErrorCode,
                        ),
                    )
                    if (kind == SyncResultKind.DOWNLOADED) onDismiss()
                }
            }
        },
    )

    // 删除确认框同样常驻组合、只翻 `show`（条件挂载同样杀退场动画）；正文按 Dart
    // `showHyperosDialog` 的 message 居中（旧版左对齐，审核 P3）。
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = confirmDelete,
        title = SyncStrings.cloudBackupDeleteTitle.zh,
        onDismissRequest = { confirmDelete = false },
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            if (activeEntry != null) {
                Text(
                    text = CloudBackupListLogic.deleteConfirmMessage(activeEntry),
                    style = MiuixTheme.textStyles.body2,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
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
                        val deleteId = activeEntry?.id ?: return@Button
                        busy = true
                        scope.launch {
                            val kind = withContext(Dispatchers.IO) { controller.deleteBackup(deleteId) }
                            busy = false
                            toast(SyncResultToasts.forDeleteBackup(kind, controller.lastErrorCode))
                            onDismiss()
                        }
                    },
                    enabled = !busy && activeEntry != null,
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
