package com.mutx163.qingyu.pages.settings

/**
 * P3-B-3「行为与系统」四页的 ARB 文案（`lib/l10n/app_zh.arb`，模板语言 zh）。
 *
 * **逐字抄录，不许改写**：每一条都在 [SettingsStringsExt3ParityTest] 里与 ARB
 * 机械比对，键缺失或值被改写都会红。要改界面文字，先改 ARB（六份同步）+
 * 重新生成 `gen-l10n`，再同步这里。
 *
 * ## 为什么另起一个文件而不是写进 `SettingsStrings.kt`
 *
 * P3-B 是 4 条泳道并行迁移（`SettingsStringsExt1..4`），共享的
 * `SettingsStrings.kt` 谁都不改——否则四个人同时写一个文件必然互相覆盖。
 * 各自的新键留在各自的 Ext 文件里，由 Lead 在合批时决定要不要合并。
 *
 * 命名与 ARB 键逐字一致（`liveSettingsTitle` 等），便于 `grep` 双向核对。
 */
object SettingsStringsExt3 {

    // ---- 共享动作与提示（被多页引用） ----

    val cancelAction = ArbText("cancelAction", "取消")
    val saveAction = ArbText("saveAction", "保存")
    val deleteAction = ArbText("deleteAction", "删除")
    val saveFailed = ArbText("saveFailed", "保存失败")
    val yesLabel = ArbText("yesLabel", "是")
    val noLabel = ArbText("noLabel", "否")

    // ---- 实时活动 · 设置首页（`settings_live.dart:49-166`） ----

    val liveSettingsTitle = ArbText("liveSettingsTitle", "超级岛与通知")
    val liveGroupReminders = ArbText("liveGroupReminders", "提醒")
    val liveReminderTimingTitle = ArbText("liveReminderTimingTitle", "提醒时段")
    val liveGroupDisplay = ArbText("liveGroupDisplay", "显示内容")
    val beforeClassDisplaySettingsTitle = ArbText("beforeClassDisplaySettingsTitle", "上课前提醒显示")
    val duringEndDisplaySettingsTitle = ArbText("duringEndDisplaySettingsTitle", "课中与下课提醒显示")
    val followBeforeClassSetting = ArbText("followBeforeClassSetting", "跟随上课前提醒")
    val liveGroupMaintenance = ArbText("liveGroupMaintenance", "维护与自检")
    val liveKeepAliveTitle = ArbText("liveKeepAliveTitle", "后台保活")
    val liveSelfCheckTitle = ArbText("liveSelfCheckTitle", "自检")

    // ---- 实时活动 · 显示摘要（`settings_shared.dart:133-161`） ----

    val liveDisplaySummaryShortName = ArbText("liveDisplaySummaryShortName", "简称")
    val liveDisplaySummaryCourseName = ArbText("liveDisplaySummaryCourseName", "课程名")
    val liveDisplaySummaryLocation = ArbText("liveDisplaySummaryLocation", "地点")
    val liveDisplaySummaryCountdownShort = ArbText("liveDisplaySummaryCountdownShort", "倒计时")
    val liveDisplaySummaryStageText = ArbText("liveDisplaySummaryStageText", "阶段文字")
    val liveDisplaySummaryLeftLabelImage = ArbText("liveDisplaySummaryLeftLabelImage", "图标")
    val liveDisplaySummaryMinimal = ArbText("liveDisplaySummaryMinimal", "最简显示")
    val liveDisplaySummaryMore = ArbText("liveDisplaySummaryMore", "{first} 等 {count} 项")

    // ---- 实时活动 · 自检页 · 假期覆盖与测试会话（`:713-832`） ----

