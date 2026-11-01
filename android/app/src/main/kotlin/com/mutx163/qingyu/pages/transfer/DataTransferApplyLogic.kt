package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.LocationTimeGroup
import com.mutx163.qingyu.core.ScheduleDateRule
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.share.TransferApplyMode
import com.mutx163.qingyu.share.TransferScope
import com.mutx163.qingyu.share.overwriteUsesMergeSemantics
import java.time.LocalDateTime

/**
 * 导入落盘与撤销的**纯逻辑**（不碰仓储、不碰 Android）。
 *
 * 对应 Dart 的两处：
 * - 落盘：`UnifiedTransferService.applyToProvider`（`unified_transfer_service.dart:485-507`）
 *   与 `TransferUndoService`；
 * - 撤销：成功提示里的「撤销」动作 → `_undoTransfer(token)`（`data_transfer_screen.dart:680-694`）。
 *
 * ## 为什么这里只放「决定」，不放「写入」
 *
 * 写入要过仓储（`TimetableRepository` 的原子入口），那层没有 JVM 假实现可用；
 * 把「该不该写 / 合并成什么 / 撤销要把什么写回去」抽成纯函数，单测才有牙。
 *
 * ## 2026-10-29 二轮修复（P0：导入丢数据）
 *
 * 旧版只写回「档案 / 课表 / 设置 / 当前周」，**导出包里的作业、考试、日程条目、
 * 时间模板、日程规则全部被丢掉**（Dart 是全部写回的）。现在写入范围由
 * [planWrites] 一次性算出来，宿主照着写，单测钉住「导出 → 解析 → 计划 → 数据仍在」。
 *
 * ## 已知与 Dart 的差异（刻意，不是漏）
 *
 * Dart 的 `TransferDiffService` 会按 scope 逐实体算差异并**合并**（含 settings 的逐字段处理）。
 * 差异计算本身已经对等了，见 `DataTransferDiffLogic`；落盘这一侧还剩一条刻意差异：
 *
 * 1. **合并模式不支持全量包**（Dart 支持）：明确拒绝，数据一个字节不动（见
 *    [ERROR_FULL_BACKUP_MERGE_UNSUPPORTED]）——宁可不动，也不猜着写；
 * 2. 单课表包的合并只做「同 id 更新、新 id 追加、缺的不删」，设置与当前周**整份覆盖**
 *    （Dart 的合并同样只写回包里带来的 settings / currentWeek，语义一致）。
 *
 * ## 2026-10-30 三修（F16：「覆盖」的边界按 scope 收窄）
 *
 * 旧版 [planWrites] 不认识 scope，**覆盖 / 合并只认用户点的那个按钮**，于是两处和 Dart 不同：
 *
 * 1. `selected_courses` / `selected_course` / `week_timetable` / `time_template` 这 4 个
 *    scope 的「覆盖」在 Dart 里只更新**包边界内**的实体，本机边界外原样保留
 *    （`lib/services/unified_transfer_service.dart:666-676` 的
 *    `incoming.scope.overwriteUsesMergeSemantics` 分支）。旧版照单把 `plan.courses`
 *    整份写回 ⇒ **导入一份「本周课表」并选覆盖，会把本机包外的课全删掉**。
 * 2. `time_template` 的「覆盖」在 Dart 里走专用分支：**只并时间模板**，课程 / 作业 / 考试 /
 *    日程 / 设置 / 当前周一个都不碰。旧版把它当单课表包处理，而这类包的课程列表本来就是空的
 *    ⇒ `replaceActiveProfileContent(emptyList(), …)` 直接把用户的课表清零。
 *
 * 现在 [planWrites] 必填 `scope`，并按上面两条收窄；`time_schemes` 之外不写任何东西时用
 * [TransferApplyWrites.writesActiveProfileContent] = false 告诉宿主「这一块整个别动」。
 */
object DataTransferApplyLogic {

    /** 全量备份 + 合并模式：Kotlin 侧没有逐实体合并服务，明确拒绝。 */
    const val ERROR_FULL_BACKUP_MERGE_UNSUPPORTED = "full_backup_merge_unsupported"

    /** 计划是否代表「全量备份」（档案表非空）。 */
    fun isFullBackupPlan(plan: TransferImportPlan): Boolean = plan.profiles.isNotEmpty()

