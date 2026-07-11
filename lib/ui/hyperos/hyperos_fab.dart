import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'hyperos_theme.dart';

/// HyperOS floating action button (primary accent, circular).
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
    final enabled = onPressed != null;
    final bg = enabled
        ? HyperosColors.primary(context)
        : HyperosColors.disabledPrimaryButton(context);
    final fg = enabled
        ? HyperosColors.onPrimary(context)
        : HyperosColors.disabledOnPrimaryButton(context);

    final size = mini ? 40.0 : 56.0;
    final iconSize = mini ? 22.0 : 26.0;

    final button = Material(
      color: bg,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                onPressed!();
              }
            : null,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: iconSize, color: fg),
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
