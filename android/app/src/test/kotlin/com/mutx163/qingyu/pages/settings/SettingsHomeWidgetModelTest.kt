package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.app.TimetableSettingsModelStore
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 桌面小组件 10 个设置键的**模型层**测试（F20-A）。
 *
 * 期望值全部手推自 Dart 源，不从 Kotlin 实现倒推：
 * - 构造默认值：`lib/models/timetable_settings.dart:786-795`；
 * - 写侧键名：`:1103-1112`；
 * - 读侧口径：`:1444-1461`（字符串走 `X.fromValue`、布尔/数字走 `lenientXxx(...) ?? 默认`，
 *   **double / int 都不 clamp**）；
 * - 枚举落盘串：`lib/models/settings/timetable_settings_extensions.dart:31-36` / `:153-167`，
 *   `lib/utils/widget_course_accent.dart:23-30`；
 * - 预览格位：`lib/services/home_widget_service.dart:96-126`。
 *
 * 另有两条**持久化镜像**约束（Dart `TimetableProvider.updateTimetableSettings` 写回档案，
 * `lib/providers/timetable_provider.dart:3036-3070`）：
 * 桌面卡片读 active 档案内嵌的 `settings`，而 `saveProfiles` 用只含 4 键的
 * `TimetableSettings.toJson()` 整体重写，必须把旧的其余键铺底保留。
 */
class SettingsHomeWidgetModelTest {

    // ------------------------------------------------------------ 模型：默认值

    @Test
    fun `缺键时 10 个小组件键回落 Dart 构造默认值`() {
        val model = TimetableSettingsModel.fromJson(emptyMap())

        assertEquals("solid", model.widgetBackgroundStyle) // :786
        assertEquals("bar_and_text", model.widgetCourseAccentMode) // :787
        assertTrue(model.widgetShowLocation) // :788
        assertTrue(model.widgetShowCountdown) // :789
        assertFalse(model.widgetHideCompletedCourses) // :790
        assertTrue(model.widgetShowTomorrowCourses) // :791
        assertEquals(-11.0, model.widgetHeightAdjustment, 0.0) // :792
        assertEquals(22.0, model.widgetCornerRadius, 0.0) // :793
        assertEquals(20, model.widgetCountdownLeadMinutes) // :794
        assertEquals("smart", model.widgetCountdownTextStyle) // :795
    }

    @Test
    fun `未知枚举串回落默认值 与 Dart 的 fromValue orElse 同口径`() {
        val model = TimetableSettingsModel.fromJson(
            mapOf(
                "widgetBackgroundStyle" to "neon",
                "widgetCourseAccentMode" to "rainbow",
                "widgetCountdownTextStyle" to "minute_second",
            ),
        )

        assertEquals("solid", model.widgetBackgroundStyle)
        assertEquals("bar_and_text", model.widgetCourseAccentMode)
        assertEquals("smart", model.widgetCountdownTextStyle)
    }

    @Test
    fun `十档枚举的每一个合法串都能读出来`() {
        // 背景三档（extensions:31-36）
        listOf("glass", "solid", "gradient").forEach { value ->
            assertEquals(
                value,
                TimetableSettingsModel.fromJson(mapOf("widgetBackgroundStyle" to value))
                    .widgetBackgroundStyle,
            )
        }
        // 课程颜色三档（widget_course_accent.dart:23-30）
        listOf("off", "bar", "bar_and_text").forEach { value ->
            assertEquals(
                value,
                TimetableSettingsModel.fromJson(mapOf("widgetCourseAccentMode" to value))
                    .widgetCourseAccentMode,
            )
        }
        // 倒计时样式十二档（extensions:153-167）
        val styles = listOf(
            "smart", "smart_min_s", "minute_second_cn", "minute_second_colon",
            "minute_second_min_s", "minute_second_min_slash_s", "minute_only_cn",
            "minute_only_min", "minute_only_slash", "second_only_cn",
            "second_only_short", "second_only_slash",
        )
        assertEquals(12, styles.size)
        styles.forEach { value ->
            assertEquals(
                value,
                TimetableSettingsModel.fromJson(mapOf("widgetCountdownTextStyle" to value))
                    .widgetCountdownTextStyle,
            )
        }
    }

