import 'package:flutter/material.dart';

import '../../../models/course_glass_tuning.dart';
import '../../../models/timetable_settings.dart';
import '../../../utils/card_surface_ink.dart';
import '../../../utils/course_color_palette.dart';
import '../../../utils/hex_color.dart';
import '../../../utils/home_page_background.dart';
import '../../../utils/wallpaper_luminance_profile.dart';
import '../../../ui/hyperos/hyperos_blurred_header.dart';
import '../../course_surface.dart';
import '../timetable_day_agenda_models.dart';

/// 日视图判墨 / 判材质所需的「壁纸环境」快照。
///
/// 这些值原本是 `_TimetableScreenState` 的私有字段（`_luminance` 控制器）与
/// build 期的局部变量；搬到独立 widget 库后不再让 widget 反向读 State，
/// 由调用方（`timetable_day_view_part.dart`）算好一次性传下来：
///
/// - [backdropBlurOn]：全局模糊管线当前可用吗（`HyperosBlurredHeader
///   .backdropBlurEnabled`，与 `CourseSurface` 渲染时同一判据）；
/// - [wallpaperBodyLuminance] / [wallpaperTopLuminance]：卡片区 / 顶栏两条
///   壁纸亮度带（`WallpaperLuminanceController.body/top`），未知时为 null；
/// - [wallpaperWeekdayInkLuminance]：星期栏那条带的亮度
///   （`WallpaperLuminanceController.weekdayInk(settings)`），摘要卡墨色用它；
/// - [profile]：**逐行**亮度剖面。有它时每张卡按自己的竖直区间取局部亮度，
///   没有时回落到上面那几条整屏带（旧行为）。
class DayViewInkEnvironment {
  final bool backdropBlurOn;
  final double? wallpaperBodyLuminance;
  final double? wallpaperTopLuminance;
  final double? wallpaperWeekdayInkLuminance;

  /// 逐行亮度剖面（可为 null：壁纸还没采到手）。
  final WallpaperLuminanceProfile? profile;

  /// 当前屏幕高度（逻辑像素）。把卡片矩形换算成 0~1 的竖直区间要用它。
  ///
  /// 由调用方从 `MediaQuery.sizeOf` 传入；为 null 时退回整屏带，不做逐卡查询。
  final double? screenHeight;

  const DayViewInkEnvironment({
    required this.backdropBlurOn,
    this.wallpaperBodyLuminance,
    this.wallpaperTopLuminance,
    this.wallpaperWeekdayInkLuminance,
    this.profile,
    this.screenHeight,
  });

  /// 这张卡背后那块壁纸的亮度。
  ///
  /// [rect] 是卡片在屏幕上的矩形（由 `LayoutBuilder` / `RenderBox` 拿到）。
  /// 剖面与屏幕高度都有时才按局部区间取；否则回落到整屏 body 带、再回落到
  /// 顶栏带 —— 与旧实现同一条兜底顺序，不会出现「算不出来就变成 null」。
  double? luminanceBehind(Rect? rect) {
    final profile = this.profile;
    final height = screenHeight;
    if (rect != null && profile != null && profile.isNotEmpty && height != null) {
      final band = VerticalBand.fromRect(rect, height);
      final local = band.luminanceOf(profile);
      if (local != null) {
        return local;
      }
    }
    return wallpaperBodyLuminance ?? wallpaperTopLuminance;
  }

  /// 没有卡片矩形时的兜底亮度（整屏 body 带）。
  double? get fallbackLuminance =>
      wallpaperBodyLuminance ?? wallpaperTopLuminance;
}

/// Translucent chip/pill glaze under [ink]-coloured content.
///
/// White ink keeps the legacy white glaze; dark ink flips to a dark glaze —
/// a white wash under dark text over a bright wallpaper adds no contrast.
Color dayAgendaInkWash(Color ink, {required double lightAlpha}) {
  return ink.computeLuminance() > 0.5
      ? Colors.white.withValues(alpha: lightAlpha)
      : Colors.black.withValues(alpha: lightAlpha * 0.55);
}

