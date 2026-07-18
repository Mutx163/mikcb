import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/scheduler.dart';
import 'package:forui/forui.dart';

import 'hyperos_blurred_header.dart';
import 'hyperos_overscroll.dart';
import 'hyperos_overlay_header.dart';
import 'hyperos_page_collaborators.dart';
import 'hyperos_theme.dart';
import 'hyperos_tokens.dart';
import 'hyperos_widgets.dart';

export 'hyperos_page_collaborators.dart'
    show
        hyperosContentUnderHeader,
        hyperosIsIncomingRouteSettled,
        hyperosIsRouteTransitioning;

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

class _HyperosBlurredPageState extends State<_HyperosBlurredPage> {
  /// Scroll offset above which frosted header replaces solid page background.
  static const scrollFrostThreshold = 0.5;

  late final HyperosRouteBlurGate _routeBlurGate;
  late final HyperosHeaderFrostFromScroll _headerFrost;
  late final HyperosOverlayHeaderMetrics _overlayMetrics;

  @override
  void initState() {
    super.initState();
    void notify() {
      if (!mounted) {
        return;
      }
      // setState is safe in idle and post-frame phases. Defer only while the
      // pipeline is mid build/layout/paint. Always scheduleFrame when deferring
      // so nested post-frame work still flushes under WidgetTester (and after
      // route animation status flips without an extra vsync tick).
      final phase = SchedulerBinding.instance.schedulerPhase;
      if (phase == SchedulerPhase.idle ||
          phase == SchedulerPhase.postFrameCallbacks) {
        setState(() {});
        return;
      }
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {});
      });
      SchedulerBinding.instance.scheduleFrame();
    }

    _routeBlurGate = HyperosRouteBlurGate(
      isLiveBlurActive: () => widget.overlayHeader,
      onChanged: () {
        notify();
        _headerFrost.scheduleResyncHeaderFrostAfterLayout();
      },
      onDidPopNext: () {
        _headerFrost.scheduleResyncHeaderFrostAfterLayout();
      },
    );
    _headerFrost = HyperosHeaderFrostFromScroll(
      useOverlayLayout: () => widget.overlayHeader,
      onChanged: notify,
      scrollFrostThreshold: scrollFrostThreshold,
    );
    _overlayMetrics = HyperosOverlayHeaderMetrics(
      useOverlayLayout: () => widget.overlayHeader,
      hasHeaderExtension: () => widget.headerExtension != null,
      onChanged: notify,
    );
    _bindCollaboratorHosts();
  }

  void _bindCollaboratorHosts() {
    _routeBlurGate.isMounted = () => mounted;
    _headerFrost.isMounted = () => mounted;
    _overlayMetrics.isMounted = () => mounted;
  }

  bool get _useOverlayLayout => widget.overlayHeader;

  bool get _backdropBlurEnabled => _routeBlurGate.backdropBlurEnabled;

  @override
  void didUpdateWidget(covariant _HyperosBlurredPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only presence (null ↔ non-null) should clear the measured height.
    // Callers often pass a freshly built [headerExtension] each frame; treating
    // widget identity changes as "structure changed" zeros the inset and causes
    // a measure → setState → rebuild flicker loop (e.g. UserGuide progress bar).
    final hadExtension = oldWidget.headerExtension != null;
    final hasExtension = widget.headerExtension != null;
    if (hadExtension != hasExtension) {
      _overlayMetrics.resetMeasuredHeight();
      _overlayMetrics.requestOverlayHeaderMeasure();
    } else if (hasExtension) {
      // Content may have resized; remeasure without zeroing to avoid inset jumps.
      _overlayMetrics.requestOverlayHeaderMeasure();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindCollaboratorHosts();
    _routeBlurGate.hostContext = context;
    _headerFrost.hostContext = context;
    _overlayMetrics.requestOverlayHeaderMeasure();
    _routeBlurGate.didChangeDependencies();
  }

  bool _handleBodyScrollForBlur(ScrollNotification notification) {
    hyperosHandleOverscrollSnapBack(notification);
    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification) {
      // PageView / horizontal carousels also bubble ScrollNotifications. Their
      // pixels are page offsets, not vertical under-header scroll, and must not
      // toggle frosted-header state.
      if (notification.metrics.axis != Axis.vertical) {
        return false;
      }
      _headerFrost.noteScrollContext(
        notification.context,
        notification.metrics.axis,
      );
      _routeBlurGate.tryEnableBlurOnUserScroll();
      _headerFrost.syncHeaderFrostForScroll(notification.metrics.pixels);
    }
    return false;
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
      contentUnderHeader: _headerFrost.contentUnderHeader,
      headerBackgroundColor: headerBackgroundColor,
      child: child,
    );
  }

  @override
  void dispose() {
    _routeBlurGate.dispose();
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
    final headerInset = _overlayMetrics.overlayContentTopInset(context);

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
                    key: _overlayMetrics.overlayHeaderKey,
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
