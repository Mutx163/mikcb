// 「桌面小组件预览」的格位换算。纯算术，期望值是按桌面网格推出来的，
// 不是从实现里抄的：
//   单格 = (屏宽 − 左右留白 20×2 − 格间距 8×3) / 4
//   跨 n 格 = n × 单格 + (n−1) × 8
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/home_widget_service.dart';

void main() {
  group('buildHomeWidgetPreviewSpecs', () {
    test('2×2 的宽高相等 —— 方卡必须是正方形', () {
      final specs = buildHomeWidgetPreviewSpecs(393);
      final compact = specs.firstWhere(
        (s) => s.target == HomeWidgetPinTarget.compact22,
      );
      expect(compact.cellWidth, 2);
      expect(compact.cellHeight, 2);
      expect(compact.widthDp, compact.heightDp);
    });

    test('4 格宽 = 屏宽 − 左右各 20dp', () {
      const screenWidth = 393.0;
      final specs = buildHomeWidgetPreviewSpecs(screenWidth);
      final large = specs.firstWhere(
        (s) => s.target == HomeWidgetPinTarget.large44,
      );
      // 393 − 20×2 = 353
      expect(large.widthDp, moreOrLessEquals(353, epsilon: 0.01));
    });

    test('2 格宽按「两格 + 一道间距」算', () {
      final specs = buildHomeWidgetPreviewSpecs(393);
      final compact = specs.firstWhere(
        (s) => s.target == HomeWidgetPinTarget.compact22,
      );
      // 单格 82.25 → 2×82.25 + 8 = 172.5
      expect(compact.widthDp, moreOrLessEquals(172.5, epsilon: 0.01));
    });

    test('4×4 比 2×2 大，4×1 是横条', () {
      final specs = buildHomeWidgetPreviewSpecs(393);
      HomeWidgetPreviewSpec pick(HomeWidgetPinTarget t) =>
          specs.firstWhere((s) => s.target == t);
      final small = pick(HomeWidgetPinTarget.compact22);
      final large = pick(HomeWidgetPinTarget.large44);
      final strip = pick(HomeWidgetPinTarget.todayStrip41);
      expect(large.widthDp, greaterThan(small.widthDp));
      expect(large.heightDp, greaterThan(small.heightDp));
      expect(strip.widthDp, greaterThan(strip.heightDp));
    });

    test('屏更宽时每张都更大', () {
      final narrow = buildHomeWidgetPreviewSpecs(360);
      final wide = buildHomeWidgetPreviewSpecs(430);
      expect(wide.first.widthDp, greaterThan(narrow.first.widthDp));
      expect(wide.last.widthDp, greaterThan(narrow.last.widthDp));
    });

    test('顺序与数量固定：第一张是主卡，共十张', () {
      final specs = buildHomeWidgetPreviewSpecs(393);
      expect(specs.length, 10);
      expect(specs.first.target, HomeWidgetPinTarget.compact22);
      // 十种卡型不重不漏
      expect(
        specs.map((s) => s.target).toSet().length,
        HomeWidgetPinTarget.values.length,
      );
    });
  });
}
