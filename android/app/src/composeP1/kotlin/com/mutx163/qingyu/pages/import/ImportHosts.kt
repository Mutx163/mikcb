package com.mutx163.qingyu.pages.import

import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import com.mutx163.qingyu.app.TimetableHostLogic
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableSnapshot
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.FormatException
import com.mutx163.qingyu.core.TimeSchemeLogic
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.core.WeekCalculator
import com.mutx163.qingyu.pages.ShellExternalEntryHub
import com.mutx163.qingyu.pages.import.warehouse.ImportCompletionCounter
import com.mutx163.qingyu.pages.shell.ShellExternalEntry
import com.mutx163.qingyu.platform.AndroidImportDocumentReader
import com.mutx163.qingyu.platform.AndroidImportTemplateSharer
import com.mutx163.qingyu.platform.PrefsKeyValueStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.LocalDateTime

/**
 * 导入三页（`g1.importEntry` / `g1.icsImport` / `g1.spreadsheetImport`）的**真宿主**。
 *
 * ## 壳里原来是什么
 *
 * | 路由 | 原挂法 | 用户看到 |
 * |---|---|---|
 * | `g1.importEntry` | `ImportEntryViewState()` 默认值 + 三个 `{}` | 随机配色开关点了不动、四个导入方式点了不动 |
 * | `g1.icsImport` | `IcsImportViewState()` + `onChooseFile = {}` | 「选择 .ics 文件」点了没反应 |
 * | `g1.spreadsheetImport` | `SpreadsheetImportViewState()` + 两个 `{}` | 「下载模板」「选择表格文件」都没反应 |
 *
 * ## 每个交互的落点
 *
 * | 控件 | 真落点 |
 * |---|---|
 * | 随机配色开关 / 配色组 | [ImportRandomColorStore]（键名与 Dart 的三个 prefs 键逐字一致） |
 * | 四个导入方式导航行 | 壳的 `onOpenPage`（IES→`g1.icsImport`、表格→`g1.spreadsheetImport`、识图→`g2.aiImageImport`、教务→`g2.schoolAdapters`） |
 * | 选择 .ics / 表格文件 | SAF `OpenDocument`（MIME 候选见 [ImportFlowModel]）→ **限长读**（20 MB，超限报「文件太大」） |
 * | 解析 | ICS→[IcsImportModel]；表格 csv→[SpreadsheetImportModel.parseBytes]、xlsx→[XlsxSheetDecoder] + [SpreadsheetImportModel.parseRows] |
 * | 预览确认 | [ImportPreviewDialog]（识别到几门 / 开学日 / 第 1 周对应校历第几周 / 覆盖还是更新）——**确认前一字节都不落盘** |
 * | 节次不足 | [ImportCapacityDialog] → 补节写时间模板（有主模板时写模板，否则写设置），失败回滚 |
 * | 落盘 | `updateSettings`（开学日 + 学期总周数只升不降）+ `replaceActiveProfileContent`（课程）+ 重算当前周 |
 * | 下载模板 | [ImportTemplateModel] 正文 → `cacheDir/transfer-share/` → FileProvider → 系统分享面板 |
 *
 * ## 为什么写在 Compose 层而不是模型层
 *
 * 要 `Context`（SAF / 分享 / Toast）与 `rememberLauncherForActivityResult`，进不了 JVM 单测。
 * 「覆盖还是合并写成什么样」「节次要补几节」「配色要不要重排」「哪句文案」这些判断
 * 全部在 [ImportFlowModel] / [ImportServiceMessages] / [ImportSharedModel] 里，有单测。
 *
 * ## 线程约定（与 `DataTransferHost` / `WeatherSettingsHost` 一致）
 *
 * 读文件、解析、落盘一律 `Dispatchers.IO`；Toast 与导航回主线程。
 *
 * ## 诚实边界（未对照真机，也不假装）
 *
 * 1. 系统选择器是否真能列出 `.ics` / `.xlsx`、分享面板是否真弹出，只能真机验收；
 * 2. `.xlsx` 走的是本仓最小的 zip+XML 解码器（[XlsxSheetDecoder]），**日期型单元格**
 *    只会读到 Excel 序列号——本模板的必填列（课程名/星期/节次/周次）都不是日期型，
 *    所以不影响导入，但「把日期列当必填列用」的第三方模板可能读不出可读日期；
 * 3. `.ics` 只认 WakeUp 风格（DESCRIPTION 里有「第 X-Y 节」），这是 Dart 侧同一个口径。
 */
