package com.mutx163.qingyu.transfer.lan

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

/**
 * 局域网导入的**撤销点**（对应 Dart `TransferUndoService` 的撤销令牌）。
 *
 * ## 为什么存「导入前 / 导入后两份现场」而不是一份反向补丁
 *
 * 撤销要做到「只回退这一批导入带来的变更，不抹掉用户之后的操作」，就必须能回答
 * 三个问题：这条数据导入前是什么、导入后是什么、现在是什么。只存导入前快照的话，
 * 撤销等于整份写回——用户导入之后又改了一门课，会被一起抹掉；只存反向补丁的话，
 * 又没法判断「现在这条还是不是导入写的那条」。两份现场 + 按 id 比对，三个问题
 * 都能答，且判据只有一处（[LanTransferUndoLogic.plan]）。
 *
 * ## 为什么是内存索引（不落盘）
 *
 * 1. Dart 的 `TransferUndoService` 本身就是内存态（注释写明「app restart is a new
 *    session」），两侧语义一致，网页端不用为「重启后撤销点还在不在」写两套逻辑；
 * 2. 每份撤销点都是**整份**课表快照（课 / 作业 / 考试 / 日程 / 作息 / 设置），
 *    落盘等于把用户数据翻倍写进 SharedPreferences，而且冷启动后那份快照大概率已
 *    与盘上数据无关（用户可能又从云备份恢复过）；
 * 3. 索引挂在进程级单例 [LanTransferUndoStore.shared] 上，局域网服务停掉再打开
 *    仍能撤销，只有杀进程才失效——这已经覆盖「导入完发现选错文件，马上撤回」的真实链路。
 *
 * ## 线程
 *
 * 局域网服务一个连接一个工作线程，[LanTransferUndoStore] 全部入口都在锁内。
 */
data class LanTransferState(
    val courses: List<Course> = emptyList(),
    val tasks: List<CourseTask> = emptyList(),
    val exams: List<Exam> = emptyList(),
    val scheduleItems: List<ScheduleItem> = emptyList(),
    val timeSchemes: List<TimeScheme> = emptyList(),
    val scheduleDateRules: List<ScheduleDateRule> = emptyList(),
    val locationTimeGroups: List<LocationTimeGroup> = emptyList(),
    val settings: TimetableSettings = TimetableSettings.defaults(),
    /**
     * 顶层设置文档的原始 JSON（Dart 侧 250+ 键）。[settings] 只是五键投影，
     * 撤销判据与写回都走这一份；null = 没捕获原文（旧调用方 / 纯逻辑单测）。
     */
    val settingsJson: Map<String, Any?>? = null,
    /** 活动档案内嵌设置文档的原始 JSON（桌面小组件读的那份镜像）。 */
    val activeProfileSettingsJson: Map<String, Any?>? = null,
    val currentWeek: Int = 1,
    /**
     * **整台设备**的档案表 + 导入时的激活档案 id。只在整份恢复的撤销点里捕获
     * （普通导入只动激活档案，抓全设备档案表白费内存）；空列表 = 未捕获。
     * 撤销判据见 [LanTransferLogic.wholeRestoreStateEquals]。
     */
    val profiles: List<TimetableProfile> = emptyList(),
    val activeProfileId: String? = null,
)

/**
 * 一个可撤销的导入。
 *
 * [profileId] 是导入发生时激活的档案。撤销时若激活档案已经换掉，**拒绝**而不是
 * 把旧档案的数据写进新档案（那样等于拿 A 课表的快照污染 B 课表）。
 */
data class LanTransferUndoToken(
    val id: String,
    val profileId: String?,
    val mode: TransferApplyMode,
    val scope: TransferScope,
    val before: LanTransferState,
    val after: LanTransferState,
    val createdAtMillis: Long,
)

/**
 * 撤销点索引：保留最近 [capacity] 个，按 id 消费一次。
 *
 * 容量取 3 与 Dart 一致：单槽时代「连做两次导入 + 一次失败回滚」会把上一份撤销点
 * 挤掉，用户点「撤销上一次导入」直接失败；每个槽是一整份课表快照，再多只徒增内存。
 */
class LanTransferUndoStore(private val capacity: Int = DEFAULT_CAPACITY) {

    private val lock = Any()
    private val tokens = ArrayList<LanTransferUndoToken>()
    private val consumedIds = LinkedHashSet<String>()

    /** 记一个新撤销点（同 id 覆盖，超出容量丢最旧）。 */
    fun create(token: LanTransferUndoToken): Unit = synchronized(lock) {
        tokens.removeAll { it.id == token.id }
        tokens.add(0, token)
        while (tokens.size > capacity) tokens.removeAt(tokens.size - 1)
        consumedIds.remove(token.id)
    }

