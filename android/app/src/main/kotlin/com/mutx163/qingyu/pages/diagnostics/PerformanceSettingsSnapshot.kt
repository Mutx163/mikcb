package com.mutx163.qingyu.pages.diagnostics

import com.mutx163.qingyu.app.CourseCardSurfaceStyle
import com.mutx163.qingyu.app.HomeNavigationForm
import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.TimetableSettings

/**
 * 渲染性能设置快照 · Kotlin 纯逻辑（移植 `lib/logging/performance_settings_snapshot.dart`，340 行）。
 *
 * ## 为什么要它
 *
 * 调性能时的老困境：现在到底是磨砂还是液态、档位是标准还是浓雾、转场有没有被系统动画
 * 缩放压掉——只能翻三层设置页回忆，回忆错一次就把两种完全不同的开销当成同一件事比较。
 * 一条快照把「会影响帧率的档位」一次性写进日志，`[frame-perf]` / `[glass-cap]` 的读数
 * 就和配置对上了。
 *
 * ## 口径：只读「有效值」，不重新推导
 *
 * Dart 版刻意不自己算「磨砂档该是多少模糊半径」——那等于把渲染侧推导抄一遍，抄错之后
 * 日志会写出一个「看起来对、实际不是这样」的值，比没有日志更误导人。本移植**继承这条**：
 * 每一项都直接取设置模型已经解析好的值，不在这里做材质/外观推导。
 *
 * ## 与 Dart 的两处必要差异（都是「还没到那一步」，不是改口径）
 *
 * 1. **底层数据面更窄**：Kotlin 设置模型现在只拥有 45 个显示设置键（Dart 250+），
 *    玻璃材质 / 壁纸 / 环境量那几组键在 Kotlin 侧**还没有读源**。
 *    这些键一条都没有编造：它们被明确登记在 [PENDING_DART_KEYS] 里，
 *    并有单测钉住「已发出的键 + 待接的键 = Dart 全部键，无重复无遗漏」。
 *    接上一个就在 [buildSettingsDerivedSnapshot] / [buildEnvironmentSnapshot] 里删掉
 *    一条 pending、发出一个真值——**不允许**为了「键齐」先写 null 或占位串。
 * 2. **落盘与 logcat 不在本文件**：Dart 版自己 `showAppToast` / `debugPrint`，
 *    Kotlin 侧落盘走 `AppLogStore.append`（泳道 A 的共享件）、logcat 走宿主层的
 *    `Log.i`。本文件保持**零 Android 依赖**，才跑得进 L0 的 JVM 单测
 *    （`scripts/test-kotlin-module.ps1` 的 classpath 里没有 android.jar）。
 *
 * ## 文案键逐字对拍 Dart
 *
 * 键名、值编码（枚举取 Dart `.name` / `.value`）、`cardTextFields` 的拼接顺序、
 * `'none'` 兜底，全部照抄；`DiagnosticsStringsParityTest` 之外另有
 * `PerformanceSettingsSnapshotTest` 用 Dart 源里的字面量钉住。
 */
object PerformanceSnapshot {

    /** 日志分类：复用已注册的 `debug_snapshot`（日志页显示「调试快照」）。 */
    const val CATEGORY: String = "debug_snapshot"

    /** logcat 里用来 grep 的前缀（Dart `kPerformanceSnapshotTag`）。 */
    const val TAG: String = "[settings-snapshot]"

    /** 落盘那条的 `message`（Dart 逐字：`render performance settings snapshot`）。 */
    const val MESSAGE: String = "render performance settings snapshot"

    /** 诊断页「设置快照」行的 `reason`（Dart `_logPerformanceSnapshot`）。 */
    const val REASON_MANUAL_EXPORT: String = "manualExport"

    /**
     * Dart `_settingsDerivedSnapshot` 里**本移植已能读到真值**的键，顺序与 Dart 一致。
     *
     * 顺序有意义：Dart 的指纹比较（[shouldLogPerformanceSettingsChange]）比的是
     * `jsonEncode` 后的整串，键序参与比较，所以两张表不能各自排序。
     */
    val EMITTED_DERIVED_KEYS: List<String> = listOf(
        "themeMode",
        "foruiTheme",
        "seedColor",
        "fontMode",
        "fontWeight",
        "textScale",
        "pageTransitionSpeed",
        "localeTag",
        "courseCardStyle",
        "useUnifiedCardColor",
        "unifiedCardColor",
        "sectionHeight",
        "sectionCount",
        "autoFitSectionHeight",
        "compactFontSize",
        "courseCardFontSize",
        "courseCardGap",
        "timeColumnWidthMode",
        "courseSpacingMode",
        "hideWeekends",
        "showConflictBadge",
        "conflictCardOpacity",
        "floatButtonOpacity",
        "cardTextFields",
        "navigationForm",
        "menuStyle",
    )

