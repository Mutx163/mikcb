// ignore_for_file: unused_element, unused_field

import 'dart:convert';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
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
import 'changelog_screen.dart';
import '../services/app_update_service.dart';
import '../services/miui_live_activities_service.dart';
import '../services/support_creator_service.dart';
import '../services/bundled_assets.dart';
import '../widgets/about_info_sheet.dart';
import '../widgets/bundled_asset_image.dart';
import '../utils/app_toast.dart';
import '../widgets/app_dialogs.dart';
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
  final successfulEntries =
      probeResults.entries.where((entry) => entry.value.isSuccess).toList()
        ..sort(
          (left, right) => left.value.elapsed.compareTo(right.value.elapsed),
        );
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
  bool _openingAppLogs = false;

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
    final colorScheme = Theme.of(context).colorScheme;
    final settings = context.select<TimetableProvider, TimetableSettings>((
      provider,
    ) {
      return provider.settings;
    });
    final versionText = _packageInfo == null
        ? l10n.loadingText
        : l10n.versionLabel(
            '${_packageInfo!.version} (${_packageInfo!.buildNumber})',
          );

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.aboutTitle),
      child: HyperosListView(
        children: [
          Material(
            color: HyperosColors.card(context),
            shape: HyperosTheme.cardShape(),
            clipBehavior: Clip.antiAlias,
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
                      child: BundledAssetImage(
                        assetPath: BundledAssets.launcherIcon,
                        fit: BoxFit.cover,
                        cacheWidth: 168,
                        cacheHeight: 168,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.timetableAppName,
                    style: HyperosTypography.summaryTitle(context),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    versionText,
                    style: HyperosTypography.listDetail(context),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.aboutHeroSubtitle,
                    textAlign: TextAlign.center,
                    style: HyperosTypography.sectionDescription(context),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.thirdPartyDisclaimer,
                    textAlign: TextAlign.center,
                    style: HyperosTypography.sectionDescription(context),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildInfoChip(
                        context,
                        label: l10n.platformLabel,
                        value: 'Android',
                      ),
                      _buildInfoChip(
                        context,
                        label: l10n.focusLabel,
                        value: 'HyperOS',
                      ),
                      _buildInfoChip(
                        context,
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
          const HyperosSectionGap(),
          HyperosListGroup(
            children: [
              _AboutEntryTile(
                icon: Icons.system_update_alt_rounded,
                iconAccent: HyperosIconColors.orange,
                title: l10n.aboutUpdatesTitle,
                subtitle: l10n.aboutUpdatesSubtitle,
                onTap: () {
                  Navigator.push(
                    context,
                    HyperosPageRoute(
                      builder: (_) =>
                          AboutUpdateScreen(packageInfo: _packageInfo),
                    ),
                  );
                },
              ),
              _AboutEntryTile(
                icon: Icons.history_rounded,
                iconAccent: HyperosIconColors.blue,
                title: l10n.aboutChangelogTitle,
                subtitle: l10n.aboutChangelogSubtitle,
                onTap: () {
                  Navigator.push(
                    context,
                    HyperosPageRoute(builder: (_) => const ChangelogScreen()),
                  );
                },
              ),
              _AboutEntryTile(
                icon: Icons.flag_outlined,
                iconAccent: HyperosIconColors.purple,
                title: l10n.aboutPositioningTitle,
                subtitle: l10n.aboutPositioningSubtitle,
                onTap: () {
                  _showInfoSheet(
                    context,
                    title: l10n.aboutPositioningTitle,
                    subtitle: l10n.aboutPositioningSubtitle,
                    items: [
                      l10n.aboutPositioningBullet1,
                      l10n.aboutPositioningBullet2,
                      l10n.aboutPositioningBullet3,
                      l10n.aboutPositioningBullet4,
                    ],
                  );
                },
              ),
              _AboutEntryTile(
                icon: Icons.import_export_rounded,
                iconAccent: HyperosIconColors.teal,
                title: l10n.aboutImportMigrationTitle,
                subtitle: l10n.aboutImportMigrationSubtitle,
                onTap: () {
                  _showInfoSheet(
                    context,
                    title: l10n.aboutImportMigrationTitle,
                    subtitle: l10n.aboutImportMigrationSubtitle,
                    items: [
                      l10n.aboutImportMigrationBullet1,
                      l10n.aboutImportMigrationBullet2,
                      l10n.aboutImportMigrationBullet3,
                      l10n.aboutImportMigrationBullet4,
                    ],
                  );
                },
              ),
              _AboutEntryTile(
                icon: Icons.group_outlined,
                iconAccent: HyperosIconColors.green,
                title: l10n.aboutContributorsTitle,
                subtitle: l10n.aboutContributorsSubtitle,
                onTap: () {
                  Navigator.push(
                    context,
                    HyperosPageRoute(
                      settings: const RouteSettings(
                        name: '/about/contributors',
                      ),
                      builder: (_) => const ContributorsScreen(),
                    ),
                  );
                },
              ),
              _AboutEntryTile(
                icon: Icons.code_rounded,
                iconAccent: HyperosIconColors.indigo,
                title: l10n.aboutRepositoryTitle,
                subtitle: l10n.aboutRepositorySubtitle,
                onTap: () => _showRepositorySheet(context),
              ),
              _AboutEntryTile(
                icon: Icons.article_outlined,
                iconAccent: HyperosIconColors.cyan,
                title: l10n.aboutAppLogsTitle,
                subtitle: l10n.aboutAppLogsSubtitle,
                onTap: _openAppLogsPage,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showInfoSheet(
    BuildContext context, {
    required String title,
    String? subtitle,
    required List<String> items,
  }) {
    showHyperosSheet<void>(
      context: context,
      builder: (sheetContext) =>
          AboutInfoSheetBody(title: title, subtitle: subtitle, items: items),
    );
  }

  void _showRepositorySheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showHyperosSheet<void>(
      context: context,
      builder: (sheetContext) => HyperosSheet(
        title: l10n.aboutRepositorySheetTitle,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppUpdateService.repositoryUrl,
              style: HyperosTypography.listDetail(sheetContext),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.aboutRepositorySheetHint,
              style: HyperosTypography.listDetail(sheetContext),
            ),
            const SizedBox(height: 16),
            HyperosButton(
              label: l10n.aboutOpenGitHubAction,
              expand: true,
              onPressed: _openRepository,
            ),
            const SizedBox(height: 10),
            HyperosButton(
              label: l10n.aboutOpenWarehouseRepoAction,
              variant: HyperosButtonVariant.secondary,
              expand: true,
              onPressed: _openWarehouseRepository,
            ),
            const SizedBox(height: 10),
            HyperosButton(
              label: l10n.copyAddress,
              variant: HyperosButtonVariant.secondary,
              expand: true,
              onPressed: _copyRepositoryUrl,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAppLogsPage() async {
    if (_openingAppLogs) {
      return;
    }
    _openingAppLogs = true;
    final settings = context.read<TimetableProvider>().settings;
    final l10n = AppLocalizations.of(context)!;
    try {
      await Navigator.of(context).push(
        HyperosPageRoute(
          settings: const RouteSettings(name: '/about/app-logs'),
          builder: (_) => LiveDiagnosticsLogViewerScreen(
            title: l10n.aboutAppLogsTitle,
            loadRawLog: () async {
              final nativeRawLog = await MiuiLiveActivitiesService()
                  .readLiveDiagnosticsText();
              return AppLogService.instance.readMergedLogsText(
                nativeRawLog: nativeRawLog,
              );
            },
            isRecordingEnabled: settings.liveEnableLocalDiagnostics,
            onRecordingChanged: (value) =>
                _updateLiveDiagnosticsPreference(value),
            onExport: (text) async {
              final nativeRawLog = await MiuiLiveActivitiesService()
                  .readLiveDiagnosticsText();
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
              final clearedAppLogs = await AppLogService.instance
                  .clearAppLogs();
              final clearedNativeLogs = await MiuiLiveActivitiesService()
                  .clearLiveDiagnostics();
              return clearedAppLogs || clearedNativeLogs;
            },
          ),
        ),
      );
    } finally {
      _openingAppLogs = false;
    }
  }

  Future<void> _updateLiveDiagnosticsPreference(bool value) async {
    final provider = context.read<TimetableProvider>();
    final l10n = AppLocalizations.of(context)!;
    final message = await provider.updateTimetableSettings(
      provider.settings.copyWith(liveEnableLocalDiagnostics: value),
    );
    if (!mounted) {
      return;
    }
    if (message != null) {
      showAppToast(context, message: message);
      return;
    }
    showAppToast(
      context,
      message: value
          ? l10n.aboutLiveDiagnosticsEnabled
          : l10n.aboutLiveDiagnosticsDisabled,
      kind: AppToastKind.success,
    );
  }

  Widget _buildInfoChip(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: HyperosColors.rowHighlight(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: HyperosTypography.listDetail(context)),
          const SizedBox(height: 2),
          Text(value, style: HyperosTypography.listTitle(context)),
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
    showAppToast(
      context,
      message: AppLocalizations.of(context)!.copiedRepositoryAddress,
      kind: AppToastKind.success,
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

  const AboutUpdateScreen({super.key, required this.packageInfo});

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
  bool _openingDiagnosticsViewer = false;
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
    final settings = context.select<TimetableProvider, TimetableSettings>((
      provider,
    ) {
      return provider.settings;
    });

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.aboutUpdateScreenTitle),
      suffixes: [
        FHeaderAction(
          icon: const Icon(Icons.tune_rounded),
          semanticsLabel: l10n.aboutAdvancedOptionsTitle,
          onPress: () => _openAdvancedOptions(theme, settings),
        ),
      ],
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: HyperosTokens.listPadding,
              child: _buildUpdateCard(theme, settings),
            ),
          ),
          if (_isDownloading) _buildDownloadProgressBar(theme),
        ],
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
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _UpdateCheckAnimation(colorScheme: colorScheme),
                  const SizedBox(height: 24),
                  Text(
                    l10n.aboutCheckingLatestVersion,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '正在连接更新服务器...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final result = snapshot.data;
        if (result == null) {
          return Material(
            color: HyperosColors.card(context),
            shape: HyperosTheme.cardShape(),
            clipBehavior: Clip.antiAlias,
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
                    style: HyperosTypography.sectionLabel(context),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.aboutReadVersionFailedHint,
                    style: HyperosTypography.sectionDescription(context),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return SingleChildScrollView(
          child: Column(
            children: [
              _buildStatusCard(theme, result),
              if ((result.latestRelease?.body ?? '').isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildNotesCard(theme, result),
              ],
            ],
          ),
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
      AboutUpdatePrimaryAction.openReleasePage => l10n.aboutViewReleaseAction,
      AboutUpdatePrimaryAction.downloadInApp => l10n.aboutDownloadNowAction,
      AboutUpdatePrimaryAction.openDownloadLink =>
        l10n.aboutOpenDownloadPageAction,
    };
    final statusColor = result.hasUpdate ? colorScheme.primary : Colors.green;
    final statusIcon = result.hasUpdate
        ? Icons.system_update_rounded
        : Icons.check_circle;

    return Material(
      color: HyperosColors.card(context),
      shape: HyperosTheme.cardShape(),
      clipBehavior: Clip.antiAlias,
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
              style: HyperosTypography.sectionLabel(
                context,
              ).copyWith(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            // 更新时间
            if (release?.updatedAt != null)
              Text(
                l10n.aboutUpdatedAt(_formatDateTime(release!.updatedAt!)),
                style: HyperosTypography.listDetail(context),
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
                      style: HyperosTypography.listDetail(context),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.currentVersion,
                      style: HyperosTypography.listTitle(
                        context,
                      ).copyWith(fontFamily: 'monospace'),
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
                      style: HyperosTypography.listDetail(context),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      release?.version ?? l10n.aboutUnreleasedLabel,
                      style: HyperosTypography.listTitle(
                        context,
                      ).copyWith(fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            // 主要操作按钮
            HyperosButton(
              label: _isDownloading
                  ? l10n.aboutDownloadCancelling
                  : primaryButtonLabel,
              expand: true,
              loading: _isDownloading,
              onPressed: result.hasRelease
                  ? () {
                      if (primaryAction ==
                          AboutUpdatePrimaryAction.openReleasePage) {
                        _openUrl(release?.releaseUrl);
                      } else if (downloadChannel ==
                          AppUpdateDownloadChannel.pgyer) {
                        _openUrl(effectiveDownloadUrl);
                      } else if (effectiveDownloadUrl != null) {
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
            ),
            if (primaryAction != AboutUpdatePrimaryAction.openReleasePage &&
                result.hasRelease) ...[
              const SizedBox(height: 10),
              HyperosButton(
                label: l10n.aboutViewReleaseAction,
                variant: HyperosButtonVariant.secondary,
                expand: true,
                onPressed: () => _openUrl(release?.releaseUrl),
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
    return Material(
      color: HyperosColors.card(context),
      shape: HyperosTheme.cardShape(),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.update_rounded,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.aboutReleaseNotesTitle,
                  style: HyperosTypography.sectionLabel(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ReleaseNotesMarkdown(
              data: result.latestRelease!.body.trim(),
              onTapLink: _openUrl,
              plainTypography: true,
            ),
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

  void _openAdvancedOptions(ThemeData theme, TimetableSettings settings) {
    Navigator.of(context).push(
      HyperosPageRoute(
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
          onExportLiveDiagnostics: _exportLiveDiagnostics,
          onOpenLiveDiagnosticsViewer: _openLiveDiagnosticsViewer,
          onClearLiveDiagnostics: _clearLiveDiagnostics,
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
      );
    });
  }

  Future<void> _updatePrereleasePreference(bool value) async {
    final provider = context.read<TimetableProvider>();
    final message = await provider.updateTimetableSettings(
      provider.settings.copyWith(appUpdateIncludePrerelease: value),
    );
    if (!mounted) {
      return;
    }
    if (message != null) {
      showAppToast(context, message: message);
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
      provider.settings.copyWith(liveEnableLocalDiagnostics: value),
    );
    if (!mounted) {
      return;
    }
    if (message != null) {
      showAppToast(context, message: message);
      return;
    }
    showAppToast(
      context,
      message: value
          ? AppLocalizations.of(context)!.aboutLiveDiagnosticsEnabled
          : AppLocalizations.of(context)!.aboutLiveDiagnosticsDisabled,
      kind: AppToastKind.success,
    );
  }

  Future<void> _openLiveDiagnosticsViewer() async {
    if (_openingDiagnosticsViewer) {
      return;
    }
    _openingDiagnosticsViewer = true;
    final settings = context.read<TimetableProvider>().settings;
    try {
      await Navigator.of(context).push(
        HyperosPageRoute(
          builder: (_) => LiveDiagnosticsLogViewerScreen(
            title: AppLocalizations.of(context)!.aboutAppLogsTitle,
            loadRawLog: () async {
              final nativeRawLog = await MiuiLiveActivitiesService()
                  .readLiveDiagnosticsText();
              return AppLogService.instance.readMergedLogsText(
                nativeRawLog: nativeRawLog,
              );
            },
            isRecordingEnabled: settings.liveEnableLocalDiagnostics,
            onRecordingChanged: _updateLiveDiagnosticsPreference,
            onExport: _exportLiveDiagnostics,
            onClear: _clearLiveDiagnostics,
          ),
        ),
      );
    } finally {
      _openingDiagnosticsViewer = false;
    }
  }

  Future<void> _exportLiveDiagnostics([String? _]) async {
    final nativeRawLog = await MiuiLiveActivitiesService()
        .readLiveDiagnosticsText();
    final path = await AppLogService.instance.exportMergedLogsFile(
      nativeRawLog: nativeRawLog,
    );
    if (!mounted) {
      return;
    }
    if (path == null || path.isEmpty) {
      showAppToast(
        context,
        message: AppLocalizations.of(context)!.aboutNoDiagnosticsExportYet,
        kind: AppToastKind.warning,
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
    final clearedNativeLogs = await MiuiLiveActivitiesService()
        .clearLiveDiagnostics();
    final cleared = clearedAppLogs || clearedNativeLogs;
    if (!mounted) {
      return cleared;
    }
    showAppToast(
      context,
      message: cleared
          ? AppLocalizations.of(context)!.liveDiagnosticsCleared
          : AppLocalizations.of(context)!.liveDiagnosticsClearFailed,
      kind: cleared ? AppToastKind.success : AppToastKind.error,
    );
    return cleared;
  }

  Future<void> _updateDownloadSource(AppUpdateDownloadSource source) async {
    final provider = context.read<TimetableProvider>();
    final message = await provider.updateTimetableSettings(
      provider.settings.copyWith(appUpdateDownloadSource: source.value),
    );
    if (!mounted) {
      return;
    }
    if (message != null) {
      showAppToast(context, message: message);
    } else {
      _analytics.logEventLater(
        name: 'update_source_changed',
        parameters: {'source': source.value},
      );
    }
  }

  Future<void> _updateDownloadChannel(AppUpdateDownloadChannel channel) async {
    final provider = context.read<TimetableProvider>();
    final message = await provider.updateTimetableSettings(
      provider.settings.copyWith(appUpdateDownloadChannel: channel.value),
    );
    if (!mounted) {
      return;
    }
    if (message != null) {
      showAppToast(context, message: message);
    } else {
      _analytics.logEventLater(
        name: 'update_channel_changed',
        parameters: {'channel': channel.value},
      );
    }
  }

  Future<void> _updateMirrorPreset(AppUpdateMirrorPreset preset) async {
    final provider = context.read<TimetableProvider>();
    final message = await provider.updateTimetableSettings(
      provider.settings.copyWith(appUpdateMirrorPreset: preset.value),
    );
    if (!mounted) {
      return;
    }
    if (message != null) {
      showAppToast(context, message: message);
      return;
    }
    _analytics.logEventLater(
      name: 'update_mirror_preset_changed',
      parameters: {'preset': preset.value},
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
      MapEntry(
        AppUpdateMirrorPreset.ghProxyCom,
        resolveAppUpdateMirrorUrlPrefix(
          preset: AppUpdateMirrorPreset.ghProxyCom,
          customUrlPrefix: customMirrorUrlPrefix,
        ),
      ),
      MapEntry(
        AppUpdateMirrorPreset.ghproxyNet,
        resolveAppUpdateMirrorUrlPrefix(
          preset: AppUpdateMirrorPreset.ghproxyNet,
          customUrlPrefix: customMirrorUrlPrefix,
        ),
      ),
    ];
    final normalizedCustomPrefix = _normalizeMirrorUrlPrefix(
      customMirrorUrlPrefix,
    );
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
      showAppToast(
        context,
        message: l10n.aboutProbeNoMirrorFound,
        kind: AppToastKind.warning,
      );
      return;
    }

    final currentPreset = AppUpdateMirrorPresetX.fromValue(
      context.read<TimetableProvider>().settings.appUpdateMirrorPreset,
    );
    _analytics.logEventLater(
      name: 'update_mirror_probe_completed',
      parameters: {'recommended': recommendedPreset.value},
    );
    if (recommendedPreset == currentPreset) {
      showAppToast(
        context,
        message: l10n.aboutProbeCurrentFastest(currentPreset.label),
        kind: AppToastKind.success,
      );
      return;
    }

    showAppToastWithAction(
      context,
      message: l10n.aboutProbeRecommendSwitch(recommendedPreset.label),
      actionLabel: l10n.switchAction,
      onAction: () => _updateMirrorPreset(recommendedPreset),
    );
  }

  void _showDownloadFailureSnackBar(String error) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.read<TimetableProvider>().settings;
    final source = AppUpdateDownloadSourceX.fromValue(
      settings.appUpdateDownloadSource,
    );

    if (source == AppUpdateDownloadSource.original) {
      showAppToastWithAction(
        context,
        message: l10n.aboutSwitchToMirrorAfterError(error),
        actionLabel: l10n.switchAction,
        onAction: () => _updateDownloadSource(AppUpdateDownloadSource.mirror),
        kind: AppToastKind.error,
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
      showAppToastWithAction(
        context,
        message: l10n.aboutSwitchPresetAfterError(error, fallbackPreset.label),
        actionLabel: l10n.switchAction,
        onAction: () => _updateMirrorPreset(fallbackPreset),
        kind: AppToastKind.error,
      );
      return;
    }

    showAppToast(context, message: error, kind: AppToastKind.error);
  }

  Future<void> _editMirrorUrlPrefix() async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<TimetableProvider>();
    final controller = TextEditingController(
      text: provider.settings.appUpdateMirrorUrlPrefix,
    );
    final result = await showAppTextInputDialog(
      context,
      title: l10n.aboutSetMirrorSourceTitle,
      body: HyperosTextField(
        controller: controller,
        label: l10n.aboutMirrorPrefixLabel,
        hint: 'https://ghfast.top/',
        autofocus: true,
      ),
      readValue: () => controller.text,
    );
    controller.dispose();

    if (result == null || !mounted) {
      return;
    }

    final normalizedPrefix = _normalizeMirrorUrlPrefix(result);
    if (normalizedPrefix == null) {
      showAppToast(
        context,
        message: l10n.aboutMirrorPrefixInvalid,
        kind: AppToastKind.error,
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
    showAppToast(
      context,
      message: message ?? l10n.aboutMirrorSaved,
      kind: AppToastKind.success,
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

    final error = await _updateService.downloadAndInstallUpdate(url, (
      downloadedBytes,
      totalBytes,
    ) {
      if (mounted) {
        setState(() {
          _downloadedBytes = downloadedBytes;
          _downloadTotalBytes = totalBytes;
        });
      }
    }, controller);

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
        showAppToast(context, message: l10n.aboutDownloadCancelled);
        return;
      }
      _analytics.logEventLater(name: 'update_download_failed');
      _showDownloadFailureSnackBar(error);
      return;
    }

    _analytics.logEventLater(name: 'update_download_completed');
    showAppToast(
      context,
      message: l10n.aboutInstallReady,
      kind: AppToastKind.success,
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
        parameters: {'has_download_id': downloadId != null},
      );
      showAppToast(
        context,
        message: l10n.aboutSystemDownloaderQueued,
        kind: AppToastKind.success,
      );
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      _analytics.logEventLater(name: 'update_system_download_failed');
      showAppToast(
        context,
        message: error.message?.trim().isNotEmpty == true
            ? error.message!
            : l10n.aboutSystemDownloaderFailed,
        kind: AppToastKind.error,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _analytics.logEventLater(name: 'update_system_download_failed');
      showAppToast(
        context,
        message: l10n.aboutSystemDownloaderFailed,
        kind: AppToastKind.error,
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
              child: LinearProgressIndicator(value: progress, minHeight: 8),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: HyperosButton(
                label: _isCancellingDownload
                    ? l10n.aboutDownloadCancelling
                    : l10n.aboutCancelDownloadAction,
                variant: HyperosButtonVariant.secondary,
                loading: _isCancellingDownload,
                onPressed: _isCancellingDownload ? null : _cancelDownload,
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

    canvas.drawArc(rect, startAngle + 3.14159, sweepAngle * 0.6, false, paint2);
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
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
  final Future<void> Function([String? rawLog]) onExportLiveDiagnostics;
  final Future<void> Function() onOpenLiveDiagnosticsViewer;
  final Future<bool> Function() onClearLiveDiagnostics;

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
    required this.onExportLiveDiagnostics,
    required this.onOpenLiveDiagnosticsViewer,
    required this.onClearLiveDiagnostics,
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
    final settings = context.select<TimetableProvider, TimetableSettings>(
      (p) => p.settings,
    );
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
    final recommendedMirrorPreset = resolveRecommendedMirrorPreset(
      probeResultByPreset,
    );

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.aboutAdvancedOptionsTitle),
      child: FutureBuilder<AppUpdateCheckResult>(
        future: widget.updateFuture,
        builder: (context, snapshot) {
          final result = snapshot.data;
          final release = result?.latestRelease;
          final originalDownloadUrl = release?.downloadUrl;

          return HyperosListView(
            children: [
              _buildDownloadChannelGroup(theme, settings),
              const HyperosSectionGap(),
              _buildDownloadMethodGroup(theme),
              const HyperosSectionGap(),
              HyperosListGroup(
                children: [
                  HyperosSwitchTile(
                    title: l10n.aboutCheckPrereleaseTitle,
                    subtitle: l10n.aboutCheckPrereleaseSubtitle,
                    value: settings.appUpdateIncludePrerelease,
                    onChanged: widget.packageInfo == null
                        ? null
                        : _updatePrereleasePreference,
                  ),
                ],
              ),
              if (downloadChannel == AppUpdateDownloadChannel.github &&
                  downloadSource == AppUpdateDownloadSource.mirror) ...[
                const HyperosSectionGap(),
                _buildMirrorPresetGroup(
                  theme,
                  settings: settings,
                  mirrorPreset: mirrorPreset,
                  recommendedPreset: recommendedMirrorPreset,
                ),
                const HyperosSectionGap(),
                HyperosControlCard(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      HyperosButton(
                        label: _isProbingMirrors
                            ? l10n.aboutProbingMirrors
                            : l10n.aboutProbeMirrorsAction,
                        variant: HyperosButtonVariant.secondary,
                        loading: _isProbingMirrors,
                        onPressed:
                            originalDownloadUrl == null || _isProbingMirrors
                            ? null
                            : () => _probeAndRecommendMirrors(
                                originalDownloadUrl,
                                customMirrorUrlPrefix:
                                    settings.appUpdateMirrorUrlPrefix,
                              ),
                      ),
                      HyperosButton(
                        label: mirrorPreset.usesCustomUrl
                            ? l10n.aboutEditCustomMirrorAction
                            : l10n.aboutSetCustomMirrorAction,
                        variant: HyperosButtonVariant.secondary,
                        onPressed: _editMirrorUrlPrefix,
                      ),
                    ],
                  ),
                ),
              ],
              const HyperosSectionGap(),
              _buildDiagnosticsCard(theme, settings),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDownloadChannelGroup(
    ThemeData theme,
    TimetableSettings settings,
  ) {
    final downloadChannel = AppUpdateDownloadChannelX.fromValue(
      settings.appUpdateDownloadChannel,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HyperosSectionLabel(text: '下载渠道'),
        const HyperosSectionDescription(text: '蒲公英国内高速下载，GitHub 支持镜像加速'),
        HyperosListGroup(
          children: [
            _HyperosChoiceTile(
              title: '蒲公英下载',
              selected: downloadChannel == AppUpdateDownloadChannel.pgyer,
              onTap: () =>
                  _updateDownloadChannel(AppUpdateDownloadChannel.pgyer),
            ),
            _HyperosChoiceTile(
              title: 'GitHub 下载',
              selected: downloadChannel == AppUpdateDownloadChannel.github,
              onTap: () =>
                  _updateDownloadChannel(AppUpdateDownloadChannel.github),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDownloadMethodGroup(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HyperosSectionLabel(text: '下载安装包方式'),
        const HyperosSectionDescription(text: '选择应用内直接下载或系统下载管理器'),
        HyperosListGroup(
          children: [
            _HyperosChoiceTile(
              title: '应用内下载',
              selected: !_useSystemDownloader,
              onTap: () {
                setState(() => _useSystemDownloader = false);
                widget.onUseSystemDownloaderChanged(false);
              },
            ),
            _HyperosChoiceTile(
              title: '系统管理器',
              selected: _useSystemDownloader,
              onTap: () {
                setState(() => _useSystemDownloader = true);
                widget.onUseSystemDownloaderChanged(true);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMirrorPresetGroup(
    ThemeData theme, {
    required TimetableSettings settings,
    required AppUpdateMirrorPreset mirrorPreset,
    required AppUpdateMirrorPreset? recommendedPreset,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HyperosSectionLabel(text: l10n.aboutMirrorSectionTitle),
        HyperosSectionDescription(text: l10n.aboutMirrorSectionMirrorHint),
        HyperosListGroup(
          children: [
            for (final preset in AppUpdateMirrorPreset.values)
              _buildMirrorPresetTile(
                theme,
                preset: preset,
                currentPreset: mirrorPreset,
                recommendedPreset: recommendedPreset,
                settings: settings,
                onTap: () => _handleMirrorPresetTap(preset, settings),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildMirrorPresetTile(
    ThemeData theme, {
    required AppUpdateMirrorPreset preset,
    required AppUpdateMirrorPreset currentPreset,
    required AppUpdateMirrorPreset? recommendedPreset,
    required TimetableSettings settings,
    required VoidCallback onTap,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final probeState = _mirrorProbeStates
        .where((s) => s.preset == preset)
        .firstOrNull;
    final isSelected = currentPreset == preset;
    final isRecommended =
        recommendedPreset == preset && probeState?.result.isSuccess == true;
    final subtitleText =
        preset.usesCustomUrl && settings.appUpdateMirrorUrlPrefix.trim().isEmpty
        ? l10n.aboutFillCustomMirrorFirst
        : (preset.usesCustomUrl
              ? resolveAppUpdateMirrorUrlPrefix(
                  preset: preset,
                  customUrlPrefix: settings.appUpdateMirrorUrlPrefix,
                )
              : preset.description);

    final suffixChildren = <Widget>[];
    if (probeState != null) {
      suffixChildren.add(_buildMirrorProbeStatusChip(theme, probeState.result));
    }

    return _HyperosChoiceTile(
      title: isRecommended
          ? '${preset.label} · ${l10n.aboutRecommended}'
          : preset.label,
      subtitle: subtitleText,
      selected: isSelected,
      trailing: suffixChildren.isEmpty
          ? null
          : Row(mainAxisSize: MainAxisSize.min, children: suffixChildren),
      onTap: onTap,
    );
  }

  Widget _buildMirrorProbeStatusChip(
    ThemeData theme,
    AppUpdateDownloadProbeResult result,
  ) {
    final colorScheme = theme.colorScheme;
    final (label, background, foreground) = switch (result) {
      AppUpdateDownloadProbeResult(isSuccess: true, :final elapsed) => (
        '${elapsed.inMilliseconds}ms',
        Colors.green.withValues(alpha: 0.12),
        Colors.green,
      ),
      AppUpdateDownloadProbeResult(isSuccess: false) => (
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
          fontWeight: FontWeight.w400,
          color: foreground,
        ),
      ),
    );
  }

  Widget _buildDiagnosticsCard(ThemeData theme, TimetableSettings settings) {
    final l10n = AppLocalizations.of(context)!;
    return HyperosControlCard(
      title: l10n.aboutDiagnosticsTitle,
      subtitle: l10n.aboutDiagnosticsSubtitle,
      plainTitle: true,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          HyperosButton(
            label: l10n.aboutExportDiagnosticsAction,
            variant: HyperosButtonVariant.secondary,
            onPressed: widget.onExportLiveDiagnostics,
          ),
          HyperosButton(
            label: l10n.aboutViewPhoneLogsAction,
            variant: HyperosButtonVariant.secondary,
            onPressed: widget.onOpenLiveDiagnosticsViewer,
          ),
          HyperosButton(
            label: l10n.aboutClearAndRecollectAction,
            variant: HyperosButtonVariant.secondary,
            onPressed: widget.onClearLiveDiagnostics,
          ),
        ],
      ),
    );
  }

  Future<void> _updateDownloadChannel(AppUpdateDownloadChannel channel) async {
    final provider = context.read<TimetableProvider>();
    final message = await provider.updateTimetableSettings(
      provider.settings.copyWith(appUpdateDownloadChannel: channel.value),
    );
    if (!mounted) return;
    if (message != null) {
      showAppToast(context, message: message);
    }
  }

  Future<void> _updatePrereleasePreference(bool value) async {
    final provider = context.read<TimetableProvider>();
    final message = await provider.updateTimetableSettings(
      provider.settings.copyWith(appUpdateIncludePrerelease: value),
    );
    if (!mounted) return;
    if (message != null) {
      showAppToast(context, message: message);
    }
  }

  Future<void> _handleMirrorPresetTap(
    AppUpdateMirrorPreset preset,
    TimetableSettings settings,
  ) async {
    final provider = context.read<TimetableProvider>();
    final message = await provider.updateTimetableSettings(
      provider.settings.copyWith(appUpdateMirrorPreset: preset.value),
    );
    if (!mounted) return;
    if (message != null) {
      showAppToast(context, message: message);
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
        MapEntry(
          AppUpdateMirrorPreset.ghProxyCom,
          resolveAppUpdateMirrorUrlPrefix(
            preset: AppUpdateMirrorPreset.ghProxyCom,
            customUrlPrefix: customMirrorUrlPrefix ?? '',
          ),
        ),
        MapEntry(
          AppUpdateMirrorPreset.ghproxyNet,
          resolveAppUpdateMirrorUrlPrefix(
            preset: AppUpdateMirrorPreset.ghproxyNet,
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
          final probeResult = await widget.updateService.probeDownloadUrl(
            probeUrl,
          );
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
          provider.settings.copyWith(appUpdateMirrorPreset: recommended.value),
        );
      }
    } finally {
      if (mounted) setState(() => _isProbingMirrors = false);
    }
  }

  Future<void> _editMirrorUrlPrefix() async {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.read<TimetableProvider>().settings;
    final controller = TextEditingController(
      text: settings.appUpdateMirrorUrlPrefix,
    );
    final result = await showAppTextInputDialog(
      context,
      title: l10n.aboutSetMirrorSourceTitle,
      body: HyperosTextField(
        controller: controller,
        label: l10n.aboutMirrorPrefixLabel,
        hint: 'https://ghfast.top/',
        autofocus: true,
      ),
      readValue: () => controller.text,
    );
    controller.dispose();
    if (result == null || !mounted) return;
    final provider = context.read<TimetableProvider>();
    await provider.updateTimetableSettings(
      provider.settings.copyWith(appUpdateMirrorUrlPrefix: result),
    );
  }
}

class ReleaseNotesMarkdown extends StatelessWidget {
  final String data;
  final ValueChanged<String?>? onTapLink;
  final bool plainTypography;

  const ReleaseNotesMarkdown({
    super.key,
    required this.data,
    this.onTapLink,
    this.plainTypography = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseSheet = MarkdownStyleSheet.fromTheme(theme);
    final body = theme.textTheme.bodyMedium;
    final styleSheet = plainTypography
        ? baseSheet.copyWith(
            p: body,
            strong: body?.copyWith(fontWeight: FontWeight.w400),
            h1: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w400,
            ),
            h2: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w400,
            ),
            h3: body?.copyWith(fontWeight: FontWeight.w400),
            h4: body?.copyWith(fontWeight: FontWeight.w400),
            h5: body?.copyWith(fontWeight: FontWeight.w400),
            h6: body?.copyWith(fontWeight: FontWeight.w400),
          )
        : baseSheet;
    return MarkdownBody(
      data: data,
      selectable: true,
      styleSheet: styleSheet,
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

    final futures = rootIndex.schools
        .map((school) async {
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
        })
        .toList(growable: false);

    final results = await Future.wait(futures);
    for (final entries in results) {
      for (final (maintainer, label) in entries) {
        groups.putIfAbsent(maintainer, () => <String>[]);
        groups[maintainer]!.add(label);
      }
    }

    final result =
        groups.entries
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
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.aboutContributorsScreenTitle),
      child: HyperosListView(
        children: [
          HyperosControlCard(
            title: l10n.aboutDevelopersTitle,
            plainTitle: true,
            child: _ContributorRow(
              name: 'Mutx163',
              subtitle: l10n.aboutDeveloperMaintainerSubtitle,
            ),
          ),
          const HyperosSectionGap(),
          HyperosControlCard(
            title: l10n.aboutWarehouseMaintainersTitle,
            subtitle: l10n.aboutWarehouseMaintainersIntro,
            plainTitle: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isLoadingMaintainers)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Center(child: HyperosCircularProgress()),
                  ),
                if (_maintainersError != null && _maintainers.isEmpty)
                  Text(
                    l10n.aboutWarehouseMaintainersLoadFailed(
                      _maintainersError!,
                    ),
                    style: HyperosTypography.listTitle(
                      context,
                    ).copyWith(color: HyperosTokens.error),
                  )
                else if (_maintainers.isEmpty && !_isLoadingMaintainers)
                  Text(
                    l10n.aboutWarehouseMaintainersEmpty,
                    style: HyperosTypography.listDetail(context),
                  )
                else
                  ..._maintainers.asMap().entries.expand((entry) {
                    final index = entry.key;
                    final group = entry.value;
                    return [
                      if (index > 0) const Divider(height: 24),
                      _ContributorRow(
                        name: group.name,
                        subtitle: l10n.aboutWarehouseMaintainerCount(
                          group.adapterLabels.length,
                        ),
                        details: group.adapterLabels,
                      ),
                    ];
                  }),
              ],
            ),
          ),
          const HyperosSectionGap(),
          HyperosControlCard(
            title: l10n.aboutParticipateWarehouseTitle,
            subtitle: l10n.aboutParticipateWarehouseSubtitle,
            plainTitle: true,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                HyperosButton(
                  label: l10n.aboutOpenWarehouseRepoAction,
                  onPressed: _openWarehouseRepository,
                ),
                HyperosButton(
                  label: l10n.copyAddress,
                  variant: HyperosButtonVariant.secondary,
                  onPressed: _copyWarehouseRepositoryUrl,
                ),
              ],
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
    showAppToast(
      context,
      message: AppLocalizations.of(context)!.copiedWarehouseRepositoryAddress,
      kind: AppToastKind.success,
    );
  }
}

EdgeInsets _aboutRowPadding(BuildContext context) {
  final scope = HyperosListTileScope.maybeOf(context);
  return HyperosTokens.rowPadding(
    isFirst: scope?.isFirst ?? true,
    isLast: scope?.isLast ?? true,
  );
}

class _AboutEntryTile extends StatelessWidget {
  const _AboutEntryTile({
    required this.icon,
    required this.iconAccent,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconAccent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);

    final row = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: HyperosTokens.listRowMinHeight,
      ),
      child: Padding(
        padding: _aboutRowPadding(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            HyperosIconBadge(icon: icon, accent: iconAccent),
            const SizedBox(width: HyperosTokens.rowContentGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: HyperosTypography.listTitle(context)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: HyperosTypography.listDetail(context)),
                ],
              ),
            ),
            SizedBox(width: HyperosTokens.titleChevronGap),
            const HyperosChevron(),
          ],
        ),
      ),
    );

    return HyperosPressableRow(
      onTap: onTap,
      backgroundColor: cardColor,
      highlightColor: highlightColor,
      child: row,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: HyperosTypography.listTitle(context)),
        const SizedBox(height: 4),
        Text(subtitle, style: HyperosTypography.listDetail(context)),
        if (details.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...details.map(
            (detail) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $detail',
                style: HyperosTypography.listDetail(context),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _HyperosChoiceTile extends StatelessWidget {
  const _HyperosChoiceTile({
    required this.title,
    this.subtitle,
    this.selected = false,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);

    Widget? suffix;
    if (trailing != null) {
      suffix = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          trailing!,
          if (selected) ...[
            const SizedBox(width: 8),
            const HyperosSelectedCheckmark(),
          ],
        ],
      );
    } else if (selected) {
      suffix = const HyperosSelectedCheckmark();
    }

    final row = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: HyperosTokens.listRowMinHeight,
      ),
      child: Padding(
        padding: _aboutRowPadding(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: HyperosTypography.listTitle(context)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: HyperosTypography.listDetail(context),
                    ),
                  ],
                ],
              ),
            ),
            if (suffix != null) ...[
              SizedBox(width: HyperosTokens.titleChevronGap),
              suffix,
            ],
          ],
        ),
      ),
    );

    return HyperosPressableRow(
      onTap: onTap,
      backgroundColor: cardColor,
      highlightColor: highlightColor,
      child: row,
    );
  }
}
