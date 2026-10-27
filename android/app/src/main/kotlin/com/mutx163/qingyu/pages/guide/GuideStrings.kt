package com.mutx163.qingyu.pages.guide

/**
 * 引导与展示 (Guide & Showcase) 模块用到的 ARB 文案（`lib/l10n/app_zh.arb`，模板语言 zh）。
 *
 * **逐字抄录，不许改写**：每一条都在 [GuideStringsParityTest] 里与 ARB 机械比对，
 * 键缺失或值被改写都会红。
 */
data class ArbText(val key: String, val zh: String) {
    /** 替换模板里的占位符（`{name}` → [value]）。 */
    fun filled(name: String, value: String): String = zh.replace("{$name}", value)

    fun filled(vararg pairs: Pair<String, String>): String {
        var result = zh
        for ((name, value) in pairs) {
            result = result.replace("{$name}", value)
        }
        return result
    }
}

fun String.filled(name: String, value: String): String = replace("{$name}", value)

object GuideStrings {

    // ── 旧版迁移与初启引导 (PackageMigrationGuideScreen & StartupFlow) ──
    val migrationTitle = ArbText("migrationTitle", "迁移旧数据")
    val migrationSafeTitle = ArbText("migrationSafeTitle", "别担心，这不是数据丢失")
    val migrationSafeSubtitle = ArbText("migrationSafeSubtitle", "我们更换了应用包名，所以桌面上会暂时出现两个应用图标，这是正常现象，旧数据仍在旧版应用里，请先去旧版备份，再回到新版导入")
    val migrationStep1Title = ArbText("migrationStep1Title", "打开旧版应用")
    val migrationStep1Subtitle = ArbText("migrationStep1Subtitle", "进入数据备份与迁移页面，选择导出全部数据。在新版恢复完成前请勿卸载旧版。")
    val migrationStep2Title = ArbText("migrationStep2Title", "保存备份文件")
    val migrationStep2Subtitle = ArbText("migrationStep2Subtitle", "旧版导出后在系统面板选择保存到文件，建议存入系统下载目录")
    val migrationStep3Title = ArbText("migrationStep3Title", "回到当前版本导入")
    val migrationStep3Subtitle = ArbText("migrationStep3Subtitle", "在新版中选择导出的 .mikcb 备份文件即可恢复。确认数据无误后再卸载旧版。")
    val migrationNoSaveToFilesTitle = ArbText("migrationNoSaveToFilesTitle", "未找到保存到文件选项")
    val migrationNoSaveToFilesSubtitle = ArbText("migrationNoSaveToFilesSubtitle", "可以先分享到微信任意一个聊天，然后在微信里点开这个备份文件并保存，保存后通常会出现在 Download / WeiXin 文件夹里，再回到新版选择这个 .mikcb 文件导入")
    val openingOldApp = ArbText("openingOldApp", "正在打开旧版……")
    val openOldAppForBackup = ArbText("openOldAppForBackup", "打开旧版去备份")
    val backupDoneGoImport = ArbText("backupDoneGoImport", "我已完成备份，去导入")
    val startFreshWithoutMigration = ArbText("startFreshWithoutMigration", "以全新应用开始，不迁移")
    val openOldAppFailed = ArbText("openOldAppFailed", "未能打开旧版应用，请手动返回桌面打开旧版")

    // ── 开学日期与周次设置 ──
    val setSemesterStartDateAction = ArbText("setSemesterStartDateAction", "设置开学日期")
    val semesterStartDateLabel = ArbText("semesterStartDateLabel", "开学日期")
    val currentWeekCompact = ArbText("currentWeekCompact", "{week} 周")
    val syncedCurrentWeekMessage = ArbText("syncedCurrentWeekMessage", "已同步到第 {week} 周")

