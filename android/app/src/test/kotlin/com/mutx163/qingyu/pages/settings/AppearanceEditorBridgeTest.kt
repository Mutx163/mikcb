package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.CourseCardSurfaceStyle as AppCourseCardSurfaceStyle
import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.LiquidGlassTuningModel
import com.mutx163.qingyu.app.TimetableHomeViewMode
import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.app.TimetableSettingsModelStore
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.app.WallpaperHistoryRowModel
import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 外观编辑页**状态桥**（[AppearanceEditorBridge.toState]）与它依赖的设置键。
 *
 * ## 这一批测试在钉什么
 *
 * 1. **逐键同源**：Dart 面板读 `_draft`（即设置模型本身），所以「模型里存了什么 →
 *    面板状态里就该是什么」。每条断言后面写着 Dart 行号，期望值是人照 Dart 读侧推的，
 *    不是从实现里抄的。
 * 2. **往返**：改一条键 → 状态变 → 经 [TimetableSettingsModelStore] 回写 →
 *    盘上其它键一个不少（这一条防的是「合并写把别人的键覆盖成 null」那类事故）。
 * 3. **两处档位表不许漂**：`app/LiquidGlassTuningModel.PRESET_TUNINGS`（写路径与读侧收敛用）
 *    与 `pages/settings/SettingsMaterialModel.LiquidGlassTuning.PRESET_TUNINGS`（渲染用）
 *    必须逐字段相等——它们分成两份是架构边界（`app/` 不能依赖 `pages/`）逼出来的，
 *    不是"可以各写一份"。
 */
class AppearanceEditorBridgeTest {

    // ------------------------------------------------------------------ 工具

    private fun json(text: String): Map<String, Any?> = MiniJson.parse(text) as Map<String, Any?>

    private fun storeOf(raw: String): InMemoryKeyValueStore =
        InMemoryKeyValueStore(mapOf("timetable_settings" to raw))

    private fun rawSettings(store: InMemoryKeyValueStore): Map<String, Any?> =
        json(store.getString("timetable_settings")!!)

    private fun stateOf(model: TimetableSettingsModel): AppearanceEditorState =
        AppearanceEditorBridge.toState(model)

    /**
     * 「每条键都取非默认值」的一份存档。
     *
     * 里面同时塞了**别人的键**（学期周数 / 主题 / 字体 / 首页导航 / 课程卡片 / 节假日，
     * 还有一个本模型完全不认识的未来键），用来证明合并写不会把它们冲掉。
     */
    private val seededJson = """
        {
          "semesterWeekCount": 18,
          "activeTimeSchemeId": "ts-1",
          "semesterStartDateText": "2026-09-07",
          "appThemeMode": "light",
          "appFontWeight": 600,
          "homeTitleStyle": "brand",
          "homeMenuStyle": "grid",
          "sectionHeight": 80,
          "courseCardShowName": false,
          "enableHolidayMarking": false,
          "someFutureDartOnlyKey": "keep-me",
          "frostedBlurEnabled": true,
          "homePageHeaderBlurEnabled": false,
          "homeBandGlassMaterial": "liquid",
          "liquidGlassPreset": "level8",
          "liquidGlassTuning": {
            "refraction": 9, "refractionBand": 13, "refractionEdgePow": 2.25,
            "dispersion": 0.4, "rimStrength": 0.25, "rimWidth": 1.7,
            "blurSigma": 18, "tintAlpha": 0.75
          },
          "liquidGlassTuningDark": {
            "refraction": 10, "refractionBand": 14, "refractionEdgePow": 2.25,
            "dispersion": 0.45, "rimStrength": 0.3, "rimWidth": 1.9,
            "blurSigma": 21, "tintAlpha": 0.8
          },
          "linkLiquidGlassTuning": false,
          "darkGlassBoostEnabled": true,
          "liquidGlassDockEnabled": true,
          "courseCardGlassPreset": "standard",
          "courseCardGlassTuning": {
            "refraction": 8, "refractionBand": 11, "refractionEdgePow": 2.5,
            "dispersion": 0.35, "rimStrength": 0.2, "rimWidth": 1.5,
            "blurSigma": 15, "tintAlpha": 0.7
          },
          "homePageWallpaperPath": "/data/user/0/app/files/wall.jpg",
          "homePageWallpaperAlignX": -0.25,
          "homePageWallpaperAlignY": 0.5,
          "homePageWallpaperScale": 2.0,
          "homePageWallpaperBlurSigma": 6,
          "wallpaperHistory": [
            {"key": "/data/user/0/app/files/wall.jpg", "alignX": -0.25, "alignY": 0.5,
             "scale": 2.0, "usedAt": 1700000000000}
          ],
          "homePageBackdropFollowsWeekPager": true
        }
    """.trimIndent()

