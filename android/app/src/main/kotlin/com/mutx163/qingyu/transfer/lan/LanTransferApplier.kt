package com.mutx163.qingyu.transfer.lan

import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimeSchemeLogic
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
 * 1. 时间模板（`_mergeTimeSchemes` 的数序：同 id **只建映射、不改写本机模板** / 同签名复用 / 新签名创建）；
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
    /**
     * 整份设置的读写缝。为 null 时退化为旧的「只写核心四键」路径
     * （JVM 单测与未接线的调用方不受影响）。
     */
    private val settingsStore: LanTransferSettingsStore? = null,
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
            settingsJson = settingsStore?.readSettingsJson(),
        )
    }

    /**
     * Dart `LanEditProviderHost.previewTransferJson`：解析 → 拒整设备写入 → 算 merge / overwrite 两套差异。
     *
     * @throws com.mutx163.qingyu.core.FormatException 包结构不合法（路由层折成 400）。
     */
    fun preview(content: String): Map<String, Any?> {
        val incoming = LanTransferLogic.parseIncoming(content)
        return LanTransferLogic.previewJson(incoming, currentSource())
    }

    /**
     * Dart `_handleTransferApply`：**先校验后落盘**。
     *
     * - 结构门 / 整设备写入 → 抛 [com.mutx163.qingyu.core.FormatException]（路由层 400）；
     * - 结构诊断（空包一类）或本地引用对不上 → 回 `applied: false` + 错误码，**一个字节不写**；
     * - 正常路径 → 真写仓储；写失败 → 尽力补偿后回 `applied: false` + `transfer_import_failed`。
     */
    fun apply(content: String, mode: TransferApplyMode): Map<String, Any?> {
        val incoming = LanTransferLogic.parseIncoming(content)
        val current = currentSource()
        val diff = LanTransferLogic.compare(current, incoming.source, incoming.scope, mode)

        val errors = ArrayList<String>(incoming.diagnostics)
        errors += LanTransferLogic.collectReferenceErrors(incoming.source, current)
        if (errors.isNotEmpty()) {
            return LanTransferLogic.applyResultJson(false, mode, diff, errors.first(), null)
        }

        // `applyIncoming` 在包里带地点分组时会 `resync = true`——那会重排**每一档**的课程钟点，
        // 所以快照要跟着扩到所有档案的课程（否则非活动档半还原，第五轮返工）。
        val resyncsAllProfileCourses = incoming.source.locationTimeGroups.isNotEmpty()
        val before = captureState(includeAllProfileCourses = resyncsAllProfileCourses)
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
                after = captureState(includeAllProfileCourses = resyncsAllProfileCourses),
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
        // 撤销点记的是导入时那个档案；换了档案再撤销等于拿 A 课表的快照写 B 课表。
        val activeProfileId = repository.snapshot.activeProfileId
        if (token.profileId != null && activeProfileId != null && token.profileId != activeProfileId) {
            undoStore.restore(token)
            return LanTransferUndoLogic.resultJson(false, id, error = "transfer_undo_profile_changed")
        }
        // 撤销点里带了「所有档案的课程」时，当前现场也必须按同一口径抓，
        // 否则比较永远不等（空表 vs 全表）⇒ 非活动档的钟点永远不还原。
        val currentState = captureState(
            includeAllProfileCourses = token.after.profileCourses.isNotEmpty(),
        )
        val plan = LanTransferUndoLogic.plan(currentState, token)
        if (!plan.hasChanges) {
            // 导入没有实际改变数据，或用户已经把每一处都改回去了：不算失败，也不写盘。
            return LanTransferUndoLogic.resultJson(true, id)
        }
        return try {
            val executed = executeUndo(plan)
            LanTransferUndoLogic.resultJson(
                undone = true,
                transferId = id,
                // 用执行后**修正过**的计数：仍被引用而保留的模板不算「已撤销」，
                // 同时它们会出现在 skipped/skippedCount 里（第五轮返工）。
                restoredCounts = executed.restoredCounts,
                skipped = executed.skipped,
            )
        } catch (_: Exception) {
            // 撤销途中写盘失败：把令牌放回索引，用户还能再试一次（不放回等于吞掉撤销机会）。
            undoStore.restore(token)
            LanTransferUndoLogic.resultJson(false, id, error = "transfer_undo_failed")
        }
    }

    /**
     * 撤销执行结果：被跳过的条目 + **修正后的** restoredCounts。
     *
     * 为什么 counts 要在这里修：plan 的 counts 是按「计划要撤多少」算的，而执行时
     * 「仍被引用的模板」会被保留（不是撤销失败，但不能算进「已撤销」）。不修就会出现
     * `undone=true` 却少撤一套还不报——第五轮返工。
     */
    private data class UndoExecution(
        val skipped: List<String>,
        val restoredCounts: Map<String, Int>,
    )

    /** 执行反向补丁。 */
    private fun executeUndo(plan: LanTransferUndoPlan): UndoExecution {
        val snapshot = repository.snapshot
        val skipped = ArrayList<String>()
        val counts = LinkedHashMap(plan.restoredCounts)
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
        plan.settingsJson?.let { settingsStore?.writeSettingsPatch(it) }
        // 还原不是「使用」：不改 lastUsedAt。
        plan.currentWeek?.let { repository.restoreCurrentWeek(it) }
        // 三块可选集合按「导入前是否存在」精确还原。
        plan.scheduleDateRules?.let { rules ->
            restoreCollection(
                presentBefore = plan.scheduleDateRulesPresentBefore,
                write = { repository.updateScheduleDateRules(rules) },
                remove = { repository.removeScheduleDateRules() },
            )
        }
        plan.locationTimeGroups?.let { groups ->
            restoreCollection(
                presentBefore = plan.locationTimeGroupsPresentBefore,
                write = { repository.updateLocationTimeGroups(groups) },
                remove = { repository.removeLocationTimeGroups() },
            )
        }
        // 导入若 resync 过所有档案的钟点，这里对称还原每一档。
        plan.profileCourses?.let { restoreProfileCourses(it) }

        // 模板表：**基于当前表重建「撤销后该有的表」再一次整份写回**（2026-11-06 返工）。
        // 不再逐个 delete/update：那样会被「节次低于已用最大节次」的引用校验拒绝（= 半还原），
        // 还会顺手重排课程钟点（撤销不该改时间）。重建只动 plan 涉及的那几套，
        // 导入后用户对其它模板的改动保留（plan 已按「现在仍是导入后值」算好）。
        if (plan.timeSchemesToDelete.isNotEmpty() || plan.timeSchemesToRestore.isNotEmpty()) {
            val now = repository.snapshot
            // 仍被引用的模板**不许删**：旧 `deleteTimeScheme` 有 isSchemeInUse 这道门，
            // 整表写回绕过它会把还被档案/课程/规则/分组引用的模板删掉、留下悬空引用，
            // 而且返回成功。这里补回同一道门（2026-11-06 三轮返工）。
            val kept = plan.timeSchemesToDelete.filter { schemeId ->
                TimeSchemeLogic.isSchemeInUse(
                    profiles = now.profiles,
                    schemeId = schemeId,
                    schemes = now.timeSchemes,
                    locationTimeGroups = now.locationTimeGroups,
                    scheduleDateRules = now.scheduleDateRules,
                )
            }
            val deletable = plan.timeSchemesToDelete - kept.toSet()
            // 少撤的那几套必须**如实报**，并把 counts 扣回去（否则 undone=true 却少数一套）。
            if (kept.isNotEmpty()) {
                for (schemeId in kept) skipped += "time_scheme_delete_refused:$schemeId"
                val adjusted = (counts["time_schemes"] ?: 0) - kept.size
                if (adjusted > 0) counts["time_schemes"] = adjusted else counts.remove("time_schemes")
            }
            // 第三件：没有可删、也没有要写回的模板时，跳过整表写回（不多写一次）。
            if (deletable.isNotEmpty() || plan.timeSchemesToRestore.isNotEmpty()) {
                val next = now.timeSchemes
                    .filterNot { scheme -> scheme.id in deletable }
                    .toMutableList()
                for (scheme in plan.timeSchemesToRestore) {
                    next.removeAll { it.id == scheme.id }
                    next.add(scheme)
                }
                val written = runCatching {
                    restoreCollection(
                        presentBefore = plan.timeSchemesPresentBefore || next.isNotEmpty(),
                        write = { repository.replaceTimeSchemes(next) },
                        remove = { repository.removeTimeSchemes() },
                    )
                }.isSuccess
                if (!written) skipped += "time_scheme_restore_failed"
            }
        }
        return UndoExecution(skipped = skipped, restoredCounts = counts)
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
            // Dart 的 settings 是整份替换；核心四键已由上面写入，这里补齐其余键。
            val raw = packageSource.settingsJson
            val sink = settingsStore
            if (raw != null && sink != null) {
                sink.writeSettingsPatch(LanTransferLogic.settingsReplacePatch(raw, sink.readSettingsJson()))
            }
        }
        val week = incoming.currentWeek
        if (week != null &&
            incoming.scope != TransferScope.SELECTED_COURSE &&
            incoming.scope != TransferScope.SELECTED_COURSES
        ) {
            repository.setCurrentWeek(week)
        }
        // Dart `_mergeRulesAndLocations` / `_replaceRulesAndLocations`：外来为空时不动本地。
        //
        // 两个分支都带 `resync = true`：本函数在 `:260` 已经按**接收方原有分组**写过一遍
        // 课程钟点，这里再把分组换成包里的；不重算就留下「盘上分组已是新楼、课程钟点还是
        // 旧楼」的错配。这正是 `TimetableRepository.updateLocationTimeGroupsLocked` 的
        // KDoc 点名「传输层必须用它」的那条，也是 `LanEditRepositoryHost` 的说明里写的
        // ② 「地点分组变化后按新分组重算课程钟点」。
        if (mergeSemantics) {
            if (incomingGroups.isNotEmpty()) {
                repository.updateLocationTimeGroups(
                    LanTransferLogic.mergeById(current.locationTimeGroups, incomingGroups) { it.id },
                    resync = true,
                )
            }
            if (incomingRules.isNotEmpty()) {
                repository.updateScheduleDateRules(
                    LanTransferLogic.mergeById(current.scheduleDateRules, incomingRules) { it.id },
                )
            }
        } else {
            if (incomingGroups.isNotEmpty()) {
                repository.updateLocationTimeGroups(incomingGroups, resync = true)
            }
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
                is LanTimeSchemeStep.Update ->
                    // 同 id：**只建映射，不改写本机模板**（2026-11-06 返工）。
                    // 旧实现调 updateTimeScheme 会把本机模板的 name/sections 用包里的覆盖，
                    // 用户已有模板被改坏且回滚救不回；方案的三段设计只允许「复用/新建」。
                    idMap[step.localId] = step.localId
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
     * @param includeAllProfileCourses 本次导入会不会 `resync=true`（见 [apply]）；
     *   会的话额外抓**所有档案的课程**——resync 重排的是每一档的钟点，只抓活动档
     *   就会留下「非活动档停在新钟点」的半还原（第五轮返工）。
     */
    private fun captureState(includeAllProfileCourses: Boolean = false): LanTransferState {
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
            settingsJson = settingsStore?.readSettingsJson(),
            currentWeek = snapshot.currentWeek,
            profileCourses = if (includeAllProfileCourses) {
                snapshot.profiles.associate { profile -> profile.id to profile.courses }
            } else {
                emptyMap()
            },
            timeSchemesPresent = repository.isStoredCollectionPresent(TimetableStore.KEY_TIME_SCHEMES),
            scheduleDateRulesPresent = repository.isStoredCollectionPresent(TimetableStore.KEY_SCHEDULE_DATE_RULES),
            locationTimeGroupsPresent = repository.isStoredCollectionPresent(TimetableStore.KEY_LOCATION_TIME_GROUPS),
        )
    }

    /**
     * 三块可选集合的「恢复精确原态」写回：导入前**不存在**就删 key，存在才写快照值。
     * 一律写空数组会凭空多出键（逐字节对比会红，见 `LanTransferApplyTest`）。
     */
    private fun restoreCollection(
        presentBefore: Boolean,
        write: () -> Unit,
        remove: () -> Unit,
    ) {
        if (presentBefore) write() else remove()
    }

    /** 把「所有档案的课程」写回（`profileCourses` 为空 = 本次导入没重排，不动）。 */
    private fun restoreProfileCourses(profileCourses: Map<String, List<Course>>) {
        if (profileCourses.isEmpty()) return
        val activeId = repository.snapshot.activeProfileId
        val profiles = repository.snapshot.profiles.map { profile ->
            val courses = profileCourses[profile.id] ?: profile.courses
            if (courses == profile.courses) profile else profile.copy(courses = courses)
        }
        repository.replaceAllProfiles(profiles, activeId)
    }

    /** 尽力补偿：任何一步失败都不上抛（见类注释）。 */
    private fun restoreState(before: LanTransferState) {
        // 逐步尽力：每步各自 catch、失败继续走完剩余步骤（2026-11-06 返工）。
        // 旧写法是单个 runCatching 包全部——第一笔写挂后面全不还原 = 半还原，
        // 与 transfer 侧 `restoreFromSnapshot` 修成同一口径。
        fun step(block: () -> Unit) {
            runCatching(block)
        }
        step { repository.scheduleItems = before.scheduleItems }
        step { repository.replaceActiveProfileContent(before.courses, before.tasks, before.exams) }
        step { repository.updateSettings(before.settings) }
        val sink = settingsStore
        val beforeJson = before.settingsJson
        if (sink != null && beforeJson != null) {
            step { sink.writeSettingsPatch(LanTransferLogic.settingsReplacePatch(beforeJson, sink.readSettingsJson())) }
        }
        // 还原不是「使用」：走 restoreCurrentWeek（不改 lastUsedAt），别用 setCurrentWeek。
        step { repository.restoreCurrentWeek(before.currentWeek) }
        // 三块可选集合按「导入前是否存在」精确还原（不存在 ⇒ 删 key）。
        step {
            restoreCollection(
                presentBefore = before.scheduleDateRulesPresent,
                write = { repository.updateScheduleDateRules(before.scheduleDateRules) },
                remove = { repository.removeScheduleDateRules() },
            )
        }
        step {
            restoreCollection(
                presentBefore = before.locationTimeGroupsPresent,
                write = { repository.updateLocationTimeGroups(before.locationTimeGroups) },
                remove = { repository.removeLocationTimeGroups() },
            )
        }
        // 模板表整份写回：精确恢复（不受引用校验阻挠、不重排钟点），不再逐个 delete/update。
        step {
            restoreCollection(
                presentBefore = before.timeSchemesPresent,
                write = { repository.replaceTimeSchemes(before.timeSchemes) },
                remove = { repository.removeTimeSchemes() },
            )
        }
        // 导入若 resync 过所有档案的钟点，这里对称还原每一档（只快照了活动档时是空表 ⇒ 不动）。
        step { restoreProfileCourses(before.profileCourses) }
    }
}
