package com.mutx163.qingyu.pages.sync

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

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

    // 进页首次加载：已连接时拉一次远端备份列表（否则备份区恒空，像云端没有备份）。
    LaunchedEffect(controller) {
        withContext(Dispatchers.IO) { controller.refreshOnEnter() }
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
        onSyncNow = { scope.launch { withContext(Dispatchers.IO) { controller.syncNow() } } },
        onCreateBackup = { scope.launch { withContext(Dispatchers.IO) { controller.createBackup() } } },
        onOpenBackup = onOpenBackup,
        onViewAllBackups = onViewAllBackups,
        onMaxCountSelected = { controller.selectMaxCount(it) },
        onMaxAgeSelected = { controller.selectMaxAge(it) },
        onManualProtectedChange = { controller.setManualBackupProtected(it) },
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

    // 同云同步页：进页首次加载，避免整页恒空。
    LaunchedEffect(controller) {
        withContext(Dispatchers.IO) { controller.refreshOnEnter() }
    }

    CloudBackupListPage(
        viewState = viewState,
        onBack = onBack,
        onCreateBackup = { scope.launch { withContext(Dispatchers.IO) { controller.createBackup() } } },
        onOpenBackup = onOpenBackup,
    )
}
