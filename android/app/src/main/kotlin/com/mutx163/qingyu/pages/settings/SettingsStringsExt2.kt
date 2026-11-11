package com.mutx163.qingyu.pages.settings

/**
 * P3-B-2 四页用到的 ARB 文案（`lib/l10n/app_zh.arb`，模板语言 zh）。
 *
 * **逐字抄录，不许改写**：每一条都在对应页面的 `...StringsParityTest` 里与 ARB
 * 机械比对。要改界面文字，先改 ARB（六份同步）+ 重新生成 `gen-l10n`，再同步这里
 * ——顺序反了会被测试拦下。
 *
 * ## 为什么不放进 `SettingsStrings.kt`
 *
 * 那个文件是设置族**共享件**：P3-B 这一轮有 4 条泳道同时在写设置族，谁都改它就会
 * 互相覆盖。所以每个批次各自新建 `SettingsStringsExt<N>.kt`，汇合由 Lead 一次做完。
 *
 * ## 与共享件的重复键
 *
 * `courseRecolorTileTitle` / `courseCardSettingsTitle` / `generalSettingsTitle` /
 * `settingsResetDefaultsTitle` 已在 [SettingsStrings] 里，这里不再重复定义，
 * 直接引用那边（同一个 ARB 键只能有一处真源）。
 *
 * 命名与 ARB 键逐字一致（`homeWidgetSettingsTitle` 等），便于 `grep` 双向核对。
 */
object SettingsStringsExt2 {

    // ------------------------------------------------------------ 桌面小组件页（`lib/screens/settings/settings_home_widget.dart`）

