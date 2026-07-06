import 'package:flutter/material.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

/// Returns disclaimer body copy without the localized title prefix.
@visibleForTesting
String thirdPartyDisclaimerBody(String text) {
  final trimmed = text.trim();
  final match = RegExp(
    r'^([^:：]+[:：])\s*(.+)$',
    dotAll: true,
  ).firstMatch(trimmed);
  return match?.group(2)?.trim() ?? trimmed;
}

/// Inline disclaimer copy for embedding inside an existing card.
class ThirdPartyDisclaimerContent extends StatelessWidget {
  const ThirdPartyDisclaimerContent({
    super.key,
    required this.text,
    this.textAlign = TextAlign.start,
  });

  final String text;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      thirdPartyDisclaimerBody(text),
      textAlign: textAlign,
      style: HyperosTypography.sectionDescription(context),
    );
  }
}

/// Standalone disclaimer block for pages without a hero card.
class ThirdPartyDisclaimerCard extends StatelessWidget {
  const ThirdPartyDisclaimerCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return HyperosControlCard(child: ThirdPartyDisclaimerContent(text: text));
  }
}
