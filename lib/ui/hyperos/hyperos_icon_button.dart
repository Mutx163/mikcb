import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

/// HyperOS-style icon button — delegates to [MiuixIconButton].
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
    final effectiveEnabled = onPressed != null;
    final iconColor = color;
    final button = MiuixIconButton(
      onPressed: onPressed,
      enabled: effectiveEnabled,
      child: Icon(icon, size: iconSize, color: iconColor),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
