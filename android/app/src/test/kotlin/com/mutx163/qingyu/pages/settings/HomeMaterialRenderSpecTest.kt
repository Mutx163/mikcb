package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.LiquidGlassTuningModel
import com.mutx163.qingyu.app.TimetableSettingsModel
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 材质设置 → 渲染快照的纯逻辑契约（2026-11-01）。
 *
 * ## 钉的是什么
 *
 * 材质面板里改的四个键（默认材质总闸 / 首页顶栏玻璃 / 玻璃坞作用范围 / 八根旋钮）
 * 曾经「能存能读、屏幕不变」——渲染层根本没有消费点。现在
 * [SettingsMaterialModel.renderSpecOf] 是唯一翻译层，本文件逐条钉住：
 *
 * 1. 总闸（`frostedBlurEnabled`）关掉后**没有任何表面**还是液态；
 * 2. 顶栏玻璃的三档 / 顶栏总开关 / 无壁纸降级；
 * 3. 玻璃坞作用范围关 → 磨砂（不是实体、也不是液态）；
 * 4. 课程卡片同时受总闸、壁纸、外观档三者约束；
 * 5. 旋钮值（染色 / 模糊）逐数透传；深色独立档与深色配方和 Dart
 *    `LiquidGlassDarkRecipe`（`liquid_glass_tuning.dart:676-740`）同口径。
 *
 * 这里**只断言纯函数**：渲染层把 `band/dock/courseCard` 画成什么由各页的
 * Compose 实现负责（真机验证归用户）。
 */
class HomeMaterialRenderSpecTest {

    private fun model(
        frosted: Boolean = true,
        headerBlur: Boolean = true,
        band: String = TimetableSettingsModel.HOME_BAND_LIQUID,
        dockOn: Boolean = true,
        cardStyle: com.mutx163.qingyu.app.CourseCardSurfaceStyle =
            com.mutx163.qingyu.app.CourseCardSurfaceStyle.LIQUID_GLASS,
        lightTuning: LiquidGlassTuningModel? = null,
        darkTuning: LiquidGlassTuningModel? = null,
        link: Boolean = true,
        darkBoost: Boolean = true,
        cardTuning: LiquidGlassTuningModel? = null,
    ): TimetableSettingsModel = TimetableSettingsModel(
        frostedBlurEnabled = frosted,
        homePageHeaderBlurEnabled = headerBlur,
        homeBandGlassMaterial = band,
        liquidGlassDockEnabled = dockOn,
        courseCardSurfaceStyle = cardStyle,
        liquidGlassTuning = lightTuning,
        liquidGlassTuningDark = darkTuning,
        linkLiquidGlassTuning = link,
        darkGlassBoostEnabled = darkBoost,
        courseCardGlassTuning = cardTuning,
    )

    private fun spec(
        model: TimetableSettingsModel,
        isDark: Boolean = false,
        hasBackdrop: Boolean = true,
    ) = SettingsMaterialModel.renderSpecOf(model, isDark = isDark, hasBackdrop = hasBackdrop)

    // ------------------------------------------------------------------ 总闸

    @Test
    fun `总闸开着时顶栏带 玻璃坞 液堂课卡都是液态`() {
        val result = spec(model())
        assertEquals(SurfaceMaterialState.LIQUID_GLASS, result.band)
        assertEquals(SurfaceMaterialState.LIQUID_GLASS, result.dock)
        assertEquals(SurfaceMaterialState.LIQUID_GLASS, result.courseCard)
    }

    @Test
    fun `总闸关掉后三个表面全部回实体`() {
        // Dart `glass_mode_choice`：实体卡片 = frostedBlurEnabled false，
        // 它不是第三种材质，而是「整机不要玻璃」。
        val result = spec(model(frosted = false, band = TimetableSettingsModel.HOME_BAND_FOLLOW))
        assertEquals(SurfaceMaterialState.SOLID, result.band)
        assertEquals(SurfaceMaterialState.SOLID, result.dock)
        assertEquals(SurfaceMaterialState.SOLID, result.courseCard)
    }

    // ------------------------------------------------------------- 顶栏玻璃带

    @Test
    fun `顶栏玻璃跟随默认时按总闸解析`() {
        assertEquals(
            SurfaceMaterialState.LIQUID_GLASS,
            spec(model(band = TimetableSettingsModel.HOME_BAND_FOLLOW)).band,
        )
        assertEquals(
            SurfaceMaterialState.SOLID,
            spec(model(band = TimetableSettingsModel.HOME_BAND_FOLLOW, frosted = false)).band,
        )
    }

    @Test
    fun `顶栏玻璃单独选实体时总闸开着也画实心条`() {
        assertEquals(
            SurfaceMaterialState.SOLID,
            spec(model(band = TimetableSettingsModel.HOME_BAND_SOLID)).band,
        )
    }

    @Test
    fun `顶栏玻璃总开关关掉时整条不画`() {
        assertEquals(
            SurfaceMaterialState.OFF,
            spec(model(headerBlur = false)).band,
        )
    }

