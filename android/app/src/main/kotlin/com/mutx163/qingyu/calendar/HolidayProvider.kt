package com.mutx163.qingyu.calendar

import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime

/**
 * 一条更新日志（时刻 + 已本地化正文）。
 *
 * [time] 是**已格式化好的字符串**（`HH:mm:ss`，时/分/秒各自补零到两位，恒 8 个字符，
 * 例如 `09:00:12`）——与 Dart `HolidayLogEntry.timeString`（`holiday_service.dart:24-29`）
 * 同口径。界面层直接展示，不要再格式化。
 *
 * [message] 已经过 [HolidayLogLocalizer.localize]，是可直接上屏的中文。
 */
data class HolidayLogLine(val time: String, val message: String)

/**
 * 节假日功能的当前状态快照（界面只读消费；每次变化整体替换引用，便于 Compose 比对）。
 *
 * 字段语义（与 audit §5 契约一致）：
 * - [year]：数据年份，页面标题用；
 * - [data]：官方数据（含邻年合并后的条目），**不含**用户自定义假期——自定义假期在
 *   [customHolidays] 里单独给，页面按 groupId 自行归并，这样「官方」与「自定义」两种
 *   三态（null / 空 / 列表）才能分别表达。需要 Dart 那种「全量合一」的数据（月视图 /
 *   小组件判定）请用 [HolidayProvider.mergedData]；
 * - [customCorrupted]：自定义假期持久化数据损坏（页面据此出提示条，而不是显示「暂无」）；
 * - [refreshing]：正在强制刷新（只影响按钮 loading 态）；
 * - [logs]：[HolidayProvider.logs] 的同一份拷贝，最新在前，上限 [HolidayProvider.MAX_LOGS]。
 */
data class HolidaySnapshot(
    val year: Int,
    val data: HolidayData?,
    val customHolidays: List<HolidayEntry>,
    val customCorrupted: Boolean,
    val refreshing: Boolean,
    val logs: List<HolidayLogLine>,
)

/**
 * 节假日状态机（移植 `lib/services/holiday_service.dart` 的 `getDataForYear`
 * + `lib/services/timetable_holiday_service.dart` 的 `_loadImpl` / `refresh` / 自定义假期用例）。
 *
 * ## 为什么是同步阻塞的
 *
 * 本目录要进 JVM 单测（`scripts/test-kotlin-module.ps1` 的 classpath 里没有协程调度器），
 * 所以所有方法都阻塞返回，真正的异步由界面层负责（Compose 宿主把调用放进
 * `Dispatchers.IO`）。这与 `weather/WeatherProvider.kt` 的取舍完全一致，理由也相同。
 *
 * ## 构造不发请求
 *
 * 构造只建立空快照；网络与磁盘读只发生在 [initialize] / [refresh] 里。
 * 失败**从不**外抛（节假日是非关键数据），只落 [logs]。
 *
 * ## 加载顺序（Dart `getDataForYear`，`:105-162`）
 *
 * 1. 内存缓存 → 命中即用；
 * 2. 本地缓存（`holiday_data_<year>`）→ 命中即用；
 * 3. 都没有 → 阻塞取远端（[HolidayRemoteGateway]，主端点 → 备用端点）；
 * 4. 远端失败 → 内置资产兜底（[builtinJson]）。
 *
 * ## 与 Dart 的已知差异（重要，别当成漏做）
 *
 * - **没有后台刷新**：Dart 缓存命中后会 fire-and-forget 地再拉一次
 *   （`_backgroundRefresh`，`:165-206`），本实现同步阻塞、命中即返回，所以
 *   `holiday_log_background_success` / `holiday_log_background_no_data` 两条键
 *   **永远不会被发出**（本地化表里仍然保留，保证 19 条与 Dart 一一对应）。
 *   需要用强刷时的入口是 [refresh]。
 * - **空兜底不落盘**：Dart 明确写了理由（`:148-153`），这里照抄——内置资产没有该年文件时
 *   内存里返回空结果，但**不写缓存**，否则「这一年确定没有假期」会被固化成事实，
 *   远程一直失败时后续版本新带的资产永远读不到。
 * - **initialize 可重复调用**：Dart 每次 `load()` 都重新走一遍；这里同样每次重新走，
 *   但因为有内存/本地缓存，**重复调用不会发第二次网络请求**（幂等），并会补记一条
 *   「命中内存缓存」日志。
 * - **merge 的生产者不同**：Dart 把自定义假期也塞进 `holidayData.entries`；这里
 *   `snapshot.data` 只放官方数据，自定义假期单独暴露（见 [HolidaySnapshot.data]）。
 *
 * @param service 远程取数接缝（生产用 [HolidayService]，单测注入假网关）
 * @param preferences 两个键的持久化
 * @param builtinJson 内置资产兜底：`year -> assets/holidays/<year>.json` 的文本，没有该年返回 null
 *   （读资产是 Android `AssetManager` 的事，壳注入；本层只拿字符串，保证可测）
 * @param clock 「今天」（Dart 用 `DateTime.now()`；注入是为了覆盖 12 月末 / 1 月初的跨年分支）
 * @param nowTime 日志时刻的口子（Dart `DateTime.now()` 的时/分/秒；同样只为可测）
 */
