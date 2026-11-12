package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.MiniJson

/**
 * 整机级「应用偏好」的独立存储（移植自 `lib/services/app_global_settings_service.dart`）。
 *
 * ## 为什么单独一份
 *
 * 这 44 个键（Dart `:59-114`）描述的是**整机偏好**——主题、字体、语言、材质、导航、
 * 更新渠道等；它们跟「哪一份课表」无关。Dart 2026-09-22 明确否掉了「切档顺带换掉
 * 这些偏好」的行为：换档只该换课表自己的数据，不该把用户刚调好的深色主题/日文界面
 * 换成另一份课表里存的值。
 *
 * Kotlin 侧曾经只读「活动档案内嵌的 settings」，等于把这些键降级成「每课表一份」；
 * 本类补的就是缺失的整机级真源。
 *
 * ## 两层键的归属（与 Dart 一致）
 *
 * | 层 | 键 | 角色 |
 * |---|---|---|
 * | 全局 | `app_global_settings_v1` | 44 个全局键的**读写真源** |
 * | 档案 | `timetable_profiles[i].settings` | 其余键的真源；全局键在这里留一份**镜像**，供备份/旧读侧使用 |
 * | 顶层 | `timetable_settings` | 旧世界镜像；仅在没有档案时作为 bootstrap 播种源与回退读源 |
 *
 * 读写口径（Dart `extract` / `overlay` / `resolveInitial`）：
 * - 读：[overlay] 把 44 键**逐个**盖到档案内嵌上（值为 `null` 也盖，才能表达「已清空」）；
 * - 写：调用方按 [split] 分拣，全局键先落本存储，其余落档案内嵌；
 * - 首次：盘上没有可用全局数据时，按 Dart 口径从**活动档案内嵌**播种一次（无档案
 *   时回落顶层 `timetable_settings`），并盖 [KEY_MIGRATED] 标记。
 */
