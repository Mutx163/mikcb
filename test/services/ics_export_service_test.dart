import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/exam.dart';
import 'package:university_timetable/models/schedule_item.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/ics_export_service.dart';

void main() {
  final service = IcsExportService();

  TimetableProfile profileWith({
    List<Course> courses = const [],
    List<Exam> exams = const [],
    List<ScheduleItem> scheduleItems = const [],
    String name = '主课表',
    DateTime? semesterStartDate,
  }) {
    return TimetableProfile(
      id: 'profile-1',
      name: name,
      courses: courses,
      exams: exams,
      scheduleItems: scheduleItems,
      settings: TimetableSettings.defaults().copyWith(
        semesterWeekCount: 8,
        semesterStartDate: semesterStartDate ?? DateTime(2026, 3, 2),
      ),
      currentWeek: 1,
      createdAt: DateTime(2026, 2, 1, 9),
      lastUsedAt: DateTime(2026, 2, 1, 10),
    );
  }

  IcsExportResult buildExport(
    TimetableProfile profile, {
    DateTime? fromDate,
    DateTime? toDate,
    Set<IcsExportEventType> eventTypes = const {
      IcsExportEventType.course,
      IcsExportEventType.exam,
      IcsExportEventType.scheduleItem,
    },
    DateTime? generatedAt,
  }) {
    return service.build(
      profile: profile,
      fromDate: fromDate ?? DateTime(2026, 3),
      toDate: toDate ?? DateTime(2026, 4, 30),
      eventTypes: eventTypes,
      generatedAt: generatedAt ?? DateTime.utc(2026, 4, 1, 12, 34, 56),
    );
  }

  test('expands continuous, odd, even, and custom course weeks', () {
    final profile = profileWith(
      courses: [
        _course(
          id: 'continuous',
          name: '连续课',
          endWeek: 4,
        ),
        _course(
          id: 'odd',
          name: '单周课',
          dayOfWeek: DateTime.tuesday,
          endWeek: 4,
          isOddWeek: true,
        ),
        _course(
          id: 'even',
          name: '双周课',
          dayOfWeek: DateTime.wednesday,
          endWeek: 4,
          isEvenWeek: true,
        ),
        _course(
          id: 'custom',
          name: '自定义周课',
          dayOfWeek: DateTime.thursday,
          endWeek: 8,
          customWeeks: [2, 4],
        ),
      ],
    );

    final result = buildExport(
      profile,
      eventTypes: const {IcsExportEventType.course},
    );
    final events = _events(result.content);

    expect(result.eventCount, 10);
    expect(events, hasLength(10));
    expect(result.content, isNot(contains('RRULE:')));
    expect(
      events
          .where((event) => _property(event, 'SUMMARY') == '连续课')
          .map((event) => _property(event, 'DTSTART')),
      containsAll(<String>[
        _icsUtc(DateTime(2026, 3, 2, 8)),
        _icsUtc(DateTime(2026, 3, 9, 8)),
        _icsUtc(DateTime(2026, 3, 16, 8)),
        _icsUtc(DateTime(2026, 3, 23, 8)),
      ]),
    );
    expect(
      events
          .where((event) => _property(event, 'SUMMARY') == '单周课')
          .map((event) => _property(event, 'DTSTART')),
      containsAll(<String>[
        _icsUtc(DateTime(2026, 3, 3, 8)),
        _icsUtc(DateTime(2026, 3, 17, 8)),
      ]),
    );
    expect(
      events
          .where((event) => _property(event, 'SUMMARY') == '双周课')
          .map((event) => _property(event, 'DTSTART')),
      containsAll(<String>[
        _icsUtc(DateTime(2026, 3, 11, 8)),
        _icsUtc(DateTime(2026, 3, 25, 8)),
      ]),
    );
    expect(
      events
          .where((event) => _property(event, 'SUMMARY') == '自定义周课')
          .map((event) => _property(event, 'DTSTART')),
      containsAll(<String>[
        _icsUtc(DateTime(2026, 3, 12, 8)),
        _icsUtc(DateTime(2026, 3, 26, 8)),
      ]),
    );
  });

  test('filters the inclusive date range and selected event types', () {
    final profile = profileWith(
      courses: [
        _course(
          id: 'course-in-range',
          name: '范围内课程',
          endWeek: 3,
        ),
      ],
      exams: [_exam(date: DateTime(2026, 3, 20))],
      scheduleItems: [
        _scheduleItem(
          id: 'agenda-in-range',
          startDate: DateTime(2026, 3, 16),
          endDate: DateTime(2026, 3, 16),
        ),
      ],
    );

    final result = buildExport(
      profile,
      fromDate: DateTime(2026, 3, 9),
      toDate: DateTime(2026, 3, 16),
      eventTypes: const {IcsExportEventType.course},
    );

    expect(result.eventCount, 2);
    expect(_events(result.content), everyElement(contains('SUMMARY:范围内课程')));
    expect(result.content, isNot(contains('考试')));
    expect(result.content, isNot(contains('日程')));
  });

  test('serializes exams and cross-day schedule items with location and notes', () {
    final profile = profileWith(
      exams: [
        _exam(
          name: '期末考试',
          date: DateTime(2026, 3, 20),
          location: '考场,北区;A101',
          seatNumber: '12号',
          note: '带证件\n提前十五分钟',
        ),
      ],
      scheduleItems: [
        _scheduleItem(
          id: 'overnight',
          title: '跨日活动',
          startDate: DateTime(2026, 3, 21),
          endDate: DateTime(2026, 3, 22),
          startTime: '23:30',
          endTime: '01:30',
          location: '礼堂,东区',
          note: '值班备注',
        ),
      ],
    );

    final result = buildExport(
      profile,
      eventTypes: const {
        IcsExportEventType.exam,
        IcsExportEventType.scheduleItem,
      },
    );
    final events = _events(result.content);
    expect(result.eventCount, 2);
    final examEvent = events.singleWhere(
      (event) => _property(event, 'SUMMARY').contains('期末考试'),
    );
    final overnightEvents = events
        .where((event) => _property(event, 'SUMMARY').contains('跨日活动'))
        .toList();
    expect(overnightEvents, hasLength(1));
    final overnightEvent = overnightEvents.single;

    expect(_property(examEvent, 'DTSTART'), _icsUtc(DateTime(2026, 3, 20, 9)));
    expect(_property(examEvent, 'DTEND'), _icsUtc(DateTime(2026, 3, 20, 11)));
    expect(_property(examEvent, 'LOCATION'), '考场\\,北区\\;A101');
    expect(_property(examEvent, 'DESCRIPTION'), contains(r'带证件\n'));
    expect(_property(examEvent, 'DESCRIPTION'), contains('12号'));
    expect(
      _property(overnightEvent, 'DTSTART'),
      _icsUtc(DateTime(2026, 3, 21, 23, 30)),
    );
    expect(
      _property(overnightEvent, 'DTEND'),
      _icsUtc(DateTime(2026, 3, 22, 1, 30)),
    );
    expect(_property(overnightEvent, 'LOCATION'), '礼堂\\,东区');
    expect(_property(overnightEvent, 'DESCRIPTION'), contains('值班备注'));
  });

  test('escapes text and folds lines at UTF-8 octet boundaries using CRLF', () {
    final profile = profileWith(
      courses: [
        _course(
          id: 'escaped',
          name: '中文,课程;专题\\路径',
          location: 'A101,主楼;\\南区',
          description: '第一行\n第二行,备注;\\路径',
        ),
        _course(
          id: 'long',
          name: List.filled(120, '长').join(),
          description: List.filled(80, '备注内容').join(),
        ),
      ],
    );

    final result = buildExport(
      profile,
      eventTypes: const {IcsExportEventType.course},
    );
    final lines = result.content.split('\r\n');
    final escapedEvent = _events(result.content).singleWhere(
      (event) => _property(event, 'SUMMARY').contains(r'中文\,课程\;专题'),
    );

    expect(result.content, endsWith('\r\n'));
    expect(result.content.replaceAll('\r\n', ''), isNot(contains('\n')));
    expect(result.content.replaceAll('\r\n', ''), isNot(contains('\r')));
    expect(lines.where((line) => line.isNotEmpty), everyElement(
      predicate<String>((line) => utf8.encode(line).length <= 75),
    ));
    expect(lines, contains(startsWith(' ')));
    expect(_property(escapedEvent, 'SUMMARY'), r'中文\,课程\;专题\\路径');
    expect(_property(escapedEvent, 'LOCATION'), r'A101\,主楼\;\\南区');
    expect(
      _property(escapedEvent, 'DESCRIPTION'),
      contains(r'第一行\n第二行\,备注\;\\路径'),
    );
  });

  test('uses UTC DTSTAMP and stable non-leaking UIDs for repeated requests', () {
    final profile = profileWith(
      name: '主课表/2026: 秋季?',
      courses: [
        _course(id: 'private-course-id', name: '稳定 UID 课程'),
      ],
    );
    final first = buildExport(profile);
    final second = buildExport(profile);

    expect(first.content, second.content);
    expect(first.eventCount, second.eventCount);
    expect(_uids(first.content), isNotEmpty);
    expect(_uids(first.content), _uids(second.content));
    expect(first.content, contains('DTSTAMP:20260401T123456Z'));
    expect(first.content, isNot(contains('private-course-id')));
    expect(first.fileName, endsWith('.ics'));
    expect(
      first.fileName,
      anyOf(contains('20260301'), contains('2026-03-01')),
    );
    expect(
      first.fileName,
      anyOf(contains('20260430'), contains('2026-04-30')),
    );
    expect(first.fileName, isNot(contains('/')));
    expect(first.fileName, isNot(contains('\\')));
    expect(first.fileName, isNot(contains(':')));
    expect(first.fileName, isNot(contains('?')));
  });

  test('keeps an empty selection and an empty profile as valid VCALENDAR files', () {
    final populated = profileWith(
      courses: [_course(id: 'ignored', name: '不应导出')],
    );
    final emptySelection = buildExport(populated, eventTypes: const {});
    final emptyProfile = buildExport(profileWith());

    for (final result in [emptySelection, emptyProfile]) {
      expect(result.eventCount, 0);
      expect(result.content, startsWith('BEGIN:VCALENDAR\r\n'));
      expect(result.content, contains('VERSION:2.0\r\n'));
      expect(result.content, endsWith('END:VCALENDAR\r\n'));
      expect(result.content, isNot(contains('BEGIN:VEVENT')));
    }
  });
}

