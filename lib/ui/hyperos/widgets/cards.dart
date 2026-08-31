import 'package:flutter/material.dart';

import '../hyperos_theme.dart';
import '../hyperos_tokens.dart';
import 'adaptive_card.dart';
import 'indicators.dart';
import 'tiles.dart';

/// HyperOS card: white rounded card with optional title, subtitle, and child.
class HyperosCard extends StatelessWidget {
  const HyperosCard({
    super.key,
    this.title,
    this.subtitle,
    this.padding,
    required this.child,
  });

  final String? title;
  final String? subtitle;
  final EdgeInsetsGeometry? padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hasTitle = title != null && title!.isNotEmpty;
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;

    return SizedBox(
      width: double.infinity,
      child: HyperosAdaptiveCard(
        padding:
            padding ??
            EdgeInsets.fromLTRB(16, hasTitle || hasSubtitle ? 16 : 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasTitle) Text(title!, style: HyperosTypography.title(context)),
            if (hasTitle && hasSubtitle)
              const SizedBox(height: HyperosTokens.titleCaptionGap),
            if (hasSubtitle)
              Text(
                subtitle!,
                style: HyperosTypography.sectionDescription(context),
                softWrap: true,
              ),
            if (hasTitle || hasSubtitle) const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Summary card: white rounded card with optional leading, title, subtitle.
class HyperosSummaryCard extends StatelessWidget {
  const HyperosSummaryCard({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.summary,
    this.onTap,
  });

  static const double leadingSize = 44;
  static const double leadingRadius = 12;

  final Widget? leading;
  final String? title;
  final String? subtitle;
  final String? summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);

    return HyperosAdaptiveCard(
      color: cardColor,
      child: HyperosPressableRow(
        onTap: onTap,
        backgroundColor: cardColor,
        highlightColor: highlightColor,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 16)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (summary != null)
                      Text(
                        summary!,
                        style: HyperosTypography.listTitle(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (title != null)
                      Text(
                        title!,
                        style: HyperosTypography.listTitle(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (subtitle != null) ...[
                      const SizedBox(height: HyperosTokens.titleCaptionGap),
                      Text(
                        subtitle!,
                        style: HyperosTypography.listDetail(context),
                        softWrap: true,
                      ),
                    ],
                  ],
                ),
              ),
              // Same affordance as [HyperosListTile]: only tappable summary
              // cards show a right chevron so the entry is not a dead-end look.
              if (onTap != null) ...[
                const SizedBox(width: HyperosTokens.titleChevronGap),
                const HyperosChevron(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