    val homeWidgetSettingsTitle = ArbText("homeWidgetSettingsTitle", "桌面小组件")
    val homeWidgetPreviewTitle = ArbText("homeWidgetPreviewTitle", "效果预览")
    val homeWidgetPreviewAddAction = ArbText("homeWidgetPreviewAddAction", "添加到桌面")
    val homeWidgetPreviewUnavailable = ArbText("homeWidgetPreviewUnavailable", "预览暂不可用")
    val homeWidgetTodayCourseTitle = ArbText("homeWidgetTodayCourseTitle", "今日课程组件")
    val homeWidgetBackgroundStyleLabel = ArbText("homeWidgetBackgroundStyleLabel", "背景样式")
    val widgetBackgroundStyleGlass = ArbText("widgetBackgroundStyleGlass", "半透明玻璃感")
    val widgetBackgroundStyleSolid = ArbText("widgetBackgroundStyleSolid", "纯色卡片")
    val widgetBackgroundStyleGradient = ArbText("widgetBackgroundStyleGradient", "渐变卡片")
    val homeWidgetCourseAccentTitle = ArbText("homeWidgetCourseAccentTitle", "课程颜色")
    val widgetCourseAccentModeOff = ArbText("widgetCourseAccentModeOff", "关闭")
    val widgetCourseAccentModeBar = ArbText("widgetCourseAccentModeBar", "仅色条")
    val widgetCourseAccentModeBarAndText = ArbText("widgetCourseAccentModeBarAndText", "色条 + 文字")
    val homeWidgetShowLocationTitle = ArbText("homeWidgetShowLocationTitle", "显示地点")
    val homeWidgetShowLocationSubtitle = ArbText("homeWidgetShowLocationSubtitle", "关闭后改显周次与课程数")
    val homeWidgetShowCountdownTitle = ArbText("homeWidgetShowCountdownTitle", "显示倒计时")
    val homeWidgetShowCountdownSubtitle = ArbText("homeWidgetShowCountdownSubtitle", "开启后每分钟刷新")
    /** 开关下方的整宽说明：把「实时」的电费明说（宽度不受单行口径约束）。 */
    val homeWidgetCountdownBatteryHint = ArbText(
        "homeWidgetCountdownBatteryHint",
        "开启后卡片每分钟重绘一次，上课日约增加几百次唤醒，待机耗电明显上升。",
    )
    val homeWidgetHideCompletedTitle = ArbText("homeWidgetHideCompletedTitle", "隐藏已上完课程")
    val homeWidgetHideCompletedSubtitle = ArbText("homeWidgetHideCompletedSubtitle", "只显示未结束的课程")
    val homeWidgetShowTomorrowTitle = ArbText("homeWidgetShowTomorrowTitle", "课后显示明日课程")
    val homeWidgetShowTomorrowSubtitle = ArbText("homeWidgetShowTomorrowSubtitle", "今日课后自动显示明天课程")
    val homeWidgetCountdownLeadTitle = ArbText("homeWidgetCountdownLeadTitle", "倒计时提前量")
    val homeWidgetCountdownLeadAlways = ArbText("homeWidgetCountdownLeadAlways", "始终显示")
    val beforeClassMinutesOption = ArbText("beforeClassMinutesOption", "{minutes} 分钟")
    val widgetCountdownStyleTitle = ArbText("widgetCountdownStyleTitle", "倒计时样式")
    val liveCountdownTextStyleSmart = ArbText("liveCountdownTextStyleSmart", "智能 中文")
    val liveCountdownTextStyleSmartMinS = ArbText("liveCountdownTextStyleSmartMinS", "智能 英文")
    val liveCountdownTextStyleMinuteSecondCn = ArbText("liveCountdownTextStyleMinuteSecondCn", "分秒 5分19秒")
    val liveCountdownTextStyleMinuteSecondColon = ArbText("liveCountdownTextStyleMinuteSecondColon", "分秒 05:19")
    val liveCountdownTextStyleMinuteSecondMinS = ArbText("liveCountdownTextStyleMinuteSecondMinS", "英文 5min19s")
    val liveCountdownTextStyleMinuteSecondMinSlashS = ArbText("liveCountdownTextStyleMinuteSecondMinSlashS", "英文 5min/19s")
    val liveCountdownTextStyleMinuteOnlyCn = ArbText("liveCountdownTextStyleMinuteOnlyCn", "纯分钟 5分钟")
    val liveCountdownTextStyleMinuteOnlyMin = ArbText("liveCountdownTextStyleMinuteOnlyMin", "纯分钟 5min")
    val liveCountdownTextStyleMinuteOnlySlash = ArbText("liveCountdownTextStyleMinuteOnlySlash", "纯分钟 5/min")
    val liveCountdownTextStyleSecondOnlyCn = ArbText("liveCountdownTextStyleSecondOnlyCn", "纯秒 5秒")
    val liveCountdownTextStyleSecondOnlyShort = ArbText("liveCountdownTextStyleSecondOnlyShort", "纯秒 5s")
    val liveCountdownTextStyleSecondOnlySlash = ArbText("liveCountdownTextStyleSecondOnlySlash", "纯秒 5/s")
    val homeWidgetAppearanceTitle = ArbText("homeWidgetAppearanceTitle", "卡片外观")
    val homeWidgetHeightAdjustTitle = ArbText("homeWidgetHeightAdjustTitle", "卡片高度")
    val homeWidgetHeightAdjustHint = ArbText("homeWidgetHeightAdjustHint", "范围 -16～16，正数更高，负数更矮")
    val homeWidgetCornerRadiusTitle = ArbText("homeWidgetCornerRadiusTitle", "卡片圆角")
    val defaultLabel = ArbText("defaultLabel", "默认")
    val higherByValue = ArbText("higherByValue", "更高 {value}")
    val lowerByValue = ArbText("lowerByValue", "更矮 {value}")
    val homeWidgetBindingSectionTitle = ArbText("homeWidgetBindingSectionTitle", "各卡片绑定管理")
    val homeWidgetBindingFollowActive = ArbText("homeWidgetBindingFollowActive", "跟随当前课表")
    val homeWidgetBindingCoupleMerged = ArbText("homeWidgetBindingCoupleMerged", "情侣课表")
    val homeWidgetBindingEmpty = ArbText("homeWidgetBindingEmpty", "桌面上还没有今日课程卡片，先添加一张再回来绑定")
    val homeWidgetExactAlarmBannerTitle = ArbText("homeWidgetExactAlarmBannerTitle", "精确闹钟权限未授予")
    val homeWidgetExactAlarmBannerText = ArbText("homeWidgetExactAlarmBannerText", "缺少闹钟权限，卡片刷新可能延迟")
    val homeWidgetExactAlarmGrantAction = ArbText("homeWidgetExactAlarmGrantAction", "去授权")
    // 系统动作结果提示（F20 宿主：pin / 授权页 / 绑定失败的 Toast，文案照 ARB 逐字）。
    val homeWidgetPinRequested = ArbText(
        "homeWidgetPinRequested",
        "已发起 {label} 添加请求，请在系统弹窗中确认添加",
    )
    val homeWidgetPinUnsupportedManual = ArbText(
        "homeWidgetPinUnsupportedManual",
        "系统桌面不支持应用内添加组件，请长按桌面通过小组件菜单添加 {label}",
    )
    val homeWidgetInvalidType = ArbText("homeWidgetInvalidType", "小组件类型无效，请稍后重试")
    val homeWidgetPinFailedManual = ArbText(
        "homeWidgetPinFailedManual",
        "添加失败，请长按桌面通过小组件菜单添加 {label}",
    )
    val homeWidgetBindingSaveFailed = ArbText(
        "homeWidgetBindingSaveFailed",
        "保存卡片绑定失败，请稍后重试",
    )
    val homeWidgetExactAlarmOpenFailed = ArbText(
        "homeWidgetExactAlarmOpenFailed",
        "打开授权页失败，请前往系统设置开启闹钟和提醒权限",
    )
    val homeWidgetExactAlarmFallbackHint = ArbText(
        "homeWidgetExactAlarmFallbackHint",
        "已打开应用设置，请开启闹钟和提醒权限",
    )
    val homeWidgetTargetCompact22 = ArbText("homeWidgetTargetCompact22", "主卡 2×2")
    val homeWidgetTargetMiniList22 = ArbText("homeWidgetTargetMiniList22", "迷你列表 2×2")
    val homeWidgetTargetMedium24 = ArbText("homeWidgetTargetMedium24", "概览 2×4")
    val homeWidgetTargetLarge44 = ArbText("homeWidgetTargetLarge44", "列表 4×4")
    val homeWidgetTargetStats22 = ArbText("homeWidgetTargetStats22", "统计 2×2")
    val homeWidgetTargetStats24 = ArbText("homeWidgetTargetStats24", "统计概览 2×4")
    val homeWidgetTargetStatsStrip41 = ArbText("homeWidgetTargetStatsStrip41", "统计横条 4×1")
    val homeWidgetTargetTodayStrip41 = ArbText("homeWidgetTargetTodayStrip41", "今日横条 4×1")
    val homeWidgetTargetExamCard22 = ArbText("homeWidgetTargetExamCard22", "考试倒计时 2×2")
    val homeWidgetTargetTodayWide42 = ArbText("homeWidgetTargetTodayWide42", "今日横宽 4×2")

