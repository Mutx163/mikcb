import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'hyperos_blurred_header.dart';
import 'hyperos_collapsible_top_app_bar.dart';
import 'hyperos_icon_button.dart';
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
    this.headerPadding,
    this.systemOverlayStyle,
    this.resizeToAvoidBottomInset = false,
    this.overlayHeader = true,
    this.bottomBar,
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

  /// Content padding of the stacked root header bar (non-overlay layout only).
  final EdgeInsetsGeometry? headerPadding;

  /// Status-bar icon style override. When null, derived from the page
  /// background — pages with a transparent background over wallpaper must
  /// pass this explicitly or the derived style is always light-on-dark.
  final SystemUiOverlayStyle? systemOverlayStyle;

  /// Defaults to false so modal sheets/dialogs handle keyboard insets themselves
  /// without lifting the page behind them. Enable on inline form subpages.
  final bool resizeToAvoidBottomInset;

  /// When false, the header stacks above content (no blur overlay). Use for
  /// pages like the main timetable where the body must not sit under the bar.
  final bool overlayHeader;

  /// Optional fixed bar pinned at the bottom, outside the collapsible
  /// translation (e.g. guide "Next" row). When set, the bar is rendered
  /// via [Scaffold.bottomNavigationBar] so the scroll-driven
  /// [_collapseInsetDelta] never lifts it.
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    final collapsibleTitle = hyperosExtractPageTitleText(title);
    return _HyperosBlurredPage(
      childPad: childPad,
      backgroundColor: backgroundColor,
      headerDecoration: headerDecoration,
      systemOverlayStyle: systemOverlayStyle,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      overlayHeader: overlayHeader,
      headerExtension: headerExtension,
      collapsibleTitle: collapsibleTitle,
      collapsibleActions: suffixes,
      bottomBar: bottomBar,
      // Root semantics (Forui root header): left-aligned interactive title.
      // The nested variant centers the title under an IgnorePointer, which
      // killed tap targets like the home profile switcher.
      header: overlayHeader
          ? HyperosOverlayNestedHeader(
              suffixes: suffixes ?? const [],
              title: title,
            )
          : HyperosRootHeader(
              title: title,
              suffixes: suffixes ?? const [],
              padding: headerPadding ?? const EdgeInsets.fromLTRB(8, 0, 8, 2),
            ),
      child: child,
    );
  }
}

