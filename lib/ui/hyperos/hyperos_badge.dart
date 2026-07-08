import 'package:flutter/material.dart';

import 'hyperos_miuix_spec.dart';
import 'hyperos_theme.dart';

/// HyperOS notification badge overlay (dot or numeric label).
class HyperosBadge extends StatelessWidget {
  const HyperosBadge({
    super.key,
    required this.child,
    this.label,
    this.show = true,
    this.alignment = Alignment.topRight,
  });

  final Widget child;
  final String? label;
  final bool show;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    if (!show) return child;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final badgeColor = isDark
        ? HyperosMiuixDarkColors.error
        : HyperosMiuixLightColors.error;
    final textColor = isDark
        ? HyperosMiuixDarkColors.onError
        : HyperosMiuixLightColors.onError;

    final hasLabel = label != null && label!.isNotEmpty;
    final badge = hasLabel
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Text(
              label!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: HyperosMiuixTypography.footnote2,
                fontWeight: FontWeight.w600,
                color: textColor,
                height: 1.1,
              ),
            ),
          )
        : Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
          );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        // Align handles any alignment (including centered edges); the translate
        // nudges corner badges 4dp outside the child like the HyperOS overlay.
        Positioned.fill(
          child: Align(
            alignment: alignment,
            child: Transform.translate(
              offset: Offset(4 * alignment.x, 4 * alignment.y),
              child: badge,
            ),
          ),
        ),
      ],
    );
  }
}

/// Inline text pill (replaces Forui [FBadge] when not overlaying an icon).
class HyperosTag extends StatelessWidget {
  const HyperosTag({
    super.key,
    required this.label,
    this.outlined = false,
    this.textStyle,
    this.backgroundColor,
  });

  final String label;
  final bool outlined;
  final TextStyle? textStyle;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark
        ? HyperosMiuixDarkColors.secondaryContainer
        : HyperosMiuixLightColors.secondaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : (backgroundColor ?? defaultBg),
        borderRadius: BorderRadius.circular(6),
        border: outlined
            ? Border.all(color: HyperosColors.actionIcon(context))
            : null,
      ),
      child: Text(
        label,
        style:
            textStyle ??
            TextStyle(
              fontSize: HyperosMiuixTypography.footnote2,
              fontWeight: FontWeight.w500,
              color: outlined
                  ? HyperosColors.secondaryText(context)
                  : HyperosColors.primaryText(context),
            ),
      ),
    );
  }
}
