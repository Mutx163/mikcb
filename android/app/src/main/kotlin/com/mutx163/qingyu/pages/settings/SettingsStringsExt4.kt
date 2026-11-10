package com.mutx163.qingyu.pages.settings

/**
 * P3-B-4 设置族第二批文案（`lib/l10n/app_zh.arb`，模板语言 zh）。
 *
 * **逐字抄录，不许改写**：每一条都在 `SettingsStringsExt4ParityTest` 里与 ARB
 * 机械比对，键缺失或值被改写都会红。要改界面文字，先改 ARB（六份同步）+
 * 重新生成 `gen-l10n`，再同步这里——顺序反了会被测试拦下。
 *
 * ## 为什么不并进 `SettingsStrings.kt`
 *
 * 那个文件是四条泳道共用的（P3-B-1…4 同时在写设置族）。各批各建一个
 * `SettingsStringsExt<N>.kt`，谁都不改共享件，四个智能体并行写同一目录也不会互相覆盖。
 *
 * ## 覆盖范围（对应本泳道三个 Dart 源）
 *
 * | Dart 源 | 用到哪些键 |
 * |---|---|
 * | `settings_glass_dock_editor.dart` | 底栏编辑器本体 + 首页入口目录标题 + 四个分类名 |
 * | `settings_glass_dock_icon_editor.dart` | 圆钮图标页标题 / 搜索提示 / 默认格文案 |
 * | `settings_reset.dart` | 五张「恢复默认」卡的作用域说明与确认弹窗正文 |
 * | `settings_shared.dart` | 该共享件的文案（本批只做核对，不产页面） |
 *
 * 命名与 ARB 键逐字一致（`glassDockCustomizeTitle` 等），便于 `grep` 双向核对。
 */
object SettingsStringsExt4 {


    // ------------------------------------------------------------ 底栏编辑器（settings_glass_dock_editor.dart:89-116）

    val glassDockCustomizeTitle = ArbText("glassDockCustomizeTitle", "自定义底栏按钮")
    val homeGridEditorEnabledTitle = ArbText("homeGridEditorEnabledTitle", "已启用")
    val homeGridEditorHintBody = ArbText("homeGridEditorHintBody", "最多放 {max} 个，按住条目可排序")
    val homeDockEditorViewCategory = ArbText("homeDockEditorViewCategory", "视图切换")
    val homeGridEditorMaxReached = ArbText("homeGridEditorMaxReached", "已达上限")
    val homeGridEditorAllAdded = ArbText("homeGridEditorAllAdded", "所有入口都已启用")
    val homeGridEditorRemoveTooltip = ArbText("homeGridEditorRemoveTooltip", "移除")
    val homeGridEditorResetAction = ArbText("homeGridEditorResetAction", "恢复默认排列")

    // ------------------------------------------------------------ 底栏的两个视图切换动作（widgets/home_menu_catalog.dart:560-570）

    val glassDockTabDay = ArbText("glassDockTabDay", "日课表")

    /**
     * 开发壳「页面索引」页的展示名（**非 ARB**，空键即不进逐字对拍）。
     *
     * 这页是开发壳专属（本体 `ShellPageIndexScreen`，屏幕标题就是硬编码的
     * `SHELL_PAGE_INDEX_TITLE`），底栏卡片历来也只写中文。这里照抄同一口径，
     * 供底栏编辑器的候选入口显示，不新开 ARB 键。
     */
    val glassDockPageIndexTitle = ArbText(NON_ARB_TEXT, "页面索引")
    val glassDockTabWeek = ArbText("glassDockTabWeek", "周课表")

    // ------------------------------------------------------------ 首页入口目录的四个分类名（widgets/home_top_menu.dart:12-20）

    val homeMenuCategoryFeatures = ArbText("homeMenuCategoryFeatures", "功能入口")
    val homeMenuCategoryData = ArbText("homeMenuCategoryData", "数据与同步")
    val homeMenuCategoryPreferences = ArbText("homeMenuCategoryPreferences", "偏好设置")
    val homeMenuCategoryAbout = ArbText("homeMenuCategoryAbout", "关于与支持")

