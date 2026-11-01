package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.LiquidGlassTuningModel
import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.app.CourseCardSurfaceStyle as ModelCourseCardSurfaceStyle
import kotlin.math.abs

/**
 * 「材质与液态玻璃」的纯 Kotlin 模型（P3-B-1）。
 *
 * 逐字搬运三个 Dart 源里的**纯函数**部分，好让「面板上拖这根滑杆，档位与表面地图
 * 会怎么变」能在 JVM 单测里断言，不需要真机、不需要渲染：
 *
 * | Dart 源 | 本文件 |
 * |---|---|
 * | `lib/models/liquid_glass_tuning.dart` | [LiquidGlassTuning] / `PRESET_TUNINGS` / `nearestStep` |
 * | `lib/models/glass_mode_choice.dart` | [GlassModeChoice] / [SettingsMaterialModel.glassModeChoice] |
 * | `lib/models/surface_material.dart` | [SurfaceMaterialState] / 三个 `*SurfaceMaterial` |
 *
 * ## 为什么不直接 import 共享件
 *
 * `SettingsPageState.kt` 是设置族共享件（四条泳道同时在用），本轮四页需要的一批
 * 材质字段（`frostedBlurEnabled` / `liquidGlassTuning` / `homeBandGlassMaterial` …）
 * 里面还没有。往共享件里加字段会与同时进行的 P3-B-2/3/4 撞车，所以这里用一个
 * 页面私有输入 [MaterialPanelState] 承载它们；[SettingsPageState] 已有的字段
 * （`courseCardSurfaceStyle`）仍从那边取，不复制第二份真源。
 */
