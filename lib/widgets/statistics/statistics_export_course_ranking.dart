import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../models/course.dart';
import '../../models/statistics_models.dart';

/// Compact course ranking for long-image / PDF export.
///
/// Differs from interactive [CourseRanking]: no expand chevrons, single-line
/// schedule summary, and a hard cap so GPU texture limits are not blown.
class StatisticsExportCourseRanking extends StatelessWidget {
  const StatisticsExportCourseRanking({
    super.key,
    required this.courseRanking,
    this.maxItems = maxExportRankingItems,
  });

  /// Safe default so full-module export stays within device texture height.
  static const int maxExportRankingItems = 20;

  final List<CourseSemesterStat> courseRanking;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (courseRanking.isEmpty) {
      return HyperosControlCard(
        child: HyperosControlCardInset(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                l10n.statisticsNoData,
                style: HyperosTypography.listDetail(context),
              ),
            ),
          ),
        ),
      );
    }

    final visibleItems = courseRanking.take(maxItems).toList(growable: false);
    final remainingCount = courseRanking.length - visibleItems.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        HyperosListGroup(
          children: [
            for (var index = 0; index < visibleItems.length; index++)
              _ExportRankingTile(stat: visibleItems[index], rank: index + 1),
          ],
        ),
        if (remainingCount > 0) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              l10n.statisticsExportRankingMore(remainingCount),
              textAlign: TextAlign.center,
              style: HyperosTypography.listDetail(context),
            ),
          ),
        ],
      ],
    );
  }
}

class _ExportRankingTile extends StatelessWidget {
  const _ExportRankingTile({required this.stat, required this.rank});

  final CourseSemesterStat stat;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scope = HyperosListTileScope.maybeOf(context);
    final isRequired = stat.nature == CourseNature.required;
    final scheduleSummary = _buildScheduleSummary(l10n);

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: HyperosTokens.listRowTwoLineMinHeight,
      ),
      child: Padding(
        padding: HyperosTokens.rowPadding(
          isFirst: scope?.isFirst ?? true,
          isLast: scope?.isLast ?? true,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _ExportRankBadge(rank: rank),
            const SizedBox(width: HyperosTokens.rowContentGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          stat.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: HyperosTypography.listTitle(context),
                        ),
                      ),
                      const SizedBox(width: 6),
                      HyperosTag(
                        label: isRequired
                            ? l10n.courseNatureRequired
                            : l10n.courseNatureElective,
                        backgroundColor: isRequired
                            ? HyperosIconColors.blue.withValues(alpha: 0.12)
                            : HyperosIconColors.purple.withValues(alpha: 0.12),
                        textStyle: HyperosTypography.listDetail(context)
                            .copyWith(
                              fontSize: HyperosMiuixTypography.footnote2,
                              fontWeight: FontWeight.w600,
                              color: isRequired
                                  ? HyperosIconColors.blue
                                  : HyperosIconColors.purple,
                            ),
                      ),
                    ],
                  ),
                  if (stat.teacher.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      stat.teacher,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HyperosTypography.listDetail(context),
                    ),
                  ],
                  if (scheduleSummary.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      scheduleSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HyperosTypography.listDetail(context),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${stat.totalSections}',
                  style: HyperosTypography.listTitle(context).copyWith(
                    fontWeight: FontWeight.w800,
                    color: HyperosColors.primary(context),
                  ),
                ),
                Text(
                  l10n.statisticsSectionsUnit,
                  style: HyperosTypography.listDetail(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _buildScheduleSummary(AppLocalizations l10n) {
    if (stat.slots.isEmpty) {
      return '';
    }
    final labels = stat.slots.take(3).map((slot) {
      final dayLabel = _weekdayShortLabel(l10n, slot.dayOfWeek);
      final sections = slot.startSection == slot.endSection
          ? '${slot.startSection}'
          : '${slot.startSection}-${slot.endSection}';
      return '$dayLabel $sections${l10n.statisticsSectionUnit}';
    }).toList();
    final joined = labels.join(' · ');
    if (stat.slots.length <= 3) {
      return joined;
    }
    return '$joined · …';
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
}

class _ExportRankBadge extends StatelessWidget {
  const _ExportRankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, icon) = switch (rank) {
      1 => (
        HyperosIconColors.yellow.withValues(alpha: 0.18),
        HyperosIconColors.yellow,
        Icons.emoji_events_rounded,
      ),
      2 => (
        HyperosColors.secondaryText(context).withValues(alpha: 0.14),
        HyperosColors.secondaryText(context),
        Icons.emoji_events_rounded,
      ),
      3 => (
        HyperosIconColors.orange.withValues(alpha: 0.16),
        HyperosIconColors.orange,
        Icons.emoji_events_rounded,
      ),
      _ => (
        HyperosColors.secondaryText(context).withValues(alpha: 0.1),
        HyperosColors.secondaryText(context),
        null,
      ),
    };

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: icon != null
          ? Icon(icon, size: 18, color: foreground)
          : Text(
              '$rank',
              style: HyperosTypography.listTitle(
                context,
              ).copyWith(color: foreground, fontWeight: FontWeight.w700),
            ),
    );
  }
}
