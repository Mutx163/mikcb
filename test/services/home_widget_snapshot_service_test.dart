import 'package:flutter_test/flutter_test.dart';
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
}
