import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../models/statistics_models.dart';

/// 时间利用分析卡
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

    Widget fact(IconData icon, Color accent, String label, String value) {
      return Row(
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: labelStyle),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: HyperosTypography.listTitle(context).copyWith(
              fontSize: HyperosMiuixTypography.footnote2,
              fontWeight: FontWeight.w700,
              color: HyperosColors.primaryText(context),
            ),
          ),
        ],
      );
    }

    return HyperosControlCard(
      child: HyperosControlCardInset(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                HyperosIconBadge(
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 150,
                  child: fact(
                    Icons.wb_sunny_outlined,
                    HyperosIconColors.orange,
                    l10n.statisticsTimeEarliest,
                    stats.earliestStart,
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: fact(
                    Icons.nights_stay_outlined,
                    HyperosIconColors.indigo,
                    l10n.statisticsTimeLatest,
                    stats.latestEnd,
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: fact(
                    Icons.free_breakfast_outlined,
                    HyperosIconColors.yellow,
                    l10n.statisticsTimeMorning,
                    '${stats.morningSections} ${l10n.statisticsSectionsUnit}',
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: fact(
                    Icons.restaurant_outlined,
                    HyperosIconColors.teal,
                    l10n.statisticsTimeNoon,
                    '${stats.noonSections} ${l10n.statisticsSectionsUnit}',
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: fact(
                    Icons.bedtime_outlined,
                    HyperosIconColors.purple,
                    l10n.statisticsTimeEvening,
                    '${stats.eveningSections} ${l10n.statisticsSectionsUnit}',
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: fact(
                    Icons.weekend_outlined,
                    HyperosIconColors.blue,
                    l10n.statisticsTimeWeekend,
                    '${stats.weekendSections} ${l10n.statisticsSectionsUnit}',
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: fact(
                    Icons.hourglass_bottom_rounded,
                    HyperosIconColors.red,
                    l10n.statisticsTimeGap,
                    l10n.statisticsTimeGapValue(stats.maxDailyGapSections),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
