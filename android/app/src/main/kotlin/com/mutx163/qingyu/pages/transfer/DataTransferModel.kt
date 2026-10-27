package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.share.TransferApplyMode
import com.mutx163.qingyu.share.TransferScope
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * 数据备份与迁移页模型层（移植自 `lib/screens/data_transfer_screen.dart` 与
 * `lib/screens/transfer_preview_dialog.dart` 的纯逻辑部分）。
 *
 * **移植边界**：打包/解包、文件读写、分享面板、扫码与 socket 都是平台能力或已迁服务，
 * 不在本文件；这里只管「概览怎么拆行、文件名怎么拼、二维码 scope 有哪些、
 * 导入结果提示怎么拼、预览弹窗正文长什么样」。真实相机与 socket **不在此批**。
 *
 * 全部纯 Kotlin（无 Compose / Android 依赖），JVM 单测可直接跑。
 */

/** 概览区需要的当前数据快照。 */
data class TransferOverviewInput(
    val courseCount: Int,
    val activeProfileName: String?,
    val profileCount: Int,
    val timeSchemeCount: Int,
    val currentWeek: Int,
    val semesterStartDate: LocalDate?,
)

/** 概览的一行：左侧标签 + 右侧取值（Dart 把整句按冒号拆成两栏显示）。 */
data class TransferOverviewRow(val label: String, val value: String)

/** 单类实体的差异计数（Dart `TransferEntityDiff` 的展示字段）。 */
data class TransferDiffSummary(
    val kind: String,
    val added: Int,
    val updated: Int,
    val removed: Int,
)

/** 导入预览弹窗的标题与正文。 */
data class TransferPreviewContent(val title: String, val message: String)

/** 预览弹窗的一个动作（[mode] 为 null 表示取消）。 */
data class TransferPreviewAction(val label: String, val mode: TransferApplyMode?)

/** 二维码发送前可选的传输范围。 */
data class QrScopeOption(
    val scope: TransferScope,
    val label: String,
    /** 选它之前要先勾课程（Dart `_qrSendCurrent` 里 selectedCourses/selectedCourse 分支）。 */
    val requiresCourseSelection: Boolean,
)

/** 导入完成后的提示（[isWarning] 为真时用警告样式）。 */
data class TransferRestoredNotice(val message: String, val isWarning: Boolean)

object DataTransferLogic {

    /** 备份文件后缀（Dart `DataTransferService.fileExtension`）。 */
    const val FILE_EXTENSION = "mikcb"

    const val FULL_BACKUP_PREFIX = "mikcb-full-backup"
    const val BACKUP_PREFIX = "mikcb-backup"
    const val TIME_SCHEME_PREFIX = "mikcb-timescheme"

    /**
     * 概览整句拆成「标签 / 取值」（Dart `_splitOverviewLabelValue`：200-218）。
     *
     * 先找全角「：」；没有再看半角「: 」（冒号+空格）；都没有时标签为空、整句当取值。
     * 取值两端 trim。
     */
    fun splitOverviewLabelValue(text: String): Pair<String, String> {
        val fullWidth = text.indexOf('：')
        if (fullWidth != -1) {
            return text.substring(0, fullWidth) to text.substring(fullWidth + 1).trim()
        }
        val halfWidth = text.indexOf(": ")
        if (halfWidth != -1) {
            return text.substring(0, halfWidth) to text.substring(halfWidth + 2).trim()
        }
        return "" to text
    }

