import 'package:flutter/material.dart';

import 'hyperos_miuix_spec.dart';

/// HyperOS pull-to-refresh wrapper (primary accent indicator).
class HyperosRefreshIndicator extends StatelessWidget {
  const HyperosRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.displacement = 36,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final double displacement;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark
        ? HyperosMiuixDarkColors.primary
        : HyperosMiuixLightColors.primary;

    return RefreshIndicator(
      color: color,
      backgroundColor: isDark
          ? HyperosMiuixDarkColors.surfaceContainer
          : HyperosMiuixLightColors.surfaceContainer,
      displacement: displacement,
      onRefresh: onRefresh,
      child: child,
    );
  }
}
