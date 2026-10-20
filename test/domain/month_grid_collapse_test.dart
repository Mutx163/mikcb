// 月网格收起 / 展开判据测试（2026-10-20）。
//
// 期望值全部**人推**，不从实现里抄：
// - 2026-10 网格从 09-28（周一）起（对照真实日历，与 month_view_logic_test 同一fixture）：
//   10-05 是网格第 8 天 → 行 1（0 基）；10-20 是第 23 天 → 行 3。
// - 2027-02 网格无前导补位（02-01 恰为周一），从 02-01 到 03-14：
//   远月页（无今天、无选中）保留 1 号所在行 = 行 0。
// - 插值：进度 0.5 时可见行数 = 1 + (6-1)×0.5 = 3.5。
// - 吸附：行程阈值 0.35、速度阈值 180，都是"明确意图才翻面"的人为取舍。
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/month_grid_collapse.dart';

DateTime d(int year, int month, int day) => DateTime(year, month, day);

/// 2026-10 的 42 格：09-28（周一）起（人推：10-01 是周四）。
List<DateTime> october2026() => [
  for (var i = 0; i < 42; i++) d(2026, 9, 28).add(Duration(days: i)),
];

void main() {
  group('monthGridRowToKeep：收起保留哪一行', () {
    test('无选中：保留今天所在行（10-20 在第 4 行，0 基 3）', () {
      final row = monthGridRowToKeep(
        dates: october2026(),
        year: 2026,
        month: 10,
        today: d(2026, 10, 20),
      );
      expect(row, 3);
    });

    test('有选中：选中日压过今天（10-05 在第 2 行，0 基 1）', () {
      final row = monthGridRowToKeep(
        dates: october2026(),
        year: 2026,
        month: 10,
        selectedDate: d(2026, 10, 5),
        today: d(2026, 10, 20),
      );
      expect(row, 1);
    });

    test('选中的日子不在这一页（日期属于别的月）：回落今天', () {
      final row = monthGridRowToKeep(
        dates: october2026(),
        year: 2026,
        month: 10,
        selectedDate: d(2026, 12, 25),
        today: d(2026, 10, 20),
      );
      expect(row, 3);
    });

    test('远月页（无今天、无选中）：保留本月 1 号所在行', () {
      // 2027-02：02-01 是周一 → 网格 02-01..03-14，1 号在行 0。
      final dates = [
        for (var i = 0; i < 42; i++) d(2027, 2, 1).add(Duration(days: i)),
      ];
      final row = monthGridRowToKeep(
        dates: dates,
        year: 2027,
        month: 2,
        today: d(2026, 10, 20),
      );
      expect(row, 0);
    });

    test('空日期列表：钳到 0，不抛异常（渲染路径宁可画第一行）', () {
      final row = monthGridRowToKeep(
        dates: const [],
        year: 2026,
        month: 10,
        today: d(2026, 10, 20),
      );
      expect(row, 0);
    });
  });

  group('monthGridVisibleRows：行数按进度线性插值', () {
    test('0 = 收起（1 行）、1 = 展开（6 行）', () {
      expect(monthGridVisibleRows(0), 1.0);
      expect(monthGridVisibleRows(1), 6.0);
    });

    test('中间值：1 + 5×t（0.5 → 3.5）', () {
      expect(monthGridVisibleRows(0.5), 3.5);
      expect(monthGridVisibleRows(0.2), closeTo(2.0, 1e-9));
      expect(monthGridVisibleRows(0.8), closeTo(5.0, 1e-9));
    });

    test('越界进度钳回两端（拖拽累加不会把窗口算成负数）', () {
      expect(monthGridVisibleRows(-3), 1.0);
      expect(monthGridVisibleRows(42), 6.0);
    });
  });

  group('monthGridSettleTarget：松手吸附', () {
    test('向上甩（速度 ≤ -180）压倒一切：收起', () {
      expect(
        monthGridSettleTarget(
          startValue: 1,
          currentValue: 0.98,
          velocityDy: -300,
        ),
        0,
      );
      expect(
        monthGridSettleTarget(
          startValue: 0,
          currentValue: 0.02,
          velocityDy: -180,
        ),
        0,
      );
    });

    test('向下甩（速度 ≥ 180）：展开', () {
      expect(
        monthGridSettleTarget(
          startValue: 0,
          currentValue: 0.02,
          velocityDy: 300,
        ),
        1,
      );
    });

    test('没甩够速度但拖过行程阈值（0.35）：吸附到对面', () {
      // 从展开往下拖了 40%。
      expect(
        monthGridSettleTarget(startValue: 1, currentValue: 0.6, velocityDy: 0),
        0,
      );
      // 从收起往上拉了 40%。
      expect(
        monthGridSettleTarget(startValue: 0, currentValue: 0.4, velocityDy: 0),
        1,
      );
    });

    test('行程不够：弹回起点状态（临界点抖动不翻面）', () {
      expect(
        monthGridSettleTarget(startValue: 1, currentValue: 0.8, velocityDy: 0),
        1,
      );
      expect(
        monthGridSettleTarget(startValue: 0, currentValue: 0.2, velocityDy: 0),
        0,
      );
    });
  });

  group('常量口径', () {
    test('42 格的合法行号范围是 0..5', () {
      expect(monthGridRowBounds(), (0, 5));
    });

    test('行程阈值在 (0, 0.5) 区间：轻划可翻面、又不至于误触', () {
      expect(kMonthGridFlipTravel, greaterThan(0));
      expect(kMonthGridFlipTravel, lessThan(0.5));
    });
  });
}
