import 'package:flutter/material.dart';

import 'hyperos_miuix_spec.dart';
import 'hyperos_theme.dart';

/// HyperOS-styled tooltip wrapper.
class HyperosTooltip extends StatelessWidget {
  const HyperosTooltip({
    super.key,
    required this.message,
    required this.child,
    this.waitDuration = const Duration(milliseconds: 500),
    this.preferBelow = true,
  });

  final String message;
  final Widget child;
  final Duration waitDuration;
  final bool preferBelow;

  @override
  Widget build(BuildContext context) {
    final background = HyperosColors.inverseSurface(context);
    final textColor = HyperosColors.onInverseSurface(context);

    return Tooltip(
      message: message,
      waitDuration: waitDuration,
      preferBelow: preferBelow,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: TextStyle(
        fontSize: HyperosMiuixTypography.footnote1,
        color: textColor,
      ),
      child: child,
    );
  }
}
