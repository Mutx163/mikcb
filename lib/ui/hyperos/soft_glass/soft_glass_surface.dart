import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show BackdropFilterLayer, PaintingContext, RenderProxyBox;

import 'soft_glass_refraction.dart';

/// 柔光玻璃 token —— 数值直译 Hyper-PiliPlus（Deadliner）的
/// `AdvancedMaterialFineTuning` / `GlassBlurSpec` / `GlassEdgeOpticsSpec` /
/// `GlassLayeringSpec` / `SoftGlassShadowTokens` / `MiuixFloatingTabBarDefaults`。
abstract final class SoftGlassTokens {
  // ---------------------------------------------------------------------
  // 底栏几何（MiuixFloatingTabBarDefaults）
  // ---------------------------------------------------------------------
  static const double barHeight = 54;
  static const double horizontalContentPadding = 7;
  static const double verticalContentPadding = 3;
  static const double indicatorHorizontalOverflow = 3;
  static const double maximumWidth = 380;
  static const double maximumItemWidth = 80;
  static const double tabIconSize = 26;
  static const double detachedIconSize = 28;
  static const double roundButtonSize = 56;

  // ---------------------------------------------------------------------
  // 按压与动效（FloatingTabMotionDefaults）
  // ---------------------------------------------------------------------
  static const double pressedScale = 52 / 56;
  static const double selectedIconPressedScale = 0.90;
  static const double maximumStretch = 0.18;
  static const double fullStretchTabsPerSecond = 8;
  static const double maximumPanelOffsetDp = 4;

  // ---------------------------------------------------------------------
  // 模糊（AdvancedMaterialTuning.DefaultBlurRadius + GlassBlurSpec）
  // ---------------------------------------------------------------------

  /// 全局模糊半径基准（AdvancedMaterialTuning.DefaultBlurRadius）。
  static const double baseBlurRadius = 92;

  /// 浮空导航的 radiusMultiplier。
  static const double floatingNavigationRadiusMultiplier = 0.25;

  /// Miuix textureBlur 的半径上限。
  static const double maximumBlurRadius = 256;

  /// Android `RenderEffect.createBlurEffect` 的 radius → Gaussian sigma 换算
  /// （与 BlurMaskFilter 同一套系数）：sigma = radius × 0.57735 + 0.5。
  ///
  /// 必须做这层换算：原版的 92 是 *radius*，Flutter `BackdropFilter` 吃的是
  /// *sigma*，直接把 23 当 sigma 用会明显糊过头。
  static const double radiusToSigmaScale = 0.57735;
  static const double radiusToSigmaBias = 0.5;

  /// Flutter 的 `BackdropFilter` 是真高斯，成本随 sigma 上升；原版走降采样
  /// 金字塔模糊，面板能开到 radius 720。这里封一个现实中付得起的上限。
  static const double maximumBlurSigma = 48;

  /// 柔光底栏默认高斯 sigma：92 × 0.25 = radius 23 → sigma ≈ 13.78。
  static const double defaultBlurSigma =
      baseBlurRadius * floatingNavigationRadiusMultiplier * radiusToSigmaScale +
      radiusToSigmaBias;

  /// 后置柔化（GlassLayeringSpec.postRefractionBlurRadius）。
  ///
  /// 原版在折射之后再过一道 0.5dp 高斯。0.5dp 折算 sigma ≈ 1.4px，肉眼不可辨，
  /// 为省掉一个额外的 BackdropFilter 通道未予实现。
  static const double postRefractionBlurDp = 0.5;

  // ---------------------------------------------------------------------
  // 边缘光学（GlassEdgeOpticsSpec，**光学档**而非回退档）
  // ---------------------------------------------------------------------

  /// 镜面边缘高光强度（有 shader 时的 opticalGlassEdge）。
  static const double edgeHighlightAlpha = 0.95;

  /// 暗色模式下高光的折减系数（原版 darkHighlightMultiplier）。
  static const double edgeDarkHighlightMultiplier = 0.20;

  /// 边缘高光灰度。
  static const double edgeHighlightGray = 1;

  /// 描边宽度（opticalGlassEdge 固定 0.5dp）。
  static const double edgeWidth = 0.5;

  /// 原版 `Brush.verticalGradient` 三档：alpha / 0.62α / 0.30α，自上而下衰减。
  static const List<double> edgeGradientStops = <double>[0, 0.5, 1];
  static const List<double> edgeGradientAlphas = <double>[1, 0.62, 0.30];

