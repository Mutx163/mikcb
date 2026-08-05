import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'frosted/frosted_appearance.dart';
import 'frosted/frosted_header_background.dart';
import 'frosted/liquid_glass_degradation.dart';
export 'frosted/frosted_appearance.dart';
export 'frosted/frosted_header_background.dart'
    show FrostedHeaderBackground, HyperosFrostedSurface;
// HyperosFrostedPanelScope is exported via frosted_appearance.dart above.
import 'hyperos_miuix_spec.dart';
import 'hyperos_theme.dart';
import 'liquid/hyperos_liquid_glass_surface.dart';

/// Scope for pages that overlay a frosted [FHeader] on scrollable content.
class HyperosBlurredHeaderScope extends InheritedWidget {
  const HyperosBlurredHeaderScope({
    required this.contentTopInset,
    this.blurEnabled = true,
    this.contentUnderHeader = false,
    this.headerBackgroundColor,
    required super.child,
    super.key,
  });

  /// Extra top inset applied to page body so content starts below the header.
  final double contentTopInset;

  /// When false, header shows tint only (no [BackdropFilter]).
  final bool blurEnabled;

  /// When true, list content has scrolled under the header — show frosted blur.
  final bool contentUnderHeader;

  /// Opaque header fill while [contentUnderHeader] is false (matches page bg).
  final Color? headerBackgroundColor;

  static HyperosBlurredHeaderScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<HyperosBlurredHeaderScope>();
  }

  static double insetOf(BuildContext context) {
    return maybeOf(context)?.contentTopInset ?? 0;
  }

  /// Reads [contentTopInset] WITHOUT registering an inherited dependency.
  ///
  /// Must be used from [ScrollBehavior.getScrollPhysics]: that runs inside
  /// `Scrollable._updatePosition` with the Scrollable's own context, so a
  /// `dependOnInheritedWidgetOfExactType` there subscribes the Scrollable
  /// element to this scope — every frost flip / inset change then triggers
  /// `didChangeDependencies → _updatePosition`, which tears down and
  /// recreates the ScrollPosition mid-gesture (pixels silently reset to 0,
  /// title flickers). See the collapse/frost regression on short pages.
  static double insetOfUntracked(BuildContext context) {
    final scope = context
        .getInheritedWidgetOfExactType<HyperosBlurredHeaderScope>();
    return scope?.contentTopInset ?? 0;
  }

  static bool blurEnabledOf(BuildContext context) {
    return maybeOf(context)?.blurEnabled ?? true;
  }

  static bool contentUnderHeaderOf(BuildContext context) {
    return maybeOf(context)?.contentUnderHeader ?? false;
  }

  static Color? headerBackgroundColorOf(BuildContext context) {
    return maybeOf(context)?.headerBackgroundColor;
  }

  @override
  bool updateShouldNotify(HyperosBlurredHeaderScope oldWidget) {
    return contentTopInset != oldWidget.contentTopInset ||
        blurEnabled != oldWidget.blurEnabled ||
        contentUnderHeader != oldWidget.contentUnderHeader ||
        headerBackgroundColor != oldWidget.headerBackgroundColor;
  }
}

/// Layout helpers for HyperOS frosted top app bars.
abstract final class HyperosBlurredHeader {
  /// Fallback blur sigma when no [FrostedAppearanceScope] is available.
  static const blurSigma = kDefaultFrostedSheetBlurSigma;

  /// Tint-only scrim while blur is paused (route transition).
  static const lightTintOnlyAlpha = 0.58;

  static const darkTintOnlyAlpha = 0.62;