    private fun seededModel(): TimetableSettingsModel =
        TimetableSettingsModelStore(TimetableStore(storeOf(seededJson))).load()

    // ------------------------------------------------------------ 映射：整卷

    @Test
    fun `整卷映射：材质那十一个键逐条同源`() {
        val model = seededModel()
        val material = stateOf(model).material

        // :655 / :925 / :1773
        assertTrue(material.frostedBlurEnabled)
        // :707 / :1829：Dart 读侧恒 true（存档里那个 false 不读）
        assertTrue(material.homePageHeaderBlurEnabled)
        // :722 / :1837
        assertEquals("liquid", material.homeBandGlassMaterial)
        // :671 / :1786-1798：档位键与参数键一致时原样保留（这里是第 8 格）
        assertEquals("level8", material.liquidGlassPreset)
        // :672 / :929（第 8 格的推荐参数）
        assertEquals(
            LiquidGlassTuning(refraction = 9.0, refractionBand = 13.0, refractionEdgePow = 2.25,
                dispersion = 0.4, rimStrength = 0.25, rimWidth = 1.7,
                blurSigma = 18.0, tintAlpha = 0.75),
            material.liquidGlassTuning,
        )
        // :675 / :930（深色档 = 第 9 格那套）
        assertEquals(
            LiquidGlassTuning(refraction = 10.0, refractionBand = 14.0, refractionEdgePow = 2.25,
                dispersion = 0.45, rimStrength = 0.3, rimWidth = 1.9,
                blurSigma = 21.0, tintAlpha = 0.8),
            material.liquidGlassTuningDark,
        )
        // :682 / :1804
        assertFalse(material.linkLiquidGlassTuning)
        // :685 / :1807
        assertTrue(material.darkGlassBoostEnabled)
        // :661 / :1775
        assertTrue(material.liquidGlassDockEnabled)
        // :705 / :1811
        assertEquals("standard", material.courseCardGlassPreset)
        // :695 / :933（卡片出厂档逐字段等于全局标准档）
        assertEquals(LiquidGlassTuning.DEFAULTS, material.courseCardGlassTuning)
        // :662 / :1778-1785
        assertEquals(CourseCardSurfaceStyle.SOLID, material.courseCardSurfaceStyle) // 面板那份枚举
        // :203-204（首页持久化视图是周 ⇒ 预览看周）
        assertFalse(material.previewDayView)
    }

    @Test
    fun `整卷映射：壁纸那七个键逐条同源`() {
        val model = seededModel()
        val wallpaper = stateOf(model).wallpaper

        // :559 / :1706
        assertEquals("/data/user/0/app/files/wall.jpg", wallpaper.path)
        // :563 / :1707（读侧不夹，原样搬运）
        assertEquals(-0.25, wallpaper.alignX, 0.0)
        // :567 / :1709
        assertEquals(0.5, wallpaper.alignY, 0.0)
        // :580 / :1712
        assertEquals(2.0, wallpaper.scale, 0.0)
        // :587 / :1715
        assertEquals(6.0, wallpaper.blurSigma, 0.0)
        // :746 / :1852
        assertTrue(wallpaper.followsWeekPager)
        // :594 / :1718 + wallpaper_history.dart:20-56
        assertEquals(1, wallpaper.history.size)
        val row = wallpaper.history.single()
        assertEquals("/data/user/0/app/files/wall.jpg", row.key)
        assertEquals("wall.jpg", row.label)
        assertEquals(-0.25, row.alignX, 0.0)
        assertEquals(0.5, row.alignY, 0.0)
        assertEquals(2.0, row.scale, 0.0)
        assertEquals(1_700_000_000_000L, row.usedAt)
        // 有壁纸 ⇒ 课卡玻璃门控为真
        assertTrue(wallpaper.hasBackdrop)
        assertTrue(stateOf(model).material.hasHomePageBackdrop)
    }