  // ---------------------------------------------------------------------
  // 底色（AdvancedMaterialFineTuning 当前默认档）
  // ---------------------------------------------------------------------

  static const double navigationTintAlpha = 0.75;
  static const double tintAlphaMultiplier = 0.90;

  /// 亮色底灰度（glassTintLightGray）→ 252。
  static const double tintLightGray = 0.99;

  /// 暗色底灰度（glassTintDarkGray）→ 31。
  static const double tintDarkGray = 0.12;

  /// 有效底色不透明度 = navigationTintAlpha × tintAlphaMultiplier ≈ 0.675，
  /// **明暗同值**（此前亮色误用了旧版 V2 的 0.72）。
  static const double tintAlpha = navigationTintAlpha * tintAlphaMultiplier;

  /// 模糊总开关关闭时的底色不透明度。
  ///
  /// 原版权威值是 0.92 × 0.90 = 0.828，但那会让「模糊关闭」的弹窗透出底下的
  /// 课表；本项目约定「模糊关闭即实底」（见 HyperosBlurredHeader.sheetTintColor），
  /// 故此处保留高不透明度，属**有意偏离**。
  static const double tintAlphaNoBlur = 0.90;

  // ---------------------------------------------------------------------
  // 阴影（SoftGlassShadowTokens）
  // ---------------------------------------------------------------------

  static bool _dark(BuildContext context, SoftGlassPolarity? polarity) =>
      switch (polarity) {
        SoftGlassPolarity.dark => true,
        SoftGlassPolarity.light => false,
        null => Theme.of(context).brightness == Brightness.dark,
      };

  /// 底色：灰度取自 glassTintLightGray / glassTintDarkGray，明暗各一值。
  static Color tint(
    BuildContext context, {
    required bool blurEnabled,
    SoftGlassPolarity? polarity,
  }) {
    final gray = _dark(context, polarity) ? tintDarkGray : tintLightGray;
    final channel = (gray * 255).round();
    return Color.fromARGB(255, channel, channel, channel).withValues(
      alpha: blurEnabled ? tintAlpha : tintAlphaNoBlur,
    );
  }

  /// 指示器填充：暗色白 13% / 亮色黑 7.5%。
  static Color indicatorFill(
    BuildContext context, {
    SoftGlassPolarity? polarity,
  }) => _dark(context, polarity)
      ? Colors.white.withValues(alpha: 0.13)
      : Colors.black.withValues(alpha: 0.075);

  static List<BoxShadow> shadows(
    BuildContext context, {
    SoftGlassPolarity? polarity,
  }) {
    if (_dark(context, polarity)) {
      return const [
        BoxShadow(color: Color(0x0D000000), blurRadius: 7, spreadRadius: -0.75),
        BoxShadow(color: Color(0x03000000), blurRadius: 3, spreadRadius: -0.75),
      ];
    }
    return const [
      BoxShadow(color: Color(0x11000000), blurRadius: 8, spreadRadius: -0.75),
      BoxShadow(color: Color(0x04000000), blurRadius: 3.5, spreadRadius: -0.75),
    ];
  }

  /// 边缘高光强度：亮 0.95 / 暗 0.19（0.95 × 0.20）。
  static double edgeAlphaOf(bool isDark) =>
      edgeHighlightAlpha * (isDark ? edgeDarkHighlightMultiplier : 1);

  static double edgeAlpha(
    BuildContext context, {
    SoftGlassPolarity? polarity,
  }) => edgeAlphaOf(_dark(context, polarity));
}

/// 柔光亮暗极性。
enum SoftGlassPolarity { light, dark }

/// 柔光玻璃表面。
///
/// 渲染分两条路径，观感以「折射路径」为准：
///
/// * **折射路径**（Impeller + shader 装载成功 + 控件高度 ≤ 72dp）
///   `compose(outer: 折射 shader, inner: 高斯)` 压在一个 backdrod 层上，
///   再叠底色与边缘高光。与原版 `glassOpticalBackdrop` 同构：先高斯，再折射，
///   再叠底与描边。
///
///   折射 shader 需要知道**控件在屏幕上的物理矩形**（引擎只喂给它整屏
///   backdrop 快照的尺寸，不喂位置），所以这条路径由 [_SoftGlassBackdrop]
///   在 paint 时用 `getTransformTo(null)` 实测，详见该类的注释。
/// * **回退路径**（其余后端 / 大面板 / 模糊总开关关闭）
///   纯高斯 + 底色 + 边缘高光。描边仍用**光学档**的高光强度，保证即便没有
///   折射 shader，玻璃面也能靠镜面边缘立住——这一步与背景内容无关，是
///   「看起来像玻璃」的最低成本来源。
class SoftGlassSurface extends StatelessWidget {
  const SoftGlassSurface({
    super.key,
    required this.child,
    this.blurEnabled = true,
    this.tint,
    this.borderRadius,
    this.materialAlpha = 1.0,
    this.polarity,
    this.blurSigma,
    this.enableShadows = true,
    this.enableEdgeHighlight = true,
    this.enableRefraction = true,
  });

