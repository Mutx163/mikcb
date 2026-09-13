import 'package:flutter/material.dart';

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

        // 不透明底 + 圆角，**不含投影**；投影单独成层（见下）。
        final shell = DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: effectiveRadius > 0.5 ? clipRadius : null,
            color: surface,
          ),
          child: page,
        );
        if (shadowStrength <= 0) {
          return shell;
        }

        // 投影单独一层，并把「强度」从颜色 alpha 挪到 Opacity：
        // 滑行中段的圆角半径是常量（transitionCornerRadiusFactor 只在两端
        // settle band 收缩），所以投影形状在中段恒定 —— 放进 RepaintBoundary
        // 后**模糊只算一次**，之后每帧只是重新合成透明度。
        //
        // 原先把 alpha 乘进 BoxShadow 颜色、与不透明底写在同一个 BoxDecoration
        // 上，等于每一帧都重做一次**全屏**模糊：真机实测一次推页会在栅格侧留下
        // 440~530ms 的单个长帧、进程 RSS 瞬时 +279MB（约 20 块全屏缓冲），
        // 1.9s 后才释放；同一页从底栏内嵌进入（无转场）则既无长帧也只 +88MB。
        return Stack(
          // 投影画在页面之下；页面不透明，投影可见部分只有滑入那条边与圆角外侧。
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: shadowStrength.clamp(0.0, 1.0),
                child: RepaintBoundary(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: effectiveRadius > 0.5 ? clipRadius : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: HyperosMiuixNavigation.pageShadowAlpha,
                          ),
                          blurRadius: HyperosMiuixNavigation.pageShadowBlur,
                          offset: const Offset(
                            HyperosMiuixNavigation.pageShadowOffsetX,
                            HyperosMiuixNavigation.pageShadowOffsetY,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            shell,
          ],
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
