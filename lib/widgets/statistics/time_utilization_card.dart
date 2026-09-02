import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../models/statistics_models.dart';

/// 时间利用卡单行读数：图标 + 强调色 + 标签 + 读数。
typedef _TimeRow = ({IconData icon, Color accent, String label, String value});

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

    final rows = <_TimeRow>[
      (
        icon: Icons.wb_sunny_outlined,
        accent: HyperosIconColors.orange,
        label: l10n.statisticsTimeEarliest,
        value: stats.earliestStart,
      ),
      (
        icon: Icons.nights_stay_outlined,
        accent: HyperosIconColors.indigo,
        label: l10n.statisticsTimeLatest,
        value: stats.latestEnd,
      ),
      (
        icon: Icons.free_breakfast_outlined,
        accent: HyperosIconColors.yellow,
        label: l10n.statisticsTimeMorning,
        value: '${stats.morningSections} ${l10n.statisticsSectionsUnit}',
      ),
      (
        icon: Icons.restaurant_outlined,
        accent: HyperosIconColors.teal,
        label: l10n.statisticsTimeNoon,
        value: '${stats.noonSections} ${l10n.statisticsSectionsUnit}',
      ),
      (
        icon: Icons.bedtime_outlined,
        accent: HyperosIconColors.purple,
        label: l10n.statisticsTimeEvening,
        value: '${stats.eveningSections} ${l10n.statisticsSectionsUnit}',
      ),
      (
        icon: Icons.weekend_outlined,
        accent: HyperosIconColors.blue,
        label: l10n.statisticsTimeWeekend,
        value: '${stats.weekendSections} ${l10n.statisticsSectionsUnit}',
      ),
      (
        icon: Icons.hourglass_bottom_rounded,
        accent: HyperosIconColors.red,
        label: l10n.statisticsTimeGap,
        value: l10n.statisticsTimeGapValue(stats.maxDailyGapSections),
      ),
    ];

    Widget fact(_TimeRow row) {
      // earliestStart / latestEnd 兜底为空串时，纵向布局会出现空读数行，
      // 统一回退到「暂无课程数据」文案。
      final displayValue =
          row.value.isEmpty ? l10n.statisticsNoData : row.value;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(row.icon, size: 16, color: row.accent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                row.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              displayValue,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
            const SizedBox(height: 8),
            for (var index = 0; index < rows.length; index++) ...[
              if (index > 0) const HyperosInsetDivider(indent: 0),
              fact(rows[index]),
            ],
          ],
        ),
      ),
    );
  }
}
