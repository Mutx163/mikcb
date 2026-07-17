import 'dart:async';

import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../services/app_sync_snapshot_service.dart';
import '../services/cloud_backup_index_service.dart';
import '../services/webdav_sync_config.dart';
import '../services/webdav_sync_coordinator.dart';
import '../services/webdav_sync_credentials_store.dart';
import '../services/webdav_sync_service.dart';
import '../utils/app_toast.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/course_field_picker_sheet.dart';
import '../ui/hyperos/hyperos.dart';
import 'cloud_backup_list_screen.dart';
import 'cloud_backup_ui_helpers.dart';

Widget _buttonLoadingPrefix() {
  return const SizedBox(
    width: 16,
    height: 16,
    child: HyperosCircularProgress(size: 16, strokeWidth: 2),
  );
}

class CloudSyncScreen extends StatefulWidget {
  const CloudSyncScreen({super.key});

  @override
  State<CloudSyncScreen> createState() => _CloudSyncScreenState();
}

class _CloudSyncScreenState extends State<CloudSyncScreen> {
  static const _maxBackupCountOptions = [5, 10, 15, 20, 30];
  static const _maxBackupAgeOptions = [7, 14, 30, 60, 90];

  final _baseUrlController = TextEditingController();
  final _remoteFolderController = TextEditingController();
  final _deviceLabelController = TextEditingController();
  final _credentialsStore = const WebdavSyncCredentialsStore();

  WebdavSyncConfig _config = const WebdavSyncConfig();
  bool _loading = true;
  bool _syncing = false;
  bool _creatingBackup = false;
  bool _loadingBackups = false;
  bool _hasStoredPassword = false;
  List<CloudBackupEntry> _backupEntries = const [];

  WebdavSyncCoordinator get _coordinator => WebdavSyncCoordinator.instance();

  bool get _isAccountConnected =>
      _config.username.trim().isNotEmpty && _hasStoredPassword;

  @override
  void initState() {
    super.initState();
    _coordinator.onConflict = _resolveConflict;
    unawaited(_loadConfig());
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _remoteFolderController.dispose();
    _deviceLabelController.dispose();
    super.dispose();
  }

