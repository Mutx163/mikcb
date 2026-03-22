import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('switching active profile updates exposed timetable state', () async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();

    final spring = await provider.createProfile(name: '春季课表');
    await provider.addCourse(
      Course(
        id: 'spring-course',
        name: '高数',
        teacher: '张老师',
        location: 'A101',
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
      ),
    );

    final autumn = await provider.createProfile(name: '秋季课表');
    await provider.switchProfile(autumn.id);
    await provider.addCourse(
      Course(
        id: 'autumn-course',
        name: '线代',
        teacher: '王老师',
        location: 'C202',
        dayOfWeek: 3,
        startSection: 5,
        endSection: 6,
        startTime: '14:00',
        endTime: '15:40',
      ),
    );
    await provider.setCurrentWeek(8);

    await provider.switchProfile(spring.id);

    expect(provider.activeProfile?.name, '春季课表');
    expect(provider.courses.single.name, '高数');
    expect(provider.currentWeek, 1);

    await provider.switchProfile(autumn.id);
    expect(provider.courses.single.name, '线代');
    expect(provider.currentWeek, 8);
  });

  test('clearing active profile removes only courses and preserves settings',
      () async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();

    await provider.updateTimetableSettings(
      TimetableSettings.defaults().copyWith(
        semesterWeekCount: 24,
        semesterStartDate: DateTime(2026, 2, 23),
      ),
    );
    await provider.setCurrentWeek(6);
    await provider.addCourse(
      Course(
        id: 'course-1',
        name: '数据库',
        teacher: '李老师',
        location: 'B301',
        dayOfWeek: 2,
        startSection: 3,
        endSection: 4,
        startTime: '10:10',
        endTime: '11:50',
      ),
    );

    final cleared = await provider.clearActiveProfileCourses();

    expect(cleared, isTrue);
    expect(provider.courses, isEmpty);
    expect(provider.currentWeek, 6);
    expect(provider.settings.semesterWeekCount, 24);
    expect(provider.settings.semesterStartDate, DateTime(2026, 2, 23));
    expect(provider.activeProfile?.name, '默认课表');
  });
}