    @Test
    fun `缺键回落与 Dart 读侧默认值一致`() {
        val state = stateOf(TimetableSettingsModel())
        val material = state.material
        val wallpaper = state.wallpaper

        assertTrue(material.frostedBlurEnabled) // :292
        assertTrue(material.homePageHeaderBlurEnabled) // :935
        assertEquals("liquid", material.homeBandGlassMaterial) // :329
        assertEquals("standard", material.liquidGlassPreset) // :928 + fromValue 的 orElse
        // :936：面板读 `_draft.liquidGlassTuning ?? defaults`
        assertEquals(LiquidGlassTuning.DEFAULTS, material.liquidGlassTuning)
        assertNull(material.liquidGlassTuningDark) // :930（null = 跟随浅色档）
        assertTrue(material.linkLiquidGlassTuning) // :307
        assertTrue(material.darkGlassBoostEnabled) // :313
        assertTrue(material.liquidGlassDockEnabled) // :300
        assertEquals("standard", material.courseCardGlassPreset) // :934
        assertEquals(LiquidGlassTuning.DEFAULTS, material.courseCardGlassTuning) // :933
        assertFalse(material.hasHomePageBackdrop)

        assertNull(wallpaper.path) // :894
        assertEquals(0.0, wallpaper.alignX, 0.0) // :895
        assertEquals(0.0, wallpaper.alignY, 0.0) // :896
        assertEquals(1.0, wallpaper.scale, 0.0) // :897
        assertEquals(0.0, wallpaper.blurSigma, 0.0) // :898 = minHomePageWallpaperBlurSigma
        assertFalse(wallpaper.followsWeekPager) // :939
        assertTrue(wallpaper.history.isEmpty()) // :899
        assertFalse(wallpaper.hasBackdrop)
    }

    @Test
    fun `模糊读侧收口 而缩放读侧不夹`() {
        // 两个量的口径**故意不同**（Dart 就这样）：
        // 模糊 `fromJson` 就 `clampHomePageWallpaperBlurSigma`（:1715-1717，0~24），
        // 缩放 `fromJson` 只有 `?? 1`（:1712-1713），夹在渲染/编辑侧（home_page_background.dart:586-587）。
        val store = storeOf("""{"homePageWallpaperBlurSigma": 30, "homePageWallpaperScale": 9}""")
        val model = TimetableSettingsModelStore(TimetableStore(store)).load()

        assertEquals(24.0, model.homePageWallpaperBlurSigma, 0.0)
        assertEquals(9.0, model.homePageWallpaperScale, 0.0)

        val wallpaper = stateOf(model).wallpaper
        assertEquals(24.0, wallpaper.blurSigma, 0.0) // 面板再夹一次，同口径
        assertEquals(9.0, wallpaper.scale, 0.0) // 面板不夹，渲染侧夹
        assertEquals(4.0, WallpaperPanelState.clampScale(wallpaper.scale), 0.0)
    }

    @Test
    fun `预览看日还是看周 跟首页持久化视图走`() {
        // settings_appearance_editor.dart:203-204 的 `_dayPreview`
        val day = TimetableSettingsModel(timetableHomeViewMode = TimetableHomeViewMode.DAY)
        assertTrue(stateOf(day).previewDayView)
        assertTrue(stateOf(day).material.previewDayView)

        val week = TimetableSettingsModel(timetableHomeViewMode = TimetableHomeViewMode.WEEK)
        assertFalse(stateOf(week).previewDayView)
        assertFalse(stateOf(week).material.previewDayView)
    }

    // ---------------------------------------------------------------- 往返

    /**
     * 一条键的往返用例。
     *
     * @param key 盘上的键名。
     * @param linkedKeys 与它**同生共死**的键（档位与参数是成对写的），跨键检查时跳过。
     * @param mutate 单键改动（必须是真改动，用例会断言「改完模型确实变了」）。
     * @param assertState 改键之后**面板状态**该看到什么。
     * @param assertWritten 回写之后**盘上**该是什么。
     */
    private class KeyCase(
        val key: String,
        val linkedKeys: Set<String> = emptySet(),
        val mutate: (TimetableSettingsModel) -> TimetableSettingsModel,
        val assertState: (AppearanceEditorState) -> Unit,
        val assertWritten: (Any?) -> Unit,
    )

