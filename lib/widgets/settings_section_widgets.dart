import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class SettingsEntryTile extends StatelessWidget with FTileMixin {
  const SettingsEntryTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.details,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? details;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FTile(
      prefix: Icon(icon),
      title: Text(title),
      details: details == null ? null : Text(details!),
      suffix: trailing ?? const Icon(Icons.chevron_right_rounded),
      onPress: onTap,
    );
  }
}

class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.plainTitle = false,
  });

  final String? title;
  final String? subtitle;
  final bool plainTitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final typo = context.theme.typography.body;
    final hasHeader = (title != null && title!.isNotEmpty) || subtitle != null;
    final header = hasHeader
        ? Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null && title!.isNotEmpty)
                  Text(
                    title!,
                    style: typo.sm.copyWith(
                      fontWeight: plainTitle
                          ? FontWeight.w400
                          : FontWeight.w600,
                    ),
                  ),
                if (subtitle != null) ...[
                  if (title != null && title!.isNotEmpty)
                    const SizedBox(height: 2),
                  Text(subtitle!, style: typo.xs2),
                ],
              ],
            ),
          )
        : null;
    return FCard.raw(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [if (header != null) header, child],
        ),
      ),
    );
  }
}

class SettingSwitchTile extends StatelessWidget with FTileMixin {
  const SettingSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final Widget title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return FTile(
      title: title,
      subtitle: subtitle,
      suffix: FSwitch(value: value, enabled: enabled, onChange: onChanged),
      onPress: enabled
          ? () {
              onChanged!(!value);
            }
          : null,
    );
  }
}
