import 'dart:convert';
import 'dart:async';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/service_message_localizer.dart';
import 'package:university_timetable/l10n/enum_localizations.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/warehouse_repository_models.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../services/app_analytics.dart';
import 'changelog_screen.dart';
import 'open_source_licenses_screen.dart';
import '../services/app_update_service.dart';
import '../services/support_creator_service.dart';
import '../services/bundled_assets.dart';
import '../widgets/about_info_sheet.dart';
import '../widgets/third_party_disclaimer_card.dart';
import '../widgets/bundled_asset_image.dart';
import '../utils/app_toast.dart';
import '../widgets/app_dialogs.dart';
import '../services/warehouse_repository_service.dart';
import 'feedback_screen.dart';
import 'log_viewer_entry.dart';

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

final RegExp _releaseNotesVersionHeadingPattern = RegExp(
  r'^#\s+v[\d.\-a-zA-Z]+$',
  caseSensitive: false,
);
final RegExp _releaseNotesHeadingPattern = RegExp(r'^#{1,6}\s+');
final RegExp _releaseNotesTopLevelBulletPattern = RegExp(
  r'^(?:[-+*]|\d+[.)])\s+',
);

/// Splits a release announcement into lazily-renderable Markdown blocks.
///
/// [MarkdownBody] parses its complete input and creates the complete widget
/// tree in one build. That is appropriate for a short paragraph, but a long
/// release announcement can contain hundreds of list rows. Keeping headings
/// and top-level list items as separate blocks lets [ListView.builder] mount
/// only the blocks near the viewport.
@visibleForTesting
List<String> splitReleaseNotesIntoBlocks(String data) {
  final normalizedData = data.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (normalizedData.trim().isEmpty) {
    return const [];
  }

  final lines = normalizedData.split('\n');
  var firstContentLine = 0;
  while (firstContentLine < lines.length &&
      lines[firstContentLine].trim().isEmpty) {
    firstContentLine++;
  }
  if (firstContentLine < lines.length &&
      _releaseNotesVersionHeadingPattern.hasMatch(
        lines[firstContentLine].trim(),
      )) {
    firstContentLine++;
  }

  final blocks = <String>[];
  final currentLines = <String>[];
  var insideCodeFence = false;

  void flushCurrentBlock() {
    final block = currentLines.join('\n').trim();
    if (block.isNotEmpty) {
      blocks.add(block);
    }
    currentLines.clear();
  }

  for (var index = firstContentLine; index < lines.length; index++) {
    final line = lines[index];
    final trimmedLine = line.trim();
    final isCodeFenceMarker =
        trimmedLine.startsWith('```') || trimmedLine.startsWith('~~~');
    final startsHeading =
        !insideCodeFence && _releaseNotesHeadingPattern.hasMatch(line);
    final startsTopLevelBullet =
        !insideCodeFence && _releaseNotesTopLevelBulletPattern.hasMatch(line);

    if (startsHeading || startsTopLevelBullet) {
      // A heading or a new top-level item starts an independently paintable
      // block. Nested / indented list items remain with their parent item.
      flushCurrentBlock();
      currentLines.add(line);
    } else if (trimmedLine.isEmpty && !insideCodeFence) {
      // Blank lines delimit paragraphs and list items. Do not retain them in
      // the block because MarkdownBody adds the relevant block spacing itself.
      flushCurrentBlock();
    } else {
      currentLines.add(line);
    }

    if (isCodeFenceMarker) {
      insideCodeFence = !insideCodeFence;
    }
  }
  flushCurrentBlock();
  return blocks;
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
                      child: const BundledAssetImage(
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
                  const SizedBox(height: 16),
                  _buildHeroMetaStrip(
                    context,
                    platformValue: 'Android',
                    focusValue: 'HyperOS',
                    updateValue: settings.appUpdateIncludePrerelease
                        ? l10n.prereleaseIncluded
                        : l10n.stableOnly,
                  ),
                  const SizedBox(height: 16),
                  ThirdPartyDisclaimerContent(
                    text: l10n.thirdPartyDisclaimer,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const HyperosSectionGap(),
          // 支持与更新：反馈、版本、日志
          HyperosSectionLabel(text: l10n.aboutSupportUpdatesSectionTitle),
          HyperosListGroup(
            children: [
              _AboutEntryTile(
                icon: Icons.chat_bubble_outline_rounded,
                iconAccent: HyperosIconColors.green,
                title: l10n.feedbackEntryTitle,
                subtitle: l10n.feedbackEntrySubtitle,
                onTap: () {
                  HyperosNavigation.push(
                    context,
                    settings: const RouteSettings(name: '/feedback'),
                    builder: (_) => const FeedbackScreen(),
                  );
                },
              ),
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
              // 日志入口保留在此，但排障工具的正门是「设置 → 关于 → 诊断与日志」。
              _AboutEntryTile(
                icon: Icons.article_outlined,
                iconAccent: HyperosIconColors.cyan,
                title: l10n.aboutAppLogsTitle,
                subtitle: l10n.aboutAppLogsSubtitle,
                onTap: _openAppLogsPage,
              ),
            ],
          ),
          const HyperosSectionGap(),
          // 产品说明：定位、导入迁移
          HyperosSectionLabel(text: l10n.aboutProductSectionTitle),
          HyperosListGroup(
            children: [
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
            ],
          ),
          const HyperosSectionGap(),
          // 社区与开源
          HyperosSectionLabel(text: l10n.aboutCommunitySectionTitle),
          HyperosListGroup(
            children: [
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
                icon: Icons.gavel_outlined,
                iconAccent: HyperosIconColors.indigo,
                title: l10n.aboutOpenSourceLicensesTitle,
                subtitle: l10n.aboutOpenSourceLicensesSubtitle,
                onTap: () {
                  Navigator.push(
                    context,
                    HyperosPageRoute(
                      settings: const RouteSettings(
                        name: '/about/oss-licenses',
                      ),
                      builder: (_) => const OpenSourceLicensesScreen(),
                    ),
                  );
                },
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
            // Buttons sit on the frosted sheet surface — do not wrap in
            // HyperosCard (solid white) or the action block looks opaque.
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

  Future<void> _openAppLogsPage() =>
      openLogViewer(context, AppLogSource.merged);

  Widget _buildHeroMetaStrip(
    BuildContext context, {
    required String platformValue,
    required String focusValue,
    required String updateValue,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final insetColor = colorScheme.brightness == Brightness.dark
        ? colorScheme.surfaceContainerHighest
        : colorScheme.surfaceContainerLowest;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: insetColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _AboutHeroMetaCell(
                label: l10n.platformLabel,
                value: platformValue,
              ),
            ),
            const _AboutHeroMetaDivider(),
            Expanded(
              child: _AboutHeroMetaCell(
                label: l10n.focusLabel,
                value: focusValue,
              ),
            ),
            const _AboutHeroMetaDivider(),
            Expanded(
              child: _AboutHeroMetaCell(
                label: l10n.updateLabel,
                value: updateValue,
              ),
            ),
          ],
        ),
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
  late bool _useSystemDownloader;
  int _downloadedBytes = 0;
  int? _downloadTotalBytes;
  AppUpdateDownloadController? _downloadController;

  /// Always empty on this screen.
  ///
  /// Mirror speed-testing lives in [_AdvancedOptionsScreen], which keeps its
  /// own probe state. This screen only forwards the (empty) list so the shared
  /// builder signature stays uniform.
  static const List<_MirrorProbeState> _mirrorProbeStates = [];

  @override
  void initState() {
    super.initState();
    _useSystemDownloader = context
        .read<TimetableProvider>()
        .settings
        .appUpdateUseSystemDownloader;
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
      // MIUI updater style: no large title; the bar rests empty and a small
      // centered title fades in once content scrolls under it.
      collapsibleLargeTitle: false,
      title: HyperosScrollRevealedTitle(
        child: Text(l10n.aboutUpdateScreenTitle),
      ),
      suffixes: [
        FHeaderAction(
          icon: const Icon(Icons.tune_rounded),
          semanticsLabel: l10n.aboutAdvancedOptionsTitle,
          onPress: () => _openAdvancedOptions(theme, settings),
        ),
      ],
      child: Column(
        children: [
          Expanded(child: _buildUpdateList(theme, settings)),
          if (_isDownloading) _buildDownloadProgressBar(theme),
        ],
      ),
    );
  }

  Widget _buildUpdateList(ThemeData theme, TimetableSettings settings) {
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<AppUpdateCheckResult>(
      future: _updateFuture,
      builder: (context, snapshot) {
        if (widget.packageInfo == null ||
            snapshot.connectionState == ConnectionState.waiting) {
          // Non-scroll centered view: inset below the bar manually.
          return HyperosBlurredBodyInset(
            child: _buildUpdateCheckingView(context, theme),
          );
        }

        final result = snapshot.data;
        if (result == null) {
          return HyperosListView(
            children: [
              Material(
                color: HyperosColors.card(context),
                shape: HyperosTheme.cardShape(),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildAppLauncherLogo(context, size: 72),
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
              ),
            ],
          );
        }

        final releaseBody = result.latestRelease?.body ?? '';
        final noteBlocks = splitReleaseNotesIntoBlocks(releaseBody);
        final hasNotes = noteBlocks.isNotEmpty;
        final itemCount = hasNotes ? noteBlocks.length + 3 : 1;

        // A long MarkdownBody is one large, eagerly-built render tree inside
        // SingleChildScrollView. Every scroll frame then has to traverse and
        // paint that tree again. Keep each Markdown block as an independent
        // lazy list item so off-screen announcement content is not built or
        // repainted until it approaches the viewport.
        return HyperosListView(
          itemCount: itemCount,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildStatusCard(theme, result);
            }
            if (!hasNotes) {
              return const SizedBox.shrink();
            }
            if (index == 1) {
              return const HyperosSectionGap();
            }
            if (index == 2) {
              return _buildNotesHeader(theme, result, isLast: false);
            }

            final blockIndex = index - 3;
            return _buildNotesBlock(
              noteBlocks[blockIndex],
              isLast: blockIndex == noteBlocks.length - 1,
            );
          },
        );
      },
    );
  }

  Widget _buildAppLauncherLogo(BuildContext context, {double size = 84}) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = size * 24 / 84;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.18),
            blurRadius: size * 0.21,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BundledAssetImage(
          assetPath: BundledAssets.launcherIcon,
          fit: BoxFit.cover,
          cacheWidth: (size * 2).round(),
          cacheHeight: (size * 2).round(),
        ),
      ),
    );
  }

  Widget _buildUpdateCheckingView(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final foruiTheme = context.theme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 2),
          _buildAppLauncherLogo(context),
          const SizedBox(height: 16),
          Text(
            l10n.timetableAppName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: foruiTheme.typography.display.lg.copyWith(
              fontWeight: FontWeight.w600,
              height: 1,
              letterSpacing: 0.1,
              color: foruiTheme.colors.foreground,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.aboutCheckingForUpdate,
            style: HyperosTypography.listDetail(context),
            textAlign: TextAlign.center,
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme, AppUpdateCheckResult result) {
    final l10n = AppLocalizations.of(context)!;
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

    return Material(
      color: HyperosColors.card(context),
      shape: HyperosTheme.cardShape(),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          children: [
            _buildAppLauncherLogo(context, size: 72),
            const SizedBox(height: 16),
            // 状态标题
            Text(
              result.hasUpdate
                  ? l10n.aboutUpdateAvailableHeadline
                  : l10n.aboutAlreadyLatestHeadline,
              style: result.hasUpdate
                  ? HyperosTypography.sectionLabel(
                      context,
                    ).copyWith(fontSize: 20, fontWeight: FontWeight.w500)
                  : HyperosTypography.sectionLabel(context).copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      color: HyperosColors.primaryText(context),
                    ),
            ),
            const SizedBox(height: 20),
            // 版本对比信息
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        l10n.aboutCurrentVersionLabel,
                        style: HyperosTypography.listDetail(context),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        result.currentVersion,
                        style: HyperosTypography.listTitle(
                          context,
                        ).copyWith(fontFamily: 'monospace'),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        l10n.aboutLatestVersionLabel,
                        style: HyperosTypography.listDetail(context),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        release?.version ?? l10n.aboutUnreleasedLabel,
                        style: HyperosTypography.listTitle(
                          context,
                        ).copyWith(fontFamily: 'monospace'),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
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
                          _downloadAndInstall(
                            effectiveDownloadUrl,
                            expectedApkSha256:
                                release?.expectedApkSha256,
                            fallbackUrl:
                                downloadChannel ==
                                    AppUpdateDownloadChannel.gitcode
                                ? release?.downloadUrl
                                : null,
                          );
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

  Widget _buildNotesHeader(
    ThemeData theme,
    AppUpdateCheckResult result, {
    required bool isLast,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = theme.colorScheme;
    final release = result.latestRelease;
    final updatedAt = release?.updatedAt;
    final headerTextStyle = HyperosTypography.listDetail(
      context,
    ).copyWith(color: Theme.of(context).colorScheme.onSurface);
    return _buildNotesSurface(
      isFirst: true,
      isLast: isLast,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Row(
          children: [
            Icon(Icons.update_rounded, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(l10n.aboutReleaseNotesTitle, style: headerTextStyle),
            ),
            if (updatedAt != null)
              Text(
                l10n.aboutUpdatedAt(_formatDateTime(updatedAt)),
                style: headerTextStyle,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesBlock(String data, {required bool isLast}) {
    return _buildNotesSurface(
      isFirst: false,
      isLast: isLast,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, isLast ? 16 : 6),
        child: ReleaseNotesMarkdown(
          data: data,
          onTapLink: _openUrl,
          plainTypography: true,
          usePrimaryTextColor: true,
        ),
      ),
    );
  }

  Widget _buildNotesSurface({
    required bool isFirst,
    required bool isLast,
    required Widget child,
  }) {
    final radius = HyperosTheme.cardBorderRadius.topLeft.x;
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(isFirst ? radius : 0),
      topRight: Radius.circular(isFirst ? radius : 0),
      bottomLeft: Radius.circular(isLast ? radius : 0),
      bottomRight: Radius.circular(isLast ? radius : 0),
    );

    return Material(
      color: HyperosColors.card(context),
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      clipBehavior: isFirst || isLast ? Clip.antiAlias : Clip.none,
      child: child,
    );
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
            _persistSystemDownloaderPreference(value);
          },
          onOpenLiveDiagnosticsViewer: () =>
              openLogViewer(context, AppLogSource.merged),
        ),
      ),
    );
  }

  Future<void> _persistSystemDownloaderPreference(bool value) async {
    final provider = context.read<TimetableProvider>();
    await provider.updateTimetableSettings(
      provider.settings.copyWith(appUpdateUseSystemDownloader: value),
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

  void _showDownloadFailureSnackBar(String error) {
    final l10n = AppLocalizations.of(context)!;
    final localizedError = localizeServiceMessage(l10n, error);
    final settings = context.read<TimetableProvider>().settings;
    final source = AppUpdateDownloadSourceX.fromValue(
      settings.appUpdateDownloadSource,
    );

    if (source == AppUpdateDownloadSource.original) {
      showAppToastWithAction(
        context,
        message: l10n.aboutSwitchToMirrorAfterError(localizedError),
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
        message: l10n.aboutSwitchPresetAfterError(
          localizedError,
          appUpdateMirrorPresetLabel(l10n, fallbackPreset),
        ),
        actionLabel: l10n.switchAction,
        onAction: () => _updateMirrorPreset(fallbackPreset),
        kind: AppToastKind.error,
      );
      return;
    }

    showAppToast(context, message: localizedError, kind: AppToastKind.error);
  }

  Future<void> _downloadAndInstall(
    String url, {
    String? expectedApkSha256,
    String? fallbackUrl,
    bool isFallbackRetry = false,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.read<TimetableProvider>().settings;
    final mirrorPreset = AppUpdateMirrorPresetX.fromValue(
      settings.appUpdateMirrorPreset,
    );
    final effectiveMirrorUrlPrefix = resolveAppUpdateMirrorUrlPrefix(
      preset: mirrorPreset,
      customUrlPrefix: settings.appUpdateMirrorUrlPrefix,
    );
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
      mirrorUrlPrefix: effectiveMirrorUrlPrefix,
      expectedApkSha256: expectedApkSha256,
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
        showAppToast(context, message: l10n.aboutDownloadCancelled);
        return;
      }
      // GitCode 直连失败时自动回退 GitHub 原始直链重试一次。取消、不受信任
      // 地址、无摘要拒装、安装器打开失败换源也无解，不重试。
      final normalizedFallback = fallbackUrl?.trim() ?? '';
      final notRetryable =
          error.startsWith('update_download_url_untrusted') ||
          error.startsWith('update_sha256_unverified_install_refused') ||
          error.startsWith('update_open_installer_failed');
      if (!isFallbackRetry &&
          !notRetryable &&
          normalizedFallback.isNotEmpty &&
          normalizedFallback != url) {
        _analytics.logEventLater(name: 'update_download_fallback_to_github');
        await _downloadAndInstall(
          normalizedFallback,
          expectedApkSha256: expectedApkSha256,
          isFallbackRetry: true,
        );
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
            ? localizeServiceMessage(l10n, error.message!)
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
  final Future<void> Function() onOpenLiveDiagnosticsViewer;

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
    required this.onOpenLiveDiagnosticsViewer,
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
              HyperosSectionLabel(text: l10n.aboutUpdatePromptTitle),
              HyperosListGroup(
                children: [
                  HyperosSwitchTile(
                    title: l10n.aboutUpdatePromptTitle,
                    subtitle: l10n.aboutUpdatePromptSubtitle,
                    value: settings.appUpdatePromptEnabled,
                    onChanged: _updatePromptPreference,
                  ),
                ],
              ),
              const HyperosSectionGap(),
              _buildDownloadChannelGroup(settings),
              const HyperosSectionGap(),
              _buildDownloadMethodGroup(),
              const HyperosSectionGap(),
              HyperosSectionLabel(text: l10n.aboutCheckPrereleaseTitle),
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
                  originalDownloadUrl: originalDownloadUrl,
                ),
              ],
              const HyperosSectionGap(),
              _buildDiagnosticsCard(settings),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDownloadChannelGroup(TimetableSettings settings) {
    final l10n = AppLocalizations.of(context)!;
    final downloadChannel = AppUpdateDownloadChannelX.fromValue(
      settings.appUpdateDownloadChannel,
    );
    const channels = AppUpdateDownloadChannel.values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        HyperosSectionLabel(text: l10n.aboutDownloadChannelSectionTitle),
        HyperosChoiceGroup(
          children: [
            for (var i = 0; i < channels.length; i++)
              HyperosChoiceTile(
                title: appUpdateDownloadChannelLabel(l10n, channels[i]),
                subtitle: Text(
                  appUpdateDownloadChannelDescription(l10n, channels[i]),
                ),
                selected: downloadChannel == channels[i],
                showDivider: i < channels.length - 1,
                onTap: () => _updateDownloadChannel(channels[i]),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDownloadMethodGroup() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        HyperosSectionLabel(text: l10n.aboutDownloadPackageMethodTitle),
        HyperosChoiceGroup(
          children: [
            HyperosChoiceTile(
              title: l10n.aboutInAppDownloadTitle,
              subtitle: Text(l10n.aboutInAppDownloadSubtitle),
              selected: !_useSystemDownloader,
              showDivider: true,
              onTap: () {
                setState(() => _useSystemDownloader = false);
                widget.onUseSystemDownloaderChanged(false);
              },
            ),
            HyperosChoiceTile(
              title: l10n.aboutSystemDownloaderTitle,
              subtitle: Text(l10n.aboutSystemDownloaderChoiceSubtitle),
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
    required String? originalDownloadUrl,
  }) {
    final l10n = AppLocalizations.of(context)!;
    const presets = AppUpdateMirrorPreset.values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        HyperosSectionLabel(text: l10n.aboutMirrorSectionTitle),
        HyperosChoiceGroup(
          children: [
            for (var i = 0; i < presets.length; i++)
              _buildMirrorPresetTile(
                theme,
                preset: presets[i],
                currentPreset: mirrorPreset,
                recommendedPreset: recommendedPreset,
                settings: settings,
                showDivider: i < presets.length - 1,
                onTap: () => _handleMirrorPresetTap(presets[i], settings),
              ),
          ],
        ),
        const HyperosSectionGap(),
        HyperosListGroup(
          children: [
            HyperosListTile(
              icon: Icons.speed_rounded,
              iconAccent: HyperosIconColors.blue,
              title: _isProbingMirrors
                  ? l10n.aboutProbingMirrors
                  : l10n.aboutProbeMirrorsAction,
              onTap: originalDownloadUrl == null || _isProbingMirrors
                  ? null
                  : () => _probeAndRecommendMirrors(
                      originalDownloadUrl,
                      customMirrorUrlPrefix: settings.appUpdateMirrorUrlPrefix,
                    ),
            ),
            HyperosListTile(
              icon: Icons.link_rounded,
              iconAccent: HyperosIconColors.teal,
              title: mirrorPreset.usesCustomUrl
                  ? l10n.aboutEditCustomMirrorAction
                  : l10n.aboutSetCustomMirrorAction,
              onTap: _editMirrorUrlPrefix,
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
    required bool showDivider,
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
              : appUpdateMirrorPresetDescription(l10n, preset));

    return HyperosChoiceTile(
      title: isRecommended
          ? '${appUpdateMirrorPresetLabel(l10n, preset)} · ${l10n.aboutRecommended}'
          : appUpdateMirrorPresetLabel(l10n, preset),
      subtitle: Text(subtitleText),
      selected: isSelected,
      showDivider: showDivider,
      trailing: probeState == null
          ? null
          : _buildMirrorProbeStatusChip(l10n, theme, probeState.result),
      onTap: onTap,
    );
  }

  Widget _buildMirrorProbeStatusChip(
    AppLocalizations l10n,
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
        l10n.aboutMirrorProbeFailedLabel,
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

  /// Export and clear used to sit here as separate rows, duplicating the log
  /// page's own header actions (and double-toasting on clear). One door now.
  Widget _buildDiagnosticsCard(TimetableSettings settings) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        HyperosSectionLabel(text: l10n.aboutDiagnosticsTitle),
        HyperosListGroup(
          children: [
            HyperosListTile(
              icon: Icons.article_outlined,
              iconAccent: HyperosIconColors.cyan,
              title: l10n.aboutViewPhoneLogsAction,
              onTap: () => widget.onOpenLiveDiagnosticsViewer(),
            ),
          ],
        ),
      ],
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

  Future<void> _updatePromptPreference(bool value) async {
    final provider = context.read<TimetableProvider>();
    final message = await provider.updateTimetableSettings(
      provider.settings.copyWith(appUpdatePromptEnabled: value),
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
    final result = await showAppTextInputDialog(
      context,
      title: l10n.aboutSetMirrorSourceTitle,
      initialValue: settings.appUpdateMirrorUrlPrefix,
      bodyBuilder: (controller) => HyperosTextField(
        controller: controller,
        label: l10n.aboutMirrorPrefixLabel,
        hint: 'https://ghfast.top/',
        autofocus: true,
      ),
    );
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
  final bool usePrimaryTextColor;

  static final RegExp _versionHeadingPattern = RegExp(
    r'^#\s+v[\d.\-a-zA-Z]+',
    caseSensitive: false,
  );

  const ReleaseNotesMarkdown({
    super.key,
    required this.data,
    this.onTapLink,
    this.plainTypography = false,
    this.usePrimaryTextColor = false,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = plainTypography ? _stripVersionHeading(data) : data;
    final styleSheet = _buildReleaseNotesStyleSheet(
      context,
      plainTypography: plainTypography,
      usePrimaryTextColor: usePrimaryTextColor,
    );
    final bulletStyle = styleSheet.listBullet;
    return MarkdownBody(
      data: normalized,
      styleSheet: styleSheet,
      listItemCrossAxisAlignment: plainTypography
          ? MarkdownListItemCrossAxisAlignment.start
          : MarkdownListItemCrossAxisAlignment.baseline,
      bulletBuilder: plainTypography
          ? (_) => Text('·', style: bulletStyle?.copyWith(height: 1.35))
          : null,
      onTapLink: (text, href, title) => onTapLink?.call(href),
    );
  }

  static String _stripVersionHeading(String data) {
    final lines = data.split('\n');
    var start = 0;
    if (lines.isNotEmpty &&
        _versionHeadingPattern.hasMatch(lines.first.trim())) {
      start = 1;
      while (start < lines.length && lines[start].trim().isEmpty) {
        start++;
      }
    }
    return lines.sublist(start).join('\n').trim();
  }

  static MarkdownStyleSheet _buildReleaseNotesStyleSheet(
    BuildContext context, {
    required bool plainTypography,
    required bool usePrimaryTextColor,
  }) {
    final theme = Theme.of(context);
    if (!plainTypography) {
      return MarkdownStyleSheet.fromTheme(theme);
    }
    final onSurface = theme.colorScheme.onSurface;
    final body = usePrimaryTextColor
        ? HyperosTypography.sectionDescription(
            context,
          ).copyWith(color: onSurface)
        : HyperosTypography.sectionDescription(context);
    final sectionHeader = body.copyWith(fontWeight: FontWeight.w600);
    final linkColor = usePrimaryTextColor
        ? onSurface
        : theme.colorScheme.primary;
    return MarkdownStyleSheet(
      p: body,
      pPadding: EdgeInsets.zero,
      listBullet: body,
      listIndent: 12,
      listBulletPadding: const EdgeInsets.only(right: 4),
      blockSpacing: 6,
      h1: sectionHeader,
      h1Padding: EdgeInsets.zero,
      h2: sectionHeader,
      h2Padding: const EdgeInsets.only(top: 8, bottom: 2),
      h3: sectionHeader,
      h3Padding: EdgeInsets.zero,
      h4: body,
      h5: body,
      h6: body,
      strong: body.copyWith(fontWeight: FontWeight.w500),
      em: body.copyWith(fontStyle: FontStyle.italic),
      a: body.copyWith(color: linkColor, decoration: TextDecoration.underline),
      blockquote: body,
      blockquotePadding: const EdgeInsets.only(left: 12),
      code: body.copyWith(
        fontFamily: 'monospace',
        fontSize: (body.fontSize ?? 14) - 1,
      ),
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
          .whereType<Map<String, dynamic>>()
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
            child: HyperosControlCardInset(
              child: _ContributorRow(
                name: 'Mutx163',
                subtitle: l10n.aboutDeveloperMaintainerSubtitle,
              ),
            ),
          ),
          const HyperosSectionGap(),
          HyperosControlCard(
            title: l10n.aboutWarehouseMaintainersTitle,
            subtitle: l10n.aboutWarehouseMaintainersIntro,
            child: HyperosControlCardInset(
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
                      ).copyWith(color: HyperosColors.error(context)),
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
          ),
          const HyperosSectionGap(),
          HyperosControlCard(
            title: l10n.aboutParticipateWarehouseTitle,
            subtitle: l10n.aboutParticipateWarehouseSubtitle,
            child: HyperosControlCardInset(
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

class _AboutHeroMetaCell extends StatelessWidget {
  const _AboutHeroMetaCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: HyperosTypography.listDetail(context),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: HyperosTypography.listDetail(context).copyWith(
              color: Color.lerp(
                HyperosColors.secondaryText(context),
                HyperosColors.primaryText(context),
                0.25,
              ),
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutHeroMetaDivider extends StatelessWidget {
  const _AboutHeroMetaDivider();

  @override
  Widget build(BuildContext context) {
    return VerticalDivider(
      width: 1,
      thickness: 1,
      color: HyperosColors.dividerLine(context),
    );
  }
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
                  Text(
                    subtitle,
                    style: HyperosTypography.listDetail(context),
                    softWrap: true,
                  ),
                ],
              ),
            ),
            const SizedBox(width: HyperosTokens.titleChevronGap),
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
