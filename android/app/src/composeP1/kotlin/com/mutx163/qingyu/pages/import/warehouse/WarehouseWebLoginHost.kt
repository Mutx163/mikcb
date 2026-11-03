package com.mutx163.qingyu.pages.import.warehouse

import android.util.Log
import android.widget.Toast
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
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
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.app.TimetableHostLogic
import com.mutx163.qingyu.pages.import.ImportFlowModel
import com.mutx163.qingyu.pages.import.ImportRandomColorStore
import com.mutx163.qingyu.pages.time_scheme.TimeSchemeServiceMessages
import com.mutx163.qingyu.platform.PrefsKeyValueStore
import com.mutx163.qingyu.transfer.MAX_ALLOWED_SEMESTER_WEEK_COUNT
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme
import java.time.LocalDate
import java.time.LocalDateTime
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
 * | 脚本回传 `courses` | 三步确认（覆盖/更新 → 开学日/首周 → 节次不够时「自动补齐并导入」）→ 周次平移 + 随机配色 → [WarehouseCoursesImportApply] 收尾落盘 |
 * | 网页 `toast` / `error` | 轻提示显示脚本原文（error 缺省兜底固定文案） |
 * | 网页 `confirm` / `prompt` / 单选 | [WarehouseBridgeDialogHost] 原生弹层（F32 收口），回传契约见模型层文件头 |
 * | 网页 `saveCourseConfig` | 字段表单 → 白名单字段落盘（[warehouseCourseConfigResolution]）→ `true`/`false` |
 * | 网页 `savePresetTimeSlots` | 载荷是节次数组、无界面可弹：直接走写链路（[WarehousePresetTimeSlotsWriteBack]）→ 落盘成功 `true` / 失败 `false` |
 * | 桥接消息 | 已由页面过了 §6.2 门禁；这里按类型分发 |
 *
 * ## 诚实边界（别删）
 *
 * 1. **抓回来的课写当前档案前按需问三步**（覆盖/更新、开学日/首周，节次不够时再加
 *    「自动补齐并导入」，任一取消=中止导入，对齐 Dart `askImportReplaceExisting` /
 *    `pickImportSemesterConfig` / `ensureImportSectionCapacity`）；按用户确认的
 *    「课表第 1 周 = 校历第 N 周」平移周次（[warehouseShiftCoursesToFirstWeek]）、
 *    按偏好随机配色，再由 [WarehouseCoursesImportApply] 收尾落盘（周数不够自动扩、
 *    扩节失败一条不写）。与 Dart 的差异只剩：设置与课程是两次独立落盘，
 *    中间失败可能出现「设置已新、课程未动」。
 * 2. **`savePresetTimeSlots` 没有界面，但它不是「用户输入」型交互**：脚本的语义就是
 *    「存这套全局作息」，直接落盘并套用（解析 → 校验 → 仓储 createTimeScheme/updateTimeScheme
 *    + applyTimeScheme）；写链路失败回 `false` 并提示，不静默、也不画一个什么都不存的确认框。
 * 3. **登录态探针/自动填充未接**（`WarehouseWebLoginPage` 的 remembered-account 相关回调仍是默认空实现），
 *    与 i2-webview 认领文件里列的缺件一致。
 * 4. **宏录制已接（P1）**：手动开关 / 首次导入自动录制 / 成功后询问保存，存储与
 *    Dart 同键共读；**回放（快捷导入）仍未移植**，保存的宏本期只落盘不回放（P2）。
 * 5. 真机未验：仓库能不能拉到脚本、教务站能不能登录并通过脚本抓课，只有用户真机可见。
 */

/**
 * 录制完成后的保存询问载荷：转出的步骤 + 来自哪个入口（自动完成 / 手动停止）。
 * 正文文案与 successfulImportCount 都按它区分（Dart widget.autoRecord 同语义）。
 */
private class WarehouseMacroSavePrompt(
    val steps: List<WarehouseMacroStep>,
    val autoRecord: Boolean,
)

private const val LOG_TAG = "WarehouseWebLogin"

/**
 * 一次待用户确认的脚本课程包（courses 写回前的两步确认期间持有）。
 *
 * `courses` 已过 [WarehouseCourseImportLogic.parse]（坏记录已剔除并计数），
 * 写回前还要问两步：覆盖还是更新（[WarehouseReplaceExistingDialog]）、
 * 开学日/首周（[WarehouseSemesterMappingSheet]）；计数留给完成提示的文案。
 */
private class WarehouseCoursesImportSession(
    val courses: List<Course>,
    val receivedCount: Int,
    val droppedCount: Int,
    val weeksTrimmedCount: Int,
)

/**
 * 第二步确认后的落盘计划：课程已平移、已按偏好配色，只差用户对节次扩容的
 * 最后确认（节次够用时跳过第三步直接落盘）。计数留给完成/中断提示的文案。
 */
