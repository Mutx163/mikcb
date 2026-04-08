import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../models/time_scheme.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';

class TimeSchemeManagementScreen extends StatefulWidget {
  final String? initialEditSchemeId;

  const TimeSchemeManagementScreen({
    super.key,
    this.initialEditSchemeId,
  });

  @override
  State<TimeSchemeManagementScreen> createState() =>
      _TimeSchemeManagementScreenState();
}

class _TimeSchemeManagementScreenState
    extends State<TimeSchemeManagementScreen> {
  bool _didOpenInitialEditor = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didOpenInitialEditor || widget.initialEditSchemeId == null) {
      return;
    }
    _didOpenInitialEditor = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _openEditor(widget.initialEditSchemeId!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        final schemes = provider.timeSchemes;
        final activeSchemeId = provider.activeTimeScheme?.id;

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.timeSchemeTitle),
            actions: [
              IconButton(
                tooltip: l10n.newSchemeTooltip,
                onPressed: () => _createScheme(context),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          body: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: schemes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final scheme = schemes[index];
              final isActive = scheme.id == activeSchemeId;
              final usage = _buildUsageSummary(provider, scheme.id);
              return _buildSchemeCard(
                context,
                scheme: scheme,
                usage: usage,
                isActive: isActive,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSchemeCard(
    BuildContext context, {
    required TimeScheme scheme,
    required _TimeSchemeUsageSummary usage,
    required bool isActive,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isActive ? null : () => _applyScheme(context, scheme),
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
                    child: Icon(
                      isActive
                          ? Icons.schedule_rounded
                          : Icons.access_time_rounded,
                      color: isActive
                          ? colorScheme.primary
                          : colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scheme.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.timeSchemeSummary(
                            scheme.sectionCount,
                            usage.profileCount,
                            usage.courseCount,
                            usage.overrideCourseCount,
                          ),
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
                    tooltip: l10n.moreActionsTooltip,
                    onSelected: (value) async {
                      switch (value) {
                        case 'usage':
                          await _showUsageDetails(context, scheme, usage);
                          break;
                        case 'apply':
                          await _applyScheme(context, scheme);
                          break;
                        case 'edit':
                          await _openEditor(scheme.id);
                          break;
                        case 'rename':
                          await _renameScheme(context, scheme);
                          break;
                        case 'duplicate':
                          await context
                              .read<TimetableProvider>()
                              .duplicateTimeScheme(scheme.id);
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
                      if (!usage.isUnused)
                        PopupMenuItem(
                          value: 'usage',
                          child: Text(l10n.viewUsageAction),
                        ),
                      if (!isActive)
                        PopupMenuItem(
                          value: 'apply',
                          child: Text(l10n.applyToCurrentTimetable),
                        ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(l10n.editSectionsAction),
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
                        child: Text(
                          '删除',
                          style: TextStyle(
                            color: usage.isUnused
                                ? colorScheme.error
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${scheme.sections.first.displayText}${scheme.sectionCount > 1 ? ' 起' : ''}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
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
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: isActive ? null : () => _applyScheme(context, scheme),
                      child: Text(
                        isActive ? l10n.usingNow : l10n.applyToCurrentTimetable,
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
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _openEditor(scheme.id),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(l10n.editSectionsAction),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEditor(String schemeId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _TimeSchemeEditorScreen(
          schemeId: schemeId,
        ),
      ),
    );
  }

  Future<void> _createScheme(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.createTimeSchemeTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.timeSchemeNameLabel,
            hintText: l10n.timeSchemeNameHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(l10n.createAction),
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
    await _openEditor(scheme.id);
  }

  Future<void> _renameScheme(BuildContext context, TimeScheme scheme) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: scheme.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.renameTimeSchemeTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.timeSchemeNameLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(l10n.saveAction),
          ),
        ],
      ),
    );

    if (!context.mounted ||
        name == null ||
        name.isEmpty ||
        name == scheme.name) {
      return;
    }

    await context.read<TimetableProvider>().renameTimeScheme(scheme.id, name);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.renamedToMessage(name))),
    );
  }

  Future<void> _deleteScheme(BuildContext context, TimeScheme scheme) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteTimeSchemeTitle),
        content: Text(l10n.deleteTimeSchemeMessage(scheme.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.deleteAction),
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
        content: Text(
          deleted
              ? l10n.deletedTimeSchemeMessage(scheme.name)
              : l10n.timeSchemeInUseMessage,
        ),
      ),
    );
  }

  Future<void> _applyScheme(BuildContext context, TimeScheme scheme) async {
    final l10n = AppLocalizations.of(context)!;
    await context.read<TimetableProvider>().applyTimeScheme(scheme.id);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.appliedTimeSchemeMessage(scheme.name))),
    );
  }

  _TimeSchemeUsageSummary _buildUsageSummary(
    TimetableProvider provider,
    String schemeId,
  ) {
    final profileNames = provider.profiles
        .where((profile) => profile.settings.activeTimeSchemeId == schemeId)
        .map((profile) => profile.name)
        .toList(growable: false);
    final references = provider.getTimeSchemeCourseUsages(schemeId);
    final overrideReferences =
        references.where((item) => item.usesOverride).toList(growable: false);
    final previewText = references.isEmpty
        ? null
        : references.length == 1
            ? _formatUsageReference(references.first)
            : '${_formatUsageReference(references.first)} 等 ${references.length} 节课程';
    return _TimeSchemeUsageSummary(
      profileNames: profileNames,
      courseReferences: references,
      overrideReferences: overrideReferences,
      previewText: previewText,
    );
  }

  String _formatUsageReference(TimeSchemeCourseUsageReference reference) {
    final course = reference.course;
    final usageType = reference.usesOverride ? '副时间表' : '主时间表';
    return '${reference.profileName} · ${course.name}'
        '（周${_weekdayLabel(course.dayOfWeek)} ${course.startSection}-${course.endSection}节，$usageType）';
  }

  Future<void> _showUsageDetails(
    BuildContext context,
    TimeScheme scheme,
    _TimeSchemeUsageSummary usage,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final directCourseReferences = usage.directCourseReferences;
    final overrideReferences = usage.overrideReferences;
    await showDialog<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        return AlertDialog(
          title: Text(l10n.timeSchemeUsageTitle(scheme.name)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.timeSchemeUsageIntro,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _TimeSchemeInfoChip(
                        label: l10n.profileCountLabel,
                        value: '${usage.profileCount} 个',
                      ),
                      _TimeSchemeInfoChip(
                        label: l10n.courseCountLabel,
                        value: '${usage.courseCount} 节',
                      ),
                      _TimeSchemeInfoChip(
                        label: l10n.overrideTimeSchemeLabel,
                        value: '${usage.overrideCourseCount} 节',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _UsageSection(
                    title: l10n.directlyBoundProfilesTitle,
                    subtitle: usage.profileCount == 0
                        ? l10n.directlyBoundProfilesEmpty
                        : l10n.directlyBoundProfilesSubtitle,
                    items: usage.profileNames
                        .map((name) => _UsageLine(primary: name))
                        .toList(growable: false),
                    emptyText: l10n.directlyBoundProfilesEmpty,
                  ),
                  const SizedBox(height: 12),
                  _UsageSection(
                    title: l10n.followMainSchemeCoursesTitle,
                    subtitle: directCourseReferences.isEmpty
                        ? l10n.followMainSchemeCoursesEmpty
                        : l10n.followMainSchemeCoursesSubtitle,
                    items: directCourseReferences
                        .map(
                          (reference) => _UsageLine(
                            primary:
                                '${reference.profileName} · ${reference.course.name}',
                            secondary:
                                '周${_weekdayLabel(reference.course.dayOfWeek)} '
                                '${reference.course.startSection}-${reference.course.endSection}节',
                          ),
                        )
                        .toList(growable: false),
                    emptyText: l10n.followMainSchemeCoursesEmpty,
                  ),
                  const SizedBox(height: 12),
                  _UsageSection(
                    title: l10n.overrideSchemeCoursesTitle,
                    subtitle: overrideReferences.isEmpty
                        ? l10n.overrideSchemeCoursesEmpty
                        : l10n.overrideSchemeCoursesSubtitle,
                    items: overrideReferences
                        .map(
                          (reference) => _UsageLine(
                            primary:
                                '${reference.profileName} · ${reference.course.name}',
                            secondary:
                                '周${_weekdayLabel(reference.course.dayOfWeek)} '
                                '${reference.course.startSection}-${reference.course.endSection}节',
                          ),
                        )
                        .toList(growable: false),
                    emptyText: l10n.overrideSchemeCoursesEmpty,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.closeAction),
            ),
          ],
        );
      },
    );
  }

  String _weekdayLabel(int dayOfWeek) {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    if (dayOfWeek < 1 || dayOfWeek > 7) {
      return dayOfWeek.toString();
    }
    return labels[dayOfWeek - 1];
  }
}

