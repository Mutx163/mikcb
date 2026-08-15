// The Skia/Impeller fallback is handled by liquid_glass_widgets' AdaptiveGlass
// (premium shader on capable devices, lightweight shader / frosted fallback
// automatically), so no per-process shader probe is needed here anymore.

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../models/liquid_glass_tuning.dart';
import '../frosted/frosted_appearance.dart';
import '../hyperos_blurred_header.dart' show HyperosBlurredHeader;
import 'liquid_glass_tokens.dart';

/// Dim painted over modal liquid-glass panels (sheets, dialogs, popups).
///
/// Liquid-glass modals sample the *undimmed* page through a BackdropGroup
/// while the barrier behind them is dimmed at
/// [HyperosBlurredHeader.liquidGlassModalBarrierAlpha] — the glass then
/// reads much brighter than the dimmed page behind it. Painting half that
/// barrier dim over the glass surface itself (brightness sits halfway
/// between the raw page and the dimmed backdrop) keeps the panel clearly
/// the brightest layer without the harsh glare.
const liquidGlassModalSurfaceDimAlpha =
    HyperosBlurredHeader.liquidGlassModalBarrierAlpha / 2;

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
        filter: ImageFilter.blur(sigmaX: 0.01, sigmaY: 0.01),
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

    /// When true (default), sheet/modal/header roles paint a soft fill under
    /// [child] so multi-line labels stay readable over busy backdrops. Set
    /// false when the caller already manages contrast (e.g. colored course
    /// cards with white text over a hue-tinted glass underlay).
    this.contentLegibilityFill = true,

    /// Overrides the role default layer strategy when non-null.
    this.layerMode,

    /// Kept for API compatibility; backdrop-group sampling of the undimmed
    /// page is handled by [UndimmedBackdropCapture] where needed.
    this.useAncestorBackdropGroup = false,
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

  /// Whether this device can run real liquid-glass refraction shaders.
  ///
  /// AdaptiveGlass falls back to its lightweight shader / frosted path on
  /// its own; this getter reports whether the engine advertises shader
  /// filters (used by callers that want to skip refraction entirely).
  static bool get supportsRealRefraction => ImageFilter.isShaderFilterSupported;

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
    var settings = switch (role) {
      _ => MikcbLiquidGlassTokens.sheetSettingsFor(brightness, tuning: tuning),
    };
    // Header and modal chrome share the same clear material. The package's
    // default chromatic fringe (chromaticAberration=0.01) and top-down light
    // make modal corners look different from the app chrome, so use the same
    // softened specular treatment for both roles.
    if (role == HyperosLiquidGlassRole.header ||
        role == HyperosLiquidGlassRole.modal) {
      settings = settings.copyWith(
        chromaticAberration: 0,
        lightIntensity: (settings.lightIntensity * 0.35).clamp(0.0, 0.25),
      );
    }
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
    final settings = HyperosLiquidGlassSurface.settingsForRole(
      role: role,
      brightness: brightness,
      tuning: tuning,
      glassColor: glassColor,
    );

    final glassChild = contentLegibilityFill
        ? _wrapChildForLegibility(
            role: role,
            brightness: brightness,
            glassTintAlpha: settings.glassColor.a,
            child: child,
          )
        : child;

    // Modal panels float over a dimmed page; halve the barrier dim on the
    // glass surface so the panel stays the brightest layer without glaring
    // against the backdrop (see liquidGlassModalSurfaceDimAlpha).
    final surfacedChild = _wrapChildForModalDim(role: role, child: glassChild);

    final resolvedLayerMode =
        widget.layerMode ?? HyperosLiquidGlassSurface.defaultLayerModeFor(role);
    final useShared =
        resolvedLayerMode == HyperosLiquidGlassLayerMode.sharedLayer;
    final useMinimal =
        resolvedLayerMode == HyperosLiquidGlassLayerMode.fake ||
        !HyperosLiquidGlassSurface.supportsRealRefraction;

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

  /// Halves the modal barrier dim over the glass surface of modal panels.
  ///
  /// Sheets, dialogs and anchored popups sample the undimmed page while the
  /// barrier behind them is dimmed, so the glass reads as a bright panel on
  /// a dark page. Painting half the barrier alpha over the glass itself
  /// pulls the panel's brightness halfway toward the dimmed backdrop:
  /// still clearly the brightest layer, but without the harsh glare.
  static Widget _wrapChildForModalDim({
    required HyperosLiquidGlassRole role,
    required Widget child,
  }) {
    if (role != HyperosLiquidGlassRole.modal ||
        liquidGlassModalSurfaceDimAlpha <= 0) {
      return child;
    }
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(
              color: Colors.black.withValues(
                alpha: liquidGlassModalSurfaceDimAlpha,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
