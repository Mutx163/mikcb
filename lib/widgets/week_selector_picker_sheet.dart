import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

/// Bottom sheet for picking the visible timetable week using HyperOS styling.
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

    return HyperosSheetFrame(
      frosted: true,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.selectWeekTitle,
            style: HyperosTypography.sheetTitle(context),
          ),
          const SizedBox(height: 8),
          HyperosSectionDescription(
            text: l10n.availableWeeksCount(availableWeeks.length),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxListHeight),
            child: SingleChildScrollView(
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: availableWeeks.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.55,
                ),
                itemBuilder: (context, index) {
                  final week = availableWeeks[index];
                  final isCurrentSemesterWeek = week == currentSemesterWeek;
                  if (isCurrentSemesterWeek) {
                    return HyperosButton(
                      label: l10n.goToWeekLabel(week),
                      variant: HyperosButtonVariant.primary,
                      dense: true,
                      expand: true,
                      onPressed: () => Navigator.of(context).pop(week),
                    );
                  }
                  return HyperosFrostedSheetButton(
                    label: l10n.goToWeekLabel(week),
                    dense: true,
                    expand: true,
                    onPressed: () => Navigator.of(context).pop(week),
                  );
                },
              ),
            ),
          ),
          if (showBackToCurrentWeek) ...[
            const SizedBox(height: 14),
            HyperosFrostedSheetButton(
              label: l10n.backToCurrentWeekAction,
              bordered: true,
              expand: true,
              onPressed: () => Navigator.of(context).pop(currentSemesterWeek),
            ),
          ],
        ],
      ),
    );
  }
}
