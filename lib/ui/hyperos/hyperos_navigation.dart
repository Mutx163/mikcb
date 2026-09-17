import 'package:flutter/material.dart';

import '../../utils/frame_perf_probe.dart';
import 'hyperos_motion.dart';
import 'hyperos_miuix_spec.dart';
import 'hyperos_theme.dart';

/// Observes route cover/pop so frosted headers restore blur after pop.
final RouteObserver<ModalRoute<void>> hyperosRouteObserver =
    RouteObserver<ModalRoute<void>>();

/// HyperOS / MIUI system-settings style page navigation.
///
/// Use [push] / [route] instead of [MaterialPageRoute] so every sub-page gets
/// the same opaque horizontal shared-axis transition and respects Android
/// `Transition animation scale`.
abstract final class HyperosNavigation {
  static const Curve transitionCurve = HyperosMiuixNavigation.transitionCurve;

  static Duration transitionDurationOf(BuildContext context) =>
      HyperosMotionScope.of(
        context,
      ).scaledDuration(HyperosMiuixNavigation.transitionDurationMs);

  static Duration get transitionDuration =>
      HyperosMotionPlatform.transitionDuration;

  /// Persists user speed preference and refreshes active route controllers.
  static void applyUserTransitionSpeed(BuildContext context, double speed) {
    HyperosMotionScope.of(context).applyUserTransitionSpeed(speed);
  }

  /// Theme hook for apps that still construct [MaterialPageRoute] somewhere.
  ///
  /// Duration still comes from [HyperosPageRoute]; prefer [route] directly.
  static PageTransitionsTheme get pageTransitionsTheme {
    return PageTransitionsTheme(
      builders: {
        for (final platform in TargetPlatform.values)
          platform: const HyperosPageTransitionsBuilder(),
      },
    );
  }

  /// Builds a [HyperosPageRoute] for [Navigator.push] call sites.
  static Route<T> route<T>({
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) {
    return HyperosPageRoute<T>(settings: settings, builder: builder);
  }

  static Future<T?> push<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) {
    return Navigator.of(
      context,
    ).push<T>(route<T>(builder: builder, settings: settings));
  }

  static Future<T?> pushWidget<T>(
    BuildContext context,
    Widget page, {
    RouteSettings? settings,
  }) {
    return push<T>(context, builder: (_) => page, settings: settings);
  }

  static Future<T?> pushReplacement<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) {
    return Navigator.of(context).pushReplacement<T, dynamic>(
      route<T>(builder: builder, settings: settings),
    );
  }

  /// Peak shadow strength while the route is mid-transition (0 at rest).
  @visibleForTesting
  static double transitionShadowStrength(double progress) {
    if (progress <= 0 || progress >= 1) {
      return 0;
    }
    return 4 * progress * (1 - progress);
  }

  /// Whether the primary route animation is still running (not settled).
  ///
  /// Prefer this over raw progress for clip decisions: floating-point values
  /// near 0/1 can leave a tiny radius that shows as a half-rounded edge in
  /// screenshots after the page has visually finished sliding.
  @visibleForTesting
  static bool isPrimaryTransitionActive(AnimationStatus status) {
    return status == AnimationStatus.forward ||
        status == AnimationStatus.reverse;
  }

  /// Corner-radius factor for the sliding page while the primary animation runs.
  ///
  /// Returns 0 at settled endpoints. While moving, stays near full radius so the
  /// page enters as a rounded card, then drops only in the final settle band.
  @visibleForTesting
  static double transitionCornerRadiusFactor(double progress) {
    if (progress <= 0 || progress >= 1) {
      return 0;
    }
    // Keep nearly full radius for most of the slide; ease out only near rest
    // so settle never leaves a visible half-corner clip.
    const settleBand = 0.12;
    if (progress <= settleBand) {
      // Reverse (pop): radius grows as the page leaves.
      return progress / settleBand;
    }
    if (progress >= 1 - settleBand) {
      // Forward (push): radius shrinks only at the end.
      return (1 - progress) / settleBand;
    }
    return 1;
  }

  /// Viewport width plus right-side bleed so parallax exit never exposes routes
  /// below in the [Navigator] stack.
  @visibleForTesting
  static double parallaxBleedWidth(double viewportWidth) {
    return viewportWidth * (1 + HyperosMiuixNavigation.exitSlideFraction);
  }

  /// Opaque horizontal shared-axis transition — no fade-through so pages never
  /// become transparent like MIUI / HyperOS system settings.
  ///
  /// While the route is animating, the incoming page is clipped to the display
  /// corner radius (card-like) and casts a soft drop shadow. After settle the
  /// clip is removed so normal use and screenshots stay square-edged.
  static Widget buildSharedAxisTransition({
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Widget child,
  }) {
    final enterCurve = CurvedAnimation(
      parent: animation,
      curve: transitionCurve,
      reverseCurve: transitionCurve,
    );
    final parallaxCurve = CurvedAnimation(
      parent: secondaryAnimation,
      curve: transitionCurve,
      reverseCurve: transitionCurve,
    );

    final enterSlide = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(enterCurve);
    final parallaxSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-HyperosMiuixNavigation.exitSlideFraction, 0),
    ).animate(parallaxCurve);

    return SlideTransition(
      position: parallaxSlide,
      child: SlideTransition(
        position: enterSlide,
        child: _HyperosParallaxBleed(
          secondaryAnimation: secondaryAnimation,
          child: _HyperosTransitionPageShell(
            animation: animation,
            // 帧缓存边界：转场期间 shell 每帧都要改「圆角裁切 + 投影」。
            // 框架给 route 那个 RepaintBoundary（routes.dart 的 `_page`）把
            // buildPage **整个包在里面**——也就是把本 shell 也包进去了，
            // 于是裁切/投影一变，它下面的整页像素照旧逐帧重栅格化。
            // 这里把页面本体单独隔离：转场期间只重新合成「裁切 + 投影」，
            // 页面像素直接复用，滑入/滑出不再重画整页。
            child: RepaintBoundary(child: child),
          ),
        ),
      ),
    );
  }
}