    val liveTestingHolidayOverride = ArbText("liveTestingHolidayOverride", "假期状态覆盖")
    val liveTestingHolidayModeEnabled = ArbText("liveTestingHolidayModeEnabled", "假期模式已开启")
    val liveTestingHolidayModeDisabled = ArbText("liveTestingHolidayModeDisabled", "假期模式已关闭")
    val liveTestingHolidayModeEnabledDesc = ArbText("liveTestingHolidayModeEnabledDesc", "课程提醒和小组件将隐藏所有课程")
    val liveTestingHolidayOverridePurpose = ArbText("liveTestingHolidayOverridePurpose", "用于测试提醒和小组件是否正确隐藏课程")
    val liveTestingNotificationTitle = ArbText("liveTestingNotificationTitle", "测试通知")
    val liveTestingNotificationSubtitle = ArbText("liveTestingNotificationSubtitle", "验证超级岛与通知栏的显示效果")
    val liveTestingSessionRunning = ArbText("liveTestingSessionRunning", "自检测试进行中")
    val liveTestingStartAction = ArbText("liveTestingStartAction", "开始测试")
    val liveTestingCancelAction = ArbText("liveTestingCancelAction", "取消测试")
    val liveTestingSessionCanceled = ArbText("liveTestingSessionCanceled", "已取消自检测试")
    val liveTestingCourseTestActiveChip = ArbText("liveTestingCourseTestActiveChip", "选课测试中 · {course}")
    val liveTestingCourseTestAction = ArbText("liveTestingCourseTestAction", "选课测试")
    val liveTestingCourseTestStopAction = ArbText("liveTestingCourseTestStopAction", "停止测试")
    val liveTestingCourseTestStoppedToast = ArbText("liveTestingCourseTestStoppedToast", "已停止超级岛测试")
    val liveTestingCourseTestPickerTitle = ArbText("liveTestingCourseTestPickerTitle", "选择要测试的课程")
    val liveTestingCourseTestStageTitle = ArbText("liveTestingCourseTestStageTitle", "选择要预览的阶段")
    val liveTestingCourseTestStageBeforeClass = ArbText("liveTestingCourseTestStageBeforeClass", "课前倒计时")
    val liveTestingCourseTestStageDuringClass = ArbText("liveTestingCourseTestStageDuringClass", "上课中")
    val liveTestingNoCourseAvailable = ArbText("liveTestingNoCourseAvailable", "当前没有可测试的课程")
    val liveTestingCrashAction = ArbText("liveTestingCrashAction", "崩溃测试")
    val liveTestingAnrAction = ArbText("liveTestingAnrAction", "异常卡顿测试")
    val liveTestingCrashSoon = ArbText("liveTestingCrashSoon", "即将触发友盟 U-APM 测试崩溃，请重新打开应用查看后台是否收到上报")
    val liveTestingAnrSoon = ArbText("liveTestingAnrSoon", "即将触发约 30 秒主线程卡死，请脱离 flutter run 测试，并在卡死后重新打开应用查看友盟后台")

    // ---- 实时活动 · 自检页 · 上岛状态诊断（`:833-984`） ----

