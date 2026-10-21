/// 卡面墨色（字色）判定的**唯一入口**。
///
/// ## 这里统一的是哪几件事
///
/// 2026-10-21 之前在三个地方各有一套判断，而且口径互相不一致，同一屏上因此
/// 先后判错四张卡的字色（两张真机截图）：
///
/// 1. `dayAgendaAutoInk` 用 `卡色 × 0.5 + 壁纸 × 0.5` —— 权重是写死的 0.5，
///    与实际染色比例无关。卡面是主题白时那一半白就把结果顶到 0.5，越过
///    0.45 的翻转线 → **浅色主题下永远是黑字**，壁纸再黑也不变。
/// 2. 同一条路径的分界点用 0.45（那是「顶栏 chrome」的口径）。0.45 处黑/白
///    对照背景都只有约 2:1，而黑白对比度相等的点是 0.20。
/// 3. 判据亮度取的是**整屏一条带**（body 带 22%~72% 的平均），不区分卡片
///    实际压在哪一行。真实照片竖直方向可以差 100 倍。
/// 4. 课程自带的自定义字色（导入「自动匹配字色」写入的 `#1F1F1F`）拿的是同一份
///    平均亮度做对比度检查，于是坐在近黑水面上的卡也通过了 3:1。
///
/// 本文件把这四条收成一条式子：**卡面实际长什么样 = 自己的底 × 染色比例 +
/// 它背后那一小块壁纸 × 其余**，再按黑/白各自的真实对比度选更清楚的一档。
///
/// ## 为什么用对比度而不是一个魔法阈值
///
/// 黑白两档对背景亮度 `L` 的对比度分别是 `1.05/(L+0.05)` 与 `(L+0.05)/0.06`，
/// 两者在 `L ≈ 0.20` 相等。直接比对比度等价于在 0.2 处分界，但把「相等点」
/// 写进代码意图，就不会有人再把它和其他表面（0.45 的 chrome 口径）混起来。
library;

import 'package:flutter/material.dart';

import 'wallpaper_luminance_profile.dart';

/// 小字（教师 / 地点 / 时间这类 11.5–12sp）的对比度门槛：WCAG AA 正文标准。
const double cardInkBodyTextContrastRatio = 4.5;

/// 大字（课名这类 titleMedium）的对比度门槛：WCAG AA 大字号标准。
const double cardInkLargeTextContrastRatio = 3;

/// 近黑墨。不用纯黑：纯白与纯黑在照片上都会显得生硬，这一档是仓里既有的
/// 「自动黑白」结果色（见 `course_color_palette.dart` 的 `_bestContrastInk`）。
const Color cardInkDark = Color(0xFF1A1A1A);

/// 亮墨。
const Color cardInkLight = Color(0xFFFFFFFF);

/// 两张候选墨色里，对 [backgroundLuminance] 对比度更高的那一档。
///
/// 两档都不达标时仍返回较优的那一档（总得给一个颜色），调用方可以用
/// [cardInkContrastRatio] 自行判断是否需要加底衬 / 提示。
Color bestCardInkForLuminance(
  double backgroundLuminance, {
  Color light = cardInkLight,
  Color dark = cardInkDark,
}) {
  final lightRatio = cardInkContrastRatio(light, backgroundLuminance);
  final darkRatio = cardInkContrastRatio(dark, backgroundLuminance);
  return lightRatio >= darkRatio ? light : dark;
}

/// [ink] 在亮度为 [backgroundLuminance] 的背景上的 WCAG 对比度（1–21）。
///
/// 直接吃亮度而不是 `Color`：判色阶段的背景是**估算出来的合成亮度**（壁纸 +
/// 半透明染色），没有对应的 `Color` 实例。
double cardInkContrastRatio(Color ink, double backgroundLuminance) {
  final inkLuminance = ink.computeLuminance();
  final hi = inkLuminance > backgroundLuminance
      ? inkLuminance
      : backgroundLuminance;
  final lo = inkLuminance > backgroundLuminance
      ? backgroundLuminance
      : inkLuminance;
  return (hi + 0.05) / (lo + 0.05);
}

