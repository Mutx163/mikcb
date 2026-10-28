package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.LenientJson
import com.mutx163.qingyu.core.MiniJson
import java.util.Locale

/**
 * 课表设置的**显示设置模型**（设置族竖切前置件，纯 Kotlin）。
 *
 * ## 它解决什么问题
 *
 * `core/TimetableSettings.kt` 只搬了时间/周次 **4 个键**（sections / activeTimeSchemeId /
 * semesterWeekCount / semesterStartDate），而设置族页面要读几十个显示设置键。
 * 在那层补齐之前，页面根本读不出值——这就是本文件。
 *
 * **所有权划分（不重叠）**：core 4 键仍归 `core/TimetableSettings` +
 * `TimetableStore.saveSettings`；本模型只拥有下面 [OWNED_KEYS] 列出的显示设置键。
 * 两者都通过 `TimetableStore.saveSettingsPatch` 做**读-合并-写**，所以谁都不会覆盖谁。
 *
 * ## 逐键对齐 Dart（`lib/models/timetable_settings.dart`，行号写在字段上）
 *
 * 每个键的**读口径**都从 Dart `fromJson` 抄，不是猜的：
 * `lenientBool/Double/Int/String(...) ?? 默认值`、枚举走 `X.fromValue(...)`、
 * 以及三处**规范化**（`normalizeAppFontWeight` / `normalizeAppTextScale` /
 * `normalizeAppLocaleTag`）和一处**联动回填**（`linkCourseCardColors` 为真时详情字色
 * 取标题字色）。落盘口径抄 `toJson`（枚举写 `.value`）。
 *
 * ## 三个「看着像默认值其实不是」的坑（都已按 Dart 读侧取）
 *
 * 1. `themeSeedColor`：**构造默认值是 `#3482FF`，而 `fromJson` 缺键默认是 `#2563EB`**
 *    （:889 vs :1696）。读侧口径取 `#2563EB`——用户从没改过种子色时，读出来就是它。
 * 2. `courseCardDetailColorLight/Dark`：`linkCourseCardColors` 为真（默认真）时
 *    **详情字色被标题字色覆盖**（:1304-1311），存档里那个值是脏的也不读。
 * 3. `appFontWeight` / `appTextScale` / `pageTransitionSpeed` /
 *    `timetableConflictCourseOpacity` 读侧都有 **clamp**（不是原样返回）。
 *
 * ## 写侧：显式 null 才能清键
 *
 * Dart 的 `toJson()` 用在**整体覆盖**上，null 值的键它直接省略；本模型走**合并写**，
 * 省略等于「保留旧值」，所以 [toJsonPatch] 把 null 也**显式写进 JSON**
 * （见 `TimetableStore.saveSettingsPatch` 的 KDoc）。两者读侧等价。
 *
 * ## 本批覆盖范围
 *
 * 覆盖 `pages/settings/SettingsPageState.kt` 的全部 45 个字段所需键 + `enableHolidayMarking`
 * （`SettingsTimetableState` 要），共 [OWNED_KEYS] 条。未覆盖的（超级岛 / 首页导航与菜单 /
 * 壁纸 / 玻璃材质调参 / 小组件 / 节假日 / 更新镜像 / 提醒）见认领文件
 * `.agents/compose-phase3/claims/P35-settings-model.md` 的覆盖率表。
 */