/// Extends the route surface to the right while the route is being covered so
/// parallax exit never reveals routes below in the [Navigator] stack.
class _HyperosParallaxBleed extends StatelessWidget {
  const _HyperosParallaxBleed({
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: secondaryAnimation,
      builder: (context, child) {
        if (secondaryAnimation.value <= 0.001) {
          return child!;
        }
        final surface = HyperosColors.scaffoldBackground(context);
        final width = MediaQuery.sizeOf(context).width;
        if (width <= 0) {
          return child!;
        }
        final bleedWidth = HyperosNavigation.parallaxBleedWidth(width);
        return SizedBox(
          width: bleedWidth,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              // 补底只铺**会被露出的那一条**（页面右侧 bleed 出来的部分）：
              // 整块 1.25× 视口铺底里，[0, width] 这一段始终被不透明页面盖住，
              // 铺它是每帧白填一整屏。补底本身不能省 —— 它负责让视差滑出后
              // 不露出 Navigator 里更下一层的路由。
              Positioned(
                left: width,
                top: 0,
                bottom: 0,
                width: bleedWidth - width,
                child: ColoredBox(color: surface),
              ),
              SizedBox(width: width, child: child),
            ],
          ),
        );
      },
      child: child,
    );
  }
}

/// Rounded clip + card drop shadow only while the route is mid-transition.
///
/// Once [AnimationStatus.completed] / [AnimationStatus.dismissed], returns the
/// bare child so screenshots never show residual half-corner clips.
class _HyperosTransitionPageShell extends StatelessWidget {
  const _HyperosTransitionPageShell({
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Prefer a dedicated transition radius so the card-like slide is obvious;
    // never smaller than the device display corner when the OS reports a larger one.
    final displayRadius = HyperosMotionScope.of(context).displayCornerRadiusDp;
    final cornerRadius =
        displayRadius > HyperosMiuixNavigation.pageTransitionCornerRadius
        ? displayRadius
        : HyperosMiuixNavigation.pageTransitionCornerRadius;
    final surface = HyperosColors.scaffoldBackground(context);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final status = animation.status;
        if (!HyperosNavigation.isPrimaryTransitionActive(status)) {
          // Settled: no ClipRRect / no rounded DecoratedBox.
          return child!;
        }

        final progress = animation.value.clamp(0.0, 1.0);
        final cornerFactor = HyperosNavigation.transitionCornerRadiusFactor(
          progress,
        );
        final effectiveRadius = cornerRadius * cornerFactor;
        // Full card corners while sliding (not only the left edge).
        final clipRadius = BorderRadius.circular(effectiveRadius);
        final shadowStrength = HyperosNavigation.transitionShadowStrength(
          progress,
        );

        if (effectiveRadius <= 0.5 && shadowStrength <= 0) {
          return child!;
        }

        Widget page = child!;
        if (effectiveRadius > 0.5) {
          page = ClipRRect(
            borderRadius: clipRadius,
            child: page,
          );
        }

        // 投影**不**单独成层：曾试过把它拆出来、用 Opacity 表达强度（让模糊
        // 只算一次），真机实测对「进入设置页的长帧」没有可测改善
        // （523/498/432ms vs 基线 440/523/531ms），反而每次转场多挂一块全屏
        // 缓存层 —— 而实测那时的瓶颈正是「每次打开都分配上百 MB 离屏目标」，
        // 加层方向相反，故回退到与不透明底同一层绘制。
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: effectiveRadius > 0.5 ? clipRadius : null,
            color: surface,
            boxShadow: shadowStrength <= 0
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha:
                            HyperosMiuixNavigation.pageShadowAlpha *
                            shadowStrength,
                      ),
                      blurRadius: HyperosMiuixNavigation.pageShadowBlur,
                      offset: const Offset(
                        HyperosMiuixNavigation.pageShadowOffsetX,
                        HyperosMiuixNavigation.pageShadowOffsetY,
                      ),
                    ),
                  ],
          ),
          child: page,
        );
      },
      child: child,
    );
  }
}

