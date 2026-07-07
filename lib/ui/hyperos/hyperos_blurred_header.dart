import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../models/timetable_settings.dart';
import 'frosted/frosted_appearance.dart';
import 'frosted/frosted_header_background.dart';
export 'frosted/frosted_appearance.dart';
export 'frosted/frosted_sheet_settings_preview.dart';
export 'frosted/frosted_header_background.dart'
    show FrostedHeaderBackground, HyperosFrostedSurface;
import 'hyperos_miuix_spec.dart';
import 'hyperos_theme.dart';

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
  static const blurSigma = TimetableSettings.defaultFrostedSheetBlurSigma;

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

  /// Whether live [BackdropFilter] blur is allowed (platform + user setting).
  static bool backdropBlurEnabled(BuildContext context) {
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

  /// Frosted bottom sheet panel tint. Light mode uses a milky white overlay so
  /// blur reads as bright frosted glass; dark mode keeps a surface scrim.
  static Color sheetTintColor(BuildContext context, {required bool withBlur}) {
    if (!withBlur) {
      return tintColor(context, withBlur: false);
    }
    return _frostedScrimColor(context);
  }

  /// Frosted tint for nested surfaces (menu tiles, chips) over a frosted parent.
  static Color nestedSurfaceTintColor(
    BuildContext context, {
    required bool withBlur,
    Color? base,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark && withBlur) {
      final parentAlpha = _appearanceOf(context).sheetTintAlpha;
      return Colors.white.withValues(
        alpha: (parentAlpha * 0.55 + 0.18).clamp(0.22, 0.72),
      );
    }
    final surface = base ?? HyperosColors.card(context);
    final tintAlpha = withBlur
        ? (isDark ? 0.52 : 0.48)
        : (isDark ? darkTintOnlyAlpha : lightTintOnlyAlpha);
    return surface.withValues(alpha: tintAlpha);
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
