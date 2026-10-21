import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/day_week_morph_layout.dart';

/// 形变几何的契约测试（2026-10-21）。
///
/// 期望值是**人推导出来的**，不是从实现里抄的：
/// - 周视图（progress 0）：时间列 40 + 7×50 = 390，第 k 列左边界 40+50k；
/// - 日视图（progress 1）：选中列铺满 0..390，时间列 0；
/// - 邻居列宽全程等于周视图日宽（只平移不压窄）；
/// - 中途任取一点，列宽随时间单调。
///
/// 参数统一取「390 视口 / 40 时间列 / 7 天 / 选中第 3 天（下标 2）」，
/// 这组数字整除（dayWidth = 50），手算容易对账。
void main() {
  const viewport = 390.0;
  const weekTime = 40.0;
  const dayCount = 7;
  const selected = 2;
  const dayWidth = (viewport - weekTime) / dayCount; // 50

  MorphColumnsLayout layoutAt(double progress) => morphColumnsLayout(
    progress: progress,
    viewportWidth: viewport,
    weekTimeColumnWidth: weekTime,
    visibleDayCount: dayCount,
    selectedIndex: selected,
  );

  group('端点：必须逐值还原两端的真实布局', () {
    test('progress=0 还原周视图', () {
      final layout = layoutAt(0);
      expect(layout.timeColumnWidth, weekTime, reason: '时间列应保持周视图宽度');
      for (var i = 0; i < dayCount; i++) {
        final col = layout.columns[i];
        expect(col.width, closeTo(dayWidth, 1e-9), reason: '第 $i 列应等于日宽');
        expect(
          col.left,
          closeTo(weekTime + i * dayWidth, 1e-9),
          reason: '第 $i 列左边界应为 时间列 + i×日宽',
        );
      }
      expect(
        layout.columns.last.right,
        closeTo(viewport, 1e-9),
        reason: '最后一列右边界应正好等于视口宽',
      );
    });

    test('progress=1 时选中列铺满整屏', () {
      final layout = layoutAt(1);
      expect(layout.timeColumnWidth, 0, reason: '日视图没有时间列');
      expect(layout.selected.left, 0, reason: '选中列左边界应为 0');
      expect(layout.selected.width, viewport, reason: '选中列应铺满视口');
    });
  });

  group('邻居列：只平移、不压窄', () {
    test('全程邻居列宽恒为周视图日宽', () {
      for (final p in [0.0, 0.13, 0.25, 0.5, 0.66, 0.9, 1.0]) {
        final layout = layoutAt(p);
        for (var i = 0; i < dayCount; i++) {
          if (i == selected) continue;
          expect(
            layout.columns[i].width,
            closeTo(dayWidth, 1e-9),
            reason: 'progress=$p 第 $i 列（邻居）宽度被改了',
          );
        }
      }
    });

    test('邻居被推出画面：日视图里所有邻居都在视口外', () {
      final layout = layoutAt(1);
      for (var i = 0; i < dayCount; i++) {
        if (i == selected) continue;
        final col = layout.columns[i];
        final fullyLeft = col.right <= 0;
        final fullyRight = col.left >= viewport;
        expect(
          fullyLeft || fullyRight,
          isTrue,
          reason: '第 $i 列应完全在视口外，实际 ${col.left}..${col.right}',
        );
      }
    });

    test('左侧邻居紧贴选中列左边，右侧邻居紧贴右边', () {
      // 中途取一点：邻居不能飘在半空，也不能和选中列重叠。
      final layout = layoutAt(0.4);
      for (var i = 0; i < dayCount; i++) {
        if (i == selected) continue;
        final col = layout.columns[i];
        if (i < selected) {
          // 第 i 列右边界 == 第 i+1 列左边界（一路紧贴到选中列）
          expect(
            col.right,
            closeTo(layout.columns[i + 1].left, 1e-9),
            reason: '第 $i 列与第 ${i + 1} 列之间不应出现空隙',
          );
        } else {
          expect(
            col.left,
            closeTo(layout.columns[i - 1].right, 1e-9),
            reason: '第 $i 列与第 ${i - 1} 列之间不应出现空隙',
          );
        }
      }
    });
  });

  group('单调性：来回拖动不能有回弹', () {
    test('选中列宽度随 progress 单调增', () {
      var prev = -1.0;
      for (var i = 0; i <= 100; i++) {
        final w = layoutAt(i / 100).selected.width;
        expect(
          w >= prev - 1e-9,
          isTrue,
          reason: 'progress=${i / 100} 时宽度回退了：$prev → $w',
        );
        prev = w;
      }
    });

    test('时间列宽度随 progress 单调减', () {
      var prev = double.infinity;
      for (var i = 0; i <= 100; i++) {
        final w = layoutAt(i / 100).timeColumnWidth;
        expect(
          w <= prev + 1e-9,
          isTrue,
          reason: 'progress=${i / 100} 时时间列变宽了：$prev → $w',
        );
        prev = w;
      }
    });
  });

  group('退化输入：不许出 NaN / 负宽 / 抛异常', () {
    test('progress 之外夹在 [0,1]', () {
      final below = layoutAt(-3);
      final above = layoutAt(9);
      expect(below.timeColumnWidth, weekTime, reason: '低于 0 应夹到周视图');
      expect(above.selected.width, viewport, reason: '高于 1 应夹到日视图');
    });

    test('视口比时间列还窄时不产生负宽', () {
      final layout = morphColumnsLayout(
        progress: 0.5,
        viewportWidth: 20, // 比时间列 40 还窄
        weekTimeColumnWidth: weekTime,
        visibleDayCount: dayCount,
        selectedIndex: selected,
      );
      for (final col in layout.columns) {
        expect(col.width.isFinite, isTrue, reason: '宽度必须是有限值');
        expect(
          col.width,
          greaterThanOrEqualTo(kMorphMinColumnWidth),
          reason: '宽度不得小于最小列宽',
        );
      }
    });

    test('全部取值都是有限数（无 NaN / Infinity）', () {
      for (final p in [0.0, 0.001, 0.5, 0.999, 1.0]) {
        final layout = layoutAt(p);
        expect(layout.timeColumnWidth.isFinite, isTrue);
        for (final col in layout.columns) {
          expect(col.left.isFinite, isTrue, reason: 'progress=$p 左边界出现非有限值');
          expect(col.width.isFinite, isTrue, reason: 'progress=$p 宽度出现非有限值');
        }
      }
    });
  });

  group('可见 5 天（隐藏周末）时同样成立', () {
    test('端点与邻居宽度', () {
      const n = 5;
      const dw = (viewport - weekTime) / n; // 70
      final at0 = morphColumnsLayout(
        progress: 0,
        viewportWidth: viewport,
        weekTimeColumnWidth: weekTime,
        visibleDayCount: n,
        selectedIndex: 0,
      );
      expect(at0.selected.width, closeTo(dw, 1e-9));
      expect(at0.columns.last.right, closeTo(viewport, 1e-9));

      final at1 = morphColumnsLayout(
        progress: 1,
        viewportWidth: viewport,
        weekTimeColumnWidth: weekTime,
        visibleDayCount: n,
        selectedIndex: 0,
      );
      expect(at1.selected.width, viewport);
      expect(at1.selected.left, 0);
    });
  });
}