    /**
     * 首页入口目录（`kHomeMenuCatalog`）各条目的标题，按 Dart 源声明顺序。
     *
     * 底栏编辑器的「可用入口」区按分类列出这张表里尚未启用的条目，所以
     * 条目名也属于本页文案。`memoryStats` 只在调试包可见（Dart 的 `visible()`
     * 门控），键仍在此登记，是否上屏由模型里的 `debugOnly` 决定。
     */
    val homeMenuUpdateTitle = ArbText("homeMenuUpdateTitle", "版本更新")
    val pickupCodeEntryTitle = ArbText("pickupCodeEntryTitle", "取件码")
    val homeMenuOverviewTitle = ArbText("homeMenuOverviewTitle", "课程总览")
    val homeMenuStatisticsTitle = ArbText("homeMenuStatisticsTitle", "课程统计")
    val homeMenuAddCourseTitle = ArbText("homeMenuAddCourseTitle", "添加")
    val examListTitle = ArbText("examListTitle", "考试安排")
    val homeMenuImportTitle = ArbText("homeMenuImportTitle", "导入课程")
    val courseRecolorTileTitle = ArbText("courseRecolorTileTitle", "课表重新配色")
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
    val homeNavigationTitle = ArbText("homeNavigationTitle", "首页与导航")
    val generalSettingsTitle = ArbText("generalSettingsTitle", "通用")
    val appearanceTitle = ArbText("appearanceTitle", "外观与配色")
    val appearanceEditorTitle = ArbText("appearanceEditorTitle", "外观编辑")
    val timetablePageSettingsTitle = ArbText("timetablePageSettingsTitle", "课表页面")
    val courseCardSettingsTitle = ArbText("courseCardSettingsTitle", "课程卡片")
    val weatherSettingsEntryTitle = ArbText("weatherSettingsEntryTitle", "课程卡天气")
    val liveSettingsTitle = ArbText("liveSettingsTitle", "超级岛与通知")
    val holidaySettingsTitle = ArbText("holidaySettingsTitle", "节假日标记")
    val homeWidgetSettingsTitle = ArbText("homeWidgetSettingsTitle", "桌面小组件")
    val diagnosticsEntryTitle = ArbText("diagnosticsEntryTitle", "诊断")
    val statisticsSettingsTitle = ArbText("statisticsSettingsTitle", "统计设置")
    val homeMenuCoffeeTitle = ArbText("homeMenuCoffeeTitle", "请喝咖啡")
    val aboutTitle = ArbText("aboutTitle", "关于软件")
    val aboutChangelogTitle = ArbText("aboutChangelogTitle", "更新日志")
    val userGuideEntryTitle = ArbText("userGuideEntryTitle", "使用引导与权限")
    val feedbackTitle = ArbText("feedbackTitle", "问题反馈")
    val aboutOpenSourceLicensesTitle = ArbText("aboutOpenSourceLicensesTitle", "开源许可")
    val memoryStatsEntryTitle = ArbText("memoryStatsEntryTitle", "内存状态")

    // ------------------------------------------------------------ 坞图标编辑器（settings_glass_dock_icon_editor.dart:142,180,230）

    val glassDockButtonIconTitle = ArbText("glassDockButtonIconTitle", "圆钮图标")
    val glassDockButtonIconSearchHint = ArbText("glassDockButtonIconSearchHint", "搜索图标名称")
    val clearSearchAction = ArbText("clearSearchAction", "清空")
    val glassDockButtonIconDefault = ArbText("glassDockButtonIconDefault", "默认 加号")

    // ------------------------------------------------------------ 恢复默认（settings_reset.dart:213-294）

    val settingsResetDefaultsTitle = ArbText("settingsResetDefaultsTitle", "恢复默认设置")
    val settingsResetDefaultsConfirmTitle = ArbText("settingsResetDefaultsConfirmTitle", "确认恢复")
    val settingsResetConfirmBodyCourseCard = ArbText("settingsResetConfirmBodyCourseCard", "将把课程卡片的显示字段、布局与颜色恢复为默认值。")
    val settingsResetConfirmBodyTimetablePage = ArbText("settingsResetConfirmBodyTimetablePage", "课表密度、回到本周按钮及背景设置将恢复默认，并清除壁纸。")
    val settingsResetConfirmBodyAppearance = ArbText("settingsResetConfirmBodyAppearance", "将把主题模式、字体、主题色与玻璃质感恢复为默认值。")
    val settingsResetConfirmBodyHomeNavigation = ArbText("settingsResetConfirmBodyHomeNavigation", "将把底栏与首页标题设置恢复为默认值。")
    val settingsResetConfirmBodyHomeWidget = ArbText("settingsResetConfirmBodyHomeWidget", "将把桌面小组件的显示项与外观恢复为默认值。")
    val settingsResetScopeNoticeAppearance = ArbText("settingsResetScopeNoticeAppearance", "主题、字体与玻璃质感")
    val settingsResetScopeNoticeTimetablePage = ArbText("settingsResetScopeNoticeTimetablePage", "课表显示与背景 含清除壁纸")
    val cancelAction = ArbText("cancelAction", "取消")
    val settingsResetDoneMessage = ArbText("settingsResetDoneMessage", "设置已重置")

    // ------------------------------------------------------------ settings_shared.dart 用到的文案（共享件核对，见 SettingsSharedParityTest）

