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
import com.mutx163.qingyu.platform.KeystoreSecretCipher
import com.mutx163.qingyu.platform.PrefsKeyValueStore
import com.mutx163.qingyu.transfer.MAX_ALLOWED_SEMESTER_WEEK_COUNT
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
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
 * 一次「执行导入脚本」的预算（毫秒）。**逐字对齐 Dart**：
 * `warehouse_adapter_web_login_screen.dart` 的 `_importTimeout = Duration(seconds: 30)`。
 *
 * 为什么要它：脚本在网页里挂死时没有任何回调会回来；没有这道计时，界面就永久停在
 * 「执行中」，而 stage 卡在 EXECUTING 之后连重试都会被闸门拒掉（用户唯一出路是刷新）。
 */
private const val SCRIPT_EXECUTION_TIMEOUT_MS = 30_000L

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
    // 壳给每个路由条目单独 `remember { WarehouseShellState() }`（条目彼此是独立组合作用域），
    // 所以上一页写进 state 的学校和适配器到不了这一页。来源页点按钮时已
    // [WarehouseImportHandoff.publish]，这里首次组合取走（取走即清）。
    val handoff = remember { WarehouseImportHandoff.take() }
    val school = state.school ?: handoff?.school
    val adapter = state.adapter ?: handoff?.adapter

    if (school == null || adapter == null) {
        // 拿不到目标（只可能从页面清单直接点进来）：给一句实话 + 返回键，
        // **不再静默退回选校页**——用户实报的「点网页导入，回答学校列表页面」就是那一下静默跳转。
        LaunchedEffect(Unit) { Log.w(LOG_TAG, "webLogin opened without school/adapter") }
        WarehouseNoTargetPage(WarehouseStrings.webLoginImport.zh, onBack)
        return
    }

    // 交接件落进本页状态：宏的「自动录制 / 待回放」各自只消费一次（与页内路径同一套消费逻辑）。
    LaunchedEffect(Unit) {
        if (state.school == null) state.school = school
        if (state.adapter == null) state.adapter = adapter
        if (handoff?.autoRecordMacro == true) state.autoRecordMacro = true
        if (handoff?.playbackMacro != null) state.playbackMacro = handoff.playbackMacro
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

    // ---- 记住账号 / 密码（F28 收尾）----
    // 凭据**只以密文落盘**：AndroidKeyStore 里的 AES-256-GCM（`KeystoreSecretCipher`），
    // 键名与 Dart 逐字一致（`warehouse_secure_remembered_login_<adapterId>`）；
    // 旧版本写在普通 prefs 里的**明文**键在首次读取时迁移进密钥库并删除，见存储类 KDoc。
    // 存储层只收「加密 / 解密」两个函数引用（模型层不能依赖 platform/，见其 KDoc）。
    val rememberedStore = remember(context) {
        val cipher = KeystoreSecretCipher(WarehouseRememberedLoginStore.KEY_ALIAS)
        WarehouseRememberedLoginStore(
            store = PrefsKeyValueStore(context),
            encrypt = cipher::encrypt,
            decrypt = cipher::decrypt,
        )
    }
    // 已记住的凭据（内存镜像）：站点门禁、保存后回填、提示卡都要它。
    // 与 session.rememberedAccount 分开存是因为「门禁挡住自动填充」时仍要知道
    // 「这个适配器已经记过账号」——那决定保存提示问不问。
    var storedLogin by remember { mutableStateOf<WarehouseRememberedLogin?>(null) }
    /**
     * 触发「记住密码」卡片时所在的文档（`warehouseDocumentKey`）。
     *
     * 卡片会活到跳转之后；保存时只有当前文档仍是这张才算「人还在登录页」，
     * 才允许把凭据回填进页面。否则（登录后落地页，哪怕同 host）只落盘、不注入，
     * 避免把学号写进搜索框 / 个人中心表单。
     */
    var savePromptDocumentKey by remember(adapter.id) { mutableStateOf<String?>(null) }
    // 受信 host（适配器登记地址 + 自定义覆盖地址）：凭据**没绑 host**（老数据）时只认这几个站。
    val trustedLoginHosts = remember(adapter.importUrl, customUrl) {
        warehouseTrustedLoginHosts(adapter.importUrl, customUrl)
    }
    // 自动填充门禁：URL 一变就重算（跨站导航后立刻收回权限）。
    fun autofillAllowedOn(url: String?, login: WarehouseRememberedLogin?): Boolean =
        rememberedLoginAllowsUrl(login, url, trustedLoginHosts)

    // 读已记凭据：解密与磁盘 IO 都放 IO 线程（密钥库首次取密钥在部分机型上不便宜）。
    LaunchedEffect(adapter.id) {
        val loaded = withContext(Dispatchers.IO) { rememberedStore.rememberedLogin(adapter.id) }
        storedLogin = loaded
        session = session.copy(
            rememberedAccount = loaded,
            autofillHostAllowed = autofillAllowedOn(controller.liveUrl() ?: session.currentUrl, loaded),
        )
    }

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

    // ---- 宏回放（P2，对齐 Dart _startPlayback / PlaybackUiState / 完成处置）----
    // 本会话要回放的宏（快捷导入入口从适配器列表/课程导入页带来，消费一次即清）。
    var playbackMacroRecord by remember { mutableStateOf<WarehouseMacroRecord?>(null) }
    var playbackJob by remember { mutableStateOf<Job?>(null) }
    var playbackUiState by remember { mutableStateOf<WarehousePlaybackUiState?>(null) }
    var playbackProgress by remember { mutableStateOf<WarehouseReplayProgress?>(null) }
    // 暂停「继续/取消」的续跑闸：覆盖层按钮改这个状态。回调 → suspend 的桥接必须
    // 有一个续体容器；与 Dart 裸 Completer 的差别是取消路径**必** resume（见下），
    // 不存在悬挂（方案 §4.6 反对的是忘 complete 的裸 Completer，不是这个桥本身）。
    var pauseGate by remember { mutableStateOf<((Boolean) -> Unit)?>(null) }
    // complete 处置（N10）：回放自动执行脚本后等课程期间 = true；写回落定后复位。
    var playbackWaitingForCourses by remember { mutableStateOf(false) }
    // 完成 sheet 一次性闸（Dart _quickImportResultHandled：complete 在定局后到达即忽略）。
    var quickResultHandled by remember { mutableStateOf(false) }
    var showFinishedSheet by remember { mutableStateOf(false) }
    var finishedScriptStatus by remember { mutableStateOf<String?>(null) }
    // 回放完成后的「自动执行导入脚本」请求：onComplete 在前部声明（不能前向引用
    // executeImportScript），由后部 LaunchedEffect 消费（延迟 500ms，Dart 同款）。
    var autoExecuteRequested by remember { mutableStateOf(false) }

    fun isMacroReplaying(): Boolean = playbackJob?.isActive == true

    /** 求值 JS 并归一化结果（suspend 桥：`evaluateJavascript` 是回调；结果已解引号转义）。 */
    suspend fun evalJsNormalized(script: String): String? =
        kotlinx.coroutines.suspendCancellableCoroutine { cont ->
            try {
                controller.evaluateJavaScript(script) { result ->
                    if (cont.isActive) cont.resume(result, onCancellation = null)
                }
            } catch (error: Exception) {
                // 视图已离开组合等：按「这一拍读不到」处理，轮询下一拍重试。
                if (cont.isActive) cont.resume(null, onCancellation = null)
            }
        }

    // ---- 执行窗口：一个收尾出口 + 30 秒超时（放在这里的原因见下）----
    // 「执行导入脚本」进来之后的所有收尾（complete / error / 落盘完成 / 用户取消 /
    // 取消回放 / 重试回放 / 超时）都必须复位执行态，否则 stage 停在 EXECUTING，而重执行
    // 闸门 `planWarehouseScriptExecution` 硬要求 `stage == LOADED` ⇒ 一次导入完成后
    // （页面没跳转）再点「执行导入脚本」恒被拒，用户唯一出路是自己想到刷新。
    // 之所以收成一个函数而不是多处各写一遍：这些出口本来就该只有一种收尾语义，
    // 分散写必然会漏掉某处的某一行（2026-11-05 用户实报的正是这种漏）。
    //
    // ⚠️ 声明顺序：局部函数**先声明后使用**。本块必须排在 `cancelMacroPlayback` /
    // `retryMacroPlayback` 之前（它们也要走这条收尾）；而 `onScriptExecutionTimeout`
    // 依赖后面的 `cancelPendingDialog`，所以那两个函数留在 `executeImportScript` 之前。

    /** 当前这一轮脚本执行的 30 秒超时计时；null = 没有在执行。 */
    var importTimeoutJob by remember { mutableStateOf<Job?>(null) }

    /** 停掉 30 秒计时（不动 stage / scriptActive：换页等场景各自还要走自己的收尾）。 */
    fun cancelImportTimeout() {
        importTimeoutJob?.cancel()
        importTimeoutJob = null
    }

    /**
     * 网页是否正在导航（`onPageStarted` 置真，`onPageFinished` / `onWebError` 置假）。
     *
     * 为什么收尾要看它：回放中途被取消时，页面很可能正被 `loadUrl` 带向新文档。
     * 此时若把 stage 直接放回 `LOADED`，「执行导入脚本」闸门就是开着的——脚本会注入到
     * **即将被销毁的旧文档**里，什么都不回，用户白等 30 秒才看到一条 timeout；
     * 更糟的是脚本抢跑成功时，courses 赶在导航前回来，用户明明取消了回放却又收到一次
     * 导入确认。所以导航中只落到 `LOADING`（闸门关闭），加载完成/失败时由
     * `onWebPageFinished` / `onWebError` 自然推进到 `LOADED` / `ERROR`。
     */
    var pageNavigating by remember { mutableStateOf(false) }

    /**
     * 结束本轮脚本执行窗口：停超时、清执行期、**按页面实际状态**放回 `LOADED` 或 `LOADING`。
     *
     * @param errorMessage 本轮结束时的错误文案（失败路径传；成功/取消传 null 清掉旧错误）。
     */
    fun endScriptWindow(errorMessage: String? = null) {
        cancelImportTimeout()
        scriptActive = false
        // 导航进行中 → 只落 LOADING：闸门据此关着，等新文档加载完再开（见 [pageNavigating]）。
        val stage = if (pageNavigating) {
            WarehouseWebLoginStage.LOADING
        } else {
            WarehouseWebLoginStage.LOADED
        }
        session = session.withStage(stage, errorMessage)
    }

    fun resetPlaybackUi() {
        playbackUiState = null
        playbackProgress = null
    }

    fun cancelMacroPlayback() {
        playbackJob?.cancel()
        playbackJob = null
        // 取消回放也要收掉**脚本执行窗口**：回放完成后 `executeImportScript` 可能已经起了
        // 30 秒预算，不并入同一条收尾的话，用户取消之后超时仍会跑——屏上冒一条
        // 「导入失败：timeout」，而 stage 还挂在 EXECUTING 让重试被拒。
        endScriptWindow()
        // 取消路径必须续跑闸也释放（协程已取消，resume(false) 会被 cont.isActive 拦下，
        // 但闸要清空，避免泄漏旧闭包）。
        pauseGate?.invoke(false)
        pauseGate = null
        playbackWaitingForCourses = false
        resetPlaybackUi()
    }

    fun startMacroPlayback(record: WarehouseMacroRecord) {
        if (playbackJob?.isActive == true) return
        playbackMacroRecord = record
        playbackUiState = WarehousePlaybackUiState.PLAYING
        playbackProgress = null
        quickResultHandled = false
        playbackWaitingForCourses = false
        playbackJob = scope.launch {
            val replayer = WarehouseMacroReplayer(
                evalJs = { script -> evalJsNormalized(script) },
                loadUrl = { url -> controller.loadUrl(url) },
                // 生产等待原语：协程 delay（响应取消）；时钟用默认系统毫秒。
                sleep = { kotlinx.coroutines.delay(it) },
                onSkipLog = { Log.w(LOG_TAG, it) },
                callbacks = object : WarehouseMacroReplayer.Callbacks {
                    override fun onProgress(progress: WarehouseReplayProgress) {
                        playbackProgress = progress
                    }

                    override suspend fun onPauseForManualInput(
                        step: WarehouseMacroStep,
                        reason: String,
                    ): Boolean = kotlinx.coroutines.suspendCancellableCoroutine { cont ->
                        playbackProgress = playbackProgress?.copy(
                            status = ReplayStepStatus.PAUSED_FOR_INPUT,
                            pauseReason = reason,
                        )
                        playbackUiState = WarehousePlaybackUiState.PAUSED_FOR_INPUT
                        pauseGate = { shouldContinue ->
                            pauseGate = null
                            if (cont.isActive) {
                                if (shouldContinue) {
                                    playbackUiState = WarehousePlaybackUiState.PLAYING
                                    playbackProgress = playbackProgress?.copy(
                                        status = ReplayStepStatus.RUNNING,
                                        pauseReason = null,
                                    )
                                }
                                cont.resume(shouldContinue, onCancellation = null)
                            }
                        }
                    }

                    override fun onShowTip(message: String) {
                        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
                    }

                    override fun onComplete(success: Boolean, errorMessage: String?) {
                        when {
                            success -> {
                                // 回放完成 → 覆盖层切「执行导入脚本」；真正的执行由
                                // 后部 LaunchedEffect 消费（延迟 500ms，Dart
                                // _autoExecuteImportAfterPlayback 同款——不能在这里
                                // 直接调 executeImportScript：局部函数没有前向引用）。
                                playbackWaitingForCourses = true
                                autoExecuteRequested = true
                                playbackUiState = WarehousePlaybackUiState.EXECUTING_IMPORT
                            }

                            errorMessage != null -> {
                                playbackUiState = WarehousePlaybackUiState.ERROR
                                playbackProgress = playbackProgress?.copy(
                                    status = ReplayStepStatus.FAILED,
                                    errorMessage = errorMessage,
                                )
                            }

                            else -> {
                                // 用户取消：cancelMacroPlayback 已复位 UI，这里兜底收层。
                                playbackUiState = null
                            }
                        }
                    }
                },
            )
            replayer.execute(record)
        }
    }

    fun retryMacroPlayback() {
        val record = playbackMacroRecord ?: return
        playbackJob?.cancel()
        playbackJob = null
        // 重试 = 上一轮作废：同样的收尾语义（停 30 秒预算、stage 回 LOADED），
        // 否则旧一轮的计时会在新一轮中途误报超时。
        endScriptWindow()
        // Dart _retryPlayback：重载入口地址后从头回放（从干净页面起步）。
        controller.loadUrl(target.loginUrl)
        startMacroPlayback(record)
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

    /** 超时收尾：文案按 Dart 的两个分叉，然后统一走 [endScriptWindow]。 */
    fun onScriptExecutionTimeout() {
        if (!scriptActive) return
        // 回放完成后在等课程：Dart 用 `courseImportScriptNoCourses`（脚本没回课程数据），
        // 其余（脚本卡死）用 `executeFailedWithError('timeout')`。
        val waitingForCourses = playbackWaitingForCourses
        val message = if (waitingForCourses) {
            WarehouseStrings.courseImportScriptNoCourses.zh
        } else {
            WarehouseStrings.executeFailedWithError.filled("error", "timeout")
        }
        Log.w(
            LOG_TAG,
            "import script timeout after ${SCRIPT_EXECUTION_TIMEOUT_MS / 1000}s " +
                "waitingForCourses=$waitingForCourses",
        )
        cancelPendingDialog("timeout")
        endScriptWindow(errorMessage = message)
        // 回放覆盖层也要收干净：超时落在「回放等课程」那段时，覆盖层会停在
        // EXECUTING_IMPORT（「正在执行导入脚本」）永远不结束，用户只能去点覆盖层的
        // 取消才逃得出来——成功路径有 FINISHED sheet 兜底，超时没有。
        // 与回放失败的其它出口同形（切 ERROR + 把原因写进进度行），不新造状态。
        if (playbackUiState != null) {
            playbackUiState = WarehousePlaybackUiState.ERROR
            playbackProgress = playbackProgress?.copy(
                status = ReplayStepStatus.FAILED,
                errorMessage = message,
            )
        }
        playbackWaitingForCourses = false
        // 回放完成后的「自动执行导入」请求可能还在排队：本轮已超时收尾，别让它再起一次。
        autoExecuteRequested = false
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
    }

    // ⚠️ 顺序要求：局部函数**先声明后使用**，所以 onScriptExecutionTimeout 必须排在
    // armImportTimeout 之前。
    /**
     * 起 30 秒导入超时（对齐 Dart `_importTimeout = Duration(seconds: 30)`）。
     *
     * Dart 的 30 秒从脚本开始执行算起，超时给明确文案并复位执行态；不移植的话脚本
     * 一挂死就永久无反馈，叠加「stage 卡在 EXECUTING」连重试都被拒。
     */
    fun armImportTimeout() {
        importTimeoutJob?.cancel()
        importTimeoutJob = scope.launch {
            delay(SCRIPT_EXECUTION_TIMEOUT_MS)
            onScriptExecutionTimeout()
        }
    }

    fun executeImportScript() {
        if (isExecuting) return
        when (val plan = planWarehouseScriptExecution(session.stage, school, adapter)) {
            is WarehouseScriptExecutionPlan.Blocked -> {
                Log.w(LOG_TAG, "execute import blocked: ${plan.reason}")
                // **具体原因必须上屏**：以前这里一律弹「脚本执行失败」，用户读作
                // 「点了没反应」（审核 G1 的根因之一）。两类原因分开说，各自可行动：
                // - 没有脚本 = 这所学校确实导不了，去反馈/换学校；
                // - 页面没加载完 = 稍等一下再点。
                Toast.makeText(
                    context,
                    when (plan.reason) {
                        WarehouseScriptBlockReason.NO_SCRIPT_PATH -> WarehouseStrings.scriptEmpty.zh
                        WarehouseScriptBlockReason.PAGE_NOT_LOADED ->
                            WarehouseStrings.macroReplayWaitPageLoad.zh
                    },
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
                    // 时刻 B：网页里的上一轮脚本可能还活着。取消回放只停宿主侧的计时与 stage，
                    // **网页里没有取消原语** —— 旧脚本仍在抓数据、仍可能自己弹原生对话框。
                    // 此时直接注入 = 同一页面两个脚本实例并发跑：
                    //   ① 各回一条 courses，`coursesSession` 在解析窗口内挡不住第二条；
                    //   ② 两个实例各弹一次 confirm，第二条会被「同刻已有挂起」的兜底**自动答 true**
                    //      —— 用户从没见过的那句确认被原生替他点了。
                    // 所以注入前先问网页里的运行哨兵（wrapper 置位、脚本收尾时复位），为真就跳过本轮。
                    if (evalJsNormalized(WAREHOUSE_IMPORT_RUNNING_PROBE_JS) == "true") {
                        Log.w(LOG_TAG, "execute import skipped: previous script instance still running")
                        val message = WarehouseStrings.courseImportScriptStillRunning.zh
                        endScriptWindow(message)
                        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
                        isExecuting = false
                        return@launch
                    }
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
                            // 30 秒执行预算：脚本挂死时必须有反馈，且要能把 stage 放回
                            // LOADED（否则用户连重试都被闸门拒掉）。
                            armImportTimeout()
                        }

                        is WarehouseLoad.Failed -> {
                            Log.w(
                                LOG_TAG,
                                "adapter script load failed code=${loaded.code} attempts=${loaded.attempts}",
                            )
                            // 拉脚本失败也走统一收尾：stage 回到 LOADED（页面本身是好的），
                            // 网络恢复后用户可以直接再点一次，不用先刷新页面。
                            endScriptWindow(WarehouseStrings.courseImportScriptFailed.zh)
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

    // ---- 登录态观察（「记住账号 / 密码」的数据源，对齐 Dart `_handleLoginStateMessage`）----

    /**
     * `loginState`：页面里的观察脚本回传「用户正在敲的账号密码 + 有没有密码框」。
     *
     * 只更新**候选账号**（内存），不落盘、不进日志（里面有口令）；同时按当前页 host
     * 重算自动填充权限——跨站页面永远拿不到填充资格（钓鱼页防护）。
     */
    fun handleLoginState(raw: String) {
        val snapshot = warehouseLoginStateSnapshot(raw) ?: return
        val liveUrl = controller.liveUrl() ?: session.currentUrl
        // 登录提交后的新页面也会立刻 collect() 一次（通常没有密码框 ⇒ 空口令）。
        // 已提交、未作答的候选由模型层钉住，否则「记住密码」卡片会闪一下就消失。
        val incoming = WarehouseRememberedLogin(
            username = snapshot.username,
            password = snapshot.password,
            // 采集当时就带密码框 = 当前真在登录页：把宿主 host 一起记下。
            // 卡片会活到跳转之后，保存时不能再按「当时页面」算 host：统一认证常从
            // `cas.x` 跳到 `jw.x`，按跳转后的页面绑会让下次在登录页的填充永远被门禁拒掉。
            host = if (snapshot.hasPasswordField) warehouseUrlHost(liveUrl) else "",
        )
        val candidate = warehouseLoginCandidateAfterState(
            previous = session.candidateAccount,
            incoming = incoming,
            hasLoginAttempt = session.hasLoginAttempt,
            hasPromptedSave = session.hasPromptedSave,
        )
        session = session.copy(
            candidateAccount = candidate,
            hasPasswordField = snapshot.hasPasswordField,
            autofillHostAllowed = autofillAllowedOn(liveUrl, storedLogin),
        )
    }

    /** `loginAttempt`：用户真的点了登录 / 提交表单——从现在起才问「要不要记住密码」。 */
    fun handleLoginAttempt() {
        if (session.hasLoginAttempt) return
        savePromptDocumentKey = warehouseDocumentKey(controller.liveUrl() ?: session.currentUrl)
        session = session.copy(hasLoginAttempt = true)
    }

    /** 「自动填充」：把记住的凭据填进页面；**先过站点门禁**，跨站一律拒绝。 */
    fun fillRememberedLogin() {
        val login = storedLogin
        if (login == null) {
            session = session.copy(hasPromptedAutofill = true)
            return
        }
        val liveUrl = controller.liveUrl() ?: session.currentUrl
        if (!autofillAllowedOn(liveUrl, login)) {
            // 钓鱼页 / 换站：宁可什么都不填，也不把口令送出去。
            Log.w(LOG_TAG, "autofill refused: current host is not the credential's bound host")
            session = session.copy(hasPromptedAutofill = true)
            return
        }
        controller.injectJavaScript(warehouseAutofillLoginScript(login))
        session = session.copy(hasPromptedAutofill = true)
    }

    /** 「暂不填充」：只记下问过，别一直追着问。 */
    fun dismissAutofillPrompt() {
        session = session.copy(hasPromptedAutofill = true)
    }

    /**
     * 「记住并自动填充」：候选凭据绑**采集时**的站点 host 后加密落盘。
     *
     * 回填自带来源校验：卡片会活到跳转之后，只有当前文档仍是触发卡片的那一页
     * （[savePromptDocumentKey]）且这页确实还有密码框时才注入，避免在登录后的
     * 落地页把学号写进搜索框 / 个人中心表单（发布版弹模态框时人还在登录页，
     * 所以它没有这个后置问题）。
     */
    fun saveRememberedLogin() {
        val candidate = session.candidateAccount
        val liveUrl = controller.liveUrl() ?: session.currentUrl
        val promptKey = savePromptDocumentKey
        if (candidate.username.isEmpty() || candidate.password.isEmpty()) {
            session = session.copy(hasPromptedSave = true)
            return
        }
        // 已绑定的 host 保持不变（同一份凭据不因为换了子域就悄悄改绑）；新凭据绑当前页 host。
        val bound = if (candidate.host.isNotEmpty()) {
            candidate
        } else {
            candidate.copy(host = warehouseUrlHost(liveUrl))
        }
        session = session.copy(
            hasPromptedSave = true,
            // 作答即结束这次「登录尝试」：把口令从会话状态里抹掉，并记下「自动填充问过」，
            // 免得卡片刚消失又弹一张「要不要帮你填」。
            hasLoginAttempt = false,
            hasPromptedAutofill = true,
            candidateAccount = candidate.copy(password = ""),
        )
        scope.launch {
            withContext(Dispatchers.IO) { rememberedStore.saveRememberedLogin(adapter.id, bound) }
            storedLogin = bound
            session = session.copy(rememberedAccount = bound)
            val nowUrl = controller.liveUrl() ?: session.currentUrl
            if (session.hasPasswordField &&
                promptKey != null &&
                promptKey == warehouseDocumentKey(nowUrl) &&
                autofillAllowedOn(nowUrl, bound)
            ) {
                controller.injectJavaScript(warehouseAutofillLoginScript(bound))
            }
            Toast.makeText(
                context,
                WarehouseStrings.rememberedCurrentLoginSuccess.zh,
                Toast.LENGTH_SHORT,
            ).show()
        }
    }

    /** 「不记住」：这次不问而已；盘上已有的凭据保持原样（清除是另一条明确动作）。 */
    fun dismissSavePrompt() {
        session = session.copy(
            hasPromptedSave = true,
            // 作答即结束这次尝试：口令不再留在会话状态里，也不再追问自动填充。
            hasLoginAttempt = false,
            hasPromptedAutofill = true,
            candidateAccount = session.candidateAccount.copy(password = ""),
        )
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

    // handleCoursesMessage 在 confirmCoursesImport 之后声明：回放旁路要直接调它落盘
    // （Kotlin 局部函数没有前向引用，见宏方法块的同款注释）。

    /** 两步确认任一步取消：中止整次导入（对齐旧版——不写回、提示、结束执行期）。 */
    fun cancelCoursesImport(interrupted: Boolean = false) {
        coursesSession = null
        coursesAskReplace = false
        coursesFinalizePlan = null
        coursesAskExpansion = false
        // 取消也是「执行窗口结束」：走统一收尾，stage 回 LOADED，用户可以直接重试。
        endScriptWindow()
        // 回放等课程期间被用户取消：等待标志复位——其后到达的 complete 走 IGNORE，
        // 不把取消翻成成功（N10 的定局口径）。
        playbackWaitingForCourses = false
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
        // 课程已收齐、开始落盘：本轮脚本窗口到此结束（stage 回 LOADED，可再次导入）。
        endScriptWindow()
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
                    // 回放成功收尾（对齐 Dart `_markMacroImportCompleted`）：记账
                    // （成功计数 +1、scriptPageUrl 更新为本次脱敏地址；**绝不抛**——
                    // 导入已成功，存储异常不能把成功翻成失败）→ 覆盖层切 FINISHED →
                    // 弹「导入完成」sheet（一次性闸置位，其后到达的 complete 一律忽略）。
                    if (playbackWaitingForCourses) {
                        playbackWaitingForCourses = false
                        quickResultHandled = true
                        playbackUiState = WarehousePlaybackUiState.FINISHED
                        finishedScriptStatus = doneMessagesFor(plan, result.importedCount)
                            .joinToString(separator = " ")
                        scope.launch {
                            withContext(Dispatchers.IO) {
                                macroStore.recordSuccessfulImport(
                                    schoolId = school.id,
                                    adapterId = adapter.id,
                                    scriptPageUrl = sanitizeWarehouseScriptPageUrl(
                                        controller.liveUrl() ?: target.loginUrl,
                                    ),
                                )
                            }
                            showFinishedSheet = true
                        }
                    }
                }

                is WarehouseCoursesImportApply.Result.Failed -> {
                    // 服务码（如节次补不满）过本地化再展示；其余落固定文案。
                    val text = result.serviceMessage
                        ?.let { TimeSchemeServiceMessages.localize(it) }
                        ?: WarehouseStrings.importFailedStatus.zh
                    Log.w(LOG_TAG, "courses import failed serviceMessage=${result.serviceMessage}")
                    showToasts(listOf(text))
                    // 回放等课程期间的写回失败：覆盖层切 ERROR（失败可重试/关闭），
                    // 等待标志复位——其后到达的 complete 走 IGNORE，不再翻成成功。
                    if (playbackWaitingForCourses) {
                        playbackWaitingForCourses = false
                        playbackUiState = WarehousePlaybackUiState.ERROR
                        playbackProgress = playbackProgress?.copy(
                            status = ReplayStepStatus.FAILED,
                            errorMessage = text,
                        )
                    }
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
            // 回放旁路（N6 取用侧，Dart `recordedReplaceExisting` / `recordedSemesterConfig`）：
            // 录过的答案直接用，不弹窗；**没录过的照常弹窗**（前台回放未记录时 Dart
            // 也是照常问，不替用户编答案）。空课表恒按覆盖走（与旧版同一口径）。
            val replayRecord = playbackMacroRecord
            val replaying = replayRecord != null && isMacroReplaying()
            val recordedReplace = if (replaying) {
                replayRecord.dialogResponses["replaceExisting"] as? Boolean
            } else {
                null
            }
            val recordedSemester = if (replaying) {
                replayRecord.dialogResponses["semesterConfig"] as? Map<*, *>
            } else {
                null
            }
            val recordedStartDate = (recordedSemester?.get("startDate") as? String)
                ?.let { warehouseSemesterStartDate(it)?.toLocalDate() }
            val recordedFirstWeek = (recordedSemester?.get("firstCourseWeek") as? Number)?.toInt()
            if (empty || recordedReplace != null) {
                coursesReplaceExisting = empty || recordedReplace == true
                coursesAskReplace = false
                if (recordedStartDate != null && recordedFirstWeek != null) {
                    // 两步都有录制值：直接落盘，一次弹窗都不问。
                    confirmCoursesImport(recordedStartDate, recordedFirstWeek)
                }
                // 只跳过了第一步（缺开学日录制值）：第二步照常弹（页面按
                // coursesAskReplace=false 呈现开学日/首周确认）。
            } else {
                coursesAskReplace = true
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
        // 快捷导入入口（P2）：列表页/课程导入页带来的宏，进页即自动回放
        //（Dart initState postFrame → _startPlayback 的等价位，同样消费一次即清）。
        val pendingReplay = state.playbackMacro
        if (pendingReplay != null) {
            state.playbackMacro = null
            startMacroPlayback(pendingReplay)
        }
    }

    // 回放完成 → 自动执行导入脚本（延迟 500ms，Dart _autoExecuteImportAfterPlayback 同款）。
    // 放在 executeImportScript 声明之后：局部函数没有前向引用。
    LaunchedEffect(playbackUiState) {
        if (playbackUiState == WarehousePlaybackUiState.EXECUTING_IMPORT && autoExecuteRequested) {
            autoExecuteRequested = false
            kotlinx.coroutines.delay(500)
            executeImportScript()
        }
    }

    /**
     * 回放旁路（N6 取用侧）：confirm / prompt / singleSelection 用录制的应答直接
     * resolve，不进挂起弹层；`saveCourseConfig` 是表单交互，没有录制应答，
     * 照常弹给用户（与 Dart 一致）。
     *
     * 兜底口径（逐字对齐 Dart §1.5 表）：confirm 未记录**默认 true**（自动化导入
     * 不因旧宏没见过该弹窗而被取消）；prompt 未记录用脚本 defaultValue；
     * singleSelection 未记录/答案过期回退脚本 selectedIndex。
     */
    fun resolveReplayDialogAnswer(record: WarehouseMacroRecord, raw: String) {
        val request = warehouseBridgeDialogRequest(raw)
        if (request == null) {
            handleDialogFallback(raw)
            return
        }
        val type = warehouseBridgeMessageType(raw).orEmpty()
        val key = warehouseDialogResponseKey(
            type,
            MiniJson.tryParse(raw) as? Map<*, *> ?: emptyMap<Any?, Any?>(),
        )
        val recorded = record.dialogResponses[key]
        when (request) {
            is WarehouseBridgeDialogRequest.Confirm ->
                answerRequest(
                    request.requestId,
                    ((recorded as? Boolean) ?: true).toString(),
                    kind = "confirm(replay)",
                )

            is WarehouseBridgeDialogRequest.Prompt ->
                answerRequest(
                    request.requestId,
                    MiniJson.encode((recorded as? String) ?: request.defaultValue),
                    kind = "prompt(replay)",
                )

            is WarehouseBridgeDialogRequest.SingleSelection -> {
                val index = resolveWarehouseRecordedSelectionIndex(
                    recorded = recorded,
                    options = request.options,
                    fallbackIndex = request.selectedIndex,
                ) ?: request.selectedIndex
                answerRequest(request.requestId, index.toString(), kind = "singleSelection(replay)")
            }

            is WarehouseBridgeDialogRequest.SaveConfig ->
                // 不可达兜底：挂点已排除 saveCourseConfig（表单交互不旁路，照常弹层）。
                // 万一上游条件变化走到这里，降级默认值回答比挂死脚本的 Promise 好。
                handleDialogFallback(raw)
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
                // 回放期间成功/进度类脚本提示抑制（N9）：完成 sheet / 覆盖层已会
                // 展示结果，不叠两条提示。
                val text = warehouseBridgeMessageText(raw)
                val suppressedByReplay = isMacroReplaying() &&
                    (isWarehouseScriptImportSuccessToast(text) ||
                        isWarehouseScriptImportProgressToast(text))
                if (text != null && !suppressedByReplay) {
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
                            val replayRecord = playbackMacroRecord
                            if (replayRecord != null && isMacroReplaying() && type != "saveCourseConfig") {
                                // 回放旁路（N6 取用侧）：录过的答案直接 resolve，
                                // 不进挂起弹层（门禁后、分发前，对齐方案 §4.12）。
                                resolveReplayDialogAnswer(replayRecord, raw)
                            } else {
                                rememberPendingDialogKey(raw)
                                pendingDialog = request
                            }
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
                // complete 的处置判定（N10）：saveImportedCourses 在 JS 侧是
                // fire-and-forget，complete 完全可能落在「本轮已定局」之后——
                // 不忽略它，取消掉的导入会在状态栏显示成功。判定顺序：
                // 已定局（执行期已结束）> 回放等课程（只更新状态文字）> 正常收尾。
                val action = warehouseImportCompletionAction(
                    importExecutionActive = scriptActive,
                    macroReplayActive = isMacroReplaying() || playbackWaitingForCourses,
                    playbackWaitingForCourses = playbackWaitingForCourses,
                    quickResultHandled = quickResultHandled,
                )
                when (action) {
                    WarehouseImportCompletionAction.FINALIZE -> {
                        // 脚本报完成 = 本轮执行窗口结束。**必须复位 stage**，
                        // 否则 page 没跳转时 stage 停在 EXECUTING，重执行闸门会一直拒。
                        endScriptWindow()
                        Log.i(LOG_TAG, "bridge complete: finalize")
                    }

                    WarehouseImportCompletionAction.SHOW_STATUS_ONLY -> {
                        // 回放还在等课程：保持执行期（courses 随后到达），complete 本身不动收尾。
                        Log.i(LOG_TAG, "bridge complete during playback waiting for courses: status only")
                    }

                    WarehouseImportCompletionAction.IGNORE -> {
                        Log.i(LOG_TAG, "bridge complete after settlement: ignored")
                    }
                }
            }

            "error" -> {
                cancelPendingDialog("error")
                // 对齐旧版：轻提示显示脚本上报的具体原因，缺省才落到固定文案。
                // 收尾走统一出口：脚本报错也要能把 stage 放回 LOADED 再重试。
                val errorText = warehouseBridgeMessageText(raw)
                    ?: WarehouseStrings.courseImportScriptFailed.zh
                Log.w(LOG_TAG, "bridge error reported by adapter script")
                endScriptWindow(errorMessage = errorText)
                showToasts(listOf(errorText))
            }

            // 登录态观察（记住账号 / 密码）：账号口令只进内存做判定，不落盘、不进日志。
            "loginState" -> handleLoginState(raw)

            // 用户点了登录 / 提交表单：从这里起才允许问「要不要记住密码」。
            "loginAttempt" -> handleLoginAttempt()

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
            foregroundReplayActive = isMacroReplaying(),
            onBack = onBack,
            onWebProgress = { progress ->
                session = session.withStage(WarehouseWebLoginWebState.stageForProgress(progress))
            },
            onWebPageStarted = { url ->
                // 新导航会重建 JS 上下文：上一轮的脚本窗口随之结束。
                // 挂着的对话框先按「取消」回话（旧 JS 上下文若还活着能收到，收不到也无害）。
                cancelPendingDialog("page navigation")
                // 导航一开始就置真：`endScriptWindow` 据此只落 LOADING（闸门关着），
                // 不让脚本注入到即将被销毁的旧文档（否则用户白等 30 秒才见一条 timeout）。
                pageNavigating = true
                // 旧脚本窗口的 30 秒预算必须一起停：否则计时在下一拍还会替新页面误报超时。
                // 走统一收尾（导航中 → 只落 LOADING），加载完/失败由下面两个回调推进。
                endScriptWindow()
                appliedSectionsSignature = null
                session = session.copy(
                    currentUrl = url,
                    stage = WarehouseWebLoginStage.LOADING,
                    errorMessage = null,
                    // 换页 = 换了一组输入框：「问过没有」全部作废，自动填充权限在页面
                    // 加载完/收到 loginState 时按新 host 重算（Dart 在 `_onPageStarted`
                    // 里同样重置 `_hasPromptedAutofill`）。
                    //
                    // candidateAccount / hasLoginAttempt **不清**（2026-11-07 用户实报
                    // 「第一次输密码不弹记住密码」）：填完账号密码点「登录」会触发表单
                    // 提交 ⇒ 跳转 ⇒ 新页面，`loginAttempt` 常在新文档注入观察脚本
                    // **之前/同时**到达，候选账号也往往来不及在新页面重采。这时清零的
                    // 后果：门禁收到 loginAttempt 时 `hasLoginAttempt` 又是 false、
                    // 候选是空的 ⇒ 「记住密码」卡片永远不出现。Dart 只重置
                    // `_hasPromptedAutofill`（`onPageStarted`，:390），
                    // `_latestLoginCandidate` / `_hasPromptedSave` 都留在内存里等
                    // `_handleLoginAttempt` 消费——同口径保留。
                    hasPasswordField = false,
                    hasPromptedAutofill = false,
                    autofillHostAllowed = false,
                )
            },
            onWebPageFinished = { url ->
                // 导航结束：闸门恢复由 stage 决定（正常推进到 LOADED，报过错则保留 ERROR）。
                pageNavigating = false
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
                // 登录态观察脚本（**记住账号/密码的数据源**）：每页加载完注入一次，
                // 脚本自带 `__qingyuLoginWatcherInstalled` 哨兵，重复注入是 no-op。
                // 不注入就没有候选账号 ⇒ 保存提示永远不会问（这正是「记住密码」以前整条失效的原因）。
                controller.injectJavaScript(WarehouseLoginWatcherJs.INSTALL_SCRIPT)
                // 页面换站后立刻重算自动填充权限：跨站必须收回（钓鱼页防护）。
                session = session.copy(
                    autofillHostAllowed = autofillAllowedOn(url, storedLogin),
                )
            },
            onWebError = { error ->
                // 加载失败也算导航结束：别让「导航中」的标志永远挂着把闸门锁死。
                pageNavigating = false
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
            // ---- 记住账号 / 密码的四条回调（以前全是页面默认空实现 ⇒ 两张卡永远不出现）----
            onAutofillLogin = { fillRememberedLogin() },
            onDismissAutofill = { dismissAutofillPrompt() },
            onSaveRememberedLogin = { saveRememberedLogin() },
            onDismissSaveLogin = { dismissSavePrompt() },
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

        // 回放过程覆盖层（P2 / N11）：常驻组合、内容按 uiState 渲染，hidden（null）不出内容。
        WarehouseMacroPlaybackOverlay(
            uiState = playbackUiState,
            progress = playbackProgress,
            schoolName = school.name,
            adapterName = adapter.adapterName,
            onCancel = { cancelMacroPlayback() },
            onRetry = { retryMacroPlayback() },
            onDismiss = { resetPlaybackUi() },
            onContinueAfterPause = { pauseGate?.invoke(true) },
        )

        // 快捷导入完成 sheet（P2 / N12）：常驻组合、show 由状态驱动；「完成」退页。
        WarehouseQuickImportFinishedDialog(
            show = showFinishedSheet,
            schoolName = school.name,
            adapterName = adapter.adapterName,
            scriptStatus = finishedScriptStatus,
            onDismiss = {
                showFinishedSheet = false
                finishedScriptStatus = null
                resetPlaybackUi()
                onBack()
            },
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

/**
 * 宿主拿不到「学校 / 适配器」时的诚实空态（只可能从页面清单直接点进来）。
 *
 * 为什么不跳回选校页：用户实报「点网页导入，回答学校列表页面」——静默跳转既不解释、
 * 又像点错了地方。这里留在原页，给一句「该去哪选」+ 返回键，行为可预期。
 * 文案复用既有键（`warehouseSchoolTapHint`），不新增 ARB。
 */
@Composable
internal fun WarehouseNoTargetPage(title: String, onBack: () -> Unit) {
    QingyuPageScaffold(
        title = title,
        onBack = onBack,
    ) {
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
        ) {
            item(key = "no-target") {
                QingyuCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = QingyuPageCardMargin, vertical = 12.dp),
                    insideMargin = QingyuCardDefaults.ContentInsideMargin,
                ) {
                    Text(
                        text = WarehouseStrings.warehouseSchoolTapHint.zh,
                        style = MiuixTheme.textStyles.body1,
                        color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                    )
                }
            }
        }
    }
}
