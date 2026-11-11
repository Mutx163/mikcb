package com.mutx163.qingyu.pages.sync

import android.widget.Toast
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.pages.transfer.AppToastCapsule
import com.mutx163.qingyu.platform.AndroidLegacyCredentialProbe
import com.mutx163.qingyu.platform.PrefsKeyValueStore
import com.mutx163.qingyu.sync.SyncConflictChoice
import com.mutx163.qingyu.sync.SyncConflictInfo
import com.mutx163.qingyu.theme.QingyuTheme
import android.util.Log
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
 * 页面层提示：[SyncToast]（含 isError / actionLabel）+ 可选动作回调。
 * 动作挂在提示尾部（Dart `showAppToastWithAction` 同位），点掉提示再执行。
 */
private class PageToast(val toast: SyncToast, val onAction: (() -> Unit)? = null)

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
    // 胶囊与确认框的明暗样式用（此前该组合体没用过 dark，新胶囊接线后补声明）。
    val dark = isSystemInDarkTheme()

    // 升级后一次性提示：新版密文键为空、旧 Dart 插件 prefs 里仍有密码、且标记没写过。
    // 只在本页入口算一次（`remember(controller)`），不随重组反复探测；判为「该提示」时
    // 立即写一次性标记（写失败也照常显示，见 CloudSyncLogic.takeLegacyPasswordReentryPrompt）。
    val promptStore = remember(context) { PrefsKeyValueStore(context.applicationContext) }
    val legacyProbe = remember(context) { AndroidLegacyCredentialProbe(context) }
    val shouldPromptReentry = remember(controller, promptStore, legacyProbe) {
        CloudSyncLogic.takeLegacyPasswordReentryPrompt(
            hasStoredPassword = controller.hasStoredPassword(),
            legacyKeySuffix = CloudSyncLogic.LEGACY_KEY_SUFFIX_CLOUD,
            alreadyPrompted = {
                promptStore.getBool(CloudSyncLogic.LEGACY_REPROMPT_MARK_CLOUD, false)
            },
            hasLegacyDartCredential = { suffix -> legacyProbe.hasLegacyPassword(suffix) },
            markPrompted = {
                promptStore.putBool(CloudSyncLogic.LEGACY_REPROMPT_MARK_CLOUD, true)
            },
        )
    }
    var showReentry by remember { mutableStateOf(shouldPromptReentry) }

    // 立即同步发现两边都改过时，控制器会挂起 pendingSyncConflict；这里弹「选边」框。
    var conflictInfo by remember { mutableStateOf<SyncConflictInfo?>(null) }
    var conflictBusy by remember { mutableStateOf(false) }

    // 页内提示胶囊（2026-11-05 云同步反馈修复）：替代四处系统 Toast——胶囊带
    // isError 样式与动作位（「以本机为准备份」直达），Dart showAppToastWithAction 同形。
    var cloudToast by remember { mutableStateOf<PageToast?>(null) }

    // 高级设置保存：verdict 分流 + 明文二次确认（成员八复核①）
    var showHttpConfirm by remember { mutableStateOf(false) }
    var savingAdvanced by remember { mutableStateOf(false) }

    // 断开确认（成员八复核⑤）：文案说清「清凭据、数据保留」，确认后才动。
    var showDisconnectConfirm by remember { mutableStateOf(false) }

    // 进页首次加载：已连接时拉一次远端备份列表（否则备份区恒空，像云端没有备份）。
    LaunchedEffect(controller) {
        withContext(Dispatchers.IO) { controller.refreshOnEnter() }
    }

    // 连接成功提示（A 类第 16 条）：发布版连接成功后 showAppToast「账号连接成功」
    // （cloud_sync_screen.dart:271-273），此前 Kotlin 侧连接成功只关弹层静默。
    // 壳层弹层（ShellPageIndex 的 onConfirm）负责调 controller.connect，页面不重复调、
    // 也不给壳层传回调——只观察 account.connected 的翻转：
    // 「未连接 → 已连接」弹成功胶囊（文案走模型层 connectSuccessFeedback，键有单测钉住）；
    // 进页时已连接（首次只定基线）与断开翻转（发布版断开静默）都不弹。
    var lastConnected by remember { mutableStateOf<Boolean?>(null) }
    LaunchedEffect(viewState.account.connected) {
        val connected = viewState.account.connected
        when (lastConnected) {
            null -> lastConnected = connected
            false -> if (connected) {
                lastConnected = true
                cloudToast = PageToast(CloudSyncLogic.connectSuccessFeedback())
            }
            true -> if (!connected) lastConnected = false
        }
    }

    // 提示走胶囊（isError 样式 + 动作位）。CANCELLED 不带动作：冲突语义由选边框承接
    // （挂起冲突时弹「选边」框、不弹 toast），放弃选边后动作是空转（2026-11-06 返工③）。
    fun toastSyncResult(kind: SyncResultKind) {
        cloudToast = PageToast(SyncResultToasts.forSyncNow(kind, controller.lastErrorCode))
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
            cloudToast = PageToast(SyncResultToasts.forUndoRestore(success, controller.lastErrorCode))
        }
    }

    // ── 保存高级设置（成员八复核①）：verdict 分流 + 主线程写盘兜崩 ──
    //
    // 崩溃链（复核员坐实）：saveAdvanced → persist → store.saveConfig →
    // PrefsKeyValueStore.commitOrThrow 在盘满等情况下抛 IOException，原实现直接在
    // 主线程调用、未捕获 ⇒ 应用崩溃。现在挪 IO + runCatching 兜住。
    //
    // verdict 分流（进 IO 前判定在模型层 advancedSaveFeedback，有单测钉住）：
    // - INVALID → forBaseUrlInvalid 错误胶囊；
    // - NEED_HTTP_CONFIRM → 弹明文 http 二次确认框，确认后带 allowedInsecureHttp = true 重存；
    // - PROCEED → 「已保存」成功提示（2026-11-06 ARB 批补键 cloudSyncSaved）。
    // 落盘失败（onFailure）→ 「保存失败」错误胶囊（复用通用键 saveFailed）。
    fun saveAdvanced(allowedInsecureHttp: Boolean) {
        savingAdvanced = true
        scope.launch {
            val result = withContext(Dispatchers.IO) {
                runCatching { controller.saveAdvanced(allowedInsecureHttp) }
            }
            savingAdvanced = false
            result.fold(
                onSuccess = { verdict ->
                    // 提示映射在模型层 advancedSaveFeedback（有单测钉住）：INVALID →
                    // 「地址非法」错误胶囊；NEED_HTTP_CONFIRM → 弹明文确认框；PROCEED →
                    // 「已保存」成功胶囊。
                    when (verdict) {
                        BaseUrlVerdict.INVALID, BaseUrlVerdict.PROCEED ->
                            CloudSyncLogic.advancedSaveFeedback(verdict)?.let { feedback ->
                                cloudToast = PageToast(feedback)
                            }
                        BaseUrlVerdict.NEED_HTTP_CONFIRM -> showHttpConfirm = true
                    }
                },
                onFailure = { error ->
                    // 落盘失败（commitOrThrow IOException 等）：不崩、界面保持原状，
                    // 并弹「保存失败」错误胶囊（2026-11-06 ARB 批：不再静默）。
                    Log.w("CloudSyncPage", "saveAdvanced failed", error)
                    cloudToast = PageToast(CloudSyncLogic.advancedSaveFailureFeedback())
                },
            )
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        CloudSyncPage(
            viewState = viewState,
            onBack = onBack,
            onConnect = onConnect,
            // 断开先弹确认框（成员八复核⑤）：清凭据、数据保留的口径说清，确认后才动。
            onDisconnect = { showDisconnectConfirm = true },
            onToggleEnabled = { controller.setSyncEnabled(it) },
            onProviderSelected = { controller.selectProvider(it) },
            onModeSelected = { controller.selectMode(it) },
            onBaseUrlChange = { controller.onBaseUrlChanged(it) },
            onRemoteFolderChange = { controller.onRemoteFolderChanged(it) },
            onDeviceLabelChange = { controller.onDeviceLabelChanged(it) },
            // 发布版口径：打字只改草稿，**提交（完成键）才落盘**。
            onDeviceLabelSubmit = { controller.submitDeviceLabel() },
            // 返回的 verdict 里 NEED_HTTP_CONFIRM / INVALID 在宿主层分流（弹确认框 / 报错胶囊）；
            // 默认 https 直接生效。保存挪 IO + runCatching（主线程写盘崩溃链已兜住）。
            onSaveAdvanced = { saveAdvanced(allowedInsecureHttp = false) },
            // 上传是同步阻塞的网络调用：必须离开主线程，否则真机上一份大课表会卡住界面。
            onSyncNow = { syncNow() },
            onCreateBackup = {
                scope.launch {
                    val kind = withContext(Dispatchers.IO) { controller.createBackup() }
                    // 立即备份接结果（成员八复核②）：成功/失败都弹（forCreateBackup 分好样式）。
                    cloudToast = PageToast(SyncResultToasts.forCreateBackup(kind, controller.lastErrorCode))
                }
            },
            onOpenBackup = onOpenBackup,
            onViewAllBackups = onViewAllBackups,
            onUndoRestore = { undoRestore() },
            onMaxCountSelected = { controller.selectMaxCount(it) },
            onMaxAgeSelected = { controller.selectMaxAge(it) },
            onManualProtectedChange = { controller.setManualBackupProtected(it) },
        )

        // 页内提示胶囊（isError 样式 + 动作位），替代系统 Toast。
        cloudToast?.let { pageToast ->
            AppToastCapsule(
                message = pageToast.toast.message,
                dark = dark,
                isError = pageToast.toast.isError,
                actionLabel = pageToast.toast.actionLabel,
                onAction = {
                    pageToast.onAction?.invoke()
                    cloudToast = null
                },
                onDismiss = { cloudToast = null },
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(horizontal = 16.dp, vertical = 32.dp),
            )
        }
    }

    // 弹层常驻组合：显隐在对话框内部由 info 判空驱动，这里不再条件挂载。
    SyncConflictChoiceDialog(
        info = conflictInfo,
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

    // 与选边框同口径：常驻组合、只翻 `show`，退场动画能播完。
    LegacyPasswordReentryDialog(
        show = showReentry,
        title = SyncStrings.cloudSyncTitle.text,
        body = SyncStrings.webdavPasswordReentryBody.text,
        connectLabel = SyncStrings.cloudSyncConnectAccount.text,
        cancelLabel = SyncStrings.cancelAction.text,
        onConnect = {
            showReentry = false
            onConnect()
        },
        onDismiss = { showReentry = false },
    )

    // 明文 http 二次确认框（verdict = NEED_HTTP_CONFIRM 时弹；文案来自 viewState 模型字段）。
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = showHttpConfirm,
        title = viewState.httpConfirmTitle,
        onDismissRequest = { if (!savingAdvanced) showHttpConfirm = false },
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(
                text = viewState.httpConfirmMessage,
                style = MiuixTheme.textStyles.body2,
                color = Color(QingyuTheme.secondaryText(dark)),
                modifier = Modifier.fillMaxWidth(),
            )
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                TextButton(
                    text = SyncStrings.cancelAction.text,
                    onClick = { if (!savingAdvanced) showHttpConfirm = false },
                    enabled = !savingAdvanced,
                    modifier = Modifier.weight(1f),
                )
                Button(
                    onClick = {
                        showHttpConfirm = false
                        // 「仍要保存」= 带明文放行重存（controller 内部走 PROCEED 分支落盘）。
                        saveAdvanced(allowedInsecureHttp = true)
                    },
                    enabled = !savingAdvanced,
                    colors = ButtonDefaults.buttonColorsPrimary(),
                    modifier = Modifier.weight(1f),
                ) {
                    Text(text = viewState.httpConfirmProceedLabel)
                }
            }
        }
    }

    // 断开确认框（成员八复核⑤）：现成文案已说清「清 WebDAV 凭据、课表数据保留」；
    // 确认后挪 IO 执行。结果提示：无「已断开」现成键（发布版亦静默、界面状态翻转即
    // 反馈），缺键已报 Chief。
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = showDisconnectConfirm,
        title = viewState.disconnectTitle,
        onDismissRequest = { showDisconnectConfirm = false },
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(
                text = viewState.disconnectBody,
                style = MiuixTheme.textStyles.body2,
                color = Color(QingyuTheme.secondaryText(dark)),
                modifier = Modifier.fillMaxWidth(),
            )
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                TextButton(
                    text = SyncStrings.cancelAction.text,
                    onClick = { showDisconnectConfirm = false },
                    modifier = Modifier.weight(1f),
                )
                Button(
                    onClick = {
                        showDisconnectConfirm = false
                        scope.launch {
                            // clearPassword / persist 都是本地 prefs 写，挪 IO 防主线程卡顿。
                            withContext(Dispatchers.IO) { controller.disconnect() }
                        }
                    },
                    // 断开是破坏性操作：红底 + onError 字（同删除备份确认键样式）。
                    colors = ButtonDefaults.buttonColors(
                        color = Color(QingyuTheme.error(dark)),
                        contentColor = Color(QingyuTheme.onError(dark)),
                    ),
                    modifier = Modifier.weight(1f),
                ) {
                    Text(text = viewState.disconnectActionLabel)
                }
            }
        }
    }
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

    // 页内提示胶囊（成员八复核②）：立即备份结果在这里弹（成功/失败都提示）。
    var backupToast by remember { mutableStateOf<SyncToast?>(null) }
    val dark = isSystemInDarkTheme()

    // 同云同步页：进页首次加载，避免整页恒空。
    LaunchedEffect(controller) {
        withContext(Dispatchers.IO) { controller.refreshOnEnter() }
    }

    fun undoRestore() {
        scope.launch {
            val success = withContext(Dispatchers.IO) { controller.undoLastRestore() }
            backupToast = SyncResultToasts.forUndoRestore(success, controller.lastErrorCode)
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        CloudBackupListPage(
            viewState = viewState,
            onBack = onBack,
            onCreateBackup = {
                scope.launch {
                    val kind = withContext(Dispatchers.IO) { controller.createBackup() }
                    // 立即备份接结果（成员八复核②，备份列表页 ：247 同修）：成功/失败都提示。
                    backupToast = SyncResultToasts.forCreateBackup(kind, controller.lastErrorCode)
                }
            },
            onOpenBackup = onOpenBackup,
            onUndoRestore = { undoRestore() },
            onRetryRefresh = {
                scope.launch { withContext(Dispatchers.IO) { controller.refreshBackups() } }
            },
        )

        backupToast?.let { toast ->
            AppToastCapsule(
                message = toast.message,
                dark = dark,
                isError = toast.isError,
                onDismiss = { backupToast = null },
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(horizontal = 16.dp, vertical = 32.dp),
            )
        }
    }
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
 *
 * 弹层常驻组合（2026-11-03 弹层审计）：`show` 由 info 是否为空驱动，宿主原先
 * `conflictInfo?.let { …(show = true) }` 条件挂载，关闭时退场动画一次不播；
 * 退场期间用 [rememberLastNonNull] 保留的最后一份非空 info 继续渲染。
 */
@Composable
private fun SyncConflictChoiceDialog(
    info: SyncConflictInfo?,
    busy: Boolean,
    onChoice: (SyncConflictChoice) -> Unit,
    onDismiss: () -> Unit,
) {
    val shown = rememberLastNonNull(info)
    val view = CloudSyncLogic.conflictDialog(isFirstSyncDivergence = shown?.isFirstSyncDivergence == true)
    val dark = isSystemInDarkTheme()
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = info != null,
        title = view.title,
        onDismissRequest = onDismiss,
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(
                text = view.message,
                style = MiuixTheme.textStyles.body2,
                color = Color(QingyuTheme.secondaryText(dark)),
                modifier = Modifier.fillMaxWidth(),
                textAlign = TextAlign.Center,
            )
            // 三个动作竖排整宽（Dart 对 3 动作竖排，原先塞同一行 10dp）；
            // 顺序：取消 → 保留本机（次） → 使用云端（主），与同族「取消在先、主操作收尾」一致。
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

/** 保留最后一次非空值：退场动画期间用它继续渲染（同 TimeSchemeHost 的同名私有件）。 */
@Composable
private fun <T : Any> rememberLastNonNull(current: T?): T? {
    var last by remember { mutableStateOf<T?>(null) }
    if (current != null) last = current
    return last
}
