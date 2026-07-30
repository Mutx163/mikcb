import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'hyperos_blurred_header.dart';
import 'hyperos_navigation.dart';

/// Whether scroll offset places list content under the overlay header.
@visibleForTesting
bool hyperosContentUnderHeader({
  required double scrollPixels,
  double threshold = 0.5,
}) {
  return scrollPixels > threshold;
}

/// Whether a HyperOS page route is mid transition.
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

/// Route-transition blur gate: animation listeners + post-frame settle budget.
///
/// Does not call [State.setState] directly; notifies via [onChanged].
class HyperosRouteBlurGate with RouteAware {
  HyperosRouteBlurGate({
    required this.isLiveBlurActive,
    required this.onChanged,
    this.onDidPopNext,
    this.blurSettleFrameCount = 2,
  });

  final bool Function() isLiveBlurActive;
  final VoidCallback onChanged;

  /// Extra work after regaining visibility (e.g. resync header frost).
  final VoidCallback? onDidPopNext;
  final int blurSettleFrameCount;

  bool blurSettled = false;
  bool _blurSettlePending = false;
  int _blurSettleGeneration = 0;
  ModalRoute<void>? _subscribedRoute;
  Animation<double>? _routeAnimation;
  Animation<double>? _secondaryRouteAnimation;
  VoidCallback? _routeAnimationListener;
  AnimationStatusListener? _routeAnimationStatusListener;

  /// Host [State.mounted] check — set by the owning State each attach.
  bool Function() isMounted = () => false;

  /// Host [BuildContext] for [ModalRoute.of] — set before [didChangeDependencies].
  BuildContext? hostContext;

  double get animationValue => _routeAnimation?.value ?? 1.0;

  double get secondaryAnimationValue => _secondaryRouteAnimation?.value ?? 0.0;

  bool get isRouteCurrent {
    final context = hostContext;
    if (context == null) {
      return true;
    }
    return ModalRoute.of(context)?.isCurrent ?? true;
  }

  bool get isRouteTransitioning => hyperosIsRouteTransitioning(
    animationValue: animationValue,
    secondaryAnimationValue: secondaryAnimationValue,
    isRouteCurrent: isRouteCurrent,
  );

  bool get blurReady => !isRouteTransitioning && blurSettled;

  bool get backdropBlurEnabled => isLiveBlurActive() && blurReady;

  void didChangeDependencies() {
    final context = hostContext;
    if (context == null) {
      return;
    }
    final route = ModalRoute.of(context);
    _subscribeRouteObserver(route);
    final animation = route?.animation;
    final secondary = route?.secondaryAnimation;
    if (animation == _routeAnimation && secondary == _secondaryRouteAnimation) {
      return;
    }
    detachRouteListeners();
    _routeAnimation = animation;
    _secondaryRouteAnimation = secondary;

    void sync() => syncRouteTransitioning();
    _routeAnimationListener = sync;
    animation?.addListener(sync);
    secondary?.addListener(sync);

    void onAnimationStatus(AnimationStatus status) {
      if (!isMounted() || !isRouteCurrent) {
        return;
      }
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        syncRouteTransitioning();
      }
    }

    _routeAnimationStatusListener = onAnimationStatus;
    animation?.addStatusListener(onAnimationStatus);

    syncRouteTransitioning();
    scheduleBlurSettle();
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
    if (!isMounted()) {
      return;
    }
    syncRouteTransitioning();
    restoreBlurAfterRegainingVisibility(source: 'didPopNext');
    onDidPopNext?.call();
  }

  void restoreBlurAfterRegainingVisibility({required String source}) {
    if (!isLiveBlurActive()) {
      return;
    }
    if (isRouteTransitioning) {
      scheduleBlurSettle();
      return;
    }
    cancelBlurSettle();
    markBlurSettled(source: source);
  }

  void cancelBlurSettle() {
    _blurSettleGeneration++;
    _blurSettlePending = false;
  }

  void markBlurSettled({String? source}) {
    if (blurSettled || !isMounted()) {
      return;
    }
    _blurSettlePending = false;
    blurSettled = true;
    onChanged();
  }

  void scheduleBlurSettle() {
    if (isRouteTransitioning) {
      cancelBlurSettle();
      if (blurSettled && isMounted()) {
        blurSettled = false;
        onChanged();
      } else {
        blurSettled = false;
      }
      return;
    }
    if (blurSettled || _blurSettlePending) {
      return;
    }
    cancelBlurSettle();
    final generation = _blurSettleGeneration;
    _blurSettlePending = true;

    // Count down post-frame hops. Only scheduleFrame when the scheduler is
    // idle / already in post-frame — never mid build/layout/paint (debug
    // asserts "Build scheduled during frame"). WidgetTester still gets an
    // explicit frame when pump runs after idle.
    var remaining = blurSettleFrameCount;
    void step(Duration _) {
      if (!isMounted() ||
          generation != _blurSettleGeneration ||
          isRouteTransitioning) {
        return;
      }
      remaining -= 1;
      if (remaining <= 0) {
        markBlurSettled(source: 'frames');
        return;
      }
      SchedulerBinding.instance.addPostFrameCallback(step);
      _scheduleFrameIfSafe();
    }

    SchedulerBinding.instance.addPostFrameCallback(step);
    _scheduleFrameIfSafe();
  }

  static void _scheduleFrameIfSafe() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      SchedulerBinding.instance.scheduleFrame();
    }
  }

  void tryEnableBlurOnUserScroll() {
    if (!isLiveBlurActive() || blurSettled || isRouteTransitioning) {
      return;
    }
    cancelBlurSettle();
    markBlurSettled(source: 'scroll');
  }

  void syncRouteTransitioning() {
    final transitioning = isRouteTransitioning;
    final isCurrent = isRouteCurrent;

    if (transitioning) {
      cancelBlurSettle();
      // Only notify when the settled flag actually flips. Animation listeners
      // fire every frame; re-notifying while already unset rebuilds the whole
      // page (and any dynamic headerExtension) for no visual change.
      if (blurSettled) {
        blurSettled = false;
        if (isMounted()) {
          onChanged();
        }
      } else {
        blurSettled = false;
      }
      return;
    }

    if (!isCurrent) {
      if (!blurSettled) {
        scheduleBlurSettle();
      }
      return;
    }

    // Transition just ended (or first attach): schedule settle frames. Do not
    // call onChanged here while already settled — that only causes flicker.
    if (!blurSettled) {
      scheduleBlurSettle();
    }
  }

  void detachRouteListeners() {
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

  void dispose() {
    if (_subscribedRoute != null) {
      hyperosRouteObserver.unsubscribe(this);
      _subscribedRoute = null;
    }
    cancelBlurSettle();
    detachRouteListeners();
  }
}

