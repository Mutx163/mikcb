import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../models/liquid_glass_tuning.dart';
import '../models/timetable_settings.dart';
import '../ui/hyperos/hyperos_blurred_header.dart';
import '../ui/hyperos/liquid/hyperos_liquid_glass_surface.dart';
import 'course_card_liquid_glass_host.dart';
import 'preblurred_wallpaper_glass.dart';

/// Paints one of the four [CourseCardSurfaceStyle] looks behind [child].
///
/// Single source of truth for course surface material, shared by the week grid
/// ([CourseCard]) and the day view agenda cards, so the two cannot drift.
///
/// **Never wrap this widget in [Opacity].** [BackdropFilter] and FakeGlass
/// cannot sample behind an opacity layer, so frost collapses to fully
/// transparent. Dim via [opacityScale], which scales fill and tint alphas.
class CourseSurface extends StatelessWidget {
  const CourseSurface({
    required this.style,
    required this.color,
    required this.borderRadius,
    required this.child,
    this.opacityScale = 1.0,
    this.solidGradient,
    this.border,
    this.boxShadow,
    this.outerShadow,
    super.key,
  });

  final CourseCardSurfaceStyle style;

  /// Course hue. Drives the solid gradient, translucent fill and glass wash.
  final Color color;

  final double borderRadius;
  final Widget child;

  /// Dim factor for conflict / holiday / suspended states (0–1).
  ///
  /// Multiplied into every fill and tint alpha. See the class doc for why this
  /// exists instead of an [Opacity] wrapper.
  final double opacityScale;

  /// Overrides the default two-stop hue gradient used by [
  /// CourseCardSurfaceStyle.solid].
  final Gradient? solidGradient;

  /// Emphasis border. Drawn inside the decoration for the opaque styles and as
  /// an overlay above the frost for the blurred ones.
  final Border? border;

  /// Shadow on the opaque decoration ([CourseCardSurfaceStyle.solid] /
  /// [CourseCardSurfaceStyle.translucent] only), matching legacy card behaviour.
  final List<BoxShadow>? boxShadow;

  /// Shadow painted beneath the surface for **all** styles.
  ///
  /// Use this when a card should keep floating off the page even as glass; the
  /// blurred styles ignore [boxShadow] so that opaque-only behaviour stays
  /// unchanged for existing callers.
  final List<BoxShadow>? outerShadow;

  /// Denser than a plain scrim so labels stay legible over busy wallpapers.
  static const double translucentFillAlpha = 0.72;
  static const double frostedFillAlpha = 0.42;

  /// Second stop of the default [CourseCardSurfaceStyle.solid] gradient.
  static Color secondaryFillColor(Color color) {
    return Color.lerp(color, Colors.white, 0.08) ?? color;
  }

