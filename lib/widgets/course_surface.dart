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

  /// 这档卡面把**自己的底色**压多少在壁纸上 —— 就是 [build] 里那个 tint 的 alpha。
  ///
  /// 判卡面墨色的调用方要按「卡色 × 这个比例 + 壁纸 × 余量」估卡面真实亮度
  /// （见 `contentCardInkOverWallpaper`）：只看壁纸亮度会在浅色主题下把白字判到
  /// 被冲白的卡面上。取数放在这里是为了与渲染层同源 —— 实体 1、高斯
  /// [frostedFillAlpha]、液态走卡片自己那套调参的 `tintAlpha`（深色下还吃
  /// 深色配方），别在调用方另写一份。
  ///
  /// [borderRadius] 与 `courseColor` 都不参与这个 alpha（只影响形状与 RGB），
  /// 所以内部按零半径、纯黑解析一次即可。
  static double washAlpha(
    BuildContext context,
    CourseCardSurfaceStyle style, {
    double opacityScale = 1,
  }) {
    return switch (style) {
      CourseCardSurfaceStyle.solid => 1,
      CourseCardSurfaceStyle.gaussian => courseGlassFillAlpha(
        frostedFillAlpha,
        opacityScale,
      ),
      CourseCardSurfaceStyle.liquidGlass => courseGlassStyleFor(
        appearance: FrostedAppearanceScope.of(context),
        borderRadius: 0,
        courseColor: const Color(0xFF000000),
        brightness: Theme.of(context).brightness,
        opacityScale: opacityScale,
      ).tint.a,
    };
  }

  /// Second stop of the default [CourseCardSurfaceStyle.solid] gradient.
  static Color secondaryFillColor(Color color) {
    return Color.lerp(color, Colors.white, 0.08) ?? color;
  }

  double _scaledAlpha(double baseAlpha) {
    return courseGlassFillAlpha(baseAlpha, opacityScale);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);

    final surface = switch (style) {
      CourseCardSurfaceStyle.solid => _buildSolid(radius),
      CourseCardSurfaceStyle.gaussian => _buildGaussian(context, radius),
      CourseCardSurfaceStyle.liquidGlass => _buildRefraction(context, radius),
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
    return _buildLiveBlurFallback(
      context,
      radius,
      tint,
      source: PreblurredWallpaperSource.home,
    );
  }

  /// 液态玻璃档：与 [CourseCardSurfaceStyle.gaussian] 采**同一份卡片位图**，
  /// 差别只在最后一步 —— 这里把位图交给折射着色器再上屏（边缘按圆角 SDF
  /// 把背景掰弯 + 叠染色 + 叠受光边缘高光），而不是直接贴图。
  ///
  /// 之所以不另起一套模糊：卡片位图整屏只有一份（[PreblurredWallpaperCache]），
  /// 一屏 20~50 张卡共用它，每张卡只多一次矩形绘制与一次纹理采样；而「每卡一次
  /// 实时 BackdropFilter」才是把课表拖到十几帧的元凶（见缓存类注释）。所以这一档
  /// 不会因为卡片变多而更贵。
  ///
  /// 卡片位图与首页那份（玻璃带 / 摘要替身卡）**是两张**：卡片有自己的磨砂量
  /// （`CourseGlassTuning.blurSigma`），共用一张就会「一处动两处变」。所以这里的
  /// 位图来自 [PreblurredWallpaperScope.courseCardMaybeOf]。
  Widget _buildRefraction(BuildContext context, BorderRadius radius) {
    final blurEnabled = HyperosBlurredHeader.backdropBlurEnabled(context);
    // 与高斯档同款最后防线：模糊管线关了就没有可采样的磨砂背景，
    // 裸 tint 过壁纸读作透明卡片，回退实体卡面。
    if (!blurEnabled) {
      return _buildSolid(radius);
    }
    // 参数来自**卡片自己的**那套档位（`CourseGlassTuning`），经唯一入口
    // `courseGlassStyleFor` 解析：形状走 `toStyle`、深色套同一份配方、染色取课程色。
    final glass = courseGlassStyleFor(
      appearance: FrostedAppearanceScope.of(context),
      borderRadius: borderRadius,
      courseColor: color,
      brightness: Theme.of(context).brightness,
      opacityScale: opacityScale,
    );
    final tint = glass.tint;
    // 卡片吃**它自己那份**预糊位图：磨砂量独立于首页玻璃带与日视图摘要卡。
    // 源必须显式指定 —— 高斯档同样读卡片那份，靠「有没有 glass」判会选错。
    final preblur = PreblurredWallpaperScope.courseCardMaybeOf(context);

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
                  glass: glass,
                  source: PreblurredWallpaperSource.courseCard,
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
    return _buildLiveBlurFallback(
      context,
      radius,
      tint,
      source: PreblurredWallpaperSource.courseCard,
    );
  }

  /// 预模糊位图尚未就绪那几帧的过渡外观：纯 tint + 分组实时模糊兜底。
  ///
  /// 两档玻璃共用（见 [_buildGaussian] 里对「为什么不回退实时 BackdropFilter」
  /// 的说明：位图还在后台构建时对空 backdrop 做分组采样，既触发首帧 shader
  /// 编译风暴，也会把空缓冲采成脏色）。位图到位后 InheritedWidget 会通知卡片
  /// 切到各自的正规路径。
  ///
  /// [source] 决定「在等哪一份位图」：液态档等的是卡片那份，高斯档等的是首页那份。
  /// 判错会让某档在位图就绪前多一帧透明（或反过来过早走实时模糊）。
  Widget _buildLiveBlurFallback(
    BuildContext context,
    BorderRadius radius,
    Color tint, {
    required PreblurredWallpaperSource source,
  }) {
    final preblurPending = switch (source) {
      PreblurredWallpaperSource.home =>
        PreblurredWallpaperScope.isWaitingForBitmap(context),
      PreblurredWallpaperSource.courseCard =>
        PreblurredWallpaperScope.courseCardIsWaitingForBitmap(context),
    };
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