    @Test
    fun `读侧不夹高度与圆角 与 Dart lenientDouble 同口径`() {
        val model = TimetableSettingsModel.fromJson(
            mapOf(
                "widgetHeightAdjustment" to -100.0,
                "widgetCornerRadius" to 999.0,
                "widgetCountdownLeadMinutes" to 7,
            ),
        )

        assertEquals(-100.0, model.widgetHeightAdjustment, 0.0)
        assertEquals(999.0, model.widgetCornerRadius, 0.0)
        assertEquals(7, model.widgetCountdownLeadMinutes)
    }

    @Test
    fun `布尔键类型不对按缺键处理`() {
        val model = TimetableSettingsModel.fromJson(
            mapOf(
                "widgetShowLocation" to "yes",
                "widgetShowCountdown" to 1,
                "widgetHideCompletedCourses" to "true",
                "widgetShowTomorrowCourses" to "false",
            ),
        )

        assertTrue(model.widgetShowLocation)
        assertTrue(model.widgetShowCountdown)
        assertTrue(model.widgetHideCompletedCourses) // "true" 是字符串 true（Dart lenientBool 同口径）
        assertFalse(model.widgetShowTomorrowCourses)
    }

    // ------------------------------------------------------------ 模型：写侧

    @Test
    fun `toJsonPatch 含这 10 个键且类型正确`() {
        val model = TimetableSettingsModel(
            widgetBackgroundStyle = "gradient",
            widgetCourseAccentMode = "off",
            widgetShowLocation = false,
            widgetShowCountdown = false,
            widgetHideCompletedCourses = true,
            widgetShowTomorrowCourses = false,
            widgetHeightAdjustment = 5.0,
            widgetCornerRadius = 36.0,
            widgetCountdownLeadMinutes = 60,
            widgetCountdownTextStyle = "second_only_slash",
        )

        val patch = model.toJsonPatch()

        assertEquals("gradient", patch["widgetBackgroundStyle"])
        assertEquals("off", patch["widgetCourseAccentMode"])
        assertEquals(false, patch["widgetShowLocation"])
        assertEquals(false, patch["widgetShowCountdown"])
        assertEquals(true, patch["widgetHideCompletedCourses"])
        assertEquals(false, patch["widgetShowTomorrowCourses"])
        assertEquals(5.0, patch["widgetHeightAdjustment"])
        assertEquals(36.0, patch["widgetCornerRadius"])
        assertEquals(60, patch["widgetCountdownLeadMinutes"])
        assertEquals("second_only_slash", patch["widgetCountdownTextStyle"])

        val owned = TimetableSettingsModel.OWNED_KEYS
        listOf(
            "widgetBackgroundStyle", "widgetCourseAccentMode", "widgetShowLocation",
            "widgetShowCountdown", "widgetHideCompletedCourses", "widgetShowTomorrowCourses",
            "widgetHeightAdjustment", "widgetCornerRadius", "widgetCountdownLeadMinutes",
            "widgetCountdownTextStyle",
        ).forEach { key ->
            assertTrue("OWNED_KEYS 缺 $key（写侧合并写靠它声明所有权）", key in owned)
        }
    }

    // ------------------------------------------------------- 模型：落盘往返

    @Test
    fun `timetable_settings 里这 10 键 保存后能原样读回`() {
        val raw = InMemoryKeyValueStore()
        val modelStore = TimetableSettingsModelStore(TimetableStore(raw))
        val model = TimetableSettingsModel(
            widgetBackgroundStyle = "glass",
            widgetCourseAccentMode = "bar",
            widgetShowLocation = false,
            widgetShowCountdown = false,
            widgetHideCompletedCourses = true,
            widgetShowTomorrowCourses = false,
            widgetHeightAdjustment = 3.5,
            widgetCornerRadius = 10.0,
            widgetCountdownLeadMinutes = 0,
            widgetCountdownTextStyle = "minute_only_cn",
        )

        modelStore.save(model)
        val loaded = modelStore.load()

        assertEquals("glass", loaded.widgetBackgroundStyle)
        assertEquals("bar", loaded.widgetCourseAccentMode)
        assertFalse(loaded.widgetShowLocation)
        assertFalse(loaded.widgetShowCountdown)
        assertTrue(loaded.widgetHideCompletedCourses)
        assertFalse(loaded.widgetShowTomorrowCourses)
        assertEquals(3.5, loaded.widgetHeightAdjustment, 0.0)
        assertEquals(10.0, loaded.widgetCornerRadius, 0.0)
        assertEquals(0, loaded.widgetCountdownLeadMinutes) // 0 = 始终显示，是合法档位
        assertEquals("minute_only_cn", loaded.widgetCountdownTextStyle)
    }

