import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/domain/week_calculator.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
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

  test(
    'getCourseInProgress returns current course for explicit day and week',
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
    },
  );

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

  test(
    'syncTemporalContext preserves viewed week while refreshing today courses',
    () async {
      final provider = await createProvider();
      await provider.addCourse(
        Course(
          id: 'course-mon',
          name: '周一课程',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: 1,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
        ),
      );
      await provider.addCourse(
        Course(
          id: 'course-tue',
          name: '周二课程',
          teacher: '李老师',
          location: 'B202',
          dayOfWeek: 2,
          startSection: 3,
          endSection: 4,
          startTime: '10:00',
          endTime: '11:40',
        ),
      );

      // 「当前周」口径（2026-08-31）：激活（含改开学时间）即按真实今天
      // 对齐到该课表的日历周（钳制在学期周数内）。syncTemporalContext(now:)
      // 模拟历史时刻时只刷新"今天"相关状态，不回写 currentWeek——
      // 它必须继续保住浏览位置，不能把翻页器拽走。
      final alignedAtActivation = clampCurrentWeekToSettings(
        WeekCalculator.calendarWeekForDate(
          DateTime.now(),
          semesterStart: DateTime(2026, 4, 13),
          fallback: 1,
        ),
        provider.settings,
      );
      expect(provider.currentWeek, alignedAtActivation);

      final monday = DateTime(2026, 4, 13, 8, 30);
      await provider.syncTemporalContext(now: monday);
      expect(provider.currentWeek, alignedAtActivation);
      expect(provider.currentDateWeek, 1);
      expect(provider.currentDayOfWeek, 1);
      expect(
        provider.getTodayCourses(now: monday).map((course) => course.name),
        ['周一课程'],
      );

      await provider.setCurrentWeek(6);
      final tuesday = DateTime(2026, 4, 21, 8, 30);
      await provider.syncTemporalContext(now: tuesday);
      expect(provider.currentWeek, 6);
      expect(provider.currentDateWeek, 2);
      expect(provider.currentDayOfWeek, 2);
      expect(
        provider.getTodayCourses(now: tuesday).map((course) => course.name),
        ['周二课程'],
      );
    },
  );
}
