import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/lan_edit_provider_host.dart';
import 'package:university_timetable/services/storage_service.dart';
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

Course buildScheduleSlot({
  required String id,
  required String name,
  required String teacher,
  int dayOfWeek = 1,
}) {
  return Course(
    id: id,
    name: name,
    teacher: teacher,
    location: 'A101',
    dayOfWeek: dayOfWeek,
    startSection: 1,
    endSection: 2,
    startTime: '08:00',
    endTime: '09:40',
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

  test('LAN replaceCourseGroup keeps each slot teacher on create', () async {
    SharedPreferences.setMockInitialValues({});
    StorageService().resetForTesting();
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    final host = LanEditProviderHost(provider);

    final created = await host.replaceCourseGroup(
      originalName: null,
      slots: [
        buildScheduleSlot(
          id: 'lan-a',
          name: '高等数学',
          teacher: '张老师',
        ),
        buildScheduleSlot(
          id: 'lan-b',
          name: '高等数学',
          teacher: '李老师',
          dayOfWeek: 3,
        ),
      ],
    );

    expect(created, hasLength(2));
    final byId = {for (final c in provider.courses) c.id: c};
    expect(byId['lan-a']!.teacher, '张老师');
    expect(byId['lan-b']!.teacher, '李老师');
  });

  test('LAN replaceGroup keeps each slot teacher on update', () async {
    SharedPreferences.setMockInitialValues({});
    StorageService().resetForTesting();
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    await provider.addCourse(
      buildScheduleSlot(id: 'old', name: '离散数学', teacher: '旧老师'),
    );
    final host = LanEditProviderHost(provider);

    final replaced = await host.replaceCourseGroup(
      originalName: '离散数学',
      slots: [
        buildScheduleSlot(
          id: 'replaced-a',
          name: '离散数学',
          teacher: '张老师',
        ),
        buildScheduleSlot(
          id: 'replaced-b',
          name: '离散数学',
          teacher: '李老师',
          dayOfWeek: 3,
        ),
      ],
    );

    expect(replaced, hasLength(2));
    final byId = {for (final c in provider.courses) c.id: c};
    expect(byId['replaced-a']!.teacher, '张老师');
    expect(byId['replaced-b']!.teacher, '李老师');
  });
}
