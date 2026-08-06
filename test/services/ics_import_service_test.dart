import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/ics_import_service.dart';

String _formatTime(DateTime value) {
  return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

DateTime _startOfWeek(DateTime value) {
  return DateTime(
    value.year,
    value.month,
    value.day,
  ).subtract(Duration(days: value.weekday - 1));
}

void main() {
  test(
    'imports saturday single-week wakeup event without spilling into next week',
    () {
      const content = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//YZune//WakeUpSchedule//EN
BEGIN:VEVENT
SUMMARY:基准课[16][必修]
DTSTART;TZID=/Asia/Shanghai:20260302T082000
DTEND;TZID=/Asia/Shanghai:20260302T100000
RRULE:FREQ=WEEKLY;UNTIL=20260308T160000Z;INTERVAL=1
LOCATION:A101 张老师
DESCRIPTION:第1 - 2节\\nA101\\n张老师
END:VEVENT
BEGIN:VEVENT
SUMMARY:程序设计技术基础[32][必修]
DTSTART;TZID=/Asia/Shanghai:20260411T103000
DTEND;TZID=/Asia/Shanghai:20260411T121000
RRULE:FREQ=WEEKLY;UNTIL=20260417T160000Z;INTERVAL=1
LOCATION:A主201 黄群惠
DESCRIPTION:第3 - 4节\\nA主201\\n黄群惠
END:VEVENT
END:VCALENDAR
''';

      final result = IcsImportService().parseWakeUpSchedule(content);
      final course = result.courses.singleWhere(
        (item) => item.name == '程序设计技术基础',
      );

      expect(course.startWeek, 6);
      expect(course.endWeek, 6);
    },
  );

  test('imports continuous weekly wakeup event with correct end week', () {
    const content = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//YZune//WakeUpSchedule//EN
BEGIN:VEVENT
SUMMARY:机械制造技术[56][必修]
DTSTART;TZID=/Asia/Shanghai:20260302T160000
DTEND;TZID=/Asia/Shanghai:20260302T174000
RRULE:FREQ=WEEKLY;UNTIL=20260405T160000Z;INTERVAL=1
LOCATION:A主314 曹老师
DESCRIPTION:第7 - 8节\\nA主314\\n曹老师
END:VEVENT
END:VCALENDAR
''';

    final result = IcsImportService().parseWakeUpSchedule(content);
    final course = result.courses.single;

    expect(course.startWeek, 1);
    expect(course.endWeek, 5);
  });

  test('merges wakeup single-week fragments into an even-week course', () {
    const content = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//YZune//WakeUpSchedule//EN
BEGIN:VEVENT
SUMMARY:基准课[16][必修]
DTSTART;TZID=/Asia/Shanghai:20260302T082000
DTEND;TZID=/Asia/Shanghai:20260302T100000
RRULE:FREQ=WEEKLY;UNTIL=20260308T160000Z;INTERVAL=1
LOCATION:A101 张老师
DESCRIPTION:第1 - 2节\\nA101\\n张老师
END:VEVENT
BEGIN:VEVENT
SUMMARY:程序设计技术基础[32][必修]
DTSTART;TZID=/Asia/Shanghai:20260328T103000
DTEND;TZID=/Asia/Shanghai:20260328T121000
RRULE:FREQ=WEEKLY;UNTIL=20260403T160000Z;INTERVAL=1
LOCATION:A主201 黄群惠
DESCRIPTION:第3 - 4节\\nA主201\\n黄群惠
END:VEVENT
BEGIN:VEVENT
SUMMARY:程序设计技术基础[32][必修]
DTSTART;TZID=/Asia/Shanghai:20260411T103000
DTEND;TZID=/Asia/Shanghai:20260411T121000
RRULE:FREQ=WEEKLY;UNTIL=20260417T160000Z;INTERVAL=1
LOCATION:A主201 黄群惠
DESCRIPTION:第3 - 4节\\nA主201\\n黄群惠
END:VEVENT
BEGIN:VEVENT
SUMMARY:程序设计技术基础[32][必修]
DTSTART;TZID=/Asia/Shanghai:20260425T103000
DTEND;TZID=/Asia/Shanghai:20260425T121000
RRULE:FREQ=WEEKLY;UNTIL=20260501T160000Z;INTERVAL=1
LOCATION:A主201 黄群惠
DESCRIPTION:第3 - 4节\\nA主201\\n黄群惠
END:VEVENT
BEGIN:VEVENT
SUMMARY:程序设计技术基础[32][必修]
DTSTART;TZID=/Asia/Shanghai:20260509T103000
DTEND;TZID=/Asia/Shanghai:20260509T121000
RRULE:FREQ=WEEKLY;UNTIL=20260515T160000Z;INTERVAL=1
LOCATION:A主201 黄群惠
DESCRIPTION:第3 - 4节\\nA主201\\n黄群惠
END:VEVENT
END:VCALENDAR
''';

    final result = IcsImportService().parseWakeUpSchedule(content);
    final course = result.courses.singleWhere(
      (item) => item.name == '程序设计技术基础',
    );

    expect(course.startWeek, 4);
    expect(course.endWeek, 10);
    expect(course.isOddWeek, isFalse);
    expect(course.isEvenWeek, isTrue);
  });

  test(
    'keeps full campus and classroom text when description provides location',
    () {
      const content = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//YZune//WakeUpSchedule//EN
BEGIN:VEVENT
SUMMARY:进阶通用英语(S1110026)
DTSTART;TZID=/Asia/Shanghai:20260302T082000
DTEND;TZID=/Asia/Shanghai:20260302T095500
RRULE:FREQ=WEEKLY;UNTIL=20260308T160000Z;INTERVAL=1
LOCATION:奉贤校区 一教C104 白玮玮(讲师)(主讲)
DESCRIPTION:第1 - 2节\\n奉贤校区 一教C104\\n白玮玮(讲师)(主讲)
END:VEVENT
END:VCALENDAR
''';

      final result = IcsImportService().parseWakeUpSchedule(content);
      final course = result.courses.single;

      expect(course.location, '奉贤校区 一教C104');
      expect(course.teacher, '白玮玮(讲师)(主讲)');
    },
  );

  test(
    'parseWakeUpSchedule returns empty result when DTSTART is unparseable',
    () {
      const content = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
SUMMARY:坏课
DESCRIPTION:第1 - 2节\\nA101\\n张老师
DTSTART:invalid
DTEND:invalid
END:VEVENT
END:VCALENDAR
''';

      final result = IcsImportService().parseWakeUpSchedule(content);
      expect(result.courses, isEmpty);
    },
  );

  test('converts UTC ICS timestamps to local wall-clock time', () {
    const content = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
SUMMARY:UTC课程
DTSTART:20260301T233000Z
DTEND:20260302T013000Z
LOCATION:A101 张老师
DESCRIPTION:第1 - 2节\\nA101\\n张老师
END:VEVENT
END:VCALENDAR
''';

    final result = IcsImportService().parseWakeUpSchedule(content);
    final course = result.courses.single;
    final expectedStart = DateTime.utc(2026, 3, 1, 23, 30).toLocal();
    final expectedEnd = DateTime.utc(2026, 3, 2, 1, 30).toLocal();

    expect(course.dayOfWeek, expectedStart.weekday);
    expect(course.startTime, _formatTime(expectedStart));
    expect(course.endTime, _formatTime(expectedEnd));
    expect(result.semesterStart, _startOfWeek(expectedStart));
  });

  test('marks biweekly INTERVAL=2 course as odd or even weeks', () {
    const content = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//YZune//WakeUpSchedule//EN
BEGIN:VEVENT
SUMMARY:双周实验[16][必修]
DTSTART;TZID=/Asia/Shanghai:20260302T082000
DTEND;TZID=/Asia/Shanghai:20260302T100000
RRULE:FREQ=WEEKLY;UNTIL=20260524T160000Z;INTERVAL=2
LOCATION:B201 李老师
DESCRIPTION:第1 - 2节\\nB201\\n李老师
END:VEVENT
END:VCALENDAR
''';

    final result = IcsImportService().parseWakeUpSchedule(content);
    final course = result.courses.single;

    expect(course.startWeek, 1);
    expect(course.isOddWeek, isTrue);
    expect(course.isEvenWeek, isFalse);
    expect(course.isInWeek(1), isTrue);
    expect(course.isInWeek(2), isFalse);
    expect(course.isInWeek(3), isTrue);
  });
}
