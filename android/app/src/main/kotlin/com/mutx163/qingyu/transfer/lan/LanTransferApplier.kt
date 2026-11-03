package com.mutx163.qingyu.transfer.lan

import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.share.TransferApplyMode
import com.mutx163.qingyu.share.TransferEnvelope
import com.mutx163.qingyu.share.TransferScope
import com.mutx163.qingyu.share.carriesSettings
import com.mutx163.qingyu.share.overwriteUsesMergeSemantics
import com.mutx163.qingyu.transfer.syncImportedCourses

/**
 * 局域网 `import/preview` 与 `import/apply` 两个端点的**执行层**：
 * 把 [LanTransferLogic] 算出的结果真正写进 [TimetableRepository]。
 *
 * ## 为什么与纯逻辑分层
 *
 * 「包能不能收」「差异是什么」是纯函数，L0 里不该被迫准备存储；而
 * 「写哪几个入口、失败怎么回滚」必须贴着真仓储。分成两层之后，
 * 两边都能各自被钉死。
 *
 * ## 写盘顺序（决定回滚覆盖面）
 *
 * 1. 时间模板（`_mergeTimeSchemes` 的数序：同 id 更新 / 同签名复用 / 新签名创建）；
 * 2. `scheduleItems` 先写内存，再随 `replaceActiveProfileContent` 一次落盘
 *    （课 / 作业 / 考试 / 日程四块一次写、一次通知 —— 见仓储该方法的说明）；
 * 3. 设置（只有 `scope.carriesSettings` 才写，且只写已移植的时间/周次子集）；
 * 4. 当前周；5. 日期规则；6. 地点分组。
 *
 * ## 回滚为什么是「尽力补偿」而不是「事务」
 *
 * Dart `applyToProvider` 在 `runMutationExclusive` 里做「快照 → 应用 → 失败 `_restore`」，
 * 但它底下的 provider 是「先改内存、后写盘」，必须在失败时手工补偿。
 * Kotlin 仓储的每个入口都是**先落盘、成功才改内存**（不会留下「盘新内存旧」），
 * 缺的是「一次性提交全部实体」的入口（属 `platform:`/`app:` 共享件，本批不越界改）。
 * 所以这里按 Dart 的同一思路做**尽力补偿**：任何一步抛错 → 用快照把
 * 课/作业/考试/日程/设置/当前周/规则/分组/模板写回；补偿自身失败不上抛，
 * 以免盖住「这次导入没成功」这个更重要的事实。
 */
