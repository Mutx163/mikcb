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

/// 课表对比卡：全部课表的关键指标直接平铺展示。
///
/// 无二次交互——曾经的「点行弹底部面板看详情」已移除，
/// 周数 / 课程门数 / 节课 / 必修选修比 / 连续天数一屏尽览。
class ProfileCompareCard extends StatelessWidget {
  final List<ProfileCompareEntry> entries;

  const ProfileCompareCard({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    return HyperosControlCard(
      edgeToEdge: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const HyperosInsetDivider(indent: 16),
            _ProfileCompareBlock(
              entry: entries[i],
              isFirst: i == 0,
              isLast: i == entries.length - 1,
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileCompareBlock extends StatelessWidget {
  final ProfileCompareEntry entry;
  final bool isFirst;
  final bool isLast;

  const _ProfileCompareBlock({
    required this.entry,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final delta = entry.deltaSections;

    return Padding(
      padding: HyperosTokens.rowPadding(isFirst: isFirst, isLast: isLast),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: entry.isActive
                      ? HyperosColors.primary(context)
                      : HyperosColors.secondaryText(
                          context,
                        ).withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: HyperosTokens.rowContentGap),
              Flexible(
                child: Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // 激活行 w600，非激活行常规体，圆点颜色区分状态
                  style: HyperosTypography.listTitle(context).copyWith(
                    fontWeight: entry.isActive
                        ? FontWeight.w600
                        : FontWeight.w400,
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
                  textStyle: HyperosTypography.listDetail(context).copyWith(
                    fontSize: HyperosMiuixTypography.footnote2,
                    fontWeight: FontWeight.w500,
                    color: HyperosColors.primary(context),
                  ),
                ),
              ],
              if (!entry.isActive && delta != null) ...[
                const Spacer(),
                Text(
                  l10n.statisticsCompareDelta(delta > 0 ? '+$delta' : '$delta'),
                  style: HyperosTypography.listDetail(context).copyWith(
                    fontSize: HyperosMiuixTypography.footnote2,
                    // 语义色已足够区分正负，字重回归常规
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
          const SizedBox(height: 2),
          Text(
            l10n.statisticsWeekSelector(entry.currentWeek),
            style: HyperosTypography.listDetail(context).copyWith(
              fontSize: HyperosMiuixTypography.footnote2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(
                value: '${entry.totalCourses}',
                label: l10n.statisticsCourseCount,
              ),
              const SizedBox(width: 12),
              _Stat(
                value: '${entry.totalSections}',
                label: l10n.statisticsSemesterLabelSections,
                highlight: entry.isActive,
              ),
              const SizedBox(width: 12),
              _Stat(
                value:
                    '${(entry.requiredRatio * 100).round()}% / '
                    '${((1 - entry.requiredRatio) * 100).round()}%',
                label: l10n.statisticsNatureRatio,
              ),
              const SizedBox(width: 12),
              _Stat(
                value: '${entry.longestStreak}',
                label: l10n.statisticsSemesterLabelDayStreak,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 指标列：数值在上（w600），小灰标签在下。
class _Stat extends StatelessWidget {
  final String value;
  final String label;

  /// 当前课表的节数用主题色轻强调
  final bool highlight;

  const _Stat({
    required this.value,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: HyperosTypography.listTitle(context).copyWith(
                fontWeight: FontWeight.w600,
                color: highlight
                    ? HyperosColors.primary(context)
                    : HyperosColors.primaryText(context),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HyperosTypography.listDetail(context).copyWith(
              fontSize: HyperosMiuixTypography.footnote2,
            ),
          ),
        ],
      ),
    );
  }
}
