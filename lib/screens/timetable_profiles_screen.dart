import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../models/timetable_profile.dart';
import '../providers/timetable_provider.dart';
import '../utils/app_toast.dart';
import '../widgets/app_dialogs.dart';

/// Shared trailing slot for active checkmark and inactive chevron.
/// Wider than the chevron glyph so a readable check can center without
/// shifting the more-actions button when the active profile changes.
const double _profileTrailingIndicatorSlot = 22;

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
              // The page title already names this page; keep a plain section
              // gap so the first card's rounded corners stay below the title.
              const HyperosSectionGap(),
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
                              // 切档案 + 复制档案两次写入都可能是裸的；复制失败
                              // 回滚并 rethrow，不接的话用户看到「已复制」而
                              // 课表根本没多出来。
                              try {
                                await provider.switchProfile(
                                  profiles[index].id,
                                );
                                await provider.duplicateActiveProfile();
                              } catch (_) {
                                if (context.mounted) {
                                  showAppToast(
                                    context,
                                    message: l10n.saveFailed,
                                    kind: AppToastKind.error,
                                  );
                                }
                                return;
                              }
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
        hint: l10n.timetableNameHint,
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

    // 落盘失败回滚并 rethrow（`timetable_provider.dart` 的 `renameProfile` 有快照）。
    // 不接就是「改完名、界面报已改名、重启后又变回去」，且异常落进 zone。
    try {
      await context.read<TimetableProvider>().renameProfile(profileId, name);
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      showAppToast(
        context,
        message: l10n.saveFailed,
        kind: AppToastKind.error,
      );
      return;
    }
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

    // 清空是整份课表 + 挂在课程上的全部作业一起没，落盘失败时 provider 会整体
    // 退回并 rethrow（`course_repository.dart` 的 `_timetableClearActiveProfileCourses`）。
    // 不接这个异常的话：错误落进 zone、页面零提示，用户以为「点了没反应」，
    // 而内存当时已是空的 —— 下一次任意成功写入就把「课表没了」永久坐实。
    final bool cleared;
    try {
      cleared = await context
          .read<TimetableProvider>()
          .clearActiveProfileCourses();
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      showAppToast(
        context,
        message: l10n.clearFailed,
        kind: AppToastKind.error,
      );
      return;
    }
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

    // `deleteProfile` 落盘失败会**回滚内存并 rethrow**（`timetable_provider.dart`
    // 自己的快照，`profilesBeforeDelete`），不接这个异常就是三件事同时发生：
    // 错误落进 zone 成为未处理异步错误、界面零提示，而确认弹窗已经关掉 ——
    // 用户看到的就是「点了删除，什么也没发生」，重启后课表还在。
    // 同文件 :209 的 `clearActiveProfileCourses` 已经是这个形状。
    final bool success;
    try {
      success = await context.read<TimetableProvider>().deleteProfile(profileId);
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      showAppToast(
        context,
        message: l10n.deleteFailed,
        kind: AppToastKind.error,
      );
      return;
    }
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.isActive)
              HyperosChoiceTile(
                title: l10n.switchToThisTimetable,
                variant: HyperosChoiceVariant.dialog,
                showDivider: true,
                onTap: () => Navigator.pop(sheetContext, 'switch'),
              ),
            HyperosChoiceTile(
              title: l10n.renameAction,
              variant: HyperosChoiceVariant.dialog,
              showDivider: true,
              onTap: () => Navigator.pop(sheetContext, 'rename'),
            ),
            HyperosChoiceTile(
              title: l10n.duplicateAction,
              variant: HyperosChoiceVariant.dialog,
              showDivider: true,
              onTap: () => Navigator.pop(sheetContext, 'duplicate'),
            ),
            if (widget.isActive)
              HyperosChoiceTile(
                title: l10n.clearCoursesAction,
                variant: HyperosChoiceVariant.dialog,
                showDivider: true,
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
              variant: HyperosChoiceVariant.dialog,
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

    // Match [HyperosListTile] row padding and [titleChevronGap]; trailing
    // indicator uses a fixed slot so check/chevron share one center.
    final row = hyperosListRowShell(
      padding: hyperosChevronRowPadding(context),
      minHeight: HyperosTokens.listRowTwoLineMinHeight,
      child: Row(
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
            const SizedBox(width: HyperosTokens.titleChevronGap),
            // Fixed slot for check / chevron so the more button never shifts
            // and both glyphs share the same geometric center.
            SizedBox(
              width: _profileTrailingIndicatorSlot,
              height: _profileTrailingIndicatorSlot,
              child: Center(
                child: widget.isActive
                    ? Transform.translate(
                        // Material [Icons.check] sits slightly low-right;
                        // nudge back onto the chevron centerline.
                        offset: const Offset(-0.5, -1),
                        child: const HyperosSelectedCheckmark(
                          
                        ),
                      )
                    : const HyperosChevron(),
              ),
            ),
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
