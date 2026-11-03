package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 液态玻璃调参与「各表面当前材质」推导的模型测试（P3-B-1）。
 *
 * 期望值全部从 Dart 源**手推**，不从 Kotlin 实现倒推：
 * - 参数上下限 / 出厂值：`lib/models/liquid_glass_tuning.dart:410-474`；
 * - 10 格档位表：同文件 `:254-368`（`presetClear` … `presetDense`）；
 * - 就近档位：同文件 `:388-406`（只按模糊与染色两项、各自归一化后等权）；
 * - 表面材质推导：`lib/models/surface_material.dart:41-107`；
 * - 玻璃档总闸：`lib/models/glass_mode_choice.dart:22-24`。
 */
class SettingsMaterialModelTest {

    // ------------------------------------------------------------ 出厂参数

    @Test
    fun `出厂档就是标准档那八个值`() {
        // liquid_glass_tuning.dart:410-451
        val d = LiquidGlassTuning.DEFAULTS
        // 2026-11-03 收档（`845dd9a49`）：位移 8→6、作用带 11→8。
        assertEquals(6.0, d.refraction, 0.0)
        assertEquals(8.0, d.refractionBand, 0.0)
        assertEquals(2.5, d.refractionEdgePow, 0.0)
        assertEquals(0.35, d.dispersion, 0.0)
        assertEquals(0.2, d.rimStrength, 0.0)
        assertEquals(1.5, d.rimWidth, 0.0)
        assertEquals(15.0, d.blurSigma, 0.0)
        assertEquals(0.70, d.tintAlpha, 0.0)
    }

    @Test
    fun `上下限逐个对得上 Dart 常量`() {
        // liquid_glass_tuning.dart:457-474
        assertEquals(0.0, LiquidGlassTuning.MIN_REFRACTION, 0.0)
        // 2026-11-03 收档（`845dd9a49`）：位移上限 20→10、作用带上限 24→12。
        assertEquals(10.0, LiquidGlassTuning.MAX_REFRACTION, 0.0)
        assertEquals(1.0, LiquidGlassTuning.MIN_REFRACTION_BAND, 0.0)
        assertEquals(12.0, LiquidGlassTuning.MAX_REFRACTION_BAND, 0.0)
        assertEquals(1.0, LiquidGlassTuning.MIN_REFRACTION_EDGE_POW, 0.0)
        assertEquals(6.0, LiquidGlassTuning.MAX_REFRACTION_EDGE_POW, 0.0)
        assertEquals(0.0, LiquidGlassTuning.MIN_DISPERSION, 0.0)
        assertEquals(1.0, LiquidGlassTuning.MAX_DISPERSION, 0.0)
        assertEquals(0.0, LiquidGlassTuning.MIN_RIM_STRENGTH, 0.0)
        assertEquals(1.0, LiquidGlassTuning.MAX_RIM_STRENGTH, 0.0)
        assertEquals(0.0, LiquidGlassTuning.MIN_RIM_WIDTH, 0.0)
        assertEquals(3.0, LiquidGlassTuning.MAX_RIM_WIDTH, 0.0)
        assertEquals(0.0, LiquidGlassTuning.MIN_BLUR_SIGMA, 0.0)
        assertEquals(40.0, LiquidGlassTuning.MAX_BLUR_SIGMA, 0.0)
        assertEquals(0.0, LiquidGlassTuning.MIN_TINT_ALPHA, 0.0)
        assertEquals(1.0, LiquidGlassTuning.MAX_TINT_ALPHA, 0.0)
        // 卡片那根模糊的上限是预糊位图的出图上限（preblurred_wallpaper_glass.dart:433）
        assertEquals(24.0, LiquidGlassTuning.PREBLUR_MAX_SIGMA, 0.0)
    }

    @Test
    fun `档位阶梯一共十格且首尾是薄厚两端`() {
        // LiquidGlassPresetX.builtIns（:135-146）
        assertEquals(10, LiquidGlassTuning.PRESET_STEPS)
        assertEquals(10, LiquidGlassTuning.PRESET_TUNINGS.size)
        // 第 1 格：染色与模糊都归零（:254-266）
        assertEquals(0.0, LiquidGlassTuning.PRESET_TUNINGS[0].blurSigma, 0.0)
        assertEquals(0.0, LiquidGlassTuning.PRESET_TUNINGS[0].tintAlpha, 0.0)
        // 第 7 格就是出厂档
        assertEquals(LiquidGlassTuning.DEFAULTS, LiquidGlassTuning.PRESET_TUNINGS[6])
        // 第 10 格：模糊封在 24、染色 0.9（刻意不到 1，:357-368）
        assertEquals(24.0, LiquidGlassTuning.PRESET_TUNINGS[9].blurSigma, 0.0)
        assertEquals(0.9, LiquidGlassTuning.PRESET_TUNINGS[9].tintAlpha, 0.0)
    }

