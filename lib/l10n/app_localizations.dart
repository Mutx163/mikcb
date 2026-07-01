import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('ko'),
    Locale('zh'),
    Locale('zh', 'HK'),
    Locale('zh', 'TW'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'轻屿课表'**
  String get appTitle;

  /// No description provided for @appTitleDebug.
  ///
  /// In zh, this message translates to:
  /// **'轻屿课表调试版'**
  String get appTitleDebug;

  /// No description provided for @appearanceTitle.
  ///
  /// In zh, this message translates to:
  /// **'外观与配色'**
  String get appearanceTitle;

  /// No description provided for @previewTitle.
  ///
  /// In zh, this message translates to:
  /// **'预览'**
  String get previewTitle;

  /// No description provided for @timetableBackgroundPreview.
  ///
  /// In zh, this message translates to:
  /// **'课表背景'**
  String get timetableBackgroundPreview;

  /// No description provided for @displayModeTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示模式'**
  String get displayModeTitle;

  /// No description provided for @displayModeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'支持跟随系统、浅色模式和深色模式。'**
  String get displayModeSubtitle;

  /// No description provided for @themeModeLabel.
  ///
  /// In zh, this message translates to:
  /// **'主题模式'**
  String get themeModeLabel;

  /// No description provided for @themeModeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeModeSystem;

  /// No description provided for @themeModeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色模式'**
  String get themeModeLight;

  /// No description provided for @themeModeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色模式'**
  String get themeModeDark;

  /// No description provided for @fontSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'应用字体'**
  String get fontSectionTitle;

  /// No description provided for @fontSectionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'支持系统默认字体和 MiSans。MiSans 不可用时会自动回退。'**
  String get fontSectionSubtitle;

  /// No description provided for @fontModeLabel.
  ///
  /// In zh, this message translates to:
  /// **'字体选择'**
  String get fontModeLabel;

  /// No description provided for @fontModeSystem.
  ///
  /// In zh, this message translates to:
  /// **'手机默认字体'**
  String get fontModeSystem;

  /// No description provided for @fontModeMiSans.
  ///
  /// In zh, this message translates to:
  /// **'MiSans（优先）'**
  String get fontModeMiSans;

  /// No description provided for @languageSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'应用语言'**
  String get languageSectionTitle;

  /// No description provided for @languageSectionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'可跟随系统，或手动切换到已适配语言。'**
  String get languageSectionSubtitle;

  /// No description provided for @languageModeLabel.
  ///
  /// In zh, this message translates to:
  /// **'语言选择'**
  String get languageModeLabel;

  /// No description provided for @languageModeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get languageModeSystem;

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'课表设置'**
  String get settingsTitle;

  /// No description provided for @dailyUsageSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'日常使用'**
  String get dailyUsageSectionTitle;

  /// No description provided for @appearanceEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'外观与配色'**
  String get appearanceEntryTitle;

  /// No description provided for @appearanceEntrySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'主题色、课表背景、课程卡片颜色'**
  String get appearanceEntrySubtitle;

  /// No description provided for @layoutSectionEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'布局与节次'**
  String get layoutSectionEntryTitle;

  /// No description provided for @layoutSectionEntrySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'节次时间、行高、时间列、周末显示与卡片布局'**
  String get layoutSectionEntrySubtitle;

  /// No description provided for @homeWidgetEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'桌面小组件'**
  String get homeWidgetEntryTitle;

  /// No description provided for @homeWidgetEntrySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'今日课程卡片、小组件背景与显示信息'**
  String get homeWidgetEntrySubtitle;

  /// No description provided for @reminderNotificationSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'提醒与通知'**
  String get reminderNotificationSectionTitle;

  /// No description provided for @userGuideEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'使用引导与权限'**
  String get userGuideEntryTitle;

  /// No description provided for @userGuideEntrySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'简称建议、通知、自启动、电池策略'**
  String get userGuideEntrySubtitle;

  /// No description provided for @timetableManagementSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'课表管理'**
  String get timetableManagementSectionTitle;

  /// No description provided for @timeSchemeEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'时间模板'**
  String get timeSchemeEntryTitle;

  /// No description provided for @timeSchemeEntrySubtitleNoneSelected.
  ///
  /// In zh, this message translates to:
  /// **'切换、编辑节次、复制和管理时间模板'**
  String get timeSchemeEntrySubtitleNoneSelected;

  /// No description provided for @timeSchemeEntrySubtitleSelected.
  ///
  /// In zh, this message translates to:
  /// **'当前：{name} · 切换、编辑节次和复制'**
  String timeSchemeEntrySubtitleSelected(String name);

  /// No description provided for @dataTransferEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'数据备份与迁移'**
  String get dataTransferEntryTitle;

  /// No description provided for @dataTransferEntrySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'导出完整课表文件，给别人直接导入使用'**
  String get dataTransferEntrySubtitle;

  /// No description provided for @lanEditEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'局域网编辑'**
  String get lanEditEntryTitle;

  /// No description provided for @lanEditEntrySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'在电脑浏览器中编辑当前课表'**
  String get lanEditEntrySubtitle;

  /// No description provided for @lanEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'局域网编辑'**
  String get lanEditTitle;

  /// No description provided for @lanEditIntro.
  ///
  /// In zh, this message translates to:
  /// **'开启后，同一 WiFi 或手机热点下的电脑可通过浏览器编辑当前课表。数据不会上传云端，关闭后即停止访问。'**
  String get lanEditIntro;

  /// No description provided for @lanEditStart.
  ///
  /// In zh, this message translates to:
  /// **'开启局域网编辑'**
  String get lanEditStart;

  /// No description provided for @lanEditStop.
  ///
  /// In zh, this message translates to:
  /// **'停止'**
  String get lanEditStop;

  /// No description provided for @lanEditStatusRunning.
  ///
  /// In zh, this message translates to:
  /// **'编辑会话进行中'**
  String get lanEditStatusRunning;

  /// No description provided for @lanEditAddressLabel.
  ///
  /// In zh, this message translates to:
  /// **'访问地址'**
  String get lanEditAddressLabel;

  /// No description provided for @lanEditAddressUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'未检测到局域网 IP，请确认已连接 WiFi 或已开启热点'**
  String get lanEditAddressUnavailable;

  /// No description provided for @lanEditPinLabel.
  ///
  /// In zh, this message translates to:
  /// **'PIN'**
  String get lanEditPinLabel;

  /// No description provided for @lanEditPortLabel.
  ///
  /// In zh, this message translates to:
  /// **'端口'**
  String get lanEditPortLabel;

  /// No description provided for @lanEditCopyAddress.
  ///
  /// In zh, this message translates to:
  /// **'复制地址'**
  String get lanEditCopyAddress;

  /// No description provided for @lanEditCopied.
  ///
  /// In zh, this message translates to:
  /// **'地址已复制'**
  String get lanEditCopied;

  /// No description provided for @lanEditHotspotHint.
  ///
  /// In zh, this message translates to:
  /// **'如果宿舍 WiFi 无法访问，请尝试用手机开热点，再让电脑连接该热点。'**
  String get lanEditHotspotHint;

  /// No description provided for @lanEditQrHint.
  ///
  /// In zh, this message translates to:
  /// **'电脑浏览器扫描上方二维码可打开控制台（链接已含 PIN，需同一局域网）。'**
  String get lanEditQrHint;

  /// No description provided for @lanEditStartFailed.
  ///
  /// In zh, this message translates to:
  /// **'启动失败'**
  String get lanEditStartFailed;

  /// No description provided for @lanEditConnectedClientsLabel.
  ///
  /// In zh, this message translates to:
  /// **'已连接'**
  String get lanEditConnectedClientsLabel;

  /// No description provided for @lanEditConnectedClientsNone.
  ///
  /// In zh, this message translates to:
  /// **'暂无'**
  String get lanEditConnectedClientsNone;

  /// No description provided for @lanEditConnectedClientsValue.
  ///
  /// In zh, this message translates to:
  /// **'{count} 台'**
  String lanEditConnectedClientsValue(int count);

  /// No description provided for @lanEditLastActivityLabel.
  ///
  /// In zh, this message translates to:
  /// **'最近活动'**
  String get lanEditLastActivityLabel;

  /// No description provided for @aboutSupportSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'关于与支持'**
  String get aboutSupportSectionTitle;

  /// No description provided for @feedbackEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'问题反馈'**
  String get feedbackEntryTitle;

  /// No description provided for @feedbackEntrySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'Issue、社区渠道和建议反馈入口'**
  String get feedbackEntrySubtitle;

  /// No description provided for @aboutEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'关于软件'**
  String get aboutEntryTitle;

  /// No description provided for @aboutEntrySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'开源说明、版本更新和 GitHub 仓库'**
  String get aboutEntrySubtitle;

  /// No description provided for @setSemesterStartDateAction.
  ///
  /// In zh, this message translates to:
  /// **'设置开学日期'**
  String get setSemesterStartDateAction;

  /// No description provided for @semesterStartDateAction.
  ///
  /// In zh, this message translates to:
  /// **'开学日期'**
  String get semesterStartDateAction;

  /// No description provided for @syncCurrentWeekAction.
  ///
  /// In zh, this message translates to:
  /// **'同步当前周'**
  String get syncCurrentWeekAction;

  /// No description provided for @semesterWeekCountAction.
  ///
  /// In zh, this message translates to:
  /// **'{count} 周'**
  String semesterWeekCountAction(int count);

  /// No description provided for @selectSemesterWeekCountTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择学期周数'**
  String get selectSemesterWeekCountTitle;

  /// No description provided for @selectSemesterWeekCountSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'不同学校可按实际教学周数调整。'**
  String get selectSemesterWeekCountSubtitle;

  /// No description provided for @unifiedCourseCardColorTitle.
  ///
  /// In zh, this message translates to:
  /// **'统一课程卡片颜色'**
  String get unifiedCourseCardColorTitle;

  /// No description provided for @unifiedCourseCardColorSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'关闭后继续使用每门课程自己的颜色'**
  String get unifiedCourseCardColorSubtitle;

  /// No description provided for @courseImportTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入课程'**
  String get courseImportTitle;

  /// No description provided for @chooseImportMethodTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择导入方式'**
  String get chooseImportMethodTitle;

  /// No description provided for @chooseImportMethodSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'现在支持传统 .ics 日历导入、识图导入，以及从仓库读取适配器的教务系统导入。'**
  String get chooseImportMethodSubtitle;

  /// No description provided for @importMethodIcsTitle.
  ///
  /// In zh, this message translates to:
  /// **'.ics 日历导入'**
  String get importMethodIcsTitle;

  /// No description provided for @importMethodIcsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'适合从 WakeUp 等课表应用导出的日历文件，流程最短。'**
  String get importMethodIcsSubtitle;

  /// No description provided for @importMethodIcsFooter.
  ///
  /// In zh, this message translates to:
  /// **'进入后直接选择 .ics 文件，可追加导入或替换现有课程。'**
  String get importMethodIcsFooter;

  /// No description provided for @importMethodAiTitle.
  ///
  /// In zh, this message translates to:
  /// **'识图导入'**
  String get importMethodAiTitle;

  /// No description provided for @importMethodAiSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'适合直接从课表截图导入，支持 1 张或多张连续截图。'**
  String get importMethodAiSubtitle;

  /// No description provided for @importMethodAiFooter.
  ///
  /// In zh, this message translates to:
  /// **'先复制提示词，再到豆包专家模式发送截图和提示词，把返回的 JSON 复制回来导入，最后选择开学日期。'**
  String get importMethodAiFooter;

  /// No description provided for @importMethodWarehouseTitle.
  ///
  /// In zh, this message translates to:
  /// **'教务系统导入'**
  String get importMethodWarehouseTitle;

  /// No description provided for @importMethodWarehouseSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'从 qingyu_warehouse 读取学校与适配器，支持网页登录导入课程。'**
  String get importMethodWarehouseSubtitle;

  /// No description provided for @importMethodWarehouseFooter.
  ///
  /// In zh, this message translates to:
  /// **'进入后选择学校和适配器，可直接打开教务网页登录并执行导入。'**
  String get importMethodWarehouseFooter;

  /// No description provided for @importMethodSpreadsheetTitle.
  ///
  /// In zh, this message translates to:
  /// **'表格导入'**
  String get importMethodSpreadsheetTitle;

  /// No description provided for @importMethodSpreadsheetSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'适合用 Excel/WPS 填写轻屿课表模板后导入，无需先导出 .ics。'**
  String get importMethodSpreadsheetSubtitle;

  /// No description provided for @importMethodSpreadsheetFooter.
  ///
  /// In zh, this message translates to:
  /// **'支持 .csv 与 .xlsx，可下载官方模板填写后选择文件导入。'**
  String get importMethodSpreadsheetFooter;

  /// No description provided for @spreadsheetImportTitle.
  ///
  /// In zh, this message translates to:
  /// **'表格导入'**
  String get spreadsheetImportTitle;

  /// No description provided for @spreadsheetScenarioIntro.
  ///
  /// In zh, this message translates to:
  /// **'轻屿模板按表头识别列：必填列为课程名、星期、开始节、结束节及周次；其余列为可选。可下载完整模板，也可只保留必要列。也兼容 WakeUp 7 列格式。'**
  String get spreadsheetScenarioIntro;

  /// No description provided for @spreadsheetStep1Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'下载完整模板填写，或只保留必填列与上课周（或开始周+结束周）做最小导入。'**
  String get spreadsheetStep1Subtitle;

  /// No description provided for @spreadsheetStep2Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'填写完成后另存为 .csv 或直接保留 .xlsx。'**
  String get spreadsheetStep2Subtitle;

  /// No description provided for @spreadsheetStep3Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'选择文件导入；如有识别提醒会先展示，再选择追加或替换。'**
  String get spreadsheetStep3Subtitle;

  /// No description provided for @spreadsheetSupportedFilesSuffix.
  ///
  /// In zh, this message translates to:
  /// **'支持 .csv 与 .xlsx（仅读取第一个工作表）。'**
  String get spreadsheetSupportedFilesSuffix;

  /// No description provided for @chooseSpreadsheetFileAction.
  ///
  /// In zh, this message translates to:
  /// **'选择表格文件'**
  String get chooseSpreadsheetFileAction;

  /// No description provided for @downloadSpreadsheetTemplateAction.
  ///
  /// In zh, this message translates to:
  /// **'下载轻屿课表模板'**
  String get downloadSpreadsheetTemplateAction;

  /// No description provided for @spreadsheetImportWarningsTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入提醒'**
  String get spreadsheetImportWarningsTitle;

  /// No description provided for @spreadsheetImportWarningsMessage.
  ///
  /// In zh, this message translates to:
  /// **'以下行未能导入，其余课程可继续：'**
  String get spreadsheetImportWarningsMessage;

  /// No description provided for @spreadsheetImportWarningsContinue.
  ///
  /// In zh, this message translates to:
  /// **'继续导入'**
  String get spreadsheetImportWarningsContinue;

  /// No description provided for @spreadsheetFormatUnrecognized.
  ///
  /// In zh, this message translates to:
  /// **'未识别表格格式，请使用轻屿课表模板；也兼容 WakeUp 等同列格式'**
  String get spreadsheetFormatUnrecognized;

  /// No description provided for @icsImportTitle.
  ///
  /// In zh, this message translates to:
  /// **'.ics 日历导入'**
  String get icsImportTitle;

  /// No description provided for @applicableScenarioTitle.
  ///
  /// In zh, this message translates to:
  /// **'适用场景'**
  String get applicableScenarioTitle;

  /// No description provided for @icsScenarioIntro.
  ///
  /// In zh, this message translates to:
  /// **'如果你已经能在 WakeUp 等课表应用里导入教务系统课程，再导出为 .ics 文件，这条路最稳。'**
  String get icsScenarioIntro;

  /// No description provided for @stepLabel.
  ///
  /// In zh, this message translates to:
  /// **'步骤 {step}'**
  String stepLabel(String step);

  /// No description provided for @icsStep1Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'先在其他课表应用里导出 .ics 日历文件。'**
  String get icsStep1Subtitle;

  /// No description provided for @icsStep2Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'回到这里选择文件，可选“追加导入”或“替换现有”。'**
  String get icsStep2Subtitle;

  /// No description provided for @icsStep3Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'导入前还会让你确认开学日期，以及课表第 1 周对应校历第几周。'**
  String get icsStep3Subtitle;

  /// No description provided for @supportedFilesTitle.
  ///
  /// In zh, this message translates to:
  /// **'支持的文件'**
  String get supportedFilesTitle;

  /// No description provided for @supportedFilesSuffix.
  ///
  /// In zh, this message translates to:
  /// **'文件后缀必须是 .ics。'**
  String get supportedFilesSuffix;

  /// No description provided for @supportedFilesImageHint.
  ///
  /// In zh, this message translates to:
  /// **'如果你手里只有截图，不要走这里，请返回上一页选择“识图导入”。'**
  String get supportedFilesImageHint;

  /// No description provided for @chooseIcsFileAction.
  ///
  /// In zh, this message translates to:
  /// **'选择 .ics 文件'**
  String get chooseIcsFileAction;

  /// No description provided for @timetableAppName.
  ///
  /// In zh, this message translates to:
  /// **'轻屿课表'**
  String get timetableAppName;

  /// No description provided for @switchProfileHint.
  ///
  /// In zh, this message translates to:
  /// **'点击切换课表'**
  String get switchProfileHint;

  /// No description provided for @moreTooltip.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get moreTooltip;

  /// No description provided for @pleaseSetSemesterStartDate.
  ///
  /// In zh, this message translates to:
  /// **'请先在课表设置里填写开学日期'**
  String get pleaseSetSemesterStartDate;

  /// No description provided for @deleteScheduleTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除日程'**
  String get deleteScheduleTitle;

  /// No description provided for @deleteLessonTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除这节课'**
  String get deleteLessonTitle;

  /// No description provided for @cancelAction.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancelAction;

  /// No description provided for @confirmAction.
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get confirmAction;

  /// No description provided for @deleteAction.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get deleteAction;

  /// No description provided for @deletedCourseMessage.
  ///
  /// In zh, this message translates to:
  /// **'已删除：{name}'**
  String deletedCourseMessage(String name);

  /// No description provided for @deleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除失败'**
  String get deleteFailed;

  /// No description provided for @rescheduleFailed.
  ///
  /// In zh, this message translates to:
  /// **'调课失败'**
  String get rescheduleFailed;

  /// No description provided for @timetableManagement.
  ///
  /// In zh, this message translates to:
  /// **'课表管理'**
  String get timetableManagement;

  /// No description provided for @weekLabel.
  ///
  /// In zh, this message translates to:
  /// **'第 {week} 周'**
  String weekLabel(int week);

  /// No description provided for @sectionLabel.
  ///
  /// In zh, this message translates to:
  /// **'第 {section} 节'**
  String sectionLabel(int section);

  /// No description provided for @feedbackTitle.
  ///
  /// In zh, this message translates to:
  /// **'问题反馈'**
  String get feedbackTitle;

  /// No description provided for @feedbackIntro.
  ///
  /// In zh, this message translates to:
  /// **'如果你遇到崩溃、课程显示异常、导入问题，或者想提交功能建议，可以通过下面这些渠道反馈。'**
  String get feedbackIntro;

  /// No description provided for @feedbackIssueHint.
  ///
  /// In zh, this message translates to:
  /// **'涉及复现步骤、截图、版本号和日志的问题，建议优先走 GitHub Issue。'**
  String get feedbackIssueHint;

  /// No description provided for @githubIssueTitle.
  ///
  /// In zh, this message translates to:
  /// **'GitHub Issue'**
  String get githubIssueTitle;

  /// No description provided for @githubIssueSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'打开仓库 Issue 页面，可提交问题、建议或查看已有反馈记录。'**
  String get githubIssueSubtitle;

  /// No description provided for @openIssuePage.
  ///
  /// In zh, this message translates to:
  /// **'打开 Issue 页面'**
  String get openIssuePage;

  /// No description provided for @copyAddress.
  ///
  /// In zh, this message translates to:
  /// **'复制地址'**
  String get copyAddress;

  /// No description provided for @copiedIssueAddress.
  ///
  /// In zh, this message translates to:
  /// **'已复制 Issue 地址'**
  String get copiedIssueAddress;

  /// No description provided for @copyXiaohongshuId.
  ///
  /// In zh, this message translates to:
  /// **'复制小红书号'**
  String get copyXiaohongshuId;

  /// No description provided for @copiedXiaohongshuId.
  ///
  /// In zh, this message translates to:
  /// **'已复制小红书号'**
  String get copiedXiaohongshuId;

  /// No description provided for @copyCoolapkId.
  ///
  /// In zh, this message translates to:
  /// **'复制酷安号'**
  String get copyCoolapkId;

  /// No description provided for @copiedCoolapkId.
  ///
  /// In zh, this message translates to:
  /// **'已复制酷安号'**
  String get copiedCoolapkId;

  /// No description provided for @copyQqGroupId.
  ///
  /// In zh, this message translates to:
  /// **'复制群号'**
  String get copyQqGroupId;

  /// No description provided for @copiedQqGroupId.
  ///
  /// In zh, this message translates to:
  /// **'已复制 QQ 群号'**
  String get copiedQqGroupId;

  /// No description provided for @timetableProfilesTitle.
  ///
  /// In zh, this message translates to:
  /// **'课表管理'**
  String get timetableProfilesTitle;

  /// No description provided for @createTimetableTooltip.
  ///
  /// In zh, this message translates to:
  /// **'新建课表'**
  String get createTimetableTooltip;

  /// No description provided for @coursesAndWeekSummary.
  ///
  /// In zh, this message translates to:
  /// **'{count} 门课程 · 第 {week} 周'**
  String coursesAndWeekSummary(int count, int week);

  /// No description provided for @moreActionsTooltip.
  ///
  /// In zh, this message translates to:
  /// **'更多操作'**
  String get moreActionsTooltip;

  /// No description provided for @switchToThisTimetable.
  ///
  /// In zh, this message translates to:
  /// **'切换到此课表'**
  String get switchToThisTimetable;

  /// No description provided for @renameAction.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get renameAction;

  /// No description provided for @duplicateAction.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get duplicateAction;

  /// No description provided for @clearCoursesAction.
  ///
  /// In zh, this message translates to:
  /// **'清空课程'**
  String get clearCoursesAction;

  /// No description provided for @usingNow.
  ///
  /// In zh, this message translates to:
  /// **'正在使用'**
  String get usingNow;

  /// No description provided for @switchedToProfile.
  ///
  /// In zh, this message translates to:
  /// **'已切换到 {name}'**
  String switchedToProfile(String name);

  /// No description provided for @createTimetableTitle.
  ///
  /// In zh, this message translates to:
  /// **'新建课表'**
  String get createTimetableTitle;

  /// No description provided for @timetableNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'课表名称'**
  String get timetableNameLabel;

  /// No description provided for @timetableNameHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：大二下'**
  String get timetableNameHint;

  /// No description provided for @createAction.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get createAction;

  /// No description provided for @createdProfile.
  ///
  /// In zh, this message translates to:
  /// **'已创建课表：{name}'**
  String createdProfile(String name);

  /// No description provided for @renameTimetableTitle.
  ///
  /// In zh, this message translates to:
  /// **'重命名课表'**
  String get renameTimetableTitle;

  /// No description provided for @saveAction.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get saveAction;

  /// No description provided for @renamedProfile.
  ///
  /// In zh, this message translates to:
  /// **'已重命名为 {name}'**
  String renamedProfile(String name);

  /// No description provided for @clearCurrentTimetableTitle.
  ///
  /// In zh, this message translates to:
  /// **'清空当前课表'**
  String get clearCurrentTimetableTitle;

  /// No description provided for @clearCurrentTimetableMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定清空“{name}”的全部课程吗？课表设置会保留。'**
  String clearCurrentTimetableMessage(String name);

  /// No description provided for @clearAction.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get clearAction;

  /// No description provided for @clearedProfile.
  ///
  /// In zh, this message translates to:
  /// **'已清空课表：{name}'**
  String clearedProfile(String name);

  /// No description provided for @noCoursesInCurrentProfile.
  ///
  /// In zh, this message translates to:
  /// **'当前课表已经没有课程'**
  String get noCoursesInCurrentProfile;

  /// No description provided for @deleteTimetableTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除课表'**
  String get deleteTimetableTitle;

  /// No description provided for @deleteTimetableMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定删除“{name}”吗？'**
  String deleteTimetableMessage(String name);

  /// No description provided for @deletedProfile.
  ///
  /// In zh, this message translates to:
  /// **'已删除课表：{name}'**
  String deletedProfile(String name);

  /// No description provided for @keepAtLeastOneProfile.
  ///
  /// In zh, this message translates to:
  /// **'至少保留一个课表'**
  String get keepAtLeastOneProfile;

  /// No description provided for @dataTransferTitle.
  ///
  /// In zh, this message translates to:
  /// **'数据备份与迁移'**
  String get dataTransferTitle;

  /// No description provided for @fullExportTitle.
  ///
  /// In zh, this message translates to:
  /// **'完整导出'**
  String get fullExportTitle;

  /// No description provided for @fullExportSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'支持导出当前课表，或一次导出全部课表、时间模板和当前选中状态。'**
  String get fullExportSubtitle;

  /// No description provided for @exportCurrentTimetable.
  ///
  /// In zh, this message translates to:
  /// **'导出当前课表'**
  String get exportCurrentTimetable;

  /// No description provided for @exportAllData.
  ///
  /// In zh, this message translates to:
  /// **'导出全部数据'**
  String get exportAllData;

  /// No description provided for @fullImportTitle.
  ///
  /// In zh, this message translates to:
  /// **'完整导入'**
  String get fullImportTitle;

  /// No description provided for @fullImportSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'导入时可以选择覆盖当前课表，或直接导入为一个新课表。建议先导出自己的备份。'**
  String get fullImportSubtitle;

  /// No description provided for @chooseFileAndImport.
  ///
  /// In zh, this message translates to:
  /// **'选择文件并导入'**
  String get chooseFileAndImport;

  /// No description provided for @transferOverviewTitle.
  ///
  /// In zh, this message translates to:
  /// **'当前可迁移内容'**
  String get transferOverviewTitle;

  /// No description provided for @courseCountBullet.
  ///
  /// In zh, this message translates to:
  /// **'课程数量：{count} 门'**
  String courseCountBullet(int count);

  /// No description provided for @currentTimetableBullet.
  ///
  /// In zh, this message translates to:
  /// **'当前课表：{name}'**
  String currentTimetableBullet(String name);

  /// No description provided for @allTimetablesBullet.
  ///
  /// In zh, this message translates to:
  /// **'全部课表：{count} 个'**
  String allTimetablesBullet(int count);

  /// No description provided for @timeSchemeCountBullet.
  ///
  /// In zh, this message translates to:
  /// **'时间模板：{count} 套'**
  String timeSchemeCountBullet(int count);

  /// No description provided for @currentWeekBullet.
  ///
  /// In zh, this message translates to:
  /// **'当前周：第 {week} 周'**
  String currentWeekBullet(int week);

  /// No description provided for @semesterStartUnsetBullet.
  ///
  /// In zh, this message translates to:
  /// **'开学日期：未设置'**
  String get semesterStartUnsetBullet;

  /// No description provided for @semesterStartBullet.
  ///
  /// In zh, this message translates to:
  /// **'开学日期：{date}'**
  String semesterStartBullet(String date);

  /// No description provided for @fileExtensionBullet.
  ///
  /// In zh, this message translates to:
  /// **'文件后缀：.{extension}'**
  String fileExtensionBullet(String extension);

  /// No description provided for @selectImportModeTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择导入方式'**
  String get selectImportModeTitle;

  /// No description provided for @selectImportModeMessage.
  ///
  /// In zh, this message translates to:
  /// **'你可以覆盖当前课表，或者把备份导入成一个新的独立课表。'**
  String get selectImportModeMessage;

  /// No description provided for @replaceCurrentTimetable.
  ///
  /// In zh, this message translates to:
  /// **'覆盖当前课表'**
  String get replaceCurrentTimetable;

  /// No description provided for @importAsNewTimetable.
  ///
  /// In zh, this message translates to:
  /// **'导入为新课表'**
  String get importAsNewTimetable;

  /// No description provided for @createdNewTimetableAfterImport.
  ///
  /// In zh, this message translates to:
  /// **'导入成功，已创建新的课表'**
  String get createdNewTimetableAfterImport;

  /// No description provided for @backupRestoredSuccess.
  ///
  /// In zh, this message translates to:
  /// **'导入成功，备份数据已恢复'**
  String get backupRestoredSuccess;

  /// No description provided for @importFailedInvalidFile.
  ///
  /// In zh, this message translates to:
  /// **'导入失败，请确认文件有效'**
  String get importFailedInvalidFile;

  /// No description provided for @welcomeTitle.
  ///
  /// In zh, this message translates to:
  /// **'欢迎使用'**
  String get welcomeTitle;

  /// No description provided for @welcomeAppName.
  ///
  /// In zh, this message translates to:
  /// **'轻屿课表'**
  String get welcomeAppName;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'你可以先开始使用，也可以直接导入课程或从备份恢复。'**
  String get welcomeSubtitle;

  /// No description provided for @startUsingTitle.
  ///
  /// In zh, this message translates to:
  /// **'开始使用'**
  String get startUsingTitle;

  /// No description provided for @startUsingSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'直接进入软件，并继续完成首次使用说明'**
  String get startUsingSubtitle;

  /// No description provided for @importTimetableTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入课表'**
  String get importTimetableTitle;

  /// No description provided for @importTimetableSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'从 .ics 文件或 AI 解析结果导入课程'**
  String get importTimetableSubtitle;

  /// No description provided for @restoreBackupTitle.
  ///
  /// In zh, this message translates to:
  /// **'从备份恢复'**
  String get restoreBackupTitle;

  /// No description provided for @restoreBackupSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'从 .mikcb 备份文件恢复旧数据'**
  String get restoreBackupSubtitle;

  /// No description provided for @viewGuideTitle.
  ///
  /// In zh, this message translates to:
  /// **'查看功能说明'**
  String get viewGuideTitle;

  /// No description provided for @viewGuideSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'先了解权限、超级岛和基础设置'**
  String get viewGuideSubtitle;

  /// No description provided for @migrationTitle.
  ///
  /// In zh, this message translates to:
  /// **'迁移旧数据'**
  String get migrationTitle;

  /// No description provided for @migrationSafeTitle.
  ///
  /// In zh, this message translates to:
  /// **'别担心，这不是数据丢失'**
  String get migrationSafeTitle;

  /// No description provided for @migrationSafeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'我们更换了应用包名，所以桌面上会暂时出现两个应用图标，这是正常现象。旧数据仍在旧版应用里，请先去旧版备份，再回到新版导入。'**
  String get migrationSafeSubtitle;

  /// No description provided for @migrationStep1Title.
  ///
  /// In zh, this message translates to:
  /// **'打开旧版应用'**
  String get migrationStep1Title;

  /// No description provided for @migrationStep1Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'进入“数据备份与迁移”页面后，请点“导出全部数据”。不要点“导出当前课表”，也不要先卸载旧版。'**
  String get migrationStep1Subtitle;

  /// No description provided for @migrationStep2Title.
  ///
  /// In zh, this message translates to:
  /// **'保存备份文件'**
  String get migrationStep2Title;

  /// No description provided for @migrationStep2Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'旧版导出后会弹出系统分享面板。优先选择“保存到文件”，建议存到 下载 / Download 文件夹。'**
  String get migrationStep2Subtitle;

  /// No description provided for @migrationStep3Title.
  ///
  /// In zh, this message translates to:
  /// **'回到当前版本导入'**
  String get migrationStep3Title;

  /// No description provided for @migrationStep3Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'回到新版后，通过系统文件选择器到 下载 / Download 文件夹选中 .mikcb 备份文件即可恢复。确认新版数据正常后，再卸载旧版应用。'**
  String get migrationStep3Subtitle;

  /// No description provided for @migrationNoSaveToFilesTitle.
  ///
  /// In zh, this message translates to:
  /// **'如果没有“保存到文件”'**
  String get migrationNoSaveToFilesTitle;

  /// No description provided for @migrationNoSaveToFilesSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'可以先分享到微信任意一个聊天，然后在微信里点开这个备份文件并保存。保存后通常会出现在 Download / WeiXin 文件夹里，再回到新版选择这个 .mikcb 文件导入。'**
  String get migrationNoSaveToFilesSubtitle;

  /// No description provided for @openingOldApp.
  ///
  /// In zh, this message translates to:
  /// **'正在打开旧版...'**
  String get openingOldApp;

  /// No description provided for @openOldAppForBackup.
  ///
  /// In zh, this message translates to:
  /// **'打开旧版去备份'**
  String get openOldAppForBackup;

  /// No description provided for @backupDoneGoImport.
  ///
  /// In zh, this message translates to:
  /// **'我已完成备份，去导入'**
  String get backupDoneGoImport;

  /// No description provided for @startFreshWithoutMigration.
  ///
  /// In zh, this message translates to:
  /// **'以全新应用开始，不迁移'**
  String get startFreshWithoutMigration;

  /// No description provided for @openOldAppFailed.
  ///
  /// In zh, this message translates to:
  /// **'未能打开旧版应用，请手动返回桌面打开旧版'**
  String get openOldAppFailed;

  /// No description provided for @supportCreatorTitle.
  ///
  /// In zh, this message translates to:
  /// **'请作者喝杯咖啡'**
  String get supportCreatorTitle;

  /// No description provided for @supportHeroTitle.
  ///
  /// In zh, this message translates to:
  /// **'支持轻屿课表继续更新'**
  String get supportHeroTitle;

  /// No description provided for @supportHeroSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'你的支持会直接用于维护课表、教务导入适配与体验优化。'**
  String get supportHeroSubtitle;

  /// No description provided for @supportChipFixes.
  ///
  /// In zh, this message translates to:
  /// **'修复问题'**
  String get supportChipFixes;

  /// No description provided for @supportChipAdapters.
  ///
  /// In zh, this message translates to:
  /// **'教务适配'**
  String get supportChipAdapters;

  /// No description provided for @supportChipPolish.
  ///
  /// In zh, this message translates to:
  /// **'体验优化'**
  String get supportChipPolish;

  /// No description provided for @supportMethodTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择支持方式'**
  String get supportMethodTitle;

  /// No description provided for @wechatLabel.
  ///
  /// In zh, this message translates to:
  /// **'微信'**
  String get wechatLabel;

  /// No description provided for @alipayLabel.
  ///
  /// In zh, this message translates to:
  /// **'支付宝'**
  String get alipayLabel;

  /// No description provided for @supportWeChatHint.
  ///
  /// In zh, this message translates to:
  /// **'使用微信扫一扫支持作者'**
  String get supportWeChatHint;

  /// No description provided for @supportAlipayHint.
  ///
  /// In zh, this message translates to:
  /// **'使用支付宝扫一扫支持作者'**
  String get supportAlipayHint;

  /// No description provided for @viewLargeImage.
  ///
  /// In zh, this message translates to:
  /// **'查看大图'**
  String get viewLargeImage;

  /// No description provided for @saveToGallery.
  ///
  /// In zh, this message translates to:
  /// **'保存到相册'**
  String get saveToGallery;

  /// No description provided for @supportCompleteThanks.
  ///
  /// In zh, this message translates to:
  /// **'感谢你支持轻屿课表继续打磨 ❤️'**
  String get supportCompleteThanks;

  /// No description provided for @supportConfirmed.
  ///
  /// In zh, this message translates to:
  /// **'我已经支持了'**
  String get supportConfirmed;

  /// No description provided for @donorListTitle.
  ///
  /// In zh, this message translates to:
  /// **'鸣谢名单'**
  String get donorListTitle;

  /// No description provided for @donorListLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'暂时无法加载在线鸣谢名单。'**
  String get donorListLoadFailed;

  /// No description provided for @reloadAction.
  ///
  /// In zh, this message translates to:
  /// **'重新加载'**
  String get reloadAction;

  /// No description provided for @updatedAtLabel.
  ///
  /// In zh, this message translates to:
  /// **'更新于 {time}'**
  String updatedAtLabel(String time);

  /// No description provided for @donorListEmpty.
  ///
  /// In zh, this message translates to:
  /// **'名单还没有填写，你可以直接编辑 docs/donors.json 后重新发布。'**
  String get donorListEmpty;

  /// No description provided for @savedToGallery.
  ///
  /// In zh, this message translates to:
  /// **'已保存到相册'**
  String get savedToGallery;

  /// No description provided for @saveToGalleryFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存到相册失败'**
  String get saveToGalleryFailed;

  /// No description provided for @saveFailedWithError.
  ///
  /// In zh, this message translates to:
  /// **'保存失败：{error}'**
  String saveFailedWithError(String error);

  /// No description provided for @courseOverviewTitle.
  ///
  /// In zh, this message translates to:
  /// **'课程总览与编辑'**
  String get courseOverviewTitle;

  /// No description provided for @addNewCourseTooltip.
  ///
  /// In zh, this message translates to:
  /// **'添加新课程'**
  String get addNewCourseTooltip;

  /// No description provided for @emptyCourseOverviewHint.
  ///
  /// In zh, this message translates to:
  /// **'长按课表或点击右上角添加课程'**
  String get emptyCourseOverviewHint;

  /// No description provided for @conflictDetectedMessage.
  ///
  /// In zh, this message translates to:
  /// **'检测到 {count} 门排课存在实际冲突，课程列表已标记冲突项。'**
  String conflictDetectedMessage(int count);

  /// No description provided for @conflictCountLabel.
  ///
  /// In zh, this message translates to:
  /// **'冲突 {count} 节'**
  String conflictCountLabel(int count);

  /// No description provided for @scheduledCountLabel.
  ///
  /// In zh, this message translates to:
  /// **'共排课 {count} 节'**
  String scheduledCountLabel(int count);

  /// No description provided for @scheduledCountWithConflictHint.
  ///
  /// In zh, this message translates to:
  /// **'共排课 {count} 节 · 展开查看冲突详情'**
  String scheduledCountWithConflictHint(int count);

  /// No description provided for @courseTimeSummary.
  ///
  /// In zh, this message translates to:
  /// **'时间: 星期{day} 第{start}-{end}节'**
  String courseTimeSummary(int day, int start, int end);

  /// No description provided for @teacherUnset.
  ///
  /// In zh, this message translates to:
  /// **'未置'**
  String get teacherUnset;

  /// No description provided for @locationUnset.
  ///
  /// In zh, this message translates to:
  /// **'未置'**
  String get locationUnset;

  /// No description provided for @courseDetailSummary.
  ///
  /// In zh, this message translates to:
  /// **'{weekDescription}  教师: {teacher}  教室: {location}'**
  String courseDetailSummary(
    String weekDescription,
    String teacher,
    String location,
  );

  /// No description provided for @courseDetailSummaryWithConflict.
  ///
  /// In zh, this message translates to:
  /// **'{weekDescription}  教师: {teacher}  教室: {location}\n冲突课程: {conflictSummary}'**
  String courseDetailSummaryWithConflict(
    String weekDescription,
    String teacher,
    String location,
    String conflictSummary,
  );

  /// No description provided for @confirmDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认删除'**
  String get confirmDeleteTitle;

  /// No description provided for @confirmDeleteCourseMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除课程“{name}”吗？'**
  String confirmDeleteCourseMessage(String name);

  /// No description provided for @currentScheduleTitle.
  ///
  /// In zh, this message translates to:
  /// **'当前排课'**
  String get currentScheduleTitle;

  /// No description provided for @currentScheduleSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'这里的星期、节次、教室、周次和单双周只影响当前这一条排课。'**
  String get currentScheduleSubtitle;

  /// No description provided for @timeSchemeLabel.
  ///
  /// In zh, this message translates to:
  /// **'上课时间方案'**
  String get timeSchemeLabel;

  /// No description provided for @followCurrentTimetableWithName.
  ///
  /// In zh, this message translates to:
  /// **'跟随当前课表（{name}）'**
  String followCurrentTimetableWithName(String name);

  /// No description provided for @followCurrentTimetableDescription.
  ///
  /// In zh, this message translates to:
  /// **'默认跟随当前课表主时间模板，适合大多数课程。'**
  String get followCurrentTimetableDescription;

  /// No description provided for @overrideTimeSchemeDescription.
  ///
  /// In zh, this message translates to:
  /// **'这门课会单独使用所选时间模板，不跟随当前课表主时间模板。'**
  String get overrideTimeSchemeDescription;

  /// No description provided for @weekdayLabel.
  ///
  /// In zh, this message translates to:
  /// **'星期'**
  String get weekdayLabel;

  /// No description provided for @startSectionLabel.
  ///
  /// In zh, this message translates to:
  /// **'开始节次'**
  String get startSectionLabel;

  /// No description provided for @endSectionLabel.
  ///
  /// In zh, this message translates to:
  /// **'结束节次'**
  String get endSectionLabel;

  /// No description provided for @timeRangeLabel.
  ///
  /// In zh, this message translates to:
  /// **'时间: {start} - {end}'**
  String timeRangeLabel(String start, String end);

  /// No description provided for @locationLabel.
  ///
  /// In zh, this message translates to:
  /// **'上课地点'**
  String get locationLabel;

  /// No description provided for @singleLessonWeekTitle.
  ///
  /// In zh, this message translates to:
  /// **'上课周次'**
  String get singleLessonWeekTitle;

  /// No description provided for @singleLessonWeekSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'单节课只会出现在一个周次里，适合补课、临时加课。'**
  String get singleLessonWeekSubtitle;

  /// No description provided for @selectWeekLabel.
  ///
  /// In zh, this message translates to:
  /// **'选择周次'**
  String get selectWeekLabel;

  /// No description provided for @weekSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'周次设置'**
  String get weekSettingsTitle;

  /// No description provided for @rangeWeeksLabel.
  ///
  /// In zh, this message translates to:
  /// **'连续周'**
  String get rangeWeeksLabel;

  /// No description provided for @customWeeksLabel.
  ///
  /// In zh, this message translates to:
  /// **'自定义周'**
  String get customWeeksLabel;

  /// No description provided for @startWeekLabel.
  ///
  /// In zh, this message translates to:
  /// **'开始周'**
  String get startWeekLabel;

  /// No description provided for @endWeekLabel.
  ///
  /// In zh, this message translates to:
  /// **'结束周'**
  String get endWeekLabel;

  /// No description provided for @allWeeksFilter.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get allWeeksFilter;

  /// No description provided for @oddWeeksFilter.
  ///
  /// In zh, this message translates to:
  /// **'单周'**
  String get oddWeeksFilter;

  /// No description provided for @evenWeeksFilter.
  ///
  /// In zh, this message translates to:
  /// **'双周'**
  String get evenWeeksFilter;

  /// No description provided for @rangeWeeksAllHint.
  ///
  /// In zh, this message translates to:
  /// **'按开始周到结束周连续排课。'**
  String get rangeWeeksAllHint;

  /// No description provided for @rangeWeeksOddHint.
  ///
  /// In zh, this message translates to:
  /// **'只保留范围内的单周。'**
  String get rangeWeeksOddHint;

  /// No description provided for @rangeWeeksEvenHint.
  ///
  /// In zh, this message translates to:
  /// **'只保留范围内的双周。'**
  String get rangeWeeksEvenHint;

  /// No description provided for @selectAllAction.
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get selectAllAction;

  /// No description provided for @selectOddWeeksAction.
  ///
  /// In zh, this message translates to:
  /// **'单周'**
  String get selectOddWeeksAction;

  /// No description provided for @selectEvenWeeksAction.
  ///
  /// In zh, this message translates to:
  /// **'双周'**
  String get selectEvenWeeksAction;

  /// No description provided for @selectedWeeksSummary.
  ///
  /// In zh, this message translates to:
  /// **'已选 {count} 周：第{weeks}周'**
  String selectedWeeksSummary(int count, String weeks);

  /// No description provided for @courseColorTitle.
  ///
  /// In zh, this message translates to:
  /// **'课程颜色'**
  String get courseColorTitle;

  /// No description provided for @customPaletteAction.
  ///
  /// In zh, this message translates to:
  /// **'调色盘自定义颜色'**
  String get customPaletteAction;

  /// No description provided for @colorPaletteTitle.
  ///
  /// In zh, this message translates to:
  /// **'调色盘'**
  String get colorPaletteTitle;

  /// No description provided for @colorHexLabel.
  ///
  /// In zh, this message translates to:
  /// **'颜色 Hex'**
  String get colorHexLabel;

  /// No description provided for @weekdayMon.
  ///
  /// In zh, this message translates to:
  /// **'周一'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In zh, this message translates to:
  /// **'周二'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In zh, this message translates to:
  /// **'周三'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In zh, this message translates to:
  /// **'周四'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In zh, this message translates to:
  /// **'周五'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In zh, this message translates to:
  /// **'周六'**
  String get weekdaySat;

  /// No description provided for @weekdaySun.
  ///
  /// In zh, this message translates to:
  /// **'周日'**
  String get weekdaySun;

  /// No description provided for @hueLabel.
  ///
  /// In zh, this message translates to:
  /// **'色相 {value}'**
  String hueLabel(int value);

  /// No description provided for @saturationLabel.
  ///
  /// In zh, this message translates to:
  /// **'饱和度 {value}%'**
  String saturationLabel(int value);

  /// No description provided for @brightnessLabel.
  ///
  /// In zh, this message translates to:
  /// **'明度 {value}%'**
  String brightnessLabel(int value);

  /// No description provided for @useThisColor.
  ///
  /// In zh, this message translates to:
  /// **'使用这个颜色'**
  String get useThisColor;

  /// No description provided for @selectAtLeastOneWeek.
  ///
  /// In zh, this message translates to:
  /// **'请至少选择一个上课周次'**
  String get selectAtLeastOneWeek;

  /// No description provided for @saveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败'**
  String get saveFailed;

  /// No description provided for @courseAddedSuccess.
  ///
  /// In zh, this message translates to:
  /// **'课程添加成功'**
  String get courseAddedSuccess;

  /// No description provided for @courseUpdatedSuccess.
  ///
  /// In zh, this message translates to:
  /// **'课程更新成功'**
  String get courseUpdatedSuccess;

  /// No description provided for @aboutTitle.
  ///
  /// In zh, this message translates to:
  /// **'关于软件'**
  String get aboutTitle;

  /// No description provided for @loadingText.
  ///
  /// In zh, this message translates to:
  /// **'读取中'**
  String get loadingText;

  /// No description provided for @versionLabel.
  ///
  /// In zh, this message translates to:
  /// **'版本 {version}'**
  String versionLabel(String version);

  /// No description provided for @aboutHeroSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'一个围绕课表查看、课程提醒和 HyperOS 超级岛体验打磨的 Android 开源项目。'**
  String get aboutHeroSubtitle;

  /// No description provided for @platformLabel.
  ///
  /// In zh, this message translates to:
  /// **'平台'**
  String get platformLabel;

  /// No description provided for @focusLabel.
  ///
  /// In zh, this message translates to:
  /// **'重点'**
  String get focusLabel;

  /// No description provided for @updateLabel.
  ///
  /// In zh, this message translates to:
  /// **'更新'**
  String get updateLabel;

  /// No description provided for @prereleaseIncluded.
  ///
  /// In zh, this message translates to:
  /// **'含预发布'**
  String get prereleaseIncluded;

  /// No description provided for @stableOnly.
  ///
  /// In zh, this message translates to:
  /// **'正式版'**
  String get stableOnly;

  /// No description provided for @aboutUpdatesTitle.
  ///
  /// In zh, this message translates to:
  /// **'版本更新'**
  String get aboutUpdatesTitle;

  /// No description provided for @aboutUpdatesSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'检查更新、立即下载，以及测试与诊断入口'**
  String get aboutUpdatesSubtitle;

  /// No description provided for @aboutChangelogTitle.
  ///
  /// In zh, this message translates to:
  /// **'更新日志'**
  String get aboutChangelogTitle;

  /// No description provided for @aboutChangelogSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'查看所有版本的更新内容'**
  String get aboutChangelogSubtitle;

  /// No description provided for @aboutPositioningTitle.
  ///
  /// In zh, this message translates to:
  /// **'项目定位'**
  String get aboutPositioningTitle;

  /// No description provided for @aboutPositioningSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'这是什么、适合谁、核心能力是什么'**
  String get aboutPositioningSubtitle;

  /// No description provided for @aboutPositioningBullet1.
  ///
  /// In zh, this message translates to:
  /// **'支持周视图课表、课程增删改、.ics 导入'**
  String get aboutPositioningBullet1;

  /// No description provided for @aboutPositioningBullet2.
  ///
  /// In zh, this message translates to:
  /// **'已支持适配学校的教务系统网页登录导入与完整备份迁移'**
  String get aboutPositioningBullet2;

  /// No description provided for @aboutPositioningBullet3.
  ///
  /// In zh, this message translates to:
  /// **'支持实时通知；HyperOS 3.0.300 起支持超级岛 / 焦点通知展示'**
  String get aboutPositioningBullet3;

  /// No description provided for @aboutPositioningBullet4.
  ///
  /// In zh, this message translates to:
  /// **'支持多课表、时间模板、主题色和卡片样式自定义'**
  String get aboutPositioningBullet4;

  /// No description provided for @aboutImportMigrationTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入与迁移'**
  String get aboutImportMigrationTitle;

  /// No description provided for @aboutImportMigrationSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'当前导入方式、备份恢复和迁移建议'**
  String get aboutImportMigrationSubtitle;

  /// No description provided for @aboutImportMigrationBullet1.
  ///
  /// In zh, this message translates to:
  /// **'当前版本已经支持适配学校的教务系统网页登录导入；进入“导入课程 > 教务系统导入”后选择学校和适配器即可。'**
  String get aboutImportMigrationBullet1;

  /// No description provided for @aboutImportMigrationBullet2.
  ///
  /// In zh, this message translates to:
  /// **'如果你的学校暂时还没适配，仍然可以先在 WakeUp 等课表应用里导入课程，再导出为日历格式，然后在本应用导入。'**
  String get aboutImportMigrationBullet2;

  /// No description provided for @aboutImportMigrationBullet3.
  ///
  /// In zh, this message translates to:
  /// **'如果其他人已经在用本应用，也可以直接让对方导出完整备份文件，你在“数据备份与迁移”里导入即可直接恢复。'**
  String get aboutImportMigrationBullet3;

  /// No description provided for @aboutImportMigrationBullet4.
  ///
  /// In zh, this message translates to:
  /// **'如果你会抓包、网页调试或 JavaScript，也欢迎去 qingyu_warehouse 参与教务适配补充。'**
  String get aboutImportMigrationBullet4;

  /// No description provided for @aboutContributorsTitle.
  ///
  /// In zh, this message translates to:
  /// **'代码贡献者'**
  String get aboutContributorsTitle;

  /// No description provided for @aboutContributorsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'开发人员与教务导入适配者名单'**
  String get aboutContributorsSubtitle;

  /// No description provided for @aboutRepositoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'开源仓库'**
  String get aboutRepositoryTitle;

  /// No description provided for @aboutAppLogsTitle.
  ///
  /// In zh, this message translates to:
  /// **'应用日志'**
  String get aboutAppLogsTitle;

  /// No description provided for @aboutAppLogsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'查看整个软件的 error / warn / info / debug / verbose 全等级日志'**
  String get aboutAppLogsSubtitle;

  /// No description provided for @appLogsShareText.
  ///
  /// In zh, this message translates to:
  /// **'这是轻屿课表导出的应用日志，包含整个软件的本地运行记录，可用于排查更新、导入、通知、页面和崩溃问题。'**
  String get appLogsShareText;

  /// No description provided for @appLogsShareSubject.
  ///
  /// In zh, this message translates to:
  /// **'轻屿课表 - 应用日志'**
  String get appLogsShareSubject;

  /// No description provided for @appLogsRecordingEnabled.
  ///
  /// In zh, this message translates to:
  /// **'正在记录应用日志'**
  String get appLogsRecordingEnabled;

  /// No description provided for @appLogsRecordingDisabled.
  ///
  /// In zh, this message translates to:
  /// **'应用日志记录已关闭'**
  String get appLogsRecordingDisabled;

  /// No description provided for @appLogsCopyAction.
  ///
  /// In zh, this message translates to:
  /// **'复制日志'**
  String get appLogsCopyAction;

  /// No description provided for @appLogsCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制当前日志'**
  String get appLogsCopied;

  /// No description provided for @appLogsExportAction.
  ///
  /// In zh, this message translates to:
  /// **'导出日志'**
  String get appLogsExportAction;

  /// No description provided for @appLogsClearAction.
  ///
  /// In zh, this message translates to:
  /// **'清空日志'**
  String get appLogsClearAction;

  /// No description provided for @appLogsCleared.
  ///
  /// In zh, this message translates to:
  /// **'已清空应用日志'**
  String get appLogsCleared;

  /// No description provided for @appLogsClearFailed.
  ///
  /// In zh, this message translates to:
  /// **'清空应用日志失败'**
  String get appLogsClearFailed;

  /// No description provided for @aboutRepositorySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'GitHub 仓库地址、源码、Release 和反馈入口'**
  String get aboutRepositorySubtitle;

  /// No description provided for @timeSchemeTitle.
  ///
  /// In zh, this message translates to:
  /// **'时间模板'**
  String get timeSchemeTitle;

  /// No description provided for @newSchemeTooltip.
  ///
  /// In zh, this message translates to:
  /// **'新建模板'**
  String get newSchemeTooltip;

  /// No description provided for @timeSchemeSummary.
  ///
  /// In zh, this message translates to:
  /// **'{sections} 节 · {profiles} 个课表 · {courses} 节课程 · {overrideCourses} 节副时间表'**
  String timeSchemeSummary(
    int sections,
    int profiles,
    int courses,
    int overrideCourses,
  );

  /// No description provided for @viewUsageAction.
  ///
  /// In zh, this message translates to:
  /// **'查看使用情况'**
  String get viewUsageAction;

  /// No description provided for @applyToCurrentTimetable.
  ///
  /// In zh, this message translates to:
  /// **'应用到当前课表'**
  String get applyToCurrentTimetable;

  /// No description provided for @editSectionsAction.
  ///
  /// In zh, this message translates to:
  /// **'编辑节次'**
  String get editSectionsAction;

  /// No description provided for @createTimeSchemeTitle.
  ///
  /// In zh, this message translates to:
  /// **'新建时间模板'**
  String get createTimeSchemeTitle;

  /// No description provided for @timeSchemeNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'模板名称'**
  String get timeSchemeNameLabel;

  /// No description provided for @timeSchemeNameHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：本校夏季作息'**
  String get timeSchemeNameHint;

  /// No description provided for @renameTimeSchemeTitle.
  ///
  /// In zh, this message translates to:
  /// **'重命名时间模板'**
  String get renameTimeSchemeTitle;

  /// No description provided for @renamedToMessage.
  ///
  /// In zh, this message translates to:
  /// **'已重命名为 {name}'**
  String renamedToMessage(String name);

  /// No description provided for @deleteTimeSchemeTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除时间模板'**
  String get deleteTimeSchemeTitle;

  /// No description provided for @deleteTimeSchemeMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定删除“{name}”吗？正在使用中的模板不能删除。'**
  String deleteTimeSchemeMessage(String name);

  /// No description provided for @deletedTimeSchemeMessage.
  ///
  /// In zh, this message translates to:
  /// **'已删除时间模板：{name}'**
  String deletedTimeSchemeMessage(String name);

  /// No description provided for @timeSchemeInUseMessage.
  ///
  /// In zh, this message translates to:
  /// **'该模板正在被课表使用'**
  String get timeSchemeInUseMessage;

  /// No description provided for @copiedTimeSchemeMessage.
  ///
  /// In zh, this message translates to:
  /// **'已复制时间模板'**
  String get copiedTimeSchemeMessage;

  /// No description provided for @appliedTimeSchemeMessage.
  ///
  /// In zh, this message translates to:
  /// **'已应用时间模板：{name}'**
  String appliedTimeSchemeMessage(String name);

  /// No description provided for @timeSchemeUsageTitle.
  ///
  /// In zh, this message translates to:
  /// **'“{name}”的使用情况'**
  String timeSchemeUsageTitle(String name);

  /// No description provided for @timeSchemeUsageIntro.
  ///
  /// In zh, this message translates to:
  /// **'先看总影响范围，再决定是直接编辑这套模板，还是先复制一套再改。'**
  String get timeSchemeUsageIntro;

  /// No description provided for @profileCountLabel.
  ///
  /// In zh, this message translates to:
  /// **'课表'**
  String get profileCountLabel;

  /// No description provided for @courseCountLabel.
  ///
  /// In zh, this message translates to:
  /// **'课程'**
  String get courseCountLabel;

  /// No description provided for @overrideTimeSchemeLabel.
  ///
  /// In zh, this message translates to:
  /// **'副时间表'**
  String get overrideTimeSchemeLabel;

  /// No description provided for @directlyBoundProfilesTitle.
  ///
  /// In zh, this message translates to:
  /// **'直接绑定这套模板的课表'**
  String get directlyBoundProfilesTitle;

  /// No description provided for @directlyBoundProfilesEmpty.
  ///
  /// In zh, this message translates to:
  /// **'当前没有课表直接使用这套模板。'**
  String get directlyBoundProfilesEmpty;

  /// No description provided for @directlyBoundProfilesSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'这些课表切到这套模板后，默认都会按这套节次时间显示。'**
  String get directlyBoundProfilesSubtitle;

  /// No description provided for @followMainSchemeCoursesTitle.
  ///
  /// In zh, this message translates to:
  /// **'跟随课表主时间表的课程'**
  String get followMainSchemeCoursesTitle;

  /// No description provided for @followMainSchemeCoursesEmpty.
  ///
  /// In zh, this message translates to:
  /// **'当前没有课程通过课表主时间表间接使用它。'**
  String get followMainSchemeCoursesEmpty;

  /// No description provided for @followMainSchemeCoursesSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'这些课程没有单独设置副时间表，而是跟着所属课表一起用这套模板。'**
  String get followMainSchemeCoursesSubtitle;

  /// No description provided for @overrideSchemeCoursesTitle.
  ///
  /// In zh, this message translates to:
  /// **'把它作为副时间表的课程'**
  String get overrideSchemeCoursesTitle;

  /// No description provided for @overrideSchemeCoursesEmpty.
  ///
  /// In zh, this message translates to:
  /// **'当前没有课程把它作为副时间表。'**
  String get overrideSchemeCoursesEmpty;

  /// No description provided for @overrideSchemeCoursesSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'这些课程即使所在课表切换了主模板，也会继续单独使用这套时间。'**
  String get overrideSchemeCoursesSubtitle;

  /// No description provided for @closeAction.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get closeAction;

  /// No description provided for @editTimeSchemeTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑时间模板'**
  String get editTimeSchemeTitle;

  /// No description provided for @backToSchemeList.
  ///
  /// In zh, this message translates to:
  /// **'返回模板列表'**
  String get backToSchemeList;

  /// No description provided for @currentInUse.
  ///
  /// In zh, this message translates to:
  /// **'当前使用'**
  String get currentInUse;

  /// No description provided for @quickGenerateAction.
  ///
  /// In zh, this message translates to:
  /// **'快捷生成'**
  String get quickGenerateAction;

  /// No description provided for @addSectionAction.
  ///
  /// In zh, this message translates to:
  /// **'新增一节'**
  String get addSectionAction;

  /// No description provided for @removeLastSectionAction.
  ///
  /// In zh, this message translates to:
  /// **'删除末节'**
  String get removeLastSectionAction;

  /// No description provided for @resetDefaultAction.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认'**
  String get resetDefaultAction;

  /// No description provided for @sectionTimesTitle.
  ///
  /// In zh, this message translates to:
  /// **'节次时间'**
  String get sectionTimesTitle;

  /// No description provided for @sectionTimesSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'如果当前课表正在使用这套模板，节次数量不能小于已使用的最大节次。'**
  String get sectionTimesSubtitle;

  /// No description provided for @schemeListCurrentLabel.
  ///
  /// In zh, this message translates to:
  /// **'当前'**
  String get schemeListCurrentLabel;

  /// No description provided for @schemeListCountLabel.
  ///
  /// In zh, this message translates to:
  /// **'数量'**
  String get schemeListCountLabel;

  /// No description provided for @sectionCountLabel.
  ///
  /// In zh, this message translates to:
  /// **'节数'**
  String get sectionCountLabel;

  /// No description provided for @quickGenerateTimeSchemeTitle.
  ///
  /// In zh, this message translates to:
  /// **'快捷生成课表时间'**
  String get quickGenerateTimeSchemeTitle;

  /// No description provided for @addBreakRuleAction.
  ///
  /// In zh, this message translates to:
  /// **'新增大课间规则'**
  String get addBreakRuleAction;

  /// No description provided for @afterSectionLabel.
  ///
  /// In zh, this message translates to:
  /// **'第几节后'**
  String get afterSectionLabel;

  /// No description provided for @breakDurationMinutesLabel.
  ///
  /// In zh, this message translates to:
  /// **'休息多久(分)'**
  String get breakDurationMinutesLabel;

  /// No description provided for @fillNumbersValidationMessage.
  ///
  /// In zh, this message translates to:
  /// **'请把节数和时长填写为数字'**
  String get fillNumbersValidationMessage;

  /// No description provided for @timeSchemeEditorActiveAndCoursesHint.
  ///
  /// In zh, this message translates to:
  /// **'当前课表和部分课程正在使用这套时间模板，保存后会同步更新所有相关课表和课程。'**
  String get timeSchemeEditorActiveAndCoursesHint;

  /// No description provided for @timeSchemeEditorActiveHint.
  ///
  /// In zh, this message translates to:
  /// **'当前课表正在使用这套时间模板，保存后会同步更新所有使用它的课表。'**
  String get timeSchemeEditorActiveHint;

  /// No description provided for @timeSchemeEditorOverrideHint.
  ///
  /// In zh, this message translates to:
  /// **'有课程正在把这套模板作为副时间表使用，保存后会同步更新所有引用课程。'**
  String get timeSchemeEditorOverrideHint;

  /// No description provided for @editTimeAction.
  ///
  /// In zh, this message translates to:
  /// **'编辑时间'**
  String get editTimeAction;

  /// No description provided for @editingSchemeLabel.
  ///
  /// In zh, this message translates to:
  /// **'正在编辑：{name}'**
  String editingSchemeLabel(String name);

  /// No description provided for @copiedTimeSchemeShortMessage.
  ///
  /// In zh, this message translates to:
  /// **'已复制时间模板'**
  String get copiedTimeSchemeShortMessage;

  /// No description provided for @unnamedTimeScheme.
  ///
  /// In zh, this message translates to:
  /// **'未命名模板'**
  String get unnamedTimeScheme;

  /// No description provided for @unsetLabel.
  ///
  /// In zh, this message translates to:
  /// **'未选择'**
  String get unsetLabel;

  /// No description provided for @timeSchemeUsageCourseRefPrefix.
  ///
  /// In zh, this message translates to:
  /// **'课程引用：'**
  String get timeSchemeUsageCourseRefPrefix;

  /// No description provided for @mainTimeSchemeLabel.
  ///
  /// In zh, this message translates to:
  /// **'主时间表'**
  String get mainTimeSchemeLabel;

  /// No description provided for @overrideTimeSchemeShortLabel.
  ///
  /// In zh, this message translates to:
  /// **'副时间表'**
  String get overrideTimeSchemeShortLabel;

  /// No description provided for @timeSchemeBottomUsageSingle.
  ///
  /// In zh, this message translates to:
  /// **'{first}'**
  String timeSchemeBottomUsageSingle(String first);

  /// No description provided for @timeSchemeBottomUsageMulti.
  ///
  /// In zh, this message translates to:
  /// **'{first} 等 {count} 节课程'**
  String timeSchemeBottomUsageMulti(String first, int count);

  /// No description provided for @morningSectionCountLabel.
  ///
  /// In zh, this message translates to:
  /// **'上午几节'**
  String get morningSectionCountLabel;

  /// No description provided for @morningFirstSectionTimeLabel.
  ///
  /// In zh, this message translates to:
  /// **'早上第一节时间'**
  String get morningFirstSectionTimeLabel;

  /// No description provided for @afternoonSectionCountLabel.
  ///
  /// In zh, this message translates to:
  /// **'下午几节'**
  String get afternoonSectionCountLabel;

  /// No description provided for @afternoonFirstSectionTimeLabel.
  ///
  /// In zh, this message translates to:
  /// **'下午第一节时间'**
  String get afternoonFirstSectionTimeLabel;

  /// No description provided for @eveningSectionCountLabel.
  ///
  /// In zh, this message translates to:
  /// **'晚上几节'**
  String get eveningSectionCountLabel;

  /// No description provided for @eveningFirstSectionTimeLabel.
  ///
  /// In zh, this message translates to:
  /// **'晚上第一节时间'**
  String get eveningFirstSectionTimeLabel;

  /// No description provided for @classDurationMinutesLabel.
  ///
  /// In zh, this message translates to:
  /// **'单节课时长（分钟）'**
  String get classDurationMinutesLabel;

  /// No description provided for @smallBreakDurationMinutesLabel.
  ///
  /// In zh, this message translates to:
  /// **'小课间时长（分钟）'**
  String get smallBreakDurationMinutesLabel;

  /// No description provided for @largeBreakRulesTitle.
  ///
  /// In zh, this message translates to:
  /// **'大课间规则'**
  String get largeBreakRulesTitle;

  /// No description provided for @noLargeBreakRulesHint.
  ///
  /// In zh, this message translates to:
  /// **'未设置大课间规则，将全部使用小课间时长。'**
  String get noLargeBreakRulesHint;

  /// No description provided for @deleteRuleTooltip.
  ///
  /// In zh, this message translates to:
  /// **'删除规则'**
  String get deleteRuleTooltip;

  /// No description provided for @generateAction.
  ///
  /// In zh, this message translates to:
  /// **'生成'**
  String get generateAction;

  /// No description provided for @liveSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'超级岛与通知'**
  String get liveSettingsTitle;

  /// No description provided for @liveReminderTimingEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'提醒时段'**
  String get liveReminderTimingEntryTitle;

  /// No description provided for @liveReminderTimingEntrySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'上课前、课中/下课提醒开关，以及下课前多久切到超级岛 / 重点提醒'**
  String get liveReminderTimingEntrySubtitle;

  /// No description provided for @liveBeforeClassDisplayEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'上课前提醒显示'**
  String get liveBeforeClassDisplayEntryTitle;

  /// No description provided for @liveDuringEndDisplayEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'课中/下课提醒显示'**
  String get liveDuringEndDisplayEntryTitle;

  /// No description provided for @liveKeepAliveEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'后台保活'**
  String get liveKeepAliveEntryTitle;

  /// No description provided for @liveKeepAliveEntrySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'隐藏后台、后台保活辅助服务和权限入口'**
  String get liveKeepAliveEntrySubtitle;

  /// No description provided for @liveTestingEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'测试与诊断'**
  String get liveTestingEntryTitle;

  /// No description provided for @liveTestingEntrySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'发送测试通知，检查超级岛和本地诊断日志'**
  String get liveTestingEntrySubtitle;

  /// No description provided for @followBeforeClassSetting.
  ///
  /// In zh, this message translates to:
  /// **'跟随上课前提醒'**
  String get followBeforeClassSetting;

  /// No description provided for @liveReminderTimingTitle.
  ///
  /// In zh, this message translates to:
  /// **'提醒时段'**
  String get liveReminderTimingTitle;

  /// No description provided for @liveReminderSwitchesTitle.
  ///
  /// In zh, this message translates to:
  /// **'提醒开关'**
  String get liveReminderSwitchesTitle;

  /// No description provided for @liveReminderSwitchesSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'不同提醒时段可以自由组合；这些开关互不替代。'**
  String get liveReminderSwitchesSubtitle;

  /// No description provided for @beforeClassReminderTitle.
  ///
  /// In zh, this message translates to:
  /// **'上课前提醒'**
  String get beforeClassReminderTitle;

  /// No description provided for @beforeClassReminderSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'在课程开始前 {minutes} 分钟弹出'**
  String beforeClassReminderSubtitle(int minutes);

  /// No description provided for @duringClassReminderTitle.
  ///
  /// In zh, this message translates to:
  /// **'课中 / 下课提醒'**
  String get duringClassReminderTitle;

  /// No description provided for @duringClassReminderSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'只影响上课后到下课前的展示'**
  String get duringClassReminderSubtitle;

  /// No description provided for @liveClassReminderLeadTitle.
  ///
  /// In zh, this message translates to:
  /// **'下课前多久切到超级岛 / 重点提醒'**
  String get liveClassReminderLeadTitle;

  /// No description provided for @liveClassReminderLeadOptionImmediate.
  ///
  /// In zh, this message translates to:
  /// **'一上课就切换'**
  String get liveClassReminderLeadOptionImmediate;

  /// No description provided for @liveClassReminderLeadOptionMinutes.
  ///
  /// In zh, this message translates to:
  /// **'下课前 {minutes} 分钟切换'**
  String liveClassReminderLeadOptionMinutes(int minutes);

  /// No description provided for @liveDisplayModeTitle.
  ///
  /// In zh, this message translates to:
  /// **'展示方式'**
  String get liveDisplayModeTitle;

  /// No description provided for @liveDisplayModeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'对已启用的提醒时段生效。'**
  String get liveDisplayModeSubtitle;

  /// No description provided for @duringClassStatusNotificationTitle.
  ///
  /// In zh, this message translates to:
  /// **'课中状态栏通知'**
  String get duringClassStatusNotificationTitle;

  /// No description provided for @duringClassStatusNotificationImmediate.
  ///
  /// In zh, this message translates to:
  /// **'上课后保留状态栏通知'**
  String get duringClassStatusNotificationImmediate;

  /// No description provided for @duringClassStatusNotificationBeforeEnd.
  ///
  /// In zh, this message translates to:
  /// **'在下课提醒开始前保留普通通知文案'**
  String get duringClassStatusNotificationBeforeEnd;

  /// No description provided for @duringClassStatusNotificationPersistent.
  ///
  /// In zh, this message translates to:
  /// **'上课后持续显示普通课中通知，到下课提醒前再切换'**
  String get duringClassStatusNotificationPersistent;

  /// No description provided for @enableIslandDisplayTitle.
  ///
  /// In zh, this message translates to:
  /// **'支持展示超级岛/灵动岛'**
  String get enableIslandDisplayTitle;

  /// No description provided for @enableIslandDisplaySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'关闭后不会再尝试触发系统超级岛'**
  String get enableIslandDisplaySubtitle;

  /// No description provided for @liveTimeThresholdTitle.
  ///
  /// In zh, this message translates to:
  /// **'时间阈值'**
  String get liveTimeThresholdTitle;

  /// No description provided for @liveTimeThresholdSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'控制上课前弹出、下课前多久切到超级岛 / 重点提醒，以及最后秒级倒计时。'**
  String get liveTimeThresholdSubtitle;

  /// No description provided for @beforeClassPopupLabel.
  ///
  /// In zh, this message translates to:
  /// **'上课前弹出时间'**
  String get beforeClassPopupLabel;

  /// No description provided for @beforeClassMinutesOption.
  ///
  /// In zh, this message translates to:
  /// **'{minutes} 分钟'**
  String beforeClassMinutesOption(int minutes);

  /// No description provided for @beforeEndSecondsLabel.
  ///
  /// In zh, this message translates to:
  /// **'下课前秒级提醒阈值'**
  String get beforeEndSecondsLabel;

  /// No description provided for @beforeEndSecondsOption.
  ///
  /// In zh, this message translates to:
  /// **'{seconds} 秒'**
  String beforeEndSecondsOption(int seconds);

  /// No description provided for @timeCorrectionLabel.
  ///
  /// In zh, this message translates to:
  /// **'铃声时间矫正：{value}'**
  String timeCorrectionLabel(String value);

  /// No description provided for @timeCorrectionHelp.
  ///
  /// In zh, this message translates to:
  /// **'如果学校铃声比课表快几秒，就调成提前；如果铃声慢几秒，就调成延后。'**
  String get timeCorrectionHelp;

  /// No description provided for @duringEndTimeDisplayLabel.
  ///
  /// In zh, this message translates to:
  /// **'课中 / 下课提醒时间样式'**
  String get duringEndTimeDisplayLabel;

  /// No description provided for @duringEndTimeDisplayHelp.
  ///
  /// In zh, this message translates to:
  /// **'控制紧凑提醒里显示最近时间还是整段总时间。'**
  String get duringEndTimeDisplayHelp;

  /// No description provided for @liveDisplayContentTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示内容'**
  String get liveDisplayContentTitle;

  /// No description provided for @liveDisplayContentSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'这组设置只影响当前阶段，不会改动另一组提醒显示。'**
  String get liveDisplayContentSubtitle;

  /// No description provided for @showCourseNameTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示课程名'**
  String get showCourseNameTitle;

  /// No description provided for @preferShortNameTitle.
  ///
  /// In zh, this message translates to:
  /// **'优先显示课程简称'**
  String get preferShortNameTitle;

  /// No description provided for @preferShortNameSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'建议简称控制在 3 个字以内'**
  String get preferShortNameSubtitle;

  /// No description provided for @showLocationTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示地点'**
  String get showLocationTitle;

  /// No description provided for @showCountdownTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示倒计时'**
  String get showCountdownTitle;

  /// No description provided for @countdownFormatLabel.
  ///
  /// In zh, this message translates to:
  /// **'倒计时格式'**
  String get countdownFormatLabel;

  /// No description provided for @countdownFormatHelp.
  ///
  /// In zh, this message translates to:
  /// **'纯分钟样式按分钟刷新，带秒样式按秒刷新'**
  String get countdownFormatHelp;

  /// No description provided for @showStageTextTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示阶段状态文案'**
  String get showStageTextTitle;

  /// No description provided for @showStageTextSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'关闭倒计时后，可继续显示“即将上课 / 上课中 / 下课提醒”'**
  String get showStageTextSubtitle;

  /// No description provided for @hidePrefixTextTitle.
  ///
  /// In zh, this message translates to:
  /// **'隐藏前缀文案'**
  String get hidePrefixTextTitle;

  /// No description provided for @hidePrefixTextSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'例如隐藏“即将上课”这类前缀'**
  String get hidePrefixTextSubtitle;

  /// No description provided for @beforeClassQuickActionTitle.
  ///
  /// In zh, this message translates to:
  /// **'上课前快捷操作'**
  String get beforeClassQuickActionTitle;

  /// No description provided for @beforeClassQuickActionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'只在上课前提醒的展开通知里显示。免打扰首次可能会跳到系统授权页。'**
  String get beforeClassQuickActionSubtitle;

  /// No description provided for @liveMiuiLabelSizePreview.
  ///
  /// In zh, this message translates to:
  /// **'{value}'**
  String liveMiuiLabelSizePreview(String value);

  /// No description provided for @liveIslandVisualTitle.
  ///
  /// In zh, this message translates to:
  /// **'左侧图标与展开态'**
  String get liveIslandVisualTitle;

  /// No description provided for @liveIslandVisualSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'左侧文字图、展开态大图标和自定义图片都按当前阶段单独保存。'**
  String get liveIslandVisualSubtitle;

  /// No description provided for @liveMiuiLabelImageTitle.
  ///
  /// In zh, this message translates to:
  /// **'小米岛左侧文字图标'**
  String get liveMiuiLabelImageTitle;

  /// No description provided for @liveMiuiLabelImageSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'仅小米手机样式生效，会把课程名或地点生成到左侧图标位。'**
  String get liveMiuiLabelImageSubtitle;

  /// No description provided for @liveMiuiLabelContentLabel.
  ///
  /// In zh, this message translates to:
  /// **'左侧文字内容'**
  String get liveMiuiLabelContentLabel;

  /// No description provided for @liveMiuiLabelStyleLabel.
  ///
  /// In zh, this message translates to:
  /// **'左侧图标样式'**
  String get liveMiuiLabelStyleLabel;

  /// No description provided for @liveMiuiLabelLogoTitle.
  ///
  /// In zh, this message translates to:
  /// **'左侧图标 Logo'**
  String get liveMiuiLabelLogoTitle;

  /// No description provided for @liveMiuiLabelLogoSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'仅在“图标+文字”样式下生效；未选择时继续使用应用图标。'**
  String get liveMiuiLabelLogoSubtitle;

  /// No description provided for @liveMiuiLabelLogoCornerRadiusLabel.
  ///
  /// In zh, this message translates to:
  /// **'左侧图标圆角 {value}'**
  String liveMiuiLabelLogoCornerRadiusLabel(String value);

  /// No description provided for @liveMiuiLabelFontSizeLabel.
  ///
  /// In zh, this message translates to:
  /// **'左侧文字大小 {value}'**
  String liveMiuiLabelFontSizeLabel(String value);

  /// No description provided for @liveMiuiLabelOffsetXLabel.
  ///
  /// In zh, this message translates to:
  /// **'左侧文字水平偏移 {value}'**
  String liveMiuiLabelOffsetXLabel(String value);

  /// No description provided for @liveMiuiLabelOffsetYLabel.
  ///
  /// In zh, this message translates to:
  /// **'左侧文字垂直偏移 {value}'**
  String liveMiuiLabelOffsetYLabel(String value);

  /// No description provided for @liveMiuiLabelFontWeightLabel.
  ///
  /// In zh, this message translates to:
  /// **'左侧文字粗细'**
  String get liveMiuiLabelFontWeightLabel;

  /// No description provided for @liveMiuiLabelRenderQualityLabel.
  ///
  /// In zh, this message translates to:
  /// **'左侧文字清晰度'**
  String get liveMiuiLabelRenderQualityLabel;

  /// No description provided for @liveMiuiExpandedIconLabel.
  ///
  /// In zh, this message translates to:
  /// **'展开态大图标'**
  String get liveMiuiExpandedIconLabel;

  /// No description provided for @selectImageAction.
  ///
  /// In zh, this message translates to:
  /// **'选择图片'**
  String get selectImageAction;

  /// No description provided for @replaceImageAction.
  ///
  /// In zh, this message translates to:
  /// **'更换图片'**
  String get replaceImageAction;

  /// No description provided for @liveDisplayConfigModeTitle.
  ///
  /// In zh, this message translates to:
  /// **'配置方式'**
  String get liveDisplayConfigModeTitle;

  /// No description provided for @liveDisplayConfigModeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'打开后，课中和下课提醒会完全跟随上课前提醒显示，下面的独立设置暂时不可编辑。'**
  String get liveDisplayConfigModeSubtitle;

  /// No description provided for @followBeforeClassDisplayTitle.
  ///
  /// In zh, this message translates to:
  /// **'跟随上课前提醒设置'**
  String get followBeforeClassDisplayTitle;

  /// No description provided for @liveKeepAliveTitle.
  ///
  /// In zh, this message translates to:
  /// **'后台保活'**
  String get liveKeepAliveTitle;

  /// No description provided for @liveKeepAliveOptionsTitle.
  ///
  /// In zh, this message translates to:
  /// **'保活选项'**
  String get liveKeepAliveOptionsTitle;

  /// No description provided for @liveKeepAliveOptionsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'用于提升超级岛和提醒在后台场景下的稳定性。'**
  String get liveKeepAliveOptionsSubtitle;

  /// No description provided for @hideFromRecentsTitle.
  ///
  /// In zh, this message translates to:
  /// **'从最近任务中隐藏应用'**
  String get hideFromRecentsTitle;

  /// No description provided for @hideFromRecentsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'开启后应用会尽量不显示在最近任务列表中。'**
  String get hideFromRecentsSubtitle;

  /// No description provided for @keepAliveServiceTitle.
  ///
  /// In zh, this message translates to:
  /// **'轻屿课表后台保活服务'**
  String get keepAliveServiceTitle;

  /// No description provided for @keepAliveServiceEnabledSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'当前已开启。系统会保持后台保活辅助服务处于可用状态。'**
  String get keepAliveServiceEnabledSubtitle;

  /// No description provided for @keepAliveServiceDisabledSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'当前未开启。可进入系统无障碍设置手动打开轻屿课表后台保活服务。'**
  String get keepAliveServiceDisabledSubtitle;

  /// No description provided for @goEnableAction.
  ///
  /// In zh, this message translates to:
  /// **'去开启'**
  String get goEnableAction;

  /// No description provided for @layoutEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'布局与节次'**
  String get layoutEntryTitle;

  /// No description provided for @layoutEntrySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'节次时间、行高、时间列、周末显示与卡片布局'**
  String get layoutEntrySubtitle;

  /// No description provided for @remindersSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'提醒与通知'**
  String get remindersSectionTitle;

  /// No description provided for @liveGuideEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'使用引导与权限'**
  String get liveGuideEntryTitle;

  /// No description provided for @liveGuideEntrySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'简称建议、通知、自启动、电池策略'**
  String get liveGuideEntrySubtitle;

  /// No description provided for @managementSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'课表管理'**
  String get managementSectionTitle;

  /// No description provided for @timeSchemeEntryCurrentPrefix.
  ///
  /// In zh, this message translates to:
  /// **'当前：{name} · 切换、编辑节次和复制'**
  String timeSchemeEntryCurrentPrefix(String name);

  /// No description provided for @timeSchemeEntrySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'切换、编辑节次、复制和管理时间模板'**
  String get timeSchemeEntrySubtitle;

  /// No description provided for @semesterOverviewCurrentWeek.
  ///
  /// In zh, this message translates to:
  /// **'当前第 {current} 周 / 共 {total} 周'**
  String semesterOverviewCurrentWeek(int current, int total);

  /// No description provided for @semesterStartUnset.
  ///
  /// In zh, this message translates to:
  /// **'未设置开学日期'**
  String get semesterStartUnset;

  /// No description provided for @semesterStartSet.
  ///
  /// In zh, this message translates to:
  /// **'开学日期：{date}'**
  String semesterStartSet(String date);

  /// No description provided for @setSemesterStartDate.
  ///
  /// In zh, this message translates to:
  /// **'设置开学日期'**
  String get setSemesterStartDate;

  /// No description provided for @semesterStartDateLabel.
  ///
  /// In zh, this message translates to:
  /// **'开学日期'**
  String get semesterStartDateLabel;

  /// No description provided for @syncedCurrentWeekMessage.
  ///
  /// In zh, this message translates to:
  /// **'已同步到第 {week} 周'**
  String syncedCurrentWeekMessage(int week);

  /// No description provided for @pickSemesterWeekCountTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择学期周数'**
  String get pickSemesterWeekCountTitle;

  /// No description provided for @pickSemesterWeekCountSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'不同学校可按实际教学周数调整。'**
  String get pickSemesterWeekCountSubtitle;

  /// No description provided for @weekCountItem.
  ///
  /// In zh, this message translates to:
  /// **'{count} 周'**
  String weekCountItem(int count);

  /// No description provided for @diagnosticsLogIntro.
  ///
  /// In zh, this message translates to:
  /// **'支持 Markdown 与原文两种查看方式，排查时可以直接在手机上看完整日志。'**
  String get diagnosticsLogIntro;

  /// No description provided for @diagnosticsRawTab.
  ///
  /// In zh, this message translates to:
  /// **'原文'**
  String get diagnosticsRawTab;

  /// No description provided for @diagnosticsStructuredTab.
  ///
  /// In zh, this message translates to:
  /// **'结构化'**
  String get diagnosticsStructuredTab;

  /// No description provided for @diagnosticsLevelLabel.
  ///
  /// In zh, this message translates to:
  /// **'等级'**
  String get diagnosticsLevelLabel;

  /// No description provided for @diagnosticsLevelAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get diagnosticsLevelAll;

  /// No description provided for @diagnosticsLevelError.
  ///
  /// In zh, this message translates to:
  /// **'错误'**
  String get diagnosticsLevelError;

  /// No description provided for @diagnosticsLevelWarn.
  ///
  /// In zh, this message translates to:
  /// **'警告'**
  String get diagnosticsLevelWarn;

  /// No description provided for @diagnosticsLevelInfo.
  ///
  /// In zh, this message translates to:
  /// **'信息'**
  String get diagnosticsLevelInfo;

  /// No description provided for @diagnosticsLevelDebug.
  ///
  /// In zh, this message translates to:
  /// **'调试'**
  String get diagnosticsLevelDebug;

  /// No description provided for @diagnosticsLevelVerbose.
  ///
  /// In zh, this message translates to:
  /// **'详细'**
  String get diagnosticsLevelVerbose;

  /// No description provided for @diagnosticsShowingCount.
  ///
  /// In zh, this message translates to:
  /// **'显示 {shown} / {total} 条日志'**
  String diagnosticsShowingCount(int shown, int total);

  /// No description provided for @diagnosticsNoMatchingTitle.
  ///
  /// In zh, this message translates to:
  /// **'当前筛选下没有日志'**
  String get diagnosticsNoMatchingTitle;

  /// No description provided for @diagnosticsNoMatchingSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'可以切换到“全部”，或改看原文继续排查。'**
  String get diagnosticsNoMatchingSubtitle;

  /// No description provided for @diagnosticsLevelInferred.
  ///
  /// In zh, this message translates to:
  /// **'推断等级'**
  String get diagnosticsLevelInferred;

  /// No description provided for @diagnosticsRawFilteredHint.
  ///
  /// In zh, this message translates to:
  /// **'原文视图会跟随当前等级筛选，只显示对应日志块。'**
  String get diagnosticsRawFilteredHint;

  /// No description provided for @diagnosticsEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无日志'**
  String get diagnosticsEmptyTitle;

  /// No description provided for @diagnosticsEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'当前没有可显示的超级岛诊断日志。'**
  String get diagnosticsEmptySubtitle;

  /// No description provided for @diagnosticsLogTitleFallback.
  ///
  /// In zh, this message translates to:
  /// **'超级岛诊断日志'**
  String get diagnosticsLogTitleFallback;

  /// No description provided for @diagnosticsDeviceInfoTitle.
  ///
  /// In zh, this message translates to:
  /// **'设备与导出信息'**
  String get diagnosticsDeviceInfoTitle;

  /// No description provided for @diagnosticsContentTitle.
  ///
  /// In zh, this message translates to:
  /// **'日志内容'**
  String get diagnosticsContentTitle;

  /// No description provided for @diagnosticsRecentLogsTitle.
  ///
  /// In zh, this message translates to:
  /// **'最近日志'**
  String get diagnosticsRecentLogsTitle;

  /// No description provided for @diagnosticsUnknownCategory.
  ///
  /// In zh, this message translates to:
  /// **'未分类事件'**
  String get diagnosticsUnknownCategory;

  /// No description provided for @diagnosticsExportedAt.
  ///
  /// In zh, this message translates to:
  /// **'导出时间'**
  String get diagnosticsExportedAt;

  /// No description provided for @diagnosticsTime.
  ///
  /// In zh, this message translates to:
  /// **'时间'**
  String get diagnosticsTime;

  /// No description provided for @diagnosticsCategory.
  ///
  /// In zh, this message translates to:
  /// **'类别'**
  String get diagnosticsCategory;

  /// No description provided for @diagnosticsMessage.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get diagnosticsMessage;

  /// No description provided for @diagnosticsStackTrace.
  ///
  /// In zh, this message translates to:
  /// **'堆栈'**
  String get diagnosticsStackTrace;

  /// No description provided for @firstUseGuideTitle.
  ///
  /// In zh, this message translates to:
  /// **'首次使用引导'**
  String get firstUseGuideTitle;

  /// No description provided for @guideAndPermissionsTitle.
  ///
  /// In zh, this message translates to:
  /// **'使用引导与权限'**
  String get guideAndPermissionsTitle;

  /// No description provided for @refreshStatusTooltip.
  ///
  /// In zh, this message translates to:
  /// **'刷新状态'**
  String get refreshStatusTooltip;

  /// No description provided for @guideHeroTitle.
  ///
  /// In zh, this message translates to:
  /// **'先把这页做完，再开始用'**
  String get guideHeroTitle;

  /// No description provided for @guideHeroSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'首屏先授权。下面还会明确说明系统版本支持、简称设置和导入方式，记得继续下滑。'**
  String get guideHeroSubtitle;

  /// No description provided for @guideChipPermissions.
  ///
  /// In zh, this message translates to:
  /// **'权限准备'**
  String get guideChipPermissions;

  /// No description provided for @guideChipShortName.
  ///
  /// In zh, this message translates to:
  /// **'简称设置'**
  String get guideChipShortName;

  /// No description provided for @guideChipImport.
  ///
  /// In zh, this message translates to:
  /// **'导入课表'**
  String get guideChipImport;

  /// No description provided for @guideChipReadyCount.
  ///
  /// In zh, this message translates to:
  /// **'{count}/3 已完成'**
  String guideChipReadyCount(int count);

  /// No description provided for @guideBottomReachedHint.
  ///
  /// In zh, this message translates to:
  /// **'你已经滑到最后了，确认无误后就可以开始使用。'**
  String get guideBottomReachedHint;

  /// No description provided for @guideScrollHint.
  ///
  /// In zh, this message translates to:
  /// **'向下滑动继续，下面还有 HyperOS 版本说明、权限清单、简称设置和导入方式。'**
  String get guideScrollHint;

  /// No description provided for @guideRequestNotificationFirst.
  ///
  /// In zh, this message translates to:
  /// **'先申请通知权限'**
  String get guideRequestNotificationFirst;

  /// No description provided for @quickSetupTitle.
  ///
  /// In zh, this message translates to:
  /// **'首屏快速设置'**
  String get quickSetupTitle;

  /// No description provided for @quickSetupSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'先把最关键的 5 个入口放在前面，不用翻到下面再找。'**
  String get quickSetupSubtitle;

  /// No description provided for @quickActionNotificationsTitle.
  ///
  /// In zh, this message translates to:
  /// **'通知设置'**
  String get quickActionNotificationsTitle;

  /// No description provided for @quickActionNotificationsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'先确保能发通知'**
  String get quickActionNotificationsSubtitle;

  /// No description provided for @quickActionIslandTitle.
  ///
  /// In zh, this message translates to:
  /// **'超级岛权限'**
  String get quickActionIslandTitle;

  /// No description provided for @quickActionIslandSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'检查 promoted 通知'**
  String get quickActionIslandSubtitle;

  /// No description provided for @quickActionAutoStartTitle.
  ///
  /// In zh, this message translates to:
  /// **'自启动'**
  String get quickActionAutoStartTitle;

  /// No description provided for @quickActionAutoStartSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'避免后台被杀'**
  String get quickActionAutoStartSubtitle;

  /// No description provided for @quickActionBatteryTitle.
  ///
  /// In zh, this message translates to:
  /// **'电池无限制'**
  String get quickActionBatteryTitle;

  /// No description provided for @quickActionBatterySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'避免提醒中断'**
  String get quickActionBatterySubtitle;

  /// No description provided for @quickActionKeepAliveTitle.
  ///
  /// In zh, this message translates to:
  /// **'后台保活辅助'**
  String get quickActionKeepAliveTitle;

  /// No description provided for @quickActionKeepAliveSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'提升后台稳定性'**
  String get quickActionKeepAliveSubtitle;

  /// No description provided for @guidePrivacyConsentLabel.
  ///
  /// In zh, this message translates to:
  /// **'我已阅读并同意友盟相关隐私说明'**
  String get guidePrivacyConsentLabel;

  /// No description provided for @guideRequireConsentHint.
  ///
  /// In zh, this message translates to:
  /// **'请先滑到底部阅读说明，并勾选同意后开始使用。'**
  String get guideRequireConsentHint;

  /// No description provided for @guideContinueHint.
  ///
  /// In zh, this message translates to:
  /// **'继续下滑查看完整引导内容。'**
  String get guideContinueHint;

  /// No description provided for @exitAppAction.
  ///
  /// In zh, this message translates to:
  /// **'退出应用'**
  String get exitAppAction;

  /// No description provided for @continueReadingAction.
  ///
  /// In zh, this message translates to:
  /// **'继续查看'**
  String get continueReadingAction;

  /// No description provided for @agreeAndStartAction.
  ///
  /// In zh, this message translates to:
  /// **'同意并开始使用'**
  String get agreeAndStartAction;

  /// No description provided for @startUsingAction.
  ///
  /// In zh, this message translates to:
  /// **'开始使用'**
  String get startUsingAction;

  /// No description provided for @editSingleLessonTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑单节课'**
  String get editSingleLessonTitle;

  /// No description provided for @editCourseTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑课程'**
  String get editCourseTitle;

  /// No description provided for @addSingleLessonTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加单节课'**
  String get addSingleLessonTitle;

  /// No description provided for @addCourseTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加课程'**
  String get addCourseTitle;

  /// No description provided for @deleteCourseTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除课程'**
  String get deleteCourseTitle;

  /// No description provided for @courseDeleted.
  ///
  /// In zh, this message translates to:
  /// **'课程已删除'**
  String get courseDeleted;

  /// No description provided for @addMethodTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加方式'**
  String get addMethodTitle;

  /// No description provided for @singleLessonLabel.
  ///
  /// In zh, this message translates to:
  /// **'单节课'**
  String get singleLessonLabel;

  /// No description provided for @recurringLessonLabel.
  ///
  /// In zh, this message translates to:
  /// **'多节课'**
  String get recurringLessonLabel;

  /// No description provided for @singleLessonHint.
  ///
  /// In zh, this message translates to:
  /// **'适合补课、临时加课，课程只会落在一个周次。'**
  String get singleLessonHint;

  /// No description provided for @recurringLessonHint.
  ///
  /// In zh, this message translates to:
  /// **'适合同一时间连续上很多周的常规课程。'**
  String get recurringLessonHint;

  /// No description provided for @sharedInfoTitle.
  ///
  /// In zh, this message translates to:
  /// **'共享信息'**
  String get sharedInfoTitle;

  /// No description provided for @sharedInfoHint.
  ///
  /// In zh, this message translates to:
  /// **'课程名、简称、老师、课程简介、课程性质和颜色会同步到同名课程的其他排课。'**
  String get sharedInfoHint;

  /// No description provided for @reuseExistingCourseLabel.
  ///
  /// In zh, this message translates to:
  /// **'沿用已有课程'**
  String get reuseExistingCourseLabel;

  /// No description provided for @reuseExistingCourseHelper.
  ///
  /// In zh, this message translates to:
  /// **'选一个已有课程，自动带入课程名、老师和其他共享信息'**
  String get reuseExistingCourseHelper;

  /// No description provided for @manualInputLabel.
  ///
  /// In zh, this message translates to:
  /// **'手动填写'**
  String get manualInputLabel;

  /// No description provided for @noTemplateCoursesHint.
  ///
  /// In zh, this message translates to:
  /// **'当前课表里还没有现成课程，先手动录入一门，后面临时加课就能直接选了。'**
  String get noTemplateCoursesHint;

  /// No description provided for @courseNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'课程名称'**
  String get courseNameLabel;

  /// No description provided for @courseNameHelper.
  ///
  /// In zh, this message translates to:
  /// **'超级岛建议 3 个字以内，显示效果最好'**
  String get courseNameHelper;

  /// No description provided for @pleaseEnterCourseName.
  ///
  /// In zh, this message translates to:
  /// **'请输入课程名称'**
  String get pleaseEnterCourseName;

  /// No description provided for @courseShortNameOptional.
  ///
  /// In zh, this message translates to:
  /// **'课程简称 (可选)'**
  String get courseShortNameOptional;

  /// No description provided for @teacherLabel.
  ///
  /// In zh, this message translates to:
  /// **'授课教师'**
  String get teacherLabel;

  /// No description provided for @courseNatureLabel.
  ///
  /// In zh, this message translates to:
  /// **'课程性质'**
  String get courseNatureLabel;

  /// No description provided for @courseDescriptionOptional.
  ///
  /// In zh, this message translates to:
  /// **'课程简介 (可选)'**
  String get courseDescriptionOptional;

  /// No description provided for @currentScheduleHint.
  ///
  /// In zh, this message translates to:
  /// **'这里的星期、节次、教室、周次和单双周只影响当前这一条排课。'**
  String get currentScheduleHint;

  /// No description provided for @followProfileTimeScheme.
  ///
  /// In zh, this message translates to:
  /// **'跟随当前课表（{name}）'**
  String followProfileTimeScheme(String name);

  /// No description provided for @timeSchemeOverrideLabel.
  ///
  /// In zh, this message translates to:
  /// **'上课时间方案'**
  String get timeSchemeOverrideLabel;

  /// No description provided for @lessonWeeksTitle.
  ///
  /// In zh, this message translates to:
  /// **'上课周次'**
  String get lessonWeeksTitle;

  /// No description provided for @singleLessonWeekHint.
  ///
  /// In zh, this message translates to:
  /// **'单节课只会出现在一个周次里，适合补课、临时加课。'**
  String get singleLessonWeekHint;

  /// No description provided for @rangeWeekLabel.
  ///
  /// In zh, this message translates to:
  /// **'连续周'**
  String get rangeWeekLabel;

  /// No description provided for @customWeekLabel.
  ///
  /// In zh, this message translates to:
  /// **'自定义周'**
  String get customWeekLabel;

  /// No description provided for @allWeeksLabel.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get allWeeksLabel;

  /// No description provided for @oddWeeksLabel.
  ///
  /// In zh, this message translates to:
  /// **'单周'**
  String get oddWeeksLabel;

  /// No description provided for @evenWeeksLabel.
  ///
  /// In zh, this message translates to:
  /// **'双周'**
  String get evenWeeksLabel;

  /// No description provided for @allWeeksHint.
  ///
  /// In zh, this message translates to:
  /// **'按开始周到结束周连续排课。'**
  String get allWeeksHint;

  /// No description provided for @oddWeeksHint.
  ///
  /// In zh, this message translates to:
  /// **'只保留范围内的单周。'**
  String get oddWeeksHint;

  /// No description provided for @evenWeeksHint.
  ///
  /// In zh, this message translates to:
  /// **'只保留范围内的双周。'**
  String get evenWeeksHint;

  /// No description provided for @customPaletteColor.
  ///
  /// In zh, this message translates to:
  /// **'调色盘自定义颜色'**
  String get customPaletteColor;

  /// No description provided for @timeSchemeSetCountValue.
  ///
  /// In zh, this message translates to:
  /// **'{count} 套'**
  String timeSchemeSetCountValue(int count);

  /// No description provided for @profileCountValue.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个'**
  String profileCountValue(int count);

  /// No description provided for @courseSectionCountValue.
  ///
  /// In zh, this message translates to:
  /// **'{count} 节'**
  String courseSectionCountValue(int count);

  /// No description provided for @timeSchemeStartsAt.
  ///
  /// In zh, this message translates to:
  /// **'{start} 起'**
  String timeSchemeStartsAt(String start);

  /// No description provided for @weekdayShortMonday.
  ///
  /// In zh, this message translates to:
  /// **'一'**
  String get weekdayShortMonday;

  /// No description provided for @weekdayShortTuesday.
  ///
  /// In zh, this message translates to:
  /// **'二'**
  String get weekdayShortTuesday;

  /// No description provided for @weekdayShortWednesday.
  ///
  /// In zh, this message translates to:
  /// **'三'**
  String get weekdayShortWednesday;

  /// No description provided for @weekdayShortThursday.
  ///
  /// In zh, this message translates to:
  /// **'四'**
  String get weekdayShortThursday;

  /// No description provided for @weekdayShortFriday.
  ///
  /// In zh, this message translates to:
  /// **'五'**
  String get weekdayShortFriday;

  /// No description provided for @weekdayShortSaturday.
  ///
  /// In zh, this message translates to:
  /// **'六'**
  String get weekdayShortSaturday;

  /// No description provided for @weekdayShortSunday.
  ///
  /// In zh, this message translates to:
  /// **'日'**
  String get weekdayShortSunday;

  /// No description provided for @weekdaySectionRange.
  ///
  /// In zh, this message translates to:
  /// **'周{weekday} {startSection}-{endSection}节'**
  String weekdaySectionRange(String weekday, int startSection, int endSection);

  /// No description provided for @timeSchemeUsageReference.
  ///
  /// In zh, this message translates to:
  /// **'{profileName} · {courseName}（周{weekday} {startSection}-{endSection}节，{usageType}）'**
  String timeSchemeUsageReference(
    String profileName,
    String courseName,
    String weekday,
    int startSection,
    int endSection,
    String usageType,
  );

  /// No description provided for @weekdaySectionSummary.
  ///
  /// In zh, this message translates to:
  /// **'周{weekday} {startSection}-{endSection}节'**
  String weekdaySectionSummary(
    String weekday,
    int startSection,
    int endSection,
  );

  /// No description provided for @timeRangeValidationNoCrossDay.
  ///
  /// In zh, this message translates to:
  /// **'结束时间必须晚于开始时间'**
  String get timeRangeValidationNoCrossDay;

  /// No description provided for @timeSchemeNameEmptyValidation.
  ///
  /// In zh, this message translates to:
  /// **'时间模板名称不能为空'**
  String get timeSchemeNameEmptyValidation;

  /// No description provided for @liveTimeCorrectionNone.
  ///
  /// In zh, this message translates to:
  /// **'不矫正'**
  String get liveTimeCorrectionNone;

  /// No description provided for @liveTimeCorrectionDelay.
  ///
  /// In zh, this message translates to:
  /// **'整体延后 {seconds} 秒'**
  String liveTimeCorrectionDelay(int seconds);

  /// No description provided for @liveTimeCorrectionAdvance.
  ///
  /// In zh, this message translates to:
  /// **'整体提前 {seconds} 秒'**
  String liveTimeCorrectionAdvance(int seconds);

  /// No description provided for @liveClassReminderLeadSummaryImmediate.
  ///
  /// In zh, this message translates to:
  /// **'从上课开始就进入重点提醒展示，并在距下课 {seconds} 秒切到秒级倒数'**
  String liveClassReminderLeadSummaryImmediate(int seconds);

  /// No description provided for @liveClassReminderLeadSummaryKeepNormal.
  ///
  /// In zh, this message translates to:
  /// **'上课后先保留普通课中通知，在距下课前 {minutes} 分钟切到重点提醒 / 下课提醒，并在最后 {seconds} 秒切到秒级倒数'**
  String liveClassReminderLeadSummaryKeepNormal(int minutes, int seconds);

  /// No description provided for @liveClassReminderLeadSummaryIsland.
  ///
  /// In zh, this message translates to:
  /// **'在距下课前 {minutes} 分钟切到超级岛 / 重点提醒，并在最后 {seconds} 秒切到秒级倒数'**
  String liveClassReminderLeadSummaryIsland(int minutes, int seconds);

  /// No description provided for @liveClassReminderLeadSummaryFocused.
  ///
  /// In zh, this message translates to:
  /// **'在距下课前 {minutes} 分钟开始展示重点提醒，并在最后 {seconds} 秒切到秒级倒数'**
  String liveClassReminderLeadSummaryFocused(int minutes, int seconds);

  /// No description provided for @liveSettingsEntrySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'提醒时段、岛展示、通知栏和显示内容'**
  String get liveSettingsEntrySubtitle;

  /// No description provided for @timetableProfilesEntrySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'新建、切换、复制、重命名和删除课表'**
  String get timetableProfilesEntrySubtitle;

  /// No description provided for @homeTitleSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'首页标题'**
  String get homeTitleSectionTitle;

  /// No description provided for @homeTitleSectionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'控制首页左上角课表切换入口的样式。'**
  String get homeTitleSectionSubtitle;

  /// No description provided for @homeTitleStyleLabel.
  ///
  /// In zh, this message translates to:
  /// **'标题样式'**
  String get homeTitleStyleLabel;

  /// No description provided for @themeSeedSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'应用主题色'**
  String get themeSeedSectionTitle;

  /// No description provided for @themeSeedSectionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'影响顶部栏、强调色和全局主色调。'**
  String get themeSeedSectionSubtitle;

  /// No description provided for @timetableBackgroundColorSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'课表背景色'**
  String get timetableBackgroundColorSectionTitle;

  /// No description provided for @timetableBackgroundColorSectionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'只作用于课表页面的大背景。'**
  String get timetableBackgroundColorSectionSubtitle;

  /// No description provided for @defaultTimetablePreviewName.
  ///
  /// In zh, this message translates to:
  /// **'默认课表'**
  String get defaultTimetablePreviewName;

  /// No description provided for @beforeClassDisplaySettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'上课前提醒显示'**
  String get beforeClassDisplaySettingsTitle;

  /// No description provided for @duringEndDisplaySettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'课中/下课提醒显示'**
  String get duringEndDisplaySettingsTitle;

  /// No description provided for @liveDisplaySummaryShortName.
  ///
  /// In zh, this message translates to:
  /// **'简称'**
  String get liveDisplaySummaryShortName;

  /// No description provided for @liveDisplaySummaryCourseName.
  ///
  /// In zh, this message translates to:
  /// **'课程名'**
  String get liveDisplaySummaryCourseName;

  /// No description provided for @liveDisplaySummaryLocation.
  ///
  /// In zh, this message translates to:
  /// **'地点'**
  String get liveDisplaySummaryLocation;

  /// No description provided for @liveDisplaySummaryCountdown.
  ///
  /// In zh, this message translates to:
  /// **'倒计时（{style}）'**
  String liveDisplaySummaryCountdown(String style);

  /// No description provided for @liveDisplaySummaryStageText.
  ///
  /// In zh, this message translates to:
  /// **'阶段文字'**
  String get liveDisplaySummaryStageText;

  /// No description provided for @liveDisplaySummaryLeftLabelImage.
  ///
  /// In zh, this message translates to:
  /// **'左侧图标'**
  String get liveDisplaySummaryLeftLabelImage;

  /// No description provided for @liveDisplaySummaryMinimal.
  ///
  /// In zh, this message translates to:
  /// **'最简显示'**
  String get liveDisplaySummaryMinimal;

  /// No description provided for @guideHyperOsChip.
  ///
  /// In zh, this message translates to:
  /// **'HyperOS 3.0.300+'**
  String get guideHyperOsChip;

  /// No description provided for @guideStatusTitle.
  ///
  /// In zh, this message translates to:
  /// **'当前状态'**
  String get guideStatusTitle;

  /// No description provided for @guideStatusNotificationPermission.
  ///
  /// In zh, this message translates to:
  /// **'通知权限'**
  String get guideStatusNotificationPermission;

  /// No description provided for @guideStatusEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已开启'**
  String get guideStatusEnabled;

  /// No description provided for @guideStatusDisabled.
  ///
  /// In zh, this message translates to:
  /// **'未开启'**
  String get guideStatusDisabled;

  /// No description provided for @guideStatusIslandSupport.
  ///
  /// In zh, this message translates to:
  /// **'焦点通知 / 超级岛'**
  String get guideStatusIslandSupport;

  /// No description provided for @guideStatusSystemAllowed.
  ///
  /// In zh, this message translates to:
  /// **'系统已允许'**
  String get guideStatusSystemAllowed;

  /// No description provided for @guideStatusEnabledPending.
  ///
  /// In zh, this message translates to:
  /// **'已开启但系统暂未确认'**
  String get guideStatusEnabledPending;

  /// No description provided for @guideStatusSuggestedCheck.
  ///
  /// In zh, this message translates to:
  /// **'建议检查'**
  String get guideStatusSuggestedCheck;

  /// No description provided for @guideStatusBatteryOptimization.
  ///
  /// In zh, this message translates to:
  /// **'电池优化'**
  String get guideStatusBatteryOptimization;

  /// No description provided for @guideStatusBatteryUnrestricted.
  ///
  /// In zh, this message translates to:
  /// **'无限制'**
  String get guideStatusBatteryUnrestricted;

  /// No description provided for @guideStatusBatteryRestricted.
  ///
  /// In zh, this message translates to:
  /// **'仍受限制'**
  String get guideStatusBatteryRestricted;

  /// No description provided for @guideStatusKeepAlive.
  ///
  /// In zh, this message translates to:
  /// **'后台保活辅助'**
  String get guideStatusKeepAlive;

  /// No description provided for @guideStatusAndroidVersion.
  ///
  /// In zh, this message translates to:
  /// **'Android 版本'**
  String get guideStatusAndroidVersion;

  /// No description provided for @guideStatusVersionUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未识别'**
  String get guideStatusVersionUnknown;

  /// No description provided for @guideStatusIslandSystemSupport.
  ///
  /// In zh, this message translates to:
  /// **'超级岛系统支持'**
  String get guideStatusIslandSystemSupport;

  /// No description provided for @guideStatusIslandSystemRequirement.
  ///
  /// In zh, this message translates to:
  /// **'需 HyperOS 3.0.300 及以上'**
  String get guideStatusIslandSystemRequirement;

  /// No description provided for @guideStatusIslandHint.
  ///
  /// In zh, this message translates to:
  /// **'如果你主要想用超级岛，先确认系统版本至少是 HyperOS 3.0.300，再继续把下面权限清单按顺序点完。'**
  String get guideStatusIslandHint;

  /// No description provided for @guidePermissionChecklistTitle.
  ///
  /// In zh, this message translates to:
  /// **'权限清单'**
  String get guidePermissionChecklistTitle;

  /// No description provided for @guidePermissionChecklistSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'按这个顺序检查，最省事，也最不容易漏。'**
  String get guidePermissionChecklistSubtitle;

  /// No description provided for @guideChecklistRequestNotificationTitle.
  ///
  /// In zh, this message translates to:
  /// **'申请通知权限'**
  String get guideChecklistRequestNotificationTitle;

  /// No description provided for @guideChecklistRequestNotificationSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'这是所有提醒的前提'**
  String get guideChecklistRequestNotificationSubtitle;

  /// No description provided for @guideChecklistOpenNotificationTitle.
  ///
  /// In zh, this message translates to:
  /// **'打开通知设置'**
  String get guideChecklistOpenNotificationTitle;

  /// No description provided for @guideChecklistOpenNotificationSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'检查通知总开关、锁屏展示和实时通知权限'**
  String get guideChecklistOpenNotificationSubtitle;

  /// No description provided for @guideChecklistOpenIslandTitle.
  ///
  /// In zh, this message translates to:
  /// **'打开焦点通知设置'**
  String get guideChecklistOpenIslandTitle;

  /// No description provided for @guideChecklistOpenIslandSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'HyperOS 3.0.300 及以上再检查 promoted / 超级岛通知'**
  String get guideChecklistOpenIslandSubtitle;

  /// No description provided for @guideChecklistOpenAutoStartTitle.
  ///
  /// In zh, this message translates to:
  /// **'打开自启动设置'**
  String get guideChecklistOpenAutoStartTitle;

  /// No description provided for @guideChecklistOpenAutoStartSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'允许应用开机自启和后台常驻'**
  String get guideChecklistOpenAutoStartSubtitle;

  /// No description provided for @guideChecklistOpenBatteryTitle.
  ///
  /// In zh, this message translates to:
  /// **'打开电池策略设置'**
  String get guideChecklistOpenBatteryTitle;

  /// No description provided for @guideChecklistOpenBatterySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'建议改成无限制，避免上课提醒被中断'**
  String get guideChecklistOpenBatterySubtitle;

  /// No description provided for @guideChecklistOpenKeepAliveTitle.
  ///
  /// In zh, this message translates to:
  /// **'打开后台保活辅助'**
  String get guideChecklistOpenKeepAliveTitle;

  /// No description provided for @guideChecklistOpenKeepAliveSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'进一步提升超级岛和提醒在后台场景下的稳定性'**
  String get guideChecklistOpenKeepAliveSubtitle;

  /// No description provided for @guideShortNameAdviceTitle.
  ///
  /// In zh, this message translates to:
  /// **'课程简称建议'**
  String get guideShortNameAdviceTitle;

  /// No description provided for @guideShortNameAdviceSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'超级岛支持显示课程简称。简称不是自动生成的，需要你在课程编辑里自己填写。建议控制在 3 个字以内，显示会更稳定。'**
  String get guideShortNameAdviceSubtitle;

  /// No description provided for @guideShortNameRecommended.
  ///
  /// In zh, this message translates to:
  /// **'推荐示例'**
  String get guideShortNameRecommended;

  /// No description provided for @guideShortNameNotRecommended.
  ///
  /// In zh, this message translates to:
  /// **'不推荐'**
  String get guideShortNameNotRecommended;

  /// No description provided for @guideShortNameRecommendedExample.
  ///
  /// In zh, this message translates to:
  /// **'高数 / 概率 / 数控'**
  String get guideShortNameRecommendedExample;

  /// No description provided for @guideShortNameNotRecommendedExample.
  ///
  /// In zh, this message translates to:
  /// **'高等数学A(1) / 数控技术及应用'**
  String get guideShortNameNotRecommendedExample;

  /// No description provided for @guideSetCourseShortNameAction.
  ///
  /// In zh, this message translates to:
  /// **'去设置课程简称'**
  String get guideSetCourseShortNameAction;

  /// No description provided for @guideImportMethodsTitle.
  ///
  /// In zh, this message translates to:
  /// **'课表导入方式'**
  String get guideImportMethodsTitle;

  /// No description provided for @guideImportMethodsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'当前版本已经支持部分学校的教务系统网页登录导入；如果你的学校还没适配，也还有其他迁移方式。'**
  String get guideImportMethodsSubtitle;

  /// No description provided for @guideImportMethodStep1.
  ///
  /// In zh, this message translates to:
  /// **'优先进入“导入课程 > 教务系统导入”，选择学校和适配器后，直接在应用内打开教务网页完成导入。'**
  String get guideImportMethodStep1;

  /// No description provided for @guideImportMethodStep2.
  ///
  /// In zh, this message translates to:
  /// **'如果你的学校暂时没有适配，可以先在 WakeUp 等课表应用里导入教务系统课程，再导出日历格式，最后回到本应用导入。'**
  String get guideImportMethodStep2;

  /// No description provided for @guideImportMethodStep3.
  ///
  /// In zh, this message translates to:
  /// **'如果别人已经在用本应用，也可以让对方导出完整备份文件，你直接导入就能恢复课程和设置。'**
  String get guideImportMethodStep3;

  /// No description provided for @guideImportMethodExtra.
  ///
  /// In zh, this message translates to:
  /// **'如果你会抓包、网页调试或 JavaScript，也欢迎参与学校教务适配补充，让更多学校能直接导入。'**
  String get guideImportMethodExtra;

  /// No description provided for @guideFinalTipsTitle.
  ///
  /// In zh, this message translates to:
  /// **'最后再看这 3 条'**
  String get guideFinalTipsTitle;

  /// No description provided for @guideFinalTip1.
  ///
  /// In zh, this message translates to:
  /// **'1. HyperOS 3.0.300 及以上才支持超级岛；如果系统版本不够，应用仍可正常发普通提醒。'**
  String get guideFinalTip1;

  /// No description provided for @guideFinalTip2.
  ///
  /// In zh, this message translates to:
  /// **'2. 先在设置页调整“上课前弹出”和“课中 / 临近下课提醒”的阈值。'**
  String get guideFinalTip2;

  /// No description provided for @guideFinalTip3.
  ///
  /// In zh, this message translates to:
  /// **'3. 完成系统权限设置后，再用测试通知验证；如果岛区还是偶尔消失，优先检查自启动和省电策略。'**
  String get guideFinalTip3;

  /// No description provided for @guidePrivacyHelperRequireConsent.
  ///
  /// In zh, this message translates to:
  /// **'你勾选同意后，代表你已阅读并同意上述友盟相关说明、隐私内容与免责提示。'**
  String get guidePrivacyHelperRequireConsent;

  /// No description provided for @guidePrivacyHelperViewOnly.
  ///
  /// In zh, this message translates to:
  /// **'这里保留与首次启动一致的隐私、第三方 SDK 与免责说明，方便你随时查看；当前页面不需要再次勾选同意。'**
  String get guidePrivacyHelperViewOnly;

  /// No description provided for @guidePrivacySectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'隐私、第三方 SDK 与免责说明'**
  String get guidePrivacySectionTitle;

  /// No description provided for @guidePrivacyParagraph1.
  ///
  /// In zh, this message translates to:
  /// **'本应用主体功能按本地运行方式设计，课表、时间模板、课程记录和大部分设置默认保存在你的设备本地。'**
  String get guidePrivacyParagraph1;

  /// No description provided for @guidePrivacyParagraph2.
  ///
  /// In zh, this message translates to:
  /// **'只有在你主动使用检查更新、下载更新、导入导出等联网功能，或你勾选同意后初始化友盟相关 SDK 时，应用才会与外部服务发生数据交互。'**
  String get guidePrivacyParagraph2;

  /// No description provided for @guidePrivacyParagraph3.
  ///
  /// In zh, this message translates to:
  /// **'本应用接入友盟移动统计 SDK、友盟应用性能监控 SDK 以及高级运营分析依赖库。它们的服务用途包括移动统计分析、应用性能监控以及高级运营分析相关能力；只有在你勾选同意后，这些 SDK 才会正式初始化。'**
  String get guidePrivacyParagraph3;

  /// No description provided for @guidePrivacyParagraph4.
  ///
  /// In zh, this message translates to:
  /// **'按友盟官方说明，这些 SDK 可能处理的信息包括：设备信息（如 IMEI、MAC、Android ID、OAID、IDFA、OpenUDID、GUID、SIM 卡 IMSI 等）、网络状态、设备标识，以及高级运营分析依赖库涉及的应用列表和地理位置相关信息。'**
  String get guidePrivacyParagraph4;

  /// No description provided for @guideRiskTitle.
  ///
  /// In zh, this message translates to:
  /// **'免责与风险提示'**
  String get guideRiskTitle;

  /// No description provided for @guideRiskParagraph1.
  ///
  /// In zh, this message translates to:
  /// **'1. 超级岛、焦点通知、后台提醒和保活效果依赖系统版本、机型、厂商策略、权限、自启动、电池策略等外部条件，无法保证所有设备表现完全一致。'**
  String get guideRiskParagraph1;

  /// No description provided for @guideRiskParagraph2.
  ///
  /// In zh, this message translates to:
  /// **'2. 检查更新、镜像下载、系统下载器、导入导出与分享等能力依赖网络环境、第三方服务和系统文件能力；若出现失败、限速或文件异常，请以 Release 页面、你自己保存的备份文件和系统提示为准。'**
  String get guideRiskParagraph2;

  /// No description provided for @guideRiskParagraph3.
  ///
  /// In zh, this message translates to:
  /// **'3. 在迁移、导入或覆盖数据前，请先自行确认备份文件完整可用，并妥善保管含有课表信息的文件；因用户自行删除、覆盖、分享或保管不当造成的数据问题，需要由用户自行承担相应风险。'**
  String get guideRiskParagraph3;

  /// No description provided for @guideUmengPrivacyLink.
  ///
  /// In zh, this message translates to:
  /// **'友盟隐私政策：https://www.umeng.com/page/policy'**
  String get guideUmengPrivacyLink;

  /// No description provided for @liveDiagnosticsUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'当前还没有可查看的超级岛诊断日志'**
  String get liveDiagnosticsUnavailable;

  /// No description provided for @liveDiagnosticsViewerTitle.
  ///
  /// In zh, this message translates to:
  /// **'超级岛诊断日志'**
  String get liveDiagnosticsViewerTitle;

  /// No description provided for @liveDiagnosticsShareText.
  ///
  /// In zh, this message translates to:
  /// **'这是轻屿课表导出的超级岛诊断日志，可用于排查“超级岛没有弹出”等问题。'**
  String get liveDiagnosticsShareText;

  /// No description provided for @liveDiagnosticsShareSubject.
  ///
  /// In zh, this message translates to:
  /// **'轻屿课表 - 超级岛诊断日志'**
  String get liveDiagnosticsShareSubject;

  /// No description provided for @liveDiagnosticsSnapshotShareText.
  ///
  /// In zh, this message translates to:
  /// **'这是轻屿课表当前测试诊断页导出的超级岛状态快照，可用于排查“超级岛没有弹出”等问题。'**
  String get liveDiagnosticsSnapshotShareText;

  /// No description provided for @liveDiagnosticsSnapshotShareSubject.
  ///
  /// In zh, this message translates to:
  /// **'轻屿课表 - 超级岛状态快照'**
  String get liveDiagnosticsSnapshotShareSubject;

  /// No description provided for @liveDiagnosticsNothingToExport.
  ///
  /// In zh, this message translates to:
  /// **'当前没有可导出的日志文件，也没有可导出的状态快照'**
  String get liveDiagnosticsNothingToExport;

  /// No description provided for @liveDiagnosticsCleared.
  ///
  /// In zh, this message translates to:
  /// **'已清空超级岛诊断日志，后续会重新开始收集'**
  String get liveDiagnosticsCleared;

  /// No description provided for @liveDiagnosticsClearFailed.
  ///
  /// In zh, this message translates to:
  /// **'清空超级岛诊断日志失败'**
  String get liveDiagnosticsClearFailed;

  /// No description provided for @liveTestingNotRefreshed.
  ///
  /// In zh, this message translates to:
  /// **'尚未刷新'**
  String get liveTestingNotRefreshed;

  /// No description provided for @liveTestingTitle.
  ///
  /// In zh, this message translates to:
  /// **'测试与诊断'**
  String get liveTestingTitle;

  /// No description provided for @liveTestingNotificationTitle.
  ///
  /// In zh, this message translates to:
  /// **'测试通知'**
  String get liveTestingNotificationTitle;

  /// No description provided for @liveTestingNotificationSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'用于验证超级岛、通知栏和课程简称等显示效果。'**
  String get liveTestingNotificationSubtitle;

  /// No description provided for @liveTestingSendAction.
  ///
  /// In zh, this message translates to:
  /// **'发送测试通知'**
  String get liveTestingSendAction;

  /// No description provided for @liveTestingUmengHint.
  ///
  /// In zh, this message translates to:
  /// **'下面两个按钮仅测试版显示，用于验证友盟 U-APM 崩溃和卡顿上报。'**
  String get liveTestingUmengHint;

  /// No description provided for @liveTestingCrashAction.
  ///
  /// In zh, this message translates to:
  /// **'崩溃测试'**
  String get liveTestingCrashAction;

  /// No description provided for @liveTestingAnrAction.
  ///
  /// In zh, this message translates to:
  /// **'异常卡顿测试'**
  String get liveTestingAnrAction;

  /// No description provided for @liveTestingIslandStatusTitle.
  ///
  /// In zh, this message translates to:
  /// **'上岛状态诊断'**
  String get liveTestingIslandStatusTitle;

  /// No description provided for @liveTestingIslandStatusSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'这里直接显示原生实时服务、通知构造结果和不上岛原因。'**
  String get liveTestingIslandStatusSubtitle;

  /// No description provided for @liveTestingServiceStatusRunning.
  ///
  /// In zh, this message translates to:
  /// **'服务运行中'**
  String get liveTestingServiceStatusRunning;

  /// No description provided for @liveTestingServiceStatusStopped.
  ///
  /// In zh, this message translates to:
  /// **'服务未运行'**
  String get liveTestingServiceStatusStopped;

  /// No description provided for @liveTestingNoIslandReasonTitle.
  ///
  /// In zh, this message translates to:
  /// **'不上岛原因'**
  String get liveTestingNoIslandReasonTitle;

  /// No description provided for @liveTestingNoIslandReasonEmpty.
  ///
  /// In zh, this message translates to:
  /// **'当前无拦截原因'**
  String get liveTestingNoIslandReasonEmpty;

  /// No description provided for @liveTestingRefreshAction.
  ///
  /// In zh, this message translates to:
  /// **'刷新诊断'**
  String get liveTestingRefreshAction;

  /// No description provided for @liveTestingRefreshing.
  ///
  /// In zh, this message translates to:
  /// **'刷新中'**
  String get liveTestingRefreshing;

  /// No description provided for @liveTestingExportAction.
  ///
  /// In zh, this message translates to:
  /// **'导出并分享日志'**
  String get liveTestingExportAction;

  /// No description provided for @liveTestingExporting.
  ///
  /// In zh, this message translates to:
  /// **'导出中'**
  String get liveTestingExporting;

  /// No description provided for @liveTestingAutoRefreshTitle.
  ///
  /// In zh, this message translates to:
  /// **'自动刷新'**
  String get liveTestingAutoRefreshTitle;

  /// No description provided for @liveTestingAutoRefreshOn.
  ///
  /// In zh, this message translates to:
  /// **'每 {seconds} 秒自动拉取一次诊断状态'**
  String liveTestingAutoRefreshOn(int seconds);

  /// No description provided for @liveTestingAutoRefreshOff.
  ///
  /// In zh, this message translates to:
  /// **'关闭后只在手动刷新时更新，便于稳定查看当前状态'**
  String get liveTestingAutoRefreshOff;

  /// No description provided for @liveTestingRefreshedAt.
  ///
  /// In zh, this message translates to:
  /// **'上次刷新：{time}'**
  String liveTestingRefreshedAt(String time);

  /// No description provided for @liveTestingSectionEnvironment.
  ///
  /// In zh, this message translates to:
  /// **'环境与权限'**
  String get liveTestingSectionEnvironment;

  /// No description provided for @liveTestingSectionService.
  ///
  /// In zh, this message translates to:
  /// **'服务状态'**
  String get liveTestingSectionService;

  /// No description provided for @liveTestingSectionCourse.
  ///
  /// In zh, this message translates to:
  /// **'课程数据'**
  String get liveTestingSectionCourse;

  /// No description provided for @liveTestingSectionTiming.
  ///
  /// In zh, this message translates to:
  /// **'时间与阶段'**
  String get liveTestingSectionTiming;

  /// No description provided for @liveTestingSectionSwitches.
  ///
  /// In zh, this message translates to:
  /// **'阶段开关'**
  String get liveTestingSectionSwitches;

  /// No description provided for @liveTestingSectionDisplay.
  ///
  /// In zh, this message translates to:
  /// **'岛显示配置'**
  String get liveTestingSectionDisplay;

  /// No description provided for @liveTestingSectionNotification.
  ///
  /// In zh, this message translates to:
  /// **'通知判定结果'**
  String get liveTestingSectionNotification;

  /// No description provided for @liveTestingSectionRecentLogs.
  ///
  /// In zh, this message translates to:
  /// **'最近诊断日志'**
  String get liveTestingSectionRecentLogs;

  /// No description provided for @liveTestingRawDataTitle.
  ///
  /// In zh, this message translates to:
  /// **'原始调试数据'**
  String get liveTestingRawDataTitle;

  /// No description provided for @liveTestingRawDataSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'默认折叠，排查时再展开核对完整原生字段。'**
  String get liveTestingRawDataSubtitle;

  /// No description provided for @liveTestingExpandRawJson.
  ///
  /// In zh, this message translates to:
  /// **'展开原始 JSON'**
  String get liveTestingExpandRawJson;

  /// No description provided for @liveTestingExpandRawJsonSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'避免大段原始字段一直占满页面'**
  String get liveTestingExpandRawJsonSubtitle;

  /// No description provided for @liveTestingLocalLogsTitle.
  ///
  /// In zh, this message translates to:
  /// **'本地诊断日志'**
  String get liveTestingLocalLogsTitle;

  /// No description provided for @liveTestingLocalLogsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'一键导出日志文件，直接通过系统分享发给开发者；也可以清空后重新收集。'**
  String get liveTestingLocalLogsSubtitle;

  /// No description provided for @liveTestingClearLogsAction.
  ///
  /// In zh, this message translates to:
  /// **'清空日志'**
  String get liveTestingClearLogsAction;

  /// No description provided for @liveTestingClearingLogs.
  ///
  /// In zh, this message translates to:
  /// **'清空中'**
  String get liveTestingClearingLogs;

  /// No description provided for @liveTestingViewPhoneLogsAction.
  ///
  /// In zh, this message translates to:
  /// **'查看手机日志'**
  String get liveTestingViewPhoneLogsAction;

  /// No description provided for @liveTestingMoreTesterOptionsAction.
  ///
  /// In zh, this message translates to:
  /// **'更多测试者选项'**
  String get liveTestingMoreTesterOptionsAction;

  /// No description provided for @yesLabel.
  ///
  /// In zh, this message translates to:
  /// **'是'**
  String get yesLabel;

  /// No description provided for @noLabel.
  ///
  /// In zh, this message translates to:
  /// **'否'**
  String get noLabel;

  /// No description provided for @liveTestingCurrentNativeFieldsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'显示当前原生诊断字段。'**
  String get liveTestingCurrentNativeFieldsSubtitle;

  /// No description provided for @liveTestingCrashSoon.
  ///
  /// In zh, this message translates to:
  /// **'即将触发友盟 U-APM 测试崩溃，请重新打开应用查看后台是否收到上报'**
  String get liveTestingCrashSoon;

  /// No description provided for @liveTestingAnrSoon.
  ///
  /// In zh, this message translates to:
  /// **'即将触发约 30 秒主线程卡死，请脱离 flutter run 测试，并在卡死后重新打开应用查看友盟后台'**
  String get liveTestingAnrSoon;

  /// No description provided for @liveTestingNoCourseAvailable.
  ///
  /// In zh, this message translates to:
  /// **'当前没有可测试的课程'**
  String get liveTestingNoCourseAvailable;

  /// No description provided for @liveTestingTestCourseNote.
  ///
  /// In zh, this message translates to:
  /// **'此处显示备注。可以在课程编辑页进行设置。'**
  String get liveTestingTestCourseNote;

  /// No description provided for @liveTestingNotificationSent.
  ///
  /// In zh, this message translates to:
  /// **'已发送上课提醒测试通知，约 8 秒内会进入上课前提醒阶段'**
  String get liveTestingNotificationSent;

  /// No description provided for @sendFailedWithError.
  ///
  /// In zh, this message translates to:
  /// **'发送失败: {error}'**
  String sendFailedWithError(String error);

  /// No description provided for @homeWidgetSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'桌面小组件'**
  String get homeWidgetSettingsTitle;

  /// No description provided for @homeWidgetTodayCourseTitle.
  ///
  /// In zh, this message translates to:
  /// **'今日课程组件'**
  String get homeWidgetTodayCourseTitle;

  /// No description provided for @homeWidgetTodayCourseSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'首批支持 2×2、2×4、4×4 三种尺寸。点击小组件会直接打开首页，课程开始和结束时会主动刷新。'**
  String get homeWidgetTodayCourseSubtitle;

  /// No description provided for @homeWidgetQuickAddTitle.
  ///
  /// In zh, this message translates to:
  /// **'快速添加到桌面'**
  String get homeWidgetQuickAddTitle;

  /// No description provided for @homeWidgetCheckingPinSupport.
  ///
  /// In zh, this message translates to:
  /// **'正在检查当前桌面是否支持应用内添加小组件…'**
  String get homeWidgetCheckingPinSupport;

  /// No description provided for @homeWidgetPinSupported.
  ///
  /// In zh, this message translates to:
  /// **'支持的话会直接弹出系统添加确认，不是单独的权限弹窗；确认后即可固定到桌面。'**
  String get homeWidgetPinSupported;

  /// No description provided for @homeWidgetPinUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'当前桌面不支持应用内直接添加时，仍可长按桌面 → 小组件 → 轻屿课表 手动添加。'**
  String get homeWidgetPinUnsupported;

  /// No description provided for @homeWidgetBackgroundStyleLabel.
  ///
  /// In zh, this message translates to:
  /// **'背景样式'**
  String get homeWidgetBackgroundStyleLabel;

  /// No description provided for @homeWidgetShowLocationTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示地点'**
  String get homeWidgetShowLocationTitle;

  /// No description provided for @homeWidgetShowLocationSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'关闭后，小组件次级信息会优先显示周次和课程数量。'**
  String get homeWidgetShowLocationSubtitle;

  /// No description provided for @homeWidgetShowCountdownTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示倒计时'**
  String get homeWidgetShowCountdownTitle;

  /// No description provided for @homeWidgetShowCountdownSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'先保留刷新开关，后续会用于下一节课和上课中的剩余时间展示。'**
  String get homeWidgetShowCountdownSubtitle;

  /// No description provided for @homeWidgetCountdownLeadTitle.
  ///
  /// In zh, this message translates to:
  /// **'倒计时提前量'**
  String get homeWidgetCountdownLeadTitle;

  /// No description provided for @homeWidgetCountdownLeadSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'设置上课前多少分钟自动切换到倒计时模式。'**
  String get homeWidgetCountdownLeadSubtitle;

  /// No description provided for @homeWidgetCountdownLeadAlways.
  ///
  /// In zh, this message translates to:
  /// **'始终显示'**
  String get homeWidgetCountdownLeadAlways;

  /// No description provided for @homeWidgetCountdownLeadMinutes.
  ///
  /// In zh, this message translates to:
  /// **'上课前 {minutes} 分钟'**
  String homeWidgetCountdownLeadMinutes(String minutes);

  /// No description provided for @widgetCountdownStyleTitle.
  ///
  /// In zh, this message translates to:
  /// **'倒计时样式'**
  String get widgetCountdownStyleTitle;

  /// No description provided for @homeWidgetHideCompletedTitle.
  ///
  /// In zh, this message translates to:
  /// **'隐藏已上完课程'**
  String get homeWidgetHideCompletedTitle;

  /// No description provided for @homeWidgetHideCompletedSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'开启后，2×2、2×4 和 4×4 课程列表只显示还没结束的课程。'**
  String get homeWidgetHideCompletedSubtitle;

  /// No description provided for @homeWidgetShowTomorrowTitle.
  ///
  /// In zh, this message translates to:
  /// **'课后显示明日课程'**
  String get homeWidgetShowTomorrowTitle;

  /// No description provided for @homeWidgetShowTomorrowSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'开启后，今日课程全部结束时小组件自动切换显示明天的课程。'**
  String get homeWidgetShowTomorrowSubtitle;

  /// No description provided for @homeWidgetHeightAdjustTitle.
  ///
  /// In zh, this message translates to:
  /// **'卡片高度微调'**
  String get homeWidgetHeightAdjustTitle;

  /// No description provided for @defaultLabel.
  ///
  /// In zh, this message translates to:
  /// **'默认'**
  String get defaultLabel;

  /// No description provided for @higherByValue.
  ///
  /// In zh, this message translates to:
  /// **'更高 {value}'**
  String higherByValue(String value);

  /// No description provided for @lowerByValue.
  ///
  /// In zh, this message translates to:
  /// **'更矮 {value}'**
  String lowerByValue(String value);

  /// No description provided for @homeWidgetCornerRadiusTitle.
  ///
  /// In zh, this message translates to:
  /// **'卡片圆角'**
  String get homeWidgetCornerRadiusTitle;

  /// No description provided for @homeWidgetDescriptionTitle.
  ///
  /// In zh, this message translates to:
  /// **'说明'**
  String get homeWidgetDescriptionTitle;

  /// No description provided for @homeWidgetDescriptionText.
  ///
  /// In zh, this message translates to:
  /// **'小组件目前优先展示今日课程。无课状态会保持完整卡片，不会出现空白；如果你切换课表或修改样式，桌面组件也会跟着刷新。'**
  String get homeWidgetDescriptionText;

  /// No description provided for @homeWidgetPinRequested.
  ///
  /// In zh, this message translates to:
  /// **'已发起“{label}”添加请求，请在系统弹窗里确认并放到桌面。'**
  String homeWidgetPinRequested(String label);

  /// No description provided for @homeWidgetPinUnsupportedManual.
  ///
  /// In zh, this message translates to:
  /// **'当前系统桌面不支持应用内直接添加小组件，请长按桌面 → 小组件 → 轻屿课表，再手动添加“{label}”。'**
  String homeWidgetPinUnsupportedManual(String label);

  /// No description provided for @homeWidgetInvalidType.
  ///
  /// In zh, this message translates to:
  /// **'小组件类型无效，请稍后重试。'**
  String get homeWidgetInvalidType;

  /// No description provided for @homeWidgetPinFailedManual.
  ///
  /// In zh, this message translates to:
  /// **'发起添加失败，请长按桌面 → 小组件 → 轻屿课表，再手动添加“{label}”。'**
  String homeWidgetPinFailedManual(String label);

  /// No description provided for @layoutSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'布局与节次'**
  String get layoutSettingsTitle;

  /// No description provided for @layoutDensityTitle.
  ///
  /// In zh, this message translates to:
  /// **'课表密度'**
  String get layoutDensityTitle;

  /// No description provided for @layoutAutoFitHeightTitle.
  ///
  /// In zh, this message translates to:
  /// **'自动充满屏幕高度'**
  String get layoutAutoFitHeightTitle;

  /// No description provided for @layoutAutoFitHeightSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'开启后会按当前节数自动铺满页面底部，不再保留下方空隙。'**
  String get layoutAutoFitHeightSubtitle;

  /// No description provided for @layoutHideWeekendsTitle.
  ///
  /// In zh, this message translates to:
  /// **'隐藏周六周日'**
  String get layoutHideWeekendsTitle;

  /// No description provided for @layoutHideWeekendsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'开启后首页只显示周一到周五，剩余列宽会自动铺满。'**
  String get layoutHideWeekendsSubtitle;

  /// No description provided for @layoutEnableHapticsTitle.
  ///
  /// In zh, this message translates to:
  /// **'启用应用内震动反馈'**
  String get layoutEnableHapticsTitle;

  /// No description provided for @layoutEnableHapticsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'关闭后，页码切换等交互不再触发轻微震动。'**
  String get layoutEnableHapticsSubtitle;

  /// No description provided for @layoutTimeColumnDisplayLabel.
  ///
  /// In zh, this message translates to:
  /// **'首页时间列显示'**
  String get layoutTimeColumnDisplayLabel;

  /// No description provided for @layoutTimeColumnWidthLabel.
  ///
  /// In zh, this message translates to:
  /// **'时间栏宽度'**
  String get layoutTimeColumnWidthLabel;

  /// No description provided for @layoutBackToCurrentWeekButtonStyleLabel.
  ///
  /// In zh, this message translates to:
  /// **'“回本周”按钮样式'**
  String get layoutBackToCurrentWeekButtonStyleLabel;

  /// No description provided for @layoutBackToCurrentWeekButtonStyleHelper.
  ///
  /// In zh, this message translates to:
  /// **'默认保持现在的内嵌样式；也可以改成周视图右下角的小型悬浮按钮。'**
  String get layoutBackToCurrentWeekButtonStyleHelper;

  /// No description provided for @layoutBackToCurrentWeekButtonStyleInline.
  ///
  /// In zh, this message translates to:
  /// **'时间栏内嵌'**
  String get layoutBackToCurrentWeekButtonStyleInline;

  /// No description provided for @layoutBackToCurrentWeekButtonStyleFloating.
  ///
  /// In zh, this message translates to:
  /// **'右下角悬浮'**
  String get layoutBackToCurrentWeekButtonStyleFloating;

  /// No description provided for @layoutBackToCurrentWeekButtonOpacityLabel.
  ///
  /// In zh, this message translates to:
  /// **'悬浮按钮不透明度 {value}%'**
  String layoutBackToCurrentWeekButtonOpacityLabel(int value);

  /// No description provided for @layoutBackToCurrentWeekButtonOpacitySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'只对右下角悬浮样式生效。'**
  String get layoutBackToCurrentWeekButtonOpacitySubtitle;

  /// No description provided for @layoutCourseCardGapLabel.
  ///
  /// In zh, this message translates to:
  /// **'课程卡片间距 {value}'**
  String layoutCourseCardGapLabel(String value);

  /// No description provided for @layoutSectionHeightLabel.
  ///
  /// In zh, this message translates to:
  /// **'课表行高 {value}'**
  String layoutSectionHeightLabel(String value);

  /// No description provided for @layoutCompactFontSizeLabel.
  ///
  /// In zh, this message translates to:
  /// **'紧凑字号 {value}'**
  String layoutCompactFontSizeLabel(String value);

  /// No description provided for @layoutCourseCardFontSizeLabel.
  ///
  /// In zh, this message translates to:
  /// **'课程卡片字号 {value}'**
  String layoutCourseCardFontSizeLabel(String value);

  /// No description provided for @layoutCourseCardDisplayTitle.
  ///
  /// In zh, this message translates to:
  /// **'课程卡片显示'**
  String get layoutCourseCardDisplayTitle;

  /// No description provided for @layoutCourseCardDisplaySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'默认显示课程名、老师和教室；其他信息可按课表自由开关组合。'**
  String get layoutCourseCardDisplaySubtitle;

  /// No description provided for @layoutShowTeacherTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示老师'**
  String get layoutShowTeacherTitle;

  /// No description provided for @layoutShowClassroomTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示教室'**
  String get layoutShowClassroomTitle;

  /// No description provided for @layoutShowTimeTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示时间'**
  String get layoutShowTimeTitle;

  /// No description provided for @layoutShowTimeLabelsTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示上课/下课字样'**
  String get layoutShowTimeLabelsTitle;

  /// No description provided for @layoutShowTimeLabelsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'关闭后仅显示时间点，不显示“上课”“下课”文字。'**
  String get layoutShowTimeLabelsSubtitle;

  /// No description provided for @layoutShowWeeksTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示周数'**
  String get layoutShowWeeksTitle;

  /// No description provided for @layoutShowWeeksSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'例如第 1-16 周、单双周'**
  String get layoutShowWeeksSubtitle;

  /// No description provided for @layoutShowDescriptionTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示课程简介'**
  String get layoutShowDescriptionTitle;

  /// No description provided for @layoutShowDescriptionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'默认关闭，空间不足时会最先被压缩'**
  String get layoutShowDescriptionSubtitle;

  /// No description provided for @layoutShowOtherWeeksTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示非本周课程'**
  String get layoutShowOtherWeeksTitle;

  /// No description provided for @layoutShowOtherWeeksSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'默认关闭，开启后会用灰色半透明显示不在当前周的课程'**
  String get layoutShowOtherWeeksSubtitle;

  /// No description provided for @layoutVerticalAlignLabel.
  ///
  /// In zh, this message translates to:
  /// **'垂直排版'**
  String get layoutVerticalAlignLabel;

  /// No description provided for @layoutHorizontalAlignLabel.
  ///
  /// In zh, this message translates to:
  /// **'水平排版'**
  String get layoutHorizontalAlignLabel;

  /// No description provided for @layoutShowConflictBadgeTitle.
  ///
  /// In zh, this message translates to:
  /// **'首页显示冲突小胶囊'**
  String get layoutShowConflictBadgeTitle;

  /// No description provided for @layoutShowConflictBadgeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'关闭后，首页课表不再对冲突课程显示“冲突”小胶囊。'**
  String get layoutShowConflictBadgeSubtitle;

  /// No description provided for @layoutConflictOpacityLabel.
  ///
  /// In zh, this message translates to:
  /// **'冲突课程透明度 {value}%'**
  String layoutConflictOpacityLabel(int value);

  /// No description provided for @layoutConflictOpacitySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'冲突课程会自动层叠显示，调低透明度后能同时看到多节课。'**
  String get layoutConflictOpacitySubtitle;

  /// No description provided for @layoutTipsText.
  ///
  /// In zh, this message translates to:
  /// **'时间模板已移到设置首页。这里主要调课表行高、时间列、周末显示和课程卡片布局；如果你想只改当前课表的时间，先在时间模板里复制一套再应用。'**
  String get layoutTipsText;

  /// No description provided for @currentWeekCompact.
  ///
  /// In zh, this message translates to:
  /// **'{week}周'**
  String currentWeekCompact(int week);

  /// No description provided for @sampleCourseNumericalControl.
  ///
  /// In zh, this message translates to:
  /// **'数控'**
  String get sampleCourseNumericalControl;

  /// No description provided for @sampleCourseAdvancedMath.
  ///
  /// In zh, this message translates to:
  /// **'高数'**
  String get sampleCourseAdvancedMath;

  /// No description provided for @sampleTeacherZhang.
  ///
  /// In zh, this message translates to:
  /// **'张老师'**
  String get sampleTeacherZhang;

  /// No description provided for @sampleCourseEnglish.
  ///
  /// In zh, this message translates to:
  /// **'英语'**
  String get sampleCourseEnglish;

  /// No description provided for @sampleTeacherLi.
  ///
  /// In zh, this message translates to:
  /// **'李老师'**
  String get sampleTeacherLi;

  /// No description provided for @aboutRepositorySheetTitle.
  ///
  /// In zh, this message translates to:
  /// **'开源仓库'**
  String get aboutRepositorySheetTitle;

  /// No description provided for @aboutRepositorySheetHint.
  ///
  /// In zh, this message translates to:
  /// **'如果你想补学校教务导入适配，建议同时查看教务适配仓 qingyu_warehouse。'**
  String get aboutRepositorySheetHint;

  /// No description provided for @aboutOpenGitHubAction.
  ///
  /// In zh, this message translates to:
  /// **'打开 GitHub'**
  String get aboutOpenGitHubAction;

  /// No description provided for @aboutOpenWarehouseRepoAction.
  ///
  /// In zh, this message translates to:
  /// **'打开教务适配仓'**
  String get aboutOpenWarehouseRepoAction;

  /// No description provided for @copiedRepositoryAddress.
  ///
  /// In zh, this message translates to:
  /// **'已复制仓库地址'**
  String get copiedRepositoryAddress;

  /// No description provided for @copiedWarehouseRepositoryAddress.
  ///
  /// In zh, this message translates to:
  /// **'已复制教务适配仓地址'**
  String get copiedWarehouseRepositoryAddress;

  /// No description provided for @aboutUpdateScreenTitle.
  ///
  /// In zh, this message translates to:
  /// **'版本更新'**
  String get aboutUpdateScreenTitle;

  /// No description provided for @aboutUpdateStatusTitle.
  ///
  /// In zh, this message translates to:
  /// **'更新状态'**
  String get aboutUpdateStatusTitle;

  /// No description provided for @aboutRefreshCheckTooltip.
  ///
  /// In zh, this message translates to:
  /// **'重新检查'**
  String get aboutRefreshCheckTooltip;

  /// No description provided for @aboutCheckingLatestVersion.
  ///
  /// In zh, this message translates to:
  /// **'正在检查最新版本信息…'**
  String get aboutCheckingLatestVersion;

  /// No description provided for @aboutReadVersionFailed.
  ///
  /// In zh, this message translates to:
  /// **'暂时无法读取版本信息，请稍后重试。'**
  String get aboutReadVersionFailed;

  /// No description provided for @aboutReadVersionFailedHint.
  ///
  /// In zh, this message translates to:
  /// **'如果你当前网络访问 GitHub 不稳定，可稍后再试，或切到下面的国内下载方式后重试。'**
  String get aboutReadVersionFailedHint;

  /// No description provided for @aboutViewReleaseAction.
  ///
  /// In zh, this message translates to:
  /// **'查看 Release'**
  String get aboutViewReleaseAction;

  /// No description provided for @aboutDownloadNowAction.
  ///
  /// In zh, this message translates to:
  /// **'立即下载'**
  String get aboutDownloadNowAction;

  /// No description provided for @aboutOpenDownloadPageAction.
  ///
  /// In zh, this message translates to:
  /// **'打开下载页'**
  String get aboutOpenDownloadPageAction;

  /// No description provided for @aboutCurrentVersionLabel.
  ///
  /// In zh, this message translates to:
  /// **'当前版本'**
  String get aboutCurrentVersionLabel;

  /// No description provided for @aboutLatestVersionLabel.
  ///
  /// In zh, this message translates to:
  /// **'最新版本'**
  String get aboutLatestVersionLabel;

  /// No description provided for @aboutUnreleasedLabel.
  ///
  /// In zh, this message translates to:
  /// **'未发布'**
  String get aboutUnreleasedLabel;

  /// No description provided for @aboutVersionChannelLabel.
  ///
  /// In zh, this message translates to:
  /// **'版本通道'**
  String get aboutVersionChannelLabel;

  /// No description provided for @aboutPrereleaseChannel.
  ///
  /// In zh, this message translates to:
  /// **'测试版'**
  String get aboutPrereleaseChannel;

  /// No description provided for @aboutUpdateAvailableHint.
  ///
  /// In zh, this message translates to:
  /// **'你现在只需要点下面的“立即下载”即可。测速、镜像和测试版都已经收进后面的高级选项里。'**
  String get aboutUpdateAvailableHint;

  /// No description provided for @aboutUpdateNoUpdateHint.
  ///
  /// In zh, this message translates to:
  /// **'当前版本已经可正常使用；如果你要体验测试版，可以在后面的高级选项里打开测试版检测。'**
  String get aboutUpdateNoUpdateHint;

  /// No description provided for @aboutUpdatedAt.
  ///
  /// In zh, this message translates to:
  /// **'更新时间：{time}'**
  String aboutUpdatedAt(String time);

  /// No description provided for @aboutUpdateNowTitle.
  ///
  /// In zh, this message translates to:
  /// **'立即更新'**
  String get aboutUpdateNowTitle;

  /// No description provided for @aboutUpdateNowAndroidSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'普通使用只需要点一次立即下载。下载慢、下载失败、要换线路时，再去下面的高级选项。'**
  String get aboutUpdateNowAndroidSubtitle;

  /// No description provided for @aboutUpdateNowOtherSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'当前平台会直接打开下载页面，不会在应用内安装。'**
  String get aboutUpdateNowOtherSubtitle;

  /// No description provided for @aboutMirrorDownloadHint.
  ///
  /// In zh, this message translates to:
  /// **'当前会优先使用国内下载。大多数国内网络直接点“立即下载”就行。'**
  String get aboutMirrorDownloadHint;

  /// No description provided for @aboutOriginalDownloadHint.
  ///
  /// In zh, this message translates to:
  /// **'当前会优先使用国际源下载。如果下载慢或打不开，建议先切回“国内下载”。'**
  String get aboutOriginalDownloadHint;

  /// No description provided for @aboutUseSystemDownloaderAction.
  ///
  /// In zh, this message translates to:
  /// **'使用系统下载器下载'**
  String get aboutUseSystemDownloaderAction;

  /// No description provided for @aboutOpenReleasePageAction.
  ///
  /// In zh, this message translates to:
  /// **'打开 Release 页面'**
  String get aboutOpenReleasePageAction;

  /// No description provided for @aboutDownloadMethodTitle.
  ///
  /// In zh, this message translates to:
  /// **'下载方式'**
  String get aboutDownloadMethodTitle;

  /// No description provided for @aboutDownloadMethodSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'默认推荐国内下载。只有你能稳定访问 GitHub 时，再切到国际源下载。'**
  String get aboutDownloadMethodSubtitle;

  /// No description provided for @aboutDownloadMethodMirror.
  ///
  /// In zh, this message translates to:
  /// **'国内下载'**
  String get aboutDownloadMethodMirror;

  /// No description provided for @aboutDownloadMethodOriginal.
  ///
  /// In zh, this message translates to:
  /// **'国际源下载'**
  String get aboutDownloadMethodOriginal;

  /// No description provided for @aboutMirrorModeHintRecommended.
  ///
  /// In zh, this message translates to:
  /// **'当前使用国内下载 · {current}。系统最近测速更推荐“{recommended}”，需要时可在后面的高级选项里切换。'**
  String aboutMirrorModeHintRecommended(String current, String recommended);

  /// No description provided for @aboutMirrorModeHintCurrent.
  ///
  /// In zh, this message translates to:
  /// **'当前使用国内下载 · {current}。如果下载慢或失败，再到后面的高级选项里测速、换线路或填写自定义地址。'**
  String aboutMirrorModeHintCurrent(String current);

  /// No description provided for @aboutOriginalModeHint.
  ///
  /// In zh, this message translates to:
  /// **'当前使用国际源下载。只有你网络能稳定访问 GitHub 时才建议这样设置；否则请切回国内下载。'**
  String get aboutOriginalModeHint;

  /// No description provided for @aboutReleaseNotesTitle.
  ///
  /// In zh, this message translates to:
  /// **'本次更新说明'**
  String get aboutReleaseNotesTitle;

  /// No description provided for @aboutReleaseNotesSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'显示当前检测到版本的 Release 说明。'**
  String get aboutReleaseNotesSubtitle;

  /// No description provided for @aboutAdvancedOptionsTitle.
  ///
  /// In zh, this message translates to:
  /// **'高级选项'**
  String get aboutAdvancedOptionsTitle;

  /// No description provided for @aboutAdvancedOptionsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'只有下载慢、要手动切线路、或要检测测试版时再展开。'**
  String get aboutAdvancedOptionsSubtitle;

  /// No description provided for @aboutMirrorSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'下载线路与镜像'**
  String get aboutMirrorSectionTitle;

  /// No description provided for @aboutMirrorSectionMirrorHint.
  ///
  /// In zh, this message translates to:
  /// **'当前使用国内下载。这里可以手动切线路、测速推荐，或填写自定义下载地址。'**
  String get aboutMirrorSectionMirrorHint;

  /// No description provided for @aboutMirrorSectionOriginalHint.
  ///
  /// In zh, this message translates to:
  /// **'你现在使用的是国际源下载。下面的线路设置只有在切回“国内下载”后才会生效。'**
  String get aboutMirrorSectionOriginalHint;

  /// No description provided for @aboutFillCustomMirrorFirst.
  ///
  /// In zh, this message translates to:
  /// **'先填写自定义下载地址'**
  String get aboutFillCustomMirrorFirst;

  /// No description provided for @aboutCurrentCustomMirrorTitle.
  ///
  /// In zh, this message translates to:
  /// **'当前自定义下载地址'**
  String get aboutCurrentCustomMirrorTitle;

  /// No description provided for @aboutCurrentMirrorTitle.
  ///
  /// In zh, this message translates to:
  /// **'当前下载线路地址'**
  String get aboutCurrentMirrorTitle;

  /// No description provided for @aboutCurrentCustomMirrorHint.
  ///
  /// In zh, this message translates to:
  /// **'当前正在使用你手动填写的下载地址。'**
  String get aboutCurrentCustomMirrorHint;

  /// No description provided for @aboutCurrentMirrorHint.
  ///
  /// In zh, this message translates to:
  /// **'如果当前线路访问失败，可以切到其他内置线路，或改用自定义地址。'**
  String get aboutCurrentMirrorHint;

  /// No description provided for @aboutProbeMirrorsAction.
  ///
  /// In zh, this message translates to:
  /// **'测速并推荐'**
  String get aboutProbeMirrorsAction;

  /// No description provided for @aboutProbingMirrors.
  ///
  /// In zh, this message translates to:
  /// **'测速中…'**
  String get aboutProbingMirrors;

  /// No description provided for @aboutEditCustomMirrorAction.
  ///
  /// In zh, this message translates to:
  /// **'修改自定义地址'**
  String get aboutEditCustomMirrorAction;

  /// No description provided for @aboutSetCustomMirrorAction.
  ///
  /// In zh, this message translates to:
  /// **'填写自定义地址'**
  String get aboutSetCustomMirrorAction;

  /// No description provided for @aboutSwitchToRecommendedAction.
  ///
  /// In zh, this message translates to:
  /// **'切到推荐：{label}'**
  String aboutSwitchToRecommendedAction(String label);

  /// No description provided for @aboutMirrorDisabledHint.
  ///
  /// In zh, this message translates to:
  /// **'当前没有使用国内下载，所以这里的线路设置暂时不会生效。需要的话，请先在上面的“下载方式”里切回国内下载。'**
  String get aboutMirrorDisabledHint;

  /// No description provided for @aboutRecentProbeResultsTitle.
  ///
  /// In zh, this message translates to:
  /// **'最近测速结果'**
  String get aboutRecentProbeResultsTitle;

  /// No description provided for @aboutUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'不可用'**
  String get aboutUnavailable;

  /// No description provided for @aboutRecommended.
  ///
  /// In zh, this message translates to:
  /// **'推荐'**
  String get aboutRecommended;

  /// No description provided for @aboutCheckPrereleaseTitle.
  ///
  /// In zh, this message translates to:
  /// **'检测测试版本'**
  String get aboutCheckPrereleaseTitle;

  /// No description provided for @aboutCheckPrereleaseSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'打开后会把测试版也纳入更新检查；普通使用建议关闭。'**
  String get aboutCheckPrereleaseSubtitle;

  /// No description provided for @aboutDiagnosticsTitle.
  ///
  /// In zh, this message translates to:
  /// **'测试与诊断'**
  String get aboutDiagnosticsTitle;

  /// No description provided for @aboutDiagnosticsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'只有遇到“超级岛没弹出”或需要给开发者反馈时再展开。'**
  String get aboutDiagnosticsSubtitle;

  /// No description provided for @aboutRecordDiagnosticsTitle.
  ///
  /// In zh, this message translates to:
  /// **'记录应用日志'**
  String get aboutRecordDiagnosticsTitle;

  /// No description provided for @aboutRecordDiagnosticsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'打开后会在本地持续记录关键日志，仅用于排查“该弹不弹”等问题。'**
  String get aboutRecordDiagnosticsSubtitle;

  /// No description provided for @aboutExportDiagnosticsAction.
  ///
  /// In zh, this message translates to:
  /// **'导出应用日志'**
  String get aboutExportDiagnosticsAction;

  /// No description provided for @aboutViewPhoneLogsAction.
  ///
  /// In zh, this message translates to:
  /// **'打开日志页'**
  String get aboutViewPhoneLogsAction;

  /// No description provided for @aboutClearAndRecollectAction.
  ///
  /// In zh, this message translates to:
  /// **'清空并重新收集'**
  String get aboutClearAndRecollectAction;

  /// No description provided for @aboutLiveDiagnosticsEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已开启超级岛诊断日志'**
  String get aboutLiveDiagnosticsEnabled;

  /// No description provided for @aboutLiveDiagnosticsDisabled.
  ///
  /// In zh, this message translates to:
  /// **'已关闭超级岛诊断日志'**
  String get aboutLiveDiagnosticsDisabled;

  /// No description provided for @aboutNoDiagnosticsExportYet.
  ///
  /// In zh, this message translates to:
  /// **'还没有可导出的超级岛诊断日志'**
  String get aboutNoDiagnosticsExportYet;

  /// No description provided for @aboutProbeNoMirrorFound.
  ///
  /// In zh, this message translates to:
  /// **'测速完成，但暂时没有发现可用镜像线路'**
  String get aboutProbeNoMirrorFound;

  /// No description provided for @aboutProbeCurrentFastest.
  ///
  /// In zh, this message translates to:
  /// **'测速完成，当前线路“{label}”已是最快可用线路'**
  String aboutProbeCurrentFastest(String label);

  /// No description provided for @aboutProbeRecommendSwitch.
  ///
  /// In zh, this message translates to:
  /// **'测速完成，推荐切换到“{label}”'**
  String aboutProbeRecommendSwitch(String label);

  /// No description provided for @switchAction.
  ///
  /// In zh, this message translates to:
  /// **'切换'**
  String get switchAction;

  /// No description provided for @aboutSwitchToMirrorAfterError.
  ///
  /// In zh, this message translates to:
  /// **'{error}，可切到国内镜像后再试'**
  String aboutSwitchToMirrorAfterError(String error);

  /// No description provided for @aboutSwitchPresetAfterError.
  ///
  /// In zh, this message translates to:
  /// **'{error}，建议切换到“{label}”后重试'**
  String aboutSwitchPresetAfterError(String error, String label);

  /// No description provided for @aboutSetMirrorSourceTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置镜像源'**
  String get aboutSetMirrorSourceTitle;

  /// No description provided for @aboutMirrorPrefixLabel.
  ///
  /// In zh, this message translates to:
  /// **'镜像前缀'**
  String get aboutMirrorPrefixLabel;

  /// No description provided for @aboutMirrorPrefixInvalid.
  ///
  /// In zh, this message translates to:
  /// **'镜像源格式不正确，请输入完整的 http 或 https 地址'**
  String get aboutMirrorPrefixInvalid;

  /// No description provided for @aboutMirrorSaved.
  ///
  /// In zh, this message translates to:
  /// **'镜像源已保存'**
  String get aboutMirrorSaved;

  /// No description provided for @aboutDownloadCancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消下载'**
  String get aboutDownloadCancelled;

  /// No description provided for @aboutInstallReady.
  ///
  /// In zh, this message translates to:
  /// **'安装包已准备好，已尝试打开安装界面；如果系统没有弹出，请稍后从通知或文件管理器手动安装'**
  String get aboutInstallReady;

  /// No description provided for @aboutUpdatePackageTitle.
  ///
  /// In zh, this message translates to:
  /// **'轻屿课表更新包'**
  String get aboutUpdatePackageTitle;

  /// No description provided for @aboutUpdatePackageDescription.
  ///
  /// In zh, this message translates to:
  /// **'已交给系统下载管理器下载，完成后可直接从系统通知安装。'**
  String get aboutUpdatePackageDescription;

  /// No description provided for @aboutSystemDownloaderQueued.
  ///
  /// In zh, this message translates to:
  /// **'已交给系统下载管理器，请在系统通知或下载列表里查看进度'**
  String get aboutSystemDownloaderQueued;

  /// No description provided for @aboutSystemDownloaderFailed.
  ///
  /// In zh, this message translates to:
  /// **'调用系统下载管理器失败'**
  String get aboutSystemDownloaderFailed;

  /// No description provided for @aboutDownloadCancelling.
  ///
  /// In zh, this message translates to:
  /// **'正在取消下载…'**
  String get aboutDownloadCancelling;

  /// No description provided for @aboutDownloadingBytes.
  ///
  /// In zh, this message translates to:
  /// **'正在下载更新 {value}'**
  String aboutDownloadingBytes(String value);

  /// No description provided for @aboutDownloadingPercent.
  ///
  /// In zh, this message translates to:
  /// **'正在下载更新 {value}%'**
  String aboutDownloadingPercent(String value);

  /// No description provided for @aboutMirrorUnknownSizeHint.
  ///
  /// In zh, this message translates to:
  /// **'镜像源未返回文件总大小，先显示已下载体积'**
  String get aboutMirrorUnknownSizeHint;

  /// No description provided for @aboutCancelDownloadAction.
  ///
  /// In zh, this message translates to:
  /// **'取消下载'**
  String get aboutCancelDownloadAction;

  /// No description provided for @aboutContributorsScreenTitle.
  ///
  /// In zh, this message translates to:
  /// **'代码贡献者'**
  String get aboutContributorsScreenTitle;

  /// No description provided for @aboutDevelopersTitle.
  ///
  /// In zh, this message translates to:
  /// **'开发人员'**
  String get aboutDevelopersTitle;

  /// No description provided for @aboutDeveloperMaintainerSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'轻屿课表开发与维护'**
  String get aboutDeveloperMaintainerSubtitle;

  /// No description provided for @aboutWarehouseMaintainersTitle.
  ///
  /// In zh, this message translates to:
  /// **'教务导入适配者'**
  String get aboutWarehouseMaintainersTitle;

  /// No description provided for @aboutWarehouseMaintainersIntro.
  ///
  /// In zh, this message translates to:
  /// **'以下名单来自 qingyu_warehouse 适配仓的 maintainer 字段汇总。若本地已有缓存，会先显示缓存，再后台刷新。'**
  String get aboutWarehouseMaintainersIntro;

  /// No description provided for @aboutWarehouseMaintainersLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'暂时无法读取适配者名单：{error}'**
  String aboutWarehouseMaintainersLoadFailed(String error);

  /// No description provided for @aboutWarehouseMaintainersEmpty.
  ///
  /// In zh, this message translates to:
  /// **'当前还没有读取到适配者信息。'**
  String get aboutWarehouseMaintainersEmpty;

  /// No description provided for @aboutWarehouseMaintainerCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个适配项'**
  String aboutWarehouseMaintainerCount(int count);

  /// No description provided for @aboutParticipateWarehouseTitle.
  ///
  /// In zh, this message translates to:
  /// **'参与教务适配'**
  String get aboutParticipateWarehouseTitle;

  /// No description provided for @aboutParticipateWarehouseSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'如果你会抓包、网页调试、JavaScript，或者愿意长期维护自己学校的教务系统，欢迎去 qingyu_warehouse 提交新的学校适配与修复。'**
  String get aboutParticipateWarehouseSubtitle;

  /// No description provided for @importFileReadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取所选文件'**
  String get importFileReadFailed;

  /// No description provided for @importReplaceExistingTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入课程'**
  String get importReplaceExistingTitle;

  /// No description provided for @importReplaceExistingMessage.
  ///
  /// In zh, this message translates to:
  /// **'导入 {name} 时，是否替换现有课程？'**
  String importReplaceExistingMessage(String name);

  /// No description provided for @importNoCoursesRecognized.
  ///
  /// In zh, this message translates to:
  /// **'未识别到可导入课程'**
  String get importNoCoursesRecognized;

  /// No description provided for @importConfirmSemesterMappingTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认开学日期和周次对应'**
  String get importConfirmSemesterMappingTitle;

  /// No description provided for @importConfirmSemesterMappingSubtitleIcs.
  ///
  /// In zh, this message translates to:
  /// **'请选择学校校历的开学日期。系统已根据文件里最早的上课日期给出默认周次对应，你也可以手动调整。'**
  String get importConfirmSemesterMappingSubtitleIcs;

  /// No description provided for @importOverwriteCount.
  ///
  /// In zh, this message translates to:
  /// **'已覆盖导入 {count} 条课程'**
  String importOverwriteCount(int count);

  /// No description provided for @importUpdatedCount.
  ///
  /// In zh, this message translates to:
  /// **'已更新课表：新增或更新 {count} 条课程'**
  String importUpdatedCount(int count);

  /// No description provided for @importNoCourseChanges.
  ///
  /// In zh, this message translates to:
  /// **'没有需要新增或更新的课程'**
  String get importNoCourseChanges;

  /// No description provided for @aiImportTitle.
  ///
  /// In zh, this message translates to:
  /// **'识图导入'**
  String get aiImportTitle;

  /// No description provided for @aiPreviewSummary.
  ///
  /// In zh, this message translates to:
  /// **'识别到 {courseCount} 门课，最高到第 {sectionCount} 节{warningSuffix}'**
  String aiPreviewSummary(
    int courseCount,
    int sectionCount,
    String warningSuffix,
  );

  /// No description provided for @aiWarningCountSuffix.
  ///
  /// In zh, this message translates to:
  /// **'，{count} 条提醒'**
  String aiWarningCountSuffix(int count);

  /// No description provided for @aiWorkflowCompactTitle.
  ///
  /// In zh, this message translates to:
  /// **'复制提示词 -> 豆包识图 -> 导入'**
  String get aiWorkflowCompactTitle;

  /// No description provided for @aiWorkflowCompactSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'豆包专家模式 -> 复制 JSON -> 选择开学日期'**
  String get aiWorkflowCompactSubtitle;

  /// No description provided for @aiWorkflowTitle.
  ///
  /// In zh, this message translates to:
  /// **'复制提示词 -> 豆包识图 -> 粘贴 JSON -> 导入'**
  String get aiWorkflowTitle;

  /// No description provided for @aiWorkflowSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'先复制提示词，再到豆包左下角切换为专家模式，把课表截图和提示词一起发过去。把豆包返回的 JSON 复制回这里，点击导入后再选择开学日期。'**
  String get aiWorkflowSubtitle;

  /// No description provided for @aiPromptShortAction.
  ///
  /// In zh, this message translates to:
  /// **'提示词'**
  String get aiPromptShortAction;

  /// No description provided for @aiExpertModeSuggestion.
  ///
  /// In zh, this message translates to:
  /// **'建议豆包专家模式，支持多图，截图需带星期表头。'**
  String get aiExpertModeSuggestion;

  /// No description provided for @aiHintExpertMode.
  ///
  /// In zh, this message translates to:
  /// **'先切到豆包专家模式'**
  String get aiHintExpertMode;

  /// No description provided for @aiHintSendScreenshot.
  ///
  /// In zh, this message translates to:
  /// **'截图和提示词一起发'**
  String get aiHintSendScreenshot;

  /// No description provided for @aiHintCopyJsonBack.
  ///
  /// In zh, this message translates to:
  /// **'返回结果复制 JSON'**
  String get aiHintCopyJsonBack;

  /// No description provided for @aiHintPickSemesterAfterImport.
  ///
  /// In zh, this message translates to:
  /// **'导入后再选开学日期'**
  String get aiHintPickSemesterAfterImport;

  /// No description provided for @jsonLabelShort.
  ///
  /// In zh, this message translates to:
  /// **'JSON'**
  String get jsonLabelShort;

  /// No description provided for @aiPasteJsonTitle.
  ///
  /// In zh, this message translates to:
  /// **'粘贴 AI 返回的 JSON'**
  String get aiPasteJsonTitle;

  /// No description provided for @aiCourseCountChip.
  ///
  /// In zh, this message translates to:
  /// **'{count} 门课'**
  String aiCourseCountChip(int count);

  /// No description provided for @aiParseFailedChip.
  ///
  /// In zh, this message translates to:
  /// **'解析失败'**
  String get aiParseFailedChip;

  /// No description provided for @aiPasteJsonHintShort.
  ///
  /// In zh, this message translates to:
  /// **'粘贴 AI 返回的 JSON'**
  String get aiPasteJsonHintShort;

  /// No description provided for @aiPasteJsonHintLong.
  ///
  /// In zh, this message translates to:
  /// **'把豆包返回的 JSON 原样粘贴到这里，然后点击导入。支持纯 JSON，也兼容 ```json 代码块。'**
  String get aiPasteJsonHintLong;

  /// No description provided for @detailAction.
  ///
  /// In zh, this message translates to:
  /// **'详情'**
  String get detailAction;

  /// No description provided for @aiParseErrorTitle.
  ///
  /// In zh, this message translates to:
  /// **'解析错误'**
  String get aiParseErrorTitle;

  /// No description provided for @viewDetailsAction.
  ///
  /// In zh, this message translates to:
  /// **'查看详情'**
  String get viewDetailsAction;

  /// No description provided for @aiWorkflowFooter.
  ///
  /// In zh, this message translates to:
  /// **'复制提示词 -> 豆包发送截图和提示词 -> 把 JSON 贴回这里 -> 点击导入 -> 选择开学日期。'**
  String get aiWorkflowFooter;

  /// No description provided for @previewAction.
  ///
  /// In zh, this message translates to:
  /// **'预览'**
  String get previewAction;

  /// No description provided for @confirmImportAction.
  ///
  /// In zh, this message translates to:
  /// **'确认导入'**
  String get confirmImportAction;

  /// No description provided for @promptCopiedHint.
  ///
  /// In zh, this message translates to:
  /// **'提示词已复制，去豆包发送截图和提示词'**
  String get promptCopiedHint;

  /// No description provided for @clipboardNoText.
  ///
  /// In zh, this message translates to:
  /// **'剪贴板里没有可用文本'**
  String get clipboardNoText;

  /// No description provided for @aiPromptSheetTitle.
  ///
  /// In zh, this message translates to:
  /// **'识图提示词'**
  String get aiPromptSheetTitle;

  /// No description provided for @aiPromptSheetSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'建议使用豆包。先把豆包左下角切换为专家模式，再把下面整段提示词和课表截图一起发过去，让它只返回 JSON。生成后把 JSON 复制回本页，点击导入后再选择开学日期。'**
  String get aiPromptSheetSubtitle;

  /// No description provided for @aiPreviewTitle.
  ///
  /// In zh, this message translates to:
  /// **'解析预览'**
  String get aiPreviewTitle;

  /// No description provided for @aiPasteJsonFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先粘贴 AI 返回的 JSON'**
  String get aiPasteJsonFirst;

  /// No description provided for @aiParseFailedIncompleteJson.
  ///
  /// In zh, this message translates to:
  /// **'解析失败，请确认粘贴的是完整 JSON'**
  String get aiParseFailedIncompleteJson;

  /// No description provided for @importAiResultTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入 AI 解析结果'**
  String get importAiResultTitle;

  /// No description provided for @importAiReplaceMessage.
  ///
  /// In zh, this message translates to:
  /// **'是否用当前这份 AI 解析结果替换现有课程？'**
  String get importAiReplaceMessage;

  /// No description provided for @importConfirmSemesterMappingSubtitleAi.
  ///
  /// In zh, this message translates to:
  /// **'请选择学校校历的开学日期，再确认课表里的第 1 周对应校历第几周。如果学校第一周没课，这里通常要改成第 2 周。'**
  String get importConfirmSemesterMappingSubtitleAi;

  /// No description provided for @aiWarningExtraSuffix.
  ///
  /// In zh, this message translates to:
  /// **'，另有 {count} 条识别提醒'**
  String aiWarningExtraSuffix(int count);

  /// No description provided for @pasteAction.
  ///
  /// In zh, this message translates to:
  /// **'粘贴'**
  String get pasteAction;

  /// No description provided for @importConfirmSemesterMappingSubtitleWarehouse.
  ///
  /// In zh, this message translates to:
  /// **'教务脚本已返回课程周次，请确认校历开学日期；如果学校前几周没有课，可把“课表第 1 周”对应到校历后面的周次。'**
  String get importConfirmSemesterMappingSubtitleWarehouse;

  /// No description provided for @aiPreviewCourseCount.
  ///
  /// In zh, this message translates to:
  /// **'课程数量：{count}'**
  String aiPreviewCourseCount(int count);

  /// No description provided for @aiPreviewMaxSection.
  ///
  /// In zh, this message translates to:
  /// **'最大节次：第 {section} 节'**
  String aiPreviewMaxSection(int section);

  /// No description provided for @aiPreviewWarningsTitle.
  ///
  /// In zh, this message translates to:
  /// **'识别提醒'**
  String get aiPreviewWarningsTitle;

  /// No description provided for @aiPreviewCoursesTitle.
  ///
  /// In zh, this message translates to:
  /// **'课程预览'**
  String get aiPreviewCoursesTitle;

  /// No description provided for @aiPreviewRemainingCourses.
  ///
  /// In zh, this message translates to:
  /// **'其余 {count} 条将在导入后写入当前课表'**
  String aiPreviewRemainingCourses(int count);

  /// No description provided for @warehouseMissingSchoolTitle.
  ///
  /// In zh, this message translates to:
  /// **'学校列表里没有你的学校？'**
  String get warehouseMissingSchoolTitle;

  /// No description provided for @warehouseMissingSchoolSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'去反馈页提一个 Issue 就行。建议一起写上学校名称、教务系统网址、登录后课表页链接或截图，这样更方便补适配。'**
  String get warehouseMissingSchoolSubtitle;

  /// No description provided for @laterAction.
  ///
  /// In zh, this message translates to:
  /// **'稍后再说'**
  String get laterAction;

  /// No description provided for @goFeedbackAction.
  ///
  /// In zh, this message translates to:
  /// **'去反馈页'**
  String get goFeedbackAction;

  /// No description provided for @warehouseFeedbackMissingSchoolTitle.
  ///
  /// In zh, this message translates to:
  /// **'缺少学校？去反馈'**
  String get warehouseFeedbackMissingSchoolTitle;

  /// No description provided for @warehouseCustomDebugTitle.
  ///
  /// In zh, this message translates to:
  /// **'自定义调试'**
  String get warehouseCustomDebugTitle;

  /// No description provided for @warehouseRootLoadFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂时无法读取适配仓'**
  String get warehouseRootLoadFailedTitle;

  /// No description provided for @searchSchoolHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索学校名称、首字母或代码'**
  String get searchSchoolHint;

  /// No description provided for @clearSearchTooltip.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get clearSearchTooltip;

  /// No description provided for @noMatchingSchools.
  ///
  /// In zh, this message translates to:
  /// **'没有找到匹配的学校'**
  String get noMatchingSchools;

  /// No description provided for @noAvailableSchools.
  ///
  /// In zh, this message translates to:
  /// **'暂无可用学校'**
  String get noAvailableSchools;

  /// No description provided for @searchSchoolSuggestion.
  ///
  /// In zh, this message translates to:
  /// **'试试学校全称、首字母或仓库里的学校代码。'**
  String get searchSchoolSuggestion;

  /// No description provided for @deleteDebugRecordTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除调试记录'**
  String get deleteDebugRecordTitle;

  /// No description provided for @deleteDebugRecordMessage.
  ///
  /// In zh, this message translates to:
  /// **'确认删除“{name}”？删除后不会影响已经导入的课程。'**
  String deleteDebugRecordMessage(String name);

  /// No description provided for @deletedDebugRecord.
  ///
  /// In zh, this message translates to:
  /// **'已删除调试记录：{name}'**
  String deletedDebugRecord(String name);

  /// No description provided for @customDebugName.
  ///
  /// In zh, this message translates to:
  /// **'自定义调试'**
  String get customDebugName;

  /// No description provided for @localDebugMaintainer.
  ///
  /// In zh, this message translates to:
  /// **'本地调试'**
  String get localDebugMaintainer;

  /// No description provided for @customDebugDescription.
  ///
  /// In zh, this message translates to:
  /// **'用户保存的自定义教务调试脚本'**
  String get customDebugDescription;

  /// No description provided for @addDebugRecordTooltip.
  ///
  /// In zh, this message translates to:
  /// **'新增调试记录'**
  String get addDebugRecordTooltip;

  /// No description provided for @customDebugIntroTitle.
  ///
  /// In zh, this message translates to:
  /// **'这里放你自己的教务调试记录'**
  String get customDebugIntroTitle;

  /// No description provided for @customDebugIntroSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'每条记录都可以保存自定义网址和整段脚本。保存后下次直接点“开始调试”就能复用，不需要再去某个学校详情页里找入口。'**
  String get customDebugIntroSubtitle;

  /// No description provided for @addDebugRecordAction.
  ///
  /// In zh, this message translates to:
  /// **'新增调试记录'**
  String get addDebugRecordAction;

  /// No description provided for @noSavedDebugRecords.
  ///
  /// In zh, this message translates to:
  /// **'还没有保存的调试记录'**
  String get noSavedDebugRecords;

  /// No description provided for @noSavedDebugRecordsHint.
  ///
  /// In zh, this message translates to:
  /// **'先新增一条，把网址和脚本贴进去，以后就能直接复用。'**
  String get noSavedDebugRecordsHint;

  /// No description provided for @debugScriptLength.
  ///
  /// In zh, this message translates to:
  /// **'脚本 {count} 字符'**
  String debugScriptLength(int count);

  /// No description provided for @startDebugAction.
  ///
  /// In zh, this message translates to:
  /// **'开始调试'**
  String get startDebugAction;

  /// No description provided for @editAction.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get editAction;

  /// No description provided for @scriptFileReadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取脚本文件'**
  String get scriptFileReadFailed;

  /// No description provided for @scriptFileImported.
  ///
  /// In zh, this message translates to:
  /// **'已导入脚本文件：{name}'**
  String scriptFileImported(String name);

  /// No description provided for @scriptFileImportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入脚本文件失败：{error}'**
  String scriptFileImportFailed(String error);

  /// No description provided for @debugRecordNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请先填写调试记录名称'**
  String get debugRecordNameRequired;

  /// No description provided for @invalidImportUrl.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的教务网址'**
  String get invalidImportUrl;

  /// No description provided for @debugScriptRequired.
  ///
  /// In zh, this message translates to:
  /// **'请先填写或导入脚本'**
  String get debugScriptRequired;

  /// No description provided for @editDebugRecordTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑调试记录'**
  String get editDebugRecordTitle;

  /// No description provided for @addDebugRecordTitle.
  ///
  /// In zh, this message translates to:
  /// **'新增调试记录'**
  String get addDebugRecordTitle;

  /// No description provided for @savingAction.
  ///
  /// In zh, this message translates to:
  /// **'保存中…'**
  String get savingAction;

  /// No description provided for @debugRecordFormula.
  ///
  /// In zh, this message translates to:
  /// **'一条记录 = 一个网址 + 一段脚本'**
  String get debugRecordFormula;

  /// No description provided for @debugRecordFormulaSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'适合你反复调试同一个学校，或者不同学校保留多套脚本。保存后会一直保留，后面可随时修改。'**
  String get debugRecordFormulaSubtitle;

  /// No description provided for @debugRecordNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'记录名称'**
  String get debugRecordNameLabel;

  /// No description provided for @debugRecordNameHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：重庆机电-新版教务'**
  String get debugRecordNameHint;

  /// No description provided for @importUrlLabel.
  ///
  /// In zh, this message translates to:
  /// **'教务网址'**
  String get importUrlLabel;

  /// No description provided for @debugScriptLabel.
  ///
  /// In zh, this message translates to:
  /// **'调试脚本'**
  String get debugScriptLabel;

  /// No description provided for @importFromFileAction.
  ///
  /// In zh, this message translates to:
  /// **'从文件导入'**
  String get importFromFileAction;

  /// No description provided for @debugScriptHint.
  ///
  /// In zh, this message translates to:
  /// **'把浏览器扩展导出的完整脚本粘贴到这里'**
  String get debugScriptHint;

  /// No description provided for @saveDebugRecordAction.
  ///
  /// In zh, this message translates to:
  /// **'保存调试记录'**
  String get saveDebugRecordAction;

  /// No description provided for @fillUrlThenImport.
  ///
  /// In zh, this message translates to:
  /// **'填写网址后导入'**
  String get fillUrlThenImport;

  /// No description provided for @webLoginImport.
  ///
  /// In zh, this message translates to:
  /// **'网页登录导入'**
  String get webLoginImport;

  /// No description provided for @savedImportUrlHint.
  ///
  /// In zh, this message translates to:
  /// **'已保存教务网址，下次可直接导入'**
  String get savedImportUrlHint;

  /// No description provided for @adapterIntroSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'可查看适配器信息、登录入口与脚本状态。'**
  String get adapterIntroSubtitle;

  /// No description provided for @schoolLabel.
  ///
  /// In zh, this message translates to:
  /// **'学校'**
  String get schoolLabel;

  /// No description provided for @categoryLabel.
  ///
  /// In zh, this message translates to:
  /// **'类别'**
  String get categoryLabel;

  /// No description provided for @maintainerLabel.
  ///
  /// In zh, this message translates to:
  /// **'维护者'**
  String get maintainerLabel;

  /// No description provided for @adapterInfoTitle.
  ///
  /// In zh, this message translates to:
  /// **'适配器信息'**
  String get adapterInfoTitle;

  /// No description provided for @scriptPathLabel.
  ///
  /// In zh, this message translates to:
  /// **'脚本路径'**
  String get scriptPathLabel;

  /// No description provided for @loginEntryLabel.
  ///
  /// In zh, this message translates to:
  /// **'登录入口'**
  String get loginEntryLabel;

  /// No description provided for @unsetConfigLabel.
  ///
  /// In zh, this message translates to:
  /// **'未配置'**
  String get unsetConfigLabel;

  /// No description provided for @adapterOverrideImportUrlHint.
  ///
  /// In zh, this message translates to:
  /// **'当前使用你手动覆盖的登录地址'**
  String get adapterOverrideImportUrlHint;

  /// No description provided for @repositoryLabel.
  ///
  /// In zh, this message translates to:
  /// **'仓库'**
  String get repositoryLabel;

  /// No description provided for @scriptStatusTitle.
  ///
  /// In zh, this message translates to:
  /// **'脚本状态'**
  String get scriptStatusTitle;

  /// No description provided for @scriptLoadedLength.
  ///
  /// In zh, this message translates to:
  /// **'脚本已成功读取，长度 {count} 字符。'**
  String scriptLoadedLength(int count);

  /// No description provided for @scriptEmpty.
  ///
  /// In zh, this message translates to:
  /// **'脚本为空'**
  String get scriptEmpty;

  /// No description provided for @openLoginInAppAction.
  ///
  /// In zh, this message translates to:
  /// **'应用内打开登录入口'**
  String get openLoginInAppAction;

  /// No description provided for @openInSystemBrowserAction.
  ///
  /// In zh, this message translates to:
  /// **'系统浏览器打开'**
  String get openInSystemBrowserAction;

  /// No description provided for @copiedImportLoginUrl.
  ///
  /// In zh, this message translates to:
  /// **'已复制教务登录地址'**
  String get copiedImportLoginUrl;

  /// No description provided for @copyLoginAddressAction.
  ///
  /// In zh, this message translates to:
  /// **'复制登录地址'**
  String get copyLoginAddressAction;

  /// No description provided for @copiedScriptRawUrl.
  ///
  /// In zh, this message translates to:
  /// **'已复制脚本原始地址'**
  String get copiedScriptRawUrl;

  /// No description provided for @copyScriptAddressAction.
  ///
  /// In zh, this message translates to:
  /// **'复制脚本地址'**
  String get copyScriptAddressAction;

  /// No description provided for @customLoginAddressAction.
  ///
  /// In zh, this message translates to:
  /// **'自定义登录地址'**
  String get customLoginAddressAction;

  /// No description provided for @editCustomLoginAddressAction.
  ///
  /// In zh, this message translates to:
  /// **'修改自定义地址'**
  String get editCustomLoginAddressAction;

  /// No description provided for @clearCustomLoginAddressAction.
  ///
  /// In zh, this message translates to:
  /// **'清除自定义地址'**
  String get clearCustomLoginAddressAction;

  /// No description provided for @restoreRepositoryAddressAction.
  ///
  /// In zh, this message translates to:
  /// **'恢复仓库地址'**
  String get restoreRepositoryAddressAction;

  /// No description provided for @invalidLoginEntryUrl.
  ///
  /// In zh, this message translates to:
  /// **'登录入口地址无效'**
  String get invalidLoginEntryUrl;

  /// No description provided for @savedCustomLoginAddress.
  ///
  /// In zh, this message translates to:
  /// **'已保存自定义登录地址'**
  String get savedCustomLoginAddress;

  /// No description provided for @clearedCustomLoginAddress.
  ///
  /// In zh, this message translates to:
  /// **'已清除自定义登录地址'**
  String get clearedCustomLoginAddress;

  /// No description provided for @restoredRepositoryImportUrl.
  ///
  /// In zh, this message translates to:
  /// **'已恢复仓库里的登录地址'**
  String get restoredRepositoryImportUrl;

  /// No description provided for @backToCurrentWeekAction.
  ///
  /// In zh, this message translates to:
  /// **'回本周'**
  String get backToCurrentWeekAction;

  /// No description provided for @nonCurrentWeekLabel.
  ///
  /// In zh, this message translates to:
  /// **'非本周'**
  String get nonCurrentWeekLabel;

  /// No description provided for @conflictLabel.
  ///
  /// In zh, this message translates to:
  /// **'冲突'**
  String get conflictLabel;

  /// No description provided for @selectWeekTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择周次'**
  String get selectWeekTitle;

  /// No description provided for @availableWeeksCount.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 周'**
  String availableWeeksCount(int count);

  /// No description provided for @goToWeekLabel.
  ///
  /// In zh, this message translates to:
  /// **'第 {week} 周'**
  String goToWeekLabel(int week);

  /// No description provided for @homeMenuUpdateTitle.
  ///
  /// In zh, this message translates to:
  /// **'软件更新'**
  String get homeMenuUpdateTitle;

  /// No description provided for @homeMenuProfilesTitle.
  ///
  /// In zh, this message translates to:
  /// **'课表管理'**
  String get homeMenuProfilesTitle;

  /// No description provided for @homeMenuOverviewTitle.
  ///
  /// In zh, this message translates to:
  /// **'课程总览'**
  String get homeMenuOverviewTitle;

  /// No description provided for @homeMenuAddCourseTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加课程'**
  String get homeMenuAddCourseTitle;

  /// No description provided for @homeMenuImportTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入课程'**
  String get homeMenuImportTitle;

  /// No description provided for @homeMenuSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'课表设置'**
  String get homeMenuSettingsTitle;

  /// No description provided for @homeMenuCoffeeTitle.
  ///
  /// In zh, this message translates to:
  /// **'请喝咖啡'**
  String get homeMenuCoffeeTitle;

  /// No description provided for @homeMenuFeedbackTitle.
  ///
  /// In zh, this message translates to:
  /// **'问题反馈'**
  String get homeMenuFeedbackTitle;

  /// No description provided for @switchTimetableTitle.
  ///
  /// In zh, this message translates to:
  /// **'切换课表'**
  String get switchTimetableTitle;

  /// No description provided for @switchTimetableSubtitleEmpty.
  ///
  /// In zh, this message translates to:
  /// **'点击下面的课表，立即切换当前视图。'**
  String get switchTimetableSubtitleEmpty;

  /// No description provided for @switchTimetableSubtitleCurrent.
  ///
  /// In zh, this message translates to:
  /// **'当前：{name}，点击下面的课表立即切换。'**
  String switchTimetableSubtitleCurrent(String name);

  /// No description provided for @todayTimetableTitle.
  ///
  /// In zh, this message translates to:
  /// **'今日课表'**
  String get todayTimetableTitle;

  /// No description provided for @dayTimetableTitle.
  ///
  /// In zh, this message translates to:
  /// **'单日时间轴'**
  String get dayTimetableTitle;

  /// No description provided for @backToWeekViewAction.
  ///
  /// In zh, this message translates to:
  /// **'返回周视图'**
  String get backToWeekViewAction;

  /// No description provided for @backToTodayAction.
  ///
  /// In zh, this message translates to:
  /// **'回到今天'**
  String get backToTodayAction;

  /// No description provided for @ongoingCourseBadge.
  ///
  /// In zh, this message translates to:
  /// **'正在上课'**
  String get ongoingCourseBadge;

  /// No description provided for @dayViewEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无课程'**
  String get dayViewEmptyTitle;

  /// No description provided for @shortNamePrefix.
  ///
  /// In zh, this message translates to:
  /// **'简称：{value}'**
  String shortNamePrefix(String value);

  /// No description provided for @teacherPrefix.
  ///
  /// In zh, this message translates to:
  /// **'老师：{value}'**
  String teacherPrefix(String value);

  /// No description provided for @locationPrefix.
  ///
  /// In zh, this message translates to:
  /// **'地点：{value}'**
  String locationPrefix(String value);

  /// No description provided for @courseDialogCurrentWeekHint.
  ///
  /// In zh, this message translates to:
  /// **'当前查看第 {week} 周，可直接对这一周这节课调课。'**
  String courseDialogCurrentWeekHint(int week);

  /// No description provided for @courseDialogNotThisWeekHint.
  ///
  /// In zh, this message translates to:
  /// **'当前查看第 {week} 周，这门课这周没有上课，因此不能按“本周这节”调课。'**
  String courseDialogNotThisWeekHint(int week);

  /// No description provided for @editActionShort.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get editActionShort;

  /// No description provided for @rescheduleAction.
  ///
  /// In zh, this message translates to:
  /// **'调课'**
  String get rescheduleAction;

  /// No description provided for @deleteActionShort.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get deleteActionShort;

  /// No description provided for @deleteModeTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除方式'**
  String get deleteModeTitle;

  /// No description provided for @deleteModeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'你可以删掉整条排课，也可以只删当前看到的这一周这一节。'**
  String get deleteModeSubtitle;

  /// No description provided for @deleteCourseAction.
  ///
  /// In zh, this message translates to:
  /// **'删这个课'**
  String get deleteCourseAction;

  /// No description provided for @deleteOccurrenceAction.
  ///
  /// In zh, this message translates to:
  /// **'删这节课'**
  String get deleteOccurrenceAction;

  /// No description provided for @deleteModeHintCurrentWeek.
  ///
  /// In zh, this message translates to:
  /// **'“删这个课”会删除这条排课的全部周次；“删这节课”只会删除第 {week} 周这一次。'**
  String deleteModeHintCurrentWeek(int week);

  /// No description provided for @deleteModeHintUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'当前卡片不是第 {week} 周的实际排课，所以只能删除整条排课。'**
  String deleteModeHintUnavailable(int week);

  /// No description provided for @deleteScheduleConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定删除“{name}”这条排课吗？\n{detail}'**
  String deleteScheduleConfirmMessage(String name, String detail);

  /// No description provided for @deleteOccurrenceConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定删除“{name}”在第 {week} 周的这一节吗？\n{detail}'**
  String deleteOccurrenceConfirmMessage(String name, int week, String detail);

  /// No description provided for @occurrenceDeletedMessage.
  ///
  /// In zh, this message translates to:
  /// **'已删除第 {week} 周这节课'**
  String occurrenceDeletedMessage(int week);

  /// No description provided for @noChangesDetected.
  ///
  /// In zh, this message translates to:
  /// **'未检测到变更'**
  String get noChangesDetected;

  /// No description provided for @rescheduleCurrentOccurrenceTitle.
  ///
  /// In zh, this message translates to:
  /// **'调本周这节课'**
  String get rescheduleCurrentOccurrenceTitle;

  /// No description provided for @rescheduleCurrentOccurrenceSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'只调整第 {week} 周这一节，原课程在这一周会自动移除，其他周保持不变。'**
  String rescheduleCurrentOccurrenceSubtitle(int week);

  /// No description provided for @rescheduleTargetWeekLabel.
  ///
  /// In zh, this message translates to:
  /// **'调到第几周'**
  String get rescheduleTargetWeekLabel;

  /// No description provided for @weekdayFieldLabel.
  ///
  /// In zh, this message translates to:
  /// **'星期'**
  String get weekdayFieldLabel;

  /// No description provided for @startSectionFieldLabel.
  ///
  /// In zh, this message translates to:
  /// **'开始节次'**
  String get startSectionFieldLabel;

  /// No description provided for @endSectionFieldLabel.
  ///
  /// In zh, this message translates to:
  /// **'结束节次'**
  String get endSectionFieldLabel;

  /// No description provided for @courseLocationFieldLabel.
  ///
  /// In zh, this message translates to:
  /// **'上课地点'**
  String get courseLocationFieldLabel;

  /// No description provided for @confirmRescheduleAction.
  ///
  /// In zh, this message translates to:
  /// **'确认调课'**
  String get confirmRescheduleAction;

  /// No description provided for @homeTitleStyleClassicLabel.
  ///
  /// In zh, this message translates to:
  /// **'经典文字'**
  String get homeTitleStyleClassicLabel;

  /// No description provided for @homeTitleStyleBrandLabel.
  ///
  /// In zh, this message translates to:
  /// **'大 Logo'**
  String get homeTitleStyleBrandLabel;

  /// No description provided for @homeTitleStyleClassicDescription.
  ///
  /// In zh, this message translates to:
  /// **'保持原本标题样式，只显示文字，点击即可切换课表'**
  String get homeTitleStyleClassicDescription;

  /// No description provided for @homeTitleStyleBrandDescription.
  ///
  /// In zh, this message translates to:
  /// **'显示大 Logo 和小课表名称，更强调品牌感'**
  String get homeTitleStyleBrandDescription;

  /// No description provided for @widgetBackgroundStyleGlass.
  ///
  /// In zh, this message translates to:
  /// **'半透明玻璃感'**
  String get widgetBackgroundStyleGlass;

  /// No description provided for @widgetBackgroundStyleSolid.
  ///
  /// In zh, this message translates to:
  /// **'纯色卡片'**
  String get widgetBackgroundStyleSolid;

  /// No description provided for @widgetBackgroundStyleGradient.
  ///
  /// In zh, this message translates to:
  /// **'渐变卡片'**
  String get widgetBackgroundStyleGradient;

  /// No description provided for @homeWidgetTargetCompact22.
  ///
  /// In zh, this message translates to:
  /// **'主卡 2×2'**
  String get homeWidgetTargetCompact22;

  /// No description provided for @homeWidgetTargetMiniList22.
  ///
  /// In zh, this message translates to:
  /// **'迷你列表 2×2'**
  String get homeWidgetTargetMiniList22;

  /// No description provided for @homeWidgetTargetMedium24.
  ///
  /// In zh, this message translates to:
  /// **'概览 2×4'**
  String get homeWidgetTargetMedium24;

  /// No description provided for @homeWidgetTargetLarge44.
  ///
  /// In zh, this message translates to:
  /// **'列表 4×4'**
  String get homeWidgetTargetLarge44;

  /// No description provided for @addCourseSheetTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加内容'**
  String get addCourseSheetTitle;

  /// No description provided for @addCourseSheetSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'空白课表区域不响应点击。请从这里明确选择是加一节临时课、整学期重复课，还是插入一条单次日程。'**
  String get addCourseSheetSubtitle;

  /// No description provided for @courseWeekdaySectionSummary.
  ///
  /// In zh, this message translates to:
  /// **'{weekDescription} · {weekday} 第{startSection}-{endSection}节'**
  String courseWeekdaySectionSummary(
    String weekDescription,
    String weekday,
    int startSection,
    int endSection,
  );

  /// No description provided for @weekdaySectionTimeSummary.
  ///
  /// In zh, this message translates to:
  /// **'{weekday} 第{startSection}-{endSection}节 · {startTime}-{endTime}'**
  String weekdaySectionTimeSummary(
    String weekday,
    int startSection,
    int endSection,
    String startTime,
    String endTime,
  );

  /// No description provided for @rescheduledToMessage.
  ///
  /// In zh, this message translates to:
  /// **'已调到第 {week} 周 {weekday} 第{startSection}-{endSection}节'**
  String rescheduledToMessage(
    int week,
    String weekday,
    int startSection,
    int endSection,
  );

  /// No description provided for @courseCountSummary.
  ///
  /// In zh, this message translates to:
  /// **'{count} 门课'**
  String courseCountSummary(int count);

  /// No description provided for @dayAgendaInProgressStatus.
  ///
  /// In zh, this message translates to:
  /// **'进行中 · 剩余 {minutes} 分钟'**
  String dayAgendaInProgressStatus(int minutes);

  /// No description provided for @dayAgendaEndingSoonStatus.
  ///
  /// In zh, this message translates to:
  /// **'快下课了 · 剩余 {minutes} 分钟'**
  String dayAgendaEndingSoonStatus(int minutes);

  /// No description provided for @scheduleAgendaInProgressStatus.
  ///
  /// In zh, this message translates to:
  /// **'进行中 · 剩余 {minutes} 分钟'**
  String scheduleAgendaInProgressStatus(int minutes);

  /// No description provided for @scheduleAgendaEndingSoonStatus.
  ///
  /// In zh, this message translates to:
  /// **'即将结束 · 剩余 {minutes} 分钟'**
  String scheduleAgendaEndingSoonStatus(int minutes);

  /// No description provided for @currentBadge.
  ///
  /// In zh, this message translates to:
  /// **'当前'**
  String get currentBadge;

  /// No description provided for @feedbackXiaohongshuTitle.
  ///
  /// In zh, this message translates to:
  /// **'小红书'**
  String get feedbackXiaohongshuTitle;

  /// No description provided for @feedbackXiaohongshuSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'小红书号：{id}'**
  String feedbackXiaohongshuSubtitle(String id);

  /// No description provided for @feedbackCoolapkTitle.
  ///
  /// In zh, this message translates to:
  /// **'酷安'**
  String get feedbackCoolapkTitle;

  /// No description provided for @feedbackCoolapkSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'酷安号：{id}'**
  String feedbackCoolapkSubtitle(String id);

  /// No description provided for @feedbackQqGroupTitle.
  ///
  /// In zh, this message translates to:
  /// **'QQ 群'**
  String get feedbackQqGroupTitle;

  /// No description provided for @feedbackQqGroupSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'群号：{id}'**
  String feedbackQqGroupSubtitle(String id);

  /// No description provided for @copiedCurrentTimetable.
  ///
  /// In zh, this message translates to:
  /// **'已复制当前课表'**
  String get copiedCurrentTimetable;

  /// No description provided for @sectionRangeLabel.
  ///
  /// In zh, this message translates to:
  /// **'第{startSection}-{endSection}节'**
  String sectionRangeLabel(int startSection, int endSection);

  /// No description provided for @classStartsAtLabel.
  ///
  /// In zh, this message translates to:
  /// **'{time} 开始'**
  String classStartsAtLabel(String time);

  /// No description provided for @classEndsAtLabel.
  ///
  /// In zh, this message translates to:
  /// **'{time} 结束'**
  String classEndsAtLabel(String time);

  /// No description provided for @invalidSectionTimeFormat.
  ///
  /// In zh, this message translates to:
  /// **'节次时间格式不正确'**
  String get invalidSectionTimeFormat;

  /// No description provided for @noSectionTimesToSave.
  ///
  /// In zh, this message translates to:
  /// **'没有可保存的节次时间'**
  String get noSectionTimesToSave;

  /// No description provided for @warehouseImportedTimeSchemeName.
  ///
  /// In zh, this message translates to:
  /// **'{schoolName} 导入节次'**
  String warehouseImportedTimeSchemeName(String schoolName);

  /// No description provided for @unnamedScript.
  ///
  /// In zh, this message translates to:
  /// **'未命名脚本'**
  String get unnamedScript;

  /// No description provided for @localDebugModeScriptStatus.
  ///
  /// In zh, this message translates to:
  /// **'本地调试模式：{scriptName}'**
  String localDebugModeScriptStatus(String scriptName);

  /// No description provided for @executeImportScriptTooltip.
  ///
  /// In zh, this message translates to:
  /// **'执行导入脚本'**
  String get executeImportScriptTooltip;

  /// No description provided for @switchToMobileWebTooltip.
  ///
  /// In zh, this message translates to:
  /// **'切换到移动端页面'**
  String get switchToMobileWebTooltip;

  /// No description provided for @switchToDesktopWebTooltip.
  ///
  /// In zh, this message translates to:
  /// **'切换到桌面端页面'**
  String get switchToDesktopWebTooltip;

  /// No description provided for @rememberCurrentInputTooltip.
  ///
  /// In zh, this message translates to:
  /// **'记住当前输入'**
  String get rememberCurrentInputTooltip;

  /// No description provided for @fillRememberedTooltip.
  ///
  /// In zh, this message translates to:
  /// **'填充已记住账号'**
  String get fillRememberedTooltip;

  /// No description provided for @clearRememberedTooltip.
  ///
  /// In zh, this message translates to:
  /// **'清除已记住账号'**
  String get clearRememberedTooltip;

  /// No description provided for @copyCurrentAddressTooltip.
  ///
  /// In zh, this message translates to:
  /// **'复制当前地址'**
  String get copyCurrentAddressTooltip;

  /// No description provided for @copiedCurrentAddress.
  ///
  /// In zh, this message translates to:
  /// **'已复制当前地址'**
  String get copiedCurrentAddress;

  /// No description provided for @warehouseLoginHintLocalDebug.
  ///
  /// In zh, this message translates to:
  /// **'当前为本地调试脚本模式'**
  String get warehouseLoginHintLocalDebug;

  /// No description provided for @warehouseLoginHintImport.
  ///
  /// In zh, this message translates to:
  /// **'在此登录教务系统后执行导入'**
  String get warehouseLoginHintImport;

  /// No description provided for @currentPageModeDesktop.
  ///
  /// In zh, this message translates to:
  /// **'当前页面模式：桌面端'**
  String get currentPageModeDesktop;

  /// No description provided for @currentPageModeMobile.
  ///
  /// In zh, this message translates to:
  /// **'当前页面模式：移动端'**
  String get currentPageModeMobile;

  /// No description provided for @localScriptLabel.
  ///
  /// In zh, this message translates to:
  /// **'本地脚本：{scriptName}'**
  String localScriptLabel(String scriptName);

  /// No description provided for @webAddressHint.
  ///
  /// In zh, this message translates to:
  /// **'输入网页地址'**
  String get webAddressHint;

  /// No description provided for @goAction.
  ///
  /// In zh, this message translates to:
  /// **'前往'**
  String get goAction;

  /// No description provided for @rememberedAccountLabel.
  ///
  /// In zh, this message translates to:
  /// **'已记住账号：{username}'**
  String rememberedAccountLabel(String username);

  /// No description provided for @importingAction.
  ///
  /// In zh, this message translates to:
  /// **'导入中...'**
  String get importingAction;

  /// No description provided for @executeLocalDebugScriptAction.
  ///
  /// In zh, this message translates to:
  /// **'执行本地调试脚本'**
  String get executeLocalDebugScriptAction;

  /// No description provided for @executeImportScriptAction.
  ///
  /// In zh, this message translates to:
  /// **'执行导入脚本'**
  String get executeImportScriptAction;

  /// No description provided for @invalidWebAddress.
  ///
  /// In zh, this message translates to:
  /// **'网页地址无效'**
  String get invalidWebAddress;

  /// No description provided for @injectingLocalDebugScript.
  ///
  /// In zh, this message translates to:
  /// **'正在注入本地调试脚本'**
  String get injectingLocalDebugScript;

  /// No description provided for @injectingAdapterScript.
  ///
  /// In zh, this message translates to:
  /// **'正在注入适配器脚本'**
  String get injectingAdapterScript;

  /// No description provided for @localDebugScriptInjected.
  ///
  /// In zh, this message translates to:
  /// **'本地调试脚本已注入'**
  String get localDebugScriptInjected;

  /// No description provided for @scriptInjected.
  ///
  /// In zh, this message translates to:
  /// **'脚本已注入'**
  String get scriptInjected;

  /// No description provided for @scriptInjectionFailed.
  ///
  /// In zh, this message translates to:
  /// **'脚本注入失败'**
  String get scriptInjectionFailed;

  /// No description provided for @executeFailedWithError.
  ///
  /// In zh, this message translates to:
  /// **'执行失败：{error}'**
  String executeFailedWithError(String error);

  /// No description provided for @importFlowFinished.
  ///
  /// In zh, this message translates to:
  /// **'导入流程已完成'**
  String get importFlowFinished;

  /// No description provided for @defaultContinuePrompt.
  ///
  /// In zh, this message translates to:
  /// **'请按提示继续操作'**
  String get defaultContinuePrompt;

  /// No description provided for @inputRequiredTitle.
  ///
  /// In zh, this message translates to:
  /// **'需要输入'**
  String get inputRequiredTitle;

  /// No description provided for @pleaseEnterFourDigitYear.
  ///
  /// In zh, this message translates to:
  /// **'请输入 4 位年份'**
  String get pleaseEnterFourDigitYear;

  /// No description provided for @pleaseChooseTitle.
  ///
  /// In zh, this message translates to:
  /// **'请选择'**
  String get pleaseChooseTitle;

  /// No description provided for @invalidCourseConfigFormat.
  ///
  /// In zh, this message translates to:
  /// **'课程配置格式不正确'**
  String get invalidCourseConfigFormat;

  /// No description provided for @saveCourseConfigFailedWithError.
  ///
  /// In zh, this message translates to:
  /// **'保存课程配置失败：{error}'**
  String saveCourseConfigFailedWithError(String error);

  /// No description provided for @saveSectionTimesFailedWithError.
  ///
  /// In zh, this message translates to:
  /// **'保存节次时间失败：{error}'**
  String saveSectionTimesFailedWithError(String error);

  /// No description provided for @invalidCourseDataFormat.
  ///
  /// In zh, this message translates to:
  /// **'课程数据格式不正确'**
  String get invalidCourseDataFormat;

  /// No description provided for @noImportableCoursesFromScript.
  ///
  /// In zh, this message translates to:
  /// **'脚本未返回可导入课程'**
  String get noImportableCoursesFromScript;

  /// No description provided for @importCourseCountPrompt.
  ///
  /// In zh, this message translates to:
  /// **'识别到 {count} 门课程，是否导入？'**
  String importCourseCountPrompt(int count);

  /// No description provided for @importCancelledStatus.
  ///
  /// In zh, this message translates to:
  /// **'已取消导入'**
  String get importCancelledStatus;

  /// No description provided for @applyReturnedTimeSchemeFailed.
  ///
  /// In zh, this message translates to:
  /// **'应用返回的节次模板失败：{error}'**
  String applyReturnedTimeSchemeFailed(String error);

  /// No description provided for @importInterruptedStatus.
  ///
  /// In zh, this message translates to:
  /// **'导入已中断'**
  String get importInterruptedStatus;

  /// No description provided for @importFailedStatus.
  ///
  /// In zh, this message translates to:
  /// **'导入失败'**
  String get importFailedStatus;

  /// No description provided for @importFailedWithError.
  ///
  /// In zh, this message translates to:
  /// **'导入失败：{error}'**
  String importFailedWithError(String error);

  /// No description provided for @unknownTeacher.
  ///
  /// In zh, this message translates to:
  /// **'未知教师'**
  String get unknownTeacher;

  /// No description provided for @unknownLocation.
  ///
  /// In zh, this message translates to:
  /// **'未知地点'**
  String get unknownLocation;

  /// No description provided for @autofillLoginTitle.
  ///
  /// In zh, this message translates to:
  /// **'自动填充登录信息'**
  String get autofillLoginTitle;

  /// No description provided for @autofillLoginMessage.
  ///
  /// In zh, this message translates to:
  /// **'检测到已记住账号 {username}，是否自动填充？'**
  String autofillLoginMessage(String username);

  /// No description provided for @notNowAction.
  ///
  /// In zh, this message translates to:
  /// **'暂不'**
  String get notNowAction;

  /// No description provided for @autofillAction.
  ///
  /// In zh, this message translates to:
  /// **'自动填充'**
  String get autofillAction;

  /// No description provided for @rememberPasswordTitle.
  ///
  /// In zh, this message translates to:
  /// **'记住密码'**
  String get rememberPasswordTitle;

  /// No description provided for @rememberPasswordMessage.
  ///
  /// In zh, this message translates to:
  /// **'是否记住账号 {username} 的登录信息，并在下次自动填充？'**
  String rememberPasswordMessage(String username);

  /// No description provided for @dontRememberAction.
  ///
  /// In zh, this message translates to:
  /// **'不记住'**
  String get dontRememberAction;

  /// No description provided for @rememberAndAutofillAction.
  ///
  /// In zh, this message translates to:
  /// **'记住并自动填充'**
  String get rememberAndAutofillAction;

  /// No description provided for @savedRememberedLoginStatus.
  ///
  /// In zh, this message translates to:
  /// **'已保存记住的登录信息'**
  String get savedRememberedLoginStatus;

  /// No description provided for @autofilledRememberedLoginStatus.
  ///
  /// In zh, this message translates to:
  /// **'已自动填充记住的登录信息'**
  String get autofilledRememberedLoginStatus;

  /// No description provided for @noRecognizedLoginInputs.
  ///
  /// In zh, this message translates to:
  /// **'未识别到登录输入项'**
  String get noRecognizedLoginInputs;

  /// No description provided for @noUsernameOrPasswordRecognized.
  ///
  /// In zh, this message translates to:
  /// **'未识别到用户名或密码'**
  String get noUsernameOrPasswordRecognized;

  /// No description provided for @rememberedCurrentLoginStatus.
  ///
  /// In zh, this message translates to:
  /// **'已记住当前登录信息'**
  String get rememberedCurrentLoginStatus;

  /// No description provided for @rememberedCurrentLoginSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已记住当前登录信息'**
  String get rememberedCurrentLoginSuccess;

  /// No description provided for @rememberLoginFailedWithError.
  ///
  /// In zh, this message translates to:
  /// **'记住登录信息失败：{error}'**
  String rememberLoginFailedWithError(String error);

  /// No description provided for @clearedRememberedLoginStatus.
  ///
  /// In zh, this message translates to:
  /// **'已清除记住的登录信息'**
  String get clearedRememberedLoginStatus;

  /// No description provided for @clearedRememberedLoginSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已清除记住的登录信息'**
  String get clearedRememberedLoginSuccess;

  /// No description provided for @addScheduleTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加日程'**
  String get addScheduleTitle;

  /// No description provided for @editScheduleTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑日程'**
  String get editScheduleTitle;

  /// No description provided for @addScheduleAction.
  ///
  /// In zh, this message translates to:
  /// **'添加日程'**
  String get addScheduleAction;

  /// No description provided for @scheduleTitleLabel.
  ///
  /// In zh, this message translates to:
  /// **'日程标题'**
  String get scheduleTitleLabel;

  /// No description provided for @scheduleTitleHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：开组会、办证件、拿快递'**
  String get scheduleTitleHint;

  /// No description provided for @scheduleTitleRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入日程标题'**
  String get scheduleTitleRequired;

  /// No description provided for @scheduleInfoSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'日程信息'**
  String get scheduleInfoSectionTitle;

  /// No description provided for @scheduleInfoSectionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'日程会按具体日期插入日视图时间线里，不会改动课程本身。'**
  String get scheduleInfoSectionSubtitle;

  /// No description provided for @scheduleTimeSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'时间安排'**
  String get scheduleTimeSectionTitle;

  /// No description provided for @scheduleTimeSectionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'选择这条日程实际发生的日期和起止时间。'**
  String get scheduleTimeSectionSubtitle;

  /// No description provided for @scheduleAppearanceSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示样式'**
  String get scheduleAppearanceSectionTitle;

  /// No description provided for @scheduleAppearanceSectionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'选择一个更容易和课程区分的日程颜色。'**
  String get scheduleAppearanceSectionSubtitle;

  /// No description provided for @scheduleLocationLabel.
  ///
  /// In zh, this message translates to:
  /// **'地点'**
  String get scheduleLocationLabel;

  /// No description provided for @scheduleLocationHint.
  ///
  /// In zh, this message translates to:
  /// **'选填'**
  String get scheduleLocationHint;

  /// No description provided for @scheduleDateLabel.
  ///
  /// In zh, this message translates to:
  /// **'日期'**
  String get scheduleDateLabel;

  /// No description provided for @scheduleStartDateLabel.
  ///
  /// In zh, this message translates to:
  /// **'开始日期'**
  String get scheduleStartDateLabel;

  /// No description provided for @scheduleEndDateLabel.
  ///
  /// In zh, this message translates to:
  /// **'结束日期'**
  String get scheduleEndDateLabel;

  /// No description provided for @scheduleStartTimeLabel.
  ///
  /// In zh, this message translates to:
  /// **'开始时间'**
  String get scheduleStartTimeLabel;

  /// No description provided for @scheduleEndTimeLabel.
  ///
  /// In zh, this message translates to:
  /// **'结束时间'**
  String get scheduleEndTimeLabel;

  /// No description provided for @scheduleColorLabel.
  ///
  /// In zh, this message translates to:
  /// **'日程颜色'**
  String get scheduleColorLabel;

  /// No description provided for @scheduleNoteLabel.
  ///
  /// In zh, this message translates to:
  /// **'备注'**
  String get scheduleNoteLabel;

  /// No description provided for @scheduleNoteHint.
  ///
  /// In zh, this message translates to:
  /// **'选填'**
  String get scheduleNoteHint;

  /// No description provided for @scheduleBadgeLabel.
  ///
  /// In zh, this message translates to:
  /// **'日程'**
  String get scheduleBadgeLabel;

  /// No description provided for @scheduleCountSummary.
  ///
  /// In zh, this message translates to:
  /// **'日程 {count} 项'**
  String scheduleCountSummary(int count);

  /// No description provided for @scheduleTimeRangeInvalid.
  ///
  /// In zh, this message translates to:
  /// **'结束时间必须晚于开始时间'**
  String get scheduleTimeRangeInvalid;

  /// No description provided for @scheduleDateRangeInvalid.
  ///
  /// In zh, this message translates to:
  /// **'结束日期不能早于开始日期'**
  String get scheduleDateRangeInvalid;

  /// No description provided for @scheduleSingleDayHint.
  ///
  /// In zh, this message translates to:
  /// **'同日结束时，结束时间必须晚于开始时间。'**
  String get scheduleSingleDayHint;

  /// No description provided for @scheduleCrossDayHint.
  ///
  /// In zh, this message translates to:
  /// **'跨日日程会按当天切片显示在日视图里。'**
  String get scheduleCrossDayHint;

  /// No description provided for @scheduleSavedHint.
  ///
  /// In zh, this message translates to:
  /// **'日程已添加'**
  String get scheduleSavedHint;

  /// No description provided for @scheduleUpdatedHint.
  ///
  /// In zh, this message translates to:
  /// **'日程已更新'**
  String get scheduleUpdatedHint;

  /// No description provided for @crossDayBadgeLabel.
  ///
  /// In zh, this message translates to:
  /// **'跨日'**
  String get crossDayBadgeLabel;

  /// No description provided for @deleteScheduleMessage.
  ///
  /// In zh, this message translates to:
  /// **'删除日程“{title}”？'**
  String deleteScheduleMessage(String title);

  /// No description provided for @scheduleDeletedHint.
  ///
  /// In zh, this message translates to:
  /// **'日程已删除'**
  String get scheduleDeletedHint;

  /// No description provided for @examListTitle.
  ///
  /// In zh, this message translates to:
  /// **'考试安排'**
  String get examListTitle;

  /// No description provided for @addExam.
  ///
  /// In zh, this message translates to:
  /// **'添加考试'**
  String get addExam;

  /// No description provided for @editExam.
  ///
  /// In zh, this message translates to:
  /// **'编辑考试'**
  String get editExam;

  /// No description provided for @saveExam.
  ///
  /// In zh, this message translates to:
  /// **'保存考试'**
  String get saveExam;

  /// No description provided for @noExams.
  ///
  /// In zh, this message translates to:
  /// **'暂无考试安排'**
  String get noExams;

  /// No description provided for @examToday.
  ///
  /// In zh, this message translates to:
  /// **'今天有考试'**
  String get examToday;

  /// No description provided for @daysUntilExam.
  ///
  /// In zh, this message translates to:
  /// **'距离考试还有 {days} 天'**
  String daysUntilExam(int days);

  /// No description provided for @examPassed.
  ///
  /// In zh, this message translates to:
  /// **'已结束'**
  String get examPassed;

  /// No description provided for @linkCourse.
  ///
  /// In zh, this message translates to:
  /// **'关联课程'**
  String get linkCourse;

  /// No description provided for @linkCourseRequired.
  ///
  /// In zh, this message translates to:
  /// **'请选择关联课程'**
  String get linkCourseRequired;

  /// No description provided for @examNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'考试名称'**
  String get examNameLabel;

  /// No description provided for @examNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入考试名称'**
  String get examNameRequired;

  /// No description provided for @examDateLabel.
  ///
  /// In zh, this message translates to:
  /// **'考试日期'**
  String get examDateLabel;

  /// No description provided for @examDateHint.
  ///
  /// In zh, this message translates to:
  /// **'请选择日期'**
  String get examDateHint;

  /// No description provided for @examDateRequired.
  ///
  /// In zh, this message translates to:
  /// **'请选择考试日期'**
  String get examDateRequired;

  /// No description provided for @examStartTimeLabel.
  ///
  /// In zh, this message translates to:
  /// **'开始时间'**
  String get examStartTimeLabel;

  /// No description provided for @examEndTimeLabel.
  ///
  /// In zh, this message translates to:
  /// **'结束时间'**
  String get examEndTimeLabel;

  /// No description provided for @examLocationLabel.
  ///
  /// In zh, this message translates to:
  /// **'考场'**
  String get examLocationLabel;

  /// No description provided for @examLocationHint.
  ///
  /// In zh, this message translates to:
  /// **'留空则使用上课教室'**
  String get examLocationHint;

  /// No description provided for @sameAsClassroom.
  ///
  /// In zh, this message translates to:
  /// **'同上课教室'**
  String get sameAsClassroom;

  /// No description provided for @examSeatLabel.
  ///
  /// In zh, this message translates to:
  /// **'座位号'**
  String get examSeatLabel;

  /// No description provided for @examReminderLabel.
  ///
  /// In zh, this message translates to:
  /// **'提醒设置'**
  String get examReminderLabel;

  /// No description provided for @examNoteLabel.
  ///
  /// In zh, this message translates to:
  /// **'备注'**
  String get examNoteLabel;

  /// No description provided for @deleteExam.
  ///
  /// In zh, this message translates to:
  /// **'删除考试'**
  String get deleteExam;

  /// No description provided for @deleteExamConfirm.
  ///
  /// In zh, this message translates to:
  /// **'删除考试「{name}」？'**
  String deleteExamConfirm(String name);

  /// No description provided for @examBadgeLabel.
  ///
  /// In zh, this message translates to:
  /// **'考试'**
  String get examBadgeLabel;

  /// No description provided for @examCountdownToday.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get examCountdownToday;

  /// No description provided for @examCountdownDays.
  ///
  /// In zh, this message translates to:
  /// **'{days}天后'**
  String examCountdownDays(int days);

  /// No description provided for @sortAction.
  ///
  /// In zh, this message translates to:
  /// **'排序'**
  String get sortAction;

  /// No description provided for @sortByAdded.
  ///
  /// In zh, this message translates to:
  /// **'按添加顺序'**
  String get sortByAdded;

  /// No description provided for @sortByName.
  ///
  /// In zh, this message translates to:
  /// **'按课程名称'**
  String get sortByName;

  /// No description provided for @sortBySchedule.
  ///
  /// In zh, this message translates to:
  /// **'按排课时间'**
  String get sortBySchedule;

  /// No description provided for @scheduleEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'排课记录 {index}'**
  String scheduleEntryTitle(int index);

  /// No description provided for @addScheduleEntryAction.
  ///
  /// In zh, this message translates to:
  /// **'添加排课时间'**
  String get addScheduleEntryAction;

  /// No description provided for @deleteScheduleEntryAction.
  ///
  /// In zh, this message translates to:
  /// **'删除排课'**
  String get deleteScheduleEntryAction;

  /// No description provided for @holidaySettingsEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'节假日标记'**
  String get holidaySettingsEntryTitle;

  /// No description provided for @holidaySettingsEntrySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'在课表上标记法定节假日和调休补班'**
  String get holidaySettingsEntrySubtitle;

  /// No description provided for @holidayMakeupWorkday.
  ///
  /// In zh, this message translates to:
  /// **'补班'**
  String get holidayMakeupWorkday;

  /// No description provided for @holidaySettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'节假日标记'**
  String get holidaySettingsTitle;

  /// No description provided for @holidayEnableTitle.
  ///
  /// In zh, this message translates to:
  /// **'启用节假日标记'**
  String get holidayEnableTitle;

  /// No description provided for @holidayEnableSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'开启后会在课表上标记法定节假日和调休补班日'**
  String get holidayEnableSubtitle;

  /// No description provided for @holidayDataSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'节假日数据'**
  String get holidayDataSectionTitle;

  /// No description provided for @holidayDataYear.
  ///
  /// In zh, this message translates to:
  /// **'年份'**
  String get holidayDataYear;

  /// No description provided for @holidayDataCount.
  ///
  /// In zh, this message translates to:
  /// **'条数'**
  String get holidayDataCount;

  /// No description provided for @holidayDataEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无节假日数据'**
  String get holidayDataEmpty;

  /// No description provided for @holidayCheckUpdate.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get holidayCheckUpdate;

  /// No description provided for @holidayUpcomingSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'近期节假日'**
  String get holidayUpcomingSectionTitle;

  /// No description provided for @holidayNoUpcoming.
  ///
  /// In zh, this message translates to:
  /// **'近期没有节假日'**
  String get holidayNoUpcoming;

  /// No description provided for @holidayBadgeLabel.
  ///
  /// In zh, this message translates to:
  /// **'假'**
  String get holidayBadgeLabel;

  /// No description provided for @holidayStatusLabel.
  ///
  /// In zh, this message translates to:
  /// **'假期'**
  String get holidayStatusLabel;

  /// No description provided for @suspendedBadgeLabel.
  ///
  /// In zh, this message translates to:
  /// **'停'**
  String get suspendedBadgeLabel;

  /// No description provided for @suspendedStatusLabel.
  ///
  /// In zh, this message translates to:
  /// **'停课'**
  String get suspendedStatusLabel;

  /// No description provided for @courseActionSuspend.
  ///
  /// In zh, this message translates to:
  /// **'停课'**
  String get courseActionSuspend;

  /// No description provided for @courseActionUnsuspend.
  ///
  /// In zh, this message translates to:
  /// **'恢复'**
  String get courseActionUnsuspend;

  /// No description provided for @suspendSheetTitle.
  ///
  /// In zh, this message translates to:
  /// **'停课'**
  String get suspendSheetTitle;

  /// No description provided for @suspendSheetSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'选择停课范围'**
  String get suspendSheetSubtitle;

  /// No description provided for @suspendThisWeek.
  ///
  /// In zh, this message translates to:
  /// **'停本周'**
  String get suspendThisWeek;

  /// No description provided for @suspendThisWeekDesc.
  ///
  /// In zh, this message translates to:
  /// **'仅暂停当前周'**
  String get suspendThisWeekDesc;

  /// No description provided for @suspendAllWeeks.
  ///
  /// In zh, this message translates to:
  /// **'全部停'**
  String get suspendAllWeeks;

  /// No description provided for @suspendAllWeeksDesc.
  ///
  /// In zh, this message translates to:
  /// **'暂停所有周次'**
  String get suspendAllWeeksDesc;

  /// No description provided for @unsuspendAllWeeks.
  ///
  /// In zh, this message translates to:
  /// **'恢复全部'**
  String get unsuspendAllWeeks;

  /// No description provided for @unsuspendAllWeeksDesc.
  ///
  /// In zh, this message translates to:
  /// **'恢复所有周次'**
  String get unsuspendAllWeeksDesc;

  /// No description provided for @customHolidayTitle.
  ///
  /// In zh, this message translates to:
  /// **'自定义假期'**
  String get customHolidayTitle;

  /// No description provided for @customHolidayAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加假期'**
  String get customHolidayAdd;

  /// No description provided for @customHolidayEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑假期'**
  String get customHolidayEdit;

  /// No description provided for @customHolidayDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get customHolidayDelete;

  /// No description provided for @customHolidayDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定删除这个自定义假期吗？'**
  String get customHolidayDeleteConfirm;

  /// No description provided for @customHolidayNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'假期名称'**
  String get customHolidayNameLabel;

  /// No description provided for @customHolidayStartDate.
  ///
  /// In zh, this message translates to:
  /// **'开始日期'**
  String get customHolidayStartDate;

  /// No description provided for @customHolidayEndDate.
  ///
  /// In zh, this message translates to:
  /// **'结束日期'**
  String get customHolidayEndDate;

  /// No description provided for @customHolidayType.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get customHolidayType;

  /// No description provided for @customHolidayTypeVacation.
  ///
  /// In zh, this message translates to:
  /// **'假期'**
  String get customHolidayTypeVacation;

  /// No description provided for @customHolidayTypeWorkday.
  ///
  /// In zh, this message translates to:
  /// **'调休上班'**
  String get customHolidayTypeWorkday;

  /// No description provided for @customHolidayEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无自定义假期'**
  String get customHolidayEmpty;

  /// No description provided for @customHolidayNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入假期名称'**
  String get customHolidayNameRequired;

  /// No description provided for @customHolidayDateRange.
  ///
  /// In zh, this message translates to:
  /// **'{start} ~ {end}'**
  String customHolidayDateRange(Object start, Object end);

  /// No description provided for @selectTeacherTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择教师'**
  String get selectTeacherTitle;

  /// No description provided for @selectLocationTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择教室'**
  String get selectLocationTitle;

  /// No description provided for @historyRecordsLabel.
  ///
  /// In zh, this message translates to:
  /// **'历史记录'**
  String get historyRecordsLabel;

  /// No description provided for @noHistoryRecords.
  ///
  /// In zh, this message translates to:
  /// **'暂无历史记录'**
  String get noHistoryRecords;

  /// No description provided for @weekPickerTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择上课周次'**
  String get weekPickerTitle;

  /// No description provided for @selectTimeSchemeTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择时间方案'**
  String get selectTimeSchemeTitle;

  /// No description provided for @manageTimeSchemesAction.
  ///
  /// In zh, this message translates to:
  /// **'管理时间方案'**
  String get manageTimeSchemesAction;

  /// No description provided for @examDefaultName.
  ///
  /// In zh, this message translates to:
  /// **'期末考试'**
  String get examDefaultName;

  /// No description provided for @examDateWeekPickerTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择考试日期'**
  String get examDateWeekPickerTitle;

  /// No description provided for @weekPickerCalendarTooltip.
  ///
  /// In zh, this message translates to:
  /// **'使用日历选择'**
  String get weekPickerCalendarTooltip;

  /// No description provided for @thisWeekLabel.
  ///
  /// In zh, this message translates to:
  /// **'本周'**
  String get thisWeekLabel;

  /// No description provided for @guidePrivacyPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'隐私协议'**
  String get guidePrivacyPageTitle;

  /// No description provided for @guidePermissionsPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'系统权限'**
  String get guidePermissionsPageTitle;

  /// No description provided for @guideTipsPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'使用技巧'**
  String get guideTipsPageTitle;

  /// No description provided for @guidePrevButton.
  ///
  /// In zh, this message translates to:
  /// **'上一步'**
  String get guidePrevButton;

  /// No description provided for @guideNextButton.
  ///
  /// In zh, this message translates to:
  /// **'下一步'**
  String get guideNextButton;

  /// No description provided for @guidePermissionsHeader.
  ///
  /// In zh, this message translates to:
  /// **'系统权限设置'**
  String get guidePermissionsHeader;

  /// No description provided for @guidePermissionsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'完成这些设置，超级岛和提醒才能正常使用'**
  String get guidePermissionsSubtitle;

  /// No description provided for @guidePermissionsFooterHint.
  ///
  /// In zh, this message translates to:
  /// **'点击后跳转到系统设置，返回应用后可识别的状态会自动刷新；自启动受系统限制，请以系统页面开关为准。'**
  String get guidePermissionsFooterHint;

  /// No description provided for @guideTipsHeader.
  ///
  /// In zh, this message translates to:
  /// **'使用技巧'**
  String get guideTipsHeader;

  /// No description provided for @guideTipsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'这些随时可以在「设置」里找到'**
  String get guideTipsSubtitle;

  /// No description provided for @guidePrivacyReadBeforeUse.
  ///
  /// In zh, this message translates to:
  /// **'使用前请阅读并同意以下内容'**
  String get guidePrivacyReadBeforeUse;

  /// No description provided for @guidePrivacyViewOnly.
  ///
  /// In zh, this message translates to:
  /// **'隐私、第三方 SDK 与免责说明'**
  String get guidePrivacyViewOnly;

  /// No description provided for @holidayDataYearLabel.
  ///
  /// In zh, this message translates to:
  /// **'{year}年法定节假日'**
  String holidayDataYearLabel(Object year);

  /// No description provided for @holidayUpdateLog.
  ///
  /// In zh, this message translates to:
  /// **'更新日志'**
  String get holidayUpdateLog;

  /// No description provided for @holidayUpdateLogCount.
  ///
  /// In zh, this message translates to:
  /// **'{count}条'**
  String holidayUpdateLogCount(int count);

  /// No description provided for @holidayDateSameMonth.
  ///
  /// In zh, this message translates to:
  /// **'{month}月{start}日 - {end}日'**
  String holidayDateSameMonth(int month, int start, int end);

  /// No description provided for @holidayDateSameDay.
  ///
  /// In zh, this message translates to:
  /// **'{month}月{day}日'**
  String holidayDateSameDay(int month, int day);

  /// No description provided for @holidayDateDiffMonth.
  ///
  /// In zh, this message translates to:
  /// **'{startMonth}月{startDay}日 - {endMonth}月{endDay}日'**
  String holidayDateDiffMonth(
    int startMonth,
    int startDay,
    int endMonth,
    int endDay,
  );

  /// No description provided for @liveTestingHolidayOverride.
  ///
  /// In zh, this message translates to:
  /// **'假期状态覆盖'**
  String get liveTestingHolidayOverride;

  /// No description provided for @liveTestingHolidayOverrideSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'开启后模拟假期状态，用于测试提醒和小组件是否正确隐藏课程'**
  String get liveTestingHolidayOverrideSubtitle;

  /// No description provided for @liveTestingHolidayModeEnabled.
  ///
  /// In zh, this message translates to:
  /// **'假期模式已开启'**
  String get liveTestingHolidayModeEnabled;

  /// No description provided for @liveTestingHolidayModeDisabled.
  ///
  /// In zh, this message translates to:
  /// **'假期模式已关闭'**
  String get liveTestingHolidayModeDisabled;

  /// No description provided for @liveTestingHolidayModeEnabledDesc.
  ///
  /// In zh, this message translates to:
  /// **'课程提醒和小组件将隐藏所有课程'**
  String get liveTestingHolidayModeEnabledDesc;

  /// No description provided for @liveTestingHolidayModeDisabledDesc.
  ///
  /// In zh, this message translates to:
  /// **'当前使用正常假期数据'**
  String get liveTestingHolidayModeDisabledDesc;

  /// No description provided for @textColorTitle.
  ///
  /// In zh, this message translates to:
  /// **'文字颜色'**
  String get textColorTitle;

  /// No description provided for @textColorSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'自定义课表各区域的文字颜色'**
  String get textColorSubtitle;

  /// No description provided for @textColorIndependentDetail.
  ///
  /// In zh, this message translates to:
  /// **'独立设置详情颜色'**
  String get textColorIndependentDetail;

  /// No description provided for @textColorCourseCardTitle.
  ///
  /// In zh, this message translates to:
  /// **'课程卡片标题颜色'**
  String get textColorCourseCardTitle;

  /// No description provided for @textColorCourseCardDetail.
  ///
  /// In zh, this message translates to:
  /// **'课程卡片详情颜色'**
  String get textColorCourseCardDetail;

  /// No description provided for @textColorWeekdayBar.
  ///
  /// In zh, this message translates to:
  /// **'星期栏字体颜色'**
  String get textColorWeekdayBar;

  /// No description provided for @textColorWeekdayBarAccent.
  ///
  /// In zh, this message translates to:
  /// **'星期栏强调色'**
  String get textColorWeekdayBarAccent;

  /// No description provided for @textColorTimeAxis.
  ///
  /// In zh, this message translates to:
  /// **'时间轴字体颜色'**
  String get textColorTimeAxis;

  /// No description provided for @textColorSelectColor.
  ///
  /// In zh, this message translates to:
  /// **'选择颜色'**
  String get textColorSelectColor;

  /// No description provided for @textColorCurrentColor.
  ///
  /// In zh, this message translates to:
  /// **'当前颜色'**
  String get textColorCurrentColor;

  /// No description provided for @themeExport.
  ///
  /// In zh, this message translates to:
  /// **'导出主题'**
  String get themeExport;

  /// No description provided for @themeImport.
  ///
  /// In zh, this message translates to:
  /// **'导入主题'**
  String get themeImport;

  /// No description provided for @themeExportSuccess.
  ///
  /// In zh, this message translates to:
  /// **'主题已复制到剪贴板'**
  String get themeExportSuccess;

  /// No description provided for @themeImportSuccess.
  ///
  /// In zh, this message translates to:
  /// **'主题已导入'**
  String get themeImportSuccess;

  /// No description provided for @themeImportFailed.
  ///
  /// In zh, this message translates to:
  /// **'剪贴板内容格式错误'**
  String get themeImportFailed;

  /// No description provided for @themeManageTitle.
  ///
  /// In zh, this message translates to:
  /// **'主题管理'**
  String get themeManageTitle;

  /// No description provided for @themeManageSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'导出、导入和切换主题'**
  String get themeManageSubtitle;

  /// No description provided for @themePreset.
  ///
  /// In zh, this message translates to:
  /// **'预设主题'**
  String get themePreset;

  /// No description provided for @themeSaved.
  ///
  /// In zh, this message translates to:
  /// **'我的主题'**
  String get themeSaved;

  /// No description provided for @themeSaveCurrent.
  ///
  /// In zh, this message translates to:
  /// **'保存当前主题'**
  String get themeSaveCurrent;

  /// No description provided for @themeApply.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get themeApply;

  /// No description provided for @themeDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get themeDelete;

  /// No description provided for @themeDeleteConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除主题“{name}”吗？'**
  String themeDeleteConfirmMessage(String name);

  /// No description provided for @textColorLowContrastWarning.
  ///
  /// In zh, this message translates to:
  /// **'颜色对比度较低，可能影响可读性'**
  String get textColorLowContrastWarning;

  /// No description provided for @themeCurrentTheme.
  ///
  /// In zh, this message translates to:
  /// **'当前主题'**
  String get themeCurrentTheme;

  /// No description provided for @themeBasedOnModified.
  ///
  /// In zh, this message translates to:
  /// **'基于{baseName}（已修改）'**
  String themeBasedOnModified(String baseName);

  /// No description provided for @themeResetToPreset.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get themeResetToPreset;

  /// No description provided for @themeUnsavedChangesTitle.
  ///
  /// In zh, this message translates to:
  /// **'未保存的修改'**
  String get themeUnsavedChangesTitle;

  /// No description provided for @themeUnsavedChangesMessage.
  ///
  /// In zh, this message translates to:
  /// **'当前主题有未保存的修改，是否保存？'**
  String get themeUnsavedChangesMessage;

  /// No description provided for @themeDiscardAndApply.
  ///
  /// In zh, this message translates to:
  /// **'放弃并应用'**
  String get themeDiscardAndApply;

  /// No description provided for @themeNameHint.
  ///
  /// In zh, this message translates to:
  /// **'输入主题名称'**
  String get themeNameHint;

  /// No description provided for @themePresetBlue.
  ///
  /// In zh, this message translates to:
  /// **'默认蓝'**
  String get themePresetBlue;

  /// No description provided for @themePresetPurple.
  ///
  /// In zh, this message translates to:
  /// **'暗夜紫'**
  String get themePresetPurple;

  /// No description provided for @themePresetGreen.
  ///
  /// In zh, this message translates to:
  /// **'森林绿'**
  String get themePresetGreen;

  /// No description provided for @themePresetOrange.
  ///
  /// In zh, this message translates to:
  /// **'暖阳橙'**
  String get themePresetOrange;

  /// No description provided for @themePresetEyeCare.
  ///
  /// In zh, this message translates to:
  /// **'护眼模式'**
  String get themePresetEyeCare;

  /// No description provided for @themePresetHighContrast.
  ///
  /// In zh, this message translates to:
  /// **'高对比度'**
  String get themePresetHighContrast;

  /// No description provided for @themePresetDarkMinimal.
  ///
  /// In zh, this message translates to:
  /// **'深色极简'**
  String get themePresetDarkMinimal;

  /// No description provided for @themeUndo.
  ///
  /// In zh, this message translates to:
  /// **'撤销'**
  String get themeUndo;

  /// No description provided for @themeChanged.
  ///
  /// In zh, this message translates to:
  /// **'已切换到 {themeName}'**
  String themeChanged(String themeName);

  /// No description provided for @themeRename.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get themeRename;

  /// No description provided for @themeDuplicate.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get themeDuplicate;

  /// No description provided for @courseNatureRequired.
  ///
  /// In zh, this message translates to:
  /// **'必修'**
  String get courseNatureRequired;

  /// No description provided for @courseNatureElective.
  ///
  /// In zh, this message translates to:
  /// **'选修'**
  String get courseNatureElective;

  /// No description provided for @homeMenuStatisticsTitle.
  ///
  /// In zh, this message translates to:
  /// **'课程统计'**
  String get homeMenuStatisticsTitle;

  /// No description provided for @statisticsTitle.
  ///
  /// In zh, this message translates to:
  /// **'课程统计'**
  String get statisticsTitle;

  /// No description provided for @statisticsOverview.
  ///
  /// In zh, this message translates to:
  /// **'本周概览'**
  String get statisticsOverview;

  /// No description provided for @statisticsCourseCount.
  ///
  /// In zh, this message translates to:
  /// **'课程门数'**
  String get statisticsCourseCount;

  /// No description provided for @statisticsSectionCount.
  ///
  /// In zh, this message translates to:
  /// **'本周课时'**
  String get statisticsSectionCount;

  /// No description provided for @statisticsWeeklyCourses.
  ///
  /// In zh, this message translates to:
  /// **'本周课程'**
  String get statisticsWeeklyCourses;

  /// No description provided for @statisticsDailyDistribution.
  ///
  /// In zh, this message translates to:
  /// **'每日课时分布'**
  String get statisticsDailyDistribution;

  /// No description provided for @statisticsNatureRatio.
  ///
  /// In zh, this message translates to:
  /// **'必修 / 选修'**
  String get statisticsNatureRatio;

  /// No description provided for @statisticsCourseList.
  ///
  /// In zh, this message translates to:
  /// **'课程列表'**
  String get statisticsCourseList;

  /// No description provided for @statisticsSectionsUnit.
  ///
  /// In zh, this message translates to:
  /// **'节'**
  String get statisticsSectionsUnit;

  /// No description provided for @statisticsSectionUnit.
  ///
  /// In zh, this message translates to:
  /// **'节'**
  String get statisticsSectionUnit;

  /// No description provided for @statisticsNoData.
  ///
  /// In zh, this message translates to:
  /// **'暂无课程数据'**
  String get statisticsNoData;

  /// No description provided for @statisticsCourseCountRatio.
  ///
  /// In zh, this message translates to:
  /// **'门数比例'**
  String get statisticsCourseCountRatio;

  /// No description provided for @statisticsSectionCountRatio.
  ///
  /// In zh, this message translates to:
  /// **'课时比例'**
  String get statisticsSectionCountRatio;

  /// No description provided for @statisticsWeekSelector.
  ///
  /// In zh, this message translates to:
  /// **'第 {week} 周'**
  String statisticsWeekSelector(int week);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'ko', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'HK':
            return AppLocalizationsZhHk();
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
