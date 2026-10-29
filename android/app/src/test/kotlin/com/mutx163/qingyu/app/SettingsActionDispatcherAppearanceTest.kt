package com.mutx163.qingyu.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 外观编辑页（材质面板 + 壁纸面板）的**写回映射**与**读侧宽容**。
 *
 * 期望值全部手推自 Dart：
 * - 写回：`lib/screens/settings/settings_appearance_editor.dart`（面板里每个控件写什么）、
 *   `lib/models/glass_mode_choice.dart`（材质两档）、
 *   `lib/screens/settings/settings_home_backdrop_flow.dart`（壁纸两根控件）；
 * - 读侧：`lib/models/timetable_settings.dart` 的 `fromJson`、
 *   `lib/models/liquid_glass_tuning.dart` 的 `fromJson` / `clamped` / `reconcileStoredPreset`、
 *   `lib/models/wallpaper_history.dart` 的 `listFromJson`。
 *
 * 本文件**不 import `pages/`**（`app/` 是每一次 L0 都收的共享模型层，反向依赖会让别的模块
 * 全部 Unresolved，见 `SettingsActionDispatcher` 的类注释）。
 */
class SettingsActionDispatcherAppearanceTest {

    private val defaults = TimetableSettingsModel()

    // ------------------------------------------------------------------ 工具

    private fun write(
        target: String?,
        rowId: String,
        model: TimetableSettingsModel = defaults,
    ): TimetableSettingsModel {
        val dispatch = SettingsActionDispatcher.dispatch(
            SettingsActionKind.WRITE_SETTING,
            target,
            rowId,
            model,
        )
        assertTrue("$rowId 应该写回，实际是 $dispatch", dispatch is SettingsDispatch.Write)
        return (dispatch as SettingsDispatch.Write).model
    }

    private fun ignored(
        target: String?,
        rowId: String,
        model: TimetableSettingsModel = defaults,
    ): SettingsDispatch.Ignored {
        val dispatch = SettingsActionDispatcher.dispatch(
            SettingsActionKind.WRITE_SETTING,
            target,
            rowId,
            model,
        )
        assertTrue("$rowId 应该被 Ignored，实际是 $dispatch", dispatch is SettingsDispatch.Ignored)
        return dispatch as SettingsDispatch.Ignored
    }

    private fun modelOf(vararg pairs: Pair<String, Any?>): TimetableSettingsModel =
        TimetableSettingsModel.fromJson(linkedMapOf(*pairs))

    // ================================================================
    // 一、每条 rowId 一例写回
    // ================================================================

    @Test
    fun `默认材质两档：实体关模糊 液态开模糊并顺带打开玻璃坞`() {
        // glass_mode_choice.dart:22-40 `applyGlassModeChoice`
        val solid = write("solid", SettingsActionDispatcher.ROW_MATERIAL_GLASS_MODE)
        assertFalse(solid.frostedBlurEnabled)

        val liquid = write(
            "liquidGlass",
            SettingsActionDispatcher.ROW_MATERIAL_GLASS_MODE,
            defaults.copy(frostedBlurEnabled = false, liquidGlassDockEnabled = false),
        )
        assertTrue(liquid.frostedBlurEnabled)
        // 液态是「整机材质」，选中它时连同唯一保留的作用范围开关一起打开
        assertTrue(liquid.liquidGlassDockEnabled)

        // 老渲染层（单行 SuperRadioButton）不带 target ⇒ 两档互切
        assertFalse(
            write(null, SettingsActionDispatcher.ROW_MATERIAL_GLASS_MODE, defaults).frostedBlurEnabled,
        )
        assertTrue(
            write(
                null,
                SettingsActionDispatcher.ROW_MATERIAL_GLASS_MODE,
                defaults.copy(frostedBlurEnabled = false),
            ).frostedBlurEnabled,
        )

        // 不认识的档不猜
        assertTrue(
            ignored("gaussian", SettingsActionDispatcher.ROW_MATERIAL_GLASS_MODE)
                .reason.contains("默认材质档"),
        )
    }

    @Test
    fun `首页顶栏玻璃三档 写回一律过 sanitize`() {
        // glass_mode_choice.dart:44-58 `applyHomeBandGlassMaterial`
        val row = SettingsActionDispatcher.ROW_MATERIAL_HOME_BAND
        assertEquals("follow", write("follow", row).homeBandGlassMaterial)
        assertEquals("solid", write("solid", row).homeBandGlassMaterial)
        assertEquals("liquid", write("liquid", row).homeBandGlassMaterial)

        // 存量渐进 / 高斯档与一切非法值都不该从写入口进来：Ignored，别静默换材质
        assertTrue(ignored("gaussian", row).reason.contains("顶栏玻璃材质"))
        assertTrue(ignored(null, row).reason.contains("顶栏玻璃材质"))
    }

