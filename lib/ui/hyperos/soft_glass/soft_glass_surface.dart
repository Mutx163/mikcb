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

  /// 柔光底栏默认高斯 sigma：92 × 0.25 = radius 23 → sigma ≈ 13.78。
  ///
  /// 仅作无配方时的兜底；实际取值走 [SoftGlassRecipe]（底栏 / 底部面板 / 对话框三套）。
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

  /// 底栏（浮空导航）配方的不透明度倍率 —— 上游 `FloatingNavigation` 的
  /// `tintAlphaMultiplier = 0.90`。面板 / 对话框配方是 `1.0`，见 [SoftGlassRecipe]。
  static const double navigationTintAlphaMultiplier = 0.90;

  /// 亮色底灰度（glassTintLightGray）→ 252。
  static const double tintLightGray = 0.99;

  /// 暗色底灰度（glassTintDarkGray）→ 31。
  static const double tintDarkGray = 0.12;

  /// 底栏有效底色不透明度 = [navigationTintAlpha] × 0.90 ≈ 0.675，
  /// **明暗同值**（此前亮色误用了旧版 V2 的 0.72）。
  static const double tintAlpha =
      navigationTintAlpha * navigationTintAlphaMultiplier;

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

  /// 底色：灰度取自 glassTintLightGray / glassTintDarkGray，明暗各一值；
  /// 不透明度 = [navigationTintAlpha] × [tintAlphaMultiplier]（配方决定后者）。
  static Color tint(
    BuildContext context, {
    required bool blurEnabled,
    SoftGlassPolarity? polarity,
    double tintAlphaMultiplier = 1,
  }) {
    final gray = _dark(context, polarity) ? tintDarkGray : tintLightGray;
    final channel = (gray * 255).round();
    final alpha = blurEnabled
        ? (navigationTintAlpha * tintAlphaMultiplier).clamp(0.0, 1.0)
        : tintAlphaNoBlur;
    return Color.fromARGB(
      255,
      channel,
      channel,
      channel,
    ).withValues(alpha: alpha);
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

/// 柔光玻璃配方 —— 直译上游 `DeadlinerGlassRecipes` 的三套。
///
/// 上游对「浮空导航 / 底部面板 / 对话框」用三套不同配方：底栏只借一点雾
/// （radius 23dp、tint ×0.90），对话框是更厚的一层（radius 92dp、tint ×1.0、
/// 圆角 40dp）。此前我们把底栏那套用到了所有面，弹层因此像一块实心白卡——
/// 「厚玻璃」的观感来自**折射透镜 + 大半径雾面**，而不是底色的透明度：
/// 对话框配方的底色其实比底栏**更实**（0.75 vs 0.675）。
///
/// 上游最终半径 = `baseBlurRadius(92) × radiusMultiplier × 0.25`（软玻璃调校
/// 默认值），下表已折算成 dp 绝对值；sigma 再按 `radius × 0.57735 + 0.5`
/// 换算成 Flutter `BackdropFilter` 吃的参数（见 [blurSigma]）。
class SoftGlassRecipe {
  const SoftGlassRecipe({
    required this.blurRadiusDp,
    this.tintAlphaMultiplier = 1,
    this.cornerRadiusDp,
  });

  /// Compose `RenderEffect.createBlurEffect` 的 radius（dp 绝对值）。
  final double blurRadiusDp;

  /// 底色不透明度倍率 —— 上游 `GlassBlurSpec.tintAlphaMultiplier`。
  final double tintAlphaMultiplier;

  /// 面板自带圆角（dp）。null = 沿用调用方给的形状（底栏是胶囊、面板用各自的
  /// borderRadius），不覆盖。
  final double? cornerRadiusDp;

  /// 折算成 Flutter `BackdropFilter` 的 sigma。
  double get blurSigma =>
      blurRadiusDp * SoftGlassTokens.radiusToSigmaScale +
      SoftGlassTokens.radiusToSigmaBias;

  /// 浮空导航（底栏、浮钮）：92 × 0.25 = radius 23 → σ ≈ 13.78。
  static const SoftGlassRecipe floatingNavigation = SoftGlassRecipe(
    blurRadiusDp:
        SoftGlassTokens.baseBlurRadius *
        SoftGlassTokens.floatingNavigationRadiusMultiplier,
    tintAlphaMultiplier: SoftGlassTokens.navigationTintAlphaMultiplier,
  );

  /// 对话框 / 弹层：92 × 1 = radius 92 → σ ≈ 53.6，圆角 40dp，底色倍率 1.0。
  static const SoftGlassRecipe dialog = SoftGlassRecipe(
    blurRadiusDp: SoftGlassTokens.baseBlurRadius,
    cornerRadiusDp: 40,
  );

  /// 底部面板 / 抽屉：92 × 2 = radius 184 → σ ≈ 106.7，圆角 36dp。
  ///
  /// ⚠️ Flutter 的 `BackdropFilter` 是真高斯，σ ≈ 107 在整屏面板上明显比
  /// σ 54 贵。上游走的是降采样金字塔模糊，付得起；这里先留作可选配方，
  /// 未在设备上确认性能前不要直接挂到大面板上。
  static const SoftGlassRecipe bottomSheet = SoftGlassRecipe(
    blurRadiusDp: SoftGlassTokens.baseBlurRadius * 2,
    cornerRadiusDp: 36,
  );
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
    this.recipe = SoftGlassRecipe.floatingNavigation,
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

  /// 是否允许走折射 shader。默认允许——折射透镜现在是绝对 dp 参数，
  /// 任意尺寸都成立；只有明确不想要的场景才传 false。
  final bool enableRefraction;

  /// 材质配方：决定雾面半径、底色倍率与自带圆角。见 [SoftGlassRecipe]。
  final SoftGlassRecipe recipe;

  /// 形状：显式 [borderRadius] 优先，其次配方自带圆角，最后兜底胶囊。
  BorderRadius get _radius {
    final explicit = borderRadius;
    if (explicit != null) {
      return explicit;
    }
    final recipeRadius = recipe.cornerRadiusDp;
    if (recipeRadius != null) {
      return BorderRadius.all(Radius.circular(recipeRadius));
    }
    return const BorderRadius.all(Radius.circular(999));
  }

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
          tintAlphaMultiplier: recipe.tintAlphaMultiplier,
        );
    final sigma = blurSigma ?? recipe.blurSigma;
    final edgeAlpha = SoftGlassTokens.edgeAlphaOf(isDark) * alpha;
    final resolvedRadius = _radius;

    return LayoutBuilder(
      builder: (context, constraints) {
        Widget? glassLayer;
        if (blurEnabled) {
          glassLayer = _SoftGlassBackdrop(
            blurSigma: sigma,
            enableRefraction: enableRefraction,
            cornerRadius: resolvedRadius.topLeft.x,
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
    required this.cornerRadius,
    required this.child,
  });

  final double blurSigma;
  final bool enableRefraction;

  /// 实际形状的圆角半径（逻辑像素）。胶囊传 999 也行——渲染侧会夹到短边一半。
  final double cornerRadius;
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
      cornerRadius: widget.cornerRadius,
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
    required this.cornerRadius,
    required super.child,
  });

  final double blurSigma;
  final SoftGlassRefractionLens? lens;
  final double devicePixelRatio;
  final Size viewSize;

  /// 实际形状的圆角半径（逻辑像素）。
  final double cornerRadius;

  @override
  _RenderSoftGlassBackdrop createRenderObject(BuildContext context) =>
      _RenderSoftGlassBackdrop(
        blurSigma, // 高斯 sigma
        lens, // 折射透镜，可为 null（回退纯高斯）
        devicePixelRatio, // 设备像素比
        viewSize, // 视图物理尺寸
        cornerRadius, // 圆角半径（逻辑像素）
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
      ..viewSize = viewSize
      ..cornerRadius = cornerRadius;
  }
}

