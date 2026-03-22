import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_update_service.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final AppUpdateService _updateService = AppUpdateService();
  PackageInfo? _packageInfo;
  Future<AppUpdateCheckResult>? _updateFuture;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

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
      _updateFuture = _updateService.checkForUpdates(
        currentVersion: info.version,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF2563EB),
                          Color(0xFF0891B2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.calendar_view_week_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '课程表',
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
                    '一个面向课表查看、课程管理和超级岛实时提醒的开源项目。',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildUpdateCard(theme),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '项目定位',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const _AboutBullet(text: '支持周视图课表、课程增删改、.ics 导入'),
                  const _AboutBullet(text: '支持小米 / HyperOS 超级岛与实时通知'),
                  const _AboutBullet(text: '支持主题色、课表背景和卡片样式自定义'),
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
                    '目前怎么导入课表',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const _AboutBullet(
                    text: '当前版本还没有直接连接教务系统导入。',
                  ),
                  const _AboutBullet(
                    text:
                        '如果你要从教务系统导入，建议先在 WakeUp 等课表应用里导入课程，再导出为日历格式，然后在本应用导入。',
                  ),
                  const _AboutBullet(
                    text: '如果其他人已经在用本应用，也可以直接让对方导出完整备份文件，你在“数据备份与迁移”里导入即可直接恢复。',
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
                    '开源仓库',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppUpdateService.repositoryUrl,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _openRepository,
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('打开 GitHub'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _copyRepositoryUrl,
                        icon: const Icon(Icons.copy_all_rounded),
                        label: const Text('复制地址'),
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

  Widget _buildUpdateCard(ThemeData theme) {
    final colorScheme = theme.colorScheme;
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
                    '检查更新',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '重新检查',
                  onPressed: _packageInfo == null ? null : _refreshUpdate,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<AppUpdateCheckResult>(
              future: _updateFuture,
              builder: (context, snapshot) {
                if (_packageInfo == null ||
                    snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(minHeight: 3),
                  );
                }

                final result = snapshot.data;
                if (result == null) {
                  return Text(
                    '暂时无法读取更新信息',
                    style: theme.textTheme.bodyMedium,
                  );
                }

                final release = result.latestRelease;
                final updateColor = result.hasUpdate
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.message ?? '',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: updateColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('当前版本：${result.currentVersion}'),
                    Text(
                      '最新版本：${release?.version ?? '未发布'}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (release?.publishedAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '发布时间：${_formatDateTime(release!.publishedAt!)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if ((release?.body ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          _trimReleaseBody(release!.body),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (_isDownloading)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '正在下载更新: ${(_downloadProgress * 100).toStringAsFixed(1)}%',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _downloadProgress,
                              minHeight: 8,
                            ),
                          ),
                        ],
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: result.hasRelease
                                ? () {
                                    if (release?.downloadUrl != null && defaultTargetPlatform == TargetPlatform.android) {
                                      _downloadAndInstall(release!.downloadUrl!);
                                    } else {
                                      _openUrl(release?.downloadUrl ?? release?.releaseUrl);
                                    }
                                  }
                                : null,
                            icon: Icon(
                              defaultTargetPlatform == TargetPlatform.android
                                  ? Icons.download_rounded
                                  : Icons.open_in_new_rounded,
                            ),
                            label: Text(
                              release?.downloadUrl != null
                                  ? '应用内下载'
                                  : '查看 Release',
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: result.hasRelease
                                ? () => _openUrl(release?.releaseUrl)
                                : null,
                            icon: const Icon(Icons.new_releases_outlined),
                            label: const Text('Release 页面'),
                          ),
                        ],
                      ),
                  ],
                );
              },
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制仓库地址')),
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
    if (_packageInfo == null) {
      return;
    }
    setState(() {
      _updateFuture = _updateService.checkForUpdates(
        currentVersion: _packageInfo!.version,
      );
    });
  }

  Future<void> _downloadAndInstall(String url) async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    final error = await _updateService.downloadAndInstallUpdate(url, (progress) {
      if (mounted) {
        setState(() {
          _downloadProgress = progress;
        });
      }
    });

    if (!mounted) return;

    setState(() {
      _isDownloading = false;
    });

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
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

  String _trimReleaseBody(String body) {
    final compact = body.trim();
    if (compact.length <= 220) {
      return compact;
    }
    return '${compact.substring(0, 220)}...';
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
