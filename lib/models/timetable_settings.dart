import 'dart:convert';
import 'package:university_timetable/models/frosted_appearance.dart';
import 'package:university_timetable/models/course_glass_tuning.dart';
import 'package:university_timetable/models/liquid_glass_tuning.dart';
import 'package:university_timetable/utils/widget_course_accent.dart';
import 'package:university_timetable/models/class_reminder.dart';
import 'package:university_timetable/models/wallpaper_history.dart';

import 'settings/timetable_settings_enums.dart';
import 'settings/timetable_settings_extensions.dart';
import 'settings/timetable_settings_live.dart';

export 'settings/timetable_settings_enums.dart';
export 'settings/timetable_settings_extensions.dart';
export 'settings/timetable_settings_live.dart';

// 2026-10-19：设置枚举/值映射/直播与节次模型拆到 settings/ 子目录；
// 本文件只留 TimetableSettings 及其主题配置。原有 import 路径由上面的
// export 保持可用，调用点无需改动。

List<String>? _safeStringList(dynamic raw) {
  if (raw is! List) return null;
  final out = <String>[];
  for (final item in raw) {
    if (item is String) out.add(item);
  }
  return out;
}

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
    final rawId = json['id'];
    final rawName = json['name'];
    if (rawId is! String || rawId.trim().isEmpty) {
      throw const FormatException('missing theme id');
    }
    if (rawName is! String || rawName.trim().isEmpty) {
      throw const FormatException('missing theme name');
    }
    final rawThemeData = json['themeData'];
    if (rawThemeData is! Map) {
      throw const FormatException('missing themeData');
    }
    final themeDataJson = Map<String, dynamic>.from(rawThemeData);
    final rawCreated = json['createdAt'];
    if (rawCreated is! String || rawCreated.trim().isEmpty) {
      throw const FormatException('missing theme createdAt');
    }
    final parsedCreated = DateTime.tryParse(rawCreated);
    if (parsedCreated == null) {
      throw FormatException('invalid theme createdAt: $rawCreated');
    }
    return SavedTheme(
      id: rawId,
      name: rawName,
      config: ThemeConfig.fromJson(themeDataJson),
      createdAt: parsedCreated,
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

  static const bool defaultFrostedBlurEnabled = true;

  /// 玻璃坞（含坞内圆钮）要不要走高级材质。
  ///
  /// 这是**硕果仅存**的作用范围开关：弹窗家族（下拉小弹窗 / 全屏选择面板 /
  /// 底部弹窗与对话框 / 选择器圆钮）自 2026-09-19 起都锁成「永远液态玻璃的
  /// 标准档」，用户改不动，对应的四个开关与字段已整体删除；坞跟随用户在
  /// 「课程页面」选的档位，所以保留这一个开关。
  static const bool defaultLiquidGlassDockEnabled = true;

  /// 液态玻璃的深色档是否跟随浅色档（默认跟随）。
  ///
  /// 见 `.agents/notes/proposed/architecture/2026-09-21-liquid-glass-light-dark-pair.md`：
  /// 浅色档是用户调的那一份（[liquidGlassTuning]，存储 key 未变，存量零迁移）；
  /// 深色默认以它为形状再套配方，用户想独立设一套时才关掉这个开关。
  static const bool defaultLinkLiquidGlassTuning = true;

  /// 深色模式是否套用「变暗配方」（[LiquidGlassDarkRecipe.standard]）。
  ///
  /// 产品默认开。关掉 = 退回今天的行为（白底 + 深色收 15%），**这是本改动的回滚开关**。
  /// 只作用于深色，浅色恒走恒等配方、逐位不变。
  static const bool defaultDarkGlassBoostEnabled = true;

  /// 首页顶栏玻璃带材质：`liquid` / `solid`（液态玻璃 / 实体）。
  ///
  /// **2026-09-20 口径收成两档**，与外观编辑器里那个开关的两个选项逐字一致
  /// （`settings_appearance_editor.dart` 的「首页顶栏玻璃」分段控件）。历史上是
  /// progressive / gaussian / soft / liquid / solid 五档，但界面早就只提供
  /// 「实体 / 液态玻璃」两个选项，并且把中间三档**显示**成液态 —— 于是存量用户
  /// 界面上看到「液态玻璃」被选中、实际渲染的却是渐进磨砂（只有模糊 + 衬底，
  /// 没有折射也没有边光那一圈），真机口径就是「顶栏没有玻璃效果」而底栏（走全局
  /// 材质）却有（用户 2026-09-20 报的正是这个）。现在**存储层就归到液态**，
  /// 界面 / 渲染 / 预设三层同口径：非实体即液态。
  ///
  /// 降级不靠这个值：液态档在引擎没有 shader 后端时会自己回落到
  /// `HomePageChromeGlassFill` 的 `frostBand()`（就是原来渐进磨砂那条链路），
  /// 所以把中间三档并进液态不会让任何设备变得更差。
  static const String defaultHomeBandGlassMaterial = 'liquid';
  static const List<String> homeBandGlassMaterialValues = [
    'follow',
    'liquid',
    'solid',
  ];

  /// 非 `solid` / `follow` 一律归到液态（含 progressive / gaussian / soft 三个
  /// 存量档与一切非法值）：界面只承诺「跟随默认 / 实体 / 液态玻璃」三档，
  /// 存储与渲染必须同口径。
  static String sanitizeHomeBandGlassMaterial(String? value) => switch (value) {
    'solid' => 'solid',
    'follow' => 'follow',
    _ => 'liquid',
  };
  static const double defaultPageTransitionSpeed = 1;
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

  /// 天气显示位置：这三个只管「画不画」，不管要不要拉数据——拉数据由设备级的
  /// `WeatherPreferences.enabled` 决定（见 `WeatherProvider`）。分开的理由：
  /// 天气不属于课表领域，provider 不该反向依赖本模型才能判断是否需要刷新。
  final bool weatherShowOnDayCard;
  final bool weatherShowOnWeekCard;
  final bool weatherShowOnSheet;

  /// 天气那一行显示哪几项。三项全关时整行不渲染（不留空行）。
  /// 现象这一项同时决定图标：勾上才有图标与「小雨」这类文字。
  final bool weatherShowPhenomenon;
  final bool weatherShowTemperature;
  final bool weatherShowProbability;

  final CourseCardVerticalAlign courseCardVerticalAlign;
  final CourseCardHorizontalAlign courseCardHorizontalAlign;
  final double courseCardFontSize;
  final TimetableTimeColumnWidthMode timetableTimeColumnWidthMode;
  final double timetableCourseCardGap;
  final TimetableCourseSpacingMode timetableCourseSpacingMode;
  final WidgetBackgroundStyle widgetBackgroundStyle;

  /// 课程色贯穿档位：关闭 / 只加色条 / 色条+文字。
  final WidgetCourseAccentMode widgetCourseAccentMode;
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

  /// 全局字重（100–900）。默认 400 不覆盖 Theme/Miuix 字重。
  final int appFontWeight;

  /// 全局字号缩放（0.85–1.6）。默认 1.0 跟随系统 textScaler。
  final double appTextScale;
  final String appLocaleTag;
  final HomeTitleStyle homeTitleStyle;
  final TimetableHomeViewMode timetableHomeViewMode;
  final HomeNavigationForm homeNavigationForm;

  /// 首页右上角「更多」菜单形态（列表弹窗 / 八宫格瓷贴）。
  final HomeMenuStyle homeMenuStyle;

  /// 八宫格菜单的按钮排列（动作 id，见 [HomeGridMenu]）。
  /// 空表表示使用 [HomeGridMenu.defaultActions] 的默认排列。
  final List<String> homeGridMenuActions;

  /// 玻璃坞底栏按钮排列（'day'/'week' 为视图动作，其余为目录 id）。
  final List<String> glassDockActions;

  /// 玻璃坞入口开关：日课表 Tab 是否显示。
  /// 至少保留一个模块 Tab 由 UI 层约束（设置页在关闭最后一个时锁定）。
  final bool glassDockShowDayTab;

  /// 玻璃坞入口开关：设置 Tab 是否显示。
  final bool glassDockShowSettingsTab;

  /// 玻璃坞入口开关：周课表 Tab 是否显示。与日/设置同规则，
  /// 三者至少保留一个；隐藏周课表 Tab 不影响周视图本身继续作为底图。
  final bool glassDockShowWeekTab;

  /// 玻璃坞独立圆形按钮（extraButton）打开的入口 id。
  /// 默认 'addCourse' 走首页添加弹层；其余 id 由八宫格目录分发，
  /// 未知/不可见 id 运行时回退添加弹层。结构 Tab（day/week/settings）
  /// 不允许作为按钮目标，由 UI 层过滤。圆钮可另选自定义图标：
  /// [glassDockButtonIconName] 存 Miuix 扩展图标名（小驼峰），null =
  /// 按功能自动（addCourse 显示加号，其余显示目录图标）。
  final String glassDockButtonEntryId;
  final String? glassDockButtonIconName;

  /// 玻璃坞入口开关：是否显示独立的圆形「添加」按钮（extraButton），
  /// 点击执行 [glassDockButtonEntryId] 对应功能。
  final bool glassDockShowAddButton;
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

  /// 截屏后是否在课表页浮出「分享干净的课表图」提示。
  ///
  /// 只影响**提示**：关掉它，课表页右上角菜单里的手动分享入口照常可用。
  /// 平台不支持（Android 14 以下）时该开关在设置页不展示 —— 系统没有那个
  /// 回调，开了也不会响。
  final bool screenshotSharePromptEnabled;

  /// When true, long-pressing an empty timetable slot marks it with a dashed
  /// "+ slot" that opens the add-course form prefilled with that day/section.
  final bool longPressEmptySlotToAddCourseEnabled;
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

  /// 展开态详情字段（可见+顺序）；null = 全部显示。存原始字符串以便原生透传。
  final List<String>? liveExpandedDetailFields;
  final List<String>? liveDuringEndExpandedDetailFields;
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

  /// 上课前自动执行快捷操作的提前分钟数；0 表示不自动执行（仅保留通知按钮）。
  final int liveBeforeClassQuickActionAutoMinutes;
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

  /// 壁纸放大倍数（1 = 刚好铺满屏幕，也就是 cover 的原始大小）。
  ///
  /// 位置编辑页的双指缩放写它；渲染侧按它把图整体放大（见
  /// `homePageBackdropImageWidget`），仍在同一套 [homePageWallpaperAlignX] /
  /// [homePageWallpaperAlignY] 的裁剪窗口里取景 —— 放大后溢出量随之变大，
  /// 可拖动的范围也跟着变大（编辑页按同一个溢出量折算拖动位移，
  /// 见 `wallpaperOverflowDragExtent`）。
  ///
  /// 钳制口径在渲染 / 编辑两侧共用 `kWallpaperMinScale` / `kWallpaperMaxScale`
  /// （见 `utils/home_page_background.dart`）：下限 1（再小就露出底色）、
  /// 上限 4（够看细节，再大只是糊）。
  final double homePageWallpaperScale;

  /// 首页壁纸「最近使用」历史，最新在前，最多 10 条。
  ///
  /// 记录用户设置过的每一张壁纸：自选图片与内置预设共用同一条列表，条目 key
  /// 与首页背景身份键同口径（见 utils/wallpaper_history.dart）。图片条目对应
  /// 的文件会保留在文档目录，只有被挤出列表时才删除。
  final List<WallpaperHistoryEntry> wallpaperHistory;
  final int homePageBackgroundScope;
  final bool timetableUseUnifiedCardColor;
  final String timetableUnifiedCardColor;
  final String appUpdateDownloadSource;
  final String appUpdateDownloadChannel;
  final bool appUpdateUseSystemDownloader;
  final String appUpdateMirrorPreset;
  final bool appUpdateIncludePrerelease;
  final String appUpdateMirrorUrlPrefix;

  /// 检测到新版本时是否在首页自动弹出更新提醒；关闭后仅显示红点角标。
  final bool appUpdatePromptEnabled;
  final bool holidayOverrideEnabled;

  /// 上课闹钟：提前量与是否跳过系统时钟确认页。
  final int classAlarmLeadMinutes;
  final bool classAlarmSkipUi;

  /// 单节课提醒：按「课程 + 真实日期」一次性生效的本地通知提醒（保留兼容）。
  /// 新的「这节课闹钟」改为写入系统时钟，不再新增此类条目。
  final List<ClassReminderEntry> classReminders;
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
  ///
  /// 弹层的三枚观感量（模糊半径 / 染色 / 遮罩深度）2026-09-23 起不再是用户
  /// 设置 —— 没有任何界面能改它们，字段已从设置里删除。外观对象仍带这三个
  /// 值（渲染注入口），但只能取内置常量（`kDefaultFrostedSheet*`）。
  FrostedAppearance get frostedAppearance => FrostedAppearance(
    blurEnabled: frostedBlurEnabled,
    sheetBlurSigma: kDefaultFrostedSheetBlurSigma,
    sheetTintAlpha: kDefaultFrostedSheetTintAlpha,
    sheetBarrierAlpha: kDefaultFrostedSheetBarrierAlpha,
    liquidGlassTuning: liquidGlassTuning,
    liquidGlassTuningDark: liquidGlassTuningDark,
    linkLiquidGlassTuning: linkLiquidGlassTuning,
    darkGlassBoostEnabled: darkGlassBoostEnabled,
    courseCardGlassTuning: courseCardGlassTuning,
    liquidGlassDockEnabled: liquidGlassDockEnabled,
    // 外观对象只带**生效值**：`follow` 在这里就解析掉，下游（渲染、预热、
    // 预览）拿到的永远是 solid / liquid 两者之一。
    homeBandGlassMaterial: homeBandGlassMaterialEffective,
  );

  final bool linkCourseCardColors; // 标题和详情颜色是否关联

  /// 模糊总开关：关掉即整机「实体卡片」档。
  ///
  /// **它就是全局材质档**（`GlassModeChoice` 两档里较钝的那一档）：2026-09-30
  /// 高斯模糊退场后，整机不再有第二种玻璃材质，「实体卡片 / 液态玻璃」只剩
  /// 「不模糊 / 模糊 + 折射」这一个区别。
  final bool frostedBlurEnabled;

  /// 玻璃坞（含坞内圆钮）要不要走液态玻璃（见 [FrostedAppearance] 同名字段）。
  ///
  /// 弹窗家族那四个同族开关已随「小件永远锁标准档」删除，只剩这一个 ——
  /// 高斯模糊档同日退场后，它成了液态档下**唯一**能让某个表面退回磨砂的开关。
  final bool liquidGlassDockEnabled;
  final CourseCardSurfaceStyle courseCardSurfaceStyle;

  /// 液态玻璃预设与自定义参数（[liquidGlassTuning] 为 null 时渲染回落
  /// [LiquidGlassTuning.defaults]）。口径与渐进完全一致：预设是非空
  /// 枚举（reset 能落回 standard），参数对象可空。
  ///
  /// **2026-09-21 起 [liquidGlassTuning] 语义明确为「浅色档」**（存储 key 未变 ⇒
  /// 存量零迁移）；深色档见 [liquidGlassTuningDark]，两个开关见
  /// [linkLiquidGlassTuning] / [darkGlassBoostEnabled]。
  final LiquidGlassPreset liquidGlassPreset;
  final LiquidGlassTuning? liquidGlassTuning;

  /// 液态玻璃的**深色档**。null = 跟随浅色档（见 [linkLiquidGlassTuning]）。
  final LiquidGlassTuning? liquidGlassTuningDark;

  /// 深色档是否跟随浅色档（默认 [defaultLinkLiquidGlassTuning]）。
  ///
  /// `false` = 用户单独设了深色一套。注意 [copyWith] 对可空字段用 `??` 语义，
  /// **清不掉** [liquidGlassTuningDark] —— 这是有意的：关掉开关只是"不使用"，
  /// 用户再打开时应拿回原来那套深色设置，而不是被清空。
  final bool linkLiquidGlassTuning;

  /// 深色模式是否套用「变暗配方」（默认 [defaultDarkGlassBoostEnabled]）。
  final bool darkGlassBoostEnabled;

  /// **课程卡片自己那套**液态玻璃参数。null = 出厂卡片档
  /// [CourseGlassTuning.courseCard]。
  ///
  /// 刻意与 [liquidGlassTuning] 分开：卡片与全局是两套独立配置，共享的只有解析入口、
  /// 深浅配方与**档位表**（那 10 格预设引的是同一批常量，见 [courseCardGlassPreset]）。
  /// 为什么不是「另一个 [LiquidGlassTuning] 实例」这类复用：那份的 `fromJson` 缺键
  /// 无法区分"卡片的出厂值"，而卡片要有自己的存档键与自己的档位胶囊 ——
  /// 详见 `lib/models/course_glass_tuning.dart` 的类注释。
  final CourseGlassTuning? courseCardGlassTuning;

  /// 课程卡片那一档的**档位**（2026-10-05 加，与 [liquidGlassPreset] 同构）。
  ///
  /// 存档语义与非空枚举字段一致：缺键回 [LiquidGlassPreset.standard]，
  /// 「恢复默认」会把旋钮清空、档名一并拨回标准（见 `settings_reset.dart`）。
  ///
  /// **为什么不靠 [CourseGlassTuning.matchPreset] 反推**：反推认不出"用户点了自定义
  /// 但一个旋钮都没动"这种状态 —— 那种状态下参数恰好等于某一档，反推会把胶囊拨回
  /// 内置档、滑杆当场消失，用户想调也没处调。跟全局那份一样把档名单独存。
  final LiquidGlassPreset courseCardGlassPreset;

  final bool homePageHeaderBlurEnabled;
  final bool homePageWeekdayBarBlurEnabled;

  /// 首页顶栏玻璃带材质（用户 2026-09-12 拍板独立选择）：
  /// `follow`（跟随全局）/ `liquid`（液态）/ `solid`（实体）三档；
  /// 写入口一律过 [sanitizeHomeBandGlassMaterial]，存量的 progressive /
  /// gaussian / soft 在读取时已归到液态。
  ///
  /// `follow` 是 2026-09-23 用户口径「顶栏带改成跟随主材质」的存储值：渲染与
  /// 只读推导一律走 [homeBandGlassMaterialEffective] 的**生效值**（模糊开 → 液态带、
  /// 模糊关 → 实心带），不要直接拿本字段判断分支 —— 那会让「跟随」在渲染层不知所云。
  /// 出厂值仍是 [defaultHomeBandGlassMaterial]（单独指定液态）。
  ///
  /// 子页顶栏永不吃这里的取值（它按 2026-09-23 口径锁死为渐进模糊，见
  /// `HyperosBlurredHeader.subpageHeaderBlurStyleOf`）。
  final String homeBandGlassMaterial;

  /// [homeBandGlassMaterial] 的**生效值**：`follow` 按当前模糊总开关解析成
  /// `solid` / `liquid`，其余取值原样返回。
  ///
  /// 渲染侧（`HomePageChromeGlassFill`）、预热判据、只读材质地图都必须消费
  /// 这里而不是原字段。液态带在引擎没有 shader 后端时自己回落成磨砂带
  /// （`frostBand`），所以生效值只有 `solid` / `liquid` 两种。
  String get homeBandGlassMaterialEffective {
    if (homeBandGlassMaterial != 'follow') {
      return homeBandGlassMaterial;
    }
    return frostedBlurEnabled ? 'liquid' : 'solid';
  }

  final bool homePageTimeColumnBlurEnabled;

  /// 首页背景是否跟着周次翻页一起滑动。
  ///
  /// **默认关**（2026-09-28 用户口径）：背景不动更稳，切周时画面不整片横移；
  /// 想要"背景跟课表一起走"的人自己开。入口有两处、同一颗开关：外观编辑页底部
  /// 「调整壁纸」弹窗，与「设置 → 课表页面 → 页面背景」（见
  /// `_buildBackdropFollowsWeekPagerTile`）。渲染侧判据在 `timetable_screen.dart`
  /// 的 `followsWeekPager`（还要 `hasBackdrop` 才生效）。
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
    this.weatherShowOnDayCard = true,
    this.weatherShowOnWeekCard = true,
    this.weatherShowOnSheet = true,
    this.weatherShowPhenomenon = true,
    this.weatherShowTemperature = true,
    this.weatherShowProbability = false,
    this.courseCardVerticalAlign = CourseCardVerticalAlign.center,
    this.courseCardHorizontalAlign = CourseCardHorizontalAlign.center,
    this.courseCardFontSize = 9,
    this.timetableTimeColumnWidthMode = TimetableTimeColumnWidthMode.narrow,
    this.timetableCourseCardGap = 1.25,
    this.timetableCourseSpacingMode = TimetableCourseSpacingMode.narrow,
    this.widgetBackgroundStyle = WidgetBackgroundStyle.solid,
    this.widgetCourseAccentMode = WidgetCourseAccentMode.barAndText,
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
    this.appFontWeight = 400,
    this.appTextScale = 1.0,
    this.appLocaleTag = '',
    this.homeTitleStyle = HomeTitleStyle.classic,
    this.timetableHomeViewMode = TimetableHomeViewMode.week,
    this.homeNavigationForm = HomeNavigationForm.classic,
    this.homeMenuStyle = HomeMenuStyle.list,
    this.homeGridMenuActions = const <String>[],
    this.glassDockActions = HomeDockMenu.defaultActions,
    this.glassDockShowDayTab = true,
    this.glassDockShowSettingsTab = true,
    this.glassDockShowWeekTab = true,
    this.glassDockButtonEntryId = 'addCourse',
    this.glassDockButtonIconName,
    this.glassDockShowAddButton = false,
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
    this.screenshotSharePromptEnabled = true,
    this.longPressEmptySlotToAddCourseEnabled = false,
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
    this.liveExpandedDetailFields,
    this.liveDuringEndExpandedDetailFields,
    this.liveShowBeforeClassMinutes = 20,
    this.liveClassReminderStartMinutes = 0,
    this.liveEndSecondsCountdownThreshold = 60,
    this.liveTimeCorrectionSeconds = 0,
    this.liveBeforeClassQuickAction = LiveBeforeClassQuickAction.none,
    this.liveBeforeClassQuickActionAutoMinutes = 0,
    this.themeSeedColor = '#3482FF',
    this.foruiTheme = ForuiTheme.miui,
    this.timetablePageBackgroundColor = '#F8FAFC',
    this.homePageBackgroundFill = HomePageBackgroundFill.color,
    this.homePageBackgroundImagePath,
    this.homePageWallpaperPath,
    this.homePageWallpaperAlignX = 0,
    this.homePageWallpaperAlignY = 0,
    this.homePageWallpaperScale = 1,
    this.wallpaperHistory = const [],
    this.homePageBackgroundScope = HomePageBackgroundScope.defaultValue,
    this.timetableUseUnifiedCardColor = false,
    this.timetableUnifiedCardColor = '#2563EB',
    this.appUpdateDownloadSource = 'mirror',
    this.appUpdateDownloadChannel = 'gitcode',
    this.appUpdateUseSystemDownloader = false,
    this.appUpdateMirrorPreset = 'ghfast',
    this.appUpdateIncludePrerelease = false,
    this.appUpdateMirrorUrlPrefix = defaultAppUpdateMirrorUrlPrefix,
    this.appUpdatePromptEnabled = true,
    this.holidayOverrideEnabled = false,
    this.classAlarmLeadMinutes = 30,
    this.classAlarmSkipUi = false,
    this.classReminders = const [],
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
    this.frostedBlurEnabled = defaultFrostedBlurEnabled,
    this.liquidGlassDockEnabled = defaultLiquidGlassDockEnabled,
    this.courseCardSurfaceStyle = CourseCardSurfaceStyle.solid,
    this.liquidGlassPreset = LiquidGlassPreset.standard,
    this.liquidGlassTuning,
    this.liquidGlassTuningDark,
    this.linkLiquidGlassTuning = defaultLinkLiquidGlassTuning,
    this.darkGlassBoostEnabled = defaultDarkGlassBoostEnabled,
    this.courseCardGlassTuning,
    this.courseCardGlassPreset = LiquidGlassPreset.standard,
    this.homePageHeaderBlurEnabled = true,
    this.homePageWeekdayBarBlurEnabled = true,
    this.homeBandGlassMaterial = defaultHomeBandGlassMaterial,
    this.homePageTimeColumnBlurEnabled = false,
    this.homePageBackdropFollowsWeekPager = false,
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
    );
  }

  /// 用**当前真源** [live] 的节次表与激活作息覆盖本对象里的这两项。
  ///
  /// 设置子页普遍把 `provider.settings` 取一份快照当草稿（`late TimetableSettings
  /// _draft`），改完再整份写回。问题是写回期间还有别的写入者在动同一份设置：
  /// 换季日期规则的批量套用会重写所有课表的 `activeTimeSchemeId` 与 `sections`
  /// （timetable_provider 的批量套用路径），首页视图状态写入也走同一条持久化。
  /// 草稿里那两项是"进页面那一刻"的旧值 —— 用户拨一下超级岛开关，就能把刚生效的
  /// 新作息连同整张节次表回滚掉，而界面显示的仍是旧时间，属于最难查的
  /// 「改了又莫名变回去」。
  ///
  /// 这两个字段不属于子页的可编辑内容，所以一律以真源为准；其余字段保留草稿
  /// （那才是用户这次要改的东西）。
  TimetableSettings withLiveScheduleFieldsFrom(TimetableSettings live) =>
      copyWith(
        sections: List<SectionTime>.from(live.sections),
        activeTimeSchemeId: live.activeTimeSchemeId,
      );

  /// 外来传输数据不得改写的**设备级信任锚**，一律保留本机 [local] 的取值。
  ///
  /// `appUpdateMirrorPreset` / `appUpdateMirrorUrlPrefix` 决定「自动更新的清单从
  /// 哪个地址取」以及「APK 允许从哪个主机下载」（isTrustedApkDownloadUrl 直接把
  /// 这个设置值当作可信主机白名单的一项，见 lib/utils/async_utils.dart）。它们却
  /// 夹在 TimetableSettings 里，于是任何携带 settings 的导入路径都能顺手改掉它：
  /// 局域网配对端一次 `POST /api/v1/import/apply`（scope=currentTimetable 属于
  /// carriesSettings）、一份被篡改的云快照、或别人分享的 .mikcb 文件，都能把机主
  /// 的更新通道指向攻击者域名。而清单里的摘要与下载地址又同时出自那个域名，
  /// 「摘要与 URL 同源」的完整性校验就此变成自证 —— 攻击者只需返回一份自洽的响应。
  ///
  /// 这两个键不是课表数据，而是本机的安全输入，因此不接受外来数据设定。
  TimetableSettings keepingDeviceTrustAnchorsFrom(TimetableSettings local) {
    if (appUpdateMirrorPreset == local.appUpdateMirrorPreset &&
        appUpdateMirrorUrlPrefix == local.appUpdateMirrorUrlPrefix) {
      return this;
    }
    return copyWith(
      appUpdateMirrorPreset: local.appUpdateMirrorPreset,
      appUpdateMirrorUrlPrefix: local.appUpdateMirrorUrlPrefix,
    );
  }

  /// 开学日的文本（`yyyy-MM-dd`）形态；见 [parseSemesterStartDate] 为什么需要它。
  static String? formatSemesterStartDateText(DateTime? date) {
    if (date == null) {
      return null;
    }
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// 读回开学日：**文本键优先**，毫秒只作为旧存档的回落。
  ///
  /// `semesterStartDate` 历史上只存 `millisecondsSinceEpoch`，那是个瞬时，隐含了
  /// 写入方的时区：在 Asia/Shanghai 设的 2026-09-07 存成 2026-09-06T16:00Z，云同步
  /// 到 UTC-5 的设备后 `DateTime.fromMillisecondsSinceEpoch` 还原成 09-06 11:00，
  /// 于是 `WeekCalculator.startOfWeek` 得到 08-31，整个学期的周次 +1、单双周翻转
  /// —— 用户看到「课表整体差一周」，而设置页显示的日期看起来是对的。
  ///
  /// 毫秒回落分支把结果归一到**本地零点**：读取方只用日期（周次、倒计时、统计都
  /// 只取 y/m/d），留着时分会让比较 `semesterStartDate` 是否变化时产生假阳性。
  /// 文本键存在但畸形时一律返回 null 而不回落到毫秒：两份键出自同一次写入，文本
  /// 坏了说明这份存档本身不可信，宁可让用户重设开学时间，也不要悄悄用一周错误的
  /// 课表。
  static DateTime? parseSemesterStartDate(Object? text, Object? millis) {
    if (text is String) {
      final trimmed = text.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      final match = RegExp(
        r'^(\d{4})-(\d{1,2})-(\d{1,2})$',
      ).firstMatch(trimmed);
      if (match == null) {
        return null;
      }
      final year = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final day = int.parse(match.group(3)!);
      if (month < 1 || month > 12 || day < 1 || day > 31) {
        return null;
      }
      final built = DateTime(year, month, day);
      // `DateTime(2026, 4, 31)` 不报错，它**顺延**成 5 月 1 日 —— 而开学日挪几天
      // 就会让 startOfWeek 落到别的星期：整学期周次 +1/−1、单双周翻转，设置页上
      // 还显示着用户认得的那个日期。判"这天真的存在"要靠 round-trip
      // （同 warehouse_course_import_logic.dart:44-56 的口径与本函数注释的承诺）。
      if (built.year != year || built.month != month || built.day != day) {
        return null;
      }
      return built;
    }
    if (millis is num) {
      final restored = DateTime.fromMillisecondsSinceEpoch(millis.toInt());
      return DateTime(restored.year, restored.month, restored.day);
    }
    return null;
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
      // 开学日是一个**日历日期**，不是时刻。毫秒瞬时隐含写入方的时区，换到别的
      // 时区恢复就会挪天：Asia/Shanghai 的 2026-09-07 00:00 存成 2026-09-06T16:00Z，
      // 在 UTC-5 的设备上还原成 09-06 11:00 → 那一周的周一变成 08-31 → 整个学期的
      // 周次 +1、单双周整体翻转（情侣同步、跨设备云同步、备份还原都会踩到）。
      // 文本键优先读，毫秒键继续写给旧版本与旧存档。
      'semesterStartDateText': formatSemesterStartDateText(semesterStartDate),
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
      'weatherShowOnDayCard': weatherShowOnDayCard,
      'weatherShowOnWeekCard': weatherShowOnWeekCard,
      'weatherShowOnSheet': weatherShowOnSheet,
      'weatherShowPhenomenon': weatherShowPhenomenon,
      'weatherShowTemperature': weatherShowTemperature,
      'weatherShowProbability': weatherShowProbability,
      'courseCardVerticalAlign': courseCardVerticalAlign.value,
      'courseCardHorizontalAlign': courseCardHorizontalAlign.value,
      'courseCardFontSize': courseCardFontSize,
      'timetableTimeColumnWidthMode': timetableTimeColumnWidthMode.value,
      'timetableCourseCardGap': timetableCourseCardGap,
      'timetableCourseSpacingMode': timetableCourseSpacingMode.value,
      'widgetBackgroundStyle': widgetBackgroundStyle.value,
      'widgetCourseAccentMode': widgetCourseAccentMode.value,
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
      'appFontWeight': appFontWeight,
      'appTextScale': appTextScale,
      'appLocaleTag': appLocaleTag,
      'homeTitleStyle': homeTitleStyle.value,
      'timetableHomeViewMode': timetableHomeViewMode.value,
      'homeNavigationForm': homeNavigationForm.value,
      'homeMenuStyle': homeMenuStyle.value,
      'homeGridMenuActions': homeGridMenuActions,
      'glassDockActions': glassDockActions,
      'glassDockShowDayTab': glassDockShowDayTab,
      'glassDockShowSettingsTab': glassDockShowSettingsTab,
      'glassDockShowWeekTab': glassDockShowWeekTab,
      'glassDockButtonEntryId': glassDockButtonEntryId,
      'glassDockButtonIconName': glassDockButtonIconName,
      'glassDockShowAddButton': glassDockShowAddButton,
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
      'screenshotSharePromptEnabled': screenshotSharePromptEnabled,
      'longPressEmptySlotToAddCourseEnabled':
          longPressEmptySlotToAddCourseEnabled,
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
      'liveExpandedDetailFields': liveExpandedDetailFields,
      'liveDuringEndExpandedDetailFields': liveDuringEndExpandedDetailFields,
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
      'liveBeforeClassQuickActionAutoMinutes':
          liveBeforeClassQuickActionAutoMinutes,
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
      'homePageWallpaperScale': homePageWallpaperScale,
      'wallpaperHistory': [
        for (final entry in wallpaperHistory) entry.toJson(),
      ],
      // homePageBackgroundScope 已下线（壁纸整体透出），不再写入。
      'timetableUseUnifiedCardColor': timetableUseUnifiedCardColor,
      'timetableUnifiedCardColor': timetableUnifiedCardColor,
      'appUpdateDownloadSource': appUpdateDownloadSource,
      'appUpdateDownloadChannel': appUpdateDownloadChannel,
      'appUpdateUseSystemDownloader': appUpdateUseSystemDownloader,
      'appUpdateMirrorPreset': appUpdateMirrorPreset,
      'appUpdateIncludePrerelease': appUpdateIncludePrerelease,
      'appUpdateMirrorUrlPrefix': appUpdateMirrorUrlPrefix,
      'appUpdatePromptEnabled': appUpdatePromptEnabled,
      'holidayOverrideEnabled': holidayOverrideEnabled,
      'classAlarmLeadMinutes': classAlarmLeadMinutes,
      'classAlarmSkipUi': classAlarmSkipUi,
      'classReminders': [for (final entry in classReminders) entry.toJson()],
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
      'frostedBlurEnabled': frostedBlurEnabled,
      'liquidGlassDockEnabled': liquidGlassDockEnabled,
      'courseCardSurfaceStyle': courseCardSurfaceStyle.value,
      'liquidGlassPreset': liquidGlassPreset.value,
      if (liquidGlassTuning != null)
        'liquidGlassTuning': liquidGlassTuning!.toJson(),
      if (liquidGlassTuningDark != null)
        'liquidGlassTuningDark': liquidGlassTuningDark!.toJson(),
      'linkLiquidGlassTuning': linkLiquidGlassTuning,
      'darkGlassBoostEnabled': darkGlassBoostEnabled,
      if (courseCardGlassTuning != null)
        'courseCardGlassTuning': courseCardGlassTuning!.toJson(),
      'courseCardGlassPreset': courseCardGlassPreset.value,
      'homePageHeaderBlurEnabled': homePageHeaderBlurEnabled,
      'homePageWeekdayBarBlurEnabled': homePageWeekdayBarBlurEnabled,
      'homeBandGlassMaterial': homeBandGlassMaterial,
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
    // 联动开时详情字色回填为标题字色，规则与 copyWith 的联动回填一致：
    // 旧版本数据 / 主题备份可能残留「联动开、详情色不同」的脏状态（白标题
    // +黑简介混色卡的根源）；独立模式（联动关）保留用户显式选择。
    //
    // ⚠️ 这里曾有一段「旧轴 → homeBandGlassMaterial」的迁移（2026-09-12 写，
    // 输入是 `homeChromeGlassMaterial` / `liquidGlassHomeChromeEnabled` /
    // `frostedGlassMode`）。它的三个分支在 2026-09-30 高斯模糊退场后**全部收敛到
    // 同一个值** `liquid` —— 而 `liquid` 恰好就是 [sanitizeHomeBandGlassMaterial]
    // 对一切非法值的默认归宿，所以整段连同那两个只被它读过的旧键一起删除。
    // 那两个旧键现在按未知键忽略（与 `headerBlurStyle` / `subpageHeaderBlurStyle`
    // 同一条规矩）。
    final linkedCardTextColors = json['linkCourseCardColors'] as bool? ?? true;
    final parsedTitleColorLight =
        json['courseCardTitleColorLight'] as String? ??
        defaultCourseCardTitleColor;
    final parsedTitleColorDark =
        json['courseCardTitleColorDark'] as String? ??
        defaultCourseCardTitleColor;
    final parsedDetailColorLight = linkedCardTextColors
        ? parsedTitleColorLight
        : json['courseCardDetailColorLight'] as String? ??
              defaultCourseCardDetailColor;
    final parsedDetailColorDark = linkedCardTextColors
        ? parsedTitleColorDark
        : json['courseCardDetailColorDark'] as String? ??
              defaultCourseCardDetailColor;
    final rawSections = json['sections'] is List
        ? json['sections'] as List<dynamic>
        : const <dynamic>[];
    // Empty sections fall back to defaults only for the section list; other
    // fields must still parse so a corrupt sections array does not wipe theme /
    // semester / live settings. Malformed entries are position-preserved (see
    // SectionTime.parseListAligned) — skipping them would shift every later
    // section against the positional Course.startSection.
    List<SectionTime> resolvedSections;
    if (rawSections.isEmpty) {
      resolvedSections = TimetableSettings.defaults().sections;
    } else {
      final parsed = SectionTime.parseListAligned(
        rawSections,
        fallbackTemplate: () => TimetableSettings.defaults().sections,
      );
      // 整表一条都没解析出来时没有位置信息可对齐，只能整套回落内置模板
      // （保持既有行为）；部分坏才按位补，避免后面的节次整体前移。
      resolvedSections = parsed.healedCount == parsed.sections.length
          ? TimetableSettings.defaults().sections
          : parsed.sections;
    }

    /// 嵌套对象解析失败只丢这一个字段，不牵连同一条记录里的其它设置。
    ///
    /// 此前这三处是 `json[key] as Map<String, dynamic>` 硬转且外层没有 try：一个
    /// 类型不对的嵌套值会抛出并冒到 `TimetableProfile.fromJsonLenient` 的 catch，
    /// 把**整份**设置换成 defaults —— 学期起始日、节次表、主题、超级岛开关一起被
    /// 清零，再经 provider 的 `AppGlobalSettingsService.syncFrom` 当作「用户刚改了
    /// 全局设置」写进设备级全局键，波及本机所有课表。同文件里 savedThemes 与
    /// themeCheckpointConfig 都有逐条 try，只有这三处口径不一致。
    T? parseNestedObject<T>(
      Object? raw,
      T Function(Map<String, dynamic> map) parse,
    ) {
      if (raw is! Map) {
        return null;
      }
      try {
        return parse(Map<String, dynamic>.from(raw));
      } catch (_) {
        return null;
      }
    }

    final rawAppUpdateMirrorUrlPrefix =
        json['appUpdateMirrorUrlPrefix'] as String? ??
        defaultAppUpdateMirrorUrlPrefix;
    final rawAppUpdateMirrorPreset = json['appUpdateMirrorPreset'] as String?;

    // 档位与参数分别在两个字段里存，读取时必须收敛成一致（2026-10-07）。
    // 渲染只吃参数键（`liquid_glass_surface.dart` / `frosted_appearance.dart` 都只读
    // `liquidGlassTuning`），所以参数侧是真源；档位键只用于设置页那根滑杆显示。
    // 两种「对不上」都真实存在，判据与理由见
    // [LiquidGlassPresetX.reconcileStoredPreset]：
    //   · 档位键 2026-10-05 才加，之前的存档只有参数键（用户拖过旋钮）；
    //   · 扩格时 clear / light / dense 三档的推荐参数被改过，老存档里档位键写着
    //     某一档、参数键存着**那一档的老推荐值**。
    // 两种情况下裸 fromValue 都会让滑杆显示的格号与旋钮读数对不上 —— 面板在说谎。
    final parsedLiquidGlassTuning = parseNestedObject(
      json['liquidGlassTuning'],
      LiquidGlassTuning.fromJson,
    );
    final parsedCourseCardGlassTuning = parseNestedObject(
      json['courseCardGlassTuning'],
      CourseGlassTuning.fromJson,
    );

    return TimetableSettings(
      sections: resolvedSections,
      activeTimeSchemeId: json['activeTimeSchemeId'] as String?,
      sectionHeight: (json['sectionHeight'] as num?)?.toDouble() ?? 68,
      compactFontSize: (json['compactFontSize'] as num?)?.toDouble() ?? 9,
      timetableAutoFitSectionHeight:
          json['timetableAutoFitSectionHeight'] as bool? ?? false,
      semesterWeekCount: _atLeastOneWeek(
        (json['semesterWeekCount'] as num?)?.toInt() ?? 20,
      ),
      semesterStartDate: parseSemesterStartDate(
        json['semesterStartDateText'],
        json['semesterStartDate'],
      ),
      weeklyReportEnabled: json['weeklyReportEnabled'] as bool? ?? false,
      enableHolidayMarking: json['enableHolidayMarking'] as bool? ?? true,
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
      weatherShowOnDayCard: json['weatherShowOnDayCard'] as bool? ?? true,
      weatherShowOnWeekCard: json['weatherShowOnWeekCard'] as bool? ?? true,
      weatherShowOnSheet: json['weatherShowOnSheet'] as bool? ?? true,
      weatherShowPhenomenon: json['weatherShowPhenomenon'] as bool? ?? true,
      weatherShowTemperature: json['weatherShowTemperature'] as bool? ?? true,
      weatherShowProbability: json['weatherShowProbability'] as bool? ?? false,
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
      widgetCourseAccentMode: WidgetCourseAccentModeX.fromValue(
        json['widgetCourseAccentMode'] as String?,
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
      appFontWeight: normalizeAppFontWeight(json['appFontWeight'] as num?),
      appTextScale: normalizeAppTextScale(json['appTextScale'] as num?),
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
      // 旧键 `glassDockStyle` 已废弃：底栏材质现在跟随全局
      // 材质 + 「作用范围 → 玻璃坞导航」，读取时直接忽略。
      homeMenuStyle: HomeMenuStyleX.fromValue(json['homeMenuStyle'] as String?),
      glassDockActions: HomeDockMenu.normalize(
        (json['glassDockActions'] as List<Object?>?) ??
            [
              // 迁移：旧档无此键时由日/周 Tab 开关推导（旧默认均 true）。
              if (json['glassDockShowDayTab'] as bool? ?? true) 'day',
              if (json['glassDockShowWeekTab'] as bool? ?? true) 'week',
            ],
      ),
      homeGridMenuActions: HomeGridMenu.normalize(
        json['homeGridMenuActions'] as List<Object?>?,
      ),

      glassDockShowDayTab: json['glassDockShowDayTab'] as bool? ?? true,
      glassDockShowSettingsTab:
          json['glassDockShowSettingsTab'] as bool? ?? true,
      glassDockShowWeekTab: json['glassDockShowWeekTab'] as bool? ?? true,
      glassDockButtonEntryId:
          json['glassDockButtonEntryId'] as String? ?? 'addCourse',
      glassDockButtonIconName: json['glassDockButtonIconName'] as String?,
      glassDockShowAddButton: json['glassDockShowAddButton'] as bool? ?? false,
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
      screenshotSharePromptEnabled:
          json['screenshotSharePromptEnabled'] as bool? ?? true,
      longPressEmptySlotToAddCourseEnabled:
          json['longPressEmptySlotToAddCourseEnabled'] as bool? ?? false,
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
      liveExpandedDetailFields: _safeStringList(
        json['liveExpandedDetailFields'],
      ),
      liveDuringEndExpandedDetailFields:
          _safeStringList(json['liveDuringEndExpandedDetailFields']) ??
          _safeStringList(json['liveExpandedDetailFields']),
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
      liveBeforeClassQuickActionAutoMinutes:
          (json['liveBeforeClassQuickActionAutoMinutes'] as num?)?.toInt() ?? 0,
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
      // 存量存档没有这个字段：缺省 1（刚好铺满），观感与加缩放之前一致。
      homePageWallpaperScale:
          (json['homePageWallpaperScale'] as num?)?.toDouble() ?? 1,
      wallpaperHistory: WallpaperHistoryEntry.listFromJson(
        json['wallpaperHistory'],
      ),
      // 「壁纸透出范围」「顶栏玻璃」开关已下线（2026-09-12）：三个字段固
      // 化为默认值（壁纸整体透出、玻璃带常开），不再读取旧存档里的用户值
      // ——那三个 UI 入口已删，保留旧值只会变成不可修改的隐藏状态。
      // ignore: avoid_redundant_argument_values -- 故意写死默认值（下线旧开关）。
      homePageBackgroundScope: HomePageBackgroundScope.defaultValue,
      timetableUseUnifiedCardColor:
          json['timetableUseUnifiedCardColor'] as bool? ?? false,
      timetableUnifiedCardColor:
          json['timetableUnifiedCardColor'] as String? ?? '#2563EB',
      appUpdateDownloadSource:
          json['appUpdateDownloadSource'] as String? ?? 'mirror',
      appUpdateDownloadChannel:
          json['appUpdateDownloadChannel'] as String? ?? 'gitcode',
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
      appUpdatePromptEnabled: json['appUpdatePromptEnabled'] as bool? ?? true,
      holidayOverrideEnabled: json['holidayOverrideEnabled'] as bool? ?? false,
      classAlarmLeadMinutes:
          (json['classAlarmLeadMinutes'] as num?)?.toInt() ?? 30,
      classAlarmSkipUi: json['classAlarmSkipUi'] as bool? ?? false,
      // 脏条目在 listFromJson 内逐条校验丢弃，绝不让单个坏值炸掉整个设置。
      classReminders: ClassReminderEntry.listFromJson(json['classReminders']),
      courseCardTitleColorLight: parsedTitleColorLight,
      courseCardTitleColorDark: parsedTitleColorDark,
      courseCardDetailColorLight: parsedDetailColorLight,
      courseCardDetailColorDark: parsedDetailColorDark,
      linkCourseCardColors: linkedCardTextColors,
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
      frostedBlurEnabled:
          json['frostedBlurEnabled'] as bool? ?? defaultFrostedBlurEnabled,
      liquidGlassDockEnabled:
          json['liquidGlassDockEnabled'] as bool? ??
          defaultLiquidGlassDockEnabled,
      courseCardSurfaceStyle: CourseCardSurfaceStyleX.fromValue(
        // 非字符串坏值按缺键处理（走 null → 出厂档），不抛：坏一个键不该把整份设置
        // 拉回默认值（学期起始日、节次表、主题一起清零）。同族的
        // `liquidGlassPreset` / `courseCardGlassPreset` 2026-10-07 已补，这一处当时漏了。
        json['courseCardSurfaceStyle'] is String
            ? json['courseCardSurfaceStyle'] as String
            : null,
      ),
      liquidGlassPreset: LiquidGlassPresetX.reconcileStoredPreset(
        // 非字符串坏值按缺键处理（rawStored 走 null 分支），不抛，否则坏一键
        // 触发整份设置回退（同 d0d2cb1b 为卡片那份补的口径）。
        rawStored: json['liquidGlassPreset'] is String
            ? json['liquidGlassPreset'] as String
            : null,
        stored: LiquidGlassPresetX.fromValue(
          json['liquidGlassPreset'] is String
              ? json['liquidGlassPreset'] as String
              : null,
        ),
        tuning: parsedLiquidGlassTuning,
      ),
      liquidGlassTuning: parsedLiquidGlassTuning,
      liquidGlassTuningDark: parseNestedObject(
        json['liquidGlassTuningDark'],
        LiquidGlassTuning.fromJson,
      ),
      linkLiquidGlassTuning:
          json['linkLiquidGlassTuning'] as bool? ??
          defaultLinkLiquidGlassTuning,
      darkGlassBoostEnabled:
          json['darkGlassBoostEnabled'] as bool? ??
          defaultDarkGlassBoostEnabled,
      courseCardGlassTuning: parsedCourseCardGlassTuning,
      courseCardGlassPreset: LiquidGlassPresetX.reconcileStoredPreset(
        // 非字符串坏值按缺键处理（rawStored 走 null 分支），不抛，否则坏一键
        // 触发整份回退。审计算出来的同族缺口，见 b0f3589f 的 parseNestedObject 口径。
        rawStored: json['courseCardGlassPreset'] is String
            ? json['courseCardGlassPreset'] as String
            : null,
        stored: LiquidGlassPresetX.fromValue(
          json['courseCardGlassPreset'] is String
              ? json['courseCardGlassPreset'] as String
              : null,
        ),
        // 卡片那 10 格与全局同值（`CourseGlassTuning` 的 presetLevelN 全部由
        // `fromLiquidGlassTuning` 派生），所以直接把参数转成全局那份再走同一个
        // 收敛，不必在 `CourseGlassTuning` 上重写一遍。
        tuning: parsedCourseCardGlassTuning?.toLiquidGlassTuning(),
      ),
      // 两个玻璃带显示开关已下线（顶栏玻璃归外观页材质五档），恒为开。
      // ignore: avoid_redundant_argument_values -- 故意写死默认值（下线旧开关）。
      homePageHeaderBlurEnabled: true,
      // ignore: avoid_redundant_argument_values -- 故意写死默认值（下线旧开关）。
      homePageWeekdayBarBlurEnabled: true,
      // 首页顶栏材质：独立自由选择（2026-09-12）。缺新键 = 从没单独指定过，
      // 按出厂值液态（2026-09-30 高斯模糊退场后，「旧轴迁移」与默认值同值，
      // 那段迁移已删，见本方法开头）。2026-09-20 起口径只有
      //「液态 / 实体」两档：存量 progressive / gaussian / soft 与一切非法值
      // 都在 sanitize 里归到液态，与界面那两个选项同口径。
      homeBandGlassMaterial: sanitizeHomeBandGlassMaterial(
        // 非字符串坏值按缺键处理（走 null → 出厂档），不抛。同族三个键
        // （liquidGlassPreset / courseCardGlassPreset / courseCardSurfaceStyle）
        // 已于 2026-10-07~08 补齐，这一处当时漏了 —— 而它比那三个更要紧：
        // 它在**全局设置**键表里（`app_global_settings_service.dart`），
        // 坏一个档位会让整机所有课表的顶栏材质一起回落出厂。
        json['homeBandGlassMaterial'] is String
            ? json['homeBandGlassMaterial'] as String
            : null,
      ),
      homePageTimeColumnBlurEnabled:
          json['homePageTimeColumnBlurEnabled'] as bool? ?? false,
      // ⚠️ 缺键按**默认关**处理（不是默认开）：缺键只可能来自 2026-07-06 引入这个
      // 字段之前存下的老存档，等价于"从没主动选过"，应落在新默认上。`toJson` 一直
      // 写这个键，所以此后存过档的用户（无论开或关）都读自己存的值，不受影响。
      homePageBackdropFollowsWeekPager:
          json['homePageBackdropFollowsWeekPager'] as bool? ?? false,
      savedThemes: (() {
        final raw = json['savedThemes'];
        if (raw is! List) return const <SavedTheme>[];
        final out = <SavedTheme>[];
        for (final t in raw) {
          try {
            if (t is! Map) continue;
            out.add(SavedTheme.fromJson(Map<String, dynamic>.from(t)));
          } catch (_) {
            continue;
          }
        }
        return out;
      })(),
      themeCheckpointName: json['themeCheckpointName'] as String?,
      themeCheckpointConfig: (() {
        final r = json['themeCheckpointConfig'];
        if (r is! Map) return null;
        try {
          return ThemeConfig.fromJson(Map<String, dynamic>.from(r));
        } catch (_) {
          return null;
        }
      })(),
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
    bool? weatherShowOnDayCard,
    bool? weatherShowOnWeekCard,
    bool? weatherShowOnSheet,
    bool? weatherShowPhenomenon,
    bool? weatherShowTemperature,
    bool? weatherShowProbability,
    CourseCardVerticalAlign? courseCardVerticalAlign,
    CourseCardHorizontalAlign? courseCardHorizontalAlign,
    double? courseCardFontSize,
    TimetableTimeColumnWidthMode? timetableTimeColumnWidthMode,
    double? timetableCourseCardGap,
    TimetableCourseSpacingMode? timetableCourseSpacingMode,
    WidgetBackgroundStyle? widgetBackgroundStyle,
    WidgetCourseAccentMode? widgetCourseAccentMode,
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
    int? appFontWeight,
    double? appTextScale,
    String? appLocaleTag,
    HomeTitleStyle? homeTitleStyle,
    TimetableHomeViewMode? timetableHomeViewMode,
    HomeNavigationForm? homeNavigationForm,
    HomeMenuStyle? homeMenuStyle,
    List<String>? homeGridMenuActions,
    List<String>? glassDockActions,
    bool? glassDockShowDayTab,
    bool? glassDockShowSettingsTab,
    bool? glassDockShowWeekTab,
    String? glassDockButtonEntryId,
    String? glassDockButtonIconName,
    bool clearGlassDockButtonIconName = false,
    bool? glassDockShowAddButton,
    BackToCurrentWeekButtonStyle? timetableBackToCurrentWeekButtonStyle,
    double? timetableFloatingBackToCurrentWeekButtonOpacity,
    int? timetableLastViewedDayOfWeek,
    bool? coupleTimetableOverlayEnabled,
    SectionTimeDisplayMode? timetableSectionTimeDisplayMode,
    bool? timetableHideWeekends,
    bool? enableHaptics,
    double? pageTransitionSpeed,
    bool? homePullQuickImportEnabled,
    bool? screenshotSharePromptEnabled,
    bool? longPressEmptySlotToAddCourseEnabled,
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
    List<String>? liveExpandedDetailFields,
    bool clearLiveExpandedDetailFields = false,
    List<String>? liveDuringEndExpandedDetailFields,
    bool clearLiveDuringEndExpandedDetailFields = false,
    int? liveShowBeforeClassMinutes,
    int? liveClassReminderStartMinutes,
    int? liveEndSecondsCountdownThreshold,
    int? liveTimeCorrectionSeconds,
    LiveBeforeClassQuickAction? liveBeforeClassQuickAction,
    int? liveBeforeClassQuickActionAutoMinutes,
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
    double? homePageWallpaperScale,
    List<WallpaperHistoryEntry>? wallpaperHistory,
    bool clearWallpaperHistory = false,
    int? homePageBackgroundScope,
    bool? timetableUseUnifiedCardColor,
    String? timetableUnifiedCardColor,
    String? appUpdateDownloadSource,
    String? appUpdateDownloadChannel,
    bool? appUpdateUseSystemDownloader,
    String? appUpdateMirrorPreset,
    bool? appUpdateIncludePrerelease,
    String? appUpdateMirrorUrlPrefix,
    bool? appUpdatePromptEnabled,
    bool? holidayOverrideEnabled,
    int? classAlarmLeadMinutes,
    bool? classAlarmSkipUi,
    List<ClassReminderEntry>? classReminders,
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
    bool? frostedBlurEnabled,
    bool? liquidGlassDockEnabled,
    CourseCardSurfaceStyle? courseCardSurfaceStyle,
    LiquidGlassPreset? liquidGlassPreset,
    LiquidGlassTuning? liquidGlassTuning,
    bool clearLiquidGlassTuning = false,
    LiquidGlassTuning? liquidGlassTuningDark,
    bool clearLiquidGlassTuningDark = false,
    bool? linkLiquidGlassTuning,
    bool? darkGlassBoostEnabled,
    CourseGlassTuning? courseCardGlassTuning,
    bool clearCourseCardGlassTuning = false,
    LiquidGlassPreset? courseCardGlassPreset,
    bool? homePageHeaderBlurEnabled,
    bool? homePageWeekdayBarBlurEnabled,
    String? homeBandGlassMaterial,
    bool? homePageTimeColumnBlurEnabled,
    bool? homePageBackdropFollowsWeekPager,
    List<SavedTheme>? savedThemes,
    String? themeCheckpointName,
    ThemeConfig? themeCheckpointConfig,
    bool clearThemeCheckpoint = false,
  }) {
    // 联动开时详情字色必须与标题字色一致：设置页在联动下本就同步写入，
    // 但旧版本数据 / 主题备份可能残留「联动开、详情色不同」的脏状态，渲染
    // 端会据此画出白标题+黑简介的混色卡。copyWith 是设置的统一写入口，在
    // 此顺手回填；独立模式（联动关）是用户显式选择，保留原值，由卡面渲染
    // 端做同极性兜底。fromJson 直达构造函数，另有同等规则的回填。
    final linkedCardTextColors =
        linkCourseCardColors ?? this.linkCourseCardColors;
    final healedDetailColorLight = linkedCardTextColors
        ? (courseCardTitleColorLight ?? this.courseCardTitleColorLight)
        : (courseCardDetailColorLight ?? this.courseCardDetailColorLight);
    final healedDetailColorDark = linkedCardTextColors
        ? (courseCardTitleColorDark ?? this.courseCardTitleColorDark)
        : (courseCardDetailColorDark ?? this.courseCardDetailColorDark);
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
      weatherShowOnDayCard: weatherShowOnDayCard ?? this.weatherShowOnDayCard,
      weatherShowOnWeekCard:
          weatherShowOnWeekCard ?? this.weatherShowOnWeekCard,
      weatherShowOnSheet: weatherShowOnSheet ?? this.weatherShowOnSheet,
      weatherShowPhenomenon:
          weatherShowPhenomenon ?? this.weatherShowPhenomenon,
      weatherShowTemperature:
          weatherShowTemperature ?? this.weatherShowTemperature,
      weatherShowProbability:
          weatherShowProbability ?? this.weatherShowProbability,
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
      widgetCourseAccentMode:
          widgetCourseAccentMode ?? this.widgetCourseAccentMode,
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
      appFontWeight: appFontWeight ?? this.appFontWeight,
      appTextScale: appTextScale ?? this.appTextScale,
      appLocaleTag: _normalizeAppLocaleTag(appLocaleTag ?? this.appLocaleTag),
      homeTitleStyle: homeTitleStyle ?? this.homeTitleStyle,
      timetableHomeViewMode:
          timetableHomeViewMode ?? this.timetableHomeViewMode,
      homeNavigationForm: homeNavigationForm ?? this.homeNavigationForm,
      homeMenuStyle: homeMenuStyle ?? this.homeMenuStyle,
      // 写入也过一遍归一：钉住项不因调用方疏漏而丢失（解析路径同）。
      homeGridMenuActions: homeGridMenuActions == null
          ? this.homeGridMenuActions
          : HomeGridMenu.normalize(homeGridMenuActions),
      glassDockActions: glassDockActions == null
          ? this.glassDockActions
          : HomeDockMenu.normalize(glassDockActions),
      glassDockShowDayTab: glassDockShowDayTab ?? this.glassDockShowDayTab,
      glassDockShowSettingsTab:
          glassDockShowSettingsTab ?? this.glassDockShowSettingsTab,
      glassDockShowWeekTab: glassDockShowWeekTab ?? this.glassDockShowWeekTab,
      glassDockButtonEntryId:
          glassDockButtonEntryId ?? this.glassDockButtonEntryId,
      glassDockButtonIconName: clearGlassDockButtonIconName
          ? null
          : glassDockButtonIconName ?? this.glassDockButtonIconName,
      glassDockShowAddButton:
          glassDockShowAddButton ?? this.glassDockShowAddButton,
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
      screenshotSharePromptEnabled:
          screenshotSharePromptEnabled ?? this.screenshotSharePromptEnabled,
      longPressEmptySlotToAddCourseEnabled:
          longPressEmptySlotToAddCourseEnabled ??
          this.longPressEmptySlotToAddCourseEnabled,
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
      liveExpandedDetailFields: clearLiveExpandedDetailFields
          ? null
          : liveExpandedDetailFields ?? this.liveExpandedDetailFields,
      liveDuringEndExpandedDetailFields: clearLiveDuringEndExpandedDetailFields
          ? null
          : liveDuringEndExpandedDetailFields ??
                this.liveDuringEndExpandedDetailFields,
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
      liveBeforeClassQuickActionAutoMinutes:
          liveBeforeClassQuickActionAutoMinutes ??
          this.liveBeforeClassQuickActionAutoMinutes,
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
      homePageWallpaperScale:
          homePageWallpaperScale ?? this.homePageWallpaperScale,
      wallpaperHistory: clearWallpaperHistory
          ? const []
          : wallpaperHistory ?? this.wallpaperHistory,
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
      appUpdatePromptEnabled:
          appUpdatePromptEnabled ?? this.appUpdatePromptEnabled,
      holidayOverrideEnabled:
          holidayOverrideEnabled ?? this.holidayOverrideEnabled,
      // 提前量允许 0（下课即提醒的场景不存在，但保留合法输入区间）。
      classAlarmLeadMinutes:
          classAlarmLeadMinutes ?? this.classAlarmLeadMinutes,
      classAlarmSkipUi: classAlarmSkipUi ?? this.classAlarmSkipUi,
      classReminders: classReminders ?? this.classReminders,
      courseCardTitleColorLight:
          courseCardTitleColorLight ?? this.courseCardTitleColorLight,
      courseCardTitleColorDark:
          courseCardTitleColorDark ?? this.courseCardTitleColorDark,
      courseCardDetailColorLight: healedDetailColorLight,
      courseCardDetailColorDark: healedDetailColorDark,
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
      frostedBlurEnabled: frostedBlurEnabled ?? this.frostedBlurEnabled,
      liquidGlassDockEnabled:
          liquidGlassDockEnabled ?? this.liquidGlassDockEnabled,
      courseCardSurfaceStyle:
          courseCardSurfaceStyle ?? this.courseCardSurfaceStyle,
      liquidGlassPreset: liquidGlassPreset ?? this.liquidGlassPreset,
      liquidGlassTuning: clearLiquidGlassTuning
          ? null
          : liquidGlassTuning ?? this.liquidGlassTuning,
      liquidGlassTuningDark: clearLiquidGlassTuningDark
          ? null
          : liquidGlassTuningDark ?? this.liquidGlassTuningDark,
      linkLiquidGlassTuning:
          linkLiquidGlassTuning ?? this.linkLiquidGlassTuning,
      darkGlassBoostEnabled:
          darkGlassBoostEnabled ?? this.darkGlassBoostEnabled,
      courseCardGlassTuning: clearCourseCardGlassTuning
          ? null
          : courseCardGlassTuning ?? this.courseCardGlassTuning,
      courseCardGlassPreset:
          courseCardGlassPreset ?? this.courseCardGlassPreset,
      homePageHeaderBlurEnabled:
          homePageHeaderBlurEnabled ?? this.homePageHeaderBlurEnabled,
      homePageWeekdayBarBlurEnabled:
          homePageWeekdayBarBlurEnabled ?? this.homePageWeekdayBarBlurEnabled,
      homeBandGlassMaterial:
          homeBandGlassMaterial ?? this.homeBandGlassMaterial,
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
    expandedDetailFields: parseLiveExpandedDetailFields(
      liveExpandedDetailFields,
    ),
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
          expandedDetailFields: parseLiveExpandedDetailFields(
            liveDuringEndExpandedDetailFields ?? liveExpandedDetailFields,
          ),
        );

  TimetableSettings copyWithBeforeClassDisplaySettings(
    LiveDisplaySettings settings, {
    bool clearExpandedIconPath = false,
    bool clearLabelLogoPath = false,
    bool clearExpandedDetailFields = false,
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
      clearLiveExpandedDetailFields: clearExpandedDetailFields,
      liveExpandedDetailFields: encodeLiveExpandedDetailFields(
        settings.expandedDetailFields,
      ),
    );
  }

  TimetableSettings copyWithDuringEndDisplaySettings(
    LiveDisplaySettings settings, {
    bool clearExpandedIconPath = false,
    bool clearLabelLogoPath = false,
    bool clearExpandedDetailFields = false,
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
      clearLiveDuringEndExpandedDetailFields: clearExpandedDetailFields,
      liveDuringEndExpandedDetailFields: encodeLiveExpandedDetailFields(
        settings.expandedDetailFields,
      ),
    );
  }

  /// 学期周数至少 1 周。`timetable_profile.dart:24-27` 与
  /// `lan_edit_provider_host.dart:475` 早已守过这条不变式（说明存量数据里确实会出现
  /// 0/负数：老版本、手改备份、跨端同步），但 `fromJson` 与本 getter 是漏的两处 ——
  /// 空表会让 `availableWeeks.first` 抛 StateError（add_course_screen.dart:1584、:1762，
  /// timetable_screen.dart:7355），表现为**添加课程页整页打不开**。
  static int _atLeastOneWeek(int weekCount) => weekCount < 1 ? 1 : weekCount;

  List<int> get availableWeeks =>
      List.generate(_atLeastOneWeek(semesterWeekCount), (index) => index + 1);

  SectionTime sectionAt(int section) => sections[section - 1];
}