private class WarehouseCoursesFinalizePlan(
    val courses: List<Course>,
    val replaceExisting: Boolean,
    val preserveLocalColors: Boolean,
    val startDate: LocalDate,
    val receivedCount: Int,
    val droppedCount: Int,
    val weeksTrimmedCount: Int,
    val requiredSectionCount: Int,
    val currentSectionCount: Int,
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
    var session by remember(target.loginUrl) {
        mutableStateOf(initialWarehouseWebLoginSession(target))
    }
    var isExecuting by remember { mutableStateOf(false) }
    // 脚本执行期窗口：注入成功到 complete/error/网页跳转之间。
    // 回传的 courses 与对话框回答只在这个窗口内处理——不然任意网页都能塞一份假课表。
    var scriptActive by remember(target.loginUrl) { mutableStateOf(false) }
    // 当前挂起的原生对话框请求（F32：脚本的 Promise 在等用户回答）。
    // 同刻至多一个：脚本按 await 串行发问；同刻又来一条说明脚本没等，后者走降级。
    var pendingDialog by remember { mutableStateOf<WarehouseBridgeDialogRequest?>(null) }
    // 本次脚本会话里已落盘生效的节次签名（对齐 Dart `_appliedImportedSectionsSignature`）：
    // 同一份载荷不重复落盘，新脚本窗口（重新执行 / 页面跳转）清零。
    var appliedSectionsSignature by remember { mutableStateOf<String?>(null) }

    // ---- 宏录制（P1）：录制态 / 事件缓冲 / 弹窗应答存入 ----
    // 存储与适配器列表宿主同一套键（Dart SharedPreferences 同键共读，D1）。
    val macroStore = remember(context) { WarehouseMacroStore(PrefsKeyValueStore(context)) }
    var macroState by remember { mutableStateOf(WarehouseMacroActionState.IDLE) }
    var recordedStepsCount by remember { mutableIntStateOf(0) }
    var macroRawEvents by remember { mutableStateOf<List<Map<String, Any?>>>(emptyList()) }
    // 弹窗应答（N6 存入侧）：用户作答后写入，保存时进 record.dialogResponses。
    val macroDialogResponses = remember { LinkedHashMap<String, Any?>() }
    // 当前挂起弹层的应答 key（录制态收到对话框请求时算好，作答时用）。
    var pendingDialogResponseKey by remember { mutableStateOf<String?>(null) }
    // 保存询问（0 步骤不问；对齐 Dart _completeMacroAndPop / _stopMacroRecording 的确认框）。
    var macroSavePrompt by remember { mutableStateOf<WarehouseMacroSavePrompt?>(null) }
    var macroBusy by remember { mutableStateOf(false) }

    // ---- 宏录制方法（P1，对齐 Dart _startMacroRecording / _stopMacroRecording / _completeMacroAndPop）----
    // 注意：这段必须声明在 confirmCoursesImport / finalizeCoursesImport 之前——
    // Kotlin 局部函数只能使用在声明点之前已声明的符号（导入成功的自动完成是前向调用）。

    fun resetMacroRecording() {
        macroState = WarehouseMacroActionState.IDLE
        recordedStepsCount = 0
        macroRawEvents = emptyList()
        macroDialogResponses.clear()
        pendingDialogResponseKey = null
    }

    fun startMacroRecording(autoRecord: Boolean) {
        if (macroState == WarehouseMacroActionState.RECORDING || macroBusy) return
        macroState = WarehouseMacroActionState.RECORDING
        recordedStepsCount = 0
        macroRawEvents = emptyList()
        // 每次录制从干净的应答表开始：上次「停止但不保存」（或同一 WebView 上重录）
        // 不能把旧应答泄漏进新宏（Dart _startMacroRecording 的防泄漏注释同款）。
        macroDialogResponses.clear()
        controller.injectJavaScript(WarehouseMacroRecorderJs.INJECT_SCRIPT)
        Toast.makeText(
            context,
            if (autoRecord) {
                WarehouseStrings.courseImportAutoRecordingStartedTip.zh
            } else {
                WarehouseStrings.courseImportRecordingStartedTip.zh
            },
            Toast.LENGTH_SHORT,
        ).show()
    }

    /** dump 补收：把页面缓冲里的尾部事件并进已收列表（桥不可用时的兜底，失败留痕不中断）。 */
    fun dumpRecordedEvents(onDone: () -> Unit) {
        controller.evaluateJavaScript(WarehouseMacroRecorderJs.DUMP_SCRIPT) { result ->
            if (!result.isNullOrEmpty() && result != "[]") {
                val decoded = MiniJson.tryParse(result)
                if (decoded is List<*>) {
                    val merged = macroRawEvents.toMutableList()
                    for (item in decoded) {
                        val map = item as? Map<*, *> ?: continue
                        val event = LinkedHashMap<String, Any?>()
                        for ((k, v) in map) {
                            if (k is String) event[k] = v
                        }
                        merged.add(event)
                    }
                    macroRawEvents = merged
                }
            }
            onDone()
        }
    }

    fun stopMacroRecording() {
        if (macroState != WarehouseMacroActionState.RECORDING || macroBusy) return
        macroState = WarehouseMacroActionState.STOPPED
        macroBusy = true
        dumpRecordedEvents {
            val steps = WarehouseMacroRecordingConverter.convert(macroRawEvents)
            macroBusy = false
            if (steps.isEmpty()) {
                // 未录到任何操作：回 IDLE + 提示，不问保存（Dart 同款）。
                resetMacroRecording()
                Toast.makeText(
                    context,
                    WarehouseStrings.courseImportRecordingEmptyTip.zh,
                    Toast.LENGTH_SHORT,
                ).show()
            } else {
                macroSavePrompt = WarehouseMacroSavePrompt(steps = steps, autoRecord = false)
            }
        }
    }

    /** 导入成功自动完成：0 步骤直接退出不打扰（导入本身已成功），有步骤则问保存。 */
    fun completeMacroAndPop() {
        if (macroState != WarehouseMacroActionState.RECORDING || macroBusy) return
        macroState = WarehouseMacroActionState.STOPPED
        macroBusy = true
        dumpRecordedEvents {
            val steps = WarehouseMacroRecordingConverter.convert(macroRawEvents)
            macroBusy = false
            if (steps.isEmpty()) {
                resetMacroRecording()
                onBack()
            } else {
                macroSavePrompt = WarehouseMacroSavePrompt(steps = steps, autoRecord = true)
            }
        }
    }

    fun saveCurrentMacro() {
        val prompt = macroSavePrompt ?: return
        macroBusy = true
        scope.launch {
            val saved = withContext(Dispatchers.IO) {
                try {
                    val now = LocalDateTime.now()
                    macroStore.saveMacro(
                        WarehouseMacroRecord(
                            schoolId = school.id,
                            adapterId = adapter.id,
                            schoolName = school.name,
                            adapterName = adapter.adapterName,
                            importUrl = target.loginUrl,
                            // 脚本页地址按旧版同款脱敏（session id 之类不进宏 / 不进云同步）。
                            scriptPageUrl = sanitizeWarehouseScriptPageUrl(
                                controller.liveUrl() ?: session.currentUrl.ifEmpty { target.loginUrl },
                            ),
                            schoolResourceFolder = school.resourceFolder,
                            adapterAssetJsPath = adapter.script,
                            steps = prompt.steps,
                            dialogResponses = LinkedHashMap<String, Any?>(macroDialogResponses),
                            createdAt = now,
                            updatedAt = now,
                            // 自动完成（导入成功）计一次成功；手动停止保存不计（Dart 同口径）。
                            successfulImportCount = if (prompt.autoRecord) 1 else 0,
                            useDesktopMode = controller.isDesktopMode,
                        ),
                    )
                    true
                } catch (error: Exception) {
                    Log.w(LOG_TAG, "macro save failed: ${error.javaClass.simpleName}")
                    false
                }
            }
            macroBusy = false
            macroSavePrompt = null
            resetMacroRecording()
            if (saved) {
                Toast.makeText(
                    context,
                    WarehouseStrings.courseImportRecordingSavedStatus
                        .filled("count", prompt.steps.size.toString()),
                    Toast.LENGTH_SHORT,
                ).show()
                onBack()
            } else {
                Toast.makeText(context, WarehouseStrings.saveFailed.zh, Toast.LENGTH_SHORT).show()
            }
        }
    }

    fun discardCurrentMacro() {
        macroSavePrompt = null
        resetMacroRecording()
    }

    /** `macro:event` 分支：录制态收事件进缓冲（坏 payload 丢这一条，不中断录制）。 */
    fun handleMacroEvent(raw: String) {
        if (macroState != WarehouseMacroActionState.RECORDING) return
        val event = parseWarehouseMacroEventPayload(raw) ?: return
        macroRawEvents = macroRawEvents + event
        recordedStepsCount += 1
    }

    /** 录制态把挂起弹层的应答 key 算好（key 口径与 Dart warehouseDialogResponseKey 逐字一致）。 */
    fun rememberPendingDialogKey(raw: String) {
        if (macroState != WarehouseMacroActionState.RECORDING) {
            pendingDialogResponseKey = null
            return
        }
        val message = MiniJson.tryParse(raw) as? Map<*, *>
        val type = warehouseBridgeMessageType(raw)
        pendingDialogResponseKey = if (message == null || type == null) {
            null
        } else {
            warehouseDialogResponseKey(type, message)
        }
    }

    /**
     * 用户作答后把应答存进录制表：confirm 存 bool（取消也是 false）；
     * prompt 存文本（取消 null 不存）；单选存「所选项文字」（宿主日后调整
     * 选项顺序也不会选错，回放时还原成下标属 P2）。
     */
    fun recordMacroDialogResponse(value: Any?) {
        if (macroState != WarehouseMacroActionState.RECORDING) return
        val key = pendingDialogResponseKey ?: return
        if (value == null) return
        macroDialogResponses[key] = value
    }

    /** 把一条回答 resolve 给网页并收起挂起弹层（requestId 不可信时脚本是空串，注入为安全 no-op）。 */
    fun answerAndClose(answer: WarehouseBridgeDialogAnswer) {
        pendingDialog = null
        val script = warehouseBridgeResolveScript(answer.requestId, answer.jsonValue)
        if (script.isNotEmpty()) {
            controller.injectJavaScript(script)
        }
        Log.i(LOG_TAG, "bridge dialog ${answer.kind.messageType} answered via native dialog")
    }

    /**
     * 脚本窗口结束（complete / error / 新导航 / 重新执行）时排空挂起弹层：
     * 按旧版「用户取消」的同一回传结构回话——旧版导入超时不回话，脚本 Promise
     * 悬死到页面关闭；这里补上明确回应（回传结构与用户取消完全一致）。
     */
    fun cancelPendingDialog(reason: String) {
        val pending = pendingDialog ?: return
        pendingDialog = null
        val answer = warehouseBridgeDialogCancelAnswer(pending)
        val script = warehouseBridgeResolveScript(answer.requestId, answer.jsonValue)
        if (script.isNotEmpty()) {
            controller.injectJavaScript(script)
        }
        Log.i(LOG_TAG, "bridge dialog ${pending.kind.messageType} cancelled at script window end ($reason)")
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
                // 新一轮执行前排空上一轮可能还挂着的弹层（正常已被 complete/error/导航排空）。
                cancelPendingDialog("re-execute")
                appliedSectionsSignature = null
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

    /** 一次待确认的脚本课程包：解析结果 + 上屏要用的计数（F32 前缺的两步确认挂这里）。 */
    var coursesSession by remember { mutableStateOf<WarehouseCoursesImportSession?>(null) }

    /** 第一步（覆盖/更新）是否还在问；false 且 [coursesSession] 非空 = 已进第二步。 */
    var coursesAskReplace by remember { mutableStateOf(false) }

    /** 用户在第一步的选择：true = 覆盖导入（替换），false = 更新课表（合并）。 */
    var coursesReplaceExisting by remember { mutableStateOf(true) }

    /** 第二步确认后的落盘计划（已平移+配色）；节次不够时等用户在第三步点头。 */
    var coursesFinalizePlan by remember { mutableStateOf<WarehouseCoursesFinalizePlan?>(null) }

    /** 第三步（节次补齐确认）是否在问。 */
    var coursesAskExpansion by remember { mutableStateOf(false) }

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
        if (coursesSession != null) {
            // 上一次导入还挂着确认弹层：丢弃新包（对齐旧版模态弹窗期间不收新 courses）。
            Log.w(LOG_TAG, "courses dropped: previous import session still open")
            return
        }
        scope.launch {
            val parsed = withContext(Dispatchers.IO) {
                val decoded = MiniJson.tryParse(payload)
                if (decoded !is List<*>) return@withContext null
                var dropped = 0
                var trimmed = 0
                val courses = WarehouseCourseImportLogic.parse(
                    rawCourses = decoded,
                    idFactory = { UUID.randomUUID().toString() },
                    unknownTeacher = WarehouseStrings.unknownTeacher.zh,
                    unknownLocation = WarehouseStrings.unknownLocation.zh,
                    maxWeek = MAX_ALLOWED_SEMESTER_WEEK_COUNT,
                ) { reason, _, _ ->
                    when (reason) {
                        WarehouseCourseImportLogic.SkipReason.MALFORMED,
                        WarehouseCourseImportLogic.SkipReason.UNUSABLE,
                        -> dropped += 1

                        WarehouseCourseImportLogic.SkipReason.PARTIAL_WEEKS -> trimmed += 1
                    }
                }
                Triple(courses, dropped, trimmed)
            }
            if (parsed == null) {
                // 载荷不是数组：对齐旧版直接报格式错误，不进弹窗。
                showToasts(listOf(WarehouseStrings.invalidCourseDataFormat.zh))
                return@launch
            }
            val (courses, dropped, trimmed) = parsed
            if (courses.isEmpty()) {
                // 对齐旧版：解析后一门都没有 → 提示 + 丢弃计数，不进弹窗。
                val toasts = mutableListOf(WarehouseStrings.noImportableCoursesFromScript.zh)
                if (dropped > 0) {
                    toasts.add(
                        WarehouseStrings.importCourseRecordsDropped.filled(
                            "imported" to (courses.size + dropped).toString(),
                            "dropped" to dropped.toString(),
                        ),
                    )
                }
                showToasts(toasts)
                return@launch
            }
            coursesSession = WarehouseCoursesImportSession(
                courses = courses,
                receivedCount = courses.size + dropped,
                droppedCount = dropped,
                weeksTrimmedCount = trimmed,
            )
            // 对齐旧版 `provider.courses.isEmpty ? true : ask…`：空表不问、直接替换，
            // 进第二步（开学日/首周）。
            val empty = withContext(Dispatchers.IO) { repo.snapshot.courses.isEmpty() }
            if (empty) {
                coursesReplaceExisting = true
                coursesAskReplace = false
            } else {
                coursesAskReplace = true
            }
        }
    }

    /** 两步确认任一步取消：中止整次导入（对齐旧版——不写回、提示、结束执行期）。 */
    fun cancelCoursesImport(interrupted: Boolean = false) {
        coursesSession = null
        coursesAskReplace = false
        coursesFinalizePlan = null
        coursesAskExpansion = false
        scriptActive = false
        Log.i(LOG_TAG, "courses import cancelled by user interrupted=$interrupted")
        // 第三步（节次补齐确认）取消落在「导入已中断」，与旧版 capacity 路径同文案。
        showToasts(
            listOf(
                if (interrupted) WarehouseStrings.importInterruptedStatus.zh
                else WarehouseStrings.importCancelledStatus.zh,
            ),
        )
    }

    /** 完成提示（Done 文案口径与旧写回层一致，计数来自本次会话）。 */
    fun doneMessagesFor(plan: WarehouseCoursesFinalizePlan, importedCount: Int): List<String> {
        val messages = mutableListOf<String>()
        messages.add(
            when {
                importedCount == 0 -> WarehouseStrings.importNoCourseChanges.zh
                plan.replaceExisting -> WarehouseStrings.importOverwriteCount.filled("count", importedCount.toString())
                else -> WarehouseStrings.importUpdatedCount.filled("count", importedCount.toString())
            },
        )
        if (plan.droppedCount > 0) {
            messages.add(
                WarehouseStrings.importCourseRecordsDropped.filled(
                    "imported" to plan.receivedCount.toString(),
                    "dropped" to plan.droppedCount.toString(),
                ),
            )
        }
        if (plan.weeksTrimmedCount > 0) {
            messages.add(
                WarehouseStrings.importCourseWeeksTrimmed.filled("count", plan.weeksTrimmedCount.toString()),
            )
        }
        return messages
    }

    /** 第三步确认或无需扩节：落盘（扩节 + 学期设置 + 课程），失败提示并已回滚。 */
    fun finalizeCoursesImport(plan: WarehouseCoursesFinalizePlan, expandSections: Boolean) {
        val repo = repository ?: return
        coursesFinalizePlan = null
        coursesAskExpansion = false
        scriptActive = false
        scope.launch {
            val result = withContext(Dispatchers.IO) {
                WarehouseCoursesImportApply.apply(
                    repository = repo,
                    request = WarehouseCoursesImportApply.Request(
                        courses = plan.courses,
                        semesterStartDate = plan.startDate,
                        replaceExisting = plan.replaceExisting,
                        preserveLocalColors = plan.preserveLocalColors,
                        expandSections = expandSections,
                    ),
                )
            }
            when (result) {
                is WarehouseCoursesImportApply.Result.Done -> {
                    Log.i(LOG_TAG, "courses import done importedCount=${result.importedCount}")
                    showToasts(doneMessagesFor(plan, result.importedCount))
                    // 导入成功（写回课程数 > 0）且正在录制：自动完成录制并询问保存
                    // （对齐 Dart `importedCount > 0 && recording → _completeMacroAndPop`）。
                    if (result.importedCount > 0 && macroState == WarehouseMacroActionState.RECORDING) {
                        completeMacroAndPop()
                    }
                }

                is WarehouseCoursesImportApply.Result.Failed -> {
                    // 服务码（如节次补不满）过本地化再展示；其余落固定文案。
                    val text = result.serviceMessage
                        ?.let { TimeSchemeServiceMessages.localize(it) }
                        ?: WarehouseStrings.importFailedStatus.zh
                    Log.w(LOG_TAG, "courses import failed serviceMessage=${result.serviceMessage}")
                    showToasts(listOf(text))
                }
            }
        }
    }

    /** 第二步确认：平移 + 按偏好配色，然后视节次容量直接落盘或先进第三步确认。 */
    fun confirmCoursesImport(startDate: LocalDate, firstCourseWeek: Int) {
        val session = coursesSession ?: return
        val repo = repository ?: return
        val replaceExisting = coursesReplaceExisting
        coursesSession = null
        coursesAskReplace = false
        // 录制态：把开学日/首周应答存进宏（N6 固定键 semesterConfig：ISO 日期 + 首周数）。
        if (macroState == WarehouseMacroActionState.RECORDING) {
            macroDialogResponses["semesterConfig"] = linkedMapOf<String, Any?>(
                "startDate" to startDate.toString(),
                "firstCourseWeek" to firstCourseWeek,
            )
        }
        scope.launch {
            val plan = withContext(Dispatchers.IO) {
                // 随机配色（Dart coursesWithOptionalRandomColors）：开关关→原样；
                // 开→按用户选的色板组给「同名同教师」派生同色。
                val colorPrefs = ImportRandomColorStore(PrefsKeyValueStore(context)).snapshot()
                val shifted = warehouseShiftCoursesToFirstWeek(session.courses, firstCourseWeek)
                val colored = ImportFlowModel.coursesWithOptionalRandomColors(shifted, colorPrefs)
                val preserveLocalColors = ImportFlowModel.shouldPreserveLocalColors(
                    replaceExisting = replaceExisting,
                    randomColorsEnabled = colorPrefs.enabled,
                )
                // 节次容量判据（Dart previewImportedCourseRequiredSectionCount）：
                // 最大结束节号 vs 当前生效节次表（有主模板取模板）。
                val snapshot = repo.snapshot
                val currentSections = WarehouseCoursesImportApply.activeSections(
                    snapshot.settings,
                    TimetableHostLogic.resolveActiveTimeScheme(
                        schemes = snapshot.timeSchemes,
                        activeTimeSchemeId = snapshot.activeTimeSchemeId,
                    )?.sections,
                )
                WarehouseCoursesFinalizePlan(
                    courses = colored,
                    replaceExisting = replaceExisting,
                    preserveLocalColors = preserveLocalColors,
                    startDate = startDate,
                    receivedCount = session.receivedCount,
                    droppedCount = session.droppedCount,
                    weeksTrimmedCount = session.weeksTrimmedCount,
                    requiredSectionCount = WarehouseCoursesImportApply.requiredSectionCount(colored),
                    currentSectionCount = currentSections.size,
                )
            }
            if (plan.requiredSectionCount > plan.currentSectionCount) {
                // 第三步：节次不够，先问用户（旧版 ensureImportSectionCapacity 的确认框）。
                coursesFinalizePlan = plan
                coursesAskExpansion = true
            } else {
                finalizeCoursesImport(plan, expandSections = false)
            }
        }
    }

    /**
     * 网页对话框降级：给一个确定的默认回答，避免脚本的 Promise 永远悬着。
     * 原生界面可用时（消息能解析成请求且没有别的弹层挂着）不再走这里；
     * 剩余场景：坏载荷 / savePresetTimeSlots 的数组载荷 / 同刻第二条弹层。
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

    /**
     * 保存配置确认：白名单字段（学期总周数 / 开学日）落盘，成功才回 `true`。
     * 白名单与「非法值不覆盖用户设置」的判定都在模型层（[warehouseCourseConfigResolution]），
     * 对齐 Dart `WarehouseCourseConfigLogic.resolve`。
     */
    fun handleSaveConfig(action: WarehouseBridgeDialogUserAction.SaveConfig) {
        val repo = repository
        if (repo == null) {
            // 壳没传仓储：配置没落盘，不能回 true 骗脚本（与降级回 false 同一口径）。
            answerAndClose(warehouseBridgeSaveConfigAnswer(action.requestId, saved = false))
            showToasts(listOf(WarehouseStrings.saveFailed.zh))
            return
        }
        val resolution = warehouseCourseConfigResolution(action.values)
        // 上游会下发本 App 收不下的键（firstDayOfWeek 等）：记执行日志，不静默丢弃
        // （对齐 Dart `_handleSaveCourseConfig` 的 received-but-unsupported 日志）。
        val ignoredKeys = warehouseUnsupportedCourseConfigKeysIn(action.values)
        if (ignoredKeys.isNotEmpty()) {
            Log.i(LOG_TAG, "courseConfig received-but-unsupported keys=$ignoredKeys")
        }
        if (!resolution.hasAnything) {
            // 没有可落盘的合法字段：设置保持现值，对脚本按成功回话（对齐 Dart「hasAnything 才写」）。
            answerAndClose(warehouseBridgeSaveConfigAnswer(action.requestId, saved = true))
            return
        }
        scope.launch {
            val saved = withContext(Dispatchers.IO) {
                try {
                    val before = repo.snapshot.settings
                    // copy 语义对齐 Dart copyWith：脚本没下发的字段保持现值，不会被清空。
                    repo.updateSettings(
                        before.copy(
                            semesterWeekCount = resolution.semesterWeekCount ?: before.semesterWeekCount,
                            semesterStartDate = resolution.semesterStartDate ?: before.semesterStartDate,
                        ),
                    )
                    true
                } catch (error: Exception) {
                    Log.w(LOG_TAG, "saveCourseConfig apply failed: ${error.javaClass.simpleName}")
                    false
                }
            }
            if (!saved) {
                showToasts(listOf(WarehouseStrings.saveFailed.zh))
            }
            answerAndClose(warehouseBridgeSaveConfigAnswer(action.requestId, saved = saved))
        }
    }

    /** 不经挂起弹层，直接把一个值 resolve 给网页侧 Promise（savePresetTimeSlots 用）。 */
    fun answerRequest(requestId: String, jsonValue: String, kind: String) {
        val script = warehouseBridgeResolveScript(requestId, jsonValue)
        if (script.isNotEmpty()) {
            controller.injectJavaScript(script)
        }
        Log.i(LOG_TAG, "bridge $kind answered with $jsonValue")
    }

    /**
     * `savePresetTimeSlots`：节次数组载荷直接落盘（不是「用户输入」型交互，不弹确认框）。
     * 解析 / 校验 / 落盘全在 [WarehousePresetTimeSlotsWriteBack]，走仓储时间方案写入口；
     * 成功 resolve `true`，任何一步失败 resolve `false` 并提示可读原因（不静默）。
     * 同一份载荷在同一脚本会话内不重复落盘（对齐 Dart 的签名去重，按成功回话）。
     */
    fun handleSavePresetTimeSlots(raw: String) {
        val request = warehousePresetTimeSlotsRequest(raw)
        if (request == null) {
            // 坏结构（坏 JSON / requestId 不可信 / payload 缺失）：按旧降级口径回答
            // （可信 id 回 false；不可信 id 不注入任何东西）。
            handleDialogFallback(raw)
            return
        }
        val repo = repository
        if (repo == null) {
            // 壳没传仓储：作息没落盘，不能回 true 骗脚本（与 saveCourseConfig 同一口径）。
            answerRequest(request.requestId, "false", kind = "savePresetTimeSlots")
            showToasts(listOf(WarehouseStrings.saveFailed.zh))
            return
        }
        scope.launch {
            val result = withContext(Dispatchers.IO) {
                WarehousePresetTimeSlotsWriteBack.applyPayload(
                    repository = repo,
                    payload = request.payload,
                    schemeName = WarehouseStrings.warehouseImportedTimeSchemeName
                        .filled("schoolName", school.name),
                )
            }
            when (result) {
                is WarehousePresetTimeSlotsWriteBack.PayloadResult.Applied -> {
                    appliedSectionsSignature = result.signature
                    answerRequest(request.requestId, "true", kind = "savePresetTimeSlots")
                }

                is WarehousePresetTimeSlotsWriteBack.PayloadResult.InvalidFormat -> {
                    answerRequest(request.requestId, "false", kind = "savePresetTimeSlots")
                    showToasts(listOf(WarehouseStrings.invalidSectionTimeFormat.zh))
                }

                is WarehousePresetTimeSlotsWriteBack.PayloadResult.NoSectionTimes -> {
                    answerRequest(request.requestId, "false", kind = "savePresetTimeSlots")
                    showToasts(listOf(WarehouseStrings.noSectionTimesToSave.zh))
                }

                is WarehousePresetTimeSlotsWriteBack.PayloadResult.Failed -> {
                    val rawReason = result.errorCode
                        ?: result.cause?.javaClass?.simpleName
                        ?: "unknown"
                    Log.w(LOG_TAG, "preset time slots write failed: $rawReason")
                    // 错误码过时间方案服务消息本地化（认不出的码原样返回，不会变空串）；
                    // 异常类名不是 service message 码，保持原文不喂本地化器。
                    val reason = result.errorCode
                        ?.let { TimeSchemeServiceMessages.localize(it) }
                        ?: rawReason
                    answerRequest(request.requestId, "false", kind = "savePresetTimeSlots")
                    showToasts(
                        listOf(
                            WarehouseStrings.saveSectionTimesFailedWithError.filled("error", reason),
                        ),
                    )
                }
            }
        }
    }

    // 首次导入 / 显式「录制导入」入口的自动录制（Dart initState postFrame 的等价位）。
    // 意图消费一次即清：从页面清单直接回到这一页时不应再自动开录制。
    LaunchedEffect(target.loginUrl) {
        if (state.autoRecordMacro) {
            state.autoRecordMacro = false
            startMacroRecording(autoRecord = true)
        }
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

            "toast" -> {
                // 对齐旧版（`_handleBridgeMessage` 的 toast 分支）：正文取脚本给的
                // message 原文，空不弹。脚本「正在获取课表…」「成功导入 N 条」全靠它。
                // 宏回放期间的成功提示抑制判据属回放引擎（F08-8c），本批不移植。
                val text = warehouseBridgeMessageText(raw)
                if (text != null) {
                    Toast.makeText(context, text, Toast.LENGTH_SHORT).show()
                }
            }

            "confirm",
            "prompt",
            "singleSelection",
            "saveCourseConfig",
            -> {
                if (!scriptActive) {
                    Log.w(LOG_TAG, "dialog message dropped outside import execution: $type")
                } else {
                    val request = warehouseBridgeDialogRequest(raw)
                    when {
                        // 解析不出界面（坏载荷等）：降级默认值回答。
                        request == null -> handleDialogFallback(raw)

                        // 同刻已有挂起：脚本本应 await 串行；后到的按降级回答，不吞（避免第二个 Promise 挂死）。
                        pendingDialog != null -> {
                            Log.w(LOG_TAG, "bridge dialog $type answered by fallback: another dialog is pending")
                            handleDialogFallback(raw)
                        }

                        else -> {
                            rememberPendingDialogKey(raw)
                            pendingDialog = request
                        }
                    }
                }
            }

            // savePresetTimeSlots 不是「用户输入」型交互：没有界面可弹，
            // 解析载荷直接落盘并套用（写链路见 WarehousePresetTimeSlotsWriteBack）。
            "savePresetTimeSlots" -> {
                if (!scriptActive) {
                    Log.w(LOG_TAG, "dialog message dropped outside import execution: $type")
                } else {
                    handleSavePresetTimeSlots(raw)
                }
            }

            // 宏录制事件（P1）：门禁已按录制态放行，这里再自检一道（纵深防御，
            // 与 Dart `_handleMacroEvent` 开头的状态判断同口径）。
            "macro:event" -> handleMacroEvent(raw)

            "complete" -> {
                cancelPendingDialog("complete")
                scriptActive = false
                Log.i(LOG_TAG, "bridge complete")
            }

            "error" -> {
                cancelPendingDialog("error")
                scriptActive = false
                // 对齐旧版：轻提示显示脚本上报的具体原因，缺省才落到固定文案。
                Log.w(LOG_TAG, "bridge error reported by adapter script")
                showToasts(
                    listOf(
                        warehouseBridgeMessageText(raw)
                            ?: WarehouseStrings.courseImportScriptFailed.zh,
                    ),
                )
            }

            else -> Log.i(LOG_TAG, "bridge message type=$type")
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        WarehouseWebLoginPage(
            title = school.name,
            sessionState = session.copy(
                macroState = macroState,
                recordedStepsCount = recordedStepsCount,
            ),
            webViewController = controller,
            trustedLoginUrls = trustedLoginUrls,
            onBack = onBack,
            onWebProgress = { progress ->
                session = session.withStage(WarehouseWebLoginWebState.stageForProgress(progress))
            },
            onWebPageStarted = { url ->
                // 新导航会重建 JS 上下文：上一轮的脚本窗口随之结束。
                // 挂着的对话框先按「取消」回话（旧 JS 上下文若还活着能收到，收不到也无害）。
                cancelPendingDialog("page navigation")
                scriptActive = false
                appliedSectionsSignature = null
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
                // 录制中每个页面加载完都重注入录制 JS（安装哨兵让重复注入变 no-op；
                // 新导航重建 JS 上下文，不重注入的话后几页收不到任何事件——Dart 同款）。
                if (macroState == WarehouseMacroActionState.RECORDING) {
                    controller.injectJavaScript(WarehouseMacroRecorderJs.INJECT_SCRIPT)
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
                // 数据回传（courses）与对话框分发在这里处理；正文不进日志（课表里有学号/课表内容）。
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
                if (macroState == WarehouseMacroActionState.RECORDING) {
                    stopMacroRecording()
                } else {
                    startMacroRecording(autoRecord = false)
                }
            },
            onExecuteImport = { executeImportScript() },
        )

        // 网页对话框原生界面（F32）：挂在页面之上，常驻组合、show 由 pendingDialog 驱动。
        WarehouseBridgeDialogHost(
            request = pendingDialog,
            onAction = { action ->
                when (action) {
                    is WarehouseBridgeDialogUserAction.SaveConfig -> handleSaveConfig(action)

                    is WarehouseBridgeDialogUserAction.Dismiss -> {
                        val pending = pendingDialog
                        // requestId 对得上才答：弹层已换人时旧动作作废（脚本 requestId 唯一）。
                        if (pending != null && pending.requestId == action.requestId) {
                            // 录制态：confirm 的取消也记成 false（Dart 同口径）；
                            // prompt / 单选的取消不记（Dart 只在结果非 null 时存）。
                            if (pending is WarehouseBridgeDialogRequest.Confirm) {
                                recordMacroDialogResponse(false)
                            }
                            answerAndClose(warehouseBridgeDialogCancelAnswer(pending))
                        }
                    }

                    is WarehouseBridgeDialogUserAction.Confirm -> {
                        recordMacroDialogResponse(action.confirmed)
                        answerAndClose(warehouseBridgeConfirmAnswer(action.requestId, action.confirmed))
                    }

                    is WarehouseBridgeDialogUserAction.Prompt -> {
                        recordMacroDialogResponse(action.text)
                        answerAndClose(warehouseBridgePromptAnswer(action.requestId, action.text))
                    }

                    is WarehouseBridgeDialogUserAction.Selection -> {
                        // 录制存「所选项文字」不存下标（Dart 同款：选项顺序变了也不会选错）。
                        val pending = pendingDialog
                        if (pending is WarehouseBridgeDialogRequest.SingleSelection &&
                            action.index in pending.options.indices
                        ) {
                            recordMacroDialogResponse(pending.options[action.index])
                        }
                        answerAndClose(warehouseBridgeSelectionAnswer(action.requestId, action.index))
                    }
                }
            },
        )

        // courses 写回前的两步确认（对齐 Dart askImportReplaceExisting / pickImportSemesterConfig）：
        // 常驻组合、show 由导入流程状态驱动；取消任一步 = 中止整次导入。
        val importSession = coursesSession
        WarehouseReplaceExistingDialog(
            show = importSession != null && coursesAskReplace,
            courseCount = importSession?.courses?.size ?: 0,
            onPick = { replaceExisting ->
                // 录制态：把覆盖/更新的选择存进宏（N6 固定键 replaceExisting）。
                if (macroState == WarehouseMacroActionState.RECORDING) {
                    macroDialogResponses["replaceExisting"] = replaceExisting
                }
                coursesReplaceExisting = replaceExisting
                coursesAskReplace = false
            },
            onCancel = { cancelCoursesImport() },
        )
        WarehouseSemesterMappingSheet(
            show = importSession != null && !coursesAskReplace,
            // 初值对齐旧版：现设开学日，没设过用今天（`provider.settings.semesterStartDate ?? DateTime.now()`）。
            initialStartDate = remember(importSession) {
                repository?.snapshot?.settings?.semesterStartDate?.toLocalDate() ?: LocalDate.now()
            },
            onConfirm = { startDate, firstCourseWeek ->
                confirmCoursesImport(startDate, firstCourseWeek)
            },
            onDismiss = { cancelCoursesImport() },
        )

        // 第三步（按需）：节次表装不下导入课程时问「自动补齐并导入」；
        // 取消落「导入已中断」（旧版 ensureImportSectionCapacity 的取消路径）。
        val finalizePlan = coursesFinalizePlan
        WarehouseSectionExpansionDialog(
            show = coursesAskExpansion && finalizePlan != null,
            currentSectionCount = finalizePlan?.currentSectionCount ?: 0,
            requiredSectionCount = finalizePlan?.requiredSectionCount ?: 0,
            onConfirm = {
                val plan = finalizePlan
                if (plan != null) finalizeCoursesImport(plan, expandSections = true)
            },
            onCancel = { cancelCoursesImport(interrupted = true) },
        )

        // 录制保存询问（P1）：常驻组合、show 由 macroSavePrompt 驱动；
        // 保存 → 构造记录落盘（键与 Dart 同键共读）；取消 → 清状态不留痕。
        val savePrompt = macroSavePrompt
        WarehouseMacroSaveRecordingDialog(
            show = savePrompt != null,
            stepCount = savePrompt?.steps?.size ?: 0,
            autoRecord = savePrompt?.autoRecord ?: false,
            onSave = { saveCurrentMacro() },
            onDiscard = { discardCurrentMacro() },
        )
    }
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
