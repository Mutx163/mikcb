import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
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
    final theme = context.theme;

    if (stats.totalCourses == 0) {
      return const SizedBox.shrink();
    }

    return HyperosCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _MetricCell(
                      icon: Icons.menu_book_rounded,
                      value: '${stats.totalCourses}',
                      label: l10n.statisticsSemesterLabelCourses,
                    ),
                  ),
                  const _VerticalDivider(),
                  Expanded(
                    child: _MetricCell(
                      icon: Icons.schedule_rounded,
                      value: '${stats.totalSections}',
                      label: l10n.statisticsSemesterLabelSections,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Divider(
                height: 1,
                color: theme.colors.border.withValues(alpha: 0.6),
              ),
            ),
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _MetricCell(
                      icon: Icons.calendar_today_rounded,
                      value: '${stats.totalWeeks}',
                      label: l10n.statisticsSemesterLabelWeeks,
                    ),
                  ),
                  const _VerticalDivider(),
                  Expanded(
                    child: _MetricCell(
                      icon: Icons.local_fire_department_rounded,
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
  final String value;
  final String label;

  const _MetricCell({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22, color: theme.colors.primary),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: theme.typography.display.sm.copyWith(
            fontWeight: FontWeight.w900,
            color: theme.colors.foreground,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: theme.typography.body.xs.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: theme.colors.border.withValues(alpha: 0.6),
    );
  }
}
