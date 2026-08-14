import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../models/statistics_models.dart';

/// 每周课时趋势折线图（截至当前周；未来周以浅色虚线预告）
class TrendChart extends StatelessWidget {
  final List<WeeklyTrendPoint> trend;
  final int currentWeek;

  const TrendChart({super.key, required this.trend, required this.currentWeek});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (trend.isEmpty) {
      return const SizedBox.shrink();
    }

    final elapsed = trend.where((p) => p.weekNumber <= currentWeek).toList();
    final future = trend.where((p) => p.weekNumber > currentWeek).toList();
    final maxY = trend.fold<int>(
      0,
      (max, p) => p.sections > max ? p.sections : max,
    );
    final minWeek = trend.first.weekNumber;
    final maxWeek = trend.last.weekNumber;

    return HyperosControlCard(
      child: HyperosControlCardInset(
        child: SizedBox(
          height: 160,
          child: LineChart(
            LineChartData(
              minX: minWeek.toDouble(),
              maxX: maxWeek.toDouble(),
              minY: 0,
              maxY: (maxY + 1).toDouble(),
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final week = spot.x.round();
                      return LineTooltipItem(
                        l10n.statisticsTrendTooltip(
                          week,
                          spot.y.round(),
                        ),
                        HyperosTypography.listDetail(context).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }).toList();
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
                    reservedSize: 26,
                    interval: _labelInterval(maxWeek),
                    getTitlesWidget: (value, meta) {
                      final week = value.round();
                      if (week < minWeek || week > maxWeek) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '$week',
                          style: HyperosTypography.listDetail(
                            context,
                          ).copyWith(
                            fontSize: HyperosMiuixTypography.footnote2,
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
                    interval: maxY > 8 ? null : 2,
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
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: HyperosColors.dividerLine(context),
                    strokeWidth: 1,
                  );
                },
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                if (elapsed.isNotEmpty)
                  LineChartBarData(
                    spots: [
                      for (final p in elapsed)
                        FlSpot(p.weekNumber.toDouble(), p.sections.toDouble()),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.25,
                    color: HyperosColors.primary(context),
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: elapsed.length <= 20,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 3,
                          color: HyperosColors.primary(context),
                          strokeWidth: 1,
                          strokeColor: HyperosColors.card(context),
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: HyperosColors.primary(context).withValues(
                        alpha: 0.10,
                      ),
                    ),
                  ),
                if (future.isNotEmpty)
                  LineChartBarData(
                    spots: [
                      for (final p in future)
                        FlSpot(p.weekNumber.toDouble(), p.sections.toDouble()),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.25,
                    color: HyperosColors.secondaryText(context).withValues(
                      alpha: 0.45,
                    ),
                    barWidth: 2,
                    dashArray: [6, 4],
                    dotData: const FlDotData(show: false),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static double _labelInterval(int maxWeek) {
    if (maxWeek <= 6) return 1;
    if (maxWeek <= 12) return 2;
    if (maxWeek <= 24) return 4;
    return 8;
  }
}
