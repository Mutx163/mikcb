package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.app.TimetableSnapshot
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.ScheduleDateRule
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.share.TransferApplyMode
import com.mutx163.qingyu.share.TransferScope
import com.mutx163.qingyu.share.carriesSettings
import com.mutx163.qingyu.share.overwriteUsesMergeSemantics

/**
 * 导入前的**按 scope 真差分**（Dart `TransferDiffService.compare` 的对等实现）。
 *
 * ## 判据源（逐条对着 Dart 抄，别在这里自创口径）
 *
 * | 本文件 | Dart 出处 |
 * | --- | --- |
 * | [DataTransferDiffLogic.compare] 的实体取材 | `_entitiesForKind`（`lib/services/transfer_diff_service.dart:369-399`）+ `_flatten`（`:411-424`） |
 * | 配对与增改删 | `_compareList`（`:313-367`） |
 * | 相等判据 | `_sameJson`（`:426-443`）：两侧都先过模型再比归一化 JSON |
 * | removed 要不要统计 | `reportRemovals`（`:159-161`）：`mode == overwrite && !scope.overwriteUsesMergeSemantics` |
 * | settings 行 | `_settingsFor`（`:401-409`）+ `compare` 里那段（`:176-200`） |
 * | 八类顺序 | `TransferDiff.allKinds`（`:93-102`） |
 *
 * ## 为什么要有这个文件（旧版错在哪）
 *
 * 旧实现（`DataTransferImportLogic.diffSummaries(currentJson, incomingJson)`）比的是**两份
 * 包文本**，三处会给出与 Dart 不同的结论：
 *
 * 1. **不做模型归一化**。Dart 两侧都 `fromJson → toJson()` 之后再比；旧版拿「本机现采包
 *    （模型序列化产物）」对「入包原始 JSON」，同一事实少一个可选键、多一个默认值就判
 *    「改动」，用户看到一堆并不存在的 `~N`。
 * 2. **removed 无条件统计**。Dart 只在「覆盖 + 该 scope 的覆盖不是合并语义」时统计；
 *    旧版恒统计，再由调用点把 merge 那份的 removed 归零——覆盖那一份对
 *    `week_timetable` / `selected_courses` 这类包会凭空多出 `-N`。
 * 3. **基线固定按 `CURRENT_TIMETABLE` 打包**。全量包（`ALL_DATA`）进来时，档案内的实体
 *    全部判「新增」、本机顶层实体全部判「删除」，一份自己刚导出的备份会显示「+120 / -120」。
 *
 * ## 与 Dart 的刻意差异（三条，都有理由）
 *
 * 1. **不保存 `before` / `after` 的完整 JSON**。Dart 的 `TransferEntityChange` 带两份
 *    实体快照给第三方消费；Compose 侧预览只渲染计数与标签，为一次全量导入把几百条实体的
 *    两侧 JSON 都留在内存里没有读者。
 * 2. **`locations` 恒为 `+0 / ~0 / -0`**。Kotlin 的导入链路既不解析地点作息分组
 *    （`TransferImportPlan` 没有这个字段）、也不落盘（`DataTransferHost.applyImport`
 *    没有写入口），给出非零计数等于向用户承诺一次不会发生的写入。
 * 3. **`time_schemes` 按 id 配对，不做内容归一之外的软匹配**。Dart 同处也是按 id
 *    （`_TransferEntity.key`），软匹配只发生在落盘的课程合并里。
 */
object DataTransferDiffLogic {

