package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.app.TimetableSnapshot
import com.mutx163.qingyu.calendar.ScheduleDateRuleLogic
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.DartTime
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.ScheduleDateRule
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.WeekCalculator
import com.mutx163.qingyu.share.TransferChannel
import com.mutx163.qingyu.share.TransferScope
import com.mutx163.qingyu.share.TransferScopeWindow
import com.mutx163.qingyu.share.carriesSettings
import com.mutx163.qingyu.sync.buildTransferPackageJson
import com.mutx163.qingyu.sync.validateTransferPackageJson
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * 数据备份与迁移页的**拼包**模型层（导出当前课表 / 导出全部数据 / 导出时间模板，
 * 以及二维码发送复用同一条打包装配线）。
 *
 * ## 它移植的是什么
 *
 * Dart 侧这条链分两段：
 * 1. `UnifiedTransferService.buildCurrentPackage`（`lib/services/unified_transfer_service.dart:158-408`）
 *    —— 决定「哪些实体进包、哪些被 scope 裁掉」，
 * 2. `UnifiedTransferService.buildFullPackage`（同文件 `:353-368`）—— 全量备份那一支。
 *
 * 两者最终都落到 `TransferPackage.toJson()`。Kotlin 侧的中段（键序 + 信封常量 +
 * 结构门）已经由 `sync/TransferPackageValidation.kt` 的 [buildTransferPackageJson]
 * 冻结好了，所以本对象**只负责选材**：谁进包、谁不进包、文件名与分享文案怎么拼。
 * 键序、信封常量、唯一 id 规则一律不在这里重写——自己再拼一遍 JSON 迟早与契约漂开。
 *
 * ## 为什么这个文件在 JVM 单测里可跑
 *
 * 全程纯 Kotlin（无 Compose / 无 Android / 不读文件、不碰分享面板）。分享本身、
 * 文件写入、二维码编码都是平台能力，由宿主（`composeP1/.../DataTransferPage.kt`）
 * 在拿到 [TransferPackageResult.Success] 之后自己做。
 *
 * ## 与 Dart 的已知差异（刻意，逐条都有理由）
 *
 * 1. **落盘路径不同**：Dart 的 `exportedAt` 是 `DateTime.now().toIso8601String()`
 *    （本地墙上时刻、无 `Z`）；这里由 [TransferPackageRequest.now] 注入，用
 *    [DartTime.toIso] 产出同一形状（`yyyy-MM-ddTHH:mm:ss.mmm`）。**绝不能**用
 *    `Instant.toString()`/带 `Z` 的串：校验器走 `DartTime.tryParseIso` →
 *    `LocalDateTime.parse`，带 `Z` 会被判 `transfer_exported_at_invalid`，
 *    自己产的包过不了自己的校验（2026-10-28 在 `LanEditRepositoryHost` 实测踩到）。
 * 2. **作息规则精确到日程条目的那套过滤是近似的**：Dart 用
 *    `item.expandInstances(fromDate, toDate).any(window.containsDate)`；Kotlin
 *    `ScheduleItem` 没有 `expandInstances`，这里按 `occursOn(day)` 逐日走窗口
 *    （同一天序、同一 `containsDate` 判据），语义一致但实现不同。
 * 3. ~~**`locationTimeGroups` 恒为空**~~ **已修（2026-10-30）**：这条差异的前提是错的。
 *    [TimetableSnapshot] 早就有 `locationTimeGroups`（`TimetableRepository.kt:45`），
 *    原先恒写空列表是**导出侧丢数据**，不是刻意差异。现在按 `snapshot.locationTimeGroups`
 *    原样写出（与 Dart `provider.locationTimeGroups` 同源），包内键名 `locationTimeGroups`。
 *    受它影响的「按地点匹配作息」分支（Dart `_selectScopedMetadata` 里的
 *    `LocationTimeMatchLogic`）因此才拿得到分组。
 * 4. **设置整份导出**（2026-11-07 修）：`core/TimetableSettings.toJson()` 只有
 *    `sections` / `activeTimeSchemeId` / `semesterWeekCount` / `semesterStartDate`
 *    （+`semesterStartDateText`）/ `classReminders` 六个键，Dart 是 250+ 键。
 *    旧实现直接写 [TimetableSnapshot.settings] 的 core 投影，导出的包只剩 6 键，
 *    接收端恢复时其余偏好被抹成默认。现在由宿主把**盘上完整 settings map**
 *    经 [build] 的 `settingsJson` / `profileSettingsById` 传进来，原样写包；
 *    缺省（旧调用点/单测）时才回落到 core 投影。
 * 5. **失败前置**：Dart 打包后不先自检，空包要等接收端 `validate()` 才被拒
 *    （`transfer_package_empty`）。这里打完就地跑一次
 *    [validateTransferPackageJson]，不合法立刻返回 [TransferPackageResult.Failure]，
 *    省掉「点分享 → 对方扫了 → 才发现包是空的」这一圈。
 * 6. **空选课直接拒**：Dart 的 `selectedCourses` 在勾选为空时产出「0 门课 + 无归属作业」
 *    的包（它依赖上层 UI 先强制勾课）。这种包语义上是垃圾，这里提前返回
 *    `no_selected_courses`（本仓新增码），不让它流到扫码/文件那一侧。
 */
