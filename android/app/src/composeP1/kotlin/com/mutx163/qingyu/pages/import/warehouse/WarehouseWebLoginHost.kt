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
import com.mutx163.qingyu.app.TimetableRepository
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
import java.util.UUID

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
 * | 脚本回传 `courses` | [WarehouseCourseImportLogic] 解析 → [WarehouseCourseWriteBack] 走仓储原子入口写回当前档案 |
 * | 网页 `confirm` / `prompt` / 单选 | [warehouseBridgeFallbackAnswer] 给确定默认值并注入回网页，避免脚本永远挂起 |
 * | 桥接消息 | 已由页面过了 §6.2 门禁；这里按类型分发 |
 *
 * ## 诚实边界（别删）
 *
 * 1. **抓回来的课直接写当前档案**：没有 Dart 的「替换/合并」弹窗与开学日/周次映射弹窗；
 *    默认策略是「空表替换、非空合并」（见 [WarehouseCourseWriteBack]）。周次按脚本原值写入，
 *    不做 `firstCourseWeek` 平移。
 * 2. **没有原生对话框**：`prompt` / 单选用脚本自带默认值回答，`saveCourseConfig` /
 *    `savePresetTimeSlots` 诚实返回 `false`；用户无法在原生界面里改选择。
 * 3. **登录态探针/自动填充未接**（`WarehouseWebLoginPage` 的 remembered-account 相关回调仍是默认空实现），
 *    与 i2-webview 认领文件里列的缺件一致。
 * 4. 宏录制/快捷导入仍未移植，按钮给「不可用」实话。
 * 5. 真机未验：仓库能不能拉到脚本、教务站能不能登录并通过脚本抓课，只有用户真机可见。
 */

private const val LOG_TAG = "WarehouseWebLogin"

/**
 * @param state 选校/适配器暂存（壳里 `remember { WarehouseShellState() }`）
 * @param prefs 自定义登录地址（键名与 Dart 逐字一致）
 * @param repository 脚本抓回的课表写到哪；**壳必须传 `wiring.timetable`**。
 *   为 null 时用户会看到「不可用」提示（不要拿假成功糊弄）。
 * @param onOpenPage 壳的导航入口；没有选中适配器时退回选校页
 */
