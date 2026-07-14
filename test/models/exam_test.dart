import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/exam.dart';

void main() {
  group('ExamReminderPreset', () {
    test('day1AndHour1 returns correct minutes', () {
      expect(ExamReminderPreset.day1AndHour1.reminderMinutes, [1440, 60]);
    });

    test('none returns empty list', () {
      expect(ExamReminderPreset.none.reminderMinutes, isEmpty);
    });

    test('custom returns empty list (uses customReminderMinutes)', () {
      expect(ExamReminderPreset.custom.reminderMinutes, isEmpty);
    });

    test('min30 returns [30]', () {
      expect(ExamReminderPreset.min30.reminderMinutes, [30]);
    });

    test('hour1 returns [60]', () {
      expect(ExamReminderPreset.hour1.reminderMinutes, [60]);
    });

    test('hour1AndMin30 returns [60, 30]', () {
      expect(ExamReminderPreset.hour1AndMin30.reminderMinutes, [60, 30]);
    });

    test('day1 returns [1440]', () {
      expect(ExamReminderPreset.day1.reminderMinutes, [1440]);
    });

    test('fromValue roundtrips', () {
      for (final preset in ExamReminderPreset.values) {
        expect(ExamReminderPresetX.fromValue(preset.value), preset);
      }
    });

    test('fromValue defaults to day1AndHour1 for unknown', () {
      expect(
        ExamReminderPresetX.fromValue('garbage'),
        ExamReminderPreset.day1AndHour1,
      );
    });
  });

  group('Exam', () {
    final baseExam = Exam(
      id: 'exam-1',
      courseId: 'course-1',
      name: '高等数学期末考试',
      dateTime: DateTime(2026, 7, 1),
      startTime: '08:30',
      endTime: '10:30',
      location: 'A-301',
      seatNumber: '12',
      reminderPreset: ExamReminderPreset.day1AndHour1,
      createdAt: DateTime(2026, 4, 1),
      updatedAt: DateTime(2026, 4, 1),
    );

    test('toJson/fromJson roundtrips', () {
      final json = baseExam.toJson();
      final restored = Exam.fromJson(json);
      expect(restored.id, baseExam.id);
      expect(restored.courseId, baseExam.courseId);
      expect(restored.name, baseExam.name);
      expect(restored.startTime, baseExam.startTime);
      expect(restored.endTime, baseExam.endTime);
      expect(restored.location, baseExam.location);
      expect(restored.seatNumber, baseExam.seatNumber);
      expect(restored.reminderPreset, baseExam.reminderPreset);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'e1',
        'courseId': 'c1',
        'name': 'Test',
        'dateTime': '2026-07-01T00:00:00.000',
        'startTime': '09:00',
        'endTime': '11:00',
        'createdAt': '2026-04-01T00:00:00.000',
        'updatedAt': '2026-04-01T00:00:00.000',
      };
      final exam = Exam.fromJson(json);
      expect(exam.location, isNull);
      expect(exam.seatNumber, isNull);
      expect(exam.note, isNull);
      expect(exam.reminderPreset, ExamReminderPreset.day1AndHour1);
      expect(exam.customReminderMinutes, isEmpty);
    });

    test('copyWith overrides specified fields', () {
      final updated = baseExam.copyWith(name: '期中考试', location: 'B-201');
      expect(updated.name, '期中考试');
      expect(updated.location, 'B-201');
      expect(updated.courseId, baseExam.courseId);
      expect(updated.seatNumber, baseExam.seatNumber);
    });

    test('copyWith can set location to null', () {
      final updated = baseExam.copyWith(location: null);
      expect(updated.location, isNull);
    });

    test('effectiveReminderMinutes returns preset minutes', () {
      expect(baseExam.effectiveReminderMinutes, [1440, 60]);
    });

    test('effectiveReminderMinutes returns custom list for custom preset', () {
      final custom = baseExam.copyWith(
        reminderPreset: ExamReminderPreset.custom,
        customReminderMinutes: [30, 10],
      );
      expect(custom.effectiveReminderMinutes, [30, 10]);
    });

    test('isExpired returns true for past exam', () {
      final past = baseExam.copyWith(
        dateTime: DateTime(2020, 1, 1),
        startTime: '08:00',
        endTime: '10:00',
      );
      expect(past.isExpired, isTrue);
    });

    test('daysUntil returns correct value', () {
      final future = Exam(
        id: 'e2',
        courseId: 'c1',
        name: 'Test',
        dateTime: DateTime.now().add(const Duration(days: 10)),
        startTime: '08:00',
        endTime: '10:00',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(future.daysUntil, 10);
    });
  });

  group('Exam edge cases', () {
    test('fromJson normalizes malformed exam times', () {
      final exam = Exam.fromJson({
        'id': 'exam-1',
        'courseId': 'course-1',
        'name': '期末',
        'dateTime': '2026-06-01T00:00:00.000',
        'startTime': 'bad',
        'endTime': '25:99',
        'createdAt': '2026-01-01T00:00:00.000',
        'updatedAt': '2026-01-01T00:00:00.000',
      });

      expect(exam.startTime, '08:30');
      expect(exam.endTime, '10:30');
      // Must not throw on malformed original times.
      expect(exam.isExpired, isA<bool>());
    });

    test('isExpired tolerates empty endTime via safe parse', () {
      final exam = Exam(
        id: 'exam-2',
        courseId: 'course-1',
        name: '期中',
        dateTime: DateTime(2020, 1, 1),
        startTime: '08:00',
        endTime: '',
        createdAt: DateTime(2020, 1, 1),
        updatedAt: DateTime(2020, 1, 1),
      );

      expect(exam.isExpired, isTrue);
    });
  });

  group('Exam.normalizeTimeOfDay', () {
    test('normalizes valid time with leading zero', () {
      expect(Exam.normalizeTimeOfDay('8:30'), '08:30');
    });

    test('normalizes valid time without leading zero', () {
      expect(Exam.normalizeTimeOfDay('12:5'), '12:05');
    });

    test('returns same value for already normalized time', () {
      expect(Exam.normalizeTimeOfDay('08:30'), '08:30');
    });

    test('handles boundary valid hour 23', () {
      expect(Exam.normalizeTimeOfDay('23:59'), '23:59');
    });

    test('handles boundary valid hour 0', () {
      expect(Exam.normalizeTimeOfDay('0:00'), '00:00');
    });

    test('returns fallback for hour 24', () {
      expect(Exam.normalizeTimeOfDay('24:00'), '08:30');
    });

    test('returns fallback for minute 60', () {
      expect(Exam.normalizeTimeOfDay('12:60'), '08:30');
    });

    test('returns fallback for non-numeric input', () {
      expect(Exam.normalizeTimeOfDay('abc'), '08:30');
    });

    test('returns fallback for empty string', () {
      expect(Exam.normalizeTimeOfDay(''), '08:30');
    });

    test('returns fallback for null', () {
      expect(Exam.normalizeTimeOfDay(null), '08:30');
    });

    test('returns custom fallback when provided', () {
      expect(Exam.normalizeTimeOfDay('bad', fallback: '10:00'), '10:00');
    });

    test('handles single digit hour and minute', () {
      expect(Exam.normalizeTimeOfDay('9:5'), '09:05');
    });
  });
}
