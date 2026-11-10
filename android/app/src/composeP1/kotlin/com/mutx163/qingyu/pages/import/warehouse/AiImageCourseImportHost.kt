package com.mutx163.qingyu.pages.import.warehouse

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.widget.Toast
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
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
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.core.WeekCalculator
import com.mutx163.qingyu.pages.import.ImportCapacityDialog
import com.mutx163.qingyu.pages.import.ImportFlowModel
import com.mutx163.qingyu.pages.import.ImportPreviewChoice
import com.mutx163.qingyu.pages.import.ImportPreviewDialog
import com.mutx163.qingyu.pages.import.ImportRandomColorPrefs
import com.mutx163.qingyu.pages.import.ImportRandomColorStore
import com.mutx163.qingyu.pages.import.ImportSharedModel
import com.mutx163.qingyu.pages.import.ImportShellBridge
import com.mutx163.qingyu.pages.import.ImportWeekAlignment
import com.mutx163.qingyu.platform.PrefsKeyValueStore
import java.time.LocalDateTime
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import top.yukonga.miuix.kmp.basic.Text
import com.mutx163.qingyu.components.QingyuSheet
import top.yukonga.miuix.kmp.theme.MiuixTheme

private const val LOG_TAG = "AiImageImportHost"

/**
 * AI 识图导入页的**真宿主**（`g2.aiImageImport`）。
 *
 * ## 每个按钮的落点
 *
 * | 控件 | 真落点 |
 * |---|---|
 * | 复制提示词 | 系统剪贴板（[AI_IMPORT_SYSTEM_PROMPT]）+ Toast「提示词已复制」 |
 * | 提示词弹层 | 共享弹层套件 `QingyuSheet`，正文可滚动 |
 * | 粘贴 | 读系统剪贴板；空剪贴板给「剪贴板里没有可用文本」，不假装粘到了 |
 * | 确认导入 | 预览确认（开学日 / 第 1 周对应第几周 / 覆盖还是更新）→ 节次不够先问 → [AiImageImportApply] 真落盘 |
 * | 导入成功 | 与 Dart `Navigator.pop(true)` 同义：调 [ImportShellBridge.markImported] 后返回（入口页据此自关） |
 *
 * ## 写的是哪个仓储、哪个方法
 *
 * 课程：`TimetableRepository.replaceActiveProfileContent`（见 [AiImageImportApply]）；
 * 开学日：`TimetableRepository.updateSettings`；
 * 节次不够且用户点「自动补齐」：有主模板写模板，否则写设置。
 * 任何一步失败：Toast「保存失败」，设置与节次回滚到导入前。
 *
 * ## 诚实边界
 *
 * - 解析仍用现有宽松解析器（`parseAiImageImportJson`）：它不强制 schema/字段类型，
 *   与 Dart 严格解析有差异；本宿主只保证「能落盘的确实落盘、落不了的说清少了几门」。
 * - 提示词正文取 [AI_IMPORT_SYSTEM_PROMPT]；它与 Dart `AiCourseImportService.prompt`
 *   的完整版相比更短（现有模型文件不在本刀写作用域）。想逐字一致需要另开一单。
 * - 真机未对照：本刀只证明 JVM 单测与代码可读；用户需在 `PagesShellActivity` 里
 *   贴一份 JSON 点「确认导入」验收。
 */
