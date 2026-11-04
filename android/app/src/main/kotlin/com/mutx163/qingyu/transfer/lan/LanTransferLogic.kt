package com.mutx163.qingyu.transfer.lan

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.FormatException
import com.mutx163.qingyu.core.LocationTimeGroup
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.ScheduleDateRule
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.share.TransferApplyMode
import com.mutx163.qingyu.share.TransferChannel
import com.mutx163.qingyu.share.TransferEnvelope
import com.mutx163.qingyu.share.TransferScope
import com.mutx163.qingyu.share.carriesSettings
import com.mutx163.qingyu.share.overwriteUsesMergeSemantics
import com.mutx163.qingyu.sync.validateTransferPackageJson
import com.mutx163.qingyu.transfer.LegacyBackupPackage
import com.mutx163.qingyu.transfer.LegacyBackupParseResult
import com.mutx163.qingyu.transfer.LegacyBackupPayload

/**
 * 局域网 `POST /api/v1/import/preview` 与 `POST /api/v1/import/apply` 的**纯逻辑**层
 * （不碰仓储、不碰 HTTP，JVM 可测）。
 *
 * ## 为什么单独一层
 *
 * `LanEditRepositoryHost` 写盘要真仓储；而「包能不能收 / 差异是什么 / 引用对不对」
 * 全是纯函数。分成两层之后，L0 里能直接钉住 Dart 的口径，不必为每个用例准备一份存储。
 *
 * ## Dart 锚点（`lib/services/lan_edit_api_handlers.dart` / `lan_edit_provider_host.dart` /
 * `unified_transfer_service.dart` / `transfer_diff_service.dart`）
 *
 * - 端点回什么：`_handleTransferPreview` → `LanTransferPreview.toJson()`；
 *   `_handleTransferApply` → `{applied, mode, transferId, diff, error?}`；
 * - 解析口径：`UnifiedTransferService.parseCompatible(content, channel: lan)` ——
 *   **channel 由调用方覆盖成 lan**（包里的 channel 只是元信息）；
 * - 拒绝口径：`_rejectWholeDeviceWrite` —— `backupType: full` 或 `scope: all_data`
 *   一律 `FormatException('use_profile_backup_not_full')`，防止配对端一键覆盖整台设备；
 * - 差异口径：`TransferDiffService.compare` —— 按 id 比 **模型 toJson 的规范化 JSON**，
 *   `merge` 不报删除；`overwrite` 只在 `!scope.overwriteUsesMergeSemantics` 时报删除；
 * - 颜色口径：`LanEditProviderHost.normalizeLanCourseColor` —— 非 `#RRGGBB` 一律回落
 *   `#2196F3`。局域网的课程颜色最终会被浏览器渲染，等于一个 HTML 注入面，必须收窄。
 *
 * ## 与 Dart 的已知偏差（刻意，逐条记在 F17 认领文件里）
 *
 * 1. 包里 `profiles` 非空 → 明确拒（`profile_backup_profiles_unsupported`），
 *    Dart 在「非全量、非 all_data」时会**静默忽略** profiles。静默丢数据比报错更糟，
 *    而局域网导出（`exportProfileBackupJson`）从来不带 profiles，正常流程不受影响；
 * 2. 模型 parse 失败统一映射成 `transfer_${kind}_invalid`，不透出模型层的自由文本消息
 *    （结构门的报错码仍与 Dart 逐字一致）；
 * 3. ~~`settings` 差异只比 Kotlin 已移植的时间/周次子集~~ **已修（2026-11-03）**：
 *    Dart 的 `settings` 是 250+ 键整份 JSON。差异与落盘改成优先使用包/盘上的
 *    **整份原始 map**（[LanTransferDiffSource.settingsJson]），核心四键仍由
 *    [TimetableSettings] 负责（见 [settingsReplacePatch]）。
 */
object LanTransferLogic {

    /** Dart `LanEditProviderHost.defaultLanCourseColor` 原样。 */
    const val DEFAULT_LAN_COURSE_COLOR = "#2196F3"

    /**
     * 备份里带多份档案时的拒绝码（**不是**通用格式错误）。
     *
     * 局域网只恢复当前档案，多档案包要么静默丢掉其它档案（不可接受），要么明确拒绝。
     * 网页端按这个码显示可读解释与替代路径（`assets/lan_edit/app.js` 的
     * `describeTransferError`）；服务端保持错误码口径，不在这里拼人话。
     *
     * 后续路线：仓储已有 [com.mutx163.qingyu.app.TimetableRepository.replaceAllProfiles]
     * 可整份替换档案表，缺的是产品决策——覆盖时旧档案留不留在回收站、激活档指向谁、
     * 与云备份恢复如何互斥。未决策前保持拒绝。
     */
    const val ERROR_PROFILE_BACKUP_PROFILES_UNSUPPORTED = "profile_backup_profiles_unsupported"

