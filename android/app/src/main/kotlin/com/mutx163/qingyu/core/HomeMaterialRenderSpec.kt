package com.mutx163.qingyu.core

/**
 * 某个表面当前生效的材质态（Dart `lib/models/surface_material.dart:10-33`）。
 *
 * ## 为什么住在 core 而不是 pages/settings
 *
 * 这是「设置算好、渲染层照单执行」的**跨域渲染契约**：设置域负责把用户偏好推导成
 * [HomeMaterialRenderSpec]，课表（日视图议程卡 alpha）、壳（顶栏玻璃带 / 玻璃坞）等
 * 渲染方只消费这份快照。原先类型放在 `pages.settings`，导致课表域的 main 与测试反向
 * import 设置域，`pages/timetable` 的 L0 离开 `-ExtraSources` 编不过
 * （2026-11-03 跨域引用治理，详见守卫 `DomainBoundaryImportGuardTest`）。
 *
 * 枚举只保留**身份与落盘值**（[value]）；屏上文案（`label`）是设置域的 UI 语义，
 * 留在 `pages.settings` 以扩展属性提供，设置域调用方无感。
 */
enum class SurfaceMaterialState(val value: String) {
    /** 表面已关闭（顶栏玻璃总开关关掉后不再渲染）。 */
    OFF("off"),

    /** 实体（模糊总开关关、作用范围关的回退）。 */
    SOLID("solid"),

    /** 磨砂（玻璃坞作用范围关掉时的回退）。 */
    FROST("frost"),

    /** 渐进模糊（子页顶栏 2026-09-23 起锁死的那一档）。 */
    FROST_PROGRESSIVE("frostProgressive"),

    /** 高斯模糊（课程卡片自己那档的展示标签）。 */
    FROST_GAUSSIAN("frostGaussian"),

    /** 液态玻璃（高级材质）。 */
    LIQUID_GLASS("liquidGlass"),
}

/**
 * 渲染层直接消费的**材质快照**（首页顶栏玻璃带 / 课程卡片 / 玻璃坞）。
 *
 * 设置域的 `SettingsMaterialModel.renderSpecOf` 一次性把「该画哪一档、用多大模糊 /
 * 染色 / 折射」算成这个不可变对象，渲染层只照单执行，不再各自判断设置语义。
 *
 * ## 字段与落盘键的对应（逐条，别另起口径）
 *
 * | 字段 | 来自 |
 * |---|---|
 * | [band] | `homePageHeaderBlurEnabled` + `homeBandGlassMaterial` + `frostedBlurEnabled` |
 * | [dock] | `frostedBlurEnabled` + `liquidGlassDockEnabled` |
 * | [courseCard] | `courseCardSurfaceStyle` + `frostedBlurEnabled` + 有没有可用壁纸 |
 * | [liquidTintAlpha] / [liquidBlurSigma] / [liquidRefraction] / [liquidRefractionBand] / [liquidRimStrength] / [liquidDispersion] | `liquidGlassTuning`（深色独立时取 `liquidGlassTuningDark`，再套深色配方） |
 * | [courseCardTintAlpha] / [courseCardBlurSigma] / [courseCardRefraction] / [courseCardRefractionBand] / [courseCardDispersion] | `courseCardGlassTuning`（卡片自己那套，刻意与全局分开） |
 *
 * 深色配方与 Dart `LiquidGlassDarkRecipe`（`liquid_glass_tuning.dart:676-748`）同口径：
 * 深色**恒**乘 `tintAlphaScale = 0.85`；`darkGlassBoostEnabled` 打开时再乘
 * `blurSigmaScale = 1.3`、`rimStrengthScale = 0.6`、`dispersionScale = 0.7`；浅色恒等。
 *
 * ⚠️ [courseCardBlurSigma] 是**唯一不吃深色配方**的字段：它喂的是整屏预糊位图，
 * 一张图只按一个 sigma 烤一次（Dart `course_glass_tuning.dart:165-170`），且量程止于
 * `kPreblurMaxSigma = 24` 而不是全局的 40。
 *
 * ⚠️ **卡片那三个折射字段（[courseCardRefraction] / [courseCardRefractionBand] /
 * [courseCardDispersion]）刻意不与顶栏带共用**：Dart 给卡片单独一套 `CourseGlassTuning`
 * （`course_glass_tuning.dart:5-23`），混用就是「调一处两处都变」。
 *
 * 默认值 = `LiquidGlassTuning` 的出厂档（`app.LiquidGlassTuningModel.DEFAULT_*`：
 * tint 0.70 / blur 15 / refraction 8 / band 11 / rim 0.2 / dispersion 0.35），逐字对应。
 *
 * @param band 顶栏玻璃带。没有壁纸时解析成 [SurfaceMaterialState.SOLID]，关掉总开关时是
 *   [SurfaceMaterialState.OFF]（整条不画）。
 * @param dock 玻璃坞。作用范围关 → 磨砂（仍模糊、不折射）；总闸关 → 实体。
 * @param courseCard 课程卡片。无壁纸 / 总闸关 / 选了实体档 → 实体。
 */
data class HomeMaterialRenderSpec(
    val band: SurfaceMaterialState = SurfaceMaterialState.OFF,
    val dock: SurfaceMaterialState = SurfaceMaterialState.FROST,
    override val courseCard: SurfaceMaterialState = SurfaceMaterialState.SOLID,
    val liquidTintAlpha: Float = 0.70f,
    val liquidBlurSigma: Float = 15.0f,
    val liquidRefraction: Float = 8.0f,
    val liquidRefractionBand: Float = 11.0f,
    val liquidRimStrength: Float = 0.2f,
    /**
     * 色散强度（0–1），`liquidGlassTuning.dispersion` 套深色配方后的值。
     *
     * 喂 miuix `lens(chromaticAberration = …)`（`components/liquid/LiquidLens.kt`）；
     * 0 = 走更便宜的无色散着色器。
     */
    val liquidDispersion: Float = 0.35f,
    override val courseCardTintAlpha: Float = 0.70f,
    val courseCardBlurSigma: Float = 15.0f,
    /** 课卡边缘折射位移（逻辑 px），取**卡片自己那套**的 `refraction`。 */
    val courseCardRefraction: Float = 8.0f,
    /** 课卡折射作用带宽度（逻辑 px），取卡片那套的 `refractionBand`。 */
    val courseCardRefractionBand: Float = 11.0f,
    /** 课卡色散强度（0–1），取卡片那套的 `dispersion` 并套深色配方。 */
    val courseCardDispersion: Float = 0.35f,
) : CourseCardSurface

/**
 * 卡面渲染读到的材质快照接口（只暴露渲染层真正用到的两项：档位 + 染色透明系数）。
 *
 * [HomeMaterialRenderSpec] 实现本接口，timetable 主源集（日视图议程卡 alpha 等）
 * 因此只依赖 `core`，不必反向引用设置页模型。
 */
interface CourseCardSurface {
    val courseCard: SurfaceMaterialState
    val courseCardTintAlpha: Float
}
