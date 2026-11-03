package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.DartFormatException
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.LocationTimeGroup
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.ScheduleDateRule
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.share.TransferChannel
import com.mutx163.qingyu.share.TransferScope
import com.mutx163.qingyu.sync.validateTransferPackageJson

/**
 * 数据备份与迁移页的**导入侧**模型层：解析包 → 预览弹窗正文。
 *
 * ## 两段各自的判据源
 *
 * | 本文件 | Dart 出处 |
 * | --- | --- |
 * | [DataTransferImportLogic.parse] | `TransferPackage.decode` / `fromJson`（`lib/services/transfer_package.dart`），外加 `validateJson` 那道前置门 |
 * | [DataTransferImportLogic.previewMessage] | `showTransferPreviewDialog`（`lib/screens/transfer_preview_dialog.dart:18-34`） |
 *
 * ## 差分不在这里了（2026-10-30 · F16）
 *
 * 差异计算搬到了 [DataTransferDiffLogic]：它比的是**仓储真内容 vs 入包模型**
 * （按 scope 选基线、按 (档案 id, 实体 id) 配对、removed 按 mode + scope 判据）。
 * 原来那个「比对两份包文本」的 `diffSummaries` 连同它的三个已知差异（不做模型归一化 /
 * removed 恒统计 / 基线固定按 `current_timetable` 打包）一并在同一次改动里删掉——
 * 同一个数字留两份实现，早晚有一份被误用。
 *
 * ## 为什么 parse 先校验再解析
 *
 * Dart 的 `TransferPackage.fromJson` 是一道**分层的门**：信封 → 版本 → 八张列表在场
 * → 标量 → settings → 逐条字段 → 唯一 id → scope 语义。这套门已经逐字移植在
 * `sync/TransferPackageValidation.kt` 的 [validateTransferPackageJson] 里（含错误码
 * 顺序）。本文件不再重写一遍，而是「先过门、再过模型」：
 *
 * ```
 * validateTransferPackageJson(content)  → 不合法 ⇒ Invalid(首个错误码)
 *          ↓ 合法
 * 各模型 fromJson                         → 抛错 ⇒ Invalid(<码>)，绝不漏给界面
 * ```
 *
 * **任何一步抛错都转成 [TransferImportParseResult.Invalid]**。界面拿到的永远是
 * 「一个码」，而不是一个把 Compose 组合树炸掉的异常。
 *
 * ## 与 Dart 的已知差异（逐条一行，都有理由）
 *
 * 1. `parse` 的 `Invalid` 码在模型层抛错时未必与 Dart 逐字相同：Dart 在 `_parseList`
 *    里把模型 parse 异常包成 `transfer_${kind}_invalid`，本实现按校验器已过的前提
 *    直接调模型 `fromJson`，异常消息是形状码就原样透出，否则落到
 *    `transfer_package_parse_failed`（本仓新增码，界面上会落到「发生未知错误」）。
 * 2. **多缺陷包的首个错误码可能指向另一实体**：Dart 是逐实体「先查字段 → 建模型 → 下一条」，
 *    前面实体的模型错误先抛；本实现是整包结构门全过（含全部实体的字段/唯一 id 检查）
 *    后才统一建模型，因此后面实体的缺字段码会先返回。
 *    包例：`courses[0]` 的 `sessionNotes.text` 是数字（Dart 抛 TypeError →
 *    `transfer_course_invalid`；本仓模型也拒绝，但映射成 `transfer_package_parse_failed`）
 *    且 `exams[0]` 缺 `name` ⇒ Dart 报 `transfer_course_invalid`，本仓报
 *    `transfer_exam_name_required`。
 *    用例钉在 `DataTransferImportLogicTest.多缺陷包的首个错误码与 Dart 不一致`。
 */

/**
 * 包的自述信息（预览与「导入完成」提示只读这一小块）。
 */
data class TransferImportPackageInfo(
    val scope: TransferScope,
    val channel: TransferChannel,
    val packageId: String,
    val isFullBackup: Boolean,
    val profileName: String?,
    val currentWeek: Int?,
    /** 顶层课程数 + 各档案课程数（全量包只有后者非零）。 */
    val courseCount: Int,
    val profileCount: Int,
    /**
     * 旧格式兼容解析时逐条跳过的坏条目（键 → 条数）。
     *
     * 当前信封解析恒为空；只有 [DataTransferLegacyBackupLogic] 会产出非空。
     * Dart 用 `AppDataBackup.droppedCounts` 让导入完成提示如实报「跳过了 N 条」，
     * 这里同样交给 [TransferRestoredNotice.droppedCount]（旧宿主把它硬编码成 0）。
     */
    val droppedCounts: Map<String, Int> = emptyMap(),
) {
    val droppedTotal: Int get() = droppedCounts.values.sum()
}