    @Test
    fun `液态档位滑杆：选一格同时写档位名与那格推荐参数`() {
        // settings_appearance_editor.dart:1026-1042
        val row = SettingsActionDispatcher.ROW_MATERIAL_PRESET

        val first = write(
            "1",
            row,
            defaults.copy(liquidGlassTuning = LiquidGlassTuningModel(refraction = 20.0)),
        )
        assertEquals("clear", first.liquidGlassPreset)
        assertEquals(LiquidGlassTuningModel.PRESET_TUNINGS[0], first.liquidGlassTuning)

        val last = write("10", row)
        assertEquals("dense", last.liquidGlassPreset)
        assertEquals(24.0, last.liquidGlassTuning!!.blurSigma, 0.0)
        assertEquals(0.9, last.liquidGlassTuning!!.tintAlpha, 0.0)

        // 越界只可能来自坏值：fromStep 回落 standard（liquid_glass_tuning.dart:156-165），不崩
        val outOfRange = write("11", row)
        assertEquals("standard", outOfRange.liquidGlassPreset)
        assertEquals(LiquidGlassTuningModel.DEFAULTS, outOfRange.liquidGlassTuning)

        assertTrue(ignored("abc", row).reason.contains("液态档位"))
        assertTrue(ignored(null, row).reason.contains("液态档位"))
    }

    @Test
    fun `浅色档八根旋钮：写参数 并把档位打成自定义`() {
        // settings_appearance_editor.dart:1355-1370 `_updateLiquidTuning`
        // expectedTuning = 出厂档里**只改这一根**：用它断言「其它七根一个都没被顺手写」。
        val cases = listOf(
            TuningCase("refraction", "12", { it.refraction }, 12.0,
                LiquidGlassTuningModel.DEFAULTS.copy(refraction = 12.0)),
            TuningCase("refractionBand", "20", { it.refractionBand }, 20.0,
                LiquidGlassTuningModel.DEFAULTS.copy(refractionBand = 20.0)),
            TuningCase("edgePow", "4.5", { it.refractionEdgePow }, 4.5,
                LiquidGlassTuningModel.DEFAULTS.copy(refractionEdgePow = 4.5)),
            TuningCase("dispersion", "0.6", { it.dispersion }, 0.6,
                LiquidGlassTuningModel.DEFAULTS.copy(dispersion = 0.6)),
            TuningCase("rimStrength", "0.7", { it.rimStrength }, 0.7,
                LiquidGlassTuningModel.DEFAULTS.copy(rimStrength = 0.7)),
            TuningCase("rimWidth", "2.2", { it.rimWidth }, 2.2,
                LiquidGlassTuningModel.DEFAULTS.copy(rimWidth = 2.2)),
            TuningCase("blurSigma", "30", { it.blurSigma }, 30.0,
                LiquidGlassTuningModel.DEFAULTS.copy(blurSigma = 30.0)),
            // 面板行 id 的后缀是 `tint`，Dart 字段名是 `tintAlpha`：两种写法都必须认
            TuningCase("tint", "0.25", { it.tintAlpha }, 0.25,
                LiquidGlassTuningModel.DEFAULTS.copy(tintAlpha = 0.25)),
            TuningCase("tintAlpha", "0.4", { it.tintAlpha }, 0.4,
                LiquidGlassTuningModel.DEFAULTS.copy(tintAlpha = 0.4)),
        )
        for (case in cases) {
            val written = write(
                case.target,
                SettingsActionDispatcher.ROW_MATERIAL_TUNING_PREFIX + case.suffix,
            )
            assertEquals(
                "${case.suffix} 没写进去",
                case.expected,
                case.read(written.liquidGlassTuning!!),
                0.0,
            )
            // 动过旋钮 ⇒ 档位必须变成 custom，否则滑杆会停在一个已经不准的格子上
            assertEquals(
                TimetableSettingsModel.LIQUID_GLASS_PRESET_CUSTOM,
                written.liquidGlassPreset,
            )
            // 其它七根旋钮不被顺手写坏：整份参数必须等于「出厂档里只改这一根」
            assertEquals(
                "${case.suffix} 顺手改坏了别的旋钮",
                case.expectedTuning,
                written.liquidGlassTuning,
            )
        }

        // 越界的滑杆值按滑杆区间收口（liquid_glass_tuning.dart:522-539）
        val row = SettingsActionDispatcher.ROW_MATERIAL_TUNING_PREFIX
        assertEquals(20.0, write("99", row + "refraction").liquidGlassTuning!!.refraction, 0.0)
        assertEquals(0.0, write("-3", row + "blurSigma").liquidGlassTuning!!.blurSigma, 0.0)
        assertEquals(1.0, write("2", row + "tint").liquidGlassTuning!!.tintAlpha, 0.0)
        assertEquals(3.0, write("9", row + "rimWidth").liquidGlassTuning!!.rimWidth, 0.0)

        // 不认识的参数名：Ignored，不猜
        assertTrue(ignored("1", row + "glow").reason.contains("不认识的液态玻璃参数"))
        assertTrue(ignored("abc", row + "refraction").reason.contains("滑杆值不是数字"))
    }

