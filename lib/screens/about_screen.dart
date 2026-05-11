import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/warehouse_repository_models.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../services/app_analytics.dart';
import '../services/app_log_service.dart';
import '../services/app_update_service.dart';
import '../services/miui_live_activities_service.dart';
import '../services/support_creator_service.dart';
import '../services/warehouse_repository_service.dart';
import 'live_diagnostics_log_viewer_screen.dart';

enum AboutUpdatePrimaryAction {
  openReleasePage,
  downloadInApp,
  openDownloadLink,
}

@visibleForTesting
AboutUpdatePrimaryAction resolveAboutUpdatePrimaryAction({
  required bool isAndroid,
  required String? downloadUrl,
  required AppUpdateDownloadChannel channel,
}) {
  final hasDownloadUrl = (downloadUrl ?? '').trim().isNotEmpty;
  if (!hasDownloadUrl) {
    return AboutUpdatePrimaryAction.openReleasePage;
  }
  // 蒲公英渠道：始终用浏览器打开下载页面
  if (channel == AppUpdateDownloadChannel.pgyer) {
    return AboutUpdatePrimaryAction.openDownloadLink;
  }
  // GitHub 渠道：Android 应用内下载，其他平台打开链接
  if (isAndroid) {
    return AboutUpdatePrimaryAction.downloadInApp;
  }
  return AboutUpdatePrimaryAction.openDownloadLink;
}

class _MirrorProbeState {
  final AppUpdateMirrorPreset preset;
  final String prefix;
  final AppUpdateDownloadProbeResult result;

  const _MirrorProbeState({
    required this.preset,
    required this.prefix,
    required this.result,
  });
}

@visibleForTesting
AppUpdateMirrorPreset? resolveRecommendedMirrorPreset(
  Map<AppUpdateMirrorPreset, AppUpdateDownloadProbeResult> probeResults,
) {
  final successfulEntries = probeResults.entries
      .where((entry) => entry.value.isSuccess)
      .toList()
    ..sort((left, right) => left.value.elapsed.compareTo(right.value.elapsed));
  return successfulEntries.isEmpty ? null : successfulEntries.first.key;
}

