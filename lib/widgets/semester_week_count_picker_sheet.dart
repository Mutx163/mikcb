import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../ui/hyperos/hyperos.dart';

/// Bottom sheet for picking semester week count — HyperOS list selection style.
Future<int?> showSemesterWeekCountPickerSheet(
  BuildContext context, {
  required int currentValue,
  int minValue = 1,
  int maxValue = 30,
}) {
  return showHyperosSheet<int>(
    context: context,
    builder: (sheetContext) => _SemesterWeekCountPickerSheetBody(
      currentValue: currentValue,
      minValue: minValue,
      maxValue: maxValue,
    ),
  );
}

class _SemesterWeekCountPickerSheetBody extends StatelessWidget {
  const _SemesterWeekCountPickerSheetBody({
    required this.currentValue,
    required this.minValue,
    required this.maxValue,
  });

  final int currentValue;
  final int minValue;
  final int maxValue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final options = List<int>.generate(
      maxValue - minValue + 1,
      (index) => minValue + index,
    );
    final maxListHeight = MediaQuery.sizeOf(context).height * 0.55;

    return HyperosSheet(
      title: l10n.selectSemesterWeekCountTitle,
      description: l10n.selectSemesterWeekCountSubtitle,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxListHeight),
        child: SingleChildScrollView(
          child: HyperosChoiceGroup(
            children: [
              for (var i = 0; i < options.length; i++)
                HyperosChoiceTile(
                  title: l10n.semesterWeekCountAction(options[i]),
                  selected: options[i] == currentValue,
                  highlightSelectedText: true,
                  onTap: () => Navigator.of(context).pop(options[i]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
