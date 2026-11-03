package com.mutx163.qingyu.pages.sync

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.mutx163.qingyu.pages.ShellWiring
import com.mutx163.qingyu.pages.transfer.AppToastCapsule
import com.mutx163.qingyu.platform.AndroidTransferShareAdapter
import com.mutx163.qingyu.platform.CoupleConfigStoreImpl
import com.mutx163.qingyu.platform.CouplePartnerPortImpl
import com.mutx163.qingyu.platform.CoupleTransferAdapter
import com.mutx163.qingyu.platform.KeystoreSecretCipher
import com.mutx163.qingyu.platform.PrefsKeyValueStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * 情侣课表设置页的**宿主**（C1 的另一半：把渲染层接到真数据、真动作、真系统交互上）。
 *
 * ## 为什么单独一个文件、而不是塞进 `ShellPageIndex`
 *
 * `ShellPageIndex` 是一千多行的路由大表，每个页面写一段接线会让它继续膨胀；
 * 更实际的理由是**并发写冲突**：那张表同时被别的批次改（作息/时间模板等），
 * 在这里单开一个文件，索引里只留一行调用，冲突面最小。
 *
 * ## 它负责的五件事
 *
 * 1. **造控制器**：`CoupleTimetableSettingsController`（纯 Kotlin，动作与状态判据都在那边）；
 * 2. **订阅**：控制器每次状态变化 `revision + 1`，这里当 `remember` 的 key 触发重组；
 * 3. **回前台重读**：`ON_RESUME → controller.refresh()`（别处改过绑定后回到本页能看见）。
 *    旧版只在构造时读一次，从「导入批次」回来还是旧数据；
 * 4. **线程**：控制器里的动作是同步阻塞的（transport 是 JDK HTTP），这里统一丢到
 *    `Dispatchers.IO`，结果回主线程再提示；
 * 5. **系统交互**：导入走 SAF「打开文档」、导出**优先系统分享面板**（Dart 同款），
 *    分享面板起不来时才退回 SAF「保存到…」。
 *
 * ## 2026-10-29 二轮修复（P1）
 *
 * 旧版导出只走 SAF「保存到…」，理由是「本仓 `AndroidManifest.xml` 没有 `FileProvider`
 * 声明，分享文件必然失败」。**这条理由在当天的 `7c8d11b6` 之后就不成立了**：
 * 该提交给 manifest 注册了 `${applicationId}.fileprovider`（见 `AndroidManifest.xml`
 * 的 `<provider>` 段与 `res/xml/file_paths.xml` 的 `transfer_share` 路径）。
 * 所以现在按 Dart 的口径走系统分享面板，SAF 只作兜底——不让用户的导出凭空消失。
 *
 * ## 提示样式
 *
 * 用同族的共享件 [AppToastCapsule]（Dart `showAppToast` 的自绘胶囊），不再用系统
 * `android.widget.Toast`：Dart 侧两页都是应用内胶囊，系统 Toast 位置与样式都不同。
 */
