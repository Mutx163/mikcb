import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../models/statistics_models.dart';

/// 学期总览区域（大数字展示）
class OverviewSection extends StatelessWidget {
  final SemesterStats stats;

  const OverviewSection({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (stats.totalCourses == 0) {
      return const SizedBox.shrink();
    }

    return HyperosControlCard(
      child: HyperosControlCardInset(
        child: Column(
          children: [
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _MetricCell(
                      icon: Icons.menu_book_rounded,
                      accent: HyperosIconColors.blue,
                      value: '${stats.totalCourses}',
                      label: l10n.statisticsSemesterLabelCourses,
                    ),
                  ),
                  const _VerticalDivider(),
                  Expanded(
                    child: _MetricCell(
                      icon: Icons.schedule_rounded,
                      accent: HyperosIconColors.teal,
                      value: '${stats.totalSections}',
                      label: l10n.statisticsSemesterLabelSections,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: HyperosTokens.divider),
            ),
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _MetricCell(
                      icon: Icons.calendar_today_rounded,
                      accent: HyperosIconColors.indigo,
                      value: '${stats.totalWeeks}',
                      label: l10n.statisticsSemesterLabelWeeks,
                    ),
                  ),
                  const _VerticalDivider(),
                  Expanded(
                    child: _MetricCell(
                      icon: Icons.local_fire_department_rounded,
                      accent: HyperosIconColors.orange,
                      value: '${stats.longestStreak}',
                      label: l10n.statisticsSemesterLabelDayStreak,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String value;
  final String label;

  const _MetricCell({
    required this.icon,
    required this.accent,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HyperosIconBadge(icon: icon, accent: accent),
        const SizedBox(height: 10),
        Text(
          value,
          style: HyperosTypography.listTitle(context).copyWith(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1,
            color: HyperosColors.primaryText(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: HyperosTypography.listDetail(context),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: HyperosTokens.divider,
    );
  }
}