data class TimetableSettingsModel(
    // ---------- 通用设置页 ----------
    /** `appLocaleTag`（:1474，缺键回落 `appLocaleMode` 旧键再规范化）。 */
    val appLocaleTag: String = "",
    /** `pageTransitionSpeed`（:1533，缺键 1.0，clamp 0.5~2.5）。 */
    val pageTransitionSpeed: Double = DEFAULT_PAGE_TRANSITION_SPEED,
    /** `enableHaptics`（:1532）。 */
    val enableHaptics: Boolean = true,
    /** `homePullQuickImportEnabled`（:1537）。 */
    val homePullQuickImportEnabled: Boolean = false,
    /** `enableHolidayMarking`（:1397，`SettingsTimetableState` 要）。 */
    val enableHolidayMarking: Boolean = true,

    // ---------- 外观与配色页 ----------
    /** `appThemeMode`（:1464）。 */
    val appThemeMode: AppThemeMode = AppThemeMode.SYSTEM,
    /** `appFontMode`（:1467）。 */
    val appFontMode: AppFontMode = AppFontMode.SYSTEM,
    /** `appFontWeight`（:1468，`normalizeAppFontWeight`：round 后 clamp 100~900）。 */
    val appFontWeight: Int = APP_FONT_WEIGHT_DEFAULT,
    /** `appTextScale`（:1471，`normalizeAppTextScale`：clamp 0.85~1.6 再留两位小数）。 */
    val appTextScale: Double = APP_TEXT_SCALE_DEFAULT,
    /** `foruiTheme`（:1697）。 */
    val foruiTheme: ForuiTheme = ForuiTheme.MIUI,
    /** `themeSeedColor`（:1696，**缺键默认 `#2563EB`**，不是构造默认的 `#3482FF`）。 */
    val themeSeedColor: String = DEFAULT_SEED_COLOR_FROM_JSON,
    /** `themeCheckpointName`（:1277，Dart 写侧 null 时省略键）。 */
    val themeCheckpointName: String? = null,
    /** `themeCheckpointConfig`（:1279，嵌套主题快照；本层**原样保留**，不解析内部字段）。 */
    val themeCheckpointConfig: Map<String, Any?>? = null,
    /** `savedThemes`（:1276，逐条 map；本层原样保留，坏条目在读侧丢弃）。 */
    val savedThemes: List<Map<String, Any?>> = emptyList(),

    // ---------- 课程卡片页 ----------
    val courseCardShowName: Boolean = true, // :1405
    val courseCardShowTeacher: Boolean = true, // :1406
    val courseCardShowLocation: Boolean = true, // :1407
    val courseCardShowTime: Boolean = false, // :1409
    val courseCardShowTimeLabels: Boolean = true, // :1410
    val courseCardShowWeeks: Boolean = false, // :1412
    val courseCardShowDescription: Boolean = false, // :1413
    /** `courseCardSurfaceStyle`（:1260 / 读侧枚举 `fromValue`，磁盘值见枚举 KDoc）。 */
    val courseCardSurfaceStyle: CourseCardSurfaceStyle = CourseCardSurfaceStyle.SOLID,
    val courseCardVerticalAlign: CourseCardVerticalAlign = CourseCardVerticalAlign.CENTER, // :1426
    val courseCardHorizontalAlign: CourseCardHorizontalAlign = CourseCardHorizontalAlign.CENTER, // :1429
    val courseCardFontSize: Double = 9.0, // :1432
    val compactFontSize: Double = 9.0, // :1386
    val timetableUseUnifiedCardColor: Boolean = false, // :1726
    val timetableUnifiedCardColor: String = DEFAULT_UNIFIED_CARD_COLOR, // :1728
    val showConflictBadgeOnTimetable: Boolean = true, // :1400
    /** `timetableConflictCourseOpacity`（:1402，clamp 0.2~1.0）。 */
    val timetableConflictCourseOpacity: Double = 0.70,
    val linkCourseCardColors: Boolean = true, // :1296
    val courseCardTitleColorLight: String = DEFAULT_CARD_TITLE_COLOR, // :1298
    val courseCardTitleColorDark: String = DEFAULT_CARD_TITLE_COLOR, // :1301
    /** 联动为真时**等于** [courseCardTitleColorLight]（:1304）。 */
    val courseCardDetailColorLight: String = DEFAULT_CARD_DETAIL_COLOR,
    /** 联动为真时**等于** [courseCardTitleColorDark]（:1308）。 */
    val courseCardDetailColorDark: String = DEFAULT_CARD_DETAIL_COLOR,
) {

    /**
     * 本模型拥有的键（读与写都只碰这些）。
     *
     * 顺序与 Dart `toJson` 一致，便于人工对拍。
     */
    val ownedKeys: List<String> get() = OWNED_KEYS

    /**
     * 写侧 patch：**所有拥有键都会出现**，null 也显式写出（合并写下「省略」= 保留旧值，
     * 只有显式 null 才能清掉键）。
     */
    fun toJsonPatch(): Map<String, Any?> = linkedMapOf(
        "appLocaleTag" to appLocaleTag,
        "pageTransitionSpeed" to pageTransitionSpeed,
        "enableHaptics" to enableHaptics,
        "homePullQuickImportEnabled" to homePullQuickImportEnabled,
        "enableHolidayMarking" to enableHolidayMarking,
        "appThemeMode" to appThemeMode.value,
        "appFontMode" to appFontMode.value,
        "appFontWeight" to appFontWeight,
        "appTextScale" to appTextScale,
        "foruiTheme" to foruiTheme.value,
        "themeSeedColor" to themeSeedColor,
        "themeCheckpointName" to themeCheckpointName,
        "themeCheckpointConfig" to themeCheckpointConfig,
        "savedThemes" to savedThemes,
        "courseCardShowName" to courseCardShowName,
        "courseCardShowTeacher" to courseCardShowTeacher,
        "courseCardShowLocation" to courseCardShowLocation,
        "courseCardShowTime" to courseCardShowTime,
        "courseCardShowTimeLabels" to courseCardShowTimeLabels,
        "courseCardShowWeeks" to courseCardShowWeeks,
        "courseCardShowDescription" to courseCardShowDescription,
        "courseCardSurfaceStyle" to courseCardSurfaceStyle.value,
        "courseCardVerticalAlign" to courseCardVerticalAlign.value,
        "courseCardHorizontalAlign" to courseCardHorizontalAlign.value,
        "courseCardFontSize" to courseCardFontSize,
        "compactFontSize" to compactFontSize,
        "timetableUseUnifiedCardColor" to timetableUseUnifiedCardColor,
        "timetableUnifiedCardColor" to timetableUnifiedCardColor,
        "showConflictBadgeOnTimetable" to showConflictBadgeOnTimetable,
        "timetableConflictCourseOpacity" to timetableConflictCourseOpacity,
        "linkCourseCardColors" to linkCourseCardColors,
        "courseCardTitleColorLight" to courseCardTitleColorLight,
        "courseCardTitleColorDark" to courseCardTitleColorDark,
        "courseCardDetailColorLight" to courseCardDetailColorLight,
        "courseCardDetailColorDark" to courseCardDetailColorDark,
    )

    companion object {

        const val KEY = "timetable_settings"

        /** `defaultPageTransitionSpeed` / min / max（:344-346）。 */
        const val DEFAULT_PAGE_TRANSITION_SPEED = 1.0
        const val MIN_PAGE_TRANSITION_SPEED = 0.5
        const val MAX_PAGE_TRANSITION_SPEED = 2.5

        /** `kAppFontWeightDefault/Min/Max`（`timetable_settings_enums.dart:28-30`）。 */
        const val APP_FONT_WEIGHT_DEFAULT = 400
        const val APP_FONT_WEIGHT_MIN = 100
        const val APP_FONT_WEIGHT_MAX = 900

        /** `kAppTextScaleDefault/Min/Max`（`timetable_settings_enums.dart:34-36`）。 */
        const val APP_TEXT_SCALE_DEFAULT = 1.0
        const val APP_TEXT_SCALE_MIN = 0.85
        const val APP_TEXT_SCALE_MAX = 1.6

        /** `TimetableSettings.defaultCourseCardTitleColor/DetailColor`（:283-284）。 */
        const val DEFAULT_CARD_TITLE_COLOR = "#FFFFFF"
        const val DEFAULT_CARD_DETAIL_COLOR = "#FFFFFF"

        /** `timetableUnifiedCardColor` 的读侧缺键默认（:1728）。 */
        const val DEFAULT_UNIFIED_CARD_COLOR = "#2563EB"

        /** `themeSeedColor` 的**读侧**缺键默认（:1696，注意不是构造默认的 `#3482FF`）。 */
        const val DEFAULT_SEED_COLOR_FROM_JSON = "#2563EB"

        /** 本模型拥有并负责回写的键。 */
        val OWNED_KEYS: List<String> = listOf(
            "appLocaleTag",
            "pageTransitionSpeed",
            "enableHaptics",
            "homePullQuickImportEnabled",
            "enableHolidayMarking",
            "appThemeMode",
            "appFontMode",
            "appFontWeight",
            "appTextScale",
            "foruiTheme",
            "themeSeedColor",
            "themeCheckpointName",
            "themeCheckpointConfig",
            "savedThemes",
            "courseCardShowName",
            "courseCardShowTeacher",
            "courseCardShowLocation",
            "courseCardShowTime",
            "courseCardShowTimeLabels",
            "courseCardShowWeeks",
            "courseCardShowDescription",
            "courseCardSurfaceStyle",
            "courseCardVerticalAlign",
            "courseCardHorizontalAlign",
            "courseCardFontSize",
            "compactFontSize",
            "timetableUseUnifiedCardColor",
            "timetableUnifiedCardColor",
            "showConflictBadgeOnTimetable",
            "timetableConflictCourseOpacity",
            "linkCourseCardColors",
            "courseCardTitleColorLight",
            "courseCardTitleColorDark",
            "courseCardDetailColorLight",
            "courseCardDetailColorDark",
        )

        /**
         * 按 Dart `TimetableSettings.fromJson` 的读口径解析（缺键/类型不符/坏值一律回落默认）。
         */
        fun fromJson(json: Map<String, Any?>): TimetableSettingsModel {
            val linked = LenientJson.bool(json["linkCourseCardColors"]) ?: true
            val titleLight = LenientJson.string(json["courseCardTitleColorLight"])
                ?: DEFAULT_CARD_TITLE_COLOR
            val titleDark = LenientJson.string(json["courseCardTitleColorDark"])
                ?: DEFAULT_CARD_TITLE_COLOR
            return TimetableSettingsModel(
                appLocaleTag = normalizeAppLocaleTag(
                    LenientJson.string(json["appLocaleTag"])
                        ?: LenientJson.string(json["appLocaleMode"]),
                ),
                pageTransitionSpeed = (LenientJson.double(json["pageTransitionSpeed"])
                    ?: DEFAULT_PAGE_TRANSITION_SPEED)
                    .coerceIn(MIN_PAGE_TRANSITION_SPEED, MAX_PAGE_TRANSITION_SPEED),
                enableHaptics = LenientJson.bool(json["enableHaptics"]) ?: true,
                homePullQuickImportEnabled =
                    LenientJson.bool(json["homePullQuickImportEnabled"]) ?: false,
                enableHolidayMarking = LenientJson.bool(json["enableHolidayMarking"]) ?: true,
                appThemeMode = AppThemeMode.fromValue(LenientJson.string(json["appThemeMode"])),
                appFontMode = AppFontMode.fromValue(LenientJson.string(json["appFontMode"])),
                appFontWeight = normalizeAppFontWeight(LenientJson.double(json["appFontWeight"])),
                appTextScale = normalizeAppTextScale(LenientJson.double(json["appTextScale"])),
                foruiTheme = ForuiTheme.fromValue(LenientJson.string(json["foruiTheme"])),
                themeSeedColor = LenientJson.string(json["themeSeedColor"])
                    ?: DEFAULT_SEED_COLOR_FROM_JSON,
                themeCheckpointName = LenientJson.string(json["themeCheckpointName"]),
                themeCheckpointConfig = asMap(json["themeCheckpointConfig"]),
                savedThemes = asMapList(json["savedThemes"]),
                courseCardShowName = LenientJson.bool(json["courseCardShowName"]) ?: true,
                courseCardShowTeacher = LenientJson.bool(json["courseCardShowTeacher"]) ?: true,
                courseCardShowLocation = LenientJson.bool(json["courseCardShowLocation"]) ?: true,
                courseCardShowTime = LenientJson.bool(json["courseCardShowTime"]) ?: false,
                courseCardShowTimeLabels =
                    LenientJson.bool(json["courseCardShowTimeLabels"]) ?: true,
                courseCardShowWeeks = LenientJson.bool(json["courseCardShowWeeks"]) ?: false,
                courseCardShowDescription =
                    LenientJson.bool(json["courseCardShowDescription"]) ?: false,
                courseCardSurfaceStyle = CourseCardSurfaceStyle.fromValue(
                    LenientJson.string(json["courseCardSurfaceStyle"]),
                ),
                courseCardVerticalAlign = CourseCardVerticalAlign.fromValue(
                    LenientJson.string(json["courseCardVerticalAlign"]),
                ),
                courseCardHorizontalAlign = CourseCardHorizontalAlign.fromValue(
                    LenientJson.string(json["courseCardHorizontalAlign"]),
                ),
                courseCardFontSize = LenientJson.double(json["courseCardFontSize"]) ?: 9.0,
                compactFontSize = LenientJson.double(json["compactFontSize"]) ?: 9.0,
                timetableUseUnifiedCardColor =
                    LenientJson.bool(json["timetableUseUnifiedCardColor"]) ?: false,
                timetableUnifiedCardColor = LenientJson.string(json["timetableUnifiedCardColor"])
                    ?: DEFAULT_UNIFIED_CARD_COLOR,
                showConflictBadgeOnTimetable =
                    LenientJson.bool(json["showConflictBadgeOnTimetable"]) ?: true,
                timetableConflictCourseOpacity =
                    (LenientJson.double(json["timetableConflictCourseOpacity"]) ?: 0.70)
                        .coerceIn(0.2, 1.0),
                linkCourseCardColors = linked,
                courseCardTitleColorLight = titleLight,
                courseCardTitleColorDark = titleDark,
                // 联动为真：详情字色**被标题字色覆盖**（存档里的旧值不读）。
                courseCardDetailColorLight = if (linked) {
                    titleLight
                } else {
                    LenientJson.string(json["courseCardDetailColorLight"]) ?: DEFAULT_CARD_DETAIL_COLOR
                },
                courseCardDetailColorDark = if (linked) {
                    titleDark
                } else {
                    LenientJson.string(json["courseCardDetailColorDark"]) ?: DEFAULT_CARD_DETAIL_COLOR
                },
            )
        }

        /** Dart `normalizeAppFontWeight`（`timetable_settings_enums.dart:40-45`）。 */
        fun normalizeAppFontWeight(value: Double?): Int {
            if (value == null) return APP_FONT_WEIGHT_DEFAULT
            return Math.round(value).toInt().coerceIn(APP_FONT_WEIGHT_MIN, APP_FONT_WEIGHT_MAX)
        }

        /**
         * Dart `normalizeAppTextScale`（`timetable_settings_enums.dart:46-51`）：
         * clamp 后 `double.parse(clamped.toStringAsFixed(2))`——保留两位小数。
         * 用 [Locale.ROOT] 格式化，避免逗号小数点区域把 `toDouble` 弄崩。
         */
        fun normalizeAppTextScale(value: Double?): Double {
            if (value == null) return APP_TEXT_SCALE_DEFAULT
            val clamped = value.coerceIn(APP_TEXT_SCALE_MIN, APP_TEXT_SCALE_MAX)
            return String.format(Locale.ROOT, "%.2f", clamped).toDouble()
        }

        /**
         * Dart `normalizeAppLocaleTag`（`lib/utils/app_locale_tag.dart:7-17`）：
         * 空与 `system` 归空串；`-` → `_`；`en_us`→`en`、`zh_cn`→`zh`（小写比较）；
         * 其余保留原文（大小写不动）。
         */
        fun normalizeAppLocaleTag(value: String?): String {
            val normalized = (value ?: "").trim()
            if (normalized.isEmpty() || normalized == "system") return ""
            val canonical = normalized.replace('-', '_')
            return when (canonical.lowercase(Locale.ROOT)) {
                "en_us" -> "en"
                "zh_cn" -> "zh"
                else -> canonical
            }
        }

        private fun asMap(raw: Any?): Map<String, Any?>? {
            if (raw !is Map<*, *>) return null
            val out = LinkedHashMap<String, Any?>()
            for ((key, value) in raw) {
                if (key is String) out[key] = value
            }
            return out
        }

        /** Dart `SavedTheme.listFromJson`：非 Map 条目丢弃，不让单条坏数据炸整份。 */
        private fun asMapList(raw: Any?): List<Map<String, Any?>> {
            if (raw !is List<*>) return emptyList()
            val out = ArrayList<Map<String, Any?>>(raw.size)
            for (item in raw) {
                asMap(item)?.let { out.add(it) }
            }
            return out
        }
    }
}

