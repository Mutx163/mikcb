import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../../models/soft_glass_tuning.dart';
import '../frosted/frosted_appearance.dart';
import '../hyperos_glass_backdrop_host.dart';

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

  /// 全局模糊半径基准 = 上游弹层材质 `MiuixGlassMaterials.popupViewGlass` 的
  /// `blurRadius`（60）—— 首页右上角菜单与选择弹层用的就是这一份材质，柔光玻璃
  /// 与它们同参。
  ///
  /// （历史值 92 是 Hyper-PiliPlus 自研链路的口径，随自研折射链路一起退场。）
  static const double baseBlurRadius = 60;

  /// Miuix textureBlur 的半径上限。
  static const double maximumBlurRadius = 256;

  /// Android `RenderEffect.createBlurEffect` 的 radius → Gaussian sigma 换算
  /// （与 BlurMaskFilter 同一套系数）：sigma = radius × 0.57735 + 0.5。
  ///
  /// 上游 radius 是 Android `RenderEffect` 的口径，旧自研链路换算成 Flutter
  /// `BackdropFilter` 的 sigma 时用这套系数；保留供文档 / 兜底对照。
  static const double radiusToSigmaScale = 0.57735;
  static const double radiusToSigmaBias = 0.5;

  /// 柔光玻璃材质基准高斯 sigma：radius 60（上游弹层材质 / 标准档）
  /// → sigma ≈ 35.14。
  ///
  /// 仅作无配方时的兜底；实际取值走 [SoftGlassRecipe]（全 app 唯一配方）
  /// 再乘用户的档位倍率，最终写到上游材质的 `blurRadius`。
  ///
  /// **档位阶梯（同一基线的绝对半径，供改数值时对照）**：
  /// | 档位 | radius (= 60 × 倍率) |
  /// |---|---|
  /// | 清透 clear (×0.6) | 36 |
  /// | 轻盈 light (×0.8) | 48 |
  /// | **标准 standard (×1.0)** | **60**（= 菜单 / 选择弹层同款） |
  /// | 浓雾 dense (×1.6) | 96 |
  /// | 滑杆上限 (×2.7) | 162 |
  ///
  /// 滑杆上限 2.7 是 UI 档位选择（162 仍远低于 [maximumBlurRadius]）。
  static const double defaultBlurSigma =
      baseBlurRadius * radiusToSigmaScale + radiusToSigmaBias;

  /// 后置柔化（上游 `GlassLayeringSpec.postRefractionBlurRadius`）。
  ///
  /// 自研折射链路时代保留的常量：自绘 shader 之后本该再过一道 0.5dp 高斯削掉
  /// 贴边硬边，当时没做。现在玻璃交给上游 OS4 shader（它自己处理边缘），本常量
  /// 已无消费者，只作为历史数值留档。
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

  /// 底色不透明度倍率 —— 上游 `AdvancedMaterialFineTuning`
  /// 的 `glassTintAlphaMultiplier`（默认 0.90）。**底栏 / 对话框 / 底部面板
  /// 三套配方共用同一个值**：上游 `DeadlinerGlassRecipes` 三者的
  /// `GlassBlurSpec.tintAlphaMultiplier` 字面值并不相同（0.90 / 1f / 1f），但
  /// 工厂函数会再乘一次 tuning 值，结果一律 0.90。详见 [SoftGlassRecipe] 类注释。
  static const double navigationTintAlphaMultiplier = 0.90;

  /// 亮色底灰度（glassTintLightGray）→ 252。
  static const double tintLightGray = 0.99;

  /// 暗色底灰度（glassTintDarkGray）→ 31。
  static const double tintDarkGray = 0.12;

  /// 有效底色不透明度 = [navigationTintAlpha] × [navigationTintAlphaMultiplier]
  /// ≈ 0.675，**明暗同值、三套配方同值**（此前亮色误用了旧版 V2 的 0.72）。
  static const double tintAlpha =
      navigationTintAlpha * navigationTintAlphaMultiplier;

  /// 模糊总开关关闭时的底色不透明度。
  ///
  /// 上游 `SoftGlassSurface` 在材质未启用（`advancedMaterial.enabled == false`）
  /// 时写死 0.92；本项目约定「模糊关闭即实底」（见
  /// HyperosBlurredHeader.sheetTintColor），故这里收紧到 0.90，属**有意偏离**：
  /// 既不能透出底下的课表，又要保住玻璃面的层级。
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
  /// 不透明度 = [navigationTintAlpha] × [navigationTintAlphaMultiplier]。
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
/// （radius 23dp），对话框与底部面板是更厚的一层（radius 92dp / 184dp，圆角
/// 40dp / 36dp）。此前我们把底栏那套用到了所有面，弹层因此像一块实心白卡——
/// 「厚玻璃」的观感来自**折射透镜 + 大半径雾面**，而不是底色的透明度。
///
/// ⚠️ **tint 倍率三套配方最终都是 0.90，不要被上游 `GlassBlurSpec` 的字面值骗了**
/// —— 上游 `DeadlinerGlassRecipes` 里 `FloatingNavigation.blur.tintAlphaMultiplier`
/// 是 0.90、`Dialog` / `BottomSheet` 是 1f，但工厂函数会再处理一次：
/// `floatingNavigation()` 用 `tuning.glassTintAlphaMultiplier` **直接覆盖**，
/// `dialog()` / `bottomSheet()` 则 `× tuning.glassTintAlphaMultiplier` ——
/// 默认 0.90，于是三者殊途同归，底色不透明度一律 = `navigationTintAlpha(0.75)
/// × 0.90 = 0.675`。
///
/// 本文件此前把 `Dialog.blur.tintAlphaMultiplier = 1f` 当成了最终倍率，对话框
/// 底色因此偏实（0.75 而非 0.675）。**层级越实，底下的模糊与折射越看不见** ——
/// 这一处偏差本身就是「弹层看着和高斯模糊一个样」的成因之一。
///
/// 现在柔光玻璃交回上游材质：配方半径由 [SoftGlassTokens.baseBlurRadius]（= 上游
/// `popupViewGlass.blurRadius`）给出，再乘用户档位倍率（[SoftGlassTuning]），写成
/// 上游 `MiuixGlassMaterial.blurRadius`。
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

  /// 折算成 Flutter `BackdropFilter` 的 sigma（自研链路时代的对照口径）。
  double get blurSigma => blurSigmaWithMultiplier(1);

  /// 按用户倍率（SoftGlassTuning.blurRadiusMultiplier）缩放配方半径后
  /// 折算 sigma，保持 radius → sigma 换算单点维护。
  double blurSigmaWithMultiplier(double multiplier) =>
      blurRadiusDp * multiplier * SoftGlassTokens.radiusToSigmaScale +
      SoftGlassTokens.radiusToSigmaBias;

  /// 全 app 柔光玻璃**唯一**的配方：底栏 / 浮钮 / 顶栏带 / 弹窗 / 面板 /
  /// 选择弹层全都用它，雾度、底色、圆角来源只有这一处。
  ///
  /// 铁律同液态玻璃：一个材质只有一种观感。历史上这里并存过多套按尺寸分派的
  /// 配方，于是同一个「柔光玻璃」在顶栏和弹层是两种雾度——用户口径「是柔光玻璃
  /// 就全部显示一样」。
  ///
  /// 档位选择：基线就是**首页菜单 / 选择弹层那份上游材质**（`popupViewGlass`，
  /// radius 60），档位的粗细由用户在设置页选
  /// （`SoftGlassTuning.blurRadiusMultiplier`，清透/轻盈/标准/浓雾），
  /// **不再由表面决定**——表面只有这一个配方。
  ///
  /// 若真机要整体改雾度，改 [SoftGlassTokens.baseBlurRadius] 一个数
  /// （档位阶梯会随之整体平移，见 [SoftGlassTokens.defaultBlurSigma] 的对照表）。
  static const SoftGlassRecipe standard = SoftGlassRecipe(
    blurRadiusDp: SoftGlassTokens.baseBlurRadius,
    tintAlphaMultiplier: SoftGlassTokens.navigationTintAlphaMultiplier,
  );
}