  /// Live [BackdropFilter] blur on mobile; web uses tint-only.
  static bool get liveBlurSupported {
    if (kIsWeb) {
      return false;
    }
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Approximate body top inset matching [FHeader] + [SafeArea] on HyperOS pages.
  static double contentTopInset(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    const headerPaddingBottom = 4.0;
    const minHeaderHeight = 44.0;
    return safeTop + minHeaderHeight + headerPaddingBottom;
  }

  /// Approximate body top inset for expanded [HyperosCollapsibleTopAppBar]
  /// before the overlay header is measured (safe top + collapsed row + large title).
  static double contentTopInsetCollapsible(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    // Match expanded layout: action row + large title 1 line + bottom pad,
    // plus the app-side title→content gap (see largeTitleContentGap).
    const expandedContentHeight =
        HyperosMiuixTopAppBar.collapsedHeight +
        HyperosMiuixTypography.title1 * 1.2 +
        HyperosMiuixTopAppBar.largeTitleBottomPadding +
        HyperosMiuixTopAppBar.largeTitleContentGap;
    return safeTop + expandedContentHeight;
  }

  /// Default vertical size for a single-line [HyperosBlurredHeaderExtension]
  /// row (padding + ~48dp field) before the overlay header is measured.
  static const defaultExtensionHeight = 68.0;

  /// Body inset when a [HyperosBlurredHeaderExtension] is pinned under the bar.
  static double contentTopInsetWithExtension(
    BuildContext context, {
    double extensionHeight = defaultExtensionHeight,
  }) {
    return contentTopInset(context) + extensionHeight;
  }

  /// Miuix collapsed top bar content height (excluding status bar).
  static const contentHeight = HyperosMiuixTopAppBar.collapsedHeight;

  static FrostedAppearance _appearanceOf(BuildContext context) {
    return FrostedAppearanceScope.of(context);
  }

  static double blurSigmaOf(BuildContext context) {
    return _appearanceOf(context).sheetBlurSigma;
  }

  static double sheetBarrierAlphaOf(BuildContext context) {
    return _appearanceOf(context).sheetBarrierAlpha;
  }

  /// Soft black dim behind liquid-glass modals (sheets, select popups, dialogs).
  ///
  /// Stronger scrims muddy refraction because the glass samples through the
  /// barrier. Fully transparent barriers make the modal hard to spot as a
  /// modal. Keep this lighter than the gaussian default (~0.20).
  static const liquidGlassModalBarrierAlpha = 0.10;

  /// Modal scrim shared by home menu, sheets, dialogs, and select popups.
  ///
  /// - **Gaussian**: black scrim from [FrostedAppearance.sheetBarrierAlpha]
  ///   (外观与配色), matching the home top-right menu.
  /// - **Liquid glass**: fixed light dim ([liquidGlassModalBarrierAlpha]).
  ///   Just enough hierarchy that every popup reads as the same modal, without
  ///   a heavy grey wash that flattens the refractive glass.
  static Color modalBarrierColor(BuildContext context) {
    final appearance = _appearanceOf(context);
    // Keep the liquid-glass light scrim only while the real refractive glass
    // is in use; once the system degrades glass to a solid (accessibility /
    // reduce-motion / high-contrast), the heavier gaussian scrim gives the
    // now-opaque modal the hierarchy it needs.
    if (appearance.glassMode == FrostedGlassMode.liquidGlass &&
        !LiquidGlassDegradation.shouldDegrade(context)) {
      return Colors.black.withValues(alpha: liquidGlassModalBarrierAlpha);
    }
    return Colors.black.withValues(alpha: sheetBarrierAlphaOf(context));
  }

  /// Whether live [BackdropFilter] blur is allowed (platform + user setting).
  ///
  /// Disabled by [LiquidGlassDegradation] (accessibility / reduce-motion /
  /// high-contrast) so every frosted / gaussian / translucent surface falls
  /// back to its solid material in one place.
  static bool backdropBlurEnabled(BuildContext context) {
    if (LiquidGlassDegradation.shouldDegrade(context)) {
      return false;
    }
    return liveBlurSupported && _appearanceOf(context).blurEnabled;
  }

  static Color tintColor(BuildContext context, {required bool withBlur}) {
    if (!withBlur) {
      final pageBackground = HyperosColors.scaffoldBackground(context);
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return pageBackground.withValues(
        alpha: isDark ? darkTintOnlyAlpha : lightTintOnlyAlpha,
      );
    }
    return _frostedScrimColor(context);
  }

  /// Shared frosted scrim for subpage headers, sheets, and menus.
  static Color _frostedScrimColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final alpha = _appearanceOf(context).sheetTintAlpha;
    if (isDark) {
      return HyperosColors.scaffoldBackground(
        context,
      ).withValues(alpha: (alpha * 0.55 + 0.10).clamp(0.22, 0.72));
    }
    return Colors.white.withValues(alpha: alpha);
  }

  /// Frosted bottom sheet / dialog panel tint.
  ///
  /// When [withBlur] is true: milky translucent glass (sigma from settings).
  /// When [withBlur] is false: **fully opaque** surface — never a see-through
  /// panel (Gaussian blur off must not leave transparent sheets).
  static Color sheetTintColor(BuildContext context, {required bool withBlur}) {
    if (!withBlur) {
      return HyperosColors.surfaceContainer(context);
    }
    return _frostedScrimColor(context);
  }

