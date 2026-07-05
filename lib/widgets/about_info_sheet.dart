import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

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
    final typo = context.theme.typography.body;
    final colors = context.theme.colors;
    final itemStyle = typo.sm.copyWith(height: 1.45);
    final descriptionStyle = typo.xs2.copyWith(
      color: colors.mutedForeground,
      height: 1.4,
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: FTileGroup(
            label: Text(title),
            description: subtitle == null
                ? null
                : Text(
                    subtitle!,
                    maxLines: null,
                    overflow: TextOverflow.clip,
                    style: descriptionStyle,
                  ),
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final item in items)
                FTile(
                  title: Text(
                    item,
                    style: itemStyle,
                    maxLines: null,
                    overflow: TextOverflow.clip,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