    /** Dart `_lanCourseColorPattern` = `^#?([0-9a-fA-F]{6})$` 原样。 */
    private val LAN_COURSE_COLOR_PATTERN = Regex("^#?([0-9a-fA-F]{6})$")

    /**
     * Dart `TransferPackage.validate()` 的结构诊断（不是 parse 门）。
     *
     * 这几个码在 Dart 里由 `validate()` 产出、由 `applyToProvider` 折成
     * `applied: false + error`，**不是** `previewTransferJson` 的 400。
     * 所以这里单列一张表：命中就降级成「可预览、应用时拒绝」，其余错误码仍是 400。
     */
    private val DEFERRED_DIAGNOSTICS = setOf(
        "transfer_package_empty",
        "transfer_full_profiles_required",
        "transfer_time_template_empty",
    )

    // -----------------------------------------------------------------------
    // 解析
    // -----------------------------------------------------------------------

    /**
     * 解析一份局域网传来的传输包。
     *
     * Dart 局域网走 `parseCompatible`（`lan_edit_provider_host.dart:342-344`）：
     * 当前信封优先；**不是信封**时才回落到旧 `.mikcb` 单档备份（老 5 键包）。
     * 信封本身损坏时整份拒收，绝不借旧通道「救回」。
     *
     * @throws FormatException 结构门失败、整设备写入、profiles 非空、旧包解析失败时；
     *   消息是错误码串（路由层折成 400 `invalid_request`）。
     */
    fun parseIncoming(content: String): LanTransferIncoming {
        return try {
            parseStrictIncoming(content)
        } catch (strictError: FormatException) {
            // 信封坏 = 整份拒收（Dart `parseCompatible` 的 fail closed）。
            if (TransferEnvelope.isTransferEnvelopeJson(content)) throw strictError
            val root = LegacyBackupPackage.decodeRoot(content) ?: throw strictError
            if (!LegacyBackupPackage.looksLikeLegacyBackup(root)) throw strictError
            when (val legacy = LegacyBackupPackage.parse(root, TransferChannel.LAN)) {
                is LegacyBackupParseResult.Invalid -> throw FormatException(legacy.code)
                is LegacyBackupParseResult.Valid -> legacyIncoming(legacy.payload)
            }
        }
    }

    private fun parseStrictIncoming(content: String): LanTransferIncoming {
        val validation = validateTransferPackageJson(content)
        // 结构门错误与结构诊断共用一张 errors 表，这里先按码分开（见 DEFERRED_DIAGNOSTICS）。
        val gateError = validation.errors.firstOrNull { it !in DEFERRED_DIAGNOSTICS }
        if (gateError != null) throw FormatException(gateError)
        val diagnostics = validation.errors.filter { it in DEFERRED_DIAGNOSTICS }

        val decoded = MiniJson.tryParse(content)
        if (decoded !is Map<*, *>) throw FormatException("transfer_package_root_invalid")
        @Suppress("UNCHECKED_CAST")
        val json = decoded as Map<String, Any?>

        val scope = try {
            TransferScope.fromValue(json["scope"])
        } catch (_: Exception) {
            throw FormatException("transfer_scope_invalid")
        }
        val isFullBackup = json["backupType"] == "full"
        // Dart `_rejectWholeDeviceWrite`：整份备份 / all_data 都拒。
        if (isFullBackup || scope == TransferScope.ALL_DATA) {
            throw FormatException("use_profile_backup_not_full")
        }
        // 偏差 1：profiles 非空明确拒（Dart 会静默忽略）。
        val profilesRaw = json["profiles"] as? List<*> ?: emptyList<Any?>()
        if (profilesRaw.isNotEmpty()) {
            throw FormatException(ERROR_PROFILE_BACKUP_PROFILES_UNSUPPORTED)
        }

        val courses = parseTransferList("course", json["courses"], Course::fromJson).map { course ->
            course.copy(color = normalizeLanCourseColor(course.color))
        }
        return LanTransferIncoming(
            packageId = (json["packageId"] as? String)?.trim().orEmpty(),
            scope = scope,
            // parseCompatible 的 channel 覆盖：无论如何都算 lan。
            channel = TransferChannel.LAN,
            profileName = (json["profileName"] as? String)?.trim()?.ifEmpty { null },
            currentWeek = (json["currentWeek"] as? Number)?.toInt(),
            activeProfileId = (json["activeProfileId"] as? String)?.trim()?.ifEmpty { null },
            isFullBackup = isFullBackup,
            profileCount = profilesRaw.size,
            diagnostics = diagnostics,
            warnings = validation.warnings,
            source = LanTransferDiffSource(
                courses = courses,
                tasks = parseTransferList("task", json["tasks"], CourseTask::fromJson),
                scheduleItems = parseTransferList("schedule_item", json["scheduleItems"], ScheduleItem::fromJson),
                exams = parseTransferList("exam", json["exams"], Exam::fromJson),
                timeSchemes = parseTransferList("time_scheme", json["timeSchemes"], TimeScheme::fromJson),
                scheduleDateRules = parseTransferList("time_rule", json["scheduleDateRules"], ScheduleDateRule::fromJson),
                locationTimeGroups = parseTransferList("location_group", json["locationTimeGroups"], LocationTimeGroup::fromJson),
                settings = parseSettings(json["settings"]),
                settingsJson = parseSettingsJson(json["settings"]),
            ),
        )
    }