    /**
     * 这组（计划，模式）能不能落盘；返回 null 表示可以，否则返回要提示的机器码。
     *
     * 判据顺序与 Dart 的「先校验后写」一致：先在纯函数里把不可行的组合挡掉，
     * 宿主再动手写盘。
     */
    fun rejectionCode(plan: TransferImportPlan, mode: TransferApplyMode): String? {
        if (isFullBackupPlan(plan)) {
            // 全量包只有「覆盖」是安全且已实现的语义：整份替换档案表。
            if (mode == TransferApplyMode.MERGE) return ERROR_FULL_BACKUP_MERGE_UNSUPPORTED
            // 覆盖模式要求至少一份档案——解析层已挡过空 profiles，这里再挡一次
            // （防御式：调用方可能直接构造计划）。
            if (plan.profiles.isEmpty()) return "transfer_full_profiles_required"
            return null
        }
        // 单课表包：合并/覆盖都支持（合并 = 只加改不删）。
        return null
    }

    // ── 落盘计划（2026-10-29 二轮修复的核心） ────────────────────────

    /**
     * 一次导入**实际要写哪些东西**。
     *
     * 存在的理由：旧版宿主在 `applyImport` 里手写「写哪几块」，漏了五类数据也没有
     * 任何地方能测出来。把「写什么」变成这份不可变数据后，单测可以直接断言
     * 「包里有的东西，计划里都有」——不需要仓储。
     *
     * @param isFullBackup true = 走 [profiles]（整份档案表），false = 走单档案四块 + 设置 + 周。
     */
    data class TransferApplyWrites(
        val isFullBackup: Boolean,
        val profiles: List<TimetableProfile> = emptyList(),
        val activeProfileId: String? = null,
        val courses: List<Course> = emptyList(),
        val tasks: List<CourseTask> = emptyList(),
        val exams: List<Exam> = emptyList(),
        val scheduleItems: List<ScheduleItem> = emptyList(),
        val settings: TimetableSettings? = null,
        val currentWeek: Int? = null,
        /** 要补进本机时间模板表的模板（幂等：id 已存在则更新）。 */
        val timeSchemes: List<TimeScheme> = emptyList(),
        /** 要整份替换的作息日期规则；空 = **不覆盖本机**（包缺该键时不该清空用户规则）。 */
        val scheduleDateRules: List<ScheduleDateRule> = emptyList(),
        /**
         * 要写回的地点作息分组；空 = **不动本机**（与 [scheduleDateRules] 同一约定：
         * 包缺该键时清空用户分组是净损失）。
         *
         * 2026-10-30 修（审核 P0）：这条通道原先**双向全丢**——导出恒写空列表、
         * 导入完全不解析。现在两侧都通。
         */
        val locationTimeGroups: List<LocationTimeGroup> = emptyList(),
        /**
         * 这次导入要不要动**活动档案的内容块**（课程 / 作业 / 考试 / 日程 / 设置 / 当前周）。
         *
         * false = 只补时间模板（`time_template` 包），宿主必须整块跳过——照常调用
         * `replaceActiveProfileContent` 会把空列表写进去，等于清空用户课表。
         */
        val writesActiveProfileContent: Boolean = true,
    )

    /** 本机当前内容（合并的基线）。只取合并真正用得上的四块。 */
    data class TransferCurrentContent(
        val courses: List<Course> = emptyList(),
        val tasks: List<CourseTask> = emptyList(),
        val exams: List<Exam> = emptyList(),
        val scheduleItems: List<ScheduleItem> = emptyList(),
    )