  final Widget child;
  final bool blurEnabled;
  final Color? tint;
  final BorderRadius? borderRadius;
  final double materialAlpha;
  final SoftGlassPolarity? polarity;
  final double? blurSigma;
  final bool enableShadows;
  final bool enableEdgeHighlight;

  /// 是否允许走折射 shader。大面板请传 false。
  final bool enableRefraction;

  BorderRadius get _radius =>
      borderRadius ?? const BorderRadius.all(Radius.circular(999));

  @override
  Widget build(BuildContext context) {
    final alpha = materialAlpha.clamp(0.0, 1.0);
    final isDark = SoftGlassTokens._dark(context, polarity);
    final fill =
        tint ??
        SoftGlassTokens.tint(
          context,
          blurEnabled: blurEnabled,
          polarity: polarity,
        );
    final sigma = blurSigma ?? SoftGlassTokens.defaultBlurSigma;
    final edgeAlpha = SoftGlassTokens.edgeAlphaOf(isDark) * alpha;
    final resolvedRadius = _radius;

    return LayoutBuilder(
      builder: (context, constraints) {
        Widget? glassLayer;
        if (blurEnabled) {
          glassLayer = _SoftGlassBackdrop(
            blurSigma: sigma,
            enableRefraction: enableRefraction,
            child: const SizedBox.expand(),
          );
        }

        final layers = <Widget>[
          if (glassLayer != null) Positioned.fill(child: glassLayer),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fill.withValues(alpha: fill.a * alpha),
              ),
            ),
          ),
          if (enableEdgeHighlight && edgeAlpha > 0.001)
            Positioned.fill(
              child: CustomPaint(
                painter: _SoftGlassEdgePainter(
                  radius: resolvedRadius,
                  alpha: edgeAlpha,
                  width: SoftGlassTokens.edgeWidth,
                ),
              ),
            ),
        ];

        final glass = ClipRRect(
          borderRadius: resolvedRadius,
          child: Stack(
            // 尺寸语义必须与改动前完全等价：
            //  - 外层给的是**紧约束**（如底栏 SizedBox 54、圆钮 SizedBox 56）
            //    → expand，让内容照旧被撑满；
            //  - 外层给的是**松约束**（弹窗/面板按内容定高）
            //    → loose，Stack 尺寸跟随内容，绝不能撑到约束上限，否则
            //      小内容弹窗会变成一整屏。
            fit: constraints.isTight ? StackFit.expand : StackFit.loose,
            children: [...layers, child],
          ),
        );

        if (!enableShadows || alpha <= 0.01) {
          return glass;
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: resolvedRadius,
            boxShadow: [
              for (final s in SoftGlassTokens.shadows(context, polarity: polarity))
                BoxShadow(
                  color: s.color.withValues(alpha: s.color.a * alpha),
                  blurRadius: s.blurRadius,
                  spreadRadius: s.spreadRadius,
                  offset: s.offset,
                ),
            ],
          ),
          child: glass,
        );
      },
    );
  }
}

/// 光学档边缘高光：沿胶囊描边一圈 0.5dp 的高光线，自上而下按
/// `1 / 0.62 / 0.30` 三档衰减（原版 `Brush.verticalGradient`）。
///
/// 原版用 `Modifier.border(width, brush, shape)` 画在底色之上、内容之下，
/// Flutter 侧没有等价的「带渐变的描边」，因此用画笔手绘，层级保持一致。
class _SoftGlassEdgePainter extends CustomPainter {
  const _SoftGlassEdgePainter({
    required this.radius,
    required this.alpha,
    required this.width,
  });

