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
import 'frosted/frosted_header_controller.dart';
import '../../../services/frosted_blur_service.dart';

/// Root settings page without a back button (HyperOS settings home pattern).
class HyperosRootPage extends StatelessWidget {
  const HyperosRootPage({
    super.key,
    required this.title,
    required this.child,
    this.suffixes,
    this.childPad = false,
    this.backgroundColor,
    this.headerStyle,
    this.resizeToAvoidBottomInset = true,
    this.overlayHeader = true,
  });

  final Widget title;
  final Widget child;
  final List<Widget>? suffixes;
  final bool childPad;
  final Color? backgroundColor;
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
/// Product scope: only the settings home uses [overlayHeader] `true` for
/// scroll-under blur. Sub-routes default to `false` (scaffold header slot).
/// See `.trellis/spec/flutter/hyperos-blurred-header.md`.
class HyperosSubpage extends StatelessWidget {
  const HyperosSubpage({
    super.key,
    required this.title,
    required this.child,
    this.onBack,
    this.prefixes,
    this.suffixes,
    this.childPad = false,
    this.overlayHeader = false,
  });

  final Widget title;
  final Widget child;
  final VoidCallback? onBack;
  final List<Widget>? prefixes;
  final List<Widget>? suffixes;
  final bool childPad;

  /// When true, the header floats above scrollable content (settings home only).
  /// Sub-routes default to false to avoid overlay + heavy [ListView] on push.
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
    this.resizeToAvoidBottomInset = true,
    this.overlayHeader = true,
  });

  final Widget header;
  final Widget child;
  final bool childPad;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;
  final bool overlayHeader;

  @override
  State<_HyperosBlurredPage> createState() => _HyperosBlurredPageState();
}

class _HyperosBlurredPageState extends State<_HyperosBlurredPage> {
  static const _blurSettleDelay = Duration(milliseconds: 350);

  final _captureBoundaryKey = GlobalKey();
  late final FrostedHeaderController _frostedController;

  bool _blurSettled = false;
  bool _frostedProbed = false;
  Timer? _blurSettleTimer;
  Animation<double>? _routeAnimation;
  Animation<double>? _secondaryRouteAnimation;
  VoidCallback? _routeAnimationListener;
  AnimationStatusListener? _routeAnimationStatusListener;

  @override
  void initState() {
    super.initState();
    _frostedController = FrostedHeaderController()
      ..attach(boundaryKey: _captureBoundaryKey);
    _frostedController.addListener(_onFrostedImageChanged);
    unawaited(_probeFrostedBlur());
  }

  Future<void> _probeFrostedBlur() async {
    await FrostedBlurService.probeNativeSupport();
    if (mounted) {
      setState(() => _frostedProbed = true);
      _syncFrostedCapture();
    }
  }

  void _onFrostedImageChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _syncFrostedCapture() {
    if (!_frostedProbed) {
      return;
    }
    final enabled = _cfhReady && HyperosBlurredHeader.liveBlurSupported;
    _frostedController.captureEnabled = enabled;
    if (enabled) {
      _frostedController.scheduleRefresh(source: 'blur_sync');
    }
  }

  /// Overlay scroll-under blur only while this route is the visible top route.
  bool get _effectiveOverlay => widget.overlayHeader && _isRouteCurrent;

  double get _animationValue => _routeAnimation?.value ?? 1.0;

  double get _secondaryAnimationValue => _secondaryRouteAnimation?.value ?? 0.0;

  bool get _isRouteCurrent => ModalRoute.of(context)?.isCurrent ?? true;

  bool get _isRouteTransitioning => hyperosIsRouteTransitioning(
    animationValue: _animationValue,
    secondaryAnimationValue: _secondaryAnimationValue,
    isRouteCurrent: _isRouteCurrent,
  );

  /// CFH capture/blur gate after route settle (platform-agnostic).
  bool get _cfhReady =>
      _isRouteCurrent && !_isRouteTransitioning && _blurSettled;