    @Test
    fun `深色档八根旋钮：以浅色档为起点 只写深色参数 不动档位`() {
        // settings_appearance_editor.dart:1373-1384 `_updateDarkTuning`
        val base = defaults.copy(
            liquidGlassTuning = LiquidGlassTuningModel(refraction = 7.0),
            liquidGlassPreset = "light",
        )
        val written = write(
            "12",
            SettingsActionDispatcher.ROW_MATERIAL_DARK_TUNING_PREFIX + "refraction",
            base,
        )
        assertEquals(12.0, written.liquidGlassTuningDark!!.refraction, 0.0)
        // 回落链是「深色档 ?? 浅色档 ?? 默认」，所以没设过时从浅色那份起跳
        assertEquals(7.0, written.liquidGlassTuning!!.refraction, 0.0)
        assertEquals(LiquidGlassTuningModel.DEFAULTS.tintAlpha, written.liquidGlassTuningDark!!.tintAlpha, 0.0)
        // 深色那套没有独立档名 ⇒ 档位不动
        assertEquals("light", written.liquidGlassPreset)
    }

    @Test
    fun `材质面板那颗恢复默认：只清液态调参 不动整体材质`() {
        // settings_appearance_editor.dart:1058-1085
        val base = defaults.copy(
            liquidGlassPreset = TimetableSettingsModel.LIQUID_GLASS_PRESET_CUSTOM,
            liquidGlassTuning = LiquidGlassTuningModel(refraction = 3.0),
            liquidGlassTuningDark = LiquidGlassTuningModel(tintAlpha = 0.1),
            frostedBlurEnabled = false,
            liquidGlassDockEnabled = false,
        )
        val byRow = write(null, SettingsActionDispatcher.ROW_MATERIAL_RESET, base)
        assertEquals("standard", byRow.liquidGlassPreset)
        assertEquals(LiquidGlassTuningModel.DEFAULTS, byRow.liquidGlassTuning)
        // 别的都不动
        assertEquals(base.liquidGlassTuningDark, byRow.liquidGlassTuningDark)
        assertFalse(byRow.frostedBlurEnabled)
        assertFalse(byRow.liquidGlassDockEnabled)

        // 面板那颗按钮的 action 是 RESET_SCOPE：确认后宿主调 applyResetScope，结果必须一致
        assertEquals(
            byRow,
            SettingsActionDispatcher.applyResetScope(
                base,
                SettingsActionDispatcher.SCOPE_LIQUID_GLASS,
            ),
        )
        // 未知作用域仍然返回 null（调用方据此什么都不做）
        assertNull(SettingsActionDispatcher.applyResetScope(base, "nope"))
    }

    @Test
    fun `三个开关：深色更暗 作用范围玻璃坞 独立深色档`() {
        // 深色更暗（settings_appearance_editor.dart:1093-1104）
        assertFalse(write(null, SettingsActionDispatcher.ROW_MATERIAL_DARK_BOOST).darkGlassBoostEnabled)
        // 作用范围 → 玻璃坞（:1148-1157）
        assertFalse(write(null, SettingsActionDispatcher.ROW_MATERIAL_SCOPE_DOCK).liquidGlassDockEnabled)

        // 独立设置深色档（:1106-1118）：开关显示「独立」，字段存「是否跟随」⇒ 取反
        val independent = write(
            null,
            SettingsActionDispatcher.ROW_MATERIAL_DARK_INDEPENDENT,
            defaults.copy(liquidGlassTuning = LiquidGlassTuningModel(refraction = 6.0)),
        )
        assertFalse(independent.linkLiquidGlassTuning)
        // 第一次打开独立、从没设过深色档 ⇒ 以浅色档为起点（这一按不该让画面跳）
        assertEquals(6.0, independent.liquidGlassTuningDark!!.refraction, 0.0)

        // 再按一次 = 关掉独立 ⇒ 恢复跟随，但**保留**深色那套（copyWith 是 ?? 语义，清不掉）
        val linked = write(null, SettingsActionDispatcher.ROW_MATERIAL_DARK_INDEPENDENT, independent)
        assertTrue(linked.linkLiquidGlassTuning)
        assertEquals(independent.liquidGlassTuningDark, linked.liquidGlassTuningDark)
    }