    /**
     * 旧 `.mikcb` 单档备份 → 局域网 preview/apply 的统一入参。
     *
     * 旧包没有 `packageType` / `scope`，Dart `parseBackupJson` 一律折成
     * `current_timetable`；落盘走与信封包相同的「整份替换 / 合并」分支
     * （`LanTransferApplier.applyIncoming`），不在这里再分叉。
     */
    private fun legacyIncoming(payload: LegacyBackupPayload): LanTransferIncoming {
        // Dart `_rejectWholeDeviceWrite`：全量旧备份也不许走局域网整设备覆盖。
        if (payload.isFullBackup || payload.scope == TransferScope.ALL_DATA) {
            throw FormatException("use_profile_backup_not_full")
        }
        if (payload.profiles.isNotEmpty()) {
            throw FormatException(ERROR_PROFILE_BACKUP_PROFILES_UNSUPPORTED)
        }
        return LanTransferIncoming(
            packageId = payload.packageId.trim(),
            scope = payload.scope,
            channel = TransferChannel.LAN,
            profileName = payload.profileName?.trim()?.ifEmpty { null },
            currentWeek = payload.currentWeek,
            activeProfileId = payload.activeProfileId?.trim()?.ifEmpty { null },
            isFullBackup = false,
            profileCount = 0,
            // 旧包没有信封的结构校验，没有可复用的诊断；apply 侧照常做引用检查。
            diagnostics = emptyList(),
            warnings = emptyList(),
            source = LanTransferDiffSource(
                courses = payload.courses.map { course ->
                    course.copy(color = normalizeLanCourseColor(course.color))
                },
                tasks = payload.tasks,
                scheduleItems = payload.scheduleItems,
                exams = payload.exams,
                timeSchemes = payload.timeSchemes,
                scheduleDateRules = payload.scheduleDateRules,
                locationTimeGroups = payload.locationTimeGroups,
                settings = payload.settings,
                settingsJson = payload.settingsJson,
            ),
        )
    }

    /** Dart `LanEditProviderHost.normalizeLanCourseColor`：只认 `#RRGGBB`（可省 `#`），其余回落默认色。 */
    fun normalizeLanCourseColor(raw: Any?): String {
        val text = raw as? String ?: return DEFAULT_LAN_COURSE_COLOR
        val match = LAN_COURSE_COLOR_PATTERN.matchEntire(text.trim()) ?: return DEFAULT_LAN_COURSE_COLOR
        return "#" + match.groupValues[1].uppercase()
    }

    private fun parseSettings(raw: Any?): TimetableSettings? {
        if (raw !is Map<*, *>) return null
        return try {
            @Suppress("UNCHECKED_CAST")
            TimetableSettings.fromJson(raw as Map<String, Any?>)
        } catch (_: Exception) {
            null
        }
    }

    /** 整份设置的原始 map（键统一成 String；非对象 → null）。 */
    fun parseSettingsJson(raw: Any?): Map<String, Any?>? {
        if (raw !is Map<*, *>) return null
        val out = LinkedHashMap<String, Any?>(raw.size)
        for ((key, value) in raw) {
            if (key is String) out[key] = value
        }
        return out
    }

    /**
     * 差异/落盘用的整份设置：优先原始 map（Dart 250+ 键），
     * 只有老调用方没带原始 map 时才回落到核心四键的 `toJson()`。
     */
    fun settingsMap(source: LanTransferDiffSource): Map<String, Any?>? =
        source.settingsJson ?: source.settings?.toJson()