    // ------------------------------------------------------------ 首页与导航页（`lib/screens/settings/settings_home_navigation.dart`）

    val homeNavigationTitle = ArbText("homeNavigationTitle", "首页与导航")
    val homeNavigationFormLabel = ArbText("homeNavigationFormLabel", "应用形态")
    val homeNavigationFormClassic = ArbText("homeNavigationFormClassic", "经典形态")
    val homeNavigationFormClassicSubtitle = ArbText("homeNavigationFormClassicSubtitle", "保持现有的页面与导航方式")
    val homeNavigationFormGlassDock = ArbText("homeNavigationFormGlassDock", "玻璃坞")
    val homeNavigationFormGlassDockSubtitle = ArbText("homeNavigationFormGlassDockSubtitle", "悬浮玻璃底栏，切换日/周课表")
    val glassDockCustomizeSectionTitle = ArbText("glassDockCustomizeSectionTitle", "底部导航栏")
    val glassDockShowAddButtonTitle = ArbText("glassDockShowAddButtonTitle", "显示圆钮")
    val glassDockShowAddButtonSubtitle = ArbText("glassDockShowAddButtonSubtitle", "在药丸右侧单独显示")
    val glassDockCustomizeTitle = ArbText("glassDockCustomizeTitle", "自定义底栏按钮")
    val glassDockRoundActionLabel = ArbText("glassDockRoundActionLabel", "圆钮功能")
    val glassDockButtonIconTitle = ArbText("glassDockButtonIconTitle", "圆钮图标")
    val glassDockButtonIconDefault = ArbText("glassDockButtonIconDefault", "默认 加号")
    val homeMenuAddCourseTitle = ArbText("homeMenuAddCourseTitle", "添加")
    val homeMenuCustomizeSectionTitle = ArbText("homeMenuCustomizeSectionTitle", "右上角菜单")
    val homeMenuStyleLabel = ArbText("homeMenuStyleLabel", "右上角菜单样式")
    val homeMenuStyleList = ArbText("homeMenuStyleList", "列表菜单")
    val homeMenuStyleGrid = ArbText("homeMenuStyleGrid", "八宫格菜单")
    val homeMenuCustomizeTitle = ArbText("homeMenuCustomizeTitle", "自定义菜单按钮")
    val homeGridCustomizeDetails = ArbText("homeGridCustomizeDetails", "已启用 {count}/{max} 个")
    val homeTitleSectionTitle = ArbText("homeTitleSectionTitle", "首页标题")
    val homeTitleStyleLabel = ArbText("homeTitleStyleLabel", "标题样式")
    val homeTitleStyleClassicLabel = ArbText("homeTitleStyleClassicLabel", "经典文字")
    val homeTitleStyleBrandLabel = ArbText("homeTitleStyleBrandLabel", "大 Logo")
    val glassDockTabDay = ArbText("glassDockTabDay", "日课表")
    val glassDockTabWeek = ArbText("glassDockTabWeek", "周课表")
    val appTitle = ArbText("appTitle", "轻屿课表")
    val defaultTimetablePreviewName = ArbText("defaultTimetablePreviewName", "默认课表")

