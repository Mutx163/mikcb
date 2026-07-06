import 'dart:async';

import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../services/app_sync_snapshot_service.dart';
import '../services/webdav_sync_config.dart';
import '../services/webdav_sync_coordinator.dart';
import '../services/webdav_sync_credentials_store.dart';
import '../services/webdav_sync_service.dart';
import '../utils/app_toast.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/course_field_picker_sheet.dart';
import '../ui/hyperos/hyperos.dart';

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
  final _baseUrlController = TextEditingController();
  final _remoteFolderController = TextEditingController();
  final _credentialsStore = const WebdavSyncCredentialsStore();

  WebdavSyncConfig _config = const WebdavSyncConfig();
  bool _loading = true;
  bool _syncing = false;
  String? _storedPassword;

  WebdavSyncCoordinator get _coordinator => WebdavSyncCoordinator.instance();

  bool get _isAccountConnected =>
      _config.username.trim().isNotEmpty &&
      (_storedPassword?.isNotEmpty ?? false);

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
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final config = await _coordinator.syncService.loadConfig();
    final password = await _credentialsStore.readPassword();
    if (!mounted) {
      return;
    }
    setState(() {
      _config = config;
      _storedPassword = password;
      _baseUrlController.text = config.baseUrl;
      _remoteFolderController.text = config.remoteFolder;
      _loading = false;
    });
    await _coordinator.refreshStatus();
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
    final nextConfig = _config.copyWith(
      username: result.username,
      enabled: true,
    );
    await _saveConfig(nextConfig);
    setState(() {
      _storedPassword = result.password;
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
      _storedPassword = null;
    });
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
          result.message ?? '',
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
        color: HyperosTokens.accent,
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
        color: HyperosTokens.accent,
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

  Widget _buildStatusSection(AppLocalizations l10n, WebdavSyncStatus status) {
    return HyperosControlCard(
      title: l10n.cloudSyncStatusTitle,
      plainTitle: true,
      child: HyperosControlCardInset(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CloudSyncInfoRow(
              label: l10n.cloudSyncLastSyncedLabel,
              value: _formatDateTime(status.lastSyncedAt),
            ),
            if (status.isSyncing)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    _buttonLoadingPrefix(),
                    const SizedBox(width: 8),
                    Text(
                      l10n.cloudSyncSyncing,
                      style: HyperosTypography.listTitle(
                        context,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            if (status.lastError != null)
              _CloudSyncInfoRow(
                label: l10n.cloudSyncLastErrorLabel,
                value: status.lastError!,
                valueColor: HyperosTokens.error,
              ),
          ],
        ),
      ),
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
                  child: HyperosSelectTile<WebdavSyncProvider>(
                    label: l10n.cloudSyncProviderTitle,
                    items: {
                      l10n.cloudSyncProviderJianguoyun:
                          WebdavSyncProvider.jianguoyun,
                      l10n.cloudSyncProviderCustom: WebdavSyncProvider.custom,
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
                          _config.copyWith(provider: value, baseUrl: baseUrl),
                        ),
                      );
                    },
                  ),
                ),
                const HyperosSectionGap(),
                HyperosControlCard(
                  edgeToEdge: true,
                  child: HyperosSelectTile<WebdavSyncMode>(
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
                      unawaited(_saveConfig(_config.copyWith(syncMode: value)));
                    },
                  ),
                ),
                const HyperosSectionGap(),
                _buildAdvancedSection(l10n),
                const HyperosSectionGap(),
                _buildStatusSection(l10n, status),
                const HyperosSectionGap(),
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
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