class AppGlobalSettingsStore(
    private val store: KeyValueStore,
    /**
     * 播种源：活动档案内嵌 `settings`；没有档案时回落顶层旧镜像；都没有返回 `null`。
     * 由 [TimetableStore] 注入，避免本类反向依赖档案解析细节。
     */
    private val seedSource: () -> Map<String, Any?>? = { null },
) {

    companion object {
        /** 全局那份的 prefs 键（Dart `preferenceKey`，`app_global_settings_service.dart:45`）。 */
        const val KEY = "app_global_settings_v1"

        /** 「把激活课表那一组字段搬成全局初始值」只做一次的标记（Dart `migratedKey`，`:51`）。 */
        const val KEY_MIGRATED = "app_global_settings_v1_migrated"

        /**
         * 全局字段清单（Dart `keys`，`:59-114`，顺序原样保留）。
         *
         * ⚠️ **这份列表就是契约，也是整机级键的唯一真源**：往里加一个键，那项偏好立刻变成整机级；
         * 改动必须与 Dart 同步，否则两边对「哪些偏好跟课表走」理解不一致。
         *
         * 生产代码只许引用这一份（`TimetableProfilesController` 曾手抄第三份，2026-11-11 已合并；
         * 抄本漂移会让某个键被当成档案级键、按旧镜像写回真源）。
         * `AppGlobalSettingsStoreTest` 里那份 44 键**逐字黄金基线**刻意独立于本表：它就是抓
         * 「本表被误删/误加」的 oracle，不要把它改成引用本表。
         */
        val KEYS: List<String> = listOf(
            // —— 首页与导航 ——
            "homeNavigationForm",
            "glassDockActions",
            "glassDockShowAddButton",
            "glassDockButtonEntryId",
            "glassDockButtonIconName",
            "homeTitleStyle",
            "homeMenuStyle",
            "homeGridMenuActions",
            "glassDockShowDayTab",
            "glassDockShowWeekTab",
            "glassDockShowSettingsTab",
            // —— 材质 ——
            "frostedBlurEnabled",
            "liquidGlassPreset",
            "liquidGlassTuning",
            "liquidGlassTuningDark",
            "linkLiquidGlassTuning",
            "darkGlassBoostEnabled",
            "liquidGlassDockEnabled",
            "courseCardSurfaceStyle",
            "courseCardGlassTuning",
            "courseCardGlassPreset",
            "homeBandGlassMaterial",
            "homePageTimeColumnBlurEnabled",
            // —— 主题与外观 ——
            "appThemeMode",
            "appFontMode",
            "appFontWeight",
            "appTextScale",
            "themeSeedColor",
            "foruiTheme",
            "savedThemes",
            "themeCheckpointName",
            "themeCheckpointConfig",
            // —— 通用 ——
            "appLocaleTag",
            "pageTransitionSpeed",
            "enableHaptics",
            "homePullQuickImportEnabled",
            // —— 应用更新与系统行为 ——
            "liveHideFromRecents",
            "appUpdateDownloadSource",
            "appUpdateDownloadChannel",
            "appUpdateUseSystemDownloader",
            "appUpdateMirrorPreset",
            "appUpdateIncludePrerelease",
            "appUpdateMirrorUrlPrefix",
            "appUpdatePromptEnabled",
        )

        private val KEY_SET: Set<String> = KEYS.toSet()

        /** 只保留整机级键；全量恢复要把「设备级真源」显式写回时用。 */
        fun globalKeysOnly(patch: Map<String, Any?>): Map<String, Any?> =
            patch.filterKeys { key -> key in KEY_SET }

        /**
         * 去掉整机级键，只留「跟着课表走」的设置。
         *
         * 单课表 / 周课表传输不得携带主题、语言、材质这类整机偏好：接收端一旦把它们
         * 写进全局真源，对方设备的偏好会被静默替换，撤销也回不来（2026-11-08 审核 P0）。
         */
        fun stripGlobalKeys(patch: Map<String, Any?>): Map<String, Any?> =
            patch.filterKeys { key -> key !in KEY_SET }
    }

    /** `key` 是否属于 44 个整机级键。 */
    fun isGlobalKey(key: String): Boolean = key in KEY_SET

    /** 盘上那份原始键值；无数据或不是 JSON 对象（坏值）返回 `null`。 */
    fun loadRaw(): Map<String, Any?>? = decode(store.getString(KEY))

    /**
     * 44 键全量视图（缺失键 = `null`，Dart `_tryDecode` 口径）；盘上没有数据返回空 map。
     */
    fun read(): Map<String, Any?> {
        val raw = loadRaw() ?: return emptyMap()
        return fill(raw)
    }

    /**
     * 读取并保证已初始化。
     *
     * 1. 盘上有可用全局数据 → **原样使用**（不重建、不看标记——标记丢失不代表数据作废）；
     * 2. 数据缺失 / 被写坏 → 按 Dart `resolveInitial` 口径从 [seedSource] 播种 + 盖标记
     *    （Dart 对「标记在但数据坏」也是重建，宁可重建也不退回跟随课表）；
     * 3. 连来源都没有（一张课表都没有、顶层也没有）→ 不写盘、不盖标记，下次再试（Dart `:174-179`）。
     */
    @Synchronized
    fun ensureInitialized(): Map<String, Any?> {
        loadRaw()?.let { return fill(it) }
        val source = seedSource() ?: return emptyMap()
        val seeded = fill(source)
        store.putString(KEY, MiniJson.encode(seeded))
        store.putBool(KEY_MIGRATED, true)
        return seeded
    }

    /** 全量写 44 键（调用方负责先与 [read] 合并）。 */
    fun save(values: Map<String, Any?>) {
        store.putString(KEY, MiniJson.encode(fill(values)))
    }

    /**
     * 出口叠加：44 个全局键**逐个**覆盖 [base] 上的同名键，其余键原样保留。
     *
     * 哪怕全局那份某项是 `null` 也要盖（Dart `overlay`，`:140-149`）——否则
     * 「清空」会被档案里的旧值复活。全局为空（还没播种）时原样返回 [base]。
     */
    fun overlay(base: Map<String, Any?>, global: Map<String, Any?>): Map<String, Any?> {
        if (global.isEmpty()) return base
        val out = LinkedHashMap<String, Any?>()
        out.putAll(base)
        for (key in KEYS) out[key] = global[key]
        return out
    }

    /**
     * 入口分拣：全局键走本存储，其余键留给活动档案内嵌。
     *
     * @return (全局 patch, 档案 patch)，两者都保持 patch 的原始顺序。
     */
    fun split(patch: Map<String, Any?>): Pair<Map<String, Any?>, Map<String, Any?>> {
        val global = LinkedHashMap<String, Any?>()
        val profile = LinkedHashMap<String, Any?>()
        for ((key, value) in patch) {
            if (isGlobalKey(key)) global[key] = value else profile[key] = value
        }
        return global to profile
    }

    /** 按 44 键顺序补齐（缺失 = null），保证落盘永远是同构对象。 */
    private fun fill(values: Map<String, Any?>): Map<String, Any?> {
        val out = LinkedHashMap<String, Any?>()
        for (key in KEYS) out[key] = values[key]
        return out
    }

    private fun decode(raw: String?): Map<String, Any?>? {
        if (raw.isNullOrEmpty()) return null
        val decoded = MiniJson.tryParse(raw)
        if (decoded !is Map<*, *>) return null
        val out = LinkedHashMap<String, Any?>()
        for ((key, value) in decoded) {
            if (key is String) out[key] = value
        }
        return out
    }
}