    /** Dart `TransferPackage._parseList`：逐条模型 parse；坏一条整份拒（此处统一折成错误码）。 */
    private fun <T> parseTransferList(
        kind: String,
        raw: Any?,
        parse: (Map<String, Any?>) -> T,
    ): List<T> {
        if (raw !is List<*>) return emptyList()
        val out = ArrayList<T>(raw.size)
        for (item in raw) {
            if (item !is Map<*, *>) throw FormatException("transfer_${kind}_invalid")
            try {
                @Suppress("UNCHECKED_CAST")
                out.add(parse(item as Map<String, Any?>))
            } catch (_: Exception) {
                // 结构门已经先跑过；走到这里只可能是模型层的自由文本异常（字段取值非法一类）。
                // 统一折成错误码，不把模型内部消息透到 HTTP 响应里。
                throw FormatException("transfer_${kind}_invalid")
            }
        }
        return out
    }

    // -----------------------------------------------------------------------
    // 差异
    // -----------------------------------------------------------------------

    /**
     * Dart `TransferDiffService.compare` 的移植（不含 profile 作用域实体，见偏差 1）。
     *
     * `mode = merge` 永不报删除；`overwrite` 仅在
     * `!scope.overwriteUsesMergeSemantics`（即 current_timetable / all_data）时报删除。
     */
    fun compare(
        current: LanTransferDiffSource,
        incoming: LanTransferDiffSource,
        scope: TransferScope,
        mode: TransferApplyMode,
    ): LanTransferDiff {
        val reportRemovals = mode == TransferApplyMode.OVERWRITE &&
            !scope.overwriteUsesMergeSemantics
        val summaries = ArrayList<LanTransferEntityDiff>(LanTransferKind.all.size)
        summaries += compareList(
            LanTransferKind.COURSES,
            current.courses.map { entityOf(it.id, it.name, it.toJson()) },
            incoming.courses.map { entityOf(it.id, it.name, it.toJson()) },
            reportRemovals,
        )
        summaries += compareList(
            LanTransferKind.EXAMS,
            current.exams.map { entityOf(it.id, it.name, it.toJson()) },
            incoming.exams.map { entityOf(it.id, it.name, it.toJson()) },
            reportRemovals,
        )
        summaries += compareList(
            LanTransferKind.TIME_RULES,
            current.scheduleDateRules.map { entityOf(it.id, it.name, it.toJson()) },
            incoming.scheduleDateRules.map { entityOf(it.id, it.name, it.toJson()) },
            reportRemovals,
        )
        summaries += compareList(
            LanTransferKind.LOCATIONS,
            current.locationTimeGroups.map { entityOf(it.id, it.name, it.toJsonMap()) },
            incoming.locationTimeGroups.map { entityOf(it.id, it.name, it.toJsonMap()) },
            reportRemovals,
        )
        summaries += compareList(
            LanTransferKind.TASKS,
            current.tasks.map { entityOf(it.id, it.title, it.toJson()) },
            incoming.tasks.map { entityOf(it.id, it.title, it.toJson()) },
            reportRemovals,
        )
        summaries += compareList(
            LanTransferKind.SCHEDULE_ITEMS,
            current.scheduleItems.map { entityOf(it.id, it.title, it.toJson()) },
            incoming.scheduleItems.map { entityOf(it.id, it.title, it.toJson()) },
            reportRemovals,
        )
        summaries += compareList(
            LanTransferKind.TIME_SCHEMES,
            current.timeSchemes.map { entityOf(it.id, it.name, it.toJson()) },
            incoming.timeSchemes.map { entityOf(it.id, it.name, it.toJson()) },
            reportRemovals,
        )

        val currentSettings = settingsMap(current)
        val incomingSettings = settingsMap(incoming)
        if (scope.carriesSettings && currentSettings != null && incomingSettings != null) {
            val changes = if (sameJson(currentSettings, incomingSettings)) {
                emptyList()
            } else {
                listOf(
                    LanTransferChange(
                        kind = LanTransferKind.SETTINGS,
                        type = LanTransferChangeType.UPDATED,
                        id = "settings",
                        label = "settings",
                        before = currentSettings,
                        after = incomingSettings,
                    ),
                )
            }
            summaries += LanTransferEntityDiff(LanTransferKind.SETTINGS, changes)
        }
        return LanTransferDiff(mode = mode, summaries = summaries)
    }

