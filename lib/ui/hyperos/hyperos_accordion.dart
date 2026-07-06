import 'package:flutter/material.dart';

import 'hyperos_theme.dart';
import 'hyperos_tokens.dart';

class HyperosAccordionItem {
  const HyperosAccordionItem({required this.title, required this.child});

  final Widget title;
  final Widget child;
}

/// Expandable sections inside a control card (replaces Forui [FAccordion]).
class HyperosAccordion extends StatelessWidget {
  const HyperosAccordion({super.key, required this.items});

  final List<HyperosAccordionItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              thickness: 1,
              color: HyperosColors.actionIcon(context).withValues(alpha: 0.25),
            ),
          _HyperosAccordionTile(item: items[i]),
        ],
      ],
    );
  }
}

class _HyperosAccordionTile extends StatefulWidget {
  const _HyperosAccordionTile({required this.item});

  final HyperosAccordionItem item;

  @override
  State<_HyperosAccordionTile> createState() => _HyperosAccordionTileState();
}

class _HyperosAccordionTileState extends State<_HyperosAccordionTile> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: HyperosTokens.rowPaddingUniform,
              child: Row(
                children: [
                  Expanded(child: widget.item.title),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: HyperosColors.actionIcon(context),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: widget.item.child,
          ),
      ],
    );
  }
}

/// Info hint row with optional leading icon (replaces Forui [FAlert]).
class HyperosHintBanner extends StatelessWidget {
  const HyperosHintBanner({super.key, required this.title, this.icon});

  final Widget title;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: HyperosColors.card(context),
        borderRadius: HyperosTheme.cardBorderRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[icon!, const SizedBox(width: 10)],
          Expanded(
            child: DefaultTextStyle(
              style: HyperosTypography.listDetail(context),
              child: title,
            ),
          ),
        ],
      ),
    );
  }
}