    @Test
    fun `没有壁纸时顶栏带与课卡都降级实体 玻璃坞不受影响`() {
        // Dart `homePageHeaderUsesFrostedChrome` / `effectiveCourseCardSurfaceStyle`
        // 都在没有可用壁纸时回落实体；坞采的是页面内容，不需要壁纸。
        val result = spec(model(), hasBackdrop = false)
        assertEquals(SurfaceMaterialState.SOLID, result.band)
        assertEquals(SurfaceMaterialState.SOLID, result.courseCard)
        assertEquals(SurfaceMaterialState.LIQUID_GLASS, result.dock)
    }

    // --------------------------------------------------------------- 玻璃坞

    @Test
    fun `玻璃坞作用范围关掉时是磨砂而不是实体`() {
        assertEquals(
            SurfaceMaterialState.FROST,
            spec(model(dockOn = false)).dock,
        )
    }

    // ----------------------------------------------------------------- 旋钮

    @Test
    fun `染色与模糊旋钮逐数透传到渲染快照`() {
        val result = spec(
            model(lightTuning = LiquidGlassTuningModel(blurSigma = 5.0, tintAlpha = 0.3)),
        )
        assertEquals(0.3f, result.liquidTintAlpha, 1e-6f)
        assertEquals(5.0f, result.liquidBlurSigma, 1e-6f)
    }

    @Test
    fun `课程卡片染色取卡片自己那套参数`() {
        // 卡片与全局是两套配置（`frosted_appearance.dart:110-115`），不能混。
        val result = spec(
            model(
                lightTuning = LiquidGlassTuningModel(tintAlpha = 0.8),
                cardTuning = LiquidGlassTuningModel(tintAlpha = 0.25, blurSigma = 3.0),
            ),
        )
        assertEquals(0.8f, result.liquidTintAlpha, 1e-6f)
        assertEquals(0.25f, result.courseCardTintAlpha, 1e-6f)
        assertEquals(3.0f, result.courseCardBlurSigma, 1e-6f)
    }

    @Test
    fun `课卡预糊不吃深色配方的模糊上浮`() {
        // 课卡的 sigma 喂的是**整屏一张预糊位图**，按一个值只烤一次；
        // 深色配方的 ×1.3 是逐帧光照适配，烤进图里等于永远不生效
        //（`course_glass_tuning.dart:165-170`、`preblurred_wallpaper_glass.dart:489-492`）。
        val result = spec(
            model(
                lightTuning = LiquidGlassTuningModel(blurSigma = 8.0),
                cardTuning = LiquidGlassTuningModel(blurSigma = 10.0),
                darkBoost = true,
            ),
            isDark = true,
        )
        // 对照：全局那一路仍走实时模糊，照吃 ×1.3（8 × 1.3 = 10.4）。
        assertEquals(10.4f, result.liquidBlurSigma, 1e-6f)
        assertEquals(10.0f, result.courseCardBlurSigma, 1e-6f)
    }

    @Test
    fun `课卡预糊按出图上限 24 收口`() {
        // 卡片磨砂滑杆的上限是 `kPreblurMaxSigma = 24`（`preblurred_wallpaper_glass.dart:433`），
        // 不是全局实时模糊的 40；出图侧本来就会夹，模型这里同口径才不会显示一个到不了的档。
        val result = spec(
            model(cardTuning = LiquidGlassTuningModel(blurSigma = 40.0)),
        )
        assertEquals(24.0f, result.courseCardBlurSigma, 1e-6f)
    }

    @Test
    fun `课卡染色照吃深色 0点85 系数`() {
        // 与磨砂相反：染色是逐帧叠上去的，深色配方照吃（`liquid_glass_tuning.dart:697`）。
        val result = spec(
            model(cardTuning = LiquidGlassTuningModel(tintAlpha = 0.4)),
            isDark = true,
        )
        assertEquals(0.4f * 0.85f, result.courseCardTintAlpha, 1e-6f)
    }

    // -------------------------------------------------------- 折射（2026-11-01）

    @Test
    fun `色散旋钮逐数透传 深色 standard 配方收 0点7`() {
        // 浅色：逐数透传，喂 `lens(chromaticAberration = …)`。
        assertEquals(
            0.4f,
            spec(model(lightTuning = LiquidGlassTuningModel(dispersion = 0.4))).liquidDispersion,
            1e-6f,
        )
        // 深色 + standard（`darkGlassBoostEnabled`）：×0.7（`LiquidGlassDarkRecipe.dispersionScale`，:714）。
        assertEquals(
            0.4f * 0.7f,
            spec(
                model(lightTuning = LiquidGlassTuningModel(dispersion = 0.4), darkBoost = true),
                isDark = true,
            ).liquidDispersion,
            1e-6f,
        )
        // 深色 + legacy（开关关）：色散不动（:697-703）。
        assertEquals(
            0.4f,
            spec(
                model(lightTuning = LiquidGlassTuningModel(dispersion = 0.4), darkBoost = false),
                isDark = true,
            ).liquidDispersion,
            1e-6f,
        )
    }

