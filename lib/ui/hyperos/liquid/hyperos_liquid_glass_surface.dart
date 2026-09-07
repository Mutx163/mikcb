// The Skia/Impeller fallback is handled by liquid_glass_widgets' AdaptiveGlass
// (premium shader on capable devices, lightweight shader / frosted fallback
// automatically), so no per-process shader probe is needed here anymore.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
// LiquidGlass 被包主入口刻意隐藏（"Impeller-only"）：它正是 AdaptiveGlass
// premium 路径的底层实现。这里只在 supportsRealRefraction 为真时走
// LiquidGlass.withOwnLayer（captureImage 通道 AdaptiveGlass 未透出），
// 引擎不支持 shader filter 时仍走 AdaptiveGlass 的回退路径，不会踩
// Skia 下静默渲染为空的坑。
// ignore: implementation_imports
import 'package:liquid_glass_widgets/src/renderer/liquid_glass.dart'
    show LiquidGlass;

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

    /// Kept for API compatibility; backdrop-group sampling of the undimmed
    /// page is handled by [UndimmedBackdropCapture] / [UndimmedBackdropLayer]
    /// where needed.
    this.useAncestorBackdropGroup = false,

    /// 宿主页面的同步捕获图（PopupPageCaptureScope 提供）。非空且引擎支持
    /// 真折射时，玻璃 shader 直接以它为背景纹理（LiquidGlass 的
    /// captureImage 通道），绕过实时合成器采样——浮在另一块玻璃上面的面
    /// （二级子卡）因此折射的是背后的页面本身，而不是下方玻璃的输出。
    this.captureImage,

    /// [captureImage] 的屏幕空间逻辑像素原点（捕获边界的全局位置）。
    this.captureOriginInScreenSpace = Offset.zero,
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
  final bool useAncestorBackdropGroup;
  final ui.Image? captureImage;
  final Offset captureOriginInScreenSpace;

  /// Caps effective [LiquidGlassSettings.thickness] so a narrow isolated
  /// strip (e.g. the 40dp preview weekday-only band) does not let the
  /// thickness-wide edge rim-light flood the whole bar. Null = no cap.
  final double? maxThickness;

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
    final captureImage = widget.captureImage;
    final captureOriginInScreenSpace = widget.captureOriginInScreenSpace;
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
    final cap = widget.maxThickness;
    if (cap != null && cap > 0 && settings.thickness > cap) {
      settings = settings.copyWith(thickness: math.min(settings.thickness, cap));
    }

    final glassChild = contentLegibilityFill
        ? _wrapChildForLegibility(
            role: role,
            brightness: brightness,
            glassTintAlpha: settings.glassColor.a,
            child: child,
          )
        : child;

    final surfacedChild = glassChild;

    final resolvedLayerMode =
        widget.layerMode ?? HyperosLiquidGlassSurface.defaultLayerModeFor(role);
    final useShared =
        resolvedLayerMode == HyperosLiquidGlassLayerMode.sharedLayer;
    final useMinimal =
        resolvedLayerMode == HyperosLiquidGlassLayerMode.fake ||
        !HyperosLiquidGlassSurface.supportsRealRefraction;

    // 页面捕获路径：整页 toImageSync 成 ui.Image 直接喂给玻璃 shader
    // （uBackgroundTexture），绕过实时合成器采样。玻璃叠玻璃的场景
    // （二级子卡浮在主面板玻璃上）自有采样必然把下方玻璃的输出算进
    // 背景，预捕获的页面图让玻璃真正折射背后页面。仅真折射引擎可用；
    // AdaptiveGlass 不透出 capture 通道，这里按它的 premium 路径同口径
    // 直接组合 LiquidGlass.withOwnLayer。
    if (captureImage != null &&
        HyperosLiquidGlassSurface.supportsRealRefraction) {
      return LiquidGlass.withOwnLayer(
        shape: shape,
        settings: settings,
        // 深色下阴影被背景吸收（与 AdaptiveGlass 自有层路径同口径）。
        shadows: brightness == Brightness.dark
            ? const <BoxShadow>[]
            : settings.effectiveShadow,
        clipBehavior: clipBehavior,
        captureImage: captureImage,
        captureOriginInScreenSpace: captureOriginInScreenSpace,
        child: surfacedChild,
      );
    }

    return AdaptiveGlass(
      shape: shape,
      // sharedLayer: inherit settings from the ancestor LiquidGlassLayer
      // (the explicit value is a placeholder in grouped mode).
      settings: useShared ? const LiquidGlassSettings() : settings,
      quality: useMinimal ? GlassQuality.minimal : GlassQuality.premium,
      useOwnLayer: !useShared,
      clipBehavior: clipBehavior,
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
