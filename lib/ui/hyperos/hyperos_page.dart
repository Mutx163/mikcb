import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/scheduler.dart';
import 'package:forui/forui.dart';

import 'hyperos_blurred_header.dart';
import 'hyperos_header_diag.dart';
import 'hyperos_overscroll.dart';
import 'hyperos_overlay_header.dart';
import 'hyperos_theme.dart';
import 'hyperos_tokens.dart';
import 'hyperos_widgets.dart';

/// Root settings page without a back button (HyperOS settings home pattern).
class HyperosRootPage extends StatelessWidget {
  const HyperosRootPage({
    super.key,
    required this.title,
    required this.child,
    this.suffixes,
    this.childPad = false,
    this.backgroundColor,
    this.headerDecoration,
    this.headerStyle,
    this.resizeToAvoidBottomInset = true,
    this.overlayHeader = true,
  });

  final Widget title;
  final Widget child;
  final List<Widget>? suffixes;
  final bool childPad;
  final Color? backgroundColor;
  final BoxDecoration? headerDecoration;
  final FHeaderStyleDelta? headerStyle;
  final bool resizeToAvoidBottomInset;

  /// When false, the header stacks above content (no blur overlay). Use for
  /// pages like the main timetable where the body must not sit under the bar.
  final bool overlayHeader;

  @override
  Widget build(BuildContext context) {
    return _HyperosBlurredPage(
      childPad: childPad,
      backgroundColor: backgroundColor,
      headerDecoration: headerDecoration,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      overlayHeader: overlayHeader,
      header: FHeader(
        style: headerStyle ?? HyperosTheme.nestedHeaderStyle(context),
        suffixes: suffixes ?? const [],
        title: title,
      ),
      child: child,
    );
  }
}

/// Wraps [FScaffold] + blurred top bar.
///
/// [HyperosSubpage] defaults to overlay layout so [BackdropFilter] can sample
/// scrollable content under the header (settings home and sub-routes).
class HyperosSubpage extends StatelessWidget {
  const HyperosSubpage({
    super.key,
    required this.title,
    required this.child,
    this.onBack,
    this.prefixes,
    this.suffixes,
    this.childPad = false,
    this.overlayHeader = true,
  });

  final Widget title;
  final Widget child;
  final VoidCallback? onBack;
  final List<Widget>? prefixes;
  final List<Widget>? suffixes;
  final bool childPad;

  /// When true, the header floats above scrollable content for live backdrop blur.
  /// Set false only when the body must not scroll under the bar.
  final bool overlayHeader;

  @override
  Widget build(BuildContext context) {
    return _HyperosBlurredPage(
      childPad: childPad,
      overlayHeader: overlayHeader,
      header: HyperosOverlayNestedHeader(
        prefixes:
            prefixes ??
            [if (onBack != null) FHeaderAction.back(onPress: onBack!)],
        suffixes: suffixes ?? const [],
        title: title,
      ),
      child: child,
    );
  }
}

class _HyperosBlurredPage extends StatefulWidget {
  const _HyperosBlurredPage({
    required this.header,
    required this.child,
    required this.childPad,
    this.backgroundColor,
    this.headerDecoration,
    this.resizeToAvoidBottomInset = true,
    this.overlayHeader = true,
  });

  final Widget header;
  final Widget child;
  final bool childPad;
  final Color? backgroundColor;
  final BoxDecoration? headerDecoration;
  final bool resizeToAvoidBottomInset;
  final bool overlayHeader;

  @override
  State<_HyperosBlurredPage> createState() => _HyperosBlurredPageState();
}

class _HyperosBlurredPageState extends State<_HyperosBlurredPage> {
  static const _blurSettleDelay = Duration(milliseconds: 350);

  bool _blurSettled = false;
  Timer? _blurSettleTimer;
  Animation<double>? _routeAnimation;
  Animation<double>? _secondaryRouteAnimation;
  VoidCallback? _routeAnimationListener;
  AnimationStatusListener? _routeAnimationStatusListener;
  bool? _diagLastTransitioning;
  bool? _diagLastIsCurrent;

  @override
  void initState() {
    super.initState();
  }

  /// Whether this page uses the overlay (stacked header) layout structure.
  bool get _useOverlayLayout => widget.overlayHeader;

  /// Live backdrop blur on overlay-header pages (see [_blurReady] for gates).
  bool get _liveBlurActive => widget.overlayHeader;

  /// [BackdropFilter] enabled after route settle on overlay pages.
  bool get _backdropBlurEnabled => _liveBlurActive && _blurReady;

  double get _animationValue => _routeAnimation?.value ?? 1.0;

  double get _secondaryAnimationValue => _secondaryRouteAnimation?.value ?? 0.0;

