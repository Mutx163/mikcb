import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/live_activity_logic.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/exam.dart';
import 'package:university_timetable/models/holiday_entry.dart';
import 'package:university_timetable/models/partner_timetable_binding.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/home_widget_binding_service.dart';
import 'package:university_timetable/services/home_widget_service.dart';
import 'package:university_timetable/services/home_widget_snapshot_service.dart';
import 'package:university_timetable/services/miui_live_activities_service.dart';
import 'package:university_timetable/services/timetable_live_activity_service.dart';

const _defaultSections = [
  SectionTime(startTime: '08:00', endTime: '09:40'),
];

TimetableSettings buildSettings({
  List<SectionTime> sections = _defaultSections,
  bool enableBeforeClass = true,
  int showBeforeClassMinutes = 20,
  int timeCorrectionSeconds = 0,
  DateTime? semesterStartDate,
}) {
  return TimetableSettings(
    sections: sections,
    semesterStartDate: semesterStartDate,
    liveEnableBeforeClass: enableBeforeClass,
    liveShowBeforeClassMinutes: showBeforeClassMinutes,
    liveTimeCorrectionSeconds: timeCorrectionSeconds,
  );
}

Course buildCourse({
  String id = 'course-1',
  String name = '高等数学',
  int dayOfWeek = 1,
  int startSection = 1,
  int endSection = 2,
  String startTime = '08:00',
  String endTime = '09:40',
  int startWeek = 1,
  int endWeek = 16,
}) {
  return Course(
    id: id,
    name: name,
    teacher: '张老师',
    location: 'A101',
    dayOfWeek: dayOfWeek,
    startSection: startSection,
    endSection: endSection,
    startTime: startTime,
    endTime: endTime,
    startWeek: startWeek,
    endWeek: endWeek,
  );
}

Course fixtureCourse({
  String id = 'live_test_1',
  String startTime = '08:00',
  String endTime = '09:40',
  int dayOfWeek = 1,
}) {
  return buildCourse(
    id: id,
    name: '自检课',
    dayOfWeek: dayOfWeek,
    startTime: startTime,
    endTime: endTime,
  );
}

/// 假端口：只实现被测路径真正会读的那些成员；原生面服务一旦被碰到就抛错，
/// 让「测试没覆盖到原生推送」这件事立刻暴露，而不是静默通过。
class _FakePort implements TimetableLiveActivityPort {
  _FakePort({
    TimetableSettings? settings,
    List<Course>? courses,
    this.holiday,
  }) : settings = settings ?? buildSettings(),
       courses = courses ?? const [];

  @override
  final LiveActivityRuntimeState liveRuntime = LiveActivityRuntimeState();

  @override
  TimetableSettings settings;

  @override
  List<Course> courses;

  final HolidayData? holiday;

  int resolveDisplayNameCalls = 0;

  @override
  bool get enableLiveActivitySync => true;

  @override
  String? get currentLiveCourseId => liveRuntime.lastActivityStageKey;

  @override
  set currentLiveCourseId(String? value) =>
      liveRuntime.lastActivityStageKey = value;

  @override
  HolidayData? get holidayData => holiday;

  @override
  List<TimetableProfile> get profiles => const [];

  @override
  TimetableProfile? get activeProfile => null;

  @override
  PartnerTimetableBinding? get partnerBinding => null;

  @override
  bool get hasPartnerBinding => false;

  @override
  TimetableProfile? get partnerProfile => null;

  @override
  int get currentWeek => 1;

  @override
  int currentDateWeek = 1;

  @override
  int currentDayOfWeek = 1;

  /// 假端口返回的「今天属于哪个日历周」。
  int calendarWeek = 1;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> syncTemporalContext({DateTime? now}) async => true;

  @override
  bool isHoliday(DateTime date) => holiday?.isHoliday(date) ?? false;

  @override
  bool isAdjustedWorkday(DateTime date) =>
      holiday?.isAdjustedWorkday(date) ?? false;

  @override
  HolidayEntry? getHolidayForDate(DateTime date) =>
      holiday?.entryForDate(date);

  @override
  List<Course> getActiveCoursesForDay(int dayOfWeek, {int? week}) =>
      getCoursesForDay(dayOfWeek, week: week);

