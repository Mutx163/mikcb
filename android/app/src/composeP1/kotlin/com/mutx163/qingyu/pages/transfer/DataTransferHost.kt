package com.mutx163.qingyu.pages.transfer

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
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
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.app.TimetableHostLogic
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableSnapshot
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.platform.AndroidTransferDocumentAdapter
import com.mutx163.qingyu.platform.AndroidTransferShareAdapter
import com.mutx163.qingyu.share.TransferApplyMode
import com.mutx163.qingyu.share.TransferChannel
import com.mutx163.qingyu.share.TransferEnvelope
import com.mutx163.qingyu.share.TransferScope
import com.mutx163.qingyu.share.TransferShareContract
import com.mutx163.qingyu.theme.QingyuTheme
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.theme.MiuixTheme
import java.time.LocalDateTime

/**
 * 「数据备份与迁移」页的**宿主**：把页面回调接到真实能力上。
 *
 * | 回调 | 落点 |
 * |---|---|
 * | 导出三条 | `DataTransferPackageLogic.build` 拼包 → `AndroidTransferShareAdapter.share`（写缓存 → FileProvider → 系统分享面板） |
 * | 选择文件并导入 | SAF 选文件 → `AndroidTransferDocumentAdapter.readText`（20MB 限长）→ 校验/解析 → 预览弹窗 → 落盘 |
 * | 二维码发送 | 拼**真**传输包 → 资源上限预检 → 交壳跳发送页（载荷经 [TransferShellBridge] 暂存） |
 * | 扫码接收 | 扫码页把收齐的字节写进 [TransferShellBridge]，回本页后走**同一条**导入链路 |
 * | 撤销 | 落盘前抓仓储现场 → 提示里的「撤销」整份写回 |
 *
 * ## 为什么写在 Compose 层（而不是模型层）
 *
 * 它要 `Context`（分享 / 选文件 / 提示）与 `rememberLauncherForActivityResult`，进不了 JVM 单测。
 * 所以**所有判断都下沉**到模型层（`DataTransferPackageLogic` / `DataTransferImportLogic` /
 * `DataTransferApplyLogic` / `TransferServiceMessages`），这里只做「调用顺序 + 线程 + 提示」。
 *
 * ## 线程约定（与 `WeatherSettingsHost` 一致）
 *
 * 打包 / 写盘 / 读文件 / 落盘一律 `Dispatchers.IO`；导航、弹层、提示回主线程。
 */
