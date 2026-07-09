import 'package:flutter/material.dart';

import '../hyperos_theme.dart';
import '../hyperos_tokens.dart';
import 'layout.dart';
import 'tiles.dart';

/// HyperOS card: white rounded card with optional title, subtitle, and child.
class HyperosCard extends StatelessWidget {
  const HyperosCard({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
  });

  final String? title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hasTitle = title != null && title!.isNotEmpty;
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: HyperosColors.card(context),
        shape: HyperosTheme.cardShape(),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            hasTitle || hasSubtitle ? 16 : 0,
            16,
            16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasTitle)
                Text(title!, style: HyperosTypography.title(context)),
              if (hasTitle && hasSubtitle) const SizedBox(height: 2),
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
      ),
    );
  }
}

/// Summary card: white rounded card with a single summary line.
class HyperosSummaryCard extends StatelessWidget {
  const HyperosSummaryCard({super.key, required this.summary, this.onTap});

  final String summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);

    return HyperosPressableRow(
      onTap: onTap,
      backgroundColor: cardColor,
      highlightColor: highlightColor,
      child: hyperosListRowShell(
        padding: hyperosRowPadding(context),
        child: Text(
          summary,
          style: HyperosTypography.listTitle(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
