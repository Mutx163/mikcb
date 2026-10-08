import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/import_export_logic.dart';
import 'package:university_timetable/models/time_scheme.dart';
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

  group('补出的末节正好收在当天结束（1440）', () {
    // 课间 15 / 单节 45、末节 22:15-23:00 ⇒ 补出来的是 23:15-24:00，正好压在边界上。
    // （课间取自**末两个节次之间**那个正间隔，所以第三、四节要挨着写。）
    //
    // 原先 `_formatClockMinutes` 只有 `% 1440` 归一（`import_export_logic.dart` 里
    // 那份是 `models/time_scheme.dart` 的 `_minutesToClock` 的**第二份副本**，且少了
    // 后者专门写的 1440 例外），于是这一节被写成 `00:00`：结束时间解析回 0 分钟，
    // 比开始时间还小 —— 紧接着 `validateSectionTimes` 报「第 N 节结束时间必须晚于
    // 开始时间」，用户按提示怎么改都存不下，而导入侧还在拿这张畸形表烤课程钟点。
    List<SectionTime> template() => const [
      SectionTime(startTime: '08:00', endTime: '08:45'),
      SectionTime(startTime: '09:00', endTime: '09:45'),
      SectionTime(startTime: '21:15', endTime: '22:00'),
      SectionTime(startTime: '22:15', endTime: '23:00'),
    ];

    test('末节写成 24:00 而不是回绕成 00:00', () {
      final expanded = ImportExportLogic.buildExpandedSections(template(), 5);

      expect(expanded, hasLength(5));
      expect(expanded.last.startTime, '23:15');
      expect(
        expanded.last.endTime,
        '24:00',
        reason: '1440 回绕成 00:00 会让这一节的结束时间小于开始时间，整张作息存不下',
      );
    });

    test('补出来的表能通过 validateSectionTimes', () {
      final expanded = ImportExportLogic.buildExpandedSections(template(), 5);

      expect(
        validateSectionTimes(expanded),
        isNull,
        reason: '补节的目标是让导入的课次有时间可用；补出一张自己都存不下的表没有意义',
      );
    });
  });
}
