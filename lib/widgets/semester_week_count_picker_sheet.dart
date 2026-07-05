import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

/// Bottom sheet for picking semester week count using Forui styling.
Future<int?> showSemesterWeekCountPickerSheet(
  BuildContext context, {
  required int currentValue,
  int minValue = 1,
  int maxValue = 30,
}) {
  return showFSheet<int>(
    context: context,
    side: FLayout.btt,
    useSafeArea: true,
    draggable: true,
    mainAxisMaxRatio: null,
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
    final colors = context.theme.colors;
    final typo = context.theme.typography;
    final colorScheme = Theme.of(context).colorScheme;
    final options = List<int>.generate(
      maxValue - minValue + 1,
      (index) => minValue + index,
    );
    final maxListHeight = MediaQuery.sizeOf(context).height * 0.42;

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
                      Icons.view_week_rounded,
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
                          l10n.selectSemesterWeekCountTitle,
                          style: typo.body.sm.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          l10n.selectSemesterWeekCountSubtitle,
                          style: typo.body.xs2.copyWith(
                            color: colors.mutedForeground,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
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
                    itemCount: options.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.35,
                        ),
                    itemBuilder: (context, index) {
                      final weekCount = options[index];
                      final isSelected = weekCount == currentValue;
                      return _WeekCountChip(
                        label: l10n.semesterWeekCountAction(weekCount),
                        isSelected: isSelected,
                        onPress: () => Navigator.of(context).pop(weekCount),
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

class _WeekCountChip extends StatelessWidget {
  const _WeekCountChip({
    required this.label,
    required this.isSelected,
    required this.onPress,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    return FButton(
      variant: isSelected ? FButtonVariant.secondary : FButtonVariant.outline,
      onPress: onPress,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }
}
