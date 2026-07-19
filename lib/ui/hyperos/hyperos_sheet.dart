import 'package:flutter/material.dart';

import 'hyperos_blurred_header.dart';
import 'hyperos_miuix_spec.dart';
import 'hyperos_theme.dart';
import 'hyperos_tokens.dart';
import 'hyperos_widgets.dart';

/// Marks descendants as sitting on a frosted (blur + milky tint) panel.
///
/// Used by [HyperosButton] secondary fill so cancel / neutral actions stay
/// readable against glass instead of blending into white-on-white.
class HyperosFrostedPanelScope extends InheritedWidget {
  const HyperosFrostedPanelScope({required super.child, super.key});

  static bool of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<HyperosFrostedPanelScope>() !=
        null;
  }

  @override
  bool updateShouldNotify(covariant HyperosFrostedPanelScope oldWidget) {
    return false;
  }
}

/// Visual chrome for [HyperosSheetFrame] / [HyperosSheet].
enum HyperosSheetChrome {
  /// Floating card: left/right/bottom outer gap + full rounded corners.
  /// Matches [HyperosDialog] (settings / form sheets).
  floating,

  /// Edge-flush panel: full width, top corners only, sits on screen bottom.
  /// Preferred for home timetable menus and action sheets.
  edge,
}

/// Provides default [HyperosSheetChrome] for nested [HyperosSheetFrame]s.
class HyperosSheetChromeScope extends InheritedWidget {
  const HyperosSheetChromeScope({
    required this.chrome,
    required super.child,
    super.key,
  });

  final HyperosSheetChrome chrome;

  static HyperosSheetChrome? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<HyperosSheetChromeScope>()
        ?.chrome;
  }

  static HyperosSheetChrome of(BuildContext context) {
    return maybeOf(context) ?? HyperosSheetChrome.floating;
  }

  @override
  bool updateShouldNotify(covariant HyperosSheetChromeScope oldWidget) {
    return chrome != oldWidget.chrome;
  }
}

/// HyperOS bottom sheet panel shell.
///
/// Defaults to frosted glass using [HyperosBlurredHeader.blurSigmaOf] (same
/// strength as 外观与配色). Defaults to [HyperosSheetChrome.floating] unless an
/// ancestor [HyperosSheetChromeScope] or [chrome] overrides it.
class HyperosSheetFrame extends StatelessWidget {
  const HyperosSheetFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
    this.maxHeight,
    this.frosted = true,
    this.chrome,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? maxHeight;

  /// When true (default), milky frosted glass + live blur when enabled in
  /// settings. Sigma / tint / master switch come from [FrostedAppearanceScope].
  final bool frosted;

  /// When null, uses [HyperosSheetChromeScope] or [HyperosSheetChrome.floating].
  final HyperosSheetChrome? chrome;

