package com.mutx163.qingyu.pages.timetable

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「复制**非当前**课表不得污染整机级偏好」的契约测试（2026-11-11）。
 *
 * ## 修的是什么
 *
 * `duplicateProfile` 原先把源档内嵌的整份 settings 原样铺到复制品上
 * （`TimetableProfilesController.rawSettingsOf`）。活动档那条路走的是 `repository.readRawSettings()`
 * = 档案内嵌 + 44 键 overlay，等于读到了真源；而**非活动档**那条路是裸读 `profiles[i].settings`，
 * 拿到的 44 个全局键只是**旧镜像**。铺到复制品时 `writeRawSettingsPatch` 会按 `split` 把这 44 键
 * 写进 `app_global_settings_v1` 真源 ⇒ 用户当前的主题 / 字体 / 语言被旧档旧值顶掉，
 * 读侧 overlay 立刻生效、界面当场变样，而且没有任何提示。
 *
 * ## 断言口径（本测试就是修复的意义）
 *
 * 逐键断言**落盘 JSON**：全局真源里 `appThemeMode` / `appFontMode` 必须还是本机当前值，
 * 不许出现源档的旧值；同时档案级键（课程卡字号 / 周末隐藏）必须照旧从源档继承——
 * 否则「修好污染」很容易顺手把「复制该带的档案级外观」也一起改没了。
 */
class ProfileDuplicateGlobalSettingsContractTest {

    @Test
    fun `复制非当前课表后 全局真源的主题与字体仍是本机当前值`() {
        val store = InMemoryKeyValueStore()
        val timetableStore = TimetableStore(store)
        timetableStore.saveProfiles(
            listOf(
                TimetableProfile(id = "p1", name = "当前课表", currentWeek = 3, createdAt = t0, lastUsedAt = t0),
                TimetableProfile(id = "p2", name = "另一份课表", currentWeek = 3, createdAt = t0, lastUsedAt = t0),
            ),
        )
        timetableStore.saveActiveProfileId("p1")
        timetableStore.saveSettings(TimetableSettings.defaults())
        // 本机当前整机偏好：深色 + 衬线字体 + 档案级字号 11。
        timetableStore.saveSettingsPatch(
            linkedMapOf(
                "appThemeMode" to "dark",
                "appFontMode" to "serif",
                "courseCardFontSize" to 11.0,
            ),
        )
        // 非活动档 p2 的内嵌 settings 是**旧镜像**：主题/字体停在旧值，档案级字号/周末隐藏与 p1 不同。
        stampStaleMirror(store)

        val repository = TimetableRepository(TimetableStore(store))
        // 前提自检：真源是 dark/serif，p2 镜像停在 light/sans（不成立就说明夹具没构造出事故现场）。
        assertEquals("前提：全局真源主题是 dark", "dark", globalTruth(store)["appThemeMode"])
        assertEquals("前提：p2 镜像主题是旧值 light", "light", embeddedSettings(store, "p2")["appThemeMode"])

        val controller = TimetableProfilesController(repository, idFactory = { "p3" }, clock = { t1 })
        val result = controller.duplicateProfile("p2")
        assertTrue("复制必须成功：$result", result is TimetableProfileActionResult.Success)

        // 主断言：全局真源（落盘 JSON）里的主题/字体仍是本机当前值，没被 p2 的旧镜像顶掉。
        val truthAfter = globalTruth(store)
        assertEquals("主题被旧档顶掉了", "dark", truthAfter["appThemeMode"])
        assertEquals("字体被旧档顶掉了", "serif", truthAfter["appFontMode"])

        // 仓储实例视图（overlay 之后）同样必须是当前值。
        assertEquals("dark", repository.readRawSettings()["appThemeMode"])
        assertEquals("serif", repository.readRawSettings()["appFontMode"])

        // 档案级键必须照旧从源档继承：修污染不能顺手把「复制该带的档案级外观」改没。
        val copyEmbedded = embeddedSettings(store, "p3")
        assertEquals("档案级字号要跟着源档", 12.0, copyEmbedded["courseCardFontSize"])
        assertEquals("课表页显示项要跟着源档", true, copyEmbedded["timetableHideWeekends"])
        assertEquals("复制品内嵌的全局镜像也应是当前真源值", "dark", copyEmbedded["appThemeMode"])
    }

