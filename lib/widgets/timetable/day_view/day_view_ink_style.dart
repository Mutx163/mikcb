import 'package:flutter/material.dart';

import '../../../models/timetable_settings.dart';
import '../../../utils/course_color_palette.dart';
import '../../../utils/hex_color.dart';
import '../../../utils/home_page_background.dart';
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
///   （`WallpaperLuminanceController.weekdayInk(settings)`），摘要卡墨色用它。
class DayViewInkEnvironment {
  final bool backdropBlurOn;
  final double? wallpaperBodyLuminance;
  final double? wallpaperTopLuminance;
  final double? wallpaperWeekdayInkLuminance;

  const DayViewInkEnvironment({
    required this.backdropBlurOn,
    this.wallpaperBodyLuminance,
    this.wallpaperTopLuminance,
    this.wallpaperWeekdayInkLuminance,
  });
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
TimetableDayAgendaPalette resolveDayAgendaPalette(
  Color background, {
  String? foregroundHex,
  TimetableSettings? settings,
  required DayViewInkEnvironment env,
}) {
  // Keep pastel import colors light; only a tiny white lift for depth.
  final fillColor = background;
  final baseColor = Color.lerp(fillColor, Colors.white, 0.06) ?? fillColor;
  final customInk = foregroundHex == null || foregroundHex.trim().isEmpty
      ? null
      : parseHexColorOrFallback(foregroundHex, fallback: Colors.white);
  // 自定义字色（导入/LAN 同步携带）在实心卡面上做可读性兜底：与卡色
  // 同色系时（如蓝字配蓝卡）替换为黑白最优墨色。玻璃档按壁纸亮度走玻璃
  // 规则（彩色墨回落自动黑白、中性墨对比度门槛），与 CourseCard 行为
  // 一致；壁纸亮度未知时保留用户选择。
  final showsWallpaper =
      settings != null &&
      courseCardSurfaceShowsWallpaper(
        effectiveCourseCardSurfaceStyle(
          settings,
          gaussianBlurAvailable: env.backdropBlurOn,
        ),
      );
  final foregroundColor = customInk == null
      ? dayAgendaAutoInk(fillColor, settings: settings, env: env)
      : resolveReadableCourseCardTitleColor(
          preferred: customInk,
          cardColor: fillColor,
          surfaceShowsWallpaper: showsWallpaper,
          wallpaperLuminance: showsWallpaper
              ? (env.wallpaperBodyLuminance ?? env.wallpaperTopLuminance)
              : null,
        );
  return TimetableDayAgendaPalette(
    baseColor: baseColor,
    fillColor: fillColor,
    foregroundColor: foregroundColor,
  );
}

/// Default agenda-card ink when the course has no custom text colour.
///
/// Opaque styles keep the legacy white-on-hue. The gaussian style shows
/// mostly wallpaper through a ~40% tint, so the ink flips black/white against
/// the blend of course hue and the wallpaper band behind the cards — a bright
/// wallpaper region otherwise gives white-on-white.
///
/// 原 `_TimetableScreenState._dayAgendaAutoInk`（2026-10-20 搬到本库）；
/// 判据不变，只把「模糊管线可用吗 + 壁纸两条亮度带」换成 [env] 快照。
Color dayAgendaAutoInk(
  Color fill, {
  TimetableSettings? settings,
  required DayViewInkEnvironment env,
}) {
  if (settings == null) {
    return Colors.white;
  }
  final glassOverWallpaper = effectiveCourseCardSurfaceStyle(
    settings,
    gaussianBlurAvailable: env.backdropBlurOn,
  ).isGlass;
  if (!glassOverWallpaper) {
    return Colors.white;
  }
  final wallpaperLuminance =
      env.wallpaperBodyLuminance ?? env.wallpaperTopLuminance;
  if (wallpaperLuminance == null) {
    return Colors.white;
  }
  final effectiveLuminance =
      fill.computeLuminance() * 0.5 + wallpaperLuminance * 0.5;
  return homePageChromeForegroundForLuminance(
    effectiveLuminance,
    fallback: Colors.white,
  );
}