    /**
     * 算落盘计划。
     *
     * @param mode 覆盖 / 合并
     * @param current 本机当前内容（合并基线）
     * @param scope 入包自述的 scope——决定「覆盖」到底是整份替换还是只更新包边界内的实体
     *   （Dart `overwriteUsesMergeSemantics`，见文件头「三修」）；`time_template` 另走专用分支。
     * @param schemeIdMap 包里的时间模板 id → 本机实际 id（宿主补模板时建的映射；
     *   空映射 = 不需要改写引用，测试与「id 恰好一致」的情形都是它）
     */
    fun planWrites(
        plan: TransferImportPlan,
        mode: TransferApplyMode,
        current: TransferCurrentContent,
        scope: TransferScope,
        schemeIdMap: Map<String, String> = emptyMap(),
    ): TransferApplyWrites {
        // 日程规则 / 地点分组：空列表视为「包没带这一块」，不覆盖本机（包缺该键时
        // 清空用户规则是净损失，而少还原一次顶多是没同步到）。
        //
        // 2026-11-01 修（P1）：这两块的 `timeSchemeId` 也必须跟课程与设置一样过
        // `schemeIdMap`。跨设备导入时包里的模板 id 在本机不存在、宿主会新建并给出
        // 「包 id → 本机 id」映射；不改写就会指向一个不存在的模板，规则/分组静默失效
        // （Dart `unified_transfer_service.dart:717-724` 对两块都做了改写）。
        // **映射缺失时保留原值**（与 `LanTransferLogic.remapScheduleDateRules` 同判据）：
        // 映射只包含「本机新建的那几套」，id 恰好一致的模板不会进映射——若按缺失置空，
        // 同设备往返会把所有引用抹掉，那是净损失。
        val rules = remapScheduleDateRules(plan.scheduleDateRules, schemeIdMap)
        val groups = remapLocationTimeGroups(plan.locationTimeGroups, schemeIdMap)

        if (isFullBackupPlan(plan)) {
            val profiles = plan.profiles.map { remapProfileSchemes(it, schemeIdMap) }
            val active = profiles.firstOrNull { it.id == plan.activeProfileId }
                ?: profiles.firstOrNull()
            return TransferApplyWrites(
                isFullBackup = true,
                profiles = profiles,
                activeProfileId = plan.activeProfileId,
                // 全量包：档案里已经带齐 courses/tasks/exams/scheduleItems，随档案一起写。
                settings = active?.settings,
                // 当前周：全量包顶层通常不带 `currentWeek`（Dart `buildFullPackage` 不传，
                // 本仓 `DataTransferPackageLogic` 对 ALL_DATA 也传 null），所以只能回落到
                // 恢复出来的活动档案自己那份。不写回的话本机全局 `current_week` 仍是旧值，
                // 用户恢复完全量备份会停在原来的那一周（2026-11-01 修 P1）。
                currentWeek = plan.currentWeek ?: active?.currentWeek?.toInt(),
                timeSchemes = plan.timeSchemes,
                scheduleDateRules = rules,
                locationTimeGroups = groups,
            )
        }

        // 时间模板包：Dart 的「覆盖」专用分支只并模板
        // （`unified_transfer_service.dart:668-671`），课程 / 作业 / 考试 / 日程 / 设置 /
        // 当前周一个都不碰。这类包的课程列表本来就是空的，照单写回等于清空用户课表。
        if (scope == TransferScope.TIME_TEMPLATE) {
            return TransferApplyWrites(
                isFullBackup = false,
                timeSchemes = plan.timeSchemes,
                writesActiveProfileContent = false,
            )
        }

        // 「覆盖」的边界：局部 scope 只更新包边界内的实体，边界外原样保留
        // （`unified_transfer_service.dart:666-676` ⇒ 语义上等同合并，只是不报删除）。
        val merge = mode == TransferApplyMode.MERGE || scope.overwriteUsesMergeSemantics
        val courses = if (merge) {
            mergeCourses(current.courses, plan.courses)
        } else {
            plan.courses
        }
        return TransferApplyWrites(
            isFullBackup = false,
            courses = remapCourseSchemes(courses, schemeIdMap),
            // P0：这两块以前传的是 `repository.tasks` / `repository.exams`（本机旧值），
            // 等于把包里带过来的作业与考试**静默丢掉**。Dart 是全量写回的。
            tasks = if (merge) {
                mergeById(current.tasks, plan.tasks, CourseTask::id)
            } else {
                plan.tasks
            },
            exams = if (merge) {
                mergeById(current.exams, plan.exams, Exam::id)
            } else {
                plan.exams
            },
            // 日程条目在合并下同样是「同 id 更新、新 id 追加、缺的不删」（Dart `_merge`
            // 对 scheduleItems 也是 add/update by id）；覆盖时整份替换。
            scheduleItems = if (merge) {
                mergeById(current.scheduleItems, plan.scheduleItems, ScheduleItem::id)
            } else {
                plan.scheduleItems
            },
            settings = plan.settings?.let { remapSettingsScheme(it, schemeIdMap) },
            currentWeek = plan.currentWeek,
            timeSchemes = plan.timeSchemes,
            scheduleDateRules = rules,
            locationTimeGroups = groups,
        )
    }

