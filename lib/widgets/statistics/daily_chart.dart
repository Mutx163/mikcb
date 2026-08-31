import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
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

    return HyperosControlCard(
      child: HyperosControlCardInset(
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
                      HyperosTypography.listDetail(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  
                ),
                rightTitles: const AxisTitles(
                  
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
                          style: HyperosTypography.listDetail(context).copyWith(
                            fontSize: HyperosMiuixTypography.footnote2,
                            // T1 轻强调：轴标签高亮用 w500，避免小字加粗发闷
                            fontWeight: isMax
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: isMax
                                ? HyperosColors.primary(context)
                                : HyperosColors.secondaryText(context),
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
                        style: HyperosTypography.listDetail(
                          context,
                        ).copyWith(fontSize: HyperosMiuixTypography.footnote2),
                      );
                    },
                  ),
                ),
              ),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: maxAverage > 4 ? null : 1,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: HyperosColors.dividerLine(context),
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

                final barColor = isMax
                    ? HyperosColors.primary(context)
                    : isMin
                    ? HyperosIconColors.teal
                    : HyperosColors.primary(context).withValues(alpha: 0.35);

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