class LanTransferApplier(
    private val repository: TimetableRepository,
    /** 撤销点索引；局域网服务传 [LanTransferUndoStore.shared]，测试各自建独立实例。 */
    private val undoStore: LanTransferUndoStore = LanTransferUndoStore(),
    private val clock: () -> Long = System::currentTimeMillis,
) {

    /** 本地当前状态（差异的 current 侧）。 */
    fun currentSource(): LanTransferDiffSource {
        val snapshot = repository.snapshot
        return LanTransferDiffSource(
            courses = snapshot.courses,
            tasks = repository.tasks,
            scheduleItems = snapshot.scheduleItems,
            exams = repository.exams,
            timeSchemes = snapshot.timeSchemes,
            scheduleDateRules = snapshot.scheduleDateRules,
            locationTimeGroups = snapshot.locationTimeGroups,
            settings = snapshot.settings,
        )
    }

    /**
     * Dart `LanEditProviderHost.previewTransferJson`：解析 → 拒整设备写入 → 算 merge / overwrite 两套差异。
     *
     * @throws com.mutx163.qingyu.core.FormatException 包结构不合法（路由层折成 400）。
     */
    fun preview(content: String): Map<String, Any?> {
        val incoming = LanTransferLogic.parseIncoming(content)
        return LanTransferLogic.previewJson(
            incoming,
            currentSource(),
            currentProfiles = repository.snapshot.profiles,
        )
    }

    /**
     * Dart `_handleTransferApply`：**先校验后落盘**。
     *
     * - 结构门 / 整设备写入 → 抛 [com.mutx163.qingyu.core.FormatException]（路由层 400）；
     * - 结构诊断（空包一类）或本地引用对不上 → 回 `applied: false` + 错误码，**一个字节不写**；
     * - 整份恢复包（`backupType: full` + profiles）→ 走 [applyWholeRestore]；
     * - 正常路径 → 真写仓储；写失败 → 尽力补偿后回 `applied: false` + `transfer_import_failed`。
     */
    fun apply(content: String, mode: TransferApplyMode): Map<String, Any?> {
        val incoming = LanTransferLogic.parseIncoming(content)
        if (incoming.isWholeRestore) return applyWholeRestore(incoming, mode)
        val current = currentSource()
        val diff = LanTransferLogic.compare(current, incoming.source, incoming.scope, mode)

        val errors = ArrayList<String>(incoming.diagnostics)
        errors += LanTransferLogic.collectReferenceErrors(incoming.source, current)
        if (errors.isNotEmpty()) {
            return LanTransferLogic.applyResultJson(false, mode, diff, errors.first(), null)
        }

        val before = captureState()
        return try {
            applyIncoming(incoming, current, mode)
            // 导入成功后立刻再抓一份现场。撤销靠「导入前 / 导入后」两份比对，才能
            // 判断某条数据是这次导入写的、之后有没有被用户改过（见 LanTransferUndoLogic）。
            val token = LanTransferUndoToken(
                id = TransferEnvelope.newPackageId(nowMicros = clock() * 1000L),
                profileId = repository.snapshot.activeProfileId,
                mode = mode,
                scope = incoming.scope,
                before = before,
                after = captureState(),
                createdAtMillis = clock(),
            )
            undoStore.create(token)
            LanTransferLogic.applyResultJson(true, mode, diff, null, token.id)
        } catch (_: Exception) {
            restoreState(before)
            LanTransferLogic.applyResultJson(false, mode, diff, "transfer_import_failed", null)
        }
    }

    /**
     * 整份快照恢复（`backupType: full` + 非空 profiles；Dart 手机端
     * `importFullAppDataBackup` 的同款语义，2026-11-03 起局域网放行）。
     *
     * - **只有覆盖一种语义**：档案表无法按 id 跨设备合并（同 id 在两端是两张不同的
     *   课表），merge 请求明确拒，不给「看起来成功、档案却没进去」的假象；
     * - **先校验后落盘**：包内引用对不上 → `applied: false` + 错误码，一个字节不写；
     * - **一次落盘**：档案表 + 激活档案 + 设置 + 当前周 + 三张设备级表走仓储的
     *   整份恢复入口（先全部落盘、成功才改内存并只通知一次），全局设置与当前周
     *   取自包里激活档案的内嵌值；`activeProfileId` 指不到包内档案时回落第一份
     *   （与 Dart 同口径）；
     * - **撤销点**：before / after 各抓一份**含档案表**的现场；导入后数据被动过
     *   就拒绝撤销（见 [undo]），不会静默覆盖用户之后的操作。
     */
    private fun applyWholeRestore(incoming: LanTransferIncoming, mode: TransferApplyMode): Map<String, Any?> {
        val diff = LanTransferLogic.wholeRestoreDiff(
            currentProfiles = repository.snapshot.profiles,
            incomingProfiles = incoming.profiles,
            current = currentSource(),
            incoming = incoming.source,
        )
        if (mode != TransferApplyMode.OVERWRITE) {
            return LanTransferLogic.applyResultJson(
                false,
                mode,
                diff,
                "transfer_full_backup_requires_overwrite",
                null,
            )
        }
        val errors = ArrayList<String>(incoming.diagnostics)
        errors += LanTransferLogic.collectWholeRestoreReferenceErrors(incoming)
        if (errors.isNotEmpty()) {
            return LanTransferLogic.applyResultJson(false, mode, diff, errors.first(), null)
        }

        val before = captureState(includeProfiles = true)
        return try {
            repository.restoreFromCloudSnapshot(
                profiles = incoming.profiles,
                activeProfileId = incoming.activeProfileId,
                timeSchemes = incoming.source.timeSchemes,
                scheduleDateRules = incoming.source.scheduleDateRules,
                locationTimeGroups = incoming.source.locationTimeGroups,
            )
            val token = LanTransferUndoToken(
                id = TransferEnvelope.newPackageId(nowMicros = clock() * 1000L),
                // 整份恢复可能合法地切换激活档案，「导入时档案 ≠ 当前档案」不构成拒绝
                // 撤销的理由；档案表比对（wholeRestoreStateEquals）已覆盖这层安全。
                profileId = null,
                mode = mode,
                scope = incoming.scope,
                before = before,
                after = captureState(includeProfiles = true),
                createdAtMillis = clock(),
            )
            undoStore.create(token)
            LanTransferLogic.applyResultJson(true, mode, diff, null, token.id)
        } catch (_: Exception) {
            restoreState(before)
            LanTransferLogic.applyResultJson(false, mode, diff, "transfer_import_failed", null)
        }
    }

    /**
     * 按撤销点 id 回退这次导入写入的内容（`POST /api/v1/import/undo` 的执行层）。
     *
     * - **只回退这一批**：每类实体按 id 比「导入前 / 导入后 / 现在」，只还原仍是
     *   「导入后」值的条目；用户导入之后改过的一律保留。判据只有
     *   [LanTransferUndoLogic.plan] 一处。
     * - **整份恢复的撤销是全有或全无**：导入后任何档案 / 设备表被动过 →
     *   `transfer_undo_state_changed`，不消费撤销点（把现场改回去还能再撤）；
     *   现场没动过 → 整份写回「导入前」（判据 [LanTransferLogic.wholeRestoreStateEquals]）。
     * - **取走即消费**：同一个撤销点不会被应用两次；第二次调用回
     *   `transfer_undo_already_undone` 且一个字节都不写。
     * - **缺失安全跳过**：不认识的 id 回 `transfer_undo_token_missing`，不写盘。
     */
    fun undo(transferId: String): Map<String, Any?> {
        val id = transferId.trim()
        if (id.isEmpty()) {
            return LanTransferUndoLogic.resultJson(false, "", error = "transfer_id_required")
        }
        val token = undoStore.take(id)
        if (token == null) {
            val reason = if (undoStore.isConsumed(id)) {
                "transfer_undo_already_undone"
            } else {
                "transfer_undo_token_missing"
            }
            return LanTransferUndoLogic.resultJson(false, id, error = reason)
        }
        val isWholeRestore = token.before.profiles.isNotEmpty()
        if (isWholeRestore) {
            val current = captureState(includeProfiles = true)
            if (!LanTransferLogic.wholeRestoreStateEquals(current, token.after)) {
                // 导入之后用户（或下一次导入）动过数据：撤销点放回，用户把现场改回去
                // 后还能再撤——「拒绝」不该烧掉撤销机会。
                undoStore.restore(token)
                return LanTransferUndoLogic.resultJson(false, id, error = "transfer_undo_state_changed")
            }
            return try {
                repository.restoreFromCloudSnapshot(
                    profiles = token.before.profiles,
                    activeProfileId = token.before.activeProfileId,
                    timeSchemes = token.before.timeSchemes,
                    scheduleDateRules = token.before.scheduleDateRules,
                    locationTimeGroups = token.before.locationTimeGroups,
                    settings = token.before.settings,
                )
                LanTransferUndoLogic.resultJson(
                    undone = true,
                    transferId = id,
                    restoredCounts = mapOf("profiles" to token.before.profiles.size),
                )
            } catch (_: Exception) {
                // 撤销途中写盘失败：把令牌放回索引，用户还能再试一次。
                undoStore.restore(token)
                LanTransferUndoLogic.resultJson(false, id, error = "transfer_undo_failed")
            }
        }
        // 撤销点记的是导入时那个档案；换了档案再撤销等于拿 A 课表的快照写 B 课表。
        val activeProfileId = repository.snapshot.activeProfileId
        if (token.profileId != null && activeProfileId != null && token.profileId != activeProfileId) {
            undoStore.restore(token)
            return LanTransferUndoLogic.resultJson(false, id, error = "transfer_undo_profile_changed")
        }
        val plan = LanTransferUndoLogic.plan(captureState(), token)
        if (!plan.hasChanges) {
            // 导入没有实际改变数据，或用户已经把每一处都改回去了：不算失败，也不写盘。
            return LanTransferUndoLogic.resultJson(true, id)
        }
        return try {
            val skipped = executeUndo(plan)
            LanTransferUndoLogic.resultJson(
                undone = true,
                transferId = id,
                restoredCounts = plan.restoredCounts,
                skipped = skipped,
            )
        } catch (_: Exception) {
            // 撤销途中写盘失败：把令牌放回索引，用户还能再试一次（不放回等于吞掉撤销机会）。
            undoStore.restore(token)
            LanTransferUndoLogic.resultJson(false, id, error = "transfer_undo_failed")
        }
    }

    /** 执行反向补丁。返回被跳过的模板说明（删除被引用拒绝 / 节次数低于已用最大节次）。 */
    private fun executeUndo(plan: LanTransferUndoPlan): List<String> {
        val snapshot = repository.snapshot
        if (plan.courses != null || plan.tasks != null || plan.exams != null || plan.scheduleItems != null) {
            // 与 apply 同序：日程先写内存，再由 replaceActiveProfileContent 一次落盘。
            repository.scheduleItems = plan.scheduleItems ?: snapshot.scheduleItems
            repository.replaceActiveProfileContent(
                plan.courses ?: snapshot.courses,
                plan.tasks ?: repository.tasks,
                plan.exams ?: repository.exams,
            )
        }
        plan.settings?.let { repository.updateSettings(it) }
        plan.currentWeek?.let { repository.setCurrentWeek(it) }
        plan.scheduleDateRules?.let { repository.updateScheduleDateRules(it) }
        plan.locationTimeGroups?.let { repository.updateLocationTimeGroups(it) }

        val skipped = ArrayList<String>()
        for (schemeId in plan.timeSchemesToDelete) {
            if (!repository.deleteTimeScheme(schemeId)) skipped += "time_scheme_delete_refused:$schemeId"
        }
        for (scheme in plan.timeSchemesToRestore) {
            val error = repository.updateTimeScheme(scheme.id, scheme.name, scheme.sections)
            if (error != null) skipped += "time_scheme_restore_failed:${scheme.id}:$error"
        }
        return skipped
    }

    // -----------------------------------------------------------------------
    // 执行
    // -----------------------------------------------------------------------

    private fun applyIncoming(
        incoming: LanTransferIncoming,
        current: LanTransferDiffSource,
        mode: TransferApplyMode,
    ) {
        val packageSource = incoming.source
        val schemeIdMap = executeTimeSchemes(packageSource.timeSchemes)
        val incomingCourses = LanTransferLogic.remapCourseSchemes(packageSource.courses, schemeIdMap)
        val incomingRules = LanTransferLogic.remapScheduleDateRules(packageSource.scheduleDateRules, schemeIdMap)
        val incomingGroups = LanTransferLogic.remapLocationTimeGroups(packageSource.locationTimeGroups, schemeIdMap)
        val incomingSettings = packageSource.settings?.let {
            LanTransferLogic.remapSettingsScheme(it, schemeIdMap)
        }

        // Dart `_overwrite`：局部作用域的「覆盖」其实走合并语义（不删包边界外的数据）。
        val mergeSemantics = mode == TransferApplyMode.MERGE ||
            incoming.scope.overwriteUsesMergeSemantics

        val nextCourses: List<Course>
        val nextTasks: List<CourseTask>
        val nextExams: List<Exam>
        if (mergeSemantics) {
            // Dart 的合并走 `importParsedCourses` → `syncImportedCourses`（软匹配、保留本地 id）。
            val synced = syncImportedCourses(current.courses, incomingCourses, preserveLocalColors = true)
            val courseIdMap = synced.importedIdToLocalId
            nextCourses = synced.mergedCourses
            nextTasks = LanTransferLogic.mergeById(
                current.tasks,
                remapTaskCourses(packageSource.tasks, courseIdMap),
            ) { it.id }
            nextExams = LanTransferLogic.mergeById(current.exams, packageSource.exams) { it.id }
        } else {
            nextCourses = incomingCourses
            nextTasks = packageSource.tasks
            nextExams = packageSource.exams
        }

        // Dart `_merge` 在写入前对作业/考试指向的课程做存在性校验（软匹配换了 id 之后）。
        val localCourseIds = HashSet<String>(nextCourses.size)
        nextCourses.mapTo(localCourseIds) { it.id }
        for (task in nextTasks) {
            val courseId = task.courseId ?: continue
            if (courseId !in localCourseIds) throw IllegalStateException("task_course_missing:${task.id}")
        }
        for (exam in nextExams) {
            if (exam.courseId !in localCourseIds) throw IllegalStateException("exam_course_missing:${exam.id}")
        }

        val nextScheduleItems = if (mergeSemantics) {
            LanTransferLogic.mergeById(current.scheduleItems, packageSource.scheduleItems) { it.id }
        } else {
            packageSource.scheduleItems
        }

        // 课/作业/考试/日程：日程先写内存，再由下面这一次落盘一并写完。
        repository.scheduleItems = nextScheduleItems
        repository.replaceActiveProfileContent(nextCourses, nextTasks, nextExams)

        if (incomingSettings != null && incoming.scope.carriesSettings) {
            repository.updateSettings(incomingSettings)
        }
        val week = incoming.currentWeek
        if (week != null &&
            incoming.scope != TransferScope.SELECTED_COURSE &&
            incoming.scope != TransferScope.SELECTED_COURSES
        ) {
            repository.setCurrentWeek(week)
        }
        // Dart `_mergeRulesAndLocations` / `_replaceRulesAndLocations`：外来为空时不动本地。
        if (mergeSemantics) {
            if (incomingGroups.isNotEmpty()) {
                repository.updateLocationTimeGroups(
                    LanTransferLogic.mergeById(current.locationTimeGroups, incomingGroups) { it.id },
                )
            }
            if (incomingRules.isNotEmpty()) {
                repository.updateScheduleDateRules(
                    LanTransferLogic.mergeById(current.scheduleDateRules, incomingRules) { it.id },
                )
            }
        } else {
            if (incomingGroups.isNotEmpty()) repository.updateLocationTimeGroups(incomingGroups)
            if (incomingRules.isNotEmpty()) repository.updateScheduleDateRules(incomingRules)
        }
    }

    /** Dart `_mergeTimeSchemes` 的执行段：返回「外来模板 id → 本地模板 id」。 */
    private fun executeTimeSchemes(incoming: List<TimeScheme>): Map<String, String> {
        if (incoming.isEmpty()) return emptyMap()
        val steps = LanTransferLogic.planTimeSchemes(repository.snapshot.timeSchemes, incoming)
        val idMap = LinkedHashMap<String, String>()
        for (step in steps) {
            when (step) {
                is LanTimeSchemeStep.Update -> {
                    val error = repository.updateTimeScheme(step.localId, step.name, step.sections)
                    if (error != null) throw IllegalStateException(error)
                    idMap[step.localId] = step.localId
                }
                is LanTimeSchemeStep.Reuse -> idMap[step.incomingId] = step.localId
                is LanTimeSchemeStep.Alias -> {
                    val resolved = idMap[step.ownerIncomingId]
                        ?: throw IllegalStateException("time_scheme_alias_unresolved")
                    idMap[step.incomingId] = resolved
                }
                is LanTimeSchemeStep.Create -> {
                    val created = repository.createTimeScheme(step.name, step.sections)
                    idMap[step.incomingId] = created.id
                }
            }
        }
        return idMap
    }

    private fun remapTaskCourses(tasks: List<CourseTask>, courseIdMap: Map<String, String>): List<CourseTask> =
        tasks.map { task ->
            val courseId = task.courseId
            if (courseId == null) {
                task
            } else {
                val mapped = courseIdMap[courseId]
                if (mapped == null || mapped == courseId) task else task.copy(courseId = mapped)
            }
        }

    // -----------------------------------------------------------------------
    // 快照 / 补偿
    // -----------------------------------------------------------------------

    /**
     * 当前仓储现场（导入前 / 导入后 / 撤销前都抓这一份）。
     *
     * [includeProfiles] 只在整份恢复路径传 true：普通导入只动激活档案，
     * 抓全设备档案表只是白占撤销槽的内存。
     */
    private fun captureState(includeProfiles: Boolean = false): LanTransferState {
        val snapshot = repository.snapshot
        return LanTransferState(
            courses = snapshot.courses,
            tasks = repository.tasks,
            exams = repository.exams,
            scheduleItems = snapshot.scheduleItems,
            timeSchemes = snapshot.timeSchemes,
            scheduleDateRules = snapshot.scheduleDateRules,
            locationTimeGroups = snapshot.locationTimeGroups,
            settings = snapshot.settings,
            currentWeek = snapshot.currentWeek,
            profiles = if (includeProfiles) snapshot.profiles else emptyList(),
            activeProfileId = snapshot.activeProfileId,
        )
    }

    /** 尽力补偿：任何一步失败都不上抛（见类注释）。 */
    private fun restoreState(before: LanTransferState) {
        runCatching {
            // 整份恢复的补偿走同一个整份入口：档案表 / 激活档案 / 设置 / 当前周 /
            // 三张设备级表一次写回（先落盘、成功才改内存）。
            if (before.profiles.isNotEmpty()) {
                repository.restoreFromCloudSnapshot(
                    profiles = before.profiles,
                    activeProfileId = before.activeProfileId,
                    timeSchemes = before.timeSchemes,
                    scheduleDateRules = before.scheduleDateRules,
                    locationTimeGroups = before.locationTimeGroups,
                    settings = before.settings,
                )
                return
            }
            repository.scheduleItems = before.scheduleItems
            repository.replaceActiveProfileContent(before.courses, before.tasks, before.exams)
            repository.updateSettings(before.settings)
            repository.setCurrentWeek(before.currentWeek)
            repository.updateScheduleDateRules(before.scheduleDateRules)
            repository.updateLocationTimeGroups(before.locationTimeGroups)

            val keepIds = HashSet<String>(before.timeSchemes.size)
            before.timeSchemes.mapTo(keepIds) { it.id }
            for (scheme in repository.snapshot.timeSchemes) {
                if (scheme.id !in keepIds) repository.deleteTimeScheme(scheme.id)
            }
            for (scheme in before.timeSchemes) {
                val current = repository.snapshot.timeSchemes.firstOrNull { it.id == scheme.id } ?: continue
                if (current.name != scheme.name || current.sections != scheme.sections) {
                    repository.updateTimeScheme(scheme.id, scheme.name, scheme.sections)
                }
            }
        }
    }
}
