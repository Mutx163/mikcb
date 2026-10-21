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

  /// 强制走实体材质，忽略用户的课程卡材质设置。
  ///
  /// 给它是因为**玻璃卡必须能采到它背后真正的东西**：玻璃档在
  /// `CourseSurface` 里是 `BackdropFilter`，采的是**屏级 backdrop**（壁纸），
  /// 而不是"父容器画的白色" —— 父容器不透明也拦不住它。于是把玻璃卡放进一块
  /// 白色面板里，卡片内部仍会透出壁纸纹理（用户 2026-10-21 报：「为什么每一个
  /// 卡片，在白色的背景下，还能显示出壁纸来，这不合理」）。
  ///
  /// 面板内的卡片因此一律实体化：这是"容器决定材质"的正当例外 —— 玻璃的意义
  /// 是透出背景，而这里的背景是**面板**，不是壁纸。
  final bool forceSolid;

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
    this.forceSolid = false,
  });

  /// 这一张卡该用哪种材质（**纯函数**，供测试钉口径）。
  ///
  /// [forceSolid] 为真时直接实体、不看用户设置 —— 用于"卡片躺在不透明容器里"
  /// 的场景（月视图信息面板）。理由见字段注释：玻璃采的是屏级 backdrop，
  /// 父容器不透明拦不住它。
  static CourseCardSurfaceStyle resolveSurfaceStyle({
    required TimetableSettings settings,
    required bool backdropBlurOn,
    required bool forceSolid,
  }) {
    if (forceSolid) {
      return CourseCardSurfaceStyle.solid;
    }
    return dayViewContentCardSurfaceStyle(
      settings,
      backdropBlurOn: backdropBlurOn,
    );
  }

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
      style: resolveSurfaceStyle(
        settings: settings,
        backdropBlurOn: HyperosBlurredHeader.backdropBlurEnabled(context),
        forceSolid: forceSolid,
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