    /**
     * Dart `TransferDiffService.validate(incoming, current:)` 的**本地比对**部分
     * （`package.validate()` 那条结构诊断由 [parseIncoming] 折进 `diagnostics`）。
     *
     * 报错顺序与 Dart 逐条一致：考试 → 作业 → 日期规则 → 地点分组 → 课程模板覆盖。
     */
    fun collectReferenceErrors(
        incoming: LanTransferDiffSource,
        current: LanTransferDiffSource,
    ): List<String> {
        val availableCourseIds = HashSet<String>()
        incoming.courses.mapTo(availableCourseIds) { it.id }
        current.courses.mapTo(availableCourseIds) { it.id }
        val availableSchemeIds = HashSet<String>()
        incoming.timeSchemes.mapTo(availableSchemeIds) { it.id }
        current.timeSchemes.mapTo(availableSchemeIds) { it.id }

        val errors = ArrayList<String>()
        for (exam in incoming.exams) {
            if (exam.courseId.isNotEmpty() && exam.courseId !in availableCourseIds) {
                errors += "exam_course_missing:${exam.id}"
            }
        }
        for (task in incoming.tasks) {
            val courseId = task.courseId ?: continue
            if (courseId !in availableCourseIds) errors += "task_course_missing:${task.id}"
        }
        for (rule in incoming.scheduleDateRules) {
            if (rule.timeSchemeId.isEmpty() || rule.timeSchemeId !in availableSchemeIds) {
                errors += "time_rule_scheme_missing:${rule.id}"
            }
        }
        for (group in incoming.locationTimeGroups) {
            if (group.timeSchemeId.isEmpty() || group.timeSchemeId !in availableSchemeIds) {
                errors += "location_scheme_missing:${group.id}"
            }
        }
        for (course in incoming.courses) {
            val schemeId = course.timeSchemeIdOverride
            if (schemeId != null && schemeId.isNotEmpty() && schemeId !in availableSchemeIds) {
                errors += "course_scheme_missing:${course.id}"
            }
        }
        return errors
    }

    /** Dart `LanTransferPreview.toJson()`：`diff` 是 `overwriteDiff` 的向后兼容别名。 */
    fun previewJson(
        incoming: LanTransferIncoming,
        current: LanTransferDiffSource,
    ): Map<String, Any?> {
        val mergeDiff = compare(current, incoming.source, incoming.scope, TransferApplyMode.MERGE)
        val overwriteDiff = compare(current, incoming.source, incoming.scope, TransferApplyMode.OVERWRITE)
        return linkedMapOf(
            "transferId" to incoming.packageId,
            "channel" to incoming.channel.value,
            "scope" to incoming.scope.value,
            "mergeDiff" to mergeDiff.toJson(),
            "overwriteDiff" to overwriteDiff.toJson(),
            "diff" to overwriteDiff.toJson(),
        )
    }

    /**
     * Dart `_handleTransferApply` 的响应体：
     * `{applied, mode, transferId, diff, error?}`。
     *
     * `transferId` 是**撤销点 id**（Dart 同样是 `result.undoToken?.id`，不是包里的
     * `packageId`）：应用成功才有值，凭它调 `POST /api/v1/import/undo` 撤回这一批导入；
     * 失败或未应用时为 null。
     */
    fun applyResultJson(
        applied: Boolean,
        mode: TransferApplyMode,
        diff: LanTransferDiff,
        error: String?,
        transferId: String? = null,
    ): Map<String, Any?> {
        val out = linkedMapOf<String, Any?>(
            "applied" to applied,
            "mode" to modeName(mode),
            "transferId" to transferId,
            "diff" to diff.toJson(),
        )
        if (error != null) out["error"] = error
        return out
    }

    fun modeName(mode: TransferApplyMode): String = when (mode) {
        TransferApplyMode.MERGE -> "merge"
        TransferApplyMode.OVERWRITE -> "overwrite"
    }

    // -----------------------------------------------------------------------
    // 应用计划（纯函数；执行在 LanTransferApplier）
    // -----------------------------------------------------------------------

    /**
     * Dart `UnifiedTransferService._mergeTimeSchemes` 的移植，但**只出计划不写盘**：
     * - 同一个 id → [LanTimeSchemeStep.Update]（外来名字与节次覆盖本地）；
     * - 节次签名相同、id 不同 → [LanTimeSchemeStep.Reuse]（复用本地 id，一次写都不做）；
     * - 同一次应用内前面刚创建的同签名模板 → [LanTimeSchemeStep.Alias]（指向那位创建者）；
     * - 否则 → [LanTimeSchemeStep.Create]。
     */
    fun planTimeSchemes(
        local: List<TimeScheme>,
        incoming: List<TimeScheme>,
    ): List<LanTimeSchemeStep> {
        val localById = local.associateBy { it.id }
        val localIdBySignature = LinkedHashMap<String, String>()
        for (scheme in local) localIdBySignature[schemeSignature(scheme)] = scheme.id
        val ownerBySignature = LinkedHashMap<String, String>()
        val steps = ArrayList<LanTimeSchemeStep>(incoming.size)

        for (scheme in incoming) {
            val signature = schemeSignature(scheme)
            val sameId = localById[scheme.id]
            if (sameId != null) {
                steps += LanTimeSchemeStep.Update(sameId.id, scheme.name, scheme.sections)
                localIdBySignature[signature] = sameId.id
                continue
            }
            val twinId = localIdBySignature[signature]
            if (twinId != null) {
                steps += LanTimeSchemeStep.Reuse(scheme.id, twinId)
                continue
            }
            val owner = ownerBySignature[signature]
            if (owner != null) {
                steps += LanTimeSchemeStep.Alias(scheme.id, owner)
                continue
            }
            steps += LanTimeSchemeStep.Create(scheme.id, scheme.name, scheme.sections)
            ownerBySignature[signature] = scheme.id
        }
        return steps
    }