    /**
     * 按 id 取走一个撤销点；取不到返回 null。
     *
     * **取走即消费**：同一份撤销点不能被点两次。第二次调用会走 [isConsumed] 分支，
     * 调用方据此回「已经撤销过」，而不是再跑一遍反向补丁。
     */
    fun take(id: String): LanTransferUndoToken? = synchronized(lock) {
        val index = tokens.indexOfFirst { it.id == id }
        if (index < 0) return null
        val token = tokens.removeAt(index)
        consumedIds.add(id)
        while (consumedIds.size > capacity * 2) {
            val iterator = consumedIds.iterator()
            iterator.next()
            iterator.remove()
        }
        token
    }

    /** 这个 id 是不是已经被成功撤销过（用于区分「没这个点」和「已经撤过了」）。 */
    fun isConsumed(id: String): Boolean = synchronized(lock) { id in consumedIds }

    /** 最近一个撤销点（网页端「撤销本次导入」只用它，不列历史）。 */
    fun pending(): LanTransferUndoToken? = synchronized(lock) { tokens.firstOrNull() }

    /**
     * 撤销执行失败时把令牌放回索引（不消耗用户的撤销机会）。
     *
     * 回炉位置按 [LanTransferUndoToken.createdAtMillis] 排序，与创建顺序一致；
     * 不放在最前面——那会让「撤销最近一次导入」指向一个更老的导入。
     */
    fun restore(token: LanTransferUndoToken): Unit = synchronized(lock) {
        consumedIds.remove(token.id)
        if (tokens.any { it.id == token.id }) return
        val index = tokens.indexOfFirst { it.createdAtMillis < token.createdAtMillis }
        if (index < 0) tokens.add(token) else tokens.add(index, token)
    }

    fun clear(): Unit = synchronized(lock) {
        tokens.clear()
        consumedIds.clear()
    }

    companion object {
        const val DEFAULT_CAPACITY = 3

        /** 进程级索引：局域网服务停掉再开不影响撤销点（杀进程才失效）。 */
        val shared = LanTransferUndoStore()
    }
}

/**
 * 一次撤销要做哪些写操作；字段为 null = 这一块不动。
 *
 * 「不动」的理由有两类：导入本来就没碰它（before 与 after 一样），或者导入之后
 * 用户又改过它（现在值与「导入后」对不上）——后者正是「不能把用户之后的操作一起
 * 抹掉」的落点。
 */
data class LanTransferUndoPlan(
    val courses: List<Course>? = null,
    val tasks: List<CourseTask>? = null,
    val exams: List<Exam>? = null,
    val scheduleItems: List<ScheduleItem>? = null,
    val scheduleDateRules: List<ScheduleDateRule>? = null,
    val locationTimeGroups: List<LocationTimeGroup>? = null,
    val settings: TimetableSettings? = null,
    /** 顶层设置文档的反向补丁（整份）；与 [settings] 同时给出，执行层优先用它。 */
    val settingsJson: Map<String, Any?>? = null,
    /** 活动档案内嵌设置文档的反向补丁（桌面小组件镜像）。 */
    val activeProfileSettingsJson: Map<String, Any?>? = null,
    val currentWeek: Int? = null,
    val timeSchemesToDelete: List<String> = emptyList(),
    val timeSchemesToRestore: List<TimeScheme> = emptyList(),
    /** 每类真正回退了多少条；只记非零项（网页端据此提示「撤销了什么」）。 */
    val restoredCounts: Map<String, Int> = emptyMap(),
) {
    val hasChanges: Boolean get() = restoredCounts.isNotEmpty()
}

/**
 * [LanTransferUndoToken] 的纯逻辑：**给定当前现场**算出反向补丁。
 *
 * 判据（对每个实体 id）：
 * - 导入**新增**的：现在值仍等于「导入后」→ 删除；已缺失或已被改过 → 不动；
 * - 导入**删除**的：现在仍缺失 → 写回「导入前」；同 id 已经存在 → 不动；
 * - 导入**修改**的：现在值仍等于「导入后」→ 写回「导入前」；已被改过 → 不动。
 *
 * 集合/设置/当前周同一口径：只有「导入确实改了」且「现在仍是导入后的值」才回退。
 */
object LanTransferUndoLogic {

