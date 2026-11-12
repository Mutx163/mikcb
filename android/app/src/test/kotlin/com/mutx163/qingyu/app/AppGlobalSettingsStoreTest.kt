package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 整机级全局设置（`app_global_settings_v1`）的归属、迁移与「切档不换全局偏好」测试。
 *
 * 期望值来自 Dart `lib/services/app_global_settings_service.dart`：
 * - 44 个键（`:59-114`）是**整机级真源**；档案内嵌只是镜像（`:140-149` overlay 覆盖读）；
 * - 首次载入以**激活课表**那份为初始值，只播一次并盖 `app_global_settings_v1_migrated`
 *   （`:162-205`）；标记在但数据坏了也重建（`:159-173`），一张课表都没有则不播、不盖标记（`:174-179`）；
 * - 2026-09-22 的决定：**切档不得改变这些偏好**（`timetable_provider.dart:1119-1123`）。
 */
class AppGlobalSettingsStoreTest {

    // ---------- 结构：键表就是契约 ----------

    /**
     * Dart `keys`（`:59-114`）逐字快照——顺序与内容漂移都必须红。
     *
     * **刻意独立于** [AppGlobalSettingsStore.KEYS]（独立 oracle）：只有「两份独立写出来、
     * 再逐字对拍」才能抓到正本被误删/误加一个键。改成引用正本，正本掉键时这条会跟着一起消失。
     */
    private val dartKeys = listOf(
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
        "appThemeMode",
        "appFontMode",
        "appFontWeight",
        "appTextScale",
        "themeSeedColor",
        "foruiTheme",
        "savedThemes",
        "themeCheckpointName",
        "themeCheckpointConfig",
        "appLocaleTag",
        "pageTransitionSpeed",
        "enableHaptics",
        "homePullQuickImportEnabled",
        "liveHideFromRecents",
        "appUpdateDownloadSource",
        "appUpdateDownloadChannel",
        "appUpdateUseSystemDownloader",
        "appUpdateMirrorPreset",
        "appUpdateIncludePrerelease",
        "appUpdateMirrorUrlPrefix",
        "appUpdatePromptEnabled",
    )

    /** 切档后必须原样保持的五类偏好（主题 / 字体 / 语言 / 材质 / 导航）。 */
    private val fivePreferences = listOf(
        "appThemeMode",
        "appFontMode",
        "appFontWeight",
        "appLocaleTag",
        "courseCardSurfaceStyle",
        "homeNavigationForm",
    )

    @Test
    fun `全局键表与 Dart 的 44 键逐字一致`() {
        assertEquals(44, dartKeys.size)
        assertEquals(dartKeys, AppGlobalSettingsStore.KEYS)
        assertEquals("重复键会让分拣漏写", 44, AppGlobalSettingsStore.KEYS.toSet().size)
    }

    // ---------- 迁移 ----------

    @Test
    fun `首次读盘从活动档案播种一次并盖迁移标记`() {
        val raw = InMemoryKeyValueStore(
            mapOf(
                TimetableStore.KEY_PROFILES to profilesJson(
                    "p1" to mapOf(
                        "appLocaleTag" to "zh_TW",
                        "appThemeMode" to "dark",
                        "legacyOnly" to "keep",
                    ),
                    // 非活动档案的全局值不得被选中（Dart 明确说「不做并集」）。
                    "p2" to mapOf("appLocaleTag" to "ja", "appThemeMode" to "light"),
                ),
                TimetableStore.KEY_ACTIVE_PROFILE_ID to "p1",
            ),
        )
        val store = TimetableStore(raw)

        val merged = store.loadSettingsJson()
        assertEquals("zh_TW", merged["appLocaleTag"])
        assertEquals("dark", merged["appThemeMode"])
        assertEquals("档案里的非全局键原样保留", "keep", merged["legacyOnly"])

        val stored = globalObject(raw)
        assertEquals("全局那份必须只装 44 键", 44, stored.size)
        assertEquals("zh_TW", stored["appLocaleTag"])
        // 激活档案没写过的全局键按 Dart `extract` 口径以 null 落盘。
        assertNull(stored["glassDockShowDayTab"])
        assertTrue(raw.getBool(AppGlobalSettingsStore.KEY_MIGRATED, false))

        // 幂等：第二次读不得重写全局那份。
        val bytes = raw.getString(AppGlobalSettingsStore.KEY)
        store.loadSettingsJson()
        assertEquals(bytes, raw.getString(AppGlobalSettingsStore.KEY))
    }

