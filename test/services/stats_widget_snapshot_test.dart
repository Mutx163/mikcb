import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/services/statistics_service.dart';
import 'package:university_timetable/services/stats_widget_service.dart';

Course _course({
  required String id,
  required String name,
  required int dayOfWeek,
  required int startSection,
  required int endSection,
}) {
  return Course(
    id: id,
    name: name,
    teacher: '张老师',
    location: 'A101',
    dayOfWeek: dayOfWeek,
    startSection: startSection,
    endSection: endSection,
    startTime: '08:00',
    endTime: '09:35',
  );
}

void main() {
  const channel = MethodChannel('com.mutx163.qingyu/home_widget');

  late List<MethodCall> pushed;

  setUp(() {
    pushed = [];
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'syncStatsSnapshot') {
            pushed.add(call);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('无课时不构建快照', () {
    expect(
      StatsWidgetSnapshot.fromCourses(
        courses: const [],
        currentWeek: 3,
        semesterWeekCount: 20,
        profileName: '默认课表',
      ),
      isNull,
    );
  });

  test('快照口径与统计服务逐项一致', () {
    final courses = [
      _course(
        id: 'math',
        name: '高等数学',
        dayOfWeek: DateTime.monday,
        startSection: 1,
        endSection: 2,
      ),
      _course(
        id: 'english',
        name: '大学英语',
        dayOfWeek: DateTime.tuesday,
        startSection: 3,
        endSection: 4,
      ),
    ];
    const currentWeek = 3;
    const semesterWeekCount = 20;

    final snapshot = StatsWidgetSnapshot.fromCourses(
      courses: courses,
      currentWeek: currentWeek,
      semesterWeekCount: semesterWeekCount,
      profileName: '默认课表',
    )!;
    final weekStats = StatisticsService.calculate(
      allCourses: courses,
      week: currentWeek,
    );
    final semesterStats = StatisticsService.calculateSemester(
      allCourses: courses,
      currentWeek: currentWeek,
      semesterWeekCount: semesterWeekCount,
    );
    final progress = StatisticsService.calculateSemesterProgress(
      allCourses: courses,
      currentWeek: currentWeek,
      semesterWeekCount: semesterWeekCount,
    );
    final comparison = StatisticsService.calculateWeeklyComparison(
      allCourses: courses,
      currentWeek: currentWeek,
      semesterWeekCount: semesterWeekCount,
    );

    expect(snapshot.profileName, '默认课表');
    expect(snapshot.currentWeek, currentWeek);
    expect(snapshot.weekSections, weekStats.totalSections);
    expect(snapshot.weekCourseCount, weekStats.totalCourses);
    expect(snapshot.deltaVsLastWeek, comparison.deltaVsLastWeek);
    expect(snapshot.semesterDone, semesterStats.totalSections);
    expect(snapshot.semesterTotal, progress.sectionsTotal);
    expect(snapshot.requiredCount, semesterStats.natureStats.requiredCount);
    expect(snapshot.electiveCount, semesterStats.natureStats.electiveCount);
    expect(snapshot.longestStreak, semesterStats.longestStreak);
  });

  test('重复同步同一份快照只推送一次', () async {
    const snapshot = StatsWidgetSnapshot(
      profileName: '默认课表',
      currentWeek: 3,
      weekSections: 4,
      weekCourseCount: 2,
      deltaVsLastWeek: 0,
      semesterDone: 12,
      semesterTotal: 80,
      requiredCount: 2,
      electiveCount: 0,
      longestStreak: 2,
    );

    await StatsWidgetService.syncSnapshot(snapshot);
    await StatsWidgetService.syncSnapshot(snapshot);
    expect(pushed.length, 1);

    // 内容变化必须重新推送。
    await StatsWidgetService.syncSnapshot(
      StatsWidgetSnapshot(
        profileName: snapshot.profileName,
        currentWeek: snapshot.currentWeek,
        weekSections: snapshot.weekSections,
        weekCourseCount: snapshot.weekCourseCount,
        deltaVsLastWeek: snapshot.deltaVsLastWeek,
        semesterDone: snapshot.semesterDone,
        semesterTotal: snapshot.semesterTotal,
        requiredCount: snapshot.requiredCount,
        electiveCount: snapshot.electiveCount,
        longestStreak: 3,
      ),
    );
    expect(pushed.length, 2);

    // 清空后再次同步同一份内容也要真正推送，而不是被去重吞掉。
    await StatsWidgetService.clearSnapshot();
    await StatsWidgetService.syncSnapshot(
      StatsWidgetSnapshot(
        profileName: snapshot.profileName,
        currentWeek: snapshot.currentWeek,
        weekSections: snapshot.weekSections,
        weekCourseCount: snapshot.weekCourseCount,
        deltaVsLastWeek: snapshot.deltaVsLastWeek,
        semesterDone: snapshot.semesterDone,
        semesterTotal: snapshot.semesterTotal,
        requiredCount: snapshot.requiredCount,
        electiveCount: snapshot.electiveCount,
        longestStreak: 3,
      ),
    );
    expect(pushed.length, 3);
  });
}
