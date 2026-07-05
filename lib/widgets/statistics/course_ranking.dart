import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../../models/course.dart';
import '../../models/statistics_models.dart';

/// 课程排行（按整个学期课时排序）
class CourseRanking extends StatelessWidget {
  final List<CourseSemesterStat> courseRanking;

  const CourseRanking({super.key, required this.courseRanking});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.theme;

    if (courseRanking.isEmpty) {
      return FCard.raw(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              l10n.statisticsNoData,
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          ),
        ),
      );
    }

    return FCard.raw(
      child: Column(
        children: List.generate(courseRanking.length, (index) {
          final stat = courseRanking[index];
          final isLast = index == courseRanking.length - 1;
          return _CourseRankingTile(
            stat: stat,
            rank: index + 1,
            isLast: isLast,
          );
        }),
      ),
    );
  }
}

class _CourseRankingTile extends StatefulWidget {
  final CourseSemesterStat stat;
  final int rank;
  final bool isLast;

  const _CourseRankingTile({
    required this.stat,
    required this.rank,
    required this.isLast,
  });

  @override
  State<_CourseRankingTile> createState() => _CourseRankingTileState();
}

class _CourseRankingTileState extends State<_CourseRankingTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isRequired = widget.stat.nature == CourseNature.required;

    // 排名颜色
    Color? rankColor;
    if (widget.rank == 1) {
      rankColor = Colors.amber;
    } else if (widget.rank == 2) {
      rankColor = Colors.grey[400];
    } else if (widget.rank == 3) {
      rankColor = Colors.brown[300];
    }

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // 排名
                SizedBox(
                  width: 28,
                  child: rankColor != null
                      ? Icon(
                          Icons.emoji_events_rounded,
                          size: 20,
                          color: rankColor,
                        )
                      : Text(
                          '${widget.rank}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                // 左侧信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.stat.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: isRequired
                                  ? colorScheme.primary.withValues(alpha: 0.12)
                                  : colorScheme.tertiary.withValues(
                                      alpha: 0.12,
                                    ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isRequired
                                  ? l10n.courseNatureRequired
                                  : l10n.courseNatureElective,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isRequired
                                    ? colorScheme.primary
                                    : colorScheme.tertiary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (widget.stat.teacher.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.stat.teacher,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      // 时间标签
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: widget.stat.slots.map((slot) {
                          final dayLabel = _weekdayShortLabel(
                            l10n,
                            slot.dayOfWeek,
                          );
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$dayLabel ${slot.startSection}-${widget.stat.slots.length > 1 ? slot.endSection : ''}${l10n.statisticsSectionUnit}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // 右侧课时数 + 展开图标
                Column(
                  children: [
                    Text(
                      '${widget.stat.totalSections}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: colorScheme.primary,
                      ),
                    ),
                    Text(
                      l10n.statisticsSectionsUnit,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                Icon(
                  _isExpanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        // 展开的详情
        if (_isExpanded)
          _buildExpandedDetail(context, l10n, theme, colorScheme),
        if (!widget.isLast)
          Divider(
            height: 1,
            indent: 52,
            endIndent: 16,
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
      ],
    );
  }

  Widget _buildExpandedDetail(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(52, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          // 详细信息
          ...widget.stat.slots.map((slot) {
            final dayLabel = _weekdayFullLabel(l10n, slot.dayOfWeek);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.statisticsRankingSlotDetail(
                        dayLabel,
                        slot.startSection,
                        slot.endSection,
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  if (slot.location.isNotEmpty) ...[
                    Icon(
                      Icons.location_on_rounded,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        slot.location,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _weekdayShortLabel(AppLocalizations l10n, int dayOfWeek) {
    return switch (dayOfWeek) {
      1 => l10n.weekdayShortMonday,
      2 => l10n.weekdayShortTuesday,
      3 => l10n.weekdayShortWednesday,
      4 => l10n.weekdayShortThursday,
      5 => l10n.weekdayShortFriday,
      6 => l10n.weekdayShortSaturday,
      7 => l10n.weekdayShortSunday,
      _ => dayOfWeek.toString(),
    };
  }

  String _weekdayFullLabel(AppLocalizations l10n, int dayOfWeek) {
    return switch (dayOfWeek) {
      1 => l10n.weekdayMon,
      2 => l10n.weekdayTue,
      3 => l10n.weekdayWed,
      4 => l10n.weekdayThu,
      5 => l10n.weekdayFri,
      6 => l10n.weekdaySat,
      7 => l10n.weekdaySun,
      _ => dayOfWeek.toString(),
    };
  }
}