data class LiquidGlassTuning(
    val refraction: Double = DEFAULT_REFRACTION,
    val refractionBand: Double = DEFAULT_REFRACTION_BAND,
    val refractionEdgePow: Double = DEFAULT_REFRACTION_EDGE_POW,
    val dispersion: Double = DEFAULT_DISPERSION,
    val rimStrength: Double = DEFAULT_RIM_STRENGTH,
    val rimWidth: Double = DEFAULT_RIM_WIDTH,
    val blurSigma: Double = DEFAULT_BLUR_SIGMA,
    val tintAlpha: Double = DEFAULT_TINT_ALPHA,
) {
    companion object {
        // ---- 出厂值（即第 7 格「标准」）：liquid_glass_tuning.dart:410-451
        const val DEFAULT_REFRACTION = 8.0
        const val DEFAULT_REFRACTION_BAND = 11.0
        const val DEFAULT_REFRACTION_EDGE_POW = 2.5
        const val DEFAULT_DISPERSION = 0.35
        const val DEFAULT_RIM_STRENGTH = 0.2
        const val DEFAULT_RIM_WIDTH = 1.5
        const val DEFAULT_BLUR_SIGMA = 15.0
        const val DEFAULT_TINT_ALPHA = 0.70

        // ---- 上下限：同文件 :457-474
        const val MIN_REFRACTION = 0.0
        const val MAX_REFRACTION = 20.0
        const val MIN_REFRACTION_BAND = 1.0
        const val MAX_REFRACTION_BAND = 24.0
        const val MIN_REFRACTION_EDGE_POW = 1.0
        const val MAX_REFRACTION_EDGE_POW = 6.0
        const val MIN_DISPERSION = 0.0
        const val MAX_DISPERSION = 1.0
        const val MIN_RIM_STRENGTH = 0.0
        const val MAX_RIM_STRENGTH = 1.0
        const val MIN_RIM_WIDTH = 0.0
        const val MAX_RIM_WIDTH = 3.0
        const val MIN_BLUR_SIGMA = 0.0
        const val MAX_BLUR_SIGMA = 40.0
        const val MIN_TINT_ALPHA = 0.0
        const val MAX_TINT_ALPHA = 1.0

        /**
         * 课程卡片那根磨砂滑杆的上限（`kPreblurMaxSigma`，
         * `lib/widgets/preblurred_wallpaper_glass.dart:433`）。
         *
         * 卡片的磨砂量只喂那张预糊位图，出图侧把它夹在这个值上；滑杆不跟着收口
         * 就会两头都是死区（0~1 全等于 2、25~40 全等于 24）。
         */
        const val PREBLUR_MAX_SIGMA = 24.0

        val DEFAULTS = LiquidGlassTuning()

        /** 10 格档位的推荐参数（`presetClear` … `presetDense`，:254-368）。 */
        val PRESET_TUNINGS: List<LiquidGlassTuning> = listOf(
            // 第 1 格：染色与模糊都归零，背景一块都不挡
            LiquidGlassTuning(
                refraction = 6.0,
                refractionBand = 8.0,
                refractionEdgePow = 3.25,
                dispersion = 0.15,
                rimStrength = 0.1,
                rimWidth = 1.2,
                blurSigma = 0.0,
                tintAlpha = 0.0,
            ),
            LiquidGlassTuning(
                refraction = 6.0,
                refractionBand = 8.5,
                refractionEdgePow = 3.25,
                dispersion = 0.2,
                rimStrength = 0.1,
                rimWidth = 1.2,
                blurSigma = 1.0,
                tintAlpha = 0.1,
            ),
            LiquidGlassTuning(
                refraction = 6.5,
                refractionBand = 9.0,
                refractionEdgePow = 3.0,
                dispersion = 0.2,
                rimStrength = 0.15,
                rimWidth = 1.3,
                blurSigma = 3.0,
                tintAlpha = 0.2,
            ),
            LiquidGlassTuning(
                refraction = 7.0,
                refractionBand = 9.5,
                refractionEdgePow = 3.0,
                dispersion = 0.25,
                rimStrength = 0.15,
                rimWidth = 1.3,
                blurSigma = 5.0,
                tintAlpha = 0.3,
            ),
            LiquidGlassTuning(
                refraction = 7.0,
                refractionBand = 10.0,
                refractionEdgePow = 2.75,
                dispersion = 0.25,
                rimStrength = 0.2,
                rimWidth = 1.4,
                blurSigma = 8.0,
                tintAlpha = 0.4,
            ),
            // 第 6 格（存档值沿用旧的 light）
            LiquidGlassTuning(
                refraction = 7.5,
                refractionBand = 10.5,
                refractionEdgePow = 2.75,
                dispersion = 0.3,
                rimStrength = 0.2,
                rimWidth = 1.4,
                blurSigma = 12.0,
                tintAlpha = 0.55,
            ),
            // 第 7 格 = 标准档 = 出厂值
            DEFAULTS,
            LiquidGlassTuning(
                refraction = 9.0,
                refractionBand = 13.0,
                refractionEdgePow = 2.25,
                dispersion = 0.4,
                rimStrength = 0.25,
                rimWidth = 1.7,
                blurSigma = 18.0,
                tintAlpha = 0.75,
            ),
            LiquidGlassTuning(
                refraction = 10.0,
                refractionBand = 14.0,
                refractionEdgePow = 2.25,
                dispersion = 0.45,
                rimStrength = 0.3,
                rimWidth = 1.9,
                blurSigma = 21.0,
                tintAlpha = 0.8,
            ),
            // 第 10 格：染色刻意不到 1（全不透明就不是玻璃了）
            LiquidGlassTuning(
                refraction = 11.0,
                refractionBand = 15.0,
                refractionEdgePow = 2.0,
                dispersion = 0.5,
                rimStrength = 0.3,
                rimWidth = 2.1,
                blurSigma = 24.0,
                tintAlpha = 0.9,
            ),
        )

        /** 阶梯格数（`LiquidGlassPresetX.builtIns.length`，:135-146）。 */
        val PRESET_STEPS: Int get() = PRESET_TUNINGS.size

        /**
         * [tuning] 最接近第几格（1 起）—— 用户动过旋钮之后档位滑杆停在哪。
         *
         * 口径逐字抄 `LiquidGlassTuning.nearestPreset`（:388-406）：
         * 距离只看**模糊**与**染色**两项，各自按整条阶梯的跨度归一化，两项等权。
         * 用「最近」而不是「上一次选的那格」，滑杆读数才能反映当前参数的真实厚薄。
         *
         * 越界输入（旧存档 / 手改 JSON）由「取最近」天然收口到 1~10。
         */
        fun nearestStep(tuning: LiquidGlassTuning): Int {
            var bestIndex = 0
            var bestDistance = Double.MAX_VALUE
            PRESET_TUNINGS.forEachIndexed { index, preset ->
                val dBlur = abs(preset.blurSigma - tuning.blurSigma) / MAX_BLUR_SIGMA
                val dTint = abs(preset.tintAlpha - tuning.tintAlpha) / MAX_TINT_ALPHA
                val distance = dBlur * dBlur + dTint * dTint
                if (distance < bestDistance) {
                    bestDistance = distance
                    bestIndex = index
                }
            }
            return bestIndex + 1
        }

        /** 磨砂读数收口（`settings_appearance_editor.dart:1481-1483` 的 `clamp`）。 */
        fun clampBlur(value: Double, max: Double): Double =
            value.coerceIn(MIN_BLUR_SIGMA, max)
    }
}

