package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.DartFormatException
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.ScheduleDateRule
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.share.TransferChannel
import com.mutx163.qingyu.share.TransferScope
import com.mutx163.qingyu.share.carriesSettings
import com.mutx163.qingyu.sync.validateTransferPackageJson

/**
 * 数据备份与迁移页的**导入侧**模型层：解析包 → 差分摘要 → 预览弹窗正文。
 *
 * ## 三段各自的判据源
 *
 * | 本文件 | Dart 出处 |
 * | --- | --- |
 * | [DataTransferImportLogic.parse] | `TransferPackage.decode` / `fromJson`（`lib/services/transfer_package.dart`），外加 `validateJson` 那道前置门 |
 * | [DataTransferImportLogic.diffSummaries] | `TransferDiffService.compare`（`lib/services/transfer_diff_service.dart:150-203`） |
 * | [DataTransferImportLogic.previewMessage] | `showTransferPreviewDialog`（`lib/screens/transfer_preview_dialog.dart:18-34`） |
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
 * 1. `diffSummaries` 比对的是**两份包文本**，Dart 比对的是「真实仓储内容 vs 入包内容」，
 *    且 `compare()` 只在 `mode == overwrite && !scope.overwriteUsesMergeSemantics`
 *    时才统计 removed。本函数的签名里没有 mode，因此 **removed 恒定统计**（页面要么
 *    把 overwrite 那侧的 removed 直接展示、要么由宿主自己归零）。这是近似，不是等价。
 * 2. Dart 的实体比对先经模型 `fromJson` 再比 `toJson()`（模型归一化后的形状）；
 *    这里比的是两份 JSON 里各自的原始实体 Map，用「递归键排序后的 JSON」做相等判据
 *    （Dart `_sameJson` 用的就是这套 canonicalize）。对**本应用自己产的包**两者等价；
 *    对手写/第三方包，若同一事实用不同键序或多余键表达，本实现判「updated」。
 * 3. Dart 的 `settings` 行只在 `incoming.scope.carriesSettings && 两侧 settings 非空`
 *    时才进 `summaries`，未进时由 `allSummaries` 的 `orElse` 补出 `+0 / ~0 / -0`。
 *    本实现直接按同一判据算 0/0/0 或 0/1/0，所以**行数恒定 8 行**（预览弹窗要求无条件全输出）。
 * 4. `parse` 的 `Invalid` 码在模型层抛错时未必与 Dart 逐字相同：Dart 在 `_parseList`
 *    里把模型 parse 异常包成 `transfer_${kind}_invalid`，本实现按校验器已过的前提
 *    直接调模型 `fromJson`，异常消息是形状码就原样透出，否则落到
 *    `transfer_package_parse_failed`（本仓新增码，界面上会落到「发生未知错误」）。
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
)

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

    // ── 差分的八个类别（顺序 = Dart `TransferDiff.allKinds`，逐字冻结） ──

    /** `(kind.value, 包里对应的 JSON 键)`，顺序即预览弹窗的行序。 */
    private val DIFF_KINDS: List<Pair<String, String>> = listOf(
        "courses" to "courses",
        "exams" to "exams",
        "time_rules" to "scheduleDateRules",
        "locations" to "locationTimeGroups",
        "tasks" to "tasks",
        "schedule_items" to "scheduleItems",
        "time_schemes" to "timeSchemes",
    )

    /** 这四类实体在包里有两种摆法：顶层一份 + 每张档案内部一份（Dart `_flatten`）。 */
    private val PROFILE_NESTED_KEYS = setOf("courses", "exams", "tasks", "scheduleItems")

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
     * 8 类差分（顺序 = `courses / exams / time_rules / locations / tasks /
     * schedule_items / time_schemes / settings`），按 id 匹配。
     *
     * 判据：
     * - incoming 有、current 无 → added；
     * - 两侧都有但规范化 JSON 不同 → updated；
     * - current 有、incoming 无 → removed；
     * - `settings` 没有 id：两侧相等 → `0/0/0`，不等 → `0/1/0`（且只在 incoming 的
     *   scope 会携带设置时才算，判据同 Dart）。
     *
     * 行数**恒定 8 行**（含 `+0 / ~0 / -0`），因为预览弹窗的契约是「全输出」——
     * 少一行用户就会以为那一类数据「不会被动」。
     *
     * ⚠️ 与 Dart 的差异见文件头「已知差异 1/2」：这里比的是两份包文本，
     * 且 removed 无条件统计（Dart 只在覆盖式导入且 scope 不是 merge 语义时统计）。
     */
    fun diffSummaries(currentJson: String, incomingJson: String): List<TransferDiffSummary> {
        val current = decodeRoot(currentJson) ?: emptyMap()
        val incoming = decodeRoot(incomingJson) ?: emptyMap()
        val summaries = ArrayList<TransferDiffSummary>(DIFF_KINDS.size + 1)
        for ((kind, jsonKey) in DIFF_KINDS) {
            summaries.add(compareEntities(kind, current, incoming, jsonKey))
        }
        summaries.add(settingsSummary(current, incoming))
        return summaries
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

    // ---------- 内部：差分的实体抽取与比对 ----------

    /** 一条参与比对的实体：出现在哪张档案里（null = 包级）、id 是什么、规范化 JSON 长什么样。 */
    private data class DiffEntity(
        val profileId: String?,
        val id: String,
        val normalizedJson: String,
    ) {
        /** Dart `_TransferEntity.key`：`jsonEncode([profileId, id])` 的等价物。 */
        val key: String get() = "${profileId ?: ""}\u0000$id"
    }

    private fun compareEntities(
        kind: String,
        current: Map<String, Any?>,
        incoming: Map<String, Any?>,
        jsonKey: String,
    ): TransferDiffSummary {
        val currentEntities = entitiesOf(current, jsonKey)
        val incomingEntities = entitiesOf(incoming, jsonKey)
        val currentById = currentEntities.associateBy { it.key }
        val incomingById = incomingEntities.associateBy { it.key }
        var added = 0
        var updated = 0
        var removed = 0
        for (entity in incomingEntities) {
            val before = currentById[entity.key]
            if (before == null) {
                added++
            } else if (before.normalizedJson != entity.normalizedJson) {
                updated++
            }
        }
        for (entity in currentEntities) {
            if (!incomingById.containsKey(entity.key)) removed++
        }
        return TransferDiffSummary(kind = kind, added = added, updated = updated, removed = removed)
    }

    private fun entitiesOf(root: Map<String, Any?>, jsonKey: String): List<DiffEntity> {
        val out = mutableListOf<DiffEntity>()
        if (jsonKey in PROFILE_NESTED_KEYS) {
            val profiles = root["profiles"] as? List<*> ?: emptyList<Any?>()
            for (profile in profiles) {
                if (profile !is Map<*, *>) continue
                val profileId = profile["id"]?.toString()
                val items = profile[jsonKey] as? List<*> ?: emptyList<Any?>()
                for (item in items) {
                    if (item !is Map<*, *>) continue
                    out += DiffEntity(profileId, idOf(item), canonicalJson(item))
                }
            }
        }
        val topLevel = root[jsonKey] as? List<*> ?: emptyList<Any?>()
        for (item in topLevel) {
            if (item !is Map<*, *>) continue
            out += DiffEntity(null, idOf(item), canonicalJson(item))
        }
        return out
    }

    /**
     * `settings` 那一行。Dart `TransferDiffService.compare` 的判据：
     * `incoming.scope.carriesSettings` 且两侧都能取到 settings 才比，否则 0/0/0。
     *
     * 取 settings 的顺序也照 Dart `_settingsFor`：先看顶层，再退「只有一张档案」时
     * 那张档案里的 settings。
     */
    private fun settingsSummary(
        current: Map<String, Any?>,
        incoming: Map<String, Any?>,
    ): TransferDiffSummary {
        val incomingScope = (incoming["scope"] as? String)?.let { raw ->
            try {
                TransferScope.fromValue(raw)
            } catch (_: Exception) {
                null
            }
        }
        val currentSettings = settingsOf(current)
        val incomingSettings = settingsOf(incoming)
        val differs = incomingScope?.carriesSettings == true &&
            currentSettings != null &&
            incomingSettings != null &&
            canonicalJson(currentSettings) != canonicalJson(incomingSettings)
        return TransferDiffSummary(
            kind = "settings",
            added = 0,
            updated = if (differs) 1 else 0,
            removed = 0,
        )
    }

    private fun settingsOf(root: Map<String, Any?>): Map<*, *>? {
        (root["settings"] as? Map<*, *>)?.let { return it }
        val profiles = root["profiles"] as? List<*> ?: return null
        if (profiles.size != 1) return null
        return (profiles.first() as? Map<*, *>)?.get("settings") as? Map<*, *>
    }

    private fun idOf(item: Map<*, *>): String = when (val raw = item["id"]) {
        null -> ""
        is String -> raw.trim()
        else -> raw.toString().trim()
    }

    // ---------- 内部：规范化 JSON 与解析辅助 ----------

    /**
     * Dart `_canonicalize`：Map 按键名排序、List 逐项递归、其余原样。
     * 排序后再 `MiniJson.encode`，键序不同但内容相同的两份实体就判相等。
     */
    private fun canonical(value: Any?): Any? = when (value) {
        is Map<*, *> -> {
            val sorted = value.entries
                .map { it.key.toString() to canonical(it.value) }
                .sortedBy { it.first }
            val out = LinkedHashMap<String, Any?>()
            for ((key, item) in sorted) out[key] = item
            out
        }
        is List<*> -> value.map { canonical(it) }
        else -> value
    }

    private fun canonicalJson(map: Map<*, *>): String = MiniJson.encode(canonical(map))

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