/// Wraps [FScaffold] + blurred top bar.
///
/// [HyperosSubpage] defaults to overlay layout so [BackdropFilter] can sample
/// scrollable content under the header (settings home and sub-routes).
///
/// When [overlayHeader] is true and [title] is a plain [Text], the shell uses
/// [HyperosCollapsibleTopAppBar] (Miuix-style large-title collapse). Complex
/// title widgets fall back to the nested frosted header.
/// 内嵌宿主标记：由底栏内嵌壳提供。被包裹的 [HyperosSubpage] 隐藏
/// 返回箭头——底栏点开的页没有「返回上一页」语义（坞常驻，页间切换
/// 走底栏；系统返回不拦内嵌页，与日/周课表同口径直接退出应用）。
/// 普通推入的路由不包此标记，行为不变。
class HyperosSubpageNoBack extends InheritedWidget {
  const HyperosSubpageNoBack({super.key, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HyperosSubpageNoBack>() !=
      null;

  @override
  bool updateShouldNotify(HyperosSubpageNoBack oldWidget) => false;
}

/// 底栏内嵌宿主注入的底部滚动余量：玻璃坞固定满屏悬浮后，任何内嵌
/// 页的可滚动内容都要能整体滑到悬浮药丸上方（与日/周课表的滚动余量
/// 同口径）。页面层无须逐页适配——[HyperosListView] 把列表底部内边距
/// 提升到本值（不小于自身默认底距）；不在坞内嵌宿主中的页面取 0，
/// 行为不变。新增内嵌页只要按惯例用 [HyperosListView] 即自动适配。
class GlassDockScrollReliefScope extends InheritedWidget {
  const GlassDockScrollReliefScope({
    super.key,
    required this.inset,
    required super.child,
  });

  /// 底部滚动余量（逻辑像素）：药丸固定占用 + 底部安全区。
  final double inset;

  static double insetOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<GlassDockScrollReliefScope>()
          ?.inset ??
      0;

  @override
  bool updateShouldNotify(GlassDockScrollReliefScope oldWidget) =>
      oldWidget.inset != inset;
}

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
    this.collapsibleLargeTitle = true,
    this.bottomBar,
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

  /// When true (default) and [title] is plain [Text], uses
  /// [HyperosCollapsibleTopAppBar]. Set false for split preview+editor pages
  /// (course card / timetable page settings) where a lower list must not drive
  /// large-title collapse.
  final bool collapsibleLargeTitle;

  /// See [HyperosRootPage.bottomBar].
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    final collapsibleTitle = collapsibleLargeTitle
        ? hyperosExtractPageTitleText(title)
        : null;
    final Widget? navigationIcon;
    // 底栏内嵌宿主里的子页不渲染返回键（见 [HyperosSubpageNoBack]）。
    final showBack = onBack != null && !HyperosSubpageNoBack.of(context);
    if (showBack) {
      navigationIcon = HyperosIconButton(
        icon: Icons.arrow_back,
        onPressed: onBack,
      );
    } else if (prefixes != null && prefixes!.isNotEmpty) {
      navigationIcon = Row(mainAxisSize: MainAxisSize.min, children: prefixes!);
    } else {
      navigationIcon = null;
    }

    return _HyperosBlurredPage(
      childPad: childPad,
      overlayHeader: overlayHeader,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      headerExtension: headerExtension,
      collapsibleTitle: collapsibleTitle,
      collapsibleNavigationIcon: navigationIcon,
      collapsibleActions: suffixes,
      bottomBar: bottomBar,
      header: HyperosOverlayNestedHeader(
        prefixes:
            prefixes ??
            [
              if (showBack)
                HyperosIconButton(icon: Icons.arrow_back, onPressed: onBack),
            ],
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
    this.systemOverlayStyle,
    this.resizeToAvoidBottomInset = false,
    this.overlayHeader = true,
    this.collapsibleTitle,
    this.collapsibleNavigationIcon,
    this.collapsibleActions,
    this.bottomBar,
  });

  final Widget header;
  final Widget? headerExtension;
  final Widget child;
  final bool childPad;
  final Color? backgroundColor;
  final BoxDecoration? headerDecoration;
  final SystemUiOverlayStyle? systemOverlayStyle;
  final bool resizeToAvoidBottomInset;
  final bool overlayHeader;

  /// When non-null and [overlayHeader] is true, drives
  /// [HyperosCollapsibleTopAppBar] instead of the nested frosted header.
  final String? collapsibleTitle;
  final Widget? collapsibleNavigationIcon;
  final List<Widget>? collapsibleActions;
  final Widget? bottomBar;

  @override
  State<_HyperosBlurredPage> createState() => _HyperosBlurredPageState();
}

class _HyperosBlurredPageState extends State<_HyperosBlurredPage> {
  /// Scroll offset above which frosted header replaces solid page background.
  static const scrollFrostThreshold = 0.5;

  late final HyperosRouteBlurGate _routeBlurGate;
  late final HyperosHeaderFrostFromScroll _headerFrost;
  late final HyperosOverlayHeaderMetrics _overlayMetrics;
  late final HyperosExitUntilCollapsedScrollBehavior _collapsibleScrollBehavior;

  /// Keeps the collapsible bar's State alive across frost flips.
  /// [HyperosFrostedHeaderShell] swaps between structurally different
  /// subtrees (liquid glass ↔ frosted background) when the frost state
  /// toggles; without this key the bar element is torn down and re-inflated
  /// — the small-title animation restarts from transparent (visible blink)
  /// and the large-title measurement is lost mid-gesture.
  final GlobalKey _collapsibleBarKey = GlobalKey();

