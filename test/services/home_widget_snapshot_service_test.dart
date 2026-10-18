import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/weekend_mood_logic.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/home_widget_snapshot_service.dart';
import 'package:university_timetable/utils/widget_course_accent.dart';

void main() {
  test(
    'widget snapshot can hide completed courses while preserving daily state',
    () {
      const service = HomeWidgetSnapshotService();
      final settings = TimetableSettings.defaults().copyWith(
        widgetHideCompletedCourses: true,
        widgetHeightAdjustment: 8,
        widgetCornerRadius: 16,
      );
      final now = DateTime(2026, 3, 27, 14, 30);
      final courses = [
        Course(
          id: 'finished',
          name: '高等数学',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: now.weekday,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:35',
        ),
        Course(
          id: 'ongoing',
          name: '大学英语',
          teacher: '李老师',
          location: 'B203',
          dayOfWeek: now.weekday,
          startSection: 5,
          endSection: 6,
          startTime: '14:00',
          endTime: '15:35',
        ),
        Course(
          id: 'upcoming',
          name: '程序设计',
          teacher: '王老师',
          location: 'C305',
          dayOfWeek: now.weekday,
          startSection: 7,
          endSection: 8,
          startTime: '16:00',
          endTime: '17:35',
        ),
      ];

      final snapshot = service.build(
        profileId: 'profile-1',
        profileName: '默认课表',
        currentWeek: 6,
        settings: settings,
        todayCourses: courses,
        now: now,
      );

      expect(snapshot.state, HomeWidgetSnapshotState.ongoing);
      expect(snapshot.totalTodayCourseCount, 3);
      expect(snapshot.heightAdjustment, 8);
      expect(snapshot.cornerRadius, 16);
      expect(snapshot.todayCourses, hasLength(3));
      expect(snapshot.visibleTodayCourses.map((course) => course.id), [
        'ongoing',
        'upcoming',
      ]);
      expect(snapshot.highlightedCourse?.id, 'ongoing');
    },
  );

  test('widget snapshot treats exact end time as course already finished', () {
    const service = HomeWidgetSnapshotService();
    final settings = TimetableSettings.defaults();
    final now = DateTime(2026, 3, 27, 9, 40);
    final courses = [
      Course(
        id: 'finished-now',
        name: '高等数学',
        teacher: '张老师',
        location: 'A101',
        dayOfWeek: now.weekday,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
      ),
      Course(
        id: 'next-course',
        name: '大学英语',
        teacher: '李老师',
        location: 'B203',
        dayOfWeek: now.weekday,
        startSection: 3,
        endSection: 4,
        startTime: '10:10',
        endTime: '11:50',
      ),
    ];

    final snapshot = service.build(
      profileId: 'profile-1',
      profileName: '默认课表',
      currentWeek: 6,
      settings: settings,
      todayCourses: courses,
      now: now,
    );

    expect(snapshot.state, HomeWidgetSnapshotState.upcoming);
    expect(snapshot.highlightedCourse?.id, 'next-course');
    expect(snapshot.nextCourse?.id, 'next-course');
  });

  test('widget refresh triggers include exact course end boundary', () {
    const service = HomeWidgetSnapshotService();
    final now = DateTime(2026, 3, 27, 8, 30);
    final courses = [
      Course(
        id: 'course-1',
        name: '高等数学',
        teacher: '张老师',
        location: 'A101',
        dayOfWeek: now.weekday,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
      ),
    ];

    final triggers = service.buildRefreshTriggers(
      todayCourses: courses,
      now: now,
    );

    expect(
      triggers,
      contains(DateTime(2026, 3, 27, 9, 40).millisecondsSinceEpoch),
    );
  });

  test(
    'dedup json excludes generatedAtMillis so identical content collapses',
    () {
      const service = HomeWidgetSnapshotService();
      final settings = TimetableSettings.defaults();
      final courses = [
        Course(
          id: 'course-1',
          name: '高等数学',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: 1,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
        ),
      ];

      final first = service.build(
        profileId: 'profile-1',
        profileName: '默认课表',
        currentWeek: 6,
        settings: settings,
        todayCourses: courses,
        now: DateTime(2026, 3, 27, 8),
      );
      final second = service.build(
        profileId: 'profile-1',
        profileName: '默认课表',
        currentWeek: 6,
        settings: settings,
        todayCourses: courses,
        now: DateTime(2026, 3, 27, 8, 1),
      );

      expect(first.generatedAtMillis, isNot(second.generatedAtMillis));
      expect(first.toJson()['generatedAtMillis'], isNotNull);
      expect(first.toDedupJson().containsKey('generatedAtMillis'), isFalse);
      expect(first.toDedupJson(), second.toDedupJson());
    },
  );

  test(
    'snapshot carries the course accent mode and the course color hex',
    () {
      const service = HomeWidgetSnapshotService();
      for (final mode in WidgetCourseAccentMode.values) {
        final settings = TimetableSettings.defaults().copyWith(
          widgetCourseAccentMode: mode,
        );
        final now = DateTime(2026, 3, 27, 8);
        final snapshot = service.build(
          profileId: 'profile-1',
          profileName: '默认课表',
          currentWeek: 6,
          settings: settings,
          todayCourses: [
            Course(
              id: 'first',
              name: '高等数学',
              teacher: '张老师',
              location: 'A101',
              dayOfWeek: now.weekday,
              startSection: 1,
              endSection: 2,
              startTime: '08:00',
              endTime: '09:35',
              color: '#22C55E',
            ),
          ],
          now: now,
        );

        expect(snapshot.courseAccentMode, mode);
        expect(
          snapshot.toJson()['courseAccentMode'],
          mode.value,
          reason: 'Kotlin 侧按这个键判档位，键名不能漂',
        );
        expect(snapshot.todayCourses.single.color, '#22C55E');
        expect(
          snapshot.toJson()['todayCourses'],
          isA<List<dynamic>>(),
        );
        final firstCourse =
            (snapshot.toJson()['todayCourses'] as List).first
                as Map<String, dynamic>;
        expect(
          firstCourse['color'],
          '#22C55E',
          reason: 'Kotlin parseCourse 读不到 color 就画不出色条',
        );
      }

      // 假期分支同样要带档位与颜色：否则「今天放假」时桌面观感会跳变。
      final holiday = service.build(
        profileId: 'profile-1',
        profileName: '默认课表',
        currentWeek: 6,
        settings: TimetableSettings.defaults().copyWith(
          widgetCourseAccentMode: WidgetCourseAccentMode.bar,
        ),
        todayCourses: const [],
        now: DateTime(2026, 3, 27, 8),
        isHoliday: true,
        holidayName: '清明',
      );
      expect(holiday.courseAccentMode, WidgetCourseAccentMode.bar);
      expect(holiday.toJson()['courseAccentMode'], 'bar');
    },
  );

  group('周末文案档位', () {
    Course fridayCourse({
      required String id,
      required String startTime,
      required String endTime,
    }) {
      return Course(
        id: id,
        name: '高等数学',
        teacher: '张老师',
        location: 'A101',
        dayOfWeek: 5,
        startSection: 1,
        endSection: 2,
        startTime: startTime,
        endTime: endTime,
      );
    }

    HomeWidgetSnapshot buildOn({
      required DateTime now,
      List<Course> todayCourses = const [],
      List<Course> tomorrowCourses = const [],
      int originalTodayCourseCount = 0,
      int tomorrowDayOfWeek = 0,
      bool isHoliday = false,
      bool isAdjustedWorkdayToday = false,
      bool isAdjustedWorkdayTomorrow = false,
    }) {
      return const HomeWidgetSnapshotService().build(
        profileId: 'profile-1',
        profileName: '默认课表',
        currentWeek: 6,
        settings: TimetableSettings.defaults(),
        todayCourses: todayCourses,
        tomorrowCourses: tomorrowCourses,
        tomorrowDayOfWeek: tomorrowDayOfWeek,
        originalTodayCourseCount: originalTodayCourseCount,
        now: now,
        isHoliday: isHoliday,
        isAdjustedWorkdayToday: isAdjustedWorkdayToday,
        isAdjustedWorkdayTomorrow: isAdjustedWorkdayTomorrow,
      );
    }

    // 2026-03-28 / 03-29 是周六 / 周日；03-27 是周五。
    test('周六没排课 → 档位 rest，但状态仍是 no_course 而不是 holiday', () {
      final snapshot = buildOn(now: DateTime(2026, 3, 28, 10));

      expect(snapshot.weekendMood, WeekendMood.rest);
      // 关键：没有把周末升级成假期态——state 一改，安卓侧 26 处
      // "holiday" 分支会连带改观感，还会清空明天课程列表。
      expect(snapshot.state, HomeWidgetSnapshotState.noCourse);
      expect(snapshot.holidayName, isNull);
      expect(snapshot.toJson()['state'], 'no_course');
      expect(snapshot.toJson()['weekendMood'], 'rest');
    });

    test('周日没排课 → 档位 rest', () {
      final snapshot = buildOn(now: DateTime(2026, 3, 29, 21));
      expect(snapshot.weekendMood, WeekendMood.rest);
    });

    test('周六有课 → 档位 none，课程照常显示', () {
      final snapshot = buildOn(
        now: DateTime(2026, 3, 28, 10),
        todayCourses: [
          fridayCourse(id: 'sat', startTime: '09:00', endTime: '11:00'),
        ],
      );

      expect(snapshot.weekendMood, WeekendMood.none);
      expect(snapshot.state, HomeWidgetSnapshotState.ongoing);
      expect(snapshot.highlightedCourse?.id, 'sat');
    });

    test('周六的课全被停课 → 档位 none（那天确实排了课）', () {
      final snapshot = buildOn(
        now: DateTime(2026, 3, 28, 10),
        originalTodayCourseCount: 2,
      );

      expect(snapshot.weekendMood, WeekendMood.none);
      expect(snapshot.state, HomeWidgetSnapshotState.completed);
    });

    test('调休补班的周六没课 → 档位 none', () {
      final snapshot = buildOn(
        now: DateTime(2026, 5, 9, 10),
        isAdjustedWorkdayToday: true,
      );
      expect(snapshot.weekendMood, WeekendMood.none);
    });

    test('周五最后一节课下课那一分钟 → 档位 ahead', () {
      final snapshot = buildOn(
        now: DateTime(2026, 3, 27, 17, 35),
        todayCourses: [
          fridayCourse(id: 'last', startTime: '14:00', endTime: '17:35'),
        ],
      );

      expect(snapshot.weekendMood, WeekendMood.ahead);
      expect(snapshot.state, HomeWidgetSnapshotState.completed);
    });

    test('周五还有课要上 → 档位 none', () {
      final snapshot = buildOn(
        now: DateTime(2026, 3, 27, 15, 50),
        todayCourses: [
          fridayCourse(id: 'last', startTime: '16:00', endTime: '17:35'),
        ],
      );

      expect(snapshot.weekendMood, WeekendMood.none);
      expect(snapshot.state, HomeWidgetSnapshotState.upcoming);
      expect(snapshot.highlightedCourse?.id, 'last');
    });

    test('周五明天是调休补班 → 档位 none', () {
      final snapshot = buildOn(
        now: DateTime(2026, 3, 27, 18),
        todayCourses: [
          fridayCourse(id: 'last', startTime: '14:00', endTime: '17:35'),
        ],
        isAdjustedWorkdayTomorrow: true,
      );
      expect(snapshot.weekendMood, WeekendMood.none);
    });

    test('法定假期 → 档位 none，走假期态自己的文案', () {
      final snapshot = buildOn(
        now: DateTime(2026, 10, 1, 10),
        isHoliday: true,
      );

      expect(snapshot.weekendMood, WeekendMood.none);
      expect(snapshot.state, HomeWidgetSnapshotState.holiday);
      expect(snapshot.toJson()['weekendMood'], 'none');
    });

    test('周末没课时快照仍带上明天的课（显示与否由原生门禁决定）', () {
      final snapshot = buildOn(
        now: DateTime(2026, 3, 28, 10),
        tomorrowDayOfWeek: 1,
        tomorrowCourses: [
          Course(
            id: 'mon',
            name: '线性代数',
            teacher: '王老师',
            location: 'C305',
            dayOfWeek: 1,
            startSection: 3,
            endSection: 4,
            startTime: '10:10',
            endTime: '11:50',
          ),
        ],
      );

      // Dart 侧只负责把数据算全；「周末不抢明天的课」这条规则落在原生
      // isShowingTomorrowCourses 里（那里是唯一正源，有架构测试守着）。
      expect(snapshot.weekendMood, WeekendMood.rest);
      expect(snapshot.tomorrowCourses.single.id, 'mon');
      expect(snapshot.tomorrowDayOfWeek, 1);
    });

    test('档位进 dedup json：内容变了才会重推卡片', () {
      final friday = [
        fridayCourse(id: 'last', startTime: '14:00', endTime: '17:35'),
      ];
      final before = buildOn(
        now: DateTime(2026, 3, 27, 17, 34),
        todayCourses: friday,
      );
      final after = buildOn(
        now: DateTime(2026, 3, 27, 17, 35),
        todayCourses: friday,
      );

      expect(before.weekendMood, WeekendMood.none);
      expect(after.weekendMood, WeekendMood.ahead);
      expect(before.toDedupJson()['weekendMood'], 'none');
      expect(after.toDedupJson()['weekendMood'], 'ahead');
      expect(
        before.toDedupJson().toString(),
        isNot(after.toDedupJson().toString()),
        reason: '档位变了但内容没变的话卡片不会重画，周五傍晚就切不了文案',
      );
    });
  });
}