/// 卡面**实际呈现**的亮度：自有底色与背后壁纸按染色比例混合。
///
/// [washAlpha] 是卡自己的底色压上去的比例（1 = 完全不透明实体卡，0 = 纯壁纸）。
/// 与渲染层同源：正源是 `CourseSurface.washAlpha`，别在调用方另写一个常数 ——
/// 写死 0.5 正是 2026-10-21 那批 bug 的来源。
double cardSurfaceLuminance({
  required Color fill,
  required double washAlpha,
  required double wallpaperLuminance,
}) {
  final t = washAlpha.clamp(0.0, 1.0);
  return fill.computeLuminance() * t + wallpaperLuminance * (1 - t);
}

/// 一张卡该用黑字还是白字。
///
/// * [fill]：卡片自己的底色（课程色 / 日程色 / 主题卡面）；
/// * [washAlpha]：这个底色压上去的真实比例（`CourseSurface.washAlpha`）；
/// * [wallpaperLuminance]：**这张卡背后那一小块**壁纸的亮度（不是整屏平均）。
///   为 null（还没采到）时按「不可判定」处理，回落到 [fallback]；
/// * [preferred]：用户 / 导入流程给这门课指定的字色。给了就**优先保留**，
///   但要求它在**这张卡的实际卡面**上达到 [minContrastRatio] —— 不达标
///   说明这个颜色在这块壁纸上读不出来，交给黑白两档。
/// * [minContrastRatio]：小字用 [cardInkBodyTextContrastRatio]，大字用
///   [cardInkLargeTextContrastRatio]。
/// * [fallback]：壁纸亮度未知时的返回值（通常跟随主题）。
Color cardSurfaceInk({
  required Color fill,
  required double washAlpha,
  required double? wallpaperLuminance,
  Color? preferred,
  double minContrastRatio = cardInkBodyTextContrastRatio,
  Color fallback = cardInkLight,
  bool preferKeepPreferredOnUnknownBackground = true,
}) {
  // 壁纸亮度未知：卡面亮度算不出来。用户指定过就保留（旧行为：不能因为还没
  // 采到就把人家挑的颜色换掉），没指定过就跟主题。
  if (wallpaperLuminance == null) {
    if (preferred != null && preferKeepPreferredOnUnknownBackground) {
      return preferred;
    }
    return preferred ?? fallback;
  }
  final surface = cardSurfaceLuminance(
    fill: fill,
    washAlpha: washAlpha,
    wallpaperLuminance: wallpaperLuminance,
  );
  if (preferred != null) {
    // 彩色墨（含导入写入的深墨）只在**这张卡的真实卡面**上达标才保留：
    // 旧实现拿整屏平均亮度检查，近黑水面上那张卡因此拿到了 3:1 的"通过"。
    if (cardInkContrastRatio(preferred, surface) >= minContrastRatio) {
      return preferred;
    }
    // 不达标仍不强抢用户的选择：先把它的明度推到达标（保色相），推不动
    // （彩色墨对着中等亮度背景常常怎么推都不够）才回落黑白。
    if (!_isNeutral(preferred)) {
      final pushed = _pushLightnessForContrast(
        preferred,
        surface,
        minContrastRatio,
      );
      if (pushed != null) {
        return pushed;
      }
    }
  }
  return bestCardInkForLuminance(surface);
}