    private fun keyCases(): List<KeyCase> = listOf(
        KeyCase(
            key = "frostedBlurEnabled",
            mutate = { it.copy(frostedBlurEnabled = false) },
            assertState = { assertFalse(it.material.frostedBlurEnabled) },
            assertWritten = { assertEquals(false, it) },
        ),
        KeyCase(
            key = "homePageHeaderBlurEnabled",
            mutate = { it.copy(homePageHeaderBlurEnabled = false) },
            assertState = { assertFalse(it.material.homePageHeaderBlurEnabled) },
            assertWritten = { assertEquals(false, it) },
        ),
        KeyCase(
            key = "homeBandGlassMaterial",
            mutate = { it.copy(homeBandGlassMaterial = "solid") },
            assertState = { assertEquals("solid", it.material.homeBandGlassMaterial) },
            assertWritten = { assertEquals("solid", it) },
        ),
        KeyCase(
            key = "liquidGlassPreset",
            linkedKeys = setOf("liquidGlassTuning"),
            mutate = {
                it.copy(
                    liquidGlassPreset = "dense",
                    liquidGlassTuning = LiquidGlassTuningModel.tuningOfPreset("dense"),
                )
            },
            assertState = {
                assertEquals("dense", it.material.liquidGlassPreset)
                // 第 10 格：折射 11 / 作用带 15 / 陡缓 2 / 色散 0.5 / 边光 0.3×2.1 / 模糊 24 / 染色 0.9
                assertEquals(11.0, it.material.liquidGlassTuning.refraction, 0.0)
                assertEquals(24.0, it.material.liquidGlassTuning.blurSigma, 0.0)
                assertEquals(0.9, it.material.liquidGlassTuning.tintAlpha, 0.0)
            },
            assertWritten = { assertEquals("dense", it) },
        ),
        KeyCase(
            key = "liquidGlassTuning",
            linkedKeys = setOf("liquidGlassPreset"),
            mutate = { it.copy(liquidGlassTuning = LiquidGlassTuningModel(refraction = 12.0)) },
            assertState = { assertEquals(12.0, it.material.liquidGlassTuning.refraction, 0.0) },
            assertWritten = {
                val map = it as Map<*, *>
                assertEquals(12.0, (map["refraction"] as Number).toDouble(), 0.0)
                // 其余七项回落出厂值（缺键 = 出厂档，liquid_glass_tuning.dart:605-624）
                assertEquals(11.0, (map["refractionBand"] as Number).toDouble(), 0.0)
            },
        ),
        KeyCase(
            key = "liquidGlassTuningDark",
            mutate = { it.copy(liquidGlassTuningDark = LiquidGlassTuningModel(tintAlpha = 0.2)) },
            assertState = {
                assertNotNull(it.material.liquidGlassTuningDark)
                assertEquals(0.2, it.material.liquidGlassTuningDark!!.tintAlpha, 0.0)
            },
            assertWritten = {
                val map = it as Map<*, *>
                assertEquals(0.2, (map["tintAlpha"] as Number).toDouble(), 0.0)
            },
        ),
        KeyCase(
            key = "linkLiquidGlassTuning",
            mutate = { it.copy(linkLiquidGlassTuning = true) },
            assertState = { assertTrue(it.material.linkLiquidGlassTuning) },
            assertWritten = { assertEquals(true, it) },
        ),
        KeyCase(
            key = "darkGlassBoostEnabled",
            mutate = { it.copy(darkGlassBoostEnabled = false) },
            assertState = { assertFalse(it.material.darkGlassBoostEnabled) },
            assertWritten = { assertEquals(false, it) },
        ),
        KeyCase(
            key = "liquidGlassDockEnabled",
            mutate = { it.copy(liquidGlassDockEnabled = false) },
            assertState = { assertFalse(it.material.liquidGlassDockEnabled) },
            assertWritten = { assertEquals(false, it) },
        ),
        KeyCase(
            key = "courseCardGlassPreset",
            linkedKeys = setOf("courseCardGlassTuning"),
            mutate = {
                it.copy(
                    courseCardGlassPreset = "clear",
                    courseCardGlassTuning = LiquidGlassTuningModel.tuningOfPreset("clear"),
                )
            },
            assertState = {
                assertEquals("clear", it.material.courseCardGlassPreset)
                // 第 1 格：染色与模糊都归零
                assertEquals(0.0, it.material.courseCardGlassTuning.tintAlpha, 0.0)
                assertEquals(0.0, it.material.courseCardGlassTuning.blurSigma, 0.0)
            },
            assertWritten = { assertEquals("clear", it) },
        ),
        KeyCase(
            key = "courseCardGlassTuning",
            linkedKeys = setOf("courseCardGlassPreset"),
            mutate = { it.copy(courseCardGlassTuning = LiquidGlassTuningModel(blurSigma = 3.0)) },
            assertState = { assertEquals(3.0, it.material.courseCardGlassTuning.blurSigma, 0.0) },
            assertWritten = {
                val map = it as Map<*, *>
                assertEquals(3.0, (map["blurSigma"] as Number).toDouble(), 0.0)
            },
        ),
        KeyCase(
            key = "homePageWallpaperPath",
            // 清壁纸：合并写里只能靠**显式 null** 把键清掉（省略 = 保留旧值）。
            mutate = { it.copy(homePageWallpaperPath = null) },
            assertState = {
                assertNull(it.wallpaper.path)
                assertFalse(it.wallpaper.hasBackdrop)
                assertFalse(it.material.hasHomePageBackdrop)
            },
            assertWritten = { assertNull(it) },
        ),
        KeyCase(
            key = "homePageWallpaperAlignX",
            mutate = { it.copy(homePageWallpaperAlignX = -0.75) },
            assertState = { assertEquals(-0.75, it.wallpaper.alignX, 0.0) },
            assertWritten = { assertEquals(-0.75, (it as Number).toDouble(), 0.0) },
        ),
        KeyCase(
            key = "homePageWallpaperAlignY",
            mutate = { it.copy(homePageWallpaperAlignY = 0.25) },
            assertState = { assertEquals(0.25, it.wallpaper.alignY, 0.0) },
            assertWritten = { assertEquals(0.25, (it as Number).toDouble(), 0.0) },
        ),
        KeyCase(
            key = "homePageWallpaperScale",
            mutate = { it.copy(homePageWallpaperScale = 3.0) },
            assertState = { assertEquals(3.0, it.wallpaper.scale, 0.0) },
            assertWritten = { assertEquals(3.0, (it as Number).toDouble(), 0.0) },
        ),
        KeyCase(
            key = "homePageWallpaperBlurSigma",
            mutate = { it.copy(homePageWallpaperBlurSigma = 10.0) },
            assertState = { assertEquals(10.0, it.wallpaper.blurSigma, 0.0) },
            assertWritten = { assertEquals(10.0, (it as Number).toDouble(), 0.0) },
        ),
        KeyCase(
            key = "wallpaperHistory",
            mutate = {
                it.copy(
                    wallpaperHistory = listOf(
                        WallpaperHistoryRowModel(
                            key = "/files/b.jpg",
                            alignX = 0.1,
                            alignY = -0.2,
                            scale = 1.5,
                            usedAt = 42L,
                        ),
                    ),
                )
            },
            assertState = {
                val row = it.wallpaper.history.single()
                assertEquals("/files/b.jpg", row.key)
                assertEquals("b.jpg", row.label)
                assertEquals(0.1, row.alignX, 0.0)
                assertEquals(-0.2, row.alignY, 0.0)
                assertEquals(1.5, row.scale, 0.0)
                assertEquals(42L, row.usedAt)
            },
            assertWritten = {
                val rows = it as List<*>
                assertEquals(1, rows.size)
                val map = rows.single() as Map<*, *>
                assertEquals("/files/b.jpg", map["key"])
                assertEquals(0.1, (map["alignX"] as Number).toDouble(), 0.0)
                assertEquals(1.5, (map["scale"] as Number).toDouble(), 0.0)
                assertEquals(42L, (map["usedAt"] as Number).toLong())
            },
        ),
        KeyCase(
            key = "homePageBackdropFollowsWeekPager",
            mutate = { it.copy(homePageBackdropFollowsWeekPager = false) },
            assertState = { assertFalse(it.wallpaper.followsWeekPager) },
            assertWritten = { assertEquals(false, it) },
        ),
    )

