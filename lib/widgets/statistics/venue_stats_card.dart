import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../models/statistics_models.dart';

/// 教室与教学楼统计卡
class VenueStatsCard extends StatelessWidget {
  final VenueStats stats;

  const VenueStatsCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (stats.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxRoom = stats.topRooms.isEmpty
        ? 1
        : stats.topRooms.first.visits;
    final maxBuilding = stats.buildings.isEmpty
        ? 1
        : stats.buildings.first.sections;

    return HyperosControlCard(
      child: HyperosControlCardInset(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                HyperosIconBadge(
                  icon: Icons.location_city_rounded,
                  accent: HyperosIconColors.purple,
                ),
                const SizedBox(width: HyperosTokens.rowContentGap),
                Text(
                  l10n.statisticsVenueTitle,
                  style: HyperosTypography.listTitle(context),
                ),
              ],
            ),
            if (stats.topRooms.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                l10n.statisticsVenueTopRooms,
                style: HyperosTypography.sectionLabel(context),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < stats.topRooms.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _BarRow(
                  label: stats.topRooms[i].name,
                  value: l10n.statisticsVenueVisits(stats.topRooms[i].visits),
                  ratio: stats.topRooms[i].visits / maxRoom,
                  color: HyperosIconColors.blue,
                ),
              ],
            ],
            if (stats.buildings.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                l10n.statisticsVenueBuildings,
                style: HyperosTypography.sectionLabel(context),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < stats.buildings.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _BarRow(
                  label: stats.buildings[i].name,
                  value: '${stats.buildings[i].sections} ${l10n.statisticsSectionsUnit}',
                  ratio: stats.buildings[i].sections / maxBuilding,
                  color: HyperosIconColors.teal,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  final String label;
  final String value;
  final double ratio;
  final Color color;

  const _BarRow({
    required this.label,
    required this.value,
    required this.ratio,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HyperosTypography.listDetail(context),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0).toDouble(),
              minHeight: 6,
              color: color,
              backgroundColor: HyperosColors.rowHighlight(context),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 64,
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HyperosTypography.listDetail(context).copyWith(
              // T2 行内数据值（14px 小字，w500 足够）
              fontWeight: FontWeight.w500,
              color: HyperosColors.primaryText(context),
            ),
          ),
        ),
      ],
    );
  }
}