/// 柔光亮暗极性。
enum SoftGlassPolarity { light, dark }

/// 柔光玻璃表面 —— **全 app 玻璃统一材质**：直接渲染 flutter_miuix 的 OS4 玻璃
/// （[MiuixGlass]），材质与首页右上角菜单、选择弹层**同一份**
/// （`MiuixGlassMaterials.popupViewGlass` + `MiuixGlassStyles.forTheme` +
/// `MiuixGlassStrokes.forTheme` + 菜单同档的 `shading: false`）。
///
/// 历史：这里曾经是 Hyper-PiliPlus「柔光玻璃」的自研实现 —— 自绘折射 shader +
/// 双影边缘 + 自己录制 backdrop。那条链路已整体删除，本类只保留原来的**入参
/// 契约**，内部换成上游玻璃，于是顶栏带 / 玻璃坞 / 弹窗 / 面板 / 选择弹层 /
/// 标签栏所有接入点一次性换成菜单那套材质，不再各写一套观感。
///
/// 采样源（`MiuixLayerBackdrop`）由屏级宿主提供：屏内玻璃取
/// [HyperosGlassBackdropScope]，modal 路由（sheet / dialog）取
/// [HyperosGlassBackdropRegistry] 栈顶那一屏，并在挂载期间 `acquire` /
/// `release` 请求录帧 —— 一屏之内没有任何玻璃时页面不做快照，零开销。
///
/// [blurEnabled] 为 false（模糊总开关关闭 / 后端不支持）时**不接采样源**：上游在
/// 没有 backdrop 时保留纯色轮廓与可绘制高光，正好就是原来的「实底兜底」观感，
/// 不会出现半透明空壳。
class SoftGlassSurface extends StatefulWidget {
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
    this.enableRefraction = false,
    this.recipe = SoftGlassRecipe.standard,
    this.tuning,
  });

  final Widget child;
  final bool blurEnabled;
  final Color? tint;
  final BorderRadius? borderRadius;
  final double materialAlpha;
  final SoftGlassPolarity? polarity;

  /// 兼容旧入参：旧自研链路用它覆盖高斯 sigma。上游玻璃的雾面由
  /// [SoftGlassRecipe.blurRadiusDp] × 用户档位决定，这里只在显式传入时按同一套
  /// radius→sigma 系数换回 radius 交给材质。
  final double? blurSigma;
  final bool enableShadows;
  final bool enableEdgeHighlight;

  /// true = 上游「仿生折射」档（bionic GlassToken）；false（默认）= OS4 栏 / 菜单的
  /// MaterialToken —— 首页右上角菜单与选择弹层用的就是 false 这一档，所以柔光玻璃
  /// 默认同档。
  final bool enableRefraction;

  /// 材质配方：决定雾面半径、底色倍率与自带圆角。见 [SoftGlassRecipe]。
  final SoftGlassRecipe recipe;

  /// 用户调参（设置页「高级材质 → 柔光玻璃」）。null = 从
  /// [FrostedAppearanceScope] 读全局设置；测试/特殊面可显式覆盖。
  final SoftGlassTuning? tuning;

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
  State<SoftGlassSurface> createState() => _SoftGlassSurfaceState();
}