    fun plan(current: LanTransferState, token: LanTransferUndoToken): LanTransferUndoPlan {
        val counts = LinkedHashMap<String, Int>()

        val coursesPatch = reversePatch(
            before = token.before.courses,
            after = token.after.courses,
            current = current.courses,
            idOf = Course::id,
            jsonOf = { it.toJson() },
        )
        coursesPatch?.let { counts["courses"] = it.changedCount }

        val tasksPatch = reversePatch(
            before = token.before.tasks,
            after = token.after.tasks,
            current = current.tasks,
            idOf = CourseTask::id,
            jsonOf = { it.toJson() },
        )
        tasksPatch?.let { counts["tasks"] = it.changedCount }

        val examsPatch = reversePatch(
            before = token.before.exams,
            after = token.after.exams,
            current = current.exams,
            idOf = Exam::id,
            jsonOf = { it.toJson() },
        )
        examsPatch?.let { counts["exams"] = it.changedCount }

        val scheduleItemsPatch = reversePatch(
            before = token.before.scheduleItems,
            after = token.after.scheduleItems,
            current = current.scheduleItems,
            idOf = ScheduleItem::id,
            jsonOf = { it.toJson() },
        )
        scheduleItemsPatch?.let { counts["schedule_items"] = it.changedCount }

        val rulesPatch = reversePatch(
            before = token.before.scheduleDateRules,
            after = token.after.scheduleDateRules,
            current = current.scheduleDateRules,
            idOf = ScheduleDateRule::id,
            jsonOf = { it.toJson() },
        )
        rulesPatch?.let { counts["time_rules"] = it.changedCount }

        val groupsPatch = reversePatch(
            before = token.before.locationTimeGroups,
            after = token.after.locationTimeGroups,
            current = current.locationTimeGroups,
            idOf = LocationTimeGroup::id,
            jsonOf = { it.toJsonMap() },
        )
        groupsPatch?.let { counts["locations"] = it.changedCount }

        val schemePlan = planTimeSchemes(token, current)
        if (schemePlan.deletedIds.isNotEmpty() || schemePlan.restored.isNotEmpty()) {
            counts["time_schemes"] = schemePlan.deletedIds.size + schemePlan.restored.size
        }

        // 设置按**原始文档**比：导入写回的是整份 250+ 键，只比五键会漏掉
        // 「只改了未移植字段」的那一类，撤销就静默不生效。
        val settingsPlan = settingsReversePatch(current, token)
        settingsPlan?.let { counts["settings"] = 1 }

        val week = if (
            token.before.currentWeek != token.after.currentWeek &&
            current.currentWeek == token.after.currentWeek
        ) {
            token.before.currentWeek
        } else {
            null
        }
        week?.let { counts["current_week"] = 1 }

        return LanTransferUndoPlan(
            courses = coursesPatch?.items,
            tasks = tasksPatch?.items,
            exams = examsPatch?.items,
            scheduleItems = scheduleItemsPatch?.items,
            scheduleDateRules = rulesPatch?.items,
            locationTimeGroups = groupsPatch?.items,
            settings = settingsPlan?.settings,
            settingsJson = settingsPlan?.settingsJson,
            activeProfileSettingsJson = settingsPlan?.activeProfileSettingsJson,
            currentWeek = week,
            timeSchemesToDelete = schemePlan.deletedIds,
            timeSchemesToRestore = schemePlan.restored,
            restoredCounts = counts,
        )
    }

    /** 撤销接口的响应体：`{undo, transferId, restored, skipped, error?}`。 */
    fun resultJson(
        undone: Boolean,
        transferId: String,
        restoredCounts: Map<String, Int> = emptyMap(),
        skipped: List<String> = emptyList(),
        error: String? = null,
    ): Map<String, Any?> = linkedMapOf<String, Any?>(
        "undo" to undone,
        "transferId" to transferId,
        "restored" to restoredCounts,
        "skipped" to skipped,
    ).apply { if (error != null) this["error"] = error }

    // -----------------------------------------------------------------------
    // 内部
    // -----------------------------------------------------------------------

    private data class Patch<T>(val items: List<T>, val changedCount: Int)

    /**
     * 三类集合通用反向补丁：按 id 比对，只回退「仍是导入后状态」的那些。
     *
     * 返回 null 表示这一块完全不需要动（导入没改它，或改了但用户又动过）。
     */
    private fun <T> reversePatch(
        before: List<T>,
        after: List<T>,
        current: List<T>,
        idOf: (T) -> String,
        jsonOf: (T) -> Map<String, Any?>,
    ): Patch<T>? {
        val beforeById = before.associateBy(idOf)
        val afterById = after.associateBy(idOf)
        val currentIds = current.mapTo(HashSet(current.size), idOf)
        val result = ArrayList<T>(current.size)
        var changed = 0

        for (item in current) {
            val id = idOf(item)
            val previous = beforeById[id]
            val imported = afterById[id]
            when {
                // 导入新增：撤掉仍保持原样的那条。
                previous == null && imported != null ->
                    if (same(imported, item, jsonOf)) changed++ else result += item

                // 导入修改：只还原仍保持「导入后」值的那条。
                previous != null && imported != null &&
                    !same(previous, imported, jsonOf) && same(imported, item, jsonOf) -> {
                    changed++
                    result += previous
                }

                // 导入没改过 / 用户已改过：原样保留。
                else -> result += item
            }
        }

        // 导入删除的：现在仍缺失才写回；同 id 已存在（用户重建过）不动。
        for (item in before) {
            val id = idOf(item)
            if (id !in afterById && id !in currentIds) {
                changed++
                result += item
            }
        }

        return if (changed == 0) null else Patch(result, changed)
    }

