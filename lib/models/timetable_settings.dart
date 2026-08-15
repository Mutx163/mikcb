import 'dart:convert';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:university_timetable/models/liquid_glass_tuning.dart';

enum AppUpdateDownloadSource { original, mirror }

enum AppUpdateDownloadChannel { pgyer, github }

enum AppUpdateMirrorPreset {
  ghfast,
  ghproxyCn,
  ghLlkk,
  ghProxyCom,
  ghproxyNet,
  custom,
}

enum WidgetBackgroundStyle { glass, solid, gradient }

enum AppThemeMode { system, light, dark }

enum AppFontMode {
  system,
  sansSerif,
  miSans,
  harmonyOS,
  oppoSans,
  pingFang,
  notoSans,
  serif,
  songti,
  monospace,
}

enum ForuiTheme {
  neutral,
  zinc,
  slate,
  blue,
  green,
  orange,
  red,
  rose,
  violet,
  yellow,
}

extension ForuiThemeX on ForuiTheme {
  String get value => name;

  /// Representative brand hex for this forui theme; synced into [TimetableSettings.themeSeedColor]
  /// and used to seed the Material ColorScheme so Material accents follow the forui theme.
  String get seedHex => switch (this) {
    ForuiTheme.neutral => '#171717',
    ForuiTheme.zinc => '#18181B',
    ForuiTheme.slate => '#0F172B',
    ForuiTheme.blue => '#1447E6',
    ForuiTheme.green => '#5EA500',
    ForuiTheme.orange => '#F54A00',
    ForuiTheme.red => '#E7000B',
    ForuiTheme.rose => '#EC003F',
    ForuiTheme.violet => '#7F22FE',
    ForuiTheme.yellow => '#FCC800',
  };

  static ForuiTheme fromValue(String? value) {
    return ForuiTheme.values.firstWhere(
      (item) => item.value == value,
      orElse: () => ForuiTheme.blue,
    );
  }
}

enum HomeTitleStyle { classic, brand }

enum HomePageBackgroundFill { color, image }

extension HomePageBackgroundFillX on HomePageBackgroundFill {
  String get value => name;

  static HomePageBackgroundFill fromValue(String? value) {
    return HomePageBackgroundFill.values.firstWhere(
      (item) => item.value == value,
      orElse: () => HomePageBackgroundFill.color,
    );
  }
}

/// Bit flags for home page background display regions.
abstract final class HomePageBackgroundScope {
  static const int timetable = 1;
  static const int weekdayBar = 2;
  static const int header = 4;
  static const int statusBar = 8;
  static const int defaultValue = timetable;

  static bool includes(int scope, int region) => (scope & region) != 0;

  static int toggle(int scope, int region, {required bool enabled}) {
    return enabled ? (scope | region) : (scope & ~region);
  }
}

enum TimetableHomeViewMode { week, day }

/// 首页导航形态：经典形态保持原样；玻璃坞形态在底部提供液态玻璃
/// 药丸导航，滑动/点击即可切换周课表、日课表与设置。
enum HomeNavigationForm { classic, glassDock }

enum BackToCurrentWeekButtonStyle { inline, floating }

enum SectionTimeDisplayMode { hidden, startOnly, startAndEnd }

enum LiveDuringClassTimeDisplayMode { nearest, total }

enum LiveCountdownTextStyle {
  smart,
  smartMinS,
  minuteSecondCn,
  minuteSecondColon,
  minuteSecondMinS,
  minuteSecondMinSlashS,
  minuteOnlyCn,
  minuteOnlyMin,
  minuteOnlySlash,
  secondOnlyCn,
  secondOnlyShort,
  secondOnlySlash,
}

enum MiuiIslandLabelStyle { textOnly, iconAndText }

enum MiuiIslandLabelContent { courseName, location, courseNameAndLocation }

enum MiuiIslandLabelFontWeight { regular, medium, bold }

enum MiuiIslandLabelRenderQuality { standard, high, ultra }

enum MiuiIslandExpandedIconMode { appIcon, customImage, hidden }

enum LiveBeforeClassQuickAction { none, silent, doNotDisturb }

const String defaultAppUpdateMirrorUrlPrefix = 'https://ghfast.top/';
const String ghproxyCnMirrorUrlPrefix = 'https://ghproxy.cn/';
const String ghLlkkMirrorUrlPrefix = 'https://gh.llkk.cc/';
const String ghProxyComMirrorUrlPrefix = 'https://gh-proxy.com/';
const String ghproxyNetMirrorUrlPrefix = 'https://ghproxy.net/';

String _normalizeAppLocaleTag(String? value) {
  final normalized = (value ?? '').trim();
  if (normalized.isEmpty || normalized == 'system') {
    return '';
  }
  final canonical = normalized.replaceAll('-', '_');
  final lower = canonical.toLowerCase();
  if (lower == 'en_us') return 'en';
  if (lower == 'zh_cn') return 'zh';
  return canonical;
}

String _normalizeMirrorUrlPrefixValue(String? value) {
  final normalized = (value ?? '').trim();
  if (normalized.isEmpty) {
    return '';
  }
  return normalized.endsWith('/')
      ? normalized.substring(0, normalized.length - 1)
      : normalized;
}

extension SectionTimeDisplayModeX on SectionTimeDisplayMode {
  String get value => switch (this) {
    SectionTimeDisplayMode.hidden => 'hidden',
    SectionTimeDisplayMode.startOnly => 'start_only',
    SectionTimeDisplayMode.startAndEnd => 'start_and_end',
  };

  static SectionTimeDisplayMode fromValue(String? value) {
    return SectionTimeDisplayMode.values.firstWhere(
      (item) => item.value == value,
      orElse: () => SectionTimeDisplayMode.startAndEnd,
    );
  }
}

extension WidgetBackgroundStyleX on WidgetBackgroundStyle {
  String get value => switch (this) {
    WidgetBackgroundStyle.glass => 'glass',
    WidgetBackgroundStyle.solid => 'solid',
    WidgetBackgroundStyle.gradient => 'gradient',
  };

  static WidgetBackgroundStyle fromValue(String? value) {
    return WidgetBackgroundStyle.values.firstWhere(
      (item) => item.value == value,
      orElse: () => WidgetBackgroundStyle.solid,
    );
  }
}

extension AppThemeModeX on AppThemeMode {
  String get value => switch (this) {
    AppThemeMode.system => 'system',
    AppThemeMode.light => 'light',
    AppThemeMode.dark => 'dark',
  };

  static AppThemeMode fromValue(String? value) {
    return AppThemeMode.values.firstWhere(
      (item) => item.value == value,
      orElse: () => AppThemeMode.system,
    );
  }
}

extension AppFontModeX on AppFontMode {
  String get value => switch (this) {
    AppFontMode.system => 'system',
    AppFontMode.sansSerif => 'sans_serif',
    AppFontMode.miSans => 'mi_sans',
    AppFontMode.harmonyOS => 'harmony_os',
    AppFontMode.oppoSans => 'oppo_sans',
    AppFontMode.pingFang => 'ping_fang',
    AppFontMode.notoSans => 'noto_sans',
    AppFontMode.serif => 'serif',
    AppFontMode.songti => 'songti',
    AppFontMode.monospace => 'monospace',
  };

  static AppFontMode fromValue(String? value) {
    return AppFontMode.values.firstWhere(
      (item) => item.value == value,
      orElse: () => AppFontMode.system,
    );
  }
}

extension HomeTitleStyleX on HomeTitleStyle {
  String get value => switch (this) {
    HomeTitleStyle.classic => 'classic',
    HomeTitleStyle.brand => 'brand',
  };

  static HomeTitleStyle fromValue(String? value) {
    return HomeTitleStyle.values.firstWhere(
      (item) => item.value == value,
      orElse: () => HomeTitleStyle.classic,
    );
  }
}

extension TimetableHomeViewModeX on TimetableHomeViewMode {
  String get value => switch (this) {
    TimetableHomeViewMode.week => 'week',
    TimetableHomeViewMode.day => 'day',
  };

  static TimetableHomeViewMode fromValue(String? value) {
    return TimetableHomeViewMode.values.firstWhere(
      (item) => item.value == value,
      orElse: () => TimetableHomeViewMode.week,
    );
  }
}

extension HomeNavigationFormX on HomeNavigationForm {
  String get value => switch (this) {
    HomeNavigationForm.classic => 'classic',
    HomeNavigationForm.glassDock => 'glass_dock',
  };

  static HomeNavigationForm fromValue(String? value) {
    return HomeNavigationForm.values.firstWhere(
      (item) => item.value == value,
      orElse: () => HomeNavigationForm.classic,
    );
  }
}

extension BackToCurrentWeekButtonStyleX on BackToCurrentWeekButtonStyle {
  String get value => switch (this) {
    BackToCurrentWeekButtonStyle.inline => 'inline',
    BackToCurrentWeekButtonStyle.floating => 'floating',
  };

  static BackToCurrentWeekButtonStyle fromValue(String? value) {
    return BackToCurrentWeekButtonStyle.values.firstWhere(
      (item) => item.value == value,
      orElse: () => BackToCurrentWeekButtonStyle.inline,
    );
  }
}

extension LiveDuringClassTimeDisplayModeX on LiveDuringClassTimeDisplayMode {
  String get value => switch (this) {
    LiveDuringClassTimeDisplayMode.nearest => 'nearest',
    LiveDuringClassTimeDisplayMode.total => 'total',
  };

  static LiveDuringClassTimeDisplayMode fromValue(String? value) {
    return LiveDuringClassTimeDisplayMode.values.firstWhere(
      (item) => item.value == value,
      orElse: () => LiveDuringClassTimeDisplayMode.nearest,
    );
  }
}

extension LiveCountdownTextStyleX on LiveCountdownTextStyle {
  String get value => switch (this) {
    LiveCountdownTextStyle.smart => 'smart',
    LiveCountdownTextStyle.smartMinS => 'smart_min_s',
    LiveCountdownTextStyle.minuteSecondCn => 'minute_second_cn',
    LiveCountdownTextStyle.minuteSecondColon => 'minute_second_colon',
    LiveCountdownTextStyle.minuteSecondMinS => 'minute_second_min_s',
    LiveCountdownTextStyle.minuteSecondMinSlashS => 'minute_second_min_slash_s',
    LiveCountdownTextStyle.minuteOnlyCn => 'minute_only_cn',
    LiveCountdownTextStyle.minuteOnlyMin => 'minute_only_min',
    LiveCountdownTextStyle.minuteOnlySlash => 'minute_only_slash',
    LiveCountdownTextStyle.secondOnlyCn => 'second_only_cn',
    LiveCountdownTextStyle.secondOnlyShort => 'second_only_short',
    LiveCountdownTextStyle.secondOnlySlash => 'second_only_slash',
  };

  bool get alwaysShowsSeconds => switch (this) {
    LiveCountdownTextStyle.minuteSecondCn ||
    LiveCountdownTextStyle.minuteSecondColon ||
    LiveCountdownTextStyle.minuteSecondMinS ||
    LiveCountdownTextStyle.minuteSecondMinSlashS ||
    LiveCountdownTextStyle.secondOnlyCn ||
    LiveCountdownTextStyle.secondOnlyShort ||
    LiveCountdownTextStyle.secondOnlySlash => true,
    _ => false,
  };

  static LiveCountdownTextStyle fromValue(String? value) {
    return LiveCountdownTextStyle.values.firstWhere(
      (item) => item.value == value,
      orElse: () => LiveCountdownTextStyle.smart,
    );
  }
}

extension MiuiIslandLabelStyleX on MiuiIslandLabelStyle {
  String get value => switch (this) {
    MiuiIslandLabelStyle.textOnly => 'text_only',
    MiuiIslandLabelStyle.iconAndText => 'icon_and_text',
  };

  static MiuiIslandLabelStyle fromValue(String? value) {
    return MiuiIslandLabelStyle.values.firstWhere(
      (item) => item.value == value,
      orElse: () => MiuiIslandLabelStyle.textOnly,
    );
  }
}

extension MiuiIslandLabelContentX on MiuiIslandLabelContent {
  String get value => switch (this) {
    MiuiIslandLabelContent.courseName => 'course_name',
    MiuiIslandLabelContent.location => 'location',
    MiuiIslandLabelContent.courseNameAndLocation => 'course_name_and_location',
  };

  static MiuiIslandLabelContent fromValue(String? value) {
    return MiuiIslandLabelContent.values.firstWhere(
      (item) => item.value == value,
      orElse: () => MiuiIslandLabelContent.courseName,
    );
  }
}

extension MiuiIslandLabelFontWeightX on MiuiIslandLabelFontWeight {
  String get value => switch (this) {
    MiuiIslandLabelFontWeight.regular => 'regular',
    MiuiIslandLabelFontWeight.medium => 'medium',
    MiuiIslandLabelFontWeight.bold => 'bold',
  };

  static MiuiIslandLabelFontWeight fromValue(String? value) {
    return MiuiIslandLabelFontWeight.values.firstWhere(
      (item) => item.value == value,
      orElse: () => MiuiIslandLabelFontWeight.bold,
    );
  }
}

extension MiuiIslandLabelRenderQualityX on MiuiIslandLabelRenderQuality {
  String get value => switch (this) {
    MiuiIslandLabelRenderQuality.standard => 'standard',
    MiuiIslandLabelRenderQuality.high => 'high',
    MiuiIslandLabelRenderQuality.ultra => 'ultra',
  };

  static MiuiIslandLabelRenderQuality fromValue(String? value) {
    return MiuiIslandLabelRenderQuality.values.firstWhere(
      (item) => item.value == value,
      orElse: () => MiuiIslandLabelRenderQuality.standard,
    );
  }
}

extension MiuiIslandExpandedIconModeX on MiuiIslandExpandedIconMode {
  String get value => switch (this) {
    MiuiIslandExpandedIconMode.appIcon => 'app_icon',
    MiuiIslandExpandedIconMode.customImage => 'custom_image',
    MiuiIslandExpandedIconMode.hidden => 'hidden',
  };

  static MiuiIslandExpandedIconMode fromValue(String? value) {
    return MiuiIslandExpandedIconMode.values.firstWhere(
      (item) => item.value == value,
      orElse: () => MiuiIslandExpandedIconMode.appIcon,
    );
  }
}

extension LiveBeforeClassQuickActionX on LiveBeforeClassQuickAction {
  String get value => switch (this) {
    LiveBeforeClassQuickAction.none => 'none',
    LiveBeforeClassQuickAction.silent => 'silent',
    LiveBeforeClassQuickAction.doNotDisturb => 'do_not_disturb',
  };

  static LiveBeforeClassQuickAction fromValue(String? value) {
    return LiveBeforeClassQuickAction.values.firstWhere(
      (item) => item.value == value,
      orElse: () => LiveBeforeClassQuickAction.none,
    );
  }
}

/// Visual surface style for course cards.
enum CourseCardSurfaceStyle {
  /// Solid opaque card with gradient wash (default).
  solid,

  /// Semi-transparent milky card.
  translucent,

  /// Gaussian blur backdrop over the page background.
  gaussian,

  /// 玻璃卡片：液态玻璃模式用与弹窗/顶部同款的液态玻璃材质；
  /// 标准/高斯材质模式退化为高斯模糊卡片（跟随全局高级材质设置）。
  glass,
}

extension CourseCardSurfaceStyleX on CourseCardSurfaceStyle {
  String get value => name;

  static CourseCardSurfaceStyle fromValue(String? value) {
    // Older settings may contain the legacy liquid-glass card style.
    // 恢复为玻璃卡片（跟随全局高级材质设置渲染）。
    if (value == 'liquidGlass') {
      return CourseCardSurfaceStyle.glass;
    }
    return CourseCardSurfaceStyle.values.firstWhere(
      (item) => item.value == value,
      orElse: () => CourseCardSurfaceStyle.solid,
    );
  }
}

enum CourseCardVerticalAlign { top, center, bottom, spaceEvenly }

extension CourseCardVerticalAlignX on CourseCardVerticalAlign {
  String get value => switch (this) {
    CourseCardVerticalAlign.top => 'top',
    CourseCardVerticalAlign.center => 'center',
    CourseCardVerticalAlign.bottom => 'bottom',
    CourseCardVerticalAlign.spaceEvenly => 'space_evenly',
  };

  static CourseCardVerticalAlign fromValue(String? value) {
    return CourseCardVerticalAlign.values.firstWhere(
      (item) => item.value == value,
      orElse: () => CourseCardVerticalAlign.center,
    );
  }
}

enum CourseCardHorizontalAlign { left, center, right }

extension CourseCardHorizontalAlignX on CourseCardHorizontalAlign {
  String get value => switch (this) {
    CourseCardHorizontalAlign.left => 'left',
    CourseCardHorizontalAlign.center => 'center',
    CourseCardHorizontalAlign.right => 'right',
  };

  static CourseCardHorizontalAlign fromValue(String? value) {
    return CourseCardHorizontalAlign.values.firstWhere(
      (item) => item.value == value,
      orElse: () => CourseCardHorizontalAlign.center,
    );
  }
}