  @override
  List<Course> getCoursesForDay(int dayOfWeek, {int? week}) => courses
      .where((course) => course.dayOfWeek == dayOfWeek)
      .where((course) => week == null || course.isActiveInWeek(week))
      .toList(growable: false);

  @override
  Exam? getNextExam() => null;

  /// 模拟展示名归一：加个后缀，用来断言服务返回的是**归一后**的课。
  @override
  Course resolveCourseDisplayName(Course course) {
    resolveDisplayNameCalls++;
    return course.copyWith(name: '${course.name}(归一名)');
  }

  @override
  int calculateCalendarWeekForDate(DateTime date, {int? fallbackWeek}) =>
      calendarWeek;

  @override
  bool isLiveTestingFixture(Course course) =>
      course.id.startsWith('live_test_');

  @override
  List<SectionTime>? resolveSectionsForCourse(
    Course course, {
    TimetableSettings? settings,
    DateTime? onDate,
  }) => settings?.sections ?? this.settings.sections;

  @override
  Future<T> runLiveSurfaceExclusive<T>(Future<T> Function() action) =>
      action();

  @override
  void notifyStateChanged() {}

  @override
  MiuiLiveActivitiesService get liveActivitiesService =>
      throw UnimplementedError('原生面不在本测试范围');

  @override
  HomeWidgetService get homeWidgetService =>
      throw UnimplementedError('原生面不在本测试范围');

  @override
  HomeWidgetSnapshotService get homeWidgetSnapshotService =>
      throw UnimplementedError('原生面不在本测试范围');

  @override
  HomeWidgetBindingService get homeWidgetBindingService =>
      throw UnimplementedError('原生面不在本测试范围');
}