/// Standard sub-page route for mikcb (settings, import, about, etc.).
class HyperosPageRoute<T> extends PageRoute<T> {
  static final Set<HyperosPageRoute<dynamic>> _activeRoutes = {};

  HyperosPageRoute({
    required this.builder,
    super.settings,
    super.fullscreenDialog,
  });

  final WidgetBuilder builder;

  @override
  Duration get transitionDuration => HyperosNavigation.transitionDuration;

  @override
  Duration get reverseTransitionDuration =>
      HyperosNavigation.transitionDuration;

  @override
  bool get maintainState => true;

  @override
  bool get opaque => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  void install() {
    super.install();
    _activeRoutes.add(this);
  }

  /// 转场打点：把「这一次 push / pop」交给帧探针开一个读数窗口。
  ///
  /// 存在的理由：转场此前没有任何标记，卡顿只能从每 2 秒的 `steady` 基线和无标记的
  /// `burst` 里猜，无法把某一次跳转单独拎出来归因。而「新页面整棵树的首次构建」
  /// 与「转场第一帧」在框架里是同一帧（`routes.dart` 的 `_page ??=` 只调一次
  /// `buildPage`），首帧一重就整段动画掉帧 —— 有标记才分得清是首帧的账还是
  /// 整段动画每帧的账。
  ///
  /// 标记用 route name（未命名路由给 `unnamed`），与 `[frame-perf] mark` 行配套读。
  /// [FramePerfProbe] 在未安装时是空操作，release 里更是一行都不输出。
  String get _probeLabel => settings.name ?? 'unnamed';

  @override
  TickerFuture didPush() {
    FramePerfProbe.mark('route:push:$_probeLabel');
    return super.didPush();
  }

  /// [Navigator.pushReplacement] 走这条（`didPush` 不会被调），同样要打点。
  @override
  void didReplace(Route<dynamic>? oldRoute) {
    super.didReplace(oldRoute);
    FramePerfProbe.mark('route:replace:$_probeLabel');
  }

  @override
  bool didPop(T? result) {
    FramePerfProbe.mark('route:pop:$_probeLabel');
    return super.didPop(result);
  }

  @override
  void dispose() {
    _activeRoutes.remove(this);
    super.dispose();
  }

  /// Re-applies the current user/system transition speed to routes still on
  /// the navigator stack (their controllers are created once in [install]).
  static void syncTransitionDurations() {
    final duration = HyperosNavigation.transitionDuration;
    for (final route in _activeRoutes) {
      final controller = route.controller;
      if (controller == null) {
        continue;
      }
      controller.duration = duration;
      controller.reverseDuration = duration;
    }
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return HyperosNavigation.buildSharedAxisTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

/// [PageTransitionsTheme] adapter sharing [HyperosNavigation.buildSharedAxisTransition].
class HyperosPageTransitionsBuilder extends PageTransitionsBuilder {
  const HyperosPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return HyperosNavigation.buildSharedAxisTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}