    // ── 引用改写 / 合并 ────────────────────────────────────────────

    /**
     * 包里的时间模板 id → 本机 id。
     *
     * 为什么要映射：跨设备导入时包里的模板 id 在本机不存在，宿主只能新建，
     * 而新建的 id 是随机 UUID。课程上的 `timeSchemeIdOverride` 与设置里的
     * `activeTimeSchemeId` 必须跟着改，否则引用悬空。
     */
    fun remapSchemeId(schemeId: String?, schemeIdMap: Map<String, String>): String? =
        schemeId?.let { schemeIdMap[it] ?: it }

    fun remapCourseSchemes(
        courses: List<Course>,
        schemeIdMap: Map<String, String>,
    ): List<Course> {
        if (schemeIdMap.isEmpty()) return courses
        return courses.map { course ->
            val mapped = remapSchemeId(course.timeSchemeIdOverride, schemeIdMap)
            if (mapped == course.timeSchemeIdOverride) course else course.copy(timeSchemeIdOverride = mapped)
        }
    }

    fun remapSettingsScheme(
        settings: TimetableSettings,
        schemeIdMap: Map<String, String>,
    ): TimetableSettings {
        if (schemeIdMap.isEmpty()) return settings
        val mapped = remapSchemeId(settings.activeTimeSchemeId, schemeIdMap)
        return if (mapped == settings.activeTimeSchemeId) {
            settings
        } else {
            settings.copy(activeTimeSchemeId = mapped)
        }
    }

    /**
     * 日程规则的模板引用改写（Dart `_remapScheduleDateRules`）。
     *
     * 映射缺失时**保留原值**，理由见 [planWrites] 里这段的注释：映射只覆盖「本机新建的
     * 模板」，同 id 模板不进映射。
     */
    fun remapScheduleDateRules(
        rules: List<ScheduleDateRule>,
        schemeIdMap: Map<String, String>,
    ): List<ScheduleDateRule> {
        if (schemeIdMap.isEmpty()) return rules
        return rules.map { rule ->
            val mapped = schemeIdMap[rule.timeSchemeId] ?: rule.timeSchemeId
            if (mapped == rule.timeSchemeId) rule else rule.copy(timeSchemeId = mapped)
        }
    }

    /** 地点作息分组的模板引用改写（Dart `_remapLocationTimeGroups`），判据同上。 */
    fun remapLocationTimeGroups(
        groups: List<LocationTimeGroup>,
        schemeIdMap: Map<String, String>,
    ): List<LocationTimeGroup> {
        if (schemeIdMap.isEmpty()) return groups
        return groups.map { group ->
            val mapped = schemeIdMap[group.timeSchemeId] ?: group.timeSchemeId
            if (mapped == group.timeSchemeId) group else group.copy(timeSchemeId = mapped)
        }
    }

    /** 档案级改写：课表的 override 与档案设置里的活动模板一起跟着映射。 */
    fun remapProfileSchemes(
        profile: TimetableProfile,
        schemeIdMap: Map<String, String>,
    ): TimetableProfile {
        if (schemeIdMap.isEmpty()) return profile
        return profile.copy(
            courses = remapCourseSchemes(profile.courses, schemeIdMap),
            settings = remapSettingsScheme(profile.settings, schemeIdMap),
        )
    }

    /**
     * 合并模式的最终课表（Dart `applyToProvider(mode: merge)` 对课程的效果）。
     *
     * 三条规则：
     * 1. **当前已有、包里也有**的同 id 课程 → 用包里的（更新）；
     * 2. **包里新出现**的 id → 追加到末尾（顺序沿用包里的顺序）；
     * 3. **当前有、包里没有** → 原样保留（合并模式不删）。
     */
    fun mergeCourses(current: List<Course>, incoming: List<Course>): List<Course> =
        mergeById(current, incoming, Course::id)