void main() {
  group('resolveRealTime', () {
    test('自检预设课用自身自由时钟，不被作息模板群覆盖', () {
      final port = _FakePort(
        settings: buildSettings(
          sections: const [SectionTime(startTime: '10:00', endTime: '10:45')],
        ),
      );
      final fixture = fixtureCourse(startTime: '07:15', endTime: '08:05');

      expect(
        TimetableLiveActivityService.resolveRealTime(port, fixture, true),
        '07:15',
      );
      expect(
        TimetableLiveActivityService.resolveRealTime(port, fixture, false),
        '08:05',
      );
    });

    test('真实课按课节在作息模板里的钟点解析', () {
      final port = _FakePort(
        settings: buildSettings(
          sections: const [
            SectionTime(startTime: '08:00', endTime: '08:45'),
            SectionTime(startTime: '08:50', endTime: '09:35'),
          ],
        ),
      );
      final course = buildCourse(startTime: '00:00', endTime: '00:00');

      expect(
        TimetableLiveActivityService.resolveRealTime(port, course, true),
        '08:00',
      );
      expect(
        TimetableLiveActivityService.resolveRealTime(port, course, false),
        '09:35',
      );
    });
  });

  group('buildCorrectedCourseDateTime', () {
    test('按设置里的时间修正秒数平移', () {
      final port = _FakePort(
        settings: buildSettings(timeCorrectionSeconds: 90),
      );

      expect(
        TimetableLiveActivityService.buildCorrectedCourseDateTime(
          port,
          DateTime(2026, 3, 2),
          '08:00',
        ),
        DateTime(2026, 3, 2, 8, 1, 30),
      );
    });

    test('非法钟点返回 null，不会把日期静默挪一天', () {
      final port = _FakePort();

      expect(
        TimetableLiveActivityService.buildCorrectedCourseDateTime(
          port,
          DateTime(2026, 3, 2),
          '25:00',
        ),
        isNull,
      );
    });
  });

  group('getActivityCourseSelection', () {
    test('节假日直接不选课（不靠停岛分支兜底）', () {
      final now = DateTime(2026, 3, 2, 9);
      final port = _FakePort(
        courses: [buildCourse(dayOfWeek: now.weekday)],
        holiday: HolidayData(
          year: 2026,
          version: 1,
          entries: [
            HolidayEntry(
              date: DateTime(2026, 3, 2),
              name: '测试假',
              type: HolidayType.vacation,
            ),
          ],
        ),
      );

      expect(
        TimetableLiveActivityService.getActivityCourseSelection(
          port,
          now: now,
        ),
        isNull,
      );
    });

    test('课中返回当前课与归一后的展示名', () {
      final now = DateTime(2026, 3, 2, 9);
      final port = _FakePort(
        courses: [buildCourse(dayOfWeek: now.weekday)],
      );

      final selection = TimetableLiveActivityService.getActivityCourseSelection(
        port,
        now: now,
      );

      expect(selection, isNotNull);
      expect(selection!.currentCourse.name, '高等数学(归一名)');
      expect(selection.stage, LiveActivityStage.duringClass);
      expect(port.resolveDisplayNameCalls, greaterThan(0));
    });

    test('当天没课返回 null', () {
      final now = DateTime(2026, 3, 2, 9);
      final otherDay = now.weekday == 1 ? 2 : 1;
      final port = _FakePort(
        courses: [buildCourse(dayOfWeek: otherDay)],
      );

      expect(
        TimetableLiveActivityService.getActivityCourseSelection(
          port,
          now: now,
        ),
        isNull,
      );
    });

    test('自检预设课与真实课同场竞争：按解析后开始时间排序，nextCourse 是真实课', () {
      final now = DateTime(2026, 3, 2, 7, 30);
      final port = _FakePort(
        settings: buildSettings(
          sections: const [SectionTime(startTime: '10:00', endTime: '11:40')],
          showBeforeClassMinutes: 40,
        ),
        courses: [
          buildCourse(id: 'real', dayOfWeek: now.weekday),
        ],
      );
      // 预设课 07:00 开始、真实课按作息模板 10:00 开始：排序后预设课在前。
      port.liveRuntime.fixtureOverlayCourses = [
        fixtureCourse(
          id: 'live_test_a',
          dayOfWeek: now.weekday,
          startTime: '07:00',
          endTime: '07:45',
        ),
      ];

      final selection = TimetableLiveActivityService.getActivityCourseSelection(
        port,
        now: now,
      );

      expect(selection, isNotNull);
      expect(selection!.currentCourse.id, 'live_test_a');
      expect(selection.nextCourse?.id, 'real');
    });

    test('未开启上课前阶段时即使允许回退也不提前选课', () {
      final now = DateTime(2026, 3, 2, 9);
      final port = _FakePort(
        settings: buildSettings(
          sections: const [SectionTime(startTime: '10:00', endTime: '11:40')],
          enableBeforeClass: false,
        ),
        courses: [buildCourse(dayOfWeek: now.weekday)],
      );

      expect(
        TimetableLiveActivityService.getActivityCourseSelection(
          port,
          now: now,
          allowUpcomingFallback: true,
        ),
        isNull,
      );
    });

    test('开启上课前阶段且允许回退时返回 beforeClass', () {
      final now = DateTime(2026, 3, 2, 9, 55);
      final port = _FakePort(
        settings: buildSettings(
          sections: const [SectionTime(startTime: '10:00', endTime: '11:40')],
        ),
        courses: [buildCourse(dayOfWeek: now.weekday)],
      );

      final selection = TimetableLiveActivityService.getActivityCourseSelection(
        port,
        now: now,
        allowUpcomingFallback: true,
      );

      expect(selection, isNotNull);
      expect(selection!.stage, LiveActivityStage.beforeClass);
    });
  });

  group('getCoursesInProgress', () {
    test('只挑实时时钟落在起止之间的课，并返回归一后的名字', () {
      final now = DateTime(2026, 3, 2, 9, 10);
      final port = _FakePort(
        settings: buildSettings(
          sections: const [
            SectionTime(startTime: '08:00', endTime: '08:45'),
            SectionTime(startTime: '08:50', endTime: '09:35'),
          ],
        ),
        courses: [
          buildCourse(id: 'c1', dayOfWeek: now.weekday),
          buildCourse(
            id: 'c2',
            name: '大学物理',
            dayOfWeek: now.weekday,
            startSection: 3,
            endSection: 4,
            startTime: '10:00',
            endTime: '11:40',
          ),
        ],
      );

      final inProgress = TimetableLiveActivityService.getCoursesInProgress(
        port,
        dayOfWeek: now.weekday,
        now: now,
      );

      expect(inProgress.map((course) => course.id), ['c1']);
      expect(inProgress.single.name, '高等数学(归一名)');
    });

    test('显式 week 会过滤掉不在周次范围的课', () {
      final now = DateTime(2026, 3, 2, 9, 10);
      final port = _FakePort(
        courses: [
          buildCourse(dayOfWeek: now.weekday, endWeek: 4),
        ],
      );

      expect(
        TimetableLiveActivityService.getCoursesInProgress(
          port,
          dayOfWeek: now.weekday,
          week: 8,
          now: now,
        ),
        isEmpty,
      );
    });
  });

  group('getTodayCourses / getCurrentCourse', () {
    test('学期未设时按 currentDateWeek 取当天的课', () {
      final port = _FakePort(
        courses: [
          buildCourse(id: 'today', endWeek: 3),
        ],
      );

      expect(
        TimetableLiveActivityService.getTodayCourses(port).map((c) => c.id),
        ['today'],
      );

      port.currentDateWeek = 5;
      expect(
        TimetableLiveActivityService.getTodayCourses(port),
        isEmpty,
        reason: '周次口径要跟着 currentDateWeek 走',
      );
    });

    test('设了开学日期后改走真实日历周（结课后不再重复列出上完的课）', () {
      final port = _FakePort(
        settings: buildSettings(semesterStartDate: DateTime(2026, 3, 2)),
        courses: [
          buildCourse(id: 'cal', startWeek: 3, endWeek: 3),
        ],
      );
      port.calendarWeek = 3;
      port.currentDateWeek = 1;

      expect(
        TimetableLiveActivityService.getTodayCourses(
          port,
        ).map((course) => course.id),
        ['cal'],
      );
    });

    test('getCurrentCourse 用分钟序判定正在上的那一节', () {
      final port = _FakePort(
        courses: [
          buildCourse(
            id: 'all-day',
            startTime: '00:00',
            endTime: '23:59',
          ),
        ],
      );

      expect(
        TimetableLiveActivityService.getCurrentCourse(port)?.id,
        'all-day',
      );
    });
  });
  group('自检预设课覆盖层', () {
    test('注入后可见、摘除后清空', () {
      final port = _FakePort();

      TimetableLiveActivityService.armFixtureCourses(port, [fixtureCourse()]);
      expect(port.liveRuntime.fixtureOverlayCourses, hasLength(1));

      TimetableLiveActivityService.disarmFixtureCourses(port);
      expect(port.liveRuntime.fixtureOverlayCourses, isEmpty);
    });

    test('预设课全部结束后才摘除，未结束保持挂载', () {
      final port = _FakePort();
      port.liveRuntime.fixtureOverlayCourses = [
        fixtureCourse(),
      ];

      expect(
        TimetableLiveActivityService.disarmFixtureCoursesIfFinished(
          port,
          DateTime(2026, 3, 2, 9, 39),
        ),
        isFalse,
      );
      expect(port.liveRuntime.fixtureOverlayCourses, hasLength(1));

      expect(
        TimetableLiveActivityService.disarmFixtureCoursesIfFinished(
          port,
          DateTime(2026, 3, 2, 9, 41),
        ),
        isTrue,
      );
      expect(port.liveRuntime.fixtureOverlayCourses, isEmpty);
    });

    test('空覆盖层时摘除是 no-op', () {
      final port = _FakePort();

      TimetableLiveActivityService.disarmFixtureCourses(port);

      expect(port.liveRuntime.fixtureOverlayCourses, isEmpty);
      expect(
        TimetableLiveActivityService.disarmFixtureCoursesIfFinished(
          port,
          DateTime(2026, 3, 2, 9, 41),
        ),
        isFalse,
      );
    });
  });

  group('挂起窗口', () {
    test('suspendSyncFor 设截止时间，clearSyncSuspend 清掉', () {
      final port = _FakePort();
      final before = DateTime.now();

      TimetableLiveActivityService.suspendSyncFor(
        port,
        const Duration(minutes: 5),
      );
      expect(port.liveRuntime.suspendedUntil, isNotNull);
      expect(port.liveRuntime.suspendedUntil!.isAfter(before), isTrue);

      TimetableLiveActivityService.clearSyncSuspend(port);
      expect(port.liveRuntime.suspendedUntil, isNull);
    });
  });
}