@Composable
fun ImportEntryHost(
    onBack: () -> Unit,
    onOpenPage: (String) -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val store = remember(context) { ImportRandomColorStore(PrefsKeyValueStore(context)) }
    // null = 偏好还没读完：页面据此把两行置灰（Dart `_loaded == false` 时 onChanged 传 null）。
    var prefs by remember { mutableStateOf<ImportRandomColorPrefs?>(null) }
    var showGroupPicker by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        prefs = withContext(Dispatchers.IO) { store.snapshot() }
    }
    // 子页导入成功 → 与 Dart 的 pop(true) 同义：入口页自关。
    //
    // 2026-11-10 第二波：桥从「每个路由条目一份」改成进程级单例（见 ImportShellBridge），
    // 且信号从布尔改成**代数**。原因有二：
    // 1. 入口页被一个子页盖住时仍留在组合里（miuix-nav opaqueDepth=1 保留下层一层），
    //    `LaunchedEffect(Unit)` 不会重跑 —— 布尔标记永远等不到消费者；
    // 2. 外部「打开方式」直接进 ICS/表格导入时没有入口页，布尔标记会留到下一次进入
    //    导入方式页、把它秒关。代数只认「挂载之后增长的那几次」，天然没有陈旧信号。
    val importGenerationAtMount = remember { ImportShellBridge.importGeneration }
    LaunchedEffect(ImportShellBridge.importGeneration) {
        if (ImportShellBridge.importGeneration > importGenerationAtMount) {
            onBack()
        }
    }
    // 外部「打开方式 / 分享」带进来但 provider 自报超限的文件（R1 补口 2026-11-02）：
    // 跳板读完声明尺寸就 post 过来，这里弹与 SAF 路径同一句的「文件过大」——超限
    // 必须告诉用户，不能像收到一个打不开的文件一样毫无反应。
    LaunchedEffect(Unit) {
        val payload = ShellExternalEntryHub.consumeImport(ShellExternalEntry.IMPORT_KIND_TOO_LARGE)
        if (payload is ShellExternalEntry.ImportPayload.TooLarge) {
            Toast.makeText(
                context,
                ImportStrings.importFileTooLarge.filled(
                    "size",
                    ImportFlowModel.formatSizeLimit(payload.maxBytes.toInt()),
                ),
                Toast.LENGTH_SHORT,
            ).show()
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        ImportEntryPage(
            viewState = ImportEntryViewState(
                randomColorsEnabled = prefs?.enabled ?: false,
                randomColorGroupId = prefs?.groupId ?: ImportRandomColorStore.DEFAULT_GROUP_ID,
                preferencesLoaded = prefs != null,
            ),
            onBack = onBack,
            onToggleRandomColors = { enabled ->
                // 先改界面再落盘：Dart 也是 setState 后 await 写（写失败用户下次进来会看到真值）。
                prefs = prefs?.copy(enabled = enabled)
                scope.launch { withContext(Dispatchers.IO) { store.setEnabled(enabled) } }
            },
            onPickColorGroup = { if (prefs?.enabled == true) showGroupPicker = true },
            onOpenDestination = { destination ->
                when (destination) {
                    ImportEntryDestination.ICS -> onOpenPage("g1.icsImport")
                    ImportEntryDestination.SPREADSHEET -> onOpenPage("g1.spreadsheetImport")
                    ImportEntryDestination.AI -> onOpenPage("g2.aiImageImport")
                    ImportEntryDestination.WAREHOUSE -> onOpenPage("g2.schoolAdapters")
                }
            },
        )
        ImportColorGroupSheet(
            show = showGroupPicker,
            selectedGroupId = prefs?.groupId ?: ImportRandomColorStore.DEFAULT_GROUP_ID,
            onSelect = { groupId ->
                showGroupPicker = false
                prefs = prefs?.copy(groupId = groupId)
                scope.launch { withContext(Dispatchers.IO) { store.setGroupId(groupId) } }
            },
            onDismiss = { showGroupPicker = false },
        )
    }
}

