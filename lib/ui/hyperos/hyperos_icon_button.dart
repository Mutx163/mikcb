import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'hyperos_miuix_spec.dart';
import 'hyperos_theme.dart';

/// HyperOS / Miuix circular icon button (40×40, full round hit target).
class HyperosIconButton extends StatelessWidget {
  const HyperosIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.iconSize = 24,
    this.color,
    this.splashRadius,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double iconSize;
  final Color? color;
  final double? splashRadius;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final iconColor = color ?? HyperosColors.onSurface(context);
    final splash = HyperosColors.surfaceContainerHigh(context);

    final button = Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                onPressed!();
              }
            : null,
        splashColor: splash,
        highlightColor: splash.withValues(alpha: 0.6),
        radius: splashRadius ?? HyperosMiuixIconButton.cornerRadius / 2,
        child: SizedBox(
          width: HyperosMiuixIconButton.minWidth,
          height: HyperosMiuixIconButton.minHeight,
          child: Icon(
            icon,
            size: iconSize,
            color: enabled ? iconColor : iconColor.withValues(alpha: 0.38),
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