    /** Dart `_environmentSnapshot` 里本移植已能读到真值的键。 */
    val EMITTED_ENVIRONMENT_KEYS: List<String> = listOf("buildMode")

    /**
     * Dart 快照里有、Kotlin 侧**还没有读源**的键 → 缺什么（不是「永久不做」的清单）。
     *
     * 读取方看到快照里没有这些键时不要去 logcat 里找：真的是没采，不是值为空。
     */
    val PENDING_DART_KEYS: Map<String, String> = linkedMapOf(
        // —— 材质 / 各表面实际用料：源在 `TimetableSettings.frostedAppearance` 与
        //    `lib/models/surface_material.dart` 的工厂函数，两者都还没迁到 Kotlin。 ——
        "glassMode" to "缺 glassModeChoiceOf（frostedAppearance 未迁）",
        "blurEnabled" to "缺 frostedBlurEnabled（frostedAppearance 未迁）",
        "surfaceHomeBand" to "缺 surface_material.dart 的 homeBandSurfaceMaterial",
        "surfaceSubpageHeader" to "缺 subpageHeaderSurfaceMaterial",
        "surfaceDock" to "缺 dockSurfaceMaterial",
        "surfaceSheetDialog" to "缺 pinnedChromeSurfaceMaterial",
        "surfaceSelectSheet" to "缺 pinnedChromeSurfaceMaterial",
        "surfacePopup" to "缺 pinnedChromeSurfaceMaterial",
        "surfacePickerButtons" to "缺 pinnedChromeSurfaceMaterial",
        "surfaceCourseCard" to "缺 courseCardSurfaceMaterial",
        "courseCardEffective" to "缺 effectiveCourseCardSurfaceStyle（含壁纸门控）",
        "lgDock" to "缺 liquidGlassDockEnabled",
        "lgPreset" to "缺 liquidGlassPreset",
        "lgTuningSource" to "缺 liquidGlassTuning",
        "lgRefraction" to "缺 LiquidGlassTuning 数值面",
        "lgRefractionBand" to "缺 LiquidGlassTuning 数值面",
        "lgRefractionEdgePow" to "缺 LiquidGlassTuning 数值面",
        "lgDispersion" to "缺 LiquidGlassTuning 数值面",
        "lgRimStrength" to "缺 LiquidGlassTuning 数值面",
        "lgRimWidth" to "缺 LiquidGlassTuning 数值面",
        "lgBlurSigma" to "缺 LiquidGlassTuning 数值面",
        "lgTintAlpha" to "缺 LiquidGlassTuning 数值面",
        "lgDarkTuningSource" to "缺 liquidGlassTuningDark",
        "lgLinkDark" to "缺 linkLiquidGlassTuning",
        "lgDarkBoost" to "缺 darkGlassBoostEnabled",
        "lgDarkBlurSigma" to "缺 liquid.toStyle(dark) 的选档配方",
        "lgDarkRimStrength" to "缺 liquid.toStyle(dark) 的选档配方",
        "lgDarkDispersion" to "缺 liquid.toStyle(dark) 的选档配方",
        "lgDarkTintAlpha" to "缺 liquid.toStyle(dark) 的选档配方",
        "ccTuningSource" to "缺 courseCardGlassTuning",
        "ccPreset" to "缺 courseCardGlassPreset",
        "ccRefraction" to "缺 CourseGlassTuning 数值面",
        "ccRefractionBand" to "缺 CourseGlassTuning 数值面",
        "ccRefractionEdgePow" to "缺 CourseGlassTuning 数值面",
        "ccDispersion" to "缺 CourseGlassTuning 数值面",
        "ccRimStrength" to "缺 CourseGlassTuning 数值面",
        "ccRimWidth" to "缺 CourseGlassTuning 数值面",
        "ccBlurSigma" to "缺 CourseGlassTuning 数值面",
        "ccTintAlpha" to "缺 CourseGlassTuning 数值面",
        "homeBandGlassMaterial" to "缺 appearance.homeBandGlassMaterial",
        "timeColumnBlur" to "缺 homePageTimeColumnBlurEnabled",
        "backdropFollowsWeekPager" to "缺 homePageBackdropFollowsWeekPager",
        // —— 背景 / 壁纸 ——
        "backgroundFill" to "缺 homePageBackgroundFill",
        "pageBackgroundColor" to "缺 timetablePageBackgroundColor",
        "wallpaperAlignX" to "缺 homePageWallpaperAlignX",
        "wallpaperAlignY" to "缺 homePageWallpaperAlignY",
        "wallpaperScale" to "缺 homePageWallpaperScale",
        "wallpaperBlurSigma" to "缺 homePageWallpaperBlurSigma",
        "backgroundScope" to "缺 homePageBackgroundScope",
        "backgroundScopeRegions" to "缺 HomePageBackgroundScope.includes（位标志解析）",
        // —— 环境量 ——
        "systemTransitionScale" to "缺 AndroidAnimationScaleService 的 Kotlin 对应物",
        "userTransitionSpeed" to "缺 AndroidAnimationScaleService 的 Kotlin 对应物",
        "transitionDurationMs" to "缺 HyperosMiuixNavigation.programmaticDurationMs 的 Kotlin 常量",
        "wallpaperConfigured" to "缺 homePageWallpaperPath",
        "wallpaperUsable" to "缺 hasHomePageBackdrop（壁纸文件真实存在性）",
    )