    /** 节次签名：Dart `_timeSchemeSectionsSignature` 就是 `jsonEncode(sections)`。 */
    fun schemeSignature(scheme: TimeScheme): String =
        MiniJson.encode(scheme.sections.map { it.toJson() })

    /** Dart `_remapCourseTimeSchemeReferences`：只改写**能命中**的模板引用。 */
    fun remapCourseSchemes(courses: List<Course>, schemeIdMap: Map<String, String>): List<Course> =
        courses.map { course ->
            val source = course.timeSchemeIdOverride
            if (source == null) {
                course
            } else {
                val target = schemeIdMap[source]
                if (target == null || target == source) course else course.copy(timeSchemeIdOverride = target)
            }
        }

    /** Dart `_remapSettingsTimeSchemeReference`。 */
    fun remapSettingsScheme(settings: TimetableSettings, schemeIdMap: Map<String, String>): TimetableSettings {
        val source = settings.activeTimeSchemeId ?: return settings
        val target = schemeIdMap[source]
        return if (target == null || target == source) settings else settings.copy(activeTimeSchemeId = target)
    }

    /** 仓储层 [TimetableSettings] 拥有的核心键，整份设置补丁不碰它们。 */
    private val CORE_SETTINGS_KEYS = setOf(
        "sections",
        "activeTimeSchemeId",
        "semesterWeekCount",
        "semesterStartDate",
        "semesterStartDateText",
    )

    /** 设备信任锚：Dart `keepingDeviceTrustAnchorsFrom` 的两键（更新镜像预设/前缀）。 */
    private val DEVICE_TRUST_ANCHOR_KEYS = listOf("appUpdateMirrorPreset", "appUpdateMirrorUrlPrefix")

    /**
     * Dart `applyToProvider` 的 settings 落盘口径——**整份替换**：
     *
     * - 外来有 → 写外来；
     * - 外来缺、本地有 → 显式 `null`（`saveSettingsPatch` 里 null 才删键；
     *   等价于 Dart 反序列化后该字段回落默认值）；
     * - 设备信任锚两键永远用**本地值**（Dart `keepingDeviceTrustAnchorsFrom`，
     *   不跟随来源设备，否则等于让对方改写本机更新源）；
     * - 核心四键剔除，由 `repository.updateSettings` 负责（含模板 id 重映射）。
     *
     * 撤销回滚复用同一函数：`incoming = 导入前`、`local = 当前`。
     */
    fun settingsReplacePatch(
        incoming: Map<String, Any?>,
        local: Map<String, Any?>,
    ): Map<String, Any?> {
        val patch = LinkedHashMap<String, Any?>()
        for ((key, value) in incoming) {
            if (key !in CORE_SETTINGS_KEYS) patch[key] = value
        }
        for (key in local.keys) {
            if (key !in incoming && key !in CORE_SETTINGS_KEYS) patch[key] = null
        }
        for (key in DEVICE_TRUST_ANCHOR_KEYS) {
            if (local.containsKey(key)) patch[key] = local[key] else patch.remove(key)
        }
        return patch
    }

    /** Dart `_remapScheduleDateRules`。 */
    fun remapScheduleDateRules(
        rules: List<ScheduleDateRule>,
        schemeIdMap: Map<String, String>,
    ): List<ScheduleDateRule> = rules.map { rule ->
        rule.copy(timeSchemeId = schemeIdMap[rule.timeSchemeId] ?: rule.timeSchemeId)
    }

    /** Dart `_remapLocationTimeGroups`。 */
    fun remapLocationTimeGroups(
        groups: List<LocationTimeGroup>,
        schemeIdMap: Map<String, String>,
    ): List<LocationTimeGroup> = groups.map { group ->
        group.copy(timeSchemeId = schemeIdMap[group.timeSchemeId] ?: group.timeSchemeId)
    }

