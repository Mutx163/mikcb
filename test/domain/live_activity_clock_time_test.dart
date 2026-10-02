import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/live_activity_logic.dart';

/// 超级岛/桌面卡片那条链上的钟点解析（回归钉，2026-10-02）。
///
/// `LiveActivityLogic.parseClockMinutes` / `buildCourseDateTime` 原先只检查
/// 「两段 + 是数字」，**不检查范围**，然后把值直接交给
/// `DateTime(y, m, d, hour, minute)` —— Dart 会静默归一：
/// - `25:00` → **次日** 01:00：超级岛的课堂时间轴与自动响点整体挪到明天；
/// - `08:75` → 09:15：显示的是一节不存在的时间；
/// - `-8:30` → 前一天的 15:30。
/// 同仓的 `ClassReminderService.parseClockMinutes`（:25-27）和
/// `SystemAlarmLogic.parseClockMinutes`（:90）都带 0..23 / 0..59 守卫，只有这条
/// 链漏了，于是同一份畸形作息会出现「岛上有、闹钟没有」这种对不上的状态。
///
/// 现在三条链共用 `ClockTime.tryParse`。`24:00` 仍被放行（晚自习末节的合法写法，
/// 换算成日期恰是次日 00:00，语义正确），但 `24:30` 这种不合法的组合一律拒绝。
void main() {
  group('parseClockMinutes', () {
    test('接受合法与未补零的钟点', () {
      expect(LiveActivityLogic.parseClockMinutes('08:30'), 510);
      expect(LiveActivityLogic.parseClockMinutes('8:05'), 485);
      expect(LiveActivityLogic.parseClockMinutes(' 09 : 40 '), 580);
      expect(LiveActivityLogic.parseClockMinutes('23:59'), 1439);
    });

    test('放行当天结束的 24:00', () {
      expect(LiveActivityLogic.parseClockMinutes('24:00'), 1440);
    });

    test('拒绝越界与畸形，而不是算出一个错分钟数', () {
      // 修复前：25:00 → 1500、08:75 → 555、-8:30 → -450、24:30 → 1470。
      for (final bad in [
        '25:00',
        '24:30',
        '08:75',
        '08:-1',
        '-8:30',
        '08:30:00',
        '08.30',
        '上午8点',
        '',
        ' ',
        'x:y',
      ]) {
        expect(LiveActivityLogic.parseClockMinutes(bad), isNull, reason: bad);
      }
    });
  });

  group('buildCourseDateTime', () {
    final day = DateTime(2026, 10, 2);

    test('落在同一天的墙上时间', () {
      expect(
        LiveActivityLogic.buildCourseDateTime(day, '08:30'),
        DateTime(2026, 10, 2, 8, 30),
      );
    });

    test('24:00 表示当天结束，即次日零点', () {
      expect(
        LiveActivityLogic.buildCourseDateTime(day, '24:00'),
        DateTime(2026, 10, 3, 0, 0),
      );
    });

    test('越界值返回 null，不再把课程挪到别的日子', () {
      // 修复前 `25:00` 会被静默归一成 2026-10-03 01:00。
      expect(LiveActivityLogic.buildCourseDateTime(day, '25:00'), isNull);
      expect(LiveActivityLogic.buildCourseDateTime(day, '08:75'), isNull);
      expect(LiveActivityLogic.buildCourseDateTime(day, '24:30'), isNull);
    });
  });
}
