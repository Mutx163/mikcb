import 'dart:convert';

enum AppUpdateDownloadSource {
  original,
  mirror,
}

enum WidgetBackgroundStyle {
  solid,
  gradient,
}

enum SectionTimeDisplayMode {
  hidden,
  startOnly,
  startAndEnd,
}

enum LiveDuringClassTimeDisplayMode {
  nearest,
  total,
}

enum MiuiIslandLabelStyle {
  textOnly,
  iconAndText,
}

enum MiuiIslandLabelContent {
  courseName,
  location,
  courseNameAndLocation,
}

enum MiuiIslandLabelFontWeight {
  regular,
  medium,
  bold,
}

enum MiuiIslandLabelRenderQuality {
  standard,
  high,
  ultra,
}

enum MiuiIslandExpandedIconMode {
  appIcon,
  customImage,
  hidden,
}

enum LiveBeforeClassQuickAction {
  none,
  silent,
  doNotDisturb,
}

extension SectionTimeDisplayModeX on SectionTimeDisplayMode {
  String get value => switch (this) {
        SectionTimeDisplayMode.hidden => 'hidden',
        SectionTimeDisplayMode.startOnly => 'start_only',
        SectionTimeDisplayMode.startAndEnd => 'start_and_end',
      };

  String get label => switch (this) {
        SectionTimeDisplayMode.hidden => '不显示',
        SectionTimeDisplayMode.startOnly => '仅显示上课时间',
        SectionTimeDisplayMode.startAndEnd => '显示上下课时间',
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
        WidgetBackgroundStyle.solid => 'solid',
        WidgetBackgroundStyle.gradient => 'gradient',
      };

  String get label => switch (this) {
        WidgetBackgroundStyle.solid => '纯色卡片',
        WidgetBackgroundStyle.gradient => '渐变卡片',
      };

  static WidgetBackgroundStyle fromValue(String? value) {
    return WidgetBackgroundStyle.values.firstWhere(
      (item) => item.value == value,
      orElse: () => WidgetBackgroundStyle.solid,
    );
  }
}

extension LiveDuringClassTimeDisplayModeX on LiveDuringClassTimeDisplayMode {
  String get value => switch (this) {
        LiveDuringClassTimeDisplayMode.nearest => 'nearest',
        LiveDuringClassTimeDisplayMode.total => 'total',
      };

  String get label => switch (this) {
        LiveDuringClassTimeDisplayMode.nearest => '最近时间',
        LiveDuringClassTimeDisplayMode.total => '总时间',
      };

  static LiveDuringClassTimeDisplayMode fromValue(String? value) {
    return LiveDuringClassTimeDisplayMode.values.firstWhere(
      (item) => item.value == value,
      orElse: () => LiveDuringClassTimeDisplayMode.nearest,
    );
  }
}

extension MiuiIslandLabelStyleX on MiuiIslandLabelStyle {
  String get value => switch (this) {
        MiuiIslandLabelStyle.textOnly => 'text_only',
        MiuiIslandLabelStyle.iconAndText => 'icon_and_text',
      };

  String get label => switch (this) {
        MiuiIslandLabelStyle.textOnly => '仅文字',
        MiuiIslandLabelStyle.iconAndText => '图标+文字',
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
        MiuiIslandLabelContent.courseNameAndLocation =>
          'course_name_and_location',
      };

