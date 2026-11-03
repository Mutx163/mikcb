package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.LocationTimeGroup
import com.mutx163.qingyu.core.ScheduleDateRule
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.ServiceMessage
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimeSchemeLogic
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.core.clampCurrentWeekToSettings
import com.mutx163.qingyu.core.validateSectionTimes
import com.mutx163.qingyu.course.TimetableCoursePort
import com.mutx163.qingyu.course.TimetableCourseService
import com.mutx163.qingyu.sync.isLiveTestingFixtureCourseId
import java.time.LocalDateTime
import java.util.UUID
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
    /** 地点作息分组（顶层 key `location_time_groups`，不属于单个档案）。 */
    val locationTimeGroups: List<LocationTimeGroup> = emptyList(),
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
 * - 并发写**串行化但不做事务**：局域网编辑服务（`LanEditHttpServer`）每个连接一个
 *   工作线程，与 UI 主线程共用同一份内存状态；本类所有公开读写入口都挂在同一把
 *   对象锁（`@Synchronized`）上，写与写、写与读快照都不再交错。锁只保证「单个
 *   入口原子」，多个入口组成的多步序列仍不是事务（那属于调用方，如 `LanTransferApplier`
 *   的快照补偿）。Kotlin 的 `@Synchronized` 可重入：服务层在入口锁内再调 port 读写
 *   不会自锁。
 * - **监听者回调绝不持锁执行**：写入口锁内只改内存 + 落盘 + 置「待通知」标志
 *   （[pendingNotify]），公共入口释放锁后统一回调（先锁外原子抓 snapshot，再逐个回调）。
 *   这样回调里再做仓储操作、同步等主线程、拿别的锁，都不会与本类对象锁成环
 *   （否则 worker → 主线程 → 仓储锁就是现成的环形等待）。锁外显式调
 *   [notifyStateChanged]（`ScheduleItemService` / 考试服务 / 日期规则自动套用 /
 *   情侣同步）维持「立即通知」语义不变。这些契约由 `TimetableRepositoryTest`
 *   的持锁断言与并发测试钉住。
 */
class TimetableRepository(private val store: TimetableStore) : TimetableCoursePort, TimetableScheduleItemPort {

    private var loadedProfiles: List<TimetableProfile> = emptyList()
    private var loadedActiveProfileId: String? = null
    private var loadedSettings: TimetableSettings = TimetableSettings.defaults()
    private var loadedCurrentWeek: Int? = null
    private var loadedTimeSchemes: List<TimeScheme> = emptyList()
    private var loadedScheduleDateRules: List<ScheduleDateRule> = emptyList()
    private var loadedLocationTimeGroups: List<LocationTimeGroup> = emptyList()

    /** Dart 侧是 provider 的一个内存字段（`_currentLiveCourseId`），不落盘。 */
    private var currentLiveCourseId: String? = null

    /**
     * 「有变更待通知」标志：锁内置位，公共入口释放锁后由 [drainPendingNotify] 排空。
     * 由本类对象锁保护——这是「监听者回调绝不持锁执行」的机制（见类注释）。
     */
    private var pendingNotify = false

    private val listeners = CopyOnWriteArrayList<(TimetableSnapshot) -> Unit>()

    init {
        reload()
    }

    // ---------- 装载 ----------

