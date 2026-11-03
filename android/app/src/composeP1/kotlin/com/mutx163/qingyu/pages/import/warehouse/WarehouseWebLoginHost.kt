package com.mutx163.qingyu.pages.import.warehouse

import android.util.Log
import android.widget.Toast
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
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
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.pages.import.ImportPreviewDialog
import java.time.LocalDateTime
import java.util.UUID
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
 * | 脚本回传 `courses` | [WarehouseCourseImportLogic] 解析 → 已有课时弹「替换/合并」（I2-3）→ [WarehouseCourseWriteBack] 写回当前档案 |
 * | 网页 `confirm` / `prompt` / 单选 | **原生弹窗**（I2-1，[WarehouseScriptConfirmDialog] 等），回答经 [warehouseBridgeResolveScript] 回网页 |
 * | `saveCourseConfig` | 解析并落盘学期周数/开学日（I2-2，[resolveWarehouseCourseConfig]），回答 true/false |
 * | 宏录制（I2-4） | 录制 JS 注入/重注 + `macro:event` 收集 + [WarehouseMacroRecordingConverter] 转步骤 + [WarehouseMacroStore] 落盘 |
 * | 桥接消息 | 已由页面过了 §6.2 门禁；这里按类型分发 |
 *
 * ## 诚实边界（别删）
 *
 * 1. **开学日/周次映射弹窗仍未接**：抓回的课周次按脚本原值写入，不做 `firstCourseWeek` 平移
 *    （Dart 那张 `pickImportSemesterConfig` 还没移植；「替换/合并」选择与它拆开，先做前者）。
 * 2. **`savePresetTimeSlots` 仍诚实回 `false`**：作息切换链路（`_applyPendingImportedSectionsIfNeeded`
 *    + 恢复点 + 轻屿专属条目）未移植；`saveCourseConfig` 已真落盘。
 * 3. **登录态探针/自动填充未接**（`WarehouseWebLoginPage` 的 remembered-account 相关回调仍是默认空实现），
 *    与 i2-webview 认领文件里列的缺件一致。
 * 4. **快捷导入（宏回放）未移植**：宏能录能存、列表能显示「快捷导入」入口，
 *    但点了仍是「不可用」实话——回放引擎（`warehouse_macro_replayer`）是另一刀。
 * 5. 真机未验：仓库能不能拉到脚本、教务站能不能登录并通过脚本抓课，只有用户真机可见。
 */

private const val LOG_TAG = "WarehouseWebLogin"

