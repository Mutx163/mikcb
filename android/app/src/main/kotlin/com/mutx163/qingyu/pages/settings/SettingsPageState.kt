package com.mutx163.qingyu.pages.settings

/**
 * 设置族三页读到的设置状态（页面构建的**唯一输入**）。
 *
 * 每页的 spec 都是 [SettingsPageState] 的**纯函数**：给同一份状态必然得到同一棵树，
 * 所以「开关 A 关掉后 B 行禁用」「统一课卡色关掉后色板消失」这类联动能在 JVM 单测里
 * 直接断言，不需要真机、不需要渲染。
 *
 * ## 枚举为什么在这里另起一套
 *
 * Dart 侧这些枚举（`lib/models/settings/timetable_settings_enums.dart:12-93`、
 * `timetable_settings_extensions.dart:294-384`、`lib/domain/course_auto_refresh_decision.dart:23-35`）
 * 的**完整设置模型移植属于设置族**，尚未合入（`core/TimetableSettings.kt:5-21`
 * 只搬了时间/周次四个字段，并明确写了「完整设置模型的合并/回写语义由设置族移植时补齐」）。
 * 在那之前，本包用页面局部镜像，[value] 与 Dart 的 `value` 字符串逐字一致，
 * 将来换成设置域枚举时按 [value] 对齐即可。
 *
 * 默认值一律照抄 `lib/models/timetable_settings.dart` 的构造默认值（行号写在每个字段上）。
 */
data class SettingsPageState(
    // ---------------------------------------------------------- 通用设置页
    val appLocaleTag: String = "",
    val pageTransitionSpeed: Double = 1.0, // :344 defaultPageTransitionSpeed
    val enableHaptics: Boolean = true, // :820
    val homePullQuickImportEnabled: Boolean = false, // :822
    /** null = 自动更新配置尚未加载完，整块不渲染（`course_auto_refresh_settings.dart:97-99`）。 */
    val autoRefresh: AutoRefreshState? = null,

    // ---------------------------------------------------------- 外观与配色页
    val appThemeMode: AppThemeMode = AppThemeMode.SYSTEM, // :796
    val appFontMode: AppFontMode = AppFontMode.SYSTEM, // :797
    val appFontWeight: Int = 400, // :798 / kAppFontWeightDefault
    val appTextScale: Double = 1.0, // :799 / kAppTextScaleDefault
    val foruiTheme: ForuiTheme = ForuiTheme.MIUI, // :890
    val themeSeedColor: String = "#3482FF", // :889
    /** 主题管理页：当前生效主题名（null = 没有主题存档，卡片不渲染）。 */
    val themeCheckpointName: String? = null,
    val themeHasModifications: Boolean = false,
    val savedThemes: List<SavedThemeRow> = emptyList(),

    // ---------------------------------------------------------- 课程卡片页
    val courseCardShowName: Boolean = true, // :765
    val courseCardShowTeacher: Boolean = true, // :766
    val courseCardShowLocation: Boolean = true, // :767
    val courseCardShowTime: Boolean = false, // :768
    val courseCardShowTimeLabels: Boolean = true, // :769
    val courseCardShowWeeks: Boolean = false, // :770
    val courseCardShowDescription: Boolean = false, // :771
    val courseCardSurfaceStyle: CourseCardSurfaceStyle = CourseCardSurfaceStyle.SOLID,
    val courseCardVerticalAlign: CourseCardVerticalAlign = CourseCardVerticalAlign.CENTER, // :780
    val courseCardHorizontalAlign: CourseCardHorizontalAlign = CourseCardHorizontalAlign.CENTER, // :781
    val courseCardFontSize: Double = 9.0, // :782
    val compactFontSize: Double = 9.0, // :755
    val timetableUseUnifiedCardColor: Boolean = false, // :901
    val timetableUnifiedCardColor: String = "#2563EB", // :902
    val showConflictBadgeOnTimetable: Boolean = true, // :763
    val timetableConflictCourseOpacity: Double = 0.70, // :764
    val linkCourseCardColors: Boolean = true, // :924
    val courseCardTitleColor: String = DEFAULT_CARD_TITLE_COLOR, // :914
    val courseCardDetailColor: String = DEFAULT_CARD_DETAIL_COLOR, // :916
    val courseCardTitleColorDark: String = DEFAULT_CARD_TITLE_COLOR, // :915
    val courseCardDetailColorDark: String = DEFAULT_CARD_DETAIL_COLOR, // :917
) {
    companion object {
        /** `TimetableSettings.defaultCourseCardTitleColor`（:283）。 */
        const val DEFAULT_CARD_TITLE_COLOR = "#FFFFFF"

        /** `TimetableSettings.defaultCourseCardDetailColor`（:284）。 */
        const val DEFAULT_CARD_DETAIL_COLOR = "#FFFFFF"
    }
}

/**
 * 「课表自动更新」整块的输入（`CourseAutoRefreshSchedule` + 台账摘要）。
 *
 * [lastSuccessLabel]/[nextRunLabel] 是**已格式化**的短时间（`9-21 07:30`），
 * 由页面按 `course_auto_refresh_settings.dart:246-252` 的格式拼好；
 * 底部整宽灰字由 [SettingsGeneralPage.autoRefreshSummary] 用 ARB 模板组装。
 */
data class AutoRefreshState(
    val enabled: Boolean = false,
    val mode: CourseAutoRefreshMode = CourseAutoRefreshMode.EVERY_LAUNCH,
    val intervalHours: Int = 24, // kCourseAutoRefreshDefaultIntervalHours
    val dailyMinuteOfDay: Int = 7 * 60 + 30, // kCourseAutoRefreshDefaultDailyMinute
    val lastSuccessLabel: String? = null,
    val nextRunLabel: String? = null,
)

