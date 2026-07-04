import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../../models/statistics_models.dart';

/// 必修/选修比例显示组件（环形图）
class NatureRatio extends StatelessWidget {
  final CourseNatureStats stats;

  const NatureRatio({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasData = stats.totalCount > 0;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: hasData
            ? Column(
                children: [
                  // 环形图 + 图例
                  Row(
                    children: [
                      // 环形图
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: _buildDonutChart(context),
                      ),
                      const SizedBox(width: 20),
                      // 图例和数据
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
                  ),
                ],
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    l10n.statisticsNoData,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                l10n.statisticsNatureLegendDetail(count, sections),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Text(
          '${(ratio * 100).round()}%',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}
