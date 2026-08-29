import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';

void main() {
  test('defaults include semester week count and preserve it in json', () {
    final settings = TimetableSettings.defaults();

    expect(settings.semesterWeekCount, 20);
    expect(settings.timetableShowCurrentWeekCourses, isTrue);
    expect(settings.timetableShowNonCurrentWeekCourses, isFalse);
    expect(settings.showConflictBadgeOnTimetable, isTrue);
    expect(settings.timetableConflictCourseOpacity, 0.70);
    expect(settings.liveHidePrefixText, isTrue);
    expect(settings.courseCardShowName, isTrue);
    expect(settings.courseCardShowTeacher, isTrue);
    expect(settings.courseCardShowLocation, isTrue);
    expect(settings.courseCardShowTime, isFalse);
    expect(settings.courseCardShowTimeLabels, isTrue);
    expect(settings.courseCardShowWeeks, isFalse);
    expect(settings.courseCardShowDescription, isFalse);
    expect(settings.timetableAutoFitSectionHeight, isFalse);
    expect(settings.widgetBackgroundStyle, WidgetBackgroundStyle.solid);
    expect(settings.widgetShowLocation, isTrue);
    expect(settings.widgetShowCountdown, isTrue);
    expect(settings.widgetHideCompletedCourses, isFalse);
    expect(settings.widgetHeightAdjustment, -11);
    expect(settings.widgetCornerRadius, 22);
    expect(settings.appThemeMode, AppThemeMode.system);
    expect(settings.homeTitleStyle, HomeTitleStyle.classic);
    expect(
      settings.timetableBackToCurrentWeekButtonStyle,
      BackToCurrentWeekButtonStyle.floating,
    );
    expect(settings.timetableFloatingBackToCurrentWeekButtonOpacity, 0.96);
    expect(
      settings.timetableSectionTimeDisplayMode,
      SectionTimeDisplayMode.startAndEnd,
    );
    expect(settings.timetableHideWeekends, isFalse);
    expect(settings.enableHaptics, isTrue);
    expect(
      settings.liveDuringClassTimeDisplayMode,
      LiveDuringClassTimeDisplayMode.nearest,
    );
    expect(settings.liveCountdownTextStyle, LiveCountdownTextStyle.smart);
    expect(settings.liveEnableMiuiIslandLabelImage, isFalse);
    expect(settings.liveHideFromRecents, isFalse);
    expect(settings.liveEnableLocalDiagnostics, isFalse);
    expect(settings.liveDuringEndFollowBeforeClass, isTrue);
    expect(settings.liveTimeCorrectionSeconds, 0);
    expect(
      settings.liveBeforeClassQuickAction,
      LiveBeforeClassQuickAction.none,
    );
    expect(settings.liveShowStageText, isTrue);
    expect(settings.liveMiuiIslandLabelStyle, MiuiIslandLabelStyle.textOnly);
    expect(
      settings.liveMiuiIslandLabelContent,
      MiuiIslandLabelContent.courseName,
    );
    expect(settings.liveMiuiIslandLabelFontColor, '#FFFFFF');
    expect(
      settings.liveMiuiIslandLabelFontWeight,
      MiuiIslandLabelFontWeight.bold,
    );
    expect(settings.liveMiuiIslandLabelFontSize, 14);
    expect(settings.liveMiuiIslandLabelOffsetX, 0);
    expect(settings.liveMiuiIslandLabelOffsetY, 0);
    expect(
      settings.liveMiuiIslandExpandedIconMode,
      MiuiIslandExpandedIconMode.appIcon,
    );
    expect(settings.liveMiuiIslandExpandedIconPath, isNull);
    expect(settings.appUpdateDownloadSource, 'mirror');
    expect(settings.appUpdateMirrorPreset, 'ghfast');
    expect(settings.appUpdateIncludePrerelease, isFalse);
    expect(settings.appUpdateMirrorUrlPrefix, defaultAppUpdateMirrorUrlPrefix);
    expect(settings.courseCardVerticalAlign, CourseCardVerticalAlign.center);
    expect(
      settings.courseCardHorizontalAlign,
      CourseCardHorizontalAlign.center,
    );
    expect(settings.courseCardFontSize, 9);
    expect(
      settings.timetableTimeColumnWidthMode,
      TimetableTimeColumnWidthMode.narrow,
    );
    expect(settings.timetableCourseCardGap, 1.25);
    expect(
      settings.timetableCourseSpacingMode,
      TimetableCourseSpacingMode.narrow,
    );

    final restored = TimetableSettings.fromJson(settings.toJson());
    expect(restored.semesterWeekCount, 20);
    expect(restored.timetableShowCurrentWeekCourses, isTrue);
    expect(restored.timetableShowNonCurrentWeekCourses, isFalse);
    expect(restored.showConflictBadgeOnTimetable, isTrue);
    expect(restored.timetableConflictCourseOpacity, 0.70);
    expect(restored.liveHidePrefixText, isTrue);
    expect(restored.courseCardShowName, isTrue);
    expect(restored.courseCardShowTeacher, isTrue);
    expect(restored.courseCardShowLocation, isTrue);
    expect(restored.courseCardShowTime, isFalse);
    expect(restored.courseCardShowTimeLabels, isTrue);
    expect(restored.courseCardShowWeeks, isFalse);
    expect(restored.courseCardShowDescription, isFalse);
    expect(restored.timetableAutoFitSectionHeight, isFalse);
    expect(restored.widgetBackgroundStyle, WidgetBackgroundStyle.solid);
    expect(restored.widgetShowLocation, isTrue);
    expect(restored.widgetShowCountdown, isTrue);
    expect(restored.widgetHideCompletedCourses, isFalse);
    expect(restored.widgetHeightAdjustment, -11);
    expect(restored.widgetCornerRadius, 22);
    expect(restored.appThemeMode, AppThemeMode.system);
    expect(restored.homeTitleStyle, HomeTitleStyle.classic);
    expect(
      restored.timetableBackToCurrentWeekButtonStyle,
      BackToCurrentWeekButtonStyle.floating,
    );
    expect(restored.timetableFloatingBackToCurrentWeekButtonOpacity, 0.96);
    expect(
      restored.timetableSectionTimeDisplayMode,
      SectionTimeDisplayMode.startAndEnd,
    );
    expect(restored.timetableHideWeekends, isFalse);
    expect(restored.enableHaptics, isTrue);
    expect(
      restored.liveDuringClassTimeDisplayMode,
      LiveDuringClassTimeDisplayMode.nearest,
    );
    expect(restored.liveCountdownTextStyle, LiveCountdownTextStyle.smart);
    expect(restored.liveEnableMiuiIslandLabelImage, isFalse);
    expect(restored.liveHideFromRecents, isFalse);
    expect(restored.liveEnableLocalDiagnostics, isFalse);
    expect(restored.liveDuringEndFollowBeforeClass, isTrue);
    expect(restored.liveTimeCorrectionSeconds, 0);
    expect(
      restored.liveBeforeClassQuickAction,
      LiveBeforeClassQuickAction.none,
    );
    expect(restored.liveShowStageText, isTrue);
    expect(restored.liveMiuiIslandLabelStyle, MiuiIslandLabelStyle.textOnly);
    expect(
      restored.liveMiuiIslandLabelContent,
      MiuiIslandLabelContent.courseName,
    );
    expect(restored.liveMiuiIslandLabelFontColor, '#FFFFFF');
    expect(
      restored.liveMiuiIslandLabelFontWeight,
      MiuiIslandLabelFontWeight.bold,
    );
    expect(restored.liveMiuiIslandLabelFontSize, 14);
    expect(restored.liveMiuiIslandLabelOffsetX, 0);
    expect(restored.liveMiuiIslandLabelOffsetY, 0);
    expect(
      restored.liveMiuiIslandExpandedIconMode,
      MiuiIslandExpandedIconMode.appIcon,
    );
    expect(restored.liveMiuiIslandExpandedIconPath, isNull);
    expect(restored.appUpdateDownloadSource, 'mirror');
    expect(restored.appUpdateMirrorPreset, 'ghfast');
    expect(restored.appUpdateIncludePrerelease, isFalse);
    expect(restored.appUpdateMirrorUrlPrefix, defaultAppUpdateMirrorUrlPrefix);
    expect(restored.courseCardVerticalAlign, CourseCardVerticalAlign.center);
    expect(
      restored.courseCardHorizontalAlign,
      CourseCardHorizontalAlign.center,
    );
    expect(restored.courseCardFontSize, 9);
    expect(
      restored.timetableTimeColumnWidthMode,
      TimetableTimeColumnWidthMode.narrow,
    );
    expect(restored.timetableCourseCardGap, 1.25);
    expect(
      restored.timetableCourseSpacingMode,
      TimetableCourseSpacingMode.narrow,
    );
  });

  test('available weeks follow configured semester week count', () {
    final settings = TimetableSettings.defaults().copyWith(
      semesterWeekCount: 24,
    );

    expect(settings.availableWeeks, List.generate(24, (index) => index + 1));
  });

  test('settings preserve active time scheme id', () {
    final settings = TimetableSettings.defaults().copyWith(
      activeTimeSchemeId: 'scheme-1',
      timetableShowNonCurrentWeekCourses: true,
      showConflictBadgeOnTimetable: false,
      timetableConflictCourseOpacity: 0.55,
      timetableAutoFitSectionHeight: true,
      courseCardShowTime: true,
      courseCardShowTimeLabels: false,
      courseCardShowWeeks: true,
      widgetBackgroundStyle: WidgetBackgroundStyle.gradient,
      widgetShowLocation: false,
      widgetShowCountdown: false,
      widgetHideCompletedCourses: true,
      widgetHeightAdjustment: 12,
      widgetCornerRadius: 18,
      appThemeMode: AppThemeMode.dark,
      homeTitleStyle: HomeTitleStyle.brand,
      timetableBackToCurrentWeekButtonStyle:
          BackToCurrentWeekButtonStyle.floating,
      timetableFloatingBackToCurrentWeekButtonOpacity: 0.7,
      courseCardVerticalAlign: CourseCardVerticalAlign.spaceEvenly,
      courseCardHorizontalAlign: CourseCardHorizontalAlign.right,
      courseCardFontSize: 10.5,
      timetableTimeColumnWidthMode: TimetableTimeColumnWidthMode.wide,
      timetableCourseCardGap: 2.4,
      timetableCourseSpacingMode: TimetableCourseSpacingMode.wide,
      timetableSectionTimeDisplayMode: SectionTimeDisplayMode.startAndEnd,
      timetableHideWeekends: true,
      enableHaptics: false,
      liveDuringClassTimeDisplayMode: LiveDuringClassTimeDisplayMode.total,
      liveCountdownTextStyle: LiveCountdownTextStyle.minuteOnlyMin,
      liveEnableMiuiIslandLabelImage: true,
      liveHideFromRecents: true,
      liveEnableLocalDiagnostics: true,
      liveDuringEndFollowBeforeClass: false,
      liveTimeCorrectionSeconds: -7,
      liveBeforeClassQuickAction: LiveBeforeClassQuickAction.doNotDisturb,
      liveShowStageText: false,
      liveMiuiIslandLabelStyle: MiuiIslandLabelStyle.iconAndText,
      liveMiuiIslandLabelContent: MiuiIslandLabelContent.courseNameAndLocation,
      liveMiuiIslandLabelFontColor: '#FDE68A',
      liveMiuiIslandLabelFontWeight: MiuiIslandLabelFontWeight.medium,
      liveMiuiIslandLabelFontSize: 18,
      liveMiuiIslandLabelOffsetX: 6,
      liveMiuiIslandLabelOffsetY: -3,
      liveMiuiIslandExpandedIconMode: MiuiIslandExpandedIconMode.customImage,
      liveMiuiIslandExpandedIconPath: '/tmp/expanded.png',
      appUpdateDownloadSource: AppUpdateDownloadSource.original.value,
      appUpdateMirrorPreset: AppUpdateMirrorPreset.custom.value,
      appUpdateIncludePrerelease: true,
      appUpdateMirrorUrlPrefix: 'https://mirror.example.com/',
    );

    final restored = TimetableSettings.fromJson(settings.toJson());

    expect(restored.activeTimeSchemeId, 'scheme-1');
    expect(restored.timetableShowCurrentWeekCourses, isTrue);
    expect(restored.timetableShowNonCurrentWeekCourses, isTrue);
    expect(restored.showConflictBadgeOnTimetable, isFalse);
    expect(restored.timetableConflictCourseOpacity, 0.55);
    expect(restored.timetableAutoFitSectionHeight, isTrue);
    expect(restored.courseCardShowTime, isTrue);
    expect(restored.courseCardShowTimeLabels, isFalse);
    expect(restored.courseCardShowWeeks, isTrue);
    expect(restored.widgetBackgroundStyle, WidgetBackgroundStyle.gradient);
    expect(restored.widgetShowLocation, isFalse);
    expect(restored.widgetShowCountdown, isFalse);
    expect(restored.widgetHideCompletedCourses, isTrue);
    expect(restored.widgetHeightAdjustment, 12);
    expect(restored.widgetCornerRadius, 18);
    expect(restored.appThemeMode, AppThemeMode.dark);
    expect(restored.homeTitleStyle, HomeTitleStyle.brand);
    expect(
      restored.timetableBackToCurrentWeekButtonStyle,
      BackToCurrentWeekButtonStyle.floating,
    );
    expect(restored.timetableFloatingBackToCurrentWeekButtonOpacity, 0.7);
    expect(
      restored.timetableSectionTimeDisplayMode,
      SectionTimeDisplayMode.startAndEnd,
    );
    expect(restored.timetableHideWeekends, isTrue);
    expect(restored.enableHaptics, isFalse);
    expect(
      restored.liveDuringClassTimeDisplayMode,
      LiveDuringClassTimeDisplayMode.total,
    );
    expect(
      restored.liveCountdownTextStyle,
      LiveCountdownTextStyle.minuteOnlyMin,
    );
    expect(restored.liveEnableMiuiIslandLabelImage, isTrue);
    expect(restored.liveHideFromRecents, isTrue);
    expect(restored.liveEnableLocalDiagnostics, isTrue);
    expect(restored.liveDuringEndFollowBeforeClass, isFalse);
    expect(restored.liveTimeCorrectionSeconds, -7);
    expect(
      restored.liveBeforeClassQuickAction,
      LiveBeforeClassQuickAction.doNotDisturb,
    );
    expect(restored.liveShowStageText, isFalse);
    expect(restored.liveMiuiIslandLabelStyle, MiuiIslandLabelStyle.iconAndText);
    expect(
      restored.liveMiuiIslandLabelContent,
      MiuiIslandLabelContent.courseNameAndLocation,
    );
    expect(restored.liveMiuiIslandLabelFontColor, '#FDE68A');
    expect(
      restored.liveMiuiIslandLabelFontWeight,
      MiuiIslandLabelFontWeight.medium,
    );
    expect(restored.liveMiuiIslandLabelFontSize, 18);
    expect(restored.liveMiuiIslandLabelOffsetX, 6);
    expect(restored.liveMiuiIslandLabelOffsetY, -3);
    expect(
      restored.liveMiuiIslandExpandedIconMode,
      MiuiIslandExpandedIconMode.customImage,
    );
    expect(restored.liveMiuiIslandExpandedIconPath, '/tmp/expanded.png');
    expect(
      restored.appUpdateDownloadSource,
      AppUpdateDownloadSource.original.value,
    );
    expect(restored.appUpdateMirrorPreset, AppUpdateMirrorPreset.custom.value);
    expect(restored.appUpdateIncludePrerelease, isTrue);
    expect(restored.appUpdateMirrorUrlPrefix, 'https://mirror.example.com/');
    expect(
      restored.courseCardVerticalAlign,
      CourseCardVerticalAlign.spaceEvenly,
    );
    expect(restored.courseCardHorizontalAlign, CourseCardHorizontalAlign.right);
    expect(restored.courseCardFontSize, 10.5);
    expect(restored.timetableCourseCardGap, 2.4);
    expect(
      restored.timetableTimeColumnWidthMode,
      TimetableTimeColumnWidthMode.wide,
    );
    expect(
      restored.timetableCourseSpacingMode,
      TimetableCourseSpacingMode.wide,
    );
  });

  test(
    'during and end live display settings can be customized independently',
    () {
      final settings = TimetableSettings.defaults().copyWith(
        liveDuringEndFollowBeforeClass: false,
        liveDuringEndShowCourseName: false,
        liveDuringEndShowLocation: false,
        liveDuringEndShowCountdown: false,
        liveDuringEndShowStageText: true,
        liveDuringEndUseShortName: false,
        liveDuringEndHidePrefixText: false,
        liveDuringEndCountdownTextStyle: LiveCountdownTextStyle.secondOnlyShort,
        liveDuringEndTimeDisplayMode: LiveDuringClassTimeDisplayMode.total,
        liveDuringEndEnableMiuiIslandLabelImage: true,
        liveDuringEndMiuiIslandLabelStyle: MiuiIslandLabelStyle.iconAndText,
        liveDuringEndMiuiIslandLabelContent:
            MiuiIslandLabelContent.courseNameAndLocation,
        liveDuringEndMiuiIslandLabelFontColor: '#BFDBFE',
        liveDuringEndMiuiIslandLabelFontWeight:
            MiuiIslandLabelFontWeight.medium,
        liveDuringEndMiuiIslandLabelFontSize: 17,
        liveDuringEndMiuiIslandLabelOffsetX: 1.2,
        liveDuringEndMiuiIslandLabelOffsetY: -0.6,
        liveDuringEndMiuiIslandExpandedIconMode:
            MiuiIslandExpandedIconMode.customImage,
        liveDuringEndMiuiIslandExpandedIconPath: '/tmp/during-end.png',
      );

      final restored = TimetableSettings.fromJson(settings.toJson());
      final beforeClass = restored.beforeClassDisplaySettings;
      final duringEnd = restored.duringEndDisplaySettings;

      expect(beforeClass.showCourseName, isTrue);
      expect(duringEnd.showCourseName, isFalse);
      expect(duringEnd.showLocation, isFalse);
      expect(duringEnd.showCountdown, isFalse);
      expect(duringEnd.showStageText, isTrue);
      expect(duringEnd.useShortName, isFalse);
      expect(duringEnd.hidePrefixText, isFalse);
      expect(
        duringEnd.countdownTextStyle,
        LiveCountdownTextStyle.secondOnlyShort,
      );
      expect(
        duringEnd.duringClassTimeDisplayMode,
        LiveDuringClassTimeDisplayMode.total,
      );
      expect(duringEnd.enableMiuiIslandLabelImage, isTrue);
      expect(duringEnd.miuiIslandLabelStyle, MiuiIslandLabelStyle.iconAndText);
      expect(
        duringEnd.miuiIslandLabelContent,
        MiuiIslandLabelContent.courseNameAndLocation,
      );
      expect(duringEnd.miuiIslandLabelFontColor, '#BFDBFE');
      expect(
        duringEnd.miuiIslandLabelFontWeight,
        MiuiIslandLabelFontWeight.medium,
      );
      expect(duringEnd.miuiIslandLabelFontSize, 17);
      expect(duringEnd.miuiIslandLabelOffsetX, 1.2);
      expect(duringEnd.miuiIslandLabelOffsetY, -0.6);
      expect(
        duringEnd.miuiIslandExpandedIconMode,
        MiuiIslandExpandedIconMode.customImage,
      );
      expect(duringEnd.miuiIslandExpandedIconPath, '/tmp/during-end.png');
    },
  );

  test('during and end live display settings can follow before class', () {
    final settings = TimetableSettings.defaults().copyWith(
      liveShowCourseName: false,
      liveShowLocation: false,
      liveCountdownTextStyle: LiveCountdownTextStyle.minuteSecondCn,
      liveDuringEndFollowBeforeClass: true,
      liveDuringEndShowCourseName: true,
      liveDuringEndShowLocation: true,
    );

    final duringEnd = settings.duringEndDisplaySettings;

    expect(duringEnd.showCourseName, isFalse);
    expect(duringEnd.showLocation, isFalse);
    expect(duringEnd.countdownTextStyle, LiveCountdownTextStyle.minuteSecondCn);
  });

  test('legacy spacing mode migrates to numeric card gap', () {
    final restored = TimetableSettings.fromJson({
      ...TimetableSettings.defaults().toJson(),
      'timetableCourseCardGap': null,
      'timetableCourseSpacingMode': 'wide',
    });

    expect(restored.timetableCourseCardGap, 2.0);
  });

  test('removed course-card styles migrate to the two surviving tiers', () {
    TimetableSettings restore(String value) => TimetableSettings.fromJson({
      ...TimetableSettings.defaults().toJson(),
      'courseCardSurfaceStyle': value,
    });

    // 半透明并入实体卡片；玻璃 / 液态玻璃并入高斯模糊。
    expect(restore('translucent').courseCardSurfaceStyle,
        CourseCardSurfaceStyle.solid);
    expect(restore('glass').courseCardSurfaceStyle,
        CourseCardSurfaceStyle.gaussian);
    expect(restore('liquidGlass').courseCardSurfaceStyle,
        CourseCardSurfaceStyle.gaussian);
  });

  test('gaussian course-card style survives json round trip', () {
    final settings = TimetableSettings.defaults().copyWith(
      courseCardSurfaceStyle: CourseCardSurfaceStyle.gaussian,
    );

    final restored = TimetableSettings.fromJson(settings.toJson());

    expect(restored.courseCardSurfaceStyle, CourseCardSurfaceStyle.gaussian);
  });

  test('mirror preset resolves built-in and custom prefixes', () {
    expect(
      resolveAppUpdateMirrorUrlPrefix(
        preset: AppUpdateMirrorPreset.ghfast,
        customUrlPrefix: 'https://custom.example.com/',
      ),
      defaultAppUpdateMirrorUrlPrefix,
    );
    expect(
      resolveAppUpdateMirrorUrlPrefix(
        preset: AppUpdateMirrorPreset.ghproxyCn,
        customUrlPrefix: 'https://custom.example.com/',
      ),
      ghproxyCnMirrorUrlPrefix,
    );
    expect(
      resolveAppUpdateMirrorUrlPrefix(
        preset: AppUpdateMirrorPreset.custom,
        customUrlPrefix: 'https://custom.example.com/',
      ),
      'https://custom.example.com/',
    );
  });

  test('legacy mirror-only settings infer preset from saved prefix', () {
    final restored = TimetableSettings.fromJson({
      ...TimetableSettings.defaults().toJson(),
      'appUpdateMirrorPreset': null,
      'appUpdateMirrorUrlPrefix': 'https://mirror.example.com/',
    });

    expect(restored.appUpdateMirrorPreset, AppUpdateMirrorPreset.custom.value);
    expect(restored.appUpdateMirrorUrlPrefix, 'https://mirror.example.com/');
  });

  group('ThemeConfig', () {
    test('roundtrip preserves all fields', () {
      const original = ThemeConfig(
        version: 2,
        seedColor: '#FF0000',
        backgroundColor: '#FFFFFF',
        unifiedCardColor: '#00FF00',
        useUnifiedCardColor: true,
        themeMode: 'dark',
        courseCardTitleColorLight: '#111111',
        courseCardTitleColorDark: '#EEEEEE',
        courseCardDetailColorLight: '#222222',
        courseCardDetailColorDark: '#DDDDDD',
        weekdayBarFontColorLight: '#333333',
        weekdayBarFontColorDark: '#CCCCCC',
        weekdayBarAccentColorLight: '#444444',
        weekdayBarAccentColorDark: '#BBBBBB',
        timeAxisFontColorLight: '#555555',
        timeAxisFontColorDark: '#AAAAAA',
        linkCourseCardColors: false,
        hideWeekends: true,
        spacingMode: 'wide',
        timeDisplayMode: 'startOnly',
      );

      final restored = ThemeConfig.fromJson(original.toJson());

      expect(restored.version, original.version);
      expect(restored.seedColor, original.seedColor);
      expect(restored.backgroundColor, original.backgroundColor);
      expect(restored.unifiedCardColor, original.unifiedCardColor);
      expect(restored.useUnifiedCardColor, original.useUnifiedCardColor);
      expect(restored.themeMode, original.themeMode);
      expect(
        restored.courseCardTitleColorLight,
        original.courseCardTitleColorLight,
      );
      expect(
        restored.courseCardTitleColorDark,
        original.courseCardTitleColorDark,
      );
      expect(
        restored.courseCardDetailColorLight,
        original.courseCardDetailColorLight,
      );
      expect(
        restored.courseCardDetailColorDark,
        original.courseCardDetailColorDark,
      );
      expect(
        restored.weekdayBarFontColorLight,
        original.weekdayBarFontColorLight,
      );
      expect(
        restored.weekdayBarFontColorDark,
        original.weekdayBarFontColorDark,
      );
      expect(
        restored.weekdayBarAccentColorLight,
        original.weekdayBarAccentColorLight,
      );
      expect(
        restored.weekdayBarAccentColorDark,
        original.weekdayBarAccentColorDark,
      );
      expect(restored.timeAxisFontColorLight, original.timeAxisFontColorLight);
      expect(restored.timeAxisFontColorDark, original.timeAxisFontColorDark);
      expect(restored.linkCourseCardColors, original.linkCourseCardColors);
      expect(restored.hideWeekends, original.hideWeekends);
      expect(restored.spacingMode, original.spacingMode);
      expect(restored.timeDisplayMode, original.timeDisplayMode);
    });

    test('v1 compat parses correctly', () {
      final v1 = {
        'v': 1,
        'ccl': '#FFFFFF',
        'ccd': '#000000',
        'cdl': '#CCCCCC',
        'cdd': '#333333',
        'wbl': '#AAAAAA',
        'wbd': '#555555',
        'tal': '#BBBBBB',
        'tad': '#444444',
        'link': true,
      };

      final config = ThemeConfig.fromJson(v1);

      expect(config.version, 1);
      expect(config.courseCardTitleColorLight, '#FFFFFF');
      expect(config.courseCardTitleColorDark, '#000000');
      expect(config.courseCardDetailColorLight, '#CCCCCC');
      expect(config.courseCardDetailColorDark, '#333333');
      expect(config.weekdayBarFontColorLight, '#AAAAAA');
      expect(config.weekdayBarFontColorDark, '#555555');
      expect(config.timeAxisFontColorLight, '#BBBBBB');
      expect(config.timeAxisFontColorDark, '#444444');
      expect(config.linkCourseCardColors, true);
      // v1 不包含这些字段
      expect(config.seedColor, isNull);
      expect(config.backgroundColor, isNull);
      expect(config.weekdayBarAccentColorLight, isNull);
    });

    test('fromSettings -> applyToSettings is identity', () {
      final settings = TimetableSettings.defaults().copyWith(
        themeSeedColor: '#FF0000',
        timetablePageBackgroundColor: '#FFFFFF',
        courseCardTitleColorLight: '#111111',
        weekdayBarAccentColorLight: '#2563EB',
        weekdayBarAccentColorDark: '#93C5FD',
      );

      final config = ThemeConfig.fromSettings(settings);
      final restored = config.applyToSettings(settings);

      expect(restored.themeSeedColor, settings.themeSeedColor);
      expect(
        restored.timetablePageBackgroundColor,
        settings.timetablePageBackgroundColor,
      );
      expect(
        restored.courseCardTitleColorLight,
        settings.courseCardTitleColorLight,
      );
      expect(
        restored.weekdayBarAccentColorLight,
        settings.weekdayBarAccentColorLight,
      );
      expect(
        restored.weekdayBarAccentColorDark,
        settings.weekdayBarAccentColorDark,
      );
    });

    test('previewColors returns up to 4 colors', () {
      const config = ThemeConfig(
        seedColor: '#FF0000',
        courseCardTitleColorLight: '#00FF00',
        courseCardDetailColorLight: '#0000FF',
        weekdayBarFontColorLight: '#FFFF00',
        weekdayBarAccentColorLight: '#FF00FF',
      );

      final colors = config.previewColors;
      expect(colors.length, 4);
      expect(colors[0], '#FF0000');
      expect(colors[1], '#00FF00');
      expect(colors[2], '#0000FF');
      expect(colors[3], '#FFFF00');
    });
  });

  group('SavedTheme', () {
    test('roundtrip preserves config', () {
      final original = SavedTheme(
        id: '123',
        name: 'Test Theme',
        config: const ThemeConfig(
          seedColor: '#FF0000',
          weekdayBarAccentColorLight: '#2563EB',
        ),
        createdAt: DateTime(2024, 1, 1),
      );

      final restored = SavedTheme.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.config.seedColor, original.config.seedColor);
      expect(
        restored.config.weekdayBarAccentColorLight,
        original.config.weekdayBarAccentColorLight,
      );
      expect(restored.createdAt, original.createdAt);
    });

    test('themeData getter returns config toJson', () {
      final theme = SavedTheme(
        id: '123',
        name: 'Test',
        config: const ThemeConfig(seedColor: '#FF0000'),
        createdAt: DateTime.now(),
      );

      expect(theme.themeData, theme.config.toJson());
    });
  });

  group('hasThemeModifications', () {
    test('returns false when no checkpoint', () {
      final settings = TimetableSettings.defaults();
      expect(settings.themeCheckpointConfig, isNull);
      expect(settings.hasThemeModifications, isFalse);
    });

    test('returns false when settings match checkpoint', () {
      const checkpoint = ThemeConfig(
        seedColor: '#FF0000',
        backgroundColor: '#FFFFFF',
        courseCardTitleColorLight: '#111111',
      );

      final settings = TimetableSettings.defaults().copyWith(
        themeSeedColor: '#FF0000',
        timetablePageBackgroundColor: '#FFFFFF',
        courseCardTitleColorLight: '#111111',
        themeCheckpointName: 'Test Theme',
        themeCheckpointConfig: checkpoint,
      );

      expect(settings.hasThemeModifications, isFalse);
    });

    test('returns true when a checkpoint field is modified', () {
      const checkpoint = ThemeConfig(
        seedColor: '#FF0000',
        backgroundColor: '#FFFFFF',
      );

      final settings = TimetableSettings.defaults().copyWith(
        themeSeedColor: '#00FF00', // 修改了
        timetablePageBackgroundColor: '#FFFFFF',
        themeCheckpointName: 'Test Theme',
        themeCheckpointConfig: checkpoint,
      );

      expect(settings.hasThemeModifications, isTrue);
    });

    test('returns false when only non-checkpoint fields differ', () {
      // checkpoint 只设置 seedColor，其他字段为 null
      const checkpoint = ThemeConfig(seedColor: '#FF0000');

      final settings = TimetableSettings.defaults().copyWith(
        themeSeedColor: '#FF0000', // 与 checkpoint 一致
        courseCardTitleColorLight: '#999999', // checkpoint 中为 null，不应比较
        themeCheckpointName: 'Test Theme',
        themeCheckpointConfig: checkpoint,
      );

      expect(settings.hasThemeModifications, isFalse);
    });

    test('handles boolean fields correctly', () {
      const checkpoint = ThemeConfig(
        useUnifiedCardColor: true,
        linkCourseCardColors: true,
        hideWeekends: false,
      );

      final settingsUnmodified = TimetableSettings.defaults().copyWith(
        timetableUseUnifiedCardColor: true,
        linkCourseCardColors: true,
        timetableHideWeekends: false,
        themeCheckpointName: 'Test',
        themeCheckpointConfig: checkpoint,
      );

      final settingsModified = TimetableSettings.defaults().copyWith(
        timetableUseUnifiedCardColor: false, // 修改了
        linkCourseCardColors: true,
        timetableHideWeekends: false,
        themeCheckpointName: 'Test',
        themeCheckpointConfig: checkpoint,
      );

      expect(settingsUnmodified.hasThemeModifications, isFalse);
      expect(settingsModified.hasThemeModifications, isTrue);
    });
  });

  group('clearThemeCheckpoint', () {
    test('clears both checkpoint fields', () {
      final settings = TimetableSettings.defaults().copyWith(
        themeCheckpointName: 'Test Theme',
        themeCheckpointConfig: const ThemeConfig(seedColor: '#FF0000'),
      );

      expect(settings.themeCheckpointName, isNotNull);
      expect(settings.themeCheckpointConfig, isNotNull);

      final cleared = settings.copyWith(clearThemeCheckpoint: true);

      expect(cleared.themeCheckpointName, isNull);
      expect(cleared.themeCheckpointConfig, isNull);
    });

    test('preserves checkpoint when clearThemeCheckpoint is false', () {
      final settings = TimetableSettings.defaults().copyWith(
        themeCheckpointName: 'Test Theme',
        themeCheckpointConfig: const ThemeConfig(seedColor: '#FF0000'),
      );

      final preserved = settings.copyWith(clearThemeCheckpoint: false);

      expect(preserved.themeCheckpointName, 'Test Theme');
      expect(preserved.themeCheckpointConfig?.seedColor, '#FF0000');
    });

    test('clearThemeCheckpoint takes priority over provided values', () {
      final settings = TimetableSettings.defaults().copyWith(
        themeCheckpointName: 'Old Theme',
        themeCheckpointConfig: const ThemeConfig(seedColor: '#FF0000'),
      );

      // 即使传入新值，clearThemeCheckpoint: true 也会清空
      final cleared = settings.copyWith(
        clearThemeCheckpoint: true,
        themeCheckpointName: 'New Theme',
        themeCheckpointConfig: const ThemeConfig(seedColor: '#00FF00'),
      );

      expect(cleared.themeCheckpointName, isNull);
      expect(cleared.themeCheckpointConfig, isNull);
    });
  });

  group('themeCheckpoint serialization', () {
    test('roundtrip preserves checkpoint fields', () {
      const checkpoint = ThemeConfig(
        seedColor: '#FF0000',
        backgroundColor: '#FFFFFF',
        courseCardTitleColorLight: '#111111',
        weekdayBarAccentColorLight: '#2563EB',
      );

      final settings = TimetableSettings.defaults().copyWith(
        themeCheckpointName: 'Blue Theme',
        themeCheckpointConfig: checkpoint,
      );

      final restored = TimetableSettings.fromJson(settings.toJson());

      expect(restored.themeCheckpointName, 'Blue Theme');
      expect(restored.themeCheckpointConfig, isNotNull);
      expect(restored.themeCheckpointConfig!.seedColor, '#FF0000');
      expect(restored.themeCheckpointConfig!.backgroundColor, '#FFFFFF');
      expect(
        restored.themeCheckpointConfig!.courseCardTitleColorLight,
        '#111111',
      );
      expect(
        restored.themeCheckpointConfig!.weekdayBarAccentColorLight,
        '#2563EB',
      );
    });

    test('handles null checkpoint in JSON', () {
      final json = TimetableSettings.defaults().toJson();
      // 默认值没有 checkpoint 字段
      expect(json.containsKey('themeCheckpointName'), isFalse);
      expect(json.containsKey('themeCheckpointConfig'), isFalse);

      final restored = TimetableSettings.fromJson(json);
      expect(restored.themeCheckpointName, isNull);
      expect(restored.themeCheckpointConfig, isNull);
    });
  });

  test('home page background settings roundtrip in json', () {
    final settings = TimetableSettings.defaults().copyWith(
      homePageBackgroundFill: HomePageBackgroundFill.image,
      homePageBackgroundImagePath: '/tmp/home_bg.png',
      homePageWallpaperPath: '/tmp/wallpaper.png',
      homePageBackgroundScope:
          HomePageBackgroundScope.timetable | HomePageBackgroundScope.header,
    );

    final restored = TimetableSettings.fromJson(settings.toJson());
    expect(restored.homePageBackgroundFill, HomePageBackgroundFill.image);
    expect(restored.homePageBackgroundImagePath, '/tmp/home_bg.png');
    expect(restored.homePageWallpaperPath, '/tmp/wallpaper.png');
    expect(
      HomePageBackgroundScope.includes(
        restored.homePageBackgroundScope,
        HomePageBackgroundScope.timetable,
      ),
      isTrue,
    );
    expect(
      HomePageBackgroundScope.includes(
        restored.homePageBackgroundScope,
        HomePageBackgroundScope.header,
      ),
      isTrue,
    );
    expect(
      HomePageBackgroundScope.includes(
        restored.homePageBackgroundScope,
        HomePageBackgroundScope.weekdayBar,
      ),
      isFalse,
    );
  });

  group('home top menu style settings', () {
    test('defaults to list style with empty grid order', () {
      final settings = TimetableSettings.defaults();

      expect(settings.homeMenuStyle, HomeMenuStyle.list);
      expect(settings.homeGridMenuActions, isEmpty);
    });

    test('menu style roundtrips in json', () {
      final settings = TimetableSettings.defaults().copyWith(
        homeMenuStyle: HomeMenuStyle.grid,
        // copyWith 会补回钉住的「课表设置」。
        homeGridMenuActions: ['tasks', 'overview', 'addCourse'],
      );

      final restored = TimetableSettings.fromJson(settings.toJson());
      expect(restored.homeMenuStyle, HomeMenuStyle.grid);
      expect(restored.homeGridMenuActions, [
        'tasks',
        'overview',
        'addCourse',
        HomeGridMenu.pinnedActionId,
      ]);
    });

    test('grid order dedupes but leaves id validity to the ui layer', () {
      // 模型层只做结构归一（去重/截断/剔除非字符串）；未知 id 是否有效
      // 属于 UI 知识，由 resolveHomeGridMenuActions 在渲染时丢弃。
      final json = TimetableSettings.defaults().toJson()
        ..['homeGridMenuActions'] = [
          'overview',
          'bogus_action',
          'overview',
          'support',
        ];

      final restored = TimetableSettings.fromJson(json);
      expect(restored.homeGridMenuActions, [
        'overview',
        'bogus_action',
        'support',
        HomeGridMenu.pinnedActionId,
      ]);
    });

    test('grid order caps at max slots', () {
      final json = TimetableSettings.defaults().toJson()
        ..['homeGridMenuActions'] = [
          'update',
          'overview',
          'statistics',
          'addCourse',
          'exams',
          'importCourses',
          'tasks',
          'settings',
          'support',
        ];

      final restored = TimetableSettings.fromJson(json);
      expect(restored.homeGridMenuActions.length, HomeGridMenu.maxSlots);
      expect(restored.homeGridMenuActions.last, 'settings');
    });

    test('non-string entries are dropped', () {
      final json = TimetableSettings.defaults().toJson()
        ..['homeGridMenuActions'] = <Object?>['exams', 42, null, 'support'];

      final restored = TimetableSettings.fromJson(json);
      expect(restored.homeGridMenuActions, [
        'exams',
        'support',
        HomeGridMenu.pinnedActionId,
      ]);
    });

    test('settings entry is pinned back when missing', () {
      // 钉住「课表设置」是防呆：删光可达设置的入口后，用户就再也进不了
      // 自定义编辑器（先有鸡还是先有蛋）。解析路径强制补回。
      final json = TimetableSettings.defaults().toJson()
        ..['homeGridMenuActions'] = ['overview', 'tasks', 'support'];

      final restored = TimetableSettings.fromJson(json);
      expect(restored.homeGridMenuActions, [
        'overview',
        'tasks',
        'support',
        HomeGridMenu.pinnedActionId,
      ]);
    });

    test('pinned entry evicts the last slot when grid is full', () {
      // 满 8 个且没有 settings：挤掉末位补回钉住项，保证不超槽。
      final json = TimetableSettings.defaults().toJson()
        ..['homeGridMenuActions'] = [
          'update',
          'overview',
          'statistics',
          'addCourse',
          'exams',
          'importCourses',
          'tasks',
          'support',
        ];

      final restored = TimetableSettings.fromJson(json);
      expect(restored.homeGridMenuActions.length, HomeGridMenu.maxSlots);
      expect(restored.homeGridMenuActions.last, HomeGridMenu.pinnedActionId);
      // 满槽时被挤掉的是末位的 support——钉住项优先级高于普通条目。
      expect(restored.homeGridMenuActions.contains('support'), isFalse);
    });

    test('copyWith also enforces the pinned entry on write', () {
      final settings = TimetableSettings.defaults().copyWith(
        homeGridMenuActions: ['tasks'],
      );
      expect(settings.homeGridMenuActions, [
        'tasks',
        HomeGridMenu.pinnedActionId,
      ]);
    });
  });

  group('glass dock module tabs and extra button', () {
    test('defaults show all three tabs and add-course button action', () {
      final settings = TimetableSettings.defaults();

      expect(settings.glassDockShowDayTab, isTrue);
      expect(settings.glassDockShowWeekTab, isTrue);
      expect(settings.glassDockShowSettingsTab, isTrue);
      expect(settings.glassDockButtonEntryId, 'addCourse');
      expect(settings.glassDockShowAddButton, isFalse);
    });

    test('week tab toggle and button entry roundtrip in json', () {
      final settings = TimetableSettings.defaults().copyWith(
        glassDockShowWeekTab: false,
        glassDockButtonEntryId: 'exams',
        glassDockShowAddButton: false,
        glassDockButtonIconName: 'star',
      );

      final restored = TimetableSettings.fromJson(settings.toJson());
      expect(restored.glassDockShowWeekTab, isFalse);
      expect(restored.glassDockShowDayTab, isTrue);
      expect(restored.glassDockButtonEntryId, 'exams');
      expect(restored.glassDockShowAddButton, isFalse);
      expect(restored.glassDockButtonIconName, 'star');
    });

    test('missing json keys fall back to shipped defaults', () {
      final restored = TimetableSettings.fromJson(
        TimetableSettings.defaults().toJson()
          ..remove('glassDockShowWeekTab'),
      );
      expect(restored.glassDockShowWeekTab, isTrue);

      final restored2 = TimetableSettings.fromJson(
        TimetableSettings.defaults().toJson()
          ..remove('glassDockButtonEntryId'),
      );
      expect(restored2.glassDockButtonEntryId, 'addCourse');

      final restored3 = TimetableSettings.fromJson(
        TimetableSettings.defaults().toJson()
          ..remove('glassDockShowAddButton'),
      );
      expect(restored3.glassDockShowAddButton, isFalse);
    });
  });

  group('linked course-card text colors self-heal', () {
    // 回归：联动开但详情色与标题色不同的脏状态（旧版本数据 / 主题备份）会
    // 让卡面画出「白标题 + 黑简介」的混色卡；加载与写入路径都要回填。
    Map<String, dynamic> dirtyJson({required bool? link}) => {
      'sections': <dynamic>[],
      'courseCardTitleColorLight': '#FFFFFF',
      'courseCardTitleColorDark': '#EEEEEE',
      'courseCardDetailColorLight': '#000000',
      'courseCardDetailColorDark': '#111111',
      'linkCourseCardColors': ?link,
    };

    test('fromJson heals divergent detail colors while linked', () {
      final settings = TimetableSettings.fromJson(dirtyJson(link: true));
      expect(settings.courseCardDetailColorLight, settings.courseCardTitleColorLight);
      expect(settings.courseCardDetailColorDark, settings.courseCardTitleColorDark);
    });

    test('fromJson defaults to linked and heals legacy data without the key', () {
      final settings = TimetableSettings.fromJson(dirtyJson(link: null));
      expect(settings.linkCourseCardColors, isTrue);
      expect(settings.courseCardDetailColorLight, settings.courseCardTitleColorLight);
      expect(settings.courseCardDetailColorDark, settings.courseCardTitleColorDark);
    });

    test('fromJson keeps explicit detail colors in independent mode', () {
      final settings = TimetableSettings.fromJson(dirtyJson(link: false));
      expect(settings.courseCardTitleColorLight, '#FFFFFF');
      expect(settings.courseCardDetailColorLight, '#000000');
      expect(settings.courseCardDetailColorDark, '#111111');
    });

    test('healed state persists through a json round trip', () {
      final settings = TimetableSettings.fromJson(dirtyJson(link: true));
      final restored = TimetableSettings.fromJson(settings.toJson());
      expect(
        restored.courseCardDetailColorLight,
        restored.courseCardTitleColorLight,
      );
      expect(
        restored.courseCardDetailColorDark,
        restored.courseCardTitleColorDark,
      );
    });

    test('copyWith heals a divergent state even without changes', () {
      // 直达构造函数注入的脏状态（绕过 copyWith）在下一次写入时被回填。
      const dirty = TimetableSettings(
        sections: [],
        courseCardDetailColorLight: '#000000',
        courseCardDetailColorDark: '#111111',
      );
      expect(dirty.linkCourseCardColors, isTrue);
      final healed = dirty.copyWith();
      expect(healed.courseCardDetailColorLight, healed.courseCardTitleColorLight);
      expect(healed.courseCardDetailColorDark, healed.courseCardTitleColorDark);
    });

    test('copyWith syncs the detail color when the title changes while linked', () {
      final changed = TimetableSettings.defaults().copyWith(
        courseCardTitleColorLight: '#0D47A1',
      );
      expect(changed.courseCardTitleColorLight, '#0D47A1');
      expect(changed.courseCardDetailColorLight, '#0D47A1');
    });

    test('copyWith keeps user-picked detail colors in independent mode', () {
      final base = TimetableSettings.defaults().copyWith(
        linkCourseCardColors: false,
      );
      final changed = base.copyWith(courseCardDetailColorLight: '#123456');
      expect(changed.courseCardDetailColorLight, '#123456');
      expect(changed.courseCardTitleColorLight, '#FFFFFF');
    });

    test('applyToSettings heals a corrupt linked theme config', () {
      const config = ThemeConfig(
        courseCardTitleColorLight: '#FFFFFF',
        courseCardDetailColorLight: '#000000',
        linkCourseCardColors: true,
      );
      final applied = config.applyToSettings(TimetableSettings.defaults());
      expect(
        applied.courseCardDetailColorLight,
        applied.courseCardTitleColorLight,
      );
    });
  });
}