    /**
     * 算一份差异。
     *
     * @param current 本机真实现场（`TimetableSnapshot` + 活动档案的作业/考试，
     *   见 [TransferDiffCurrent.ofSnapshot]）
     * @param plan 已解析、尚未落盘的入包（[DataTransferImportLogic.parse] 的产出）
     * @param scope 入包自述的 scope——决定「覆盖」要不要报删除（见 [reportRemovalsFor]），
     *   也决定基线取「整份档案表」还是「活动档案」：与
     *   [DataTransferApplyLogic.planWrites] 实际写入的范围一一对应，预览才不会说了不做。
     * @param mode `merge`（合并）/ `overwrite`（覆盖）
     *
     * 调用方要两个模式的数字时**分别调两次**（Dart `data_transfer_screen.dart:599-605` 同）。
     */
    fun compare(
        current: TransferDiffCurrent,
        plan: TransferImportPlan,
        scope: TransferScope,
        mode: TransferApplyMode,
    ): TransferDiff {
        val fullBackup = DataTransferApplyLogic.isFullBackupPlan(plan)
        val reportRemovals = reportRemovalsFor(scope, mode)

        // settings：Dart `_settingsFor` + `compare`（:176-200）三段判据缺一不可——
        // ① scope 会携带设置；② 本机取得到；③ 入包取得到（顶层没有就退到「只有一张档案」那家）。
        // 缺任何一条都不该出行：比出个 `~1` 等于告诉用户「设置会被改」，而落盘那边不会动。
        val incomingSettings = plan.settings ?: plan.profiles.singleOrNull()?.settings
        val settingsDiff = if (scope.carriesSettings && current.settings != null && incomingSettings != null) {
            compareEntities(
                kind = TransferDiffKind.SETTINGS,
                current = settingsSide(current.settings),
                incoming = settingsSide(incomingSettings),
                // 设置没有「本机独有」这一说：两侧都取得到就比，不等就是一条 updated。
                reportRemovals = false,
            )
        } else {
            TransferEntityDiff(TransferDiffKind.SETTINGS, emptyList())
        }

        val summaries = listOf(
            compareEntities(
                TransferDiffKind.COURSES,
                sideEntities(
                    current.courses, current.profiles, { it.courses }, fullBackup,
                    Course::id, Course::name, Course::toJson,
                ),
                sideEntities(
                    plan.courses, plan.profiles, { it.courses }, fullBackup,
                    Course::id, Course::name, Course::toJson,
                ),
                reportRemovals,
            ),
            compareEntities(
                TransferDiffKind.EXAMS,
                sideEntities(
                    current.exams, current.profiles, { it.exams }, fullBackup,
                    Exam::id, Exam::name, Exam::toJson,
                ),
                sideEntities(
                    plan.exams, plan.profiles, { it.exams }, fullBackup,
                    Exam::id, Exam::name, Exam::toJson,
                ),
                reportRemovals,
            ),
            compareEntities(
                TransferDiffKind.TIME_RULES,
                sideEntities(
                    current.scheduleDateRules, emptyList(), { emptyList() }, false,
                    ScheduleDateRule::id, ScheduleDateRule::name, ScheduleDateRule::toJson,
                ),
                sideEntities(
                    plan.scheduleDateRules, emptyList(), { emptyList() }, false,
                    ScheduleDateRule::id, ScheduleDateRule::name, ScheduleDateRule::toJson,
                ),
                reportRemovals,
            ),
            // 地点作息分组：见类注释「刻意差异 2」——既不解析也不落盘，所以恒空。
            TransferEntityDiff(TransferDiffKind.LOCATIONS, emptyList()),
            compareEntities(
                TransferDiffKind.TASKS,
                sideEntities(
                    current.tasks, current.profiles, { it.tasks }, fullBackup,
                    CourseTask::id, CourseTask::title, CourseTask::toJson,
                ),
                sideEntities(
                    plan.tasks, plan.profiles, { it.tasks }, fullBackup,
                    CourseTask::id, CourseTask::title, CourseTask::toJson,
                ),
                reportRemovals,
            ),
            compareEntities(
                TransferDiffKind.SCHEDULE_ITEMS,
                sideEntities(
                    current.scheduleItems, current.profiles, { it.scheduleItems }, fullBackup,
                    ScheduleItem::id, ScheduleItem::title, ScheduleItem::toJson,
                ),
                sideEntities(
                    plan.scheduleItems, plan.profiles, { it.scheduleItems }, fullBackup,
                    ScheduleItem::id, ScheduleItem::title, ScheduleItem::toJson,
                ),
                reportRemovals,
            ),
            compareEntities(
                TransferDiffKind.TIME_SCHEMES,
                sideEntities(
                    current.timeSchemes, emptyList(), { emptyList() }, false,
                    TimeScheme::id, TimeScheme::name, TimeScheme::toJson,
                ),
                sideEntities(
                    plan.timeSchemes, emptyList(), { emptyList() }, false,
                    TimeScheme::id, TimeScheme::name, TimeScheme::toJson,
                ),
                reportRemovals,
            ),
            settingsDiff,
        )

        return TransferDiff(mode = mode, summaries = summaries)
    }

    /**
     * 「覆盖」要不要报删除。
     *
     * Dart `transfer_diff_service.dart:159-161`：`mode == overwrite &&
     * !incoming.scope.overwriteUsesMergeSemantics`。
     *
     * `overwriteUsesMergeSemantics` 为真的 4 个 scope（`selected_courses` /
     * `selected_course` / `week_timetable` / `time_template`，见
     * `lib/services/transfer_package.dart:44-52`）在落盘时只更新包边界内的实体，
     * 本机边界外的原样保留（`lib/services/unified_transfer_service.dart:666-676`），
     * 所以那里「覆盖」不删东西，报删除就是吓唬用户。
     */
    fun reportRemovalsFor(scope: TransferScope, mode: TransferApplyMode): Boolean =
        mode == TransferApplyMode.OVERWRITE && !scope.overwriteUsesMergeSemantics

