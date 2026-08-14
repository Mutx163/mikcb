import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

/// 单个课表（profile）的对比条目
class ProfileCompareEntry {
  final String name;
  final bool isActive;
  final int currentWeek;
  final int totalSections;
  final int totalCourses;
  final double requiredRatio;
  final int longestStreak;

  /// 相对当前课表的课时差（当前课表为 null）
  final int? deltaSections;

  const ProfileCompareEntry({
    required this.name,
    required this.isActive,
    required this.currentWeek,
    required this.totalSections,
    required this.totalCourses,
    required this.requiredRatio,
    required this.longestStreak,
    this.deltaSections,
  });
}

/// 课表对比卡：当前课表 vs 其他课表，点击行查看详情
class ProfileCompareCard extends StatelessWidget {
  final List<ProfileCompareEntry> entries;

  const ProfileCompareCard({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return HyperosControlCard(
      edgeToEdge: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: HyperosTokens.rowPadding(isFirst: true, isLast: false),
            child: Row(
              children: [
                HyperosIconBadge(
                  icon: Icons.compare_arrows_rounded,
                  accent: HyperosIconColors.indigo,
                ),
                const SizedBox(width: HyperosTokens.rowContentGap),
                Text(
                  l10n.statisticsCompareTitle,
                  style: HyperosTypography.listTitle(context),
                ),
              ],
            ),
          ),
          for (var i = 0; i < entries.length; i++) ...[
            HyperosInsetDivider(indent: HyperosTokens.listTileDividerIndent),
            _CompareRow(
              entry: entries[i],
              isLast: i == entries.length - 1,
            ),
          ],
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  final ProfileCompareEntry entry;
  final bool isLast;

  const _CompareRow({required this.entry, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scope = HyperosListTileScope.maybeOf(context);
    final delta = entry.deltaSections;

    return HyperosPressableRow(
      onTap: () => _showDetail(context),
      backgroundColor: HyperosColors.card(context),
      highlightColor: HyperosColors.rowHighlight(context),
      child: Padding(
        padding: HyperosTokens.rowPadding(
          isFirst: scope?.isFirst ?? true,
          isLast: isLast,
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: entry.isActive
                    ? HyperosColors.primary(context)
                    : HyperosColors.secondaryText(context).withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: HyperosTokens.rowContentGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HyperosTypography.listTitle(context).copyWith(
                            fontWeight: entry.isActive
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (entry.isActive) ...[
                        const SizedBox(width: 6),
                        HyperosTag(
                          label: l10n.statisticsCompareActive,
                          backgroundColor: HyperosColors.primary(
                            context,
                          ).withValues(alpha: 0.12),
                          textStyle: HyperosTypography.listDetail(context)
                              .copyWith(
                                fontSize: HyperosMiuixTypography.footnote2,
                                fontWeight: FontWeight.w600,
                                color: HyperosColors.primary(context),
                              ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.statisticsWeekSelector(entry.currentWeek),
                    style: HyperosTypography.listDetail(context).copyWith(
                      fontSize: HyperosMiuixTypography.footnote2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${entry.totalSections}',
                  style: HyperosTypography.listTitle(context).copyWith(
                    fontWeight: FontWeight.w800,
                    color: entry.isActive
                        ? HyperosColors.primary(context)
                        : HyperosColors.primaryText(context),
                  ),
                ),
                Text(
                  l10n.statisticsSemesterLabelSections,
                  style: HyperosTypography.listDetail(context),
                ),
                if (!entry.isActive && delta != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    l10n.statisticsCompareDelta(
                      delta > 0 ? '+$delta' : '$delta',
                    ),
                    style: HyperosTypography.listDetail(context).copyWith(
                      fontSize: HyperosMiuixTypography.footnote2,
                      fontWeight: FontWeight.w600,
                      color: delta > 0
                          ? HyperosIconColors.red
                          : (delta < 0
                                ? HyperosIconColors.green
                                : HyperosColors.secondaryText(context)),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: HyperosColors.actionIcon(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showHyperosSheet<void>(
      context: context,
      builder: (sheetContext) {
        return HyperosSheet(
          title: l10n.statisticsCompareDetailTitle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  entry.name,
                  style: HyperosTypography.sheetTitle(sheetContext),
                ),
                const SizedBox(height: 12),
                _DetailRow(
                  label: l10n.statisticsWeekSelector(entry.currentWeek),
                  value: l10n.statisticsCompareWeek,
                ),
                _DetailRow(
                  label: l10n.statisticsCourseCount,
                  value: '${entry.totalCourses}',
                ),
                _DetailRow(
                  label: l10n.statisticsSemesterLabelSections,
                  value: '${entry.totalSections}',
                ),
                _DetailRow(
                  label: l10n.statisticsNatureRatio,
                  value:
                      '${(entry.requiredRatio * 100).round()}% / ${((1 - entry.requiredRatio) * 100).round()}%',
                ),
                _DetailRow(
                  label: l10n.statisticsSemesterLabelDayStreak,
                  value: '${entry.longestStreak}',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: HyperosTypography.listDetail(context),
            ),
          ),
          Text(
            value,
            style: HyperosTypography.listTitle(context).copyWith(
              fontWeight: FontWeight.w700,
              color: HyperosColors.primaryText(context),
            ),
          ),
        ],
      ),
    );
  }
}