    /**
     * 按 id 合并：同 id 用包里的值，新 id 追加，缺的保留。
     *
     * 作业 / 考试 / 日程条目与课程同一套语义（Dart 的 merge 分支对四类实体一致）。
     * 课程 id 在合并里**保留原值**（不做软匹配重编），所以作业指向的 `courseId`
     * 不会失效——这也是 Dart 那边要算 `idMap` 而我们这边不用的原因。
     */
    fun <T> mergeById(
        current: List<T>,
        incoming: List<T>,
        idOf: (T) -> String,
    ): List<T> {
        if (incoming.isEmpty()) return current
        val incomingById = incoming.associateBy(idOf)
        val merged = current.map { existing -> incomingById[idOf(existing)] ?: existing }
        val existingIds = current.mapTo(mutableSetOf(), idOf)
        val appended = incoming.filter { idOf(it) !in existingIds }
        return merged + appended
    }

    /**
     * 覆盖模式写完之后「超出当前作息」的课有多少节（Dart `_previewAndApply` 的
     * `TimeSchemeLogic.countCoursesWithoutVisibleRow`，`data_transfer_screen.dart:640-643`）。
     *
     * 这里直接转发 `core/TimeSchemeLogic`——不复制判据，避免两处漂移。
     */
    fun coursesBeyondScheme(courses: List<Course>, sectionCount: Int): Int =
        com.mutx163.qingyu.core.TimeSchemeLogic.countCoursesWithoutVisibleRow(courses, sectionCount)

    /**
     * 撤销快照要抓什么：全量包抓**整份档案表**，单课表包抓**当前档案五块 + 设置 + 当前周**。
     *
     * 与写入范围一一对应——撤销必须能把这次写进去的每一处都还原（多抓是浪费，
     * 少抓就是「撤销了一半」，那比没有撤销更糟）。
     *
     * ⚠️ 时间模板表**不在**撤销范围内：本次新建的模板留在表里（列表多一条，
     * 不影响任何课表渲染），因为删模板要走 `deleteTimeScheme` 的「是否被引用」判据，
     * 撤销时若别的档案已经在用它，删不掉会变成半还原。这是刻意的取舍。
     */
    fun undoKindFor(plan: TransferImportPlan): TransferUndoScope =
        if (isFullBackupPlan(plan)) TransferUndoScope.FULL_PROFILES else TransferUndoScope.ACTIVE_PROFILE_CONTENT
}

/** 撤销快照抓的范围：决定撤销时把哪一份数据整份写回。 */
enum class TransferUndoScope {
    /** 全量包：整份档案表 + 激活档案 id。 */
    FULL_PROFILES,

    /** 单课表包：当前档案的课表/作业/考试/日程 + 设置 + 当前周。 */
    ACTIVE_PROFILE_CONTENT,
}

/**
 * 导入前的仓储现场（撤销的唯一依据）。
 *
 * 只存内存：Dart 的 undo token 同样是内存态（服务层维护、按 id 消费一次），
 * 区别是 Dart 存的是「备份 JSON」、这里存的是「已解析的模型」。杀进程即失效——
 * 属已知缺口，见审核文档 §六。
 */
data class TransferUndoSnapshot(
    val kind: TransferUndoScope,
    val profiles: List<TimetableProfile> = emptyList(),
    val activeProfileId: String? = null,
    val courses: List<Course> = emptyList(),
    val tasks: List<CourseTask> = emptyList(),
    val exams: List<Exam> = emptyList(),
    val scheduleItems: List<ScheduleItem> = emptyList(),
    val settings: TimetableSettings? = null,
    val currentWeek: Int = 1,
    /** null = 本次导入没动日程规则，撤销时也不碰它。 */
    val scheduleDateRules: List<ScheduleDateRule>? = null,
    /**
     * 撤销时要还原的地点作息分组；null = 本次导入没动它，撤销时也不碰。
     *
     * 2026-10-30 起导入会写这块，撤销必须能一起回到原样，否则「撤销」只回滚一半。
     */
    val locationTimeGroups: List<LocationTimeGroup>? = null,
)

/** 一次可撤销的导入（Dart `TransferUndoToken` 的展示侧最小投影）。 */
data class TransferUndoToken(
    val id: String,
    val snapshot: TransferUndoSnapshot,
    val createdAt: LocalDateTime,
)