/** `GlassModeChoice`（`lib/models/glass_mode_choice.dart:13）。 */
enum class GlassModeChoice(val value: String, val label: ArbText) {
    SOLID("solid", SettingsStringsExt1.frostedGlassModeSolid),
    LIQUID_GLASS("liquidGlass", SettingsStringsExt1.frostedGlassModeLiquid),
}

/**
 * 某个表面当前生效的材质态（`lib/models/surface_material.dart:10-33`）。
 *
 * 与渲染侧门控**同口径**的纯推导：只用于面板里那张「各表面当前材质」只读地图，
 * 系统级降级（无障碍 / 降动效 / 不支持 shader）不在推导范围内。
 */
enum class SurfaceMaterialState(val value: String, val label: ArbText) {
    /** 表面已关闭（顶栏玻璃总开关关掉后不再渲染）。 */
    OFF("off", SettingsStringsExt1.materialStateOff),

    /** 实体（模糊总开关关、作用范围关的回退）。 */
    SOLID("solid", SettingsStringsExt1.materialStateSolid),

    /** 磨砂（玻璃坞作用范围关掉时的回退）。 */
    FROST("frost", SettingsStringsExt1.materialStateFrost),

    /** 渐进模糊（子页顶栏 2026-09-23 起锁死的那一档）。 */
    FROST_PROGRESSIVE("frostProgressive", SettingsStringsExt1.headerBlurStyleInspire),

    /** 高斯模糊（课程卡片自己那档的展示标签）。 */
    FROST_GAUSSIAN("frostGaussian", SettingsStringsExt1.headerBlurStyleGaussian),

    /** 液态玻璃（高级材质）。 */
    LIQUID_GLASS("liquidGlass", SettingsStringsExt1.frostedGlassModeLiquid),
}

/**
 * 材质面板与壁纸流程读到的材质状态（页面私有输入）。
 *
 * 默认值一律照抄 `lib/models/timetable_settings.dart` 的构造默认值，行号写在字段上。
 * [courseCardSurfaceStyle] 不在这里取真源 —— 它由 [SettingsPageState] 提供，
 * 构造 spec 时覆盖进来。
 */
data class MaterialPanelState(
    /** `:292 defaultFrostedBlurEnabled`。 */
    val frostedBlurEnabled: Boolean = true,
    /** `:935 homePageHeaderBlurEnabled = true`。 */
    val homePageHeaderBlurEnabled: Boolean = true,
    /** `:329 defaultHomeBandGlassMaterial = 'liquid'`。 */
    val homeBandGlassMaterial: String = "liquid",
    /** `:928 liquidGlassPreset = standard`。 */
    val liquidGlassPreset: String = "standard",
    /** `:936 liquidGlassTuning`（可空，null = 出厂档）。 */
    val liquidGlassTuning: LiquidGlassTuning = LiquidGlassTuning.DEFAULTS,
    /** 深色档参数；null = 跟随浅色档。 */
    val liquidGlassTuningDark: LiquidGlassTuning? = null,
    /** `:307 defaultLinkLiquidGlassTuning = true`。 */
    val linkLiquidGlassTuning: Boolean = true,
    /** `:313 defaultDarkGlassBoostEnabled = true`。 */
    val darkGlassBoostEnabled: Boolean = true,
    /** `:300 defaultLiquidGlassDockEnabled = true`。 */
    val liquidGlassDockEnabled: Boolean = true,
    /** `:934 courseCardGlassPreset = standard`。 */
    val courseCardGlassPreset: String = "standard",
    /** 卡片那份液态参数（null = 出厂档）。 */
    val courseCardGlassTuning: LiquidGlassTuning = LiquidGlassTuning.DEFAULTS,
    /** 首页当前有没有可用壁纸（`hasHomePageBackdrop`），课卡材质门控要它。 */
    val hasHomePageBackdrop: Boolean = false,
    /** 课程卡片外观档（真源在 [SettingsPageState.courseCardSurfaceStyle]）。 */
    val courseCardSurfaceStyle: CourseCardSurfaceStyle = CourseCardSurfaceStyle.SOLID,
    /** 预览看日课表还是周课表（`_dayPreview`，:203）。 */
    val previewDayView: Boolean = false,
)

