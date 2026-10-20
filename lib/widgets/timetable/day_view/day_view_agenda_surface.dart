import 'package:flutter/material.dart';

import '../../../models/timetable_settings.dart';
import '../../../ui/hyperos/hyperos.dart';
import '../../../utils/home_page_background.dart';
import '../../course_surface.dart';

/// 日视图议程卡的表层（2026-10-20 自 `timetable_day_view_part.dart` 搬出）。
///
/// Day-view card surface honouring [TimetableSettings.courseCardSurfaceStyle]
/// (falling back to solid whenever there is no wallpaper backdrop to blur).
///
/// Shares [CourseSurface] with the week grid so the two views cannot drift.
/// The tap target sits *inside* the surface behind a transparent [Material]
/// so ink ripples paint above the frost rather than on the far page Material
/// (which is what `Ink(decoration:)` used to buy us on an opaque card).
///
/// [surfaceKey] 是给**表层本身**（[CourseSurface]）用的 key，不是本 widget 的
/// key：日视图摘要卡既有测试直接 `tester.widget(find.byKey(...))` 断言拿到的是
/// [CourseSurface]，所以身份必须落在那一层（见 `day_view_summary_material_test`）。
class DayViewAgendaSurface extends StatelessWidget {
  final TimetableSettings settings;
  final Color color;
  final Widget child;

  /// 从 State 传入的日视图卡片圆角（正源是 `_TimetableScreenState
  /// ._dayViewCardRadius`，避免两个 20 各写一份）。
  final double radius;

  final Key? surfaceKey;
  final Gradient? gradient;
  final Border? border;
  final List<BoxShadow>? shadow;
  final VoidCallback? onTap;
  final double opacityScale;

  const DayViewAgendaSurface({
    super.key,
    required this.settings,
    required this.color,
    required this.child,
    required this.radius,
    this.surfaceKey,
    this.gradient,
    this.border,
    this.shadow,
    this.onTap,
    this.opacityScale = 1,
  });

  @override
  Widget build(BuildContext context) {
    final content = onTap == null
        ? child
        : Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(radius),
              child: child,
            ),
          );
    return CourseSurface(
      key: surfaceKey,
      // Effective style: without a wallpaper or without the blur pipeline
      // (global solid / degraded) the gaussian look has no source to sample,
      // so every agenda card falls back to solid. 与顶部摘要卡**同源**
      // （[dayViewContentCardSurfaceStyle]）：日视图两种内容卡一个材质口径，
      // 见那里的说明。
      style: dayViewContentCardSurfaceStyle(
        settings,
        backdropBlurOn: HyperosBlurredHeader.backdropBlurEnabled(context),
      ),
      color: color,
      borderRadius: radius,
      opacityScale: opacityScale,
      solidGradient: gradient,
      border: border,
      outerShadow: shadow,
      child: content,
    );
  }
}