enum TimetableTimeColumnWidthMode { narrow, wide }

extension TimetableTimeColumnWidthModeX on TimetableTimeColumnWidthMode {
  String get value => switch (this) {
    TimetableTimeColumnWidthMode.narrow => 'narrow',
    TimetableTimeColumnWidthMode.wide => 'wide',
  };

  static TimetableTimeColumnWidthMode fromValue(String? value) {
    return TimetableTimeColumnWidthMode.values.firstWhere(
      (item) => item.value == value,
      orElse: () => TimetableTimeColumnWidthMode.narrow,
    );
  }
}

enum TimetableCourseSpacingMode { narrow, wide }

extension TimetableCourseSpacingModeX on TimetableCourseSpacingMode {
  String get value => switch (this) {
    TimetableCourseSpacingMode.narrow => 'narrow',
    TimetableCourseSpacingMode.wide => 'wide',
  };

  static TimetableCourseSpacingMode fromValue(String? value) {
    return TimetableCourseSpacingMode.values.firstWhere(
      (item) => item.value == value,
      orElse: () => TimetableCourseSpacingMode.narrow,
    );
  }
}

extension AppUpdateDownloadSourceX on AppUpdateDownloadSource {
  String get value => switch (this) {
    AppUpdateDownloadSource.original => 'original',
    AppUpdateDownloadSource.mirror => 'mirror',
  };

  static AppUpdateDownloadSource fromValue(String? value) {
    return AppUpdateDownloadSource.values.firstWhere(
      (item) => item.value == value,
      orElse: () => AppUpdateDownloadSource.mirror,
    );
  }
}

extension AppUpdateDownloadChannelX on AppUpdateDownloadChannel {
  String get value => switch (this) {
    AppUpdateDownloadChannel.pgyer => 'pgyer',
    AppUpdateDownloadChannel.github => 'github',
  };

  static AppUpdateDownloadChannel fromValue(String? value) {
    return AppUpdateDownloadChannel.values.firstWhere(
      (item) => item.value == value,
      orElse: () => AppUpdateDownloadChannel.pgyer,
    );
  }
}

extension AppUpdateMirrorPresetX on AppUpdateMirrorPreset {
  String get value => switch (this) {
    AppUpdateMirrorPreset.ghfast => 'ghfast',
    AppUpdateMirrorPreset.ghproxyCn => 'ghproxy_cn',
    AppUpdateMirrorPreset.ghLlkk => 'gh_llkk',
    AppUpdateMirrorPreset.ghProxyCom => 'gh_proxy_com',
    AppUpdateMirrorPreset.ghproxyNet => 'ghproxy_net',
    AppUpdateMirrorPreset.custom => 'custom',
  };

  bool get usesCustomUrl => this == AppUpdateMirrorPreset.custom;

  static AppUpdateMirrorPreset fromValue(String? value) {
    return AppUpdateMirrorPreset.values.firstWhere(
      (item) => item.value == value,
      orElse: () => AppUpdateMirrorPreset.ghfast,
    );
  }

  static AppUpdateMirrorPreset fromUrlPrefix(String? urlPrefix) {
    final normalized = _normalizeMirrorUrlPrefixValue(urlPrefix);
    if (normalized.isEmpty ||
        normalized ==
            _normalizeMirrorUrlPrefixValue(defaultAppUpdateMirrorUrlPrefix)) {
      return AppUpdateMirrorPreset.ghfast;
    }
    if (normalized ==
        _normalizeMirrorUrlPrefixValue(ghproxyCnMirrorUrlPrefix)) {
      return AppUpdateMirrorPreset.ghproxyCn;
    }
    if (normalized == _normalizeMirrorUrlPrefixValue(ghLlkkMirrorUrlPrefix)) {
      return AppUpdateMirrorPreset.ghLlkk;
    }
    if (normalized ==
        _normalizeMirrorUrlPrefixValue(ghProxyComMirrorUrlPrefix)) {
      return AppUpdateMirrorPreset.ghProxyCom;
    }
    if (normalized ==
        _normalizeMirrorUrlPrefixValue(ghproxyNetMirrorUrlPrefix)) {
      return AppUpdateMirrorPreset.ghproxyNet;
    }
    return AppUpdateMirrorPreset.custom;
  }
}

String resolveAppUpdateMirrorUrlPrefix({
  required AppUpdateMirrorPreset preset,
  required String customUrlPrefix,
}) {
  final normalizedCustomUrlPrefix = customUrlPrefix.trim();
  return switch (preset) {
    AppUpdateMirrorPreset.ghfast => defaultAppUpdateMirrorUrlPrefix,
    AppUpdateMirrorPreset.ghproxyCn => ghproxyCnMirrorUrlPrefix,
    AppUpdateMirrorPreset.ghLlkk => ghLlkkMirrorUrlPrefix,
    AppUpdateMirrorPreset.ghProxyCom => ghProxyComMirrorUrlPrefix,
    AppUpdateMirrorPreset.ghproxyNet => ghproxyNetMirrorUrlPrefix,
    AppUpdateMirrorPreset.custom =>
      normalizedCustomUrlPrefix.isEmpty
          ? defaultAppUpdateMirrorUrlPrefix
          : normalizedCustomUrlPrefix,
  };
}

class LiveDisplaySettings {
  final bool showCourseName;
  final bool showLocation;
  final bool showCountdown;
  final LiveCountdownTextStyle countdownTextStyle;
  final bool showStageText;
  final bool useShortName;
  final bool hidePrefixText;
  final LiveDuringClassTimeDisplayMode duringClassTimeDisplayMode;
  final bool enableMiuiIslandLabelImage;
  final MiuiIslandLabelStyle miuiIslandLabelStyle;
  final MiuiIslandLabelContent miuiIslandLabelContent;
  final String miuiIslandLabelFontColor;
  final MiuiIslandLabelFontWeight miuiIslandLabelFontWeight;
  final MiuiIslandLabelRenderQuality miuiIslandLabelRenderQuality;
  final double miuiIslandLabelFontSize;
  final double miuiIslandLabelOffsetX;
  final double miuiIslandLabelOffsetY;
  final String? miuiIslandLabelLogoPath;
  final double miuiIslandLabelLogoCornerRadius;
  final MiuiIslandExpandedIconMode miuiIslandExpandedIconMode;
  final String? miuiIslandExpandedIconPath;

  const LiveDisplaySettings({
    required this.showCourseName,
    required this.showLocation,
    required this.showCountdown,
    required this.countdownTextStyle,
    required this.showStageText,
    required this.useShortName,
    required this.hidePrefixText,
    required this.duringClassTimeDisplayMode,
    required this.enableMiuiIslandLabelImage,
    required this.miuiIslandLabelStyle,
    required this.miuiIslandLabelContent,
    required this.miuiIslandLabelFontColor,
    required this.miuiIslandLabelFontWeight,
    required this.miuiIslandLabelRenderQuality,
    required this.miuiIslandLabelFontSize,
    required this.miuiIslandLabelOffsetX,
    required this.miuiIslandLabelOffsetY,
    required this.miuiIslandLabelLogoPath,
    required this.miuiIslandLabelLogoCornerRadius,
    required this.miuiIslandExpandedIconMode,
    required this.miuiIslandExpandedIconPath,
  });

  LiveDisplaySettings copyWith({
    bool? showCourseName,
    bool? showLocation,
    bool? showCountdown,
    LiveCountdownTextStyle? countdownTextStyle,
    bool? showStageText,
    bool? useShortName,
    bool? hidePrefixText,
    LiveDuringClassTimeDisplayMode? duringClassTimeDisplayMode,
    bool? enableMiuiIslandLabelImage,
    MiuiIslandLabelStyle? miuiIslandLabelStyle,
    MiuiIslandLabelContent? miuiIslandLabelContent,
    String? miuiIslandLabelFontColor,
    MiuiIslandLabelFontWeight? miuiIslandLabelFontWeight,
    MiuiIslandLabelRenderQuality? miuiIslandLabelRenderQuality,
    double? miuiIslandLabelFontSize,
    double? miuiIslandLabelOffsetX,
    double? miuiIslandLabelOffsetY,
    String? miuiIslandLabelLogoPath,
    bool clearMiuiIslandLabelLogoPath = false,
    double? miuiIslandLabelLogoCornerRadius,
    MiuiIslandExpandedIconMode? miuiIslandExpandedIconMode,
    String? miuiIslandExpandedIconPath,
    bool clearMiuiIslandExpandedIconPath = false,
  }) {
    return LiveDisplaySettings(
      showCourseName: showCourseName ?? this.showCourseName,
      showLocation: showLocation ?? this.showLocation,
      showCountdown: showCountdown ?? this.showCountdown,
      countdownTextStyle: countdownTextStyle ?? this.countdownTextStyle,
      showStageText: showStageText ?? this.showStageText,
      useShortName: useShortName ?? this.useShortName,
      hidePrefixText: hidePrefixText ?? this.hidePrefixText,
      duringClassTimeDisplayMode:
          duringClassTimeDisplayMode ?? this.duringClassTimeDisplayMode,
      enableMiuiIslandLabelImage:
          enableMiuiIslandLabelImage ?? this.enableMiuiIslandLabelImage,
      miuiIslandLabelStyle: miuiIslandLabelStyle ?? this.miuiIslandLabelStyle,
      miuiIslandLabelContent:
          miuiIslandLabelContent ?? this.miuiIslandLabelContent,
      miuiIslandLabelFontColor:
          miuiIslandLabelFontColor ?? this.miuiIslandLabelFontColor,
      miuiIslandLabelFontWeight:
          miuiIslandLabelFontWeight ?? this.miuiIslandLabelFontWeight,
      miuiIslandLabelRenderQuality:
          miuiIslandLabelRenderQuality ?? this.miuiIslandLabelRenderQuality,
      miuiIslandLabelFontSize:
          miuiIslandLabelFontSize ?? this.miuiIslandLabelFontSize,
      miuiIslandLabelOffsetX:
          miuiIslandLabelOffsetX ?? this.miuiIslandLabelOffsetX,
      miuiIslandLabelOffsetY:
          miuiIslandLabelOffsetY ?? this.miuiIslandLabelOffsetY,
      miuiIslandLabelLogoPath: clearMiuiIslandLabelLogoPath
          ? null
          : miuiIslandLabelLogoPath ?? this.miuiIslandLabelLogoPath,
      miuiIslandLabelLogoCornerRadius:
          miuiIslandLabelLogoCornerRadius ??
          this.miuiIslandLabelLogoCornerRadius,
      miuiIslandExpandedIconMode:
          miuiIslandExpandedIconMode ?? this.miuiIslandExpandedIconMode,
      miuiIslandExpandedIconPath: clearMiuiIslandExpandedIconPath
          ? null
          : miuiIslandExpandedIconPath ?? this.miuiIslandExpandedIconPath,
    );
  }
}

class SectionTime {
  final String startTime;
  final String endTime;

  const SectionTime({required this.startTime, required this.endTime});

  Map<String, dynamic> toJson() {
    return {'startTime': startTime, 'endTime': endTime};
  }

  factory SectionTime.fromJson(Map<String, dynamic> json) {
    return SectionTime(
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
    );
  }

