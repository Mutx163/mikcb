import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/class_reminder.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/services/class_reminder_service.dart';
import 'package:university_timetable/services/exam_reminder_service.dart';

Course _course({String id = 'c1'}) => Course(
      id: id,
      name: '高等数学',
      teacher: '张三',
      location: '教一 101',
      dayOfWeek: 1,
      startSection: 1,
      endSection: 2,
      startTime: '08:30',
      endTime: '10:00',
    );

void main() {
  group('ClassReminderEntry', () {
    test('json round-trip keeps identity and fields', () {
      const entry = ClassReminderEntry(
        courseId: 'c1',
        date: '2026-09-01',
        minuteOfDay: 480,
      );
      final restored = ClassReminderEntry.fromJson(entry.toJson());
      expect(restored, entry);
      expect(restored!.id, entry.id);
      expect(entry.id, 'classreminder:c1@2026-09-01');
    });

    test('rejects malformed json instead of throwing', () {
      expect(ClassReminderEntry.fromJson(null), isNull);
      expect(ClassReminderEntry.fromJson('x'), isNull);
      expect(ClassReminderEntry.fromJson(<String, Object>{}), isNull);
      expect(
        ClassReminderEntry.fromJson({
          'courseId': '',
          'date': '2026-09-01',
          'minuteOfDay': 480,
        }),
        isNull,
      );
      expect(
        ClassReminderEntry.fromJson({
          'courseId': 'c1',
          'date': '2026-13-01',
          'minuteOfDay': 480,
        }),
        isNull,
      );
      expect(
        ClassReminderEntry.fromJson({
          'courseId': 'c1',
          'date': '2026-09-01',
          'minuteOfDay': 1440,
        }),
        isNull,
      );
    });

    test('listFromJson skips broken rows', () {
      final list = ClassReminderEntry.listFromJson([
        null,
        'bad',
        <String, Object>{},
        {
          'courseId': 'ok',
          'date': '2026-09-01',
          'minuteOfDay': 510,
        },
      ]);
      expect(list.length, 1);
      expect(list.single.courseId, 'ok');
      expect(ClassReminderEntry.listFromJson(null), isEmpty);
    });
  });

  group('ClassReminderService.parseClockMinutes / formatClock', () {
    test('parses valid clock times', () {
      expect(ClassReminderService.parseClockMinutes('08:00'), 480);
      expect(ClassReminderService.parseClockMinutes('23:59'), 1439);
      expect(ClassReminderService.parseClockMinutes('00:00'), 0);
    });

    test('rejects malformed times', () {
      expect(ClassReminderService.parseClockMinutes('25:00'), isNull);
      expect(ClassReminderService.parseClockMinutes('08:60'), isNull);
      expect(ClassReminderService.parseClockMinutes(''), isNull);
    });

    test('formats within one day', () {
      expect(ClassReminderService.formatClock(480), '08:00');
      expect(ClassReminderService.formatClock(0), '00:00');
      expect(ClassReminderService.formatClock(1440 + 90), '01:30');
    });
  });

  group('ClassReminderService.occurrenceDateTime', () {
    test('builds local wall-clock time on the entry date', () {
      final dt = ClassReminderService.occurrenceDateTime(
        const ClassReminderEntry(
          courseId: 'c1',
          date: '2026-09-07',
          minuteOfDay: 8 * 60 + 5,
        ),
      );
      expect(dt, DateTime(2026, 9, 7, 8, 5));
    });
  });

  group('ClassReminderService.requestCode', () {
    test('stable for identical entries, distinct across times', () {
      const a = ClassReminderEntry(
        courseId: 'c1',
        date: '2026-09-07',
        minuteOfDay: 480,
      );
      const b = ClassReminderEntry(
        courseId: 'c1',
        date: '2026-09-07',
        minuteOfDay: 480,
      );
      const c = ClassReminderEntry(
        courseId: 'c1',
        date: '2026-09-07',
        minuteOfDay: 510,
      );
      expect(ClassReminderService.requestCode(a), ClassReminderService.requestCode(b));
      expect(ClassReminderService.requestCode(a), isNot(ClassReminderService.requestCode(c)));
      // 与考试提醒命名空间一致且不越界。
      final code = ClassReminderService.requestCode(a);
      expect(code & 0xff000000, ExamReminderService.requestCodeNamespace);
    });
  });

  group('ClassReminderService.buildFires', () {
    test('expands valid future entries into fires', () {
      final fires = ClassReminderService.buildFires(
        entries: const [
          ClassReminderEntry(
            courseId: 'c1',
            date: '2099-09-07',
            minuteOfDay: 8 * 60,
          ),
        ],
        resolveCourse: (_) => _course(),
        now: DateTime(2099, 9, 1),
      );
      expect(fires.length, 1);
      expect(fires.single.examId, 'classreminder:c1@2099-09-07');
      expect(fires.single.title, '高等数学');
      expect(fires.single.body, '教一 101');
      expect(
        DateTime.fromMillisecondsSinceEpoch(fires.single.fireAtMillis),
        DateTime(2099, 9, 7, 8, 0),
      );
    });

    test('drops deleted courses, past fires and invalid entries', () {
      final fires = ClassReminderService.buildFires(
        entries: const [
          // 课程不存在
          ClassReminderEntry(courseId: 'ghost', date: '2099-09-07', minuteOfDay: 480),
          // 已过期
          ClassReminderEntry(courseId: 'c1', date: '2099-09-07', minuteOfDay: 480),
          // 非法日期
          ClassReminderEntry(courseId: 'c1', date: '2099-02-30', minuteOfDay: 480),
          // 合法
          ClassReminderEntry(courseId: 'c1', date: '2099-09-08', minuteOfDay: 490),
        ],
        resolveCourse: (id) => id == 'c1' ? _course() : null,
        now: DateTime(2099, 9, 7, 12, 0),
      );
      expect(fires.length, 1);
      expect(fires.single.examId, 'classreminder:c1@2099-09-08');
    });
  });
}
