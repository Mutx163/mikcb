package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.LocationTimeGroup
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.ScheduleDateRule
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import java.io.IOException
import java.time.LocalDateTime

/**
 * 课表相关 key 的**领域存储**（纯 Kotlin，无 Android 依赖）。
 *
 * 这一层只干一件事：把「冻结格式的盘上字节」翻译成模型对象、以及反向。
 * 它不持有状态、不做业务规则——那些在 [TimetableRepository]。
 *
 * ## 冻结格式（数据契约 §1 / §2.1，写错就是用户数据丢失）
 *
 * | 契约 key | 盘上类型 | 内容 |
 * |---|---|---|
 * | `timetable_profiles` | String(JSON) | 课表全量 JSON **数组**，v1 布局 |
 * | `timetable_profiles_schema_version` | int | 恒 1；**写路径自动盖章** |
 * | `active_timetable_profile_id` | String | 当前激活档案 id |
 * | `timetable_settings` | String(JSON) | 设置（本层只拥有时间/周次 4 键 + 单节提醒 1 键，见下） |
 * | `current_week` | int | 当前周次 |
 * | `time_schemes` | String(JSON) | 作息方案数组 |
 * | `schedule_date_rules` | String(JSON) | 作息日期规则数组 |
 * | `location_time_groups` | String(JSON) | 地点作息分组数组 |
 * | `teacher_records` / `location_records` | **List<String>** | 教师/地点历史（走 [FrozenValueCodec]） |
 * | `timetable_profiles_unparsed_items` | String(JSON) | 条目级坏数据滚动留档 `{archivedAt, count, items}` |
 *
 * `flutter.` 前缀由 [KeyValueStore] 的实现负责，本层永远只说**契约 key**。
 *
 * ## 损坏值必须留档，不许静默吞掉
 *
 * 解析失败 → `{key}_corrupt_backup_{微秒时间戳}` 留档 + 删原 key
 *（Dart `storage_service.dart:555-578` 同口径）。「留档」不是锦上添花：
 * 没有它，用户数据就无声消失、事后连坏在哪都查不到。
 * 顺带复刻 Dart 的清扫：**同 key 的旧留档只保留最近一份**
 *（`_sweepOldCorruptBackups`，:527-553）——不然每次冷启动都追加一份，
 * 留档自己会变成新的存储问题。
 *
 * ## 设置为什么是「合并不是整体覆盖」
 *
 * [TimetableSettings] 只移植了时间/周次的 4 个键 + 单节提醒 `classReminders`，Dart 侧同名字典有 250+ 字段
 *（`timetable_settings.dart` 头注释已写明：**在设置族补齐前，Compose 侧不得用本类
 * 整体覆盖设置存档，会丢其余字段**）。所以 [saveSettings] 的做法是：
 * 读回盘上那份 JSON 对象 → 只覆盖本层拥有的键 → 写回。其余字段原样保留。
 * 直接把 `settings.toJson()` 写下去会让用户丢设置，这是本层最危险的一处。
 */
