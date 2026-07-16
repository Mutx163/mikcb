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
              HyperosSectionLabel(text: l10n.timetableManagementSectionTitle),
              HyperosListGroup(
                children: [
                  for (var index = 0; index < profiles.length; index++)
                    _TimetableProfileTile(
                      profile: profiles[index],
                      isActive: profiles[index].id == activeProfileId,
                      canDelete:
                          profiles.length > 1 &&
                          !profiles[index].isPartnerImported,
                      isPartnerImported: profiles[index].isPartnerImported,
                      onSwitch: profiles[index].isPartnerImported
                          ? () {}
                          : () => _switchProfile(
                              context,
                              profiles[index].id,
                              profiles[index].name,
                            ),
                      onRename: profiles[index].isPartnerImported
                          ? () {}
                          : () => _renameProfile(
                              context,
                              profiles[index].id,
                              profiles[index].name,
                            ),
                      onDuplicate: profiles[index].isPartnerImported
                          ? () {}
                          : () async {
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
                      onClear:
                          profiles[index].id == activeProfileId &&
                              !profiles[index].isPartnerImported
                          ? () => _clearActiveProfileCourses(
                              context,
                              profiles[index].name,
                            )
                          : null,
                      onDelete:
                          profiles.length > 1 &&
                              !profiles[index].isPartnerImported
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
    final name = await showAppTextInputDialog(
      context,
      title: l10n.createTimetableTitle,
      confirmLabel: l10n.createAction,
      bodyBuilder: (controller) => HyperosTextField(
        controller: controller,
        label: l10n.timetableNameLabel,
        hint: l10n.timetableNameHint,
        autofocus: true,
      ),
      validate: (value) => value.isNotEmpty,
    );

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
    final name = await showAppTextInputDialog(
      context,
      title: l10n.renameTimetableTitle,
      initialValue: currentName,
      bodyBuilder: (controller) => HyperosTextField(
        controller: controller,
        label: l10n.timetableNameLabel,
        autofocus: true,
      ),
      validate: (value) => value.isNotEmpty,
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

class _TimetableProfileTile extends StatefulWidget {
  const _TimetableProfileTile({
    required this.profile,
    required this.isActive,
    required this.canDelete,
    this.isPartnerImported = false,
    required this.onSwitch,
    required this.onRename,
    required this.onDuplicate,
    this.onClear,
    this.onDelete,
  });

  final TimetableProfile profile;
  final bool isActive;
  final bool canDelete;
  final bool isPartnerImported;
  final VoidCallback onSwitch;
  final VoidCallback onRename;
  final VoidCallback onDuplicate;
  final VoidCallback? onClear;
  final VoidCallback? onDelete;

  @override
  State<_TimetableProfileTile> createState() => _TimetableProfileTileState();
}

class _TimetableProfileTileState extends State<_TimetableProfileTile> {
  Future<void> _openMoreMenu() async {
    final l10n = AppLocalizations.of(context)!;
    final destructiveStyle = TextStyle(color: HyperosColors.error(context));

    final value = await showHyperosSheet<String>(
      context: context,
      builder: (sheetContext) => HyperosSheet(
        title: widget.profile.name,
        child: HyperosChoiceGroup(
          children: [
            if (!widget.isActive)
              HyperosChoiceTile(
                title: l10n.switchToThisTimetable,
                onTap: () => Navigator.pop(sheetContext, 'switch'),
              ),
            HyperosChoiceTile(
              title: l10n.renameAction,
              onTap: () => Navigator.pop(sheetContext, 'rename'),
            ),
            HyperosChoiceTile(
              title: l10n.duplicateAction,
              onTap: () => Navigator.pop(sheetContext, 'duplicate'),
            ),
            if (widget.isActive)
              HyperosChoiceTile(
                title: l10n.clearCoursesAction,
                enabled:
                    widget.profile.courses.isNotEmpty && widget.onClear != null,
                titleStyle: destructiveStyle,
                onTap:
                    widget.profile.courses.isNotEmpty && widget.onClear != null
                    ? () => Navigator.pop(sheetContext, 'clear')
                    : null,
              ),
            HyperosChoiceTile(
              title: l10n.deleteAction,
              enabled: widget.canDelete && widget.onDelete != null,
              titleStyle: destructiveStyle,
              onTap: widget.canDelete && widget.onDelete != null
                  ? () => Navigator.pop(sheetContext, 'delete')
                  : null,
            ),
          ],
        ),
      ),
    );
    if (!mounted || value == null) {
      return;
    }
    // Let the sheet finish dismissing before opening rename/confirm dialogs.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) {
      return;
    }
    switch (value) {
      case 'switch':
        widget.onSwitch();
      case 'rename':
        widget.onRename();
      case 'duplicate':
        widget.onDuplicate();
      case 'clear':
        widget.onClear?.call();
      case 'delete':
        widget.onDelete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);
    final primaryText = HyperosColors.primaryText(context);
    final primaryColor = HyperosColors.primary(context);

    final summary = widget.isPartnerImported
        ? l10n.coupleTimetablePartnerReadOnlyBadge
        : l10n.coursesAndWeekSummary(
            widget.profile.courses.length,
            widget.profile.currentWeek,
          );

    // Match [HyperosListTile] trailing chrome exactly: same row padding
    // ([hyperosChevronRowPadding]), same [titleChevronGap], bare
    // [HyperosChevron] with no custom size box or extra margin.
    final row = hyperosListRowShell(
      padding: hyperosChevronRowPadding(context),
      minHeight: HyperosTokens.listRowTwoLineMinHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.profile.name,
                  style: HyperosTypography.listTitle(context).copyWith(
                    color: widget.isActive ? primaryColor : primaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  summary,
                  style: HyperosTypography.listDetail(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!widget.isPartnerImported) ...[
            HyperosIconButton(
              icon: Icons.more_horiz_rounded,
              tooltip: l10n.moreActionsTooltip,
              // Same gray as [HyperosChevron] / settings trailing actions.
              color: HyperosColors.actionIcon(context),
              onPressed: _openMoreMenu,
            ),
            SizedBox(width: HyperosTokens.titleChevronGap),
            // Checkmark uses the kit default (22), same as [HyperosChoiceTile];
            // do not shrink it into the chevron glyph box.
            if (widget.isActive)
              const HyperosSelectedCheckmark()
            else
              const HyperosChevron(),
          ],
        ],
      ),
    );

    return HyperosPressableRow(
      onTap: widget.isActive || widget.isPartnerImported
          ? null
          : widget.onSwitch,
      backgroundColor: cardColor,
      highlightColor: highlightColor,
      child: row,
    );
  }
}