@Composable
fun DataTransferHost(
    repository: TimetableRepository,
    bridge: TransferShellBridge,
    onBack: () -> Unit,
    onOpenPage: (String) -> Unit,
    onRequestQrSend: () -> Unit,
    onRequestQrScan: () -> Unit,
) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    val dark = isSystemInDarkTheme()

    // 仓储现场：概览行与预览用的 diff 基线都读它，跟随 observe 变化。
    var snapshot by remember(repository) { mutableStateOf(repository.snapshot) }
    DisposableEffect(repository) {
        val subscription = repository.observe { snapshot = it }
        onDispose { subscription.close() }
    }

    var isExporting by remember { mutableStateOf(false) }
    var isImporting by remember { mutableStateOf(false) }

    var previewContent by remember { mutableStateOf<TransferPreviewContent?>(null) }
    var pendingImport by remember { mutableStateOf<PendingImport?>(null) }
    var undoToken by remember { mutableStateOf<TransferUndoToken?>(null) }

    var toastState by remember { mutableStateOf<TransferToastState?>(null) }
    fun showToast(message: String, actionLabel: String? = null, onAction: (() -> Unit)? = null) {
        toastState = TransferToastState(message, actionLabel, onAction)
    }

    val shareAdapter = remember(context) { AndroidTransferShareAdapter(context) }
    val documentAdapter = remember(context) { AndroidTransferDocumentAdapter(context) }

    /** 打包失败 / 分享失败 → 提示（Dart `_showTransferSendError`）。 */
    fun showSendFailure(code: String) {
        // Dart 的设备侧文案来自 `localizeServiceError`，未登记码兜底成「发生未知错误」；
        // 这里用同一条兜底口径，不另造句子。
        showToast(
            TransferStrings.sendFailedWithError.filled(
                "error",
                TransferServiceMessages.localize("transfer_send_${code.lowercase()}"),
            ),
        )
    }

    /** 导入一份包文本（文件与二维码两条入口共用）。 */
    fun openImportPreview(text: String, channel: TransferChannel) {
        when (val parsed = DataTransferImportLogic.parse(text)) {
            is TransferImportParseResult.Invalid ->
                showToast(TransferServiceMessages.localize(parsed.code))

            is TransferImportParseResult.Valid -> {
                // 预览的 diff 基线 = 当前课表按同 channel 打出来的包（Dart 也是现采 current）。
                val currentJson = (
                    DataTransferPackageLogic.build(
                        snapshot = snapshot,
                        request = TransferPackageRequest(
                            scope = TransferScope.CURRENT_TIMETABLE,
                            channel = channel,
                            packageId = TransferEnvelope.newPackageId(),
                            now = LocalDateTime.now(),
                        ),
                    ) as? TransferPackageResult.Success
                    )?.json.orEmpty()
                val overwrite = DataTransferImportLogic.diffSummaries(currentJson, text)
                // 合并模式不删：把 removed 归零，正是「合并预览」与「覆盖预览」的核心差别。
                val merge = overwrite.map { it.copy(removed = 0) }
                pendingImport = PendingImport(info = parsed.info, plan = parsed.plan)
                previewContent = TransferPreviewContent(
                    title = TransferStrings.selectImportModeTitle.zh,
                    message = DataTransferImportLogic.previewMessage(
                        channel = channel,
                        scope = parsed.info.scope,
                        packageId = parsed.info.packageId,
                        overwrite = overwrite,
                        merge = merge,
                    ),
                )
            }
        }
    }

    fun runExport(scope: TransferScope) {
        if (isExporting) return
        isExporting = true
        coroutineScope.launch {
            val failure = withContext(Dispatchers.IO) {
                when (val built = DataTransferPackageLogic.build(snapshot, exportRequest(scope))) {
                    is TransferPackageResult.Failure -> built.code
                    is TransferPackageResult.Success -> when (
                        val outcome = shareAdapter.share(
                            fileName = built.fileName,
                            content = built.json,
                            shareText = built.shareText,
                            shareSubject = built.shareSubject,
                        )
                    ) {
                        is AndroidTransferShareAdapter.Outcome.Launched -> null
                        is AndroidTransferShareAdapter.Outcome.Failed -> outcome.failure.name
                    }
                }
            }
            isExporting = false
            failure?.let(::showSendFailure)
        }
    }

    /** 二维码发送：拼真包 → 资源上限预检 → 交壳跳发送页。 */
    fun runQrSend(scope: TransferScope, selectedCourseIds: Set<String>, title: String) {
        if (isExporting) return
        isExporting = true
        coroutineScope.launch {
            // 预检（压缩 + 分帧容量）是重活：放 IO，回到主线程再决定导航还是提示。
            val result = withContext(Dispatchers.IO) { prepareQrPayload(snapshot, scope, selectedCourseIds, title) }
            isExporting = false
            when (result) {
                is QrPayloadResult.Failure -> showSendFailure(result.code)
                is QrPayloadResult.OverLimit -> showToast(TransferStrings.qrTransferResourceLimit.zh)
                is QrPayloadResult.Ready -> {
                    bridge.outboundPayload = result.bytes
                    bridge.outboundTitle = result.title
                    onRequestQrSend()
                }
            }
        }
    }

    val importLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument(),
    ) { uri ->
        // Dart：用户取消选文件 → 无提示，直接返回（`data_transfer_screen.dart:391-393`）。
        if (uri != null) {
            isImporting = true
            coroutineScope.launch {
                val result = withContext(Dispatchers.IO) { documentAdapter.readText(uri) }
                isImporting = false
                when (result) {
                    is AndroidTransferDocumentAdapter.ReadResult.TooLarge -> showToast(
                        TransferStrings.importFileTooLarge.filled("size", "20 MB"),
                    )

                    is AndroidTransferDocumentAdapter.ReadResult.ReadFailed ->
                        showToast(TransferStrings.importFileReadFailed.zh)

                    is AndroidTransferDocumentAdapter.ReadResult.Success ->
                        if (result.text.isEmpty()) {
                            // 空内容：Dart 明确落到「无法读取所选文件」（`:419-421`）。
                            showToast(TransferStrings.importFileReadFailed.zh)
                        } else {
                            openImportPreview(result.text, TransferChannel.FILE)
                        }
                }
            }
        }
    }

    // 扫码页收齐字节后回填到这里：与文件导入走同一条链路。
    LaunchedEffect(bridge.inboundBytes) {
        val bytes = bridge.inboundBytes ?: return@LaunchedEffect
        bridge.inboundBytes = null
        isImporting = true
        val text = withContext(Dispatchers.IO) { runCatching { String(bytes, Charsets.UTF_8) }.getOrNull() }
        isImporting = false
        if (text == null) {
            // Dart：UTF-8 解码失败统一落到「导入失败，请确认文件有效」（`:551-563`）。
            showToast(TransferStrings.importFailedInvalidFile.zh)
        } else {
            openImportPreview(text, TransferChannel.QR)
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        DataTransferPage(
            viewState = buildViewState(snapshot, isExporting, isImporting),
            onBack = onBack,
            onExportCurrent = { runExport(TransferScope.CURRENT_TIMETABLE) },
            onExportAllData = { runExport(TransferScope.ALL_DATA) },
            onExportTimeTemplate = { runExport(TransferScope.TIME_TEMPLATE) },
            onOpenIcsExport = { onOpenPage("g3.icsExport") },
            onChooseFileAndImport = {
                if (!isImporting) {
                    importLauncher.launch(TransferShareContract.OPEN_MIME_TYPES.toTypedArray())
                }
            },
            onQrSend = { scope, courseIds ->
                runQrSend(scope, courseIds, TransferStrings.qrTransferSendCurrent.zh)
            },
            onQrSendAll = {
                runQrSend(TransferScope.ALL_DATA, emptySet(), TransferStrings.qrTransferSendAll.zh)
            },
            onQrScan = { if (!isImporting) onRequestQrScan() },
        )

        // 预览弹窗（Dart `showTransferPreviewDialog`）：选完模式才落盘。
        TransferPreviewDialog(
            content = previewContent,
            onChoose = { mode ->
                val pending = pendingImport
                previewContent = null
                pendingImport = null
                if (pending != null && mode != null) {
                    val rejection = DataTransferApplyLogic.rejectionCode(pending.plan, mode)
                    if (rejection != null) {
                        showToast(TransferServiceMessages.localize(rejection))
                    } else {
                        isImporting = true
                        coroutineScope.launch {
                            val outcome = withContext(Dispatchers.IO) { applyImport(repository, pending, mode) }
                            isImporting = false
                            when (outcome) {
                                is ApplyOutcome.Failed ->
                                    showToast(TransferServiceMessages.localize(outcome.code))

                                is ApplyOutcome.Applied -> {
                                    val after = repository.snapshot
                                    val sectionCount = sectionCountOf(after)
                                    val notice = DataTransferLogic.restoredNotice(
                                        beyondSchemeCount = DataTransferApplyLogic.coursesBeyondScheme(
                                            courses = after.courses,
                                            sectionCount = sectionCount,
                                        ),
                                        sectionCount = sectionCount,
                                        // 跳过条目恒 0：Kotlin 解析层「坏一条就整份拒收」，
                                        // 没有 Dart 那条「部分损坏仍导入」的通道（`lastImportDroppedTotal`）。
                                        droppedCount = 0,
                                    )
                                    undoToken = outcome.token
                                    if (outcome.token == null) {
                                        showToast(notice.message)
                                    } else {
                                        showToast(
                                            message = notice.message,
                                            actionLabel = TransferStrings.themeUndo.zh,
                                            onAction = {
                                                val token = undoToken
                                                if (token != null) {
                                                    undoToken = null
                                                    coroutineScope.launch {
                                                        val ok = withContext(Dispatchers.IO) {
                                                            undoImport(repository, token)
                                                        }
                                                        showToast(
                                                            if (ok) {
                                                                TransferStrings.dataTransferUndoSuccess.zh
                                                            } else {
                                                                TransferStrings.dataTransferUndoFailed.zh
                                                            },
                                                        )
                                                    }
                                                }
                                            },
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            },
        )

        // 提示胶囊：底部居中、2 秒自动消失（Dart `HyperosMiuixSnackbar.durationShortMs = 2000`）。
        TransferToastCapsule(
            state = toastState,
            dark = dark,
            onDismiss = { toastState = null },
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(horizontal = 16.dp, vertical = 32.dp),
        )
    }
}

/** 一次待落盘的导入（预览弹窗确认后消费）。 */
private data class PendingImport(
    val info: TransferImportPackageInfo,
    val plan: TransferImportPlan,
)

/** 落盘结果。 */
private sealed interface ApplyOutcome {
    data class Applied(val token: TransferUndoToken?) : ApplyOutcome
    data class Failed(val code: String) : ApplyOutcome
}

/** 二维码载荷预检结果。 */
private sealed interface QrPayloadResult {
    data class Ready(val bytes: ByteArray, val title: String) : QrPayloadResult
    data object OverLimit : QrPayloadResult
    data class Failure(val code: String) : QrPayloadResult
}

private fun exportRequest(scope: TransferScope): TransferPackageRequest =
    TransferPackageRequest(
        scope = scope,
        channel = TransferChannel.FILE,
        packageId = TransferEnvelope.newPackageId(),
        now = LocalDateTime.now(),
    )

private fun prepareQrPayload(
    snapshot: TimetableSnapshot,
    scope: TransferScope,
    selectedCourseIds: Set<String>,
    title: String,
): QrPayloadResult = when (
    val built = DataTransferPackageLogic.build(
        snapshot = snapshot,
        request = TransferPackageRequest(
            scope = scope,
            channel = TransferChannel.QR,
            packageId = TransferEnvelope.newPackageId(),
            now = LocalDateTime.now(),
            selectedCourseIds = selectedCourseIds,
        ),
    )
) {
    is TransferPackageResult.Failure -> QrPayloadResult.Failure(built.code)
    is TransferPackageResult.Success -> {
        val bytes = built.json.toByteArray(Charsets.UTF_8)
        // Dart `QrTransferEncoder.preflight`：超资源上限直接提示、不打开送页。
        val session = QrTransferSendSession.prepare(bytes)
        if (session.overResourceLimit) QrPayloadResult.OverLimit else QrPayloadResult.Ready(bytes, title)
    }
}

/**
 * 真正写盘（Dart `applyToProvider`）。
 *
 * 写入范围**逐条对应**撤销快照抓的范围，撤销才可能完整：
 * - 全量包（覆盖）→ `replaceAllProfiles`；
 * - 单课表包（覆盖 / 合并）→ `replaceActiveProfileContent` + 设置 + 当前周。
 *
 * `tasks` / `exams` 一律**不写回**（保留当前档案里的）：这是台账 §9.4 ③ 的已知缺口，
 * 与 `LanEditRepositoryHost.importProfileBackupJson` 的口径一致（审核文档 §六·5）。
 */
private fun applyImport(
    repository: TimetableRepository,
    pending: PendingImport,
    mode: TransferApplyMode,
): ApplyOutcome {
    val plan = pending.plan
    val before = repository.snapshot
    val undoSnapshot = when (DataTransferApplyLogic.undoKindFor(plan)) {
        TransferUndoScope.FULL_PROFILES -> TransferUndoSnapshot(
            kind = TransferUndoScope.FULL_PROFILES,
            profiles = before.profiles,
            activeProfileId = before.activeProfileId,
        )

        TransferUndoScope.ACTIVE_PROFILE_CONTENT -> TransferUndoSnapshot(
            kind = TransferUndoScope.ACTIVE_PROFILE_CONTENT,
            courses = before.courses,
            tasks = repository.tasks,
            exams = repository.exams,
            settings = before.settings,
            currentWeek = before.currentWeek,
        )
    }
    return runCatching {
        if (DataTransferApplyLogic.isFullBackupPlan(plan)) {
            repository.replaceAllProfiles(plan.profiles, plan.activeProfileId)
        } else {
            val courses = if (mode == TransferApplyMode.MERGE) {
                DataTransferApplyLogic.mergeCourses(before.courses, plan.courses)
            } else {
                plan.courses
            }
            repository.replaceActiveProfileContent(
                courses = courses,
                tasks = repository.tasks,
                exams = repository.exams,
            )
            plan.settings?.let(repository::updateSettings)
            plan.currentWeek?.let(repository::setCurrentWeek)
        }
        ApplyOutcome.Applied(
            token = TransferUndoToken(
                id = TransferEnvelope.newPackageId(),
                snapshot = undoSnapshot,
                createdAt = LocalDateTime.now(),
            ),
        )
    }.getOrElse { error ->
        // Dart：应用失败且无具体原因 → 「导入失败，请确认文件有效」。
        ApplyOutcome.Failed(code = error.message ?: "import_failed_invalid_file")
    }
}

/** 撤销一份导入：按快照种类整份写回（Dart `undoToken`）。 */
private fun undoImport(repository: TimetableRepository, token: TransferUndoToken): Boolean =
    runCatching {
        val snapshot = token.snapshot
        when (snapshot.kind) {
            TransferUndoScope.FULL_PROFILES ->
                repository.replaceAllProfiles(snapshot.profiles, snapshot.activeProfileId)

            TransferUndoScope.ACTIVE_PROFILE_CONTENT -> {
                repository.replaceActiveProfileContent(
                    courses = snapshot.courses,
                    tasks = snapshot.tasks,
                    exams = snapshot.exams,
                )
                snapshot.settings?.let(repository::updateSettings)
                repository.setCurrentWeek(snapshot.currentWeek)
            }
        }
    }.isSuccess

/** 当前作息的有效节数（`TimetableSettings` 没有 `sectionCount`，取活动模板，再回落设置里的节次表）。 */
private fun sectionCountOf(snapshot: TimetableSnapshot): Int {
    val scheme = TimetableHostLogic.resolveActiveTimeScheme(
        schemes = snapshot.timeSchemes,
        activeTimeSchemeId = snapshot.activeTimeSchemeId,
    )
    return scheme?.sections?.size ?: snapshot.settings.sections.size
}

/** 页面视图状态（概览 / 两个忙碌位 / 选课弹层的科目组）。 */
private fun buildViewState(
    snapshot: TimetableSnapshot,
    isExporting: Boolean,
    isImporting: Boolean,
): DataTransferViewState {
    val activeProfile = snapshot.profiles.firstOrNull { it.id == snapshot.activeProfileId }
        ?: snapshot.profiles.firstOrNull()
    return DataTransferViewState(
        overview = TransferOverviewInput(
            courseCount = snapshot.courses.size,
            activeProfileName = activeProfile?.name,
            profileCount = snapshot.profiles.size,
            // 旧版壳把这里写死成 1：页面上「时间模板：1 套」与实际无关，导出按钮也因此永远可点。
            timeSchemeCount = snapshot.timeSchemes.size,
            currentWeek = snapshot.currentWeek,
            semesterStartDate = snapshot.settings.semesterStartDate?.toLocalDate(),
        ),
        timeSchemeCount = snapshot.timeSchemes.size,
        isExporting = isExporting,
        isImporting = isImporting,
        activeProfileName = activeProfile?.name,
        courseGroups = DataTransferLogic.courseGroups(snapshot.courses),
    )
}

/**
 * 跨路由暂存（壳里 `remember { TransferShellBridge() }`，挂在 `when (pageId)` 之上）。
 *
 * 为什么需要：二维码的「发送页」与「扫码页」是两个独立路由，而发送载荷只有本页算得出来
 * （要读仓储）。壳原先拿 `"QingyuTimetable:<课表名>"` 当载荷，就是这一步没接的后果。
 */
class TransferShellBridge {
    /** 待发送的传输包字节（`g3.qrSend` 读它建会话）。 */
    var outboundPayload by mutableStateOf<ByteArray?>(null)

    /** 发送页标题（Dart 按 scope 取「二维码发送当前课表」/「二维码发送全部数据」）。 */
    var outboundTitle by mutableStateOf<String?>(null)

    /** 扫码收齐的字节（`g3.qrScan` 写它，回本页后消费）。 */
    var inboundBytes by mutableStateOf<ByteArray?>(null)
}

/** 一条提示（带可选动作）。 */
private data class TransferToastState(
    val message: String,
    val actionLabel: String? = null,
    val onAction: (() -> Unit)? = null,
)

/**
 * 提示胶囊（Dart `HyperosToastCapsule`）：底部浮层、圆角 16、2 秒自动消失、动作在右侧。
 *
 * 用 Compose 浮层而不是 `android.widget.Toast`：系统 Toast 挂不了动作按钮，
 * 而 Dart 的「撤销」正挂在提示尾部；且 Dart 那个提示本来就是自绘胶囊，不是系统 Toast。
 */
@Composable
private fun TransferToastCapsule(
    state: TransferToastState?,
    dark: Boolean,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
) {
    if (state == null) return
    LaunchedEffect(state) {
        delay(TOAST_DURATION_MILLIS)
        onDismiss()
    }
    QingyuCard(
        modifier = modifier.fillMaxWidth(),
        cornerRadius = 16.dp,
        insideMargin = PaddingValues(start = 16.dp, top = 12.dp, end = 12.dp, bottom = 12.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = state.message,
                style = MiuixTheme.textStyles.body2,
                color = Color(QingyuTheme.primaryText(dark)),
                modifier = Modifier.weight(1f),
            )
            if (state.actionLabel != null) {
                TextButton(
                    text = state.actionLabel,
                    onClick = {
                        onDismiss()
                        state.onAction?.invoke()
                    },
                )
            }
        }
    }
}

/** Dart `HyperosMiuixSnackbar.durationShortMs` = 2000（`app_toast.dart:6-8`）。 */
private const val TOAST_DURATION_MILLIS = 2000L
