package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.ScheduleDateRule
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimeSchemeLogic
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.core.clampCurrentWeekToSettings
import com.mutx163.qingyu.course.TimetableCoursePort
import com.mutx163.qingyu.course.TimetableCourseService
import com.mutx163.qingyu.sync.isLiveTestingFixtureCourseId
import java.time.LocalDateTime
import java.util.concurrent.CopyOnWriteArrayList

/**
 * 课表数据层的**不可变快照**。宿主拿它渲染，拿不到任何可变引用。
 *
 * `semesterStartEpochDay` 是开学日的**天序**（`LocalDate.toEpochDay()`）而不是毫秒：
 * 开学日是日历日期，毫秒会带上写入方时区（`TimetableSettings.parseSemesterStartDate`
 * 头注释记着「换时区恢复会挪天 → 整学期周次 +1、单双周翻转」的历史事故）。
 */
data class TimetableSnapshot(
    val profiles: List<TimetableProfile> = emptyList(),
    val activeProfileId: String? = null,
    val courses: List<Course> = emptyList(),
    /** 活动档案里的日程条目（`timetable_profiles[].scheduleItems`，冻结格式内嵌）。 */
    val scheduleItems: List<ScheduleItem> = emptyList(),
    /** 作息日期规则（顶层 key `schedule_date_rules`，不属于单个档案）。 */
    val scheduleDateRules: List<ScheduleDateRule> = emptyList(),
    val settings: TimetableSettings = TimetableSettings.defaults(),
    val currentWeek: Int = 1,
    val semesterStartEpochDay: Long? = null,
    val timeSchemes: List<TimeScheme> = emptyList(),
    val activeTimeSchemeId: String? = null,
)

/**
 * 课表仓储：**持有状态 + 实现写入口 + 变更即落盘并通知**。
 *
 * 移植自 Dart `lib/providers/timetable_provider.dart` 的课表族职责
 *（Dart 侧那份 3834 行、混了 UI 状态与 30 个域；本类只取「课表族数据 + 写入口」）。
 *
 * ## 分工（三层，谁都不越界）
 *
 * ```
 * TimetableCourseService（业务规则：归一、同组广播、作业联动、失败回滚）
 *        ↓ 通过 TimetableCoursePort 回调
 * TimetableRepository（本类：内存状态 + 落盘时机 + 通知）
 *        ↓
 * TimetableStore（冻结格式 JSON 编解码 + 损坏留档）
 * ```
 *
 * [TimetableCourseService] 只认 [TimetableCoursePort]，所以本类把 port 的
 * `courses/tasks/exams/profiles` 实现成「**改内存不落盘**」，
 * 落盘统一由服务显式调用的 [persistActiveProfileState] 触发——
 * 这正是 Dart 的 port 语义：服务负责「什么时候写」，宿主负责「写到哪」。
 *
 * ## 通知语义（测试钉的就是这两条）
 *
 * - **变更成功才通知**：服务先 `persistActiveProfileState()` 再 `notifyStateChanged()`；
 *   落盘抛错时服务回滚并上抛，`notifyStateChanged()` 根本不会被调到。
 * - **[observe] 不立刻推**：只在**后续变更**时回调。初始值读 [snapshot]。
 *   这样「通知次数」是可数的，宿主也不会在订阅瞬间被重入渲染。
 *
 * ## 明确不做的（诚实清单）
 *
 * - `logEvent` / `syncExamReminders` / `updateLiveActivity` 是**空实现**：
 *   埋点、考试提醒通知、实时活动都属 Phase 4 原生能力对齐，本阶段只接线数据。
 * - 不做跨 key 事务日志（`app_global_settings_mirror_tx_v1`）：那是全局设置族的活。
 * - 不做并发写串行化：宿主是单线程 Compose 状态持有者；真并发场景由 Phase 4 决定。
 */
class TimetableRepository(private val store: TimetableStore) : TimetableCoursePort, TimetableScheduleItemPort {

