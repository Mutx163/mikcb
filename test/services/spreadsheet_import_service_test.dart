import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/spreadsheet_import_service.dart';

void main() {
  final service = SpreadsheetImportService();
  final settings = TimetableSettings.defaults();

  const mikcbFullSample = '''
# mikcb-course-import-v1
课程名,星期,开始节,结束节,教师,教室,上课周
高等数学,1,1,2,张老师,A101,1-16
大学英语,3,3,4,无,教学楼201,1-8、10-16
程序设计,5,5,6,李老师,实验室,1-5、7-11单
''';

  const wakeUpSample = '''
课程名称,星期,开始节数,结束节数,老师,地点,周数
高等数学,1,1,2,张老师,A101,1-16
大学英语,3,3,4,无,教学楼201,1-8、10-16
程序设计,5,5,6,李老师,实验室,1-5、7-11单
''';

  test('parses minimal 5-column mikcb import', () {
    const csv = '''
课程名,星期,开始节,结束节,上课周
线性代数,2,3,4,1-16
''';

    final result = service.parseBytes(
      utf8.encode(csv),
      fileName: 'courses.csv',
      settings: settings,
    );

    expect(result.format, SpreadsheetImportService.formatMikcb);
    expect(result.warnings, isEmpty);
    expect(result.courses, hasLength(1));

    final course = result.courses.first;
    expect(course.name, '线性代数');
    expect(course.dayOfWeek, 2);
    expect(course.startSection, 3);
    expect(course.endSection, 4);
    expect(course.teacher, isEmpty);
    expect(course.location, isEmpty);
    expect(course.customWeeks, [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
    ]);
    expect(course.color, '#2196F3');
    expect(course.courseNature, CourseNature.required);
    expect(course.id, startsWith('spreadsheet-'));
  });

  test('parses full optional columns into Course model', () {
    const csv = '''
课程名,星期,开始节,结束节,上课周,简称,教师,教室,开始时间,结束时间,颜色,停课周,性质,简介,备注,时间模板
数据结构,4,1,2,1-8,数构,王老师,C302,08:00,09:40,FF5722,5,选修,算法与结构,期中考试,scheme-a
''';

    final result = service.parseBytes(
      utf8.encode(csv),
      fileName: 'courses.csv',
      settings: settings,
    );

    expect(result.format, SpreadsheetImportService.formatMikcb);
    expect(result.warnings, isEmpty);
    expect(result.courses, hasLength(1));

    final course = result.courses.first;
    expect(course.name, '数据结构');
    expect(course.shortName, '数构');
    expect(course.teacher, '王老师');
    expect(course.location, 'C302');
    expect(course.startTime, '08:00');
    expect(course.endTime, '09:40');
    expect(course.color, '#FF5722');
    expect(course.suspendedWeeks, [5]);
    expect(course.courseNature, CourseNature.elective);
    expect(course.description, '算法与结构');
    expect(course.note, '期中考试');
    expect(course.timeSchemeIdOverride, 'scheme-a');
    expect(course.customWeeks, [1, 2, 3, 4, 5, 6, 7, 8]);
  });

  test('parses range week mode without custom weeks column value', () {
    const csv = '''
课程名,星期,开始节,结束节,开始周,结束周,单周
物理实验,3,5,6,1,16,是
''';

    final result = service.parseBytes(
      utf8.encode(csv),
      fileName: 'courses.csv',
      settings: settings,
    );

    expect(result.format, SpreadsheetImportService.formatMikcb);
    expect(result.warnings, isEmpty);
    expect(result.courses, hasLength(1));

    final course = result.courses.first;
    expect(course.name, '物理实验');
    expect(course.customWeeks, isNull);
    expect(course.startWeek, 1);
    expect(course.endWeek, 16);
    expect(course.isOddWeek, isTrue);
    expect(course.isEvenWeek, isFalse);
    expect(course.activeWeeks, [1, 3, 5, 7, 9, 11, 13, 15]);
  });

  test('parses mikcb official template XLSX sample', () {
    final bytes = File(
      'test/fixtures/mikcb_course_import_template.xlsx',
    ).readAsBytesSync();
    final result = service.parseBytes(
      bytes,
      fileName: 'courses.xlsx',
      settings: settings,
    );

    expect(result.format, SpreadsheetImportService.formatMikcb);
    expect(result.warnings, isEmpty);
    expect(result.courses, hasLength(3));
    expect(result.courses.first.name, '高等数学');
    expect(result.courses[2].customWeeks, [1, 2, 3, 4, 5, 7, 9, 11]);
  });

  test('warns when custom weeks exceed semester week count', () {
    const csv = '''
课程名,星期,开始节,结束节,上课周
超限课程,2,1,2,1-20
''';

    final result = service.parseBytes(
      utf8.encode(csv),
      fileName: 'courses.csv',
      settings: settings.copyWith(semesterWeekCount: 16),
    );

    expect(result.courses, hasLength(1));
    expect(result.courses.first.customWeeks, hasLength(16));
    expect(result.courses.first.customWeeks!.last, 16);
    expect(result.warnings, isNotEmpty);
    expect(result.warnings.first, contains('16'));
  });

  test('parses mikcb official template CSV sample', () {
    final result = service.parseBytes(
      utf8.encode(mikcbFullSample),
      fileName: 'courses.csv',
      settings: settings,
    );

    expect(result.format, SpreadsheetImportService.formatMikcb);
    expect(result.warnings, isEmpty);
    expect(result.courses, hasLength(3));

    final math = result.courses[0];
    expect(math.name, '高等数学');
    expect(math.dayOfWeek, 1);
    expect(math.startSection, 1);
    expect(math.endSection, 2);
    expect(math.teacher, '张老师');
    expect(math.location, 'A101');
    expect(math.customWeeks, [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
    ]);

    final english = result.courses[1];
    expect(english.teacher, isEmpty);
    expect(english.location, '教学楼201');
    expect(english.customWeeks, [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
    ]);

    final programming = result.courses[2];
    expect(programming.customWeeks, [1, 2, 3, 4, 5, 7, 9, 11]);
    expect(result.requiredSectionCount, 6);
  });

  test('parses WakeUp compatible CSV sample', () {
    final result = service.parseBytes(
      utf8.encode(wakeUpSample),
      fileName: 'courses.csv',
      settings: settings,
    );

    expect(result.format, SpreadsheetImportService.formatWakeUp);
    expect(result.warnings, isEmpty);
    expect(result.courses, hasLength(3));
    expect(result.courses.first.name, '高等数学');
  });

  test('skips empty rows and reports invalid row warnings', () {
    const csv = '''
课程名,星期,开始节,结束节,上课周
有效课程,2,1,2,1-4

,0,1,2,1-4
''';

    final result = service.parseBytes(
      utf8.encode(csv),
      fileName: 'courses.csv',
      settings: settings,
    );

    expect(result.courses, hasLength(1));
    expect(result.courses.first.name, '有效课程');
    expect(result.warnings, hasLength(1));
    expect(result.warnings.first, contains('第 3 行'));
  });

  test('rejects unknown header format', () {
    const csv = '''
name,teacher,day,section,room,weeks
Course A,Teacher,1,1-2,Room,1-16
''';

    expect(
      () => service.parseBytes(
        utf8.encode(csv),
        fileName: 'courses.csv',
        settings: settings,
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