@Composable
fun CoupleTimetableSettingsHost(
    wiring: ShellWiring,
    onBack: () -> Unit,
) {
    val appContext = LocalContext.current.applicationContext
    val dark = isSystemInDarkTheme()
    val prefs = remember(appContext) { PrefsKeyValueStore(appContext) }
    val configStore = remember(prefs) {
        CoupleConfigStoreImpl(
            store = prefs,
            // 与云同步**不是同一把钥匙**：密钥库别名分开，一侧失效不牵连另一侧。
            cipher = KeystoreSecretCipher(alias = "qingyu_couple_webdav"),
        )
    }
    val partnerPort = remember(wiring, prefs) { CouplePartnerPortImpl(wiring.timetable, prefs) }
    val transfer = remember(appContext) { CoupleTransferAdapter(appContext) }
    val shareAdapter = remember(appContext) { AndroidTransferShareAdapter(appContext) }

    // 应用内提示（一次一条，2 秒自动消失）。null = 不显示。
    var toast by remember { mutableStateOf<String?>(null) }
    fun notify(message: String) {
        toast = message
    }

    // 导出两段式保底：分享面板起不来时，正文经这一格交给 SAF 回调。
    val pendingExport = remember { mutableStateOf<String?>(null) }
    val saveDocLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument(CoupleTransferAdapter.MIME_JSON),
    ) { uri ->
        val content = pendingExport.value
        pendingExport.value = null
        if (uri == null || content == null) return@rememberLauncherForActivityResult
        val ok = transfer.writeUtf8(uri, content)
        notify(
            // 存成功就把「发给对方后怎么用」直接说出来（ARB 里现成那句分享文案）；
            // 存失败绝不假装成功。
            if (ok) CoupleStrings.coupleTimetableShareText.zh else CoupleStrings.saveFailed.zh,
        )
    }

    val controller = remember(configStore, partnerPort, transfer) {
        CoupleTimetableSettingsController(
            configStore = configStore,
            partnerPort = partnerPort,
            exportSink = { content, fileName ->
                // Dart `_exportForPartner` 走 share_plus（系统分享面板）。
                val outcome = shareAdapter.share(
                    fileName = fileName,
                    content = content,
                    shareText = CoupleStrings.coupleTimetableShareText.zh,
                    shareSubject = CoupleStrings.coupleTimetableShareSubject.zh,
                )
                if (outcome is AndroidTransferShareAdapter.Outcome.Launched) {
                    true
                } else {
                    // provider 不可用 / 没有可接收的应用 / 拉起失败 ⇒ 退回「保存到…」。
                    pendingExport.value = content
                    runCatching { saveDocLauncher.launch(fileName) }.isSuccess
                }
            },
        )
    }

    var revision by remember(controller) { mutableStateOf(0) }
    DisposableEffect(controller) {
        val listener = { revision += 1 }
        controller.addListener(listener)
        onDispose { controller.removeListener(listener) }
    }

    // 回前台重读：别处（导入批次 / 云同步恢复）改过绑定后，本页不该还停在旧值。
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner, controller) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                controller.refresh()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    val scope = rememberCoroutineScope()
    val openDocLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument(),
    ) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        scope.launch {
            val text = withContext(Dispatchers.IO) { transfer.readUtf8(uri) }
            if (text == null) {
                notify(CoupleStrings.importFileReadFailed.zh)
                return@launch
            }
            val result = withContext(Dispatchers.IO) { controller.importFromContent(text) }
            notify(result.message)
        }
    }

    var showConnectSheet by remember { mutableStateOf(false) }
    var sheetTesting by remember { mutableStateOf(false) }
    var sheetConnecting by remember { mutableStateOf(false) }

    val viewState = remember(revision) { controller.viewState() }
    val config = remember(revision) { configStore.loadConfig() }

    Box(modifier = Modifier.fillMaxSize()) {
        CoupleTimetableSettingsPage(
            viewState = viewState,
            onBack = onBack,
            onAction = { actionId ->
                when (actionId) {
                    CoupleTimetableSettingsLogic.WEBDAV_CONNECT -> showConnectSheet = true
                    CoupleTimetableSettingsLogic.WEBDAV_PULL -> scope.launch {
                        val result = withContext(Dispatchers.IO) { controller.pullNow() }
                        notify(result.message)
                    }
                    CoupleTimetableSettingsLogic.WEBDAV_UPLOAD -> scope.launch {
                        val result = withContext(Dispatchers.IO) { controller.uploadMine() }
                        notify(result.message)
                    }
                    CoupleTimetableSettingsLogic.WEBDAV_DISCONNECT -> scope.launch {
                        val result = withContext(Dispatchers.IO) { controller.disconnect() }
                        // Dart 断开成功不弹提示；只有失败（保存失败）才说话。
                        result?.let { notify(it.message) }
                    }
                    // 导出只组包 + 拉起分享面板，不跑网络，留主线程（要 startActivity）。
                    CoupleTimetableSettingsLogic.COUPLE_EXPORT -> {
                        controller.exportMine()?.let { notify(it.message) }
                    }
                    CoupleTimetableSettingsLogic.COUPLE_IMPORT -> {
                        openDocLauncher.launch(CoupleTransferAdapter.OPEN_MIME_TYPES)
                    }
                    CoupleTimetableSettingsLogic.COUPLE_UNLINK -> scope.launch {
                        val result = withContext(Dispatchers.IO) { controller.unlink() }
                        notify(result.message)
                    }
                }
            },
            onShiftWeekOffset = { delta ->
                controller.shiftWeekOffset(delta)?.let { notify(it.message) }
            },
            onPickColor = { rowIndex, hex ->
                controller.pickColor(rowIndex, hex)?.let { notify(it.message) }
            },
        )

        val currentToast = toast
        if (currentToast != null) {
            AppToastCapsule(
                message = currentToast,
                dark = dark,
                onDismiss = { toast = null },
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(horizontal = 16.dp, vertical = 32.dp),
            )
        }
    }

    // 弹层常驻组合（2026-11-03 弹层审计）：`show` 由 showConnectSheet 驱动，
    // 原先 `if (showConnectSheet)` 条件挂载会让关闭时的 260ms 退场动画一次不播。
    CoupleWebdavConnectSheet(
        show = showConnectSheet,
        texts = viewState.webdavSheetTexts,
        initialUsername = config.username,
        initialSlot = config.normalizedMySlot,
        testing = sheetTesting,
        connecting = sheetConnecting,
        onDismissRequest = { showConnectSheet = false },
        onTest = { username, password ->
            scope.launch {
                sheetTesting = true
                val ok = withContext(Dispatchers.IO) {
                    controller.testConnection(username, password)
                }
                sheetTesting = false
                notify(
                    if (ok) {
                        viewState.webdavSheetTexts.testSuccess
                    } else {
                        viewState.webdavSheetTexts.testFailed
                    },
                )
            }
        },
        onConfirm = { username, password, mySlot ->
            scope.launch {
                sheetConnecting = true
                val outcome = withContext(Dispatchers.IO) {
                    controller.connect(username, password, mySlot)
                }
                sheetConnecting = false
                if (outcome.ok) {
                    showConnectSheet = false
                    outcome.pullToast?.let { notify(it.message) }
                } else {
                    notify(viewState.webdavSheetTexts.testFailed)
                }
            }
        },
    )
}
