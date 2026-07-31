import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

/// HyperOS notification badge overlay — delegates to [MiuixBadgedBox] + [MiuixBadge].
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

    final hasLabel = label != null && label!.isNotEmpty;
    // MiuixText 从 MiuixContentColor 取 onError 前景色，并继承 MiuixBadge 注入的
    // 上游文字样式（11sp/16 行框）；普通 Text 读不到内容色会回退成黑字。
    final badge = MiuixBadge(
      child: hasLabel
          ? MiuixText(label!, textAlign: TextAlign.center)
          : null,
    );

    if (alignment == Alignment.topRight) {
      return MiuixBadgedBox(badge: badge, child: child);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
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
    final theme = MiuixTheme.of(context);
    final defaultBg = theme.colors.secondaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : (backgroundColor ?? defaultBg),
        borderRadius: BorderRadius.circular(6),
        border: outlined
            ? Border.all(color: theme.colors.onSurfaceVariantActions)
            : null,
      ),
      child: Text(
        label,
        style:
            textStyle ??
            TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: outlined
                  ? theme.colors.onSurfaceVariantSummary
                  : theme.colors.onSurface,
            ),
      ),
    );
  }
}