/**
 * 设置族完整模型的**读写入口**：`timetable_settings` 的读-合并-写。
 *
 * 与 `TimetableStore.loadSettings/saveSettings`（core 4 键）共用同一个键与同一套合并语义
 * （都走 `TimetableStore.saveSettingsPatch`），所以两边互不覆盖。
 */
class TimetableSettingsModelStore(private val store: TimetableStore) {

    /** 读；盘上不是 JSON 对象时由 [TimetableStore.loadSettingsJson] 留档 + 删 key，返回默认值。 */
    fun load(): TimetableSettingsModel = TimetableSettingsModel.fromJson(store.loadSettingsJson())

    /** 合并写：只覆盖本模型拥有的键，其余键原样保留。 */
    fun save(model: TimetableSettingsModel) {
        store.saveSettingsPatch(model.toJsonPatch())
    }
}

/** `AppThemeMode`（`timetable_settings_enums.dart:12`）。 */
enum class AppThemeMode(val value: String) {
    SYSTEM("system"),
    LIGHT("light"),
    DARK("dark");

    companion object {
        /** 未知值回落 system（Dart `X.fromValue`）。 */
        fun fromValue(raw: String?): AppThemeMode =
            entries.firstOrNull { it.value == raw } ?: SYSTEM
    }
}