    // ------------------------------------------------------------ 八宫格编辑器（`lib/screens/settings/settings_home_menu_editor.dart`）

    val homeGridEditorEnabledTitle = ArbText("homeGridEditorEnabledTitle", "已启用")
    val homeGridEditorHintBody = ArbText("homeGridEditorHintBody", "最多放 {max} 个，按住条目可排序")
    val homeGridEditorAllAdded = ArbText("homeGridEditorAllAdded", "所有入口都已启用")
    val homeGridEditorMaxReached = ArbText("homeGridEditorMaxReached", "已达上限")
    val homeGridEditorPinnedTooltip = ArbText("homeGridEditorPinnedTooltip", "此入口用于重新打开本页，不能移除")
    val homeGridEditorRemoveTooltip = ArbText("homeGridEditorRemoveTooltip", "移除")
    val homeGridEditorResetAction = ArbText("homeGridEditorResetAction", "恢复默认排列")
    val homeMenuCategoryFeatures = ArbText("homeMenuCategoryFeatures", "功能入口")
    val homeMenuCategoryData = ArbText("homeMenuCategoryData", "数据与同步")
    val homeMenuCategoryPreferences = ArbText("homeMenuCategoryPreferences", "偏好设置")
    val homeMenuCategoryAbout = ArbText("homeMenuCategoryAbout", "关于与支持")

    // ------------------------------------------------------------ 八宫格候选目录（`lib/widgets/home_menu_catalog.dart` + `home_top_menu.dart`）

