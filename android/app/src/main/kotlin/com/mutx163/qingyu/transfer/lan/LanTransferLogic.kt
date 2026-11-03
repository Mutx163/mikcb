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
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.share.TransferApplyMode
import com.mutx163.qingyu.share.TransferChannel
import com.mutx163.qingyu.share.TransferScope
import com.mutx163.qingyu.share.carriesSettings
import com.mutx163.qingyu.share.overwriteUsesMergeSemantics
import com.mutx163.qingyu.sync.validateTransferPackageJson

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
 * - 拒绝口径：整设备写入按**分层矩阵**（见 [parseIncoming]）——`backupType: full`
 *   + 非空 profiles 走整份快照恢复（Dart 旧版 `_overwrite → importFullAppDataBackup`
 *   的同款能力，bf09a7c3 一刀切拒绝时被误伤，2026-11-03 放开）；`all_data` 非 full、
 *   full 缺档案、非 full 带 profiles 仍明确拒且理由各不相同；
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
 * 3. `settings` 的**写回与差异**走原始 JSON 整份，不再只覆盖 Kotlin 已移植的
 *    时间/周次子集：Dart 侧 `updateSettings` 写的是整份 `TimetableSettings.toJson()`，
 *    只写五个键会把包里其余 200+ 个设置静默丢掉。模型层仍只解析这五个键（那层的
 *    边界没变），但落盘走 [settingsApplyPatch] 的合并补丁，未知键原样写回；
 *    设备级信任锚（更新镜像）按 Dart `keepingDeviceTrustAnchorsFrom` 一律保留本机值。
 */
object LanTransferLogic {

    /** Dart `LanEditProviderHost.defaultLanCourseColor` 原样。 */
    const val DEFAULT_LAN_COURSE_COLOR = "#2196F3"