enum class TransferExportScopeKind { CURRENT_TIMETABLE, ALL_DATA, TIME_TEMPLATE }

/**
 * 一次打包请求（宿主按页面三个按钮 + 二维码范围填）。
 *
 * [packageId] 与 [now] 都由调用方注入而不是在这里取 `System`/`LocalDateTime.now()`：
 * 单测要能把 id 与时间钉死，才能对「文件名 / `exportedAt` / 完整 JSON」做逐字断言。
 */
data class TransferPackageRequest(
    /** 支持的取值：CURRENT_TIMETABLE / ALL_DATA / TIME_TEMPLATE / WEEK_TIMETABLE / SELECTED_COURSES。 */
    val scope: TransferScope,
    val channel: TransferChannel,
    /** 由调用方注入（生产用 `TransferEnvelope.newPackageId()`，测试可钉死）。 */
    val packageId: String,
    /** 由调用方注入（生产用 `LocalDateTime.now()`，测试可钉死）。 */
    val now: LocalDateTime,
    /** 仅 SELECTED_COURSES / SELECTED_COURSE 用；其它 scope 为空即「全带」。 */
    val selectedCourseIds: Set<String> = emptySet(),
)

sealed interface TransferPackageResult {
    data class Success(
        /** `MiniJson.encode(包 Map)`——键序 = Dart `TransferPackage.toJson`。 */
        val json: String,
        /** 分享文件名：`前缀-yyyyMMdd-HHmm.mikcb`。 */
        val fileName: String,
        /** 系统分享正文（ARB 逐字）。 */
        val shareText: String,
        /** 系统分享主题（ARB 逐字；有课表名时带名字）。 */
        val shareSubject: String,
        val scope: TransferScope,
        /** 全量备份（`backupType: full` + `profiles` 非空）。 */
        val isFullBackup: Boolean,
    ) : TransferPackageResult

    /** 机器码（例：`no_time_schemes` / `no_active_profile` / `transfer_package_empty`）。 */
    data class Failure(val code: String) : TransferPackageResult
}

object DataTransferPackageLogic {

    // ── 分享文案（`lib/l10n/app_zh.arb` 逐字；本页只用到这三条 + 三个主题） ──

    private val profileShareText = ArbText(
        "dataTransferProfileShareText",
        "这是轻屿课表当前课表的完整备份文件，导入后可直接恢复课程和设置",
    )
    private val profileShareSubject =
        ArbText("dataTransferProfileShareSubject", "轻屿课表备份")
    private val profileShareSubjectNamed =
        ArbText("dataTransferProfileShareSubjectNamed", "{profileName} - 轻屿课表备份")
    private val fullBackupShareText = ArbText(
        "dataTransferFullBackupShareText",
        "这是轻屿课表的全部数据备份文件，包含所有课表、当前选中课表和时间模板",
    )
    private val fullBackupShareSubject =
        ArbText("dataTransferFullBackupShareSubject", "轻屿课表 - 全部数据备份")
    private val timeSchemeShareText = ArbText(
        "dataTransferTimeSchemeShareText",
        "这是轻屿课表的时间模板分享文件，导入后即可恢复使用",
    )
    private val timeSchemeShareSubjectArb =
        ArbText("timeSchemeShareSubject", "轻屿课表 · 时间模板")