    private var loadedProfiles: List<TimetableProfile> = emptyList()
    private var loadedActiveProfileId: String? = null
    private var loadedSettings: TimetableSettings = TimetableSettings.defaults()
    private var loadedCurrentWeek: Int? = null
    private var loadedTimeSchemes: List<TimeScheme> = emptyList()
    private var loadedScheduleDateRules: List<ScheduleDateRule> = emptyList()

    /** Dart 侧是 provider 的一个内存字段（`_currentLiveCourseId`），不落盘。 */
    private var currentLiveCourseId: String? = null

    private val listeners = CopyOnWriteArrayList<(TimetableSnapshot) -> Unit>()

    init {
        reload()
    }

    // ---------- 装载 ----------

    /** 从盘上重新装载（[initialize] 与构造共用）。 */
    fun reload() {
        val profilesResult = store.loadProfiles()
        loadedProfiles = profilesResult.profiles
        val storedActiveId = store.loadActiveProfileId()
        // 悬空 id（指向不存在的档案）回落第一份，避免 activeProfileId 指向空气。
        loadedActiveProfileId = storedActiveId
            ?.takeIf { id -> loadedProfiles.any { it.id == id } }
            ?: loadedProfiles.firstOrNull()?.id
        loadedSettings = store.loadSettings()
        loadedCurrentWeek = store.loadCurrentWeek()
        loadedTimeSchemes = store.loadTimeSchemes().schemes
        loadedScheduleDateRules = store.loadScheduleDateRules()
    }

    /** 盘上档案的解析结果（含「只是条目级损坏」信号，供宿主决定是否提示用户）。 */
    fun loadProfilesResult(): TimetableStore.ProfilesLoadResult = store.loadProfiles()

    // ---------- 对外只读视图 ----------

    val snapshot: TimetableSnapshot
        get() = TimetableSnapshot(
            profiles = loadedProfiles,
            activeProfileId = activeProfile.id,
            courses = activeProfile.courses,
            scheduleItems = activeProfile.scheduleItems,
            scheduleDateRules = loadedScheduleDateRules,
            settings = loadedSettings,
            currentWeek = resolvedCurrentWeek(),
            semesterStartEpochDay = loadedSettings.semesterStartDate?.toLocalDate()?.toEpochDay(),
            timeSchemes = loadedTimeSchemes,
            activeTimeSchemeId = loadedSettings.activeTimeSchemeId,
        )

    /** 订阅变更；返回的 [AutoCloseable] 用于退订。**订阅时不立刻回调**（见类注释）。 */
    fun observe(listener: (TimetableSnapshot) -> Unit): AutoCloseable {
        listeners.add(listener)
        return AutoCloseable { listeners.remove(listener) }
    }

    // ---------- 对外写入口 ----------

    fun addCourse(course: Course) {
        TimetableCourseService.add(this, course)
    }

    fun updateCourse(course: Course, previousSharedName: String? = null) {
        TimetableCourseService.update(this, course, previousSharedName)
    }

    fun deleteCourse(courseId: String) {
        TimetableCourseService.delete(this, courseId)
    }

    /**
     * 切换激活档案。
     * @return true 表示真的切了（目标存在且与当前不同）；否则 false 且**不通知**。
     */
    fun setActiveProfile(profileId: String): Boolean {
        if (loadedProfiles.none { it.id == profileId }) return false
        if (profileId == activeProfile.id) return false
        loadedActiveProfileId = profileId
        store.saveActiveProfileId(profileId)
        notifyStateChanged()
        return true
    }

    /** 更新设置：落盘（合并写）后通知。 */
    fun updateSettings(settings: TimetableSettings) {
        loadedSettings = settings
        store.saveSettings(settings)
        notifyStateChanged()
    }

    // ---------- 备份恢复用的原子入口 ----------