class HolidayProvider(
    private val service: HolidayRemoteGateway,
    private val preferences: HolidayPreferences,
    private val builtinJson: (year: Int) -> String?,
    private val clock: () -> LocalDate = { LocalDate.now() },
    private val nowTime: () -> LocalTime = { LocalTime.now() },
) {

    companion object {
        /** Dart `_log` 里 `if (logs.length > 50) logs.removeLast()`（`:74-81`）。 */
        const val MAX_LOGS = 50

        /**
         * `HH:mm:ss`（Dart `HolidayLogEntry.timeString`）。
         *
         * 用 [java.util.Locale.ROOT] 而不是默认 locale：阿拉伯语等 locale 下
         * `String.format` 会输出本地数字，与 Dart 的 `padLeft` 行为不一致。
         */
        fun formatTime(time: LocalTime): String =
            String.format(
                java.util.Locale.ROOT,
                "%02d:%02d:%02d",
                time.hour,
                time.minute,
                time.second,
            )
    }

    private val listeners = ArrayList<() -> Unit>()

    /** 内存缓存：年份 → 当年官方数据（与 Dart `_memoryCache` 同义）。 */
    private val memoryCache = HashMap<Int, HolidayData>()

    /** 本次会话的日志，**最新在前**（Dart `logs.insert(0, entry)`）。 */
    private val logLines = ArrayList<HolidayLogLine>()

    /** 重入保护：界面层可能在同一帧里连点两次「检查更新」。 */
    private var loading = false

    /** 当前状态。只读消费；变化时整体换引用。 */
    var snapshot: HolidaySnapshot = HolidaySnapshot(
        year = clock().year,
        data = null,
        customHolidays = emptyList(),
        customCorrupted = false,
        refreshing = false,
        logs = emptyList(),
    )
        private set

    /** 本次会话的更新日志（最新在前，上限 [MAX_LOGS]），供高级页展示。 */
    val logs: List<HolidayLogLine>
        get() = logLines.toList()

    // ---------- 监听 ----------

    fun addListener(listener: () -> Unit) {
        listeners.add(listener)
    }

    fun removeListener(listener: () -> Unit) {
        listeners.remove(listener)
    }

    // ---------- 生命周期 ----------

    /**
     * 读盘 + 缺年份补一次远端（Dart `TimetableHolidayService.load` / `_loadImpl`，`:52-92`）。
     *
     * 全量重走一遍「缓存 → 远端 → 内置」，但命中缓存时**不发网络**，所以重复调用是幂等的
     * （同一份数据、零网络）。跨年那一周会把邻年数据一起合进来（见 [holidayYearsToLoad]）。
     */
    fun initialize() {
        if (loading) return
        loading = true
        try {
            load(forceRemote = false, refreshing = false)
        } finally {
            loading = false
        }
        notifyChanged()
    }

    /**
     * 强制刷新（高级页「检查更新」，Dart `TimetableHolidayService.refresh`，`:99-103`）：
     * 先清掉这几年的内存 + 本地缓存，再重新取网；成功就写缓存（[load] 内部完成）。
     *
     * 不清缓存的话，Dart 的 `refresh` 会退化成「命中缓存直接返回」，按钮点了没反应。
     */
    fun refresh() {
        if (loading) return
        loading = true
        // 先亮 loading（界面据此把按钮置灰），再干活。
        snapshot = snapshot.copy(refreshing = true)
        notifyChanged()
        try {
            load(forceRemote = true, refreshing = false)
        } finally {
            loading = false
        }
        notifyChanged()
    }

    // ---------- 自定义假期 ----------

    /**
     * 读自定义假期：`null` = 持久化数据损坏（**不是**「没有数据」）。
     *
     * 只读展示场景无法修复损坏，所以这里不做兜底成空列表——设置页要靠这个 null
     * 区分「暂无」与「损坏」并给提示条（Dart `loadCustomHolidaysOrNull`，`:113-118`）。
     */
    fun customHolidaysOrNull(): List<HolidayEntry>? = preferences.loadCustomHolidays()

    /**
     * 批量新增（Dart `addCustomHolidays`，`:705-710`）：一次 load → append → save。
     *
     * @throws HolidayCustomSaveException 存储损坏（拒绝覆盖）或写盘失败
     */
    fun addCustomHolidays(entries: List<HolidayEntry>) {
        mutate(CustomHolidayListOps.Operation.AddMany(entries))
    }

    /**
     * 按 groupId 整组替换（编辑已有假期，Dart `updateCustomHoliday`，`:694-703`）。
     *
     * @throws HolidayCustomSaveException 存储损坏或写盘失败
     */
    fun updateCustomHoliday(groupId: String, entries: List<HolidayEntry>) {
        mutate(CustomHolidayListOps.Operation.Update(groupId, entries))
    }

    /**
     * 按 groupId 整组删除（Dart `removeCustomHoliday`，`:687-692`）。
     *
     * @throws HolidayCustomSaveException 存储损坏或写盘失败
     */
    fun removeCustomHoliday(groupId: String) {
        mutate(CustomHolidayListOps.Operation.Remove(groupId))
    }

    // ---------- 合成数据 ----------

    /**
     * 官方条目 + 自定义条目（等价 Dart `_loadImpl` 合并后的 `holidayData`，`:58-75`）。
     *
     * 给需要「按天判定假期」的消费方用（月视图网格、桌面小组件）——判定语义
     * （[HolidayData.isHoliday] 里「自定义假期优先级最高」）依赖两类条目在同一份数据里。
     * 设置页不要用它：那边要分别展示「官方」与「自定义」两个三态。
     *
     * 自定义数据损坏时只返回官方条目（与 Dart「跳过合并」的口径一致，`:64-70`）。
     */
    fun mergedData(): HolidayData? {
        val official = snapshot.data ?: return null
        if (snapshot.customHolidays.isEmpty()) return official
        return HolidayData(
            year = official.year,
            version = official.version,
            entries = official.entries + snapshot.customHolidays,
        )
    }

    // ---------- 内部 ----------

    /**
     * 一次完整加载：逐年份取数据（缓存/远端/内置）→ 合并邻年 → 读自定义假期 → 换快照。
     *
     * [forceRemote] 为 true 时跳过内存与本地缓存，并把这两层清掉（[refresh] 用）。
     */
    private fun load(forceRemote: Boolean, refreshing: Boolean) {
        val today = clock()
        // 「这一周里出现过的年份」都要加载（元旦/春节整段可能挂邻年响应里）。
        // 用 LinkedHashSet 的插入序：当前年在最前，与 Dart 的 `{now.year, weekStart.year, weekEnd.year}`
        // 字面量顺序一致，合并结果的条目顺序因此也一致。
        val years = holidayYearsToLoad(LocalDateTime.of(today, LocalTime.NOON))

        val current = dataForYear(today.year, forceRemote)
        val allEntries = ArrayList(current.entries)
        for (year in years) {
            if (year == today.year) continue
            allEntries.addAll(dataForYear(year, forceRemote).entries)
        }

        val storedCustoms = preferences.loadCustomHolidays()
        if (storedCustoms == null) {
            // Dart `:637 _log('custom_holidays_corrupted|error=…')`：这里是故意不翻译的
            // 原始串（本地化表里没有这条键），界面会原样展示，用来提示用户「数据坏了」。
            log("custom_holidays_corrupted")
        }

        snapshot = HolidaySnapshot(
            year = current.year,
            data = HolidayData(
                // Dart 合并后仍沿用「当前年那份数据」的 year/version（`:71-75`）。
                year = current.year,
                version = current.version,
                entries = allEntries,
            ),
            customHolidays = storedCustoms ?: emptyList(),
            customCorrupted = storedCustoms == null,
            refreshing = refreshing,
            logs = logs,
        )
    }

    /**
     * 取某一年：内存缓存 → 本地缓存 → 远端 → 内置资产（Dart `getDataForYear`）。
     *
     * 永远返回非 null：走到最后一步的内置兜底时，没有该年资产就返回空数据
     * （「没有数据」是合法结果，不假装失败）。
     */
    private fun dataForYear(year: Int, forceRemote: Boolean): HolidayData {
        if (forceRemote) {
            memoryCache.remove(year)
            preferences.clearYear(year)
        } else {
            val cachedInMemory = memoryCache[year]
            if (cachedInMemory != null) {
                log("$KEY_MEMORY_CACHE_HIT|year=$year|count=${cachedInMemory.entries.size}")
                return cachedInMemory
            }
            val cachedOnDisk = preferences.loadYear(year)
            if (cachedOnDisk != null) {
                memoryCache[year] = cachedOnDisk
                log("$KEY_LOCAL_CACHE_HIT|year=$year|count=${cachedOnDisk.entries.size}")
                return cachedOnDisk
            }
        }

        log("$KEY_NO_CACHE_FETCHING|year=$year")
        val remote = service.fetchYear(year) { raw -> log(raw) }
        // 空条目不算成功（网关已保证，这里再兜一层，防止假网关回空列表被写进缓存）。
        if (remote != null && remote.entries.isNotEmpty()) {
            memoryCache[year] = remote
            preferences.saveYear(year, remote)
            log("$KEY_REMOTE_SUCCESS|year=$year|count=${remote.entries.size}")
            return remote
        }

        log("$KEY_REMOTE_FAILED_BUILTIN|year=$year")
        val builtin = loadBuiltin(year)
        memoryCache[year] = builtin
        // 空兜底**不落盘**（Dart `:148-153` 的理由原样保留）。
        if (builtin.entries.isNotEmpty()) {
            preferences.saveYear(year, builtin)
        }
        log("$KEY_BUILTIN_LOADED|year=$year|count=${builtin.entries.size}")
        return builtin
    }

    /** 内置资产兜底（Dart `_loadBuiltin`，`:245-253`）：没有该年文件 / 解析失败 → 空数据。 */
    private fun loadBuiltin(year: Int): HolidayData {
        val json = try {
            builtinJson(year)
        } catch (_: Exception) {
            null
        } ?: return HolidayData(year = year, version = 1, entries = emptyList())
        return try {
            HolidayData.fromJsonString(json)
        } catch (_: Exception) {
            HolidayData(year = year, version = 1, entries = emptyList())
        }
    }

    /**
     * 增删改的共同尾部：读 → 纯变换 → 写盘 → 换快照。
     *
     * 读返回 null 时 [CustomHolidayListOps.mutate] 也给 null，这里立刻抛异常：
     * **绝不允许**「损坏 → 当空列表 → 写回」这条会清零用户数据的路径。
     */
    private fun mutate(operation: CustomHolidayListOps.Operation) {
        val existing = preferences.loadCustomHolidays()
        val next = CustomHolidayListOps.mutate(existing, operation)
            ?: throw HolidayCustomSaveException(
                "custom holiday storage corrupted; refusing to overwrite",
            )
        preferences.saveCustomHolidays(next)
        snapshot = snapshot.copy(customHolidays = next, customCorrupted = false, logs = logs)
        notifyChanged()
    }

    private fun log(rawKey: String) {
        val line = HolidayLogLine(
            time = formatTime(nowTime()),
            message = HolidayLogLocalizer.localize(rawKey),
        )
        logLines.add(0, line)
        while (logLines.size > MAX_LOGS) {
            logLines.removeAt(logLines.size - 1)
        }
    }

    private fun notifyChanged() {
        for (listener in listeners.toList()) listener()
    }
}

// 日志键（Dart `getDataForYear` 的 `_logKey` 调用，`holiday_service.dart:109-160`）。
// 文件级常量：`HolidayProvider` 已经有一个公开常量 companion（一个类只能有一个）。
private const val KEY_MEMORY_CACHE_HIT = "holiday_log_memory_cache_hit"
private const val KEY_LOCAL_CACHE_HIT = "holiday_log_local_cache_hit"
private const val KEY_NO_CACHE_FETCHING = "holiday_log_no_cache_fetching"
private const val KEY_REMOTE_SUCCESS = "holiday_log_remote_success"
private const val KEY_REMOTE_FAILED_BUILTIN = "holiday_log_remote_failed_builtin"
private const val KEY_BUILTIN_LOADED = "holiday_log_builtin_loaded"