    /** 本对象用到的全部文案（供 ARB 逐字对拍测试遍历）。 */
    val allTexts: List<ArbText> = listOf(
        profileShareText,
        profileShareSubject,
        profileShareSubjectNamed,
        fullBackupShareText,
        fullBackupShareSubject,
        timeSchemeShareText,
        timeSchemeShareSubjectArb,
    )

    /** 页面三个导出按钮 → 传输范围。 */
    fun scopeFor(kind: TransferExportScopeKind): TransferScope = when (kind) {
        TransferExportScopeKind.CURRENT_TIMETABLE -> TransferScope.CURRENT_TIMETABLE
        TransferExportScopeKind.ALL_DATA -> TransferScope.ALL_DATA
        TransferExportScopeKind.TIME_TEMPLATE -> TransferScope.TIME_TEMPLATE
    }

    /** 需要「有课表」才打得出来的范围（没有活动课表时返回 `no_active_profile`）。 */
    private val SCOPES_NEEDING_TIMETABLE = setOf(
        TransferScope.CURRENT_TIMETABLE,
        TransferScope.WEEK_TIMETABLE,
        TransferScope.SELECTED_COURSES,
        TransferScope.SELECTED_COURSE,
    )

    /**
     * 打包。
     *
     * 失败一律走 [TransferPackageResult.Failure]（不抛异常）：
     * - `no_time_schemes`：`TIME_TEMPLATE` 但一条时间模板都没有；
     * - `no_active_profile`：需要课表却没有活动档案；
     * - `transfer_package_empty`（及校验器其它错误码）：打出来的包自己不合法。
     *
     * 成功时保证 `validateTransferPackageJson(json).isValid == true`。
     */
    fun build(
        snapshot: TimetableSnapshot,
        request: TransferPackageRequest,
        /**
         * 盘上**活动档案的完整 settings map**（含 Dart 侧 250+ 偏好键）。
         *
         * null = 调用方没有完整文档（旧测试），回落 [TimetableSnapshot.settings] 的
         * core 投影。生产宿主必须传 `repository.readRawSettings()`，否则又退回
         * 「只带 6 键」的旧缺陷。
         */
        settingsJson: Map<String, Any?>? = null,
        /**
         * 全量备份用：每份档案 id → 盘上内嵌的完整 settings map。
         *
         * [TimetableProfile.toJson] 的 `settings` 只有 core 键；全量包不带这份映射
         * 就会在每份档案里丢掉其余偏好。
         */
        profileSettingsById: Map<String, Map<String, Any?>> = emptyMap(),
    ): TransferPackageResult {
        val scope = request.scope
        val channel = request.channel
        val activeProfile = snapshot.profiles.firstOrNull { it.id == snapshot.activeProfileId }
            ?: snapshot.profiles.firstOrNull()

        if (scope == TransferScope.TIME_TEMPLATE && snapshot.timeSchemes.isEmpty()) {
            return TransferPackageResult.Failure("no_time_schemes")
        }
        if (scope in SCOPES_NEEDING_TIMETABLE && activeProfile == null) {
            return TransferPackageResult.Failure("no_active_profile")
        }
        val scopedSelection = scope == TransferScope.SELECTED_COURSES ||
            scope == TransferScope.SELECTED_COURSE
        if (scopedSelection && request.selectedCourseIds.isEmpty()) {
            // 见类注释「已知差异 6」：空勾选会产出一个只含无归属作业的空壳包。
            return TransferPackageResult.Failure("no_selected_courses")
        }

        val isFullBackup = scope == TransferScope.ALL_DATA

        // 选材：课程 → 作业/考试 → 附属元数据（Dart `buildCurrentPackage` 的四段）。
        val sourceCourses: List<Course> = when {
            scope == TransferScope.WEEK_TIMETABLE ->
                snapshot.courses.filter { it.isActiveInWeek(snapshot.currentWeek) }
            else -> snapshot.courses
        }
        val selected = request.selectedCourseIds
        val courses: List<Course> = when {
            scope == TransferScope.TIME_TEMPLATE -> emptyList()
            scopedSelection -> sourceCourses.filter { selected.contains(it.id) }
            selected.isEmpty() -> sourceCourses
            else -> sourceCourses.filter { selected.contains(it.id) }
        }
        val courseIds = courses.map { it.id }.toSet()

        // ⚠️ 附属数据必须跟着课程一起收窄（Dart 同处有一整段事故注释）：
        // `WEEK_TIMETABLE` 上面已按周筛过课，若这里走「全带」就会把**别周**的作业与
        // 考试一起打包；接收端 `exam_course_missing` 判 error，整单导入被拒
        // （「分享本周课表」直接不可用），若接收端恰好有同 id 的课还会导入包外数据。
        val keepsAllCourses = selected.isEmpty() && !scopedSelection &&
            scope != TransferScope.WEEK_TIMETABLE
        // TimetableSnapshot 只扁平化了课程与日程，作业/考试在活动档案里，取法见
        // `app/TimetableRepository.kt` 的 `snapshot` 构造（courses 来自 activeProfile）。
        val allTasks: List<CourseTask> = activeProfile?.tasks ?: emptyList()
        val allExams: List<Exam> = activeProfile?.exams ?: emptyList()
        val tasks: List<CourseTask> = when {
            scope == TransferScope.TIME_TEMPLATE -> emptyList()
            keepsAllCourses -> allTasks
            // 收窄时保留「无归属」作业（Dart：`item.courseId == null || ids.contains`）。
            else -> allTasks.filter { it.courseId == null || courseIds.contains(it.courseId) }
        }
        val exams: List<Exam> = when {
            scope == TransferScope.TIME_TEMPLATE -> emptyList()
            keepsAllCourses -> allExams
            else -> allExams.filter { courseIds.contains(it.courseId) }
        }

        val metadata = selectScopedMetadata(snapshot, scope, courses, request.now)

        val exportedSettingsJson = if (scope.carriesSettings && !isFullBackup) {
            settingsJson ?: snapshot.settings.toJson()
        } else {
            null
        }

        val packageMap = buildTransferPackageJson(
            packageId = request.packageId,
            scope = scope,
            // Dart 口径的本地墙上时刻（不带 Z），见类注释「已知差异 1」。
            exportedAtIso = DartTime.toIso(request.now),
            channel = channel,
            // 全量备份不带顶层 profileName（Dart `buildFullPackage` 不传）。
            profileName = if (isFullBackup) null else activeProfile?.name,
            currentWeek = when (scope) {
                TransferScope.TIME_TEMPLATE, TransferScope.ALL_DATA -> null
                else -> snapshot.currentWeek
            },
            activeProfileId = if (isFullBackup) snapshot.activeProfileId else null,
            settingsJson = exportedSettingsJson,
            coursesJson = if (isFullBackup) emptyList() else courses.map { it.toJson() },
            tasksJson = if (isFullBackup) emptyList() else tasks.map { it.toJson() },
            scheduleItemsJson = if (isFullBackup) {
                emptyList()
            } else {
                metadata.scheduleItems.map { it.toJson() }
            },
            examsJson = if (isFullBackup) emptyList() else exams.map { it.toJson() },
            timeSchemesJson = if (isFullBackup) {
                snapshot.timeSchemes.map { it.toJson() }
            } else {
                metadata.timeSchemes.map { it.toJson() }
            },
            scheduleDateRulesJson = if (isFullBackup) {
                snapshot.scheduleDateRules.map { it.toJson() }
            } else {
                metadata.scheduleDateRules.map { it.toJson() }
            },
            // 地点作息分组（顶层键 `locationTimeGroups`，Dart `FullAppDataBackup` 同键名）。
            // 2026-10-30 修（审核 P0）：原先恒写空列表，理由是「TimetableSnapshot 没有该字段」——
            // 但 `TimetableRepository.kt:45` 早就有 `locationTimeGroups`（`9c2ec06a` 引入，早于本文件）。
            // 结果导出侧静默丢数据：跨设备导入后「按地点匹配作息」全失效，且包内无痕迹。
            locationTimeGroupsJson = snapshot.locationTimeGroups.map { it.toJsonMap() },
            profilesJson = if (isFullBackup) {
                snapshot.profiles.map { profile -> profileJsonWithFullSettings(profile, profileSettingsById) }
            } else {
                emptyList()
            },
            isFullBackup = isFullBackup,
        )

        val json = MiniJson.encode(packageMap)
        // 自产包必须过自己的校验器，否则等于把坏包递到扫码/文件那一侧才炸。
        val validation = validateTransferPackageJson(json)
        if (!validation.isValid) {
            return TransferPackageResult.Failure(validation.errors.first())
        }

        val prefix = DataTransferLogic.shareFilePrefix(scope, isFullBackup)
        return TransferPackageResult.Success(
            json = json,
            fileName = DataTransferLogic.buildShareFileName(prefix, request.now),
            shareText = shareTextFor(scope),
            shareSubject = shareSubjectFor(scope, activeProfile?.name),
            scope = scope,
            isFullBackup = isFullBackup,
        )
    }

