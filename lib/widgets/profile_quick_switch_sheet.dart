import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../models/timetable_profile.dart';

typedef ProfileQuickSwitchManageHandler =
    void Function(BuildContext sheetContext);

/// Shows the home-screen profile quick-switch sheet with Forui styling.
Future<String?> showProfileQuickSwitchSheet(
  BuildContext context, {
  required List<TimetableProfile> profiles,
  required String? activeProfileId,
  required ProfileQuickSwitchManageHandler onManageTimetables,
}) {
  return showHomeHyperosSheet<String>(
    context: context,
    builder: (sheetContext) => _ProfileQuickSwitchSheet(
      profiles: profiles,
      activeProfileId: activeProfileId,
      onManageTimetables: onManageTimetables,
    ),
  );
}

class _ProfileQuickSwitchSheet extends StatelessWidget {
  const _ProfileQuickSwitchSheet({
    required this.profiles,
    required this.activeProfileId,
    required this.onManageTimetables,
  });

  final List<TimetableProfile> profiles;
  final String? activeProfileId;
  final ProfileQuickSwitchManageHandler onManageTimetables;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return HyperosSheet(
      frosted: true,
      title: l10n.switchTimetableTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HyperosChoiceGroup(
            children: [
              for (final profile in profiles)
                _profileQuickSwitchTile(
                  context: context,
                  profile: profile,
                  isActive: profile.id == activeProfileId,
                  onTap: () => Navigator.of(context).pop(profile.id),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (buttonContext) {
              return HyperosButton(
                label: l10n.timetableManagement,
                variant: HyperosButtonVariant.secondary,
                expand: true,
                onPressed: () => onManageTimetables(buttonContext),
              );
            },
          ),
        ],
      ),
    );
  }
}

Widget _profileQuickSwitchTile({
  required BuildContext context,
  required TimetableProfile profile,
  required bool isActive,
  required VoidCallback onTap,
}) {
  final l10n = AppLocalizations.of(context)!;
  final colors = context.theme.colors;
  final colorScheme = Theme.of(context).colorScheme;
  final accentColor = isActive ? colorScheme.primary : colors.mutedForeground;

  return HyperosChoiceTile(
    prefix: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: isActive ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Icon(
        isActive ? Icons.check_circle_rounded : Icons.layers_rounded,
        color: accentColor,
        size: 20,
      ),
    ),
    title: profile.name,
    subtitle: Text(l10n.courseCountSummary(profile.courses.length)),
    trailing: isActive
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              l10n.currentBadge,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
          )
        : const Icon(Icons.chevron_right_rounded),
    selected: isActive,
    highlightSelectedText: true,
    onTap: onTap,
  );
}
