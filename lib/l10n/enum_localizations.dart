import '../models/course.dart';
import '../models/exam.dart';
import 'package:university_timetable/models/liquid_glass_tuning.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import '../models/timetable_settings.dart';
import 'app_localizations.dart';

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
};

String appUpdateDownloadChannelDescription(
  AppLocalizations l10n,
  AppUpdateDownloadChannel channel,
) => switch (channel) {
  AppUpdateDownloadChannel.pgyer =>
    l10n.appUpdateDownloadChannelPgyerDescription,
  AppUpdateDownloadChannel.github =>
    l10n.appUpdateDownloadChannelGithubDescription,
};

String appUpdateMirrorPresetLabel(
  AppLocalizations l10n,
  AppUpdateMirrorPreset preset,
) => switch (preset) {
  AppUpdateMirrorPreset.ghfast => l10n.appUpdateMirrorPresetGhfast,
  AppUpdateMirrorPreset.ghproxyCn => l10n.appUpdateMirrorPresetGhproxyCn,
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
  AppUpdateMirrorPreset.ghproxyCn => ghproxyCnMirrorUrlPrefix,
  AppUpdateMirrorPreset.ghLlkk => ghLlkkMirrorUrlPrefix,
  AppUpdateMirrorPreset.ghProxyCom => ghProxyComMirrorUrlPrefix,
  AppUpdateMirrorPreset.ghproxyNet => ghproxyNetMirrorUrlPrefix,
  AppUpdateMirrorPreset.custom => l10n.appUpdateMirrorPresetCustomDescription,
};

String frostedGlassModeLabel(AppLocalizations l10n, FrostedGlassMode mode) =>
    switch (mode) {
      FrostedGlassMode.frosted => l10n.frostedGlassModeFrosted,
      FrostedGlassMode.liquidGlass => l10n.frostedGlassModeLiquid,
      FrostedGlassMode.gaussian => l10n.frostedGlassModeGaussian,
      FrostedGlassMode.translucent => l10n.frostedGlassModeTranslucent,
    };

String liquidGlassPresetLabel(
  AppLocalizations l10n,
  LiquidGlassPreset preset,
) => switch (preset) {
  LiquidGlassPreset.clear => l10n.liquidGlassPresetClear,
  LiquidGlassPreset.light => l10n.liquidGlassPresetLight,
  LiquidGlassPreset.standard => l10n.liquidGlassPresetStandard,
  LiquidGlassPreset.dense => l10n.liquidGlassPresetDense,
  LiquidGlassPreset.custom => l10n.liquidGlassPresetCustom,
};

String courseCardSurfaceStyleLabel(
  AppLocalizations l10n,
  CourseCardSurfaceStyle style,
) => switch (style) {
  CourseCardSurfaceStyle.solid => l10n.courseCardSurfaceStyleSolid,
  CourseCardSurfaceStyle.gaussian => l10n.courseCardSurfaceStyleGaussian,
};

String foruiThemeLabel(AppLocalizations l10n, ForuiTheme theme) =>
    switch (theme) {
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
