package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.EventPrivacy
import com.mutx163.qingyu.core.EventSink
import com.mutx163.qingyu.core.EventSinks
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.LocationTimeGroup
import com.mutx163.qingyu.core.MiniJson
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
 * - `syncExamReminders` / `updateLiveActivity` 仍是**空实现**：
 *   考试提醒通知、实时活动都属 Phase 4 原生能力对齐，本阶段只接线数据。
 *   `logEvent` 自 2026-11-03 起接通：先过 [EventPrivacy.sanitize] 隐私闸门，
 *   再进注入的 [EventSink]（默认 [EventSinks.shared] 内存环形缓冲）。
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
class TimetableRepository(
    private val store: TimetableStore,
    /**
     * 埋点出口（2026-11-03 接通；此前是空实现）。默认汇入进程级内存环形缓冲
     * [EventSinks.shared]（不联网、不落盘）。替换实现时注入即可；参数在
     * [logEvent] 入口先过 [EventPrivacy.sanitize] 隐私闸门，任何实现拿到的都是干净参数。
     */
    private val eventSink: EventSink = EventSinks.shared,
) : TimetableCoursePort, TimetableScheduleItemPort {

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
        // 旧 `courses` 通道 bootstrap：只在「盘上还没有可用档案」时组装默认档案
        // （Dart `storage_service.dart:1637-1651`）。幂等标记与「不覆盖已有档案」
        // 由 TimetableStore 保证；这里只把迁移结果并入本次装载视图。
        var profiles = profilesResult.profiles
        if (profiles.isEmpty()) {
            val bootstrap = store.bootstrapLegacyProfileIfNeeded(currentProfilesEmpty = true)
            if (bootstrap.bootstrapped) {
                bootstrap.profile?.let { profiles = listOf(it) }
            }
        }
        loadedProfiles = profiles
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
        // D1：整条档案坏掉时把清洗结果写回（坏记录已由 store.loadProfiles 先留档）。
        // 写回只切除坏记录、其余条目逐字节保留；写入在本对象的锁内完成，与 UI 写入串行。
        profilesResult.prunedRawProfiles?.let { pruned ->
            runCatching { store.saveRawProfiles(pruned) }
        }
    }

    /** 盘上档案的解析结果（含「只是条目级损坏」信号，供宿主决定是否提示用户）。 */
    fun loadProfilesResult(): TimetableStore.ProfilesLoadResult = store.loadProfiles()

    /**
     * 读盘上原始串（只读；语义见 [TimetableStore.rawJson]）。
     *
     * 只给「删档案后回收独占用图」的引用扫描用——本层不认识壁纸键，也不做可用性判断。
     */
    fun rawStoredJson(key: String): String? = store.rawJson(key)

    /**
     * 盘上每份档案**内嵌**的完整 `settings`（id → 键值表，只读）。
     *
     * 云备份写快照要用：`TimetableProfile.settings` 只带 core 4 键，整份 250+ 键
     * 设置只存在于磁盘档案里（见 [TimetableStore.embeddedSettingsById]）。
     */
    fun embeddedSettingsById(): Map<String, Map<String, Any?>> = store.embeddedSettingsById()

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
     * 「课表重新配色」批量写色：按 id 对位只改 `color` / `textColor`，其余字段一律不动。
     *
     * 为什么要单开一个入口，而不是循环调 [updateCourse]：后者每次都要整份档案落盘 +
     * 一次通知，一次重刷几十门课就是几十次写、几十帧中间态闪动。这里**一次落盘、一次通知**。
     *
     * - 没有任何颜色变化时返回 0，且**不落盘、不通知**（重复点「换一批」不会打空转）；
     * - 落盘失败时内存与监听者都不动（先写盘、成功后才改内存，抛给调用方处理）；
     * - 不碰考试提醒 / 日程：换色不影响任何提醒。
     *
     * @param recolored 目标课程列表（可来自 [Course.copy] 过的整份列表；不在当前档案里的 id 忽略）。
     * @return 真正改了颜色的课程条数。
     */
    fun applyCourseRecolors(recolored: List<Course>): Int {
        val changed = applyCourseRecolorsLocked(recolored)
        drainPendingNotify()
        return changed
    }

    @Synchronized
    private fun applyCourseRecolorsLocked(recolored: List<Course>): Int {
        val byId = recolored.associateBy { it.id }
        var changed = 0
        val nextCourses = activeProfile.courses.map { current ->
            val updated = byId[current.id]
            when {
                updated == null -> current
                updated.color == current.color && updated.textColor == current.textColor -> current
                else -> {
                    changed += 1
                    current.copy(color = updated.color, textColor = updated.textColor)
                }
            }
        }
        if (changed == 0) return 0

        val week = resolvedCurrentWeek()
        val profile = activeProfile.copy(
            courses = nextCourses,
            settings = loadedSettings,
            currentWeek = week.toLong(),
            lastUsedAt = LocalDateTime.now(),
        )
        val nextProfiles = upsertProfile(profile)
        // 先落盘：失败直接抛，内存与监听者都不动。
        store.saveProfiles(nextProfiles)
        store.saveActiveProfileId(profile.id)
        loadedProfiles = nextProfiles
        loadedActiveProfileId = profile.id
        pendingNotify = true
        return changed
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
        // 同步活动档案的内嵌投影（2026-11-05 数据安全修复）：此前只更新 loadedSettings
        // 与顶层镜像，内存档案的内嵌 core 投影留在旧值——下一次 saveProfiles（课程导入
        // replace 路径必然发生）会用内存模型的旧 core 值**覆盖刚写进磁盘内嵌的新值**
        // （磁盘证据：内嵌 20 / 顶层镜像 22 并存），成功路径上学期设置重启后回退。
        // 与 updateSettingsPatchLocked 的内存同步口径一致（mergeSettings 补投影），
        // 只补投影、不改写盘行为；放 store.saveSettings 之后 = 落盘失败时内存不动。
        val activeId = activeProfile.id
        val patch = settings.toJson()
        loadedProfiles = loadedProfiles.map { profile ->
            if (profile.id == activeId) {
                profile.copy(settings = mergeSettings(profile.settings, patch))
            } else {
                profile
            }
        }
        pendingNotify = true
    }

    /**
     * 盘上 `timetable_settings` 的**原始 JSON 文档**（只读）。
     *
     * [TimetableSettings] 只是时间/周次五键的投影，Dart 侧那份是 250+ 键。局域网
     * 导入要整份写回、差异要比原文、撤销要能判断「导入后用户改过没有」，都需要它。
     */
    @Synchronized
    fun settingsJson(): Map<String, Any?> = store.loadSettingsJson()

    /**
     * 盘上**激活档案内嵌** `settings` 的原始 JSON；盘上还没有档案 → null。
     *
     * 桌面小组件读的是档案里那份（`TimetableStore.saveSettingsPatchToActiveProfile`
     * 的类注释），撤销与失败补偿要靠它把镜像也还原。
     */
    @Synchronized
    fun activeProfileSettingsJson(): Map<String, Any?>? = activeProfileSettingsJsonLocked()

    /**
     * 设置的**合并写**（局域网导入的落点）：只覆盖 [patch] 里出现的键，盘上其余
     * （Dart 侧 250+ 个）原样保留；同一份补丁同时镜像进活动档案内嵌的 `settings`
     * ——Dart `updateSettings` 走 `_persistActiveProfileState`，档案那份也会被写，
     * 只写顶层等于「设置页改了、桌面卡片纹丝不动」。
     *
     * **失败语义**：两笔写（顶层 + 档案）。第二笔失败时把顶层写回旧值再上抛；
     * 内存只在两笔都成功后才更新。补丁里值为 null = 删除该键（合并写的约定）。
     */
    fun updateSettingsPatch(patch: Map<String, Any?>) {
        updateSettingsPatchLocked(patch)
        drainPendingNotify()
    }

    @Synchronized
    private fun updateSettingsPatchLocked(patch: Map<String, Any?>) {
        if (patch.isEmpty()) return
        val previousTop = store.loadSettingsJson()
        val mergedTop = LinkedHashMap<String, Any?>(previousTop)
        mergedTop.putAll(patch)
        val nextSettings = TimetableSettings.fromJson(mergedTop)

        store.saveSettingsPatch(patch)
        try {
            store.saveSettingsPatchToActiveProfile(patch)
        } catch (error: Throwable) {
            // 第二笔失败：第一笔已落盘，把顶层写回旧文档（补偿失败不遮原始错误）。
            runCatching { store.saveSettingsPatch(settingsDiffPatch(store.loadSettingsJson(), previousTop)) }
            throw error
        }

        loadedSettings = nextSettings
        val activeId = activeProfile.id
        loadedProfiles = loadedProfiles.map { profile ->
            if (profile.id == activeId) profile.copy(settings = mergeSettings(profile.settings, patch)) else profile
        }
        pendingNotify = true
    }

    /**
     * 把顶层设置文档**整份写回**为 [values]（撤销 / 失败补偿用）。
     *
     * 底层只有合并写，所以先和盘上现有文档求差：目标里没有的键显式写 null（= 删除）。
     */
    fun replaceSettingsJson(values: Map<String, Any?>) {
        replaceSettingsJsonLocked(values)
        drainPendingNotify()
    }

    @Synchronized
    private fun replaceSettingsJsonLocked(values: Map<String, Any?>) {
        val patch = settingsDiffPatch(store.loadSettingsJson(), values)
        if (patch.isEmpty()) return
        val nextSettings = TimetableSettings.fromJson(values)
        store.saveSettingsPatch(patch)
        loadedSettings = nextSettings
        pendingNotify = true
    }

    /** 把**活动档案内嵌**的设置文档整份写回（撤销 / 失败补偿用）。 */
    fun replaceActiveProfileSettingsJson(values: Map<String, Any?>) {
        replaceActiveProfileSettingsJsonLocked(values)
        drainPendingNotify()
    }

    @Synchronized
    private fun replaceActiveProfileSettingsJsonLocked(values: Map<String, Any?>) {
        if (loadedProfiles.isEmpty()) return
        val current = activeProfileSettingsJsonLocked() ?: emptyMap()
        val patch = settingsDiffPatch(current, values)
        val nextSettings = TimetableSettings.fromJson(values)
        if (patch.isNotEmpty()) store.saveSettingsPatchToActiveProfile(patch)

        val activeId = activeProfile.id
        val nextProfiles = loadedProfiles.map { profile ->
            if (profile.id == activeId) profile.copy(settings = nextSettings) else profile
        }
        if (nextProfiles != loadedProfiles) {
            loadedProfiles = nextProfiles
            pendingNotify = true
        }
    }

    /** 内存模型合并一份设置补丁（只关心时间/周次五键；其余键由存储层保留）。 */
    private fun mergeSettings(base: TimetableSettings, patch: Map<String, Any?>): TimetableSettings {
        val merged = LinkedHashMap<String, Any?>(base.toJson())
        // 开学日双键：外来只给毫秒时，别让本机旧的文本键把它压掉（fromJson 文本优先）。
        if (patch.containsKey("semesterStartDate") && !patch.containsKey("semesterStartDateText")) {
            merged.remove("semesterStartDateText")
        }
        merged.putAll(patch)
        return TimetableSettings.fromJson(merged)
    }

    /**
     * 「把 [current] 改成 [target]」所需的合并补丁：缺的键写 null（删除），
     * 值不同的键写目标值。键序不影响语义。
     */
    private fun settingsDiffPatch(
        current: Map<String, Any?>,
        target: Map<String, Any?>,
    ): Map<String, Any?> {
        val patch = LinkedHashMap<String, Any?>()
        for (key in current.keys) if (key !in target) patch[key] = null
        for ((key, value) in target) {
            if (current[key] != value) patch[key] = value
        }
        return patch
    }

    private fun activeProfileSettingsJsonLocked(): Map<String, Any?>? {
        val raw = store.rawJson(TimetableStore.KEY_PROFILES) ?: return null
        val decoded = MiniJson.tryParse(raw)
        if (decoded !is List<*>) return null
        val activeId = activeProfile.id
        val profile = decoded.firstOrNull { item ->
            item is Map<*, *> && item["id"] == activeId
        } as? Map<*, *> ?: return null
        val settings = profile["settings"] as? Map<*, *> ?: return null
        val out = LinkedHashMap<String, Any?>()
        for ((key, value) in settings) if (key is String) out[key] = value
        return out
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
            // saveSettingsPatch 现在同时写活动档案内嵌 settings（真源）与顶层镜像，
            // 不必再单独调 saveSettingsPatchToActiveProfile（避免同一份档案写两遍）。
            store.saveSettingsPatch(patch)
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
    fun replaceAllProfiles(
        profiles: List<TimetableProfile>,
        activeProfileId: String?,
        /**
         * 外部来源（全量备份）的完整档案内嵌 settings（id → 键值表）。
         *
         * 铺底顺序见 [TimetableStore.saveProfiles]：本机旧内嵌 → 这里给的外部内嵌
         * → 本次 core 投影。不传 = 与旧行为完全一致。
         */
        preferredEmbeddedSettings: Map<String, Map<String, Any?>> = emptyMap(),
    ) {
        replaceAllProfilesLocked(profiles, activeProfileId, preferredEmbeddedSettings)
        drainPendingNotify()
    }

    @Synchronized
    private fun replaceAllProfilesLocked(
        profiles: List<TimetableProfile>,
        activeProfileId: String?,
        preferredEmbeddedSettings: Map<String, Map<String, Any?>> = emptyMap(),
    ) {
        // 先落盘：失败则内存与监听者都不动。
        store.saveProfiles(profiles, preferredEmbeddedSettings)
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
        /**
         * 可选的日历周（调用方已按新 [settings] 算好并 clamp）。
         *
         * 非空时与 [profiles] / [settings] 在**同一次锁定写入**里落盘（`current_week` 键 +
         * 活动档案内嵌的 `currentWeek`），并且仍然只通知一次；为空时行为与旧签名完全一致。
         */
        currentWeek: Int? = null,
    ) {
        replaceAllProfilesAndSettingsLocked(profiles, activeProfileId, settings, currentWeek)
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
        currentWeek: Int?,
    ) {
        // 周次非空：先把新设置下的钳制结果同步进活动档案（Dart `_persistActiveProfileState`
        // 的一致性口径），再与其余 key 一起落盘。悬空 id 回落第一份，与 [reload] 读侧一致。
        val clampedWeek = currentWeek
            ?.let { clampCurrentWeekToSettings(it.toLong(), settings).toInt() }
        val nextProfiles = if (clampedWeek == null) {
            profiles
        } else {
            val targetId = activeProfileId
                ?.takeIf { id -> profiles.any { it.id == id } }
                ?: profiles.firstOrNull()?.id
            profiles.map { profile ->
                if (profile.id == targetId) profile.copy(currentWeek = clampedWeek.toLong())
                else profile
            }
        }
        store.saveSettings(settings)
        store.saveProfiles(nextProfiles)
        store.saveActiveProfileId(activeProfileId)
        if (clampedWeek != null) store.saveCurrentWeek(clampedWeek)
        loadedSettings = settings
        loadedProfiles = nextProfiles
        loadedActiveProfileId = activeProfileId
        if (clampedWeek != null) loadedCurrentWeek = clampedWeek
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
        /**
         * 快照里每份档案**完整内嵌**的 settings（id → 键值表）。
         *
         * 备份恢复时这里的键优先落盘，不被本机当前内嵌覆盖；老备份只带 core 4 键时，
         * 本机其余键仍按 [TimetableStore.saveProfiles] 的铺底口径保留。
         */
        preferredEmbeddedSettings: Map<String, Map<String, Any?>> = emptyMap(),
    ) {
        restoreFromCloudSnapshotLocked(
            profiles,
            activeProfileId,
            timeSchemes,
            scheduleDateRules,
            locationTimeGroups,
            settings,
            preferredEmbeddedSettings,
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
        preferredEmbeddedSettings: Map<String, Map<String, Any?>>,
    ) {
        require(profiles.isNotEmpty()) { "restore snapshot must contain at least one profile" }
        val resolvedActiveId = activeProfileId
            ?.takeIf { id -> profiles.any { it.id == id } }
            ?: profiles.first().id
        val active = profiles.first { it.id == resolvedActiveId }
        val restoredSettings = settings ?: active.settings
        val restoredWeek = clampCurrentWeekToSettings(active.currentWeek, restoredSettings).toInt()

        // 先落盘：全部成功后才改内存，失败时界面保持旧状态。
        // 多 key 一次提交（2026-11-05 数据安全修复）：这七笔此前是逐 key 直写，中途
        // 一笔抛错会把磁盘留在半新半旧（如 profiles 新、settings 旧），内存却保持旧值
        // ——盘上状态从此对不上任何一致性口径。现在按快照回滚已写键再上抛。
        store.runRestoreTransaction {
            store.saveProfiles(profiles, preferredEmbeddedSettings)
            store.saveActiveProfileId(resolvedActiveId)
            store.saveSettings(restoredSettings)
            store.saveCurrentWeek(restoredWeek)
            store.saveTimeSchemes(timeSchemes)
            store.saveScheduleDateRules(scheduleDateRules)
            store.saveLocationTimeGroups(locationTimeGroups)
        }

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

    /**
     * 还原当前周次——**仅供导入回滚 / 撤销使用**，不是普通「切周」入口。
     *
     * 与 [setCurrentWeek] 的唯一差别：**不碰活动档的 `lastUsedAt`**。
     * [persistActiveProfileState] 会把 `lastUsedAt` 刷成当下时刻，而回滚 / 撤销不是「使用」
     * 这份课表：刷了它，盘上状态就与「导入前」不再逐字节相同（局域网导入的补偿用例正是
     * 靠逐字节对比抓回归，2026-11-06 第五轮返工）。
     *
     * 其余语义与 [setCurrentWeek] 一致：先按本机学期范围钳制、写 `profiles` /
     * `activeProfileId` / `settings` / `current_week` 四个键，落盘成功后才通知监听者。
     * **档案自带的 `currentWeek` 必须一起同步**，否则之后任何一次落盘（都会写档案本体）
     * 会把旧周次写回去，还原白做。
     */
    fun restoreCurrentWeek(week: Int) {
        restoreCurrentWeekLocked(week)
        drainPendingNotify()
    }

    @Synchronized
    private fun restoreCurrentWeekLocked(week: Int) {
        val clamped = clampCurrentWeekToSettings(week.toLong(), loadedSettings).toInt()
        val profile = activeProfile.copy(
            settings = loadedSettings,
            // 刻意**不写** lastUsedAt：保留当前档案原有的那个值。
            currentWeek = clamped.toLong(),
        )
        val nextProfiles = upsertProfile(profile)
        store.saveProfiles(nextProfiles)
        store.saveActiveProfileId(profile.id)
        store.saveSettings(loadedSettings)
        store.saveCurrentWeek(clamped)
        loadedProfiles = nextProfiles
        loadedActiveProfileId = profile.id
        loadedCurrentWeek = clamped
        currentLiveCourseId = null
        pendingNotify = true
    }

    /**
     * 把「按日历算出的周次」夹回本机学期范围（**纯计算，不写回**）。
     *
     * 对齐 Dart `syncTemporalContext`（`timetable_provider.dart:3259-3302`）：日历周由
     * `WeekCalculator.calendarWeekForDate`（`lib/domain/week_calculator.dart`，Kotlin
     * [com.mutx163.qingyu.core.WeekCalculator.calendarWeekForDate]）算出，学期结束后
     * 会得到大于 `semesterWeekCount` 的值、开学前得到 0；Dart 在 `:3286` 用
     * `clampCurrentWeekToSettings`（`timetable_profile.dart:27-38`）夹回展示范围再写
     * `_currentDateWeek`。Kotlin 首页线此前走 `TimetableDateLogic.currentSemesterWeek`
     * （Dart `_resolveCurrentSemesterWeek` 口径，`timetable_screen.dart:1392-1420`），
     * 学期外返回 null ⇒ 不写 ⇒ 停在旧周次；本 API 补上「越界也夹」的那一半。
     *
     * 口径：
     * 1. 学期内（`1..semesterWeekCount`）原样返回；
     * 2. `week < 1` ⇒ 1（开学前日历周为 0）；`week > semesterWeekCount` ⇒
     *    `semesterWeekCount`（学期结束后停在最后一周，与 Dart 同）；
     * 3. `semesterStartDate == null` ⇒ 原样返回：开学日未知时日历周推导无意义，
     *    Dart `_resolveCurrentCalendarWeek:3338-3341` 同样直接回落 `_currentWeek`；
     * 4. `semesterWeekCount <= 0` ⇒ 原样返回：周数缺失/坏值不具上限语义，夹到 1 会把
     *    用户当前周强行改成「第 1 周」，比不夹更坏。[clampCurrentWeekToSettings] 的
     *    `maxWeek = max(1, count)` 是**写入口**的兜底，不用于展示口径。
     *
     * 节假日不参与：本 API 只按数值边界夹取；节假日仅由 `ScheduleDateRule` 换课，
     * 不改变周次编号（Dart `syncTemporalContext` 同样没有节假日分支）。
     *
     * 与 [setCurrentWeek] 的关系：**只算不写**——不落盘、不改 `loadedCurrentWeek`、
     * 不通知监听者。是否写回由调用方决定（首页分钟心跳拿到结果后再自行调
     * [setCurrentWeek]）。
     */
    @Synchronized
    fun clampWeekToSettings(week: Int): Int {
        val settings = loadedSettings
        if (settings.semesterStartDate == null) return week
        val count = settings.semesterWeekCount
        if (count <= 0) return week
        return week.coerceIn(1, count)
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
    fun updateLocationTimeGroups(groups: List<LocationTimeGroup>, resync: Boolean = false) {
        updateLocationTimeGroupsLocked(groups, resync)
        drainPendingNotify()
    }

    /**
     * [resync] = true 是 Dart `replaceLocationTimeGroups(resync: true)` 的对应物：
     * 分组落盘后按**新分组**重算每份档案的课程钟点（[TimeSchemeLogic.syncCoursesWithEffectiveTimeSchemes]，
     * 与地点规则族同一份口径），再整份写回档案。
     *
     * 为什么传输层必须用它：局域网覆盖导入的顺序是「先写课（按接收方**原有**分组算钟点）、
     * 后换分组」。少了重算，盘上分组已经是新的、课程时间还是旧楼的教学节次，用户要到
     * 下一次任意地点规则改动才会被静默改对。
     *
     * 失败语义：分组先落盘；重算后的档案写盘失败时，尽力把旧分组写回去再上抛
     * （Dart `commitGroupChange` 同型），不留下「盘上新分组、内存旧分组」。
     * 默认 false 保持既有调用方语义不变（撤销路径自己会写回课程，不能重算覆盖）。
     */
    @Synchronized
    private fun updateLocationTimeGroupsLocked(groups: List<LocationTimeGroup>, resync: Boolean) {
        if (!resync) {
            store.saveLocationTimeGroups(groups)
            loadedLocationTimeGroups = groups
            pendingNotify = true
            return
        }
        val previousGroups = loadedLocationTimeGroups
        val nextProfiles = loadedProfiles.map { profile ->
            profile.copy(
                courses = TimeSchemeLogic.syncCoursesWithEffectiveTimeSchemes(
                    source = profile.courses,
                    schemes = loadedTimeSchemes,
                    settings = profile.settings,
                    locationTimeGroups = groups,
                    scheduleDateRules = loadedScheduleDateRules,
                ),
            )
        }
        store.saveLocationTimeGroups(groups)
        try {
            if (nextProfiles != loadedProfiles) store.saveProfiles(nextProfiles)
        } catch (error: Throwable) {
            runCatching { store.saveLocationTimeGroups(previousGroups) }
            throw error
        }
        loadedLocationTimeGroups = groups
        loadedProfiles = nextProfiles
        currentLiveCourseId = null
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

    /**
     * **整份写回时间模板表**——**仅供导入回滚 / 撤销使用**，不是普通编辑入口。
     *
     * 为什么单独要一个：导入的第一步就会 reconcile 模板（新建一套），而本仓储是
     * 「多 key 独立落盘、没有跨 key 事务」。回滚若只还原档案表，本机就会留下导入新建的模板，
     * 且没有任何接口能救回来——发布版快照含 `timeSchemes`、失败时整份写回，本方法就是那个落点。
     *
     * **刻意不做** `updateTimeScheme` 那套「被引用节数校验 / 课程钟点重排」：这是恢复原样、
     * 不是改模板；课程钟点由调用方用**同一份快照里的档案内容**一起写回，两边同源。
     */
    fun replaceTimeSchemes(schemes: List<TimeScheme>) {
        replaceTimeSchemesLocked(schemes)
        drainPendingNotify()
    }

    @Synchronized
    private fun replaceTimeSchemesLocked(schemes: List<TimeScheme>) {
        store.saveTimeSchemes(schemes)
        loadedTimeSchemes = schemes
        pendingNotify = true
    }

    /** 顶层集合 key 是否真的存在于盘上（恢复「导入前不存在」的精确原态时需要）。 */
    fun isStoredCollectionPresent(key: String): Boolean = store.containsKey(key)

    /** 删除整张时间模板表（恢复「导入前根本没有这个 key」，见 [isStoredCollectionPresent]）。 */
    fun removeTimeSchemes() {
        removeTimeSchemesLocked()
        drainPendingNotify()
    }

    @Synchronized
    private fun removeTimeSchemesLocked() {
        store.removeKey(TimetableStore.KEY_TIME_SCHEMES)
        loadedTimeSchemes = emptyList()
        pendingNotify = true
    }

    /** 删除日程规则 key（同上，恢复「导入前不存在」）。 */
    fun removeScheduleDateRules() {
        removeScheduleDateRulesLocked()
        drainPendingNotify()
    }

    @Synchronized
    private fun removeScheduleDateRulesLocked() {
        store.removeKey(TimetableStore.KEY_SCHEDULE_DATE_RULES)
        loadedScheduleDateRules = emptyList()
        pendingNotify = true
    }

    /** 删除地点作息分组 key（同上）。 */
    fun removeLocationTimeGroups() {
        removeLocationTimeGroupsLocked()
        drainPendingNotify()
    }

    @Synchronized
    private fun removeLocationTimeGroupsLocked() {
        store.removeKey(TimetableStore.KEY_LOCATION_TIME_GROUPS)
        loadedLocationTimeGroups = emptyList()
        pendingNotify = true
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

    /**
     * 埋点出口：先过 [EventPrivacy.sanitize] 隐私闸门（默认拒绝——只放行
     * 数值/布尔参数，课程名、教师名、地点名、档案名、URL、账号及一切自由文本、
     * 随机 id、日期一律剥掉），再交给注入的 [eventSink]（默认本地内存环形缓冲，
     * 不联网、不落盘、无用户标识）。Phase 4 接真分析后端时只需替换 sink 实现。
     */
    override fun logEvent(name: String, parameters: Map<String, Any>) {
        eventSink.log(name, EventPrivacy.sanitize(parameters))
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
