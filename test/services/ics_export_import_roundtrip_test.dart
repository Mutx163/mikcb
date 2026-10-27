import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/ics_import_service.dart';

/// **往返**验收：本 App 导出的 .ics 必须能导回来（2026-10-27）。
///
/// ## 为什么需要它
///
/// 2026-09-26 审计 §3.1 记了一条：`ics_export_service.dart:318` 把节次写成
/// `Sections: ${startSection}-${endSection}`（英文），而
/// `ics_import_service.dart` 的解析只认中文 `第X-Y节`、**且只看描述的第一行**。
/// 导出侧的第一行是 `Teacher: ...` —— 两条都不满足，于是整门课被静默丢弃。
///
/// 后果不只是「第三方日历导不进」：**本 App 自己导出的文件也导不回来**。
/// 用户换机、备份恢复时导出一次再导入，得到的是空课表，而且没有任何提示
///（`_buildCourseFromEvent` 返回 null 就跳过，不记 warning）。
///
/// 这里钉的是导出侧的真实格式，不是手写的理想格式 —— 格式一旦漂移，测试先红。
void main() {
  /// 导出侧的 DESCRIPTION 形状：`Teacher: X` → `Sections: X-Y` → 其它。
  String exportedEvent({
    required String summary,
    required String start,
    required String end,
    String teacher = '张三',
    String sections = '1-2',
    String? location = '教三-201',
    String? extraDescription,
  }) {
    final descriptionParts = <String>[
      if (teacher.trim().isNotEmpty) 'Teacher: $teacher',
      'Sections: $sections',
      ?extraDescription,
    ];
    return '''
BEGIN:VEVENT
UID:test-uid
DTSTAMP:20260301T000000Z
DTSTART:$start
DTEND:$end
SUMMARY:$summary
${location == null ? '' : 'LOCATION:$location'}
DESCRIPTION:${descriptionParts.join(r'\n')}
END:VEVENT''';
  }

  String calendar(List<String> events) => '''
BEGIN:VCALENDAR
PRODID:-//Mutx163//Qingyu Timetable//EN
VERSION:2.0
${events.join('\n')}
END:VCALENDAR
''';

  group('导出 → 导入 往返', () {
    test('导出格式的节次 / 教师 / 地点都能读回来（原先整门课被丢弃）', () {
      final content = calendar([
        exportedEvent(
          summary: '高等数学',
          // 导出侧写 UTC，2026-03-02 08:00 (+08:00) = 00:00Z
          start: '20260302T000000Z',
          end: '20260302T014000Z',
          teacher: '张老师',
        ),
      ]);

      final result = IcsImportService().parseWakeUpSchedule(content);

      expect(
        result.courses,
        hasLength(1),
        reason: '本 App 导出的文件必须能导回来；为空说明节次行没被识别',
      );
      final course = result.courses.single;
      expect(course.name, '高等数学');
      expect(course.startSection, 1);
      expect(course.endSection, 2);
      expect(course.teacher, '张老师');
      expect(course.location, '教三-201');
    });

    test('节次不在第一行也能找到（导出侧第一行是 Teacher）', () {
      final content = calendar([
        exportedEvent(
          summary: '线性代数',
          start: '20260303T020000Z',
          end: '20260303T034000Z',
          teacher: '李老师',
          sections: '3-4',
        ),
      ]);

      final result = IcsImportService().parseWakeUpSchedule(content);
      expect(result.courses, hasLength(1));
      expect(result.courses.single.startSection, 3);
      expect(result.courses.single.endSection, 4);
    });

    test('`Sections: X-Y` 那一行不会被当成教师或地点写进课程', () {
      final content = calendar([
        exportedEvent(
          summary: '大学物理',
          start: '20260304T040000Z',
          end: '20260304T054000Z',
          teacher: '王老师',
          sections: '5-6',
          location: '理科楼-101',
        ),
      ]);

      final course = IcsImportService()
          .parseWakeUpSchedule(content)
          .courses
          .single;

      expect(course.teacher, isNot(contains('Sections')));
      expect(course.location, isNot(contains('Sections')));
      expect(course.teacher, isNot(contains('5-6')));
    });

    test('没有地点时也不会把节次行当地点', () {
      final content = calendar([
        exportedEvent(
          summary: '体育',
          start: '20260305T060000Z',
          end: '20260305T074000Z',
          teacher: '',
          sections: '7-8',
          location: null,
        ),
      ]);

      final course = IcsImportService()
          .parseWakeUpSchedule(content)
          .courses
          .single;
      expect(course.startSection, 7);
      expect(course.endSection, 8);
      expect(course.location, isNot(contains('Sections')));
    });
  });

  group('仍然接受原有的中文写法（不能因为加格式而破坏旧文件）', () {
    test('中文「第X - Y节」照常解析', () {
      const content = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
SUMMARY:基准课[16][必修]
DTSTART;TZID=/Asia/Shanghai:20260302T082000
DTEND;TZID=/Asia/Shanghai:20260302T100000
RRULE:FREQ=WEEKLY;UNTIL=20260308T160000Z;INTERVAL=1
LOCATION:A101 张老师
DESCRIPTION:第1 - 2节\\nA101\\n张老师
END:VEVENT
END:VCALENDAR
''';

      final course = IcsImportService()
          .parseWakeUpSchedule(content)
          .courses
          .single;
      expect(course.startSection, 1);
      expect(course.endSection, 2);
      expect(course.location, 'A101');
      expect(course.teacher, '张老师');
    });

    test('常见第三方写法 Period / Section 也能认', () {
      for (final line in ['Period 3-4', 'Section 3-4', 'Periods: 3-4']) {
        final content = calendar([
          '''
BEGIN:VEVENT
UID:u
DTSTAMP:20260301T000000Z
DTSTART:20260302T000000Z
DTEND:20260302T014000Z
SUMMARY:外语
DESCRIPTION:$line
END:VEVENT''',
        ]);
        final courses = IcsImportService().parseWakeUpSchedule(content).courses;
        expect(
          courses,
          hasLength(1),
          reason: '写法 `$line` 应当被识别',
        );
        expect(courses.single.startSection, 3, reason: '写法 `$line`');
        expect(courses.single.endSection, 4, reason: '写法 `$line`');
      }
    });
  });

  group('不猜节次（猜错比不导入更糟）', () {
    test('描述里完全没有节次信息时仍然丢弃，不编一个出来', () {
      final content = calendar([
        '''
BEGIN:VEVENT
UID:u
DTSTAMP:20260301T000000Z
DTSTART:20260302T000000Z
DTEND:20260302T014000Z
SUMMARY:来路不明的课
DESCRIPTION:Teacher: 某人\\n就是没写第几节
LOCATION:某处
END:VEVENT''',
      ]);

      expect(
        IcsImportService().parseWakeUpSchedule(content).courses,
        isEmpty,
        reason: '没有节次就不该收 —— 猜一个会让课显示在错误的时间格上',
      );
    });

    test('只有单个数字（不是区间）时不认', () {
      final content = calendar([
        '''
BEGIN:VEVENT
UID:u
DTSTAMP:20260301T000000Z
DTSTART:20260302T000000Z
DTEND:20260302T014000Z
SUMMARY:单节号
DESCRIPTION:Sections: 3
END:VEVENT''',
      ]);

      expect(IcsImportService().parseWakeUpSchedule(content).courses, isEmpty);
    });
  });
}