    // ── 用户指南：欢迎页 ──
    val welcomeTitle = ArbText("welcomeTitle", "欢迎使用")
    val welcomeAppName = ArbText("welcomeAppName", "轻屿课表")
    val welcomeSubtitle = ArbText("welcomeSubtitle", "你可以先开始使用，也可以直接导入课程或从备份恢复")
    val thirdPartyDisclaimer = ArbText("thirdPartyDisclaimer", "特此声明：本应用由第三方开发者独立开发，仅用于学习研究用途，不属于小米官方软件，与小米科技有限责任公司无任何隶属、合作或授权关系。如涉及内容侵权，请权利方联系作者，我们将第一时间下架并删除相关内容。")
    val languageSectionTitle = ArbText("languageSectionTitle", "应用语言")
    val languageModeLabel = ArbText("languageModeLabel", "语言选择")
    val startUsingTitle = ArbText("startUsingTitle", "开始使用")
    val importTimetableTitle = ArbText("importTimetableTitle", "导入课表")
    val importTimetableSubtitle = ArbText("importTimetableSubtitle", "从 .ics 或 AI 解析结果导入")
    val restoreBackupTitle = ArbText("restoreBackupTitle", "从备份恢复")
    val restoreBackupSubtitle = ArbText("restoreBackupSubtitle", "从 .mikcb 备份文件恢复旧数据")

    // ── 用户指南：隐私与免责页 ──
    val guidePrivacyPageTitle = ArbText("guidePrivacyPageTitle", "隐私协议")
    val guidePrivacyReadBeforeUse = ArbText("guidePrivacyReadBeforeUse", "使用前请阅读并同意以下内容")
    val guidePrivacyViewOnly = ArbText("guidePrivacyViewOnly", "隐私、第三方 SDK 与免责说明")
    val guidePrivacySectionTitle = ArbText("guidePrivacySectionTitle", "隐私、第三方 SDK 与免责说明")
    val guidePrivacyParagraph1 = ArbText("guidePrivacyParagraph1", "本应用主体功能按本地运行方式设计，课表、时间模板、课程记录和大部分设置默认保存在你的设备本地。")
    val guidePrivacyParagraph2 = ArbText("guidePrivacyParagraph2", "只有在你主动使用检查更新、下载更新、导入导出等联网功能，或你勾选同意后初始化友盟相关 SDK 时，应用才会与外部服务发生数据交互。")
    val guidePrivacyParagraph3 = ArbText("guidePrivacyParagraph3", "本应用接入友盟移动统计 SDK、友盟应用性能监控 SDK 以及高级运营分析依赖库。它们的服务用途包括移动统计分析、应用性能监控和高级运营分析。只有在你勾选同意后，这些 SDK 才会正式初始化。")
    val guidePrivacyParagraph4 = ArbText("guidePrivacyParagraph4", "按友盟官方说明，这些 SDK 可能处理的信息包括：设备信息（如 IMEI、MAC、Android ID、OAID、IDFA、OpenUDID、GUID、SIM 卡 IMSI 等）、网络状态与设备标识。高级运营分析依赖库还会处理应用列表和地理位置相关信息。")
    val guideRiskTitle = ArbText("guideRiskTitle", "免责与风险提示")
    val guideRiskParagraph1 = ArbText("guideRiskParagraph1", "1. 超级岛、焦点通知、后台提醒和保活效果受外部条件限制。各设备表现无法完全一致。限制条件包括系统版本、机型、厂商策略、权限、自启动和电池策略。")
    val guideRiskParagraph2 = ArbText("guideRiskParagraph2", "2. 检查更新、镜像下载、系统下载器、导入导出与分享，依赖三类外部条件：网络环境、第三方服务和系统文件能力。若出现失败、限速或文件异常，请以 Release 页面、你自己保存的备份文件和系统提示为准。")
    val guideRiskParagraph3 = ArbText("guideRiskParagraph3", "3. 在迁移、导入或覆盖数据前，请先自行确认备份文件完整可用，并妥善保管含有课表信息的文件；因用户自行删除、覆盖、分享或保管不当造成的数据问题，需要由用户自行承担相应风险。")
    val guideUmengPrivacyLink = ArbText("guideUmengPrivacyLink", "友盟隐私政策：https://www.umeng.com/page/policy")
    val guidePrivacyConsentLabel = ArbText("guidePrivacyConsentLabel", "我已阅读并同意友盟相关隐私说明")
    val guidePrivacyHelperRequireConsent = ArbText("guidePrivacyHelperRequireConsent", "你勾选同意后，代表你已阅读并同意上述友盟相关说明、隐私内容与免责提示")
    val guidePrivacyHelperViewOnly = ArbText("guidePrivacyHelperViewOnly", "这里保留与首次启动一致的隐私、第三方 SDK 与免责说明，方便你随时查看；当前页面不需要再次勾选同意")

