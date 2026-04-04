import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../services/app_analytics.dart';
import '../services/app_update_service.dart';
import '../services/miui_live_activities_service.dart';
import '../services/support_creator_service.dart';
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settings =
        context.select<TimetableProvider, TimetableSettings>((provider) {
      return provider.settings;
    });
    final versionText = _packageInfo == null
        ? '读取中'
        : '${_packageInfo!.version} (${_packageInfo!.buildNumber})';

    return Scaffold(
      appBar: AppBar(
        title: const Text('关于软件'),
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
                    '轻屿课表',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '版本 $versionText',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '一个围绕课表查看、课程提醒和 HyperOS 超级岛体验打磨的 Android 开源项目。',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildInfoChip(theme, label: '平台', value: 'Android'),
                      _buildInfoChip(theme, label: '重点', value: 'HyperOS'),
                      _buildInfoChip(
                        theme,
                        label: '更新',
                        value: settings.appUpdateIncludePrerelease
                            ? '含预发布'
                            : '正式版',
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
                  title: '版本更新',
                  subtitle: '检查更新、下载源、镜像源、预发布和诊断',
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
                const Divider(height: 1),
                _AboutNavTile(
                  icon: Icons.flag_outlined,
                  title: '项目定位',
                  subtitle: '这是什么、适合谁、核心能力是什么',
                  onTap: () {
                    _showInfoSheet(
                      context,
                      title: '项目定位',
                      children: const [
                        _AboutBullet(text: '支持周视图课表、课程增删改、.ics 导入'),
                        _AboutBullet(
                          text: '支持实时通知；HyperOS 3.0.300 起支持超级岛 / 焦点通知展示',
                        ),
                        _AboutBullet(
                          text: '支持多课表、时间模板、主题色和卡片样式自定义',
                        ),
                      ],
                    );
                  },
                ),
                const Divider(height: 1),
                _AboutNavTile(
                  icon: Icons.import_export_rounded,
                  title: '导入与迁移',
                  subtitle: '当前导入方式、备份恢复和迁移建议',
                  onTap: () {
                    _showInfoSheet(
                      context,
                      title: '导入与迁移',
                      children: const [
                        _AboutBullet(text: '当前版本还没有直接连接教务系统导入。'),
                        _AboutBullet(
                          text:
                              '如果你要从教务系统导入，建议先在 WakeUp 等课表应用里导入课程，再导出为日历格式，然后在本应用导入。',
                        ),
                        _AboutBullet(
                          text:
                              '如果其他人已经在用本应用，也可以直接让对方导出完整备份文件，你在“数据备份与迁移”里导入即可直接恢复。',
                        ),
                      ],
                    );
                  },
                ),
                const Divider(height: 1),
                _AboutNavTile(
                  icon: Icons.code_rounded,
                  title: '开源仓库',
                  subtitle: 'GitHub 仓库地址、源码、Release 和反馈入口',
                  onTap: () {
                    _showRepositorySheet(context, theme);
                  },
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
                  '开源仓库',
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _openRepository,
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('打开 GitHub'),
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
                        label: const Text('复制地址'),
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
      const SnackBar(content: Text('已复制仓库地址')),
    );
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
    final theme = Theme.of(context);
    final settings =
        context.select<TimetableProvider, TimetableSettings>((provider) {
      return provider.settings;
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('版本更新'),
      ),
      bottomNavigationBar:
          _isDownloading ? _buildDownloadProgressBar(theme) : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildUpdateCard(theme, settings),
          const SizedBox(height: 16),
          _buildTesterOptionsCard(theme, settings),
        ],
      ),
    );
  }

  Widget _buildUpdateCard(ThemeData theme, TimetableSettings settings) {
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
            title: '检查更新',
            trailing: IconButton(
              tooltip: '重新检查',
              onPressed: widget.packageInfo == null ? null : _refreshUpdate,
              icon: const Icon(Icons.refresh_rounded),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          );
        }

        final result = snapshot.data;
        if (result == null) {
          return _buildUpdateSectionCard(
            theme,
            title: '检查更新',
            trailing: IconButton(
              tooltip: '重新检查',
              onPressed: widget.packageInfo == null ? null : _refreshUpdate,
              icon: const Icon(Icons.refresh_rounded),
            ),
            child: Text(
              '暂时无法读取更新信息',
              style: theme.textTheme.bodyMedium,
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
          AboutUpdatePrimaryAction.openReleasePage => '查看 Release',
          AboutUpdatePrimaryAction.downloadInApp => '应用内下载安装',
          AboutUpdatePrimaryAction.openDownloadLink =>
            downloadSource == AppUpdateDownloadSource.mirror
                ? '打开国内镜像下载'
                : '打开 GitHub 下载',
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
              title: '检查更新',
              trailing: IconButton(
                tooltip: '重新检查',
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
                        label: '当前版本',
                        value: result.currentVersion,
                      ),
                      _buildUpdateInfoChip(
                        theme,
                        label: '最新版本',
                        value: release?.version ?? '未发布',
                      ),
                      if (release?.isPrerelease == true)
                        _buildUpdateInfoChip(
                          theme,
                          label: '发布类型',
                          value: '预发布',
                        ),
                    ],
                  ),
                  if (release?.updatedAt != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      '更新时间：${_formatDateTime(release!.updatedAt!)}',
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
              title: '下载与打开',
              subtitle: isAndroid
                  ? '国内网络建议优先用国内镜像下载；也可以直接交给系统下载管理器，走系统通知和下载列表。'
                  : '当前平台不支持应用内安装，会直接打开下载地址。',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (downloadSource == AppUpdateDownloadSource.mirror)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        '当前已选：国内镜像。大多数国内网络直接点这个就行。',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        '当前已选：GitHub 原版。若下载慢或打不开，建议切回国内镜像。',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: result.hasRelease
                        ? (primaryAction ==
                                    AboutUpdatePrimaryAction.downloadInApp &&
                                _isDownloading
                            ? null
                            : () {
                                switch (primaryAction) {
                                  case AboutUpdatePrimaryAction.downloadInApp:
                                    _downloadAndInstall(effectiveDownloadUrl!);
                                    break;
                                  case AboutUpdatePrimaryAction
                                        .openDownloadLink:
                                    _openUrl(effectiveDownloadUrl);
                                    break;
                                  case AboutUpdatePrimaryAction.openReleasePage:
                                    _openUrl(release?.releaseUrl);
                                    break;
                                }
                              })
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
                      label: const Text('使用系统下载器下载'),
                    ),
                  ],
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    onPressed: result.hasRelease
                        ? () => _openUrl(release?.releaseUrl)
                        : null,
                    icon: const Icon(Icons.new_releases_outlined),
                    label: const Text('打开 Release 页面'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildUpdateSectionCard(
              theme,
              title: '下载源',
              subtitle: '国内用户建议保持“国内镜像”。只有你能稳定访问 GitHub 时，再切到 GitHub 原版。',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<AppUpdateDownloadSource>(
                    segments: const [
                      ButtonSegment<AppUpdateDownloadSource>(
                        value: AppUpdateDownloadSource.mirror,
                        label: Text('国内镜像'),
                      ),
                      ButtonSegment<AppUpdateDownloadSource>(
                        value: AppUpdateDownloadSource.original,
                        label: Text('GitHub 原版'),
                      ),
                    ],
                    selected: {downloadSource},
                    onSelectionChanged: (selection) {
                      final nextSource = selection.first;
                      _updateDownloadSource(nextSource);
                    },
                  ),
                  const SizedBox(height: 14),
                  if (downloadSource == AppUpdateDownloadSource.mirror) ...[
                    Text(
                      '镜像线路',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...AppUpdateMirrorPreset.values.map((preset) {
                      final isSelected = mirrorPreset == preset;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: isSelected
                              ? colorScheme.primaryContainer
                              : colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(16),
                          child: RadioListTile<AppUpdateMirrorPreset>(
                            value: preset,
                            groupValue: mirrorPreset,
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              _updateMirrorPreset(value);
                            },
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 2,
                            ),
                            title: Text(preset.label),
                            subtitle: Text(preset.description),
                          ),
                        ),
                      );
                    }),
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
                                ? '当前自定义镜像前缀'
                                : '当前生效镜像前缀',
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
                                ? '当前使用你自定义的镜像地址。保存后会记住这个选项。'
                                : '已记住当前镜像线路。若访问失败，可切换到其他内置镜像或自定义镜像。',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (originalDownloadUrl != null) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: _isProbingMirrors
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
                                        ? '测速中…'
                                        : '测速并推荐',
                                  ),
                                ),
                                if (recommendedMirrorPreset != null &&
                                    recommendedMirrorPreset != mirrorPreset)
                                  FilledButton.tonalIcon(
                                    onPressed: () => _updateMirrorPreset(
                                      recommendedMirrorPreset,
                                    ),
                                    icon:
                                        const Icon(Icons.bolt_rounded),
                                    label: Text(
                                      '切换到推荐：${recommendedMirrorPreset.label}',
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          if (mirrorPreset.usesCustomUrl) ...[
                            const SizedBox(height: 10),
                            FilledButton.tonalIcon(
                              onPressed: _editMirrorUrlPrefix,
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('修改自定义镜像'),
                            ),
                          ],
                          if ((effectiveDownloadUrl ?? '').isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              '当前镜像下载地址',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: SelectableText(
                                effectiveDownloadUrl!,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                          if (_mirrorProbeStates.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              '线路测速结果',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ..._mirrorProbeStates.map((item) {
                              final isRecommended =
                                  item.preset == recommendedMirrorPreset &&
                                      item.result.isSuccess;
                              final statusText = item.result.isSuccess
                                  ? '${item.result.elapsed.inMilliseconds} ms'
                                  : (item.result.message ?? '不可用');
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surface,
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.preset.label,
                                              style: theme
                                                  .textTheme.bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              item.prefix,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            statusText,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  color: item.result.isSuccess
                                                      ? colorScheme.primary
                                                      : colorScheme.error,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          if (isRecommended)
                                            Text(
                                              '推荐',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color:
                                                        colorScheme.primary,
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
                        ],
                      ),
                    ),
                  ] else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'GitHub 原版现在也支持应用内下载安装。若当前网络访问 GitHub 慢或失败，可切回上面的国内镜像。',
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
                title: '本次更新日志',
                subtitle: '显示当前检测到版本的 Release 说明。',
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

  Widget _buildTesterOptionsCard(
    ThemeData theme,
    TimetableSettings settings,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '测试者选项',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '默认只检测正式版。需要帮忙测试时，可以在这里打开预发布版本检测，或开启超级岛诊断日志并导出给开发者。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: settings.appUpdateIncludePrerelease,
              onChanged: widget.packageInfo == null
                  ? null
                  : (value) => _updatePrereleasePreference(value),
              title: const Text('检测预发布版本'),
              subtitle: const Text('打开后会把 GitHub 预发布版本也纳入更新检查。'),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: settings.liveEnableLocalDiagnostics,
              onChanged: widget.packageInfo == null
                  ? null
                  : (value) => _updateLiveDiagnosticsPreference(value),
              title: const Text('超级岛诊断日志'),
              subtitle: const Text('打开后会在本地持续记录超级岛关键日志，仅用于排查“该弹不弹”等问题。'),
            ),
            if (settings.liveEnableLocalDiagnostics)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _exportLiveDiagnostics,
                    icon: const Icon(Icons.ios_share_rounded),
                    label: const Text('导出超级岛诊断日志'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _openLiveDiagnosticsViewer,
                    icon: const Icon(Icons.article_outlined),
                    label: const Text('查看手机日志'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _clearLiveDiagnostics,
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('清空并重新收集'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
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
    setState(() {
      _updateFuture = _updateService.checkForUpdates(
        currentVersion: widget.packageInfo!.version,
        includePrerelease: context
            .read<TimetableProvider>()
            .settings
            .appUpdateIncludePrerelease,
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
        content: Text(value ? '已开启超级岛诊断日志' : '已关闭超级岛诊断日志'),
      ),
    );
  }

  Future<void> _openLiveDiagnosticsViewer() async {
    final rawLog = await MiuiLiveActivitiesService().readLiveDiagnosticsText();
    if (!mounted) {
      return;
    }
    if (rawLog == null || rawLog.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前还没有可查看的超级岛诊断日志')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveDiagnosticsLogViewerScreen(
          title: '超级岛诊断日志',
          rawLog: rawLog,
        ),
      ),
    );
  }

  Future<void> _exportLiveDiagnostics() async {
    final path = await MiuiLiveActivitiesService().exportLiveDiagnosticsFile();
    if (!mounted) {
      return;
    }
    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('还没有可导出的超级岛诊断日志')),
      );
      return;
    }

    await Share.shareXFiles(
      [XFile(path)],
      text: '这是轻屿课表导出的超级岛诊断日志，可用于排查“超级岛没有弹出”等问题。',
      subject: '轻屿课表 - 超级岛诊断日志',
    );
  }

  Future<void> _clearLiveDiagnostics() async {
    final cleared = await MiuiLiveActivitiesService().clearLiveDiagnostics();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          cleared ? '已清空超级岛诊断日志，后续会重新开始收集' : '清空超级岛诊断日志失败',
        ),
      ),
    );
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

  Future<void> _probeAndRecommendMirrors(
    String originalDownloadUrl, {
    required String customMirrorUrlPrefix,
  }) async {
    final candidates = _buildMirrorPresetCandidates(customMirrorUrlPrefix);
    if (candidates.isEmpty) {
      return;
    }

    _analytics.logEventLater(name: 'update_mirror_probe_started');
    setState(() {
      _isProbingMirrors = true;
      _mirrorProbeStates = const [];
    });

    final nextStates = <_MirrorProbeState>[];
    for (final candidate in candidates) {
      final probeUrl = _updateService.buildDownloadUrl(
        originalUrl: originalDownloadUrl,
        source: AppUpdateDownloadSource.mirror,
        mirrorUrlPrefix: candidate.value,
      );
      final probeResult = await _updateService.probeDownloadUrl(probeUrl);
      nextStates.add(
        _MirrorProbeState(
          preset: candidate.key,
          prefix: candidate.value,
          result: probeResult,
        ),
      );
    }

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
        const SnackBar(content: Text('测速完成，但暂时没有发现可用镜像线路')),
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
        SnackBar(content: Text('测速完成，当前线路“${currentPreset.label}”已是最快可用线路')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('测速完成，推荐切换到“${recommendedPreset.label}”'),
        action: SnackBarAction(
          label: '切换',
          onPressed: () {
            _updateMirrorPreset(recommendedPreset);
          },
        ),
      ),
    );
  }

  void _showDownloadFailureSnackBar(String error) {
    final settings = context.read<TimetableProvider>().settings;
    final source = AppUpdateDownloadSourceX.fromValue(
      settings.appUpdateDownloadSource,
    );

    if (source == AppUpdateDownloadSource.original) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$error，可切到国内镜像后再试'),
          action: SnackBarAction(
            label: '切换',
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
    final fallbackPreset = recommendedPreset != null &&
            recommendedPreset != currentPreset
        ? recommendedPreset
        : resolveMirrorFallbackPreset(
            currentPreset: currentPreset,
            availablePresets: availablePresets,
          );

    if (fallbackPreset != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$error，建议切换到“${fallbackPreset.label}”后重试'),
          action: SnackBarAction(
            label: '切换',
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
    final provider = context.read<TimetableProvider>();
    final controller = TextEditingController(
      text: provider.settings.appUpdateMirrorUrlPrefix,
    );
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('设置镜像源'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: '镜像前缀',
              hintText: 'https://ghfast.top/',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(controller.text.trim());
              },
              child: const Text('保存'),
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
        const SnackBar(content: Text('镜像源格式不正确，请输入完整的 http 或 https 地址')),
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
      SnackBar(content: Text(message ?? '镜像源已保存')),
    );
    _analytics.logEventLater(name: 'update_mirror_saved');
  }

  Future<void> _downloadAndInstall(String url) async {
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
          const SnackBar(content: Text('已取消下载')),
        );
        return;
      }
      _analytics.logEventLater(name: 'update_download_failed');
      _showDownloadFailureSnackBar(error);
      return;
    }

    _analytics.logEventLater(name: 'update_download_completed');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('安装包已准备好，已尝试打开安装界面；如果系统没有弹出，请稍后从通知或文件管理器手动安装'),
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
    try {
      final normalizedVersion = (version ?? '').trim().replaceAll(' ', '_');
      final fileName = normalizedVersion.isEmpty
          ? 'mikcb_update.apk'
          : 'mikcb_v$normalizedVersion.apk';
      final downloadId = await _supportService.enqueueSystemDownload(
        url: url,
        fileName: fileName,
        title: '轻屿课表更新包',
        description: '已交给系统下载管理器下载，完成后可直接从系统通知安装。',
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
        const SnackBar(
          content: Text('已交给系统下载管理器，请在系统通知或下载列表里查看进度'),
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
                : '调用系统下载管理器失败',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _analytics.logEventLater(name: 'update_system_download_failed');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('调用系统下载管理器失败')),
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
    final colorScheme = theme.colorScheme;
    final totalBytes = _downloadTotalBytes;
    final progress = totalBytes == null || totalBytes <= 0
        ? null
        : _downloadedBytes / totalBytes;
    final progressText = _isCancellingDownload
        ? '正在取消下载…'
        : progress == null
            ? '正在下载更新 ${_formatBytes(_downloadedBytes)}'
            : '正在下载更新 ${(progress * 100).toStringAsFixed(1)}%';
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
                '镜像源未返回文件总大小，先显示已下载体积',
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
                label: Text(_isCancellingDownload ? '正在取消…' : '取消下载'),
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
