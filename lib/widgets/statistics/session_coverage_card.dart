import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../domain/course_session_stats.dart';

/// 记录覆盖卡：这门课有多少次课留下了备注 / 作业 / 提醒。
///
/// 判断「值不值得补记录」靠这三个数，而不是要求用户额外填表：
/// 数据本来就散落在课程备注、作业清单、上课提醒里，这里只是把它们按
/// 课次对齐后数一遍。
///
/// 分母是 [CourseSessionStats.sessions.length]（全部列出的课次，含停课与
/// 假期）：停课周不清备注，那次的记录真实存在、列表里也可见；分子分母
/// 同口径才不会出现「3 / 1」这种超过 100% 的数字，且与汇总卡「课次」
/// 天然对齐。
class SessionCoverageCard extends StatelessWidget {
  const SessionCoverageCard({super.key, required this.stats});

  final CourseSessionStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final total = stats.sessions.length;
    if (total == 0) {
      return HyperosControlCard(
        child: HyperosControlCardInset(
          child: Text(
            l10n.statisticsSessionEmpty,
            style: HyperosTypography.listDetail(context),
          ),
        ),
      );
    }

    return HyperosControlCard(
      child: HyperosControlCardInset(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CoverageRow(
              label: l10n.statisticsSessionCoverageNote,
              count: stats.notedSessions,
              total: total,
              color: HyperosIconColors.blue,
            ),
            const SizedBox(height: 12),
            _CoverageRow(
              label: l10n.statisticsSessionCoverageHomework,
              count: stats.homeworkSessions,
              total: total,
              color: HyperosIconColors.orange,
            ),
            const SizedBox(height: 12),
            _CoverageRow(
              label: l10n.statisticsSessionCoverageReminder,
              count: stats.reminderSessions,
              total: total,
              color: HyperosIconColors.purple,
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverageRow extends StatelessWidget {
  const _CoverageRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  final String label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = total <= 0 ? 0.0 : (count / total).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HyperosTypography.listDetail(context),
              ),
            ),
            Text(
              '$count / $total',
              style: HyperosTypography.listDetail(context).copyWith(
                fontWeight: FontWeight.w500,
                color: HyperosColors.primaryText(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: HyperosColors.dividerLine(context),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
