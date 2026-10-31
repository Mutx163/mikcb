/// 月视图的**判墨**工具（2026-10-21 立，2026-10-23 随"格子进白卡"大幅收窄）。
///
/// ## 现在只剩两件事
///
/// | 函数 | 用在哪 | 判据 |
/// |---|---|---|
/// | [dimInkToContrast] | 月外日期弱化 | 按**对比度**弱化，不乘 alpha |
/// | [readableMonthDotColor] | 课程色与卡面的可辨性保底 | 压明度、保色相 |
///
/// ## 已删除的部分与理由（留档，别再搬回来）
///
/// 2026-10-21 这一层原本负责「**每一行查自己那段壁纸亮度**再判黑/白字」——
/// 因为当时 42 个格子各是一张玻璃卡、直接铺在壁纸上，同一屏壁纸自上而下亮度
/// 从 0.56 走到 0.23，整屏一个数必然错掉一头（实测月外日期掉到 1.97:1）。
///
/// 2026-10-23 用户把版面改成「日历白卡 + 独立信息卡」之后，格子躺在**不透明白卡**
/// 上，壁纸亮度不再影响格子里的字 —— 那套逐行判据（`monthRowLuminances` /
/// `monthCellInkFor` / `monthCellSurfaceLuminance` / `monthHandleInk`）失去前提，
/// 全部删除。**如果哪天真把它们接回来，先确认卡片是不是又变透明了。**
///
/// 「弱化 ≠ 变淡」那条仍然成立，所以 [dimInkToContrast] 留着：
/// 乘 alpha 会把墨与卡面的亮度差一起吃掉（2026-10-22 实测：圆点 1.42:1，
/// 读起来像"禁用控件"）。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'card_surface_ink.dart';

/// 月外日期弱化后**仍须达到**的对比度。
///
/// 3.2 的依据：它比 WCAG 正文门槛 4.5 明显低（看得出"这是上个月"），
/// 又高于非正文下限 3.0（看得出"这是几号"）。旧实现实测 1.97:1，
/// 低于 3.0 就不是"弱"，而是"没有"。
const double monthOutsideTextContrast = 3.2;

/// 圆点（课程 / 考试 / 日程标记）与卡面的最小对比度。
///
/// 圆点是非文字图形，WCAG 图形对象门槛就是 3.0。实测旧实现里课程点（浅粉，
/// 5dp）压在暖色卡面上只有 **1.01:1** —— 不是"偏淡"，是等于没有。
const double monthDotContrast = 3;

/// 两个亮度之间的 WCAG 对比度（1–21）。
double _contrastOf(double a, double b) {
  final hi = math.max(a, b);
  final lo = math.min(a, b);
  return (hi + 0.05) / (lo + 0.05);
}

/// 把 [ink] 弱化到「仍然满足 [targetContrast]」的最淡程度。
///
/// 实现是在 alpha 上二分：alpha = 1 是原色、越小越接近卡面（越淡）。取满足
/// 对比度门槛的最小 alpha —— 也就是**弱化到看得清的极限**，再淡一步就不可读。
///
/// 满强度的对比度本来就低于门槛时**原样返回**：那说明这组配色在极限处都勉强，
/// 再淡只会更糟；该由调用方另想办法，不在这里偷偷减对比度。
///
/// ⚠️ 合成按**亮度线性**近似（真实 alpha 混合发生在编码 sRGB 通道上）。这个
/// 近似只在两端之间插值，且本函数一律留出 3.0 以上的余量，误差不会把结果推到
/// 门槛以下。
Color dimInkToContrast(
  Color ink,
  double surfaceLuminance, {
  double targetContrast = monthOutsideTextContrast,
}) {
  final inkLuminance = ink.computeLuminance();
  if (_contrastOf(inkLuminance, surfaceLuminance) <= targetContrast) {
    return ink;
  }
  var low = 0.0;
  var high = 1.0;
  for (var i = 0; i < 14; i++) {
    final mid = (low + high) / 2;
    final composed = inkLuminance * mid + surfaceLuminance * (1 - mid);
    if (_contrastOf(composed, surfaceLuminance) >= targetContrast) {
      high = mid;
    } else {
      low = mid;
    }
  }
  return ink.withValues(alpha: high);
}

/// 把 [ink] 向卡面 [cardFill] **混色**来弱化（不压 alpha）。
///
/// ## 为什么弱化不能用 alpha
///
/// 半透明墨上屏后是「墨与背景的混合色」—— 它以**同一个方向**把墨推向背景。
/// 想弱化时这正好把"墨与背景的亮度差"一起吃掉：真机实测图例里那颗
/// 「考试 0」的圆点用 `alpha 0.28` 压完只剩 **1.42:1**，读起来不是"弱"，是
/// "禁用 / 没加载出来"。
///
/// 向卡面混色是同一件事的可控版本：它只改变**颜色**，不改变不透明度，所以
/// 想让"弱多少"就说多少。
///
/// [amount] = 0 是原色、1 是完全等于卡面（看不见）。调用方给 0.5~0.72 一档。
Color dimTowardCard(Color ink, Color cardFill, {double amount = 0.62}) {
  return Color.lerp(ink, cardFill, amount.clamp(0.0, 1.0))!;
}

/// 圆点自身颜色与卡面的对比度是否达标；不达标时返回一个可达标的替代色。
///
/// 保守策略：只压明度、不动色相（与 `readableColorOnLuminance` 同一套理由 ——
/// 用户导入时挑的是"这门课的颜色"，换掉它等于他的设置失效）。
Color readableMonthDotColor(
  Color dot,
  double surfaceLuminance, {
  double minContrast = monthDotContrast,
}) {
  if (_contrastOf(dot.computeLuminance(), surfaceLuminance) >= minContrast) {
    return dot;
  }
  final hsl = HSLColor.fromColor(dot);
  final goLighter = surfaceLuminance < 0.5;
  for (var step = 1; step <= 12; step++) {
    final delta = step / 12;
    final lightness = goLighter
        ? hsl.lightness + (1 - hsl.lightness) * delta
        : hsl.lightness * (1 - delta);
    final candidate = hsl.withLightness(lightness.clamp(0.0, 1.0)).toColor();
    if (_contrastOf(candidate.computeLuminance(), surfaceLuminance) >=
        minContrast) {
      return candidate;
    }
  }
  // 推到极限仍不达标：交给卡面墨色（黑白两档里较优的那一档）。
  return bestCardInkForLuminance(surfaceLuminance);
}