  /// Frosted tint for nested surfaces (menu tiles, chips) over a frosted parent.
  static Color nestedSurfaceTintColor(
    BuildContext context, {
    required bool withBlur,
    Color? base,
  }) {
    if (!withBlur) {
      // Parent may be liquid glass or solid. Prefer a translucent wash so nested
      // icon wells never punch opaque blocks through the panel.
      final isDark = Theme.of(context).brightness == Brightness.dark;
      if (isDark) {
        return Colors.white.withValues(alpha: 0.10);
      }
      return Colors.black.withValues(alpha: 0.05);
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) {
      final parentAlpha = _appearanceOf(context).sheetTintAlpha;
      return Colors.white.withValues(
        alpha: (parentAlpha * 0.55 + 0.18).clamp(0.22, 0.72),
      );
    }
    final surface = base ?? HyperosColors.card(context);
    return surface.withValues(alpha: 0.52);
  }

  /// Nested tile wash when the parent sheet already uses liquid glass.
  ///
  /// Must stay translucent — solid secondaryVariant reads as dead blocks.
  static Color nestedLiquidTileTintColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return Colors.white.withValues(alpha: 0.12);
    }
    return Colors.white.withValues(alpha: 0.28);
  }

  /// Frosted tint for home timetable regions over a full-screen backdrop.
  ///
  /// Uses a milky scrim so blur reads on both light and dark photos; the generic
  /// [tintColor] scrim is too dark and low-contrast on dark wallpapers.
  static Color homePageRegionTintColor(
    BuildContext context, {
    required bool withBlur,
  }) {
    if (!withBlur) {
      return tintColor(context, withBlur: false);
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return Colors.white.withValues(alpha: 0.20);
    }
    final alpha = (_appearanceOf(context).sheetTintAlpha * 0.85 + 0.14).clamp(
      0.30,
      0.68,
    );
    return Colors.white.withValues(alpha: alpha);
  }

  /// Light accent wash for icon wells on an already-frosted tile.
  ///
  /// Do not stack another [BackdropFilter] here — nested blur on a tinted
  /// parent reads muddy/dark. Pair with [HyperosFrostedSurface.blurEnabled:
  /// false].
  static Color accentSurfaceTintColor(Color accent) {
    return accent.withValues(alpha: 0.12);
  }
}

/// Frosted header chrome: [BackdropFilter] blur + tint + title row.
class HyperosBlurredHeaderShell extends StatelessWidget {
  const HyperosBlurredHeaderShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = HyperosBlurredHeaderScope.maybeOf(context);
    final routeBlur = scope?.blurEnabled ?? true;
    final underHeader = scope?.contentUnderHeader ?? true;
    final useBlur =
        HyperosBlurredHeader.backdropBlurEnabled(context) &&
        routeBlur &&
        underHeader;
    final atRestColor =
        scope?.headerBackgroundColor ??
        HyperosColors.scaffoldBackground(context);
    final tint = useBlur
        ? HyperosBlurredHeader.tintColor(context, withBlur: true)
        : atRestColor;

    if (useBlur &&
        FrostedAppearanceScope.of(context).glassMode ==
            FrostedGlassMode.liquidGlass) {
      return HyperosLiquidGlassSurface(
        role: HyperosLiquidGlassRole.header,
        instantUnderlay: true,
        child: child,
      );
    }

    return HyperosFrostedHeaderShell(
      blurEnabled: useBlur,
      tint: tint,
      child: child,
    );
  }
}

/// Pads widgets pinned directly under the frosted title row inside the same
/// [HyperosBlurredHeaderShell] (search bars, segmented filters, etc.).
class HyperosBlurredHeaderExtension extends StatelessWidget {
  const HyperosBlurredHeaderExtension({
    super.key,
    required this.child,
    this.padding = defaultPadding,
  });

  static const defaultPadding = EdgeInsets.fromLTRB(16, 8, 16, 12);

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(padding: padding, child: child);
  }
}

/// Pads non-scroll page bodies below a frosted header overlay.
class HyperosBlurredBodyInset extends StatelessWidget {
  const HyperosBlurredBodyInset({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inset = HyperosBlurredHeaderScope.insetOf(context);
    if (inset == 0) {
      return child;
    }
    return Padding(
      padding: EdgeInsets.only(top: inset),
      child: child,
    );
  }
}
