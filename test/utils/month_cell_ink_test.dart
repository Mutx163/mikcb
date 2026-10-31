import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/utils/month_cell_ink.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_day_cell.dart';

/// 月视图**判墨**的判据（2026-10-21 立，2026-10-23 随"格子进白卡"收窄）。
///
/// ## 2026-10-23：一半判据随版式一起作废
///
/// 2026-10-21 的专业评审量真机截图得出的结论是「这页最要紧的问题不是不好看，
/// 是有些字物理上看不见」—— 因为当时 42 个格子各是一张玻璃卡直接铺在壁纸上，
/// 同一屏壁纸亮度 0.56 → 0.23，整屏一个数判墨必然错掉一头。
///
/// 用户 2026-10-23 把格子改进**白色日历卡**之后，壁纸不再影响格子里的字，
/// 那套「逐行查壁纸亮度」的判据（`monthRowLuminances` / `monthCellInkFor` /
/// `monthCellSurfaceLuminance` / `monthHandleInk`）连同它们的测试一起删除。
///
/// **留下的是仍然成立的两种弱化判据**：
///
/// * 月外日期弱化后 ≥ 3.2:1（比正文低、但明显高于"看得见/看不见"的 3.0；
///   旧实现实测 1.97:1）；
/// * 圆点等非文字图形 ≥ 3.0:1（WCAG 1.4.11；旧实现实测 1.01:1）。
///
/// 期望值全部按 WCAG 公式**自己算**，不复用被测实现里的对比度函数 ——
/// 否则测的是自我一致性，不是可读性。
void main() {
  /// WCAG 相对亮度 —— 按定义自己实现（不调 `month_cell_ink` 里的私有函数）。
  double luminanceOf(Color color) {
    double channel(double c) => c <= 0.03928
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(color.r) +
        0.7152 * channel(color.g) +
        0.0722 * channel(color.b);
  }

  /// WCAG 对比度（1–21）。
  double contrast(Color a, Color b) {
    final la = luminanceOf(a);
    final lb = luminanceOf(b);
    final hi = math.max(la, lb);
    final lo = math.min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }

  group('月外日期：弱化只弱到仍然可读', () {
    test('弱化后 ≥ 3.2:1，且确实比本月日期淡', () {
      // 白卡上的主题墨（浅色主题）。
      const ink = Color(0xFF1A1A1A);
      const cardLuminance = 0.97; // 白卡
      final dimmed = dimInkToContrast(ink, cardLuminance);

      // ⚠️ `Color.computeLuminance()` **不看 alpha**，所以"变淡"这件事只能从
      // `a` 上读，不能拿亮度比大小（本地第一版就写错了）。
      expect(dimmed.a, lessThan(1), reason: '弱化手段就是把它推成半透明墨 —— alpha 必须降下来');
      const card = Color(0xFFF8F8F8);
      // 半透明墨上屏后的合成色，才是用户实际看到的东西。
      final composed = Color.alphaBlend(dimmed, card);
      expect(
        contrast(composed, card),
        greaterThanOrEqualTo(monthOutsideTextContrast - 0.05),
        reason: '月外日期弱化后仍须 ≥3.2:1 —— 低于 3.0 就不是"弱"，是"没有"',
      );
      expect(
        luminanceOf(composed),
        greaterThan(luminanceOf(ink)),
        reason: '弱化必须让它更接近卡面（更淡），而不是反方向',
      );
    });

    test('满强度本来就够不着目标时不再弱化（不能偷偷减对比度）', () {
      // 灰墨贴在灰卡上：3.2:1 本来就不成立。
      const ink = Color(0xFF8A8A8A);
      const cardLuminance = 0.30;
      final result = dimInkToContrast(ink, cardLuminance, targetContrast: 12);
      expect(
        result,
        ink,
        reason:
            '连原始对比度都不到目标时，弱化只会更糟 —— 必须原样返回，'
            '交给调用方（圆点描边等）另想办法',
      );
    });
  });

  group('圆点：8dp + 对比度保底（非文字图形 3:1）', () {
    test('课程自身色撞卡面时，压明度保色相到达标', () {
      const palePink = Color(0xFFFFC0CB);
      const surface = 0.86; // 浅灰白卡面
      final readable = readableMonthDotColor(palePink, surface);
      final surfaceColor = _grayOf(surface);

      expect(
        contrast(readable, surfaceColor),
        greaterThanOrEqualTo(monthDotContrast),
        reason:
            '圆点是非文字图形，必须达到 3:1；'
            '旧实现实测 1.01:1 —— 不是"偏淡"，是等于没有',
      );
      // 色相不许被换掉：用户导入时挑的就是这门课的颜色。
      final before = HSLColor.fromColor(palePink);
      final after = HSLColor.fromColor(readable);
      expect(
        (after.hue - before.hue).abs(),
        lessThan(30),
        reason: '保底只能压明度，不能把用户的课程色改掉',
      );
    });

    test('本来就达标时原样返回（不为改而改）', () {
      const strongBlue = Color(0xFF1A3FA8);
      expect(readableMonthDotColor(strongBlue, 0.92), strongBlue);
    });

    test('直径 ≥8dp，且行高容得下它', () {
      expect(MonthDot.diameter, greaterThanOrEqualTo(8));
      expect(MonthDot.extent, greaterThanOrEqualTo(MonthDot.diameter));
    });
  });

  group('弱化手段：混色，不压 alpha', () {
    test('dimTowardCard 只改颜色、不改不透明度', () {
      const ink = Color(0xFF000000);
      const card = Color(0xFFFFFFFF);
      final dimmed = dimTowardCard(ink, card);
      expect(dimmed.a, 1, reason: '压 alpha 会把"墨与卡面的亮度差"一起吃掉（实测圆点 1.42:1）');
      expect(
        luminanceOf(dimmed),
        greaterThan(luminanceOf(ink)),
        reason: '向白卡混色 → 必须比原色更接近卡面',
      );
    });

    test('amount=0 是原色、amount=1 完全等于卡面', () {
      const ink = Color(0xFF123456);
      const card = Color(0xFFE0E0E0);
      expect(dimTowardCard(ink, card, amount: 0).toARGB32(), ink.toARGB32());
      expect(dimTowardCard(ink, card, amount: 1).toARGB32(), card.toARGB32());
    });
  });
}

/// 给定亮度的一段灰（用于把"卡面亮度"换算成能算对比度的颜色）。
Color _grayOf(double luminance) {
  double channel(double l) {
    final c = l.clamp(0.0, 1.0);
    return c <= 0.0031308 ? c * 12.92 : 1.055 * math.pow(c, 1 / 2.4) - 0.055;
  }

  final g = channel(luminance);
  return Color.from(alpha: 1, red: g, green: g, blue: g);
}
