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

  group('收起几何：行区窗口 + 表头不参与滚动', () {
    // 这三条钉的是 2026-10-21 那次返工的判据。当时窗口高度算成
    // `表头 + 可见行数×行高`，但内容整体上移把表头也推出了窗口 ——
    // 于是"收起不彻底、露出半格上一行、表头消失"。
    //
    // 现在的不变式：**行区窗口只按可见行数算**，表头是它外面的固定块。
    test('收起态（t=0）行区窗口恰好 1 行高', () {
      const rowHeight = 50.0;
      final window = monthGridVisibleRows(0) * rowHeight;
      expect(window, 50.0);
    });

    test('展开态（t=1）行区窗口恰好 6 行高', () {
      const rowHeight = 50.0;
      final window = monthGridVisibleRows(1) * rowHeight;
      expect(window, 300.0);
    });

    test('行区窗口不含表头：任何进度下都等于「可见行数 × 行高」', () {
      const rowHeight = 50.0;
      for (final t in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        final window = monthGridVisibleRows(t) * rowHeight;
        // 窗口若是"表头 + 行"，收起态就会是 24+50=74 而不是 50 ——
        // 多出的 24px 正是露出上一行的来源。这里钉的正是「只有行、没有表头」。
        expect(window, closeTo(monthGridVisibleRows(t) * rowHeight, 1e-9));
        expect(
          window,
          lessThan(monthGridVisibleRows(t) * rowHeight + 1),
          reason: '窗口不许额外加表头高度',
        );
      }
    });

    test('收起位移：保留行被推到窗口内（3 行 × 行高 × 0.65 的中间态）', () {
      const rowHeight = 50.0;
      const keptRow = 3;
      // t = 0.35 时位移应为 3×50×0.65 = 97.5（人推）。
      const offset = keptRow * rowHeight * (1 - 0.35);
      expect(offset, closeTo(97.5, 1e-9));
    });
  });

  group('monthGridRowHeight：格子要正方形', () {
    // 判据：取「高度能给的」与「宽度能给的」较小者。
    // 参考机（360 逻辑宽、可用高 520）：宽向 = (360-20-30)/7 = 44.28…，
    // 高向 = 520/6 = 86.67 → 取 44.28，正好是格宽 ⇒ 正方形。
    test('手机竖屏：宽度更紧，行高 = 格宽（正方形）', () {
      final h = monthGridRowHeight(
        availableWidth: 360,
        availableForGrid: 520,
        weekNumberColumnVisible: true,
        horizontalPadding: 10,
        weekLabelWidth: 30,
        minRowHeight: 44,
        maxRowHeight: 78,
      );
      // 人推：(360 - 20 - 30) / 7 = 44.2857…
      expect(h, closeTo(310 / 7, 1e-9));
    });

    test('旧口径的形状（只按高度均分）会被宽度这一侧压住，不再拉长', () {
      // 假如只按高度：520/6 = 86.67，会 clamp 到上限 78 —— 远高于格宽 44.3，
      // 那正是用户看到的"上下的长方形"。新口径必须远低于 78。
      final h = monthGridRowHeight(
        availableWidth: 360,
        availableForGrid: 520,
        weekNumberColumnVisible: true,
        horizontalPadding: 10,
        weekLabelWidth: 30,
        minRowHeight: 44,
        maxRowHeight: 78,
      );
      expect(h, lessThan(78));
      expect(h, lessThan(86.67));
    });

    test('学期未配置（周次列不占位）：格宽变大，行高跟着变', () {
      final withColumn = monthGridRowHeight(
        availableWidth: 360,
        availableForGrid: 520,
        weekNumberColumnVisible: true,
        horizontalPadding: 10,
        weekLabelWidth: 30,
        minRowHeight: 44,
        maxRowHeight: 78,
      );
      final withoutColumn = monthGridRowHeight(
        availableWidth: 360,
        availableForGrid: 520,
        weekNumberColumnVisible: false,
        horizontalPadding: 10,
        weekLabelWidth: 30,
        minRowHeight: 44,
        maxRowHeight: 78,
      );
      // 去掉 30 宽后：(360-20)/7 = 48.57 > 44.28。
      expect(withoutColumn, closeTo(340 / 7, 1e-9));
      expect(withoutColumn, greaterThan(withColumn));
    });

    test('高度很紧（横屏 / 平板分栏）时由高度兜住', () {
      final h = monthGridRowHeight(
        availableWidth: 900,
        availableForGrid: 300,
        weekNumberColumnVisible: true,
        horizontalPadding: 10,
        weekLabelWidth: 30,
        minRowHeight: 44,
        maxRowHeight: 78,
      );
      // 宽向 860/7=122.9，高向 300/6=50 → 取 50。
      expect(h, closeTo(50, 1e-9));
    });

    test('两端钳制生效（极窄 / 极矮都不会画成畸形）', () {
      final tiny = monthGridRowHeight(
        availableWidth: 100,
        availableForGrid: 999,
        weekNumberColumnVisible: true,
        horizontalPadding: 10,
        weekLabelWidth: 30,
        minRowHeight: 44,
        maxRowHeight: 78,
      );
      // (100-20-30)/7 = 7.14 → 被下限抬到 44。
      expect(tiny, 44);
      final huge = monthGridRowHeight(
        availableWidth: 4000,
        availableForGrid: 4000,
        weekNumberColumnVisible: false,
        horizontalPadding: 10,
        weekLabelWidth: 30,
        minRowHeight: 44,
        maxRowHeight: 78,
      );
      expect(huge, 78);
    });
  });

  group('monthGridLayout：上下同时收（2026-10-21 用户截图口径）', () {
    MonthGridLayout layoutAt(double t, {int keptRow = 3}) => monthGridLayout(
      t: t,
      availableHeight: 600,
      headerHeight: 24,
      horizontalPadding: 10,
      availableWidth: 360,
      weekNumberColumnVisible: true,
      weekLabelWidth: 30,
      minRowHeight: 44,
      maxRowHeight: 78,
      keptRow: keptRow,
    );

    test('行高恒按 6 行算：收起时格子不会突然变高', () {
      // 可用高 600、表头 24 → 576/6 = 96，但宽向 (360-20-30)/7 = 44.28 更紧，
      // 所以行高恒为 44.28 —— 与进度无关（否则收起像"字放大了"）。
      final expanded = layoutAt(1);
      final collapsed = layoutAt(0);
      expect(expanded.rowHeight, closeTo(310 / 7, 1e-9));
      expect(collapsed.rowHeight, closeTo(310 / 7, 1e-9));
    });

    test('窗口高：展开 = 表头 + 6 行；收起 = 表头 + 1 行', () {
      const rowH = 310 / 7;
      expect(layoutAt(1).gridHeight, closeTo(24 + 6 * rowH, 1e-9));
      expect(layoutAt(0).gridHeight, closeTo(24 + rowH, 1e-9));
    });

    test('面板高 = 可用高 - 网格窗口高（它盖住腾出来的那段）', () {
      for (final t in [0.0, 0.5, 1.0]) {
        final l = layoutAt(t);
        expect(l.panelHeight, closeTo(600 - l.gridHeight, 1e-9));
      }
      // 收起时面板必须变得很高（把下方几行盖住）。
      expect(layoutAt(0).panelHeight, greaterThan(layoutAt(1).panelHeight));
    });

    test('内容位移：展开为 0，收起把保留行顶到窗口顶端', () {
      const rowH = 310 / 7;
      expect(layoutAt(1).scrollOffset, 0);
      // 保留行 3 → 3 × 行高。
      expect(layoutAt(0).scrollOffset, closeTo(3 * rowH, 1e-9));
    });

    test('中间态按进度插值：位移 = keptRow × 行高 × (1 - t)', () {
      const rowH = 310 / 7;
      final l = layoutAt(0.4);
      expect(l.scrollOffset, closeTo(3 * rowH * 0.6, 1e-9));
    });

    test('保留行在第 5 行（0 基 4）时位移跟着它走 —— 用户截图那种情况', () {
      final l = layoutAt(0, keptRow: 4);
      expect(l.scrollOffset, closeTo(4 * (310 / 7), 1e-9));
      // 保留行下方只剩 1 行，那行就是被面板盖住的。
      expect(l.keptRow, 4);
    });

    test('进度越界钳制：不会算出负的窗口高或负的面板高', () {
      for (final t in [-2.0, 3.0]) {
        final l = layoutAt(t);
        expect(l.gridHeight, greaterThan(0));
        expect(l.panelHeight, greaterThanOrEqualTo(0));
      }
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