    /**
     * 按 id 合并两份列表，语义 = Dart `_mergeRulesAndLocations` 里的
     * `{...本地, ...外来}` map 并集：本地顺序保留，同 id 用外来值覆盖，新 id 追加在后。
     */
    fun <T> mergeById(current: List<T>, incoming: List<T>, idOf: (T) -> String): List<T> {
        if (incoming.isEmpty()) return current
        val incomingById = incoming.associateBy(idOf)
        val merged = ArrayList<T>(current.size + incoming.size)
        for (item in current) merged += incomingById[idOf(item)] ?: item
        val existingIds = current.mapTo(HashSet(current.size)) { idOf(it) }
        for (item in incoming) if (idOf(item) !in existingIds) merged += item
        return merged
    }

    // -----------------------------------------------------------------------
    // 内部：差异工具
    // -----------------------------------------------------------------------

    private fun compareList(
        kind: LanTransferKind,
        current: List<LanDiffEntity>,
        incoming: List<LanDiffEntity>,
        reportRemovals: Boolean,
    ): LanTransferEntityDiff {
        val currentById = current.associateBy { it.id }
        val incomingById = incoming.associateBy { it.id }
        val changes = ArrayList<LanTransferChange>()
        for (item in incoming) {
            val before = currentById[item.id]
            if (before == null) {
                changes += LanTransferChange(
                    kind = kind,
                    type = LanTransferChangeType.ADDED,
                    id = item.id,
                    label = item.label,
                    before = null,
                    after = item.json,
                )
            } else if (!sameJson(before.json, item.json)) {
                changes += LanTransferChange(
                    kind = kind,
                    type = LanTransferChangeType.UPDATED,
                    id = item.id,
                    label = item.label,
                    before = before.json,
                    after = item.json,
                )
            }
        }
        if (reportRemovals) {
            for (item in current) {
                if (item.id !in incomingById) {
                    changes += LanTransferChange(
                        kind = kind,
                        type = LanTransferChangeType.REMOVED,
                        id = item.id,
                        label = item.label,
                        before = item.json,
                        after = null,
                    )
                }
            }
        }
        return LanTransferEntityDiff(kind = kind, changes = changes)
    }

    private fun entityOf(id: String, label: String, json: Map<String, Any?>): LanDiffEntity =
        LanDiffEntity(id = id, label = label, json = json)

    /** Dart `_sameJson`：先做键排序的规范化，再逐字节比对。 */
    fun sameJson(left: Map<String, Any?>, right: Map<String, Any?>): Boolean =
        canonicalJson(left) == canonicalJson(right)

    private fun canonicalJson(value: Any?): String = MiniJson.encode(canonicalize(value))

    /** Dart `TransferDiffService._canonicalize`：map 按键名排序，list 保序。 */
    private fun canonicalize(value: Any?): Any? = when (value) {
        is Map<*, *> -> {
            val out = LinkedHashMap<String, Any?>()
            value.entries
                .map { it.key.toString() to it.value }
                .sortedBy { it.first }
                .forEach { (key, item) -> out[key] = canonicalize(item) }
            out
        }
        is List<*> -> value.map { canonicalize(it) }
        else -> value
    }
}

/** 差异比对用的实体投影（Dart `_TransferEntity`，不含 profileId 作用域，见类注释偏差 1）。 */
internal data class LanDiffEntity(
    val id: String,
    val label: String,
    val json: Map<String, Any?>,
)

/**
 * 一份传输包在本次导入里会用到的全部数据（Dart `TransferPackage` 的本地投影）。
 *
 * `settings` 为 null 表示包里没带设置或带得不合法（后者已被结构门拦下）。
 */
data class LanTransferDiffSource(
    val courses: List<Course> = emptyList(),
    val tasks: List<CourseTask> = emptyList(),
    val scheduleItems: List<ScheduleItem> = emptyList(),
    val exams: List<Exam> = emptyList(),
    val timeSchemes: List<TimeScheme> = emptyList(),
    val scheduleDateRules: List<ScheduleDateRule> = emptyList(),
    val locationTimeGroups: List<LocationTimeGroup> = emptyList(),
    val settings: TimetableSettings? = null,
    /**
     * 整份设置的原始 map（盘上/包里的原样键集）。
     *
     * Dart 的 `settings` 是 250+ 键；[settings] 只有时间/周次核心四键。
     * 差异与回写优先用这份原始 map，缺失时才回落到 [settings]。
     */
    val settingsJson: Map<String, Any?>? = null,
)

/** [LanTransferLogic.parseIncoming] 的结果。 */
data class LanTransferIncoming(
    val packageId: String,
    val scope: TransferScope,
    val channel: TransferChannel,
    val profileName: String?,
    val currentWeek: Int?,
    val activeProfileId: String?,
    val isFullBackup: Boolean,
    val profileCount: Int,
    /** 结构诊断（`transfer_package_empty` 一类）：可预览，应用时折成 `applied: false`。 */
    val diagnostics: List<String>,
    val warnings: List<String>,
    val source: LanTransferDiffSource,
)

