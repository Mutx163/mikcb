import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable/live_activity_logic.dart';

Course buildCourse({
  String id = 'course-1',
  int startSection = 1,
  int endSection = 2,
  String startTime = '08:00',
  String endTime = '09:40',
  String location = 'A101',
  String teacher = '张老师',
  String name = '高等数学',
}) {
  return Course(
    id: id,
    name: name,
    teacher: teacher,
    location: location,
    dayOfWeek: 1,
    startSection: startSection,
    endSection: endSection,
    startTime: startTime,
    endTime: endTime,
  );
}

TimetableSettings settingsWithLive({
  bool beforeClass = true,
  bool duringClass = true,
  bool beforeEnd = true,
  bool showDuringNotification = true,
  bool promoteDuringClass = true,
  int classReminderStartMinutes = 0,
}) {
  return TimetableSettings(
    sections: const [
      SectionTime(startTime: '08:00', endTime: '08:45'),
      SectionTime(startTime: '08:50', endTime: '09:35'),
    ],
    liveEnableBeforeClass: beforeClass,
    liveEnableDuringClass: duringClass,
    liveEnableBeforeEnd: beforeEnd,
    liveShowDuringClassNotification: showDuringNotification,
    livePromoteDuringClass: promoteDuringClass,
    liveClassReminderStartMinutes: classReminderStartMinutes,
  );
}

