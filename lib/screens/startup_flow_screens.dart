import 'package:flutter/material.dart';

import '../services/app_migration_service.dart';

enum WelcomeFlowAction {
  startUsing,
  importCourses,
  restoreBackup,
  viewGuide,
}

enum MigrationFlowAction {
  restoreBackup,
  skip,
}

class StartupWelcomeScreen extends StatelessWidget {
  const StartupWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('欢迎使用'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primaryContainer,
                    colorScheme.surfaceContainerHighest,
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '轻屿课表',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '你可以先开始使用，也可以直接导入课程或从备份恢复。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _StartupActionTile(
              icon: Icons.rocket_launch_rounded,
              title: '开始使用',
              subtitle: '直接进入软件，并继续完成首次使用说明',
              onTap: () => Navigator.pop(context, WelcomeFlowAction.startUsing),
            ),
            const SizedBox(height: 12),
            _StartupActionTile(
              icon: Icons.file_upload_outlined,
              title: '导入课表',
              subtitle: '从 .ics 文件导入课程',
              onTap: () =>
                  Navigator.pop(context, WelcomeFlowAction.importCourses),
            ),
            const SizedBox(height: 12),
            _StartupActionTile(
              icon: Icons.restore_page_rounded,
              title: '从备份恢复',
              subtitle: '从 .mikcb 备份文件恢复旧数据',
              onTap: () =>
                  Navigator.pop(context, WelcomeFlowAction.restoreBackup),
            ),
            const SizedBox(height: 12),
            _StartupActionTile(
              icon: Icons.menu_book_rounded,
              title: '查看功能说明',
              subtitle: '先了解权限、超级岛和基础设置',
              onTap: () => Navigator.pop(context, WelcomeFlowAction.viewGuide),
            ),
          ],
        ),
      ),
    );
  }
}

class PackageMigrationGuideScreen extends StatefulWidget {
  final String legacyPackageName;

  const PackageMigrationGuideScreen({
    super.key,
    required this.legacyPackageName,
  });

  @override
  State<PackageMigrationGuideScreen> createState() =>
      _PackageMigrationGuideScreenState();
}

class _PackageMigrationGuideScreenState
    extends State<PackageMigrationGuideScreen> {
  final AppMigrationService _migrationService = AppMigrationService();
  bool _isOpeningOldApp = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('迁移旧数据'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color:
                            colorScheme.errorContainer.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '别担心，这不是数据丢失',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '我们更换了应用包名，所以桌面上会暂时出现两个应用图标，这是正常现象。旧数据仍在旧版应用里，请先去旧版备份，再回到新版导入。',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onErrorContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _MigrationStep(
                      index: 1,
                      title: '打开旧版应用',
                      subtitle:
                          '进入“数据备份与迁移”页面后，请点“导出全部数据”。不要点“导出当前课表”，也不要先卸载旧版。',
                    ),
                    const SizedBox(height: 10),
                    _MigrationStep(
                      index: 2,
                      title: '保存备份文件',
                      subtitle:
                          '旧版导出后会弹出系统分享面板。优先选择“保存到文件”，建议存到 下载 / Download 文件夹。',
                    ),
                    const SizedBox(height: 10),
                    _MigrationStep(
                      index: 3,
                      title: '回到当前版本导入',
                      subtitle:
                          '回到新版后，通过系统文件选择器到 下载 / Download 文件夹选中 .mikcb 备份文件即可恢复。确认新版数据正常后，再卸载旧版应用。',
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.tips_and_updates_rounded,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '如果没有“保存到文件”',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '可以先分享到微信任意一个聊天，然后在微信里点开这个备份文件并保存。保存后通常会出现在 Download / WeiXin 文件夹里，再回到新版选择这个 .mikcb 文件导入。',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isOpeningOldApp ? null : _openLegacyApp,
                      icon: _isOpeningOldApp
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.open_in_new_rounded),
                      label: Text(
                        _isOpeningOldApp ? '正在打开旧版...' : '打开旧版去备份',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () => Navigator.pop(
                        context,
                        MigrationFlowAction.restoreBackup,
                      ),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('我已完成备份，去导入'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed: () =>
                          Navigator.pop(context, MigrationFlowAction.skip),
                      child: const Text('稍后再说'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLegacyApp() async {
    setState(() {
      _isOpeningOldApp = true;
    });
    final opened =
        await _migrationService.openPackage(widget.legacyPackageName);
    if (!mounted) {
      return;
    }
    setState(() {
      _isOpeningOldApp = false;
    });
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未能打开旧版应用，请手动返回桌面打开旧版')),
      );
    }
  }
}

class _StartupActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _StartupActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MigrationStep extends StatelessWidget {
  final int index;
  final String title;
  final String subtitle;

  const _MigrationStep({
    required this.index,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