class _TimeSchemeEditorScreen extends StatefulWidget {
  final String schemeId;

  const _TimeSchemeEditorScreen({required this.schemeId});

  @override
  State<_TimeSchemeEditorScreen> createState() =>
      _TimeSchemeEditorScreenState();
}

class _TimeSchemeEditorScreenState extends State<_TimeSchemeEditorScreen> {
  late final TextEditingController _nameController;
  late List<SectionTime> _sections;
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
    final provider = context.read<TimetableProvider>();
    final scheme =
        provider.timeSchemes.firstWhere((item) => item.id == widget.schemeId);
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
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TimetableProvider>();
    final isActive = provider.activeTimeScheme?.id == widget.schemeId;
    final usage = _buildUsageSummary(provider, widget.schemeId);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editTimeSchemeTitle),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(l10n.saveAction),
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
                  Text(
                    l10n.timeSchemeNameLabel,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: l10n.timeSchemeNameLabel,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (isActive)
                        _TimeSchemeBadge(
                          text: l10n.currentInUse,
                          icon: Icons.check_circle_outline_rounded,
                        ),
                      _TimeSchemeInfoChip(
                        label: l10n.profileCountLabel,
                        value: '${usage.profileCount} 个',
                      ),
                      _TimeSchemeInfoChip(
                        label: l10n.courseCountLabel,
                        value: '${usage.courseCount} 节',
                      ),
                      _TimeSchemeInfoChip(
                        label: l10n.overrideTimeSchemeLabel,
                        value: '${usage.overrideCourseCount} 节',
                      ),
                    ],
                  ),
                  if (isActive || usage.courseCount > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      isActive && usage.courseCount > 0
                          ? l10n.overrideSchemeCoursesSubtitle
                          : isActive
                              ? l10n.directlyBoundProfilesSubtitle
                              : l10n.overrideSchemeCoursesSubtitle,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (usage.previewText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      usage.previewText!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
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
                  Text(
                    l10n.sectionTimesTitle,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.sectionTimesSubtitle,
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
                        label: Text(l10n.quickGenerateAction),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _sections.length >= 20 ? null : _addSection,
                        icon: const Icon(Icons.add),
                        label: Text(l10n.addSectionAction),
                      ),
                      FilledButton.tonalIcon(
                        onPressed:
                            _sections.length <= 1 ? null : _removeSection,
                        icon: const Icon(Icons.remove),
                        label: Text(l10n.removeLastSectionAction),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _resetSections,
                        icon: const Icon(Icons.restart_alt),
                        label: Text(l10n.resetDefaultAction),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(_sections.length, (index) {
                    final section = _sections[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outlineVariant,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${index + 1}',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '第 ${index + 1} 节',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${section.startTime} - ${section.endTime}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: '编辑时间',
                            onPressed: () => _editSectionTime(index),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
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

  _TimeSchemeUsageSummary _buildUsageSummary(
    TimetableProvider provider,
    String schemeId,
  ) {
    final profileNames = provider.profiles
        .where((profile) => profile.settings.activeTimeSchemeId == schemeId)
        .map((profile) => profile.name)
        .toList(growable: false);
    final references = provider.getTimeSchemeCourseUsages(schemeId);
    final overrideReferences =
        references.where((item) => item.usesOverride).toList(growable: false);
    final previewText = references.isEmpty
        ? null
        : references.length == 1
            ? _formatUsageReference(references.first)
            : '${_formatUsageReference(references.first)} 等 ${references.length} 节课程';
    return _TimeSchemeUsageSummary(
      profileNames: profileNames,
      courseReferences: references,
      overrideReferences: overrideReferences,
      previewText: previewText,
    );
  }

  String _formatUsageReference(TimeSchemeCourseUsageReference reference) {
    final course = reference.course;
    final usageType = reference.usesOverride ? '副时间表' : '主时间表';
    return '${reference.profileName} · ${course.name}'
        '（周${_weekdayLabel(course.dayOfWeek)} ${course.startSection}-${course.endSection}节，$usageType）';
  }

  String _weekdayLabel(int dayOfWeek) {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    if (dayOfWeek < 1 || dayOfWeek > 7) {
      return dayOfWeek.toString();
    }
    return labels[dayOfWeek - 1];
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

class _TimeSchemeUsageSummary {
  final List<String> profileNames;
  final List<TimeSchemeCourseUsageReference> courseReferences;
  final List<TimeSchemeCourseUsageReference> overrideReferences;
  final String? previewText;

  const _TimeSchemeUsageSummary({
    required this.profileNames,
    required this.courseReferences,
    required this.overrideReferences,
    required this.previewText,
  });

  int get profileCount => profileNames.length;
  int get courseCount => courseReferences.length;
  int get overrideCourseCount => overrideReferences.length;
  List<TimeSchemeCourseUsageReference> get directCourseReferences =>
      courseReferences.where((item) => !item.usesOverride).toList(growable: false);
  bool get isUnused => profileCount == 0 && courseCount == 0;
}

class _UsageSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<_UsageLine> items;
  final String emptyText;

  const _UsageSection({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(
              emptyText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...items.map((item) => item),
        ],
      ),
    );
  }
}

class _UsageLine extends StatelessWidget {
  final String primary;
  final String? secondary;

  const _UsageLine({
    required this.primary,
    this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(primary, style: theme.textTheme.bodyMedium),
                if (secondary != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    secondary!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeSchemeInfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _TimeSchemeInfoChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: theme.textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TimeSchemeBadge extends StatelessWidget {
  final String text;
  final IconData icon;

  const _TimeSchemeBadge({
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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
        .where(
            (item) => item.afterSection > 0 && item.breakDurationMinutes >= 0)
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
