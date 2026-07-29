import 'package:flutter/material.dart';

import '../models/timetable_settings.dart';
import '../ui/hyperos/liquid/hyperos_liquid_glass_surface.dart';

/// Ambient policy for dense timetable [CourseCard] liquid glass.
///
/// Provided by [CourseCardLiquidGlassHost] around the week grid (or a tight
/// card cluster). Cards read this to choose
/// [HyperosLiquidGlassLayerMode.sharedLayer] instead of per-card layers.
///
/// Presence of this scope is the whole signal: dense course grids always use
/// the package FakeGlass / shared-backdrop path. Real refraction is reserved
/// for sparse chrome (sheets / headers) — at course-card density it recreates
/// N× offscreen work and collapses mid-range FPS (device-measured ~14 FPS).
class CourseCardLiquidGlassScope extends InheritedWidget {
  const CourseCardLiquidGlassScope({required super.child, super.key});

  static CourseCardLiquidGlassScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<CourseCardLiquidGlassScope>();
  }

  @override
  bool updateShouldNotify(CourseCardLiquidGlassScope oldWidget) => false;
}

/// Shared liquid-glass host for dense course cards.
///
/// Architecture (device-validated on mid-range Android):
/// - **One** [LiquidGlassLayer] with `fake: true` for the whole card grid
///   (shared [BackdropGroup] — O(1) backdrop capture, not O(N)).
/// - Cards register as [HyperosLiquidGlassLayerMode.sharedLayer] shapes →
///   [FakeGlass.inLayer] with shared settings.
/// - Course hue stays on per-card wash overlays (independent conflict dim).
/// - Real Impeller refraction is **not** used for the dense grid: on MediaTek
///   mid-range devices it measured ~14 FPS with multi-column real layers.
class CourseCardLiquidGlassHost extends StatelessWidget {
  const CourseCardLiquidGlassHost({required this.child, super.key});

  final Widget child;

  /// Whether this device can run real liquid-glass shaders.
  static bool get supportsRealRefraction =>
      HyperosLiquidGlassSurface.supportsRealRefraction;

  @override
  Widget build(BuildContext context) {
    return CourseCardLiquidGlassScope(
      child: HyperosLiquidGlassLayer(
        role: HyperosLiquidGlassRole.courseCard,
        // Shared FakeGlass + BackdropGroup (package recommended dense path).
        // Real refraction is never used at course-card density: the package
        // rebuilds its geometry matte with a synchronous toImageSync on every
        // frame the shapes move (measured ~14 FPS on mid-range MediaTek).
        fake: true,
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
///   one shared faked [LiquidGlassLayer] (which brings its own [BackdropGroup])
///   so every card samples a single backdrop capture instead of one each.
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