    @Test
    fun `复制当前课表仍然整份照抄 不被本次修复误伤`() {
        val store = InMemoryKeyValueStore()
        val timetableStore = TimetableStore(store)
        timetableStore.saveProfiles(
            listOf(
                TimetableProfile(id = "p1", name = "当前课表", currentWeek = 3, createdAt = t0, lastUsedAt = t0),
            ),
        )
        timetableStore.saveActiveProfileId("p1")
        timetableStore.saveSettings(TimetableSettings.defaults())
        timetableStore.saveSettingsPatch(
            linkedMapOf(
                "appThemeMode" to "dark",
                "appFontMode" to "serif",
                "courseCardFontSize" to 11.0,
            ),
        )
        val repository = TimetableRepository(TimetableStore(store))

        val controller = TimetableProfilesController(repository, idFactory = { "p2" }, clock = { t1 })
        assertTrue(controller.duplicateProfile("p1") is TimetableProfileActionResult.Success)

        val copyEmbedded = embeddedSettings(store, "p2")
        assertEquals("dark", copyEmbedded["appThemeMode"])
        assertEquals("serif", copyEmbedded["appFontMode"])
        assertEquals(11.0, copyEmbedded["courseCardFontSize"])
    }

    // -----------------------------------------------------------------------
    // 夹具
    // -----------------------------------------------------------------------

    private val t0: LocalDateTime = LocalDateTime.of(2026, 9, 1, 8, 0)
    private val t1: LocalDateTime = t0.plusDays(2)

    /** 把 p2 的内嵌 settings 改写成「旧镜像」：主题/字体停在旧值，档案级键换成另一套。 */
    private fun stampStaleMirror(store: InMemoryKeyValueStore) {
        val raw = store.rawSnapshot()["flutter.${TimetableStore.KEY_PROFILES}"]
        assertNotNull("盘上必须有 timetable_profiles", raw)
        val decoded = MiniJson.tryParse(raw!!) as List<*>
        val rewritten = decoded.map { item ->
            val map = LinkedHashMap<String, Any?>()
            for ((key, value) in (item as Map<*, *>)) if (key is String) map[key] = value
            if (map["id"] == "p2") {
                val settings = LinkedHashMap<String, Any?>()
                for ((key, value) in (map["settings"] as? Map<*, *> ?: emptyMap<String, Any?>())) {
                    if (key is String) settings[key] = value
                }
                settings["appThemeMode"] = "light"
                settings["appFontMode"] = "sans"
                settings["courseCardFontSize"] = 12.0
                settings["timetableHideWeekends"] = true
                map["settings"] = settings
            }
            map
        }
        store.putString(TimetableStore.KEY_PROFILES, MiniJson.encode(rewritten))
    }

    /** 全局真源（`app_global_settings_v1`）落盘 JSON。 */
    @Suppress("UNCHECKED_CAST")
    private fun globalTruth(store: InMemoryKeyValueStore): Map<String, Any?> {
        val raw = store.rawSnapshot()["flutter.app_global_settings_v1"]
        assertNotNull("盘上必须有全局真源 app_global_settings_v1", raw)
        return MiniJson.tryParse(raw!!) as Map<String, Any?>
    }

    /** 指定档案的内嵌 settings（落盘 JSON，剥掉显式 null）。 */
    @Suppress("UNCHECKED_CAST")
    private fun embeddedSettings(store: InMemoryKeyValueStore, profileId: String): Map<String, Any?> {
        val raw = store.rawSnapshot()["flutter.${TimetableStore.KEY_PROFILES}"]
        assertNotNull("盘上必须有 timetable_profiles", raw)
        val profiles = MiniJson.tryParse(raw!!) as List<*>
        val profile = profiles.first { (it as Map<*, *>)["id"] == profileId } as Map<*, *>
        val settings = profile["settings"] as? Map<String, Any?> ?: emptyMap()
        return settings.filterValues { it != null }
    }
}