    val liveTestingIslandStatusTitle = ArbText("liveTestingIslandStatusTitle", "上岛状态诊断")
    val pleaseSetSemesterStartDate = ArbText("pleaseSetSemesterStartDate", "请先在课表设置里填写开学日期")
    val liveTestingServiceStatusRunning = ArbText("liveTestingServiceStatusRunning", "服务运行中")
    val liveTestingServiceStatusStopped = ArbText("liveTestingServiceStatusStopped", "服务未运行")
    val liveTestingNoIslandReasonTitle = ArbText("liveTestingNoIslandReasonTitle", "不上岛原因")
    val liveTestingNoIslandReasonEmpty = ArbText("liveTestingNoIslandReasonEmpty", "当前无拦截原因")
    val liveTestingHolidayHidden = ArbText("liveTestingHolidayHidden", "当前处于假期范围，超级岛在假期期间不显示")
    val liveTestingRefreshAction = ArbText("liveTestingRefreshAction", "刷新诊断")
    val liveTestingRefreshing = ArbText("liveTestingRefreshing", "刷新中")
    val liveTestingExportAction = ArbText("liveTestingExportAction", "导出并分享日志")
    val liveTestingExporting = ArbText("liveTestingExporting", "导出中")
    val liveTestingAutoRefreshTitle = ArbText("liveTestingAutoRefreshTitle", "自动刷新")
    val liveTestingAutoRefreshOn = ArbText("liveTestingAutoRefreshOn", "每 {seconds} 秒自动拉取一次诊断状态")
    val liveTestingAutoRefreshOffReason = ArbText("liveTestingAutoRefreshOffReason", "便于稳定查看当前状态")
    val liveTestingRefreshedAt = ArbText("liveTestingRefreshedAt", "上次刷新：{time}")
    val liveTestingNotRefreshed = ArbText("liveTestingNotRefreshed", "尚未刷新")
    val liveDiagnosticsNothingToExport = ArbText("liveDiagnosticsNothingToExport", "当前没有可导出的日志文件，也没有可导出的状态快照")
    val liveDiagnosticsCleared = ArbText("liveDiagnosticsCleared", "已清空应用日志")
    val liveDiagnosticsClearFailed = ArbText("liveDiagnosticsClearFailed", "清空应用日志失败")
    val liveDiagnosticsShareText = ArbText("liveDiagnosticsShareText", "轻屿课表超级岛运行日志，用于排查不显示等问题")
    val liveDiagnosticsShareSubject = ArbText("liveDiagnosticsShareSubject", "轻屿课表 - 超级岛日志")
    val liveDiagnosticsSnapshotShareText = ArbText("liveDiagnosticsSnapshotShareText", "轻屿课表超级岛状态快照，用于排查不显示等问题")
    val liveDiagnosticsSnapshotShareSubject = ArbText("liveDiagnosticsSnapshotShareSubject", "轻屿课表 - 超级岛状态快照")

    // ---- 实时活动 · 自检页 · 时间校正（`:985-1040`） ----

    val timeCorrectionTitle = ArbText("timeCorrectionTitle", "铃声时间矫正")
    val timeCorrectionLabel = ArbText("timeCorrectionLabel", "铃声时间矫正：{value}")
    val timeCorrectionHelp = ArbText("timeCorrectionHelp", "铃声比课表快则提前，慢则延后")
    val liveTimeCorrectionNone = ArbText("liveTimeCorrectionNone", "不矫正")
    val liveTimeCorrectionDelay = ArbText("liveTimeCorrectionDelay", "整体延后 {seconds} 秒")
    val liveTimeCorrectionAdvance = ArbText("liveTimeCorrectionAdvance", "整体提前 {seconds} 秒")

    // ---- 实时活动 · 自检页 · 八张诊断卡（`:1041-1114`） ----

    val liveTestingSectionEnvironment = ArbText("liveTestingSectionEnvironment", "环境与权限")
    val liveTestingSectionService = ArbText("liveTestingSectionService", "服务状态")
    val liveTestingSectionCourse = ArbText("liveTestingSectionCourse", "课程数据")
    val liveTestingSectionTiming = ArbText("liveTestingSectionTiming", "时间与阶段")
    val liveTestingSectionSwitches = ArbText("liveTestingSectionSwitches", "阶段开关")
    val liveTestingSectionDisplay = ArbText("liveTestingSectionDisplay", "岛显示配置")
    val liveTestingSectionNotification = ArbText("liveTestingSectionNotification", "通知判定结果")
    val liveTestingSectionRecentLogs = ArbText("liveTestingSectionRecentLogs", "最近诊断日志")

    // ---- 实时活动 · 自检页 · 原始 JSON 与本地日志（`:1115-1183`） ----