  /// Difference applied to the body top inset by the collapsed large title.
  /// `0` while expanded, or on pages whose scroll position holds the collapse
  /// (offset tracks pixels 1:1). `-expansion` once a short page parks the
  /// title collapsed while its scroll position rests at the top — the resting
  /// gap then matches the small-title bar instead of the expanded one.
  ///
  /// A [ValueNotifier] driving [Transform.translate] directly: the value
  /// changes on every spring-back frame and must land in the SAME frame as
  /// the scroll update — routing it through a page-level deferred setState
  /// applied it one frame late, which read as visible stutter.
  final ValueNotifier<double> _collapseInsetDelta = ValueNotifier<double>(0);

  /// setState guarded against build/layout/paint phases. Post-frame callbacks
  /// run at the end of the current frame; see the note below about not
  /// calling [SchedulerBinding.scheduleFrame] here.
  void _deferredSetState() {
    if (!mounted) {
      return;
    }
    // setState is safe in idle and post-frame phases. Defer only while the
    // pipeline is mid build/layout/paint.
    //
    // Do NOT call [SchedulerBinding.scheduleFrame] here: during
    // build/layout/paint it throws "Build scheduled during frame" in debug
    // (e.g. route-animation listeners notifying while the transition paints).
    // Post-frame callbacks already run at the end of the current frame.
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.transientCallbacks ||
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
  }

  @override
  void initState() {
    super.initState();

    _routeBlurGate = HyperosRouteBlurGate(
      isLiveBlurActive: () => widget.overlayHeader,
      onChanged: () {
        _deferredSetState();
        _headerFrost.scheduleResyncHeaderFrostAfterLayout();
      },
      onDidPopNext: () {
        _headerFrost.scheduleResyncHeaderFrostAfterLayout();
      },
    );
    _headerFrost = HyperosHeaderFrostFromScroll(
      useOverlayLayout: () => widget.overlayHeader,
      onChanged: _deferredSetState,
      frostThresholdOverride: _collapsibleFrostThreshold,
    );
    _overlayMetrics = HyperosOverlayHeaderMetrics(
      useOverlayLayout: () => widget.overlayHeader,
      hasHeaderExtension: () => widget.headerExtension != null,
      useCollapsibleTopAppBar: () => _useCollapsibleTopAppBar,
      collapsibleBarSettled: _collapsibleBarSettled,
      onChanged: _deferredSetState,
    );
    // Page shell listens above nested list NotificationListeners → accept any depth.
    _collapsibleScrollBehavior = HyperosExitUntilCollapsedScrollBehavior(
      requireOuterScrollable: false,
    );
    _bindCollaboratorHosts();
  }

  void _bindCollaboratorHosts() {
    _routeBlurGate.isMounted = () => mounted;
    _headerFrost.isMounted = () => mounted;
    _overlayMetrics.isMounted = () => mounted;
  }

  bool get _useOverlayLayout => widget.overlayHeader;

  /// Measurement gate for [HyperosOverlayHeaderMetrics.collapsibleBarSettled]:
  /// `null` until the bar publishes its large-title expansion (its height is
  /// still the collapsed placeholder — recording it froze the inset at the
  /// small height and read as a jump once the title expanded), `false` while
  /// mid-collapse (the inset must keep the expanded height), `true` at rest.
  bool? _collapsibleBarSettled() {
    final state = _collapsibleScrollBehavior.state;
    final limit = state.heightOffsetLimit;
    if (!limit.isFinite || limit >= 0) {
      return null;
    }
    final offset = state.heightOffset;
    return offset.isFinite && offset.abs() < 0.5;
  }

  bool get _backdropBlurEnabled => _routeBlurGate.backdropBlurEnabled;

