import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/ai_course_import_service.dart';

/// AI 视觉解析结果里的节次越界不能被"造一个钟点"糊过去（2026-10-05 审查）。
///
/// `ai_course_import_service.dart:236-241`：
/// ```dart
/// final startTime = startSection <= settings.sectionCount
///     ? settings.sections[startSection - 1].startTime
///     : '00:00';
/// final endTime = endSection <= settings.sectionCount
///     ? settings.sections[endSection - 1].endTime
///     : '00:00';
/// ```
/// 上面 :194-213 已经把 `dayOfWeek`（1~7）、`startSection >= 1`、
/// `endSection >= startSection` 都当成**必须拒收**的畸形输入，唯独漏了上界：
/// 模型/作息只有 8 节而 AI 返回第 12 节时，它不报错，而是**凭空给一门课编一个
/// `00:00` 的钟点**收下。后果分两层：
/// 1. 这门课挂在一个不存在的节次上、钟点是假的 00:00，日视图/时间轴/统计都按它算；
/// 2. `updateTimetableSettings` 的守卫是 `sectionConfigChanged && settings.sectionCount < maxUsedSection`
///    → 返回 `section_count_below_usage` 并**拒绝**这次设置保存（provider 里同款守卫还有
///    `ensureSectionCapacityForImport` 走"扩表"路径），于是用户之后想改节次数会被
///    "有课排到第 12 节"卡住，而那门课在界面上根本不存在第 12 节。
///
/// 同一个错误在别的入口是有正确话术的：`section_count_below_usage`（本地化在四种语言里
/// 都有）。所以这里不是新增规则，而是把这条入口补上同一道校验、复用同一句话。
void main() {
  final settings = TimetableSettings.defaults().copyWith(
    sections: const [
      SectionTime(startTime: '08:00', endTime: '08:45'),
      SectionTime(startTime: '09:00', endTime: '09:45'),
    ],
  );

  String aiResult({required int startSection, required int endSection}) {
    return jsonEncode({
      'schema': AiCourseImportService.schema,
      'courses': [
        {
          'name': '高等数学',
          'teacher': '王老师',
          'location': 'A101',
          'dayOfWeek': 1,
          'startSection': startSection,
          'endSection': endSection,
          'customWeeks': const [1, 2, 3],
          'courseNature': 'required',
        },
      ],
      'warnings': <String>[],
    });
  }

  group('AI 解析的节次上界', () {
    test('节次超出课表时必须拒收，而不是给这门课编一个 00:00', () {
      final service = AiCourseImportService();

      expect(
        () => service.parse(
          aiResult(startSection: 1, endSection: 5),
          settings: settings,
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('section_count_below_usage'),
          ),
        ),
        reason: '越界节次被静默收下 = 一门有假钟点的课 + 之后改节次数被它永久卡住',
      );
    });

    test('起始节次本身就越界时同样拒收', () {
      final service = AiCourseImportService();

      expect(
        () => service.parse(
          aiResult(startSection: 4, endSection: 6),
          settings: settings,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('对照：最后一节以内照常接受，钟点取真实节次', () {
      final service = AiCourseImportService();

      final result = service.parse(
        aiResult(startSection: 1, endSection: 2),
        settings: settings,
      );

      final course = result.courses.single;
      expect(course.startTime, '08:00');
      expect(course.endTime, '09:45');
      expect(course.startWeek, 1);
      expect(course.endWeek, 3);
    });
  });

  /// 上面的拒收是**对的**（越界必须拒），但界面得先有机会补救：解析在弹
  /// 「要不要自动补齐节次」之前发生，于是那个弹窗永远到不了 —— 用户只收到一句
  /// 「节次数不足」，却没有任何办法把这批课导进来。`maxSectionIn` 就是那一步预扫：
  /// 只看 `endSection`、读不到就跳过，让界面**先扩节、再解析**（2026-10-08）。
  group('导入前的节次预扫', () {
    test('越界结果能预扫出真实的最大节次，供界面先扩节', () {
      final service = AiCourseImportService();

      expect(
        service.maxSectionIn(aiResult(startSection: 1, endSection: 5)),
        5,
        reason: '预扫读不出这个数字，界面就不可能在解析前弹自动补齐',
      );
    });

    test('多门课取最大，且不因为某一项畸形就放弃整个预扫', () {
      final service = AiCourseImportService();
      final content = jsonEncode({
        'schema': AiCourseImportService.schema,
        'courses': [
          {
            'name': '高等数学',
            'dayOfWeek': 1,
            'startSection': 1,
            'endSection': 3,
            'customWeeks': const [1],
          },
          // 这一项读不出来，跳过即可 —— 预扫的职责是"要不要先扩节"，不是校验。
          {'name': '坏项', 'endSection': '上午'},
          {
            'name': '大学英语',
            'dayOfWeek': 2,
            'startSection': 1,
            'endSection': 7,
            'customWeeks': const [1],
          },
        ],
        'warnings': <String>[],
      });

      expect(service.maxSectionIn(content), 7);
    });

    test('读不出任何节次时返回 null（让 parse 去报真正的错）', () {
      final service = AiCourseImportService();

      expect(service.maxSectionIn('{ 不是 JSON'), isNull);
      expect(
        service.maxSectionIn(jsonEncode({'schema': 'x', 'courses': <Object>[]})),
        isNull,
      );
      expect(
        service.maxSectionIn(aiResult(startSection: 1, endSection: 2)),
        2,
        reason: '合法结果同样给出最大值；界面只在它大于当前节数时才动手',
      );
    });
  });
}
