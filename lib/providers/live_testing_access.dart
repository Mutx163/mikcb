import '../models/course.dart';
import '../models/timetable_settings.dart';
import '../services/live_testing_fixture_service.dart';
import '../services/live_testing_trigger.dart';
import 'live_testing_fixture_access.dart';
import 'timetable_provider.dart';

/// [LiveTestingTriggerHost] 的宿主适配器：把 [TimetableProvider] 的公开面
/// 以窄端口交给超级岛触发管线（`lib/services/live_testing_trigger.dart`）。
///
/// 服务在 providers 下层，不能反向 import 本文件；端口抽象由服务自己定义，
/// 本适配器住 providers 层（providers → services 是合法方向），由调用点
/// （live_settings_subpages、live_testing_fixture_screen、settings_live、
/// 测试）构造注入。[fixtureHost] 用同一份 provider 组装夹具适配器——
/// 与改前「同一个 provider 对象传给夹具」等价。
class LiveTestingProviderAccess implements LiveTestingTriggerHost {
  LiveTestingProviderAccess(this._provider);

  final TimetableProvider _provider;

  @override
  LiveTestingFixtureHost get fixtureHost => LiveFixtureProviderAccess(_provider);

  @override
  Future<void> initialize() => _provider.initialize();

  @override
  List<Course> get courses => _provider.courses;

  @override
  TimetableSettings get settings => _provider.settings;

  @override
  int get currentWeek => _provider.currentWeek;

  @override
  int get liveSelectionCalendarWeek => _provider.liveSelectionCalendarWeek;

  @override
  bool get hasLiveTestFixtureCourses => _provider.hasLiveTestFixtureCourses;

  @override
  bool isHoliday(DateTime date) => _provider.isHoliday(date);

  @override
  Course resolveCourseDisplayName(Course course) =>
      _provider.resolveCourseDisplayName(course);

  @override
  List<Course> getActiveCoursesForDay(int dayOfWeek, {int? week}) =>
      _provider.getActiveCoursesForDay(dayOfWeek, week: week);

  @override
  LiveActivityCourseSelection? getLiveActivityCourseSelection({
    DateTime? now,
    bool allowUpcomingFallback = false,
    int? week,
  }) => _provider.getLiveActivityCourseSelection(
    now: now,
    allowUpcomingFallback: allowUpcomingFallback,
    week: week,
  );

  @override
  List<Map<String, dynamic>> buildLiveProgressMilestones(
    Course course, {
    int? startAtMillis,
    int? endAtMillis,
  }) => _provider.buildLiveProgressMilestones(
    course,
    startAtMillis: startAtMillis,
    endAtMillis: endAtMillis,
  );

  @override
  List<int> buildLiveProgressBreakOffsetsMillis(
    Course course, {
    int? startAtMillis,
    int? endAtMillis,
  }) => _provider.buildLiveProgressBreakOffsetsMillis(
    course,
    startAtMillis: startAtMillis,
    endAtMillis: endAtMillis,
  );

  @override
  void armLiveTestFixtureCourses(List<Course> courses) =>
      _provider.armLiveTestFixtureCourses(courses);

  @override
  void suspendLiveActivitySyncFor(Duration duration) =>
      _provider.suspendLiveActivitySyncFor(duration);

  @override
  void clearLiveActivitySyncSuspend() =>
      _provider.clearLiveActivitySyncSuspend();

  @override
  Future<void> refreshLiveActivityNow({bool forceSnapshotSync = false}) =>
      _provider.refreshLiveActivityNow(forceSnapshotSync: forceSnapshotSync);
}