    @Test
    fun `每条新键：改键 到 状态变 到 回写 存档其它键一个不少`() {
        val raw = storeOf(seededJson)
        val store = TimetableSettingsModelStore(TimetableStore(raw))
        var previous = rawSettings(raw)

        for (case in keyCases()) {
            val current = store.load()
            val changed = case.mutate(current)
            assertNotEquals("${case.key}：用例没有真的改动模型", current, changed)

            // ① 改键 → 状态变
            case.assertState(stateOf(changed))

            // ② 补丁边界：除本键（与它的联动键）外，别的键**逐条不变**。
            //    这一条防的是「改一个开关顺手把别人的字段也写了」。
            val beforePatch = current.toJsonPatch()
            val afterPatch = changed.toJsonPatch()
            for (key in afterPatch.keys) {
                if (key == case.key || key in case.linkedKeys) continue
                assertEquals("${case.key}：改键顺手改了 $key", beforePatch[key], afterPatch[key])
            }

            // ③ 回写（读-合并-写）→ 该键写成预期值
            store.save(changed)
            val written = rawSettings(raw)
            case.assertWritten(written[case.key])

            // ④ 存档其它键一个不少：上一版盘上有的键，这一版必须都还在
            for (key in previous.keys) {
                assertTrue("${case.key}：回写把 $key 弄丢了", written.containsKey(key))
            }
            previous = written
        }
    }