/** `AppFontMode`（`timetable_settings_enums.dart:14-25`）。 */
enum class AppFontMode(val value: String) {
    SYSTEM("system"),
    SANS_SERIF("sansSerif"),
    MI_SANS("miSans"),
    HARMONY_OS("harmonyOS"),
    OPPO_SANS("oppoSans"),
    PING_FANG("pingFang"),
    NOTO_SANS("notoSans"),
    SERIF("serif"),
    SONG_TI("songti"),
    MONOSPACE("monospace");

    companion object {
        fun fromValue(raw: String?): AppFontMode =
            entries.firstOrNull { it.value == raw } ?: SYSTEM
    }
}

/** `ForuiTheme`（`timetable_settings_enums.dart:52-85`，含 `seedHex`）。 */
enum class ForuiTheme(val value: String, val seedHex: String) {
    MIUI("miui", "#3482FF"),
    NEUTRAL("neutral", "#171717"),
    ZINC("zinc", "#18181B"),
    SLATE("slate", "#0F172B"),
    BLUE("blue", "#1447E6"),
    GREEN("green", "#5EA500"),
    ORANGE("orange", "#F54A00"),
    RED("red", "#E7000B"),
    ROSE("rose", "#EC003F"),
    VIOLET("violet", "#7F22FE"),
    YELLOW("yellow", "#FCC800");