  Future<void> _loadBackups() async {
    if (!_isAccountConnected || !_config.enabled) {
      return;
    }
    setState(() {
      _loadingBackups = true;
    });
    try {
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
        _backupEntries = result.entries;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingBackups = false;
        });
      }
    }
  }

  static String formatBackupDateTime(DateTime value) =>
      CloudBackupUiHelpers.formatBackupDateTime(value);

  static String resolveBackupDeviceLabel(
    BuildContext context,
    String deviceLabel,
  ) => CloudBackupUiHelpers.resolveBackupDeviceLabel(context, deviceLabel);

  static String buildBackupSubtitle(
    BuildContext context,
    CloudBackupEntry entry,
  ) => CloudBackupUiHelpers.buildBackupSubtitle(context, entry);

  Future<void> _loadConfig() async {
    final config = await _coordinator.syncService.loadConfig();
    final password = await _credentialsStore.readPassword();
    final deviceLabel = await _credentialsStore.readDeviceLabel();
    if (!mounted) {
      return;
    }
    setState(() {
      _config = config;
      _hasStoredPassword = password?.trim().isNotEmpty ?? false;
      _baseUrlController.text = config.baseUrl;
      _remoteFolderController.text = config.remoteFolder;
      _deviceLabelController.text = deviceLabel ?? '';
      _loading = false;
    });
    await _coordinator.refreshStatus();
    await _loadBackups();
  }

  Future<void> _saveConfig(WebdavSyncConfig nextConfig) async {
    await _coordinator.syncService.saveConfig(nextConfig);
    if (!mounted) {
      return;
    }
    setState(() {
      _config = nextConfig;
    });
    await _coordinator.refreshStatus();
  }

  Future<SyncConflictChoice?> _resolveConflict(SyncConflictInfo info) async {
    if (!mounted) {
      return SyncConflictChoice.cancel;
    }
    final l10n = AppLocalizations.of(context)!;
    final choice = await showHyperosDialog<SyncConflictChoice>(
      context: context,
      title: l10n.cloudSyncConflictTitle,
      message: l10n.cloudSyncConflictBody,
      actions: [
        HyperosDialogAction(
          label: l10n.cancelAction,
          onPressed: () => Navigator.pop(context, SyncConflictChoice.cancel),
        ),
        HyperosDialogAction(
          label: l10n.cloudSyncUseRemoteAction,
          onPressed: () =>
              Navigator.pop(context, SyncConflictChoice.keepRemote),
        ),
        HyperosDialogAction(
          label: l10n.cloudSyncKeepLocalAction,
          isPrimary: true,
          onPressed: () => Navigator.pop(context, SyncConflictChoice.keepLocal),
        ),
      ],
    );
    return choice;
  }

  Future<void> _openConnectSheet() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showHyperosSheet<_WebdavConnectResult>(
      context: context,
      builder: (ctx) => _WebdavConnectSheet(
        syncService: _coordinator.syncService,
        config: _config,
        baseUrl: _baseUrlController.text.trim().isEmpty
            ? WebdavSyncConfig.defaultJianguoyunBaseUrl
            : _baseUrlController.text.trim(),
      ),
    );
    if (result == null || !mounted) {
      return;
    }

    await _credentialsStore.writePassword(result.password);
    final deviceLabel = await _coordinator.syncService.resolveDeviceLabel();
    if (deviceLabel.isNotEmpty) {
      await _credentialsStore.writeDeviceLabel(deviceLabel);
    }
    final nextConfig = _config.copyWith(
      username: result.username,
      enabled: true,
    );
    await _saveConfig(nextConfig);
    setState(() {
      _hasStoredPassword = true;
      _deviceLabelController.text = deviceLabel;
    });
    if (!mounted) {
      return;
    }
    showAppToast(
      context,
      message: l10n.cloudSyncConnectSuccess,
      kind: AppToastKind.success,
    );
  }

  Future<void> _disconnectAccount() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.cloudSyncDisconnectTitle,
      message: l10n.cloudSyncDisconnectBody,
      confirmLabel: l10n.cloudSyncDisconnect,
      destructiveConfirm: true,
    );
    if (confirmed != true || !mounted) {
      return;
    }

    await _credentialsStore.deletePassword();
    await _credentialsStore.deleteDeviceLabel();
    final nextConfig = _config.copyWith(
      username: '',
      enabled: false,
      clearLastAppliedRemoteHash: true,
      clearLastUploadedLocalHash: true,
      clearLastSyncedAt: true,
    );
    await _saveConfig(nextConfig);
    if (!mounted) {
      return;
    }
    setState(() {
      _hasStoredPassword = false;
      _deviceLabelController.clear();
      _backupEntries = const [];
    });
  }

  Future<void> _saveDeviceLabel() async {
    final label = _deviceLabelController.text.trim();
    if (label.isEmpty) {
      await _credentialsStore.deleteDeviceLabel();
    } else {
      await _credentialsStore.writeDeviceLabel(label);
    }
  }

  Future<void> _openBackupDetail(CloudBackupEntry entry) async {
    final action = await showCloudBackupDetailSheet(
      context: context,
      entry: entry,
      deviceLabel: resolveBackupDeviceLabel(context, entry.deviceLabel),
      formattedTime: formatBackupDateTime(entry.exportedAt),
    );
    if (!mounted || action == null) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    switch (action) {
      case CloudBackupDetailAction.restore:
        final confirmed = await showAppConfirmDialog(
          context,
          title: l10n.cloudBackupRestoreTitle,
          message: l10n.cloudBackupRestoreBody(
            formatBackupDateTime(entry.exportedAt),
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
        showAppToast(
          context,
          message: result.kind == WebdavSyncResultKind.backupRestored
              ? l10n.cloudBackupRestoreSuccess
              : l10n.cloudBackupRestoreFailed(
                  CloudBackupUiHelpers.localizeSyncError(l10n, result.message),
                ),
          kind: result.kind == WebdavSyncResultKind.backupRestored
              ? AppToastKind.success
              : AppToastKind.error,
        );
        if (result.kind == WebdavSyncResultKind.backupRestored) {
          await _loadBackups();
        }
      case CloudBackupDetailAction.delete:
        final confirmed = await showAppConfirmDialog(
          context,
          title: l10n.cloudBackupDeleteTitle,
          message: l10n.cloudBackupDeleteBody(
            formatBackupDateTime(entry.exportedAt),
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
  }

  Future<void> _createManualBackup() async {
    if (!_isAccountConnected || !_config.enabled) {
      return;
    }
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

  Future<void> _openAllBackups() async {
    await HyperosNavigation.push(
      context,
      settings: const RouteSettings(name: '/settings/cloud-sync/backups'),
      builder: (_) => const CloudBackupListScreen(),
    );
    if (mounted) {
      await _loadBackups();
    }
  }

  Future<void> _syncNow() async {
    if (!_isAccountConnected) {
      return;
    }
    setState(() {
      _syncing = true;
    });
    try {
      final result = await _coordinator.syncNow(allowConflictPrompt: true);
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context)!;
      final message = switch (result.kind) {
        WebdavSyncResultKind.uploaded => l10n.cloudSyncResultUploaded,
        WebdavSyncResultKind.downloaded => l10n.cloudSyncResultDownloaded,
        WebdavSyncResultKind.upToDate => l10n.cloudSyncResultUpToDate,
        WebdavSyncResultKind.cancelled => l10n.cloudSyncResultCancelled,
        WebdavSyncResultKind.failed => l10n.cloudSyncResultFailed(
          CloudBackupUiHelpers.localizeSyncError(l10n, result.message),
        ),
        _ => l10n.cloudSyncResultUpToDate,
      };
      showAppToast(
        context,
        message: message,
        kind: result.kind == WebdavSyncResultKind.failed
            ? AppToastKind.error
            : AppToastKind.success,
      );
      if (result.kind == WebdavSyncResultKind.uploaded ||
          result.kind == WebdavSyncResultKind.downloaded) {
        await _loadBackups();
      }
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
        });
      }
    }
  }

  Future<void> _saveAdvancedFields() async {
    await _saveConfig(
      _config.copyWith(
        baseUrl: _baseUrlController.text.trim().isEmpty
            ? WebdavSyncConfig.defaultJianguoyunBaseUrl
            : _baseUrlController.text.trim(),
        remoteFolder: _remoteFolderController.text.trim().isEmpty
            ? WebdavSyncConfig.defaultRemoteFolder
            : _remoteFolderController.text.trim(),
      ),
    );
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String _providerLabel(AppLocalizations l10n) {
    return switch (_config.provider) {
      WebdavSyncProvider.jianguoyun => l10n.cloudSyncProviderJianguoyun,
      WebdavSyncProvider.custom => l10n.cloudSyncProviderCustom,
    };
  }

  Widget _buildIntroBanner(AppLocalizations l10n) {
    return HyperosHintBanner(
      icon: Icon(
        Icons.cloud_sync_rounded,
        size: 18,
        color: HyperosColors.primary(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.cloudSyncIntroTitle,
            style: HyperosTypography.listTitle(context),
          ),
          const SizedBox(height: 4),
          Text(l10n.cloudSyncIntroSubtitle),
        ],
      ),
    );
  }

  Widget _buildHelpBanner(AppLocalizations l10n) {
    return HyperosHintBanner(
      icon: Icon(
        Icons.help_outline_rounded,
        size: 18,
        color: HyperosColors.primary(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.cloudSyncHelpTitle,
            style: HyperosTypography.listTitle(context),
          ),
          const SizedBox(height: 4),
          Text(l10n.cloudSyncHelpBody),
        ],
      ),
    );
  }

  Widget _buildAdvancedSection(AppLocalizations l10n) {
    return HyperosControlCard(
      edgeToEdge: true,
      child: HyperosAccordion(
        items: [
          HyperosAccordionItem(
            title: Row(
              children: [
                const HyperosIconBadge(
                  icon: Icons.tune_outlined,
                  accent: HyperosIconColors.blue,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    l10n.cloudSyncAdvancedTitle,
                    style: HyperosTypography.listTitle(context),
                  ),
                ),
              ],
            ),
            child: Column(
              children: [
                HyperosTextField(
                  controller: _baseUrlController,
                  label: l10n.cloudSyncBaseUrlLabel,
                  onSubmitted: (_) => _saveAdvancedFields(),
                ),
                const SizedBox(height: 12),
                HyperosTextField(
                  controller: _remoteFolderController,
                  label: l10n.cloudSyncRemoteFolderLabel,
                  onSubmitted: (_) => _saveAdvancedFields(),
                ),
                const SizedBox(height: 12),
                HyperosTextField(
                  controller: _deviceLabelController,
                  label: l10n.cloudBackupDeviceLabelTitle,
                  hint: l10n.cloudBackupDeviceLabelHint,
                  onSubmitted: (_) => _saveDeviceLabel(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection(AppLocalizations l10n) {
    if (_isAccountConnected) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HyperosSectionLabel(text: l10n.cloudSyncAccountSectionTitle),
          HyperosSummaryCard(
            leading: SizedBox(
              width: HyperosSummaryCard.leadingSize,
              height: HyperosSummaryCard.leadingSize,
              child: Center(
                child: HyperosIconBadge(
                  icon: Icons.cloud_done_rounded,
                  accent: HyperosIconColors.teal,
                ),
              ),
            ),
            title: l10n.cloudSyncConnectedAs(_config.username.trim()),
            subtitle: _providerLabel(l10n),
          ),
          const HyperosSectionGap(),
          HyperosListGroup(
            children: [
              HyperosActionTile(
                icon: Icons.link_off_rounded,
                title: l10n.cloudSyncDisconnect,
                onTap: _disconnectAccount,
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HyperosSectionLabel(text: l10n.cloudSyncAccountSectionTitle),
        HyperosListGroup(
          children: [
            HyperosNavTile(
              title: l10n.cloudSyncConnectAccount,
              subtitle: l10n.cloudSyncNotConnectedHint,
              onTap: _openConnectSheet,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBackupSection(AppLocalizations l10n) {
    final previewEntries = _backupEntries.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HyperosSectionLabel(text: l10n.cloudBackupSectionTitle),
        HyperosControlCard(
          child: HyperosControlCardInset(
            child: HyperosButton(
              label: l10n.cloudBackupCreateNow,
              loading: _creatingBackup,
              onPressed: _creatingBackup || _syncing
                  ? null
                  : _createManualBackup,
            ),
          ),
        ),
        const HyperosSectionGap(),
        if (_loadingBackups)
          const HyperosControlCard(
            edgeToEdge: true,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: HyperosCircularProgress()),
            ),
          )
        else if (previewEntries.isEmpty)
          HyperosListGroup(
            children: [
              HyperosNavTile(title: l10n.cloudBackupEmpty, enabled: false),
            ],
          )
        else
          HyperosListGroup(
            children: [
              for (final entry in previewEntries)
                HyperosNavTile(
                  title: entry.isCurrent
                      ? l10n.cloudBackupCurrentLabel
                      : formatBackupDateTime(entry.exportedAt),
                  subtitle: buildBackupSubtitle(context, entry),
                  details: entry.isCurrent
                      ? l10n.cloudBackupCurrentBadge
                      : null,
                  onTap: () => _openBackupDetail(entry),
                ),
              if (_backupEntries.length > 3)
                HyperosNavTile(
                  title: l10n.cloudBackupViewAll,
                  onTap: _openAllBackups,
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildRetentionSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HyperosSectionLabel(text: l10n.cloudBackupRetentionTitle),
        HyperosControlCard(
          edgeToEdge: true,
          child: HyperosControlCardRows(
            children: [
              HyperosSelectTile<int>(
                label: l10n.cloudBackupMaxCountTitle,
                subtitle: l10n.cloudBackupMaxCountSubtitle,
                items: {
                  for (final count in _maxBackupCountOptions)
                    l10n.cloudBackupMaxCountOption(count): count,
                },
                value: _config.maxBackupCount,
                onChanged: (value) {
                  if (value == _config.maxBackupCount) {
                    return;
                  }
                  unawaited(
                    _saveConfig(_config.copyWith(maxBackupCount: value)),
                  );
                },
              ),
              HyperosSelectTile<int>(
                label: l10n.cloudBackupMaxAgeTitle,
                subtitle: l10n.cloudBackupMaxAgeSubtitle,
                items: {
                  for (final days in _maxBackupAgeOptions)
                    l10n.cloudBackupMaxAgeOption(days): days,
                },
                value: _config.maxBackupAgeDays,
                onChanged: (value) {
                  if (value == _config.maxBackupAgeDays) {
                    return;
                  }
                  unawaited(
                    _saveConfig(_config.copyWith(maxBackupAgeDays: value)),
                  );
                },
              ),
            ],
          ),
        ),
        const HyperosSectionGap(),
        HyperosListGroup(
          children: [
            HyperosSwitchTile(
              title: l10n.cloudBackupManualProtectedTitle,
              subtitle: l10n.cloudBackupManualProtectedSubtitle,
              value: _config.manualBackupProtected,
              onChanged: (value) {
                unawaited(
                  _saveConfig(_config.copyWith(manualBackupProtected: value)),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSyncNowSection(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HyperosSectionLabel(text: l10n.cloudSyncSyncNow),
        HyperosControlCard(
          child: HyperosControlCardInset(
            child: HyperosButton(
              label: l10n.cloudSyncSyncNow,
              loading: _syncing,
              onPressed: _syncing || !_config.enabled ? null : _syncNow,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSection(AppLocalizations l10n, WebdavSyncStatus status) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HyperosSectionLabel(text: l10n.cloudSyncStatusTitle),
        HyperosControlCard(
          child: HyperosControlCardInset(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CloudSyncInfoRow(
                  label: l10n.cloudSyncLastSyncedLabel,
                  value: _formatDateTime(status.lastSyncedAt),
                  isLast: !status.isSyncing && status.lastError == null,
                ),
                if (status.isSyncing)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: status.lastError == null ? 0 : 8,
                    ),
                    child: Row(
                      children: [
                        _buttonLoadingPrefix(),
                        const SizedBox(width: 8),
                        Text(
                          l10n.cloudSyncSyncing,
                          style: HyperosTypography.listTitle(context),
                        ),
                      ],
                    ),
                  ),
                if (status.lastError != null)
                  _CloudSyncInfoRow(
                    label: l10n.cloudSyncLastErrorLabel,
                    value: CloudBackupUiHelpers.localizeSyncError(
                      l10n,
                      status.lastError,
                    ),
                    valueColor: HyperosColors.error(context),
                    isLast: true,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return HyperosSubpage(
        onBack: () => Navigator.pop(context),
        title: Text(l10n.cloudSyncTitle),
        child: const Center(child: HyperosCircularProgress()),
      );
    }

    return ListenableBuilder(
      listenable: _coordinator,
      builder: (context, _) {
        final status = _coordinator.status;

        return HyperosSubpage(
          onBack: () => Navigator.pop(context),
          title: Text(l10n.cloudSyncTitle),
          child: HyperosListView(
            children: [
              _buildIntroBanner(l10n),
              const HyperosSectionGap(),
              _buildAccountSection(l10n),
              if (_isAccountConnected) ...[
                const HyperosSectionGap(),
                HyperosSectionLabel(text: l10n.cloudSyncSettingsSectionTitle),
                HyperosListGroup(
                  children: [
                    HyperosSwitchTile(
                      title: l10n.cloudSyncEnabledTitle,
                      subtitle: l10n.cloudSyncEnabledSubtitle,
                      value: _config.enabled,
                      onChanged: (value) {
                        unawaited(
                          _saveConfig(_config.copyWith(enabled: value)),
                        );
                      },
                    ),
                  ],
                ),
                const HyperosSectionGap(),
                HyperosControlCard(
                  edgeToEdge: true,
                  child: HyperosControlCardRows(
                    children: [
                      HyperosSelectTile<WebdavSyncProvider>(
                        label: l10n.cloudSyncProviderTitle,
                        items: {
                          l10n.cloudSyncProviderJianguoyun:
                              WebdavSyncProvider.jianguoyun,
                          l10n.cloudSyncProviderCustom:
                              WebdavSyncProvider.custom,
                        },
                        value: _config.provider,
                        onChanged: (value) {
                          if (value == _config.provider) {
                            return;
                          }
                          var baseUrl = _baseUrlController.text.trim();
                          if (value == WebdavSyncProvider.jianguoyun) {
                            baseUrl = WebdavSyncConfig.defaultJianguoyunBaseUrl;
                            _baseUrlController.text = baseUrl;
                          }
                          unawaited(
                            _saveConfig(
                              _config.copyWith(
                                provider: value,
                                baseUrl: baseUrl,
                              ),
                            ),
                          );
                        },
                      ),
                      HyperosSelectTile<WebdavSyncMode>(
                        label: l10n.cloudSyncModeTitle,
                        subtitle: l10n.cloudSyncSettingsSectionSubtitle,
                        items: {
                          l10n.cloudSyncModeAuto: WebdavSyncMode.auto,
                          l10n.cloudSyncModeManual: WebdavSyncMode.manual,
                        },
                        value: _config.syncMode,
                        onChanged: (value) {
                          if (value == _config.syncMode) {
                            return;
                          }
                          unawaited(
                            _saveConfig(_config.copyWith(syncMode: value)),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const HyperosSectionGap(),
                _buildAdvancedSection(l10n),
                const HyperosSectionGap(),
                _buildStatusSection(l10n, status),
                const HyperosSectionGap(),
                if (_config.enabled) _buildSyncNowSection(l10n),
                if (_config.enabled) const HyperosSectionGap(),
                if (_config.enabled) _buildBackupSection(l10n),
                if (_config.enabled) const HyperosSectionGap(),
                if (_config.enabled) _buildRetentionSection(l10n),
              ],
              const HyperosSectionGap(),
              _buildHelpBanner(l10n),
            ],
          ),
        );
      },
    );
  }
}

class _CloudSyncInfoRow extends StatelessWidget {
  const _CloudSyncInfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isLast = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: HyperosTypography.listDetail(context)),
          ),
          Expanded(
            child: Text(
              value,
              style: HyperosTypography.listTitle(
                context,
              ).copyWith(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _WebdavConnectResult {
  final String username;
  final String password;

  const _WebdavConnectResult({required this.username, required this.password});
}

class _WebdavConnectSheet extends StatefulWidget {
  const _WebdavConnectSheet({
    required this.syncService,
    required this.config,
    required this.baseUrl,
  });

  final WebdavSyncService syncService;
  final WebdavSyncConfig config;
  final String baseUrl;

  @override
  State<_WebdavConnectSheet> createState() => _WebdavConnectSheetState();
}

class _WebdavConnectSheetState extends State<_WebdavConnectSheet> {
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  bool _testing = false;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.config.username);
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  WebdavSyncConfig _draftConfig() {
    return widget.config.copyWith(
      username: _usernameController.text.trim(),
      baseUrl: widget.baseUrl,
    );
  }

  Future<bool> _testConnection() async {
    final password = _passwordController.text;
    if (_usernameController.text.trim().isEmpty || password.isEmpty) {
      return false;
    }
    setState(() {
      _testing = true;
    });
    try {
      await widget.syncService.testConnection(
        config: _draftConfig(),
        passwordOverride: password,
      );
      if (!mounted) {
        return false;
      }
      showAppToast(
        context,
        message: AppLocalizations.of(context)!.cloudSyncTestSuccess,
        kind: AppToastKind.success,
      );
      return true;
    } catch (_) {
      if (!mounted) {
        return false;
      }
      showAppToast(
        context,
        message: AppLocalizations.of(context)!.cloudSyncTestFailed,
        kind: AppToastKind.error,
      );
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _testing = false;
        });
      }
    }
  }

  Future<void> _confirmConnect() async {
    if (_connecting) {
      return;
    }
    setState(() {
      _connecting = true;
    });
    try {
      final ok = await _testConnection();
      if (!ok || !mounted) {
        return;
      }
      Navigator.of(context).pop(
        _WebdavConnectResult(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _connecting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PickerSheetScaffold(
      actions: Row(
        children: [
          Expanded(
            child: HyperosButton(
              label: l10n.cloudSyncTestConnection,
              variant: HyperosButtonVariant.secondary,
              loading: _testing,
              onPressed: _testing || _connecting ? null : _testConnection,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: HyperosButton(
              label: l10n.cloudSyncConfirmConnect,
              loading: _connecting,
              onPressed: _connecting ? null : _confirmConnect,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.cloudSyncLoginSheetTitle,
            style: HyperosTypography.sheetTitle(context),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.cloudSyncLoginSheetSubtitle,
            style: HyperosTypography.sectionDescription(context),
          ),
          const SizedBox(height: 16),
          HyperosTextField(
            controller: _usernameController,
            label: l10n.cloudSyncUsernameLabel,
            hint: l10n.cloudSyncUsernameHint,
          ),
          const SizedBox(height: 12),
          HyperosTextField(
            controller: _passwordController,
            label: l10n.cloudSyncPasswordLabel,
            hint: l10n.cloudSyncPasswordHint,
            obscureText: true,
          ),
        ],
      ),
    );
  }
}
