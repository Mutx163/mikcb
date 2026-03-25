import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/time_scheme.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';

Future<void> showTimeSchemeBottomSheet(
  BuildContext context, {
  String? initialEditSchemeId,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _TimeSchemeBottomSheet(
      initialEditSchemeId: initialEditSchemeId,
    ),
  );
}

class _TimeSchemeBottomSheet extends StatefulWidget {
  final String? initialEditSchemeId;

  const _TimeSchemeBottomSheet({
    this.initialEditSchemeId,
  });

  @override
  State<_TimeSchemeBottomSheet> createState() => _TimeSchemeBottomSheetState();
}

class _TimeSchemeBottomSheetState extends State<_TimeSchemeBottomSheet> {
  String? _editingSchemeId;
  TextEditingController? _nameController;
  List<SectionTime> _sections = [];
  _QuickGeneratePreset _lastQuickGeneratePreset = const _QuickGeneratePreset(
    morningCount: 4,
    afternoonCount: 4,
    eveningCount: 2,
    morningStartTime: '08:00',
    afternoonStartTime: '14:00',
    eveningStartTime: '19:00',
    classDurationMinutes: 45,
    breakDurationMinutes: 10,
    breakOverrideRules: [
      BreakOverrideRule(afterSection: 2, breakDurationMinutes: 20),
    ],
  );

