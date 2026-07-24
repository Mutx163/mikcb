import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                  return _WeekSelectorCell(
                    label: l10n.goToWeekLabel(week),
                    highlighted: week == currentSemesterWeek,
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

/// Compact week tile: single-line label, smaller than sheet title, fills the grid cell.
class _WeekSelectorCell extends StatelessWidget {
  const _WeekSelectorCell({
    required this.label,
    required this.highlighted,
    required this.onPressed,
  });

  final String label;
  final bool highlighted;
  final VoidCallback onPressed;

  /// Below [HyperosTypography.sheetTitle] (~preference title), above dense footnote.
  static const double _labelFontSize = HyperosMiuixTypography.body2;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const minHeight = 40.0;
    final cornerRadius = HyperosRadius.clampCornerRadius(
      HyperosMiuixButton.cornerRadius,
      minHeight,
    );
    final borderRadius = BorderRadius.circular(cornerRadius);

    final backgroundColor = highlighted
        ? HyperosColors.primary(context)
        : (isDark
              ? Colors.white.withValues(alpha: 0.14)
              : const Color(0xFFE8E8E8));
    final foregroundColor = highlighted
        ? HyperosColors.onPrimary(context)
        : HyperosColors.onSecondaryVariant(context);

    final labelWidget = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: _labelFontSize,
          color: foregroundColor,
          fontWeight: FontWeight.w400,
          height: 1.1,
        ),
      ),
    );

    return Material(
      color: backgroundColor,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Center(child: labelWidget),
        ),
      ),
    );
  }
}