    // ---------- 内部：配对与比对 ----------

    /**
     * 一条参与比对的实体。
     *
     * [key] 对应 Dart `_TransferEntity.key`（`jsonEncode([profileId, id])`）：**档案 id 参与
     * 配对**，否则两张档案里的同 id 实体（跨设备导入时很常见）会互相顶替。
     */
    private data class DiffEntity(
        val profileId: String?,
        val id: String,
        val label: String,
        /** 模型 `toJson()` 的产物（两侧都是模型，所以同键同型，直接值比较即可）。 */
        val json: Map<String, Any?>,
    ) {
        val key: String get() = (profileId ?: "") + "\u0000" + id
    }

    private fun DiffEntity.change(kind: TransferDiffKind, type: TransferChangeType) =
        TransferEntityChange(
            kind = kind,
            type = type,
            id = id,
            label = label,
            profileId = profileId,
        )

    /**
     * 一侧的实体清单。
     *
     * `includeProfiles = false`（单课表包）：只取活动档案那一份扁平列表——`TimetableSnapshot`
     * 的 `courses` / `scheduleItems` 就是活动档案的，作业与考试由
     * [TransferDiffCurrent.ofSnapshot] 从档案里取。
     *
     * `includeProfiles = true`（全量包）：逐档案打散，`profileId` 参与配对；顶层列表照旧
     * 追加（历史包允许「档案 + 顶层补充」并存，Dart `_entitiesForKind` 同）。
     */
    private fun <T> sideEntities(
        topLevel: List<T>,
        fullProfiles: List<TimetableProfile>,
        nested: (TimetableProfile) -> List<T>,
        includeProfiles: Boolean,
        idOf: (T) -> String,
        labelOf: (T) -> String,
        jsonOf: (T) -> Map<String, Any?>,
    ): List<DiffEntity> {
        val out = ArrayList<DiffEntity>(topLevel.size)
        if (includeProfiles) {
            for (profile in fullProfiles) {
                for (item in nested(profile)) {
                    out += DiffEntity(profile.id, idOf(item), labelOf(item), jsonOf(item))
                }
            }
        }
        for (item in topLevel) {
            out += DiffEntity(null, idOf(item), labelOf(item), jsonOf(item))
        }
        return out
    }

    /** 设置只有一条「实体」，且它没有 id 之外的粒度。 */
    private fun settingsSide(settings: TimetableSettings?): List<DiffEntity> =
        if (settings == null) {
            emptyList()
        } else {
            listOf(DiffEntity(profileId = null, id = "settings", label = "settings", json = settings.toJson()))
        }

    /**
     * 按 (profileId, id) 配对：入包有本机无 → added；两侧都有但归一化内容不同 → updated；
     * [reportRemovals] 为真时，本机有入包无 → removed。
     *
     * 变更顺序 = Dart：先按入包顺序出 added/updated，再按本机顺序出 removed。
     */
    private fun compareEntities(
        kind: TransferDiffKind,
        current: List<DiffEntity>,
        incoming: List<DiffEntity>,
        reportRemovals: Boolean,
    ): TransferEntityDiff {
        val currentByKey = current.associateBy { it.key }
        val changes = ArrayList<TransferEntityChange>()
        for (entity in incoming) {
            val before = currentByKey[entity.key]
            when {
                before == null -> changes += entity.change(kind, TransferChangeType.ADDED)
                before.json != entity.json -> changes += entity.change(kind, TransferChangeType.UPDATED)
            }
        }
        if (reportRemovals) {
            val incomingKeys = incoming.mapTo(mutableSetOf()) { it.key }
            for (entity in current) {
                if (entity.key !in incomingKeys) changes += entity.change(kind, TransferChangeType.REMOVED)
            }
        }
        return TransferEntityDiff(kind = kind, changes = changes)
    }
}

/** 差异类别。[value] 与 Dart `TransferEntityKind.value` 逐字一致，`entries` 顺序即预览行序。 */
enum class TransferDiffKind(val value: String) {
    COURSES("courses"),
    EXAMS("exams"),
    TIME_RULES("time_rules"),
    LOCATIONS("locations"),
    TASKS("tasks"),
    SCHEDULE_ITEMS("schedule_items"),
    TIME_SCHEMES("time_schemes"),
    SETTINGS("settings"),
}

/** 一条差异的性质（Dart `TransferChangeType`）。 */
enum class TransferChangeType { ADDED, UPDATED, REMOVED }

