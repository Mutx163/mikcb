import 'package:flutter/material.dart';

import 'hyperos_blurred_header.dart';
import 'hyperos_miuix_spec.dart';
import 'hyperos_theme.dart';
import 'hyperos_tokens.dart';
import 'hyperos_widgets.dart';
import 'liquid/hyperos_liquid_glass_surface.dart';

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

    final panel = frosted
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
          );

    // BoxShadow creates a dark ring around the panel — visible on all sides,
    // moves with the panel (no tracking), and matches the panel's rounded
    // corners naturally.  The shadow sits BEHIND the frosted glass, so
    // BackdropFilter inside the glass samples the bright page content, not
    // the shadow.
    return Padding(
      padding: EdgeInsets.fromLTRB(
        outerInset,
        0,
        outerInset,
        outerInset + bottomSafeInset,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: panel,
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
    final appearance = FrostedAppearanceScope.of(context);
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

    // Liquid glass mode: real-time refraction shader panel.
    if (appearance.glassMode == FrostedGlassMode.liquidGlass) {
      return HyperosFrostedPanelScope(
        child: HyperosLiquidGlassSurface(
          role: HyperosLiquidGlassRole.sheet,
          borderRadius: borderRadius.topLeft.x,
          instantUnderlay: true,
          child: content,
        ),
      );
    }

    // Frosted / gaussian / translucent: BackdropFilter + tint.
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

/// Bottom velocity threshold to dismiss (pixels/second).
const double _kDismissVelocity = 600.0;

/// Bottom distance threshold to dismiss (fraction of sheet height).
const double _kDismissFraction = 0.3;

/// A wrapper that adds vertical drag-to-dismiss for the sheet content.
///
/// Wraps the sheet content (not the full-screen Align) so that the
/// [LayoutBuilder] measures the actual sheet height, enabling the
/// distance-based dismiss threshold.
///
/// Dragging only translates the panel — the sheet never fades out. An
/// `Opacity` layer here would degrade frosted [BackdropFilter] / liquid glass
/// shaders (the same reason [_SheetSlideUp] avoids animated Opacity), showing
/// as transparency flicker while the panel is dragged down.
class _DragDismissableSheet extends StatefulWidget {
  const _DragDismissableSheet({required this.child});

  final Widget child;

  @override
  State<_DragDismissableSheet> createState() => _DragDismissableSheetState();
}

class _DragDismissableSheetState extends State<_DragDismissableSheet>
    with SingleTickerProviderStateMixin {
  /// Pixel offset the sheet has been dragged down (0 = at rest).
  ///
  /// A [ValueNotifier] instead of `setState`: dragging would otherwise rebuild
  /// the whole frosted / liquid glass subtree on every pointer move. The
  /// notifier only rebuilds the [Transform.translate] layer while the sheet
  /// subtree stays mounted untouched (same pattern as [HyperosPage]).
  final _dragOffset = ValueNotifier<double>(0);
  double _sheetHeight = 0.0;

  late AnimationController _resetController;
  late final CurvedAnimation _resetCurve;
  Animation<double> _resetAnimation = const AlwaysStoppedAnimation<double>(0);

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(vsync: this);
    _resetCurve = CurvedAnimation(
      parent: _resetController,
      curve: Curves.easeOutCubic,
    );
    _resetAnimation = Tween<double>(begin: 0, end: 0).animate(_resetCurve)
      ..addListener(_onResetTick);
  }

  @override
  void dispose() {
    _resetAnimation.removeListener(_onResetTick);
    _resetCurve.dispose();
    _resetController.dispose();
    _dragOffset.dispose();
    super.dispose();
  }

  void _onResetTick() {
    _dragOffset.value = _resetAnimation.value;
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    final dy = details.primaryDelta ?? 0;
    if (dy > 0 || _dragOffset.value > 0) {
      _dragOffset.value = (_dragOffset.value + dy).clamp(0.0, double.infinity);
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    // Dismiss if velocity or distance exceeds threshold.
    if (velocity > _kDismissVelocity ||
        (_sheetHeight > 0 &&
            _dragOffset.value > _sheetHeight * _kDismissFraction)) {
      Navigator.of(context).pop();
      return;
    }

    // Animate back to origin.
    if (_dragOffset.value > 0) {
      final startOffset = _dragOffset.value;
      _resetController.stop();
      _resetAnimation.removeListener(_onResetTick);
      _resetAnimation = Tween<double>(
        begin: startOffset,
        end: 0,
      ).animate(_resetCurve)..addListener(_onResetTick);
      final durationMs =
          (250 * (startOffset / (_sheetHeight > 0 ? _sheetHeight : 300))).clamp(
            100,
            350,
          );
      _resetController
        ..duration = Duration(milliseconds: durationMs.toInt())
        ..forward(from: 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _sheetHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height * 0.5;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          child: ValueListenableBuilder<double>(
            valueListenable: _dragOffset,
            // Kept outside the builder so the sheet subtree (frosted glass /
            // liquid glass shaders) never rebuilds while dragging.
            child: widget.child,
            builder: (context, dragOffset, child) {
              return Transform.translate(
                offset: Offset(0, dragOffset),
                child: child,
              );
            },
          ),
        );
      },
    );
  }
}

/// Internal slide-up animation for sheet entrance. Uses a simple spring on
/// initial build — no route-level transition needed, so frosted glass never
/// sits inside an animated Opacity layer (which breaks LiquidGlass shaders).
class _SheetSlideUp extends StatefulWidget {
  const _SheetSlideUp({required this.child});

  final Widget child;

  @override
  State<_SheetSlideUp> createState() => _SheetSlideUpState();
}

class _SheetSlideUpState extends State<_SheetSlideUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.3),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(position: _slide, child: widget.child);
  }
}

