import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../models/statistics_models.dart';

/// 学期进度卡（校历对齐：日期范围 + 课时进度）
class SemesterProgressCard extends StatelessWidget {
  final SemesterProgress progress;

  const SemesterProgressCard({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasDates = progress.semesterStartDate != null;
    final isBeforeStart = progress.phase == SemesterProgressPhase.beforeStart;

    final startLabel = hasDates
        ? DateFormat.yMMMd(l10n.localeName).format(progress.semesterStartDate!)
        : '';
    final endLabel = hasDates
        ? DateFormat.yMMMd(l10n.localeName).format(progress.semesterEndDate!)
        : '';
    final asOfLabel = hasDates
        ? DateFormat.MMMd(l10n.localeName).format(progress.currentDate!)
        : '';

    return HyperosControlCard(
      child: HyperosControlCardInset(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题行：标题居左，周数右上角
            Row(
              children: [
                const HyperosIconBadge(
                  icon: Icons.trending_up_rounded,
                ),
                const SizedBox(width: HyperosTokens.rowContentGap),
                Expanded(
                  child: Text(
                    l10n.statisticsSemesterProgressTitle,
                    style: HyperosTypography.listTitle(context),
                  ),
                ),
                Text(
                  '${progress.weeksElapsed}/${progress.totalWeeks}',
                  // T2 行内数据值：用主题色强调，不靠超粗字重
                  style: HyperosTypography.listTitle(context).copyWith(
                    fontWeight: FontWeight.w600,
                    color: HyperosColors.primary(context),
                  ),
                ),
              ],
            ),
            // 日期行：独占整行，不再被右侧挤压换行
            if (hasDates) ...[
              const SizedBox(height: 6),
              Text(
                l10n.statisticsSemesterProgressRange(startLabel, endLabel),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HyperosTypography.listDetail(context).copyWith(
                  fontSize: HyperosMiuixTypography.footnote2,
                ),
              ),
            ],
            const SizedBox(height: 12),
            HyperosLinearProgress(value: progress.percent),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _ProgressFact(
                    label: isBeforeStart
                        ? l10n.statisticsSemesterProgressNotStarted
                        : l10n.statisticsSemesterProgressDetail(
                            progress.weeksElapsed,
                            progress.sectionsDone,
                            progress.sectionsTotal,
                          ),
                    value: '${(progress.percent * 100).round()}%',
                  ),
                ),
                if (!isBeforeStart) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ProgressFact(
                      label: hasDates
                          ? l10n.statisticsSemesterProgressAsOf(asOfLabel)
                          : l10n.statisticsSemesterProgressEstimated,
                      value: l10n.statisticsSemesterProgressRemaining(
                        progress.remainingSections,
                      ),
                      alignEnd: true,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressFact extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;

  const _ProgressFact({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          // 次级口径（% / 剩余 X 节）保留 18 号层级，只收口样式。
          style: HyperosTypography.metricMedium(context),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: HyperosTypography.metricCaption(context),
        ),
      ],
    );
  }
}
