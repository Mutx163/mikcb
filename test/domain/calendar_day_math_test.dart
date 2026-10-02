import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/week_calculator.dart';

/// 日历日算术的不变量（2026-10-02 审查后收口）。
///
/// 本仓原先到处用本地 `DateTime` 的**绝对时长**表达**日历日**语义：
/// `a.difference(b).inDays` 数的是经过的时间，`base.add(Duration(days: n))` 数的是
/// n×24 小时。实行夏令时的时区里跨「拨快」那一夜只有 23 小时、跨「拨慢」有 25
/// 小时，于是周次数少一周、日期挪一天 —— 上游已经为这件事修过一次（ff0ae83d 把
/// 周次推导从 `difference().inDays ~/ 7` 换成 `WeekCalculator.getWeekIndex`），
/// 本次把剩下的同类调用点收口到这里的 [WeekCalculator.addDays] /
/// [WeekCalculator.daysBetween]。
///
/// 这些断言在任何机器时区下都成立（`addDays` 的定义就是「按日历日」），在实行
/// 夏令时的时区里它们会把旧写法照出为失败：例如 America/New_York 下
/// `DateTime(2026,3,8).add(Duration(days: 7))` 的 weekday 不再是周一。
void main() {
  group('addDays', () {
    test('推进的是日历日，同时保留墙上时间', () {
      final base = DateTime(2026, 3, 7, 23, 30, 15);

      final next = WeekCalculator.addDays(base, 1);
      expect(next.year, 2026);
      expect(next.month, 3);
      expect(next.day, 8);
      expect(next.hour, 23);
      expect(next.minute, 30);
      expect(next.second, 15);
    });

    test('跨月末与闰年正确归一', () {
      expect(
        WeekCalculator.addDays(DateTime(2026, 1, 31), 1),
        DateTime(2026, 2),
      );
      expect(
        WeekCalculator.addDays(DateTime(2028, 2, 28), 1),
        DateTime(2028, 2, 29),
      );
      expect(
        WeekCalculator.addDays(DateTime(2026, 12, 31), 1),
        DateTime(2027),
      );
      expect(
        WeekCalculator.addDays(DateTime(2026, 3), -1),
        DateTime(2026, 2, 28),
      );
    });

    test('加 7 天回到同一个星期几，且始终是零点', () {
      for (var week = 0; week < 12; week++) {
        final monday = WeekCalculator.addDays(DateTime(2026, 3, 2), week * 7);
        expect(monday.weekday, DateTime.monday, reason: '第 $week 周起点应是周一');
        expect(monday.hour, 0);
        expect(monday.minute, 0);
      }
    });
  });

  group('daysBetween', () {
    test('数的是日历日，不看经过了几小时', () {
      expect(WeekCalculator.daysBetween(DateTime(2026, 3, 7), DateTime(2026, 3, 8)), 1);
      expect(
        WeekCalculator.daysBetween(
          DateTime(2026, 3, 7, 23, 59),
          DateTime(2026, 3, 8, 0, 1),
        ),
        1,
        reason: '跨午夜的两分钟仍是一个日历日差',
      );
      expect(WeekCalculator.daysBetween(DateTime(2026, 3, 8), DateTime(2026, 3, 7)), -1);
      expect(WeekCalculator.daysBetween(DateTime(2026, 3, 8, 20), DateTime(2026, 3, 8, 4)), 0);
    });

    test('跨年与 366 天学期', () {
      expect(
        WeekCalculator.daysBetween(DateTime(2026, 12, 31), DateTime(2027)),
        1,
      );
      expect(
        WeekCalculator.daysBetween(DateTime(2028), DateTime(2028, 12, 31)),
        365,
      );
    });

    test('startOfWeek 永远是周一零点', () {
      for (var offset = 0; offset < 30; offset++) {
        final day = WeekCalculator.addDays(DateTime(2026, 3, 2), offset);
        final monday = WeekCalculator.startOfWeek(day);
        expect(monday.weekday, DateTime.monday);
        expect(monday.hour, 0);
        expect(monday.isAfter(day), isFalse);
        expect(WeekCalculator.daysBetween(monday, day), lessThan(7));
      }
    });

    test('getWeekIndex 与 daysBetween 同口径', () {
      final semesterStart = DateTime(2026, 9, 7);
      expect(WeekCalculator.getWeekIndex(DateTime(2026, 9, 7), semesterStart), 1);
      expect(WeekCalculator.getWeekIndex(DateTime(2026, 9, 13), semesterStart), 1);
      expect(WeekCalculator.getWeekIndex(DateTime(2026, 9, 14), semesterStart), 2);
      expect(WeekCalculator.getWeekIndex(DateTime(2026, 9, 6), semesterStart), isNull);
    });
  });
}
