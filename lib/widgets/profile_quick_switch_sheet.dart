import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../models/timetable_profile.dart';
import '../services/bundled_assets.dart';
import 'bundled_asset_image.dart';

typedef ProfileQuickSwitchManageHandler =
    void Function(BuildContext sheetContext);

/// Shows the home-screen profile quick-switch sheet with Forui styling.
Future<String?> showProfileQuickSwitchSheet(
  BuildContext context, {
  required List<TimetableProfile> profiles,
  required String? activeProfileId,
  required ProfileQuickSwitchManageHandler onManageTimetables,
}) {
  return showFSheet<String>(
    context: context,
    side: FLayout.btt,
    useSafeArea: true,
    draggable: true,
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
    final colors = context.theme.colors;
    final typo = context.theme.typography;
    final colorScheme = Theme.of(context).colorScheme;
    final activeIndex = profiles.indexWhere(
      (profile) => profile.id == activeProfileId,
    );
    final activeProfile = activeIndex >= 0 ? profiles[activeIndex] : null;

    final subtitle = activeProfile == null
        ? l10n.switchTimetableSubtitleEmpty
        : l10n.switchTimetableSubtitleCurrent(activeProfile.name);

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: colorScheme.primary.withValues(alpha: 0.12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: BundledAssetImage(
                      assetPath: BundledAssets.launcherIcon,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.switchTimetableTitle,
                          style: typo.body.sm.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: typo.body.xs2.copyWith(
                            color: colors.mutedForeground,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FTileGroup(
                physics: const NeverScrollableScrollPhysics(),
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
                  return FButton(
                    variant: FButtonVariant.secondary,
                    onPress: () => onManageTimetables(buttonContext),
                    prefix: const Icon(Icons.view_week_rounded, size: 18),
                    child: Text(l10n.timetableManagement),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

FTile _profileQuickSwitchTile({
  required BuildContext context,
  required TimetableProfile profile,
  required bool isActive,
  required VoidCallback onTap,
}) {
  final l10n = AppLocalizations.of(context)!;
  final colors = context.theme.colors;
  final colorScheme = Theme.of(context).colorScheme;
  final accentColor = isActive ? colorScheme.primary : colors.mutedForeground;

  return FTile(
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
    title: Text(profile.name),
    subtitle: Text(l10n.courseCountSummary(profile.courses.length)),
    suffix: isActive
        ? FBadge(variant: FBadgeVariant.primary, child: Text(l10n.currentBadge))
        : const Icon(Icons.chevron_right_rounded),
    onPress: onTap,
  );
}
