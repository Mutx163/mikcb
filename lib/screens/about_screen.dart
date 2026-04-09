import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
  openDownloadLink,
  downloadInApp,
}

@visibleForTesting
AboutUpdatePrimaryAction resolveAboutUpdatePrimaryAction({
  required bool isAndroid,
  required String? downloadUrl,
}) {
  final hasDownloadUrl = (downloadUrl ?? '').trim().isNotEmpty;
  if (!hasDownloadUrl) {
    return AboutUpdatePrimaryAction.openReleasePage;
  }
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
      ),
      bottomNavigationBar:
          _isDownloading ? _buildDownloadProgressBar(theme) : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildUpdateCard(theme, settings),
          const SizedBox(height: 16),
          _buildAdvancedOptionsCard(theme, settings),
          const SizedBox(height: 16),
          _buildDiagnosticsCard(theme, settings),
        ],
      ),
    );
  }

  Widget _buildUpdateCard(ThemeData theme, TimetableSettings settings) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = theme.colorScheme;
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
    final probeResultByPreset = {
      for (final item in _mirrorProbeStates) item.preset: item.result,
    };
    final recommendedMirrorPreset =
        resolveRecommendedMirrorPreset(probeResultByPreset);
    return FutureBuilder<AppUpdateCheckResult>(
      future: _updateFuture,
      builder: (context, snapshot) {
        if (widget.packageInfo == null ||
            snapshot.connectionState == ConnectionState.waiting) {
          return _buildUpdateSectionCard(
            theme,
            title: l10n.aboutUpdateStatusTitle,
            trailing: IconButton(
              tooltip: l10n.aboutRefreshCheckTooltip,
              onPressed: widget.packageInfo == null ? null : _refreshUpdate,
              icon: const Icon(Icons.refresh_rounded),
            ),
            subtitle: l10n.aboutCheckingLatestVersion,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          );
        }

        final result = snapshot.data;
        if (result == null) {
          return _buildUpdateSectionCard(
            theme,
            title: l10n.aboutUpdateStatusTitle,
            trailing: IconButton(
              tooltip: l10n.aboutRefreshCheckTooltip,
              onPressed: widget.packageInfo == null ? null : _refreshUpdate,
              icon: const Icon(Icons.refresh_rounded),
            ),
            subtitle: l10n.aboutReadVersionFailed,
            child: Text(
              l10n.aboutReadVersionFailedHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        final release = result.latestRelease;
        final updateColor = result.hasUpdate
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant;
        final originalDownloadUrl = release?.downloadUrl;
        final effectiveDownloadUrl = originalDownloadUrl == null
            ? null
            : _updateService.buildDownloadUrl(
                originalUrl: originalDownloadUrl,
                source: downloadSource,
                mirrorUrlPrefix: effectiveMirrorUrlPrefix,
              );
        final isAndroid = defaultTargetPlatform == TargetPlatform.android;
        final primaryAction = resolveAboutUpdatePrimaryAction(
          isAndroid: isAndroid,
          downloadUrl: effectiveDownloadUrl,
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
          AboutUpdatePrimaryAction.openReleasePage =>
            Icons.open_in_new_rounded,
        };

        return Column(
          children: [
            _buildUpdateSectionCard(
              theme,
              title: l10n.aboutUpdateStatusTitle,
              trailing: IconButton(
                tooltip: l10n.aboutRefreshCheckTooltip,
                onPressed: widget.packageInfo == null ? null : _refreshUpdate,
                icon: const Icon(Icons.refresh_rounded),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: updateColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      result.message ?? '',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: updateColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildUpdateInfoChip(
                        theme,
                        label: l10n.aboutCurrentVersionLabel,
                        value: result.currentVersion,
                      ),
                      _buildUpdateInfoChip(
                        theme,
                        label: l10n.aboutLatestVersionLabel,
                        value: release?.version ?? l10n.aboutUnreleasedLabel,
                      ),
                      if (release?.isPrerelease == true)
                        _buildUpdateInfoChip(
                          theme,
                          label: l10n.aboutVersionChannelLabel,
                          value: l10n.aboutPrereleaseChannel,
                        ),
                    ],
                  ),
                  if (release != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      result.hasUpdate
                          ? l10n.aboutUpdateAvailableHint
                          : l10n.aboutUpdateNoUpdateHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (release?.updatedAt != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      l10n.aboutUpdatedAt(_formatDateTime(release!.updatedAt!)),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildUpdateSectionCard(
              theme,
              title: l10n.aboutUpdateNowTitle,
              subtitle: isAndroid
                  ? l10n.aboutUpdateNowAndroidSubtitle
                  : l10n.aboutUpdateNowOtherSubtitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      downloadSource == AppUpdateDownloadSource.mirror
                          ? l10n.aboutMirrorDownloadHint
                          : l10n.aboutOriginalDownloadHint,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: result.hasRelease
                        ? (primaryAction ==
                                    AboutUpdatePrimaryAction.downloadInApp &&
                                _isDownloading
                            ? null
                            : () => _handlePrimaryUpdateAction(
                                  primaryAction: primaryAction,
                                  effectiveDownloadUrl: effectiveDownloadUrl,
                                  releaseUrl: release?.releaseUrl,
                                ))
                        : null,
                    icon: Icon(primaryButtonIcon),
                    label: Text(primaryButtonLabel),
                  ),
                  if (result.hasRelease &&
                      isAndroid &&
                      effectiveDownloadUrl != null) ...[
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: _isDownloading
                          ? null
                          : () => _enqueueSystemDownload(
                                url: effectiveDownloadUrl,
                                version: release?.version,
                              ),
                      icon: const Icon(Icons.download_for_offline_rounded),
                      label: Text(l10n.aboutUseSystemDownloaderAction),
                    ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: result.hasRelease
                        ? () => _openUrl(release?.releaseUrl)
                        : null,
                    icon: const Icon(Icons.new_releases_outlined),
                    label: Text(l10n.aboutOpenReleasePageAction),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildUpdateSectionCard(
              theme,
              title: l10n.aboutDownloadMethodTitle,
              subtitle: l10n.aboutDownloadMethodSubtitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<AppUpdateDownloadSource>(
                    segments: [
                      ButtonSegment<AppUpdateDownloadSource>(
                        value: AppUpdateDownloadSource.mirror,
                        label: Text(l10n.aboutDownloadMethodMirror),
                      ),
                      ButtonSegment<AppUpdateDownloadSource>(
                        value: AppUpdateDownloadSource.original,
                        label: Text(l10n.aboutDownloadMethodOriginal),
                      ),
                    ],
                    selected: {downloadSource},
                    onSelectionChanged: (selection) {
                      final nextSource = selection.first;
                      _updateDownloadSource(nextSource);
                    },
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      downloadSource == AppUpdateDownloadSource.mirror
                          ? recommendedMirrorPreset != null &&
                                  recommendedMirrorPreset != mirrorPreset
                              ? l10n.aboutMirrorModeHintRecommended(
                                  mirrorPreset.label,
                                  recommendedMirrorPreset.label)
                              : l10n.aboutMirrorModeHintCurrent(
                                  mirrorPreset.label)
                          : l10n.aboutOriginalModeHint,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if ((release?.body ?? '').isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildUpdateSectionCard(
                theme,
                title: l10n.aboutReleaseNotesTitle,
                subtitle: l10n.aboutReleaseNotesSubtitle,
                child: ReleaseNotesMarkdown(
                  data: release!.body.trim(),
                  onTapLink: _openUrl,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildAdvancedOptionsCard(
    ThemeData theme,
    TimetableSettings settings,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = theme.colorScheme;
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
    final probeResultByPreset = {
      for (final item in _mirrorProbeStates) item.preset: item.result,
    };
    final recommendedMirrorPreset =
        resolveRecommendedMirrorPreset(probeResultByPreset);

    return FutureBuilder<AppUpdateCheckResult>(
      future: _updateFuture,
      builder: (context, snapshot) {
        final originalDownloadUrl = snapshot.data?.latestRelease?.downloadUrl;
        return Card(
          child: Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              title: Text(
                l10n.aboutAdvancedOptionsTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                l10n.aboutAdvancedOptionsSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.aboutMirrorSectionTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  downloadSource == AppUpdateDownloadSource.mirror
                      ? l10n.aboutMirrorSectionMirrorHint
                      : l10n.aboutMirrorSectionOriginalHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                if (downloadSource == AppUpdateDownloadSource.mirror) ...[
                  ...AppUpdateMirrorPreset.values.map((preset) {
                    final subtitleText = preset.usesCustomUrl &&
                            settings.appUpdateMirrorUrlPrefix.trim().isEmpty
                        ? l10n.aboutFillCustomMirrorFirst
                        : preset.description;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: mirrorPreset == preset
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        child: RadioListTile<AppUpdateMirrorPreset>(
                          value: preset,
                          groupValue: mirrorPreset,
                          title: Text(preset.label),
                          subtitle: Text(subtitleText),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            if (value.usesCustomUrl &&
                                settings.appUpdateMirrorUrlPrefix
                                    .trim()
                                    .isEmpty) {
                              _editMirrorUrlPrefix();
                              return;
                            }
                            _updateMirrorPreset(value);
                          },
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mirrorPreset.usesCustomUrl
                              ? l10n.aboutCurrentCustomMirrorTitle
                              : l10n.aboutCurrentMirrorTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          effectiveMirrorUrlPrefix,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          mirrorPreset.usesCustomUrl
                              ? l10n.aboutCurrentCustomMirrorHint
                              : l10n.aboutCurrentMirrorHint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed:
                            originalDownloadUrl == null || _isProbingMirrors
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
                        ),
                        label: Text(
                          _isProbingMirrors
                              ? l10n.aboutProbingMirrors
                              : l10n.aboutProbeMirrorsAction,
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _editMirrorUrlPrefix,
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(
                          mirrorPreset.usesCustomUrl
                              ? l10n.aboutEditCustomMirrorAction
                              : l10n.aboutSetCustomMirrorAction,
                        ),
                      ),
                      if (recommendedMirrorPreset != null &&
                          recommendedMirrorPreset != mirrorPreset)
                        FilledButton.tonalIcon(
                          onPressed: () => _updateMirrorPreset(
                            recommendedMirrorPreset,
                          ),
                          icon: const Icon(Icons.bolt_rounded),
                          label: Text(
                            l10n.aboutSwitchToRecommendedAction(
                                recommendedMirrorPreset.label),
                          ),
                        ),
                    ],
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      l10n.aboutMirrorDisabledHint,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                if (_mirrorProbeStates.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.aboutRecentProbeResultsTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._mirrorProbeStates.map((item) {
                    final isRecommended =
                        item.preset == recommendedMirrorPreset &&
                            item.result.isSuccess;
                    final statusText = item.result.isSuccess
                        ? '${item.result.elapsed.inMilliseconds} ms'
                        : (item.result.message ?? l10n.aboutUnavailable);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isRecommended
                                ? colorScheme.primary
                                : colorScheme.outlineVariant,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.preset.label,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.prefix,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  statusText,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: item.result.isSuccess
                                        ? colorScheme.primary
                                        : colorScheme.error,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (isRecommended)
                                  Text(
                                    l10n.aboutRecommended,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.primary,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: settings.appUpdateIncludePrerelease,
                  onChanged: widget.packageInfo == null
                      ? null
                      : (value) => _updatePrereleasePreference(value),
                  title: Text(l10n.aboutCheckPrereleaseTitle),
                  subtitle: Text(l10n.aboutCheckPrereleaseSubtitle),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDiagnosticsCard(
    ThemeData theme,
    TimetableSettings settings,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            l10n.aboutDiagnosticsTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            l10n.aboutDiagnosticsSubtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: settings.liveEnableLocalDiagnostics,
              onChanged: widget.packageInfo == null
                  ? null
                  : (value) => _updateLiveDiagnosticsPreference(value),
              title: Text(l10n.aboutRecordDiagnosticsTitle),
              subtitle: Text(l10n.aboutRecordDiagnosticsSubtitle),
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

  Widget _buildUpdateInfoChip(
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

  Widget _buildUpdateSectionCard(
    ThemeData theme, {
    required String title,
    String? subtitle,
    Widget? trailing,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
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