/**
 * 解析出来、**尚未落盘**的导入计划。
 *
 * [profiles] 非空 = 全量备份，宿主应整份替换档案表；
 * 空列表 = 单课表包，按 [courses] / [settings] / … 落进当前档案。
 * 本对象只描述「盘上应该变成什么」，**不落盘**：落盘入口是仓储/服务的事。
 */
data class TransferImportPlan(
    /** 非空 = 全量备份，按整份档案表落盘；空列表 = 单课表包。 */
    val profiles: List<TimetableProfile>,
    val activeProfileId: String?,
    val courses: List<Course>,
    val settings: TimetableSettings?,
    val currentWeek: Int?,
    val timeSchemes: List<TimeScheme>,
    val tasks: List<CourseTask>,
    val exams: List<Exam>,
    val scheduleItems: List<ScheduleItem>,
    val scheduleDateRules: List<ScheduleDateRule>,
    /**
     * 地点作息分组（顶层 key `locationTimeGroups`）。
     *
     * 2026-10-30 修：导出侧原先恒写空列表，导入侧也不解析 ⇒ 这条通道**双向**丢数据。
     * 现在两侧都通：导出按 `snapshot.locationTimeGroups` 写，这里按 id 解析，
     * 宿主再经 `repository.updateLocationTimeGroups` 落盘。
     */
    val locationTimeGroups: List<LocationTimeGroup> = emptyList(),
)

sealed interface TransferImportParseResult {
    data class Valid(
        val info: TransferImportPackageInfo,
        val plan: TransferImportPlan,
    ) : TransferImportParseResult

    /** = [validateTransferPackageJson] 的首个错误码（或模型解析失败码）。 */
    data class Invalid(val code: String) : TransferImportParseResult
}

object DataTransferImportLogic {

    /**
     * 解析一个包文本。
     *
     * 全量包（`backupType == "full"` 或 `profiles` 非空）解析成 [TransferImportPlan.profiles]；
     * 单课表包解析顶层 `courses` / `settings` / `currentWeek` / `tasks` / `exams` / …
     * （Dart `TransferPackage` 就是这结构）。顶层列表在全量包里也照常解析——正常产出的
     * 全量包把它们留空，但保留这条通道才能同时容纳「档案 + 顶层补充」的历史包。
     */
    fun parse(content: String): TransferImportParseResult {
        val validation = validateTransferPackageJson(content)
        if (!validation.isValid) {
            return TransferImportParseResult.Invalid(validation.errors.first())
        }
        val root = decodeRoot(content)
            ?: return TransferImportParseResult.Invalid("transfer_package_root_invalid")
        return try {
            val scope = TransferScope.fromValue(root["scope"])
            val channel = TransferChannel.fromValue(root["channel"])
            val packageId = (root["packageId"] as? String).orEmpty().trim()
            val profiles = mapList("profile", root["profiles"]) { TimetableProfile.fromJson(it) }
            // Dart `fromJson`：`backupType: full` 与「带档案」都算全量。
            val isFullBackup = root["backupType"] == "full" || profiles.isNotEmpty()
            val courses = mapList("course", root["courses"]) { Course.fromJson(it) }
            val tasks = mapList("task", root["tasks"]) { CourseTask.fromJson(it) }
            val exams = mapList("exam", root["exams"]) { Exam.fromJson(it) }
            val scheduleItems =
                mapList("schedule_item", root["scheduleItems"]) { ScheduleItem.fromJson(it) }
            val timeSchemes =
                mapList("time_scheme", root["timeSchemes"]) { TimeScheme.fromJson(it) }
            val scheduleDateRules =
                mapList("time_rule", root["scheduleDateRules"]) { ScheduleDateRule.fromJson(it) }
            // 地点作息分组：与 Dart `FullAppDataBackup.locationTimeGroups` 同键名。
            // 2026-10-30 修：不解析 = 导入侧静默丢弃（审核 P0：导出导入双向全丢）。
            val locationTimeGroups =
                mapList("location_time_group", root["locationTimeGroups"]) {
                    LocationTimeGroup.fromJson(it)
                }
            val settings = asJsonMap(root["settings"])?.let {
                TimetableSettings.fromJson(it)
            }
            val currentWeek = (root["currentWeek"] as? Number)?.toInt()
            val plan = TransferImportPlan(
                profiles = profiles,
                activeProfileId = root["activeProfileId"] as? String,
                courses = courses,
                settings = settings,
                currentWeek = currentWeek,
                timeSchemes = timeSchemes,
                tasks = tasks,
                exams = exams,
                scheduleItems = scheduleItems,
                scheduleDateRules = scheduleDateRules,
                locationTimeGroups = locationTimeGroups,
            )
            val info = TransferImportPackageInfo(
                scope = scope,
                channel = channel,
                packageId = packageId,
                isFullBackup = isFullBackup,
                profileName = root["profileName"] as? String,
                currentWeek = currentWeek,
                courseCount = courses.size + profiles.sumOf { it.courses.size },
                profileCount = profiles.size,
            )
            TransferImportParseResult.Valid(info, plan)
        } catch (error: Exception) {
            TransferImportParseResult.Invalid(codeOf(error))
        }
    }