    @Test
    fun `合并写不冲掉盘上其它设置键`() {
        val raw = InMemoryKeyValueStore(
            mapOf(
                "timetable_settings" to
                    """{"someDartOnlyKey":"keep-me","widgetCornerRadius":30.0}""",
            ),
        )
        val modelStore = TimetableSettingsModelStore(TimetableStore(raw))

        modelStore.save(TimetableSettingsModel())

        val stored = MiniJson.parse(raw.getString("timetable_settings")!!) as Map<*, *>
        assertEquals("keep-me", stored["someDartOnlyKey"])
        // 保存的是整份模型 ⇒ 圆角被写回默认 22（不是保留旧 30）
        assertEquals(22.0, (stored["widgetCornerRadius"] as Number).toDouble(), 0.0)
    }

    // --------------------------------------------- 持久化镜像：active 档案 settings

    @Test
    fun `saveSettingsPatchToActiveProfile 写进 active 档案的 settings 且不动其它键`() {
        val raw = InMemoryKeyValueStore(
            mapOf(
                "timetable_profiles" to rawProfilesJson(
                    "p1" to linkedMapOf(
                        "semesterWeekCount" to 18,
                        "widgetCornerRadius" to 30.0,
                        "someDartOnlyKey" to "keep-me",
                    ),
                    "p2" to linkedMapOf(
                        "semesterWeekCount" to 20,
                        "widgetCornerRadius" to 8.0,
                    ),
                ),
                "active_timetable_profile_id" to "p2",
            ),
        )
        val store = TimetableStore(raw)

        store.saveSettingsPatchToActiveProfile(
            mapOf("widgetCornerRadius" to 24.0, "widgetShowLocation" to false),
        )

        val profiles = profilesOf(raw)
        val p1Settings = settingsOf(profiles, "p1")
        val p2Settings = settingsOf(profiles, "p2")
        // active 那份被合并
        assertEquals(24.0, (p2Settings["widgetCornerRadius"] as Number).toDouble(), 0.0)
        assertEquals(false, p2Settings["widgetShowLocation"])
        assertEquals(20L, (p2Settings["semesterWeekCount"] as Number).toLong())
        // 非 active 那份一个键都不能动
        assertEquals(30.0, (p1Settings["widgetCornerRadius"] as Number).toDouble(), 0.0)
        assertEquals("keep-me", p1Settings["someDartOnlyKey"])
        assertEquals(18L, (p1Settings["semesterWeekCount"] as Number).toLong())
        // 档案本身的其它键也保留
        assertEquals("p2", (profiles.first { (it as Map<*, *>)["id"] == "p2" } as Map<*, *>)["name"])
        assertEquals(1L, store.profilesSchemaVersion().toLong())
    }

    @Test
    fun `saveSettingsPatchToActiveProfile 找不到 active id 时写数组第一个档案`() {
        val raw = InMemoryKeyValueStore(
            mapOf(
                "timetable_profiles" to rawProfilesJson(
                    "p1" to linkedMapOf("widgetCornerRadius" to 30.0),
                    "p2" to linkedMapOf("widgetCornerRadius" to 8.0),
                ),
                "active_timetable_profile_id" to "gone",
            ),
        )
        TimetableStore(raw).saveSettingsPatchToActiveProfile(mapOf("widgetCornerRadius" to 12.0))

        val profiles = profilesOf(raw)
        assertEquals(12.0, (settingsOf(profiles, "p1")["widgetCornerRadius"] as Number).toDouble(), 0.0)
        assertEquals(8.0, (settingsOf(profiles, "p2")["widgetCornerRadius"] as Number).toDouble(), 0.0)
    }

    @Test
    fun `saveSettingsPatchToActiveProfile 解析失败时什么都不做`() {
        val broken = "{not json at all"
        val raw = InMemoryKeyValueStore(mapOf("timetable_profiles" to broken))
        val store = TimetableStore(raw)

        store.saveSettingsPatchToActiveProfile(mapOf("widgetCornerRadius" to 12.0))

        assertEquals(broken, raw.getString("timetable_profiles"))
        // 解析失败不许留档、更不许删数据（这份数据可能还要被 Dart 侧读走）
        assertTrue(
            raw.keys().none { it.startsWith("timetable_profiles_corrupt_backup") },
        )
    }

