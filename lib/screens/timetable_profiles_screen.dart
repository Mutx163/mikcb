import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../providers/timetable_provider.dart';

class TimetableProfilesScreen extends StatelessWidget {
  const TimetableProfilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        final l10n = AppLocalizations.of(context)!;
        final profiles = provider.profiles;
        final activeProfileId = provider.activeProfileId;

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.timetableProfilesTitle),
            actions: [
              IconButton(
                tooltip: l10n.createTimetableTooltip,
                onPressed: () => _createBlankProfile(context),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          body: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: profiles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final profile = profiles[index];
              final isActive = profile.id == activeProfileId;
              final theme = Theme.of(context);
              final colorScheme = theme.colorScheme;
              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: isActive
                      ? null
                      : () => _switchProfile(
                            context,
                            profile.id,
                            profile.name,
                          ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: (isActive
                                        ? colorScheme.primary
                                        : colorScheme.secondaryContainer)
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${index + 1}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: isActive
                                      ? colorScheme.primary
                                      : colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.coursesAndWeekSummary(
                                      profile.courses.length,
                                      profile.currentWeek,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
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
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('已复制当前课表'),
                                        ),
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
                                        color: colorScheme.error,
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
                                          ? colorScheme.error
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.tonal(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 36),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: isActive
                                    ? null
                                    : () => _switchProfile(
                                          context,
                                          profile.id,
                                          profile.name,
                                        ),
                                child: Text(
                                  isActive
                                      ? l10n.usingNow
                                      : l10n.switchToThisTimetable,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 36),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => _renameProfile(
                                context,
                                profile.id,
                                profile.name,
                              ),
                              icon: const Icon(Icons.edit_outlined),
                              label: Text(l10n.renameAction),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              AppLocalizations.of(context)!.switchedToProfile(profileName))),
    );
  }

  Future<void> _createBlankProfile(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.createTimetableTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.timetableNameLabel,
              hintText: AppLocalizations.of(context)!.timetableNameHint,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.cancelAction),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text(AppLocalizations.of(context)!.createAction),
            ),
          ],
        );
      },
    );

    if (!context.mounted || name == null || name.isEmpty) {
      return;
    }

    await context.read<TimetableProvider>().createProfile(name: name);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(AppLocalizations.of(context)!.createdProfile(name))),
    );
  }

  Future<void> _renameProfile(
    BuildContext context,
    String profileId,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.renameTimetableTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.timetableNameLabel,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.cancelAction),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text(AppLocalizations.of(context)!.saveAction),
            ),
          ],
        );
      },
    );

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(AppLocalizations.of(context)!.renamedProfile(name))),
    );
  }

  Future<void> _clearActiveProfileCourses(
    BuildContext context,
    String profileName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.clearCurrentTimetableTitle),
          content: Text(
            AppLocalizations.of(context)!
                .clearCurrentTimetableMessage(profileName),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context)!.cancelAction),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppLocalizations.of(context)!.clearAction),
            ),
          ],
        );
      },
    );

    if (!context.mounted || confirmed != true) {
      return;
    }

    final cleared =
        await context.read<TimetableProvider>().clearActiveProfileCourses();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          cleared
              ? AppLocalizations.of(context)!.clearedProfile(profileName)
              : AppLocalizations.of(context)!.noCoursesInCurrentProfile,
        ),
      ),
    );
  }

  Future<void> _deleteProfile(
    BuildContext context,
    String profileId,
    String name,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.deleteTimetableTitle),
          content:
              Text(AppLocalizations.of(context)!.deleteTimetableMessage(name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context)!.cancelAction),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppLocalizations.of(context)!.deleteAction),
            ),
          ],
        );
      },
    );

    if (!context.mounted || confirmed != true) {
      return;
    }

    final success =
        await context.read<TimetableProvider>().deleteProfile(profileId);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? AppLocalizations.of(context)!.deletedProfile(name)
              : AppLocalizations.of(context)!.keepAtLeastOneProfile,
        ),
      ),
    );
  }
}