    @Test
    fun `每一格都落在滑杆格点上`() {
        // 人推的两条硬约束：模糊是 0~40 的整数档，染色是 0~1 的 0.05 步长
        // （:1461-1465：10 格预设的染色全都落在 divisions=20 的格点上）
        LiquidGlassTuning.PRESET_TUNINGS.forEachIndexed { index, tuning ->
            assertEquals(
                "第 ${index + 1} 格的模糊必须是整数（滑杆每格 1）",
                tuning.blurSigma,
                Math.round(tuning.blurSigma).toDouble(),
                0.0,
            )
            assertEquals(
                "第 ${index + 1} 格的染色必须是 0.05 的整数倍（divisions=20）",
                tuning.tintAlpha * 20,
                Math.round(tuning.tintAlpha * 20).toDouble(),
                1e-9,
            )
        }
    }

    // ------------------------------------------------------------ 就近档位

    @Test
    fun `出厂参数落在第七格`() {
        // :388-406：两格都被精确命中时距离为 0
        assertEquals(7, LiquidGlassTuning.nearestStep(LiquidGlassTuning.DEFAULTS))
    }

    @Test
    fun `最薄与最厚各自贴边`() {
        assertEquals(1, LiquidGlassTuning.nearestStep(LiquidGlassTuning(blurSigma = 0.0, tintAlpha = 0.0)))
        assertEquals(
            10,
            LiquidGlassTuning.nearestStep(LiquidGlassTuning(blurSigma = 40.0, tintAlpha = 1.0)),
        )
    }

    @Test
    fun `只有模糊与染色参与距离计算`() {
        // 折射 / 作用带 / 陡缓 / 色散 / 高光 / 带宽 六项都不在距离里（:386-387）
        val tweaked = LiquidGlassTuning(
            refraction = 0.0,
            refractionBand = 24.0,
            refractionEdgePow = 6.0,
            dispersion = 1.0,
            rimStrength = 1.0,
            rimWidth = 3.0,
        )
        assertEquals(7, LiquidGlassTuning.nearestStep(tweaked))
    }

    @Test
    fun `模糊拖大档位就往右走`() {
        // 人推：模糊 18、染色 0.75 正是第 8 格的推荐值
        assertEquals(8, LiquidGlassTuning.nearestStep(LiquidGlassTuning(blurSigma = 18.0, tintAlpha = 0.75)))
        // 模糊 3、染色 0.2 是第 3 格
        assertEquals(3, LiquidGlassTuning.nearestStep(LiquidGlassTuning(blurSigma = 3.0, tintAlpha = 0.2)))
    }

    @Test
    fun `档位滑杆读数夹在一到十之间`() {
        // 滑杆 min=1 / max=10，越界的存档值不能把滑块顶出去
        assertEquals(1, LiquidGlassTuning.nearestStep(LiquidGlassTuning(blurSigma = -5.0, tintAlpha = -1.0)))
        assertEquals(
            10,
            LiquidGlassTuning.nearestStep(LiquidGlassTuning(blurSigma = 999.0, tintAlpha = 9.0)),
        )
    }

    @Test
    fun `模糊读数按档位上限收口`() {
        // settings_appearance_editor.dart:1481-1483：存量值高于本档上限时显示也夹到上限
        assertEquals(24.0, LiquidGlassTuning.clampBlur(40.0, LiquidGlassTuning.PREBLUR_MAX_SIGMA), 0.0)
        assertEquals(40.0, LiquidGlassTuning.clampBlur(40.0, LiquidGlassTuning.MAX_BLUR_SIGMA), 0.0)
        assertEquals(12.0, LiquidGlassTuning.clampBlur(12.0, LiquidGlassTuning.MAX_BLUR_SIGMA), 0.0)
        assertEquals(0.0, LiquidGlassTuning.clampBlur(-3.0, LiquidGlassTuning.MAX_BLUR_SIGMA), 0.0)
    }

