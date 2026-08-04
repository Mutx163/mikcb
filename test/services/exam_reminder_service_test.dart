import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/exam.dart';
import 'package:university_timetable/models/schedule_item.dart';
import 'package:university_timetable/services/exam_reminder_service.dart';

void main() {
  Course buildCourse() {
    return Course(
      id: 'course-1',
      name: '高等数学',
      teacher: '张老师',
      location: 'A101',
      dayOfWeek: 1,
      startSection: 1,
      endSection: 2,
      startTime: '08:00',
      endTime: '09:40',
    );
  }

  Exam buildExam({
    String id = 'exam-1',
    String name = '期末考试',
    DateTime? dateTime,
    String startTime = '08:30',
    String endTime = '10:30',
    ExamReminderPreset preset = ExamReminderPreset.day1AndHour1,
    List<int> customMinutes = const [],
    String? location = 'A-301',
    String? seatNumber = '12',
  }) {
    return Exam(
      id: id,
      courseId: 'course-1',
      name: name,
      dateTime: dateTime ?? DateTime(2026, 7, 20),
      startTime: startTime,
      endTime: endTime,
      location: location,
      seatNumber: seatNumber,
      reminderPreset: preset,
      customReminderMinutes: customMinutes,
      createdAt: DateTime(2026, 4, 1),
      updatedAt: DateTime(2026, 4, 1),
    );
  }

  ScheduleItem buildSchedule({
    String id = 'schedule-1',
    DateTime? startDate,
    DateTime? endDate,
    ScheduleRecurrence recurrence = ScheduleRecurrence.daily,
    int? reminderMinutesBefore = 30,
    bool enabled = true,
    Iterable<DateTime> exceptionDates = const <DateTime>[],
  }) {
    return ScheduleItem(
      id: id,
      title: '每日自习',
      startDate: startDate ?? DateTime(2026, 7, 10),
      endDate: endDate ?? DateTime(2026, 7, 12),
      startTime: '09:00',
      endTime: '10:00',
      recurrence: recurrence,
      exceptionDates: exceptionDates,
      reminderMinutesBefore: reminderMinutesBefore,
      enabled: enabled,
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 1),
    );
  }

  group('ExamReminderService.buildFires', () {
    test('expands day1AndHour1 into two future fires', () {
      final exam = buildExam(dateTime: DateTime(2026, 7, 20));
      final now = DateTime(2026, 7, 10, 12);
      final fires = ExamReminderService.buildFires(
        exams: [exam],
        resolveCourse: (_) => buildCourse(),
        now: now,
      );

      expect(fires, hasLength(2));
      expect(fires.map((f) => f.offsetMinutes).toList(), [1440, 60]);
      expect(fires.every((f) => f.examId == 'exam-1'), isTrue);
      expect(
        fires.every(
          (f) =>
              f.requestCode ==
              ExamReminderService.stableRequestCode(f.examId, f.offsetMinutes),
        ),
        isTrue,
      );
    });

    test('skips past fire points and expired exams', () {
      final exam = buildExam(
        dateTime: DateTime(2026, 7, 20),
        preset: ExamReminderPreset.hour1AndMin30,
      );
      // 1 hour before (07:30) is past; 30 minutes before (08:00) is still future.
      final now = DateTime(2026, 7, 20, 7, 45);
      final fires = ExamReminderService.buildFires(
        exams: [exam],
        resolveCourse: (_) => null,
        now: now,
      );

      expect(fires, hasLength(1));
      expect(fires.single.offsetMinutes, 30);
    });

    test('none preset yields no fires', () {
      final fires = ExamReminderService.buildFires(
        exams: [
          buildExam(
            dateTime: DateTime(2026, 8, 1),
            preset: ExamReminderPreset.none,
          ),
        ],
        resolveCourse: (_) => null,
        now: DateTime(2026, 7, 1),
      );
      expect(fires, isEmpty);
    });

    test('body includes time, location and seat', () {
      final fires = ExamReminderService.buildFires(
        exams: [buildExam(dateTime: DateTime(2026, 8, 1))],
        resolveCourse: (_) => buildCourse(),
        now: DateTime(2026, 7, 1),
      );
      expect(fires.first.body, contains('08:30-10:30'));
      expect(fires.first.body, contains('A-301'));
      expect(fires.first.body, contains('12'));
    });

    test('body falls back to course location when exam location is empty', () {
      final fires = ExamReminderService.buildFires(
        exams: [
          buildExam(
            dateTime: DateTime(2026, 8, 1),
            location: null,
            seatNumber: null,
          ),
        ],
        resolveCourse: (_) => buildCourse(),
        now: DateTime(2026, 7, 1),
      );
      expect(fires.first.body, '08:30-10:30 · A101');
    });

    test(
      'uses exam name as title and leaves blank for native i18n fallback',
      () {
        final named = ExamReminderService.buildFires(
          exams: [buildExam(dateTime: DateTime(2026, 8, 1), name: ' 高等数学 ')],
          resolveCourse: (_) => null,
          now: DateTime(2026, 7, 1),
        );
        expect(named.first.title, '高等数学');

        final blank = ExamReminderService.buildFires(
          exams: [buildExam(dateTime: DateTime(2026, 8, 1), name: '   ')],
          resolveCourse: (_) => null,
          now: DateTime(2026, 7, 1),
        );
        // Empty title is intentional: native uses localized default title.
        expect(blank.first.title, isEmpty);
        expect(blank.first.title, isNot('考试提醒'));
      },
    );

    test('stableRequestCode is deterministic', () {
      expect(
        ExamReminderService.stableRequestCode('exam-1', 60),
        ExamReminderService.stableRequestCode('exam-1', 60),
      );
      expect(
        ExamReminderService.stableRequestCode('exam-1', 60),
        isNot(ExamReminderService.stableRequestCode('exam-1', 1440)),
      );
    });
  });

  group('Exam.examStartDateTime', () {
    test('combines date and startTime', () {
      final exam = buildExam(
        dateTime: DateTime(2026, 7, 19),
        startTime: '21:37',
      );
      expect(exam.examStartDateTime, DateTime(2026, 7, 19, 21, 37));
    });
  });

  group('ExamReminderService schedule reminders', () {
    test('expands future recurring schedule occurrences', () {
      final fires = ExamReminderService.buildScheduleFires(
        scheduleItems: [buildSchedule()],
        now: DateTime(2026, 7, 10, 8),
      );

      expect(fires, hasLength(3));
      expect(fires.map((fire) => fire.examId).toList(), [
        'schedule:schedule-1@2026-07-10',
        'schedule:schedule-1@2026-07-11',
        'schedule:schedule-1@2026-07-12',
      ]);
      expect(fires.first.offsetMinutes, 30);
      expect(fires.first.body, '09:00-10:00');
    });

    test('disabled schedule and disabled override do not retain alarms', () {
      final root = buildSchedule(
        endDate: DateTime(2026, 7, 12),
        exceptionDates: [DateTime(2026, 7, 11)],
      );
      final disabledOverride = buildSchedule(
        id: 'schedule-1@2026-07-11',
        startDate: DateTime(2026, 7, 11),
        endDate: DateTime(2026, 7, 11),
        recurrence: ScheduleRecurrence.none,
        reminderMinutesBefore: null,
        enabled: false,
      ).copyWith(seriesId: root.id, occurrenceDate: DateTime(2026, 7, 11));

      final fires = ExamReminderService.buildScheduleFires(
        scheduleItems: [root, disabledOverride],
        now: DateTime(2026, 7, 10, 8),
      );

      expect(fires.map((fire) => fire.examId), [
        'schedule:schedule-1@2026-07-10',
        'schedule:schedule-1@2026-07-12',
      ]);
      expect(
        ExamReminderService.buildScheduleActiveIds(
          scheduleItems: [root, disabledOverride],
          now: DateTime(2026, 7, 10, 8),
        ),
        {'schedule:schedule-1@2026-07-10', 'schedule:schedule-1@2026-07-12'},
      );
    });

    test('skips schedule fire already in the past', () {
      final fires = ExamReminderService.buildScheduleFires(
        scheduleItems: [buildSchedule()],
        now: DateTime(2026, 7, 10, 8, 45),
      );

      expect(fires, hasLength(2));
      expect(
        fires.first.examStartMillis,
        DateTime(2026, 7, 11, 9).millisecondsSinceEpoch,
      );
    });
  });
}
