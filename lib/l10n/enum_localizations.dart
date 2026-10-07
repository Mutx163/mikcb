import '../models/bing_wallpaper.dart';
import '../models/course.dart';
import '../models/exam.dart';
import '../models/timetable_settings.dart';
import '../models/wallpaper_daily_source.dart';
import '../utils/widget_course_accent.dart';
import 'app_localizations.dart';

/// Bing 壁纸画质档位的胶囊文案。
///
/// 三档**各叫各的**（标准 / 适配 / 高清）：曾经把横屏的「超清」也译成「高清」，
/// 用户看到一排里出现两个「高清」直接问了「为啥有两个高清档位」（2026-10-06）。
/// 根因不是文案而是**多了一档没用的横屏**——横屏已从枚举里删掉，这里也随之简化。
///
/// ⚠️ 不要写「1x / 2x / 4x」这类倍数：三档里 `standard` 与 `tall` **宽度相同**、
/// 比例也不同（9:16 与 9:20），「几倍」是错的说法。
String bingWallpaperResolutionLabel(
  AppLocalizations l10n,
  BingWallpaperResolution resolution,
) => switch (resolution) {
  BingWallpaperResolution.standard => l10n.bingWallpaperResolutionStandard,
  BingWallpaperResolution.tall => l10n.bingWallpaperResolutionTall,
  BingWallpaperResolution.high => l10n.bingWallpaperResolutionHigh,
};

/// 每日壁纸**图源**的胶囊文案。
///
/// 两档各叫各的，且**不能**只用「高清 / 超清」那种画质词 —— 两者的差别**不在清晰度
/// 一项**：Wallhaven 更清晰（原生竖图、放大 1.0），Bing 是每天必换。所以名字各自点出
/// 自己那一项优势，用户一眼知道自己换来的是什么。
///
/// 同 `bingWallpaperResolutionLabel` 那条纪律：断言要钉在**用户看得见的这个值**上，
/// 别只钉枚举内部键（见 `test/l10n/arb_duplicate_key_test.dart` 里那次「两个高清」）。
String wallpaperDailySourceLabel(
  AppLocalizations l10n,
  WallpaperDailySource source,
) => switch (source) {
  WallpaperDailySource.bing => l10n.wallpaperDailySourceBing,
  WallpaperDailySource.wallhaven => l10n.wallpaperDailySourceWallhaven,
};

/// 图库入口行的标题**随图源变**。
///
/// 加了第二个源之后那行不能再说死「Bing 每日壁纸」—— 否则选 Wallhaven 的用户点进去
/// 看到的是另一个图库，而那一行还在说 Bing。
String wallpaperDailySourceGalleryLabel(
  AppLocalizations l10n,
  WallpaperDailySource source,
) => switch (source) {
  WallpaperDailySource.bing => l10n.bingWallpaperGalleryTitle,
  WallpaperDailySource.wallhaven => l10n.wallhavenWallpaperGalleryTitle,
};

String courseNatureLabel(AppLocalizations l10n, CourseNature nature) =>
    switch (nature) {
      CourseNature.required => l10n.courseNatureRequired,
      CourseNature.elective => l10n.courseNatureElective,
    };

String examReminderPresetLabel(
  AppLocalizations l10n,
  ExamReminderPreset preset,
) => switch (preset) {
  ExamReminderPreset.none => l10n.examReminderNone,
  ExamReminderPreset.min30 => l10n.examReminderMin30,
  ExamReminderPreset.hour1 => l10n.examReminderHour1,
  ExamReminderPreset.hour1AndMin30 => l10n.examReminderHour1AndMin30,
  ExamReminderPreset.day1 => l10n.examReminderDay1,
  ExamReminderPreset.day1AndHour1 => l10n.examReminderDay1AndHour1,
  ExamReminderPreset.custom => l10n.examReminderCustom,
};

String sectionTimeDisplayModeLabel(
  AppLocalizations l10n,
  SectionTimeDisplayMode mode,
) => switch (mode) {
  SectionTimeDisplayMode.hidden => l10n.sectionTimeDisplayHidden,
  SectionTimeDisplayMode.startOnly => l10n.sectionTimeDisplayStartOnly,
  SectionTimeDisplayMode.startAndEnd => l10n.sectionTimeDisplayStartAndEnd,
};

String widgetBackgroundStyleLabel(
  AppLocalizations l10n,
  WidgetBackgroundStyle style,
) => switch (style) {
  WidgetBackgroundStyle.glass => l10n.widgetBackgroundStyleGlass,
  WidgetBackgroundStyle.solid => l10n.widgetBackgroundStyleSolid,
  WidgetBackgroundStyle.gradient => l10n.widgetBackgroundStyleGradient,
};