@Composable
fun AiImageCourseImportHost(
    repository: TimetableRepository,
    bridge: ImportShellBridge,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val colorStore = remember(context) { ImportRandomColorStore(PrefsKeyValueStore(context)) }

    var colorPrefs by remember { mutableStateOf(ImportRandomColorPrefs()) }
    var isImporting by remember { mutableStateOf(false) }
    var pendingPreview by remember { mutableStateOf<AiCourseImportParseResult?>(null) }
    var capacity by remember { mutableStateOf<AiCapacityRequest?>(null) }
    var showPromptSheet by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        colorPrefs = withContext(Dispatchers.IO) { colorStore.snapshot() }
    }

    fun toast(message: String) {
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
    }

    fun runImport(
        result: AiCourseImportParseResult,
        choice: ImportPreviewChoice,
        expandSections: Boolean,
    ) {
        if (isImporting) return
        isImporting = true
        val prefs = colorPrefs
        scope.launch {
            val outcome = withContext(Dispatchers.IO) {
                val snapshot = repository.snapshot
                val currentSections = AiImageImportApply.activeSections(snapshot)
                val required = AiImageImportCourseModel.requiredSectionCount(result.courses)
                val sections = if (expandSections) {
                    AiImageImportApply.expandedSections(currentSections, required)
                } else {
                    currentSections
                }
                val conversion = AiImageImportCourseModel.convert(
                    courses = result.courses,
                    sections = sections,
                    semesterWeekCount = snapshot.settings.semesterWeekCount,
                )
                val aligned = ImportWeekAlignment.shiftCoursesToSemesterWeeks(
                    courses = conversion.courses,
                    firstCourseWeek = choice.firstCourseWeek,
                )
                val colored = ImportFlowModel.coursesWithOptionalRandomColors(aligned, prefs)
                val applied = AiImageImportApply.apply(
                    repository = repository,
                    request = AiImageImportApply.Request(
                        courses = colored,
                        semesterStartDate = choice.semesterStartDate,
                        replaceExisting = choice.replaceExisting,
                        preserveLocalColors = ImportFlowModel.shouldPreserveLocalColors(
                            replaceExisting = choice.replaceExisting,
                            randomColorsEnabled = prefs.enabled,
                        ),
                    ),
                    expandSections = expandSections,
                )
                AiImportOutcome(
                    applied = applied,
                    message = buildOutcomeMessage(
                        applied = applied,
                        warningCount = result.warnings.size,
                        parsedCount = result.courses.size,
                        droppedCount = conversion.droppedCount,
                    ),
                )
            }
            isImporting = false
            toast(outcome.message)
            val applied = outcome.applied
            if (applied is AiImageImportApply.Result.Done && applied.importedCount > 0) {
                bridge.markImported()
                onBack()
            }
        }
    }

    AiImageCourseImportPage(
        onBack = onBack,
        isImporting = isImporting,
        onCopyPrompt = {
            copyToClipboard(context, PROMPT_CLIP_LABEL, AI_IMPORT_SYSTEM_PROMPT)
            toast(WarehouseStrings.promptCopiedHint.text)
        },
        onShowPromptSheet = { showPromptSheet = true },
        onPasteFromClipboard = {
            val text = readClipboardText(context)?.trim().orEmpty()
            if (text.isEmpty()) {
                toast(WarehouseStrings.clipboardNoText.text)
            }
            text
        },
        onConfirmImport = { result ->
            if (!isImporting && result.isValid) {
                pendingPreview = result
            }
        },
    )

    val previewResult = pendingPreview
    val snapshot = repository.snapshot
    ImportPreviewDialog(
        show = previewResult != null && capacity == null,
        importLabel = WarehouseStrings.importAiResultTitle.text,
        courseCount = previewResult?.courses?.size ?: 0,
        // AI 解析拿不到文件里的最早上课日期：预填「设置里的开学日」，没有就取本周周一。
        semesterStartDate = snapshot.settings.semesterStartDate
            ?: WeekCalculator.startOfWeek(LocalDateTime.now()),
        initialFirstCourseWeek = 1,
        lastAllowedWeek = snapshot.settings.semesterWeekCount,
        hasExistingCourses = snapshot.courses.isNotEmpty(),
        onCancel = { pendingPreview = null },
        onConfirm = { choice ->
            val result = pendingPreview
            if (result != null) {
                val currentSections = AiImageImportApply.activeSections(repository.snapshot)
                val required = AiImageImportCourseModel.requiredSectionCount(result.courses)
                if (AiImageImportApply.needsExpansion(currentSections, required)) {
                    capacity = AiCapacityRequest(
                        result = result,
                        choice = choice,
                        currentSectionCount = currentSections.size,
                        requiredSectionCount = required,
                    )
                } else {
                    pendingPreview = null
                    runImport(result, choice, expandSections = false)
                }
            }
        },
    )

    val pendingCapacity = capacity
    ImportCapacityDialog(
        show = pendingCapacity != null,
        currentSectionCount = pendingCapacity?.currentSectionCount ?: 0,
        requiredSectionCount = pendingCapacity?.requiredSectionCount ?: 0,
        onCancel = { capacity = null },
        onAutoFill = {
            val current = capacity
            capacity = null
            if (current != null) {
                pendingPreview = null
                runImport(current.result, current.choice, expandSections = true)
            }
        },
    )

    // 走共享弹层套件（统一 16dp 侧边距 + 底部手势区让位），不直接调官方 Overlay。
    QingyuSheet(
        show = showPromptSheet,
        title = WarehouseStrings.aiPromptSheetTitle.text,
        onDismissRequest = { showPromptSheet = false },
        // 内容根自己带 16dp；框架侧横向归零 ⇒ 单边仍是 16，不再叠成 32。
        // 标题行没有 start/end action，归零不影响标题。
        contentPadsHorizontally = true,
        // 正文里是 QingyuPageList（LazyColumn）：不传 contentScrolls 时套件在外面再套
        // 一层 verticalScroll，两个竖向滚动容器嵌套抢手势；改为内容自管滚动，
        // 底部让位按套件契约用末尾的 Spacer(bottomInset) 落实。
        contentScrolls = true,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
        ) {
            Text(
                text = WarehouseStrings.aiPromptSheetSubtitle.text,
                style = MiuixTheme.textStyles.body2,
                color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                lineHeight = 20.sp,
            )
            Spacer(modifier = Modifier.height(12.dp))
            // 提示词较长：用共享列表（内含官方滚动三件套与滚动条）承载，不自己拼
            // Column + verticalScroll（那会丢惰性组合，也不满足页面样式守卫）。
            QingyuPageList(
                innerPadding = PaddingValues(0.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(320.dp),
                contentPadding = PaddingValues(vertical = 4.dp),
            ) {
                item(key = "prompt") {
                    Text(
                        text = AI_IMPORT_SYSTEM_PROMPT.trim(),
                        style = MiuixTheme.textStyles.body2,
                        lineHeight = 20.sp,
                    )
                }
            }
        }
        Spacer(modifier = Modifier.height(bottomInset))
    }
}