    @Test
    fun `saveSettingsPatchToActiveProfile 在空盘上不造出档案`() {
        val raw = InMemoryKeyValueStore()
        TimetableStore(raw).saveSettingsPatchToActiveProfile(mapOf("widgetCornerRadius" to 12.0))

        assertNull(raw.getString("timetable_profiles"))
    }

    @Test
    fun `saveProfiles 保留旧档案 settings 里本层不认识的键`() {
        val raw = InMemoryKeyValueStore(
            mapOf(
                "timetable_profiles" to rawProfilesJson(
                    "p1" to linkedMapOf(
                        "semesterWeekCount" to 18,
                        "widgetBackgroundStyle" to "glass",
                        "widgetHeightAdjustment" to 5.0,
                        "someDartOnlyKey" to "keep-me",
                    ),
                ),
            ),
        )
        val store = TimetableStore(raw)

        store.saveProfiles(listOf(profile("p1", TimetableSettings(semesterWeekCount = 18))))

        val settings = settingsOf(profilesOf(raw), "p1")
        assertEquals("glass", settings["widgetBackgroundStyle"])
        assertEquals(5.0, (settings["widgetHeightAdjustment"] as Number).toDouble(), 0.0)
        assertEquals("keep-me", settings["someDartOnlyKey"])
        // 本层拥有的 4 键按新值写（同键以新值为准）
        assertEquals(18L, (settings["semesterWeekCount"] as Number).toLong())
        assertTrue(settings.containsKey("sections"))
        assertEquals(1L, store.profilesSchemaVersion().toLong())
    }

    @Test
    fun `saveProfiles 在空盘上行为不变 只写 4 键 settings`() {
        val raw = InMemoryKeyValueStore()
        TimetableStore(raw).saveProfiles(listOf(profile("p1")))

        val settings = settingsOf(profilesOf(raw), "p1")
        assertEquals(20L, (settings["semesterWeekCount"] as Number).toLong())
        assertFalse(settings.containsKey("widgetBackgroundStyle"))
    }

    // ------------------------------------------------------- 桥：状态映射

    @Test
    fun `toHomeWidgetState 逐字段直给 高度给存储值而不是偏移`() {
        val model = TimetableSettingsModel(
            widgetBackgroundStyle = "gradient",
            widgetCourseAccentMode = "off",
            widgetShowLocation = false,
            widgetShowCountdown = false,
            widgetHideCompletedCourses = true,
            widgetShowTomorrowCourses = false,
            widgetHeightAdjustment = -6.0,
            widgetCornerRadius = 30.0,
            widgetCountdownLeadMinutes = 10,
            widgetCountdownTextStyle = "second_only_cn",
        )
        val instances = listOf(HomeWidgetInstanceSpec(7, "compact", null))
        val profiles = listOf(ProfileSpec("p1", "课表一"))
        val partner = ProfileSpec("p2", "TA 的课表", isPartnerImported = true)

        val state = SettingsPageBridge.toHomeWidgetState(
            model = model,
            widgetInstances = instances,
            profiles = profiles,
            partnerProfile = partner,
            exactAlarmGranted = false,
        )

        assertEquals("gradient", state.backgroundStyle)
        assertEquals("off", state.courseAccentMode)
        assertFalse(state.showLocation)
        assertFalse(state.showCountdown)
        assertTrue(state.hideCompletedCourses)
        assertFalse(state.showTomorrowCourses)
        // 页面自己减 -11 得偏移；这里直给 -6 才对（不是 -17，也不是 5）
        assertEquals(-6.0, state.heightAdjustment, 0.0)
        assertEquals(5.0, SettingsHomeWidgetPage.heightOffset(state.heightAdjustment), 0.0)
        assertEquals(30.0, state.cornerRadius, 0.0)
        assertEquals(10, state.countdownLeadMinutes)
        assertEquals("second_only_cn", state.countdownTextStyle)
        assertEquals(instances, state.widgetInstances)
        assertEquals(profiles, state.profiles)
        assertEquals(partner, state.partnerProfile)
        assertEquals(false, state.exactAlarmGranted)
    }