    @Test
    fun `课程卡片页：外观档 档位 八根旋钮`() {
        // 外观档（settings_appearance_editor.dart:1244-1253）
        val row = SettingsActionDispatcher.ROW_MATERIAL_CARD_SURFACE_STYLE
        assertEquals(
            CourseCardSurfaceStyle.LIQUID_GLASS,
            write("refraction", row).courseCardSurfaceStyle,
        )
        assertEquals(CourseCardSurfaceStyle.GAUSSIAN, write("gaussian", row).courseCardSurfaceStyle)
        assertEquals(CourseCardSurfaceStyle.SOLID, write("solid", row).courseCardSurfaceStyle)
        // 老值 `liquidGlass` 早就不是档名（液态玻璃档磁盘值是 refraction）⇒ 不猜
        assertTrue(ignored("liquidGlass", row).reason.contains("课程卡片外观档"))

        // 档位（:1263-1290）：卡片与全局共用同一批常量
        val preset = write("3", SettingsActionDispatcher.ROW_MATERIAL_CARD_PRESET)
        assertEquals("level3", preset.courseCardGlassPreset)
        assertEquals(LiquidGlassTuningModel.PRESET_TUNINGS[2], preset.courseCardGlassTuning)

        // 八根旋钮（:1294-1312）：写卡片那份 + 卡片档位打自定义；全局那份一个字节都不动
        val tuned = write(
            "2",
            SettingsActionDispatcher.ROW_MATERIAL_CARD_TUNING_PREFIX + "blurSigma",
            defaults.copy(courseCardGlassTuning = LiquidGlassTuningModel(refraction = 9.0)),
        )
        assertEquals(2.0, tuned.courseCardGlassTuning!!.blurSigma, 0.0)
        assertEquals(9.0, tuned.courseCardGlassTuning!!.refraction, 0.0)
        assertEquals(TimetableSettingsModel.LIQUID_GLASS_PRESET_CUSTOM, tuned.courseCardGlassPreset)
        assertNull(tuned.liquidGlassTuning)
        assertEquals(defaults.liquidGlassPreset, tuned.liquidGlassPreset)
    }

    @Test
    fun `壁纸两根控件：随周次滑动取反 模糊按 0 到 24 收口`() {
        // settings_home_backdrop_flow.dart:786-788 / widgets/wallpaper_blur_tile.dart:56-74
        assertTrue(
            write(null, SettingsActionDispatcher.ROW_BACKDROP_FOLLOWS_WEEK_PAGER)
                .homePageBackdropFollowsWeekPager,
        )

        val blur = SettingsActionDispatcher.ROW_BACKDROP_BLUR
        assertEquals(12.0, write("12", blur).homePageWallpaperBlurSigma, 0.0)
        // 越界与 Dart 的 clampHomePageWallpaperBlurSigma 同口径（timetable_settings.dart:357-360）
        assertEquals(24.0, write("99", blur).homePageWallpaperBlurSigma, 0.0)
        assertEquals(0.0, write("-3", blur).homePageWallpaperBlurSigma, 0.0)
        assertTrue(ignored("abc", blur).reason.contains("壁纸模糊量"))
        assertTrue(ignored(null, blur).reason.contains("壁纸模糊量"))
    }

    // ================================================================
    // 二、读侧：逐键同源 + 脏数据宽容
    // ================================================================