    val liveTestingExpandRawJson = ArbText("liveTestingExpandRawJson", "展开原始 JSON")
    val liveTestingExpandRawJsonSubtitle = ArbText("liveTestingExpandRawJsonSubtitle", "避免大段原始字段一直占满页面")
    val liveTestingLocalLogsTitle = ArbText("liveTestingLocalLogsTitle", "本地诊断日志")
    val liveTestingClearLogsAction = ArbText("liveTestingClearLogsAction", "清空日志")
    val liveTestingClearingLogs = ArbText("liveTestingClearingLogs", "清空中")
    val liveTestingViewPhoneLogsAction = ArbText("liveTestingViewPhoneLogsAction", "查看手机日志")
    val liveTestingMoreTesterOptionsAction = ArbText("liveTestingMoreTesterOptionsAction", "更多测试者选项")

    // ---- 节假日标记（`settings_holiday.dart`） ----

    val holidaySettingsTitle = ArbText("holidaySettingsTitle", "节假日标记")
    val holidayEnableTitle = ArbText("holidayEnableTitle", "启用节假日标记")
    val holidayEnableSubtitle = ArbText("holidayEnableSubtitle", "标记法定节假日和调休补班日")
    val customHolidayTitle = ArbText("customHolidayTitle", "自定义假期")
    val customHolidayCorrupted = ArbText("customHolidayCorrupted", "读取异常，暂停读写防丢")
    val customHolidayEmpty = ArbText("customHolidayEmpty", "暂无自定义假期")
    val customHolidayAdd = ArbText("customHolidayAdd", "添加假期")
    val customHolidayEdit = ArbText("customHolidayEdit", "编辑假期")
    val customHolidayDelete = ArbText("customHolidayDelete", "删除")
    val customHolidayDeleteConfirm = ArbText("customHolidayDeleteConfirm", "确定删除这个自定义假期吗？")
    val customHolidayNameLabel = ArbText("customHolidayNameLabel", "假期名称")
    val customHolidayNameRequired = ArbText("customHolidayNameRequired", "请输入假期名称")
    val customHolidayStartDate = ArbText("customHolidayStartDate", "开始日期")
    val customHolidayEndDate = ArbText("customHolidayEndDate", "结束日期")
    val customHolidayType = ArbText("customHolidayType", "类型")
    val customHolidayTypeVacation = ArbText("customHolidayTypeVacation", "假期")
    val customHolidayTypeWorkday = ArbText("customHolidayTypeWorkday", "调休上班")
    val holidayNoUpcoming = ArbText("holidayNoUpcoming", "近期没有节假日")
    val holidayDataYearLabel = ArbText("holidayDataYearLabel", "{year} 年法定节假日")
    val holidayDateSameDay = ArbText("holidayDateSameDay", "{month} 月 {day} 日")
    val holidayDateSameMonth = ArbText("holidayDateSameMonth", "{month} 月 {start} 日～{end} 日")
    val holidayDateDiffMonth = ArbText("holidayDateDiffMonth", "{startMonth} 月 {startDay} 日～{endMonth} 月 {endDay} 日")
    val holidayMakeupWorkday = ArbText("holidayMakeupWorkday", "补班")
    val holidayStatutoryLabel = ArbText("holidayStatutoryLabel", "法定节假日")
    val holidayNameNewYear = ArbText("holidayNameNewYear", "元旦")
    val holidayNameLaborDay = ArbText("holidayNameLaborDay", "劳动节")
    val holidayNameNationalDay = ArbText("holidayNameNationalDay", "国庆节")
    val holidayNameSpringFestival = ArbText("holidayNameSpringFestival", "春节")
    val holidayNameQingming = ArbText("holidayNameQingming", "清明节")
    val holidayNameDragonBoat = ArbText("holidayNameDragonBoat", "端午节")
    val holidayNameMidAutumn = ArbText("holidayNameMidAutumn", "中秋节")
    val holidayAdvancedTitle = ArbText("holidayAdvancedTitle", "节假日数据更新")
    val holidayUpdateLog = ArbText("holidayUpdateLog", "更新日志")
    val holidayCheckUpdate = ArbText("holidayCheckUpdate", "检查更新")