    // --------------------------------------------------------- 内置档位存档值

    @Test
    fun `十个内置档位的存档值与顺序`() {
        // LiquidGlassPresetX.value（:62-77）：四个老值原样沿用，其余 levelN
        assertEquals(
            listOf("clear", "level2", "level3", "level4", "level5", "light", "standard", "level8", "level9", "dense"),
            SettingsMaterialModel.PRESET_VALUES,
        )
        assertEquals(1, SettingsMaterialModel.presetStepOf("clear"))
        assertEquals(7, SettingsMaterialModel.presetStepOf("standard"))
        assertEquals(10, SettingsMaterialModel.presetStepOf("dense"))
        // custom 不在阶梯上（:30-32：「用户动过旋钮」的状态，不占格位）
        assertEquals(null, SettingsMaterialModel.presetStepOf("custom"))
        assertEquals(null, SettingsMaterialModel.presetStepOf(""))
    }

    // -------------------------------------------------------- 玻璃档（总闸）

    @Test
    fun `总闸只看模糊开关`() {
        // glass_mode_choice.dart:22-24
        assertEquals(
            GlassModeChoice.SOLID,
            SettingsMaterialModel.glassModeChoice(MaterialPanelState(frostedBlurEnabled = false)),
        )
        assertEquals(
            GlassModeChoice.LIQUID_GLASS,
            SettingsMaterialModel.glassModeChoice(MaterialPanelState(frostedBlurEnabled = true)),
        )
    }

    @Test
    fun `首页顶栏玻璃的跟随档按总闸解析`() {
        // timetable_settings.dart:730-735
        assertEquals(
            "liquid",
            SettingsMaterialModel.effectiveHomeBandMaterial(
                MaterialPanelState(homeBandGlassMaterial = "follow", frostedBlurEnabled = true),
            ),
        )
        assertEquals(
            "solid",
            SettingsMaterialModel.effectiveHomeBandMaterial(
                MaterialPanelState(homeBandGlassMaterial = "follow", frostedBlurEnabled = false),
            ),
        )
        // 单独指定不被总闸改写
        assertEquals(
            "solid",
            SettingsMaterialModel.effectiveHomeBandMaterial(
                MaterialPanelState(homeBandGlassMaterial = "solid", frostedBlurEnabled = true),
            ),
        )
    }

    // ------------------------------------------------------- 各表面材质推导

    @Test
    fun `首页玻璃带：开关关掉是不渲染`() {
        // surface_material.dart:64-67
        assertEquals(
            SurfaceMaterialState.OFF,
            SettingsMaterialModel.homeBandSurfaceMaterial(
                MaterialPanelState(homePageHeaderBlurEnabled = false),
            ),
        )
    }

    @Test
    fun `首页玻璃带：三档与模糊总闸的组合`() {
        assertEquals(
            SurfaceMaterialState.LIQUID_GLASS,
            SettingsMaterialModel.homeBandSurfaceMaterial(MaterialPanelState()),
        )
        assertEquals(
            SurfaceMaterialState.SOLID,
            SettingsMaterialModel.homeBandSurfaceMaterial(
                MaterialPanelState(homeBandGlassMaterial = "solid"),
            ),
        )
        // follow + 模糊关 → 实心带
        assertEquals(
            SurfaceMaterialState.SOLID,
            SettingsMaterialModel.homeBandSurfaceMaterial(
                MaterialPanelState(homeBandGlassMaterial = "follow", frostedBlurEnabled = false),
            ),
        )
        // follow + 模糊开 → 液态带
        assertEquals(
            SurfaceMaterialState.LIQUID_GLASS,
            SettingsMaterialModel.homeBandSurfaceMaterial(
                MaterialPanelState(homeBandGlassMaterial = "follow", frostedBlurEnabled = true),
            ),
        )
        // 单独指定液态但总闸关：渲染侧一样回落实心（:70-75 的 else 分支）
        assertEquals(
            SurfaceMaterialState.SOLID,
            SettingsMaterialModel.homeBandSurfaceMaterial(
                MaterialPanelState(homeBandGlassMaterial = "liquid", frostedBlurEnabled = false),
            ),
        )
    }

