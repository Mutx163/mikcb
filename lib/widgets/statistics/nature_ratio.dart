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
                    child: _buildDonutChart(context),
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

  Widget _buildDonutChart(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // 单侧缺失（必修=0 / 选修=0）时的中心提示文案，两侧对称。
    final String? missingLabel = stats.requiredCount == 0
        ? l10n.statisticsNatureNoneRequired
        : stats.electiveCount == 0
            ? l10n.statisticsNatureNoneElective
            : null;
    // 缺失态中心要放提示文案（英文/日/韩较长），孔径加大 4dp 防溢出；
    // 正常态 radius 20 + 孔 28 = 直径 100 恰好贴合 100x100 容器，
    // 修复原来 22+30=104 被裁 4dp 的问题。
    final double radius = missingLabel != null ? 18.0 : 20.0;
    final double centerRadius = missingLabel != null ? 32.0 : 28.0;

    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: centerRadius,
            sections: [
              PieChartSectionData(
                value: stats.requiredCount.toDouble(),
                color: _requiredColor,
                radius: radius,
                showTitle: false,
              ),
              PieChartSectionData(
                value: stats.electiveCount.toDouble(),
                color: _electiveColor,
                radius: radius,
                showTitle: false,
              ),
              // fl_chart 对 value=0 的段不渲染弧线，纯色圆会被误读为
              // 100%：哪侧为 0 就在哪侧补一段极浅轨道段，让“空”可见。
              if (stats.requiredCount == 0)
                PieChartSectionData(
                  value: 1,
                  color: _requiredColor.withValues(alpha: 0.12),
                  radius: radius,
                  showTitle: false,
                ),
              if (stats.electiveCount == 0)
                PieChartSectionData(
                  value: 1,
                  color: _electiveColor.withValues(alpha: 0.12),
                  radius: radius,
                  showTitle: false,
                ),
            ],
          ),
        ),
        if (missingLabel != null)
          // FittedBox 兜底：英文/日/韩文案较长，两行后仍可能超出中心孔，
          // 等比缩小保证不压到环上。
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                missingLabel,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: HyperosTypography.listDetail(context).copyWith(
                  fontSize: HyperosMiuixTypography.footnote2,
                  color: HyperosColors.secondaryText(context),
                  height: 1.2,
                ),
              ),
            ),
          ),
      ],
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