/// 小组件「课程颜色」三档：关闭 / 仅色条 / 色条 + 文字。
String widgetCourseAccentModeLabel(
  AppLocalizations l10n,
  WidgetCourseAccentMode mode,
) => switch (mode) {
  WidgetCourseAccentMode.off => l10n.widgetCourseAccentModeOff,
  WidgetCourseAccentMode.bar => l10n.widgetCourseAccentModeBar,
  WidgetCourseAccentMode.barAndText => l10n.widgetCourseAccentModeBarAndText,
};

String appThemeModeLabel(AppLocalizations l10n, AppThemeMode mode) =>
    switch (mode) {
      AppThemeMode.system => l10n.themeModeSystem,
      AppThemeMode.light => l10n.themeModeLight,
      AppThemeMode.dark => l10n.themeModeDark,
    };

String appFontModeLabel(AppLocalizations l10n, AppFontMode mode) =>
    switch (mode) {
      AppFontMode.system => l10n.fontModeSystem,
      AppFontMode.sansSerif => l10n.fontModeSansSerif,
      AppFontMode.miSans => l10n.fontModeMiSans,
      AppFontMode.harmonyOS => l10n.fontModeHarmonyOS,
      AppFontMode.oppoSans => l10n.fontModeOppoSans,
      AppFontMode.pingFang => l10n.fontModePingFang,
      AppFontMode.notoSans => l10n.fontModeNotoSans,
      AppFontMode.serif => l10n.fontModeSerif,
      AppFontMode.songti => l10n.fontModeSongti,
      AppFontMode.monospace => l10n.fontModeMonospace,
    };

String homeTitleStyleLabel(AppLocalizations l10n, HomeTitleStyle style) =>
    switch (style) {
      HomeTitleStyle.classic => l10n.homeTitleStyleClassicLabel,
      HomeTitleStyle.brand => l10n.homeTitleStyleBrandLabel,
    };

String homeTitleStyleDescription(AppLocalizations l10n, HomeTitleStyle style) =>
    switch (style) {
      HomeTitleStyle.classic => l10n.homeTitleStyleClassicDescription,
      HomeTitleStyle.brand => l10n.homeTitleStyleBrandDescription,
    };

String liveDuringClassTimeDisplayModeLabel(
  AppLocalizations l10n,
  LiveDuringClassTimeDisplayMode mode,
) => switch (mode) {
  LiveDuringClassTimeDisplayMode.nearest => l10n.liveDuringClassTimeNearest,
  LiveDuringClassTimeDisplayMode.total => l10n.liveDuringClassTimeTotal,
};

String liveCountdownTextStyleLabel(
  AppLocalizations l10n,
  LiveCountdownTextStyle style,
) => switch (style) {
  LiveCountdownTextStyle.smart => l10n.liveCountdownTextStyleSmart,
  LiveCountdownTextStyle.smartMinS => l10n.liveCountdownTextStyleSmartMinS,
  LiveCountdownTextStyle.minuteSecondCn =>
    l10n.liveCountdownTextStyleMinuteSecondCn,
  LiveCountdownTextStyle.minuteSecondColon =>
    l10n.liveCountdownTextStyleMinuteSecondColon,
  LiveCountdownTextStyle.minuteSecondMinS =>
    l10n.liveCountdownTextStyleMinuteSecondMinS,
  LiveCountdownTextStyle.minuteSecondMinSlashS =>
    l10n.liveCountdownTextStyleMinuteSecondMinSlashS,
  LiveCountdownTextStyle.minuteOnlyCn =>
    l10n.liveCountdownTextStyleMinuteOnlyCn,
  LiveCountdownTextStyle.minuteOnlyMin =>
    l10n.liveCountdownTextStyleMinuteOnlyMin,
  LiveCountdownTextStyle.minuteOnlySlash =>
    l10n.liveCountdownTextStyleMinuteOnlySlash,
  LiveCountdownTextStyle.secondOnlyCn =>
    l10n.liveCountdownTextStyleSecondOnlyCn,
  LiveCountdownTextStyle.secondOnlyShort =>
    l10n.liveCountdownTextStyleSecondOnlyShort,
  LiveCountdownTextStyle.secondOnlySlash =>
    l10n.liveCountdownTextStyleSecondOnlySlash,
};

String miuiIslandLabelStyleLabel(
  AppLocalizations l10n,
  MiuiIslandLabelStyle style,
) => switch (style) {
  MiuiIslandLabelStyle.textOnly => l10n.miuiIslandLabelStyleTextOnly,
  MiuiIslandLabelStyle.iconAndText => l10n.miuiIslandLabelStyleIconAndText,
};

String miuiIslandLabelContentLabel(
  AppLocalizations l10n,
  MiuiIslandLabelContent content,
) => switch (content) {
  MiuiIslandLabelContent.courseName => l10n.miuiIslandLabelContentCourseName,
  MiuiIslandLabelContent.location => l10n.miuiIslandLabelContentLocation,
  MiuiIslandLabelContent.courseNameAndLocation =>
    l10n.miuiIslandLabelContentCourseNameAndLocation,
};

