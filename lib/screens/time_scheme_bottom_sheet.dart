import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../models/time_scheme.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../utils/app_toast.dart';
import '../widgets/settings_section_widgets.dart';

Future<void> showTimeSchemeBottomSheet(
  BuildContext context, {
  String? initialEditSchemeId,
}) async {
  await showFSheet<void>(
    context: context,
    side: FLayout.btt,
    useSafeArea: true,
    draggable: true,
    mainAxisMaxRatio: 0.88,
    builder: (_) =>
        _TimeSchemeBottomSheet(initialEditSchemeId: initialEditSchemeId),
  );
}

class _TimeSchemeBottomSheet extends StatefulWidget {
  final String? initialEditSchemeId;

  const _TimeSchemeBottomSheet({this.initialEditSchemeId});

  @override
  State<_TimeSchemeBottomSheet> createState() => _TimeSchemeBottomSheetState();
}

class _TimeSchemeBottomSheetState extends State<_TimeSchemeBottomSheet> {
  String? _editingSchemeId;
  TextEditingController? _nameController;
  List<SectionTime> _sections = [];
  Timer? _autoSaveTimer;
  Future<void> _saveQueue = Future<void>.value();
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
    _autoSaveTimer?.cancel();
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
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TimetableProvider>();
    final schemes = provider.timeSchemes;
    final currentSchemeId = provider.activeTimeScheme?.id;
    final activeSchemeName = provider.activeTimeScheme?.name ?? l10n.unsetLabel;
    final theme = context.theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FCard.raw(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.timeSchemeTitle,
                        style: theme.typography.body.md.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _TimeSchemeInfoChip(
                            label: l10n.schemeListCurrentLabel,
                            value: activeSchemeName,
                          ),
                          _TimeSchemeInfoChip(
                            label: l10n.schemeListCountLabel,
                            value: l10n.timeSchemeSetCountValue(schemes.length),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FButton(
                  variant: FButtonVariant.secondary,
                  onPress: _createScheme,
                  prefix: const Icon(Icons.add_rounded),
                  child: Text(l10n.createAction),
                ),
              ],
            ),
          ),
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

              return _buildSchemeCard(
                context,
                scheme: scheme,
                usage: usage,
                isCurrent: isCurrent,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEditor(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TimetableProvider>();
    final schemeId = _editingSchemeId!;
    final scheme = provider.timeSchemes.firstWhere(
      (item) => item.id == schemeId,
    );
    final isActive = provider.activeTimeScheme?.id == schemeId;
    final usage = _buildUsageInfo(provider, schemeId);
    final theme = context.theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: _stopEditing,
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: l10n.backToSchemeList,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                l10n.editTimeSchemeTitle,
                style: theme.typography.body.md.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: [
              SettingsSectionCard(
                title: l10n.timeSchemeNameLabel,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
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
                          value: l10n.profileCountValue(usage.profileCount),
                        ),
                        _TimeSchemeInfoChip(
                          label: l10n.courseCountLabel,
                          value: l10n.courseSectionCountValue(
                            usage.courseCount,
                          ),
                        ),
                      ],
                    ),
                    if (isActive || usage.courseCount > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        isActive && usage.courseCount > 0
                            ? l10n.timeSchemeEditorActiveAndCoursesHint
                            : isActive
                            ? l10n.timeSchemeEditorActiveHint
                            : l10n.timeSchemeEditorOverrideHint,
                        style: theme.typography.body.xs,
                      ),
                    ],
                    if (usage.courseReferencePreview != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        usage.courseReferencePreview!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.body.xs,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SettingsSectionCard(
                title: l10n.sectionTimesTitle,
                subtitle: l10n.sectionTimesSubtitle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FButton(
                          variant: FButtonVariant.secondary,
                          onPress: _openQuickGenerate,
                          prefix: const Icon(Icons.auto_fix_high_rounded),
                          child: Text(l10n.quickGenerateAction),
                        ),
                        FButton(
                          variant: FButtonVariant.secondary,
                          onPress: _sections.length >= 20 ? () {} : _addSection,
                          prefix: const Icon(Icons.add),
                          child: Text(l10n.addSectionAction),
                        ),
                        FButton(
                          variant: FButtonVariant.secondary,
                          onPress: _sections.length <= 1
                              ? () {}
                              : _removeSection,
                          prefix: const Icon(Icons.remove),
                          child: Text(l10n.removeLastSectionAction),
                        ),
                        FButton(
                          variant: FButtonVariant.secondary,
                          onPress: _resetSections,
                          prefix: const Icon(Icons.restart_alt),
                          child: Text(l10n.resetDefaultAction),
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
                          color: theme.colors.muted,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.colors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: theme.colors.primary.withValues(
                                  alpha: 0.10,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${index + 1}',
                                style: theme.typography.body.sm.copyWith(
                                  color: theme.colors.primary,
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
                                    l10n.sectionLabel(index + 1),
                                    style: theme.typography.body.sm.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${section.startTime} - ${section.endTime}',
                                    style: theme.typography.body.sm.copyWith(
                                      color: theme.colors.mutedForeground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: l10n.editTimeAction,
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
              const SizedBox(height: 8),
              Text(
                l10n.editingSchemeLabel(scheme.name),
                style: theme.typography.body.xs,
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
    final l10n = AppLocalizations.of(context)!;
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
        showAppToast(
          this.context,
          message: l10n.copiedTimeSchemeShortMessage,
          kind: AppToastKind.success,
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
    final scheme = provider.timeSchemes.firstWhere(
      (item) => item.id == schemeId,
    );
    _nameController?.dispose();
    _nameController = TextEditingController(text: scheme.name)
      ..addListener(_scheduleAutoSave);
    setState(() {
      _editingSchemeId = schemeId;
      _sections = List<SectionTime>.from(scheme.sections);
    });
  }

  void _stopEditing() {
    _autoSaveTimer?.cancel();
    _nameController?.dispose();
    _nameController = null;
    setState(() {
      _editingSchemeId = null;
      _sections = [];
    });
  }

  Future<void> _applyScheme(String schemeId) async {
    final l10n = AppLocalizations.of(context)!;
    await context.read<TimetableProvider>().applyTimeScheme(schemeId);
    if (!mounted) {
      return;
    }
    final nextScheme = context.read<TimetableProvider>().activeTimeScheme;
    Navigator.of(context).pop();
    showAppToast(
      context,
      message: l10n.appliedTimeSchemeMessage(
        nextScheme?.name ?? l10n.unnamedTimeScheme,
      ),
      kind: AppToastKind.success,
    );
  }

  Future<void> _createScheme() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final name = await showFDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (ctx, style, animation) => FDialog(
        title: Text(l10n.createTimeSchemeTitle),
        body: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.timeSchemeNameLabel,
            hintText: l10n.timeSchemeNameHint,
          ),
        ),
        actions: [
          FButton(
            variant: FButtonVariant.ghost,
            onPress: () => Navigator.pop(ctx),
            child: Text(l10n.cancelAction),
          ),
          FButton(
            variant: FButtonVariant.primary,
            onPress: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.createAction),
          ),
        ],
      ),
    );
    controller.dispose();

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
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: scheme.name);
    final name = await showFDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (ctx, style, animation) => FDialog(
        title: Text(l10n.renameTimeSchemeTitle),
        body: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.timeSchemeNameLabel),
        ),
        actions: [
          FButton(
            variant: FButtonVariant.ghost,
            onPress: () => Navigator.pop(ctx),
            child: Text(l10n.cancelAction),
          ),
          FButton(
            variant: FButtonVariant.primary,
            onPress: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.saveAction),
          ),
        ],
      ),
    );
    controller.dispose();

    if (!mounted || name == null || name.isEmpty || name == scheme.name) {
      return;
    }

    await context.read<TimetableProvider>().renameTimeScheme(scheme.id, name);
    if (!mounted) {
      return;
    }
    showAppToast(
      context,
      message: l10n.renamedToMessage(name),
      kind: AppToastKind.success,
    );
  }

  Future<void> _deleteScheme(TimeScheme scheme) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showFDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx, style, animation) => FDialog(
        title: Text(l10n.deleteTimeSchemeTitle),
        body: Text(l10n.deleteTimeSchemeMessage(scheme.name)),
        actions: [
          FButton(
            variant: FButtonVariant.ghost,
            onPress: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancelAction),
          ),
          FButton(
            variant: FButtonVariant.primary,
            onPress: () => Navigator.pop(ctx, true),
            child: Text(l10n.deleteAction),
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
    showAppToast(
      context,
      message: deleted
          ? l10n.deletedTimeSchemeMessage(scheme.name)
          : l10n.timeSchemeInUseMessage,
      kind: deleted ? AppToastKind.success : AppToastKind.warning,
    );
  }

  Future<void> _showUsageDetails(
    TimeScheme scheme,
    _TimeSchemeUsageInfo usage,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    await showFDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx, style, animation) => FDialog(
        title: Text(l10n.timeSchemeUsageTitle(scheme.name)),
        body: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${l10n.profileCountLabel}：${l10n.profileCountValue(usage.profileCount)}',
                ),
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
                Text(
                  '${l10n.courseCountLabel}：${l10n.courseSectionCountValue(usage.courseCount)}',
                ),
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
          FButton(
            variant: FButtonVariant.ghost,
            onPress: () => Navigator.pop(ctx),
            child: Text(l10n.closeAction),
          ),
        ],
      ),
    );
  }

  _TimeSchemeUsageInfo _buildUsageInfo(
    TimetableProvider provider,
    String schemeId,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final profileNames = <String>[];
    final courseReferences = <String>[];
    final usages = provider.getTimeSchemeCourseUsages(schemeId);

    for (final profile in provider.profiles) {
      if (profile.settings.activeTimeSchemeId == schemeId) {
        profileNames.add(profile.name);
      }
    }

    for (final usage in usages) {
      final course = usage.course;
      final usageType = usage.usesOverride
          ? l10n.overrideTimeSchemeShortLabel
          : l10n.mainTimeSchemeLabel;
      courseReferences.add(
        l10n.timeSchemeUsageReference(
          usage.profileName,
          course.name,
          _weekdayLabel(context, course.dayOfWeek),
          course.startSection,
          course.endSection,
          usageType,
        ),
      );
    }

    final previewText = courseReferences.isEmpty
        ? null
        : courseReferences.length == 1
        ? l10n.timeSchemeUsageCourseRefPrefix + courseReferences.first
        : l10n.timeSchemeUsageCourseRefPrefix +
              l10n.timeSchemeBottomUsageMulti(
                courseReferences.take(2).join('；'),
                courseReferences.length,
              );

    return _TimeSchemeUsageInfo(
      profileNames: profileNames,
      courseReferences: courseReferences,
      courseReferencePreview: previewText,
    );
  }

  Widget _buildSchemeCard(
    BuildContext context, {
    required TimeScheme scheme,
    required _TimeSchemeUsageInfo usage,
    required bool isCurrent,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return FTileGroup(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        FTile(
          prefix: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color:
                  (isCurrent
                          ? colorScheme.primary
                          : colorScheme.secondaryContainer)
                      .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isCurrent ? Icons.schedule_rounded : Icons.access_time_rounded,
              color: isCurrent
                  ? colorScheme.primary
                  : colorScheme.onSecondaryContainer,
            ),
          ),
          title: Text(
            scheme.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (isCurrent)
                    _TimeSchemeBadge(
                      text: AppLocalizations.of(context)!.currentInUse,
                      icon: Icons.check_circle_outline_rounded,
                    ),
                  _TimeSchemeInfoChip(
                    label: AppLocalizations.of(context)!.sectionCountLabel,
                    value: AppLocalizations.of(
                      context,
                    )!.courseSectionCountValue(scheme.sectionCount),
                  ),
                  _TimeSchemeInfoChip(
                    label: AppLocalizations.of(context)!.profileCountLabel,
                    value: l10n.profileCountValue(usage.profileCount),
                  ),
                  _TimeSchemeInfoChip(
                    label: AppLocalizations.of(context)!.courseCountLabel,
                    value: l10n.courseSectionCountValue(usage.courseCount),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                scheme.sectionCount > 1
                    ? AppLocalizations.of(
                        context,
                      )!.timeSchemeStartsAt(scheme.sections.first.displayText)
                    : scheme.sections.first.displayText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (usage.courseReferencePreview != null) ...[
                const SizedBox(height: 6),
                Text(
                  usage.courseReferencePreview!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          suffix: PopupMenuButton<String>(
            onSelected: (value) =>
                _handleSchemeMenu(context, scheme, usage, value),
            itemBuilder: (context) => [
              if (!usage.isUnused)
                PopupMenuItem(
                  value: 'usage',
                  child: Text(AppLocalizations.of(context)!.viewUsageAction),
                ),
              if (!isCurrent)
                PopupMenuItem(
                  value: 'apply',
                  child: Text(
                    AppLocalizations.of(context)!.applyToCurrentTimetable,
                  ),
                ),
              PopupMenuItem(
                value: 'edit',
                child: Text(AppLocalizations.of(context)!.editSectionsAction),
              ),
              PopupMenuItem(
                value: 'rename',
                child: Text(AppLocalizations.of(context)!.renameAction),
              ),
              PopupMenuItem(
                value: 'duplicate',
                child: Text(AppLocalizations.of(context)!.duplicateAction),
              ),
              PopupMenuItem(
                value: 'delete',
                enabled: usage.isUnused,
                child: Text(AppLocalizations.of(context)!.deleteAction),
              ),
            ],
          ),
          onPress: isCurrent ? null : () => _applyScheme(scheme.id),
        ),
      ],
    );
  }

  String _weekdayLabel(BuildContext context, int dayOfWeek) {
    final l10n = AppLocalizations.of(context)!;
    switch (dayOfWeek) {
      case 1:
        return l10n.weekdayShortMonday;
      case 2:
        return l10n.weekdayShortTuesday;
      case 3:
        return l10n.weekdayShortWednesday;
      case 4:
        return l10n.weekdayShortThursday;
      case 5:
        return l10n.weekdayShortFriday;
      case 6:
        return l10n.weekdayShortSaturday;
      case 7:
        return l10n.weekdayShortSunday;
      default:
        return dayOfWeek.toString();
    }
  }

  Future<void> _editSectionTime(int index) async {
    final start = await showTimePicker(
      context: context,
      useRootNavigator: true,
      initialTime: _parseTimeOfDay(_sections[index].startTime),
    );
    if (start == null || !mounted) {
      return;
    }

    final end = await showTimePicker(
      context: context,
      useRootNavigator: true,
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
      final l10n = AppLocalizations.of(context)!;
      showAppToast(
        context,
        message: l10n.timeRangeValidationNoCrossDay,
        kind: AppToastKind.warning,
      );
      return;
    }

    final nextSections = List<SectionTime>.from(_sections);
    nextSections[index] = editedSection;
    final validationMessage = validateSectionTimes(nextSections);
    if (validationMessage != null) {
      showAppToast(
        context,
        message: validationMessage,
        kind: AppToastKind.warning,
      );
      return;
    }

    setState(() {
      _sections[index] = editedSection;
    });
    _scheduleAutoSave();
  }

  void _addSection() {
    setState(() {
      _sections.add(_buildNextSection(_sections.last));
    });
    _scheduleAutoSave();
  }

  void _removeSection() {
    setState(() {
      _sections.removeLast();
    });
    _scheduleAutoSave();
  }

  void _resetSections() {
    setState(() {
      _sections = List<SectionTime>.from(TimetableSettings.defaults().sections);
    });
    _scheduleAutoSave();
  }

  Future<void> _openQuickGenerate() async {
    final preset = await showFDialog<_QuickGeneratePreset>(
      context: context,
      useRootNavigator: true,
      builder: (ctx, style, animation) =>
          _QuickGenerateDialog(initialPreset: _lastQuickGeneratePreset),
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
      _scheduleAutoSave();
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      showAppToast(context, message: error.message, kind: AppToastKind.error);
    }
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(
      const Duration(milliseconds: 300),
      _enqueuePersistEditingScheme,
    );
  }

  void _enqueuePersistEditingScheme() {
    _saveQueue = _saveQueue
        .catchError((_) {})
        .then((_) => _persistEditingScheme());
  }

  Future<void> _persistEditingScheme() async {
    final schemeId = _editingSchemeId;
    if (schemeId == null || _nameController == null) {
      return;
    }
    final trimmedName = _nameController!.text.trim();
    if (trimmedName.isEmpty) {
      final provider = context.read<TimetableProvider>();
      final scheme = provider.timeSchemes.firstWhere(
        (item) => item.id == schemeId,
      );
      _nameController!
        ..removeListener(_scheduleAutoSave)
        ..text = scheme.name
        ..selection = TextSelection.collapsed(offset: scheme.name.length)
        ..addListener(_scheduleAutoSave);
      final l10n = AppLocalizations.of(context)!;
      showAppToast(
        context,
        message: l10n.timeSchemeNameEmptyValidation,
        kind: AppToastKind.warning,
      );
      return;
    }
    final provider = context.read<TimetableProvider>();
    final message = await context.read<TimetableProvider>().updateTimeScheme(
      schemeId: schemeId,
      name: trimmedName,
      sections: _sections,
    );
    if (!mounted) {
      return;
    }
    if (message != null) {
      final scheme = provider.timeSchemes.firstWhere(
        (item) => item.id == schemeId,
      );
      _nameController!
        ..removeListener(_scheduleAutoSave)
        ..text = scheme.name
        ..selection = TextSelection.collapsed(offset: scheme.name.length)
        ..addListener(_scheduleAutoSave);
      setState(() {
        _sections = List<SectionTime>.from(scheme.sections);
      });
      showAppToast(context, message: message);
      return;
    }
  }
}

TimeOfDay _parseTimeOfDay(String value) {
  final parts = value.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
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
  final String? courseReferencePreview;

  const _TimeSchemeUsageInfo({
    required this.profileNames,
    required this.courseReferences,
    this.courseReferencePreview,
  });

  int get profileCount => profileNames.length;
  int get courseCount => courseReferences.length;
  bool get isUnused => profileCount == 0 && courseCount == 0;
}

class _TimeSchemeInfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _TimeSchemeInfoChip({required this.label, required this.value});

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

  const _TimeSchemeBadge({required this.text, required this.icon});

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

class _QuickGenerateDialog extends StatefulWidget {
  final _QuickGeneratePreset initialPreset;

  const _QuickGenerateDialog({required this.initialPreset});

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
    _morningCountController = TextEditingController(
      text: '${preset.morningCount}',
    );
    _afternoonCountController = TextEditingController(
      text: '${preset.afternoonCount}',
    );
    _eveningCountController = TextEditingController(
      text: '${preset.eveningCount}',
    );
    _classDurationController = TextEditingController(
      text: '${preset.classDurationMinutes}',
    );
    _breakDurationController = TextEditingController(
      text: '${preset.breakDurationMinutes}',
    );
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
    final l10n = AppLocalizations.of(context)!;
    final theme = context.theme;
    return FDialog(
      title: Text(l10n.quickGenerateTimeSchemeTitle),
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNumberField(
              _morningCountController,
              l10n.morningSectionCountLabel,
            ),
            const SizedBox(height: 12),
            _buildTimeTile(
              label: l10n.morningFirstSectionTimeLabel,
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
            _buildNumberField(
              _afternoonCountController,
              l10n.afternoonSectionCountLabel,
            ),
            const SizedBox(height: 12),
            _buildTimeTile(
              label: l10n.afternoonFirstSectionTimeLabel,
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
            _buildNumberField(
              _eveningCountController,
              l10n.eveningSectionCountLabel,
            ),
            const SizedBox(height: 12),
            _buildTimeTile(
              label: l10n.eveningFirstSectionTimeLabel,
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
            _buildNumberField(
              _classDurationController,
              l10n.classDurationMinutesLabel,
            ),
            const SizedBox(height: 12),
            _buildNumberField(
              _breakDurationController,
              l10n.smallBreakDurationMinutesLabel,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.largeBreakRulesTitle,
                style: theme.typography.body.sm.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ..._buildBreakOverrideRows(),
            Align(
              alignment: Alignment.centerLeft,
              child: FButton(
                variant: FButtonVariant.ghost,
                onPress: _addBreakOverride,
                prefix: const Icon(Icons.add_rounded),
                child: Text(l10n.addBreakRuleAction),
              ),
            ),
          ],
        ),
      ),
      actions: [
        FButton(
          variant: FButtonVariant.ghost,
          onPress: () => Navigator.pop(context),
          child: Text(l10n.cancelAction),
        ),
        FButton(
          variant: FButtonVariant.primary,
          onPress: _submit,
          child: Text(l10n.generateAction),
        ),
      ],
    );
  }

  Widget _buildNumberField(TextEditingController controller, String label) {
    final theme = context.theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.typography.body.sm.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
      ],
    );
  }

  Widget _buildTimeTile({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return FTile(
      title: Text(label),
      details: Text(value),
      suffix: const Icon(Icons.schedule_outlined),
      onPress: onTap,
    );
  }

  List<Widget> _buildBreakOverrideRows() {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.theme;
    if (_breakOverrides.isEmpty) {
      return [
        Text(l10n.noLargeBreakRulesHint, style: theme.typography.body.xs),
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
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: l10n.afterSectionLabel,
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
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: l10n.breakDurationMinutesLabel,
                ),
                onChanged: (value) {
                  item.breakDurationMinutes = int.tryParse(value) ?? 0;
                },
              ),
            ),
            IconButton(
              tooltip: l10n.deleteRuleTooltip,
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
    final l10n = AppLocalizations.of(context)!;
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
      showAppToast(
        context,
        message: l10n.fillNumbersValidationMessage,
        kind: AppToastKind.warning,
      );
      return;
    }

    final breakOverrideRules = _breakOverrides
        .where(
          (item) => item.afterSection > 0 && item.breakDurationMinutes >= 0,
        )
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
