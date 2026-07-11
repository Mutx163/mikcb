import 'package:flutter/material.dart';

import 'hyperos_theme.dart';

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
    return RefreshIndicator(
      color: HyperosColors.primary(context),
      backgroundColor: HyperosColors.surfaceContainer(context),
      displacement: displacement,
      onRefresh: onRefresh,
      child: child,
    );
  }
}
