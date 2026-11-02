package com.mutx163.qingyu.transfer.lan

import com.mutx163.qingyu.app.TimetableHostLogic
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.DartTime
import com.mutx163.qingyu.core.FormatException
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.course.TimetableCourseService
import com.mutx163.qingyu.share.TransferApplyMode
import com.mutx163.qingyu.share.TransferChannel
import com.mutx163.qingyu.share.TransferEnvelope
import com.mutx163.qingyu.share.TransferScope
import com.mutx163.qingyu.sync.buildTransferPackageJson
import java.time.LocalDateTime

/**
 * 表格解析结果的**最小投影**（`pages/import` 的 `SpreadsheetImportResult` 等价物）。
 *
 * 为什么不直接用它：`pages/import` **不在 L0 脚本的共享目录名单里**，
 * `transfer/lan` 一旦静态依赖它，全队每一次 L0 都会 unresolved
 * （`transfer/` 是被无条件收录的目录）。所以解析器由接线方**注入**，
 * 本文件只认这个投影类型。
 */
data class LanEditSpreadsheetParse(
    val courses: List<Course>,
    val warnings: List<String>,
    val format: String,
)

/**
 * [LanEditHost] 的**仓储实现**：局域网编辑的全部读写都走 [TimetableRepository]。
 *
 * ## 为什么必须走仓储
 *
 * 「电脑端导入的课表，落盘后手机主界面读不出来」这类 bug 的根因只有一个：
 * 两条路径各写一份存储格式。所以这里**一个字节都不直接写 prefs**：
 * - 增删改课 → `repository.addCourse/updateCourse/deleteCourse`
 *   （内部是 `TimetableCourseService`，归一、同组广播、失败回滚都在那里）；
 * - 组替换 → `TimetableCourseService.updateGroup(repository, originalName, courses)`
 *   （`TimetableRepository` 本身就是 `TimetableCoursePort`，直接当 port 传）；
 * - 设置 / 当前周 / 切档案 → `repository.updateSettings/setCurrentWeek/setActiveProfile`。
 *
 * ## 导入为什么先校验后落盘
 *
 * 整份备份导入是**唯一能一次性覆盖用户全部课表**的操作。2026-11-01 起它与
 * [applyTransferJson] 走同一条 LAN 应用链 [LanTransferApplier]（Dart 的
 * `importProfileBackupJson` 本来就是 `applyToProvider(overwrite)`）：
 * 1. `LanTransferLogic.parseIncoming` 先过结构门（纯函数，不碰存储）；
 * 2. 通过后才开始「补时间模板 → 写实体 → 写设置 / 当前周」；
 * 3. 落盘阶段任一步失败，applier 用导入前快照尽力补偿，再回 `applied: false`。
 *
 * 校验失败时盘上一个字节都没动 —— 这条有测试钉着（见 `LanEditRepositoryHostTest`）。
 *
 * ## 明确不做的（诚实清单）
 *
 * - **局部传输的 diff/预览 / 应用 / 撤销已接线**（2026-10-30 应用，2026-11-02 撤销）：
 *   `previewTransferJson` / `applyTransferJson` / `undoTransferJson` 交给
 *   [LanTransferApplier]（纯逻辑 [LanTransferLogic] + [LanTransferUndoLogic] + 仓储写入）。
 *   `applyTransferJson` 成功后回真实 `transferId`（撤销点 id），凭它调
 *   `POST /api/v1/import/undo` 只回退这一批导入、保留用户之后的操作。
 *   仍未做的两件：① 设置只应用 Kotlin 已移植的时间/周次子集（`TimetableSettings` 的
 *   边界说明）；② 地点分组改变后**不重算**课程钟点（Dart
 *   `replaceLocationTimeGroups(resync: true)` 的对应物在仓储层还没有）。
 *   调色板同步：局域网课程颜色按 `normalizeLanCourseColor` 收窄到 `#RRGGBB`（防 HTML 注入面）。
 * - **多档案整份恢复不支持**：备份里 `profiles` 非空时明确抛
 *   [LanTransferLogic.ERROR_PROFILE_BACKUP_PROFILES_UNSUPPORTED]，而不是静默只恢复
 *   活动档案（那会无声吞掉用户其它课表）。网页端按该错误码显示可读解释与替代路径
 *   （手机端「数据备份与迁移」支持整份档案恢复）；后续路线见该常量的 KDoc。
 * - ~~备份里的 `tasks` / `exams` 导出会带上、导入不写回~~ **已修（2026-11-01）**：
 *   整份备份导出补齐了日程 / 日期规则 / 地点作息分组，导入改走 [LanTransferApplier]，
 *   八张实体表 + 时间模板全部写回（P0 数据丢失）。
 */
