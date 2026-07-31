import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../../../models/liquid_glass_tuning.dart';
import '../frosted/frosted_appearance.dart';
import 'liquid_glass_tokens.dart';

/// Role of a liquid-glass surface (drives recommended shape + settings).
enum HyperosLiquidGlassRole {
  /// Bottom sheet / dialog panel shell.
  sheet,

  /// Nested menu tile / card on top of a sheet or home menu.
  nestedTile,

  /// Full-width top app bar (no corner radius).
  header,

  /// Dense timetable course cards (many instances on one page).
  ///
  /// Prefer a per-day [HyperosLiquidGlassLayer] + [sharedLayer] shapes (see
  /// [CourseCardLiquidGlassHost]). Standalone default is [FakeGlass] so a lone
  /// card never spawns an expensive own-layer path.
  courseCard,
}

/// How a [HyperosLiquidGlassSurface] obtains its liquid-glass layer.
enum HyperosLiquidGlassLayerMode {
  /// Create a private [LiquidGlassLayer] (fine for a single sheet / header).
  ownLayer,

  /// Register as a shape inside an ancestor [LiquidGlassLayer].
  ///
  /// Prefer this for multiple shapes that share the same settings.
  sharedLayer,

  /// Lightweight glass look without the refraction shader ([FakeGlass]).
  ///
  /// Official performance guidance: use for low-impact / multi-instance chrome.
  fake,
}

/// Shared [LiquidGlassLayer] host for multiple glass shapes.
///
/// Use this when several sibling surfaces share the same settings (e.g. a
/// small group of menu tiles). Do **not** wrap a full-screen sparse grid —
/// the layer allocates a texture for its entire bounds.
class HyperosLiquidGlassLayer extends StatelessWidget {
  const HyperosLiquidGlassLayer({
    required this.child,
    this.role = HyperosLiquidGlassRole.nestedTile,
    this.settings,
    this.fake = false,
    super.key,
  });

  final Widget child;
  final HyperosLiquidGlassRole role;
  final LiquidGlassSettings? settings;
  final bool fake;

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
      // Opting into fake ourselves on Skia keeps the package from logging a
      // fallback warning on every rebuild.
      fake: fake || !HyperosLiquidGlassSurface.supportsRealRefraction,
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
/// - Dense course cards → day-column shared layer ([sharedLayer]); fallback [fake]
///
/// Content legibility follows the package default
/// (`glassContainsChild: false`): labels sit *on top of* the glass, never
/// inside the refracted material. Sheets/headers also get a soft fill under
/// the child so busy backdrops (timetable, photos) do not steal contrast —
/// similar to Apple using thicker / more frosted glass on large panels.
class HyperosLiquidGlassSurface extends StatelessWidget {
  const HyperosLiquidGlassSurface({
    required this.child,
    this.role = HyperosLiquidGlassRole.sheet,
    this.borderRadius,
    this.clipBehavior = Clip.hardEdge,

    /// When set, replaces the white glass tint from [LiquidGlassTuning].
    /// Thickness / blur / lighting still come from the user's tuning.
    this.glassColor,
    // Default off: FakeGlass→LiquidGlass underlay causes a visible style flash
    // on short-lived overlays (select popups). Callers that need an underlay
    // can opt in explicitly.
    this.instantUnderlay = false,

    /// When true (default), sheet/header roles paint a soft fill under [child]
    /// so multi-line labels stay readable over busy backdrops. Set false when
    /// the caller already manages contrast (e.g. colored course cards with
    /// white text over a hue-tinted glass underlay).
    this.contentLegibilityFill = true,

    /// Overrides the role default layer strategy when non-null.
    this.layerMode,

    /// When true, own-layer glass blurs the backdrop captured at the nearest
    /// ancestor [BackdropGroup] instead of everything painted below it. Modal
    /// popups use this so their hand-drawn dim layer (a sibling inside the
    /// group) stays out of the refraction input.
    this.useAncestorBackdropGroup = false,
    super.key,
  });

  final Widget child;
  final HyperosLiquidGlassRole role;
  final double? borderRadius;
  final Clip clipBehavior;
  final Color? glassColor;

  /// When true, paints [FakeGlass] under the real shader so the first frames
  /// are not a solid/empty panel while Impeller warms up (select popups).
  final bool instantUnderlay;

  /// Soft fill under content for sheet/header roles (see constructor).
  final bool contentLegibilityFill;

  /// Layer / fake strategy. Null → [defaultLayerModeFor].
  final HyperosLiquidGlassLayerMode? layerMode;

  /// Sample the ancestor [BackdropGroup]'s backdrop (see constructor).
  ///
  /// Only affects [HyperosLiquidGlassLayerMode.ownLayer]: [sharedLayer] defers
  /// to the caller-managed layer, and the [fake] fallback (Skia) keeps its own
  /// local capture — the dim is then sampled, matching pre-group behavior.
  final bool useAncestorBackdropGroup;

  /// Whether this device can run the real liquid-glass refraction shader.
  ///
  /// False on Skia (OpenGL-only Android). The package would fall back to
  /// [FakeGlass] on its own, but only after logging a warning from `build` —
  /// i.e. once per rebuild — so callers downgrade explicitly instead.
  static bool get supportsRealRefraction => ImageFilter.isShaderFilterSupported;

