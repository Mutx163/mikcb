import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../providers/timetable_provider.dart';
import '../utils/app_toast.dart';

class TimetableProfilesScreen extends StatelessWidget {
  const TimetableProfilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        final l10n = AppLocalizations.of(context)!;
        final profiles = provider.profiles;
        final activeProfileId = provider.activeProfileId;

        return FScaffold(
          header: FHeader.nested(
            prefixes: [
              FHeaderAction.back(onPress: () => Navigator.pop(context)),
            ],
            suffixes: [
              FHeaderAction(
                icon: const Icon(Icons.add_rounded),
                semanticsLabel: l10n.createTimetableTooltip,
                onPress: () => _createBlankProfile(context),
              ),
            ],
            title: Text(l10n.timetableProfilesTitle),
          ),
          childPad: false,
          child: Material(
            type: MaterialType.transparency,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FTileGroup(
                  physics: const NeverScrollableScrollPhysics(),
                  children: profiles.asMap().entries.map((entry) {
                    final index = entry.key;
                    final profile = entry.value;
                    final isActive = profile.id == activeProfileId;
                    final theme = context.theme;
                    return FTile(
                      prefix: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color:
                              (isActive
                                      ? theme.colors.primary
                                      : theme.colors.muted)
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
                      title: Text(profile.name),
                      subtitle: Text(
                        l10n.coursesAndWeekSummary(
                          profile.courses.length,
                          profile.currentWeek,
                        ),
                      ),
                      details: PopupMenuButton<String>(
                        tooltip: l10n.moreActionsTooltip,
                        onSelected: (value) async {
                          switch (value) {
                            case 'switch':
                              await _switchProfile(
                                context,
                                profile.id,
                                profile.name,
                              );
                              break;
                            case 'rename':
                              await _renameProfile(
                                context,
                                profile.id,
                                profile.name,
                              );
                              break;
                            case 'duplicate':
                              await provider.switchProfile(profile.id);
                              await provider.duplicateActiveProfile();
                              if (context.mounted) {
                                showAppToast(
                                  context,
                                  message: l10n.copiedCurrentTimetable,
                                  kind: AppToastKind.success,
                                );
                              }
                              break;
                            case 'clear':
                              await _clearActiveProfileCourses(
                                context,
                                profile.name,
                              );
                              break;
                            case 'delete':
                              await _deleteProfile(
                                context,
                                profile.id,
                                profile.name,
                              );
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          if (!isActive)
                            PopupMenuItem(
                              value: 'switch',
                              child: Text(l10n.switchToThisTimetable),
                            ),
                          PopupMenuItem(
                            value: 'rename',
                            child: Text(l10n.renameAction),
                          ),
                          PopupMenuItem(
                            value: 'duplicate',
                            child: Text(l10n.duplicateAction),
                          ),
                          if (isActive || profiles.length > 1)
                            const PopupMenuDivider(),
                          if (isActive)
                            PopupMenuItem(
                              value: 'clear',
                              enabled: profile.courses.isNotEmpty,
                              child: Text(
                                l10n.clearCoursesAction,
                                style: TextStyle(
                                  color: theme.colors.destructive,
                                ),
                              ),
                            ),
                          PopupMenuItem(
                            value: 'delete',
                            enabled: profiles.length > 1,
                            child: Text(
                              l10n.deleteAction,
                              style: TextStyle(
                                color: profiles.length > 1
                                    ? theme.colors.destructive
                                    : theme.colors.mutedForeground,
                              ),
                            ),
                          ),
                        ],
                      ),
                      suffix: const Icon(Icons.chevron_right_rounded),
                      selected: isActive,
                      onPress: isActive
                          ? null
                          : () => _switchProfile(
                              context,
                              profile.id,
                              profile.name,
                            ),
                    );
                  }).toList(),
                ),
              ],
            ),
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
    final name = await showFDialog<String>(
      context: context,
      builder: (ctx, style, animation) => FDialog(
        title: Text(l10n.createTimetableTitle),
        body: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.timetableNameLabel,
            hintText: l10n.timetableNameHint,
          ),
        ),
        actions: [
          FButton(
            variant: FButtonVariant.ghost,
            onPress: () => Navigator.pop(ctx),
            child: Text(l10n.cancelAction),
          ),
          FButton(
            variant: FButtonVariant.primary,
            onPress: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.createAction),
          ),
        ],
      ),
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
    final name = await showFDialog<String>(
      context: context,
      builder: (ctx, style, animation) => FDialog(
        title: Text(l10n.renameTimetableTitle),
        body: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.timetableNameLabel),
        ),
        actions: [
          FButton(
            variant: FButtonVariant.ghost,
            onPress: () => Navigator.pop(ctx),
            child: Text(l10n.cancelAction),
          ),
          FButton(
            variant: FButtonVariant.primary,
            onPress: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.saveAction),
          ),
        ],
      ),
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
    final confirmed = await showFDialog<bool>(
      context: context,
      builder: (ctx, style, animation) => FDialog(
        title: Text(l10n.clearCurrentTimetableTitle),
        body: Text(l10n.clearCurrentTimetableMessage(profileName)),
        actions: [
          FButton(
            variant: FButtonVariant.ghost,
            onPress: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancelAction),
          ),
          FButton(
            variant: FButtonVariant.primary,
            onPress: () => Navigator.pop(ctx, true),
            child: Text(l10n.clearAction),
          ),
        ],
      ),
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
    final confirmed = await showFDialog<bool>(
      context: context,
      builder: (ctx, style, animation) => FDialog(
        title: Text(l10n.deleteTimetableTitle),
        body: Text(l10n.deleteTimetableMessage(name)),
        actions: [
          FButton(
            variant: FButtonVariant.ghost,
            onPress: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancelAction),
          ),
          FButton(
            variant: FButtonVariant.primary,
            onPress: () => Navigator.pop(ctx, true),
            child: Text(l10n.deleteAction),
          ),
        ],
      ),
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