  bool get _isRouteCurrent => ModalRoute.of(context)?.isCurrent ?? true;

  bool get _isRouteTransitioning => hyperosIsRouteTransitioning(
    animationValue: _animationValue,
    secondaryAnimationValue: _secondaryAnimationValue,
    isRouteCurrent: _isRouteCurrent,
  );

  /// Backdrop blur gate after route settle. Modal overlays (sheet / dialog) keep
  /// blur on the page below; only full-page slide transitions pause it.
  bool get _blurReady => !_isRouteTransitioning && _blurSettled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    final animation = route?.animation;
    final secondary = route?.secondaryAnimation;
    if (animation == _routeAnimation && secondary == _secondaryRouteAnimation) {
      return;
    }
    _detachRouteListeners();
    _routeAnimation = animation;
    _secondaryRouteAnimation = secondary;
    _diagLastTransitioning = null;
    _diagLastIsCurrent = null;

    void sync() => _syncRouteTransitioning();
    _routeAnimationListener = sync;
    animation?.addListener(sync);
    secondary?.addListener(sync);

    void onAnimationStatus(AnimationStatus status) {
      if (!mounted || !_isRouteCurrent) {
        return;
      }
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        _syncRouteTransitioning();
        _scheduleBlurSettle();
      }
    }

    _routeAnimationStatusListener = onAnimationStatus;
    animation?.addStatusListener(onAnimationStatus);

    _syncRouteTransitioning();
    _scheduleBlurSettle();
  }

  void _cancelBlurSettle() {
    _blurSettleTimer?.cancel();
    _blurSettleTimer = null;
  }

  void _scheduleBlurSettle() {
    _cancelBlurSettle();
    if (_isRouteTransitioning) {
      if (_blurSettled && mounted) {
        setState(() => _blurSettled = false);
      } else {
        _blurSettled = false;
      }
      return;
    }
    _blurSettleTimer = Timer(_blurSettleDelay, () {
      if (!mounted || _isRouteTransitioning) {
        return;
      }
      HyperosHeaderDiag.log('blur_settle', {'blurSettled': true});
      setState(() => _blurSettled = true);
    });
  }

  void _maybeLogRouteTransition({
    required bool transitioning,
    required bool isCurrent,
  }) {
    if (_diagLastTransitioning == transitioning &&
        _diagLastIsCurrent == isCurrent) {
      return;
    }
    _diagLastTransitioning = transitioning;
    _diagLastIsCurrent = isCurrent;

    // Background routes only matter when transition edges change.
    if (!isCurrent && transitioning) {
      return;
    }

    HyperosHeaderDiag.log('route_transition', {
      'isRouteTransitioning': transitioning,
      'isRouteCurrent': isCurrent,
      if (isCurrent) ...{
        'liveBlurActive': _liveBlurActive,
        'useOverlayLayout': _useOverlayLayout,
      },
      'animationValue': _animationValue,
      'secondaryAnimationValue': _secondaryAnimationValue,
    });
  }

  void _syncRouteTransitioning() {
    final transitioning = _isRouteTransitioning;
    final isCurrent = _isRouteCurrent;

    if (transitioning) {
      _cancelBlurSettle();
      if (_blurSettled && mounted) {
        setState(() => _blurSettled = false);
      } else {
        _blurSettled = false;
      }
      if (isCurrent && mounted) {
        _maybeLogRouteTransition(transitioning: true, isCurrent: true);
        setState(() {});
      } else {
        _maybeLogRouteTransition(transitioning: true, isCurrent: false);
      }
      return;
    }

    if (!isCurrent) {
      _maybeLogRouteTransition(transitioning: false, isCurrent: false);
      if (!_blurSettled) {
        _scheduleBlurSettle();
      }
      return;
    }

    _maybeLogRouteTransition(transitioning: false, isCurrent: true);
    _scheduleBlurSettle();
    if (mounted) {
      setState(() {});
    }
  }

  void _detachRouteListeners() {
    final listener = _routeAnimationListener;
    if (listener != null) {
      _routeAnimation?.removeListener(listener);
      _secondaryRouteAnimation?.removeListener(listener);
    }
    _routeAnimationListener = null;

    final statusListener = _routeAnimationStatusListener;
    if (statusListener != null) {
      _routeAnimation?.removeStatusListener(statusListener);
    }
    _routeAnimationStatusListener = null;
  }

  @override
  void dispose() {
    _cancelBlurSettle();
    _detachRouteListeners();
    super.dispose();
  }

  Widget _buildHeaderShell(Widget header, Color pageBackground) {
    if (!widget.overlayHeader) {
      // Stacked headers (e.g. timetable home) use a solid bar; frosted tint
      // is based on HyperosColors.scaffoldBackground and mismatches custom
      // page backgrounds in the status-bar inset above FHeader SafeArea.
      final headerDecoration = widget.headerDecoration;
      if (headerDecoration != null) {
        return DecoratedBox(decoration: headerDecoration, child: header);
      }
      return ColoredBox(color: pageBackground, child: header);
    }
    return HyperosBlurredHeaderShell(child: header);
  }

  Widget _buildBody({required Color pageBackground, required Widget child}) {
    return Material(
      type: MaterialType.transparency,
      color: pageBackground,
      child: child,
    );
  }

  Widget _buildScaffoldHeaderLayout(Color pageBackground) {
    final blurredHeader = _buildHeaderShell(widget.header, pageBackground);
    final header = HyperosBlurredHeaderScope(
      contentTopInset: 0,
      blurEnabled: _backdropBlurEnabled,
      child: blurredHeader,
    );
    return FScaffold(
      resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
      scaffoldStyle: FScaffoldStyleDelta.delta(
        backgroundColor: pageBackground,
        systemOverlayStyle: HyperosColors.systemOverlayForBackground(
          pageBackground,
        ),
      ),
      header: header,
      childPad: widget.childPad,
      child: _buildBody(pageBackground: pageBackground, child: widget.child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageBackground =
        widget.backgroundColor ?? HyperosColors.scaffoldBackground(context);

    if (!_useOverlayLayout) {
      return _buildScaffoldHeaderLayout(pageBackground);
    }

    final blurredHeader = _buildHeaderShell(widget.header, pageBackground);
    final headerInset = HyperosBlurredHeader.contentTopInset(context);

    return FScaffold(
      resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
      scaffoldStyle: FScaffoldStyleDelta.delta(backgroundColor: pageBackground),
      childPad: widget.childPad,
      child: HyperosBlurredHeaderScope(
        contentTopInset: headerInset,
        blurEnabled: _backdropBlurEnabled,
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: _buildBody(
                pageBackground: pageBackground,
                child: widget.child,
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  if (!width.isFinite || width <= 0) {
                    HyperosHeaderDiag.log('header_skipped', {
                      'reason': 'invalid_width',
                      'maxWidth': width,
                    });
                    return const SizedBox.shrink();
                  }
                  return SizedBox(width: width, child: blurredHeader);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Whether a HyperOS page route is mid transition.
///
/// On the **current** (top) route, only the primary enter/exit animation
/// matters. [secondaryAnimation] tracks the route below and must not block
/// blur or body on the pushed page (fixes permanent blank sub-page body).
///
/// On a **covered** route, [secondaryAnimation] indicates a sub-page is sliding
/// over — skip expensive rebuilds while it runs.
@visibleForTesting
bool hyperosIsRouteTransitioning({
  required double animationValue,
  required double secondaryAnimationValue,
  bool isRouteCurrent = true,
}) {
  if (isRouteCurrent) {
    return !hyperosIsIncomingRouteSettled(animationValue: animationValue);
  }
  return secondaryAnimationValue > 0.001;
}

/// Whether the pushed route's own enter animation has finished.
@visibleForTesting
bool hyperosIsIncomingRouteSettled({required double animationValue}) {
  return animationValue >= 0.999;
}

/// Scrollable HyperOS settings list with standard page padding.
///
/// Provide either [children] (light pages) or [itemCount] + [itemBuilder] for
/// lazy per-section construction on heavy settings subpages.
class HyperosListView extends StatefulWidget {
  const HyperosListView({
    super.key,
    this.children,
    this.itemCount,
    this.itemBuilder,
    this.padding,
    this.includeHeaderInset = true,
    this.pageStorageKey,
  }) : assert(
         (children != null) ^ (itemCount != null && itemBuilder != null),
         'Provide either children or itemCount+itemBuilder',
       );

  final List<Widget>? children;
  final int? itemCount;
  final IndexedWidgetBuilder? itemBuilder;
  final EdgeInsetsGeometry? padding;

  /// When false, skip overlay-header top inset (e.g. a fixed preview above the
  /// list already clears the frosted bar via [HyperosBlurredBodyInset]).
  final bool includeHeaderInset;

  /// Restores scroll offset when the list is rebuilt (e.g. after route pop).
  final PageStorageKey<String>? pageStorageKey;

  @override
  State<HyperosListView> createState() => _HyperosListViewState();
}

class _HyperosListViewState extends State<HyperosListView> {
  bool _isUserScrolling = false;
  int _pressHighlightGeneration = 0;

  void _setScrollState(VoidCallback update) {
    if (!mounted) {
      return;
    }
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle) {
      setState(update);
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(update);
    });
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      _setScrollState(() => _pressHighlightGeneration++);
    }
    if (notification is UserScrollNotification) {
      final scrolling = notification.direction != ScrollDirection.idle;
      if (_isUserScrolling != scrolling) {
        _setScrollState(() => _isUserScrolling = scrolling);
      }
    }
    if (notification is ScrollEndNotification && _isUserScrolling) {
      _setScrollState(() => _isUserScrolling = false);
    }
    return false;
  }

  EdgeInsets _resolveListPadding(BuildContext context) {
    final base = (widget.padding ?? HyperosTokens.listPadding).resolve(
      Directionality.of(context),
    );
    // Initial content sits below the overlay header; scrolling still passes
    // rows under the frosted bar once this padding scrolls away.
    if (!widget.includeHeaderInset) {
      return base;
    }
    final headerInset = HyperosBlurredHeaderScope.insetOf(context);
    if (headerInset <= 0) {
      return base;
    }
    return EdgeInsets.fromLTRB(
      base.left,
      base.top + headerInset,
      base.right,
      base.bottom,
    );
  }

  @override
  Widget build(BuildContext context) {
    final children = widget.children;
    final resolvedItemCount = children?.length ?? widget.itemCount!;
    final resolvedItemBuilder =
        widget.itemBuilder ?? (context, index) => children![index];

    final listKey = widget.pageStorageKey ?? _pageStorageKeyFromRoute(context);

    return HyperosListScrollScope(
      isUserScrolling: _isUserScrolling,
      pressHighlightGeneration: _pressHighlightGeneration,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScroll,
        child: ListView.builder(
          key: listKey,
          physics: const HyperosOverscrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: _resolveListPadding(context),
          itemCount: resolvedItemCount,
          itemBuilder: resolvedItemBuilder,
        ),
      ),
    );
  }

  PageStorageKey<String>? _pageStorageKeyFromRoute(BuildContext context) {
    final name = ModalRoute.of(context)?.settings.name;
    if (name == null || name.isEmpty) {
      return null;
    }
    return PageStorageKey<String>('hyperos-list-$name');
  }
}

/// Gray rounded bottom sheet container (no title row).
class HyperosSheetFrame extends StatelessWidget {
  const HyperosSheetFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
    this.maxHeight,
    this.frosted = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? maxHeight;

  /// When true, samples the page behind the sheet with [BackdropFilter] blur
  /// and a translucent tint (same frosted stack as [HyperosBlurredHeader]).
  final bool frosted;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.vertical(
      top: Radius.circular(HyperosTokens.cardRadius),
    );
    final content = SafeArea(
      top: false,
      child: Padding(padding: padding, child: child),
    );

    if (frosted) {
      final useBlur = HyperosBlurredHeader.backdropBlurEnabled(context);
      final tint = HyperosBlurredHeader.sheetTintColor(
        context,
        withBlur: useBlur,
      );

      return ClipRRect(
        borderRadius: borderRadius,
        child: Container(
          width: double.infinity,
          constraints: maxHeight != null
              ? BoxConstraints(maxHeight: maxHeight!)
              : null,
          child: FrostedHeaderBackground(
            blurEnabled: useBlur,
            blurSigma: HyperosBlurredHeader.blurSigmaOf(context),
            tint: tint,
            child: content,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      constraints: maxHeight != null
          ? BoxConstraints(maxHeight: maxHeight!)
          : null,
      decoration: BoxDecoration(
        color: HyperosColors.scaffoldBackground(context),
        borderRadius: borderRadius,
      ),
      child: content,
    );
  }
}

/// Gray-background bottom sheet body for HyperOS single-choice lists.
class HyperosSheet extends StatelessWidget {
  const HyperosSheet({
    super.key,
    this.title,
    required this.child,
    this.description,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
    this.frosted = false,
  });

  final String? title;
  final Widget child;
  final String? description;
  final EdgeInsetsGeometry padding;
  final bool frosted;

  @override
  Widget build(BuildContext context) {
    return HyperosSheetFrame(
      frosted: frosted,
      padding: padding,
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
Future<T?> showHyperosSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useRootNavigator = false,
  Color? barrierColor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useRootNavigator: useRootNavigator,
    backgroundColor: Colors.transparent,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.32),
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: builder(sheetContext),
      );
    },
  );
}

/// Home timetable bottom sheets: frosted panel + lighter modal barrier.
Future<T?> showHomeHyperosSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useRootNavigator = false,
  Color? barrierColor,
}) {
  return showHyperosSheet<T>(
    context: context,
    builder: builder,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useRootNavigator: useRootNavigator,
    barrierColor:
        barrierColor ??
        Colors.black.withValues(
          alpha: HyperosBlurredHeader.sheetBarrierAlphaOf(context),
        ),
  );
}