String miuiIslandLabelFontWeightLabel(
  AppLocalizations l10n,
  MiuiIslandLabelFontWeight weight,
) => switch (weight) {
  MiuiIslandLabelFontWeight.regular => l10n.miuiIslandLabelFontWeightRegular,
  MiuiIslandLabelFontWeight.medium => l10n.miuiIslandLabelFontWeightMedium,
  MiuiIslandLabelFontWeight.bold => l10n.miuiIslandLabelFontWeightBold,
};

String miuiIslandLabelRenderQualityLabel(
  AppLocalizations l10n,
  MiuiIslandLabelRenderQuality quality,
) => switch (quality) {
  MiuiIslandLabelRenderQuality.standard =>
    l10n.miuiIslandLabelRenderQualityStandard,
  MiuiIslandLabelRenderQuality.high => l10n.miuiIslandLabelRenderQualityHigh,
  MiuiIslandLabelRenderQuality.ultra => l10n.miuiIslandLabelRenderQualityUltra,
};

String miuiIslandExpandedIconModeLabel(
  AppLocalizations l10n,
  MiuiIslandExpandedIconMode mode,
) => switch (mode) {
  MiuiIslandExpandedIconMode.appIcon => l10n.miuiIslandExpandedIconAppIcon,
  MiuiIslandExpandedIconMode.customImage =>
    l10n.miuiIslandExpandedIconCustomImage,
  MiuiIslandExpandedIconMode.hidden => l10n.miuiIslandExpandedIconHidden,
};

String liveBeforeClassQuickActionLabel(
  AppLocalizations l10n,
  LiveBeforeClassQuickAction action,
) => switch (action) {
  LiveBeforeClassQuickAction.none => l10n.liveBeforeClassQuickActionNone,
  LiveBeforeClassQuickAction.silent => l10n.liveBeforeClassQuickActionSilent,
  LiveBeforeClassQuickAction.doNotDisturb =>
    l10n.liveBeforeClassQuickActionDoNotDisturb,
  LiveBeforeClassQuickAction.both => l10n.liveBeforeClassQuickActionBoth,
};

String liveExpandedDetailFieldLabel(
  AppLocalizations l10n,
  LiveExpandedDetailField field,
) => switch (field) {
  LiveExpandedDetailField.stage => l10n.liveExpandedDetailFieldStage,
  LiveExpandedDetailField.shortName => l10n.liveExpandedDetailFieldShortName,
  LiveExpandedDetailField.progress => l10n.liveExpandedDetailFieldProgress,
  LiveExpandedDetailField.status => l10n.liveExpandedDetailFieldStatus,
  LiveExpandedDetailField.time => l10n.liveExpandedDetailFieldTime,
  LiveExpandedDetailField.location => l10n.liveExpandedDetailFieldLocation,
  LiveExpandedDetailField.teacher => l10n.liveExpandedDetailFieldTeacher,
  LiveExpandedDetailField.nextCourse => l10n.liveExpandedDetailFieldNext,
  LiveExpandedDetailField.note => l10n.liveExpandedDetailFieldNote,
};

String courseCardVerticalAlignLabel(
  AppLocalizations l10n,
  CourseCardVerticalAlign align,
) => switch (align) {
  CourseCardVerticalAlign.top => l10n.courseCardVerticalAlignTop,
  CourseCardVerticalAlign.center => l10n.courseCardVerticalAlignCenter,
  CourseCardVerticalAlign.bottom => l10n.courseCardVerticalAlignBottom,
  CourseCardVerticalAlign.spaceEvenly =>
    l10n.courseCardVerticalAlignSpaceEvenly,
};

String courseCardHorizontalAlignLabel(
  AppLocalizations l10n,
  CourseCardHorizontalAlign align,
) => switch (align) {
  CourseCardHorizontalAlign.left => l10n.courseCardHorizontalAlignLeft,
  CourseCardHorizontalAlign.center => l10n.courseCardHorizontalAlignCenter,
  CourseCardHorizontalAlign.right => l10n.courseCardHorizontalAlignRight,
};

String timetableTimeColumnWidthModeLabel(
  AppLocalizations l10n,
  TimetableTimeColumnWidthMode mode,
) => switch (mode) {
  TimetableTimeColumnWidthMode.narrow => l10n.timetableTimeColumnWidthNarrow,
  TimetableTimeColumnWidthMode.wide => l10n.timetableTimeColumnWidthWide,
};

String timetableCourseSpacingModeLabel(
  AppLocalizations l10n,
  TimetableCourseSpacingMode mode,
) => switch (mode) {
  TimetableCourseSpacingMode.narrow => l10n.timetableCourseSpacingNarrow,
  TimetableCourseSpacingMode.wide => l10n.timetableCourseSpacingWide,
};

