import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/timetable_settings.dart';
import '../../../utils/home_page_background.dart';
import '../hyperos_blurred_header.dart';

/// Overlap between adjacent home frosted bands to hide backdrop seams.
const homePageFrostedRegionSeamOverlap = 4.0;

bool homePageUsesUnifiedChromeBlur(
  TimetableSettings settings, {
  required bool hasBackdrop,
}) {
  return hasBackdrop &&
      settings.homePageHeaderBlurEnabled &&
      settings.homePageWeekdayBarBlurEnabled &&
      settings.homePageTimeColumnBlurEnabled;
}

HomePageBackgroundVisual homePageRegionChromeVisual({
  required TimetableSettings settings,
  required bool isDark,
  required Color darkFallback,
  required int region,
  required bool chromeBlurEnabled,
}) {
  if (chromeBlurEnabled && hasHomePageBackdropImage(settings, isDark: isDark)) {
    return const HomePageBackgroundVisual(color: Colors.transparent);
  }
  return resolveHomePageRegionBackground(
    settings: settings,
    isDark: isDark,
    darkFallback: darkFallback,
    region: region,
  );
}

/// Frosted band behind the stacked home header (status bar + title row).
class HomePageHeaderBlurBand extends StatelessWidget {
  const HomePageHeaderBlurBand({
    required this.enabled,
    this.includeStatusBar = true,
    this.extendBottom = 0,
    super.key,
  });

  final bool enabled;
  final bool includeStatusBar;
  final double extendBottom;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return const SizedBox.shrink();
    }
    final useBlur = HyperosBlurredHeader.backdropBlurEnabled(context);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height:
          homePageHeaderBandHeight(
            context,
            includeStatusBar: includeStatusBar,
          ) +
          extendBottom,
      child: IgnorePointer(
        child: FrostedHeaderBackground(
          blurEnabled: useBlur,
          blurSigma: HyperosBlurredHeader.blurSigmaOf(context),
          tint: HyperosBlurredHeader.homePageRegionTintColor(
            context,
            withBlur: useBlur,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Solid mask over the status bar when backdrop scope excludes it.
class HomePageStatusBarBackdropMask extends StatelessWidget {
  const HomePageStatusBarBackdropMask({required this.color, super.key});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.paddingOf(context).top;
    if (height <= 0) {
      return const SizedBox.shrink();
    }
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: height,
      child: ColoredBox(color: color),
    );
  }
}

/// Single frosted L-shape for weekday bar + time column (continuous blur).
class HomePageUnifiedWeekFrostedOverlay extends StatelessWidget {
  const HomePageUnifiedWeekFrostedOverlay({
    required this.weekdayBarHeight,
    required this.timeColumnWidth,
    this.overlapTop = 0,
    super.key,
  });

  final double weekdayBarHeight;
  final double timeColumnWidth;
  final double overlapTop;

  @override
  Widget build(BuildContext context) {
    final useBlur = HyperosBlurredHeader.backdropBlurEnabled(context);
    final frosted = LayoutBuilder(
      builder: (context, constraints) {
        return ClipPath(
          clipper: _HomePageWeekChromeClipper(
            weekdayBarHeight: weekdayBarHeight + overlapTop,
            timeColumnWidth: timeColumnWidth,
          ),
          child: FrostedHeaderBackground(
            blurEnabled: useBlur,
            blurSigma: HyperosBlurredHeader.blurSigmaOf(context),
            tint: HyperosBlurredHeader.homePageRegionTintColor(
              context,
              withBlur: useBlur,
            ),
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight + overlapTop,
            ),
          ),
        );
      },
    );
    if (overlapTop <= 0) {
      return IgnorePointer(child: frosted);
    }
    return IgnorePointer(
      child: Transform.translate(
        offset: Offset(0, -overlapTop),
        child: frosted,
      ),
    );
  }
}

class _HomePageWeekChromeClipper extends CustomClipper<Path> {
  const _HomePageWeekChromeClipper({
    required this.weekdayBarHeight,
    required this.timeColumnWidth,
  });

  final double weekdayBarHeight;
  final double timeColumnWidth;

  @override
  Path getClip(Size size) {
    final weekdayRect = Rect.fromLTWH(0, 0, size.width, weekdayBarHeight);
    final timeColumnRect = Rect.fromLTWH(
      0,
      weekdayBarHeight,
      timeColumnWidth,
      math.max(0, size.height - weekdayBarHeight),
    );
    return Path()
      ..addRect(weekdayRect)
      ..addRect(timeColumnRect);
  }

  @override
  bool shouldReclip(covariant _HomePageWeekChromeClipper oldClipper) {
    return oldClipper.weekdayBarHeight != weekdayBarHeight ||
        oldClipper.timeColumnWidth != timeColumnWidth;
  }
}

/// Optional frosted backdrop for a home timetable region over wallpaper.
class HomePageFrostedRegion extends StatelessWidget {
  const HomePageFrostedRegion({
    required this.enabled,
    required this.child,
    this.overlapTop = 0,
    super.key,
  });

  final bool enabled;
  final Widget child;
  final double overlapTop;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }
    final useBlur = HyperosBlurredHeader.backdropBlurEnabled(context);
    final frosted = ClipRect(
      child: FrostedHeaderBackground(
        blurEnabled: useBlur,
        blurSigma: HyperosBlurredHeader.blurSigmaOf(context),
        tint: HyperosBlurredHeader.homePageRegionTintColor(
          context,
          withBlur: useBlur,
        ),
        child: child,
      ),
    );
    if (overlapTop <= 0) {
      return frosted;
    }
    return Transform.translate(offset: Offset(0, -overlapTop), child: frosted);
  }
}
