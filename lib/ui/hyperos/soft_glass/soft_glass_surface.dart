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

  /// Miuix 材质的半径上限（上游 `MiuixGlassMaterial.blurRadius` 的实际天花板
  /// 由离屏目标尺寸决定，这里只做兜底 clamp）。
  static const double maximumBlurRadius = 256;

  /// **档位阶梯（同一基线的绝对半径，供改数值时对照）**：
  /// | 档位 | radius (= [baseBlurRadius] × 倍率) |
  /// |---|---|
  /// | 清透 clear (×0.6) | 36 |
  /// | 轻盈 light (×0.8) | 48 |
  /// | **标准 standard (×1.0)** | **60**（= 菜单 / 选择弹层同款） |
  /// | 浓雾 dense (×1.6) | 96 |
  /// | 滑杆上限 (×2.7) | 162 |
  ///
  /// 倍率来自用户档位（[SoftGlassTuning.blurRadiusMultiplier]），不是在
  /// 这里写死的。滑杆上限 2.7 对应 162，仍远低于 [maximumBlurRadius]。

  // ---------------------------------------------------------------------
  // 边缘光学
  // ---------------------------------------------------------------------
  //
  // 自绘的双影描边（0.5dp 描边 + 上/中/下三档垂直渐变高光 + 暗色折减）已随
  // 自研链路删除。现在边缘由上游 `MiuixGlassStrokes.forTheme(isDark)` 提供，
  // 用户档位（[SoftGlassTuning.edgeHighlight]）经 [scaleSoftGlassStroke]
  // 按比例缩放到它的三处高光（color / primary / secondary）。
  //
  // 注意：倍率 1.0 = 上游原样 = 首页菜单 / 选择弹层同款，不要再引入
  // "额外折减"的默认值——那会让标准档悄悄偏离菜单（见
  // `SoftGlassTuning.defaultEdgeHighlight` 的注释）。

  // ---------------------------------------------------------------------
  // 兜底底色（没有 backdrop 时画的那层实底）
  // ---------------------------------------------------------------------
  //
  // ⚠️ 有 backdrop 时**这些数值一个都不参与渲染**：那时玻璃的底色由上游
  // `popupViewGlass` 的三层颜色层 + blend shader 决定（见
  // `softGlassMaterialFor`），`fill` 只在 `MiuixGlass` 的"无背景兜底"分支
  // （`canvas.drawPath(shapePath, fill)`）被读。
  //
  // 所以这一段服务于两件事，别拿它去解释玻璃的观感：
  // 1. **模糊关闭 / 系统降级时的实底**（`SoftGlassSurface.fill`）；
  // 2. **静态替身的等效底色**（转场期间用，见
  //    `HomePageChromeGlassFill.standInWashColor`）。

  /// 亮/暗底色的不透明度基准（0.75）。
  static const double navigationTintAlpha = 0.75;

  /// 底色基准的配方倍率（0.90）。
  ///
  /// 两个常量相乘 ≈ 0.675，是"亮色 252@67.5% / 暗色 31@67.5%"这个对外口径的
  /// 来源。之所以拆成两个而不是一个 0.675，是为了保留上游
  /// `AdvancedMaterialFineTuning.glassTintAlphaMultiplier` 的数值可追溯性。
  static const double navigationTintAlphaMultiplier = 0.90;

  /// 亮色底灰度（glassTintLightGray）→ 252。
  static const double tintLightGray = 0.99;

  /// 暗色底灰度（glassTintDarkGray）→ 31。
  static const double tintDarkGray = 0.12;

  /// 模糊总开关关闭时的底色不透明度。
  ///
  /// 上游 `SoftGlassSurface` 在材质未启用（`advancedMaterial.enabled == false`）
  /// 时写死 0.92；本项目约定「模糊关闭即实底」（见
  /// HyperosBlurredHeader.sheetTintColor），故这里收紧到 0.90，属**有意偏离**：
  /// 既不能透出底下的课表，又要保住玻璃面的层级。
  static const double tintAlphaNoBlur = 0.90;

  // ---------------------------------------------------------------------
  // 极性
  // ---------------------------------------------------------------------

  static bool _dark(BuildContext context, SoftGlassPolarity? polarity) =>
      switch (polarity) {
        SoftGlassPolarity.dark => true,
        SoftGlassPolarity.light => false,
        null => Theme.of(context).brightness == Brightness.dark,
      };

  /// 兜底底色（灰度取自 [tintLightGray] / [tintDarkGray]）。
  ///
  /// - [blurEnabled] 为 true 时给**静态替身**用：不透明度 =
  ///   [navigationTintAlpha] × [navigationTintAlphaMultiplier] ×
  ///   [tintAlphaMultiplier]（≈ 0.675 × 用户倍率）。
  /// - 为 false（模糊关闭 / 系统降级）时是**实底**：[tintAlphaNoBlur]。
  ///
  /// 真实玻璃（有 backdrop）不走这里，见类头的说明。
  static Color tint(
    BuildContext context, {
    required bool blurEnabled,
    SoftGlassPolarity? polarity,
    double tintAlphaMultiplier = 1,
  }) {
    final gray = _dark(context, polarity) ? tintDarkGray : tintLightGray;
    final channel = (gray * 255).round();
    final alpha = blurEnabled
        ? (navigationTintAlpha *
                  navigationTintAlphaMultiplier *
                  tintAlphaMultiplier)
              .clamp(0.0, 1.0)
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
}

