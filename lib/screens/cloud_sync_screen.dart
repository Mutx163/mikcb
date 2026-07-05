import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../services/app_sync_snapshot_service.dart';
import '../services/webdav_sync_config.dart';
import '../services/webdav_sync_coordinator.dart';
import '../services/webdav_sync_credentials_store.dart';
import '../services/webdav_sync_service.dart';
import '../utils/app_toast.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/course_field_picker_sheet.dart';
import '../widgets/settings_section_widgets.dart';

const _buttonIconSize = 18.0;

Widget _buttonLoadingPrefix() {
  return const SizedBox(
    width: 16,
    height: 16,
    child: FCircularProgress(size: FCircularProgressSizeVariant.xs),
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
  bool _showAdvanced = false;
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
    final choice = await showFDialog<SyncConflictChoice>(
      context: context,
      builder: (ctx, style, animation) {
        return FDialog(
          title: Text(l10n.cloudSyncConflictTitle),
          body: Text(l10n.cloudSyncConflictBody),
          actions: [
            FButton(
              variant: FButtonVariant.ghost,
              onPress: () => Navigator.pop(ctx, SyncConflictChoice.cancel),
              child: Text(l10n.cancelAction),
            ),
            FButton(
              variant: FButtonVariant.secondary,
              onPress: () => Navigator.pop(ctx, SyncConflictChoice.keepRemote),
              child: Text(l10n.cloudSyncUseRemoteAction),
            ),
            FButton(
              variant: FButtonVariant.primary,
              onPress: () => Navigator.pop(ctx, SyncConflictChoice.keepLocal),
              child: Text(l10n.cloudSyncKeepLocalAction),
            ),
          ],
        );
      },
    );
    return choice;
  }

  Future<void> _openConnectSheet() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showFSheet<_WebdavConnectResult>(
      context: context,
      side: FLayout.btt,
      useSafeArea: true,
      draggable: true,
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
      confirmVariant: FButtonVariant.destructive,
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

  Widget _buildAccountSection(AppLocalizations l10n) {
    if (_isAccountConnected) {
      final colorScheme = Theme.of(context).colorScheme;
      return FTileGroup(
        label: Text(l10n.cloudSyncAccountSectionTitle),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          FTile(
            title: Text(l10n.cloudSyncConnectedAs(_config.username.trim())),
            suffix: Icon(
              Icons.check_circle_rounded,
              color: colorScheme.primary,
              size: 20,
            ),
          ),
          FTile(
            prefix: const Icon(Icons.link_off_rounded),
            title: Text(l10n.cloudSyncDisconnect),
            onPress: _disconnectAccount,
          ),
        ],
      );
    }

    return FTileGroup(
      label: Text(l10n.cloudSyncAccountSectionTitle),
      description: Text(l10n.cloudSyncNotConnectedHint),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        FTile(
          prefix: const Icon(Icons.login_rounded),
          title: Text(l10n.cloudSyncConnectAccount),
          suffix: Icon(
            Icons.chevron_right_rounded,
            color: context.theme.colors.mutedForeground,
          ),
          onPress: _openConnectSheet,
        ),
      ],
    );
  }

  Widget _buildStatusSection(AppLocalizations l10n, WebdavSyncStatus status) {
    return SettingsSectionCard(
      title: l10n.cloudSyncStatusTitle,
      plainTitle: true,
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
                    style: context.theme.typography.body.xs2.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          if (status.lastError != null)
            _CloudSyncInfoRow(
              label: l10n.cloudSyncLastErrorLabel,
              value: status.lastError!,
              valueColor: context.theme.colors.destructive,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return FScaffold(
        header: FHeader.nested(
          prefixes: [FHeaderAction.back(onPress: () => Navigator.pop(context))],
          title: Text(l10n.cloudSyncTitle),
        ),
        child: const Center(child: FCircularProgress()),
      );
    }

    return ListenableBuilder(
      listenable: _coordinator,
      builder: (context, _) {
        final status = _coordinator.status;
        final showAdvanced =
            _showAdvanced &&
            (_isAccountConnected ||
                _config.provider == WebdavSyncProvider.custom);

        return FScaffold(
          header: FHeader.nested(
            prefixes: [
              FHeaderAction.back(onPress: () => Navigator.pop(context)),
            ],
            title: Text(l10n.cloudSyncTitle),
          ),
          childPad: false,
          child: Material(
            type: MaterialType.transparency,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SettingsSectionCard(
                  title: l10n.cloudSyncIntroTitle,
                  subtitle: l10n.cloudSyncIntroSubtitle,
                  plainTitle: true,
                  child: const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
                _buildAccountSection(l10n),
                if (_isAccountConnected) ...[
                  const SizedBox(height: 12),
                  FTileGroup(
                    label: Text(l10n.cloudSyncSettingsSectionTitle),
                    description: Text(l10n.cloudSyncSettingsSectionSubtitle),
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      SettingSwitchTile(
                        title: Text(l10n.cloudSyncEnabledTitle),
                        subtitle: Text(l10n.cloudSyncEnabledSubtitle),
                        value: _config.enabled,
                        onChanged: (value) async {
                          await _saveConfig(_config.copyWith(enabled: value));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SettingsSectionCard(
                    child: FSelect<WebdavSyncProvider>(
                      hint: l10n.cloudSyncProviderTitle,
                      items: {
                        l10n.cloudSyncProviderJianguoyun:
                            WebdavSyncProvider.jianguoyun,
                        l10n.cloudSyncProviderCustom: WebdavSyncProvider.custom,
                      },
                      control: FSelectControl.lifted(
                        value: _config.provider,
                        onChange: (value) async {
                          if (value == null || value == _config.provider) {
                            return;
                          }
                          var baseUrl = _baseUrlController.text.trim();
                          if (value == WebdavSyncProvider.jianguoyun) {
                            baseUrl = WebdavSyncConfig.defaultJianguoyunBaseUrl;
                            _baseUrlController.text = baseUrl;
                          }
                          await _saveConfig(
                            _config.copyWith(provider: value, baseUrl: baseUrl),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SettingsSectionCard(
                    child: FSelect<WebdavSyncMode>(
                      hint: l10n.cloudSyncModeTitle,
                      items: {
                        l10n.cloudSyncModeAuto: WebdavSyncMode.auto,
                        l10n.cloudSyncModeManual: WebdavSyncMode.manual,
                      },
                      control: FSelectControl.lifted(
                        value: _config.syncMode,
                        onChange: (value) async {
                          if (value == null || value == _config.syncMode) {
                            return;
                          }
                          await _saveConfig(_config.copyWith(syncMode: value));
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FTileGroup(
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      FTile(
                        title: Text(l10n.cloudSyncAdvancedTitle),
                        suffix: Icon(
                          _showAdvanced
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                        ),
                        onPress: () {
                          setState(() {
                            _showAdvanced = !_showAdvanced;
                          });
                        },
                      ),
                    ],
                  ),
                  if (showAdvanced) ...[
                    const SizedBox(height: 12),
                    SettingsSectionCard(
                      child: Column(
                        children: [
                          FTextField(
                            control: FTextFieldControl.managed(
                              controller: _baseUrlController,
                            ),
                            label: Text(l10n.cloudSyncBaseUrlLabel),
                            onSubmit: (_) => _saveAdvancedFields(),
                          ),
                          const SizedBox(height: 12),
                          FTextField(
                            control: FTextFieldControl.managed(
                              controller: _remoteFolderController,
                            ),
                            label: Text(l10n.cloudSyncRemoteFolderLabel),
                            onSubmit: (_) => _saveAdvancedFields(),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildStatusSection(l10n, status),
                  const SizedBox(height: 12),
                  SettingsSectionCard(
                    child: FButton(
                      variant: FButtonVariant.primary,
                      onPress: _syncing || !_config.enabled ? null : _syncNow,
                      prefix: _syncing
                          ? _buttonLoadingPrefix()
                          : const Icon(
                              Icons.sync_rounded,
                              size: _buttonIconSize,
                            ),
                      child: Text(l10n.cloudSyncSyncNow),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SettingsSectionCard(
                  title: l10n.cloudSyncHelpTitle,
                  subtitle: l10n.cloudSyncHelpBody,
                  plainTitle: true,
                  child: const SizedBox.shrink(),
                ),
              ],
            ),
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
    final typo = context.theme.typography.body;
    final colors = context.theme.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: typo.xs2.copyWith(color: colors.mutedForeground),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: typo.xs2.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
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
    final typo = context.theme.typography.body;

    return PickerSheetScaffold(
      actions: Row(
        children: [
          Expanded(
            child: FButton(
              variant: FButtonVariant.secondary,
              onPress: _testing || _connecting ? null : _testConnection,
              prefix: _testing
                  ? _buttonLoadingPrefix()
                  : const Icon(Icons.link_rounded, size: _buttonIconSize),
              child: Text(l10n.cloudSyncTestConnection),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FButton(
              onPress: _connecting ? null : _confirmConnect,
              prefix: _connecting
                  ? _buttonLoadingPrefix()
                  : const Icon(Icons.check_rounded, size: _buttonIconSize),
              child: Text(l10n.cloudSyncConfirmConnect),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.cloudSyncLoginSheetTitle,
            style: typo.lg.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(l10n.cloudSyncLoginSheetSubtitle, style: typo.sm),
          const SizedBox(height: 16),
          FTextField(
            control: FTextFieldControl.managed(controller: _usernameController),
            label: Text(l10n.cloudSyncUsernameLabel),
            hint: l10n.cloudSyncUsernameHint,
          ),
          const SizedBox(height: 12),
          FTextField(
            control: FTextFieldControl.managed(controller: _passwordController),
            label: Text(l10n.cloudSyncPasswordLabel),
            hint: l10n.cloudSyncPasswordHint,
          ),
        ],
      ),
    );
  }
}
