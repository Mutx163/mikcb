import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../models/time_scheme.dart';
import '../utils/app_toast.dart';
import 'miuix_time_picker_sheet.dart';

/// Preset values returned by [showTimeSchemeQuickGenerateSheet].
class TimeSchemeQuickGeneratePreset {
  final int morningCount;
  final int afternoonCount;
  final int eveningCount;
  final String? morningStartTime;
  final String? afternoonStartTime;
  final String? eveningStartTime;
  final int classDurationMinutes;
  final int breakDurationMinutes;
  final List<BreakOverrideRule> breakOverrideRules;

  const TimeSchemeQuickGeneratePreset({
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

/// Default preset used when opening the quick-generate sheet for the first time.
const TimeSchemeQuickGeneratePreset kDefaultTimeSchemeQuickGeneratePreset =
    TimeSchemeQuickGeneratePreset(
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

/// Floating HyperOS form card with solid [HyperosButton]s.
///
/// Same bottom floating card pattern as [showHyperosDialog] /
/// [showAppTextInputDialog].
Future<TimeSchemeQuickGeneratePreset?> showTimeSchemeQuickGenerateSheet(
  BuildContext context, {
  required TimeSchemeQuickGeneratePreset initialPreset,
  bool useRootNavigator = false,
}) {
  return showHyperosSheet<TimeSchemeQuickGeneratePreset>(
    context: context,
    useRootNavigator: useRootNavigator,
    builder: (_) => _TimeSchemeQuickGenerateSheet(initialPreset: initialPreset),
  );
}

class _TimeSchemeQuickGenerateSheet extends StatefulWidget {
  final TimeSchemeQuickGeneratePreset initialPreset;

  const _TimeSchemeQuickGenerateSheet({required this.initialPreset});

  @override
  State<_TimeSchemeQuickGenerateSheet> createState() =>
      _TimeSchemeQuickGenerateSheetState();
}

class _TimeSchemeQuickGenerateSheetState
    extends State<_TimeSchemeQuickGenerateSheet> {
  late final TextEditingController _morningCountController;
  late final TextEditingController _afternoonCountController;
  late final TextEditingController _eveningCountController;
  late final TextEditingController _classDurationController;
  late final TextEditingController _breakDurationController;
  final List<_BreakOverrideDraft> _breakOverrides = [];
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
    if (_breakOverrides.isEmpty) {
      _breakOverrides.add(
        _BreakOverrideDraft(afterSection: 2, breakDurationMinutes: 20),
      );
    }
  }

  @override
  void dispose() {
    _morningCountController.dispose();
    _afternoonCountController.dispose();
    _eveningCountController.dispose();
    _classDurationController.dispose();
    _breakDurationController.dispose();
    for (final item in _breakOverrides) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.88;

    return HyperosSheetFrame(
      chrome: HyperosSheetChrome.floating,
      frosted: true,
      maxHeight: maxSheetHeight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.quickGenerateTimeSchemeTitle,
            style: HyperosTypography.sheetTitle(context),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      title: l10n.morningFirstSectionTimeLabel,
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
                      title: l10n.afternoonFirstSectionTimeLabel,
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
                      title: l10n.eveningFirstSectionTimeLabel,
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
                      style: HyperosTypography.listTitle(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._buildBreakOverrideRows(),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: HyperosButton(
                      label: l10n.addBreakRuleAction,
                      variant: HyperosButtonVariant.secondary,
                      onPressed: _addBreakOverride,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: HyperosButton(
                  label: l10n.cancelAction,
                  variant: HyperosButtonVariant.secondary,
                  expand: true,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: HyperosButton(
                  label: l10n.generateAction,
                  expand: true,
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumberField(TextEditingController controller, String label) {
    return HyperosTextField(
      controller: controller,
      label: label,
      keyboardType: TextInputType.number,
    );
  }

  Widget _buildTimeTile({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    // Match [HyperosTextField] chrome (secondary fill + 16 radius), not a white
    // [HyperosListGroup] card that stands out on frosted sheets.
    return HyperosPickerField(
      label: label,
      value: value,
      icon: Icons.schedule_outlined,
      onTap: onTap,
    );
  }

  List<Widget> _buildBreakOverrideRows() {
    final l10n = AppLocalizations.of(context)!;
    if (_breakOverrides.isEmpty) {
      return [
        Text(
          l10n.noLargeBreakRulesHint,
          style: HyperosTypography.sectionDescription(context),
        ),
      ];
    }

    return List.generate(_breakOverrides.length, (index) {
      final item = _breakOverrides[index];
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: HyperosTextField(
                controller: item.afterController,
                label: l10n.afterSectionLabel,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: HyperosTextField(
                controller: item.durationController,
                label: l10n.breakDurationMinutesLabel,
                keyboardType: TextInputType.number,
              ),
            ),
            HyperosIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: l10n.deleteRuleTooltip,
              onPressed: () {
                setState(() {
                  _breakOverrides.removeAt(index).dispose();
                });
              },
            ),
          ],
        ),
      );
    });
  }

  Future<void> _pickTime({
    required String title,
    required String currentValue,
    required ValueChanged<String> onSelected,
  }) async {
    final selected = await showMiuixTimePickerSheet(
      context,
      initialTime: _parseTimeOfDay(currentValue),
      title: title,
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
      TimeSchemeQuickGeneratePreset(
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
  _BreakOverrideDraft({
    required int afterSection,
    required int breakDurationMinutes,
  }) : afterController = TextEditingController(text: '$afterSection'),
       durationController = TextEditingController(
         text: '$breakDurationMinutes',
       );

  final TextEditingController afterController;
  final TextEditingController durationController;

  int get afterSection => int.tryParse(afterController.text.trim()) ?? 0;

  int get breakDurationMinutes =>
      int.tryParse(durationController.text.trim()) ?? 0;

  void dispose() {
    afterController.dispose();
    durationController.dispose();
  }
}

TimeOfDay _parseTimeOfDay(String value) {
  final parts = value.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

String _formatTimeOfDay(TimeOfDay time) {
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}