    /**
     * **原子替换活动档案的三块内容**（课 / 作业 / 考试）：一次落盘、一次通知。
     *
     * 为什么要它：`courses` / `tasks` / `exams` 三个 setter **各自都会落盘并通知**
     * （见 [courses] 等），逐个用就是 3 次写 + 3 次通知——备份恢复这种整块替换
     * 既慢又会让界面闪三下中间态。本方法一次写、一次通知。
     *
     * **调用方义务**：本方法不做任何校验（不知道调用方在恢复什么）。备份包里的
     * 内容是否合法、是否该覆盖当前档案，由调用方先校验完再调这里。
     *
     * **失败语义**：先落盘、成功后才改内存；落盘抛错时内存与监听者都不动
     * （与 [addCourse] 等同一套「成功才通知」）。落盘本身是两次 key 写
     * （profiles + active id），两次之间失败会留下「盘新内存旧」——
     * Dart 侧用 `runSettingsMirrorTransaction` 覆盖这一段，本层未实现事务。
     */
    fun replaceActiveProfileContent(
        courses: List<Course>,
        tasks: List<CourseTask>,
        exams: List<Exam>,
    ) {
        val current = activeProfile
        val next = current.copy(courses = courses, tasks = tasks, exams = exams)
        val nextProfiles = upsertProfile(next)
        // 先落盘：失败则内存与监听者都不动。
        store.saveProfiles(nextProfiles)
        store.saveActiveProfileId(next.id)
        loadedProfiles = nextProfiles
        loadedActiveProfileId = next.id
        notifyStateChanged()
    }

    /**
     * **整份替换所有档案 + 指定激活项**（多档案备份恢复）。**破坏性操作。**
     *
     * ## 调用方义务（校验先行）
     *
     * 本方法**不校验、不合并、不备份**：传进来什么就写什么，当前档案列表会被整份替换掉。
     * 调用方必须先自己校验（备份包完整性、是否要覆盖、是否要留旧档），否则用户数据
     * 会无声消失。`activeProfileId` 传 null 表示「没有激活档案」（会删掉盘上那个键）。
     *
     * ## `activeProfileId` 不在 [profiles] 里时的口径（去 Dart 核过，不是自创）
     *
     * - **写侧**：Dart 恢复流程是 `saveProfiles(profiles)` 之后直接
     *   `setActiveProfileId(activeProfileId)`（`timetable_import_export_service.dart:296-301`），
     *   **不校验、不抛异常、不偷偷改写**。本方法照做：悬空 id 原样落盘。
     * - **读侧**：Dart 在 `timetable_provider.dart:864-872` 只对「指向**情侣导入**档案」
     *   这一种情况回落（换成本档案列表里第一个非情侣档案）；其余悬空 id **原样保留**，
     *   表现为 `activeProfile` 为 null。
     * - ⚠️ **本层读侧比 Dart 宽松**（task-7 已裁定并写进 KDoc）：任何悬空 id 都回落
     *   第一份档案，保证宿主拿到的 `activeProfile` 永不为 null。这是**有意偏离**，
     *   不是漏抄。
     *
     * **失败语义**：先落盘、成功后才改内存；落盘抛错时内存与监听者都不动。
     */
    fun replaceAllProfiles(profiles: List<TimetableProfile>, activeProfileId: String?) {
        // 先落盘：失败则内存与监听者都不动。
        store.saveProfiles(profiles)
        store.saveActiveProfileId(activeProfileId)
        loadedProfiles = profiles
        loadedActiveProfileId = activeProfileId
        notifyStateChanged()
    }