  bool get _useCollapsibleTopAppBar =>
      widget.overlayHeader &&
      widget.collapsibleTitle != null &&
      widget.collapsibleTitle!.isNotEmpty;

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
      if (_useCollapsibleTopAppBar) {
        _collapsibleScrollBehavior.handleScroll(notification);
        // Keep the inset delta fresh before the frost check below reads it.
        _syncCollapseInsetDelta(notification);
      }
      if (!_collapsibleScrollBehavior.isSnapInProgress &&
          !_collapsibleScrollBehavior.isSnapCooldown) {
        _headerFrost.syncHeaderFrostForScroll(notification.metrics.pixels);
      } else if (notification is ScrollEndNotification) {
        // The snap completion callback may run before this final notification
        // reaches the page shell. Resync once the scroll activity is settled,
        // while keeping the frost state stable during the snap itself.
        _headerFrost.scheduleResyncHeaderFrostAfterLayout();
      }
    }
    return false;
  }

  /// Frost threshold for collapsible large-title pages.
  ///
  /// While the large title is collapsing, the band bottom and the content top
  /// move in sync — nothing is under the header yet, so the bar must keep the
  /// plain page color (no blur, no tint flip). Content only tucks under the
  /// band after scrolling past the large-title zone; that zone shrinks
  /// together with the body inset once a short page parks the title small.
  /// The fixed 0.5px default would frost on the first scrolled pixel and then
  /// flash back seconds later when the overscroll spring's asymptotic tail
  /// finally crossed back under it.
  double? _collapsibleFrostThreshold() {
    if (!_useCollapsibleTopAppBar) {
      return null;
    }
    final limit = _collapsibleScrollBehavior.state.heightOffsetLimit;
    if (!limit.isFinite || limit >= 0) {
      // Expansion unmeasured — suppress frost instead of flashing early.
      return double.infinity;
    }
    final threshold =
        -limit +
        _collapseInsetDelta.value +
        HyperosCollapsibleTopAppBarDefaults.largeTitleBottomPadding +
        // Content rests this much lower than the upstream layout (see
        // largeTitleContentGap) — frost must not light up until the content
        // edge actually reaches the band.
        HyperosCollapsibleTopAppBarDefaults.largeTitleContentGap;
    return threshold < scrollFrostThreshold ? scrollFrostThreshold : threshold;
  }

  /// Tracks how much the collapsed large title should shrink the body inset.
  ///
  /// `delta = heightOffset + clamp(pixels - min, 0, expansion)`:
  /// - Scrollable pages: offset tracks pixels 1:1 inside the collapse zone →
  ///   delta stays 0 → inset keeps the expanded height (content scrolls under
  ///   the bar as before).
  /// - Short pages: after release the title stays collapsed while pixels
  ///   spring back to 0 → delta settles at `-expansion` → content rests right
  ///   below the small-title bar. During the spring-back the shrinking inset
  ///   compensates the returning pixels, so content stays visually pinned.
  ///
  /// Gestures that *start* from the parked-small state skip the pixel
  /// compensation ([_insetFollowsGesture] = false): the inset stays frozen at
  /// `-expansion` so content follows the finger under the band instead of
  /// being dead-pinned, and rubber-bands back naturally on release.
  bool _insetFollowsGesture = true;

  void _syncCollapseInsetDelta(ScrollNotification notification) {
    final metrics = notification.metrics;
    final state = _collapsibleScrollBehavior.state;
    final limit = state.heightOffsetLimit;
    final expansion = limit.isFinite ? -limit : 0.0;
    final pixels = metrics.pixels - metrics.minScrollExtent;
    var delta = 0.0;
    if (expansion > 0 && state.heightOffset.isFinite) {
      if (notification is ScrollStartNotification) {
        _insetFollowsGesture = _collapseInsetDelta.value > -expansion + 1.0;
      }
      final isBallisticFrame =
          notification is ScrollUpdateNotification &&
          notification.dragDetails == null;
      final shortPageSpringProgress = _collapsibleScrollBehavior
          .shortPageSpringProgressForPixels(metrics.pixels);
      if (_insetFollowsGesture &&
          isBallisticFrame &&
          state.heightOffset <= -expansion + 0.01 &&
          shortPageSpringProgress != null) {
        // Fully collapsed spring-back from deep overscroll: release the
        // parked inset proportionally over the whole spring travel so the
        // content decelerates with the spring and lands exactly as it
        // settles — instead of freezing dead the instant pixels < expansion.
        delta = -expansion * shortPageSpringProgress;
      } else {
        final scrolled = _insetFollowsGesture
            ? pixels.clamp(0.0, expansion)
            : 0.0;
        delta = (state.heightOffset + scrolled).clamp(-expansion, 0.0);
      }
    }
    if ((delta - _collapseInsetDelta.value).abs() < 0.1) {
      return;
    }
    // Normally a scroll notification fires in the idle phase → apply the delta
    // immediately so the body transform lands in the same frame. If instead it
    // arrives mid build/layout/paint (e.g. the first layout at a constrained
    // size in a widget test), defer to a post-frame callback so the
    // [ValueListenableBuilder] is not marked dirty during the current frame
    // ("Build scheduled during frame").
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.transientCallbacks ||
        phase == SchedulerPhase.postFrameCallbacks) {
      _collapseInsetDelta.value = delta;
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _collapseInsetDelta.value = delta;
        }
      });
    }
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
    _collapseInsetDelta.dispose();
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
    if (_useCollapsibleTopAppBar) {
      return HyperosCollapsibleTopAppBar(
        key: _collapsibleBarKey,
        title: widget.collapsibleTitle!,
        color: Colors.transparent,
        scrollBehavior: _collapsibleScrollBehavior,
        navigationIcon: widget.collapsibleNavigationIcon,
        actions: widget.collapsibleActions,
        bottomContent: widget.headerExtension,
      );
    }
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
      child: ScrollConfiguration(
        behavior: const HyperosScrollBehavior(),
        child: child,
      ),
    );
    // Always listen: edge haptics + snap-back are not limited to frosted overlay
    // pages. HyperosScrollBehavior also hooks each Scrollable as a second path.
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          widget.systemOverlayStyle ??
          HyperosColors.systemOverlayForBackground(pageBackground),
      child: Scaffold(
        resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
        backgroundColor: pageBackground,
        bottomNavigationBar: widget.bottomBar == null
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [widget.bottomBar!],
              ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top + 44,
              ),
              child: _buildBody(
                pageBackground: pageBackground,
                child: widget.childPad
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: widget.child,
                      )
                    : widget.child,
              ),
            ),
            Positioned(top: 0, left: 0, right: 0, child: header),
          ],
        ),
      ),
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
    // Collapsed large title shifts the body up to the small-title resting gap
    // via a PAINT translation, never via the scope inset / list padding:
    // changing the scroll content's padding mid-overscroll forces a relayout,
    // and _RenderSingleChildViewport.performLayout silently clamps
    // out-of-range pixels back to the boundary (correctBy, no notification)
    // — which restarted the spring from 0 every frame and made the whole
    // page thrash. Transform.translate is paint-only: no relayout, no clamp.
    final headerInset = _overlayMetrics.overlayContentTopInset(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          widget.systemOverlayStyle ??
          HyperosColors.systemOverlayForBackground(pageBackground),
      child: Scaffold(
        resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
        backgroundColor: pageBackground,
        bottomNavigationBar: widget.bottomBar == null
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [widget.bottomBar!],
              ),
        body: _buildHeaderScope(
          contentTopInset: headerInset,
          routeBlurEnabled: _backdropBlurEnabled,
          headerBackgroundColor: pageBackground,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: ValueListenableBuilder<double>(
                  valueListenable: _collapseInsetDelta,
                  child: _buildBody(
                    pageBackground: pageBackground,
                    child: widget.child,
                  ),
                  builder: (context, delta, body) {
                    return Transform.translate(
                      offset: Offset(0, delta),
                      child: body,
                    );
                  },
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
/// Provide either:
/// - [children] for light / form pages — [SingleChildScrollView] + [Column]
///   so every child stays mounted while scrolling ([ListView] still
///   disposes off-screen rows, which can blank [TextField] text until
///   re-focus).
/// - [itemCount] + [itemBuilder] for heavy settings subpages that need lazy
///   per-section construction.
class HyperosListView extends StatefulWidget {
  const HyperosListView({
    super.key,
    this.children,
    this.itemCount,
    this.itemBuilder,
    this.padding,
    this.includeHeaderInset = true,
    this.blockVerticalScrollBubbling,
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

  /// When true, vertical [ScrollNotification]s do not bubble to ancestors.
  /// Defaults to `!includeHeaderInset` (preview+editor split). Set false when
  /// an outer shell (e.g. Miuix TopAppBar) must receive scroll for collapse.
  final bool? blockVerticalScrollBubbling;

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
    // 玻璃坞内嵌宿主的底部滚动余量：列表末尾要能整体滑到悬浮药丸
    // 上方，余量小于自身默认底距时不生效。
    final dockRelief = GlassDockScrollReliefScope.insetOf(context);
    final bottom = dockRelief > base.bottom ? dockRelief : base.bottom;
    // Initial content sits below the overlay header; scrolling still passes
    // rows under the frosted bar once this padding scrolls away.
    if (!widget.includeHeaderInset) {
      return EdgeInsets.fromLTRB(base.left, base.top, base.right, bottom);
    }
    final headerInset = HyperosBlurredHeaderScope.insetOf(context);
    if (headerInset <= 0) {
      return EdgeInsets.fromLTRB(base.left, base.top, base.right, bottom);
    }
    return EdgeInsets.fromLTRB(
      base.left,
      base.top + headerInset,
      base.right,
      bottom,
    );
  }

  @override
  Widget build(BuildContext context) {
    final listKey = widget.pageStorageKey ?? _pageStorageKeyFromRoute(context);
    final scrollPhysics = HyperosOverscrollPhysics(
      parent: const AlwaysScrollableScrollPhysics(),
      topInset: widget.includeHeaderInset
          ? HyperosBlurredHeaderScope.insetOf(context)
          : 0,
    );
    final listPadding = _resolveListPadding(context);

    // [children] mode: SingleChildScrollView + Column keeps every child
    // mounted (forms / TextFields). Plain ListView(children:) still only
    // mounts the visible window and disposes the rest.
    // [itemBuilder] mode: keep lazy builder for long lists.
    final Widget list;
    final children = widget.children;
    if (children != null) {
      list = SingleChildScrollView(
        key: listKey,
        physics: scrollPhysics,
        padding: listPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );
    } else {
      list = ListView.builder(
        key: listKey,
        physics: scrollPhysics,
        padding: listPadding,
        itemCount: widget.itemCount,
        itemBuilder: widget.itemBuilder!,
      );
    }

    Widget scrollable = _HyperosListScrollHost(
      child: hyperosBlockStretchOverscroll(
        child: ScrollConfiguration(
          behavior: const HyperosScrollBehavior(),
          child: list,
        ),
      ),
    );

    // Fixed preview + editor split: the lower list does not sit under the
    // frosted title. Stop vertical scroll from bubbling so it cannot drive
    // large-title collapse or header frost (avoids distant-preview flicker).
    final blockBubbling =
        widget.blockVerticalScrollBubbling ?? !widget.includeHeaderInset;
    if (blockBubbling) {
      scrollable = NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis == Axis.vertical) {
            return true;
          }
          return false;
        },
        child: scrollable,
      );
    }

    return scrollable;
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
