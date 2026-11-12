package com.mutx163.qingyu.pages.timetable

import com.mutx163.qingyu.app.AppGlobalSettingsStore
import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.testutil.readKotlinSourceNormalized
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「复制**非当前**课表不得污染整机级偏好」的契约测试（2026-11-11，对抗审查 H3 后重写）。
 *
 * ## 修的是什么
 *
 * `duplicateProfile` 原先把源档内嵌的整份 settings 原样铺到复制品上
 * （`TimetableProfilesController.rawSettingsOf`）。活动档那条路走 `repository.readRawSettings()`
 * = 档案内嵌 + 44 键 overlay，等于读到了真源；而**非活动档**那条路是裸读 `profiles[i].settings`，
 * 拿到的 44 个全局键只是**旧镜像**。铺到复制品时 `writeRawSettingsPatch` 会按 `split` 把这 44 键
 * 写进 `app_global_settings_v1` 真源 ⇒ 用户当前的主题/字体/语言/更新渠道被旧档旧值顶掉，
 * 读侧 overlay 立刻生效、界面当场变样，且没有任何提示。
 *
 * ## H3：为什么断言必须遍历，而不是点名两个键
 *
 * 第一版这里只断言 `appThemeMode` + `appFontMode`，而控制器自己手抄了一份 44 键名单。
 * 攻击面：从控制器名单里删掉 `savedThemes`（或正本新增键没同步）⇒ 该键被当成档案级键、
 * 按旧镜像写回真源，**测试照样全绿**。丢的是数据不是外观。
 * 现在生产代码只剩唯一真源 [AppGlobalSettingsStore.KEYS]，本类改为**遍历 44 键**逐键比对
 * 复制前后的真源值；另加一条源码守卫，禁止控制器再出现任何整机级键字面量。
 *
 * ⚠️ 更正：上一笔提交 `3bb7456d9` 的信息里写「逐键断言落盘 JSON」，实际只断言了 2/44。
 * 当前这版才是遍历断言 44 键。
 */
class ProfileDuplicateGlobalSettingsContractTest {

    @Test
    fun `复制非当前课表后 44 个整机级键逐键不变`() {
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

        val truthBefore = globalTruth(store)
        // 前提自检：真源必须覆盖全部整机级键（缺键说明播种/分拣本身有问题，先红在前提上）。
        assertEquals(
            "前提：全局真源必须覆盖全部 44 个整机级键（少的就是分拣漏掉的）",
            AppGlobalSettingsStore.KEYS.toSet(),
            truthBefore.keys,
        )
        assertEquals("前提：本机当前主题是 dark", "dark", truthBefore["appThemeMode"])
        assertEquals("前提：本机当前字体是 serif", "serif", truthBefore["appFontMode"])
        assertEquals("前提：p2 镜像是旧值 light", "light", embeddedSettings(store, "p2")["appThemeMode"])

        val repository = TimetableRepository(TimetableStore(store))
        val controller = TimetableProfilesController(repository, idFactory = { "p3" }, clock = { t1 })
        val result = controller.duplicateProfile("p2")
        assertTrue("复制必须成功：$result", result is TimetableProfileActionResult.Success)

        // 主断言：遍历 44 键，逐键比对复制前后的真源值——任何一个键被旧镜像顶掉都要红。
        val truthAfter = globalTruth(store)
        assertEquals("复制后真源的键集合不许变", truthBefore.keys, truthAfter.keys)
        val polluted = AppGlobalSettingsStore.KEYS.mapNotNull { key ->
            val before = truthBefore[key]
            val after = truthAfter[key]
            if (before != after) "$key: $before -> $after" else null
        }
        assertTrue("这些整机级键被源档旧镜像顶掉了：$polluted", polluted.isEmpty())

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

    /**
     * H3 的回归钉子：控制器**不许再手抄**整机级键名单。
     *
     * 只要有人往控制器里放回任意一个整机级键的字面量，这条就红——那正是「抄本漂移、
     * 某个键被当成档案级键悄悄写回真源、而遍历测试也可能因为键不在名单里而不检查」的入口。
     */
    @Test
    fun `控制器只引用唯一真源 不再手抄整机级键字面量`() {
        val source = readKotlinSourceNormalized(CONTROLLER_PATH)
        assertTrue(
            "必须引用唯一真源 AppGlobalSettingsStore.KEYS（找不到引用）",
            source.contains("AppGlobalSettingsStore.KEYS"),
        )
        val copied = AppGlobalSettingsStore.KEYS.filter { key -> source.contains("\"$key\"") }
        assertTrue(
            "控制器里又出现了整机级键字面量（$copied）——请改为引用 AppGlobalSettingsStore.KEYS",
            copied.isEmpty(),
        )
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

    private companion object {
        const val CONTROLLER_PATH =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/timetable/TimetableProfilesController.kt"
    }
}
