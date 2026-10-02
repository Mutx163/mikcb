import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/ics_import_service.dart';

/// RFC 5545 文本转义（回归钉，2026-10-02）。
///
/// `_parseEvents` 原先把属性值原样入库，只有 DESCRIPTION 手工 replaceAll 了一次
/// `\n`。于是课程名/教室里的 `\,` `\;` `\:` `\\` 全部带着那个反斜杠存进数据库 ——
/// `SUMMARY:高等数学\, 实验` 的课名变成 `高等数学\, 实验`。这不只是难看：课程合并
/// 与去重的键里也带着它，同一门课在两份导出里一个转义一个没转义就会被当成两门课。
void main() {
  const header = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//YZune//WakeUpSchedule//EN
''';

  String event({
    required String summary,
    required String location,
    required String description,
  }) => '${header}BEGIN:VEVENT\n'
      'SUMMARY:$summary\n'
      'DTSTART;TZID=/Asia/Shanghai:20260302T082000\n'
      'DTEND;TZID=/Asia/Shanghai:20260302T100000\n'
      'RRULE:FREQ=WEEKLY;UNTIL=20260615T160000Z;INTERVAL=1\n'
      'LOCATION:$location\n'
      'DESCRIPTION:$description\n'
      'END:VEVENT\nEND:VCALENDAR\n';

  final service = IcsImportService();

  test('comma and colon escapes are restored in the course name', () {
    final result = service.parseWakeUpSchedule(
      event(
        summary: r'高等数学\, 实验[16][必修]',
        location: r'教一\, 202',
        description: r'第1 - 2节\n教一, 202\n王\;老师',
      ),
    );

    final course = result.courses.single;
    expect(course.name, '高等数学, 实验');
    expect(course.location, '教一, 202');
    expect(course.teacher, '王;老师');
  });

  test('newline escape still splits the description lines', () {
    final result = service.parseWakeUpSchedule(
      event(
        summary: r'线性代数[8][必修]',
        location: 'B101',
        description: r'第3 - 4节\nB101\n李老师',
      ),
    );

    final course = result.courses.single;
    expect(course.name, '线性代数');
    expect(course.startSection, 3);
    expect(course.endSection, 4);
    expect(course.location, 'B101');
    expect(course.teacher, '李老师');
  });

  // `\\` 是一个字面反斜杠，后面那个字符**不再**被当成转义序列的一部分。
  test('double backslash yields one literal backslash', () {
    final result = service.parseWakeUpSchedule(
      event(
        summary: r'编译原理\\n实验[8][必修]',
        location: r'C\主楼',
        description: r'第5 - 6节\nC\主楼\n周老师',
      ),
    );

    expect(result.courses.single.name, r'编译原理\n实验');
    expect(result.courses.single.location, r'C\主楼');
  });

  test('untouched text stays verbatim', () {
    expect(service.unescapeIcsText('高等数学[16][必修]'), '高等数学[16][必修]');
    expect(service.unescapeIcsText(r'无转义 A101'), r'无转义 A101');
    // 结尾单独一个反斜杠不是合法转义序列，保留原样而不是吃掉它。
    expect(service.unescapeIcsText(r'尾反斜杠\'), r'尾反斜杠\');
    // 未知Escape（\x）按 RFC 允许接收方丢弃反斜杠，这里保守保留原样。
    expect(service.unescapeIcsText(r'\x'), r'\x');
  });

  test('时刻与 RRULE 的值不被反转义', () {
    // 这两个属性不在 TEXT 属性集合里：全局反转义会把 `FREQ=WEEKLY;UNTIL=…`
    // 的分号、`TZID=/Asia/Shanghai:` 的冒号改坏。
    final result = service.parseWakeUpSchedule(
      event(
        summary: '结构力学[8][必修]',
        location: 'D303',
        description: r'第7 - 8节\nD303\n赵老师',
      ),
    );

    final course = result.courses.single;
    expect(course.startWeek, 1);
    expect(course.endWeek, 16, reason: 'UNTIL 的冒号/分号必须保持原样才能解析');
  });
}