    /**
     * 切当前周次（宿主 `onWeekChanged` 的落点）。
     *
     * 语义逐条对齐 Dart `_setCurrentWeekImpl`（`timetable_provider.dart:1853-1866`）：
     * 1. **先钳制**：`clampCurrentWeekToSettings(week, settings)` —— `< 1` 归 1，
     *    `> semesterWeekCount` 归 `semesterWeekCount`，`semesterWeekCount < 1` 时上限按 1
     *    （`timetable_profile.dart:27-38`，即 [clampCurrentWeekToSettings] 本身，不自创口径）；
     * 2. 清 `currentLiveCourseId`（Dart 原注释：触发超级岛重刷）；
     * 3. 落盘：写 `current_week` **并且**把活动档案一起落盘（档案自带 currentWeek 要同步，
     *    Dart 走的是 `_persistActiveProfileState()`）；
     * 4. 落盘成功后才通知监听者（界面跟着翻周）。
     *
     * Dart 的 `notify: Boolean = true` 开关对应内部调用路径，本层暂无消费方，不预置。
     */
    fun setCurrentWeek(week: Int) {
        val clamped = clampCurrentWeekToSettings(week.toLong(), loadedSettings).toInt()
        loadedCurrentWeek = clamped
        currentLiveCourseId = null
        persistActiveProfileState()
        notifyStateChanged()
    }

    // ---------- TimetableCoursePort ----------

    override var courses: List<Course>
        get() = activeProfile.courses
        set(value) {
            updateActiveProfile { it.copy(courses = value) }
        }

    override var tasks: List<CourseTask>
        get() = activeProfile.tasks
        set(value) {
            updateActiveProfile { it.copy(tasks = value) }
        }

    override var exams: List<Exam>
        get() = activeProfile.exams
        set(value) {
            updateActiveProfile { it.copy(exams = value) }
        }

    override var profiles: List<TimetableProfile>
        get() = loadedProfiles
        set(value) {
            loadedProfiles = value
        }

    // ---------- TimetableScheduleItemPort ----------

    /**
     * 活动档案的日程列表。setter 只改内存（与 courses/tasks/exams 同口径），
     * 落盘由 [ScheduleItemService] 显式调用 [persistActiveProfileState] 触发。
     */
    override var scheduleItems: List<ScheduleItem>
        get() = activeProfile.scheduleItems
        set(value) {
            updateActiveProfile { it.copy(scheduleItems = value) }
        }

    // ---------- 作息日期规则 ----------

    /** 整份替换作息日期规则：落盘成功后才改内存并通知（成功才通知语义）。 */
    fun updateScheduleDateRules(rules: List<ScheduleDateRule>) {
        store.saveScheduleDateRules(rules)
        loadedScheduleDateRules = rules
        notifyStateChanged()
    }

    override val semesterWeekCount: Int
        get() = loadedSettings.semesterWeekCount

    override fun getCourseById(id: String): Course? =
        activeProfile.courses.firstOrNull { it.id == id }

    override fun dateForCourseOccurrence(course: Course, week: Int): LocalDateTime? =
        TimetableCourseService.courseOccurrenceDate(loadedSettings.semesterStartDate, course, week)

    override fun validateCourseTimeSchemeOverride(
        timeSchemeId: String?,
        startSection: Int,
        endSection: Int,
    ): String? = TimeSchemeLogic.validateCourseTimeSchemeOverride(
        schemes = loadedTimeSchemes,
        settings = loadedSettings,
        timeSchemeId = timeSchemeId,
        startSection = startSection,
        endSection = endSection,
    )

    override fun syncCourseWithEffectiveTimeScheme(course: Course): Course =
        TimeSchemeLogic.syncCourseWithEffectiveTimeScheme(
            course = course,
            schemes = loadedTimeSchemes,
            settings = loadedSettings,
        )

    override fun isLiveTestingFixture(course: Course): Boolean =
        isLiveTestingFixtureCourseId(course.id)

    /**
     * 记教师历史（幂等）：Dart `_recordTeacherImpl` 原样——空串跳过、已存在跳过、
     * 新增后**排序**再落盘（排序是为了下拉列表稳定，不是审美）。
     */
    override fun recordTeacher(teacher: String) {
        recordHistoryValue(teacher, store.loadTeacherRecords()) { store.saveTeacherRecords(it) }
    }

    override fun recordLocation(location: String) {
        recordHistoryValue(location, store.loadLocationRecords()) { store.saveLocationRecords(it) }
    }

    private fun recordHistoryValue(
        raw: String,
        existing: List<String>,
        save: (List<String>) -> Unit,
    ) {
        val value = raw.trim()
        if (value.isEmpty()) return
        if (existing.contains(value)) return
        val next = (existing + value).sorted()
        save(next)
    }

