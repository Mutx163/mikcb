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

class CloudBackupListScreen extends StatefulWidget {
  const CloudBackupListScreen({super.key});

  @override
  State<CloudBackupListScreen> createState() => _CloudBackupListScreenState();
}

class _CloudBackupListScreenState extends State<CloudBackupListScreen> {
  final _coordinator = WebdavSyncCoordinator.instance();
  List<CloudBackupEntry> _entries = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBackups());
  }

  Future<void> _loadBackups() async {
    setState(() {
      _loading = true;
    });
    final entries = await _coordinator.fetchBackupList();
    if (!mounted) {
      return;
    }
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _openBackupDetail(CloudBackupEntry entry) async {
    final action = await showCloudBackupDetailSheet(
      context: context,
      entry: entry,
      deviceLabel: CloudBackupUiHelpers.resolveBackupDeviceLabel(
        context,
        entry.deviceLabel,
      ),
      formattedTime: CloudBackupUiHelpers.formatBackupDateTime(entry.exportedAt),
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
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.cloudBackupRestoreTitle,
      message: l10n.cloudBackupRestoreBody(
        CloudBackupUiHelpers.formatBackupDateTime(entry.exportedAt),
      ),
      confirmLabel: l10n.cloudBackupRestoreAction,
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final uploadAsCurrent = await showAppConfirmDialog(
      context,
      title: l10n.cloudBackupUploadAsCurrentTitle,
      message: l10n.cloudBackupUploadAsCurrentBody,
      confirmLabel: l10n.cloudBackupUploadAsCurrentYes,
      cancelLabel: l10n.cloudBackupUploadAsCurrentNo,
    );

    final result = await _coordinator.restoreBackup(
      entry.id,
      uploadAsCurrent: uploadAsCurrent == true,
    );
    if (!mounted) {
      return;
    }

    final message = switch (result.kind) {
      WebdavSyncResultKind.backupRestored => l10n.cloudBackupRestoreSuccess,
      WebdavSyncResultKind.failed => l10n.cloudBackupRestoreFailed(
        result.message ?? '',
      ),
      _ => l10n.cloudBackupRestoreFailed(result.message ?? ''),
    };
    showAppToast(
      context,
      message: message,
      kind: result.kind == WebdavSyncResultKind.failed
          ? AppToastKind.error
          : AppToastKind.success,
    );
    if (result.kind == WebdavSyncResultKind.backupRestored) {
      await _loadBackups();
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
          : l10n.cloudBackupDeleteFailed(result.message ?? ''),
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
                        details: entry.isCurrent ? l10n.cloudBackupCurrentBadge : null,
                        onTap: () => _openBackupDetail(entry),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}
