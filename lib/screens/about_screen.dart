import 'dart:convert';
import 'dart:async';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/service_message_localizer.dart';
import 'package:university_timetable/l10n/enum_localizations.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/warehouse_repository_models.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../services/app_analytics.dart';
import '../widgets/release_notes_markdown.dart';
import 'changelog_screen.dart';

// `ReleaseNotesMarkdown` 已抽到 widgets/（断 about ↔ changelog 环）；
// 这里 re-export 保持既有 import 本文件取该类的调用方不受影响。
export '../widgets/release_notes_markdown.dart' show ReleaseNotesMarkdown;
import 'open_source_licenses_screen.dart';
import '../services/app_update_service.dart';
import '../services/support_creator_service.dart';
import '../widgets/about_info_sheet.dart';
import '../widgets/app_icon_badge.dart';
import '../widgets/third_party_disclaimer_card.dart';
import '../utils/app_toast.dart';
import '../widgets/app_dialogs.dart';
import '../services/warehouse_repository_service.dart';
import '../utils/release_notes_digest.dart';
import '../widgets/release_digest_view.dart';
import 'feedback_screen.dart';
import 'log_viewer_entry.dart';
import 'support_creator_screen.dart';

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

/// 状态卡要显示哪一种形态。
enum AboutUpdateCardState { checkFailed, alreadyLatest, updateAvailable }

