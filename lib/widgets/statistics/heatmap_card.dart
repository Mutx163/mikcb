import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../models/statistics_models.dart';

/// 学期热力图：周 × 天 课时密度
class SemesterHeatmapCard extends StatelessWidget {
  final SemesterHeatmap heatmap;
  final int currentWeek;

  const SemesterHeatmapCard({
    super.key,
    required this.heatmap,
    required this.currentWeek,
  });

  static const double _cellSize = 13;
  static const double _cellGap = 3;
  static const double _labelWidth = 22;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (heatmap.weekCount < 1) {
      return const SizedBox.shrink();
    }

    final clipped = heatmap.clippedToWeek(currentWeek);
    final base = HyperosColors.primary(context);
    final emptyColor = HyperosColors.rowHighlight(context);

    Color cellColor(int value) {
      if (value <= 0) return emptyColor;
      final max = clipped.maxSections < 1 ? 1 : clipped.maxSections;
      final t = (value / max).clamp(0.0, 1.0);
      // 4 档色阶
      if (t < 0.25) return base.withValues(alpha: 0.22);
      if (t < 0.5) return base.withValues(alpha: 0.45);
      if (t < 0.75) return base.withValues(alpha: 0.68);
      return base;
    }

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                HyperosIconBadge(
                  icon: Icons.grid_view_rounded,
                  accent: HyperosIconColors.indigo,
                ),
                const SizedBox(width: HyperosTokens.rowContentGap),
                Expanded(
                  child: Text(
                    l10n.statisticsHeatmapTitle,
                    style: HyperosTypography.listTitle(context),
                  ),
                ),
                Text(
                  l10n.statisticsHeatmapHint,
                  style: HyperosTypography.listDetail(context).copyWith(
                    fontSize: HyperosMiuixTypography.footnote2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 星期标签列
                  Column(
                    children: [
                      const SizedBox(height: _cellSize + _cellGap),
                      for (var day = 0; day < 7; day++)
                        Container(
                          width: _labelWidth,
                          height: _cellSize + _cellGap,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            weekdayLabels[day],
                            style: HyperosTypography.listDetail(context)
                                .copyWith(fontSize: 10),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  // 周次 × 天 网格
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 周次标签行（每 4 周标一个）
                      SizedBox(
                        height: _cellSize + _cellGap,
                        child: Row(
                          children: [
                            for (var week = 1; week <= heatmap.weekCount; week++)
                              Container(
                                width: _cellSize,
                                margin: const EdgeInsets.only(right: _cellGap),
                                alignment: Alignment.center,
                                child: week % 4 == 1 || week == heatmap.weekCount
                                    ? Text(
                                        '$week',
                                        style: HyperosTypography.listDetail(
                                          context,
                                        ).copyWith(fontSize: 9),
                                      )
                                    : null,
                              ),
                          ],
                        ),
                      ),
                      for (var day = 0; day < 7; day++) ...[
                        if (day > 0) const SizedBox(height: _cellGap),
                        Row(
                          children: [
                            for (var week = 0; week < heatmap.weekCount; week++)
                              Container(
                                width: _cellSize,
                                height: _cellSize,
                                margin: const EdgeInsets.only(right: _cellGap),
                                decoration: BoxDecoration(
                                  color: cellColor(clipped.rows[day][week]),
                                  borderRadius: BorderRadius.circular(3.5),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
