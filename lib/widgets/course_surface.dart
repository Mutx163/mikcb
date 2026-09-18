import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../models/timetable_settings.dart';
import '../ui/hyperos/hyperos_blurred_header.dart';
import 'course_glass_shader.dart';
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

  /// 折射玻璃档的染色底透明度。
  ///
  /// 比高斯档（[frostedFillAlpha]）低一截：这一档的卖点就是「能看见背景在边缘
  /// 被掰弯」，染色压太实会把折射和高光一起盖掉；但也留足色相，让课程颜色
  /// 仍然可辨。
  static const double refractionFillAlpha = 0.32;

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
      CourseCardSurfaceStyle.refraction => _buildRefraction(context, radius),
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
            color.withValues(alpha: _scaledAlpha(1)),
            secondaryFillColor(color).withValues(alpha: _scaledAlpha(1)),
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
    // 模糊管线不可用（全局材质「实体卡片」= 模糊总开关关，或系统降级）时
    // 高斯档没有可采样背景：裸 tint 过壁纸读作透明卡片，必须回退实体卡面。
    // 调用方应已通过 effectiveCourseCardSurfaceStyle(gaussianBlurAvailable:)
    // 把墨色规则一并切到实体口径，这里是渲染层的最后防线。
    if (!blurEnabled) {
      return _buildSolid(radius);
    }
    final tint = color.withValues(alpha: _scaledAlpha(frostedFillAlpha));
    // Prefer the pre-blurred wallpaper fill when available: frost stays
    // identical while pages slide (no live BackdropFilter) and it keeps
    // painting inside an ancestor Opacity saveLayer — the
    // day-view open/close ramp fades the whole panel, where a real
    // BackdropFilter samples an empty buffer and the card collapses to its
    // bare tint until the ramp ends. The bitmap is built with the same sheet
    // sigma this style would pass to BackdropFilter, so the frost matches.
    final preblur = PreblurredWallpaperScope.maybeOf(context);

    if (preblur != null) {
      return ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            // Own layer for pager-driven repaints.
            const Positioned.fill(
              child: RepaintBoundary(child: PreblurredWallpaperAlignedFill()),
            ),
            Positioned.fill(child: ColoredBox(color: tint)),
            if (border != null) _borderOverlay(radius, border!),
            child,
          ],
        ),
      );
    }
    return _buildLiveBlurFallback(context, radius, tint);
  }

  /// 折射玻璃档：与 [CourseCardSurfaceStyle.gaussian] 采**同一份**共享预模糊
  /// 位图，差别只在最后一步 —— 这里把位图交给折射着色器再上屏（边缘按圆角 SDF
  /// 把背景掰弯 + 叠染色 + 叠受光边缘高光），而不是直接贴图。
  ///
  /// 之所以不另起一套模糊：整屏只有一份预模糊位图（[PreblurredWallpaperCache]），
  /// 一屏 20~50 张卡共用它，每张卡只多一次矩形绘制与一次纹理采样；而「每卡一次
  /// 实时 BackdropFilter」才是把课表拖到十几帧的元凶（见缓存类注释）。所以这一档
  /// 不会因为卡片变多而更贵。
  Widget _buildRefraction(BuildContext context, BorderRadius radius) {
    final blurEnabled = HyperosBlurredHeader.backdropBlurEnabled(context);
    // 与高斯档同款最后防线：模糊管线关了就没有可采样的磨砂背景，
    // 裸 tint 过壁纸读作透明卡片，回退实体卡面。
    if (!blurEnabled) {
      return _buildSolid(radius);
    }
    final tint = color.withValues(alpha: _scaledAlpha(refractionFillAlpha));
    final preblur = PreblurredWallpaperScope.maybeOf(context);

    if (preblur != null) {
      return ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(
              // Own layer for pager-driven repaints.
              child: RepaintBoundary(
                child: PreblurredWallpaperAlignedFill(
                  glass: CourseGlassStyle(
                    borderRadius: borderRadius,
                    tint: tint,
                  ),
                ),
              ),
            ),
            // 这里**不**再叠 ColoredBox：折射路径的染色由着色器自己出，它还要在
            // 染色之上叠边缘高光；外面再罩一层会把高光压掉。
            if (border != null) _borderOverlay(radius, border!),
            child,
          ],
        ),
      );
    }
    return _buildLiveBlurFallback(context, radius, tint);
  }

  /// 预模糊位图尚未就绪那几帧的过渡外观：纯 tint + 分组实时模糊兜底。
  ///
  /// 两档玻璃共用（见 [_buildGaussian] 里对「为什么不回退实时 BackdropFilter」
  /// 的说明：位图还在后台构建时对空 backdrop 做分组采样，既触发首帧 shader
  /// 编译风暴，也会把空缓冲采成脏色）。位图到位后 InheritedWidget 会通知卡片
  /// 切到各自的正规路径。
  Widget _buildLiveBlurFallback(
    BuildContext context,
    BorderRadius radius,
    Color tint,
  ) {
    final preblurPending = PreblurredWallpaperScope.isWaitingForBitmap(context);
    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          if (!preblurPending)
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
