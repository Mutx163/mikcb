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
        now: DateTime(2099, 9),
      );
      expect(fires.length, 1);
      expect(fires.single.examId, 'classreminder:c1@2099-09-07');
      expect(fires.single.title, '高等数学');
      expect(fires.single.body, '教一 101');
      expect(
        DateTime.fromMillisecondsSinceEpoch(fires.single.fireAtMillis),
        DateTime(2099, 9, 7, 8),
      );
    });

    // 原生侧把 offsetMinutes 当「提前量」用：开机/换时区重建时按
    // `examStartMillis - offsetMinutes*60_000` 反推响点
    // （ExamReminderScheduler.kt:186-187），并在解析入参时按
    // `fireAtMillis + offsetMinutes*60_000` 反推上课时刻（:426-427）。
    // 单节课提醒没有「上课时刻 + 提前量」这一对概念——entry.minuteOfDay 就是
    // 响点本身——原先却把 minuteOfDay 原样填进 offsetMinutes：22:00 的提醒
    // (minuteOfDay=1320) 在 10-08 09:00 开机后被反推成 10-08 00:00（已过期但在
    // 24h 宽限内）→ 改排到 now+1s，用户当场收到一条提前 22 小时的提醒，而这条
    // fire 投递后就从快照删除（:283-287），22:00 的真提醒不再来。
    // 这里钉住契约：这两个字段必须让原生的加减法退化成「响点就是绝对时刻」。
    test('leaves the native offset arithmetic as a no-op', () {
      final fires = ClassReminderService.buildFires(
        entries: const [
          ClassReminderEntry(
            courseId: 'c1',
            date: '2099-09-07',
            minuteOfDay: 22 * 60,
          ),
        ],
        resolveCourse: (_) => _course(),
        now: DateTime(2099, 9),
      );
      final fire = fires.single;

      expect(fire.offsetMinutes, 0, reason: 'offsetMinutes 是提前量，不是当日分钟数');
      expect(fire.examStartMillis, fire.fireAtMillis);
      // 原生的两个反推公式在 offsetMinutes=0 时都必须回到同一个响点。
      expect(fire.examStartMillis - fire.offsetMinutes * 60, fire.fireAtMillis);
      expect(fire.fireAtMillis + fire.offsetMinutes * 60, fire.fireAtMillis);
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
        now: DateTime(2099, 9, 7, 12),
      );
      expect(fires.length, 1);
      expect(fires.single.examId, 'classreminder:c1@2099-09-08');
    });
  });
}
