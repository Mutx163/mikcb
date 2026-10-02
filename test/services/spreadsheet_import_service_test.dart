import 'dart:convert';
import 'dart:io';

import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/spreadsheet_import_service.dart';

/// Excel「CSV UTF-8」导出会在最前面写 EF BB BF（UTF-8 BOM），这里按**字节**复刻
/// 那个签名，避免把不可见的 U+FEFF 直接写进源码。
List<int> csvBytesWithBom(String csv) =>
    const <int>[0xEF, 0xBB, 0xBF] + utf8.encode(csv);

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
    expect(result.warnings.first, contains('spreadsheet_row_warning|rowNumber=3'));
  });

  // UTF-8 BOM 是 Excel「CSV UTF-8」导出的固定签名（EF BB BF）。这条只钉行为：
  // 带 BOM 时格式识别与列名匹配必须照常成立（将来换解析器或改解码顺序时它会
  // 立刻变红）。
  test('strips a UTF-8 BOM before header detection', () {
    const csv = '''
课程名,星期,开始节,结束节,上课周
线性代数,2,3,4,1-16
''';

    final result = service.parseBytes(
      csvBytesWithBom(csv),
      fileName: 'courses.csv',
      settings: settings,
    );

    expect(result.format, SpreadsheetImportService.formatMikcb);
    expect(result.courses.single.name, '线性代数');
  });

  // TableParser.decodeCsv 的引号处理整块都在 `if (_textDelimiter != null)` 里
  // （table_parser-1.0.1/lib/src/csv.dart:86-118），而本服务调用时没传该参数
  // （spreadsheet_import_service.dart:244），默认就是 null。于是 RFC4180 的带引号
  // 字段被当成普通字符：引号留在值里、引号内的逗号照样切分 —— 用户看到教师变成
  // `"王`、教室变成 `老师"`，且没有任何警告。
  test('honours quoted CSV fields, including commas and doubled quotes', () {
    const csv = '''
课程名,星期,开始节,结束节,教师,教室,上课周
"数据结构,进阶",1,1,2,"王,老师","C302",1-8
"编译原理""实验",2,3,4,周老师,D001,1-8
''';

    final result = service.parseBytes(
      utf8.encode(csv),
      fileName: 'courses.csv',
      settings: settings,
    );

    expect(result.courses, hasLength(2));
    expect(result.courses[0].name, '数据结构,进阶');
    expect(result.courses[0].teacher, '王,老师');
    expect(result.courses[0].location, 'C302');
    expect(result.courses[1].name, '编译原理"实验');
  });

  // shouldParseNumbers 默认为 true：纯数字单元格会先转成 num 再 toString 回来，
  // 于是 Excel 里存成文本的教室号 `007` 变成 `7`、`1.10` 变成 `1.1`。本服务随后
  // 自己按文本解析每一列，数值化没有任何收益，只会静默改数据。
  test('keeps numeric-looking cells as literal text', () {
    const csv = '''
课程名,星期,开始节,结束节,教师,教室,上课周
数值分析,1,1,2,吴老师,007,1-8
''';

    final result = service.parseBytes(
      utf8.encode(csv),
      fileName: 'courses.csv',
      settings: settings,
    );

    expect(result.courses.single.location, '007');
  });

  test('rejects unknown header format', () {    const csv = '''
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

  // 报错里的字段名要走本地化，传的必须是字段代码（如 weekday），
  // 不能是中文表头，否则英文界面会显示「星期 must be an integer」。
  test('error field names use localizable codes, not Chinese headers', () {
    const badWeekday = '''
课程名,星期,开始节,结束节,上课周
高等数学,不是数字,1,2,1-16
''';
    const badSection = '''
课程名,星期,开始节,结束节,上课周
高等数学,1,一,2,1-16
''';
    const badWeek = '''
课程名,星期,开始节,结束节,开始周,结束周
高等数学,1,1,2,不是数字,16
''';

    List<String> warningsFor(String csv) {
      final result = service.parseBytes(
        utf8.encode(csv),
        fileName: 'courses.csv',
        settings: settings,
      );
      return result.warnings;
    }

    final weekdayWarnings = warningsFor(badWeekday);
    expect(weekdayWarnings.join('|'), contains('field=weekday'));
    expect(weekdayWarnings.join('|'), isNot(contains('星期')));

    final sectionWarnings = warningsFor(badSection);
    expect(sectionWarnings.join('|'), contains('field=start_section'));
    expect(sectionWarnings.join('|'), isNot(contains('开始节')));

    final weekWarnings = warningsFor(badWeek);
    expect(weekWarnings.join('|'), contains('field=start_week'));
    expect(weekWarnings.join('|'), isNot(contains('开始周')));
  });

  test('prefers odd week when both odd and even columns are true', () {
    const csv = '''
课程名,星期,开始节,结束节,开始周,结束周,单周,双周
冲突课,2,1,2,1,16,是,是
''';

    final result = service.parseBytes(
      utf8.encode(csv),
      fileName: 'courses.csv',
      settings: settings,
    );

    expect(result.courses, hasLength(1));
    final course = result.courses.first;
    expect(course.isOddWeek, isTrue);
    expect(course.isEvenWeek, isFalse);
    expect(course.activeWeeks, isNotEmpty);
    expect(result.warnings, isNotEmpty);
    expect(result.warnings.first, contains('spreadsheet_odd_even_both'));
  });

  test('parses GBK-encoded CSV exported from Chinese Windows Excel', () {
    const csv = '''
课程名,星期,开始节,结束节,上课周
高等数学,1,1,2,1-16
''';
    final gbkBytes = gbk.encode(csv);

    final result = service.parseBytes(
      gbkBytes,
      fileName: 'courses.csv',
      settings: settings,
    );

    expect(result.courses, hasLength(1));
    expect(result.courses.first.name, '高等数学');
  });

  test('caps a spreadsheet well above any real export', () {
    // The cap itself, and the read-before-measure guard that makes it
    // enforceable, live in import_file_reader and are covered by
    // test/utils/import_file_reader_test.dart. Here we only pin the budget this
    // service asks for.
    expect(SpreadsheetImportService.maxFileBytes, 20 * 1024 * 1024);
  });
}