    // ── 用户指南：系统权限页 ──
    val guidePermissionsPageTitle = ArbText("guidePermissionsPageTitle", "系统权限")
    val guidePermissionsSubtitle = ArbText("guidePermissionsSubtitle", "完成这些设置，超级岛和提醒才能正常使用")
    val guidePermissionsProgressLabel = ArbText("guidePermissionsProgressLabel", "已就绪 {ready}/{total}")
    val guidePermissionsFooterHint = ArbText("guidePermissionsFooterHint", "自启动受系统限制，以系统开关为准")
    val guideStatusNotificationPermission = ArbText("guideStatusNotificationPermission", "通知权限")
    val guideStatusEnabled = ArbText("guideStatusEnabled", "已开启")
    val guideStatusDisabled = ArbText("guideStatusDisabled", "未开启")
    val guideStatusIslandSupport = ArbText("guideStatusIslandSupport", "焦点通知 / 超级岛")
    val guideStatusSystemAllowed = ArbText("guideStatusSystemAllowed", "系统已允许")
    val guideStatusEnabledPending = ArbText("guideStatusEnabledPending", "已开启但系统暂未确认")
    val guideStatusSuggestedCheck = ArbText("guideStatusSuggestedCheck", "建议检查")
    val quickActionAutoStartTitle = ArbText("quickActionAutoStartTitle", "自启动")
    val guideStatusBatteryOptimization = ArbText("guideStatusBatteryOptimization", "电池优化")
    val guideStatusBatteryUnrestricted = ArbText("guideStatusBatteryUnrestricted", "无限制")
    val guideStatusBatteryRestricted = ArbText("guideStatusBatteryRestricted", "仍受限制")
    val guideStatusKeepAlive = ArbText("guideStatusKeepAlive", "后台保活辅助")
    val guideStatusDoNotDisturbAccess = ArbText("guideStatusDoNotDisturbAccess", "勿扰模式访问权限")
    val guideStatusDoNotDisturbAccessHint = ArbText("guideStatusDoNotDisturbAccessHint", "未授权时课前静音点了没反应")
    val refreshStatusTooltip = ArbText("refreshStatusTooltip", "刷新状态")

    // ── 用户指南：个性化定制页 ──
    val guidePersonalizePageTitle = ArbText("guidePersonalizePageTitle", "个性化定制")
    val guidePersonalizeMenuStyleTitle = ArbText("guidePersonalizeMenuStyleTitle", "菜单样式")
    val homeMenuStyleList = ArbText("homeMenuStyleList", "列表菜单")
    val homeMenuStyleListSubtitle = ArbText("homeMenuStyleListSubtitle", "锚定列表，可自定义")
    val homeMenuStyleGrid = ArbText("homeMenuStyleGrid", "八宫格菜单")
    val homeMenuStyleGridSubtitle = ArbText("homeMenuStyleGridSubtitle", "图标瓷贴，可自定义")
    val frostedGlassModeLabel = ArbText("frostedGlassModeLabel", "默认材质")
    val frostedGlassModeLiquid = ArbText("frostedGlassModeLiquid", "液态玻璃")
    val guidePersonalizeVisualEffectSolid = ArbText("guidePersonalizeVisualEffectSolid", "实体卡片")
    val guideVisualEffectLiquidDesc = ArbText("guideVisualEffectLiquidDesc", "液态玻璃折射，更具质感")
    val guideVisualEffectSolidDesc = ArbText("guideVisualEffectSolidDesc", "顶栏、玻璃坞与课程卡片回到实体，最省性能；弹窗等固定小件保持玻璃")
    val guideVisualEffectWallpaperHint = ArbText("guideVisualEffectWallpaperHint", "玻璃材质配上首页壁纸后效果更明显")
    val guidePersonalizeThemeModeTitle = ArbText("guidePersonalizeThemeModeTitle", "深浅色模式")
    val guidePersonalizeSeedColorTitle = ArbText("guidePersonalizeSeedColorTitle", "主题色")