    val homeMenuUpdateTitle = ArbText("homeMenuUpdateTitle", "版本更新")
    val pickupCodeEntryTitle = ArbText("pickupCodeEntryTitle", "取件码")
    val homeMenuOverviewTitle = ArbText("homeMenuOverviewTitle", "课程总览")
    val homeMenuStatisticsTitle = ArbText("homeMenuStatisticsTitle", "课程统计")
    val examListTitle = ArbText("examListTitle", "考试安排")
    val homeMenuImportTitle = ArbText("homeMenuImportTitle", "导入课程")
    val homeMenuShareTimetableTitle = ArbText("homeMenuShareTimetableTitle", "分享课表图片")
    val homeMenuTasksTitle = ArbText("homeMenuTasksTitle", "任务清单")
    val addExam = ArbText("addExam", "添加考试")
    val addTask = ArbText("addTask", "添加任务")
    val addScheduleTitle = ArbText("addScheduleTitle", "添加日程")
    val scheduleListTitle = ArbText("scheduleListTitle", "日程安排")
    val courseConflictDetailTitle = ArbText("courseConflictDetailTitle", "冲突详情")
    val locationTimeMatchTitle = ArbText("locationTimeMatchTitle", "地点作息匹配")
    val scheduleDateRuleSectionTitle = ArbText("scheduleDateRuleSectionTitle", "日期作息规则")
    val icsExportTitle = ArbText("icsExportTitle", "导出日历")
    val monthViewTitle = ArbText("monthViewTitle", "月视图")
    val timeSchemeTitle = ArbText("timeSchemeTitle", "时间模板")
    val timetableProfilesTitle = ArbText("timetableProfilesTitle", "课表管理")
    val switchTimetableTitle = ArbText("switchTimetableTitle", "切换课表")
    val homeMenuMoreTitle = ArbText("homeMenuMoreTitle", "全部功能")
    val dataTransferEntryTitle = ArbText("dataTransferEntryTitle", "数据备份与迁移")
    val cloudSyncTitle = ArbText("cloudSyncTitle", "云同步")
    val lanEditTitle = ArbText("lanEditTitle", "局域网编辑")
    val coupleTimetableTitle = ArbText("coupleTimetableTitle", "情侣课表")
    val homeMenuSettingsTitle = ArbText("homeMenuSettingsTitle", "课表设置")
    val statisticsSettingsTitle = ArbText("statisticsSettingsTitle", "统计设置")
    val homeMenuCoffeeTitle = ArbText("homeMenuCoffeeTitle", "请喝咖啡")
    val aboutTitle = ArbText("aboutTitle", "关于软件")
    val aboutChangelogTitle = ArbText("aboutChangelogTitle", "更新日志")
    val userGuideEntryTitle = ArbText("userGuideEntryTitle", "使用引导与权限")
    val feedbackTitle = ArbText("feedbackTitle", "问题反馈")
    val aboutOpenSourceLicensesTitle = ArbText("aboutOpenSourceLicensesTitle", "开源许可")
    val memoryStatsEntryTitle = ArbText("memoryStatsEntryTitle", "内存状态")

    // ------------------------------------------------------------ 设置首页 / 学期设置（`lib/screens/timetable_settings_screen.dart`）

