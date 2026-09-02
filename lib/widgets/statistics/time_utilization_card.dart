import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../models/statistics_models.dart';

/// 时间利用分析卡
///
/// 7 项并列读数以纵向键值对列表呈现，行间用细分隔线区分，
/// 避免横向 Wrap 固定宽度造成的留白与列距不均问题。
class TimeUtilizationCard extends StatelessWidget {
  final TimeUtilizationStats stats;

  const TimeUtilizationCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (stats.isEmpty) {
      return const SizedBox.shrink();
    }

    final labelStyle = HyperosTypography.listDetail(context).copyWith(
      fontSize: HyperosMiuixTypography.footnote2,
    );

    final rows = <(IconData, Color, String, String)>[
      (
        Icons.wb_sunny_outlined,
        HyperosIconColors.orange,
        l10n.statisticsTimeEarliest,
        stats.earliestStart,
      ),
      (
        Icons.nights_stay_outlined,
        HyperosIconColors.indigo,
        l10n.statisticsTimeLatest,
        stats.latestEnd,
      ),
      (
        Icons.free_breakfast_outlined,
        HyperosIconColors.yellow,
        l10n.statisticsTimeMorning,
        '${stats.morningSections} ${l10n.statisticsSectionsUnit}',
      ),
      (
        Icons.restaurant_outlined,
        HyperosIconColors.teal,
        l10n.statisticsTimeNoon,
        '${stats.noonSections} ${l10n.statisticsSectionsUnit}',
      ),
      (
        Icons.bedtime_outlined,
        HyperosIconColors.purple,
        l10n.statisticsTimeEvening,
        '${stats.eveningSections} ${l10n.statisticsSectionsUnit}',
      ),
      (
        Icons.weekend_outlined,
        HyperosIconColors.blue,
        l10n.statisticsTimeWeekend,
        '${stats.weekendSections} ${l10n.statisticsSectionsUnit}',
      ),
      (
        Icons.hourglass_bottom_rounded,
        HyperosIconColors.red,
        l10n.statisticsTimeGap,
        l10n.statisticsTimeGapValue(stats.maxDailyGapSections),
      ),
    ];

    Widget fact(IconData icon, Color accent, String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Icon(icon, size: 16, color: accent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: labelStyle),
            ),
            const SizedBox(width: 6),
            Text(
              value,
              // T2 弹窗/行内数据值
              style: HyperosTypography.listTitle(context).copyWith(
                fontSize: HyperosMiuixTypography.footnote2,
                fontWeight: FontWeight.w600,
                color: HyperosColors.primaryText(context),
              ),
            ),
          ],
        ),
      );
    }

    return HyperosControlCard(
      child: HyperosControlCardInset(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const HyperosIconBadge(
                  icon: Icons.schedule_rounded,
                  accent: HyperosIconColors.cyan,
                ),
                const SizedBox(width: HyperosTokens.rowContentGap),
                Text(
                  l10n.statisticsTimeUtilTitle,
                  style: HyperosTypography.listTitle(context),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (var index = 0; index < rows.length; index++) ...[
              if (index > 0)
                const HyperosInsetDivider(indent: 0),
              fact(rows[index].$1, rows[index].$2, rows[index].$3, rows[index].$4),
            ],
          ],
        ),
      ),
    );
  }
}