/// Shows a HyperOS-styled modal bottom sheet (replaces Forui `showFSheet`).
///
/// Content should use [HyperosSheetFrame] / [HyperosSheet] / [HyperosDialog].
/// Default chrome is [HyperosSheetChrome.floating] unless [chrome] or a
/// [HyperosSheetChromeScope] says otherwise.
///
/// When [padForKeyboard] is true (default), the sheet is lifted by
/// [MediaQuery.viewInsets] so it sits above the IME. Set it to false when the
/// sheet body manages keyboard avoidance itself (e.g. scroll-to-field).
Future<T?> showHyperosSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useRootNavigator = false,
  bool padForKeyboard = true,
  Color? barrierColor,
  HyperosSheetChrome chrome = HyperosSheetChrome.floating,
}) {
  final dimColor =
      barrierColor ?? HyperosBlurredHeader.modalBarrierColor(context);

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: isDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: dimColor,
    transitionDuration: Duration.zero,
    useRootNavigator: useRootNavigator,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final keyboardInset = padForKeyboard
          ? MediaQuery.viewInsetsOf(dialogContext).bottom
          : 0.0;
      final sheetContent = HyperosSheetChromeScope(
        chrome: chrome,
        child: builder(dialogContext),
      );

      // Wrap drag-to-dismiss around the sheet content (not the full-screen
      // Align) so LayoutBuilder measures the actual sheet height.
      final sheet = enableDrag
          ? _DragDismissableSheet(child: sheetContent)
          : sheetContent;

      return _SheetSlideUp(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: keyboardInset),
            child: sheet,
          ),
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
  bool padForKeyboard = true,
  Color? barrierColor,
  HyperosSheetChrome chrome = HyperosSheetChrome.edge,
}) {
  return showHyperosSheet<T>(
    context: context,
    builder: builder,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useRootNavigator: useRootNavigator,
    padForKeyboard: padForKeyboard,
    chrome: chrome,
    barrierColor:
        barrierColor ??
        Colors.black.withValues(
          alpha: HyperosBlurredHeader.sheetBarrierAlphaOf(context),
        ),
  );
}