    // ── 用户指南：使用技巧页与底部按钮 ──
    val guideTipsPageTitle = ArbText("guideTipsPageTitle", "使用技巧")
    val guideShortNameAdviceTitle = ArbText("guideShortNameAdviceTitle", "课程简称建议")
    val guideShortNameAdviceSubtitle = ArbText("guideShortNameAdviceSubtitle", "简称需在课程编辑中手动填写，建议 3 字以内，显示更稳定")
    val guideShortNameRecommended = ArbText("guideShortNameRecommended", "推荐示例")
    val guideShortNameRecommendedExample = ArbText("guideShortNameRecommendedExample", "高数 / 概率 / 数控")
    val guideShortNameNotRecommended = ArbText("guideShortNameNotRecommended", "不推荐")
    val guideShortNameNotRecommendedExample = ArbText("guideShortNameNotRecommendedExample", "高等数学A(1) / 数控技术及应用")
    val guideSetCourseShortNameAction = ArbText("guideSetCourseShortNameAction", "去设置课程简称")
    val guideImportMethodsTitle = ArbText("guideImportMethodsTitle", "课表导入方式")
    val guideImportMethodsSubtitle = ArbText("guideImportMethodsSubtitle", "当前版本已经支持部分学校的教务系统网页登录导入；如果你的学校还没适配，也还有其他迁移方式")
    val guideImportMethodStep1 = ArbText("guideImportMethodStep1", "建议进入 导入课程 > 教务系统导入，选择学校并在应用内登录完成导入。")
    val guideImportMethodStep2 = ArbText("guideImportMethodStep2", "如果你的学校暂时没有适配，可以先在其他课表应用里导入教务系统课程，再导出日历格式，最后回到本应用导入。")
    val guideImportMethodStep3 = ArbText("guideImportMethodStep3", "如果别人已经在用本应用，也可以让对方导出完整备份文件，你直接导入就能恢复课程和设置。")
    val guideImportMethodExtra = ArbText("guideImportMethodExtra", "如果你会抓包、网页调试或 JavaScript，也欢迎参与学校教务适配补充，让更多学校能直接导入。")
    val guideFinalTipsTitle = ArbText("guideFinalTipsTitle", "最后再看这 3 条")
    val guideFinalTip1 = ArbText("guideFinalTip1", "1. HyperOS 3.0.300 及以上才支持超级岛；如果系统版本不够，应用仍可正常发普通提醒。")
    val guideFinalTip2 = ArbText("guideFinalTip2", "2. 可在设置中调整上课前弹出与课中提醒时间。")
    val guideFinalTip3 = ArbText("guideFinalTip3", "3. 完成系统权限设置后，再用测试通知验证；如果超级岛还是偶尔消失，优先检查自启动和省电策略。")
    val exitAppAction = ArbText("exitAppAction", "退出应用")
    val guidePrevButton = ArbText("guidePrevButton", "上一步")
    val guideNextButton = ArbText("guideNextButton", "下一步")
    val agreeAndStartAction = ArbText("agreeAndStartAction", "同意并开始使用")
    val gotItAction = ArbText("gotItAction", "知道了")

    // ── 更多功能与搜索 (MoreFeaturesScreen & Overlay) ──
    val homeMenuMoreTitle = ArbText("homeMenuMoreTitle", "全部功能")
    val homeMenuMoreSearchHint = ArbText("homeMenuMoreSearchHint", "搜功能，如 外观、导入、小组件")
    val homeMenuMoreSearchEmptyTitle = ArbText("homeMenuMoreSearchEmptyTitle", "没找到")
    val homeMenuMoreSearchEmptyHint = ArbText("homeMenuMoreSearchEmptyHint", "换个词试试，或去课表设置里找")

    val settingsTimetableSectionTitle = ArbText("settingsTimetableSectionTitle", "课表")
    val settingsDisplayAppearanceSectionTitle = ArbText("settingsDisplayAppearanceSectionTitle", "课表显示")
    val settingsReminderDesktopSectionTitle = ArbText("settingsReminderDesktopSectionTitle", "提醒与桌面")
    val settingsAppSectionTitle = ArbText("settingsAppSectionTitle", "应用")
    val settingsDataShareSectionTitle = ArbText("settingsDataShareSectionTitle", "数据与共享")
    val settingsAboutSectionTitle = ArbText("settingsAboutSectionTitle", "关于")
    val appearanceEditorEntrySubtitle = ArbText("appearanceEditorEntrySubtitle", "整页微缩预览，改壁纸与材质")

