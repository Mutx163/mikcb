// The Skia/Impeller fallback is handled by liquid_glass_widgets' AdaptiveGlass
// (premium shader on capable devices, lightweight shader / frosted fallback
// automatically), so no per-process shader probe is needed here anymore.

import 'dart:math' as math;
import 'dart:ui' as ui;

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

  /// 把 [settings] 的**厚度能否被看见**交代清楚，按渲染路径二选一。
  ///
  /// 液态玻璃现在全 app 只有一条渲染路径（[MikcbLiquidGlassTokens.defaultQuality]
  /// = premium，实时读底面、厚度驱动真实折射）。这个二选一只剩下「引擎降级」
  /// 一种用途：impeller 不可用时包内退到轻量片元着色器，厚度在那里几乎看不见
  /// （PATH B 只影响 ~11dp 边界带内的 rim），于是用
  /// `LiquidGlassTuning.visibleThicknessOptics()` 把厚度折算成真正生效的
  /// edgeAbsorption / fresnelStrength。
  ///
  /// 历史包袱（勿重犯）：这里曾经按「有 backgroundKey 的抓拍纹理通道 / 没有」
  /// 来分派，于是同一材质在不同表面走不同补偿——又一种观感分叉。抓拍纹理
  /// 通道已删除，分派依据只剩引擎能力，全 app 一致。
  ///
  /// 所以在此显式化：
  /// - [withThicknessOptics]：实时折射路径（premium）——只保留厚度本身的
  ///   真实折射，去掉折算量，避免双重计数。**本函数不使用 [tuning]**，保留
  ///   该形参只为与降级版本同签名、便于调用点成对书写。
  /// - [withoutThicknessOptics]：降级路径 —— 把折算量按生效厚度算出来。
  ///
  /// 两者都是**幂等**的，且厚度默认值 30 下折算结果恰好等于包构造默认
  /// （edgeAbsorption 0 / fresnelStrength 1），因此默认观感不变。
  ///
  /// 注意 [withoutThicknessOptics] 的 [tuning] 必须携带**生效厚度**（已含
  /// cap 与入场缩放）；调用方负责在传参前把 `tuning.thickness` 对齐到
  /// `settings.thickness`，否则入场动画期间的补偿量与折射位移量会脱钩。
  ///
  /// 这两个纯函数放在**公共**类上而非私有 State 上：它们是
  /// `@visibleForTesting` 的决策函数，测试需要直接钉住「补偿按路径分派」。
  /// 私有类成员对测试不可见（`Member not found`），会让 `flutter analyze`
  /// 与 `flutter test` 同时失败。
  @visibleForTesting
  static LiquidGlassSettings withThicknessOptics(
    LiquidGlassSettings settings,
    LiquidGlassTuning tuning,
  ) {
    return settings.copyWith(edgeAbsorption: 0, fresnelStrength: 1);
  }

  /// 见 [withThicknessOptics] 的说明。引擎降级（包内轻量片元着色器）时，
  /// 把厚度折算成那里真正生效的可见光学量。
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
    // 全 app 一条路：premium（实时读底面、厚度驱动真实折射）。唯一的分叉
    // 是引擎降级——`fake` 预览层或设备不支持 shader filter 时才退到最小档，
    // 那是全 app 一起降级，不是某个表面换个观感。
    final resolvedLayerMode =
        widget.layerMode ?? HyperosLiquidGlassSurface.defaultLayerModeFor(role);
    final useShared =
        resolvedLayerMode == HyperosLiquidGlassLayerMode.sharedLayer;
    final useMinimal =
        resolvedLayerMode == HyperosLiquidGlassLayerMode.fake ||
        !HyperosLiquidGlassSurface.supportsRealRefraction;

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

    // 生效厚度（含 cap 与入场缩放的衰减）回写光学补偿：可见反馈按用户最终
    // 看到的厚度算，而不是原始滑杆值。分派依据只有「引擎是否还能跑实时
    // 折射」——全 app 同一个判据。
    var tuned = tuning ?? LiquidGlassTuning.defaults;
    if (settings.thickness != tuned.thickness) {
      tuned = tuned.copyWith(
        thickness: settings.thickness.clamp(
          LiquidGlassTuning.minThickness,
          LiquidGlassTuning.maxThickness,
        ),
      );
    }
    settings = useMinimal
        ? HyperosLiquidGlassSurface.withoutThicknessOptics(settings, tuned)
        : HyperosLiquidGlassSurface.withThicknessOptics(settings, tuned);

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

    // 唯一入口 AdaptiveGlass（premium）：折射、模糊、tint/whiten/rim 全链路
    // 与玻璃坞、顶栏带、弹窗、卡片完全同参同档。
    //
    // 历史包袱（勿重犯）：这里曾经有一条「抓拍纹理真折射通道」——绕开
    // AdaptiveGlass 直连 LightweightLiquidGlass 并传 backgroundKey，让
    // standard 档也能折射。它的代价是玻璃里贴一张静态照片、且只有部分表面
    // 走它，于是同一个材质出现两种观感。已整体删除。
    return AdaptiveGlass(
      shape: shape,
      // sharedLayer: inherit settings from the ancestor LiquidGlassLayer
      // (the explicit value is a placeholder in grouped mode).
      settings: useShared ? const LiquidGlassSettings() : settings,
      // 唯一的档位常量：全 app 液态玻璃同档同观感。降级时（无 shader
      // filter / fake 预览层）一起退到 minimal。
      quality: useMinimal
          ? GlassQuality.minimal
          : MikcbLiquidGlassTokens.defaultQuality,
      useOwnLayer: !useShared,
      clipBehavior: clipBehavior,
      clipExpansion: clipExpansion,
      child: surfacedChild,
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