private const val PROMPT_CLIP_LABEL = "ai-import-prompt"

private data class AiCapacityRequest(
    val result: AiCourseImportParseResult,
    val choice: ImportPreviewChoice,
    val currentSectionCount: Int,
    val requiredSectionCount: Int,
)

private data class AiImportOutcome(
    val applied: AiImageImportApply.Result,
    val message: String,
)

private fun buildOutcomeMessage(
    applied: AiImageImportApply.Result,
    warningCount: Int,
    parsedCount: Int,
    droppedCount: Int,
): String {
    if (applied !is AiImageImportApply.Result.Done) {
        return WarehouseStrings.saveFailed.text
    }
    val base = ImportSharedModel.buildImportResultMessage(
        importedCount = applied.importedCount,
        replaceExisting = applied.replaceExisting,
        warningCount = warningCount,
    )
    if (droppedCount <= 0) return base
    val dropped = WarehouseStrings.importCourseRecordsDropped.filled(
        "imported" to parsedCount.toString(),
        "dropped" to droppedCount.toString(),
    )
    return "$base $dropped"
}

private fun copyToClipboard(context: Context, label: String, text: String) {
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager ?: return
    clipboard.setPrimaryClip(ClipData.newPlainText(label, text))
}

private fun readClipboardText(context: Context): String? {
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager ?: return null
    val clip = clipboard.primaryClip ?: return null
    if (clip.itemCount <= 0) return null
    return clip.getItemAt(0).coerceToText(context)?.toString()
}