    /**
     * 快照里「由设置推导」的那部分（Dart `_settingsDerivedSnapshot`，:81-223）。
     *
     * @param model 设置模型（显示设置族）
     * @param coreSettings 只用来取 `sectionCount`（Dart `s.sectionCount => sections.length`，
     *   `timetable_settings.dart:2479`）；节次表归 core，不归显示设置模型
     */
    fun buildSettingsDerivedSnapshot(
        model: TimetableSettingsModel,
        coreSettings: TimetableSettings,
    ): Map<String, Any?> = linkedMapOf(
        // —— 一句话档位（外观）——
        "themeMode" to model.appThemeMode.value,
        // Dart 取 `.name`；`ForuiTheme` 的枚举名与磁盘值一致（miui/neutral/…），直接取 value。
        "foruiTheme" to model.foruiTheme.value,
        "seedColor" to model.themeSeedColor,
        "fontMode" to model.appFontMode.value,
        "fontWeight" to model.appFontWeight,
        "textScale" to model.appTextScale,
        "pageTransitionSpeed" to model.pageTransitionSpeed,
        "localeTag" to model.appLocaleTag,

        // —— 课卡与课表密度（直接决定整页布局与滚动成本）——
        // Dart 取 `.name`，而这里磁盘值是 `refraction`、枚举名才是 `liquidGlass`。
        "courseCardStyle" to courseCardSurfaceStyleDartName(model.courseCardSurfaceStyle),
        "useUnifiedCardColor" to model.timetableUseUnifiedCardColor,
        "unifiedCardColor" to model.timetableUnifiedCardColor,
        "sectionHeight" to model.sectionHeight,
        "sectionCount" to coreSettings.sections.size,
        "autoFitSectionHeight" to model.timetableAutoFitSectionHeight,
        "compactFontSize" to model.compactFontSize,
        "courseCardFontSize" to model.courseCardFontSize,
        "courseCardGap" to model.timetableCourseCardGap,
        "timeColumnWidthMode" to model.timetableTimeColumnWidthMode.value,
        "courseSpacingMode" to model.timetableCourseSpacingMode.value,
        "hideWeekends" to model.timetableHideWeekends,
        "showConflictBadge" to model.showConflictBadgeOnTimetable,
        "conflictCardOpacity" to model.timetableConflictCourseOpacity,
        "floatButtonOpacity" to model.timetableFloatingBackToCurrentWeekButtonOpacity,
        "cardTextFields" to buildCardTextFields(model),

        // —— 导航形态 ——
        // Dart 取 `.name`：`glassDock`；磁盘值是 `glass_dock`，两者不同，必须映射。
        "navigationForm" to homeNavigationFormDartName(model.homeNavigationForm),
        "menuStyle" to model.homeMenuStyle.value,
    )

    /**
     * 快照里「当前环境」的那部分（Dart `_environmentSnapshot`，:230-248）。
     *
     * 这些量不看你设置、但同样决定掉帧：开发者选项里把动画缩放调成 0.5 之后，
     * 500ms 的转场只剩 250ms、120Hz 上只有几十帧，任何一帧稍重都会读作「卡」。
     *
     * @param buildMode `debug` / `profile` / `release`（Dart 由 `kReleaseMode` /
     *   `kProfileMode` 判；Kotlin 侧由包名后缀判，见宿主层）
     */
    fun buildEnvironmentSnapshot(buildMode: String): Map<String, Any?> = linkedMapOf(
        // 一眼看出这份日志来自调试版还是性能版。
        "buildMode" to buildMode,
    )

