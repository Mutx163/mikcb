// 从 timetable_settings.dart 拆出的枚举值映射与更新镜像解析（2026-10-19）。
// 只依赖 timetable_settings_enums.dart，不反向依赖宿主。

import 'timetable_settings_enums.dart';

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

  /// 解析旧档：inline（时间栏内嵌小字）已收敛为浮钮唯一入口，
  /// 存量 'inline' 值迁移为 floating；枚举保留两值仅为兼容旧 JSON。
  static BackToCurrentWeekButtonStyle fromValue(String? value) {
    if (value == 'floating') {
      return BackToCurrentWeekButtonStyle.floating;
    }
    // 'inline' 与未知值一律落到 floating。
    return BackToCurrentWeekButtonStyle.floating;
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
    LiveBeforeClassQuickAction.priorityOnly => 'priority_only',
    LiveBeforeClassQuickAction.both => 'both',
  };

  /// 该动作是否需要「勿扰模式访问权限」。Android 13+ 连静音档
  /// （setRingerMode(SILENT)）也被并入这套策略，未授权直接抛异常。
  bool get requiresDoNotDisturbAccess => switch (this) {
    LiveBeforeClassQuickAction.none => false,
    LiveBeforeClassQuickAction.silent => false,
    LiveBeforeClassQuickAction.doNotDisturb => true,
    LiveBeforeClassQuickAction.priorityOnly => true,
    LiveBeforeClassQuickAction.both => true,
  };

  static LiveBeforeClassQuickAction fromValue(String? value) {
    return LiveBeforeClassQuickAction.values.firstWhere(
      (item) => item.value == value,
      orElse: () => LiveBeforeClassQuickAction.none,
    );
  }
}

/// Visual surface style for course cards.
///
/// 只保留三档：实体卡片、高斯模糊、液态玻璃。旧版本的「半透明」「玻璃（液态
/// 玻璃）」档位已下线，读取旧配置时分别并入实体/高斯（见
/// [CourseCardSurfaceStyleX.fromValue]）。
enum CourseCardSurfaceStyle {
  /// Solid opaque card with gradient wash (default).
  solid,

  /// Gaussian blur backdrop over the page background.
  gaussian,

  /// 液态玻璃：在**共享的**预模糊壁纸位上跑一遍折射着色器，卡片边缘按圆角
  /// SDF 把背景「掰弯」，再叠染色与受光边缘高光。
  ///
  /// 与 [gaussian] 的关系：两者采的是同一份预模糊位图（同一份
  /// `PreblurredWallpaperCache` 出图，全部卡片共用），差别只在最后一步 ——
  /// 高斯档直接贴图，这一档多跑一次折射着色器。因此它不会因为卡片变多而
  /// 更贵，是「实体卡片 / 高斯模糊」之外的第三种材质。
  ///
  /// 与全局「液态玻璃」材质（弹层 / 顶栏 / 玻璃坞）同源：同一份着色器家族、
  /// 同一套调参，只是卡片走共享预模糊位图、其他表面走实时背景。
  liquidGlass,
}

extension CourseCardSurfaceStyleX on CourseCardSurfaceStyle {
  /// 持久化值。**刻意不等于 `name`**：新档的枚举名是 `liquidGlass`，但磁盘上
  /// 沿用 `'refraction'` —— `'liquidGlass'` 这个字符串已经被老版本的「玻璃」
  /// 档占用（语义是现在的高斯磨砂，见 [fromValue]），跟着枚举改名会让存量配置
  /// 悄悄换材质。
  String get value => switch (this) {
    CourseCardSurfaceStyle.solid => 'solid',
    CourseCardSurfaceStyle.gaussian => 'gaussian',
    CourseCardSurfaceStyle.liquidGlass => 'refraction',
  };

  /// 是否属于「寄生在共享预模糊壁纸上」的玻璃材质（高斯模糊 / 液态玻璃）。
  ///
  /// 这两档共享同一套前置条件与墨色规则，判断「是不是玻璃材质」一律用这个，
  /// **不要写 `== gaussian`**：那样每新增一档玻璃就要满仓找一遍漏改点
  /// （壁纸采样开关、摘要卡铬玻璃、墨色自动黑白、进度条半透明填充）。
  bool get isGlass => this != CourseCardSurfaceStyle.solid;

  static CourseCardSurfaceStyle fromValue(String? value) {
    // 旧档位迁移：半透明并入实体卡片；玻璃 / 旧液态玻璃并入高斯模糊。
    // 注意 'glass' 与 'liquidGlass' 这两个历史字符串**不是**现在的液态玻璃
    // 档：老配置里它们指的是当年那档液态玻璃，语义上就是现在的高斯磨砂。
    // 液态玻璃档的持久化值是 'refraction'（见 [value]），由下面的按值匹配
    // 命中，所以本档既不需要改磁盘格式，也不会抢走那两条历史值。
    switch (value) {
      case 'translucent':
        return CourseCardSurfaceStyle.solid;
      case 'glass':
      case 'liquidGlass':
        return CourseCardSurfaceStyle.gaussian;
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
    AppUpdateDownloadChannel.gitcode => 'gitcode',
  };

  /// 该渠道是否属于国内源：GitCode 直连与蒲公英都是国内可直连的渠道。
  /// 教务适配仓、鸣谢名单等同步 API 据此优先走 GitCode 镜像（失败自动
  /// 回退 GitHub raw）；GitHub 渠道保持直连 GitHub 主仓不变。
  bool get preferGitCodeSync =>
      this == AppUpdateDownloadChannel.gitcode ||
      this == AppUpdateDownloadChannel.pgyer;

  static AppUpdateDownloadChannel fromValue(String? value) {
    return AppUpdateDownloadChannel.values.firstWhere(
      (item) => item.value == value,
      orElse: () => AppUpdateDownloadChannel.gitcode,
    );
  }
}

extension AppUpdateMirrorPresetX on AppUpdateMirrorPreset {
  String get value => switch (this) {
    AppUpdateMirrorPreset.ghfast => 'ghfast',
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
    AppUpdateMirrorPreset.ghLlkk => ghLlkkMirrorUrlPrefix,
    AppUpdateMirrorPreset.ghProxyCom => ghProxyComMirrorUrlPrefix,
    AppUpdateMirrorPreset.ghproxyNet => ghproxyNetMirrorUrlPrefix,
    AppUpdateMirrorPreset.custom =>
      normalizedCustomUrlPrefix.isEmpty
          ? defaultAppUpdateMirrorUrlPrefix
          : normalizedCustomUrlPrefix,
  };
}