import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/providers/timetable_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<TimetableProvider> createProvider() async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        semesterStartDate: DateTime(2026, 4, 13),
        semesterWeekCount: 20,
      ),
    );
    return provider;
  }

  test('getCourseInProgress returns current course for explicit day and week',
      () async {
    final provider = await createProvider();
    await provider.addCourse(
      Course(
        id: 'course-now',
        name: '高等数学',
        teacher: '张老师',
        location: 'A101',
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
      ),
    );

    final course = provider.getCourseInProgress(
      dayOfWeek: 1,
      week: 1,
      now: DateTime(2026, 4, 13, 8, 30),
    );

    expect(course?.name, '高等数学');
  });

  test('getCourseInProgress returns null before class starts', () async {
    final provider = await createProvider();
    await provider.addCourse(
      Course(
        id: 'course-later',
        name: '大学英语',
        teacher: '李老师',
        location: 'B202',
        dayOfWeek: 1,
        startSection: 3,
        endSection: 4,
        startTime: '10:00',
        endTime: '11:40',
      ),
    );

    final course = provider.getCourseInProgress(
      dayOfWeek: 1,
      week: 1,
      now: DateTime(2026, 4, 13, 9, 20),
    );

    expect(course, isNull);
  });

  test('getCourseInProgress does not match another weekday', () async {
    final provider = await createProvider();
    await provider.addCourse(
      Course(
        id: 'course-monday',
        name: '软件工程',
        teacher: '王老师',
        location: 'C303',
        dayOfWeek: 1,
        startSection: 5,
        endSection: 6,
        startTime: '14:00',
        endTime: '15:40',
      ),
    );

    final course = provider.getCourseInProgress(
      dayOfWeek: 2,
      week: 1,
      now: DateTime(2026, 4, 13, 14, 20),
    );

    expect(course, isNull);
  });
}
