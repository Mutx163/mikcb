import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../models/statistics_models.dart';

/// 本周小结：本周 vs 上周 vs 学期周均
class WeeklyComparisonCard extends StatelessWidget {
  final WeeklyComparison comparison;
  final int currentWeek;

  const WeeklyComparisonCard({
    super.key,
    required this.comparison,
    required this.currentWeek,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isFirstWeek = currentWeek <= 1;
    final primary = HyperosColors.primary(context);
    final up = HyperosIconColors.red;
    final down = HyperosIconColors.green;

    final vsLast = comparison.deltaVsLastWeek;

    Color deltaColor(int d) => d > 0
        ? up
        : (d < 0 ? down : HyperosColors.secondaryText(context));
    String deltaText(int d) => d > 0 ? '+$d' : (d < 0 ? '$d' : '0');

    return HyperosControlCard(
      child: HyperosControlCardInset(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                HyperosIconBadge(
                  icon: Icons.summarize_rounded,
                  accent: HyperosIconColors.orange,
                ),
                const SizedBox(width: HyperosTokens.rowContentGap),
                Text(
                  l10n.statisticsComparisonTitle,
                  style: HyperosTypography.listTitle(context),
                ),
                const Spacer(),
                Text(
                  l10n.statisticsWeekSelector(currentWeek),
                  style: HyperosTypography.listDetail(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ComparisonCell(
                    value: '${comparison.weekSections}',
                    label: l10n.statisticsSectionCount,
                    accent: primary,
                    highlight: true,
                  ),
                ),
                Expanded(
                  child: _ComparisonCell(
                    value: isFirstWeek
                        ? '—'
                        : deltaText(vsLast),
                    label: l10n.statisticsComparisonVsLastWeek(
                      isFirstWeek ? '—' : deltaText(vsLast),
                    ),
                    accent: isFirstWeek
                        ? HyperosColors.secondaryText(context)
                        : deltaColor(vsLast),
                  ),
                ),
                Expanded(
                  child: _ComparisonCell(
                    value: comparison.semesterAverageSections.toStringAsFixed(1),
                    label: l10n.statisticsComparisonAverage,
                    accent: HyperosIconColors.teal,
                  ),
                ),
              ],
            ),
            if (isFirstWeek) ...[
              const SizedBox(height: 8),
              Text(
                l10n.statisticsComparisonNew,
                style: HyperosTypography.listDetail(context).copyWith(
                  fontSize: HyperosMiuixTypography.footnote2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ComparisonCell extends StatelessWidget {
  final String value;
  final String label;
  final Color accent;
  final bool highlight;

  const _ComparisonCell({
    required this.value,
    required this.label,
    required this.accent,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: HyperosTypography.listTitle(context).copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1,
            color: accent,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: HyperosTypography.listDetail(context).copyWith(
            fontSize: HyperosMiuixTypography.footnote2,
            color: highlight
                ? HyperosColors.primaryText(context)
                : HyperosColors.secondaryText(context),
          ),
        ),
      ],
    );
  }
}