  @override
  Widget build(BuildContext context) {
    final resolvedChrome = chrome ?? HyperosSheetChromeScope.of(context);
    final panel = switch (resolvedChrome) {
      HyperosSheetChrome.floating => _buildFloatingPanel(context),
      HyperosSheetChrome.edge => _buildEdgePanel(context),
    };

    if (maxHeight == null) {
      return panel;
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight!),
      child: panel,
    );
  }

  Widget _buildFloatingPanel(BuildContext context) {
    final outerInset = HyperosMiuixDialog.outsideMarginHorizontal;
    final bottomSafeInset = MediaQuery.paddingOf(context).bottom;
    final borderRadius = BorderRadius.circular(HyperosTokens.cardRadius);
    final content = Padding(padding: padding, child: child);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        outerInset,
        0,
        outerInset,
        outerInset + bottomSafeInset,
      ),
      child: frosted
          ? _buildFrostedSurface(
              context: context,
              borderRadius: borderRadius,
              content: content,
            )
          : Material(
              color: HyperosColors.surfaceContainer(context),
              shape: HyperosTheme.cardShape(),
              clipBehavior: Clip.antiAlias,
              child: content,
            ),
    );
  }

  Widget _buildEdgePanel(BuildContext context) {
    final borderRadius = BorderRadius.vertical(
      top: Radius.circular(HyperosTokens.cardRadius),
    );
    final content = SafeArea(
      top: false,
      child: Padding(padding: padding, child: child),
    );

    if (frosted) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: SizedBox(
          width: double.infinity,
          child: _buildFrostedSurface(
            context: context,
            borderRadius: borderRadius,
            content: content,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: HyperosColors.scaffoldBackground(context),
        borderRadius: borderRadius,
      ),
      child: content,
    );
  }

  Widget _buildFrostedSurface({
    required BuildContext context,
    required BorderRadius borderRadius,
    required Widget content,
  }) {
    final useBlur = HyperosBlurredHeader.backdropBlurEnabled(context);

    // Blur off → solid opaque panel (no translucent scrim over the page).
    if (!useBlur) {
      return HyperosFrostedPanelScope(
        child: Material(
          color: HyperosColors.surfaceContainer(context),
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
          child: content,
        ),
      );
    }

    final tint = HyperosBlurredHeader.sheetTintColor(context, withBlur: true);

    return HyperosFrostedPanelScope(
      child: ClipRRect(
        borderRadius: borderRadius,
        child: FrostedHeaderBackground(
          blurEnabled: true,
          blurSigma: HyperosBlurredHeader.blurSigmaOf(context),
          tint: tint,
          child: content,
        ),
      ),
    );
  }
}

/// Bottom sheet body with optional title (uses [HyperosSheetFrame] chrome).
class HyperosSheet extends StatelessWidget {
  const HyperosSheet({
    super.key,
    this.title,
    required this.child,
    this.description,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
    this.frosted = true,
    this.chrome,
  });

  final String? title;
  final Widget child;
  final String? description;
  final EdgeInsetsGeometry padding;
  final bool frosted;
  final HyperosSheetChrome? chrome;

  @override
  Widget build(BuildContext context) {
    return HyperosSheetFrame(
      frosted: frosted,
      padding: padding,
      chrome: chrome,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: HyperosTypography.sheetTitle(context)),
            const SizedBox(height: 16),
          ],
          child,
          if (description != null) ...[
            const SizedBox(height: 12),
            HyperosSectionDescription(text: description!),
          ],
        ],
      ),
    );
  }
}

/// Shows a HyperOS-styled modal bottom sheet (replaces Forui `showFSheet`).
///
/// Content should use [HyperosSheetFrame] / [HyperosSheet] / [HyperosDialog].
/// Default chrome is [HyperosSheetChrome.floating] unless [chrome] or a
/// [HyperosSheetChromeScope] says otherwise.
Future<T?> showHyperosSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useRootNavigator = false,
  Color? barrierColor,
  HyperosSheetChrome chrome = HyperosSheetChrome.floating,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useRootNavigator: useRootNavigator,
    backgroundColor: Colors.transparent,
    barrierColor: barrierColor ?? HyperosColors.windowDimming(context),
    builder: (sheetContext) {
      return HyperosSheetChromeScope(
        chrome: chrome,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: builder(sheetContext),
        ),
      );
    },
  );
}

/// Home timetable sheets: edge-flush chrome + lighter barrier.
/// Nested [HyperosSheetFrame]s default to frosted glass.
Future<T?> showHomeHyperosSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useRootNavigator = false,
  Color? barrierColor,
  HyperosSheetChrome chrome = HyperosSheetChrome.edge,
}) {
  return showHyperosSheet<T>(
    context: context,
    builder: builder,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useRootNavigator: useRootNavigator,
    chrome: chrome,
    barrierColor:
        barrierColor ??
        Colors.black.withValues(
          alpha: HyperosBlurredHeader.sheetBarrierAlphaOf(context),
        ),
  );
}