/**
 * 跨路由暂存：**进程级单例**（2026-11-10 第二波修桥）。
 *
 * ## 为什么必须是 object
 *
 * 原先它是 `ShellPageContent` 里的 `remember { ImportShellBridge() }`，而 `ShellPageContent`
 * 由 `entry<ShellRoute.Page>` **每个路由条目各组合一次** ⇒ 入口页与子页各拿一份，
 * 子页写的 `completedImport` 入口页永远读不到（「导入成功后入口页不自关」的根因）。
 * 跨路由的一次性交接件在本仓已有先例：`WarehouseImportHandoff` 也是 object。
 *
 * ## 为什么是「代数」而不是布尔
 *
 * 发布版是 `Navigator.pop(true)` 的**返回值**，天然只对当前入口页生效、不会跨次残留。
 * 进程级单例没有返回值，于是入口页挂载时记下 [importGeneration]，只认它之后的增长：
 * 正常流程自关；外部「打开方式」直接进子页导入成功时没有入口页在等，代数增长不会
 * 传染给下一次进入的入口页（详见 `ImportCompletionCounter`）。
 */
object ImportShellBridge {

    private val counter = ImportCompletionCounter()

    /**
     * 「子页导入成功」代数（只增不减）。
     *
     * 用 Compose 状态承载：入口页在组合里读它，代数一变就重组、由
     * `LaunchedEffect` 消费并自关（被盖住时也在组合里，不会漏）。
     */
    var importGeneration by mutableStateOf(0)
        private set

    /** 子页成功导入并已落盘：通知入口页可以关了（子页自己也会 `onBack`）。 */
    fun markImported() {
        counter.markImported()
        importGeneration = counter.snapshot()
    }
}