/// 柔光玻璃配方 —— 全 app 只有一个（[standard]）。
///
/// 现在柔光玻璃渲染的是上游 `MiuixGlass`，配方半径由
/// [SoftGlassTokens.baseBlurRadius]（= 上游 `popupViewGlass.blurRadius`，60）
/// 给出，再乘用户档位倍率（[SoftGlassTuning.blurRadiusMultiplier]），最终写成
/// 上游 `MiuixGlassMaterial.blurRadius`。
///
/// 历史：这里曾经并存过按表面分派的多套配方（照搬 Hyper-PiliPlus 的
/// 「浮空导航 23dp / 对话框 92dp / 底部面板 184dp」），于是同一个「柔光玻璃」
/// 在顶栏和弹层是两种雾度。用户口径是「是柔光玻璃就全部显示一样」，所以现在
/// 只保留一个半径值；**形状**（圆角 / 胶囊）由调用方的 `borderRadius` 决定，
/// 不放在配方里——配方只管雾度这一件事。
class SoftGlassRecipe {
  const SoftGlassRecipe({required this.blurRadiusDp});

  /// 材质基准半径（dp），会被用户档位倍率缩放。
  final double blurRadiusDp;

  /// 全 app 柔光玻璃**唯一**的配方：底栏 / 浮钮 / 顶栏带 / 弹窗 / 面板 /
  /// 选择弹层全都用它，雾度来源只有这一处。
  ///
  /// 若真机要整体改雾度，改 [SoftGlassTokens.baseBlurRadius] 一个数
  /// （档位阶梯会随之整体平移，见该常量的对照表）。
  static const SoftGlassRecipe standard = SoftGlassRecipe(
    blurRadiusDp: SoftGlassTokens.baseBlurRadius,
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
/// ## 采样源怎么来的
///
/// 每个表面自带一个 [HyperosZoneBackdrop]，并通过 [HyperosGlassBackdropReporter]
/// 把自己的渲染对象登记给屏级控制器（[HyperosGlassBackdropController]）。控制器
/// 按矩形把玻璃归并成最多几块 zone，捕获节点**只为每块录它那条窄带**（并集 +
/// `sampleMargin`），而不是整层 —— 整屏快照在 2.75x 上约 100MB/帧，是之前
/// "静止也吃满一个核"的主因。一屏之内没有任何玻璃时完全不录帧。
///
/// ## ⚠️ 已知偏差：捕获子树包含玻璃自身
///
/// 上游要求「`MiuixGlass` 必须放在 backdrop 捕获子树之外，防止反馈采样」
/// （`miuix_glass.dart` 类注释），也就是捕获节点应该只包住**背景内容**、玻璃与它
/// **并列**。本项目的现实是：`HyperosGlassBackdropHost` 把捕获节点包在**整页**
/// 外面（`hyperos_page.dart` / `timetable_screen.dart`），而页内玻璃就在那棵子树
/// 里 —— 于是玻璃采到的那条窄带里**含有它自己上一帧的合成结果**。
///
/// 影响：滚动 / 转场时玻璃边缘会有拖影与自我叠加（弹层因为画在 Overlay 上、
/// 天然在捕获之外，不受影响）。`f9ba002b` 的"跳过被自己通知带出来的那一帧"只
/// 截断了自激重绘循环，**没有、也无法**把玻璃从快照里去掉。
///
/// 修它需要页面分层（背景层被捕获、玻璃层在其外）或把页内玻璃也画到 Overlay，
/// 属架构级改动，尚未做。**在此之前，不要以为"玻璃已经和菜单一致"就等于
/// "采样也是对的"** —— 这两件事是分开的。
///
/// ## blurEnabled == false 时
///
/// 不接采样源（`backdrop: null`），上游走"保留纯色轮廓 + 可绘制高光"那条分支，
/// 此时用 [SoftGlassTokens.tint] 算出的兜底实底（[fill]）上色 —— 即原来的
/// 「模糊关闭即实底」观感，不会出现半透明空壳。
class SoftGlassSurface extends StatefulWidget {
  const SoftGlassSurface({
    super.key,
    required this.child,
    this.blurEnabled = true,
    this.borderRadius,
    this.materialAlpha = 1.0,
    this.polarity,
    this.enableShadows = true,
    this.enableEdgeHighlight = true,
    this.recipe = SoftGlassRecipe.standard,
    this.tuning,
  });

  final Widget child;
  final bool blurEnabled;
  final BorderRadius? borderRadius;

  /// 整体不透明度（上游 `MiuixGlass.alpha`）：会同时作用到混合结果、
  /// 描边、阴影与遮罩。**目前没有页面用它**（全部走默认 1.0），
  /// 弹层也没接这个入参（弹层的柔光面走 [SoftGlassSurface]，见
  /// `os4_glass_popup_surface.dart`）—— 若将来要用，记得两边一起加，
  /// 否则弹层与页内表面口径会分叉。
  final double materialAlpha;
  final SoftGlassPolarity? polarity;
  final bool enableShadows;
  final bool enableEdgeHighlight;

  /// 材质配方。全 app 只有一个（[SoftGlassRecipe.standard]）；显式传入只用于
  /// 测试或将来真要按表面分派雾度时。
  final SoftGlassRecipe recipe;

  /// 用户调参（设置页「高级材质 → 柔光玻璃」）。null = 从
  /// [FrostedAppearanceScope] 读全局设置；测试/特殊面可显式覆盖。
  final SoftGlassTuning? tuning;

  /// 形状：显式 [borderRadius] 优先，否则兜底胶囊。
  ///
  /// 999 会被上游 `MiuixGlassShape` 按短边一半 clamp，所以极窄或极扁的表面
  /// 也拿得到正确胶囊，不需要在这里算。
  BorderRadius get _radius =>
      borderRadius ?? const BorderRadius.all(Radius.circular(999));

  @override
  State<SoftGlassSurface> createState() => _SoftGlassSurfaceState();
}

class _SoftGlassSurfaceState extends State<SoftGlassSurface> {
  HyperosGlassBackdropController? _controller;

  /// 本表面自己的采样源：内容由屏级控制器按"这块玻璃背后那条窄带"写入。
  final HyperosZoneBackdrop _backdrop = HyperosZoneBackdrop();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindController();
  }

  @override
  void didUpdateWidget(SoftGlassSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 每次父级重建都重新解析一次采样源，而不是只在 blurEnabled 变化时：
    // 宿主可能被替换、注册表栈顶可能换人（页面 push / pop、modal 关闭、
    // 旧屏被 GC），而本表面读 scope 时**不建立 InheritedWidget 依赖**
    // （HyperosGlassBackdropScope.maybeOf 走 getInheritedWidgetOfExactType），
    // 不重新解析就永远绑在旧的那个上。resolve 是纯查表，开销可忽略。
    _bindController();
  }

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }

  /// 解析采样源（屏内作用域 → modal 时的栈顶屏）。真正的"要不要录帧"由
  /// [HyperosGlassBackdropReporter] 在 attach 时按区域登记，这里只解析归属。
  void _bindController() {
    final resolved = widget.blurEnabled
        ? HyperosGlassBackdropRegistry.resolve(context)
        : null;
    // 已释放的宿主不再持有：它的 backdrop 图已被 dispose，继续用它采样会踩到
    // 已释放的 ui.Image。注册表侧也会跳过僵尸，这里是页内作用域那条路的兜底。
    final next = (resolved == null || resolved.disposed) ? null : resolved;
    if (identical(next, _controller)) {
      return;
    }
    _controller = next;
  }

  @override
  Widget build(BuildContext context) {
    final tuning =
        widget.tuning ?? FrostedAppearanceScope.of(context).softGlassTuning;
    final isDark = SoftGlassTokens._dark(context, widget.polarity);
    return MiuixGlass(
      backdrop: widget.blurEnabled ? _backdrop : null,
      style: MiuixGlassStyles.forTheme(isDark),
      material: softGlassMaterialFor(
        context,
        dark: isDark,
        recipe: widget.recipe,
        tuning: tuning,
      ),
      shape: MiuixGlassShape(borderRadius: widget._radius),
      alpha: widget.materialAlpha.clamp(0.0, 1.0),
      // 兜底实底：只在"没有 backdrop"（模糊关闭 / 系统降级 / 首帧还没录到快照）
      // 时被上游读——有 backdrop 时玻璃底色由材质三层色 + blend shader 决定，
      // 这个 `fill` 不参与（`MiuixGlass` 的两条分支互斥，见其 paint）。
      //
      // 之前这里接的是 `widget.tint`，而 `tint` 只在 `shading == true` 时被上游
      // 当 `in_tint` uniform 读；柔光玻璃钉死 `shading: false`，所以那个入参
      // 传了也不生效，一直没有页面用它。现在改成按明暗/模糊开关直接算兜底实底，
      // 与 `HomePageChromeGlassFill.standInWashColor` 同源同口径。
      fill: SoftGlassTokens.tint(
        context,
        blurEnabled: widget.blurEnabled,
        polarity: widget.polarity,
      ),
      // 菜单 / 选择弹层同档：OS4 的「栏与菜单 MaterialToken」而不是 bionic 折射档。
      // 钉死 false —— 柔光玻璃的对外承诺就是"与首页右上角菜单同一份材质"，
      // 不留开关，避免有人翻到 `shading: true` 时把 tint / rim 那两条上游分支
      // 一并打开、观感在此处断开。
      shading: false,
      stroke: widget.enableEdgeHighlight
          ? scaleSoftGlassStroke(
              MiuixGlassStrokes.forTheme(isDark),
              tuning.edgeHighlight,
            )
          : null,
      shadow: widget.enableShadows ? MiuixGlassShadows.floating : null,
      // 外面再包一层"报告自己占哪块"的渲染对象：屏级捕获据此只录玻璃背后的
      // 那条窄带，而不是整屏（整屏快照 ~100MB/帧，实测静止也吃满一个核）。
      child: HyperosGlassBackdropReporter(
        controller: widget.blurEnabled ? _controller : null,
        backdrop: widget.blurEnabled ? _backdrop : null,
        child: widget.child,
      ),
    );
  }

}

