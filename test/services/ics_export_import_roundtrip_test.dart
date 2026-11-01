import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/ics_export_service.dart';
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
  /// 导出侧的 DESCRIPTION 形状（2026-11 起每行都带明确前缀）：
  /// `Teacher: X` → `Location: Y` → `Sections: X-Y` → `Description: ...`。
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
      if (location != null && location.trim().isNotEmpty)
        'Location: $location',
      'Sections: $sections',
      if (extraDescription != null) 'Description: $extraDescription',
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

  // ── 2026-11 缺陷：导出 → 导入把课程描述错当教师 / 地点 ──
  //
  // 导出侧以前把 `description` / `note` / 节次备注写成**裸行**。没有
  // `Teacher:` 行时，导入侧的位置式配对会把它们当成「地点 / 教师」：
  // 单行 → 整行当地点，多行 → 地点=描述、教师=备注，真正的 `LOCATION`
  // 被丢弃。现在导出给每一行都带前缀，导入侧优先认前缀、无前缀行不再
  // 参与位置式配对。下面用**真实导出服务**跑一遍，格式一漂就红。
  group('真实导出 → 导入：教师 / 地点 / 描述不串（2026-11）', () {
    TimetableProfile profileWith(List<Course> courses) => TimetableProfile(
      id: 'profile-1',
      name: '主课表',
      courses: courses,
      settings: TimetableSettings.defaults().copyWith(
        semesterWeekCount: 8,
        semesterStartDate: DateTime(2026, 3, 2),
      ),
      currentWeek: 1,
      createdAt: DateTime(2026, 2),
      lastUsedAt: DateTime(2026, 2),
    );

    IcsImportResult roundTrip(List<Course> courses) {
      final exported = IcsExportService().build(
        profile: profileWith(courses),
        fromDate: DateTime(2026, 3),
        toDate: DateTime(2026, 3, 31),
        eventTypes: const {IcsExportEventType.course},
        generatedAt: DateTime.utc(2026, 3),
      );
      return IcsImportService().parseWakeUpSchedule(exported.content);
    }

    test('没有教师、只剩地点 + 描述 + 备注：三项各归各位，互不冒充', () {
      final result = roundTrip([
        Course(
          id: 'c1',
          name: '大学物理',
          teacher: '',
          location: '理科楼-101',
          dayOfWeek: DateTime.monday,
          startSection: 3,
          endSection: 4,
          startTime: '10:00',
          endTime: '11:40',
          endWeek: 1,
          description: '实验课，需穿实验服',
          note: '带计算器',
        ),
      ]);

      expect(result.courses, hasLength(1));
      final course = result.courses.single;
      // 修复前：描述/备注会被当成地点/教师，而真实 LOCATION 消失。
      expect(course.teacher, isEmpty, reason: '描述与备注不许冒充教师');
      expect(course.location, '理科楼-101', reason: '真实的 LOCATION 不许被丢弃');
      expect(course.description, '实验课，需穿实验服');
      expect(course.note, '带计算器');
    });

    test('有教师的课：教师、地点、描述仍然各就各位', () {
      final result = roundTrip([
        Course(
          id: 'c2',
          name: '线性代数',
          teacher: '李老师',
          location: '教学楼 A101',
          dayOfWeek: DateTime.tuesday,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
          endWeek: 1,
          description: '课后作业见群',
          note: '单周带习题册',
        ),
      ]);

      expect(result.courses, hasLength(1));
      final course = result.courses.single;
      expect(course.teacher, '李老师');
      // 地点里本身带空格：旧口径会按空格把最后一个词剥成教师。
      expect(course.location, '教学楼 A101');
      expect(course.description, '课后作业见群');
      expect(course.note, '单周带习题册');
    });
  });
}
