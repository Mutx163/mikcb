/// 月视图的**分区判墨**（2026-10-21，专业美学评审 P0-1 / P0-2 的落地）。
///
/// ## 为什么不能「整屏一个亮度」
///
/// 旧实现（`monthPageInkOverWallpaper`）取壁纸**主体带**（屏幕 22%~72%）的平均
/// 亮度，42 个格子共用这一个数去判黑字还是白字。实测真机截图：
///
/// * 同一屏壁纸自上而下亮度从 **0.56**（顶部亮云）走到 **0.23**（底部深紫），
///   而卡面填充亮度跨 **0.56 → 0.23**，同一个黑字在 42 格上的对比度因此
///   从 **12:1** 摆到 **5:1**；
/// * 月外日期（前后月补位）再叠两层弱化（墨色 `×0.45`、整卡再 `×0.55`），
///   落到 **1.97:1** —— 1–7 日那一整行物理上不可读。
///
/// 判据的粒度比场景粗一个数量级，是这个页面最重要的可读性病灶。本文件把它拆成
/// 「每一行查自己那段壁纸」＋「弱化只弱化到仍然可读为止」。
///
/// ## 一条重要边界：弱化 ≠ 变淡
///
/// 「月外日期要弱一点」是对的，旧实现的问题在**弱化的手段**：
/// 乘两次 alpha 后墨色与卡面的亮度差被吃掉了。这里改成**按对比度弱化**——
/// 把墨色推到「刚好还读得出来」（[monthOutsideTextContrast]）为止，而不是
/// 推到一个凭感觉的 alpha。浅色卡面上它仍然明显更淡（8:1 → 3.2:1）；
/// 深色卡面上几乎不淡（3.7:1 → 3.2:1），因为那里已经没有可淡的空间。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'card_surface_ink.dart';
import 'wallpaper_luminance_profile.dart';

/// 日期数字的对比度门槛：WCAG AA 正文（14sp，非大字）。
const double monthCellTextContrast = 4.5;

/// 月外日期弱化后**仍须达到**的对比度。
///
/// 3.2 的依据：它比 [monthCellTextContrast] 明显低（看得出"这是上个月"），
/// 又高于 WCAG 的非正文下限 3.0（看得出"这是几号"）。旧实现实测 1.97:1，
/// 低于 3.0 就不是"弱"，而是"没有"。
const double monthOutsideTextContrast = 3.2;

/// 圆点（课程 / 考试 / 日程标记）与卡面的最小对比度。
///
/// 圆点是非文字图形，WCAG 图形对象门槛就是 3.0。实测旧实现里课程点（浅粉，
/// 5dp）压在暖色壁纸卡面上只有 **1.01:1** —— 不是"偏淡"，是等于没有。
const double monthDotContrast = 3;

/// 两个亮度之间的 WCAG 对比度（1–21）。
double _contrastOf(double a, double b) {
  final hi = math.max(a, b);
  final lo = math.min(a, b);
  return (hi + 0.05) / (lo + 0.05);
}

/// 一格日期背后那段壁纸的亮度 → 卡面实际亮度（自有底色 × 染色比例 + 壁纸）。
///
/// 与渲染层同源：`washAlpha` 必须传 `CourseSurface.washAlpha(...)` 的真实值，
/// 不要在调用方另写一个常数（写死 0.5 正是 2026-10-21 那批判错字色的来源，
/// 见 `card_surface_ink.dart` 的文件注释）。
double monthCellSurfaceLuminance({
  required Color fill,
  required double washAlpha,
  required double wallpaperLuminance,
}) {
  return cardSurfaceLuminance(
    fill: fill,
    washAlpha: washAlpha,
    wallpaperLuminance: wallpaperLuminance,
  );
}

/// 把 [ink] 弱化到「仍然满足 [targetContrast]」的最淡程度。
///
/// 实现是在 alpha 上二分：alpha = 1 是原色、越小越接近卡面（越淡）。取满足
/// 对比度门槛的最小 alpha —— 也就是**弱化到看得清的极限**，再淡一步就不可读。
///
/// 满强度的对比度本来就低于门槛时**原样返回**：那说明这组配色在极限处都勉强，
/// 再淡只会更糟；该由调用方（圆点 / 描边）另想办法，不在这里偷偷减对比度。
///
/// ⚠️ 合成按**亮度线性**近似（真实 alpha 混合发生在编码 sRGB 通道上）。这个
/// 近似只在两端之间插值，且本函数一律留出 3.0 以上的余量，误差不会把结果推到
/// 门槛以下 —— 用它是为了不引入「卡面颜色」这一路额外输入（月格子里卡面是
/// 半透明玻璃叠在壁纸上，颜色并不简单可得）。
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

/// 一格日期该用的墨色（**按这一格背后那段壁纸**判，不是整屏一个数）。
///
/// [outsideMonth] 为真时（前后月补位格）再压到 [monthOutsideTextContrast]：
/// 弱化只弱到仍然可读，绝不再乘第二个 alpha。
Color monthCellInkFor({
  required double wallpaperLuminance,
  required Color fill,
  required double washAlpha,
  bool outsideMonth = false,
}) {
  final surface = monthCellSurfaceLuminance(
    fill: fill,
    washAlpha: washAlpha,
    wallpaperLuminance: wallpaperLuminance,
  );
  final ink = bestCardInkForLuminance(surface);
  if (!outsideMonth) {
    return ink;
  }
  return dimInkToContrast(ink, surface);
}