/** ICS 导入页宿主（`g1.icsImport`）。 */
@Composable
fun IcsImportHost(
    repository: TimetableRepository,
    bridge: ImportShellBridge,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val reader = remember(context) { AndroidImportDocumentReader(context) }
    val colorStore = remember(context) { ImportRandomColorStore(PrefsKeyValueStore(context)) }

    var isImporting by remember { mutableStateOf(false) }
    var colorPrefs by remember { mutableStateOf<ImportRandomColorPrefs?>(null) }
    var pending by remember { mutableStateOf<PendingImport?>(null) }
    var capacity by remember { mutableStateOf<CapacityRequest?>(null) }

    LaunchedEffect(Unit) {
        colorPrefs = withContext(Dispatchers.IO) { colorStore.snapshot() }
    }
    // 外部「打开方式 / 分享」带进来的 .ics（R1 补口 2026-11-02）：跳板已限长读好，
    // 这里与 SAF 读到字节走同一条「解析 → 预览确认」链，不落盘、不再读一遍 URI。
    LaunchedEffect(Unit) {
        val payload = ShellExternalEntryHub.consumeImport("ics")
            as? ShellExternalEntry.ImportPayload.Ics
            ?: return@LaunchedEffect
        // Dart 用 `utf8.decode(allowMalformed: true)`：坏字节变 U+FFFD，不整份失败。
        val parsed = runCatching { IcsImportModel.parseWakeUpSchedule(payload.text) }.getOrNull()
        if (parsed == null || parsed.courses.isEmpty()) {
            Toast.makeText(context, ImportStrings.importNoCoursesRecognized.text, Toast.LENGTH_SHORT).show()
            return@LaunchedEffect
        }
        val snapshot = repository.snapshot
        val defaultStart = snapshot.settings.semesterStartDate ?: parsed.semesterStart
        pending = PendingImport(
            courses = parsed.courses,
            semesterStartDate = defaultStart,
            firstCourseWeek = ImportWeekAlignment.inferFirstCourseWeek(
                semesterStartDate = defaultStart,
                firstCourseDate = parsed.semesterStart,
            ),
        )
    }

    fun showToast(message: String) {
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
    }

    fun runImport(request: ApplyRequest, expandSections: Boolean) {
        if (isImporting) return
        isImporting = true
        scope.launch {
            val result = withContext(Dispatchers.IO) { applyImport(repository, request, expandSections) }
            isImporting = false
            showToast(result.message)
            if (result is ApplyResult.Done && result.importedCount > 0) {
                bridge.markImported()
                onBack()
            }
        }
    }

    val launcher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument(),
    ) { uri ->
        // 用户取消选文件：Dart 不提示、直接返回（`ics_course_import_screen.dart:108`）。
        if (uri == null) return@rememberLauncherForActivityResult
        isImporting = true
        scope.launch {
            val read = withContext(Dispatchers.IO) {
                reader.read(uri, IcsImportModel.MAX_FILE_BYTES.toLong())
            }
            isImporting = false
            when (read) {
                is AndroidImportDocumentReader.Result.TooLarge -> showToast(
                    ImportStrings.importFileTooLarge.filled(
                        "size",
                        ImportFlowModel.formatSizeLimit(IcsImportModel.MAX_FILE_BYTES),
                    ),
                )

                is AndroidImportDocumentReader.Result.ReadFailed ->
                    showToast(ImportStrings.importFileReadFailed.text)

                is AndroidImportDocumentReader.Result.Bytes -> {
                    // Dart 用 `utf8.decode(allowMalformed: true)`：坏字节变 U+FFFD，不整份失败。
                    val text = String(read.bytes, Charsets.UTF_8)
                    val parsed = runCatching { IcsImportModel.parseWakeUpSchedule(text) }.getOrNull()
                    if (parsed == null || parsed.courses.isEmpty()) {
                        showToast(ImportStrings.importNoCoursesRecognized.text)
                        return@launch
                    }
                    val snapshot = repository.snapshot
                    val defaultStart = snapshot.settings.semesterStartDate ?: parsed.semesterStart
                    pending = PendingImport(
                        courses = parsed.courses,
                        semesterStartDate = defaultStart,
                        firstCourseWeek = ImportWeekAlignment.inferFirstCourseWeek(
                            semesterStartDate = defaultStart,
                            firstCourseDate = parsed.semesterStart,
                        ),
                    )
                }
            }
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        IcsImportPage(
            viewState = IcsImportViewState(isImporting = isImporting),
            onBack = onBack,
            onChooseFile = {
                if (!isImporting) launcher.launch(ImportFlowModel.ICS_MIME_TYPES.toTypedArray())
            },
        )

        val snapshot = repository.snapshot
        val current = pending
        ImportPreviewDialog(
            show = current != null,
            importLabel = ImportStrings.icsImportTitle.text,
            courseCount = current?.courses?.size ?: 0,
            semesterStartDate = current?.semesterStartDate,
            initialFirstCourseWeek = current?.firstCourseWeek ?: 1,
            lastAllowedWeek = snapshot.settings.semesterWeekCount,
            hasExistingCourses = snapshot.courses.isNotEmpty(),
            onCancel = { pending = null },
            onConfirm = { choice ->
                val parsed = pending ?: return@ImportPreviewDialog
                pending = null
                val prefs = colorPrefs ?: colorStore.snapshot()
                // Dart 顺序：周次对齐（按用户确认的「第 1 周对应校历第几周」）→ 随机配色 → 落盘。
                val aligned = ImportWeekAlignment.shiftCoursesToSemesterWeeks(
                    courses = parsed.courses,
                    firstCourseWeek = choice.firstCourseWeek,
                )
                val request = ApplyRequest(
                    courses = ImportFlowModel.coursesWithOptionalRandomColors(aligned, prefs),
                    semesterStartDate = choice.semesterStartDate,
                    replaceExisting = choice.replaceExisting,
                    preserveLocalColors = ImportFlowModel.shouldPreserveLocalColors(
                        replaceExisting = choice.replaceExisting,
                        randomColorsEnabled = prefs.enabled,
                    ),
                )
                requestCapacityOrImport(
                    snapshot = repository.snapshot,
                    request = request,
                    onNeedsCapacity = { current0, required ->
                        capacity = CapacityRequest(
                            request = request,
                            currentSectionCount = current0,
                            requiredSectionCount = required,
                        )
                    },
                    onReady = { runImport(request, expandSections = false) },
                )
            },
        )

        val cap = capacity
        ImportCapacityDialog(
            show = cap != null,
            currentSectionCount = cap?.currentSectionCount ?: 0,
            requiredSectionCount = cap?.requiredSectionCount ?: 0,
            onCancel = { capacity = null },
            onAutoFill = {
                val request = capacity?.request
                capacity = null
                if (request != null) runImport(request, expandSections = true)
            },
        )
    }
}

