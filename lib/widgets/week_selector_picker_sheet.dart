import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

/// Bottom sheet for picking the visible timetable week using Forui styling.
Future<int?> showWeekSelectorPickerSheet(
  BuildContext context, {
  required List<int> availableWeeks,
  required int visibleWeek,
  required int? currentSemesterWeek,
}) {
  return showHomeHyperosSheet<int>(
    context: context,
    builder: (sheetContext) => _WeekSelectorPickerSheetBody(
      availableWeeks: availableWeeks,
      visibleWeek: visibleWeek,
      currentSemesterWeek: currentSemesterWeek,
    ),
  );
}

class _WeekSelectorPickerSheetBody extends StatelessWidget {
  const _WeekSelectorPickerSheetBody({
    required this.availableWeeks,
    required this.visibleWeek,
    required this.currentSemesterWeek,
  });

  final List<int> availableWeeks;
  final int visibleWeek;
  final int? currentSemesterWeek;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final maxListHeight = MediaQuery.sizeOf(context).height * 0.42;
    final showBackToCurrentWeek =
        currentSemesterWeek != null && visibleWeek != currentSemesterWeek;

    return HyperosSheet(
      frosted: true,
      title: l10n.selectWeekTitle,
      description: l10n.availableWeeksCount(availableWeeks.length),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showBackToCurrentWeek) ...[
            Align(
              alignment: Alignment.centerRight,
              child: HyperosButton(
                label: l10n.backToCurrentWeekAction,
                variant: HyperosButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop(currentSemesterWeek),
              ),
            ),
            const SizedBox(height: 10),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxListHeight),
            child: SingleChildScrollView(
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: availableWeeks.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.35,
                ),
                itemBuilder: (context, index) {
                  final week = availableWeeks[index];
                  final isCurrentSemesterWeek = week == currentSemesterWeek;
                  return _WeekSelectorChip(
                    label: l10n.goToWeekLabel(week),
                    isCurrentSemesterWeek: isCurrentSemesterWeek,
                    onPress: () => Navigator.of(context).pop(week),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekSelectorChip extends StatelessWidget {
  const _WeekSelectorChip({
    required this.label,
    required this.isCurrentSemesterWeek,
    required this.onPress,
  });

  final String label;
  final bool isCurrentSemesterWeek;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    return HyperosButton(
      label: label,
      variant: isCurrentSemesterWeek
          ? HyperosButtonVariant.primary
          : HyperosButtonVariant.secondary,
      expand: true,
      onPressed: onPress,
    );
  }
}
