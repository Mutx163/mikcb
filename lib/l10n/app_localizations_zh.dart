// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '轻屿课表';

  @override
  String get appTitleDebug => '轻屿课表调试版';

  @override
  String get appearanceTitle => '外观与配色';

  @override
  String get previewTitle => '预览';

  @override
  String get timetableBackgroundPreview => '课表背景';

  @override
  String get displayModeTitle => '显示模式';

  @override
  String get displayModeSubtitle => '支持跟随系统、浅色模式和深色模式。';

  @override
  String get themeModeLabel => '主题模式';

  @override
  String get themeModeSystem => '跟随系统';

  @override
  String get themeModeLight => '浅色模式';

  @override
  String get themeModeDark => '深色模式';

  @override
  String get fontSectionTitle => '应用字体';

  @override
  String get fontSectionSubtitle => '支持系统默认字体和 MiSans。MiSans 不可用时会自动回退。';

  @override
  String get fontModeLabel => '字体选择';

  @override
  String get fontModeSystem => '手机默认字体';

  @override
  String get fontModeMiSans => 'MiSans（优先）';

  @override
  String get languageSectionTitle => '应用语言';

  @override
  String get languageSectionSubtitle => '可跟随系统，或手动切换到已适配语言。';

  @override
  String get languageModeLabel => '语言选择';

  @override
  String get languageModeSystem => '跟随系统';

  @override
  String get settingsTitle => '课表设置';

  @override
  String get dailyUsageSectionTitle => '日常使用';

  @override
  String get appearanceEntryTitle => '外观与配色';

  @override
  String get appearanceEntrySubtitle => '主题色、课表背景、课程卡片颜色';

  @override
  String get layoutSectionEntryTitle => '布局与节次';

  @override
  String get layoutSectionEntrySubtitle => '节次时间、行高、时间列、周末显示与卡片布局';

  @override
  String get homeWidgetEntryTitle => '桌面小组件';

  @override
  String get homeWidgetEntrySubtitle => '今日课程卡片、小组件背景与显示信息';

  @override
  String get reminderNotificationSectionTitle => '提醒与通知';

  @override
  String get userGuideEntryTitle => '使用引导与权限';

  @override
  String get userGuideEntrySubtitle => '简称建议、通知、自启动、电池策略';

  @override
  String get timetableManagementSectionTitle => '课表管理';

  @override
  String get timeSchemeEntryTitle => '时间模板';

  @override
  String get timeSchemeEntrySubtitleNoneSelected => '切换、编辑节次、复制和管理时间模板';

  @override
  String timeSchemeEntrySubtitleSelected(String name) {
    return '当前：$name · 切换、编辑节次和复制';
  }

  @override
  String get dataTransferEntryTitle => '数据备份与迁移';

  @override
  String get dataTransferEntrySubtitle => '导出完整课表文件，给别人直接导入使用';

  @override
  String get lanEditEntryTitle => '局域网编辑';

  @override
  String get lanEditEntrySubtitle => '在电脑浏览器中编辑当前课表';

  @override
  String get lanEditTitle => '局域网编辑';

  @override
  String get lanEditIntro =>
      '开启后，同一 WiFi 或手机热点下的电脑可通过浏览器编辑当前课表。数据不会上传云端，关闭后即停止访问。';

  @override
  String get lanEditStart => '开启局域网编辑';

  @override
  String get lanEditStop => '停止';

  @override
  String get lanEditStatusRunning => '编辑会话进行中';

  @override
  String get lanEditAddressLabel => '访问地址';

  @override
  String get lanEditAddressUnavailable => '未检测到局域网 IP，请确认已连接 WiFi 或已开启热点';

  @override
  String get lanEditPinLabel => 'PIN';

  @override
  String get lanEditPortLabel => '端口';

  @override
  String get lanEditCopyAddress => '复制地址';

  @override
  String get lanEditCopied => '地址已复制';

  @override
  String get lanEditHotspotHint => '如果宿舍 WiFi 无法访问，请尝试用手机开热点，再让电脑连接该热点。';

  @override
  String get lanEditQrHint => '电脑浏览器扫描上方二维码可打开控制台（链接已含 PIN，需同一局域网）。';

  @override
  String get lanEditStartFailed => '启动失败';

  @override
  String get lanEditConnectedClientsLabel => '已连接';

  @override
  String get lanEditConnectedClientsNone => '暂无';

  @override
  String lanEditConnectedClientsValue(int count) {
    return '$count 台';
  }

  @override
  String get lanEditLastActivityLabel => '最近活动';

  @override
  String get aboutSupportSectionTitle => '关于与支持';

  @override
  String get feedbackEntryTitle => '问题反馈';

  @override
  String get feedbackEntrySubtitle => 'Issue、社区渠道和建议反馈入口';

  @override
  String get aboutEntryTitle => '关于软件';

  @override
  String get aboutEntrySubtitle => '开源说明、版本更新和 GitHub 仓库';

  @override
  String get setSemesterStartDateAction => '设置开学日期';

  @override
  String get semesterStartDateAction => '开学日期';

  @override
  String get syncCurrentWeekAction => '同步当前周';

  @override
  String semesterWeekCountAction(int count) {
    return '$count 周';
  }

  @override
  String get selectSemesterWeekCountTitle => '选择学期周数';

  @override
  String get selectSemesterWeekCountSubtitle => '不同学校可按实际教学周数调整。';

  @override
  String get unifiedCourseCardColorTitle => '统一课程卡片颜色';

  @override
  String get unifiedCourseCardColorSubtitle => '关闭后继续使用每门课程自己的颜色';

  @override
  String get courseImportTitle => '导入课程';

  @override
  String get chooseImportMethodTitle => '选择导入方式';

  @override
  String get chooseImportMethodSubtitle =>
      '现在支持传统 .ics 日历导入、识图导入，以及从仓库读取适配器的教务系统导入。';

  @override
  String get importMethodIcsTitle => '.ics 日历导入';

  @override
  String get importMethodIcsSubtitle => '适合从 WakeUp 等课表应用导出的日历文件，流程最短。';

  @override
  String get importMethodIcsFooter => '进入后直接选择 .ics 文件，可追加导入或替换现有课程。';

  @override
  String get importMethodAiTitle => '识图导入';

  @override
  String get importMethodAiSubtitle => '适合直接从课表截图导入，支持 1 张或多张连续截图。';

  @override
  String get importMethodAiFooter =>
      '先复制提示词，再到豆包专家模式发送截图和提示词，把返回的 JSON 复制回来导入，最后选择开学日期。';

  @override
  String get importMethodWarehouseTitle => '教务系统导入';

  @override
  String get importMethodWarehouseSubtitle =>
      '从 qingyu_warehouse 读取学校与适配器，支持网页登录导入课程。';

  @override
  String get importMethodWarehouseFooter => '进入后选择学校和适配器，可直接打开教务网页登录并执行导入。';

  @override
  String get importMethodSpreadsheetTitle => '表格导入';

  @override
  String get importMethodSpreadsheetSubtitle =>
      '适合用 Excel/WPS 填写轻屿课表模板后导入，无需先导出 .ics。';

  @override
  String get importMethodSpreadsheetFooter =>
      '支持 .csv 与 .xlsx，可下载官方模板填写后选择文件导入。';

  @override
  String get spreadsheetImportTitle => '表格导入';

  @override
  String get spreadsheetScenarioIntro =>
      '轻屿模板按表头识别列：必填列为课程名、星期、开始节、结束节及周次；其余列为可选。可下载完整模板，也可只保留必要列。也兼容 WakeUp 7 列格式。';

  @override
  String get spreadsheetStep1Subtitle => '下载完整模板填写，或只保留必填列与上课周（或开始周+结束周）做最小导入。';

  @override
  String get spreadsheetStep2Subtitle => '填写完成后另存为 .csv 或直接保留 .xlsx。';

  @override
  String get spreadsheetStep3Subtitle => '选择文件导入；如有识别提醒会先展示，再选择追加或替换。';

  @override
  String get spreadsheetSupportedFilesSuffix => '支持 .csv 与 .xlsx（仅读取第一个工作表）。';

  @override
  String get chooseSpreadsheetFileAction => '选择表格文件';

  @override
  String get downloadSpreadsheetTemplateAction => '下载轻屿课表模板';

  @override
  String get spreadsheetImportWarningsTitle => '导入提醒';

  @override
  String get spreadsheetImportWarningsMessage => '以下行未能导入，其余课程可继续：';

  @override
  String get spreadsheetImportWarningsContinue => '继续导入';

  @override
  String get spreadsheetFormatUnrecognized =>
      '未识别表格格式，请使用轻屿课表模板；也兼容 WakeUp 等同列格式';

  @override
  String get icsImportTitle => '.ics 日历导入';

  @override
  String get applicableScenarioTitle => '适用场景';

  @override
  String get icsScenarioIntro =>
      '如果你已经能在 WakeUp 等课表应用里导入教务系统课程，再导出为 .ics 文件，这条路最稳。';

  @override
  String stepLabel(String step) {
    return '步骤 $step';
  }

  @override
  String get icsStep1Subtitle => '先在其他课表应用里导出 .ics 日历文件。';

  @override
  String get icsStep2Subtitle => '回到这里选择文件，可选“追加导入”或“替换现有”。';

  @override
  String get icsStep3Subtitle => '导入前还会让你确认开学日期，以及课表第 1 周对应校历第几周。';

  @override
  String get supportedFilesTitle => '支持的文件';

  @override
  String get supportedFilesSuffix => '文件后缀必须是 .ics。';

  @override
  String get supportedFilesImageHint => '如果你手里只有截图，不要走这里，请返回上一页选择“识图导入”。';

  @override
  String get chooseIcsFileAction => '选择 .ics 文件';

  @override
  String get timetableAppName => '轻屿课表';

  @override
  String get switchProfileHint => '点击切换课表';

  @override
  String get moreTooltip => '更多';

  @override
  String get pleaseSetSemesterStartDate => '请先在课表设置里填写开学日期';

  @override
  String get deleteScheduleTitle => '删除日程';

  @override
  String get deleteLessonTitle => '删除这节课';

  @override
  String get cancelAction => '取消';

  @override
  String get confirmAction => '确认';

  @override
  String get deleteAction => '删除';

  @override
  String deletedCourseMessage(String name) {
    return '已删除：$name';
  }

  @override
  String get deleteFailed => '删除失败';

  @override
  String get rescheduleFailed => '调课失败';

  @override
  String get timetableManagement => '课表管理';

  @override
  String weekLabel(int week) {
    return '第 $week 周';
  }

  @override
  String sectionLabel(int section) {
    return '第 $section 节';
  }

  @override
  String get feedbackTitle => '问题反馈';

  @override
  String get feedbackIntro => '如果你遇到崩溃、课程显示异常、导入问题，或者想提交功能建议，可以通过下面这些渠道反馈。';

  @override
  String get feedbackIssueHint => '涉及复现步骤、截图、版本号和日志的问题，建议优先走 GitHub Issue。';

  @override
  String get githubIssueTitle => 'GitHub Issue';

  @override
  String get githubIssueSubtitle => '打开仓库 Issue 页面，可提交问题、建议或查看已有反馈记录。';

  @override
  String get openIssuePage => '打开 Issue 页面';

  @override
  String get copyAddress => '复制地址';

  @override
  String get copiedIssueAddress => '已复制 Issue 地址';

  @override
  String get copyXiaohongshuId => '复制小红书号';

  @override
  String get copiedXiaohongshuId => '已复制小红书号';

  @override
  String get copyCoolapkId => '复制酷安号';

  @override
  String get copiedCoolapkId => '已复制酷安号';

  @override
  String get copyQqGroupId => '复制群号';

  @override
  String get copiedQqGroupId => '已复制 QQ 群号';

  @override
  String get timetableProfilesTitle => '课表管理';

  @override
  String get createTimetableTooltip => '新建课表';

  @override
  String coursesAndWeekSummary(int count, int week) {
    return '$count 门课程 · 第 $week 周';
  }

  @override
  String get moreActionsTooltip => '更多操作';

  @override
  String get switchToThisTimetable => '切换到此课表';

  @override
  String get renameAction => '重命名';

  @override
  String get duplicateAction => '复制';

  @override
  String get clearCoursesAction => '清空课程';

  @override
  String get usingNow => '正在使用';

  @override
  String switchedToProfile(String name) {
    return '已切换到 $name';
  }

  @override
  String get createTimetableTitle => '新建课表';

  @override
  String get timetableNameLabel => '课表名称';

  @override
  String get timetableNameHint => '例如：大二下';

  @override
  String get createAction => '创建';

  @override
  String createdProfile(String name) {
    return '已创建课表：$name';
  }

  @override
  String get renameTimetableTitle => '重命名课表';

  @override
  String get saveAction => '保存';

  @override
  String renamedProfile(String name) {
    return '已重命名为 $name';
  }

  @override
  String get clearCurrentTimetableTitle => '清空当前课表';

  @override
  String clearCurrentTimetableMessage(String name) {
    return '确定清空“$name”的全部课程吗？课表设置会保留。';
  }

  @override
  String get clearAction => '清空';

  @override
  String clearedProfile(String name) {
    return '已清空课表：$name';
  }

  @override
  String get noCoursesInCurrentProfile => '当前课表已经没有课程';

  @override
  String get deleteTimetableTitle => '删除课表';

  @override
  String deleteTimetableMessage(String name) {
    return '确定删除“$name”吗？';
  }

  @override
  String deletedProfile(String name) {
    return '已删除课表：$name';
  }

  @override
  String get keepAtLeastOneProfile => '至少保留一个课表';

  @override
  String get dataTransferTitle => '数据备份与迁移';

  @override
  String get fullExportTitle => '完整导出';

  @override
  String get fullExportSubtitle => '支持导出当前课表，或一次导出全部课表、时间模板和当前选中状态。';

  @override
  String get exportCurrentTimetable => '导出当前课表';

  @override
  String get exportAllData => '导出全部数据';

  @override
  String get fullImportTitle => '完整导入';

  @override
  String get fullImportSubtitle => '导入时可以选择覆盖当前课表，或直接导入为一个新课表。建议先导出自己的备份。';

  @override
  String get chooseFileAndImport => '选择文件并导入';

  @override
  String get transferOverviewTitle => '当前可迁移内容';

  @override
  String courseCountBullet(int count) {
    return '课程数量：$count 门';
  }

  @override
  String currentTimetableBullet(String name) {
    return '当前课表：$name';
  }

  @override
  String allTimetablesBullet(int count) {
    return '全部课表：$count 个';
  }

  @override
  String timeSchemeCountBullet(int count) {
    return '时间模板：$count 套';
  }

  @override
  String currentWeekBullet(int week) {
    return '当前周：第 $week 周';
  }

  @override
  String get semesterStartUnsetBullet => '开学日期：未设置';

  @override
  String semesterStartBullet(String date) {
    return '开学日期：$date';
  }

  @override
  String fileExtensionBullet(String extension) {
    return '文件后缀：.$extension';
  }

  @override
  String get selectImportModeTitle => '选择导入方式';

  @override
  String get selectImportModeMessage => '你可以覆盖当前课表，或者把备份导入成一个新的独立课表。';

  @override
  String get replaceCurrentTimetable => '覆盖当前课表';

  @override
  String get importAsNewTimetable => '导入为新课表';

  @override
  String get createdNewTimetableAfterImport => '导入成功，已创建新的课表';

  @override
  String get backupRestoredSuccess => '导入成功，备份数据已恢复';

  @override
  String get importFailedInvalidFile => '导入失败，请确认文件有效';

  @override
  String get welcomeTitle => '欢迎使用';

  @override
  String get welcomeAppName => '轻屿课表';

  @override
  String get welcomeSubtitle => '你可以先开始使用，也可以直接导入课程或从备份恢复。';

  @override
  String get startUsingTitle => '开始使用';

  @override
  String get startUsingSubtitle => '直接进入软件，并继续完成首次使用说明';

  @override
  String get importTimetableTitle => '导入课表';

  @override
  String get importTimetableSubtitle => '从 .ics 文件或 AI 解析结果导入课程';

  @override
  String get restoreBackupTitle => '从备份恢复';

  @override
  String get restoreBackupSubtitle => '从 .mikcb 备份文件恢复旧数据';

  @override
  String get viewGuideTitle => '查看功能说明';

  @override
  String get viewGuideSubtitle => '先了解权限、超级岛和基础设置';

  @override
  String get migrationTitle => '迁移旧数据';

  @override
  String get migrationSafeTitle => '别担心，这不是数据丢失';

  @override
  String get migrationSafeSubtitle =>
      '我们更换了应用包名，所以桌面上会暂时出现两个应用图标，这是正常现象。旧数据仍在旧版应用里，请先去旧版备份，再回到新版导入。';

  @override
  String get migrationStep1Title => '打开旧版应用';

  @override
  String get migrationStep1Subtitle =>
      '进入“数据备份与迁移”页面后，请点“导出全部数据”。不要点“导出当前课表”，也不要先卸载旧版。';

  @override
  String get migrationStep2Title => '保存备份文件';

  @override
  String get migrationStep2Subtitle =>
      '旧版导出后会弹出系统分享面板。优先选择“保存到文件”，建议存到 下载 / Download 文件夹。';

  @override
  String get migrationStep3Title => '回到当前版本导入';

  @override
  String get migrationStep3Subtitle =>
      '回到新版后，通过系统文件选择器到 下载 / Download 文件夹选中 .mikcb 备份文件即可恢复。确认新版数据正常后，再卸载旧版应用。';

  @override
  String get migrationNoSaveToFilesTitle => '如果没有“保存到文件”';

  @override
  String get migrationNoSaveToFilesSubtitle =>
      '可以先分享到微信任意一个聊天，然后在微信里点开这个备份文件并保存。保存后通常会出现在 Download / WeiXin 文件夹里，再回到新版选择这个 .mikcb 文件导入。';

  @override
  String get openingOldApp => '正在打开旧版...';

  @override
  String get openOldAppForBackup => '打开旧版去备份';

  @override
  String get backupDoneGoImport => '我已完成备份，去导入';

  @override
  String get startFreshWithoutMigration => '以全新应用开始，不迁移';

  @override
  String get openOldAppFailed => '未能打开旧版应用，请手动返回桌面打开旧版';

  @override
  String get supportCreatorTitle => '请作者喝杯咖啡';

  @override
  String get supportHeroTitle => '支持轻屿课表继续更新';

  @override
  String get supportHeroSubtitle => '你的支持会直接用于维护课表、教务导入适配与体验优化。';

  @override
  String get supportChipFixes => '修复问题';

  @override
  String get supportChipAdapters => '教务适配';

  @override
  String get supportChipPolish => '体验优化';

  @override
  String get supportMethodTitle => '选择支持方式';

  @override
  String get wechatLabel => '微信';

  @override
  String get alipayLabel => '支付宝';

  @override
  String get supportWeChatHint => '使用微信扫一扫支持作者';

  @override
  String get supportAlipayHint => '使用支付宝扫一扫支持作者';

  @override
  String get viewLargeImage => '查看大图';

  @override
  String get saveToGallery => '保存到相册';

  @override
  String get supportCompleteThanks => '感谢你支持轻屿课表继续打磨 ❤️';

  @override
  String get supportConfirmed => '我已经支持了';

  @override
  String get donorListTitle => '鸣谢名单';

  @override
  String get donorListLoadFailed => '暂时无法加载在线鸣谢名单。';

  @override
  String get reloadAction => '重新加载';

  @override
  String updatedAtLabel(String time) {
    return '更新于 $time';
  }

  @override
  String get donorListEmpty => '名单还没有填写，你可以直接编辑 docs/donors.json 后重新发布。';

  @override
  String get savedToGallery => '已保存到相册';

  @override
  String get saveToGalleryFailed => '保存到相册失败';

  @override
  String saveFailedWithError(String error) {
    return '保存失败：$error';
  }

  @override
  String get courseOverviewTitle => '课程总览与编辑';

  @override
  String get addNewCourseTooltip => '添加新课程';

  @override
  String get emptyCourseOverviewHint => '长按课表或点击右上角添加课程';

  @override
  String conflictDetectedMessage(int count) {
    return '检测到 $count 门排课存在实际冲突，课程列表已标记冲突项。';
  }

  @override
  String conflictCountLabel(int count) {
    return '冲突 $count 节';
  }

  @override
  String scheduledCountLabel(int count) {
    return '共排课 $count 节';
  }

  @override
  String scheduledCountWithConflictHint(int count) {
    return '共排课 $count 节 · 展开查看冲突详情';
  }

  @override
  String courseTimeSummary(int day, int start, int end) {
    return '时间: 星期$day 第$start-$end节';
  }

  @override
  String get teacherUnset => '未置';

  @override
  String get locationUnset => '未置';

  @override
  String courseDetailSummary(
    String weekDescription,
    String teacher,
    String location,
  ) {
    return '$weekDescription  教师: $teacher  教室: $location';
  }

  @override
  String courseDetailSummaryWithConflict(
    String weekDescription,
    String teacher,
    String location,
    String conflictSummary,
  ) {
    return '$weekDescription  教师: $teacher  教室: $location\n冲突课程: $conflictSummary';
  }

  @override
  String get confirmDeleteTitle => '确认删除';

  @override
  String confirmDeleteCourseMessage(String name) {
    return '确定要删除课程“$name”吗？';
  }

  @override
  String get currentScheduleTitle => '当前排课';

  @override
  String get currentScheduleSubtitle => '这里的星期、节次、教室、周次和单双周只影响当前这一条排课。';

  @override
  String get timeSchemeLabel => '上课时间方案';

  @override
  String followCurrentTimetableWithName(String name) {
    return '跟随当前课表（$name）';
  }

  @override
  String get followCurrentTimetableDescription => '默认跟随当前课表主时间模板，适合大多数课程。';

  @override
  String get overrideTimeSchemeDescription => '这门课会单独使用所选时间模板，不跟随当前课表主时间模板。';

  @override
  String get weekdayLabel => '星期';

  @override
  String get startSectionLabel => '开始节次';

  @override
  String get endSectionLabel => '结束节次';

  @override
  String timeRangeLabel(String start, String end) {
    return '时间: $start - $end';
  }

  @override
  String get locationLabel => '上课地点';

  @override
  String get singleLessonWeekTitle => '上课周次';

  @override
  String get singleLessonWeekSubtitle => '单节课只会出现在一个周次里，适合补课、临时加课。';

  @override
  String get selectWeekLabel => '选择周次';

  @override
  String get weekSettingsTitle => '周次设置';

  @override
  String get rangeWeeksLabel => '连续周';

  @override
  String get customWeeksLabel => '自定义周';

  @override
  String get startWeekLabel => '开始周';

  @override
  String get endWeekLabel => '结束周';

  @override
  String get allWeeksFilter => '全部';

  @override
  String get oddWeeksFilter => '单周';

  @override
  String get evenWeeksFilter => '双周';

  @override
  String get rangeWeeksAllHint => '按开始周到结束周连续排课。';

  @override
  String get rangeWeeksOddHint => '只保留范围内的单周。';

  @override
  String get rangeWeeksEvenHint => '只保留范围内的双周。';

  @override
  String get selectAllAction => '全选';

  @override
  String get selectOddWeeksAction => '单周';

  @override
  String get selectEvenWeeksAction => '双周';

  @override
  String selectedWeeksSummary(int count, String weeks) {
    return '已选 $count 周：第$weeks周';
  }

  @override
  String get courseColorTitle => '课程颜色';

  @override
  String get customPaletteAction => '调色盘自定义颜色';

  @override
  String get colorPaletteTitle => '调色盘';

  @override
  String get colorHexLabel => '颜色 Hex';

  @override
  String get weekdayMon => '周一';

  @override
  String get weekdayTue => '周二';

  @override
  String get weekdayWed => '周三';

  @override
  String get weekdayThu => '周四';

  @override
  String get weekdayFri => '周五';

  @override
  String get weekdaySat => '周六';

  @override
  String get weekdaySun => '周日';

  @override
  String hueLabel(int value) {
    return '色相 $value';
  }

  @override
  String saturationLabel(int value) {
    return '饱和度 $value%';
  }

  @override
  String brightnessLabel(int value) {
    return '明度 $value%';
  }

  @override
  String get useThisColor => '使用这个颜色';

  @override
  String get selectAtLeastOneWeek => '请至少选择一个上课周次';

  @override
  String get saveFailed => '保存失败';

  @override
  String get courseAddedSuccess => '课程添加成功';

  @override
  String get courseUpdatedSuccess => '课程更新成功';

  @override
  String get aboutTitle => '关于软件';

  @override
  String get loadingText => '读取中';

  @override
  String versionLabel(String version) {
    return '版本 $version';
  }

  @override
  String get aboutHeroSubtitle =>
      '一个围绕课表查看、课程提醒和 HyperOS 超级岛体验打磨的 Android 开源项目。';

  @override
  String get platformLabel => '平台';

  @override
  String get focusLabel => '重点';

  @override
  String get updateLabel => '更新';

  @override
  String get prereleaseIncluded => '含预发布';

  @override
  String get stableOnly => '正式版';

  @override
  String get aboutUpdatesTitle => '版本更新';

  @override
  String get aboutUpdatesSubtitle => '检查更新、立即下载，以及测试与诊断入口';

  @override
  String get aboutChangelogTitle => '更新日志';

  @override
  String get aboutChangelogSubtitle => '查看所有版本的更新内容';

  @override
  String get aboutPositioningTitle => '项目定位';

  @override
  String get aboutPositioningSubtitle => '这是什么、适合谁、核心能力是什么';

  @override
  String get aboutPositioningBullet1 => '支持周视图课表、课程增删改、.ics 导入';

  @override
  String get aboutPositioningBullet2 => '已支持适配学校的教务系统网页登录导入与完整备份迁移';

  @override
  String get aboutPositioningBullet3 =>
      '支持实时通知；HyperOS 3.0.300 起支持超级岛 / 焦点通知展示';

  @override
  String get aboutPositioningBullet4 => '支持多课表、时间模板、主题色和卡片样式自定义';

  @override
  String get aboutImportMigrationTitle => '导入与迁移';

  @override
  String get aboutImportMigrationSubtitle => '当前导入方式、备份恢复和迁移建议';

  @override
  String get aboutImportMigrationBullet1 =>
      '当前版本已经支持适配学校的教务系统网页登录导入；进入“导入课程 > 教务系统导入”后选择学校和适配器即可。';

  @override
  String get aboutImportMigrationBullet2 =>
      '如果你的学校暂时还没适配，仍然可以先在 WakeUp 等课表应用里导入课程，再导出为日历格式，然后在本应用导入。';

  @override
  String get aboutImportMigrationBullet3 =>
      '如果其他人已经在用本应用，也可以直接让对方导出完整备份文件，你在“数据备份与迁移”里导入即可直接恢复。';

  @override
  String get aboutImportMigrationBullet4 =>
      '如果你会抓包、网页调试或 JavaScript，也欢迎去 qingyu_warehouse 参与教务适配补充。';

  @override
  String get aboutContributorsTitle => '代码贡献者';

  @override
  String get aboutContributorsSubtitle => '开发人员与教务导入适配者名单';

  @override
  String get aboutRepositoryTitle => '开源仓库';

  @override
  String get aboutAppLogsTitle => '应用日志';

  @override
  String get aboutAppLogsSubtitle =>
      '查看整个软件的 error / warn / info / debug / verbose 全等级日志';

  @override
  String get appLogsShareText =>
      '这是轻屿课表导出的应用日志，包含整个软件的本地运行记录，可用于排查更新、导入、通知、页面和崩溃问题。';

  @override
  String get appLogsShareSubject => '轻屿课表 - 应用日志';

  @override
  String get appLogsRecordingEnabled => '正在记录应用日志';

  @override
  String get appLogsRecordingDisabled => '应用日志记录已关闭';

  @override
  String get appLogsCopyAction => '复制日志';

  @override
  String get appLogsCopied => '已复制当前日志';

  @override
  String get appLogsExportAction => '导出日志';

  @override
  String get appLogsClearAction => '清空日志';

  @override
  String get appLogsCleared => '已清空应用日志';

  @override
  String get appLogsClearFailed => '清空应用日志失败';

  @override
  String get aboutRepositorySubtitle => 'GitHub 仓库地址、源码、Release 和反馈入口';

  @override
  String get timeSchemeTitle => '时间模板';

  @override
  String get newSchemeTooltip => '新建模板';

  @override
  String timeSchemeSummary(
    int sections,
    int profiles,
    int courses,
    int overrideCourses,
  ) {
    return '$sections 节 · $profiles 个课表 · $courses 节课程 · $overrideCourses 节副时间表';
  }

  @override
  String get viewUsageAction => '查看使用情况';

  @override
  String get applyToCurrentTimetable => '应用到当前课表';

  @override
  String get editSectionsAction => '编辑节次';

  @override
  String get createTimeSchemeTitle => '新建时间模板';

  @override
  String get timeSchemeNameLabel => '模板名称';

  @override
  String get timeSchemeNameHint => '例如：本校夏季作息';

  @override
  String get renameTimeSchemeTitle => '重命名时间模板';

  @override
  String renamedToMessage(String name) {
    return '已重命名为 $name';
  }

  @override
  String get deleteTimeSchemeTitle => '删除时间模板';

  @override
  String deleteTimeSchemeMessage(String name) {
    return '确定删除“$name”吗？正在使用中的模板不能删除。';
  }

  @override
  String deletedTimeSchemeMessage(String name) {
    return '已删除时间模板：$name';
  }

  @override
  String get timeSchemeInUseMessage => '该模板正在被课表使用';

  @override
  String get copiedTimeSchemeMessage => '已复制时间模板';

  @override
  String appliedTimeSchemeMessage(String name) {
    return '已应用时间模板：$name';
  }

  @override
  String timeSchemeUsageTitle(String name) {
    return '“$name”的使用情况';
  }

  @override
  String get timeSchemeUsageIntro => '先看总影响范围，再决定是直接编辑这套模板，还是先复制一套再改。';

  @override
  String get profileCountLabel => '课表';

  @override
  String get courseCountLabel => '课程';

  @override
  String get overrideTimeSchemeLabel => '副时间表';

  @override
  String get directlyBoundProfilesTitle => '直接绑定这套模板的课表';

  @override
  String get directlyBoundProfilesEmpty => '当前没有课表直接使用这套模板。';

  @override
  String get directlyBoundProfilesSubtitle => '这些课表切到这套模板后，默认都会按这套节次时间显示。';

  @override
  String get followMainSchemeCoursesTitle => '跟随课表主时间表的课程';

  @override
  String get followMainSchemeCoursesEmpty => '当前没有课程通过课表主时间表间接使用它。';

  @override
  String get followMainSchemeCoursesSubtitle =>
      '这些课程没有单独设置副时间表，而是跟着所属课表一起用这套模板。';

  @override
  String get overrideSchemeCoursesTitle => '把它作为副时间表的课程';

  @override
  String get overrideSchemeCoursesEmpty => '当前没有课程把它作为副时间表。';

  @override
  String get overrideSchemeCoursesSubtitle => '这些课程即使所在课表切换了主模板，也会继续单独使用这套时间。';

  @override
  String get closeAction => '关闭';

  @override
  String get editTimeSchemeTitle => '编辑时间模板';

  @override
  String get backToSchemeList => '返回模板列表';

  @override
  String get currentInUse => '当前使用';

  @override
  String get quickGenerateAction => '快捷生成';

  @override
  String get addSectionAction => '新增一节';

  @override
  String get removeLastSectionAction => '删除末节';

  @override
  String get resetDefaultAction => '恢复默认';

  @override
  String get sectionTimesTitle => '节次时间';

  @override
  String get sectionTimesSubtitle => '如果当前课表正在使用这套模板，节次数量不能小于已使用的最大节次。';

  @override
  String get schemeListCurrentLabel => '当前';

  @override
  String get schemeListCountLabel => '数量';

  @override
  String get sectionCountLabel => '节数';

  @override
  String get quickGenerateTimeSchemeTitle => '快捷生成课表时间';

  @override
  String get addBreakRuleAction => '新增大课间规则';

  @override
  String get afterSectionLabel => '第几节后';

  @override
  String get breakDurationMinutesLabel => '休息多久(分)';

  @override
  String get fillNumbersValidationMessage => '请把节数和时长填写为数字';

  @override
  String get timeSchemeEditorActiveAndCoursesHint =>
      '当前课表和部分课程正在使用这套时间模板，保存后会同步更新所有相关课表和课程。';

  @override
  String get timeSchemeEditorActiveHint => '当前课表正在使用这套时间模板，保存后会同步更新所有使用它的课表。';

  @override
  String get timeSchemeEditorOverrideHint =>
      '有课程正在把这套模板作为副时间表使用，保存后会同步更新所有引用课程。';

  @override
  String get editTimeAction => '编辑时间';

  @override
  String editingSchemeLabel(String name) {
    return '正在编辑：$name';
  }

  @override
  String get copiedTimeSchemeShortMessage => '已复制时间模板';

  @override
  String get unnamedTimeScheme => '未命名模板';

  @override
  String get unsetLabel => '未选择';

  @override
  String get timeSchemeUsageCourseRefPrefix => '课程引用：';

  @override
  String get mainTimeSchemeLabel => '主时间表';

  @override
  String get overrideTimeSchemeShortLabel => '副时间表';

  @override
  String timeSchemeBottomUsageSingle(String first) {
    return '$first';
  }

  @override
  String timeSchemeBottomUsageMulti(String first, int count) {
    return '$first 等 $count 节课程';
  }

  @override
  String get morningSectionCountLabel => '上午几节';

  @override
  String get morningFirstSectionTimeLabel => '早上第一节时间';

  @override
  String get afternoonSectionCountLabel => '下午几节';

  @override
  String get afternoonFirstSectionTimeLabel => '下午第一节时间';

  @override
  String get eveningSectionCountLabel => '晚上几节';

  @override
  String get eveningFirstSectionTimeLabel => '晚上第一节时间';

  @override
  String get classDurationMinutesLabel => '单节课时长（分钟）';

  @override
  String get smallBreakDurationMinutesLabel => '小课间时长（分钟）';

  @override
  String get largeBreakRulesTitle => '大课间规则';

  @override
  String get noLargeBreakRulesHint => '未设置大课间规则，将全部使用小课间时长。';

  @override
  String get deleteRuleTooltip => '删除规则';

  @override
  String get generateAction => '生成';

  @override
  String get liveSettingsTitle => '超级岛与通知';

  @override
  String get liveReminderTimingEntryTitle => '提醒时段';

  @override
  String get liveReminderTimingEntrySubtitle =>
      '上课前、课中/下课提醒开关，以及下课前多久切到超级岛 / 重点提醒';

  @override
  String get liveBeforeClassDisplayEntryTitle => '上课前提醒显示';

  @override
  String get liveDuringEndDisplayEntryTitle => '课中/下课提醒显示';

  @override
  String get liveKeepAliveEntryTitle => '后台保活';

  @override
  String get liveKeepAliveEntrySubtitle => '隐藏后台、后台保活辅助服务和权限入口';

  @override
  String get liveTestingEntryTitle => '测试与诊断';

  @override
  String get liveTestingEntrySubtitle => '发送测试通知，检查超级岛和本地诊断日志';

  @override
  String get followBeforeClassSetting => '跟随上课前提醒';

  @override
  String get liveReminderTimingTitle => '提醒时段';

  @override
  String get liveReminderSwitchesTitle => '提醒开关';

  @override
  String get liveReminderSwitchesSubtitle => '不同提醒时段可以自由组合；这些开关互不替代。';

  @override
  String get beforeClassReminderTitle => '上课前提醒';

  @override
  String beforeClassReminderSubtitle(int minutes) {
    return '在课程开始前 $minutes 分钟弹出';
  }

  @override
  String get duringClassReminderTitle => '课中 / 下课提醒';

  @override
  String get duringClassReminderSubtitle => '只影响上课后到下课前的展示';

  @override
  String get liveClassReminderLeadTitle => '下课前多久切到超级岛 / 重点提醒';

  @override
  String get liveClassReminderLeadOptionImmediate => '一上课就切换';

  @override
  String liveClassReminderLeadOptionMinutes(int minutes) {
    return '下课前 $minutes 分钟切换';
  }

  @override
  String get liveDisplayModeTitle => '展示方式';

  @override
  String get liveDisplayModeSubtitle => '对已启用的提醒时段生效。';

  @override
  String get duringClassStatusNotificationTitle => '课中状态栏通知';

  @override
  String get duringClassStatusNotificationImmediate => '上课后保留状态栏通知';

  @override
  String get duringClassStatusNotificationBeforeEnd => '在下课提醒开始前保留普通通知文案';

  @override
  String get duringClassStatusNotificationPersistent =>
      '上课后持续显示普通课中通知，到下课提醒前再切换';

  @override
  String get enableIslandDisplayTitle => '支持展示超级岛/灵动岛';

  @override
  String get enableIslandDisplaySubtitle => '关闭后不会再尝试触发系统超级岛';

  @override
  String get liveTimeThresholdTitle => '时间阈值';

  @override
  String get liveTimeThresholdSubtitle =>
      '控制上课前弹出、下课前多久切到超级岛 / 重点提醒，以及最后秒级倒计时。';

  @override
  String get beforeClassPopupLabel => '上课前弹出时间';

  @override
  String beforeClassMinutesOption(int minutes) {
    return '$minutes 分钟';
  }

  @override
  String get beforeEndSecondsLabel => '下课前秒级提醒阈值';

  @override
  String beforeEndSecondsOption(int seconds) {
    return '$seconds 秒';
  }

  @override
  String timeCorrectionLabel(String value) {
    return '铃声时间矫正：$value';
  }

  @override
  String get timeCorrectionHelp => '如果学校铃声比课表快几秒，就调成提前；如果铃声慢几秒，就调成延后。';

  @override
  String get duringEndTimeDisplayLabel => '课中 / 下课提醒时间样式';

  @override
  String get duringEndTimeDisplayHelp => '控制紧凑提醒里显示最近时间还是整段总时间。';

  @override
  String get liveDisplayContentTitle => '显示内容';

  @override
  String get liveDisplayContentSubtitle => '这组设置只影响当前阶段，不会改动另一组提醒显示。';

  @override
  String get showCourseNameTitle => '显示课程名';

  @override
  String get preferShortNameTitle => '优先显示课程简称';

  @override
  String get preferShortNameSubtitle => '建议简称控制在 3 个字以内';

  @override
  String get showLocationTitle => '显示地点';

  @override
  String get showCountdownTitle => '显示倒计时';

  @override
  String get countdownFormatLabel => '倒计时格式';

  @override
  String get countdownFormatHelp => '纯分钟样式按分钟刷新，带秒样式按秒刷新';

  @override
  String get showStageTextTitle => '显示阶段状态文案';

  @override
  String get showStageTextSubtitle => '关闭倒计时后，可继续显示“即将上课 / 上课中 / 下课提醒”';

  @override
  String get hidePrefixTextTitle => '隐藏前缀文案';

  @override
  String get hidePrefixTextSubtitle => '例如隐藏“即将上课”这类前缀';

  @override
  String get beforeClassQuickActionTitle => '上课前快捷操作';

  @override
  String get beforeClassQuickActionSubtitle =>
      '只在上课前提醒的展开通知里显示。免打扰首次可能会跳到系统授权页。';

  @override
  String liveMiuiLabelSizePreview(String value) {
    return '$value';
  }

  @override
  String get liveIslandVisualTitle => '左侧图标与展开态';

  @override
  String get liveIslandVisualSubtitle => '左侧文字图、展开态大图标和自定义图片都按当前阶段单独保存。';

  @override
  String get liveMiuiLabelImageTitle => '小米岛左侧文字图标';

  @override
  String get liveMiuiLabelImageSubtitle => '仅小米手机样式生效，会把课程名或地点生成到左侧图标位。';

  @override
  String get liveMiuiLabelContentLabel => '左侧文字内容';

  @override
  String get liveMiuiLabelStyleLabel => '左侧图标样式';

  @override
  String get liveMiuiLabelLogoTitle => '左侧图标 Logo';

  @override
  String get liveMiuiLabelLogoSubtitle => '仅在“图标+文字”样式下生效；未选择时继续使用应用图标。';

  @override
  String liveMiuiLabelLogoCornerRadiusLabel(String value) {
    return '左侧图标圆角 $value';
  }

  @override
  String liveMiuiLabelFontSizeLabel(String value) {
    return '左侧文字大小 $value';
  }

  @override
  String liveMiuiLabelOffsetXLabel(String value) {
    return '左侧文字水平偏移 $value';
  }

  @override
  String liveMiuiLabelOffsetYLabel(String value) {
    return '左侧文字垂直偏移 $value';
  }

  @override
  String get liveMiuiLabelFontWeightLabel => '左侧文字粗细';

  @override
  String get liveMiuiLabelRenderQualityLabel => '左侧文字清晰度';

  @override
  String get liveMiuiExpandedIconLabel => '展开态大图标';

  @override
  String get selectImageAction => '选择图片';

  @override
  String get replaceImageAction => '更换图片';

  @override
  String get liveDisplayConfigModeTitle => '配置方式';

  @override
  String get liveDisplayConfigModeSubtitle =>
      '打开后，课中和下课提醒会完全跟随上课前提醒显示，下面的独立设置暂时不可编辑。';

  @override
  String get followBeforeClassDisplayTitle => '跟随上课前提醒设置';

  @override
  String get liveKeepAliveTitle => '后台保活';

  @override
  String get liveKeepAliveOptionsTitle => '保活选项';

  @override
  String get liveKeepAliveOptionsSubtitle => '用于提升超级岛和提醒在后台场景下的稳定性。';

  @override
  String get hideFromRecentsTitle => '从最近任务中隐藏应用';

  @override
  String get hideFromRecentsSubtitle => '开启后应用会尽量不显示在最近任务列表中。';

  @override
  String get keepAliveServiceTitle => '轻屿课表后台保活服务';

  @override
  String get keepAliveServiceEnabledSubtitle => '当前已开启。系统会保持后台保活辅助服务处于可用状态。';

  @override
  String get keepAliveServiceDisabledSubtitle =>
      '当前未开启。可进入系统无障碍设置手动打开轻屿课表后台保活服务。';

  @override
  String get goEnableAction => '去开启';

  @override
  String get layoutEntryTitle => '布局与节次';

  @override
  String get layoutEntrySubtitle => '节次时间、行高、时间列、周末显示与卡片布局';

  @override
  String get remindersSectionTitle => '提醒与通知';

  @override
  String get liveGuideEntryTitle => '使用引导与权限';

  @override
  String get liveGuideEntrySubtitle => '简称建议、通知、自启动、电池策略';

  @override
  String get managementSectionTitle => '课表管理';

  @override
  String timeSchemeEntryCurrentPrefix(String name) {
    return '当前：$name · 切换、编辑节次和复制';
  }

  @override
  String get timeSchemeEntrySubtitle => '切换、编辑节次、复制和管理时间模板';

  @override
  String semesterOverviewCurrentWeek(int current, int total) {
    return '当前第 $current 周 / 共 $total 周';
  }

  @override
  String get semesterStartUnset => '未设置开学日期';

  @override
  String semesterStartSet(String date) {
    return '开学日期：$date';
  }

  @override
  String get setSemesterStartDate => '设置开学日期';

  @override
  String get semesterStartDateLabel => '开学日期';

  @override
  String syncedCurrentWeekMessage(int week) {
    return '已同步到第 $week 周';
  }

  @override
  String get pickSemesterWeekCountTitle => '选择学期周数';

  @override
  String get pickSemesterWeekCountSubtitle => '不同学校可按实际教学周数调整。';

  @override
  String weekCountItem(int count) {
    return '$count 周';
  }

  @override
  String get diagnosticsLogIntro => '支持 Markdown 与原文两种查看方式，排查时可以直接在手机上看完整日志。';

  @override
  String get diagnosticsRawTab => '原文';

  @override
  String get diagnosticsStructuredTab => '结构化';

  @override
  String get diagnosticsLevelLabel => '等级';

  @override
  String get diagnosticsLevelAll => '全部';

  @override
  String get diagnosticsLevelError => '错误';

  @override
  String get diagnosticsLevelWarn => '警告';

  @override
  String get diagnosticsLevelInfo => '信息';

  @override
  String get diagnosticsLevelDebug => '调试';

  @override
  String get diagnosticsLevelVerbose => '详细';

  @override
  String diagnosticsShowingCount(int shown, int total) {
    return '显示 $shown / $total 条日志';
  }

  @override
  String get diagnosticsNoMatchingTitle => '当前筛选下没有日志';

  @override
  String get diagnosticsNoMatchingSubtitle => '可以切换到“全部”，或改看原文继续排查。';

  @override
  String get diagnosticsLevelInferred => '推断等级';

  @override
  String get diagnosticsRawFilteredHint => '原文视图会跟随当前等级筛选，只显示对应日志块。';

  @override
  String get diagnosticsEmptyTitle => '暂无日志';

  @override
  String get diagnosticsEmptySubtitle => '当前没有可显示的超级岛诊断日志。';

  @override
  String get diagnosticsLogTitleFallback => '超级岛诊断日志';

  @override
  String get diagnosticsDeviceInfoTitle => '设备与导出信息';

  @override
  String get diagnosticsContentTitle => '日志内容';

  @override
  String get diagnosticsRecentLogsTitle => '最近日志';

  @override
  String get diagnosticsUnknownCategory => '未分类事件';

  @override
  String get diagnosticsExportedAt => '导出时间';

  @override
  String get diagnosticsTime => '时间';

  @override
  String get diagnosticsCategory => '类别';

  @override
  String get diagnosticsMessage => '消息';

  @override
  String get diagnosticsStackTrace => '堆栈';

  @override
  String get firstUseGuideTitle => '首次使用引导';

  @override
  String get guideAndPermissionsTitle => '使用引导与权限';

  @override
  String get refreshStatusTooltip => '刷新状态';

  @override
  String get guideHeroTitle => '先把这页做完，再开始用';

  @override
  String get guideHeroSubtitle => '首屏先授权。下面还会明确说明系统版本支持、简称设置和导入方式，记得继续下滑。';

  @override
  String get guideChipPermissions => '权限准备';

  @override
  String get guideChipShortName => '简称设置';

  @override
  String get guideChipImport => '导入课表';

  @override
  String guideChipReadyCount(int count) {
    return '$count/3 已完成';
  }

  @override
  String get guideBottomReachedHint => '你已经滑到最后了，确认无误后就可以开始使用。';

  @override
  String get guideScrollHint => '向下滑动继续，下面还有 HyperOS 版本说明、权限清单、简称设置和导入方式。';

  @override
  String get guideRequestNotificationFirst => '先申请通知权限';

  @override
  String get quickSetupTitle => '首屏快速设置';

  @override
  String get quickSetupSubtitle => '先把最关键的 5 个入口放在前面，不用翻到下面再找。';

  @override
  String get quickActionNotificationsTitle => '通知设置';

  @override
  String get quickActionNotificationsSubtitle => '先确保能发通知';

  @override
  String get quickActionIslandTitle => '超级岛权限';

  @override
  String get quickActionIslandSubtitle => '检查 promoted 通知';

  @override
  String get quickActionAutoStartTitle => '自启动';

  @override
  String get quickActionAutoStartSubtitle => '避免后台被杀';

  @override
  String get quickActionBatteryTitle => '电池无限制';

  @override
  String get quickActionBatterySubtitle => '避免提醒中断';

  @override
  String get quickActionKeepAliveTitle => '后台保活辅助';

  @override
  String get quickActionKeepAliveSubtitle => '提升后台稳定性';

  @override
  String get guidePrivacyConsentLabel => '我已阅读并同意友盟相关隐私说明';

  @override
  String get guideRequireConsentHint => '请先滑到底部阅读说明，并勾选同意后开始使用。';

  @override
  String get guideContinueHint => '继续下滑查看完整引导内容。';

  @override
  String get exitAppAction => '退出应用';

  @override
  String get continueReadingAction => '继续查看';

  @override
  String get agreeAndStartAction => '同意并开始使用';

  @override
  String get startUsingAction => '开始使用';

  @override
  String get editSingleLessonTitle => '编辑单节课';

  @override
  String get editCourseTitle => '编辑课程';

  @override
  String get addSingleLessonTitle => '添加单节课';

  @override
  String get addCourseTitle => '添加课程';

  @override
  String get deleteCourseTitle => '删除课程';

  @override
  String get courseDeleted => '课程已删除';

  @override
  String get addMethodTitle => '添加方式';

  @override
  String get singleLessonLabel => '单节课';

  @override
  String get recurringLessonLabel => '多节课';

  @override
  String get singleLessonHint => '适合补课、临时加课，课程只会落在一个周次。';

  @override
  String get recurringLessonHint => '适合同一时间连续上很多周的常规课程。';

  @override
  String get sharedInfoTitle => '共享信息';

  @override
  String get sharedInfoHint => '课程名、简称、老师、课程简介、课程性质和颜色会同步到同名课程的其他排课。';

  @override
  String get reuseExistingCourseLabel => '沿用已有课程';

  @override
  String get reuseExistingCourseHelper => '选一个已有课程，自动带入课程名、老师和其他共享信息';

  @override
  String get manualInputLabel => '手动填写';

  @override
  String get noTemplateCoursesHint => '当前课表里还没有现成课程，先手动录入一门，后面临时加课就能直接选了。';

  @override
  String get courseNameLabel => '课程名称';

  @override
  String get courseNameHelper => '超级岛建议 3 个字以内，显示效果最好';

  @override
  String get pleaseEnterCourseName => '请输入课程名称';

  @override
  String get courseShortNameOptional => '课程简称 (可选)';

  @override
  String get teacherLabel => '授课教师';

  @override
  String get courseNatureLabel => '课程性质';

  @override
  String get courseDescriptionOptional => '课程简介 (可选)';

  @override
  String get currentScheduleHint => '这里的星期、节次、教室、周次和单双周只影响当前这一条排课。';

  @override
  String followProfileTimeScheme(String name) {
    return '跟随当前课表（$name）';
  }

  @override
  String get timeSchemeOverrideLabel => '上课时间方案';

  @override
  String get lessonWeeksTitle => '上课周次';

  @override
  String get singleLessonWeekHint => '单节课只会出现在一个周次里，适合补课、临时加课。';

  @override
  String get rangeWeekLabel => '连续周';

  @override
  String get customWeekLabel => '自定义周';

  @override
  String get allWeeksLabel => '全部';

  @override
  String get oddWeeksLabel => '单周';

  @override
  String get evenWeeksLabel => '双周';

  @override
  String get allWeeksHint => '按开始周到结束周连续排课。';

  @override
  String get oddWeeksHint => '只保留范围内的单周。';

  @override
  String get evenWeeksHint => '只保留范围内的双周。';

  @override
  String get customPaletteColor => '调色盘自定义颜色';

  @override
  String timeSchemeSetCountValue(int count) {
    return '$count 套';
  }

  @override
  String profileCountValue(int count) {
    return '$count 个';
  }

  @override
  String courseSectionCountValue(int count) {
    return '$count 节';
  }

  @override
  String timeSchemeStartsAt(String start) {
    return '$start 起';
  }

  @override
  String get weekdayShortMonday => '一';

  @override
  String get weekdayShortTuesday => '二';

  @override
  String get weekdayShortWednesday => '三';

  @override
  String get weekdayShortThursday => '四';

  @override
  String get weekdayShortFriday => '五';

  @override
  String get weekdayShortSaturday => '六';

  @override
  String get weekdayShortSunday => '日';

  @override
  String weekdaySectionRange(String weekday, int startSection, int endSection) {
    return '周$weekday $startSection-$endSection节';
  }

  @override
  String timeSchemeUsageReference(
    String profileName,
    String courseName,
    String weekday,
    int startSection,
    int endSection,
    String usageType,
  ) {
    return '$profileName · $courseName（周$weekday $startSection-$endSection节，$usageType）';
  }

  @override
  String weekdaySectionSummary(
    String weekday,
    int startSection,
    int endSection,
  ) {
    return '周$weekday $startSection-$endSection节';
  }

  @override
  String get timeRangeValidationNoCrossDay => '结束时间必须晚于开始时间';

  @override
  String get timeSchemeNameEmptyValidation => '时间模板名称不能为空';

  @override
  String get liveTimeCorrectionNone => '不矫正';

  @override
  String liveTimeCorrectionDelay(int seconds) {
    return '整体延后 $seconds 秒';
  }

  @override
  String liveTimeCorrectionAdvance(int seconds) {
    return '整体提前 $seconds 秒';
  }

  @override
  String liveClassReminderLeadSummaryImmediate(int seconds) {
    return '从上课开始就进入重点提醒展示，并在距下课 $seconds 秒切到秒级倒数';
  }

  @override
  String liveClassReminderLeadSummaryKeepNormal(int minutes, int seconds) {
    return '上课后先保留普通课中通知，在距下课前 $minutes 分钟切到重点提醒 / 下课提醒，并在最后 $seconds 秒切到秒级倒数';
  }

  @override
  String liveClassReminderLeadSummaryIsland(int minutes, int seconds) {
    return '在距下课前 $minutes 分钟切到超级岛 / 重点提醒，并在最后 $seconds 秒切到秒级倒数';
  }

  @override
  String liveClassReminderLeadSummaryFocused(int minutes, int seconds) {
    return '在距下课前 $minutes 分钟开始展示重点提醒，并在最后 $seconds 秒切到秒级倒数';
  }

  @override
  String get liveSettingsEntrySubtitle => '提醒时段、岛展示、通知栏和显示内容';

  @override
  String get timetableProfilesEntrySubtitle => '新建、切换、复制、重命名和删除课表';

  @override
  String get homeTitleSectionTitle => '首页标题';

  @override
  String get homeTitleSectionSubtitle => '控制首页左上角课表切换入口的样式。';

  @override
  String get homeTitleStyleLabel => '标题样式';

  @override
  String get themeSeedSectionTitle => '应用主题色';

  @override
  String get themeSeedSectionSubtitle => '影响顶部栏、强调色和全局主色调。';

  @override
  String get timetableBackgroundColorSectionTitle => '课表背景色';

  @override
  String get timetableBackgroundColorSectionSubtitle => '只作用于课表页面的大背景。';

  @override
  String get defaultTimetablePreviewName => '默认课表';

  @override
  String get beforeClassDisplaySettingsTitle => '上课前提醒显示';

  @override
  String get duringEndDisplaySettingsTitle => '课中/下课提醒显示';

  @override
  String get liveDisplaySummaryShortName => '简称';

  @override
  String get liveDisplaySummaryCourseName => '课程名';

  @override
  String get liveDisplaySummaryLocation => '地点';

  @override
  String liveDisplaySummaryCountdown(String style) {
    return '倒计时（$style）';
  }

  @override
  String get liveDisplaySummaryStageText => '阶段文字';

  @override
  String get liveDisplaySummaryLeftLabelImage => '左侧图标';

  @override
  String get liveDisplaySummaryMinimal => '最简显示';

  @override
  String get guideHyperOsChip => 'HyperOS 3.0.300+';

  @override
  String get guideStatusTitle => '当前状态';

  @override
  String get guideStatusNotificationPermission => '通知权限';

  @override
  String get guideStatusEnabled => '已开启';

  @override
  String get guideStatusDisabled => '未开启';

  @override
  String get guideStatusIslandSupport => '焦点通知 / 超级岛';

  @override
  String get guideStatusSystemAllowed => '系统已允许';

  @override
  String get guideStatusEnabledPending => '已开启但系统暂未确认';

  @override
  String get guideStatusSuggestedCheck => '建议检查';

  @override
  String get guideStatusBatteryOptimization => '电池优化';

  @override
  String get guideStatusBatteryUnrestricted => '无限制';

  @override
  String get guideStatusBatteryRestricted => '仍受限制';

  @override
  String get guideStatusKeepAlive => '后台保活辅助';

  @override
  String get guideStatusAndroidVersion => 'Android 版本';

  @override
  String get guideStatusVersionUnknown => '未识别';

  @override
  String get guideStatusIslandSystemSupport => '超级岛系统支持';

  @override
  String get guideStatusIslandSystemRequirement => '需 HyperOS 3.0.300 及以上';

  @override
  String get guideStatusIslandHint =>
      '如果你主要想用超级岛，先确认系统版本至少是 HyperOS 3.0.300，再继续把下面权限清单按顺序点完。';

  @override
  String get guidePermissionChecklistTitle => '权限清单';

  @override
  String get guidePermissionChecklistSubtitle => '按这个顺序检查，最省事，也最不容易漏。';

  @override
  String get guideChecklistRequestNotificationTitle => '申请通知权限';

  @override
  String get guideChecklistRequestNotificationSubtitle => '这是所有提醒的前提';

  @override
  String get guideChecklistOpenNotificationTitle => '打开通知设置';

  @override
  String get guideChecklistOpenNotificationSubtitle => '检查通知总开关、锁屏展示和实时通知权限';

  @override
  String get guideChecklistOpenIslandTitle => '打开焦点通知设置';

  @override
  String get guideChecklistOpenIslandSubtitle =>
      'HyperOS 3.0.300 及以上再检查 promoted / 超级岛通知';

  @override
  String get guideChecklistOpenAutoStartTitle => '打开自启动设置';

  @override
  String get guideChecklistOpenAutoStartSubtitle => '允许应用开机自启和后台常驻';

  @override
  String get guideChecklistOpenBatteryTitle => '打开电池策略设置';

  @override
  String get guideChecklistOpenBatterySubtitle => '建议改成无限制，避免上课提醒被中断';

  @override
  String get guideChecklistOpenKeepAliveTitle => '打开后台保活辅助';

  @override
  String get guideChecklistOpenKeepAliveSubtitle => '进一步提升超级岛和提醒在后台场景下的稳定性';

  @override
  String get guideShortNameAdviceTitle => '课程简称建议';

  @override
  String get guideShortNameAdviceSubtitle =>
      '超级岛支持显示课程简称。简称不是自动生成的，需要你在课程编辑里自己填写。建议控制在 3 个字以内，显示会更稳定。';

  @override
  String get guideShortNameRecommended => '推荐示例';

  @override
  String get guideShortNameNotRecommended => '不推荐';

  @override
  String get guideShortNameRecommendedExample => '高数 / 概率 / 数控';

  @override
  String get guideShortNameNotRecommendedExample => '高等数学A(1) / 数控技术及应用';

  @override
  String get guideSetCourseShortNameAction => '去设置课程简称';

  @override
  String get guideImportMethodsTitle => '课表导入方式';

  @override
  String get guideImportMethodsSubtitle =>
      '当前版本已经支持部分学校的教务系统网页登录导入；如果你的学校还没适配，也还有其他迁移方式。';

  @override
  String get guideImportMethodStep1 =>
      '优先进入“导入课程 > 教务系统导入”，选择学校和适配器后，直接在应用内打开教务网页完成导入。';

  @override
  String get guideImportMethodStep2 =>
      '如果你的学校暂时没有适配，可以先在 WakeUp 等课表应用里导入教务系统课程，再导出日历格式，最后回到本应用导入。';

  @override
  String get guideImportMethodStep3 =>
      '如果别人已经在用本应用，也可以让对方导出完整备份文件，你直接导入就能恢复课程和设置。';

  @override
  String get guideImportMethodExtra =>
      '如果你会抓包、网页调试或 JavaScript，也欢迎参与学校教务适配补充，让更多学校能直接导入。';

  @override
  String get guideFinalTipsTitle => '最后再看这 3 条';

  @override
  String get guideFinalTip1 =>
      '1. HyperOS 3.0.300 及以上才支持超级岛；如果系统版本不够，应用仍可正常发普通提醒。';

  @override
  String get guideFinalTip2 => '2. 先在设置页调整“上课前弹出”和“课中 / 临近下课提醒”的阈值。';

  @override
  String get guideFinalTip3 => '3. 完成系统权限设置后，再用测试通知验证；如果岛区还是偶尔消失，优先检查自启动和省电策略。';

  @override
  String get guidePrivacyHelperRequireConsent =>
      '你勾选同意后，代表你已阅读并同意上述友盟相关说明、隐私内容与免责提示。';

  @override
  String get guidePrivacyHelperViewOnly =>
      '这里保留与首次启动一致的隐私、第三方 SDK 与免责说明，方便你随时查看；当前页面不需要再次勾选同意。';

  @override
  String get guidePrivacySectionTitle => '隐私、第三方 SDK 与免责说明';

  @override
  String get guidePrivacyParagraph1 =>
      '本应用主体功能按本地运行方式设计，课表、时间模板、课程记录和大部分设置默认保存在你的设备本地。';

  @override
  String get guidePrivacyParagraph2 =>
      '只有在你主动使用检查更新、下载更新、导入导出等联网功能，或你勾选同意后初始化友盟相关 SDK 时，应用才会与外部服务发生数据交互。';

  @override
  String get guidePrivacyParagraph3 =>
      '本应用接入友盟移动统计 SDK、友盟应用性能监控 SDK 以及高级运营分析依赖库。它们的服务用途包括移动统计分析、应用性能监控以及高级运营分析相关能力；只有在你勾选同意后，这些 SDK 才会正式初始化。';

  @override
  String get guidePrivacyParagraph4 =>
      '按友盟官方说明，这些 SDK 可能处理的信息包括：设备信息（如 IMEI、MAC、Android ID、OAID、IDFA、OpenUDID、GUID、SIM 卡 IMSI 等）、网络状态、设备标识，以及高级运营分析依赖库涉及的应用列表和地理位置相关信息。';

  @override
  String get guideRiskTitle => '免责与风险提示';

  @override
  String get guideRiskParagraph1 =>
      '1. 超级岛、焦点通知、后台提醒和保活效果依赖系统版本、机型、厂商策略、权限、自启动、电池策略等外部条件，无法保证所有设备表现完全一致。';

  @override
  String get guideRiskParagraph2 =>
      '2. 检查更新、镜像下载、系统下载器、导入导出与分享等能力依赖网络环境、第三方服务和系统文件能力；若出现失败、限速或文件异常，请以 Release 页面、你自己保存的备份文件和系统提示为准。';

  @override
  String get guideRiskParagraph3 =>
      '3. 在迁移、导入或覆盖数据前，请先自行确认备份文件完整可用，并妥善保管含有课表信息的文件；因用户自行删除、覆盖、分享或保管不当造成的数据问题，需要由用户自行承担相应风险。';

  @override
  String get guideUmengPrivacyLink =>
      '友盟隐私政策：https://www.umeng.com/page/policy';

  @override
  String get liveDiagnosticsUnavailable => '当前还没有可查看的超级岛诊断日志';

  @override
  String get liveDiagnosticsViewerTitle => '超级岛诊断日志';

  @override
  String get liveDiagnosticsShareText => '这是轻屿课表导出的超级岛诊断日志，可用于排查“超级岛没有弹出”等问题。';

  @override
  String get liveDiagnosticsShareSubject => '轻屿课表 - 超级岛诊断日志';

  @override
  String get liveDiagnosticsSnapshotShareText =>
      '这是轻屿课表当前测试诊断页导出的超级岛状态快照，可用于排查“超级岛没有弹出”等问题。';

  @override
  String get liveDiagnosticsSnapshotShareSubject => '轻屿课表 - 超级岛状态快照';

  @override
  String get liveDiagnosticsNothingToExport => '当前没有可导出的日志文件，也没有可导出的状态快照';

  @override
  String get liveDiagnosticsCleared => '已清空超级岛诊断日志，后续会重新开始收集';

  @override
  String get liveDiagnosticsClearFailed => '清空超级岛诊断日志失败';

  @override
  String get liveTestingNotRefreshed => '尚未刷新';

  @override
  String get liveTestingTitle => '测试与诊断';

  @override
  String get liveTestingNotificationTitle => '测试通知';

  @override
  String get liveTestingNotificationSubtitle => '用于验证超级岛、通知栏和课程简称等显示效果。';

  @override
  String get liveTestingSendAction => '发送测试通知';

  @override
  String get liveTestingUmengHint => '下面两个按钮仅测试版显示，用于验证友盟 U-APM 崩溃和卡顿上报。';

  @override
  String get liveTestingCrashAction => '崩溃测试';

  @override
  String get liveTestingAnrAction => '异常卡顿测试';

  @override
  String get liveTestingIslandStatusTitle => '上岛状态诊断';

  @override
  String get liveTestingIslandStatusSubtitle => '这里直接显示原生实时服务、通知构造结果和不上岛原因。';

  @override
  String get liveTestingServiceStatusRunning => '服务运行中';

  @override
  String get liveTestingServiceStatusStopped => '服务未运行';

  @override
  String get liveTestingNoIslandReasonTitle => '不上岛原因';

  @override
  String get liveTestingNoIslandReasonEmpty => '当前无拦截原因';

  @override
  String get liveTestingRefreshAction => '刷新诊断';

  @override
  String get liveTestingRefreshing => '刷新中';

  @override
  String get liveTestingExportAction => '导出并分享日志';

  @override
  String get liveTestingExporting => '导出中';

  @override
  String get liveTestingAutoRefreshTitle => '自动刷新';

  @override
  String liveTestingAutoRefreshOn(int seconds) {
    return '每 $seconds 秒自动拉取一次诊断状态';
  }

  @override
  String get liveTestingAutoRefreshOff => '关闭后只在手动刷新时更新，便于稳定查看当前状态';

  @override
  String liveTestingRefreshedAt(String time) {
    return '上次刷新：$time';
  }

  @override
  String get liveTestingSectionEnvironment => '环境与权限';

  @override
  String get liveTestingSectionService => '服务状态';

  @override
  String get liveTestingSectionCourse => '课程数据';

  @override
  String get liveTestingSectionTiming => '时间与阶段';

  @override
  String get liveTestingSectionSwitches => '阶段开关';

  @override
  String get liveTestingSectionDisplay => '岛显示配置';

  @override
  String get liveTestingSectionNotification => '通知判定结果';

  @override
  String get liveTestingSectionRecentLogs => '最近诊断日志';

  @override
  String get liveTestingRawDataTitle => '原始调试数据';

  @override
  String get liveTestingRawDataSubtitle => '默认折叠，排查时再展开核对完整原生字段。';

  @override
  String get liveTestingExpandRawJson => '展开原始 JSON';

  @override
  String get liveTestingExpandRawJsonSubtitle => '避免大段原始字段一直占满页面';

  @override
  String get liveTestingLocalLogsTitle => '本地诊断日志';

  @override
  String get liveTestingLocalLogsSubtitle =>
      '一键导出日志文件，直接通过系统分享发给开发者；也可以清空后重新收集。';

  @override
  String get liveTestingClearLogsAction => '清空日志';

  @override
  String get liveTestingClearingLogs => '清空中';

  @override
  String get liveTestingViewPhoneLogsAction => '查看手机日志';

  @override
  String get liveTestingMoreTesterOptionsAction => '更多测试者选项';

  @override
  String get yesLabel => '是';

  @override
  String get noLabel => '否';

  @override
  String get liveTestingCurrentNativeFieldsSubtitle => '显示当前原生诊断字段。';

  @override
  String get liveTestingCrashSoon => '即将触发友盟 U-APM 测试崩溃，请重新打开应用查看后台是否收到上报';

  @override
  String get liveTestingAnrSoon =>
      '即将触发约 30 秒主线程卡死，请脱离 flutter run 测试，并在卡死后重新打开应用查看友盟后台';

  @override
  String get liveTestingNoCourseAvailable => '当前没有可测试的课程';

  @override
  String get liveTestingTestCourseNote => '此处显示备注。可以在课程编辑页进行设置。';

  @override
  String get liveTestingNotificationSent => '已发送上课提醒测试通知，约 8 秒内会进入上课前提醒阶段';

  @override
  String sendFailedWithError(String error) {
    return '发送失败: $error';
  }

  @override
  String get homeWidgetSettingsTitle => '桌面小组件';

  @override
  String get homeWidgetTodayCourseTitle => '今日课程组件';

  @override
  String get homeWidgetTodayCourseSubtitle =>
      '首批支持 2×2、2×4、4×4 三种尺寸。点击小组件会直接打开首页，课程开始和结束时会主动刷新。';

  @override
  String get homeWidgetQuickAddTitle => '快速添加到桌面';

  @override
  String get homeWidgetCheckingPinSupport => '正在检查当前桌面是否支持应用内添加小组件…';

  @override
  String get homeWidgetPinSupported => '支持的话会直接弹出系统添加确认，不是单独的权限弹窗；确认后即可固定到桌面。';

  @override
  String get homeWidgetPinUnsupported =>
      '当前桌面不支持应用内直接添加时，仍可长按桌面 → 小组件 → 轻屿课表 手动添加。';

  @override
  String get homeWidgetBackgroundStyleLabel => '背景样式';

  @override
  String get homeWidgetShowLocationTitle => '显示地点';

  @override
  String get homeWidgetShowLocationSubtitle => '关闭后，小组件次级信息会优先显示周次和课程数量。';

  @override
  String get homeWidgetShowCountdownTitle => '显示倒计时';

  @override
  String get homeWidgetShowCountdownSubtitle => '先保留刷新开关，后续会用于下一节课和上课中的剩余时间展示。';

  @override
  String get homeWidgetCountdownLeadTitle => '倒计时提前量';

  @override
  String get homeWidgetCountdownLeadSubtitle => '设置上课前多少分钟自动切换到倒计时模式。';

  @override
  String get homeWidgetCountdownLeadAlways => '始终显示';

  @override
  String homeWidgetCountdownLeadMinutes(String minutes) {
    return '上课前 $minutes 分钟';
  }

  @override
  String get widgetCountdownStyleTitle => '倒计时样式';

  @override
  String get homeWidgetHideCompletedTitle => '隐藏已上完课程';

  @override
  String get homeWidgetHideCompletedSubtitle =>
      '开启后，2×2、2×4 和 4×4 课程列表只显示还没结束的课程。';

  @override
  String get homeWidgetShowTomorrowTitle => '课后显示明日课程';

  @override
  String get homeWidgetShowTomorrowSubtitle => '开启后，今日课程全部结束时小组件自动切换显示明天的课程。';

  @override
  String get homeWidgetHeightAdjustTitle => '卡片高度微调';

  @override
  String get defaultLabel => '默认';

  @override
  String higherByValue(String value) {
    return '更高 $value';
  }

  @override
  String lowerByValue(String value) {
    return '更矮 $value';
  }

  @override
  String get homeWidgetCornerRadiusTitle => '卡片圆角';

  @override
  String get homeWidgetDescriptionTitle => '说明';

  @override
  String get homeWidgetDescriptionText =>
      '小组件目前优先展示今日课程。无课状态会保持完整卡片，不会出现空白；如果你切换课表或修改样式，桌面组件也会跟着刷新。';

  @override
  String homeWidgetPinRequested(String label) {
    return '已发起“$label”添加请求，请在系统弹窗里确认并放到桌面。';
  }

  @override
  String homeWidgetPinUnsupportedManual(String label) {
    return '当前系统桌面不支持应用内直接添加小组件，请长按桌面 → 小组件 → 轻屿课表，再手动添加“$label”。';
  }

  @override
  String get homeWidgetInvalidType => '小组件类型无效，请稍后重试。';

  @override
  String homeWidgetPinFailedManual(String label) {
    return '发起添加失败，请长按桌面 → 小组件 → 轻屿课表，再手动添加“$label”。';
  }

  @override
  String get layoutSettingsTitle => '布局与节次';

  @override
  String get layoutDensityTitle => '课表密度';

  @override
  String get layoutAutoFitHeightTitle => '自动充满屏幕高度';

  @override
  String get layoutAutoFitHeightSubtitle => '开启后会按当前节数自动铺满页面底部，不再保留下方空隙。';

  @override
  String get layoutHideWeekendsTitle => '隐藏周六周日';

  @override
  String get layoutHideWeekendsSubtitle => '开启后首页只显示周一到周五，剩余列宽会自动铺满。';

  @override
  String get layoutEnableHapticsTitle => '启用应用内震动反馈';

  @override
  String get layoutEnableHapticsSubtitle => '关闭后，页码切换等交互不再触发轻微震动。';

  @override
  String get layoutTimeColumnDisplayLabel => '首页时间列显示';

  @override
  String get layoutTimeColumnWidthLabel => '时间栏宽度';

  @override
  String get layoutBackToCurrentWeekButtonStyleLabel => '“回本周”按钮样式';

  @override
  String get layoutBackToCurrentWeekButtonStyleHelper =>
      '默认保持现在的内嵌样式；也可以改成周视图右下角的小型悬浮按钮。';

  @override
  String get layoutBackToCurrentWeekButtonStyleInline => '时间栏内嵌';

  @override
  String get layoutBackToCurrentWeekButtonStyleFloating => '右下角悬浮';

  @override
  String layoutBackToCurrentWeekButtonOpacityLabel(int value) {
    return '悬浮按钮不透明度 $value%';
  }

  @override
  String get layoutBackToCurrentWeekButtonOpacitySubtitle => '只对右下角悬浮样式生效。';

  @override
  String layoutCourseCardGapLabel(String value) {
    return '课程卡片间距 $value';
  }

  @override
  String layoutSectionHeightLabel(String value) {
    return '课表行高 $value';
  }

  @override
  String layoutCompactFontSizeLabel(String value) {
    return '紧凑字号 $value';
  }

  @override
  String layoutCourseCardFontSizeLabel(String value) {
    return '课程卡片字号 $value';
  }

  @override
  String get layoutCourseCardDisplayTitle => '课程卡片显示';

  @override
  String get layoutCourseCardDisplaySubtitle => '默认显示课程名、老师和教室；其他信息可按课表自由开关组合。';

  @override
  String get layoutShowTeacherTitle => '显示老师';

  @override
  String get layoutShowClassroomTitle => '显示教室';

  @override
  String get layoutShowTimeTitle => '显示时间';

  @override
  String get layoutShowTimeLabelsTitle => '显示上课/下课字样';

  @override
  String get layoutShowTimeLabelsSubtitle => '关闭后仅显示时间点，不显示“上课”“下课”文字。';

  @override
  String get layoutShowWeeksTitle => '显示周数';

  @override
  String get layoutShowWeeksSubtitle => '例如第 1-16 周、单双周';

  @override
  String get layoutShowDescriptionTitle => '显示课程简介';

  @override
  String get layoutShowDescriptionSubtitle => '默认关闭，空间不足时会最先被压缩';

  @override
  String get layoutShowOtherWeeksTitle => '显示非本周课程';

  @override
  String get layoutShowOtherWeeksSubtitle => '默认关闭，开启后会用灰色半透明显示不在当前周的课程';

  @override
  String get layoutVerticalAlignLabel => '垂直排版';

  @override
  String get layoutHorizontalAlignLabel => '水平排版';

  @override
  String get layoutShowConflictBadgeTitle => '首页显示冲突小胶囊';

  @override
  String get layoutShowConflictBadgeSubtitle => '关闭后，首页课表不再对冲突课程显示“冲突”小胶囊。';

  @override
  String layoutConflictOpacityLabel(int value) {
    return '冲突课程透明度 $value%';
  }

  @override
  String get layoutConflictOpacitySubtitle => '冲突课程会自动层叠显示，调低透明度后能同时看到多节课。';

  @override
  String get layoutTipsText =>
      '时间模板已移到设置首页。这里主要调课表行高、时间列、周末显示和课程卡片布局；如果你想只改当前课表的时间，先在时间模板里复制一套再应用。';

  @override
  String currentWeekCompact(int week) {
    return '$week周';
  }

  @override
  String get sampleCourseNumericalControl => '数控';

  @override
  String get sampleCourseAdvancedMath => '高数';

  @override
  String get sampleTeacherZhang => '张老师';

  @override
  String get sampleCourseEnglish => '英语';

  @override
  String get sampleTeacherLi => '李老师';

  @override
  String get aboutRepositorySheetTitle => '开源仓库';

  @override
  String get aboutRepositorySheetHint =>
      '如果你想补学校教务导入适配，建议同时查看教务适配仓 qingyu_warehouse。';

  @override
  String get aboutOpenGitHubAction => '打开 GitHub';

  @override
  String get aboutOpenWarehouseRepoAction => '打开教务适配仓';

  @override
  String get copiedRepositoryAddress => '已复制仓库地址';

  @override
  String get copiedWarehouseRepositoryAddress => '已复制教务适配仓地址';

  @override
  String get aboutUpdateScreenTitle => '版本更新';

  @override
  String get aboutUpdateStatusTitle => '更新状态';

  @override
  String get aboutRefreshCheckTooltip => '重新检查';

  @override
  String get aboutCheckingLatestVersion => '正在检查最新版本信息…';

  @override
  String get aboutReadVersionFailed => '暂时无法读取版本信息，请稍后重试。';

  @override
  String get aboutReadVersionFailedHint =>
      '如果你当前网络访问 GitHub 不稳定，可稍后再试，或切到下面的国内下载方式后重试。';

  @override
  String get aboutViewReleaseAction => '查看 Release';

  @override
  String get aboutDownloadNowAction => '立即下载';

  @override
  String get aboutOpenDownloadPageAction => '打开下载页';

  @override
  String get aboutCurrentVersionLabel => '当前版本';

  @override
  String get aboutLatestVersionLabel => '最新版本';

  @override
  String get aboutUnreleasedLabel => '未发布';

  @override
  String get aboutVersionChannelLabel => '版本通道';

  @override
  String get aboutPrereleaseChannel => '测试版';

  @override
  String get aboutUpdateAvailableHint =>
      '你现在只需要点下面的“立即下载”即可。测速、镜像和测试版都已经收进后面的高级选项里。';

  @override
  String get aboutUpdateNoUpdateHint =>
      '当前版本已经可正常使用；如果你要体验测试版，可以在后面的高级选项里打开测试版检测。';

  @override
  String aboutUpdatedAt(String time) {
    return '更新时间：$time';
  }

  @override
  String get aboutUpdateNowTitle => '立即更新';

  @override
  String get aboutUpdateNowAndroidSubtitle =>
      '普通使用只需要点一次立即下载。下载慢、下载失败、要换线路时，再去下面的高级选项。';

  @override
  String get aboutUpdateNowOtherSubtitle => '当前平台会直接打开下载页面，不会在应用内安装。';

  @override
  String get aboutMirrorDownloadHint => '当前会优先使用国内下载。大多数国内网络直接点“立即下载”就行。';

  @override
  String get aboutOriginalDownloadHint => '当前会优先使用国际源下载。如果下载慢或打不开，建议先切回“国内下载”。';

  @override
  String get aboutUseSystemDownloaderAction => '使用系统下载器下载';

  @override
  String get aboutOpenReleasePageAction => '打开 Release 页面';

  @override
  String get aboutDownloadMethodTitle => '下载方式';

  @override
  String get aboutDownloadMethodSubtitle =>
      '默认推荐国内下载。只有你能稳定访问 GitHub 时，再切到国际源下载。';

  @override
  String get aboutDownloadMethodMirror => '国内下载';

  @override
  String get aboutDownloadMethodOriginal => '国际源下载';

  @override
  String aboutMirrorModeHintRecommended(String current, String recommended) {
    return '当前使用国内下载 · $current。系统最近测速更推荐“$recommended”，需要时可在后面的高级选项里切换。';
  }

  @override
  String aboutMirrorModeHintCurrent(String current) {
    return '当前使用国内下载 · $current。如果下载慢或失败，再到后面的高级选项里测速、换线路或填写自定义地址。';
  }

  @override
  String get aboutOriginalModeHint =>
      '当前使用国际源下载。只有你网络能稳定访问 GitHub 时才建议这样设置；否则请切回国内下载。';

  @override
  String get aboutReleaseNotesTitle => '本次更新说明';

  @override
  String get aboutReleaseNotesSubtitle => '显示当前检测到版本的 Release 说明。';

  @override
  String get aboutAdvancedOptionsTitle => '高级选项';

  @override
  String get aboutAdvancedOptionsSubtitle => '只有下载慢、要手动切线路、或要检测测试版时再展开。';

  @override
  String get aboutMirrorSectionTitle => '下载线路与镜像';

  @override
  String get aboutMirrorSectionMirrorHint =>
      '当前使用国内下载。这里可以手动切线路、测速推荐，或填写自定义下载地址。';

  @override
  String get aboutMirrorSectionOriginalHint =>
      '你现在使用的是国际源下载。下面的线路设置只有在切回“国内下载”后才会生效。';

  @override
  String get aboutFillCustomMirrorFirst => '先填写自定义下载地址';

  @override
  String get aboutCurrentCustomMirrorTitle => '当前自定义下载地址';

  @override
  String get aboutCurrentMirrorTitle => '当前下载线路地址';

  @override
  String get aboutCurrentCustomMirrorHint => '当前正在使用你手动填写的下载地址。';

  @override
  String get aboutCurrentMirrorHint => '如果当前线路访问失败，可以切到其他内置线路，或改用自定义地址。';

  @override
  String get aboutProbeMirrorsAction => '测速并推荐';

  @override
  String get aboutProbingMirrors => '测速中…';

  @override
  String get aboutEditCustomMirrorAction => '修改自定义地址';

  @override
  String get aboutSetCustomMirrorAction => '填写自定义地址';

  @override
  String aboutSwitchToRecommendedAction(String label) {
    return '切到推荐：$label';
  }

  @override
  String get aboutMirrorDisabledHint =>
      '当前没有使用国内下载，所以这里的线路设置暂时不会生效。需要的话，请先在上面的“下载方式”里切回国内下载。';

  @override
  String get aboutRecentProbeResultsTitle => '最近测速结果';

  @override
  String get aboutUnavailable => '不可用';

  @override
  String get aboutRecommended => '推荐';

  @override
  String get aboutCheckPrereleaseTitle => '检测测试版本';

  @override
  String get aboutCheckPrereleaseSubtitle => '打开后会把测试版也纳入更新检查；普通使用建议关闭。';

  @override
  String get aboutDiagnosticsTitle => '测试与诊断';

  @override
  String get aboutDiagnosticsSubtitle => '只有遇到“超级岛没弹出”或需要给开发者反馈时再展开。';

  @override
  String get aboutRecordDiagnosticsTitle => '记录应用日志';

  @override
  String get aboutRecordDiagnosticsSubtitle =>
      '打开后会在本地持续记录关键日志，仅用于排查“该弹不弹”等问题。';

  @override
  String get aboutExportDiagnosticsAction => '导出应用日志';

  @override
  String get aboutViewPhoneLogsAction => '打开日志页';

  @override
  String get aboutClearAndRecollectAction => '清空并重新收集';

  @override
  String get aboutLiveDiagnosticsEnabled => '已开启超级岛诊断日志';

  @override
  String get aboutLiveDiagnosticsDisabled => '已关闭超级岛诊断日志';

  @override
  String get aboutNoDiagnosticsExportYet => '还没有可导出的超级岛诊断日志';

  @override
  String get aboutProbeNoMirrorFound => '测速完成，但暂时没有发现可用镜像线路';

  @override
  String aboutProbeCurrentFastest(String label) {
    return '测速完成，当前线路“$label”已是最快可用线路';
  }

  @override
  String aboutProbeRecommendSwitch(String label) {
    return '测速完成，推荐切换到“$label”';
  }

  @override
  String get switchAction => '切换';

  @override
  String aboutSwitchToMirrorAfterError(String error) {
    return '$error，可切到国内镜像后再试';
  }

  @override
  String aboutSwitchPresetAfterError(String error, String label) {
    return '$error，建议切换到“$label”后重试';
  }

  @override
  String get aboutSetMirrorSourceTitle => '设置镜像源';

  @override
  String get aboutMirrorPrefixLabel => '镜像前缀';

  @override
  String get aboutMirrorPrefixInvalid => '镜像源格式不正确，请输入完整的 http 或 https 地址';

  @override
  String get aboutMirrorSaved => '镜像源已保存';

  @override
  String get aboutDownloadCancelled => '已取消下载';

  @override
  String get aboutInstallReady => '安装包已准备好，已尝试打开安装界面；如果系统没有弹出，请稍后从通知或文件管理器手动安装';

  @override
  String get aboutUpdatePackageTitle => '轻屿课表更新包';

  @override
  String get aboutUpdatePackageDescription => '已交给系统下载管理器下载，完成后可直接从系统通知安装。';

  @override
  String get aboutSystemDownloaderQueued => '已交给系统下载管理器，请在系统通知或下载列表里查看进度';

  @override
  String get aboutSystemDownloaderFailed => '调用系统下载管理器失败';

  @override
  String get aboutDownloadCancelling => '正在取消下载…';

  @override
  String aboutDownloadingBytes(String value) {
    return '正在下载更新 $value';
  }

  @override
  String aboutDownloadingPercent(String value) {
    return '正在下载更新 $value%';
  }

  @override
  String get aboutMirrorUnknownSizeHint => '镜像源未返回文件总大小，先显示已下载体积';

  @override
  String get aboutCancelDownloadAction => '取消下载';

  @override
  String get aboutContributorsScreenTitle => '代码贡献者';

  @override
  String get aboutDevelopersTitle => '开发人员';

  @override
  String get aboutDeveloperMaintainerSubtitle => '轻屿课表开发与维护';

  @override
  String get aboutWarehouseMaintainersTitle => '教务导入适配者';

  @override
  String get aboutWarehouseMaintainersIntro =>
      '以下名单来自 qingyu_warehouse 适配仓的 maintainer 字段汇总。若本地已有缓存，会先显示缓存，再后台刷新。';

  @override
  String aboutWarehouseMaintainersLoadFailed(String error) {
    return '暂时无法读取适配者名单：$error';
  }

  @override
  String get aboutWarehouseMaintainersEmpty => '当前还没有读取到适配者信息。';

  @override
  String aboutWarehouseMaintainerCount(int count) {
    return '$count 个适配项';
  }

  @override
  String get aboutParticipateWarehouseTitle => '参与教务适配';

  @override
  String get aboutParticipateWarehouseSubtitle =>
      '如果你会抓包、网页调试、JavaScript，或者愿意长期维护自己学校的教务系统，欢迎去 qingyu_warehouse 提交新的学校适配与修复。';

  @override
  String get importFileReadFailed => '无法读取所选文件';

  @override
  String get importReplaceExistingTitle => '导入课程';

  @override
  String importReplaceExistingMessage(String name) {
    return '导入 $name 时，是否替换现有课程？';
  }

  @override
  String get importNoCoursesRecognized => '未识别到可导入课程';

  @override
  String get importConfirmSemesterMappingTitle => '确认开学日期和周次对应';

  @override
  String get importConfirmSemesterMappingSubtitleIcs =>
      '请选择学校校历的开学日期。系统已根据文件里最早的上课日期给出默认周次对应，你也可以手动调整。';

  @override
  String importOverwriteCount(int count) {
    return '已覆盖导入 $count 条课程';
  }

  @override
  String importUpdatedCount(int count) {
    return '已更新课表：新增或更新 $count 条课程';
  }

  @override
  String get importNoCourseChanges => '没有需要新增或更新的课程';

  @override
  String get aiImportTitle => '识图导入';

  @override
  String aiPreviewSummary(
    int courseCount,
    int sectionCount,
    String warningSuffix,
  ) {
    return '识别到 $courseCount 门课，最高到第 $sectionCount 节$warningSuffix';
  }

  @override
  String aiWarningCountSuffix(int count) {
    return '，$count 条提醒';
  }

  @override
  String get aiWorkflowCompactTitle => '复制提示词 -> 豆包识图 -> 导入';

  @override
  String get aiWorkflowCompactSubtitle => '豆包专家模式 -> 复制 JSON -> 选择开学日期';

  @override
  String get aiWorkflowTitle => '复制提示词 -> 豆包识图 -> 粘贴 JSON -> 导入';

  @override
  String get aiWorkflowSubtitle =>
      '先复制提示词，再到豆包左下角切换为专家模式，把课表截图和提示词一起发过去。把豆包返回的 JSON 复制回这里，点击导入后再选择开学日期。';

  @override
  String get aiPromptShortAction => '提示词';

  @override
  String get aiExpertModeSuggestion => '建议豆包专家模式，支持多图，截图需带星期表头。';

  @override
  String get aiHintExpertMode => '先切到豆包专家模式';

  @override
  String get aiHintSendScreenshot => '截图和提示词一起发';

  @override
  String get aiHintCopyJsonBack => '返回结果复制 JSON';

  @override
  String get aiHintPickSemesterAfterImport => '导入后再选开学日期';

  @override
  String get jsonLabelShort => 'JSON';

  @override
  String get aiPasteJsonTitle => '粘贴 AI 返回的 JSON';

  @override
  String aiCourseCountChip(int count) {
    return '$count 门课';
  }

  @override
  String get aiParseFailedChip => '解析失败';

  @override
  String get aiPasteJsonHintShort => '粘贴 AI 返回的 JSON';

  @override
  String get aiPasteJsonHintLong =>
      '把豆包返回的 JSON 原样粘贴到这里，然后点击导入。支持纯 JSON，也兼容 ```json 代码块。';

  @override
  String get detailAction => '详情';

  @override
  String get aiParseErrorTitle => '解析错误';

  @override
  String get viewDetailsAction => '查看详情';

  @override
  String get aiWorkflowFooter =>
      '复制提示词 -> 豆包发送截图和提示词 -> 把 JSON 贴回这里 -> 点击导入 -> 选择开学日期。';

  @override
  String get previewAction => '预览';

  @override
  String get confirmImportAction => '确认导入';

  @override
  String get promptCopiedHint => '提示词已复制，去豆包发送截图和提示词';

  @override
  String get clipboardNoText => '剪贴板里没有可用文本';

  @override
  String get aiPromptSheetTitle => '识图提示词';

  @override
  String get aiPromptSheetSubtitle =>
      '建议使用豆包。先把豆包左下角切换为专家模式，再把下面整段提示词和课表截图一起发过去，让它只返回 JSON。生成后把 JSON 复制回本页，点击导入后再选择开学日期。';

  @override
  String get aiPreviewTitle => '解析预览';

  @override
  String get aiPasteJsonFirst => '请先粘贴 AI 返回的 JSON';

  @override
  String get aiParseFailedIncompleteJson => '解析失败，请确认粘贴的是完整 JSON';

  @override
  String get importAiResultTitle => '导入 AI 解析结果';

  @override
  String get importAiReplaceMessage => '是否用当前这份 AI 解析结果替换现有课程？';

  @override
  String get importConfirmSemesterMappingSubtitleAi =>
      '请选择学校校历的开学日期，再确认课表里的第 1 周对应校历第几周。如果学校第一周没课，这里通常要改成第 2 周。';

  @override
  String aiWarningExtraSuffix(int count) {
    return '，另有 $count 条识别提醒';
  }

  @override
  String get pasteAction => '粘贴';

  @override
  String get importConfirmSemesterMappingSubtitleWarehouse =>
      '教务脚本已返回课程周次，请确认校历开学日期；如果学校前几周没有课，可把“课表第 1 周”对应到校历后面的周次。';

  @override
  String aiPreviewCourseCount(int count) {
    return '课程数量：$count';
  }

  @override
  String aiPreviewMaxSection(int section) {
    return '最大节次：第 $section 节';
  }

  @override
  String get aiPreviewWarningsTitle => '识别提醒';

  @override
  String get aiPreviewCoursesTitle => '课程预览';

  @override
  String aiPreviewRemainingCourses(int count) {
    return '其余 $count 条将在导入后写入当前课表';
  }

  @override
  String get warehouseMissingSchoolTitle => '学校列表里没有你的学校？';

  @override
  String get warehouseMissingSchoolSubtitle =>
      '去反馈页提一个 Issue 就行。建议一起写上学校名称、教务系统网址、登录后课表页链接或截图，这样更方便补适配。';

  @override
  String get laterAction => '稍后再说';

  @override
  String get goFeedbackAction => '去反馈页';

  @override
  String get warehouseFeedbackMissingSchoolTitle => '缺少学校？去反馈';

  @override
  String get warehouseCustomDebugTitle => '自定义调试';

  @override
  String get warehouseRootLoadFailedTitle => '暂时无法读取适配仓';

  @override
  String get searchSchoolHint => '搜索学校名称、首字母或代码';

  @override
  String get clearSearchTooltip => '清空';

  @override
  String get noMatchingSchools => '没有找到匹配的学校';

  @override
  String get noAvailableSchools => '暂无可用学校';

  @override
  String get searchSchoolSuggestion => '试试学校全称、首字母或仓库里的学校代码。';

  @override
  String get deleteDebugRecordTitle => '删除调试记录';

  @override
  String deleteDebugRecordMessage(String name) {
    return '确认删除“$name”？删除后不会影响已经导入的课程。';
  }

  @override
  String deletedDebugRecord(String name) {
    return '已删除调试记录：$name';
  }

  @override
  String get customDebugName => '自定义调试';

  @override
  String get localDebugMaintainer => '本地调试';

  @override
  String get customDebugDescription => '用户保存的自定义教务调试脚本';

  @override
  String get addDebugRecordTooltip => '新增调试记录';

  @override
  String get customDebugIntroTitle => '这里放你自己的教务调试记录';

  @override
  String get customDebugIntroSubtitle =>
      '每条记录都可以保存自定义网址和整段脚本。保存后下次直接点“开始调试”就能复用，不需要再去某个学校详情页里找入口。';

  @override
  String get addDebugRecordAction => '新增调试记录';

  @override
  String get noSavedDebugRecords => '还没有保存的调试记录';

  @override
  String get noSavedDebugRecordsHint => '先新增一条，把网址和脚本贴进去，以后就能直接复用。';

  @override
  String debugScriptLength(int count) {
    return '脚本 $count 字符';
  }

  @override
  String get startDebugAction => '开始调试';

  @override
  String get editAction => '编辑';

  @override
  String get scriptFileReadFailed => '无法读取脚本文件';

  @override
  String scriptFileImported(String name) {
    return '已导入脚本文件：$name';
  }

  @override
  String scriptFileImportFailed(String error) {
    return '导入脚本文件失败：$error';
  }

  @override
  String get debugRecordNameRequired => '请先填写调试记录名称';

  @override
  String get invalidImportUrl => '请输入有效的教务网址';

  @override
  String get debugScriptRequired => '请先填写或导入脚本';

  @override
  String get editDebugRecordTitle => '编辑调试记录';

  @override
  String get addDebugRecordTitle => '新增调试记录';

  @override
  String get savingAction => '保存中…';

  @override
  String get debugRecordFormula => '一条记录 = 一个网址 + 一段脚本';

  @override
  String get debugRecordFormulaSubtitle =>
      '适合你反复调试同一个学校，或者不同学校保留多套脚本。保存后会一直保留，后面可随时修改。';

  @override
  String get debugRecordNameLabel => '记录名称';

  @override
  String get debugRecordNameHint => '例如：重庆机电-新版教务';

  @override
  String get importUrlLabel => '教务网址';

  @override
  String get debugScriptLabel => '调试脚本';

  @override
  String get importFromFileAction => '从文件导入';

  @override
  String get debugScriptHint => '把浏览器扩展导出的完整脚本粘贴到这里';

  @override
  String get saveDebugRecordAction => '保存调试记录';

  @override
  String get fillUrlThenImport => '填写网址后导入';

  @override
  String get webLoginImport => '网页登录导入';

  @override
  String get savedImportUrlHint => '已保存教务网址，下次可直接导入';

  @override
  String get adapterIntroSubtitle => '可查看适配器信息、登录入口与脚本状态。';

  @override
  String get schoolLabel => '学校';

  @override
  String get categoryLabel => '类别';

  @override
  String get maintainerLabel => '维护者';

  @override
  String get adapterInfoTitle => '适配器信息';

  @override
  String get scriptPathLabel => '脚本路径';

  @override
  String get loginEntryLabel => '登录入口';

  @override
  String get unsetConfigLabel => '未配置';

  @override
  String get adapterOverrideImportUrlHint => '当前使用你手动覆盖的登录地址';

  @override
  String get repositoryLabel => '仓库';

  @override
  String get scriptStatusTitle => '脚本状态';

  @override
  String scriptLoadedLength(int count) {
    return '脚本已成功读取，长度 $count 字符。';
  }

  @override
  String get scriptEmpty => '脚本为空';

  @override
  String get openLoginInAppAction => '应用内打开登录入口';

  @override
  String get openInSystemBrowserAction => '系统浏览器打开';

  @override
  String get copiedImportLoginUrl => '已复制教务登录地址';

  @override
  String get copyLoginAddressAction => '复制登录地址';

  @override
  String get copiedScriptRawUrl => '已复制脚本原始地址';

  @override
  String get copyScriptAddressAction => '复制脚本地址';

  @override
  String get customLoginAddressAction => '自定义登录地址';

  @override
  String get editCustomLoginAddressAction => '修改自定义地址';

  @override
  String get clearCustomLoginAddressAction => '清除自定义地址';

  @override
  String get restoreRepositoryAddressAction => '恢复仓库地址';

  @override
  String get invalidLoginEntryUrl => '登录入口地址无效';

  @override
  String get savedCustomLoginAddress => '已保存自定义登录地址';

  @override
  String get clearedCustomLoginAddress => '已清除自定义登录地址';

  @override
  String get restoredRepositoryImportUrl => '已恢复仓库里的登录地址';

  @override
  String get backToCurrentWeekAction => '回本周';

  @override
  String get nonCurrentWeekLabel => '非本周';

  @override
  String get conflictLabel => '冲突';

  @override
  String get selectWeekTitle => '选择周次';

  @override
  String availableWeeksCount(int count) {
    return '共 $count 周';
  }

  @override
  String goToWeekLabel(int week) {
    return '第 $week 周';
  }

  @override
  String get homeMenuUpdateTitle => '软件更新';

  @override
  String get homeMenuProfilesTitle => '课表管理';

  @override
  String get homeMenuOverviewTitle => '课程总览';

  @override
  String get homeMenuAddCourseTitle => '添加课程';

  @override
  String get homeMenuImportTitle => '导入课程';

  @override
  String get homeMenuSettingsTitle => '课表设置';

  @override
  String get homeMenuCoffeeTitle => '请喝咖啡';

  @override
  String get homeMenuFeedbackTitle => '问题反馈';

  @override
  String get switchTimetableTitle => '切换课表';

  @override
  String get switchTimetableSubtitleEmpty => '点击下面的课表，立即切换当前视图。';

  @override
  String switchTimetableSubtitleCurrent(String name) {
    return '当前：$name，点击下面的课表立即切换。';
  }

  @override
  String get todayTimetableTitle => '今日课表';

  @override
  String get dayTimetableTitle => '单日时间轴';

  @override
  String get backToWeekViewAction => '返回周视图';

  @override
  String get backToTodayAction => '回到今天';

  @override
  String get ongoingCourseBadge => '正在上课';

  @override
  String get dayViewEmptyTitle => '暂无课程';

  @override
  String shortNamePrefix(String value) {
    return '简称：$value';
  }

  @override
  String teacherPrefix(String value) {
    return '老师：$value';
  }

  @override
  String locationPrefix(String value) {
    return '地点：$value';
  }

  @override
  String courseDialogCurrentWeekHint(int week) {
    return '当前查看第 $week 周，可直接对这一周这节课调课。';
  }

  @override
  String courseDialogNotThisWeekHint(int week) {
    return '当前查看第 $week 周，这门课这周没有上课，因此不能按“本周这节”调课。';
  }

  @override
  String get editActionShort => '编辑';

  @override
  String get rescheduleAction => '调课';

  @override
  String get deleteActionShort => '删除';

  @override
  String get deleteModeTitle => '删除方式';

  @override
  String get deleteModeSubtitle => '你可以删掉整条排课，也可以只删当前看到的这一周这一节。';

  @override
  String get deleteCourseAction => '删这个课';

  @override
  String get deleteOccurrenceAction => '删这节课';

  @override
  String deleteModeHintCurrentWeek(int week) {
    return '“删这个课”会删除这条排课的全部周次；“删这节课”只会删除第 $week 周这一次。';
  }

  @override
  String deleteModeHintUnavailable(int week) {
    return '当前卡片不是第 $week 周的实际排课，所以只能删除整条排课。';
  }

  @override
  String deleteScheduleConfirmMessage(String name, String detail) {
    return '确定删除“$name”这条排课吗？\n$detail';
  }

  @override
  String deleteOccurrenceConfirmMessage(String name, int week, String detail) {
    return '确定删除“$name”在第 $week 周的这一节吗？\n$detail';
  }

  @override
  String occurrenceDeletedMessage(int week) {
    return '已删除第 $week 周这节课';
  }

  @override
  String get noChangesDetected => '未检测到变更';

  @override
  String get rescheduleCurrentOccurrenceTitle => '调本周这节课';

  @override
  String rescheduleCurrentOccurrenceSubtitle(int week) {
    return '只调整第 $week 周这一节，原课程在这一周会自动移除，其他周保持不变。';
  }

  @override
  String get rescheduleTargetWeekLabel => '调到第几周';

  @override
  String get weekdayFieldLabel => '星期';

  @override
  String get startSectionFieldLabel => '开始节次';

  @override
  String get endSectionFieldLabel => '结束节次';

  @override
  String get courseLocationFieldLabel => '上课地点';

  @override
  String get confirmRescheduleAction => '确认调课';

  @override
  String get homeTitleStyleClassicLabel => '经典文字';

  @override
  String get homeTitleStyleBrandLabel => '大 Logo';

  @override
  String get homeTitleStyleClassicDescription => '保持原本标题样式，只显示文字，点击即可切换课表';

  @override
  String get homeTitleStyleBrandDescription => '显示大 Logo 和小课表名称，更强调品牌感';

  @override
  String get widgetBackgroundStyleGlass => '半透明玻璃感';

  @override
  String get widgetBackgroundStyleSolid => '纯色卡片';

  @override
  String get widgetBackgroundStyleGradient => '渐变卡片';

  @override
  String get homeWidgetTargetCompact22 => '主卡 2×2';

  @override
  String get homeWidgetTargetMiniList22 => '迷你列表 2×2';

  @override
  String get homeWidgetTargetMedium24 => '概览 2×4';

  @override
  String get homeWidgetTargetLarge44 => '列表 4×4';

  @override
  String get addCourseSheetTitle => '添加内容';

  @override
  String get addCourseSheetSubtitle =>
      '空白课表区域不响应点击。请从这里明确选择是加一节临时课、整学期重复课，还是插入一条单次日程。';

  @override
  String courseWeekdaySectionSummary(
    String weekDescription,
    String weekday,
    int startSection,
    int endSection,
  ) {
    return '$weekDescription · $weekday 第$startSection-$endSection节';
  }

  @override
  String weekdaySectionTimeSummary(
    String weekday,
    int startSection,
    int endSection,
    String startTime,
    String endTime,
  ) {
    return '$weekday 第$startSection-$endSection节 · $startTime-$endTime';
  }

  @override
  String rescheduledToMessage(
    int week,
    String weekday,
    int startSection,
    int endSection,
  ) {
    return '已调到第 $week 周 $weekday 第$startSection-$endSection节';
  }

  @override
  String courseCountSummary(int count) {
    return '$count 门课';
  }

  @override
  String dayAgendaInProgressStatus(int minutes) {
    return '进行中 · 剩余 $minutes 分钟';
  }

  @override
  String dayAgendaEndingSoonStatus(int minutes) {
    return '快下课了 · 剩余 $minutes 分钟';
  }

  @override
  String scheduleAgendaInProgressStatus(int minutes) {
    return '进行中 · 剩余 $minutes 分钟';
  }

  @override
  String scheduleAgendaEndingSoonStatus(int minutes) {
    return '即将结束 · 剩余 $minutes 分钟';
  }

  @override
  String get currentBadge => '当前';

  @override
  String get feedbackXiaohongshuTitle => '小红书';

  @override
  String feedbackXiaohongshuSubtitle(String id) {
    return '小红书号：$id';
  }

  @override
  String get feedbackCoolapkTitle => '酷安';

  @override
  String feedbackCoolapkSubtitle(String id) {
    return '酷安号：$id';
  }

  @override
  String get feedbackQqGroupTitle => 'QQ 群';

  @override
  String feedbackQqGroupSubtitle(String id) {
    return '群号：$id';
  }

  @override
  String get copiedCurrentTimetable => '已复制当前课表';

  @override
  String sectionRangeLabel(int startSection, int endSection) {
    return '第$startSection-$endSection节';
  }

  @override
  String classStartsAtLabel(String time) {
    return '$time 开始';
  }

  @override
  String classEndsAtLabel(String time) {
    return '$time 结束';
  }

  @override
  String get invalidSectionTimeFormat => '节次时间格式不正确';

  @override
  String get noSectionTimesToSave => '没有可保存的节次时间';

  @override
  String warehouseImportedTimeSchemeName(String schoolName) {
    return '$schoolName 导入节次';
  }

  @override
  String get unnamedScript => '未命名脚本';

  @override
  String localDebugModeScriptStatus(String scriptName) {
    return '本地调试模式：$scriptName';
  }

  @override
  String get executeImportScriptTooltip => '执行导入脚本';

  @override
  String get switchToMobileWebTooltip => '切换到移动端页面';

  @override
  String get switchToDesktopWebTooltip => '切换到桌面端页面';

  @override
  String get rememberCurrentInputTooltip => '记住当前输入';

  @override
  String get fillRememberedTooltip => '填充已记住账号';

  @override
  String get clearRememberedTooltip => '清除已记住账号';

  @override
  String get copyCurrentAddressTooltip => '复制当前地址';

  @override
  String get copiedCurrentAddress => '已复制当前地址';

  @override
  String get warehouseLoginHintLocalDebug => '当前为本地调试脚本模式';

  @override
  String get warehouseLoginHintImport => '在此登录教务系统后执行导入';

  @override
  String get currentPageModeDesktop => '当前页面模式：桌面端';

  @override
  String get currentPageModeMobile => '当前页面模式：移动端';

  @override
  String localScriptLabel(String scriptName) {
    return '本地脚本：$scriptName';
  }

  @override
  String get webAddressHint => '输入网页地址';

  @override
  String get goAction => '前往';

  @override
  String rememberedAccountLabel(String username) {
    return '已记住账号：$username';
  }

  @override
  String get importingAction => '导入中...';

  @override
  String get executeLocalDebugScriptAction => '执行本地调试脚本';

  @override
  String get executeImportScriptAction => '执行导入脚本';

  @override
  String get invalidWebAddress => '网页地址无效';

  @override
  String get injectingLocalDebugScript => '正在注入本地调试脚本';

  @override
  String get injectingAdapterScript => '正在注入适配器脚本';

  @override
  String get localDebugScriptInjected => '本地调试脚本已注入';

  @override
  String get scriptInjected => '脚本已注入';

  @override
  String get scriptInjectionFailed => '脚本注入失败';

  @override
  String executeFailedWithError(String error) {
    return '执行失败：$error';
  }

  @override
  String get importFlowFinished => '导入流程已完成';

  @override
  String get defaultContinuePrompt => '请按提示继续操作';

  @override
  String get inputRequiredTitle => '需要输入';

  @override
  String get pleaseEnterFourDigitYear => '请输入 4 位年份';

  @override
  String get pleaseChooseTitle => '请选择';

  @override
  String get invalidCourseConfigFormat => '课程配置格式不正确';

  @override
  String saveCourseConfigFailedWithError(String error) {
    return '保存课程配置失败：$error';
  }

  @override
  String saveSectionTimesFailedWithError(String error) {
    return '保存节次时间失败：$error';
  }

  @override
  String get invalidCourseDataFormat => '课程数据格式不正确';

  @override
  String get noImportableCoursesFromScript => '脚本未返回可导入课程';

  @override
  String importCourseCountPrompt(int count) {
    return '识别到 $count 门课程，是否导入？';
  }

  @override
  String get importCancelledStatus => '已取消导入';

  @override
  String applyReturnedTimeSchemeFailed(String error) {
    return '应用返回的节次模板失败：$error';
  }

  @override
  String get importInterruptedStatus => '导入已中断';

  @override
  String get importFailedStatus => '导入失败';

  @override
  String importFailedWithError(String error) {
    return '导入失败：$error';
  }

  @override
  String get unknownTeacher => '未知教师';

  @override
  String get unknownLocation => '未知地点';

  @override
  String get autofillLoginTitle => '自动填充登录信息';

  @override
  String autofillLoginMessage(String username) {
    return '检测到已记住账号 $username，是否自动填充？';
  }

  @override
  String get notNowAction => '暂不';

  @override
  String get autofillAction => '自动填充';

  @override
  String get rememberPasswordTitle => '记住密码';

  @override
  String rememberPasswordMessage(String username) {
    return '是否记住账号 $username 的登录信息，并在下次自动填充？';
  }

  @override
  String get dontRememberAction => '不记住';

  @override
  String get rememberAndAutofillAction => '记住并自动填充';

  @override
  String get savedRememberedLoginStatus => '已保存记住的登录信息';

  @override
  String get autofilledRememberedLoginStatus => '已自动填充记住的登录信息';

  @override
  String get noRecognizedLoginInputs => '未识别到登录输入项';

  @override
  String get noUsernameOrPasswordRecognized => '未识别到用户名或密码';

  @override
  String get rememberedCurrentLoginStatus => '已记住当前登录信息';

  @override
  String get rememberedCurrentLoginSuccess => '已记住当前登录信息';

  @override
  String rememberLoginFailedWithError(String error) {
    return '记住登录信息失败：$error';
  }

  @override
  String get clearedRememberedLoginStatus => '已清除记住的登录信息';

  @override
  String get clearedRememberedLoginSuccess => '已清除记住的登录信息';

  @override
  String get addScheduleTitle => '添加日程';

  @override
  String get editScheduleTitle => '编辑日程';

  @override
  String get addScheduleAction => '添加日程';

  @override
  String get scheduleTitleLabel => '日程标题';

  @override
  String get scheduleTitleHint => '例如：开组会、办证件、拿快递';

  @override
  String get scheduleTitleRequired => '请输入日程标题';

  @override
  String get scheduleInfoSectionTitle => '日程信息';

  @override
  String get scheduleInfoSectionSubtitle => '日程会按具体日期插入日视图时间线里，不会改动课程本身。';

  @override
  String get scheduleTimeSectionTitle => '时间安排';

  @override
  String get scheduleTimeSectionSubtitle => '选择这条日程实际发生的日期和起止时间。';

  @override
  String get scheduleAppearanceSectionTitle => '显示样式';

  @override
  String get scheduleAppearanceSectionSubtitle => '选择一个更容易和课程区分的日程颜色。';

  @override
  String get scheduleLocationLabel => '地点';

  @override
  String get scheduleLocationHint => '选填';

  @override
  String get scheduleDateLabel => '日期';

  @override
  String get scheduleStartDateLabel => '开始日期';

  @override
  String get scheduleEndDateLabel => '结束日期';

  @override
  String get scheduleStartTimeLabel => '开始时间';

  @override
  String get scheduleEndTimeLabel => '结束时间';

  @override
  String get scheduleColorLabel => '日程颜色';

  @override
  String get scheduleNoteLabel => '备注';

  @override
  String get scheduleNoteHint => '选填';

  @override
  String get scheduleBadgeLabel => '日程';

  @override
  String scheduleCountSummary(int count) {
    return '日程 $count 项';
  }

  @override
  String get scheduleTimeRangeInvalid => '结束时间必须晚于开始时间';

  @override
  String get scheduleDateRangeInvalid => '结束日期不能早于开始日期';

  @override
  String get scheduleSingleDayHint => '同日结束时，结束时间必须晚于开始时间。';

  @override
  String get scheduleCrossDayHint => '跨日日程会按当天切片显示在日视图里。';

  @override
  String get scheduleSavedHint => '日程已添加';

  @override
  String get scheduleUpdatedHint => '日程已更新';

  @override
  String get crossDayBadgeLabel => '跨日';

  @override
  String deleteScheduleMessage(String title) {
    return '删除日程“$title”？';
  }

  @override
  String get scheduleDeletedHint => '日程已删除';

  @override
  String get examListTitle => '考试安排';

  @override
  String get addExam => '添加考试';

  @override
  String get editExam => '编辑考试';

  @override
  String get saveExam => '保存考试';

  @override
  String get noExams => '暂无考试安排';

  @override
  String get examToday => '今天有考试';

  @override
  String daysUntilExam(int days) {
    return '距离考试还有 $days 天';
  }

  @override
  String get examPassed => '已结束';

  @override
  String get linkCourse => '关联课程';

  @override
  String get linkCourseRequired => '请选择关联课程';

  @override
  String get examNameLabel => '考试名称';

  @override
  String get examNameRequired => '请输入考试名称';

  @override
  String get examDateLabel => '考试日期';

  @override
  String get examDateHint => '请选择日期';

  @override
  String get examDateRequired => '请选择考试日期';

  @override
  String get examStartTimeLabel => '开始时间';

  @override
  String get examEndTimeLabel => '结束时间';

  @override
  String get examLocationLabel => '考场';

  @override
  String get examLocationHint => '留空则使用上课教室';

  @override
  String get sameAsClassroom => '同上课教室';

  @override
  String get examSeatLabel => '座位号';

  @override
  String get examReminderLabel => '提醒设置';

  @override
  String get examNoteLabel => '备注';

  @override
  String get deleteExam => '删除考试';

  @override
  String deleteExamConfirm(String name) {
    return '删除考试「$name」？';
  }

  @override
  String get examBadgeLabel => '考试';

  @override
  String get examCountdownToday => '今天';

  @override
  String examCountdownDays(int days) {
    return '$days天后';
  }

  @override
  String get sortAction => '排序';

  @override
  String get sortByAdded => '按添加顺序';

  @override
  String get sortByName => '按课程名称';

  @override
  String get sortBySchedule => '按排课时间';

  @override
  String scheduleEntryTitle(int index) {
    return '排课记录 $index';
  }

  @override
  String get addScheduleEntryAction => '添加排课时间';

  @override
  String get deleteScheduleEntryAction => '删除排课';

  @override
  String get holidaySettingsEntryTitle => '节假日标记';

  @override
  String get holidaySettingsEntrySubtitle => '在课表上标记法定节假日和调休补班';

  @override
  String get holidayMakeupWorkday => '补班';

  @override
  String get holidaySettingsTitle => '节假日标记';

  @override
  String get holidayEnableTitle => '启用节假日标记';

  @override
  String get holidayEnableSubtitle => '开启后会在课表上标记法定节假日和调休补班日';

  @override
  String get holidayDataSectionTitle => '节假日数据';

  @override
  String get holidayDataYear => '年份';

  @override
  String get holidayDataCount => '条数';

  @override
  String get holidayDataEmpty => '暂无节假日数据';

  @override
  String get holidayCheckUpdate => '检查更新';

  @override
  String get holidayUpcomingSectionTitle => '近期节假日';

  @override
  String get holidayNoUpcoming => '近期没有节假日';

  @override
  String get holidayBadgeLabel => '假';

  @override
  String get holidayStatusLabel => '假期';

  @override
  String get suspendedBadgeLabel => '停';

  @override
  String get suspendedStatusLabel => '停课';

  @override
  String get courseActionSuspend => '停课';

  @override
  String get courseActionUnsuspend => '恢复';

  @override
  String get suspendSheetTitle => '停课';

  @override
  String get suspendSheetSubtitle => '选择停课范围';

  @override
  String get suspendThisWeek => '停本周';

  @override
  String get suspendThisWeekDesc => '仅暂停当前周';

  @override
  String get suspendAllWeeks => '全部停';

  @override
  String get suspendAllWeeksDesc => '暂停所有周次';

  @override
  String get unsuspendAllWeeks => '恢复全部';

  @override
  String get unsuspendAllWeeksDesc => '恢复所有周次';

  @override
  String get customHolidayTitle => '自定义假期';

  @override
  String get customHolidayAdd => '添加假期';

  @override
  String get customHolidayEdit => '编辑假期';

  @override
  String get customHolidayDelete => '删除';

  @override
  String get customHolidayDeleteConfirm => '确定删除这个自定义假期吗？';

  @override
  String get customHolidayNameLabel => '假期名称';

  @override
  String get customHolidayStartDate => '开始日期';

  @override
  String get customHolidayEndDate => '结束日期';

  @override
  String get customHolidayType => '类型';

  @override
  String get customHolidayTypeVacation => '假期';

  @override
  String get customHolidayTypeWorkday => '调休上班';

  @override
  String get customHolidayEmpty => '暂无自定义假期';

  @override
  String get customHolidayNameRequired => '请输入假期名称';

  @override
  String customHolidayDateRange(Object start, Object end) {
    return '$start ~ $end';
  }

  @override
  String get selectTeacherTitle => '选择教师';

  @override
  String get selectLocationTitle => '选择教室';

  @override
  String get historyRecordsLabel => '历史记录';

  @override
  String get noHistoryRecords => '暂无历史记录';

  @override
  String get weekPickerTitle => '选择上课周次';

  @override
  String get selectTimeSchemeTitle => '选择时间方案';

  @override
  String get manageTimeSchemesAction => '管理时间方案';

  @override
  String get examDefaultName => '期末考试';

  @override
  String get examDateWeekPickerTitle => '选择考试日期';

  @override
  String get weekPickerCalendarTooltip => '使用日历选择';

  @override
  String get thisWeekLabel => '本周';

  @override
  String get guidePrivacyPageTitle => '隐私协议';

  @override
  String get guidePermissionsPageTitle => '系统权限';

  @override
  String get guideTipsPageTitle => '使用技巧';

  @override
  String get guidePrevButton => '上一步';

  @override
  String get guideNextButton => '下一步';

  @override
  String get guidePermissionsHeader => '系统权限设置';

  @override
  String get guidePermissionsSubtitle => '完成这些设置，超级岛和提醒才能正常使用';

  @override
  String get guidePermissionsFooterHint =>
      '点击后跳转到系统设置，返回应用后可识别的状态会自动刷新；自启动受系统限制，请以系统页面开关为准。';

  @override
  String get guideTipsHeader => '使用技巧';

  @override
  String get guideTipsSubtitle => '这些随时可以在「设置」里找到';

  @override
  String get guidePrivacyReadBeforeUse => '使用前请阅读并同意以下内容';

  @override
  String get guidePrivacyViewOnly => '隐私、第三方 SDK 与免责说明';

  @override
  String holidayDataYearLabel(Object year) {
    return '$year年法定节假日';
  }

  @override
  String get holidayUpdateLog => '更新日志';

  @override
  String holidayUpdateLogCount(int count) {
    return '$count条';
  }

  @override
  String holidayDateSameMonth(int month, int start, int end) {
    return '$month月$start日 - $end日';
  }

  @override
  String holidayDateSameDay(int month, int day) {
    return '$month月$day日';
  }

  @override
  String holidayDateDiffMonth(
    int startMonth,
    int startDay,
    int endMonth,
    int endDay,
  ) {
    return '$startMonth月$startDay日 - $endMonth月$endDay日';
  }

  @override
  String get liveTestingHolidayOverride => '假期状态覆盖';

  @override
  String get liveTestingHolidayOverrideSubtitle =>
      '开启后模拟假期状态，用于测试提醒和小组件是否正确隐藏课程';

  @override
  String get liveTestingHolidayModeEnabled => '假期模式已开启';

  @override
  String get liveTestingHolidayModeDisabled => '假期模式已关闭';

  @override
  String get liveTestingHolidayModeEnabledDesc => '课程提醒和小组件将隐藏所有课程';

  @override
  String get liveTestingHolidayModeDisabledDesc => '当前使用正常假期数据';

  @override
  String get textColorTitle => '文字颜色';

  @override
  String get textColorSubtitle => '自定义课表各区域的文字颜色';

  @override
  String get textColorIndependentDetail => '独立设置详情颜色';

  @override
  String get textColorCourseCardTitle => '课程卡片标题颜色';

  @override
  String get textColorCourseCardDetail => '课程卡片详情颜色';

  @override
  String get textColorWeekdayBar => '星期栏字体颜色';

  @override
  String get textColorWeekdayBarAccent => '星期栏强调色';

  @override
  String get textColorTimeAxis => '时间轴字体颜色';

  @override
  String get textColorSelectColor => '选择颜色';

  @override
  String get textColorCurrentColor => '当前颜色';

  @override
  String get themeExport => '导出主题';

  @override
  String get themeImport => '导入主题';

  @override
  String get themeExportSuccess => '主题已复制到剪贴板';

  @override
  String get themeImportSuccess => '主题已导入';

  @override
  String get themeImportFailed => '剪贴板内容格式错误';

  @override
  String get themeManageTitle => '主题管理';

  @override
  String get themeManageSubtitle => '导出、导入和切换主题';

  @override
  String get themePreset => '预设主题';

  @override
  String get themeSaved => '我的主题';

  @override
  String get themeSaveCurrent => '保存当前主题';

  @override
  String get themeApply => '应用';

  @override
  String get themeDelete => '删除';

  @override
  String themeDeleteConfirmMessage(String name) {
    return '确定要删除主题“$name”吗？';
  }

  @override
  String get textColorLowContrastWarning => '颜色对比度较低，可能影响可读性';

  @override
  String get themeCurrentTheme => '当前主题';

  @override
  String themeBasedOnModified(String baseName) {
    return '基于$baseName（已修改）';
  }

  @override
  String get themeResetToPreset => '重置';

  @override
  String get themeUnsavedChangesTitle => '未保存的修改';

  @override
  String get themeUnsavedChangesMessage => '当前主题有未保存的修改，是否保存？';

  @override
  String get themeDiscardAndApply => '放弃并应用';

  @override
  String get themeNameHint => '输入主题名称';

  @override
  String get themePresetBlue => '默认蓝';

  @override
  String get themePresetPurple => '暗夜紫';

  @override
  String get themePresetGreen => '森林绿';

  @override
  String get themePresetOrange => '暖阳橙';

  @override
  String get themePresetEyeCare => '护眼模式';

  @override
  String get themePresetHighContrast => '高对比度';

  @override
  String get themePresetDarkMinimal => '深色极简';

  @override
  String get themeUndo => '撤销';

  @override
  String themeChanged(String themeName) {
    return '已切换到 $themeName';
  }

  @override
  String get themeRename => '重命名';

  @override
  String get themeDuplicate => '复制';
}

/// The translations for Chinese, as used in Hong Kong (`zh_HK`).
class AppLocalizationsZhHk extends AppLocalizationsZh {
  AppLocalizationsZhHk() : super('zh_HK');

  @override
  String get appTitle => '輕嶼課表';

  @override
  String get appTitleDebug => '輕嶼課表偵錯版';

  @override
  String get appearanceTitle => '外觀與配色';

  @override
  String get previewTitle => '預覽';

  @override
  String get timetableBackgroundPreview => '課表背景';

  @override
  String get displayModeTitle => '顯示模式';

  @override
  String get displayModeSubtitle => '支持跟隨系統、淺色模式和深色模式。';

  @override
  String get themeModeLabel => '主題模式';

  @override
  String get themeModeSystem => '跟隨系統';

  @override
  String get themeModeLight => '淺色模式';

  @override
  String get themeModeDark => '深色模式';

  @override
  String get fontSectionTitle => '應用字體';

  @override
  String get fontSectionSubtitle => '支持系統預設字體和 MiSans。MiSans 不可用時會自動回退。';

  @override
  String get fontModeLabel => '字體選擇';

  @override
  String get fontModeSystem => '手機預設字體';

  @override
  String get fontModeMiSans => 'MiSans（優先）';

  @override
  String get languageSectionTitle => '應用語言';

  @override
  String get languageSectionSubtitle => '可跟隨系統，或手動切換到已適配語言。';

  @override
  String get languageModeLabel => '語言選擇';

  @override
  String get languageModeSystem => '跟隨系統';

  @override
  String get settingsTitle => '課表設定';

  @override
  String get dailyUsageSectionTitle => '日常使用';

  @override
  String get appearanceEntryTitle => '外觀與配色';

  @override
  String get appearanceEntrySubtitle => '主題色、課表背景、課程卡片顏色';

  @override
  String get layoutSectionEntryTitle => '布局與節次';

  @override
  String get layoutSectionEntrySubtitle => '節次時間、行高、時間列、周末顯示與卡片布局';

  @override
  String get homeWidgetEntryTitle => '桌面小組件';

  @override
  String get homeWidgetEntrySubtitle => '今日課程卡片、小組件背景與顯示資訊';

  @override
  String get reminderNotificationSectionTitle => '提醒與通知';

  @override
  String get userGuideEntryTitle => '使用引導與權限';

  @override
  String get userGuideEntrySubtitle => '簡稱建議、通知、自啟動、電池策略';

  @override
  String get timetableManagementSectionTitle => '課表管理';

  @override
  String get timeSchemeEntryTitle => '時間範本';

  @override
  String get timeSchemeEntrySubtitleNoneSelected => '切換、編輯節次、複製和管理時間範本';

  @override
  String timeSchemeEntrySubtitleSelected(String name) {
    return '目前：$name · 切換、編輯節次和複製';
  }

  @override
  String get dataTransferEntryTitle => '資料備份與遷移';

  @override
  String get dataTransferEntrySubtitle => '匯出完整課表檔案，給別人直接匯入使用';

  @override
  String get lanEditEntryTitle => '局域網編輯';

  @override
  String get lanEditEntrySubtitle => '在電腦瀏覽器中編輯當前課表';

  @override
  String get lanEditTitle => '局域網編輯';

  @override
  String get lanEditIntro =>
      '開啟後，同一 Wi-Fi 或手機熱點下的電腦可透過瀏覽器編輯當前課表。資料不會上傳雲端，關閉後即停止存取。';

  @override
  String get lanEditStart => '開啟局域網編輯';

  @override
  String get lanEditStop => '停止';

  @override
  String get lanEditStatusRunning => '編輯會話進行中';

  @override
  String get lanEditAddressLabel => '存取網址';

  @override
  String get lanEditAddressUnavailable => '未偵測到局域網 IP，請確認已連接 Wi-Fi 或已開啟熱點';

  @override
  String get lanEditPinLabel => 'PIN';

  @override
  String get lanEditPortLabel => '連接埠';

  @override
  String get lanEditCopyAddress => '複製網址';

  @override
  String get lanEditCopied => '網址已複製';

  @override
  String get lanEditHotspotHint => '若宿舍 Wi-Fi 無法存取，請嘗試用手機開熱點，再讓電腦連接該熱點。';

  @override
  String get lanEditQrHint => '電腦瀏覽器掃描上方二維碼可開啟控制台（連結已含 PIN，需同一區域網路）。';

  @override
  String get lanEditStartFailed => '啟動失敗';

  @override
  String get lanEditConnectedClientsLabel => '已連接';

  @override
  String get lanEditConnectedClientsNone => '暫無';

  @override
  String lanEditConnectedClientsValue(int count) {
    return '$count 台';
  }

  @override
  String get lanEditLastActivityLabel => '最近活動';

  @override
  String get aboutSupportSectionTitle => '關於與支持';

  @override
  String get feedbackEntryTitle => '問題回饋';

  @override
  String get feedbackEntrySubtitle => 'Issue、社区渠道和建議反饋入口';

  @override
  String get aboutEntryTitle => '關於軟件';

  @override
  String get aboutEntrySubtitle => '開源說明、版本更新和 GitHub 倉庫';

  @override
  String get setSemesterStartDateAction => '設定開學日期';

  @override
  String get semesterStartDateAction => '開學日期';

  @override
  String get syncCurrentWeekAction => '同步目前周';

  @override
  String semesterWeekCountAction(int count) {
    return '$count 周';
  }

  @override
  String get selectSemesterWeekCountTitle => '選擇學期周數';

  @override
  String get selectSemesterWeekCountSubtitle => '不同學校可按實際教學周數調整。';

  @override
  String get unifiedCourseCardColorTitle => '統一課程卡片顏色';

  @override
  String get unifiedCourseCardColorSubtitle => '關閉後繼續使用每門課程自己的顏色';

  @override
  String get courseImportTitle => '匯入課程';

  @override
  String get chooseImportMethodTitle => '選擇匯入方式';

  @override
  String get chooseImportMethodSubtitle =>
      '現在支持傳統 .ics 日歷匯入、識圖匯入，以及從倉庫讀取適配器的教務系統匯入。';

  @override
  String get importMethodIcsTitle => '.ics 日歷匯入';

  @override
  String get importMethodIcsSubtitle => '適合從 WakeUp 等課表應用匯出的日歷檔案，流程最短。';

  @override
  String get importMethodIcsFooter => '進入後直接選擇 .ics 檔案，可追加匯入或替換現有課程。';

  @override
  String get importMethodAiTitle => '識圖匯入';

  @override
  String get importMethodAiSubtitle => '適合直接從課表截圖匯入，支持 1 張或多張連續截圖。';

  @override
  String get importMethodAiFooter =>
      '先複製提示詞，再到豆包專家模式發送截圖和提示詞，把返回的 JSON 複製回來匯入，最後選擇開學日期。';

  @override
  String get importMethodWarehouseTitle => '教務系統匯入';

  @override
  String get importMethodWarehouseSubtitle =>
      '從 qingyu_warehouse 讀取學校與適配器，支持網頁登錄匯入課程。';

  @override
  String get importMethodWarehouseFooter => '進入後選擇學校和適配器，可直接打開教務網頁登錄並執行匯入。';

  @override
  String get importMethodSpreadsheetTitle => '表格匯入';

  @override
  String get importMethodSpreadsheetSubtitle =>
      '適合用 Excel/WPS 填寫輕嶼課表模板後匯入，無需先匯出 .ics。';

  @override
  String get importMethodSpreadsheetFooter =>
      '支持 .csv 與 .xlsx，可下載官方模板填寫後選擇檔案匯入。';

  @override
  String get spreadsheetImportTitle => '表格匯入';

  @override
  String get spreadsheetScenarioIntro =>
      '輕嶼模板依表頭辨識欄位：必填為課程名、星期、開始節、結束節及週次；其餘為可選。可下載完整模板，或只保留必要欄。亦相容 WakeUp 7 欄格式。';

  @override
  String get spreadsheetStep1Subtitle => '下載完整模板填寫，或只保留必填欄與上課週（或開始週+結束週）做最小匯入。';

  @override
  String get spreadsheetStep2Subtitle => '填寫完成後另存為 .csv 或直接保留 .xlsx。';

  @override
  String get spreadsheetStep3Subtitle => '選擇檔案匯入；如有識別提醒會先展示，再選擇追加或替換。';

  @override
  String get spreadsheetSupportedFilesSuffix => '支持 .csv 與 .xlsx（僅讀取第一個工作表）。';

  @override
  String get chooseSpreadsheetFileAction => '選擇表格檔案';

  @override
  String get downloadSpreadsheetTemplateAction => '下載輕嶼課表模板';

  @override
  String get spreadsheetImportWarningsTitle => '匯入提醒';

  @override
  String get spreadsheetImportWarningsMessage => '以下行未能匯入，其餘課程可繼續：';

  @override
  String get spreadsheetImportWarningsContinue => '繼續匯入';

  @override
  String get spreadsheetFormatUnrecognized =>
      '未識別表格格式，請使用輕嶼課表模板；也相容 WakeUp 等同列格式';

  @override
  String get icsImportTitle => '.ics 日歷匯入';

  @override
  String get applicableScenarioTitle => '適用場景';

  @override
  String get icsScenarioIntro =>
      '如果你已經能在 WakeUp 等課表應用裡匯入教務系統課程，再匯出為 .ics 檔案，這條路最穩。';

  @override
  String stepLabel(String step) {
    return '步骤 $step';
  }

  @override
  String get icsStep1Subtitle => '先在其他課表應用裡匯出 .ics 日歷檔案。';

  @override
  String get icsStep2Subtitle => '回到這裡選擇檔案，可選“追加匯入”或“替換現有”。';

  @override
  String get icsStep3Subtitle => '匯入前還會讓你確認開學日期，以及課表第 1 周對應校歷第几周。';

  @override
  String get supportedFilesTitle => '支持的檔案';

  @override
  String get supportedFilesSuffix => '檔案後綴必須是 .ics。';

  @override
  String get supportedFilesImageHint => '如果你手裡只有截圖，不要走這裡，請返回上一頁選擇“識圖匯入”。';

  @override
  String get chooseIcsFileAction => '選擇 .ics 檔案';

  @override
  String get timetableAppName => '輕嶼課表';

  @override
  String get switchProfileHint => '點擊切換課表';

  @override
  String get moreTooltip => '更多';

  @override
  String get pleaseSetSemesterStartDate => '請先在課表設定裡填寫開學日期';

  @override
  String get deleteScheduleTitle => '刪除日程';

  @override
  String get deleteLessonTitle => '刪除這節課';

  @override
  String get cancelAction => '取消';

  @override
  String get confirmAction => '確認';

  @override
  String get deleteAction => '刪除';

  @override
  String deletedCourseMessage(String name) {
    return '已刪除：$name';
  }

  @override
  String get deleteFailed => '刪除失敗';

  @override
  String get rescheduleFailed => '調課失敗';

  @override
  String get timetableManagement => '課表管理';

  @override
  String weekLabel(int week) {
    return '第 $week 周';
  }

  @override
  String sectionLabel(int section) {
    return '第 $section 節';
  }

  @override
  String get feedbackTitle => '問題回饋';

  @override
  String get feedbackIntro => '如果你遇到崩溃、課程顯示異常、匯入問題，或者想提交功能建議，可以通過下面這些渠道反饋。';

  @override
  String get feedbackIssueHint => '涉及複現步骤、截圖、版本號和日誌的問題，建議優先走 GitHub Issue。';

  @override
  String get githubIssueTitle => 'GitHub Issue';

  @override
  String get githubIssueSubtitle => '打開倉庫 Issue 頁面，可提交問題、建議或查看已有反饋記錄。';

  @override
  String get openIssuePage => '打開 Issue 頁面';

  @override
  String get copyAddress => '複製地址';

  @override
  String get copiedIssueAddress => '已複製 Issue 地址';

  @override
  String get copyXiaohongshuId => '複製小紅書號';

  @override
  String get copiedXiaohongshuId => '已複製小紅書號';

  @override
  String get copyCoolapkId => '複製酷安號';

  @override
  String get copiedCoolapkId => '已複製酷安號';

  @override
  String get copyQqGroupId => '複製群號';

  @override
  String get copiedQqGroupId => '已複製 QQ 群號';

  @override
  String get timetableProfilesTitle => '課表管理';

  @override
  String get createTimetableTooltip => '新建課表';

  @override
  String coursesAndWeekSummary(int count, int week) {
    return '$count 門課程 · 第 $week 周';
  }

  @override
  String get moreActionsTooltip => '更多操作';

  @override
  String get switchToThisTimetable => '切換到此課表';

  @override
  String get renameAction => '重新命名';

  @override
  String get duplicateAction => '複製';

  @override
  String get clearCoursesAction => '清空課程';

  @override
  String get usingNow => '正在使用';

  @override
  String switchedToProfile(String name) {
    return '已切換到 $name';
  }

  @override
  String get createTimetableTitle => '新建課表';

  @override
  String get timetableNameLabel => '課表名稱';

  @override
  String get timetableNameHint => '例如：大二下';

  @override
  String get createAction => '建立';

  @override
  String createdProfile(String name) {
    return '已建立課表：$name';
  }

  @override
  String get renameTimetableTitle => '重新命名課表';

  @override
  String get saveAction => '保存';

  @override
  String renamedProfile(String name) {
    return '已重新命名為 $name';
  }

  @override
  String get clearCurrentTimetableTitle => '清空目前課表';

  @override
  String clearCurrentTimetableMessage(String name) {
    return '確定清空“$name”的全部課程嗎？課表設定會保留。';
  }

  @override
  String get clearAction => '清空';

  @override
  String clearedProfile(String name) {
    return '已清空課表：$name';
  }

  @override
  String get noCoursesInCurrentProfile => '目前課表已經沒有有課程';

  @override
  String get deleteTimetableTitle => '刪除課表';

  @override
  String deleteTimetableMessage(String name) {
    return '確定刪除“$name”嗎？';
  }

  @override
  String deletedProfile(String name) {
    return '已刪除課表：$name';
  }

  @override
  String get keepAtLeastOneProfile => '至少保留一個課表';

  @override
  String get dataTransferTitle => '資料備份與遷移';

  @override
  String get fullExportTitle => '完整匯出';

  @override
  String get fullExportSubtitle => '支持匯出目前課表，或一次匯出全部課表、時間範本和目前選中狀態。';

  @override
  String get exportCurrentTimetable => '匯出目前課表';

  @override
  String get exportAllData => '匯出全部資料';

  @override
  String get fullImportTitle => '完整匯入';

  @override
  String get fullImportSubtitle => '匯入時可以選擇覆蓋目前課表，或直接匯入為一個新課表。建議先匯出自己的備份。';

  @override
  String get chooseFileAndImport => '選擇檔案並匯入';

  @override
  String get transferOverviewTitle => '目前可遷移內容';

  @override
  String courseCountBullet(int count) {
    return '課程數量：$count 門';
  }

  @override
  String currentTimetableBullet(String name) {
    return '目前課表：$name';
  }

  @override
  String allTimetablesBullet(int count) {
    return '全部課表：$count 個';
  }

  @override
  String timeSchemeCountBullet(int count) {
    return '時間範本：$count 套';
  }

  @override
  String currentWeekBullet(int week) {
    return '目前周：第 $week 周';
  }

  @override
  String get semesterStartUnsetBullet => '開學日期：未設定';

  @override
  String semesterStartBullet(String date) {
    return '開學日期：$date';
  }

  @override
  String fileExtensionBullet(String extension) {
    return '檔案後綴：.$extension';
  }

  @override
  String get selectImportModeTitle => '選擇匯入方式';

  @override
  String get selectImportModeMessage => '你可以覆蓋目前課表，或者把備份匯入成一個新的独立課表。';

  @override
  String get replaceCurrentTimetable => '覆蓋目前課表';

  @override
  String get importAsNewTimetable => '匯入為新課表';

  @override
  String get createdNewTimetableAfterImport => '匯入成功，已建立新的課表';

  @override
  String get backupRestoredSuccess => '匯入成功，備份資料已還原';

  @override
  String get importFailedInvalidFile => '匯入失敗，請確認檔案有效';

  @override
  String get welcomeTitle => '歡迎使用';

  @override
  String get welcomeAppName => '輕嶼課表';

  @override
  String get welcomeSubtitle => '你可以先開始使用，也可以直接匯入課程或從備份還原。';

  @override
  String get startUsingTitle => '開始使用';

  @override
  String get startUsingSubtitle => '直接進入軟件，並繼續完成首次使用說明';

  @override
  String get importTimetableTitle => '匯入課表';

  @override
  String get importTimetableSubtitle => '從 .ics 檔案或 AI 解析結果匯入課程';

  @override
  String get restoreBackupTitle => '從備份還原';

  @override
  String get restoreBackupSubtitle => '從 .mikcb 備份檔案還原舊資料';

  @override
  String get viewGuideTitle => '查看功能說明';

  @override
  String get viewGuideSubtitle => '先了解權限、超級島和基础設定';

  @override
  String get migrationTitle => '遷移舊資料';

  @override
  String get migrationSafeTitle => '別擔心，這不是資料丢失';

  @override
  String get migrationSafeSubtitle =>
      '我們更換了應用包名，所以桌面上會暫時出現兩個應用圖示，這是正常現象。舊資料仍在舊版應用裡，請先去舊版備份，再回到新版匯入。';

  @override
  String get migrationStep1Title => '打開舊版應用';

  @override
  String get migrationStep1Subtitle =>
      '進入“資料備份與遷移”頁面後，請點“匯出全部資料”。不要點“匯出目前課表”，也不要先卸載舊版。';

  @override
  String get migrationStep2Title => '保存備份檔案';

  @override
  String get migrationStep2Subtitle =>
      '舊版匯出後會彈出系統分享面板。優先選擇“保存到檔案”，建議存到 下載 / Download 檔案夾。';

  @override
  String get migrationStep3Title => '回到目前版本匯入';

  @override
  String get migrationStep3Subtitle =>
      '回到新版後，通過系統檔案選擇器到 下載 / Download 檔案夾選中 .mikcb 備份檔案即可還原。確認新版資料正常後，再卸載舊版應用。';

  @override
  String get migrationNoSaveToFilesTitle => '如果沒有有“保存到檔案”';

  @override
  String get migrationNoSaveToFilesSubtitle =>
      '可以先分享到微信任意一個聊天，然後在微信裡點開這個備份檔案並保存。保存後通常會出現在 Download / WeiXin 檔案夾裡，再回到新版選擇這個 .mikcb 檔案匯入。';

  @override
  String get openingOldApp => '正在打開舊版...';

  @override
  String get openOldAppForBackup => '打開舊版去備份';

  @override
  String get backupDoneGoImport => '我已完成備份，去匯入';

  @override
  String get startFreshWithoutMigration => '以全新應用開始，不遷移';

  @override
  String get openOldAppFailed => '未能打開舊版應用，請手動返回桌面打開舊版';

  @override
  String get supportCreatorTitle => '請作者喝杯咖啡';

  @override
  String get supportHeroTitle => '支持輕嶼課表繼續更新';

  @override
  String get supportHeroSubtitle => '你的支持會直接用於維護課表、教務匯入適配與體驗優化。';

  @override
  String get supportChipFixes => '修複問題';

  @override
  String get supportChipAdapters => '教務適配';

  @override
  String get supportChipPolish => '體驗優化';

  @override
  String get supportMethodTitle => '選擇支持方式';

  @override
  String get wechatLabel => '微信';

  @override
  String get alipayLabel => '支付寶';

  @override
  String get supportWeChatHint => '使用微信掃一掃支持作者';

  @override
  String get supportAlipayHint => '使用支付寶掃一掃支持作者';

  @override
  String get viewLargeImage => '查看大圖';

  @override
  String get saveToGallery => '保存到相冊';

  @override
  String get supportCompleteThanks => '感谢你支持輕嶼課表繼續打磨 ❤️';

  @override
  String get supportConfirmed => '我已經支持了';

  @override
  String get donorListTitle => '鳴谢名單';

  @override
  String get donorListLoadFailed => '暫時無法加載在線鳴谢名單。';

  @override
  String get reloadAction => '重新加載';

  @override
  String updatedAtLabel(String time) {
    return '更新於 $time';
  }

  @override
  String get donorListEmpty => '名單還沒有有填寫，你可以直接編輯 docs/donors.json 後重新發布。';

  @override
  String get savedToGallery => '已保存到相冊';

  @override
  String get saveToGalleryFailed => '保存到相冊失敗';

  @override
  String saveFailedWithError(String error) {
    return '保存失敗：$error';
  }

  @override
  String get courseOverviewTitle => '課程總覽與編輯';

  @override
  String get addNewCourseTooltip => '添加新課程';

  @override
  String get emptyCourseOverviewHint => '長按課表或點擊右上角添加課程';

  @override
  String conflictDetectedMessage(int count) {
    return '檢測到 $count 門排課存在實際衝突，課程列表已標記衝突項。';
  }

  @override
  String conflictCountLabel(int count) {
    return '衝突 $count 節';
  }

  @override
  String scheduledCountLabel(int count) {
    return '共排課 $count 節';
  }

  @override
  String scheduledCountWithConflictHint(int count) {
    return '共排課 $count 節 · 展開查看衝突詳情';
  }

  @override
  String courseTimeSummary(int day, int start, int end) {
    return '時間: 星期$day 第$start-$end節';
  }

  @override
  String get teacherUnset => '未置';

  @override
  String get locationUnset => '未置';

  @override
  String courseDetailSummary(
    String weekDescription,
    String teacher,
    String location,
  ) {
    return '$weekDescription  教師: $teacher  教室: $location';
  }

  @override
  String courseDetailSummaryWithConflict(
    String weekDescription,
    String teacher,
    String location,
    String conflictSummary,
  ) {
    return '$weekDescription  教師: $teacher  教室: $location\n衝突課程: $conflictSummary';
  }

  @override
  String get confirmDeleteTitle => '確認刪除';

  @override
  String confirmDeleteCourseMessage(String name) {
    return '確定要刪除課程“$name”嗎？';
  }

  @override
  String get currentScheduleTitle => '目前排課';

  @override
  String get currentScheduleSubtitle => '這裡的星期、節次、教室、周次和單雙周只影響目前這一條排課。';

  @override
  String get timeSchemeLabel => '上課時間方案';

  @override
  String followCurrentTimetableWithName(String name) {
    return '跟隨目前課表（$name）';
  }

  @override
  String get followCurrentTimetableDescription => '預設跟隨目前課表主時間範本，適合大多數課程。';

  @override
  String get overrideTimeSchemeDescription => '這門課會單独使用所選時間範本，不跟隨目前課表主時間範本。';

  @override
  String get weekdayLabel => '星期';

  @override
  String get startSectionLabel => '開始節次';

  @override
  String get endSectionLabel => '結束節次';

  @override
  String timeRangeLabel(String start, String end) {
    return '時間: $start - $end';
  }

  @override
  String get locationLabel => '上課地點';

  @override
  String get singleLessonWeekTitle => '上課周次';

  @override
  String get singleLessonWeekSubtitle => '單節課只會出現在一個周次裡，適合補課、臨時加課。';

  @override
  String get selectWeekLabel => '選擇周次';

  @override
  String get weekSettingsTitle => '周次設定';

  @override
  String get rangeWeeksLabel => '連續周';

  @override
  String get customWeeksLabel => '自定義周';

  @override
  String get startWeekLabel => '開始周';

  @override
  String get endWeekLabel => '結束周';

  @override
  String get allWeeksFilter => '全部';

  @override
  String get oddWeeksFilter => '單周';

  @override
  String get evenWeeksFilter => '雙周';

  @override
  String get rangeWeeksAllHint => '按開始周到結束周連續排課。';

  @override
  String get rangeWeeksOddHint => '只保留范圍內的單周。';

  @override
  String get rangeWeeksEvenHint => '只保留范圍內的雙周。';

  @override
  String get selectAllAction => '全選';

  @override
  String get selectOddWeeksAction => '單周';

  @override
  String get selectEvenWeeksAction => '雙周';

  @override
  String selectedWeeksSummary(int count, String weeks) {
    return '已選 $count 周：第$weeks周';
  }

  @override
  String get courseColorTitle => '課程顏色';

  @override
  String get customPaletteAction => '調色盤自定義顏色';

  @override
  String get colorPaletteTitle => '調色盤';

  @override
  String get colorHexLabel => '顏色 Hex';

  @override
  String get weekdayMon => '周一';

  @override
  String get weekdayTue => '周二';

  @override
  String get weekdayWed => '周三';

  @override
  String get weekdayThu => '周四';

  @override
  String get weekdayFri => '周五';

  @override
  String get weekdaySat => '周六';

  @override
  String get weekdaySun => '周日';

  @override
  String hueLabel(int value) {
    return '色相 $value';
  }

  @override
  String saturationLabel(int value) {
    return '饱和度 $value%';
  }

  @override
  String brightnessLabel(int value) {
    return '明度 $value%';
  }

  @override
  String get useThisColor => '使用這個顏色';

  @override
  String get selectAtLeastOneWeek => '請至少選擇一個上課周次';

  @override
  String get saveFailed => '保存失敗';

  @override
  String get courseAddedSuccess => '課程添加成功';

  @override
  String get courseUpdatedSuccess => '課程更新成功';

  @override
  String get aboutTitle => '關於軟件';

  @override
  String get loadingText => '讀取中';

  @override
  String versionLabel(String version) {
    return '版本 $version';
  }

  @override
  String get aboutHeroSubtitle =>
      '一個圍繞課表查看、課程提醒和 HyperOS 超級島體驗打磨的 Android 開源項目。';

  @override
  String get platformLabel => '平台';

  @override
  String get focusLabel => '重點';

  @override
  String get updateLabel => '更新';

  @override
  String get prereleaseIncluded => '含預發布';

  @override
  String get stableOnly => '正式版';

  @override
  String get aboutUpdatesTitle => '版本更新';

  @override
  String get aboutUpdatesSubtitle => '檢查更新、立即下載，以及測試與診斷入口';

  @override
  String get aboutChangelogTitle => '更新日誌';

  @override
  String get aboutChangelogSubtitle => '查看所有版本的更新內容';

  @override
  String get aboutPositioningTitle => '項目定位';

  @override
  String get aboutPositioningSubtitle => '這是什麼、適合誰、核心能力是什麼';

  @override
  String get aboutPositioningBullet1 => '支持周視圖課表、課程增刪改、.ics 匯入';

  @override
  String get aboutPositioningBullet2 => '已支持適配學校的教務系統網頁登錄匯入與完整備份遷移';

  @override
  String get aboutPositioningBullet3 =>
      '支持實時通知；HyperOS 3.0.300 起支持超級島 / 焦點通知展示';

  @override
  String get aboutPositioningBullet4 => '支持多課表、時間範本、主題色和卡片樣式自定義';

  @override
  String get aboutImportMigrationTitle => '匯入與遷移';

  @override
  String get aboutImportMigrationSubtitle => '目前匯入方式、備份還原和遷移建議';

  @override
  String get aboutImportMigrationBullet1 =>
      '目前版本已經支持適配學校的教務系統網頁登錄匯入；進入“匯入課程 > 教務系統匯入”後選擇學校和適配器即可。';

  @override
  String get aboutImportMigrationBullet2 =>
      '如果你的學校暫時還沒有適配，仍然可以先在 WakeUp 等課表應用裡匯入課程，再匯出為日歷格式，然後在本應用匯入。';

  @override
  String get aboutImportMigrationBullet3 =>
      '如果其他人已經在用本應用，也可以直接讓對方匯出完整備份檔案，你在“資料備份與遷移”裡匯入即可直接還原。';

  @override
  String get aboutImportMigrationBullet4 =>
      '如果你會抓包、網頁偵錯或 JavaScript，也歡迎去 qingyu_warehouse 參與教務適配補充。';

  @override
  String get aboutContributorsTitle => '代碼貢獻者';

  @override
  String get aboutContributorsSubtitle => '開發人員與教務匯入適配者名單';

  @override
  String get aboutRepositoryTitle => '開源倉庫';

  @override
  String get aboutAppLogsTitle => '應用日誌';

  @override
  String get aboutAppLogsSubtitle =>
      '查看整個軟件的 error / warn / info / debug / verbose 全等級日誌';

  @override
  String get appLogsShareText =>
      '這是輕嶼課表匯出的應用日誌，包含整個軟件的本地運行記錄，可用於排查更新、匯入、通知、頁面與崩潰問題。';

  @override
  String get appLogsShareSubject => '輕嶼課表 - 應用日誌';

  @override
  String get appLogsRecordingEnabled => '正在記錄應用日誌';

  @override
  String get appLogsRecordingDisabled => '應用日誌記錄已關閉';

  @override
  String get appLogsCopyAction => '複製日誌';

  @override
  String get appLogsCopied => '已複製目前日誌';

  @override
  String get appLogsExportAction => '導出日誌';

  @override
  String get appLogsClearAction => '清空日誌';

  @override
  String get appLogsCleared => '已清空應用日誌';

  @override
  String get appLogsClearFailed => '清空應用日誌失敗';

  @override
  String get aboutRepositorySubtitle => 'GitHub 倉庫地址、源碼、Release 和反饋入口';

  @override
  String get timeSchemeTitle => '時間範本';

  @override
  String get newSchemeTooltip => '新建範本';

  @override
  String timeSchemeSummary(
    int sections,
    int profiles,
    int courses,
    int overrideCourses,
  ) {
    return '$sections 節 · $profiles 個課表 · $courses 節課程 · $overrideCourses 節副時間表';
  }

  @override
  String get viewUsageAction => '查看使用情況';

  @override
  String get applyToCurrentTimetable => '應用到目前課表';

  @override
  String get editSectionsAction => '編輯節次';

  @override
  String get createTimeSchemeTitle => '新建時間範本';

  @override
  String get timeSchemeNameLabel => '範本名稱';

  @override
  String get timeSchemeNameHint => '例如：本校夏季作息';

  @override
  String get renameTimeSchemeTitle => '重新命名時間範本';

  @override
  String renamedToMessage(String name) {
    return '已重新命名為 $name';
  }

  @override
  String get deleteTimeSchemeTitle => '刪除時間範本';

  @override
  String deleteTimeSchemeMessage(String name) {
    return '確定刪除“$name”嗎？正在使用中的範本不能刪除。';
  }

  @override
  String deletedTimeSchemeMessage(String name) {
    return '已刪除時間範本：$name';
  }

  @override
  String get timeSchemeInUseMessage => '該範本正在被課表使用';

  @override
  String get copiedTimeSchemeMessage => '已複製時間範本';

  @override
  String appliedTimeSchemeMessage(String name) {
    return '已應用時間範本：$name';
  }

  @override
  String timeSchemeUsageTitle(String name) {
    return '“$name”的使用情況';
  }

  @override
  String get timeSchemeUsageIntro => '先看總影響范圍，再決定是直接編輯這套範本，還是先複製一套再改。';

  @override
  String get profileCountLabel => '課表';

  @override
  String get courseCountLabel => '課程';

  @override
  String get overrideTimeSchemeLabel => '副時間表';

  @override
  String get directlyBoundProfilesTitle => '直接綁定這套範本的課表';

  @override
  String get directlyBoundProfilesEmpty => '目前沒有有課表直接使用這套範本。';

  @override
  String get directlyBoundProfilesSubtitle => '這些課表切到這套範本後，預設都會按這套節次時間顯示。';

  @override
  String get followMainSchemeCoursesTitle => '跟隨課表主時間表的課程';

  @override
  String get followMainSchemeCoursesEmpty => '目前沒有有課程通過課表主時間表間接使用它。';

  @override
  String get followMainSchemeCoursesSubtitle =>
      '這些課程沒有有單独設定副時間表，而是跟著所屬課表一起用這套範本。';

  @override
  String get overrideSchemeCoursesTitle => '把它作為副時間表的課程';

  @override
  String get overrideSchemeCoursesEmpty => '目前沒有有課程把它作為副時間表。';

  @override
  String get overrideSchemeCoursesSubtitle => '這些課程即使所在課表切換了主範本，也會繼續單独使用這套時間。';

  @override
  String get closeAction => '關閉';

  @override
  String get editTimeSchemeTitle => '編輯時間範本';

  @override
  String get backToSchemeList => '返回範本列表';

  @override
  String get currentInUse => '目前使用';

  @override
  String get quickGenerateAction => '快捷生成';

  @override
  String get addSectionAction => '新增一節';

  @override
  String get removeLastSectionAction => '刪除末節';

  @override
  String get resetDefaultAction => '還原預設';

  @override
  String get sectionTimesTitle => '節次時間';

  @override
  String get sectionTimesSubtitle => '如果目前課表正在使用這套範本，節次數量不能小於已使用的最大節次。';

  @override
  String get schemeListCurrentLabel => '目前';

  @override
  String get schemeListCountLabel => '數量';

  @override
  String get sectionCountLabel => '節數';

  @override
  String get quickGenerateTimeSchemeTitle => '快捷生成課表時間';

  @override
  String get addBreakRuleAction => '新增大課間規則';

  @override
  String get afterSectionLabel => '第几節後';

  @override
  String get breakDurationMinutesLabel => '休息多久(分)';

  @override
  String get fillNumbersValidationMessage => '請把節數和時長填寫為數字';

  @override
  String get timeSchemeEditorActiveAndCoursesHint =>
      '目前課表和部分課程正在使用這套時間範本，保存後會同步更新所有相關課表和課程。';

  @override
  String get timeSchemeEditorActiveHint => '目前課表正在使用這套時間範本，保存後會同步更新所有使用它的課表。';

  @override
  String get timeSchemeEditorOverrideHint =>
      '有課程正在把這套範本作為副時間表使用，保存後會同步更新所有引用課程。';

  @override
  String get editTimeAction => '編輯時間';

  @override
  String editingSchemeLabel(String name) {
    return '正在編輯：$name';
  }

  @override
  String get copiedTimeSchemeShortMessage => '已複製時間範本';

  @override
  String get unnamedTimeScheme => '未命名範本';

  @override
  String get unsetLabel => '未選擇';

  @override
  String get timeSchemeUsageCourseRefPrefix => '課程引用：';

  @override
  String get mainTimeSchemeLabel => '主時間表';

  @override
  String get overrideTimeSchemeShortLabel => '副時間表';

  @override
  String timeSchemeBottomUsageSingle(String first) {
    return '$first';
  }

  @override
  String timeSchemeBottomUsageMulti(String first, int count) {
    return '$first 等 $count 節課程';
  }

  @override
  String get morningSectionCountLabel => '上午几節';

  @override
  String get morningFirstSectionTimeLabel => '早上第一節時間';

  @override
  String get afternoonSectionCountLabel => '下午几節';

  @override
  String get afternoonFirstSectionTimeLabel => '下午第一節時間';

  @override
  String get eveningSectionCountLabel => '晚上几節';

  @override
  String get eveningFirstSectionTimeLabel => '晚上第一節時間';

  @override
  String get classDurationMinutesLabel => '單節課時長（分鐘）';

  @override
  String get smallBreakDurationMinutesLabel => '小課間時長（分鐘）';

  @override
  String get largeBreakRulesTitle => '大課間規則';

  @override
  String get noLargeBreakRulesHint => '未設定大課間規則，將全部使用小課間時長。';

  @override
  String get deleteRuleTooltip => '刪除規則';

  @override
  String get generateAction => '生成';

  @override
  String get liveSettingsTitle => '超級島與通知';

  @override
  String get liveReminderTimingEntryTitle => '提醒時段';

  @override
  String get liveReminderTimingEntrySubtitle =>
      '上課前、課中/下課提醒開關，以及下課前多久切到超級島 / 重點提醒';

  @override
  String get liveBeforeClassDisplayEntryTitle => '上課前提醒顯示';

  @override
  String get liveDuringEndDisplayEntryTitle => '課中/下課提醒顯示';

  @override
  String get liveKeepAliveEntryTitle => '後台保活';

  @override
  String get liveKeepAliveEntrySubtitle => '隱藏後台、後台保活輔助服務和權限入口';

  @override
  String get liveTestingEntryTitle => '測試與診斷';

  @override
  String get liveTestingEntrySubtitle => '發送測試通知，檢查超級島和本地診斷日誌';

  @override
  String get followBeforeClassSetting => '跟隨上課前提醒';

  @override
  String get liveReminderTimingTitle => '提醒時段';

  @override
  String get liveReminderSwitchesTitle => '提醒開關';

  @override
  String get liveReminderSwitchesSubtitle => '不同提醒時段可以自由組合；這些開關互不替代。';

  @override
  String get beforeClassReminderTitle => '上課前提醒';

  @override
  String beforeClassReminderSubtitle(int minutes) {
    return '在課程開始前 $minutes 分鐘彈出';
  }

  @override
  String get duringClassReminderTitle => '課中 / 下課提醒';

  @override
  String get duringClassReminderSubtitle => '只影響上課後到下課前的展示';

  @override
  String get liveClassReminderLeadTitle => '下課前多久切到超級島 / 重點提醒';

  @override
  String get liveClassReminderLeadOptionImmediate => '一上課就切換';

  @override
  String liveClassReminderLeadOptionMinutes(int minutes) {
    return '下課前 $minutes 分鐘切換';
  }

  @override
  String get liveDisplayModeTitle => '展示方式';

  @override
  String get liveDisplayModeSubtitle => '對已啟用的提醒時段生效。';

  @override
  String get duringClassStatusNotificationTitle => '課中狀態栏通知';

  @override
  String get duringClassStatusNotificationImmediate => '上課後保留狀態栏通知';

  @override
  String get duringClassStatusNotificationBeforeEnd => '在下課提醒開始前保留普通通知文案';

  @override
  String get duringClassStatusNotificationPersistent =>
      '上課後持續顯示普通課中通知，到下課提醒前再切換';

  @override
  String get enableIslandDisplayTitle => '支持展示超級島/靈動島';

  @override
  String get enableIslandDisplaySubtitle => '關閉後不會再尝試觸發系統超級島';

  @override
  String get liveTimeThresholdTitle => '時間阈值';

  @override
  String get liveTimeThresholdSubtitle =>
      '控製上課前彈出、下課前多久切到超級島 / 重點提醒，以及最後秒級倒計時。';

  @override
  String get beforeClassPopupLabel => '上課前彈出時間';

  @override
  String beforeClassMinutesOption(int minutes) {
    return '$minutes 分鐘';
  }

  @override
  String get beforeEndSecondsLabel => '下課前秒級提醒阈值';

  @override
  String beforeEndSecondsOption(int seconds) {
    return '$seconds 秒';
  }

  @override
  String timeCorrectionLabel(String value) {
    return '鈴声時間矯正：$value';
  }

  @override
  String get timeCorrectionHelp => '如果學校鈴声比課表快几秒，就調成提前；如果鈴声慢几秒，就調成延後。';

  @override
  String get duringEndTimeDisplayLabel => '課中 / 下課提醒時間樣式';

  @override
  String get duringEndTimeDisplayHelp => '控製緊湊提醒裡顯示最近時間還是整段總時間。';

  @override
  String get liveDisplayContentTitle => '顯示內容';

  @override
  String get liveDisplayContentSubtitle => '這組設定只影響目前階段，不會改動另一組提醒顯示。';

  @override
  String get showCourseNameTitle => '顯示課程名';

  @override
  String get preferShortNameTitle => '優先顯示課程簡稱';

  @override
  String get preferShortNameSubtitle => '建議簡稱控製在 3 個字以內';

  @override
  String get showLocationTitle => '顯示地點';

  @override
  String get showCountdownTitle => '顯示倒計時';

  @override
  String get countdownFormatLabel => '倒計時格式';

  @override
  String get countdownFormatHelp => '純分鐘樣式按分鐘刷新，帶秒樣式按秒刷新';

  @override
  String get showStageTextTitle => '顯示階段狀態文案';

  @override
  String get showStageTextSubtitle => '關閉倒計時後，可繼續顯示“即將上課 / 上課中 / 下課提醒”';

  @override
  String get hidePrefixTextTitle => '隱藏前綴文案';

  @override
  String get hidePrefixTextSubtitle => '例如隱藏“即將上課”這類前綴';

  @override
  String get beforeClassQuickActionTitle => '上課前快捷操作';

  @override
  String get beforeClassQuickActionSubtitle =>
      '只在上課前提醒的展開通知裡顯示。免打擾首次可能會跳到系統授權頁。';

  @override
  String liveMiuiLabelSizePreview(String value) {
    return '$value';
  }

  @override
  String get liveIslandVisualTitle => '左側圖示與展開態';

  @override
  String get liveIslandVisualSubtitle => '左側文字圖、展開態大圖示和自定義圖片都按目前階段單独保存。';

  @override
  String get liveMiuiLabelImageTitle => '小米島左側文字圖示';

  @override
  String get liveMiuiLabelImageSubtitle => '僅小米手機樣式生效，會把課程名或地點生成到左側圖示位。';

  @override
  String get liveMiuiLabelContentLabel => '左側文字內容';

  @override
  String get liveMiuiLabelStyleLabel => '左側圖示樣式';

  @override
  String get liveMiuiLabelLogoTitle => '左側圖示 Logo';

  @override
  String get liveMiuiLabelLogoSubtitle => '僅在「圖示+文字」樣式下生效；未選擇時會繼續使用應用圖示。';

  @override
  String liveMiuiLabelLogoCornerRadiusLabel(String value) {
    return '左側圖示圓角 $value';
  }

  @override
  String liveMiuiLabelFontSizeLabel(String value) {
    return '左側文字大小 $value';
  }

  @override
  String liveMiuiLabelOffsetXLabel(String value) {
    return '左側文字水平偏移 $value';
  }

  @override
  String liveMiuiLabelOffsetYLabel(String value) {
    return '左側文字垂直偏移 $value';
  }

  @override
  String get liveMiuiLabelFontWeightLabel => '左側文字粗細';

  @override
  String get liveMiuiLabelRenderQualityLabel => '左側文字清晰度';

  @override
  String get liveMiuiExpandedIconLabel => '展開態大圖示';

  @override
  String get selectImageAction => '選擇圖片';

  @override
  String get replaceImageAction => '更換圖片';

  @override
  String get liveDisplayConfigModeTitle => '配置方式';

  @override
  String get liveDisplayConfigModeSubtitle =>
      '打開後，課中和下課提醒會完全跟隨上課前提醒顯示，下面的独立設定暫時不可編輯。';

  @override
  String get followBeforeClassDisplayTitle => '跟隨上課前提醒設定';

  @override
  String get liveKeepAliveTitle => '後台保活';

  @override
  String get liveKeepAliveOptionsTitle => '保活選項';

  @override
  String get liveKeepAliveOptionsSubtitle => '用於提升超級島和提醒在後台場景下的穩定性。';

  @override
  String get hideFromRecentsTitle => '從最近任務中隱藏應用';

  @override
  String get hideFromRecentsSubtitle => '開啟後應用會尽量不顯示在最近任務列表中。';

  @override
  String get keepAliveServiceTitle => '輕嶼課表後台保活服務';

  @override
  String get keepAliveServiceEnabledSubtitle => '目前已開啟。系統會保持後台保活輔助服務處於可用狀態。';

  @override
  String get keepAliveServiceDisabledSubtitle =>
      '目前未開啟。可進入系統無障礙設定手動打開輕嶼課表後台保活服務。';

  @override
  String get goEnableAction => '去開啟';

  @override
  String get layoutEntryTitle => '布局與節次';

  @override
  String get layoutEntrySubtitle => '節次時間、行高、時間列、周末顯示與卡片布局';

  @override
  String get remindersSectionTitle => '提醒與通知';

  @override
  String get liveGuideEntryTitle => '使用引導與權限';

  @override
  String get liveGuideEntrySubtitle => '簡稱建議、通知、自啟動、電池策略';

  @override
  String get managementSectionTitle => '課表管理';

  @override
  String timeSchemeEntryCurrentPrefix(String name) {
    return '目前：$name · 切換、編輯節次和複製';
  }

  @override
  String get timeSchemeEntrySubtitle => '切換、編輯節次、複製和管理時間範本';

  @override
  String semesterOverviewCurrentWeek(int current, int total) {
    return '目前第 $current 周 / 共 $total 周';
  }

  @override
  String get semesterStartUnset => '未設定開學日期';

  @override
  String semesterStartSet(String date) {
    return '開學日期：$date';
  }

  @override
  String get setSemesterStartDate => '設定開學日期';

  @override
  String get semesterStartDateLabel => '開學日期';

  @override
  String syncedCurrentWeekMessage(int week) {
    return '已同步到第 $week 周';
  }

  @override
  String get pickSemesterWeekCountTitle => '選擇學期周數';

  @override
  String get pickSemesterWeekCountSubtitle => '不同學校可按實際教學周數調整。';

  @override
  String weekCountItem(int count) {
    return '$count 周';
  }

  @override
  String get diagnosticsLogIntro => '支持 Markdown 與原文兩種查看方式，排查時可以直接在手機上看完整日誌。';

  @override
  String get diagnosticsRawTab => '原文';

  @override
  String get diagnosticsStructuredTab => '結構化';

  @override
  String get diagnosticsLevelLabel => '等級';

  @override
  String get diagnosticsLevelAll => '全部';

  @override
  String get diagnosticsLevelError => '錯誤';

  @override
  String get diagnosticsLevelWarn => '警告';

  @override
  String get diagnosticsLevelInfo => '資訊';

  @override
  String get diagnosticsLevelDebug => '除錯';

  @override
  String get diagnosticsLevelVerbose => '詳細';

  @override
  String diagnosticsShowingCount(int shown, int total) {
    return '顯示 $shown / $total 條日誌';
  }

  @override
  String get diagnosticsNoMatchingTitle => '目前篩選下沒有日誌';

  @override
  String get diagnosticsNoMatchingSubtitle => '可切換回「全部」，或改看原文繼續排查。';

  @override
  String get diagnosticsLevelInferred => '推斷等級';

  @override
  String get diagnosticsRawFilteredHint => '原文視圖會跟隨目前等級篩選，只顯示對應日誌區塊。';

  @override
  String get diagnosticsEmptyTitle => '暫無日誌';

  @override
  String get diagnosticsEmptySubtitle => '目前沒有有可顯示的超級島診斷日誌。';

  @override
  String get diagnosticsLogTitleFallback => '超級島診斷日誌';

  @override
  String get diagnosticsDeviceInfoTitle => '設備與匯出資訊';

  @override
  String get diagnosticsContentTitle => '日誌內容';

  @override
  String get diagnosticsRecentLogsTitle => '最近日誌';

  @override
  String get diagnosticsUnknownCategory => '未分類事件';

  @override
  String get diagnosticsExportedAt => '匯出時間';

  @override
  String get diagnosticsTime => '時間';

  @override
  String get diagnosticsCategory => '類別';

  @override
  String get diagnosticsMessage => '消息';

  @override
  String get diagnosticsStackTrace => '堆棧';

  @override
  String get firstUseGuideTitle => '首次使用引導';

  @override
  String get guideAndPermissionsTitle => '使用引導與權限';

  @override
  String get refreshStatusTooltip => '刷新狀態';

  @override
  String get guideHeroTitle => '先把這頁做完，再開始用';

  @override
  String get guideHeroSubtitle => '首屏先授權。下面還會明確說明系統版本支持、簡稱設定和匯入方式，記得繼續下滑。';

  @override
  String get guideChipPermissions => '權限準備';

  @override
  String get guideChipShortName => '簡稱設定';

  @override
  String get guideChipImport => '匯入課表';

  @override
  String guideChipReadyCount(int count) {
    return '$count/3 已完成';
  }

  @override
  String get guideBottomReachedHint => '你已經滑到最後了，確認無誤後就可以開始使用。';

  @override
  String get guideScrollHint => '向下滑動繼續，下面還有 HyperOS 版本說明、權限清單、簡稱設定和匯入方式。';

  @override
  String get guideRequestNotificationFirst => '先申請通知權限';

  @override
  String get quickSetupTitle => '首屏快速設定';

  @override
  String get quickSetupSubtitle => '先把最關鍵的 5 個入口放在前面，不用翻到下面再找。';

  @override
  String get quickActionNotificationsTitle => '通知設定';

  @override
  String get quickActionNotificationsSubtitle => '先確保能發通知';

  @override
  String get quickActionIslandTitle => '超級島權限';

  @override
  String get quickActionIslandSubtitle => '檢查 promoted 通知';

  @override
  String get quickActionAutoStartTitle => '自啟動';

  @override
  String get quickActionAutoStartSubtitle => '避免後台被殺';

  @override
  String get quickActionBatteryTitle => '電池無限製';

  @override
  String get quickActionBatterySubtitle => '避免提醒中斷';

  @override
  String get quickActionKeepAliveTitle => '後台保活輔助';

  @override
  String get quickActionKeepAliveSubtitle => '提升後台穩定性';

  @override
  String get guidePrivacyConsentLabel => '我已閱讀並同意友盟相關隱私說明';

  @override
  String get guideRequireConsentHint => '請先滑到底部閱讀說明，並勾選同意後開始使用。';

  @override
  String get guideContinueHint => '繼續下滑查看完整引導內容。';

  @override
  String get exitAppAction => '退出應用';

  @override
  String get continueReadingAction => '繼續查看';

  @override
  String get agreeAndStartAction => '同意並開始使用';

  @override
  String get startUsingAction => '開始使用';

  @override
  String get editSingleLessonTitle => '編輯單節課';

  @override
  String get editCourseTitle => '編輯課程';

  @override
  String get addSingleLessonTitle => '添加單節課';

  @override
  String get addCourseTitle => '添加課程';

  @override
  String get deleteCourseTitle => '刪除課程';

  @override
  String get courseDeleted => '課程已刪除';

  @override
  String get addMethodTitle => '添加方式';

  @override
  String get singleLessonLabel => '單節課';

  @override
  String get recurringLessonLabel => '多節課';

  @override
  String get singleLessonHint => '適合補課、臨時加課，課程只會落在一個周次。';

  @override
  String get recurringLessonHint => '適合同一時間連續上很多周的常規課程。';

  @override
  String get sharedInfoTitle => '共享資訊';

  @override
  String get sharedInfoHint => '課程名、簡稱、老師、課程簡介、課程性質和顏色會同步到同名課程的其他排課。';

  @override
  String get reuseExistingCourseLabel => '沿用已有課程';

  @override
  String get reuseExistingCourseHelper => '選一個已有課程，自動帶入課程名、老師和其他共享資訊';

  @override
  String get manualInputLabel => '手動填寫';

  @override
  String get noTemplateCoursesHint => '目前課表裡還沒有有現成課程，先手動錄入一門，後面臨時加課就能直接選了。';

  @override
  String get courseNameLabel => '課程名稱';

  @override
  String get courseNameHelper => '超級島建議 3 個字以內，顯示效果最好';

  @override
  String get pleaseEnterCourseName => '請輸入課程名稱';

  @override
  String get courseShortNameOptional => '課程簡稱 (可選)';

  @override
  String get teacherLabel => '授課教師';

  @override
  String get courseNatureLabel => '課程性質';

  @override
  String get courseDescriptionOptional => '課程簡介 (可選)';

  @override
  String get currentScheduleHint => '這裡的星期、節次、教室、周次和單雙周只影響目前這一條排課。';

  @override
  String followProfileTimeScheme(String name) {
    return '跟隨目前課表（$name）';
  }

  @override
  String get timeSchemeOverrideLabel => '上課時間方案';

  @override
  String get lessonWeeksTitle => '上課周次';

  @override
  String get singleLessonWeekHint => '單節課只會出現在一個周次裡，適合補課、臨時加課。';

  @override
  String get rangeWeekLabel => '連續周';

  @override
  String get customWeekLabel => '自定義周';

  @override
  String get allWeeksLabel => '全部';

  @override
  String get oddWeeksLabel => '單周';

  @override
  String get evenWeeksLabel => '雙周';

  @override
  String get allWeeksHint => '按開始周到結束周連續排課。';

  @override
  String get oddWeeksHint => '只保留范圍內的單周。';

  @override
  String get evenWeeksHint => '只保留范圍內的雙周。';

  @override
  String get customPaletteColor => '調色盤自定義顏色';

  @override
  String timeSchemeSetCountValue(int count) {
    return '$count 套';
  }

  @override
  String profileCountValue(int count) {
    return '$count 個';
  }

  @override
  String courseSectionCountValue(int count) {
    return '$count 節';
  }

  @override
  String timeSchemeStartsAt(String start) {
    return '$start 起';
  }

  @override
  String get weekdayShortMonday => '一';

  @override
  String get weekdayShortTuesday => '二';

  @override
  String get weekdayShortWednesday => '三';

  @override
  String get weekdayShortThursday => '四';

  @override
  String get weekdayShortFriday => '五';

  @override
  String get weekdayShortSaturday => '六';

  @override
  String get weekdayShortSunday => '日';

  @override
  String weekdaySectionRange(String weekday, int startSection, int endSection) {
    return '週$weekday $startSection-$endSection節';
  }

  @override
  String timeSchemeUsageReference(
    String profileName,
    String courseName,
    String weekday,
    int startSection,
    int endSection,
    String usageType,
  ) {
    return '$profileName · $courseName（週$weekday $startSection-$endSection節，$usageType）';
  }

  @override
  String weekdaySectionSummary(
    String weekday,
    int startSection,
    int endSection,
  ) {
    return '周$weekday $startSection-$endSection節';
  }

  @override
  String get timeRangeValidationNoCrossDay => '結束時間必須晚於開始時間';

  @override
  String get timeSchemeNameEmptyValidation => '時間模板名稱不能為空';

  @override
  String get liveTimeCorrectionNone => '不校正';

  @override
  String liveTimeCorrectionDelay(int seconds) {
    return '整體延後 $seconds 秒';
  }

  @override
  String liveTimeCorrectionAdvance(int seconds) {
    return '整體提前 $seconds 秒';
  }

  @override
  String liveClassReminderLeadSummaryImmediate(int seconds) {
    return '從上課開始就進入重點提醒顯示，並在距離下課 $seconds 秒切到秒級倒數';
  }

  @override
  String liveClassReminderLeadSummaryKeepNormal(int minutes, int seconds) {
    return '上課後先保留普通課中通知，在距離下課前 $minutes 分鐘切到重點提醒 / 下課提醒，並在最後 $seconds 秒切到秒級倒數';
  }

  @override
  String liveClassReminderLeadSummaryIsland(int minutes, int seconds) {
    return '在距離下課前 $minutes 分鐘切到超級島 / 重點提醒，並在最後 $seconds 秒切到秒級倒數';
  }

  @override
  String liveClassReminderLeadSummaryFocused(int minutes, int seconds) {
    return '在距離下課前 $minutes 分鐘開始顯示重點提醒，並在最後 $seconds 秒切到秒級倒數';
  }

  @override
  String get liveSettingsEntrySubtitle => '提醒時段、島顯示、通知欄和顯示內容';

  @override
  String get timetableProfilesEntrySubtitle => '新建、切換、複製、重新命名和刪除課表';

  @override
  String get homeTitleSectionTitle => '首頁標題';

  @override
  String get homeTitleSectionSubtitle => '控制首頁左上角課表切換入口的樣式。';

  @override
  String get homeTitleStyleLabel => '標題樣式';

  @override
  String get themeSeedSectionTitle => '應用主題色';

  @override
  String get themeSeedSectionSubtitle => '影響頂部欄、強調色和全局主色調。';

  @override
  String get timetableBackgroundColorSectionTitle => '課表背景色';

  @override
  String get timetableBackgroundColorSectionSubtitle => '只作用於課表頁面的大背景。';

  @override
  String get defaultTimetablePreviewName => '預設課表';

  @override
  String get beforeClassDisplaySettingsTitle => '上課前提醒顯示';

  @override
  String get duringEndDisplaySettingsTitle => '課中／下課提醒顯示';

  @override
  String get liveDisplaySummaryShortName => '簡稱';

  @override
  String get liveDisplaySummaryCourseName => '課程名';

  @override
  String get liveDisplaySummaryLocation => '地點';

  @override
  String liveDisplaySummaryCountdown(String style) {
    return '倒數（$style）';
  }

  @override
  String get liveDisplaySummaryStageText => '階段文字';

  @override
  String get liveDisplaySummaryLeftLabelImage => '左側圖示';

  @override
  String get liveDisplaySummaryMinimal => '最簡顯示';

  @override
  String get guideHyperOsChip => 'HyperOS 3.0.300+';

  @override
  String get guideStatusTitle => '目前狀態';

  @override
  String get guideStatusNotificationPermission => '通知權限';

  @override
  String get guideStatusEnabled => '已開啟';

  @override
  String get guideStatusDisabled => '未開啟';

  @override
  String get guideStatusIslandSupport => '焦點通知 / 超級島';

  @override
  String get guideStatusSystemAllowed => '系統已允许';

  @override
  String get guideStatusEnabledPending => '已開啟但系統暫未確認';

  @override
  String get guideStatusSuggestedCheck => '建議檢查';

  @override
  String get guideStatusBatteryOptimization => '電池優化';

  @override
  String get guideStatusBatteryUnrestricted => '無限制';

  @override
  String get guideStatusBatteryRestricted => '仍受限制';

  @override
  String get guideStatusKeepAlive => '後台保活輔助';

  @override
  String get guideStatusAndroidVersion => 'Android 版本';

  @override
  String get guideStatusVersionUnknown => '未識别';

  @override
  String get guideStatusIslandSystemSupport => '超級島系統支持';

  @override
  String get guideStatusIslandSystemRequirement => '需 HyperOS 3.0.300 及以上';

  @override
  String get guideStatusIslandHint =>
      '如果你主要想用超級島，先確認系統版本至少是 HyperOS 3.0.300，再继续把下面權限清單按顺序點完。';

  @override
  String get guidePermissionChecklistTitle => '權限清單';

  @override
  String get guidePermissionChecklistSubtitle => '按這個顺序檢查，最省事，也最不容易漏。';

  @override
  String get guideChecklistRequestNotificationTitle => '申请通知權限';

  @override
  String get guideChecklistRequestNotificationSubtitle => '這是所有提醒的前提';

  @override
  String get guideChecklistOpenNotificationTitle => '打開通知設定';

  @override
  String get guideChecklistOpenNotificationSubtitle => '檢查通知总開關、锁屏展示和实時通知權限';

  @override
  String get guideChecklistOpenIslandTitle => '打開焦點通知設定';

  @override
  String get guideChecklistOpenIslandSubtitle =>
      'HyperOS 3.0.300 及以上再檢查 promoted / 超級島通知';

  @override
  String get guideChecklistOpenAutoStartTitle => '打開自啟動設定';

  @override
  String get guideChecklistOpenAutoStartSubtitle => '允许應用開机自啟和後台常驻';

  @override
  String get guideChecklistOpenBatteryTitle => '打開電池策略設定';

  @override
  String get guideChecklistOpenBatterySubtitle => '建議改成無限制，避免上課提醒被中斷';

  @override
  String get guideChecklistOpenKeepAliveTitle => '打開後台保活輔助';

  @override
  String get guideChecklistOpenKeepAliveSubtitle => '進一步提升超級島和提醒在後台場景下的穩定性';

  @override
  String get guideShortNameAdviceTitle => '課程簡稱建議';

  @override
  String get guideShortNameAdviceSubtitle =>
      '超級島支持顯示課程簡稱。簡稱不是自動生成的，需要你在課程编辑裡自己填寫。建議控制在 3 個字以內，顯示会更穩定。';

  @override
  String get guideShortNameRecommended => '推荐示例';

  @override
  String get guideShortNameNotRecommended => '不推荐';

  @override
  String get guideShortNameRecommendedExample => '高數 / 概率 / 數控';

  @override
  String get guideShortNameNotRecommendedExample => '高等數学A(1) / 數控技術及應用';

  @override
  String get guideSetCourseShortNameAction => '去設定課程簡稱';

  @override
  String get guideImportMethodsTitle => '課表導入方式';

  @override
  String get guideImportMethodsSubtitle =>
      '目前版本已经支持部分学校的教務系統網頁登入導入；如果你的学校還没適配，也還有其他遷移方式。';

  @override
  String get guideImportMethodStep1 =>
      '優先進入“導入課程 > 教務系統導入”，选擇学校和適配器後，直接在應用內打開教務網頁完成導入。';

  @override
  String get guideImportMethodStep2 =>
      '如果你的学校暫時没有適配，可以先在 WakeUp 等課表應用裡導入教務系統課程，再導出日歷格式，最後回到本應用導入。';

  @override
  String get guideImportMethodStep3 =>
      '如果别人已经在用本應用，也可以让对方導出完整備份文件，你直接導入就能恢複課程和設定。';

  @override
  String get guideImportMethodExtra =>
      '如果你会抓包、網頁偵錯或 JavaScript，也欢迎參與学校教務適配补充，让更多学校能直接導入。';

  @override
  String get guideFinalTipsTitle => '最後再看這 3 条';

  @override
  String get guideFinalTip1 =>
      '1. HyperOS 3.0.300 及以上才支持超級島；如果系統版本不够，應用仍可正常發普通提醒。';

  @override
  String get guideFinalTip2 => '2. 先在設定頁調整“上課前弹出”和“課中 / 臨近下課提醒”的阈值。';

  @override
  String get guideFinalTip3 => '3. 完成系統權限設定後，再用測試通知驗證；如果島区還是偶尔消失，優先檢查自啟動和省電策略。';

  @override
  String get guidePrivacyHelperRequireConsent =>
      '你勾选同意後，代表你已阅讀並同意上述友盟相關說明、隱私內容與免责提示。';

  @override
  String get guidePrivacyHelperViewOnly =>
      '這裡保留與首次啟動一致的隱私、第三方 SDK 與免责說明，方便你隨時查看；目前頁面不需要再次勾选同意。';

  @override
  String get guidePrivacySectionTitle => '隱私、第三方 SDK 與免责說明';

  @override
  String get guidePrivacyParagraph1 =>
      '本應用主體功能按本地运行方式設計，課表、時間模板、課程記錄和大部分設定預設保存在你的裝置本地。';

  @override
  String get guidePrivacyParagraph2 =>
      '只有在你主動使用檢查更新、下載更新、導入導出等联網功能，或你勾选同意後初始化友盟相關 SDK 時，應用才会與外部服務發生資料交互。';

  @override
  String get guidePrivacyParagraph3 =>
      '本應用接入友盟移動統計 SDK、友盟應用性能监控 SDK 以及高級运营分析依赖庫。它們的服務用途包括移動統計分析、應用性能监控以及高級运营分析相關能力；只有在你勾选同意後，這些 SDK 才会正式初始化。';

  @override
  String get guidePrivacyParagraph4 =>
      '按友盟官方說明，這些 SDK 可能處理的資訊包括：裝置資訊（如 IMEI、MAC、Android ID、OAID、IDFA、OpenUDID、GUID、SIM 卡 IMSI 等）、網路狀態、裝置標識，以及高級运营分析依赖庫涉及的應用列表和地理位置相關資訊。';

  @override
  String get guideRiskTitle => '免责與风险提示';

  @override
  String get guideRiskParagraph1 =>
      '1. 超級島、焦點通知、後台提醒和保活效果依赖系統版本、机型、厂商策略、權限、自啟動、電池策略等外部条件，無法保证所有裝置表现完全一致。';

  @override
  String get guideRiskParagraph2 =>
      '2. 檢查更新、鏡像下載、系統下載器、導入導出與分享等能力依赖網路环境、第三方服務和系統文件能力；若出现失败、限速或文件異常，请以 Release 頁面、你自己保存的備份文件和系統提示為准。';

  @override
  String get guideRiskParagraph3 =>
      '3. 在遷移、導入或覆盖資料前，请先自行確認備份文件完整可用，並妥善保管含有課表資訊的文件；因用户自行刪除、覆盖、分享或保管不當造成的資料問題，需要由用户自行承担相應风险。';

  @override
  String get guideUmengPrivacyLink =>
      '友盟隱私政策：https://www.umeng.com/page/policy';

  @override
  String get liveDiagnosticsUnavailable => '目前還没有可查看的超級島診斷日誌';

  @override
  String get liveDiagnosticsViewerTitle => '超級島診斷日誌';

  @override
  String get liveDiagnosticsShareText => '這是輕嶼課表導出的超級島診斷日誌，可用于排查“超級島没有弹出”等問題。';

  @override
  String get liveDiagnosticsShareSubject => '輕嶼課表 - 超級島診斷日誌';

  @override
  String get liveDiagnosticsSnapshotShareText =>
      '這是輕嶼課表目前測試診斷頁導出的超級島狀態快照，可用于排查“超級島没有弹出”等問題。';

  @override
  String get liveDiagnosticsSnapshotShareSubject => '輕嶼課表 - 超級島狀態快照';

  @override
  String get liveDiagnosticsNothingToExport => '目前没有可導出的日誌文件，也没有可導出的狀態快照';

  @override
  String get liveDiagnosticsCleared => '已清空超級島診斷日誌，後续会重新開始收集';

  @override
  String get liveDiagnosticsClearFailed => '清空超級島診斷日誌失败';

  @override
  String get liveTestingNotRefreshed => '尚未刷新';

  @override
  String get liveTestingTitle => '測試與診斷';

  @override
  String get liveTestingNotificationTitle => '測試通知';

  @override
  String get liveTestingNotificationSubtitle => '用于驗證超級島、通知栏和課程簡稱等顯示效果。';

  @override
  String get liveTestingSendAction => '發送測試通知';

  @override
  String get liveTestingUmengHint => '下面兩個按鈕僅測試版顯示，用于驗證友盟 U-APM 崩溃和卡顿上報。';

  @override
  String get liveTestingCrashAction => '崩溃測試';

  @override
  String get liveTestingAnrAction => '異常卡顿測試';

  @override
  String get liveTestingIslandStatusTitle => '上島狀態診斷';

  @override
  String get liveTestingIslandStatusSubtitle => '這裡直接顯示原生实時服務、通知构造结果和不上島原因。';

  @override
  String get liveTestingServiceStatusRunning => '服務运行中';

  @override
  String get liveTestingServiceStatusStopped => '服務未运行';

  @override
  String get liveTestingNoIslandReasonTitle => '不上島原因';

  @override
  String get liveTestingNoIslandReasonEmpty => '目前無拦截原因';

  @override
  String get liveTestingRefreshAction => '刷新診斷';

  @override
  String get liveTestingRefreshing => '刷新中';

  @override
  String get liveTestingExportAction => '導出並分享日誌';

  @override
  String get liveTestingExporting => '導出中';

  @override
  String get liveTestingAutoRefreshTitle => '自動刷新';

  @override
  String liveTestingAutoRefreshOn(int seconds) {
    return '每 $seconds 秒自動拉取一次診斷狀態';
  }

  @override
  String get liveTestingAutoRefreshOff => '關閉後只在手動刷新時更新，便于穩定查看目前狀態';

  @override
  String liveTestingRefreshedAt(String time) {
    return '上次刷新：$time';
  }

  @override
  String get liveTestingSectionEnvironment => '环境與權限';

  @override
  String get liveTestingSectionService => '服務狀態';

  @override
  String get liveTestingSectionCourse => '課程資料';

  @override
  String get liveTestingSectionTiming => '時間與階段';

  @override
  String get liveTestingSectionSwitches => '階段開關';

  @override
  String get liveTestingSectionDisplay => '島顯示配置';

  @override
  String get liveTestingSectionNotification => '通知判定结果';

  @override
  String get liveTestingSectionRecentLogs => '最近診斷日誌';

  @override
  String get liveTestingRawDataTitle => '原始偵錯資料';

  @override
  String get liveTestingRawDataSubtitle => '預設折叠，排查時再展開核对完整原生字段。';

  @override
  String get liveTestingExpandRawJson => '展開原始 JSON';

  @override
  String get liveTestingExpandRawJsonSubtitle => '避免大段原始字段一直占满頁面';

  @override
  String get liveTestingLocalLogsTitle => '本地診斷日誌';

  @override
  String get liveTestingLocalLogsSubtitle =>
      '一键導出日誌文件，直接通過系統分享發给開發者；也可以清空後重新收集。';

  @override
  String get liveTestingClearLogsAction => '清空日誌';

  @override
  String get liveTestingClearingLogs => '清空中';

  @override
  String get liveTestingViewPhoneLogsAction => '查看手机日誌';

  @override
  String get liveTestingMoreTesterOptionsAction => '更多測試者选項';

  @override
  String get yesLabel => '是';

  @override
  String get noLabel => '否';

  @override
  String get liveTestingCurrentNativeFieldsSubtitle => '顯示目前原生診斷字段。';

  @override
  String get liveTestingCrashSoon => '即将触發友盟 U-APM 測試崩溃，请重新打開應用查看後台是否收到上報';

  @override
  String get liveTestingAnrSoon =>
      '即将触發约 30 秒主線程卡死，请脱离 flutter run 測試，並在卡死後重新打開應用查看友盟後台';

  @override
  String get liveTestingNoCourseAvailable => '目前没有可測試的課程';

  @override
  String get liveTestingTestCourseNote => '此處顯示備注。可以在課程编辑頁進行設定。';

  @override
  String get liveTestingNotificationSent => '已發送上課提醒測試通知，约 8 秒內会進入上課前提醒階段';

  @override
  String sendFailedWithError(String error) {
    return '發送失败: $error';
  }

  @override
  String get homeWidgetSettingsTitle => '桌面小組件';

  @override
  String get homeWidgetTodayCourseTitle => '今日課程組件';

  @override
  String get homeWidgetTodayCourseSubtitle =>
      '首批支持 2×2、2×4、4×4 三种尺寸。點擊小組件会直接打開首頁，課程開始和结束時会主動刷新。';

  @override
  String get homeWidgetQuickAddTitle => '快速添加到桌面';

  @override
  String get homeWidgetCheckingPinSupport => '正在檢查目前桌面是否支持應用內添加小組件…';

  @override
  String get homeWidgetPinSupported => '支持的话会直接弹出系統添加確認，不是單独的權限弹窗；確認後即可固定到桌面。';

  @override
  String get homeWidgetPinUnsupported =>
      '目前桌面不支持應用內直接添加時，仍可长按桌面 → 小組件 → 輕嶼課表 手動添加。';

  @override
  String get homeWidgetBackgroundStyleLabel => '背景样式';

  @override
  String get homeWidgetShowLocationTitle => '顯示地點';

  @override
  String get homeWidgetShowLocationSubtitle => '關閉後，小組件次級資訊会優先顯示周次和課程數量。';

  @override
  String get homeWidgetShowCountdownTitle => '顯示倒計時';

  @override
  String get homeWidgetShowCountdownSubtitle => '先保留刷新開關，後续会用于下一節課和上課中的剩余時間展示。';

  @override
  String get homeWidgetCountdownLeadTitle => '倒計時提前量';

  @override
  String get homeWidgetCountdownLeadSubtitle => '設置上課前多少分鐘自動切換到倒計時模式。';

  @override
  String get homeWidgetCountdownLeadAlways => '始終顯示';

  @override
  String homeWidgetCountdownLeadMinutes(String minutes) {
    return '上課前 $minutes 分鐘';
  }

  @override
  String get widgetCountdownStyleTitle => '倒計時樣式';

  @override
  String get homeWidgetHideCompletedTitle => '隱藏已上完課程';

  @override
  String get homeWidgetHideCompletedSubtitle =>
      '開啟後，2×2、2×4 和 4×4 課程列表只顯示還没结束的課程。';

  @override
  String get homeWidgetShowTomorrowTitle => '課後顯示明日課程';

  @override
  String get homeWidgetShowTomorrowSubtitle =>
      '啟用後，當今日課程全部結束時，桌面小組件會自動切換顯示明日課程。';

  @override
  String get homeWidgetHeightAdjustTitle => '卡片高度微調';

  @override
  String get defaultLabel => '預設';

  @override
  String higherByValue(String value) {
    return '更高 $value';
  }

  @override
  String lowerByValue(String value) {
    return '更矮 $value';
  }

  @override
  String get homeWidgetCornerRadiusTitle => '卡片圆角';

  @override
  String get homeWidgetDescriptionTitle => '說明';

  @override
  String get homeWidgetDescriptionText =>
      '小組件目前優先展示今日課程。無課狀態会保持完整卡片，不会出现空白；如果你切换課表或修改样式，桌面組件也会跟着刷新。';

  @override
  String homeWidgetPinRequested(String label) {
    return '已發起“$label”添加请求，请在系統弹窗裡確認並放到桌面。';
  }

  @override
  String homeWidgetPinUnsupportedManual(String label) {
    return '目前系統桌面不支持應用內直接添加小組件，请长按桌面 → 小組件 → 輕嶼課表，再手動添加“$label”。';
  }

  @override
  String get homeWidgetInvalidType => '小組件類型無效，请稍後重試。';

  @override
  String homeWidgetPinFailedManual(String label) {
    return '發起添加失败，请长按桌面 → 小組件 → 輕嶼課表，再手動添加“$label”。';
  }

  @override
  String get layoutSettingsTitle => '布局與節次';

  @override
  String get layoutDensityTitle => '課表密度';

  @override
  String get layoutAutoFitHeightTitle => '自動充满屏幕高度';

  @override
  String get layoutAutoFitHeightSubtitle => '開啟後会按目前節數自動铺满頁面底部，不再保留下方空隙。';

  @override
  String get layoutHideWeekendsTitle => '隱藏周六周日';

  @override
  String get layoutHideWeekendsSubtitle => '開啟後首頁只顯示周一到周五，剩余列宽会自動铺满。';

  @override
  String get layoutEnableHapticsTitle => '啟用應用內震動反饋';

  @override
  String get layoutEnableHapticsSubtitle => '關閉後，頁码切换等交互不再触發輕微震動。';

  @override
  String get layoutTimeColumnDisplayLabel => '首頁時間列顯示';

  @override
  String get layoutTimeColumnWidthLabel => '時間栏宽度';

  @override
  String get layoutBackToCurrentWeekButtonStyleLabel => '「返回本週」按鈕樣式';

  @override
  String get layoutBackToCurrentWeekButtonStyleHelper =>
      '預設維持現在的內嵌樣式；也可以改成周視圖右下角的小型懸浮按鈕。';

  @override
  String get layoutBackToCurrentWeekButtonStyleInline => '時間欄內嵌';

  @override
  String get layoutBackToCurrentWeekButtonStyleFloating => '右下角懸浮';

  @override
  String layoutBackToCurrentWeekButtonOpacityLabel(int value) {
    return '懸浮按鈕不透明度 $value%';
  }

  @override
  String get layoutBackToCurrentWeekButtonOpacitySubtitle => '只對右下角懸浮樣式生效。';

  @override
  String layoutCourseCardGapLabel(String value) {
    return '課程卡片間距 $value';
  }

  @override
  String layoutSectionHeightLabel(String value) {
    return '課表行高 $value';
  }

  @override
  String layoutCompactFontSizeLabel(String value) {
    return '紧凑字級 $value';
  }

  @override
  String layoutCourseCardFontSizeLabel(String value) {
    return '課程卡片字級 $value';
  }

  @override
  String get layoutCourseCardDisplayTitle => '課程卡片顯示';

  @override
  String get layoutCourseCardDisplaySubtitle => '預設顯示課程名、老師和教室；其他資訊可按課表自由開關組合。';

  @override
  String get layoutShowTeacherTitle => '顯示老師';

  @override
  String get layoutShowClassroomTitle => '顯示教室';

  @override
  String get layoutShowTimeTitle => '顯示時間';

  @override
  String get layoutShowTimeLabelsTitle => '顯示上課/下課字样';

  @override
  String get layoutShowTimeLabelsSubtitle => '關閉後僅顯示時間點，不顯示“上課”“下課”文字。';

  @override
  String get layoutShowWeeksTitle => '顯示週數';

  @override
  String get layoutShowWeeksSubtitle => '例如第 1-16 周、單双周';

  @override
  String get layoutShowDescriptionTitle => '顯示課程簡介';

  @override
  String get layoutShowDescriptionSubtitle => '預設關閉，空間不足時会最先被壓缩';

  @override
  String get layoutShowOtherWeeksTitle => '顯示非本周課程';

  @override
  String get layoutShowOtherWeeksSubtitle => '預設關閉，開啟後会用灰色半透明顯示不在目前周的課程';

  @override
  String get layoutVerticalAlignLabel => '垂直排版';

  @override
  String get layoutHorizontalAlignLabel => '水平排版';

  @override
  String get layoutShowConflictBadgeTitle => '首頁顯示冲突小胶囊';

  @override
  String get layoutShowConflictBadgeSubtitle => '關閉後，首頁課表不再对冲突課程顯示“冲突”小胶囊。';

  @override
  String layoutConflictOpacityLabel(int value) {
    return '冲突課程透明度 $value%';
  }

  @override
  String get layoutConflictOpacitySubtitle => '冲突課程会自動层叠顯示，調低透明度後能同時看到多節課。';

  @override
  String get layoutTipsText =>
      '時間模板已移到設定首頁。這裡主要調課表行高、時間列、周末顯示和課程卡片布局；如果你想只改目前課表的時間，先在時間模板裡複制一套再應用。';

  @override
  String currentWeekCompact(int week) {
    return '$week周';
  }

  @override
  String get sampleCourseNumericalControl => '數控';

  @override
  String get sampleCourseAdvancedMath => '高數';

  @override
  String get sampleTeacherZhang => '张老師';

  @override
  String get sampleCourseEnglish => '英語';

  @override
  String get sampleTeacherLi => '李老師';

  @override
  String get aboutRepositorySheetTitle => '開源倉庫';

  @override
  String get aboutRepositorySheetHint =>
      '如果你想补学校教務匯入適配，建議同時查看教務適配倉 qingyu_warehouse。';

  @override
  String get aboutOpenGitHubAction => '打開 GitHub';

  @override
  String get aboutOpenWarehouseRepoAction => '打開教務適配倉';

  @override
  String get copiedRepositoryAddress => '已複制倉庫地址';

  @override
  String get copiedWarehouseRepositoryAddress => '已複制教務適配倉地址';

  @override
  String get aboutUpdateScreenTitle => '版本更新';

  @override
  String get aboutUpdateStatusTitle => '更新狀態';

  @override
  String get aboutRefreshCheckTooltip => '重新檢查';

  @override
  String get aboutCheckingLatestVersion => '正在檢查最新版本資訊…';

  @override
  String get aboutReadVersionFailed => '暫時無法讀取版本資訊，请稍後重試。';

  @override
  String get aboutReadVersionFailedHint =>
      '如果你目前網路访問 GitHub 不穩定，可稍後再試，或切到下面的國內下載方式後重試。';

  @override
  String get aboutViewReleaseAction => '查看 Release';

  @override
  String get aboutDownloadNowAction => '立即下載';

  @override
  String get aboutOpenDownloadPageAction => '打開下載頁';

  @override
  String get aboutCurrentVersionLabel => '目前版本';

  @override
  String get aboutLatestVersionLabel => '最新版本';

  @override
  String get aboutUnreleasedLabel => '未發布';

  @override
  String get aboutVersionChannelLabel => '版本通道';

  @override
  String get aboutPrereleaseChannel => '測試版';

  @override
  String get aboutUpdateAvailableHint =>
      '你现在只需要點下面的“立即下載”即可。測速、鏡像和測試版都已经收進後面的高級选項裡。';

  @override
  String get aboutUpdateNoUpdateHint =>
      '目前版本已经可正常使用；如果你要體验測試版，可以在後面的高級选項裡打開測試版檢測。';

  @override
  String aboutUpdatedAt(String time) {
    return '更新時間：$time';
  }

  @override
  String get aboutUpdateNowTitle => '立即更新';

  @override
  String get aboutUpdateNowAndroidSubtitle =>
      '普通使用只需要點一次立即下載。下載慢、下載失败、要换線路時，再去下面的高級选項。';

  @override
  String get aboutUpdateNowOtherSubtitle => '目前平台会直接打開下載頁面，不会在應用內安装。';

  @override
  String get aboutMirrorDownloadHint => '目前会優先使用國內下載。大多數國內網路直接點“立即下載”就行。';

  @override
  String get aboutOriginalDownloadHint => '目前会優先使用國際源下載。如果下載慢或打不開，建議先切回“國內下載”。';

  @override
  String get aboutUseSystemDownloaderAction => '使用系統下載器下載';

  @override
  String get aboutOpenReleasePageAction => '打開 Release 頁面';

  @override
  String get aboutDownloadMethodTitle => '下載方式';

  @override
  String get aboutDownloadMethodSubtitle =>
      '預設推荐國內下載。只有你能穩定访問 GitHub 時，再切到國際源下載。';

  @override
  String get aboutDownloadMethodMirror => '國內下載';

  @override
  String get aboutDownloadMethodOriginal => '國際源下載';

  @override
  String aboutMirrorModeHintRecommended(String current, String recommended) {
    return '目前使用國內下載 · $current。系統最近測速更推荐“$recommended”，需要時可在後面的高級选項裡切换。';
  }

  @override
  String aboutMirrorModeHintCurrent(String current) {
    return '目前使用國內下載 · $current。如果下載慢或失败，再到後面的高級选項裡測速、换線路或填寫自定义地址。';
  }

  @override
  String get aboutOriginalModeHint =>
      '目前使用國際源下載。只有你網路能穩定访問 GitHub 時才建議這样設定；否則请切回國內下載。';

  @override
  String get aboutReleaseNotesTitle => '本次更新說明';

  @override
  String get aboutReleaseNotesSubtitle => '顯示目前檢測到版本的 Release 說明。';

  @override
  String get aboutAdvancedOptionsTitle => '高級选項';

  @override
  String get aboutAdvancedOptionsSubtitle => '只有下載慢、要手動切線路、或要檢測測試版時再展開。';

  @override
  String get aboutMirrorSectionTitle => '下載線路與鏡像';

  @override
  String get aboutMirrorSectionMirrorHint =>
      '目前使用國內下載。這裡可以手動切線路、測速推荐，或填寫自定义下載地址。';

  @override
  String get aboutMirrorSectionOriginalHint =>
      '你现在使用的是國際源下載。下面的線路設定只有在切回“國內下載”後才会生效。';

  @override
  String get aboutFillCustomMirrorFirst => '先填寫自定义下載地址';

  @override
  String get aboutCurrentCustomMirrorTitle => '目前自定义下載地址';

  @override
  String get aboutCurrentMirrorTitle => '目前下載線路地址';

  @override
  String get aboutCurrentCustomMirrorHint => '目前正在使用你手動填寫的下載地址。';

  @override
  String get aboutCurrentMirrorHint => '如果目前線路访問失败，可以切到其他內置線路，或改用自定义地址。';

  @override
  String get aboutProbeMirrorsAction => '測速並推荐';

  @override
  String get aboutProbingMirrors => '測速中…';

  @override
  String get aboutEditCustomMirrorAction => '修改自定义地址';

  @override
  String get aboutSetCustomMirrorAction => '填寫自定义地址';

  @override
  String aboutSwitchToRecommendedAction(String label) {
    return '切到推荐：$label';
  }

  @override
  String get aboutMirrorDisabledHint =>
      '目前没有使用國內下載，所以這裡的線路設定暫時不会生效。需要的话，请先在上面的“下載方式”裡切回國內下載。';

  @override
  String get aboutRecentProbeResultsTitle => '最近測速结果';

  @override
  String get aboutUnavailable => '不可用';

  @override
  String get aboutRecommended => '推荐';

  @override
  String get aboutCheckPrereleaseTitle => '檢測測試版本';

  @override
  String get aboutCheckPrereleaseSubtitle => '打開後会把測試版也纳入更新檢查；普通使用建議關閉。';

  @override
  String get aboutDiagnosticsTitle => '測試與診斷';

  @override
  String get aboutDiagnosticsSubtitle => '只有遇到“超級島没弹出”或需要给開發者反饋時再展開。';

  @override
  String get aboutRecordDiagnosticsTitle => '記錄應用日誌';

  @override
  String get aboutRecordDiagnosticsSubtitle =>
      '打開後会在本地持续記錄關键日誌，僅用于排查“该弹不弹”等問題。';

  @override
  String get aboutExportDiagnosticsAction => '匯出診斷日誌';

  @override
  String get aboutViewPhoneLogsAction => '查看手机日誌';

  @override
  String get aboutClearAndRecollectAction => '清空並重新收集';

  @override
  String get aboutLiveDiagnosticsEnabled => '已開啟超級島診斷日誌';

  @override
  String get aboutLiveDiagnosticsDisabled => '已關閉超級島診斷日誌';

  @override
  String get aboutNoDiagnosticsExportYet => '還没有可匯出的超級島診斷日誌';

  @override
  String get aboutProbeNoMirrorFound => '測速完成，但暫時没有發现可用鏡像線路';

  @override
  String aboutProbeCurrentFastest(String label) {
    return '測速完成，目前線路“$label”已是最快可用線路';
  }

  @override
  String aboutProbeRecommendSwitch(String label) {
    return '測速完成，推荐切换到“$label”';
  }

  @override
  String get switchAction => '切换';

  @override
  String aboutSwitchToMirrorAfterError(String error) {
    return '$error，可切到國內鏡像後再試';
  }

  @override
  String aboutSwitchPresetAfterError(String error, String label) {
    return '$error，建議切换到“$label”後重試';
  }

  @override
  String get aboutSetMirrorSourceTitle => '設定鏡像源';

  @override
  String get aboutMirrorPrefixLabel => '鏡像前缀';

  @override
  String get aboutMirrorPrefixInvalid => '鏡像源格式不正確，请輸入完整的 http 或 https 地址';

  @override
  String get aboutMirrorSaved => '鏡像源已保存';

  @override
  String get aboutDownloadCancelled => '已取消下載';

  @override
  String get aboutInstallReady => '安装包已准備好，已尝試打開安装界面；如果系統没有弹出，请稍後从通知或文件管理器手動安装';

  @override
  String get aboutUpdatePackageTitle => '輕嶼課表更新包';

  @override
  String get aboutUpdatePackageDescription => '已交给系統下載管理器下載，完成後可直接从系統通知安装。';

  @override
  String get aboutSystemDownloaderQueued => '已交给系統下載管理器，请在系統通知或下載列表裡查看進度';

  @override
  String get aboutSystemDownloaderFailed => '調用系統下載管理器失败';

  @override
  String get aboutDownloadCancelling => '正在取消下載…';

  @override
  String aboutDownloadingBytes(String value) {
    return '正在下載更新 $value';
  }

  @override
  String aboutDownloadingPercent(String value) {
    return '正在下載更新 $value%';
  }

  @override
  String get aboutMirrorUnknownSizeHint => '鏡像源未返回文件总大小，先顯示已下載體积';

  @override
  String get aboutCancelDownloadAction => '取消下載';

  @override
  String get aboutContributorsScreenTitle => '代码贡献者';

  @override
  String get aboutDevelopersTitle => '開發人员';

  @override
  String get aboutDeveloperMaintainerSubtitle => '輕嶼課表開發與維護';

  @override
  String get aboutWarehouseMaintainersTitle => '教務匯入適配者';

  @override
  String get aboutWarehouseMaintainersIntro =>
      '以下名單来自 qingyu_warehouse 適配倉的 maintainer 字段汇总。若本地已有缓存，会先顯示缓存，再後台刷新。';

  @override
  String aboutWarehouseMaintainersLoadFailed(String error) {
    return '暫時無法讀取適配者名單：$error';
  }

  @override
  String get aboutWarehouseMaintainersEmpty => '目前還没有讀取到適配者資訊。';

  @override
  String aboutWarehouseMaintainerCount(int count) {
    return '$count 個適配項';
  }

  @override
  String get aboutParticipateWarehouseTitle => '參與教務適配';

  @override
  String get aboutParticipateWarehouseSubtitle =>
      '如果你会抓包、網頁偵錯、JavaScript，或者愿意长期維護自己学校的教務系統，欢迎去 qingyu_warehouse 提交新的学校適配與修複。';

  @override
  String get importFileReadFailed => '無法讀取所选文件';

  @override
  String get importReplaceExistingTitle => '匯入課程';

  @override
  String importReplaceExistingMessage(String name) {
    return '匯入 $name 時，是否替换现有課程？';
  }

  @override
  String get importNoCoursesRecognized => '未識别到可匯入課程';

  @override
  String get importConfirmSemesterMappingTitle => '確認開学日期和周次对應';

  @override
  String get importConfirmSemesterMappingSubtitleIcs =>
      '请选擇学校校歷的開学日期。系統已根据文件裡最早的上課日期给出預設周次对應，你也可以手動調整。';

  @override
  String importOverwriteCount(int count) {
    return '已覆盖匯入 $count 条課程';
  }

  @override
  String importUpdatedCount(int count) {
    return '已更新課表：新增或更新 $count 条課程';
  }

  @override
  String get importNoCourseChanges => '没有需要新增或更新的課程';

  @override
  String get aiImportTitle => '識圖匯入';

  @override
  String aiPreviewSummary(
    int courseCount,
    int sectionCount,
    String warningSuffix,
  ) {
    return '識别到 $courseCount 門課，最高到第 $sectionCount 節$warningSuffix';
  }

  @override
  String aiWarningCountSuffix(int count) {
    return '，$count 条提醒';
  }

  @override
  String get aiWorkflowCompactTitle => '複制提示词 -> 豆包識圖 -> 匯入';

  @override
  String get aiWorkflowCompactSubtitle => '豆包專家模式 -> 複制 JSON -> 选擇開学日期';

  @override
  String get aiWorkflowTitle => '複制提示词 -> 豆包識圖 -> 粘贴 JSON -> 匯入';

  @override
  String get aiWorkflowSubtitle =>
      '先複制提示词，再到豆包左下角切换為專家模式，把課表截圖和提示词一起發過去。把豆包返回的 JSON 複制回這裡，點擊匯入後再选擇開学日期。';

  @override
  String get aiPromptShortAction => '提示词';

  @override
  String get aiExpertModeSuggestion => '建議豆包專家模式，支持多圖，截圖需带星期表头。';

  @override
  String get aiHintExpertMode => '先切到豆包專家模式';

  @override
  String get aiHintSendScreenshot => '截圖和提示词一起發';

  @override
  String get aiHintCopyJsonBack => '返回结果複制 JSON';

  @override
  String get aiHintPickSemesterAfterImport => '匯入後再选開学日期';

  @override
  String get jsonLabelShort => 'JSON';

  @override
  String get aiPasteJsonTitle => '粘贴 AI 返回的 JSON';

  @override
  String aiCourseCountChip(int count) {
    return '$count 門課';
  }

  @override
  String get aiParseFailedChip => '解析失败';

  @override
  String get aiPasteJsonHintShort => '粘贴 AI 返回的 JSON';

  @override
  String get aiPasteJsonHintLong =>
      '把豆包返回的 JSON 原样粘贴到這裡，然後點擊匯入。支持纯 JSON，也兼容 ```json 代码块。';

  @override
  String get detailAction => '详情';

  @override
  String get aiParseErrorTitle => '解析错误';

  @override
  String get viewDetailsAction => '查看详情';

  @override
  String get aiWorkflowFooter =>
      '複制提示词 -> 豆包發送截圖和提示词 -> 把 JSON 贴回這裡 -> 點擊匯入 -> 选擇開学日期。';

  @override
  String get previewAction => '預覽';

  @override
  String get confirmImportAction => '確認匯入';

  @override
  String get promptCopiedHint => '提示词已複制，去豆包發送截圖和提示词';

  @override
  String get clipboardNoText => '剪贴板裡没有可用文本';

  @override
  String get aiPromptSheetTitle => '識圖提示词';

  @override
  String get aiPromptSheetSubtitle =>
      '建議使用豆包。先把豆包左下角切换為專家模式，再把下面整段提示词和課表截圖一起發過去，让它只返回 JSON。生成後把 JSON 複制回本頁，點擊匯入後再选擇開学日期。';

  @override
  String get aiPreviewTitle => '解析預覽';

  @override
  String get aiPasteJsonFirst => '请先粘贴 AI 返回的 JSON';

  @override
  String get aiParseFailedIncompleteJson => '解析失败，请確認粘贴的是完整 JSON';

  @override
  String get importAiResultTitle => '匯入 AI 解析结果';

  @override
  String get importAiReplaceMessage => '是否用目前這份 AI 解析结果替换现有課程？';

  @override
  String get importConfirmSemesterMappingSubtitleAi =>
      '请选擇学校校歷的開学日期，再確認課表裡的第 1 周对應校歷第几周。如果学校第一周没課，這裡通常要改成第 2 周。';

  @override
  String aiWarningExtraSuffix(int count) {
    return '，另有 $count 条識别提醒';
  }

  @override
  String get pasteAction => '粘贴';

  @override
  String get importConfirmSemesterMappingSubtitleWarehouse =>
      '教務脚本已返回課程周次，请確認校歷開学日期；如果学校前几周没有課，可把“課表第 1 周”对應到校歷後面的周次。';

  @override
  String aiPreviewCourseCount(int count) {
    return '課程數量：$count';
  }

  @override
  String aiPreviewMaxSection(int section) {
    return '最大節次：第 $section 節';
  }

  @override
  String get aiPreviewWarningsTitle => '識别提醒';

  @override
  String get aiPreviewCoursesTitle => '課程預覽';

  @override
  String aiPreviewRemainingCourses(int count) {
    return '其余 $count 条将在匯入後寫入目前課表';
  }

  @override
  String get warehouseMissingSchoolTitle => '学校列表裡没有你的学校？';

  @override
  String get warehouseMissingSchoolSubtitle =>
      '去反饋頁提一個 Issue 就行。建議一起寫上学校名稱、教務系統網址、登入後課表頁連結或截圖，這样更方便补適配。';

  @override
  String get laterAction => '稍後再說';

  @override
  String get goFeedbackAction => '去反饋頁';

  @override
  String get warehouseFeedbackMissingSchoolTitle => '缺少学校？去反饋';

  @override
  String get warehouseCustomDebugTitle => '自訂偵錯';

  @override
  String get warehouseRootLoadFailedTitle => '暫時無法讀取適配倉';

  @override
  String get searchSchoolHint => '搜索学校名稱、首字母或代码';

  @override
  String get clearSearchTooltip => '清空';

  @override
  String get noMatchingSchools => '没有找到匹配的学校';

  @override
  String get noAvailableSchools => '暫無可用学校';

  @override
  String get searchSchoolSuggestion => '試試学校全稱、首字母或倉庫裡的学校代码。';

  @override
  String get deleteDebugRecordTitle => '刪除偵錯記錄';

  @override
  String deleteDebugRecordMessage(String name) {
    return '確認刪除“$name”？刪除後不会影响已经匯入的課程。';
  }

  @override
  String deletedDebugRecord(String name) {
    return '已刪除偵錯記錄：$name';
  }

  @override
  String get customDebugName => '自定义偵錯';

  @override
  String get localDebugMaintainer => '本地偵錯';

  @override
  String get customDebugDescription => '用户保存的自定义教務偵錯脚本';

  @override
  String get addDebugRecordTooltip => '新增偵錯記錄';

  @override
  String get customDebugIntroTitle => '這裡放你自己的教務偵錯記錄';

  @override
  String get customDebugIntroSubtitle =>
      '每条記錄都可以保存自定义網址和整段脚本。保存後下次直接點“開始偵錯”就能複用，不需要再去某個学校详情頁裡找入口。';

  @override
  String get addDebugRecordAction => '新增偵錯記錄';

  @override
  String get noSavedDebugRecords => '還没有保存的偵錯記錄';

  @override
  String get noSavedDebugRecordsHint => '先新增一条，把網址和脚本贴進去，以後就能直接複用。';

  @override
  String debugScriptLength(int count) {
    return '脚本 $count 字符';
  }

  @override
  String get startDebugAction => '開始偵錯';

  @override
  String get editAction => '编辑';

  @override
  String get scriptFileReadFailed => '無法讀取脚本文件';

  @override
  String scriptFileImported(String name) {
    return '已匯入脚本文件：$name';
  }

  @override
  String scriptFileImportFailed(String error) {
    return '匯入脚本文件失败：$error';
  }

  @override
  String get debugRecordNameRequired => '请先填寫偵錯記錄名稱';

  @override
  String get invalidImportUrl => '请輸入有效的教務網址';

  @override
  String get debugScriptRequired => '请先填寫或匯入脚本';

  @override
  String get editDebugRecordTitle => '编辑偵錯記錄';

  @override
  String get addDebugRecordTitle => '新增偵錯記錄';

  @override
  String get savingAction => '保存中…';

  @override
  String get debugRecordFormula => '一条記錄 = 一個網址 + 一段脚本';

  @override
  String get debugRecordFormulaSubtitle =>
      '適合你反複偵錯同一個学校，或者不同学校保留多套脚本。保存後会一直保留，後面可隨時修改。';

  @override
  String get debugRecordNameLabel => '記錄名稱';

  @override
  String get debugRecordNameHint => '例如：重庆机電-新版教務';

  @override
  String get importUrlLabel => '教務網址';

  @override
  String get debugScriptLabel => '偵錯脚本';

  @override
  String get importFromFileAction => '从文件匯入';

  @override
  String get debugScriptHint => '把浏覽器擴展匯出的完整脚本粘贴到這裡';

  @override
  String get saveDebugRecordAction => '保存偵錯記錄';

  @override
  String get fillUrlThenImport => '填寫網址後匯入';

  @override
  String get webLoginImport => '網頁登入匯入';

  @override
  String get savedImportUrlHint => '已保存教務網址，下次可直接匯入';

  @override
  String get adapterIntroSubtitle => '可查看適配器資訊、登入入口與脚本狀態。';

  @override
  String get schoolLabel => '学校';

  @override
  String get categoryLabel => '類别';

  @override
  String get maintainerLabel => '維護者';

  @override
  String get adapterInfoTitle => '適配器資訊';

  @override
  String get scriptPathLabel => '脚本路徑';

  @override
  String get loginEntryLabel => '登入入口';

  @override
  String get unsetConfigLabel => '未配置';

  @override
  String get adapterOverrideImportUrlHint => '目前使用你手動覆盖的登入地址';

  @override
  String get repositoryLabel => '倉庫';

  @override
  String get scriptStatusTitle => '脚本狀態';

  @override
  String scriptLoadedLength(int count) {
    return '脚本已成功讀取，长度 $count 字符。';
  }

  @override
  String get scriptEmpty => '脚本為空';

  @override
  String get openLoginInAppAction => '應用內打開登入入口';

  @override
  String get openInSystemBrowserAction => '系統浏覽器打開';

  @override
  String get copiedImportLoginUrl => '已複制教務登入地址';

  @override
  String get copyLoginAddressAction => '複制登入地址';

  @override
  String get copiedScriptRawUrl => '已複制脚本原始地址';

  @override
  String get copyScriptAddressAction => '複制脚本地址';

  @override
  String get customLoginAddressAction => '自定义登入地址';

  @override
  String get editCustomLoginAddressAction => '修改自定义地址';

  @override
  String get clearCustomLoginAddressAction => '清除自定义地址';

  @override
  String get restoreRepositoryAddressAction => '恢複倉庫地址';

  @override
  String get invalidLoginEntryUrl => '登入入口地址無效';

  @override
  String get savedCustomLoginAddress => '已保存自定义登入地址';

  @override
  String get clearedCustomLoginAddress => '已清除自定义登入地址';

  @override
  String get restoredRepositoryImportUrl => '已恢複倉庫裡的登入地址';

  @override
  String get backToCurrentWeekAction => '返回本週';

  @override
  String get nonCurrentWeekLabel => '非本周';

  @override
  String get conflictLabel => '冲突';

  @override
  String get selectWeekTitle => '选擇周次';

  @override
  String availableWeeksCount(int count) {
    return '共 $count 周';
  }

  @override
  String goToWeekLabel(int week) {
    return '第 $week 周';
  }

  @override
  String get homeMenuUpdateTitle => '軟體更新';

  @override
  String get homeMenuProfilesTitle => '課表管理';

  @override
  String get homeMenuOverviewTitle => '課程總覽';

  @override
  String get homeMenuAddCourseTitle => '新增課程';

  @override
  String get homeMenuImportTitle => '匯入課程';

  @override
  String get homeMenuSettingsTitle => '課表設定';

  @override
  String get homeMenuCoffeeTitle => '請喝咖啡';

  @override
  String get homeMenuFeedbackTitle => '問題回饋';

  @override
  String get switchTimetableTitle => '切换課表';

  @override
  String get switchTimetableSubtitleEmpty => '點擊下面的課表，立即切换目前視圖。';

  @override
  String switchTimetableSubtitleCurrent(String name) {
    return '目前：$name，點擊下面的課表立即切换。';
  }

  @override
  String get todayTimetableTitle => '今日課表';

  @override
  String get dayTimetableTitle => '單日時間軸';

  @override
  String get backToWeekViewAction => '返回周視圖';

  @override
  String get backToTodayAction => '回到今天';

  @override
  String get ongoingCourseBadge => '正在上課';

  @override
  String get dayViewEmptyTitle => '暫無課程';

  @override
  String shortNamePrefix(String value) {
    return '簡稱：$value';
  }

  @override
  String teacherPrefix(String value) {
    return '老師：$value';
  }

  @override
  String locationPrefix(String value) {
    return '地點：$value';
  }

  @override
  String courseDialogCurrentWeekHint(int week) {
    return '目前查看第 $week 周，可直接对這一周這節課調課。';
  }

  @override
  String courseDialogNotThisWeekHint(int week) {
    return '目前查看第 $week 周，這門課這周没有上課，因此不能按“本周這節”調課。';
  }

  @override
  String get editActionShort => '编辑';

  @override
  String get rescheduleAction => '調課';

  @override
  String get deleteActionShort => '刪除';

  @override
  String get deleteModeTitle => '刪除方式';

  @override
  String get deleteModeSubtitle => '你可以刪掉整条排課，也可以只刪目前看到的這一周這一節。';

  @override
  String get deleteCourseAction => '刪這個課';

  @override
  String get deleteOccurrenceAction => '刪這節課';

  @override
  String deleteModeHintCurrentWeek(int week) {
    return '“刪這個課”会刪除這条排課的全部周次；“刪這節課”只会刪除第 $week 周這一次。';
  }

  @override
  String deleteModeHintUnavailable(int week) {
    return '目前卡片不是第 $week 周的实際排課，所以只能刪除整条排課。';
  }

  @override
  String deleteScheduleConfirmMessage(String name, String detail) {
    return '確定刪除“$name”這条排課嗎？\n$detail';
  }

  @override
  String deleteOccurrenceConfirmMessage(String name, int week, String detail) {
    return '確定刪除“$name”在第 $week 周的這一節嗎？\n$detail';
  }

  @override
  String occurrenceDeletedMessage(int week) {
    return '已刪除第 $week 周這節課';
  }

  @override
  String get noChangesDetected => '未檢測到变更';

  @override
  String get rescheduleCurrentOccurrenceTitle => '調本周這節課';

  @override
  String rescheduleCurrentOccurrenceSubtitle(int week) {
    return '只調整第 $week 周這一節，原課程在這一周会自動移除，其他周保持不变。';
  }

  @override
  String get rescheduleTargetWeekLabel => '調到第几周';

  @override
  String get weekdayFieldLabel => '星期';

  @override
  String get startSectionFieldLabel => '開始節次';

  @override
  String get endSectionFieldLabel => '结束節次';

  @override
  String get courseLocationFieldLabel => '上課地點';

  @override
  String get confirmRescheduleAction => '確認調課';

  @override
  String get homeTitleStyleClassicLabel => '經典文字';

  @override
  String get homeTitleStyleBrandLabel => '大 Logo';

  @override
  String get homeTitleStyleClassicDescription => '維持原本標題樣式，只顯示文字，點一下即可切換課表';

  @override
  String get homeTitleStyleBrandDescription => '顯示大 Logo 和較小的課表名稱，更強調品牌感';

  @override
  String get widgetBackgroundStyleGlass => '半透明玻璃感';

  @override
  String get widgetBackgroundStyleSolid => '純色卡片';

  @override
  String get widgetBackgroundStyleGradient => '漸變卡片';

  @override
  String get homeWidgetTargetCompact22 => '主卡 2×2';

  @override
  String get homeWidgetTargetMiniList22 => '迷你清單 2×2';

  @override
  String get homeWidgetTargetMedium24 => '概覽 2×4';

  @override
  String get homeWidgetTargetLarge44 => '清單 4×4';

  @override
  String get addCourseSheetTitle => '新增內容';

  @override
  String get addCourseSheetSubtitle =>
      '空白課表區域不響應點擊。請從這裡明確選擇是加一節臨時課、整學期重複課，還是插入一條單次日程。';

  @override
  String courseWeekdaySectionSummary(
    String weekDescription,
    String weekday,
    int startSection,
    int endSection,
  ) {
    return '$weekDescription · $weekday 第$startSection-$endSection節';
  }

  @override
  String weekdaySectionTimeSummary(
    String weekday,
    int startSection,
    int endSection,
    String startTime,
    String endTime,
  ) {
    return '$weekday 第$startSection-$endSection節 · $startTime-$endTime';
  }

  @override
  String rescheduledToMessage(
    int week,
    String weekday,
    int startSection,
    int endSection,
  ) {
    return '已調到第 $week 周 $weekday 第$startSection-$endSection節';
  }

  @override
  String courseCountSummary(int count) {
    return '$count 門課';
  }

  @override
  String dayAgendaInProgressStatus(int minutes) {
    return '進行中 · 剩餘 $minutes 分鐘';
  }

  @override
  String dayAgendaEndingSoonStatus(int minutes) {
    return '快下課了 · 剩餘 $minutes 分鐘';
  }

  @override
  String scheduleAgendaInProgressStatus(int minutes) {
    return '進行中 · 剩餘 $minutes 分鐘';
  }

  @override
  String scheduleAgendaEndingSoonStatus(int minutes) {
    return '即將結束 · 剩餘 $minutes 分鐘';
  }

  @override
  String get currentBadge => '當前';

  @override
  String get feedbackXiaohongshuTitle => '小紅書';

  @override
  String feedbackXiaohongshuSubtitle(String id) {
    return '小紅書号：$id';
  }

  @override
  String get feedbackCoolapkTitle => '酷安';

  @override
  String feedbackCoolapkSubtitle(String id) {
    return '酷安号：$id';
  }

  @override
  String get feedbackQqGroupTitle => 'QQ 群';

  @override
  String feedbackQqGroupSubtitle(String id) {
    return '群号：$id';
  }

  @override
  String get copiedCurrentTimetable => '已複製當前課表';

  @override
  String sectionRangeLabel(int startSection, int endSection) {
    return '第$startSection-$endSection節';
  }

  @override
  String classStartsAtLabel(String time) {
    return '$time 開始';
  }

  @override
  String classEndsAtLabel(String time) {
    return '$time 結束';
  }

  @override
  String get invalidSectionTimeFormat => '節次時間格式不正確';

  @override
  String get noSectionTimesToSave => '沒有可保存的節次時間';

  @override
  String warehouseImportedTimeSchemeName(String schoolName) {
    return '$schoolName 匯入節次';
  }

  @override
  String get unnamedScript => '未命名腳本';

  @override
  String localDebugModeScriptStatus(String scriptName) {
    return '本地偵錯模式：$scriptName';
  }

  @override
  String get executeImportScriptTooltip => '執行匯入腳本';

  @override
  String get switchToMobileWebTooltip => '切換到移動端頁面';

  @override
  String get switchToDesktopWebTooltip => '切換到桌面端頁面';

  @override
  String get rememberCurrentInputTooltip => '記住當前輸入';

  @override
  String get fillRememberedTooltip => '填充已記住賬號';

  @override
  String get clearRememberedTooltip => '清除已記住賬號';

  @override
  String get copyCurrentAddressTooltip => '複製當前地址';

  @override
  String get copiedCurrentAddress => '已複製當前地址';

  @override
  String get warehouseLoginHintLocalDebug => '當前為本地偵錯腳本模式';

  @override
  String get warehouseLoginHintImport => '在此登入教務系統後執行匯入';

  @override
  String get currentPageModeDesktop => '當前页面模式：桌面端';

  @override
  String get currentPageModeMobile => '當前页面模式：移动端';

  @override
  String localScriptLabel(String scriptName) {
    return '本地腳本：$scriptName';
  }

  @override
  String get webAddressHint => '輸入網頁地址';

  @override
  String get goAction => '前往';

  @override
  String rememberedAccountLabel(String username) {
    return '已記住賬號：$username';
  }

  @override
  String get importingAction => '匯入中...';

  @override
  String get executeLocalDebugScriptAction => '執行本地偵錯腳本';

  @override
  String get executeImportScriptAction => '執行匯入腳本';

  @override
  String get invalidWebAddress => '網頁地址無效';

  @override
  String get injectingLocalDebugScript => '正在注入本地偵錯腳本';

  @override
  String get injectingAdapterScript => '正在注入適配器腳本';

  @override
  String get localDebugScriptInjected => '本地偵錯腳本已注入';

  @override
  String get scriptInjected => '腳本已注入';

  @override
  String get scriptInjectionFailed => '腳本注入失敗';

  @override
  String executeFailedWithError(String error) {
    return '執行失敗：$error';
  }

  @override
  String get importFlowFinished => '匯入流程已完成';

  @override
  String get defaultContinuePrompt => '請按提示繼續操作';

  @override
  String get inputRequiredTitle => '需要输入';

  @override
  String get pleaseEnterFourDigitYear => '請輸入 4 位年份';

  @override
  String get pleaseChooseTitle => '請選擇';

  @override
  String get invalidCourseConfigFormat => '課程配置格式不正確';

  @override
  String saveCourseConfigFailedWithError(String error) {
    return '保存課程配置失敗：$error';
  }

  @override
  String saveSectionTimesFailedWithError(String error) {
    return '保存節次時間失敗：$error';
  }

  @override
  String get invalidCourseDataFormat => '課程資料格式不正確';

  @override
  String get noImportableCoursesFromScript => '腳本未返回可匯入課程';

  @override
  String importCourseCountPrompt(int count) {
    return '識別到 $count 門課程，是否匯入？';
  }

  @override
  String get importCancelledStatus => '已取消匯入';

  @override
  String applyReturnedTimeSchemeFailed(String error) {
    return '應用返回的節次模板失败：$error';
  }

  @override
  String get importInterruptedStatus => '匯入已中斷';

  @override
  String get importFailedStatus => '匯入失敗';

  @override
  String importFailedWithError(String error) {
    return '匯入失敗：$error';
  }

  @override
  String get unknownTeacher => '未知教師';

  @override
  String get unknownLocation => '未知地點';

  @override
  String get autofillLoginTitle => '自動填充登入資訊';

  @override
  String autofillLoginMessage(String username) {
    return '檢測到已記住賬號 $username，是否自動填充？';
  }

  @override
  String get notNowAction => '暫不';

  @override
  String get autofillAction => '自動填充';

  @override
  String get rememberPasswordTitle => '記住密碼';

  @override
  String rememberPasswordMessage(String username) {
    return '是否記住賬號 $username 的登入資訊，並在下次自動填充？';
  }

  @override
  String get dontRememberAction => '不記住';

  @override
  String get rememberAndAutofillAction => '記住並自動填充';

  @override
  String get savedRememberedLoginStatus => '已保存記住的登入資訊';

  @override
  String get autofilledRememberedLoginStatus => '已自動填充記住的登入資訊';

  @override
  String get noRecognizedLoginInputs => '未識別到登入輸入項';

  @override
  String get noUsernameOrPasswordRecognized => '未識別到用戶名或密碼';

  @override
  String get rememberedCurrentLoginStatus => '已記住當前登入資訊';

  @override
  String get rememberedCurrentLoginSuccess => '已記住當前登入資訊';

  @override
  String rememberLoginFailedWithError(String error) {
    return '記住登入資訊失敗：$error';
  }

  @override
  String get clearedRememberedLoginStatus => '已清除記住的登入資訊';

  @override
  String get clearedRememberedLoginSuccess => '已清除記住的登入資訊';

  @override
  String get addScheduleTitle => '新增日程';

  @override
  String get editScheduleTitle => '編輯日程';

  @override
  String get addScheduleAction => '新增日程';

  @override
  String get scheduleTitleLabel => '日程標題';

  @override
  String get scheduleTitleHint => '例如：開組會、辦證件、取快遞';

  @override
  String get scheduleTitleRequired => '請輸入日程標題';

  @override
  String get scheduleInfoSectionTitle => '日程資訊';

  @override
  String get scheduleInfoSectionSubtitle => '日程會按具體日期插入日視圖時間線，不會改動課程本身。';

  @override
  String get scheduleTimeSectionTitle => '時間安排';

  @override
  String get scheduleTimeSectionSubtitle => '選擇這條日程實際發生的日期和起止時間。';

  @override
  String get scheduleAppearanceSectionTitle => '顯示樣式';

  @override
  String get scheduleAppearanceSectionSubtitle => '選一個更容易和課程區分的日程顏色。';

  @override
  String get scheduleLocationLabel => '地點';

  @override
  String get scheduleLocationHint => '選填';

  @override
  String get scheduleDateLabel => '日期';

  @override
  String get scheduleStartDateLabel => '開始日期';

  @override
  String get scheduleEndDateLabel => '結束日期';

  @override
  String get scheduleStartTimeLabel => '開始時間';

  @override
  String get scheduleEndTimeLabel => '結束時間';

  @override
  String get scheduleColorLabel => '日程顏色';

  @override
  String get scheduleNoteLabel => '備註';

  @override
  String get scheduleNoteHint => '選填';

  @override
  String get scheduleBadgeLabel => '日程';

  @override
  String scheduleCountSummary(int count) {
    return '日程 $count 項';
  }

  @override
  String get scheduleTimeRangeInvalid => '結束時間必須晚於開始時間';

  @override
  String get scheduleDateRangeInvalid => '結束日期不能早於開始日期';

  @override
  String get scheduleSingleDayHint => '同日結束時，結束時間必須晚於開始時間。';

  @override
  String get scheduleCrossDayHint => '跨日日程會按當天切片顯示在日視圖時間線裡。';

  @override
  String get scheduleSavedHint => '日程已新增';

  @override
  String get scheduleUpdatedHint => '日程已更新';

  @override
  String get crossDayBadgeLabel => '跨日';

  @override
  String deleteScheduleMessage(String title) {
    return '刪除日程「$title」？';
  }

  @override
  String get scheduleDeletedHint => '日程已刪除';

  @override
  String get examListTitle => '考試安排';

  @override
  String get addExam => '添加考試';

  @override
  String get editExam => '編輯考試';

  @override
  String get saveExam => '儲存考試';

  @override
  String get noExams => '暫無考試安排';

  @override
  String get examToday => '今天有考試';

  @override
  String daysUntilExam(int days) {
    return '距離考試還有 $days 天';
  }

  @override
  String get examPassed => '已結束';

  @override
  String get linkCourse => '關聯課程';

  @override
  String get linkCourseRequired => '請選擇關聯課程';

  @override
  String get examNameLabel => '考試名稱';

  @override
  String get examNameRequired => '請輸入考試名稱';

  @override
  String get examDateLabel => '考試日期';

  @override
  String get examDateHint => '請選擇日期';

  @override
  String get examDateRequired => '請選擇考試日期';

  @override
  String get examStartTimeLabel => '開始時間';

  @override
  String get examEndTimeLabel => '結束時間';

  @override
  String get examLocationLabel => '考場';

  @override
  String get examLocationHint => '留空則使用上課教室';

  @override
  String get sameAsClassroom => '同上課教室';

  @override
  String get examSeatLabel => '座位號';

  @override
  String get examReminderLabel => '提醒設定';

  @override
  String get examNoteLabel => '備註';

  @override
  String get deleteExam => '刪除考試';

  @override
  String deleteExamConfirm(String name) {
    return '刪除考試「$name」？';
  }

  @override
  String get examBadgeLabel => '考試';

  @override
  String get examCountdownToday => '今天';

  @override
  String examCountdownDays(int days) {
    return '$days天後';
  }

  @override
  String get sortAction => '排序';

  @override
  String get sortByAdded => '按加入次序';

  @override
  String get sortByName => '按課程名稱';

  @override
  String get sortBySchedule => '按上課時間';

  @override
  String scheduleEntryTitle(int index) {
    return '排課記錄 $index';
  }

  @override
  String get addScheduleEntryAction => '新增排課時段';

  @override
  String get deleteScheduleEntryAction => '刪除排課';

  @override
  String get holidaySettingsEntryTitle => '假期標記';

  @override
  String get holidaySettingsEntrySubtitle => '在課表上標記公眾假期和調休補班';

  @override
  String get holidayMakeupWorkday => '補班';

  @override
  String get holidaySettingsTitle => '假期標記';

  @override
  String get holidayEnableTitle => '啟用假期標記';

  @override
  String get holidayEnableSubtitle => '啟用後會在課表上標記公眾假期和調休補班。';

  @override
  String get holidayDataSectionTitle => '假期資料';

  @override
  String get holidayDataYear => '年份';

  @override
  String get holidayDataCount => '數量';

  @override
  String get holidayDataEmpty => '暫無假期資料';

  @override
  String get holidayCheckUpdate => '檢查更新';

  @override
  String get holidayUpcomingSectionTitle => '近期假期';

  @override
  String get holidayNoUpcoming => '近期沒有假期';

  @override
  String get holidayBadgeLabel => '休';

  @override
  String get holidayStatusLabel => '假期';

  @override
  String get suspendedBadgeLabel => '停';

  @override
  String get suspendedStatusLabel => '停課';

  @override
  String get courseActionSuspend => '停課';

  @override
  String get courseActionUnsuspend => '恢復上課';

  @override
  String get suspendSheetTitle => '停課';

  @override
  String get suspendSheetSubtitle => '選擇停課範圍';

  @override
  String get suspendThisWeek => '本週停課';

  @override
  String get suspendThisWeekDesc => '只停本週';

  @override
  String get suspendAllWeeks => '全部週次停課';

  @override
  String get suspendAllWeeksDesc => '套用到所有週次';

  @override
  String get unsuspendAllWeeks => '恢復全部週次';

  @override
  String get unsuspendAllWeeksDesc => '恢復所有週次';

  @override
  String get customHolidayTitle => '自訂假期';

  @override
  String get customHolidayAdd => '新增假期';

  @override
  String get customHolidayEdit => '編輯假期';

  @override
  String get customHolidayDelete => '刪除';

  @override
  String get customHolidayDeleteConfirm => '確定要刪除此自訂假期嗎？';

  @override
  String get customHolidayNameLabel => '假期名稱';

  @override
  String get customHolidayStartDate => '開始日期';

  @override
  String get customHolidayEndDate => '結束日期';

  @override
  String get customHolidayType => '類型';

  @override
  String get customHolidayTypeVacation => '放假';

  @override
  String get customHolidayTypeWorkday => '調休補班';

  @override
  String get customHolidayEmpty => '暫無自訂假期';

  @override
  String get customHolidayNameRequired => '請輸入假期名稱';

  @override
  String customHolidayDateRange(Object start, Object end) {
    return '$start ~ $end';
  }

  @override
  String get selectTeacherTitle => '選擇老師';

  @override
  String get selectLocationTitle => '選擇地點';

  @override
  String get historyRecordsLabel => '歷史記錄';

  @override
  String get noHistoryRecords => '暫無歷史記錄';

  @override
  String get weekPickerTitle => '選擇上課週次';

  @override
  String get selectTimeSchemeTitle => '選擇時間方案';

  @override
  String get manageTimeSchemesAction => '管理時間方案';

  @override
  String get examDefaultName => '期末考試';

  @override
  String get examDateWeekPickerTitle => '選擇考試日期';

  @override
  String get weekPickerCalendarTooltip => '使用日曆選擇';

  @override
  String get thisWeekLabel => '本週';

  @override
  String get guidePrivacyPageTitle => '私隱條款';

  @override
  String get guidePermissionsPageTitle => '系統權限';

  @override
  String get guideTipsPageTitle => '使用技巧';

  @override
  String get guidePrevButton => '上一步';

  @override
  String get guideNextButton => '下一步';

  @override
  String get guidePermissionsHeader => '系統權限設置';

  @override
  String get guidePermissionsSubtitle => '完成這些設置，超級島和提醒才能正常使用';

  @override
  String get guidePermissionsFooterHint =>
      '點擊後跳轉到系統設置，返回應用後可識別的狀態會自動刷新；自啟動受系統限制，請以系統頁面開關為準。';

  @override
  String get guideTipsHeader => '使用技巧';

  @override
  String get guideTipsSubtitle => '這些隨時可以在「設置」裡找到';

  @override
  String get guidePrivacyReadBeforeUse => '使用前請閱讀並同意以下內容';

  @override
  String get guidePrivacyViewOnly => '私隱、第三方 SDK 與免責聲明';

  @override
  String holidayDataYearLabel(Object year) {
    return '$year年公眾假期';
  }

  @override
  String get holidayUpdateLog => '更新日誌';

  @override
  String holidayUpdateLogCount(int count) {
    return '$count條';
  }

  @override
  String holidayDateSameMonth(int month, int start, int end) {
    return '$month月$start日 - $end日';
  }

  @override
  String holidayDateSameDay(int month, int day) {
    return '$month月$day日';
  }

  @override
  String holidayDateDiffMonth(
    int startMonth,
    int startDay,
    int endMonth,
    int endDay,
  ) {
    return '$startMonth月$startDay日 - $endMonth月$endDay日';
  }

  @override
  String get liveTestingHolidayOverride => '假期狀態覆蓋';

  @override
  String get liveTestingHolidayOverrideSubtitle =>
      '開啟後模擬假期狀態，用於測試提醒和小工具是否正確隱藏課程';

  @override
  String get liveTestingHolidayModeEnabled => '假期模式已開啟';

  @override
  String get liveTestingHolidayModeDisabled => '假期模式已關閉';

  @override
  String get liveTestingHolidayModeEnabledDesc => '課程提醒和小工具將隱藏所有課程';

  @override
  String get liveTestingHolidayModeDisabledDesc => '當前使用正常假期數據';

  @override
  String get textColorTitle => '文字顏色';

  @override
  String get textColorSubtitle => '自訂課表各區域嘅文字顏色';

  @override
  String get textColorIndependentDetail => '獨立設定詳情顏色';

  @override
  String get textColorCourseCardTitle => '課程卡片標題顏色';

  @override
  String get textColorCourseCardDetail => '課程卡片詳情顏色';

  @override
  String get textColorWeekdayBar => '星期欄字體顏色';

  @override
  String get textColorWeekdayBarAccent => '星期欄強調顏色';

  @override
  String get textColorTimeAxis => '時間軸字體顏色';

  @override
  String get textColorSelectColor => '選擇顏色';

  @override
  String get textColorCurrentColor => '目前顏色';

  @override
  String get themeExport => '匯出主題';

  @override
  String get themeImport => '匯入主題';

  @override
  String get themeExportSuccess => '主題已複製到剪貼簿';

  @override
  String get themeImportSuccess => '主題已匯入';

  @override
  String get themeImportFailed => '剪貼簿內容格式錯誤';

  @override
  String get themeManageTitle => '主題管理';

  @override
  String get themeManageSubtitle => '匯出、匯入和切換主題';

  @override
  String get themePreset => '預設主題';

  @override
  String get themeSaved => '我的主題';

  @override
  String get themeSaveCurrent => '儲存當前主題';

  @override
  String get themeApply => '套用';

  @override
  String get themeDelete => '刪除';

  @override
  String themeDeleteConfirmMessage(String name) {
    return '確定要刪除主題「$name」嗎？';
  }

  @override
  String get textColorLowContrastWarning => '顏色對比度較低，可能會影響可讀性';

  @override
  String get themeCurrentTheme => '當前主題';

  @override
  String themeBasedOnModified(String baseName) {
    return '基於$baseName（已修改）';
  }

  @override
  String get themeResetToPreset => '重設';

  @override
  String get themeUnsavedChangesTitle => '未儲存的修改';

  @override
  String get themeUnsavedChangesMessage => '當前主題有未儲存的修改，是否儲存？';

  @override
  String get themeDiscardAndApply => '放棄並套用';

  @override
  String get themeNameHint => '輸入主題名稱';

  @override
  String get themePresetBlue => '預設藍';

  @override
  String get themePresetPurple => '暗夜紫';

  @override
  String get themePresetGreen => '森林綠';

  @override
  String get themePresetOrange => '暖陽橙';

  @override
  String get themePresetEyeCare => '護眼模式';

  @override
  String get themePresetHighContrast => '高對比度';

  @override
  String get themePresetDarkMinimal => '深色極簡';

  @override
  String get themeUndo => '撤銷';

  @override
  String themeChanged(String themeName) {
    return '已切換到 $themeName';
  }

  @override
  String get themeRename => '重新命名';

  @override
  String get themeDuplicate => '複製';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get appTitle => '輕嶼課表';

  @override
  String get appTitleDebug => '輕嶼課表偵錯版';

  @override
  String get appearanceTitle => '外觀與配色';

  @override
  String get previewTitle => '預覽';

  @override
  String get timetableBackgroundPreview => '課表背景';

  @override
  String get displayModeTitle => '顯示模式';

  @override
  String get displayModeSubtitle => '支持跟隨系統、淺色模式和深色模式。';

  @override
  String get themeModeLabel => '主題模式';

  @override
  String get themeModeSystem => '跟隨系統';

  @override
  String get themeModeLight => '淺色模式';

  @override
  String get themeModeDark => '深色模式';

  @override
  String get fontSectionTitle => '應用字體';

  @override
  String get fontSectionSubtitle => '支持系統預設字體和 MiSans。MiSans 不可用時會自動回退。';

  @override
  String get fontModeLabel => '字體選擇';

  @override
  String get fontModeSystem => '手機預設字體';

  @override
  String get fontModeMiSans => 'MiSans（優先）';

  @override
  String get languageSectionTitle => '應用語言';

  @override
  String get languageSectionSubtitle => '可跟隨系統，或手動切換到已適配語言。';

  @override
  String get languageModeLabel => '語言選擇';

  @override
  String get languageModeSystem => '跟隨系統';

  @override
  String get settingsTitle => '課表設定';

  @override
  String get dailyUsageSectionTitle => '日常使用';

  @override
  String get appearanceEntryTitle => '外觀與配色';

  @override
  String get appearanceEntrySubtitle => '主題色、課表背景、課程卡片顏色';

  @override
  String get layoutSectionEntryTitle => '布局與節次';

  @override
  String get layoutSectionEntrySubtitle => '節次時間、行高、時間列、周末顯示與卡片布局';

  @override
  String get homeWidgetEntryTitle => '桌面小工具';

  @override
  String get homeWidgetEntrySubtitle => '今日課程卡片、小工具背景與顯示資訊';

  @override
  String get reminderNotificationSectionTitle => '提醒與通知';

  @override
  String get userGuideEntryTitle => '使用引導與權限';

  @override
  String get userGuideEntrySubtitle => '簡稱建議、通知、自啟動、電池策略';

  @override
  String get timetableManagementSectionTitle => '課表管理';

  @override
  String get timeSchemeEntryTitle => '時間範本';

  @override
  String get timeSchemeEntrySubtitleNoneSelected => '切換、編輯節次、複製和管理時間範本';

  @override
  String timeSchemeEntrySubtitleSelected(String name) {
    return '目前：$name · 切換、編輯節次和複製';
  }

  @override
  String get dataTransferEntryTitle => '資料備份與遷移';

  @override
  String get dataTransferEntrySubtitle => '匯出完整課表檔案，給別人直接匯入使用';

  @override
  String get lanEditEntryTitle => '區域網路編輯';

  @override
  String get lanEditEntrySubtitle => '在電腦瀏覽器中編輯目前課表';

  @override
  String get lanEditTitle => '區域網路編輯';

  @override
  String get lanEditIntro =>
      '開啟後，同一 Wi-Fi 或手機熱點下的電腦可透過瀏覽器編輯目前課表。資料不會上傳雲端，關閉後即停止存取。';

  @override
  String get lanEditStart => '開啟區域網路編輯';

  @override
  String get lanEditStop => '停止';

  @override
  String get lanEditStatusRunning => '編輯工作階段進行中';

  @override
  String get lanEditAddressLabel => '存取網址';

  @override
  String get lanEditAddressUnavailable => '未偵測到區域網路 IP，請確認已連接 Wi-Fi 或已開啟熱點';

  @override
  String get lanEditPinLabel => 'PIN';

  @override
  String get lanEditPortLabel => '連接埠';

  @override
  String get lanEditCopyAddress => '複製網址';

  @override
  String get lanEditCopied => '網址已複製';

  @override
  String get lanEditHotspotHint => '若宿舍 Wi-Fi 無法存取，請嘗試用手機開熱點，再讓電腦連接該熱點。';

  @override
  String get lanEditQrHint => '電腦瀏覽器掃描上方二維碼可開啟控制台（連結已含 PIN，需同一區域網路）。';

  @override
  String get lanEditStartFailed => '啟動失敗';

  @override
  String get lanEditConnectedClientsLabel => '已連接';

  @override
  String get lanEditConnectedClientsNone => '暫無';

  @override
  String lanEditConnectedClientsValue(int count) {
    return '$count 台';
  }

  @override
  String get lanEditLastActivityLabel => '最近活動';

  @override
  String get aboutSupportSectionTitle => '關於與支持';

  @override
  String get feedbackEntryTitle => '問題回饋';

  @override
  String get feedbackEntrySubtitle => 'Issue、社区渠道和建議反饋入口';

  @override
  String get aboutEntryTitle => '關於軟件';

  @override
  String get aboutEntrySubtitle => '開源說明、版本更新和 GitHub 倉庫';

  @override
  String get setSemesterStartDateAction => '設定開學日期';

  @override
  String get semesterStartDateAction => '開學日期';

  @override
  String get syncCurrentWeekAction => '同步目前周';

  @override
  String semesterWeekCountAction(int count) {
    return '$count 周';
  }

  @override
  String get selectSemesterWeekCountTitle => '選擇學期周數';

  @override
  String get selectSemesterWeekCountSubtitle => '不同學校可按實際教學周數調整。';

  @override
  String get unifiedCourseCardColorTitle => '統一課程卡片顏色';

  @override
  String get unifiedCourseCardColorSubtitle => '關閉後繼續使用每門課程自己的顏色';

  @override
  String get courseImportTitle => '匯入課程';

  @override
  String get chooseImportMethodTitle => '選擇匯入方式';

  @override
  String get chooseImportMethodSubtitle =>
      '現在支持傳統 .ics 日歷匯入、識圖匯入，以及從倉庫讀取適配器的教務系統匯入。';

  @override
  String get importMethodIcsTitle => '.ics 日歷匯入';

  @override
  String get importMethodIcsSubtitle => '適合從 WakeUp 等課表應用匯出的日歷檔案，流程最短。';

  @override
  String get importMethodIcsFooter => '進入後直接選擇 .ics 檔案，可追加匯入或替換現有課程。';

  @override
  String get importMethodAiTitle => '識圖匯入';

  @override
  String get importMethodAiSubtitle => '適合直接從課表截圖匯入，支持 1 張或多張連續截圖。';

  @override
  String get importMethodAiFooter =>
      '先複製提示詞，再到豆包專家模式發送截圖和提示詞，把返回的 JSON 複製回來匯入，最後選擇開學日期。';

  @override
  String get importMethodWarehouseTitle => '教務系統匯入';

  @override
  String get importMethodWarehouseSubtitle =>
      '從 qingyu_warehouse 讀取學校與適配器，支持網頁登錄匯入課程。';

  @override
  String get importMethodWarehouseFooter => '進入後選擇學校和適配器，可直接打開教務網頁登錄並執行匯入。';

  @override
  String get importMethodSpreadsheetTitle => '表格匯入';

  @override
  String get importMethodSpreadsheetSubtitle =>
      '適合用 Excel/WPS 填寫輕嶼課表模板後匯入，無需先匯出 .ics。';

  @override
  String get importMethodSpreadsheetFooter =>
      '支持 .csv 與 .xlsx，可下載官方模板填寫後選擇檔案匯入。';

  @override
  String get spreadsheetImportTitle => '表格匯入';

  @override
  String get spreadsheetScenarioIntro =>
      '輕嶼模板依表頭辨識欄位：必填為課程名、星期、開始節、結束節及週次；其餘為可選。可下載完整模板，或只保留必要欄。亦相容 WakeUp 7 欄格式。';

  @override
  String get spreadsheetStep1Subtitle => '下載完整模板填寫，或只保留必填欄與上課週（或開始週+結束週）做最小匯入。';

  @override
  String get spreadsheetStep2Subtitle => '填寫完成後另存為 .csv 或直接保留 .xlsx。';

  @override
  String get spreadsheetStep3Subtitle => '選擇檔案匯入；如有識別提醒會先展示，再選擇追加或替換。';

  @override
  String get spreadsheetSupportedFilesSuffix => '支持 .csv 與 .xlsx（僅讀取第一個工作表）。';

  @override
  String get chooseSpreadsheetFileAction => '選擇表格檔案';

  @override
  String get downloadSpreadsheetTemplateAction => '下載輕嶼課表模板';

  @override
  String get spreadsheetImportWarningsTitle => '匯入提醒';

  @override
  String get spreadsheetImportWarningsMessage => '以下行未能匯入，其餘課程可繼續：';

  @override
  String get spreadsheetImportWarningsContinue => '繼續匯入';

  @override
  String get spreadsheetFormatUnrecognized =>
      '未識別表格格式，請使用輕嶼課表模板；也相容 WakeUp 等同列格式';

  @override
  String get icsImportTitle => '.ics 日歷匯入';

  @override
  String get applicableScenarioTitle => '適用場景';

  @override
  String get icsScenarioIntro =>
      '如果你已經能在 WakeUp 等課表應用裡匯入教務系統課程，再匯出為 .ics 檔案，這條路最穩。';

  @override
  String stepLabel(String step) {
    return '步骤 $step';
  }

  @override
  String get icsStep1Subtitle => '先在其他課表應用裡匯出 .ics 日歷檔案。';

  @override
  String get icsStep2Subtitle => '回到這裡選擇檔案，可選“追加匯入”或“替換現有”。';

  @override
  String get icsStep3Subtitle => '匯入前還會讓你確認開學日期，以及課表第 1 周對應校歷第几周。';

  @override
  String get supportedFilesTitle => '支持的檔案';

  @override
  String get supportedFilesSuffix => '檔案後綴必須是 .ics。';

  @override
  String get supportedFilesImageHint => '如果你手裡只有截圖，不要走這裡，請返回上一頁選擇“識圖匯入”。';

  @override
  String get chooseIcsFileAction => '選擇 .ics 檔案';

  @override
  String get timetableAppName => '輕嶼課表';

  @override
  String get switchProfileHint => '點擊切換課表';

  @override
  String get moreTooltip => '更多';

  @override
  String get pleaseSetSemesterStartDate => '請先在課表設定裡填寫開學日期';

  @override
  String get deleteScheduleTitle => '刪除日程';

  @override
  String get deleteLessonTitle => '刪除這節課';

  @override
  String get cancelAction => '取消';

  @override
  String get confirmAction => '確認';

  @override
  String get deleteAction => '刪除';

  @override
  String deletedCourseMessage(String name) {
    return '已刪除：$name';
  }

  @override
  String get deleteFailed => '刪除失敗';

  @override
  String get rescheduleFailed => '調課失敗';

  @override
  String get timetableManagement => '課表管理';

  @override
  String weekLabel(int week) {
    return '第 $week 周';
  }

  @override
  String sectionLabel(int section) {
    return '第 $section 節';
  }

  @override
  String get feedbackTitle => '問題回饋';

  @override
  String get feedbackIntro => '如果你遇到崩溃、課程顯示異常、匯入問題，或者想提交功能建議，可以通過下面這些渠道反饋。';

  @override
  String get feedbackIssueHint => '涉及複現步骤、截圖、版本號和日誌的問題，建議優先走 GitHub Issue。';

  @override
  String get githubIssueTitle => 'GitHub Issue';

  @override
  String get githubIssueSubtitle => '打開倉庫 Issue 頁面，可提交問題、建議或查看已有反饋記錄。';

  @override
  String get openIssuePage => '打開 Issue 頁面';

  @override
  String get copyAddress => '複製地址';

  @override
  String get copiedIssueAddress => '已複製 Issue 地址';

  @override
  String get copyXiaohongshuId => '複製小紅書號';

  @override
  String get copiedXiaohongshuId => '已複製小紅書號';

  @override
  String get copyCoolapkId => '複製酷安號';

  @override
  String get copiedCoolapkId => '已複製酷安號';

  @override
  String get copyQqGroupId => '複製群號';

  @override
  String get copiedQqGroupId => '已複製 QQ 群號';

  @override
  String get timetableProfilesTitle => '課表管理';

  @override
  String get createTimetableTooltip => '新建課表';

  @override
  String coursesAndWeekSummary(int count, int week) {
    return '$count 門課程 · 第 $week 周';
  }

  @override
  String get moreActionsTooltip => '更多操作';

  @override
  String get switchToThisTimetable => '切換到此課表';

  @override
  String get renameAction => '重新命名';

  @override
  String get duplicateAction => '複製';

  @override
  String get clearCoursesAction => '清空課程';

  @override
  String get usingNow => '正在使用';

  @override
  String switchedToProfile(String name) {
    return '已切換到 $name';
  }

  @override
  String get createTimetableTitle => '新建課表';

  @override
  String get timetableNameLabel => '課表名稱';

  @override
  String get timetableNameHint => '例如：大二下';

  @override
  String get createAction => '建立';

  @override
  String createdProfile(String name) {
    return '已建立課表：$name';
  }

  @override
  String get renameTimetableTitle => '重新命名課表';

  @override
  String get saveAction => '保存';

  @override
  String renamedProfile(String name) {
    return '已重新命名為 $name';
  }

  @override
  String get clearCurrentTimetableTitle => '清空目前課表';

  @override
  String clearCurrentTimetableMessage(String name) {
    return '確定清空“$name”的全部課程嗎？課表設定會保留。';
  }

  @override
  String get clearAction => '清空';

  @override
  String clearedProfile(String name) {
    return '已清空課表：$name';
  }

  @override
  String get noCoursesInCurrentProfile => '目前課表已經沒有有課程';

  @override
  String get deleteTimetableTitle => '刪除課表';

  @override
  String deleteTimetableMessage(String name) {
    return '確定刪除“$name”嗎？';
  }

  @override
  String deletedProfile(String name) {
    return '已刪除課表：$name';
  }

  @override
  String get keepAtLeastOneProfile => '至少保留一個課表';

  @override
  String get dataTransferTitle => '資料備份與遷移';

  @override
  String get fullExportTitle => '完整匯出';

  @override
  String get fullExportSubtitle => '支持匯出目前課表，或一次匯出全部課表、時間範本和目前選中狀態。';

  @override
  String get exportCurrentTimetable => '匯出目前課表';

  @override
  String get exportAllData => '匯出全部資料';

  @override
  String get fullImportTitle => '完整匯入';

  @override
  String get fullImportSubtitle => '匯入時可以選擇覆蓋目前課表，或直接匯入為一個新課表。建議先匯出自己的備份。';

  @override
  String get chooseFileAndImport => '選擇檔案並匯入';

  @override
  String get transferOverviewTitle => '目前可遷移內容';

  @override
  String courseCountBullet(int count) {
    return '課程數量：$count 門';
  }

  @override
  String currentTimetableBullet(String name) {
    return '目前課表：$name';
  }

  @override
  String allTimetablesBullet(int count) {
    return '全部課表：$count 個';
  }

  @override
  String timeSchemeCountBullet(int count) {
    return '時間範本：$count 套';
  }

  @override
  String currentWeekBullet(int week) {
    return '目前周：第 $week 周';
  }

  @override
  String get semesterStartUnsetBullet => '開學日期：未設定';

  @override
  String semesterStartBullet(String date) {
    return '開學日期：$date';
  }

  @override
  String fileExtensionBullet(String extension) {
    return '檔案後綴：.$extension';
  }

  @override
  String get selectImportModeTitle => '選擇匯入方式';

  @override
  String get selectImportModeMessage => '你可以覆蓋目前課表，或者把備份匯入成一個新的独立課表。';

  @override
  String get replaceCurrentTimetable => '覆蓋目前課表';

  @override
  String get importAsNewTimetable => '匯入為新課表';

  @override
  String get createdNewTimetableAfterImport => '匯入成功，已建立新的課表';

  @override
  String get backupRestoredSuccess => '匯入成功，備份資料已還原';

  @override
  String get importFailedInvalidFile => '匯入失敗，請確認檔案有效';

  @override
  String get welcomeTitle => '歡迎使用';

  @override
  String get welcomeAppName => '輕嶼課表';

  @override
  String get welcomeSubtitle => '你可以先開始使用，也可以直接匯入課程或從備份還原。';

  @override
  String get startUsingTitle => '開始使用';

  @override
  String get startUsingSubtitle => '直接進入軟件，並繼續完成首次使用說明';

  @override
  String get importTimetableTitle => '匯入課表';

  @override
  String get importTimetableSubtitle => '從 .ics 檔案或 AI 解析結果匯入課程';

  @override
  String get restoreBackupTitle => '從備份還原';

  @override
  String get restoreBackupSubtitle => '從 .mikcb 備份檔案還原舊資料';

  @override
  String get viewGuideTitle => '查看功能說明';

  @override
  String get viewGuideSubtitle => '先了解權限、超級島和基础設定';

  @override
  String get migrationTitle => '遷移舊資料';

  @override
  String get migrationSafeTitle => '別擔心，這不是資料丢失';

  @override
  String get migrationSafeSubtitle =>
      '我們更換了應用包名，所以桌面上會暫時出現兩個應用圖示，這是正常現象。舊資料仍在舊版應用裡，請先去舊版備份，再回到新版匯入。';

  @override
  String get migrationStep1Title => '打開舊版應用';

  @override
  String get migrationStep1Subtitle =>
      '進入“資料備份與遷移”頁面後，請點“匯出全部資料”。不要點“匯出目前課表”，也不要先卸載舊版。';

  @override
  String get migrationStep2Title => '保存備份檔案';

  @override
  String get migrationStep2Subtitle =>
      '舊版匯出後會彈出系統分享面板。優先選擇“保存到檔案”，建議存到 下載 / Download 檔案夾。';

  @override
  String get migrationStep3Title => '回到目前版本匯入';

  @override
  String get migrationStep3Subtitle =>
      '回到新版後，通過系統檔案選擇器到 下載 / Download 檔案夾選中 .mikcb 備份檔案即可還原。確認新版資料正常後，再卸載舊版應用。';

  @override
  String get migrationNoSaveToFilesTitle => '如果沒有有“保存到檔案”';

  @override
  String get migrationNoSaveToFilesSubtitle =>
      '可以先分享到微信任意一個聊天，然後在微信裡點開這個備份檔案並保存。保存後通常會出現在 Download / WeiXin 檔案夾裡，再回到新版選擇這個 .mikcb 檔案匯入。';

  @override
  String get openingOldApp => '正在打開舊版...';

  @override
  String get openOldAppForBackup => '打開舊版去備份';

  @override
  String get backupDoneGoImport => '我已完成備份，去匯入';

  @override
  String get startFreshWithoutMigration => '以全新應用開始，不遷移';

  @override
  String get openOldAppFailed => '未能打開舊版應用，請手動返回桌面打開舊版';

  @override
  String get supportCreatorTitle => '請作者喝杯咖啡';

  @override
  String get supportHeroTitle => '支持輕嶼課表繼續更新';

  @override
  String get supportHeroSubtitle => '你的支持會直接用於維護課表、教務匯入適配與體驗優化。';

  @override
  String get supportChipFixes => '修複問題';

  @override
  String get supportChipAdapters => '教務適配';

  @override
  String get supportChipPolish => '體驗優化';

  @override
  String get supportMethodTitle => '選擇支持方式';

  @override
  String get wechatLabel => '微信';

  @override
  String get alipayLabel => '支付寶';

  @override
  String get supportWeChatHint => '使用微信掃一掃支持作者';

  @override
  String get supportAlipayHint => '使用支付寶掃一掃支持作者';

  @override
  String get viewLargeImage => '查看大圖';

  @override
  String get saveToGallery => '保存到相冊';

  @override
  String get supportCompleteThanks => '感谢你支持輕嶼課表繼續打磨 ❤️';

  @override
  String get supportConfirmed => '我已經支持了';

  @override
  String get donorListTitle => '鳴谢名單';

  @override
  String get donorListLoadFailed => '暫時無法加載在線鳴谢名單。';

  @override
  String get reloadAction => '重新加載';

  @override
  String updatedAtLabel(String time) {
    return '更新於 $time';
  }

  @override
  String get donorListEmpty => '名單還沒有有填寫，你可以直接編輯 docs/donors.json 後重新發布。';

  @override
  String get savedToGallery => '已保存到相冊';

  @override
  String get saveToGalleryFailed => '保存到相冊失敗';

  @override
  String saveFailedWithError(String error) {
    return '保存失敗：$error';
  }

  @override
  String get courseOverviewTitle => '課程總覽與編輯';

  @override
  String get addNewCourseTooltip => '添加新課程';

  @override
  String get emptyCourseOverviewHint => '長按課表或點擊右上角添加課程';

  @override
  String conflictDetectedMessage(int count) {
    return '檢測到 $count 門排課存在實際衝突，課程列表已標記衝突項。';
  }

  @override
  String conflictCountLabel(int count) {
    return '衝突 $count 節';
  }

  @override
  String scheduledCountLabel(int count) {
    return '共排課 $count 節';
  }

  @override
  String scheduledCountWithConflictHint(int count) {
    return '共排課 $count 節 · 展開查看衝突詳情';
  }

  @override
  String courseTimeSummary(int day, int start, int end) {
    return '時間: 星期$day 第$start-$end節';
  }

  @override
  String get teacherUnset => '未置';

  @override
  String get locationUnset => '未置';

  @override
  String courseDetailSummary(
    String weekDescription,
    String teacher,
    String location,
  ) {
    return '$weekDescription  教師: $teacher  教室: $location';
  }

  @override
  String courseDetailSummaryWithConflict(
    String weekDescription,
    String teacher,
    String location,
    String conflictSummary,
  ) {
    return '$weekDescription  教師: $teacher  教室: $location\n衝突課程: $conflictSummary';
  }

  @override
  String get confirmDeleteTitle => '確認刪除';

  @override
  String confirmDeleteCourseMessage(String name) {
    return '確定要刪除課程“$name”嗎？';
  }

  @override
  String get currentScheduleTitle => '目前排課';

  @override
  String get currentScheduleSubtitle => '這裡的星期、節次、教室、周次和單雙周只影響目前這一條排課。';

  @override
  String get timeSchemeLabel => '上課時間方案';

  @override
  String followCurrentTimetableWithName(String name) {
    return '跟隨目前課表（$name）';
  }

  @override
  String get followCurrentTimetableDescription => '預設跟隨目前課表主時間範本，適合大多數課程。';

  @override
  String get overrideTimeSchemeDescription => '這門課會單独使用所選時間範本，不跟隨目前課表主時間範本。';

  @override
  String get weekdayLabel => '星期';

  @override
  String get startSectionLabel => '開始節次';

  @override
  String get endSectionLabel => '結束節次';

  @override
  String timeRangeLabel(String start, String end) {
    return '時間: $start - $end';
  }

  @override
  String get locationLabel => '上課地點';

  @override
  String get singleLessonWeekTitle => '上課周次';

  @override
  String get singleLessonWeekSubtitle => '單節課只會出現在一個周次裡，適合補課、臨時加課。';

  @override
  String get selectWeekLabel => '選擇周次';

  @override
  String get weekSettingsTitle => '周次設定';

  @override
  String get rangeWeeksLabel => '連續周';

  @override
  String get customWeeksLabel => '自定義周';

  @override
  String get startWeekLabel => '開始周';

  @override
  String get endWeekLabel => '結束周';

  @override
  String get allWeeksFilter => '全部';

  @override
  String get oddWeeksFilter => '單周';

  @override
  String get evenWeeksFilter => '雙周';

  @override
  String get rangeWeeksAllHint => '按開始周到結束周連續排課。';

  @override
  String get rangeWeeksOddHint => '只保留范圍內的單周。';

  @override
  String get rangeWeeksEvenHint => '只保留范圍內的雙周。';

  @override
  String get selectAllAction => '全選';

  @override
  String get selectOddWeeksAction => '單周';

  @override
  String get selectEvenWeeksAction => '雙周';

  @override
  String selectedWeeksSummary(int count, String weeks) {
    return '已選 $count 周：第$weeks周';
  }

  @override
  String get courseColorTitle => '課程顏色';

  @override
  String get customPaletteAction => '調色盤自定義顏色';

  @override
  String get colorPaletteTitle => '調色盤';

  @override
  String get colorHexLabel => '顏色 Hex';

  @override
  String get weekdayMon => '周一';

  @override
  String get weekdayTue => '周二';

  @override
  String get weekdayWed => '周三';

  @override
  String get weekdayThu => '周四';

  @override
  String get weekdayFri => '周五';

  @override
  String get weekdaySat => '周六';

  @override
  String get weekdaySun => '周日';

  @override
  String hueLabel(int value) {
    return '色相 $value';
  }

  @override
  String saturationLabel(int value) {
    return '饱和度 $value%';
  }

  @override
  String brightnessLabel(int value) {
    return '明度 $value%';
  }

  @override
  String get useThisColor => '使用這個顏色';

  @override
  String get selectAtLeastOneWeek => '請至少選擇一個上課周次';

  @override
  String get saveFailed => '保存失敗';

  @override
  String get courseAddedSuccess => '課程添加成功';

  @override
  String get courseUpdatedSuccess => '課程更新成功';

  @override
  String get aboutTitle => '關於軟件';

  @override
  String get loadingText => '讀取中';

  @override
  String versionLabel(String version) {
    return '版本 $version';
  }

  @override
  String get aboutHeroSubtitle =>
      '一個圍繞課表查看、課程提醒和 HyperOS 超級島體驗打磨的 Android 開源項目。';

  @override
  String get platformLabel => '平台';

  @override
  String get focusLabel => '重點';

  @override
  String get updateLabel => '更新';

  @override
  String get prereleaseIncluded => '含預發布';

  @override
  String get stableOnly => '正式版';

  @override
  String get aboutUpdatesTitle => '版本更新';

  @override
  String get aboutUpdatesSubtitle => '檢查更新、立即下載，以及測試與診斷入口';

  @override
  String get aboutChangelogTitle => '更新日誌';

  @override
  String get aboutChangelogSubtitle => '查看所有版本的更新內容';

  @override
  String get aboutPositioningTitle => '項目定位';

  @override
  String get aboutPositioningSubtitle => '這是什麼、適合誰、核心能力是什麼';

  @override
  String get aboutPositioningBullet1 => '支持周視圖課表、課程增刪改、.ics 匯入';

  @override
  String get aboutPositioningBullet2 => '已支持適配學校的教務系統網頁登錄匯入與完整備份遷移';

  @override
  String get aboutPositioningBullet3 =>
      '支持實時通知；HyperOS 3.0.300 起支持超級島 / 焦點通知展示';

  @override
  String get aboutPositioningBullet4 => '支持多課表、時間範本、主題色和卡片樣式自定義';

  @override
  String get aboutImportMigrationTitle => '匯入與遷移';

  @override
  String get aboutImportMigrationSubtitle => '目前匯入方式、備份還原和遷移建議';

  @override
  String get aboutImportMigrationBullet1 =>
      '目前版本已經支持適配學校的教務系統網頁登錄匯入；進入“匯入課程 > 教務系統匯入”後選擇學校和適配器即可。';

  @override
  String get aboutImportMigrationBullet2 =>
      '如果你的學校暫時還沒有適配，仍然可以先在 WakeUp 等課表應用裡匯入課程，再匯出為日歷格式，然後在本應用匯入。';

  @override
  String get aboutImportMigrationBullet3 =>
      '如果其他人已經在用本應用，也可以直接讓對方匯出完整備份檔案，你在“資料備份與遷移”裡匯入即可直接還原。';

  @override
  String get aboutImportMigrationBullet4 =>
      '如果你會抓包、網頁偵錯或 JavaScript，也歡迎去 qingyu_warehouse 參與教務適配補充。';

  @override
  String get aboutContributorsTitle => '代碼貢獻者';

  @override
  String get aboutContributorsSubtitle => '開發人員與教務匯入適配者名單';

  @override
  String get aboutRepositoryTitle => '開源倉庫';

  @override
  String get aboutAppLogsTitle => '應用日誌';

  @override
  String get aboutAppLogsSubtitle =>
      '查看整個軟體的 error / warn / info / debug / verbose 全等級日誌';

  @override
  String get appLogsShareText =>
      '這是輕嶼課表匯出的應用日誌，包含整個軟體的本地執行記錄，可用於排查更新、匯入、通知、頁面與崩潰問題。';

  @override
  String get appLogsShareSubject => '輕嶼課表 - 應用日誌';

  @override
  String get appLogsRecordingEnabled => '正在記錄應用日誌';

  @override
  String get appLogsRecordingDisabled => '應用日誌記錄已關閉';

  @override
  String get appLogsCopyAction => '複製日誌';

  @override
  String get appLogsCopied => '已複製目前日誌';

  @override
  String get appLogsExportAction => '匯出日誌';

  @override
  String get appLogsClearAction => '清空日誌';

  @override
  String get appLogsCleared => '已清空應用日誌';

  @override
  String get appLogsClearFailed => '清空應用日誌失敗';

  @override
  String get aboutRepositorySubtitle => 'GitHub 倉庫地址、源碼、Release 和反饋入口';

  @override
  String get timeSchemeTitle => '時間範本';

  @override
  String get newSchemeTooltip => '新建範本';

  @override
  String timeSchemeSummary(
    int sections,
    int profiles,
    int courses,
    int overrideCourses,
  ) {
    return '$sections 節 · $profiles 個課表 · $courses 節課程 · $overrideCourses 節副時間表';
  }

  @override
  String get viewUsageAction => '查看使用情況';

  @override
  String get applyToCurrentTimetable => '應用到目前課表';

  @override
  String get editSectionsAction => '編輯節次';

  @override
  String get createTimeSchemeTitle => '新建時間範本';

  @override
  String get timeSchemeNameLabel => '範本名稱';

  @override
  String get timeSchemeNameHint => '例如：本校夏季作息';

  @override
  String get renameTimeSchemeTitle => '重新命名時間範本';

  @override
  String renamedToMessage(String name) {
    return '已重新命名為 $name';
  }

  @override
  String get deleteTimeSchemeTitle => '刪除時間範本';

  @override
  String deleteTimeSchemeMessage(String name) {
    return '確定刪除“$name”嗎？正在使用中的範本不能刪除。';
  }

  @override
  String deletedTimeSchemeMessage(String name) {
    return '已刪除時間範本：$name';
  }

  @override
  String get timeSchemeInUseMessage => '該範本正在被課表使用';

  @override
  String get copiedTimeSchemeMessage => '已複製時間範本';

  @override
  String appliedTimeSchemeMessage(String name) {
    return '已應用時間範本：$name';
  }

  @override
  String timeSchemeUsageTitle(String name) {
    return '“$name”的使用情況';
  }

  @override
  String get timeSchemeUsageIntro => '先看總影響范圍，再決定是直接編輯這套範本，還是先複製一套再改。';

  @override
  String get profileCountLabel => '課表';

  @override
  String get courseCountLabel => '課程';

  @override
  String get overrideTimeSchemeLabel => '副時間表';

  @override
  String get directlyBoundProfilesTitle => '直接綁定這套範本的課表';

  @override
  String get directlyBoundProfilesEmpty => '目前沒有有課表直接使用這套範本。';

  @override
  String get directlyBoundProfilesSubtitle => '這些課表切到這套範本後，預設都會按這套節次時間顯示。';

  @override
  String get followMainSchemeCoursesTitle => '跟隨課表主時間表的課程';

  @override
  String get followMainSchemeCoursesEmpty => '目前沒有有課程通過課表主時間表間接使用它。';

  @override
  String get followMainSchemeCoursesSubtitle =>
      '這些課程沒有有單独設定副時間表，而是跟著所屬課表一起用這套範本。';

  @override
  String get overrideSchemeCoursesTitle => '把它作為副時間表的課程';

  @override
  String get overrideSchemeCoursesEmpty => '目前沒有有課程把它作為副時間表。';

  @override
  String get overrideSchemeCoursesSubtitle => '這些課程即使所在課表切換了主範本，也會繼續單独使用這套時間。';

  @override
  String get closeAction => '關閉';

  @override
  String get editTimeSchemeTitle => '編輯時間範本';

  @override
  String get backToSchemeList => '返回範本列表';

  @override
  String get currentInUse => '目前使用';

  @override
  String get quickGenerateAction => '快捷生成';

  @override
  String get addSectionAction => '新增一節';

  @override
  String get removeLastSectionAction => '刪除末節';

  @override
  String get resetDefaultAction => '還原預設';

  @override
  String get sectionTimesTitle => '節次時間';

  @override
  String get sectionTimesSubtitle => '如果目前課表正在使用這套範本，節次數量不能小於已使用的最大節次。';

  @override
  String get schemeListCurrentLabel => '目前';

  @override
  String get schemeListCountLabel => '數量';

  @override
  String get sectionCountLabel => '節數';

  @override
  String get quickGenerateTimeSchemeTitle => '快捷生成課表時間';

  @override
  String get addBreakRuleAction => '新增大課間規則';

  @override
  String get afterSectionLabel => '第几節後';

  @override
  String get breakDurationMinutesLabel => '休息多久(分)';

  @override
  String get fillNumbersValidationMessage => '請把節數和時長填寫為數字';

  @override
  String get timeSchemeEditorActiveAndCoursesHint =>
      '目前課表和部分課程正在使用這套時間範本，保存後會同步更新所有相關課表和課程。';

  @override
  String get timeSchemeEditorActiveHint => '目前課表正在使用這套時間範本，保存後會同步更新所有使用它的課表。';

  @override
  String get timeSchemeEditorOverrideHint =>
      '有課程正在把這套範本作為副時間表使用，保存後會同步更新所有引用課程。';

  @override
  String get editTimeAction => '編輯時間';

  @override
  String editingSchemeLabel(String name) {
    return '正在編輯：$name';
  }

  @override
  String get copiedTimeSchemeShortMessage => '已複製時間範本';

  @override
  String get unnamedTimeScheme => '未命名範本';

  @override
  String get unsetLabel => '未選擇';

  @override
  String get timeSchemeUsageCourseRefPrefix => '課程引用：';

  @override
  String get mainTimeSchemeLabel => '主時間表';

  @override
  String get overrideTimeSchemeShortLabel => '副時間表';

  @override
  String timeSchemeBottomUsageSingle(String first) {
    return '$first';
  }

  @override
  String timeSchemeBottomUsageMulti(String first, int count) {
    return '$first 等 $count 節課程';
  }

  @override
  String get morningSectionCountLabel => '上午几節';

  @override
  String get morningFirstSectionTimeLabel => '早上第一節時間';

  @override
  String get afternoonSectionCountLabel => '下午几節';

  @override
  String get afternoonFirstSectionTimeLabel => '下午第一節時間';

  @override
  String get eveningSectionCountLabel => '晚上几節';

  @override
  String get eveningFirstSectionTimeLabel => '晚上第一節時間';

  @override
  String get classDurationMinutesLabel => '單節課時長（分鐘）';

  @override
  String get smallBreakDurationMinutesLabel => '小課間時長（分鐘）';

  @override
  String get largeBreakRulesTitle => '大課間規則';

  @override
  String get noLargeBreakRulesHint => '未設定大課間規則，將全部使用小課間時長。';

  @override
  String get deleteRuleTooltip => '刪除規則';

  @override
  String get generateAction => '生成';

  @override
  String get liveSettingsTitle => '超級島與通知';

  @override
  String get liveReminderTimingEntryTitle => '提醒時段';

  @override
  String get liveReminderTimingEntrySubtitle =>
      '上課前、課中/下課提醒開關，以及下課前多久切到超級島 / 重點提醒';

  @override
  String get liveBeforeClassDisplayEntryTitle => '上課前提醒顯示';

  @override
  String get liveDuringEndDisplayEntryTitle => '課中/下課提醒顯示';

  @override
  String get liveKeepAliveEntryTitle => '後台保活';

  @override
  String get liveKeepAliveEntrySubtitle => '隱藏後台、後台保活輔助服務和權限入口';

  @override
  String get liveTestingEntryTitle => '測試與診斷';

  @override
  String get liveTestingEntrySubtitle => '發送測試通知，檢查超級島和本地診斷日誌';

  @override
  String get followBeforeClassSetting => '跟隨上課前提醒';

  @override
  String get liveReminderTimingTitle => '提醒時段';

  @override
  String get liveReminderSwitchesTitle => '提醒開關';

  @override
  String get liveReminderSwitchesSubtitle => '不同提醒時段可以自由組合；這些開關互不替代。';

  @override
  String get beforeClassReminderTitle => '上課前提醒';

  @override
  String beforeClassReminderSubtitle(int minutes) {
    return '在課程開始前 $minutes 分鐘彈出';
  }

  @override
  String get duringClassReminderTitle => '課中 / 下課提醒';

  @override
  String get duringClassReminderSubtitle => '只影響上課後到下課前的展示';

  @override
  String get liveClassReminderLeadTitle => '下課前多久切到超級島 / 重點提醒';

  @override
  String get liveClassReminderLeadOptionImmediate => '一上課就切換';

  @override
  String liveClassReminderLeadOptionMinutes(int minutes) {
    return '下課前 $minutes 分鐘切換';
  }

  @override
  String get liveDisplayModeTitle => '展示方式';

  @override
  String get liveDisplayModeSubtitle => '對已啟用的提醒時段生效。';

  @override
  String get duringClassStatusNotificationTitle => '課中狀態栏通知';

  @override
  String get duringClassStatusNotificationImmediate => '上課後保留狀態栏通知';

  @override
  String get duringClassStatusNotificationBeforeEnd => '在下課提醒開始前保留普通通知文案';

  @override
  String get duringClassStatusNotificationPersistent =>
      '上課後持續顯示普通課中通知，到下課提醒前再切換';

  @override
  String get enableIslandDisplayTitle => '支持展示超級島/靈動島';

  @override
  String get enableIslandDisplaySubtitle => '關閉後不會再尝試觸發系統超級島';

  @override
  String get liveTimeThresholdTitle => '時間阈值';

  @override
  String get liveTimeThresholdSubtitle =>
      '控製上課前彈出、下課前多久切到超級島 / 重點提醒，以及最後秒級倒計時。';

  @override
  String get beforeClassPopupLabel => '上課前彈出時間';

  @override
  String beforeClassMinutesOption(int minutes) {
    return '$minutes 分鐘';
  }

  @override
  String get beforeEndSecondsLabel => '下課前秒級提醒阈值';

  @override
  String beforeEndSecondsOption(int seconds) {
    return '$seconds 秒';
  }

  @override
  String timeCorrectionLabel(String value) {
    return '鈴声時間矯正：$value';
  }

  @override
  String get timeCorrectionHelp => '如果學校鈴声比課表快几秒，就調成提前；如果鈴声慢几秒，就調成延後。';

  @override
  String get duringEndTimeDisplayLabel => '課中 / 下課提醒時間樣式';

  @override
  String get duringEndTimeDisplayHelp => '控製緊湊提醒裡顯示最近時間還是整段總時間。';

  @override
  String get liveDisplayContentTitle => '顯示內容';

  @override
  String get liveDisplayContentSubtitle => '這組設定只影響目前階段，不會改動另一組提醒顯示。';

  @override
  String get showCourseNameTitle => '顯示課程名';

  @override
  String get preferShortNameTitle => '優先顯示課程簡稱';

  @override
  String get preferShortNameSubtitle => '建議簡稱控製在 3 個字以內';

  @override
  String get showLocationTitle => '顯示地點';

  @override
  String get showCountdownTitle => '顯示倒計時';

  @override
  String get countdownFormatLabel => '倒計時格式';

  @override
  String get countdownFormatHelp => '純分鐘樣式按分鐘刷新，帶秒樣式按秒刷新';

  @override
  String get showStageTextTitle => '顯示階段狀態文案';

  @override
  String get showStageTextSubtitle => '關閉倒計時後，可繼續顯示“即將上課 / 上課中 / 下課提醒”';

  @override
  String get hidePrefixTextTitle => '隱藏前綴文案';

  @override
  String get hidePrefixTextSubtitle => '例如隱藏“即將上課”這類前綴';

  @override
  String get beforeClassQuickActionTitle => '上課前快捷操作';

  @override
  String get beforeClassQuickActionSubtitle =>
      '只在上課前提醒的展開通知裡顯示。免打擾首次可能會跳到系統授權頁。';

  @override
  String liveMiuiLabelSizePreview(String value) {
    return '$value';
  }

  @override
  String get liveIslandVisualTitle => '左側圖示與展開態';

  @override
  String get liveIslandVisualSubtitle => '左側文字圖、展開態大圖示和自定義圖片都按目前階段單独保存。';

  @override
  String get liveMiuiLabelImageTitle => '小米島左側文字圖示';

  @override
  String get liveMiuiLabelImageSubtitle => '僅小米手機樣式生效，會把課程名或地點生成到左側圖示位。';

  @override
  String get liveMiuiLabelContentLabel => '左側文字內容';

  @override
  String get liveMiuiLabelStyleLabel => '左側圖示樣式';

  @override
  String get liveMiuiLabelLogoTitle => '左側圖示 Logo';

  @override
  String get liveMiuiLabelLogoSubtitle => '僅在「圖示+文字」樣式下生效；未選擇時會繼續使用應用圖示。';

  @override
  String liveMiuiLabelLogoCornerRadiusLabel(String value) {
    return '左側圖示圓角 $value';
  }

  @override
  String liveMiuiLabelFontSizeLabel(String value) {
    return '左側文字大小 $value';
  }

  @override
  String liveMiuiLabelOffsetXLabel(String value) {
    return '左側文字水平偏移 $value';
  }

  @override
  String liveMiuiLabelOffsetYLabel(String value) {
    return '左側文字垂直偏移 $value';
  }

  @override
  String get liveMiuiLabelFontWeightLabel => '左側文字粗細';

  @override
  String get liveMiuiLabelRenderQualityLabel => '左側文字清晰度';

  @override
  String get liveMiuiExpandedIconLabel => '展開態大圖示';

  @override
  String get selectImageAction => '選擇圖片';

  @override
  String get replaceImageAction => '更換圖片';

  @override
  String get liveDisplayConfigModeTitle => '配置方式';

  @override
  String get liveDisplayConfigModeSubtitle =>
      '打開後，課中和下課提醒會完全跟隨上課前提醒顯示，下面的独立設定暫時不可編輯。';

  @override
  String get followBeforeClassDisplayTitle => '跟隨上課前提醒設定';

  @override
  String get liveKeepAliveTitle => '後台保活';

  @override
  String get liveKeepAliveOptionsTitle => '保活選項';

  @override
  String get liveKeepAliveOptionsSubtitle => '用於提升超級島和提醒在後台場景下的穩定性。';

  @override
  String get hideFromRecentsTitle => '從最近任務中隱藏應用';

  @override
  String get hideFromRecentsSubtitle => '開啟後應用會尽量不顯示在最近任務列表中。';

  @override
  String get keepAliveServiceTitle => '輕嶼課表後台保活服務';

  @override
  String get keepAliveServiceEnabledSubtitle => '目前已開啟。系統會保持後台保活輔助服務處於可用狀態。';

  @override
  String get keepAliveServiceDisabledSubtitle =>
      '目前未開啟。可進入系統無障礙設定手動打開輕嶼課表後台保活服務。';

  @override
  String get goEnableAction => '去開啟';

  @override
  String get layoutEntryTitle => '布局與節次';

  @override
  String get layoutEntrySubtitle => '節次時間、行高、時間列、周末顯示與卡片布局';

  @override
  String get remindersSectionTitle => '提醒與通知';

  @override
  String get liveGuideEntryTitle => '使用引導與權限';

  @override
  String get liveGuideEntrySubtitle => '簡稱建議、通知、自啟動、電池策略';

  @override
  String get managementSectionTitle => '課表管理';

  @override
  String timeSchemeEntryCurrentPrefix(String name) {
    return '目前：$name · 切換、編輯節次和複製';
  }

  @override
  String get timeSchemeEntrySubtitle => '切換、編輯節次、複製和管理時間範本';

  @override
  String semesterOverviewCurrentWeek(int current, int total) {
    return '目前第 $current 周 / 共 $total 周';
  }

  @override
  String get semesterStartUnset => '未設定開學日期';

  @override
  String semesterStartSet(String date) {
    return '開學日期：$date';
  }

  @override
  String get setSemesterStartDate => '設定開學日期';

  @override
  String get semesterStartDateLabel => '開學日期';

  @override
  String syncedCurrentWeekMessage(int week) {
    return '已同步到第 $week 周';
  }

  @override
  String get pickSemesterWeekCountTitle => '選擇學期周數';

  @override
  String get pickSemesterWeekCountSubtitle => '不同學校可按實際教學周數調整。';

  @override
  String weekCountItem(int count) {
    return '$count 周';
  }

  @override
  String get diagnosticsLogIntro => '支持 Markdown 與原文兩種查看方式，排查時可以直接在手機上看完整日誌。';

  @override
  String get diagnosticsRawTab => '原文';

  @override
  String get diagnosticsStructuredTab => '結構化';

  @override
  String get diagnosticsLevelLabel => '等級';

  @override
  String get diagnosticsLevelAll => '全部';

  @override
  String get diagnosticsLevelError => '錯誤';

  @override
  String get diagnosticsLevelWarn => '警告';

  @override
  String get diagnosticsLevelInfo => '資訊';

  @override
  String get diagnosticsLevelDebug => '除錯';

  @override
  String get diagnosticsLevelVerbose => '詳細';

  @override
  String diagnosticsShowingCount(int shown, int total) {
    return '顯示 $shown / $total 條日誌';
  }

  @override
  String get diagnosticsNoMatchingTitle => '目前篩選下沒有日誌';

  @override
  String get diagnosticsNoMatchingSubtitle => '可切換回「全部」，或改看原文繼續排查。';

  @override
  String get diagnosticsLevelInferred => '推斷等級';

  @override
  String get diagnosticsRawFilteredHint => '原文視圖會跟隨目前等級篩選，只顯示對應日誌區塊。';

  @override
  String get diagnosticsEmptyTitle => '暫無日誌';

  @override
  String get diagnosticsEmptySubtitle => '目前沒有有可顯示的超級島診斷日誌。';

  @override
  String get diagnosticsLogTitleFallback => '超級島診斷日誌';

  @override
  String get diagnosticsDeviceInfoTitle => '設備與匯出資訊';

  @override
  String get diagnosticsContentTitle => '日誌內容';

  @override
  String get diagnosticsRecentLogsTitle => '最近日誌';

  @override
  String get diagnosticsUnknownCategory => '未分類事件';

  @override
  String get diagnosticsExportedAt => '匯出時間';

  @override
  String get diagnosticsTime => '時間';

  @override
  String get diagnosticsCategory => '類別';

  @override
  String get diagnosticsMessage => '消息';

  @override
  String get diagnosticsStackTrace => '堆棧';

  @override
  String get firstUseGuideTitle => '首次使用引導';

  @override
  String get guideAndPermissionsTitle => '使用引導與權限';

  @override
  String get refreshStatusTooltip => '刷新狀態';

  @override
  String get guideHeroTitle => '先把這頁做完，再開始用';

  @override
  String get guideHeroSubtitle => '首屏先授權。下面還會明確說明系統版本支持、簡稱設定和匯入方式，記得繼續下滑。';

  @override
  String get guideChipPermissions => '權限準備';

  @override
  String get guideChipShortName => '簡稱設定';

  @override
  String get guideChipImport => '匯入課表';

  @override
  String guideChipReadyCount(int count) {
    return '$count/3 已完成';
  }

  @override
  String get guideBottomReachedHint => '你已經滑到最後了，確認無誤後就可以開始使用。';

  @override
  String get guideScrollHint => '向下滑動繼續，下面還有 HyperOS 版本說明、權限清單、簡稱設定和匯入方式。';

  @override
  String get guideRequestNotificationFirst => '先申請通知權限';

  @override
  String get quickSetupTitle => '首屏快速設定';

  @override
  String get quickSetupSubtitle => '先把最關鍵的 5 個入口放在前面，不用翻到下面再找。';

  @override
  String get quickActionNotificationsTitle => '通知設定';

  @override
  String get quickActionNotificationsSubtitle => '先確保能發通知';

  @override
  String get quickActionIslandTitle => '超級島權限';

  @override
  String get quickActionIslandSubtitle => '檢查 promoted 通知';

  @override
  String get quickActionAutoStartTitle => '自啟動';

  @override
  String get quickActionAutoStartSubtitle => '避免後台被殺';

  @override
  String get quickActionBatteryTitle => '電池無限製';

  @override
  String get quickActionBatterySubtitle => '避免提醒中斷';

  @override
  String get quickActionKeepAliveTitle => '後台保活輔助';

  @override
  String get quickActionKeepAliveSubtitle => '提升後台穩定性';

  @override
  String get guidePrivacyConsentLabel => '我已閱讀並同意友盟相關隱私說明';

  @override
  String get guideRequireConsentHint => '請先滑到底部閱讀說明，並勾選同意後開始使用。';

  @override
  String get guideContinueHint => '繼續下滑查看完整引導內容。';

  @override
  String get exitAppAction => '退出應用';

  @override
  String get continueReadingAction => '繼續查看';

  @override
  String get agreeAndStartAction => '同意並開始使用';

  @override
  String get startUsingAction => '開始使用';

  @override
  String get editSingleLessonTitle => '編輯單節課';

  @override
  String get editCourseTitle => '編輯課程';

  @override
  String get addSingleLessonTitle => '添加單節課';

  @override
  String get addCourseTitle => '添加課程';

  @override
  String get deleteCourseTitle => '刪除課程';

  @override
  String get courseDeleted => '課程已刪除';

  @override
  String get addMethodTitle => '添加方式';

  @override
  String get singleLessonLabel => '單節課';

  @override
  String get recurringLessonLabel => '多節課';

  @override
  String get singleLessonHint => '適合補課、臨時加課，課程只會落在一個周次。';

  @override
  String get recurringLessonHint => '適合同一時間連續上很多周的常規課程。';

  @override
  String get sharedInfoTitle => '共享資訊';

  @override
  String get sharedInfoHint => '課程名、簡稱、老師、課程簡介、課程性質和顏色會同步到同名課程的其他排課。';

  @override
  String get reuseExistingCourseLabel => '沿用已有課程';

  @override
  String get reuseExistingCourseHelper => '選一個已有課程，自動帶入課程名、老師和其他共享資訊';

  @override
  String get manualInputLabel => '手動填寫';

  @override
  String get noTemplateCoursesHint => '目前課表裡還沒有有現成課程，先手動錄入一門，後面臨時加課就能直接選了。';

  @override
  String get courseNameLabel => '課程名稱';

  @override
  String get courseNameHelper => '超級島建議 3 個字以內，顯示效果最好';

  @override
  String get pleaseEnterCourseName => '請輸入課程名稱';

  @override
  String get courseShortNameOptional => '課程簡稱 (可選)';

  @override
  String get teacherLabel => '授課教師';

  @override
  String get courseNatureLabel => '課程性質';

  @override
  String get courseDescriptionOptional => '課程簡介 (可選)';

  @override
  String get currentScheduleHint => '這裡的星期、節次、教室、周次和單雙周只影響目前這一條排課。';

  @override
  String followProfileTimeScheme(String name) {
    return '跟隨目前課表（$name）';
  }

  @override
  String get timeSchemeOverrideLabel => '上課時間方案';

  @override
  String get lessonWeeksTitle => '上課周次';

  @override
  String get singleLessonWeekHint => '單節課只會出現在一個周次裡，適合補課、臨時加課。';

  @override
  String get rangeWeekLabel => '連續周';

  @override
  String get customWeekLabel => '自定義周';

  @override
  String get allWeeksLabel => '全部';

  @override
  String get oddWeeksLabel => '單周';

  @override
  String get evenWeeksLabel => '雙周';

  @override
  String get allWeeksHint => '按開始周到結束周連續排課。';

  @override
  String get oddWeeksHint => '只保留范圍內的單周。';

  @override
  String get evenWeeksHint => '只保留范圍內的雙周。';

  @override
  String get customPaletteColor => '調色盤自定義顏色';

  @override
  String timeSchemeSetCountValue(int count) {
    return '$count 套';
  }

  @override
  String profileCountValue(int count) {
    return '$count 個';
  }

  @override
  String courseSectionCountValue(int count) {
    return '$count 節';
  }

  @override
  String timeSchemeStartsAt(String start) {
    return '$start 起';
  }

  @override
  String get weekdayShortMonday => '一';

  @override
  String get weekdayShortTuesday => '二';

  @override
  String get weekdayShortWednesday => '三';

  @override
  String get weekdayShortThursday => '四';

  @override
  String get weekdayShortFriday => '五';

  @override
  String get weekdayShortSaturday => '六';

  @override
  String get weekdayShortSunday => '日';

  @override
  String weekdaySectionRange(String weekday, int startSection, int endSection) {
    return '週$weekday $startSection-$endSection節';
  }

  @override
  String timeSchemeUsageReference(
    String profileName,
    String courseName,
    String weekday,
    int startSection,
    int endSection,
    String usageType,
  ) {
    return '$profileName · $courseName（週$weekday $startSection-$endSection節，$usageType）';
  }

  @override
  String weekdaySectionSummary(
    String weekday,
    int startSection,
    int endSection,
  ) {
    return '周$weekday $startSection-$endSection節';
  }

  @override
  String get timeRangeValidationNoCrossDay => '結束時間必須晚於開始時間';

  @override
  String get timeSchemeNameEmptyValidation => '時間模板名稱不能為空';

  @override
  String get liveTimeCorrectionNone => '不校正';

  @override
  String liveTimeCorrectionDelay(int seconds) {
    return '整體延後 $seconds 秒';
  }

  @override
  String liveTimeCorrectionAdvance(int seconds) {
    return '整體提前 $seconds 秒';
  }

  @override
  String liveClassReminderLeadSummaryImmediate(int seconds) {
    return '從上課開始就進入重點提醒顯示，並在距離下課 $seconds 秒切到秒級倒數';
  }

  @override
  String liveClassReminderLeadSummaryKeepNormal(int minutes, int seconds) {
    return '上課後先保留普通課中通知，在距離下課前 $minutes 分鐘切到重點提醒 / 下課提醒，並在最後 $seconds 秒切到秒級倒數';
  }

  @override
  String liveClassReminderLeadSummaryIsland(int minutes, int seconds) {
    return '在距離下課前 $minutes 分鐘切到超級島 / 重點提醒，並在最後 $seconds 秒切到秒級倒數';
  }

  @override
  String liveClassReminderLeadSummaryFocused(int minutes, int seconds) {
    return '在距離下課前 $minutes 分鐘開始顯示重點提醒，並在最後 $seconds 秒切到秒級倒數';
  }

  @override
  String get liveSettingsEntrySubtitle => '提醒時段、島顯示、通知欄和顯示內容';

  @override
  String get timetableProfilesEntrySubtitle => '新建、切換、複製、重新命名和刪除課表';

  @override
  String get homeTitleSectionTitle => '首頁標題';

  @override
  String get homeTitleSectionSubtitle => '控制首頁左上角課表切換入口的樣式。';

  @override
  String get homeTitleStyleLabel => '標題樣式';

  @override
  String get themeSeedSectionTitle => '應用主題色';

  @override
  String get themeSeedSectionSubtitle => '影響頂部欄、強調色和全局主色調。';

  @override
  String get timetableBackgroundColorSectionTitle => '課表背景色';

  @override
  String get timetableBackgroundColorSectionSubtitle => '只作用於課表頁面的大背景。';

  @override
  String get defaultTimetablePreviewName => '預設課表';

  @override
  String get beforeClassDisplaySettingsTitle => '上課前提醒顯示';

  @override
  String get duringEndDisplaySettingsTitle => '課中／下課提醒顯示';

  @override
  String get liveDisplaySummaryShortName => '簡稱';

  @override
  String get liveDisplaySummaryCourseName => '課程名';

  @override
  String get liveDisplaySummaryLocation => '地點';

  @override
  String liveDisplaySummaryCountdown(String style) {
    return '倒數（$style）';
  }

  @override
  String get liveDisplaySummaryStageText => '階段文字';

  @override
  String get liveDisplaySummaryLeftLabelImage => '左側圖示';

  @override
  String get liveDisplaySummaryMinimal => '最簡顯示';

  @override
  String get guideHyperOsChip => 'HyperOS 3.0.300+';

  @override
  String get guideStatusTitle => '目前狀態';

  @override
  String get guideStatusNotificationPermission => '通知權限';

  @override
  String get guideStatusEnabled => '已開啟';

  @override
  String get guideStatusDisabled => '未開啟';

  @override
  String get guideStatusIslandSupport => '焦點通知 / 超級島';

  @override
  String get guideStatusSystemAllowed => '系統已允许';

  @override
  String get guideStatusEnabledPending => '已開啟但系統暫未確認';

  @override
  String get guideStatusSuggestedCheck => '建議檢查';

  @override
  String get guideStatusBatteryOptimization => '電池優化';

  @override
  String get guideStatusBatteryUnrestricted => '無限制';

  @override
  String get guideStatusBatteryRestricted => '仍受限制';

  @override
  String get guideStatusKeepAlive => '後台保活輔助';

  @override
  String get guideStatusAndroidVersion => 'Android 版本';

  @override
  String get guideStatusVersionUnknown => '未識别';

  @override
  String get guideStatusIslandSystemSupport => '超級島系統支持';

  @override
  String get guideStatusIslandSystemRequirement => '需 HyperOS 3.0.300 及以上';

  @override
  String get guideStatusIslandHint =>
      '如果你主要想用超級島，先確認系統版本至少是 HyperOS 3.0.300，再继续把下面權限清單按顺序點完。';

  @override
  String get guidePermissionChecklistTitle => '權限清單';

  @override
  String get guidePermissionChecklistSubtitle => '按這個顺序檢查，最省事，也最不容易漏。';

  @override
  String get guideChecklistRequestNotificationTitle => '申请通知權限';

  @override
  String get guideChecklistRequestNotificationSubtitle => '這是所有提醒的前提';

  @override
  String get guideChecklistOpenNotificationTitle => '打開通知設定';

  @override
  String get guideChecklistOpenNotificationSubtitle => '檢查通知总開關、锁屏展示和实時通知權限';

  @override
  String get guideChecklistOpenIslandTitle => '打開焦點通知設定';

  @override
  String get guideChecklistOpenIslandSubtitle =>
      'HyperOS 3.0.300 及以上再檢查 promoted / 超級島通知';

  @override
  String get guideChecklistOpenAutoStartTitle => '打開自啟動設定';

  @override
  String get guideChecklistOpenAutoStartSubtitle => '允许應用開机自啟和後台常驻';

  @override
  String get guideChecklistOpenBatteryTitle => '打開電池策略設定';

  @override
  String get guideChecklistOpenBatterySubtitle => '建議改成無限制，避免上課提醒被中斷';

  @override
  String get guideChecklistOpenKeepAliveTitle => '打開後台保活輔助';

  @override
  String get guideChecklistOpenKeepAliveSubtitle => '進一步提升超級島和提醒在後台場景下的穩定性';

  @override
  String get guideShortNameAdviceTitle => '課程簡稱建議';

  @override
  String get guideShortNameAdviceSubtitle =>
      '超級島支持顯示課程簡稱。簡稱不是自動生成的，需要你在課程编辑裡自己填寫。建議控制在 3 個字以內，顯示会更穩定。';

  @override
  String get guideShortNameRecommended => '推荐示例';

  @override
  String get guideShortNameNotRecommended => '不推荐';

  @override
  String get guideShortNameRecommendedExample => '高數 / 概率 / 數控';

  @override
  String get guideShortNameNotRecommendedExample => '高等數学A(1) / 數控技術及應用';

  @override
  String get guideSetCourseShortNameAction => '去設定課程簡稱';

  @override
  String get guideImportMethodsTitle => '課表導入方式';

  @override
  String get guideImportMethodsSubtitle =>
      '目前版本已经支持部分学校的教務系統網頁登入導入；如果你的学校還没適配，也還有其他遷移方式。';

  @override
  String get guideImportMethodStep1 =>
      '優先進入“導入課程 > 教務系統導入”，选擇学校和適配器後，直接在應用內打開教務網頁完成導入。';

  @override
  String get guideImportMethodStep2 =>
      '如果你的学校暫時没有適配，可以先在 WakeUp 等課表應用裡導入教務系統課程，再導出日歷格式，最後回到本應用導入。';

  @override
  String get guideImportMethodStep3 =>
      '如果别人已经在用本應用，也可以让对方導出完整備份文件，你直接導入就能恢複課程和設定。';

  @override
  String get guideImportMethodExtra =>
      '如果你会抓包、網頁偵錯或 JavaScript，也欢迎參與学校教務適配补充，让更多学校能直接導入。';

  @override
  String get guideFinalTipsTitle => '最後再看這 3 条';

  @override
  String get guideFinalTip1 =>
      '1. HyperOS 3.0.300 及以上才支持超級島；如果系統版本不够，應用仍可正常發普通提醒。';

  @override
  String get guideFinalTip2 => '2. 先在設定頁調整“上課前弹出”和“課中 / 臨近下課提醒”的阈值。';

  @override
  String get guideFinalTip3 => '3. 完成系統權限設定後，再用測試通知驗證；如果島区還是偶尔消失，優先檢查自啟動和省電策略。';

  @override
  String get guidePrivacyHelperRequireConsent =>
      '你勾选同意後，代表你已阅讀並同意上述友盟相關說明、隱私內容與免责提示。';

  @override
  String get guidePrivacyHelperViewOnly =>
      '這裡保留與首次啟動一致的隱私、第三方 SDK 與免责說明，方便你隨時查看；目前頁面不需要再次勾选同意。';

  @override
  String get guidePrivacySectionTitle => '隱私、第三方 SDK 與免责說明';

  @override
  String get guidePrivacyParagraph1 =>
      '本應用主體功能按本地运行方式設計，課表、時間模板、課程記錄和大部分設定預設保存在你的裝置本地。';

  @override
  String get guidePrivacyParagraph2 =>
      '只有在你主動使用檢查更新、下載更新、導入導出等联網功能，或你勾选同意後初始化友盟相關 SDK 時，應用才会與外部服務發生資料交互。';

  @override
  String get guidePrivacyParagraph3 =>
      '本應用接入友盟移動統計 SDK、友盟應用性能监控 SDK 以及高級运营分析依赖庫。它們的服務用途包括移動統計分析、應用性能监控以及高級运营分析相關能力；只有在你勾选同意後，這些 SDK 才会正式初始化。';

  @override
  String get guidePrivacyParagraph4 =>
      '按友盟官方說明，這些 SDK 可能處理的資訊包括：裝置資訊（如 IMEI、MAC、Android ID、OAID、IDFA、OpenUDID、GUID、SIM 卡 IMSI 等）、網路狀態、裝置標識，以及高級运营分析依赖庫涉及的應用列表和地理位置相關資訊。';

  @override
  String get guideRiskTitle => '免责與风险提示';

  @override
  String get guideRiskParagraph1 =>
      '1. 超級島、焦點通知、後台提醒和保活效果依赖系統版本、机型、厂商策略、權限、自啟動、電池策略等外部条件，無法保证所有裝置表现完全一致。';

  @override
  String get guideRiskParagraph2 =>
      '2. 檢查更新、鏡像下載、系統下載器、導入導出與分享等能力依赖網路环境、第三方服務和系統文件能力；若出现失败、限速或文件異常，请以 Release 頁面、你自己保存的備份文件和系統提示為准。';

  @override
  String get guideRiskParagraph3 =>
      '3. 在遷移、導入或覆盖資料前，请先自行確認備份文件完整可用，並妥善保管含有課表資訊的文件；因用户自行刪除、覆盖、分享或保管不當造成的資料問題，需要由用户自行承担相應风险。';

  @override
  String get guideUmengPrivacyLink =>
      '友盟隱私政策：https://www.umeng.com/page/policy';

  @override
  String get liveDiagnosticsUnavailable => '目前還没有可查看的超級島診斷日誌';

  @override
  String get liveDiagnosticsViewerTitle => '超級島診斷日誌';

  @override
  String get liveDiagnosticsShareText => '這是輕嶼課表導出的超級島診斷日誌，可用于排查“超級島没有弹出”等問題。';

  @override
  String get liveDiagnosticsShareSubject => '輕嶼課表 - 超級島診斷日誌';

  @override
  String get liveDiagnosticsSnapshotShareText =>
      '這是輕嶼課表目前測試診斷頁導出的超級島狀態快照，可用于排查“超級島没有弹出”等問題。';

  @override
  String get liveDiagnosticsSnapshotShareSubject => '輕嶼課表 - 超級島狀態快照';

  @override
  String get liveDiagnosticsNothingToExport => '目前没有可導出的日誌文件，也没有可導出的狀態快照';

  @override
  String get liveDiagnosticsCleared => '已清空超級島診斷日誌，後续会重新開始收集';

  @override
  String get liveDiagnosticsClearFailed => '清空超級島診斷日誌失败';

  @override
  String get liveTestingNotRefreshed => '尚未刷新';

  @override
  String get liveTestingTitle => '測試與診斷';

  @override
  String get liveTestingNotificationTitle => '測試通知';

  @override
  String get liveTestingNotificationSubtitle => '用于驗證超級島、通知栏和課程簡稱等顯示效果。';

  @override
  String get liveTestingSendAction => '發送測試通知';

  @override
  String get liveTestingUmengHint => '下面兩個按鈕僅測試版顯示，用于驗證友盟 U-APM 崩溃和卡顿上報。';

  @override
  String get liveTestingCrashAction => '崩溃測試';

  @override
  String get liveTestingAnrAction => '異常卡顿測試';

  @override
  String get liveTestingIslandStatusTitle => '上島狀態診斷';

  @override
  String get liveTestingIslandStatusSubtitle => '這裡直接顯示原生实時服務、通知构造结果和不上島原因。';

  @override
  String get liveTestingServiceStatusRunning => '服務运行中';

  @override
  String get liveTestingServiceStatusStopped => '服務未运行';

  @override
  String get liveTestingNoIslandReasonTitle => '不上島原因';

  @override
  String get liveTestingNoIslandReasonEmpty => '目前無拦截原因';

  @override
  String get liveTestingRefreshAction => '刷新診斷';

  @override
  String get liveTestingRefreshing => '刷新中';

  @override
  String get liveTestingExportAction => '導出並分享日誌';

  @override
  String get liveTestingExporting => '導出中';

  @override
  String get liveTestingAutoRefreshTitle => '自動刷新';

  @override
  String liveTestingAutoRefreshOn(int seconds) {
    return '每 $seconds 秒自動拉取一次診斷狀態';
  }

  @override
  String get liveTestingAutoRefreshOff => '關閉後只在手動刷新時更新，便于穩定查看目前狀態';

  @override
  String liveTestingRefreshedAt(String time) {
    return '上次刷新：$time';
  }

  @override
  String get liveTestingSectionEnvironment => '环境與權限';

  @override
  String get liveTestingSectionService => '服務狀態';

  @override
  String get liveTestingSectionCourse => '課程資料';

  @override
  String get liveTestingSectionTiming => '時間與階段';

  @override
  String get liveTestingSectionSwitches => '階段開關';

  @override
  String get liveTestingSectionDisplay => '島顯示配置';

  @override
  String get liveTestingSectionNotification => '通知判定结果';

  @override
  String get liveTestingSectionRecentLogs => '最近診斷日誌';

  @override
  String get liveTestingRawDataTitle => '原始偵錯資料';

  @override
  String get liveTestingRawDataSubtitle => '預設折叠，排查時再展開核对完整原生字段。';

  @override
  String get liveTestingExpandRawJson => '展開原始 JSON';

  @override
  String get liveTestingExpandRawJsonSubtitle => '避免大段原始字段一直占满頁面';

  @override
  String get liveTestingLocalLogsTitle => '本地診斷日誌';

  @override
  String get liveTestingLocalLogsSubtitle =>
      '一键導出日誌文件，直接通過系統分享發给開發者；也可以清空後重新收集。';

  @override
  String get liveTestingClearLogsAction => '清空日誌';

  @override
  String get liveTestingClearingLogs => '清空中';

  @override
  String get liveTestingViewPhoneLogsAction => '查看手机日誌';

  @override
  String get liveTestingMoreTesterOptionsAction => '更多測試者选項';

  @override
  String get yesLabel => '是';

  @override
  String get noLabel => '否';

  @override
  String get liveTestingCurrentNativeFieldsSubtitle => '顯示目前原生診斷字段。';

  @override
  String get liveTestingCrashSoon => '即将触發友盟 U-APM 測試崩溃，请重新打開應用查看後台是否收到上報';

  @override
  String get liveTestingAnrSoon =>
      '即将触發约 30 秒主線程卡死，请脱离 flutter run 測試，並在卡死後重新打開應用查看友盟後台';

  @override
  String get liveTestingNoCourseAvailable => '目前没有可測試的課程';

  @override
  String get liveTestingTestCourseNote => '此處顯示備注。可以在課程编辑頁進行設定。';

  @override
  String get liveTestingNotificationSent => '已發送上課提醒測試通知，约 8 秒內会進入上課前提醒階段';

  @override
  String sendFailedWithError(String error) {
    return '發送失败: $error';
  }

  @override
  String get homeWidgetSettingsTitle => '桌面小工具';

  @override
  String get homeWidgetTodayCourseTitle => '今日課程工具';

  @override
  String get homeWidgetTodayCourseSubtitle =>
      '首批支持 2×2、2×4、4×4 三种尺寸。點擊小工具会直接打開首頁，課程開始和结束時会主動刷新。';

  @override
  String get homeWidgetQuickAddTitle => '快速添加到桌面';

  @override
  String get homeWidgetCheckingPinSupport => '正在檢查目前桌面是否支持應用內添加小工具…';

  @override
  String get homeWidgetPinSupported => '支持的话会直接弹出系統添加確認，不是單独的權限弹窗；確認後即可固定到桌面。';

  @override
  String get homeWidgetPinUnsupported =>
      '目前桌面不支持應用內直接添加時，仍可长按桌面 → 小工具 → 輕嶼課表 手動添加。';

  @override
  String get homeWidgetBackgroundStyleLabel => '背景样式';

  @override
  String get homeWidgetShowLocationTitle => '顯示地點';

  @override
  String get homeWidgetShowLocationSubtitle => '關閉後，小工具次級資訊会優先顯示周次和課程數量。';

  @override
  String get homeWidgetShowCountdownTitle => '顯示倒計時';

  @override
  String get homeWidgetShowCountdownSubtitle => '先保留刷新開關，後续会用于下一節課和上課中的剩余時間展示。';

  @override
  String get homeWidgetCountdownLeadTitle => '倒計時提前量';

  @override
  String get homeWidgetCountdownLeadSubtitle => '設置上課前多少分鐘自動切換到倒計時模式。';

  @override
  String get homeWidgetCountdownLeadAlways => '始終顯示';

  @override
  String homeWidgetCountdownLeadMinutes(String minutes) {
    return '上課前 $minutes 分鐘';
  }

  @override
  String get widgetCountdownStyleTitle => '倒計時樣式';

  @override
  String get homeWidgetHideCompletedTitle => '隱藏已上完課程';

  @override
  String get homeWidgetHideCompletedSubtitle =>
      '開啟後，2×2、2×4 和 4×4 課程列表只顯示還没结束的課程。';

  @override
  String get homeWidgetShowTomorrowTitle => '下課後顯示明天課程';

  @override
  String get homeWidgetShowTomorrowSubtitle =>
      '啟用後，當今天的課程全部結束時，桌面小工具會自動切換顯示明天的課程。';

  @override
  String get homeWidgetHeightAdjustTitle => '卡片高度微調';

  @override
  String get defaultLabel => '預設';

  @override
  String higherByValue(String value) {
    return '更高 $value';
  }

  @override
  String lowerByValue(String value) {
    return '更矮 $value';
  }

  @override
  String get homeWidgetCornerRadiusTitle => '卡片圆角';

  @override
  String get homeWidgetDescriptionTitle => '說明';

  @override
  String get homeWidgetDescriptionText =>
      '小工具目前優先展示今日課程。無課狀態会保持完整卡片，不会出现空白；如果你切换課表或修改样式，桌面工具也会跟着刷新。';

  @override
  String homeWidgetPinRequested(String label) {
    return '已發起“$label”添加请求，请在系統弹窗裡確認並放到桌面。';
  }

  @override
  String homeWidgetPinUnsupportedManual(String label) {
    return '目前系統桌面不支持應用內直接添加小工具，请长按桌面 → 小工具 → 輕嶼課表，再手動添加“$label”。';
  }

  @override
  String get homeWidgetInvalidType => '小工具類型無效，请稍後重試。';

  @override
  String homeWidgetPinFailedManual(String label) {
    return '發起添加失败，请长按桌面 → 小工具 → 輕嶼課表，再手動添加“$label”。';
  }

  @override
  String get layoutSettingsTitle => '布局與節次';

  @override
  String get layoutDensityTitle => '課表密度';

  @override
  String get layoutAutoFitHeightTitle => '自動充满屏幕高度';

  @override
  String get layoutAutoFitHeightSubtitle => '開啟後会按目前節數自動铺满頁面底部，不再保留下方空隙。';

  @override
  String get layoutHideWeekendsTitle => '隱藏周六周日';

  @override
  String get layoutHideWeekendsSubtitle => '開啟後首頁只顯示周一到周五，剩余列宽会自動铺满。';

  @override
  String get layoutEnableHapticsTitle => '啟用應用內震動反饋';

  @override
  String get layoutEnableHapticsSubtitle => '關閉後，頁码切换等交互不再触發輕微震動。';

  @override
  String get layoutTimeColumnDisplayLabel => '首頁時間列顯示';

  @override
  String get layoutTimeColumnWidthLabel => '時間栏宽度';

  @override
  String get layoutBackToCurrentWeekButtonStyleLabel => '「返回本週」按鈕樣式';

  @override
  String get layoutBackToCurrentWeekButtonStyleHelper =>
      '預設維持現在的內嵌樣式；也可以改成周視圖右下角的小型懸浮按鈕。';

  @override
  String get layoutBackToCurrentWeekButtonStyleInline => '時間欄內嵌';

  @override
  String get layoutBackToCurrentWeekButtonStyleFloating => '右下角懸浮';

  @override
  String layoutBackToCurrentWeekButtonOpacityLabel(int value) {
    return '懸浮按鈕不透明度 $value%';
  }

  @override
  String get layoutBackToCurrentWeekButtonOpacitySubtitle => '只對右下角懸浮樣式生效。';

  @override
  String layoutCourseCardGapLabel(String value) {
    return '課程卡片間距 $value';
  }

  @override
  String layoutSectionHeightLabel(String value) {
    return '課表行高 $value';
  }

  @override
  String layoutCompactFontSizeLabel(String value) {
    return '紧凑字級 $value';
  }

  @override
  String layoutCourseCardFontSizeLabel(String value) {
    return '課程卡片字級 $value';
  }

  @override
  String get layoutCourseCardDisplayTitle => '課程卡片顯示';

  @override
  String get layoutCourseCardDisplaySubtitle => '預設顯示課程名、老師和教室；其他資訊可按課表自由開關組合。';

  @override
  String get layoutShowTeacherTitle => '顯示老師';

  @override
  String get layoutShowClassroomTitle => '顯示教室';

  @override
  String get layoutShowTimeTitle => '顯示時間';

  @override
  String get layoutShowTimeLabelsTitle => '顯示上課/下課字样';

  @override
  String get layoutShowTimeLabelsSubtitle => '關閉後僅顯示時間點，不顯示“上課”“下課”文字。';

  @override
  String get layoutShowWeeksTitle => '顯示週數';

  @override
  String get layoutShowWeeksSubtitle => '例如第 1-16 周、單双周';

  @override
  String get layoutShowDescriptionTitle => '顯示課程簡介';

  @override
  String get layoutShowDescriptionSubtitle => '預設關閉，空間不足時会最先被壓缩';

  @override
  String get layoutShowOtherWeeksTitle => '顯示非本周課程';

  @override
  String get layoutShowOtherWeeksSubtitle => '預設關閉，開啟後会用灰色半透明顯示不在目前周的課程';

  @override
  String get layoutVerticalAlignLabel => '垂直排版';

  @override
  String get layoutHorizontalAlignLabel => '水平排版';

  @override
  String get layoutShowConflictBadgeTitle => '首頁顯示冲突小胶囊';

  @override
  String get layoutShowConflictBadgeSubtitle => '關閉後，首頁課表不再对冲突課程顯示“冲突”小胶囊。';

  @override
  String layoutConflictOpacityLabel(int value) {
    return '冲突課程透明度 $value%';
  }

  @override
  String get layoutConflictOpacitySubtitle => '冲突課程会自動层叠顯示，調低透明度後能同時看到多節課。';

  @override
  String get layoutTipsText =>
      '時間模板已移到設定首頁。這裡主要調課表行高、時間列、周末顯示和課程卡片布局；如果你想只改目前課表的時間，先在時間模板裡複制一套再應用。';

  @override
  String currentWeekCompact(int week) {
    return '$week周';
  }

  @override
  String get sampleCourseNumericalControl => '數控';

  @override
  String get sampleCourseAdvancedMath => '高數';

  @override
  String get sampleTeacherZhang => '张老師';

  @override
  String get sampleCourseEnglish => '英語';

  @override
  String get sampleTeacherLi => '李老師';

  @override
  String get aboutRepositorySheetTitle => '開源倉庫';

  @override
  String get aboutRepositorySheetHint =>
      '如果你想补学校教務匯入適配，建議同時查看教務適配倉 qingyu_warehouse。';

  @override
  String get aboutOpenGitHubAction => '打開 GitHub';

  @override
  String get aboutOpenWarehouseRepoAction => '打開教務適配倉';

  @override
  String get copiedRepositoryAddress => '已複制倉庫地址';

  @override
  String get copiedWarehouseRepositoryAddress => '已複制教務適配倉地址';

  @override
  String get aboutUpdateScreenTitle => '版本更新';

  @override
  String get aboutUpdateStatusTitle => '更新狀態';

  @override
  String get aboutRefreshCheckTooltip => '重新檢查';

  @override
  String get aboutCheckingLatestVersion => '正在檢查最新版本資訊…';

  @override
  String get aboutReadVersionFailed => '暫時無法讀取版本資訊，请稍後重試。';

  @override
  String get aboutReadVersionFailedHint =>
      '如果你目前網路访問 GitHub 不穩定，可稍後再試，或切到下面的國內下載方式後重試。';

  @override
  String get aboutViewReleaseAction => '查看 Release';

  @override
  String get aboutDownloadNowAction => '立即下載';

  @override
  String get aboutOpenDownloadPageAction => '打開下載頁';

  @override
  String get aboutCurrentVersionLabel => '目前版本';

  @override
  String get aboutLatestVersionLabel => '最新版本';

  @override
  String get aboutUnreleasedLabel => '未發布';

  @override
  String get aboutVersionChannelLabel => '版本通道';

  @override
  String get aboutPrereleaseChannel => '測試版';

  @override
  String get aboutUpdateAvailableHint =>
      '你现在只需要點下面的“立即下載”即可。測速、鏡像和測試版都已经收進後面的高級选項裡。';

  @override
  String get aboutUpdateNoUpdateHint =>
      '目前版本已经可正常使用；如果你要體验測試版，可以在後面的高級选項裡打開測試版檢測。';

  @override
  String aboutUpdatedAt(String time) {
    return '更新時間：$time';
  }

  @override
  String get aboutUpdateNowTitle => '立即更新';

  @override
  String get aboutUpdateNowAndroidSubtitle =>
      '普通使用只需要點一次立即下載。下載慢、下載失败、要换線路時，再去下面的高級选項。';

  @override
  String get aboutUpdateNowOtherSubtitle => '目前平台会直接打開下載頁面，不会在應用內安装。';

  @override
  String get aboutMirrorDownloadHint => '目前会優先使用國內下載。大多數國內網路直接點“立即下載”就行。';

  @override
  String get aboutOriginalDownloadHint => '目前会優先使用國際源下載。如果下載慢或打不開，建議先切回“國內下載”。';

  @override
  String get aboutUseSystemDownloaderAction => '使用系統下載器下載';

  @override
  String get aboutOpenReleasePageAction => '打開 Release 頁面';

  @override
  String get aboutDownloadMethodTitle => '下載方式';

  @override
  String get aboutDownloadMethodSubtitle =>
      '預設推荐國內下載。只有你能穩定访問 GitHub 時，再切到國際源下載。';

  @override
  String get aboutDownloadMethodMirror => '國內下載';

  @override
  String get aboutDownloadMethodOriginal => '國際源下載';

  @override
  String aboutMirrorModeHintRecommended(String current, String recommended) {
    return '目前使用國內下載 · $current。系統最近測速更推荐“$recommended”，需要時可在後面的高級选項裡切换。';
  }

  @override
  String aboutMirrorModeHintCurrent(String current) {
    return '目前使用國內下載 · $current。如果下載慢或失败，再到後面的高級选項裡測速、换線路或填寫自定义地址。';
  }

  @override
  String get aboutOriginalModeHint =>
      '目前使用國際源下載。只有你網路能穩定访問 GitHub 時才建議這样設定；否則请切回國內下載。';

  @override
  String get aboutReleaseNotesTitle => '本次更新說明';

  @override
  String get aboutReleaseNotesSubtitle => '顯示目前檢測到版本的 Release 說明。';

  @override
  String get aboutAdvancedOptionsTitle => '高級选項';

  @override
  String get aboutAdvancedOptionsSubtitle => '只有下載慢、要手動切線路、或要檢測測試版時再展開。';

  @override
  String get aboutMirrorSectionTitle => '下載線路與鏡像';

  @override
  String get aboutMirrorSectionMirrorHint =>
      '目前使用國內下載。這裡可以手動切線路、測速推荐，或填寫自定义下載地址。';

  @override
  String get aboutMirrorSectionOriginalHint =>
      '你现在使用的是國際源下載。下面的線路設定只有在切回“國內下載”後才会生效。';

  @override
  String get aboutFillCustomMirrorFirst => '先填寫自定义下載地址';

  @override
  String get aboutCurrentCustomMirrorTitle => '目前自定义下載地址';

  @override
  String get aboutCurrentMirrorTitle => '目前下載線路地址';

  @override
  String get aboutCurrentCustomMirrorHint => '目前正在使用你手動填寫的下載地址。';

  @override
  String get aboutCurrentMirrorHint => '如果目前線路访問失败，可以切到其他內置線路，或改用自定义地址。';

  @override
  String get aboutProbeMirrorsAction => '測速並推荐';

  @override
  String get aboutProbingMirrors => '測速中…';

  @override
  String get aboutEditCustomMirrorAction => '修改自定义地址';

  @override
  String get aboutSetCustomMirrorAction => '填寫自定义地址';

  @override
  String aboutSwitchToRecommendedAction(String label) {
    return '切到推荐：$label';
  }

  @override
  String get aboutMirrorDisabledHint =>
      '目前没有使用國內下載，所以這裡的線路設定暫時不会生效。需要的话，请先在上面的“下載方式”裡切回國內下載。';

  @override
  String get aboutRecentProbeResultsTitle => '最近測速结果';

  @override
  String get aboutUnavailable => '不可用';

  @override
  String get aboutRecommended => '推荐';

  @override
  String get aboutCheckPrereleaseTitle => '檢測測試版本';

  @override
  String get aboutCheckPrereleaseSubtitle => '打開後会把測試版也纳入更新檢查；普通使用建議關閉。';

  @override
  String get aboutDiagnosticsTitle => '測試與診斷';

  @override
  String get aboutDiagnosticsSubtitle => '只有遇到“超級島没弹出”或需要给開發者反饋時再展開。';

  @override
  String get aboutRecordDiagnosticsTitle => '記錄應用日誌';

  @override
  String get aboutRecordDiagnosticsSubtitle =>
      '打開後会在本地持续記錄關键日誌，僅用于排查“该弹不弹”等問題。';

  @override
  String get aboutExportDiagnosticsAction => '匯出診斷日誌';

  @override
  String get aboutViewPhoneLogsAction => '查看手机日誌';

  @override
  String get aboutClearAndRecollectAction => '清空並重新收集';

  @override
  String get aboutLiveDiagnosticsEnabled => '已開啟超級島診斷日誌';

  @override
  String get aboutLiveDiagnosticsDisabled => '已關閉超級島診斷日誌';

  @override
  String get aboutNoDiagnosticsExportYet => '還没有可匯出的超級島診斷日誌';

  @override
  String get aboutProbeNoMirrorFound => '測速完成，但暫時没有發现可用鏡像線路';

  @override
  String aboutProbeCurrentFastest(String label) {
    return '測速完成，目前線路“$label”已是最快可用線路';
  }

  @override
  String aboutProbeRecommendSwitch(String label) {
    return '測速完成，推荐切换到“$label”';
  }

  @override
  String get switchAction => '切换';

  @override
  String aboutSwitchToMirrorAfterError(String error) {
    return '$error，可切到國內鏡像後再試';
  }

  @override
  String aboutSwitchPresetAfterError(String error, String label) {
    return '$error，建議切换到“$label”後重試';
  }

  @override
  String get aboutSetMirrorSourceTitle => '設定鏡像源';

  @override
  String get aboutMirrorPrefixLabel => '鏡像前缀';

  @override
  String get aboutMirrorPrefixInvalid => '鏡像源格式不正確，请輸入完整的 http 或 https 地址';

  @override
  String get aboutMirrorSaved => '鏡像源已保存';

  @override
  String get aboutDownloadCancelled => '已取消下載';

  @override
  String get aboutInstallReady => '安装包已准備好，已尝試打開安装界面；如果系統没有弹出，请稍後从通知或文件管理器手動安装';

  @override
  String get aboutUpdatePackageTitle => '輕嶼課表更新包';

  @override
  String get aboutUpdatePackageDescription => '已交给系統下載管理器下載，完成後可直接从系統通知安装。';

  @override
  String get aboutSystemDownloaderQueued => '已交给系統下載管理器，请在系統通知或下載列表裡查看進度';

  @override
  String get aboutSystemDownloaderFailed => '調用系統下載管理器失败';

  @override
  String get aboutDownloadCancelling => '正在取消下載…';

  @override
  String aboutDownloadingBytes(String value) {
    return '正在下載更新 $value';
  }

  @override
  String aboutDownloadingPercent(String value) {
    return '正在下載更新 $value%';
  }

  @override
  String get aboutMirrorUnknownSizeHint => '鏡像源未返回文件总大小，先顯示已下載體积';

  @override
  String get aboutCancelDownloadAction => '取消下載';

  @override
  String get aboutContributorsScreenTitle => '代码贡献者';

  @override
  String get aboutDevelopersTitle => '開發人员';

  @override
  String get aboutDeveloperMaintainerSubtitle => '輕嶼課表開發與維護';

  @override
  String get aboutWarehouseMaintainersTitle => '教務匯入適配者';

  @override
  String get aboutWarehouseMaintainersIntro =>
      '以下名單来自 qingyu_warehouse 適配倉的 maintainer 字段汇总。若本地已有缓存，会先顯示缓存，再後台刷新。';

  @override
  String aboutWarehouseMaintainersLoadFailed(String error) {
    return '暫時無法讀取適配者名單：$error';
  }

  @override
  String get aboutWarehouseMaintainersEmpty => '目前還没有讀取到適配者資訊。';

  @override
  String aboutWarehouseMaintainerCount(int count) {
    return '$count 個適配項';
  }

  @override
  String get aboutParticipateWarehouseTitle => '參與教務適配';

  @override
  String get aboutParticipateWarehouseSubtitle =>
      '如果你会抓包、網頁偵錯、JavaScript，或者愿意长期維護自己学校的教務系統，欢迎去 qingyu_warehouse 提交新的学校適配與修複。';

  @override
  String get importFileReadFailed => '無法讀取所选文件';

  @override
  String get importReplaceExistingTitle => '匯入課程';

  @override
  String importReplaceExistingMessage(String name) {
    return '匯入 $name 時，是否替换现有課程？';
  }

  @override
  String get importNoCoursesRecognized => '未識别到可匯入課程';

  @override
  String get importConfirmSemesterMappingTitle => '確認開学日期和周次对應';

  @override
  String get importConfirmSemesterMappingSubtitleIcs =>
      '请选擇学校校歷的開学日期。系統已根据文件裡最早的上課日期给出預設周次对應，你也可以手動調整。';

  @override
  String importOverwriteCount(int count) {
    return '已覆盖匯入 $count 条課程';
  }

  @override
  String importUpdatedCount(int count) {
    return '已更新課表：新增或更新 $count 条課程';
  }

  @override
  String get importNoCourseChanges => '没有需要新增或更新的課程';

  @override
  String get aiImportTitle => '識圖匯入';

  @override
  String aiPreviewSummary(
    int courseCount,
    int sectionCount,
    String warningSuffix,
  ) {
    return '識别到 $courseCount 門課，最高到第 $sectionCount 節$warningSuffix';
  }

  @override
  String aiWarningCountSuffix(int count) {
    return '，$count 条提醒';
  }

  @override
  String get aiWorkflowCompactTitle => '複制提示词 -> 豆包識圖 -> 匯入';

  @override
  String get aiWorkflowCompactSubtitle => '豆包專家模式 -> 複制 JSON -> 选擇開学日期';

  @override
  String get aiWorkflowTitle => '複制提示词 -> 豆包識圖 -> 粘贴 JSON -> 匯入';

  @override
  String get aiWorkflowSubtitle =>
      '先複制提示词，再到豆包左下角切换為專家模式，把課表截圖和提示词一起發過去。把豆包返回的 JSON 複制回這裡，點擊匯入後再选擇開学日期。';

  @override
  String get aiPromptShortAction => '提示词';

  @override
  String get aiExpertModeSuggestion => '建議豆包專家模式，支持多圖，截圖需带星期表头。';

  @override
  String get aiHintExpertMode => '先切到豆包專家模式';

  @override
  String get aiHintSendScreenshot => '截圖和提示词一起發';

  @override
  String get aiHintCopyJsonBack => '返回结果複制 JSON';

  @override
  String get aiHintPickSemesterAfterImport => '匯入後再选開学日期';

  @override
  String get jsonLabelShort => 'JSON';

  @override
  String get aiPasteJsonTitle => '粘贴 AI 返回的 JSON';

  @override
  String aiCourseCountChip(int count) {
    return '$count 門課';
  }

  @override
  String get aiParseFailedChip => '解析失败';

  @override
  String get aiPasteJsonHintShort => '粘贴 AI 返回的 JSON';

  @override
  String get aiPasteJsonHintLong =>
      '把豆包返回的 JSON 原样粘贴到這裡，然後點擊匯入。支持纯 JSON，也兼容 ```json 代码块。';

  @override
  String get detailAction => '详情';

  @override
  String get aiParseErrorTitle => '解析错误';

  @override
  String get viewDetailsAction => '查看详情';

  @override
  String get aiWorkflowFooter =>
      '複制提示词 -> 豆包發送截圖和提示词 -> 把 JSON 贴回這裡 -> 點擊匯入 -> 选擇開学日期。';

  @override
  String get previewAction => '預覽';

  @override
  String get confirmImportAction => '確認匯入';

  @override
  String get promptCopiedHint => '提示词已複制，去豆包發送截圖和提示词';

  @override
  String get clipboardNoText => '剪贴板裡没有可用文本';

  @override
  String get aiPromptSheetTitle => '識圖提示词';

  @override
  String get aiPromptSheetSubtitle =>
      '建議使用豆包。先把豆包左下角切换為專家模式，再把下面整段提示词和課表截圖一起發過去，让它只返回 JSON。生成後把 JSON 複制回本頁，點擊匯入後再选擇開学日期。';

  @override
  String get aiPreviewTitle => '解析預覽';

  @override
  String get aiPasteJsonFirst => '请先粘贴 AI 返回的 JSON';

  @override
  String get aiParseFailedIncompleteJson => '解析失败，请確認粘贴的是完整 JSON';

  @override
  String get importAiResultTitle => '匯入 AI 解析结果';

  @override
  String get importAiReplaceMessage => '是否用目前這份 AI 解析结果替换现有課程？';

  @override
  String get importConfirmSemesterMappingSubtitleAi =>
      '请选擇学校校歷的開学日期，再確認課表裡的第 1 周对應校歷第几周。如果学校第一周没課，這裡通常要改成第 2 周。';

  @override
  String aiWarningExtraSuffix(int count) {
    return '，另有 $count 条識别提醒';
  }

  @override
  String get pasteAction => '粘贴';

  @override
  String get importConfirmSemesterMappingSubtitleWarehouse =>
      '教務脚本已返回課程周次，请確認校歷開学日期；如果学校前几周没有課，可把“課表第 1 周”对應到校歷後面的周次。';

  @override
  String aiPreviewCourseCount(int count) {
    return '課程數量：$count';
  }

  @override
  String aiPreviewMaxSection(int section) {
    return '最大節次：第 $section 節';
  }

  @override
  String get aiPreviewWarningsTitle => '識别提醒';

  @override
  String get aiPreviewCoursesTitle => '課程預覽';

  @override
  String aiPreviewRemainingCourses(int count) {
    return '其余 $count 条将在匯入後寫入目前課表';
  }

  @override
  String get warehouseMissingSchoolTitle => '学校列表裡没有你的学校？';

  @override
  String get warehouseMissingSchoolSubtitle =>
      '去反饋頁提一個 Issue 就行。建議一起寫上学校名稱、教務系統網址、登入後課表頁連結或截圖，這样更方便补適配。';

  @override
  String get laterAction => '稍後再說';

  @override
  String get goFeedbackAction => '去反饋頁';

  @override
  String get warehouseFeedbackMissingSchoolTitle => '缺少学校？去反饋';

  @override
  String get warehouseCustomDebugTitle => '自訂偵錯';

  @override
  String get warehouseRootLoadFailedTitle => '暫時無法讀取適配倉';

  @override
  String get searchSchoolHint => '搜索学校名稱、首字母或代码';

  @override
  String get clearSearchTooltip => '清空';

  @override
  String get noMatchingSchools => '没有找到匹配的学校';

  @override
  String get noAvailableSchools => '暫無可用学校';

  @override
  String get searchSchoolSuggestion => '試試学校全稱、首字母或倉庫裡的学校代码。';

  @override
  String get deleteDebugRecordTitle => '刪除偵錯記錄';

  @override
  String deleteDebugRecordMessage(String name) {
    return '確認刪除“$name”？刪除後不会影响已经匯入的課程。';
  }

  @override
  String deletedDebugRecord(String name) {
    return '已刪除偵錯記錄：$name';
  }

  @override
  String get customDebugName => '自定义偵錯';

  @override
  String get localDebugMaintainer => '本地偵錯';

  @override
  String get customDebugDescription => '用户保存的自定义教務偵錯脚本';

  @override
  String get addDebugRecordTooltip => '新增偵錯記錄';

  @override
  String get customDebugIntroTitle => '這裡放你自己的教務偵錯記錄';

  @override
  String get customDebugIntroSubtitle =>
      '每条記錄都可以保存自定义網址和整段脚本。保存後下次直接點“開始偵錯”就能複用，不需要再去某個学校详情頁裡找入口。';

  @override
  String get addDebugRecordAction => '新增偵錯記錄';

  @override
  String get noSavedDebugRecords => '還没有保存的偵錯記錄';

  @override
  String get noSavedDebugRecordsHint => '先新增一条，把網址和脚本贴進去，以後就能直接複用。';

  @override
  String debugScriptLength(int count) {
    return '脚本 $count 字符';
  }

  @override
  String get startDebugAction => '開始偵錯';

  @override
  String get editAction => '编辑';

  @override
  String get scriptFileReadFailed => '無法讀取脚本文件';

  @override
  String scriptFileImported(String name) {
    return '已匯入脚本文件：$name';
  }

  @override
  String scriptFileImportFailed(String error) {
    return '匯入脚本文件失败：$error';
  }

  @override
  String get debugRecordNameRequired => '请先填寫偵錯記錄名稱';

  @override
  String get invalidImportUrl => '请輸入有效的教務網址';

  @override
  String get debugScriptRequired => '请先填寫或匯入脚本';

  @override
  String get editDebugRecordTitle => '编辑偵錯記錄';

  @override
  String get addDebugRecordTitle => '新增偵錯記錄';

  @override
  String get savingAction => '保存中…';

  @override
  String get debugRecordFormula => '一条記錄 = 一個網址 + 一段脚本';

  @override
  String get debugRecordFormulaSubtitle =>
      '適合你反複偵錯同一個学校，或者不同学校保留多套脚本。保存後会一直保留，後面可隨時修改。';

  @override
  String get debugRecordNameLabel => '記錄名稱';

  @override
  String get debugRecordNameHint => '例如：重庆机電-新版教務';

  @override
  String get importUrlLabel => '教務網址';

  @override
  String get debugScriptLabel => '偵錯脚本';

  @override
  String get importFromFileAction => '从文件匯入';

  @override
  String get debugScriptHint => '把浏覽器擴展匯出的完整脚本粘贴到這裡';

  @override
  String get saveDebugRecordAction => '保存偵錯記錄';

  @override
  String get fillUrlThenImport => '填寫網址後匯入';

  @override
  String get webLoginImport => '網頁登入匯入';

  @override
  String get savedImportUrlHint => '已保存教務網址，下次可直接匯入';

  @override
  String get adapterIntroSubtitle => '可查看適配器資訊、登入入口與脚本狀態。';

  @override
  String get schoolLabel => '学校';

  @override
  String get categoryLabel => '類别';

  @override
  String get maintainerLabel => '維護者';

  @override
  String get adapterInfoTitle => '適配器資訊';

  @override
  String get scriptPathLabel => '脚本路徑';

  @override
  String get loginEntryLabel => '登入入口';

  @override
  String get unsetConfigLabel => '未配置';

  @override
  String get adapterOverrideImportUrlHint => '目前使用你手動覆盖的登入地址';

  @override
  String get repositoryLabel => '倉庫';

  @override
  String get scriptStatusTitle => '脚本狀態';

  @override
  String scriptLoadedLength(int count) {
    return '脚本已成功讀取，长度 $count 字符。';
  }

  @override
  String get scriptEmpty => '脚本為空';

  @override
  String get openLoginInAppAction => '應用內打開登入入口';

  @override
  String get openInSystemBrowserAction => '系統浏覽器打開';

  @override
  String get copiedImportLoginUrl => '已複制教務登入地址';

  @override
  String get copyLoginAddressAction => '複制登入地址';

  @override
  String get copiedScriptRawUrl => '已複制脚本原始地址';

  @override
  String get copyScriptAddressAction => '複制脚本地址';

  @override
  String get customLoginAddressAction => '自定义登入地址';

  @override
  String get editCustomLoginAddressAction => '修改自定义地址';

  @override
  String get clearCustomLoginAddressAction => '清除自定义地址';

  @override
  String get restoreRepositoryAddressAction => '恢複倉庫地址';

  @override
  String get invalidLoginEntryUrl => '登入入口地址無效';

  @override
  String get savedCustomLoginAddress => '已保存自定义登入地址';

  @override
  String get clearedCustomLoginAddress => '已清除自定义登入地址';

  @override
  String get restoredRepositoryImportUrl => '已恢複倉庫裡的登入地址';

  @override
  String get backToCurrentWeekAction => '返回本週';

  @override
  String get nonCurrentWeekLabel => '非本周';

  @override
  String get conflictLabel => '冲突';

  @override
  String get selectWeekTitle => '选擇周次';

  @override
  String availableWeeksCount(int count) {
    return '共 $count 周';
  }

  @override
  String goToWeekLabel(int week) {
    return '第 $week 周';
  }

  @override
  String get homeMenuUpdateTitle => '軟體更新';

  @override
  String get homeMenuProfilesTitle => '課表管理';

  @override
  String get homeMenuOverviewTitle => '課程總覽';

  @override
  String get homeMenuAddCourseTitle => '新增課程';

  @override
  String get homeMenuImportTitle => '匯入課程';

  @override
  String get homeMenuSettingsTitle => '課表設定';

  @override
  String get homeMenuCoffeeTitle => '請喝咖啡';

  @override
  String get homeMenuFeedbackTitle => '問題回饋';

  @override
  String get switchTimetableTitle => '切换課表';

  @override
  String get switchTimetableSubtitleEmpty => '點擊下面的課表，立即切换目前視圖。';

  @override
  String switchTimetableSubtitleCurrent(String name) {
    return '目前：$name，點擊下面的課表立即切换。';
  }

  @override
  String get todayTimetableTitle => '今日課表';

  @override
  String get dayTimetableTitle => '單日時間軸';

  @override
  String get backToWeekViewAction => '返回周視圖';

  @override
  String get backToTodayAction => '回到今天';

  @override
  String get ongoingCourseBadge => '正在上課';

  @override
  String get dayViewEmptyTitle => '暫無課程';

  @override
  String shortNamePrefix(String value) {
    return '簡稱：$value';
  }

  @override
  String teacherPrefix(String value) {
    return '老師：$value';
  }

  @override
  String locationPrefix(String value) {
    return '地點：$value';
  }

  @override
  String courseDialogCurrentWeekHint(int week) {
    return '目前查看第 $week 周，可直接对這一周這節課調課。';
  }

  @override
  String courseDialogNotThisWeekHint(int week) {
    return '目前查看第 $week 周，這門課這周没有上課，因此不能按“本周這節”調課。';
  }

  @override
  String get editActionShort => '编辑';

  @override
  String get rescheduleAction => '調課';

  @override
  String get deleteActionShort => '刪除';

  @override
  String get deleteModeTitle => '刪除方式';

  @override
  String get deleteModeSubtitle => '你可以刪掉整条排課，也可以只刪目前看到的這一周這一節。';

  @override
  String get deleteCourseAction => '刪這個課';

  @override
  String get deleteOccurrenceAction => '刪這節課';

  @override
  String deleteModeHintCurrentWeek(int week) {
    return '“刪這個課”会刪除這条排課的全部周次；“刪這節課”只会刪除第 $week 周這一次。';
  }

  @override
  String deleteModeHintUnavailable(int week) {
    return '目前卡片不是第 $week 周的实際排課，所以只能刪除整条排課。';
  }

  @override
  String deleteScheduleConfirmMessage(String name, String detail) {
    return '確定刪除“$name”這条排課嗎？\n$detail';
  }

  @override
  String deleteOccurrenceConfirmMessage(String name, int week, String detail) {
    return '確定刪除“$name”在第 $week 周的這一節嗎？\n$detail';
  }

  @override
  String occurrenceDeletedMessage(int week) {
    return '已刪除第 $week 周這節課';
  }

  @override
  String get noChangesDetected => '未檢測到变更';

  @override
  String get rescheduleCurrentOccurrenceTitle => '調本周這節課';

  @override
  String rescheduleCurrentOccurrenceSubtitle(int week) {
    return '只調整第 $week 周這一節，原課程在這一周会自動移除，其他周保持不变。';
  }

  @override
  String get rescheduleTargetWeekLabel => '調到第几周';

  @override
  String get weekdayFieldLabel => '星期';

  @override
  String get startSectionFieldLabel => '開始節次';

  @override
  String get endSectionFieldLabel => '结束節次';

  @override
  String get courseLocationFieldLabel => '上課地點';

  @override
  String get confirmRescheduleAction => '確認調課';

  @override
  String get homeTitleStyleClassicLabel => '經典文字';

  @override
  String get homeTitleStyleBrandLabel => '大 Logo';

  @override
  String get homeTitleStyleClassicDescription => '維持原本標題樣式，只顯示文字，點一下即可切換課表';

  @override
  String get homeTitleStyleBrandDescription => '顯示大 Logo 和較小的課表名稱，更強調品牌感';

  @override
  String get widgetBackgroundStyleGlass => '半透明玻璃感';

  @override
  String get widgetBackgroundStyleSolid => '純色卡片';

  @override
  String get widgetBackgroundStyleGradient => '漸層卡片';

  @override
  String get homeWidgetTargetCompact22 => '主卡 2×2';

  @override
  String get homeWidgetTargetMiniList22 => '迷你清單 2×2';

  @override
  String get homeWidgetTargetMedium24 => '總覽 2×4';

  @override
  String get homeWidgetTargetLarge44 => '清單 4×4';

  @override
  String get addCourseSheetTitle => '新增內容';

  @override
  String get addCourseSheetSubtitle =>
      '空白課表區域不響應點擊。請從這裡明確選擇是加一節臨時課、整學期重複課，還是插入一條單次日程。';

  @override
  String courseWeekdaySectionSummary(
    String weekDescription,
    String weekday,
    int startSection,
    int endSection,
  ) {
    return '$weekDescription · $weekday 第$startSection-$endSection節';
  }

  @override
  String weekdaySectionTimeSummary(
    String weekday,
    int startSection,
    int endSection,
    String startTime,
    String endTime,
  ) {
    return '$weekday 第$startSection-$endSection節 · $startTime-$endTime';
  }

  @override
  String rescheduledToMessage(
    int week,
    String weekday,
    int startSection,
    int endSection,
  ) {
    return '已調到第 $week 周 $weekday 第$startSection-$endSection節';
  }

  @override
  String courseCountSummary(int count) {
    return '$count 門課';
  }

  @override
  String dayAgendaInProgressStatus(int minutes) {
    return '進行中 · 剩餘 $minutes 分鐘';
  }

  @override
  String dayAgendaEndingSoonStatus(int minutes) {
    return '快下課了 · 剩餘 $minutes 分鐘';
  }

  @override
  String scheduleAgendaInProgressStatus(int minutes) {
    return '進行中 · 剩餘 $minutes 分鐘';
  }

  @override
  String scheduleAgendaEndingSoonStatus(int minutes) {
    return '即將結束 · 剩餘 $minutes 分鐘';
  }

  @override
  String get currentBadge => '當前';

  @override
  String get feedbackXiaohongshuTitle => '小紅書';

  @override
  String feedbackXiaohongshuSubtitle(String id) {
    return '小紅書号：$id';
  }

  @override
  String get feedbackCoolapkTitle => '酷安';

  @override
  String feedbackCoolapkSubtitle(String id) {
    return '酷安号：$id';
  }

  @override
  String get feedbackQqGroupTitle => 'QQ 群';

  @override
  String feedbackQqGroupSubtitle(String id) {
    return '群号：$id';
  }

  @override
  String get copiedCurrentTimetable => '已複製當前課表';

  @override
  String sectionRangeLabel(int startSection, int endSection) {
    return '第$startSection-$endSection節';
  }

  @override
  String classStartsAtLabel(String time) {
    return '$time 開始';
  }

  @override
  String classEndsAtLabel(String time) {
    return '$time 結束';
  }

  @override
  String get invalidSectionTimeFormat => '節次時間格式不正確';

  @override
  String get noSectionTimesToSave => '沒有可保存的節次時間';

  @override
  String warehouseImportedTimeSchemeName(String schoolName) {
    return '$schoolName 匯入節次';
  }

  @override
  String get unnamedScript => '未命名腳本';

  @override
  String localDebugModeScriptStatus(String scriptName) {
    return '本地偵錯模式：$scriptName';
  }

  @override
  String get executeImportScriptTooltip => '執行匯入腳本';

  @override
  String get switchToMobileWebTooltip => '切換到移動端頁面';

  @override
  String get switchToDesktopWebTooltip => '切換到桌面端頁面';

  @override
  String get rememberCurrentInputTooltip => '記住當前輸入';

  @override
  String get fillRememberedTooltip => '填充已記住賬號';

  @override
  String get clearRememberedTooltip => '清除已記住賬號';

  @override
  String get copyCurrentAddressTooltip => '複製當前地址';

  @override
  String get copiedCurrentAddress => '已複製當前地址';

  @override
  String get warehouseLoginHintLocalDebug => '當前為本地偵錯腳本模式';

  @override
  String get warehouseLoginHintImport => '在此登入教務系統後執行匯入';

  @override
  String get currentPageModeDesktop => '當前页面模式：桌面端';

  @override
  String get currentPageModeMobile => '當前页面模式：移动端';

  @override
  String localScriptLabel(String scriptName) {
    return '本地腳本：$scriptName';
  }

  @override
  String get webAddressHint => '輸入網頁地址';

  @override
  String get goAction => '前往';

  @override
  String rememberedAccountLabel(String username) {
    return '已記住賬號：$username';
  }

  @override
  String get importingAction => '匯入中...';

  @override
  String get executeLocalDebugScriptAction => '執行本地偵錯腳本';

  @override
  String get executeImportScriptAction => '執行匯入腳本';

  @override
  String get invalidWebAddress => '網頁地址無效';

  @override
  String get injectingLocalDebugScript => '正在注入本地偵錯腳本';

  @override
  String get injectingAdapterScript => '正在注入適配器腳本';

  @override
  String get localDebugScriptInjected => '本地偵錯腳本已注入';

  @override
  String get scriptInjected => '腳本已注入';

  @override
  String get scriptInjectionFailed => '腳本注入失敗';

  @override
  String executeFailedWithError(String error) {
    return '執行失敗：$error';
  }

  @override
  String get importFlowFinished => '匯入流程已完成';

  @override
  String get defaultContinuePrompt => '請按提示繼續操作';

  @override
  String get inputRequiredTitle => '需要输入';

  @override
  String get pleaseEnterFourDigitYear => '請輸入 4 位年份';

  @override
  String get pleaseChooseTitle => '請選擇';

  @override
  String get invalidCourseConfigFormat => '課程配置格式不正確';

  @override
  String saveCourseConfigFailedWithError(String error) {
    return '保存課程配置失敗：$error';
  }

  @override
  String saveSectionTimesFailedWithError(String error) {
    return '保存節次時間失敗：$error';
  }

  @override
  String get invalidCourseDataFormat => '課程資料格式不正確';

  @override
  String get noImportableCoursesFromScript => '腳本未返回可匯入課程';

  @override
  String importCourseCountPrompt(int count) {
    return '識別到 $count 門課程，是否匯入？';
  }

  @override
  String get importCancelledStatus => '已取消匯入';

  @override
  String applyReturnedTimeSchemeFailed(String error) {
    return '應用返回的節次模板失败：$error';
  }

  @override
  String get importInterruptedStatus => '匯入已中斷';

  @override
  String get importFailedStatus => '匯入失敗';

  @override
  String importFailedWithError(String error) {
    return '匯入失敗：$error';
  }

  @override
  String get unknownTeacher => '未知教師';

  @override
  String get unknownLocation => '未知地點';

  @override
  String get autofillLoginTitle => '自動填充登入資訊';

  @override
  String autofillLoginMessage(String username) {
    return '檢測到已記住賬號 $username，是否自動填充？';
  }

  @override
  String get notNowAction => '暫不';

  @override
  String get autofillAction => '自動填充';

  @override
  String get rememberPasswordTitle => '記住密碼';

  @override
  String rememberPasswordMessage(String username) {
    return '是否記住賬號 $username 的登入資訊，並在下次自動填充？';
  }

  @override
  String get dontRememberAction => '不記住';

  @override
  String get rememberAndAutofillAction => '記住並自動填充';

  @override
  String get savedRememberedLoginStatus => '已保存記住的登入資訊';

  @override
  String get autofilledRememberedLoginStatus => '已自動填充記住的登入資訊';

  @override
  String get noRecognizedLoginInputs => '未識別到登入輸入項';

  @override
  String get noUsernameOrPasswordRecognized => '未識別到用戶名或密碼';

  @override
  String get rememberedCurrentLoginStatus => '已記住當前登入資訊';

  @override
  String get rememberedCurrentLoginSuccess => '已記住當前登入資訊';

  @override
  String rememberLoginFailedWithError(String error) {
    return '記住登入資訊失敗：$error';
  }

  @override
  String get clearedRememberedLoginStatus => '已清除記住的登入資訊';

  @override
  String get clearedRememberedLoginSuccess => '已清除記住的登入資訊';

  @override
  String get addScheduleTitle => '新增日程';

  @override
  String get editScheduleTitle => '編輯日程';

  @override
  String get addScheduleAction => '新增日程';

  @override
  String get scheduleTitleLabel => '日程標題';

  @override
  String get scheduleTitleHint => '例如：開組會、辦證件、取包裹';

  @override
  String get scheduleTitleRequired => '請輸入日程標題';

  @override
  String get scheduleInfoSectionTitle => '日程資訊';

  @override
  String get scheduleInfoSectionSubtitle => '日程會按具體日期插入日視圖時間線，不會改動課程本身。';

  @override
  String get scheduleTimeSectionTitle => '時間安排';

  @override
  String get scheduleTimeSectionSubtitle => '選擇這條日程實際發生的日期和起止時間。';

  @override
  String get scheduleAppearanceSectionTitle => '顯示樣式';

  @override
  String get scheduleAppearanceSectionSubtitle => '選一個更容易和課程區分的日程顏色。';

  @override
  String get scheduleLocationLabel => '地點';

  @override
  String get scheduleLocationHint => '選填';

  @override
  String get scheduleDateLabel => '日期';

  @override
  String get scheduleStartDateLabel => '開始日期';

  @override
  String get scheduleEndDateLabel => '結束日期';

  @override
  String get scheduleStartTimeLabel => '開始時間';

  @override
  String get scheduleEndTimeLabel => '結束時間';

  @override
  String get scheduleColorLabel => '日程顏色';

  @override
  String get scheduleNoteLabel => '備註';

  @override
  String get scheduleNoteHint => '選填';

  @override
  String get scheduleBadgeLabel => '日程';

  @override
  String scheduleCountSummary(int count) {
    return '日程 $count 項';
  }

  @override
  String get scheduleTimeRangeInvalid => '結束時間必須晚於開始時間';

  @override
  String get scheduleDateRangeInvalid => '結束日期不能早於開始日期';

  @override
  String get scheduleSingleDayHint => '同日結束時，結束時間必須晚於開始時間。';

  @override
  String get scheduleCrossDayHint => '跨日日程會按當天切片顯示在日視圖時間軸裡。';

  @override
  String get scheduleSavedHint => '日程已新增';

  @override
  String get scheduleUpdatedHint => '日程已更新';

  @override
  String get crossDayBadgeLabel => '跨日';

  @override
  String deleteScheduleMessage(String title) {
    return '刪除日程「$title」？';
  }

  @override
  String get scheduleDeletedHint => '日程已刪除';

  @override
  String get examListTitle => '考試安排';

  @override
  String get addExam => '新增考試';

  @override
  String get editExam => '編輯考試';

  @override
  String get saveExam => '儲存考試';

  @override
  String get noExams => '暫無考試安排';

  @override
  String get examToday => '今天有考試';

  @override
  String daysUntilExam(int days) {
    return '距離考試還有 $days 天';
  }

  @override
  String get examPassed => '已結束';

  @override
  String get linkCourse => '關聯課程';

  @override
  String get linkCourseRequired => '請選擇關聯課程';

  @override
  String get examNameLabel => '考試名稱';

  @override
  String get examNameRequired => '請輸入考試名稱';

  @override
  String get examDateLabel => '考試日期';

  @override
  String get examDateHint => '請選擇日期';

  @override
  String get examDateRequired => '請選擇考試日期';

  @override
  String get examStartTimeLabel => '開始時間';

  @override
  String get examEndTimeLabel => '結束時間';

  @override
  String get examLocationLabel => '考場';

  @override
  String get examLocationHint => '留空則使用上課教室';

  @override
  String get sameAsClassroom => '同上課教室';

  @override
  String get examSeatLabel => '座位號';

  @override
  String get examReminderLabel => '提醒設定';

  @override
  String get examNoteLabel => '備註';

  @override
  String get deleteExam => '刪除考試';

  @override
  String deleteExamConfirm(String name) {
    return '刪除考試「$name」？';
  }

  @override
  String get examBadgeLabel => '考試';

  @override
  String get examCountdownToday => '今天';

  @override
  String examCountdownDays(int days) {
    return '$days天後';
  }

  @override
  String get sortAction => '排序';

  @override
  String get sortByAdded => '依新增順序';

  @override
  String get sortByName => '依課程名稱';

  @override
  String get sortBySchedule => '依上課時間';

  @override
  String scheduleEntryTitle(int index) {
    return '排課紀錄 $index';
  }

  @override
  String get addScheduleEntryAction => '新增排課時段';

  @override
  String get deleteScheduleEntryAction => '刪除排課';

  @override
  String get holidaySettingsEntryTitle => '假日標記';

  @override
  String get holidaySettingsEntrySubtitle => '在課表上標示放假日與補班日';

  @override
  String get holidayMakeupWorkday => '補班';

  @override
  String get holidaySettingsTitle => '假日標記';

  @override
  String get holidayEnableTitle => '啟用假日標記';

  @override
  String get holidayEnableSubtitle => '啟用後會在課表上標示放假日與補班日。';

  @override
  String get holidayDataSectionTitle => '假日資料';

  @override
  String get holidayDataYear => '年份';

  @override
  String get holidayDataCount => '數量';

  @override
  String get holidayDataEmpty => '目前沒有假日資料';

  @override
  String get holidayCheckUpdate => '檢查更新';

  @override
  String get holidayUpcomingSectionTitle => '近期假日';

  @override
  String get holidayNoUpcoming => '近期沒有假日';

  @override
  String get holidayBadgeLabel => '休';

  @override
  String get holidayStatusLabel => '放假';

  @override
  String get suspendedBadgeLabel => '停';

  @override
  String get suspendedStatusLabel => '停課';

  @override
  String get courseActionSuspend => '停課';

  @override
  String get courseActionUnsuspend => '恢復上課';

  @override
  String get suspendSheetTitle => '停課';

  @override
  String get suspendSheetSubtitle => '選擇停課範圍';

  @override
  String get suspendThisWeek => '本週停課';

  @override
  String get suspendThisWeekDesc => '只停本週';

  @override
  String get suspendAllWeeks => '全部週次停課';

  @override
  String get suspendAllWeeksDesc => '套用到所有週次';

  @override
  String get unsuspendAllWeeks => '恢復全部週次';

  @override
  String get unsuspendAllWeeksDesc => '恢復所有週次';

  @override
  String get customHolidayTitle => '自訂假日';

  @override
  String get customHolidayAdd => '新增假日';

  @override
  String get customHolidayEdit => '編輯假日';

  @override
  String get customHolidayDelete => '刪除';

  @override
  String get customHolidayDeleteConfirm => '確定要刪除此自訂假日嗎？';

  @override
  String get customHolidayNameLabel => '假日名稱';

  @override
  String get customHolidayStartDate => '開始日期';

  @override
  String get customHolidayEndDate => '結束日期';

  @override
  String get customHolidayType => '類型';

  @override
  String get customHolidayTypeVacation => '放假';

  @override
  String get customHolidayTypeWorkday => '補班日';

  @override
  String get customHolidayEmpty => '目前沒有自訂假日';

  @override
  String get customHolidayNameRequired => '請輸入假日名稱';

  @override
  String customHolidayDateRange(Object start, Object end) {
    return '$start ~ $end';
  }

  @override
  String get selectTeacherTitle => '選擇老師';

  @override
  String get selectLocationTitle => '選擇地點';

  @override
  String get historyRecordsLabel => '歷史紀錄';

  @override
  String get noHistoryRecords => '目前沒有歷史紀錄';

  @override
  String get weekPickerTitle => '選擇上課週次';

  @override
  String get selectTimeSchemeTitle => '選擇時間方案';

  @override
  String get manageTimeSchemesAction => '管理時間方案';

  @override
  String get examDefaultName => '期末考試';

  @override
  String get examDateWeekPickerTitle => '選擇考試日期';

  @override
  String get weekPickerCalendarTooltip => '使用日曆選擇';

  @override
  String get thisWeekLabel => '本週';

  @override
  String get guidePrivacyPageTitle => '隱私權條款';

  @override
  String get guidePermissionsPageTitle => '系統權限';

  @override
  String get guideTipsPageTitle => '使用技巧';

  @override
  String get guidePrevButton => '上一步';

  @override
  String get guideNextButton => '下一步';

  @override
  String get guidePermissionsHeader => '系統權限設定';

  @override
  String get guidePermissionsSubtitle => '完成這些設定，超級島和提醒才能正常使用';

  @override
  String get guidePermissionsFooterHint =>
      '點擊後跳轉到系統設定，返回應用後可識別的狀態會自動刷新；自啟動受系統限制，請以系統頁面開關為準。';

  @override
  String get guideTipsHeader => '使用技巧';

  @override
  String get guideTipsSubtitle => '這些隨時可以在「設定」裡找到';

  @override
  String get guidePrivacyReadBeforeUse => '使用前請閱讀並同意以下內容';

  @override
  String get guidePrivacyViewOnly => '隱私權、第三方 SDK 與免責聲明';

  @override
  String holidayDataYearLabel(Object year) {
    return '$year年國定假日';
  }

  @override
  String get holidayUpdateLog => '更新紀錄';

  @override
  String holidayUpdateLogCount(int count) {
    return '$count筆';
  }

  @override
  String holidayDateSameMonth(int month, int start, int end) {
    return '$month月$start日 - $end日';
  }

  @override
  String holidayDateSameDay(int month, int day) {
    return '$month月$day日';
  }

  @override
  String holidayDateDiffMonth(
    int startMonth,
    int startDay,
    int endMonth,
    int endDay,
  ) {
    return '$startMonth月$startDay日 - $endMonth月$endDay日';
  }

  @override
  String get liveTestingHolidayOverride => '假期狀態覆蓋';

  @override
  String get liveTestingHolidayOverrideSubtitle =>
      '開啟後模擬假期狀態，用於測試提醒和小工具是否正確隱藏課程';

  @override
  String get liveTestingHolidayModeEnabled => '假期模式已開啟';

  @override
  String get liveTestingHolidayModeDisabled => '假期模式已關閉';

  @override
  String get liveTestingHolidayModeEnabledDesc => '課程提醒和小工具將隱藏所有課程';

  @override
  String get liveTestingHolidayModeDisabledDesc => '當前使用正常假期數據';

  @override
  String get textColorTitle => '文字顏色';

  @override
  String get textColorSubtitle => '自訂課表各區域的文字顏色';

  @override
  String get textColorIndependentDetail => '獨立設定詳情顏色';

  @override
  String get textColorCourseCardTitle => '課程卡片標題顏色';

  @override
  String get textColorCourseCardDetail => '課程卡片詳情顏色';

  @override
  String get textColorWeekdayBar => '星期欄字體顏色';

  @override
  String get textColorWeekdayBarAccent => '星期欄強調色彩';

  @override
  String get textColorTimeAxis => '時間軸字體顏色';

  @override
  String get textColorSelectColor => '選擇顏色';

  @override
  String get textColorCurrentColor => '目前顏色';

  @override
  String get themeExport => '匯出主題';

  @override
  String get themeImport => '匯入主題';

  @override
  String get themeExportSuccess => '主題已複製到剪貼簿';

  @override
  String get themeImportSuccess => '主題已匯入';

  @override
  String get themeImportFailed => '剪貼簿內容格式錯誤';

  @override
  String get themeManageTitle => '主題管理';

  @override
  String get themeManageSubtitle => '匯出、匯入和切換主題';

  @override
  String get themePreset => '預設主題';

  @override
  String get themeSaved => '我的主題';

  @override
  String get themeSaveCurrent => '儲存當前主題';

  @override
  String get themeApply => '套用';

  @override
  String get themeDelete => '刪除';

  @override
  String themeDeleteConfirmMessage(String name) {
    return '確定要刪除主題「$name」嗎？';
  }

  @override
  String get textColorLowContrastWarning => '顏色對比度較低，可能會影響可讀性';

  @override
  String get themeCurrentTheme => '當前主題';

  @override
  String themeBasedOnModified(String baseName) {
    return '基於$baseName（已修改）';
  }

  @override
  String get themeResetToPreset => '重設';

  @override
  String get themeUnsavedChangesTitle => '未儲存的修改';

  @override
  String get themeUnsavedChangesMessage => '當前主題有未儲存的修改，是否儲存？';

  @override
  String get themeDiscardAndApply => '放棄並套用';

  @override
  String get themeNameHint => '輸入主題名稱';

  @override
  String get themePresetBlue => '預設藍';

  @override
  String get themePresetPurple => '暗夜紫';

  @override
  String get themePresetGreen => '森林綠';

  @override
  String get themePresetOrange => '暖陽橙';

  @override
  String get themePresetEyeCare => '護眼模式';

  @override
  String get themePresetHighContrast => '高對比度';

  @override
  String get themePresetDarkMinimal => '深色極簡';

  @override
  String get themeUndo => '撤銷';

  @override
  String themeChanged(String themeName) {
    return '已切換到 $themeName';
  }

  @override
  String get themeRename => '重新命名';

  @override
  String get themeDuplicate => '複製';
}
