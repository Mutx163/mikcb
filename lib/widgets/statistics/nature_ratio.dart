import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../models/statistics_models.dart';

/// 必修/选修比例显示组件（环形图）
class NatureRatio extends StatelessWidget {
  final CourseNatureStats stats;

  const NatureRatio({super.key, required this.stats});

  static const _requiredColor = HyperosIconColors.blue;
  static const _electiveColor = HyperosIconColors.purple;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasData = stats.totalCount > 0;

    return HyperosControlCard(
      child: HyperosControlCardInset(
        child: hasData
            ? Row(
                children: [
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: _buildDonutChart(),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LegendItem(
                          color: _requiredColor,
                          label: l10n.courseNatureRequired,
                          count: stats.requiredCount,
                          sections: stats.requiredSections,
                          ratio: stats.requiredRatio,
                        ),
                        const SizedBox(height: 12),
                        _LegendItem(
                          color: _electiveColor,
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
                    style: HyperosTypography.listDetail(context),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildDonutChart() {
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 30,
        sections: [
          PieChartSectionData(
            value: stats.requiredCount.toDouble(),
            color: _requiredColor,
            radius: 22,
            showTitle: false,
          ),
          PieChartSectionData(
            value: stats.electiveCount.toDouble(),
            color: _electiveColor,
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
                style: HyperosTypography.listTitle(context),
              ),
              Text(
                l10n.statisticsNatureLegendDetail(count, sections),
                style: HyperosTypography.listDetail(context).copyWith(
                  fontSize: HyperosMiuixTypography.footnote2,
                ),
              ),
            ],
          ),
        ),
        Text(
          '${(ratio * 100).round()}%',
          // T2 行内数据值：语义色 + w600
          style: HyperosTypography.listTitle(context).copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