/** Dart `TransferEntityKind.value` 原样（顺序 = `TransferDiff.allKinds`）。 */
enum class LanTransferKind(val value: String) {
    COURSES("courses"),
    EXAMS("exams"),
    TIME_RULES("time_rules"),
    LOCATIONS("locations"),
    TASKS("tasks"),
    SCHEDULE_ITEMS("schedule_items"),
    TIME_SCHEMES("time_schemes"),
    SETTINGS("settings");

    companion object {
        val all: List<LanTransferKind> = listOf(
            COURSES, EXAMS, TIME_RULES, LOCATIONS, TASKS, SCHEDULE_ITEMS, TIME_SCHEMES, SETTINGS,
        )
    }
}

/** Dart `TransferChangeType`。 */
enum class LanTransferChangeType(val value: String) {
    ADDED("added"),
    UPDATED("updated"),
    REMOVED("removed"),
}

/** Dart `TransferEntityChange`（`description` 由 `toJson` 现算，前端可整条显示）。 */
data class LanTransferChange(
    val kind: LanTransferKind,
    val type: LanTransferChangeType,
    val id: String,
    val label: String,
    val before: Map<String, Any?>? = null,
    val after: Map<String, Any?>? = null,
) {
    val readableLabel: String get() = label.trim().ifEmpty { id }

    val description: String get() = "${type.value}: $readableLabel ($id)"

    fun toJson(): Map<String, Any?> {
        val out = linkedMapOf<String, Any?>(
            "kind" to kind.value,
            "type" to type.value,
            "id" to id,
            "label" to label,
            "description" to description,
        )
        before?.let { out["before"] = it }
        after?.let { out["after"] = it }
        return out
    }
}

/** Dart `TransferEntityDiff`。 */
data class LanTransferEntityDiff(
    val kind: LanTransferKind,
    val changes: List<LanTransferChange>,
) {
    val addedCount: Int get() = changes.count { it.type == LanTransferChangeType.ADDED }
    val updatedCount: Int get() = changes.count { it.type == LanTransferChangeType.UPDATED }
    val removedCount: Int get() = changes.count { it.type == LanTransferChangeType.REMOVED }
    val totalCount: Int get() = changes.size
    val isEmpty: Boolean get() = changes.isEmpty()

    fun toJson(): Map<String, Any?> = linkedMapOf(
        "kind" to kind.value,
        "added" to addedCount,
        "updated" to updatedCount,
        "removed" to removedCount,
        "total" to totalCount,
        "changes" to changes.map { it.toJson() },
    )
}

/** Dart `TransferDiff`（`summaries` 恒定按 `allKinds` 全量输出，含计数为 0 的类别）。 */
data class LanTransferDiff(
    val mode: TransferApplyMode,
    val summaries: List<LanTransferEntityDiff>,
) {
    fun forKind(kind: LanTransferKind): LanTransferEntityDiff =
        summaries.firstOrNull { it.kind == kind } ?: LanTransferEntityDiff(kind, emptyList())

    val addedCount: Int get() = summaries.sumOf { it.addedCount }
    val updatedCount: Int get() = summaries.sumOf { it.updatedCount }
    val removedCount: Int get() = summaries.sumOf { it.removedCount }
    val totalCount: Int get() = summaries.sumOf { it.totalCount }
    val hasChanges: Boolean get() = summaries.any { it.changes.isNotEmpty() }

    fun toJson(): Map<String, Any?> = linkedMapOf(
        "mode" to LanTransferLogic.modeName(mode),
        "added" to addedCount,
        "updated" to updatedCount,
        "removed" to removedCount,
        "total" to totalCount,
        "summaries" to LanTransferKind.all.map { forKind(it).toJson() },
    )
}

/** [LanTransferLogic.planTimeSchemes] 的一步。 */
sealed interface LanTimeSchemeStep {
    /** 本地已有同 id：按外来名字 + 节次更新。 */
    data class Update(val localId: String, val name: String, val sections: List<SectionTime>) : LanTimeSchemeStep

    /** 节次签名与本地某张表相同：复用本地 id，不写。 */
    data class Reuse(val incomingId: String, val localId: String) : LanTimeSchemeStep

    /** 指向同一次应用里前面刚创建的那张表。 */
    data class Alias(val incomingId: String, val ownerIncomingId: String) : LanTimeSchemeStep

    /** 新建一张本地表。 */
    data class Create(val incomingId: String, val name: String, val sections: List<SectionTime>) : LanTimeSchemeStep
}