  /// Role-based default for [layerMode].
  static HyperosLiquidGlassLayerMode defaultLayerModeFor(
    HyperosLiquidGlassRole role,
  ) {
    return switch (role) {
      // Standalone fallback only. Timetable wraps cards in a shared host.
      HyperosLiquidGlassRole.courseCard => HyperosLiquidGlassLayerMode.fake,
      HyperosLiquidGlassRole.sheet ||
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
      HyperosLiquidGlassRole.sheet || HyperosLiquidGlassRole.header =>
        MikcbLiquidGlassTokens.sheetSettingsFor(brightness, tuning: tuning),
      HyperosLiquidGlassRole.nestedTile =>
        MikcbLiquidGlassTokens.nestedTileSettingsFor(
          brightness,
          tuning: tuning,
        ),
      HyperosLiquidGlassRole.courseCard =>
        MikcbLiquidGlassTokens.courseCardSettingsFor(
          brightness,
          tuning: tuning,
        ),
    };
    // Full-width header bars sit flush with the screen top. The package's
    // default chromatic fringe + top-down light draw a 1px blue hairline on
    // that edge; kill aberration and soften specular for this role only.
    if (role == HyperosLiquidGlassRole.header) {
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
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final tuning = FrostedAppearanceScope.of(context).liquidGlassTuning;
    final resolvedRadius =
        borderRadius ??
        switch (role) {
          HyperosLiquidGlassRole.sheet =>
            MikcbLiquidGlassTokens.sheetBorderRadius(),
          HyperosLiquidGlassRole.nestedTile ||
          HyperosLiquidGlassRole.courseCard =>
            MikcbLiquidGlassTokens.nestedTileBorderRadius(),
          HyperosLiquidGlassRole.header => 0,
        };
    final shape = resolvedRadius <= 0.01
        ? const LiquidRoundedRectangle(borderRadius: 0)
        : LiquidRoundedSuperellipse(borderRadius: resolvedRadius);
    final settings = settingsForRole(
      role: role,
      brightness: brightness,
      tuning: tuning,
      glassColor: glassColor,
    );

    // Official default: child on top of glass (not tinted/refracted with it).
    // Sheets and headers carry dense UI chrome; nested tiles stay pure glass.
    final glassChild = contentLegibilityFill
        ? _wrapChildForLegibility(
            role: role,
            brightness: brightness,
            glassTintAlpha: settings.glassColor.a,
            child: child,
          )
        : child;

    var resolvedLayerMode = layerMode ?? defaultLayerModeFor(role);
    if (resolvedLayerMode == HyperosLiquidGlassLayerMode.ownLayer &&
        !supportsRealRefraction) {
      // sharedLayer needs no handling: the package resolves shapes inside a
      // faked ancestor layer to FakeGlass.inLayer without warning.
      resolvedLayerMode = HyperosLiquidGlassLayerMode.fake;
    }

    final Widget liquid = switch (resolvedLayerMode) {
      HyperosLiquidGlassLayerMode.fake => FakeGlass(
        shape: shape,
        settings: settings,
        child: glassChild,
      ),
      HyperosLiquidGlassLayerMode.sharedLayer => LiquidGlass(
        shape: shape,
        clipBehavior: clipBehavior,
        glassContainsChild: false,
        child: glassChild,
      ),
      // withOwnLayer never forwards useBackdropGroup (package hardcodes the
      // default), so the group-sampling path builds the layer explicitly.
      HyperosLiquidGlassLayerMode.ownLayer when useAncestorBackdropGroup =>
        LiquidGlassLayer(
          settings: settings,
          useBackdropGroup: true,
          child: LiquidGlass(
            shape: shape,
            clipBehavior: clipBehavior,
            glassContainsChild: false,
            child: glassChild,
          ),
        ),
      HyperosLiquidGlassLayerMode.ownLayer => LiquidGlass.withOwnLayer(
        settings: settings,
        shape: shape,
        clipBehavior: clipBehavior,
        glassContainsChild: false,
        child: glassChild,
      ),
    };

    // Instant underlay only helps real shaders; FakeGlass already paints ASAP.
    if (!instantUnderlay ||
        resolvedLayerMode == HyperosLiquidGlassLayerMode.fake) {
      return liquid;
    }

    // FakeGlass is cheap and paints immediately; real LiquidGlass may take a
    // frame or two after shader/geometry setup, which used to flash solid UI.
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: FakeGlass(
              shape: shape,
              settings: settings,
              child: const SizedBox.expand(),
            ),
          ),
        ),
        liquid,
      ],
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
      // Large panels with dense labels / lists.
      HyperosLiquidGlassRole.sheet =>
        brightness == Brightness.dark ? 0.50 : 0.56,
      // Titles / icons — slightly lighter so the bar still reads as glass.
      HyperosLiquidGlassRole.header =>
        brightness == Brightness.dark ? 0.40 : 0.44,
      // Small chrome / course cards: caller owns contrast (or pure glass).
      HyperosLiquidGlassRole.nestedTile ||
      HyperosLiquidGlassRole.courseCard => null,
    };
    if (targetFloor == null) {
      return child;
    }

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