    /**
     * 预览弹窗正文，逐字对齐 `transfer_preview_dialog.dart:18-34`。
     *
     * 段间一个空行（`\n\n`），段内一行一条（`\n`）：
     *
     * ```
     * selectImportModeMessage
     *
     * channel=file
     * scope=current_timetable
     * transferId=transfer-…
     *
     * merge:\n<8 行>
     *
     * overwrite:\n<8 行>
     * ```
     *
     * 无 [merge] 时最后一段整段就是 overwrite 的汇总（没有 `merge:` / `overwrite:`
     * 前缀）——这是 Dart 的写法，用户在两台手机间逐字对数字，不能改成更好看的版式。
     */
    fun previewMessage(
        channel: TransferChannel,
        scope: TransferScope,
        packageId: String,
        overwrite: List<TransferDiffSummary>,
        merge: List<TransferDiffSummary>? = null,
    ): String {
        val blocks = mutableListOf(
            TransferStrings.selectImportModeMessage.zh,
            "channel=${channel.value}",
            "scope=${scope.value}",
            "transferId=$packageId",
        )
        if (merge != null) {
            blocks += "merge:\n" + DataTransferLogic.diffSummary(merge)
            blocks += "overwrite:\n" + DataTransferLogic.diffSummary(overwrite)
        } else {
            blocks += DataTransferLogic.diffSummary(overwrite)
        }
        return blocks.joinToString("\n\n")
    }

    // ---------- 内部：解析辅助 ----------

    private fun decodeRoot(content: String): Map<String, Any?>? = asJsonMap(
        try {
            MiniJson.parse(content)
        } catch (_: Exception) {
            null
        },
    )

    /** `MiniJson` 产出的对象键恒为 String，这一处集中做一次强转。 */
    @Suppress("UNCHECKED_CAST")
    private fun asJsonMap(raw: Any?): Map<String, Any?>? = raw as? Map<String, Any?>

    /**
     * `_parseList` 的模型段：逐条 `fromJson`。
     *
     * 元素不是对象时抛 `transfer_${kind}_invalid`——与 Dart 同码；正常情况下这道门
     * 已被 [validateTransferPackageJson] 拦在前面，这里只是不变量兜底。
     */
    private inline fun <T> mapList(
        kind: String,
        raw: Any?,
        parse: (Map<String, Any?>) -> T,
    ): List<T> {
        val list = raw as? List<*> ?: return emptyList()
        val out = ArrayList<T>(list.size)
        for (item in list) {
            @Suppress("UNCHECKED_CAST")
            val map = item as? Map<String, Any?>
                ?: throw DartFormatException("transfer_${kind}_invalid")
            out.add(parse(map))
        }
        return out
    }

    /** 内部错误码形状：ASCII 小写蛇形，可选 `:细节`（与 `TransferServiceMessages` 同一判据）。 */
    private val MACHINE_CODE = Regex("[a-z][a-z0-9_]*(:[A-Za-z0-9._-]+)?")

    private fun codeOf(error: Throwable): String {
        val message = error.message?.trim().orEmpty()
        return if (MACHINE_CODE.matches(message)) message else "transfer_package_parse_failed"
    }
}