/// 用户档位（[SoftGlassTuning]）→ 上游 OS4 玻璃材质。
///
/// **柔光玻璃全 app 共用这一份映射**：页面表面（[SoftGlassSurface]）与 OS4 弹层
/// （首页右上角菜单、选择弹层）都走它。否则同一个「柔光玻璃」，弹层不跟档位 ——
/// 真机反馈就是「选最透明和最浓的档位，首页右上角菜单一模一样」。
///
/// 两条作用通道：
/// - [SoftGlassTuning.blurRadiusMultiplier] → 材质 `blurRadius`
///   （基准 = [SoftGlassRecipe.blurRadiusDp]）。
/// - [SoftGlassTuning.tintAlphaMultiplier] → 三层颜色层 alpha **线性缩放**。
///   注意首层 α 只有 0.02，所以档位的可见差异几乎全在第二、三层
///   （详见 [SoftGlassTuning] 类头那张表）。
MiuixGlassMaterial softGlassMaterialFor(
  BuildContext context, {
  bool? dark,
  SoftGlassRecipe recipe = SoftGlassRecipe.standard,
  SoftGlassTuning? tuning,
}) {
  final isDark = dark ?? SoftGlassTokens._dark(context, null);
  final resolvedTuning =
      tuning ?? FrostedAppearanceScope.of(context).softGlassTuning;
  final radius =
      (recipe.blurRadiusDp * resolvedTuning.blurRadiusMultiplier).clamp(
        0.0,
        SoftGlassTokens.maximumBlurRadius,
      );
  final tintScale = resolvedTuning.tintAlphaMultiplier.clamp(0.0, 2.0);
  final base = MiuixGlassMaterials.popupViewGlass(isDark);
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
MiuixGlassStroke scaleSoftGlassStroke(MiuixGlassStroke base, double strength) {
  final scale = strength.clamp(0.0, 1.0);
  Color scaleColor(Color color) =>
      color.withValues(alpha: (color.a * scale).clamp(0.0, 1.0));
  MiuixGlassStrokeLight scaleLight(MiuixGlassStrokeLight light) =>
      MiuixGlassStrokeLight(light.x, light.y, light.z, scaleColor(light.color));
  return MiuixGlassStroke(
    width: base.width,
    bevel: base.bevel,
    color: scaleColor(base.color),
    primary: scaleLight(base.primary),
    secondary: scaleLight(base.secondary),
  );
}