    @Test
    fun `已有全局数据原样读且不重建`() {
        val original =
            """{"appThemeMode":"light","homeNavigationForm":"glass_dock"}"""
        val raw = InMemoryKeyValueStore(
            mapOf(
                TimetableStore.KEY_PROFILES to profilesJson(
                    "p1" to mapOf("appThemeMode" to "dark", "homeNavigationForm" to "classic"),
                ),
                TimetableStore.KEY_ACTIVE_PROFILE_ID to "p1",
                AppGlobalSettingsStore.KEY to original,
            ),
        )
        val store = TimetableStore(raw)

        val merged = store.loadSettingsJson()
        assertEquals("light", merged["appThemeMode"])
        assertEquals("glass_dock", merged["homeNavigationForm"])
        // 数据在就是真源：不补键、不重建、不看标记（标记缺失也不代表数据作废）。
        assertEquals(original, raw.getString(AppGlobalSettingsStore.KEY))
        assertFalse(raw.contains(AppGlobalSettingsStore.KEY_MIGRATED))
    }

    @Test
    fun `只存在顶层 timetable_settings 的旧盘从顶层播种`() {
        val raw = InMemoryKeyValueStore(
            mapOf(
                TimetableStore.KEY_SETTINGS to
                    """{"semesterWeekCount":18,"appLocaleTag":"ja","homeNavigationForm":"classic"}""",
            ),
        )
        val store = TimetableStore(raw)

        assertEquals("ja", store.loadSettingsJson()["appLocaleTag"])
        assertTrue(raw.contains(AppGlobalSettingsStore.KEY))
        assertTrue(raw.getBool(AppGlobalSettingsStore.KEY_MIGRATED, false))
        // 只播全局键：课表核心键仍留在顶层，不进全局那份。
        assertFalse(globalObject(raw).containsKey("semesterWeekCount"))
    }

    @Test
    fun `一张课表都没有且没有顶层时不播种也不盖标记`() {
        val raw = InMemoryKeyValueStore()
        val store = TimetableStore(raw)

        assertTrue(store.loadSettingsJson().isEmpty())
        assertFalse(raw.contains(AppGlobalSettingsStore.KEY))
        assertFalse(raw.contains(AppGlobalSettingsStore.KEY_MIGRATED))
    }

    @Test
    fun `全局那份被写坏时按活动档案重建`() {
        val raw = InMemoryKeyValueStore(
            mapOf(
                TimetableStore.KEY_PROFILES to profilesJson(
                    "p1" to mapOf("appThemeMode" to "dark"),
                ),
                TimetableStore.KEY_ACTIVE_PROFILE_ID to "p1",
                AppGlobalSettingsStore.KEY to "{broken",
            ),
        )
        val store = TimetableStore(raw)

        assertEquals("dark", store.loadSettingsJson()["appThemeMode"])
        assertTrue("坏值必须被替换成有效对象", globalObject(raw).isNotEmpty())
        assertEquals(44, globalObject(raw).size)
    }

    // ---------- 写入口分拣 ----------

    @Test
    fun `saveSettingsPatch 全局键进全局 store 其余键留在档案与镜像`() {
        val raw = InMemoryKeyValueStore(
            mapOf(
                TimetableStore.KEY_PROFILES to profilesJson(
                    "p1" to mapOf("appThemeMode" to "light"),
                ),
                TimetableStore.KEY_ACTIVE_PROFILE_ID to "p1",
            ),
        )
        val store = TimetableStore(raw)

        store.saveSettingsPatch(
            mapOf(
                "appThemeMode" to "dark",
                "semesterWeekCount" to 20,
                "timetableHomeViewMode" to "day",
            ),
        )

        val global = globalObject(raw)
        assertEquals("dark", global["appThemeMode"])
        assertFalse("非全局键不得进全局那份", global.containsKey("semesterWeekCount"))
        assertFalse(global.containsKey("timetableHomeViewMode"))

        val embedded = embeddedSettings(raw, "p1")
        assertEquals("档案内嵌仍是全量镜像（备份 payload 只序列化 profiles）", "dark", embedded["appThemeMode"])
        assertEquals(20L, (embedded["semesterWeekCount"] as Number).toLong())
        assertEquals("day", embedded["timetableHomeViewMode"])

        val topMirror = MiniJson.tryParse(raw.getString(TimetableStore.KEY_SETTINGS)!!) as Map<*, *>
        assertEquals("dark", topMirror["appThemeMode"])
        assertEquals(20L, (topMirror["semesterWeekCount"] as Number).toLong())
    }

