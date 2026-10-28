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
import com.mutx163.qingyu.sync.validateTransferPackageJson
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
 * 整份备份导入是**唯一能一次性覆盖用户全部课表**的操作。所以
 * [importProfileBackupJson] 的顺序是死的：
 * 1. `validateTransferPackageJson`（纯函数，不碰存储）；
 * 2. 把要写的课**全部**解析成模型（仍不碰存储）；
 * 3. 只有前两步都过了，才开始清空 + 写入。
 *
 * 任何一步抛错，盘上一个字节都没动 —— 这条有测试钉着（见 `LanEditRepositoryHostTest`）。
 *
 * ## 明确不做的（诚实清单）
 *
 * - `previewTransferJson` / `applyTransferJson` 返回 null（→ 501）：Kotlin 侧还没有
 *   传输包的 diff/预览与应用服务，`pages/transfer` 只有渲染层模型。等那层落地再接。
 * - **多档案整份恢复不支持**：备份里 `profiles` 非空时明确抛
 *   `profile_backup_profiles_unsupported`，而不是静默只恢复活动档案
 *   （那会无声吞掉用户其它课表）。要支持得给仓储加「替换整份档案表」的入口，
 *   属 Lead 决定的范围，本泳道不自己加。
 * - 备份里的 `tasks` / `exams` **导出会带上、导入不写回**：恢复作业与考试需要
 *   `TimetableCourseService` 上没有的批量入口，留待 Lead 拍板。
 */
class LanEditRepositoryHost(
    private val repository: TimetableRepository,
    /** 表格解析器，由接线方注入（见 [LanEditSpreadsheetParse] 的说明）。 */
    private val parseSpreadsheet: (ByteArray, String, TimetableSettings) -> LanEditSpreadsheetParse = { _, _, _ ->
        throw UnsupportedOperationException("spreadsheet_import_unsupported")
    },
) : LanEditHost {

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
                timeSchemesJson = snapshot.timeSchemes.map { it.toJson() },
            ),
        )
    }

    override fun importProfileBackupJson(content: String) {
        // ---- 第 1 步：校验（纯函数，不碰存储）----
        val validation = validateTransferPackageJson(content)
        if (!validation.isValid) {
            throw FormatException(validation.errors.first())
        }
        val root = MiniJson.tryParse(content) as? Map<*, *>
            ?: throw FormatException("transfer_package_json_invalid")
        val profiles = root["profiles"] as? List<*> ?: emptyList<Any?>()
        if (profiles.isNotEmpty()) {
            // 多档案整份恢复要「替换整份档案表」的仓储入口；没有就先明确拒绝，
            // 不静默只恢复活动档案（那会无声吞掉用户其它课表）。
            throw FormatException("profile_backup_profiles_unsupported")
        }

        // ---- 第 2 步：把要写的东西全部解析出来（仍然不碰存储）----
        val courses = parseCourseList(root["courses"])
        val settings = (root["settings"] as? Map<*, *>)?.let { raw ->
            try {
                @Suppress("UNCHECKED_CAST")
                TimetableSettings.fromJson(raw as Map<String, Any?>)
            } catch (error: Exception) {
                throw FormatException("transfer_settings_invalid")
            }
        }
        val week = (root["currentWeek"] as? Number)?.toInt()

        // ---- 第 3 步：前两步都过了才落盘，全部走仓储/服务 ----
        //
        // ⚠️ 这里**必须逐门 addCourse，不能用 addGroup**：`addGroup` 是「同一门课排在
        // 不同天」的工具，它会把整组课的名字/教师/地点统一成第一门课的
        //（`CourseDomain.applySharedFields(course, shared)`）。拿它恢复一份含多门**不同**
        // 课的备份，会把所有课名压成第一个课名——2026-10-28 实测踩到（测试当场变红）。
        TimetableCourseService.clearActiveProfileCourses(repository)
        for (course in courses) {
            repository.addCourse(course)
        }
        settings?.let { repository.updateSettings(it) }
        week?.let { repository.setCurrentWeek(it) }
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
    // B 组：传输包预览 / 应用（Kotlin 侧还没有服务 → 501）
    // -----------------------------------------------------------------------

    override fun previewTransferJson(content: String): Map<String, Any?>? = null

    override fun applyTransferJson(content: String, mode: TransferApplyMode): Map<String, Any?>? = null

    // -----------------------------------------------------------------------
    // 内部
    // -----------------------------------------------------------------------

    /** 把包里的 `courses` 全部解析成模型；任何一条坏 → [FormatException]（此时还没写任何东西）。 */
    private fun parseCourseList(raw: Any?): List<Course> {
        if (raw !is List<*>) return emptyList()
        val courses = ArrayList<Course>(raw.size)
        for (item in raw) {
            if (item !is Map<*, *>) throw FormatException("transfer_course_invalid")
            try {
                @Suppress("UNCHECKED_CAST")
                courses.add(Course.fromJson(item as Map<String, Any?>))
            } catch (error: Exception) {
                throw FormatException("transfer_course_invalid")
            }
        }
        return courses
    }
}