    @Test
    fun `课卡折射与作用带取卡片自己那套参数`() {
        // 卡片有自己一套 `CourseGlassTuning`（`course_glass_tuning.dart:5-23`）：
        // 顶栏带 / 玻璃坞读全局那份，卡片读它自己那份，两边不许混。
        val result = spec(
            model(
                lightTuning = LiquidGlassTuningModel(refraction = 12.0, refractionBand = 16.0),
                cardTuning = LiquidGlassTuningModel(refraction = 4.0, refractionBand = 6.0),
            ),
        )
        assertEquals(12.0f, result.liquidRefraction, 1e-6f)
        assertEquals(16.0f, result.liquidRefractionBand, 1e-6f)
        assertEquals(4.0f, result.courseCardRefraction, 1e-6f)
        assertEquals(6.0f, result.courseCardRefractionBand, 1e-6f)
    }

    @Test
    fun `课卡折射与作用带按滑杆区间收口`() {
        // 折射 0..20、作用带 1..24（`liquid_glass_tuning.dart:457-474` 那一批常量，
        // 卡片直接引用它们）。旧存档 / 手改 JSON 顶出区间时不许把几何算飞。
        val result = spec(
            model(cardTuning = LiquidGlassTuningModel(refraction = 40.0, refractionBand = 40.0)),
        )
        assertEquals(20.0f, result.courseCardRefraction, 1e-6f)
        assertEquals(24.0f, result.courseCardRefractionBand, 1e-6f)
    }

    @Test
    fun `课卡色散取卡片自己那套并照吃深色配方`() {
        val result = spec(
            model(
                lightTuning = LiquidGlassTuningModel(dispersion = 0.8),
                cardTuning = LiquidGlassTuningModel(dispersion = 0.5),
                darkBoost = true,
            ),
            isDark = true,
        )
        assertEquals(0.8f * 0.7f, result.liquidDispersion, 1e-6f)
        assertEquals(0.5f * 0.7f, result.courseCardDispersion, 1e-6f)
    }

    @Test
    fun `顶栏玻璃带的外溢量随作用带加宽且有 8 的下限`() {
        // 上 / 左 / 右三条边要推到屏幕外，才只有底边在折射（Dart 同口径）。
        // 下限 8 顶住窄作用带；宽作用带按「作用带 + 1」跟着走。
        assertEquals(8f, SettingsMaterialModel.bandGlassOverdrawDp(1f), 1e-6f)
        assertEquals(12f, SettingsMaterialModel.bandGlassOverdrawDp(11f), 1e-6f)
        assertEquals(25f, SettingsMaterialModel.bandGlassOverdrawDp(24f), 1e-6f)
    }

    @Test
    fun `深色独立档生效时取深色参数并乘深色染色系数`() {
        val result = spec(
            model(
                lightTuning = LiquidGlassTuningModel(blurSigma = 8.0, tintAlpha = 0.6),
                darkTuning = LiquidGlassTuningModel(blurSigma = 10.0, tintAlpha = 0.4),
                link = false,
                darkBoost = false,
            ),
            isDark = true,
        )
        // legacy 配方：染色 0.85、模糊不动（`liquid_glass_tuning.dart:697-705`）。
        assertEquals(0.4f * 0.85f, result.liquidTintAlpha, 1e-6f)
        assertEquals(10.0f, result.liquidBlurSigma, 1e-6f)
    }

    @Test
    fun `深色跟随浅色档时套变暗配方的模糊上浮`() {
        val result = spec(
            model(
                lightTuning = LiquidGlassTuningModel(blurSigma = 10.0, tintAlpha = 0.4),
                link = true,
                darkBoost = true,
            ),
            isDark = true,
        )
        // standard 配方：染色 0.85、模糊 ×1.3、边光 ×0.6（`:709-719`）。
        assertEquals(0.4f * 0.85f, result.liquidTintAlpha, 1e-6f)
        assertEquals(13.0f, result.liquidBlurSigma, 1e-6f)
        assertEquals(0.2f * 0.6f, result.liquidRimStrength, 1e-6f)
    }

    @Test
    fun `浅色模式不吃深色配方`() {
        val result = spec(
            model(lightTuning = LiquidGlassTuningModel(blurSigma = 10.0, tintAlpha = 0.4)),
            isDark = false,
        )
        assertEquals(0.4f, result.liquidTintAlpha, 1e-6f)
        assertEquals(10.0f, result.liquidBlurSigma, 1e-6f)
        assertEquals(0.2f, result.liquidRimStrength, 1e-6f)
    }

    // ----------------------------------------------------------------- 面板同源

    @Test
    fun `面板状态与渲染快照同源`() {
        // 两个 CourseCardSurfaceStyle 枚举（app 落盘 / 本包界面）只在这里翻译一次。
        val panel = SettingsMaterialModel.panelStateOf(
            model(cardStyle = com.mutx163.qingyu.app.CourseCardSurfaceStyle.LIQUID_GLASS),
            hasBackdrop = true,
        )
        assertEquals(CourseCardSurfaceStyle.LIQUID_GLASS, panel.courseCardSurfaceStyle)
        assertEquals(
            SettingsMaterialModel.courseCardSurfaceMaterial(panel),
            spec(model()).courseCard,
        )
    }
}
