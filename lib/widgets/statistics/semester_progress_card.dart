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
            Row(
              children: [
                HyperosIconBadge(
                  icon: Icons.trending_up_rounded,
                  accent: HyperosIconColors.blue,
                ),
                const SizedBox(width: HyperosTokens.rowContentGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.statisticsSemesterProgressTitle,
                        style: HyperosTypography.listTitle(context),
                      ),
                      if (hasDates) ...[
                        const SizedBox(height: 2),
                        Text(
                          l10n.statisticsSemesterProgressRange(
                            startLabel,
                            endLabel,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HyperosTypography.listDetail(context),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  '${progress.weeksElapsed}/${progress.totalWeeks}',
                  style: HyperosTypography.listTitle(context).copyWith(
                    fontWeight: FontWeight.w800,
                    color: HyperosColors.primary(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            HyperosLinearProgress(value: progress.percent),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ProgressFact(
                    label: l10n.statisticsSemesterProgressDetail(
                      progress.sectionsDone,
                      progress.sectionsTotal,
                    ),
                    value: '${(progress.percent * 100).round()}%',
                  ),
                ),
                if (hasDates) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ProgressFact(
                      label: l10n.statisticsSemesterProgressAsOf(asOfLabel),
                      value: l10n.statisticsSemesterProgressRemaining(
                        progress.remainingSections,
                      ),
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

  const _ProgressFact({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: HyperosTypography.listTitle(context).copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: HyperosColors.primaryText(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: HyperosTypography.listDetail(context).copyWith(
            fontSize: HyperosMiuixTypography.footnote2,
          ),
        ),
      ],
    );
  }
}
