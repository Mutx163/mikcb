import 'package:flutter/material.dart';

import '../models/timetable_settings.dart';
import '../ui/hyperos/liquid/hyperos_liquid_glass_surface.dart';

/// Ambient policy for dense timetable [CourseCard] liquid glass.
///
/// Provided by [CourseCardLiquidGlassHost] around the week grid (or a tight
/// card cluster). Cards read this to choose
/// [HyperosLiquidGlassLayerMode.sharedLayer] instead of per-card layers.
///
/// Presence of this scope is the whole signal: dense course grids share one
/// liquid-glass layer and one backdrop capture instead of one layer per card.
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
    return CourseCardLiquidGlassScope(
      child: HyperosLiquidGlassLayer(
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