    @Test
    fun `回写不动别人的键`() {
        // 「读-合并-写」的全部意义：本模型只覆盖 OWNED_KEYS，别人的键（学期 / 节次 /
        // 超级岛 / 本模型还不认识的未来键）必须原样留在盘上。
        val raw = storeOf(seededJson)
        val store = TimetableSettingsModelStore(TimetableStore(raw))
        val seeded = store.load()
        val before = rawSettings(raw)

        store.save(seeded.copy(frostedBlurEnabled = false))
        val after = rawSettings(raw)

        val owned = TimetableSettingsModel.OWNED_KEYS.toSet()
        for (key in before.keys.filter { it !in owned }) {
            assertTrue("回写把不归本模型管的 $key 弄丢了", after.containsKey(key))
            assertEquals("回写改坏了不归本模型管的 $key", before[key], after[key])
        }

        // 本模型拥有的其它键，也必须与「原样存一遍、什么都没改」的结果逐条一致
        val reference = storeOf(seededJson)
        TimetableSettingsModelStore(TimetableStore(reference)).save(seeded)
        val expected = rawSettings(reference)
        for (key in owned) {
            if (key == "frostedBlurEnabled") continue
            assertEquals("回写改坏了本模型拥有的 $key", expected[key], after[key])
            assertEquals("frostedBlurEnabled 没写进去", false, after["frostedBlurEnabled"])
        }
    }

    // ------------------------------------------------- 结构守卫 / 两处档位表

    @Test
    fun `新键在 OWNED_KEYS 与 toJsonPatch 里齐全`() {
        val patch = TimetableSettingsModel().toJsonPatch()
        assertEquals(TimetableSettingsModel.OWNED_KEYS.toSet(), patch.keys)

        val newKeys = setOf(
            "frostedBlurEnabled", "homePageHeaderBlurEnabled", "homeBandGlassMaterial",
            "liquidGlassPreset", "liquidGlassTuning", "liquidGlassTuningDark",
            "linkLiquidGlassTuning", "darkGlassBoostEnabled", "liquidGlassDockEnabled",
            "courseCardGlassPreset", "courseCardGlassTuning",
            "homePageWallpaperPath", "homePageWallpaperAlignX", "homePageWallpaperAlignY",
            "homePageWallpaperScale", "homePageWallpaperBlurSigma", "wallpaperHistory",
            "homePageBackdropFollowsWeekPager",
        )
        assertEquals(newKeys, newKeys.intersect(patch.keys))
        assertEquals(newKeys, newKeys.intersect(TimetableSettingsModel.OWNED_KEYS.toSet()))
    }

