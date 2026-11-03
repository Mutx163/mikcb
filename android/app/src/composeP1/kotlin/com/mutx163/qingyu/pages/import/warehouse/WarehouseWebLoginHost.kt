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
import com.mutx163.qingyu.transfer.MAX_ALLOWED_SEMESTER_WEEK_COUNT
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme
import java.time.LocalDate
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
 * | 脚本回传 `courses` | 两步确认（覆盖/更新 → 开学日/首周）→ 周次平移 → [WarehouseCourseWriteBack] 写回当前档案 |
 * | 网页 `toast` / `error` | 轻提示显示脚本原文（error 缺省兜底固定文案） |
 * | 网页 `confirm` / `prompt` / 单选 | [WarehouseBridgeDialogHost] 原生弹层（F32 收口），回传契约见模型层文件头 |
 * | 网页 `saveCourseConfig` | 字段表单 → 白名单字段落盘（[warehouseCourseConfigResolution]）→ `true`/`false` |
 * | 网页 `savePresetTimeSlots` | 载荷是节次数组、无界面可弹：直接走写链路（[WarehousePresetTimeSlotsWriteBack]）→ 落盘成功 `true` / 失败 `false` |
 * | 桥接消息 | 已由页面过了 §6.2 门禁；这里按类型分发 |
 *
 * ## 诚实边界（别删）
 *
 * 1. **抓回来的课写当前档案前问两步**（覆盖/更新、开学日/首周，任一取消=中止导入，
 *    对齐 Dart `askImportReplaceExisting` / `pickImportSemesterConfig`）；按用户确认的
 *    「课表第 1 周 = 校历第 N 周」平移周次后写回（[warehouseShiftCoursesToFirstWeek]）。
 *    与 Dart 的差异：节次容量自动扩展（`ensureImportSectionCapacity`）、随机配色、
 *    作息应用链（`_applyPendingImportedSectionsIfNeeded`，见 `savePresetTimeSlots`）
 *    未接入本流程；设置与课程是两次独立落盘，中间失败可能出现「设置已新、课程未动」。
 * 2. **`savePresetTimeSlots` 没有界面，但它不是「用户输入」型交互**：脚本的语义就是
 *    「存这套全局作息」，直接落盘并套用（解析 → 校验 → 仓储 createTimeScheme/updateTimeScheme
 *    + applyTimeScheme）；写链路失败回 `false` 并提示，不静默、也不画一个什么都不存的确认框。
 * 3. **登录态探针/自动填充未接**（`WarehouseWebLoginPage` 的 remembered-account 相关回调仍是默认空实现），
 *    与 i2-webview 认领文件里列的缺件一致。
 * 4. 宏录制/快捷导入仍未移植，按钮给「不可用」实话。
 * 5. 真机未验：仓库能不能拉到脚本、教务站能不能登录并通过脚本抓课，只有用户真机可见。
 */

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

    /** 一次待确认的脚本课程包：解析结果 + 上屏要用的计数（F32 前缺的两步确认挂这里）。 */
    var coursesSession by remember { mutableStateOf<WarehouseCoursesImportSession?>(null) }

    /** 第一步（覆盖/更新）是否还在问；false 且 [coursesSession] 非空 = 已进第二步。 */
    var coursesAskReplace by remember { mutableStateOf(false) }

    /** 用户在第一步的选择：true = 覆盖导入（替换），false = 更新课表（合并）。 */
    var coursesReplaceExisting by remember { mutableStateOf(true) }

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
    fun cancelCoursesImport() {
        coursesSession = null
        coursesAskReplace = false
        scriptActive = false
        Log.i(LOG_TAG, "courses import cancelled by user")
        showToasts(listOf(WarehouseStrings.importCancelledStatus.zh))
    }

    /** 第二步确认：按「课表第 1 周 = 校历第 N 周」平移，写回设置与课程。 */
    fun confirmCoursesImport(startDate: LocalDate, firstCourseWeek: Int) {
        val session = coursesSession ?: return
        val repo = repository ?: return
        val replaceExisting = coursesReplaceExisting
        coursesSession = null
        coursesAskReplace = false
        scope.launch {
            val result = withContext(Dispatchers.IO) {
                try {
                    val shifted = warehouseShiftCoursesToFirstWeek(session.courses, firstCourseWeek)
                    // 对齐旧版 importParsedCourses（timetable_import_export_service.dart:596-601）：
                    // 用户确认的开学日写进设置；课程需要的周数比现设大就自动扩。
                    val before = repo.snapshot.settings
                    val requiredWeeks = warehouseMaxCourseWeek(shifted, before.semesterWeekCount)
                    repo.updateSettings(
                        before.copy(
                            semesterStartDate = startDate.atStartOfDay(),
                            semesterWeekCount = maxOf(before.semesterWeekCount, requiredWeeks),
                        ),
                    )
                    WarehouseCourseWriteBack.apply(
                        repository = repo,
                        courses = shifted,
                        requestedMode = if (replaceExisting) {
                            WarehouseCourseWriteBack.Mode.REPLACE
                        } else {
                            WarehouseCourseWriteBack.Mode.MERGE
                        },
                        droppedCount = session.droppedCount,
                        weeksTrimmedCount = session.weeksTrimmedCount,
                    )
                } catch (error: Exception) {
                    Log.w(LOG_TAG, "courses write-back failed: ${error.javaClass.simpleName}")
                    WarehouseCourseWriteBack.Result.Failed(error)
                }
            }
            // messagesFor 吃的是 PayloadResult 形状；补上收到总数供文案用。
            val payloadResult = when (result) {
                is WarehouseCourseWriteBack.Result.Done ->
                    WarehouseCourseWriteBack.PayloadResult.Done(result.outcome, session.receivedCount)

                is WarehouseCourseWriteBack.Result.NoImportableCourses ->
                    WarehouseCourseWriteBack.PayloadResult.NoImportableCourses(
                        result.droppedCount,
                        session.receivedCount,
                    )

                is WarehouseCourseWriteBack.Result.Failed ->
                    WarehouseCourseWriteBack.PayloadResult.Failed(result.cause, session.receivedCount)
            }
            Log.i(LOG_TAG, "courses write-back result=${result.javaClass.simpleName}")
            showToasts(messagesFor(payloadResult))
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
                    val reason = result.errorCode
                        ?: result.cause?.javaClass?.simpleName
                        ?: "unknown"
                    Log.w(LOG_TAG, "preset time slots write failed: $reason")
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

                        else -> pendingDialog = request
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
            sessionState = session,
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
                toastUnavailable(context, "macro recording: engine not ported (F08-8c)")
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
                            answerAndClose(warehouseBridgeDialogCancelAnswer(pending))
                        }
                    }

                    is WarehouseBridgeDialogUserAction.Confirm ->
                        answerAndClose(warehouseBridgeConfirmAnswer(action.requestId, action.confirmed))

                    is WarehouseBridgeDialogUserAction.Prompt ->
                        answerAndClose(warehouseBridgePromptAnswer(action.requestId, action.text))

                    is WarehouseBridgeDialogUserAction.Selection ->
                        answerAndClose(warehouseBridgeSelectionAnswer(action.requestId, action.index))
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
