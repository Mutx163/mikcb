import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/timetable_settings.dart';
import '../ui/hyperos/liquid/hyperos_liquid_glass_surface.dart';

/// Drives the dense course-card material policy while the timetable moves.
///
/// Real liquid glass is intentionally used while the page is settled. During a
/// pager/expand animation the package has to rebuild the shared screen-space
/// geometry texture on every frame; that is the expensive path that made the
/// old all-live implementation drop frames on mid-range devices. The notifier
/// lets the host remove the shader layer for the short motion window and lets
/// each card use the cached wallpaper fill instead.
class CourseCardGlassMotionScope
    extends InheritedNotifier<ValueListenable<bool>> {
  const CourseCardGlassMotionScope({
    required this.motion,
    required super.child,
    super.key,
  }) : super(notifier: motion);

  final ValueListenable<bool> motion;

  static bool isMovingOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<CourseCardGlassMotionScope>()
            ?.motion
            .value ??
        false;
  }
}

/// Ambient policy for dense timetable [CourseCard] liquid glass.
///
/// Provided by [CourseCardLiquidGlassHost] around the week grid (or a tight
/// card cluster). Cards read this to choose
/// [HyperosLiquidGlassLayerMode.sharedLayer] instead of per-card layers.
///
/// Presence of this scope is the whole signal: dense course grids share one
/// liquid-glass layer and one backdrop capture instead of one layer per card.
class CourseCardLiquidGlassScope extends InheritedWidget {
  const CourseCardLiquidGlassScope({
    required super.child,
    this.motionFallback = false,
    super.key,
  });

  /// True only during pager/expand motion, when cards deliberately use the
  /// lightweight cached material instead of rebuilding real refraction.
  final bool motionFallback;

  static CourseCardLiquidGlassScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<CourseCardLiquidGlassScope>();
  }

  @override
  bool updateShouldNotify(CourseCardLiquidGlassScope oldWidget) =>
      motionFallback != oldWidget.motionFallback;
}

/// Shared liquid-glass host for dense course cards.
///
/// Architecture:
/// - **One** [LiquidGlassLayer] for the whole card grid (shared backdrop).
/// - Cards register as [HyperosLiquidGlassLayerMode.sharedLayer] shapes.
/// - Course hue stays on per-card wash overlays (independent conflict dim).
/// - The shader probe decides whether the dense grid uses real refraction or
///   fake glass; both paths share one material and one backdrop capture.
class CourseCardLiquidGlassHost extends StatelessWidget {
  const CourseCardLiquidGlassHost({required this.child, super.key});

  final Widget child;

  /// Whether this device can run real liquid-glass shaders.
  static bool get supportsRealRefraction =>
      HyperosLiquidGlassSurface.supportsRealRefraction;

  @override
  Widget build(BuildContext context) {
    final motionFallback = CourseCardGlassMotionScope.isMovingOf(context);

    // Do not keep a real LiquidGlassLayer mounted during pager/expand motion.
    // The package tracks every shape transform and rebuilds a full-screen matte
    // texture when any card moves. The fallback is only a short-lived motion
    // material; once the animation settles this widget rebuilds into the real
    // shader path again.
    return CourseCardLiquidGlassScope(
      motionFallback: motionFallback,
      child: motionFallback
          ? child
          : HyperosLiquidGlassLayer(
              role: HyperosLiquidGlassRole.courseCard,
              fake: false,
              child: child,
            ),
    );
  }
}

/// Wraps a course grid in whatever glass host its surface style needs.
///
/// Shared by the home week grid and the settings previews so the two cannot
/// drift into different hosting strategies:
///
/// - [CourseCardSurfaceStyle.liquidGlass] → [CourseCardLiquidGlassHost], i.e.
///   one shared [LiquidGlassLayer] so every card samples a single backdrop
///   capture instead of one each.
/// - [CourseCardSurfaceStyle.gaussian] → a bare [BackdropGroup], which the
///   cards' `BackdropFilter.grouped` then shares.
/// - Opaque styles need no host at all.
class CourseGridGlassHost extends StatelessWidget {
  const CourseGridGlassHost({
    required this.settings,
    required this.child,
    super.key,
  });

  final TimetableSettings settings;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return switch (settings.courseCardSurfaceStyle) {
      CourseCardSurfaceStyle.liquidGlass => CourseCardLiquidGlassHost(
        child: child,
      ),
      CourseCardSurfaceStyle.gaussian => BackdropGroup(child: child),
      CourseCardSurfaceStyle.solid ||
      CourseCardSurfaceStyle.translucent => child,
    };
  }
}