  @override
  void initState() {
    super.initState();
    _editingSchemeId = widget.initialEditSchemeId;
    if (_editingSchemeId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _beginEditing(_editingSchemeId!);
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.88;
    return PopScope<void>(
      canPop: _editingSchemeId == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _editingSchemeId != null) {
          _stopEditing();
        }
      },
      child: SafeArea(
        child: SizedBox(
          height: maxSheetHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: _editingSchemeId == null
                ? _buildSchemeList(context)
                : _buildEditor(context),
          ),
        ),
      ),
    );
  }

  Widget _buildSchemeList(BuildContext context) {
    final provider = context.watch<TimetableProvider>();
    final schemes = provider.timeSchemes;
    final currentSchemeId = provider.activeTimeScheme?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '时间模板',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _createScheme,
              icon: const Icon(Icons.add_rounded),
              label: const Text('新建'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '直接切换、新建、复制、编辑节次和删除模板都在这里完成。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: schemes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final scheme = schemes[index];
              final isCurrent = scheme.id == currentSchemeId;
              final usage = _buildUsageInfo(provider, scheme.id);

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(
                      isCurrent
                          ? Icons.schedule_rounded
                          : Icons.access_time_rounded,
                    ),
                  ),
                  title: Text(
                    scheme.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: _buildUsageSubtitle(
                    context,
                    scheme: scheme,
                    usage: usage,
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) => _handleSchemeMenu(
                      context,
                      scheme,
                      usage,
                      value,
                    ),
                    itemBuilder: (context) => [
                      if (!usage.isUnused)
                        const PopupMenuItem(
                          value: 'usage',
                          child: Text('查看使用情况'),
                        ),
                      if (!isCurrent)
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
                        enabled: usage.isUnused,
                        child: const Text('删除'),
                      ),
                    ],
                  ),
                  onTap: isCurrent ? null : () => _applyScheme(scheme.id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEditor(BuildContext context) {
    final provider = context.watch<TimetableProvider>();
    final schemeId = _editingSchemeId!;
    final scheme = provider.timeSchemes.firstWhere((item) => item.id == schemeId);
    final isActive = provider.activeTimeScheme?.id == schemeId;
    final usage = _buildUsageInfo(provider, schemeId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: _stopEditing,
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: '返回模板列表',
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                '编辑时间模板',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: _save,
              child: const Text('保存'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '模板名称',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: '模板名称',
                        ),
                      ),
                      if (isActive || usage.courseCount > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          isActive && usage.courseCount > 0
                              ? '当前课表和部分课程正在使用这套时间模板，保存后会同步更新所有相关课表和课程。'
                              : isActive
                                  ? '当前课表正在使用这套时间模板，保存后会同步更新所有使用它的课表。'
                                  : '有课程正在把这套模板作为副时间表使用，保存后会同步更新所有引用课程。',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (usage.courseReferencePreview != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          usage.courseReferencePreview!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '如果当前课表或课程正在使用这套模板，节次数量不能小于已使用的最大节次。',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: _openQuickGenerate,
                            icon: const Icon(Icons.auto_fix_high_rounded),
                            label: const Text('快捷生成'),
                          ),
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
              const SizedBox(height: 8),
              Text(
                '正在编辑：${scheme.name}',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleSchemeMenu(
    BuildContext context,
    TimeScheme scheme,
    _TimeSchemeUsageInfo usage,
    String value,
  ) async {
    switch (value) {
      case 'apply':
        await _applyScheme(scheme.id);
        break;
      case 'usage':
        _showUsageDetails(scheme, usage);
        break;
      case 'edit':
        _beginEditing(scheme.id);
        break;
      case 'rename':
        await _renameScheme(scheme);
        break;
      case 'duplicate':
        await context.read<TimetableProvider>().duplicateTimeScheme(scheme.id);
        if (!mounted) return;
        ScaffoldMessenger.of(this.context).showSnackBar(
          const SnackBar(content: Text('已复制时间模板')),
        );
        break;
      case 'delete':
        if (usage.isUnused) {
          await _deleteScheme(scheme);
        }
        break;
    }
  }

  void _beginEditing(String schemeId) {
    final provider = context.read<TimetableProvider>();
    final scheme = provider.timeSchemes.firstWhere((item) => item.id == schemeId);
    _nameController?.dispose();
    _nameController = TextEditingController(text: scheme.name);
    setState(() {
      _editingSchemeId = schemeId;
      _sections = List<SectionTime>.from(scheme.sections);
    });
  }

  void _stopEditing() {
    _nameController?.dispose();
    _nameController = null;
    setState(() {
      _editingSchemeId = null;
      _sections = [];
    });
  }

  Future<void> _applyScheme(String schemeId) async {
    await context.read<TimetableProvider>().applyTimeScheme(schemeId);
    if (!mounted) {
      return;
    }
    final nextScheme = context.read<TimetableProvider>().activeTimeScheme;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已应用时间模板：${nextScheme?.name ?? "未命名模板"}')),
    );
  }

  Future<void> _createScheme() async {
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

    if (!mounted || name == null || name.isEmpty) {
      return;
    }

    final scheme = await context.read<TimetableProvider>().createTimeScheme(
          name: name,
        );
    if (!mounted) {
      return;
    }
    _beginEditing(scheme.id);
  }

  Future<void> _renameScheme(TimeScheme scheme) async {
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

    if (!mounted || name == null || name.isEmpty || name == scheme.name) {
      return;
    }

    await context.read<TimetableProvider>().renameTimeScheme(scheme.id, name);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已重命名为 $name')),
    );
  }

  Future<void> _deleteScheme(TimeScheme scheme) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除时间模板'),
        content: Text('确定删除“${scheme.name}”吗？正在被课表或课程使用的模板不能删除。'),
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

    if (!mounted || confirmed != true) {
      return;
    }

    final deleted = await context.read<TimetableProvider>().deleteTimeScheme(
          scheme.id,
        );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted ? '已删除时间模板：${scheme.name}' : '该模板正在被课表或课程使用',
        ),
      ),
    );
  }

  Future<void> _showUsageDetails(
    TimeScheme scheme,
    _TimeSchemeUsageInfo usage,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('“${scheme.name}”的使用情况'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('课表使用：${usage.profileCount} 个'),
                if (usage.profileNames.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...usage.profileNames.map(
                    (name) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• $name'),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text('课程引用：${usage.courseCount} 节'),
                if (usage.courseReferences.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...usage.courseReferences.map(
                    (reference) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• $reference'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  _TimeSchemeUsageInfo _buildUsageInfo(
    TimetableProvider provider,
    String schemeId,
  ) {
    final profileNames = <String>[];
    final courseReferences = <String>[];

    for (final profile in provider.profiles) {
      if (profile.settings.activeTimeSchemeId == schemeId) {
        profileNames.add(profile.name);
      }
      for (final course in profile.courses) {
        if (course.timeSchemeIdOverride != schemeId) {
          continue;
        }
        courseReferences.add(
          '${profile.name} · ${course.name}（周${_weekdayLabel(course.dayOfWeek)} ${course.startSection}-${course.endSection}节）',
        );
      }
    }

    return _TimeSchemeUsageInfo(
      profileNames: profileNames,
      courseReferences: courseReferences,
    );
  }

  Widget _buildUsageSubtitle(
    BuildContext context, {
    required TimeScheme scheme,
    required _TimeSchemeUsageInfo usage,
  }) {
    final summary =
        '${scheme.sectionCount} 节 · ${scheme.sections.first.displayText}${scheme.sectionCount > 1 ? ' 起' : ''} · ${usage.profileCount} 个课表 · ${usage.courseCount} 节课程';
    final preview = usage.courseReferencePreview;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(summary),
        if (preview != null) ...[
          const SizedBox(height: 4),
          Text(
            preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  String _weekdayLabel(int dayOfWeek) {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    if (dayOfWeek < 1 || dayOfWeek > 7) {
      return dayOfWeek.toString();
    }
    return labels[dayOfWeek - 1];
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

    final editedSection = SectionTime(
      startTime: _formatTimeOfDay(start),
      endTime: _formatTimeOfDay(end),
    );
    final startMinutes = _parseTimeMinutes(editedSection.startTime);
    final endMinutes = _parseTimeMinutes(editedSection.endTime);
    if (endMinutes <= startMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('结束时间必须晚于开始时间，暂不支持跨 0 点课程'),
        ),
      );
      return;
    }

    final nextSections = List<SectionTime>.from(_sections);
    nextSections[index] = editedSection;
    final validationMessage = validateSectionTimes(nextSections);
    if (validationMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationMessage)),
      );
      return;
    }

    setState(() {
      _sections[index] = editedSection;
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

  Future<void> _openQuickGenerate() async {
    final preset = await showDialog<_QuickGeneratePreset>(
      context: context,
      builder: (context) => _QuickGenerateDialog(
        initialPreset: _lastQuickGeneratePreset,
      ),
    );
    if (preset == null || !mounted) {
      return;
    }

    try {
      final sections = buildQuickSectionTimes(
        morningCount: preset.morningCount,
        afternoonCount: preset.afternoonCount,
        eveningCount: preset.eveningCount,
        morningStartTime: preset.morningStartTime,
        afternoonStartTime: preset.afternoonStartTime,
        eveningStartTime: preset.eveningStartTime,
        classDurationMinutes: preset.classDurationMinutes,
        breakDurationMinutes: preset.breakDurationMinutes,
        breakOverrideRules: preset.breakOverrideRules,
      );
      setState(() {
        _lastQuickGeneratePreset = preset;
        _sections = sections;
      });
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _save() async {
    final schemeId = _editingSchemeId;
    if (schemeId == null || _nameController == null) {
      return;
    }
    final message = await context.read<TimetableProvider>().updateTimeScheme(
          schemeId: schemeId,
          name: _nameController!.text.trim(),
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
    _stopEditing();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已保存时间模板')),
    );
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

int _parseTimeMinutes(String value) {
  final parts = value.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
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

class _QuickGeneratePreset {
  final int morningCount;
  final int afternoonCount;
  final int eveningCount;
  final String? morningStartTime;
  final String? afternoonStartTime;
  final String? eveningStartTime;
  final int classDurationMinutes;
  final int breakDurationMinutes;
  final List<BreakOverrideRule> breakOverrideRules;

  const _QuickGeneratePreset({
    required this.morningCount,
    required this.afternoonCount,
    required this.eveningCount,
    required this.morningStartTime,
    required this.afternoonStartTime,
    required this.eveningStartTime,
    required this.classDurationMinutes,
    required this.breakDurationMinutes,
    required this.breakOverrideRules,
  });
}

class _TimeSchemeUsageInfo {
  final List<String> profileNames;
  final List<String> courseReferences;

  const _TimeSchemeUsageInfo({
    required this.profileNames,
    required this.courseReferences,
  });

  int get profileCount => profileNames.length;
  int get courseCount => courseReferences.length;
  bool get isUnused => profileCount == 0 && courseCount == 0;

  String? get courseReferencePreview {
    if (courseReferences.isEmpty) {
      return null;
    }
    if (courseReferences.length == 1) {
      return '课程引用：${courseReferences.first}';
    }
    return '课程引用：${courseReferences.take(2).join('；')} 等 $courseCount 节课程';
  }
}

class _QuickGenerateDialog extends StatefulWidget {
  final _QuickGeneratePreset initialPreset;

  const _QuickGenerateDialog({
    required this.initialPreset,
  });

  @override
  State<_QuickGenerateDialog> createState() => _QuickGenerateDialogState();
}

class _QuickGenerateDialogState extends State<_QuickGenerateDialog> {
  late final TextEditingController _morningCountController;
  late final TextEditingController _afternoonCountController;
  late final TextEditingController _eveningCountController;
  late final TextEditingController _classDurationController;
  late final TextEditingController _breakDurationController;
  final List<_BreakOverrideDraft> _breakOverrides = [
    _BreakOverrideDraft(afterSection: 2, breakDurationMinutes: 20),
  ];
  String _morningStartTime = '08:00';
  String _afternoonStartTime = '14:00';
  String _eveningStartTime = '19:00';

  @override
  void initState() {
    super.initState();
    final preset = widget.initialPreset;
    _morningCountController =
        TextEditingController(text: '${preset.morningCount}');
    _afternoonCountController =
        TextEditingController(text: '${preset.afternoonCount}');
    _eveningCountController =
        TextEditingController(text: '${preset.eveningCount}');
    _classDurationController =
        TextEditingController(text: '${preset.classDurationMinutes}');
    _breakDurationController =
        TextEditingController(text: '${preset.breakDurationMinutes}');
    _morningStartTime = preset.morningStartTime ?? '08:00';
    _afternoonStartTime = preset.afternoonStartTime ?? '14:00';
    _eveningStartTime = preset.eveningStartTime ?? '19:00';
    _breakOverrides
      ..clear()
      ..addAll(
        preset.breakOverrideRules.map(
          (rule) => _BreakOverrideDraft(
            afterSection: rule.afterSection,
            breakDurationMinutes: rule.breakDurationMinutes,
          ),
        ),
      );
  }

  @override
  void dispose() {
    _morningCountController.dispose();
    _afternoonCountController.dispose();
    _eveningCountController.dispose();
    _classDurationController.dispose();
    _breakDurationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('快捷生成课表时间'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNumberField(_morningCountController, '上午几节'),
            const SizedBox(height: 12),
            _buildTimeTile(
              label: '早上第一节时间',
              value: _morningStartTime,
              onTap: () => _pickTime(
                currentValue: _morningStartTime,
                onSelected: (value) {
                  setState(() {
                    _morningStartTime = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            _buildNumberField(_afternoonCountController, '下午几节'),
            const SizedBox(height: 12),
            _buildTimeTile(
              label: '下午第一节时间',
              value: _afternoonStartTime,
              onTap: () => _pickTime(
                currentValue: _afternoonStartTime,
                onSelected: (value) {
                  setState(() {
                    _afternoonStartTime = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            _buildNumberField(_eveningCountController, '晚上几节'),
            const SizedBox(height: 12),
            _buildTimeTile(
              label: '晚上第一节时间',
              value: _eveningStartTime,
              onTap: () => _pickTime(
                currentValue: _eveningStartTime,
                onSelected: (value) {
                  setState(() {
                    _eveningStartTime = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            _buildNumberField(_classDurationController, '单节课时长（分钟）'),
            const SizedBox(height: 12),
            _buildNumberField(_breakDurationController, '小课间时长（分钟）'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '大课间规则',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 8),
            ..._buildBreakOverrideRows(),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addBreakOverride,
                icon: const Icon(Icons.add_rounded),
                label: const Text('新增大课间规则'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('生成'),
        ),
      ],
    );
  }

  Widget _buildNumberField(TextEditingController controller, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeTile({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(value),
      trailing: const Icon(Icons.schedule_outlined),
      onTap: onTap,
    );
  }

  List<Widget> _buildBreakOverrideRows() {
    if (_breakOverrides.isEmpty) {
      return [
        Text(
          '未设置大课间规则，将全部使用小课间时长。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ];
    }

    return List.generate(_breakOverrides.length, (index) {
      final item = _breakOverrides[index];
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: '${item.afterSection}',
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '第几节后',
                ),
                onChanged: (value) {
                  item.afterSection = int.tryParse(value) ?? 0;
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: '${item.breakDurationMinutes}',
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '休息多久(分)',
                ),
                onChanged: (value) {
                  item.breakDurationMinutes = int.tryParse(value) ?? 0;
                },
              ),
            ),
            IconButton(
              tooltip: '删除规则',
              onPressed: () {
                setState(() {
                  _breakOverrides.removeAt(index);
                });
              },
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _pickTime({
    required String currentValue,
    required ValueChanged<String> onSelected,
  }) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _parseTimeOfDay(currentValue),
    );
    if (selected == null || !mounted) {
      return;
    }
    onSelected(_formatTimeOfDay(selected));
  }

  void _submit() {
    final morningCount = int.tryParse(_morningCountController.text.trim());
    final afternoonCount = int.tryParse(_afternoonCountController.text.trim());
    final eveningCount = int.tryParse(_eveningCountController.text.trim());
    final classDuration = int.tryParse(_classDurationController.text.trim());
    final breakDuration = int.tryParse(_breakDurationController.text.trim());

    if (morningCount == null ||
        afternoonCount == null ||
        eveningCount == null ||
        classDuration == null ||
        breakDuration == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请把节数和时长填写为数字')),
      );
      return;
    }

    final breakOverrideRules = _breakOverrides
        .where((item) => item.afterSection > 0 && item.breakDurationMinutes >= 0)
        .map(
          (item) => BreakOverrideRule(
            afterSection: item.afterSection,
            breakDurationMinutes: item.breakDurationMinutes,
          ),
        )
        .toList();

    Navigator.pop(
      context,
      _QuickGeneratePreset(
        morningCount: morningCount,
        afternoonCount: afternoonCount,
        eveningCount: eveningCount,
        morningStartTime: _morningStartTime,
        afternoonStartTime: _afternoonStartTime,
        eveningStartTime: _eveningStartTime,
        classDurationMinutes: classDuration,
        breakDurationMinutes: breakDuration,
        breakOverrideRules: breakOverrideRules,
      ),
    );
  }

  void _addBreakOverride() {
    setState(() {
      _breakOverrides.add(
        _BreakOverrideDraft(afterSection: 0, breakDurationMinutes: 20),
      );
    });
  }
}

class _BreakOverrideDraft {
  int afterSection;
  int breakDurationMinutes;

  _BreakOverrideDraft({
    required this.afterSection,
    required this.breakDurationMinutes,
  });
}
