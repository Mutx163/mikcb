// The Skia fallback intentionally uses the package's internal RawFakeGlass so
// it can share a BackdropGroup key with the real refraction path.
// ignore_for_file: implementation_imports, invalid_use_of_internal_member

import 'dart:ui' show ImageFilter, FragmentProgram;

import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/src/fake_glass.dart' show RawFakeGlass;
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

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

/// Runtime shader-support state shared by every liquid-glass surface.
///
/// [ImageFilter.isShaderFilterSupported] only answers "does this engine
/// advertise shader filters". Some engines (e.g. Impeller on Vulkan) still
/// fail to compile the packaged refraction shader, and the package's
/// [ShaderBuilder] turns that compile failure into a `FlutterError.reportError`
/// that crashes debug builds. We probe once per process with a direct
/// `FragmentProgram.fromAsset` and remember the outcome so every surface can
/// downgrade to [FakeGlass] (a shader-less frosted look) instead of crashing.
abstract final class LiquidGlassShaderProbe {
  static Future<void>? _probeFuture;
  static bool? _realRefractionReady;

  /// Whether the refraction shader actually compiled on this engine.
  ///
  /// False until the first probe finishes, so surfaces default to fake while
  /// the probe is in flight and no frame can crash on a half-loaded shader.
  static bool get realRefractionReady => _realRefractionReady ?? false;

  static Future<void> probeIfNeeded() {
    final existing = _probeFuture;
    if (existing != null) {
      return existing;
    }
    final future = _probe();
    _probeFuture = future;
    return future;
  }

  static Future<void> _probe() async {
    if (_realRefractionReady != null) {
      return;
    }
    if (!ImageFilter.isShaderFilterSupported) {
      _realRefractionReady = false;
      return;
    }
    try {
      // 只探测弹窗/header 主渲染路径实际使用的 final_render shader。
      // 其余 shader（glassify / geometry_blended / filter）只服务于单独的
      // glassify / 多形状混合功能，与 HyperosLiquidGlassSurface 无关；
      // 它们编译失败（例如本机 Vulkan 下的 SkSL 不兼容）不应连累弹窗降级。
      await FragmentProgram.fromAsset(
        'packages/liquid_glass_renderer/lib/assets/shaders/'
        'liquid_glass_final_render.frag',
      );
      _realRefractionReady = true;
      debugPrint(
        '[LiquidGlassProbe] real refraction shader OK '
        '(final_render.frag compiled)',
      );
    } catch (error, stackTrace) {
      _realRefractionReady = false;
      debugPrint(
        '[LiquidGlassProbe] real refraction UNAVAILABLE, '
        'falling back to FakeGlass',
      );
      debugPrint('[LiquidGlassProbe] shader probe error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}

/// Shared [LiquidGlassLayer] host for multiple glass shapes.
///
/// Use this when several sibling surfaces share the same settings (e.g. a
/// small group of menu tiles). Do **not** wrap a full-screen sparse grid —
/// the layer allocates a texture for its entire bounds.
class HyperosLiquidGlassLayer extends StatefulWidget {
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

  /// Blur the backdrop captured at the nearest ancestor [BackdropGroup]
  /// (undimmed page) instead of everything painted below this layer, which
  /// inside a modal would include the dim scrim.
  final bool useBackdropGroup;

  @override
  State<HyperosLiquidGlassLayer> createState() =>
      _HyperosLiquidGlassLayerState();
}

class _HyperosLiquidGlassLayerState extends State<HyperosLiquidGlassLayer> {
  @override
  void initState() {
    super.initState();
    // A shared layer is built before its child surfaces can finish probing the
    // packaged refraction shader. Rebuild the host when the one-shot probe
    // completes; otherwise the initial `fake: true` decision would stick for
    // the lifetime of dense course-card/menu hosts even on Impeller devices.
    LiquidGlassShaderProbe.probeIfNeeded().then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final tuning = FrostedAppearanceScope.of(context).liquidGlassTuning;
    final resolvedSettings =
        widget.settings ??
        HyperosLiquidGlassSurface.settingsForRole(
          role: widget.role,
          brightness: brightness,
          tuning: tuning,
        );
    return LiquidGlassLayer(
      settings: resolvedSettings,
      useBackdropGroup: widget.useBackdropGroup,
      // Opting into fake ourselves on Skia keeps the package from logging a
      // fallback warning on every rebuild. When the refraction shader cannot
      // actually compile (probed once), every layer downgrades to fake too.
      fake: widget.fake || !LiquidGlassShaderProbe.realRefractionReady,
      child: widget.child,
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
/// (`glassContainsChild: false`): labels sit *on top of* the glass, never
/// inside the refracted material. Sheets/headers also get a soft fill under
/// the child so busy backdrops (timetable, photos) do not steal contrast —
/// similar to Apple using thicker / more frosted glass on large panels.
class HyperosLiquidGlassSurface extends StatefulWidget {
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

    /// When true (default), sheet/modal/header roles paint a soft fill under
    /// [child] so multi-line labels stay readable over busy backdrops. Set
    /// false when the caller already manages contrast (e.g. colored course
    /// cards with white text over a hue-tinted glass underlay).
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
  void initState() {
    super.initState();
    // Default every surface to fake until the probe confirms the shader is
    // actually usable; then rebuild once to the real refraction look.
    LiquidGlassShaderProbe.probeIfNeeded().then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.role;
    final borderRadius = widget.borderRadius;
    final clipBehavior = widget.clipBehavior;
    final glassColor = widget.glassColor;
    final instantUnderlay = widget.instantUnderlay;
    final layerMode = widget.layerMode;
    final useAncestorBackdropGroup = widget.useAncestorBackdropGroup;
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

    // Official default: child on top of glass (not tinted/refracted with it).
    // Sheets and modal/header chrome carry dense UI; nested tiles stay pure
    // glass.
    final glassChild = contentLegibilityFill
        ? _wrapChildForLegibility(
            role: role,
            brightness: brightness,
            glassTintAlpha: settings.glassColor.a,
            child: child,
          )
        : child;

    var resolvedLayerMode =
        layerMode ?? HyperosLiquidGlassSurface.defaultLayerModeFor(role);
    if (resolvedLayerMode == HyperosLiquidGlassLayerMode.ownLayer &&
        !LiquidGlassShaderProbe.realRefractionReady) {
      // sharedLayer needs no handling: the package resolves shapes inside a
      // faked ancestor layer to FakeGlass.inLayer without warning.
      resolvedLayerMode = HyperosLiquidGlassLayerMode.fake;
    }

    final Widget liquid = switch (resolvedLayerMode) {
      HyperosLiquidGlassLayerMode.fake => _buildFakeGlass(
        context: context,
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

  static Widget _buildFakeGlass({
    required BuildContext context,
    required LiquidShape shape,
    required LiquidGlassSettings settings,
    required Widget child,
  }) {
    return ClipPath(
      clipper: ShapeBorderClipper(shape: shape),
      child: RawFakeGlass(
        shape: shape,
        settings: settings,
        backdropKey: BackdropGroup.of(context)?.backdropKey,
        child: Opacity(
          opacity: settings.visibility.clamp(0, 1),
          child: GlassGlowLayer(child: child),
        ),
      ),
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