@Composable
fun WarehouseWebLoginHost(
    state: WarehouseShellState,
    prefs: WarehouseImportPrefs,
    onBack: () -> Unit,
    onOpenPage: (String) -> Unit,
    repository: TimetableRepository? = null,
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

    // 受信登录地址（loginAttempt 门禁的「受信 host」放行锚点）：适配器登记地址 +
    // 受信自定义地址，与 Dart 侧同一来源口径；host 化在门禁里做。
    val trustedLoginUrls = remember(adapter.importUrl, customUrl) {
        listOfNotNull(adapter.importUrl.takeIf { it.isNotBlank() }, customUrl?.takeIf { it.isNotBlank() })
    }

    val controller = rememberWarehouseWebViewController()
    val service = remember(fetch) { WarehouseRepositoryService(fetch) }
    var session by remember(target.loginUrl) {
        mutableStateOf(initialWarehouseWebLoginSession(target))
    }
    var isExecuting by remember { mutableStateOf(false) }
    // 脚本执行期窗口：注入成功到 complete/error/网页跳转之间。
    // 回传的 courses 与对话框回答只在这个窗口内处理——不然任意网页都能塞一份假课表。
    var scriptActive by remember(target.loginUrl) { mutableStateOf(false) }

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
                            scriptActive = true
                        }

                        is WarehouseLoad.Failed -> {
                            scriptActive = false
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

    fun showToasts(messages: List<String>) {
        for (message in messages) {
            Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
        }
    }

    /** 把写回结果翻成用户能看懂的几句话（全部取 ARB 原文，不在代码里硬写中文）。 */
    fun messagesFor(result: WarehouseCourseWriteBack.PayloadResult): List<String> {
        val messages = mutableListOf<String>()
        when (result) {
            is WarehouseCourseWriteBack.PayloadResult.InvalidFormat ->
                messages.add(WarehouseStrings.invalidCourseDataFormat.zh)

            is WarehouseCourseWriteBack.PayloadResult.NoImportableCourses -> {
                messages.add(WarehouseStrings.noImportableCoursesFromScript.zh)
                if (result.droppedCount > 0) {
                    messages.add(
                        WarehouseStrings.importCourseRecordsDropped.filled(
                            "imported" to result.receivedCount.toString(),
                            "dropped" to result.droppedCount.toString(),
                        ),
                    )
                }
            }

            is WarehouseCourseWriteBack.PayloadResult.Failed -> {
                Log.e(LOG_TAG, "course write-back failed: ${result.cause?.javaClass?.simpleName}")
                messages.add(WarehouseStrings.importFailedStatus.zh)
            }

            is WarehouseCourseWriteBack.PayloadResult.Done -> {
                val outcome = result.outcome
                when {
                    outcome.importedCount == 0 -> messages.add(WarehouseStrings.importNoCourseChanges.zh)
                    outcome.mode == WarehouseCourseWriteBack.Mode.REPLACE ->
                        messages.add(
                            WarehouseStrings.importOverwriteCount.filled(
                                "count" to outcome.importedCount.toString(),
                            ),
                        )

                    else -> messages.add(
                        WarehouseStrings.importUpdatedCount.filled(
                            "count" to outcome.importedCount.toString(),
                        ),
                    )
                }
                if (outcome.droppedCount > 0) {
                    messages.add(
                        WarehouseStrings.importCourseRecordsDropped.filled(
                            "imported" to result.receivedCount.toString(),
                            "dropped" to outcome.droppedCount.toString(),
                        ),
                    )
                }
                if (outcome.weeksTrimmedCount > 0) {
                    messages.add(
                        WarehouseStrings.importCourseWeeksTrimmed.filled(
                            "count" to outcome.weeksTrimmedCount.toString(),
                        ),
                    )
                }
            }
        }
        return messages
    }

    fun handleCoursesMessage(raw: String) {
        val payload = warehouseBridgeCoursesPayload(raw)
        if (payload == null) {
            Log.w(LOG_TAG, "courses message without payload")
            return
        }
        val repo = repository
        if (repo == null) {
            // 壳没传仓储：不许假装导入成功。
            Log.w(LOG_TAG, "courses received but repository is not wired")
            showToasts(listOf(WarehouseStrings.importFailedStatus.zh))
            return
        }
        scope.launch {
            val result = withContext(Dispatchers.IO) {
                WarehouseCourseWriteBack.applyPayload(
                    repository = repo,
                    payload = payload,
                    unknownTeacher = WarehouseStrings.unknownTeacher.zh,
                    unknownLocation = WarehouseStrings.unknownLocation.zh,
                    idFactory = { UUID.randomUUID().toString() },
                )
            }
            Log.i(
                LOG_TAG,
                "courses write-back result=${result.javaClass.simpleName}",
            )
            showToasts(messagesFor(result))
        }
    }

    /**
     * 网页对话框降级：给一个确定的默认回答，避免脚本的 Promise 永远悬着。
     * 原生对话框还没移植，所以这里只保证「不挂起 + 有日志」，不代表用户真的做了选择。
     */
    fun handleDialogFallback(raw: String) {
        val answer = warehouseBridgeFallbackAnswer(raw)
        if (answer == null) {
            Log.w(LOG_TAG, "bridge dialog ignored: unsafe requestId or unknown type")
            return
        }
        val script = warehouseBridgeResolveScript(answer.requestId, answer.jsonValue)
        if (script.isEmpty()) return
        controller.injectJavaScript(script)
        Log.i(
            LOG_TAG,
            "bridge dialog ${answer.kind.messageType} answered with fallback value",
        )
    }

    fun handleBridgeMessage(raw: String) {
        val type = warehouseBridgeMessageType(raw)
        when (type) {
            "courses" -> {
                if (scriptActive) {
                    handleCoursesMessage(raw)
                } else {
                    Log.w(LOG_TAG, "courses message dropped outside import execution")
                }
            }

            "confirm",
            "prompt",
            "singleSelection",
            "saveCourseConfig",
            "savePresetTimeSlots",
            -> {
                if (scriptActive) {
                    handleDialogFallback(raw)
                } else {
                    Log.w(LOG_TAG, "dialog message dropped outside import execution: $type")
                }
            }

            "complete" -> {
                scriptActive = false
                Log.i(LOG_TAG, "bridge complete")
            }

            "error" -> {
                scriptActive = false
                Log.w(LOG_TAG, "bridge error reported by adapter script")
                showToasts(listOf(WarehouseStrings.courseImportScriptFailed.zh))
            }

            else -> Log.i(LOG_TAG, "bridge message type=$type")
        }
    }

    WarehouseWebLoginPage(
        title = school.name,
        sessionState = session,
        webViewController = controller,
        trustedLoginUrls = trustedLoginUrls,
        onBack = onBack,
        onWebProgress = { progress ->
            session = session.withStage(WarehouseWebLoginWebState.stageForProgress(progress))
        },
        onWebPageStarted = { url ->
            // 新导航会重建 JS 上下文：上一轮的脚本窗口随之结束。
            scriptActive = false
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
            // 数据回传（courses）与对话框降级在这里分发；正文不进日志（课表里有学号/课表内容）。
            handleBridgeMessage(raw)
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