    /**
     * 档案 JSON + 盘上完整 settings（有就覆盖 core 投影）。
     *
     * 用 `LinkedHashMap` 复制：`TimetableProfile.toJson()` 返回可变 map，直接改会污染模型。
     */
    private fun profileJsonWithFullSettings(
        profile: TimetableProfile,
        profileSettingsById: Map<String, Map<String, Any?>>,
    ): Map<String, Any?> {
        val json = LinkedHashMap(profile.toJson())
        profileSettingsById[profile.id]?.let { full -> json["settings"] = full }
        return json
    }

    /** 分享正文：三条 ARB 按 scope 分派（`data_transfer_screen.dart:268-370`）。 */
    fun shareTextFor(scope: TransferScope): String = when (scope) {
        TransferScope.ALL_DATA -> fullBackupShareText.text
        TransferScope.TIME_TEMPLATE -> timeSchemeShareText.text
        else -> profileShareText.text
    }

    /** 分享主题：全量/时间模板各有专属主题，其余按「有无课表名」二选一。 */
    fun shareSubjectFor(scope: TransferScope, profileName: String?): String = when (scope) {
        TransferScope.ALL_DATA -> fullBackupShareSubject.text
        TransferScope.TIME_TEMPLATE -> timeSchemeShareSubjectArb.text
        else -> profileName?.let { profileShareSubjectNamed.filled("profileName", it) }
            ?: profileShareSubject.text
    }

