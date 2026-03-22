import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/time_scheme.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';

class TimeSchemeManagementScreen extends StatelessWidget {
  const TimeSchemeManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        final schemes = provider.timeSchemes;
        final activeSchemeId = provider.activeTimeScheme?.id;

        return Scaffold(
          appBar: AppBar(
            title: const Text('时间模板管理'),
            actions: [
              IconButton(
                tooltip: '新建模板',
                onPressed: () => _createScheme(context),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          body: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: schemes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final scheme = schemes[index];
              final isActive = scheme.id == activeSchemeId;
              final usageCount = provider.profiles
                  .where((profile) => profile.settings.activeTimeSchemeId == scheme.id)
                  .length;

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(
                      isActive ? Icons.schedule_rounded : Icons.access_time_rounded,
                    ),
                  ),
                  title: Text(
                    scheme.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${scheme.sectionCount} 节 · ${scheme.sections.first.displayText}${scheme.sectionCount > 1 ? ' 起' : ''} · 被 $usageCount 个课表使用',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'apply':
                          await provider.applyTimeScheme(scheme.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('已应用时间模板：${scheme.name}')),
                            );
                          }
                          break;
                        case 'edit':
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _TimeSchemeEditorScreen(
                                schemeId: scheme.id,
                              ),
                            ),
                          );
                          break;
                        case 'rename':
                          await _renameScheme(context, scheme);
                          break;
                        case 'duplicate':
                          await provider.duplicateTimeScheme(scheme.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已复制时间模板')),
                            );
                          }
                          break;
                        case 'delete':
                          await _deleteScheme(context, scheme);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      if (!isActive)
                        const PopupMenuItem(
                          value: 'apply',
                          child: Text('应用到当前课表'),
                        ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('编辑节次'),
                      ),
                      const PopupMenuItem(
                        value: 'rename',
                        child: Text('重命名'),
                      ),
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: Text('复制'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        enabled: usageCount == 0,
                        child: const Text('删除'),
                      ),
                    ],
                  ),
                  onTap: isActive ? null : () => provider.applyTimeScheme(scheme.id),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _createScheme(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建时间模板'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '模板名称',
            hintText: '例如：本校夏季作息',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (!context.mounted || name == null || name.isEmpty) {
      return;
    }

    final scheme = await context.read<TimetableProvider>().createTimeScheme(
          name: name,
        );
    if (!context.mounted) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _TimeSchemeEditorScreen(schemeId: scheme.id),
      ),
    );
  }

  Future<void> _renameScheme(BuildContext context, TimeScheme scheme) async {
    final controller = TextEditingController(text: scheme.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名时间模板'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '模板名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (!context.mounted || name == null || name.isEmpty || name == scheme.name) {
      return;
    }

    await context.read<TimetableProvider>().renameTimeScheme(scheme.id, name);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已重命名为 $name')),
    );
  }

  Future<void> _deleteScheme(BuildContext context, TimeScheme scheme) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除时间模板'),
        content: Text('确定删除“${scheme.name}”吗？正在使用中的模板不能删除。'),
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
      ),
    );

    if (!context.mounted || confirmed != true) {
      return;
    }

    final deleted = await context.read<TimetableProvider>().deleteTimeScheme(
          scheme.id,
        );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(deleted ? '已删除时间模板：${scheme.name}' : '该模板正在被课表使用'),
      ),
    );
  }
}

class _TimeSchemeEditorScreen extends StatefulWidget {
  final String schemeId;

  const _TimeSchemeEditorScreen({required this.schemeId});

  @override
  State<_TimeSchemeEditorScreen> createState() => _TimeSchemeEditorScreenState();
}

class _TimeSchemeEditorScreenState extends State<_TimeSchemeEditorScreen> {
  late final TextEditingController _nameController;
  late List<SectionTime> _sections;

  @override
  void initState() {
    super.initState();
    final provider = context.read<TimetableProvider>();
    final scheme = provider.timeSchemes.firstWhere((item) => item.id == widget.schemeId);
    _nameController = TextEditingController(text: scheme.name);
    _sections = List<SectionTime>.from(scheme.sections);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimetableProvider>();
    final isActive = provider.activeTimeScheme?.id == widget.schemeId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑时间模板'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
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
                  const Text(
                    '模板名称',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: '模板名称',
                    ),
                  ),
                  if (isActive) ...[
                    const SizedBox(height: 8),
                    Text(
                      '当前课表正在使用这套时间模板，保存后会同步更新所有使用它的课表。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
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
                  const Text(
                    '节次时间',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '如果当前课表正在使用这套模板，节次数量不能小于已使用的最大节次。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _sections.length >= 20 ? null : _addSection,
                        icon: const Icon(Icons.add),
                        label: const Text('新增一节'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _sections.length <= 1 ? null : _removeSection,
                        icon: const Icon(Icons.remove),
                        label: const Text('删除末节'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _resetSections,
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('恢复默认'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(_sections.length, (index) {
                    final section = _sections[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('第 ${index + 1} 节'),
                      subtitle: Text('${section.startTime} - ${section.endTime}'),
                      trailing: IconButton(
                        tooltip: '编辑时间',
                        onPressed: () => _editSectionTime(index),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editSectionTime(int index) async {
    final start = await showTimePicker(
      context: context,
      initialTime: _parseTimeOfDay(_sections[index].startTime),
    );
    if (start == null || !mounted) {
      return;
    }

    final end = await showTimePicker(
      context: context,
      initialTime: _parseTimeOfDay(_sections[index].endTime),
    );
    if (end == null || !mounted) {
      return;
    }

    setState(() {
      _sections[index] = SectionTime(
        startTime: _formatTimeOfDay(start),
        endTime: _formatTimeOfDay(end),
      );
    });
  }

  void _addSection() {
    setState(() {
      _sections.add(_buildNextSection(_sections.last));
    });
  }

  void _removeSection() {
    setState(() {
      _sections.removeLast();
    });
  }

  void _resetSections() {
    setState(() {
      _sections = List<SectionTime>.from(TimetableSettings.defaults().sections);
    });
  }

  Future<void> _save() async {
    final message = await context.read<TimetableProvider>().updateTimeScheme(
          schemeId: widget.schemeId,
          name: _nameController.text.trim(),
          sections: _sections,
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
    Navigator.pop(context);
  }
}

TimeOfDay _parseTimeOfDay(String value) {
  final parts = value.split(':');
  return TimeOfDay(
    hour: int.parse(parts[0]),
    minute: int.parse(parts[1]),
  );
}

String _formatTimeOfDay(TimeOfDay time) {
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

SectionTime _buildNextSection(SectionTime last) {
  final end = _parseTimeOfDay(last.endTime);
  final startMinutes = end.hour * 60 + end.minute + 10;
  final endMinutes = startMinutes + 45;
  return SectionTime(
    startTime: _minutesToTime(startMinutes),
    endTime: _minutesToTime(endMinutes),
  );
}

String _minutesToTime(int minutes) {
  final normalized = minutes % (24 * 60);
  final hour = normalized ~/ 60;
  final minute = normalized % 60;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
