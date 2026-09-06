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

  /// No description provided for @appTitleProfile.
  ///
  /// In zh, this message translates to:
  /// **'轻屿课表性能版'**
  String get appTitleProfile;

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
  /// **'支持跟随系统、浅色模式和深色模式'**
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
  /// **'内置 Inter 默认；也可选用系统已安装的字体'**
  String get fontSectionSubtitle;

  /// No description provided for @fontSectionFootnote.
  ///
  /// In zh, this message translates to:
  /// **'厂商字体未内置，需系统已预装才生效，小米通常只有 MiSans 明显；没变化时会自动回退，一般不必自行安装'**
  String get fontSectionFootnote;

  /// No description provided for @fontModeLabel.
  ///
  /// In zh, this message translates to:
  /// **'字体选择'**
  String get fontModeLabel;

  /// No description provided for @fontModeSystem.
  ///
  /// In zh, this message translates to:
  /// **'应用默认'**
  String get fontModeSystem;

  /// No description provided for @fontModeSansSerif.
  ///
  /// In zh, this message translates to:
  /// **'系统无衬线'**
  String get fontModeSansSerif;

  /// No description provided for @fontModeMiSans.
  ///
  /// In zh, this message translates to:
  /// **'MiSans'**
  String get fontModeMiSans;

  /// No description provided for @fontModeHarmonyOS.
  ///
  /// In zh, this message translates to:
  /// **'鸿蒙黑体'**
  String get fontModeHarmonyOS;

  /// No description provided for @fontModeOppoSans.
  ///
  /// In zh, this message translates to:
  /// **'OPPO Sans'**
  String get fontModeOppoSans;

  /// No description provided for @fontModePingFang.
  ///
  /// In zh, this message translates to:
  /// **'苹方'**
  String get fontModePingFang;

  /// No description provided for @fontModeNotoSans.
  ///
  /// In zh, this message translates to:
  /// **'Noto Sans'**
  String get fontModeNotoSans;

  /// No description provided for @fontModeSerif.
  ///
  /// In zh, this message translates to:
  /// **'衬线体'**
  String get fontModeSerif;

  /// No description provided for @fontModeSongti.
  ///
  /// In zh, this message translates to:
  /// **'宋体'**
  String get fontModeSongti;

  /// No description provided for @fontModeMonospace.
  ///
  /// In zh, this message translates to:
  /// **'等宽体'**
  String get fontModeMonospace;

  /// No description provided for @languageSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'应用语言'**
  String get languageSectionTitle;

  /// No description provided for @languageSectionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'可跟随系统，或手动切换到已适配语言'**
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
  /// **'主题模式、字体、首页标题与弹窗磨砂玻璃'**
  String get appearanceEntrySubtitle;

  /// No description provided for @appearanceThemeDisplaySectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'主题与显示'**
  String get appearanceThemeDisplaySectionTitle;

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

  /// No description provided for @timeSchemeEntryNotSelected.
  ///
  /// In zh, this message translates to:
  /// **'未选择'**
  String get timeSchemeEntryNotSelected;

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

  /// No description provided for @coupleTimetableEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'情侣课表'**
  String get coupleTimetableEntryTitle;

  /// No description provided for @coupleTimetableEntryBound.
  ///
  /// In zh, this message translates to:
  /// **'已绑定'**
  String get coupleTimetableEntryBound;

  /// No description provided for @coupleTimetableModeEnableTooltip.
  ///
  /// In zh, this message translates to:
  /// **'开启情侣课表'**
  String get coupleTimetableModeEnableTooltip;

  /// No description provided for @coupleTimetableModeDisableTooltip.
  ///
  /// In zh, this message translates to:
  /// **'关闭情侣课表'**
  String get coupleTimetableModeDisableTooltip;

  /// No description provided for @coupleTimetableTitle.
  ///
  /// In zh, this message translates to:
  /// **'情侣课表'**
  String get coupleTimetableTitle;

  /// No description provided for @coupleTimetableIntro.
  ///
  /// In zh, this message translates to:
  /// **'导出你的课表发给 TA，或导入 TA 分享的课表文件，导入后可在叠加视图中查看双方课程'**
  String get coupleTimetableIntro;

  /// No description provided for @coupleTimetableBoundTitle.
  ///
  /// In zh, this message translates to:
  /// **'已绑定对方课表'**
  String get coupleTimetableBoundTitle;

  /// No description provided for @coupleTimetableUnboundTitle.
  ///
  /// In zh, this message translates to:
  /// **'尚未绑定对方课表'**
  String get coupleTimetableUnboundTitle;

  /// No description provided for @coupleTimetablePartnerNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'对方名称'**
  String get coupleTimetablePartnerNameLabel;

  /// No description provided for @coupleTimetableLastImportedAt.
  ///
  /// In zh, this message translates to:
  /// **'上次导入：{time}'**
  String coupleTimetableLastImportedAt(String time);

  /// No description provided for @coupleTimetableExportForPartner.
  ///
  /// In zh, this message translates to:
  /// **'导出我的课表给对方'**
  String get coupleTimetableExportForPartner;

  /// No description provided for @coupleTimetableImportPartner.
  ///
  /// In zh, this message translates to:
  /// **'导入对方课表'**
  String get coupleTimetableImportPartner;

  /// No description provided for @coupleTimetableUnlink.
  ///
  /// In zh, this message translates to:
  /// **'解除绑定'**
  String get coupleTimetableUnlink;

  /// No description provided for @coupleTimetableOpenOverlay.
  ///
  /// In zh, this message translates to:
  /// **'进入叠加视图'**
  String get coupleTimetableOpenOverlay;

  /// No description provided for @coupleTimetableImportSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已导入对方课表'**
  String get coupleTimetableImportSuccess;

  /// No description provided for @coupleTimetableImportUpdated.
  ///
  /// In zh, this message translates to:
  /// **'已更新对方课表'**
  String get coupleTimetableImportUpdated;

  /// No description provided for @coupleTimetableUnlinkConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'解除情侣课表绑定？'**
  String get coupleTimetableUnlinkConfirmTitle;

  /// No description provided for @coupleTimetableUnlinkConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'解除后将删除本地保存的对方课表，叠加视图也会关闭'**
  String get coupleTimetableUnlinkConfirmMessage;

  /// No description provided for @coupleTimetableUnlinkSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已解除绑定'**
  String get coupleTimetableUnlinkSuccess;

  /// No description provided for @coupleTimetablePrivacyHint.
  ///
  /// In zh, this message translates to:
  /// **'对方只能看到你导出文件中包含的课表内容'**
  String get coupleTimetablePrivacyHint;

  /// No description provided for @coupleTimetableOverlayTitle.
  ///
  /// In zh, this message translates to:
  /// **'情侣叠加'**
  String get coupleTimetableOverlayTitle;

  /// No description provided for @coupleTimetableLegendMine.
  ///
  /// In zh, this message translates to:
  /// **'我的课'**
  String get coupleTimetableLegendMine;

  /// No description provided for @coupleTimetableLegendPartner.
  ///
  /// In zh, this message translates to:
  /// **'TA的课'**
  String get coupleTimetableLegendPartner;

  /// No description provided for @coupleTimetableLegendTogether.
  ///
  /// In zh, this message translates to:
  /// **'一起上课'**
  String get coupleTimetableLegendTogether;

  /// No description provided for @coupleTimetableLegendFree.
  ///
  /// In zh, this message translates to:
  /// **'共同空闲'**
  String get coupleTimetableLegendFree;

  /// No description provided for @coupleTimetableSharedFreeTitle.
  ///
  /// In zh, this message translates to:
  /// **'今日共同空闲'**
  String get coupleTimetableSharedFreeTitle;

  /// No description provided for @coupleTimetableSharedFreeTitleOtherDay.
  ///
  /// In zh, this message translates to:
  /// **'该日共同空闲'**
  String get coupleTimetableSharedFreeTitleOtherDay;

  /// No description provided for @coupleTimetableNoSharedFree.
  ///
  /// In zh, this message translates to:
  /// **'今天没有共同空闲时段'**
  String get coupleTimetableNoSharedFree;

  /// No description provided for @coupleTimetableNoSharedFreeOtherDay.
  ///
  /// In zh, this message translates to:
  /// **'该日没有共同空闲时段'**
  String get coupleTimetableNoSharedFreeOtherDay;

  /// No description provided for @coupleTimetableSharedFreeMeta.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 段'**
  String coupleTimetableSharedFreeMeta(int count);

  /// No description provided for @coupleTimetableSharedFreeMoreCount.
  ///
  /// In zh, this message translates to:
  /// **'还有 {count} 段'**
  String coupleTimetableSharedFreeMoreCount(int count);

  /// No description provided for @coupleTimetableSharedFreeUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'暂时算不出共同空闲'**
  String get coupleTimetableSharedFreeUnavailable;

  /// No description provided for @coupleTimetableSharedFreeStaleHint.
  ///
  /// In zh, this message translates to:
  /// **'对方课表可能不是最新'**
  String get coupleTimetableSharedFreeStaleHint;

  /// No description provided for @coupleTimetablePartnerReadOnlyBadge.
  ///
  /// In zh, this message translates to:
  /// **'对方课表（只读）'**
  String get coupleTimetablePartnerReadOnlyBadge;

  /// No description provided for @coupleTimetableNotBoundMessage.
  ///
  /// In zh, this message translates to:
  /// **'请先导入对方课表后再查看叠加视图'**
  String get coupleTimetableNotBoundMessage;

  /// No description provided for @coupleTimetableShareText.
  ///
  /// In zh, this message translates to:
  /// **'这是我的课表，导入到轻屿课表的情侣课表即可一起查看'**
  String get coupleTimetableShareText;

  /// No description provided for @coupleTimetableShareSubject.
  ///
  /// In zh, this message translates to:
  /// **'轻屿课表 · 情侣课表分享'**
  String get coupleTimetableShareSubject;

  /// No description provided for @coupleTimetableWeekOffsetTitle.
  ///
  /// In zh, this message translates to:
  /// **'周次偏移'**
  String get coupleTimetableWeekOffsetTitle;

  /// No description provided for @coupleTimetableWeekOffsetSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'查看你的第 N 周时，读取对方课表的第 N+偏移 周，例如 +1 表示对方学期进度比你快一周'**
  String get coupleTimetableWeekOffsetSubtitle;

  /// No description provided for @coupleTimetableWeekOffsetZero.
  ///
  /// In zh, this message translates to:
  /// **'无偏移'**
  String get coupleTimetableWeekOffsetZero;

  /// No description provided for @coupleTimetableWeekOffsetSigned.
  ///
  /// In zh, this message translates to:
  /// **'{offset} 周'**
  String coupleTimetableWeekOffsetSigned(String offset);

  /// No description provided for @coupleTimetableWeekOffsetPreview.
  ///
  /// In zh, this message translates to:
  /// **'查看你的第 {myWeek} 周时，显示对方第 {partnerWeek} 周的课'**
  String coupleTimetableWeekOffsetPreview(int myWeek, int partnerWeek);

  /// No description provided for @coupleTimetableColorsTitle.
  ///
  /// In zh, this message translates to:
  /// **'叠加颜色'**
  String get coupleTimetableColorsTitle;

  /// No description provided for @coupleTimetableColorsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'自定义「我的课」「TA的课」「一起上课」在叠加视图中的显示颜色，可按喜好自由搭配'**
  String get coupleTimetableColorsSubtitle;

  /// No description provided for @partnerImportRequiresSingleProfile.
  ///
  /// In zh, this message translates to:
  /// **'请导入单课表备份文件，不支持全量备份'**
  String get partnerImportRequiresSingleProfile;

  /// No description provided for @coupleWebdavTitle.
  ///
  /// In zh, this message translates to:
  /// **'坚果云拉取'**
  String get coupleWebdavTitle;

  /// No description provided for @coupleWebdavSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'登录对方（或你们共用的）坚果云账号，自动下载对方上传的课表文件，与「云同步」账号独立，互不影响'**
  String get coupleWebdavSubtitle;

  /// No description provided for @coupleWebdavNotConnected.
  ///
  /// In zh, this message translates to:
  /// **'尚未连接坚果云'**
  String get coupleWebdavNotConnected;

  /// No description provided for @coupleWebdavConnectedAs.
  ///
  /// In zh, this message translates to:
  /// **'已连接：{username}'**
  String coupleWebdavConnectedAs(String username);

  /// No description provided for @coupleWebdavRemotePathHint.
  ///
  /// In zh, this message translates to:
  /// **'远程文件路径：{path}'**
  String coupleWebdavRemotePathHint(String path);

  /// No description provided for @coupleWebdavLastPulledAt.
  ///
  /// In zh, this message translates to:
  /// **'上次拉取：{time}'**
  String coupleWebdavLastPulledAt(String time);

  /// No description provided for @coupleWebdavConnect.
  ///
  /// In zh, this message translates to:
  /// **'连接坚果云'**
  String get coupleWebdavConnect;

  /// No description provided for @coupleWebdavDisconnect.
  ///
  /// In zh, this message translates to:
  /// **'断开连接'**
  String get coupleWebdavDisconnect;

  /// No description provided for @coupleWebdavPullNow.
  ///
  /// In zh, this message translates to:
  /// **'立即拉取对方课表'**
  String get coupleWebdavPullNow;

  /// No description provided for @coupleWebdavUploadForPartner.
  ///
  /// In zh, this message translates to:
  /// **'上传我的课表到坚果云'**
  String get coupleWebdavUploadForPartner;

  /// No description provided for @coupleWebdavLoginSheetTitle.
  ///
  /// In zh, this message translates to:
  /// **'连接坚果云（情侣课表）'**
  String get coupleWebdavLoginSheetTitle;

  /// No description provided for @coupleWebdavLoginSheetSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'请使用应用专用密码，对方需先将课表上传到约定路径，或由你在对方设备上登录同一账号并上传'**
  String get coupleWebdavLoginSheetSubtitle;

  /// No description provided for @coupleWebdavConfirmConnect.
  ///
  /// In zh, this message translates to:
  /// **'连接并拉取'**
  String get coupleWebdavConfirmConnect;

  /// No description provided for @coupleWebdavMySlotLabel.
  ///
  /// In zh, this message translates to:
  /// **'本机槽位'**
  String get coupleWebdavMySlotLabel;

  /// No description provided for @coupleWebdavMySlotHint.
  ///
  /// In zh, this message translates to:
  /// **'双方必须选不同槽位：一方选 1，另一方选 2，否则会互相读不到课表'**
  String get coupleWebdavMySlotHint;

  /// No description provided for @coupleWebdavSlotOne.
  ///
  /// In zh, this message translates to:
  /// **'槽位 1'**
  String get coupleWebdavSlotOne;

  /// No description provided for @coupleWebdavSlotTwo.
  ///
  /// In zh, this message translates to:
  /// **'槽位 2'**
  String get coupleWebdavSlotTwo;

  /// No description provided for @coupleWebdavTestSuccess.
  ///
  /// In zh, this message translates to:
  /// **'坚果云连接成功'**
  String get coupleWebdavTestSuccess;

  /// No description provided for @coupleWebdavTestFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接失败，请检查账号、应用专用密码与网络'**
  String get coupleWebdavTestFailed;

  /// No description provided for @coupleWebdavPullImported.
  ///
  /// In zh, this message translates to:
  /// **'已从坚果云导入对方课表'**
  String get coupleWebdavPullImported;

  /// No description provided for @coupleWebdavPullUpdated.
  ///
  /// In zh, this message translates to:
  /// **'已从坚果云更新对方课表'**
  String get coupleWebdavPullUpdated;

  /// No description provided for @coupleWebdavPullUnchanged.
  ///
  /// In zh, this message translates to:
  /// **'对方课表无变化'**
  String get coupleWebdavPullUnchanged;

  /// No description provided for @coupleWebdavUploadSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已上传课表，对方可拉取'**
  String get coupleWebdavUploadSuccess;

  /// No description provided for @coupleWebdavPartnerFileMissing.
  ///
  /// In zh, this message translates to:
  /// **'未找到对方课表文件，请让对方先上传'**
  String get coupleWebdavPartnerFileMissing;

  /// No description provided for @coupleWebdavPullFailed.
  ///
  /// In zh, this message translates to:
  /// **'拉取对方课表失败，请稍后重试'**
  String get coupleWebdavPullFailed;

  /// No description provided for @coupleWebdavNotConnectedError.
  ///
  /// In zh, this message translates to:
  /// **'请先连接坚果云'**
  String get coupleWebdavNotConnectedError;

  /// No description provided for @cloudSyncEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'云同步'**
  String get cloudSyncEntryTitle;

  /// No description provided for @cloudSyncEntrySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'通过坚果云等多设备同步课表与导入数据'**
  String get cloudSyncEntrySubtitle;

  /// No description provided for @cloudSyncEntryDisabled.
  ///
  /// In zh, this message translates to:
  /// **'已关闭'**
  String get cloudSyncEntryDisabled;

  /// No description provided for @cloudSyncEntryEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已开启'**
  String get cloudSyncEntryEnabled;

  /// No description provided for @cloudSyncEntrySyncing.
  ///
  /// In zh, this message translates to:
  /// **'同步中'**
  String get cloudSyncEntrySyncing;

  /// No description provided for @cloudSyncEntryError.
  ///
  /// In zh, this message translates to:
  /// **'上次同步失败'**
  String get cloudSyncEntryError;

  /// No description provided for @cloudSyncTitle.
  ///
  /// In zh, this message translates to:
  /// **'云同步'**
  String get cloudSyncTitle;

  /// No description provided for @cloudSyncIntroTitle.
  ///
  /// In zh, this message translates to:
  /// **'多设备同步'**
  String get cloudSyncIntroTitle;

  /// No description provided for @cloudSyncIntroSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'配置坚果云 WebDAV 后，可在手机、平板之间自动同步课表、仓库账号与相关设置'**
  String get cloudSyncIntroSubtitle;

  /// No description provided for @cloudSyncSettingsSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'同步设置'**
  String get cloudSyncSettingsSectionTitle;

  /// No description provided for @cloudSyncSettingsSectionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'可切换手动或自动同步'**
  String get cloudSyncSettingsSectionSubtitle;

  /// No description provided for @cloudSyncEnabledTitle.
  ///
  /// In zh, this message translates to:
  /// **'启用云同步'**
  String get cloudSyncEnabledTitle;

  /// No description provided for @cloudSyncEnabledSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'关闭后不会上传或下载云端快照'**
  String get cloudSyncEnabledSubtitle;

  /// No description provided for @cloudSyncProviderTitle.
  ///
  /// In zh, this message translates to:
  /// **'服务提供商'**
  String get cloudSyncProviderTitle;

  /// No description provided for @cloudSyncProviderJianguoyun.
  ///
  /// In zh, this message translates to:
  /// **'坚果云'**
  String get cloudSyncProviderJianguoyun;

  /// No description provided for @cloudSyncProviderCustom.
  ///
  /// In zh, this message translates to:
  /// **'自定义 WebDAV'**
  String get cloudSyncProviderCustom;

  /// No description provided for @cloudSyncModeTitle.
  ///
  /// In zh, this message translates to:
  /// **'同步方式'**
  String get cloudSyncModeTitle;

  /// No description provided for @cloudSyncModeAuto.
  ///
  /// In zh, this message translates to:
  /// **'自动同步'**
  String get cloudSyncModeAuto;

  /// No description provided for @cloudSyncModeManual.
  ///
  /// In zh, this message translates to:
  /// **'手动同步'**
  String get cloudSyncModeManual;

  /// No description provided for @cloudSyncAccountTitle.
  ///
  /// In zh, this message translates to:
  /// **'账号配置'**
  String get cloudSyncAccountTitle;

  /// No description provided for @cloudSyncAccountSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'请使用坚果云应用专用密码，而不是登录密码，快照会包含仓库记住的学校账号'**
  String get cloudSyncAccountSubtitle;

  /// No description provided for @cloudSyncUsernameLabel.
  ///
  /// In zh, this message translates to:
  /// **'邮箱 / 用户名'**
  String get cloudSyncUsernameLabel;

  /// No description provided for @cloudSyncUsernameHint.
  ///
  /// In zh, this message translates to:
  /// **'坚果云注册邮箱'**
  String get cloudSyncUsernameHint;

  /// No description provided for @cloudSyncPasswordLabel.
  ///
  /// In zh, this message translates to:
  /// **'应用专用密码'**
  String get cloudSyncPasswordLabel;

  /// No description provided for @cloudSyncPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'在坚果云账户安全选项中生成'**
  String get cloudSyncPasswordHint;

  /// No description provided for @cloudSyncPasswordStoredHint.
  ///
  /// In zh, this message translates to:
  /// **'已保存密码；留空表示继续使用已保存的密码'**
  String get cloudSyncPasswordStoredHint;

  /// No description provided for @cloudSyncAdvancedTitle.
  ///
  /// In zh, this message translates to:
  /// **'高级设置'**
  String get cloudSyncAdvancedTitle;

  /// No description provided for @cloudSyncBaseUrlLabel.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 地址'**
  String get cloudSyncBaseUrlLabel;

  /// 安全提示：说明正式版仅支持HTTPS加密连接，HTTP明文协议已被禁用
  ///
  /// In zh, this message translates to:
  /// **'建议使用 HTTPS 加密连接；HTTP 明文连接仅建议在可信网络环境下使用'**
  String get cloudSyncBaseUrlSecurityNote;

  /// No description provided for @cloudSyncRemoteFolderLabel.
  ///
  /// In zh, this message translates to:
  /// **'远程目录'**
  String get cloudSyncRemoteFolderLabel;

  /// No description provided for @cloudSyncStatusTitle.
  ///
  /// In zh, this message translates to:
  /// **'同步状态'**
  String get cloudSyncStatusTitle;

  /// No description provided for @cloudSyncLastSyncedLabel.
  ///
  /// In zh, this message translates to:
  /// **'上次同步'**
  String get cloudSyncLastSyncedLabel;

  /// No description provided for @cloudSyncLastErrorLabel.
  ///
  /// In zh, this message translates to:
  /// **'最近错误'**
  String get cloudSyncLastErrorLabel;

  /// No description provided for @cloudSyncLastSyncedAt.
  ///
  /// In zh, this message translates to:
  /// **'上次同步：{time}'**
  String cloudSyncLastSyncedAt(String time);

  /// No description provided for @cloudSyncSyncing.
  ///
  /// In zh, this message translates to:
  /// **'正在同步…'**
  String get cloudSyncSyncing;

  /// No description provided for @cloudSyncLastError.
  ///
  /// In zh, this message translates to:
  /// **'最近错误：{message}'**
  String cloudSyncLastError(String message);

  /// No description provided for @cloudSyncHelpTitle.
  ///
  /// In zh, this message translates to:
  /// **'如何获取坚果云应用密码'**
  String get cloudSyncHelpTitle;

  /// No description provided for @cloudSyncHelpBody.
  ///
  /// In zh, this message translates to:
  /// **'打开坚果云网页或客户端 → 账户信息 → 安全选项 → 添加应用密码，WebDAV 地址默认为 https://dav.jianguoyun.com/dav/ '**
  String get cloudSyncHelpBody;

  /// No description provided for @cloudSyncTestConnection.
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get cloudSyncTestConnection;

  /// No description provided for @cloudSyncSyncNow.
  ///
  /// In zh, this message translates to:
  /// **'立即同步'**
  String get cloudSyncSyncNow;

  /// No description provided for @cloudSyncSyncNowSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'与其他设备对齐课表：先拉取云端更新，再上传本机修改'**
  String get cloudSyncSyncNowSubtitle;

  /// No description provided for @cloudSyncTestSuccess.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 连接成功'**
  String get cloudSyncTestSuccess;

  /// No description provided for @cloudSyncTestFailed.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 连接失败，请检查账号、应用密码和网络'**
  String get cloudSyncTestFailed;

  /// No description provided for @cloudSyncResultUploaded.
  ///
  /// In zh, this message translates to:
  /// **'已上传到云端'**
  String get cloudSyncResultUploaded;

  /// No description provided for @cloudSyncResultDownloaded.
  ///
  /// In zh, this message translates to:
  /// **'已从云端恢复'**
  String get cloudSyncResultDownloaded;

  /// No description provided for @cloudSyncResultUpToDate.
  ///
  /// In zh, this message translates to:
  /// **'本地与云端已一致'**
  String get cloudSyncResultUpToDate;

  /// No description provided for @cloudSyncResultCancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消同步'**
  String get cloudSyncResultCancelled;

  /// No description provided for @cloudSyncResultFailed.
  ///
  /// In zh, this message translates to:
  /// **'同步失败：{message}'**
  String cloudSyncResultFailed(String message);

  /// No description provided for @cloudSyncConflictTitle.
  ///
  /// In zh, this message translates to:
  /// **'检测到同步冲突'**
  String get cloudSyncConflictTitle;

  /// No description provided for @cloudSyncConflictBody.
  ///
  /// In zh, this message translates to:
  /// **'本机和云端都有新的修改，请选择保留哪一边的数据'**
  String get cloudSyncConflictBody;

  /// No description provided for @cloudSyncUseRemoteAction.
  ///
  /// In zh, this message translates to:
  /// **'使用云端'**
  String get cloudSyncUseRemoteAction;

  /// No description provided for @cloudSyncKeepLocalAction.
  ///
  /// In zh, this message translates to:
  /// **'保留本机'**
  String get cloudSyncKeepLocalAction;

  /// No description provided for @cloudSyncConflictFirstSyncTitle.
  ///
  /// In zh, this message translates to:
  /// **'本机与云端数据不一致'**
  String get cloudSyncConflictFirstSyncTitle;

  /// No description provided for @cloudSyncConflictFirstSyncBody.
  ///
  /// In zh, this message translates to:
  /// **'云端已有数据，与本机不一致。选「保留本机」会上传本机数据覆盖云端；选「使用云端」会下载云端数据替换本机。'**
  String get cloudSyncConflictFirstSyncBody;

  /// No description provided for @cloudSyncKeepLocalBackupAction.
  ///
  /// In zh, this message translates to:
  /// **'以本机为准备份'**
  String get cloudSyncKeepLocalBackupAction;

  /// No description provided for @cloudSyncAccountSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'云账号'**
  String get cloudSyncAccountSectionTitle;

  /// No description provided for @cloudSyncNotConnectedHint.
  ///
  /// In zh, this message translates to:
  /// **'连接坚果云后，可在多设备间同步课表与导入数据'**
  String get cloudSyncNotConnectedHint;

  /// No description provided for @cloudSyncConnectAccount.
  ///
  /// In zh, this message translates to:
  /// **'连接坚果云'**
  String get cloudSyncConnectAccount;

  /// No description provided for @cloudSyncConnectedAs.
  ///
  /// In zh, this message translates to:
  /// **'已连接：{email}'**
  String cloudSyncConnectedAs(String email);

  /// No description provided for @cloudSyncDisconnect.
  ///
  /// In zh, this message translates to:
  /// **'断开连接'**
  String get cloudSyncDisconnect;

  /// No description provided for @cloudSyncDisconnectTitle.
  ///
  /// In zh, this message translates to:
  /// **'断开云同步账号'**
  String get cloudSyncDisconnectTitle;

  /// No description provided for @cloudSyncDisconnectBody.
  ///
  /// In zh, this message translates to:
  /// **'断开后将清除本机保存的 WebDAV 凭据，课表数据仍保留在本机，是否继续？'**
  String get cloudSyncDisconnectBody;

  /// No description provided for @cloudSyncLoginSheetTitle.
  ///
  /// In zh, this message translates to:
  /// **'连接坚果云'**
  String get cloudSyncLoginSheetTitle;

  /// No description provided for @cloudSyncLoginSheetSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'请使用应用专用密码，不要使用坚果云登录密码'**
  String get cloudSyncLoginSheetSubtitle;

  /// No description provided for @cloudSyncConfirmConnect.
  ///
  /// In zh, this message translates to:
  /// **'确认连接'**
  String get cloudSyncConfirmConnect;

  /// No description provided for @cloudSyncConnectSuccess.
  ///
  /// In zh, this message translates to:
  /// **'账号连接成功'**
  String get cloudSyncConnectSuccess;

  /// No description provided for @cloudBackupSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'可恢复版本'**
  String get cloudBackupSectionTitle;

  /// No description provided for @cloudBackupSectionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'每次同步都会自动保留可恢复版本'**
  String get cloudBackupSectionSubtitle;

  /// No description provided for @cloudBackupCurrentLabel.
  ///
  /// In zh, this message translates to:
  /// **'当前版本'**
  String get cloudBackupCurrentLabel;

  /// No description provided for @cloudBackupCurrentBadge.
  ///
  /// In zh, this message translates to:
  /// **'当前'**
  String get cloudBackupCurrentBadge;

  /// No description provided for @cloudBackupCreateNow.
  ///
  /// In zh, this message translates to:
  /// **'立即备份'**
  String get cloudBackupCreateNow;

  /// No description provided for @cloudBackupViewAll.
  ///
  /// In zh, this message translates to:
  /// **'查看全部可恢复版本'**
  String get cloudBackupViewAll;

  /// No description provided for @cloudBackupEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无可恢复版本，同步后会自动生成'**
  String get cloudBackupEmpty;

  /// No description provided for @cloudBackupSourceAuto.
  ///
  /// In zh, this message translates to:
  /// **'自动备份'**
  String get cloudBackupSourceAuto;

  /// No description provided for @cloudBackupSourceManual.
  ///
  /// In zh, this message translates to:
  /// **'手动备份'**
  String get cloudBackupSourceManual;

  /// No description provided for @cloudBackupDefaultDeviceLabel.
  ///
  /// In zh, this message translates to:
  /// **'本机'**
  String get cloudBackupDefaultDeviceLabel;

  /// No description provided for @cloudBackupDeviceLabelTitle.
  ///
  /// In zh, this message translates to:
  /// **'设备名称'**
  String get cloudBackupDeviceLabelTitle;

  /// No description provided for @cloudBackupDeviceLabelHint.
  ///
  /// In zh, this message translates to:
  /// **'在备份列表中显示，例如「我的手机」'**
  String get cloudBackupDeviceLabelHint;

  /// No description provided for @cloudBackupSummary.
  ///
  /// In zh, this message translates to:
  /// **'{profileCount} 个课表 · {courseCount} 门课程'**
  String cloudBackupSummary(int profileCount, int courseCount);

  /// No description provided for @cloudBackupRestoreTitle.
  ///
  /// In zh, this message translates to:
  /// **'恢复到此备份'**
  String get cloudBackupRestoreTitle;

  /// No description provided for @cloudBackupRestoreBody.
  ///
  /// In zh, this message translates to:
  /// **'将恢复到 {time} 的课表，本地未同步的修改会丢失，是否继续？'**
  String cloudBackupRestoreBody(String time);

  /// No description provided for @cloudBackupRestoreAction.
  ///
  /// In zh, this message translates to:
  /// **'恢复'**
  String get cloudBackupRestoreAction;

  /// No description provided for @cloudBackupRestoreSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已恢复到此备份'**
  String get cloudBackupRestoreSuccess;

  /// No description provided for @cloudBackupRestoreFailed.
  ///
  /// In zh, this message translates to:
  /// **'恢复失败：{message}'**
  String cloudBackupRestoreFailed(String message);

  /// No description provided for @cloudBackupDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除此备份'**
  String get cloudBackupDeleteTitle;

  /// No description provided for @cloudBackupDeleteBody.
  ///
  /// In zh, this message translates to:
  /// **'确定删除 {time} 的云端备份吗？此操作不可撤销'**
  String cloudBackupDeleteBody(String time);

  /// No description provided for @cloudBackupDeleteSuccess.
  ///
  /// In zh, this message translates to:
  /// **'备份已删除'**
  String get cloudBackupDeleteSuccess;

  /// No description provided for @cloudBackupDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除失败：{message}'**
  String cloudBackupDeleteFailed(String message);

  /// No description provided for @cloudBackupCreateSuccess.
  ///
  /// In zh, this message translates to:
  /// **'备份已保存到云端'**
  String get cloudBackupCreateSuccess;

  /// No description provided for @cloudBackupCreateFailed.
  ///
  /// In zh, this message translates to:
  /// **'备份失败：{message}'**
  String cloudBackupCreateFailed(String message);

  /// No description provided for @cloudBackupUploadAsCurrentTitle.
  ///
  /// In zh, this message translates to:
  /// **'设为当前云端版本'**
  String get cloudBackupUploadAsCurrentTitle;

  /// No description provided for @cloudBackupUploadAsCurrentBody.
  ///
  /// In zh, this message translates to:
  /// **'是否将此备份设为当前云端版本？建议开启，可避免其他设备同步冲突'**
  String get cloudBackupUploadAsCurrentBody;

  /// No description provided for @cloudBackupUploadAsCurrentYes.
  ///
  /// In zh, this message translates to:
  /// **'设为当前版本'**
  String get cloudBackupUploadAsCurrentYes;

  /// No description provided for @cloudBackupUploadAsCurrentNo.
  ///
  /// In zh, this message translates to:
  /// **'仅恢复本地'**
  String get cloudBackupUploadAsCurrentNo;

  /// No description provided for @cloudBackupDetailDevice.
  ///
  /// In zh, this message translates to:
  /// **'设备'**
  String get cloudBackupDetailDevice;

  /// No description provided for @cloudBackupDetailSource.
  ///
  /// In zh, this message translates to:
  /// **'来源'**
  String get cloudBackupDetailSource;

  /// No description provided for @cloudBackupDetailSummary.
  ///
  /// In zh, this message translates to:
  /// **'内容'**
  String get cloudBackupDetailSummary;

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
  /// **'开启后，同一 WiFi 或手机热点下的电脑可通过浏览器编辑当前课表，数据不会上传云端，关闭后即停止访问'**
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
  /// **'如果宿舍 WiFi 无法访问，请尝试用手机开热点，再让电脑连接该热点'**
  String get lanEditHotspotHint;

  /// No description provided for @lanEditQrHint.
  ///
  /// In zh, this message translates to:
  /// **'电脑浏览器扫描上方二维码可打开控制台（链接已含 PIN，需同一局域网）'**
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

  /// No description provided for @lanEditKeepAliveWhenLeavingTitle.
  ///
  /// In zh, this message translates to:
  /// **'离开后保持开启'**
  String get lanEditKeepAliveWhenLeavingTitle;

  /// No description provided for @lanEditKeepAliveWhenLeavingSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'开启后，返回设置页不会自动关闭局域网编辑；关闭后离开本页即停止'**
  String get lanEditKeepAliveWhenLeavingSubtitle;

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
  /// **'不同学校可按实际教学周数调整'**
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

  /// No description provided for @importRandomCourseColorTitle.
  ///
  /// In zh, this message translates to:
  /// **'随机课程颜色'**
  String get importRandomCourseColorTitle;

  /// No description provided for @importRandomCourseColorSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'按课程名与教师自动分配预设色'**
  String get importRandomCourseColorSubtitle;

  /// No description provided for @importRandomColorGroupTitle.
  ///
  /// In zh, this message translates to:
  /// **'随机配色组'**
  String get importRandomColorGroupTitle;

  /// No description provided for @colorGroupAll.
  ///
  /// In zh, this message translates to:
  /// **'全部颜色'**
  String get colorGroupAll;

  /// No description provided for @colorGroupPastel.
  ///
  /// In zh, this message translates to:
  /// **'马卡龙系'**
  String get colorGroupPastel;

  /// No description provided for @colorGroupVibrant.
  ///
  /// In zh, this message translates to:
  /// **'活泼系'**
  String get colorGroupVibrant;

  /// No description provided for @colorGroupDeep.
  ///
  /// In zh, this message translates to:
  /// **'深色系'**
  String get colorGroupDeep;

  /// No description provided for @colorGroupDopamine.
  ///
  /// In zh, this message translates to:
  /// **'多巴胺系'**
  String get colorGroupDopamine;

  /// No description provided for @colorGroupSunset.
  ///
  /// In zh, this message translates to:
  /// **'落日系'**
  String get colorGroupSunset;

  /// No description provided for @colorGroupOcean.
  ///
  /// In zh, this message translates to:
  /// **'海洋系'**
  String get colorGroupOcean;

  /// No description provided for @courseRecolorTileTitle.
  ///
  /// In zh, this message translates to:
  /// **'课表重新配色'**
  String get courseRecolorTileTitle;

  /// No description provided for @courseRecolorTileSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'不用重新导入，随时一键给全部课程换套颜色'**
  String get courseRecolorTileSubtitle;

  /// No description provided for @courseRecolorSheetTitle.
  ///
  /// In zh, this message translates to:
  /// **'课表重新配色'**
  String get courseRecolorSheetTitle;

  /// No description provided for @courseRecolorSheetDescription.
  ///
  /// In zh, this message translates to:
  /// **'每次「换一批」都会给全部课程刷一套随机颜色；不满意可以切回上一套，或回到导入时的原色。'**
  String get courseRecolorSheetDescription;

  /// No description provided for @courseRecolorNewBatchButton.
  ///
  /// In zh, this message translates to:
  /// **'换一批颜色'**
  String get courseRecolorNewBatchButton;

  /// No description provided for @courseRecolorPrevious.
  ///
  /// In zh, this message translates to:
  /// **'上一套'**
  String get courseRecolorPrevious;

  /// No description provided for @courseRecolorNext.
  ///
  /// In zh, this message translates to:
  /// **'下一套'**
  String get courseRecolorNext;

  /// No description provided for @courseRecolorSchemePosition.
  ///
  /// In zh, this message translates to:
  /// **'第 {index}/{total} 套'**
  String courseRecolorSchemePosition(int index, int total);

  /// No description provided for @courseRecolorNoCoursesToast.
  ///
  /// In zh, this message translates to:
  /// **'暂无课程，先导入或添加课程再换颜色'**
  String get courseRecolorNoCoursesToast;

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
  /// **'现在支持传统 .ics 日历导入、识图导入，以及从仓库读取适配器的教务系统导入'**
  String get chooseImportMethodSubtitle;

  /// No description provided for @importMethodIcsTitle.
  ///
  /// In zh, this message translates to:
  /// **'.ics 日历导入'**
  String get importMethodIcsTitle;

  /// No description provided for @importMethodIcsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'从其他课表应用导出的日历文件'**
  String get importMethodIcsSubtitle;

  /// No description provided for @importMethodIcsFooter.
  ///
  /// In zh, this message translates to:
  /// **'进入后直接选择 .ics 文件，可追加导入或替换现有课程'**
  String get importMethodIcsFooter;

  /// No description provided for @importMethodAiTitle.
  ///
  /// In zh, this message translates to:
  /// **'识图导入'**
  String get importMethodAiTitle;

  /// No description provided for @importMethodAiSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'从课表截图识别并导入'**
  String get importMethodAiSubtitle;

  /// No description provided for @importMethodAiFooter.
  ///
  /// In zh, this message translates to:
  /// **'先复制提示词，再到豆包专家模式发送截图和提示词，把返回的 JSON 复制回来导入，最后选择开学日期'**
  String get importMethodAiFooter;

  /// No description provided for @importMethodWarehouseTitle.
  ///
  /// In zh, this message translates to:
  /// **'教务系统导入'**
  String get importMethodWarehouseTitle;

  /// No description provided for @importMethodWarehouseSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'登录学校教务系统导入'**
  String get importMethodWarehouseSubtitle;

  /// No description provided for @importMethodWarehouseFooter.
  ///
  /// In zh, this message translates to:
  /// **'进入后选择学校和适配器，可直接打开教务网页登录并执行导入'**
  String get importMethodWarehouseFooter;

  /// No description provided for @importMethodSpreadsheetTitle.
  ///
  /// In zh, this message translates to:
  /// **'表格导入'**
  String get importMethodSpreadsheetTitle;

  /// No description provided for @importMethodSpreadsheetSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'填写 Excel / CSV 模板后导入'**
  String get importMethodSpreadsheetSubtitle;

  /// No description provided for @importMethodSpreadsheetFooter.
  ///
  /// In zh, this message translates to:
  /// **'支持 .csv 与 .xlsx，可下载官方模板填写后选择文件导入'**
  String get importMethodSpreadsheetFooter;

  /// No description provided for @spreadsheetImportTitle.
  ///
  /// In zh, this message translates to:
  /// **'表格导入'**
  String get spreadsheetImportTitle;

  /// No description provided for @spreadsheetScenarioIntro.
  ///
  /// In zh, this message translates to:
  /// **'轻屿模板按表头识别列：必填列为课程名、星期、开始节、结束节及周次；其余列为可选，可下载完整模板，也可只保留必要列，也兼容 WakeUp 7 列格式'**
  String get spreadsheetScenarioIntro;

  /// No description provided for @spreadsheetStep1Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'下载完整模板填写，或只保留必填列与上课周（或开始周+结束周）做最小导入'**
  String get spreadsheetStep1Subtitle;

  /// No description provided for @spreadsheetStep2Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'填写完成后另存为 .csv 或直接保留 .xlsx'**
  String get spreadsheetStep2Subtitle;

  /// No description provided for @spreadsheetStep3Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'选择文件导入；如有识别提醒会先展示，再选择追加或替换'**
  String get spreadsheetStep3Subtitle;

  /// No description provided for @spreadsheetSupportedFilesSuffix.
  ///
  /// In zh, this message translates to:
  /// **'支持 .csv 与 .xlsx（仅读取第一个工作表）'**
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
  /// **'如果你已经能在 WakeUp 等课表应用里导入教务系统课程，再导出为 .ics 文件，这条路最稳'**
  String get icsScenarioIntro;

  /// No description provided for @stepLabel.
  ///
  /// In zh, this message translates to:
  /// **'步骤 {step}'**
  String stepLabel(String step);

  /// No description provided for @icsStep1Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'先在其他课表应用里导出 .ics 日历文件'**
  String get icsStep1Subtitle;

  /// No description provided for @icsStep2Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'回到这里选择文件，可选“追加导入”或“替换现有”'**
  String get icsStep2Subtitle;

  /// No description provided for @icsStep3Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'导入前还会让你确认开学日期，以及课表第 1 周对应校历第几周'**
  String get icsStep3Subtitle;

  /// No description provided for @supportedFilesTitle.
  ///
  /// In zh, this message translates to:
  /// **'支持的文件'**
  String get supportedFilesTitle;

  /// No description provided for @supportedFilesSuffix.
  ///
  /// In zh, this message translates to:
  /// **'文件后缀必须是 .ics'**
  String get supportedFilesSuffix;

  /// No description provided for @supportedFilesImageHint.
  ///
  /// In zh, this message translates to:
  /// **'如果你手里只有截图，不要走这里，请返回上一页选择“识图导入”'**
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
  /// **'如果你遇到崩溃、课程显示异常、导入问题，或者想提交功能建议，可以通过下面这些渠道反馈'**
  String get feedbackIntro;

  /// No description provided for @feedbackIssueHint.
  ///
  /// In zh, this message translates to:
  /// **'涉及复现步骤、截图、版本号和日志的问题，建议优先走 GitHub Issue'**
  String get feedbackIssueHint;

  /// No description provided for @githubIssueTitle.
  ///
  /// In zh, this message translates to:
  /// **'GitHub Issue'**
  String get githubIssueTitle;

  /// No description provided for @githubIssueSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'打开仓库 Issue 页面，可提交问题、建议或查看已有反馈记录'**
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

  /// No description provided for @copiedWechatOaName.
  ///
  /// In zh, this message translates to:
  /// **'已复制公众号名称'**
  String get copiedWechatOaName;

  /// No description provided for @feedbackWechatOaOpenHint.
  ///
  /// In zh, this message translates to:
  /// **'已复制公众号名称，请到微信中粘贴搜索'**
  String get feedbackWechatOaOpenHint;

  /// No description provided for @feedbackOpeningChannel.
  ///
  /// In zh, this message translates to:
  /// **'正在打开…'**
  String get feedbackOpeningChannel;

  /// No description provided for @feedbackOpenChannelFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法打开，已复制相关信息'**
  String get feedbackOpenChannelFailed;

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
  /// **'确定清空“{name}”的全部课程吗？课表设置会保留'**
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

  /// No description provided for @qrTransferSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'二维码面对面传输'**
  String get qrTransferSectionTitle;

  /// No description provided for @qrTransferSectionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'两台手机靠近，扫码即可直接传输课表与全部设置，无需网络'**
  String get qrTransferSectionSubtitle;

  /// No description provided for @qrTransferSendCurrent.
  ///
  /// In zh, this message translates to:
  /// **'二维码发送当前课表'**
  String get qrTransferSendCurrent;

  /// No description provided for @qrTransferSendAll.
  ///
  /// In zh, this message translates to:
  /// **'二维码发送全部数据'**
  String get qrTransferSendAll;

  /// No description provided for @qrTransferScanReceive.
  ///
  /// In zh, this message translates to:
  /// **'扫码接收课表数据'**
  String get qrTransferScanReceive;

  /// No description provided for @qrTransferFrameProgress.
  ///
  /// In zh, this message translates to:
  /// **'已发送 {sent} 帧，约需 {total} 帧'**
  String qrTransferFrameProgress(int sent, int total);

  /// No description provided for @qrTransferSendHint.
  ///
  /// In zh, this message translates to:
  /// **'请对方打开「扫码接收」，将摄像头对准此屏幕，保持到接收完成'**
  String get qrTransferSendHint;

  /// No description provided for @qrTransferStop.
  ///
  /// In zh, this message translates to:
  /// **'停止发送'**
  String get qrTransferStop;

  /// No description provided for @qrTransferScanTitle.
  ///
  /// In zh, this message translates to:
  /// **'扫码接收'**
  String get qrTransferScanTitle;

  /// No description provided for @qrTransferScanHint.
  ///
  /// In zh, this message translates to:
  /// **'将摄像头对准对方手机屏幕，保持稳定，等待进度完成'**
  String get qrTransferScanHint;

  /// No description provided for @qrTransferReceiveProgress.
  ///
  /// In zh, this message translates to:
  /// **'已接收 {received} 帧 · 已解出 {decoded}/{total}'**
  String qrTransferReceiveProgress(int received, int decoded, int total);

  /// No description provided for @qrTransferReceiveComplete.
  ///
  /// In zh, this message translates to:
  /// **'数据接收完成，正在导入…'**
  String get qrTransferReceiveComplete;

  /// No description provided for @qrTransferSessionMismatch.
  ///
  /// In zh, this message translates to:
  /// **'检测到不同传输内容，请确认只对准一份数据'**
  String get qrTransferSessionMismatch;

  /// No description provided for @qrTransferChecksumFailed.
  ///
  /// In zh, this message translates to:
  /// **'传输校验失败，请重新开始'**
  String get qrTransferChecksumFailed;

  /// No description provided for @qrTransferRawLengthMismatch.
  ///
  /// In zh, this message translates to:
  /// **'接收数据长度校验失败，请重新开始'**
  String get qrTransferRawLengthMismatch;

  /// No description provided for @qrTransferDecompressionFailed.
  ///
  /// In zh, this message translates to:
  /// **'数据解压失败，请重新开始'**
  String get qrTransferDecompressionFailed;

  /// No description provided for @qrTransferPlaintextWarning.
  ///
  /// In zh, this message translates to:
  /// **'二维码传输是明文，附近摄像头可能读取内容。请确认来源，未经确认不会覆盖数据。'**
  String get qrTransferPlaintextWarning;

  /// No description provided for @qrTransferResourceLimit.
  ///
  /// In zh, this message translates to:
  /// **'接收数据超过二维码传输资源上限，请重新开始并使用更小的备份。'**
  String get qrTransferResourceLimit;

  /// No description provided for @qrTransferSessionExpired.
  ///
  /// In zh, this message translates to:
  /// **'二维码传输已超时，请重新开始并只对准一台设备。'**
  String get qrTransferSessionExpired;

  /// No description provided for @qrTransferFullBackupWarning.
  ///
  /// In zh, this message translates to:
  /// **'确认后，该完整备份会替换本设备上的数据。'**
  String get qrTransferFullBackupWarning;

  /// No description provided for @qrTransferImportFullBackup.
  ///
  /// In zh, this message translates to:
  /// **'导入完整备份'**
  String get qrTransferImportFullBackup;

  /// No description provided for @qrTransferDecodeFailed.
  ///
  /// In zh, this message translates to:
  /// **'二维码数据解码失败，请重新开始'**
  String get qrTransferDecodeFailed;

  /// No description provided for @qrTransferRestart.
  ///
  /// In zh, this message translates to:
  /// **'重新开始'**
  String get qrTransferRestart;

  /// No description provided for @qrTransferSampleFps.
  ///
  /// In zh, this message translates to:
  /// **'采样帧率'**
  String get qrTransferSampleFps;

  /// No description provided for @qrTransferDecodeFps.
  ///
  /// In zh, this message translates to:
  /// **'解码帧率'**
  String get qrTransferDecodeFps;

  /// No description provided for @qrTransferReceiveSpeed.
  ///
  /// In zh, this message translates to:
  /// **'接收速度'**
  String get qrTransferReceiveSpeed;

  /// No description provided for @qrTransferElapsed.
  ///
  /// In zh, this message translates to:
  /// **'已用时间'**
  String get qrTransferElapsed;

  /// No description provided for @qrTransferNewFrames.
  ///
  /// In zh, this message translates to:
  /// **'新增帧'**
  String get qrTransferNewFrames;

  /// No description provided for @qrTransferDuplicateFrames.
  ///
  /// In zh, this message translates to:
  /// **'重复帧'**
  String get qrTransferDuplicateFrames;

  /// No description provided for @qrTransferBlockSize.
  ///
  /// In zh, this message translates to:
  /// **'单块大小'**
  String get qrTransferBlockSize;

  /// No description provided for @qrTransferBlockCount.
  ///
  /// In zh, this message translates to:
  /// **'数据块数'**
  String get qrTransferBlockCount;

  /// No description provided for @qrTransferFileData.
  ///
  /// In zh, this message translates to:
  /// **'文件数据'**
  String get qrTransferFileData;

  /// No description provided for @qrTransferFileDataDetail.
  ///
  /// In zh, this message translates to:
  /// **'原始 {rawSize} · 压缩 {compressedSize}'**
  String qrTransferFileDataDetail(String rawSize, String compressedSize);

  /// No description provided for @qrTransferShareWeek.
  ///
  /// In zh, this message translates to:
  /// **'分享本周课表'**
  String get qrTransferShareWeek;

  /// No description provided for @qrTransferShareSelectedCourses.
  ///
  /// In zh, this message translates to:
  /// **'分享勾选的课程'**
  String get qrTransferShareSelectedCourses;

  /// No description provided for @qrTransferShareTimeTemplate.
  ///
  /// In zh, this message translates to:
  /// **'分享时间模板'**
  String get qrTransferShareTimeTemplate;

  /// No description provided for @qrTransferSelectCoursesDone.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get qrTransferSelectCoursesDone;

  /// No description provided for @dataTransferUndoSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已撤销本次导入'**
  String get dataTransferUndoSuccess;

  /// No description provided for @dataTransferUndoFailed.
  ///
  /// In zh, this message translates to:
  /// **'撤销失败'**
  String get dataTransferUndoFailed;

  /// No description provided for @selectImportModeMerge.
  ///
  /// In zh, this message translates to:
  /// **'合并更改'**
  String get selectImportModeMerge;

  /// No description provided for @fullExportTitle.
  ///
  /// In zh, this message translates to:
  /// **'完整导出'**
  String get fullExportTitle;

  /// No description provided for @fullExportSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'支持导出当前课表，或一次导出全部课表、时间模板和当前选中状态'**
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
  /// **'导入时可以选择覆盖当前课表，或直接导入为一个新课表，建议先导出自己的备份'**
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
  /// **'你可以覆盖当前课表，或者把备份导入成一个新的独立课表'**
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
  /// **'你可以先开始使用，也可以直接导入课程或从备份恢复'**
  String get welcomeSubtitle;

  /// No description provided for @thirdPartyDisclaimer.
  ///
  /// In zh, this message translates to:
  /// **'特此声明：本应用由第三方开发者独立开发，仅用于学习研究用途，不属于小米官方软件，与小米科技有限责任公司无任何隶属、合作或授权关系。如涉及内容侵权，请权利方联系作者，我们将第一时间下架并删除相关内容。'**
  String get thirdPartyDisclaimer;

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
  /// **'我们更换了应用包名，所以桌面上会暂时出现两个应用图标，这是正常现象，旧数据仍在旧版应用里，请先去旧版备份，再回到新版导入'**
  String get migrationSafeSubtitle;

  /// No description provided for @migrationStep1Title.
  ///
  /// In zh, this message translates to:
  /// **'打开旧版应用'**
  String get migrationStep1Title;

  /// No description provided for @migrationStep1Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'进入“数据备份与迁移”页面后，请点“导出全部数据”，不要点“导出当前课表”，也不要先卸载旧版'**
  String get migrationStep1Subtitle;

  /// No description provided for @migrationStep2Title.
  ///
  /// In zh, this message translates to:
  /// **'保存备份文件'**
  String get migrationStep2Title;

  /// No description provided for @migrationStep2Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'旧版导出后会弹出系统分享面板，优先选择“保存到文件”，建议存到 下载 / Download 文件夹'**
  String get migrationStep2Subtitle;

  /// No description provided for @migrationStep3Title.
  ///
  /// In zh, this message translates to:
  /// **'回到当前版本导入'**
  String get migrationStep3Title;

  /// No description provided for @migrationStep3Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'回到新版后，通过系统文件选择器到 下载 / Download 文件夹选中 .mikcb 备份文件即可恢复，确认新版数据正常后，再卸载旧版应用'**
  String get migrationStep3Subtitle;

  /// No description provided for @migrationNoSaveToFilesTitle.
  ///
  /// In zh, this message translates to:
  /// **'如果没有“保存到文件”'**
  String get migrationNoSaveToFilesTitle;

  /// No description provided for @migrationNoSaveToFilesSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'可以先分享到微信任意一个聊天，然后在微信里点开这个备份文件并保存，保存后通常会出现在 Download / WeiXin 文件夹里，再回到新版选择这个 .mikcb 文件导入'**
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
  /// **'你的支持会直接用于维护课表、教务导入适配与体验优化'**
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
  /// **'暂时无法加载在线鸣谢名单'**
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
  /// **'名单还没有填写，你可以直接编辑 docs/donors.json 后重新发布'**
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

  /// No description provided for @supportRunningBadge.
  ///
  /// In zh, this message translates to:
  /// **'运行中'**
  String get supportRunningBadge;

  /// No description provided for @supportTapQrHint.
  ///
  /// In zh, this message translates to:
  /// **'点击放大扫码'**
  String get supportTapQrHint;

  /// No description provided for @supportSaveShort.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get supportSaveShort;

  /// No description provided for @supportConfirmedShort.
  ///
  /// In zh, this message translates to:
  /// **'已支持'**
  String get supportConfirmedShort;

  /// No description provided for @donorSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜昵称/寄语...'**
  String get donorSearchHint;

  /// No description provided for @donorSortLargeFirst.
  ///
  /// In zh, this message translates to:
  /// **'大额优先'**
  String get donorSortLargeFirst;

  /// No description provided for @donorSortSmallFirst.
  ///
  /// In zh, this message translates to:
  /// **'小额优先'**
  String get donorSortSmallFirst;

  /// No description provided for @supportMonthlyGoalLabel.
  ///
  /// In zh, this message translates to:
  /// **'本月服务器和证书续期进度'**
  String get supportMonthlyGoalLabel;

  /// No description provided for @supportGoalRaised.
  ///
  /// In zh, this message translates to:
  /// **'已筹: {raised} / 目标 {goal}'**
  String supportGoalRaised(String raised, String goal);

  /// No description provided for @supportBackerCount.
  ///
  /// In zh, this message translates to:
  /// **'已有 {count} 人献出爱心'**
  String supportBackerCount(int count);

  /// No description provided for @supportDonorListFooter.
  ///
  /// In zh, this message translates to:
  /// **'名单永久保留 💖'**
  String get supportDonorListFooter;

  /// No description provided for @supportMarqueeThanks.
  ///
  /// In zh, this message translates to:
  /// **'🎉 感谢 {name} 赞助 {amount}'**
  String supportMarqueeThanks(String name, String amount);

  /// No description provided for @supportMarqueeTail.
  ///
  /// In zh, this message translates to:
  /// **'轻屿课表正在稳定运行中，期待你的每一次陪伴与爱心！'**
  String get supportMarqueeTail;

  /// No description provided for @scanQrWechatTitle.
  ///
  /// In zh, this message translates to:
  /// **'使用微信扫描二维码'**
  String get scanQrWechatTitle;

  /// No description provided for @scanQrAlipayTitle.
  ///
  /// In zh, this message translates to:
  /// **'使用支付宝扫描二维码'**
  String get scanQrAlipayTitle;

  /// No description provided for @scanQrSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'截图并导入扫一扫，感谢支持！'**
  String get scanQrSubtitle;

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
  /// **'检测到 {count} 门排课存在实际冲突，课程列表已标记冲突项'**
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
  /// **'这里的星期、节次、教室、周次和单双周只影响当前这一条排课'**
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
  /// **'未手动指定时，按上课地点自动匹配时间模板；未命中则跟随课表主时间模板'**
  String get followCurrentTimetableDescription;

  /// No description provided for @overrideTimeSchemeDescription.
  ///
  /// In zh, this message translates to:
  /// **'这门课会单独使用所选时间模板，不跟随当前课表主时间模板'**
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
  /// **'单节课只会出现在一个周次里，适合补课、临时加课'**
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
  /// **'按开始周到结束周连续排课'**
  String get rangeWeeksAllHint;

  /// No description provided for @rangeWeeksOddHint.
  ///
  /// In zh, this message translates to:
  /// **'只保留范围内的单周'**
  String get rangeWeeksOddHint;

  /// No description provided for @rangeWeeksEvenHint.
  ///
  /// In zh, this message translates to:
  /// **'只保留范围内的双周'**
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

  /// No description provided for @courseColorQuickSection.
  ///
  /// In zh, this message translates to:
  /// **'常用颜色'**
  String get courseColorQuickSection;

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
  /// **'一个围绕课表查看、课程提醒和 HyperOS 超级岛体验打磨的 Android 开源项目'**
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
  /// **'检查更新与立即下载'**
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
  /// **'当前版本已经支持适配学校的教务系统网页登录导入；进入“导入课程 > 教务系统导入”后选择学校和适配器即可'**
  String get aboutImportMigrationBullet1;

  /// No description provided for @aboutImportMigrationBullet2.
  ///
  /// In zh, this message translates to:
  /// **'如果你的学校暂时还没适配，仍然可以先在 WakeUp 等课表应用里导入课程，再导出为日历格式，然后在本应用导入'**
  String get aboutImportMigrationBullet2;

  /// No description provided for @aboutImportMigrationBullet3.
  ///
  /// In zh, this message translates to:
  /// **'如果其他人已经在用本应用，也可以直接让对方导出完整备份文件，你在“数据备份与迁移”里导入即可直接恢复'**
  String get aboutImportMigrationBullet3;

  /// No description provided for @aboutImportMigrationBullet4.
  ///
  /// In zh, this message translates to:
  /// **'如果你会抓包、网页调试或 JavaScript，也欢迎去 qingyu_warehouse 参与教务适配补充'**
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

  /// No description provided for @aboutRepositorySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'GitHub 仓库地址、源码、Release 和反馈入口'**
  String get aboutRepositorySubtitle;

  /// No description provided for @aboutOpenSourceLicensesTitle.
  ///
  /// In zh, this message translates to:
  /// **'开源许可'**
  String get aboutOpenSourceLicensesTitle;

  /// No description provided for @aboutOpenSourceLicensesSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'本应用协议与第三方组件许可证'**
  String get aboutOpenSourceLicensesSubtitle;

  /// No description provided for @aboutOpenSourceLicensesSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索组件名称'**
  String get aboutOpenSourceLicensesSearchHint;

  /// No description provided for @aboutOpenSourceLicensesAppSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'许可说明'**
  String get aboutOpenSourceLicensesAppSectionTitle;

  /// No description provided for @aboutOpenSourceLicensesAppLicenseLabel.
  ///
  /// In zh, this message translates to:
  /// **'轻屿课表源码以 GPL-3.0-or-later 发布。'**
  String get aboutOpenSourceLicensesAppLicenseLabel;

  /// No description provided for @aboutOpenSourceLicensesIntro.
  ///
  /// In zh, this message translates to:
  /// **'下方列表为本应用使用的开源组件及其许可证，点进可查看全文。'**
  String get aboutOpenSourceLicensesIntro;

  /// No description provided for @aboutOpenSourceLicensesExtraSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'许可说明'**
  String get aboutOpenSourceLicensesExtraSectionTitle;

  /// No description provided for @aboutOpenSourceLicensesExtraUmeng.
  ///
  /// In zh, this message translates to:
  /// **'友盟统计等分析服务仅在你同意隐私政策后启用，适用友盟自身的用户协议与隐私政策。'**
  String get aboutOpenSourceLicensesExtraUmeng;

  /// No description provided for @aboutOpenSourceLicensesExtraNote.
  ///
  /// In zh, this message translates to:
  /// **''**
  String get aboutOpenSourceLicensesExtraNote;

  /// No description provided for @aboutOpenSourceLicensesPackagesSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'开源组件（{count}）'**
  String aboutOpenSourceLicensesPackagesSectionTitle(int count);

  /// No description provided for @aboutOpenSourceLicensesPackageSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'{count} 份许可证文本'**
  String aboutOpenSourceLicensesPackageSubtitle(int count);

  /// No description provided for @aboutOpenSourceLicensesLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载许可证失败，请稍后重试'**
  String get aboutOpenSourceLicensesLoadFailed;

  /// No description provided for @aboutOpenSourceLicensesEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的组件'**
  String get aboutOpenSourceLicensesEmpty;

  /// No description provided for @aboutAppLogsTitle.
  ///
  /// In zh, this message translates to:
  /// **'应用日志'**
  String get aboutAppLogsTitle;

  /// No description provided for @aboutAppLogsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'查看运行日志'**
  String get aboutAppLogsSubtitle;

  /// No description provided for @appLogsShareText.
  ///
  /// In zh, this message translates to:
  /// **'这是轻屿课表导出的应用日志，包含整个软件的本地运行记录，可用于排查更新、导入、通知、页面和崩溃问题'**
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

  /// No description provided for @appLogsSourceApp.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get appLogsSourceApp;

  /// No description provided for @appLogsSourceNative.
  ///
  /// In zh, this message translates to:
  /// **'超级岛'**
  String get appLogsSourceNative;

  /// No description provided for @appLogsRecordingPausedHint.
  ///
  /// In zh, this message translates to:
  /// **'记录已关闭，下方为历史日志，关闭后不再新增'**
  String get appLogsRecordingPausedHint;

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
  /// **'确定删除“{name}”吗？正在使用中的模板不能删除'**
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
  /// **'先看总影响范围，再决定是直接编辑这套模板，还是先复制一套再改'**
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
  /// **'当前没有课表直接使用这套模板'**
  String get directlyBoundProfilesEmpty;

  /// No description provided for @directlyBoundProfilesSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'这些课表切到这套模板后，默认都会按这套节次时间显示'**
  String get directlyBoundProfilesSubtitle;

  /// No description provided for @followMainSchemeCoursesTitle.
  ///
  /// In zh, this message translates to:
  /// **'跟随课表主时间表的课程'**
  String get followMainSchemeCoursesTitle;

  /// No description provided for @followMainSchemeCoursesEmpty.
  ///
  /// In zh, this message translates to:
  /// **'当前没有课程通过课表主时间表间接使用它'**
  String get followMainSchemeCoursesEmpty;

  /// No description provided for @followMainSchemeCoursesSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'这些课程没有单独设置副时间表，而是跟着所属课表一起用这套模板'**
  String get followMainSchemeCoursesSubtitle;

  /// No description provided for @overrideSchemeCoursesTitle.
  ///
  /// In zh, this message translates to:
  /// **'把它作为副时间表的课程'**
  String get overrideSchemeCoursesTitle;

  /// No description provided for @overrideSchemeCoursesEmpty.
  ///
  /// In zh, this message translates to:
  /// **'当前没有课程把它作为副时间表'**
  String get overrideSchemeCoursesEmpty;

  /// No description provided for @overrideSchemeCoursesSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'这些课程即使所在课表切换了主模板，也会继续单独使用这套时间'**
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
  /// **'如果当前课表正在使用这套模板，节次数量不能小于已使用的最大节次'**
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
  /// **'当前课表和部分课程正在使用这套时间模板，保存后会同步更新所有相关课表和课程'**
  String get timeSchemeEditorActiveAndCoursesHint;

  /// No description provided for @timeSchemeEditorActiveHint.
  ///
  /// In zh, this message translates to:
  /// **'当前课表正在使用这套时间模板，保存后会同步更新所有使用它的课表'**
  String get timeSchemeEditorActiveHint;

  /// No description provided for @timeSchemeEditorOverrideHint.
  ///
  /// In zh, this message translates to:
  /// **'有课程正在把这套模板作为副时间表使用，保存后会同步更新所有引用课程'**
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
  /// **'未设置大课间规则，将全部使用小课间时长'**
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

  /// No description provided for @liveGroupReminders.
  ///
  /// In zh, this message translates to:
  /// **'提醒'**
  String get liveGroupReminders;

  /// No description provided for @liveGroupDisplay.
  ///
  /// In zh, this message translates to:
  /// **'显示内容'**
  String get liveGroupDisplay;

  /// No description provided for @liveGroupMaintenance.
  ///
  /// In zh, this message translates to:
  /// **'维护与自检'**
  String get liveGroupMaintenance;

  /// No description provided for @liveReminderTimingEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'提醒时段'**
  String get liveReminderTimingEntryTitle;

  /// No description provided for @liveReminderTimingEntrySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'上课前、课中与下课提醒，以及重点提醒切入时机'**
  String get liveReminderTimingEntrySubtitle;

  /// No description provided for @liveBeforeClassDisplayEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'上课前提醒显示'**
  String get liveBeforeClassDisplayEntryTitle;

  /// No description provided for @liveDuringEndDisplayEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'课中与下课提醒显示'**
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
  /// **'可自由组合，互不影响'**
  String get liveReminderSwitchesSubtitle;

  /// No description provided for @beforeClassReminderTitle.
  ///
  /// In zh, this message translates to:
  /// **'上课前提醒'**
  String get beforeClassReminderTitle;

  /// No description provided for @beforeClassReminderSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'课程开始前 {minutes} 分钟弹出'**
  String beforeClassReminderSubtitle(int minutes);

  /// No description provided for @duringClassReminderTitle.
  ///
  /// In zh, this message translates to:
  /// **'课中与下课提醒'**
  String get duringClassReminderTitle;

  /// No description provided for @duringClassReminderSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'上课后到下课前的展示'**
  String get duringClassReminderSubtitle;

  /// No description provided for @liveClassReminderLeadTitle.
  ///
  /// In zh, this message translates to:
  /// **'重点提醒切入时机'**
  String get liveClassReminderLeadTitle;

  /// No description provided for @liveClassReminderLeadOptionImmediate.
  ///
  /// In zh, this message translates to:
  /// **'一上课就切换'**
  String get liveClassReminderLeadOptionImmediate;

  /// No description provided for @liveClassReminderLeadOptionMinutes.
  ///
  /// In zh, this message translates to:
  /// **'下课前 {minutes} 分钟'**
  String liveClassReminderLeadOptionMinutes(int minutes);

  /// No description provided for @liveDisplayModeTitle.
  ///
  /// In zh, this message translates to:
  /// **'展示方式'**
  String get liveDisplayModeTitle;

  /// No description provided for @liveDisplayModeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'对已开启的提醒生效'**
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
  /// **'重点提醒前保留普通通知'**
  String get duringClassStatusNotificationBeforeEnd;

  /// No description provided for @duringClassStatusNotificationPersistent.
  ///
  /// In zh, this message translates to:
  /// **'课中持续显示普通通知'**
  String get duringClassStatusNotificationPersistent;

  /// No description provided for @enableIslandDisplayTitle.
  ///
  /// In zh, this message translates to:
  /// **'展示超级岛'**
  String get enableIslandDisplayTitle;

  /// No description provided for @enableIslandDisplaySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'关闭后不触发系统超级岛'**
  String get enableIslandDisplaySubtitle;

  /// No description provided for @liveTimeThresholdTitle.
  ///
  /// In zh, this message translates to:
  /// **'时间阈值'**
  String get liveTimeThresholdTitle;

  /// No description provided for @liveTimeThresholdSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'控制课前弹出与秒级倒计时'**
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
  /// **'下课前秒级阈值'**
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

  /// No description provided for @timeCorrectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'铃声时间矫正'**
  String get timeCorrectionTitle;

  /// No description provided for @timeCorrectionHelp.
  ///
  /// In zh, this message translates to:
  /// **'铃声比课表快则提前，慢则延后'**
  String get timeCorrectionHelp;

  /// No description provided for @duringEndTimeDisplayLabel.
  ///
  /// In zh, this message translates to:
  /// **'课中时间样式'**
  String get duringEndTimeDisplayLabel;

  /// No description provided for @duringEndTimeDisplayHelp.
  ///
  /// In zh, this message translates to:
  /// **'紧凑提醒显示最近时间或总时长'**
  String get duringEndTimeDisplayHelp;

  /// No description provided for @liveDisplayContentTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示内容'**
  String get liveDisplayContentTitle;

  /// No description provided for @liveDisplayContentSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'这组设置只影响当前阶段，不会改动另一组提醒显示'**
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

  /// No description provided for @liveIslandPreviewTitle.
  ///
  /// In zh, this message translates to:
  /// **'超级岛预览'**
  String get liveIslandPreviewTitle;

  /// No description provided for @liveIslandPreviewFollowBadge.
  ///
  /// In zh, this message translates to:
  /// **'正在跟随“课前提醒显示”设置，调整课前提醒即可生效'**
  String get liveIslandPreviewFollowBadge;

  /// No description provided for @liveIslandPreviewStageBeforeClass.
  ///
  /// In zh, this message translates to:
  /// **'即将上课'**
  String get liveIslandPreviewStageBeforeClass;

  /// No description provided for @liveIslandPreviewStageInClass.
  ///
  /// In zh, this message translates to:
  /// **'上课中'**
  String get liveIslandPreviewStageInClass;

  /// No description provided for @liveIslandPreviewStageBeforeEnd.
  ///
  /// In zh, this message translates to:
  /// **'下课提醒'**
  String get liveIslandPreviewStageBeforeEnd;

  /// No description provided for @liveIslandPreviewUntilClassStart.
  ///
  /// In zh, this message translates to:
  /// **'距上课{time}'**
  String liveIslandPreviewUntilClassStart(String time);

  /// No description provided for @liveIslandPreviewUntilClassEnd.
  ///
  /// In zh, this message translates to:
  /// **'距下课{time}'**
  String liveIslandPreviewUntilClassEnd(String time);

  /// No description provided for @liveIslandPreviewSampleCourse.
  ///
  /// In zh, this message translates to:
  /// **'高等数学'**
  String get liveIslandPreviewSampleCourse;

  /// No description provided for @liveIslandPreviewSampleCourseShort.
  ///
  /// In zh, this message translates to:
  /// **'高数'**
  String get liveIslandPreviewSampleCourseShort;

  /// No description provided for @liveIslandPreviewSampleLocation.
  ///
  /// In zh, this message translates to:
  /// **'三教-401'**
  String get liveIslandPreviewSampleLocation;

  /// No description provided for @beforeClassQuickActionTitle.
  ///
  /// In zh, this message translates to:
  /// **'上课前快捷操作'**
  String get beforeClassQuickActionTitle;

  /// No description provided for @beforeClassQuickActionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'只在上课前提醒的展开通知里显示，静音/免打扰会在下课后自动恢复，重启手机也会恢复；免打扰首次可能会跳到系统授权页'**
  String get beforeClassQuickActionSubtitle;

  /// No description provided for @liveBeforeClassQuickActionAutoTitle.
  ///
  /// In zh, this message translates to:
  /// **'自动执行'**
  String get liveBeforeClassQuickActionAutoTitle;

  /// No description provided for @liveBeforeClassQuickActionAutoSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'上课前自动打开所选模式，下课后自动恢复，重启手机也会恢复；免打扰需要先在系统设置中授权'**
  String get liveBeforeClassQuickActionAutoSubtitle;

  /// No description provided for @liveBeforeClassQuickActionAutoOptionOff.
  ///
  /// In zh, this message translates to:
  /// **'不自动执行'**
  String get liveBeforeClassQuickActionAutoOptionOff;

  /// No description provided for @liveBeforeClassQuickActionAutoOptionMinutes.
  ///
  /// In zh, this message translates to:
  /// **'上课前 {minutes} 分钟'**
  String liveBeforeClassQuickActionAutoOptionMinutes(int minutes);

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
  /// **'左侧文字图、展开态大图标和自定义图片都按当前阶段单独保存'**
  String get liveIslandVisualSubtitle;

  /// No description provided for @liveMiuiLabelImageTitle.
  ///
  /// In zh, this message translates to:
  /// **'小米岛左侧文字图标'**
  String get liveMiuiLabelImageTitle;

  /// No description provided for @liveMiuiLabelImageSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'仅小米手机样式生效，会把课程名或地点生成到左侧图标位'**
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
  /// **'仅在“图标+文字”样式下生效；未选择时继续使用应用图标'**
  String get liveMiuiLabelLogoSubtitle;

  /// No description provided for @liveMiuiLabelLogoCornerRadiusLabel.
  ///
  /// In zh, this message translates to:
  /// **'左侧图标圆角 {value}'**
  String liveMiuiLabelLogoCornerRadiusLabel(String value);

  /// No description provided for @liveMiuiLabelLogoCornerRadiusTitle.
  ///
  /// In zh, this message translates to:
  /// **'左侧图标圆角'**
  String get liveMiuiLabelLogoCornerRadiusTitle;

  /// No description provided for @liveMiuiLabelFontSizeLabel.
  ///
  /// In zh, this message translates to:
  /// **'左侧文字大小 {value}'**
  String liveMiuiLabelFontSizeLabel(String value);

  /// No description provided for @liveMiuiLabelFontSizeTitle.
  ///
  /// In zh, this message translates to:
  /// **'左侧文字大小'**
  String get liveMiuiLabelFontSizeTitle;

  /// No description provided for @liveMiuiLabelOffsetXLabel.
  ///
  /// In zh, this message translates to:
  /// **'左侧文字水平偏移 {value}'**
  String liveMiuiLabelOffsetXLabel(String value);

  /// No description provided for @liveMiuiLabelOffsetXTitle.
  ///
  /// In zh, this message translates to:
  /// **'左侧文字水平偏移'**
  String get liveMiuiLabelOffsetXTitle;

  /// No description provided for @liveMiuiLabelOffsetYLabel.
  ///
  /// In zh, this message translates to:
  /// **'左侧文字垂直偏移 {value}'**
  String liveMiuiLabelOffsetYLabel(String value);

  /// No description provided for @liveMiuiLabelOffsetYTitle.
  ///
  /// In zh, this message translates to:
  /// **'左侧文字垂直偏移'**
  String get liveMiuiLabelOffsetYTitle;

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
  /// **'打开后，课中和下课提醒会完全跟随上课前提醒显示，下面的独立设置暂时不可编辑'**
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
  /// **'用于提升超级岛和提醒在后台场景下的稳定性'**
  String get liveKeepAliveOptionsSubtitle;

  /// No description provided for @hideFromRecentsTitle.
  ///
  /// In zh, this message translates to:
  /// **'从最近任务中隐藏应用'**
  String get hideFromRecentsTitle;

  /// No description provided for @hideFromRecentsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'开启后应用会尽量不显示在最近任务列表中'**
  String get hideFromRecentsSubtitle;

  /// No description provided for @keepAliveServiceTitle.
  ///
  /// In zh, this message translates to:
  /// **'轻屿课表后台保活服务'**
  String get keepAliveServiceTitle;

  /// No description provided for @keepAliveServiceEnabledSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'当前已开启，系统会保持后台保活辅助服务处于可用状态'**
  String get keepAliveServiceEnabledSubtitle;

  /// No description provided for @keepAliveServiceDisabledSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'当前未开启，可进入系统无障碍设置手动打开轻屿课表后台保活服务'**
  String get keepAliveServiceDisabledSubtitle;

  /// No description provided for @goEnableAction.
  ///
  /// In zh, this message translates to:
  /// **'去开启'**
  String get goEnableAction;

  /// No description provided for @keepAliveConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'开启后台保活服务'**
  String get keepAliveConfirmTitle;

  /// No description provided for @keepAliveConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'该服务仅用于在后台刷新桌面小组件与重排课程提醒，不会读取屏幕内容，也不会代替你执行任何点击操作。开启需要在系统设置中授予「无障碍」权限，可随时关闭。'**
  String get keepAliveConfirmBody;

  /// No description provided for @keepAliveConfirmGoAction.
  ///
  /// In zh, this message translates to:
  /// **'去开启'**
  String get keepAliveConfirmGoAction;

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
  /// **'不同学校可按实际教学周数调整'**
  String get pickSemesterWeekCountSubtitle;

  /// No description provided for @weekCountItem.
  ///
  /// In zh, this message translates to:
  /// **'{count} 周'**
  String weekCountItem(int count);

  /// No description provided for @diagnosticsLogIntro.
  ///
  /// In zh, this message translates to:
  /// **'支持 Markdown 与原文两种查看方式，排查时可以直接在手机上看完整日志'**
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
  /// **'可以切换到“全部”，或改看原文继续排查'**
  String get diagnosticsNoMatchingSubtitle;

  /// 日志查看器分页加载：在列表边缘加载更早日志的入口行文案，count 为尚未显示的更早日志条数
  ///
  /// In zh, this message translates to:
  /// **'加载更早日志（还有 {count} 条）'**
  String diagnosticsLoadEarlierLabel(int count);

  /// No description provided for @diagnosticsLevelInferred.
  ///
  /// In zh, this message translates to:
  /// **'推断等级'**
  String get diagnosticsLevelInferred;

  /// No description provided for @diagnosticsRawFilteredHint.
  ///
  /// In zh, this message translates to:
  /// **'原文视图会跟随当前等级筛选，只显示对应日志块'**
  String get diagnosticsRawFilteredHint;

  /// No description provided for @diagnosticsTimeSortAscending.
  ///
  /// In zh, this message translates to:
  /// **'正序'**
  String get diagnosticsTimeSortAscending;

  /// No description provided for @diagnosticsTimeSortDescending.
  ///
  /// In zh, this message translates to:
  /// **'倒序'**
  String get diagnosticsTimeSortDescending;

  /// No description provided for @diagnosticsDisplayOptionsTitle.
  ///
  /// In zh, this message translates to:
  /// **'查看与排序'**
  String get diagnosticsDisplayOptionsTitle;

  /// No description provided for @diagnosticsStreamingHint.
  ///
  /// In zh, this message translates to:
  /// **'实时更新中，新日志会自动追加显示'**
  String get diagnosticsStreamingHint;

  /// No description provided for @diagnosticsEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无日志'**
  String get diagnosticsEmptyTitle;

  /// No description provided for @diagnosticsEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'当前没有可显示的应用日志'**
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
  /// **'首屏先授权，下面还会明确说明系统版本支持、简称设置和导入方式，记得继续下滑'**
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
  /// **'你已经滑到最后了，确认无误后就可以开始使用'**
  String get guideBottomReachedHint;

  /// No description provided for @guideScrollHint.
  ///
  /// In zh, this message translates to:
  /// **'向下滑动继续，下面还有 HyperOS 版本说明、权限清单、简称设置和导入方式'**
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
  /// **'先把最关键的 5 个入口放在前面，不用翻到下面再找'**
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
  /// **'请先滑到底部阅读说明，并勾选同意后开始使用'**
  String get guideRequireConsentHint;

  /// No description provided for @guideContinueHint.
  ///
  /// In zh, this message translates to:
  /// **'继续下滑查看完整引导内容'**
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
  /// **'适合补课、临时加课，课程只会落在一个周次'**
  String get singleLessonHint;

  /// No description provided for @recurringLessonHint.
  ///
  /// In zh, this message translates to:
  /// **'适合同一时间连续上很多周的常规课程'**
  String get recurringLessonHint;

  /// No description provided for @sharedInfoTitle.
  ///
  /// In zh, this message translates to:
  /// **'共享信息'**
  String get sharedInfoTitle;

  /// No description provided for @sharedInfoHint.
  ///
  /// In zh, this message translates to:
  /// **'查看共享字段说明'**
  String get sharedInfoHint;

  /// No description provided for @sharedInfoSheetItemCourseName.
  ///
  /// In zh, this message translates to:
  /// **'课程名称：课程唯一标识，名称相同的多条排课视为同一课程；更改名称将形成独立课程记录'**
  String get sharedInfoSheetItemCourseName;

  /// No description provided for @sharedInfoSheetItemShortName.
  ///
  /// In zh, this message translates to:
  /// **'课程简称：用于超级岛等场景的简短展示，需手动填写，系统不会自动生成，启用「优先显示课程简称」后生效；建议控制在 3 个汉字以内'**
  String get sharedInfoSheetItemShortName;

  /// No description provided for @sharedInfoSheetItemSharedSync.
  ///
  /// In zh, this message translates to:
  /// **'共享同步：课程简称、颜色、性质、简介等字段将同步至同名课程的其他排课记录'**
  String get sharedInfoSheetItemSharedSync;

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
  /// **'当前课表里还没有现成课程，先手动录入一门，后面临时加课就能直接选了'**
  String get noTemplateCoursesHint;

  /// No description provided for @courseNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'课程名称'**
  String get courseNameLabel;

  /// No description provided for @courseNameHelper.
  ///
  /// In zh, this message translates to:
  /// **'作为课程唯一标识；名称相同的多条排课将归为同一课程，请填写完整名称，请勿为界面显示而缩写'**
  String get courseNameHelper;

  /// No description provided for @pleaseEnterCourseName.
  ///
  /// In zh, this message translates to:
  /// **'请输入课程名称'**
  String get pleaseEnterCourseName;

  /// No description provided for @courseShortNameOptional.
  ///
  /// In zh, this message translates to:
  /// **'课程简称'**
  String get courseShortNameOptional;

  /// No description provided for @courseShortNameHelper.
  ///
  /// In zh, this message translates to:
  /// **'建议填写，用于超级岛等场景的简短展示，简称不会自动生成；启用「优先显示课程简称」后生效，建议控制在 3 个汉字以内'**
  String get courseShortNameHelper;

  /// No description provided for @courseShortNameAutoFillAction.
  ///
  /// In zh, this message translates to:
  /// **'取前两字'**
  String get courseShortNameAutoFillAction;

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
  /// **'这里的星期、节次、教室、周次和单双周只影响当前这一条排课'**
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
  /// **'单节课只会出现在一个周次里，适合补课、临时加课'**
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
  /// **'按开始周到结束周连续排课'**
  String get allWeeksHint;

  /// No description provided for @oddWeeksHint.
  ///
  /// In zh, this message translates to:
  /// **'只保留范围内的单周'**
  String get oddWeeksHint;

  /// No description provided for @evenWeeksHint.
  ///
  /// In zh, this message translates to:
  /// **'只保留范围内的双周'**
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
  /// **'一上课进入重点提醒，下课前 {seconds} 秒秒级倒数'**
  String liveClassReminderLeadSummaryImmediate(int seconds);

  /// No description provided for @liveClassReminderLeadSummaryKeepNormal.
  ///
  /// In zh, this message translates to:
  /// **'课中普通通知，下课前 {minutes} 分钟重点提醒'**
  String liveClassReminderLeadSummaryKeepNormal(int minutes, int seconds);

  /// No description provided for @liveClassReminderLeadSummaryIsland.
  ///
  /// In zh, this message translates to:
  /// **'下课前 {minutes} 分钟切到超级岛与重点提醒'**
  String liveClassReminderLeadSummaryIsland(int minutes, int seconds);

  /// No description provided for @liveClassReminderLeadSummaryFocused.
  ///
  /// In zh, this message translates to:
  /// **'下课前 {minutes} 分钟开始重点提醒'**
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
  /// **'控制首页左上角课表切换入口的样式'**
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
  /// **'影响顶部栏、强调色和全局主色调'**
  String get themeSeedSectionSubtitle;

  /// No description provided for @frostedSheetSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'磨砂玻璃'**
  String get frostedSheetSectionTitle;

  /// No description provided for @frostedSheetSectionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'调节首页弹出面板的高斯模糊强度与磨砂亮度，滑块越靠右，白色磨砂层越明显'**
  String get frostedSheetSectionSubtitle;

  /// No description provided for @frostedBlurEnabledTitle.
  ///
  /// In zh, this message translates to:
  /// **'启用模糊'**
  String get frostedBlurEnabledTitle;

  /// No description provided for @frostedBlurEnabledSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'关闭后，弹窗、首页模糊区域与「回本周」按钮仅保留半透明底色，不再采样模糊'**
  String get frostedBlurEnabledSubtitle;

  /// No description provided for @frostedSheetPreviewOpenAction.
  ///
  /// In zh, this message translates to:
  /// **'打开预览面板'**
  String get frostedSheetPreviewOpenAction;

  /// No description provided for @frostedSheetPreviewDemoTitle.
  ///
  /// In zh, this message translates to:
  /// **'预览'**
  String get frostedSheetPreviewDemoTitle;

  /// No description provided for @frostedSheetPreviewDemoSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'磨砂玻璃效果实时预览'**
  String get frostedSheetPreviewDemoSubtitle;

  /// No description provided for @frostedSheetBlurLabel.
  ///
  /// In zh, this message translates to:
  /// **'模糊强度'**
  String get frostedSheetBlurLabel;

  /// No description provided for @frostedSheetTintLabel.
  ///
  /// In zh, this message translates to:
  /// **'磨砂亮度'**
  String get frostedSheetTintLabel;

  /// No description provided for @timetableBackgroundColorSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'课表背景色'**
  String get timetableBackgroundColorSectionTitle;

  /// No description provided for @timetableBackgroundColorSectionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'纯色模式下作用于已选显示区域；可与背景图搭配使用'**
  String get timetableBackgroundColorSectionSubtitle;

  /// No description provided for @homePageBackgroundFillLabel.
  ///
  /// In zh, this message translates to:
  /// **'背景填充'**
  String get homePageBackgroundFillLabel;

  /// No description provided for @homePageBackgroundFillColor.
  ///
  /// In zh, this message translates to:
  /// **'纯色'**
  String get homePageBackgroundFillColor;

  /// No description provided for @homePageBackgroundFillImage.
  ///
  /// In zh, this message translates to:
  /// **'图片'**
  String get homePageBackgroundFillImage;

  /// No description provided for @homePageBackgroundImageTitle.
  ///
  /// In zh, this message translates to:
  /// **'背景图'**
  String get homePageBackgroundImageTitle;

  /// No description provided for @homePageBackgroundImageSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'在「图片」模式下，作用于下方勾选的显示区域'**
  String get homePageBackgroundImageSubtitle;

  /// No description provided for @homePageWallpaperTitle.
  ///
  /// In zh, this message translates to:
  /// **'背景图片'**
  String get homePageWallpaperTitle;

  /// No description provided for @homePageWallpaperSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'全屏铺底一张图；勾选下方区域决定透出范围，未勾选区域仍显示课表背景色'**
  String get homePageWallpaperSubtitle;

  /// No description provided for @homePageBackdropFollowsWeekPagerTitle.
  ///
  /// In zh, this message translates to:
  /// **'背景随周次滑动'**
  String get homePageBackdropFollowsWeekPagerTitle;

  /// No description provided for @homePageBackdropFollowsWeekPagerSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'左右切换周次时，背景图与课表页面一起移动'**
  String get homePageBackdropFollowsWeekPagerSubtitle;

  /// No description provided for @homePageBackgroundScopeTitle.
  ///
  /// In zh, this message translates to:
  /// **'背景显示区域'**
  String get homePageBackgroundScopeTitle;

  /// No description provided for @homePageBackgroundScopeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'从上到下依次控制各区域是否透出背景图；未勾选区域仍显示课表背景色'**
  String get homePageBackgroundScopeSubtitle;

  /// No description provided for @homePageBackgroundScopeStatusBar.
  ///
  /// In zh, this message translates to:
  /// **'状态栏'**
  String get homePageBackgroundScopeStatusBar;

  /// No description provided for @homePageBackgroundScopeTimetable.
  ///
  /// In zh, this message translates to:
  /// **'课表区域'**
  String get homePageBackgroundScopeTimetable;

  /// No description provided for @homePageBackgroundScopeWeekdayBar.
  ///
  /// In zh, this message translates to:
  /// **'信息栏'**
  String get homePageBackgroundScopeWeekdayBar;

  /// No description provided for @homePageBackgroundScopeHeader.
  ///
  /// In zh, this message translates to:
  /// **'顶栏'**
  String get homePageBackgroundScopeHeader;

  /// No description provided for @homePageHeaderBlurTitle.
  ///
  /// In zh, this message translates to:
  /// **'顶栏高斯模糊'**
  String get homePageHeaderBlurTitle;

  /// No description provided for @homePageHeaderBlurSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'模糊标题栏（轻屿课表）区域；勾选「状态栏」时一并模糊状态栏'**
  String get homePageHeaderBlurSubtitle;

  /// No description provided for @homePageWeekdayBarBlurTitle.
  ///
  /// In zh, this message translates to:
  /// **'信息栏高斯模糊'**
  String get homePageWeekdayBarBlurTitle;

  /// No description provided for @homePageWeekdayBarBlurSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'模糊周次与星期信息栏，透出下方背景图'**
  String get homePageWeekdayBarBlurSubtitle;

  /// No description provided for @homePageTimeColumnBlurTitle.
  ///
  /// In zh, this message translates to:
  /// **'时间栏高斯模糊'**
  String get homePageTimeColumnBlurTitle;

  /// No description provided for @homePageTimeColumnBlurSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'模糊左侧节次/时间列，透出下方背景图'**
  String get homePageTimeColumnBlurSubtitle;

  /// No description provided for @homePageRegionBlurSectionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'需配合背景图使用；模糊强度跟随「弹窗磨砂玻璃」设置'**
  String get homePageRegionBlurSectionSubtitle;

  /// No description provided for @homePagePickImageAction.
  ///
  /// In zh, this message translates to:
  /// **'选择图片'**
  String get homePagePickImageAction;

  /// No description provided for @homePageSwitchImageAction.
  ///
  /// In zh, this message translates to:
  /// **'切换照片'**
  String get homePageSwitchImageAction;

  /// No description provided for @homePageClearImageAction.
  ///
  /// In zh, this message translates to:
  /// **'清除图片'**
  String get homePageClearImageAction;

  /// No description provided for @homePageImageNotSelected.
  ///
  /// In zh, this message translates to:
  /// **'未选择'**
  String get homePageImageNotSelected;

  /// No description provided for @wallpaperPositionPickerTitle.
  ///
  /// In zh, this message translates to:
  /// **'调整壁纸显示位置'**
  String get wallpaperPositionPickerTitle;

  /// No description provided for @wallpaperPositionPickerResetTooltip.
  ///
  /// In zh, this message translates to:
  /// **'重置居中'**
  String get wallpaperPositionPickerResetTooltip;

  /// No description provided for @wallpaperPositionPickerDragHint.
  ///
  /// In zh, this message translates to:
  /// **'拖动壁纸调整位置'**
  String get wallpaperPositionPickerDragHint;

  /// No description provided for @wallpaperPositionPickerSwitchWallpaper.
  ///
  /// In zh, this message translates to:
  /// **'换壁纸'**
  String get wallpaperPositionPickerSwitchWallpaper;

  /// No description provided for @wallpaperPositionPickerDone.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get wallpaperPositionPickerDone;

  /// No description provided for @wallpaperPositionPickerExit.
  ///
  /// In zh, this message translates to:
  /// **'退出'**
  String get wallpaperPositionPickerExit;

  /// No description provided for @appearanceTextColorsSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'文字颜色'**
  String get appearanceTextColorsSectionTitle;

  /// No description provided for @appearanceTextColorsSectionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'自定义课程卡片、星期栏与时间轴文字颜色'**
  String get appearanceTextColorsSectionSubtitle;

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
  /// **'图标'**
  String get liveDisplaySummaryLeftLabelImage;

  /// No description provided for @liveDisplaySummaryMinimal.
  ///
  /// In zh, this message translates to:
  /// **'最简显示'**
  String get liveDisplaySummaryMinimal;

  /// No description provided for @liveDisplaySummaryCountdownShort.
  ///
  /// In zh, this message translates to:
  /// **'倒计时'**
  String get liveDisplaySummaryCountdownShort;

  /// No description provided for @liveDisplaySummaryMore.
  ///
  /// In zh, this message translates to:
  /// **'{first}等{count}项'**
  String liveDisplaySummaryMore(String first, int count);

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
  /// **'如果你主要想用超级岛，先确认系统版本至少是 HyperOS 3.0.300，再继续把下面权限清单按顺序点完'**
  String get guideStatusIslandHint;

  /// No description provided for @guidePermissionChecklistTitle.
  ///
  /// In zh, this message translates to:
  /// **'权限清单'**
  String get guidePermissionChecklistTitle;

  /// No description provided for @guidePermissionChecklistSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'按这个顺序检查，最省事，也最不容易漏'**
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
  /// **'超级岛支持显示课程简称，简称不是自动生成的，需要你在课程编辑里自己填写，建议控制在 3 个字以内，显示会更稳定'**
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
  /// **'当前版本已经支持部分学校的教务系统网页登录导入；如果你的学校还没适配，也还有其他迁移方式'**
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
  /// **'2. 先在设置页调整“上课前弹出”和“课中与临近下课提醒”的阈值。'**
  String get guideFinalTip2;

  /// No description provided for @guideFinalTip3.
  ///
  /// In zh, this message translates to:
  /// **'3. 完成系统权限设置后，再用测试通知验证；如果岛区还是偶尔消失，优先检查自启动和省电策略。'**
  String get guideFinalTip3;

  /// No description provided for @guidePrivacyHelperRequireConsent.
  ///
  /// In zh, this message translates to:
  /// **'你勾选同意后，代表你已阅读并同意上述友盟相关说明、隐私内容与免责提示'**
  String get guidePrivacyHelperRequireConsent;

  /// No description provided for @guidePrivacyHelperViewOnly.
  ///
  /// In zh, this message translates to:
  /// **'这里保留与首次启动一致的隐私、第三方 SDK 与免责说明，方便你随时查看；当前页面不需要再次勾选同意'**
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
  /// **'当前还没有可查看的应用日志'**
  String get liveDiagnosticsUnavailable;

  /// No description provided for @liveDiagnosticsViewerTitle.
  ///
  /// In zh, this message translates to:
  /// **'超级岛日志'**
  String get liveDiagnosticsViewerTitle;

  /// No description provided for @liveDiagnosticsShareText.
  ///
  /// In zh, this message translates to:
  /// **'这是轻屿课表导出的超级岛相关日志，可用于排查“超级岛没有弹出”等问题'**
  String get liveDiagnosticsShareText;

  /// No description provided for @liveDiagnosticsShareSubject.
  ///
  /// In zh, this message translates to:
  /// **'轻屿课表 - 超级岛日志'**
  String get liveDiagnosticsShareSubject;

  /// No description provided for @liveDiagnosticsSnapshotShareText.
  ///
  /// In zh, this message translates to:
  /// **'这是轻屿课表当前测试诊断页导出的超级岛状态快照，可用于排查“超级岛没有弹出”等问题'**
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
  /// **'已清空应用日志'**
  String get liveDiagnosticsCleared;

  /// No description provided for @liveDiagnosticsClearFailed.
  ///
  /// In zh, this message translates to:
  /// **'清空应用日志失败'**
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
  /// **'用于验证超级岛、通知栏和课程简称等显示效果'**
  String get liveTestingNotificationSubtitle;

  /// No description provided for @liveTestingStartAction.
  ///
  /// In zh, this message translates to:
  /// **'开始测试'**
  String get liveTestingStartAction;

  /// No description provided for @liveTestingCancelAction.
  ///
  /// In zh, this message translates to:
  /// **'取消测试'**
  String get liveTestingCancelAction;

  /// No description provided for @liveTestingSessionRunning.
  ///
  /// In zh, this message translates to:
  /// **'自检测试进行中'**
  String get liveTestingSessionRunning;

  /// No description provided for @liveTestingSessionCanceled.
  ///
  /// In zh, this message translates to:
  /// **'已取消自检测试'**
  String get liveTestingSessionCanceled;

  /// No description provided for @liveTestingUmengHint.
  ///
  /// In zh, this message translates to:
  /// **'下面两个按钮仅测试版显示，用于验证友盟 U-APM 崩溃和卡顿上报'**
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
  /// **'这里直接显示原生实时服务、通知构造结果和不上岛原因'**
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
  /// **'默认折叠，排查时再展开核对完整原生字段'**
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
  /// **'一键导出日志文件，直接通过系统分享发给开发者；也可以清空后重新收集'**
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
  /// **'显示当前原生诊断字段'**
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

  /// No description provided for @liveTestingPresetArmedButHidden.
  ///
  /// In zh, this message translates to:
  /// **'已注入自检预设课程，但超级岛此刻不会弹出——若「上课前提醒」已关闭，岛会在课程真正开始后（约 1 分钟后）才出现'**
  String get liveTestingPresetArmedButHidden;

  /// No description provided for @liveTestingHolidayBlocked.
  ///
  /// In zh, this message translates to:
  /// **'当前在假期范围内，超级岛在假期期间不显示；如需测试，请先在「课表设置 → 节假日标记」中移除覆盖今天的假期'**
  String get liveTestingHolidayBlocked;

  /// No description provided for @liveTestingNotIslandHoliday.
  ///
  /// In zh, this message translates to:
  /// **'当前在假期范围内——超级岛在假期期间不显示，可在「课表设置 → 节假日标记」中管理假期'**
  String get liveTestingNotIslandHoliday;

  /// No description provided for @liveTestingCourseTestAction.
  ///
  /// In zh, this message translates to:
  /// **'选课测试'**
  String get liveTestingCourseTestAction;

  /// No description provided for @liveTestingCourseTestPickerTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择要测试的课程'**
  String get liveTestingCourseTestPickerTitle;

  /// No description provided for @liveTestingCourseTestStageTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择要预览的阶段'**
  String get liveTestingCourseTestStageTitle;

  /// No description provided for @liveTestingCourseTestStageBeforeClass.
  ///
  /// In zh, this message translates to:
  /// **'课前倒计时（岛保持约 3 分钟）'**
  String get liveTestingCourseTestStageBeforeClass;

  /// No description provided for @liveTestingCourseTestStageDuringClass.
  ///
  /// In zh, this message translates to:
  /// **'上课中（岛保持约 4 分钟）'**
  String get liveTestingCourseTestStageDuringClass;

  /// No description provided for @liveTestingCourseTestActiveChip.
  ///
  /// In zh, this message translates to:
  /// **'选课测试中 · {course}'**
  String liveTestingCourseTestActiveChip(String course);

  /// No description provided for @liveTestingCourseTestStopAction.
  ///
  /// In zh, this message translates to:
  /// **'停止测试'**
  String get liveTestingCourseTestStopAction;

  /// No description provided for @liveTestingCourseTestStartedToast.
  ///
  /// In zh, this message translates to:
  /// **'已强制启动「{course}」的超级岛测试（{stage}）。请按 Home 键回桌面查看；岛会在测试窗口结束后自动收岛并恢复正式调度'**
  String liveTestingCourseTestStartedToast(String course, String stage);

  /// No description provided for @liveTestingCourseTestStoppedToast.
  ///
  /// In zh, this message translates to:
  /// **'已停止选课测试，正式调度已恢复'**
  String get liveTestingCourseTestStoppedToast;

  /// No description provided for @liveTestingInFlight.
  ///
  /// In zh, this message translates to:
  /// **'测试进行中，请勿重复点击，请稍后再试'**
  String get liveTestingInFlight;

  /// No description provided for @liveTestingProductionHomeHint.
  ///
  /// In zh, this message translates to:
  /// **'已走正式超级岛选课路径。请按 Home 键回到桌面查看（停留在应用内时系统通常不会弹出）'**
  String get liveTestingProductionHomeHint;

  /// No description provided for @liveTestingPresetFallbackNote.
  ///
  /// In zh, this message translates to:
  /// **'（未检测到可测试的真实课程，已改用自检预设课程，不会写入课表）'**
  String get liveTestingPresetFallbackNote;

  /// No description provided for @liveTestingTestCourseNote.
  ///
  /// In zh, this message translates to:
  /// **'此处显示备注，可以在课程编辑页进行设置'**
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
  /// **'首批支持 2×2、2×4、4×4 三种尺寸，点击小组件会直接打开首页，课程开始和结束时会主动刷新'**
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
  /// **'支持的话会直接弹出系统添加确认，不是单独的权限弹窗；确认后即可固定到桌面'**
  String get homeWidgetPinSupported;

  /// No description provided for @homeWidgetPinUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'当前桌面不支持应用内直接添加时，仍可长按桌面 → 小组件 → 轻屿课表 手动添加'**
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
  /// **'关闭后改显周次与课程数'**
  String get homeWidgetShowLocationSubtitle;

  /// No description provided for @homeWidgetShowCountdownTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示倒计时'**
  String get homeWidgetShowCountdownTitle;

  /// No description provided for @homeWidgetShowCountdownSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'显示下节课倒计时'**
  String get homeWidgetShowCountdownSubtitle;

  /// No description provided for @homeWidgetCountdownLeadTitle.
  ///
  /// In zh, this message translates to:
  /// **'倒计时提前量'**
  String get homeWidgetCountdownLeadTitle;

  /// No description provided for @homeWidgetCountdownLeadSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'设置上课前多少分钟自动切换到倒计时模式'**
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
  /// **'只显示未结束的课程'**
  String get homeWidgetHideCompletedSubtitle;

  /// No description provided for @homeWidgetShowTomorrowTitle.
  ///
  /// In zh, this message translates to:
  /// **'课后显示明日课程'**
  String get homeWidgetShowTomorrowTitle;

  /// No description provided for @homeWidgetShowTomorrowSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'今日课后自动显示明天课程'**
  String get homeWidgetShowTomorrowSubtitle;

  /// No description provided for @homeWidgetAppearanceTitle.
  ///
  /// In zh, this message translates to:
  /// **'卡片外观'**
  String get homeWidgetAppearanceTitle;

  /// No description provided for @homeWidgetHeightAdjustTitle.
  ///
  /// In zh, this message translates to:
  /// **'卡片高度'**
  String get homeWidgetHeightAdjustTitle;

  /// No description provided for @homeWidgetHeightAdjustHint.
  ///
  /// In zh, this message translates to:
  /// **'范围 -16 ~ 16，0 为默认档：正数比默认更高，负数更矮'**
  String get homeWidgetHeightAdjustHint;

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
  /// **'小组件目前优先展示今日课程，无课状态会保持完整卡片，不会出现空白；如果你切换课表或修改样式，桌面组件也会跟着刷新'**
  String get homeWidgetDescriptionText;

  /// No description provided for @homeWidgetPinRequested.
  ///
  /// In zh, this message translates to:
  /// **'已发起“{label}”添加请求，请在系统弹窗里确认并放到桌面'**
  String homeWidgetPinRequested(String label);

  /// No description provided for @homeWidgetPinUnsupportedManual.
  ///
  /// In zh, this message translates to:
  /// **'当前系统桌面不支持应用内直接添加小组件，请长按桌面 → 小组件 → 轻屿课表，再手动添加“{label}”'**
  String homeWidgetPinUnsupportedManual(String label);

  /// No description provided for @homeWidgetInvalidType.
  ///
  /// In zh, this message translates to:
  /// **'小组件类型无效，请稍后重试'**
  String get homeWidgetInvalidType;

  /// No description provided for @homeWidgetPinFailedManual.
  ///
  /// In zh, this message translates to:
  /// **'发起添加失败，请长按桌面 → 小组件 → 轻屿课表，再手动添加“{label}”'**
  String homeWidgetPinFailedManual(String label);

  /// No description provided for @homeWidgetBindingSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'各卡片绑定管理'**
  String get homeWidgetBindingSectionTitle;

  /// No description provided for @homeWidgetBindingFollowActive.
  ///
  /// In zh, this message translates to:
  /// **'跟随当前课表'**
  String get homeWidgetBindingFollowActive;

  /// No description provided for @homeWidgetBindingEmpty.
  ///
  /// In zh, this message translates to:
  /// **'桌面上还没有今日课程卡片，先添加一张再回来绑定'**
  String get homeWidgetBindingEmpty;

  /// No description provided for @homeWidgetBindingSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存卡片绑定失败，请稍后重试'**
  String get homeWidgetBindingSaveFailed;

  /// No description provided for @homeWidgetBindingMissingToast.
  ///
  /// In zh, this message translates to:
  /// **'这张卡片绑定的课表已失效，已按普通方式打开'**
  String get homeWidgetBindingMissingToast;

  /// No description provided for @homeWidgetExactAlarmBannerTitle.
  ///
  /// In zh, this message translates to:
  /// **'精确闹钟权限未授予'**
  String get homeWidgetExactAlarmBannerTitle;

  /// No description provided for @homeWidgetExactAlarmBannerText.
  ///
  /// In zh, this message translates to:
  /// **'未授予「闹钟和提醒」权限时，课程边界只能非精确刷新，桌面卡片可能延迟更新，建议授权以保证按课程时间精确刷新'**
  String get homeWidgetExactAlarmBannerText;

  /// No description provided for @homeWidgetExactAlarmGrantAction.
  ///
  /// In zh, this message translates to:
  /// **'去授权'**
  String get homeWidgetExactAlarmGrantAction;

  /// No description provided for @homeWidgetExactAlarmOpenFailed.
  ///
  /// In zh, this message translates to:
  /// **'打开授权页失败，请到系统设置中手动开启「闹钟和提醒」权限'**
  String get homeWidgetExactAlarmOpenFailed;

  /// No description provided for @homeWidgetExactAlarmFallbackHint.
  ///
  /// In zh, this message translates to:
  /// **'已在系统设置中打开应用信息，请在其中开启「闹钟和提醒」权限'**
  String get homeWidgetExactAlarmFallbackHint;

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
  /// **'开启后会按当前节数自动铺满页面底部，不再保留下方空隙'**
  String get layoutAutoFitHeightSubtitle;

  /// No description provided for @layoutHideWeekendsTitle.
  ///
  /// In zh, this message translates to:
  /// **'隐藏周六周日'**
  String get layoutHideWeekendsTitle;

  /// No description provided for @layoutHideWeekendsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'开启后首页只显示周一到周五，剩余列宽会自动铺满'**
  String get layoutHideWeekendsSubtitle;

  /// No description provided for @layoutEnableHapticsTitle.
  ///
  /// In zh, this message translates to:
  /// **'启用应用内震动反馈'**
  String get layoutEnableHapticsTitle;

  /// No description provided for @layoutEnableHapticsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'关闭后，页码切换等交互不再触发轻微震动'**
  String get layoutEnableHapticsSubtitle;

  /// No description provided for @pageTransitionSpeedLabel.
  ///
  /// In zh, this message translates to:
  /// **'页面转场速度 {speed}×'**
  String pageTransitionSpeedLabel(String speed);

  /// No description provided for @pageTransitionSpeedTitle.
  ///
  /// In zh, this message translates to:
  /// **'页面转场速度'**
  String get pageTransitionSpeedTitle;

  /// No description provided for @pageTransitionSpeedSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'调节进入和返回子页面时的滑动动画快慢，数值越大越快，越小越慢；会叠加系统「过渡动画缩放」设置'**
  String get pageTransitionSpeedSubtitle;

  /// No description provided for @pageTransitionSpeedDurationHint.
  ///
  /// In zh, this message translates to:
  /// **'约 {milliseconds} 毫秒'**
  String pageTransitionSpeedDurationHint(int milliseconds);

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
  /// **'默认保持现在的内嵌样式；也可以改成周视图右下角的小型悬浮按钮'**
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

  /// No description provided for @layoutBackToCurrentWeekButtonOpacityTitle.
  ///
  /// In zh, this message translates to:
  /// **'悬浮按钮不透明度'**
  String get layoutBackToCurrentWeekButtonOpacityTitle;

  /// No description provided for @layoutBackToCurrentWeekButtonOpacitySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'只对右下角悬浮样式生效'**
  String get layoutBackToCurrentWeekButtonOpacitySubtitle;

  /// No description provided for @layoutCourseCardGapLabel.
  ///
  /// In zh, this message translates to:
  /// **'课程卡片间距 {value}'**
  String layoutCourseCardGapLabel(String value);

  /// No description provided for @layoutCourseCardGapTitle.
  ///
  /// In zh, this message translates to:
  /// **'课程卡片间距'**
  String get layoutCourseCardGapTitle;

  /// No description provided for @layoutSectionHeightLabel.
  ///
  /// In zh, this message translates to:
  /// **'课表行高 {value}'**
  String layoutSectionHeightLabel(String value);

  /// No description provided for @layoutSectionHeightTitle.
  ///
  /// In zh, this message translates to:
  /// **'课表行高'**
  String get layoutSectionHeightTitle;

  /// No description provided for @layoutCompactFontSizeLabel.
  ///
  /// In zh, this message translates to:
  /// **'紧凑字号 {value}'**
  String layoutCompactFontSizeLabel(String value);

  /// No description provided for @layoutCompactFontSizeTitle.
  ///
  /// In zh, this message translates to:
  /// **'紧凑字号'**
  String get layoutCompactFontSizeTitle;

  /// No description provided for @layoutCourseCardFontSizeLabel.
  ///
  /// In zh, this message translates to:
  /// **'课程卡片字号 {value}'**
  String layoutCourseCardFontSizeLabel(String value);

  /// No description provided for @layoutCourseCardFontSizeTitle.
  ///
  /// In zh, this message translates to:
  /// **'课程卡片字号'**
  String get layoutCourseCardFontSizeTitle;

  /// No description provided for @layoutCourseCardDisplayTitle.
  ///
  /// In zh, this message translates to:
  /// **'课程卡片显示'**
  String get layoutCourseCardDisplayTitle;

  /// No description provided for @layoutCourseCardDisplaySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'默认显示课程名、老师和教室；其他信息可按课表自由开关组合'**
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
  /// **'显示上下课字样'**
  String get layoutShowTimeLabelsTitle;

  /// No description provided for @layoutShowTimeLabelsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'关闭后仅显示时间点，不显示“上课”“下课”文字'**
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
  /// **'非本周课程以半透明灰色显示'**
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
  /// **'关闭后，首页课表不再对冲突课程显示“冲突”小胶囊'**
  String get layoutShowConflictBadgeSubtitle;

  /// No description provided for @layoutConflictOpacityLabel.
  ///
  /// In zh, this message translates to:
  /// **'冲突课程透明度 {value}%'**
  String layoutConflictOpacityLabel(int value);

  /// No description provided for @layoutConflictOpacityTitle.
  ///
  /// In zh, this message translates to:
  /// **'冲突课程透明度'**
  String get layoutConflictOpacityTitle;

  /// No description provided for @layoutConflictOpacitySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'冲突课程会自动层叠显示，调低透明度后能同时看到多节课'**
  String get layoutConflictOpacitySubtitle;

  /// No description provided for @layoutTipsText.
  ///
  /// In zh, this message translates to:
  /// **'时间模板已移到设置首页，这里主要调课表行高、时间列、周末显示和课程卡片布局；如果你想只改当前课表的时间，先在时间模板里复制一套再应用'**
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
  /// **'如果你想补学校教务导入适配，建议同时查看教务适配仓 qingyu_warehouse'**
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

  /// No description provided for @aboutCheckingForUpdate.
  ///
  /// In zh, this message translates to:
  /// **'正在检测更新…'**
  String get aboutCheckingForUpdate;

  /// No description provided for @aboutReadVersionFailed.
  ///
  /// In zh, this message translates to:
  /// **'暂时无法读取版本信息，请稍后重试'**
  String get aboutReadVersionFailed;

  /// No description provided for @aboutReadVersionFailedHint.
  ///
  /// In zh, this message translates to:
  /// **'如果你当前网络访问 GitHub 不稳定，可稍后再试，或切到下面的国内下载方式后重试'**
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
  /// **'你现在只需要点下面的“立即下载”即可，测速、镜像和测试版都已经收进后面的高级选项里'**
  String get aboutUpdateAvailableHint;

  /// No description provided for @aboutUpdateNoUpdateHint.
  ///
  /// In zh, this message translates to:
  /// **'当前版本已经可正常使用；如果你要体验测试版，可以在后面的高级选项里打开测试版检测'**
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
  /// **'普通使用只需要点一次立即下载，下载慢、下载失败、要换线路时，再去下面的高级选项'**
  String get aboutUpdateNowAndroidSubtitle;

  /// No description provided for @aboutUpdateNowOtherSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'当前平台会直接打开下载页面，不会在应用内安装'**
  String get aboutUpdateNowOtherSubtitle;

  /// No description provided for @aboutMirrorDownloadHint.
  ///
  /// In zh, this message translates to:
  /// **'当前会优先使用国内下载，大多数国内网络直接点“立即下载”就行'**
  String get aboutMirrorDownloadHint;

  /// No description provided for @aboutOriginalDownloadHint.
  ///
  /// In zh, this message translates to:
  /// **'当前会优先使用国际源下载，如果下载慢或打不开，建议先切回“国内下载”'**
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
  /// **'默认推荐国内下载，只有你能稳定访问 GitHub 时，再切到国际源下载'**
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
  /// **'当前使用国内下载 · {current}，系统最近测速更推荐“{recommended}”，需要时可在后面的高级选项里切换'**
  String aboutMirrorModeHintRecommended(String current, String recommended);

  /// No description provided for @aboutMirrorModeHintCurrent.
  ///
  /// In zh, this message translates to:
  /// **'当前使用国内下载 · {current}，如果下载慢或失败，再到后面的高级选项里测速、换线路或填写自定义地址'**
  String aboutMirrorModeHintCurrent(String current);

  /// No description provided for @aboutOriginalModeHint.
  ///
  /// In zh, this message translates to:
  /// **'当前使用国际源下载，只有你网络能稳定访问 GitHub 时才建议这样设置；否则请切回国内下载'**
  String get aboutOriginalModeHint;

  /// No description provided for @aboutReleaseNotesTitle.
  ///
  /// In zh, this message translates to:
  /// **'本次更新说明'**
  String get aboutReleaseNotesTitle;

  /// No description provided for @aboutReleaseNotesSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'显示当前检测到版本的 Release 说明'**
  String get aboutReleaseNotesSubtitle;

  /// No description provided for @aboutAdvancedOptionsTitle.
  ///
  /// In zh, this message translates to:
  /// **'高级选项'**
  String get aboutAdvancedOptionsTitle;

  /// No description provided for @aboutAdvancedOptionsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'只有下载慢、要手动切线路、或要检测测试版时再展开'**
  String get aboutAdvancedOptionsSubtitle;

  /// No description provided for @aboutMirrorSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'下载线路与镜像'**
  String get aboutMirrorSectionTitle;

  /// No description provided for @aboutMirrorSectionMirrorHint.
  ///
  /// In zh, this message translates to:
  /// **'当前使用国内下载，这里可以手动切线路、测速推荐，或填写自定义下载地址'**
  String get aboutMirrorSectionMirrorHint;

  /// No description provided for @aboutMirrorSectionOriginalHint.
  ///
  /// In zh, this message translates to:
  /// **'你现在使用的是国际源下载，下面的线路设置只有在切回“国内下载”后才会生效'**
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
  /// **'当前正在使用你手动填写的下载地址'**
  String get aboutCurrentCustomMirrorHint;

  /// No description provided for @aboutCurrentMirrorHint.
  ///
  /// In zh, this message translates to:
  /// **'如果当前线路访问失败，可以切到其他内置线路，或改用自定义地址'**
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
  /// **'当前没有使用国内下载，所以这里的线路设置暂时不会生效，需要的话，请先在上面的“下载方式”里切回国内下载'**
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
  /// **'打开后会把测试版也纳入更新检查；普通使用建议关闭'**
  String get aboutCheckPrereleaseSubtitle;

  /// No description provided for @aboutUpdatePromptTitle.
  ///
  /// In zh, this message translates to:
  /// **'弹窗提醒'**
  String get aboutUpdatePromptTitle;

  /// No description provided for @aboutUpdatePromptSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'发现新版本时在首页自动弹窗，关闭后仅显示红点角标'**
  String get aboutUpdatePromptSubtitle;

  /// No description provided for @aboutDiagnosticsTitle.
  ///
  /// In zh, this message translates to:
  /// **'测试与诊断'**
  String get aboutDiagnosticsTitle;

  /// No description provided for @aboutDiagnosticsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'只有遇到“超级岛没弹出”或需要给开发者反馈时再展开'**
  String get aboutDiagnosticsSubtitle;

  /// No description provided for @aboutRecordDiagnosticsTitle.
  ///
  /// In zh, this message translates to:
  /// **'记录应用日志'**
  String get aboutRecordDiagnosticsTitle;

  /// No description provided for @aboutRecordDiagnosticsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'打开后会在本地持续记录应用运行日志；超级岛相关日志会单独标注来源'**
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
  /// **'已开启应用日志记录'**
  String get aboutLiveDiagnosticsEnabled;

  /// No description provided for @aboutLiveDiagnosticsDisabled.
  ///
  /// In zh, this message translates to:
  /// **'已关闭应用日志记录'**
  String get aboutLiveDiagnosticsDisabled;

  /// No description provided for @aboutNoDiagnosticsExportYet.
  ///
  /// In zh, this message translates to:
  /// **'还没有可导出的应用日志'**
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
  /// **'已交给系统下载管理器下载，完成后可直接从系统通知安装'**
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

  /// No description provided for @aboutContinueDownloadAction.
  ///
  /// In zh, this message translates to:
  /// **'继续下载'**
  String get aboutContinueDownloadAction;

  /// No description provided for @aboutDismissDialogAction.
  ///
  /// In zh, this message translates to:
  /// **'关闭弹窗'**
  String get aboutDismissDialogAction;

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
  /// **'以下名单来自 qingyu_warehouse 适配仓的 maintainer 字段汇总，若本地已有缓存，会先显示缓存，再后台刷新'**
  String get aboutWarehouseMaintainersIntro;

  /// No description provided for @aboutWarehouseMaintainersLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'暂时无法读取适配者名单：{error}'**
  String aboutWarehouseMaintainersLoadFailed(String error);

  /// No description provided for @aboutWarehouseMaintainersEmpty.
  ///
  /// In zh, this message translates to:
  /// **'当前还没有读取到适配者信息'**
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
  /// **'如果你会抓包、网页调试、JavaScript，或者愿意长期维护自己学校的教务系统，欢迎去 qingyu_warehouse 提交新的学校适配与修复'**
  String get aboutParticipateWarehouseSubtitle;

  /// No description provided for @importFileReadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取所选文件'**
  String get importFileReadFailed;

  /// No description provided for @importCleartextBlockedHint.
  ///
  /// In zh, this message translates to:
  /// **'该站点暂不支持 HTTPS 访问且未在明文白名单内，无法在此打开'**
  String get importCleartextBlockedHint;

  /// No description provided for @importReplaceExistingTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入课程'**
  String get importReplaceExistingTitle;

  /// No description provided for @importReplaceExistingMessage.
  ///
  /// In zh, this message translates to:
  /// **'导入 {name} 时，是否替换现有课程？此操作也会清空当前课表上的独立日程（如自习、会议等）。'**
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
  /// **'请选择学校校历的开学日期，系统已根据文件里最早的上课日期给出默认周次对应，你也可以手动调整'**
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
  /// **'先复制提示词，再到豆包左下角切换为专家模式，把课表截图和提示词一起发过去，把豆包返回的 JSON 复制回这里，点击导入后再选择开学日期'**
  String get aiWorkflowSubtitle;

  /// No description provided for @aiPromptShortAction.
  ///
  /// In zh, this message translates to:
  /// **'提示词'**
  String get aiPromptShortAction;

  /// No description provided for @aiExpertModeSuggestion.
  ///
  /// In zh, this message translates to:
  /// **'建议豆包专家模式，支持多图，截图需带星期表头'**
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
  /// **'把豆包返回的 JSON 原样粘贴到这里，然后点击导入，支持纯 JSON，也兼容 ```json 代码块'**
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
  /// **'复制提示词 -> 豆包发送截图和提示词 -> 把 JSON 贴回这里 -> 点击导入 -> 选择开学日期'**
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
  /// **'建议使用豆包，先把豆包左下角切换为专家模式，再把下面整段提示词和课表截图一起发过去，让它只返回 JSON，生成后把 JSON 复制回本页，点击导入后再选择开学日期'**
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
  /// **'是否用当前这份 AI 解析结果替换现有课程？此操作也会清空当前课表上的独立日程（如自习、会议等）。'**
  String get importAiReplaceMessage;

  /// No description provided for @importConfirmSemesterMappingSubtitleAi.
  ///
  /// In zh, this message translates to:
  /// **'请选择学校校历的开学日期，再确认课表里的第 1 周对应校历第几周，如果学校第一周没课，这里通常要改成第 2 周'**
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
  /// **'教务脚本已返回课程周次，请确认校历开学日期；如果学校前几周没有课，可把“课表第 1 周”对应到校历后面的周次'**
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
  /// **'去反馈页提一个 Issue 就行，建议一起写上学校名称、教务系统网址、登录后课表页链接或截图，这样更方便补适配'**
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

  /// No description provided for @warehouseImportExecutionLogTitle.
  ///
  /// In zh, this message translates to:
  /// **'课表导入执行日志'**
  String get warehouseImportExecutionLogTitle;

  /// No description provided for @warehouseImportExecutionLogMenuLabel.
  ///
  /// In zh, this message translates to:
  /// **'课表导入执行日志'**
  String get warehouseImportExecutionLogMenuLabel;

  /// No description provided for @warehouseImportExecutionLogShareText.
  ///
  /// In zh, this message translates to:
  /// **'这是轻屿课表导出的教务导入执行日志，包含脚本注入、桥接消息、超时与导入结果等过程记录，可直接反馈给开发人员排查问题'**
  String get warehouseImportExecutionLogShareText;

  /// No description provided for @warehouseImportExecutionLogShareSubject.
  ///
  /// In zh, this message translates to:
  /// **'轻屿课表 - 课表导入执行日志'**
  String get warehouseImportExecutionLogShareSubject;

  /// No description provided for @warehouseImportExecutionLogEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无导入执行记录。请先打开教务网页并执行导入脚本，再回来查看。'**
  String get warehouseImportExecutionLogEmpty;

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
  /// **'试试学校全称、首字母或仓库里的学校代码'**
  String get searchSchoolSuggestion;

  /// No description provided for @deleteDebugRecordTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除调试记录'**
  String get deleteDebugRecordTitle;

  /// No description provided for @deleteDebugRecordMessage.
  ///
  /// In zh, this message translates to:
  /// **'确认删除“{name}”？删除后不会影响已经导入的课程'**
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
  /// **'每条记录都可以保存自定义网址和整段脚本，保存后下次直接点“开始调试”就能复用，不需要再去某个学校详情页里找入口'**
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
  /// **'先新增一条，把网址和脚本贴进去，以后就能直接复用'**
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
  /// **'适合你反复调试同一个学校，或者不同学校保留多套脚本，保存后会一直保留，后面可随时修改'**
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

  /// No description provided for @fillUrlThenRecord.
  ///
  /// In zh, this message translates to:
  /// **'填写网址后录制'**
  String get fillUrlThenRecord;

  /// No description provided for @recordImportAction.
  ///
  /// In zh, this message translates to:
  /// **'录制导入'**
  String get recordImportAction;

  /// No description provided for @quickImportAction.
  ///
  /// In zh, this message translates to:
  /// **'⚡ 快捷导入'**
  String get quickImportAction;

  /// No description provided for @quickImportTooltip.
  ///
  /// In zh, this message translates to:
  /// **'快捷导入'**
  String get quickImportTooltip;

  /// No description provided for @selectQuickImportTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择快捷导入'**
  String get selectQuickImportTitle;

  /// No description provided for @quickImportMacroSteps.
  ///
  /// In zh, this message translates to:
  /// **'{adapterName} · {stepCount} 步'**
  String quickImportMacroSteps(String adapterName, int stepCount);

  /// No description provided for @quickImportTitle.
  ///
  /// In zh, this message translates to:
  /// **'快捷导入 - {name}'**
  String quickImportTitle(String name);

  /// No description provided for @noSavedQuickImportRecords.
  ///
  /// In zh, this message translates to:
  /// **'暂无已保存的快捷导入记录'**
  String get noSavedQuickImportRecords;

  /// No description provided for @noValidWarehouseLoginUrl.
  ///
  /// In zh, this message translates to:
  /// **'未找到有效的教务登录地址'**
  String get noValidWarehouseLoginUrl;

  /// No description provided for @noMacroRecordFound.
  ///
  /// In zh, this message translates to:
  /// **'未找到录制记录，请先完成一次录制'**
  String get noMacroRecordFound;

  /// No description provided for @quickImportPlayingTitle.
  ///
  /// In zh, this message translates to:
  /// **'自动导入中…'**
  String get quickImportPlayingTitle;

  /// No description provided for @quickImportExecutingScriptTitle.
  ///
  /// In zh, this message translates to:
  /// **'回放完成，正在执行导入脚本…'**
  String get quickImportExecutingScriptTitle;

  /// No description provided for @quickImportManualInputTitle.
  ///
  /// In zh, this message translates to:
  /// **'需要手动操作'**
  String get quickImportManualInputTitle;

  /// No description provided for @quickImportManualInputHint.
  ///
  /// In zh, this message translates to:
  /// **'请完成当前需要的手动操作，完成后点击继续'**
  String get quickImportManualInputHint;

  /// No description provided for @quickImportCancelImportAction.
  ///
  /// In zh, this message translates to:
  /// **'取消导入'**
  String get quickImportCancelImportAction;

  /// No description provided for @quickImportContinueAction.
  ///
  /// In zh, this message translates to:
  /// **'继续'**
  String get quickImportContinueAction;

  /// No description provided for @quickImportFinishedTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入完成'**
  String get quickImportFinishedTitle;

  /// No description provided for @quickImportDismissAction.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get quickImportDismissAction;

  /// No description provided for @quickImportRetryAction.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get quickImportRetryAction;

  /// No description provided for @homePullQuickImportTitle.
  ///
  /// In zh, this message translates to:
  /// **'首页下拉快捷导入'**
  String get homePullQuickImportTitle;

  /// No description provided for @homePullQuickImportSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'在首页下拉时自动执行教务快捷导入'**
  String get homePullQuickImportSubtitle;

  /// No description provided for @homePullQuickImportFetchingCourses.
  ///
  /// In zh, this message translates to:
  /// **'正在获取新课程…'**
  String get homePullQuickImportFetchingCourses;

  /// No description provided for @homePullQuickImportNeedsManualAction.
  ///
  /// In zh, this message translates to:
  /// **'需要手动操作，请前往教务导入页面继续'**
  String get homePullQuickImportNeedsManualAction;

  /// No description provided for @quickImportPlaybackStepProgress.
  ///
  /// In zh, this message translates to:
  /// **'步骤 {current} / {total}'**
  String quickImportPlaybackStepProgress(int current, int total);

  /// No description provided for @quickImportCancelPlaybackAction.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get quickImportCancelPlaybackAction;

  /// No description provided for @quickImportUnknownError.
  ///
  /// In zh, this message translates to:
  /// **'发生未知错误'**
  String get quickImportUnknownError;

  /// No description provided for @recentSchoolLabel.
  ///
  /// In zh, this message translates to:
  /// **'最近使用'**
  String get recentSchoolLabel;

  /// No description provided for @warehouseSchoolTapHint.
  ///
  /// In zh, this message translates to:
  /// **'点击进入，选择适配器导入'**
  String get warehouseSchoolTapHint;

  /// No description provided for @warehouseAdaptersLoadFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂时无法读取适配器列表'**
  String get warehouseAdaptersLoadFailedTitle;

  /// No description provided for @stopRecordingTooltip.
  ///
  /// In zh, this message translates to:
  /// **'停止录制'**
  String get stopRecordingTooltip;

  /// No description provided for @startRecordingTooltip.
  ///
  /// In zh, this message translates to:
  /// **'录制操作'**
  String get startRecordingTooltip;

  /// No description provided for @savedImportUrlHint.
  ///
  /// In zh, this message translates to:
  /// **'已保存教务网址，下次可直接导入'**
  String get savedImportUrlHint;

  /// No description provided for @adapterIntroSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'可查看适配器信息、登录入口与脚本状态'**
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
  /// **'脚本已成功读取，长度 {count} 字符'**
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

  /// No description provided for @courseConflictSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'冲突课程'**
  String get courseConflictSectionTitle;

  /// No description provided for @courseNormalSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'其他课程'**
  String get courseNormalSectionTitle;

  /// No description provided for @courseConflictDetailTitle.
  ///
  /// In zh, this message translates to:
  /// **'冲突详情'**
  String get courseConflictDetailTitle;

  /// No description provided for @courseConflictDetailEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'查看冲突详情'**
  String get courseConflictDetailEntryTitle;

  /// No description provided for @courseConflictDetailEntrySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'查看互撞排课与重叠时段'**
  String get courseConflictDetailEntrySubtitle;

  /// No description provided for @courseConflictWithCourse.
  ///
  /// In zh, this message translates to:
  /// **'与「{name}」冲突'**
  String courseConflictWithCourse(String name);

  /// No description provided for @courseConflictOpenPartnerAction.
  ///
  /// In zh, this message translates to:
  /// **'查看对方排课'**
  String get courseConflictOpenPartnerAction;

  /// No description provided for @courseConflictEmpty.
  ///
  /// In zh, this message translates to:
  /// **'当前没有检测到冲突'**
  String get courseConflictEmpty;

  /// No description provided for @courseConflictPairTitle.
  ///
  /// In zh, this message translates to:
  /// **'冲突组合'**
  String get courseConflictPairTitle;

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
  /// **'当前查看第 {week} 周，可直接对这一周这节课调课'**
  String courseDialogCurrentWeekHint(int week);

  /// No description provided for @courseDialogNotThisWeekHint.
  ///
  /// In zh, this message translates to:
  /// **'当前查看第 {week} 周，这门课这周没有上课，因此不能按“本周这节”调课'**
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
  /// **'你可以删掉整条排课，也可以只删当前看到的这一周这一节'**
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
  /// **'“删这个课”会删除这条排课的全部周次；“删这节课”只会删除第 {week} 周这一次'**
  String deleteModeHintCurrentWeek(int week);

  /// No description provided for @deleteModeHintUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'当前卡片不是第 {week} 周的实际排课，所以只能删除整条排课'**
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
  /// **'仅改第 {week} 周本节，原课该周移除，其他周不变'**
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

  /// No description provided for @homeWidgetTargetStats22.
  ///
  /// In zh, this message translates to:
  /// **'统计 2×2'**
  String get homeWidgetTargetStats22;

  /// No description provided for @homeWidgetTargetStats24.
  ///
  /// In zh, this message translates to:
  /// **'统计概览 2×4'**
  String get homeWidgetTargetStats24;

  /// No description provided for @homeWidgetTargetTodayStrip41.
  ///
  /// In zh, this message translates to:
  /// **'今日横条 4×1'**
  String get homeWidgetTargetTodayStrip41;

  /// No description provided for @homeWidgetTargetStatsStrip41.
  ///
  /// In zh, this message translates to:
  /// **'统计横条 4×1'**
  String get homeWidgetTargetStatsStrip41;

  /// No description provided for @homeWidgetTargetExamCard22.
  ///
  /// In zh, this message translates to:
  /// **'考试倒计时 2×2'**
  String get homeWidgetTargetExamCard22;

  /// No description provided for @homeWidgetTargetTodayWide42.
  ///
  /// In zh, this message translates to:
  /// **'今日横宽 4×2'**
  String get homeWidgetTargetTodayWide42;

  /// No description provided for @addCourseSheetTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加内容'**
  String get addCourseSheetTitle;

  /// No description provided for @addCourseSheetSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'空白课表区域不响应点击，请从这里明确选择是加一节临时课、整学期重复课，还是插入一条单次日程'**
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

  /// No description provided for @feedbackWechatOaTitle.
  ///
  /// In zh, this message translates to:
  /// **'微信公众号'**
  String get feedbackWechatOaTitle;

  /// No description provided for @feedbackWechatOaSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'{name}'**
  String feedbackWechatOaSubtitle(String name);

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
  /// **'日程会按具体日期插入日视图时间线里，不会改动课程本身'**
  String get scheduleInfoSectionSubtitle;

  /// No description provided for @scheduleTimeSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'时间安排'**
  String get scheduleTimeSectionTitle;

  /// No description provided for @scheduleTimeSectionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'选择这条日程实际发生的日期和起止时间'**
  String get scheduleTimeSectionSubtitle;

  /// No description provided for @scheduleAppearanceSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示样式'**
  String get scheduleAppearanceSectionTitle;

  /// No description provided for @scheduleAppearanceSectionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'选择一个更容易和课程区分的日程颜色'**
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

  /// No description provided for @scheduleStartGroupLabel.
  ///
  /// In zh, this message translates to:
  /// **'开始'**
  String get scheduleStartGroupLabel;

  /// No description provided for @scheduleEndGroupLabel.
  ///
  /// In zh, this message translates to:
  /// **'结束'**
  String get scheduleEndGroupLabel;

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
  /// **'同日结束时，结束时间必须晚于开始时间'**
  String get scheduleSingleDayHint;

  /// No description provided for @scheduleCrossDaySpanHint.
  ///
  /// In zh, this message translates to:
  /// **'从 {start} 持续到 {end}'**
  String scheduleCrossDaySpanHint(Object start, Object end);

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

  /// No description provided for @scheduleListTitle.
  ///
  /// In zh, this message translates to:
  /// **'日程安排'**
  String get scheduleListTitle;

  /// No description provided for @scheduleListEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无日程'**
  String get scheduleListEmptyTitle;

  /// No description provided for @scheduleUpcomingSection.
  ///
  /// In zh, this message translates to:
  /// **'即将到来'**
  String get scheduleUpcomingSection;

  /// No description provided for @schedulePastSection.
  ///
  /// In zh, this message translates to:
  /// **'已过期'**
  String get schedulePastSection;

  /// No description provided for @schedulePausedSection.
  ///
  /// In zh, this message translates to:
  /// **'已暂停'**
  String get schedulePausedSection;

  /// No description provided for @scheduleOngoingLabel.
  ///
  /// In zh, this message translates to:
  /// **'进行中'**
  String get scheduleOngoingLabel;

  /// No description provided for @scheduleTimeRange.
  ///
  /// In zh, this message translates to:
  /// **'{start} – {end}'**
  String scheduleTimeRange(String start, String end);

  /// No description provided for @scheduleWeeklyWithDay.
  ///
  /// In zh, this message translates to:
  /// **'每周{day}'**
  String scheduleWeeklyWithDay(String day);

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

  /// No description provided for @examEndTimeBeforeStart.
  ///
  /// In zh, this message translates to:
  /// **'结束时间不能早于开始时间'**
  String get examEndTimeBeforeStart;

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

  /// No description provided for @examOverviewCountdown.
  ///
  /// In zh, this message translates to:
  /// **'倒计时'**
  String get examOverviewCountdown;

  /// No description provided for @examOverviewCountdownUnit.
  ///
  /// In zh, this message translates to:
  /// **'天后'**
  String get examOverviewCountdownUnit;

  /// No description provided for @examOverviewTodayCount.
  ///
  /// In zh, this message translates to:
  /// **'今日 {count} 场'**
  String examOverviewTodayCount(int count);

  /// No description provided for @examOverviewUpcomingCount.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 场'**
  String examOverviewUpcomingCount(int count);

  /// No description provided for @examOverviewInProgress.
  ///
  /// In zh, this message translates to:
  /// **'考试进行中'**
  String get examOverviewInProgress;

  /// No description provided for @examOverviewLiveBadge.
  ///
  /// In zh, this message translates to:
  /// **'进行中'**
  String get examOverviewLiveBadge;

  /// No description provided for @examOverviewStartsAt.
  ///
  /// In zh, this message translates to:
  /// **'{time} 开始'**
  String examOverviewStartsAt(String time);

  /// No description provided for @examOverviewUntilTime.
  ///
  /// In zh, this message translates to:
  /// **'至 {time}'**
  String examOverviewUntilTime(String time);

  /// No description provided for @examOverviewReminderOn.
  ///
  /// In zh, this message translates to:
  /// **'已设提醒'**
  String get examOverviewReminderOn;

  /// No description provided for @examOverviewReminderOff.
  ///
  /// In zh, this message translates to:
  /// **'未设提醒'**
  String get examOverviewReminderOff;

  /// No description provided for @examTimeRange.
  ///
  /// In zh, this message translates to:
  /// **'{start} – {end}'**
  String examTimeRange(String start, String end);

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

  /// No description provided for @scheduleEntrySingleTitle.
  ///
  /// In zh, this message translates to:
  /// **'上课安排'**
  String get scheduleEntrySingleTitle;

  /// No description provided for @scheduleEntryCardSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'设置这门课在何时、哪些周、由谁在哪里上课'**
  String get scheduleEntryCardSubtitle;

  /// No description provided for @scheduleEntryTimeSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'什么时候上'**
  String get scheduleEntryTimeSectionTitle;

  /// No description provided for @scheduleEntryTimeSectionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'选择星期几和第几节课；连堂请填写起止节次，单节课起止相同'**
  String get scheduleEntryTimeSectionSubtitle;

  /// No description provided for @scheduleEntryWeeksSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'哪些周上'**
  String get scheduleEntryWeeksSectionTitle;

  /// No description provided for @scheduleEntryPeopleSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'谁在哪里上'**
  String get scheduleEntryPeopleSectionTitle;

  /// No description provided for @scheduleEntryTimeSchemeSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'特殊时间方案'**
  String get scheduleEntryTimeSchemeSectionTitle;

  /// No description provided for @scheduleEntryTimeSchemeSectionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'默认跟随当前课表；仅当本节课上下课时间与课表不同时才需要修改'**
  String get scheduleEntryTimeSchemeSectionSubtitle;

  /// No description provided for @scheduleSectionNumberLabel.
  ///
  /// In zh, this message translates to:
  /// **'{section}节'**
  String scheduleSectionNumberLabel(int section);

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

  /// No description provided for @holidayAdvancedTitle.
  ///
  /// In zh, this message translates to:
  /// **'节假日数据更新'**
  String get holidayAdvancedTitle;

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

  /// No description provided for @courseActionEditPrimary.
  ///
  /// In zh, this message translates to:
  /// **'编辑课程'**
  String get courseActionEditPrimary;

  /// No description provided for @courseActionRescheduleSecondary.
  ///
  /// In zh, this message translates to:
  /// **'调课'**
  String get courseActionRescheduleSecondary;

  /// No description provided for @courseActionSuspendSecondary.
  ///
  /// In zh, this message translates to:
  /// **'停课'**
  String get courseActionSuspendSecondary;

  /// No description provided for @courseActionDeleteSecondary.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get courseActionDeleteSecondary;

  /// No description provided for @courseNoteSheetTitle.
  ///
  /// In zh, this message translates to:
  /// **'课程备注'**
  String get courseNoteSheetTitle;

  /// No description provided for @courseNoteAction.
  ///
  /// In zh, this message translates to:
  /// **'备注'**
  String get courseNoteAction;

  /// No description provided for @courseNoteSaveAction.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get courseNoteSaveAction;

  /// No description provided for @courseNoteTabWholeCourse.
  ///
  /// In zh, this message translates to:
  /// **'课程简介'**
  String get courseNoteTabWholeCourse;

  /// No description provided for @courseNoteTabThisSession.
  ///
  /// In zh, this message translates to:
  /// **'本节课'**
  String get courseNoteTabThisSession;

  /// No description provided for @courseNoteWholeCourseLabel.
  ///
  /// In zh, this message translates to:
  /// **'课程简介'**
  String get courseNoteWholeCourseLabel;

  /// No description provided for @courseNoteWholeCourseHint.
  ///
  /// In zh, this message translates to:
  /// **'同名课程共享，长期有效（例如课程说明、课堂注意点）。'**
  String get courseNoteWholeCourseHint;

  /// No description provided for @courseNoteWholeCoursePlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'例如：这个老师容易点名、教室在新楼…'**
  String get courseNoteWholeCoursePlaceholder;

  /// No description provided for @courseNoteSessionLabel.
  ///
  /// In zh, this message translates to:
  /// **'本节课备注'**
  String get courseNoteSessionLabel;

  /// No description provided for @courseNoteSessionHint.
  ///
  /// In zh, this message translates to:
  /// **'仅对第 {week} 周这一次课生效，适合记录作业或携带物品。'**
  String courseNoteSessionHint(int week);

  /// No description provided for @courseNoteSessionPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'例如：交第三章习题、带电脑…'**
  String get courseNoteSessionPlaceholder;

  /// No description provided for @courseNoteHasHomeworkTitle.
  ///
  /// In zh, this message translates to:
  /// **'有作业'**
  String get courseNoteHasHomeworkTitle;

  /// No description provided for @courseNoteHasHomeworkSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'开启后，周视图课程卡片会显示作业圆标'**
  String get courseNoteHasHomeworkSubtitle;

  /// No description provided for @courseNoteHomeworkMarked.
  ///
  /// In zh, this message translates to:
  /// **'本节有作业'**
  String get courseNoteHomeworkMarked;

  /// No description provided for @courseNoteTileSubtitleEmpty.
  ///
  /// In zh, this message translates to:
  /// **'记录作业、带电脑或课堂提醒'**
  String get courseNoteTileSubtitleEmpty;

  /// No description provided for @courseNoteTileSubtitleWhole.
  ///
  /// In zh, this message translates to:
  /// **'已有课程简介'**
  String get courseNoteTileSubtitleWhole;

  /// No description provided for @courseNoteTileSubtitleSession.
  ///
  /// In zh, this message translates to:
  /// **'已有本节课备注'**
  String get courseNoteTileSubtitleSession;

  /// No description provided for @courseNoteTileSubtitleBoth.
  ///
  /// In zh, this message translates to:
  /// **'课程简介与本节课均有备注'**
  String get courseNoteTileSubtitleBoth;

  /// No description provided for @courseNoteReadOnlyNotice.
  ///
  /// In zh, this message translates to:
  /// **'对方课程仅可查看备注，无法编辑。'**
  String get courseNoteReadOnlyNotice;

  /// No description provided for @courseNoteDoneEditingAction.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get courseNoteDoneEditingAction;

  /// No description provided for @courseActionSheetNotice.
  ///
  /// In zh, this message translates to:
  /// **'您正在查看第 {week} 周，如该时段突发考试或冲突，可立即在下方执行快速调课或停课'**
  String courseActionSheetNotice(int week);

  /// No description provided for @courseActionOddWeekShort.
  ///
  /// In zh, this message translates to:
  /// **'单周'**
  String get courseActionOddWeekShort;

  /// No description provided for @courseActionEvenWeekShort.
  ///
  /// In zh, this message translates to:
  /// **'双周'**
  String get courseActionEvenWeekShort;

  /// No description provided for @courseActionConflictExpandHint.
  ///
  /// In zh, this message translates to:
  /// **'展开查看其他冲突课程，点击可切换操作对象'**
  String get courseActionConflictExpandHint;

  /// No description provided for @courseActionConflictCollapseHint.
  ///
  /// In zh, this message translates to:
  /// **'点击收起冲突课程列表'**
  String get courseActionConflictCollapseHint;

  /// No description provided for @courseActionConflictSwitchAction.
  ///
  /// In zh, this message translates to:
  /// **'切换'**
  String get courseActionConflictSwitchAction;

  /// No description provided for @courseActionCoupleRelatedCount.
  ///
  /// In zh, this message translates to:
  /// **'还有 {count} 节情侣课表课程'**
  String courseActionCoupleRelatedCount(int count);

  /// No description provided for @courseActionCoupleExpandHint.
  ///
  /// In zh, this message translates to:
  /// **'展开查看 TA 的课或一起上课，点击可切换预览'**
  String get courseActionCoupleExpandHint;

  /// No description provided for @courseActionCoupleCollapseHint.
  ///
  /// In zh, this message translates to:
  /// **'点击收起情侣课表课程列表'**
  String get courseActionCoupleCollapseHint;

  /// No description provided for @courseActionMixedRelatedCount.
  ///
  /// In zh, this message translates to:
  /// **'还有 {count} 节相关课程'**
  String courseActionMixedRelatedCount(int count);

  /// No description provided for @courseActionPartnerReadOnlyNotice.
  ///
  /// In zh, this message translates to:
  /// **'这是对方课表中的课程，仅供查看，无法编辑或调课'**
  String get courseActionPartnerReadOnlyNotice;

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

  /// No description provided for @customHolidayCorrupted.
  ///
  /// In zh, this message translates to:
  /// **'自定义假期数据读取异常，已暂停读写以防覆盖丢失'**
  String get customHolidayCorrupted;

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

  /// No description provided for @guidePersonalizePageTitle.
  ///
  /// In zh, this message translates to:
  /// **'个性化定制'**
  String get guidePersonalizePageTitle;

  /// No description provided for @guidePersonalizeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'以下选择立即生效，之后可随时在「设置 → 外观」中调整'**
  String get guidePersonalizeSubtitle;

  /// No description provided for @guidePersonalizeMenuStyleTitle.
  ///
  /// In zh, this message translates to:
  /// **'菜单样式'**
  String get guidePersonalizeMenuStyleTitle;

  /// No description provided for @guidePersonalizeNavFormTitle.
  ///
  /// In zh, this message translates to:
  /// **'导航形态'**
  String get guidePersonalizeNavFormTitle;

  /// No description provided for @guidePersonalizeVisualEffectTitle.
  ///
  /// In zh, this message translates to:
  /// **'视觉效果'**
  String get guidePersonalizeVisualEffectTitle;

  /// No description provided for @guidePersonalizeVisualEffectSolid.
  ///
  /// In zh, this message translates to:
  /// **'实体卡片'**
  String get guidePersonalizeVisualEffectSolid;

  /// No description provided for @guideVisualEffectGaussianDesc.
  ///
  /// In zh, this message translates to:
  /// **'背景实时高斯模糊，通透有层次'**
  String get guideVisualEffectGaussianDesc;

  /// No description provided for @guideVisualEffectLiquidDesc.
  ///
  /// In zh, this message translates to:
  /// **'液态玻璃折射，更具质感（功耗略高）'**
  String get guideVisualEffectLiquidDesc;

  /// No description provided for @guideVisualEffectSolidDesc.
  ///
  /// In zh, this message translates to:
  /// **'不启用模糊效果，性能最好'**
  String get guideVisualEffectSolidDesc;

  /// No description provided for @guidePersonalizeThemeModeTitle.
  ///
  /// In zh, this message translates to:
  /// **'深浅色模式'**
  String get guidePersonalizeThemeModeTitle;

  /// No description provided for @guidePersonalizeSeedColorTitle.
  ///
  /// In zh, this message translates to:
  /// **'主题色'**
  String get guidePersonalizeSeedColorTitle;

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
  /// **'点击后跳转到系统设置，返回应用后可识别的状态会自动刷新；自启动受系统限制，请以系统页面开关为准'**
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

  /// No description provided for @foruiThemeNeutral.
  ///
  /// In zh, this message translates to:
  /// **'中性灰'**
  String get foruiThemeNeutral;

  /// No description provided for @foruiThemeZinc.
  ///
  /// In zh, this message translates to:
  /// **'锌灰'**
  String get foruiThemeZinc;

  /// No description provided for @foruiThemeSlate.
  ///
  /// In zh, this message translates to:
  /// **'石板灰'**
  String get foruiThemeSlate;

  /// No description provided for @foruiThemeBlue.
  ///
  /// In zh, this message translates to:
  /// **'蓝'**
  String get foruiThemeBlue;

  /// No description provided for @foruiThemeGreen.
  ///
  /// In zh, this message translates to:
  /// **'绿'**
  String get foruiThemeGreen;

  /// No description provided for @foruiThemeOrange.
  ///
  /// In zh, this message translates to:
  /// **'橙'**
  String get foruiThemeOrange;

  /// No description provided for @foruiThemeRed.
  ///
  /// In zh, this message translates to:
  /// **'红'**
  String get foruiThemeRed;

  /// No description provided for @foruiThemeRose.
  ///
  /// In zh, this message translates to:
  /// **'玫红'**
  String get foruiThemeRose;

  /// No description provided for @foruiThemeViolet.
  ///
  /// In zh, this message translates to:
  /// **'紫'**
  String get foruiThemeViolet;

  /// No description provided for @foruiThemeYellow.
  ///
  /// In zh, this message translates to:
  /// **'黄'**
  String get foruiThemeYellow;

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

  /// No description provided for @themeDuplicateCopyName.
  ///
  /// In zh, this message translates to:
  /// **'{name} 副本'**
  String themeDuplicateCopyName(String name);

  /// No description provided for @themeMoreActions.
  ///
  /// In zh, this message translates to:
  /// **'更多操作'**
  String get themeMoreActions;

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

  /// No description provided for @statisticsStoryBusiestDayTitle.
  ///
  /// In zh, this message translates to:
  /// **'最忙的一天'**
  String get statisticsStoryBusiestDayTitle;

  /// No description provided for @statisticsStoryBusiestDayContent.
  ///
  /// In zh, this message translates to:
  /// **'截至第{week}周，这学期你最忙的一天是 **{day}**，平均 **{avg}** 节课'**
  String statisticsStoryBusiestDayContent(int week, String day, String avg);

  /// No description provided for @statisticsStoryLightestDayTitle.
  ///
  /// In zh, this message translates to:
  /// **'最轻松的一天'**
  String get statisticsStoryLightestDayTitle;

  /// No description provided for @statisticsStoryLightestDayContent.
  ///
  /// In zh, this message translates to:
  /// **'截至第{week}周，你最轻松的一天是 **{day}**，只有 **{avg}** 节课'**
  String statisticsStoryLightestDayContent(int week, String day, String avg);

  /// No description provided for @statisticsStoryFavoriteRoomTitle.
  ///
  /// In zh, this message translates to:
  /// **'最常去的教室'**
  String get statisticsStoryFavoriteRoomTitle;

  /// No description provided for @statisticsStoryFavoriteRoomContent.
  ///
  /// In zh, this message translates to:
  /// **'截至第{week}周，你最常去的教室是 **{room}**，共去了 **{count}** 次'**
  String statisticsStoryFavoriteRoomContent(int week, String room, int count);

  /// No description provided for @statisticsStoryBuildingCountTitle.
  ///
  /// In zh, this message translates to:
  /// **'教学楼探险'**
  String get statisticsStoryBuildingCountTitle;

  /// No description provided for @statisticsStoryBuildingCountContent.
  ///
  /// In zh, this message translates to:
  /// **'截至第{week}周，你的课程分布在 **{count}** 栋不同的教学楼'**
  String statisticsStoryBuildingCountContent(int week, int count);

  /// No description provided for @statisticsStoryTimeRangeTitle.
  ///
  /// In zh, this message translates to:
  /// **'时间跨度'**
  String get statisticsStoryTimeRangeTitle;

  /// No description provided for @statisticsStoryTimeRangeContent.
  ///
  /// In zh, this message translates to:
  /// **'你最早的课是 **{earliest}**，最晚的课是 **{latest}**'**
  String statisticsStoryTimeRangeContent(String earliest, String latest);

  /// No description provided for @statisticsSemesterLabelCourses.
  ///
  /// In zh, this message translates to:
  /// **'门课程'**
  String get statisticsSemesterLabelCourses;

  /// No description provided for @statisticsSemesterLabelSections.
  ///
  /// In zh, this message translates to:
  /// **'节课'**
  String get statisticsSemesterLabelSections;

  /// No description provided for @statisticsSemesterLabelWeeks.
  ///
  /// In zh, this message translates to:
  /// **'周'**
  String get statisticsSemesterLabelWeeks;

  /// No description provided for @statisticsSemesterLabelDayStreak.
  ///
  /// In zh, this message translates to:
  /// **'天连续'**
  String get statisticsSemesterLabelDayStreak;

  /// No description provided for @statisticsAchievementsTitle.
  ///
  /// In zh, this message translates to:
  /// **'成就徽章'**
  String get statisticsAchievementsTitle;

  /// No description provided for @statisticsStoriesTitle.
  ///
  /// In zh, this message translates to:
  /// **'数据故事'**
  String get statisticsStoriesTitle;

  /// No description provided for @statisticsRankingTitle.
  ///
  /// In zh, this message translates to:
  /// **'课程排行'**
  String get statisticsRankingTitle;

  /// No description provided for @statisticsNoDataHint.
  ///
  /// In zh, this message translates to:
  /// **'添加课程后即可查看统计'**
  String get statisticsNoDataHint;

  /// No description provided for @statisticsShareLabel.
  ///
  /// In zh, this message translates to:
  /// **'分享统计'**
  String get statisticsShareLabel;

  /// No description provided for @statisticsExportTitle.
  ///
  /// In zh, this message translates to:
  /// **'导出统计'**
  String get statisticsExportTitle;

  /// No description provided for @statisticsExportModulesSection.
  ///
  /// In zh, this message translates to:
  /// **'包含模块'**
  String get statisticsExportModulesSection;

  /// No description provided for @statisticsExportFormatSection.
  ///
  /// In zh, this message translates to:
  /// **'导出格式'**
  String get statisticsExportFormatSection;

  /// No description provided for @statisticsExportFormatImage.
  ///
  /// In zh, this message translates to:
  /// **'长图 (PNG)'**
  String get statisticsExportFormatImage;

  /// No description provided for @statisticsExportFormatPdf.
  ///
  /// In zh, this message translates to:
  /// **'PDF 文档'**
  String get statisticsExportFormatPdf;

  /// No description provided for @statisticsExportAction.
  ///
  /// In zh, this message translates to:
  /// **'开始导出'**
  String get statisticsExportAction;

  /// No description provided for @statisticsExportSelectModuleHint.
  ///
  /// In zh, this message translates to:
  /// **'请至少选择一个模块'**
  String get statisticsExportSelectModuleHint;

  /// No description provided for @statisticsExportModuleOverview.
  ///
  /// In zh, this message translates to:
  /// **'学期总览'**
  String get statisticsExportModuleOverview;

  /// No description provided for @statisticsExportBrandTagline.
  ///
  /// In zh, this message translates to:
  /// **'把课程信息做成系统体验'**
  String get statisticsExportBrandTagline;

  /// No description provided for @statisticsExportGithubHint.
  ///
  /// In zh, this message translates to:
  /// **'GitHub 搜索项目：{url}'**
  String statisticsExportGithubHint(String url);

  /// No description provided for @statisticsExportQrScanHint.
  ///
  /// In zh, this message translates to:
  /// **'扫码访问官网'**
  String get statisticsExportQrScanHint;

  /// No description provided for @statisticsExportRankingMore.
  ///
  /// In zh, this message translates to:
  /// **'另有 {count} 门课程未展示'**
  String statisticsExportRankingMore(int count);

  /// No description provided for @statisticsShareTitle.
  ///
  /// In zh, this message translates to:
  /// **'我的学期统计'**
  String get statisticsShareTitle;

  /// No description provided for @statisticsRankingSlotDetail.
  ///
  /// In zh, this message translates to:
  /// **'{day} 第{startSection}-{endSection}节'**
  String statisticsRankingSlotDetail(
    String day,
    int startSection,
    int endSection,
  );

  /// No description provided for @statisticsAchievementEarlyBirdName.
  ///
  /// In zh, this message translates to:
  /// **'早八战士'**
  String get statisticsAchievementEarlyBirdName;

  /// No description provided for @statisticsAchievementEarlyBirdDescription.
  ///
  /// In zh, this message translates to:
  /// **'有 8:00 的课，真棒！'**
  String get statisticsAchievementEarlyBirdDescription;

  /// No description provided for @statisticsAchievementPerfectAttendanceName.
  ///
  /// In zh, this message translates to:
  /// **'全勤达人'**
  String get statisticsAchievementPerfectAttendanceName;

  /// No description provided for @statisticsAchievementPerfectAttendanceDescription.
  ///
  /// In zh, this message translates to:
  /// **'某门课每周都有'**
  String get statisticsAchievementPerfectAttendanceDescription;

  /// No description provided for @statisticsAchievementWeekendWarriorName.
  ///
  /// In zh, this message translates to:
  /// **'周末战士'**
  String get statisticsAchievementWeekendWarriorName;

  /// No description provided for @statisticsAchievementWeekendWarriorDescription.
  ///
  /// In zh, this message translates to:
  /// **'周末有课'**
  String get statisticsAchievementWeekendWarriorDescription;

  /// No description provided for @statisticsAchievementClassKingName.
  ///
  /// In zh, this message translates to:
  /// **'课王'**
  String get statisticsAchievementClassKingName;

  /// No description provided for @statisticsAchievementClassKingDescription.
  ///
  /// In zh, this message translates to:
  /// **'某天 ≥ 6 节课'**
  String get statisticsAchievementClassKingDescription;

  /// No description provided for @statisticsAchievementScholarName.
  ///
  /// In zh, this message translates to:
  /// **'学霸'**
  String get statisticsAchievementScholarName;

  /// No description provided for @statisticsAchievementScholarDescription.
  ///
  /// In zh, this message translates to:
  /// **'总课时 ≥ 100'**
  String get statisticsAchievementScholarDescription;

  /// No description provided for @statisticsAchievementBalancedName.
  ///
  /// In zh, this message translates to:
  /// **'均衡大师'**
  String get statisticsAchievementBalancedName;

  /// No description provided for @statisticsAchievementBalancedDescription.
  ///
  /// In zh, this message translates to:
  /// **'每天课时差距 ≤ 2'**
  String get statisticsAchievementBalancedDescription;

  /// No description provided for @statisticsAchievementNightOwlName.
  ///
  /// In zh, this message translates to:
  /// **'夜猫子'**
  String get statisticsAchievementNightOwlName;

  /// No description provided for @statisticsAchievementNightOwlDescription.
  ///
  /// In zh, this message translates to:
  /// **'有 18:00 以后的课'**
  String get statisticsAchievementNightOwlDescription;

  /// No description provided for @statisticsAchievementExplorerName.
  ///
  /// In zh, this message translates to:
  /// **'教室探索家'**
  String get statisticsAchievementExplorerName;

  /// No description provided for @statisticsAchievementExplorerDescription.
  ///
  /// In zh, this message translates to:
  /// **'使用过 ≥ 5 个不同教室'**
  String get statisticsAchievementExplorerDescription;

  /// No description provided for @statisticsNatureLegendDetail.
  ///
  /// In zh, this message translates to:
  /// **'{count} 门 · {sections} 节'**
  String statisticsNatureLegendDetail(int count, int sections);

  /// No description provided for @statisticsWeekCurrentHint.
  ///
  /// In zh, this message translates to:
  /// **'本周'**
  String get statisticsWeekCurrentHint;

  /// No description provided for @weeklyReportTitle.
  ///
  /// In zh, this message translates to:
  /// **'本周课程小结'**
  String get weeklyReportTitle;

  /// No description provided for @weeklyReportBody.
  ///
  /// In zh, this message translates to:
  /// **'第{week}周 · 共{sections}节 · {courses}门课\n较上周 {delta} 节\n最忙的一天是 {busiestDay}'**
  String weeklyReportBody(
    int week,
    int sections,
    int courses,
    String delta,
    String busiestDay,
  );

  /// No description provided for @weeklyReportBodyEmpty.
  ///
  /// In zh, this message translates to:
  /// **'本周暂无课程，好好休息吧'**
  String get weeklyReportBodyEmpty;

  /// No description provided for @weeklyReportNextFire.
  ///
  /// In zh, this message translates to:
  /// **'下次推送 {date} {time}'**
  String weeklyReportNextFire(String date, String time);

  /// No description provided for @weeklyReportEnabledHint.
  ///
  /// In zh, this message translates to:
  /// **'已开启每周周报推送'**
  String get weeklyReportEnabledHint;

  /// No description provided for @weeklyReportDisabledHint.
  ///
  /// In zh, this message translates to:
  /// **'已关闭每周周报推送'**
  String get weeklyReportDisabledHint;

  /// No description provided for @statisticsCompareTitle.
  ///
  /// In zh, this message translates to:
  /// **'课表对比'**
  String get statisticsCompareTitle;

  /// No description provided for @statisticsCompareActive.
  ///
  /// In zh, this message translates to:
  /// **'当前课表'**
  String get statisticsCompareActive;

  /// No description provided for @statisticsCompareNone.
  ///
  /// In zh, this message translates to:
  /// **'暂无其他课表，可在课表管理中新建'**
  String get statisticsCompareNone;

  /// No description provided for @statisticsCompareDelta.
  ///
  /// In zh, this message translates to:
  /// **'较当前 {delta} 节'**
  String statisticsCompareDelta(String delta);

  /// No description provided for @statisticsCompareDetailTitle.
  ///
  /// In zh, this message translates to:
  /// **'课表对比详情'**
  String get statisticsCompareDetailTitle;

  /// No description provided for @statisticsCompareWeek.
  ///
  /// In zh, this message translates to:
  /// **'当前周'**
  String get statisticsCompareWeek;

  /// No description provided for @statisticsMoreTitle.
  ///
  /// In zh, this message translates to:
  /// **'深度分析'**
  String get statisticsMoreTitle;

  /// Accordion group header: trend and distribution analysis entries
  ///
  /// In zh, this message translates to:
  /// **'趋势 · 分布'**
  String get statisticsMoreGroupTrend;

  /// Accordion group header: classroom, teacher and ranking analysis entries
  ///
  /// In zh, this message translates to:
  /// **'教室 · 教师 · 排行'**
  String get statisticsMoreGroupPeople;

  /// Donut chart center hint when required-course count is zero
  ///
  /// In zh, this message translates to:
  /// **'暂无必修'**
  String get statisticsNatureNoneRequired;

  /// Donut chart center hint when elective-course count is zero
  ///
  /// In zh, this message translates to:
  /// **'暂无选修'**
  String get statisticsNatureNoneElective;

  /// No description provided for @statisticsAchievementMorningPersonName.
  ///
  /// In zh, this message translates to:
  /// **'早起鸟'**
  String get statisticsAchievementMorningPersonName;

  /// No description provided for @statisticsAchievementMorningPersonDescription.
  ///
  /// In zh, this message translates to:
  /// **'早间课时占比 ≥ 50%'**
  String get statisticsAchievementMorningPersonDescription;

  /// No description provided for @statisticsAchievementGapMasterName.
  ///
  /// In zh, this message translates to:
  /// **'时间管理大师'**
  String get statisticsAchievementGapMasterName;

  /// No description provided for @statisticsAchievementGapMasterDescription.
  ///
  /// In zh, this message translates to:
  /// **'最长课间空档 ≤ 2 节'**
  String get statisticsAchievementGapMasterDescription;

  /// No description provided for @statisticsAchievementEarlyBirdDetail.
  ///
  /// In zh, this message translates to:
  /// **'解锁条件：课表中有 08:00 或更早开始的课程。'**
  String get statisticsAchievementEarlyBirdDetail;

  /// No description provided for @statisticsAchievementPerfectAttendanceDetail.
  ///
  /// In zh, this message translates to:
  /// **'解锁条件：至少一门课程在开课周期内每周都有课（无停课、无单双周跳课）。'**
  String get statisticsAchievementPerfectAttendanceDetail;

  /// No description provided for @statisticsAchievementWeekendWarriorDetail.
  ///
  /// In zh, this message translates to:
  /// **'解锁条件：周末（周六或周日）有课。'**
  String get statisticsAchievementWeekendWarriorDetail;

  /// No description provided for @statisticsAchievementClassKingDetail.
  ///
  /// In zh, this message translates to:
  /// **'解锁条件：某一天排课达到 6 节及以上。'**
  String get statisticsAchievementClassKingDetail;

  /// No description provided for @statisticsAchievementScholarDetail.
  ///
  /// In zh, this message translates to:
  /// **'解锁条件：学期累计课时达到 100 节。'**
  String get statisticsAchievementScholarDetail;

  /// No description provided for @statisticsAchievementBalancedDetail.
  ///
  /// In zh, this message translates to:
  /// **'解锁条件：每天课时差距不超过 2 节，课表安排均衡。'**
  String get statisticsAchievementBalancedDetail;

  /// No description provided for @statisticsAchievementNightOwlDetail.
  ///
  /// In zh, this message translates to:
  /// **'解锁条件：有 18:00 以后才结束的课。'**
  String get statisticsAchievementNightOwlDetail;

  /// No description provided for @statisticsAchievementExplorerDetail.
  ///
  /// In zh, this message translates to:
  /// **'解锁条件：使用过 5 个及以上不同的教室。'**
  String get statisticsAchievementExplorerDetail;

  /// No description provided for @statisticsAchievementFullDayKingDetail.
  ///
  /// In zh, this message translates to:
  /// **'解锁条件：某一天排课达到 8 节及以上，全天满课。'**
  String get statisticsAchievementFullDayKingDetail;

  /// No description provided for @statisticsAchievementBuildingHopperDetail.
  ///
  /// In zh, this message translates to:
  /// **'解锁条件：同一天内去过 3 栋及以上不同的教学楼。'**
  String get statisticsAchievementBuildingHopperDetail;

  /// No description provided for @statisticsAchievementMorningPersonDetail.
  ///
  /// In zh, this message translates to:
  /// **'解锁条件：早间（12:00 前开始）课时占总课时的一半以上。'**
  String get statisticsAchievementMorningPersonDetail;

  /// No description provided for @statisticsAchievementGapMasterDetail.
  ///
  /// In zh, this message translates to:
  /// **'解锁条件：每天课间最长空档不超过 2 节，时间安排紧凑。'**
  String get statisticsAchievementGapMasterDetail;

  /// No description provided for @statisticsAchievementDetailConfirm.
  ///
  /// In zh, this message translates to:
  /// **'知道了'**
  String get statisticsAchievementDetailConfirm;

  /// No description provided for @statisticsAchievementLocked.
  ///
  /// In zh, this message translates to:
  /// **'未达成'**
  String get statisticsAchievementLocked;

  /// No description provided for @statisticsSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'统计设置'**
  String get statisticsSettingsTitle;

  /// No description provided for @statisticsTabSemester.
  ///
  /// In zh, this message translates to:
  /// **'学期'**
  String get statisticsTabSemester;

  /// No description provided for @statisticsTabWeek.
  ///
  /// In zh, this message translates to:
  /// **'周'**
  String get statisticsTabWeek;

  /// No description provided for @statisticsSemesterProgressTitle.
  ///
  /// In zh, this message translates to:
  /// **'学期进度'**
  String get statisticsSemesterProgressTitle;

  /// No description provided for @statisticsSemesterProgressRange.
  ///
  /// In zh, this message translates to:
  /// **'学期 {start} - {end}'**
  String statisticsSemesterProgressRange(String start, String end);

  /// No description provided for @statisticsSemesterProgressAsOf.
  ///
  /// In zh, this message translates to:
  /// **'今天 {date}'**
  String statisticsSemesterProgressAsOf(String date);

  /// No description provided for @statisticsSemesterProgressDetail.
  ///
  /// In zh, this message translates to:
  /// **'截至第 {week} 周，已上 {done} 节 / 共 {total} 节'**
  String statisticsSemesterProgressDetail(int week, int done, int total);

  /// No description provided for @statisticsSemesterProgressRemaining.
  ///
  /// In zh, this message translates to:
  /// **'剩余 {count} 节'**
  String statisticsSemesterProgressRemaining(int count);

  /// No description provided for @statisticsSemesterProgressNotStarted.
  ///
  /// In zh, this message translates to:
  /// **'还未开学，尚未上课'**
  String get statisticsSemesterProgressNotStarted;

  /// No description provided for @statisticsSemesterProgressEstimated.
  ///
  /// In zh, this message translates to:
  /// **'按周估算'**
  String get statisticsSemesterProgressEstimated;

  /// No description provided for @statisticsTrendTitle.
  ///
  /// In zh, this message translates to:
  /// **'每周课时趋势'**
  String get statisticsTrendTitle;

  /// No description provided for @statisticsTrendTooltip.
  ///
  /// In zh, this message translates to:
  /// **'第 {week} 周 · {sections} 节'**
  String statisticsTrendTooltip(int week, int sections);

  /// No description provided for @statisticsComparisonTitle.
  ///
  /// In zh, this message translates to:
  /// **'本周小结'**
  String get statisticsComparisonTitle;

  /// No description provided for @statisticsComparisonLastWeek.
  ///
  /// In zh, this message translates to:
  /// **'上周课时'**
  String get statisticsComparisonLastWeek;

  /// No description provided for @statisticsComparisonAverage.
  ///
  /// In zh, this message translates to:
  /// **'学期周均'**
  String get statisticsComparisonAverage;

  /// No description provided for @statisticsComparisonVsLastWeek.
  ///
  /// In zh, this message translates to:
  /// **'较上周 {delta} 节'**
  String statisticsComparisonVsLastWeek(String delta);

  /// No description provided for @statisticsComparisonVsAverage.
  ///
  /// In zh, this message translates to:
  /// **'较周均 {delta} 节'**
  String statisticsComparisonVsAverage(String delta);

  /// No description provided for @statisticsComparisonNew.
  ///
  /// In zh, this message translates to:
  /// **'新学期第一周'**
  String get statisticsComparisonNew;

  /// No description provided for @statisticsHeatmapTitle.
  ///
  /// In zh, this message translates to:
  /// **'学期热力图'**
  String get statisticsHeatmapTitle;

  /// No description provided for @statisticsHeatmapHint.
  ///
  /// In zh, this message translates to:
  /// **'颜色越深，课时越多'**
  String get statisticsHeatmapHint;

  /// No description provided for @statisticsTimeUtilTitle.
  ///
  /// In zh, this message translates to:
  /// **'时间利用'**
  String get statisticsTimeUtilTitle;

  /// No description provided for @statisticsTimeEarliest.
  ///
  /// In zh, this message translates to:
  /// **'最早课'**
  String get statisticsTimeEarliest;

  /// No description provided for @statisticsTimeLatest.
  ///
  /// In zh, this message translates to:
  /// **'最晚课'**
  String get statisticsTimeLatest;

  /// No description provided for @statisticsTimeMorning.
  ///
  /// In zh, this message translates to:
  /// **'早间课时'**
  String get statisticsTimeMorning;

  /// No description provided for @statisticsTimeNoon.
  ///
  /// In zh, this message translates to:
  /// **'午间课时'**
  String get statisticsTimeNoon;

  /// No description provided for @statisticsTimeEvening.
  ///
  /// In zh, this message translates to:
  /// **'晚间课时'**
  String get statisticsTimeEvening;

  /// No description provided for @statisticsTimeWeekend.
  ///
  /// In zh, this message translates to:
  /// **'周末课时'**
  String get statisticsTimeWeekend;

  /// No description provided for @statisticsTimeGap.
  ///
  /// In zh, this message translates to:
  /// **'最长课间空档'**
  String get statisticsTimeGap;

  /// No description provided for @statisticsTimeGapValue.
  ///
  /// In zh, this message translates to:
  /// **'{sections} 节'**
  String statisticsTimeGapValue(int sections);

  /// No description provided for @statisticsVenueTitle.
  ///
  /// In zh, this message translates to:
  /// **'教室与教学楼'**
  String get statisticsVenueTitle;

  /// No description provided for @statisticsVenueTopRooms.
  ///
  /// In zh, this message translates to:
  /// **'常去教室'**
  String get statisticsVenueTopRooms;

  /// No description provided for @statisticsVenueBuildings.
  ///
  /// In zh, this message translates to:
  /// **'教学楼课时'**
  String get statisticsVenueBuildings;

  /// No description provided for @statisticsVenueVisits.
  ///
  /// In zh, this message translates to:
  /// **'{count} 次'**
  String statisticsVenueVisits(int count);

  /// No description provided for @statisticsTeacherTitle.
  ///
  /// In zh, this message translates to:
  /// **'教师课时排行'**
  String get statisticsTeacherTitle;

  /// No description provided for @statisticsTeacherCourseCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 门课'**
  String statisticsTeacherCourseCount(int count);

  /// No description provided for @statisticsAchievementFullDayKingName.
  ///
  /// In zh, this message translates to:
  /// **'满课日之王'**
  String get statisticsAchievementFullDayKingName;

  /// No description provided for @statisticsAchievementFullDayKingDescription.
  ///
  /// In zh, this message translates to:
  /// **'单日 ≥ 8 节课'**
  String get statisticsAchievementFullDayKingDescription;

  /// No description provided for @statisticsAchievementBuildingHopperName.
  ///
  /// In zh, this message translates to:
  /// **'跨楼达人'**
  String get statisticsAchievementBuildingHopperName;

  /// No description provided for @statisticsAchievementBuildingHopperDescription.
  ///
  /// In zh, this message translates to:
  /// **'单日跨 ≥ 3 栋教学楼'**
  String get statisticsAchievementBuildingHopperDescription;

  /// No description provided for @statisticsAchievementProgress.
  ///
  /// In zh, this message translates to:
  /// **'{current}/{target}'**
  String statisticsAchievementProgress(int current, int target);

  /// No description provided for @statisticsAchievementDone.
  ///
  /// In zh, this message translates to:
  /// **'已达成'**
  String get statisticsAchievementDone;

  /// No description provided for @statisticsWeekDailyHint.
  ///
  /// In zh, this message translates to:
  /// **'点击查看第 {week} 周详情'**
  String statisticsWeekDailyHint(int week);

  /// No description provided for @weekListSeparator.
  ///
  /// In zh, this message translates to:
  /// **'、'**
  String get weekListSeparator;

  /// No description provided for @courseWeekListLabel.
  ///
  /// In zh, this message translates to:
  /// **'第{weeks}周'**
  String courseWeekListLabel(String weeks);

  /// No description provided for @courseWeekRangeLabel.
  ///
  /// In zh, this message translates to:
  /// **'第{startWeek}-{endWeek}周{mode}'**
  String courseWeekRangeLabel(int startWeek, int endWeek, String mode);

  /// No description provided for @courseWeekSuspendedLabel.
  ///
  /// In zh, this message translates to:
  /// **'第{weeks}周停课'**
  String courseWeekSuspendedLabel(String weeks);

  /// No description provided for @importSemesterStartDateTitle.
  ///
  /// In zh, this message translates to:
  /// **'开学日期'**
  String get importSemesterStartDateTitle;

  /// No description provided for @importSemesterStartDateSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'按这一天所在周作为校历第 1 周'**
  String get importSemesterStartDateSubtitle;

  /// No description provided for @importFirstCourseWeekMappingLabel.
  ///
  /// In zh, this message translates to:
  /// **'课表第 1 周对应校历第几周'**
  String get importFirstCourseWeekMappingLabel;

  /// No description provided for @importFirstCourseWeekMappingSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'如果学校第一周没课，就选第 2 周；前两周都没课就选第 3 周'**
  String get importFirstCourseWeekMappingSubtitle;

  /// No description provided for @importSemesterMappingNoShiftHint.
  ///
  /// In zh, this message translates to:
  /// **'导入后会直接把课表第 1 周当作校历第 1 周'**
  String get importSemesterMappingNoShiftHint;

  /// No description provided for @importSemesterMappingShiftHint.
  ///
  /// In zh, this message translates to:
  /// **'导入后会把所有课程周次整体顺延 {shiftedWeeks} 周，让课表第 1 周落在校历第 {calendarWeek} 周'**
  String importSemesterMappingShiftHint(int shiftedWeeks, int calendarWeek);

  /// No description provided for @calendarWeekOption.
  ///
  /// In zh, this message translates to:
  /// **'校历第 {week} 周'**
  String calendarWeekOption(int week);

  /// No description provided for @aboutDownloadPackageMethodTitle.
  ///
  /// In zh, this message translates to:
  /// **'下载安装包方式'**
  String get aboutDownloadPackageMethodTitle;

  /// No description provided for @aboutInAppDownloadTitle.
  ///
  /// In zh, this message translates to:
  /// **'应用内下载'**
  String get aboutInAppDownloadTitle;

  /// No description provided for @aboutInAppDownloadSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'下载完成后直接在应用内安装'**
  String get aboutInAppDownloadSubtitle;

  /// No description provided for @aboutSystemDownloaderTitle.
  ///
  /// In zh, this message translates to:
  /// **'系统管理器'**
  String get aboutSystemDownloaderTitle;

  /// No description provided for @aboutSystemDownloaderChoiceSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'交给系统下载管理器处理'**
  String get aboutSystemDownloaderChoiceSubtitle;

  /// No description provided for @syncErrorAuthFailed.
  ///
  /// In zh, this message translates to:
  /// **'账号或密码错误'**
  String get syncErrorAuthFailed;

  /// No description provided for @syncErrorAccessDenied.
  ///
  /// In zh, this message translates to:
  /// **'没有访问权限'**
  String get syncErrorAccessDenied;

  /// No description provided for @syncErrorCertificateError.
  ///
  /// In zh, this message translates to:
  /// **'证书校验失败'**
  String get syncErrorCertificateError;

  /// No description provided for @syncErrorConnectionTimeout.
  ///
  /// In zh, this message translates to:
  /// **'连接超时'**
  String get syncErrorConnectionTimeout;

  /// No description provided for @syncErrorConnectionFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法连接服务器'**
  String get syncErrorConnectionFailed;

  /// No description provided for @syncErrorNetworkError.
  ///
  /// In zh, this message translates to:
  /// **'网络异常'**
  String get syncErrorNetworkError;

  /// No description provided for @syncErrorInvalidResponse.
  ///
  /// In zh, this message translates to:
  /// **'服务器响应无效'**
  String get syncErrorInvalidResponse;

  /// No description provided for @syncErrorLocalChangesPendingSync.
  ///
  /// In zh, this message translates to:
  /// **'本地有未同步修改，已跳过自动覆盖'**
  String get syncErrorLocalChangesPendingSync;

  /// No description provided for @syncErrorMissingCredentials.
  ///
  /// In zh, this message translates to:
  /// **'请先配置云同步账号'**
  String get syncErrorMissingCredentials;

  /// No description provided for @syncErrorBackupNotFound.
  ///
  /// In zh, this message translates to:
  /// **'备份不存在'**
  String get syncErrorBackupNotFound;

  /// No description provided for @syncErrorMissingBackupSnapshot.
  ///
  /// In zh, this message translates to:
  /// **'备份快照缺失'**
  String get syncErrorMissingBackupSnapshot;

  /// No description provided for @syncErrorCannotDeleteCurrentBackup.
  ///
  /// In zh, this message translates to:
  /// **'不能删除当前备份'**
  String get syncErrorCannotDeleteCurrentBackup;

  /// No description provided for @syncErrorProviderNotReady.
  ///
  /// In zh, this message translates to:
  /// **'课表尚未就绪'**
  String get syncErrorProviderNotReady;

  /// Error shown when the WebDAV URL uses insecure HTTP protocol, which is blocked in release builds
  ///
  /// In zh, this message translates to:
  /// **'仅支持 HTTPS 加密连接，HTTP 明文协议已被禁用'**
  String get syncErrorInsecureUrl;

  /// No description provided for @syncErrorSyncFailed.
  ///
  /// In zh, this message translates to:
  /// **'同步失败'**
  String get syncErrorSyncFailed;

  /// No description provided for @sectionTimeDisplayHidden.
  ///
  /// In zh, this message translates to:
  /// **'不显示'**
  String get sectionTimeDisplayHidden;

  /// No description provided for @sectionTimeDisplayStartOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅显示上课时间'**
  String get sectionTimeDisplayStartOnly;

  /// No description provided for @sectionTimeDisplayStartAndEnd.
  ///
  /// In zh, this message translates to:
  /// **'显示上下课时间'**
  String get sectionTimeDisplayStartAndEnd;

  /// No description provided for @examReminderNone.
  ///
  /// In zh, this message translates to:
  /// **'不提醒'**
  String get examReminderNone;

  /// No description provided for @examReminderMin30.
  ///
  /// In zh, this message translates to:
  /// **'考前 30 分钟'**
  String get examReminderMin30;

  /// No description provided for @examReminderHour1.
  ///
  /// In zh, this message translates to:
  /// **'考前 1 小时'**
  String get examReminderHour1;

  /// No description provided for @examReminderHour1AndMin30.
  ///
  /// In zh, this message translates to:
  /// **'考前 1 小时 + 30 分钟'**
  String get examReminderHour1AndMin30;

  /// No description provided for @examReminderDay1.
  ///
  /// In zh, this message translates to:
  /// **'考前 1 天'**
  String get examReminderDay1;

  /// No description provided for @examReminderDay1AndHour1.
  ///
  /// In zh, this message translates to:
  /// **'考前 1 天 + 1 小时'**
  String get examReminderDay1AndHour1;

  /// No description provided for @examReminderCustom.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get examReminderCustom;

  /// No description provided for @examReminderOffsetMinutes.
  ///
  /// In zh, this message translates to:
  /// **'考前 {minutes} 分钟'**
  String examReminderOffsetMinutes(int minutes);

  /// No description provided for @examReminderOffsetHours.
  ///
  /// In zh, this message translates to:
  /// **'考前 {hours} 小时'**
  String examReminderOffsetHours(int hours);

  /// No description provided for @examReminderOffsetDays.
  ///
  /// In zh, this message translates to:
  /// **'考前 {days} 天'**
  String examReminderOffsetDays(int days);

  /// No description provided for @examReminderCustomEmpty.
  ///
  /// In zh, this message translates to:
  /// **'请至少选择一个提醒时间'**
  String get examReminderCustomEmpty;

  /// No description provided for @examReminderAddCustom.
  ///
  /// In zh, this message translates to:
  /// **'添加提醒'**
  String get examReminderAddCustom;

  /// No description provided for @examReminderAddCustomTitle.
  ///
  /// In zh, this message translates to:
  /// **'自定义提醒时间'**
  String get examReminderAddCustomTitle;

  /// No description provided for @examReminderAddCustomHint.
  ///
  /// In zh, this message translates to:
  /// **'设置距离考试开始前多久提醒，可添加多个'**
  String get examReminderAddCustomHint;

  /// No description provided for @examReminderPickerDays.
  ///
  /// In zh, this message translates to:
  /// **'天'**
  String get examReminderPickerDays;

  /// No description provided for @examReminderPickerHours.
  ///
  /// In zh, this message translates to:
  /// **'小时'**
  String get examReminderPickerHours;

  /// No description provided for @examReminderPickerMinutes.
  ///
  /// In zh, this message translates to:
  /// **'分钟'**
  String get examReminderPickerMinutes;

  /// No description provided for @examReminderCustomAlreadyAdded.
  ///
  /// In zh, this message translates to:
  /// **'该提醒时间已添加'**
  String get examReminderCustomAlreadyAdded;

  /// No description provided for @examReminderCustomInvalid.
  ///
  /// In zh, this message translates to:
  /// **'请设置大于 0 的提醒时间'**
  String get examReminderCustomInvalid;

  /// No description provided for @examReminderCustomEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'还没有自定义提醒，点下方添加'**
  String get examReminderCustomEmptyHint;

  /// No description provided for @debugCopiedJson.
  ///
  /// In zh, this message translates to:
  /// **'已复制 JSON'**
  String get debugCopiedJson;

  /// No description provided for @liveDuringClassTimeNearest.
  ///
  /// In zh, this message translates to:
  /// **'最近时间'**
  String get liveDuringClassTimeNearest;

  /// No description provided for @liveDuringClassTimeTotal.
  ///
  /// In zh, this message translates to:
  /// **'总时间'**
  String get liveDuringClassTimeTotal;

  /// No description provided for @liveCountdownTextStyleSmart.
  ///
  /// In zh, this message translates to:
  /// **'智能（中文）'**
  String get liveCountdownTextStyleSmart;

  /// No description provided for @liveCountdownTextStyleSmartMinS.
  ///
  /// In zh, this message translates to:
  /// **'智能（英文）'**
  String get liveCountdownTextStyleSmartMinS;

  /// No description provided for @liveCountdownTextStyleMinuteSecondCn.
  ///
  /// In zh, this message translates to:
  /// **'分秒（5分钟19秒）'**
  String get liveCountdownTextStyleMinuteSecondCn;

  /// No description provided for @liveCountdownTextStyleMinuteSecondColon.
  ///
  /// In zh, this message translates to:
  /// **'mm:ss（05:19）'**
  String get liveCountdownTextStyleMinuteSecondColon;

  /// No description provided for @liveCountdownTextStyleMinuteSecondMinS.
  ///
  /// In zh, this message translates to:
  /// **'min+s（5min19s）'**
  String get liveCountdownTextStyleMinuteSecondMinS;

  /// No description provided for @liveCountdownTextStyleMinuteSecondMinSlashS.
  ///
  /// In zh, this message translates to:
  /// **'min/s（5min/19s）'**
  String get liveCountdownTextStyleMinuteSecondMinSlashS;

  /// No description provided for @liveCountdownTextStyleMinuteOnlyCn.
  ///
  /// In zh, this message translates to:
  /// **'纯分钟（5分钟）'**
  String get liveCountdownTextStyleMinuteOnlyCn;

  /// No description provided for @liveCountdownTextStyleMinuteOnlyMin.
  ///
  /// In zh, this message translates to:
  /// **'min（5min）'**
  String get liveCountdownTextStyleMinuteOnlyMin;

  /// No description provided for @liveCountdownTextStyleMinuteOnlySlash.
  ///
  /// In zh, this message translates to:
  /// **'/min（5/min）'**
  String get liveCountdownTextStyleMinuteOnlySlash;

  /// No description provided for @liveCountdownTextStyleSecondOnlyCn.
  ///
  /// In zh, this message translates to:
  /// **'纯秒（5秒）'**
  String get liveCountdownTextStyleSecondOnlyCn;

  /// No description provided for @liveCountdownTextStyleSecondOnlyShort.
  ///
  /// In zh, this message translates to:
  /// **'s（5s）'**
  String get liveCountdownTextStyleSecondOnlyShort;

  /// No description provided for @liveCountdownTextStyleSecondOnlySlash.
  ///
  /// In zh, this message translates to:
  /// **'/s（5/s）'**
  String get liveCountdownTextStyleSecondOnlySlash;

  /// No description provided for @miuiIslandLabelStyleTextOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅文字'**
  String get miuiIslandLabelStyleTextOnly;

  /// No description provided for @miuiIslandLabelStyleIconAndText.
  ///
  /// In zh, this message translates to:
  /// **'图标+文字'**
  String get miuiIslandLabelStyleIconAndText;

  /// No description provided for @miuiIslandLabelContentCourseName.
  ///
  /// In zh, this message translates to:
  /// **'课程名'**
  String get miuiIslandLabelContentCourseName;

  /// No description provided for @miuiIslandLabelContentLocation.
  ///
  /// In zh, this message translates to:
  /// **'教室'**
  String get miuiIslandLabelContentLocation;

  /// No description provided for @miuiIslandLabelContentCourseNameAndLocation.
  ///
  /// In zh, this message translates to:
  /// **'课程名+教室'**
  String get miuiIslandLabelContentCourseNameAndLocation;

  /// No description provided for @miuiIslandLabelFontWeightRegular.
  ///
  /// In zh, this message translates to:
  /// **'常规'**
  String get miuiIslandLabelFontWeightRegular;

  /// No description provided for @miuiIslandLabelFontWeightMedium.
  ///
  /// In zh, this message translates to:
  /// **'中等'**
  String get miuiIslandLabelFontWeightMedium;

  /// No description provided for @miuiIslandLabelFontWeightBold.
  ///
  /// In zh, this message translates to:
  /// **'加粗'**
  String get miuiIslandLabelFontWeightBold;

  /// No description provided for @miuiIslandLabelRenderQualityStandard.
  ///
  /// In zh, this message translates to:
  /// **'标准'**
  String get miuiIslandLabelRenderQualityStandard;

  /// No description provided for @miuiIslandLabelRenderQualityHigh.
  ///
  /// In zh, this message translates to:
  /// **'高清'**
  String get miuiIslandLabelRenderQualityHigh;

  /// No description provided for @miuiIslandLabelRenderQualityUltra.
  ///
  /// In zh, this message translates to:
  /// **'超高清'**
  String get miuiIslandLabelRenderQualityUltra;

  /// No description provided for @miuiIslandExpandedIconAppIcon.
  ///
  /// In zh, this message translates to:
  /// **'应用图标'**
  String get miuiIslandExpandedIconAppIcon;

  /// No description provided for @miuiIslandExpandedIconCustomImage.
  ///
  /// In zh, this message translates to:
  /// **'自定义图片'**
  String get miuiIslandExpandedIconCustomImage;

  /// No description provided for @miuiIslandExpandedIconHidden.
  ///
  /// In zh, this message translates to:
  /// **'不显示'**
  String get miuiIslandExpandedIconHidden;

  /// No description provided for @liveBeforeClassQuickActionNone.
  ///
  /// In zh, this message translates to:
  /// **'不显示'**
  String get liveBeforeClassQuickActionNone;

  /// No description provided for @liveBeforeClassQuickActionSilent.
  ///
  /// In zh, this message translates to:
  /// **'打开静音'**
  String get liveBeforeClassQuickActionSilent;

  /// No description provided for @liveBeforeClassQuickActionDoNotDisturb.
  ///
  /// In zh, this message translates to:
  /// **'打开免打扰'**
  String get liveBeforeClassQuickActionDoNotDisturb;

  /// No description provided for @liveBeforeClassQuickActionBoth.
  ///
  /// In zh, this message translates to:
  /// **'静音和免打扰'**
  String get liveBeforeClassQuickActionBoth;

  /// No description provided for @courseCardVerticalAlignTop.
  ///
  /// In zh, this message translates to:
  /// **'顶部对齐'**
  String get courseCardVerticalAlignTop;

  /// No description provided for @courseCardVerticalAlignCenter.
  ///
  /// In zh, this message translates to:
  /// **'垂直居中'**
  String get courseCardVerticalAlignCenter;

  /// No description provided for @courseCardVerticalAlignBottom.
  ///
  /// In zh, this message translates to:
  /// **'底部对齐'**
  String get courseCardVerticalAlignBottom;

  /// No description provided for @courseCardVerticalAlignSpaceEvenly.
  ///
  /// In zh, this message translates to:
  /// **'上下均布'**
  String get courseCardVerticalAlignSpaceEvenly;

  /// No description provided for @courseCardHorizontalAlignLeft.
  ///
  /// In zh, this message translates to:
  /// **'居左'**
  String get courseCardHorizontalAlignLeft;

  /// No description provided for @courseCardHorizontalAlignCenter.
  ///
  /// In zh, this message translates to:
  /// **'居中'**
  String get courseCardHorizontalAlignCenter;

  /// No description provided for @courseCardHorizontalAlignRight.
  ///
  /// In zh, this message translates to:
  /// **'居右'**
  String get courseCardHorizontalAlignRight;

  /// No description provided for @timetableTimeColumnWidthNarrow.
  ///
  /// In zh, this message translates to:
  /// **'窄'**
  String get timetableTimeColumnWidthNarrow;

  /// No description provided for @timetableTimeColumnWidthWide.
  ///
  /// In zh, this message translates to:
  /// **'宽'**
  String get timetableTimeColumnWidthWide;

  /// No description provided for @timetableCourseSpacingNarrow.
  ///
  /// In zh, this message translates to:
  /// **'窄'**
  String get timetableCourseSpacingNarrow;

  /// No description provided for @timetableCourseSpacingWide.
  ///
  /// In zh, this message translates to:
  /// **'宽'**
  String get timetableCourseSpacingWide;

  /// No description provided for @appUpdateDownloadSourceOriginal.
  ///
  /// In zh, this message translates to:
  /// **'GitHub 原版'**
  String get appUpdateDownloadSourceOriginal;

  /// No description provided for @appUpdateDownloadSourceMirror.
  ///
  /// In zh, this message translates to:
  /// **'国内镜像'**
  String get appUpdateDownloadSourceMirror;

  /// No description provided for @appUpdateDownloadChannelPgyer.
  ///
  /// In zh, this message translates to:
  /// **'蒲公英下载'**
  String get appUpdateDownloadChannelPgyer;

  /// No description provided for @appUpdateDownloadChannelGithub.
  ///
  /// In zh, this message translates to:
  /// **'GitHub 下载'**
  String get appUpdateDownloadChannelGithub;

  /// No description provided for @appUpdateDownloadChannelPgyerDescription.
  ///
  /// In zh, this message translates to:
  /// **'国内高速下载，推荐使用'**
  String get appUpdateDownloadChannelPgyerDescription;

  /// No description provided for @appUpdateDownloadChannelGithubDescription.
  ///
  /// In zh, this message translates to:
  /// **'GitHub 原生 + 国内镜像'**
  String get appUpdateDownloadChannelGithubDescription;

  /// No description provided for @appUpdateDownloadChannelGitcode.
  ///
  /// In zh, this message translates to:
  /// **'GitCode 直连'**
  String get appUpdateDownloadChannelGitcode;

  /// No description provided for @appUpdateDownloadChannelGitcodeDescription.
  ///
  /// In zh, this message translates to:
  /// **'GitCode 发行版直连下载，国内速度快'**
  String get appUpdateDownloadChannelGitcodeDescription;

  /// No description provided for @holidayStatutoryLabel.
  ///
  /// In zh, this message translates to:
  /// **'法定节假日'**
  String get holidayStatutoryLabel;

  /// No description provided for @serviceMsgImportFileUnrecognized.
  ///
  /// In zh, this message translates to:
  /// **'导入失败，文件内容无法识别'**
  String get serviceMsgImportFileUnrecognized;

  /// No description provided for @serviceMsgImportUseOverwriteForFullBackup.
  ///
  /// In zh, this message translates to:
  /// **'这是全部数据备份，请使用“覆盖当前课表”方式导入'**
  String get serviceMsgImportUseOverwriteForFullBackup;

  /// No description provided for @serviceMsgImportNoProfilesInBackup.
  ///
  /// In zh, this message translates to:
  /// **'备份文件中没有可恢复的课表'**
  String get serviceMsgImportNoProfilesInBackup;

  /// No description provided for @serviceMsgUnrecognizedMikcbDataFile.
  ///
  /// In zh, this message translates to:
  /// **'不是可识别的 mikcb 数据文件'**
  String get serviceMsgUnrecognizedMikcbDataFile;

  /// No description provided for @serviceMsgMissingSettingsData.
  ///
  /// In zh, this message translates to:
  /// **'缺少设置数据'**
  String get serviceMsgMissingSettingsData;

  /// No description provided for @serviceMsgUnrecognizedMikcbFullBackup.
  ///
  /// In zh, this message translates to:
  /// **'不是可识别的 mikcb 全量备份文件'**
  String get serviceMsgUnrecognizedMikcbFullBackup;

  /// No description provided for @serviceMsgMissingFullBackupData.
  ///
  /// In zh, this message translates to:
  /// **'缺少完整备份数据'**
  String get serviceMsgMissingFullBackupData;

  /// No description provided for @serviceMsgUseProfileBackupNotFull.
  ///
  /// In zh, this message translates to:
  /// **'请使用课表档案备份 JSON，而非全部数据备份'**
  String get serviceMsgUseProfileBackupNotFull;

  /// No description provided for @serviceMsgUnrecognizedSyncSnapshot.
  ///
  /// In zh, this message translates to:
  /// **'不是可识别的 mikcb 云同步快照'**
  String get serviceMsgUnrecognizedSyncSnapshot;

  /// No description provided for @serviceMsgMissingSyncTimetableData.
  ///
  /// In zh, this message translates to:
  /// **'缺少云同步课表数据'**
  String get serviceMsgMissingSyncTimetableData;

  /// No description provided for @serviceMsgSyncSnapshotChecksumFailed.
  ///
  /// In zh, this message translates to:
  /// **'云同步快照校验失败'**
  String get serviceMsgSyncSnapshotChecksumFailed;

  /// No description provided for @serviceMsgSyncSnapshotNoProfiles.
  ///
  /// In zh, this message translates to:
  /// **'云同步快照中没有可恢复的课表'**
  String get serviceMsgSyncSnapshotNoProfiles;

  /// No description provided for @serviceMsgSyncSnapshotUnrecognized.
  ///
  /// In zh, this message translates to:
  /// **'云同步快照无法识别'**
  String get serviceMsgSyncSnapshotUnrecognized;

  /// No description provided for @serviceMsgTimeSchemeNotFound.
  ///
  /// In zh, this message translates to:
  /// **'时间模板不存在'**
  String get serviceMsgTimeSchemeNotFound;

  /// No description provided for @serviceMsgTimeSchemeConfigUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'当前课表时间配置不可用'**
  String get serviceMsgTimeSchemeConfigUnavailable;

  /// No description provided for @serviceMsgTimeSchemeNotFoundSelected.
  ///
  /// In zh, this message translates to:
  /// **'未找到所选时间模板'**
  String get serviceMsgTimeSchemeNotFoundSelected;

  /// No description provided for @serviceMsgTimeSchemeSectionsInsufficient.
  ///
  /// In zh, this message translates to:
  /// **'所选时间模板节次数不足，无法覆盖第 {startSection}-{endSection} 节'**
  String serviceMsgTimeSchemeSectionsInsufficient(
    int startSection,
    int endSection,
  );

  /// No description provided for @serviceMsgSectionCountBelowUsage.
  ///
  /// In zh, this message translates to:
  /// **'有课排到第{requiredMaxSection}节'**
  String serviceMsgSectionCountBelowUsage(int requiredMaxSection);

  /// No description provided for @serviceMsgSectionCountBelowUsageDetail.
  ///
  /// In zh, this message translates to:
  /// **'节次数量不能小于当前已使用的最大节次（第{requiredMaxSection}节），正在使用：{profileName} · {courseName}（周{dayOfWeek} {startSection}-{endSection}节，{usageType}）'**
  String serviceMsgSectionCountBelowUsageDetail(
    int requiredMaxSection,
    String profileName,
    String courseName,
    int dayOfWeek,
    int startSection,
    int endSection,
    String usageType,
  );

  /// No description provided for @serviceMsgAtLeastOneSectionRequired.
  ///
  /// In zh, this message translates to:
  /// **'至少需要保留一节课的时间'**
  String get serviceMsgAtLeastOneSectionRequired;

  /// No description provided for @serviceMsgSectionEndMustAfterStart.
  ///
  /// In zh, this message translates to:
  /// **'第 {sectionNumber} 节结束时间必须晚于开始时间，暂不支持跨 0 点课程'**
  String serviceMsgSectionEndMustAfterStart(int sectionNumber);

  /// No description provided for @serviceMsgSectionStartBeforePreviousEnd.
  ///
  /// In zh, this message translates to:
  /// **'第 {sectionNumber} 节开始时间不能早于上一节的结束时间'**
  String serviceMsgSectionStartBeforePreviousEnd(int sectionNumber);

  /// No description provided for @serviceMsgPeriodStartTimeRequired.
  ///
  /// In zh, this message translates to:
  /// **'请为有节次的时段设置第一节开始时间'**
  String get serviceMsgPeriodStartTimeRequired;

  /// No description provided for @serviceMsgSectionCrossesMidnight.
  ///
  /// In zh, this message translates to:
  /// **'第 {sectionNumber} 节会跨到次日，当前暂不支持跨 0 点课程'**
  String serviceMsgSectionCrossesMidnight(int sectionNumber);

  /// No description provided for @serviceMsgClassDurationMustPositive.
  ///
  /// In zh, this message translates to:
  /// **'上课时长必须大于 0'**
  String get serviceMsgClassDurationMustPositive;

  /// No description provided for @serviceMsgBreakDurationMustNonNegative.
  ///
  /// In zh, this message translates to:
  /// **'课间时长不能小于 0'**
  String get serviceMsgBreakDurationMustNonNegative;

  /// No description provided for @serviceMsgAtLeastOnePeriodSection.
  ///
  /// In zh, this message translates to:
  /// **'至少需要设置一个时段的节次数'**
  String get serviceMsgAtLeastOnePeriodSection;

  /// No description provided for @serviceMsgInvalidTimeFormat.
  ///
  /// In zh, this message translates to:
  /// **'时间格式不正确'**
  String get serviceMsgInvalidTimeFormat;

  /// No description provided for @serviceMsgLinkedCourseNotFound.
  ///
  /// In zh, this message translates to:
  /// **'关联的课程不存在'**
  String get serviceMsgLinkedCourseNotFound;

  /// No description provided for @serviceMsgCourseNotFoundForDelete.
  ///
  /// In zh, this message translates to:
  /// **'未找到要删除的课程'**
  String get serviceMsgCourseNotFoundForDelete;

  /// No description provided for @serviceMsgCourseNotScheduledWeek.
  ///
  /// In zh, this message translates to:
  /// **'这门课在第 {sourceWeek} 周没有排课'**
  String serviceMsgCourseNotScheduledWeek(int sourceWeek);

  /// No description provided for @serviceMsgCourseNotFoundForReschedule.
  ///
  /// In zh, this message translates to:
  /// **'未找到要调课的课程'**
  String get serviceMsgCourseNotFoundForReschedule;

  /// No description provided for @serviceMsgTargetWeekOutOfRange.
  ///
  /// In zh, this message translates to:
  /// **'目标周次超出当前学期范围'**
  String get serviceMsgTargetWeekOutOfRange;

  /// No description provided for @serviceMsgAtLeastOneScheduleSlot.
  ///
  /// In zh, this message translates to:
  /// **'至少需要保留一个上课时间段'**
  String get serviceMsgAtLeastOneScheduleSlot;

  /// No description provided for @serviceMsgCourseNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'课程名称不能为空'**
  String get serviceMsgCourseNameRequired;

  /// No description provided for @serviceMsgBackupContentRequired.
  ///
  /// In zh, this message translates to:
  /// **'备份内容不能为空'**
  String get serviceMsgBackupContentRequired;

  /// No description provided for @serviceMsgSpreadsheetFormatOrEncodingUnrecognized.
  ///
  /// In zh, this message translates to:
  /// **'无法识别表格格式或编码，请将 CSV 另存为 UTF-8 后重试'**
  String get serviceMsgSpreadsheetFormatOrEncodingUnrecognized;

  /// No description provided for @serviceMsgSpreadsheetXlsxParseFailed.
  ///
  /// In zh, this message translates to:
  /// **'XLSX 文件解析失败：{error}'**
  String serviceMsgSpreadsheetXlsxParseFailed(String error);

  /// No description provided for @serviceMsgSpreadsheetRowWarning.
  ///
  /// In zh, this message translates to:
  /// **'第 {rowNumber} 行：{message}'**
  String serviceMsgSpreadsheetRowWarning(int rowNumber, String message);

  /// No description provided for @serviceMsgSpreadsheetWakeupInsufficientColumns.
  ///
  /// In zh, this message translates to:
  /// **'WakeUp 格式需要至少 7 列，但第 {rowNumber} 行只有 {columnCount} 列'**
  String serviceMsgSpreadsheetWakeupInsufficientColumns(
    int rowNumber,
    int columnCount,
  );

  /// No description provided for @serviceMsgWeekdayMustBe1To7.
  ///
  /// In zh, this message translates to:
  /// **'星期必须是 1-7'**
  String get serviceMsgWeekdayMustBe1To7;

  /// No description provided for @serviceMsgCustomWeeksRequired.
  ///
  /// In zh, this message translates to:
  /// **'周数 不能为空'**
  String get serviceMsgCustomWeeksRequired;

  /// No description provided for @serviceMsgClassWeeksRequired.
  ///
  /// In zh, this message translates to:
  /// **'上课周 不能为空'**
  String get serviceMsgClassWeeksRequired;

  /// No description provided for @serviceMsgStartWeekMustBeAtLeast1.
  ///
  /// In zh, this message translates to:
  /// **'开始周 必须大于等于 1'**
  String get serviceMsgStartWeekMustBeAtLeast1;

  /// No description provided for @serviceMsgStartWeekExceedsSemester.
  ///
  /// In zh, this message translates to:
  /// **'开始周 {startWeek} 超过学期周数 {semesterWeekCount}'**
  String serviceMsgStartWeekExceedsSemester(
    int startWeek,
    int semesterWeekCount,
  );

  /// No description provided for @serviceMsgEndWeekBeforeStartWeek.
  ///
  /// In zh, this message translates to:
  /// **'结束周 不能小于开始周'**
  String get serviceMsgEndWeekBeforeStartWeek;

  /// No description provided for @serviceMsgWeeksRangeRequired.
  ///
  /// In zh, this message translates to:
  /// **'上课周 或 开始周+结束周 必须填写'**
  String get serviceMsgWeeksRangeRequired;

  /// No description provided for @serviceMsgFieldMustBeAtLeast1.
  ///
  /// In zh, this message translates to:
  /// **'{field} 必须大于等于 1'**
  String serviceMsgFieldMustBeAtLeast1(String field);

  /// No description provided for @serviceMsgFieldCannotBeLessThan.
  ///
  /// In zh, this message translates to:
  /// **'{endField} 不能小于{startField}'**
  String serviceMsgFieldCannotBeLessThan(String startField, String endField);

  /// No description provided for @serviceMsgSectionOutOfRange.
  ///
  /// In zh, this message translates to:
  /// **'节次 {section} 超出时间模板范围（1-{maxSection}）'**
  String serviceMsgSectionOutOfRange(int section, int maxSection);

  /// No description provided for @serviceMsgFieldMustBeInteger.
  ///
  /// In zh, this message translates to:
  /// **'{field} 必须是整数'**
  String serviceMsgFieldMustBeInteger(String field);

  /// No description provided for @serviceMsgFieldCannotBeEmpty.
  ///
  /// In zh, this message translates to:
  /// **'{field} 不能为空'**
  String serviceMsgFieldCannotBeEmpty(String field);

  /// No description provided for @serviceMsgSpreadsheetEndWeekClamped.
  ///
  /// In zh, this message translates to:
  /// **'第 {rowNumber} 行：结束周 {endWeek} 超过学期周数 {semesterWeekCount}，已调整为 {semesterWeekCount}'**
  String serviceMsgSpreadsheetEndWeekClamped(
    int rowNumber,
    int endWeek,
    int semesterWeekCount,
  );

  /// No description provided for @serviceMsgSpreadsheetOddEvenBoth.
  ///
  /// In zh, this message translates to:
  /// **'第 {rowNumber} 行：单周与双周不能同时勾选，已按单周处理'**
  String serviceMsgSpreadsheetOddEvenBoth(int rowNumber);

  /// No description provided for @serviceMsgFieldCourseName.
  ///
  /// In zh, this message translates to:
  /// **'课程名称'**
  String get serviceMsgFieldCourseName;

  /// No description provided for @serviceMsgFieldWeekday.
  ///
  /// In zh, this message translates to:
  /// **'星期'**
  String get serviceMsgFieldWeekday;

  /// No description provided for @serviceMsgFieldStartSection.
  ///
  /// In zh, this message translates to:
  /// **'开始节数'**
  String get serviceMsgFieldStartSection;

  /// No description provided for @serviceMsgFieldEndSection.
  ///
  /// In zh, this message translates to:
  /// **'结束节数'**
  String get serviceMsgFieldEndSection;

  /// No description provided for @serviceMsgFieldCustomWeeks.
  ///
  /// In zh, this message translates to:
  /// **'周数'**
  String get serviceMsgFieldCustomWeeks;

  /// No description provided for @serviceMsgFieldClassWeeks.
  ///
  /// In zh, this message translates to:
  /// **'上课周'**
  String get serviceMsgFieldClassWeeks;

  /// No description provided for @serviceMsgFieldStartWeek.
  ///
  /// In zh, this message translates to:
  /// **'开始周'**
  String get serviceMsgFieldStartWeek;

  /// No description provided for @serviceMsgFieldEndWeek.
  ///
  /// In zh, this message translates to:
  /// **'结束周'**
  String get serviceMsgFieldEndWeek;

  /// No description provided for @serviceMsgWeekStartInvalid.
  ///
  /// In zh, this message translates to:
  /// **'{itemName} 周次起始值不合法'**
  String serviceMsgWeekStartInvalid(String itemName);

  /// No description provided for @serviceMsgWeekRangeInvalid.
  ///
  /// In zh, this message translates to:
  /// **'{itemName} 周次范围不合法'**
  String serviceMsgWeekRangeInvalid(String itemName);

  /// No description provided for @serviceMsgWeekRangeTooLarge.
  ///
  /// In zh, this message translates to:
  /// **'{itemName} 周次范围过大，请检查'**
  String serviceMsgWeekRangeTooLarge(String itemName);

  /// No description provided for @serviceMsgWeekTokenUnrecognized.
  ///
  /// In zh, this message translates to:
  /// **'{itemName} 含有无法识别的周次：{token}'**
  String serviceMsgWeekTokenUnrecognized(String itemName, String token);

  /// No description provided for @serviceMsgWeeksExceedSemesterClamped.
  ///
  /// In zh, this message translates to:
  /// **'{itemName} 含有超过学期周数 {semesterWeekCount} 的周次（{weeks}），已忽略超出部分'**
  String serviceMsgWeeksExceedSemesterClamped(
    String itemName,
    int semesterWeekCount,
    String weeks,
  );

  /// No description provided for @serviceMsgAiResultNotObject.
  ///
  /// In zh, this message translates to:
  /// **'AI 结果不是合法对象，请重新复制完整 JSON'**
  String get serviceMsgAiResultNotObject;

  /// No description provided for @serviceMsgAiSchemaMustBe.
  ///
  /// In zh, this message translates to:
  /// **'schema 必须为 {schema}'**
  String serviceMsgAiSchemaMustBe(String schema);

  /// No description provided for @serviceMsgAiCoursesMustBeArray.
  ///
  /// In zh, this message translates to:
  /// **'courses 必须是数组'**
  String get serviceMsgAiCoursesMustBeArray;

  /// No description provided for @serviceMsgAiWarningsMustBeArray.
  ///
  /// In zh, this message translates to:
  /// **'warnings 必须是字符串数组'**
  String get serviceMsgAiWarningsMustBeArray;

  /// No description provided for @serviceMsgAiWarningItemMustBeString.
  ///
  /// In zh, this message translates to:
  /// **'warnings 中的每一项都必须是字符串'**
  String get serviceMsgAiWarningItemMustBeString;

  /// No description provided for @serviceMsgAiCourseNotObject.
  ///
  /// In zh, this message translates to:
  /// **'courses[{index}] 不是合法对象'**
  String serviceMsgAiCourseNotObject(int index);

  /// No description provided for @serviceMsgAiCourseNameEmpty.
  ///
  /// In zh, this message translates to:
  /// **'courses[{index}].name 不能为空'**
  String serviceMsgAiCourseNameEmpty(int index);

  /// No description provided for @serviceMsgAiCourseDayOfWeekInvalid.
  ///
  /// In zh, this message translates to:
  /// **'courses[{index}].dayOfWeek 必须是 1-7'**
  String serviceMsgAiCourseDayOfWeekInvalid(int index);

  /// No description provided for @serviceMsgAiCourseStartSectionInvalid.
  ///
  /// In zh, this message translates to:
  /// **'courses[{index}].startSection 必须大于等于 1'**
  String serviceMsgAiCourseStartSectionInvalid(int index);

  /// No description provided for @serviceMsgAiCourseEndSectionInvalid.
  ///
  /// In zh, this message translates to:
  /// **'courses[{index}].endSection 不能小于 startSection'**
  String serviceMsgAiCourseEndSectionInvalid(int index);

  /// No description provided for @serviceMsgAiCourseCustomWeeksEmpty.
  ///
  /// In zh, this message translates to:
  /// **'courses[{index}].customWeeks 不能为空'**
  String serviceMsgAiCourseCustomWeeksEmpty(int index);

  /// No description provided for @serviceMsgAiCourseNatureInvalid.
  ///
  /// In zh, this message translates to:
  /// **'courses[{index}].courseNature 只能是 required 或 elective'**
  String serviceMsgAiCourseNatureInvalid(int index);

  /// No description provided for @serviceMsgAiUnknownFields.
  ///
  /// In zh, this message translates to:
  /// **'{targetName} 包含不支持的字段：{fields}'**
  String serviceMsgAiUnknownFields(String targetName, String fields);

  /// No description provided for @serviceMsgAiFieldMustBeString.
  ///
  /// In zh, this message translates to:
  /// **'{field} 必须是字符串'**
  String serviceMsgAiFieldMustBeString(String field);

  /// No description provided for @serviceMsgAiFieldMustBeInteger.
  ///
  /// In zh, this message translates to:
  /// **'{field} 必须是整数'**
  String serviceMsgAiFieldMustBeInteger(String field);

  /// No description provided for @serviceMsgAiWeekListInvalid.
  ///
  /// In zh, this message translates to:
  /// **'{itemName} 只能包含大于等于 1 的整数'**
  String serviceMsgAiWeekListInvalid(String itemName);

  /// No description provided for @serviceMsgAiWeekListTypeInvalid.
  ///
  /// In zh, this message translates to:
  /// **'{field} 必须是整数数组或周次字符串'**
  String serviceMsgAiWeekListTypeInvalid(String field);

  /// No description provided for @serviceMsgNoReleaseAvailable.
  ///
  /// In zh, this message translates to:
  /// **'仓库还没有发布 Release'**
  String get serviceMsgNoReleaseAvailable;

  /// No description provided for @serviceMsgNoReleaseWithPrerelease.
  ///
  /// In zh, this message translates to:
  /// **'还没有可用的正式版或预发布版本'**
  String get serviceMsgNoReleaseWithPrerelease;

  /// No description provided for @serviceMsgUpdateCheckHttpFailed.
  ///
  /// In zh, this message translates to:
  /// **'检查更新失败（HTTP {statusCode}）'**
  String serviceMsgUpdateCheckHttpFailed(int statusCode);

  /// No description provided for @serviceMsgUpdateCheckNetworkFailed.
  ///
  /// In zh, this message translates to:
  /// **'网络异常，暂时无法检查更新'**
  String get serviceMsgUpdateCheckNetworkFailed;

  /// No description provided for @serviceMsgUpdateDownloadHashMismatch.
  ///
  /// In zh, this message translates to:
  /// **'安装包校验失败，为防止安装被篡改的文件已取消本次更新'**
  String get serviceMsgUpdateDownloadHashMismatch;

  /// No description provided for @serviceMsgUpdateSha256UnverifiedRefused.
  ///
  /// In zh, this message translates to:
  /// **'无法校验安装包完整性（缺少官方 SHA-256），已取消应用内更新，请前往发布页手动下载'**
  String get serviceMsgUpdateSha256UnverifiedRefused;

  /// No description provided for @serviceMsgUpdateDownloadUrlUntrusted.
  ///
  /// In zh, this message translates to:
  /// **'更新下载地址未通过安全校验'**
  String get serviceMsgUpdateDownloadUrlUntrusted;

  /// No description provided for @serviceMsgUpdateDownloadHttpFailed.
  ///
  /// In zh, this message translates to:
  /// **'下载失败（HTTP {statusCode}）'**
  String serviceMsgUpdateDownloadHttpFailed(int statusCode);

  /// No description provided for @serviceMsgUpdateOpenInstallerFailed.
  ///
  /// In zh, this message translates to:
  /// **'打开安装包失败: {detail}'**
  String serviceMsgUpdateOpenInstallerFailed(String detail);

  /// No description provided for @serviceMsgUpdateDownloadInstallError.
  ///
  /// In zh, this message translates to:
  /// **'下载或安装过程中出现错误: {detail}'**
  String serviceMsgUpdateDownloadInstallError(String detail);

  /// No description provided for @serviceMsgInvalidUrl.
  ///
  /// In zh, this message translates to:
  /// **'地址无效'**
  String get serviceMsgInvalidUrl;

  /// No description provided for @serviceMsgUpdateAvailablePrerelease.
  ///
  /// In zh, this message translates to:
  /// **'发现新的预发布版本'**
  String get serviceMsgUpdateAvailablePrerelease;

  /// No description provided for @serviceMsgUpdateAvailable.
  ///
  /// In zh, this message translates to:
  /// **'发现新版本'**
  String get serviceMsgUpdateAvailable;

  /// No description provided for @serviceMsgAlreadyLatest.
  ///
  /// In zh, this message translates to:
  /// **'当前已经是最新版本'**
  String get serviceMsgAlreadyLatest;

  /// No description provided for @serviceMsgShareBackupText.
  ///
  /// In zh, this message translates to:
  /// **'这是轻屿课表当前课表的完整备份文件，导入后可直接恢复课程和设置'**
  String get serviceMsgShareBackupText;

  /// No description provided for @serviceMsgShareBackupSubject.
  ///
  /// In zh, this message translates to:
  /// **'轻屿课表备份'**
  String get serviceMsgShareBackupSubject;

  /// No description provided for @serviceMsgShareBackupSubjectNamed.
  ///
  /// In zh, this message translates to:
  /// **'{profileName} - 轻屿课表备份'**
  String serviceMsgShareBackupSubjectNamed(String profileName);

  /// No description provided for @serviceMsgShareFullBackupText.
  ///
  /// In zh, this message translates to:
  /// **'这是轻屿课表的全部数据备份文件，包含所有课表、当前选中课表和时间模板'**
  String get serviceMsgShareFullBackupText;

  /// No description provided for @serviceMsgShareFullBackupSubject.
  ///
  /// In zh, this message translates to:
  /// **'轻屿课表 - 全部数据备份'**
  String get serviceMsgShareFullBackupSubject;

  /// No description provided for @serviceMsgInvalidRepositoryUrl.
  ///
  /// In zh, this message translates to:
  /// **'仓库地址格式不正确'**
  String get serviceMsgInvalidRepositoryUrl;

  /// No description provided for @serviceMsgIncompleteGithubRepoUrl.
  ///
  /// In zh, this message translates to:
  /// **'GitHub 仓库地址不完整'**
  String get serviceMsgIncompleteGithubRepoUrl;

  /// No description provided for @serviceMsgIncompleteRawGithubUrl.
  ///
  /// In zh, this message translates to:
  /// **'raw.githubusercontent.com 地址不完整'**
  String get serviceMsgIncompleteRawGithubUrl;

  /// No description provided for @serviceMsgGithubOnlySupported.
  ///
  /// In zh, this message translates to:
  /// **'当前只支持 GitHub 仓库地址'**
  String get serviceMsgGithubOnlySupported;

  /// No description provided for @serviceMsgWarehouseNoSchoolsIndex.
  ///
  /// In zh, this message translates to:
  /// **'未读取到任何学校或工具索引'**
  String get serviceMsgWarehouseNoSchoolsIndex;

  /// No description provided for @serviceMsgWarehouseNoAdapters.
  ///
  /// In zh, this message translates to:
  /// **'未读取到 {schoolName} 的适配器信息'**
  String serviceMsgWarehouseNoAdapters(String schoolName);

  /// No description provided for @serviceMsgWarehouseFetchFailedMirror.
  ///
  /// In zh, this message translates to:
  /// **'暂时无法读取适配仓，已尝试 {candidatesCount} 个镜像线路均失败，请检查网络，或到「版本更新」里切到其他镜像线路后重试'**
  String serviceMsgWarehouseFetchFailedMirror(int candidatesCount);

  /// No description provided for @serviceMsgWarehouseFetchFailedGithub.
  ///
  /// In zh, this message translates to:
  /// **'暂时无法读取适配仓，当前正在使用 GitHub 原始线路，请检查网络，或在「版本更新」里切到国内镜像后重试'**
  String get serviceMsgWarehouseFetchFailedGithub;

  /// No description provided for @serviceMsgWarehouseScriptChecksumFailed.
  ///
  /// In zh, this message translates to:
  /// **'适配器脚本完整性校验失败：下载内容与仓库声明的 SHA-256 不一致，已阻止执行。请刷新学校列表后重试；若反复出现，请到 qingyu_warehouse 反馈该适配器'**
  String get serviceMsgWarehouseScriptChecksumFailed;

  /// No description provided for @serviceMsgManualInputCaptcha.
  ///
  /// In zh, this message translates to:
  /// **'请手动输入验证码；完成后点击继续'**
  String get serviceMsgManualInputCaptcha;

  /// No description provided for @serviceMsgManualInputPassword.
  ///
  /// In zh, this message translates to:
  /// **'请手动输入密码；如已自动填充请直接继续'**
  String get serviceMsgManualInputPassword;

  /// No description provided for @serviceMsgMacroNoSteps.
  ///
  /// In zh, this message translates to:
  /// **'没有录制的步骤'**
  String get serviceMsgMacroNoSteps;

  /// No description provided for @serviceMsgMacroUserCancelled.
  ///
  /// In zh, this message translates to:
  /// **'用户取消'**
  String get serviceMsgMacroUserCancelled;

  /// No description provided for @serviceMsgMacroStepFailed.
  ///
  /// In zh, this message translates to:
  /// **'第 {stepIndex}/{totalSteps} 步失败: {detail}'**
  String serviceMsgMacroStepFailed(
    int stepIndex,
    int totalSteps,
    String detail,
  );

  /// No description provided for @serviceMsgMacroNavigateUrlEmpty.
  ///
  /// In zh, this message translates to:
  /// **'导航 URL 为空'**
  String get serviceMsgMacroNavigateUrlEmpty;

  /// No description provided for @serviceMsgMacroNavigateUrlInvalid.
  ///
  /// In zh, this message translates to:
  /// **'无效的 URL: {url}'**
  String serviceMsgMacroNavigateUrlInvalid(String url);

  /// No description provided for @serviceMsgMacroFillSelectorEmpty.
  ///
  /// In zh, this message translates to:
  /// **'填充字段的选择器为空'**
  String get serviceMsgMacroFillSelectorEmpty;

  /// No description provided for @serviceMsgMacroElementNotFound.
  ///
  /// In zh, this message translates to:
  /// **'未找到元素: {selector}'**
  String serviceMsgMacroElementNotFound(String selector);

  /// No description provided for @serviceMsgMacroClickSelectorEmpty.
  ///
  /// In zh, this message translates to:
  /// **'点击元素的选择器为空'**
  String get serviceMsgMacroClickSelectorEmpty;

  /// No description provided for @serviceMsgMacroUrlPatternEmpty.
  ///
  /// In zh, this message translates to:
  /// **'URL 模式为空'**
  String get serviceMsgMacroUrlPatternEmpty;

  /// No description provided for @serviceMsgMacroWaitSelectorEmpty.
  ///
  /// In zh, this message translates to:
  /// **'等待元素的选择器为空'**
  String get serviceMsgMacroWaitSelectorEmpty;

  /// No description provided for @serviceMsgMacroManualInputDefault.
  ///
  /// In zh, this message translates to:
  /// **'需要手动操作'**
  String get serviceMsgMacroManualInputDefault;

  /// No description provided for @serviceMsgMacroPollTimeout.
  ///
  /// In zh, this message translates to:
  /// **'{stepLabel} 超时（{timeoutSeconds}秒）{lastError}'**
  String serviceMsgMacroPollTimeout(
    String stepLabel,
    int timeoutSeconds,
    String lastError,
  );

  /// No description provided for @serviceMsgMacroReplayNavigate.
  ///
  /// In zh, this message translates to:
  /// **'正在导航...'**
  String get serviceMsgMacroReplayNavigate;

  /// No description provided for @serviceMsgMacroReplayFillField.
  ///
  /// In zh, this message translates to:
  /// **'正在填充表单...'**
  String get serviceMsgMacroReplayFillField;

  /// No description provided for @serviceMsgMacroReplayClick.
  ///
  /// In zh, this message translates to:
  /// **'正在点击...'**
  String get serviceMsgMacroReplayClick;

  /// No description provided for @serviceMsgMacroReplayWaitUrl.
  ///
  /// In zh, this message translates to:
  /// **'等待页面跳转...'**
  String get serviceMsgMacroReplayWaitUrl;

  /// No description provided for @serviceMsgMacroReplayWaitSelector.
  ///
  /// In zh, this message translates to:
  /// **'等待页面元素...'**
  String get serviceMsgMacroReplayWaitSelector;

  /// No description provided for @serviceMsgMacroReplayWaitManual.
  ///
  /// In zh, this message translates to:
  /// **'等待用户操作'**
  String get serviceMsgMacroReplayWaitManual;

  /// No description provided for @serviceMsgMacroReplayExecuteScript.
  ///
  /// In zh, this message translates to:
  /// **'正在执行导入脚本...'**
  String get serviceMsgMacroReplayExecuteScript;

  /// No description provided for @serviceMsgMacroReplayDelay.
  ///
  /// In zh, this message translates to:
  /// **'等待中...'**
  String get serviceMsgMacroReplayDelay;

  /// No description provided for @serviceMsgMacroReplayFailed.
  ///
  /// In zh, this message translates to:
  /// **'失败: {detail}'**
  String serviceMsgMacroReplayFailed(String detail);

  /// No description provided for @serviceMsgMacroReplayPaused.
  ///
  /// In zh, this message translates to:
  /// **'等待手动操作: {reason}'**
  String serviceMsgMacroReplayPaused(String reason);

  /// No description provided for @serviceMsgSupportDonorsLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载鸣谢名单失败：{detail}'**
  String serviceMsgSupportDonorsLoadFailed(String detail);

  /// No description provided for @serviceMsgStatisticsShareFailed.
  ///
  /// In zh, this message translates to:
  /// **'分享失败: {detail}'**
  String serviceMsgStatisticsShareFailed(String detail);

  /// No description provided for @serviceMsgAuthFailed.
  ///
  /// In zh, this message translates to:
  /// **'账号或密码错误'**
  String get serviceMsgAuthFailed;

  /// No description provided for @serviceMsgAccessDenied.
  ///
  /// In zh, this message translates to:
  /// **'没有访问权限'**
  String get serviceMsgAccessDenied;

  /// No description provided for @serviceMsgCertificateError.
  ///
  /// In zh, this message translates to:
  /// **'证书校验失败'**
  String get serviceMsgCertificateError;

  /// No description provided for @serviceMsgConnectionTimeout.
  ///
  /// In zh, this message translates to:
  /// **'连接超时'**
  String get serviceMsgConnectionTimeout;

  /// No description provided for @serviceMsgConnectionFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法连接服务器'**
  String get serviceMsgConnectionFailed;

  /// No description provided for @serviceMsgInvalidResponse.
  ///
  /// In zh, this message translates to:
  /// **'服务器响应无效'**
  String get serviceMsgInvalidResponse;

  /// No description provided for @serviceMsgSyncFailed.
  ///
  /// In zh, this message translates to:
  /// **'同步失败'**
  String get serviceMsgSyncFailed;

  /// No description provided for @serviceMsgUsageTypeOverride.
  ///
  /// In zh, this message translates to:
  /// **'副时间表'**
  String get serviceMsgUsageTypeOverride;

  /// No description provided for @serviceMsgUsageTypeProfile.
  ///
  /// In zh, this message translates to:
  /// **'课表主时间表'**
  String get serviceMsgUsageTypeProfile;

  /// No description provided for @dataTransferProfileShareText.
  ///
  /// In zh, this message translates to:
  /// **'这是轻屿课表当前课表的完整备份文件，导入后可直接恢复课程和设置'**
  String get dataTransferProfileShareText;

  /// No description provided for @dataTransferProfileShareSubject.
  ///
  /// In zh, this message translates to:
  /// **'轻屿课表备份'**
  String get dataTransferProfileShareSubject;

  /// No description provided for @dataTransferProfileShareSubjectNamed.
  ///
  /// In zh, this message translates to:
  /// **'{profileName} - 轻屿课表备份'**
  String dataTransferProfileShareSubjectNamed(String profileName);

  /// No description provided for @dataTransferFullBackupShareText.
  ///
  /// In zh, this message translates to:
  /// **'这是轻屿课表的全部数据备份文件，包含所有课表、当前选中课表和时间模板'**
  String get dataTransferFullBackupShareText;

  /// No description provided for @dataTransferFullBackupShareSubject.
  ///
  /// In zh, this message translates to:
  /// **'轻屿课表 - 全部数据备份'**
  String get dataTransferFullBackupShareSubject;

  /// No description provided for @courseWeekCustomDescription.
  ///
  /// In zh, this message translates to:
  /// **'第{weeks}周'**
  String courseWeekCustomDescription(String weeks);

  /// No description provided for @courseWeekRangeDescription.
  ///
  /// In zh, this message translates to:
  /// **'第{startWeek}-{endWeek}周{mode}'**
  String courseWeekRangeDescription(int startWeek, int endWeek, String mode);

  /// No description provided for @courseWeekOddModeSuffix.
  ///
  /// In zh, this message translates to:
  /// **' 单周'**
  String get courseWeekOddModeSuffix;

  /// No description provided for @courseWeekEvenModeSuffix.
  ///
  /// In zh, this message translates to:
  /// **' 双周'**
  String get courseWeekEvenModeSuffix;

  /// No description provided for @courseWeekSuspensionDescription.
  ///
  /// In zh, this message translates to:
  /// **'第{weeks}周停课'**
  String courseWeekSuspensionDescription(String weeks);

  /// No description provided for @courseWeekListSeparator.
  ///
  /// In zh, this message translates to:
  /// **'、'**
  String get courseWeekListSeparator;

  /// No description provided for @holidayLogMemoryCacheHit.
  ///
  /// In zh, this message translates to:
  /// **'{year}年：命中内存缓存（{count} 条），后台刷新中…'**
  String holidayLogMemoryCacheHit(int year, int count);

  /// No description provided for @holidayLogLocalCacheHit.
  ///
  /// In zh, this message translates to:
  /// **'{year}年：命中本地缓存（{count} 条），后台刷新中…'**
  String holidayLogLocalCacheHit(int year, int count);

  /// No description provided for @holidayLogNoCacheFetching.
  ///
  /// In zh, this message translates to:
  /// **'{year}年：无缓存，正在拉取远程数据…'**
  String holidayLogNoCacheFetching(int year);

  /// No description provided for @holidayLogRemoteSuccess.
  ///
  /// In zh, this message translates to:
  /// **'{year}年：远程拉取成功（{count} 条），已缓存'**
  String holidayLogRemoteSuccess(int year, int count);

  /// No description provided for @holidayLogRemoteFailedBuiltin.
  ///
  /// In zh, this message translates to:
  /// **'{year}年：远程拉取失败，使用内置资产兜底'**
  String holidayLogRemoteFailedBuiltin(int year);

  /// No description provided for @holidayLogBuiltinLoaded.
  ///
  /// In zh, this message translates to:
  /// **'{year}年：加载内置资产（{count} 条）'**
  String holidayLogBuiltinLoaded(int year, int count);

  /// No description provided for @holidayLogBackgroundSuccess.
  ///
  /// In zh, this message translates to:
  /// **'{year}年：后台更新成功（{count} 条），已覆盖缓存'**
  String holidayLogBackgroundSuccess(int year, int count);

  /// No description provided for @holidayLogBackgroundNoData.
  ///
  /// In zh, this message translates to:
  /// **'{year}年：后台更新未获取到新数据'**
  String holidayLogBackgroundNoData(int year);

  /// No description provided for @holidayLogPrimaryApiFailed.
  ///
  /// In zh, this message translates to:
  /// **'主 API 失败，尝试备用 API…'**
  String get holidayLogPrimaryApiFailed;

  /// No description provided for @holidayLogRequesting.
  ///
  /// In zh, this message translates to:
  /// **'正在请求 {uri} …'**
  String holidayLogRequesting(String uri);

  /// No description provided for @holidayLogPrimaryApiStatus.
  ///
  /// In zh, this message translates to:
  /// **'主 API 响应 {statusCode}，跳过'**
  String holidayLogPrimaryApiStatus(int statusCode);

  /// No description provided for @holidayLogPrimaryApiError.
  ///
  /// In zh, this message translates to:
  /// **'主 API 返回错误：{message}'**
  String holidayLogPrimaryApiError(String message);

  /// No description provided for @holidayLogPrimaryApiException.
  ///
  /// In zh, this message translates to:
  /// **'主 API 异常：{error}'**
  String holidayLogPrimaryApiException(String error);

  /// No description provided for @holidayLogPrimaryApiParsing.
  ///
  /// In zh, this message translates to:
  /// **'主 API 返回 {count} 条原始数据，正在解析…'**
  String holidayLogPrimaryApiParsing(int count);

  /// No description provided for @holidayLogNoValidEntries.
  ///
  /// In zh, this message translates to:
  /// **'解析后无有效条目，跳过'**
  String get holidayLogNoValidEntries;

  /// No description provided for @holidayLogFallbackApiStatus.
  ///
  /// In zh, this message translates to:
  /// **'备用 API 响应 {statusCode}，跳过'**
  String holidayLogFallbackApiStatus(int statusCode);

  /// No description provided for @holidayLogFallbackApiError.
  ///
  /// In zh, this message translates to:
  /// **'备用 API 返回错误'**
  String get holidayLogFallbackApiError;

  /// No description provided for @holidayLogFallbackApiParsing.
  ///
  /// In zh, this message translates to:
  /// **'备用 API 返回 {count} 条原始数据，正在解析…'**
  String holidayLogFallbackApiParsing(int count);

  /// No description provided for @holidayLogFallbackApiException.
  ///
  /// In zh, this message translates to:
  /// **'备用 API 异常：{error}'**
  String holidayLogFallbackApiException(String error);

  /// No description provided for @holidayNameNewYear.
  ///
  /// In zh, this message translates to:
  /// **'元旦'**
  String get holidayNameNewYear;

  /// No description provided for @holidayNameLaborDay.
  ///
  /// In zh, this message translates to:
  /// **'劳动节'**
  String get holidayNameLaborDay;

  /// No description provided for @holidayNameNationalDay.
  ///
  /// In zh, this message translates to:
  /// **'国庆节'**
  String get holidayNameNationalDay;

  /// No description provided for @holidayNameSpringFestival.
  ///
  /// In zh, this message translates to:
  /// **'春节'**
  String get holidayNameSpringFestival;

  /// No description provided for @holidayNameQingming.
  ///
  /// In zh, this message translates to:
  /// **'清明节'**
  String get holidayNameQingming;

  /// No description provided for @holidayNameDragonBoat.
  ///
  /// In zh, this message translates to:
  /// **'端午节'**
  String get holidayNameDragonBoat;

  /// No description provided for @holidayNameMidAutumn.
  ///
  /// In zh, this message translates to:
  /// **'中秋节'**
  String get holidayNameMidAutumn;

  /// No description provided for @macroReplayStatusFailed.
  ///
  /// In zh, this message translates to:
  /// **'失败: {error}'**
  String macroReplayStatusFailed(String error);

  /// No description provided for @macroReplayStatusPaused.
  ///
  /// In zh, this message translates to:
  /// **'等待手动操作: {reason}'**
  String macroReplayStatusPaused(String reason);

  /// No description provided for @macroReplayStepNavigating.
  ///
  /// In zh, this message translates to:
  /// **'正在导航...'**
  String get macroReplayStepNavigating;

  /// No description provided for @macroReplayStepFilling.
  ///
  /// In zh, this message translates to:
  /// **'正在填充表单...'**
  String get macroReplayStepFilling;

  /// No description provided for @macroReplayStepClicking.
  ///
  /// In zh, this message translates to:
  /// **'正在点击...'**
  String get macroReplayStepClicking;

  /// No description provided for @macroReplayStepWaitUrl.
  ///
  /// In zh, this message translates to:
  /// **'等待页面跳转...'**
  String get macroReplayStepWaitUrl;

  /// No description provided for @macroReplayStepWaitSelector.
  ///
  /// In zh, this message translates to:
  /// **'等待页面元素...'**
  String get macroReplayStepWaitSelector;

  /// No description provided for @macroReplayStepWaitManual.
  ///
  /// In zh, this message translates to:
  /// **'等待用户操作'**
  String get macroReplayStepWaitManual;

  /// No description provided for @macroReplayStepExecuteScript.
  ///
  /// In zh, this message translates to:
  /// **'正在执行导入脚本...'**
  String get macroReplayStepExecuteScript;

  /// No description provided for @macroReplayStepDelay.
  ///
  /// In zh, this message translates to:
  /// **'等待中...'**
  String get macroReplayStepDelay;

  /// No description provided for @macroReplayAcceleratedFallbackTip.
  ///
  /// In zh, this message translates to:
  /// **'快捷路径失败，正在使用完整录制步骤重试…'**
  String get macroReplayAcceleratedFallbackTip;

  /// No description provided for @macroReplayNoSteps.
  ///
  /// In zh, this message translates to:
  /// **'没有录制的步骤'**
  String get macroReplayNoSteps;

  /// No description provided for @macroReplayUserCancelled.
  ///
  /// In zh, this message translates to:
  /// **'用户取消'**
  String get macroReplayUserCancelled;

  /// No description provided for @macroReplayStepFailed.
  ///
  /// In zh, this message translates to:
  /// **'第 {current}/{total} 步失败: {error}'**
  String macroReplayStepFailed(int current, int total, String error);

  /// No description provided for @macroReplayEmptyNavigateUrl.
  ///
  /// In zh, this message translates to:
  /// **'导航 URL 为空'**
  String get macroReplayEmptyNavigateUrl;

  /// No description provided for @macroReplayInvalidUrl.
  ///
  /// In zh, this message translates to:
  /// **'无效的 URL: {url}'**
  String macroReplayInvalidUrl(String url);

  /// No description provided for @macroReplayEmptyFillSelector.
  ///
  /// In zh, this message translates to:
  /// **'填充字段的选择器为空'**
  String get macroReplayEmptyFillSelector;

  /// No description provided for @macroReplayFieldNotFound.
  ///
  /// In zh, this message translates to:
  /// **'未找到表单字段: {selector}'**
  String macroReplayFieldNotFound(String selector);

  /// No description provided for @macroReplayEmptyClickSelector.
  ///
  /// In zh, this message translates to:
  /// **'点击元素的选择器为空'**
  String get macroReplayEmptyClickSelector;

  /// No description provided for @macroReplayClickNotFound.
  ///
  /// In zh, this message translates to:
  /// **'未找到点击元素: {selector}'**
  String macroReplayClickNotFound(String selector);

  /// No description provided for @macroReplayWaitUrlPattern.
  ///
  /// In zh, this message translates to:
  /// **'等待 URL 匹配: {pattern}'**
  String macroReplayWaitUrlPattern(String pattern);

  /// No description provided for @macroReplayEmptyWaitSelector.
  ///
  /// In zh, this message translates to:
  /// **'等待元素的选择器为空'**
  String get macroReplayEmptyWaitSelector;

  /// No description provided for @macroReplayWaitSelector.
  ///
  /// In zh, this message translates to:
  /// **'等待元素: {selector}'**
  String macroReplayWaitSelector(String selector);

  /// No description provided for @macroReplayManualActionRequired.
  ///
  /// In zh, this message translates to:
  /// **'需要手动操作'**
  String get macroReplayManualActionRequired;

  /// No description provided for @macroReplayNavigateTo.
  ///
  /// In zh, this message translates to:
  /// **'导航到 {url}'**
  String macroReplayNavigateTo(String url);

  /// No description provided for @macroReplayWaitPageLoad.
  ///
  /// In zh, this message translates to:
  /// **'等待页面加载'**
  String get macroReplayWaitPageLoad;

  /// No description provided for @macroReplayWaitDomReady.
  ///
  /// In zh, this message translates to:
  /// **'等待 DOM 就绪'**
  String get macroReplayWaitDomReady;

  /// No description provided for @hyperosShowcaseTitle.
  ///
  /// In zh, this message translates to:
  /// **'澎湃 UI 组件库'**
  String get hyperosShowcaseTitle;

  /// No description provided for @hyperosShowcaseSectionSummary.
  ///
  /// In zh, this message translates to:
  /// **'概要卡片'**
  String get hyperosShowcaseSectionSummary;

  /// No description provided for @hyperosShowcaseKitSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'mikcb 澎湃风格组件一览'**
  String get hyperosShowcaseKitSubtitle;

  /// No description provided for @hyperosShowcaseSectionTags.
  ///
  /// In zh, this message translates to:
  /// **'标签 / 手风琴 / 提示'**
  String get hyperosShowcaseSectionTags;

  /// No description provided for @hyperosShowcaseAccordionSection1.
  ///
  /// In zh, this message translates to:
  /// **'第一节'**
  String get hyperosShowcaseAccordionSection1;

  /// No description provided for @hyperosShowcaseAccordionSection1Body.
  ///
  /// In zh, this message translates to:
  /// **'展开后显示的内容区域'**
  String get hyperosShowcaseAccordionSection1Body;

  /// No description provided for @hyperosShowcaseAccordionSection2.
  ///
  /// In zh, this message translates to:
  /// **'第二节'**
  String get hyperosShowcaseAccordionSection2;

  /// No description provided for @hyperosShowcaseAccordionSection2Body.
  ///
  /// In zh, this message translates to:
  /// **'可折叠分组，替代 FAccordion'**
  String get hyperosShowcaseAccordionSection2Body;

  /// No description provided for @hyperosShowcaseSectionNavRows.
  ///
  /// In zh, this message translates to:
  /// **'列表行 · 导航'**
  String get hyperosShowcaseSectionNavRows;

  /// No description provided for @hyperosShowcaseNavRowWithIcon.
  ///
  /// In zh, this message translates to:
  /// **'带图标'**
  String get hyperosShowcaseNavRowWithIcon;

  /// No description provided for @hyperosShowcaseNavRowNoIconSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'无左侧彩图标'**
  String get hyperosShowcaseNavRowNoIconSubtitle;

  /// No description provided for @hyperosShowcaseNavRowDetails.
  ///
  /// In zh, this message translates to:
  /// **'详情'**
  String get hyperosShowcaseNavRowDetails;

  /// No description provided for @hyperosShowcaseSectionSwitchRows.
  ///
  /// In zh, this message translates to:
  /// **'列表行 · 开关 / 危险'**
  String get hyperosShowcaseSectionSwitchRows;

  /// No description provided for @hyperosShowcaseSwitchRowSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'带图标开关行'**
  String get hyperosShowcaseSwitchRowSubtitle;

  /// No description provided for @hyperosShowcaseSwitchRowPlain.
  ///
  /// In zh, this message translates to:
  /// **'纯文字开关行'**
  String get hyperosShowcaseSwitchRowPlain;

  /// No description provided for @hyperosShowcaseSectionChoiceRows.
  ///
  /// In zh, this message translates to:
  /// **'列表行 · 单选 / 选择 / 日期'**
  String get hyperosShowcaseSectionChoiceRows;

  /// No description provided for @hyperosShowcaseOptionA.
  ///
  /// In zh, this message translates to:
  /// **'选项 A'**
  String get hyperosShowcaseOptionA;

  /// No description provided for @hyperosShowcaseOptionB.
  ///
  /// In zh, this message translates to:
  /// **'选项 B'**
  String get hyperosShowcaseOptionB;

  /// No description provided for @hyperosShowcaseOptionC.
  ///
  /// In zh, this message translates to:
  /// **'选项 C'**
  String get hyperosShowcaseOptionC;

  /// No description provided for @hyperosShowcaseSelectSizeTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择尺寸'**
  String get hyperosShowcaseSelectSizeTitle;

  /// No description provided for @hyperosShowcaseSizeSmall.
  ///
  /// In zh, this message translates to:
  /// **'小'**
  String get hyperosShowcaseSizeSmall;

  /// No description provided for @hyperosShowcaseSizeMedium.
  ///
  /// In zh, this message translates to:
  /// **'中'**
  String get hyperosShowcaseSizeMedium;

  /// No description provided for @hyperosShowcaseSizeLarge.
  ///
  /// In zh, this message translates to:
  /// **'大'**
  String get hyperosShowcaseSizeLarge;

  /// No description provided for @hyperosShowcaseSectionControls.
  ///
  /// In zh, this message translates to:
  /// **'控件卡片'**
  String get hyperosShowcaseSectionControls;

  /// No description provided for @hyperosShowcaseControlsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'滑条、分段、按钮'**
  String get hyperosShowcaseControlsSubtitle;

  /// No description provided for @hyperosShowcaseSegmentLeft.
  ///
  /// In zh, this message translates to:
  /// **'左'**
  String get hyperosShowcaseSegmentLeft;

  /// No description provided for @hyperosShowcaseSegmentRight.
  ///
  /// In zh, this message translates to:
  /// **'右'**
  String get hyperosShowcaseSegmentRight;

  /// No description provided for @hyperosShowcaseSectionInput.
  ///
  /// In zh, this message translates to:
  /// **'输入'**
  String get hyperosShowcaseSectionInput;

  /// No description provided for @hyperosShowcaseInputHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入内容'**
  String get hyperosShowcaseInputHint;

  /// No description provided for @hyperosShowcaseInputCardLabel.
  ///
  /// In zh, this message translates to:
  /// **'卡片内输入'**
  String get hyperosShowcaseInputCardLabel;

  /// No description provided for @hyperosShowcaseSectionPicker.
  ///
  /// In zh, this message translates to:
  /// **'滚轮选择器'**
  String get hyperosShowcaseSectionPicker;

  /// No description provided for @hyperosShowcasePickerCurrentValue.
  ///
  /// In zh, this message translates to:
  /// **'当前值：{value}'**
  String hyperosShowcasePickerCurrentValue(int value);

  /// No description provided for @hyperosShowcaseSectionInline.
  ///
  /// In zh, this message translates to:
  /// **'基础控件 · 行内'**
  String get hyperosShowcaseSectionInline;

  /// No description provided for @hyperosShowcaseCheckboxSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'多选偏好行'**
  String get hyperosShowcaseCheckboxSubtitle;

  /// No description provided for @hyperosShowcaseSectionNavActions.
  ///
  /// In zh, this message translates to:
  /// **'导航与操作'**
  String get hyperosShowcaseSectionNavActions;

  /// No description provided for @hyperosShowcaseTooltipButton.
  ///
  /// In zh, this message translates to:
  /// **'带 Tooltip 的按钮'**
  String get hyperosShowcaseTooltipButton;

  /// No description provided for @hyperosShowcaseSectionProgress.
  ///
  /// In zh, this message translates to:
  /// **'进度与刷新'**
  String get hyperosShowcaseSectionProgress;

  /// No description provided for @hyperosShowcaseSectionColorChip.
  ///
  /// In zh, this message translates to:
  /// **'颜色选择 · ColorChip'**
  String get hyperosShowcaseSectionColorChip;

  /// No description provided for @hyperosShowcaseSectionNavBar.
  ///
  /// In zh, this message translates to:
  /// **'底部导航 · HyperosNavigationBar'**
  String get hyperosShowcaseSectionNavBar;

  /// No description provided for @hyperosShowcaseNavHome.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get hyperosShowcaseNavHome;

  /// No description provided for @hyperosShowcaseNavTimetable.
  ///
  /// In zh, this message translates to:
  /// **'课表'**
  String get hyperosShowcaseNavTimetable;

  /// No description provided for @hyperosShowcaseNavSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get hyperosShowcaseNavSettings;

  /// No description provided for @hyperosShowcaseSectionEmpty.
  ///
  /// In zh, this message translates to:
  /// **'空态 / 分割线 / 装饰'**
  String get hyperosShowcaseSectionEmpty;

  /// No description provided for @hyperosShowcaseEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'列表无数据时的占位'**
  String get hyperosShowcaseEmptySubtitle;

  /// No description provided for @hyperosShowcaseActionButton.
  ///
  /// In zh, this message translates to:
  /// **'操作按钮'**
  String get hyperosShowcaseActionButton;

  /// No description provided for @hyperosShowcaseDividerRowTitle.
  ///
  /// In zh, this message translates to:
  /// **'第二行（上方有缩进分割线）'**
  String get hyperosShowcaseDividerRowTitle;

  /// No description provided for @hyperosShowcaseSectionPressable.
  ///
  /// In zh, this message translates to:
  /// **'底层行 · HyperosPressableRow'**
  String get hyperosShowcaseSectionPressable;

  /// No description provided for @hyperosShowcaseSectionShell.
  ///
  /// In zh, this message translates to:
  /// **'页面壳层'**
  String get hyperosShowcaseSectionShell;

  /// No description provided for @hyperosShowcaseRootPageDetails.
  ///
  /// In zh, this message translates to:
  /// **'无返回键根页'**
  String get hyperosShowcaseRootPageDetails;

  /// No description provided for @hyperosShowcaseSubpageSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'当前页即 Subpage + HyperosListView'**
  String get hyperosShowcaseSubpageSubtitle;

  /// No description provided for @hyperosShowcaseAlreadyInSubpage.
  ///
  /// In zh, this message translates to:
  /// **'已在 Subpage 中'**
  String get hyperosShowcaseAlreadyInSubpage;

  /// No description provided for @hyperosShowcaseSectionFrosted.
  ///
  /// In zh, this message translates to:
  /// **'模糊顶栏 · 滚动物理'**
  String get hyperosShowcaseSectionFrosted;

  /// No description provided for @hyperosShowcaseSectionFeedback.
  ///
  /// In zh, this message translates to:
  /// **'反馈 · 弹层'**
  String get hyperosShowcaseSectionFeedback;

  /// No description provided for @hyperosShowcaseSectionIconColors.
  ///
  /// In zh, this message translates to:
  /// **'主题色 · HyperosIconColors'**
  String get hyperosShowcaseSectionIconColors;

  /// No description provided for @hyperosShowcaseFooterNote.
  ///
  /// In zh, this message translates to:
  /// **'此页仅在非 Release 构建设置首页可见，用于组件视觉验收'**
  String get hyperosShowcaseFooterNote;

  /// No description provided for @hyperosShowcaseUndoAction.
  ///
  /// In zh, this message translates to:
  /// **'撤销'**
  String get hyperosShowcaseUndoAction;

  /// No description provided for @hyperosShowcaseDialogMessage.
  ///
  /// In zh, this message translates to:
  /// **'系统风格对话框示例'**
  String get hyperosShowcaseDialogMessage;

  /// No description provided for @hyperosShowcaseConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认操作'**
  String get hyperosShowcaseConfirmTitle;

  /// No description provided for @hyperosShowcaseConfirmed.
  ///
  /// In zh, this message translates to:
  /// **'已确认'**
  String get hyperosShowcaseConfirmed;

  /// No description provided for @hyperosShowcaseToastDescription.
  ///
  /// In zh, this message translates to:
  /// **'带图标与副标题，App Toast 同款'**
  String get hyperosShowcaseToastDescription;

  /// No description provided for @hyperosShowcaseMenuCopy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get hyperosShowcaseMenuCopy;

  /// No description provided for @hyperosShowcaseMenuShare.
  ///
  /// In zh, this message translates to:
  /// **'分享'**
  String get hyperosShowcaseMenuShare;

  /// No description provided for @hyperosShowcaseMenuDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get hyperosShowcaseMenuDelete;

  /// No description provided for @hyperosShowcaseRefreshDone.
  ///
  /// In zh, this message translates to:
  /// **'刷新完成'**
  String get hyperosShowcaseRefreshDone;

  /// No description provided for @hyperosShowcaseSearchTooltip.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get hyperosShowcaseSearchTooltip;

  /// No description provided for @hyperosShowcaseRootShellLabel.
  ///
  /// In zh, this message translates to:
  /// **'根页壳层'**
  String get hyperosShowcaseRootShellLabel;

  /// No description provided for @hyperosShowcasePushSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'通过 HyperosNavigation.push 进入'**
  String get hyperosShowcasePushSubtitle;

  /// No description provided for @hyperosShowcaseSampleText.
  ///
  /// In zh, this message translates to:
  /// **'示例文本'**
  String get hyperosShowcaseSampleText;

  /// No description provided for @courseImportQuickImportDescription.
  ///
  /// In zh, this message translates to:
  /// **'快捷导入 {schoolName} {adapterName}'**
  String courseImportQuickImportDescription(
    String schoolName,
    String adapterName,
  );

  /// No description provided for @courseImportScriptNoCourses.
  ///
  /// In zh, this message translates to:
  /// **'导入脚本未返回课程数据'**
  String get courseImportScriptNoCourses;

  /// No description provided for @courseImportScriptFailed.
  ///
  /// In zh, this message translates to:
  /// **'脚本执行失败'**
  String get courseImportScriptFailed;

  /// No description provided for @courseImportRecordingStatus.
  ///
  /// In zh, this message translates to:
  /// **'录制中…点击停止完成录制'**
  String get courseImportRecordingStatus;

  /// No description provided for @courseImportRecordingStartedTip.
  ///
  /// In zh, this message translates to:
  /// **'录制已开始，请按正常流程操作教务网站'**
  String get courseImportRecordingStartedTip;

  /// No description provided for @courseImportAutoRecordingStartedTip.
  ///
  /// In zh, this message translates to:
  /// **'已在后台记录操作，导入成功后可保存为快捷导入'**
  String get courseImportAutoRecordingStartedTip;

  /// No description provided for @courseImportRecordingEmptyStatus.
  ///
  /// In zh, this message translates to:
  /// **'未录制到任何操作'**
  String get courseImportRecordingEmptyStatus;

  /// No description provided for @courseImportRecordingEmptyTip.
  ///
  /// In zh, this message translates to:
  /// **'未录制到任何操作'**
  String get courseImportRecordingEmptyTip;

  /// No description provided for @courseImportSaveRecordingTitle.
  ///
  /// In zh, this message translates to:
  /// **'保存录制'**
  String get courseImportSaveRecordingTitle;

  /// No description provided for @courseImportSaveRecordingMessage.
  ///
  /// In zh, this message translates to:
  /// **'录制了 {count} 个操作步骤，是否保存为快捷导入？'**
  String courseImportSaveRecordingMessage(int count);

  /// No description provided for @courseImportSaveAutoRecordingMessage.
  ///
  /// In zh, this message translates to:
  /// **'导入成功。已记录 {count} 个操作步骤，是否保存本次导入路径，以便下次快捷导入？'**
  String courseImportSaveAutoRecordingMessage(int count);

  /// No description provided for @courseImportRecordingSavedStatus.
  ///
  /// In zh, this message translates to:
  /// **'录制已保存（{count} 步）'**
  String courseImportRecordingSavedStatus(int count);

  /// No description provided for @courseImportWeekNotProvided.
  ///
  /// In zh, this message translates to:
  /// **'未提供周次'**
  String get courseImportWeekNotProvided;

  /// No description provided for @courseImportLocationNotFilled.
  ///
  /// In zh, this message translates to:
  /// **'未填写地点'**
  String get courseImportLocationNotFilled;

  /// No description provided for @courseImportPreviewLine.
  ///
  /// In zh, this message translates to:
  /// **'周{weekday} 第{startSection}-{endSection}节  {name}  {location}  周次：{weekText}'**
  String courseImportPreviewLine(
    String weekday,
    int startSection,
    int endSection,
    String name,
    String location,
    String weekText,
  );

  /// No description provided for @courseImportCalendarWeekLabel.
  ///
  /// In zh, this message translates to:
  /// **'校历第 {week} 周'**
  String courseImportCalendarWeekLabel(int week);

  /// No description provided for @courseImportTermStartDateTitle.
  ///
  /// In zh, this message translates to:
  /// **'开学日期'**
  String get courseImportTermStartDateTitle;

  /// No description provided for @courseImportFirstWeekMappingLabel.
  ///
  /// In zh, this message translates to:
  /// **'课表第 1 周对应校历第几周'**
  String get courseImportFirstWeekMappingLabel;

  /// No description provided for @courseImportFirstWeekMappingSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'如果学校第一周没课，就选第 2 周；前两周都没课就选第 3 周'**
  String get courseImportFirstWeekMappingSubtitle;

  /// No description provided for @courseImportFirstWeekNoShift.
  ///
  /// In zh, this message translates to:
  /// **'导入后会直接把课表第 1 周当作校历第 1 周'**
  String get courseImportFirstWeekNoShift;

  /// No description provided for @courseImportFirstWeekShifted.
  ///
  /// In zh, this message translates to:
  /// **'导入后会把所有课程周次整体顺延 {weeks} 周，让课表第 1 周落在校历第 {targetWeek} 周'**
  String courseImportFirstWeekShifted(int weeks, int targetWeek);

  /// No description provided for @courseImportContinueAction.
  ///
  /// In zh, this message translates to:
  /// **'继续导入'**
  String get courseImportContinueAction;

  /// No description provided for @courseImportUpdateRecommendedAction.
  ///
  /// In zh, this message translates to:
  /// **'更新课表（推荐）'**
  String get courseImportUpdateRecommendedAction;

  /// No description provided for @courseImportOverwriteAction.
  ///
  /// In zh, this message translates to:
  /// **'覆盖导入'**
  String get courseImportOverwriteAction;

  /// No description provided for @courseImportSectionCountInsufficientTitle.
  ///
  /// In zh, this message translates to:
  /// **'时间模板节次不足'**
  String get courseImportSectionCountInsufficientTitle;

  /// No description provided for @courseImportSectionCountInsufficientMessage.
  ///
  /// In zh, this message translates to:
  /// **'当前课表时间模板只有 {current} 节，但导入数据需要到第 {required} 节，是否自动补齐后继续导入？'**
  String courseImportSectionCountInsufficientMessage(int current, int required);

  /// No description provided for @courseImportAutoFillAndImportAction.
  ///
  /// In zh, this message translates to:
  /// **'自动补齐并导入'**
  String get courseImportAutoFillAndImportAction;

  /// No description provided for @courseImportPortalUrlTitle.
  ///
  /// In zh, this message translates to:
  /// **'输入教务网址'**
  String get courseImportPortalUrlTitle;

  /// No description provided for @courseImportPortalUrlSaveContinue.
  ///
  /// In zh, this message translates to:
  /// **'保存并继续'**
  String get courseImportPortalUrlSaveContinue;

  /// No description provided for @courseImportPortalUrlLabel.
  ///
  /// In zh, this message translates to:
  /// **'教务网址'**
  String get courseImportPortalUrlLabel;

  /// No description provided for @courseImportPortalUrlHint.
  ///
  /// In zh, this message translates to:
  /// **'保存后下次会直接使用，也可以在适配器信息页里修改'**
  String get courseImportPortalUrlHint;

  /// No description provided for @courseImportPortalUrlInvalid.
  ///
  /// In zh, this message translates to:
  /// **'登录地址格式不正确'**
  String get courseImportPortalUrlInvalid;

  /// No description provided for @logAppLoggerInitialized.
  ///
  /// In zh, this message translates to:
  /// **'应用日志服务已初始化'**
  String get logAppLoggerInitialized;

  /// No description provided for @logPrivacyConsentUpdated.
  ///
  /// In zh, this message translates to:
  /// **'隐私协议同意状态已更新'**
  String get logPrivacyConsentUpdated;

  /// No description provided for @logAppLogRecordingEnabled.
  ///
  /// In zh, this message translates to:
  /// **'应用日志记录已开启'**
  String get logAppLogRecordingEnabled;

  /// No description provided for @logAppLogRecordingRemainsEnabled.
  ///
  /// In zh, this message translates to:
  /// **'应用日志记录保持开启'**
  String get logAppLogRecordingRemainsEnabled;

  /// No description provided for @logStartupFlowStarted.
  ///
  /// In zh, this message translates to:
  /// **'启动流程处理已开始'**
  String get logStartupFlowStarted;

  /// No description provided for @logStartupFlowCompletedNoOnboarding.
  ///
  /// In zh, this message translates to:
  /// **'启动流程已完成（无需引导页）'**
  String get logStartupFlowCompletedNoOnboarding;

  /// No description provided for @logStartupFlowCompletedAfterGuide.
  ///
  /// In zh, this message translates to:
  /// **'启动流程已完成（经过引导页）'**
  String get logStartupFlowCompletedAfterGuide;

  /// No description provided for @logStartupFlowFailed.
  ///
  /// In zh, this message translates to:
  /// **'启动流程失败，进入降级模式'**
  String get logStartupFlowFailed;

  /// No description provided for @logAppLifecycleChanged.
  ///
  /// In zh, this message translates to:
  /// **'应用生命周期已变更'**
  String get logAppLifecycleChanged;

  /// No description provided for @logNavigatorRouteReplaced.
  ///
  /// In zh, this message translates to:
  /// **'导航路由已替换'**
  String get logNavigatorRouteReplaced;

  /// No description provided for @logNavigatorRouteChanged.
  ///
  /// In zh, this message translates to:
  /// **'导航路由已变更'**
  String get logNavigatorRouteChanged;

  /// No description provided for @logAppLogsDefaultMigrated.
  ///
  /// In zh, this message translates to:
  /// **'迁移时已默认开启应用日志记录'**
  String get logAppLogsDefaultMigrated;

  /// No description provided for @logTimetableLoadSettingsFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载课表设置失败'**
  String get logTimetableLoadSettingsFailed;

  /// No description provided for @logTimetableLoadCoursesFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载课程数据失败'**
  String get logTimetableLoadCoursesFailed;

  /// No description provided for @logTimetableLoadCurrentWeekFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载当前周次失败'**
  String get logTimetableLoadCurrentWeekFailed;

  /// No description provided for @logHomeWidgetPinSupportFailed.
  ///
  /// In zh, this message translates to:
  /// **'检查桌面小组件固定支持失败'**
  String get logHomeWidgetPinSupportFailed;

  /// No description provided for @logHomeWidgetPinRequestFailed.
  ///
  /// In zh, this message translates to:
  /// **'请求固定桌面小组件失败'**
  String get logHomeWidgetPinRequestFailed;

  /// No description provided for @logHomeWidgetSyncFailed.
  ///
  /// In zh, this message translates to:
  /// **'同步桌面小组件快照失败'**
  String get logHomeWidgetSyncFailed;

  /// No description provided for @logHomeWidgetClearFailed.
  ///
  /// In zh, this message translates to:
  /// **'清空桌面小组件快照失败'**
  String get logHomeWidgetClearFailed;

  /// No description provided for @logHomeWidgetScheduleFailed.
  ///
  /// In zh, this message translates to:
  /// **'调度桌面小组件刷新失败'**
  String get logHomeWidgetScheduleFailed;

  /// No description provided for @logHomeWidgetExactAlarmCheckFailed.
  ///
  /// In zh, this message translates to:
  /// **'检查精确闹钟权限失败'**
  String get logHomeWidgetExactAlarmCheckFailed;

  /// No description provided for @logHomeWidgetExactAlarmRequestFailed.
  ///
  /// In zh, this message translates to:
  /// **'请求精确闹钟授权失败'**
  String get logHomeWidgetExactAlarmRequestFailed;

  /// No description provided for @logMiuiLiveInitializeFailed.
  ///
  /// In zh, this message translates to:
  /// **'初始化 MIUI 超级岛通道失败'**
  String get logMiuiLiveInitializeFailed;

  /// No description provided for @logMiuiLiveOpenPromotedSettingsFailed.
  ///
  /// In zh, this message translates to:
  /// **'打开超级岛权限设置失败'**
  String get logMiuiLiveOpenPromotedSettingsFailed;

  /// No description provided for @logMiuiLiveOpenNotificationSettingsFailed.
  ///
  /// In zh, this message translates to:
  /// **'打开通知设置失败'**
  String get logMiuiLiveOpenNotificationSettingsFailed;

  /// No description provided for @logMiuiLiveOpenAutostartSettingsFailed.
  ///
  /// In zh, this message translates to:
  /// **'打开自启动设置失败'**
  String get logMiuiLiveOpenAutostartSettingsFailed;

  /// No description provided for @logMiuiLiveOpenBatterySettingsFailed.
  ///
  /// In zh, this message translates to:
  /// **'打开电池优化设置失败'**
  String get logMiuiLiveOpenBatterySettingsFailed;

  /// No description provided for @logMiuiLiveOpenAccessibilitySettingsFailed.
  ///
  /// In zh, this message translates to:
  /// **'打开无障碍设置失败'**
  String get logMiuiLiveOpenAccessibilitySettingsFailed;

  /// No description provided for @logMiuiLiveHideFromRecentsFailed.
  ///
  /// In zh, this message translates to:
  /// **'更新「从最近任务隐藏」失败'**
  String get logMiuiLiveHideFromRecentsFailed;

  /// No description provided for @logLiveUpdateStartFailed.
  ///
  /// In zh, this message translates to:
  /// **'从 Flutter 启动超级岛失败'**
  String get logLiveUpdateStartFailed;

  /// No description provided for @logLiveUpdateStopFailed.
  ///
  /// In zh, this message translates to:
  /// **'从 Flutter 停止超级岛失败'**
  String get logLiveUpdateStopFailed;

  /// No description provided for @logLiveUpdateDebugStatusFailed.
  ///
  /// In zh, this message translates to:
  /// **'获取原生超级岛调试状态失败'**
  String get logLiveUpdateDebugStatusFailed;

  /// No description provided for @logLiveUpdateSnapshotSyncFailed.
  ///
  /// In zh, this message translates to:
  /// **'同步超级岛课表快照失败'**
  String get logLiveUpdateSnapshotSyncFailed;

  /// No description provided for @logLiveUpdateSnapshotClearFailed.
  ///
  /// In zh, this message translates to:
  /// **'清空超级岛课表快照失败'**
  String get logLiveUpdateSnapshotClearFailed;

  /// No description provided for @logLiveUpdateSuspendTriggersFailed.
  ///
  /// In zh, this message translates to:
  /// **'挂起超级岛课表调度失败'**
  String get logLiveUpdateSuspendTriggersFailed;

  /// No description provided for @logLanEditAuthFailed.
  ///
  /// In zh, this message translates to:
  /// **'局域网编辑：认证失败'**
  String get logLanEditAuthFailed;

  /// No description provided for @logLanEditCourseCreated.
  ///
  /// In zh, this message translates to:
  /// **'局域网编辑：已创建课程'**
  String get logLanEditCourseCreated;

  /// No description provided for @logLanEditCourseUpdated.
  ///
  /// In zh, this message translates to:
  /// **'局域网编辑：已更新课程'**
  String get logLanEditCourseUpdated;

  /// No description provided for @logLanEditCourseDeleted.
  ///
  /// In zh, this message translates to:
  /// **'局域网编辑：已删除课程'**
  String get logLanEditCourseDeleted;

  /// No description provided for @logLanEditCourseGroupSaved.
  ///
  /// In zh, this message translates to:
  /// **'局域网编辑：已保存课程组'**
  String get logLanEditCourseGroupSaved;

  /// No description provided for @logLanEditMergeImported.
  ///
  /// In zh, this message translates to:
  /// **'局域网编辑：已导入合并备份'**
  String get logLanEditMergeImported;

  /// No description provided for @logLanEditCoursesBatchDeleted.
  ///
  /// In zh, this message translates to:
  /// **'局域网编辑：已批量删除课程'**
  String get logLanEditCoursesBatchDeleted;

  /// No description provided for @logLanEditCurrentWeekSet.
  ///
  /// In zh, this message translates to:
  /// **'局域网编辑：已设置当前周次'**
  String get logLanEditCurrentWeekSet;

  /// No description provided for @logLanEditProfileSwitched.
  ///
  /// In zh, this message translates to:
  /// **'局域网编辑：已切换课表'**
  String get logLanEditProfileSwitched;

  /// No description provided for @logLanEditSpreadsheetImported.
  ///
  /// In zh, this message translates to:
  /// **'局域网编辑：已导入表格'**
  String get logLanEditSpreadsheetImported;

  /// No description provided for @logLanEditSessionStarted.
  ///
  /// In zh, this message translates to:
  /// **'局域网编辑：会话已启动'**
  String get logLanEditSessionStarted;

  /// No description provided for @logLanEditSessionStopped.
  ///
  /// In zh, this message translates to:
  /// **'局域网编辑：会话已停止'**
  String get logLanEditSessionStopped;

  /// No description provided for @logLiveUpdateTestRequested.
  ///
  /// In zh, this message translates to:
  /// **'用户请求手动超级岛测试通知'**
  String get logLiveUpdateTestRequested;

  /// No description provided for @logLiveUpdateTestNoSelection.
  ///
  /// In zh, this message translates to:
  /// **'手动超级岛测试：未找到可用课程'**
  String get logLiveUpdateTestNoSelection;

  /// No description provided for @logLiveUpdateTestSelectionReady.
  ///
  /// In zh, this message translates to:
  /// **'手动超级岛测试：已解析目标课程'**
  String get logLiveUpdateTestSelectionReady;

  /// No description provided for @logLiveUpdateTestSuspendSync.
  ///
  /// In zh, this message translates to:
  /// **'手动超级岛测试：已临时暂停定时同步'**
  String get logLiveUpdateTestSuspendSync;

  /// No description provided for @logLiveUpdateTestStarting.
  ///
  /// In zh, this message translates to:
  /// **'手动超级岛测试：正在启动原生超级岛'**
  String get logLiveUpdateTestStarting;

  /// No description provided for @logLiveUpdateTestStarted.
  ///
  /// In zh, this message translates to:
  /// **'手动超级岛测试：已成功请求原生超级岛'**
  String get logLiveUpdateTestStarted;

  /// No description provided for @logLiveUpdateTestFailed.
  ///
  /// In zh, this message translates to:
  /// **'手动超级岛测试：原生超级岛出现前失败'**
  String get logLiveUpdateTestFailed;

  /// No description provided for @logLiveUpdateSettingsSynced.
  ///
  /// In zh, this message translates to:
  /// **'Flutter 超级岛设置已同步：课前={beforeClass}，课中={duringClass}，下课前={beforeEnd}，提升={promote}，通知={notification}，倒计时={countdown}，课程名={courseName}，地点={location}'**
  String logLiveUpdateSettingsSynced(
    String beforeClass,
    String duringClass,
    String beforeEnd,
    String promote,
    String notification,
    String countdown,
    String courseName,
    String location,
  );

  /// No description provided for @logFieldSource.
  ///
  /// In zh, this message translates to:
  /// **'来源'**
  String get logFieldSource;

  /// No description provided for @logFieldPlatform.
  ///
  /// In zh, this message translates to:
  /// **'平台'**
  String get logFieldPlatform;

  /// No description provided for @logFieldVersion.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get logFieldVersion;

  /// No description provided for @logFieldBuildNumber.
  ///
  /// In zh, this message translates to:
  /// **'构建号'**
  String get logFieldBuildNumber;

  /// No description provided for @logFieldLoggingEnabled.
  ///
  /// In zh, this message translates to:
  /// **'日志记录'**
  String get logFieldLoggingEnabled;

  /// No description provided for @logFieldPrivacyAccepted.
  ///
  /// In zh, this message translates to:
  /// **'隐私协议'**
  String get logFieldPrivacyAccepted;

  /// No description provided for @logFieldAccepted.
  ///
  /// In zh, this message translates to:
  /// **'已同意'**
  String get logFieldAccepted;

  /// No description provided for @logFieldPrevious.
  ///
  /// In zh, this message translates to:
  /// **'先前状态'**
  String get logFieldPrevious;

  /// No description provided for @logFieldTruncated.
  ///
  /// In zh, this message translates to:
  /// **'已截断'**
  String get logFieldTruncated;

  /// No description provided for @logFieldTruncatedHint.
  ///
  /// In zh, this message translates to:
  /// **'截断提示'**
  String get logFieldTruncatedHint;

  /// No description provided for @logFieldThrowable.
  ///
  /// In zh, this message translates to:
  /// **'异常'**
  String get logFieldThrowable;

  /// No description provided for @logFieldExtras.
  ///
  /// In zh, this message translates to:
  /// **'附加信息'**
  String get logFieldExtras;

  /// No description provided for @logFieldContext.
  ///
  /// In zh, this message translates to:
  /// **'设备上下文'**
  String get logFieldContext;

  /// No description provided for @logFieldError.
  ///
  /// In zh, this message translates to:
  /// **'错误'**
  String get logFieldError;

  /// No description provided for @logFieldBrand.
  ///
  /// In zh, this message translates to:
  /// **'品牌'**
  String get logFieldBrand;

  /// No description provided for @logFieldManufacturer.
  ///
  /// In zh, this message translates to:
  /// **'制造商'**
  String get logFieldManufacturer;

  /// No description provided for @logFieldModel.
  ///
  /// In zh, this message translates to:
  /// **'型号'**
  String get logFieldModel;

  /// No description provided for @logFieldSdkInt.
  ///
  /// In zh, this message translates to:
  /// **'SDK 版本'**
  String get logFieldSdkInt;

  /// No description provided for @logFieldVersionName.
  ///
  /// In zh, this message translates to:
  /// **'版本名'**
  String get logFieldVersionName;

  /// No description provided for @logFieldChannel.
  ///
  /// In zh, this message translates to:
  /// **'渠道'**
  String get logFieldChannel;

  /// No description provided for @logFieldHasNotificationPermission.
  ///
  /// In zh, this message translates to:
  /// **'通知权限'**
  String get logFieldHasNotificationPermission;

  /// No description provided for @logFieldHasPromotedPermissionDeclared.
  ///
  /// In zh, this message translates to:
  /// **'已声明提升通知权限'**
  String get logFieldHasPromotedPermissionDeclared;

  /// No description provided for @logFieldCanPostPromotedNotifications.
  ///
  /// In zh, this message translates to:
  /// **'可发布提升通知'**
  String get logFieldCanPostPromotedNotifications;

  /// No description provided for @logFieldIgnoringBatteryOptimizations.
  ///
  /// In zh, this message translates to:
  /// **'忽略电池优化'**
  String get logFieldIgnoringBatteryOptimizations;

  /// No description provided for @logFieldKeepAliveAccessibilityEnabled.
  ///
  /// In zh, this message translates to:
  /// **'无障碍保活已启用'**
  String get logFieldKeepAliveAccessibilityEnabled;

  /// No description provided for @logFieldHideFromRecentsEnabled.
  ///
  /// In zh, this message translates to:
  /// **'从最近任务隐藏'**
  String get logFieldHideFromRecentsEnabled;

  /// No description provided for @logFieldTaskRemovedRecently.
  ///
  /// In zh, this message translates to:
  /// **'近期任务被移除'**
  String get logFieldTaskRemovedRecently;

  /// No description provided for @logFieldLastTaskRemovedAt.
  ///
  /// In zh, this message translates to:
  /// **'上次任务移除时间'**
  String get logFieldLastTaskRemovedAt;

  /// No description provided for @logFieldProcessImportance.
  ///
  /// In zh, this message translates to:
  /// **'进程重要性'**
  String get logFieldProcessImportance;

  /// No description provided for @logFieldAutoStartStatus.
  ///
  /// In zh, this message translates to:
  /// **'自启动状态'**
  String get logFieldAutoStartStatus;

  /// No description provided for @logFieldLiveEnableBeforeClass.
  ///
  /// In zh, this message translates to:
  /// **'课前超级岛'**
  String get logFieldLiveEnableBeforeClass;

  /// No description provided for @logFieldLiveEnableDuringClass.
  ///
  /// In zh, this message translates to:
  /// **'课中超级岛'**
  String get logFieldLiveEnableDuringClass;

  /// No description provided for @logFieldLiveEnableBeforeEnd.
  ///
  /// In zh, this message translates to:
  /// **'下课前超级岛'**
  String get logFieldLiveEnableBeforeEnd;

  /// No description provided for @logFieldLivePromoteDuringClass.
  ///
  /// In zh, this message translates to:
  /// **'课中提升通知'**
  String get logFieldLivePromoteDuringClass;

  /// No description provided for @logFieldLiveShowDuringClassNotification.
  ///
  /// In zh, this message translates to:
  /// **'课中状态栏通知'**
  String get logFieldLiveShowDuringClassNotification;

  /// No description provided for @logFieldLiveShowCountdown.
  ///
  /// In zh, this message translates to:
  /// **'显示倒计时'**
  String get logFieldLiveShowCountdown;

  /// No description provided for @logFieldLiveShowStageText.
  ///
  /// In zh, this message translates to:
  /// **'显示阶段文字'**
  String get logFieldLiveShowStageText;

  /// No description provided for @logFieldLiveShowCourseName.
  ///
  /// In zh, this message translates to:
  /// **'显示课程名'**
  String get logFieldLiveShowCourseName;

  /// No description provided for @logFieldLiveShowLocation.
  ///
  /// In zh, this message translates to:
  /// **'显示地点'**
  String get logFieldLiveShowLocation;

  /// No description provided for @logFieldLiveUseShortName.
  ///
  /// In zh, this message translates to:
  /// **'使用简称'**
  String get logFieldLiveUseShortName;

  /// No description provided for @logFieldLiveHidePrefixText.
  ///
  /// In zh, this message translates to:
  /// **'隐藏前缀文字'**
  String get logFieldLiveHidePrefixText;

  /// No description provided for @logFieldLiveDuringClassTimeDisplayMode.
  ///
  /// In zh, this message translates to:
  /// **'课中时间显示模式'**
  String get logFieldLiveDuringClassTimeDisplayMode;

  /// No description provided for @logFieldLiveEnableMiuiIslandLabelImage.
  ///
  /// In zh, this message translates to:
  /// **'岛标签图片'**
  String get logFieldLiveEnableMiuiIslandLabelImage;

  /// No description provided for @logFieldLiveMiuiIslandLabelStyle.
  ///
  /// In zh, this message translates to:
  /// **'岛标签样式'**
  String get logFieldLiveMiuiIslandLabelStyle;

  /// No description provided for @logFieldLiveMiuiIslandLabelContent.
  ///
  /// In zh, this message translates to:
  /// **'岛标签内容'**
  String get logFieldLiveMiuiIslandLabelContent;

  /// No description provided for @logFieldLiveMiuiIslandLabelFontColor.
  ///
  /// In zh, this message translates to:
  /// **'岛标签字体颜色'**
  String get logFieldLiveMiuiIslandLabelFontColor;

  /// No description provided for @logFieldLiveMiuiIslandLabelFontWeight.
  ///
  /// In zh, this message translates to:
  /// **'岛标签字重'**
  String get logFieldLiveMiuiIslandLabelFontWeight;

  /// No description provided for @logFieldLiveMiuiIslandLabelRenderQuality.
  ///
  /// In zh, this message translates to:
  /// **'岛标签渲染质量'**
  String get logFieldLiveMiuiIslandLabelRenderQuality;

  /// No description provided for @logFieldLiveMiuiIslandLabelFontSize.
  ///
  /// In zh, this message translates to:
  /// **'岛标签字号'**
  String get logFieldLiveMiuiIslandLabelFontSize;

  /// No description provided for @logFieldLiveMiuiIslandLabelOffsetX.
  ///
  /// In zh, this message translates to:
  /// **'岛标签 X 偏移'**
  String get logFieldLiveMiuiIslandLabelOffsetX;

  /// No description provided for @logFieldLiveMiuiIslandLabelOffsetY.
  ///
  /// In zh, this message translates to:
  /// **'岛标签 Y 偏移'**
  String get logFieldLiveMiuiIslandLabelOffsetY;

  /// No description provided for @logFieldLiveMiuiIslandExpandedIconMode.
  ///
  /// In zh, this message translates to:
  /// **'展开图标模式'**
  String get logFieldLiveMiuiIslandExpandedIconMode;

  /// No description provided for @logFieldLiveShowBeforeClassMinutes.
  ///
  /// In zh, this message translates to:
  /// **'课前显示分钟数'**
  String get logFieldLiveShowBeforeClassMinutes;

  /// No description provided for @logFieldLiveClassReminderStartMinutes.
  ///
  /// In zh, this message translates to:
  /// **'上课提醒开始分钟'**
  String get logFieldLiveClassReminderStartMinutes;

  /// No description provided for @logFieldLiveEndSecondsCountdownThreshold.
  ///
  /// In zh, this message translates to:
  /// **'下课秒倒计时阈值'**
  String get logFieldLiveEndSecondsCountdownThreshold;

  /// No description provided for @logFieldState.
  ///
  /// In zh, this message translates to:
  /// **'状态'**
  String get logFieldState;

  /// No description provided for @logFieldRoute.
  ///
  /// In zh, this message translates to:
  /// **'路由'**
  String get logFieldRoute;

  /// No description provided for @logFieldPreviousRoute.
  ///
  /// In zh, this message translates to:
  /// **'先前路由'**
  String get logFieldPreviousRoute;

  /// No description provided for @logFieldProfileId.
  ///
  /// In zh, this message translates to:
  /// **'课表配置 ID'**
  String get logFieldProfileId;

  /// No description provided for @logFieldReason.
  ///
  /// In zh, this message translates to:
  /// **'原因'**
  String get logFieldReason;

  /// No description provided for @logFieldClientIp.
  ///
  /// In zh, this message translates to:
  /// **'客户端 IP'**
  String get logFieldClientIp;

  /// No description provided for @logFieldPort.
  ///
  /// In zh, this message translates to:
  /// **'端口'**
  String get logFieldPort;

  /// No description provided for @logFieldCourseName.
  ///
  /// In zh, this message translates to:
  /// **'课程名'**
  String get logFieldCourseName;

  /// No description provided for @logFieldStage.
  ///
  /// In zh, this message translates to:
  /// **'阶段'**
  String get logFieldStage;

  /// No description provided for @logFieldFrom.
  ///
  /// In zh, this message translates to:
  /// **'来源页面'**
  String get logFieldFrom;

  /// No description provided for @logFieldCurrentWeek.
  ///
  /// In zh, this message translates to:
  /// **'当前周次'**
  String get logFieldCurrentWeek;

  /// No description provided for @logFieldWeekday.
  ///
  /// In zh, this message translates to:
  /// **'星期'**
  String get logFieldWeekday;

  /// No description provided for @logFieldUntilMillis.
  ///
  /// In zh, this message translates to:
  /// **'暂停截止时间'**
  String get logFieldUntilMillis;

  /// No description provided for @logFieldStartAtMillis.
  ///
  /// In zh, this message translates to:
  /// **'开始时间'**
  String get logFieldStartAtMillis;

  /// No description provided for @logFieldMergedCourseCount.
  ///
  /// In zh, this message translates to:
  /// **'合并课程数'**
  String get logFieldMergedCourseCount;

  /// No description provided for @logFieldDeletedCount.
  ///
  /// In zh, this message translates to:
  /// **'删除数量'**
  String get logFieldDeletedCount;

  /// No description provided for @logFieldRequested.
  ///
  /// In zh, this message translates to:
  /// **'请求数量'**
  String get logFieldRequested;

  /// No description provided for @logFieldTarget.
  ///
  /// In zh, this message translates to:
  /// **'目标'**
  String get logFieldTarget;

  /// No description provided for @logFieldCount.
  ///
  /// In zh, this message translates to:
  /// **'数量'**
  String get logFieldCount;

  /// No description provided for @logFieldValue.
  ///
  /// In zh, this message translates to:
  /// **'值'**
  String get logFieldValue;

  /// No description provided for @logFieldSnapshotLength.
  ///
  /// In zh, this message translates to:
  /// **'快照长度'**
  String get logFieldSnapshotLength;

  /// No description provided for @logFieldStoredSnapshotVersion.
  ///
  /// In zh, this message translates to:
  /// **'存储快照版本'**
  String get logFieldStoredSnapshotVersion;

  /// No description provided for @logFieldIntentIsNull.
  ///
  /// In zh, this message translates to:
  /// **'Intent 为空'**
  String get logFieldIntentIsNull;

  /// No description provided for @logFieldAction.
  ///
  /// In zh, this message translates to:
  /// **'操作'**
  String get logFieldAction;

  /// No description provided for @logFieldStep.
  ///
  /// In zh, this message translates to:
  /// **'步骤'**
  String get logFieldStep;

  /// No description provided for @logCatAppLoggerInitialized.
  ///
  /// In zh, this message translates to:
  /// **'应用日志：初始化'**
  String get logCatAppLoggerInitialized;

  /// No description provided for @logCatPrivacyConsentUpdated.
  ///
  /// In zh, this message translates to:
  /// **'应用日志：隐私协议'**
  String get logCatPrivacyConsentUpdated;

  /// No description provided for @logCatAppLogRecordingEnabled.
  ///
  /// In zh, this message translates to:
  /// **'应用日志：记录开关'**
  String get logCatAppLogRecordingEnabled;

  /// No description provided for @logCatStartupFlowStarted.
  ///
  /// In zh, this message translates to:
  /// **'启动流程：开始'**
  String get logCatStartupFlowStarted;

  /// No description provided for @logCatStartupFlowCompleted.
  ///
  /// In zh, this message translates to:
  /// **'启动流程：完成'**
  String get logCatStartupFlowCompleted;

  /// No description provided for @logCatStartupFlowFailed.
  ///
  /// In zh, this message translates to:
  /// **'启动流程：失败'**
  String get logCatStartupFlowFailed;

  /// No description provided for @logCatAppLifecycleStateChanged.
  ///
  /// In zh, this message translates to:
  /// **'应用生命周期'**
  String get logCatAppLifecycleStateChanged;

  /// No description provided for @logCatRoutePushed.
  ///
  /// In zh, this message translates to:
  /// **'路由：入栈'**
  String get logCatRoutePushed;

  /// No description provided for @logCatRoutePopped.
  ///
  /// In zh, this message translates to:
  /// **'路由：出栈'**
  String get logCatRoutePopped;

  /// No description provided for @logCatRouteReplaced.
  ///
  /// In zh, this message translates to:
  /// **'路由：替换'**
  String get logCatRouteReplaced;

  /// No description provided for @logCatFlutterFrameworkError.
  ///
  /// In zh, this message translates to:
  /// **'Flutter 框架错误'**
  String get logCatFlutterFrameworkError;

  /// No description provided for @logCatFlutterPlatformError.
  ///
  /// In zh, this message translates to:
  /// **'Flutter 平台错误'**
  String get logCatFlutterPlatformError;

  /// No description provided for @logCatFlutterZoneError.
  ///
  /// In zh, this message translates to:
  /// **'Flutter Zone 错误'**
  String get logCatFlutterZoneError;

  /// No description provided for @logCatAppLogsDefaultMigrated.
  ///
  /// In zh, this message translates to:
  /// **'应用日志：迁移'**
  String get logCatAppLogsDefaultMigrated;

  /// No description provided for @logCatTimetableLoadSettingsFailed.
  ///
  /// In zh, this message translates to:
  /// **'课表：加载设置失败'**
  String get logCatTimetableLoadSettingsFailed;

  /// No description provided for @logCatTimetableLoadCoursesFailed.
  ///
  /// In zh, this message translates to:
  /// **'课表：加载课程失败'**
  String get logCatTimetableLoadCoursesFailed;

  /// No description provided for @logCatTimetableLoadCurrentWeekFailed.
  ///
  /// In zh, this message translates to:
  /// **'课表：加载周次失败'**
  String get logCatTimetableLoadCurrentWeekFailed;

  /// No description provided for @logCatHomeWidgetPinSupportFailed.
  ///
  /// In zh, this message translates to:
  /// **'桌面小组件：检查固定支持'**
  String get logCatHomeWidgetPinSupportFailed;

  /// No description provided for @logCatHomeWidgetPinRequestFailed.
  ///
  /// In zh, this message translates to:
  /// **'桌面小组件：请求固定'**
  String get logCatHomeWidgetPinRequestFailed;

  /// No description provided for @logCatHomeWidgetSyncFailed.
  ///
  /// In zh, this message translates to:
  /// **'桌面小组件：同步失败'**
  String get logCatHomeWidgetSyncFailed;

  /// No description provided for @logCatHomeWidgetClearFailed.
  ///
  /// In zh, this message translates to:
  /// **'桌面小组件：清空失败'**
  String get logCatHomeWidgetClearFailed;

  /// No description provided for @logCatHomeWidgetScheduleFailed.
  ///
  /// In zh, this message translates to:
  /// **'桌面小组件：调度刷新'**
  String get logCatHomeWidgetScheduleFailed;

  /// No description provided for @logCatMiuiLiveInitializeFailed.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：初始化失败'**
  String get logCatMiuiLiveInitializeFailed;

  /// No description provided for @logCatMiuiLiveOpenPromotedSettingsFailed.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：打开权限设置'**
  String get logCatMiuiLiveOpenPromotedSettingsFailed;

  /// No description provided for @logCatMiuiLiveOpenNotificationSettingsFailed.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：打开通知设置'**
  String get logCatMiuiLiveOpenNotificationSettingsFailed;

  /// No description provided for @logCatMiuiLiveOpenAutostartSettingsFailed.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：打开自启动设置'**
  String get logCatMiuiLiveOpenAutostartSettingsFailed;

  /// No description provided for @logCatMiuiLiveOpenBatterySettingsFailed.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：打开电池优化'**
  String get logCatMiuiLiveOpenBatterySettingsFailed;

  /// No description provided for @logCatMiuiLiveOpenAccessibilitySettingsFailed.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：打开无障碍设置'**
  String get logCatMiuiLiveOpenAccessibilitySettingsFailed;

  /// No description provided for @logCatMiuiLiveHideFromRecentsFailed.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：隐藏最近任务'**
  String get logCatMiuiLiveHideFromRecentsFailed;

  /// No description provided for @logCatLiveUpdateFlutterInitializeFailed.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：Flutter 初始化失败'**
  String get logCatLiveUpdateFlutterInitializeFailed;

  /// No description provided for @logCatLiveUpdateStartFailed.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：启动失败'**
  String get logCatLiveUpdateStartFailed;

  /// No description provided for @logCatLiveUpdateStopFailed.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：停止失败'**
  String get logCatLiveUpdateStopFailed;

  /// No description provided for @logCatLiveUpdateDebugStatusFailed.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：调试状态失败'**
  String get logCatLiveUpdateDebugStatusFailed;

  /// No description provided for @logCatLiveUpdateSettingsSynced.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：设置已同步'**
  String get logCatLiveUpdateSettingsSynced;

  /// No description provided for @logCatLiveUpdateSnapshotSyncFailed.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：快照同步失败'**
  String get logCatLiveUpdateSnapshotSyncFailed;

  /// No description provided for @logCatLiveUpdateSnapshotClearFailed.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：快照清空失败'**
  String get logCatLiveUpdateSnapshotClearFailed;

  /// No description provided for @logCatLanEditAuthFailed.
  ///
  /// In zh, this message translates to:
  /// **'局域网编辑：认证'**
  String get logCatLanEditAuthFailed;

  /// No description provided for @logCatLanEditCourseCreated.
  ///
  /// In zh, this message translates to:
  /// **'局域网编辑：创建课程'**
  String get logCatLanEditCourseCreated;

  /// No description provided for @logCatLanEditCourseUpdated.
  ///
  /// In zh, this message translates to:
  /// **'局域网编辑：更新课程'**
  String get logCatLanEditCourseUpdated;

  /// No description provided for @logCatLanEditCourseDeleted.
  ///
  /// In zh, this message translates to:
  /// **'局域网编辑：删除课程'**
  String get logCatLanEditCourseDeleted;

  /// No description provided for @logCatLanEditCourseGroupSaved.
  ///
  /// In zh, this message translates to:
  /// **'局域网编辑：保存课程组'**
  String get logCatLanEditCourseGroupSaved;

  /// No description provided for @logCatLanEditMergeImported.
  ///
  /// In zh, this message translates to:
  /// **'局域网编辑：合并导入'**
  String get logCatLanEditMergeImported;

  /// No description provided for @logCatLanEditCoursesBatchDeleted.
  ///
  /// In zh, this message translates to:
  /// **'局域网编辑：批量删除'**
  String get logCatLanEditCoursesBatchDeleted;

  /// No description provided for @logCatLanEditCurrentWeekSet.
  ///
  /// In zh, this message translates to:
  /// **'局域网编辑：设置周次'**
  String get logCatLanEditCurrentWeekSet;

  /// No description provided for @logCatLanEditSpreadsheetImported.
  ///
  /// In zh, this message translates to:
  /// **'局域网编辑：表格导入'**
  String get logCatLanEditSpreadsheetImported;

  /// No description provided for @logCatLanEditSessionStarted.
  ///
  /// In zh, this message translates to:
  /// **'局域网编辑：会话启动'**
  String get logCatLanEditSessionStarted;

  /// No description provided for @logCatLanEditSessionStopped.
  ///
  /// In zh, this message translates to:
  /// **'局域网编辑：会话停止'**
  String get logCatLanEditSessionStopped;

  /// No description provided for @logCatLiveUpdateTestRequested.
  ///
  /// In zh, this message translates to:
  /// **'超级岛测试：请求'**
  String get logCatLiveUpdateTestRequested;

  /// No description provided for @logCatLiveUpdateTestNoSelection.
  ///
  /// In zh, this message translates to:
  /// **'超级岛测试：无课程'**
  String get logCatLiveUpdateTestNoSelection;

  /// No description provided for @logCatLiveUpdateTestSelectionReady.
  ///
  /// In zh, this message translates to:
  /// **'超级岛测试：已选课程'**
  String get logCatLiveUpdateTestSelectionReady;

  /// No description provided for @logCatLiveUpdateTestSuspendSync.
  ///
  /// In zh, this message translates to:
  /// **'超级岛测试：暂停同步'**
  String get logCatLiveUpdateTestSuspendSync;

  /// No description provided for @logCatLiveUpdateTestStarting.
  ///
  /// In zh, this message translates to:
  /// **'超级岛测试：启动中'**
  String get logCatLiveUpdateTestStarting;

  /// No description provided for @logCatLiveUpdateTestStarted.
  ///
  /// In zh, this message translates to:
  /// **'超级岛测试：已启动'**
  String get logCatLiveUpdateTestStarted;

  /// No description provided for @logCatLiveUpdateTestFailed.
  ///
  /// In zh, this message translates to:
  /// **'超级岛测试：失败'**
  String get logCatLiveUpdateTestFailed;

  /// No description provided for @logCatLiveUpdateSnapshotSettings.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：快照设置'**
  String get logCatLiveUpdateSnapshotSettings;

  /// No description provided for @logCatLiveUpdateSnapshotSynced.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：快照已同步'**
  String get logCatLiveUpdateSnapshotSynced;

  /// No description provided for @logCatLiveUpdateSnapshotCleared.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：快照已清空'**
  String get logCatLiveUpdateSnapshotCleared;

  /// No description provided for @logCatLiveUpdateAlarmTriggered.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：闹钟触发'**
  String get logCatLiveUpdateAlarmTriggered;

  /// No description provided for @logCatLiveUpdateSchedulerResume.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：调度恢复'**
  String get logCatLiveUpdateSchedulerResume;

  /// No description provided for @logCatLiveUpdateRescheduleHoliday.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：节假日跳过'**
  String get logCatLiveUpdateRescheduleHoliday;

  /// No description provided for @logCatLiveUpdateRescheduleActive.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：立即启动'**
  String get logCatLiveUpdateRescheduleActive;

  /// No description provided for @logCatLiveUpdateRescheduleScheduled.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：已调度'**
  String get logCatLiveUpdateRescheduleScheduled;

  /// No description provided for @logCatLiveUpdateSnapshotParseFailed.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：快照解析失败'**
  String get logCatLiveUpdateSnapshotParseFailed;

  /// No description provided for @logCatLiveUpdateSnapshotInvalidatedAfterUpgrade.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：升级后快照失效'**
  String get logCatLiveUpdateSnapshotInvalidatedAfterUpgrade;

  /// No description provided for @logCatLiveUpdateSnapshotSalvagedAfterUpgrade.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：升级后快照校验通过已保留'**
  String get logCatLiveUpdateSnapshotSalvagedAfterUpgrade;

  /// No description provided for @logCatLiveUpdatePayloadSelected.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：已选负载'**
  String get logCatLiveUpdatePayloadSelected;

  /// No description provided for @logCatLiveUpdateSchedulerStartFailed.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：调度启动失败'**
  String get logCatLiveUpdateSchedulerStartFailed;

  /// No description provided for @logCatLiveUpdateStartRequested.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：请求启动'**
  String get logCatLiveUpdateStartRequested;

  /// No description provided for @logCatLiveUpdateStopRequested.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：请求停止'**
  String get logCatLiveUpdateStopRequested;

  /// No description provided for @logCatLiveUpdateServiceMissingPayload.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：服务缺少负载'**
  String get logCatLiveUpdateServiceMissingPayload;

  /// No description provided for @logCatLiveUpdateServiceStarted.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：服务已启动'**
  String get logCatLiveUpdateServiceStarted;

  /// No description provided for @logCatLiveUpdateServiceStartFailed.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：服务启动失败'**
  String get logCatLiveUpdateServiceStartFailed;

  /// No description provided for @logCatLiveUpdateServiceFgsStartDenied.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：服务内 startForeground 被拒'**
  String get logCatLiveUpdateServiceFgsStartDenied;

  /// No description provided for @logCatLiveUpdateFgsRetryScheduled.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：前台服务被拒，已排退避重试'**
  String get logCatLiveUpdateFgsRetryScheduled;

  /// No description provided for @logCatLiveUpdateFgsStartGaveUp.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：重试耗尽，已降级为普通通知'**
  String get logCatLiveUpdateFgsStartGaveUp;

  /// No description provided for @logCatLiveUpdateTaskRemoved.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：任务被移除'**
  String get logCatLiveUpdateTaskRemoved;

  /// No description provided for @logCatLiveUpdateTaskRemovedResumed.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：任务移除后恢复'**
  String get logCatLiveUpdateTaskRemovedResumed;

  /// No description provided for @logCatLiveUpdateBeforeClassQuickAction.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：课前快捷操作'**
  String get logCatLiveUpdateBeforeClassQuickAction;

  /// No description provided for @logCatLiveUpdateBeforeClassQuickActionRestored.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：课前快捷操作已恢复'**
  String get logCatLiveUpdateBeforeClassQuickActionRestored;

  /// No description provided for @logCatLiveUpdateStatusBarDismissed.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：状态栏通知已关闭'**
  String get logCatLiveUpdateStatusBarDismissed;

  /// No description provided for @logCatLiveUpdateNotPromoted.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：未提升通知'**
  String get logCatLiveUpdateNotPromoted;

  /// No description provided for @logCatLiveUpdatePromotedNotShown.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：提升未显示'**
  String get logCatLiveUpdatePromotedNotShown;

  /// No description provided for @logCatLiveUpdateServiceStopped.
  ///
  /// In zh, this message translates to:
  /// **'超级岛：服务已停止'**
  String get logCatLiveUpdateServiceStopped;

  /// No description provided for @logCatKeepAliveAccessibilityConnected.
  ///
  /// In zh, this message translates to:
  /// **'保活：无障碍已连接'**
  String get logCatKeepAliveAccessibilityConnected;

  /// No description provided for @logCatDiagnosticsEnabled.
  ///
  /// In zh, this message translates to:
  /// **'诊断：已开启'**
  String get logCatDiagnosticsEnabled;

  /// No description provided for @logCatDiagnosticsCleared.
  ///
  /// In zh, this message translates to:
  /// **'诊断：已清空'**
  String get logCatDiagnosticsCleared;

  /// No description provided for @logCatDiagnosticsBootstrap.
  ///
  /// In zh, this message translates to:
  /// **'诊断：引导'**
  String get logCatDiagnosticsBootstrap;

  /// No description provided for @logCatFlutterDiagnostic.
  ///
  /// In zh, this message translates to:
  /// **'Flutter 诊断'**
  String get logCatFlutterDiagnostic;

  /// No description provided for @logCatFlutterDiagnosticEvent.
  ///
  /// In zh, this message translates to:
  /// **'Flutter 诊断事件'**
  String get logCatFlutterDiagnosticEvent;

  /// No description provided for @logCatRenderFailed.
  ///
  /// In zh, this message translates to:
  /// **'渲染失败'**
  String get logCatRenderFailed;

  /// No description provided for @logCatDebugSnapshot.
  ///
  /// In zh, this message translates to:
  /// **'调试快照'**
  String get logCatDebugSnapshot;

  /// No description provided for @logExportTitle.
  ///
  /// In zh, this message translates to:
  /// **'轻屿课表 - 应用日志'**
  String get logExportTitle;

  /// No description provided for @appUpdateMirrorPresetGhfast.
  ///
  /// In zh, this message translates to:
  /// **'默认镜像'**
  String get appUpdateMirrorPresetGhfast;

  /// No description provided for @appUpdateMirrorPresetGhproxyCn.
  ///
  /// In zh, this message translates to:
  /// **'备用镜像 1'**
  String get appUpdateMirrorPresetGhproxyCn;

  /// No description provided for @appUpdateMirrorPresetGhLlkk.
  ///
  /// In zh, this message translates to:
  /// **'备用镜像 2'**
  String get appUpdateMirrorPresetGhLlkk;

  /// No description provided for @appUpdateMirrorPresetGhProxyCom.
  ///
  /// In zh, this message translates to:
  /// **'备用镜像 3'**
  String get appUpdateMirrorPresetGhProxyCom;

  /// No description provided for @appUpdateMirrorPresetGhproxyNet.
  ///
  /// In zh, this message translates to:
  /// **'备用镜像 4'**
  String get appUpdateMirrorPresetGhproxyNet;

  /// No description provided for @appUpdateMirrorPresetCustom.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get appUpdateMirrorPresetCustom;

  /// No description provided for @appUpdateMirrorPresetCustomDescription.
  ///
  /// In zh, this message translates to:
  /// **'填写自定义镜像地址前缀'**
  String get appUpdateMirrorPresetCustomDescription;

  /// No description provided for @cloudBackupRetentionTitle.
  ///
  /// In zh, this message translates to:
  /// **'备份保留策略'**
  String get cloudBackupRetentionTitle;

  /// No description provided for @cloudBackupMaxCountTitle.
  ///
  /// In zh, this message translates to:
  /// **'最多保留份数'**
  String get cloudBackupMaxCountTitle;

  /// No description provided for @cloudBackupMaxCountSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'超过后自动删除最旧的备份'**
  String get cloudBackupMaxCountSubtitle;

  /// No description provided for @cloudBackupMaxCountOption.
  ///
  /// In zh, this message translates to:
  /// **'{count} 份'**
  String cloudBackupMaxCountOption(int count);

  /// No description provided for @cloudBackupMaxAgeTitle.
  ///
  /// In zh, this message translates to:
  /// **'最长保留天数'**
  String get cloudBackupMaxAgeTitle;

  /// No description provided for @cloudBackupMaxAgeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'超过后自动删除过期备份'**
  String get cloudBackupMaxAgeSubtitle;

  /// No description provided for @cloudBackupMaxAgeOption.
  ///
  /// In zh, this message translates to:
  /// **'{days} 天'**
  String cloudBackupMaxAgeOption(int days);

  /// No description provided for @statisticsShareText.
  ///
  /// In zh, this message translates to:
  /// **'来自轻屿课表的学期统计'**
  String get statisticsShareText;

  /// No description provided for @aboutUpdateAvailableHeadline.
  ///
  /// In zh, this message translates to:
  /// **'有版本更新'**
  String get aboutUpdateAvailableHeadline;

  /// No description provided for @aboutAlreadyLatestHeadline.
  ///
  /// In zh, this message translates to:
  /// **'已是最新版本'**
  String get aboutAlreadyLatestHeadline;

  /// No description provided for @aboutDownloadChannelSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'下载渠道'**
  String get aboutDownloadChannelSectionTitle;

  /// No description provided for @aboutMirrorProbeFailedLabel.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get aboutMirrorProbeFailedLabel;

  /// No description provided for @timeSchemeImportSupplementName.
  ///
  /// In zh, this message translates to:
  /// **'{name}（导入补齐）'**
  String timeSchemeImportSupplementName(String name);

  /// No description provided for @profileTimeSchemeName.
  ///
  /// In zh, this message translates to:
  /// **'{profileName} 时间'**
  String profileTimeSchemeName(String profileName);

  /// No description provided for @currentProfileTimeSchemeName.
  ///
  /// In zh, this message translates to:
  /// **'当前课表时间'**
  String get currentProfileTimeSchemeName;

  /// No description provided for @unnamedTimetableProfile.
  ///
  /// In zh, this message translates to:
  /// **'未命名课表'**
  String get unnamedTimetableProfile;

  /// No description provided for @cloudBackupManualProtectedTitle.
  ///
  /// In zh, this message translates to:
  /// **'手动备份永不过期'**
  String get cloudBackupManualProtectedTitle;

  /// No description provided for @cloudBackupManualProtectedSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'开启后，手动创建的备份不会被自动清理'**
  String get cloudBackupManualProtectedSubtitle;

  /// No description provided for @courseImportPortalUrlMissingBody.
  ///
  /// In zh, this message translates to:
  /// **'“{schoolName} / {adapterName}” 没有默认登录地址，请先输入学校教务系统网址'**
  String courseImportPortalUrlMissingBody(
    String schoolName,
    String adapterName,
  );

  /// No description provided for @guidePermissionsProgressLabel.
  ///
  /// In zh, this message translates to:
  /// **'已就绪 {ready}/{total}'**
  String guidePermissionsProgressLabel(int ready, int total);

  /// No description provided for @locationTimeMatchEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'地点作息匹配'**
  String get locationTimeMatchEntryTitle;

  /// No description provided for @locationTimeMatchEntrySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'按上课地点关键词自动选用时间模板'**
  String get locationTimeMatchEntrySubtitle;

  /// No description provided for @locationTimeMatchTitle.
  ///
  /// In zh, this message translates to:
  /// **'地点作息匹配'**
  String get locationTimeMatchTitle;

  /// No description provided for @locationTimeMatchSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'按地点关键词自动匹配时间模板。重新匹配仅更新命中课程的钟点，未命中课程保持不变。'**
  String get locationTimeMatchSubtitle;

  /// No description provided for @locationTimeMatchWeekAxisNote.
  ///
  /// In zh, this message translates to:
  /// **'说明：首页左侧时间列仍显示课表默认模板；卡片/详情/实况上的钟点以地点匹配结果为准。'**
  String get locationTimeMatchWeekAxisNote;

  /// No description provided for @locationTimeMatchPreviewLabel.
  ///
  /// In zh, this message translates to:
  /// **'试匹配地点'**
  String get locationTimeMatchPreviewLabel;

  /// No description provided for @locationTimeMatchPreviewHint.
  ///
  /// In zh, this message translates to:
  /// **'例如 A1062 或 A主201'**
  String get locationTimeMatchPreviewHint;

  /// No description provided for @locationTimeMatchPreviewNoMatch.
  ///
  /// In zh, this message translates to:
  /// **'未命中任何地点组，将使用课表默认时间模板'**
  String get locationTimeMatchPreviewNoMatch;

  /// No description provided for @locationTimeMatchPreviewResult.
  ///
  /// In zh, this message translates to:
  /// **'将匹配：{group} · {scheme}（关键词 {keyword}）'**
  String locationTimeMatchPreviewResult(
    String group,
    String scheme,
    String keyword,
  );

  /// No description provided for @locationTimeMatchApplyActive.
  ///
  /// In zh, this message translates to:
  /// **'重新匹配当前课表'**
  String get locationTimeMatchApplyActive;

  /// No description provided for @locationTimeMatchApplyTitle.
  ///
  /// In zh, this message translates to:
  /// **'重新匹配当前课表？'**
  String get locationTimeMatchApplyTitle;

  /// No description provided for @locationTimeMatchApplyMessage.
  ///
  /// In zh, this message translates to:
  /// **'当前有 {count} 门课程命中地点规则。节次适配的课程会恢复自动匹配并同步钟点；此前手动指定的模板将被清除，未命中的课程不会改变。'**
  String locationTimeMatchApplyMessage(int count);

  /// No description provided for @locationTimeMatchApplyConfirm.
  ///
  /// In zh, this message translates to:
  /// **'重新匹配'**
  String get locationTimeMatchApplyConfirm;

  /// No description provided for @locationTimeMatchApplyUpdated.
  ///
  /// In zh, this message translates to:
  /// **'已重新匹配 {matched} 门，更新 {updated} 门钟点'**
  String locationTimeMatchApplyUpdated(int matched, int updated);

  /// No description provided for @locationTimeMatchApplyAlreadyAligned.
  ///
  /// In zh, this message translates to:
  /// **'已重新匹配 {matched} 门，钟点无需改写'**
  String locationTimeMatchApplyAlreadyAligned(int matched);

  /// No description provided for @locationTimeMatchApplyNoneMatched.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配到可套用的课程'**
  String get locationTimeMatchApplyNoneMatched;

  /// No description provided for @locationTimeMatchApplyOverflowResult.
  ///
  /// In zh, this message translates to:
  /// **'有 {count} 门课节次无法对号入座（模板节数不足），已拒绝套用'**
  String locationTimeMatchApplyOverflowResult(int matched, int count);

  /// No description provided for @locationTimeMatchApplyOverflowHint.
  ///
  /// In zh, this message translates to:
  /// **'未套用示例：{names}'**
  String locationTimeMatchApplyOverflowHint(String names);

  /// No description provided for @locationTimeMatchEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有地点组'**
  String get locationTimeMatchEmpty;

  /// No description provided for @locationTimeMatchCreateGroup.
  ///
  /// In zh, this message translates to:
  /// **'新建地点组'**
  String get locationTimeMatchCreateGroup;

  /// No description provided for @locationTimeMatchEditGroup.
  ///
  /// In zh, this message translates to:
  /// **'编辑地点组'**
  String get locationTimeMatchEditGroup;

  /// No description provided for @locationTimeMatchUnknownScheme.
  ///
  /// In zh, this message translates to:
  /// **'未知时间模板'**
  String get locationTimeMatchUnknownScheme;

  /// No description provided for @locationTimeMatchNoKeywords.
  ///
  /// In zh, this message translates to:
  /// **'未设置关键词'**
  String get locationTimeMatchNoKeywords;

  /// No description provided for @locationTimeMatchBoundScheme.
  ///
  /// In zh, this message translates to:
  /// **'时间模板：{name}'**
  String locationTimeMatchBoundScheme(String name);

  /// No description provided for @locationTimeMatchKeywordsLine.
  ///
  /// In zh, this message translates to:
  /// **'关键词：{keywords}'**
  String locationTimeMatchKeywordsLine(String keywords);

  /// No description provided for @locationTimeMatchDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除地点组？'**
  String get locationTimeMatchDeleteTitle;

  /// No description provided for @locationTimeMatchDeleteMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定删除「{name}」？自动匹配的课程将恢复课表默认模板；手动指定模板的课程不受影响。'**
  String locationTimeMatchDeleteMessage(String name);

  /// No description provided for @locationTimeMatchDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除地点组'**
  String get locationTimeMatchDeleted;

  /// No description provided for @locationTimeMatchGroupNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'地点组名称'**
  String get locationTimeMatchGroupNameLabel;

  /// No description provided for @locationTimeMatchGroupNameHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：主教学楼 / 其他教学楼'**
  String get locationTimeMatchGroupNameHint;

  /// No description provided for @locationTimeMatchBoundSchemeLabel.
  ///
  /// In zh, this message translates to:
  /// **'绑定时间模板'**
  String get locationTimeMatchBoundSchemeLabel;

  /// No description provided for @locationTimeMatchNeedTimeScheme.
  ///
  /// In zh, this message translates to:
  /// **'请先创建至少一套时间模板'**
  String get locationTimeMatchNeedTimeScheme;

  /// No description provided for @locationTimeMatchEnabledLabel.
  ///
  /// In zh, this message translates to:
  /// **'启用此地点组'**
  String get locationTimeMatchEnabledLabel;

  /// No description provided for @locationTimeMatchKeywordsSection.
  ///
  /// In zh, this message translates to:
  /// **'地点关键词'**
  String get locationTimeMatchKeywordsSection;

  /// No description provided for @locationTimeMatchKeywordsHelp.
  ///
  /// In zh, this message translates to:
  /// **'可从课表地点一键识别楼栋，或手动填写关键词（如 A主、A1、A6）。匹配模式建议用「前缀」，更长的关键词优先。'**
  String get locationTimeMatchKeywordsHelp;

  /// No description provided for @locationTimeMatchSelectedKeywords.
  ///
  /// In zh, this message translates to:
  /// **'已选关键词'**
  String get locationTimeMatchSelectedKeywords;

  /// No description provided for @locationTimeMatchNoSelectedKeywords.
  ///
  /// In zh, this message translates to:
  /// **'尚未添加关键词'**
  String get locationTimeMatchNoSelectedKeywords;

  /// No description provided for @locationTimeMatchPickFromLocations.
  ///
  /// In zh, this message translates to:
  /// **'从课表地点选择'**
  String get locationTimeMatchPickFromLocations;

  /// No description provided for @locationTimeMatchBuildingSuggestions.
  ///
  /// In zh, this message translates to:
  /// **'从课表识别的楼栋'**
  String get locationTimeMatchBuildingSuggestions;

  /// No description provided for @locationTimeMatchNoBuildingSuggestions.
  ///
  /// In zh, this message translates to:
  /// **'当前课表没有可识别的楼栋地点'**
  String get locationTimeMatchNoBuildingSuggestions;

  /// No description provided for @locationTimeMatchAddBuilding.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get locationTimeMatchAddBuilding;

  /// No description provided for @locationTimeMatchAddAllBuildings.
  ///
  /// In zh, this message translates to:
  /// **'一键添加全部未配置楼栋'**
  String get locationTimeMatchAddAllBuildings;

  /// No description provided for @locationTimeMatchBuildingRoomCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 间教室'**
  String locationTimeMatchBuildingRoomCount(int count);

  /// No description provided for @locationTimeMatchBuildingGateTags.
  ///
  /// In zh, this message translates to:
  /// **'标签：{tags}'**
  String locationTimeMatchBuildingGateTags(String tags);

  /// No description provided for @locationTimeMatchKeywordExtracted.
  ///
  /// In zh, this message translates to:
  /// **'已从地点提取关键词 {keyword}'**
  String locationTimeMatchKeywordExtracted(String keyword);

  /// No description provided for @locationTimeMatchKeywordAlreadyExists.
  ///
  /// In zh, this message translates to:
  /// **'关键词已存在'**
  String get locationTimeMatchKeywordAlreadyExists;

  /// No description provided for @locationTimeMatchKeywordUsedByGroup.
  ///
  /// In zh, this message translates to:
  /// **'关键词已被「{group}」使用'**
  String locationTimeMatchKeywordUsedByGroup(String group);

  /// No description provided for @locationTimeMatchAddKeyword.
  ///
  /// In zh, this message translates to:
  /// **'手动添加关键词'**
  String get locationTimeMatchAddKeyword;

  /// No description provided for @locationTimeMatchKeywordLabel.
  ///
  /// In zh, this message translates to:
  /// **'关键词'**
  String get locationTimeMatchKeywordLabel;

  /// No description provided for @locationTimeMatchKeywordHint.
  ///
  /// In zh, this message translates to:
  /// **'A1 / A主 / 六教'**
  String get locationTimeMatchKeywordHint;

  /// No description provided for @locationTimeMatchModeLabel.
  ///
  /// In zh, this message translates to:
  /// **'匹配模式'**
  String get locationTimeMatchModeLabel;

  /// No description provided for @locationTimeMatchModePrefix.
  ///
  /// In zh, this message translates to:
  /// **'前缀'**
  String get locationTimeMatchModePrefix;

  /// No description provided for @locationTimeMatchModeContains.
  ///
  /// In zh, this message translates to:
  /// **'包含'**
  String get locationTimeMatchModeContains;

  /// No description provided for @locationTimeMatchModeExact.
  ///
  /// In zh, this message translates to:
  /// **'精确'**
  String get locationTimeMatchModeExact;

  /// No description provided for @locationTimeMatchKeywordTooShort.
  ///
  /// In zh, this message translates to:
  /// **'关键词过短，容易误匹配'**
  String get locationTimeMatchKeywordTooShort;

  /// No description provided for @locationTimeMatchNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写地点组名称'**
  String get locationTimeMatchNameRequired;

  /// No description provided for @locationTimeMatchKeywordRequired.
  ///
  /// In zh, this message translates to:
  /// **'请至少添加一个关键词'**
  String get locationTimeMatchKeywordRequired;

  /// No description provided for @locationTimeMatchSaved.
  ///
  /// In zh, this message translates to:
  /// **'地点组已保存'**
  String get locationTimeMatchSaved;

  /// No description provided for @locationTimeMatchSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败'**
  String get locationTimeMatchSaveFailed;

  /// No description provided for @followLocationAutoTimeScheme.
  ///
  /// In zh, this message translates to:
  /// **'跟随课表 / 地点自动'**
  String get followLocationAutoTimeScheme;

  /// No description provided for @followLocationAutoTimeSchemeDescription.
  ///
  /// In zh, this message translates to:
  /// **'未手动指定时，按上课地点关键词自动匹配时间模板；未命中则用课表默认模板'**
  String get followLocationAutoTimeSchemeDescription;

  /// No description provided for @locationTimeMatchedSchemeHint.
  ///
  /// In zh, this message translates to:
  /// **'地点匹配 · {scheme}'**
  String locationTimeMatchedSchemeHint(String scheme);

  /// No description provided for @locationTimeAutoResolvedByGroup.
  ///
  /// In zh, this message translates to:
  /// **'地点组「{group}」→ {scheme}'**
  String locationTimeAutoResolvedByGroup(String group, String scheme);

  /// No description provided for @locationTimeAutoResolvedByTimetable.
  ///
  /// In zh, this message translates to:
  /// **'课表默认 → {scheme}'**
  String locationTimeAutoResolvedByTimetable(String scheme);

  /// No description provided for @scheduleDateRuleSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'日期作息规则'**
  String get scheduleDateRuleSectionTitle;

  /// No description provided for @scheduleDateRuleSectionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'开始日自动将所选模板套用为全部课表默认作息。最多 2 条且区间不重叠；地点作息匹配优先。'**
  String get scheduleDateRuleSectionSubtitle;

  /// No description provided for @scheduleDateRuleAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加日期规则'**
  String get scheduleDateRuleAdd;

  /// No description provided for @scheduleDateRuleEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑日期规则'**
  String get scheduleDateRuleEdit;

  /// No description provided for @scheduleDateRuleEmpty.
  ///
  /// In zh, this message translates to:
  /// **'未设置日期规则'**
  String get scheduleDateRuleEmpty;

  /// No description provided for @scheduleDateRuleNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'规则名称'**
  String get scheduleDateRuleNameLabel;

  /// No description provided for @scheduleDateRuleNameHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：夏令时 / 冬令时'**
  String get scheduleDateRuleNameHint;

  /// No description provided for @scheduleDateRuleStartDate.
  ///
  /// In zh, this message translates to:
  /// **'开始日期'**
  String get scheduleDateRuleStartDate;

  /// No description provided for @scheduleDateRuleEndDate.
  ///
  /// In zh, this message translates to:
  /// **'结束日期'**
  String get scheduleDateRuleEndDate;

  /// No description provided for @scheduleDateRuleBoundScheme.
  ///
  /// In zh, this message translates to:
  /// **'使用时间模板'**
  String get scheduleDateRuleBoundScheme;

  /// No description provided for @scheduleDateRuleEnabled.
  ///
  /// In zh, this message translates to:
  /// **'启用'**
  String get scheduleDateRuleEnabled;

  /// No description provided for @scheduleDateRuleActiveToday.
  ///
  /// In zh, this message translates to:
  /// **'今天在区间内'**
  String get scheduleDateRuleActiveToday;

  /// No description provided for @scheduleDateRuleRangeSummary.
  ///
  /// In zh, this message translates to:
  /// **'{start} ~ {end}'**
  String scheduleDateRuleRangeSummary(String start, String end);

  /// No description provided for @scheduleDateRuleMaxReached.
  ///
  /// In zh, this message translates to:
  /// **'最多只能添加 2 条日期规则'**
  String get scheduleDateRuleMaxReached;

  /// No description provided for @scheduleDateRuleNeedScheme.
  ///
  /// In zh, this message translates to:
  /// **'请先创建至少一套时间模板'**
  String get scheduleDateRuleNeedScheme;

  /// No description provided for @scheduleDateRuleNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写规则名称'**
  String get scheduleDateRuleNameRequired;

  /// No description provided for @scheduleDateRuleSaved.
  ///
  /// In zh, this message translates to:
  /// **'日期规则已保存'**
  String get scheduleDateRuleSaved;

  /// No description provided for @scheduleDateRuleSavedAndApplied.
  ///
  /// In zh, this message translates to:
  /// **'日期规则已保存，今天已更新所有课表的默认作息'**
  String get scheduleDateRuleSavedAndApplied;

  /// No description provided for @scheduleDateRuleSavedForFuture.
  ///
  /// In zh, this message translates to:
  /// **'日期规则已保存，将在开始日期更新所有课表的默认作息'**
  String get scheduleDateRuleSavedForFuture;

  /// No description provided for @scheduleDateRuleSavedButApplyFailed.
  ///
  /// In zh, this message translates to:
  /// **'日期规则已保存，但今天自动套用失败（请检查模板节次是否足够）'**
  String get scheduleDateRuleSavedButApplyFailed;

  /// No description provided for @scheduleDateRuleDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除日期规则'**
  String get scheduleDateRuleDeleted;

  /// No description provided for @scheduleDateRuleDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除日期规则？'**
  String get scheduleDateRuleDeleteTitle;

  /// No description provided for @scheduleDateRuleDeleteMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定删除「{name}」？删除后不会自动恢复已套用的作息，需手动调整。'**
  String scheduleDateRuleDeleteMessage(String name);

  /// No description provided for @scheduleDateRuleSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败：{reason}'**
  String scheduleDateRuleSaveFailed(String reason);

  /// No description provided for @scheduleDateRuleErrorMax.
  ///
  /// In zh, this message translates to:
  /// **'已达到 2 条上限'**
  String get scheduleDateRuleErrorMax;

  /// No description provided for @scheduleDateRuleErrorOverlap.
  ///
  /// In zh, this message translates to:
  /// **'日期区间与已有规则重叠'**
  String get scheduleDateRuleErrorOverlap;

  /// No description provided for @scheduleDateRuleErrorInvalidDate.
  ///
  /// In zh, this message translates to:
  /// **'日期格式无效'**
  String get scheduleDateRuleErrorInvalidDate;

  /// No description provided for @scheduleDateRuleErrorEndBeforeStart.
  ///
  /// In zh, this message translates to:
  /// **'结束日期不能早于开始日期'**
  String get scheduleDateRuleErrorEndBeforeStart;

  /// No description provided for @scheduleDateRuleErrorSchemeRequired.
  ///
  /// In zh, this message translates to:
  /// **'请选择时间模板'**
  String get scheduleDateRuleErrorSchemeRequired;

  /// No description provided for @scheduleDateRuleErrorNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写名称'**
  String get scheduleDateRuleErrorNameRequired;

  /// No description provided for @scheduleDateRuleNote.
  ///
  /// In zh, this message translates to:
  /// **'地点匹配优先于日期规则。'**
  String get scheduleDateRuleNote;

  /// No description provided for @frostedGlassModeLabel.
  ///
  /// In zh, this message translates to:
  /// **'玻璃模式'**
  String get frostedGlassModeLabel;

  /// No description provided for @liquidGlassScopeSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'液态玻璃作用范围'**
  String get liquidGlassScopeSectionTitle;

  /// No description provided for @liquidGlassScopePopupTitle.
  ///
  /// In zh, this message translates to:
  /// **'下拉选择弹窗'**
  String get liquidGlassScopePopupTitle;

  /// No description provided for @liquidGlassScopePopupSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'玻璃模式等设置行弹出的小气泡菜单'**
  String get liquidGlassScopePopupSubtitle;

  /// No description provided for @liquidGlassScopeSelectSheetTitle.
  ///
  /// In zh, this message translates to:
  /// **'全屏选择面板'**
  String get liquidGlassScopeSelectSheetTitle;

  /// No description provided for @liquidGlassScopeSelectSheetSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'预设主题、字体等长列表选择弹窗，默认保持磨砂'**
  String get liquidGlassScopeSelectSheetSubtitle;

  /// No description provided for @liquidGlassScopeSheetDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'弹窗与对话框'**
  String get liquidGlassScopeSheetDialogTitle;

  /// No description provided for @liquidGlassScopeSheetDialogSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'底部弹窗、确认对话框与操作菜单'**
  String get liquidGlassScopeSheetDialogSubtitle;

  /// No description provided for @liquidGlassScopeHomeChromeTitle.
  ///
  /// In zh, this message translates to:
  /// **'首页玻璃带'**
  String get liquidGlassScopeHomeChromeTitle;

  /// No description provided for @liquidGlassScopeHomeChromeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'标题栏与星期栏的玻璃背景带'**
  String get liquidGlassScopeHomeChromeSubtitle;

  /// No description provided for @liquidGlassScopeDockTitle.
  ///
  /// In zh, this message translates to:
  /// **'玻璃坞导航'**
  String get liquidGlassScopeDockTitle;

  /// No description provided for @liquidGlassScopeDockSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'底部悬浮药丸与加课圆钮'**
  String get liquidGlassScopeDockSubtitle;

  /// No description provided for @liquidGlassScopePickerButtonsTitle.
  ///
  /// In zh, this message translates to:
  /// **'壁纸选点按钮'**
  String get liquidGlassScopePickerButtonsTitle;

  /// No description provided for @liquidGlassScopePickerButtonsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'壁纸位置选择页悬浮在壁纸上的玻璃按钮'**
  String get liquidGlassScopePickerButtonsSubtitle;

  /// No description provided for @frostedGlassModeFrosted.
  ///
  /// In zh, this message translates to:
  /// **'经典磨砂'**
  String get frostedGlassModeFrosted;

  /// No description provided for @frostedGlassModeLiquid.
  ///
  /// In zh, this message translates to:
  /// **'液态玻璃'**
  String get frostedGlassModeLiquid;

  /// No description provided for @frostedGlassModeGaussian.
  ///
  /// In zh, this message translates to:
  /// **'高斯模糊'**
  String get frostedGlassModeGaussian;

  /// No description provided for @frostedGlassModeTranslucent.
  ///
  /// In zh, this message translates to:
  /// **'半透明'**
  String get frostedGlassModeTranslucent;

  /// No description provided for @frostedLiquidGlassHint.
  ///
  /// In zh, this message translates to:
  /// **'液态玻璃需要高性能设备支持'**
  String get frostedLiquidGlassHint;

  /// No description provided for @advancedMaterialTitle.
  ///
  /// In zh, this message translates to:
  /// **'高级材质'**
  String get advancedMaterialTitle;

  /// No description provided for @advancedMaterialEntrySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'液态玻璃参数微调'**
  String get advancedMaterialEntrySubtitle;

  /// No description provided for @liquidGlassPresetLabel.
  ///
  /// In zh, this message translates to:
  /// **'液态玻璃预设'**
  String get liquidGlassPresetLabel;

  /// No description provided for @liquidGlassPresetClear.
  ///
  /// In zh, this message translates to:
  /// **'清澈'**
  String get liquidGlassPresetClear;

  /// No description provided for @liquidGlassPresetLight.
  ///
  /// In zh, this message translates to:
  /// **'轻雾'**
  String get liquidGlassPresetLight;

  /// No description provided for @liquidGlassPresetStandard.
  ///
  /// In zh, this message translates to:
  /// **'标准'**
  String get liquidGlassPresetStandard;

  /// No description provided for @liquidGlassPresetDense.
  ///
  /// In zh, this message translates to:
  /// **'浓密'**
  String get liquidGlassPresetDense;

  /// No description provided for @liquidGlassPresetCustom.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get liquidGlassPresetCustom;

  /// No description provided for @courseCardSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'课程卡片'**
  String get courseCardSettingsTitle;

  /// No description provided for @courseCardSectionFields.
  ///
  /// In zh, this message translates to:
  /// **'显示字段'**
  String get courseCardSectionFields;

  /// No description provided for @courseCardSectionLayout.
  ///
  /// In zh, this message translates to:
  /// **'布局'**
  String get courseCardSectionLayout;

  /// No description provided for @courseCardSurfaceStyleLabel.
  ///
  /// In zh, this message translates to:
  /// **'卡片外观'**
  String get courseCardSurfaceStyleLabel;

  /// No description provided for @courseCardSurfaceStyleSolid.
  ///
  /// In zh, this message translates to:
  /// **'实体卡片'**
  String get courseCardSurfaceStyleSolid;

  /// No description provided for @courseCardSurfaceStyleGaussian.
  ///
  /// In zh, this message translates to:
  /// **'高斯模糊'**
  String get courseCardSurfaceStyleGaussian;

  /// No description provided for @courseCardSectionColor.
  ///
  /// In zh, this message translates to:
  /// **'颜色'**
  String get courseCardSectionColor;

  /// No description provided for @liveSelfCheckTitle.
  ///
  /// In zh, this message translates to:
  /// **'自检'**
  String get liveSelfCheckTitle;

  /// No description provided for @collapsibleLargeTitle.
  ///
  /// In zh, this message translates to:
  /// **'折叠大标题'**
  String get collapsibleLargeTitle;

  /// No description provided for @liquidGlassCustomExpandedTitle.
  ///
  /// In zh, this message translates to:
  /// **'自定义参数'**
  String get liquidGlassCustomExpandedTitle;

  /// No description provided for @liquidGlassThicknessLabel.
  ///
  /// In zh, this message translates to:
  /// **'厚度'**
  String get liquidGlassThicknessLabel;

  /// No description provided for @liquidGlassBlurLabel.
  ///
  /// In zh, this message translates to:
  /// **'模糊强度'**
  String get liquidGlassBlurLabel;

  /// No description provided for @liquidGlassTintLabel.
  ///
  /// In zh, this message translates to:
  /// **'染色强度'**
  String get liquidGlassTintLabel;

  /// No description provided for @liquidGlassLightIntensityLabel.
  ///
  /// In zh, this message translates to:
  /// **'灯光强度'**
  String get liquidGlassLightIntensityLabel;

  /// No description provided for @liquidGlassAmbientStrengthLabel.
  ///
  /// In zh, this message translates to:
  /// **'环境光强度'**
  String get liquidGlassAmbientStrengthLabel;

  /// No description provided for @liquidGlassRefractiveIndexLabel.
  ///
  /// In zh, this message translates to:
  /// **'折射率'**
  String get liquidGlassRefractiveIndexLabel;

  /// No description provided for @liquidGlassSaturationLabel.
  ///
  /// In zh, this message translates to:
  /// **'饱和度'**
  String get liquidGlassSaturationLabel;

  /// No description provided for @liquidGlassChromaticAberrationLabel.
  ///
  /// In zh, this message translates to:
  /// **'色差'**
  String get liquidGlassChromaticAberrationLabel;

  /// No description provided for @liquidGlassLightAngleLabel.
  ///
  /// In zh, this message translates to:
  /// **'光照角度'**
  String get liquidGlassLightAngleLabel;

  /// No description provided for @liquidGlassVisibilityLabel.
  ///
  /// In zh, this message translates to:
  /// **'可见性'**
  String get liquidGlassVisibilityLabel;

  /// No description provided for @liquidGlassResetAction.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认'**
  String get liquidGlassResetAction;

  /// No description provided for @diagnosticsEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'诊断'**
  String get diagnosticsEntryTitle;

  /// No description provided for @memoryStatsEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'内存状态'**
  String get memoryStatsEntryTitle;

  /// No description provided for @generalSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'通用'**
  String get generalSettingsTitle;

  /// No description provided for @settingsResetDefaultsTitle.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认设置'**
  String get settingsResetDefaultsTitle;

  /// No description provided for @settingsResetDefaultsConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认恢复'**
  String get settingsResetDefaultsConfirmTitle;

  /// No description provided for @settingsResetConfirmBodyCourseCard.
  ///
  /// In zh, this message translates to:
  /// **'将把课程卡片的显示字段、布局与颜色恢复为默认值。'**
  String get settingsResetConfirmBodyCourseCard;

  /// No description provided for @settingsResetConfirmBodyTimetablePage.
  ///
  /// In zh, this message translates to:
  /// **'将把课表页面的密度、回到当前周按钮与背景（含清除壁纸）恢复为默认值。'**
  String get settingsResetConfirmBodyTimetablePage;

  /// No description provided for @settingsResetConfirmBodyAppearance.
  ///
  /// In zh, this message translates to:
  /// **'将把主题模式、字体、主题色与玻璃质感恢复为默认值。'**
  String get settingsResetConfirmBodyAppearance;

  /// No description provided for @settingsResetConfirmBodyHomeWidget.
  ///
  /// In zh, this message translates to:
  /// **'将把桌面小组件的显示项与外观恢复为默认值。'**
  String get settingsResetConfirmBodyHomeWidget;

  /// No description provided for @settingsResetConfirmBodyHomeNavigation.
  ///
  /// In zh, this message translates to:
  /// **'将把底栏、菜单与首页标题设置恢复为默认值。'**
  String get settingsResetConfirmBodyHomeNavigation;

  /// No description provided for @settingsResetDoneMessage.
  ///
  /// In zh, this message translates to:
  /// **'设置已重置'**
  String get settingsResetDoneMessage;

  /// No description provided for @timetablePageSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'课表页面'**
  String get timetablePageSettingsTitle;

  /// No description provided for @timetablePageSectionDensity.
  ///
  /// In zh, this message translates to:
  /// **'密度'**
  String get timetablePageSectionDensity;

  /// No description provided for @timetablePageSectionBackToWeek.
  ///
  /// In zh, this message translates to:
  /// **'回到当前周'**
  String get timetablePageSectionBackToWeek;

  /// No description provided for @timetablePageSectionBackground.
  ///
  /// In zh, this message translates to:
  /// **'背景'**
  String get timetablePageSectionBackground;

  /// No description provided for @largeTitleContentGap.
  ///
  /// In zh, this message translates to:
  /// **'16.0'**
  String get largeTitleContentGap;

  /// No description provided for @selectTimeTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择时间'**
  String get selectTimeTitle;

  /// No description provided for @liveSelfCheckSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'运行自检'**
  String get liveSelfCheckSubtitle;

  /// No description provided for @frostedSheetPreviewShowTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示预览'**
  String get frostedSheetPreviewShowTitle;

  /// No description provided for @frostedSheetPreviewShowSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'在顶部显示磨砂玻璃预览'**
  String get frostedSheetPreviewShowSubtitle;

  /// No description provided for @aboutSupportUpdatesSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'支持与更新'**
  String get aboutSupportUpdatesSectionTitle;

  /// No description provided for @aboutProductSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'产品'**
  String get aboutProductSectionTitle;

  /// No description provided for @aboutCommunitySectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'社区'**
  String get aboutCommunitySectionTitle;

  /// No description provided for @selectStartTimeTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择开始时间'**
  String get selectStartTimeTitle;

  /// No description provided for @selectEndTimeTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择结束时间'**
  String get selectEndTimeTitle;

  /// No description provided for @weekdayInkContrastTitle.
  ///
  /// In zh, this message translates to:
  /// **'文字对比度不足'**
  String get weekdayInkContrastTitle;

  /// No description provided for @weekdayInkContrastBodyDark.
  ///
  /// In zh, this message translates to:
  /// **'你的信息栏文字颜色在深色壁纸上对比度不足，已临时切换为自动白色保证可读。可在「课表页面 → 文字颜色」中更换颜色或恢复默认。'**
  String get weekdayInkContrastBodyDark;

  /// No description provided for @weekdayInkContrastBodyLight.
  ///
  /// In zh, this message translates to:
  /// **'你的信息栏文字颜色在浅色壁纸上对比度不足，已临时切换为自动黑色保证可读。可在「课表页面 → 文字颜色」中更换颜色或恢复默认。'**
  String get weekdayInkContrastBodyLight;

  /// No description provided for @gotItAction.
  ///
  /// In zh, this message translates to:
  /// **'知道了'**
  String get gotItAction;

  /// No description provided for @settingsTimetableSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'课表'**
  String get settingsTimetableSectionTitle;

  /// No description provided for @liveIslandLabelEntryEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已开启'**
  String get liveIslandLabelEntryEnabled;

  /// No description provided for @liveIslandLabelEntryDisabled.
  ///
  /// In zh, this message translates to:
  /// **'已关闭'**
  String get liveIslandLabelEntryDisabled;

  /// No description provided for @settingsDisplayAppearanceSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'课表显示'**
  String get settingsDisplayAppearanceSectionTitle;

  /// No description provided for @settingsReminderDesktopSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'提醒与桌面'**
  String get settingsReminderDesktopSectionTitle;

  /// No description provided for @settingsAppSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get settingsAppSectionTitle;

  /// No description provided for @settingsDataShareSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'数据与共享'**
  String get settingsDataShareSectionTitle;

  /// No description provided for @coupleTimetableEntryUnboundLabel.
  ///
  /// In zh, this message translates to:
  /// **'未绑定'**
  String get coupleTimetableEntryUnboundLabel;

  /// No description provided for @settingsAboutSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get settingsAboutSectionTitle;

  /// No description provided for @diagnosticsEntrySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'日志 · 自检 · 内存'**
  String get diagnosticsEntrySubtitle;

  /// No description provided for @settingsSemesterScreenTitle.
  ///
  /// In zh, this message translates to:
  /// **'学期设置'**
  String get settingsSemesterScreenTitle;

  /// No description provided for @syncCurrentWeekNeedsStartDate.
  ///
  /// In zh, this message translates to:
  /// **'请先设置开学日期'**
  String get syncCurrentWeekNeedsStartDate;

  /// No description provided for @liveNotificationPermissionMissing.
  ///
  /// In zh, this message translates to:
  /// **'缺少通知权限'**
  String get liveNotificationPermissionMissing;

  /// No description provided for @developerSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'开发者选项'**
  String get developerSectionTitle;

  /// No description provided for @liveTestingFixtureEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'实况测试样例'**
  String get liveTestingFixtureEntryTitle;

  /// No description provided for @hyperosShowcaseEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'HyperOS 组件展示'**
  String get hyperosShowcaseEntryTitle;

  /// No description provided for @hyperosShowcaseEntrySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'HyperOS 组件预览'**
  String get hyperosShowcaseEntrySubtitle;

  /// No description provided for @miuixShowcaseEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'Miuix 组件展示'**
  String get miuixShowcaseEntryTitle;

  /// No description provided for @miuixShowcaseEntrySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'Miuix 组件预览'**
  String get miuixShowcaseEntrySubtitle;

  /// No description provided for @debugUiOverlayToggleTitle.
  ///
  /// In zh, this message translates to:
  /// **'调试 UI 叠层'**
  String get debugUiOverlayToggleTitle;

  /// No description provided for @scheduleRepeatSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'重复设置'**
  String get scheduleRepeatSectionTitle;

  /// No description provided for @scheduleRepeatNone.
  ///
  /// In zh, this message translates to:
  /// **'不重复'**
  String get scheduleRepeatNone;

  /// No description provided for @scheduleRepeatDaily.
  ///
  /// In zh, this message translates to:
  /// **'每天'**
  String get scheduleRepeatDaily;

  /// No description provided for @scheduleRepeatWeekly.
  ///
  /// In zh, this message translates to:
  /// **'每周'**
  String get scheduleRepeatWeekly;

  /// No description provided for @scheduleRepeatEndDateLabel.
  ///
  /// In zh, this message translates to:
  /// **'重复结束日期'**
  String get scheduleRepeatEndDateLabel;

  /// No description provided for @scheduleRepeatEndDateHint.
  ///
  /// In zh, this message translates to:
  /// **'重复日程需要设置结束日期'**
  String get scheduleRepeatEndDateHint;

  /// No description provided for @scheduleRepeatWeeklyHint.
  ///
  /// In zh, this message translates to:
  /// **'按开始日期对应的星期重复'**
  String get scheduleRepeatWeeklyHint;

  /// No description provided for @scheduleReminderSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'日程提醒'**
  String get scheduleReminderSectionTitle;

  /// No description provided for @scheduleReminderOff.
  ///
  /// In zh, this message translates to:
  /// **'不提醒'**
  String get scheduleReminderOff;

  /// No description provided for @scheduleReminderMinutes.
  ///
  /// In zh, this message translates to:
  /// **'提前 {minutes} 分钟'**
  String scheduleReminderMinutes(int minutes);

  /// No description provided for @scheduleReminderPermissionMissing.
  ///
  /// In zh, this message translates to:
  /// **'通知权限未开启，日程仍会保存，但提醒可能无法送达'**
  String get scheduleReminderPermissionMissing;

  /// No description provided for @scheduleReminderPermissionAction.
  ///
  /// In zh, this message translates to:
  /// **'检查通知权限'**
  String get scheduleReminderPermissionAction;

  /// No description provided for @scheduleEnabledTitle.
  ///
  /// In zh, this message translates to:
  /// **'启用日程'**
  String get scheduleEnabledTitle;

  /// No description provided for @scheduleDisabledSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'已暂停，不会显示提醒'**
  String get scheduleDisabledSubtitle;

  /// No description provided for @scheduleEditScopeTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑范围'**
  String get scheduleEditScopeTitle;

  /// No description provided for @scheduleEditScopeThis.
  ///
  /// In zh, this message translates to:
  /// **'仅本次'**
  String get scheduleEditScopeThis;

  /// No description provided for @scheduleEditScopeAll.
  ///
  /// In zh, this message translates to:
  /// **'全部重复日程'**
  String get scheduleEditScopeAll;

  /// No description provided for @scheduleDeleteScopeTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除范围'**
  String get scheduleDeleteScopeTitle;

  /// No description provided for @scheduleDeleteScopeThis.
  ///
  /// In zh, this message translates to:
  /// **'仅删除本次'**
  String get scheduleDeleteScopeThis;

  /// No description provided for @scheduleDeleteScopeAll.
  ///
  /// In zh, this message translates to:
  /// **'删除全部重复日程'**
  String get scheduleDeleteScopeAll;

  /// No description provided for @scheduleOccurrenceEditHint.
  ///
  /// In zh, this message translates to:
  /// **'你正在编辑这条重复日程的一次实例'**
  String get scheduleOccurrenceEditHint;

  /// No description provided for @scheduleRepeatEndRequired.
  ///
  /// In zh, this message translates to:
  /// **'请选择重复结束日期'**
  String get scheduleRepeatEndRequired;

  /// No description provided for @homeMenuTasksTitle.
  ///
  /// In zh, this message translates to:
  /// **'任务清单'**
  String get homeMenuTasksTitle;

  /// No description provided for @taskListTitle.
  ///
  /// In zh, this message translates to:
  /// **'任务清单'**
  String get taskListTitle;

  /// No description provided for @addTask.
  ///
  /// In zh, this message translates to:
  /// **'添加任务'**
  String get addTask;

  /// No description provided for @editTask.
  ///
  /// In zh, this message translates to:
  /// **'编辑任务'**
  String get editTask;

  /// No description provided for @saveTask.
  ///
  /// In zh, this message translates to:
  /// **'保存任务'**
  String get saveTask;

  /// No description provided for @taskTitleLabel.
  ///
  /// In zh, this message translates to:
  /// **'任务标题'**
  String get taskTitleLabel;

  /// No description provided for @taskTitleHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：完成第三章习题'**
  String get taskTitleHint;

  /// No description provided for @taskTitleRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入任务标题'**
  String get taskTitleRequired;

  /// No description provided for @taskNoteLabel.
  ///
  /// In zh, this message translates to:
  /// **'备注'**
  String get taskNoteLabel;

  /// No description provided for @taskNoteHint.
  ///
  /// In zh, this message translates to:
  /// **'补充说明（可选）'**
  String get taskNoteHint;

  /// No description provided for @taskDueDateLabel.
  ///
  /// In zh, this message translates to:
  /// **'截止日期'**
  String get taskDueDateLabel;

  /// No description provided for @taskNoDueDate.
  ///
  /// In zh, this message translates to:
  /// **'无截止日期'**
  String get taskNoDueDate;

  /// No description provided for @taskCourseLabel.
  ///
  /// In zh, this message translates to:
  /// **'来源课程'**
  String get taskCourseLabel;

  /// No description provided for @taskCourseFilter.
  ///
  /// In zh, this message translates to:
  /// **'课程筛选'**
  String get taskCourseFilter;

  /// No description provided for @taskAllCourses.
  ///
  /// In zh, this message translates to:
  /// **'全部课程'**
  String get taskAllCourses;

  /// No description provided for @taskNoCourse.
  ///
  /// In zh, this message translates to:
  /// **'无关联课程'**
  String get taskNoCourse;

  /// No description provided for @taskAllFilter.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get taskAllFilter;

  /// No description provided for @taskTodayFilter.
  ///
  /// In zh, this message translates to:
  /// **'今日'**
  String get taskTodayFilter;

  /// No description provided for @taskWeekFilter.
  ///
  /// In zh, this message translates to:
  /// **'本周'**
  String get taskWeekFilter;

  /// No description provided for @taskOverdueSection.
  ///
  /// In zh, this message translates to:
  /// **'已逾期'**
  String get taskOverdueSection;

  /// No description provided for @taskCompletedSection.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get taskCompletedSection;

  /// No description provided for @taskNoTasks.
  ///
  /// In zh, this message translates to:
  /// **'还没有任务'**
  String get taskNoTasks;

  /// No description provided for @taskNoTasksForToday.
  ///
  /// In zh, this message translates to:
  /// **'今日没有待办任务'**
  String get taskNoTasksForToday;

  /// No description provided for @taskNoTasksForWeek.
  ///
  /// In zh, this message translates to:
  /// **'本周没有待办任务'**
  String get taskNoTasksForWeek;

  /// No description provided for @taskNoTasksForCourse.
  ///
  /// In zh, this message translates to:
  /// **'这个课程暂无任务'**
  String get taskNoTasksForCourse;

  /// No description provided for @taskDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除任务'**
  String get taskDelete;

  /// No description provided for @taskDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定删除这个任务吗？'**
  String get taskDeleteConfirm;

  /// No description provided for @taskHomeworkDefaultTitle.
  ///
  /// In zh, this message translates to:
  /// **'课程作业'**
  String get taskHomeworkDefaultTitle;

  /// No description provided for @taskAddFromCourse.
  ///
  /// In zh, this message translates to:
  /// **'添加任务'**
  String get taskAddFromCourse;

  /// No description provided for @taskViewCourse.
  ///
  /// In zh, this message translates to:
  /// **'查看课程'**
  String get taskViewCourse;

  /// No description provided for @taskSaved.
  ///
  /// In zh, this message translates to:
  /// **'任务已保存'**
  String get taskSaved;

  /// No description provided for @taskUpdated.
  ///
  /// In zh, this message translates to:
  /// **'任务已更新'**
  String get taskUpdated;

  /// No description provided for @taskDeleted.
  ///
  /// In zh, this message translates to:
  /// **'任务已删除'**
  String get taskDeleted;

  /// No description provided for @icsExportSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'导出日历'**
  String get icsExportSectionTitle;

  /// No description provided for @icsExportSectionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'选择课程、考试和日程，生成 ICS 日历并分享'**
  String get icsExportSectionSubtitle;

  /// No description provided for @icsExportTitle.
  ///
  /// In zh, this message translates to:
  /// **'导出日历'**
  String get icsExportTitle;

  /// No description provided for @icsExportProfileLabel.
  ///
  /// In zh, this message translates to:
  /// **'课表'**
  String get icsExportProfileLabel;

  /// No description provided for @icsExportProfileSelectTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择课表'**
  String get icsExportProfileSelectTitle;

  /// No description provided for @icsExportDateRangeTitle.
  ///
  /// In zh, this message translates to:
  /// **'日期范围'**
  String get icsExportDateRangeTitle;

  /// No description provided for @icsExportStartDate.
  ///
  /// In zh, this message translates to:
  /// **'开始日期'**
  String get icsExportStartDate;

  /// No description provided for @icsExportEndDate.
  ///
  /// In zh, this message translates to:
  /// **'结束日期'**
  String get icsExportEndDate;

  /// No description provided for @icsExportTypesTitle.
  ///
  /// In zh, this message translates to:
  /// **'日历内容'**
  String get icsExportTypesTitle;

  /// No description provided for @icsExportCourses.
  ///
  /// In zh, this message translates to:
  /// **'课程'**
  String get icsExportCourses;

  /// No description provided for @icsExportExams.
  ///
  /// In zh, this message translates to:
  /// **'考试'**
  String get icsExportExams;

  /// No description provided for @icsExportSchedules.
  ///
  /// In zh, this message translates to:
  /// **'日程'**
  String get icsExportSchedules;

  /// No description provided for @icsExportButton.
  ///
  /// In zh, this message translates to:
  /// **'导出并分享'**
  String get icsExportButton;

  /// No description provided for @icsExportSharing.
  ///
  /// In zh, this message translates to:
  /// **'准备日历…'**
  String get icsExportSharing;

  /// No description provided for @icsExportNoProfiles.
  ///
  /// In zh, this message translates to:
  /// **'暂无可导出的课表'**
  String get icsExportNoProfiles;

  /// No description provided for @icsExportDateRangeInvalid.
  ///
  /// In zh, this message translates to:
  /// **'请选择不早于开始日期的结束日期'**
  String get icsExportDateRangeInvalid;

  /// No description provided for @icsExportNoSelection.
  ///
  /// In zh, this message translates to:
  /// **'至少选择一种日历内容'**
  String get icsExportNoSelection;

  /// No description provided for @icsExportSemesterStartRequired.
  ///
  /// In zh, this message translates to:
  /// **'导出课程前，请先设置学期开始日期'**
  String get icsExportSemesterStartRequired;

  /// No description provided for @icsExportNoEvents.
  ///
  /// In zh, this message translates to:
  /// **'所选日期范围内没有日历事件'**
  String get icsExportNoEvents;

  /// No description provided for @icsExportCancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消分享日历'**
  String get icsExportCancelled;

  /// No description provided for @icsExportFailed.
  ///
  /// In zh, this message translates to:
  /// **'日历导出失败，请稍后重试'**
  String get icsExportFailed;

  /// No description provided for @icsExportShared.
  ///
  /// In zh, this message translates to:
  /// **'已导出并分享 {count} 个日历事件'**
  String icsExportShared(int count);

  /// No description provided for @icsExportShareText.
  ///
  /// In zh, this message translates to:
  /// **'这是来自轻屿课表的日历文件'**
  String get icsExportShareText;

  /// No description provided for @icsExportShareSubject.
  ///
  /// In zh, this message translates to:
  /// **'轻屿课表日历'**
  String get icsExportShareSubject;

  /// No description provided for @homeNavigationTitle.
  ///
  /// In zh, this message translates to:
  /// **'首页与导航'**
  String get homeNavigationTitle;

  /// No description provided for @homeMenuCustomizeSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'右上角菜单'**
  String get homeMenuCustomizeSectionTitle;

  /// No description provided for @homeNavigationSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'底栏形态、菜单与首页标题'**
  String get homeNavigationSubtitle;

  /// No description provided for @homeNavigationFormLabel.
  ///
  /// In zh, this message translates to:
  /// **'应用形态'**
  String get homeNavigationFormLabel;

  /// No description provided for @homeNavigationFormClassic.
  ///
  /// In zh, this message translates to:
  /// **'经典形态'**
  String get homeNavigationFormClassic;

  /// No description provided for @homeNavigationFormClassicSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'保持现有的页面与导航方式'**
  String get homeNavigationFormClassicSubtitle;

  /// No description provided for @homeNavigationFormGlassDock.
  ///
  /// In zh, this message translates to:
  /// **'玻璃坞'**
  String get homeNavigationFormGlassDock;

  /// No description provided for @homeNavigationFormGlassDockSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'悬浮玻璃底栏，切换日/周课表'**
  String get homeNavigationFormGlassDockSubtitle;

  /// No description provided for @glassDockTabWeek.
  ///
  /// In zh, this message translates to:
  /// **'周课表'**
  String get glassDockTabWeek;

  /// No description provided for @glassDockTabDay.
  ///
  /// In zh, this message translates to:
  /// **'日课表'**
  String get glassDockTabDay;

  /// No description provided for @glassDockLayoutLabel.
  ///
  /// In zh, this message translates to:
  /// **'玻璃坞内容布局'**
  String get glassDockLayoutLabel;

  /// No description provided for @glassDockLayoutOverlay.
  ///
  /// In zh, this message translates to:
  /// **'满屏悬浮'**
  String get glassDockLayoutOverlay;

  /// No description provided for @glassDockLayoutOverlaySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'课表满屏显示，底栏浮动在课表之上'**
  String get glassDockLayoutOverlaySubtitle;

  /// No description provided for @glassDockLayoutInset.
  ///
  /// In zh, this message translates to:
  /// **'内容避让'**
  String get glassDockLayoutInset;

  /// No description provided for @glassDockLayoutInsetSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'课表底部预留空间，底栏悬浮在下方'**
  String get glassDockLayoutInsetSubtitle;

  /// No description provided for @glassDockInsetClearanceLabel.
  ///
  /// In zh, this message translates to:
  /// **'避让高度'**
  String get glassDockInsetClearanceLabel;

  /// No description provided for @glassDockRoundActionLabel.
  ///
  /// In zh, this message translates to:
  /// **'圆钮功能'**
  String get glassDockRoundActionLabel;

  /// No description provided for @glassDockButtonIconTitle.
  ///
  /// In zh, this message translates to:
  /// **'圆钮图标'**
  String get glassDockButtonIconTitle;

  /// No description provided for @glassDockButtonIconDefault.
  ///
  /// In zh, this message translates to:
  /// **'默认（加号）'**
  String get glassDockButtonIconDefault;

  /// No description provided for @glassDockButtonIconSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索图标名称'**
  String get glassDockButtonIconSearchHint;

  /// No description provided for @glassDockCustomizeSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'底部导航栏'**
  String get glassDockCustomizeSectionTitle;

  /// No description provided for @glassDockCustomizeTitle.
  ///
  /// In zh, this message translates to:
  /// **'自定义底栏按钮'**
  String get glassDockCustomizeTitle;

  /// No description provided for @homeDockEditorViewCategory.
  ///
  /// In zh, this message translates to:
  /// **'视图切换'**
  String get homeDockEditorViewCategory;

  /// No description provided for @glassDockEntriesSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'底栏入口'**
  String get glassDockEntriesSectionTitle;

  /// No description provided for @glassDockShowDayTabTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示日课表入口'**
  String get glassDockShowDayTabTitle;

  /// No description provided for @glassDockShowWeekTabTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示周课表入口'**
  String get glassDockShowWeekTabTitle;

  /// No description provided for @glassDockShowAddButtonTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示圆钮'**
  String get glassDockShowAddButtonTitle;

  /// No description provided for @glassDockShowAddButtonSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'在药丸右侧显示独立圆钮，功能与图标可在下方自定义'**
  String get glassDockShowAddButtonSubtitle;

  /// No description provided for @glassDockButtonBackToWeekLabel.
  ///
  /// In zh, this message translates to:
  /// **'回本周 / 今天'**
  String get glassDockButtonBackToWeekLabel;

  /// No description provided for @glassDockExtraButtonSemanticLabel.
  ///
  /// In zh, this message translates to:
  /// **'添加课程'**
  String get glassDockExtraButtonSemanticLabel;

  /// No description provided for @homeMenuStyleLabel.
  ///
  /// In zh, this message translates to:
  /// **'右上角菜单样式'**
  String get homeMenuStyleLabel;

  /// No description provided for @homeMenuStyleList.
  ///
  /// In zh, this message translates to:
  /// **'列表菜单'**
  String get homeMenuStyleList;

  /// No description provided for @homeMenuStyleGrid.
  ///
  /// In zh, this message translates to:
  /// **'八宫格菜单'**
  String get homeMenuStyleGrid;

  /// No description provided for @homeMenuStyleListSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'锚定列表，可自定义'**
  String get homeMenuStyleListSubtitle;

  /// No description provided for @homeMenuStyleGridSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'图标瓷贴，可自定义'**
  String get homeMenuStyleGridSubtitle;

  /// No description provided for @homeMenuCustomizeTitle.
  ///
  /// In zh, this message translates to:
  /// **'自定义菜单按钮'**
  String get homeMenuCustomizeTitle;

  /// No description provided for @homeGridCustomizeDetails.
  ///
  /// In zh, this message translates to:
  /// **'已启用 {count}/{max} 个'**
  String homeGridCustomizeDetails(int count, int max);

  /// No description provided for @homeGridEditorHintBody.
  ///
  /// In zh, this message translates to:
  /// **'最多放置 {max} 个按钮；按住条目拖动即可排序。'**
  String homeGridEditorHintBody(int max);

  /// No description provided for @homeGridEditorEnabledTitle.
  ///
  /// In zh, this message translates to:
  /// **'已启用'**
  String get homeGridEditorEnabledTitle;

  /// No description provided for @homeGridEditorAvailableTitle.
  ///
  /// In zh, this message translates to:
  /// **'可添加'**
  String get homeGridEditorAvailableTitle;

  /// No description provided for @homeGridEditorRemoveTooltip.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get homeGridEditorRemoveTooltip;

  /// No description provided for @homeGridEditorAddTooltip.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get homeGridEditorAddTooltip;

  /// No description provided for @homeGridEditorResetAction.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认排列'**
  String get homeGridEditorResetAction;

  /// No description provided for @homeGridEditorAllAdded.
  ///
  /// In zh, this message translates to:
  /// **'所有入口都已启用'**
  String get homeGridEditorAllAdded;

  /// No description provided for @homeGridEditorMaxReached.
  ///
  /// In zh, this message translates to:
  /// **'已达上限'**
  String get homeGridEditorMaxReached;

  /// No description provided for @homeGridEditorPinnedTooltip.
  ///
  /// In zh, this message translates to:
  /// **'此入口用于重新打开本页，不能移除'**
  String get homeGridEditorPinnedTooltip;

  /// No description provided for @homeMenuCategoryFeatures.
  ///
  /// In zh, this message translates to:
  /// **'功能入口'**
  String get homeMenuCategoryFeatures;

  /// No description provided for @homeMenuCategoryData.
  ///
  /// In zh, this message translates to:
  /// **'数据与同步'**
  String get homeMenuCategoryData;

  /// No description provided for @homeMenuCategoryPreferences.
  ///
  /// In zh, this message translates to:
  /// **'偏好设置'**
  String get homeMenuCategoryPreferences;

  /// No description provided for @homeMenuCategoryAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于与支持'**
  String get homeMenuCategoryAbout;

  /// No description provided for @classAlarmLeadMinutesLabel.
  ///
  /// In zh, this message translates to:
  /// **'提前 {minutes} 分钟'**
  String classAlarmLeadMinutesLabel(int minutes);

  /// No description provided for @classAlarmInvalidTimeToast.
  ///
  /// In zh, this message translates to:
  /// **'这门课的节次超出时间模板，无法设置闹钟'**
  String get classAlarmInvalidTimeToast;

  /// No description provided for @classAlarmSheetTitle.
  ///
  /// In zh, this message translates to:
  /// **'上课提醒'**
  String get classAlarmSheetTitle;

  /// No description provided for @classAlarmQuickOption.
  ///
  /// In zh, this message translates to:
  /// **'上课前 {minutes} 分钟提醒'**
  String classAlarmQuickOption(Object minutes);

  /// No description provided for @classAlarmCustomOption.
  ///
  /// In zh, this message translates to:
  /// **'自定义提醒时间…'**
  String get classAlarmCustomOption;

  /// No description provided for @classAlarmExistingLabel.
  ///
  /// In zh, this message translates to:
  /// **'已设提醒：{time}'**
  String classAlarmExistingLabel(Object time);

  /// No description provided for @classAlarmSetToast.
  ///
  /// In zh, this message translates to:
  /// **'提醒已设置'**
  String get classAlarmSetToast;

  /// No description provided for @classAlarmRemovedToast.
  ///
  /// In zh, this message translates to:
  /// **'已取消这节课的提醒'**
  String get classAlarmRemovedToast;

  /// No description provided for @classAlarmPastToast.
  ///
  /// In zh, this message translates to:
  /// **'所选时间已经过了，请换一个时间'**
  String get classAlarmPastToast;

  /// No description provided for @classAlarmNoSemesterToast.
  ///
  /// In zh, this message translates to:
  /// **'请先在设置中填写学期开始日期'**
  String get classAlarmNoSemesterToast;

  /// No description provided for @classAlarmActionLabel.
  ///
  /// In zh, this message translates to:
  /// **'设这节课的闹钟'**
  String get classAlarmActionLabel;

  /// No description provided for @classAlarmConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'将在系统时钟创建：{detail}。系统闹钟无法识别假期与调休，停课期间照常响铃；删除请在系统时钟中完成。'**
  String classAlarmConfirmMessage(String detail);

  /// No description provided for @classAlarmVariableSuffix.
  ///
  /// In zh, this message translates to:
  /// **'另外，{days}的第一节课时间在不同周不一致，这些天未创建闹钟。'**
  String classAlarmVariableSuffix(String days);

  /// No description provided for @classAlarmEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'上课闹钟'**
  String get classAlarmEntryTitle;

  /// No description provided for @classAlarmGroupSetup.
  ///
  /// In zh, this message translates to:
  /// **'添加闹钟'**
  String get classAlarmGroupSetup;

  /// No description provided for @classAlarmGroupBehavior.
  ///
  /// In zh, this message translates to:
  /// **'响铃行为'**
  String get classAlarmGroupBehavior;

  /// No description provided for @classAlarmAddAllTitle.
  ///
  /// In zh, this message translates to:
  /// **'批量添加上课闹钟'**
  String get classAlarmAddAllTitle;

  /// No description provided for @classAlarmRangeNext4Weeks.
  ///
  /// In zh, this message translates to:
  /// **'未来 4 周'**
  String get classAlarmRangeNext4Weeks;

  /// No description provided for @classAlarmRangeNext8Weeks.
  ///
  /// In zh, this message translates to:
  /// **'未来 8 周'**
  String get classAlarmRangeNext8Weeks;

  /// No description provided for @classAlarmRangeLabel.
  ///
  /// In zh, this message translates to:
  /// **'添加范围'**
  String get classAlarmRangeLabel;

  /// No description provided for @classAlarmRangeRemaining.
  ///
  /// In zh, this message translates to:
  /// **'本周起至学期结束'**
  String get classAlarmRangeRemaining;

  /// No description provided for @classAlarmRangeWhole.
  ///
  /// In zh, this message translates to:
  /// **'整学期'**
  String get classAlarmRangeWhole;

  /// No description provided for @classAlarmLeadTitle.
  ///
  /// In zh, this message translates to:
  /// **'提前量'**
  String get classAlarmLeadTitle;

  /// No description provided for @classAlarmSkipUiTitle.
  ///
  /// In zh, this message translates to:
  /// **'跳过确认页'**
  String get classAlarmSkipUiTitle;

  /// No description provided for @classAlarmSkipUiSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'尝试直接写入闹钟，不弹出时钟确认页（部分机型不支持）'**
  String get classAlarmSkipUiSubtitle;

  /// No description provided for @classAlarmOpenClock.
  ///
  /// In zh, this message translates to:
  /// **'打开系统时钟'**
  String get classAlarmOpenClock;

  /// No description provided for @classAlarmConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'创建重复闹钟？'**
  String get classAlarmConfirmTitle;

  /// No description provided for @classAlarmNoSchemeToast.
  ///
  /// In zh, this message translates to:
  /// **'请先在设置中选择时间模板'**
  String get classAlarmNoSchemeToast;

  /// No description provided for @classAlarmNoDataToast.
  ///
  /// In zh, this message translates to:
  /// **'所选范围内没有找到课表'**
  String get classAlarmNoDataToast;

  /// No description provided for @classAlarmAddedToast.
  ///
  /// In zh, this message translates to:
  /// **'已交给系统时钟处理'**
  String get classAlarmAddedToast;

  /// No description provided for @classAlarmLaunchFailedToast.
  ///
  /// In zh, this message translates to:
  /// **'未找到可处理的时钟应用'**
  String get classAlarmLaunchFailedToast;

  /// No description provided for @classAlarmCourseConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加这节课的重复闹钟？'**
  String get classAlarmCourseConfirmTitle;

  /// No description provided for @classAlarmCourseConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'将在系统时钟创建每周{weekday} {time} 的重复闹钟（比上课提前{lead}分钟响铃；上课周次：{weeks}）。假期与非上课周仍会响铃，删除需在系统时钟中完成。'**
  String classAlarmCourseConfirmMessage(
    String weekday,
    String time,
    int lead,
    String weeks,
  );

  /// No description provided for @classAlarmDaySeparator.
  ///
  /// In zh, this message translates to:
  /// **'、'**
  String get classAlarmDaySeparator;

  /// No description provided for @classAlarmDetailSeparator.
  ///
  /// In zh, this message translates to:
  /// **'；'**
  String get classAlarmDetailSeparator;
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