    /** 一次打包里「跟着 scope 收窄」的四块附属数据。 */
    private data class ScopedMetadata(
        val scheduleItems: List<ScheduleItem>,
        val scheduleDateRules: List<ScheduleDateRule>,
        val timeSchemes: List<TimeScheme>,
    )

    /**
     * 附属元数据选材（Dart `_selectScopedMetadata`）。
     *
     * - `TIME_TEMPLATE`：只放时间模板，日程/规则全清（作息可以单独发给别人）；
     * - 非局部范围（当前课表 / 全量）：全带；
     * - 局部范围（本周 / 选课）：日程按时间窗口相交、日期规则按区间重叠，
     *   时间模板只带「被用到」的（课程覆盖 id / 默认作息 id / 日期规则引用 id）。
     */
    private fun selectScopedMetadata(
        snapshot: TimetableSnapshot,
        scope: TransferScope,
        courses: List<Course>,
        now: LocalDateTime,
    ): ScopedMetadata {
        if (scope == TransferScope.TIME_TEMPLATE) {
            return ScopedMetadata(
                scheduleItems = emptyList(),
                scheduleDateRules = emptyList(),
                timeSchemes = snapshot.timeSchemes,
            )
        }

        val isScoped = scope == TransferScope.SELECTED_COURSE ||
            scope == TransferScope.SELECTED_COURSES ||
            scope == TransferScope.WEEK_TIMETABLE
        if (!isScoped) {
            return ScopedMetadata(
                scheduleItems = snapshot.scheduleItems,
                scheduleDateRules = snapshot.scheduleDateRules,
                timeSchemes = snapshot.timeSchemes,
            )
        }

        val window = buildScopeWindow(snapshot, scope, courses, now)
        if (window.isEmpty) {
            return ScopedMetadata(emptyList(), emptyList(), emptyList())
        }
        val scheduleItems = snapshot.scheduleItems.filter { intersects(it, window) }
        val scheduleDateRules = snapshot.scheduleDateRules.filter { rule ->
            val start = ScheduleDateRuleLogic.parseIsoDate(rule.startDate)
            val end = ScheduleDateRuleLogic.parseIsoDate(rule.endDate)
            start != null && end != null &&
                window.overlapsDateRange(start.toLocalDate(), end.toLocalDate())
        }

        val timeSchemeIds = mutableSetOf<String>()
        for (course in courses) {
            val overrideId = course.timeSchemeIdOverride?.trim()
            if (!overrideId.isNullOrEmpty()) {
                timeSchemeIds.add(overrideId)
                continue
            }
            // Dart 这里还会先按地点匹配分组作息；本实现无分组（类注释「已知差异 3」）。
            timeSchemeIds.add(snapshot.settings.activeTimeSchemeId?.trim().orEmpty())
        }
        for (rule in scheduleDateRules) {
            val id = rule.timeSchemeId.trim()
            if (id.isNotEmpty()) timeSchemeIds.add(id)
        }
        val timeSchemes = snapshot.timeSchemes.filter { timeSchemeIds.contains(it.id) }
        return ScopedMetadata(scheduleItems, scheduleDateRules, timeSchemes)
    }