    /** 从盘上重新装载（[initialize] 与构造共用）。 */
    @Synchronized
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
        loadedLocationTimeGroups = store.loadLocationTimeGroups()
    }

    /** 盘上档案的解析结果（含「只是条目级损坏」信号，供宿主决定是否提示用户）。 */
    fun loadProfilesResult(): TimetableStore.ProfilesLoadResult = store.loadProfiles()

    /**
     * 读盘上原始串（只读；语义见 [TimetableStore.rawJson]）。
     *
     * 只给「删档案后回收独占用图」的引用扫描用——本层不认识壁纸键，也不做可用性判断。
     */
    fun rawStoredJson(key: String): String? = store.rawJson(key)

    // ---------- 对外只读视图 ----------

    val snapshot: TimetableSnapshot
        @Synchronized get() = TimetableSnapshot(
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
            locationTimeGroups = loadedLocationTimeGroups,
        )

    /** 订阅变更；返回的 [AutoCloseable] 用于退订。**订阅时不立刻回调**（见类注释）。 */
    fun observe(listener: (TimetableSnapshot) -> Unit): AutoCloseable {
        listeners.add(listener)
        return AutoCloseable { listeners.remove(listener) }
    }

    // ---------- 对外写入口 ----------
    //
    // 公共入口统一形态：**非 synchronized 包装 + `@Synchronized private …Locked` 实现**。
    // 包装在锁实现返回（对象锁已释放）后调 [drainPendingNotify]，保证监听者回调
    // 绝不在持锁状态下执行（见类注释）。锁实现内部一律用 `pendingNotify = true`
    // 代替直接回调；`@Synchronized` 可重入，锁实现之间的互相调用不会自锁。

    fun addCourse(course: Course) {
        addCourseLocked(course)
        drainPendingNotify()
    }

    @Synchronized
    private fun addCourseLocked(course: Course) {
        TimetableCourseService.add(this, course)
    }

    fun updateCourse(course: Course, previousSharedName: String? = null) {
        updateCourseLocked(course, previousSharedName)
        drainPendingNotify()
    }

    @Synchronized
    private fun updateCourseLocked(course: Course, previousSharedName: String? = null) {
        TimetableCourseService.update(this, course, previousSharedName)
    }

    fun deleteCourse(courseId: String) {
        deleteCourseLocked(courseId)
        drainPendingNotify()
    }

    @Synchronized
    private fun deleteCourseLocked(courseId: String) {
        TimetableCourseService.delete(this, courseId)
    }

    /**
     * 切换激活档案。
     * @return true 表示真的切了（目标存在且与当前不同）；否则 false 且**不通知**。
     */
    fun setActiveProfile(profileId: String): Boolean {
        val changed = setActiveProfileLocked(profileId)
        drainPendingNotify()
        return changed
    }

    @Synchronized
    private fun setActiveProfileLocked(profileId: String): Boolean {
        if (loadedProfiles.none { it.id == profileId }) return false
        if (profileId == activeProfile.id) return false
        loadedActiveProfileId = profileId
        store.saveActiveProfileId(profileId)
        pendingNotify = true
        return true
    }

    /** 更新设置：落盘（合并写）后通知。 */
    fun updateSettings(settings: TimetableSettings) {
        updateSettingsLocked(settings)
        drainPendingNotify()
    }

    @Synchronized
    private fun updateSettingsLocked(settings: TimetableSettings) {
        loadedSettings = settings
        store.saveSettings(settings)
        pendingNotify = true
    }

    // ---------- 整份原始 settings 的带锁通道 ----------

    /**
     * **带锁读盘上整份 settings**（原样键集，含本层不认识的 Dart 侧 250+ 键）。
     *
     * 给「必须按整份 JSON 处理、又不该绕过仓储直接摸 `KeyValueStore`」的调用方
     * （当前是局域网导入）。返回值是副本，调用方随便改不会影响内存或盘上状态。
     *
     * 注意：盘上可能保留合并写产生的显式 `null`（表示「该键已删除」）。本方法原样返回，
     * 语义判断留给调用方，与 [TimetableStore.loadSettingsJson] 一致。
     */
    fun readRawSettings(): Map<String, Any?> = readRawSettingsLocked()

    @Synchronized
    private fun readRawSettingsLocked(): Map<String, Any?> = LinkedHashMap(store.loadSettingsJson())

    /**
     * **带锁按 patch 合并写整份 settings**：只覆盖 [patch] 里出现的键，值 `null` 表示删键。
     *
     * 口径与 [TimetableStore.saveSettingsPatch] / [TimetableStore.saveSettingsPatchToActiveProfile]
     * 完全相同（后者同步活动档案内嵌的 `settings`，桌面小组件读的是那一份）；
     * 区别只在于**整段读-合并-写发生在同一把锁内**，与 UI 设置编辑并发时不会丢更新。
     *
     * 成功后从盘上重载一次内存快照并通知监听者（patch 可能改到核心键，
     * 如 `semesterWeekCount` / `sections`，不能只写盘不改内存）。
     *
     * @return true = 已落盘且快照已刷新；false = 底层抛错（内存不动）。
     */
    fun writeRawSettingsPatch(patch: Map<String, Any?>): Boolean {
        if (patch.isEmpty()) return true
        val ok = writeRawSettingsPatchLocked(patch)
        if (ok) drainPendingNotify()
        return ok
    }

    @Synchronized
    private fun writeRawSettingsPatchLocked(patch: Map<String, Any?>): Boolean =
        try {
            store.saveSettingsPatch(patch)
            store.saveSettingsPatchToActiveProfile(patch)
            reload()
            pendingNotify = true
            true
        } catch (_: Exception) {
            // 顶层写与档案内嵌写之间失败时，盘上可能只落了前一半；
            // 本层不实现跨 key 事务（见 replaceActiveProfileContent 的同类说明），内存保持旧值。
            false
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
        replaceActiveProfileContentLocked(courses, tasks, exams)
        drainPendingNotify()
        // 整块替换绕过了各写服务的提醒漏斗：考试 / 课程刚被换掉，闹钟必须跟着重排
        //（与 Dart 恢复备份后 reconcile 同一时机；无宿主订阅时是 no-op）。
        syncExamReminders()
    }

    @Synchronized
    private fun replaceActiveProfileContentLocked(
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
        pendingNotify = true
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
        replaceAllProfilesLocked(profiles, activeProfileId)
        drainPendingNotify()
    }

    @Synchronized
    private fun replaceAllProfilesLocked(profiles: List<TimetableProfile>, activeProfileId: String?) {
        // 先落盘：失败则内存与监听者都不动。
        store.saveProfiles(profiles)
        store.saveActiveProfileId(activeProfileId)
        loadedProfiles = profiles
        loadedActiveProfileId = activeProfileId
        pendingNotify = true
    }

    /**
     * 日期规则自动套用作息专用：**一次落盘全部档案 + 全局设置**，成功后才改内存并通知。
     *
     * 为什么不分别调 [replaceAllProfiles] 与 [updateSettings]：两者各自通知一次，
     * 套用会先让界面看到「档案换了、全局设置还是旧的」的中间态；而且 [updateSettings]
     * 是**先改内存再落盘**，落盘失败会留下内存新、盘上旧。
     *
     * **失败语义**：先落三次盘、全部成功后才改内存；任一次抛错时内存与监听者都不动。
     * 盘上可能已写成一半（与 [replaceAllProfiles] 同口径，本层不做跨 key 事务）。
     */
    fun replaceAllProfilesAndSettings(
        profiles: List<TimetableProfile>,
        activeProfileId: String?,
        settings: TimetableSettings,
    ) {
        replaceAllProfilesAndSettingsLocked(profiles, activeProfileId, settings)
        drainPendingNotify()
        // 日期规则自动套用会整块换档案（含日程与考试），绕过了写服务的提醒漏斗，
        // 这里补一次重排（`ScheduleReminderScheduler.reconcile` KDoc 列明的
        // 「恢复备份后」时机；无宿主订阅时是 no-op）。
        syncExamReminders()
    }

    @Synchronized
    private fun replaceAllProfilesAndSettingsLocked(
        profiles: List<TimetableProfile>,
        activeProfileId: String?,
        settings: TimetableSettings,
    ) {
        store.saveSettings(settings)
        store.saveProfiles(profiles)
        store.saveActiveProfileId(activeProfileId)
        loadedSettings = settings
        loadedProfiles = profiles
        loadedActiveProfileId = activeProfileId
        pendingNotify = true
    }

    /**
     * **把一份云端 / 本地备份快照整份写回**（云同步「恢复」的落点）。**破坏性操作。**
     *
     * ## 为什么要这一个入口（而不是让调用方逐个调 setter）
     *
     * 一次恢复要动 6 个 key（档案 / 激活 id / 设置 / 当前周 / 作息表 / 日期规则 / 地点分组）。
     * 逐个调现有写入口会 **6 次落盘 + 6 次通知**，界面会闪 6 下中间态；而且任何一步失败，
     * 用户看到的就是「一半新一半旧」。本方法把顺序固定下来、只在最后通知一次。
     *
     * ## 口径（对齐 Dart `_applySnapshotData` 的课表族部分）
     *
     * - 全局设置与当前周**取自快照里的激活档案**：Dart 快照的顶层没有这两项，它们本就
     *   内嵌在每个档案里（`TimetableProfile.settings` / `.currentWeek`）。
     * - `activeProfileId` 悬空时回落第一份档案（与 [snapshot] 的读侧宽松口径一致）；
     *   [profiles] 为空直接拒绝，**不写空包**（那等于把用户数据清空）。
     * - 先全部落盘、成功后才改内存并 [notifyStateChanged] 一次；落盘中途抛错时内存与监听者
     *   都不动（下次 `reload()` 会读到已落的那些 key —— 与 [replaceAllProfiles] 相同，
     *   本层没有跨 key 事务）。
     *
     * **调用方义务**：备快照的信封 / 校验和 / 档案列表是否可信必须由调用方先校验完。
     */
    fun restoreFromCloudSnapshot(
        profiles: List<TimetableProfile>,
        activeProfileId: String?,
        timeSchemes: List<TimeScheme>,
        scheduleDateRules: List<ScheduleDateRule>,
        locationTimeGroups: List<LocationTimeGroup>,
        /** 快照里携带的全局设置（core 四键）；null = 取激活档案内嵌的那份。 */
        settings: TimetableSettings? = null,
    ) {
        restoreFromCloudSnapshotLocked(
            profiles,
            activeProfileId,
            timeSchemes,
            scheduleDateRules,
            locationTimeGroups,
            settings,
        )
        drainPendingNotify()
        // 云恢复整块替换了课 / 作业 / 考试 / 日程，绕过了写服务的提醒漏斗；
        // Dart 侧恢复后也会整表重排提醒（`ScheduleReminderScheduler.reconcile` KDoc），
        // 这里对齐同一时机。无宿主订阅时是 no-op。
        syncExamReminders()
    }

    @Synchronized
    private fun restoreFromCloudSnapshotLocked(
        profiles: List<TimetableProfile>,
        activeProfileId: String?,
        timeSchemes: List<TimeScheme>,
        scheduleDateRules: List<ScheduleDateRule>,
        locationTimeGroups: List<LocationTimeGroup>,
        settings: TimetableSettings?,
    ) {
        require(profiles.isNotEmpty()) { "restore snapshot must contain at least one profile" }
        val resolvedActiveId = activeProfileId
            ?.takeIf { id -> profiles.any { it.id == id } }
            ?: profiles.first().id
        val active = profiles.first { it.id == resolvedActiveId }
        val restoredSettings = settings ?: active.settings
        val restoredWeek = clampCurrentWeekToSettings(active.currentWeek, restoredSettings).toInt()

        // 先落盘：全部成功后才改内存，失败时界面保持旧状态。
        store.saveProfiles(profiles)
        store.saveActiveProfileId(resolvedActiveId)
        store.saveSettings(restoredSettings)
        store.saveCurrentWeek(restoredWeek)
        store.saveTimeSchemes(timeSchemes)
        store.saveScheduleDateRules(scheduleDateRules)
        store.saveLocationTimeGroups(locationTimeGroups)

        loadedProfiles = profiles
        loadedActiveProfileId = resolvedActiveId
        loadedSettings = restoredSettings
        loadedCurrentWeek = restoredWeek
        loadedTimeSchemes = timeSchemes
        loadedScheduleDateRules = scheduleDateRules
        loadedLocationTimeGroups = locationTimeGroups
        currentLiveCourseId = null
        pendingNotify = true
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
        setCurrentWeekLocked(week)
        drainPendingNotify()
    }

    @Synchronized
    private fun setCurrentWeekLocked(week: Int) {
        val clamped = clampCurrentWeekToSettings(week.toLong(), loadedSettings).toInt()
        loadedCurrentWeek = clamped
        currentLiveCourseId = null
        persistActiveProfileState()
        pendingNotify = true
    }

    // ---------- TimetableCoursePort ----------

    override var courses: List<Course>
        @Synchronized get() = activeProfile.courses
        @Synchronized set(value) {
            updateActiveProfile { it.copy(courses = value) }
        }

    override var tasks: List<CourseTask>
        @Synchronized get() = activeProfile.tasks
        @Synchronized set(value) {
            updateActiveProfile { it.copy(tasks = value) }
        }

    override var exams: List<Exam>
        @Synchronized get() = activeProfile.exams
        @Synchronized set(value) {
            updateActiveProfile { it.copy(exams = value) }
        }

    override var profiles: List<TimetableProfile>
        @Synchronized get() = loadedProfiles
        @Synchronized set(value) {
            loadedProfiles = value
        }

    // ---------- TimetableScheduleItemPort ----------

    /**
     * 活动档案的日程列表。setter 只改内存（与 courses/tasks/exams 同口径），
     * 落盘由 [ScheduleItemService] 显式调用 [persistActiveProfileState] 触发。
     */
    override var scheduleItems: List<ScheduleItem>
        @Synchronized get() = activeProfile.scheduleItems
        @Synchronized set(value) {
            updateActiveProfile { it.copy(scheduleItems = value) }
        }

    // ---------- 作息日期规则 ----------

    /** 整份替换作息日期规则：落盘成功后才改内存并通知（成功才通知语义）。 */
    fun updateScheduleDateRules(rules: List<ScheduleDateRule>) {
        updateScheduleDateRulesLocked(rules)
        drainPendingNotify()
    }

    @Synchronized
    private fun updateScheduleDateRulesLocked(rules: List<ScheduleDateRule>) {
        store.saveScheduleDateRules(rules)
        loadedScheduleDateRules = rules
        pendingNotify = true
    }

    // ---------- 地点作息分组 ----------

    /**
     * 整份替换地点作息分组（顶层 key `location_time_groups`，与 Dart
     * `storage_service.dart` 同名，**不属于单个档案**）。
     *
     * 与 [updateScheduleDateRules] 同语义：**先落盘、成功才改内存并通知**；落盘抛错时内存与
     * 监听者都不动 ⇒ 界面不会出现「显示已保存、盘上还是旧数据」的假成功
     * （`d3.locationMatch` 的宿主正是靠这个契约决定要不要回显）。
     *
     * 出处：`lib/services/timetable_location_rule_service.dart:174-260` 的
     * `createGroup` / `updateGroup` / `deleteGroup` / `setGroupEnabled` 四个入口最终都落到
     * 「整份数组写回 `location_time_groups`」这一笔上；批次 F10 只搬这一笔，
     * 分组增删改的判据在 `pages/time_scheme/LocationTimeGroupController`（纯 Kotlin、JVM 可测）。
     */
    fun updateLocationTimeGroups(groups: List<LocationTimeGroup>) {
        updateLocationTimeGroupsLocked(groups)
        drainPendingNotify()
    }

    @Synchronized
    private fun updateLocationTimeGroupsLocked(groups: List<LocationTimeGroup>) {
        store.saveLocationTimeGroups(groups)
        loadedLocationTimeGroups = groups
        pendingNotify = true
    }

    // ---------- 时间模板（作息）写入口 ----------

    /**
     * 时间模板族的六个写入口，语义逐条对 Dart `TimetableTimeSchemeService`
     * （`lib/services/timetable_time_scheme_service.dart`）。
     *
     * ## 回滚语义为什么不在这里手写
     *
     * Dart 侧是「先改内存、后写盘」，所以每个入口都要手写快照/补偿。本层的做法是
     * **先落盘、成功才改内存**，落盘抛错时内存与监听者都不动 —— 回滚语义天然成立。
     * 唯一需要显式补偿的是 [updateTimeScheme]：它要写两个 key（作息表 + 档案），
     * 第二笔失败时第一笔已落盘，必须把旧作息表写回去，否则「盘上新节次、内存旧节次」，
     * 冷启动后用户被告知「没改成」的节次会自己生效（Dart 同处注释记的正是这个事故）。
     *
     * ## 成功才通知
     *
     * 每个入口都在最后一步才 [notifyStateChanged]；校验失败、被引用拒绝、找不到目标
     * 都**不通知**，界面不会闪一下再退回。
     */

    /**
     * 新建一套时间模板。
     *
     * 节次缺省取「当前生效模板的节次」，再退到全局设置的节次（Dart `create` 同口径：
     * `sections ?? activeTimeScheme?.sections ?? settings.sections`）。
     * [applyToActiveProfile] 为真时顺手把它套到当前课表（等于随后调 [applyTimeScheme]）。
     */
    fun createTimeScheme(
        name: String,
        sections: List<SectionTime>? = null,
        applyToActiveProfile: Boolean = false,
    ): TimeScheme {
        val scheme = createTimeSchemeLocked(name, sections, applyToActiveProfile)
        drainPendingNotify()
        return scheme
    }

    @Synchronized
    private fun createTimeSchemeLocked(
        name: String,
        sections: List<SectionTime>?,
        applyToActiveProfile: Boolean,
    ): TimeScheme {
        val now = LocalDateTime.now()
        val scheme = TimeScheme(
            id = UUID.randomUUID().toString(),
            name = name.trim(),
            sections = (sections ?: activeTimeScheme()?.sections ?: loadedSettings.sections).toList(),
            createdAt = now,
            updatedAt = now,
        )
        val next = loadedTimeSchemes + scheme
        store.saveTimeSchemes(next)
        loadedTimeSchemes = next
        if (applyToActiveProfile) {
            // 锁内互调：走 Locked 实现，不经过公共包装（那会在持锁状态下排空通知）。
            applyTimeSchemeLocked(scheme.id)
        } else {
            pendingNotify = true
        }
        return scheme
    }

    /** 改名；找不到返回 null（不落盘、不通知）。 */
    fun renameTimeScheme(schemeId: String, name: String): TimeScheme? {
        val updated = renameTimeSchemeLocked(schemeId, name)
        drainPendingNotify()
        return updated
    }

    @Synchronized
    private fun renameTimeSchemeLocked(schemeId: String, name: String): TimeScheme? {
        val index = loadedTimeSchemes.indexOfFirst { it.id == schemeId }
        if (index < 0) return null
        val updated = loadedTimeSchemes[index].copy(name = name.trim(), updatedAt = LocalDateTime.now())
        val next = loadedTimeSchemes.toMutableList().also { it[index] = updated }
        store.saveTimeSchemes(next)
        loadedTimeSchemes = next
        pendingNotify = true
        return updated
    }

    /**
     * 复制一套模板；源不存在返回 null。
     *
     * 默认名是 Dart 的硬编码字面量 `'${source.name} 副本'`（
     * `timetable_time_scheme_service.dart:224`）。**这不是新造的文案**：它与 Dart
     * 逐字一致，宿主通常直接传入列表页算好的 `copyName`（那条走 ARB 同形键）。
     */
    fun duplicateTimeScheme(schemeId: String, name: String? = null): TimeScheme? {
        val duplicated = duplicateTimeSchemeLocked(schemeId, name)
        drainPendingNotify()
        return duplicated
    }

    @Synchronized
    private fun duplicateTimeSchemeLocked(schemeId: String, name: String?): TimeScheme? {
        val source = loadedTimeSchemes.firstOrNull { it.id == schemeId } ?: return null
        val now = LocalDateTime.now()
        val duplicated = source.copy(
            id = UUID.randomUUID().toString(),
            name = (name ?: "${source.name} 副本").trim(),
            sections = source.sections.toList(),
            createdAt = now,
            updatedAt = now,
        )
        val next = loadedTimeSchemes + duplicated
        store.saveTimeSchemes(next)
        loadedTimeSchemes = next
        pendingNotify = true
        return duplicated
    }

    /**
     * 改一套模板的名称与节次表；成功返回 null，失败返回 service message 码。
     *
     * 两道校验顺序与 Dart 一致：
     * 1. [validateSectionTimes]：节次表本身是否合法（含跨天、倒序、格式）；
     * 2. 节次数不能小于**已用最大节次**：课程按节次下标取钟点，收窄会让课程无处取时间。
     *    能定位到具体是哪门课时给带明细的那条（`section_count_below_usage_detail`）。
     */
    fun updateTimeScheme(schemeId: String, name: String, sections: List<SectionTime>): String? {
        val result = updateTimeSchemeLocked(schemeId, name, sections)
        drainPendingNotify()
        return result
    }

    @Synchronized
    private fun updateTimeSchemeLocked(schemeId: String, name: String, sections: List<SectionTime>): String? {
        validateSectionTimes(sections)?.let { return it }

        val requiredMaxSection = TimeSchemeLogic.maxUsedSection(
            profiles = loadedProfiles,
            schemeId = schemeId,
            profilesOverride = null,
            schemes = loadedTimeSchemes,
            locationTimeGroups = loadedLocationTimeGroups,
        )
        val index = loadedTimeSchemes.indexOfFirst { it.id == schemeId }
        if (index >= 0 && requiredMaxSection > 0 && sections.size < requiredMaxSection) {
            val usage = TimeSchemeLogic.maxSectionUsage(
                profiles = loadedProfiles,
                schemeId = schemeId,
                profilesOverride = null,
                schemes = loadedTimeSchemes,
                locationTimeGroups = loadedLocationTimeGroups,
            )
            if (usage != null) {
                return ServiceMessage.encode(
                    "section_count_below_usage_detail",
                    linkedMapOf(
                        "requiredMaxSection" to requiredMaxSection,
                        "profileName" to usage.profileName,
                        "courseName" to usage.course.name,
                        "dayOfWeek" to usage.course.dayOfWeek,
                        "startSection" to usage.course.startSection,
                        "endSection" to usage.course.endSection,
                        "usageType" to if (usage.usesOverride) "usage_type_override" else "usage_type_profile",
                    ),
                )
            }
            return ServiceMessage.encode(
                "section_count_below_usage",
                linkedMapOf("requiredMaxSection" to requiredMaxSection),
            )
        }
        if (index < 0) return "time_scheme_not_found"

        val updated = loadedTimeSchemes[index].copy(
            name = name.trim(),
            sections = sections.toList(),
            updatedAt = LocalDateTime.now(),
        )
        val nextSchemes = loadedTimeSchemes.toMutableList().also { it[index] = updated }

        // 档案里那份设置只是镜像：以该模板为主模板的档要把节次镜像同步过去，
        // 并按新节次重排课程钟点（Dart update 里的 nextProfiles 循环）。
        val nextProfiles = loadedProfiles.map { profile ->
            val normalized = if (profile.settings.activeTimeSchemeId == schemeId) {
                profile.settings.copy(activeTimeSchemeId = schemeId, sections = updated.sections)
            } else {
                profile.settings
            }
            profile.copy(
                courses = TimeSchemeLogic.syncCoursesWithEffectiveTimeSchemes(
                    source = profile.courses,
                    schemes = nextSchemes,
                    settings = normalized,
                    locationTimeGroups = loadedLocationTimeGroups,
                    scheduleDateRules = loadedScheduleDateRules,
                ),
                settings = normalized,
            )
        }
        val nextSettings = if (loadedSettings.activeTimeSchemeId == schemeId) {
            loadedSettings.copy(activeTimeSchemeId = schemeId, sections = updated.sections)
        } else {
            loadedSettings
        }

        // 第一笔：作息表。
        store.saveTimeSchemes(nextSchemes)
        try {
            // 第二笔：档案（含各档镜像设置）+ 全局设置。
            store.saveProfiles(nextProfiles)
            if (nextSettings != loadedSettings) store.saveSettings(nextSettings)
        } catch (error: Throwable) {
            // 补偿：第一笔已经成功落盘，把旧作息表写回去。补偿失败不遮住原始错误。
            runCatching { store.saveTimeSchemes(loadedTimeSchemes) }
            throw error
        }

        loadedTimeSchemes = nextSchemes
        loadedProfiles = nextProfiles
        loadedSettings = nextSettings
        currentLiveCourseId = null
        pendingNotify = true
        return null
    }

    /**
     * 把某套模板套到当前课表；成功返回 null，失败返回 service message 码。
     *
     * 先查「现有课程最靠后的那一节」：课程保留自己的节次下标，目标模板必须覆盖它们，
     * 否则那些课会取不到钟点（`section_count_below_usage`）。
     */
    fun applyTimeScheme(schemeId: String): String? {
        val result = applyTimeSchemeLocked(schemeId)
        drainPendingNotify()
        return result
    }

    @Synchronized
    private fun applyTimeSchemeLocked(schemeId: String): String? {
        val scheme = loadedTimeSchemes.firstOrNull { it.id == schemeId } ?: return "time_scheme_not_found"
        val requiredMaxSection = activeProfile.courses.maxOfOrNull { it.endSection } ?: 0
        if (requiredMaxSection > scheme.sections.size) {
            return ServiceMessage.encode(
                "section_count_below_usage",
                linkedMapOf("requiredMaxSection" to requiredMaxSection),
            )
        }
        val nextSettings = loadedSettings.copy(
            activeTimeSchemeId = scheme.id,
            sections = scheme.sections,
        )
        val nextCourses = TimeSchemeLogic.syncCoursesWithEffectiveTimeSchemes(
            source = activeProfile.courses,
            schemes = loadedTimeSchemes,
            settings = nextSettings,
            locationTimeGroups = loadedLocationTimeGroups,
            scheduleDateRules = loadedScheduleDateRules,
        )
        persistActiveProfileContent(courses = nextCourses, settings = nextSettings)
        return null
    }

    /**
     * 删一套模板：**被任何档案 / 课程 / 地点分组 / 日期规则引用时直接拒绝**
     * （返回 false、不落盘、不通知）；成功返回 true。
     *
     * 判据走 [TimeSchemeLogic.isSchemeInUse] 这唯一一份口径，不在本层另写一套。
     */
    fun deleteTimeScheme(schemeId: String): Boolean {
        val deleted = deleteTimeSchemeLocked(schemeId)
        drainPendingNotify()
        return deleted
    }

    @Synchronized
    private fun deleteTimeSchemeLocked(schemeId: String): Boolean {
        if (TimeSchemeLogic.isSchemeInUse(
                profiles = loadedProfiles,
                schemeId = schemeId,
                locationTimeGroups = loadedLocationTimeGroups,
                schemes = loadedTimeSchemes,
                scheduleDateRules = loadedScheduleDateRules,
            )
        ) {
            return false
        }
        val index = loadedTimeSchemes.indexOfFirst { it.id == schemeId }
        if (index < 0) return false
        val next = loadedTimeSchemes.toMutableList().also { it.removeAt(index) }
        store.saveTimeSchemes(next)
        loadedTimeSchemes = next
        pendingNotify = true
        return true
    }

    /** 当前课表正在使用的那套模板（[TimetableSettings.activeTimeSchemeId] 指向的）。 */
    private fun activeTimeScheme(): TimeScheme? =
        loadedTimeSchemes.firstOrNull { it.id == loadedSettings.activeTimeSchemeId }

    /**
     * 落盘「活动档案的内容 + 全局设置」：**先写、成功才改内存并通知**。
     *
     * 与 [persistActiveProfileState] 的区别只在于「课与设置由调用方给」——
     * 那个方法是从当前内存状态推出来的，套用模板这条路径必须用**算好的新值**。
     */
    private fun persistActiveProfileContent(courses: List<Course>, settings: TimetableSettings) {
        val week = resolvedCurrentWeek()
        val profile = activeProfile.copy(
            courses = courses,
            settings = settings,
            currentWeek = week.toLong(),
            lastUsedAt = LocalDateTime.now(),
        )
        val nextProfiles = upsertProfile(profile)
        store.saveProfiles(nextProfiles)
        store.saveActiveProfileId(profile.id)
        store.saveSettings(settings)
        store.saveCurrentWeek(week)
        loadedProfiles = nextProfiles
        loadedActiveProfileId = profile.id
        loadedSettings = settings
        loadedCurrentWeek = week
        currentLiveCourseId = null
        pendingNotify = true
    }

    override val semesterWeekCount: Int
        @Synchronized get() = loadedSettings.semesterWeekCount

    @Synchronized
    override fun getCourseById(id: String): Course? =
        activeProfile.courses.firstOrNull { it.id == id }

    @Synchronized
    override fun dateForCourseOccurrence(course: Course, week: Int): LocalDateTime? =
        TimetableCourseService.courseOccurrenceDate(loadedSettings.semesterStartDate, course, week)

    @Synchronized
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

    @Synchronized
    override fun syncCourseWithEffectiveTimeScheme(course: Course): Course =
        TimeSchemeLogic.syncCourseWithEffectiveTimeScheme(
            course = course,
            schemes = loadedTimeSchemes,
            settings = loadedSettings,
        )

    @Synchronized
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
    @Synchronized
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

    /**
     * 日程条目变化后的「提醒重排」钩子（纯 Kotlin 回调，不引用 Android 类型）。
     *
     * 谁调：`ScheduleItemService` 在日程增 / 改 / 删后统一调 [syncExamReminders]；
     * 谁接：壳在启动时把它设成 `ScheduleReminderScheduler.reconcile(context, snapshot.scheduleItems)`。
     *
     * 放回调而不是直接在这里调调度器：本包必须保持纯 Kotlin（所有泳道的 L0 单测共用），
     * 一旦 import Android 的 AlarmManager / Notification，轻量单测就编不过。
     */
    var onScheduleRemindersChanged: (() -> Unit)? = null

    /**
     * 考试 / 课程 / 日程变化后的「考试提醒重排」钩子（对位 [onScheduleRemindersChanged]）。
     *
     * 谁调：与 [syncExamReminders] 同一口径——考试增删改（`TimetableExamService`）、
     * 课程增删改（会连带摘考试）、日程增删改都会触发。
     * 谁接：壳在启动时把它设成 `ExamReminderCoordinator` 的整表重排。
     */
    var onExamRemindersChanged: (() -> Unit)? = null

    /** 提醒重排：没有宿主订阅时什么也不做（不是「假装排好了」）。 */
    override fun syncExamReminders() {
        onScheduleRemindersChanged?.invoke()
        onExamRemindersChanged?.invoke()
    }

    /** 实时活动（超级岛）：Phase 4 原生能力，本阶段空实现。 */
    override fun updateLiveActivity() {
        // no-op：实时活动属 Phase 4。
    }

    /**
     * 通知监听者「状态已变」。**双语义**（见类注释「监听者回调绝不持锁执行」）：
     *
     * - **持锁调用**（本类 `@Synchronized` 锁实现内部、或服务层经 port 回到持锁中的仓储）：
     *   只置「待通知」标志，由最外层公共入口释放锁后统一回调——锁内多次置位合并成一次回调。
     * - **锁外调用**（`ScheduleItemService` / 考试服务 / 日期规则自动套用 / 情侣同步等
     *   自管持久化与通知时序的调用方）：立即回调，与历史行为一致。
     */
    override fun notifyStateChanged() {
        if (Thread.holdsLock(this)) {
            pendingNotify = true
        } else {
            fireNotification()
        }
    }

    /**
     * 抓一份当前快照后逐个回调监听者。
     *
     * 调用方必须保证此刻**不持有**本类对象锁：回调里可能做任何事（再读仓储、等别的锁、
     * 同步等主线程），持锁回调正是本类要杜绝的死锁隐患。
     */
    private fun fireNotification() {
        if (listeners.isEmpty()) return
        val current = snapshot
        listeners.forEach { it(current) }
    }

    /**
     * 排空「待通知」标志：在锁内原子取走标志（并发下多次置位在此合并成一次），
     * 有变更才在**锁外**回调一次。公共写入口在自己的 `…Locked` 实现返回（锁已释放）后调用。
     */
    private fun drainPendingNotify() {
        val pending = synchronized(this) {
            val wasPending = pendingNotify
            pendingNotify = false
            wasPending
        }
        if (pending) fireNotification()
    }

    @Synchronized
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
