import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/timetable_provider.dart';

class TimetableProfilesScreen extends StatelessWidget {
  const TimetableProfilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        final profiles = provider.profiles;
        final activeProfileId = provider.activeProfileId;

        return Scaffold(
          appBar: AppBar(
            title: const Text('课表管理'),
            actions: [
              IconButton(
                tooltip: '新建课表',
                onPressed: () => _createBlankProfile(context),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          body: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: profiles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final profile = profiles[index];
              final isActive = profile.id == activeProfileId;
              final theme = Theme.of(context);
              final colorScheme = theme.colorScheme;
              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: isActive
                      ? null
                      : () => _switchProfile(
                            context,
                            profile.id,
                            profile.name,
                          ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: (isActive
                                        ? colorScheme.primary
                                        : colorScheme.secondaryContainer)
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${index + 1}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: isActive
                                      ? colorScheme.primary
                                      : colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${profile.courses.length} 门课程 · 第 ${profile.currentWeek} 周',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: '更多操作',
                              onSelected: (value) async {
                                switch (value) {
                                  case 'switch':
                                    await _switchProfile(
                                      context,
                                      profile.id,
                                      profile.name,
                                    );
                                    break;
                                  case 'rename':
                                    await _renameProfile(
                                      context,
                                      profile.id,
                                      profile.name,
                                    );
                                    break;
                                  case 'duplicate':
                                    await provider.switchProfile(profile.id);
                                    await provider.duplicateActiveProfile();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('已复制当前课表'),
                                        ),
                                      );
                                    }
                                    break;
                                  case 'clear':
                                    await _clearActiveProfileCourses(
                                      context,
                                      profile.name,
                                    );
                                    break;
                                  case 'delete':
                                    await _deleteProfile(
                                      context,
                                      profile.id,
                                      profile.name,
                                    );
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                if (!isActive)
                                  const PopupMenuItem(
                                    value: 'switch',
                                    child: Text('切换到此课表'),
                                  ),
                                const PopupMenuItem(
                                  value: 'rename',
                                  child: Text('重命名'),
                                ),
                                const PopupMenuItem(
                                  value: 'duplicate',
                                  child: Text('复制'),
                                ),
                                if (isActive || profiles.length > 1)
                                  const PopupMenuDivider(),
                                if (isActive)
                                  PopupMenuItem(
                                    value: 'clear',
                                    enabled: profile.courses.isNotEmpty,
                                    child: Text(
                                      '清空课程',
                                      style: TextStyle(
                                        color: colorScheme.error,
                                      ),
                                    ),
                                  ),
                                PopupMenuItem(
                                  value: 'delete',
                                  enabled: profiles.length > 1,
                                  child: Text(
                                    '删除',
                                    style: TextStyle(
                                      color: profiles.length > 1
                                          ? colorScheme.error
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.tonal(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 36),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: isActive
                                    ? null
                                    : () => _switchProfile(
                                          context,
                                          profile.id,
                                          profile.name,
                                        ),
                                child: Text(
                                  isActive ? '正在使用' : '切换到此课表',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 36),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => _renameProfile(
                                context,
                                profile.id,
                                profile.name,
                              ),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('重命名'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _switchProfile(
    BuildContext context,
    String profileId,
    String profileName,
  ) async {
    await context.read<TimetableProvider>().switchProfile(profileId);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已切换到 $profileName')),
    );
  }

  Future<void> _createBlankProfile(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新建课表'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '课表名称',
              hintText: '例如：大二下',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, controller.text.trim()),
              child: const Text('创建'),
            ),
          ],
        );
      },
    );

    if (!context.mounted || name == null || name.isEmpty) {
      return;
    }

    await context.read<TimetableProvider>().createProfile(name: name);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已创建课表：$name')),
    );
  }

  Future<void> _renameProfile(
    BuildContext context,
    String profileId,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('重命名课表'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: '课表名称'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, controller.text.trim()),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (!context.mounted ||
        name == null ||
        name.isEmpty ||
        name == currentName) {
      return;
    }

    await context.read<TimetableProvider>().renameProfile(profileId, name);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已重命名为 $name')),
    );
  }

  Future<void> _clearActiveProfileCourses(
    BuildContext context,
    String profileName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('清空当前课表'),
          content: Text('确定清空“$profileName”的全部课程吗？课表设置会保留。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('清空'),
            ),
          ],
        );
      },
    );

    if (!context.mounted || confirmed != true) {
      return;
    }

    final cleared =
        await context.read<TimetableProvider>().clearActiveProfileCourses();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(cleared ? '已清空课表：$profileName' : '当前课表已经没有课程'),
      ),
    );
  }

  Future<void> _deleteProfile(
    BuildContext context,
    String profileId,
    String name,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除课表'),
          content: Text('确定删除“$name”吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (!context.mounted || confirmed != true) {
      return;
    }

    final success =
        await context.read<TimetableProvider>().deleteProfile(profileId);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? '已删除课表：$name' : '至少保留一个课表')),
    );
  }
}