Course _course({
  required String id,
  required String name,
  int dayOfWeek = DateTime.monday,
  int startWeek = 1,
  int endWeek = 1,
  bool isOddWeek = false,
  bool isEvenWeek = false,
  List<int>? customWeeks,
  String startTime = '08:00',
  String endTime = '10:00',
  String teacher = '张老师',
  String location = 'A101',
  String? description,
}) {
  return Course(
    id: id,
    name: name,
    teacher: teacher,
    location: location,
    dayOfWeek: dayOfWeek,
    startSection: 1,
    endSection: 2,
    startTime: startTime,
    endTime: endTime,
    startWeek: startWeek,
    endWeek: endWeek,
    isOddWeek: isOddWeek,
    isEvenWeek: isEvenWeek,
    customWeeks: customWeeks,
    description: description,
  );
}

Exam _exam({
  String id = 'exam-1',
  String name = '考试',
  DateTime? date,
  String startTime = '09:00',
  String endTime = '11:00',
  String? location,
  String? seatNumber,
  String? note,
}) {
  return Exam(
    id: id,
    courseId: 'course-1',
    name: name,
    dateTime: date ?? DateTime(2026, 3, 20),
    startTime: startTime,
    endTime: endTime,
    location: location,
    seatNumber: seatNumber,
    note: note,
    createdAt: DateTime(2026, 2),
    updatedAt: DateTime(2026, 2, 2),
  );
}

