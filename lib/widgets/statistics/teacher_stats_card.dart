import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../models/statistics_models.dart';

/// 教师课时排行卡
class TeacherStatsCard extends StatelessWidget {
  final List<TeacherStat> stats;

  const TeacherStatsCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (stats.isEmpty) {
      return const SizedBox.shrink();
    }

    return HyperosControlCard(
      edgeToEdge: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: HyperosTokens.rowPadding(isFirst: true, isLast: false),
            child: Row(
              children: [
                HyperosIconBadge(
                  icon: Icons.school_outlined,
                  accent: HyperosIconColors.green,
                ),
                const SizedBox(width: HyperosTokens.rowContentGap),
                Text(
                  l10n.statisticsTeacherTitle,
                  style: HyperosTypography.listTitle(context),
                ),
              ],
            ),
          ),
          for (var i = 0; i < stats.length; i++) ...[
            HyperosInsetDivider(indent: HyperosTokens.listTileDividerIndent),
            Padding(
              padding: HyperosTokens.rowPadding(
                isFirst: false,
                isLast: i == stats.length - 1,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${i + 1}',
                      style: HyperosTypography.listDetail(context).copyWith(
                        fontWeight: FontWeight.w800,
                        color: i < 3
                            ? HyperosIconColors.yellow
                            : HyperosColors.secondaryText(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: HyperosTokens.rowContentGap),
                  Expanded(
                    child: Text(
                      stats[i].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HyperosTypography.listTitle(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.statisticsTeacherCourseCount(stats[i].courseCount),
                    style: HyperosTypography.listDetail(context).copyWith(
                      fontSize: HyperosMiuixTypography.footnote2,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${stats[i].sections} ${l10n.statisticsSectionsUnit}',
                    style: HyperosTypography.listTitle(context).copyWith(
                      fontWeight: FontWeight.w800,
                      color: HyperosColors.primary(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