    val liveTimeCorrectionNone = ArbText("liveTimeCorrectionNone", "不矫正")
    val liveTimeCorrectionDelay = ArbText("liveTimeCorrectionDelay", "整体延后 {seconds} 秒")
    val liveTimeCorrectionAdvance = ArbText("liveTimeCorrectionAdvance", "整体提前 {seconds} 秒")
    val saveFailed = ArbText("saveFailed", "保存失败")
    val languageModeSystem = ArbText("languageModeSystem", "跟随系统")
    val liveDisplaySummaryShortName = ArbText("liveDisplaySummaryShortName", "简称")
    val liveDisplaySummaryCourseName = ArbText("liveDisplaySummaryCourseName", "课程名")
    val liveDisplaySummaryLocation = ArbText("liveDisplaySummaryLocation", "地点")
    val liveDisplaySummaryCountdownShort = ArbText("liveDisplaySummaryCountdownShort", "倒计时")
    val liveDisplaySummaryStageText = ArbText("liveDisplaySummaryStageText", "阶段文字")
    val liveDisplaySummaryLeftLabelImage = ArbText("liveDisplaySummaryLeftLabelImage", "图标")
    val liveDisplaySummaryMinimal = ArbText("liveDisplaySummaryMinimal", "最简显示")
    val liveDisplaySummaryMore = ArbText("liveDisplaySummaryMore", "{first} 等 {count} 项")

    /**
     * 全部文案（键 + 逐字值），供 `SettingsStringsExt4ParityTest` 机械比对。
     *
     * 加一条文案而忘了加进这张表，对拍测试的「条数下限」会红——这样「新增文案
     * 漏测」不可能悄悄发生。
     */
    val allTexts: List<ArbText> = listOf(
        glassDockCustomizeTitle,
        homeGridEditorEnabledTitle,
        homeGridEditorHintBody,
        homeDockEditorViewCategory,
        homeGridEditorMaxReached,
        homeGridEditorAllAdded,
        homeGridEditorRemoveTooltip,
        homeGridEditorResetAction,
        glassDockTabDay,
        glassDockTabWeek,
        homeMenuCategoryFeatures,
        homeMenuCategoryData,
        homeMenuCategoryPreferences,
        homeMenuCategoryAbout,
        homeMenuUpdateTitle,
        pickupCodeEntryTitle,
        homeMenuOverviewTitle,
        homeMenuStatisticsTitle,
        homeMenuAddCourseTitle,
        examListTitle,
        homeMenuImportTitle,
        courseRecolorTileTitle,
        homeMenuShareTimetableTitle,
        homeMenuTasksTitle,
        addExam,
        addTask,
        addScheduleTitle,
        scheduleListTitle,
        courseConflictDetailTitle,
        locationTimeMatchTitle,
        scheduleDateRuleSectionTitle,
        icsExportTitle,
        monthViewTitle,
        timeSchemeTitle,
        timetableProfilesTitle,
        switchTimetableTitle,
        homeMenuMoreTitle,
        dataTransferEntryTitle,
        cloudSyncTitle,
        lanEditTitle,
        coupleTimetableTitle,
        homeMenuSettingsTitle,
        homeNavigationTitle,
        generalSettingsTitle,
        appearanceTitle,
        appearanceEditorTitle,
        timetablePageSettingsTitle,
        courseCardSettingsTitle,
        weatherSettingsEntryTitle,
        liveSettingsTitle,
        holidaySettingsTitle,
        homeWidgetSettingsTitle,
        diagnosticsEntryTitle,
        statisticsSettingsTitle,
        homeMenuCoffeeTitle,
        aboutTitle,
        aboutChangelogTitle,
        userGuideEntryTitle,
        feedbackTitle,
        aboutOpenSourceLicensesTitle,
        memoryStatsEntryTitle,
        glassDockButtonIconTitle,
        glassDockButtonIconSearchHint,
        clearSearchAction,
        glassDockButtonIconDefault,
        settingsResetDefaultsTitle,
        settingsResetDefaultsConfirmTitle,
        settingsResetConfirmBodyCourseCard,
        settingsResetConfirmBodyTimetablePage,
        settingsResetConfirmBodyAppearance,
        settingsResetConfirmBodyHomeNavigation,
        settingsResetConfirmBodyHomeWidget,
        settingsResetScopeNoticeAppearance,
        settingsResetScopeNoticeTimetablePage,
        cancelAction,
        settingsResetDoneMessage,
        liveTimeCorrectionNone,
        liveTimeCorrectionDelay,
        liveTimeCorrectionAdvance,
        saveFailed,
        languageModeSystem,
        liveDisplaySummaryShortName,
        liveDisplaySummaryCourseName,
        liveDisplaySummaryLocation,
        liveDisplaySummaryCountdownShort,
        liveDisplaySummaryStageText,
        liveDisplaySummaryLeftLabelImage,
        liveDisplaySummaryMinimal,
        liveDisplaySummaryMore,
    )
}