    // ---------- 切档：全局偏好不变 ----------

    @Test
    fun `换档不改变主题字体语言材质导航`() {
        val raw = InMemoryKeyValueStore(
            mapOf(
                TimetableStore.KEY_PROFILES to profilesJson(
                    "p1" to mapOf(
                        "appThemeMode" to "dark",
                        "appFontMode" to "harmony_os",
                        "appFontWeight" to 700,
                        "appLocaleTag" to "zh_TW",
                        "courseCardSurfaceStyle" to "refraction",
                        "homeNavigationForm" to "glass_dock",
                        "semesterWeekCount" to 18,
                    ),
                    "p2" to mapOf(
                        "appThemeMode" to "light",
                        "appFontMode" to "sans_serif",
                        "appFontWeight" to 400,
                        "appLocaleTag" to "ja",
                        "courseCardSurfaceStyle" to "solid",
                        "homeNavigationForm" to "classic",
                        "semesterWeekCount" to 25,
                    ),
                ),
                TimetableStore.KEY_ACTIVE_PROFILE_ID to "p1",
            ),
        )
        val repository = TimetableRepository(TimetableStore(raw))

        val before = repository.readRawSettings()
        assertTrue(repository.setActiveProfile("p2"))
        val after = repository.readRawSettings()

        for (key in fivePreferences) {
            assertEquals("切档不得改变 $key", before[key], after[key])
        }
        // 读模型层同样必须一致（设置页读的就是这条路径）。
        val beforeModel = TimetableSettingsModel.fromJson(before)
        val afterModel = TimetableSettingsModel.fromJson(after)
        assertEquals(beforeModel.appThemeMode, afterModel.appThemeMode)
        assertEquals(beforeModel.appFontMode, afterModel.appFontMode)
        assertEquals(beforeModel.appFontWeight, afterModel.appFontWeight)
        assertEquals(beforeModel.appLocaleTag, afterModel.appLocaleTag)
        assertEquals(beforeModel.courseCardSurfaceStyle, afterModel.courseCardSurfaceStyle)
        assertEquals(beforeModel.homeNavigationForm, afterModel.homeNavigationForm)

        // 非全局键仍跟着课表走（证明 overlay 只盖 44 键，不是把整份档案冻结）。
        assertEquals(25L, (after["semesterWeekCount"] as Number).toLong())
        assertEquals("档案内嵌镜像仍是 p2 自己的旧值", 25L, (embeddedSettings(raw, "p2")["semesterWeekCount"] as Number).toLong())
    }

    // ---------- 辅助 ----------

    private fun profilesJson(vararg profiles: Pair<String, Map<String, Any?>>): String =
        profiles.joinToString(prefix = "[", postfix = "]") { (id, settings) ->
            """{"id":"$id","name":"$id","courses":[],"settings":${MiniJson.encode(settings)}}"""
        }

    private fun globalObject(raw: InMemoryKeyValueStore): Map<*, *> =
        MiniJson.tryParse(raw.getString(AppGlobalSettingsStore.KEY) ?: "") as Map<*, *>

    private fun embeddedSettings(
        raw: InMemoryKeyValueStore,
        profileId: String,
    ): Map<*, *> {
        val profiles = MiniJson.tryParse(raw.getString(TimetableStore.KEY_PROFILES)!!) as List<*>
        val profile = profiles.first { (it as Map<*, *>)["id"] == profileId } as Map<*, *>
        return profile["settings"] as Map<*, *>
    }
}