    /** 把当前设置与活动课表落盘；失败时抛错，由 [TimetableCourseService] 回滚。 */
    override fun persistActiveProfileState() {
        val week = resolvedCurrentWeek()
        val profile = activeProfile.copy(
            courses = activeProfile.courses,
            settings = loadedSettings,
            currentWeek = week.toLong(),
            lastUsedAt = LocalDateTime.now(),
        )
        val nextProfiles = upsertProfile(profile)
        // 先写档案本体：失败直接抛，调用方（服务）负责回滚内存快照。
        store.saveProfiles(nextProfiles)
        store.saveActiveProfileId(profile.id)
        store.saveSettings(loadedSettings)
        store.saveCurrentWeek(week)
        loadedProfiles = nextProfiles
        loadedActiveProfileId = profile.id
        loadedCurrentWeek = week
    }

    override fun clearCurrentLiveCourseId() {
        currentLiveCourseId = null
    }

    /** 埋点：Phase 4 才接分析服务，本阶段空实现（不假装记了）。 */
    override fun logEvent(name: String, parameters: Map<String, Any>) {
        // no-op：Compose 侧还没有分析通道。
    }

    /** 考试提醒通知：Phase 4 原生能力，本阶段空实现。 */
    override fun syncExamReminders() {
        // no-op：通知权限与调度属 Phase 4。
    }

    /** 实时活动（超级岛）：Phase 4 原生能力，本阶段空实现。 */
    override fun updateLiveActivity() {
        // no-op：实时活动属 Phase 4。
    }

    override fun notifyStateChanged() {
        if (listeners.isEmpty()) return
        val current = snapshot
        listeners.forEach { it(current) }
    }

    override fun initialize() {
        reload()
    }

    // ---------- 内部 ----------

    /**
     * 当前激活档案。盘上一份都没有时给一份内存默认档案（id 固定），
     * 这样「首启 → 直接加课」这条路径不必先造档案。
     *
     * 注意这里**不能**回头调 [resolvedCurrentWeek]（它会读 [activeProfile] 兜底），
     * 否则两者互递归到栈溢出。
     */
    private val activeProfile: TimetableProfile
        get() = loadedProfiles.firstOrNull { it.id == loadedActiveProfileId }
            ?: loadedProfiles.firstOrNull()
            ?: defaultProfile()

    private fun defaultProfile(): TimetableProfile = TimetableProfile(
        id = DEFAULT_PROFILE_ID,
        name = DEFAULT_PROFILE_NAME,
        currentWeek = clampCurrentWeekToSettings(
            (loadedCurrentWeek ?: 1).toLong(),
            loadedSettings,
        ),
        createdAt = LocalDateTime.now(),
        lastUsedAt = LocalDateTime.now(),
    )

    private fun updateActiveProfile(transform: (TimetableProfile) -> TimetableProfile) {
        val next = transform(activeProfile)
        loadedProfiles = upsertProfile(next)
        loadedActiveProfileId = next.id
    }

    private fun upsertProfile(profile: TimetableProfile): List<TimetableProfile> {
        val index = loadedProfiles.indexOfFirst { it.id == profile.id }
        if (index < 0) return loadedProfiles + profile
        val mutable = loadedProfiles.toMutableList()
        mutable[index] = profile
        return mutable
    }

    /** 当前周次：顶层 `current_week` 优先，缺失回落活动档案自带的那份，再按学期钳制。 */
    private fun resolvedCurrentWeek(): Int {
        val raw = loadedCurrentWeek ?: activeProfile.currentWeek.toInt()
        return clampCurrentWeekToSettings(raw.toLong(), loadedSettings).toInt()
    }

    companion object {
        /** 首启无档案时的内存默认档案 id（落盘后即是真档案）。 */
        const val DEFAULT_PROFILE_ID = "default"
        const val DEFAULT_PROFILE_NAME = "默认课表"
    }
}
