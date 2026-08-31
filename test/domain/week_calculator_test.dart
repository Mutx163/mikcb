import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/week_calculator.dart';

// 2026-08-24 为周一（本周），2026-08-29 为周六，2026-08-30 为周日。
void main() {
  group('WeekCalculator.startOfWeek', () {
    test('任意时刻归到本周周一 00:00', () {
      final result = WeekCalculator.startOfWeek(DateTime(2026, 8, 29, 15, 42));
      expect(result, DateTime(2026, 8, 24));
      expect(result.weekday, DateTime.monday);
    });

    test('周一当天归到自身零点', () {
      final result = WeekCalculator.startOfWeek(DateTime(2026, 8, 24, 15, 30));
      expect(result, DateTime(2026, 8, 24));
    });

    test('周日归到本周周一而非下周', () {
      final result = WeekCalculator.startOfWeek(DateTime(2026, 8, 30, 23));
      expect(result, DateTime(2026, 8, 24));
    });
  });

  group('WeekCalculator.getWeekIndex', () {
    final semesterStart = DateTime(2026, 8, 24); // 周一

    test('开学当天为第 1 周', () {
      expect(WeekCalculator.getWeekIndex(semesterStart, semesterStart), 1);
    });

    test('同周内（+6 天）仍为第 1 周', () {
      expect(
        WeekCalculator.getWeekIndex(DateTime(2026, 8, 30), semesterStart),
        1,
      );
    });

    test('+7 天进入第 2 周', () {
      expect(
        WeekCalculator.getWeekIndex(DateTime(2026, 8, 31), semesterStart),
        2,
      );
    });

    test('开学前返回 null', () {
      expect(
        WeekCalculator.getWeekIndex(DateTime(2026, 8, 23), semesterStart),
        isNull,
      );
    });

    test('开学日为周中（周三）时，对齐到该周周一', () {
      final wedStart = DateTime(2026, 8, 26); // 周三
      // 该周周一与开学同周 → 第 1 周
      expect(
        WeekCalculator.getWeekIndex(DateTime(2026, 8, 24), wedStart),
        1,
      );
      // 该周周一之前 → null
      expect(
        WeekCalculator.getWeekIndex(DateTime(2026, 8, 23), wedStart),
        isNull,
      );
    });
  });

  group('WeekCalculator.weekForDate（教学周，钳制口径）', () {
    final semesterStart = DateTime(2026, 8, 24);

    test('学期未配置时返回 fallback', () {
      expect(
        WeekCalculator.weekForDate(
          DateTime(2026, 8, 29),
          semesterStart: null,
          semesterWeekCount: 18,
          fallback: 5,
        ),
        5,
      );
    });

    test('开学前一律第 1 周（不取 fallback）', () {
      expect(
        WeekCalculator.weekForDate(
          DateTime(2026, 8, 23),
          semesterStart: semesterStart,
          semesterWeekCount: 18,
          fallback: 5,
        ),
        1,
      );
    });

    test('学期中返回真实教学周', () {
      expect(
        WeekCalculator.weekForDate(
          DateTime(2026, 9),
          semesterStart: semesterStart,
          semesterWeekCount: 18,
          fallback: 5,
        ),
        2,
      );
    });

    test('超出学期周数钳制到最后一周', () {
      expect(
        WeekCalculator.weekForDate(
          semesterStart.add(const Duration(days: 20 * 7)),
          semesterStart: semesterStart,
          semesterWeekCount: 18,
          fallback: 5,
        ),
        18,
      );
    });
  });

  group('WeekCalculator.calendarWeekForDate（日历周，不钳制口径）', () {
    final semesterStart = DateTime(2026, 8, 24);

    test('学期未配置时返回 fallback', () {
      expect(
        WeekCalculator.calendarWeekForDate(
          DateTime(2026, 8, 29),
          semesterStart: null,
          fallback: 7,
        ),
        7,
      );
    });

    test('开学前返回 0（避免课程提前显示）', () {
      expect(
        WeekCalculator.calendarWeekForDate(
          DateTime(2026, 8, 23),
          semesterStart: semesterStart,
          fallback: 7,
        ),
        0,
      );
    });

    test('学期中返回真实周次', () {
      expect(
        WeekCalculator.calendarWeekForDate(
          DateTime(2026, 9),
          semesterStart: semesterStart,
          fallback: 7,
        ),
        2,
      );
    });

    test('超出配置学期周数不钳制（超级岛口径）', () {
      expect(
        WeekCalculator.calendarWeekForDate(
          semesterStart.add(const Duration(days: 20 * 7)),
          semesterStart: semesterStart,
          fallback: 7,
        ),
        21,
      );
    });
  });
}
