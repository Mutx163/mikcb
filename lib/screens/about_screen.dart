import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../services/app_analytics.dart';
import '../services/app_update_service.dart';
import '../services/miui_live_activities_service.dart';

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
  Future<AppUpdateCheckResult>? _updateFuture;
  bool _isDownloading = false;
  int _downloadedBytes = 0;
  int? _downloadTotalBytes;

  @override
  void initState() {
    super.initState();
    _refreshUpdate();
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
                mirrorUrlPrefix: settings.appUpdateMirrorUrlPrefix,
              );
        final isAndroid = defaultTargetPlatform == TargetPlatform.android;
        final primaryButtonLabel = effectiveDownloadUrl == null
            ? '查看 Release'
            : isAndroid
                ? downloadSource == AppUpdateDownloadSource.mirror
                    ? '应用内下载安装'
                    : '打开 GitHub 下载'
                : downloadSource == AppUpdateDownloadSource.mirror
                    ? '打开国内镜像下载'
                    : '打开 GitHub 下载';

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
                  ? '国内网络建议优先用国内镜像下载；如果你能稳定访问 GitHub，也可以切到原版。'
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
                        ? () {
                            if (effectiveDownloadUrl != null && isAndroid) {
                              _downloadAndInstall(effectiveDownloadUrl);
                            } else {
                              _openUrl(
                                  effectiveDownloadUrl ?? release?.releaseUrl);
                            }
                          }
                        : null,
                    icon: Icon(
                      isAndroid
                          ? Icons.download_rounded
                          : Icons.open_in_new_rounded,
                    ),
                    label: Text(primaryButtonLabel),
                  ),
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
                          '镜像源前缀',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          settings.appUpdateMirrorUrlPrefix,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '一般不用改，保持默认就可以。',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.tonalIcon(
                          onPressed: _editMirrorUrlPrefix,
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('修改镜像源'),
                        ),
                        if (downloadSource == AppUpdateDownloadSource.mirror &&
                            (effectiveDownloadUrl ?? '').isNotEmpty) ...[
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
                      ],
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
                child: Text(
                  release!.body.trim(),
                  style: theme.textTheme.bodyMedium,
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
        appUpdateMirrorUrlPrefix: normalizedPrefix,
      ),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message ?? '镜像源已保存')),
    );
    _analytics.logEventLater(name: 'update_mirror_saved');
  }

  Future<void> _downloadAndInstall(String url) async {
    _analytics.logEventLater(name: 'update_download_started');
    setState(() {
      _isDownloading = true;
      _downloadedBytes = 0;
      _downloadTotalBytes = null;
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
    );

    if (!mounted) return;

    setState(() {
      _isDownloading = false;
    });

    if (error != null) {
      _analytics.logEventLater(name: 'update_download_failed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    _analytics.logEventLater(name: 'update_download_completed');
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
    final progressText = progress == null
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