    private data class SchemePlan(
        val deletedIds: List<String>,
        val restored: List<TimeScheme>,
    )

    /**
     * 时间模板的反向补丁。
     *
     * 只比 `name` + `sections`：`createdAt` / `updatedAt` 是本地写入时间，导入/撤销
     * 本来就无法还原到原值，拿它比对会把所有模板都判成「用户改过」。
     *
     * 导入不会删模板（`planTimeSchemes` 只有更新/复用/新建），所以这里只有「删新建」
     * 与「还原被改名/改节次」两种。删除可能被 `deleteTimeScheme` 的引用判据拒绝、
     * 还原可能被「节次数不能少于已用最大节次」拒绝——都属可预期的跳过，由执行层汇报。
     */
    private fun planTimeSchemes(
        token: LanTransferUndoToken,
        current: LanTransferState,
    ): SchemePlan {
        val beforeById = token.before.timeSchemes.associateBy { it.id }
        val afterById = token.after.timeSchemes.associateBy { it.id }
        val currentById = current.timeSchemes.associateBy { it.id }
        val deleted = ArrayList<String>()
        val restored = ArrayList<TimeScheme>()

        for (scheme in token.after.timeSchemes) {
            val previous = beforeById[scheme.id]
            val live = currentById[scheme.id]
            if (previous == null) {
                if (live != null && sameScheme(live, scheme)) deleted += scheme.id
            } else if (!sameScheme(previous, scheme) && live != null && sameScheme(live, scheme)) {
                restored += previous
            }
        }
        // 导入后才出现在 after 里、但已从 after 之外被用户删掉的模板：无需处理。
        if (deleted.isEmpty() && restored.isEmpty()) return SchemePlan(emptyList(), emptyList())
        return SchemePlan(deleted, restored)
    }

    private fun sameScheme(left: TimeScheme, right: TimeScheme): Boolean =
        left.id == right.id && left.name == right.name &&
            left.sections == right.sections

    private fun <T> same(left: T, right: T, jsonOf: (T) -> Map<String, Any?>): Boolean =
        LanTransferLogic.sameJson(jsonOf(left), jsonOf(right))

    private data class SettingsPlan(
        val settings: TimetableSettings?,
        val settingsJson: Map<String, Any?>?,
        val activeProfileSettingsJson: Map<String, Any?>?,
    )

    /**
     * 设置的反向补丁：只有「导入确实改了」且「现在仍是导入后的值」才回退。
     *
     * 优先按**原始文档**比（两侧都捕获到原文时）；任一侧没有原文（纯逻辑单测
     * 直接构造 [LanTransferState]）退回五键投影，与旧口径等价。
     * 活动档案镜像只在它确实被导入改过时才还原。
     */
    private fun settingsReversePatch(
        current: LanTransferState,
        token: LanTransferUndoToken,
    ): SettingsPlan? {
        val beforeTop = token.before.settingsJson?.let(LanTransferLogic::normalizeSettingsDocument)
        val afterTop = token.after.settingsJson?.let(LanTransferLogic::normalizeSettingsDocument)
        val currentTop = current.settingsJson?.let(LanTransferLogic::normalizeSettingsDocument)
        val useRawTop = beforeTop != null && afterTop != null && currentTop != null

        val changed = if (useRawTop) {
            !LanTransferLogic.sameJson(beforeTop!!, afterTop!!)
        } else {
            !LanTransferLogic.sameJson(token.before.settings.toJson(), token.after.settings.toJson())
        }
        if (!changed) return null

        val stillAfter = if (useRawTop) {
            LanTransferLogic.sameJson(currentTop!!, afterTop!!)
        } else {
            LanTransferLogic.sameJson(current.settings.toJson(), token.after.settings.toJson())
        }
        if (!stillAfter) return null

        val beforeProfile = token.before.activeProfileSettingsJson
            ?.let(LanTransferLogic::normalizeSettingsDocument)
        val afterProfile = token.after.activeProfileSettingsJson
            ?.let(LanTransferLogic::normalizeSettingsDocument)
        val profileChanged = beforeProfile != null && afterProfile != null &&
            !LanTransferLogic.sameJson(beforeProfile, afterProfile)

        return SettingsPlan(
            settings = if (useRawTop) null else token.before.settings,
            settingsJson = if (useRawTop) beforeTop else null,
            activeProfileSettingsJson = if (profileChanged) beforeProfile else null,
        )
    }
}