class _RenderSoftGlassBackdrop extends RenderProxyBox {
  _RenderSoftGlassBackdrop(
    this._blurSigma,
    this._lens,
    this._devicePixelRatio,
    this._viewSize,
    this._cornerRadius,
  );

  double _blurSigma;
  SoftGlassRefractionLens? _lens;
  double _devicePixelRatio;
  Size _viewSize;
  double _cornerRadius;

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

  double get cornerRadius => _cornerRadius;
  set cornerRadius(double value) {
    if (_cornerRadius == value) {
      return;
    }
    _cornerRadius = value;
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
            outer: lens.filterFor(
              geometry,
              viewSize,
              devicePixelRatio: _devicePixelRatio,
              cornerRadiusPx: _cornerRadiusPx(),
            ),
            inner: blur,
          )
        : blur;

    _cachedLens = refracted ? lens : null;
    _cachedGeometry = geometry;
    _cachedSigma = blurSigma;
    _cachedFilter = result;
    return result;
  }

  /// 圆角半径（物理像素）。胶囊传 999 也能用——这里夹到短边一半，即胶囊半径；
  /// 面板传自己的 borderRadius。shader 里还会再夹一次。
  double _cornerRadiusPx() {
    final limit = size.isEmpty ? 0.0 : size.shortestSide * 0.5;
    return (_cornerRadius <= 0 || _cornerRadius > limit ? limit : _cornerRadius) *
        _devicePixelRatio;
  }

  /// 控件在整屏 backdrop 快照里的矩形，物理像素。
  ///
  /// 旋转或非等比缩放时返回 null：折射 SDF 是轴对齐的，那种情形几何必然失真，
  /// 退回纯高斯比画一个歪掉的透镜更稳妥。
  ///
  /// 注：折射透镜改用绝对 dp 参数后**不再限制高度**——任意尺寸都挂同一套透镜。
  Rect? _geometryInPhysicalPixels() {
    if (size.isEmpty) {
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
