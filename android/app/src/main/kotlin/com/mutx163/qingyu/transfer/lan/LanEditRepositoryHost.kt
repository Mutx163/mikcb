package com.mutx163.qingyu.transfer.lan

import com.mutx163.qingyu.app.TimetableHostLogic
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseColorPalette
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
 * - **多档案整份恢复已支持**（2026-11-03，分层放行）：`backupType: full` + 非空
 *   profiles 的包走 [LanTransferApplier] 的整份快照恢复（校验 → 预演 → 仓储
 *   `restoreFromCloudSnapshot` 一次落盘 + 撤销点）。仍明确拒的三种形状理由各不相同：
 *   `all_data` 非 full（清空全设备规则/分组的绕过形状）、full 缺档案（无可恢复内容）、
 *   非 full 带 profiles（要么静默丢档案要么拒）——矩阵见 [LanTransferLogic.parseIncoming]。
 * - **局部传输的 diff/预览 / 应用 / 撤销已接线**（2026-10-30 应用，2026-11-02 撤销）：
 *   `previewTransferJson` / `applyTransferJson` / `undoTransferJson` 交给
 *   [LanTransferApplier]（纯逻辑 [LanTransferLogic] + [LanTransferUndoLogic] + 仓储写入）。
 *   `applyTransferJson` 成功后回真实 `transferId`（撤销点 id），凭它调
 *   `POST /api/v1/import/undo` 只回退这一批导入、保留用户之后的操作；
 *   整份恢复的撤销是全有或全无（导入后数据被动过即拒，见 [LanTransferApplier.undo]）。
 *   2026-11-03 补齐的两件：① 设置改为**整份文档合并写回**（Dart 侧 250+ 键不再丢，
 *   设备级更新镜像保留本机值），撤销 / 失败补偿按原文还原；② 地点分组变化后按新分组
 *   **重算课程钟点**（Dart `replaceLocationTimeGroups(resync: true)` 的对应物
 *   `TimetableRepository.updateLocationTimeGroups(resync = true)`）。
 *   调色板同步：局域网课程颜色按 `normalizeLanCourseColor` 收窄到 `#RRGGBB`（防 HTML 注入面）。
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
    /**
     * 整份设置读写缝（Dart 250+ 键口径）。为 null 时退化为核心四键子集
     * （老单测与未接线调用方不受影响）。
     */
    private val settingsStore: LanTransferSettingsStore? = null,
) : LanEditHost, LanTransferHost {

    /** 传输包预览/应用/撤销的执行层（无状态，只持仓储与撤销索引）。 */
    private val applier = LanTransferApplier(
        repository = repository,
        undoStore = undoStore,
        settingsStore = settingsStore,
    )

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

    /**
     * 局域网编辑网页端星期标签（对齐 Dart `buildMetaJson` 的内联字面量
     * `['周一'…'周日']`——Dart 侧就是硬编码中文，不走 ARB，这里同口径）。
     *
     * 这 7 条中文已按**协议内中文**登记进 `cjk-literal-baseline-main.txt`（i18n 门禁放行）：
     * 它们只作为 meta API 的 JSON 字段下发给网页，手机 UI 不渲染、main 源集也没有
     * `ArbText`；网页端 `assets/lan_edit/i18n.js` 四语都有 `weekdayMon..weekdaySun`，
     * `weekdayHeaderText()` 见到「周」前缀标签就改写成本地文案——改发键名反而会把
     * 键名原样上屏，破坏四语显示。
     */
    private val weekdayLabels = listOf("周一", "周二", "周三", "周四", "周五", "周六", "周日")

    override fun buildMetaJson(): Map<String, Any?> {
        val snapshot = repository.snapshot
        val scheme = TimetableHostLogic.resolveActiveTimeScheme(
            schemes = snapshot.timeSchemes,
            activeTimeSchemeId = snapshot.activeTimeSchemeId,
        )
        val effectiveSections = scheme?.sections ?: snapshot.settings.sections
        val sections = effectiveSections.map { it.toJson() }
        // 2026-11-02 修：原来只回 5 个键，Dart 版回 9 个；网页端
        // `assets/lan_edit/app.js` 直接读 `presetColors`（选色块）、`weekdayLabels`、
        // `sectionCount`、`profileId`/`profileName`、`profiles`——缺了就各自退化
        // （选色只剩一个默认蓝、周几显示成数字等）。这里逐字段对齐 Dart
        // `LanEditProviderHost.buildMetaJson`；末尾两个 Kotlin 键是本仓扩展，保留。
        return linkedMapOf<String, Any?>(
            "profileId" to snapshot.activeProfileId,
            "profileName" to activeProfileName,
            "currentWeek" to snapshot.currentWeek,
            "semesterWeekCount" to snapshot.settings.semesterWeekCount,
            "sectionCount" to effectiveSections.size,
            "sections" to sections,
            "presetColors" to CourseColorPalette.PRESET_COURSE_COLOR_HEXES,
            "weekdayLabels" to weekdayLabels,
            "profiles" to listProfilesSummary(),
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
                settingsJson = settingsStore?.readSettingsJson() ?: snapshot.settings.toJson(),
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
        // - 结构门 / 整设备包的分层拒绝（`all_data` 非 full、full 缺档案、非 full 带
        //   profiles）由 `parseIncoming` 抛 [FormatException]，**此时一个字节都没写**
        //   （校验在落盘之前）；`backupType: full` + profiles 的整份包走整份快照恢复。
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
        // 2026-11-02 修（P0）：旧实现 replaceExisting=true 时**先清空旧课表（立即落盘）
        // 再逐行 add**，任一行校验/落盘失败只回 400——旧课表已经没了、新课表只写了一半。
        // 现在先在内存里校验+归一全部行（[TimetableCourseService.prepareForImport]，
        // 与逐行 add 同一份校验/归一逻辑），任一行非法在这里抛，盘上一个字节都没动；
        // 全部通过后走 [TimetableRepository.replaceActiveProfileContent] **一次落盘**
        // （先落盘、成功才改内存），不存在「清完没写完」的中间态。这与 Dart
        // `importParsedCourses` 的「内存合并 → 整份替换 → 一次 persist → 失败恢复」同型，
        // 只是把失败恢复做进了唯一写入口的失败语义里（该入口落盘失败时内存与盘都不动）。
        //
        // 与逐行 add 的两处已知行为差异（有意，对齐 Dart 的整份替换口径）：
        // - 落盘与通知从「每行一次」变成「整批一次」，界面不再闪中间态；
        // - 覆盖模式沿用 clearActiveProfileCourses 的口径：挂在课程上的作业一起清、
        //   考试刻意保留（清空后往往马上重导，考试留着才接得上）。
        val prepared = parsed.courses.map { course ->
            TimetableCourseService.prepareForImport(repository, course)
        }
        val beforeCourses = repository.courses
        val beforeTasks = repository.tasks
        val beforeExams = repository.exams
        val nextCourses = if (replaceExisting) prepared else beforeCourses + prepared
        val nextTasks = if (replaceExisting) {
            beforeTasks.filter { it.courseId == null }
        } else {
            beforeTasks
        }
        repository.replaceActiveProfileContent(nextCourses, nextTasks, beforeExams)
        // 课表整份换掉了，「当前正在上的课」缓存必须失效（clearActiveProfileCourses 同口径）。
        repository.clearCurrentLiveCourseId()
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
