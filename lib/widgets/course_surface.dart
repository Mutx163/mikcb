import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../models/timetable_settings.dart';
import '../ui/hyperos/hyperos_blurred_header.dart';
import 'preblurred_wallpaper_glass.dart';

/// Paints one of the two supported [CourseCardSurfaceStyle] looks behind
/// [child].
///
/// Single source of truth for course surface material, shared by the week grid
/// ([CourseCard]) and the day view agenda cards, so the two cannot drift.
///
/// **Never wrap this widget in [Opacity].** [BackdropFilter] cannot sample
/// behind an opacity layer, so frost collapses to fully transparent. Dim via
/// [opacityScale], which scales fill alphas.
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

  /// Course hue. Drives the solid gradient and translucent/gaussian fill.
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

  /// Shadow on the opaque decoration ([CourseCardSurfaceStyle.solid] only),
  /// matching legacy card behaviour.
  final List<BoxShadow>? boxShadow;

  /// Shadow painted beneath the surface for **all** styles.
  ///
  /// Use this when a card should keep floating off the page; the gaussian
  /// style ignores [boxShadow] so that opaque-only behaviour stays unchanged
  /// for existing callers.
  final List<BoxShadow>? outerShadow;

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
      CourseCardSurfaceStyle.gaussian => _buildGaussian(context, radius),
    };

    final outer = outerShadow;
    if (outer == null || outer.isEmpty) {
      return surface;
    }
    // Shadow-only decoration (no fill), so it also works with gaussian cards.
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

  Widget _buildGaussian(BuildContext context, BorderRadius radius) {
    final blurEnabled = HyperosBlurredHeader.backdropBlurEnabled(context);
    final tint = color.withValues(alpha: _scaledAlpha(frostedFillAlpha));
    // Prefer the pre-blurred wallpaper fill when available: frost stays
    // identical while pages slide (no live BackdropFilter) and it keeps
    // painting inside an ancestor Opacity saveLayer — the
    // day-view open/close ramp fades the whole panel, where a real
    // BackdropFilter samples an empty buffer and the card collapses to its
    // bare tint until the ramp ends. The bitmap is built with the same sheet
    // sigma this style would pass to BackdropFilter, so the frost matches.
    final preblur = blurEnabled
        ? PreblurredWallpaperScope.maybeOf(context)
        : null;
    // 位图仍在后台构建时不回退实时 BackdropFilter：对尚未解码完成的空
    // backdrop 做分组采样既触发首帧 shader 编译风暴，也会把空缓冲采成脏色。
    // 先以纯 tint 过渡；位图就绪后 InheritedWidget 通知本卡片切到位图填充。
    final preblurPending =
        preblur == null &&
        blurEnabled &&
        PreblurredWallpaperScope.isWaitingForBitmap(context);

    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          if (preblur != null)
            // Own layer for pager-driven repaints.
            const Positioned.fill(
              child: RepaintBoundary(child: PreblurredWallpaperAlignedFill()),
            )
          else if (blurEnabled && !preblurPending)
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

  static Widget _borderOverlay(BorderRadius radius, Border border) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, border: border),
      ),
    );
  }
}
