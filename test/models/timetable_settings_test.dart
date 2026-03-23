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
    expect(settings.liveMiuiIslandLabelStyle, MiuiIslandLabelStyle.textOnly);
    expect(
      settings.liveMiuiIslandLabelContent,
      MiuiIslandLabelContent.courseName,
    );
    expect(settings.liveMiuiIslandLabelFontSize, 14);
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
    expect(restored.liveMiuiIslandLabelStyle, MiuiIslandLabelStyle.textOnly);
    expect(
      restored.liveMiuiIslandLabelContent,
      MiuiIslandLabelContent.courseName,
    );
    expect(restored.liveMiuiIslandLabelFontSize, 14);
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
      courseCardVerticalAlign: CourseCardVerticalAlign.spaceEvenly,
      courseCardHorizontalAlign: CourseCardHorizontalAlign.right,
      timetableSectionTimeDisplayMode: SectionTimeDisplayMode.startAndEnd,
      timetableHideWeekends: true,
      enableHaptics: false,
      liveDuringClassTimeDisplayMode: LiveDuringClassTimeDisplayMode.total,
      liveEnableMiuiIslandLabelImage: true,
      liveMiuiIslandLabelStyle: MiuiIslandLabelStyle.iconAndText,
      liveMiuiIslandLabelContent: MiuiIslandLabelContent.courseNameAndLocation,
      liveMiuiIslandLabelFontSize: 18,
    );

    final restored = TimetableSettings.fromJson(settings.toJson());

    expect(restored.activeTimeSchemeId, 'scheme-1');
    expect(restored.showConflictBadgeOnTimetable, isFalse);
    expect(restored.timetableAutoFitSectionHeight, isTrue);
    expect(restored.courseCardShowTime, isTrue);
    expect(restored.courseCardShowTimeLabels, isFalse);
    expect(restored.courseCardShowWeeks, isTrue);
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
    expect(
      restored.liveMiuiIslandLabelStyle,
      MiuiIslandLabelStyle.iconAndText,
    );
    expect(
      restored.liveMiuiIslandLabelContent,
      MiuiIslandLabelContent.courseNameAndLocation,
    );
    expect(restored.liveMiuiIslandLabelFontSize, 18);
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