    @Test
    fun `读侧：十八条新键的缺键默认值`() {
        val model = TimetableSettingsModel.fromJson(emptyMap())

        assertTrue(model.frostedBlurEnabled) // :292 defaultFrostedBlurEnabled
        assertTrue(model.homePageHeaderBlurEnabled) // :1829（读侧恒 true）
        assertEquals("liquid", model.homeBandGlassMaterial) // :329
        assertEquals("standard", model.liquidGlassPreset) // :928
        assertNull(model.liquidGlassTuning) // :929（null = 从没调过）
        assertNull(model.liquidGlassTuningDark) // :930
        assertTrue(model.linkLiquidGlassTuning) // :307
        assertTrue(model.darkGlassBoostEnabled) // :313
        assertTrue(model.liquidGlassDockEnabled) // :300
        assertEquals("standard", model.courseCardGlassPreset) // :934
        assertNull(model.courseCardGlassTuning) // :933

        assertNull(model.homePageWallpaperPath) // :894
        assertEquals(0.0, model.homePageWallpaperAlignX, 0.0) // :895
        assertEquals(0.0, model.homePageWallpaperAlignY, 0.0) // :896
        assertEquals(1.0, model.homePageWallpaperScale, 0.0) // :897
        assertEquals(0.0, model.homePageWallpaperBlurSigma, 0.0) // :898 = minHomePageWallpaperBlurSigma
        assertTrue(model.wallpaperHistory.isEmpty()) // :899
        assertFalse(model.homePageBackdropFollowsWeekPager) // :939
    }

    @Test
    fun `读侧：顶栏材质坏值与下线老档都归液态 顶栏开关恒开`() {
        // timetable_settings.dart:339-343 + :1837-1846
        for (raw in listOf<Any?>("gaussian", "progressive", "soft", "", 42, null)) {
            assertEquals(
                "homeBandGlassMaterial=$raw 应归液态",
                "liquid",
                modelOf("homeBandGlassMaterial" to raw).homeBandGlassMaterial,
            )
        }
        assertEquals("solid", modelOf("homeBandGlassMaterial" to "solid").homeBandGlassMaterial)
        assertEquals("follow", modelOf("homeBandGlassMaterial" to "follow").homeBandGlassMaterial)

        // :1827-1831：两个玻璃带开关已下线，存档里的 false 不读
        assertTrue(modelOf("homePageHeaderBlurEnabled" to false).homePageHeaderBlurEnabled)
    }

    @Test
    fun `读侧：档位与参数对不上时以参数为准`() {
        // liquid_glass_tuning.dart:113-129 `reconcileStoredPreset`
        val level9 = LiquidGlassTuningModel.PRESET_TUNINGS[8]

        // ① 老存档只有参数键（档位键 2026-10-05 才加）⇒ 按参数反推成那一格
        assertEquals(
            "level9",
            modelOf("liquidGlassTuning" to level9.toJson()).liquidGlassPreset,
        )
        // ② 档位键与参数键矛盾（扩格时改过三档的推荐值）⇒ 面板不许说谎，按参数反推
        assertEquals(
            "level9",
            modelOf(
                "liquidGlassPreset" to "light",
                "liquidGlassTuning" to level9.toJson(),
            ).liquidGlassPreset,
        )
        // ③ 参数不精确等于任何一格 ⇒ custom
        assertEquals(
            "custom",
            modelOf("liquidGlassTuning" to mapOf<String, Any?>("refraction" to 12.5))
                .liquidGlassPreset,
        )
        // ④ 没有参数键 ⇒ 档位键原样；不认识的档位归 standard（绝不归 custom）
        assertEquals("light", modelOf("liquidGlassPreset" to "light").liquidGlassPreset)
        assertEquals("custom", modelOf("liquidGlassPreset" to "custom").liquidGlassPreset)
        assertEquals("standard", modelOf("liquidGlassPreset" to "nonsense").liquidGlassPreset)
        assertEquals("standard", modelOf("liquidGlassPreset" to 42).liquidGlassPreset)
        // ⑤ 档位键等于某一格、参数也等于该格 ⇒ 原样保留（不因为"用了自定义"被抹掉）
        assertEquals(
            "dense",
            modelOf(
                "liquidGlassPreset" to "dense",
                "liquidGlassTuning" to LiquidGlassTuningModel.PRESET_TUNINGS[9].toJson(),
            ).liquidGlassPreset,
        )
        // ⑥ 卡片那份走同一个收敛（course_glass_tuning.dart:73-124 与全局同值）
        assertEquals(
            "dense",
            modelOf("courseCardGlassTuning" to LiquidGlassTuningModel.PRESET_TUNINGS[9].toJson())
                .courseCardGlassPreset,
        )
    }

