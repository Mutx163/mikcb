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
import com.mutx163.qingyu.app.AppGlobalSettingsStore
import com.mutx163.qingyu.app.TimetableHostLogic
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableSnapshot
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.pages.ShellExternalEntryHub
import com.mutx163.qingyu.pages.shell.ShellExternalEntry
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
import java.util.UUID

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

    /** 导入一份包文本（文件 / 二维码 / 外部打开三条入口共用）。 */
    fun openImportPreview(
        text: String,
        channel: TransferChannel,
        entry: ImportEntry = ImportEntry.FILE_PICK,
    ) {
        // 2026-11-03：旧格式（无信封的单课表备份 / backupType=full 的全量备份）走
        // 兼容解析；信封坏了一律整份拒收，不回退（Dart `parseCompatible`）。
        when (val parsed = DataTransferLegacyBackupLogic.parseCompatible(text, channel)) {
            is TransferImportParseResult.Invalid ->
                showToast(TransferServiceMessages.localize(parsed.code))

            is TransferImportParseResult.Valid -> {
                // 差异基线 = **仓储真内容**（活动档案的课程/作业/考试/日程/设置/当前周），
                // 不是「按 CURRENT_TIMETABLE 现打一份包再比文本」：后者对全量包会把档案内
                // 实体全判新增、本机顶层实体全判删除（见 DataTransferDiffLogic 类注释）。
                val diffCurrent = TransferDiffCurrent.ofSnapshot(
                    snapshot = snapshot,
                    tasks = repository.tasks,
                    exams = repository.exams,
                )
                // 正文的「合并」段必须和**按钮**同口径（2026-11-06 返工）：
                // - 全量包不支持合并（见 DataTransferApplyLogic.rejectionCode）；
                // - 「外部打开备份」这条入口发布版只有 取消/覆盖/导入为新，**没有合并**，
                //   正文也就不许出现 `merge:` 段（发布版那条弹框正文只有一句 selectImportModeMessage）。
                // 旧实现只看全量包、不看 entry，于是外部打开会出现「按钮没合并、正文却有合并」。
                val canMerge = entry != ImportEntry.EXTERNAL_OPEN &&
                    !DataTransferApplyLogic.isFullBackupPlan(parsed.plan)
                val overwrite = DataTransferDiffLogic
                    .compare(diffCurrent, parsed.plan, parsed.info.scope, TransferApplyMode.OVERWRITE)
                    .toSummaries()
                // 合并那一份**单独算**（Dart `data_transfer_screen.dart:599-605` 两次 preview）：
                // 合并不报删除、覆盖只在非合并语义的 scope 上报删除，不是「把删除清零」。
                val merge = if (canMerge) {
                    DataTransferDiffLogic
                        .compare(diffCurrent, parsed.plan, parsed.info.scope, TransferApplyMode.MERGE)
                        .toSummaries()
                } else {
                    null
                }
                pendingImport = PendingImport(info = parsed.info, plan = parsed.plan, entry = entry)
                previewContent = TransferPreviewContent(
                    title = TransferStrings.selectImportModeTitle.text,
                    message = if (entry == ImportEntry.EXTERNAL_OPEN) {
                        // 发布版「外部打开备份」那条弹框（`_runBackupImportFlow`）正文**只有一句**
                        // `selectImportModeMessage`；channel/scope/transferId/差异摘要都是
                        // 文件选择那套预览弹框（`transfer_preview_dialog.dart`）的正文，这里不带
                        //（2026-11-06 三轮返工：正文与按钮同口径）。
                        TransferStrings.selectImportModeMessage.text
                    } else {
                        DataTransferImportLogic.previewMessage(
                            channel = channel,
                            scope = parsed.info.scope,
                            packageId = parsed.info.packageId,
                            overwrite = overwrite,
                            merge = merge,
                        )
                    },
                )
            }
        }
    }

    fun runExport(scope: TransferScope) {
        if (isExporting) return
        isExporting = true
        coroutineScope.launch {
            val failure = withContext(Dispatchers.IO) {
                when (
                    val built = DataTransferPackageLogic.build(
                        snapshot = snapshot,
                        request = exportRequest(scope),
                        // 盘上完整 settings（含 Dart 侧 250+ 键）：不传就只剩 core 6 键。
                        settingsJson = repository.readRawSettings(),
                        // 全量包的每份档案也要带自己的完整内嵌设置。
                        profileSettingsById = repository.embeddedSettingsById(),
                    )
                ) {
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
            val result = withContext(Dispatchers.IO) {
                prepareQrPayload(repository, snapshot, scope, selectedCourseIds, title)
            }
            isExporting = false
            when (result) {
                is QrPayloadResult.Failure -> showSendFailure(result.code)
                is QrPayloadResult.OverLimit -> showToast(TransferStrings.qrTransferResourceLimit.text)
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

                    is AndroidTransferDocumentAdapter.ReadResult.ReadFailed,
                    is AndroidTransferDocumentAdapter.ReadResult.EmptyContent -> showToast(
                        TransferStrings.importFileReadFailed.text,
                    )

                    is AndroidTransferDocumentAdapter.ReadResult.InvalidEncoding ->
                        // 畸形 UTF-8：复用「导入失败，请确认文件有效」（Lead 裁决，不新增键）。
                        showToast(TransferStrings.importFailedInvalidFile.text)

                    is AndroidTransferDocumentAdapter.ReadResult.Success ->
                        // 显式传 FILE_PICK：这条入口与「外部打开备份」共用同一个弹窗，
                        // 只有后者开放「导入为新课表」；显式写出来守卫才咬得住（默认值容易被顺手改掉）。
                        openImportPreview(result.text, TransferChannel.FILE, ImportEntry.FILE_PICK)
                }
            }
        }
    }

    // 扫码页收齐字节后回填到这里：与文件导入走同一条链路。
    LaunchedEffect(bridge.inboundBytes) {
        val bytes = bridge.inboundBytes ?: return@LaunchedEffect
        bridge.inboundBytes = null
        isImporting = true
        // 严格 UTF-8：畸形字节不落成 U+FFFD 文本，直接走下面的「导入失败」分支。
        val text = withContext(Dispatchers.IO) { DataTransferInboundDecoding.decodeTransferText(bytes) }
        isImporting = false
        if (text == null) {
            // Dart：UTF-8 解码失败统一落到「导入失败，请确认文件有效」（`:551-563`）。
            showToast(TransferStrings.importFailedInvalidFile.text)
        } else {
            openImportPreview(text, TransferChannel.QR)
        }
    }

    // 外部打开 .mikcb / .json 备份（R1 补口 2026-11-02 的最后一步）：透明跳板把 payload
    // 备进 `ShellExternalEntryHub`、壳把页面推到本页后，这里把备份文本接进与「选择文件
    // 导入」同一条预览链路——外部打开的本来就是一份文件，通道按 FILE 口径。kind 不符时
    // （ics / spreadsheet / 超限各有自己的落点页）`consumeImport` 不消费，各页面互不抢。
    LaunchedEffect(ShellExternalEntryHub.pendingImport) {
        val payload = ShellExternalEntryHub.consumeImport("backup") ?: return@LaunchedEffect
        if (payload is ShellExternalEntry.ImportPayload.Backup) {
            // 外部打开备份 = 发布版唯一会出现「导入为新课表」那条动作的入口
            // （工作区 `lib/main.dart:1669` / 发布版 v2.1.4.1 `:1569`；弹框本体
            // 工作区 `:1490-1522` / 发布版 `:1401-1422`）。文件选择 / 二维码 / 局域网保持三条。
            openImportPreview(payload.text, TransferChannel.FILE, ImportEntry.EXTERNAL_OPEN)
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
                runQrSend(scope, courseIds, TransferStrings.qrTransferSendCurrent.text)
            },
            onQrSendAll = {
                runQrSend(TransferScope.ALL_DATA, emptySet(), TransferStrings.qrTransferSendAll.text)
            },
            onQrScan = { if (!isImporting) onRequestQrScan() },
        )

        // 预览弹窗（Dart `showTransferPreviewDialog`）：选完动作才落盘。
        TransferPreviewDialog(
            content = previewContent,
            // 合并的两条限制：
            // 1. 全量包不支持合并（见 DataTransferApplyLogic.rejectionCode），不摆点了必然失败的按钮；
            // 2. 「外部打开备份」这条入口发布版只有**三**个动作（取消/覆盖/导入为新，
            //    `_runBackupImportFlow` 的弹框没有「合并」）——「合并」属于文件选择那套弹框。
            canMerge = pendingImport?.let {
                it.entry != ImportEntry.EXTERNAL_OPEN && !DataTransferApplyLogic.isFullBackupPlan(it.plan)
            } ?: true,
            // 「导入为新课表」只在「外部打开备份文件」这条入口出现——发布版里有它的
            // 三动作弹框只挂在 `_runBackupImportFlow`（`main.dart:1490-1522`（工作区；发布版 `:1401-1422`）），而
            // 文件选择 / 二维码 / 局域网用的预览弹框本来就没有这条。全量备份不显示
            // （Dart 会挑一条拒；我们沿用「死按钮先隐藏」的同一总口径）。
            canImportAsNew = pendingImport?.let {
                it.entry == ImportEntry.EXTERNAL_OPEN && !DataTransferApplyLogic.isFullBackupPlan(it.plan)
            } ?: false,
            onChoose = { action ->
                val pending = pendingImport
                val mode = action?.mode
                previewContent = null
                pendingImport = null
                // action == null = 取消；非 as-new 却没有 mode 属异常，一律当取消处理。
                if (pending != null && action != null && (action.importAsNew || mode != null)) {
                    val rejection = if (action.importAsNew) {
                        DataTransferApplyLogic.importAsNewRejectionCode(pending.plan)
                    } else {
                        // 上面的守卫保证非 as-new 时 mode 非空。
                        DataTransferApplyLogic.rejectionCode(pending.plan, mode!!)
                    }
                    if (rejection != null) {
                        showToast(TransferServiceMessages.localize(rejection))
                    } else {
                        isImporting = true
                        coroutineScope.launch {
                            val outcome = withContext(Dispatchers.IO) {
                                if (action.importAsNew) {
                                    applyImportAsNew(repository, pending)
                                } else {
                                    applyImport(repository, pending, mode!!)
                                }
                            }
                            isImporting = false
                            when (outcome) {
                                is ApplyOutcome.Failed ->
                                    showToast(TransferServiceMessages.localize(outcome.code))

                                is ApplyOutcome.Applied -> {
                                    val notice = if (action.importAsNew) {
                                        // 发布版 as-new 的成功句是「已创建新的课表」+「坏条目已跳过」，
                                        // 不算「超出作息范围」那一段（`main.dart:1584-1593`（工作区））。
                                        DataTransferLogic.createdNotice(droppedCount = pending.info.droppedTotal)
                                    } else {
                                        val after = repository.snapshot
                                        val sectionCount = sectionCountOf(after)
                                        DataTransferLogic.restoredNotice(
                                            beyondSchemeCount = DataTransferApplyLogic.coursesBeyondScheme(
                                                courses = after.courses,
                                                sectionCount = sectionCount,
                                            ),
                                            sectionCount = sectionCount,
                                            // 旧格式文件逐条跳过的坏条目数（Dart
                                            // `lastImportDroppedCounts`）；当前信封恒 0。
                                            droppedCount = pending.info.droppedTotal,
                                        )
                                    }
                                    undoToken = outcome.token
                                    if (outcome.token == null) {
                                        showToast(notice.message)
                                    } else {
                                        showToast(
                                            message = notice.message,
                                            actionLabel = TransferStrings.themeUndo.text,
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
                                                                TransferStrings.dataTransferUndoSuccess.text
                                                            } else {
                                                                TransferStrings.dataTransferUndoFailed.text
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

/**
 * 这次导入是从哪个入口进来的。
 *
 * 只用来决定预览弹窗**摆几条动作**：发布版里「导入为新课表」只挂在
 * 「外部打开一份备份文件」这条链路上（`main.dart:1490-1522`（工作区；发布版 `:1401-1422`）），文件选择 / 二维码 /
 * 局域网都保持 取消·合并·覆盖。别的行为一律不加入口差异。
 */
private enum class ImportEntry { FILE_PICK, EXTERNAL_OPEN }

/** 一次待落盘的导入（预览弹窗确认后消费）。 */
private data class PendingImport(
    val info: TransferImportPackageInfo,
    val plan: TransferImportPlan,
    val entry: ImportEntry,
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
    repository: TimetableRepository,
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
        settingsJson = repository.readRawSettings(),
        profileSettingsById = repository.embeddedSettingsById(),
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
 * - 单课表包（覆盖 / 合并）→ `replaceActiveProfileContent` + 设置 + 当前周；
 * - `time_template` 包 → 只补时间模板，内容块整块跳过
 *   （[DataTransferApplyLogic.TransferApplyWrites.writesActiveProfileContent]）。
 *
 * 「覆盖」不等于「整份替换」：4 个局部 scope（`selected_courses` / `selected_course` /
 * `week_timetable` / `time_template`）在 Dart 里只更新包边界内的实体，边界外保留
 * （`unified_transfer_service.dart:666-676`），判据集中在
 * [DataTransferApplyLogic.planWrites]，宿主不再自己判断。
 */
private fun applyImport(
    repository: TimetableRepository,
    pending: PendingImport,
    mode: TransferApplyMode,
): ApplyOutcome {
    val plan = pending.plan
    val scope = pending.info.scope
    val before = repository.snapshot
    // 2026-11-03：落盘前补齐 Dart `validate` 的引用门（课/作息表指向必须存在）。
    // 旧实现只做结构校验就写；包内一条考试指向不存在的课会被静默写进档案，
    // Dart 则整份拒收（`exam_course_missing:<id>`）——这里返回同一族错误码。
    val referenceErrors = DataTransferApplyLogic.referenceErrors(
        plan = plan,
        baseline = DataTransferApplyLogic.TransferReferenceBaseline(
            courseIds = buildSet {
                before.courses.mapTo(this) { it.id }
                before.profiles.forEach { profile -> profile.courses.mapTo(this) { it.id } }
            },
            timeSchemeIds = before.timeSchemes.mapTo(HashSet()) { it.id },
        ),
    )
    if (referenceErrors.isNotEmpty()) {
        return ApplyOutcome.Failed(code = referenceErrors.first())
    }
    // 「改多少、还原多少」必须对称（2026-11-06 三轮返工）：本函数末尾会
    // `updateLocationTimeGroups(..., resync = true)`（或 all_data 整设备覆盖），
    // 那会把**所有档案**的课程钟点按新分组重排；回滚若只还原活动档，其它档就停在新钟点上。
    // 所以凡是会触发 resync 的路径，快照必须按整份档案表抓。
    // 这里用「不含 schemeIdMap」的 planWrites 只为判 `locationTimeGroups` 是否为空/是否 all_data
    // ——引用改写不影响这两个判据，故不必等 reconcile 完再算。
    val willResyncAllProfiles = DataTransferApplyLogic.planWrites(
        plan = plan,
        mode = mode,
        current = DataTransferApplyLogic.TransferCurrentContent(
            courses = before.courses,
            tasks = repository.tasks,
            exams = repository.exams,
            scheduleItems = before.scheduleItems,
            locationTimeGroups = before.locationTimeGroups,
        ),
        scope = scope,
    ).let { it.locationTimeGroups.isNotEmpty() || scope == TransferScope.ALL_DATA }
    val undoSnapshot = when (
        DataTransferApplyLogic.undoKindFor(plan, rewritesAllProfiles = willResyncAllProfiles)
    ) {
        TransferUndoScope.FULL_PROFILES -> TransferUndoSnapshot(
            kind = TransferUndoScope.FULL_PROFILES,
            profiles = before.profiles,
            activeProfileId = before.activeProfileId,
            settings = before.settings,
            currentWeek = before.currentWeek,
            scheduleDateRules = before.scheduleDateRules,
            locationTimeGroups = before.locationTimeGroups,
            // 全量恢复会整份重写档案，撤销要把每份档案的完整内嵌设置一起还原。
            profileSettingsById = repository.embeddedSettingsById(),
            // 全量恢复还会把备份里的整机偏好写回全局真源，撤销也必须还原它。
            globalSettingsJson = AppGlobalSettingsStore.globalKeysOnly(repository.readRawSettings()),
            // 模板表在第一次改动（`reconcileTimeSchemes`）之前抓：导入会新建模板，
            // 不整份还原就会在本机留下多出来的一套、且救不回来（仓储无跨 key 事务）。
            timeSchemes = before.timeSchemes,
        )

        TransferUndoScope.ACTIVE_PROFILE_CONTENT -> TransferUndoSnapshot(
            kind = TransferUndoScope.ACTIVE_PROFILE_CONTENT,
            courses = before.courses,
            tasks = repository.tasks,
            exams = repository.exams,
            scheduleItems = before.scheduleItems,
            settings = before.settings,
            currentWeek = before.currentWeek,
            scheduleDateRules = before.scheduleDateRules,
            locationTimeGroups = before.locationTimeGroups,
            // 单课表导入也写完整设置，撤销要能把它回到原文。
            settingsJson = repository.activeProfileSettingsJson(),
            timeSchemes = before.timeSchemes,
        )
    }
    // 2026-11-01 修（P1）：失败必须回滚。旧版整段 runCatching 却不还原，任何一步抛错
    // 都会留下「课表已经换了、作业/日程还停在旧值」的半替换现场。回滚复用撤销那份快照
    // 与 [restoreFromSnapshot]（同一判据，不另写一套）；撤销 token 只在成功后生成。
    val applied = runCatching {
        // ① 先补时间模板表：包里带了模板而本机没有（跨设备导入的常态）时，
        //    这里新建并拿到「包 id → 本机 id」映射，下面的写入按映射改写引用。
        val schemeIdMap = reconcileTimeSchemes(repository, plan.timeSchemes)
        // ② 「要写哪几块」全部由模型层一次算好（2026-10-29 二轮修复：旧版在这里
        //    手写写入范围，漏了作业 / 考试 / 日程条目 / 时间模板 / 日程规则）。
        val writes = DataTransferApplyLogic.planWrites(
            plan = plan,
            mode = mode,
            current = DataTransferApplyLogic.TransferCurrentContent(
                courses = before.courses,
                tasks = repository.tasks,
                exams = repository.exams,
                scheduleItems = before.scheduleItems,
                locationTimeGroups = before.locationTimeGroups,
            ),
            // scope 决定「覆盖」的边界：局部 scope 只更新包内实体（Dart 同判据），
            // time_template 连内容块都不碰——写作用域与 [writes] 一一对应。
            scope = scope,
            schemeIdMap = schemeIdMap,
        )
        if (writes.isFullBackup) {
            // 全量包的每份档案都要带自己的完整 settings（模型只带 core 键，
            // 不铺这份原文，恢复后外观/语言等偏好全部回默认）。
            repository.replaceAllProfiles(
                profiles = writes.profiles,
                activeProfileId = writes.activeProfileId,
                preferredEmbeddedSettings = writes.profileSettingsById,
            )
            // 全量包里的全局设置：优先写完整原文（按键合并），否则从刚恢复的活动档案
            // 内嵌设置里取 44 个整机级键，显式写回设备级真源。
            // 不写这一步，本机原有的全局值会在读侧把内嵌值整组盖掉——同机恢复 / 换机
            // 恢复后外观、语言、材质仍是本机的，备份里的那份永远读不到。
            if (writes.settingsJson != null) {
                repository.updateSettingsPatch(writes.settingsJson)
            } else {
                val restoredGlobals = AppGlobalSettingsStore.globalKeysOnly(
                    repository.activeProfileSettingsJson().orEmpty(),
                )
                if (restoredGlobals.isNotEmpty() &&
                    !repository.writeRawSettingsPatch(restoredGlobals)
                ) {
                    error("restore_global_settings_failed")
                }
                writes.settings?.let(repository::updateSettings)
            }
            // 全量包也要还原当前周（见 planWrites 全量分支：顶层没有时取档案自己那份）。
            writes.currentWeek?.let(repository::setCurrentWeek)
        } else if (writes.writesActiveProfileContent) {
            repository.replaceActiveProfileContent(
                courses = writes.courses,
                tasks = writes.tasks,
                exams = writes.exams,
            )
            // 日程条目：计划里算好的就是「本机最终应该是什么」。覆盖模式下包内为空
            // 就该清空——校验层要求八张列表键必须在场，所以「空数组」= 包里真的是空，
            // 不是「没带该键」；合并模式下 planWrites 已保留本机独有的条目。
            // 2026-11-01 修（P2）：旧版 isNotEmpty() 守卫让覆盖时空包清不掉本机日程。
            repository.scheduleItems = writes.scheduleItems
            // 设置：有完整原文就按键合并写（不丢包里的 250+ 键，也不删本机独有键）；
            // 只有旧包（无完整原文）时才回落到 core 投影。
            // 整机级键一律剔除：本修复之前导出的旧包里仍带着对方的主题/语言/材质，
            // 直接写进全局真源会改掉本机偏好且撤销回不来。
            val settingsPatch = writes.settingsJson?.let(AppGlobalSettingsStore::stripGlobalKeys)
            if (settingsPatch != null) {
                repository.updateSettingsPatch(settingsPatch)
            } else {
                writes.settings?.let(repository::updateSettings)
            }
            writes.currentWeek?.let(repository::setCurrentWeek)
            // 日程条目 / 设置 / 当前周一次落盘（上面的 setter 只改内存）。
            repository.persistActiveProfileState()
        }
        // ③ 日程规则 / 地点分组：Dart `_replaceRulesAndLocations` 的口径是
        //    「非空 ⇒ 替换」，外加 `scope == all_data` 时**空也替换**（整设备覆盖）。
        //    其他 scope 下包内为空表示「这一块没带」，保持本机不动。
        val overwriteAllData = scope == TransferScope.ALL_DATA
        if (writes.scheduleDateRules.isNotEmpty() || overwriteAllData) {
            repository.updateScheduleDateRules(writes.scheduleDateRules)
        }
        if (writes.locationTimeGroups.isNotEmpty() || overwriteAllData) {
            // `resync = true`：本函数的顺序是「② 先写课 → ③ 后换分组」，不重算就会留下
            // 「分组是包里的、课程钟点还是按本机旧分组算的」。Dart 侧
            // `_replaceRulesAndLocations` 之后走 `replaceLocationTimeGroups(resync: true)`
            // （默认即 true，`timetable_location_rule_service.dart:265-279`），
            // 仓储 `updateLocationTimeGroupsLocked` 的 KDoc 也点名「传输层必须用它」。
            repository.updateLocationTimeGroups(writes.locationTimeGroups, resync = true)
        }
    }
    return applied.fold(
        onSuccess = {
            ApplyOutcome.Applied(
                token = TransferUndoToken(
                    id = TransferEnvelope.newPackageId(),
                    snapshot = undoSnapshot,
                    createdAt = LocalDateTime.now(),
                ),
            )
        },
        onFailure = { error ->
            // Dart：应用失败且无具体原因 → 「导入失败，请确认文件有效」。
            // 回滚**不许吞掉结果**：快照还原也可能是半份（仓储无跨 key 事务），
            // 还原失败必须报发布版那条用户可见码 `import_rollback_incomplete`，
            // 别让用户以为「什么都没发生」。
            val restored = restoreFromSnapshot(repository, undoSnapshot)
            ApplyOutcome.Failed(
                code = when {
                    !restored -> "import_rollback_incomplete"
                    else -> error.message ?: "import_failed_invalid_file"
                },
            )
        },
    )
}

/**
 * 落盘「导入为新课表」（Dart `importAppDataBackupAsNewProfile`，发布版 v2.1.4.1
 * `lib/providers/timetable/import_export_service.dart:550-638`；工作区对应实现
 * `lib/services/timetable_import_export_service.dart:754-849`）。
 *
 * 与 [applyImport] 的区别：**不写当前档案一个字节**，只多出一份新档并切过去。
 * 顺序照发布版：补模板 → 设置对齐模板表 → 建新档 → 整份档案表落盘 → 铺本机全局偏好。
 * 撤销快照抓 `FULL_PROFILES`（多一份档 + 换激活 id + 换全局设置/周次），撤销即整份还原。
 *
 * ## 设备信任锚（刻意与发布版不同，别「对齐」掉）
 *
 * 发布版这条路径**没有**剥掉设备信任锚（`keepingDeviceTrustAnchorsFrom` 只在覆盖路径用），
 * 也就是说包里的更新通道会跟着进来；**本版主动保留本机信任锚**——`appUpdateMirrorPreset` /
 * `appUpdateMirrorUrlPrefix` 住在整机级 `AppGlobalSettingsStore`（44 键真源），
 * 不从包内取值，也不写回。这是安全加固，不是漏迁。
 */
private fun applyImportAsNew(
    repository: TimetableRepository,
    pending: PendingImport,
): ApplyOutcome {
    val plan = pending.plan
    val before = repository.snapshot
    // 落盘前把「本机全局偏好」（外观 / 语言 / 更新通道…）抓下来：切档后活动档变成新档，
    // 而本仓传输包只携带 core 设置子集（`DataTransferPackageLogic.kt:63-67`），
    // 不铺这一步新档的镜像里就缺这些键、备份出去/旧读侧会当它们没设过。
    // 键表用整机级真源的公开清单 `AppGlobalSettingsStore.KEYS`（44 键，Dart `app_global_settings_service.dart:59-114`），
    // 值取自 `readRawSettings()` 的叠加视图（内嵌 + 全局真源，见 `TimetableStore:593`）。
    // 新建 / 复制档走的是同一条口子（`TimetableProfilesController.seedActiveSettings`）。
    val globalPreferences = repository.readRawSettings()
        .filterKeys { key -> key in AppGlobalSettingsStore.KEYS }
    val undoSnapshot = TransferUndoSnapshot(
        kind = TransferUndoScope.FULL_PROFILES,
        profiles = before.profiles,
        activeProfileId = before.activeProfileId,
        settings = before.settings,
        currentWeek = before.currentWeek,
        // 「导入为新课表」不碰日程规则 / 地点分组：null = 撤销时也不碰。
        scheduleDateRules = null,
        locationTimeGroups = null,
        // 全量导入的撤销会把档案表整份写回，每份档案的完整内嵌设置也要一起还原。
        profileSettingsById = repository.embeddedSettingsById(),
        // 模板表在 `reconcileTimeSchemes` 之前抓：as-new 会新建「<名> 时间」等模板，
        // 撤销/回滚必须整份写回，否则本机永久多出模板且无法回收。
        timeSchemes = before.timeSchemes,
    )
    val applied = runCatching {
        val nextName = DataTransferApplyLogic.resolvedProfileName(pending.info.profileName)
        // ① 包里的时间模板补进本机表，拿到「包 id → 本机 id」映射。
        val schemeIdMap = reconcileTimeSchemes(repository, plan.timeSchemes)
        // ② 设置对齐本机模板表（本机有 → 复用；节次签名相同 → 复用；都没有 → 新建「<名> 时间」）。
        val baseSettings = plan.settings
            ?.let { DataTransferApplyLogic.remapSettingsScheme(it, schemeIdMap) }
            ?: TimetableSettings.defaults()
        val now = LocalDateTime.now()
        val resolution = DataTransferApplyLogic.resolveSettingsAgainstSchemes(
            settings = baseSettings,
            schemes = repository.snapshot.timeSchemes,
            // 模板名 `<课表名> 时间`（发布版硬编码 `'$nextName 时间'`）走文案系统，
            // 不许新增硬编码中文（`CjkLiteralGateTest`）。
            fallbackSchemeName = TransferStrings.transferImportedTimeSchemeName.filled("name", nextName),
            newSchemeId = UUID.randomUUID().toString(),
            now = now,
        )
        val settings = resolution.schemeToCreate?.let { toCreate ->
            val created = repository.createTimeScheme(toCreate.name, toCreate.sections)
            // 仓储建出来的 id 才是真 id：以它为准重建设置（与 Dart 同一处意图）。
            resolution.settings.copy(
                activeTimeSchemeId = created.id,
                sections = created.sections.toList(),
            )
        } ?: resolution.settings
        // ③ 建新档 → 整份档案表 + 激活 id + 全局设置 / 周次，一次写、一次通知。
        val newProfile = DataTransferApplyLogic.planImportAsNew(
            plan = plan,
            profileName = nextName,
            settings = settings,
            schemes = repository.snapshot.timeSchemes,
            newProfileId = UUID.randomUUID().toString(),
            now = now,
            schemeIdMap = schemeIdMap,
        )
        repository.replaceAllProfilesAndSettings(
            profiles = before.profiles + newProfile,
            activeProfileId = newProfile.id,
            settings = settings,
            currentWeek = newProfile.currentWeek.toInt(),
        )
        // ⑤ 包里带了完整 settings 时，把非 core 键也铺进新档（core 键以解析后的
        //    模板/节次为准）。不这一步，「导入为新课表」只落 6 键、其余偏好回默认。
        plan.settingsJson?.let { raw ->
            // 同上：旧包可能带对方的整机偏好，别铺进本机档案镜像。
            val merged = LinkedHashMap(AppGlobalSettingsStore.stripGlobalKeys(raw))
            merged.putAll(settings.toJson())
            repository.replaceActiveProfileSettingsJson(merged)
        }
        // ④ 把本机全局偏好铺到新档（失败按快照整份回滚，不留「多一份档、外观是默认值」）。
        if (globalPreferences.isNotEmpty() && !repository.writeRawSettingsPatch(globalPreferences)) {
            error("seed_profile_settings_failed")
        }
    }
    return applied.fold(
        onSuccess = {
            ApplyOutcome.Applied(
                token = TransferUndoToken(
                    id = TransferEnvelope.newPackageId(),
                    snapshot = undoSnapshot,
                    createdAt = LocalDateTime.now(),
                ),
            )
        },
        onFailure = { error ->
            // 回滚结果不许吞：as-new 一路已落过模板 / 档案表 / 全局偏好多次盘，
            // 还原失败必须报 `import_rollback_incomplete`（发布版有同一用户可见码）。
            val restored = restoreFromSnapshot(repository, undoSnapshot)
            ApplyOutcome.Failed(
                code = when {
                    !restored -> "import_rollback_incomplete"
                    else -> error.message ?: "import_failed_invalid_file"
                },
            )
        },
    )
}

/**
 * 把包里带的时间模板并进本机模板表，返回「包 id → 本机 id」映射。
 *
 * 判据全部下沉到 [DataTransferApplyLogic.planTimeSchemeSteps]，但**只落 Create**：
 * - 同 id（Update）→ **一个字都不改本机模板**（2026-11-06 返工：旧实现会把本机模板的
 *   name/sections 用包里的覆盖掉，用户原有模板被改坏且回滚救不回；违背方案三段设计）；
 * - 节次签名相同（Reuse）→ 复用本机 id，不新建、不改写；
 * - 其余（Create）→ 新建一套。
 *
 * 该落哪些写的判据由 [DataTransferApplyLogic.timeSchemeStepsToCreate] 统一给出（可单测），
 * 这里不自己再判一遍，避免两处漂移。
 */
private fun reconcileTimeSchemes(
    repository: TimetableRepository,
    incoming: List<TimeScheme>,
): Map<String, String> {
    if (incoming.isEmpty()) return emptyMap()
    val mapping = LinkedHashMap<String, String>(incoming.size)
    val steps = DataTransferApplyLogic.planTimeSchemeSteps(
        current = repository.snapshot.timeSchemes,
        incoming = incoming,
    )
    // 复用：只记映射（id 相同/同签名都不需要新建，也不可能改本机那份）。
    for (step in steps) {
        if (step is DataTransferApplyLogic.TimeSchemeStep.Reuse) {
            mapping[step.incomingId] = step.localId
        }
    }
    // 新建：只落 Create；Update 一律跳过（见 KDoc）。
    for (step in DataTransferApplyLogic.timeSchemeStepsToCreate(steps)) {
        val created = runCatching {
            repository.createTimeScheme(step.name, step.sections)
        }.getOrNull()
        if (created != null) mapping[step.incomingId] = created.id
    }
    return mapping
}

/** 撤销一份导入：按快照种类整份写回（Dart `undoToken`）。 */
private fun undoImport(repository: TimetableRepository, token: TransferUndoToken): Boolean =
    restoreFromSnapshot(repository, token.snapshot)

/**
 * 按快照整份写回。**撤销**与「导入失败回滚」共用这一份判据——两处需要还原的
 * 东西完全一样（时间模板表 / profiles / 活动档案内容 / 设置 / 当前周 / 日程 / 规则 / 分组），
 * 分成两份实现早晚会漂。
 *
 * 快照里的每一块都是**导入前本机的真实值**（不是「包里没带」），所以空列表也必须
 * 照写：否则撤销清不掉本次导入进来的日程，回滚也会留下半替换现场。
 *
 * **时间模板表先写回**（2026-11-06 返工）：导入第一步就会新建模板，不还原就永久留一套；
 * 先写模板表再写档案内容，任何内部按模板同步的路径看到的都是原始模板。
 *
 * ## 逐步尽力还原（2026-11-06 二轮返工）
 *
 * 发布版失败回滚是「每步各自 catch、继续还原剩余步骤」，最后按是否有失败决定报
 * `import_rollback_incomplete`；本函数照此改掉「一个 `runCatching` 包全部」的写法——
 * 旧写法第一笔写挂就整段中止，后面的步骤一个都不还原，等于半还原。
 * 与本仓 `LanTransferApplier.restoreState` 的「尽力补偿」同一口径。
 *
 * 返回值 = **所有步骤是否都成功**；任何一步失败都返回 false，调用方翻成
 * `import_rollback_incomplete`（用户可见）。单步失败不中断后续步骤。
 *
 * ## 已知差异（如实记，不装等价）
 *
 * 发布版**有** `runSettingsMirrorTransaction` 之类的事务包裹（整份恢复在事务里），
 * 本仓仓储是「多 key 独立落盘、没有跨 key 事务」（`TimetableRepository` 的 KDoc 自认）——
 * 所以这里只能**逐步尽力还原**，失败聚合报 `import_rollback_incomplete`，做不到发布版那种原子性。
 *
 * 发布版回滚还会还原 partnerBinding / signature / live 状态；但「导入为新课表」与
 * 「单课表/全量覆盖」这两条路径**根本不碰**那些（快照里也就没有它们），
 * 所以本函数不纳入——这是范围差异，不是漏迁。
 *
 * 另一处曾是的差异已经**消除**：`updateLocationTimeGroups(resync = true)` / `all_data` 会重排
 * **所有档案**的课程钟点，旧快照只抓活动档 ⇒ 其它档停在新钟点上（半还原）。现在这类路径
 * 由 `undoKindFor(..., rewritesAllProfiles = true)` 改抓 `FULL_PROFILES`，改多少档就还原多少档。
 */
private fun restoreFromSnapshot(
    repository: TimetableRepository,
    snapshot: TransferUndoSnapshot,
): Boolean {
    var allSucceeded = true

    // 单步失败只记账、继续走完剩余步骤（见 KDoc「逐步尽力还原」）。
    fun step(block: () -> Unit) {
        if (!runCatching(block).isSuccess) allSucceeded = false
    }

    // 模板表：null = 这份快照不负责它（老调用点），有值就整份写回。
    snapshot.timeSchemes?.let { schemes -> step { repository.replaceTimeSchemes(schemes) } }
    when (snapshot.kind) {
        TransferUndoScope.FULL_PROFILES -> {
            step {
                repository.replaceAllProfiles(
                    profiles = snapshot.profiles,
                    activeProfileId = snapshot.activeProfileId,
                    preferredEmbeddedSettings = snapshot.profileSettingsById.orEmpty(),
                )
            }
            snapshot.settings?.let { settings -> step { repository.updateSettings(settings) } }
            // 全量恢复写回过整机偏好（见 applyImport），撤销必须一起还原。
            snapshot.globalSettingsJson?.let { globals ->
                step { repository.writeRawSettingsPatch(globals) }
            }
            // 全量导入现在会写当前周（见 applyImport），撤销必须一起还原。
            step { repository.setCurrentWeek(snapshot.currentWeek) }
        }

        TransferUndoScope.ACTIVE_PROFILE_CONTENT -> {
            // 日程条目无条件写回（含空列表），理由见函数注释。
            step { repository.scheduleItems = snapshot.scheduleItems }
            step {
                repository.replaceActiveProfileContent(
                    courses = snapshot.courses,
                    tasks = snapshot.tasks,
                    exams = snapshot.exams,
                )
            }
            snapshot.settings?.let { settings -> step { repository.updateSettings(settings) } }
            // 完整设置原文（非 core 键）也要回到导入前，否则撤销只回滚一半。
            snapshot.settingsJson?.let { json -> step { repository.replaceActiveProfileSettingsJson(json) } }
            step { repository.setCurrentWeek(snapshot.currentWeek) }
            step { repository.persistActiveProfileState() }
        }
    }
    // 本次导入动过日程规则才还原（null = 没动过，别把本机规则抹了）。
    snapshot.scheduleDateRules?.let { rules -> step { repository.updateScheduleDateRules(rules) } }
    // 地点作息分组同理：导入会写它，撤销就得能一起回到原样。
    snapshot.locationTimeGroups?.let { groups -> step { repository.updateLocationTimeGroups(groups) } }
    return allSucceeded
}

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
 *
 * 样式本体在共享件 [AppToastCapsule]（情侣课表页也用同一颗，见
 * `CoupleTimetableSettingsHost`），这里只把「可能为 null 的一次性状态」翻成它。
 */
@Composable
private fun TransferToastCapsule(
    state: TransferToastState?,
    dark: Boolean,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val current = state ?: return
    AppToastCapsule(
        message = current.message,
        dark = dark,
        modifier = modifier,
        actionLabel = current.actionLabel,
        onAction = current.onAction,
        onDismiss = onDismiss,
    )
}