    /**
     * 概览七行（Dart `_buildOverviewRow` 的调用序列：158-191）。
     *
     * 文案顺序沿用 Dart：课程数量 / 当前课表 / 全部课表 / 时间模板 / 当前周 / 开学日期 / 文件后缀。
     */
    fun overviewRows(input: TransferOverviewInput): List<TransferOverviewRow> {
        val activeProfileName = input.activeProfileName ?: TransferStrings.timetableAppName.zh
        val semesterLine = input.semesterStartDate?.let {
            TransferStrings.semesterStartBullet.filled("date", formatDate(it))
        } ?: TransferStrings.semesterStartUnsetBullet.zh

        val texts = listOf(
            TransferStrings.courseCountBullet.filled("count", input.courseCount.toString()),
            TransferStrings.currentTimetableBullet.filled("name", activeProfileName),
            TransferStrings.allTimetablesBullet.filled("count", input.profileCount.toString()),
            TransferStrings.timeSchemeCountBullet.filled("count", input.timeSchemeCount.toString()),
            TransferStrings.currentWeekBullet.filled("week", input.currentWeek.toString()),
            semesterLine,
            TransferStrings.fileExtensionBullet.filled("extension", FILE_EXTENSION),
        )
        return texts.map { text ->
            val (label, value) = splitOverviewLabelValue(text)
            TransferOverviewRow(label = label, value = value)
        }
    }

    /** 概览里的日期（Dart `_formatDate`：835-837，`yyyy-MM-dd`，月日补零）。 */
    fun formatDate(date: LocalDate): String {
        val month = date.monthValue.toString().padStart(2, '0')
        val day = date.dayOfMonth.toString().padStart(2, '0')
        return "${date.year}-$month-$day"
    }

    /**
     * 分享文件名前缀（Dart `_shareTransferPackage`：290-317）。
     *
     * 时间模板有专属前缀（把作息单独发给别人）；整包备份与当前课表分开命名。
     */
    fun shareFilePrefix(scope: TransferScope, isFullBackup: Boolean): String = when {
        scope == TransferScope.TIME_TEMPLATE -> TIME_SCHEME_PREFIX
        isFullBackup -> FULL_BACKUP_PREFIX
        else -> BACKUP_PREFIX
    }

    /** 分享文件名：`前缀-yyyyMMdd-HHmm.mikcb`（Dart 同处）。 */
    fun buildShareFileName(prefix: String, now: LocalDateTime): String {
        val y = now.year.toString().padStart(4, '0')
        val mo = now.monthValue.toString().padStart(2, '0')
        val d = now.dayOfMonth.toString().padStart(2, '0')
        val h = now.hour.toString().padStart(2, '0')
        val mi = now.minute.toString().padStart(2, '0')
        return "$prefix-$y$mo$d-$h$mi.$FILE_EXTENSION"
    }

    /**
     * 二维码发送的范围选项（Dart `_chooseQrScope`：696-736 的动作顺序，
     * 取消与「发送当前课表」的 primary 属性由渲染层决定，这里只列可选范围）。
     */
    fun qrScopeOptions(): List<QrScopeOption> = listOf(
        QrScopeOption(
            scope = TransferScope.WEEK_TIMETABLE,
            label = TransferStrings.qrTransferShareWeek.zh,
            requiresCourseSelection = false,
        ),
        QrScopeOption(
            scope = TransferScope.SELECTED_COURSES,
            label = TransferStrings.qrTransferShareSelectedCourses.zh,
            requiresCourseSelection = true,
        ),
        QrScopeOption(
            scope = TransferScope.TIME_TEMPLATE,
            label = TransferStrings.qrTransferShareTimeTemplate.zh,
            requiresCourseSelection = false,
        ),
        QrScopeOption(
            scope = TransferScope.CURRENT_TIMETABLE,
            label = TransferStrings.qrTransferSendCurrent.zh,
            requiresCourseSelection = false,
        ),
    )

    /**
     * 导入完成提示（Dart `_previewAndApply`：640-661）。
     *
     * 基础句 + 「超出当前作息范围」+「格式损坏已跳过」两个可选后缀，
     * 任一个出现就降级成警告样式。
     */
    fun restoredNotice(
        beyondSchemeCount: Int,
        sectionCount: Int,
        droppedCount: Int,
    ): TransferRestoredNotice {
        var message = TransferStrings.backupRestoredSuccess.zh
        if (beyondSchemeCount > 0) {
            message += TransferStrings.coursesBeyondSchemeExtraSuffix.filled(
                "count" to beyondSchemeCount.toString(),
                "sections" to sectionCount.toString(),
            )
        }
        if (droppedCount > 0) {
            message += TransferStrings.importPartialSkippedSuffix
                .filled("count", droppedCount.toString())
        }
        return TransferRestoredNotice(
            message = message,
            isWarning = beyondSchemeCount > 0 || droppedCount > 0,
        )
    }

