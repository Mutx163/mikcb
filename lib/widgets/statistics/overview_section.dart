import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../../models/statistics_models.dart';

/// 学期总览区域（大数字展示）
class OverviewSection extends StatelessWidget {
  final SemesterStats stats;

  const OverviewSection({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    if (stats.totalCourses == 0) {
      return const SizedBox.shrink();
    }

    return FCard.raw(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer,
              colorScheme.tertiaryContainer,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            // 第一行：总课程门数 + 总课时数
            Row(
              children: [
                Expanded(
                  child: _BigNumber(
                    icon: Icons.menu_book_rounded,
                    value: '${stats.totalCourses}',
                    label: l10n.statisticsSemesterLabelCourses,
                    colorScheme: colorScheme,
                  ),
                ),
                Container(
                  width: 1,
                  height: 48,
                  color: colorScheme.onPrimaryContainer.withValues(alpha: 0.15),
                ),
                Expanded(
                  child: _BigNumber(
                    icon: Icons.schedule_rounded,
                    value: '${stats.totalSections}',
                    label: l10n.statisticsSemesterLabelSections,
                    colorScheme: colorScheme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 第二行：上课周数 + 最长连续天数
            Row(
              children: [
                Expanded(
                  child: _BigNumber(
                    icon: Icons.calendar_today_rounded,
                    value: '${stats.totalWeeks}',
                    label: l10n.statisticsSemesterLabelWeeks,
                    colorScheme: colorScheme,
                  ),
                ),
                Container(
                  width: 1,
                  height: 48,
                  color: colorScheme.onPrimaryContainer.withValues(alpha: 0.15),
                ),
                Expanded(
                  child: _BigNumber(
                    icon: Icons.local_fire_department_rounded,
                    value: '${stats.longestStreak}',
                    label: l10n.statisticsSemesterLabelDayStreak,
                    colorScheme: colorScheme,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BigNumber extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final ColorScheme colorScheme;

  const _BigNumber({
    required this.icon,
    required this.value,
    required this.label,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 24,
          color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: colorScheme.onPrimaryContainer,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
