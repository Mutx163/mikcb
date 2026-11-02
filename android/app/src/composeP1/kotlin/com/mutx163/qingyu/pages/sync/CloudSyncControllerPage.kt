package com.mutx163.qingyu.pages.sync

import android.widget.Toast
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
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
import com.mutx163.qingyu.sync.SyncConflictChoice
import com.mutx163.qingyu.sync.SyncConflictInfo
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
 * 云同步 / 云备份两页的**控制器驱动入口**（C1 · 页面消费真实状态）。
 *
 * ## 什么时候用它
 *
 * 现有 [CloudSyncPage] / [CloudBackupListPage]（无状态、只吃 viewState + 回调）保持不变；
 * 本文件给出一层**很薄的桥**：把 [CloudSyncController] 的可观察状态订阅成 Compose 重组，
 * 并把页面回调原样转给控制器。壳侧只需把 P3-F 时代写死的示例 viewState 换成
 * `CloudSyncPage(controller = <真的 controller>, …)`，演示数据即清零。
 *
 * ## 分工（诚实说明）
 *
 * - 本层负责：viewState 订阅 + 把「同步/备份/配置编辑」回调接到控制器；
 * - **交宿主（Lead）**：创建 [CloudSyncController]（真实 store / 传输）、显示登录弹窗
 *   [WebdavConnectSheet]、明文 http 二次确认弹窗、备份详情/恢复 sheet、路由。这些都要
 *   密码存储与页面导航，属壳层职责，本层不臆造。
 */

/**
 * 订阅控制器版本号：控制器任一状态变化会 `notifyChanged()` 自增 `revision`，
 * 这里把它变成 Compose 可观察状态，从而触发重组。
 */
@Composable
private fun rememberControllerRevision(controller: CloudSyncController): Long {
    val revision = remember(controller) { mutableStateOf(controller.revision) }
    DisposableEffect(controller) {
        val listener: () -> Unit = { revision.value = controller.revision }
        controller.addListener(listener)
        onDispose { controller.removeListener(listener) }
    }
    return revision.value
}

/**
 * 云同步页（控制器驱动）。
 *
 * @param onConnect 宿主弹出登录弹窗（[WebdavConnectSheet]）后，把账号密码交给 `controller.connect`
 * @param onOpenBackup 打开某条备份的详情/恢复流程（属宿主 sheet）
 * @param onViewAllBackups 跳转「备份版本」整页
 */
@Composable
fun CloudSyncPage(
    controller: CloudSyncController,
    onBack: () -> Unit,
    onConnect: () -> Unit,
    onOpenBackup: (entryId: String) -> Unit,
    onViewAllBackups: () -> Unit,
) {
    val revision = rememberControllerRevision(controller)
    val viewState = remember(controller, revision) { controller.cloudSyncViewState() }
    val scope = rememberCoroutineScope()
    val context = LocalContext.current

    // 立即同步发现两边都改过时，控制器会挂起 pendingSyncConflict；这里弹「选边」框。
    var conflictInfo by remember { mutableStateOf<SyncConflictInfo?>(null) }
    var conflictBusy by remember { mutableStateOf(false) }

    // 进页首次加载：已连接时拉一次远端备份列表（否则备份区恒空，像云端没有备份）。
    LaunchedEffect(controller) {
        withContext(Dispatchers.IO) { controller.refreshOnEnter() }
    }

    fun toastSyncResult(kind: SyncResultKind) {
        val toast = SyncResultToasts.forSyncNow(kind, controller.lastErrorCode)
        Toast.makeText(context, toast.message, Toast.LENGTH_SHORT).show()
    }

    // 立即同步：返回后有挂起冲突就弹选边框（不弹「已取消」，避免两个提示打架）。
    fun syncNow() {
        scope.launch {
            val kind = withContext(Dispatchers.IO) { controller.syncNow() }
            val pending = controller.pendingSyncConflict
            if (pending != null) {
                conflictInfo = pending
            } else {
                toastSyncResult(kind)
            }
        }
    }

    fun resolveConflict(choice: SyncConflictChoice) {
        conflictBusy = true
        scope.launch {
            val kind = withContext(Dispatchers.IO) { controller.resolveSyncConflict(choice) }
            conflictBusy = false
            conflictInfo = null
            toastSyncResult(kind)
        }
    }

    // 撤销成功后控制器会自增 revision（撤销卡片随之消失）；失败则给出明确提示。
    fun undoRestore() {
        scope.launch {
            val success = withContext(Dispatchers.IO) { controller.undoLastRestore() }
            val toast = SyncResultToasts.forUndoRestore(success, controller.lastErrorCode)
            Toast.makeText(context, toast.message, Toast.LENGTH_SHORT).show()
        }
    }

    CloudSyncPage(
        viewState = viewState,
        onBack = onBack,
        onConnect = onConnect,
        onDisconnect = { controller.disconnect() },
        onToggleEnabled = { controller.setSyncEnabled(it) },
        onProviderSelected = { controller.selectProvider(it) },
        onModeSelected = { controller.selectMode(it) },
        onBaseUrlChange = { controller.onBaseUrlChanged(it) },
        onRemoteFolderChange = { controller.onRemoteFolderChanged(it) },
        onDeviceLabelChange = { controller.onDeviceLabelChanged(it) },
        // 返回的 verdict 里 NEED_HTTP_CONFIRM / INVALID 需宿主弹框；默认 https 直接生效。
        onSaveAdvanced = { controller.saveAdvanced() },
        // 上传是同步阻塞的网络调用：必须离开主线程，否则真机上一份大课表会卡住界面。
        onSyncNow = { syncNow() },
        onCreateBackup = { scope.launch { withContext(Dispatchers.IO) { controller.createBackup() } } },
        onOpenBackup = onOpenBackup,
        onViewAllBackups = onViewAllBackups,
        onUndoRestore = { undoRestore() },
        onMaxCountSelected = { controller.selectMaxCount(it) },
        onMaxAgeSelected = { controller.selectMaxAge(it) },
        onManualProtectedChange = { controller.setManualBackupProtected(it) },
    )

    // 弹层常驻组合、只翻 `show`：`conflictInfo?.let { … }` 会在置 null 的一瞬把整棵弹层摘出
    // 组合，退场动画一次都播不出来。退场期间的标题/正文/动作用 remember 保留的最后一份
    // 非空冲突渲染（先例：pages/diagnostics/MemoryStatsPage.kt:297-320）。
    var shownConflict by remember { mutableStateOf(conflictInfo) }
    if (conflictInfo != null) shownConflict = conflictInfo
    SyncConflictChoiceDialog(
        show = conflictInfo != null,
        info = shownConflict,
        busy = conflictBusy,
        onChoice = { choice ->
            if (choice == SyncConflictChoice.CANCEL) {
                // 取消不碰网络：直接清掉挂起冲突（同时清掉控制器侧状态）。
                controller.resolveSyncConflict(SyncConflictChoice.CANCEL)
                conflictInfo = null
            } else {
                resolveConflict(choice)
            }
        },
        // 点遮罩/返回键 = 放弃选边，与「取消」同义，也必须清掉挂起冲突。
        onDismiss = {
            controller.resolveSyncConflict(SyncConflictChoice.CANCEL)
            conflictInfo = null
        },
    )
}

