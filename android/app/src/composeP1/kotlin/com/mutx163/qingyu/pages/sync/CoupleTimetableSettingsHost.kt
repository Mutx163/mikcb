package com.mutx163.qingyu.pages.sync

import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import com.mutx163.qingyu.pages.ShellWiring
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
 * ## 它负责的四件事
 *
 * 1. **造控制器**：`CoupleTimetableSettingsController`（纯 Kotlin，动作与状态判据都在那边）；
 * 2. **订阅**：控制器每次状态变化 `revision + 1`，这里当 `remember` 的 key 触发重组；
 * 3. **线程**：控制器里的动作是同步阻塞的（transport 是 JDK HTTP），这里统一丢到
 *    `Dispatchers.IO`，结果回主线程再弹 Toast —— 旧壳把阻塞调用直接放点击回调里，会卡整屏；
 * 4. **系统交互**：导入走 SAF「打开文档」、导出走 SAF「保存到…」（本仓没有声明 FileProvider，
 *    分享文件那条路走不通，理由见 [CoupleTransferAdapter] 的 KDoc）。
 *
 * ## 与 Dart 的一处已知差异（诚实清单）
 *
 * Dart 的「导出我的课表给对方」是**系统分享面板**（`share_plus` 发文件 + 分享文案）。
 * 本仓 `AndroidManifest.xml` 没有 `FileProvider` 声明，分享文件必然在 `getUriForFile`
 * 那一步失败；补那套声明属于打包决策。所以这里退一步：**让用户自己选保存位置**，
 * 存完用 ARB 里现成那句分享文案提示「发给对方后怎么导入」。行为差异记在审核文档里。
 */
@Composable
fun CoupleTimetableSettingsHost(
    wiring: ShellWiring,
    onBack: () -> Unit,
) {
    val appContext = LocalContext.current.applicationContext
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

    // 导出两段式：先生成正文 → 让用户选保存位置（SAF）→ 结果回调里再写。
    // 正文只经这一格状态在「点击」与「回调」之间传递，不落临时文件。
    val pendingExport = remember { mutableStateOf<String?>(null) }
    val saveDocLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument(CoupleTransferAdapter.MIME_JSON),
    ) { uri ->
        val content = pendingExport.value
        pendingExport.value = null
        if (uri == null || content == null) return@rememberLauncherForActivityResult
        val ok = transfer.writeUtf8(uri, content)
        Toast.makeText(
            appContext,
            // 存成功就把「发给对方后怎么用」直接说出来（ARB 里现成那句分享文案）；
            // 存失败绝不假装成功。
            if (ok) CoupleStrings.coupleTimetableShareText.zh else CoupleStrings.saveFailed.zh,
            Toast.LENGTH_LONG,
        ).show()
    }

    val controller = remember(configStore, partnerPort, transfer) {
        CoupleTimetableSettingsController(
            configStore = configStore,
            partnerPort = partnerPort,
            exportSink = { content, fileName ->
                pendingExport.value = content
                saveDocLauncher.launch(fileName)
                true
            },
        )
    }

    var revision by remember(controller) { mutableStateOf(0) }
    DisposableEffect(controller) {
        val listener = { revision += 1 }
        controller.addListener(listener)
        onDispose { controller.removeListener(listener) }
    }

    val scope = rememberCoroutineScope()
    val openDocLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument(),
    ) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        scope.launch {
            val text = withContext(Dispatchers.IO) { transfer.readUtf8(uri) }
            if (text == null) {
                Toast.makeText(
                    appContext,
                    CoupleStrings.importFileReadFailed.zh,
                    Toast.LENGTH_SHORT,
                ).show()
                return@launch
            }
            val result = withContext(Dispatchers.IO) { controller.importFromContent(text) }
            Toast.makeText(appContext, result.message, Toast.LENGTH_LONG).show()
        }
    }

    var showConnectSheet by remember { mutableStateOf(false) }
    var sheetTesting by remember { mutableStateOf(false) }
    var sheetConnecting by remember { mutableStateOf(false) }

    val viewState = remember(revision) { controller.viewState() }
    val config = remember(revision) { configStore.loadConfig() }

    CoupleTimetableSettingsPage(
        viewState = viewState,
        onBack = onBack,
        onAction = { actionId ->
            when (actionId) {
                CoupleTimetableSettingsLogic.WEBDAV_CONNECT -> showConnectSheet = true
                CoupleTimetableSettingsLogic.WEBDAV_PULL -> scope.launch {
                    val result = withContext(Dispatchers.IO) { controller.pullNow() }
                    Toast.makeText(appContext, result.message, Toast.LENGTH_LONG).show()
                }
                CoupleTimetableSettingsLogic.WEBDAV_UPLOAD -> scope.launch {
                    val result = withContext(Dispatchers.IO) { controller.uploadMine() }
                    Toast.makeText(appContext, result.message, Toast.LENGTH_LONG).show()
                }
                CoupleTimetableSettingsLogic.WEBDAV_DISCONNECT -> scope.launch {
                    val result = withContext(Dispatchers.IO) { controller.disconnect() }
                    // Dart 断开成功不弹提示；只有失败（保存失败）才说话。
                    result?.let { Toast.makeText(appContext, it.message, Toast.LENGTH_LONG).show() }
                }
                // 导出只组包 + 拉起「保存到…」，不跑网络，留主线程（要 startActivity）。
                CoupleTimetableSettingsLogic.COUPLE_EXPORT -> {
                    controller.exportMine()?.let {
                        Toast.makeText(appContext, it.message, Toast.LENGTH_LONG).show()
                    }
                }
                CoupleTimetableSettingsLogic.COUPLE_IMPORT -> {
                    openDocLauncher.launch(CoupleTransferAdapter.OPEN_MIME_TYPES)
                }
                CoupleTimetableSettingsLogic.COUPLE_UNLINK -> scope.launch {
                    val result = withContext(Dispatchers.IO) { controller.unlink() }
                    Toast.makeText(appContext, result.message, Toast.LENGTH_LONG).show()
                }
            }
        },
        onShiftWeekOffset = { delta ->
            controller.shiftWeekOffset(delta)?.let {
                Toast.makeText(appContext, it.message, Toast.LENGTH_SHORT).show()
            }
        },
        onPickColor = { rowIndex, hex ->
            controller.pickColor(rowIndex, hex)?.let {
                Toast.makeText(appContext, it.message, Toast.LENGTH_SHORT).show()
            }
        },
    )

    if (showConnectSheet) {
        CoupleWebdavConnectSheet(
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
                    Toast.makeText(
                        appContext,
                        if (ok) {
                            viewState.webdavSheetTexts.testSuccess
                        } else {
                            viewState.webdavSheetTexts.testFailed
                        },
                        Toast.LENGTH_SHORT,
                    ).show()
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
                        outcome.pullToast?.let {
                            Toast.makeText(appContext, it.message, Toast.LENGTH_LONG).show()
                        }
                    } else {
                        Toast.makeText(
                            appContext,
                            viewState.webdavSheetTexts.testFailed,
                            Toast.LENGTH_SHORT,
                        ).show()
                    }
                }
            },
        )
    }
}