/// 把 [ink] 向卡面 [cardFill] **混色**来弱化（不压 alpha）。
///
/// ## 为什么弱化不能用 alpha
///
/// 半透明墨上屏后是「墨与背景的混合色」—— 也就是说它以**同一个方向**把墨推向
/// 背景。想弱化时这正好把"墨与背景的亮度差"一起吃掉：真机实测图例里那颗
/// 「考试 0」的圆点用 `alpha 0.28` 压完只剩 **1.42:1**，读起来不是"弱"，是
/// "禁用/没加载出来"。
///
/// 向卡面混色是同一件事的可控版本：它只改变**颜色**，不改变不透明度，所以
/// 想让"弱多少"就说多少，而不是让不透明度顺带决定可读性。
///
/// [amount] = 0 是原色、1 是完全等于卡面（看不见）。调用方给 0.5~0.72 一档。
Color dimTowardCard(Color ink, Color cardFill, {double amount = 0.62}) {
  return Color.lerp(ink, cardFill, amount.clamp(0.0, 1.0))!;
}

/// 圆点在卡面上是否已经足够可辨；不够时该用哪个颜色描边。
///
/// 课程点用的是**课程自身的颜色**（用户导入时就带过来的），它天然不受控：
/// 浅粉、浅黄这类颜色压在任意卡面上都可能接近卡面亮度。所以圆点必须有描边，
/// 而描边色取「卡面墨色」（与卡面已经过了对比度判定的那一档），而不是
/// `scaffoldBackgroundColor` —— 后者在独立页外壳里是 **transparent**，
/// 描边等于没画（这正是旧实现 `outlined: true` 从来没生效的原因）。
Color monthDotOutlineColor(Color cellInk) => cellInk.withValues(alpha: 0.55);

/// 把网格的**每一行**换算成「这一行背后那段壁纸的亮度」。
///
/// [gridTopOnScreen] 是网格顶边在屏幕上的绝对 y（逻辑 px），由页面用
/// `屏幕高 - 正文约束高` 反推 —— 不靠「状态栏 + 标题行 + 工具行」那串加法，
/// 因为玻璃带那条缝只有在带子真的画的时候才存在，加法学不准。
///
/// [headerHeight] 是星期表头；[rowHeight] 是单行高度；[topPadding] 是网格外面
/// 那层上内边距（算进窗口高、真占屏幕）。
///
/// 返回长度恒为 [rowCount]；剖面不可用（还没采到 / 采样失败）时每项都是 null，
/// 调用方据此回落到主题墨色 —— 与改动前同一条兜底，不会比原来更差。
List<double?> monthRowLuminances({
  required WallpaperLuminanceProfile? profile,
  required double screenHeight,
  required double gridTopOnScreen,
  required double headerHeight,
  required double rowHeight,
  required int rowCount,
  double topPadding = 0,
}) {
  if (rowCount <= 0) {
    return const <double?>[];
  }
  if (profile == null || profile.isEmpty || screenHeight <= 0) {
    return List<double?>.filled(rowCount, null);
  }
  final rowsTop = gridTopOnScreen + topPadding + headerHeight;
  return <double?>[
    for (var row = 0; row < rowCount; row++)
      _bandLuminance(
        profile,
        screenHeight,
        rowsTop + rowHeight * row,
        rowsTop + rowHeight * (row + 1),
      ),
  ];
}

/// 屏幕上一段竖直区间 [(top], [bottom)] 背后壁纸的平均亮度；剖面无数据时 null。
double? monthBandLuminance(
  WallpaperLuminanceProfile? profile,
  double screenHeight, {
  required double top,
  required double bottom,
}) {
  if (profile == null || profile.isEmpty || screenHeight <= 0) {
    return null;
  }
  return _bandLuminance(profile, screenHeight, top, bottom);
}

double? _bandLuminance(
  WallpaperLuminanceProfile profile,
  double screenHeight,
  double top,
  double bottom,
) {
  final from = (top / screenHeight).clamp(0.0, 1.0);
  final to = (bottom / screenHeight).clamp(0.0, 1.0);
  return profile.luminanceForVerticalRange(from, to);
}

/// 表格拉杆（把手）该用的墨色。
///
/// 拉杆画在**壁纸上**（不在任何卡面上），是全页唯一教用户「这张表可以上滑」
/// 的控件。旧实现取「主体带平均亮度」判出的墨色再乘 **0.32** alpha：在真机那张
/// 壁纸上，主体带平均 0.356 判成深墨，而拉杆实际压着的那段水面只有 0.09 ——
/// 深墨 32% 压上去实测 **1.22:1**，等于没有。
///
/// 这里两点都改：① 判据换成**拉杆自己那段**壁纸的亮度；② 用满 alpha ——
/// 黑白两档对任一亮度的对比度都不低于 ~4.1:1（相等点在 0.20），不需要再靠
/// 半透明去"柔和"，柔和是用对比度换的。
Color monthHandleInk(double? wallpaperLuminance, {required Color fallback}) {
  if (wallpaperLuminance == null) {
    return fallback;
  }
  return bestCardInkForLuminance(wallpaperLuminance);
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