@visibleForTesting
AppUpdateMirrorPreset? resolveMirrorFallbackPreset({
  required AppUpdateMirrorPreset currentPreset,
  required List<AppUpdateMirrorPreset> availablePresets,
}) {
  for (final preset in availablePresets) {
    if (preset != currentPreset) {
      return preset;
    }
  }
  return null;
}

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    setState(() {
      _packageInfo = info;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settings =
        context.select<TimetableProvider, TimetableSettings>((provider) {
      return provider.settings;
    });
    final versionText = _packageInfo == null
        ? l10n.loadingText
        : l10n.versionLabel(
            '${_packageInfo!.version} (${_packageInfo!.buildNumber})',
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aboutTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/branding/launcher_icon.png',
                        fit: BoxFit.cover,
                        cacheWidth: 168,
                        cacheHeight: 168,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.calendar_view_week_rounded,
                            color: colorScheme.primary,
                            size: 42,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.timetableAppName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    versionText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.aboutHeroSubtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildInfoChip(theme,
                          label: l10n.platformLabel, value: 'Android'),
                      _buildInfoChip(theme,
                          label: l10n.focusLabel, value: 'HyperOS'),
                      _buildInfoChip(
                        theme,
                        label: l10n.updateLabel,
                        value: settings.appUpdateIncludePrerelease
                            ? l10n.prereleaseIncluded
                            : l10n.stableOnly,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                _AboutNavTile(
                  icon: Icons.system_update_alt_rounded,
                  title: l10n.aboutUpdatesTitle,
                  subtitle: l10n.aboutUpdatesSubtitle,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AboutUpdateScreen(
                          packageInfo: _packageInfo,
                        ),
                      ),
                    );
                  },
                ),
                _AboutNavTile(
                  icon: Icons.flag_outlined,
                  title: l10n.aboutPositioningTitle,
                  subtitle: l10n.aboutPositioningSubtitle,
                  onTap: () {
                    _showInfoSheet(
                      context,
                      title: l10n.aboutPositioningTitle,
                      children: [
                        _AboutBullet(text: l10n.aboutPositioningBullet1),
                        _AboutBullet(
                          text: l10n.aboutPositioningBullet2,
                        ),
                        _AboutBullet(
                          text: l10n.aboutPositioningBullet3,
                        ),
                        _AboutBullet(
                          text: l10n.aboutPositioningBullet4,
                        ),
                      ],
                    );
                  },
                ),
                _AboutNavTile(
                  icon: Icons.import_export_rounded,
                  title: l10n.aboutImportMigrationTitle,
                  subtitle: l10n.aboutImportMigrationSubtitle,
                  onTap: () {
                    _showInfoSheet(
                      context,
                      title: l10n.aboutImportMigrationTitle,
                      children: [
                        _AboutBullet(
                          text: l10n.aboutImportMigrationBullet1,
                        ),
                        _AboutBullet(
                          text: l10n.aboutImportMigrationBullet2,
                        ),
                        _AboutBullet(
                          text: l10n.aboutImportMigrationBullet3,
                        ),
                        _AboutBullet(
                          text: l10n.aboutImportMigrationBullet4,
                        ),
                      ],
                    );
                  },
                ),
                _AboutNavTile(
                  icon: Icons.group_outlined,
                  title: l10n.aboutContributorsTitle,
                  subtitle: l10n.aboutContributorsSubtitle,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        settings:
                            const RouteSettings(name: '/about/contributors'),
                        builder: (_) => const ContributorsScreen(),
                      ),
                    );
                  },
                ),
                _AboutNavTile(
                  icon: Icons.code_rounded,
                  title: l10n.aboutRepositoryTitle,
                  subtitle: l10n.aboutRepositorySubtitle,
                  onTap: () {
                    _showRepositorySheet(context, theme);
                  },
                ),
                _AboutNavTile(
                  icon: Icons.article_outlined,
                  title: l10n.aboutAppLogsTitle,
                  subtitle: l10n.aboutAppLogsSubtitle,
                  onTap: _openAppLogsPage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoSheet(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 16),
                ...children,
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRepositorySheet(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final colorScheme = theme.colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.aboutRepositorySheetTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  AppUpdateService.repositoryUrl,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.aboutRepositorySheetHint,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _openRepository,
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: Text(l10n.aboutOpenGitHubAction),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _openWarehouseRepository,
                        icon: const Icon(Icons.hub_rounded),
                        label: Text(l10n.aboutOpenWarehouseRepoAction),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _copyRepositoryUrl,
                        icon: const Icon(Icons.copy_all_rounded),
                        label: Text(l10n.copyAddress),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAppLogsPage() async {
    final settings = context.read<TimetableProvider>().settings;
    final l10n = AppLocalizations.of(context)!;
    final nativeRawLog =
        await MiuiLiveActivitiesService().readLiveDiagnosticsText();
    final rawLog = await AppLogService.instance.readMergedLogsText(
      nativeRawLog: nativeRawLog,
    );
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveDiagnosticsLogViewerScreen(
          title: AppLocalizations.of(context)!.aboutAppLogsTitle,
          rawLog: rawLog,
          isRecordingEnabled: settings.liveEnableLocalDiagnostics,
          onExport: (text) async {
            final path = await AppLogService.instance.exportMergedLogsFile(
              nativeRawLog: nativeRawLog,
            );
            if (path == null || path.isEmpty) {
              return;
            }
            await Share.shareXFiles(
              [XFile(path)],
              text: l10n.appLogsShareText,
              subject: l10n.appLogsShareSubject,
            );
          },
          onClear: () async {
            final clearedAppLogs = await AppLogService.instance.clearAppLogs();
            final clearedNativeLogs =
                await MiuiLiveActivitiesService().clearLiveDiagnostics();
            return clearedAppLogs || clearedNativeLogs;
          },
        ),
      ),
    );
  }

  Widget _buildInfoChip(
    ThemeData theme, {
    required String label,
    required String value,
  }) {
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openRepository() async {
    final uri = Uri.tryParse(AppUpdateService.repositoryUrl);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _copyRepositoryUrl() async {
    await Clipboard.setData(
      const ClipboardData(text: AppUpdateService.repositoryUrl),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(AppLocalizations.of(context)!.copiedRepositoryAddress)),
    );
  }

  Future<void> _openWarehouseRepository() async {
    final uri = Uri.tryParse('https://github.com/Mutx163/qingyu_warehouse');
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class AboutUpdateScreen extends StatefulWidget {
  final PackageInfo? packageInfo;

  const AboutUpdateScreen({
    super.key,
    required this.packageInfo,
  });

  @override
  State<AboutUpdateScreen> createState() => _AboutUpdateScreenState();
}

class _AboutUpdateScreenState extends State<AboutUpdateScreen> {
  final AppUpdateService _updateService = AppUpdateService();
  final AppAnalytics _analytics = AppAnalytics.instance;
  final SupportCreatorService _supportService = SupportCreatorService();
  Future<AppUpdateCheckResult>? _updateFuture;
  bool _isDownloading = false;
  bool _isCancellingDownload = false;
  bool _isProbingMirrors = false;
  bool _useSystemDownloader = false;
  int _downloadedBytes = 0;
  int? _downloadTotalBytes;
  AppUpdateDownloadController? _downloadController;
  List<_MirrorProbeState> _mirrorProbeStates = const [];

  @override
  void initState() {
    super.initState();
    _refreshUpdate();
  }

  @override
  void dispose() {
    _downloadController?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final settings =
        context.select<TimetableProvider, TimetableSettings>((provider) {
      return provider.settings;
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aboutUpdateScreenTitle),
        actions: [
          IconButton(
            tooltip: l10n.aboutAdvancedOptionsTitle,
            onPressed: () => _openAdvancedOptions(theme, settings),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      bottomNavigationBar:
          _isDownloading ? _buildDownloadProgressBar(theme) : null,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          children: [
            Expanded(child: _buildUpdateCard(theme, settings)),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateCard(ThemeData theme, TimetableSettings settings) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = theme.colorScheme;

    return FutureBuilder<AppUpdateCheckResult>(
      future: _updateFuture,
      builder: (context, snapshot) {
        if (widget.packageInfo == null ||
            snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  _UpdateCheckAnimation(colorScheme: colorScheme),
                  const SizedBox(height: 24),
                  Text(
                    l10n.aboutCheckingLatestVersion,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '正在连接更新服务器...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        }

        final result = snapshot.data;
        if (result == null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.aboutReadVersionFailed,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.aboutReadVersionFailedHint,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            _buildStatusCard(theme, result),
            if ((result.latestRelease?.body ?? '').isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildNotesCard(theme, result),
            ],
          ],
        );
      },
    );
  }

  Widget _buildStatusCard(ThemeData theme, AppUpdateCheckResult result) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = theme.colorScheme;
    final release = result.latestRelease;
    final settings = context.read<TimetableProvider>().settings;
    final downloadChannel = AppUpdateDownloadChannelX.fromValue(
      settings.appUpdateDownloadChannel,
    );
    final downloadSource = AppUpdateDownloadSourceX.fromValue(
      settings.appUpdateDownloadSource,
    );
    final mirrorPreset = AppUpdateMirrorPresetX.fromValue(
      settings.appUpdateMirrorPreset,
    );
    final effectiveMirrorUrlPrefix = resolveAppUpdateMirrorUrlPrefix(
      preset: mirrorPreset,
      customUrlPrefix: settings.appUpdateMirrorUrlPrefix,
    );
    final effectiveDownloadUrl = _updateService.getEffectiveDownloadUrl(
      release: release,
      channel: downloadChannel,
      source: downloadSource,
      mirrorUrlPrefix: effectiveMirrorUrlPrefix,
    );
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final primaryAction = resolveAboutUpdatePrimaryAction(
      isAndroid: isAndroid,
      downloadUrl: effectiveDownloadUrl,
      channel: downloadChannel,
    );
    final primaryButtonLabel = switch (primaryAction) {
      AboutUpdatePrimaryAction.openReleasePage =>
        l10n.aboutViewReleaseAction,
      AboutUpdatePrimaryAction.downloadInApp => l10n.aboutDownloadNowAction,
      AboutUpdatePrimaryAction.openDownloadLink =>
        l10n.aboutOpenDownloadPageAction,
    };
    final primaryButtonIcon = switch (primaryAction) {
      AboutUpdatePrimaryAction.downloadInApp => Icons.download_rounded,
      AboutUpdatePrimaryAction.openDownloadLink ||
      AboutUpdatePrimaryAction.openReleasePage => Icons.open_in_new_rounded,
    };
    final statusColor = result.hasUpdate ? colorScheme.primary : Colors.green;
    final statusIcon =
        result.hasUpdate ? Icons.system_update_rounded : Icons.check_circle;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          children: [
            // 居中状态图标
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, size: 32, color: statusColor),
            ),
            const SizedBox(height: 16),
            // 状态标题
            Text(
              result.hasUpdate ? '有版本更新' : '已是最新版本',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            // 更新时间
            if (release?.updatedAt != null)
              Text(
                l10n.aboutUpdatedAt(_formatDateTime(release!.updatedAt!)),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 20),
            // 版本对比信息
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    Text(
                      l10n.aboutCurrentVersionLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.currentVersion,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    width: 1,
                    height: 32,
                    color: colorScheme.outlineVariant,
                  ),
                ),
                Column(
                  children: [
                    Text(
                      l10n.aboutLatestVersionLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      release?.version ?? l10n.aboutUnreleasedLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            // 主要操作按钮
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: result.hasRelease
                    ? () {
                        if (primaryAction == AboutUpdatePrimaryAction.openReleasePage) {
                          _openUrl(release?.releaseUrl);
                        } else if (downloadChannel == AppUpdateDownloadChannel.pgyer) {
                          // 蒲公英渠道：用浏览器打开下载页面
                          _openUrl(effectiveDownloadUrl);
                        } else if (effectiveDownloadUrl != null) {
                          // GitHub 渠道：应用内下载或系统管理器
                          if (_useSystemDownloader) {
                            _enqueueSystemDownload(
                              url: effectiveDownloadUrl,
                              version: release?.version,
                            );
                          } else {
                            _downloadAndInstall(effectiveDownloadUrl);
                          }
                        }
                      }
                    : null,
                icon: Icon(_isDownloading
                    ? Icons.cancel_rounded
                    : primaryButtonIcon),
                label: Text(_isDownloading
                    ? l10n.aboutDownloadCancelling
                    : primaryButtonLabel),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            // 次要操作按钮
            if (primaryAction != AboutUpdatePrimaryAction.openReleasePage &&
                result.hasRelease) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openUrl(release?.releaseUrl),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text(l10n.aboutViewReleaseAction),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard(ThemeData theme, AppUpdateCheckResult result) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.update_rounded,
                    size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.aboutReleaseNotesTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ReleaseNotesMarkdown(
                data: result.latestRelease!.body.trim(),
                onTapLink: _openUrl,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadMethodTab(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _SegmentedTabButton(
              label: '应用内下载',
              isSelected: !_useSystemDownloader,
              onTap: () => setState(() => _useSystemDownloader = false),
              selectedColor: colorScheme.primary,
              selectedTextColor: colorScheme.onPrimary,
              unselectedTextColor: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _SegmentedTabButton(
              label: '系统管理器',
              isSelected: _useSystemDownloader,
              onTap: () => setState(() => _useSystemDownloader = true),
              selectedColor: colorScheme.primary,
              selectedTextColor: colorScheme.onPrimary,
              unselectedTextColor: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadChannelTab(ThemeData theme, TimetableSettings settings) {
    final colorScheme = theme.colorScheme;
    final downloadChannel = AppUpdateDownloadChannelX.fromValue(
      settings.appUpdateDownloadChannel,
    );
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _SegmentedTabButton(
              label: '蒲公英下载',
              isSelected: downloadChannel == AppUpdateDownloadChannel.pgyer,
              onTap: () => _updateDownloadChannel(AppUpdateDownloadChannel.pgyer),
              selectedColor: colorScheme.primary,
              selectedTextColor: colorScheme.onPrimary,
              unselectedTextColor: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _SegmentedTabButton(
              label: 'GitHub 下载',
              isSelected: downloadChannel == AppUpdateDownloadChannel.github,
              onTap: () => _updateDownloadChannel(AppUpdateDownloadChannel.github),
              selectedColor: colorScheme.primary,
              selectedTextColor: colorScheme.onPrimary,
              unselectedTextColor: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(
    ThemeData theme, {
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final colorScheme = theme.colorScheme;
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged(!value),
      child: Container(
        width: 52,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: value ? colorScheme.primary : colorScheme.surfaceContainerHigh,
          border: Border.all(
            color: value ? colorScheme.primary : colorScheme.outlineVariant,
            width: 1.5,
          ),
        ),
        child: Align(
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    value ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handlePrimaryUpdateAction({
    required AboutUpdatePrimaryAction primaryAction,
    required String? effectiveDownloadUrl,
    required String? releaseUrl,
  }) {
    switch (primaryAction) {
      case AboutUpdatePrimaryAction.downloadInApp:
        if ((effectiveDownloadUrl ?? '').isNotEmpty) {
          _downloadAndInstall(effectiveDownloadUrl!);
        }
        break;
      case AboutUpdatePrimaryAction.openDownloadLink:
        _openUrl(effectiveDownloadUrl);
        break;
      case AboutUpdatePrimaryAction.openReleasePage:
        _openUrl(releaseUrl);
        break;
    }
  }

  Future<void> _openUrl(String? url) async {
    final uri = Uri.tryParse(url ?? '');
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openAdvancedOptions(ThemeData theme, TimetableSettings settings) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _AdvancedOptionsScreen(
          theme: theme,
          settings: settings,
          packageInfo: widget.packageInfo,
          updateService: _updateService,
          analytics: _analytics,
          updateFuture: _updateFuture,
          mirrorProbeStates: _mirrorProbeStates,
          isDownloading: _isDownloading,
          useSystemDownloader: _useSystemDownloader,
          onUseSystemDownloaderChanged: (value) {
            setState(() => _useSystemDownloader = value);
          },
        ),
      ),
    );
  }

  void _refreshUpdate() {
    if (widget.packageInfo == null) {
      return;
    }
    _analytics.logEventLater(name: 'update_check_requested');
    final settings = context.read<TimetableProvider>().settings;
    final downloadSource = AppUpdateDownloadSourceX.fromValue(
      settings.appUpdateDownloadSource,
    );
    final mirrorPreset = AppUpdateMirrorPresetX.fromValue(
      settings.appUpdateMirrorPreset,
    );
    final effectiveMirrorUrlPrefix = resolveAppUpdateMirrorUrlPrefix(
      preset: mirrorPreset,
      customUrlPrefix: settings.appUpdateMirrorUrlPrefix,
    );
    setState(() {
      _updateFuture = _updateService.checkForUpdates(
        currentVersion: widget.packageInfo!.version,
        includePrerelease: settings.appUpdateIncludePrerelease,
        preferredSource: downloadSource,
        mirrorUrlPrefix: effectiveMirrorUrlPrefix,
        pgyerApiKey: settings.pgyerApiKey,
        pgyerAppKey: settings.pgyerAppKey,
      );
    });
  }

  Future<void> _updatePrereleasePreference(bool value) async {
    final provider = context.read<TimetableProvider>();
    final message = await provider.updateTimetableSettings(
      provider.settings.copyWith(
        appUpdateIncludePrerelease: value,
      ),
    );
    if (!mounted) {
      return;
    }
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }
    _analytics.logEventLater(
      name: 'update_prerelease_toggled',
      parameters: {'enabled': value},
    );
    _refreshUpdate();
  }

  Future<void> _updateLiveDiagnosticsPreference(bool value) async {
    final provider = context.read<TimetableProvider>();
    final message = await provider.updateTimetableSettings(
      provider.settings.copyWith(
        liveEnableLocalDiagnostics: value,
      ),
    );
    if (!mounted) {
      return;
    }
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value
            ? AppLocalizations.of(context)!.aboutLiveDiagnosticsEnabled
            : AppLocalizations.of(context)!.aboutLiveDiagnosticsDisabled),
      ),
    );
  }

  Future<void> _openLiveDiagnosticsViewer() async {
    final settings = context.read<TimetableProvider>().settings;
    final nativeRawLog =
        await MiuiLiveActivitiesService().readLiveDiagnosticsText();
    final rawLog = await AppLogService.instance.readMergedLogsText(
      nativeRawLog: nativeRawLog,
    );
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveDiagnosticsLogViewerScreen(
          title: AppLocalizations.of(context)!.aboutAppLogsTitle,
          rawLog: rawLog,
          isRecordingEnabled: settings.liveEnableLocalDiagnostics,
          onExport: _exportLiveDiagnostics,
          onClear: _clearLiveDiagnostics,
        ),
      ),
    );
  }

  Future<void> _exportLiveDiagnostics([String? _]) async {
    final nativeRawLog =
        await MiuiLiveActivitiesService().readLiveDiagnosticsText();
    final path = await AppLogService.instance.exportMergedLogsFile(
      nativeRawLog: nativeRawLog,
    );
    if (!mounted) {
      return;
    }
    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                AppLocalizations.of(context)!.aboutNoDiagnosticsExportYet)),
      );
      return;
    }

    await Share.shareXFiles(
      [XFile(path)],
      text: AppLocalizations.of(context)!.appLogsShareText,
      subject: AppLocalizations.of(context)!.appLogsShareSubject,
    );
  }

  Future<bool> _clearLiveDiagnostics() async {
    final clearedAppLogs = await AppLogService.instance.clearAppLogs();
    final clearedNativeLogs =
        await MiuiLiveActivitiesService().clearLiveDiagnostics();
    final cleared = clearedAppLogs || clearedNativeLogs;
    if (!mounted) {
      return cleared;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          cleared
              ? AppLocalizations.of(context)!.liveDiagnosticsCleared
              : AppLocalizations.of(context)!.liveDiagnosticsClearFailed,
        ),
      ),
    );
    return cleared;
  }

  Future<void> _updateDownloadSource(AppUpdateDownloadSource source) async {
    final provider = context.read<TimetableProvider>();
    final message = await provider.updateTimetableSettings(
      provider.settings.copyWith(
        appUpdateDownloadSource: source.value,
      ),
    );
    if (!mounted) {
      return;
    }
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } else {
      _analytics.logEventLater(
        name: 'update_source_changed',
        parameters: {
          'source': source.value,
        },
      );
    }
  }

  Future<void> _updateDownloadChannel(AppUpdateDownloadChannel channel) async {
    final provider = context.read<TimetableProvider>();
    final message = await provider.updateTimetableSettings(
      provider.settings.copyWith(
        appUpdateDownloadChannel: channel.value,
      ),
    );
    if (!mounted) {
      return;
    }
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } else {
      _analytics.logEventLater(
        name: 'update_channel_changed',
        parameters: {
          'channel': channel.value,
        },
      );
    }
  }

  Future<void> _updateMirrorPreset(AppUpdateMirrorPreset preset) async {
    final provider = context.read<TimetableProvider>();
    final message = await provider.updateTimetableSettings(
      provider.settings.copyWith(
        appUpdateMirrorPreset: preset.value,
      ),
    );
    if (!mounted) {
      return;
    }
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }
    _analytics.logEventLater(
      name: 'update_mirror_preset_changed',
      parameters: {
        'preset': preset.value,
      },
    );
  }

  _MirrorProbeState? _findMirrorProbeState(AppUpdateMirrorPreset preset) {
    for (final item in _mirrorProbeStates) {
      if (item.preset == preset) {
        return item;
      }
    }
    return null;
  }

  Future<void> _handleMirrorPresetTap(
    AppUpdateMirrorPreset preset,
    TimetableSettings settings,
  ) async {
    if (preset.usesCustomUrl &&
        settings.appUpdateMirrorUrlPrefix.trim().isEmpty) {
      await _editMirrorUrlPrefix();
      return;
    }
    await _updateMirrorPreset(preset);
  }

  List<MapEntry<AppUpdateMirrorPreset, String>> _buildMirrorPresetCandidates(
    String customMirrorUrlPrefix,
  ) {
    final candidates = <MapEntry<AppUpdateMirrorPreset, String>>[
      MapEntry(
        AppUpdateMirrorPreset.ghfast,
        resolveAppUpdateMirrorUrlPrefix(
          preset: AppUpdateMirrorPreset.ghfast,
          customUrlPrefix: customMirrorUrlPrefix,
        ),
      ),
      MapEntry(
        AppUpdateMirrorPreset.ghproxyCn,
        resolveAppUpdateMirrorUrlPrefix(
          preset: AppUpdateMirrorPreset.ghproxyCn,
          customUrlPrefix: customMirrorUrlPrefix,
        ),
      ),
      MapEntry(
        AppUpdateMirrorPreset.ghLlkk,
        resolveAppUpdateMirrorUrlPrefix(
          preset: AppUpdateMirrorPreset.ghLlkk,
          customUrlPrefix: customMirrorUrlPrefix,
        ),
      ),
    ];
    final normalizedCustomPrefix =
        _normalizeMirrorUrlPrefix(customMirrorUrlPrefix);
    if (normalizedCustomPrefix != null) {
      candidates.add(
        MapEntry(AppUpdateMirrorPreset.custom, normalizedCustomPrefix),
      );
    }
    return candidates;
  }

  Future<List<_MirrorProbeState>> _probeMirrorCandidates(
    String originalDownloadUrl, {
    required String customMirrorUrlPrefix,
  }) async {
    final candidates = _buildMirrorPresetCandidates(customMirrorUrlPrefix);
    return Future.wait(
      candidates.map((candidate) async {
        final probeUrl = _updateService.buildDownloadUrl(
          originalUrl: originalDownloadUrl,
          source: AppUpdateDownloadSource.mirror,
          mirrorUrlPrefix: candidate.value,
        );
        final probeResult = await _updateService.probeDownloadUrl(probeUrl);
        return _MirrorProbeState(
          preset: candidate.key,
          prefix: candidate.value,
          result: probeResult,
        );
      }),
    );
  }

  Future<void> _probeAndRecommendMirrors(
    String originalDownloadUrl, {
    required String customMirrorUrlPrefix,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    if (_buildMirrorPresetCandidates(customMirrorUrlPrefix).isEmpty) {
      return;
    }

    _analytics.logEventLater(name: 'update_mirror_probe_started');
    setState(() {
      _isProbingMirrors = true;
      _mirrorProbeStates = const [];
    });

    final nextStates = await _probeMirrorCandidates(
      originalDownloadUrl,
      customMirrorUrlPrefix: customMirrorUrlPrefix,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isProbingMirrors = false;
      _mirrorProbeStates = nextStates;
    });

    final recommendedPreset = resolveRecommendedMirrorPreset({
      for (final item in nextStates) item.preset: item.result,
    });
    if (recommendedPreset == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.aboutProbeNoMirrorFound)),
      );
      return;
    }

    final currentPreset = AppUpdateMirrorPresetX.fromValue(
      context.read<TimetableProvider>().settings.appUpdateMirrorPreset,
    );
    _analytics.logEventLater(
      name: 'update_mirror_probe_completed',
      parameters: {
        'recommended': recommendedPreset.value,
      },
    );
    if (recommendedPreset == currentPreset) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(l10n.aboutProbeCurrentFastest(currentPreset.label))),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.aboutProbeRecommendSwitch(recommendedPreset.label)),
        action: SnackBarAction(
          label: l10n.switchAction,
          onPressed: () {
            _updateMirrorPreset(recommendedPreset);
          },
        ),
      ),
    );
  }

  void _showDownloadFailureSnackBar(String error) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.read<TimetableProvider>().settings;
    final source = AppUpdateDownloadSourceX.fromValue(
      settings.appUpdateDownloadSource,
    );

    if (source == AppUpdateDownloadSource.original) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.aboutSwitchToMirrorAfterError(error)),
          action: SnackBarAction(
            label: l10n.switchAction,
            onPressed: () {
              _updateDownloadSource(AppUpdateDownloadSource.mirror);
            },
          ),
        ),
      );
      return;
    }

    final currentPreset = AppUpdateMirrorPresetX.fromValue(
      settings.appUpdateMirrorPreset,
    );
    final availablePresets = _buildMirrorPresetCandidates(
      settings.appUpdateMirrorUrlPrefix,
    ).map((item) => item.key).toList();
    final recommendedPreset = resolveRecommendedMirrorPreset({
      for (final item in _mirrorProbeStates) item.preset: item.result,
    });
    final fallbackPreset =
        recommendedPreset != null && recommendedPreset != currentPreset
            ? recommendedPreset
            : resolveMirrorFallbackPreset(
                currentPreset: currentPreset,
                availablePresets: availablePresets,
              );

    if (fallbackPreset != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              l10n.aboutSwitchPresetAfterError(error, fallbackPreset.label)),
          action: SnackBarAction(
            label: l10n.switchAction,
            onPressed: () {
              _updateMirrorPreset(fallbackPreset);
            },
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error)),
    );
  }

  Future<void> _editMirrorUrlPrefix() async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<TimetableProvider>();
    final controller = TextEditingController(
      text: provider.settings.appUpdateMirrorUrlPrefix,
    );
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.aboutSetMirrorSourceTitle),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: l10n.aboutMirrorPrefixLabel,
              hintText: 'https://ghfast.top/',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(AppLocalizations.of(dialogContext)!.cancelAction),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(controller.text.trim());
              },
              child: Text(AppLocalizations.of(dialogContext)!.saveAction),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (result == null || !mounted) {
      return;
    }

    final normalizedPrefix = _normalizeMirrorUrlPrefix(result);
    if (normalizedPrefix == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.aboutMirrorPrefixInvalid)),
      );
      return;
    }

    final message = await provider.updateTimetableSettings(
      provider.settings.copyWith(
        appUpdateMirrorPreset: AppUpdateMirrorPreset.custom.value,
        appUpdateMirrorUrlPrefix: normalizedPrefix,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _mirrorProbeStates = const [];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message ?? l10n.aboutMirrorSaved)),
    );
    _analytics.logEventLater(name: 'update_mirror_saved');
  }

  Future<void> _downloadAndInstall(String url) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = AppUpdateDownloadController();
    _analytics.logEventLater(name: 'update_download_started');
    setState(() {
      _isDownloading = true;
      _isCancellingDownload = false;
      _downloadedBytes = 0;
      _downloadTotalBytes = null;
      _downloadController = controller;
    });

    final error = await _updateService.downloadAndInstallUpdate(
      url,
      (downloadedBytes, totalBytes) {
        if (mounted) {
          setState(() {
            _downloadedBytes = downloadedBytes;
            _downloadTotalBytes = totalBytes;
          });
        }
      },
      controller,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isDownloading = false;
      _isCancellingDownload = false;
      _downloadController = null;
    });

    if (error != null) {
      if (error == AppUpdateService.downloadCancelledMessage) {
        _analytics.logEventLater(name: 'update_download_cancelled');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.aboutDownloadCancelled)),
        );
        return;
      }
      _analytics.logEventLater(name: 'update_download_failed');
      _showDownloadFailureSnackBar(error);
      return;
    }

    _analytics.logEventLater(name: 'update_download_completed');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.aboutInstallReady),
      ),
    );
  }

  void _cancelDownload() {
    if (!_isDownloading || _isCancellingDownload) {
      return;
    }
    _analytics.logEventLater(name: 'update_download_cancel_requested');
    _downloadController?.cancel();
    setState(() {
      _isCancellingDownload = true;
    });
  }

  Future<void> _enqueueSystemDownload({
    required String url,
    String? version,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final normalizedVersion = (version ?? '').trim().replaceAll(' ', '_');
      final fileName = normalizedVersion.isEmpty
          ? 'mikcb_update.apk'
          : 'mikcb_v$normalizedVersion.apk';
      final downloadId = await _supportService.enqueueSystemDownload(
        url: url,
        fileName: fileName,
        title: l10n.aboutUpdatePackageTitle,
        description: l10n.aboutUpdatePackageDescription,
      );
      if (!mounted) {
        return;
      }
      _analytics.logEventLater(
        name: 'update_system_download_enqueued',
        parameters: {
          'has_download_id': downloadId != null,
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.aboutSystemDownloaderQueued),
        ),
      );
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      _analytics.logEventLater(name: 'update_system_download_failed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message?.trim().isNotEmpty == true
                ? error.message!
                : l10n.aboutSystemDownloaderFailed,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _analytics.logEventLater(name: 'update_system_download_failed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.aboutSystemDownloaderFailed)),
      );
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final year = dateTime.year.toString();
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  String? _normalizeMirrorUrlPrefix(String input) {
    final value = input.trim();
    if (value.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return null;
    }

    final base = value.endsWith('/') ? value : '$value/';
    return base;
  }

  Widget _buildDownloadProgressBar(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = theme.colorScheme;
    final totalBytes = _downloadTotalBytes;
    final progress = totalBytes == null || totalBytes <= 0
        ? null
        : _downloadedBytes / totalBytes;
    final progressText = _isCancellingDownload
        ? l10n.aboutDownloadCancelling
        : progress == null
            ? l10n.aboutDownloadingBytes(_formatBytes(_downloadedBytes))
            : l10n.aboutDownloadingPercent((progress * 100).toStringAsFixed(1));
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              progressText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (progress == null && _downloadedBytes > 0) ...[
              const SizedBox(height: 4),
              Text(
                l10n.aboutMirrorUnknownSizeHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _isCancellingDownload ? null : _cancelDownload,
                icon: const Icon(Icons.close_rounded),
                label: Text(_isCancellingDownload
                    ? l10n.aboutDownloadCancelling
                    : l10n.aboutCancelDownloadAction),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _UpdateCheckAnimation extends StatefulWidget {
  final ColorScheme colorScheme;

  const _UpdateCheckAnimation({required this.colorScheme});

  @override
  State<_UpdateCheckAnimation> createState() => _UpdateCheckAnimationState();
}

class _UpdateCheckAnimationState extends State<_UpdateCheckAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final AnimationController _pulseController;
  late final AnimationController _arcController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _arcController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _arcController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.colorScheme;
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 外圈脉冲效果
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primary.withValues(alpha: 0.08),
                  ),
                ),
              );
            },
          ),
          // 旋转的弧形
          AnimatedBuilder(
            animation: _arcController,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(64, 64),
                painter: _ArcPainter(
                  color: colorScheme.primary,
                  animationValue: _arcController.value,
                ),
              );
            },
          ),
          // 中心图标
          AnimatedBuilder(
            animation: _rotationController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotationController.value * 2 * 3.14159,
                child: Icon(
                  Icons.sync_rounded,
                  size: 28,
                  color: colorScheme.primary,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final Color color;
  final double animationValue;

  _ArcPainter({required this.color, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final startAngle = animationValue * 2 * 3.14159;
    const sweepAngle = 3.14159 * 0.8; // 约 144 度的弧

    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);

    // 第二条较短的弧
    final paint2 = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      startAngle + 3.14159,
      sweepAngle * 0.6,
      false,
      paint2,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class _SegmentedTabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color selectedColor;
  final Color selectedTextColor;
  final Color unselectedTextColor;

  const _SegmentedTabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.selectedColor,
    required this.selectedTextColor,
    required this.unselectedTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: selectedColor.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? selectedTextColor : unselectedTextColor,
          ),
        ),
      ),
    );
  }
}