    val settingsTitle = ArbText("settingsTitle", "课表设置")
    val settingsTimetableSectionTitle = ArbText("settingsTimetableSectionTitle", "课表")
    val timetableManagement = ArbText("timetableManagement", "课表管理")
    val timeSchemeEntryTitle = ArbText("timeSchemeEntryTitle", "时间模板")
    val holidaySettingsEntryTitle = ArbText("holidaySettingsEntryTitle", "节假日标记")
    val liveIslandLabelEntryEnabled = ArbText("liveIslandLabelEntryEnabled", "已开启")
    val liveIslandLabelEntryDisabled = ArbText("liveIslandLabelEntryDisabled", "已关闭")
    val settingsDisplayAppearanceSectionTitle = ArbText("settingsDisplayAppearanceSectionTitle", "课表显示")
    val timetablePageSettingsTitle = ArbText("timetablePageSettingsTitle", "课表页面")
    val weatherSettingsEntryTitle = ArbText("weatherSettingsEntryTitle", "课程卡天气")
    val weatherCityNotSet = ArbText("weatherCityNotSet", "未设置")
    val settingsReminderDesktopSectionTitle = ArbText("settingsReminderDesktopSectionTitle", "提醒与桌面")
    val liveSettingsTitle = ArbText("liveSettingsTitle", "超级岛与通知")
    val liveNotificationPermissionMissing = ArbText("liveNotificationPermissionMissing", "缺少通知权限")
    val homeWidgetEntryTitle = ArbText("homeWidgetEntryTitle", "桌面小组件")
    val settingsAppSectionTitle = ArbText("settingsAppSectionTitle", "应用")
    val appearanceEntryTitle = ArbText("appearanceEntryTitle", "外观与配色")
    val settingsDataShareSectionTitle = ArbText("settingsDataShareSectionTitle", "数据与共享")
    val cloudSyncEntryTitle = ArbText("cloudSyncEntryTitle", "云同步")
    val cloudSyncEntryDisabled = ArbText("cloudSyncEntryDisabled", "已关闭")
    val cloudSyncEntrySyncing = ArbText("cloudSyncEntrySyncing", "同步中")
    val cloudSyncEntryError = ArbText("cloudSyncEntryError", "上次同步失败")
    val cloudSyncEntryEnabled = ArbText("cloudSyncEntryEnabled", "已开启")
    val lanEditEntryTitle = ArbText("lanEditEntryTitle", "局域网编辑")
    val coupleTimetableEntryTitle = ArbText("coupleTimetableEntryTitle", "情侣课表")
    val coupleTimetableEntryBound = ArbText("coupleTimetableEntryBound", "已绑定")
    val coupleTimetableEntryUnboundLabel = ArbText("coupleTimetableEntryUnboundLabel", "未绑定")
    val settingsAboutSectionTitle = ArbText("settingsAboutSectionTitle", "关于")
    val aboutEntryTitle = ArbText("aboutEntryTitle", "关于软件")
    val diagnosticsEntryTitle = ArbText("diagnosticsEntryTitle", "诊断")
    val diagnosticsEntrySubtitle = ArbText("diagnosticsEntrySubtitle", "日志 · 自检 · 内存")
    val developerSectionTitle = ArbText("developerSectionTitle", "开发者选项")
    val liveTestingFixtureEntryTitle = ArbText("liveTestingFixtureEntryTitle", "实况测试样例")
    val hyperosShowcaseEntryTitle = ArbText("hyperosShowcaseEntryTitle", "HyperOS 组件展示")
    val hyperosShowcaseEntrySubtitle = ArbText("hyperosShowcaseEntrySubtitle", "HyperOS 组件预览")
    val miuixShowcaseEntryTitle = ArbText("miuixShowcaseEntryTitle", "Miuix 组件展示")
    val miuixShowcaseEntrySubtitle = ArbText("miuixShowcaseEntrySubtitle", "Miuix 组件预览")
    val debugUiOverlayToggleTitle = ArbText("debugUiOverlayToggleTitle", "调试 UI 叠层")
    val debugUiOverlayOpenPanelTitle = ArbText("debugUiOverlayOpenPanelTitle", "打开调试面板")
    val semesterOverviewCurrentWeek = ArbText("semesterOverviewCurrentWeek", "第 {current} 周，共 {total} 周")
    val semesterStartUnset = ArbText("semesterStartUnset", "未设置开学日期")
    val semesterStartSet = ArbText("semesterStartSet", "开学日期：{date}")
    val settingsSemesterScreenTitle = ArbText("settingsSemesterScreenTitle", "学期设置")
    val setSemesterStartDateAction = ArbText("setSemesterStartDateAction", "设置开学日期")
    val semesterStartDateAction = ArbText("semesterStartDateAction", "开学日期")
    val semesterStartDateLabel = ArbText("semesterStartDateLabel", "开学日期")
    val selectSemesterWeekCountTitle = ArbText("selectSemesterWeekCountTitle", "选择学期周数")
    val semesterWeekCountAction = ArbText("semesterWeekCountAction", "{count} 周")
    val syncCurrentWeekAction = ArbText("syncCurrentWeekAction", "同步当前周")
    val syncCurrentWeekNeedsStartDate = ArbText("syncCurrentWeekNeedsStartDate", "请先设置开学日期")
    val syncedCurrentWeekMessage = ArbText("syncedCurrentWeekMessage", "已同步到第 {week} 周")
    val saveFailed = ArbText("saveFailed", "保存失败")

