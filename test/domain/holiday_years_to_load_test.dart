import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/holiday_resolver.dart';

/// 回归钉（2026-10-05 审查第 16 轮）：该加载哪几年的节假日数据。
///
/// 旧代码只有 `now.year`，外加「十一月之后预取下一年」这半边跨年假期意图，
/// 于是**一月初那一周**里属于上一年的日子（12-28..12-31）没有任何数据：
/// 本仓库自己的 fixture 就把元旦写成 2026-12-31 / 2027-01-01 / 2027-01-02 一段
/// 连续假期（`holiday_service.dart` 的 `_nameForGroup` 还为它特例过），
/// 结果是法定休息日在界面上照常排课、也不置灰；而 `refreshHolidayData` 同样
/// 只清 `now.year` 的缓存，用户手动刷新也修不回来。
void main() {
  DateTime weekStartOf(DateTime day) => DateTime(
    day.year,
    day.month,
    day.day - (day.weekday - DateTime.monday),
  );

  Iterable<DateTime> daily(int from, int to) sync* {
    var cursor = DateTime(from, 1);
    final stop = DateTime(to, 1);
    while (cursor.isBefore(stop)) {
      yield cursor;
      cursor = cursor.add(const Duration(days: 1));
    }
  }

  test('不变量：当前这一周（周一起算）里出现过的年份都必须被加载', () {
    for (final day in daily(2025, 2029)) {
      final years = holidayYearsToLoad(day);
      expect(years, contains(day.year), reason: '$day 自己的年份');
      final weekStart = weekStartOf(day);
      for (var offset = 0; offset < 7; offset++) {
        final inWeek = weekStart.add(Duration(days: offset));
        expect(
          years,
          contains(inWeek.year),
          reason: '$day 所在周的第 $offset 天是 $inWeek',
        );
      }
    }
  });

  test('元旦跨年那一周：2027-01-01 必须连 2026 一起加载', () {
    // 2027-01-01 是周五，这一周为 2026-12-28 .. 2027-01-03。
    expect(holidayYearsToLoad(DateTime(2027, 1)), {2026, 2027});
    expect(holidayYearsToLoad(DateTime(2027, 1, 3)), {2026, 2027});
  });

  test('保留既有意图：十一月之后仍然预取下一年', () {
    expect(holidayYearsToLoad(DateTime(2026, 11, 10)), {2026, 2027});
    // 12-30 落在 12-28..2027-01-03 这一周里，两侧都要。
    expect(holidayYearsToLoad(DateTime(2026, 12, 30)), {2026, 2027});
  });

  test('对照：平时不多取任何年份', () {
    for (final day in [
      DateTime(2026, 3, 11),
      DateTime(2026, 7, 8),
      DateTime(2026, 10, 14),
      DateTime(2026, 1, 15),
    ]) {
      expect(holidayYearsToLoad(day), {day.year}, reason: '$day');
    }
  });

  test('旧规则是新集合的子集：不会因为改动少加载任何一年', () {
    for (final day in daily(2025, 2029)) {
      final years = holidayYearsToLoad(day);
      expect(years, contains(day.year));
      if (day.month >= 11) {
        expect(years, contains(day.year + 1), reason: '$day 属旧规则的预取年');
      }
    }
  });
}