/** 表格导入页宿主（`g1.spreadsheetImport`）。 */
@Composable
fun SpreadsheetImportHost(
    repository: TimetableRepository,
    bridge: ImportShellBridge,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val reader = remember(context) { AndroidImportDocumentReader(context) }
    val colorStore = remember(context) { ImportRandomColorStore(PrefsKeyValueStore(context)) }
    val sharer = remember(context) { AndroidImportTemplateSharer(context) }

    var isImporting by remember { mutableStateOf(false) }
    var isSharingTemplate by remember { mutableStateOf(false) }
    var colorPrefs by remember { mutableStateOf<ImportRandomColorPrefs?>(null) }
    var pending by remember { mutableStateOf<PendingImport?>(null) }
    var warnings by remember { mutableStateOf<List<String>>(emptyList()) }
    var showWarnings by remember { mutableStateOf(false) }
    var capacity by remember { mutableStateOf<CapacityRequest?>(null) }

    LaunchedEffect(Unit) {
        colorPrefs = withContext(Dispatchers.IO) { colorStore.snapshot() }
    }
    // 外部「打开方式 / 分享」带进来的表格文件（R1 补口 2026-11-02）：跳板已把字节读好，
    // csv 编码探测 / xlsx 容器解码走与 SAF 完全相同的 parseSpreadsheet 链。
    LaunchedEffect(Unit) {
        val payload = ShellExternalEntryHub.consumeImport("spreadsheet")
            as? ShellExternalEntry.ImportPayload.Spreadsheet
            ?: return@LaunchedEffect
        val settings = repository.snapshot.settings
        val parsed = runCatching {
            withContext(Dispatchers.IO) { parseSpreadsheet(payload.bytes, payload.fileName, settings) }
        }.getOrElse { error ->
            // 解析失败要说清原因（格式不识别 / 编码不识别 / xlsx 容器读不出来），与 SAF 同口径。
            val code = (error as? FormatException)?.message
            Toast.makeText(
                context,
                ImportServiceMessages.localize(code ?: error.message),
                Toast.LENGTH_SHORT,
            ).show()
            return@LaunchedEffect
        }
        if (parsed.courses.isEmpty()) {
            Toast.makeText(context, ImportStrings.importNoCoursesRecognized.text, Toast.LENGTH_SHORT).show()
            return@LaunchedEffect
        }
        // 提醒先看，再确认导入（Dart `_executeSpreadsheetImport` 同顺序）。
        warnings = parsed.warnings.map(ImportServiceMessages::localize)
        pending = if (warnings.isNotEmpty()) {
            showWarnings = true
            PendingImport(
                courses = parsed.courses,
                semesterStartDate = null,
                firstCourseWeek = 1,
                warningCount = warnings.size,
            )
        } else {
            PendingImport(
                courses = parsed.courses,
                semesterStartDate = null,
                firstCourseWeek = 1,
            )
        }
    }

    fun showToast(message: String) {
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
    }

    fun runImport(request: ApplyRequest, expandSections: Boolean) {
        if (isImporting) return
        isImporting = true
        scope.launch {
            val result = withContext(Dispatchers.IO) { applyImport(repository, request, expandSections) }
            isImporting = false
            showToast(result.message)
            if (result is ApplyResult.Done && result.importedCount > 0) {
                bridge.markImported()
                onBack()
            }
        }
    }

    val launcher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument(),
    ) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        isImporting = true
        scope.launch {
            val read = withContext(Dispatchers.IO) {
                reader.read(uri, SpreadsheetImportModel.MAX_FILE_BYTES.toLong())
            }
            isImporting = false
            when (read) {
                is AndroidImportDocumentReader.Result.TooLarge -> showToast(
                    ImportStrings.importFileTooLarge.filled(
                        "size",
                        ImportFlowModel.formatSizeLimit(SpreadsheetImportModel.MAX_FILE_BYTES),
                    ),
                )

                is AndroidImportDocumentReader.Result.ReadFailed ->
                    showToast(ImportStrings.importFileReadFailed.text)

                is AndroidImportDocumentReader.Result.Bytes -> {
                    val settings = repository.snapshot.settings
                    val fileName = read.fileName ?: ImportStrings.spreadsheetImportTitle.text
                    val parsed = runCatching {
                        withContext(Dispatchers.IO) { parseSpreadsheet(read.bytes, fileName, settings) }
                    }.getOrElse { error ->
                        // 解析失败要说清原因：格式不识别 / 编码不识别 / xlsx 容器读不出来，
                        // 都是服务层码，交给 ImportServiceMessages 出人话（Dart 同口径）。
                        val code = (error as? FormatException)?.message
                        showToast(ImportServiceMessages.localize(code ?: error.message))
                        return@launch
                    }
                    if (parsed.courses.isEmpty()) {
                        showToast(ImportStrings.importNoCoursesRecognized.text)
                        return@launch
                    }
                    // 提醒先看，再确认导入（Dart `_executeSpreadsheetImport` 同顺序）。
                    warnings = parsed.warnings.map(ImportServiceMessages::localize)
                    if (warnings.isNotEmpty()) {
                        showWarnings = true
                        pending = PendingImport(
                            courses = parsed.courses,
                            semesterStartDate = null,
                            firstCourseWeek = 1,
                            warningCount = warnings.size,
                        )
                    } else {
                        pending = PendingImport(
                            courses = parsed.courses,
                            semesterStartDate = null,
                            firstCourseWeek = 1,
                        )
                    }
                }
            }
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        SpreadsheetImportPage(
            viewState = SpreadsheetImportViewState(
                isImporting = isImporting,
                isSharingTemplate = isSharingTemplate,
            ),
            onBack = onBack,
            onDownloadTemplate = {
                if (!isSharingTemplate && !isImporting) {
                    isSharingTemplate = true
                    scope.launch {
                        val outcome = withContext(Dispatchers.IO) {
                            sharer.shareTemplate(ImportStrings.downloadSpreadsheetTemplateAction.text)
                        }
                        isSharingTemplate = false
                        // 分享面板拉起后不再提示（成功由面板本身体现）；只有写盘/拉起失败才说话。
                        if (outcome is AndroidImportTemplateSharer.Outcome.Failed) {
                            showToast(ImportStrings.saveFailed.text)
                        }
                    }
                }
            },
            onChooseFile = {
                if (!isImporting) {
                    launcher.launch(ImportFlowModel.SPREADSHEET_MIME_TYPES.toTypedArray())
                }
            },
        )

        // 提醒对话框：只展示「哪一行、哪个字段」，点「继续导入」后才进预览确认。
        ImportSpreadsheetWarningsDialog(
            show = showWarnings,
            warnings = warnings,
            onContinue = { showWarnings = false },
            onDismiss = {
                showWarnings = false
                pending = null
            },
        )

        val snapshot = repository.snapshot
        val current = pending
        ImportPreviewDialog(
            show = current != null && !showWarnings,
            importLabel = ImportStrings.spreadsheetImportTitle.text,
            courseCount = current?.courses?.size ?: 0,
            // 表格导入没有学期映射环节（周次直接来自表里的周次列），Dart 同口径。
            semesterStartDate = null,
            initialFirstCourseWeek = 1,
            lastAllowedWeek = snapshot.settings.semesterWeekCount,
            hasExistingCourses = snapshot.courses.isNotEmpty(),
            onCancel = { pending = null },
            onConfirm = { choice ->
                val parsed = pending ?: return@ImportPreviewDialog
                pending = null
                val prefs = colorPrefs ?: colorStore.snapshot()
                val request = ApplyRequest(
                    courses = ImportFlowModel.coursesWithOptionalRandomColors(parsed.courses, prefs),
                    semesterStartDate = null,
                    replaceExisting = choice.replaceExisting,
                    preserveLocalColors = ImportFlowModel.shouldPreserveLocalColors(
                        replaceExisting = choice.replaceExisting,
                        randomColorsEnabled = prefs.enabled,
                    ),
                    warningCount = parsed.warningCount,
                )
                requestCapacityOrImport(
                    snapshot = repository.snapshot,
                    request = request,
                    onNeedsCapacity = { current0, required ->
                        capacity = CapacityRequest(
                            request = request,
                            currentSectionCount = current0,
                            requiredSectionCount = required,
                        )
                    },
                    onReady = { runImport(request, expandSections = false) },
                )
            },
        )

        val cap = capacity
        ImportCapacityDialog(
            show = cap != null,
            currentSectionCount = cap?.currentSectionCount ?: 0,
            requiredSectionCount = cap?.requiredSectionCount ?: 0,
            onCancel = { capacity = null },
            onAutoFill = {
                val request = capacity?.request
                capacity = null
                if (request != null) runImport(request, expandSections = true)
            },
        )
    }
}