class LanEditRepositoryHost(
    private val repository: TimetableRepository,
    /**
     * 撤销点索引。局域网服务传进程级单例 [LanTransferUndoStore.shared]（停服再开仍可撤销）；
     * 单测各自建独立实例，避免用例之间互相污染。
     */
    private val undoStore: LanTransferUndoStore = LanTransferUndoStore(),
    /** 表格解析器，由接线方注入（见 [LanEditSpreadsheetParse] 的说明）。 */
    private val parseSpreadsheet: (ByteArray, String, TimetableSettings) -> LanEditSpreadsheetParse = { _, _, _ ->
        throw UnsupportedOperationException("spreadsheet_import_unsupported")
    },
) : LanEditHost, LanTransferHost {

    /** 传输包预览/应用/撤销的执行层（无状态，只持仓储与撤销索引）。 */
    private val applier = LanTransferApplier(repository, undoStore)

    /**
     * 仓储在构造时就装载完毕（`TimetableRepository.init { reload() }`），
     * 所以这里**刻意不 reload**：局域网服务与界面共用同一个仓储实例，
     * 每次请求都 reload 会把界面上正在编辑的内存状态冲掉。
     */
    override fun ensureInitialized() = Unit

    override val activeProfileId: String? get() = repository.snapshot.activeProfileId

    override val activeProfileName: String?
        get() = TimetableHostLogic.resolveProfileName(
            profiles = repository.snapshot.profiles,
            activeProfileId = repository.snapshot.activeProfileId,
        )

    override fun listProfilesSummary(): List<Map<String, Any?>> {
        val snapshot = repository.snapshot
        return snapshot.profiles.map { profile ->
            linkedMapOf<String, Any?>(
                "id" to profile.id,
                "name" to profile.name,
                "courseCount" to profile.courses.size,
                "currentWeek" to profile.currentWeek.toInt(),
                "isActive" to (profile.id == snapshot.activeProfileId),
            )
        }
    }

    override val currentWeek: Int get() = repository.snapshot.currentWeek

    override val semesterWeekCount: Int get() = repository.semesterWeekCount

    override val courses: List<Course> get() = repository.snapshot.courses

    override fun findCourse(id: String): Course? = repository.getCourseById(id)

    override fun createCourse(draft: Course): Course {
        repository.addCourse(draft)
        return repository.getCourseById(draft.id) ?: draft
    }

    override fun updateCourse(course: Course): Boolean {
        if (repository.getCourseById(course.id) == null) return false
        repository.updateCourse(course)
        return true
    }

    override fun deleteCourse(id: String): Boolean {
        if (repository.getCourseById(id) == null) return false
        repository.deleteCourse(id)
        return true
    }

    override fun deleteCoursesBatch(courseIds: List<String>): Int {
        var removed = 0
        for (id in courseIds) {
            if (deleteCourse(id)) removed++
        }
        return removed
    }

    override fun setCurrentWeek(week: Int) {
        repository.setCurrentWeek(week)
    }

    override fun switchProfile(profileId: String) {
        val snapshot = repository.snapshot
        if (snapshot.profiles.none { it.id == profileId }) {
            throw IllegalArgumentException("profile_not_found")
        }
        if (snapshot.activeProfileId == profileId) return
        if (!repository.setActiveProfile(profileId)) {
            throw IllegalArgumentException("profile_switch_failed")
        }
    }

    override fun buildMetaJson(): Map<String, Any?> {
        val snapshot = repository.snapshot
        val scheme = TimetableHostLogic.resolveActiveTimeScheme(
            schemes = snapshot.timeSchemes,
            activeTimeSchemeId = snapshot.activeTimeSchemeId,
        )
        val sections = (scheme?.sections ?: snapshot.settings.sections).map { it.toJson() }
        return linkedMapOf<String, Any?>(
            "semesterWeekCount" to snapshot.settings.semesterWeekCount,
            "sections" to sections,
            "currentWeek" to snapshot.currentWeek,
            "activeProfileId" to snapshot.activeProfileId,
            "activeTimeSchemeId" to snapshot.activeTimeSchemeId,
        )
    }

    // -----------------------------------------------------------------------
    // B 组：整份备份
    // -----------------------------------------------------------------------

    /**
     * 整份备份导出：按 Dart `buildCurrentPackage(channel: lan)` 的口径，
     * 打一份 **scope = currentTimetable** 的传输包（当前课表 + 设置 + 当前周 + 作息）。
     *
     * 用 [buildTransferPackageJson] 而不是自己拼 JSON：键序与信封常量是冻结契约
     * （`sync/TransferPackageValidation.kt` 那层就是为它写的），自己拼早晚会漂。
     */
    override fun exportProfileBackupJson(): String {
        val snapshot = repository.snapshot
        return MiniJson.encode(
            buildTransferPackageJson(
                packageId = TransferEnvelope.newPackageId(),
                scope = TransferScope.CURRENT_TIMETABLE,
                // 必须是 **Dart 口径的本地时间**（`yyyy-MM-ddTHH:mm:ss.mmm`，不带 Z）：
                // 校验器走 `DartTime.tryParseIso` → `LocalDateTime.parse`，`Instant.toString()`
                // 那种带 `Z` 的串会被判 `transfer_exported_at_invalid`，
                // 导出的包自己就过不了自己的校验（2026-10-28 实测踩到）。
                exportedAtIso = DartTime.toIso(LocalDateTime.now()),
                channel = TransferChannel.LAN,
                profileName = activeProfileName,
                currentWeek = snapshot.currentWeek,
                activeProfileId = snapshot.activeProfileId,
                settingsJson = snapshot.settings.toJson(),
                coursesJson = snapshot.courses.map { it.toJson() },
                tasksJson = repository.tasks.map { it.toJson() },
                examsJson = repository.exams.map { it.toJson() },
                // 2026-11-01 修（P0）：这三块原先没传，导出恒为空列表 ⇒ 接收端拿到
                // 的「整份备份」里日程 / 日期规则 / 地点作息分组**全部消失**。
                // 快照里都有，按 Dart `buildCurrentPackage` 的同源口径原样写出。
                scheduleItemsJson = snapshot.scheduleItems.map { it.toJson() },
                scheduleDateRulesJson = snapshot.scheduleDateRules.map { it.toJson() },
                locationTimeGroupsJson = snapshot.locationTimeGroups.map { it.toJsonMap() },
                timeSchemesJson = snapshot.timeSchemes.map { it.toJson() },
            ),
        )
    }

    override fun importProfileBackupJson(content: String) {
        // 2026-11-01 修（P0）：旧版只手写「课程 + 设置 + 当前周」，**作业、考试、
        // 日程、日期规则、地点作息分组、时间模板全部丢掉**（导出侧已经带着它们，
        // 导入侧却不认）。Dart 的 `importProfileBackupJson` 就是
        // `applyToProvider(mode: overwrite)`，所以这里直接复用同一条 LAN 应用链
        // （`LanTransferApplier`）：逐条写回八张实体表、补/并时间模板并按映射改写
        // 引用、失败尽力回滚。不再在 LAN 层另写一份字段映射。
        //
        // 契约不变：
        // - 结构门 / 多档案包（`profiles` 非空）/ 整设备包（`backupType: full` 或
        //   `scope: all_data`）由 `parseIncoming` 抛 [FormatException]，**此时一个
        //   字节都没写**（校验在落盘之前）；多档案仍是「明确拒绝」，不会静默只恢复活动档案。
        // - 落盘阶段失败时 applier 先补偿再回 `applied: false`，这里折成 [FormatException]，
        //   路由层照旧折 400。
        val result = applier.apply(content, TransferApplyMode.OVERWRITE)
        if (result["applied"] != true) {
            throw FormatException((result["error"] as? String) ?: "transfer_import_failed")
        }
    }

    // -----------------------------------------------------------------------
    // B 组：组替换 / 表格导入
    // -----------------------------------------------------------------------

    /**
     * 组替换：走 `TimetableCourseService.updateGroup`（Dart `replaceCourseGroup` 的对应物）。
     * 传进去的 `originalName` 为 null 时按第一门课的课名当组名（Dart 的回落口径）。
     */
    override fun replaceCourseGroup(originalName: String?, slots: List<Course>): List<Course> {
        val groupName = originalName?.trim().orEmpty().ifEmpty { slots.first().name }
        TimetableCourseService.updateGroup(repository, groupName, slots)
        val key = groupName.trim()
        return repository.courses.filter { it.name.trim() == key }
    }

    override fun importSpreadsheetBytes(
        bytes: ByteArray,
        fileName: String,
        replaceExisting: Boolean,
    ): LanEditSpreadsheetImport {
        val parsed = parseSpreadsheet(bytes, fileName, repository.snapshot.settings)
        if (parsed.courses.isEmpty()) {
            // Dart 同口径：一门都没解析出来时**不落盘**，直接回 0 + 警告。
            return LanEditSpreadsheetImport(0, parsed.warnings, parsed.format)
        }
        if (replaceExisting) {
            TimetableCourseService.clearActiveProfileCourses(repository)
        }
        // 同样逐门 add：表格每一行都是**独立**的课（名字各不相同），
        // `addGroup` 会把它们压成同一门课（见 importProfileBackupJson 里的同一处说明）。
        for (course in parsed.courses) {
            repository.addCourse(course)
        }
        return LanEditSpreadsheetImport(parsed.courses.size, parsed.warnings, parsed.format)
    }

    // -----------------------------------------------------------------------
    // B 组：传输包预览 / 应用（批次 F17 接线；逻辑见 LanTransferLogic / LanTransferApplier）
    // -----------------------------------------------------------------------

    /**
     * Dart `LanEditProviderHost.previewTransferJson`：回 merge / overwrite 两套差异。
     * 结构不合法（含整份备份、`all_data`、带 profiles 的包）抛 [FormatException]，
     * 由路由层折成 400 `invalid_request`。
     */
    override fun previewTransferJson(content: String): Map<String, Any?> = applier.preview(content)

    /**
     * Dart `LanEditProviderHost.applyTransferJson`：**先校验后落盘**，失败回 `applied: false`。
     * 成功后 `transferId` 是这个撤销点的真实 id（不是包里的 `packageId`）。
     */
    override fun applyTransferJson(content: String, mode: TransferApplyMode): Map<String, Any?> =
        applier.apply(content, mode)

    /**
     * `POST /api/v1/import/undo`：凭 `transferId` 撤回这次导入。
     *
     * 只回退这次导入写入、且之后没被用户改过的那部分（判据见 [LanTransferUndoLogic]）；
     * 不认识的 id / 已撤销过的 id 都安全跳过，不写盘。
     */
    override fun undoTransferJson(transferId: String): Map<String, Any?> = applier.undo(transferId)
}