    /**
     * 局部范围的时间窗口（Dart `_buildScopeWindow`）。
     *
     * 学期起点按周一归一；学期未配置时退回 [now] 所在自然周。开学日是日历日，
     * 一律走 [WeekCalculator.startOfWeek] 的日历口径，**不用**毫秒时长（换时区会挪天）。
     */
    private fun buildScopeWindow(
        snapshot: TimetableSnapshot,
        scope: TransferScope,
        courses: List<Course>,
        now: LocalDateTime,
    ): TransferScopeWindow {
        val fallbackWeekStart: LocalDate = WeekCalculator.startOfWeek(now).toLocalDate()
        val isSelectedScope = scope == TransferScope.SELECTED_COURSE ||
            scope == TransferScope.SELECTED_COURSES
        if (isSelectedScope && courses.isEmpty()) {
            return TransferScopeWindow.empty(fallbackWeekStart)
        }
        val weeks: Set<Int> = if (scope == TransferScope.WEEK_TIMETABLE) {
            setOf(snapshot.currentWeek)
        } else {
            courses.flatMap { it.activeWeeks }.toSet()
        }
        if (weeks.isEmpty()) {
            return TransferScopeWindow.empty(fallbackWeekStart)
        }
        val semesterStart = snapshot.settings.semesterStartDate
        return TransferScopeWindow(
            weeks = weeks,
            semesterStartWeek = semesterStart?.let { WeekCalculator.startOfWeek(it).toLocalDate() },
            fallbackWeekStart = fallbackWeekStart,
        )
    }

    /**
     * 日程条目是否落在窗口里（Dart `_scheduleItemIntersects` 的等价实现）。
     *
     * 逐日走窗口而不是用 `expandInstances`——Kotlin `ScheduleItem` 没有那个方法，
     * 但 [ScheduleItem.occursOn] 承载同一套「区间 + 例外日 + 日/周重复」判据。
     */
    private fun intersects(item: ScheduleItem, window: TransferScopeWindow): Boolean {
        if (window.isEmpty) return false
        val end = window.endDate()
        var day = window.startDate()
        while (!day.isAfter(end)) {
            if (window.containsDate(day) && item.occursOn(day.atStartOfDay())) return true
            day = day.plusDays(1)
        }
        return false
    }
}