/**
 * 渲染层直接消费的**材质快照**（首页顶栏玻璃带 / 课程卡片 / 玻璃坞）。
 *
 * ## 为什么要有这一层
 *
 * 2026-11-01 之前，材质面板里改「默认材质 / 顶栏玻璃 / 八根旋钮」能落盘、能读回、
 * 面板读数也对，但**屏幕上什么都没有发生**：渲染层从来没有读过
 * `frostedBlurEnabled` / `homeBandGlassMaterial` / `liquidGlassTuning`。
 *
 * 现在由 [SettingsMaterialModel.renderSpecOf] 一次性把「该画哪一档、用多大模糊 /
 * 染色 / 折射」算成这个不可变对象，渲染层只照单执行，不再各自判断设置语义。
 *
 * ## 字段与落盘键的对应（逐条，别另起口径）
 *
 * | 字段 | 来自 |
 * |---|---|
 * | [band] | `homePageHeaderBlurEnabled` + `homeBandGlassMaterial` + `frostedBlurEnabled`（[SettingsMaterialModel.homeBandSurfaceMaterial]） |
 * | [dock] | `frostedBlurEnabled` + `liquidGlassDockEnabled`（[SettingsMaterialModel.dockSurfaceMaterial]） |
 * | [courseCard] | `courseCardSurfaceStyle` + `frostedBlurEnabled` + 有没有可用壁纸（[SettingsMaterialModel.courseCardSurfaceMaterial]） |
 * | [liquidTintAlpha] / [liquidBlurSigma] / [liquidRefraction] / [liquidRefractionBand] / [liquidRimStrength] | `liquidGlassTuning`（深色独立时取 `liquidGlassTuningDark`，再套深色配方） |
 * | [courseCardTintAlpha] / [courseCardBlurSigma] | `courseCardGlassTuning`（卡片自己那套，刻意与全局分开） |
 *
 * 深色配方与 Dart `LiquidGlassDarkRecipe`（`liquid_glass_tuning.dart:676-740`）同口径：
 * 深色**恒**乘 `tintAlphaScale = 0.85`；`darkGlassBoostEnabled` 打开时再乘
 * `blurSigmaScale = 1.3`、`rimStrengthScale = 0.6`；浅色恒等。
 *
 * @param band 顶栏玻璃带。没有壁纸时解析成 [SurfaceMaterialState.SOLID]（Dart
 *   `homePageHeaderUsesFrostedChrome` 在无壁纸时恒 false），关掉总开关时是
 *   [SurfaceMaterialState.OFF]（整条不画）。
 * @param dock 玻璃坞。作用范围关 → 磨砂（仍模糊、不折射）；总闸关 → 实体。
 * @param courseCard 课程卡片。无壁纸 / 总闸关 / 选了实体档 → 实体。
 */
data class HomeMaterialRenderSpec(
    val band: SurfaceMaterialState = SurfaceMaterialState.OFF,
    val dock: SurfaceMaterialState = SurfaceMaterialState.FROST,
    val courseCard: SurfaceMaterialState = SurfaceMaterialState.SOLID,
    val liquidTintAlpha: Float = LiquidGlassTuning.DEFAULT_TINT_ALPHA.toFloat(),
    val liquidBlurSigma: Float = LiquidGlassTuning.DEFAULT_BLUR_SIGMA.toFloat(),
    val liquidRefraction: Float = LiquidGlassTuning.DEFAULT_REFRACTION.toFloat(),
    val liquidRefractionBand: Float = LiquidGlassTuning.DEFAULT_REFRACTION_BAND.toFloat(),
    val liquidRimStrength: Float = LiquidGlassTuning.DEFAULT_RIM_STRENGTH.toFloat(),
    val courseCardTintAlpha: Float = LiquidGlassTuning.DEFAULT_TINT_ALPHA.toFloat(),
    val courseCardBlurSigma: Float = LiquidGlassTuning.DEFAULT_BLUR_SIGMA.toFloat(),
)

