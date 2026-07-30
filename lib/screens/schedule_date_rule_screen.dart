import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../models/schedule_date_rule.dart';
import '../models/time_scheme.dart';
import '../providers/timetable_provider.dart';
import '../utils/app_toast.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/miuix_date_picker_sheet.dart';

/// Secondary settings page for seasonal / date-range schedule rules.
class ScheduleDateRuleScreen extends StatelessWidget {
  const ScheduleDateRuleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        final dateRules = provider.scheduleDateRules;
        final activeDateRule = provider.matchScheduleDateRule(DateTime.now());

        return HyperosSubpage(
          onBack: () => Navigator.pop(context),
          title: Text(l10n.scheduleDateRuleSectionTitle),
          suffixes: [
            FHeaderAction(
              icon: const Icon(Icons.add_rounded),
              semanticsLabel: l10n.scheduleDateRuleAdd,
              onPress: () =>
                  _openScheduleDateRuleEditor(context, existing: null),
            ),
          ],
          child: HyperosListView(
            children: [
              HyperosSectionLabel(text: l10n.scheduleDateRuleSectionTitle),
              if (dateRules.isEmpty)
                HyperosListGroup(
                  children: [
                    HyperosActionTile(
                      icon: Icons.add_rounded,
                      title: l10n.scheduleDateRuleAdd,
                      onTap: () =>
                          _openScheduleDateRuleEditor(context, existing: null),
                    ),
                  ],
                )
              else ...[
                for (var index = 0; index < dateRules.length; index++) ...[
                  if (index > 0) const HyperosSectionGap(),
                  _ScheduleDateRuleCard(
                    rule: dateRules[index],
                    isActiveToday: activeDateRule?.id == dateRules[index].id,
                    schemeName:
                        provider.timeSchemes
                            .where(
                              (scheme) =>
                                  scheme.id == dateRules[index].timeSchemeId,
                            )
                            .map((scheme) => scheme.name)
                            .firstOrNull ??
                        l10n.locationTimeMatchUnknownScheme,
                    onEdit: () => _openScheduleDateRuleEditor(
                      context,
                      existing: dateRules[index],
                    ),
                    onDelete: () =>
                        _deleteScheduleDateRule(context, dateRules[index]),
                  ),
                ],
              ],
              HyperosSectionDescription(
                text: l10n.scheduleDateRuleSectionSubtitle,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScheduleDateRuleCard extends StatelessWidget {
  const _ScheduleDateRuleCard({
    required this.rule,
    required this.isActiveToday,
    required this.schemeName,
    required this.onEdit,
    required this.onDelete,
  });

  final ScheduleDateRule rule;
  final bool isActiveToday;
  final String schemeName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
                  onPressed: onEdit,
                ),
              ),
              const SizedBox(width: 8),
              HyperosButton(
                label: l10n.deleteAction,
                variant: HyperosButtonVariant.secondary,
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _localizeScheduleDateRuleError(AppLocalizations l10n, String code) {
  return switch (code) {
    'schedule_date_rule_max_exceeded' => l10n.scheduleDateRuleErrorMax,
    'schedule_date_rule_overlap' => l10n.scheduleDateRuleErrorOverlap,
    'schedule_date_rule_invalid_date' => l10n.scheduleDateRuleErrorInvalidDate,
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
      ScheduleDateRuleLogic.parseIsoDate(existing?.startDate) ?? DateTime.now();
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
    return showMiuixDatePickerSheet(
      pickerContext,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(2040),
    );
  }

  final saved = await showHyperosDialog<bool>(
    context: context,
    enableDrag: false,
    maxBodyHeightFactor: 0.55,
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
