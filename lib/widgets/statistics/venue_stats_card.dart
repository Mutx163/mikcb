import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../models/statistics_models.dart';

/// 教室与教学楼统计卡
///
/// [standalone] 用于深度分析独立二级页：卡内标题与页面大标题重复，
/// 略去；行读数从小卡 14px 放大到正文刻度、标签列加宽，
/// 避免整页只顶着一小条字、下方大片留白。
class VenueStatsCard extends StatelessWidget {
  final VenueStats stats;

  final bool standalone;

  const VenueStatsCard({
    super.key,
    required this.stats,
    this.standalone = false,
  });

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
            if (!standalone)
              Row(
                children: [
                  const HyperosIconBadge(
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
                style: standalone
                    ? HyperosTypography.listDetail(context)
                    : HyperosTypography.sectionLabel(context),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < stats.topRooms.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _BarRow(
                  label: stats.topRooms[i].name,
                  value: l10n.statisticsVenueVisits(stats.topRooms[i].visits),
                  ratio: stats.topRooms[i].visits / maxRoom,
                  color: HyperosIconColors.blue,
                  standalone: standalone,
                ),
              ],
            ],
            if (stats.buildings.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                l10n.statisticsVenueBuildings,
                style: standalone
                    ? HyperosTypography.listDetail(context)
                    : HyperosTypography.sectionLabel(context),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < stats.buildings.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _BarRow(
                  label: stats.buildings[i].name,
                  value: '${stats.buildings[i].sections} ${l10n.statisticsSectionsUnit}',
                  ratio: stats.buildings[i].sections / maxBuilding,
                  color: HyperosIconColors.teal,
                  standalone: standalone,
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

  /// 独立二级页模式：读数放大到正文刻度、标签列加宽。
  final bool standalone;

  const _BarRow({
    required this.label,
    required this.value,
    required this.ratio,
    required this.color,
    this.standalone = false,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = standalone
        ? HyperosTypography.listDetail(context).copyWith(
            fontSize: HyperosMiuixTypography.body1,
            color: HyperosColors.primaryText(context),
          )
        : HyperosTypography.listDetail(context);
    final valueStyle = standalone
        ? HyperosTypography.listDetail(context).copyWith(
            fontSize: HyperosMiuixTypography.body1,
            fontWeight: FontWeight.w500,
            color: HyperosColors.primaryText(context),
          )
        : HyperosTypography.listDetail(context).copyWith(
            // T2 行内数据值（14px 小字，w500 足够）
            fontWeight: FontWeight.w500,
            color: HyperosColors.primaryText(context),
          );

    return Row(
      children: [
        SizedBox(
          width: standalone ? 140 : 110,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(standalone ? 4 : 3),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0).toDouble(),
              minHeight: standalone ? 8 : 6,
              color: color,
              backgroundColor: HyperosColors.rowHighlight(context),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: standalone ? 72 : 64,
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: valueStyle,
          ),
        ),
      ],
    );
  }
}