  final BorderRadius radius;
  final double alpha;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    if (alpha <= 0.001 || width <= 0 || size.isEmpty) {
      return;
    }
    // 半线宽内缩，让整条 0.5dp 描边都落在控件内部。
    final inset = width / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - width,
      size.height - width,
    );
    if (rect.width <= 0 || rect.height <= 0) {
      return;
    }
    final corner = math.min(
      radius.topLeft.x,
      math.min(rect.width, rect.height) / 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..isAntiAlias = true
      ..shader = ui.Gradient.linear(
        Offset(rect.center.dx, rect.top),
        Offset(rect.center.dx, rect.bottom),
        [
          for (final factor in SoftGlassTokens.edgeGradientAlphas)
            Colors.white.withValues(alpha: alpha * factor),
        ],
        SoftGlassTokens.edgeGradientStops,
      );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(corner)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_SoftGlassEdgePainter oldDelegate) =>
      oldDelegate.alpha != alpha ||
      oldDelegate.width != width ||
      oldDelegate.radius != radius;
}

/// 玻璃背衬层：高斯 + 折射 shader。
///
/// 存在的唯一理由：`ImageFilter.shader` 拿到的 `FlutterFragCoord()` 落在
/// **backdrop 快照（整屏）的纹理空间**里，引擎只把自己的纹理尺寸写进 uniform 0，
/// **不会**告诉 shader 控件在其中的位置。位置只能由 Dart 侧在 paint 时实测
/// （[RenderBox.getTransformTo]）——这正是本仓库已在用的 `liquid_glass_widgets`
/// 的做法，也是它在同一台设备上能正常渲染的原因。
///
/// 不能沿用普通 `BackdropFilter`：它的 `filter` 是构建期给的，里面没有几何，
/// 而几何每帧都可能变（底栏拉伸、弹窗入场）。由渲染对象在 paint 时现算，滤镜与
/// 当前帧严格同步，不会出现「用上一帧位置」的错位。
///
/// shader 是异步装载的：[SoftGlassRefraction.warmUp] 完成后补一次重建。首个
/// 帧只有高斯，这是可接受的——比第一帧画一个几何未知的透镜要好。
class _SoftGlassBackdrop extends StatefulWidget {
  const _SoftGlassBackdrop({
    required this.blurSigma,
    required this.enableRefraction,
    required this.child,
  });

  final double blurSigma;
  final bool enableRefraction;
  final Widget child;

  @override
  State<_SoftGlassBackdrop> createState() => _SoftGlassBackdropState();
}

class _SoftGlassBackdropState extends State<_SoftGlassBackdrop> {
  SoftGlassRefractionLens? _lens;

  @override
  void initState() {
    super.initState();
    _syncLens();
  }