  SectionTime copyWith({String? startTime, String? endTime}) {
    return SectionTime(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  String get displayText => '$startTime-$endTime';
}

class SavedTheme {
  final String id;
  final String name;
  final ThemeConfig config;
  final DateTime createdAt;

  SavedTheme({
    required this.id,
    required this.name,
    required this.config,
    required this.createdAt,
  });

  /// 兼容旧版本的 themeData getter
  Map<String, dynamic> get themeData => config.toJson();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'themeData': config.toJson(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory SavedTheme.fromJson(Map<String, dynamic> json) {
    final themeDataJson = json['themeData'] as Map<String, dynamic>;
    return SavedTheme(
      id: json['id'] as String,
      name: json['name'] as String,
      config: ThemeConfig.fromJson(themeDataJson),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// 类型化的主题配置，替代 Map。
class ThemeConfig {
  final int version;
  final String? seedColor;
  final String? backgroundColor;
  final String? unifiedCardColor;
  final bool? useUnifiedCardColor;
  final String? themeMode; // "system" / "light" / "dark"
  final String? courseCardTitleColorLight;
  final String? courseCardTitleColorDark;
  final String? courseCardDetailColorLight;
  final String? courseCardDetailColorDark;
  final String? weekdayBarFontColorLight;
  final String? weekdayBarFontColorDark;
  final String? weekdayBarAccentColorLight;
  final String? weekdayBarAccentColorDark;
  final String? timeAxisFontColorLight;
  final String? timeAxisFontColorDark;
  final bool? linkCourseCardColors;
  final bool? hideWeekends;
  final String? spacingMode;
  final String? timeDisplayMode;

  const ThemeConfig({
    this.version = 2,
    this.seedColor,
    this.backgroundColor,
    this.unifiedCardColor,
    this.useUnifiedCardColor,
    this.themeMode,
    this.courseCardTitleColorLight,
    this.courseCardTitleColorDark,
    this.courseCardDetailColorLight,
    this.courseCardDetailColorDark,
    this.weekdayBarFontColorLight,
    this.weekdayBarFontColorDark,
    this.weekdayBarAccentColorLight,
    this.weekdayBarAccentColorDark,
    this.timeAxisFontColorLight,
    this.timeAxisFontColorDark,
    this.linkCourseCardColors,
    this.hideWeekends,
    this.spacingMode,
    this.timeDisplayMode,
  });

  Map<String, dynamic> toJson() => {
    'v': version,
    if (seedColor != null) 'seed': seedColor,
    if (backgroundColor != null) 'bg': backgroundColor,
    if (unifiedCardColor != null) 'uc': unifiedCardColor,
    if (useUnifiedCardColor != null) 'ucOn': useUnifiedCardColor,
    if (themeMode != null) 'mode': themeMode,
    if (courseCardTitleColorLight != null) 'ccl': courseCardTitleColorLight,
    if (courseCardTitleColorDark != null) 'ccd': courseCardTitleColorDark,
    if (courseCardDetailColorLight != null) 'cdl': courseCardDetailColorLight,
    if (courseCardDetailColorDark != null) 'cdd': courseCardDetailColorDark,
    if (weekdayBarFontColorLight != null) 'wbl': weekdayBarFontColorLight,
    if (weekdayBarFontColorDark != null) 'wbd': weekdayBarFontColorDark,
    if (weekdayBarAccentColorLight != null) 'wal': weekdayBarAccentColorLight,
    if (weekdayBarAccentColorDark != null) 'wad': weekdayBarAccentColorDark,
    if (timeAxisFontColorLight != null) 'tal': timeAxisFontColorLight,
    if (timeAxisFontColorDark != null) 'tad': timeAxisFontColorDark,
    if (linkCourseCardColors != null) 'link': linkCourseCardColors,
    if (hideWeekends != null) 'hideWeekend': hideWeekends,
    if (spacingMode != null) 'spacing': spacingMode,
    if (timeDisplayMode != null) 'timeDisplay': timeDisplayMode,
  };

  factory ThemeConfig.fromJson(Map<String, dynamic> json) {
    final version = json['v'] as int? ?? 1;
    if (version == 1) {
      // v1: 仅颜色
      return ThemeConfig(
        version: 1,
        courseCardTitleColorLight: json['ccl'] as String?,
        courseCardTitleColorDark: json['ccd'] as String?,
        courseCardDetailColorLight: json['cdl'] as String?,
        courseCardDetailColorDark: json['cdd'] as String?,
        weekdayBarFontColorLight: json['wbl'] as String?,
        weekdayBarFontColorDark: json['wbd'] as String?,
        weekdayBarAccentColorLight: json['wal'] as String?,
        weekdayBarAccentColorDark: json['wad'] as String?,
        timeAxisFontColorLight: json['tal'] as String?,
        timeAxisFontColorDark: json['tad'] as String?,
        linkCourseCardColors: json['link'] as bool?,
      );
    }
    // v2: 完整主题
    return ThemeConfig(
      version: 2,
      seedColor: json['seed'] as String?,
      backgroundColor: json['bg'] as String?,
      unifiedCardColor: json['uc'] as String?,
      useUnifiedCardColor: json['ucOn'] as bool?,
      themeMode: json['mode'] as String?,
      courseCardTitleColorLight: json['ccl'] as String?,
      courseCardTitleColorDark: json['ccd'] as String?,
      courseCardDetailColorLight: json['cdl'] as String?,
      courseCardDetailColorDark: json['cdd'] as String?,
      weekdayBarFontColorLight: json['wbl'] as String?,
      weekdayBarFontColorDark: json['wbd'] as String?,
      weekdayBarAccentColorLight: json['wal'] as String?,
      weekdayBarAccentColorDark: json['wad'] as String?,
      timeAxisFontColorLight: json['tal'] as String?,
      timeAxisFontColorDark: json['tad'] as String?,
      linkCourseCardColors: json['link'] as bool?,
      hideWeekends: json['hideWeekend'] as bool?,
      spacingMode: json['spacing'] as String?,
      timeDisplayMode: json['timeDisplay'] as String?,
    );
  }

  /// 从当前设置创建 ThemeConfig
  factory ThemeConfig.fromSettings(TimetableSettings settings) => ThemeConfig(
    version: 2,
    seedColor: settings.themeSeedColor,
    backgroundColor: settings.timetablePageBackgroundColor,
    unifiedCardColor: settings.timetableUnifiedCardColor,
    useUnifiedCardColor: settings.timetableUseUnifiedCardColor,
    themeMode: settings.appThemeMode.value,
    courseCardTitleColorLight: settings.courseCardTitleColorLight,
    courseCardTitleColorDark: settings.courseCardTitleColorDark,
    courseCardDetailColorLight: settings.courseCardDetailColorLight,
    courseCardDetailColorDark: settings.courseCardDetailColorDark,
    weekdayBarFontColorLight: settings.weekdayBarFontColorLight,
    weekdayBarFontColorDark: settings.weekdayBarFontColorDark,
    weekdayBarAccentColorLight: settings.weekdayBarAccentColorLight,
    weekdayBarAccentColorDark: settings.weekdayBarAccentColorDark,
    timeAxisFontColorLight: settings.timeAxisFontColorLight,
    timeAxisFontColorDark: settings.timeAxisFontColorDark,
    linkCourseCardColors: settings.linkCourseCardColors,
    hideWeekends: settings.timetableHideWeekends,
    spacingMode: settings.timetableCourseSpacingMode.value,
    timeDisplayMode: settings.timetableSectionTimeDisplayMode.value,
  );

  /// 应用主题到当前设置
  TimetableSettings applyToSettings(TimetableSettings current) {
    return current.copyWith(
      themeSeedColor: seedColor ?? current.themeSeedColor,
      timetablePageBackgroundColor:
          backgroundColor ?? current.timetablePageBackgroundColor,
      timetableUnifiedCardColor:
          unifiedCardColor ?? current.timetableUnifiedCardColor,
      timetableUseUnifiedCardColor:
          useUnifiedCardColor ?? current.timetableUseUnifiedCardColor,
      appThemeMode: themeMode != null
          ? AppThemeModeX.fromValue(themeMode)
          : current.appThemeMode,
      courseCardTitleColorLight:
          courseCardTitleColorLight ?? current.courseCardTitleColorLight,
      courseCardTitleColorDark:
          courseCardTitleColorDark ?? current.courseCardTitleColorDark,
      courseCardDetailColorLight:
          courseCardDetailColorLight ?? current.courseCardDetailColorLight,
      courseCardDetailColorDark:
          courseCardDetailColorDark ?? current.courseCardDetailColorDark,
      weekdayBarFontColorLight:
          weekdayBarFontColorLight ?? current.weekdayBarFontColorLight,
      weekdayBarFontColorDark:
          weekdayBarFontColorDark ?? current.weekdayBarFontColorDark,
      weekdayBarAccentColorLight:
          weekdayBarAccentColorLight ?? current.weekdayBarAccentColorLight,
      weekdayBarAccentColorDark:
          weekdayBarAccentColorDark ?? current.weekdayBarAccentColorDark,
      timeAxisFontColorLight:
          timeAxisFontColorLight ?? current.timeAxisFontColorLight,
      timeAxisFontColorDark:
          timeAxisFontColorDark ?? current.timeAxisFontColorDark,
      linkCourseCardColors:
          linkCourseCardColors ?? current.linkCourseCardColors,
      timetableHideWeekends: hideWeekends ?? current.timetableHideWeekends,
      timetableCourseSpacingMode: spacingMode != null
          ? TimetableCourseSpacingMode.values.firstWhere(
              (e) => e.value == spacingMode,
              orElse: () => current.timetableCourseSpacingMode,
            )
          : current.timetableCourseSpacingMode,
      timetableSectionTimeDisplayMode: timeDisplayMode != null
          ? SectionTimeDisplayMode.values.firstWhere(
              (e) => e.value == timeDisplayMode,
              orElse: () => current.timetableSectionTimeDisplayMode,
            )
          : current.timetableSectionTimeDisplayMode,
    );
  }

  /// 提取主题预览色块
  List<String> get previewColors {
    final colors = <String>[];
    if (seedColor != null) colors.add(seedColor!);
    if (courseCardTitleColorLight != null) {
      colors.add(courseCardTitleColorLight!);
    }
    if (courseCardDetailColorLight != null) {
      colors.add(courseCardDetailColorLight!);
    }
    if (weekdayBarFontColorLight != null) colors.add(weekdayBarFontColorLight!);
    if (weekdayBarAccentColorLight != null) {
      colors.add(weekdayBarAccentColorLight!);
    }
    return colors.take(4).toList();
  }
}

class TimetableSettings {
  // 颜色默认值常量
  static const String defaultCourseCardTitleColor = '#FFFFFF';
  static const String defaultCourseCardDetailColor = '#FFFFFF';
  static const String defaultWeekdayBarFontColorLight = '#000000';
  static const String defaultWeekdayBarFontColorDark = '#FFFFFF';
  static const String defaultWeekdayBarAccentColorLight = '#2563EB';
  static const String defaultWeekdayBarAccentColorDark = '#93C5FD';
  static const String defaultTimeAxisFontColorLight = '#757575';
  static const String defaultTimeAxisFontColorDark = '#FFFFFF';

  static const double defaultFrostedSheetBlurSigma = 15.0;
  static const double defaultFrostedSheetTintAlpha = 0.70;
  static const double defaultFrostedSheetBarrierAlpha = 0.20;
  static const bool defaultFrostedBlurEnabled = true;
  static const double defaultPageTransitionSpeed = 1.0;
  static const double minPageTransitionSpeed = 0.5;
  static const double maxPageTransitionSpeed = 2.5;

  final List<SectionTime> sections;
  final String? activeTimeSchemeId;
  final double sectionHeight;
  final double compactFontSize;
  final bool timetableAutoFitSectionHeight;
  final int semesterWeekCount;
  final DateTime? semesterStartDate;
  final bool weeklyReportEnabled;
  final bool enableHolidayMarking;
  final bool timetableShowCurrentWeekCourses;
  final bool timetableShowNonCurrentWeekCourses;
  final bool showConflictBadgeOnTimetable;
  final double timetableConflictCourseOpacity;
  final bool courseCardShowName;
  final bool courseCardShowTeacher;
  final bool courseCardShowLocation;
  final bool courseCardShowTime;
  final bool courseCardShowTimeLabels;
  final bool courseCardShowWeeks;
  final bool courseCardShowDescription;
  final CourseCardVerticalAlign courseCardVerticalAlign;
  final CourseCardHorizontalAlign courseCardHorizontalAlign;
  final double courseCardFontSize;
  final TimetableTimeColumnWidthMode timetableTimeColumnWidthMode;
  final double timetableCourseCardGap;
  final TimetableCourseSpacingMode timetableCourseSpacingMode;
  final WidgetBackgroundStyle widgetBackgroundStyle;
  final bool widgetShowLocation;
  final bool widgetShowCountdown;
  final bool widgetHideCompletedCourses;
  final bool widgetShowTomorrowCourses;
  final double widgetHeightAdjustment;
  final double widgetCornerRadius;
  final int widgetCountdownLeadMinutes;
  final LiveCountdownTextStyle widgetCountdownTextStyle;
  final AppThemeMode appThemeMode;
  final AppFontMode appFontMode;
  final String appLocaleTag;
  final HomeTitleStyle homeTitleStyle;
  final TimetableHomeViewMode timetableHomeViewMode;
  final HomeNavigationForm homeNavigationForm;
  final BackToCurrentWeekButtonStyle timetableBackToCurrentWeekButtonStyle;
  final double timetableFloatingBackToCurrentWeekButtonOpacity;
  final int timetableLastViewedDayOfWeek;

  /// Whether couple-timetable overlay (header heart) was last left on.
  final bool coupleTimetableOverlayEnabled;
  final SectionTimeDisplayMode timetableSectionTimeDisplayMode;
  final bool timetableHideWeekends;
  final bool enableHaptics;
  final double pageTransitionSpeed;

  /// When true, home-page pull-down runs warehouse quick import in the background.
  final bool homePullQuickImportEnabled;
  final bool liveShowCourseName;
  final bool liveShowLocation;
  final bool liveShowCountdown;
  final LiveCountdownTextStyle liveCountdownTextStyle;
  final bool liveShowStageText;
  final bool liveEnableBeforeClass;
  final bool liveEnableDuringClass;
  final bool liveEnableBeforeEnd;
  final bool livePromoteDuringClass;
  final bool liveShowDuringClassNotification;
  final bool liveUseShortName;
  final bool liveHidePrefixText;
  final LiveDuringClassTimeDisplayMode liveDuringClassTimeDisplayMode;
  final bool liveEnableMiuiIslandLabelImage;
  final bool liveDuringEndShowCourseName;
  final bool liveDuringEndShowLocation;
  final bool liveDuringEndShowCountdown;
  final LiveCountdownTextStyle liveDuringEndCountdownTextStyle;
  final bool liveDuringEndShowStageText;
  final bool liveDuringEndUseShortName;
  final bool liveDuringEndHidePrefixText;
  final bool liveDuringEndFollowBeforeClass;
  final LiveDuringClassTimeDisplayMode liveDuringEndTimeDisplayMode;
  final bool liveDuringEndEnableMiuiIslandLabelImage;
  final bool liveHideFromRecents;
  final bool liveEnableLocalDiagnostics;
  final MiuiIslandLabelStyle liveMiuiIslandLabelStyle;
  final MiuiIslandLabelContent liveMiuiIslandLabelContent;
  final String liveMiuiIslandLabelFontColor;
  final MiuiIslandLabelFontWeight liveMiuiIslandLabelFontWeight;
  final MiuiIslandLabelRenderQuality liveMiuiIslandLabelRenderQuality;
  final double liveMiuiIslandLabelFontSize;
  final double liveMiuiIslandLabelOffsetX;
  final double liveMiuiIslandLabelOffsetY;
  final String? liveMiuiIslandLabelLogoPath;
  final double liveMiuiIslandLabelLogoCornerRadius;
  final MiuiIslandExpandedIconMode liveMiuiIslandExpandedIconMode;
  final String? liveMiuiIslandExpandedIconPath;
  final MiuiIslandLabelStyle liveDuringEndMiuiIslandLabelStyle;
  final MiuiIslandLabelContent liveDuringEndMiuiIslandLabelContent;
  final String liveDuringEndMiuiIslandLabelFontColor;
  final MiuiIslandLabelFontWeight liveDuringEndMiuiIslandLabelFontWeight;
  final MiuiIslandLabelRenderQuality liveDuringEndMiuiIslandLabelRenderQuality;
  final double liveDuringEndMiuiIslandLabelFontSize;
  final double liveDuringEndMiuiIslandLabelOffsetX;
  final double liveDuringEndMiuiIslandLabelOffsetY;
  final String? liveDuringEndMiuiIslandLabelLogoPath;
  final double liveDuringEndMiuiIslandLabelLogoCornerRadius;
  final MiuiIslandExpandedIconMode liveDuringEndMiuiIslandExpandedIconMode;
  final String? liveDuringEndMiuiIslandExpandedIconPath;
  final int liveShowBeforeClassMinutes;
  final int liveClassReminderStartMinutes;
  final int liveEndSecondsCountdownThreshold;
  final int liveTimeCorrectionSeconds;
  final LiveBeforeClassQuickAction liveBeforeClassQuickAction;
  final String themeSeedColor;
  final ForuiTheme foruiTheme;
  final String timetablePageBackgroundColor;
  final HomePageBackgroundFill homePageBackgroundFill;
  final String? homePageBackgroundImagePath;
  final String? homePageWallpaperPath;

  /// 壁纸在页面内的水平对齐（-1 靠左 … 0 居中 … 1 靠右），用于横向壁纸
  /// 拖动选择显示区域；竖屏壁纸下 cover 不会水平溢出，该值不产生位移。
  final double homePageWallpaperAlignX;

  /// 壁纸在页面内的垂直对齐（-1 靠上 … 0 居中 … 1 靠下），用于长图壁纸
  /// 拖动选择显示区域；cover 下高度未溢出时该值不产生位移。
  final double homePageWallpaperAlignY;
  final int homePageBackgroundScope;
  final bool timetableUseUnifiedCardColor;
  final String timetableUnifiedCardColor;
  final String appUpdateDownloadSource;
  final String appUpdateDownloadChannel;
  final bool appUpdateUseSystemDownloader;
  final String appUpdateMirrorPreset;
  final bool appUpdateIncludePrerelease;
  final String appUpdateMirrorUrlPrefix;
  final String pgyerApiKey;
  final String pgyerAppKey;
  final bool holidayOverrideEnabled;
  final String courseCardTitleColorLight;
  final String courseCardTitleColorDark;
  final String courseCardDetailColorLight;
  final String courseCardDetailColorDark;
  final String weekdayBarFontColorLight;
  final String weekdayBarFontColorDark;
  final String weekdayBarAccentColorLight;
  final String weekdayBarAccentColorDark;
  final String timeAxisFontColorLight;
  final String timeAxisFontColorDark;

  /// Convenience getter that maps frosted-glass fields to a [FrostedAppearance].
  FrostedAppearance get frostedAppearance => FrostedAppearance(
    sheetBlurSigma: frostedSheetBlurSigma,
    sheetTintAlpha: frostedSheetTintAlpha,
    sheetBarrierAlpha: frostedSheetBarrierAlpha,
    blurEnabled: frostedBlurEnabled,
    glassMode: frostedGlassMode,
    liquidGlassTuning: liquidGlassTuning,
  );

  final bool linkCourseCardColors; // 标题和详情颜色是否关联
  final double frostedSheetBlurSigma;
  final double frostedSheetTintAlpha;
  final double frostedSheetBarrierAlpha;
  final bool frostedBlurEnabled;
  final FrostedGlassMode frostedGlassMode;
  final CourseCardSurfaceStyle courseCardSurfaceStyle;
  final LiquidGlassPreset liquidGlassPreset;
  final LiquidGlassTuning? liquidGlassTuning;
  final bool homePageHeaderBlurEnabled;
  final bool homePageWeekdayBarBlurEnabled;
  final bool homePageTimeColumnBlurEnabled;
  final bool homePageBackdropFollowsWeekPager;
  final List<SavedTheme> savedThemes; // 保存的主题列表
  final String? themeCheckpointName; // 当前主题来源名称（预设或保存的主题）
  final ThemeConfig? themeCheckpointConfig; // 应用主题时的配置快照

  const TimetableSettings({
    required this.sections,
    this.activeTimeSchemeId,
    this.sectionHeight = 68,
    this.compactFontSize = 9,
    this.timetableAutoFitSectionHeight = false,
    this.semesterWeekCount = 20,
    this.semesterStartDate,
    this.weeklyReportEnabled = false,
    this.enableHolidayMarking = true,
    this.timetableShowCurrentWeekCourses = true,
    this.timetableShowNonCurrentWeekCourses = false,
    this.showConflictBadgeOnTimetable = true,
    this.timetableConflictCourseOpacity = 0.70,
    this.courseCardShowName = true,
    this.courseCardShowTeacher = true,
    this.courseCardShowLocation = true,
    this.courseCardShowTime = false,
    this.courseCardShowTimeLabels = true,
    this.courseCardShowWeeks = false,
    this.courseCardShowDescription = false,
    this.courseCardVerticalAlign = CourseCardVerticalAlign.center,
    this.courseCardHorizontalAlign = CourseCardHorizontalAlign.center,
    this.courseCardFontSize = 9,
    this.timetableTimeColumnWidthMode = TimetableTimeColumnWidthMode.narrow,
    this.timetableCourseCardGap = 1.25,
    this.timetableCourseSpacingMode = TimetableCourseSpacingMode.narrow,
    this.widgetBackgroundStyle = WidgetBackgroundStyle.solid,
    this.widgetShowLocation = true,
    this.widgetShowCountdown = true,
    this.widgetHideCompletedCourses = false,
    this.widgetShowTomorrowCourses = true,
    this.widgetHeightAdjustment = -11,
    this.widgetCornerRadius = 22,
    this.widgetCountdownLeadMinutes = 20,
    this.widgetCountdownTextStyle = LiveCountdownTextStyle.smart,
    this.appThemeMode = AppThemeMode.system,
    this.appFontMode = AppFontMode.system,
    this.appLocaleTag = '',
    this.homeTitleStyle = HomeTitleStyle.classic,
    this.timetableHomeViewMode = TimetableHomeViewMode.week,
    this.homeNavigationForm = HomeNavigationForm.classic,
    this.timetableBackToCurrentWeekButtonStyle =
        BackToCurrentWeekButtonStyle.floating,
    this.timetableFloatingBackToCurrentWeekButtonOpacity = 0.96,
    this.timetableLastViewedDayOfWeek = 1,
    this.coupleTimetableOverlayEnabled = false,
    this.timetableSectionTimeDisplayMode = SectionTimeDisplayMode.startAndEnd,
    this.timetableHideWeekends = false,
    this.enableHaptics = true,
    this.pageTransitionSpeed = defaultPageTransitionSpeed,
    this.homePullQuickImportEnabled = false,
    this.liveShowCourseName = true,
    this.liveShowLocation = true,
    this.liveShowCountdown = true,
    this.liveCountdownTextStyle = LiveCountdownTextStyle.smart,
    this.liveShowStageText = true,
    this.liveEnableBeforeClass = true,
    this.liveEnableDuringClass = true,
    this.liveEnableBeforeEnd = true,
    this.livePromoteDuringClass = true,
    this.liveShowDuringClassNotification = true,
    this.liveUseShortName = true,
    this.liveHidePrefixText = true,
    this.liveDuringClassTimeDisplayMode =
        LiveDuringClassTimeDisplayMode.nearest,
    this.liveEnableMiuiIslandLabelImage = false,
    this.liveDuringEndShowCourseName = true,
    this.liveDuringEndShowLocation = true,
    this.liveDuringEndShowCountdown = true,
    this.liveDuringEndCountdownTextStyle = LiveCountdownTextStyle.smart,
    this.liveDuringEndShowStageText = true,
    this.liveDuringEndUseShortName = true,
    this.liveDuringEndHidePrefixText = true,
    this.liveDuringEndFollowBeforeClass = true,
    this.liveDuringEndTimeDisplayMode = LiveDuringClassTimeDisplayMode.nearest,
    this.liveDuringEndEnableMiuiIslandLabelImage = false,
    this.liveHideFromRecents = false,
    this.liveEnableLocalDiagnostics = false,
    this.liveMiuiIslandLabelStyle = MiuiIslandLabelStyle.textOnly,
    this.liveMiuiIslandLabelContent = MiuiIslandLabelContent.courseName,
    this.liveMiuiIslandLabelFontColor = '#FFFFFF',
    this.liveMiuiIslandLabelFontWeight = MiuiIslandLabelFontWeight.bold,
    this.liveMiuiIslandLabelRenderQuality =
        MiuiIslandLabelRenderQuality.standard,
    this.liveMiuiIslandLabelFontSize = 14,
    this.liveMiuiIslandLabelOffsetX = 0,
    this.liveMiuiIslandLabelOffsetY = 0,
    this.liveMiuiIslandLabelLogoPath,
    this.liveMiuiIslandLabelLogoCornerRadius = 8,
    this.liveMiuiIslandExpandedIconMode = MiuiIslandExpandedIconMode.appIcon,
    this.liveMiuiIslandExpandedIconPath,
    this.liveDuringEndMiuiIslandLabelStyle = MiuiIslandLabelStyle.textOnly,
    this.liveDuringEndMiuiIslandLabelContent =
        MiuiIslandLabelContent.courseName,
    this.liveDuringEndMiuiIslandLabelFontColor = '#FFFFFF',
    this.liveDuringEndMiuiIslandLabelFontWeight =
        MiuiIslandLabelFontWeight.bold,
    this.liveDuringEndMiuiIslandLabelRenderQuality =
        MiuiIslandLabelRenderQuality.standard,
    this.liveDuringEndMiuiIslandLabelFontSize = 14,
    this.liveDuringEndMiuiIslandLabelOffsetX = 0,
    this.liveDuringEndMiuiIslandLabelOffsetY = 0,
    this.liveDuringEndMiuiIslandLabelLogoPath,
    this.liveDuringEndMiuiIslandLabelLogoCornerRadius = 8,
    this.liveDuringEndMiuiIslandExpandedIconMode =
        MiuiIslandExpandedIconMode.appIcon,
    this.liveDuringEndMiuiIslandExpandedIconPath,
    this.liveShowBeforeClassMinutes = 20,
    this.liveClassReminderStartMinutes = 0,
    this.liveEndSecondsCountdownThreshold = 60,
    this.liveTimeCorrectionSeconds = 0,
    this.liveBeforeClassQuickAction = LiveBeforeClassQuickAction.none,
    this.themeSeedColor = '#2563EB',
    this.foruiTheme = ForuiTheme.blue,
    this.timetablePageBackgroundColor = '#F8FAFC',
    this.homePageBackgroundFill = HomePageBackgroundFill.color,
    this.homePageBackgroundImagePath,
    this.homePageWallpaperPath,
    this.homePageWallpaperAlignX = 0,
    this.homePageWallpaperAlignY = 0,
    this.homePageBackgroundScope = HomePageBackgroundScope.defaultValue,
    this.timetableUseUnifiedCardColor = false,
    this.timetableUnifiedCardColor = '#2563EB',
    this.appUpdateDownloadSource = 'mirror',
    this.appUpdateDownloadChannel = 'pgyer',
    this.appUpdateUseSystemDownloader = false,
    this.appUpdateMirrorPreset = 'ghfast',
    this.appUpdateIncludePrerelease = false,
    this.appUpdateMirrorUrlPrefix = defaultAppUpdateMirrorUrlPrefix,
    this.pgyerApiKey = '',
    this.pgyerAppKey = '',
    this.holidayOverrideEnabled = false,
    this.courseCardTitleColorLight = defaultCourseCardTitleColor,
    this.courseCardTitleColorDark = defaultCourseCardTitleColor,
    this.courseCardDetailColorLight = defaultCourseCardDetailColor,
    this.courseCardDetailColorDark = defaultCourseCardDetailColor,
    this.weekdayBarFontColorLight = defaultWeekdayBarFontColorLight,
    this.weekdayBarFontColorDark = defaultWeekdayBarFontColorDark,
    this.weekdayBarAccentColorLight = defaultWeekdayBarAccentColorLight,
    this.weekdayBarAccentColorDark = defaultWeekdayBarAccentColorDark,
    this.timeAxisFontColorLight = defaultTimeAxisFontColorLight,
    this.timeAxisFontColorDark = defaultTimeAxisFontColorDark,
    this.linkCourseCardColors = true,
    this.frostedSheetBlurSigma = defaultFrostedSheetBlurSigma,
    this.frostedSheetTintAlpha = defaultFrostedSheetTintAlpha,
    this.frostedSheetBarrierAlpha = defaultFrostedSheetBarrierAlpha,
    this.frostedBlurEnabled = defaultFrostedBlurEnabled,
    this.frostedGlassMode = FrostedGlassMode.frosted,
    this.courseCardSurfaceStyle = CourseCardSurfaceStyle.solid,
    this.liquidGlassPreset = LiquidGlassPreset.standard,
    this.liquidGlassTuning,
    this.homePageHeaderBlurEnabled = false,
    this.homePageWeekdayBarBlurEnabled = false,
    this.homePageTimeColumnBlurEnabled = false,
    this.homePageBackdropFollowsWeekPager = true,
    this.savedThemes = const [],
    this.themeCheckpointName,
    this.themeCheckpointConfig,
  });

  factory TimetableSettings.defaults() {
    return const TimetableSettings(
      sections: [
        SectionTime(startTime: '08:00', endTime: '08:45'),
        SectionTime(startTime: '08:55', endTime: '09:40'),
        SectionTime(startTime: '10:00', endTime: '10:45'),
        SectionTime(startTime: '10:55', endTime: '11:40'),
        SectionTime(startTime: '14:00', endTime: '14:45'),
        SectionTime(startTime: '14:55', endTime: '15:40'),
        SectionTime(startTime: '16:00', endTime: '16:45'),
        SectionTime(startTime: '16:55', endTime: '17:40'),
        SectionTime(startTime: '19:00', endTime: '19:45'),
        SectionTime(startTime: '19:55', endTime: '20:40'),
      ],
      activeTimeSchemeId: null,
      sectionHeight: 68,
      compactFontSize: 9,
      timetableAutoFitSectionHeight: false,
      semesterWeekCount: 20,
      semesterStartDate: null,
      weeklyReportEnabled: false,
      enableHolidayMarking: true,
      timetableShowCurrentWeekCourses: true,
      timetableShowNonCurrentWeekCourses: false,
      showConflictBadgeOnTimetable: true,
      timetableConflictCourseOpacity: 0.70,
      courseCardShowName: true,
      courseCardShowTeacher: true,
      courseCardShowLocation: true,
      courseCardShowTime: false,
      courseCardShowTimeLabels: true,
      courseCardShowWeeks: false,
      courseCardShowDescription: false,
      courseCardVerticalAlign: CourseCardVerticalAlign.center,
      courseCardHorizontalAlign: CourseCardHorizontalAlign.center,
      courseCardFontSize: 9,
      timetableTimeColumnWidthMode: TimetableTimeColumnWidthMode.narrow,
      timetableCourseCardGap: 1.25,
      timetableCourseSpacingMode: TimetableCourseSpacingMode.narrow,
      widgetBackgroundStyle: WidgetBackgroundStyle.solid,
      widgetShowLocation: true,
      widgetShowCountdown: true,
      widgetHideCompletedCourses: false,
      widgetShowTomorrowCourses: true,
      widgetHeightAdjustment: -11,
      widgetCornerRadius: 22,
      appThemeMode: AppThemeMode.system,
      appFontMode: AppFontMode.system,
      appLocaleTag: '',
      homeTitleStyle: HomeTitleStyle.classic,
      timetableHomeViewMode: TimetableHomeViewMode.week,
      homeNavigationForm: HomeNavigationForm.classic,
      timetableBackToCurrentWeekButtonStyle:
          BackToCurrentWeekButtonStyle.floating,
      timetableFloatingBackToCurrentWeekButtonOpacity: 0.96,
      timetableLastViewedDayOfWeek: 1,
      coupleTimetableOverlayEnabled: false,
      timetableSectionTimeDisplayMode: SectionTimeDisplayMode.startAndEnd,
      timetableHideWeekends: false,
      enableHaptics: true,
      pageTransitionSpeed: defaultPageTransitionSpeed,
      homePullQuickImportEnabled: false,
      liveShowCourseName: true,
      liveShowLocation: true,
      liveShowCountdown: true,
      liveCountdownTextStyle: LiveCountdownTextStyle.smart,
      liveShowStageText: true,
      liveEnableBeforeClass: true,
      liveEnableDuringClass: true,
      liveEnableBeforeEnd: true,
      livePromoteDuringClass: true,
      liveShowDuringClassNotification: true,
      liveUseShortName: true,
      liveHidePrefixText: true,
      liveDuringClassTimeDisplayMode: LiveDuringClassTimeDisplayMode.nearest,
      liveEnableMiuiIslandLabelImage: false,
      liveDuringEndShowCourseName: true,
      liveDuringEndShowLocation: true,
      liveDuringEndShowCountdown: true,
      liveDuringEndCountdownTextStyle: LiveCountdownTextStyle.smart,
      liveDuringEndShowStageText: true,
      liveDuringEndUseShortName: true,
      liveDuringEndHidePrefixText: true,
      liveDuringEndFollowBeforeClass: true,
      liveDuringEndTimeDisplayMode: LiveDuringClassTimeDisplayMode.nearest,
      liveDuringEndEnableMiuiIslandLabelImage: false,
      liveHideFromRecents: false,
      liveEnableLocalDiagnostics: false,
      liveMiuiIslandLabelStyle: MiuiIslandLabelStyle.textOnly,
      liveMiuiIslandLabelContent: MiuiIslandLabelContent.courseName,
      liveMiuiIslandLabelFontColor: '#FFFFFF',
      liveMiuiIslandLabelFontWeight: MiuiIslandLabelFontWeight.bold,
      liveMiuiIslandLabelRenderQuality: MiuiIslandLabelRenderQuality.standard,
      liveMiuiIslandLabelFontSize: 14,
      liveMiuiIslandLabelOffsetX: 0,
      liveMiuiIslandLabelOffsetY: 0,
      liveMiuiIslandLabelLogoPath: null,
      liveMiuiIslandLabelLogoCornerRadius: 8,
      liveMiuiIslandExpandedIconMode: MiuiIslandExpandedIconMode.appIcon,
      liveMiuiIslandExpandedIconPath: null,
      liveDuringEndMiuiIslandLabelStyle: MiuiIslandLabelStyle.textOnly,
      liveDuringEndMiuiIslandLabelContent: MiuiIslandLabelContent.courseName,
      liveDuringEndMiuiIslandLabelFontColor: '#FFFFFF',
      liveDuringEndMiuiIslandLabelFontWeight: MiuiIslandLabelFontWeight.bold,
      liveDuringEndMiuiIslandLabelRenderQuality:
          MiuiIslandLabelRenderQuality.standard,
      liveDuringEndMiuiIslandLabelFontSize: 14,
      liveDuringEndMiuiIslandLabelOffsetX: 0,
      liveDuringEndMiuiIslandLabelOffsetY: 0,
      liveDuringEndMiuiIslandLabelLogoPath: null,
      liveDuringEndMiuiIslandLabelLogoCornerRadius: 8,
      liveDuringEndMiuiIslandExpandedIconMode:
          MiuiIslandExpandedIconMode.appIcon,
      liveDuringEndMiuiIslandExpandedIconPath: null,
      liveShowBeforeClassMinutes: 20,
      liveClassReminderStartMinutes: 0,
      liveEndSecondsCountdownThreshold: 60,
      liveTimeCorrectionSeconds: 0,
      liveBeforeClassQuickAction: LiveBeforeClassQuickAction.none,
      themeSeedColor: '#2563EB',
      foruiTheme: ForuiTheme.blue,
      timetablePageBackgroundColor: '#F8FAFC',
      homePageBackgroundFill: HomePageBackgroundFill.color,
      homePageBackgroundImagePath: null,
      homePageWallpaperPath: null,
      homePageWallpaperAlignX: 0,
      homePageWallpaperAlignY: 0,
      homePageBackgroundScope: HomePageBackgroundScope.defaultValue,
      timetableUseUnifiedCardColor: false,
      timetableUnifiedCardColor: '#2563EB',
      appUpdateDownloadSource: 'mirror',
      appUpdateMirrorPreset: 'ghfast',
      appUpdateIncludePrerelease: false,
      appUpdateMirrorUrlPrefix: defaultAppUpdateMirrorUrlPrefix,
      holidayOverrideEnabled: false,
      courseCardTitleColorLight: defaultCourseCardTitleColor,
      courseCardTitleColorDark: defaultCourseCardTitleColor,
      courseCardDetailColorLight: defaultCourseCardDetailColor,
      courseCardDetailColorDark: defaultCourseCardDetailColor,
      weekdayBarFontColorLight: defaultWeekdayBarFontColorLight,
      weekdayBarFontColorDark: defaultWeekdayBarFontColorDark,
      weekdayBarAccentColorLight: defaultWeekdayBarAccentColorLight,
      weekdayBarAccentColorDark: defaultWeekdayBarAccentColorDark,
      timeAxisFontColorLight: defaultTimeAxisFontColorLight,
      timeAxisFontColorDark: defaultTimeAxisFontColorDark,
      linkCourseCardColors: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sections': sections.map((section) => section.toJson()).toList(),
      'activeTimeSchemeId': activeTimeSchemeId,
      'sectionHeight': sectionHeight,
      'compactFontSize': compactFontSize,
      'timetableAutoFitSectionHeight': timetableAutoFitSectionHeight,
      'semesterWeekCount': semesterWeekCount,
      'semesterStartDate': semesterStartDate?.millisecondsSinceEpoch,
      'weeklyReportEnabled': weeklyReportEnabled,
      'enableHolidayMarking': enableHolidayMarking,
      'timetableShowCurrentWeekCourses': timetableShowCurrentWeekCourses,
      'timetableShowNonCurrentWeekCourses': timetableShowNonCurrentWeekCourses,
      'showConflictBadgeOnTimetable': showConflictBadgeOnTimetable,
      'timetableConflictCourseOpacity': timetableConflictCourseOpacity,
      'courseCardShowName': courseCardShowName,
      'courseCardShowTeacher': courseCardShowTeacher,
      'courseCardShowLocation': courseCardShowLocation,
      'courseCardShowTime': courseCardShowTime,
      'courseCardShowTimeLabels': courseCardShowTimeLabels,
      'courseCardShowWeeks': courseCardShowWeeks,
      'courseCardShowDescription': courseCardShowDescription,
      'courseCardVerticalAlign': courseCardVerticalAlign.value,
      'courseCardHorizontalAlign': courseCardHorizontalAlign.value,
      'courseCardFontSize': courseCardFontSize,
      'timetableTimeColumnWidthMode': timetableTimeColumnWidthMode.value,
      'timetableCourseCardGap': timetableCourseCardGap,
      'timetableCourseSpacingMode': timetableCourseSpacingMode.value,
      'widgetBackgroundStyle': widgetBackgroundStyle.value,
      'widgetShowLocation': widgetShowLocation,
      'widgetShowCountdown': widgetShowCountdown,
      'widgetHideCompletedCourses': widgetHideCompletedCourses,
      'widgetShowTomorrowCourses': widgetShowTomorrowCourses,
      'widgetHeightAdjustment': widgetHeightAdjustment,
      'widgetCornerRadius': widgetCornerRadius,
      'widgetCountdownLeadMinutes': widgetCountdownLeadMinutes,
      'widgetCountdownTextStyle': widgetCountdownTextStyle.value,
      'appThemeMode': appThemeMode.value,
      'appFontMode': appFontMode.value,
      'appLocaleTag': appLocaleTag,
      'homeTitleStyle': homeTitleStyle.value,
      'timetableHomeViewMode': timetableHomeViewMode.value,
      'homeNavigationForm': homeNavigationForm.value,
      'timetableBackToCurrentWeekButtonStyle':
          timetableBackToCurrentWeekButtonStyle.value,
      'timetableFloatingBackToCurrentWeekButtonOpacity':
          timetableFloatingBackToCurrentWeekButtonOpacity,
      'timetableLastViewedDayOfWeek': timetableLastViewedDayOfWeek,
      'coupleTimetableOverlayEnabled': coupleTimetableOverlayEnabled,
      'timetableSectionTimeDisplayMode': timetableSectionTimeDisplayMode.value,
      'timetableHideWeekends': timetableHideWeekends,
      'enableHaptics': enableHaptics,
      'pageTransitionSpeed': pageTransitionSpeed,
      'homePullQuickImportEnabled': homePullQuickImportEnabled,
      'liveShowCourseName': liveShowCourseName,
      'liveShowLocation': liveShowLocation,
      'liveShowCountdown': liveShowCountdown,
      'liveCountdownTextStyle': liveCountdownTextStyle.value,
      'liveShowStageText': liveShowStageText,
      'liveEnableBeforeClass': liveEnableBeforeClass,
      'liveEnableDuringClass': liveEnableDuringClass,
      'liveEnableBeforeEnd': liveEnableBeforeEnd,
      'livePromoteDuringClass': livePromoteDuringClass,
      'liveShowDuringClassNotification': liveShowDuringClassNotification,
      'liveUseShortName': liveUseShortName,
      'liveHidePrefixText': liveHidePrefixText,
      'liveDuringClassTimeDisplayMode': liveDuringClassTimeDisplayMode.value,
      'liveEnableMiuiIslandLabelImage': liveEnableMiuiIslandLabelImage,
      'liveDuringEndShowCourseName': liveDuringEndShowCourseName,
      'liveDuringEndShowLocation': liveDuringEndShowLocation,
      'liveDuringEndShowCountdown': liveDuringEndShowCountdown,
      'liveDuringEndCountdownTextStyle': liveDuringEndCountdownTextStyle.value,
      'liveDuringEndShowStageText': liveDuringEndShowStageText,
      'liveDuringEndUseShortName': liveDuringEndUseShortName,
      'liveDuringEndHidePrefixText': liveDuringEndHidePrefixText,
      'liveDuringEndFollowBeforeClass': liveDuringEndFollowBeforeClass,
      'liveDuringEndTimeDisplayMode': liveDuringEndTimeDisplayMode.value,
      'liveDuringEndEnableMiuiIslandLabelImage':
          liveDuringEndEnableMiuiIslandLabelImage,
      'liveHideFromRecents': liveHideFromRecents,
      'liveEnableLocalDiagnostics': liveEnableLocalDiagnostics,
      'liveMiuiIslandLabelStyle': liveMiuiIslandLabelStyle.value,
      'liveMiuiIslandLabelContent': liveMiuiIslandLabelContent.value,
      'liveMiuiIslandLabelFontColor': liveMiuiIslandLabelFontColor,
      'liveMiuiIslandLabelFontWeight': liveMiuiIslandLabelFontWeight.value,
      'liveMiuiIslandLabelRenderQuality':
          liveMiuiIslandLabelRenderQuality.value,
      'liveMiuiIslandLabelFontSize': liveMiuiIslandLabelFontSize,
      'liveMiuiIslandLabelOffsetX': liveMiuiIslandLabelOffsetX,
      'liveMiuiIslandLabelOffsetY': liveMiuiIslandLabelOffsetY,
      'liveMiuiIslandLabelLogoPath': liveMiuiIslandLabelLogoPath,
      'liveMiuiIslandLabelLogoCornerRadius':
          liveMiuiIslandLabelLogoCornerRadius,
      'liveMiuiIslandExpandedIconMode': liveMiuiIslandExpandedIconMode.value,
      'liveMiuiIslandExpandedIconPath': liveMiuiIslandExpandedIconPath,
      'liveDuringEndMiuiIslandLabelStyle':
          liveDuringEndMiuiIslandLabelStyle.value,
      'liveDuringEndMiuiIslandLabelContent':
          liveDuringEndMiuiIslandLabelContent.value,
      'liveDuringEndMiuiIslandLabelFontColor':
          liveDuringEndMiuiIslandLabelFontColor,
      'liveDuringEndMiuiIslandLabelFontWeight':
          liveDuringEndMiuiIslandLabelFontWeight.value,
      'liveDuringEndMiuiIslandLabelRenderQuality':
          liveDuringEndMiuiIslandLabelRenderQuality.value,
      'liveDuringEndMiuiIslandLabelFontSize':
          liveDuringEndMiuiIslandLabelFontSize,
      'liveDuringEndMiuiIslandLabelOffsetX':
          liveDuringEndMiuiIslandLabelOffsetX,
      'liveDuringEndMiuiIslandLabelOffsetY':
          liveDuringEndMiuiIslandLabelOffsetY,
      'liveDuringEndMiuiIslandLabelLogoPath':
          liveDuringEndMiuiIslandLabelLogoPath,
      'liveDuringEndMiuiIslandLabelLogoCornerRadius':
          liveDuringEndMiuiIslandLabelLogoCornerRadius,
      'liveDuringEndMiuiIslandExpandedIconMode':
          liveDuringEndMiuiIslandExpandedIconMode.value,
      'liveDuringEndMiuiIslandExpandedIconPath':
          liveDuringEndMiuiIslandExpandedIconPath,
      'liveShowBeforeClassMinutes': liveShowBeforeClassMinutes,
      'liveClassReminderStartMinutes': liveClassReminderStartMinutes,
      'liveEndSecondsCountdownThreshold': liveEndSecondsCountdownThreshold,
      'liveTimeCorrectionSeconds': liveTimeCorrectionSeconds,
      'liveBeforeClassQuickAction': liveBeforeClassQuickAction.value,
      'themeSeedColor': themeSeedColor,
      'foruiTheme': foruiTheme.value,
      'timetablePageBackgroundColor': timetablePageBackgroundColor,
      'homePageBackgroundFill': homePageBackgroundFill.value,
      if (homePageBackgroundImagePath != null)
        'homePageBackgroundImagePath': homePageBackgroundImagePath,
      if (homePageWallpaperPath != null)
        'homePageWallpaperPath': homePageWallpaperPath,
      'homePageWallpaperAlignX': homePageWallpaperAlignX,
      'homePageWallpaperAlignY': homePageWallpaperAlignY,
      'homePageBackgroundScope': homePageBackgroundScope,
      'timetableUseUnifiedCardColor': timetableUseUnifiedCardColor,
      'timetableUnifiedCardColor': timetableUnifiedCardColor,
      'appUpdateDownloadSource': appUpdateDownloadSource,
      'appUpdateDownloadChannel': appUpdateDownloadChannel,
      'appUpdateUseSystemDownloader': appUpdateUseSystemDownloader,
      'appUpdateMirrorPreset': appUpdateMirrorPreset,
      'appUpdateIncludePrerelease': appUpdateIncludePrerelease,
      'appUpdateMirrorUrlPrefix': appUpdateMirrorUrlPrefix,
      'pgyerApiKey': pgyerApiKey,
      'pgyerAppKey': pgyerAppKey,
      'holidayOverrideEnabled': holidayOverrideEnabled,
      'courseCardTitleColorLight': courseCardTitleColorLight,
      'courseCardTitleColorDark': courseCardTitleColorDark,
      'courseCardDetailColorLight': courseCardDetailColorLight,
      'courseCardDetailColorDark': courseCardDetailColorDark,
      'weekdayBarFontColorLight': weekdayBarFontColorLight,
      'weekdayBarFontColorDark': weekdayBarFontColorDark,
      'weekdayBarAccentColorLight': weekdayBarAccentColorLight,
      'weekdayBarAccentColorDark': weekdayBarAccentColorDark,
      'timeAxisFontColorLight': timeAxisFontColorLight,
      'timeAxisFontColorDark': timeAxisFontColorDark,
      'linkCourseCardColors': linkCourseCardColors,
      'frostedSheetBlurSigma': frostedSheetBlurSigma,
      'frostedSheetTintAlpha': frostedSheetTintAlpha,
      'frostedSheetBarrierAlpha': frostedSheetBarrierAlpha,
      'frostedBlurEnabled': frostedBlurEnabled,
      'frostedGlassMode': frostedGlassMode.value,
      'courseCardSurfaceStyle': courseCardSurfaceStyle.value,
      'liquidGlassPreset': liquidGlassPreset.value,
      if (liquidGlassTuning != null)
        'liquidGlassTuning': liquidGlassTuning!.toJson(),
      'homePageHeaderBlurEnabled': homePageHeaderBlurEnabled,
      'homePageWeekdayBarBlurEnabled': homePageWeekdayBarBlurEnabled,
      'homePageTimeColumnBlurEnabled': homePageTimeColumnBlurEnabled,
      'homePageBackdropFollowsWeekPager': homePageBackdropFollowsWeekPager,
      'savedThemes': savedThemes.map((t) => t.toJson()).toList(),
      if (themeCheckpointName != null)
        'themeCheckpointName': themeCheckpointName,
      if (themeCheckpointConfig != null)
        'themeCheckpointConfig': themeCheckpointConfig!.toJson(),
    };
  }

  factory TimetableSettings.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'] as List<dynamic>? ?? const [];
    // Empty sections fall back to defaults only for the section list; other
    // fields must still parse so a corrupt sections array does not wipe theme /
    // semester / live settings.
    final resolvedSections = rawSections.isEmpty
        ? TimetableSettings.defaults().sections
        : rawSections
              .map(
                (item) => SectionTime.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList();
    final rawAppUpdateMirrorUrlPrefix =
        json['appUpdateMirrorUrlPrefix'] as String? ??
        defaultAppUpdateMirrorUrlPrefix;
    final rawAppUpdateMirrorPreset = json['appUpdateMirrorPreset'] as String?;

    return TimetableSettings(
      sections: resolvedSections,
      activeTimeSchemeId: json['activeTimeSchemeId'] as String?,
      sectionHeight: (json['sectionHeight'] as num?)?.toDouble() ?? 68,
      compactFontSize: (json['compactFontSize'] as num?)?.toDouble() ?? 9,
      timetableAutoFitSectionHeight:
          json['timetableAutoFitSectionHeight'] as bool? ?? false,
      semesterWeekCount: (json['semesterWeekCount'] as num?)?.toInt() ?? 20,
      semesterStartDate: (json['semesterStartDate'] as num?) != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['semesterStartDate'] as num).toInt(),
            )
          : null,
      weeklyReportEnabled: json['weeklyReportEnabled'] as bool? ?? false,
      enableHolidayMarking: json['enableHolidayMarking'] as bool? ?? true,
      timetableShowCurrentWeekCourses: true,
      timetableShowNonCurrentWeekCourses:
          json['timetableShowNonCurrentWeekCourses'] as bool? ?? false,
      showConflictBadgeOnTimetable:
          json['showConflictBadgeOnTimetable'] as bool? ?? true,
      timetableConflictCourseOpacity:
          ((json['timetableConflictCourseOpacity'] as num?)?.toDouble() ?? 0.70)
              .clamp(0.2, 1.0),
      courseCardShowName: json['courseCardShowName'] as bool? ?? true,
      courseCardShowTeacher: json['courseCardShowTeacher'] as bool? ?? true,
      courseCardShowLocation: json['courseCardShowLocation'] as bool? ?? true,
      courseCardShowTime: json['courseCardShowTime'] as bool? ?? false,
      courseCardShowTimeLabels:
          json['courseCardShowTimeLabels'] as bool? ?? true,
      courseCardShowWeeks: json['courseCardShowWeeks'] as bool? ?? false,
      courseCardShowDescription:
          json['courseCardShowDescription'] as bool? ?? false,
      courseCardVerticalAlign: CourseCardVerticalAlignX.fromValue(
        json['courseCardVerticalAlign'] as String?,
      ),
      courseCardHorizontalAlign: CourseCardHorizontalAlignX.fromValue(
        json['courseCardHorizontalAlign'] as String?,
      ),
      courseCardFontSize: (json['courseCardFontSize'] as num?)?.toDouble() ?? 9,
      timetableTimeColumnWidthMode: TimetableTimeColumnWidthModeX.fromValue(
        json['timetableTimeColumnWidthMode'] as String?,
      ),
      timetableCourseCardGap:
          (json['timetableCourseCardGap'] as num?)?.toDouble() ??
          ((json['timetableCourseSpacingMode'] as String?) == 'wide'
              ? 2.0
              : 1.25),
      timetableCourseSpacingMode: TimetableCourseSpacingModeX.fromValue(
        json['timetableCourseSpacingMode'] as String?,
      ),
      widgetBackgroundStyle: WidgetBackgroundStyleX.fromValue(
        json['widgetBackgroundStyle'] as String?,
      ),
      widgetShowLocation: json['widgetShowLocation'] as bool? ?? true,
      widgetShowCountdown: json['widgetShowCountdown'] as bool? ?? true,
      widgetHideCompletedCourses:
          json['widgetHideCompletedCourses'] as bool? ?? false,
      widgetShowTomorrowCourses:
          json['widgetShowTomorrowCourses'] as bool? ?? true,
      widgetHeightAdjustment:
          (json['widgetHeightAdjustment'] as num?)?.toDouble() ?? -11,
      widgetCornerRadius:
          (json['widgetCornerRadius'] as num?)?.toDouble() ?? 22,
      widgetCountdownLeadMinutes:
          (json['widgetCountdownLeadMinutes'] as num?)?.toInt() ?? 20,
      widgetCountdownTextStyle: LiveCountdownTextStyleX.fromValue(
        json['widgetCountdownTextStyle'] as String?,
      ),
      appThemeMode: AppThemeModeX.fromValue(json['appThemeMode'] as String?),
      appFontMode: AppFontModeX.fromValue(json['appFontMode'] as String?),
      appLocaleTag: _normalizeAppLocaleTag(
        json['appLocaleTag'] as String? ?? json['appLocaleMode'] as String?,
      ),
      homeTitleStyle: HomeTitleStyleX.fromValue(
        json['homeTitleStyle'] as String?,
      ),
      timetableHomeViewMode: TimetableHomeViewModeX.fromValue(
        json['timetableHomeViewMode'] as String?,
      ),
      homeNavigationForm: HomeNavigationFormX.fromValue(
        json['homeNavigationForm'] as String?,
      ),
      timetableBackToCurrentWeekButtonStyle:
          BackToCurrentWeekButtonStyleX.fromValue(
            json['timetableBackToCurrentWeekButtonStyle'] as String?,
          ),
      timetableFloatingBackToCurrentWeekButtonOpacity:
          ((json['timetableFloatingBackToCurrentWeekButtonOpacity'] as num?)
                      ?.toDouble() ??
                  0.96)
              .clamp(0.55, 1.0),
      timetableLastViewedDayOfWeek:
          ((json['timetableLastViewedDayOfWeek'] as num?)?.toInt() ?? 1).clamp(
            1,
            7,
          ),
      coupleTimetableOverlayEnabled:
          json['coupleTimetableOverlayEnabled'] as bool? ?? false,
      timetableSectionTimeDisplayMode: SectionTimeDisplayModeX.fromValue(
        json['timetableSectionTimeDisplayMode'] as String?,
      ),
      timetableHideWeekends: json['timetableHideWeekends'] as bool? ?? false,
      enableHaptics: json['enableHaptics'] as bool? ?? true,
      pageTransitionSpeed:
          ((json['pageTransitionSpeed'] as num?)?.toDouble() ??
                  defaultPageTransitionSpeed)
              .clamp(minPageTransitionSpeed, maxPageTransitionSpeed),
      homePullQuickImportEnabled:
          json['homePullQuickImportEnabled'] as bool? ?? false,
      liveShowCourseName: json['liveShowCourseName'] as bool? ?? true,
      liveShowLocation: json['liveShowLocation'] as bool? ?? true,
      liveShowCountdown: json['liveShowCountdown'] as bool? ?? true,
      liveCountdownTextStyle: LiveCountdownTextStyleX.fromValue(
        json['liveCountdownTextStyle'] as String?,
      ),
      liveShowStageText: json['liveShowStageText'] as bool? ?? true,
      liveEnableBeforeClass: json['liveEnableBeforeClass'] as bool? ?? true,
      // Migrate: these two are controlled by a single UI switch.
      // If either is true, both should be true to avoid UI/logic mismatch.
      liveEnableDuringClass:
          (json['liveEnableDuringClass'] as bool? ?? true) ||
          (json['liveEnableBeforeEnd'] as bool? ?? true),
      liveEnableBeforeEnd:
          (json['liveEnableDuringClass'] as bool? ?? true) ||
          (json['liveEnableBeforeEnd'] as bool? ?? true),
      livePromoteDuringClass: json['livePromoteDuringClass'] as bool? ?? true,
      liveShowDuringClassNotification:
          json['liveShowDuringClassNotification'] as bool? ?? true,
      liveUseShortName: json['liveUseShortName'] as bool? ?? true,
      liveHidePrefixText: json['liveHidePrefixText'] as bool? ?? true,
      liveDuringClassTimeDisplayMode: LiveDuringClassTimeDisplayModeX.fromValue(
        json['liveDuringClassTimeDisplayMode'] as String?,
      ),
      liveEnableMiuiIslandLabelImage:
          json['liveEnableMiuiIslandLabelImage'] as bool? ?? false,
      liveDuringEndShowCourseName:
          json['liveDuringEndShowCourseName'] as bool? ??
          (json['liveShowCourseName'] as bool? ?? true),
      liveDuringEndShowLocation:
          json['liveDuringEndShowLocation'] as bool? ??
          (json['liveShowLocation'] as bool? ?? true),
      liveDuringEndShowCountdown:
          json['liveDuringEndShowCountdown'] as bool? ??
          (json['liveShowCountdown'] as bool? ?? true),
      liveDuringEndCountdownTextStyle: LiveCountdownTextStyleX.fromValue(
        json['liveDuringEndCountdownTextStyle'] as String? ??
            json['liveCountdownTextStyle'] as String?,
      ),
      liveDuringEndShowStageText:
          json['liveDuringEndShowStageText'] as bool? ??
          (json['liveShowStageText'] as bool? ?? true),
      liveDuringEndUseShortName:
          json['liveDuringEndUseShortName'] as bool? ??
          (json['liveUseShortName'] as bool? ?? true),
      liveDuringEndHidePrefixText:
          json['liveDuringEndHidePrefixText'] as bool? ??
          (json['liveHidePrefixText'] as bool? ?? true),
      liveDuringEndFollowBeforeClass:
          json['liveDuringEndFollowBeforeClass'] as bool? ?? true,
      liveDuringEndTimeDisplayMode: LiveDuringClassTimeDisplayModeX.fromValue(
        json['liveDuringEndTimeDisplayMode'] as String? ??
            json['liveDuringClassTimeDisplayMode'] as String?,
      ),
      liveDuringEndEnableMiuiIslandLabelImage:
          json['liveDuringEndEnableMiuiIslandLabelImage'] as bool? ??
          (json['liveEnableMiuiIslandLabelImage'] as bool? ?? false),
      liveHideFromRecents: json['liveHideFromRecents'] as bool? ?? false,
      liveEnableLocalDiagnostics:
          json['liveEnableLocalDiagnostics'] as bool? ?? false,
      liveMiuiIslandLabelStyle: MiuiIslandLabelStyleX.fromValue(
        json['liveMiuiIslandLabelStyle'] as String?,
      ),
      liveMiuiIslandLabelContent: MiuiIslandLabelContentX.fromValue(
        json['liveMiuiIslandLabelContent'] as String?,
      ),
      liveMiuiIslandLabelFontColor:
          json['liveMiuiIslandLabelFontColor'] as String? ?? '#FFFFFF',
      liveMiuiIslandLabelFontWeight: MiuiIslandLabelFontWeightX.fromValue(
        json['liveMiuiIslandLabelFontWeight'] as String?,
      ),
      liveMiuiIslandLabelRenderQuality: MiuiIslandLabelRenderQualityX.fromValue(
        json['liveMiuiIslandLabelRenderQuality'] as String?,
      ),
      liveMiuiIslandLabelFontSize:
          (json['liveMiuiIslandLabelFontSize'] as num?)?.toDouble() ?? 14,
      liveMiuiIslandLabelOffsetX:
          (json['liveMiuiIslandLabelOffsetX'] as num?)?.toDouble() ?? 0,
      liveMiuiIslandLabelOffsetY:
          (json['liveMiuiIslandLabelOffsetY'] as num?)?.toDouble() ?? 0,
      liveMiuiIslandLabelLogoPath:
          json['liveMiuiIslandLabelLogoPath'] as String?,
      liveMiuiIslandLabelLogoCornerRadius:
          (json['liveMiuiIslandLabelLogoCornerRadius'] as num?)?.toDouble() ??
          8,
      liveMiuiIslandExpandedIconMode: MiuiIslandExpandedIconModeX.fromValue(
        json['liveMiuiIslandExpandedIconMode'] as String?,
      ),
      liveMiuiIslandExpandedIconPath:
          json['liveMiuiIslandExpandedIconPath'] as String?,
      liveDuringEndMiuiIslandLabelStyle: MiuiIslandLabelStyleX.fromValue(
        json['liveDuringEndMiuiIslandLabelStyle'] as String? ??
            json['liveMiuiIslandLabelStyle'] as String?,
      ),
      liveDuringEndMiuiIslandLabelContent: MiuiIslandLabelContentX.fromValue(
        json['liveDuringEndMiuiIslandLabelContent'] as String? ??
            json['liveMiuiIslandLabelContent'] as String?,
      ),
      liveDuringEndMiuiIslandLabelFontColor:
          json['liveDuringEndMiuiIslandLabelFontColor'] as String? ??
          (json['liveMiuiIslandLabelFontColor'] as String? ?? '#FFFFFF'),
      liveDuringEndMiuiIslandLabelFontWeight:
          MiuiIslandLabelFontWeightX.fromValue(
            json['liveDuringEndMiuiIslandLabelFontWeight'] as String? ??
                json['liveMiuiIslandLabelFontWeight'] as String?,
          ),
      liveDuringEndMiuiIslandLabelRenderQuality:
          MiuiIslandLabelRenderQualityX.fromValue(
            json['liveDuringEndMiuiIslandLabelRenderQuality'] as String? ??
                json['liveMiuiIslandLabelRenderQuality'] as String?,
          ),
      liveDuringEndMiuiIslandLabelFontSize:
          (json['liveDuringEndMiuiIslandLabelFontSize'] as num?)?.toDouble() ??
          ((json['liveMiuiIslandLabelFontSize'] as num?)?.toDouble() ?? 14),
      liveDuringEndMiuiIslandLabelOffsetX:
          (json['liveDuringEndMiuiIslandLabelOffsetX'] as num?)?.toDouble() ??
          ((json['liveMiuiIslandLabelOffsetX'] as num?)?.toDouble() ?? 0),
      liveDuringEndMiuiIslandLabelOffsetY:
          (json['liveDuringEndMiuiIslandLabelOffsetY'] as num?)?.toDouble() ??
          ((json['liveMiuiIslandLabelOffsetY'] as num?)?.toDouble() ?? 0),
      liveDuringEndMiuiIslandLabelLogoPath:
          json['liveDuringEndMiuiIslandLabelLogoPath'] as String? ??
          json['liveMiuiIslandLabelLogoPath'] as String?,
      liveDuringEndMiuiIslandLabelLogoCornerRadius:
          (json['liveDuringEndMiuiIslandLabelLogoCornerRadius'] as num?)
              ?.toDouble() ??
          (json['liveMiuiIslandLabelLogoCornerRadius'] as num?)?.toDouble() ??
          8,
      liveDuringEndMiuiIslandExpandedIconMode:
          MiuiIslandExpandedIconModeX.fromValue(
            json['liveDuringEndMiuiIslandExpandedIconMode'] as String? ??
                json['liveMiuiIslandExpandedIconMode'] as String?,
          ),
      liveDuringEndMiuiIslandExpandedIconPath:
          json['liveDuringEndMiuiIslandExpandedIconPath'] as String? ??
          json['liveMiuiIslandExpandedIconPath'] as String?,
      liveShowBeforeClassMinutes:
          (json['liveShowBeforeClassMinutes'] as num?)?.toInt() ?? 20,
      liveClassReminderStartMinutes:
          (json['liveClassReminderStartMinutes'] as num?)?.toInt() ?? 0,
      liveEndSecondsCountdownThreshold:
          (json['liveEndSecondsCountdownThreshold'] as num?)?.toInt() ?? 60,
      liveTimeCorrectionSeconds:
          (json['liveTimeCorrectionSeconds'] as num?)?.toInt() ?? 0,
      liveBeforeClassQuickAction: LiveBeforeClassQuickActionX.fromValue(
        json['liveBeforeClassQuickAction'] as String?,
      ),
      themeSeedColor: json['themeSeedColor'] as String? ?? '#2563EB',
      foruiTheme: ForuiThemeX.fromValue(json['foruiTheme'] as String?),
      timetablePageBackgroundColor:
          json['timetablePageBackgroundColor'] as String? ?? '#F8FAFC',
      homePageBackgroundFill: HomePageBackgroundFillX.fromValue(
        json['homePageBackgroundFill'] as String?,
      ),
      homePageBackgroundImagePath:
          json['homePageBackgroundImagePath'] as String?,
      homePageWallpaperPath: json['homePageWallpaperPath'] as String?,
      homePageWallpaperAlignX:
          (json['homePageWallpaperAlignX'] as num?)?.toDouble() ?? 0,
      homePageWallpaperAlignY:
          (json['homePageWallpaperAlignY'] as num?)?.toDouble() ?? 0,
      homePageBackgroundScope:
          (json['homePageBackgroundScope'] as num?)?.toInt() ??
          HomePageBackgroundScope.defaultValue,
      timetableUseUnifiedCardColor:
          json['timetableUseUnifiedCardColor'] as bool? ?? false,
      timetableUnifiedCardColor:
          json['timetableUnifiedCardColor'] as String? ?? '#2563EB',
      appUpdateDownloadSource:
          json['appUpdateDownloadSource'] as String? ?? 'mirror',
      appUpdateDownloadChannel:
          json['appUpdateDownloadChannel'] as String? ?? 'pgyer',
      appUpdateUseSystemDownloader:
          json['appUpdateUseSystemDownloader'] as bool? ?? false,
      appUpdateMirrorPreset: (rawAppUpdateMirrorPreset == null
          ? AppUpdateMirrorPresetX.fromUrlPrefix(
              rawAppUpdateMirrorUrlPrefix,
            ).value
          : AppUpdateMirrorPresetX.fromValue(rawAppUpdateMirrorPreset).value),
      appUpdateIncludePrerelease:
          json['appUpdateIncludePrerelease'] as bool? ?? false,
      appUpdateMirrorUrlPrefix: rawAppUpdateMirrorUrlPrefix,
      pgyerApiKey: json['pgyerApiKey'] as String? ?? '',
      pgyerAppKey: json['pgyerAppKey'] as String? ?? '',
      holidayOverrideEnabled: json['holidayOverrideEnabled'] as bool? ?? false,
      courseCardTitleColorLight:
          json['courseCardTitleColorLight'] as String? ??
          defaultCourseCardTitleColor,
      courseCardTitleColorDark:
          json['courseCardTitleColorDark'] as String? ??
          defaultCourseCardTitleColor,
      courseCardDetailColorLight:
          json['courseCardDetailColorLight'] as String? ??
          defaultCourseCardDetailColor,
      courseCardDetailColorDark:
          json['courseCardDetailColorDark'] as String? ??
          defaultCourseCardDetailColor,
      weekdayBarFontColorLight:
          json['weekdayBarFontColorLight'] as String? ??
          defaultWeekdayBarFontColorLight,
      weekdayBarFontColorDark:
          json['weekdayBarFontColorDark'] as String? ??
          defaultWeekdayBarFontColorDark,
      weekdayBarAccentColorLight:
          json['weekdayBarAccentColorLight'] as String? ??
          defaultWeekdayBarAccentColorLight,
      weekdayBarAccentColorDark:
          json['weekdayBarAccentColorDark'] as String? ??
          defaultWeekdayBarAccentColorDark,
      timeAxisFontColorLight:
          json['timeAxisFontColorLight'] as String? ??
          defaultTimeAxisFontColorLight,
      timeAxisFontColorDark:
          json['timeAxisFontColorDark'] as String? ??
          defaultTimeAxisFontColorDark,
      linkCourseCardColors: json['linkCourseCardColors'] as bool? ?? true,
      frostedSheetBlurSigma:
          (json['frostedSheetBlurSigma'] as num?)?.toDouble() ??
          defaultFrostedSheetBlurSigma,
      frostedSheetTintAlpha:
          (json['frostedSheetTintAlpha'] as num?)?.toDouble() ??
          defaultFrostedSheetTintAlpha,
      frostedSheetBarrierAlpha:
          (json['frostedSheetBarrierAlpha'] as num?)?.toDouble() ??
          defaultFrostedSheetBarrierAlpha,
      frostedBlurEnabled:
          json['frostedBlurEnabled'] as bool? ?? defaultFrostedBlurEnabled,
      frostedGlassMode: FrostedGlassModeX.fromValue(
        json['frostedGlassMode'] as String?,
      ),
      courseCardSurfaceStyle: CourseCardSurfaceStyleX.fromValue(
        json['courseCardSurfaceStyle'] as String?,
      ),
      liquidGlassPreset: LiquidGlassPresetX.fromValue(
        json['liquidGlassPreset'] as String?,
      ),
      liquidGlassTuning: json['liquidGlassTuning'] != null
          ? LiquidGlassTuning.fromJson(
              json['liquidGlassTuning'] as Map<String, dynamic>,
            )
          : null,
      homePageHeaderBlurEnabled:
          json['homePageHeaderBlurEnabled'] as bool? ?? false,
      homePageWeekdayBarBlurEnabled:
          json['homePageWeekdayBarBlurEnabled'] as bool? ?? false,
      homePageTimeColumnBlurEnabled:
          json['homePageTimeColumnBlurEnabled'] as bool? ?? false,
      homePageBackdropFollowsWeekPager:
          json['homePageBackdropFollowsWeekPager'] as bool? ?? true,
      savedThemes:
          (json['savedThemes'] as List<dynamic>?)
              ?.map((t) => SavedTheme.fromJson(t as Map<String, dynamic>))
              .toList() ??
          const [],
      themeCheckpointName: json['themeCheckpointName'] as String?,
      themeCheckpointConfig: json['themeCheckpointConfig'] != null
          ? ThemeConfig.fromJson(
              json['themeCheckpointConfig'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory TimetableSettings.fromJsonString(String jsonString) {
    return TimetableSettings.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }

  TimetableSettings copyWith({
    List<SectionTime>? sections,
    String? activeTimeSchemeId,
    double? sectionHeight,
    double? compactFontSize,
    bool? timetableAutoFitSectionHeight,
    int? semesterWeekCount,
    DateTime? semesterStartDate,
    bool? weeklyReportEnabled,
    bool? enableHolidayMarking,
    bool? timetableShowCurrentWeekCourses,
    bool? timetableShowNonCurrentWeekCourses,
    bool? showConflictBadgeOnTimetable,
    double? timetableConflictCourseOpacity,
    bool? courseCardShowName,
    bool? courseCardShowTeacher,
    bool? courseCardShowLocation,
    bool? courseCardShowTime,
    bool? courseCardShowTimeLabels,
    bool? courseCardShowWeeks,
    bool? courseCardShowDescription,
    CourseCardVerticalAlign? courseCardVerticalAlign,
    CourseCardHorizontalAlign? courseCardHorizontalAlign,
    double? courseCardFontSize,
    TimetableTimeColumnWidthMode? timetableTimeColumnWidthMode,
    double? timetableCourseCardGap,
    TimetableCourseSpacingMode? timetableCourseSpacingMode,
    WidgetBackgroundStyle? widgetBackgroundStyle,
    bool? widgetShowLocation,
    bool? widgetShowCountdown,
    bool? widgetHideCompletedCourses,
    bool? widgetShowTomorrowCourses,
    double? widgetHeightAdjustment,
    double? widgetCornerRadius,
    int? widgetCountdownLeadMinutes,
    LiveCountdownTextStyle? widgetCountdownTextStyle,
    AppThemeMode? appThemeMode,
    AppFontMode? appFontMode,
    String? appLocaleTag,
    HomeTitleStyle? homeTitleStyle,
    TimetableHomeViewMode? timetableHomeViewMode,
    HomeNavigationForm? homeNavigationForm,
    BackToCurrentWeekButtonStyle? timetableBackToCurrentWeekButtonStyle,
    double? timetableFloatingBackToCurrentWeekButtonOpacity,
    int? timetableLastViewedDayOfWeek,
    bool? coupleTimetableOverlayEnabled,
    SectionTimeDisplayMode? timetableSectionTimeDisplayMode,
    bool? timetableHideWeekends,
    bool? enableHaptics,
    double? pageTransitionSpeed,
    bool? homePullQuickImportEnabled,
    bool? liveShowCourseName,
    bool? liveShowLocation,
    bool? liveShowCountdown,
    LiveCountdownTextStyle? liveCountdownTextStyle,
    bool? liveShowStageText,
    bool? liveEnableBeforeClass,
    bool? liveEnableDuringClass,
    bool? liveEnableBeforeEnd,
    bool? livePromoteDuringClass,
    bool? liveShowDuringClassNotification,
    bool? liveUseShortName,
    bool? liveHidePrefixText,
    LiveDuringClassTimeDisplayMode? liveDuringClassTimeDisplayMode,
    bool? liveEnableMiuiIslandLabelImage,
    bool? liveDuringEndShowCourseName,
    bool? liveDuringEndShowLocation,
    bool? liveDuringEndShowCountdown,
    LiveCountdownTextStyle? liveDuringEndCountdownTextStyle,
    bool? liveDuringEndShowStageText,
    bool? liveDuringEndUseShortName,
    bool? liveDuringEndHidePrefixText,
    bool? liveDuringEndFollowBeforeClass,
    LiveDuringClassTimeDisplayMode? liveDuringEndTimeDisplayMode,
    bool? liveDuringEndEnableMiuiIslandLabelImage,
    bool? liveHideFromRecents,
    bool? liveEnableLocalDiagnostics,
    MiuiIslandLabelStyle? liveMiuiIslandLabelStyle,
    MiuiIslandLabelContent? liveMiuiIslandLabelContent,
    String? liveMiuiIslandLabelFontColor,
    MiuiIslandLabelFontWeight? liveMiuiIslandLabelFontWeight,
    MiuiIslandLabelRenderQuality? liveMiuiIslandLabelRenderQuality,
    double? liveMiuiIslandLabelFontSize,
    double? liveMiuiIslandLabelOffsetX,
    double? liveMiuiIslandLabelOffsetY,
    String? liveMiuiIslandLabelLogoPath,
    bool clearLiveMiuiIslandLabelLogoPath = false,
    double? liveMiuiIslandLabelLogoCornerRadius,
    MiuiIslandExpandedIconMode? liveMiuiIslandExpandedIconMode,
    String? liveMiuiIslandExpandedIconPath,
    bool clearLiveMiuiIslandExpandedIconPath = false,
    MiuiIslandLabelStyle? liveDuringEndMiuiIslandLabelStyle,
    MiuiIslandLabelContent? liveDuringEndMiuiIslandLabelContent,
    String? liveDuringEndMiuiIslandLabelFontColor,
    MiuiIslandLabelFontWeight? liveDuringEndMiuiIslandLabelFontWeight,
    MiuiIslandLabelRenderQuality? liveDuringEndMiuiIslandLabelRenderQuality,
    double? liveDuringEndMiuiIslandLabelFontSize,
    double? liveDuringEndMiuiIslandLabelOffsetX,
    double? liveDuringEndMiuiIslandLabelOffsetY,
    String? liveDuringEndMiuiIslandLabelLogoPath,
    bool clearLiveDuringEndMiuiIslandLabelLogoPath = false,
    double? liveDuringEndMiuiIslandLabelLogoCornerRadius,
    MiuiIslandExpandedIconMode? liveDuringEndMiuiIslandExpandedIconMode,
    String? liveDuringEndMiuiIslandExpandedIconPath,
    bool clearLiveDuringEndMiuiIslandExpandedIconPath = false,
    int? liveShowBeforeClassMinutes,
    int? liveClassReminderStartMinutes,
    int? liveEndSecondsCountdownThreshold,
    int? liveTimeCorrectionSeconds,
    LiveBeforeClassQuickAction? liveBeforeClassQuickAction,
    String? themeSeedColor,
    ForuiTheme? foruiTheme,
    String? timetablePageBackgroundColor,
    HomePageBackgroundFill? homePageBackgroundFill,
    String? homePageBackgroundImagePath,
    bool clearHomePageBackgroundImagePath = false,
    String? homePageWallpaperPath,
    bool clearHomePageWallpaperPath = false,
    double? homePageWallpaperAlignX,
    double? homePageWallpaperAlignY,
    int? homePageBackgroundScope,
    bool? timetableUseUnifiedCardColor,
    String? timetableUnifiedCardColor,
    String? appUpdateDownloadSource,
    String? appUpdateDownloadChannel,
    bool? appUpdateUseSystemDownloader,
    String? appUpdateMirrorPreset,
    bool? appUpdateIncludePrerelease,
    String? appUpdateMirrorUrlPrefix,
    String? pgyerApiKey,
    String? pgyerAppKey,
    bool? holidayOverrideEnabled,
    String? courseCardTitleColorLight,
    String? courseCardTitleColorDark,
    String? courseCardDetailColorLight,
    String? courseCardDetailColorDark,
    String? weekdayBarFontColorLight,
    String? weekdayBarFontColorDark,
    String? weekdayBarAccentColorLight,
    String? weekdayBarAccentColorDark,
    String? timeAxisFontColorLight,
    String? timeAxisFontColorDark,
    bool? linkCourseCardColors,
    double? frostedSheetBlurSigma,
    double? frostedSheetTintAlpha,
    double? frostedSheetBarrierAlpha,
    bool? frostedBlurEnabled,
    FrostedGlassMode? frostedGlassMode,
    CourseCardSurfaceStyle? courseCardSurfaceStyle,
    LiquidGlassPreset? liquidGlassPreset,
    LiquidGlassTuning? liquidGlassTuning,
    bool? homePageHeaderBlurEnabled,
    bool? homePageWeekdayBarBlurEnabled,
    bool? homePageTimeColumnBlurEnabled,
    bool? homePageBackdropFollowsWeekPager,
    List<SavedTheme>? savedThemes,
    String? themeCheckpointName,
    ThemeConfig? themeCheckpointConfig,
    bool clearThemeCheckpoint = false,
  }) {
    return TimetableSettings(
      sections: sections ?? this.sections,
      activeTimeSchemeId: activeTimeSchemeId ?? this.activeTimeSchemeId,
      sectionHeight: sectionHeight ?? this.sectionHeight,
      compactFontSize: compactFontSize ?? this.compactFontSize,
      timetableAutoFitSectionHeight:
          timetableAutoFitSectionHeight ?? this.timetableAutoFitSectionHeight,
      semesterWeekCount: semesterWeekCount ?? this.semesterWeekCount,
      semesterStartDate: semesterStartDate ?? this.semesterStartDate,
      weeklyReportEnabled: weeklyReportEnabled ?? this.weeklyReportEnabled,
      enableHolidayMarking: enableHolidayMarking ?? this.enableHolidayMarking,
      timetableShowCurrentWeekCourses: true,
      timetableShowNonCurrentWeekCourses:
          timetableShowNonCurrentWeekCourses ??
          this.timetableShowNonCurrentWeekCourses,
      showConflictBadgeOnTimetable:
          showConflictBadgeOnTimetable ?? this.showConflictBadgeOnTimetable,
      timetableConflictCourseOpacity:
          (timetableConflictCourseOpacity ??
                  this.timetableConflictCourseOpacity)
              .clamp(0.2, 1.0),
      courseCardShowName: courseCardShowName ?? this.courseCardShowName,
      courseCardShowTeacher:
          courseCardShowTeacher ?? this.courseCardShowTeacher,
      courseCardShowLocation:
          courseCardShowLocation ?? this.courseCardShowLocation,
      courseCardShowTime: courseCardShowTime ?? this.courseCardShowTime,
      courseCardShowTimeLabels:
          courseCardShowTimeLabels ?? this.courseCardShowTimeLabels,
      courseCardShowWeeks: courseCardShowWeeks ?? this.courseCardShowWeeks,
      courseCardShowDescription:
          courseCardShowDescription ?? this.courseCardShowDescription,
      courseCardVerticalAlign:
          courseCardVerticalAlign ?? this.courseCardVerticalAlign,
      courseCardHorizontalAlign:
          courseCardHorizontalAlign ?? this.courseCardHorizontalAlign,
      courseCardFontSize: courseCardFontSize ?? this.courseCardFontSize,
      timetableTimeColumnWidthMode:
          timetableTimeColumnWidthMode ?? this.timetableTimeColumnWidthMode,
      timetableCourseCardGap:
          timetableCourseCardGap ?? this.timetableCourseCardGap,
      timetableCourseSpacingMode:
          timetableCourseSpacingMode ?? this.timetableCourseSpacingMode,
      widgetBackgroundStyle:
          widgetBackgroundStyle ?? this.widgetBackgroundStyle,
      widgetShowLocation: widgetShowLocation ?? this.widgetShowLocation,
      widgetShowCountdown: widgetShowCountdown ?? this.widgetShowCountdown,
      widgetHideCompletedCourses:
          widgetHideCompletedCourses ?? this.widgetHideCompletedCourses,
      widgetShowTomorrowCourses:
          widgetShowTomorrowCourses ?? this.widgetShowTomorrowCourses,
      widgetHeightAdjustment:
          widgetHeightAdjustment ?? this.widgetHeightAdjustment,
      widgetCornerRadius: widgetCornerRadius ?? this.widgetCornerRadius,
      widgetCountdownLeadMinutes:
          widgetCountdownLeadMinutes ?? this.widgetCountdownLeadMinutes,
      widgetCountdownTextStyle:
          widgetCountdownTextStyle ?? this.widgetCountdownTextStyle,
      appThemeMode: appThemeMode ?? this.appThemeMode,
      appFontMode: appFontMode ?? this.appFontMode,
      appLocaleTag: _normalizeAppLocaleTag(appLocaleTag ?? this.appLocaleTag),
      homeTitleStyle: homeTitleStyle ?? this.homeTitleStyle,
      timetableHomeViewMode:
          timetableHomeViewMode ?? this.timetableHomeViewMode,
      homeNavigationForm:
          homeNavigationForm ?? this.homeNavigationForm,
      timetableBackToCurrentWeekButtonStyle:
          timetableBackToCurrentWeekButtonStyle ??
          this.timetableBackToCurrentWeekButtonStyle,
      timetableFloatingBackToCurrentWeekButtonOpacity:
          (timetableFloatingBackToCurrentWeekButtonOpacity ??
                  this.timetableFloatingBackToCurrentWeekButtonOpacity)
              .clamp(0.55, 1.0),
      timetableLastViewedDayOfWeek:
          (timetableLastViewedDayOfWeek ?? this.timetableLastViewedDayOfWeek)
              .clamp(1, 7),
      coupleTimetableOverlayEnabled:
          coupleTimetableOverlayEnabled ?? this.coupleTimetableOverlayEnabled,
      timetableSectionTimeDisplayMode:
          timetableSectionTimeDisplayMode ??
          this.timetableSectionTimeDisplayMode,
      timetableHideWeekends:
          timetableHideWeekends ?? this.timetableHideWeekends,
      enableHaptics: enableHaptics ?? this.enableHaptics,
      pageTransitionSpeed: (pageTransitionSpeed ?? this.pageTransitionSpeed)
          .clamp(minPageTransitionSpeed, maxPageTransitionSpeed),
      homePullQuickImportEnabled:
          homePullQuickImportEnabled ?? this.homePullQuickImportEnabled,
      liveShowCourseName: liveShowCourseName ?? this.liveShowCourseName,
      liveShowLocation: liveShowLocation ?? this.liveShowLocation,
      liveShowCountdown: liveShowCountdown ?? this.liveShowCountdown,
      liveCountdownTextStyle:
          liveCountdownTextStyle ?? this.liveCountdownTextStyle,
      liveShowStageText: liveShowStageText ?? this.liveShowStageText,
      liveEnableBeforeClass:
          liveEnableBeforeClass ?? this.liveEnableBeforeClass,
      liveEnableDuringClass:
          liveEnableDuringClass ?? this.liveEnableDuringClass,
      liveEnableBeforeEnd: liveEnableBeforeEnd ?? this.liveEnableBeforeEnd,
      livePromoteDuringClass:
          livePromoteDuringClass ?? this.livePromoteDuringClass,
      liveShowDuringClassNotification:
          liveShowDuringClassNotification ??
          this.liveShowDuringClassNotification,
      liveUseShortName: liveUseShortName ?? this.liveUseShortName,
      liveHidePrefixText: liveHidePrefixText ?? this.liveHidePrefixText,
      liveDuringClassTimeDisplayMode:
          liveDuringClassTimeDisplayMode ?? this.liveDuringClassTimeDisplayMode,
      liveEnableMiuiIslandLabelImage:
          liveEnableMiuiIslandLabelImage ?? this.liveEnableMiuiIslandLabelImage,
      liveDuringEndShowCourseName:
          liveDuringEndShowCourseName ?? this.liveDuringEndShowCourseName,
      liveDuringEndShowLocation:
          liveDuringEndShowLocation ?? this.liveDuringEndShowLocation,
      liveDuringEndShowCountdown:
          liveDuringEndShowCountdown ?? this.liveDuringEndShowCountdown,
      liveDuringEndCountdownTextStyle:
          liveDuringEndCountdownTextStyle ??
          this.liveDuringEndCountdownTextStyle,
      liveDuringEndShowStageText:
          liveDuringEndShowStageText ?? this.liveDuringEndShowStageText,
      liveDuringEndUseShortName:
          liveDuringEndUseShortName ?? this.liveDuringEndUseShortName,
      liveDuringEndHidePrefixText:
          liveDuringEndHidePrefixText ?? this.liveDuringEndHidePrefixText,
      liveDuringEndFollowBeforeClass:
          liveDuringEndFollowBeforeClass ?? this.liveDuringEndFollowBeforeClass,
      liveDuringEndTimeDisplayMode:
          liveDuringEndTimeDisplayMode ?? this.liveDuringEndTimeDisplayMode,
      liveDuringEndEnableMiuiIslandLabelImage:
          liveDuringEndEnableMiuiIslandLabelImage ??
          this.liveDuringEndEnableMiuiIslandLabelImage,
      liveHideFromRecents: liveHideFromRecents ?? this.liveHideFromRecents,
      liveEnableLocalDiagnostics:
          liveEnableLocalDiagnostics ?? this.liveEnableLocalDiagnostics,
      liveMiuiIslandLabelStyle:
          liveMiuiIslandLabelStyle ?? this.liveMiuiIslandLabelStyle,
      liveMiuiIslandLabelContent:
          liveMiuiIslandLabelContent ?? this.liveMiuiIslandLabelContent,
      liveMiuiIslandLabelFontColor:
          liveMiuiIslandLabelFontColor ?? this.liveMiuiIslandLabelFontColor,
      liveMiuiIslandLabelFontWeight:
          liveMiuiIslandLabelFontWeight ?? this.liveMiuiIslandLabelFontWeight,
      liveMiuiIslandLabelRenderQuality:
          liveMiuiIslandLabelRenderQuality ??
          this.liveMiuiIslandLabelRenderQuality,
      liveMiuiIslandLabelFontSize:
          liveMiuiIslandLabelFontSize ?? this.liveMiuiIslandLabelFontSize,
      liveMiuiIslandLabelOffsetX:
          liveMiuiIslandLabelOffsetX ?? this.liveMiuiIslandLabelOffsetX,
      liveMiuiIslandLabelOffsetY:
          liveMiuiIslandLabelOffsetY ?? this.liveMiuiIslandLabelOffsetY,
      liveMiuiIslandLabelLogoPath: clearLiveMiuiIslandLabelLogoPath
          ? null
          : liveMiuiIslandLabelLogoPath ?? this.liveMiuiIslandLabelLogoPath,
      liveMiuiIslandLabelLogoCornerRadius:
          liveMiuiIslandLabelLogoCornerRadius ??
          this.liveMiuiIslandLabelLogoCornerRadius,
      liveMiuiIslandExpandedIconMode:
          liveMiuiIslandExpandedIconMode ?? this.liveMiuiIslandExpandedIconMode,
      liveMiuiIslandExpandedIconPath: clearLiveMiuiIslandExpandedIconPath
          ? null
          : liveMiuiIslandExpandedIconPath ??
                this.liveMiuiIslandExpandedIconPath,
      liveDuringEndMiuiIslandLabelStyle:
          liveDuringEndMiuiIslandLabelStyle ??
          this.liveDuringEndMiuiIslandLabelStyle,
      liveDuringEndMiuiIslandLabelContent:
          liveDuringEndMiuiIslandLabelContent ??
          this.liveDuringEndMiuiIslandLabelContent,
      liveDuringEndMiuiIslandLabelFontColor:
          liveDuringEndMiuiIslandLabelFontColor ??
          this.liveDuringEndMiuiIslandLabelFontColor,
      liveDuringEndMiuiIslandLabelFontWeight:
          liveDuringEndMiuiIslandLabelFontWeight ??
          this.liveDuringEndMiuiIslandLabelFontWeight,
      liveDuringEndMiuiIslandLabelRenderQuality:
          liveDuringEndMiuiIslandLabelRenderQuality ??
          this.liveDuringEndMiuiIslandLabelRenderQuality,
      liveDuringEndMiuiIslandLabelFontSize:
          liveDuringEndMiuiIslandLabelFontSize ??
          this.liveDuringEndMiuiIslandLabelFontSize,
      liveDuringEndMiuiIslandLabelOffsetX:
          liveDuringEndMiuiIslandLabelOffsetX ??
          this.liveDuringEndMiuiIslandLabelOffsetX,
      liveDuringEndMiuiIslandLabelOffsetY:
          liveDuringEndMiuiIslandLabelOffsetY ??
          this.liveDuringEndMiuiIslandLabelOffsetY,
      liveDuringEndMiuiIslandLabelLogoPath:
          clearLiveDuringEndMiuiIslandLabelLogoPath
          ? null
          : liveDuringEndMiuiIslandLabelLogoPath ??
                this.liveDuringEndMiuiIslandLabelLogoPath,
      liveDuringEndMiuiIslandLabelLogoCornerRadius:
          liveDuringEndMiuiIslandLabelLogoCornerRadius ??
          this.liveDuringEndMiuiIslandLabelLogoCornerRadius,
      liveDuringEndMiuiIslandExpandedIconMode:
          liveDuringEndMiuiIslandExpandedIconMode ??
          this.liveDuringEndMiuiIslandExpandedIconMode,
      liveDuringEndMiuiIslandExpandedIconPath:
          clearLiveDuringEndMiuiIslandExpandedIconPath
          ? null
          : liveDuringEndMiuiIslandExpandedIconPath ??
                this.liveDuringEndMiuiIslandExpandedIconPath,
      liveShowBeforeClassMinutes:
          liveShowBeforeClassMinutes ?? this.liveShowBeforeClassMinutes,
      liveClassReminderStartMinutes:
          liveClassReminderStartMinutes ?? this.liveClassReminderStartMinutes,
      liveEndSecondsCountdownThreshold:
          liveEndSecondsCountdownThreshold ??
          this.liveEndSecondsCountdownThreshold,
      liveTimeCorrectionSeconds:
          liveTimeCorrectionSeconds ?? this.liveTimeCorrectionSeconds,
      liveBeforeClassQuickAction:
          liveBeforeClassQuickAction ?? this.liveBeforeClassQuickAction,
      themeSeedColor: themeSeedColor ?? this.themeSeedColor,
      foruiTheme: foruiTheme ?? this.foruiTheme,
      timetablePageBackgroundColor:
          timetablePageBackgroundColor ?? this.timetablePageBackgroundColor,
      homePageBackgroundFill:
          homePageBackgroundFill ?? this.homePageBackgroundFill,
      homePageBackgroundImagePath: clearHomePageBackgroundImagePath
          ? null
          : homePageBackgroundImagePath ?? this.homePageBackgroundImagePath,
      homePageWallpaperPath: clearHomePageWallpaperPath
          ? null
          : homePageWallpaperPath ?? this.homePageWallpaperPath,
      homePageWallpaperAlignX:
          homePageWallpaperAlignX ?? this.homePageWallpaperAlignX,
      homePageWallpaperAlignY:
          homePageWallpaperAlignY ?? this.homePageWallpaperAlignY,
      homePageBackgroundScope:
          homePageBackgroundScope ?? this.homePageBackgroundScope,
      timetableUseUnifiedCardColor:
          timetableUseUnifiedCardColor ?? this.timetableUseUnifiedCardColor,
      timetableUnifiedCardColor:
          timetableUnifiedCardColor ?? this.timetableUnifiedCardColor,
      appUpdateDownloadSource:
          appUpdateDownloadSource ?? this.appUpdateDownloadSource,
      appUpdateDownloadChannel:
          appUpdateDownloadChannel ?? this.appUpdateDownloadChannel,
      appUpdateUseSystemDownloader:
          appUpdateUseSystemDownloader ?? this.appUpdateUseSystemDownloader,
      appUpdateMirrorPreset:
          appUpdateMirrorPreset ?? this.appUpdateMirrorPreset,
      appUpdateIncludePrerelease:
          appUpdateIncludePrerelease ?? this.appUpdateIncludePrerelease,
      appUpdateMirrorUrlPrefix:
          appUpdateMirrorUrlPrefix ?? this.appUpdateMirrorUrlPrefix,
      pgyerApiKey: pgyerApiKey ?? this.pgyerApiKey,
      pgyerAppKey: pgyerAppKey ?? this.pgyerAppKey,
      holidayOverrideEnabled:
          holidayOverrideEnabled ?? this.holidayOverrideEnabled,
      courseCardTitleColorLight:
          courseCardTitleColorLight ?? this.courseCardTitleColorLight,
      courseCardTitleColorDark:
          courseCardTitleColorDark ?? this.courseCardTitleColorDark,
      courseCardDetailColorLight:
          courseCardDetailColorLight ?? this.courseCardDetailColorLight,
      courseCardDetailColorDark:
          courseCardDetailColorDark ?? this.courseCardDetailColorDark,
      weekdayBarFontColorLight:
          weekdayBarFontColorLight ?? this.weekdayBarFontColorLight,
      weekdayBarFontColorDark:
          weekdayBarFontColorDark ?? this.weekdayBarFontColorDark,
      weekdayBarAccentColorLight:
          weekdayBarAccentColorLight ?? this.weekdayBarAccentColorLight,
      weekdayBarAccentColorDark:
          weekdayBarAccentColorDark ?? this.weekdayBarAccentColorDark,
      timeAxisFontColorLight:
          timeAxisFontColorLight ?? this.timeAxisFontColorLight,
      timeAxisFontColorDark:
          timeAxisFontColorDark ?? this.timeAxisFontColorDark,
      linkCourseCardColors: linkCourseCardColors ?? this.linkCourseCardColors,
      frostedSheetBlurSigma:
          frostedSheetBlurSigma ?? this.frostedSheetBlurSigma,
      frostedSheetTintAlpha:
          frostedSheetTintAlpha ?? this.frostedSheetTintAlpha,
      frostedSheetBarrierAlpha:
          frostedSheetBarrierAlpha ?? this.frostedSheetBarrierAlpha,
      frostedBlurEnabled: frostedBlurEnabled ?? this.frostedBlurEnabled,
      frostedGlassMode: frostedGlassMode ?? this.frostedGlassMode,
      courseCardSurfaceStyle:
          courseCardSurfaceStyle ?? this.courseCardSurfaceStyle,
      liquidGlassPreset: liquidGlassPreset ?? this.liquidGlassPreset,
      liquidGlassTuning: liquidGlassTuning ?? this.liquidGlassTuning,
      homePageHeaderBlurEnabled:
          homePageHeaderBlurEnabled ?? this.homePageHeaderBlurEnabled,
      homePageWeekdayBarBlurEnabled:
          homePageWeekdayBarBlurEnabled ?? this.homePageWeekdayBarBlurEnabled,
      homePageTimeColumnBlurEnabled:
          homePageTimeColumnBlurEnabled ?? this.homePageTimeColumnBlurEnabled,
      homePageBackdropFollowsWeekPager:
          homePageBackdropFollowsWeekPager ??
          this.homePageBackdropFollowsWeekPager,
      savedThemes: savedThemes ?? this.savedThemes,
      themeCheckpointName: clearThemeCheckpoint
          ? null
          : (themeCheckpointName ?? this.themeCheckpointName),
      themeCheckpointConfig: clearThemeCheckpoint
          ? null
          : (themeCheckpointConfig ?? this.themeCheckpointConfig),
    );
  }

  int get sectionCount => sections.length;

  /// 检查当前主题设置是否与检查点不同（即用户修改过）
  bool get hasThemeModifications {
    if (themeCheckpointConfig == null) return false;
    final currentConfig = ThemeConfig.fromSettings(this);
    final checkpoint = themeCheckpointConfig!;

    // 只比较检查点中非 null 的字段
    bool differs(String? Function(ThemeConfig c) getter) {
      final checkpointVal = getter(checkpoint);
      if (checkpointVal == null) return false; // 检查点未设置的字段不比较
      return getter(currentConfig) != checkpointVal;
    }

    return differs((c) => c.seedColor) ||
        differs((c) => c.backgroundColor) ||
        differs((c) => c.unifiedCardColor) ||
        differs((c) => c.useUnifiedCardColor?.toString()) ||
        differs((c) => c.themeMode) ||
        differs((c) => c.courseCardTitleColorLight) ||
        differs((c) => c.courseCardTitleColorDark) ||
        differs((c) => c.courseCardDetailColorLight) ||
        differs((c) => c.courseCardDetailColorDark) ||
        differs((c) => c.weekdayBarFontColorLight) ||
        differs((c) => c.weekdayBarFontColorDark) ||
        differs((c) => c.weekdayBarAccentColorLight) ||
        differs((c) => c.weekdayBarAccentColorDark) ||
        differs((c) => c.timeAxisFontColorLight) ||
        differs((c) => c.timeAxisFontColorDark) ||
        differs((c) => c.linkCourseCardColors?.toString()) ||
        differs((c) => c.hideWeekends?.toString()) ||
        differs((c) => c.spacingMode) ||
        differs((c) => c.timeDisplayMode);
  }

  LiveDisplaySettings get beforeClassDisplaySettings => LiveDisplaySettings(
    showCourseName: liveShowCourseName,
    showLocation: liveShowLocation,
    showCountdown: liveShowCountdown,
    countdownTextStyle: liveCountdownTextStyle,
    showStageText: liveShowStageText,
    useShortName: liveUseShortName,
    hidePrefixText: liveHidePrefixText,
    duringClassTimeDisplayMode: liveDuringClassTimeDisplayMode,
    enableMiuiIslandLabelImage: liveEnableMiuiIslandLabelImage,
    miuiIslandLabelStyle: liveMiuiIslandLabelStyle,
    miuiIslandLabelContent: liveMiuiIslandLabelContent,
    miuiIslandLabelFontColor: liveMiuiIslandLabelFontColor,
    miuiIslandLabelFontWeight: liveMiuiIslandLabelFontWeight,
    miuiIslandLabelRenderQuality: liveMiuiIslandLabelRenderQuality,
    miuiIslandLabelFontSize: liveMiuiIslandLabelFontSize,
    miuiIslandLabelOffsetX: liveMiuiIslandLabelOffsetX,
    miuiIslandLabelOffsetY: liveMiuiIslandLabelOffsetY,
    miuiIslandLabelLogoPath: liveMiuiIslandLabelLogoPath,
    miuiIslandLabelLogoCornerRadius: liveMiuiIslandLabelLogoCornerRadius,
    miuiIslandExpandedIconMode: liveMiuiIslandExpandedIconMode,
    miuiIslandExpandedIconPath: liveMiuiIslandExpandedIconPath,
  );

  LiveDisplaySettings get duringEndDisplaySettings =>
      liveDuringEndFollowBeforeClass
      ? beforeClassDisplaySettings
      : LiveDisplaySettings(
          showCourseName: liveDuringEndShowCourseName,
          showLocation: liveDuringEndShowLocation,
          showCountdown: liveDuringEndShowCountdown,
          countdownTextStyle: liveDuringEndCountdownTextStyle,
          showStageText: liveDuringEndShowStageText,
          useShortName: liveDuringEndUseShortName,
          hidePrefixText: liveDuringEndHidePrefixText,
          duringClassTimeDisplayMode: liveDuringEndTimeDisplayMode,
          enableMiuiIslandLabelImage: liveDuringEndEnableMiuiIslandLabelImage,
          miuiIslandLabelStyle: liveDuringEndMiuiIslandLabelStyle,
          miuiIslandLabelContent: liveDuringEndMiuiIslandLabelContent,
          miuiIslandLabelFontColor: liveDuringEndMiuiIslandLabelFontColor,
          miuiIslandLabelFontWeight: liveDuringEndMiuiIslandLabelFontWeight,
          miuiIslandLabelRenderQuality:
              liveDuringEndMiuiIslandLabelRenderQuality,
          miuiIslandLabelFontSize: liveDuringEndMiuiIslandLabelFontSize,
          miuiIslandLabelOffsetX: liveDuringEndMiuiIslandLabelOffsetX,
          miuiIslandLabelOffsetY: liveDuringEndMiuiIslandLabelOffsetY,
          miuiIslandLabelLogoPath: liveDuringEndMiuiIslandLabelLogoPath,
          miuiIslandLabelLogoCornerRadius:
              liveDuringEndMiuiIslandLabelLogoCornerRadius,
          miuiIslandExpandedIconMode: liveDuringEndMiuiIslandExpandedIconMode,
          miuiIslandExpandedIconPath: liveDuringEndMiuiIslandExpandedIconPath,
        );

  TimetableSettings copyWithBeforeClassDisplaySettings(
    LiveDisplaySettings settings, {
    bool clearExpandedIconPath = false,
    bool clearLabelLogoPath = false,
  }) {
    return copyWith(
      liveShowCourseName: settings.showCourseName,
      liveShowLocation: settings.showLocation,
      liveShowCountdown: settings.showCountdown,
      liveCountdownTextStyle: settings.countdownTextStyle,
      liveShowStageText: settings.showStageText,
      liveUseShortName: settings.useShortName,
      liveHidePrefixText: settings.hidePrefixText,
      liveDuringClassTimeDisplayMode: settings.duringClassTimeDisplayMode,
      liveEnableMiuiIslandLabelImage: settings.enableMiuiIslandLabelImage,
      liveMiuiIslandLabelStyle: settings.miuiIslandLabelStyle,
      liveMiuiIslandLabelContent: settings.miuiIslandLabelContent,
      liveMiuiIslandLabelFontColor: settings.miuiIslandLabelFontColor,
      liveMiuiIslandLabelFontWeight: settings.miuiIslandLabelFontWeight,
      liveMiuiIslandLabelRenderQuality: settings.miuiIslandLabelRenderQuality,
      liveMiuiIslandLabelFontSize: settings.miuiIslandLabelFontSize,
      liveMiuiIslandLabelOffsetX: settings.miuiIslandLabelOffsetX,
      liveMiuiIslandLabelOffsetY: settings.miuiIslandLabelOffsetY,
      liveMiuiIslandLabelLogoPath: settings.miuiIslandLabelLogoPath,
      liveMiuiIslandLabelLogoCornerRadius:
          settings.miuiIslandLabelLogoCornerRadius,
      clearLiveMiuiIslandLabelLogoPath: clearLabelLogoPath,
      liveMiuiIslandExpandedIconMode: settings.miuiIslandExpandedIconMode,
      liveMiuiIslandExpandedIconPath: settings.miuiIslandExpandedIconPath,
      clearLiveMiuiIslandExpandedIconPath: clearExpandedIconPath,
    );
  }

  TimetableSettings copyWithDuringEndDisplaySettings(
    LiveDisplaySettings settings, {
    bool clearExpandedIconPath = false,
    bool clearLabelLogoPath = false,
  }) {
    return copyWith(
      liveDuringEndShowCourseName: settings.showCourseName,
      liveDuringEndShowLocation: settings.showLocation,
      liveDuringEndShowCountdown: settings.showCountdown,
      liveDuringEndCountdownTextStyle: settings.countdownTextStyle,
      liveDuringEndShowStageText: settings.showStageText,
      liveDuringEndUseShortName: settings.useShortName,
      liveDuringEndHidePrefixText: settings.hidePrefixText,
      liveDuringEndTimeDisplayMode: settings.duringClassTimeDisplayMode,
      liveDuringEndEnableMiuiIslandLabelImage:
          settings.enableMiuiIslandLabelImage,
      liveDuringEndMiuiIslandLabelStyle: settings.miuiIslandLabelStyle,
      liveDuringEndMiuiIslandLabelContent: settings.miuiIslandLabelContent,
      liveDuringEndMiuiIslandLabelFontColor: settings.miuiIslandLabelFontColor,
      liveDuringEndMiuiIslandLabelFontWeight:
          settings.miuiIslandLabelFontWeight,
      liveDuringEndMiuiIslandLabelRenderQuality:
          settings.miuiIslandLabelRenderQuality,
      liveDuringEndMiuiIslandLabelFontSize: settings.miuiIslandLabelFontSize,
      liveDuringEndMiuiIslandLabelOffsetX: settings.miuiIslandLabelOffsetX,
      liveDuringEndMiuiIslandLabelOffsetY: settings.miuiIslandLabelOffsetY,
      liveDuringEndMiuiIslandLabelLogoPath: settings.miuiIslandLabelLogoPath,
      liveDuringEndMiuiIslandLabelLogoCornerRadius:
          settings.miuiIslandLabelLogoCornerRadius,
      clearLiveDuringEndMiuiIslandLabelLogoPath: clearLabelLogoPath,
      liveDuringEndMiuiIslandExpandedIconMode:
          settings.miuiIslandExpandedIconMode,
      liveDuringEndMiuiIslandExpandedIconPath:
          settings.miuiIslandExpandedIconPath,
      clearLiveDuringEndMiuiIslandExpandedIconPath: clearExpandedIconPath,
    );
  }

  List<int> get availableWeeks =>
      List.generate(semesterWeekCount, (index) => index + 1);

  SectionTime sectionAt(int section) => sections[section - 1];
}