    // ---- 天气（`settings_weather.dart`） ----

    val weatherSettingsTitle = ArbText("weatherSettingsTitle", "天气")
    val weatherSectionSourceTitle = ArbText("weatherSectionSourceTitle", "数据来源")
    val weatherUseCurrentLocation = ArbText("weatherUseCurrentLocation", "使用当前位置")
    val weatherCityLabel = ArbText("weatherCityLabel", "城市")
    val weatherCityNotSet = ArbText("weatherCityNotSet", "未设置")
    val weatherStatusFailed = ArbText("weatherStatusFailed", "上次更新失败")
    val weatherRetryAction = ArbText("weatherRetryAction", "重试")
    val weatherAttribution = ArbText("weatherAttribution", "天气数据来自 Open-Meteo.com")
    val weatherSectionDisplayTitle = ArbText("weatherSectionDisplayTitle", "显示")
    val weatherEnableTitle = ArbText("weatherEnableTitle", "显示天气")
    val weatherEnableSubtitle = ArbText("weatherEnableSubtitle", "关闭后不再获取天气数据")
    val weatherShowOnDayCardTitle = ArbText("weatherShowOnDayCardTitle", "日视图课卡")
    val weatherShowOnWeekCardTitle = ArbText("weatherShowOnWeekCardTitle", "周视图课卡")
    val weatherShowOnWeekCardSubtitle = ArbText("weatherShowOnWeekCardSubtitle", "格子窄，只写一项，优先温度")
    val weatherShowOnSheetTitle = ArbText("weatherShowOnSheetTitle", "课程详情弹窗")
    val weatherCoverageNote = ArbText("weatherCoverageNote", "预报只覆盖未来 16 天，更远不显示")
    val weatherSectionContentTitle = ArbText("weatherSectionContentTitle", "显示内容")
    val weatherShowPhenomenonTitle = ArbText("weatherShowPhenomenonTitle", "天气现象")
    val weatherShowPhenomenonSubtitle = ArbText("weatherShowPhenomenonSubtitle", "例如 小雨、多云")
    val weatherShowTemperatureTitle = ArbText("weatherShowTemperatureTitle", "温度")
    val weatherShowProbabilityTitle = ArbText("weatherShowProbabilityTitle", "降水概率")
    val weatherShowProbabilitySubtitle = ArbText("weatherShowProbabilitySubtitle", "低于 30% 时不显示")
    val weatherLocationEstimated = ArbText("weatherLocationEstimated", "已按网络位置估算，可能不精确")

    // ---- 诊断（`settings_diagnostics.dart`） ----

    val diagnosticsEntryTitle = ArbText("diagnosticsEntryTitle", "诊断")
    val aboutAppLogsTitle = ArbText("aboutAppLogsTitle", "应用日志")
    val aboutAppLogsSubtitle = ArbText("aboutAppLogsSubtitle", "查看运行日志")
    val aboutRecordDiagnosticsTitle = ArbText("aboutRecordDiagnosticsTitle", "记录应用日志")
    val aboutRecordDiagnosticsSubtitle = ArbText("aboutRecordDiagnosticsSubtitle", "持续记录运行日志，存本机")
    val memoryStatsEntryTitle = ArbText("memoryStatsEntryTitle", "内存状态")
    val performanceSnapshotEntryTitle = ArbText("performanceSnapshotEntryTitle", "设置快照")
    val performanceSnapshotEntrySubtitle = ArbText("performanceSnapshotEntrySubtitle", "把当前设置写进应用日志")
    val performanceSnapshotEntryDone = ArbText("performanceSnapshotEntryDone", "已写入应用日志")
    val aboutLiveDiagnosticsEnabled = ArbText("aboutLiveDiagnosticsEnabled", "已开启应用日志记录")
    val aboutLiveDiagnosticsDisabled = ArbText("aboutLiveDiagnosticsDisabled", "已关闭应用日志记录")
}