// ==========================================================================
// 纯逻辑部分（本文件私有；判断本身都在 ImportFlowModel / 模型层）
// ==========================================================================

/** 一次待确认的导入（预览卡消费它）。 */
private data class PendingImport(
    val courses: List<Course>,
    /** ICS 才有；表格导入为 null。 */
    val semesterStartDate: LocalDateTime?,
    val firstCourseWeek: Int,
    val warningCount: Int = 0,
)

/** 待落盘请求（预览确认后构造，容量补齐前后共用同一份）。 */
private data class ApplyRequest(
    val courses: List<Course>,
    val semesterStartDate: LocalDateTime?,
    val replaceExisting: Boolean,
    val preserveLocalColors: Boolean,
    val warningCount: Int = 0,
)

/** 待用户拍板的「节次不够」。 */
private data class CapacityRequest(
    val request: ApplyRequest,
    val currentSectionCount: Int,
    val requiredSectionCount: Int,
)

/** 落盘结果（Toast 文案 + 是否算「导入了东西」）。 */
private sealed interface ApplyResult {
    val message: String

    data class Done(override val message: String, val importedCount: Int) : ApplyResult

    data class Failed(override val message: String) : ApplyResult
}

/**
 * 节次检查：够用就直接导入，不够就交给宿主弹「自动补齐并导入」。
 *
 * 判据全部来自 [ImportFlowModel]（最终课程表要用到第几节 / 现有几节 / 要不要补）。
 */
