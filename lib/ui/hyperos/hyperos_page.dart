import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/scheduler.dart';
import 'package:forui/forui.dart';

import 'hyperos_blurred_header.dart';
import 'hyperos_navigation.dart';
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
    this.headerExtension,
    this.childPad = false,
    this.backgroundColor,
    this.headerDecoration,
    this.headerStyle,
    this.resizeToAvoidBottomInset = false,
    this.overlayHeader = true,
  });

  final Widget title;
  final Widget child;
  final List<Widget>? suffixes;

  /// Optional chrome rendered below the title row inside the same frosted header
  /// shell (shares live backdrop blur with the status-bar region).
  final Widget? headerExtension;
  final bool childPad;
  final Color? backgroundColor;
  final BoxDecoration? headerDecoration;
  final FHeaderStyleDelta? headerStyle;

  /// Defaults to false so modal sheets/dialogs handle keyboard insets themselves
  /// without lifting the page behind them. Enable on inline form subpages.
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
      headerExtension: headerExtension,
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
    this.headerExtension,
    this.childPad = false,
    this.overlayHeader = true,
    this.resizeToAvoidBottomInset = false,
  });

  final Widget title;
  final Widget child;
  final VoidCallback? onBack;
  final List<Widget>? prefixes;
  final List<Widget>? suffixes;

  /// Optional chrome below the title row, sharing the header frosted backdrop.
  final Widget? headerExtension;
  final bool childPad;

  /// When true, the header floats above scrollable content for live backdrop blur.
  /// Set false only when the body must not scroll under the bar.
  final bool overlayHeader;

  /// Defaults to false so modal sheets/dialogs handle keyboard insets themselves
  /// without lifting the page behind them. Enable on inline form subpages.
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return _HyperosBlurredPage(
      childPad: childPad,
      overlayHeader: overlayHeader,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      headerExtension: headerExtension,
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
    this.headerExtension,
    this.backgroundColor,
    this.headerDecoration,
    this.resizeToAvoidBottomInset = false,
    this.overlayHeader = true,
  });

  final Widget header;
  final Widget? headerExtension;
  final Widget child;
  final bool childPad;
  final Color? backgroundColor;
  final BoxDecoration? headerDecoration;
  final bool resizeToAvoidBottomInset;
  final bool overlayHeader;

  @override
  State<_HyperosBlurredPage> createState() => _HyperosBlurredPageState();
}

