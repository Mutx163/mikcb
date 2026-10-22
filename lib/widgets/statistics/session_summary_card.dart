import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../domain/course_session_stats.dart';

/// 单节课汇总（单行四指标：课次 / 已过 / 课时 / 有备注）。
///
/// 口径与 [OverviewSection] 一致（24px 数字 + footnote2 标签、细分隔线），
/// 首格用主题色强调。
class SessionSummaryCard extends StatelessWidget {
  const SessionSummaryCard({super.key, required this.stats});

  final CourseSessionStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (stats.isEmpty) {
      return const SizedBox.shrink();
    }

    final divider = Container(
      width: 1,
      height: 28,
      color: HyperosColors.dividerLine(context),
    );

    return HyperosControlCard(
      child: Row(
        children: [
          _SessionMetricCell(
            value: '${stats.sessions.length}',
            label: l10n.statisticsSessionMetricSessions,
            highlight: true,
          ),
          divider,
          _SessionMetricCell(
            value: '${stats.doneSessions}',
            label: l10n.statisticsSessionMetricDone,
          ),
          divider,
          _SessionMetricCell(
            value: '${stats.doneSections}',
            label: l10n.statisticsSessionMetricSections,
          ),
          divider,
          _SessionMetricCell(
            value: '${stats.notedSessions}',
            label: l10n.statisticsSessionMetricNoted,
          ),
        ],
      ),
    );
  }
}

class _SessionMetricCell extends StatelessWidget {
  const _SessionMetricCell({
    required this.value,
    required this.label,
    this.highlight = false,
  });

  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: HyperosTypography.metricLarge(context).copyWith(
                color: highlight
                    ? HyperosColors.primary(context)
                    : HyperosColors.primaryText(context),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: HyperosTypography.metricCaption(context).copyWith(
                color: highlight
                    ? HyperosColors.primaryText(context)
                    : HyperosColors.secondaryText(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