/** 材质/表面的纯推导（`lib/models/surface_material.dart` + `glass_mode_choice.dart`）。 */
object SettingsMaterialModel {
    /** 模糊总开关 → 玻璃档（`glass_mode_choice.dart:22-24`）。 */
    fun glassModeChoice(state: MaterialPanelState): GlassModeChoice =
        if (state.frostedBlurEnabled) GlassModeChoice.LIQUID_GLASS else GlassModeChoice.SOLID

    /**
     * `homeBandGlassMaterial` 的**生效值**（`timetable_settings.dart:730-735`）：
     * `follow` 按当前模糊总开关解析成 `liquid` / `solid`；单独指定原样返回。
     */
    fun effectiveHomeBandMaterial(state: MaterialPanelState): String =
        if (state.homeBandGlassMaterial != HOME_BAND_FOLLOW) {
            state.homeBandGlassMaterial
        } else {
            if (state.frostedBlurEnabled) HOME_BAND_LIQUID else HOME_BAND_SOLID
        }

    /** 首页玻璃带（标题栏 + 星期栏共用一条带），`surface_material.dart:64-77`。 */
    fun homeBandSurfaceMaterial(state: MaterialPanelState): SurfaceMaterialState {
        if (!state.homePageHeaderBlurEnabled) return SurfaceMaterialState.OFF
        return when (effectiveHomeBandMaterial(state)) {
            HOME_BAND_SOLID -> SurfaceMaterialState.SOLID
            // 液态带在引擎没有 shader 后端时自己回落成磨砂带，那是渲染期的事
            else -> if (state.frostedBlurEnabled) {
                SurfaceMaterialState.LIQUID_GLASS
            } else {
                SurfaceMaterialState.SOLID
            }
        }
    }

    /** 玻璃坞（含坞内圆钮），`surface_material.dart:82-83`。 */
    fun dockSurfaceMaterial(state: MaterialPanelState): SurfaceMaterialState =
        advancedSurfaceMaterial(state, state.liquidGlassDockEnabled)

    /**
     * 走液态玻璃、且作用范围开关允许的表面（`surface_material.dart:41-59`）。
     *
     * ⚠️ **模糊总开关必须排在最前面**：高斯档 2026-09-30 退场后，那一层「顺带归位」
     * 没了；不先看总开关，「实体卡片」档下作用范围开着的坞会被报成液态玻璃，
     * 与渲染侧直接矛盾。
     */
    private fun advancedSurfaceMaterial(
        state: MaterialPanelState,
        scopeOn: Boolean,
    ): SurfaceMaterialState {
        if (!state.frostedBlurEnabled) return SurfaceMaterialState.SOLID
        return if (scopeOn) SurfaceMaterialState.LIQUID_GLASS else SurfaceMaterialState.FROST
    }

    /**
     * 课程卡片（`surface_material.dart:96-107`）。
     *
     * 玻璃档同时依赖**可用壁纸**与全局模糊管线：渲染侧在无壁纸时一律回落实体，
     * 地图这里必须同口径，否则会显示一个屏幕上看不到的档位。
     */
    fun courseCardSurfaceMaterial(state: MaterialPanelState): SurfaceMaterialState {
        if (state.courseCardSurfaceStyle == CourseCardSurfaceStyle.SOLID) {
            return SurfaceMaterialState.SOLID
        }
        if (!state.frostedBlurEnabled || !state.hasHomePageBackdrop) {
            return SurfaceMaterialState.SOLID
        }
        return if (state.courseCardSurfaceStyle == CourseCardSurfaceStyle.LIQUID_GLASS) {
            SurfaceMaterialState.LIQUID_GLASS
        } else {
            SurfaceMaterialState.FROST_GAUSSIAN
        }
    }

    /**
     * 课程卡片页顶那句「总闸盖过本页」的提示是否需要出现
     * （`settings_appearance_editor.dart:1223-1225` 的 `maskedByMaster`）。
     *
     * 只在这一档**确实被总闸压住**时提示：用户选的本来就是实体卡片时，
     * 没有什么「不生效」可言，多一行字只会是噪音。
     */
    fun courseCardMaskedByMaster(state: MaterialPanelState): Boolean =
        !state.frostedBlurEnabled &&
            state.courseCardSurfaceStyle != CourseCardSurfaceStyle.SOLID