    /**
     * 本文件声明的**全部**文案，声明顺序。
     *
     * 给 `...StringsParityTest` 用来「逐条与 ARB 比对」：Kotlin 反射读不到
     * `object` 的 val 清单（没有 `declaredFields` 顺序保证、也拿不到泛型实参），
     * 所以显式列一遍。新增一条文案时**必须**同时加到这里——漏加会被
     * `Ext2 的文案条数太少` 那条门槛抓住。
     */
    fun all(): List<ArbText> = listOf(
        homeWidgetSettingsTitle, homeWidgetPreviewTitle, homeWidgetPreviewAddAction, homeWidgetPreviewUnavailable, homeWidgetTodayCourseTitle, homeWidgetBackgroundStyleLabel,
        widgetBackgroundStyleGlass, widgetBackgroundStyleSolid, widgetBackgroundStyleGradient, homeWidgetCourseAccentTitle, widgetCourseAccentModeOff, widgetCourseAccentModeBar,
        widgetCourseAccentModeBarAndText, homeWidgetShowLocationTitle, homeWidgetShowLocationSubtitle, homeWidgetShowCountdownTitle, homeWidgetShowCountdownSubtitle, homeWidgetCountdownBatteryHint, homeWidgetHideCompletedTitle,
        homeWidgetHideCompletedSubtitle, homeWidgetShowTomorrowTitle, homeWidgetShowTomorrowSubtitle, homeWidgetCountdownLeadTitle, homeWidgetCountdownLeadAlways, beforeClassMinutesOption,
        widgetCountdownStyleTitle, liveCountdownTextStyleSmart, liveCountdownTextStyleSmartMinS, liveCountdownTextStyleMinuteSecondCn, liveCountdownTextStyleMinuteSecondColon, liveCountdownTextStyleMinuteSecondMinS,
        liveCountdownTextStyleMinuteSecondMinSlashS, liveCountdownTextStyleMinuteOnlyCn, liveCountdownTextStyleMinuteOnlyMin, liveCountdownTextStyleMinuteOnlySlash, liveCountdownTextStyleSecondOnlyCn, liveCountdownTextStyleSecondOnlyShort,
        liveCountdownTextStyleSecondOnlySlash, homeWidgetAppearanceTitle, homeWidgetHeightAdjustTitle, homeWidgetHeightAdjustHint, homeWidgetCornerRadiusTitle, defaultLabel,
        higherByValue, lowerByValue, homeWidgetBindingSectionTitle, homeWidgetBindingFollowActive, homeWidgetBindingCoupleMerged, homeWidgetBindingEmpty,
        homeWidgetExactAlarmBannerTitle, homeWidgetExactAlarmBannerText, homeWidgetExactAlarmGrantAction, homeWidgetPinRequested, homeWidgetPinUnsupportedManual,
        homeWidgetInvalidType, homeWidgetPinFailedManual, homeWidgetBindingSaveFailed, homeWidgetExactAlarmOpenFailed, homeWidgetExactAlarmFallbackHint, homeWidgetTargetCompact22, homeWidgetTargetMiniList22, homeWidgetTargetMedium24,
        homeWidgetTargetLarge44, homeWidgetTargetStats22, homeWidgetTargetStats24, homeWidgetTargetStatsStrip41, homeWidgetTargetTodayStrip41, homeWidgetTargetExamCard22,
        homeWidgetTargetTodayWide42, homeNavigationTitle, homeNavigationFormLabel, homeNavigationFormClassic, homeNavigationFormClassicSubtitle, homeNavigationFormGlassDock,
        homeNavigationFormGlassDockSubtitle, glassDockCustomizeSectionTitle, glassDockShowAddButtonTitle, glassDockShowAddButtonSubtitle, glassDockCustomizeTitle, glassDockRoundActionLabel,
        glassDockButtonIconTitle, glassDockButtonIconDefault, homeMenuAddCourseTitle, homeMenuCustomizeSectionTitle, homeMenuStyleLabel, homeMenuStyleList,
        homeMenuStyleGrid, homeMenuCustomizeTitle, homeGridCustomizeDetails, homeTitleSectionTitle, homeTitleStyleLabel, homeTitleStyleClassicLabel,
        homeTitleStyleBrandLabel, glassDockTabDay, glassDockTabWeek, appTitle, defaultTimetablePreviewName, homeGridEditorEnabledTitle,
        homeGridEditorHintBody, homeGridEditorAllAdded, homeGridEditorMaxReached, homeGridEditorPinnedTooltip, homeGridEditorRemoveTooltip, homeGridEditorResetAction,
        homeMenuCategoryFeatures, homeMenuCategoryData, homeMenuCategoryPreferences, homeMenuCategoryAbout, homeMenuUpdateTitle, pickupCodeEntryTitle,
        homeMenuOverviewTitle, homeMenuStatisticsTitle, examListTitle, homeMenuImportTitle, homeMenuShareTimetableTitle, homeMenuTasksTitle,
        addExam, addTask, addScheduleTitle, scheduleListTitle, courseConflictDetailTitle, locationTimeMatchTitle,
        scheduleDateRuleSectionTitle, icsExportTitle, monthViewTitle, timeSchemeTitle, timetableProfilesTitle, switchTimetableTitle,
        homeMenuMoreTitle, dataTransferEntryTitle, cloudSyncTitle, lanEditTitle, coupleTimetableTitle, homeMenuSettingsTitle,
        statisticsSettingsTitle, homeMenuCoffeeTitle, aboutTitle, aboutChangelogTitle, userGuideEntryTitle, feedbackTitle,
        aboutOpenSourceLicensesTitle, memoryStatsEntryTitle, settingsTitle, settingsTimetableSectionTitle, timetableManagement, timeSchemeEntryTitle,
        holidaySettingsEntryTitle, liveIslandLabelEntryEnabled, liveIslandLabelEntryDisabled, settingsDisplayAppearanceSectionTitle, timetablePageSettingsTitle,
        weatherSettingsEntryTitle, weatherCityNotSet, settingsReminderDesktopSectionTitle, liveSettingsTitle, liveNotificationPermissionMissing, homeWidgetEntryTitle,
        settingsAppSectionTitle, appearanceEntryTitle, settingsDataShareSectionTitle, cloudSyncEntryTitle, cloudSyncEntryDisabled, cloudSyncEntrySyncing,
        cloudSyncEntryError, cloudSyncEntryEnabled, lanEditEntryTitle, coupleTimetableEntryTitle, coupleTimetableEntryBound, coupleTimetableEntryUnboundLabel,
        settingsAboutSectionTitle, aboutEntryTitle, diagnosticsEntryTitle, diagnosticsEntrySubtitle, developerSectionTitle, liveTestingFixtureEntryTitle,
        hyperosShowcaseEntryTitle, hyperosShowcaseEntrySubtitle, miuixShowcaseEntryTitle, miuixShowcaseEntrySubtitle, debugUiOverlayToggleTitle, debugUiOverlayOpenPanelTitle,
        semesterOverviewCurrentWeek, semesterStartUnset, semesterStartSet, settingsSemesterScreenTitle, setSemesterStartDateAction, semesterStartDateAction,
        semesterStartDateLabel, selectSemesterWeekCountTitle, semesterWeekCountAction, syncCurrentWeekAction, syncCurrentWeekNeedsStartDate, syncedCurrentWeekMessage,
        saveFailed,
    )
}