/// Maps body scroll pixels to frosted-header state.
class HyperosHeaderFrostFromScroll {
  HyperosHeaderFrostFromScroll({
    required this.useOverlayLayout,
    required this.onChanged,
    this.scrollFrostThreshold = 0.5,
    this.frostThresholdOverride,
  });

  final bool Function() useOverlayLayout;
  final VoidCallback onChanged;
  final double scrollFrostThreshold;

  /// Optional dynamic threshold. Collapsible large-title pages frost only
  /// once content actually tucks under the collapsed band (pixels ≥ large
  /// title expansion) — during the collapse itself the header keeps the plain
  /// page color. Returning null falls back to [scrollFrostThreshold].
  final double? Function()? frostThresholdOverride;

  bool contentUnderHeader = false;
  BuildContext? lastBodyScrollContext;

  bool Function() isMounted = () => false;
  BuildContext? hostContext;

  void syncHeaderFrostForScroll(double pixels) {
    if (!useOverlayLayout()) {
      return;
    }
    final underHeader = hyperosContentUnderHeader(
      scrollPixels: pixels,
      threshold: frostThresholdOverride?.call() ?? scrollFrostThreshold,
    );
    if (contentUnderHeader == underHeader) {
      return;
    }
    contentUnderHeader = underHeader;
    onChanged();
  }

  void scheduleResyncHeaderFrostAfterLayout() {
    if (!useOverlayLayout()) {
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!isMounted()) {
        return;
      }
      final pixels = findBodyScrollPixels();
      if (pixels != null) {
        syncHeaderFrostForScroll(pixels);
      }
    });
  }

  double? findBodyScrollPixels() {
    final lastContext = lastBodyScrollContext;
    if (lastContext is StatefulElement && lastContext.mounted) {
      final state = lastContext.state;
      if (state is ScrollableState && state.position.hasPixels) {
        return state.position.pixels;
      }
    }

    final context = hostContext;
    if (context == null) {
      return null;
    }

    ScrollPosition? found;
    void visit(Element element) {
      if (found != null) {
        return;
      }
      if (element is StatefulElement && element.state is ScrollableState) {
        final position = (element.state as ScrollableState).position;
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

  void noteScrollContext(BuildContext? notificationContext, Axis axis) {
    if (axis == Axis.vertical) {
      lastBodyScrollContext = notificationContext;
    }
  }
}

/// Measures overlay header height for content top inset.
class HyperosOverlayHeaderMetrics {
  HyperosOverlayHeaderMetrics({
    required this.useOverlayLayout,
    required this.hasHeaderExtension,
    required this.onChanged,
    this.useCollapsibleTopAppBar,
  });

  final bool Function() useOverlayLayout;
  final bool Function() hasHeaderExtension;
  final VoidCallback onChanged;

  /// When true, fallback inset uses collapsible large-title estimate.
  final bool Function()? useCollapsibleTopAppBar;

  final GlobalKey overlayHeaderKey = GlobalKey();
  double measuredOverlayHeaderHeight = 0;
  bool _overlayHeaderMeasurePending = false;

  bool Function() isMounted = () => false;

  void resetMeasuredHeight() {
    measuredOverlayHeaderHeight = 0;
  }

  double overlayContentTopInset(BuildContext context) {
    if (!useOverlayLayout()) {
      return 0;
    }
    // Collapsible large-title bar: return the *expanded* height as the base.
    // The page shell adds a collapse delta on top (_collapseInsetDelta in
    // hyperos_page.dart) so short pages rest at the small-title height once
    // collapsed, while scrollable pages keep this expanded inset.
    if (useCollapsibleTopAppBar?.call() ?? false) {
      return HyperosBlurredHeader.contentTopInsetCollapsible(context);
    }
    if (measuredOverlayHeaderHeight > 0) {
      return measuredOverlayHeaderHeight;
    }
    if (hasHeaderExtension()) {
      return HyperosBlurredHeader.contentTopInsetWithExtension(context);
    }
    return HyperosBlurredHeader.contentTopInset(context);
  }

  void requestOverlayHeaderMeasure() {
    // Collapsible bars keep a fixed expanded inset — measuring live height only
    // feeds padding churn. Extension rows still need measure.
    if (!useOverlayLayout() || (useCollapsibleTopAppBar?.call() ?? false)) {
      return;
    }
    if (_overlayHeaderMeasurePending) {
      return;
    }
    _overlayHeaderMeasurePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overlayHeaderMeasurePending = false;
      if (!isMounted()) {
        return;
      }
      final box =
          overlayHeaderKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) {
        return;
      }
      final height = box.size.height;
      if ((height - measuredOverlayHeaderHeight).abs() > 0.5) {
        measuredOverlayHeaderHeight = height;
        onChanged();
      }
    });
  }
}
