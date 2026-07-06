import 'package:flutter/material.dart';

import '../../services/android_animation_scale_service.dart';
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

  static Duration get transitionDuration =>
      AndroidAnimationScaleService.scaledDuration(
        HyperosMiuixNavigation.transitionDurationMs,
      );

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

  /// Left-edge corner radius factor during slide (0 when the route is settled).
  @visibleForTesting
  static double transitionCornerRadiusFactor(double progress) {
    if (progress <= 0 || progress >= 1) {
      return 0;
    }
    return 1 - progress;
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
  /// The incoming page clips to the display corner radius on the left edge and
  /// casts a soft drop shadow onto the page below (left-bottom, overhead light).
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
      end: Offset(-HyperosMiuixNavigation.exitSlideFraction, 0),
    ).animate(parallaxCurve);

    return SlideTransition(
      position: parallaxSlide,
      child: SlideTransition(
        position: enterSlide,
        child: _HyperosParallaxBleed(
          secondaryAnimation: secondaryAnimation,
          child: _HyperosTransitionPageShell(
            animation: animation,
            child: child,
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
              Positioned.fill(child: ColoredBox(color: surface)),
              SizedBox(width: width, child: child),
            ],
          ),
        );
      },
      child: child,
    );
  }
}

/// Left-edge rounded clip + card drop shadow for the sliding sub-page.
class _HyperosTransitionPageShell extends StatelessWidget {
  const _HyperosTransitionPageShell({
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cornerRadius = AndroidAnimationScaleService.displayCornerRadiusDp;
    final surface = HyperosColors.scaffoldBackground(context);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final progress = animation.value;
        final cornerFactor = HyperosNavigation.transitionCornerRadiusFactor(
          progress,
        );
        final effectiveRadius = cornerRadius * cornerFactor;
        final clipRadius = BorderRadius.only(
          topLeft: Radius.circular(effectiveRadius),
          bottomLeft: Radius.circular(effectiveRadius),
        );
        final shadowStrength = HyperosNavigation.transitionShadowStrength(
          progress,
        );
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: clipRadius,
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
                      offset: Offset(
                        HyperosMiuixNavigation.pageShadowOffsetX,
                        HyperosMiuixNavigation.pageShadowOffsetY,
                      ),
                    ),
                  ],
          ),
          child: effectiveRadius <= 0
              ? child
              : ClipRRect(borderRadius: clipRadius, child: child),
        );
      },
      child: child,
    );
  }
}

/// Standard sub-page route for mikcb (settings, import, about, etc.).
class HyperosPageRoute<T> extends PageRouteBuilder<T> {
  HyperosPageRoute({
    required this.builder,
    super.settings,
    super.fullscreenDialog,
  }) : super(
         transitionDuration: HyperosNavigation.transitionDuration,
         reverseTransitionDuration: HyperosNavigation.transitionDuration,
         pageBuilder: (context, animation, secondaryAnimation) =>
             builder(context),
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           return HyperosNavigation.buildSharedAxisTransition(
             animation: animation,
             secondaryAnimation: secondaryAnimation,
             child: child,
           );
         },
       );

  final WidgetBuilder builder;

  @override
  bool get maintainState => true;

  @override
  bool get opaque => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;
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