  bool get _blurEnabled => HyperosBlurredHeader.liveBlurSupported && _cfhReady;

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
    if (!_isRouteCurrent || _isRouteTransitioning) {
      if (_blurSettled && mounted) {
        setState(() => _blurSettled = false);
      } else {
        _blurSettled = false;
      }
      return;
    }
    _blurSettleTimer = Timer(_blurSettleDelay, () {
      if (!mounted || !_isRouteCurrent || _isRouteTransitioning) {
        return;
      }
      HyperosHeaderDiag.log('blur_settle', {'blurSettled': true});
      setState(() => _blurSettled = true);
      _syncFrostedCapture();
    });
  }

  void _syncRouteTransitioning() {
    final transitioning = _isRouteTransitioning;
    final isCurrent = _isRouteCurrent;

    if (transitioning) {
      _cancelBlurSettle();
      if (_blurSettled && isCurrent && mounted) {
        setState(() => _blurSettled = false);
      } else {
        _blurSettled = false;
      }
      if (isCurrent && mounted) {
        HyperosHeaderDiag.log('route_transition', {
          'isRouteTransitioning': true,
          'isRouteCurrent': true,
          'effectiveOverlay': _effectiveOverlay,
          'animationValue': _animationValue,
          'secondaryAnimationValue': _secondaryAnimationValue,
        });
        setState(() {});
      } else {
        HyperosHeaderDiag.log('route_transition', {
          'isRouteTransitioning': true,
          'isRouteCurrent': false,
          'skippedRebuild': true,
          'animationValue': _animationValue,
          'secondaryAnimationValue': _secondaryAnimationValue,
        });
      }
      return;
    }

    if (!isCurrent) {
      HyperosHeaderDiag.log('route_transition', {
        'isRouteTransitioning': false,
        'isRouteCurrent': false,
        'skippedRebuild': true,
        'animationValue': _animationValue,
        'secondaryAnimationValue': _secondaryAnimationValue,
      });
      return;
    }

    HyperosHeaderDiag.log('route_transition', {
      'isRouteTransitioning': false,
      'isRouteCurrent': true,
      'effectiveOverlay': _effectiveOverlay,
      'animationValue': _animationValue,
      'secondaryAnimationValue': _secondaryAnimationValue,
    });
    _scheduleBlurSettle();
    if (mounted) {
      setState(() {});
      _syncFrostedCapture();
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
    _frostedController.removeListener(_onFrostedImageChanged);
    _frostedController.dispose();
    _cancelBlurSettle();
    _detachRouteListeners();
    super.dispose();
  }

  Widget _buildFrostedHeaderShell(Widget header) {
    return HyperosBlurredHeaderShell(
      blurredImage: _frostedController.blurredImage,
      child: header,
    );
  }

  Widget _buildCapturableBody({
    required Color pageBackground,
    required Widget child,
  }) {
    return RepaintBoundary(
      key: _captureBoundaryKey,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          _frostedController.onScrollNotification(notification);
          return false;
        },
        child: Material(
          type: MaterialType.transparency,
          color: pageBackground,
          child: child,
        ),
      ),
    );
  }

  Widget _buildScaffoldHeaderLayout(Color pageBackground) {
    final blurredHeader = _buildFrostedHeaderShell(widget.header);
    HyperosHeaderDiag.log('page_build', {
      'layoutMode': 'scaffold_header',
      'liveBlurSupported': HyperosBlurredHeader.liveBlurSupported,
      'isRouteCurrent': _isRouteCurrent,
      'effectiveOverlay': _effectiveOverlay,
      'isRouteTransitioning': _isRouteTransitioning,
      'blurSettled': _blurSettled,
      'animationValue': _animationValue,
      'secondaryAnimationValue': _secondaryAnimationValue,
      'blurEnabled': _blurEnabled,
    });
    final header = HyperosBlurredHeaderScope(
      contentTopInset: 0,
      blurEnabled: _cfhReady,
      frostedController: _frostedController,
      child: blurredHeader,
    );
    return FScaffold(
      resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
      scaffoldStyle: FScaffoldStyleDelta.delta(backgroundColor: pageBackground),
      header: header,
      childPad: widget.childPad,
      child: _buildCapturableBody(
        pageBackground: pageBackground,
        child: widget.child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageBackground =
        widget.backgroundColor ?? HyperosColors.scaffoldBackground(context);

    if (!_effectiveOverlay) {
      return _buildScaffoldHeaderLayout(pageBackground);
    }

    final blurredHeader = _buildFrostedHeaderShell(widget.header);
    final headerInset = HyperosBlurredHeader.contentTopInset(context);

    HyperosHeaderDiag.log('page_build', {
      'layoutMode': 'overlay_blur',
      'liveBlurSupported': HyperosBlurredHeader.liveBlurSupported,
      'isRouteCurrent': _isRouteCurrent,
      'effectiveOverlay': _effectiveOverlay,
      'isRouteTransitioning': _isRouteTransitioning,
      'blurSettled': _blurSettled,
      'animationValue': _animationValue,
      'secondaryAnimationValue': _secondaryAnimationValue,
      'blurEnabled': _blurEnabled,
      'headerInset': headerInset,
    });

    return FScaffold(
      resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
      scaffoldStyle: FScaffoldStyleDelta.delta(backgroundColor: pageBackground),
      childPad: widget.childPad,
      child: HyperosBlurredHeaderScope(
        contentTopInset: headerInset,
        blurEnabled: _cfhReady,
        frostedController: _frostedController,
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: _buildCapturableBody(
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
  }) : assert(
         (children != null) ^ (itemCount != null && itemBuilder != null),
         'Provide either children or itemCount+itemBuilder',
       );

  final List<Widget>? children;
  final int? itemCount;
  final IndexedWidgetBuilder? itemBuilder;
  final EdgeInsetsGeometry? padding;

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
    HyperosBlurredHeaderScope.frostedControllerOf(
      context,
    )?.onScrollNotification(notification);
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
    // Overlay scroll-under: list must start at y=0 so content passes under the
    // frosted header. [HyperosBlurredHeaderScope.contentTopInset] is only for
    // [HyperosBlurredBodyInset], not list top padding.
    return (widget.padding ?? HyperosTokens.listPadding).resolve(
      Directionality.of(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final children = widget.children;
    final resolvedItemCount = children?.length ?? widget.itemCount!;
    final resolvedItemBuilder =
        widget.itemBuilder ?? (context, index) => children![index];

    return HyperosListScrollScope(
      isUserScrolling: _isUserScrolling,
      pressHighlightGeneration: _pressHighlightGeneration,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScroll,
        child: ListView.builder(
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
}

/// Gray rounded bottom sheet container (no title row).
class HyperosSheetFrame extends StatelessWidget {
  const HyperosSheetFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
    this.maxHeight,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: maxHeight != null
          ? BoxConstraints(maxHeight: maxHeight!)
          : null,
      decoration: BoxDecoration(
        color: HyperosColors.scaffoldBackground(context),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(HyperosTokens.cardRadius),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(padding: padding, child: child),
      ),
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
  });

  final String? title;
  final Widget child;
  final String? description;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return HyperosSheetFrame(
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
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useRootNavigator: useRootNavigator,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.32),
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
