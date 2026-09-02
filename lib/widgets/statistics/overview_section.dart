import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../models/statistics_models.dart';

/// 学期总览（单行四指标：数字在上、标签在下，细分隔线隔开）。
///
/// 与 [WeeklyComparisonCard] 的格子口径一致（24px 数字 + footnote2 标签），
/// 首格用主题色强调。
class OverviewSection extends StatelessWidget {
  final SemesterStats stats;

  const OverviewSection({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (stats.totalCourses == 0) {
      return const SizedBox.shrink();
    }

    final divider = Container(
      width: 1,
      height: 28,
      color: HyperosColors.dividerLine(context),
    );

    return HyperosControlCard(
      child: Row(
        children: [
          _MetricCell(
            value: '${stats.totalCourses}',
            label: l10n.statisticsSemesterLabelCourses,
            highlight: true,
          ),
          divider,
          _MetricCell(
            value: '${stats.totalSections}',
            label: l10n.statisticsSemesterLabelSections,
          ),
          divider,
          _MetricCell(
            value: '${stats.totalWeeks}',
            label: l10n.statisticsSemesterLabelWeeks,
          ),
          divider,
          _MetricCell(
            value: '${stats.longestStreak}',
            label: l10n.statisticsSemesterLabelDayStreak,
          ),
        ],
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  final String value;
  final String label;

  /// 首格数字用主题色（对齐下方本周小结卡的高亮口径）。
  final bool highlight;

  const _MetricCell({
    required this.value,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: HyperosTypography.metricLarge(context).copyWith(
                color: highlight
                    ? HyperosColors.primary(context)
                    : HyperosColors.primaryText(context),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: HyperosTypography.metricCaption(context).copyWith(
                color: highlight
                    ? HyperosColors.primaryText(context)
                    : HyperosColors.secondaryText(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
