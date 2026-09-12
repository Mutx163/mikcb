// The Skia/Impeller fallback is handled by liquid_glass_widgets' AdaptiveGlass
// (premium shader on capable devices, lightweight shader / frosted fallback
// automatically), so no per-process shader probe is needed here anymore.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../models/liquid_glass_tuning.dart';
import '../frosted/frosted_appearance.dart';
import 'liquid_glass_tokens.dart';

/// Role of a liquid-glass surface (drives recommended shape + settings).
enum HyperosLiquidGlassRole {
  /// Bottom sheet / dialog panel shell.
  sheet,

  /// Modal / popup surface using the same clear material as the top chrome.
  ///
  /// Modal panels need the same tint and specular treatment everywhere so a
  /// select popup does not look denser than a dialog or an action sheet.
  modal,

  /// Nested menu tile / card on top of a sheet or home menu.
  nestedTile,

  /// Full-width top app bar (no corner radius).
  header,
}

/// How a [HyperosLiquidGlassSurface] obtains its liquid-glass layer.
enum HyperosLiquidGlassLayerMode {
  /// Create a private glass layer (fine for a single sheet / header).
  ownLayer,

  /// Register as a shape inside an ancestor [HyperosLiquidGlassLayer]
  /// (grouped glass — several shapes share one layer / settings).
  sharedLayer,

  /// Lightweight frosted look without the refraction shader.
  ///
  /// Official performance guidance: use for low-impact / multi-instance chrome.
  fake,
}

