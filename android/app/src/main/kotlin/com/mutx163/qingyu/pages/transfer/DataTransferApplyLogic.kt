package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.share.TransferApplyMode
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
 * ## 已知与 Dart 的差异（刻意，不是漏）
 *
 * Dart 的 `TransferDiffService` 会按 scope 逐实体算差异并**合并**（含 settings 的逐字段处理），
 * Kotlin 侧没有对等实现，所以：
 * 1. **合并模式不支持全量包**（Dart 支持）：明确拒绝，数据一个字节不动（见
 *    [ERROR_FULL_BACKUP_MERGE_UNSUPPORTED]）——宁可不动，也不猜着写；
 * 2. 单课表包的合并只做课表（同 id 更新、新 id 追加、**缺的不删**），设置与当前周**整份覆盖**。
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

    /**
     * 合并模式的最终课表（Dart `applyToProvider(mode: merge)` 对课程的效果）。
     *
     * 三条规则：
     * 1. **当前已有、包里也有**的同 id 课程 → 用包里的（更新）；
     * 2. **包里新出现**的 id → 追加到末尾（顺序沿用包里的顺序）；
     * 3. **当前有、包里没有** → 原样保留（合并模式不删）。
     */
    fun mergeCourses(current: List<Course>, incoming: List<Course>): List<Course> {
        if (incoming.isEmpty()) return current
        val incomingById = incoming.associateBy { it.id }
        val merged = current.map { existing -> incomingById[existing.id] ?: existing }
        val existingIds = current.mapTo(mutableSetOf()) { it.id }
        val appended = incoming.filter { it.id !in existingIds }
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
     * 撤销快照要抓什么：全量包抓**整份档案表**，单课表包抓**当前档案三块 + 设置 + 当前周**。
     *
     * 与写入范围一一对应——撤销必须能把这次写进去的每一处都还原（多抓是浪费，
     * 少抓就是「撤销了一半」，那比没有撤销更糟）。
     */
    fun undoKindFor(plan: TransferImportPlan): TransferUndoScope =
        if (isFullBackupPlan(plan)) TransferUndoScope.FULL_PROFILES else TransferUndoScope.ACTIVE_PROFILE_CONTENT
}

/** 撤销快照抓的范围：决定撤销时把哪一份数据整份写回。 */
enum class TransferUndoScope {
    /** 全量包：整份档案表 + 激活档案 id。 */
    FULL_PROFILES,

    /** 单课表包：当前档案的课表/任务/考试 + 设置 + 当前周。 */
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
    val settings: TimetableSettings? = null,
    val currentWeek: Int = 1,
)

/** 一次可撤销的导入（Dart `TransferUndoToken` 的展示侧最小投影）。 */
data class TransferUndoToken(
    val id: String,
    val snapshot: TransferUndoSnapshot,
    val createdAt: LocalDateTime,
)