/**
 * 云备份列表页（控制器驱动）。
 *
 * @param onOpenBackup 打开某条备份详情（宿主 sheet）
 */
@Composable
fun CloudBackupListPage(
    controller: CloudSyncController,
    onBack: () -> Unit,
    onOpenBackup: (entryId: String) -> Unit,
) {
    val revision = rememberControllerRevision(controller)
    val viewState = remember(controller, revision) { controller.backupListViewState() }
    val scope = rememberCoroutineScope()
    val context = LocalContext.current

    // 同云同步页：进页首次加载，避免整页恒空。
    LaunchedEffect(controller) {
        withContext(Dispatchers.IO) { controller.refreshOnEnter() }
    }

    fun undoRestore() {
        scope.launch {
            val success = withContext(Dispatchers.IO) { controller.undoLastRestore() }
            val toast = SyncResultToasts.forUndoRestore(success, controller.lastErrorCode)
            Toast.makeText(context, toast.message, Toast.LENGTH_SHORT).show()
        }
    }

    CloudBackupListPage(
        viewState = viewState,
        onBack = onBack,
        onCreateBackup = { scope.launch { withContext(Dispatchers.IO) { controller.createBackup() } } },
        onOpenBackup = onOpenBackup,
        onUndoRestore = { undoRestore() },
    )
}

/**
 * 同步冲突「选边」三键框（Dart `_resolveConflict`，标题/正文/三动作走
 * [CloudSyncLogic.conflictDialog]，首次同步分歧自动换解释性文案）。
 *
 * 三动作竖排整宽、间距 12dp（Dart `showAppTripleActionDialog` 口径：三动作不挤同一行；
 * 本仓先例 pages/import/ImportCommon.kt 的三动作分支）。弹层常驻组合、只翻 [show]，
 * [info] 传 remember 保留的最后一份非空冲突，供退场期间继续渲染。
 *
 * 两个「选边」动作都会发起网络（保留本机 = PUT、使用云端 = GET+应用），经
 * [onChoice] 交给宿主协程在 IO 线程执行；「取消」与点遮罩等价，纯本地状态清理。
 */
@Composable
private fun SyncConflictChoiceDialog(
    show: Boolean,
    info: SyncConflictInfo?,
    busy: Boolean,
    onChoice: (SyncConflictChoice) -> Unit,
    onDismiss: () -> Unit,
) {
    val view = info?.let { CloudSyncLogic.conflictDialog(isFirstSyncDivergence = it.isFirstSyncDivergence) }
    val dark = isSystemInDarkTheme()
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = show,
        title = view?.title,
        onDismissRequest = onDismiss,
    ) {
        if (view != null) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(
                    text = view.message,
                    style = MiuixTheme.textStyles.body2,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
                TextButton(
                    text = view.cancelLabel,
                    onClick = { onChoice(SyncConflictChoice.CANCEL) },
                    enabled = !busy,
                    colors = ButtonDefaults.textButtonColors(),
                    modifier = Modifier.fillMaxWidth(),
                )
                Button(
                    onClick = { onChoice(SyncConflictChoice.KEEP_LOCAL) },
                    enabled = !busy,
                    colors = ButtonDefaults.buttonColors(),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(text = view.keepLocalLabel)
                }
                Button(
                    onClick = { onChoice(SyncConflictChoice.KEEP_REMOTE) },
                    enabled = !busy,
                    colors = ButtonDefaults.buttonColorsPrimary(),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(text = view.useRemoteLabel)
                }
            }
        }
    }
}
