import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'frosted/frosted_header_background.dart';
import 'hyperos_header_diag.dart';
import 'hyperos_miuix_spec.dart';
import 'hyperos_theme.dart';

import 'frosted/frosted_header_controller.dart';

/// Scope for pages that overlay a frosted [FHeader] on scrollable content.
class HyperosBlurredHeaderScope extends InheritedWidget {
  const HyperosBlurredHeaderScope({
    required this.contentTopInset,
    this.blurEnabled = true,
    this.frostedController,
    required super.child,
    super.key,
  });

  /// Extra top inset applied to page body so content starts below the header.
  final double contentTopInset;

  /// When false, header shows tint only (no cached blur image).
  final bool blurEnabled;

  /// CFH capture controller for overlay / scaffold pages.
  final FrostedHeaderController? frostedController;

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

  static FrostedHeaderController? frostedControllerOf(BuildContext context) {
    return maybeOf(context)?.frostedController;
  }

  @override
  bool updateShouldNotify(HyperosBlurredHeaderScope oldWidget) {
    return contentTopInset != oldWidget.contentTopInset ||
        blurEnabled != oldWidget.blurEnabled ||
        frostedController != oldWidget.frostedController;
  }
}

/// Layout helpers for HyperOS frosted top app bars (CFH).
abstract final class HyperosBlurredHeader {
  /// Visual blur strength (maps to native radius / Dart sigma).
  static const blurSigma = 10.0;

  /// Translucent scrim alpha over the blurred backdrop (light mode).
  static const lightTintAlpha = 0.42;

  /// Translucent scrim alpha over the blurred backdrop (dark mode).
  static const darkTintAlpha = 0.40;

  /// Tint-only scrim while blur is paused (route transition).
  static const lightTintOnlyAlpha = 0.58;

  static const darkTintOnlyAlpha = 0.62;

  /// CFH live blur: Android only (native RenderEffect or Dart fallback on snapshot).
  /// iOS and web use tint-only per product scope.
  static bool get liveBlurSupported {
    if (kIsWeb) {
      return false;
    }
    return Platform.isAndroid;
  }

  /// Approximate body top inset matching [FHeader] + [SafeArea] on HyperOS pages.
  static double contentTopInset(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    const headerPaddingBottom = 4.0;
    const minHeaderHeight = 44.0;
    return safeTop + minHeaderHeight + headerPaddingBottom;
  }

  /// Miuix collapsed top bar content height (excluding status bar).
  static const contentHeight = HyperosMiuixTopAppBar.collapsedHeight;

  static Color tintColor(BuildContext context, {required bool withBlur}) {
    final pageBackground = HyperosColors.scaffoldBackground(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tintAlpha = withBlur
        ? (isDark ? darkTintAlpha : lightTintAlpha)
        : (isDark ? darkTintOnlyAlpha : lightTintOnlyAlpha);
    return pageBackground.withValues(alpha: tintAlpha);
  }
}

/// Frosted header chrome: cached blur image + tint + title row.
class HyperosBlurredHeaderShell extends StatelessWidget {
  const HyperosBlurredHeaderShell({
    required this.child,
    this.blurredImage,
    super.key,
  });

  final Widget child;
  final ui.Image? blurredImage;

  @override
  Widget build(BuildContext context) {
    final scopeBlur = HyperosBlurredHeaderScope.blurEnabledOf(context);
    final useBlur = HyperosBlurredHeader.liveBlurSupported && scopeBlur;

    HyperosHeaderDiag.log('shell_build', {
      'scopeBlur': scopeBlur,
      'useBlur': useBlur,
      'mode': useBlur ? 'cfh_blur+tint' : 'tint-only',
      'hasImage': blurredImage != null,
      'sigma': HyperosBlurredHeader.blurSigma,
    });

    return HyperosFrostedHeaderShell(blurredImage: blurredImage, child: child);
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