class _HyperosBlurredPageState extends State<_HyperosBlurredPage>
    with RouteAware {
  /// Post-route frames before enabling [BackdropFilter] (layout behind header).
  static const _blurSettleFrameCount = 2;

  /// Scroll offset above which frosted header replaces solid page background.
  static const scrollFrostThreshold = 0.5;

  bool _blurSettled = false;

  /// True while post-frame settle callbacks are outstanding (not yet settled).
  bool _blurSettlePending = false;
  bool _contentUnderHeader = false;
  int _blurSettleGeneration = 0;
  ModalRoute<void>? _subscribedRoute;
  Animation<double>? _routeAnimation;
  Animation<double>? _secondaryRouteAnimation;
  VoidCallback? _routeAnimationListener;
  AnimationStatusListener? _routeAnimationStatusListener;
  final GlobalKey _overlayHeaderKey = GlobalKey();
  double _measuredOverlayHeaderHeight = 0;
  bool _overlayHeaderMeasurePending = false;

  /// Context of the vertical scrollable that last emitted a body scroll
  /// notification; used to resync frost against the correct scrollable.
  BuildContext? _lastBodyScrollContext;

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
  void didUpdateWidget(covariant _HyperosBlurredPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.headerExtension != widget.headerExtension) {
      _measuredOverlayHeaderHeight = 0;
      _requestOverlayHeaderMeasure();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _requestOverlayHeaderMeasure();
    final route = ModalRoute.of(context);
    _subscribeRouteObserver(route);
    final animation = route?.animation;
    final secondary = route?.secondaryAnimation;
    if (animation == _routeAnimation && secondary == _secondaryRouteAnimation) {
      return;
    }
    _detachRouteListeners();
    _routeAnimation = animation;
    _secondaryRouteAnimation = secondary;

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
        // Sync schedules settle when needed; do not call _scheduleBlurSettle
        // again here — that cancels the in-flight post-frame budget.
        _syncRouteTransitioning();
      }
    }

    _routeAnimationStatusListener = onAnimationStatus;
    animation?.addStatusListener(onAnimationStatus);

    _syncRouteTransitioning();
    _scheduleBlurSettle();
  }

  void _subscribeRouteObserver(ModalRoute<dynamic>? route) {
    if (route is! ModalRoute<void> || identical(route, _subscribedRoute)) {
      return;
    }
    if (_subscribedRoute != null) {
      hyperosRouteObserver.unsubscribe(this);
    }
    _subscribedRoute = route;
    hyperosRouteObserver.subscribe(this, route);
  }

  @override
  void didPopNext() {
    if (!mounted) {
      return;
    }
    _syncRouteTransitioning();
    _restoreBlurAfterRegainingVisibility(source: 'didPopNext');
    _scheduleResyncHeaderFrostAfterLayout();
  }

  /// Re-enable header blur when this route becomes visible again after a pop.
  void _restoreBlurAfterRegainingVisibility({required String source}) {
    if (!_liveBlurActive) {
      return;
    }
    if (_isRouteTransitioning) {
      _scheduleBlurSettle();
      return;
    }
    _cancelBlurSettle();
    _markBlurSettled(source: source);
  }

  void _cancelBlurSettle() {
    _blurSettleGeneration++;
    _blurSettlePending = false;
  }

  void _markBlurSettled({String? source}) {
    if (_blurSettled || !mounted) {
      return;
    }
    _blurSettlePending = false;
    setState(() => _blurSettled = true);
    _scheduleResyncHeaderFrostAfterLayout();
  }

  void _scheduleBlurSettle() {
    if (_isRouteTransitioning) {
      _cancelBlurSettle();
      if (_blurSettled && mounted) {
        setState(() => _blurSettled = false);
      } else {
        _blurSettled = false;
      }
      return;
    }
    // Skip if already settled OR a settle frame budget is already running —
    // rescheduling would bump generation and cancel the in-flight settle.
    if (_blurSettled || _blurSettlePending) {
      return;
    }
    _cancelBlurSettle();
    final generation = _blurSettleGeneration;
    _blurSettlePending = true;
    void afterFrames(int remaining) {
      if (!mounted ||
          generation != _blurSettleGeneration ||
          _isRouteTransitioning) {
        return;
      }
      if (remaining <= 0) {
        _markBlurSettled(source: 'frames');
        return;
      }
      SchedulerBinding.instance.addPostFrameCallback((_) {
        afterFrames(remaining - 1);
      });
    }

    afterFrames(_blurSettleFrameCount);
  }

  /// User scroll means content is moving under the header — enable blur immediately
  /// instead of waiting for the post-route frame budget (fixes fast scroll after push).
  void _tryEnableBlurOnUserScroll() {
    if (!_liveBlurActive || _blurSettled || _isRouteTransitioning) {
      return;
    }
    _cancelBlurSettle();
    _markBlurSettled(source: 'scroll');
  }

  bool _handleBodyScrollForBlur(ScrollNotification notification) {
    hyperosHandleOverscrollSnapBack(notification);
    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification) {
      if (notification.metrics.axis == Axis.vertical) {
        _lastBodyScrollContext = notification.context;
      }
      _tryEnableBlurOnUserScroll();
      _syncHeaderFrostForScroll(notification.metrics.pixels);
    }
    return false;
  }

  void _syncHeaderFrostForScroll(double pixels) {
    if (!_useOverlayLayout) {
      return;
    }
    final underHeader = hyperosContentUnderHeader(
      scrollPixels: pixels,
      threshold: scrollFrostThreshold,
    );
    if (_contentUnderHeader == underHeader) {
      return;
    }
    setState(() => _contentUnderHeader = underHeader);
  }

  void _scheduleResyncHeaderFrostAfterLayout() {
    if (!_useOverlayLayout) {
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final pixels = _findBodyScrollPixels();
      if (pixels != null) {
        _syncHeaderFrostForScroll(pixels);
      }
    });
  }

  double? _findBodyScrollPixels() {
    // Prefer the scrollable that actually drove the frost state via scroll
    // notifications — a DFS can hit the wrong one on pages with multiple
    // scrollables (e.g. preview + settings list) and desync the header frost.
    final lastContext = _lastBodyScrollContext;
    if (lastContext is StatefulElement && lastContext.mounted) {
      final state = lastContext.state;
      if (state is ScrollableState && state.position.hasPixels) {
        return state.position.pixels;
      }
    }

    ScrollPosition? found;
    void visit(Element element) {
      if (found != null) {
        return;
      }
      if (element is StatefulElement && element.state is ScrollableState) {
        final position = (element.state as ScrollableState).position;
        // Header frost tracks vertical body scroll only; skip horizontal
        // scrollables (chip rows, carousels) but keep searching inside them.
        if (position.axis == Axis.vertical) {
          found = position;
          return;
        }
      }
      element.visitChildren(visit);
    }

    visit(context as Element);
    return found?.pixels;
  }

  HyperosBlurredHeaderScope _buildHeaderScope({
    required double contentTopInset,
    required bool routeBlurEnabled,
    required Color headerBackgroundColor,
    required Widget child,
  }) {
    return HyperosBlurredHeaderScope(
      contentTopInset: contentTopInset,
      blurEnabled: routeBlurEnabled,
      contentUnderHeader: _contentUnderHeader,
      headerBackgroundColor: headerBackgroundColor,
      child: child,
    );
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
        setState(() {});
      }
      return;
    }

    if (!isCurrent) {
      if (!_blurSettled) {
        _scheduleBlurSettle();
      }
      return;
    }

    // Already settled: do not cancel/restart the frame budget (that left blur
    // stuck off when sync fired again from animation status / rebuilds).
    if (!_blurSettled) {
      _scheduleBlurSettle();
    }
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
    if (_subscribedRoute != null) {
      hyperosRouteObserver.unsubscribe(this);
      _subscribedRoute = null;
    }
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

  Widget _buildHeaderContent() {
    if (widget.headerExtension == null) {
      return widget.header;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [widget.header, widget.headerExtension!],
    );
  }

  double _overlayContentTopInset(BuildContext context) {
    if (!_useOverlayLayout) {
      return 0;
    }
    if (_measuredOverlayHeaderHeight > 0) {
      return _measuredOverlayHeaderHeight;
    }
    if (widget.headerExtension != null) {
      return HyperosBlurredHeader.contentTopInsetWithExtension(context);
    }
    return HyperosBlurredHeader.contentTopInset(context);
  }

  void _requestOverlayHeaderMeasure() {
    if (!_useOverlayLayout || widget.headerExtension == null) {
      return;
    }
    if (_overlayHeaderMeasurePending) {
      return;
    }
    _overlayHeaderMeasurePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overlayHeaderMeasurePending = false;
      if (!mounted) {
        return;
      }
      final box =
          _overlayHeaderKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) {
        return;
      }
      final height = box.size.height;
      if ((height - _measuredOverlayHeaderHeight).abs() > 0.5) {
        setState(() => _measuredOverlayHeaderHeight = height);
      }
    });
  }

  Widget _buildBody({required Color pageBackground, required Widget child}) {
    final body = Material(
      type: MaterialType.transparency,
      color: pageBackground,
      child: ScrollConfiguration(
        behavior: const HyperosScrollBehavior(),
        child: child,
      ),
    );
    if (!_useOverlayLayout) {
      return body;
    }
    return NotificationListener<ScrollNotification>(
      onNotification: _handleBodyScrollForBlur,
      child: body,
    );
  }

  Widget _buildScaffoldHeaderLayout(Color pageBackground) {
    final headerContent = _buildHeaderContent();
    final blurredHeader = _buildHeaderShell(headerContent, pageBackground);
    final header = _buildHeaderScope(
      contentTopInset: 0,
      routeBlurEnabled: _backdropBlurEnabled,
      headerBackgroundColor: pageBackground,
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

    final headerContent = _buildHeaderContent();
    final blurredHeader = _buildHeaderShell(headerContent, pageBackground);
    final headerInset = _overlayContentTopInset(context);

    return FScaffold(
      resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
      scaffoldStyle: FScaffoldStyleDelta.delta(backgroundColor: pageBackground),
      childPad: widget.childPad,
      child: _buildHeaderScope(
        contentTopInset: headerInset,
        routeBlurEnabled: _backdropBlurEnabled,
        headerBackgroundColor: pageBackground,
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
                    return const SizedBox.shrink();
                  }
                  return SizedBox(
                    key: _overlayHeaderKey,
                    width: width,
                    child: blurredHeader,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Whether scroll offset places list content under the overlay header.
@visibleForTesting
bool hyperosContentUnderHeader({
  required double scrollPixels,
  double threshold = _HyperosBlurredPageState.scrollFrostThreshold,
}) {
  return scrollPixels > threshold;
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
/// Uses [HyperosOverscrollPhysics] (same as [HyperosScrollBehavior] on
/// [HyperosSubpage] / [HyperosRootPage]). Prefer this for settings-style
/// pages; raw [ListView] inside those shells also inherits the physics.
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

    return _HyperosListScrollHost(
      child: hyperosBlockStretchOverscroll(
        child: ScrollConfiguration(
          behavior: const HyperosScrollBehavior(),
          child: ListView.builder(
            key: listKey,
            physics: HyperosOverscrollPhysics(
              parent: const AlwaysScrollableScrollPhysics(),
              topInset: widget.includeHeaderInset
                  ? HyperosBlurredHeaderScope.insetOf(context)
                  : 0,
            ),
            padding: _resolveListPadding(context),
            itemCount: resolvedItemCount,
            itemBuilder: resolvedItemBuilder,
          ),
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

/// Owns scroll highlight state so [HyperosListView] items are not rebuilt on
/// every scroll start/end (avoids TextField width jitter in form rows).
class _HyperosListScrollHost extends StatefulWidget {
  const _HyperosListScrollHost({required this.child});

  final Widget child;

  @override
  State<_HyperosListScrollHost> createState() => _HyperosListScrollHostState();
}

class _HyperosListScrollHostState extends State<_HyperosListScrollHost> {
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
    hyperosHandleOverscrollSnapBack(notification);
    if (notification is ScrollStartNotification) {
      _setScrollState(() => _pressHighlightGeneration++);
    }
    if (notification is UserScrollNotification) {
      final scrolling = notification.direction != ScrollDirection.idle;
      if (_isUserScrolling != scrolling) {
        _setScrollState(() => _isUserScrolling = scrolling);
      }
    }
    if (notification is ScrollEndNotification) {
      if (_isUserScrolling) {
        _setScrollState(() => _isUserScrolling = false);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return HyperosListScrollScope(
      isUserScrolling: _isUserScrolling,
      pressHighlightGeneration: _pressHighlightGeneration,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScroll,
        child: widget.child,
      ),
    );
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
