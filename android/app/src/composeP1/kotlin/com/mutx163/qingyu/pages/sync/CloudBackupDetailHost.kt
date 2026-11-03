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
 * 云端备份「详情 → 差异概要 → 恢复 / 删除」的**宿主**（2026-10-30 F12 新增）。
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
 * | `RestoreDiffLogic` + `RestoreDiffStrings`（纯逻辑，有单测） | 差异概要计数与概要行文案 |
 * | `SyncResultToasts`（纯逻辑，有单测） | 结果 → 提示文案（成功/失败/是否刷新列表） |
 * | 本文件 | 弹层编排：sheet → 预览下载 → 确认框（带概要）→ 调控制器 → 弹提示 |
 *
 * ## 恢复是两步（2026-11-03 起带差异预览）
 *
 * 点「恢复」先走 [CloudSyncController.prepareRestore]：下载远端快照、校验、与当前
 * 本机算「将新增 X、覆盖 Y、删除 Z」概要——**零副作用**，用户没确认前任何一端都不动。
 * 确认框里给出概要后，点「恢复」才走 [CloudSyncController.confirmPreparedRestore]
 * 应用（预览的字节就是应用的字节，不存在二次下载被并发换掉）；取消即
 * [CloudSyncController.discardPreparedRestore] 丢弃。恢复是整份覆盖，这一眼概要
 * 是用户确认前唯一的影响面说明。
 *
 * ## 诚实边界
 *
 * - 恢复走两步入口：**强制以远端为准**（Dart `KEEP_REMOTE` 语义）。
 * - 恢复成功后列表会由控制器自己刷新（confirm 内部 `refreshBackups`）；
 *   撤销入口在两页备份区（`canUndoRestore` 有撤销点才出现，见 `CloudRestoreUndoCard`）。
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
    // 恢复确认框常驻组合、由 show 驱动（退场动画要能播完）；概要在 prepare 成功后才有，
    // 隐藏期间保留最后一份非空值，退场中不至于闪空。
    var showRestoreConfirm by remember { mutableStateOf(false) }
    var restoreDiff by remember { mutableStateOf<RestoreDiffSummary?>(null) }

    fun toast(toast: SyncToast) {
        Toast.makeText(context, toast.message, Toast.LENGTH_SHORT).show()
    }

    fun restore() {
        busy = true
        scope.launch {
            val prepared = withContext(Dispatchers.IO) { controller.prepareRestore(entryId) }
            busy = false
            when (prepared) {
                is RestorePrepareOutcome.Ready -> {
                    restoreDiff = prepared.diff
                    showRestoreConfirm = true
                }
                is RestorePrepareOutcome.Failed ->
                    toast(SyncResultToasts.forRestore(false, prepared.errorCode))
                // 缺文件 / 未连接走既有错误通道（lastErrorCode 为空时给通用失败句）。
                RestorePrepareOutcome.NotFound ->
                    toast(SyncResultToasts.forRestore(false, controller.lastErrorCode))
                RestorePrepareOutcome.Missing ->
                    toast(SyncResultToasts.forRestore(false, controller.lastErrorCode))
            }
        }
    }

    fun cancelRestoreConfirm() {
        showRestoreConfirm = false
        controller.discardPreparedRestore()
    }

    fun applyRestore() {
        busy = true
        scope.launch {
            val kind = withContext(Dispatchers.IO) { controller.confirmPreparedRestore() }
            busy = false
            showRestoreConfirm = false
            toast(SyncResultToasts.forRestore(kind == SyncResultKind.DOWNLOADED, controller.lastErrorCode))
            onDismiss()
        }
    }

    CloudBackupDetailSheet(
        view = view,
        busy = busy,
        onDismissRequest = { if (!busy) onDismiss() },
        // 恢复是**整份覆盖**且会丢本地未同步修改：先下载算概要，确认框里看过影响面再写回。
        onRestore = { restore() },
        onDelete = { confirmDelete = true },
    )

    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = showRestoreConfirm,
        title = SyncStrings.cloudBackupRestoreTitle.zh,
        onDismissRequest = { if (!busy) cancelRestoreConfirm() },
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
            // 差异概要（prepare 成功必有值；null 只出现在退场/隐藏期，不渲染）。
            restoreDiff?.let { diff ->
                val diffLines = RestoreDiffLogic.buildDiffLines(diff)
                if (diffLines.isNotEmpty()) {
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        diffLines.forEach { line ->
                            Text(
                                text = line,
                                style = MiuixTheme.textStyles.body2,
                                color = Color(QingyuTheme.primaryText(dark)),
                            )
                        }
                    }
                }
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                TextButton(
                    text = SyncStrings.cancelAction.zh,
                    onClick = { if (!busy) cancelRestoreConfirm() },
                    enabled = !busy,
                    colors = ButtonDefaults.textButtonColors(),
                    modifier = Modifier.weight(1f),
                )
                Button(
                    onClick = { if (!busy) applyRestore() },
                    enabled = !busy,
                    colors = ButtonDefaults.buttonColorsPrimary(),
                    modifier = Modifier.weight(1f),
                ) {
                    Text(SyncStrings.cloudBackupRestoreAction.zh)
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
