import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/import_export_logic.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/utils/clock_time.dart';

/// 导入扩节不得越过"当天结束"（第 35 轮）。
///
/// `buildExpandedSections` 在导入的课表用到的节数多于当前作息模板时，从**最后一条能解析的
/// 结束时间**往后补节。锚点取自本文件私有的 `_parseClockToMinutes` —— 它是
/// `ClockTime.tryParse` 的第三份副本且**不带 `allowEndOfDay`**（`hour > 23` 判非法）。
/// 而 `24:00` 是本仓认可的"当天结束"（`models/time_scheme.dart:229-240`、
/// 原生 `LiveClock.minutesOfDay` 同样放行；`test/models/time_scheme_quick_generate_midnight_test.dart`
/// 钉着快速生成作息的末节就是 24:00）。于是末节写着 `23:00-24:00` 的模板锚点会退到
/// **倒数第二节**的结束时间（如 22:10），补出 22:20-23:05 这类与已有节次**重叠**的时间；
/// 而 `_formatClockMinutes` 用 `% 1440` 归一，当天余量不足时补出的节次会绕回凌晨
/// （`00:25` 当第 6 节）。`import_export_service.dart:171` 正是拿这张展开表烤导入课程的钟点。
void main() {
  int minutesOf(String clock) =>
      ClockTime.tryParse(clock, allowEndOfDay: true)!.totalMinutes;

  List<SectionTime> endingAt(String lastEnd) => [
    const SectionTime(startTime: '08:00', endTime: '08:45'),
    const SectionTime(startTime: '09:00', endTime: '09:45'),
    const SectionTime(startTime: '21:25', endTime: '22:10'),
    SectionTime(startTime: '23:00', endTime: lastEnd),
  ];

  group('末节 24:00 的模板（当天已无余量）', () {
    test('停止补节：不补出与已有节次重叠的钟点', () {
      final sections = endingAt('24:00');

      final expanded = ImportExportLogic.buildExpandedSections(sections, 6);

      expect(
        expanded.length,
        sections.length,
        reason:
            '末节已到当天结束还继续补 = 锚点退到倒数第二节（22:10），'
            '补出来的节次排在 22:20 之前，与已有的 23:00-24:00 重叠',
      );
    });

    test('已有节次的钟点原样保留', () {
      final expanded = ImportExportLogic.buildExpandedSections(
        endingAt('24:00'),
        6,
      );

      expect(expanded.map((s) => s.startTime), [
        '08:00',
        '09:00',
        '21:25',
        '23:00',
      ]);
      expect(expanded.map((s) => s.endTime), [
        '08:45',
        '09:45',
        '22:10',
        '24:00',
      ]);
    });
  });

  group('有余量时仍按原语义补节', () {
    test('白天模板补节的时长与课间都取自模板自身', () {
      final expanded = ImportExportLogic.buildExpandedSections(const [
        SectionTime(startTime: '08:00', endTime: '08:45'),
        SectionTime(startTime: '09:00', endTime: '09:45'),
      ], 4);

      expect(expanded, hasLength(4));
      expect(expanded[2].startTime, '10:00');
      expect(expanded[2].endTime, '10:45');
      expect(expanded[3].startTime, '11:00');
      expect(expanded[3].endTime, '11:45');
    });

    test('补出来的每一节都必须严格排在前一节之后、且不跨过当天结束', () {
      // 末节 23:50：只有一节的余量，第二节的结束时间会绕到次日凌晨。
      final expanded = ImportExportLogic.buildExpandedSections(const [
        SectionTime(startTime: '08:00', endTime: '08:45'),
        SectionTime(startTime: '23:10', endTime: '23:50'),
      ], 6);

      for (var i = 1; i < expanded.length; i++) {
        expect(
          minutesOf(expanded[i].startTime) >
              minutesOf(expanded[i - 1].startTime),
          isTrue,
          reason:
              '第 ${i + 1} 节没有严格排在前一节之后：'
              '${expanded[i - 1].startTime}-${expanded[i - 1].endTime} 之后是 '
              '${expanded[i].startTime}-${expanded[i].endTime}',
        );
        expect(
          minutesOf(expanded[i].endTime) <= 24 * 60,
          isTrue,
          reason: '补出的节次绕回了次日凌晨：${expanded[i].endTime}',
        );
      }
    });
  });

  test('一条结束时间都解析不出来时不凭空编时间', () {
    final expanded = ImportExportLogic.buildExpandedSections(const [
      SectionTime(startTime: '上午8点', endTime: '非法串'),
    ], 5);

    expect(expanded.length, 1);
  });
}
