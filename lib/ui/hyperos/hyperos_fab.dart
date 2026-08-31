import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

/// HyperOS floating action button — delegates to [MiuixFloatingActionButton].
class HyperosFab extends StatelessWidget {
  const HyperosFab({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.mini = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool mini;

  @override
  Widget build(BuildContext context) {
    final size = mini ? 40.0 : 56.0;
    final iconSize = mini ? 22.0 : 26.0;
    final theme = MiuixTheme.of(context);

    // MiuixFAB 使用 onSurface 作为默认内容色，我们需要 onPrimary。
    final button = MiuixContentColor(
      color: theme.colors.onPrimary,
      child: MiuixFloatingActionButton(
        onPressed: onPressed,
        enabled: onPressed != null,
        minWidth: size,
        minHeight: size,
        child: Icon(icon, size: iconSize),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(message: tooltip, child: button);
    }
    return button;
  }
}