    // ── 候选目录条目标题 ──
    val homeMenuUpdateTitle = ArbText("homeMenuUpdateTitle", "版本更新")
    val pickupCodeEntryTitle = ArbText("pickupCodeEntryTitle", "取件码")
    val homeMenuOverviewTitle = ArbText("homeMenuOverviewTitle", "课程总览")
    val homeMenuStatisticsTitle = ArbText("homeMenuStatisticsTitle", "课程统计")
    val homeMenuAddCourseTitle = ArbText("homeMenuAddCourseTitle", "添加")
    val examListTitle = ArbText("examListTitle", "考试安排")
    val homeMenuImportTitle = ArbText("homeMenuImportTitle", "导入课程")
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

    // ── HyperOS 组件展示页 ──
    val hyperosShowcaseTitle = ArbText("hyperosShowcaseTitle", "澎湃 UI 组件库")
    val hyperosShowcaseSectionSummary = ArbText("hyperosShowcaseSectionSummary", "概要卡片")
    val hyperosShowcaseKitSubtitle = ArbText("hyperosShowcaseKitSubtitle", "mikcb 澎湃风格组件一览")
    val hyperosShowcaseSectionTags = ArbText("hyperosShowcaseSectionTags", "标签、手风琴、提示")
    val hyperosShowcaseAccordionSection1 = ArbText("hyperosShowcaseAccordionSection1", "第一节")
    val hyperosShowcaseAccordionSection1Body = ArbText("hyperosShowcaseAccordionSection1Body", "展开后显示的内容区域")
    val hyperosShowcaseAccordionSection2 = ArbText("hyperosShowcaseAccordionSection2", "第二节")
    val hyperosShowcaseAccordionSection2Body = ArbText("hyperosShowcaseAccordionSection2Body", "可折叠分组，替代 FAccordion")
    val hyperosShowcaseSizeSmall = ArbText("hyperosShowcaseSizeSmall", "小")
    val hyperosShowcaseSizeMedium = ArbText("hyperosShowcaseSizeMedium", "中")
    val hyperosShowcaseSizeLarge = ArbText("hyperosShowcaseSizeLarge", "大")
    val hyperosShowcaseSampleText = ArbText("hyperosShowcaseSampleText", "示例文本")
    val hyperosShowcaseSectionControls = ArbText("hyperosShowcaseSectionControls", "控件卡片")
    val hyperosShowcaseSectionInput = ArbText("hyperosShowcaseSectionInput", "输入")
    val hyperosShowcaseInputHint = ArbText("hyperosShowcaseInputHint", "请输入内容")
    val hyperosShowcaseSectionPicker = ArbText("hyperosShowcaseSectionPicker", "滚轮选择器")
    val hyperosShowcasePickerCurrentValue = ArbText("hyperosShowcasePickerCurrentValue", "当前值：{value}")
    val hyperosShowcaseSectionFeedback = ArbText("hyperosShowcaseSectionFeedback", "反馈 · 弹层")
    val hyperosShowcaseDialogMessage = ArbText("hyperosShowcaseDialogMessage", "系统风格对话框示例")
    val hyperosShowcaseConfirmTitle = ArbText("hyperosShowcaseConfirmTitle", "确认操作")
    val hyperosShowcaseConfirmed = ArbText("hyperosShowcaseConfirmed", "已确认")
    val hyperosShowcaseToastDescription = ArbText("hyperosShowcaseToastDescription", "带图标与副标题，App Toast 同款")