private fun requestCapacityOrImport(
    snapshot: TimetableSnapshot,
    request: ApplyRequest,
    onNeedsCapacity: (current: Int, required: Int) -> Unit,
    onReady: () -> Unit,
) {
    val currentSections = activeSections(snapshot).size
    val required = ImportFlowModel.requiredSectionCount(
        ImportFlowModel.planApply(
            existingCourses = snapshot.courses,
            importedCourses = request.courses,
            replaceExisting = request.replaceExisting,
            preserveLocalColors = request.preserveLocalColors,
        ).courses,
    )
    if (ImportFlowModel.needsSectionExpansion(activeSections(snapshot), required)) {
        onNeedsCapacity(currentSections, required)
    } else {
        onReady()
    }
}

/** 当前生效的节次表：有主时间模板就取模板，否则取设置里的（与课表页判据同源）。 */
private fun activeSections(snapshot: TimetableSnapshot) =
    TimetableHostLogic.resolveActiveTimeScheme(
        schemes = snapshot.timeSchemes,
        activeTimeSchemeId = snapshot.activeTimeSchemeId,
    )?.sections ?: snapshot.settings.sections

/** csv 走模型自带的编码探测；xlsx 先解容器再走同一条 `parseRows`。 */
private fun parseSpreadsheet(
    bytes: ByteArray,
    fileName: String,
    settings: TimetableSettings,
): SpreadsheetImportResult {
    if (ImportFlowModel.isXlsxFile(fileName)) {
        return SpreadsheetImportModel.parseRows(
            rows = XlsxSheetDecoder.decodeFirstSheet(bytes),
            fileName = fileName,
            settings = settings,
        )
    }
    return SpreadsheetImportModel.parseBytes(bytes, fileName, settings)
}

/**
 * 真正落盘（Dart `provider.importParsedCourses` 的 Kotlin 侧等价物）。
 *
 * 顺序与 Dart 一致：**先确认节次够（必要时当场补表并落盘）→ 写学期设置（总周数只升不降、
 * 开学日）→ 按生效模板同步课程钟点后写课程 → 重算当前周、清实时卡片**。
 * 任一步抛错就把已改的设置/节次回滚回去——「导入失败但作息被改了」是最难解释的状态。
 *
 * 课程写入走 `replaceActiveProfileContent`（一次落盘 + 一次通知），作业与考试原样带上，
 * 与 `DataTransferHost.applyImport` 同一口径（这两块本批不动）。
 */