class _AdvancedOptionsScreen extends StatefulWidget {
  final ThemeData theme;
  final TimetableSettings settings;
  final PackageInfo? packageInfo;
  final AppUpdateService updateService;
  final AppAnalytics analytics;
  final Future<AppUpdateCheckResult>? updateFuture;
  final List<_MirrorProbeState> mirrorProbeStates;
  final bool isDownloading;
  final bool useSystemDownloader;
  final ValueChanged<bool> onUseSystemDownloaderChanged;

  const _AdvancedOptionsScreen({
    required this.theme,
    required this.settings,
    required this.packageInfo,
    required this.updateService,
    required this.analytics,
    required this.updateFuture,
    required this.mirrorProbeStates,
    required this.isDownloading,
    required this.useSystemDownloader,
    required this.onUseSystemDownloaderChanged,
  });

  @override
  State<_AdvancedOptionsScreen> createState() => _AdvancedOptionsScreenState();
}

class _AdvancedOptionsScreenState extends State<_AdvancedOptionsScreen> {
  bool _isProbingMirrors = false;
  List<_MirrorProbeState> _mirrorProbeStates = const [];
  late bool _useSystemDownloader;

  @override
  void initState() {
    super.initState();
    _mirrorProbeStates = widget.mirrorProbeStates;
    _useSystemDownloader = widget.useSystemDownloader;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = widget.theme;
    final settings = context.select<TimetableProvider, TimetableSettings>((p) => p.settings);
    final colorScheme = theme.colorScheme;
    final downloadChannel = AppUpdateDownloadChannelX.fromValue(
      settings.appUpdateDownloadChannel,
    );
    final downloadSource = AppUpdateDownloadSourceX.fromValue(
      settings.appUpdateDownloadSource,
    );
    final mirrorPreset = AppUpdateMirrorPresetX.fromValue(
      settings.appUpdateMirrorPreset,
    );
    final probeResultByPreset = {
      for (final item in _mirrorProbeStates) item.preset: item.result,
    };
    final recommendedMirrorPreset =
        resolveRecommendedMirrorPreset(probeResultByPreset);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aboutAdvancedOptionsTitle),
      ),
      body: FutureBuilder<AppUpdateCheckResult>(
        future: widget.updateFuture,
        builder: (context, snapshot) {
          final result = snapshot.data;
          final release = result?.latestRelease;
          final originalDownloadUrl = release?.downloadUrl;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              // 下载设置卡片
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 下载渠道切换
                      Text(
                        '下载渠道',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '蒲公英国内高速下载，GitHub 支持镜像加速',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildDownloadChannelTab(theme, settings),
                      const SizedBox(height: 16),
                      // 下载方式切换
                      Text(
                        '下载安装包方式',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '选择应用内直接下载或系统下载管理器',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildDownloadMethodTab(theme),
                      // 检测测试版本
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.aboutCheckPrereleaseTitle,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.aboutCheckPrereleaseSubtitle,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildToggle(
                              theme,
                              value: settings.appUpdateIncludePrerelease,
                              onChanged: widget.packageInfo == null
                                  ? null
                                  : (value) => _updatePrereleasePreference(value),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 镜像设置卡片（仅 GitHub 渠道）
              if (downloadChannel == AppUpdateDownloadChannel.github &&
                  downloadSource == AppUpdateDownloadSource.mirror)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.aboutMirrorSectionTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...AppUpdateMirrorPreset.values.map(
                          (preset) => _buildMirrorRadioTile(
                            theme,
                            preset: preset,
                            currentPreset: mirrorPreset,
                            recommendedPreset: recommendedMirrorPreset,
                            onTap: () => _handleMirrorPresetTap(preset, settings),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.tonalIcon(
                                onPressed: originalDownloadUrl == null ||
                                        _isProbingMirrors
                                    ? null
                                    : () => _probeAndRecommendMirrors(
                                          originalDownloadUrl,
                                          customMirrorUrlPrefix:
                                              settings.appUpdateMirrorUrlPrefix,
                                        ),
                                icon: Icon(
                                  _isProbingMirrors
                                      ? Icons.hourglass_top_rounded
                                      : Icons.speed_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  _isProbingMirrors
                                      ? l10n.aboutProbingMirrors
                                      : l10n.aboutProbeMirrorsAction,
                                ),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.tonalIcon(
                                onPressed: _editMirrorUrlPrefix,
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                label: Text(
                                  mirrorPreset.usesCustomUrl
                                      ? l10n.aboutEditCustomMirrorAction
                                      : l10n.aboutSetCustomMirrorAction,
                                ),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (downloadChannel == AppUpdateDownloadChannel.github &&
                  downloadSource == AppUpdateDownloadSource.mirror)
                const SizedBox(height: 16),
              // 诊断设置卡片
              _buildDiagnosticsCard(theme, settings),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDownloadChannelTab(ThemeData theme, TimetableSettings settings) {
    final colorScheme = theme.colorScheme;
    final downloadChannel = AppUpdateDownloadChannelX.fromValue(
      settings.appUpdateDownloadChannel,
    );
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _SegmentedTabButton(
              label: '蒲公英下载',
              isSelected: downloadChannel == AppUpdateDownloadChannel.pgyer,
              onTap: () => _updateDownloadChannel(AppUpdateDownloadChannel.pgyer),
              selectedColor: colorScheme.primary,
              selectedTextColor: colorScheme.onPrimary,
              unselectedTextColor: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _SegmentedTabButton(
              label: 'GitHub 下载',
              isSelected: downloadChannel == AppUpdateDownloadChannel.github,
              onTap: () => _updateDownloadChannel(AppUpdateDownloadChannel.github),
              selectedColor: colorScheme.primary,
              selectedTextColor: colorScheme.onPrimary,
              unselectedTextColor: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadMethodTab(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _SegmentedTabButton(
              label: '应用内下载',
              isSelected: !_useSystemDownloader,
              onTap: () {
                setState(() => _useSystemDownloader = false);
                widget.onUseSystemDownloaderChanged(false);
              },
              selectedColor: colorScheme.primary,
              selectedTextColor: colorScheme.onPrimary,
              unselectedTextColor: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _SegmentedTabButton(
              label: '系统管理器',
              isSelected: _useSystemDownloader,
              onTap: () {
                setState(() => _useSystemDownloader = true);
                widget.onUseSystemDownloaderChanged(true);
              },
              selectedColor: colorScheme.primary,
              selectedTextColor: colorScheme.onPrimary,
              unselectedTextColor: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(
    ThemeData theme, {
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final colorScheme = theme.colorScheme;
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 28,
        decoration: BoxDecoration(
          color: onChanged == null
              ? colorScheme.surfaceContainerHighest
              : value
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              left: value ? 22 : 2,
              top: 2,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: onChanged == null
                      ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
                      : value
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMirrorRadioTile(
    ThemeData theme, {
    required AppUpdateMirrorPreset preset,
    required AppUpdateMirrorPreset currentPreset,
    required AppUpdateMirrorPreset? recommendedPreset,
    required VoidCallback onTap,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = theme.colorScheme;
    final probeState = _mirrorProbeStates.where((s) => s.preset == preset).firstOrNull;
    final isSelected = currentPreset == preset;
    final isRecommended =
        recommendedPreset == preset && probeState?.result.isSuccess == true;
    final settings = context.read<TimetableProvider>().settings;
    final subtitleText = preset.usesCustomUrl &&
            settings.appUpdateMirrorUrlPrefix.trim().isEmpty
        ? l10n.aboutFillCustomMirrorFirst
        : (preset.usesCustomUrl
            ? resolveAppUpdateMirrorUrlPrefix(
                preset: preset,
                customUrlPrefix: settings.appUpdateMirrorUrlPrefix,
              )
            : preset.description);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outline,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorScheme.primary,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              preset.label,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isRecommended) ...[
                            const SizedBox(width: 6),
                            _MirrorBadge(
                              label: l10n.aboutRecommended,
                              backgroundColor: colorScheme.primaryContainer,
                              foregroundColor: colorScheme.onPrimaryContainer,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitleText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (probeState != null) ...[
                  const SizedBox(width: 8),
                  _buildMirrorProbeStatusChip(theme, probeState.result),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMirrorProbeStatusChip(
    ThemeData theme,
    AppUpdateDownloadProbeResult result,
  ) {
    final colorScheme = theme.colorScheme;
    final (label, background, foreground) = switch (result) {
      AppUpdateDownloadProbeResult(isSuccess: true, :final elapsed) =>
        (
          '${elapsed.inMilliseconds}ms',
          Colors.green.withValues(alpha: 0.12),
          Colors.green,
        ),
      AppUpdateDownloadProbeResult(isSuccess: false) =>
        (
          '失败',
          colorScheme.errorContainer,
          colorScheme.onErrorContainer,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }

  Widget _buildDiagnosticsCard(
    ThemeData theme,
    TimetableSettings settings,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.aboutDiagnosticsTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              l10n.aboutDiagnosticsSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.aboutRecordDiagnosticsTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.aboutRecordDiagnosticsSubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildToggle(
                    theme,
                    value: settings.liveEnableLocalDiagnostics,
                    onChanged: widget.packageInfo == null
                        ? null
                        : (value) => _updateLiveDiagnosticsPreference(value),
                  ),
                ],
              ),
            ),
            if (settings.liveEnableLocalDiagnostics) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _exportLiveDiagnostics,
                    icon: const Icon(Icons.ios_share_rounded),
                    label: Text(l10n.aboutExportDiagnosticsAction),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _openLiveDiagnosticsViewer,
                    icon: const Icon(Icons.article_outlined),
                    label: Text(l10n.aboutViewPhoneLogsAction),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _clearLiveDiagnostics,
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: Text(l10n.aboutClearAndRecollectAction),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _updateDownloadChannel(AppUpdateDownloadChannel channel) async {
    final provider = context.read<TimetableProvider>();
    final message = await provider.updateTimetableSettings(
      provider.settings.copyWith(
        appUpdateDownloadChannel: channel.value,
      ),
    );
    if (!mounted) return;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _updatePrereleasePreference(bool value) async {
    final provider = context.read<TimetableProvider>();
    final message = await provider.updateTimetableSettings(
      provider.settings.copyWith(
        appUpdateIncludePrerelease: value,
      ),
    );
    if (!mounted) return;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _updateLiveDiagnosticsPreference(bool value) async {
    final provider = context.read<TimetableProvider>();
    final message = await provider.updateTimetableSettings(
      provider.settings.copyWith(
        liveEnableLocalDiagnostics: value,
      ),
    );
    if (!mounted) return;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _handleMirrorPresetTap(
    AppUpdateMirrorPreset preset,
    TimetableSettings settings,
  ) async {
    final provider = context.read<TimetableProvider>();
    final message = await provider.updateTimetableSettings(
      provider.settings.copyWith(
        appUpdateMirrorPreset: preset.value,
      ),
    );
    if (!mounted) return;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _probeAndRecommendMirrors(
    String originalDownloadUrl, {
    String? customMirrorUrlPrefix,
  }) async {
    setState(() => _isProbingMirrors = true);
    try {
      final candidates = <MapEntry<AppUpdateMirrorPreset, String>>[
        MapEntry(
          AppUpdateMirrorPreset.ghfast,
          resolveAppUpdateMirrorUrlPrefix(
            preset: AppUpdateMirrorPreset.ghfast,
            customUrlPrefix: customMirrorUrlPrefix ?? '',
          ),
        ),
        MapEntry(
          AppUpdateMirrorPreset.ghproxyCn,
          resolveAppUpdateMirrorUrlPrefix(
            preset: AppUpdateMirrorPreset.ghproxyCn,
            customUrlPrefix: customMirrorUrlPrefix ?? '',
          ),
        ),
        MapEntry(
          AppUpdateMirrorPreset.ghLlkk,
          resolveAppUpdateMirrorUrlPrefix(
            preset: AppUpdateMirrorPreset.ghLlkk,
            customUrlPrefix: customMirrorUrlPrefix ?? '',
          ),
        ),
      ];

      final results = await Future.wait(
        candidates.map((candidate) async {
          final probeUrl = widget.updateService.buildDownloadUrl(
            originalUrl: originalDownloadUrl,
            source: AppUpdateDownloadSource.mirror,
            mirrorUrlPrefix: candidate.value,
          );
          final probeResult = await widget.updateService.probeDownloadUrl(probeUrl);
          return _MirrorProbeState(
            preset: candidate.key,
            prefix: candidate.value,
            result: probeResult,
          );
        }),
      );

      if (!mounted) return;
      setState(() => _mirrorProbeStates = results);
      final recommended = resolveRecommendedMirrorPreset({
        for (final item in results) item.preset: item.result,
      });
      if (recommended != null) {
        final provider = context.read<TimetableProvider>();
        await provider.updateTimetableSettings(
          provider.settings.copyWith(
            appUpdateMirrorPreset: recommended.value,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProbingMirrors = false);
    }
  }

  Future<void> _editMirrorUrlPrefix() async {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.read<TimetableProvider>().settings;
    final controller =
        TextEditingController(text: settings.appUpdateMirrorUrlPrefix);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.aboutSetMirrorSourceTitle),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: l10n.aboutMirrorPrefixLabel,
            hintText: 'https://ghfast.top/',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(AppLocalizations.of(context)!.saveAction),
          ),
        ],
      ),
    );
    if (result == null) return;
    final provider = context.read<TimetableProvider>();
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        appUpdateMirrorUrlPrefix: result,
      ),
    );
  }

  Future<void> _exportLiveDiagnostics() async {
    // TODO: 实现导出诊断
  }

  Future<void> _openLiveDiagnosticsViewer() async {
    // TODO: 实现查看日志
  }

  Future<void> _clearLiveDiagnostics() async {
    // TODO: 实现清除诊断
  }
}

class _MirrorBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  const _MirrorBadge({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: foregroundColor,
        ),
      ),
    );
  }
}

class ReleaseNotesMarkdown extends StatelessWidget {
  final String data;
  final ValueChanged<String?>? onTapLink;

  const ReleaseNotesMarkdown({
    super.key,
    required this.data,
    this.onTapLink,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MarkdownBody(
      data: data,
      selectable: true,
      styleSheet: MarkdownStyleSheet.fromTheme(theme),
      onTapLink: (text, href, title) => onTapLink?.call(href),
    );
  }
}

class ContributorsScreen extends StatefulWidget {
  const ContributorsScreen({super.key});

  @override
  State<ContributorsScreen> createState() => _ContributorsScreenState();
}

class _ContributorsScreenState extends State<ContributorsScreen> {
  static final WarehouseRepositorySource _warehouseSource =
      WarehouseRepositorySource.fromGitHubUrl(
    'https://github.com/Mutx163/qingyu_warehouse',
  );
  static const String _maintainersCacheKey = 'warehouse_maintainers_cache_v1';

  final WarehouseRepositoryService _repositoryService =
      WarehouseRepositoryService();
  List<_WarehouseMaintainerGroup> _maintainers = const [];
  bool _isLoadingMaintainers = true;
  String? _maintainersError;

  @override
  void initState() {
    super.initState();
    _loadMaintainers();
  }

  Future<List<_WarehouseMaintainerGroup>>
      _fetchMaintainersFromWarehouse() async {
    final settings = context.read<TimetableProvider>().settings;
    final options = WarehouseFetchOptions.fromSettings(settings);
    final rootIndex = await _repositoryService.fetchRootIndex(
      _warehouseSource,
      options: options,
    );
    final groups = <String, List<String>>{};

    final futures = rootIndex.schools.map((school) async {
      try {
        final adapters = await _repositoryService.fetchAdaptersIndex(
          _warehouseSource,
          school,
          options: options,
        );
        return adapters.adapters
            .where((adapter) => adapter.maintainer.trim().isNotEmpty)
            .map(
              (adapter) => (
                adapter.maintainer.trim(),
                '${school.name} · ${adapter.adapterName}',
              ),
            )
            .toList(growable: false);
      } catch (_) {
        return const <(String, String)>[];
      }
    }).toList(growable: false);

    final results = await Future.wait(futures);
    for (final entries in results) {
      for (final (maintainer, label) in entries) {
        groups.putIfAbsent(maintainer, () => <String>[]);
        groups[maintainer]!.add(label);
      }
    }

    final result = groups.entries
        .map(
          (entry) => _WarehouseMaintainerGroup(
            name: entry.key,
            adapterLabels: [...entry.value]..sort(),
          ),
        )
        .toList(growable: false)
      ..sort((left, right) => left.name.compareTo(right.name));
    return result;
  }

  Future<void> _loadMaintainers() async {
    final cached = await _readMaintainersCache();
    if (!mounted) return;
    if (cached.isNotEmpty) {
      setState(() {
        _maintainers = cached;
        _isLoadingMaintainers = true;
        _maintainersError = null;
      });
    }
    try {
      final fresh = await _fetchMaintainersFromWarehouse();
      if (!mounted) return;
      setState(() {
        _maintainers = fresh;
        _isLoadingMaintainers = false;
        _maintainersError = null;
      });
      await _writeMaintainersCache(fresh);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingMaintainers = false;
        _maintainersError = '$error';
      });
    }
  }

  Future<List<_WarehouseMaintainerGroup>> _readMaintainersCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_maintainersCacheKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }
      return decoded
          .whereType<Map>()
          .map(
            (item) => _WarehouseMaintainerGroup(
              name: item['name'] as String? ?? '',
              adapterLabels:
                  (item['adapterLabels'] as List<dynamic>? ?? const [])
                      .whereType<String>()
                      .toList(),
            ),
          )
          .where((item) => item.name.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _writeMaintainersCache(
    List<_WarehouseMaintainerGroup> groups,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _maintainersCacheKey,
      jsonEncode(
        groups
            .map(
              (group) => {
                'name': group.name,
                'adapterLabels': group.adapterLabels,
              },
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aboutContributorsScreenTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.aboutDevelopersTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ContributorRow(
                    name: 'Mutx163',
                    subtitle: l10n.aboutDeveloperMaintainerSubtitle,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.aboutWarehouseMaintainersTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (_isLoadingMaintainers)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.aboutWarehouseMaintainersIntro,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_maintainersError != null && _maintainers.isEmpty)
                    Text(
                      l10n.aboutWarehouseMaintainersLoadFailed(
                          _maintainersError!),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.error,
                      ),
                    )
                  else if (_maintainers.isEmpty)
                    Text(
                      l10n.aboutWarehouseMaintainersEmpty,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    ..._maintainers.map(
                      (group) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ContributorRow(
                          name: group.name,
                          subtitle: l10n.aboutWarehouseMaintainerCount(
                              group.adapterLabels.length),
                          details: group.adapterLabels,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.aboutParticipateWarehouseTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.aboutParticipateWarehouseSubtitle,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _openWarehouseRepository,
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: Text(l10n.aboutOpenWarehouseRepoAction),
                      ),
                      OutlinedButton.icon(
                        onPressed: _copyWarehouseRepositoryUrl,
                        icon: const Icon(Icons.copy_all_rounded),
                        label: Text(l10n.copyAddress),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openWarehouseRepository() async {
    final uri = Uri.tryParse(_warehouseSource.repositoryUrl);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _copyWarehouseRepositoryUrl() async {
    await Clipboard.setData(
      ClipboardData(text: _warehouseSource.repositoryUrl),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              AppLocalizations.of(context)!.copiedWarehouseRepositoryAddress)),
    );
  }
}

class _WarehouseMaintainerGroup {
  final String name;
  final List<String> adapterLabels;

  const _WarehouseMaintainerGroup({
    required this.name,
    required this.adapterLabels,
  });
}

class _ContributorRow extends StatelessWidget {
  final String name;
  final String subtitle;
  final List<String> details;

  const _ContributorRow({
    required this.name,
    required this.subtitle,
    this.details = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...details.map(
              (detail) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $detail',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AboutNavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AboutNavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _AboutBullet extends StatelessWidget {
  final String text;

  const _AboutBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