/// 三态判据。
///
/// `hasRelease`（有没有拿到 release）决定「能不能展示版本信息」，
/// `hasUpdate`（版本高不高）决定「要不要让人更新」——两者混用正是 2026-10-19
/// 修掉的那个 bug：下载按钮只看 `hasRelease`，于是「已是最新版本」下面挂着一个
/// 能点的「立即下载」，点下去装的是同一个版本。
///
/// `hasRelease == false` 时一律按检查失败处理，即便上游给出自相矛盾的
/// `hasUpdate == true`（那种输入既装不了也说不清）。
@visibleForTesting
AboutUpdateCardState resolveAboutUpdateCardState(AppUpdateCheckResult result) {
  if (!result.hasRelease) {
    return AboutUpdateCardState.checkFailed;
  }
  return result.hasUpdate
      ? AboutUpdateCardState.updateAvailable
      : AboutUpdateCardState.alreadyLatest;
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
                  const AppIconBadge(size: 84, radius: 24),
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
          // 支持与更新：请喝咖啡、反馈、版本、日志
          HyperosSectionLabel(text: l10n.aboutSupportUpdatesSectionTitle),
          HyperosListGroup(
            children: [
              _AboutEntryTile(
                icon: Icons.free_breakfast_rounded,
                iconAccent: HyperosIconColors.yellow,
                title: l10n.homeMenuCoffeeTitle,
                subtitle: l10n.supportHeroTitle,
                onTap: () {
                  Navigator.push(
                    context,
                    HyperosPageRoute(
                      settings: const RouteSettings(
                        name: '/about/support-creator',
                      ),
                      builder: (_) => const SupportCreatorScreen(),
                    ),
                  );
                },
              ),
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

  /// 调试预览开关（长按状态卡图标切换，仅非 release 构建可用）。
  ///
  /// 自测包永远装的是最新一版，「发现新版本」那一屏平时看不到；打开这个开关
  /// 会把「当前版本」按低一段，让这一屏在真机上也能核对。
  bool _debugPreviewUpdate = false;

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
          // 与「检查更新失败」（hasRelease == false）走同一张卡：两条路都是
          // 「拿不到版本信息」，此前这张卡连重试按钮都没有。
          return HyperosListView(children: [_buildCheckFailedCard()]);
        }

        final releaseBody = result.latestRelease?.body ?? '';
        // 「本次更新说明」与首页更新弹窗、历史版本页共用同一份摘要：
        // 顶部 3 条重点 + 分类计数 + 展开后的分组条目。老版本正文里没有可解析
        // 条目时（纯段落）仍退回原来的 Markdown 分块渲染。
        final digest = buildReleaseNotesDigest(releaseBody);
        final useDigest = digest.entries.isNotEmpty;
        final noteBlocks =
            useDigest ? const <String>[] : splitReleaseNotesIntoBlocks(releaseBody);
        final hasNotes = useDigest || noteBlocks.isNotEmpty;
        final itemCount = hasNotes ? (useDigest ? 4 : noteBlocks.length + 3) : 1;

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
            if (useDigest) {
              return _buildNotesDigest(digest);
            }
            return _buildNotesBlock(
              noteBlocks[blockIndex],
              isLast: blockIndex == noteBlocks.length - 1,
            );
          },
        );
      },
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
          const AppIconBadge(),
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
    // 系统下载器（DownloadManager）通道只能吃官方直连 URL：原生
    // UpdateDownloadTrust 只认 github/gitcode 域，镜像外壳（默认 ghfast）
    // 会被拒。因此这条通道单独取直连地址（2026-10-20）。
    final systemDownloaderUrl = _updateService.getSystemDownloaderUrl(
      release: release,
      channel: downloadChannel,
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

    // 2026-10-19：检查失败不再伪装成「已是最新版本」。没拿到 release 时
    // hasRelease 为 false，旧实现与「已是最新」共用同一张卡，于是失败被画成
    // 「已是最新版本 / 最新版本：未发布 / 一个灰掉的按钮」；失败原因
    // （result.message，六语言齐全）整页没有任何渲染点，也没有重试入口。
    final cardState = resolveAboutUpdateCardState(result);
    if (cardState == AboutUpdateCardState.checkFailed) {
      return _buildCheckFailedCard();
    }

    // 调试预览（仅非 release 构建，长按图标切换）：把「当前版本」按低一段，
    // 逼出「有更新」形态——正常测试包永远是最新版，这个状态平时看不到。
    final previewUpdate = _debugPreviewUpdate && !kReleaseMode;
    final latestVersion = release?.version;
    final currentVersion = previewUpdate
        ? _debugPreviousVersion(latestVersion)
        : result.currentVersion;
    final hasUpdate =
        cardState == AboutUpdateCardState.updateAvailable || previewUpdate;

    return Material(
      color: HyperosColors.card(context),
      shape: HyperosTheme.cardShape(),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onLongPress: kReleaseMode
                  ? null
                  : () => setState(
                      () => _debugPreviewUpdate = !_debugPreviewUpdate,
                    ),
              child: const AppIconBadge(),
            ),
            const SizedBox(height: 16),
            // 状态标题：有更新时用主题色 + w600 承担「要做事」，已是最新时
            // 退回主文字色与常规字重，不与下面的版本信息抢层级。
            Text(
              hasUpdate
                  ? l10n.aboutUpdateAvailableHeadline
                  : l10n.aboutAlreadyLatestHeadline,
              textAlign: TextAlign.center,
              style: HyperosTypography.listTitle(context).copyWith(
                color: hasUpdate
                    ? HyperosColors.primary(context)
                    : HyperosColors.primaryText(context),
                fontWeight: hasUpdate ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 8),
            // 版本关系压成一行，与首页更新弹窗同一套写法（旧弱化 → 新强调）。
            // 原先左右两列等宽对比：「2.1.3-4-profile」实测已占满左列 98%，
            // 版本号再多一位就会折行，而且两种写法要用户自己判断谁新。
            if (hasUpdate)
              _buildVersionTransition(
                currentVersion: currentVersion,
                latestVersion: latestVersion ?? l10n.aboutUnreleasedLabel,
              )
            else
              Text(
                '${l10n.aboutCurrentVersionLabel} $currentVersion',
                textAlign: TextAlign.center,
                style: HyperosTypography.sectionDescription(context),
              ),
            const SizedBox(height: 20),
            // 只有真能升的时候才给「立即下载」：已是最新时它只会把同一个版本
            // 再装一遍（首页更新弹窗在这种情况下根本不出现）。没有更新时主
            // 按钮改成「重新检查」，顺带补上此前缺失的重试入口。
            if (hasUpdate)
              HyperosButton(
                label: _isCancellingDownload
                    ? l10n.aboutDownloadCancelling
                    : primaryButtonLabel,
                expand: true,
                loading: _isDownloading,
                onPressed: () {
                  if (primaryAction ==
                      AboutUpdatePrimaryAction.openReleasePage) {
                    _openUrl(release?.releaseUrl);
                  } else if (downloadChannel ==
                      AppUpdateDownloadChannel.pgyer) {
                    _openUrl(effectiveDownloadUrl);
                  } else if (effectiveDownloadUrl != null) {
                    if (_useSystemDownloader) {
                      // 直连地址缺失时不做镜像回退：镜像 URL 必被原生拒，
                      // 直接给失败提示比「点了没反应/必然失败」更清楚。
                      final directUrl = systemDownloaderUrl;
                      if (directUrl == null) {
                        showAppToast(
                          context,
                          message: l10n.aboutSystemDownloaderFailed,
                          kind: AppToastKind.error,
                        );
                      } else {
                        _enqueueSystemDownload(
                          url: directUrl,
                          version: release?.version,
                        );
                      }
                    } else {
                      _downloadAndInstall(
                        effectiveDownloadUrl,
                        // 2026-10-10 信任根收紧：digest 的镜像剥离统一在
                        // 服务层出口（checkForUpdates 返回前）执行，
                        // 这里直接透传。见 app_update_service.dart。
                        expectedApkSha256: release?.expectedApkSha256,
                        fallbackUrl:
                            downloadChannel ==
                                AppUpdateDownloadChannel.gitcode
                            ? release?.downloadUrl
                            : null,
                      );
                    }
                  }
                },
              )
            else
              HyperosButton(
                label: l10n.aboutRefreshCheckTooltip,
                variant: HyperosButtonVariant.secondary,
                expand: true,
                onPressed: _refreshUpdate,
              ),
            // 「查看 Release」是次级出口，用文字动作而不是第二个通栏按钮：与主
            // 按钮同宽同高时，形状在说「我们一样重要」，只有颜色在分主次。
            // 没有更新时也保留——那时它是唯一还能打开发布页的入口。
            if (!hasUpdate ||
                primaryAction != AboutUpdatePrimaryAction.openReleasePage) ...[
              const SizedBox(height: 8),
              Center(
                child: _buildTextAction(
                  label: l10n.aboutViewReleaseAction,
                  // 开「发布页列表」而不是某个 tag：tag 页来自赢得竞争的清单
                  // 策略（可能是 GitCode 镜像），与用户选的渠道无关，也不稳。
                  onPressed: () => _openUrl(
                    AppUpdateService.releaseListUrlFor(downloadChannel),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 卡片里的次级文字动作（「查看 Release」这类）。
  ///
  /// 不用 `HyperosButton(expand: false)`：那个组件内部是 `Center`，在父级给出的
  /// 松约束下会撑满可用宽度——真机上就变成了两个一样宽的灰按钮（2026-10-19
  /// 截图复现）。文字动作只占文字本身的宽度，主次一眼能分。
  Widget _buildTextAction({
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: HyperosTypography.listDetail(context).copyWith(
            color: HyperosColors.primary(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// 把版本号最后一段减一（`2.1.3.4` → `2.1.3.3`），只给调试试预览用。
  String _debugPreviousVersion(String? latest) {
    final parts = (latest ?? '').split('.');
    if (parts.length < 2) {
      return '0.0.0';
    }
    final last = int.tryParse(parts.last.replaceAll(RegExp(r'[^0-9]'), ''));
    if (last == null || last <= 0) {
      return '0.0.0';
    }
    return [...parts.take(parts.length - 1), '${last - 1}'].join('.');
  }

  /// 「旧版本 → 新版本」一行，与首页更新弹窗同一套写法：旧版本弱化、
  /// 箭头用三级动作色、新版本用主题色 + w600。
  Widget _buildVersionTransition({
    required String currentVersion,
    required String latestVersion,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 两侧都给 Flexible：安装包版本号可能带上 flavor 后缀（如
        // `2.1.3-4-profile`），极端长串在这里宁可省略号，也不要横向溢出。
        Flexible(
          child: Text(
            currentVersion,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HyperosTypography.listDetail(context),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '→',
          style: HyperosTypography.listDetail(
            context,
          ).copyWith(color: HyperosColors.actionIcon(context)),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            latestVersion,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HyperosTypography.listDetail(context).copyWith(
              color: HyperosColors.primary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// 拿不到版本信息时的卡片（检查更新失败，或 Future 直接给出 null）。
  ///
  /// 只渲染六语言都齐的通用文案，**不直出** `result.message`：那几条
  /// `serviceMsg*` 更新检查消息码在 ja / ko 与 zh_TW / zh_HK 里仍是英文占位，
  /// 直出会让这四个语言的用户看到英文句子（这些码此前整页没有渲染点，
  /// 所以没人撞见）。要显示具体原因，得先把那几条翻译补齐。
  Widget _buildCheckFailedCard() {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: HyperosColors.card(context),
      shape: HyperosTheme.cardShape(),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const AppIconBadge(),
            const SizedBox(height: 16),
            Text(
              l10n.aboutReadVersionFailed,
              textAlign: TextAlign.center,
              style: HyperosTypography.listTitle(
                context,
              ).copyWith(color: HyperosColors.primaryText(context)),
            ),
            const SizedBox(height: 20),
            HyperosButton(
              label: l10n.aboutRefreshCheckTooltip,
              expand: true,
              onPressed: _refreshUpdate,
            ),
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
    return _buildNotesSurface(
      isFirst: true,
      isLast: isLast,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
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
                    Expanded(
                      child: Text(
                        l10n.aboutReleaseNotesTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HyperosTypography.listTitle(
                          context,
                        ).copyWith(color: HyperosColors.primaryText(context)),
                      ),
                    ),
                  ],
                ),
                // 更新时间从标题行右端挪到第二行、降到 13sp 次要墨色：原先它和
                // 标题同字号同颜色挤在一行，实测内容已占满可用宽度的 99%，
                // 360dp 宽的手机上标题必被 ellipsis 吃掉。
                if (updatedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.aboutUpdatedAt(_formatDateTime(updatedAt)),
                    style: HyperosTypography.sectionDescription(context),
                  ),
                ],
              ],
            ),
          ),
          const HyperosDivider(),
        ],
      ),
    );
  }

  Widget _buildNotesBlock(String data, {required bool isLast}) {
    return _buildNotesSurface(
      isFirst: false,
      isLast: isLast,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, isLast ? 16 : 6),
        child: ReleaseNotesMarkdown(
          data: data,
          onTapLink: _openUrl,
          plainTypography: true,
          usePrimaryTextColor: true,
        ),
      ),
    );
  }

  /// 「本次更新说明」：与更新弹窗 / 历史版本页同一个摘要组件。
  ///
  /// 以前这里直接把 Release 正文丢给 Markdown 渲染，首屏是一大段「新增 …」
  /// 平铺；同样的正文在弹窗里已经是「3 条重点 + 分类计数」。现在统一成一份，
  /// 用户在同一版更新里看到的第一屏一致。
  ///
  /// 2026-10-19（第二轮真机反馈）：这一页**默认展开**，且条目不多时不给折叠——
  /// 用户来这一页就是为了看这一版改了什么，没有理由先让人点一下；折叠只在
  /// 「重点行没覆盖全部条目」的长版本上才有意义（那才是真的会省滚动）。
  Widget _buildNotesDigest(ReleaseNotesDigest digest) {
    return _buildNotesSurface(
      isFirst: false,
      isLast: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: ReleaseDigestView(
          digest: digest,
          groupEntries: true,
          // 默认展开（true 是组件默认值，这里写明是为了让「这一页为什么要展开」
          // 在调用处就能读到）；alwaysExpandable 保持默认 false——条目已经全在
          // 重点行里时不出现「收起」。
          initiallyExpanded: true,
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
      // 与状态卡同一种形状（超椭圆）：此前这里是 RoundedRectangleBorder，
      // 同一屏两张卡在深色下角形状会对不上。
      shape: RoundedSuperellipseBorder(borderRadius: borderRadius),
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
    try {
      await provider.updateTimetableSettings(
        provider.settings.copyWith(appUpdateUseSystemDownloader: value),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: AppLocalizations.of(context)!.saveFailed,
        kind: AppToastKind.error,
      );
      return;
    }
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
    String? message;
    try {
      message = await provider.updateTimetableSettings(
        provider.settings.copyWith(appUpdateDownloadSource: source.value),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: AppLocalizations.of(context)!.saveFailed,
        kind: AppToastKind.error,
      );
      return;
    }
    if (!mounted) {
      return;
    }
    if (message != null) {
      showAppToast(
        context,
        message: localizeServiceMessage(AppLocalizations.of(context)!, message),
      );
    } else {
      _analytics.logEventLater(
        name: 'update_source_changed',
        parameters: {'source': source.value},
      );
    }
  }

  Future<void> _updateMirrorPreset(AppUpdateMirrorPreset preset) async {
    final provider = context.read<TimetableProvider>();
    String? message;
    try {
      message = await provider.updateTimetableSettings(
        provider.settings.copyWith(appUpdateMirrorPreset: preset.value),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: AppLocalizations.of(context)!.saveFailed,
        kind: AppToastKind.error,
      );
      return;
    }
    if (!mounted) {
      return;
    }
    if (message != null) {
      showAppToast(
        context,
        message: localizeServiceMessage(AppLocalizations.of(context)!, message),
      );
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
              color: colorScheme.shadow.withValues(alpha: 0.06),
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
              // 分组标签「弹窗提醒」删：组里唯一那行开关的标题就是它（同词念两遍）。
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
              // 分组标签「检测测试版」同上：与组内开关标题同词。
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
          : _buildMirrorProbeStatusChip(
              context,
              l10n,
              theme,
              probeState.result,
            ),
      onTap: onTap,
    );
  }

  Widget _buildMirrorProbeStatusChip(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    AppUpdateDownloadProbeResult result,
  ) {
    final colorScheme = theme.colorScheme;
    final (label, background, foreground) = switch (result) {
      AppUpdateDownloadProbeResult(isSuccess: true, :final elapsed) => (
        '${elapsed.inMilliseconds}ms',
        HyperosColors.success(context).withValues(alpha: 0.12),
        HyperosColors.success(context),
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
    String? message;
    try {
      message = await provider.updateTimetableSettings(
        provider.settings.copyWith(appUpdateDownloadChannel: channel.value),
      );
    } catch (_) {
      if (!mounted) return;
      showAppToast(
        context,
        message: AppLocalizations.of(context)!.saveFailed,
        kind: AppToastKind.error,
      );
      return;
    }
    if (!mounted) return;
    if (message != null) {
      showAppToast(
        context,
        message: localizeServiceMessage(AppLocalizations.of(context)!, message),
      );
    }
  }

  Future<void> _updatePromptPreference(bool value) async {
    final provider = context.read<TimetableProvider>();
    String? message;
    try {
      message = await provider.updateTimetableSettings(
        provider.settings.copyWith(appUpdatePromptEnabled: value),
      );
    } catch (_) {
      if (!mounted) return;
      showAppToast(
        context,
        message: AppLocalizations.of(context)!.saveFailed,
        kind: AppToastKind.error,
      );
      return;
    }
    if (!mounted) return;
    if (message != null) {
      showAppToast(
        context,
        message: localizeServiceMessage(AppLocalizations.of(context)!, message),
      );
    }
  }

  Future<void> _updatePrereleasePreference(bool value) async {
    final provider = context.read<TimetableProvider>();
    String? message;
    try {
      message = await provider.updateTimetableSettings(
        provider.settings.copyWith(appUpdateIncludePrerelease: value),
      );
    } catch (_) {
      if (!mounted) return;
      showAppToast(
        context,
        message: AppLocalizations.of(context)!.saveFailed,
        kind: AppToastKind.error,
      );
      return;
    }
    if (!mounted) return;
    if (message != null) {
      showAppToast(
        context,
        message: localizeServiceMessage(AppLocalizations.of(context)!, message),
      );
    }
  }

  Future<void> _handleMirrorPresetTap(
    AppUpdateMirrorPreset preset,
    TimetableSettings settings,
  ) async {
    final provider = context.read<TimetableProvider>();
    String? message;
    try {
      message = await provider.updateTimetableSettings(
        provider.settings.copyWith(appUpdateMirrorPreset: preset.value),
      );
    } catch (_) {
      if (!mounted) return;
      showAppToast(
        context,
        message: AppLocalizations.of(context)!.saveFailed,
        kind: AppToastKind.error,
      );
      return;
    }
    if (!mounted) return;
    if (message != null) {
      showAppToast(
        context,
        message: localizeServiceMessage(AppLocalizations.of(context)!, message),
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
        try {
          await provider.updateTimetableSettings(
            provider.settings.copyWith(appUpdateMirrorPreset: recommended.value),
          );
        } catch (_) {
          if (!mounted) return;
          showAppToast(
            context,
            message: AppLocalizations.of(context)!.saveFailed,
            kind: AppToastKind.error,
          );
          return;
        }
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
    try {
      await provider.updateTimetableSettings(
        provider.settings.copyWith(appUpdateMirrorUrlPrefix: result),
      );
    } catch (_) {
      if (!mounted) return;
      showAppToast(
        context,
        message: AppLocalizations.of(context)!.saveFailed,
        kind: AppToastKind.error,
      );
      return;
    }
  }
}

class ContributorsScreen extends StatefulWidget {
  const ContributorsScreen({super.key});

  @override
  State<ContributorsScreen> createState() => _ContributorsScreenState();
}

class _ContributorsScreenState extends State<ContributorsScreen> {
  static const WarehouseRepositorySource _warehouseSource =
      defaultQingyuWarehouseSource;
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
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _isLoadingMaintainers = false;
        _maintainersError = localizeServiceError(l10n, error);
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