void main() {
  group('LiveActivityLogic.parseClockMinutes', () {
    test('parses valid HH:mm', () {
      expect(LiveActivityLogic.parseClockMinutes('08:30'), 8 * 60 + 30);
      expect(LiveActivityLogic.parseClockMinutes('00:00'), 0);
      expect(LiveActivityLogic.parseClockMinutes('23:59'), 23 * 60 + 59);
    });

    test('returns null for invalid values', () {
      expect(LiveActivityLogic.parseClockMinutes('8'), isNull);
      expect(LiveActivityLogic.parseClockMinutes('aa:bb'), isNull);
      expect(LiveActivityLogic.parseClockMinutes('08:xx'), isNull);
      expect(LiveActivityLogic.parseClockMinutes(''), isNull);
    });
  });

  group('LiveActivityLogic.buildCourseDateTime', () {
    test('combines date and course time', () {
      final date = DateTime(2026, 4, 16);
      expect(
        LiveActivityLogic.buildCourseDateTime(date, '09:15'),
        DateTime(2026, 4, 16, 9, 15),
      );
    });

    test('returns null for invalid course time', () {
      expect(
        LiveActivityLogic.buildCourseDateTime(DateTime(2026, 4, 16), 'bad'),
        isNull,
      );
    });
  });

  group('LiveActivityLogic.resolveRealTime', () {
    final sections = [
      const SectionTime(startTime: '08:00', endTime: '08:45'),
      const SectionTime(startTime: '08:50', endTime: '09:35'),
    ];

    test('uses section table when indexes are in range', () {
      final course = buildCourse(startSection: 1, endSection: 2);
      expect(
        LiveActivityLogic.resolveRealTime(course, true, sections),
        '08:00',
      );
      expect(
        LiveActivityLogic.resolveRealTime(course, false, sections),
        '09:35',
      );
    });

    test('falls back to course clock when sections missing', () {
      final course = buildCourse(startTime: '07:30', endTime: '09:10');
      expect(LiveActivityLogic.resolveRealTime(course, true, null), '07:30');
      expect(LiveActivityLogic.resolveRealTime(course, false, null), '09:10');
    });
  });

  group('LiveActivityLogic milestones', () {
    final sections = [
      const SectionTime(startTime: '08:00', endTime: '08:45'),
      const SectionTime(startTime: '08:55', endTime: '09:40'),
    ];

    test('returns empty when course spans fewer than 2 sections', () {
      final single = buildCourse(startSection: 1, endSection: 1);
      expect(
        LiveActivityLogic.buildLiveProgressMilestones(
          single,
          sections,
          startAtMillis: 0,
          endAtMillis: 1000,
        ),
        isEmpty,
      );
    });

    test('returns empty when endAt is not after startAt', () {
      final course = buildCourse(startSection: 1, endSection: 2);
      expect(
        LiveActivityLogic.buildLiveProgressMilestones(
          course,
          sections,
          startAtMillis: 1000,
          endAtMillis: 1000,
        ),
        isEmpty,
      );
    });

    test('builds break milestones with stable label keys', () {
      final course = buildCourse(startSection: 1, endSection: 2);
      final milestones = LiveActivityLogic.buildLiveProgressMilestones(
        course,
        sections,
        startAtMillis: 0,
        endAtMillis: 100 * 60 * 1000,
      );

      expect(milestones, hasLength(2));
      expect(milestones[0]['label'], milestoneRecentEndLabelKey);
      expect(milestones[0]['timeText'], '08:45');
      expect(milestones[1]['label'], milestoneNextStartLabelKey);
      expect(milestones[1]['timeText'], '08:55');
      expect(
        (milestones[0]['offsetMillis'] as int) <
            (milestones[1]['offsetMillis'] as int),
        isTrue,
      );

      final offsets = LiveActivityLogic.buildLiveProgressBreakOffsetsMillis(
        course,
        sections,
        startAtMillis: 0,
        endAtMillis: 100 * 60 * 1000,
      );
      expect(offsets, [
        milestones[0]['offsetMillis'],
        milestones[1]['offsetMillis'],
      ]);
    });
  });

  group('LiveActivityLogic stage helpers', () {
    test('buildStageTransitionKey includes course and stage identity', () {
      final course = buildCourse();
      final selection = LiveActivityCourseSelection(
        currentCourse: course,
        nextCourse: null,
        stage: LiveActivityStage.duringClass,
      );

      final key = LiveActivityLogic.buildStageTransitionKey(selection);
      expect(key, contains(course.id));
      expect(key, contains(LiveActivityStage.duringClass.name));
      expect(key, contains(course.name));
      expect(key, contains(course.location));
    });

    test('canDisplayStage respects live toggles', () {
      final settings = settingsWithLive(
        beforeClass: false,
        duringClass: true,
        beforeEnd: false,
        showDuringNotification: false,
        promoteDuringClass: true,
      );

      expect(
        LiveActivityLogic.canDisplayStage(
          LiveActivityStage.beforeClass,
          settings,
        ),
        isFalse,
      );
      // duringClass needs promote or notification.
      expect(
        LiveActivityLogic.canDisplayStage(
          LiveActivityStage.duringClass,
          settings,
        ),
        isTrue,
      );
      expect(
        LiveActivityLogic.canDisplayStage(
          LiveActivityStage.duringClassStatusBar,
          settings,
        ),
        isFalse,
      );
      expect(
        LiveActivityLogic.canDisplayStage(
          LiveActivityStage.beforeEnd,
          settings,
        ),
        isFalse,
      );
    });

    test('preferredTestStage picks first enabled stage', () {
      expect(
        LiveActivityLogic.preferredTestStage(
          settingsWithLive(beforeClass: true),
        ),
        LiveActivityStage.beforeClass,
      );
      expect(
        LiveActivityLogic.preferredTestStage(
          settingsWithLive(beforeClass: false, duringClass: true),
        ),
        LiveActivityStage.duringClass,
      );
      expect(
        LiveActivityLogic.preferredTestStage(
          settingsWithLive(
            beforeClass: false,
            duringClass: false,
            beforeEnd: true,
          ),
        ),
        LiveActivityStage.beforeEnd,
      );
      expect(
        LiveActivityLogic.preferredTestStage(
          settingsWithLive(
            beforeClass: false,
            duringClass: false,
            beforeEnd: false,
          ),
        ),
        isNull,
      );
    });

    test('resolveEndReminderStart never starts before class start', () {
      final start = DateTime(2026, 4, 16, 8);
      final end = DateTime(2026, 4, 16, 8, 20);
      expect(
        LiveActivityLogic.resolveEndReminderStart(
          start,
          end,
          const Duration(minutes: 30),
        ),
        start,
      );
      expect(
        LiveActivityLogic.resolveEndReminderStart(
          start,
          end,
          const Duration(minutes: 5),
        ),
        DateTime(2026, 4, 16, 8, 15),
      );
    });

    test('resolveLiveActivityStage covers before / during / beforeEnd', () {
      final settings = settingsWithLive();
      final start = DateTime(2026, 4, 16, 8);
      final end = DateTime(2026, 4, 16, 9, 40);
      final ahead = start.subtract(const Duration(minutes: 20));

      expect(
        LiveActivityLogic.resolveLiveActivityStage(
          currentTime: ahead.subtract(const Duration(minutes: 1)),
          startTime: start,
          endTime: end,
          aheadTime: ahead,
          settings: settings,
          endReminderWindow: const Duration(minutes: 10),
        ),
        isNull,
      );

      expect(
        LiveActivityLogic.resolveLiveActivityStage(
          currentTime: start.subtract(const Duration(minutes: 5)),
          startTime: start,
          endTime: end,
          aheadTime: ahead,
          settings: settings,
          endReminderWindow: const Duration(minutes: 10),
        ),
        LiveActivityStage.beforeClass,
      );

      expect(
        LiveActivityLogic.resolveLiveActivityStage(
          currentTime: start.add(const Duration(minutes: 10)),
          startTime: start,
          endTime: end,
          aheadTime: ahead,
          settings: settings,
          endReminderWindow: const Duration(minutes: 10),
        ),
        LiveActivityStage.duringClass,
      );

      expect(
        LiveActivityLogic.resolveLiveActivityStage(
          currentTime: end.subtract(const Duration(minutes: 5)),
          startTime: start,
          endTime: end,
          aheadTime: ahead,
          settings: settings,
          endReminderWindow: const Duration(minutes: 10),
        ),
        LiveActivityStage.beforeEnd,
      );

      expect(
        LiveActivityLogic.resolveLiveActivityStage(
          currentTime: end,
          startTime: start,
          endTime: end,
          aheadTime: ahead,
          settings: settings,
          endReminderWindow: const Duration(minutes: 10),
        ),
        isNull,
      );
    });

    test('resolveLiveActivityStage uses status-bar window when configured', () {
      final settings = settingsWithLive(classReminderStartMinutes: 15);
      final start = DateTime(2026, 4, 16, 8);
      final end = DateTime(2026, 4, 16, 9);
      final ahead = start.subtract(const Duration(minutes: 20));

      // After class start but before the late-class reminder window.
      expect(
        LiveActivityLogic.resolveLiveActivityStage(
          currentTime: start.add(const Duration(minutes: 5)),
          startTime: start,
          endTime: end,
          aheadTime: ahead,
          settings: settings,
          endReminderWindow: const Duration(minutes: 10),
        ),
        LiveActivityStage.duringClassStatusBar,
      );

      // Inside the configured end-of-class reminder window.
      expect(
        LiveActivityLogic.resolveLiveActivityStage(
          currentTime: end.subtract(const Duration(minutes: 10)),
          startTime: start,
          endTime: end,
          aheadTime: ahead,
          settings: settings,
          endReminderWindow: const Duration(minutes: 10),
        ),
        LiveActivityStage.beforeEnd,
      );
    });
  });
}