    /** 所有 ARB 条目清单，供对拍测试校验 */
    val allTexts: List<ArbText> by lazy {
        listOf(
            migrationTitle,
            migrationSafeTitle,
            migrationSafeSubtitle,
            migrationStep1Title,
            migrationStep1Subtitle,
            migrationStep2Title,
            migrationStep2Subtitle,
            migrationStep3Title,
            migrationStep3Subtitle,
            migrationNoSaveToFilesTitle,
            migrationNoSaveToFilesSubtitle,
            openingOldApp,
            openOldAppForBackup,
            backupDoneGoImport,
            startFreshWithoutMigration,
            openOldAppFailed,
            setSemesterStartDateAction,
            semesterStartDateLabel,
            currentWeekCompact,
            syncedCurrentWeekMessage,
            welcomeTitle,
            welcomeAppName,
            welcomeSubtitle,
            thirdPartyDisclaimer,
            languageSectionTitle,
            languageModeLabel,
            startUsingTitle,
            importTimetableTitle,
            importTimetableSubtitle,
            restoreBackupTitle,
            restoreBackupSubtitle,
            guidePrivacyPageTitle,
            guidePrivacyReadBeforeUse,
            guidePrivacyViewOnly,
            guidePrivacySectionTitle,
            guidePrivacyParagraph1,
            guidePrivacyParagraph2,
            guidePrivacyParagraph3,
            guidePrivacyParagraph4,
            guideRiskTitle,
            guideRiskParagraph1,
            guideRiskParagraph2,
            guideRiskParagraph3,
            guideUmengPrivacyLink,
            guidePrivacyConsentLabel,
            guidePrivacyHelperRequireConsent,
            guidePrivacyHelperViewOnly,
            guidePermissionsPageTitle,
            guidePermissionsSubtitle,
            guidePermissionsProgressLabel,
            guidePermissionsFooterHint,
            guideStatusNotificationPermission,
            guideStatusEnabled,
            guideStatusDisabled,
            guideStatusIslandSupport,
            guideStatusSystemAllowed,
            guideStatusEnabledPending,
            guideStatusSuggestedCheck,
            quickActionAutoStartTitle,
            guideStatusBatteryOptimization,
            guideStatusBatteryUnrestricted,
            guideStatusBatteryRestricted,
            guideStatusKeepAlive,
            guideStatusDoNotDisturbAccess,
            guideStatusDoNotDisturbAccessHint,
            refreshStatusTooltip,
            guidePersonalizePageTitle,
            guidePersonalizeMenuStyleTitle,
            homeMenuStyleList,
            homeMenuStyleListSubtitle,
            homeMenuStyleGrid,
            homeMenuStyleGridSubtitle,
            frostedGlassModeLabel,
            frostedGlassModeLiquid,
            guidePersonalizeVisualEffectSolid,
            guideVisualEffectLiquidDesc,
            guideVisualEffectSolidDesc,
            guideVisualEffectWallpaperHint,
            guidePersonalizeThemeModeTitle,
            guidePersonalizeSeedColorTitle,
            guideTipsPageTitle,
            guideShortNameAdviceTitle,
            guideShortNameAdviceSubtitle,
            guideShortNameRecommended,
            guideShortNameRecommendedExample,
            guideShortNameNotRecommended,
            guideShortNameNotRecommendedExample,
            guideSetCourseShortNameAction,
            guideImportMethodsTitle,
            guideImportMethodsSubtitle,
            guideImportMethodStep1,
            guideImportMethodStep2,
            guideImportMethodStep3,
            guideImportMethodExtra,
            guideFinalTipsTitle,
            guideFinalTip1,
            guideFinalTip2,
            guideFinalTip3,
            exitAppAction,
            guidePrevButton,
            guideNextButton,
            agreeAndStartAction,
            gotItAction,
            homeMenuMoreTitle,
            homeMenuMoreSearchHint,
            homeMenuMoreSearchEmptyTitle,
            homeMenuMoreSearchEmptyHint,
            settingsTimetableSectionTitle,
            settingsDisplayAppearanceSectionTitle,
            settingsReminderDesktopSectionTitle,
            settingsAppSectionTitle,
            settingsDataShareSectionTitle,
            settingsAboutSectionTitle,
            appearanceEditorEntrySubtitle,
            homeMenuUpdateTitle,
            pickupCodeEntryTitle,
            homeMenuOverviewTitle,
            homeMenuStatisticsTitle,
            homeMenuAddCourseTitle,
            examListTitle,
            homeMenuImportTitle,
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
            hyperosShowcaseTitle,
            hyperosShowcaseSectionSummary,
            hyperosShowcaseKitSubtitle,
            hyperosShowcaseSectionTags,
            hyperosShowcaseAccordionSection1,
            hyperosShowcaseAccordionSection1Body,
            hyperosShowcaseAccordionSection2,
            hyperosShowcaseAccordionSection2Body,
            hyperosShowcaseSizeSmall,
            hyperosShowcaseSizeMedium,
            hyperosShowcaseSizeLarge,
            hyperosShowcaseSampleText,
            hyperosShowcaseSectionControls,
            hyperosShowcaseSectionInput,
            hyperosShowcaseInputHint,
            hyperosShowcaseSectionPicker,
            hyperosShowcasePickerCurrentValue,
            hyperosShowcaseSectionFeedback,
            hyperosShowcaseDialogMessage,
            hyperosShowcaseConfirmTitle,
            hyperosShowcaseConfirmed,
            hyperosShowcaseToastDescription
        )
    }
}