/** 主题管理页「我的主题」的一行。 */
data class SavedThemeRow(
    val id: String,
    val name: String,
    val selected: Boolean = false,
    val previewColors: List<String> = emptyList(),
)

/** `AppThemeMode`（`timetable_settings_enums.dart:12`）。 */
enum class AppThemeMode(val value: String, val label: ArbText) {
    SYSTEM("system", SettingsStrings.themeModeSystem),
    LIGHT("light", SettingsStrings.themeModeLight),
    DARK("dark", SettingsStrings.themeModeDark),
}

/**
 * `AppFontMode`（枚举名 `timetable_settings_enums.dart:14-25`，磁盘值
 * `timetable_settings_extensions.dart:61-80`）。
 *
 * ⚠️ [value] 必须与磁盘值一致（下划线），不是 Dart 枚举名：`SettingsPageBridge.pick`
 * 按 `.value` 把模型档位映射到这里，写成驼峰会静默回落到默认档。
 */
enum class AppFontMode(val value: String, val label: ArbText) {
    SYSTEM("system", SettingsStrings.fontModeSystem),
    SANS_SERIF("sans_serif", SettingsStrings.fontModeSansSerif),
    MI_SANS("mi_sans", SettingsStrings.fontModeMiSans),
    HARMONY_OS("harmony_os", SettingsStrings.fontModeHarmonyOS),
    OPPO_SANS("oppo_sans", SettingsStrings.fontModeOppoSans),
    PING_FANG("ping_fang", SettingsStrings.fontModePingFang),
    NOTO_SANS("noto_sans", SettingsStrings.fontModeNotoSans),
    SERIF("serif", SettingsStrings.fontModeSerif),
    SONG_TI("songti", SettingsStrings.fontModeSongti),
    MONOSPACE("monospace", SettingsStrings.fontModeMonospace),
}

/** `ForuiTheme`（`timetable_settings_enums.dart:52-85`，含 `seedHex`）。 */
enum class ForuiTheme(val value: String, val label: ArbText, val seedHex: String) {
    MIUI("miui", SettingsStrings.foruiThemeMiuix, "#3482FF"),
    NEUTRAL("neutral", SettingsStrings.foruiThemeNeutral, "#171717"),
    ZINC("zinc", SettingsStrings.foruiThemeZinc, "#18181B"),
    SLATE("slate", SettingsStrings.foruiThemeSlate, "#0F172B"),
    BLUE("blue", SettingsStrings.foruiThemeBlue, "#1447E6"),
    GREEN("green", SettingsStrings.foruiThemeGreen, "#5EA500"),
    ORANGE("orange", SettingsStrings.foruiThemeOrange, "#F54A00"),
    RED("red", SettingsStrings.foruiThemeRed, "#E7000B"),
    ROSE("rose", SettingsStrings.foruiThemeRose, "#EC003F"),
    VIOLET("violet", SettingsStrings.foruiThemeViolet, "#7F22FE"),
    YELLOW("yellow", SettingsStrings.foruiThemeYellow, "#FCC800"),
}

/**
 * `CourseCardSurfaceStyle`（`timetable_settings_extensions.dart:294-350`）。
 *
 * 注意 [value]：液态玻璃档的**磁盘值是 `refraction`**，与枚举名 `liquidGlass`
 * 不同（老版本的 `liquidGlass` 字符串指现在的玻璃磨砂，改名会让存量配置换材质）。
 */
enum class CourseCardSurfaceStyle(val value: String, val label: ArbText) {
    SOLID("solid", SettingsStrings.courseCardSurfaceStyleSolid),
    GAUSSIAN("gaussian", SettingsStrings.courseCardSurfaceStyleGaussian),
    LIQUID_GLASS("refraction", SettingsStrings.courseCardSurfaceStyleLiquidGlass),
}

/** `CourseCardVerticalAlign`（`timetable_settings_extensions.dart:352-368`）。 */
enum class CourseCardVerticalAlign(val value: String, val label: ArbText) {
    TOP("top", SettingsStrings.courseCardVerticalAlignTop),
    CENTER("center", SettingsStrings.courseCardVerticalAlignCenter),
    BOTTOM("bottom", SettingsStrings.courseCardVerticalAlignBottom),
    SPACE_EVENLY("space_evenly", SettingsStrings.courseCardVerticalAlignSpaceEvenly),
}

/** `CourseCardHorizontalAlign`（`timetable_settings_extensions.dart:370-385`）。 */
enum class CourseCardHorizontalAlign(val value: String, val label: ArbText) {
    LEFT("left", SettingsStrings.courseCardHorizontalAlignLeft),
    CENTER("center", SettingsStrings.courseCardHorizontalAlignCenter),
    RIGHT("right", SettingsStrings.courseCardHorizontalAlignRight),
}

/** `CourseAutoRefreshMode`（`lib/domain/course_auto_refresh_decision.dart:23-35`）。 */
enum class CourseAutoRefreshMode(val value: String, val label: ArbText) {
    EVERY_LAUNCH("everyLaunch", SettingsStrings.courseAutoRefreshModeEveryLaunch),
    INTERVAL_HOURS("intervalHours", SettingsStrings.courseAutoRefreshModeInterval),
    DAILY_AT("dailyAt", SettingsStrings.courseAutoRefreshModeDaily),
}
