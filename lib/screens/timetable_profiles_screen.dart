import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../models/timetable_profile.dart';
import '../providers/timetable_provider.dart';
import '../utils/app_toast.dart';
import '../widgets/app_dialogs.dart';

class TimetableProfilesScreen extends StatelessWidget {
  const TimetableProfilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        final l10n = AppLocalizations.of(context)!;
        final profiles = provider.profiles;
        final activeProfileId = provider.activeProfileId;

        return HyperosSubpage(
          onBack: () => Navigator.pop(context),
          title: Text(l10n.timetableProfilesTitle),
          suffixes: [
            FHeaderAction(
              icon: const Icon(Icons.add_rounded),
              semanticsLabel: l10n.createTimetableTooltip,
              onPress: () => _createBlankProfile(context),
            ),
          ],
          child: HyperosListView(
            children: [
              HyperosListGroup(
                children: [
                  for (var index = 0; index < profiles.length; index++)
                    _TimetableProfileTile(
                      index: index,
                      profile: profiles[index],
                      isActive: profiles[index].id == activeProfileId,
                      canDelete: profiles.length > 1,
                      onSwitch: () => _switchProfile(
                        context,
                        profiles[index].id,
                        profiles[index].name,
                      ),
                      onRename: () => _renameProfile(
                        context,
                        profiles[index].id,
                        profiles[index].name,
                      ),
                      onDuplicate: () async {
                        await provider.switchProfile(profiles[index].id);
                        await provider.duplicateActiveProfile();
                        if (context.mounted) {
                          showAppToast(
                            context,
                            message: l10n.copiedCurrentTimetable,
                            kind: AppToastKind.success,
                          );
                        }
                      },
                      onClear: profiles[index].id == activeProfileId
                          ? () => _clearActiveProfileCourses(
                              context,
                              profiles[index].name,
                            )
                          : null,
                      onDelete: profiles.length > 1
                          ? () => _deleteProfile(
                              context,
                              profiles[index].id,
                              profiles[index].name,
                            )
                          : null,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _switchProfile(
    BuildContext context,
    String profileId,
    String profileName,
  ) async {
    await context.read<TimetableProvider>().switchProfile(profileId);
    if (!context.mounted) {
      return;
    }
    showAppToast(
      context,
      message: AppLocalizations.of(context)!.switchedToProfile(profileName),
      kind: AppToastKind.success,
    );
  }

  Future<void> _createBlankProfile(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final name = await showAppTextInputDialog(
      context,
      title: l10n.createTimetableTitle,
      body: HyperosTextField(
        controller: controller,
        label: l10n.timetableNameLabel,
        hint: l10n.timetableNameHint,
        autofocus: true,
      ),
      confirmLabel: l10n.createAction,
      readValue: () => controller.text,
      validate: (value) => value.isNotEmpty,
    );
    controller.dispose();

    if (!context.mounted || name == null || name.isEmpty) {
      return;
    }

    await context.read<TimetableProvider>().createProfile(name: name);
    if (!context.mounted) {
      return;
    }
    showAppToast(
      context,
      message: l10n.createdProfile(name),
      kind: AppToastKind.success,
    );
  }

  Future<void> _renameProfile(
    BuildContext context,
    String profileId,
    String currentName,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: currentName);
    final name = await showAppTextInputDialog(
      context,
      title: l10n.renameTimetableTitle,
      body: HyperosTextField(
        controller: controller,
        label: l10n.timetableNameLabel,
        autofocus: true,
      ),
      readValue: () => controller.text,
      validate: (value) => value.isNotEmpty,
    );
    controller.dispose();

    if (!context.mounted ||
        name == null ||
        name.isEmpty ||
        name == currentName) {
      return;
    }

    await context.read<TimetableProvider>().renameProfile(profileId, name);
    if (!context.mounted) {
      return;
    }
    showAppToast(
      context,
      message: l10n.renamedProfile(name),
      kind: AppToastKind.success,
    );
  }

  Future<void> _clearActiveProfileCourses(
    BuildContext context,
    String profileName,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showHyperosConfirmDialog(
      context: context,
      title: l10n.clearCurrentTimetableTitle,
      message: l10n.clearCurrentTimetableMessage(profileName),
      cancelLabel: l10n.cancelAction,
      confirmLabel: l10n.clearAction,
    );

    if (!context.mounted || confirmed != true) {
      return;
    }

    final cleared = await context
        .read<TimetableProvider>()
        .clearActiveProfileCourses();
    if (!context.mounted) {
      return;
    }
    showAppToast(
      context,
      message: cleared
          ? l10n.clearedProfile(profileName)
          : l10n.noCoursesInCurrentProfile,
      kind: cleared ? AppToastKind.success : AppToastKind.info,
    );
  }

  Future<void> _deleteProfile(
    BuildContext context,
    String profileId,
    String name,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showHyperosConfirmDialog(
      context: context,
      title: l10n.deleteTimetableTitle,
      message: l10n.deleteTimetableMessage(name),
      cancelLabel: l10n.cancelAction,
      confirmLabel: l10n.deleteAction,
      destructive: true,
    );

    if (!context.mounted || confirmed != true) {
      return;
    }

    final success = await context.read<TimetableProvider>().deleteProfile(
      profileId,
    );
    if (!context.mounted) {
      return;
    }
    showAppToast(
      context,
      message: success ? l10n.deletedProfile(name) : l10n.keepAtLeastOneProfile,
      kind: success ? AppToastKind.success : AppToastKind.warning,
    );
  }
}

class _TimetableProfileTile extends StatelessWidget {
  const _TimetableProfileTile({
    required this.index,
    required this.profile,
    required this.isActive,
    required this.canDelete,
    required this.onSwitch,
    required this.onRename,
    required this.onDuplicate,
    this.onClear,
    this.onDelete,
  });

  final int index;
  final TimetableProfile profile;
  final bool isActive;
  final bool canDelete;
  final VoidCallback onSwitch;
  final VoidCallback onRename;
  final VoidCallback onDuplicate;
  final VoidCallback? onClear;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.theme;
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);

    final row = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: HyperosTokens.listRowMinHeight,
      ),
      child: Padding(
        padding: HyperosTokens.rowPadding(
          isFirst: HyperosListTileScope.maybeOf(context)?.isFirst ?? true,
          isLast: HyperosListTileScope.maybeOf(context)?.isLast ?? true,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (isActive ? theme.colors.primary : theme.colors.muted)
                    .withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: theme.typography.body.sm.copyWith(
                  color: isActive
                      ? theme.colors.primary
                      : theme.colors.mutedForeground,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: HyperosTokens.rowContentGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    profile.name,
                    style: HyperosTypography.listTitle(context).copyWith(
                      color: isActive
                          ? theme.colors.primary
                          : HyperosColors.primaryText(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.coursesAndWeekSummary(
                      profile.courses.length,
                      profile.currentWeek,
                    ),
                    style: HyperosTypography.listDetail(context),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: l10n.moreActionsTooltip,
              onSelected: (value) {
                switch (value) {
                  case 'switch':
                    onSwitch();
                  case 'rename':
                    onRename();
                  case 'duplicate':
                    onDuplicate();
                  case 'clear':
                    onClear?.call();
                  case 'delete':
                    onDelete?.call();
                }
              },
              itemBuilder: (context) => [
                if (!isActive)
                  PopupMenuItem(
                    value: 'switch',
                    child: Text(l10n.switchToThisTimetable),
                  ),
                PopupMenuItem(value: 'rename', child: Text(l10n.renameAction)),
                PopupMenuItem(
                  value: 'duplicate',
                  child: Text(l10n.duplicateAction),
                ),
                if (isActive || canDelete) const PopupMenuDivider(),
                if (isActive)
                  PopupMenuItem(
                    value: 'clear',
                    enabled: profile.courses.isNotEmpty,
                    child: Text(
                      l10n.clearCoursesAction,
                      style: TextStyle(color: theme.colors.destructive),
                    ),
                  ),
                PopupMenuItem(
                  value: 'delete',
                  enabled: canDelete,
                  child: Text(
                    l10n.deleteAction,
                    style: TextStyle(
                      color: canDelete
                          ? theme.colors.destructive
                          : theme.colors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
            if (!isActive) ...[
              SizedBox(width: HyperosTokens.titleChevronGap),
              const HyperosChevron(),
            ],
          ],
        ),
      ),
    );

    return HyperosPressableRow(
      onTap: isActive ? null : onSwitch,
      backgroundColor: cardColor,
      highlightColor: highlightColor,
      child: row,
    );
  }
}