    companion object {
        fun fromValue(raw: String?): ForuiTheme =
            entries.firstOrNull { it.value == raw } ?: MIUI
    }
}

/**
 * `CourseCardSurfaceStyle`（`timetable_settings_extensions.dart:294-350`）。
 *
 * ⚠️ 液态玻璃档的**磁盘值是 `refraction`**，与枚举名不同：老版本的 `liquidGlass`
 * 字符串指现在的玻璃磨砂，改名会让存量配置换材质。
 */
enum class CourseCardSurfaceStyle(val value: String) {
    SOLID("solid"),
    GAUSSIAN("gaussian"),
    LIQUID_GLASS("refraction");

    companion object {
        fun fromValue(raw: String?): CourseCardSurfaceStyle =
            entries.firstOrNull { it.value == raw } ?: SOLID
    }
}

/** `CourseCardVerticalAlign`（`timetable_settings_extensions.dart:352-368`）。 */
enum class CourseCardVerticalAlign(val value: String) {
    TOP("top"),
    CENTER("center"),
    BOTTOM("bottom"),
    SPACE_EVENLY("space_evenly");

    companion object {
        fun fromValue(raw: String?): CourseCardVerticalAlign =
            entries.firstOrNull { it.value == raw } ?: CENTER
    }
}

/** `CourseCardHorizontalAlign`（`timetable_settings_extensions.dart:370-385`）。 */
enum class CourseCardHorizontalAlign(val value: String) {
    LEFT("left"),
    CENTER("center"),
    RIGHT("right");

    companion object {
        fun fromValue(raw: String?): CourseCardHorizontalAlign =
            entries.firstOrNull { it.value == raw } ?: CENTER
    }
}