    @Test
    fun `读侧：八项参数逐项收口 缺项取出厂值`() {
        // liquid_glass_tuning.dart:605-624 `.clamped()`
        val tuning = modelOf(
            "liquidGlassTuning" to linkedMapOf<String, Any?>(
                "refraction" to 99,
                "rimWidth" to -1,
                "tintAlpha" to 2,
                "blurSigma" to 100,
            ),
        ).liquidGlassTuning!!
        assertEquals(20.0, tuning.refraction, 0.0)
        assertEquals(0.0, tuning.rimWidth, 0.0)
        assertEquals(1.0, tuning.tintAlpha, 0.0)
        assertEquals(40.0, tuning.blurSigma, 0.0)
        // 缺的项 = 出厂值（第 7 格）
        assertEquals(11.0, tuning.refractionBand, 0.0)
        assertEquals(2.5, tuning.refractionEdgePow, 0.0)
        assertEquals(0.35, tuning.dispersion, 0.0)
        assertEquals(0.2, tuning.rimStrength, 0.0)

        // 非 Map ⇒ 整个参数对象当没写过（null），不抛
        assertNull(modelOf("liquidGlassTuning" to "oops").liquidGlassTuning)
        assertNull(modelOf("liquidGlassTuningDark" to listOf(1, 2)).liquidGlassTuningDark)
    }

    @Test
    fun `读侧：最近使用历史里的脏条目逐条丢弃`() {
        // wallpaper_history.dart:78-108
        val model = modelOf(
            "wallpaperHistory" to listOf<Any?>(
                mapOf("key" to "/a.jpg", "alignX" to 0.5, "scale" to 2, "usedAt" to 5),
                "不是 map",
                mapOf("key" to ""), // 空 key ⇒ 脏（isValid 走 trim）
                mapOf("key" to "   "), // 只有空白 ⇒ 脏
                mapOf("alignX" to 1.0), // 缺 key ⇒ 脏
                // 字符串数字**不认**（只认 num，见 wallpaper_history.dart:69-98）
                mapOf("key" to "/b.jpg", "alignX" to "0.7", "usedAt" to "8"),
            ),
        )
        val rows = model.wallpaperHistory
        assertEquals(2, rows.size)

        assertEquals("/a.jpg", rows[0].key)
        assertEquals(0.5, rows[0].alignX, 0.0)
        assertEquals(0.0, rows[0].alignY, 0.0)
        assertEquals(2.0, rows[0].scale, 0.0)
        assertEquals(5L, rows[0].usedAt)

        assertEquals("/b.jpg", rows[1].key)
        assertEquals(0.0, rows[1].alignX, 0.0) // 字符串数字按缺失 ⇒ 0
        assertEquals(1.0, rows[1].scale, 0.0) // 存量没有 scale ⇒ 1（刚好铺满）
        assertEquals(0L, rows[1].usedAt) // 存量没有 usedAt ⇒ 0

        // 非 List ⇒ 空表（不是 null、不抛）
        assertTrue(modelOf("wallpaperHistory" to 42).wallpaperHistory.isEmpty())
    }

    @Test
    fun `写侧：十八条键都在补丁里 可空键显式写 null`() {
        val patch = TimetableSettingsModel().toJsonPatch()
        for (key in listOf(
            "liquidGlassTuning",
            "liquidGlassTuningDark",
            "courseCardGlassTuning",
            "homePageWallpaperPath",
        )) {
            // 合并写下「省略」= 保留旧值，只有显式 null 才能清掉
            assertTrue("$key 必须在补丁里且写成 null", patch.containsKey(key))
            assertNull(patch[key])
        }
        // 历史写成数组：空表也要写，否则盘上那份旧历史清不掉
        assertEquals(emptyList<Any?>(), patch["wallpaperHistory"])
        // 档位写存档值（不是枚举名），与 Dart `toJson` 同口径（:1261 / :1270）
        assertEquals("standard", patch["courseCardGlassPreset"])
        assertEquals("standard", patch["liquidGlassPreset"])
        assertEquals("liquid", patch["homeBandGlassMaterial"])
    }

    /**
     * 一条旋钮用例。
     *
     * @param suffix rowId 后缀（面板行 id 的最后一段）。
     * @param target 渲染层传来的 target（滑杆的数字字符串）。
     * @param read 读哪一根（断言用）。
     * @param expected 该根写成的值。
     * @param expectedTuning 写完之后**整份**参数（出厂档里只改这一根）——用来钉「没顺手改别的」。
     */
    private class TuningCase(
        val suffix: String,
        val target: String,
        val read: (LiquidGlassTuningModel) -> Double,
        val expected: Double,
        val expectedTuning: LiquidGlassTuningModel,
    )
}