    @Test
    fun `toHomeWidgetState 默认参数 权限未知时不显示引导条`() {
        val state = SettingsPageBridge.toHomeWidgetState(TimetableSettingsModel())

        assertEquals(SettingsHomeWidgetState(), state)
        assertNull(state.exactAlarmGranted)
        // exactAlarmGranted == null 时页面只出预览、不出权限横幅（:64-66 / :212）
        val ids = SettingsHomeWidgetPage.spec(state).nodes.map { it.id }
        assertTrue("homeWidget.preview" in ids)
        assertFalse("homeWidget.preview.alarmBanner" in ids)
    }

    // ------------------------------------------------------- 预览格位尺寸

    @Test
    fun `360dp 屏 单格 74 两格 156 四格 320`() {
        val specs = HomeWidgetPreviewSpecs.build(360.0)
        val byId = specs.associateBy { it.targetId }

        // 单格 = (360 − 40 − 24) / 4 = 74；1 格的 today_strip 直接读到单格
        assertEquals(10, specs.size)
        assertEquals(74.0, byId.getValue("today_strip").heightDp, 0.0)
        assertEquals(156.0, byId.getValue("compact").widthDp, 0.0) // 2×74 + 8
        assertEquals(156.0, byId.getValue("compact").heightDp, 0.0)
        assertEquals(320.0, byId.getValue("large").widthDp, 0.0) // 4×74 + 3×8
        assertEquals(320.0, byId.getValue("large").heightDp, 0.0)
    }

    @Test
    fun `极窄屏 200dp 单格兜底 56 两格 120 四格 248`() {
        val byId = HomeWidgetPreviewSpecs.build(200.0).associateBy { it.targetId }

        // raw = (200 − 40 − 24) / 4 = 34 → 兜底 56
        assertEquals(120.0, byId.getValue("compact").widthDp, 0.0) // 2×56 + 8
        assertEquals(248.0, byId.getValue("large").widthDp, 0.0) // 4×56 + 24
    }

    @Test
    fun `预览顺序与跨格数与页面 PREVIEW_TARGETS 一致`() {
        val specs = HomeWidgetPreviewSpecs.build(360.0)
        val pageIds = SettingsHomeWidgetPage.PREVIEW_TARGETS.map { it.id }
        val specIds = specs.map { it.targetId }
        assertEquals(pageIds, specIds)

        // 跨格数逐项对照 Dart `buildHomeWidgetPreviewSpecs`（home_widget_service.dart:115-126）
        assertEquals(
            listOf(2 to 2, 2 to 2, 2 to 4, 4 to 4, 4 to 1, 4 to 2, 2 to 2, 2 to 4, 4 to 1, 2 to 2),
            specs.map { it.cellWidth to it.cellHeight },
        )
    }

    // ------------------------------------------------------------------ 工具

    /** 盘上 `timetable_profiles` → 档案 Map 列表（测试自带的解析，不借实现）。 */
    private fun profilesOf(raw: InMemoryKeyValueStore): List<Any?> {
        val text = raw.getString("timetable_profiles")
        assertNotNull("timetable_profiles 没写出来", text)
        val parsed = MiniJson.parse(text!!)
        assertTrue(parsed is List<*>)
        return parsed as List<*>
    }

    private fun settingsOf(profiles: List<Any?>, id: String): Map<*, *> {
        val profile = profiles
            .map { it as Map<*, *> }
            .firstOrNull { it["id"] == id }
            ?: error("盘上没有档案 $id")
        return profile["settings"] as Map<*, *>
    }

    /**
     * 造一份 `timetable_profiles` 原始 JSON：每份档案只写 id/name/settings/currentWeek，
     * settings 用调用方给的那份（可含本层不认识的键）。
     */
    private fun rawProfilesJson(vararg entries: Pair<String, Map<String, Any?>>): String =
        MiniJson.encode(
            entries.map { (id, settings) ->
                linkedMapOf(
                    "id" to id,
                    "name" to id,
                    "settings" to settings,
                    "currentWeek" to 1,
                    "courses" to emptyList<Any?>(),
                )
            },
        )

    private fun profile(id: String, settings: TimetableSettings = TimetableSettings()) =
        TimetableProfile(
            id = id,
            name = id,
            settings = settings,
            currentWeek = 1L,
            createdAt = LocalDateTime.of(2026, 1, 1, 0, 0),
            lastUsedAt = LocalDateTime.of(2026, 1, 1, 0, 0),
        )
}
