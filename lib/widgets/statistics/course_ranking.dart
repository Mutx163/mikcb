import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../models/course.dart';
import '../../models/statistics_models.dart';

/// 课程排行（按整个学期课时排序）
class CourseRanking extends StatelessWidget {
  final List<CourseSemesterStat> courseRanking;

  const CourseRanking({super.key, required this.courseRanking});

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

    return HyperosListGroup(
      children: [
        for (var index = 0; index < courseRanking.length; index++)
          _CourseRankingTile(
            stat: courseRanking[index],
            rank: index + 1,
          ),
      ],
    );
  }
}

class _CourseRankingTile extends StatefulWidget {
  final CourseSemesterStat stat;
  final int rank;

  const _CourseRankingTile({required this.stat, required this.rank});

  @override
  State<_CourseRankingTile> createState() => _CourseRankingTileState();
}

class _CourseRankingTileState extends State<_CourseRankingTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scope = HyperosListTileScope.maybeOf(context);
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);
    final isRequired = widget.stat.nature == CourseNature.required;

    final row = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: HyperosTokens.listRowTwoLineMinHeight,
      ),
      child: Padding(
        padding: HyperosTokens.rowPadding(
          isFirst: scope?.isFirst ?? true,
          isLast: (scope?.isLast ?? true) && !_isExpanded,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RankBadge(rank: widget.rank),
            const SizedBox(width: HyperosTokens.rowContentGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.stat.name,
                          maxLines: 1,
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
                  if (widget.stat.teacher.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.stat.teacher,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HyperosTypography.listDetail(context),
                    ),
                  ],
                  if (widget.stat.slots.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: widget.stat.slots.map((slot) {
                        return HyperosTag(
                          label: _slotLabel(l10n, slot),
                          outlined: true,
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${widget.stat.totalSections}',
                  style: HyperosTypography.listTitle(context).copyWith(
                    fontWeight: FontWeight.w800,
                    color: HyperosTokens.accent,
                  ),
                ),
                Text(
                  l10n.statisticsSectionsUnit,
                  style: HyperosTypography.listDetail(context),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: HyperosColors.actionIcon(context),
            ),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HyperosPressableRow(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          backgroundColor: cardColor,
          highlightColor: highlightColor,
          child: row,
        ),
        if (_isExpanded) _buildExpandedDetail(context, l10n),
      ],
    );
  }

  Widget _buildExpandedDetail(BuildContext context, AppLocalizations l10n) {
    const rankBadgeSize = 36.0;
    final dividerIndent =
        HyperosMiuixSpec.settingsRowPadding.left +
        rankBadgeSize +
        HyperosTokens.rowContentGap;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HyperosInsetDivider(indent: dividerIndent),
        Padding(
          padding: EdgeInsets.fromLTRB(
            dividerIndent,
            10,
            HyperosMiuixSpec.settingsRowPadding.right,
            scopeBottomPadding(context),
          ),
          child: Column(
            children: [
              for (var i = 0; i < widget.stat.slots.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _SlotDetailRow(slot: widget.stat.slots[i], l10n: l10n),
              ],
            ],
          ),
        ),
      ],
    );
  }

  double scopeBottomPadding(BuildContext context) {
    final scope = HyperosListTileScope.maybeOf(context);
    return scope?.isLast ?? true ? 12 : 0;
  }

  String _slotLabel(AppLocalizations l10n, CourseSlot slot) {
    final dayLabel = _weekdayShortLabel(l10n, slot.dayOfWeek);
    final sections = slot.startSection == slot.endSection
        ? '${slot.startSection}'
        : '${slot.startSection}-${slot.endSection}';
    return '$dayLabel $sections${l10n.statisticsSectionUnit}';
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

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

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
              style: HyperosTypography.listTitle(context).copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}

class _SlotDetailRow extends StatelessWidget {
  const _SlotDetailRow({required this.slot, required this.l10n});

  final CourseSlot slot;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final dayLabel = _weekdayFullLabel(l10n, slot.dayOfWeek);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.schedule_rounded,
          size: 16,
          color: HyperosColors.actionIcon(context),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l10n.statisticsRankingSlotDetail(
              dayLabel,
              slot.startSection,
              slot.endSection,
            ),
            style: HyperosTypography.listDetail(context),
          ),
        ),
        if (slot.location.isNotEmpty) ...[
          Icon(
            Icons.location_on_outlined,
            size: 16,
            color: HyperosColors.actionIcon(context),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              slot.location,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: HyperosTypography.listDetail(context),
            ),
          ),
        ],
      ],
    );
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
