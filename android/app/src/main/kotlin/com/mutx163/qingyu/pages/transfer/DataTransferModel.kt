package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.core.Course
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

/**
 * 预览弹窗的一个动作。
 *
 * @param mode 落盘模式；null = 取消，或「导入为新课表」这种不走 [TransferApplyMode] 的动作。
 * @param importAsNew true = 这次是「导入为新课表」（新建一份档案，不是写进当前档）。
 *   用独立标记而不是给 [TransferApplyMode] 加枚举值：那个枚举在 LAN / diff 全链路被
 *   `when` 穷举（`LanTransferLogic.modeName` 等），加值会把一行改动扩散到别人域；
 *   这条动作本来就只属于「外部打开备份」一个入口，标记更贴事实。
 */
data class TransferPreviewAction(
    val label: String,
    val mode: TransferApplyMode?,
    val importAsNew: Boolean = false,
)

/** 二维码发送前可选的传输范围。 */
data class QrScopeOption(
    val scope: TransferScope,
    val label: String,
    /** 选它之前要先勾课程（Dart `_qrSendCurrent` 里 selectedCourses/selectedCourse 分支）。 */
    val requiresCourseSelection: Boolean,
)

/** 二维码范围弹窗的一个动作；[scope] 为 null 表示「取消」。 */
data class QrScopeDialogAction(
    val label: String,
    val scope: TransferScope?,
    /** 最后一个动作是主操作（Dart `isPrimary: true`，`data_transfer_screen.dart:730`）。 */
    val isPrimary: Boolean = false,
)

/**
 * 选课弹层里的一个科目组（Dart `provider.courseGroups` 的**展示投影**）。
 *
 * 为什么按科目聚合而不逐条列课：Dart 的注释写明「避免同一科目多次出现逐条列出」，
 * 勾选语义也是**整组**全选/全不选（`data_transfer_screen.dart:797-811`）。
 */