ScheduleItem _scheduleItem({
  required String id,
  String title = '日程',
  required DateTime startDate,
  required DateTime endDate,
  String startTime = '18:00',
  String endTime = '19:30',
  String? location,
  String? note,
}) {
  return ScheduleItem(
    id: id,
    title: title,
    startDate: startDate,
    endDate: endDate,
    startTime: startTime,
    endTime: endTime,
    location: location,
    note: note,
    createdAt: DateTime(2026, 2),
    updatedAt: DateTime(2026, 2, 2),
  );
}

List<String> _events(String content) {
  final unfolded = _unfold(content);
  return RegExp(
    r'BEGIN:VEVENT\n(.*?)\nEND:VEVENT',
    dotAll: true,
  ).allMatches(unfolded).map((match) => match.group(1)!).toList();
}

String _unfold(String content) {
  final lines = content.replaceAll('\r\n', '\n').split('\n');
  final unfolded = <String>[];
  for (final line in lines) {
    if ((line.startsWith(' ') || line.startsWith('\t')) && unfolded.isNotEmpty) {
      unfolded[unfolded.length - 1] += line.substring(1);
    } else {
      unfolded.add(line);
    }
  }
  return unfolded.join('\n');
}

String _property(String event, String name) {
  final line = event
      .split('\n')
      .firstWhere((line) => line.startsWith('$name:'), orElse: () => '');
  return line.substring(name.length + 1);
}

List<String> _uids(String content) {
  return _events(content)
      .map((event) => _property(event, 'UID'))
      .where((uid) => uid.isNotEmpty)
      .toList();
}

String _icsUtc(DateTime localWallClock) {
  final value = localWallClock.toUtc();
  return '${value.year.toString().padLeft(4, '0')}'
      '${value.month.toString().padLeft(2, '0')}'
      '${value.day.toString().padLeft(2, '0')}'
      'T${value.hour.toString().padLeft(2, '0')}'
      '${value.minute.toString().padLeft(2, '0')}'
      '${value.second.toString().padLeft(2, '0')}Z';
}