/// 日视图议程卡的底色 / 填充 / 前景色三元组。
///
/// 原 `_TimetableScreenState._resolveDayAgendaPalette`（2026-10-20 搬到本库）。
///
/// [cardRect] 是这张卡**在屏幕上的实际矩形**（可为 null：拿不到时回落到整屏
/// 带）。判字色只用它背后那一小块壁纸的亮度 —— 用整屏平均是 2026-10-21 两张
/// 真机截图判错字色的直接原因（见 `card_surface_ink.dart` 的库注释）。
TimetableDayAgendaPalette resolveDayAgendaPalette(
  Color background, {
  String? foregroundHex,
  TimetableSettings? settings,
  required DayViewInkEnvironment env,
  Rect? cardRect,
  double? washAlpha,
}) {
  // Keep pastel import colors light; only a tiny white lift for depth.
  final fillColor = background;
  final baseColor = Color.lerp(fillColor, Colors.white, 0.06) ?? fillColor;
  final customInk = foregroundHex == null || foregroundHex.trim().isEmpty
      ? null
      : parseHexColorOrFallback(foregroundHex, fallback: Colors.white);
  // 自定义字色（导入/LAN 同步携带）在**这张卡的实际卡面**上做可读性兜底。
  //
  // 与旧实现的两处差别（都在 `resolveReadableCourseCardTitleColor` 内部统一）：
  // * 亮度取这张卡背后的局部亮度，不再是整屏 body 带；
  // * 混合权重取 `CourseSurface.washAlpha` 的真实染色比例，不再是写死的 0.5。
  final showsWallpaper =
      settings != null &&
      courseCardSurfaceShowsWallpaper(
        effectiveCourseCardSurfaceStyle(
          settings,
          gaussianBlurAvailable: env.backdropBlurOn,
        ),
      );
  final foregroundColor = customInk == null
      ? dayAgendaAutoInk(
          fillColor,
          settings: settings,
          env: env,
          cardRect: cardRect,
          washAlpha: washAlpha,
        )
      : resolveReadableCourseCardTitleColor(
          preferred: customInk,
          cardColor: fillColor,
          surfaceShowsWallpaper: showsWallpaper,
          wallpaperLuminance:
              showsWallpaper ? env.luminanceBehind(cardRect) : null,
        );
  return TimetableDayAgendaPalette(
    baseColor: baseColor,
    fillColor: fillColor,
    foregroundColor: foregroundColor,
  );
}

/// Default agenda-card ink when the course has no custom text colour.
///
/// 实体档：卡面是课程色实底，与壁纸无关，沿用「白字压课程色」的旧口径。
/// 玻璃档：卡面 = 课程色 × 真实染色比例 + 背后壁纸 × 其余 —— 明度按这条式子
/// 估出来后，取黑/白中对比度更高的一档（分界点因此落在 0.20，而不是旧实现
/// 写死的 0.45）。
///
/// 2026-10-21 修：旧实现是 `fill × 0.5 + 壁纸 × 0.5` 再按 0.45 翻转。卡面是
/// 主题白（作业带 / 日期卡）时那一半白恒定把结果推到 0.5 以上，于是浅色主题下
/// **永远是黑字**，壁纸再黑也不变 —— 真机上表现为黑字压在近黑夜景上。
Color dayAgendaAutoInk(
  Color fill, {
  TimetableSettings? settings,
  required DayViewInkEnvironment env,
  Rect? cardRect,
  double? washAlpha,
}) {
  if (settings == null) {
    return Colors.white;
  }
  final style = effectiveCourseCardSurfaceStyle(
    settings,
    gaussianBlurAvailable: env.backdropBlurOn,
  );
  if (!style.isGlass) {
    return Colors.white;
  }
  // 染色比例**必须**是渲染层真正用的那个值（`CourseSurface.washAlpha`），
  // 不能拿出厂常数顶替：用户把卡片的染色滑杆拖到「清澈」时真实 alpha 接近 0，
  // 拿 0.42/0.70 去估会把卡面判得比实际亮得多。
  //
  // 2026-10-21 实测（截图 2，浅色主题 + 水墨夜景壁纸）：卡面内部 0.071，
  // 上下邻接的裸壁纸 0.078~0.114 —— 卡比壁纸还暗，说明实际有效染色只有 ~3%。
  // 所以这里的 [washAlpha] 由 widget 层（拿得到 context）用
  // `CourseSurface.washAlpha` 算好传进来；只有没传时才回落到出厂值。
  final resolvedWashAlpha = washAlpha ?? _defaultWashAlphaFor(style);
  return cardSurfaceInk(
    fill: fill,
    washAlpha: resolvedWashAlpha,
    wallpaperLuminance: env.luminanceBehind(cardRect),
  );
}

/// 日视图卡面的**真实染色比例**（判字色用，与渲染层同源）。
///
/// 正源是 `CourseSurface.washAlpha`：它吃用户调的材质档、深色配方与压暗系数。
/// 判色绝不能拿出厂常数顶替 —— 2026-10-21 实测（浅色主题 + 水墨夜景壁纸）卡面
/// 有效染色只有约 3%，而出厂常数是 42%~70%，差一个量级：按常数判会把卡面算成
/// 中灰，从而给近黑壁纸上的卡发黑字。
///
/// 放在本库而不是 State 分片：它只是「读 settings + 读 context」的纯取值，与
/// [dayAgendaAutoInk] 是一对；留在 State 里会顶爆 timetable_screen 的行数棘轮。
double dayAgendaWashAlpha(BuildContext context, TimetableSettings settings) {
  final style = effectiveCourseCardSurfaceStyle(
    settings,
    gaussianBlurAvailable: HyperosBlurredHeader.backdropBlurEnabled(context),
  );
  return CourseSurface.washAlpha(context, style);
}

/// 拿不到 context 时的兜底染色比例（出厂档）。
///
/// 正源是 `CourseSurface.washAlpha`（吃用户调档与深色配方）；这里只是「调用方
/// 没传」时的最后兜底，别把这里的常数当成真实值用。
double _defaultWashAlphaFor(CourseCardSurfaceStyle style) {
  return switch (style) {
    CourseCardSurfaceStyle.solid => 1,
    CourseCardSurfaceStyle.gaussian => CourseSurface.frostedFillAlpha,
    CourseCardSurfaceStyle.liquidGlass => CourseGlassTuning.defaultTintAlpha,
  };
}
