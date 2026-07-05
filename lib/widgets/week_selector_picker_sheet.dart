import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

/// Bottom sheet for picking the visible timetable week using Forui styling.
Future<int?> showWeekSelectorPickerSheet(
  BuildContext context, {
  required List<int> availableWeeks,
  required int visibleWeek,
  required int? currentSemesterWeek,
}) {
  return showFSheet<int>(
    context: context,
    side: FLayout.btt,
    useSafeArea: true,
    draggable: true,
    mainAxisMaxRatio: null,
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
    final colors = context.theme.colors;
    final typo = context.theme.typography;
    final colorScheme = Theme.of(context).colorScheme;
    final maxListHeight = MediaQuery.sizeOf(context).height * 0.42;
    final showBackToCurrentWeek =
        currentSemesterWeek != null && visibleWeek != currentSemesterWeek;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: colorScheme.primary.withValues(alpha: 0.12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.calendar_view_week_rounded,
                      color: colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.selectWeekTitle,
                          style: typo.body.sm.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          l10n.availableWeeksCount(availableWeeks.length),
                          style: typo.body.xs2.copyWith(
                            color: colors.mutedForeground,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showBackToCurrentWeek)
                    FButton(
                      variant: FButtonVariant.secondary,
                      onPress: () =>
                          Navigator.of(context).pop(currentSemesterWeek),
                      prefix: const Icon(Icons.my_location_rounded, size: 18),
                      child: Text(l10n.backToCurrentWeekAction),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxListHeight),
                child: SingleChildScrollView(
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: availableWeeks.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
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
        ),
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
    return FButton(
      variant: isCurrentSemesterWeek
          ? FButtonVariant.secondary
          : FButtonVariant.outline,
      onPress: onPress,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isCurrentSemesterWeek ? FontWeight.w700 : FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }
}
