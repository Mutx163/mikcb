import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/timetable_persist_hooks.dart';

/// 假端口：只提供落盘钩子需要的三样东西。
class _FakePort implements TimetablePersistPort {
  _FakePort({
    required this.settings,
    this.courses = const <Course>[],
    this.currentWeek = 3,
  });

  @override
  TimetableSettings settings;

  @override
  final List<Course> courses;

  @override
  final int currentWeek;
}

Course _course(String id) => Course(
  id: id,
  name: '课程$id',
  teacher: '张老师',
  location: 'A101',
  dayOfWeek: 1,
  startSection: 1,
  endSection: 1,
  startTime: '08:00',
  endTime: '08:45',
);

void main() {
  late int notifyCalls;
  late List<Map<String, Object?>> refreshCalls;

  setUp(() {
    notifyCalls = 0;
    refreshCalls = <Map<String, Object?>>[];
  });

  Future<bool> fakeRefresh({
    required String localeTag,
    required List<Course> allCourses,
    required int currentWeek,
    required int semesterWeekCount,
  }) async {
    refreshCalls.add(<String, Object?>{
      'localeTag': localeTag,
      'courseIds': allCourses.map((course) => course.id).toList(),
      'currentWeek': currentWeek,
      'semesterWeekCount': semesterWeekCount,
    });
    return true;
  }

  TimetableSettings enabledSettings() => TimetableSettings.defaults().copyWith(
    weeklyReportEnabled: true,
    appLocaleTag: 'zh',
    semesterWeekCount: 20,
  );

  test('notifySync=false：补偿写 / 回滚不通知、不重推', () {
    final port = _FakePort(settings: enabledSettings());

    TimetablePersistHooks.afterProfilePersisted(
      port,
      notifySync: false,
      notifySyncHook: () => notifyCalls++,
      refreshWeeklyReport: fakeRefresh,
    );

    expect(notifyCalls, 0);
    expect(refreshCalls, isEmpty);
  });

  test('notifySync=true 但周报关闭：只通知同步层', () {
    final port = _FakePort(
      settings: TimetableSettings.defaults().copyWith(
        weeklyReportEnabled: false,
      ),
    );

    TimetablePersistHooks.afterProfilePersisted(
      port,
      notifySync: true,
      notifySyncHook: () => notifyCalls++,
      refreshWeeklyReport: fakeRefresh,
    );

    expect(notifyCalls, 1);
    expect(refreshCalls, isEmpty);
  });

  test('周报开启：用当前设置 / 课程 / 周次重推一次', () {
    final port = _FakePort(
      settings: enabledSettings(),
      courses: <Course>[_course('c1'), _course('c2')],
      currentWeek: 7,
    );

    TimetablePersistHooks.afterProfilePersisted(
      port,
      notifySync: true,
      notifySyncHook: () => notifyCalls++,
      refreshWeeklyReport: fakeRefresh,
    );

    expect(notifyCalls, 1);
    expect(refreshCalls, hasLength(1));
    expect(refreshCalls.single, <String, Object?>{
      'localeTag': 'zh',
      'courseIds': <String>['c1', 'c2'],
      'currentWeek': 7,
      'semesterWeekCount': 20,
    });
  });
}