String appUpdateDownloadSourceLabel(
  AppLocalizations l10n,
  AppUpdateDownloadSource source,
) => switch (source) {
  AppUpdateDownloadSource.original => l10n.appUpdateDownloadSourceOriginal,
  AppUpdateDownloadSource.mirror => l10n.appUpdateDownloadSourceMirror,
};

String appUpdateDownloadChannelLabel(
  AppLocalizations l10n,
  AppUpdateDownloadChannel channel,
) => switch (channel) {
  AppUpdateDownloadChannel.pgyer => l10n.appUpdateDownloadChannelPgyer,
  AppUpdateDownloadChannel.github => l10n.appUpdateDownloadChannelGithub,
  AppUpdateDownloadChannel.gitcode => l10n.appUpdateDownloadChannelGitcode,
};

String appUpdateDownloadChannelDescription(
  AppLocalizations l10n,
  AppUpdateDownloadChannel channel,
) => switch (channel) {
  AppUpdateDownloadChannel.pgyer =>
    l10n.appUpdateDownloadChannelPgyerDescription,
  AppUpdateDownloadChannel.github =>
    l10n.appUpdateDownloadChannelGithubDescription,
  AppUpdateDownloadChannel.gitcode =>
    l10n.appUpdateDownloadChannelGitcodeDescription,
};

String appUpdateMirrorPresetLabel(
  AppLocalizations l10n,
  AppUpdateMirrorPreset preset,
) => switch (preset) {
  AppUpdateMirrorPreset.ghfast => l10n.appUpdateMirrorPresetGhfast,
  AppUpdateMirrorPreset.ghLlkk => l10n.appUpdateMirrorPresetGhLlkk,
  AppUpdateMirrorPreset.ghProxyCom => l10n.appUpdateMirrorPresetGhProxyCom,
  AppUpdateMirrorPreset.ghproxyNet => l10n.appUpdateMirrorPresetGhproxyNet,
  AppUpdateMirrorPreset.custom => l10n.appUpdateMirrorPresetCustom,
};

String appUpdateMirrorPresetDescription(
  AppLocalizations l10n,
  AppUpdateMirrorPreset preset,
) => switch (preset) {
  AppUpdateMirrorPreset.ghfast => defaultAppUpdateMirrorUrlPrefix,
  AppUpdateMirrorPreset.ghLlkk => ghLlkkMirrorUrlPrefix,
  AppUpdateMirrorPreset.ghProxyCom => ghProxyComMirrorUrlPrefix,
  AppUpdateMirrorPreset.ghproxyNet => ghproxyNetMirrorUrlPrefix,
  AppUpdateMirrorPreset.custom => l10n.appUpdateMirrorPresetCustomDescription,
};

// 档位**名字**的映射在 2026-10-05 删掉了：那一排胶囊换成了一根 10 格的节点滑杆，
// 读数只给「第几格」（用户口径：「不要名字，只用节点 + 数字」）。
// `l10n.liquidGlassPresetLabel`（"液态玻璃预设"）还在用 —— 它是滑杆那行的标题。
// `liquidGlassPreset{Clear,Light,Standard,Dense,Custom}` 五个词条随之无人引用，
// 但**故意留着**：删它们要重跑 l10n 生成，而生成文件此刻正被另一个会话改着。
// 等那边收工后连带这五个键一起清（连同 arb 里的六份翻译）。

String courseCardSurfaceStyleLabel(
  AppLocalizations l10n,
  CourseCardSurfaceStyle style,
) => switch (style) {
  CourseCardSurfaceStyle.solid => l10n.courseCardSurfaceStyleSolid,
  CourseCardSurfaceStyle.gaussian => l10n.courseCardSurfaceStyleGaussian,
  CourseCardSurfaceStyle.liquidGlass =>
    l10n.courseCardSurfaceStyleLiquidGlass,
};

String foruiThemeLabel(AppLocalizations l10n, ForuiTheme theme) =>
    switch (theme) {
      ForuiTheme.miui => l10n.foruiThemeMiuix,
      ForuiTheme.neutral => l10n.foruiThemeNeutral,
      ForuiTheme.zinc => l10n.foruiThemeZinc,
      ForuiTheme.slate => l10n.foruiThemeSlate,
      ForuiTheme.blue => l10n.foruiThemeBlue,
      ForuiTheme.green => l10n.foruiThemeGreen,
      ForuiTheme.orange => l10n.foruiThemeOrange,
      ForuiTheme.red => l10n.foruiThemeRed,
      ForuiTheme.rose => l10n.foruiThemeRose,
      ForuiTheme.violet => l10n.foruiThemeViolet,
      ForuiTheme.yellow => l10n.foruiThemeYellow,
    };