  @override
  void didUpdateWidget(_SoftGlassBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enableRefraction != widget.enableRefraction) {
      _syncLens();
    }
  }

  @override
  void dispose() {
    _lens?.dispose();
    _lens = null;
    super.dispose();
  }

  void _syncLens() {
    if (!widget.enableRefraction) {
      _lens?.dispose();
      _lens = null;
      return;
    }
    if (_lens != null) {
      return;
    }
    final lens = SoftGlassRefraction.createLens();
    if (lens != null) {
      _lens = lens;
      return;
    }
    SoftGlassRefraction.warmUp().then((_) {
      if (!mounted || _lens != null) {
        return;
      }
      final loaded = SoftGlassRefraction.createLens();
      if (loaded != null) {
        setState(() => _lens = loaded);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final view = View.of(context);
    return _SoftGlassBackdropHost(
      blurSigma: widget.blurSigma,
      lens: _lens,
      devicePixelRatio: view.devicePixelRatio,
      viewSize: view.physicalSize,
      child: widget.child,
    );
  }
}

class _SoftGlassBackdropHost extends SingleChildRenderObjectWidget {
  const _SoftGlassBackdropHost({
    required this.blurSigma,
    required this.lens,
    required this.devicePixelRatio,
    required this.viewSize,
    required super.child,
  });

  final double blurSigma;
  final SoftGlassRefractionLens? lens;
  final double devicePixelRatio;
  final Size viewSize;

  @override
  _RenderSoftGlassBackdrop createRenderObject(BuildContext context) =>
      _RenderSoftGlassBackdrop(
        blurSigma, // 高斯 sigma
        lens, // 折射透镜，可为 null（回退纯高斯）
        devicePixelRatio, // 设备像素比
        viewSize, // 视图物理尺寸
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSoftGlassBackdrop renderObject,
  ) {
    renderObject
      ..blurSigma = blurSigma
      ..lens = lens
      ..devicePixelRatio = devicePixelRatio
      ..viewSize = viewSize;
  }
}

class _RenderSoftGlassBackdrop extends RenderProxyBox {
  _RenderSoftGlassBackdrop(
    this._blurSigma,
    this._lens,
    this._devicePixelRatio,
    this._viewSize,
  );

  double _blurSigma;
  SoftGlassRefractionLens? _lens;
  double _devicePixelRatio;
  Size _viewSize;

  ui.ImageFilter? _cachedFilter;
  SoftGlassRefractionLens? _cachedLens;
  Rect? _cachedGeometry;
  double? _cachedSigma;

  @override
  BackdropFilterLayer? get layer => super.layer as BackdropFilterLayer?;

  @override
  bool get alwaysNeedsCompositing => child != null;

  double get blurSigma => _blurSigma;
  set blurSigma(double value) {
    if (_blurSigma == value) {
      return;
    }
    _blurSigma = value;
    markNeedsPaint();
  }

  SoftGlassRefractionLens? get lens => _lens;
  set lens(SoftGlassRefractionLens? value) {
    if (identical(_lens, value)) {
      return;
    }
    _lens = value;
    // 旧滤镜可能引用已释放的 shader，缓存必须一并失效。
    _cachedFilter = null;
    _cachedLens = null;
    markNeedsPaint();
  }

  double get devicePixelRatio => _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (_devicePixelRatio == value) {
      return;
    }
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  Size get viewSize => _viewSize;
  set viewSize(Size value) {
    if (_viewSize == value) {
      return;
    }
    _viewSize = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      layer = null;
      return;
    }
    assert(needsCompositing);
    layer ??= BackdropFilterLayer();
    layer!.filter = _resolveFilter();
    layer!.blendMode = BlendMode.srcOver;
    context.pushLayer(layer!, super.paint, offset);
  }

  /// 出滤镜。几何没变就复用——`ImageFilter.shader` 每次创建都会重新抓一份
  /// uniform，逐帧新建纯属浪费。
  ui.ImageFilter _resolveFilter() {
    final lens = _lens;
    final Rect? geometry = lens == null ? null : _geometryInPhysicalPixels();
    final bool refracted = lens != null && geometry != null;
    if (_cachedFilter != null &&
        identical(_cachedLens, refracted ? lens : null) &&
        _cachedGeometry == geometry &&
        _cachedSigma == blurSigma) {
      return _cachedFilter!;
    }

    final blur = ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma);
    // compose 语义：先 inner（高斯）后 outer（折射），与原版
    // 「colorControls → BlurEffect → runtimeShader(折射)」同序，且只占一个
    // backdrop 通道。引擎侧对此有专门的单测（ComposeBackdropRuntimeOuterBlurInner）。
    final result = refracted
        ? ui.ImageFilter.compose(
            outer: lens.filterFor(geometry, viewSize),
            inner: blur,
          )
        : blur;

    _cachedLens = refracted ? lens : null;
    _cachedGeometry = geometry;
    _cachedSigma = blurSigma;
    _cachedFilter = result;
    return result;
  }

  /// 控件在整屏 backdrop 快照里的矩形，物理像素。
  ///
  /// 旋转或非等比缩放时返回 null：折射 SDF 是轴对齐的，那种情形几何必然失真，
  /// 退回纯高斯比画一个歪掉的透镜更稳妥。
  Rect? _geometryInPhysicalPixels() {
    if (size.isEmpty || size.height > SoftGlassRefraction.maxSurfaceHeight) {
      return null;
    }
    final transform = getTransformTo(null);
    // 只看左上 2×2：m01/m10 非零即有旋转或错切，对角线不等即非等比缩放。
    if (transform.entry(0, 1).abs() > 0.001 ||
        transform.entry(1, 0).abs() > 0.001) {
      return null;
    }
    final double scaleX = transform.entry(0, 0);
    final double scaleY = transform.entry(1, 1);
    if (scaleX <= 0 || scaleY <= 0 || (scaleX - scaleY).abs() > 0.02) {
      return null;
    }
    // 轴对齐时平移量即左上角（entry(0,3) / entry(1,3)）。
    return Rect.fromLTWH(
      transform.entry(0, 3) * _devicePixelRatio,
      transform.entry(1, 3) * _devicePixelRatio,
      size.width * scaleX * _devicePixelRatio,
      size.height * scaleY * _devicePixelRatio,
    );
  }
}