/** 录制收尾的「保存为快捷导入？」弹窗状态。 */
private data class WarehouseMacroSavePrompt(
    val steps: List<WarehouseMacroStep>,
    /** 列表页「录制导入」一录到底流程：用 Dart 的自动录制文案变体。 */
    val autoRecord: Boolean,
    /** 导入成功后自动收尾（Dart `_completeMacroAndPop`）：成功计数记 1，且收尾后返回上一页。 */
    val completedImport: Boolean,
)

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
    // 宏存储与 Dart 共享同一份 SharedPreferences（键名逐字一致），借 prefs 的底层 store。
    val macroStore = remember(prefs) { WarehouseMacroStore(prefs.store) }
    var session by remember(target.loginUrl) {
        mutableStateOf(initialWarehouseWebLoginSession(target))
    }
    var isExecuting by remember { mutableStateOf(false) }
    // 脚本执行期窗口：注入成功到 complete/error/网页跳转之间。
    // 回传的 courses 与对话框回答只在这个窗口内处理——不然任意网页都能塞一份假课表。
    var scriptActive by remember(target.loginUrl) { mutableStateOf(false) }

    // ---- I2-1：脚本对话框的待答请求（同一时刻至多一个：脚本是 await 串行的） ----
    var pendingDialog by remember { mutableStateOf<WarehouseBridgeDialogRequest?>(null) }
    // ---- I2-3：已解析、等用户在「替换/合并」里做选择的课程 ----
    var pendingImport by remember { mutableStateOf<WarehouseCourseWriteBack.PayloadParse.Parsed?>(null) }
    // ---- I2-4：宏录制暂存 ----
    val macroEvents = remember { mutableStateListOf<Map<String, Any?>>() }
    val macroDialogResponses = remember { mutableStateMapOf<String, Any?>() }
    var macroAutoRecord by remember { mutableStateOf(false) }
    var macroSavePrompt by remember { mutableStateOf<WarehouseMacroSavePrompt?>(null) }

    val recording = session.macroState == WarehouseMacroActionState.RECORDING

    fun showToasts(messages: List<String>) {
        for (message in messages) {
            Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
        }
    }

    /** 把回答 resolve 回网页侧 Promise（requestId 白名单校验在 [warehouseBridgeResolveScript] 里）。 */
    fun resolveBridgeRequest(requestId: String, jsonValue: String) {
        val script = warehouseBridgeResolveScript(requestId, jsonValue)
        if (script.isEmpty()) return
        controller.injectJavaScript(script)
    }

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

    // ---- I2-4 宏录制 ----

    fun startMacroRecording(auto: Boolean) {
        if (isExecuting || scriptActive) {
            // Dart 在导入执行中禁用录制按钮（`onPress: _isExecutingImport ? null`）。
            Log.w(LOG_TAG, "macro recording start ignored: import executing")
            return
        }
        // 每次录制都从干净的事件流与应答表开始（Dart：避免上一次「停止但没存」泄漏进来）。
        macroEvents.clear()
        macroDialogResponses.clear()
        macroAutoRecord = auto
        session = session.copy(
            macroState = WarehouseMacroActionState.RECORDING,
            recordedStepsCount = 0,
        )
        controller.injectJavaScript(WarehouseMacroRecorderJs.INJECT_SCRIPT)
        showToasts(
            listOf(
                if (auto) {
                    WarehouseStrings.courseImportAutoRecordingStartedTip.zh
                } else {
                    WarehouseStrings.courseImportRecordingStartedTip.zh
                },
            ),
        )
    }

    /**
     * 收尾录制：先从页面 dump 剩余事件（桥不可用时事件仍留在 window 缓冲），
     * 再转步骤；空 → 实话提示并复位，非空 → 弹「保存为快捷导入？」。
     *
     * Dart 的 dump 会带上**全部**事件（含桥已逐条推过来的），重复由
     * [WarehouseMacroRecordingConverter.convert] 的五元组去重吸收。
     */
    fun stopMacroRecording(completedImport: Boolean) {
        session = session.copy(macroState = WarehouseMacroActionState.STOPPED)
        controller.evaluateJavaScript(WarehouseMacroRecorderJs.DUMP_SCRIPT) { dump ->
            val dumped = (MiniJson.tryParse(dump) as? List<*>).orEmpty()
            for (entry in dumped) {
                val event = (entry as? Map<*, *>)?.mapKeys { (key, _) -> key.toString() }
                if (event != null) {
                    macroEvents.add(event)
                }
            }
            val steps = WarehouseMacroRecordingConverter.convert(macroEvents.toList())
            if (steps.isEmpty()) {
                macroEvents.clear()
                macroDialogResponses.clear()
                session = session.copy(
                    macroState = WarehouseMacroActionState.IDLE,
                    recordedStepsCount = 0,
                )
                showToasts(listOf(WarehouseStrings.courseImportRecordingEmptyTip.zh))
                if (completedImport) onBack()
                return@evaluateJavaScript
            }
            macroSavePrompt = WarehouseMacroSavePrompt(
                steps = steps,
                autoRecord = macroAutoRecord,
                completedImport = completedImport,
            )
        }
    }

    fun saveMacroRecording(prompt: WarehouseMacroSavePrompt) {
        val now = LocalDateTime.now()
        val record = WarehouseMacroRecord(
            schoolId = school.id,
            adapterId = adapter.id,
            schoolName = school.name,
            adapterName = adapter.adapterName,
            importUrl = target.loginUrl,
            schoolResourceFolder = school.resourceFolder,
            adapterAssetJsPath = adapter.script,
            steps = prompt.steps,
            dialogResponses = macroDialogResponses.toMap(),
            createdAt = now,
            updatedAt = now,
            successfulImportCount = if (prompt.completedImport) 1 else 0,
            scriptPageUrl = sanitizeWarehouseScriptPageUrl(controller.liveUrl() ?: session.currentUrl),
            useDesktopMode = controller.isDesktopMode,
        )
        macroEvents.clear()
        macroDialogResponses.clear()
        session = session.copy(
            macroState = WarehouseMacroActionState.IDLE,
            recordedStepsCount = 0,
        )
        scope.launch {
            val saved = withContext(Dispatchers.IO) {
                try {
                    macroStore.saveMacro(record)
                    true
                } catch (error: Exception) {
                    Log.w(LOG_TAG, "macro save failed: ${error.message}")
                    false
                }
            }
            if (saved) {
                // 通知列表页重拉 macroMap/计数（导航回退不重跑 LaunchedEffect，靠版本号联动）。
                state.macrosVersion += 1
                showToasts(
                    listOf(
                        WarehouseStrings.courseImportRecordingSavedStatus.filled(
                            "count",
                            prompt.steps.size.toString(),
                        ),
                    ),
                )
                // Dart：保存后自动返回适配器列表，用户即可看到快捷导入按钮。
                onBack()
            } else {
                showToasts(listOf(WarehouseStrings.saveFailed.zh))
            }
        }
    }

    fun discardMacroRecording(prompt: WarehouseMacroSavePrompt) {
        macroEvents.clear()
        macroDialogResponses.clear()
        session = session.copy(
            macroState = WarehouseMacroActionState.IDLE,
            recordedStepsCount = 0,
        )
        // 导入成功后的自动收尾无论存不存都返回上一页（Dart `_completeMacroAndPop` 口径）；
        // 手动停止后丢弃则留在本页。
        if (prompt.completedImport) onBack()
    }

    // ---- I2-3 课程写回（含「替换/合并」选择） ----

    fun applyCourses(
        parsed: WarehouseCourseWriteBack.PayloadParse.Parsed,
        requestedMode: WarehouseCourseWriteBack.Mode?,
    ) {
        val repo = repository ?: return
        scope.launch {
            val result = withContext(Dispatchers.IO) {
                WarehouseCourseWriteBack.applyParsed(repo, parsed, requestedMode)
            }
            Log.i(LOG_TAG, "courses write-back result=${result.javaClass.simpleName}")
            showToasts(messagesFor(result))
            // 导入成功且正在录制：自动收尾录制并询问保存（Dart `_completeMacroAndPop`）。
            val done = result as? WarehouseCourseWriteBack.PayloadResult.Done
            if (done != null && done.outcome.importedCount > 0 && recording) {
                stopMacroRecording(completedImport = true)
            }
        }
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
            val parsed = withContext(Dispatchers.IO) {
                WarehouseCourseWriteBack.parsePayload(
                    payload = payload,
                    unknownTeacher = WarehouseStrings.unknownTeacher.zh,
                    unknownLocation = WarehouseStrings.unknownLocation.zh,
                    idFactory = { UUID.randomUUID().toString() },
                )
            }
            when (parsed) {
                is WarehouseCourseWriteBack.PayloadParse.InvalidFormat ->
                    showToasts(listOf(WarehouseStrings.invalidCourseDataFormat.zh))

                is WarehouseCourseWriteBack.PayloadParse.Parsed -> {
                    if (parsed.courses.isNotEmpty() && repo.snapshot.courses.isNotEmpty()) {
                        // 已有课：必须让用户在「更新（合并）/覆盖（替换）」之间明确选一个
                        // （Dart `askImportReplaceExisting`；空表直接 REPLACE 不问）。
                        pendingImport = parsed
                    } else {
                        applyCourses(parsed, requestedMode = null)
                    }
                }
            }
        }
    }

    // ---- I2-1 原生脚本对话框 ----

    fun handleNativeDialogMessage(raw: String) {
        val request = warehouseBridgeDialogRequest(raw)
        if (request == null) {
            Log.w(LOG_TAG, "bridge dialog ignored: unsafe requestId or unknown type")
            return
        }
        if (pendingDialog != null) {
            // 脚本 await 语义下不该有第二个并发弹窗；真来了用确定降级答掉新的，防脚本挂起。
            Log.w(LOG_TAG, "bridge dialog while another pending; fallback-answer the new one")
            val fallback = warehouseBridgeFallbackAnswer(raw)
            if (fallback != null) resolveBridgeRequest(fallback.requestId, fallback.jsonValue)
            return
        }
        pendingDialog = request
    }

    /** 用户在脚本弹窗里答完：录制期先记应答（Dart `_macroDialogResponses`），再 resolve 回网页。 */
    fun answerConfirm(request: WarehouseBridgeDialogRequest, answer: Boolean) {
        if (recording) {
            macroDialogResponses[request.responseKey()] = answer
        }
        resolveBridgeRequest(request.requestId, if (answer) "true" else "false")
        pendingDialog = null
    }

    fun answerPrompt(request: WarehouseBridgeDialogRequest, text: String?) {
        if (recording && text != null) {
            macroDialogResponses[request.responseKey()] = text
        }
        resolveBridgeRequest(request.requestId, MiniJson.encode(text))
        pendingDialog = null
    }

    fun answerSingleSelection(request: WarehouseBridgeDialogRequest, index: Int?) {
        // Dart 录制侧存的是「用户选的那一项的文字」：宿主调整选项顺序也不会选错；
        // 回放时再把文字还原成下标（回放引擎未移植，这里只负责存对形状）。
        if (recording && index != null && request.options.isNotEmpty()) {
            request.optionTextAt(index)?.let { macroDialogResponses[request.responseKey()] = it }
        }
        resolveBridgeRequest(request.requestId, index?.toString() ?: "null")
        pendingDialog = null
    }

    // ---- I2-2：saveCourseConfig 落盘 ----

    fun handleSaveCourseConfig(raw: String) {
        val request = warehouseBridgeSaveRequest(raw, "saveCourseConfig")
        if (request == null) {
            Log.w(LOG_TAG, "saveCourseConfig ignored: unsafe requestId or bad shape")
            return
        }
        val decoded = MiniJson.tryParse(request.payload) as? Map<*, *>
        if (decoded == null) {
            Log.w(LOG_TAG, "saveCourseConfig payload not an object")
            resolveBridgeRequest(request.requestId, "false")
            return
        }
        // 上游脚本还会下发 firstDayOfWeek / defaultClassDuration / defaultBreakDuration，
        // 本 App 没有对应设置可落：记日志，不静默丢弃（Dart 同口径）。
        val ignored = WAREHOUSE_UNSUPPORTED_COURSE_CONFIG_KEYS.filter { decoded[it] != null }
        if (ignored.isNotEmpty()) {
            Log.i(LOG_TAG, "courseConfig received-but-unsupported keys=$ignored")
        }
        val resolved = resolveWarehouseCourseConfig(decoded)
        if (!resolved.hasAnything) {
            // 脚本没给可用值：不写盘、保留用户设置，但回答 true（Dart 同口径）。
            resolveBridgeRequest(request.requestId, "true")
            return
        }
        val repo = repository
        if (repo == null) {
            Log.w(LOG_TAG, "saveCourseConfig but repository is not wired")
            resolveBridgeRequest(request.requestId, "false")
            return
        }
        scope.launch {
            val saved = withContext(Dispatchers.IO) {
                try {
                    // 无效项不覆盖用户已有设置（copy 只替换解析出来的字段）。
                    val current = repo.snapshot.settings
                    repo.updateSettings(
                        current.copy(
                            semesterWeekCount = resolved.semesterWeekCount ?: current.semesterWeekCount,
                            semesterStartDate = resolved.semesterStartDate ?: current.semesterStartDate,
                        ),
                    )
                    true
                } catch (error: Exception) {
                    Log.w(LOG_TAG, "saveCourseConfig persist failed: ${error.message}")
                    false
                }
            }
            if (!saved) {
                showToasts(listOf(WarehouseStrings.saveFailed.zh))
            }
            resolveBridgeRequest(request.requestId, if (saved) "true" else "false")
        }
    }

    /**
     * 网页对话框降级：给一个确定的默认回答，避免脚本的 Promise 永远悬着。
     *
     * 现在只服务两类：a) `savePresetTimeSlots`（作息切换链路未移植，诚实回 false）；
     * b) 已有弹窗待答时并发到来的第二个弹窗（脚本 await 语义下不该发生）。
     */
    fun handleDialogFallback(raw: String) {
        val answer = warehouseBridgeFallbackAnswer(raw)
        if (answer == null) {
            Log.w(LOG_TAG, "bridge dialog ignored: unsafe requestId or unknown type")
            return
        }
        resolveBridgeRequest(answer.requestId, answer.jsonValue)
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

            "confirm", "prompt", "singleSelection" -> {
                if (scriptActive) {
                    handleNativeDialogMessage(raw)
                } else {
                    Log.w(LOG_TAG, "dialog message dropped outside import execution: $type")
                }
            }

            "saveCourseConfig" -> {
                if (scriptActive) {
                    handleSaveCourseConfig(raw)
                } else {
                    Log.w(LOG_TAG, "saveCourseConfig dropped outside import execution")
                }
            }

            "savePresetTimeSlots" -> {
                if (scriptActive) {
                    // 作息切换链路未移植：诚实回 false（见文件头诚实边界第 2 条）。
                    handleDialogFallback(raw)
                } else {
                    Log.w(LOG_TAG, "savePresetTimeSlots dropped outside import execution")
                }
            }

            "macro:event" -> {
                if (recording) {
                    val payloadText = (MiniJson.tryParse(raw) as? Map<*, *>)?.get("payload") as? String
                    val event = payloadText
                        ?.let { MiniJson.tryParse(it) as? Map<*, *> }
                        ?.mapKeys { (key, _) -> key.toString() }
                    if (event != null) {
                        macroEvents.add(event)
                        session = session.withStepRecorded()
                    } else {
                        // 单条事件损坏只丢这一条，不中断录制（Dart 同口径，留痕便于核对）。
                        Log.w(LOG_TAG, "macro event decode failed")
                    }
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

    // 列表页「录制导入」进来的一录到底（Dart `widget.autoRecord`）：进页自动开录，只触发一次。
    LaunchedEffect(Unit) {
        if (state.autoRecord) {
            state.autoRecord = false
            startMacroRecording(auto = true)
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
            // 录制 JS 随导航重建：每次页面加载完成后重注（Dart 同口径：先注入录制 JS，
            // 再探测登录状态——这样填充事件也能被录制到）。
            if (session.macroState == WarehouseMacroActionState.RECORDING) {
                controller.injectJavaScript(WarehouseMacroRecorderJs.INJECT_SCRIPT)
            }
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
            // 数据回传（courses）与原生对话框在这里分发；正文不进日志（课表里有学号/课表内容）。
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
            when (session.macroState) {
                WarehouseMacroActionState.RECORDING -> stopMacroRecording(completedImport = false)
                else -> startMacroRecording(auto = false)
            }
        },
        onExecuteImport = { executeImportScript() },
    )

    // ---- I2-1 原生脚本弹窗（常驻组合 + show 驱动；弹层内记住最后一份非空请求供退场渲染） ----
    WarehouseScriptConfirmDialog(
        show = pendingDialog?.kind == WarehouseBridgeDialogKind.CONFIRM,
        request = pendingDialog?.takeIf { it.kind == WarehouseBridgeDialogKind.CONFIRM },
        onResult = { answer -> pendingDialog?.let { answerConfirm(it, answer) } },
    )
    WarehouseScriptPromptDialog(
        show = pendingDialog?.kind == WarehouseBridgeDialogKind.PROMPT,
        request = pendingDialog?.takeIf { it.kind == WarehouseBridgeDialogKind.PROMPT },
        onResult = { text -> pendingDialog?.let { answerPrompt(it, text) } },
    )
    WarehouseScriptSingleSelectionDialog(
        show = pendingDialog?.kind == WarehouseBridgeDialogKind.SINGLE_SELECTION,
        request = pendingDialog?.takeIf { it.kind == WarehouseBridgeDialogKind.SINGLE_SELECTION },
        onResult = { index -> pendingDialog?.let { answerSingleSelection(it, index) } },
    )

    // ---- I2-3 「替换/合并」选择（复用导入域共享预览卡；表格导入同形态：无学期映射行） ----
    val pendingImportShown = pendingImport
    ImportPreviewDialog(
        show = pendingImportShown != null,
        importLabel = school.name,
        courseCount = pendingImportShown?.courses?.size ?: 0,
        // 开学日/周次映射弹窗未接（诚实边界第 1 条）：周次按脚本原值写入。
        semesterStartDate = null,
        initialFirstCourseWeek = 1,
        lastAllowedWeek = repository?.snapshot?.settings?.semesterWeekCount ?: 20,
        hasExistingCourses = true,
        onCancel = {
            // Dart：取消 = 中止本次导入（课程一个字节不落盘）。
            Log.i(LOG_TAG, "courses import cancelled at replace/merge dialog")
            pendingImport = null
            scriptActive = false
        },
        onConfirm = { choice ->
            val parsed = pendingImport
            pendingImport = null
            if (parsed != null) {
                applyCourses(
                    parsed,
                    requestedMode = if (choice.replaceExisting) {
                        WarehouseCourseWriteBack.Mode.REPLACE
                    } else {
                        WarehouseCourseWriteBack.Mode.MERGE
                    },
                )
            }
        },
    )

    // ---- I2-4 录制收尾「保存为快捷导入？」 ----
    WarehouseMacroSaveConfirmDialog(
        show = macroSavePrompt != null,
        stepCount = macroSavePrompt?.steps?.size ?: 0,
        autoRecord = macroSavePrompt?.autoRecord ?: false,
        onSave = {
            val prompt = macroSavePrompt
            macroSavePrompt = null
            if (prompt != null) saveMacroRecording(prompt)
        },
        onDiscard = {
            val prompt = macroSavePrompt
            macroSavePrompt = null
            if (prompt != null) discardMacroRecording(prompt)
        },
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
