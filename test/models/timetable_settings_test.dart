import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';

void main() {
  test('defaults include semester week count and preserve it in json', () {
    final settings = TimetableSettings.defaults();

    expect(settings.semesterWeekCount, 20);
    expect(settings.showConflictBadgeOnTimetable, isTrue);
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
    expect(settings.liveEnableMiuiIslandLabelImage, isFalse);
    expect(settings.liveHideFromRecents, isFalse);
    expect(settings.liveEnableLocalDiagnostics, isFalse);
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
    expect(settings.appUpdateIncludePrerelease, isFalse);
    expect(
      settings.courseCardVerticalAlign,
      CourseCardVerticalAlign.center,
    );
    expect(
      settings.courseCardHorizontalAlign,
      CourseCardHorizontalAlign.center,
    );

    final restored = TimetableSettings.fromJson(settings.toJson());
    expect(restored.semesterWeekCount, 20);
    expect(restored.showConflictBadgeOnTimetable, isTrue);
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
    expect(restored.liveEnableMiuiIslandLabelImage, isFalse);
    expect(restored.liveHideFromRecents, isFalse);
    expect(restored.liveEnableLocalDiagnostics, isFalse);
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
    expect(restored.appUpdateIncludePrerelease, isFalse);
    expect(
      restored.courseCardVerticalAlign,
      CourseCardVerticalAlign.center,
    );
    expect(
      restored.courseCardHorizontalAlign,
      CourseCardHorizontalAlign.center,
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
      showConflictBadgeOnTimetable: false,
      timetableAutoFitSectionHeight: true,
      courseCardShowTime: true,
      courseCardShowTimeLabels: false,
      courseCardShowWeeks: true,
      widgetBackgroundStyle: WidgetBackgroundStyle.gradient,
      widgetShowLocation: false,
      widgetShowCountdown: false,
      courseCardVerticalAlign: CourseCardVerticalAlign.spaceEvenly,
      courseCardHorizontalAlign: CourseCardHorizontalAlign.right,
      timetableSectionTimeDisplayMode: SectionTimeDisplayMode.startAndEnd,
      timetableHideWeekends: true,
      enableHaptics: false,
      liveDuringClassTimeDisplayMode: LiveDuringClassTimeDisplayMode.total,
      liveEnableMiuiIslandLabelImage: true,
      liveHideFromRecents: true,
      liveEnableLocalDiagnostics: true,
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
      appUpdateIncludePrerelease: true,
    );

    final restored = TimetableSettings.fromJson(settings.toJson());

    expect(restored.activeTimeSchemeId, 'scheme-1');
    expect(restored.showConflictBadgeOnTimetable, isFalse);
    expect(restored.timetableAutoFitSectionHeight, isTrue);
    expect(restored.courseCardShowTime, isTrue);
    expect(restored.courseCardShowTimeLabels, isFalse);
    expect(restored.courseCardShowWeeks, isTrue);
    expect(restored.widgetBackgroundStyle, WidgetBackgroundStyle.gradient);
    expect(restored.widgetShowLocation, isFalse);
    expect(restored.widgetShowCountdown, isFalse);
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
    expect(restored.liveEnableMiuiIslandLabelImage, isTrue);
    expect(restored.liveHideFromRecents, isTrue);
    expect(restored.liveEnableLocalDiagnostics, isTrue);
    expect(restored.liveShowStageText, isFalse);
    expect(
      restored.liveMiuiIslandLabelStyle,
      MiuiIslandLabelStyle.iconAndText,
    );
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
    expect(restored.appUpdateIncludePrerelease, isTrue);
    expect(
      restored.courseCardVerticalAlign,
      CourseCardVerticalAlign.spaceEvenly,
    );
    expect(
      restored.courseCardHorizontalAlign,
      CourseCardHorizontalAlign.right,
    );
  });
}