private fun applyImport(
    repository: TimetableRepository,
    request: ApplyRequest,
    expandSections: Boolean,
): ApplyResult {
    val before = repository.snapshot
    val plan = ImportFlowModel.planApply(
        existingCourses = before.courses,
        importedCourses = request.courses,
        replaceExisting = request.replaceExisting,
        preserveLocalColors = request.preserveLocalColors,
    )
    val currentSections = activeSections(before)
    val required = ImportFlowModel.requiredSectionCount(plan.courses)
    val scheme = TimetableHostLogic.resolveActiveTimeScheme(before.timeSchemes, before.activeTimeSchemeId)
    val needsExpansion = expandSections &&
        ImportFlowModel.needsSectionExpansion(currentSections, required)
    return try {
        if (needsExpansion) {
            val nextSections = ImportFlowModel.sectionsForImport(currentSections, required)
            if (scheme != null) {
                // 有主模板时页面读的是模板节次，写设置里的节次表不会生效。
                val error = repository.updateTimeScheme(scheme.id, scheme.name, nextSections)
                if (error != null) {
                    return ApplyResult.Failed(ImportStrings.saveFailed.text)
                }
            } else {
                repository.updateSettings(before.settings.copy(sections = nextSections))
            }
        }
        // Dart `importParsedCourses`：学期总周数按合并后课程的最大周次**只升不降**落盘；
        // 开学日若有变化一并在同一次设置写入里提交（模板路径已先改写节次镜像，这里重取快照）。
        val baseSettings = repository.snapshot.settings
        val nextSettings = baseSettings.copy(
            semesterStartDate = request.semesterStartDate ?: baseSettings.semesterStartDate,
            semesterWeekCount = ImportFlowModel.nextSemesterWeekCount(
                baseSettings.semesterWeekCount,
                plan.courses,
            ),
        )
        if (nextSettings != baseSettings) {
            repository.updateSettings(nextSettings)
        }
        // Dart 写入前会按生效时间模板重新绑定课程节次（`syncCoursesWithEffectiveTimeSchemes`），
        // 补过节的模板也在这时生效。
        val syncedCourses = TimeSchemeLogic.syncCoursesWithEffectiveTimeSchemes(
            source = plan.courses,
            schemes = repository.snapshot.timeSchemes,
            settings = repository.snapshot.settings,
            locationTimeGroups = repository.snapshot.locationTimeGroups,
            scheduleDateRules = repository.snapshot.scheduleDateRules,
        )
        repository.replaceActiveProfileContent(
            courses = syncedCourses,
            tasks = repository.tasks,
            exams = repository.exams,
        )
        // Dart：给了开学日就按今天重算当前周；课程写成功后再落，失败不留半张课表。
        request.semesterStartDate?.let {
            runCatching {
                val settings = repository.snapshot.settings
                repository.setCurrentWeek(
                    WeekCalculator.weekForDate(
                        date = LocalDateTime.now(),
                        semesterStart = settings.semesterStartDate,
                        semesterWeekCount = settings.semesterWeekCount,
                        fallback = before.currentWeek,
                    ),
                )
            }
        }
        // Dart：导入后清掉「正在上课」实时卡片，等下一轮按新课表重算。
        runCatching { repository.clearCurrentLiveCourseId() }
        ApplyResult.Done(
            message = ImportSharedModel.buildImportResultMessage(
                importedCount = plan.importedCount,
                replaceExisting = plan.replaceExisting,
                warningCount = request.warningCount,
            ),
            importedCount = plan.importedCount,
        )
    } catch (error: Exception) {
        // 回滚：课程、设置（含开学日与节次表）、主模板节次都恢复成导入前的样子。
        // 2026-11-05 数据安全修复：replaceActiveProfileContent 是两笔写（profiles + active id），
        // saveProfiles 成功、saveActiveProfileId 抛时**课程已经落盘**——此前只回滚设置，
        // 盘上留下「新课表 + 旧设置」的半套状态，还报成失败（用户重导又来一遍）。
        // 顺序：先恢复课程本体（saveProfiles 会按当前盘上内嵌 settings 合并，随后
        // settings 回滚把 core 键也修正），再恢复设置与节次表；逐条 runCatching，
        // 不让回滚失败遮原始错误。
        runCatching {
            val beforeActive = before.profiles.firstOrNull { it.id == before.activeProfileId }
                ?: before.profiles.firstOrNull()
            repository.replaceActiveProfileContent(
                courses = before.courses,
                tasks = beforeActive?.tasks.orEmpty(),
                exams = beforeActive?.exams.orEmpty(),
            )
        }
        runCatching { repository.updateSettings(before.settings) }
        if (needsExpansion && scheme != null) {
            runCatching { repository.updateTimeScheme(scheme.id, scheme.name, scheme.sections) }
        }
        ApplyResult.Failed(ImportStrings.saveFailed.text)
    }
}
