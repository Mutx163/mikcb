import 'package:flutter/material.dart';

import '../ui/hyperos/hyperos.dart';

/// Bottom sheet body for about-page info sections (positioning, import, etc.).
///
/// Bullet rows use primary (black) body text and wrap fully — do not reuse
/// disabled [HyperosChoiceTile]s (those force gray + single-line ellipsis).
class AboutInfoSheetBody extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<String> items;

  const AboutInfoSheetBody({
    super.key,
    required this.title,
    this.subtitle,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    // Match secondary brand line under the icon (version / list detail size),
    // not list-title 17sp — keep primary black for full readable bullets.
    final bodyStyle = HyperosTypography.listDetail(
      context,
    ).copyWith(color: HyperosColors.primaryText(context), height: 1.45);

    return HyperosSheet(
      title: title,
      description: subtitle,
      child: HyperosControlCard(
        edgeToEdge: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            HyperosControlCardScope.defaultHorizontalPadding,
            16,
            HyperosControlCardScope.defaultHorizontalPadding,
            HyperosControlCardScope.defaultBodyBottomInset + 4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < items.length; index++) ...[
                if (index > 0) const SizedBox(height: 12),
                Text(items[index], style: bodyStyle, softWrap: true),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
