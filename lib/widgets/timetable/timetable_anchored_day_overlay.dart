import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ui/hyperos/hyperos.dart';

/// 日视图从星期栏锚点展开/收起的壳（2026-10-19 从课表页 State 搬出）。
///
/// 只做位次/圆角/边框/阴影的动画；面板内容与展开动画由调用方注入。
class TimetableAnchoredDayOverlay extends StatelessWidget {
  final Widget panel;
  final Animation<double> expandAnimation;
  final double anchorAlignmentX;

  const TimetableAnchoredDayOverlay({
    super.key,
    required this.panel,
    required this.expandAnimation,
    required this.anchorAlignmentX,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return AnimatedBuilder(
      animation: expandAnimation,
      child: panel,
      builder: (context, child) {
        final progress = Curves.easeInOutCubicEmphasized.transform(
          expandAnimation.value,
        );
        final widthFactor = 0.18 + (0.82 * progress);
        final heightFactor = math.max(0.04, progress);
        final translateY = (1 - progress) * -24;
        final borderRadius = HyperosNavigation.anchorExpandRadius(progress);
        final borderColor = Color.lerp(
          colorScheme.outlineVariant,
          Colors.transparent,
          progress,
        )!;
        final shadowAlpha =
            (theme.brightness == Brightness.dark ? 0.08 : 0.06) *
            (1 - progress);

        return IgnorePointer(
          // Block only while the shell is still a tiny seed (open start / close
          // end). Waiting for 0.98 left the close button unhittable for most of
          // the open animation and flaky under widget-test pumps.
          ignoring: progress < 0.05,
          child: Opacity(
            opacity: Curves.easeOutCubic.transform(progress),
            child: ClipRRect(
              borderRadius: borderRadius,
              child: Align(
                alignment: Alignment(anchorAlignmentX, -1),
                widthFactor: widthFactor,
                heightFactor: heightFactor,
                child: Transform.translate(
                  offset: Offset(0, translateY),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(
                            alpha: shadowAlpha,
                          ),
                          blurRadius: 28 * (1 - progress),
                          offset: Offset(0, 12 * (1 - progress)),
                        ),
                      ],
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
