package com.mutx163.qingyu.transfer.lan

import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.LocationTimeGroup
import com.mutx163.qingyu.core.ScheduleDateRule
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.share.TransferApplyMode
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
class LanTransferApplier(private val repository: TimetableRepository) {

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
            return LanTransferLogic.applyResultJson(false, mode, diff, errors.first())
        }

        val before = captureSnapshot()
        return try {
            applyIncoming(incoming, current, mode)
            LanTransferLogic.applyResultJson(true, mode, diff, null)
        } catch (_: Exception) {
            restoreSnapshot(before)
            LanTransferLogic.applyResultJson(false, mode, diff, "transfer_import_failed")
        }
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

    private data class LanSnapshot(
        val courses: List<Course>,
        val tasks: List<CourseTask>,
        val exams: List<Exam>,
        val scheduleItems: List<ScheduleItem>,
        val settings: TimetableSettings,
        val currentWeek: Int,
        val rules: List<ScheduleDateRule>,
        val groups: List<LocationTimeGroup>,
        val schemes: List<TimeScheme>,
    )

    private fun captureSnapshot(): LanSnapshot {
        val snapshot = repository.snapshot
        return LanSnapshot(
            courses = snapshot.courses,
            tasks = repository.tasks,
            exams = repository.exams,
            scheduleItems = snapshot.scheduleItems,
            settings = snapshot.settings,
            currentWeek = snapshot.currentWeek,
            rules = snapshot.scheduleDateRules,
            groups = snapshot.locationTimeGroups,
            schemes = snapshot.timeSchemes,
        )
    }

    /** 尽力补偿：任何一步失败都不上抛（见类注释）。 */
    private fun restoreSnapshot(before: LanSnapshot) {
        runCatching {
            repository.scheduleItems = before.scheduleItems
            repository.replaceActiveProfileContent(before.courses, before.tasks, before.exams)
            repository.updateSettings(before.settings)
            repository.setCurrentWeek(before.currentWeek)
            repository.updateScheduleDateRules(before.rules)
            repository.updateLocationTimeGroups(before.groups)

            val keepIds = HashSet<String>(before.schemes.size)
            before.schemes.mapTo(keepIds) { it.id }
            for (scheme in repository.snapshot.timeSchemes) {
                if (scheme.id !in keepIds) repository.deleteTimeScheme(scheme.id)
            }
            for (scheme in before.schemes) {
                val current = repository.snapshot.timeSchemes.firstOrNull { it.id == scheme.id } ?: continue
                if (current.name != scheme.name || current.sections != scheme.sections) {
                    repository.updateTimeScheme(scheme.id, scheme.name, scheme.sections)
                }
            }
        }
    }
}
