import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/utils/card_surface_ink.dart';
import 'package:university_timetable/utils/month_cell_ink.dart';
import 'package:university_timetable/utils/wallpaper_luminance_profile.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_day_cell.dart';

/// 月视图**分区判墨**的判据（2026-10-21 专业美学评审 P0-1 / P0-2 的落地）。
///
/// ## 为什么这些数必须钉住
///
/// 评审是对着真机截图逐像素量出来的，结论是「这页最要紧的问题不是不好看，
/// 是有些字物理上看不见」。改完如果只凭"看起来好了"就收工，下一轮很容易
/// 在别处又乘一个 alpha、又把整屏平均亮度拿来判 42 格 —— 而这两件事都不会让
/// 任何既有测试变红（既有的测的是结构，不是可读性）。
///
/// 所以这里钉的都是**外部标准**（WCAG 对比度），期望值按公式自己算出来，
/// 不复用被测实现里的对比度函数 —— 否则测的是自我一致性，不是可读性：
///
/// * 正文 ≥ 4.5:1（WCAG AA 正常字号）；
/// * 月外日期弱化后 ≥ 3.2:1（比正文低、但仍明显高于"看得见/看不见"的 3.0；
///   旧实现实测 1.97:1）；
/// * 圆点等非文字图形 ≥ 3.0:1（WCAG 1.4.11；旧实现实测 1.01:1）。
///
/// 放 `test/utils/`：纯判据，按 TEST-POLICY 允许新增的位置。
void main() {
  /// WCAG 相对亮度 —— 按定义自己实现（不调 `month_cell_ink` 里的私有函数）。
  double luminanceOf(Color color) {
    double channel(double c) => c <= 0.04045
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(color.r) +
        0.7152 * channel(color.g) +
        0.0722 * channel(color.b);
  }

  double contrast(Color a, Color b) {
    final la = luminanceOf(a);
    final lb = luminanceOf(b);
    final hi = math.max(la, lb);
    final lo = math.min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }

  /// 把「相对亮度」折算成不透明灰的 **sRGB 通道值**，好拿真实 `Color` 去算对比度。
  ///
  /// ⚠️ 这一步不能省：亮度是线性量、通道值是编码量，直接把亮度当通道用会算出
  /// 一个比目标暗得多的颜色（亮度 0.86 对应通道 0.94），于是「期望值」本身就是错的。
  /// 本文件第一版就栽在这里，四条用例因此假红。
  double channelOf(double luminance) => luminance <= 0.0031308
      ? 12.92 * luminance
      : 1.055 * math.pow(luminance, 1 / 2.4) - 0.055;

  Color grayOf(double luminance) {
    final c = channelOf(luminance.clamp(0.0, 1.0));
    return Color.from(alpha: 1, red: c, green: c, blue: c);
  }

  group('逐行剖面查询：每一行查自己那一段', () {
    // 造一条"上亮下暗"的剖面（0.60 → 0.10），正是评审那张截图的壁纸结构：
    // 顶部亮云，底部深紫水面。
    WallpaperLuminanceProfile rampProfile() {
      const rows = 100;
      return WallpaperLuminanceProfile(
        rowLuminances: List<double>.generate(
          rows,
          (i) => 0.60 - 0.50 * (i / (rows - 1)),
        ),
      );
    }

    test('6 行亮度各不相同，且自上而下递减', () {
      final rows = monthRowLuminances(
        profile: rampProfile(),
        screenHeight: 1000,
        gridTopOnScreen: 200,
        headerHeight: 24,
        rowHeight: 60,
        rowCount: 6,
      );
      expect(rows.length, 6);
      expect(
        rows.every((r) => r != null),
        isTrue,
        reason: '有剖面时每一行都必须能查出亮度（null 说明区间算歪了）',
      );
      for (var i = 1; i < rows.length; i++) {
        expect(
          rows[i],
          lessThan(rows[i - 1]!),
          reason: '剖面自上而下变暗，行亮度也必须递减；相等说明 6 行查的是同一段'
              '（＝又退回"整屏一个数"）',
        );
      }
      final spread = rows.first! - rows.last!;
      expect(
        spread,
        greaterThan(0.05),
        reason: '顶行与底行的亮度差只有 ${spread.toStringAsFixed(3)} —— '
            '真机那张壁纸差 2.5 倍，逐行判墨的意义就在这个差上',
      );
    });

    test('没有剖面时每一行都是 null（调用方据此回落整屏带）', () {
      final rows = monthRowLuminances(
        profile: null,
        screenHeight: 1000,
        gridTopOnScreen: 200,
        headerHeight: 24,
        rowHeight: 60,
        rowCount: 6,
      );
      expect(rows.length, 6);
      expect(rows.every((r) => r == null), isTrue);
    });

    test('空剖面 / 非法屏幕高同样安全回落', () {
      final rows = monthRowLuminances(
        profile: WallpaperLuminanceProfile.empty,
        screenHeight: 0,
        gridTopOnScreen: 0,
        headerHeight: 24,
        rowHeight: 60,
        rowCount: 6,
      );
      expect(rows.every((r) => r == null), isTrue);
    });
  });

  group('日期墨色：逐格判据（4.5:1 正文标准）', () {
    // 真实卡底色（浅色主题 surfaceContainerHighest）与真实染色比例
    // （月外日期整卡 0.55）。
    const fill = Color(0xFFE3E3E9);
    const washAlpha = 0.55;

    test('真机截图的取样：旧实现的墨色实测 1.97 / 2.78 / 3.46 —— 这就是病灶', () {
      // 下面三组是评审时从原图逐像素取样的**实测值**（不是推导值）：
      // 卡面填充色与它上面那层日期数字的颜色。
      //   · 第 6 行（月外 1–7 日）fill 127,124,148  ink 80,80,93
      //   · 第 5 行（本月 25–31 日）fill 152,151,173 ink 80,80,95
      //   · 第 1 行（上月 28–31 日）fill 218,192,186 ink 103,98,106
      //
      // 三行里只有本月那行勉强够到 4.5 的门槛以下，月外两行是 1.97 / 3.46 ——
      // 前者物理上读不出来。这条用例把"旧实现到底有多差"钉成可回归的数字：
      // 若哪天有人把判据改回去，这三组数会对不上新的判据（见下一组用例）。
      const measured = <(String, Color, Color, double)>[
        ('第 6 行 · 月外', Color(0xFF7F7C94), Color(0xFF50505D), 1.97),
        ('第 5 行 · 本月', Color(0xFF9898AD), Color(0xFF50505F), 2.78),
        ('第 1 行 · 上月', Color(0xFFDAC0BA), Color(0xFF67626A), 3.46),
      ];
      for (final (_, fill, ink, expected) in measured) {
        expect(
          contrast(fill, ink),
          closeTo(expected, 0.02),
          reason: '取样值的复算结果对不上 $expected —— 取样本身有问题',
        );
      }

      // 同一批卡面上，新判据给出的墨色必须过门槛：
      // 本月 ≥ 4.5:1、月外弱化后 ≥ 3.2:1。
      for (final (name, fill, _, _) in measured) {
        final surface = luminanceOf(fill);
        final isOutside = name.contains('月外') || name.contains('上月');
        final ink = isOutside
            ? dimInkToContrast(bestCardInkForLuminance(surface), surface)
            : bestCardInkForLuminance(surface);
        final alpha = ink.a;
        final composed = Color.from(
          alpha: 1,
          red: ink.r * alpha + fill.r * (1 - alpha),
          green: ink.g * alpha + fill.g * (1 - alpha),
          blue: ink.b * alpha + fill.b * (1 - alpha),
        );
        final target = isOutside ? 3.2 : 4.5;
        expect(
          contrast(composed, fill),
          greaterThanOrEqualTo(target),
          reason: '$name 上新判据只有 '
              '${contrast(composed, fill).toStringAsFixed(2)}:1，低于 $target',
        );
      }
    });

    test('每一行自己判出来的墨色都达到 4.5:1', () {
      for (final wallpaper in <double>[
        0.08,
        0.15,
        0.23,
        0.36,
        0.45,
        0.56,
        0.65,
      ]) {
        final ink = monthCellInkFor(
          wallpaperLuminance: wallpaper,
          fill: fill,
          washAlpha: washAlpha,
        );
        final surface = monthCellSurfaceLuminance(
          fill: fill,
          washAlpha: washAlpha,
          wallpaperLuminance: wallpaper,
        );
        expect(
          contrast(ink, grayOf(surface)),
          greaterThanOrEqualTo(4.5),
          reason: '壁纸亮度 $wallpaper 上判出的墨色只有 '
              '${contrast(ink, grayOf(surface)).toStringAsFixed(2)}:1，'
              '低于正文标准 4.5:1',
        );
      }
    });
  });

  group('月外日期：弱化只弱到仍然可读', () {
    /// 半透明墨实际上屏后的颜色（与卡面按 alpha 合成）。
    Color composed(Color ink, double amount, double surface) {
      return Color.from(
        alpha: 1,
        red: ink.r * amount + surface * (1 - amount),
        green: ink.g * amount + surface * (1 - amount),
        blue: ink.b * amount + surface * (1 - amount),
      );
    }

    test('弱化后 ≥ 3.2:1，且确实比本月日期淡', () {
      const surface = 0.42;
      final full = bestCardInkForLuminance(surface);
      final dimmed = dimInkToContrast(full, surface);
      final alpha = dimmed.a;

      expect(
        contrast(composed(dimmed, alpha, surface), grayOf(surface)),
        greaterThanOrEqualTo(3.2),
        reason: '弱化后低于 3.2:1 就落进"看不见"那一档（旧实现实测 1.97:1）',
      );
      expect(
        alpha,
        lessThan(1.0),
        reason: '可弱化的场合必须真的弱化，否则月外日期与本月日期一样重',
      );
      expect(
        alpha,
        greaterThan(0.4),
        reason: '弱到 40% 以下就已经读不出来（旧实现连乘两次 alpha 就是这条路）',
      );
    });

    test('满强度本来就够不着目标时不再弱化（不能偷偷减对比度）', () {
      const surface = 0.18;
      final full = bestCardInkForLuminance(surface);
      // 目标 12:1 对这种卡面根本做不到 —— 此时必须原样返回，而不是"尽力弱化"。
      expect(dimInkToContrast(full, surface, targetContrast: 12), full);
    });
  });

  group('圆点：8dp + 对比度保底（非文字图形 3:1）', () {
    test('课程自身色撞卡面时，压明度保色相到达标', () {
      // 浅粉课程色压在浅色卡面上：评审实测原样只有 1.01:1。
      const palePink = Color(0xFFF3C6C9);
      const surface = 0.86;
      final readable = readableMonthDotColor(palePink, surface);

      expect(
        contrast(readable, grayOf(surface)),
        greaterThanOrEqualTo(3.0),
        reason: '圆点是网格里唯一的内容信号；低于 3:1 等于没有（旧实现 1.01:1）',
      );
      // 色相保住：用户导入时挑的是"这门课的颜色"，换掉等于设置失效。
      expect(
        HSLColor.fromColor(readable).hue,
        closeTo(HSLColor.fromColor(palePink).hue, 15),
      );
    });

    test('本来就达标时原样返回（不为改而改）', () {
      const strongBlue = Color(0xFF2E5BE0);
      expect(readableMonthDotColor(strongBlue, 0.9), strongBlue);
    });

    test('直径 ≥8dp，且行高容得下它', () {
      expect(
        MonthDot.diameter,
        greaterThanOrEqualTo(8),
        reason: '5dp 在 393dp 宽的屏上只占 1.5%，压在纹理复杂的壁纸上认不出来',
      );
      expect(
        MonthDot.extent,
        greaterThanOrEqualTo(MonthDot.diameter),
        reason: '圆点行高度必须容得下圆点（含描边），否则上下会被裁掉',
      );
    });
  });

  group('拉杆：满 alpha 的黑/白，不再乘 0.32', () {
    test('按拉杆自己那段壁纸判黑白', () {
      // 评审实测：主体带 0.356 判成深墨，而拉杆那段只有 0.09 —— 深墨直接消失。
      expect(
        monthHandleInk(0.09, fallback: Colors.black),
        bestCardInkForLuminance(0.09),
      );
      expect(
        monthHandleInk(0.75, fallback: Colors.black),
        bestCardInkForLuminance(0.75),
      );
    });

    test('没有壁纸亮度时回落调用方给的墨色', () {
      const fallback = Color(0xFF123456);
      expect(monthHandleInk(null, fallback: fallback), fallback);
    });
  });
}
