package com.mutx163.qingyu.pages.import.warehouse

import android.util.Log
import android.widget.Toast
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * `g2.webLogin` 的**真宿主**（F28，补派工大表 I2 的最后一段壳侧缺口）。
 *
 * ## 之前为什么是空态
 *
 * 不是「没有学校数据」：学校清单（`index/root_index.yaml`）与适配器（`resources/<学校>/adapters.yaml`）
 * 早就由 [WarehouseRepositoryService] 真网络拉取，`g2.warehouseImport` / `g2.schoolAdapters` /
 * `g2.adapterDetail` 也已接上真宿主。**只有 `g2.webLogin` 这一条**还挂在
 * `ShellWarehouseEmptyPage` 上（壳里没接），所以用户永远看到「未找到有效的教务登录地址」。
 * 本文件把这条链路补齐，壳侧只需一行分支（见 `WIRING-NOTE.md` 与认领文件）。
 *
 * ## 这一页现在做什么
 *
 * | 步骤 | 落点 |
 * |---|---|
 * | 取当前学校 + 适配器 | [WarehouseShellState]（选校页/适配器页已写入） |
 * | 解析登录地址 | [resolveWarehouseWebLoginTarget]：自定义覆盖 > 仓库 `import_url` |
 * | 真 WebView | [WarehouseWebLoginPage] → [WarehouseWebViewHost] |
 * | 加载进度 / 错误上屏 | [WarehouseWebLoginWebState]（错误文案优先取 ARB） |
 * | 「执行导入脚本」 | 拉脚本（[WarehouseRepositoryService.loadAdapterScript]，含 SHA-256 校验）→ 包桥接垫片 → 注入 |
 * | 桥接消息 | 已由页面过了 §6.2 门禁；这里只记类型日志 |
 *
 * ## 诚实边界（别删）
 *
 * 1. **没有写回课表**：脚本回传的 `courses` 消息到这里只记日志；写课表要 `TimetableRepository`，
 *    不在本泳道作用域，属上层接线。
 * 2. **没有原生对话框**：脚本调 `AndroidBridgePromise.showAlert/showPrompt/showSingleSelection/...`
 *    会一直等原生回话；回答要上层用 [warehouseBridgeResolveScript] 注入（对话框 UI 未接）。
 * 3. **登录态探针/自动填充未接**（`WarehouseWebLoginPage` 的 remembered-account 相关回调仍是默认空实现），
 *    与 i2-webview 认领文件里列的缺件一致。
 * 4. 宏录制/快捷导入仍未移植，按钮给「不可用」实话。
 * 5. 真机未验：仓库能不能拉到脚本、教务站能不能登录并通过脚本抓课，只有用户真机可见。
 */

private const val LOG_TAG = "WarehouseWebLogin"

/**
 * @param state 选校/适配器暂存（壳里 `remember { WarehouseShellState() }`）
 * @param prefs 自定义登录地址（键名与 Dart 逐字一致）
 * @param onOpenPage 壳的导航入口；没有选中适配器时退回选校页
 */