data class TransferCourseGroup(
    val name: String,
    /** 老师名（空串表示没有，行只显示单行标题）。 */
    val teacher: String,
    val courseIds: List<String>,
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
        val activeProfileName = input.activeProfileName ?: TransferStrings.timetableAppName.text
        val semesterLine = input.semesterStartDate?.let {
            TransferStrings.semesterStartBullet.filled("date", formatDate(it))
        } ?: TransferStrings.semesterStartUnsetBullet.text

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
            label = TransferStrings.qrTransferShareWeek.text,
            requiresCourseSelection = false,
        ),
        QrScopeOption(
            scope = TransferScope.SELECTED_COURSES,
            label = TransferStrings.qrTransferShareSelectedCourses.text,
            requiresCourseSelection = true,
        ),
        QrScopeOption(
            scope = TransferScope.TIME_TEMPLATE,
            label = TransferStrings.qrTransferShareTimeTemplate.text,
            requiresCourseSelection = false,
        ),
        QrScopeOption(
            scope = TransferScope.CURRENT_TIMETABLE,
            label = TransferStrings.qrTransferSendCurrent.text,
            requiresCourseSelection = false,
        ),
    )

    /**
     * 二维码范围弹窗的**动作序列**（Dart `_chooseQrScope`：710-734 的按钮顺序）。
     *
     * 5 个动作竖排：取消 → 分享本周课表 → 分享勾选的课程 → 分享时间模板 → 发送当前课表（primary）。
     * 取消是弹窗自己的动作（Dart 里 `Navigator.pop` 返回 null），不属于 [TransferScope]，
     * 所以 [QrScopeDialogAction.scope] 为 null。
     */
    fun qrScopeDialogActions(): List<QrScopeDialogAction> =
        buildList {
            add(QrScopeDialogAction(label = TransferStrings.cancelAction.text, scope = null))
            for (option in qrScopeOptions()) {
                add(
                    QrScopeDialogAction(
                        label = option.label,
                        scope = option.scope,
                        // Dart 把「二维码发送当前课表」标成主操作（源码顺序里它是最后一个）。
                        isPrimary = option.scope == TransferScope.CURRENT_TIMETABLE,
                    ),
                )
            }
        }

    /**
     * 该范围是否要先在选课弹层里勾课（Dart `_qrSendCurrent`：458-465）。
     *
     * Dart 对单数 `selectedCourse` 与复数 `selectedCourses` **同权处理**，走同一个弹层。
     */
    fun requiresCourseSelection(scope: TransferScope): Boolean =
        scope == TransferScope.SELECTED_COURSES || scope == TransferScope.SELECTED_COURSE

    /**
     * 某个科目组当前是否显示为「已勾选」。
     *
     * Dart 的判据是「组里**任一**课程被勾」（`data_transfer_screen.dart:793-795`），
     * 不是「全部」——因为用户可能只勾了同科目的一部分。
     */
    fun isCourseGroupSelected(selected: Set<String>, group: TransferCourseGroup): Boolean =
        group.courseIds.any { it in selected }

    /**
     * 点一下科目组：整组已全选则整组取消，否则整组加入（`data_transfer_screen.dart:797-811`）。
     *
     * 注意「已全选」与「显示为已勾选」是两个不同判据：只勾了一部分时点一下是**补齐**整组，
     * 不是取消（Dart 的 `allSelected = groupIds.every(selected.contains)`）。
     */
    fun toggleCourseGroup(selected: Set<String>, group: TransferCourseGroup): Set<String> {
        if (group.courseIds.isEmpty()) return selected
        val ids = group.courseIds.toSet()
        val allSelected = ids.all { it in selected }
        return if (allSelected) selected - ids else selected + ids
    }

    /**
     * 把课程列表按科目聚合成选课弹层的行（Dart `CourseGroup.buildFrom`：
     * `lib/utils/course_group.dart:24-32`）。
     *
     * 口径三条：① 按 `name` 分组、**保持课程在列表里的出现顺序**；
     * ② 组长（老师名）取**该组第一门课**的老师（`course_group.dart:35`）；
     * ③ 组内 id 即该组全部课程 id——勾一行等于勾这门的全部时段。
     */
    fun courseGroups(courses: List<Course>): List<TransferCourseGroup> {
        val grouped = LinkedHashMap<String, MutableList<Course>>()
        for (course in courses) {
            grouped.getOrPut(course.name) { mutableListOf() }.add(course)
        }
        return grouped.map { (name, groupCourses) ->
            TransferCourseGroup(
                name = name,
                teacher = groupCourses.first().teacher,
                courseIds = groupCourses.map { it.id },
            )
        }
    }

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
        var message = TransferStrings.backupRestoredSuccess.text
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

    /**
     * 单行差异摘要（Dart `formatSummary`：`kind: +a / ~u / -r`）。
     *
     * ⚠️ 这两个函数是**在用的**：[DataTransferImportLogic.previewMessage] 拼预览正文
     * 就是靠它们（Dart 的正文里 `merge:` / `overwrite:` 两段各是一串这样的行）。
     * 2026-10-29 二轮清理时曾误以为它们只被已删的 `previewContent` 用着——
     * 删掉会直接编不过，别再来一次。
     */
    fun diffSummaryLine(summary: TransferDiffSummary): String =
        "${summary.kind}: +${summary.added} / ~${summary.updated} / -${summary.removed}"

    /** 多类实体摘要逐行拼接。 */
    fun diffSummary(lines: List<TransferDiffSummary>): String =
        lines.joinToString("\n") { diffSummaryLine(it) }

    /**
     * 「导入为新课表」完成的提示（Dart `main.dart:1584-1593`（工作区））：
     * 基础句是 `createdNewTimetableAfterImport`，只追加「格式损坏已跳过」后缀。
     *
     * **不带**「超出当前作息范围」后缀：发布版 as-new 不算这一段（新档的节次表来自包本身）。
     */
    fun createdNotice(droppedCount: Int): TransferRestoredNotice {
        var message = TransferStrings.createdNewTimetableAfterImport.text
        if (droppedCount > 0) {
            message += TransferStrings.importPartialSkippedSuffix
                .filled("count", droppedCount.toString())
        }
        return TransferRestoredNotice(message = message, isWarning = droppedCount > 0)
    }

    /**
     * 预览弹窗的动作（Dart `transfer_preview_dialog.dart:41-53`）：取消 / 合并 / 覆盖
     * （覆盖为主操作）。
     *
     * @param canMerge false ⇒ 不显示「合并更改」。只给全量备份用：Kotlin 侧没有
     *   逐实体合并服务（[DataTransferApplyLogic.rejectionCode] 明确拒绝），把这条
     *   点了必然失败的按钮摆出来只会让用户看到一句「发生未知错误」。
     * @param canImportAsNew true ⇒ 追加「导入为新课表」。**只在「外部打开备份文件」**
     *   这条入口给（发布版那条三动作弹框就是它，`main.dart:1490-1522`（工作区；发布版 `:1401-1422`））；文件选择 /
     *   二维码 / 局域网用的预览弹框在发布版里没有这条，保持原样。
     *   全量备份不给（[DataTransferApplyLogic.importAsNewRejectionCode] 会拒，UI 先隐藏）。
     */
    fun previewActions(
        canMerge: Boolean = true,
        canImportAsNew: Boolean = false,
    ): List<TransferPreviewAction> = buildList {
        add(TransferPreviewAction(TransferStrings.cancelAction.text, null))
        if (canMerge) {
            add(TransferPreviewAction(TransferStrings.selectImportModeMerge.text, TransferApplyMode.MERGE))
        }
        add(
            TransferPreviewAction(
                TransferStrings.replaceCurrentTimetable.text,
                TransferApplyMode.OVERWRITE,
            ),
        )
        if (canImportAsNew) {
            add(
                TransferPreviewAction(
                    label = TransferStrings.importAsNewTimetable.text,
                    mode = null,
                    importAsNew = true,
                ),
            )
        }
    }
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
    /** 选课弹层要列的科目组（Dart `provider.courseGroups`；空 = 弹层显示空态）。 */
    val courseGroups: List<TransferCourseGroup> = emptyList(),
) {
    val overviewRows: List<TransferOverviewRow>
        get() = DataTransferLogic.overviewRows(overview)

}