    /**
     * 档位滑杆的读数（`settings_appearance_editor.dart:1429-1430`）：
     * `preset.step ?? nearest.step`，`custom` 时停在最近那格。
     */
    fun presetStep(state: MaterialPanelState, tuning: LiquidGlassTuning, preset: String): Int =
        presetStepOf(preset) ?: LiquidGlassTuning.nearestStep(tuning)

    /**
     * 内置档位的格号；`custom` 与不认识的值返回 null（不在阶梯上）。
     *
     * 顺序与 `LiquidGlassPresetX.builtIns` 一一对应：clear / level2..level5 /
     * light / standard / level8 / level9 / dense（:135-146）。
     */
    fun presetStepOf(preset: String): Int? = PRESET_VALUES.indexOf(preset).takeIf { it >= 0 }?.plus(1)

    /** 内置档位（不含 `custom`）的存档值，顺序 = 厚度从薄到厚。 */
    val PRESET_VALUES: List<String> = listOf(
        "clear",
        "level2",
        "level3",
        "level4",
        "level5",
        "light",
        "standard",
        "level8",
        "level9",
        "dense",
    )

    const val HOME_BAND_FOLLOW = "follow"
    const val HOME_BAND_SOLID = "solid"
    const val HOME_BAND_LIQUID = "liquid"

    /** 「自定义」档的存档值：不在 10 格阶梯上。 */
    const val PRESET_CUSTOM = "custom"

    // ───────────────────────── 渲染侧快照（设置模型 → 屏幕该画什么） ─────────────────────────

    /**
     * 设置模型 → [HomeMaterialRenderSpec]。
     *
     * 渲染层**只调用这一个入口**，不要在页面里再读 `frostedBlurEnabled` 一类原始键：
     * 那样「跟随默认 / 深色档 / 无壁纸降级」三套判据会在每个表面各写一遍，迟早漂开。
     *
     * @param isDark 当前系统明暗（决定深色档与深色配方）。
     * @param hasBackdrop 当前有没有**可用**壁纸（宿主用 `HomeBackdropSnapshot.hasWallpaper`
     *   传进来；课程卡片的实体降级与顶栏带的实心降级都依赖它，Dart 同口径）。
     */
    fun renderSpecOf(
        model: TimetableSettingsModel,
        isDark: Boolean,
        hasBackdrop: Boolean,
    ): HomeMaterialRenderSpec {
        val panel = panelStateOf(model, hasBackdrop)
        val rawBand = homeBandSurfaceMaterial(panel)
        // Dart `homePageHeaderUsesFrostedChrome`：没有壁纸时标题行恒为不透明实心条。
        // 「OFF」（顶栏玻璃总开关关）保持不画，不被这条降级吞掉。
        val band = if (!hasBackdrop && rawBand != SurfaceMaterialState.OFF) {
            SurfaceMaterialState.SOLID
        } else {
            rawBand
        }
        val global = activeLiquidTuning(model, isDark)
        val card = model.courseCardGlassTuning ?: LiquidGlassTuningModel.DEFAULTS
        val tintScale = darkTintScale(isDark)
        val blurScale = darkBlurScale(isDark, model.darkGlassBoostEnabled)
        val rimScale = darkRimScale(isDark, model.darkGlassBoostEnabled)
        return HomeMaterialRenderSpec(
            band = band,
            dock = dockSurfaceMaterial(panel),
            courseCard = courseCardSurfaceMaterial(panel),
            liquidTintAlpha = (global.tintAlpha * tintScale).coerceIn(0.0, 1.0).toFloat(),
            liquidBlurSigma = (global.blurSigma * blurScale)
                .coerceIn(0.0, LiquidGlassTuningModel.MAX_BLUR_SIGMA).toFloat(),
            liquidRefraction = global.refraction
                .coerceIn(0.0, LiquidGlassTuningModel.MAX_REFRACTION).toFloat(),
            liquidRefractionBand = global.refractionBand
                .coerceIn(0.0, LiquidGlassTuningModel.MAX_REFRACTION_BAND).toFloat(),
            liquidRimStrength = (global.rimStrength * rimScale).coerceIn(0.0, 1.0).toFloat(),
            courseCardTintAlpha = (card.tintAlpha * tintScale).coerceIn(0.0, 1.0).toFloat(),
            courseCardBlurSigma = (card.blurSigma * blurScale)
                .coerceIn(0.0, LiquidGlassTuningModel.MAX_BLUR_SIGMA).toFloat(),
        )
    }

