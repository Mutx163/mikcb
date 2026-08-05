import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/lan_edit_provider_host.dart';
import 'package:university_timetable/services/transfer_package.dart';

Course buildTestCourse({required String id, required String color}) {
  return Course(
    id: id,
    name: '测试课程',
    teacher: '',
    location: '',
    dayOfWeek: 1,
    startSection: 1,
    endSection: 1,
    startTime: '08:00',
    endTime: '08:45',
    color: color,
  );
}

void main() {
  test('LAN API colors accept only six-digit hex values', () {
    expect(LanEditProviderHost.normalizeLanCourseColor(' #aBc123 '), '#ABC123');
    expect(
      LanEditProviderHost.normalizeLanCourseColor('red" onmouseover="alert(1)'),
      LanEditProviderHost.defaultLanCourseColor,
    );
    expect(
      LanEditProviderHost.normalizeLanCourseColor('rgb(255, 0, 0)'),
      LanEditProviderHost.defaultLanCourseColor,
    );
  });

  test('courseFromApiJson removes unsafe colors before persistence', () {
    final settings = TimetableSettings.defaults();
    final course = LanEditProviderHost.courseFromApiJson(
      {'name': '测试课程', 'color': 'red" onmouseover="alert(1)'},
      sections: settings.sections,
      semesterWeekCount: settings.semesterWeekCount,
    );

    expect(course.color, LanEditProviderHost.defaultLanCourseColor);
  });

  test('transfer normalization covers top-level and profile courses', () {
    final profile = TimetableProfile(
      id: 'profile-a',
      name: '测试课表',
      courses: [
        buildTestCourse(
          id: 'profile-course',
          color: 'red" onmouseover="alert(1)',
        ),
      ],
      settings: TimetableSettings.defaults(),
      currentWeek: 1,
      createdAt: DateTime(2026),
      lastUsedAt: DateTime(2026),
    );
    final package = TransferPackage(
      packageId: 'transfer-test',
      scope: TransferScope.currentTimetable,
      courses: [
        buildTestCourse(
          id: 'top-level-course',
          color: 'red" onmouseover="alert(1)',
        ),
      ],
      profiles: [profile],
    );

    final normalizedPackage = LanEditProviderHost.normalizeTransferCourseColors(
      package,
    );

    expect(
      normalizedPackage.courses.single.color,
      LanEditProviderHost.defaultLanCourseColor,
    );
    expect(
      normalizedPackage.profiles.single.courses.single.color,
      LanEditProviderHost.defaultLanCourseColor,
    );
  });
}
