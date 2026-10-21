import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ui/hyperos/day_view_expand_motion.dart';
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
        // 曲线与时长是**一处**策略（见 [DayViewExpandMotion]）：这里不能再写死
        // 一条曲线，否则 `DayViewExpandMotion.baseMilliseconds` 调了时长、
        // 观感却还是旧曲线的配速。2026-10-21 就是这么从「一下就弹开」变成
        // 「能看到其他日期正在露出来」的。
        final progress = DayViewExpandMotion.curve.transform(
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
          // ⚠️ 面板**不套 Opacity**（2026-10-20 拆掉）：这块面板里是成片的
          // `CourseSurface` 玻璃卡（BackdropFilter 实时采样），而 BackdropFilter
          // 在半透明层里采不到身后内容 —— 磨砂整段塌成透明（CourseSurface 类
          // 注释的原文规则），落定瞬间 progress 到 1、透明层消失，磨砂又「啪」地
          // 弹回来：用户口径「展开/收完的瞬间变黑然后变白」。浮现的柔和交给
          // 几何本身（窗口从锚点尺寸长大 + 位移），边框/浮影的淡出在下面各自的
          // alpha 上（不是玻璃，不进离屏层）。
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
        );
      },
    );
  }
}
