import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../models/statistics_models.dart';

/// 每日课时分布柱状图（显示平均课时）
class DailyChart extends StatelessWidget {
  final List<DailyAverageStats> dailyAverages;

  const DailyChart({super.key, required this.dailyAverages});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.theme;
    final colorScheme = Theme.of(context).colorScheme;

    if (dailyAverages.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxAverage = dailyAverages.fold<double>(
      0,
      (max, s) => s.averageSections > max ? s.averageSections : max,
    );

    final activeDays = dailyAverages
        .where((s) => s.averageSections > 0)
        .toList();
    final minAverage = activeDays.isEmpty
        ? 0.0
        : activeDays
              .map((s) => s.averageSections)
              .reduce((a, b) => a < b ? a : b);

    final weekdayLabels = [
      l10n.weekdayShortMonday,
      l10n.weekdayShortTuesday,
      l10n.weekdayShortWednesday,
      l10n.weekdayShortThursday,
      l10n.weekdayShortFriday,
      l10n.weekdayShortSaturday,
      l10n.weekdayShortSunday,
    ];

    return HyperosCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 12, 4),
        child: SizedBox(
          height: 168,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: (maxAverage + 1).toDouble(),
              minY: 0,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${rod.toY.toStringAsFixed(1)} ${l10n.statisticsSectionsUnit}',
                      theme.typography.body.xs.copyWith(
                        color: colorScheme.onInverseSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= weekdayLabels.length) {
                        return const SizedBox.shrink();
                      }
                      final stat = dailyAverages[index];
                      final isMax =
                          activeDays.isNotEmpty &&
                          stat.averageSections == maxAverage;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          weekdayLabels[index],
                          style: theme.typography.body.xs.copyWith(
                            fontWeight: isMax
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: isMax
                                ? theme.colors.primary
                                : theme.colors.mutedForeground,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: maxAverage > 4 ? null : 1,
                    getTitlesWidget: (value, meta) {
                      if (value != value.roundToDouble()) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        value.toInt().toString(),
                        style: theme.typography.body.xs.copyWith(
                          color: theme.colors.mutedForeground,
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxAverage > 4 ? null : 1,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: theme.colors.border.withValues(alpha: 0.5),
                    strokeWidth: 1,
                  );
                },
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(7, (index) {
                final stat = dailyAverages[index];
                final isMax =
                    activeDays.isNotEmpty && stat.averageSections == maxAverage;
                final isMin =
                    activeDays.isNotEmpty &&
                    stat.averageSections == minAverage &&
                    stat.averageSections > 0;

                Color barColor;
                if (isMax) {
                  barColor = colorScheme.primary;
                } else if (isMin) {
                  barColor = colorScheme.tertiary;
                } else {
                  barColor = colorScheme.primary.withValues(alpha: 0.4);
                }

                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: stat.averageSections,
                      color: barColor,
                      width: 20,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