    /** 单行差异摘要（Dart `formatSummary`：`kind: +a / ~u / -r`）。 */
    fun diffSummaryLine(summary: TransferDiffSummary): String =
        "${summary.kind}: +${summary.added} / ~${summary.updated} / -${summary.removed}"

    /** 多类实体摘要逐行拼接。 */
    fun diffSummary(lines: List<TransferDiffSummary>): String =
        lines.joinToString("\n") { diffSummaryLine(it) }

    /**
     * 导入预览弹窗正文（Dart `showTransferPreviewDialog`：18-34）。
     *
     * 固定四行（说明句 / channel / scope / transferId），再按是否有 merge 备选
     * 决定挂一份还是两份差异摘要。块之间用空行分隔。
     */
    fun previewContent(
        channel: String,
        scope: String,
        transferId: String,
        overwrite: List<TransferDiffSummary>,
        merge: List<TransferDiffSummary>? = null,
    ): TransferPreviewContent {
        val blocks = mutableListOf(
            TransferStrings.selectImportModeMessage.zh,
            "channel=$channel",
            "scope=$scope",
            "transferId=$transferId",
        )
        if (merge != null) {
            blocks += "merge:\n${diffSummary(merge)}"
            blocks += "overwrite:\n${diffSummary(overwrite)}"
        } else {
            blocks += diffSummary(overwrite)
        }
        return TransferPreviewContent(
            title = TransferStrings.selectImportModeTitle.zh,
            message = blocks.joinToString("\n\n"),
        )
    }

    /** 预览弹窗的三个动作（Dart 41-53）：取消 / 合并 / 覆盖（覆盖为主操作）。 */
    fun previewActions(): List<TransferPreviewAction> = listOf(
        TransferPreviewAction(TransferStrings.cancelAction.zh, null),
        TransferPreviewAction(TransferStrings.selectImportModeMerge.zh, TransferApplyMode.MERGE),
        TransferPreviewAction(
            TransferStrings.replaceCurrentTimetable.zh,
            TransferApplyMode.OVERWRITE,
        ),
    )
}

/**
 * 数据备份与迁移页视图状态（渲染层只读它，不做业务计算）。
 */
data class DataTransferViewState(
    val overview: TransferOverviewInput,
    val timeSchemeCount: Int = 0,
    val canExportTimeTemplate: Boolean = timeSchemeCount > 0,
    val isExporting: Boolean = false,
    val isImporting: Boolean = false,
    /** 当前生效课表名（没有课表时 null，导出文案兜底用）。 */
    val activeProfileName: String? = null,
) {
    val overviewRows: List<TransferOverviewRow>
        get() = DataTransferLogic.overviewRows(overview)

    /** 导出当前课表的分享主题（Dart 273-278：有课表名时带名字）。 */
    val profileShareSubject: String
        get() = activeProfileName?.let {
            TransferStrings.dataTransferProfileShareSubjectNamed.filled("profileName", it)
        } ?: TransferStrings.dataTransferProfileShareSubject.zh

    /** 导出按钮忙碌时的文案（Dart 62-64：`完整导出...`）。 */
    val exportCurrentLabel: String
        get() = if (isExporting) {
            "${TransferStrings.fullExportTitle.zh}..."
        } else {
            TransferStrings.exportCurrentTimetable.zh
        }

    val importLabel: String
        get() = if (isImporting) {
            "${TransferStrings.fullImportTitle.zh}..."
        } else {
            TransferStrings.chooseFileAndImport.zh
        }
}