    @Test
    fun `两处 10 格档位表必须逐字段相等`() {
        // 一份在 app/（模型读侧收敛与写路径用），一份在 pages/settings/（渲染与滑杆用）。
        // 分成两份是架构边界（app/ 不能 import pages/）逼出来的，数值必须一模一样。
        assertEquals(SettingsMaterialModel.PRESET_VALUES, LiquidGlassTuningModel.PRESET_VALUES)
        assertEquals(SettingsMaterialModel.PRESET_VALUES.size, LiquidGlassTuningModel.PRESET_TUNINGS.size)

        LiquidGlassTuningModel.PRESET_VALUES.forEachIndexed { index, preset ->
            val model = LiquidGlassTuningModel.PRESET_TUNINGS[index]
            val panel = LiquidGlassTuning.PRESET_TUNINGS[index]
            assertEquals("第 ${index + 1} 格（$preset）折射", panel.refraction, model.refraction, 0.0)
            assertEquals("第 ${index + 1} 格（$preset）作用带", panel.refractionBand, model.refractionBand, 0.0)
            assertEquals(
                "第 ${index + 1} 格（$preset）陡缓",
                panel.refractionEdgePow,
                model.refractionEdgePow,
                0.0,
            )
            assertEquals("第 ${index + 1} 格（$preset）色散", panel.dispersion, model.dispersion, 0.0)
            assertEquals("第 ${index + 1} 格（$preset）边光强度", panel.rimStrength, model.rimStrength, 0.0)
            assertEquals("第 ${index + 1} 格（$preset）边光宽度", panel.rimWidth, model.rimWidth, 0.0)
            assertEquals("第 ${index + 1} 格（$preset）模糊", panel.blurSigma, model.blurSigma, 0.0)
            assertEquals("第 ${index + 1} 格（$preset）染色", panel.tintAlpha, model.tintAlpha, 0.0)
        }
        // 出厂值也必须一致（第 7 格）
        assertEquals(LiquidGlassTuning.DEFAULTS, stateOf(TimetableSettingsModel()).material.liquidGlassTuning)
    }

    // ------------------------------------------------------ 渲染侧真的活了

    @Test
    fun `面板节点树读的是桥后的状态`() {
        // 模糊关掉 ⇒ 「默认材质」那格显示实体，且整块高级材质不渲染（:1019-1021）
        val solidState = stateOf(TimetableSettingsModel(frostedBlurEnabled = false))
        val solidSpec = SettingsMaterialGeneralPage.spec(SettingsPageState(), solidState.material)
        assertEquals("solid", solidSpec.row("material.general.glassMode.row").selectedOptionId)
        assertFalse(
            "实体档不该渲染高级材质那一段",
            solidSpec.flattenedIds().contains("material.general.preset"),
        )

        // 打开独立深色档 ⇒ 那行开关显示「开」（字段存的是「是否跟随」，显示要取反，:1106-1109）
        val independent = stateOf(TimetableSettingsModel(linkLiquidGlassTuning = false))
        val independentSpec = SettingsMaterialGeneralPage.spec(SettingsPageState(), independent.material)
        assertEquals(true, independentSpec.row("material.general.darkIndependent").switchValue)
        // 深色档八根旋钮这时才出现（:1130-1139）
        assertTrue(
            independentSpec.flattenedIds().contains("material.general.darkTuning.refraction"),
        )
        // 而「跟随」状态下不出现
        val linked = stateOf(TimetableSettingsModel(linkLiquidGlassTuning = true))
        assertFalse(
            SettingsMaterialGeneralPage.spec(SettingsPageState(), linked.material)
                .flattenedIds()
                .contains("material.general.darkTuning.refraction"),
        )

        // 有壁纸 + 卡片档为液态 ⇒ 表面地图报液态玻璃；没壁纸一律实体（surface_material.dart:96-107）
        val withWallpaper = stateOf(
            TimetableSettingsModel(
                frostedBlurEnabled = true,
                homePageWallpaperPath = "/files/a.jpg",
                courseCardSurfaceStyle = AppCourseCardSurfaceStyle.LIQUID_GLASS,
            ),
        )
        assertEquals(
            SurfaceMaterialState.LIQUID_GLASS,
            SettingsMaterialModel.courseCardSurfaceMaterial(withWallpaper.material),
        )
        val withoutWallpaper = stateOf(
            TimetableSettingsModel(
                frostedBlurEnabled = true,
                courseCardSurfaceStyle = AppCourseCardSurfaceStyle.LIQUID_GLASS,
            ),
        )
        assertEquals(
            SurfaceMaterialState.SOLID,
            SettingsMaterialModel.courseCardSurfaceMaterial(withoutWallpaper.material),
        )
    }
}