/// 详情墨（教师 / 地点 / 天气 / 备注那几行）：跟随标题墨的极性，透明度软化。
///
/// 极性必须跟标题一致：同一张卡上出现「白标题 + 黑简介」读起来是半洗白的混色卡
/// （见 `course_color_palette.dart` 里同一条结论）。
///
/// 软化会把对比度再打掉一截：半透明墨上屏后是「墨与背景的混合色」，所以能否
/// 读清要拿**混合后的实际颜色**去比背景，而不是拿墨色原值去比。达不到正文标准
/// 就提回不透明的同一档墨 —— 极性不变，只把字加实。
Color cardSurfaceDetailInk(
  Color titleInk, {
  double alpha = 0.92,
  double? surfaceLuminance,
  double minContrastRatio = cardInkBodyTextContrastRatio,
}) {
  final softened = titleInk.withValues(alpha: alpha);
  if (surfaceLuminance == null) {
    return softened;
  }
  // 上屏后的实际亮度：墨以 [alpha] 压在背景上。
  final rendered = _compositeLuminance(
    titleInk.computeLuminance(),
    surfaceLuminance,
    alpha,
  );
  final hi = rendered > surfaceLuminance ? rendered : surfaceLuminance;
  final lo = rendered > surfaceLuminance ? surfaceLuminance : rendered;
  final renderedContrast = (hi + 0.05) / (lo + 0.05);
  return renderedContrast >= minContrastRatio ? softened : titleInk;
}

/// 把 [ink] 的明度沿「远离背景」的方向推，直到对比度达标；推不到返回 null。
///
/// 只动 HSL 的 lightness，**色相与饱和度不动** —— 用户挑的是「这个颜色」，
/// 换掉它会读作「我的设置失效了」（同 `home_page_background.dart` 里
/// `readableColorOnLuminance` 的口径）。
Color? _pushLightnessForContrast(
  Color ink,
  double backgroundLuminance,
  double minContrastRatio,
) {
  final hsl = HSLColor.fromColor(ink);
  final goLighter = backgroundLuminance < 0.5;
  const steps = 20;
  for (var step = 1; step <= steps; step++) {
    final delta = step / steps;
    final lightness = goLighter
        ? (hsl.lightness + (1 - hsl.lightness) * delta)
        : (hsl.lightness * (1 - delta));
    final candidate = hsl.withLightness(lightness.clamp(0.0, 1.0)).toColor();
    if (cardInkContrastRatio(candidate, backgroundLuminance) >=
        minContrastRatio) {
      return candidate;
    }
  }
  return null;
}

/// 是否中性墨（黑 / 白 / 灰）：中性墨没有「色相」可言，推到极限就等价于
/// 自动黑白，不必走保色相那条路。
bool _isNeutral(Color ink) {
  final channels = <double>[ink.r, ink.g, ink.b]..sort();
  if (channels.last - channels.first <= 0.04) {
    return true;
  }
  return HSLColor.fromColor(ink).saturation <= 0.15;
}

/// 把 [inkLuminance] 以 [alpha] 混到 [backgroundLuminance] 上的亮度。
double _compositeLuminance(
  double inkLuminance,
  double backgroundLuminance,
  double alpha,
) {
  return inkLuminance * alpha + backgroundLuminance * (1 - alpha);
}

/// 一张卡在屏幕上占的竖直区间（0~1，从屏幕顶往下），用来向
/// `WallpaperLuminanceProfile` 查「这张卡背后那块壁纸多亮」。
@immutable
class VerticalBand {
  const VerticalBand(this.fromFraction, this.toFraction);

  final double fromFraction;
  final double toFraction;

  /// 由卡片的屏幕矩形与整屏高度算出。
  factory VerticalBand.fromRect(Rect rect, double screenHeight) {
    if (screenHeight <= 0 || !rect.height.isFinite) {
      return const VerticalBand(0.22, 0.72);
    }
    final from = (rect.top / screenHeight).clamp(0.0, 1.0);
    final to = (rect.bottom / screenHeight).clamp(0.0, 1.0);
    if (to <= from) {
      return VerticalBand(from, from + 0.01);
    }
    return VerticalBand(from, to);
  }

  /// 这个区间背后那块壁纸的亮度；剖面不可用时返回 null。
  double? luminanceOf(WallpaperLuminanceProfile? profile) {
    if (profile == null || profile.isEmpty) {
      return null;
    }
    return profile.luminanceForVerticalRange(fromFraction, toFraction);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VerticalBand &&
          other.fromFraction == fromFraction &&
          other.toFraction == toFraction;

  @override
  int get hashCode => Object.hash(fromFraction, toFraction);
}
