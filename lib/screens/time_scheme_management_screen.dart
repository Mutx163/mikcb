import 'package:flutter/material.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/service_message_localizer.dart';
import 'package:provider/provider.dart';

import '../models/schedule_date_rule.dart';
import '../models/time_scheme.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../utils/app_toast.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/time_scheme_quick_generate_sheet.dart';
import 'location_time_match_screen.dart';

class TimeSchemeManagementScreen extends StatefulWidget {
  final String? initialEditSchemeId;
  final bool openCreateOnOpen;

  const TimeSchemeManagementScreen({
    super.key,
    this.initialEditSchemeId,
    this.openCreateOnOpen = false,
  });

  @override
  State<TimeSchemeManagementScreen> createState() =>
      _TimeSchemeManagementScreenState();
}

class _TimeSchemeManagementScreenState
    extends State<TimeSchemeManagementScreen> {
  bool _didOpenInitialAction = false;

  /// Stable menu anchors per scheme card (must not be recreated each build).
  final Map<String, GlobalKey> _schemeMenuAnchorKeys = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didOpenInitialAction) {
      return;
    }
    final editId = widget.initialEditSchemeId;
    final openCreate = widget.openCreateOnOpen;
    if (editId == null && !openCreate) {
      return;
    }
    _didOpenInitialAction = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (editId != null) {
        _openEditor(editId);
      } else {
        _createScheme(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        final schemes = provider.timeSchemes;
        final activeSchemeId = provider.activeTimeScheme?.id;
        final dateRules = provider.scheduleDateRules;
        final activeDateRule = provider.matchScheduleDateRule(DateTime.now());

        return HyperosSubpage(
          onBack: () => Navigator.pop(context),
          title: Text(l10n.timeSchemeTitle),
          suffixes: [
            FHeaderAction(
              icon: const Icon(Icons.add_rounded),
              semanticsLabel: l10n.newSchemeTooltip,
              onPress: () => _createScheme(context),
            ),
          ],
          child: HyperosListView(
            children: [
              HyperosListGroup(
                children: [
                  HyperosListTile(
                    icon: Icons.place_outlined,
                    iconAccent: HyperosIconColors.orange,
                    title: l10n.locationTimeMatchEntryTitle,
                    details: provider.locationTimeGroups.isEmpty
                        ? null
                        : '${provider.locationTimeGroups.length}',
                    onTap: () {
                      Navigator.push(
                        context,
                        HyperosPageRoute(
                          builder: (_) => const LocationTimeMatchScreen(),
                        ),
                      );
                    },
                  ),
                  HyperosListTile(
                    icon: Icons.event_available_outlined,
                    iconAccent: HyperosIconColors.teal,
                    title: l10n.scheduleDateRuleSectionTitle,
                    details: dateRules.isEmpty
                        ? null
                        : activeDateRule == null
                        ? '${dateRules.length}'
                        : l10n.scheduleDateRuleActiveToday,
                    onTap: () =>
                        _openScheduleDateRuleEditor(context, existing: null),
                  ),
                ],
              ),
              const HyperosSectionGap(),
              HyperosSectionLabel(text: l10n.scheduleDateRuleSectionTitle),
              if (dateRules.isEmpty)
                HyperosListGroup(
                  children: [
                    HyperosNavTile(
                      title: l10n.scheduleDateRuleEmpty,
                      enabled: false,
                      showChevron: false,
                    ),
                  ],
                )
              else ...[
                for (var index = 0; index < dateRules.length; index++) ...[
                  if (index > 0) const HyperosSectionGap(),
                  _buildDateRuleCard(
                    context,
                    provider,
                    dateRules[index],
                    isActiveToday: activeDateRule?.id == dateRules[index].id,
                  ),
                ],
              ],
              HyperosSectionDescription(
                text: l10n.scheduleDateRuleSectionSubtitle,
              ),
              HyperosSectionDescription(text: l10n.scheduleDateRuleNote),
              const HyperosSectionGap(),
              HyperosSectionLabel(text: l10n.timeSchemeEntryTitle),
              if (schemes.isEmpty)
                HyperosListGroup(
                  children: [
                    HyperosNavTile(
                      title: l10n.locationTimeMatchNeedTimeScheme,
                      enabled: false,
                      showChevron: false,
                    ),
                  ],
                )
              else ...[
                for (var index = 0; index < schemes.length; index++) ...[
                  if (index > 0) const HyperosSectionGap(),
                  _buildSchemeCard(
                    context,
                    scheme: schemes[index],
                    usage: _buildUsageSummary(provider, schemes[index].id),
                    isActive: schemes[index].id == activeSchemeId,
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateRuleCard(
    BuildContext context,
    TimetableProvider provider,
    ScheduleDateRule rule, {
    required bool isActiveToday,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final schemeName =
        provider.timeSchemes
            .where((scheme) => scheme.id == rule.timeSchemeId)
            .map((scheme) => scheme.name)
            .firstOrNull ??
        l10n.locationTimeMatchUnknownScheme;

    return HyperosControlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(rule.name, style: HyperosTypography.listTitle(context)),
          const SizedBox(height: 4),
          Text(
            l10n.scheduleDateRuleRangeSummary(rule.startDate, rule.endDate),
            style: HyperosTypography.listDetail(context),
          ),
          const SizedBox(height: 2),
          Text(schemeName, style: HyperosTypography.listDetail(context)),
          if (isActiveToday) ...[
            const SizedBox(height: 4),
            Text(
              l10n.scheduleDateRuleActiveToday,
              style: HyperosTypography.listDetail(
                context,
              ).copyWith(color: HyperosColors.primary(context)),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: HyperosButton(
                  label: l10n.editAction,
                  variant: HyperosButtonVariant.secondary,
                  expand: true,
                  onPressed: () =>
                      _openScheduleDateRuleEditor(context, existing: rule),
                ),
              ),
              const SizedBox(width: 8),
              HyperosButton(
                label: l10n.deleteAction,
                variant: HyperosButtonVariant.secondary,
                onPressed: () => _deleteScheduleDateRule(context, rule),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _localizeScheduleDateRuleError(AppLocalizations l10n, String code) {
    return switch (code) {
      'schedule_date_rule_max_exceeded' => l10n.scheduleDateRuleErrorMax,
      'schedule_date_rule_overlap' => l10n.scheduleDateRuleErrorOverlap,
      'schedule_date_rule_invalid_date' =>
        l10n.scheduleDateRuleErrorInvalidDate,
      'schedule_date_rule_end_before_start' =>
        l10n.scheduleDateRuleErrorEndBeforeStart,
      'schedule_date_rule_scheme_required' =>
        l10n.scheduleDateRuleErrorSchemeRequired,
      'schedule_date_rule_name_required' =>
        l10n.scheduleDateRuleErrorNameRequired,
      'time_scheme_not_found' => l10n.serviceMsgTimeSchemeNotFound,
      _ => code,
    };
  }

  Future<void> _openScheduleDateRuleEditor(
    BuildContext context, {
    required ScheduleDateRule? existing,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<TimetableProvider>();
    if (provider.timeSchemes.isEmpty) {
      showAppToast(
        context,
        message: l10n.scheduleDateRuleNeedScheme,
        kind: AppToastKind.warning,
      );
      return;
    }
    if (existing == null &&
        provider.scheduleDateRules.length >=
            ScheduleDateRuleLogic.maxRulesPerDevice) {
      showAppToast(
        context,
        message: l10n.scheduleDateRuleMaxReached,
        kind: AppToastKind.warning,
      );
      return;
    }

    var nameDraft = existing?.name ?? '';
    var startDate =
        ScheduleDateRuleLogic.parseIsoDate(existing?.startDate) ??
        DateTime.now();
    var endDate =
        ScheduleDateRuleLogic.parseIsoDate(existing?.endDate) ??
        DateTime.now().add(const Duration(days: 90));
    var selectedSchemeId =
        existing?.timeSchemeId ??
        provider.activeTimeScheme?.id ??
        provider.timeSchemes.first.id;
    var enabled = existing?.enabled ?? true;
    const dialogFieldFontSize = 16.0;

    String formatDate(DateTime date) {
      final year = date.year.toString().padLeft(4, '0');
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      return '$year-$month-$day';
    }

    Future<DateTime?> pickDate(
      BuildContext pickerContext, {
      required DateTime initialDate,
      required DateTime firstDate,
    }) {
      return showDatePicker(
        context: pickerContext,
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: DateTime(2040),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.fromSeed(
                seedColor: HyperosColors.primary(context),
                brightness: Theme.of(context).brightness,
              ),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
      );
    }

    final saved = await showHyperosDialog<bool>(
      context: context,
      enableDrag: false,
      maxBodyHeightFactor: 0.65,
      title: existing == null
          ? l10n.scheduleDateRuleAdd
          : l10n.scheduleDateRuleEdit,
      body: StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final schemeItems = _timeSchemeSelectItems(provider.timeSchemes);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DateRuleNameField(
                initialValue: nameDraft,
                label: l10n.scheduleDateRuleNameLabel,
                hint: l10n.scheduleDateRuleNameHint,
                fontSize: dialogFieldFontSize,
                onChanged: (value) => nameDraft = value,
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final startField = HyperosPickerField(
                    label: l10n.scheduleDateRuleStartDate,
                    value: formatDate(startDate),
                    fontSize: dialogFieldFontSize,
                    onTap: () async {
                      FocusManager.instance.primaryFocus?.unfocus();
                      final picked = await pickDate(
                        dialogContext,
                        initialDate: startDate,
                        firstDate: DateTime(2020),
                      );
                      if (picked == null) return;
                      setDialogState(() {
                        startDate = picked;
                        if (endDate.isBefore(startDate)) {
                          endDate = startDate;
                        }
                      });
                    },
                  );
                  final endField = HyperosPickerField(
                    label: l10n.scheduleDateRuleEndDate,
                    value: formatDate(endDate),
                    fontSize: dialogFieldFontSize,
                    onTap: () async {
                      FocusManager.instance.primaryFocus?.unfocus();
                      final picked = await pickDate(
                        dialogContext,
                        initialDate: endDate,
                        firstDate: startDate,
                      );
                      if (picked != null) {
                        setDialogState(() => endDate = picked);
                      }
                    },
                  );
                  if (constraints.maxWidth < 300) {
                    return Column(
                      children: [
                        startField,
                        const SizedBox(height: 12),
                        endField,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: startField),
                      const SizedBox(width: 12),
                      Expanded(child: endField),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              HyperosPickerField(
                label: l10n.scheduleDateRuleBoundScheme,
                value:
                    hyperosSelectLabelFor(schemeItems, selectedSchemeId) ??
                    selectedSchemeId,
                fontSize: dialogFieldFontSize,
                icon: Icons.schedule_outlined,
                onTap: () async {
                  final value = await showHyperosSelectSheet<String>(
                    context: dialogContext,
                    title: l10n.scheduleDateRuleBoundScheme,
                    items: schemeItems,
                    currentValue: selectedSchemeId,
                    cancelLabel: MaterialLocalizations.of(
                      dialogContext,
                    ).cancelButtonLabel,
                  );
                  if (value != null) {
                    setDialogState(() => selectedSchemeId = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              _DateRuleSwitchField(
                label: l10n.scheduleDateRuleEnabled,
                value: enabled,
                fontSize: dialogFieldFontSize,
                onChanged: (value) => setDialogState(() => enabled = value),
              ),
            ],
          );
        },
      ),
      actions: [
        HyperosDialogAction(
          label: l10n.cancelAction,
          onPressed: () => Navigator.pop(context, false),
        ),
        HyperosDialogAction(
          label: l10n.saveAction,
          isPrimary: true,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );

    if (saved != true || !context.mounted) {
      return;
    }
    final name = nameDraft.trim();
    if (name.isEmpty) {
      showAppToast(
        context,
        message: l10n.scheduleDateRuleNameRequired,
        kind: AppToastKind.warning,
      );
      return;
    }

    try {
      late final ScheduleDateRuleSaveResult saveResult;
      if (existing == null) {
        saveResult = await provider.createScheduleDateRule(
          name: name,
          timeSchemeId: selectedSchemeId,
          startDate: ScheduleDateRuleLogic.formatIsoDate(startDate),
          endDate: ScheduleDateRuleLogic.formatIsoDate(endDate),
          enabled: enabled,
        );
      } else {
        saveResult = (await provider.updateScheduleDateRule(
          existing.copyWith(
            name: name,
            timeSchemeId: selectedSchemeId,
            startDate: ScheduleDateRuleLogic.formatIsoDate(startDate),
            endDate: ScheduleDateRuleLogic.formatIsoDate(endDate),
            enabled: enabled,
          ),
        ))!;
      }
      if (!context.mounted) {
        return;
      }
      final savedRule = saveResult.rule;
      final willApplyLater =
          savedRule.enabled &&
          ScheduleDateRuleLogic.dateOnly(
            DateTime.now(),
          ).isBefore(ScheduleDateRuleLogic.dateOnly(startDate));
      showAppToast(
        context,
        message: saveResult.failedWhileDue
            ? l10n.scheduleDateRuleSavedButApplyFailed
            : saveResult.didApply
            ? l10n.scheduleDateRuleSavedAndApplied
            : willApplyLater
            ? l10n.scheduleDateRuleSavedForFuture
            : l10n.scheduleDateRuleSaved,
        kind: saveResult.failedWhileDue
            ? AppToastKind.warning
            : AppToastKind.success,
      );
    } on ArgumentError catch (error) {
      if (!context.mounted) {
        return;
      }
      showAppToast(
        context,
        message: l10n.scheduleDateRuleSaveFailed(
          _localizeScheduleDateRuleError(l10n, error.message.toString()),
        ),
        kind: AppToastKind.error,
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      showAppToast(
        context,
        message: l10n.scheduleDateRuleSaveFailed(
          l10n.locationTimeMatchSaveFailed,
        ),
        kind: AppToastKind.error,
      );
    }
  }

  Future<void> _deleteScheduleDateRule(
    BuildContext context,
    ScheduleDateRule rule,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.scheduleDateRuleDeleteTitle,
      message: l10n.scheduleDateRuleDeleteMessage(rule.name),
      confirmLabel: l10n.deleteAction,
      destructiveConfirm: true,
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    await context.read<TimetableProvider>().deleteScheduleDateRule(rule.id);
    if (!context.mounted) {
      return;
    }
    showAppToast(
      context,
      message: l10n.scheduleDateRuleDeleted,
      kind: AppToastKind.success,
    );
  }

  Widget _buildSchemeCard(
    BuildContext context, {
    required TimeScheme scheme,
    required _TimeSchemeUsageSummary usage,
    required bool isActive,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final menuAnchorKey = _schemeMenuAnchorKeys.putIfAbsent(
      scheme.id,
      GlobalKey.new,
    );
    return HyperosControlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              HyperosIconBadge(
                icon: isActive
                    ? Icons.schedule_rounded
                    : Icons.access_time_rounded,
                accent: isActive
                    ? HyperosIconColors.teal
                    : HyperosIconColors.blue,
              ),
              const SizedBox(width: HyperosTokens.rowContentGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scheme.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HyperosTypography.listTitle(context),
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
                      style: HyperosTypography.listDetail(context),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: menuAnchorKey,
                tooltip: l10n.moreActionsTooltip,
                onPressed: () async {
                  final value = await showHyperosListPopup<String>(
                    context: context,
                    position: hyperosPopupPositionBelow(context, menuAnchorKey),
                    items: [
                      if (!usage.isUnused)
                        HyperosPopupMenuItem(
                          label: l10n.viewUsageAction,
                          value: 'usage',
                        ),
                      if (!isActive)
                        HyperosPopupMenuItem(
                          label: l10n.applyToCurrentTimetable,
                          value: 'apply',
                        ),
                      HyperosPopupMenuItem(
                        label: l10n.editSectionsAction,
                        value: 'edit',
                      ),
                      HyperosPopupMenuItem(
                        label: l10n.renameAction,
                        value: 'rename',
                      ),
                      HyperosPopupMenuItem(
                        label: l10n.duplicateAction,
                        value: 'duplicate',
                      ),
                      HyperosPopupMenuItem(
                        label: l10n.deleteAction,
                        value: 'delete',
                        destructive: true,
                        enabled: usage.isUnused,
                      ),
                    ],
                  );
                  if (!context.mounted || value == null) {
                    return;
                  }
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
                        showAppToast(
                          context,
                          message: l10n.copiedTimeSchemeMessage,
                          kind: AppToastKind.success,
                        );
                      }
                      break;
                    case 'delete':
                      await _deleteScheme(context, scheme);
                      break;
                  }
                },
                icon: const Icon(Icons.more_horiz_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            scheme.sectionCount > 1
                ? l10n.timeSchemeStartsAt(scheme.sections.first.displayText)
                : scheme.sections.first.displayText,
            style: HyperosTypography.listDetail(context),
          ),
          if (isActive) ...[
            const SizedBox(height: 8),
            Text(
              l10n.usingNow,
              style: HyperosTypography.listDetail(
                context,
              ).copyWith(color: HyperosColors.primary(context)),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: HyperosButton(
                  label: isActive
                      ? l10n.usingNow
                      : l10n.applyToCurrentTimetable,
                  variant: HyperosButtonVariant.secondary,
                  expand: true,
                  onPressed: isActive
                      ? null
                      : () => _applyScheme(context, scheme),
                ),
              ),
              const SizedBox(width: 8),
              HyperosButton(
                label: l10n.editSectionsAction,
                variant: HyperosButtonVariant.secondary,
                onPressed: () => _openEditor(scheme.id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(String schemeId) async {
    await Navigator.push(
      context,
      HyperosPageRoute(
        builder: (_) => _TimeSchemeEditorScreen(schemeId: schemeId),
      ),
    );
  }

  Future<void> _createScheme(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await showAppTextInputDialog(
      context,
      title: l10n.createTimeSchemeTitle,
      confirmLabel: l10n.createAction,
      bodyBuilder: (controller) => HyperosTextField(
        controller: controller,
        label: l10n.timeSchemeNameLabel,
        hint: l10n.timeSchemeNameHint,
        autofocus: true,
      ),
      validate: (value) => value.isNotEmpty,
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
    final name = await showAppTextInputDialog(
      context,
      title: l10n.renameTimeSchemeTitle,
      initialValue: scheme.name,
      bodyBuilder: (controller) => HyperosTextField(
        controller: controller,
        label: l10n.timeSchemeNameLabel,
        autofocus: true,
      ),
      validate: (value) => value.isNotEmpty,
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
    showAppToast(
      context,
      message: l10n.renamedToMessage(name),
      kind: AppToastKind.success,
    );
  }

  Future<void> _deleteScheme(BuildContext context, TimeScheme scheme) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showHyperosConfirmDialog(
      context: context,
      title: l10n.deleteTimeSchemeTitle,
      message: l10n.deleteTimeSchemeMessage(scheme.name),
      cancelLabel: l10n.cancelAction,
      confirmLabel: l10n.deleteAction,
      destructive: true,
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
    showAppToast(
      context,
      message: deleted
          ? l10n.deletedTimeSchemeMessage(scheme.name)
          : l10n.timeSchemeInUseMessage,
      kind: deleted ? AppToastKind.success : AppToastKind.warning,
    );
  }

  Future<void> _applyScheme(BuildContext context, TimeScheme scheme) async {
    final l10n = AppLocalizations.of(context)!;
    final error = await context.read<TimetableProvider>().applyTimeScheme(
      scheme.id,
    );
    if (!context.mounted) {
      return;
    }
    if (error != null) {
      showAppToast(
        context,
        message: localizeServiceMessage(l10n, error),
        kind: AppToastKind.warning,
      );
      return;
    }
    showAppToast(
      context,
      message: l10n.appliedTimeSchemeMessage(scheme.name),
      kind: AppToastKind.success,
    );
  }

  _TimeSchemeUsageSummary _buildUsageSummary(
    TimetableProvider provider,
    String schemeId,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final profileNames = provider.profiles
        .where((profile) => profile.settings.activeTimeSchemeId == schemeId)
        .map((profile) => profile.name)
        .toList(growable: false);
    final references = provider.getTimeSchemeCourseUsages(schemeId);
    final overrideReferences = references
        .where((item) => item.usesOverride)
        .toList(growable: false);
    final previewText = references.isEmpty
        ? null
        : references.length == 1
        ? _formatUsageReference(l10n, references.first)
        : l10n.timeSchemeBottomUsageMulti(
            _formatUsageReference(l10n, references.first),
            references.length,
          );
    return _TimeSchemeUsageSummary(
      profileNames: profileNames,
      courseReferences: references,
      overrideReferences: overrideReferences,
      previewText: previewText,
    );
  }

  String _formatUsageReference(
    AppLocalizations l10n,
    TimeSchemeCourseUsageReference reference,
  ) {
    final course = reference.course;
    final usageType = reference.usesOverride
        ? l10n.overrideTimeSchemeShortLabel
        : l10n.mainTimeSchemeLabel;
    return l10n.timeSchemeUsageReference(
      reference.profileName,
      course.name,
      _weekdayLabel(l10n, course.dayOfWeek),
      course.startSection,
      course.endSection,
      usageType,
    );
  }

  Future<void> _showUsageDetails(
    BuildContext context,
    TimeScheme scheme,
    _TimeSchemeUsageSummary usage,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final directCourseReferences = usage.directCourseReferences;
    final overrideReferences = usage.overrideReferences;
    await showHyperosDialog<void>(
      context: context,
      title: l10n.timeSchemeUsageTitle(scheme.name),
      body: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.timeSchemeUsageIntro,
                style: HyperosTypography.listDetail(context),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _TimeSchemeInfoChip(
                    label: l10n.profileCountLabel,
                    value: l10n.profileCountValue(usage.profileCount),
                  ),
                  _TimeSchemeInfoChip(
                    label: l10n.courseCountLabel,
                    value: l10n.courseSectionCountValue(usage.courseCount),
                  ),
                  _TimeSchemeInfoChip(
                    label: l10n.overrideTimeSchemeLabel,
                    value: l10n.courseSectionCountValue(
                      usage.overrideCourseCount,
                    ),
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
                        secondary: l10n.weekdaySectionRange(
                          _weekdayLabel(l10n, reference.course.dayOfWeek),
                          reference.course.startSection,
                          reference.course.endSection,
                        ),
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
                        secondary: l10n.weekdaySectionRange(
                          _weekdayLabel(l10n, reference.course.dayOfWeek),
                          reference.course.startSection,
                          reference.course.endSection,
                        ),
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
        HyperosDialogAction(
          label: l10n.closeAction,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  String _weekdayLabel(AppLocalizations l10n, int dayOfWeek) {
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
  TimeSchemeQuickGeneratePreset _lastQuickGeneratePreset =
      kDefaultTimeSchemeQuickGeneratePreset;

  @override
  void initState() {
    super.initState();
    final provider = context.read<TimetableProvider>();
    final scheme = provider.timeSchemes.firstWhere(
      (item) => item.id == widget.schemeId,
    );
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

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      resizeToAvoidBottomInset: true,
      title: Text(l10n.editTimeSchemeTitle),
      suffixes: [
        FHeaderAction(
          icon: const Icon(Icons.check_rounded),
          semanticsLabel: l10n.saveAction,
          onPress: _save,
        ),
      ],
      child: HyperosBlurredBodyInset(
        child: HyperosListView(
          includeHeaderInset: false,
          children: [
            HyperosControlCard(
              title: l10n.timeSchemeNameLabel,
              child: HyperosControlCardInset(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HyperosTextField(
                      controller: _nameController,
                      hint: l10n.timeSchemeNameHint,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (isActive) _TimeSchemeBadge(text: l10n.currentInUse),
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
                        _TimeSchemeInfoChip(
                          label: l10n.overrideTimeSchemeLabel,
                          value: l10n.courseSectionCountValue(
                            usage.overrideCourseCount,
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
                        style: HyperosTypography.sectionDescription(context),
                      ),
                    ],
                    if (usage.previewText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        usage.previewText!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: HyperosTypography.sectionDescription(context),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const HyperosSectionGap(),
            HyperosControlCard(
              title: l10n.sectionTimesTitle,
              subtitle: l10n.sectionTimesSubtitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HyperosControlCardInset(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        HyperosButton(
                          label: l10n.quickGenerateAction,
                          variant: HyperosButtonVariant.secondary,
                          onPressed: _openQuickGenerate,
                        ),
                        HyperosButton(
                          label: l10n.addSectionAction,
                          variant: HyperosButtonVariant.secondary,
                          onPressed: _sections.length >= 20
                              ? null
                              : _addSection,
                        ),
                        HyperosButton(
                          label: l10n.removeLastSectionAction,
                          variant: HyperosButtonVariant.secondary,
                          onPressed: _sections.length <= 1
                              ? null
                              : _removeSection,
                        ),
                        HyperosButton(
                          label: l10n.resetDefaultAction,
                          variant: HyperosButtonVariant.secondary,
                          onPressed: _resetSections,
                        ),
                      ],
                    ),
                  ),
                  if (_sections.isNotEmpty)
                    HyperosControlCardRows(
                      children: [
                        for (var index = 0; index < _sections.length; index++)
                          HyperosListTile(
                            icon: Icons.access_time_rounded,
                            iconAccent: HyperosIconColors.teal,
                            title: l10n.sectionLabel(index + 1),
                            details:
                                '${_sections[index].startTime} - ${_sections[index].endTime}',
                            onTap: () => _editSectionTime(index),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editSectionTime(int index) async {
    final l10n = AppLocalizations.of(context)!;
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
        message: localizeServiceMessage(l10n, validationMessage),
        kind: AppToastKind.warning,
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
    final l10n = AppLocalizations.of(context)!;
    final profileNames = provider.profiles
        .where((profile) => profile.settings.activeTimeSchemeId == schemeId)
        .map((profile) => profile.name)
        .toList(growable: false);
    final references = provider.getTimeSchemeCourseUsages(schemeId);
    final overrideReferences = references
        .where((item) => item.usesOverride)
        .toList(growable: false);
    final previewText = references.isEmpty
        ? null
        : references.length == 1
        ? _formatUsageReference(l10n, references.first)
        : l10n.timeSchemeBottomUsageMulti(
            _formatUsageReference(l10n, references.first),
            references.length,
          );
    return _TimeSchemeUsageSummary(
      profileNames: profileNames,
      courseReferences: references,
      overrideReferences: overrideReferences,
      previewText: previewText,
    );
  }

  String _formatUsageReference(
    AppLocalizations l10n,
    TimeSchemeCourseUsageReference reference,
  ) {
    final course = reference.course;
    final usageType = reference.usesOverride
        ? l10n.overrideTimeSchemeShortLabel
        : l10n.mainTimeSchemeLabel;
    return l10n.timeSchemeUsageReference(
      reference.profileName,
      course.name,
      _weekdayLabel(l10n, course.dayOfWeek),
      course.startSection,
      course.endSection,
      usageType,
    );
  }

  String _weekdayLabel(AppLocalizations l10n, int dayOfWeek) {
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

  Future<void> _openQuickGenerate() async {
    final l10n = AppLocalizations.of(context)!;
    final preset = await showTimeSchemeQuickGenerateSheet(
      context,
      initialPreset: _lastQuickGeneratePreset,
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
      showAppToast(
        context,
        message: localizeServiceMessage(l10n, error.message),
        kind: AppToastKind.error,
      );
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final message = await context.read<TimetableProvider>().updateTimeScheme(
      schemeId: widget.schemeId,
      name: _nameController.text.trim(),
      sections: _sections,
    );
    if (!mounted) {
      return;
    }
    if (message != null) {
      showAppToast(context, message: localizeServiceMessage(l10n, message));
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
      courseReferences
          .where((item) => !item.usesOverride)
          .toList(growable: false);
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HyperosColors.card(context),
        borderRadius: BorderRadius.circular(HyperosTokens.controlRadius),
        border: Border.all(color: HyperosColors.dividerLine(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: HyperosTypography.listTitle(context)),
          const SizedBox(height: 4),
          Text(subtitle, style: HyperosTypography.listDetail(context)),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(emptyText, style: HyperosTypography.listDetail(context))
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

  const _UsageLine({required this.primary, this.secondary});

  @override
  Widget build(BuildContext context) {
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
                color: HyperosColors.primary(context),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(primary, style: HyperosTypography.listTitle(context)),
                if (secondary != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    secondary!,
                    style: HyperosTypography.listDetail(context),
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

  const _TimeSchemeInfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return HyperosTag(label: '$label $value');
  }
}

class _TimeSchemeBadge extends StatelessWidget {
  final String text;

  const _TimeSchemeBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    final primary = HyperosColors.primary(context);
    return HyperosTag(
      label: text,
      backgroundColor: primary.withValues(alpha: 0.12),
      textStyle: HyperosTypography.listDetail(context).copyWith(
        color: primary,
        fontSize: HyperosTokens.sectionDescriptionSize,
      ),
    );
  }
}

class _DateRuleNameField extends StatefulWidget {
  const _DateRuleNameField({
    required this.initialValue,
    required this.label,
    required this.hint,
    required this.fontSize,
    required this.onChanged,
  });

  final String initialValue;
  final String label;
  final String hint;
  final double fontSize;
  final ValueChanged<String> onChanged;

  @override
  State<_DateRuleNameField> createState() => _DateRuleNameFieldState();
}

class _DateRuleNameFieldState extends State<_DateRuleNameField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HyperosTextField(
      controller: _controller,
      label: widget.label,
      hint: widget.hint,
      fontSize: widget.fontSize,
      onChanged: widget.onChanged,
    );
  }
}

/// Switch control with the same frosted form chrome as [HyperosPickerField].
class _DateRuleSwitchField extends StatelessWidget {
  const _DateRuleSwitchField({
    required this.label,
    required this.value,
    required this.fontSize,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(HyperosMiuixTextField.cornerRadius);
    final fill = HyperosColors.secondaryVariant(context);
    final outline = HyperosColors.outline(context);
    final onSurface = HyperosColors.onSurface(context);

    return Material(
      color: fill,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: outline, width: 1),
          ),
          child: Padding(
            padding: HyperosMiuixTextField.insideMargin,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: fontSize, color: onSurface),
                  ),
                ),
                // The row owns the toggle action. Prevent the nested switch's
                // GestureDetector from competing for the same tap, which can
                // make one user tap appear to toggle twice on some devices.
                AbsorbPointer(
                  child: HyperosSwitch(value: value, onChanged: onChanged),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

TimeOfDay _parseTimeOfDay(String value) {
  final parts = value.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

/// Select items for [HyperosSelectTile]: unique labels, values are scheme ids.
/// Duplicate names get a short id suffix so Map keys never collapse.
Map<String, String> _timeSchemeSelectItems(List<TimeScheme> schemes) {
  final nameCounts = <String, int>{};
  for (final scheme in schemes) {
    nameCounts[scheme.name] = (nameCounts[scheme.name] ?? 0) + 1;
  }
  final items = <String, String>{};
  for (final scheme in schemes) {
    final hasDuplicateName = (nameCounts[scheme.name] ?? 0) > 1;
    final label = hasDuplicateName
        ? '${scheme.name} · ${scheme.id.substring(0, scheme.id.length.clamp(0, 8))}'
        : scheme.name;
    items[label] = scheme.id;
  }
  return items;
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