class _SoftGlassSurfaceState extends State<SoftGlassSurface> {
  HyperosGlassBackdropController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindController();
  }

  @override
  void didUpdateWidget(SoftGlassSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blurEnabled != widget.blurEnabled) {
      _bindController();
    }
  }

  @override
  void dispose() {
    _controller?.release();
    _controller = null;
    super.dispose();
  }

  /// 解析采样源（屏内作用域 → modal 时的栈顶屏），并在挂载期间请求录帧。
  void _bindController() {
    final next = widget.blurEnabled
        ? HyperosGlassBackdropRegistry.resolve(context)
        : null;
    if (identical(next, _controller)) {
      return;
    }
    _controller?.release();
    _controller = next;
    next?.acquire();
  }

  @override
  Widget build(BuildContext context) {
    final tuning =
        widget.tuning ?? FrostedAppearanceScope.of(context).softGlassTuning;
    final isDark = SoftGlassTokens._dark(context, widget.polarity);
    return MiuixGlass(
      backdrop: widget.blurEnabled ? _controller?.backdrop : null,
      style: MiuixGlassStyles.forTheme(isDark),
      material: _tunedMaterial(
        MiuixGlassMaterials.popupViewGlass(isDark),
        tuning,
      ),
      shape: MiuixGlassShape(borderRadius: widget._radius),
      alpha: widget.materialAlpha.clamp(0.0, 1.0),
      fill: widget.tint,
      // 菜单 / 选择弹层同档：栏与菜单 MaterialToken（shading: false）。
      shading: widget.enableRefraction,
      stroke: widget.enableEdgeHighlight
          ? _scaledStroke(
              MiuixGlassStrokes.forTheme(isDark),
              tuning.edgeHighlight,
            )
          : null,
      shadow: widget.enableShadows ? MiuixGlassShadows.floating : null,
      child: widget.child,
    );
  }

  /// 上游材质包上用户档位：雾面半径 = 配方半径 × 档位倍率；底色浓度按
  /// `tintAlphaMultiplier` 缩放颜色层不透明度。
  MiuixGlassMaterial _tunedMaterial(
    MiuixGlassMaterial base,
    SoftGlassTuning tuning,
  ) {
    final radius =
        (widget.blurSigma != null
                ? (widget.blurSigma! - SoftGlassTokens.radiusToSigmaBias) /
                      SoftGlassTokens.radiusToSigmaScale
                : widget.recipe.blurRadiusDp * tuning.blurRadiusMultiplier)
            .clamp(0.0, SoftGlassTokens.maximumBlurRadius);
    final tintScale = tuning.tintAlphaMultiplier.clamp(0.0, 2.0);
    MiuixGlassColorLayer scale(MiuixGlassColorLayer layer) =>
        MiuixGlassColorLayer(
          layer.color.withValues(
            alpha: (layer.color.a * tintScale).clamp(0.0, 1.0),
          ),
          layer.mode,
        );
    return MiuixGlassMaterial(
      blurRadius: radius,
      first: scale(base.first),
      second: base.second == null ? null : scale(base.second!),
      third: base.third == null ? null : scale(base.third!),
    );
  }

  /// 边缘高光强度（0..1）按比例作用到上游描边的三处高光上。
  MiuixGlassStroke _scaledStroke(MiuixGlassStroke base, double strength) {
    final scale = strength.clamp(0.0, 1.0);
    Color scaleColor(Color color) =>
        color.withValues(alpha: (color.a * scale).clamp(0.0, 1.0));
    MiuixGlassStrokeLight scaleLight(MiuixGlassStrokeLight light) =>
        MiuixGlassStrokeLight(
          light.x,
          light.y,
          light.z,
          scaleColor(light.color),
        );
    return MiuixGlassStroke(
      width: base.width,
      bevel: base.bevel,
      color: scaleColor(base.color),
      primary: scaleLight(base.primary),
      secondary: scaleLight(base.secondary),
    );
  }
}
