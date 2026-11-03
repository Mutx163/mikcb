package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.DartFormatException
import com.mutx163.qingyu.core.DartTime
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
 * | `app_global_settings_v1` | String(JSON) | 44 个整机级键的真源（见 [AppGlobalSettingsStore]；档案内嵌只留镜像） |
 * | `current_week` | int | 当前周次 |
 * | `time_schemes` | String(JSON) | 作息方案数组 |
 * | `schedule_date_rules` | String(JSON) | 作息日期规则数组 |
 * | `location_time_groups` | String(JSON) | 地点作息分组数组 |
 * | `teacher_records` / `location_records` | **List<String>** | 教师/地点历史（走 [FrozenValueCodec]） |
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
        /**
         * 需要写回的清洗后数组串：**整条档案**坏掉且没有条目级损失时才有值。
         * 由本层按原始字节切除坏记录生成，其余档案的字节原样保留
         * （Dart `_writeProfilesWithoutLock` 的等价物，:1216-1226）。
         */
        val prunedRawProfiles: String? = null,
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
        // 坏条目一律先留档再交给内存视图（Dart `_archiveUnparsedProfileItems`，:1136-1150）。
        // 不做这一步，条目级损坏在每次冷启动都会重演，而原始字节只活在内存里，
        // 进程一退就永久消失——这正是 Dart 侧最在意的「丢课要能找回」。
        archiveUnparsedItems(parsed.quarantinedItems)
        // D1：整条档案坏掉（profile 级）且没有条目级损失 → 生成「按原始字节切除坏记录」
        // 的清洗结果，交由仓储在持锁写回（坏记录已在上一行留档）。
        // 条目级坏条目**一律不写回**：能救的条目（下次解析器修好就能读）绝不删除。
        val prunedRaw = if (
            parsed.stats.hasProfileLevelDrops && !parsed.stats.hasItemLevelDrops
        ) {
            pruneTopLevelJsonItems(raw, parsed.droppedProfileIndices.toSet())
        } else {
            null
        }
        return ProfilesLoadResult(
            profiles = parsed.profiles,
            didDrop = parsed.didDrop,
            itemLevelOnlyDrop = parsed.hasItemLevelOnlyDrops,
            quarantinedItems = parsed.quarantinedItems,
            prunedRawProfiles = prunedRaw,
        )
    }

    /**
     * 按原始字节切除顶层数组里的坏档案（[dropIndices] 为下标）。
     *
     * 只做「切片 + 重新加分隔符」，保留的条目**逐字节不变**——不能用
     * [MiniJson.encode] 重编：那会把档案内嵌的完整 settings 等不属于本层
     * 的键/数值格式一并改写（数据冻结区不许这么干）。
     * 任何无法安全解析的结构（非数组、字符串未闭合、下标越界）一律返回 null，
     * 调用方放弃写回，宁可不修也不破坏。
     */
    fun pruneTopLevelJsonItems(raw: String, dropIndices: Set<Int>): String? {
        if (dropIndices.isEmpty()) return null
        val items = splitTopLevelArrayItems(raw) ?: return null
        if (dropIndices.any { it !in items.indices }) return null
        val kept = items.filterIndexed { index, _ -> index !in dropIndices }
        if (kept.isEmpty()) return null
        return kept.joinToString(",", prefix = "[", postfix = "]")
    }

    /** 把顶层 JSON 数组切成「每个元素的原文字节」；结构不合法返回 null。 */
    private fun splitTopLevelArrayItems(raw: String): List<String>? {
        var i = 0
        fun skipWs() {
            while (i < raw.length && raw[i].isWhitespace()) i++
        }
        skipWs()
        if (i >= raw.length || raw[i] != '[') return null
        i++
        skipWs()
        if (i < raw.length && raw[i] == ']') {
            i++
            skipWs()
            return if (i >= raw.length) emptyList() else null
        }
        val out = mutableListOf<String>()
        while (true) {
            skipWs()
            val start = i
            i = scanValueEnd(raw, i) ?: return null
            val text = raw.substring(start, i).trimEnd()
            if (text.isEmpty()) return null
            out.add(text)
            skipWs()
            if (i >= raw.length) return null
            when (raw[i]) {
                ',' -> i++
                ']' -> {
                    i++
                    skipWs()
                    return if (i >= raw.length) out else null
                }
                else -> return null
            }
        }
    }

    /** 扫描一个 JSON 值的结尾（返回下标后一位）；不合法返回 null。 */
    private fun scanValueEnd(raw: String, start: Int): Int? {
        if (start >= raw.length) return null
        return when (raw[start]) {
            '"' -> scanStringEnd(raw, start)
            '{', '[' -> scanContainerEnd(raw, start)
            else -> {
                var i = start
                while (i < raw.length && raw[i] != ',' && raw[i] != ']' && !raw[i].isWhitespace()) i++
                if (i == start) null else i
            }
        }
    }

    private fun scanStringEnd(raw: String, start: Int): Int? {
        var i = start + 1
        while (i < raw.length) {
            when (raw[i]) {
                '\\' -> i += 2
                '"' -> return i + 1
                else -> i++
            }
        }
        return null
    }

    private fun scanContainerEnd(raw: String, start: Int): Int? {
        var depth = 0
        var i = start
        while (i < raw.length) {
            when (raw[i]) {
                '"' -> {
                    i = scanStringEnd(raw, i) ?: return null
                    continue
                }
                '{', '[' -> depth++
                '}', ']' -> {
                    depth--
                    if (depth == 0) return i + 1
                }
            }
            i++
        }
        return null
    }


    /**
     * 把解析失败的原始条目留档到**单个滚动 key**（覆盖写，Dart :1136-1150 同口径）。
     *
     * 不追加 `*_corrupt_backup_<ts>`：条目级损坏每次冷启动都重现（本层刻意不把
     * 清洗结果写回盘），追加会让留档自己长成新的存储问题。
     */
    private fun archiveUnparsedItems(
        items: List<String>,
        key: String = KEY_PROFILES_UNPARSED_ITEMS,
    ) {
        if (items.isEmpty()) return
        try {
            store.putString(
                key,
                MiniJson.encode(
                    linkedMapOf(
                        "archivedAt" to DartTime.toIso(LocalDateTime.now()),
                        "count" to items.size,
                        "items" to items,
                    ),
                ),
            )
        } catch (_: Exception) {
            // 留档失败不阻断启动：坏条目本就进不了内存视图，这里只是尽力保留找回的可能。
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
     * 写回**已经清洗好的原始数组串**（[pruneTopLevelJsonItems] 的产物）。
     *
     * 与 [saveProfiles] 的区别：这里不经过模型编解码，保留条目逐字节不变，
     * 因此不会动档案内嵌的完整 settings。只在整条档案坏掉时使用。
     */
    fun saveRawProfiles(raw: String) {
        store.putString(KEY_PROFILES, raw)
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

    // ---------- 旧 courses 通道一次性迁移（bootstrap） ----------

    /** 迁移结果：只用于日志/测试断言，不参与业务分支（幂等靠 marker）。 */
    data class LegacyBootstrapResult(
        val bootstrapped: Boolean,
        val skippedReason: String? = null,
        val profile: TimetableProfile? = null,
        val importedCourses: Int = 0,
        val quarantinedCourses: Int = 0,
    )

    /**
     * 旧 `courses` 通道的一次性迁移（Dart `_doEnsureProfilesInitialized:1637-1651`）。
     *
     * 触发条件：`timetable_profiles` 还没有可用档案（[currentProfilesEmpty]）且旧
     * `courses` 非空。迁移内容：
     * - 好条目 → 新建「默认课表」档案的 courses；
     * - 坏条目 → `courses_unparsed_items` **先留档**（Dart `_quarantineDroppedCourseEntry:711`）；
     * - 顶层 `timetable_settings` + `semester_start` + `current_week` → 档案内嵌 settings / 周次。
     *
     * **幂等**：成功后写 `compose_bootstrap_migrated_v1`；已有档案或 marker 在 ⇒ 不跑。
     * **不覆盖**：盘上档案数组非空时直接跳过（解析失败但留档也失败时 Dart 保留原 key，绝不覆盖）。
     */
    @Synchronized
    fun bootstrapLegacyProfileIfNeeded(currentProfilesEmpty: Boolean): LegacyBootstrapResult {
        if (store.getBool(KEY_BOOTSTRAP_MIGRATED, false)) {
            return LegacyBootstrapResult(bootstrapped = false, skippedReason = "already_migrated")
        }
        if (!currentProfilesEmpty || !store.getString(KEY_PROFILES).isNullOrEmpty()) {
            return LegacyBootstrapResult(bootstrapped = false, skippedReason = "profiles_present")
        }
        val legacyCourses = try {
            store.getStringList(KEY_LEGACY_COURSES) ?: emptyList()
        } catch (_: Exception) {
            archiveCorrupt(KEY_LEGACY_COURSES)
            emptyList()
        }
        if (legacyCourses.isEmpty()) {
            return LegacyBootstrapResult(bootstrapped = false, skippedReason = "no_legacy_courses")
        }

        val courses = mutableListOf<Course>()
        val quarantined = mutableListOf<String>()
        for (rawCourse in legacyCourses) {
            val parsed = try {
                val decoded = MiniJson.parse(rawCourse)
                if (decoded !is Map<*, *>) throw DartFormatException("course json must be an object")
                @Suppress("UNCHECKED_CAST")
                Course.fromJson(decoded as Map<String, Any?>)
            } catch (_: Exception) {
                null
            }
            if (parsed != null) courses.add(parsed) else quarantineCourseEntry(quarantined, rawCourse)
        }
        // 先留档再覆盖：坏条目全部进隔离档（整份 key 保留，Dart 刻意不写回原始列表）。
        archiveUnparsedItems(quarantined, KEY_COURSES_UNPARSED_ITEMS)
        if (courses.isEmpty()) {
            // 全坏：Dart 把整份 key 留档再删（:672-674）；这里不建空档案。
            archiveCorrupt(KEY_LEGACY_COURSES)
            return LegacyBootstrapResult(
                bootstrapped = false,
                skippedReason = "no_parsable_courses",
                quarantinedCourses = quarantined.size,
            )
        }

        val legacySettingsJson = readLegacyTopLevelSettingsJson()
        val legacySettings = try {
            TimetableSettings.fromJson(legacySettingsJson)
        } catch (_: Exception) {
            TimetableSettings.defaults()
        }
        val semesterStartMillis = if (store.contains(KEY_SEMESTER_START)) {
            store.getLong(KEY_SEMESTER_START, 0L)
        } else {
            null
        }
        // Dart :1639-1642：旧 `semester_start` 只在 settings 里没有开学日时才补进档案。
        val migratedSettings = if (semesterStartMillis != null && legacySettings.semesterStartDate == null) {
            legacySettings.copy(semesterStartDate = DartTime.fromEpochMillis(semesterStartMillis))
        } else {
            legacySettings
        }
        val now = LocalDateTime.now()
        val profile = TimetableProfile(
            id = "profile-${nowMicros()}",
            name = TimetableHostLogic.DEFAULT_PROFILE_NAME,
            courses = courses,
            settings = migratedSettings,
            currentWeek = (loadCurrentWeek() ?: 1).toLong(),
            createdAt = now,
            lastUsedAt = now,
        )
        return try {
            saveBootstrapProfile(profile, legacySettingsJson)
            saveActiveProfileId(profile.id)
            store.putBool(KEY_BOOTSTRAP_MIGRATED, true)
            LegacyBootstrapResult(
                bootstrapped = true,
                profile = profile,
                importedCourses = courses.size,
                quarantinedCourses = quarantined.size,
            )
        } catch (_: Exception) {
            // 写失败不盖 marker：下次启动重试（与 Dart :1653-1663 的 deferred 同口径）。
            LegacyBootstrapResult(
                bootstrapped = false,
                skippedReason = "write_failed",
                quarantinedCourses = quarantined.size,
            )
        }
    }

    /**
     * 写一条 bootstrap 档案：`settings` 用**顶层旧设置全量对象**铺底、core 4 键收口。
     *
     * 不能走 [saveProfiles]：它按 id 取旧 settings 铺底，新 id 没有旧值，只会落 core 4 键，
     * 用户 Dart 侧那 250+ 个设置键会在迁移这一步被抹掉。
     */
    private fun saveBootstrapProfile(profile: TimetableProfile, embeddedSettings: Map<String, Any?>) {
        val settings = LinkedHashMap<String, Any?>()
        settings.putAll(embeddedSettings)
        settings.putAll(profile.settings.toJson())
        val payload = LinkedHashMap<String, Any?>(profile.toJson())
        payload["settings"] = settings
        store.putString(KEY_PROFILES, MiniJson.encode(listOf(payload)))
        stampProfilesSchemaVersion()
    }

    /** Dart `_quarantineDroppedCourseEntry:711-734`：原始条目编码成 JSON 字符串字面量，封顶 50 条 / 4096 字符。 */
    private fun quarantineCourseEntry(sink: MutableList<String>, raw: String) {
        if (sink.size >= COURSES_MAX_QUARANTINED_ITEMS) return
        var encoded = MiniJson.encode(raw)
        if (encoded.length > COURSES_MAX_QUARANTINED_ITEM_CHARS) {
            encoded = encoded.substring(0, COURSES_MAX_QUARANTINED_ITEM_CHARS) + "…<truncated>"
        }
        sink.add(encoded)
    }

    // ---------- timetable_settings ----------

    /**
     * **settings 单一真源**：活动档案内嵌 `settings`（Dart `TimetableProfile.settings`）。
     *
     * 顶层 `timetable_settings` 在 Dart 侧是**旧世界镜像**：唯一写点
     * `storage_service.dart:817-820` 无调用方，profile 化后设置只写档案内嵌
     * （`timetable_provider.dart:1499-1510`）。读它 = 读到迁移前的旧值。
     *
     * 只有「盘上还没有档案」这一种状态（= bootstrap 前）才回落顶层：
     * 那正是 Dart `_doEnsureProfilesInitialized` 组装默认档案时读的同一份数据
     * （`storage_service.dart:1637`）。
     */
    @Synchronized
    fun loadSettings(): TimetableSettings {
        val json = readActiveEmbeddedSettingsJson() ?: readLegacyTopLevelSettingsJson()
        if (json.isEmpty()) return TimetableSettings.defaults()
        return try {
            TimetableSettings.fromJson(json)
        } catch (_: Exception) {
            TimetableSettings.defaults()
        }
    }

    /** 旧世界顶层 `timetable_settings`；坏值留档 + 删 key，返回空 map。 */
    private fun readLegacyTopLevelSettingsJson(): Map<String, Any?> {
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
     * 活动档案内嵌的 `settings`；`null` 仅表示「盘上还没有档案数组」。
     *
     * 档案存在但没带 `settings` 时返回**空 map**（不回落顶层）：一旦有档案，
     * 顶层就只剩镜像身份，读取永不走它。
     */
    private fun readActiveEmbeddedSettingsJson(): Map<String, Any?>? {
        val raw = store.getString(KEY_PROFILES)
        if (raw.isNullOrEmpty()) return null
        val decoded = MiniJson.tryParse(raw)
        if (decoded !is List<*> || decoded.isEmpty()) return null
        val activeId = loadActiveProfileId()
        val target = if (activeId == null) {
            null
        } else {
            decoded.firstOrNull { it is Map<*, *> && it["id"] == activeId }
        } ?: decoded.firstOrNull { it is Map<*, *> } ?: return emptyMap()
        val settings = (target as Map<*, *>)["settings"]
        if (settings !is Map<*, *>) return emptyMap()
        val out = LinkedHashMap<String, Any?>()
        for ((key, value) in settings) {
            if (key is String) out[key] = value
        }
        return out
    }

    /**
     * 盘上**活动档案内嵌** `settings` 的原始 JSON 对象（不做模型解析）。
     *
     * 供设置族完整模型 [TimetableSettingsModel] 按自己的口径读——那层认识几十个键，
     * 本层只认识 4 个。没有档案时回落到顶层旧镜像（**仅 bootstrap 前**，见 [loadSettings]）。
     */
    @Synchronized
    fun loadSettingsJson(): Map<String, Any?> {
        val embedded = readActiveEmbeddedSettingsJson() ?: readLegacyTopLevelSettingsJson()
        // 44 个整机级键以全局那份为准，逐个覆盖档案内嵌同名键（值为 null 也覆盖，
        // 才能表达「已清空」）。少了这一层，切档就会连带换掉主题/字体/语言/材质/导航，
        // 正是 Dart 2026-09-22 明确否掉的行为（app_global_settings_service.dart:140-149）。
        return globalSettings.overlay(embedded, globalSettings.ensureInitialized())
    }

    /**
     * 整机级全局设置（44 键，见 [AppGlobalSettingsStore]）。
     *
     * 播种源与 Dart `_pickSourceProfile` / `resolveInitial` 同口径：**活动档案内嵌**
     * 优先；盘上还没有档案（bootstrap 前）时回落顶层旧镜像；两者都没有就不播种。
     */
    private val globalSettings = AppGlobalSettingsStore(store) {
        readActiveEmbeddedSettingsJson()
            ?: readLegacyTopLevelSettingsJson().takeIf { it.isNotEmpty() }
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
    @Synchronized
    fun saveSettingsPatch(patch: Map<String, Any?>) {
        if (patch.isEmpty()) return
        // 整机级键分拣（44 键）：先写全局那份（真源、不随切档变化），再与其余键一起
        // 镜像进活动档案内嵌与顶层。镜像不是多余——Dart 备份 payload 只序列化 profiles，
        // 全局键在档案里不留一份，备份 → 换机 → 恢复就会整组丢掉。
        // 读侧优先级见 [loadSettingsJson]（全局覆盖档案同名键）。
        // 读-合并-写必须整体持锁（@Synchronized）：设置页模型、灵动显示、局域网导入
        // 三路写入共用本实例，不持锁时两次并发 patch 会读到同一份旧值、后写覆盖先写。
        val (globalPatch, _) = globalSettings.split(patch)
        if (globalPatch.isNotEmpty()) {
            // 整机级真源：先合并进全局那份（缺数据时按 Dart 口径从活动档案播种）。
            val next = LinkedHashMap<String, Any?>()
            next.putAll(globalSettings.ensureInitialized())
            next.putAll(globalPatch)
            globalSettings.save(next)
        }
        applySettingsPatchToActiveProfile(patch)
        val mirrored = LinkedHashMap<String, Any?>()
        mirrored.putAll(readLegacyTopLevelSettingsJson())
        mirrored.putAll(patch)
        store.putString(KEY_SETTINGS, MiniJson.encode(mirrored))
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
    @Synchronized
    fun saveSettingsPatchToActiveProfile(patch: Map<String, Any?>) {
        applySettingsPatchToActiveProfile(patch)
    }

    /**
     * [saveSettingsPatchToActiveProfile] 的实现体：只写档案内嵌 settings，不碰顶层。
     * 返回是否真的写入了档案数组（没有档案 / 数组不可用 ⇒ false）。
     */
    private fun applySettingsPatchToActiveProfile(patch: Map<String, Any?>): Boolean {
        if (patch.isEmpty()) return false
        val raw = store.getString(KEY_PROFILES)
        if (raw.isNullOrEmpty()) return false
        val decoded = MiniJson.tryParse(raw)
        if (decoded !is List<*> || decoded.isEmpty()) return false

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
        if (targetIndex < 0) return false
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
        return true
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

        /**
         * 条目级损坏的原始条目留档（单个滚动 key，覆盖写）。
         * 与 Dart `StorageService._unparsedProfileItemsKey` 同名（storage_service.dart:1127）。
         */
        const val KEY_PROFILES_UNPARSED_ITEMS = "timetable_profiles_unparsed_items"
        const val KEY_ACTIVE_PROFILE_ID = "active_timetable_profile_id"
        const val KEY_SETTINGS = "timetable_settings"

        /** 旧世界单 key 课程列表（`List<String>`，每条是 Course JSON）——**只读，迁移用**。 */
        const val KEY_LEGACY_COURSES = "courses"

        /** 旧世界学期开始日（epoch 毫秒，Int 落盘）——只在 bootstrap 时读。 */
        const val KEY_SEMESTER_START = "semester_start"

        /** 旧 `courses` 条目级损坏的隔离留档（与 Dart `coursesUnparsedItemsKey` 同名）。 */
        const val KEY_COURSES_UNPARSED_ITEMS = "courses_unparsed_items"

        /** bootstrap 成功后的幂等标记：存在 ⇒ 迁移已完成，不再组装默认档案。 */
        const val KEY_BOOTSTRAP_MIGRATED = "compose_bootstrap_migrated_v1"

        /** 与 Dart `_coursesMaxQuarantinedItems` / `_coursesMaxQuarantinedItemChars` 同口径。 */
        const val COURSES_MAX_QUARANTINED_ITEMS = 50
        const val COURSES_MAX_QUARANTINED_ITEM_CHARS = 4096
        const val KEY_CURRENT_WEEK = "current_week"
        const val KEY_TIME_SCHEMES = "time_schemes"
        const val KEY_SCHEDULE_DATE_RULES = "schedule_date_rules"
        const val KEY_LOCATION_TIME_GROUPS = "location_time_groups"
        const val KEY_TEACHER_RECORDS = "teacher_records"
        const val KEY_LOCATION_RECORDS = "location_records"

        /** 当前 profiles 存储布局版本（数据契约 §2.1：v1 = 单 key 全量数组）。 */
        const val PROFILES_SCHEMA_VERSION = 1
    }
}