class TimetableStore(
    private val store: KeyValueStore,
    /** 留档时间戳来源，可注入——否则「留档名对不对」在测试里只能写「大致像」。 */
    private val nowMicros: () -> Long = { System.currentTimeMillis() * 1000L },
) {

    /** 课表全量数组的解析结果（含损坏留档信息）。 */
    data class ProfilesLoadResult(
        val profiles: List<TimetableProfile>,
        val didDrop: Boolean,
        /** 只有条目级损坏（整条档案仍可用）——此时**不许**把清洗结果写回盘。 */
        val itemLevelOnlyDrop: Boolean,
        val quarantinedItems: List<String>,
        /** 本次因整份坏掉而留档用的契约 key；没留档为 null。 */
        val corruptBackupKey: String? = null,
    )

    /** 作息方案数组的解析结果。 */
    data class TimeSchemesLoadResult(
        val schemes: List<TimeScheme>,
        val corruptBackupKey: String? = null,
    )

    // ---------- timetable_profiles ----------

    /**
     * 读**原始串**（只读、不解析、不留档）。
     *
     * 只给「删档案后回收独占用图」的引用扫描用：壁纸键不在 [TimetableSettings]
     * 的 4 键里，仓储快照也拿不到。JSON 读不懂时由调用方负责 fail-safe，本层不替它猜。
     */
    fun rawJson(key: String): String? = store.getString(key)

    fun loadProfiles(): ProfilesLoadResult {
        val raw = store.getString(KEY_PROFILES)
        if (raw.isNullOrEmpty()) {
            return ProfilesLoadResult(emptyList(), didDrop = false, itemLevelOnlyDrop = false, quarantinedItems = emptyList())
        }
        val decoded = MiniJson.tryParse(raw)
        if (decoded !is List<*>) {
            // 不是数组：整份不可用 → 留档再删（Dart _readJsonListPreference:608-623）。
            return ProfilesLoadResult(
                profiles = emptyList(),
                didDrop = true,
                itemLevelOnlyDrop = false,
                quarantinedItems = emptyList(),
                corruptBackupKey = archiveCorrupt(KEY_PROFILES),
            )
        }
        val parsed = TimetableProfile.parseProfilesPayload(decoded)
        if (parsed.profiles.isEmpty() && decoded.isNotEmpty()) {
            // 一条都救不回来 = 顶层全损：只有这时才删 key（Dart :1189-1201）。
            return ProfilesLoadResult(
                profiles = emptyList(),
                didDrop = true,
                itemLevelOnlyDrop = false,
                quarantinedItems = emptyList(),
                corruptBackupKey = archiveCorrupt(KEY_PROFILES),
            )
        }
        // 坏条目一律先留档再返回（Dart storage_service.dart:1102-1103 同口径）：
        // 只要还有可用档案、且确有条目被丢弃，就把原始条目写进滚动 key。
        // 与 Dart 一致地**不写回**清洗结果——写回等于把「解析器读不懂」变成永久删除。
        if (parsed.didDrop && parsed.profiles.isNotEmpty()) {
            archiveUnparsedProfileItems(parsed.quarantinedItems)
        }
        return ProfilesLoadResult(
            profiles = parsed.profiles,
            didDrop = parsed.didDrop,
            itemLevelOnlyDrop = parsed.hasItemLevelOnlyDrops,
            quarantinedItems = parsed.quarantinedItems,
        )
    }

    /**
     * 把条目级坏数据留档到**单个滚动 key** `timetable_profiles_unparsed_items`
     * （Dart `_archiveUnparsedProfileItems`，storage_service.dart:1136-1150 同口径）。
     *
     * 覆盖写、不按次追加 `*_corrupt_backup_<ts>`：条目级损坏每次冷启动都会重现，
     * 追加会把留档本身长成新的存储问题。留档写失败不阻断读取——坏条目已进不了
     * 内存视图，这里只是尽力保留找回的可能（与 Dart 的 try/catch 同口径）。
     */
    private fun archiveUnparsedProfileItems(items: List<String>) {
        if (items.isEmpty()) return
        try {
            val payload = MiniJson.encode(
                linkedMapOf<String, Any>(
                    "archivedAt" to LocalDateTime.now().toString(),
                    "count" to items.size,
                    "items" to items,
                ),
            )
            store.putString(KEY_PROFILES_UNPARSED_ITEMS, payload)
        } catch (error: Exception) {
            error.printStackTrace()
        }
    }

    /** 写全量档案数组并盖 schema 版本章（Dart `_writeProfilesWithoutLock:1216-1226`）。 */
    fun saveProfiles(profiles: List<TimetableProfile>) {
        // ⚠️ `TimetableProfile.toJson()` 里的 `settings` 只有 core 4 键
        // （`TimetableSettings.toJson`），而盘上每份档案的 `settings` 是**完整**的
        // 250+ 键对象（Dart 每个档案内嵌整份 `TimetableSettings`）。直接整体重写会把
        // 其余键（含桌面小组件那 10 个）从档案里冲掉 ⇒ 桌面卡片读到的设置全部回默认。
        // 所以按 id 取旧 `settings` 铺底、再用新值覆盖（同键以新值为准），其余键保留。
        // 读不到旧数据（首次写入 / 坏 JSON）时行为与之前完全一致。
        val previousSettings = previousEmbeddedSettingsById()
        val payload = profiles.map { profile ->
            val json = profile.toJson()
            val old = previousSettings[profile.id]
            if (old == null) {
                json
            } else {
                val merged = LinkedHashMap<String, Any?>(old)
                val fresh = json["settings"]
                if (fresh is Map<*, *>) {
                    for ((key, value) in fresh) {
                        if (key is String) merged[key] = value
                    }
                }
                val out = LinkedHashMap(json)
                out["settings"] = merged
                out
            }
        }
        store.putString(KEY_PROFILES, MiniJson.encode(payload))
        stampProfilesSchemaVersion()
    }

    /**
     * 盘上每份档案**内嵌**的 `settings` 原始对象（id → 键值表）。
     *
     * 只用于 [saveProfiles] 的「铺底」；整份不是数组、条目不是对象、没有字符串 id
     * 一律跳过（与 [loadProfiles] 的宽松口径一致，读不懂就当没有旧值）。
     */
    private fun previousEmbeddedSettingsById(): Map<String, Map<String, Any?>> {
        val raw = store.getString(KEY_PROFILES)
        if (raw.isNullOrEmpty()) return emptyMap()
        val decoded = MiniJson.tryParse(raw)
        if (decoded !is List<*>) return emptyMap()
        val out = LinkedHashMap<String, Map<String, Any?>>()
        for (item in decoded) {
            if (item !is Map<*, *>) continue
            val id = item["id"] as? String ?: continue
            val settings = item["settings"]
            if (settings !is Map<*, *>) continue
            val copy = LinkedHashMap<String, Any?>()
            for ((key, value) in settings) {
                if (key is String) copy[key] = value
            }
            out[id] = copy
        }
        return out
    }

    /** 写后盖章（幂等）：盘上值已是 1 就不写，避免每次保存的写放大（Dart :1228-1235）。 */
    fun stampProfilesSchemaVersion() {
        if (store.getInt(KEY_PROFILES_SCHEMA_VERSION, 0) != PROFILES_SCHEMA_VERSION) {
            store.putInt(KEY_PROFILES_SCHEMA_VERSION, PROFILES_SCHEMA_VERSION)
        }
    }

    /** 盘上的 schema 版本；键不存在返回 0（Dart `getProfilesSchemaVersion`）。 */
    fun profilesSchemaVersion(): Int = store.getInt(KEY_PROFILES_SCHEMA_VERSION, 0)

    // ---------- active_timetable_profile_id ----------

    fun loadActiveProfileId(): String? = store.getString(KEY_ACTIVE_PROFILE_ID)

    fun saveActiveProfileId(profileId: String?) {
        if (profileId == null) store.remove(KEY_ACTIVE_PROFILE_ID) else store.putString(KEY_ACTIVE_PROFILE_ID, profileId)
    }

    // ---------- timetable_settings ----------

    fun loadSettings(): TimetableSettings {
        val raw = store.getString(KEY_SETTINGS)
        if (raw.isNullOrEmpty()) return TimetableSettings.defaults()
        val decoded = MiniJson.tryParse(raw)
        if (decoded !is Map<*, *>) {
            archiveCorrupt(KEY_SETTINGS)
            return TimetableSettings.defaults()
        }
        return try {
            @Suppress("UNCHECKED_CAST")
            TimetableSettings.fromJson(decoded as Map<String, Any?>)
        } catch (_: Exception) {
            archiveCorrupt(KEY_SETTINGS)
            TimetableSettings.defaults()
        }
    }

    /**
     * 盘上 `timetable_settings` 的**原始 JSON 对象**（不做模型解析）。
     *
     * 供设置族完整模型 [TimetableSettingsModel] 按自己的口径读——那层认识几十个键，
     * 本层只认识 4 个。坏值同样留档 + 删 key，返回空 map。
     */
    fun loadSettingsJson(): Map<String, Any?> {
        val raw = store.getString(KEY_SETTINGS)
        if (raw.isNullOrEmpty()) return emptyMap()
        val decoded = MiniJson.tryParse(raw)
        if (decoded !is Map<*, *>) {
            archiveCorrupt(KEY_SETTINGS)
            return emptyMap()
        }
        val out = LinkedHashMap<String, Any?>()
        for ((key, value) in decoded) {
            if (key is String) out[key] = value
        }
        return out
    }

    /**
     * **读-合并-写**：只覆盖 [patch] 里出现的键，盘上其余键（Dart 侧 250+ 个）原样保留。
     *
     * 这是全仓唯一一份 `timetable_settings` 合并写实现——[saveSettings]（core 键子集）
     * 与设置族完整模型都走这里。合并逻辑若有两份，「测试用的那份」就会比真实现宽松。
     *
     * ⚠️ 与 Dart `toJson()` **整体覆盖**的一处必要差异：Dart 对 null 值的键是**省略**
     * （省略即删除）；合并写下「省略」等于「保留旧值」，所以这里把 `null` **显式写进
     * JSON**。两者对读侧等价（Dart 的 `lenientXxx(null) ?? 默认值` 与
     * `parseNestedObject` 都把 null 当缺键），但只有显式 null 才能真正清掉一个键。
     */
    fun saveSettingsPatch(patch: Map<String, Any?>) {
        if (patch.isEmpty()) return
        val merged = LinkedHashMap<String, Any?>()
        merged.putAll(loadSettingsJson())
        merged.putAll(patch)
        store.putString(KEY_SETTINGS, MiniJson.encode(merged))
    }

    /**
     * **合并写**：保留盘上 JSON 里本层不认识的键（Dart 侧 250+ 字段），
     * 只覆盖本层拥有的那几个。见类注释「设置为什么是合并不是整体覆盖」。
     */
    fun saveSettings(settings: TimetableSettings) {
        saveSettingsPatch(settings.toJson())
    }

    /**
     * 把 [patch] 合并进**当前档案内嵌的 `settings`**（`timetable_profiles[i].settings`）。
     *
     * ## 为什么需要这一处
     *
     * 桌面小组件（今日课程卡 / 统计卡 / 考试卡）的渲染读的是 **active profile 内嵌的
     * `settings` 对象**（`TodayWidgetSupport.buildSnapshotFromFlutterState` 的
     * `profile.optJSONObject("settings")`，`TodayWidgetSupport.kt:262`），
     * 不是顶层 `timetable_settings`。Dart 的 `updateTimetableSettings` 会把整份 settings
     * 写回档案（`lib/providers/timetable_provider.dart:3036-3070` →
     * `_persistActiveProfileState`）。
     * 只写顶层 = 设置页看着改了、桌面卡片纹丝不动。
     *
     * ## 口径（与 Dart 保存路径对齐）
     *
     * - 目标档案：`active_timetable_profile_id` 命中的那份；**找不到（或没有 active id）
     *   时用数组第一个档案对象**（Dart 的 `_persistActiveProfileState` 写的就是 active）。
     * - 只动那份档案的 `settings`：其它档案、其它键（courses / exams / id / name …）原样保留。
     * - **解析失败什么都不做**（不删数据、不留档）——这份数据仍可能被 Dart 侧读走，
     *   这里没有「损坏自愈」的语义。
     */
    fun saveSettingsPatchToActiveProfile(patch: Map<String, Any?>) {
        if (patch.isEmpty()) return
        val raw = store.getString(KEY_PROFILES)
        if (raw.isNullOrEmpty()) return
        val decoded = MiniJson.tryParse(raw)
        if (decoded !is List<*> || decoded.isEmpty()) return

        // 逐条转成可变副本：MiniJson 解出来的 map 只保证是 LinkedHashMap，
        // 但就地改「别人传进来的树」不是本层的风格，也不该依赖可变性假设。
        val items = decoded.map { item ->
            if (item is Map<*, *>) {
                val copy = LinkedHashMap<String, Any?>()
                for ((key, value) in item) {
                    if (key is String) copy[key] = value
                }
                copy
            } else {
                item
            }
        }
        val activeId = loadActiveProfileId()
        val activeIndex = if (activeId == null) {
            -1
        } else {
            items.indexOfFirst { it is Map<*, *> && it["id"] == activeId }
        }
        val targetIndex = if (activeIndex >= 0) {
            activeIndex
        } else {
            items.indexOfFirst { it is Map<*, *> }
        }
        if (targetIndex < 0) return
        @Suppress("UNCHECKED_CAST")
        val target = items[targetIndex] as LinkedHashMap<String, Any?>

        val merged = LinkedHashMap<String, Any?>()
        val oldSettings = target["settings"]
        if (oldSettings is Map<*, *>) {
            for ((key, value) in oldSettings) {
                if (key is String) merged[key] = value
            }
        }
        merged.putAll(patch)
        target["settings"] = merged

        store.putString(KEY_PROFILES, MiniJson.encode(items))
        stampProfilesSchemaVersion()
    }

    // ---------- current_week ----------

    /** 键不存在返回 null（与「显式存了 0」区分开）。 */
    fun loadCurrentWeek(): Int? =
        if (store.contains(KEY_CURRENT_WEEK)) store.getInt(KEY_CURRENT_WEEK, 0) else null

    fun saveCurrentWeek(week: Int) {
        store.putInt(KEY_CURRENT_WEEK, week)
    }

    // ---------- time_schemes ----------

    fun loadTimeSchemes(): TimeSchemesLoadResult {
        val raw = store.getString(KEY_TIME_SCHEMES)
        if (raw.isNullOrEmpty()) return TimeSchemesLoadResult(emptyList())
        val decoded = MiniJson.tryParse(raw)
        if (decoded !is List<*>) {
            return TimeSchemesLoadResult(emptyList(), archiveCorrupt(KEY_TIME_SCHEMES))
        }
        val schemes = mutableListOf<TimeScheme>()
        for (item in decoded) {
            if (item !is Map<*, *>) continue
            try {
                @Suppress("UNCHECKED_CAST")
                schemes.add(TimeScheme.fromJson(item as Map<String, Any?>))
            } catch (_: Exception) {
                // 单条坏方案丢掉，不让它炸掉整份（与 profiles 的 lenient 口径一致）。
            }
        }
        if (schemes.isEmpty() && decoded.isNotEmpty()) {
            return TimeSchemesLoadResult(emptyList(), archiveCorrupt(KEY_TIME_SCHEMES))
        }
        return TimeSchemesLoadResult(schemes)
    }

    fun saveTimeSchemes(schemes: List<TimeScheme>) {
        store.putString(KEY_TIME_SCHEMES, MiniJson.encode(schemes.map { it.toJson() }))
    }

    // ---------- schedule_date_rules ----------

    /**
     * 作息日期规则数组（数据契约 §2.1 `schedule_date_rules`，String(JSON) 数组）。
     *
     * 这是**顶层 key**（不属于某个档案）。逐条宽松解析：坏条目丢弃，不让一条坏规则炸掉整份；
     * 整份不是数组时留档 + 删 key（与 profiles 同口径，坏数据不静默吞）。
     */
    fun loadScheduleDateRules(): List<ScheduleDateRule> {
        val raw = store.getString(KEY_SCHEDULE_DATE_RULES)
        if (raw.isNullOrEmpty()) return emptyList()
        val decoded = MiniJson.tryParse(raw)
        if (decoded !is List<*>) {
            archiveCorrupt(KEY_SCHEDULE_DATE_RULES)
            return emptyList()
        }
        val rules = mutableListOf<ScheduleDateRule>()
        for (item in decoded) {
            if (item !is Map<*, *>) continue
            try {
                @Suppress("UNCHECKED_CAST")
                rules.add(ScheduleDateRule.fromJson(item as Map<String, Any?>))
            } catch (_: Exception) {
                // 单条坏规则丢弃（lenient 口径）。
            }
        }
        return rules
    }

    fun saveScheduleDateRules(rules: List<ScheduleDateRule>) {
        store.putString(KEY_SCHEDULE_DATE_RULES, MiniJson.encode(rules.map { it.toJson() }))
    }

    // ---------- location_time_groups ----------

    /**
     * 地点作息分组数组（数据契约 §2.1 `location_time_groups`，String(JSON) 数组；
     * 键名与 Dart `storage_service.dart:25` 同名）。
     *
     * 逐条宽松解析：坏条目丢弃，不让一条坏分组炸掉整份；整份不是数组时
     * 留档 + 删 key（与 [loadScheduleDateRules] 同口径，坏数据不静默吞）。
     *
     * 为什么这一层也要有它：删除/应用时间模板的拦截判据要用地点分组
     * （绑定了该模板的分组会阻止删除），而 1.6 的快照字段就是从这里读的。
     */
    fun loadLocationTimeGroups(): List<LocationTimeGroup> {
        val raw = store.getString(KEY_LOCATION_TIME_GROUPS)
        if (raw.isNullOrEmpty()) return emptyList()
        val decoded = MiniJson.tryParse(raw)
        if (decoded !is List<*>) {
            archiveCorrupt(KEY_LOCATION_TIME_GROUPS)
            return emptyList()
        }
        val groups = mutableListOf<LocationTimeGroup>()
        for (item in decoded) {
            if (item !is Map<*, *>) continue
            try {
                @Suppress("UNCHECKED_CAST")
                groups.add(LocationTimeGroup.fromJson(item as Map<String, Any?>))
            } catch (_: Exception) {
                // 单条坏分组丢弃（lenient 口径）。
            }
        }
        return groups
    }

    fun saveLocationTimeGroups(groups: List<LocationTimeGroup>) {
        store.putString(KEY_LOCATION_TIME_GROUPS, MiniJson.encode(groups.map { it.toJsonMap() }))
    }

    // ---------- teacher_records / location_records（List<String>） ----------

    /**
     * 读 `List<String>`。
     *
     * [KeyValueStore.getStringList] 解码失败会**抛**（接口硬要求）。这里在边界上
     * 把它接住并**留档**——注意是留档后返回空列表，不是「静默当空」：
     * 坏值被移出原 key 并留下备份，下次写路径不会拿空列表覆盖掉一份可救的数据。
     */
    fun loadTeacherRecords(): List<String> = loadStringListLenient(KEY_TEACHER_RECORDS)

    fun saveTeacherRecords(records: List<String>) {
        store.putStringList(KEY_TEACHER_RECORDS, records)
    }

    fun loadLocationRecords(): List<String> = loadStringListLenient(KEY_LOCATION_RECORDS)

    fun saveLocationRecords(records: List<String>) {
        store.putStringList(KEY_LOCATION_RECORDS, records)
    }

    private fun loadStringListLenient(key: String): List<String> {
        if (!store.contains(key)) return emptyList()
        return try {
            store.getStringList(key) ?: emptyList()
        } catch (_: Exception) {
            archiveCorrupt(key)
            emptyList()
        }
    }

    // ---------- 留档 ----------

    /**
     * 留档 + 删原 key + 清扫旧留档；返回本次留档用的**契约 key**。
     * 时间戳由 [nowMicros] 给，便于测试断言留档名。
     *
     * **留档本身写不进去（`IOException`，磁盘满）时不再上抛**：本方法只被 load 侧的
     * 损坏分支调用，抛出去等于「坏数据 + 磁盘满」双重故障下仓储 `init` 直接崩、
     * App 起不来。这里选择继续按「默认值」读（与没有留档机制时同口径），坏值留在盘上，
     * 下一次写路径成功或下次冷启动再补留档——延迟留档不等于丢数据。
     */
    fun archiveCorrupt(key: String): String {
        return try {
            val backupKey = store.archiveCorruptAndRemove(key, nowMicros())
            sweepOldCorruptBackups(key, keepKey = backupKey)
            backupKey
        } catch (error: IOException) {
            error.printStackTrace()
            // 返回「本应写出的留档名」：生产代码不消费这个返回值（只有测试断言成功路径），
            // 失败时给名字只是保持签名语义，不代表盘上真有那份留档。
            corruptBackupKey(key, nowMicros())
        }
    }

    /** 同 key 的旧留档只留最近一份（Dart `_sweepOldCorruptBackups`，:527-553）。 */
    private fun sweepOldCorruptBackups(key: String, keepKey: String) {
        val prefix = "${key}_corrupt_backup_"
        store.keys()
            .filter { it.startsWith(prefix) && it != keepKey }
            .forEach { store.remove(it) }
    }

    companion object {
        const val KEY_PROFILES = "timetable_profiles"
        const val KEY_PROFILES_SCHEMA_VERSION = "timetable_profiles_schema_version"
        const val KEY_ACTIVE_PROFILE_ID = "active_timetable_profile_id"
        const val KEY_SETTINGS = "timetable_settings"
        const val KEY_CURRENT_WEEK = "current_week"
        const val KEY_TIME_SCHEMES = "time_schemes"
        const val KEY_SCHEDULE_DATE_RULES = "schedule_date_rules"
        const val KEY_LOCATION_TIME_GROUPS = "location_time_groups"
        const val KEY_TEACHER_RECORDS = "teacher_records"
        const val KEY_LOCATION_RECORDS = "location_records"

        /** 条目级坏数据滚动留档 key（Dart `_unparsedProfileItemsKey`，storage_service.dart:1127）。 */
        const val KEY_PROFILES_UNPARSED_ITEMS = "timetable_profiles_unparsed_items"

        /** 当前 profiles 存储布局版本（数据契约 §2.1：v1 = 单 key 全量数组）。 */
        const val PROFILES_SCHEMA_VERSION = 1
    }
}
