// The Skia/Impeller fallback is handled by liquid_glass_widgets' AdaptiveGlass
// (premium shader on capable devices, lightweight shader / frosted fallback
// automatically), so no per-process shader probe is needed here anymore.

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../models/liquid_glass_tuning.dart';
import '../frosted/frosted_appearance.dart';
import 'liquid_glass_tokens.dart';

/// App 根 [RepaintBoundary] 的 key（在 main.dart 注册，包住整个应用）。
///
/// 弹窗打开前用它把「未压暗的当前屏幕」抓成静态图像，作为弹窗玻璃的
/// backdrop——玻璃 shader 直接采样这份图像，而不是实时采样 modal dim
/// 压暗后的画面（否则弹窗玻璃显得比页面玻璃脏黑）。
final GlobalKey liquidGlassAppRootBoundaryKey = GlobalKey(
  debugLabel: 'liquid-glass-app-root-boundary',
);

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

/// 弹窗玻璃的「未压暗背景」：打开弹窗前把当前屏幕（Flutter 内容，未被
/// modal dim 压暗）抓成静态图像，经 [_LiquidGlassBackdropCapture] 提供给
/// 弹窗内的液态玻璃作为 shader 的 backdrop（captureImage 路径）。
///
/// 背景：弹窗玻璃（premium shader）通过 BackdropFilter 实时采样其背后
/// 内容——那正是 modal dim（半透明黑）叠加后的画面，所以弹窗玻璃看起来
/// 比页面上的玻璃脏、黑。捕获未压暗页面后，玻璃直接采样这份图像，
/// 观感与页面玻璃一致；dim 仍然只压暗页面本身。
///
/// 图像生命周期：由本宿主持有，随弹窗 route 销毁时 dispose。
class LiquidGlassBackdropCaptureHost extends StatefulWidget {
  const LiquidGlassBackdropCaptureHost({
    super.key,
    required this.image,
    required this.child,
  });

  /// 未压暗屏幕图像；null 表示捕获失败（玻璃回退实时采样）。
  final ui.Image? image;

  final Widget child;

  /// 捕获当前屏幕（app 根 RepaintBoundary，全局逻辑原点 0,0，物理分辨率
  /// = 逻辑尺寸 × dpr，与 shader 的 uCaptureOffset / uSize 约定一致）。
  /// 失败返回 null（弹窗玻璃回退实时 backdrop，观感略暗但可用）。
  static Future<ui.Image?> captureUndimmedScreen() async {
    if (kIsWeb || !HyperosLiquidGlassSurface.supportsRealRefraction) {
      return null;
    }
    final boundary = liquidGlassAppRootBoundaryKey.currentContext
        ?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      return null;
    }
    try {
      final dpr = ui.PlatformDispatcher.instance.views.isEmpty
          ? 1.0
          : ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
      return await boundary.toImage(pixelRatio: dpr);
    } catch (_) {
      // 捕获失败：弹窗玻璃回退实时 backdrop（观感略暗但可用）。
      return null;
    }
  }

  /// 当前捕获的未压暗背景图像（无捕获时为 null）。
  static ui.Image? maybeImageOf(BuildContext context) {
    return _LiquidGlassBackdropCapture.maybeOf(context);
  }

  @override
  State<LiquidGlassBackdropCaptureHost> createState() =>
      _LiquidGlassBackdropCaptureHostState();
}

class _LiquidGlassBackdropCaptureHostState
    extends State<LiquidGlassBackdropCaptureHost> {
  @override
  void dispose() {
    widget.image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _LiquidGlassBackdropCapture(
      image: widget.image,
      child: widget.child,
    );
  }
}

class _LiquidGlassBackdropCapture extends InheritedWidget {
  const _LiquidGlassBackdropCapture({
    required this.image,
    required super.child,
  });

  final ui.Image? image;

  static ui.Image? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_LiquidGlassBackdropCapture>()
        ?.image;
  }

  @override
  bool updateShouldNotify(covariant _LiquidGlassBackdropCapture oldWidget) =>
      image != oldWidget.image;
}

/// 弹窗玻璃的「未压暗背景」垫层。
///
/// 画在玻璃层之下、modal dim 之上：玻璃的 BackdropFilter / shader 采样
/// 到这份未压暗页面图像（不透明，盖住下方的 dim），因此弹窗玻璃与页面
/// 玻璃观感一致；弹窗面板之外的区域仍由 dim 压暗，modal 层次不变。
///
/// 仅当捕获成功（[LiquidGlassBackdropCaptureHost] 提供图像）时绘制；
/// 捕获失败时返回空组件，玻璃回退实时采样（观感略暗但可用）。
class UndimmedBackdropLayer extends StatelessWidget {
  const UndimmedBackdropLayer({super.key, this.radius});

  /// 与玻璃形状一致的圆角（略放大 2px，避免玻璃边缘采样到 dim）。
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final image = LiquidGlassBackdropCaptureHost.maybeImageOf(context);
    if (image == null) {
      return const SizedBox.shrink();
    }
    Widget layer = RawImage(image: image, fit: BoxFit.fill);
    final r = radius;
    if (r != null && r > 0) {
      layer = ClipRRect(
        borderRadius: BorderRadius.circular(r + 2),
        child: layer,
      );
    }
    return Positioned.fill(child: IgnorePointer(child: layer));
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

    final surfacedChild = glassChild;

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

}
