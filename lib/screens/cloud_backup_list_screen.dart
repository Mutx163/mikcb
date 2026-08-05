import 'dart:async';

import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../services/cloud_backup_index_service.dart';
import '../services/webdav_sync_coordinator.dart';
import '../services/webdav_sync_service.dart';
import '../utils/app_toast.dart';
import '../widgets/app_dialogs.dart';
import '../ui/hyperos/hyperos.dart';
import 'cloud_backup_ui_helpers.dart';
import 'transfer_preview_dialog.dart';

class CloudBackupListScreen extends StatefulWidget {
  const CloudBackupListScreen({super.key});

  @override
  State<CloudBackupListScreen> createState() => _CloudBackupListScreenState();
}

class _CloudBackupListScreenState extends State<CloudBackupListScreen> {
  final _coordinator = WebdavSyncCoordinator.instance();
  List<CloudBackupEntry> _entries = const [];
  bool _loading = true;
  bool _creatingBackup = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBackups());
  }

  Future<void> _loadBackups() async {
    setState(() {
      _loading = true;
    });
    final result = await _coordinator.fetchBackupList();
    if (!mounted) {
      return;
    }
    if (result.hasError) {
      final l10n = AppLocalizations.of(context)!;
      showAppToast(
        context,
        message: CloudBackupUiHelpers.localizeSyncError(
          l10n,
          result.errorMessage,
        ),
        kind: AppToastKind.error,
      );
    }
    setState(() {
      _entries = result.entries;
      _loading = false;
    });
  }

  Future<void> _undoCloudRestore() async {
    final success = await _coordinator.undoLastRestore();
    if (!mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    showAppToast(
      context,
      message: success
          ? l10n.cloudBackupRestoreSuccess
          : l10n.cloudBackupRestoreFailed('Undo failed'),
      kind: success ? AppToastKind.success : AppToastKind.error,
    );
    if (success) {
      await _loadBackups();
    }
  }

  Future<void> _createManualBackup() async {
    setState(() {
      _creatingBackup = true;
    });
    try {
      final result = await _coordinator.createManualBackup();
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context)!;
      final succeeded =
          result.kind == WebdavSyncResultKind.backupCreated ||
          result.kind == WebdavSyncResultKind.uploaded;
      showAppToast(
        context,
        message: succeeded
            ? l10n.cloudBackupCreateSuccess
            : l10n.cloudBackupCreateFailed(
                CloudBackupUiHelpers.localizeSyncError(l10n, result.message),
              ),
        kind: succeeded ? AppToastKind.success : AppToastKind.error,
      );
      if (succeeded) {
        await _loadBackups();
      }
    } finally {
      if (mounted) {
        setState(() {
          _creatingBackup = false;
        });
      }
    }
  }

  Future<void> _openBackupDetail(CloudBackupEntry entry) async {
    final action = await showCloudBackupDetailSheet(
      context: context,
      entry: entry,
      deviceLabel: CloudBackupUiHelpers.resolveBackupDeviceLabel(
        context,
        entry.deviceLabel,
      ),
      formattedTime: CloudBackupUiHelpers.formatBackupDateTime(
        entry.exportedAt,
      ),
    );
    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case CloudBackupDetailAction.restore:
        await _restoreBackup(entry);
      case CloudBackupDetailAction.delete:
        await _deleteBackup(entry);
    }
  }

  Future<void> _restoreBackup(CloudBackupEntry entry) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final preview = await _coordinator.previewBackupRestore(entry.id);
      if (!mounted || preview == null) {
        return;
      }
      final mode = await showTransferPreviewDialog(
        context: context,
        title: l10n.cloudBackupRestoreTitle,
        preview: preview.overwriteDiff,
        alternatePreview: preview.mergeDiff,
        incoming: preview.overwritePackage,
      );
      if (mode == null || !mounted) {
        return;
      }
      final uploadAsCurrent = await showAppConfirmDialog(
        context,
        title: l10n.cloudBackupUploadAsCurrentTitle,
        message: l10n.cloudBackupUploadAsCurrentBody,
        confirmLabel: l10n.cloudBackupUploadAsCurrentYes,
        cancelLabel: l10n.cloudBackupUploadAsCurrentNo,
      );
      if (!mounted) {
        return;
      }
      final result = await _coordinator.applyPreviewedBackupRestore(
        preview: preview,
        mode: mode,
        uploadAsCurrent: uploadAsCurrent == true,
      );
      if (!mounted) {
        return;
      }
      if (result.applied) {
        showAppToastWithAction(
          context,
          message: l10n.cloudBackupRestoreSuccess,
          actionLabel: l10n.themeUndo,
          kind: AppToastKind.success,
          onAction: () => unawaited(_undoCloudRestore()),
        );
        await _loadBackups();
      } else {
        showAppToast(
          context,
          message: l10n.cloudBackupRestoreFailed(
            CloudBackupUiHelpers.localizeSyncError(l10n, result.error),
          ),
          kind: AppToastKind.error,
        );
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: l10n.cloudBackupRestoreFailed(
          CloudBackupUiHelpers.localizeSyncError(l10n, '$error'),
        ),
        kind: AppToastKind.error,
      );
    }
  }

  Future<void> _deleteBackup(CloudBackupEntry entry) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.cloudBackupDeleteTitle,
      message: l10n.cloudBackupDeleteBody(
        CloudBackupUiHelpers.formatBackupDateTime(entry.exportedAt),
      ),
      confirmLabel: l10n.deleteAction,
      destructiveConfirm: true,
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final result = await _coordinator.deleteBackup(entry.id);
    if (!mounted) {
      return;
    }

    showAppToast(
      context,
      message: result.kind == WebdavSyncResultKind.backupDeleted
          ? l10n.cloudBackupDeleteSuccess
          : l10n.cloudBackupDeleteFailed(
              CloudBackupUiHelpers.localizeSyncError(l10n, result.message),
            ),
      kind: result.kind == WebdavSyncResultKind.backupDeleted
          ? AppToastKind.success
          : AppToastKind.error,
    );
    if (result.kind == WebdavSyncResultKind.backupDeleted) {
      await _loadBackups();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.cloudBackupSectionTitle),
      child: _loading
          ? const Center(child: HyperosCircularProgress())
          : _entries.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.cloudBackupEmpty,
                  textAlign: TextAlign.center,
                  style: HyperosTypography.sectionDescription(context),
                ),
              ),
            )
          : HyperosListView(
              children: [
                HyperosControlCard(
                  child: HyperosControlCardInset(
                    child: HyperosButton(
                      label: l10n.cloudBackupCreateNow,
                      loading: _creatingBackup,
                      onPressed: _creatingBackup ? null : _createManualBackup,
                    ),
                  ),
                ),
                const HyperosSectionGap(),
                HyperosListGroup(
                  children: [
                    for (final entry in _entries)
                      HyperosNavTile(
                        title: entry.isCurrent
                            ? l10n.cloudBackupCurrentLabel
                            : CloudBackupUiHelpers.formatBackupDateTime(
                                entry.exportedAt,
                              ),
                        subtitle: CloudBackupUiHelpers.buildBackupSubtitle(
                          context,
                          entry,
                        ),
                        details: entry.isCurrent
                            ? l10n.cloudBackupCurrentBadge
                            : null,
                        onTap: () => _openBackupDetail(entry),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}