/** 一条实体级差异（Dart `TransferEntityChange` 的展示侧投影）。 */
data class TransferEntityChange(
    val kind: TransferDiffKind,
    val type: TransferChangeType,
    val id: String,
    val label: String,
    /** 档案归属；null = 包级 / 全局（顶层列表里的实体）。 */
    val profileId: String? = null,
) {
    /**
     * 稳定、与传输格式无关的可读行（Dart `TransferEntityChange.description` 同口径）。
     * 文案本地化可以只换操作词，不必重新解析载荷。
     */
    val description: String
        get() = buildString {
            append(type.name.lowercase())
            append(": ")
            append(label.ifBlank { id })
            append(" (")
            append(id)
            append(')')
            if (profileId != null) {
                append(" [")
                append(profileId)
                append(']')
            }
        }
}

/** 一类实体的差异集合（Dart `TransferEntityDiff`）。 */
data class TransferEntityDiff(
    val kind: TransferDiffKind,
    val changes: List<TransferEntityChange>,
) {
    val addedCount: Int get() = changes.count { it.type == TransferChangeType.ADDED }
    val updatedCount: Int get() = changes.count { it.type == TransferChangeType.UPDATED }
    val removedCount: Int get() = changes.count { it.type == TransferChangeType.REMOVED }
    val totalCount: Int get() = changes.size
    val isEmpty: Boolean get() = changes.isEmpty()
}

/** 一份完整的导入预览差异（Dart `TransferDiff`）。 */
data class TransferDiff(
    val mode: TransferApplyMode,
    val summaries: List<TransferEntityDiff>,
) {
    /** 缺项补一条空行——预览契约是「八行全输出」，少一行用户就以为那类数据不会被动。 */
    fun forKind(kind: TransferDiffKind): TransferEntityDiff =
        summaries.firstOrNull { it.kind == kind } ?: TransferEntityDiff(kind, emptyList())

    val addedCount: Int get() = summaries.sumOf { it.addedCount }
    val updatedCount: Int get() = summaries.sumOf { it.updatedCount }
    val removedCount: Int get() = summaries.sumOf { it.removedCount }
    val totalCount: Int get() = summaries.sumOf { it.totalCount }
    val hasChanges: Boolean get() = summaries.any { !it.isEmpty }

    /**
     * 喂给 [DataTransferImportLogic.previewMessage] 的八行摘要。
     *
     * 顺序**冻结**为 [TransferDiffKind.entries]（= Dart `TransferDiff.allKinds`）；用户在两台
     * 手机之间逐字对数字，不能重排。
     */
    fun toSummaries(): List<TransferDiffSummary> = TransferDiffKind.entries.map { kind ->
        val diff = forKind(kind)
        TransferDiffSummary(
            kind = kind.value,
            added = diff.addedCount,
            updated = diff.updatedCount,
            removed = diff.removedCount,
        )
    }
}

/**
 * 本机当前内容的**模型层**现场（差异的基线）。
 *
 * 刻意不直接用 `TimetableSnapshot`：`app/` 的仓储现场里没有作业与考试（它们在活动档案里），
 * 而这两类必须参与比对；[ofSnapshot] 负责把它们拼齐，单测也能脱离仓储直接构造。
 */
data class TransferDiffCurrent(
    val profiles: List<TimetableProfile> = emptyList(),
    val activeProfileId: String? = null,
    /** 活动档案的课程。 */
    val courses: List<Course> = emptyList(),
    /** 活动档案的作业。 */
    val tasks: List<CourseTask> = emptyList(),
    /** 活动档案的考试。 */
    val exams: List<Exam> = emptyList(),
    /** 活动档案的日程条目。 */
    val scheduleItems: List<ScheduleItem> = emptyList(),
    val timeSchemes: List<TimeScheme> = emptyList(),
    val scheduleDateRules: List<ScheduleDateRule> = emptyList(),
    val settings: TimetableSettings? = null,
) {
    companion object {
        /**
         * 从仓储现场拼出基线。
         *
         * @param tasks / @param exams 来自活动档案（`TimetableRepository.tasks` / `.exams`）；
         *   其余字段 `TimetableSnapshot` 已经扁平化好了。
         */
        fun ofSnapshot(
            snapshot: TimetableSnapshot,
            tasks: List<CourseTask>,
            exams: List<Exam>,
        ): TransferDiffCurrent = TransferDiffCurrent(
            profiles = snapshot.profiles,
            activeProfileId = snapshot.activeProfileId,
            courses = snapshot.courses,
            tasks = tasks,
            exams = exams,
            scheduleItems = snapshot.scheduleItems,
            timeSchemes = snapshot.timeSchemes,
            scheduleDateRules = snapshot.scheduleDateRules,
            settings = snapshot.settings,
        )
    }
}
