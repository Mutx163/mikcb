import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../models/statistics_models.dart';

/// 必修/选修比例显示组件（环形图）
class NatureRatio extends StatelessWidget {
  final CourseNatureStats stats;

  const NatureRatio({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.theme;
    final colorScheme = Theme.of(context).colorScheme;
    final hasData = stats.totalCount > 0;

    return HyperosCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: hasData
            ? Row(
                children: [
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: _buildDonutChart(context),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LegendItem(
                          color: colorScheme.primary,
                          label: l10n.courseNatureRequired,
                          count: stats.requiredCount,
                          sections: stats.requiredSections,
                          ratio: stats.requiredRatio,
                        ),
                        const SizedBox(height: 12),
                        _LegendItem(
                          color: colorScheme.tertiary,
                          label: l10n.courseNatureElective,
                          count: stats.electiveCount,
                          sections: stats.electiveSections,
                          ratio: stats.electiveRatio,
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    l10n.statisticsNoData,
                    style: theme.typography.body.sm.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildDonutChart(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 30,
        sections: [
          PieChartSectionData(
            value: stats.requiredCount.toDouble(),
            color: colorScheme.primary,
            radius: 22,
            showTitle: false,
          ),
          PieChartSectionData(
            value: stats.electiveCount.toDouble(),
            color: colorScheme.tertiary,
            radius: 22,
            showTitle: false,
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  final int sections;
  final double ratio;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.count,
    required this.sections,
    required this.ratio,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.theme;

    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.typography.body.sm.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                l10n.statisticsNatureLegendDetail(count, sections),
                style: theme.typography.body.xs.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        Text(
          '${(ratio * 100).round()}%',
          style: theme.typography.body.md.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}