    /**
     * 收集当前所有会影响渲染开销的设置（Dart `buildPerformanceSettingsSnapshot`，:254-259）。
     *
     * 纯函数：同样的设置一定得到同样的结果（`buildMode` 由调用方注入，也不抖）。
     */
    fun build(
        model: TimetableSettingsModel,
        coreSettings: TimetableSettings,
        buildMode: String,
    ): Map<String, Any?> {
        val out = LinkedHashMap<String, Any?>()
        out.putAll(buildSettingsDerivedSnapshot(model, coreSettings))
        out.putAll(buildEnvironmentSnapshot(buildMode))
        return out
    }

    /**
     * 落盘用的 extras：快照本体 + `reason`（Dart `logPerformanceSettingsSnapshot`，:290-291）。
     *
     * `reason` 说明这次是谁触发的，便于事后按来源分组比对。
     */
    fun buildExtras(
        model: TimetableSettingsModel,
        coreSettings: TimetableSettings,
        buildMode: String,
        reason: String,
    ): Map<String, Any?> {
        val out = LinkedHashMap<String, Any?>(build(model, coreSettings, buildMode))
        out["reason"] = reason
        return out
    }

    /**
     * 「会影响帧率的那些项」是否真的变了（Dart `shouldLogPerformanceSettingsChange`，:266-272）。
     *
     * 拖材质滑杆自带防抖，但快速连拖仍会触发多次保存；没有这道守卫，一次调参会往
     * 日志里灌进一屏一模一样的快照。指纹直接取推导后的快照本身：以后往
     * [buildSettingsDerivedSnapshot] 加字段，守卫自动跟着覆盖，不会漏。
     */
    fun shouldLogChange(
        previousModel: TimetableSettingsModel,
        previousCore: TimetableSettings,
        nextModel: TimetableSettingsModel,
        nextCore: TimetableSettings,
    ): Boolean = MiniJson.encode(buildSettingsDerivedSnapshot(previousModel, previousCore)) !=
        MiniJson.encode(buildSettingsDerivedSnapshot(nextModel, nextCore))

    /**
     * 课卡此刻显示哪几行文本（Dart `_cardTextFields`，:323-335）。
     *
     * 行数直接决定每张卡的布局与绘制成本。顺序即 Dart 的 if 顺序。
     */
    fun buildCardTextFields(model: TimetableSettingsModel): String {
        val enabled = ArrayList<String>(8)
        if (model.courseCardShowName) enabled.add("name")
        if (model.courseCardShowTeacher) enabled.add("teacher")
        if (model.courseCardShowLocation) enabled.add("location")
        if (model.courseCardShowTime) enabled.add("time")
        if (model.courseCardShowTimeLabels) enabled.add("timeLabels")
        if (model.courseCardShowWeeks) enabled.add("weeks")
        if (model.courseCardShowDescription) enabled.add("description")
        if (model.weatherShowOnWeekCard) enabled.add("weather")
        return if (enabled.isEmpty()) "none" else enabled.joinToString(",")
    }
}

/**
 * Dart `CourseCardSurfaceStyle.name`（`timetable_settings_extensions.dart:294-327`）。
 *
 * ⚠️ **不能**用 [CourseCardSurfaceStyle.value]：那个是磁盘值，液态玻璃档是 `refraction`，
 * 而 Dart 快照报的是**枚举名** `liquidGlass`。混用的结果是日志读数和设置页档位对不上。
 */
fun courseCardSurfaceStyleDartName(style: CourseCardSurfaceStyle): String = when (style) {
    CourseCardSurfaceStyle.SOLID -> "solid"
    CourseCardSurfaceStyle.GAUSSIAN -> "gaussian"
    CourseCardSurfaceStyle.LIQUID_GLASS -> "liquidGlass"
}

/**
 * Dart `HomeNavigationForm.name`（`timetable_settings_enums.dart:134`）。
 *
 * ⚠️ 磁盘值是 `glass_dock`（下划线），枚举名是 `glassDock`。Dart 快照取 `.name`。
 */
fun homeNavigationFormDartName(form: HomeNavigationForm): String = when (form) {
    HomeNavigationForm.CLASSIC -> "classic"
    HomeNavigationForm.GLASS_DOCK -> "glassDock"
}