    /**
     * 设置模型 → 材质面板的输入状态（[MaterialPanelState]）。
     *
     * 与面板自己用的那份**同一形状**，这样「面板上显示的档位」与「渲染层拿到的档位」
     * 不会各算一遍。两个 `CourseCardSurfaceStyle` 枚举（`app` 的落盘模型 / 本包的
     * 界面模型）在这里做唯一一次翻译。
     */
    fun panelStateOf(
        model: TimetableSettingsModel,
        hasBackdrop: Boolean,
    ): MaterialPanelState = MaterialPanelState(
        frostedBlurEnabled = model.frostedBlurEnabled,
        homePageHeaderBlurEnabled = model.homePageHeaderBlurEnabled,
        homeBandGlassMaterial = model.homeBandGlassMaterial,
        liquidGlassPreset = model.liquidGlassPreset,
        liquidGlassTuning = model.liquidGlassTuning?.toPanelTuning() ?: LiquidGlassTuning.DEFAULTS,
        liquidGlassTuningDark = model.liquidGlassTuningDark?.toPanelTuning(),
        linkLiquidGlassTuning = model.linkLiquidGlassTuning,
        darkGlassBoostEnabled = model.darkGlassBoostEnabled,
        liquidGlassDockEnabled = model.liquidGlassDockEnabled,
        courseCardGlassPreset = model.courseCardGlassPreset,
        courseCardGlassTuning =
        model.courseCardGlassTuning?.toPanelTuning() ?: LiquidGlassTuning.DEFAULTS,
        hasHomePageBackdrop = hasBackdrop,
        courseCardSurfaceStyle = when (model.courseCardSurfaceStyle) {
            ModelCourseCardSurfaceStyle.SOLID -> CourseCardSurfaceStyle.SOLID
            ModelCourseCardSurfaceStyle.GAUSSIAN -> CourseCardSurfaceStyle.GAUSSIAN
            ModelCourseCardSurfaceStyle.LIQUID_GLASS -> CourseCardSurfaceStyle.LIQUID_GLASS
        },
    )

    /**
     * 当前明暗该用哪一档液态参数（Dart `LiquidGlassTuning.forMode`，
     * `liquid_glass_tuning.dart:588-605`）：浅色恒用浅色档；深色在**独立**（`link = false`）
     * 且深色档非空时才切过去，否则仍以浅色档为形状、再套深色配方。
     */
    fun activeLiquidTuning(
        model: TimetableSettingsModel,
        isDark: Boolean,
    ): LiquidGlassTuningModel {
        val light = model.liquidGlassTuning ?: LiquidGlassTuningModel.DEFAULTS
        if (!isDark || model.linkLiquidGlassTuning) return light
        return model.liquidGlassTuningDark ?: light
    }

    /** 深色配方的染色系数（`LiquidGlassDarkRecipe`：standard / legacy 都是 0.85）。 */
    fun darkTintScale(isDark: Boolean): Double = if (isDark) 0.85 else 1.0

    /** 深色配方的模糊系数：只有 standard 配方（`darkGlassBoostEnabled`）才上浮 1.3。 */
    fun darkBlurScale(isDark: Boolean, darkBoost: Boolean): Double =
        if (isDark && darkBoost) 1.3 else 1.0

    /** 深色配方的边光系数：standard 收 0.6，legacy 不动。 */
    fun darkRimScale(isDark: Boolean, darkBoost: Boolean): Double =
        if (isDark && darkBoost) 0.6 else 1.0
}

/** 落盘模型（`app`）的液态参数 → 本包面板模型（字段一一对应，`liquid_glass_tuning.dart:476-498`）。 */
private fun LiquidGlassTuningModel.toPanelTuning(): LiquidGlassTuning = LiquidGlassTuning(
    refraction = refraction,
    refractionBand = refractionBand,
    refractionEdgePow = refractionEdgePow,
    dispersion = dispersion,
    rimStrength = rimStrength,
    rimWidth = rimWidth,
    blurSigma = blurSigma,
    tintAlpha = tintAlpha,
)