    @Test
    fun `玻璃坞：作用范围开关关掉退回磨砂`() {
        // surface_material.dart:56-59 / 82-83
        assertEquals(
            SurfaceMaterialState.LIQUID_GLASS,
            SettingsMaterialModel.dockSurfaceMaterial(MaterialPanelState()),
        )
        assertEquals(
            SurfaceMaterialState.FROST,
            SettingsMaterialModel.dockSurfaceMaterial(
                MaterialPanelState(liquidGlassDockEnabled = false),
            ),
        )
        // 模糊总闸必须排在最前面：关掉一律实体，不能报成液态（:41-52）
        assertEquals(
            SurfaceMaterialState.SOLID,
            SettingsMaterialModel.dockSurfaceMaterial(
                MaterialPanelState(frostedBlurEnabled = false, liquidGlassDockEnabled = true),
            ),
        )
        assertEquals(
            SurfaceMaterialState.SOLID,
            SettingsMaterialModel.dockSurfaceMaterial(
                MaterialPanelState(frostedBlurEnabled = false, liquidGlassDockEnabled = false),
            ),
        )
    }

    @Test
    fun `课程卡片：实体档、无壁纸、总闸关都回落实体`() {
        // surface_material.dart:96-107
        assertEquals(
            SurfaceMaterialState.SOLID,
            SettingsMaterialModel.courseCardSurfaceMaterial(
                MaterialPanelState(courseCardSurfaceStyle = CourseCardSurfaceStyle.SOLID),
            ),
        )
        assertEquals(
            SurfaceMaterialState.SOLID,
            SettingsMaterialModel.courseCardSurfaceMaterial(
                MaterialPanelState(
                    courseCardSurfaceStyle = CourseCardSurfaceStyle.LIQUID_GLASS,
                    hasHomePageBackdrop = false,
                ),
            ),
        )
        assertEquals(
            SurfaceMaterialState.SOLID,
            SettingsMaterialModel.courseCardSurfaceMaterial(
                MaterialPanelState(
                    courseCardSurfaceStyle = CourseCardSurfaceStyle.GAUSSIAN,
                    frostedBlurEnabled = false,
                    hasHomePageBackdrop = true,
                ),
            ),
        )
    }

    @Test
    fun `课程卡片：液态与高斯各报自己那一档`() {
        assertEquals(
            SurfaceMaterialState.LIQUID_GLASS,
            SettingsMaterialModel.courseCardSurfaceMaterial(
                MaterialPanelState(
                    courseCardSurfaceStyle = CourseCardSurfaceStyle.LIQUID_GLASS,
                    hasHomePageBackdrop = true,
                ),
            ),
        )
        assertEquals(
            SurfaceMaterialState.FROST_GAUSSIAN,
            SettingsMaterialModel.courseCardSurfaceMaterial(
                MaterialPanelState(
                    courseCardSurfaceStyle = CourseCardSurfaceStyle.GAUSSIAN,
                    hasHomePageBackdrop = true,
                ),
            ),
        )
    }

    @Test
    fun `材质状态的展示文案逐项对得上`() {
        // settings_appearance_editor.dart:33-41 的 _surfaceMaterialLabel
        assertEquals("已关闭", SurfaceMaterialState.OFF.label.zh)
        assertEquals("实体", SurfaceMaterialState.SOLID.label.zh)
        assertEquals("高斯模糊", SurfaceMaterialState.FROST.label.zh)
        assertEquals("渐进模糊", SurfaceMaterialState.FROST_PROGRESSIVE.label.zh)
        assertEquals("高斯模糊", SurfaceMaterialState.FROST_GAUSSIAN.label.zh)
        assertEquals("液态玻璃", SurfaceMaterialState.LIQUID_GLASS.label.zh)
    }

    // ------------------------------------------------------ 「总闸盖过本页」提示

    @Test
    fun `卡片页提示只在真的被总闸压住时出现`() {
        // settings_appearance_editor.dart:1223-1225
        assertEquals(
            false,
            SettingsMaterialModel.courseCardMaskedByMaster(MaterialPanelState()),
        )
        assertEquals(
            false,
            SettingsMaterialModel.courseCardMaskedByMaster(
                MaterialPanelState(
                    frostedBlurEnabled = false,
                    courseCardSurfaceStyle = CourseCardSurfaceStyle.SOLID,
                ),
            ),
        )
        assertEquals(
            true,
            SettingsMaterialModel.courseCardMaskedByMaster(
                MaterialPanelState(
                    frostedBlurEnabled = false,
                    courseCardSurfaceStyle = CourseCardSurfaceStyle.LIQUID_GLASS,
                ),
            ),
        )
    }
}
