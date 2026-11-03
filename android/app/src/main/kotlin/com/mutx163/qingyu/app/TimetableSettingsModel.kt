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
 * semesterWeekCount / semesterStartDate）+ 单节课提醒 **classReminders**，而设置族页面
 * 要读几十个显示设置键。
 * 在那层补齐之前，页面根本读不出值——这就是本文件。
 *
 * **所有权划分（不重叠）**：core 4 键 + `classReminders` 仍归 `core/TimetableSettings` +
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
 * （`SettingsTimetableState` 要）+ 桌面小组件 10 键（`timetable_settings.dart:786-795`），
 * 共 [OWNED_KEYS] 条。未覆盖的（超级岛 / 节假日 / 更新镜像 / 提醒）见认领文件
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

    // ---------- 课表显示（batch 2：settings_timetable_page 所需） ----------
    /** `sectionHeight`（:1385，缺键 68）。 */
    val sectionHeight: Double = 68.0,
    /** `timetableAutoFitSectionHeight`（:1387，缺键 false）。 */
    val timetableAutoFitSectionHeight: Boolean = false,
    /** `timetableShowNonCurrentWeekCourses`（:1398，缺键 false）。 */
    val timetableShowNonCurrentWeekCourses: Boolean = false,
    val weekGridShowExams: Boolean = true, // :1416
    val weekGridShowSchedules: Boolean = true, // :1417
    val weatherShowOnDayCard: Boolean = true, // :1415
    val weatherShowOnWeekCard: Boolean = true, // :1419
    val weatherShowOnSheet: Boolean = true, // :1420
    val weatherShowPhenomenon: Boolean = true, // :1421
    val weatherShowTemperature: Boolean = true, // :1422
    val weatherShowProbability: Boolean = false, // :1424
    val timetableTimeColumnWidthMode: TimetableTimeColumnWidthMode =
        TimetableTimeColumnWidthMode.NARROW, // :1433
    val timetableCourseSpacingMode: TimetableCourseSpacingMode =
        TimetableCourseSpacingMode.NARROW, // :1441
    /**
     * `timetableCourseCardGap`（:1436-1440）。
     *
     * ⚠️ 缺键时**不是固定默认值**，而是按 `timetableCourseSpacingMode` 的**原始字符串**
     * 推导：`wide` → 2.0，其余（含坏值/缺键）→ 1.25。这是「看着像常量其实不是」的坑。
     */
    val timetableCourseCardGap: Double = DEFAULT_COURSE_CARD_GAP,
    val timetableSectionTimeDisplayMode: SectionTimeDisplayMode =
        SectionTimeDisplayMode.START_AND_END, // :1528
    val timetableHideWeekends: Boolean = false, // :1531
    /** `timetableLastViewedDayOfWeek`（:1521，缺键 1，clamp 1~7）。 */
    val timetableLastViewedDayOfWeek: Int = 1,
    val coupleTimetableOverlayEnabled: Boolean = false, // :1526
    val screenshotSharePromptEnabled: Boolean = true, // :1539
    val longPressEmptySlotToAddCourseEnabled: Boolean = false, // :1541

    // ---------- 星期栏 / 时间轴字色（batch 2） ----------
    val weekdayBarFontColorLight: String = DEFAULT_WEEKDAY_BAR_FONT_LIGHT, // :1755
    val weekdayBarFontColorDark: String = DEFAULT_WEEKDAY_BAR_FONT_DARK, // :1758
    val weekdayBarAccentColorLight: String = DEFAULT_WEEKDAY_BAR_ACCENT_LIGHT, // :1761
    val weekdayBarAccentColorDark: String = DEFAULT_WEEKDAY_BAR_ACCENT_DARK, // :1764
    val timeAxisFontColorLight: String = DEFAULT_TIME_AXIS_FONT_LIGHT, // :1767
    val timeAxisFontColorDark: String = DEFAULT_TIME_AXIS_FONT_DARK, // :1770

    // ---------- 首页导航与玻璃坞（batch 3） ----------
    val homeTitleStyle: HomeTitleStyle = HomeTitleStyle.CLASSIC, // :1478
    val timetableHomeViewMode: TimetableHomeViewMode = TimetableHomeViewMode.WEEK, // :1481
    val homeNavigationForm: HomeNavigationForm = HomeNavigationForm.CLASSIC, // :1484
    val homeMenuStyle: HomeMenuStyle = HomeMenuStyle.LIST, // :1489
    /** `homeGridMenuActions`（:1500，去重 / 截断到 8 / 钉住 `settings`）。 */
    val homeGridMenuActions: List<String> = emptyList(),
    /**
     * `glassDockActions`（:1492-1499）。
     *
     * ⚠️ 缺键（或类型不对）时**不是空表**，而是由 `glassDockShowDayTab` /
     * `glassDockShowWeekTab`（两者缺省都是 true）推导出 `['day','week']`；
     * 但**显式给了空数组就是空表**（渲染层再回落默认值）。去重、截断到 5、不钉项。
     */
    val glassDockActions: List<String> = emptyList(),
    val glassDockShowDayTab: Boolean = true, // :1504
    val glassDockShowSettingsTab: Boolean = true, // :1505
    val glassDockShowWeekTab: Boolean = true, // :1507
    val glassDockButtonEntryId: String = DEFAULT_GLASS_DOCK_BUTTON_ENTRY_ID, // :1508
    val glassDockButtonIconName: String? = null, // :1510
    val glassDockShowAddButton: Boolean = false, // :1511
    /**
     * `timetableBackToCurrentWeekButtonStyle`（:1513）。
     *
     * ⚠️ 读侧把**存量 `'inline'` 与一切未知值都映射成 `FLOATING`**
     * （`BackToCurrentWeekButtonStyleX.fromValue` 的迁移注释：内嵌小字入口已收敛为浮钮）。
     * 枚举保留 INLINE 只为让写侧能表达旧值，**读回来的永远不可能是 INLINE**。
     */
    val timetableBackToCurrentWeekButtonStyle: BackToCurrentWeekButtonStyle =
        BackToCurrentWeekButtonStyle.FLOATING,
    /** `timetableFloatingBackToCurrentWeekButtonOpacity`（:1517，缺键 0.96，clamp 0.55~1.0）。 */
    val timetableFloatingBackToCurrentWeekButtonOpacity: Double = 0.96,

    // ---------- 桌面小组件（`timetable_settings.dart:786-795` 构造默认 / `:1444-1461` 读侧） ----------
    /**
     * `widgetBackgroundStyle`（:786，构造默认 `WidgetBackgroundStyle.solid`）。
     *
     * 落盘串见 `timetable_settings_extensions.dart:31-36`：`glass` / `solid` / `gradient`。
     * 读侧走 `X.fromValue` 语义——缺键与未知串一律回落 [DEFAULT_WIDGET_BACKGROUND_STYLE]。
     */
    val widgetBackgroundStyle: String = DEFAULT_WIDGET_BACKGROUND_STYLE,
    /** `widgetCourseAccentMode`（:787 `barAndText`；落盘串 `widget_course_accent.dart:23-30`）。 */
    val widgetCourseAccentMode: String = DEFAULT_WIDGET_COURSE_ACCENT_MODE,
    /** `widgetShowLocation`（:788，缺键 true）。 */
    val widgetShowLocation: Boolean = true,
    /** `widgetShowCountdown`（:789，缺键 true）；false 时倒计时整块连同提前量/样式两行一起消失。 */
    val widgetShowCountdown: Boolean = true,
    /** `widgetHideCompletedCourses`（:790，缺键 false）。 */
    val widgetHideCompletedCourses: Boolean = false,
    /** `widgetShowTomorrowCourses`（:791，缺键 true）。 */
    val widgetShowTomorrowCourses: Boolean = true,
    /**
     * `widgetHeightAdjustment`（:792，读侧 `lenientDouble(...) ?? -11`，**Dart 不夹**）。
     *
     * 这是**绝对档位**；滑杆读数是相对它的偏移（`settings_home_widget.dart:344-359`）。
     */
    val widgetHeightAdjustment: Double = DEFAULT_WIDGET_HEIGHT_ADJUSTMENT,
    /** `widgetCornerRadius`（:793，读侧 `lenientDouble(...) ?? 22`，**Dart 不夹**）。 */
    val widgetCornerRadius: Double = DEFAULT_WIDGET_CORNER_RADIUS,
    /** `widgetCountdownLeadMinutes`（:794，读侧 `lenientInt(...) ?? 20`，**Dart 不夹**；0 = 始终显示）。 */
    val widgetCountdownLeadMinutes: Int = DEFAULT_WIDGET_COUNTDOWN_LEAD_MINUTES,
    /** `widgetCountdownTextStyle`（:795 `LiveCountdownTextStyle.smart`；12 档落盘串见 extensions:153-167）。 */
    val widgetCountdownTextStyle: String = DEFAULT_WIDGET_COUNTDOWN_TEXT_STYLE,

    /**
     * `liveEnableLocalDiagnostics`（`timetable_settings.dart:517 / :851 / :1602-1603`）：
     * 「记录应用日志」开关。缺键回落 false（Dart `lenientBool(...) ?? false`）。
     *
     * 设置→诊断页（`settings_diagnostics.dart:38-41 / :121-147`）唯一的读写方。
     */
    val liveEnableLocalDiagnostics: Boolean = false,

    // ---------- 材质与液态玻璃（外观编辑页材质面板所需） ----------
    /**
     * 模糊总开关（`timetable_settings.dart:655` 字段、`:925` 构造默认
     * `defaultFrostedBlurEnabled`（`:292` = true）、`:1773-1774` 读侧）。
     *
     * 它就是整机「默认材质」两档里较钝的那一档（`glass_mode_choice.dart:22-24`）：
     * 关掉 ⇒ 实体卡片，全 app 不再有液态玻璃表面。
     */
    val frostedBlurEnabled: Boolean = true,
    /**
     * 首页顶栏玻璃带开关（`timetable_settings.dart:707` / `:935`）。
     *
     * ⚠️ 读侧**恒为 true**：那两个开关键在 Dart 侧已下线（界面不再有入口），
     * `fromJson` 直接写死（`:1827-1829`「两个玻璃带显示开关已下线，恒为开」）。
     * 本模型照抄——存档里的旧值不读，与 Dart 逐字同口径。
     */
    val homePageHeaderBlurEnabled: Boolean = true,
    /**
     * 首页顶栏玻璃带材质（`timetable_settings.dart:722` / `:937` / 读侧 `:1837-1846`）。
     *
     * 三档 `follow` / `liquid` / `solid`，读侧一律过 `sanitizeHomeBandGlassMaterial`
     * （`:339-343`）：不属于这三档的一切取值（含存量 progressive / gaussian / soft）
     * 都归 `liquid`。**不要**直接拿本字段判分支——`follow` 要按模糊总开关解析成
     * 生效值（`:730-735`，Kotlin 侧是 `SettingsMaterialModel.effectiveHomeBandMaterial`）。
     */
    val homeBandGlassMaterial: String = DEFAULT_HOME_BAND_GLASS_MATERIAL,
    /**
     * 液态玻璃档位（`timetable_settings.dart:671` / `:928` / 读侧 `:1786-1798`）。
     *
     * 存档值是 `clear` / `level2`…`dense` / `custom`（`liquid_glass_tuning.dart:44-84`）。
     * 缺键与不认识的值回落 `standard`，但**还要与参数键收敛**
     * —— 判据见 [LiquidGlassTuningModel.reconcileStoredPreset]。
     */
    val liquidGlassPreset: String = LIQUID_GLASS_PRESET_STANDARD,
    /** 浅色档那八个参数（`:672` / `:929`）；null = 从没调过，渲染回落出厂档（`:664-666`）。 */
    val liquidGlassTuning: LiquidGlassTuningModel? = null,
    /** 深色档那八个参数（`:675` / `:930`）；null = 跟随浅色档。 */
    val liquidGlassTuningDark: LiquidGlassTuningModel? = null,
    /** 深色档是否跟随浅色档（`:682` / `:931`，构造默认 `:307` `defaultLinkLiquidGlassTuning` = true）。 */
    val linkLiquidGlassTuning: Boolean = true,
    /** 深色模式是否套「变暗配方」（`:685` / `:932`，构造默认 `:313` = true）。 */
    val darkGlassBoostEnabled: Boolean = true,
    /** 玻璃坞（含坞内圆钮）是否走液态玻璃（`:661` / `:926`，构造默认 `:300` = true）。 */
    val liquidGlassDockEnabled: Boolean = true,
    /** 课程卡片自己那档的档位（`:705` / `:934` / 读侧 `:1811-1826`，收敛口径同上）。 */
    val courseCardGlassPreset: String = LIQUID_GLASS_PRESET_STANDARD,
    /** 课程卡片那八个参数（`:695` / `:933`）；null = 出厂卡片档。 */
    val courseCardGlassTuning: LiquidGlassTuningModel? = null,
    /**
     * 时间列（时间轴）是否走液态玻璃模糊（`:737` / 构造默认 `:938` = false / 读侧 `:1847-1848`）。
     *
     * 属「外观」恢复默认作用域（`settings_reset.dart:155`），控件在材质轴里。
     */
    val homePageTimeColumnBlurEnabled: Boolean = false,

    // ---------- 课表页面背景（`timetable_settings.dart:556-558` / `:891-893` / `:1698-1704`） ----------
    /**
     * 课表页纯色背景（`:556` / 构造默认 `:891` `#F8FAFC` / 读侧 `:1698-1699`）。
     *
     * 色板写在 `SettingsTimetablePageSettingsPage.BACKGROUND_COLORS`；存量值可能是
     * 旧存档 / 手改 JSON 里的任意色，读侧**不校验**是否在色板内（Dart 同口径）。
     */
    val timetablePageBackgroundColor: String = DEFAULT_TIMETABLE_PAGE_BACKGROUND_COLOR,
    /**
     * 背景填充形态（`:557` / 构造默认 `:892` `color` / 读侧 `:1700-1702`）。
     *
     * 落盘串 `color` / `image`（`HomePageBackgroundFillX.value` = 枚举名）。
     * 未知值回落 `color`，与 Dart `fromValue` 的 `orElse` 一致。
     */
    val homePageBackgroundFill: HomePageBackgroundFill = HomePageBackgroundFill.COLOR,
    /**
     * 旧版背景图路径（`:558` / 构造默认 `:893` null / 读侧 `:1703-1704`）。
     *
     * ⚠️ 新版壁纸已经迁到 [homePageWallpaperPath]（`home_page_background.dart:346-356`
     * 的 `resolveHomePageBackdropImagePath`：壁纸优先、本字段只是老存档的回退）。
     * Dart 写侧**只在非 null 时写键**（`:1222-1223`）；本模型是合并写，要清掉旧键
     * 必须显式写 null，所以这里照其它可空键的写法进 patch。
     */
    val homePageBackgroundImagePath: String? = null,
    /**
     * 背景透出范围位标志（`:595` / 构造默认 `:900`）。
     *
     * ⚠️ **Dart 已下线这个键**：读侧恒写默认值（`:1725`），写侧不再写（`:1233`
     * 「homePageBackgroundScope 已下线」）。保留字段只为恢复默认作用域
     * （`settings_reset.dart:112`）与诊断口径，**不参与序列化**（见 [toJsonPatch]）。
     */
    val homePageBackgroundScope: Int = DEFAULT_HOME_PAGE_BACKGROUND_SCOPE,

    // ---------- 首页壁纸（`timetable_settings.dart:559-594` + `:746`） ----------
    /** 壁纸路径（`:559` / 构造默认 `:894`；null = 没有壁纸）。 */
    val homePageWallpaperPath: String? = null,
    /** 取景水平对齐（`:563` / `:895`，-1 靠左 … 0 居中 … 1 靠右）。 */
    val homePageWallpaperAlignX: Double = 0.0,
    /** 取景垂直对齐（`:567` / `:896`，-1 靠上 … 0 居中 … 1 靠下）。 */
    val homePageWallpaperAlignY: Double = 0.0,
    /**
     * 放大倍数（`:580` / `:897`，1 = 刚好铺满 = cover 的原始大小）。
     *
     * ⚠️ 读侧**不夹**（Dart `:1712-1713` 就是 `?? 1`）：夹在渲染 / 编辑两侧，
     * 共用 `kWallpaperMinScale` / `kWallpaperMaxScale` = 1 / 4（`home_page_background.dart:586-587`）。
     */
    val homePageWallpaperScale: Double = 1.0,
    /**
     * 壁纸高斯模糊强度（`:587` / `:898`，0 = 不模糊）。
     *
     * 读侧夹在 `minHomePageWallpaperBlurSigma`…`maxHomePageWallpaperBlurSigma` = 0…24
     * （`:353-360` 的 `clampHomePageWallpaperBlurSigma`），越界值一律收口。
     */
    val homePageWallpaperBlurSigma: Double = MIN_HOME_PAGE_WALLPAPER_BLUR_SIGMA,
    /** 「最近使用」历史（`:594` / `:899`，最新在前；脏条目在 [WallpaperHistoryRowModel.listFromJson] 里逐条丢弃）。 */
    val wallpaperHistory: List<WallpaperHistoryRowModel> = emptyList(),
    /** 背景是否跟着周次翻页一起滑动（`:746` / `:939`，**默认关**；读侧缺键也是关，`:1849-1853`）。 */
    val homePageBackdropFollowsWeekPager: Boolean = false,
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
        "sectionHeight" to sectionHeight,
        "timetableAutoFitSectionHeight" to timetableAutoFitSectionHeight,
        "timetableShowNonCurrentWeekCourses" to timetableShowNonCurrentWeekCourses,
        "weekGridShowExams" to weekGridShowExams,
        "weekGridShowSchedules" to weekGridShowSchedules,
        "weatherShowOnDayCard" to weatherShowOnDayCard,
        "weatherShowOnWeekCard" to weatherShowOnWeekCard,
        "weatherShowOnSheet" to weatherShowOnSheet,
        "weatherShowPhenomenon" to weatherShowPhenomenon,
        "weatherShowTemperature" to weatherShowTemperature,
        "weatherShowProbability" to weatherShowProbability,
        "timetableTimeColumnWidthMode" to timetableTimeColumnWidthMode.value,
        "timetableCourseSpacingMode" to timetableCourseSpacingMode.value,
        "timetableCourseCardGap" to timetableCourseCardGap,
        "timetableSectionTimeDisplayMode" to timetableSectionTimeDisplayMode.value,
        "timetableHideWeekends" to timetableHideWeekends,
        "timetableLastViewedDayOfWeek" to timetableLastViewedDayOfWeek,
        "coupleTimetableOverlayEnabled" to coupleTimetableOverlayEnabled,
        "screenshotSharePromptEnabled" to screenshotSharePromptEnabled,
        "longPressEmptySlotToAddCourseEnabled" to longPressEmptySlotToAddCourseEnabled,
        "weekdayBarFontColorLight" to weekdayBarFontColorLight,
        "weekdayBarFontColorDark" to weekdayBarFontColorDark,
        "weekdayBarAccentColorLight" to weekdayBarAccentColorLight,
        "weekdayBarAccentColorDark" to weekdayBarAccentColorDark,
        "timeAxisFontColorLight" to timeAxisFontColorLight,
        "timeAxisFontColorDark" to timeAxisFontColorDark,
        "homeTitleStyle" to homeTitleStyle.value,
        "timetableHomeViewMode" to timetableHomeViewMode.value,
        "homeNavigationForm" to homeNavigationForm.value,
        "homeMenuStyle" to homeMenuStyle.value,
        "homeGridMenuActions" to homeGridMenuActions,
        "glassDockActions" to glassDockActions,
        "glassDockShowDayTab" to glassDockShowDayTab,
        "glassDockShowSettingsTab" to glassDockShowSettingsTab,
        "glassDockShowWeekTab" to glassDockShowWeekTab,
        "glassDockButtonEntryId" to glassDockButtonEntryId,
        "glassDockButtonIconName" to glassDockButtonIconName,
        "glassDockShowAddButton" to glassDockShowAddButton,
        "timetableBackToCurrentWeekButtonStyle" to timetableBackToCurrentWeekButtonStyle.value,
        "timetableFloatingBackToCurrentWeekButtonOpacity" to
            timetableFloatingBackToCurrentWeekButtonOpacity,
        // ---------- 桌面小组件（写侧口径：`timetable_settings.dart:1103-1112`） ----------
        "widgetBackgroundStyle" to widgetBackgroundStyle,
        "widgetCourseAccentMode" to widgetCourseAccentMode,
        "widgetShowLocation" to widgetShowLocation,
        "widgetShowCountdown" to widgetShowCountdown,
        "widgetHideCompletedCourses" to widgetHideCompletedCourses,
        "widgetShowTomorrowCourses" to widgetShowTomorrowCourses,
        "widgetHeightAdjustment" to widgetHeightAdjustment,
        "widgetCornerRadius" to widgetCornerRadius,
        "widgetCountdownLeadMinutes" to widgetCountdownLeadMinutes,
        "widgetCountdownTextStyle" to widgetCountdownTextStyle,
        "liveEnableLocalDiagnostics" to liveEnableLocalDiagnostics,
        // ---------- 课表页面背景（写侧口径：`timetable_settings.dart:1220-1223`） ----------
        // `homePageBackgroundScope` **不写**：Dart 已下线该键（`:1233`），只在读侧固定默认。
        "timetablePageBackgroundColor" to timetablePageBackgroundColor,
        "homePageBackgroundFill" to homePageBackgroundFill.value,
        "homePageBackgroundImagePath" to homePageBackgroundImagePath,
        // ---------- 首页壁纸（写侧口径：`timetable_settings.dart:1224-1232`） ----------
        "homePageWallpaperPath" to homePageWallpaperPath,
        "homePageWallpaperAlignX" to homePageWallpaperAlignX,
        "homePageWallpaperAlignY" to homePageWallpaperAlignY,
        "homePageWallpaperScale" to homePageWallpaperScale,
        "homePageWallpaperBlurSigma" to homePageWallpaperBlurSigma,
        "wallpaperHistory" to wallpaperHistory.map { it.toJson() },
        // ---------- 材质与液态玻璃（写侧口径：`timetable_settings.dart:1258-1275`） ----------
        "frostedBlurEnabled" to frostedBlurEnabled,
        "liquidGlassDockEnabled" to liquidGlassDockEnabled,
        "liquidGlassPreset" to liquidGlassPreset,
        // Dart 写侧对这三个可空参数是「null 时省略键」（`:1262-1269`）；本模型是**合并写**，
        // 省略等于保留旧值、清不掉，所以显式写 null（见类注释「写侧：显式 null 才能清键」）。
        "liquidGlassTuning" to liquidGlassTuning?.toJson(),
        "liquidGlassTuningDark" to liquidGlassTuningDark?.toJson(),
        "linkLiquidGlassTuning" to linkLiquidGlassTuning,
        "darkGlassBoostEnabled" to darkGlassBoostEnabled,
        "courseCardGlassTuning" to courseCardGlassTuning?.toJson(),
        "courseCardGlassPreset" to courseCardGlassPreset,
        "homePageHeaderBlurEnabled" to homePageHeaderBlurEnabled,
        "homeBandGlassMaterial" to homeBandGlassMaterial,
        "homePageTimeColumnBlurEnabled" to homePageTimeColumnBlurEnabled,
        "homePageBackdropFollowsWeekPager" to homePageBackdropFollowsWeekPager,
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

        /** `timetablePageBackgroundColor` 的构造默认与读侧缺键默认（`:891` / `:1699`）。 */
        const val DEFAULT_TIMETABLE_PAGE_BACKGROUND_COLOR = "#F8FAFC"

        /**
         * `HomePageBackgroundScope.defaultValue`（`timetable_settings_enums.dart:111-121`）：
         * 课表 1 | 星期栏 2 | 顶栏 4 | 状态栏 8 = 15。
         *
         * Dart 已下线这个键（读侧恒此值、写侧不写），保留常量只为恢复默认与诊断口径。
         */
        const val DEFAULT_HOME_PAGE_BACKGROUND_SCOPE = 15

        /** `timetableCourseCardGap` 的两种缺键默认（:1436-1440，按 spacingMode 选）。 */
        const val DEFAULT_COURSE_CARD_GAP = 1.25
        const val DEFAULT_COURSE_CARD_GAP_WIDE = 2.0

        /** `defaultWeekdayBar*` 与 `defaultTimeAxisFont*` 六条颜色默认值（:285-290）。 */
        const val DEFAULT_WEEKDAY_BAR_FONT_LIGHT = "#000000"
        const val DEFAULT_WEEKDAY_BAR_FONT_DARK = "#FFFFFF"
        const val DEFAULT_WEEKDAY_BAR_ACCENT_LIGHT = "#2563EB"
        const val DEFAULT_WEEKDAY_BAR_ACCENT_DARK = "#93C5FD"
        const val DEFAULT_TIME_AXIS_FONT_LIGHT = "#757575"
        const val DEFAULT_TIME_AXIS_FONT_DARK = "#FFFFFF"

        /** `glassDockButtonEntryId` 缺键默认（:1508-1509）。 */
        const val DEFAULT_GLASS_DOCK_BUTTON_ENTRY_ID = "addCourse"

        /** `HomeGridMenu` 槽位上限与钉住项（`timetable_settings_enums.dart:160-208`）。 */
        const val HOME_GRID_MENU_MAX_SLOTS = 8
        const val HOME_GRID_MENU_PINNED_ACTION_ID = "settings"

        /** `HomeDockMenu` 槽位上限（`timetable_settings_enums.dart:215-236`，不钉项）。 */
        const val HOME_DOCK_MENU_MAX_SLOTS = 5

        /**
         * 壁纸高斯模糊强度的收口带（`timetable_settings.dart:353-354`
         * `minHomePageWallpaperBlurSigma` / `maxHomePageWallpaperBlurSigma`）。
         *
         * 读侧（`:1715-1717`）与 `copyWith`（`:2385-2387`）都走
         * [clampHomePageWallpaperBlurSigma]，0 = 不模糊（走清晰原图）。
         */
        const val MIN_HOME_PAGE_WALLPAPER_BLUR_SIGMA = 0.0
        const val MAX_HOME_PAGE_WALLPAPER_BLUR_SIGMA = 24.0

        /** `defaultHomeBandGlassMaterial`（`timetable_settings.dart:329`，出厂单独指定液态）。 */
        const val DEFAULT_HOME_BAND_GLASS_MATERIAL = "liquid"

        /** 首页顶栏玻璃带的三档取值（`:330-334` `homeBandGlassMaterialValues`）。 */
        const val HOME_BAND_FOLLOW = "follow"
        const val HOME_BAND_LIQUID = "liquid"
        const val HOME_BAND_SOLID = "solid"

        /**
         * 液态玻璃档位的两个特殊存档值（`liquid_glass_tuning.dart:44-84`）：
         * `standard` 是缺键与坏值的归宿（`fromValue` 的 `orElse`），`custom` 不在 10 格阶梯上。
         */
        const val LIQUID_GLASS_PRESET_STANDARD = "standard"
        const val LIQUID_GLASS_PRESET_CUSTOM = "custom"

        /**
         * Dart `clampHomePageWallpaperBlurSigma`（`timetable_settings.dart:357-360`）：
         * null 按 0 处理，再夹进 0…24。**读侧与写侧同一口径**。
         */
        fun clampHomePageWallpaperBlurSigma(value: Double?): Double =
            (value ?: MIN_HOME_PAGE_WALLPAPER_BLUR_SIGMA)
                .coerceIn(MIN_HOME_PAGE_WALLPAPER_BLUR_SIGMA, MAX_HOME_PAGE_WALLPAPER_BLUR_SIGMA)

        /**
         * Dart `sanitizeHomeBandGlassMaterial`（`timetable_settings.dart:339-343`）：
         * 只有 `solid` / `follow` 原样保留，**其余一律液态**（含存量 progressive /
         * gaussian / soft 与一切非字符串坏值）。
         *
         * 与 Dart 一致只认字符串：数字之类按 `null` 处理（→ 液态），不做 `toString`。
         */
        fun sanitizeHomeBandGlassMaterial(raw: Any?): String = when (raw) {
            HOME_BAND_SOLID -> HOME_BAND_SOLID
            HOME_BAND_FOLLOW -> HOME_BAND_FOLLOW
            else -> HOME_BAND_LIQUID
        }

        // ---------- 桌面小组件（`timetable_settings.dart:786-795` / `:1444-1461`） ----------
        //
        // 这些常量是**唯一一份**：`SettingsActionDispatcher`（在 `app/`，不能 import
        // `pages.settings`）与 `pages/settings` 的桥/测试都引用这里，谁都不许再抄一份
        // -11 / 22 / [1,5,10,…] 之类的字面量。

        /** `WidgetBackgroundStyle` 的三档落盘串（`timetable_settings_extensions.dart:31-36`）。 */
        val WIDGET_BACKGROUND_STYLES: List<String> = listOf("glass", "solid", "gradient")

        /** `WidgetCourseAccentMode` 的三档落盘串（`widget_course_accent.dart:23-30`）。 */
        val WIDGET_COURSE_ACCENT_MODES: List<String> = listOf("off", "bar", "bar_and_text")

        /**
         * `LiveCountdownTextStyle` 的十二档落盘串（`timetable_settings_extensions.dart:153-167`）。
         *
         * 顺序与 Dart 枚举一致（下拉顺序依赖它），**不要重排**。
         */
        val WIDGET_COUNTDOWN_TEXT_STYLES: List<String> = listOf(
            "smart",
            "smart_min_s",
            "minute_second_cn",
            "minute_second_colon",
            "minute_second_min_s",
            "minute_second_min_slash_s",
            "minute_only_cn",
            "minute_only_min",
            "minute_only_slash",
            "second_only_cn",
            "second_only_short",
            "second_only_slash",
        )

        /** 三个字符串枚举的读侧回落值（Dart `X.fromValue(null)` 的 `orElse`）。 */
        const val DEFAULT_WIDGET_BACKGROUND_STYLE = "solid" // :786
        const val DEFAULT_WIDGET_COURSE_ACCENT_MODE = "bar_and_text" // :787
        const val DEFAULT_WIDGET_COUNTDOWN_TEXT_STYLE = "smart" // :795

        /** 卡片高度的默认档存储值（`:792` `-11`；滑杆读数是相对它的偏移）。 */
        const val DEFAULT_WIDGET_HEIGHT_ADJUSTMENT = -11.0

        /** 高度滑杆偏移范围（`settings_home_widget.dart:352-354`：-16~+16，32 档）。 */
        const val WIDGET_HEIGHT_OFFSET_MIN = -16.0
        const val WIDGET_HEIGHT_OFFSET_MAX = 16.0

        /** 卡片圆角默认值与可调范围（`:793` = 22；滑杆 `:368-370` = 默认 ±14）。 */
        const val DEFAULT_WIDGET_CORNER_RADIUS = 22.0
        const val WIDGET_CORNER_RADIUS_MIN = 8.0
        const val WIDGET_CORNER_RADIUS_MAX = 36.0

        /** 倒计时提前量默认档（`:794` = 20 分钟）。 */
        const val DEFAULT_WIDGET_COUNTDOWN_LEAD_MINUTES = 20

        /**
         * 倒计时提前量的九档分钟（`settings_home_widget.dart:310`
         * `const [1, 5, 10, 15, 20, 30, 40, 50, 60]`）；另允许 `0` = 始终显示（下拉首项）。
         */
        val WIDGET_COUNTDOWN_LEAD_MINUTES: List<Int> = listOf(1, 5, 10, 15, 20, 30, 40, 50, 60)

        /**
         * `X.fromValue` 语义：只收 [allowed] 里的串，其余（含 null）回落 [fallback]。
         *
         * Dart `WidgetBackgroundStyleX.fromValue` / `LiveCountdownTextStyleX.fromValue`
         * 都是 `values.firstWhere(value == v, orElse: 默认)`——不做大小写/去空白归一。
         */
        fun widgetEnumOrDefault(raw: String?, allowed: List<String>, fallback: String): String =
            if (raw != null && raw in allowed) raw else fallback

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
            "sectionHeight",
            "timetableAutoFitSectionHeight",
            "timetableShowNonCurrentWeekCourses",
            "weekGridShowExams",
            "weekGridShowSchedules",
            "weatherShowOnDayCard",
            "weatherShowOnWeekCard",
            "weatherShowOnSheet",
            "weatherShowPhenomenon",
            "weatherShowTemperature",
            "weatherShowProbability",
            "timetableTimeColumnWidthMode",
            "timetableCourseSpacingMode",
            "timetableCourseCardGap",
            "timetableSectionTimeDisplayMode",
            "timetableHideWeekends",
            "timetableLastViewedDayOfWeek",
            "coupleTimetableOverlayEnabled",
            "screenshotSharePromptEnabled",
            "longPressEmptySlotToAddCourseEnabled",
            "weekdayBarFontColorLight",
            "weekdayBarFontColorDark",
            "weekdayBarAccentColorLight",
            "weekdayBarAccentColorDark",
            "timeAxisFontColorLight",
            "timeAxisFontColorDark",
            "homeTitleStyle",
            "timetableHomeViewMode",
            "homeNavigationForm",
            "homeMenuStyle",
            "homeGridMenuActions",
            "glassDockActions",
            "glassDockShowDayTab",
            "glassDockShowSettingsTab",
            "glassDockShowWeekTab",
            "glassDockButtonEntryId",
            "glassDockButtonIconName",
            "glassDockShowAddButton",
            "timetableBackToCurrentWeekButtonStyle",
            "timetableFloatingBackToCurrentWeekButtonOpacity",
            // 桌面小组件（`timetable_settings.dart:1103-1112` / 读侧 `:1444-1461`）
            "widgetBackgroundStyle",
            "widgetCourseAccentMode",
            "widgetShowLocation",
            "widgetShowCountdown",
            "widgetHideCompletedCourses",
            "widgetShowTomorrowCourses",
            "widgetHeightAdjustment",
            "widgetCornerRadius",
            "widgetCountdownLeadMinutes",
            "widgetCountdownTextStyle",
            "liveEnableLocalDiagnostics",
            // 课表页面背景（`timetable_settings.dart:1220-1223`；
            // homePageBackgroundScope 已下线，不拥有）
            "timetablePageBackgroundColor",
            "homePageBackgroundFill",
            "homePageBackgroundImagePath",
            // 首页壁纸（`timetable_settings.dart:559-594` + `:746`）
            "homePageWallpaperPath",
            "homePageWallpaperAlignX",
            "homePageWallpaperAlignY",
            "homePageWallpaperScale",
            "homePageWallpaperBlurSigma",
            "wallpaperHistory",
            // 材质与液态玻璃（`timetable_settings.dart:655-746`）
            "frostedBlurEnabled",
            "liquidGlassDockEnabled",
            "liquidGlassPreset",
            "liquidGlassTuning",
            "liquidGlassTuningDark",
            "linkLiquidGlassTuning",
            "darkGlassBoostEnabled",
            "courseCardGlassTuning",
            "courseCardGlassPreset",
            "homePageHeaderBlurEnabled",
            "homeBandGlassMaterial",
            "homePageTimeColumnBlurEnabled",
            "homePageBackdropFollowsWeekPager",
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
            // 档位与参数分别在两个键里存，读取时必须收敛成一致（`timetable_settings.dart:1364-1380`）：
            // 渲染只吃参数键，档位键只用来画那根 10 格滑杆；两者对不上就会出现
            // 「滑杆停在第 7 格、旋钮却是自定义参数」的面板在说谎。
            val parsedLiquidGlassTuning =
                LiquidGlassTuningModel.fromJson(json["liquidGlassTuning"])
            val parsedCourseCardGlassTuning =
                LiquidGlassTuningModel.fromJson(json["courseCardGlassTuning"])
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
                sectionHeight = LenientJson.double(json["sectionHeight"]) ?: 68.0,
                timetableAutoFitSectionHeight =
                    LenientJson.bool(json["timetableAutoFitSectionHeight"]) ?: false,
                timetableShowNonCurrentWeekCourses =
                    LenientJson.bool(json["timetableShowNonCurrentWeekCourses"]) ?: false,
                weekGridShowExams = LenientJson.bool(json["weekGridShowExams"]) ?: true,
                weekGridShowSchedules = LenientJson.bool(json["weekGridShowSchedules"]) ?: true,
                weatherShowOnDayCard = LenientJson.bool(json["weatherShowOnDayCard"]) ?: true,
                weatherShowOnWeekCard = LenientJson.bool(json["weatherShowOnWeekCard"]) ?: true,
                weatherShowOnSheet = LenientJson.bool(json["weatherShowOnSheet"]) ?: true,
                weatherShowPhenomenon = LenientJson.bool(json["weatherShowPhenomenon"]) ?: true,
                weatherShowTemperature =
                    LenientJson.bool(json["weatherShowTemperature"]) ?: true,
                weatherShowProbability =
                    LenientJson.bool(json["weatherShowProbability"]) ?: false,
                timetableTimeColumnWidthMode = TimetableTimeColumnWidthMode.fromValue(
                    LenientJson.string(json["timetableTimeColumnWidthMode"]),
                ),
                timetableCourseSpacingMode = TimetableCourseSpacingMode.fromValue(
                    LenientJson.string(json["timetableCourseSpacingMode"]),
                ),
                // 缺键时按 spacingMode 的**原始字符串**推导，不是固定常量（Dart :1436-1440）。
                timetableCourseCardGap = LenientJson.double(json["timetableCourseCardGap"])
                    ?: if (LenientJson.string(json["timetableCourseSpacingMode"]) == "wide") {
                        DEFAULT_COURSE_CARD_GAP_WIDE
                    } else {
                        DEFAULT_COURSE_CARD_GAP
                    },
                timetableSectionTimeDisplayMode = SectionTimeDisplayMode.fromValue(
                    LenientJson.string(json["timetableSectionTimeDisplayMode"]),
                ),
                timetableHideWeekends = LenientJson.bool(json["timetableHideWeekends"]) ?: false,
                timetableLastViewedDayOfWeek =
                    (LenientJson.int(json["timetableLastViewedDayOfWeek"]) ?: 1L).toInt()
                        .coerceIn(1, 7),
                coupleTimetableOverlayEnabled =
                    LenientJson.bool(json["coupleTimetableOverlayEnabled"]) ?: false,
                screenshotSharePromptEnabled =
                    LenientJson.bool(json["screenshotSharePromptEnabled"]) ?: true,
                longPressEmptySlotToAddCourseEnabled =
                    LenientJson.bool(json["longPressEmptySlotToAddCourseEnabled"]) ?: false,
                weekdayBarFontColorLight = LenientJson.string(json["weekdayBarFontColorLight"])
                    ?: DEFAULT_WEEKDAY_BAR_FONT_LIGHT,
                weekdayBarFontColorDark = LenientJson.string(json["weekdayBarFontColorDark"])
                    ?: DEFAULT_WEEKDAY_BAR_FONT_DARK,
                weekdayBarAccentColorLight =
                    LenientJson.string(json["weekdayBarAccentColorLight"])
                        ?: DEFAULT_WEEKDAY_BAR_ACCENT_LIGHT,
                weekdayBarAccentColorDark = LenientJson.string(json["weekdayBarAccentColorDark"])
                    ?: DEFAULT_WEEKDAY_BAR_ACCENT_DARK,
                timeAxisFontColorLight = LenientJson.string(json["timeAxisFontColorLight"])
                    ?: DEFAULT_TIME_AXIS_FONT_LIGHT,
                timeAxisFontColorDark = LenientJson.string(json["timeAxisFontColorDark"])
                    ?: DEFAULT_TIME_AXIS_FONT_DARK,
                homeTitleStyle = HomeTitleStyle.fromValue(
                    LenientJson.string(json["homeTitleStyle"]),
                ),
                timetableHomeViewMode = TimetableHomeViewMode.fromValue(
                    LenientJson.string(json["timetableHomeViewMode"]),
                ),
                homeNavigationForm = HomeNavigationForm.fromValue(
                    LenientJson.string(json["homeNavigationForm"]),
                ),
                homeMenuStyle = HomeMenuStyle.fromValue(
                    LenientJson.string(json["homeMenuStyle"]),
                ),
                homeGridMenuActions = normalizeHomeGridMenuActions(json["homeGridMenuActions"]),
                // 缺键/类型不对 → 由日、周 Tab 开关推导（两者缺省 true）；显式空数组保持空表。
                glassDockActions = if (json["glassDockActions"] is List<*>) {
                    normalizeGlassDockActions(json["glassDockActions"] as List<*>)
                } else {
                    normalizeGlassDockActions(
                        buildList {
                            if (LenientJson.bool(json["glassDockShowDayTab"]) ?: true) add("day")
                            if (LenientJson.bool(json["glassDockShowWeekTab"]) ?: true) add("week")
                        },
                    )
                },
                glassDockShowDayTab = LenientJson.bool(json["glassDockShowDayTab"]) ?: true,
                glassDockShowSettingsTab =
                    LenientJson.bool(json["glassDockShowSettingsTab"]) ?: true,
                glassDockShowWeekTab = LenientJson.bool(json["glassDockShowWeekTab"]) ?: true,
                glassDockButtonEntryId = LenientJson.string(json["glassDockButtonEntryId"])
                    ?: DEFAULT_GLASS_DOCK_BUTTON_ENTRY_ID,
                glassDockButtonIconName = LenientJson.string(json["glassDockButtonIconName"]),
                glassDockShowAddButton = LenientJson.bool(json["glassDockShowAddButton"]) ?: false,
                timetableBackToCurrentWeekButtonStyle = BackToCurrentWeekButtonStyle.fromValue(
                    LenientJson.string(json["timetableBackToCurrentWeekButtonStyle"]),
                ),
                timetableFloatingBackToCurrentWeekButtonOpacity =
                    (LenientJson.double(json["timetableFloatingBackToCurrentWeekButtonOpacity"])
                        ?: 0.96)
                        .coerceIn(0.55, 1.0),
                // ---------- 桌面小组件（`timetable_settings.dart:1444-1461`） ----------
                // 三个字符串枚举走 `X.fromValue` 语义：缺键/未知串回落默认（不是报错、不是保留旧值）。
                widgetBackgroundStyle = widgetEnumOrDefault(
                    LenientJson.string(json["widgetBackgroundStyle"]),
                    WIDGET_BACKGROUND_STYLES,
                    DEFAULT_WIDGET_BACKGROUND_STYLE,
                ),
                widgetCourseAccentMode = widgetEnumOrDefault(
                    LenientJson.string(json["widgetCourseAccentMode"]),
                    WIDGET_COURSE_ACCENT_MODES,
                    DEFAULT_WIDGET_COURSE_ACCENT_MODE,
                ),
                widgetShowLocation = LenientJson.bool(json["widgetShowLocation"]) ?: true,
                widgetShowCountdown = LenientJson.bool(json["widgetShowCountdown"]) ?: true,
                widgetHideCompletedCourses =
                    LenientJson.bool(json["widgetHideCompletedCourses"]) ?: false,
                widgetShowTomorrowCourses =
                    LenientJson.bool(json["widgetShowTomorrowCourses"]) ?: true,
                // 两个 double 读侧**不夹**（Dart 就是 `?? -11` / `?? 22`）：夹在滑杆与分派器侧。
                widgetHeightAdjustment = LenientJson.double(json["widgetHeightAdjustment"])
                    ?: DEFAULT_WIDGET_HEIGHT_ADJUSTMENT,
                widgetCornerRadius = LenientJson.double(json["widgetCornerRadius"])
                    ?: DEFAULT_WIDGET_CORNER_RADIUS,
                // int 同样不夹（`?? 20`）；0 是合法档位（始终显示），所以不能用「非空即收」以外的判断。
                widgetCountdownLeadMinutes =
                    (LenientJson.int(json["widgetCountdownLeadMinutes"])
                        ?: DEFAULT_WIDGET_COUNTDOWN_LEAD_MINUTES.toLong()).toInt(),
                widgetCountdownTextStyle = widgetEnumOrDefault(
                    LenientJson.string(json["widgetCountdownTextStyle"]),
                    WIDGET_COUNTDOWN_TEXT_STYLES,
                    DEFAULT_WIDGET_COUNTDOWN_TEXT_STYLE,
                ),
                liveEnableLocalDiagnostics =
                    LenientJson.bool(json["liveEnableLocalDiagnostics"]) ?: false,
                // ---------- 课表页面背景（`timetable_settings.dart:1698-1704`） ----------
                timetablePageBackgroundColor =
                    LenientJson.string(json["timetablePageBackgroundColor"])
                        ?: DEFAULT_TIMETABLE_PAGE_BACKGROUND_COLOR,
                homePageBackgroundFill = HomePageBackgroundFill.fromValue(
                    LenientJson.string(json["homePageBackgroundFill"]),
                ),
                // 新旧两条路径都只是不透明字符串；哪个生效由「壁纸优先」的解析决定
                // （`home_page_background.dart:346-356`）。
                homePageBackgroundImagePath =
                    LenientJson.string(json["homePageBackgroundImagePath"]),
                // ⚠️ 读侧恒为默认值（`:1725`）：这个键 Dart 已下线，存档里的旧值不读。
                homePageBackgroundScope = DEFAULT_HOME_PAGE_BACKGROUND_SCOPE,
                // ---------- 首页壁纸（`timetable_settings.dart:1706-1720` + `:1852-1853`） ----------
                // 路径只认字符串/null（Dart `lenientString` 会把非字符串 toString，这里同口径）。
                homePageWallpaperPath = LenientJson.string(json["homePageWallpaperPath"]),
                // 两根对齐读侧**不夹**（`:1707-1710` 就是 `?? 0`），夹在渲染/编辑侧。
                homePageWallpaperAlignX = LenientJson.double(json["homePageWallpaperAlignX"]) ?: 0.0,
                homePageWallpaperAlignY = LenientJson.double(json["homePageWallpaperAlignY"]) ?: 0.0,
                // 存量存档没有这个字段：缺省 1（刚好铺满），观感与加缩放之前一致（`:1711-1713`）。
                homePageWallpaperScale = LenientJson.double(json["homePageWallpaperScale"]) ?: 1.0,
                // 存量存档没有这个字段：缺省 0（不模糊）+ 收口带（`:1714-1717`）。
                homePageWallpaperBlurSigma = clampHomePageWallpaperBlurSigma(
                    LenientJson.double(json["homePageWallpaperBlurSigma"]),
                ),
                // 脏条目在 listFromJson 内逐条校验丢弃，绝不让单个坏值炸掉整个设置（`:1718-1720`）。
                wallpaperHistory = WallpaperHistoryRowModel.listFromJson(json["wallpaperHistory"]),
                // 缺键按**默认关**：缺键只可能来自引入该字段之前的老存档，等价于"从没主动选过"
                // （`:1849-1853`）。
                homePageBackdropFollowsWeekPager =
                    LenientJson.bool(json["homePageBackdropFollowsWeekPager"]) ?: false,
                // ---------- 材质与液态玻璃（`timetable_settings.dart:1773-1846`） ----------
                frostedBlurEnabled =
                    LenientJson.bool(json["frostedBlurEnabled"]) ?: true, // :292 defaultFrostedBlurEnabled
                liquidGlassDockEnabled =
                    LenientJson.bool(json["liquidGlassDockEnabled"]) ?: true, // :300
                // 两个玻璃带显示开关已下线，Dart 恒写 true（`:1827-1831`）：存档值不读。
                homePageHeaderBlurEnabled = true,
                homeBandGlassMaterial = sanitizeHomeBandGlassMaterial(json["homeBandGlassMaterial"]),
                liquidGlassPreset = LiquidGlassTuningModel.reconcileStoredPreset(
                    rawStored = json["liquidGlassPreset"],
                    tuning = parsedLiquidGlassTuning,
                ),
                liquidGlassTuning = parsedLiquidGlassTuning,
                liquidGlassTuningDark = LiquidGlassTuningModel.fromJson(json["liquidGlassTuningDark"]),
                linkLiquidGlassTuning =
                    LenientJson.bool(json["linkLiquidGlassTuning"]) ?: true, // :307
                darkGlassBoostEnabled =
                    LenientJson.bool(json["darkGlassBoostEnabled"]) ?: true, // :313
                courseCardGlassPreset = LiquidGlassTuningModel.reconcileStoredPreset(
                    rawStored = json["courseCardGlassPreset"],
                    // 卡片那 10 格与全局同值（`course_glass_tuning.dart:73-124`：直接引用全局常量），
                    // 所以同一个收敛函数可直接用在卡片参数上（Dart `:1822-1825` 同口径）。
                    tuning = parsedCourseCardGlassTuning,
                ),
                courseCardGlassTuning = parsedCourseCardGlassTuning,
                // `:1847-1848`：缺键 false。
                homePageTimeColumnBlurEnabled =
                    LenientJson.bool(json["homePageTimeColumnBlurEnabled"]) ?: false,
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

        /**
         * `HomeGridMenu.normalize`（`timetable_settings_enums.dart:187-207`）：
         * 非 List → 空表；去重、剔空串与非字符串 → 截断到 8 → **保证钉住项 `settings` 在场**
         * （若已满 8 先丢最后一个给它腾位）。钉住的原因是它是回到八宫格编辑器的唯一入口。
         */
        fun normalizeHomeGridMenuActions(raw: Any?): List<String> {
            if (raw !is List<*>) return emptyList()
            val unique = ArrayList<String>(raw.size)
            for (item in raw) {
                if (item is String && item.isNotEmpty() && !unique.contains(item)) unique.add(item)
            }
            if (unique.size > HOME_GRID_MENU_MAX_SLOTS) {
                while (unique.size > HOME_GRID_MENU_MAX_SLOTS) unique.removeAt(unique.size - 1)
            }
            if (!unique.contains(HOME_GRID_MENU_PINNED_ACTION_ID)) {
                if (unique.size >= HOME_GRID_MENU_MAX_SLOTS) unique.removeAt(unique.size - 1)
                unique.add(HOME_GRID_MENU_PINNED_ACTION_ID)
            }
            return unique
        }

        /**
         * `HomeDockMenu.normalize`（`timetable_settings_enums.dart:221-235`）：
         * 去重、剔空串与非字符串 → 截断到 5。**不钉项**（空排列合法，渲染层回落默认值）。
         */
        fun normalizeGlassDockActions(raw: List<*>): List<String> {
            val unique = ArrayList<String>(raw.size)
            for (item in raw) {
                if (item is String && item.isNotEmpty() && !unique.contains(item)) unique.add(item)
            }
            while (unique.size > HOME_DOCK_MENU_MAX_SLOTS) unique.removeAt(unique.size - 1)
            return unique
        }

        private fun asMap(raw: Any?): Map<String, Any?>? {            if (raw !is Map<*, *>) return null
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
 * 与 `TimetableStore.loadSettings/saveSettings`（core 4 键 + `classReminders`）共用同一个键与同一套合并语义
 * （都走 `TimetableStore.saveSettingsPatch`），所以两边互不覆盖。
 */
class TimetableSettingsModelStore(private val store: TimetableStore) {

    /** 读；盘上不是 JSON 对象时由 [TimetableStore.loadSettingsJson] 留档 + 删 key，返回默认值。 */
    fun load(): TimetableSettingsModel = TimetableSettingsModel.fromJson(store.loadSettingsJson())

    /**
     * 合并写：只覆盖本模型拥有的键，其余键原样保留。
     *
     * ## 为什么还要写第二处（active profile 内嵌 settings）
     *
     * 桌面小组件的卡片渲染读的是 **active profile 内嵌的 `settings` 对象**
     * （`TodayWidgetSupport.buildSnapshotFromFlutterState` 的
     * `profile.optJSONObject("settings")`），不是顶层 `timetable_settings`。
     * Dart 的 `TimetableProvider.updateTimetableSettings` 也把整份 settings 写回档案
     * （`lib/providers/timetable_provider.dart:3036-3070` → `_persistActiveProfileState`），
     * 两条通路读同一份值。
     * 只写顶层 = 设置页看着改了、桌面卡片纹丝不动，所以这里两处一起写。
     */
    fun save(model: TimetableSettingsModel) {
        val patch = model.toJsonPatch()
        store.saveSettingsPatch(patch)
        store.saveSettingsPatchToActiveProfile(patch)
    }

    /**
     * 只落**视图档**一个键（日 / 周 / 月）。
     *
     * ## 为什么不复用 [save]
     *
     * [save] 会把 [TimetableSettingsModel.toJsonPatch] 里那 80+ 个键整份写一遍。壳在
     * 底栏点一下「日/周」就调它 ⇒ 每次切视图都拿**点击那一刻的内存快照**去覆盖整份
     * 设置。落盘已经被挪到后台线程（`PagesShellActivity.selectRoot`），只要后台写比
     * 用户的下一次设置改动慢半拍，就会把刚改的那一项按旧值写回去。视图档只需要它
     * 自己那一个键，那就只写那一个。
     *
     * ## 两个落点都写
     *
     * 与 [save] 和 Dart `persistHomeViewState`（`timetable_provider.dart:3012-3027`）
     * 同口径：顶层 `timetable_settings` 是壳自己读的那份；active profile 内嵌的
     * `settings` 保持跟 Dart 写路径一致（桌面小组件不读这个键，但它读同一个
     * settings 对象，写侧口径分叉迟早会在别处咬人）。
     */
    fun saveHomeViewMode(mode: TimetableHomeViewMode) {
        val patch = mapOf("timetableHomeViewMode" to mode.value)
        store.saveSettingsPatch(patch)
        store.saveSettingsPatchToActiveProfile(patch)
    }

    /**
     * 只落**日视图看的是哪一天**一个键（1..7）。
     *
     * ## 谁写、谁读
     *
     * * 写：首页日视图每次翻页**停稳**后（`ShellPageIndex` 的 `c3.day` 分支
     *   `onPageChanged`），与 Dart `persistHomeViewState(mode:, dayOfWeek:)`
     *   （`timetable_provider.dart:3012-3027`）里 dayOfWeek 那半边同口径；
     * * 读：进日视图时的初始日（从底栏进也回到上次看的那天，Dart
     *   `_restoreViewStateFromProvider` 同口径），以及外观编辑页的日预览
     *   （`AppearanceEditorHost.DayViewPreview`，Dart `:208-210` / `:379`）。
     *
     * ## 为什么单独一个键、单独一个方法
     *
     * 理由与 [saveHomeViewMode] 相同：整份 [save] 会把 80+ 个键按「翻页那一刻的快照」
     * 重写一遍，后台写慢半拍就会覆盖用户刚改的设置。这里只写这一个键。
     * 调用方必须**离开主线程**调用：`saveSettingsPatchToActiveProfile` 会把整份
     * 课表档案 JSON 读出来重编码再提交。
     */
    fun saveLastViewedDayOfWeek(dayOfWeek: Int) {
        val patch = mapOf("timetableLastViewedDayOfWeek" to dayOfWeek.coerceIn(1, 7))
        store.saveSettingsPatch(patch)
        store.saveSettingsPatchToActiveProfile(patch)
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

/** `TimetableTimeColumnWidthMode`（`timetable_settings_enums.dart`，未知值回落 narrow）。 */
enum class TimetableTimeColumnWidthMode(val value: String) {
    NARROW("narrow"),
    WIDE("wide");

    companion object {
        fun fromValue(raw: String?): TimetableTimeColumnWidthMode =
            entries.firstOrNull { it.value == raw } ?: NARROW
    }
}

/** `TimetableCourseSpacingMode`（未知值回落 narrow）。 */
enum class TimetableCourseSpacingMode(val value: String) {
    NARROW("narrow"),
    WIDE("wide");

    companion object {
        fun fromValue(raw: String?): TimetableCourseSpacingMode =
            entries.firstOrNull { it.value == raw } ?: NARROW
    }
}

/**
 * `SectionTimeDisplayMode`（`timetable_settings_extensions.dart`）。
 *
 * ⚠️ 磁盘值与枚举名不同名：`startOnly` → `start_only`、`startAndEnd` → `start_and_end`；
 * 未知值回落 **`startAndEnd`**（不是第一个枚举项）。
 */
enum class SectionTimeDisplayMode(val value: String) {
    HIDDEN("hidden"),
    START_ONLY("start_only"),
    START_AND_END("start_and_end");

    companion object {
        fun fromValue(raw: String?): SectionTimeDisplayMode =
            entries.firstOrNull { it.value == raw } ?: START_AND_END
    }
}

/** `HomeTitleStyle`（`timetable_settings_enums.dart:95`，未知值回落 classic）。 */
enum class HomeTitleStyle(val value: String) {
    CLASSIC("classic"),
    BRAND("brand");

    companion object {
        fun fromValue(raw: String?): HomeTitleStyle =
            entries.firstOrNull { it.value == raw } ?: CLASSIC
    }
}

/** `TimetableHomeViewMode`（:130，`value` 取枚举名；未知值一律回落 week）。 */
enum class TimetableHomeViewMode(val value: String) {
    WEEK("week"),
    DAY("day"),
    MONTH("month");

    companion object {
        fun fromValue(raw: String?): TimetableHomeViewMode =
            entries.firstOrNull { it.value == raw } ?: WEEK
    }
}

/**
 * `HomeNavigationForm`（:134）。
 *
 * ⚠️ 玻璃坞档的**磁盘值是 `glass_dock`**（下划线），与枚举名不同。
 */
enum class HomeNavigationForm(val value: String) {
    CLASSIC("classic"),
    GLASS_DOCK("glass_dock");

    companion object {
        fun fromValue(raw: String?): HomeNavigationForm =
            entries.firstOrNull { it.value == raw } ?: CLASSIC
    }
}

/** `HomeMenuStyle`（:139，未知值回落 list）。 */
enum class HomeMenuStyle(val value: String) {
    LIST("list"),
    GRID("grid");

    companion object {
        fun fromValue(raw: String?): HomeMenuStyle =
            entries.firstOrNull { it.value == raw } ?: LIST
    }
}

/**
 * `BackToCurrentWeekButtonStyle`（:238）。
 *
 * ⚠️ **读侧不返回 [INLINE]**：存量 `'inline'`（时间栏内嵌小字，入口已下线）与一切未知值
 * 都被迁移成 [FLOATING]（`BackToCurrentWeekButtonStyleX.fromValue` 的注释：内嵌入口已收敛为浮钮）。
 * 枚举保留 [INLINE] 只为让写侧能表达旧值。
 */
enum class BackToCurrentWeekButtonStyle(val value: String) {
    INLINE("inline"),
    FLOATING("floating");

    companion object {
        /** 读侧永远 FLOATING：`'inline'` 与未知值都被迁移（见枚举 KDoc）。 */
        fun fromValue(raw: String?): BackToCurrentWeekButtonStyle = FLOATING
    }
}

/**
 * 首页背景填充形态（`timetable_settings_enums.dart:97-108`）。
 *
 * `value` 就是枚举名（Dart `HomePageBackgroundFillX.value` = `name`）：`color` / `image`。
 * 未知值回落 [COLOR]（Dart `fromValue` 的 `orElse`）。
 */
enum class HomePageBackgroundFill(val value: String) {
    COLOR("color"),
    IMAGE("image");

    companion object {
        fun fromValue(raw: String?): HomePageBackgroundFill =
            entries.firstOrNull { it.value == raw } ?: COLOR
    }
}

/**
 * 液态玻璃的**八个观感参数**（`lib/models/liquid_glass_tuning.dart:201-451`）。
 *
 * ## 为什么在 `app/` 里另有一个同名概念的类
 *
 * `pages/settings/SettingsMaterialModel.kt` 里那份 `LiquidGlassTuning` 是**面板显示**用的
 * （它自带 10 格档位表与最近格推算）；它住在 `pages/settings/`，而 `app/` 是**每一次 L0
 * 都会收的共享模型层**，不能反向依赖某个页面域（见 `SettingsActionDispatcher.kt` 的类注释
 * 「为什么参数是镜像枚举」）。所以设置模型需要一份自己的纯数据类，页面侧那份继续只管渲染。
 * 两边数值必须一致——`AppearanceEditorBridgeTest` 有一条逐字段对拍两处档位表的测试。
 *
 * ## 口径
 *
 * - 八个默认值 = 第 7 格「标准」= 全 app 的玻璃基准（`:408-454`）；
 * - 上下限 = 滑杆区间（`:456-474`）；
 * - 读侧 `fromJson` 缺键取默认值、随后**整体收口**（`:605-624` 的 `.clamped()`）。
 *
 * ⚠️ 课程卡片那套（Dart `CourseGlassTuning`，`lib/models/course_glass_tuning.dart`）是
 * **同一个八字段形状、同一批出厂值与上下限**（`:45-71` / `:197-234` 直接引用全局常量），
 * 所以本类一并承载它；两者的区别只在**染色语义**（全局染玻璃底色白、卡片染课程色）
 * 与存档键，不是数值口径。
 */
data class LiquidGlassTuningModel(
    /** 边缘处的最大折射位移（逻辑 px，`:476-477`）。 */
    val refraction: Double = DEFAULT_REFRACTION,
    /** 折射作用带宽度（逻辑 px，`:479-480`）。 */
    val refractionBand: Double = DEFAULT_REFRACTION_BAND,
    /** 位移沿边缘上升的陡缓（`:482-483`）。 */
    val refractionEdgePow: Double = DEFAULT_REFRACTION_EDGE_POW,
    /** 色散强度 0–1（`:485-486`）。 */
    val dispersion: Double = DEFAULT_DISPERSION,
    /** 边缘高光强度 0–1（`:488-489`）。 */
    val rimStrength: Double = DEFAULT_RIM_STRENGTH,
    /** 边缘高光带宽（逻辑 px，`:491-492`）。 */
    val rimWidth: Double = DEFAULT_RIM_WIDTH,
    /** 实时背景的模糊量（逻辑 px，`:494-495`）。 */
    val blurSigma: Double = DEFAULT_BLUR_SIGMA,
    /** 底色（白）不透明度 0–1（`:497-498`）。 */
    val tintAlpha: Double = DEFAULT_TINT_ALPHA,
) {

    /** 逐项收口（Dart `clamped()`，`:522-539`）。 */
    fun clamped(): LiquidGlassTuningModel = copy(
        refraction = refraction.coerceIn(MIN_REFRACTION, MAX_REFRACTION),
        refractionBand = refractionBand.coerceIn(MIN_REFRACTION_BAND, MAX_REFRACTION_BAND),
        refractionEdgePow = refractionEdgePow.coerceIn(
            MIN_REFRACTION_EDGE_POW,
            MAX_REFRACTION_EDGE_POW,
        ),
        dispersion = dispersion.coerceIn(MIN_DISPERSION, MAX_DISPERSION),
        rimStrength = rimStrength.coerceIn(MIN_RIM_STRENGTH, MAX_RIM_STRENGTH),
        rimWidth = rimWidth.coerceIn(MIN_RIM_WIDTH, MAX_RIM_WIDTH),
        blurSigma = blurSigma.coerceIn(MIN_BLUR_SIGMA, MAX_BLUR_SIGMA),
        tintAlpha = tintAlpha.coerceIn(MIN_TINT_ALPHA, MAX_TINT_ALPHA),
    )

    /** 落盘：八个短键，顺序与 Dart `toJson` 一致（`:594-603`）。 */
    fun toJson(): Map<String, Any?> = linkedMapOf(
        "refraction" to refraction,
        "refractionBand" to refractionBand,
        "refractionEdgePow" to refractionEdgePow,
        "dispersion" to dispersion,
        "rimStrength" to rimStrength,
        "rimWidth" to rimWidth,
        "blurSigma" to blurSigma,
        "tintAlpha" to tintAlpha,
    )

    companion object {

        // ---- 出厂值（即第 7 格「标准」，`liquid_glass_tuning.dart:408-454`）----
        // 2026-11-03 折射收档：默认 8→6、作用带默认 11→8。顶栏玻璃带把交界处画面
        // 弯得太多（用户口径「壁纸错位」），收小位移与作用范围后，带内除紧贴交界
        // 的一小条外与下方内容视觉连续。渲染层另有 8dp 硬夹具
        // （`timetableBandRefraction`），滑杆拖多大都不会超过。
        const val DEFAULT_REFRACTION = 6.0 // :410
        const val DEFAULT_REFRACTION_BAND = 8.0 // :418
        const val DEFAULT_REFRACTION_EDGE_POW = 2.5 // :419
        const val DEFAULT_RIM_STRENGTH = 0.2 // :432
        const val DEFAULT_RIM_WIDTH = 1.5 // :433
        const val DEFAULT_BLUR_SIGMA = 15.0 // :450
        const val DEFAULT_TINT_ALPHA = 0.70 // :451
        const val DEFAULT_DISPERSION = 0.35 // :454

        // ---- 滑杆区间（同文件 `:456-474`）----
        // 2026-11-03 折射上限收档：位移 20→10、作用带 24→12（理由同上）。
        const val MIN_REFRACTION = 0.0 // :457
        const val MAX_REFRACTION = 10.0 // :458
        const val MIN_REFRACTION_BAND = 1.0 // :459
        const val MAX_REFRACTION_BAND = 12.0 // :460
        const val MIN_REFRACTION_EDGE_POW = 1.0 // :461
        const val MAX_REFRACTION_EDGE_POW = 6.0 // :462
        const val MIN_DISPERSION = 0.0 // :463
        const val MAX_DISPERSION = 1.0 // :464
        const val MIN_RIM_STRENGTH = 0.0 // :465
        const val MAX_RIM_STRENGTH = 1.0 // :466
        const val MIN_RIM_WIDTH = 0.0 // :467
        const val MAX_RIM_WIDTH = 3.0 // :470
        const val MIN_BLUR_SIGMA = 0.0 // :471
        const val MAX_BLUR_SIGMA = 40.0 // :472
        const val MIN_TINT_ALPHA = 0.0 // :473
        const val MAX_TINT_ALPHA = 1.0 // :474

        /** 出厂档（`static const defaults = LiquidGlassTuning()`，`:213`）。 */
        val DEFAULTS = LiquidGlassTuningModel()

        /**
         * 10 格阶梯的存档值，**顺序就是厚度从薄到厚**（`liquid_glass_tuning.dart:135-146`
         * `LiquidGlassPresetX.builtIns`）。
         *
         * 注意第 6 / 7 / 10 格沿用旧的 `light` / `standard` / `dense`（`:44-84` 的枚举注释），
         * `custom` 不在阶梯上，所以不在这张表里。
         */
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

        /** 每格的推荐参数（`presetClear` … `presetDense`，`:254-368`）。 */
        val PRESET_TUNINGS: List<LiquidGlassTuningModel> = listOf(
            // 第 1 格：染色与模糊都归零，背景一块都不挡（`:254-266`）
            LiquidGlassTuningModel(
                refraction = 6.0,
                refractionBand = 8.0,
                refractionEdgePow = 3.25,
                dispersion = 0.15,
                rimStrength = 0.1,
                rimWidth = 1.2,
                blurSigma = 0.0,
                tintAlpha = 0.0,
            ),
            // 第 2 格（`:269-278`）
            LiquidGlassTuningModel(
                refraction = 6.0,
                refractionBand = 8.5,
                refractionEdgePow = 3.25,
                dispersion = 0.2,
                rimStrength = 0.1,
                rimWidth = 1.2,
                blurSigma = 1.0,
                tintAlpha = 0.1,
            ),
            // 第 3 格（`:281-290`）
            LiquidGlassTuningModel(
                refraction = 6.5,
                refractionBand = 9.0,
                refractionEdgePow = 3.0,
                dispersion = 0.2,
                rimStrength = 0.15,
                rimWidth = 1.3,
                blurSigma = 3.0,
                tintAlpha = 0.2,
            ),
            // 第 4 格（`:293-302`）
            LiquidGlassTuningModel(
                refraction = 7.0,
                refractionBand = 9.5,
                refractionEdgePow = 3.0,
                dispersion = 0.25,
                rimStrength = 0.15,
                rimWidth = 1.3,
                blurSigma = 5.0,
                tintAlpha = 0.3,
            ),
            // 第 5 格（`:305-317`）
            LiquidGlassTuningModel(
                refraction = 7.0,
                refractionBand = 10.0,
                refractionEdgePow = 2.75,
                dispersion = 0.25,
                rimStrength = 0.2,
                rimWidth = 1.4,
                blurSigma = 8.0,
                tintAlpha = 0.4,
            ),
            // 第 6 格（存档值沿用旧的 light，`:320-330`）
            LiquidGlassTuningModel(
                refraction = 7.5,
                refractionBand = 10.5,
                refractionEdgePow = 2.75,
                dispersion = 0.3,
                rimStrength = 0.2,
                rimWidth = 1.4,
                blurSigma = 12.0,
                tintAlpha = 0.55,
            ),
            // 第 7 格 = 标准档 = 出厂值（`:249-250` presetStandard = defaults）
            DEFAULTS,
            // 第 8 格（`:333-342`）
            // 2026-11-03 与上下限同步收档：作用带 13 超出新上限 12，这里收到 12。
            // 预设必须落在滑杆区间内，否则「选档 → 存 → 读」经过 `.clamped()` 后与原档位
            // 值对不上，只能被判成自定义（第 8/9/10 格当时整条回读链路都是 `custom`）。
            LiquidGlassTuningModel(
                refraction = 9.0,
                refractionBand = 12.0,
                refractionEdgePow = 2.25,
                dispersion = 0.4,
                rimStrength = 0.25,
                rimWidth = 1.7,
                blurSigma = 18.0,
                tintAlpha = 0.75,
            ),
            // 第 9 格（`:345-354`）：作用带 14 同上收到 12
            LiquidGlassTuningModel(
                refraction = 10.0,
                refractionBand = 12.0,
                refractionEdgePow = 2.25,
                dispersion = 0.45,
                rimStrength = 0.3,
                rimWidth = 1.9,
                blurSigma = 21.0,
                tintAlpha = 0.8,
            ),
            // 第 10 格（最厚，存档值沿用旧的 dense，`:357-368`；染色刻意不到 1）
            // 折射 11 / 作用带 15 同上收到新上限 10 / 12
            LiquidGlassTuningModel(
                refraction = 10.0,
                refractionBand = 12.0,
                refractionEdgePow = 2.0,
                dispersion = 0.5,
                rimStrength = 0.3,
                rimWidth = 2.1,
                blurSigma = 24.0,
                tintAlpha = 0.9,
            ),
        )

        /** 阶梯格数（`LiquidGlassPresetX.builtIns.length`，`:135-146`）。 */
        val PRESET_STEPS: Int get() = PRESET_VALUES.size

        /**
         * 读侧解析（`liquid_glass_tuning.dart:605-624`）：非 Map ⇒ null（Dart `parseNestedObject`
         * 面对非 Map 返回 null，`timetable_settings.dart:1344-1355`）。
         *
         * 每个字段「有值就收，收不下按缺键处理」，再整体收口（`.clamped()`）。
         *
         * 与 Dart 的**唯一差异**：Dart 的 `fromJson` 对任一字段做 `as num?` 强转，遇到字符串
         * 之类会抛 TypeError，被 `parseNestedObject` 的 `catch` 吞掉后**整个参数对象变 null**；
         * 这里逐字段宽松读（那一个字段失效、其余保留）。两者对合法存档逐字节等价，
         * 对脏数据则这里更宽容——与「绝不让一个坏值把整份设置打回默认」这条仓规一致。
         */
        fun fromJson(raw: Any?): LiquidGlassTuningModel? {
            val map = raw as? Map<*, *> ?: return null
            fun d(key: String, fallback: Double): Double =
                LenientJson.double(map[key]) ?: fallback
            return LiquidGlassTuningModel(
                refraction = d("refraction", DEFAULT_REFRACTION),
                refractionBand = d("refractionBand", DEFAULT_REFRACTION_BAND),
                refractionEdgePow = d("refractionEdgePow", DEFAULT_REFRACTION_EDGE_POW),
                dispersion = d("dispersion", DEFAULT_DISPERSION),
                rimStrength = d("rimStrength", DEFAULT_RIM_STRENGTH),
                rimWidth = d("rimWidth", DEFAULT_RIM_WIDTH),
                blurSigma = d("blurSigma", DEFAULT_BLUR_SIGMA),
                tintAlpha = d("tintAlpha", DEFAULT_TINT_ALPHA),
            ).clamped()
        }

        /**
         * 档位值 → 存档值（`LiquidGlassPresetX.fromValue`，`liquid_glass_tuning.dart:86-112`）：
         * 认识的原样返回，**不认识（含缺键）一律 `standard`**——绝不能是 `custom`，
         * 否则"从没调过"的老用户会被显示成自定义、参数区莫名展开。
         */
        fun presetValueOrStandard(raw: String?): String {
            if (raw == TimetableSettingsModel.LIQUID_GLASS_PRESET_CUSTOM) {
                return TimetableSettingsModel.LIQUID_GLASS_PRESET_CUSTOM
            }
            return if (PRESET_VALUES.contains(raw)) {
                raw!!
            } else {
                TimetableSettingsModel.LIQUID_GLASS_PRESET_STANDARD
            }
        }

        /** 该档的推荐参数（`recommendedTuning`，`:167-180`；`custom` / 坏值回落出厂档）。 */
        fun tuningOfPreset(preset: String?): LiquidGlassTuningModel {
            val index = PRESET_VALUES.indexOf(preset)
            return if (index >= 0) PRESET_TUNINGS[index] else DEFAULTS
        }

        /**
         * 第几格（1 起）→ 档位（`LiquidGlassPresetX.fromStep`，`:156-165`）。
         * 越界回落 `standard`：滑杆只会给 1~10，这里只是别让坏值把渲染层带崩。
         */
        fun fromStep(step: Int): String =
            if (step < 1 || step > PRESET_STEPS) {
                TimetableSettingsModel.LIQUID_GLASS_PRESET_STANDARD
            } else {
                PRESET_VALUES[step - 1]
            }

        /** 反推档位（`matchPreset`，`:370-378`）：都不匹配时 `custom`。 */
        fun matchPreset(tuning: LiquidGlassTuningModel): String {
            PRESET_VALUES.forEachIndexed { index, value ->
                if (PRESET_TUNINGS[index] == tuning) return value
            }
            return TimetableSettingsModel.LIQUID_GLASS_PRESET_CUSTOM
        }

        /**
         * 存档里「档位键」与「参数键」对不上时以谁为准（`reconcileStoredPreset`，
         * `liquid_glass_tuning.dart:113-129`）——**参数侧永远是真源**，因为渲染只吃参数键。
         *
         * 三种情况逐条照 Dart：
         * 1. 没有参数键（null）⇒ 没有任何东西与档位键矛盾，返回档位键的值（缺键 → `standard`）；
         * 2. 档位键有值、且不是 `custom`、且逐字段等于该档推荐值 ⇒ 保留档位键；
         * 3. 其余 ⇒ `matchPreset` 的结果（等于某格就回那格，否则 `custom`）。
         *
         * @param rawStored 存档里的**原始**值，只用于区分「缺键」与「真的写了某一档」。
         */
        fun reconcileStoredPreset(rawStored: Any?, tuning: LiquidGlassTuningModel?): String {
            val raw = rawStored as? String
            val stored = presetValueOrStandard(raw)
            if (tuning == null) return stored
            if (raw != null &&
                stored != TimetableSettingsModel.LIQUID_GLASS_PRESET_CUSTOM &&
                tuningOfPreset(stored) == tuning
            ) {
                return stored
            }
            return matchPreset(tuning)
        }
    }
}

/**
 * 首页壁纸「最近使用」的一条（`lib/models/wallpaper_history.dart:15-125`）。
 *
 * [key] 是**背景身份键**（自选图片 = 文件绝对路径），与 `homePageBackdropKey` 同口径；
 * 模型层只当它是不透明字符串，不理解 `builtin:` 之类前缀（`:10-13`）。
 *
 * [alignX] / [alignY] / [scale] 是**用这张图时的取景**：切回历史时要连缩放一起还原，
 * 只还原位置等于取景被改了一半（`:33-37`）。
 */
data class WallpaperHistoryRowModel(
    val key: String,
    val alignX: Double = 0.0,
    val alignY: Double = 0.0,
    val scale: Double = 1.0,
    /** 最近一次使用时间（epoch 毫秒）；旧数据缺字段回退 0（`:39-42`）。 */
    val usedAt: Long = 0L,
) {

    /** 空 key 是无意义条目，直接视为脏数据（`:44-45`）。 */
    val isValid: Boolean get() = key.trim().isNotEmpty()

    /** 落盘：五个短键（`:61-67`）。 */
    fun toJson(): Map<String, Any?> = linkedMapOf(
        "key" to key,
        "alignX" to alignX,
        "alignY" to alignY,
        "scale" to scale,
        "usedAt" to usedAt,
    )

    companion object {

        /**
         * 单条解析（`wallpaper_history.dart:78-95`）：非法输入返回 null 而不是抛错。
         *
         * ⚠️ 数值字段**只认 num**（`_numOrNull`，`:97-98`），字符串数字按缺失处理——
         * Dart 那里刻意不用 `as num?`（遇到字符串会抛 TypeError，被上层吞掉后整份设置回落默认，
         * 见 `:69-77` 的注释）。`LenientJson.double` 会接受字符串数字，所以这里不能直接用。
         */
        fun fromJson(raw: Any?): WallpaperHistoryRowModel? {
            val map = raw as? Map<*, *> ?: return null
            val key = map["key"] as? String ?: return null
            fun numOrNull(value: Any?): Double? = (value as? Number)?.toDouble()
            val entry = WallpaperHistoryRowModel(
                key = key,
                alignX = numOrNull(map["alignX"]) ?: 0.0,
                alignY = numOrNull(map["alignY"]) ?: 0.0,
                // 存量存档没有 scale：缺省 1（刚好铺满），与加缩放之前一致（`:90-91`）。
                scale = numOrNull(map["scale"]) ?: 1.0,
                usedAt = (map["usedAt"] as? Number)?.toLong() ?: 0L,
            )
            return if (entry.isValid) entry else null
        }

        /** 列表解析（`:100-108`）：非 List ⇒ 空表；坏条目**逐条丢弃**，不影响其余条目。 */
        fun listFromJson(raw: Any?): List<WallpaperHistoryRowModel> {
            val list = raw as? List<*> ?: return emptyList()
            val out = ArrayList<WallpaperHistoryRowModel>(list.size)
            for (item in list) {
                fromJson(item)?.let { out.add(it) }
            }
            return out
        }
    }
}