/// Paints a no-op grouped backdrop filter before modal dim layers.
///
/// The first filter in a [BackdropGroup] caches the backdrop. Placing this
/// before the dim layer means later liquid glass surfaces in the same group
/// sample the undimmed page instead of the darkened modal scrim.
class UndimmedBackdropCapture extends StatelessWidget {
  const UndimmedBackdropCapture({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: BackdropFilter.grouped(
        filter: ui.ImageFilter.blur(sigmaX: 0.01, sigmaY: 0.01),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Shared [LiquidGlassLayer] host for multiple glass shapes.
///
/// Use this when several sibling surfaces share the same settings (e.g. a
/// small group of menu tiles). Children rendered with
/// [HyperosLiquidGlassLayerMode.sharedLayer] inherit this layer's settings.
class HyperosLiquidGlassLayer extends StatelessWidget {
  const HyperosLiquidGlassLayer({
    required this.child,
    this.role = HyperosLiquidGlassRole.nestedTile,
    this.settings,
    this.fake = false,
    this.useBackdropGroup = false,
    super.key,
  });

  final Widget child;
  final HyperosLiquidGlassRole role;
  final LiquidGlassSettings? settings;
  final bool fake;

  /// Kept for API compatibility. liquid_glass_widgets handles backdrop
  /// isolation via its own layer capture; the Flutter [BackdropGroup]
  /// opt-in of the old renderer is no longer surfaced.
  final bool useBackdropGroup;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final tuning = FrostedAppearanceScope.of(context).liquidGlassTuning;
    final resolvedSettings =
        settings ??
        HyperosLiquidGlassSurface.settingsForRole(
          role: role,
          brightness: brightness,
          tuning: tuning,
        );
    return LiquidGlassLayer(
      settings: resolvedSettings,
      child: child,
    );
  }
}

/// Single liquid-glass panel using official recommended shapes/settings.
///
/// Layer strategy (official performance tips):
/// - Sparse single panels (sheet / header) → [HyperosLiquidGlassLayerMode.ownLayer]
/// - Several siblings with identical settings → wrap in [HyperosLiquidGlassLayer]
///   and use [HyperosLiquidGlassLayerMode.sharedLayer]
/// Content legibility follows the package default
/// (glassContainsChild: false): labels sit *on top of* the glass, never
/// inside the refracted material. Sheets/headers also get a soft fill under
/// the child so busy backdrops (timetable, photos) do not steal contrast —
/// similar to Apple using thicker / more frosted glass on large panels.
class HyperosLiquidGlassSurface extends StatefulWidget {
  const HyperosLiquidGlassSurface({
    required this.child,
    this.role = HyperosLiquidGlassRole.sheet,
    this.borderRadius,
    this.clipBehavior = Clip.antiAlias,

    /// When set, replaces the white glass tint from [LiquidGlassTuning].
    /// Thickness / blur / lighting still come from the user's tuning.
    this.glassColor,

    /// Kept for API compatibility; the AdaptiveGlass engine handles its own
    /// first-frame warm-up, so no explicit underlay is required.
    this.instantUnderlay = false,

    /// 官方默认观感：不再为可读性叠加填充层。需要时（如课程卡片）
    /// 调用方可显式开启。
    this.contentLegibilityFill = false,

    /// Overrides the role default layer strategy when non-null.
    this.layerMode,

    /// 折射厚度缩放（0..1）：非空且 <1 时，材质 thickness 按该比例缩放。
    /// 用于入场动画——厚度从近零生长到满值，玻璃「凝固」入场，边缘折射
    /// 对周边文字的镜像随厚度减弱，揭示完成后回到完整观感。
    this.thicknessFactor,

    /// Kept for API compatibility; backdrop-group sampling of the undimmed
    /// page is handled by [UndimmedBackdropCapture] / [UndimmedBackdropLayer]
    /// where needed.
    ///
    /// 注意：自玻璃引擎切换（cc98db3a）起已是**死参数**——本组件只存储、
    /// 从不读取，传 true 不会有任何行为差异（真实采样完全由
    /// liquid_glass_widgets 内部决定）。保留仅因调用点众多、删除需同步
    /// 五处调用与两处测试断言，收益不足。新代码不要据此做任何决策。
    this.useAncestorBackdropGroup = false,
    this.maxThickness,
    this.backgroundKey,
    super.key,
  });

  final Widget child;
  final HyperosLiquidGlassRole role;
  final double? borderRadius;
  final Clip clipBehavior;
  final Color? glassColor;
  final bool instantUnderlay;
  final bool contentLegibilityFill;
  final HyperosLiquidGlassLayerMode? layerMode;

  /// 死参数（见构造处说明）：只存储不读取。
  final bool useAncestorBackdropGroup;

  /// Caps effective [LiquidGlassSettings.thickness] so a narrow isolated
  /// strip (e.g. the 40dp preview weekday-only band) does not let the
  /// thickness-wide edge rim-light flood the whole bar. Null = no cap.
  final double? maxThickness;

  /// 折射厚度缩放（0..1），见构造参数文档。null = 不缩放。
  final double? thicknessFactor;

  /// 折射取样边界的 [RepaintBoundary] key（宿主页面的整页捕获边界）。
  ///
  /// **这是「有没有折射」的唯一开关。** 包内 lightweight_glass.frag 的折射
  /// 位移写在 PATH A，而 PATH A 的守卫是 `uBackgroundSize.x > 1.0`——只有
  /// 传了 backgroundKey、真正抓到了背景纹理才成立；否则走 PATH B，折射位移
  /// 整段不执行，玻璃只剩「一圈 rim/fresnel 描边」。
  ///
  /// 而 `AdaptiveGlass`（本项目其余所有液态表面的入口）**从不传**
  /// backgroundKey，所以凡经它渲染的表面在 standard 档下恒定零折射。要让
  /// 折射真正出现，必须绕开 AdaptiveGlass、直接走
  /// `LightweightLiquidGlass(backgroundKey: …)`——见本文件的 build 内
  /// 「真折射通道」分支（[usesRefractingPath] 判定）。
  ///
  /// 注意：走这条通道时不再经过 `AdaptiveGlass`，因此它顺带提供的
  /// 浅色模式外投影由本组件自行补回（[_wrapRefractingDecorations]）。
  final GlobalKey? backgroundKey;

  /// Whether this device can run real liquid-glass refraction shaders.
  ///
  /// AdaptiveGlass falls back to its lightweight shader / frosted path on
  /// its own; this getter reports whether the engine advertises shader
  /// filters (used by callers that want to skip refraction entirely).
  static bool get supportsRealRefraction => ui.ImageFilter.isShaderFilterSupported;

  /// Role-based default for [layerMode].
  static HyperosLiquidGlassLayerMode defaultLayerModeFor(
    HyperosLiquidGlassRole role,
  ) {
    return switch (role) {
      HyperosLiquidGlassRole.sheet ||
      HyperosLiquidGlassRole.modal ||
      HyperosLiquidGlassRole.header ||
      HyperosLiquidGlassRole.nestedTile => HyperosLiquidGlassLayerMode.ownLayer,
    };
  }

  /// Resolves [LiquidGlassSettings] for a role without building a widget.
  static LiquidGlassSettings settingsForRole({
    required HyperosLiquidGlassRole role,
    required Brightness brightness,
    LiquidGlassTuning? tuning,
    Color? glassColor,
  }) {
    // 所有角色共用同一套玻璃参数（与玻璃坞切换栏一致），
    // 不再对 header/modal 做单独的光学调节。
    var settings = switch (role) {
      _ => MikcbLiquidGlassTokens.sheetSettingsFor(brightness, tuning: tuning),
    };
    if (glassColor != null) {
      settings = settings.copyWith(glassColor: glassColor);
    }
    return settings;
  }

  /// 是否走「真折射通道」（[LightweightLiquidGlass] + backgroundKey）。
  ///
  /// 纯决策函数，便于在无 GPU 的测试环境里钉住行为（widget 测试里
  /// `ImageFilter.isShaderFilterSupported` 为 false，渲染路径会被强制降级，
  /// 直接把这条判定塞在 build 里就没法稳定断言）。
  ///
  /// 三个必要条件，缺一即回落到 AdaptiveGlass：
  /// - 有宿主捕获边界（没有它 PATH A 永远不成立，折射位移无从执行）；
  /// - 非共享组（共享组靠祖先 LiquidGlassLayer 提供设置，直用会丢参数）；
  /// - 非降级（`fake` 角色或设备不支持 shader filter 时本就不该折射）。
  @visibleForTesting
  static bool usesRefractingPath({
    required GlobalKey? backgroundKey,
    required bool useShared,
    required bool useMinimal,
  }) {
    return backgroundKey != null && !useShared && !useMinimal;
  }



  @override
  State<HyperosLiquidGlassSurface> createState() =>
      _HyperosLiquidGlassSurfaceState();
}

class _HyperosLiquidGlassSurfaceState extends State<HyperosLiquidGlassSurface> {
  @override
  Widget build(BuildContext context) {
    final role = widget.role;
    final borderRadius = widget.borderRadius;
    final clipBehavior = widget.clipBehavior;
    final glassColor = widget.glassColor;
    final contentLegibilityFill = widget.contentLegibilityFill;
    final child = widget.child;

    final brightness = Theme.of(context).brightness;
    final tuning = FrostedAppearanceScope.of(context).liquidGlassTuning;
    final resolvedRadius =
        borderRadius ??
        switch (role) {
          HyperosLiquidGlassRole.sheet =>
            MikcbLiquidGlassTokens.sheetBorderRadius(),
          HyperosLiquidGlassRole.modal =>
            MikcbLiquidGlassTokens.sheetBorderRadius(),
          HyperosLiquidGlassRole.nestedTile =>
            MikcbLiquidGlassTokens.nestedTileBorderRadius(),
          HyperosLiquidGlassRole.header => 0,
        };
    final shape = resolvedRadius <= 0.01
        ? const LiquidRoundedRectangle(borderRadius: 0)
        : LiquidRoundedSuperellipse(borderRadius: resolvedRadius);
    var settings = HyperosLiquidGlassSurface.settingsForRole(
      role: role,
      brightness: brightness,
      tuning: tuning,
      glassColor: glassColor,
    );

    // ---- 渲染路径判定（必须先于 settings 调整）--------------------------
    // 这条判定同时决定「厚度怎么补偿」：PATH A 下 thickness 本身就驱动真实
    // 折射位移，再叠一层可见光学量就是双重计数（详见 [withThicknessOptics]）。
    final resolvedLayerMode =
        widget.layerMode ?? HyperosLiquidGlassSurface.defaultLayerModeFor(role);
    final useShared =
        resolvedLayerMode == HyperosLiquidGlassLayerMode.sharedLayer;
    final useMinimal =
        resolvedLayerMode == HyperosLiquidGlassLayerMode.fake ||
        !HyperosLiquidGlassSurface.supportsRealRefraction;
    final GlobalKey? captureKey = widget.backgroundKey;
    final refracts = HyperosLiquidGlassSurface.usesRefractingPath(
      backgroundKey: captureKey,
      useShared: useShared,
      useMinimal: useMinimal,
    );

    final cap = widget.maxThickness;
    if (cap != null && cap > 0 && settings.thickness > cap) {
      settings = settings.copyWith(thickness: math.min(settings.thickness, cap));
    }
    // 折射厚度缩放（入场「凝固」动画）：厚度按比例衰减，边缘折射对周边
    // 内容的取样镜像随之减弱；厚度变化触发包内几何重建，入场 200ms 内
    // 每帧重建一次 SDF matte，成本可接受。
    final factor = widget.thicknessFactor;
    if (factor != null && factor < 1) {
      settings = settings.copyWith(
        thickness: math.max(0, settings.thickness * factor),
      );
    }

    // 生效厚度（含 cap 与入场缩放的衰减）回写光学补偿：两条路的可见反馈
    // 都按用户最终看到的厚度计算，而不是原始滑杆值。
    var tuned = tuning ?? LiquidGlassTuning.defaults;
    if (settings.thickness != tuned.thickness) {
      tuned = tuned.copyWith(
        thickness: settings.thickness.clamp(
          LiquidGlassTuning.minThickness,
          LiquidGlassTuning.maxThickness,
        ),
      );
    }
    settings = refracts
        ? withThicknessOptics(settings, tuned)
        : withoutThicknessOptics(settings, tuned);

    final glassChild = contentLegibilityFill
        ? _wrapChildForLegibility(
            role: role,
            brightness: brightness,
            glassTintAlpha: settings.glassColor.a,
            child: child,
          )
        : child;

    final surfacedChild = glassChild;

    // 弹出面板以弹簧缩放入场（0.15→1、ratio 0.82 必有过冲 ~1.1%）：过冲
    // 帧把玻璃纹理放大到超出 RepaintBoundary 的布局边界，Impeller 在纹理
    // 边缘硬裁出「顶切」闪斑——弹窗打开必闪一下的来源。给弹窗角色预留
    // 纹理扩边（_ScaleSafeRepaintBoundary 的 clipExpansion 通道，包官方
    // 建议 12dp 覆盖 480px 面 5% 缩放），其余角色不缩放、不预留。
    final clipExpansion = role == HyperosLiquidGlassRole.modal
        ? const EdgeInsets.all(12)
        : EdgeInsets.zero;

    // ---- 真折射通道 -------------------------------------------------------
    // 给了宿主捕获边界（且非降级、非共享组）时，绕开 AdaptiveGlass 直接走
    // 公开的 LightweightLiquidGlass：只有它接受 backgroundKey，进而让
    // lightweight_glass.frag 进入 PATH A——折射位移、边缘色散、背景饱和度
    // 那一整条链路才会执行。经 AdaptiveGlass 的表面恒为 PATH B，折射为零，
    // 真机上只剩一圈 rim/fresnel 描边（用户口径：「一个颜色不一样的圈圈包
    // 边」）。
    //
    // 安全性：LightweightLiquidGlass 不再依赖祖先 LiquidGlassLayer
    // （0.30.2 #214 修掉了「无 layer 时 LiquidGlassBlendGroup 崩」），因此
    // 顶栏带这种挂在裸 Stack 上的表面可以安全直用。渲染质量仍是 standard
    // （轻量片元着色器），不引入 premium 的逐帧全屏纹理抓取，性能口径不变。
    if (refracts) {
      final refracting = ClipPath(
        clipBehavior: clipBehavior,
        clipper: ShapeBorderClipper(shape: shape),
        child: LightweightLiquidGlass(
          shape: shape,
          settings: settings,
          backgroundKey: captureKey,
          child: surfacedChild,
        ),
      );
      return _wrapRefractingDecorations(
        context: context,
        shape: shape,
        settings: settings,
        glass: refracting,
      );
    }

    return AdaptiveGlass(
      shape: shape,
      // sharedLayer: inherit settings from the ancestor LiquidGlassLayer
      // (the explicit value is a placeholder in grouped mode).
      settings: useShared ? const LiquidGlassSettings() : settings,
      quality: useMinimal
          ? GlassQuality.minimal
          : MikcbLiquidGlassTokens.defaultQuality,
      useOwnLayer: !useShared,
      clipBehavior: clipBehavior,
      clipExpansion: clipExpansion,
      child: surfacedChild,
    );
  }

  /// 补回绕开 `AdaptiveGlass` 后失去的装饰层（浅色模式外投影）。
  ///
  /// 经 `AdaptiveGlass` 的表面会额外套 `_wrapWithBacker` +
  /// `_wrapWithLightModeShadow`：本项目 `sheetSettings` 没有 `backerColor`
  /// （alpha 0 即无操作），但 `effectiveShadow` 默认非空（`shadowElevation
  /// = 1.0`）。直连 `LightweightLiquidGlass` 后这层没了，后果分两类：
  ///
  /// - 平边形状（顶栏带，圆角 0）：包内 `_isFlatEdge` 本就会跳过投影，
  ///   拆掉后**无差异**；
  /// - 带圆角的板面（弹窗 / 二级子卡）：浅色模式下**丢了外投影**，面板
  ///   读作「贴平在页面上」。
  ///
  /// 实现与包内同款：投影画在玻璃**之上**，再用反向形状裁剪把玻璃内部挖
  /// 空（[PathFillType.evenOdd]），只让投影落在玻璃外侧——否则玻璃会模糊
  /// 自己的投影，糊出一圈脏边。深色模式与平边形状直接短路，与包内一致。
  static Widget _wrapRefractingDecorations({
    required BuildContext context,
    required LiquidShape shape,
    required LiquidGlassSettings settings,
    required Widget glass,
  }) {
    if (GlassTheme.brightnessOf(context) == Brightness.dark) return glass;
    if (shape is LiquidRoundedRectangle && shape.borderRadius == 0) {
      return glass;
    }
    if (shape is LiquidRoundedSuperellipse && shape.borderRadius == 0) {
      return glass;
    }
    final shadows = settings.effectiveShadow;
    if (shadows.isEmpty) return glass;
    final borderRadius = switch (shape) {
      LiquidRoundedRectangle(:final borderRadius) => BorderRadius.circular(
        borderRadius,
      ),
      LiquidRoundedSuperellipse(:final borderRadius) => BorderRadius.circular(
        borderRadius,
      ),
      _ => null,
    };
    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        glass,
        Positioned.fill(
          child: IgnorePointer(
            child: ClipPath(
              clipBehavior: Clip.antiAlias,
              clipper: _InverseLiquidShapeClipper(shape),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  boxShadow: shadows,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 把 [settings] 的**厚度能否被看见**交代清楚，按渲染路径二选一。
  ///
  /// 包内 lightweight_glass.frag 的折射位移只在 PATH A（拿到背景纹理、
  /// `uBackgroundSize.x > 1`）执行；PATH B 下 thickness 只影响 ~11dp 边界
  /// 带内的 rim，肉眼不可辨。而全 app 曾长期恒走 PATH B，于是
  /// `LiquidGlassTuning.visibleThicknessOptics()` 把厚度折算成 PATH B 真正
  /// 生效的 edgeAbsorption / fresnelStrength。
  ///
  /// 接通真折射通道（backgroundKey）后出现新问题：PATH A 下 thickness 本身
  /// 就驱动折射位移，再叠这两个量就是**双重计数**（用户拉高厚度会同时得到
  /// 真实折射 + 边缘变沉 + 边缘变亮）；而且 `tuning == null` 的兜底档拿不到
  /// 折算，两条路的厚度观感会分叉。
  ///
  /// 所以在此显式化：
  /// - [withThicknessOptics]：PATH A —— 只保留厚度本身的真实折射，去掉
  ///   折算量。
  /// - [withoutThicknessOptics]：PATH B —— 把折算量按生效厚度算出来。
  ///
  /// 两者都是**幂等**的，且厚度默认值 30 下折算结果恰好等于包构造默认
  /// （edgeAbsorption 0 / fresnelStrength 1），因此默认观感不变。
  ///
  /// 注意 [tuning] 必须携带**生效厚度**（已含 cap 与入场缩放）；调用方
  /// 负责在传参前把 `tuning.thickness` 对齐到 `settings.thickness`，否则
  /// 入场动画期间的补偿量与折射位移量会脱钩。
  @visibleForTesting
  static LiquidGlassSettings withThicknessOptics(
    LiquidGlassSettings settings,
    LiquidGlassTuning tuning,
  ) {
    return settings.copyWith(
      edgeAbsorption: 0.0,
      fresnelStrength: 1.0,
    );
  }

  /// 见 [withThicknessOptics] 的说明。PATH B 把厚度折算成可见光学量。
  @visibleForTesting
  static LiquidGlassSettings withoutThicknessOptics(
    LiquidGlassSettings settings,
    LiquidGlassTuning tuning,
  ) {
    final optics = tuning.visibleThicknessOptics();
    return settings.copyWith(
      edgeAbsorption: optics.edgeAbsorption,
      fresnelStrength: optics.fresnelStrength,
    );
  }

  /// Soft fill under sheet/header content so body text keeps contrast.
  ///
  /// Package README glass tint is only ~20% white — fine for icon chrome over
  /// photos, too thin for multi-line lists. Gaussian sheets in mikcb use ~70%
  /// scrim; this fill bridges the gap without rewriting official shader knobs.
  static Widget _wrapChildForLegibility({
    required HyperosLiquidGlassRole role,
    required Brightness brightness,
    required double glassTintAlpha,
    required Widget child,
  }) {
    final targetFloor = switch (role) {
      // Legacy direct surfaces use the same legibility floor so brightness
      // does not drift between sheets, headers and popups. Modal shells pass
      // contentLegibilityFill=false when they need the clear chrome material.
      HyperosLiquidGlassRole.sheet ||
      HyperosLiquidGlassRole.modal ||
      HyperosLiquidGlassRole.header ||
      HyperosLiquidGlassRole.nestedTile =>
        brightness == Brightness.dark ? 0.50 : 0.56,
    };

    // glassColor already contributes some milky wash; only add the shortfall.
    final fillAlpha = (targetFloor - glassTintAlpha).clamp(0.10, 0.50);
    final fillColor = brightness == Brightness.dark
        ? Colors.black.withValues(alpha: fillAlpha)
        : Colors.white.withValues(alpha: fillAlpha);

    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: IgnorePointer(child: ColoredBox(color: fillColor)),
        ),
        child,
      ],
    );
  }
}

/// 反向形状裁剪：保留 [shape] **之外**的区域，用来把玻璃的外投影挖到玻璃
/// 外侧。与包内 `_InverseShapeClipper` 同款实现（包未导出该类）：外扩矩形
/// 减掉形状本体，按 [PathFillType.evenOdd] 取差集，避开 Impeller 上不稳的
/// CPU 布尔路径运算。外扩 50dp 足以覆盖包内默认投影的最大模糊半径。
class _InverseLiquidShapeClipper extends CustomClipper<Path> {
  const _InverseLiquidShapeClipper(this.shape);

  final LiquidShape shape;

  @override
  Path getClip(Size size) {
    final rect = Offset.zero & size;
    return Path()
      ..addRect(rect.inflate(50.0))
      ..addPath(shape.getOuterPath(rect), Offset.zero)
      ..fillType = PathFillType.evenOdd;
  }

  @override
  bool shouldReclip(_InverseLiquidShapeClipper oldClipper) =>
      oldClipper.shape != shape;
}
