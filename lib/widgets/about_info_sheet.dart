import 'package:flutter/material.dart';

import '../ui/hyperos/hyperos.dart';

/// Bottom sheet body for about-page info sections (positioning, import, etc.).
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
    return HyperosSheet(
      title: title,
      description: subtitle,
      child: HyperosChoiceGroup(
        children: [
          for (final item in items) HyperosChoiceTile(title: item, onTap: null),
        ],
      ),
    );
  }
}