@Composable
fun WarehouseWebLoginHost(
    state: WarehouseShellState,
    prefs: WarehouseImportPrefs,
    onBack: () -> Unit,
    onOpenPage: (String) -> Unit,
    fetch: WarehouseFetch = remember { WarehouseJdkFetch() },
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val school = state.school
    val adapter = state.adapter

    if (school == null || adapter == null) {
        // 直接从页面清单点进来时没有暂存：退回选校页，而不是拿演示学校凑合。
        LaunchedEffect(Unit) { onOpenPage(WarehouseRoutes.IMPORT_PICKER) }
        return
    }

    val customUrl = prefs.customImportUrl(adapter.id)
    val target = remember(adapter.id, adapter.importUrl, customUrl) {
        resolveWarehouseWebLoginTarget(adapter, customUrl)
    }
    if (target == null) {
        // 自定义地址与仓库地址都不合法：给一句实话，不加载空白网页。
        WarehouseWebLoginMissingUrlPage(onBack = onBack)
        return
    }

    val controller = rememberWarehouseWebViewController()
    val service = remember(fetch) { WarehouseRepositoryService(fetch) }
    var session by remember(target.loginUrl) {
        mutableStateOf(initialWarehouseWebLoginSession(target))
    }
    var isExecuting by remember { mutableStateOf(false) }

    fun executeImportScript() {
        if (isExecuting) return
        when (val plan = planWarehouseScriptExecution(session.stage, school, adapter)) {
            is WarehouseScriptExecutionPlan.Blocked -> {
                Log.w(LOG_TAG, "execute import blocked: ${plan.reason}")
                Toast.makeText(
                    context,
                    WarehouseStrings.courseImportScriptFailed.zh,
                    Toast.LENGTH_SHORT,
                ).show()
            }

            is WarehouseScriptExecutionPlan.Ready -> {
                isExecuting = true
                session = session.withStage(WarehouseWebLoginStage.INJECTING_SCRIPT)
                scope.launch {
                    val loaded = withContext(Dispatchers.IO) {
                        service.loadAdapterScript(school, adapter)
                    }
                    when (loaded) {
                        is WarehouseLoad.Ok -> {
                            // 对齐 Dart：脚本外面要包一层 AndroidBridge / shiguangBridge 垫片，
                            // 否则上游脚本找不到桥对象会直接抛错。
                            controller.injectJavaScript(
                                warehouseImportScriptWrapper(
                                    script = loaded.value,
                                    confirmText = WarehouseStrings.confirmImportAction.zh,
                                ),
                            )
                            session = session.withStage(WarehouseWebLoginStage.EXECUTING)
                        }

                        is WarehouseLoad.Failed -> {
                            Log.w(
                                LOG_TAG,
                                "adapter script load failed code=${loaded.code} attempts=${loaded.attempts}",
                            )
                            session = session.withStage(
                                WarehouseWebLoginStage.ERROR,
                                WarehouseStrings.courseImportScriptFailed.zh,
                            )
                            Toast.makeText(
                                context,
                                WarehouseStrings.courseImportScriptFailed.zh,
                                Toast.LENGTH_SHORT,
                            ).show()
                        }
                    }
                    isExecuting = false
                }
            }
        }
    }

    WarehouseWebLoginPage(
        title = school.name,
        sessionState = session,
        webViewController = controller,
        onBack = onBack,
        onWebProgress = { progress ->
            session = session.withStage(WarehouseWebLoginWebState.stageForProgress(progress))
        },
        onWebPageStarted = { url ->
            session = session.copy(
                currentUrl = url,
                stage = WarehouseWebLoginStage.LOADING,
                errorMessage = null,
            )
        },
        onWebPageFinished = { url ->
            // 主框架报过错之后平台仍会回调 finished；不要把 ERROR 覆盖回 LOADED，
            // 否则用户看到的错误一闪就没（真正的新导航会先经过 onPageStarted 重置为 LOADING）。
            session = if (session.stage == WarehouseWebLoginStage.ERROR) {
                session.copy(currentUrl = url)
            } else {
                session.copy(
                    currentUrl = url,
                    stage = WarehouseWebLoginWebState.stageForProgress(100),
                    errorMessage = null,
                )
            }
        },
        onWebError = { error ->
            val message = WarehouseWebLoginWebState.errorText(error) { key ->
                when (key) {
                    WarehouseStrings.importCleartextBlockedHint.key ->
                        WarehouseStrings.importCleartextBlockedHint.zh

                    else -> null
                }
            }
            session = session.copy(
                stage = WarehouseWebLoginWebState.stageForError(),
                errorMessage = message,
            )
        },
        onWebBridgeMessage = { raw ->
            // 能走到这里的消息已经过页面的 §6.2 门禁（UI 类消息只在 EXECUTING 放行）。
            // 数据回传（courses / saveCourseConfig / ...）要写进课表，属上层接线；
            // 这里只记类型，不记正文（课表数据里有学号/课表内容，不进日志）。
            Log.i(LOG_TAG, "bridge message type=${warehouseBridgeMessageType(raw)}")
        },
        onMoreOptions = {
            val url = controller.liveUrl() ?: session.currentUrl
            if (url.isBlank()) {
                toastUnavailable(context, "copy address: empty current url")
            } else {
                copyTextToClipboard(context, "warehouse-current-url", url)
                Toast.makeText(
                    context,
                    WarehouseStrings.copiedCurrentAddress.zh,
                    Toast.LENGTH_SHORT,
                ).show()
            }
        },
        onToggleMacroRecording = {
            toastUnavailable(context, "macro recording: engine not ported (F08-8c)")
        },
        onExecuteImport = { executeImportScript() },
    )
}

/**
 * 没有任何可用登录地址时的诚实空态（不加载空白 WebView）。
 *
 * 骨架/列表/卡片全部走共享套件（R1/R2/R3）；文案取 ARB 原文，不在 Kotlin 里另写。
 */
@Composable
private fun WarehouseWebLoginMissingUrlPage(onBack: () -> Unit) {
    QingyuPageScaffold(
        title = WarehouseStrings.webLoginImport.zh,
        onBack = onBack,
    ) {
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
        ) {
            item(key = "missing-url") {
                QingyuCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = QingyuPageCardMargin, vertical = 12.dp),
                    insideMargin = QingyuCardDefaults.ContentInsideMargin,
                ) {
                    Text(
                        text = WarehouseStrings.noValidWarehouseLoginUrl.zh,
                        style = MiuixTheme.textStyles.body1,
                        color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                    )
                }
            }
        }
    }
}