  double _scaledAlpha(double baseAlpha) {
    return (baseAlpha * opacityScale).clamp(0.04, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);

    final surface = switch (style) {
      CourseCardSurfaceStyle.solid => _buildSolid(radius),
      CourseCardSurfaceStyle.translucent => _buildTranslucent(radius),
      CourseCardSurfaceStyle.gaussian => _buildGaussian(context, radius),
      CourseCardSurfaceStyle.liquidGlass => _buildLiquidGlass(context, radius),
    };

    final outer = outerShadow;
    if (outer == null || outer.isEmpty) {
      return surface;
    }
    // Shadow-only decoration (no fill), so it reads through glass styles too.
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: outer),
      child: surface,
    );
  }

  Widget _buildSolid(BorderRadius radius) {
    final gradient =
        solidGradient ??
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: _scaledAlpha(1.0)),
            secondaryFillColor(color).withValues(alpha: _scaledAlpha(1.0)),
          ],
        );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: gradient,
        border: border,
        boxShadow: boxShadow,
      ),
      child: child,
    );
  }

  Widget _buildTranslucent(BorderRadius radius) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        color: color.withValues(alpha: _scaledAlpha(translucentFillAlpha)),
        border: border,
        boxShadow: boxShadow,
      ),
      child: child,
    );
  }

  Widget _buildGaussian(BuildContext context, BorderRadius radius) {
    final blurEnabled = HyperosBlurredHeader.backdropBlurEnabled(context);
    final tint = color.withValues(alpha: _scaledAlpha(frostedFillAlpha));
    // Prefer the pre-blurred wallpaper fill when available, same as liquid
    // glass: frost stays identical while pages slide (no live BackdropFilter)
    // and it keeps painting inside an ancestor Opacity saveLayer — the
    // day-view open/close ramp fades the whole panel, where a real
    // BackdropFilter samples an empty buffer and the card collapses to its
    // bare tint until the ramp ends. The bitmap is built with the same sheet
    // sigma this style would pass to BackdropFilter, so the frost matches.
    final preblur = blurEnabled
        ? PreblurredWallpaperScope.maybeOf(context)
        : null;

    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          if (preblur != null)
            // Own layer for the pager-driven repaints (see _buildLiquidGlass).
            const Positioned.fill(
              child: RepaintBoundary(child: PreblurredWallpaperAlignedFill()),
            )
          else if (blurEnabled)
            Positioned.fill(
              // Grouped: shares one backdrop capture with the sibling cards in
              // the surrounding BackdropGroup instead of capturing per card.
              child: BackdropFilter.grouped(
                filter: ImageFilter.blur(
                  sigmaX: FrostedAppearanceScope.of(context).sheetBlurSigma,
                  sigmaY: FrostedAppearanceScope.of(context).sheetBlurSigma,
                  tileMode: TileMode.clamp,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          Positioned.fill(child: ColoredBox(color: tint)),
          if (border != null) _borderOverlay(radius, border!),
          child,
        ],
      ),
    );
  }

  Widget _buildLiquidGlass(BuildContext context, BorderRadius radius) {
    final blurEnabled = HyperosBlurredHeader.backdropBlurEnabled(context);
    final appearance = FrostedAppearanceScope.of(context);
    final tuning = appearance.liquidGlassTuning ?? LiquidGlassTuning.defaults;
    // Prefer the pre-blurred wallpaper fill when available: frost stays
    // identical while pages slide (no live BackdropFilter) and, because it is a
    // plain bitmap sample, it works even under an isolating ancestor layer.
    final preblur = PreblurredWallpaperScope.maybeOf(context);
    final glassTintAlpha = tuning.tintAlpha.clamp(0.0, 1.0);
    final washAlpha = _scaledAlpha(frostedFillAlpha);
    final highlightAlpha = _scaledAlpha(0.55);

    // Platform blur off → translucent tint only.
    if (!blurEnabled) {
      return ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: color.withValues(
                  alpha: _scaledAlpha(translucentFillAlpha),
                ),
              ),
            ),
            if (border != null) _borderOverlay(radius, border!),
            child,
          ],
        ),
      );
    }

    if (preblur != null) {
      return ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            // Own layer: with a screen-fixed wallpaper the pager listener
            // marks this fill dirty on every swipe frame; without a boundary
            // that repaint re-records the whole card (texts, badges, wash
            // overlays) instead of just one drawImageRect per card.
            const Positioned.fill(
              child: RepaintBoundary(child: PreblurredWallpaperAlignedFill()),
            ),
            // Same glass tint as sheets, headers and popups.
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: glassTintAlpha),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(color: color.withValues(alpha: washAlpha)),
              ),
            ),
            // Edge highlight (cheap stand-in for liquid specular).
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: highlightAlpha),
                      width: 0.8,
                    ),
                  ),
                ),
              ),
            ),
            if (border != null) _borderOverlay(radius, border!),
            child,
          ],
        ),
      );
    }

    // No pre-blurred wallpaper (settings preview / no wallpaper): use the
    // package glass. Inside a host the shapes share one liquid-glass layer.
    final usesSharedHost = CourseCardLiquidGlassScope.maybeOf(context) != null;
    final layerMode = usesSharedHost
        ? HyperosLiquidGlassLayerMode.sharedLayer
        : HyperosLiquidGlassLayerMode.fake;

    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: HyperosLiquidGlassSurface(
                role: HyperosLiquidGlassRole.courseCard,
                layerMode: layerMode,
                borderRadius: borderRadius,
                contentLegibilityFill: false,
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(color: color.withValues(alpha: washAlpha)),
            ),
          ),
          if (border != null) _borderOverlay(radius, border!),
          child,
        ],
      ),
    );
  }

  static Widget _borderOverlay(BorderRadius radius, Border border) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, border: border),
      ),
    );
  }
}
