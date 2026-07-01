import 'dart:ui';

import 'package:flutter/material.dart';

/// 通用玻璃拟态（Glassmorphism）容器
///
/// 提供磨砂玻璃效果，支持自定义模糊度、透明度和边框。
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color? tintColor;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Border? border;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 10.0,
    this.opacity = 0.15,
    this.tintColor,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveTintColor =
        tintColor ?? colorScheme.surface.withValues(alpha: opacity);

    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: effectiveTintColor,
              borderRadius: borderRadius,
              border: border ??
                  Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                    width: 1,
                  ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 玻璃拟态弹窗内容包装
///
/// 在弹窗内部使用，不改变外部布局
class GlassModalContent extends StatelessWidget {
  final Widget child;

  const GlassModalContent({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: child,
      ),
    );
  }
}

/// 玻璃拟态卡片
///
/// 预设参数的快捷卡片组件
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: padding,
      margin: margin,
      borderRadius: BorderRadius.circular(20),
      child: onTap != null
          ? InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: child,
            )
          : child,
    );
  }
}