    /**
     * 备份里带 profiles 但**不是** `backupType: full` 全量格式时的拒绝码（**不是**通用格式错误）。
     *
     * 这种包要么静默丢掉其它档案（不可接受），要么明确拒绝。整份恢复请走手机端
     * 「数据备份与迁移」导出的 full 备份（`backupType: full` + profiles），那条路
     * 2026-11-03 起在局域网放行。网页端按这个码显示可读解释与替代路径
     * （`assets/lan_edit/app.js` 的 `describeTransferError`）；服务端保持错误码口径，
     * 不在这里拼人话。
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
     * 严格解析一份局域网传来的传输包。
     *
     * @throws FormatException 结构门失败、整设备写入、profiles 非空时；
     *   消息是错误码串（路由层折成 400 `invalid_request`）。
     */
    fun parseIncoming(content: String): LanTransferIncoming {
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
        val profilesRaw = json["profiles"] as? List<*> ?: emptyList<Any?>()

        // 整设备写入的**分层**拒绝矩阵（2026-11-03 起 full+profiles 放行为整份恢复）：
        // 1. `backupType: full` + 非空 profiles → 整份快照恢复（Dart 旧版经
        //    `_overwrite → importFullAppDataBackup` 本来就支持，bf09a7c3 一刀切时被误伤）；
        // 2. `backupType: full` 但 profiles 为空 → 拒：整份备份的壳里没有可恢复内容；
        // 3. `scope: all_data` 且非 full → 拒：bf09a7c3 修的正是这个绕过形状——非全量
        //    信封却声称整设备作用域，`_replaceRulesAndLocations` 判 scope 不看数组，
        //    一次 200 会把全设备的规则 / 分组清空；
        // 4. profiles 非空但非 full → 拒：要么静默丢掉其它档案，要么明确拒（不变）。
        if (isFullBackup) {
            if (profilesRaw.isEmpty()) throw FormatException("use_profile_backup_not_full")
        } else if (scope == TransferScope.ALL_DATA) {
            throw FormatException("use_profile_backup_not_full")
        } else if (profilesRaw.isNotEmpty()) {
            throw FormatException(ERROR_PROFILE_BACKUP_PROFILES_UNSUPPORTED)
        }
        val profiles = if (isFullBackup) parseWholeProfiles(profilesRaw) else emptyList()

        val courses = parseTransferList("course", json["courses"], Course::fromJson).map { course ->
            course.copy(color = normalizeLanCourseColor(course.color))
        }
        // 设置保留**原始文档**：模型层只认识时间/周次五键，落盘却要整份写回
        // （见 [settingsApplyPatch]）。结构门已经保证它是对象且五键能解析。
        val rawSettings = (json["settings"] as? Map<*, *>)?.let { raw ->
            val out = LinkedHashMap<String, Any?>(raw.size)
            for ((key, value) in raw) if (key is String) out[key] = value
            out
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
            profiles = profiles,
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
                settings = parseSettings(rawSettings),
                settingsJson = rawSettings,
            ),
        )
    }

    /**
     * 整份备份的档案表解析（Dart `TransferPackage.fromJson` 对 profiles 走
     * `_parseList(TimetableProfile.fromJson)` 的严格口径：任一档案模型层解析失败
     * 整份拒，折成 `transfer_profile_invalid`）。档案内嵌课程的颜色同样过
     * [normalizeLanCourseColor]——整份恢复会把它们写进本机课表，最终被浏览器
     * 渲染，注入面与顶层课程相同。
     */
    private fun parseWholeProfiles(rawProfiles: List<*>): List<TimetableProfile> {
        val out = ArrayList<TimetableProfile>(rawProfiles.size)
        for (item in rawProfiles) {
            if (item !is Map<*, *>) throw FormatException("transfer_profile_invalid")
            @Suppress("UNCHECKED_CAST")
            val profile = try {
                TimetableProfile.fromJson(item as Map<String, Any?>)
            } catch (_: Exception) {
                throw FormatException("transfer_profile_invalid")
            }
            out += profile.copy(
                courses = profile.courses.map { it.copy(color = normalizeLanCourseColor(it.color)) },
            )
        }
        return out
    }

    /** Dart `LanEditProviderHost.normalizeLanCourseColor`：只认 `#RRGGBB`（可省 `#`），其余回落默认色。 */
    fun normalizeLanCourseColor(raw: Any?): String {
        val text = raw as? String ?: return DEFAULT_LAN_COURSE_COLOR
        val match = LAN_COURSE_COLOR_PATTERN.matchEntire(text.trim()) ?: return DEFAULT_LAN_COURSE_COLOR
        return "#" + match.groupValues[1].uppercase()
    }

    private fun parseSettings(raw: Map<String, Any?>?): TimetableSettings? {
        if (raw == null) return null
        return try {
            TimetableSettings.fromJson(raw)
        } catch (_: Exception) {
            null
        }
    }

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

        val currentSettings = current.settings
        val incomingSettings = incoming.settings
        if (scope.carriesSettings && currentSettings != null && incomingSettings != null) {
            // 两侧都有原始文档时按整份比（Dart 比的就是完整 TimetableSettings.toJson）；
            // 只有一侧有（单测直接构造模型）才退回已移植五键，避免把「没带原文」
            // 误判成「设置全被清空」。信任锚在写入时保留本机值，差异里也不该报。
            val useRawDocuments = current.settingsJson != null && incoming.settingsJson != null
            val before = if (useRawDocuments) {
                normalizeSettingsDocument(current.settingsJson!!)
            } else {
                currentSettings.toJson()
            }
            val after = if (useRawDocuments) {
                normalizeSettingsDocument(incoming.settingsJson!!)
            } else {
                incomingSettings.toJson()
            }
            val changes = if (sameJson(before, after)) {
                emptyList()
            } else {
                listOf(
                    LanTransferChange(
                        kind = LanTransferKind.SETTINGS,
                        type = LanTransferChangeType.UPDATED,
                        id = "settings",
                        label = "settings",
                        before = before,
                        after = after,
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
        currentProfiles: List<TimetableProfile> = emptyList(),
    ): Map<String, Any?> {
        val mergeDiff: LanTransferDiff
        val overwriteDiff: LanTransferDiff
        if (incoming.isWholeRestore) {
            // 整份恢复的预演：档案表 + 三张设备级表（整表替换口径，报删除）。
            // 顶层课程 / 作业等列表在全量包里恒为空，逐类比过去只会得到全 0 行。
            val whole = wholeRestoreDiff(currentProfiles, incoming.profiles, current, incoming.source)
            mergeDiff = whole
            overwriteDiff = whole
        } else {
            mergeDiff = compare(current, incoming.source, incoming.scope, TransferApplyMode.MERGE)
            overwriteDiff = compare(current, incoming.source, incoming.scope, TransferApplyMode.OVERWRITE)
        }
        return linkedMapOf(
            "transferId" to incoming.packageId,
            "channel" to incoming.channel.value,
            "scope" to incoming.scope.value,
            "mergeDiff" to mergeDiff.toJson(),
            "overwriteDiff" to overwriteDiff.toJson(),
            "diff" to overwriteDiff.toJson(),
            // 网页端据此隐藏「合并」按钮：整份恢复只有覆盖一种语义。
            "wholeRestore" to incoming.isWholeRestore,
        )
    }

    /**
     * 整份恢复的差异：**档案表按档案粒度**（增 / 删 / 内容变），三张设备级表
     * （作息模板 / 日期规则 / 地点分组）按实体粒度整表替换比对（报删除——
     * 恢复后本机表就是包里那张，包外的条目确实会消失）。
     *
     * 全量包的顶层课程 / 作业 / 考试 / 日程 / 设置恒为空（导出侧不带），不比。
     */
    fun wholeRestoreDiff(
        currentProfiles: List<TimetableProfile>,
        incomingProfiles: List<TimetableProfile>,
        current: LanTransferDiffSource,
        incoming: LanTransferDiffSource,
    ): LanTransferDiff {
        val currentById = currentProfiles.associateBy { it.id }
        val incomingById = incomingProfiles.associateBy { it.id }
        val profileChanges = ArrayList<LanTransferChange>()
        for (profile in incomingProfiles) {
            val before = currentById[profile.id]
            if (before == null) {
                profileChanges += LanTransferChange(
                    kind = LanTransferKind.PROFILES,
                    type = LanTransferChangeType.ADDED,
                    id = profile.id,
                    label = profile.name,
                )
            } else if (!sameJson(before.toJson(), profile.toJson())) {
                profileChanges += LanTransferChange(
                    kind = LanTransferKind.PROFILES,
                    type = LanTransferChangeType.UPDATED,
                    id = profile.id,
                    label = profile.name,
                    before = before.toJson(),
                    after = profile.toJson(),
                )
            }
        }
        for (profile in currentProfiles) {
            if (profile.id !in incomingById) {
                profileChanges += LanTransferChange(
                    kind = LanTransferKind.PROFILES,
                    type = LanTransferChangeType.REMOVED,
                    id = profile.id,
                    label = profile.name,
                    before = profile.toJson(),
                )
            }
        }
        val summaries = ArrayList<LanTransferEntityDiff>()
        if (profileChanges.isNotEmpty()) {
            summaries += LanTransferEntityDiff(LanTransferKind.PROFILES, profileChanges)
        }
        // 三张设备级表：整表替换，报删除。与 compare() 的 reportRemovals 口径一致，
        // 但不经过它——那条按 mode 判，整份恢复无论 mode 都是整表替换。
        summaries += compareList(
            LanTransferKind.TIME_SCHEMES,
            current.timeSchemes.map { entityOf(it.id, it.name, it.toJson()) },
            incoming.timeSchemes.map { entityOf(it.id, it.name, it.toJson()) },
            reportRemovals = true,
        )
        summaries += compareList(
            LanTransferKind.TIME_RULES,
            current.scheduleDateRules.map { entityOf(it.id, it.name, it.toJson()) },
            incoming.scheduleDateRules.map { entityOf(it.id, it.name, it.toJson()) },
            reportRemovals = true,
        )
        summaries += compareList(
            LanTransferKind.LOCATIONS,
            current.locationTimeGroups.map { entityOf(it.id, it.name, it.toJsonMap()) },
            incoming.locationTimeGroups.map { entityOf(it.id, it.name, it.toJsonMap()) },
            reportRemovals = true,
        )
        return LanTransferDiff(mode = TransferApplyMode.OVERWRITE, summaries = summaries)
    }

    // -----------------------------------------------------------------------
    // 整份恢复：引用校验与状态等价
    // -----------------------------------------------------------------------

    /**
     * 整份恢复的**包内自洽**校验（Dart 的手机端整份恢复不做引用校验——整表替换后
     * 引用天然指向包内；但局域网来源不可信，手工拼包可能把考试指向不存在的课，
     * 恢复后那门考试在界面上永远点不开。错误码沿用单档案路径的词表，id 加
     * 档案前缀定位：`exam_course_missing:<profileId>/<examId>`）。
     *
     * 顺序：逐档案（考试 → 作业 → 课程模板覆盖）→ 日期规则 → 地点分组。
     */
    fun collectWholeRestoreReferenceErrors(incoming: LanTransferIncoming): List<String> {
        val schemeIds = incoming.source.timeSchemes.mapTo(HashSet()) { it.id }
        val errors = ArrayList<String>()
        for (profile in incoming.profiles) {
            val courseIds = profile.courses.mapTo(HashSet()) { it.id }
            for (exam in profile.exams) {
                if (exam.courseId !in courseIds) {
                    errors += "exam_course_missing:${profile.id}/${exam.id}"
                }
            }
            for (task in profile.tasks) {
                val courseId = task.courseId ?: continue
                if (courseId !in courseIds) errors += "task_course_missing:${profile.id}/${task.id}"
            }
            for (course in profile.courses) {
                val schemeId = course.timeSchemeIdOverride
                if (schemeId != null && schemeId.isNotEmpty() && schemeId !in schemeIds) {
                    errors += "course_scheme_missing:${profile.id}/${course.id}"
                }
            }
        }
        for (rule in incoming.source.scheduleDateRules) {
            if (rule.timeSchemeId.isEmpty() || rule.timeSchemeId !in schemeIds) {
                errors += "time_rule_scheme_missing:${rule.id}"
            }
        }
        for (group in incoming.source.locationTimeGroups) {
            if (group.timeSchemeId.isEmpty() || group.timeSchemeId !in schemeIds) {
                errors += "location_scheme_missing:${group.id}"
            }
        }
        return errors
    }

    /**
     * 整份恢复撤销的**全有或全无**判据：当前现场是否仍与「导入后」完全一致
     * （档案表 + 激活档案 + 各实体表 + 设置 + 当前周）。
     *
     * 为什么不做部分撤销：撤销点存的是**整台设备**的档案表，用户导入后若动过
     * 任何一个档案，「按实体回退」需要跨多档案的三方比对机器——那套机器目前
     * 只对单档案存在（[LanTransferUndoLogic.plan]）。与其静默覆盖用户后来的
     * 操作（Dart 整份恢复撤销的做法），不如明确拒绝并让人话解释。
     */
    fun wholeRestoreStateEquals(left: LanTransferState, right: LanTransferState): Boolean {
        if (left.activeProfileId != right.activeProfileId) return false
        if (left.currentWeek != right.currentWeek) return false
        if (!sameJson(left.settings.toJson(), right.settings.toJson())) return false
        if (left.profiles.size != right.profiles.size) return false
        val rightById = right.profiles.associateBy { it.id }
        for (profile in left.profiles) {
            val other = rightById[profile.id] ?: return false
            if (!sameJson(profile.toJson(), other.toJson())) return false
        }
        return listsEqualById(left.timeSchemes, right.timeSchemes, TimeScheme::id, TimeScheme::toJson) &&
            listsEqualById(
                left.scheduleDateRules,
                right.scheduleDateRules,
                ScheduleDateRule::id,
                ScheduleDateRule::toJson,
            ) &&
            listsEqualById(
                left.locationTimeGroups,
                right.locationTimeGroups,
                LocationTimeGroup::id,
                LocationTimeGroup::toJsonMap,
            )
    }

    /** 按 id 一一对应的规范化 JSON 相等（顺序也算：整表替换连顺序一起写）。 */
    private fun <T> listsEqualById(
        left: List<T>,
        right: List<T>,
        idOf: (T) -> String,
        jsonOf: (T) -> Map<String, Any?>,
    ): Boolean {
        if (left.size != right.size) return false
        return left.zip(right).all { (l, r) ->
            idOf(l) == idOf(r) && sameJson(jsonOf(l), jsonOf(r))
        }
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

    /**
     * 设备级信任锚的键名（Dart `TimetableSettings.keepingDeviceTrustAnchorsFrom`）。
     *
     * 这两个键决定「自动更新清单从哪取」「APK 允许从哪个主机下载」，夹在设置里
     * 一起传输。局域网的 `POST /api/v1/import/apply` 属于携带设置的作用域，
     * 若整份写回外来设置，配对端就能把机主更新通道指向攻击者域名——而清单摘要
     * 与下载地址又同源，「摘要与 URL 同源」的完整性校验会变成自证。故一律保留本机值。
     */
    val DEVICE_TRUST_ANCHOR_KEYS: Set<String> = setOf(
        "appUpdateMirrorPreset",
        "appUpdateMirrorUrlPrefix",
    )

    /**
     * 设置文档的比较口径：去掉设备级信任锚（写入时保留本机值）与 null 值键
     * （Dart `toJson` 对 null 是省略；合并写为了能删键会显式留 null，两者读侧等价）。
     */
    fun normalizeSettingsDocument(settings: Map<String, Any?>): Map<String, Any?> =
        withoutNullValues(withoutDeviceTrustAnchors(settings))

    /** null 值键与缺键在读侧等价（`LenientJson.*(null) ?? 默认值`），比较前一并抹平。 */
    fun withoutNullValues(settings: Map<String, Any?>): Map<String, Any?> {
        if (settings.values.none { it == null }) return settings
        val out = LinkedHashMap<String, Any?>(settings.size)
        for ((key, value) in settings) {
            if (value != null) out[key] = value
        }
        return out
    }

    /** 去掉设备级信任锚，其余键原样（Dart 里等价于写回时取本机那两项）。 */
    fun withoutDeviceTrustAnchors(settings: Map<String, Any?>): Map<String, Any?> {
        if (settings.keys.none { it in DEVICE_TRUST_ANCHOR_KEYS }) return settings
        val out = LinkedHashMap<String, Any?>(settings.size)
        for ((key, value) in settings) {
            if (key !in DEVICE_TRUST_ANCHOR_KEYS) out[key] = value
        }
        return out
    }

    /**
     * 外来的**完整设置文档** → 真正要写盘的合并补丁。
     *
     * - 剔除设备级信任锚（[withoutDeviceTrustAnchors]）；
     * - 模板引用被 [remapSettingsScheme] 改写时，用改写后的 `activeTimeSchemeId`
     *   覆盖原文——包里引用的是发送端模板 id，直接写回会指向本机不存在的模板。
     *
     * 返回空补丁表示「这份包没有可写回的设置键」（正常不会发生：携带设置的作用域
     * 在结构门里要求 settings 非空）。
     */
    fun settingsApplyPatch(
        raw: Map<String, Any?>,
        remapped: TimetableSettings,
    ): Map<String, Any?> {
        val patch = LinkedHashMap(withoutDeviceTrustAnchors(raw))
        val rawScheme = raw["activeTimeSchemeId"] as? String
        if (remapped.activeTimeSchemeId != rawScheme) {
            // 显式 null = 删除该键（`TimetableStore.saveSettingsPatch` 的合并写语义）。
            patch["activeTimeSchemeId"] = remapped.activeTimeSchemeId
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
     * 设置文档的原始 JSON（Dart 侧 250+ 键）。[settings] 只是时间/周次五键的投影，
     * 落盘与差异都必须用这一份，否则包里其余设置会被静默丢掉。
     * null = 调用方没提供原文（纯逻辑单测直接构造模型时的兼容路径）。
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
    /**
     * 解析好的档案表，**只在整份恢复包**（`backupType: full` + 非空 profiles）里非空。
     * 内嵌课程颜色已过 [LanTransferLogic.normalizeLanCourseColor]。
     */
    val profiles: List<TimetableProfile> = emptyList(),
    /** 结构诊断（`transfer_package_empty` 一类）：可预览，应用时折成 `applied: false`。 */
    val diagnostics: List<String>,
    val warnings: List<String>,
    val source: LanTransferDiffSource,
) {
    /** 整份快照恢复包：full + 至少一份档案（Dart `_overwrite` 走 `importFullAppDataBackup` 的同一判据）。 */
    val isWholeRestore: Boolean get() = isFullBackup && profiles.isNotEmpty()
}

/**
 * Dart `TransferEntityKind.value` 原样（顺序 = `TransferDiff.allKinds`）。
 *
 * [PROFILES] 是 Kotlin 侧扩展（整份恢复的差异以档案为粒度），**不在** [all] 里：
 * Dart 的 `TransferDiff.allKinds` 冻结为 8 类，普通导入的 `summaries` 输出必须
 * 与 Dart 逐字同形；PROFILES 只在整份恢复的差异里出现（见 [LanTransferDiff.toJson]）。
 */
enum class LanTransferKind(val value: String) {
    COURSES("courses"),
    EXAMS("exams"),
    TIME_RULES("time_rules"),
    LOCATIONS("locations"),
    TASKS("tasks"),
    SCHEDULE_ITEMS("schedule_items"),
    TIME_SCHEMES("time_schemes"),
    SETTINGS("settings"),
    PROFILES("profiles");

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

    fun toJson(): Map<String, Any?> {
        // PROFILES 不在 all 里（保持普通导入与 Dart 同形）；整份恢复的差异带它时排在首位。
        val ordered = summaries.filter { it.kind == LanTransferKind.PROFILES } +
            LanTransferKind.all.map { forKind(it) }
        return linkedMapOf(
            "mode" to LanTransferLogic.modeName(mode),
            "added" to addedCount,
            "updated" to updatedCount,
            "removed" to removedCount,
            "total" to totalCount,
            "summaries" to ordered.map { it.toJson() },
        )
    }
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