  String get label => switch (this) {
        MiuiIslandLabelContent.courseName => '课程名',
        MiuiIslandLabelContent.location => '教室',
        MiuiIslandLabelContent.courseNameAndLocation => '课程名+教室',
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

  String get label => switch (this) {
        MiuiIslandLabelFontWeight.regular => '常规',
        MiuiIslandLabelFontWeight.medium => '中等',
        MiuiIslandLabelFontWeight.bold => '加粗',
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

  String get label => switch (this) {
        MiuiIslandLabelRenderQuality.standard => '标准',
        MiuiIslandLabelRenderQuality.high => '高清',
        MiuiIslandLabelRenderQuality.ultra => '超高清',
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

  String get label => switch (this) {
        MiuiIslandExpandedIconMode.appIcon => '应用图标',
        MiuiIslandExpandedIconMode.customImage => '自定义图片',
        MiuiIslandExpandedIconMode.hidden => '不显示',
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

  String get label => switch (this) {
        LiveBeforeClassQuickAction.none => '不显示',
        LiveBeforeClassQuickAction.silent => '打开静音',
        LiveBeforeClassQuickAction.doNotDisturb => '打开免打扰',
      };

  static LiveBeforeClassQuickAction fromValue(String? value) {
    return LiveBeforeClassQuickAction.values.firstWhere(
      (item) => item.value == value,
      orElse: () => LiveBeforeClassQuickAction.none,
    );
  }
}

enum CourseCardVerticalAlign {
  top,
  center,
  bottom,
  spaceEvenly,
}

extension CourseCardVerticalAlignX on CourseCardVerticalAlign {
  String get value => switch (this) {
        CourseCardVerticalAlign.top => 'top',
        CourseCardVerticalAlign.center => 'center',
        CourseCardVerticalAlign.bottom => 'bottom',
        CourseCardVerticalAlign.spaceEvenly => 'space_evenly',
      };

  String get label => switch (this) {
        CourseCardVerticalAlign.top => '顶部对齐',
        CourseCardVerticalAlign.center => '垂直居中',
        CourseCardVerticalAlign.bottom => '底部对齐',
        CourseCardVerticalAlign.spaceEvenly => '上下均布',
      };

  static CourseCardVerticalAlign fromValue(String? value) {
    return CourseCardVerticalAlign.values.firstWhere(
      (item) => item.value == value,
      orElse: () => CourseCardVerticalAlign.center,
    );
  }
}

enum CourseCardHorizontalAlign {
  left,
  center,
  right,
}

extension CourseCardHorizontalAlignX on CourseCardHorizontalAlign {
  String get value => switch (this) {
        CourseCardHorizontalAlign.left => 'left',
        CourseCardHorizontalAlign.center => 'center',
        CourseCardHorizontalAlign.right => 'right',
      };

  String get label => switch (this) {
        CourseCardHorizontalAlign.left => '居左',
        CourseCardHorizontalAlign.center => '居中',
        CourseCardHorizontalAlign.right => '居右',
      };

  static CourseCardHorizontalAlign fromValue(String? value) {
    return CourseCardHorizontalAlign.values.firstWhere(
      (item) => item.value == value,
      orElse: () => CourseCardHorizontalAlign.center,
    );
  }
}

extension AppUpdateDownloadSourceX on AppUpdateDownloadSource {
  String get value => switch (this) {
        AppUpdateDownloadSource.original => 'original',
        AppUpdateDownloadSource.mirror => 'mirror',
      };

  String get label => switch (this) {
        AppUpdateDownloadSource.original => '原版下载',
        AppUpdateDownloadSource.mirror => '镜像下载',
      };

  static AppUpdateDownloadSource fromValue(String? value) {
    return AppUpdateDownloadSource.values.firstWhere(
      (item) => item.value == value,
      orElse: () => AppUpdateDownloadSource.original,
    );
  }
}

class LiveDisplaySettings {
  final bool showCourseName;
  final bool showLocation;
  final bool showCountdown;
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
  final MiuiIslandExpandedIconMode miuiIslandExpandedIconMode;
  final String? miuiIslandExpandedIconPath;

  const LiveDisplaySettings({
    required this.showCourseName,
    required this.showLocation,
    required this.showCountdown,
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
    required this.miuiIslandExpandedIconMode,
    required this.miuiIslandExpandedIconPath,
  });

  LiveDisplaySettings copyWith({
    bool? showCourseName,
    bool? showLocation,
    bool? showCountdown,
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
    MiuiIslandExpandedIconMode? miuiIslandExpandedIconMode,
    String? miuiIslandExpandedIconPath,
    bool clearMiuiIslandExpandedIconPath = false,
  }) {
    return LiveDisplaySettings(
      showCourseName: showCourseName ?? this.showCourseName,
      showLocation: showLocation ?? this.showLocation,
      showCountdown: showCountdown ?? this.showCountdown,
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

  const SectionTime({
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime,
      'endTime': endTime,
    };
  }

  factory SectionTime.fromJson(Map<String, dynamic> json) {
    return SectionTime(
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
    );
  }

  SectionTime copyWith({
    String? startTime,
    String? endTime,
  }) {
    return SectionTime(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  String get displayText => '$startTime-$endTime';
}

class TimetableSettings {
  final List<SectionTime> sections;
  final String? activeTimeSchemeId;
  final double sectionHeight;
  final double compactFontSize;
  final bool timetableAutoFitSectionHeight;
  final int semesterWeekCount;
  final DateTime? semesterStartDate;
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
  final WidgetBackgroundStyle widgetBackgroundStyle;
  final bool widgetShowLocation;
  final bool widgetShowCountdown;
  final SectionTimeDisplayMode timetableSectionTimeDisplayMode;
  final bool timetableHideWeekends;
  final bool enableHaptics;
  final bool liveShowCourseName;
  final bool liveShowLocation;
  final bool liveShowCountdown;
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
  final MiuiIslandExpandedIconMode liveDuringEndMiuiIslandExpandedIconMode;
  final String? liveDuringEndMiuiIslandExpandedIconPath;
  final int liveShowBeforeClassMinutes;
  final int liveClassReminderStartMinutes;
  final int liveEndSecondsCountdownThreshold;
  final int liveTimeCorrectionSeconds;
  final LiveBeforeClassQuickAction liveBeforeClassQuickAction;
  final String themeSeedColor;
  final String timetablePageBackgroundColor;
  final bool timetableUseUnifiedCardColor;
  final String timetableUnifiedCardColor;
  final String appUpdateDownloadSource;
  final bool appUpdateIncludePrerelease;
  final String appUpdateMirrorUrlPrefix;

  const TimetableSettings({
    required this.sections,
    this.activeTimeSchemeId,
    this.sectionHeight = 68,
    this.compactFontSize = 9,
    this.timetableAutoFitSectionHeight = false,
    this.semesterWeekCount = 20,
    this.semesterStartDate,
    this.timetableShowCurrentWeekCourses = true,
    this.timetableShowNonCurrentWeekCourses = false,
    this.showConflictBadgeOnTimetable = true,
    this.timetableConflictCourseOpacity = 0.72,
    this.courseCardShowName = true,
    this.courseCardShowTeacher = true,
    this.courseCardShowLocation = true,
    this.courseCardShowTime = false,
    this.courseCardShowTimeLabels = true,
    this.courseCardShowWeeks = false,
    this.courseCardShowDescription = false,
    this.courseCardVerticalAlign = CourseCardVerticalAlign.center,
    this.courseCardHorizontalAlign = CourseCardHorizontalAlign.center,
    this.widgetBackgroundStyle = WidgetBackgroundStyle.solid,
    this.widgetShowLocation = true,
    this.widgetShowCountdown = true,
    this.timetableSectionTimeDisplayMode = SectionTimeDisplayMode.startAndEnd,
    this.timetableHideWeekends = false,
    this.enableHaptics = true,
    this.liveShowCourseName = true,
    this.liveShowLocation = true,
    this.liveShowCountdown = true,
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
    this.liveDuringEndMiuiIslandExpandedIconMode =
        MiuiIslandExpandedIconMode.appIcon,
    this.liveDuringEndMiuiIslandExpandedIconPath,
    this.liveShowBeforeClassMinutes = 20,
    this.liveClassReminderStartMinutes = 0,
    this.liveEndSecondsCountdownThreshold = 60,
    this.liveTimeCorrectionSeconds = 0,
    this.liveBeforeClassQuickAction = LiveBeforeClassQuickAction.none,
    this.themeSeedColor = '#2563EB',
    this.timetablePageBackgroundColor = '#F8FAFC',
    this.timetableUseUnifiedCardColor = false,
    this.timetableUnifiedCardColor = '#2563EB',
    this.appUpdateDownloadSource = 'original',
    this.appUpdateIncludePrerelease = false,
    this.appUpdateMirrorUrlPrefix = 'https://ghfast.top/',
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
      timetableShowCurrentWeekCourses: true,
      timetableShowNonCurrentWeekCourses: false,
      showConflictBadgeOnTimetable: true,
      timetableConflictCourseOpacity: 0.72,
      courseCardShowName: true,
      courseCardShowTeacher: true,
      courseCardShowLocation: true,
      courseCardShowTime: false,
      courseCardShowTimeLabels: true,
      courseCardShowWeeks: false,
      courseCardShowDescription: false,
      courseCardVerticalAlign: CourseCardVerticalAlign.center,
      courseCardHorizontalAlign: CourseCardHorizontalAlign.center,
      widgetBackgroundStyle: WidgetBackgroundStyle.solid,
      widgetShowLocation: true,
      widgetShowCountdown: true,
      timetableSectionTimeDisplayMode: SectionTimeDisplayMode.startAndEnd,
      timetableHideWeekends: false,
      enableHaptics: true,
      liveShowCourseName: true,
      liveShowLocation: true,
      liveShowCountdown: true,
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
      liveDuringEndMiuiIslandExpandedIconMode:
          MiuiIslandExpandedIconMode.appIcon,
      liveDuringEndMiuiIslandExpandedIconPath: null,
      liveShowBeforeClassMinutes: 20,
      liveClassReminderStartMinutes: 0,
      liveEndSecondsCountdownThreshold: 60,
      liveTimeCorrectionSeconds: 0,
      liveBeforeClassQuickAction: LiveBeforeClassQuickAction.none,
      themeSeedColor: '#2563EB',
      timetablePageBackgroundColor: '#F8FAFC',
      timetableUseUnifiedCardColor: false,
      timetableUnifiedCardColor: '#2563EB',
      appUpdateDownloadSource: 'original',
      appUpdateIncludePrerelease: false,
      appUpdateMirrorUrlPrefix: 'https://ghfast.top/',
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
      'widgetBackgroundStyle': widgetBackgroundStyle.value,
      'widgetShowLocation': widgetShowLocation,
      'widgetShowCountdown': widgetShowCountdown,
      'timetableSectionTimeDisplayMode': timetableSectionTimeDisplayMode.value,
      'timetableHideWeekends': timetableHideWeekends,
      'enableHaptics': enableHaptics,
      'liveShowCourseName': liveShowCourseName,
      'liveShowLocation': liveShowLocation,
      'liveShowCountdown': liveShowCountdown,
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
      'timetablePageBackgroundColor': timetablePageBackgroundColor,
      'timetableUseUnifiedCardColor': timetableUseUnifiedCardColor,
      'timetableUnifiedCardColor': timetableUnifiedCardColor,
      'appUpdateDownloadSource': appUpdateDownloadSource,
      'appUpdateIncludePrerelease': appUpdateIncludePrerelease,
      'appUpdateMirrorUrlPrefix': appUpdateMirrorUrlPrefix,
    };
  }

  factory TimetableSettings.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'] as List<dynamic>? ?? const [];
    if (rawSections.isEmpty) {
      return TimetableSettings.defaults();
    }

    return TimetableSettings(
      sections: rawSections
          .map((item) =>
              SectionTime.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
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
      timetableShowCurrentWeekCourses: true,
      timetableShowNonCurrentWeekCourses:
          json['timetableShowNonCurrentWeekCourses'] as bool? ?? false,
      showConflictBadgeOnTimetable:
          json['showConflictBadgeOnTimetable'] as bool? ?? true,
      timetableConflictCourseOpacity:
          ((json['timetableConflictCourseOpacity'] as num?)?.toDouble() ?? 0.72)
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
      widgetBackgroundStyle: WidgetBackgroundStyleX.fromValue(
        json['widgetBackgroundStyle'] as String?,
      ),
      widgetShowLocation: json['widgetShowLocation'] as bool? ?? true,
      widgetShowCountdown: json['widgetShowCountdown'] as bool? ?? true,
      timetableSectionTimeDisplayMode: SectionTimeDisplayModeX.fromValue(
        json['timetableSectionTimeDisplayMode'] as String?,
      ),
      timetableHideWeekends: json['timetableHideWeekends'] as bool? ?? false,
      enableHaptics: json['enableHaptics'] as bool? ?? true,
      liveShowCourseName: json['liveShowCourseName'] as bool? ?? true,
      liveShowLocation: json['liveShowLocation'] as bool? ?? true,
      liveShowCountdown: json['liveShowCountdown'] as bool? ?? true,
      liveShowStageText: json['liveShowStageText'] as bool? ?? true,
      liveEnableBeforeClass: json['liveEnableBeforeClass'] as bool? ?? true,
      liveEnableDuringClass: json['liveEnableDuringClass'] as bool? ?? true,
      liveEnableBeforeEnd: json['liveEnableBeforeEnd'] as bool? ?? true,
      livePromoteDuringClass: json['livePromoteDuringClass'] as bool? ?? true,
      liveShowDuringClassNotification:
          json['liveShowDuringClassNotification'] as bool? ?? true,
      liveUseShortName: json['liveUseShortName'] as bool? ?? true,
      liveHidePrefixText: json['liveHidePrefixText'] as bool? ?? true,
      liveDuringClassTimeDisplayMode: LiveDuringClassTimeDisplayModeX.fromValue(
          json['liveDuringClassTimeDisplayMode'] as String?),
      liveEnableMiuiIslandLabelImage:
          json['liveEnableMiuiIslandLabelImage'] as bool? ?? false,
      liveDuringEndShowCourseName:
          json['liveDuringEndShowCourseName'] as bool? ??
              (json['liveShowCourseName'] as bool? ?? true),
      liveDuringEndShowLocation: json['liveDuringEndShowLocation'] as bool? ??
          (json['liveShowLocation'] as bool? ?? true),
      liveDuringEndShowCountdown: json['liveDuringEndShowCountdown'] as bool? ??
          (json['liveShowCountdown'] as bool? ?? true),
      liveDuringEndShowStageText: json['liveDuringEndShowStageText'] as bool? ??
          (json['liveShowStageText'] as bool? ?? true),
      liveDuringEndUseShortName: json['liveDuringEndUseShortName'] as bool? ??
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
      timetablePageBackgroundColor:
          json['timetablePageBackgroundColor'] as String? ?? '#F8FAFC',
      timetableUseUnifiedCardColor:
          json['timetableUseUnifiedCardColor'] as bool? ?? false,
      timetableUnifiedCardColor:
          json['timetableUnifiedCardColor'] as String? ?? '#2563EB',
      appUpdateDownloadSource:
          json['appUpdateDownloadSource'] as String? ?? 'original',
      appUpdateIncludePrerelease:
          json['appUpdateIncludePrerelease'] as bool? ?? false,
      appUpdateMirrorUrlPrefix:
          json['appUpdateMirrorUrlPrefix'] as String? ?? 'https://ghfast.top/',
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
    WidgetBackgroundStyle? widgetBackgroundStyle,
    bool? widgetShowLocation,
    bool? widgetShowCountdown,
    SectionTimeDisplayMode? timetableSectionTimeDisplayMode,
    bool? timetableHideWeekends,
    bool? enableHaptics,
    bool? liveShowCourseName,
    bool? liveShowLocation,
    bool? liveShowCountdown,
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
    MiuiIslandExpandedIconMode? liveDuringEndMiuiIslandExpandedIconMode,
    String? liveDuringEndMiuiIslandExpandedIconPath,
    bool clearLiveDuringEndMiuiIslandExpandedIconPath = false,
    int? liveShowBeforeClassMinutes,
    int? liveClassReminderStartMinutes,
    int? liveEndSecondsCountdownThreshold,
    int? liveTimeCorrectionSeconds,
    LiveBeforeClassQuickAction? liveBeforeClassQuickAction,
    String? themeSeedColor,
    String? timetablePageBackgroundColor,
    bool? timetableUseUnifiedCardColor,
    String? timetableUnifiedCardColor,
    String? appUpdateDownloadSource,
    bool? appUpdateIncludePrerelease,
    String? appUpdateMirrorUrlPrefix,
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
      timetableShowCurrentWeekCourses: true,
      timetableShowNonCurrentWeekCourses: timetableShowNonCurrentWeekCourses ??
          this.timetableShowNonCurrentWeekCourses,
      showConflictBadgeOnTimetable:
          showConflictBadgeOnTimetable ?? this.showConflictBadgeOnTimetable,
      timetableConflictCourseOpacity: (timetableConflictCourseOpacity ??
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
      widgetBackgroundStyle:
          widgetBackgroundStyle ?? this.widgetBackgroundStyle,
      widgetShowLocation: widgetShowLocation ?? this.widgetShowLocation,
      widgetShowCountdown: widgetShowCountdown ?? this.widgetShowCountdown,
      timetableSectionTimeDisplayMode: timetableSectionTimeDisplayMode ??
          this.timetableSectionTimeDisplayMode,
      timetableHideWeekends:
          timetableHideWeekends ?? this.timetableHideWeekends,
      enableHaptics: enableHaptics ?? this.enableHaptics,
      liveShowCourseName: liveShowCourseName ?? this.liveShowCourseName,
      liveShowLocation: liveShowLocation ?? this.liveShowLocation,
      liveShowCountdown: liveShowCountdown ?? this.liveShowCountdown,
      liveShowStageText: liveShowStageText ?? this.liveShowStageText,
      liveEnableBeforeClass:
          liveEnableBeforeClass ?? this.liveEnableBeforeClass,
      liveEnableDuringClass:
          liveEnableDuringClass ?? this.liveEnableDuringClass,
      liveEnableBeforeEnd: liveEnableBeforeEnd ?? this.liveEnableBeforeEnd,
      livePromoteDuringClass:
          livePromoteDuringClass ?? this.livePromoteDuringClass,
      liveShowDuringClassNotification: liveShowDuringClassNotification ??
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
      liveMiuiIslandLabelRenderQuality: liveMiuiIslandLabelRenderQuality ??
          this.liveMiuiIslandLabelRenderQuality,
      liveMiuiIslandLabelFontSize:
          liveMiuiIslandLabelFontSize ?? this.liveMiuiIslandLabelFontSize,
      liveMiuiIslandLabelOffsetX:
          liveMiuiIslandLabelOffsetX ?? this.liveMiuiIslandLabelOffsetX,
      liveMiuiIslandLabelOffsetY:
          liveMiuiIslandLabelOffsetY ?? this.liveMiuiIslandLabelOffsetY,
      liveMiuiIslandExpandedIconMode:
          liveMiuiIslandExpandedIconMode ?? this.liveMiuiIslandExpandedIconMode,
      liveMiuiIslandExpandedIconPath: clearLiveMiuiIslandExpandedIconPath
          ? null
          : liveMiuiIslandExpandedIconPath ??
              this.liveMiuiIslandExpandedIconPath,
      liveDuringEndMiuiIslandLabelStyle: liveDuringEndMiuiIslandLabelStyle ??
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
      liveEndSecondsCountdownThreshold: liveEndSecondsCountdownThreshold ??
          this.liveEndSecondsCountdownThreshold,
      liveTimeCorrectionSeconds:
          liveTimeCorrectionSeconds ?? this.liveTimeCorrectionSeconds,
      liveBeforeClassQuickAction:
          liveBeforeClassQuickAction ?? this.liveBeforeClassQuickAction,
      themeSeedColor: themeSeedColor ?? this.themeSeedColor,
      timetablePageBackgroundColor:
          timetablePageBackgroundColor ?? this.timetablePageBackgroundColor,
      timetableUseUnifiedCardColor:
          timetableUseUnifiedCardColor ?? this.timetableUseUnifiedCardColor,
      timetableUnifiedCardColor:
          timetableUnifiedCardColor ?? this.timetableUnifiedCardColor,
      appUpdateDownloadSource:
          appUpdateDownloadSource ?? this.appUpdateDownloadSource,
      appUpdateIncludePrerelease:
          appUpdateIncludePrerelease ?? this.appUpdateIncludePrerelease,
      appUpdateMirrorUrlPrefix:
          appUpdateMirrorUrlPrefix ?? this.appUpdateMirrorUrlPrefix,
    );
  }

  int get sectionCount => sections.length;

  LiveDisplaySettings get beforeClassDisplaySettings => LiveDisplaySettings(
        showCourseName: liveShowCourseName,
        showLocation: liveShowLocation,
        showCountdown: liveShowCountdown,
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
              showStageText: liveDuringEndShowStageText,
              useShortName: liveDuringEndUseShortName,
              hidePrefixText: liveDuringEndHidePrefixText,
              duringClassTimeDisplayMode: liveDuringEndTimeDisplayMode,
              enableMiuiIslandLabelImage:
                  liveDuringEndEnableMiuiIslandLabelImage,
              miuiIslandLabelStyle: liveDuringEndMiuiIslandLabelStyle,
              miuiIslandLabelContent: liveDuringEndMiuiIslandLabelContent,
              miuiIslandLabelFontColor: liveDuringEndMiuiIslandLabelFontColor,
              miuiIslandLabelFontWeight: liveDuringEndMiuiIslandLabelFontWeight,
              miuiIslandLabelRenderQuality:
                  liveDuringEndMiuiIslandLabelRenderQuality,
              miuiIslandLabelFontSize: liveDuringEndMiuiIslandLabelFontSize,
              miuiIslandLabelOffsetX: liveDuringEndMiuiIslandLabelOffsetX,
              miuiIslandLabelOffsetY: liveDuringEndMiuiIslandLabelOffsetY,
              miuiIslandExpandedIconMode:
                  liveDuringEndMiuiIslandExpandedIconMode,
              miuiIslandExpandedIconPath:
                  liveDuringEndMiuiIslandExpandedIconPath,
            );

  TimetableSettings copyWithBeforeClassDisplaySettings(
    LiveDisplaySettings settings, {
    bool clearExpandedIconPath = false,
  }) {
    return copyWith(
      liveShowCourseName: settings.showCourseName,
      liveShowLocation: settings.showLocation,
      liveShowCountdown: settings.showCountdown,
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
      liveMiuiIslandExpandedIconMode: settings.miuiIslandExpandedIconMode,
      liveMiuiIslandExpandedIconPath: settings.miuiIslandExpandedIconPath,
      clearLiveMiuiIslandExpandedIconPath: clearExpandedIconPath,
    );
  }

  TimetableSettings copyWithDuringEndDisplaySettings(
    LiveDisplaySettings settings, {
    bool clearExpandedIconPath = false,
  }) {
    return copyWith(
      liveDuringEndShowCourseName: settings.showCourseName,
      liveDuringEndShowLocation: settings.showLocation,
      liveDuringEndShowCountdown: settings.showCountdown,
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
