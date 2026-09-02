import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../models/course.dart';
import '../../models/statistics_models.dart';
import '../../services/statistics_service.dart';
import '../../widgets/week_selector_picker_sheet.dart';
import 'nature_ratio.dart';
import 'time_utilization_card.dart';
import 'weekly_comparison_card.dart';

/// 周统计视图：周选择器 + 本周小结 + 每日分布 + 必修/选修 + 时间利用 + 课程列表
class WeekStatsView extends StatelessWidget {
  final WeeklyStats stats;
  final int currentWeek; // 当前教学周（用于标记"本周"）
  final int maxWeek;
  final ValueChanged<int> onWeekChanged;

  /// 可选顶部内容（如学期/周切换行），作为列表首元素随列表滚动
  final Widget? header;

  /// 全部课程（用于计算本周小结 / 时间利用）
  final List<Course> allCourses;

  const WeekStatsView({
    super.key,
    required this.stats,
    required this.currentWeek,
    required this.maxWeek,
    required this.onWeekChanged,
    required this.allCourses,
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final week = stats.weekNumber;

    final comparison = StatisticsService.calculateWeeklyComparison(
      allCourses: allCourses,
      currentWeek: week,
      semesterWeekCount: maxWeek,
    );
    final timeUtil = StatisticsService.calculateTimeUtilization(
      allCourses: allCourses,
      currentWeek: week,
    );

    return HyperosListView(
      children: [
        if (header != null) ...[
          header!,
          const HyperosSectionGap(),
        ],
        _WeekSelector(
          week: week,
          maxWeek: maxWeek,
          currentSemesterWeek: currentWeek,
          onWeekChanged: onWeekChanged,
        ),
        const HyperosSectionGap(),
        WeeklyComparisonCard(
          comparison: comparison,
          currentWeek: week,
        ),
        const HyperosSectionGap(),
        HyperosSettingsBlock(
          title: l10n.statisticsDailyDistribution,
          child: _WeekDailyChart(stats: stats),
        ),
        const HyperosSectionGap(),
        HyperosSettingsBlock(
          title: l10n.statisticsNatureRatio,
          child: NatureRatio(stats: stats.natureStats),
        ),
        if (!timeUtil.isEmpty) ...[
          const HyperosSectionGap(),
          HyperosSettingsBlock(
            title: l10n.statisticsTimeUtilTitle,
            child: TimeUtilizationCard(stats: timeUtil),
          ),
        ],
        if (stats.courseStats.isNotEmpty) ...[
          const HyperosSectionGap(),
          HyperosSettingsBlock(
            title: l10n.statisticsCourseList,
            child: _WeekCourseList(stats: stats),
          ),
        ],
      ],
    );
  }
}

/// 周选择器（整行点击，弹出与首页一致的周次选择弹窗）
class _WeekSelector extends StatelessWidget {
  final int week;
  final int maxWeek;

  /// 当前教学周（用于高亮与"回到当前周"），可为 null
  final int? currentSemesterWeek;
  final ValueChanged<int> onWeekChanged;

  const _WeekSelector({
    required this.week,
    required this.maxWeek,
    required this.currentSemesterWeek,
    required this.onWeekChanged,
  });

  bool get _isCurrentWeek => currentSemesterWeek != null && week == currentSemesterWeek;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isCurrentWeek = _isCurrentWeek;

    return HyperosControlCard(
      child: HyperosControlCardInset(
        child: HyperosPressableRow(
          onTap: () => _showPicker(context),
          backgroundColor: Colors.transparent,
          highlightColor: HyperosColors.rowHighlight(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const HyperosIconBadge(
                  icon: Icons.calendar_view_week_rounded,
                ),
                const SizedBox(width: HyperosTokens.rowContentGap),
                Expanded(
                  child: Text(
                    l10n.statisticsWeekSelector(week),
                    // 卡片标题回归常规体，靠字号(18)建立层级。
                    // 注意：这里是标题文案而非展示数字，保持 w400 不动。
                    style: HyperosTypography.listTitle(context).copyWith(
                      fontSize: 18,
                      color: HyperosColors.primaryText(context),
                    ),
                  ),
                ),
                if (isCurrentWeek) ...[
                  HyperosTag(
                    label: l10n.statisticsWeekCurrentHint,
                    backgroundColor: HyperosColors.primary(
                      context,
                    ).withValues(alpha: 0.12),
                    textStyle: HyperosTypography.listDetail(context).copyWith(
                      fontSize: HyperosMiuixTypography.footnote2,
                      // T1 轻强调：小号 Tag 用 w500
                      fontWeight: FontWeight.w500,
                      color: HyperosColors.primary(context),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Icon(
                  Icons.expand_more_rounded,
                  size: 22,
                  color: HyperosColors.actionIcon(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    final selected = await showWeekSelectorPickerSheet(
      context,
      availableWeeks: List.generate(maxWeek, (index) => index + 1),
      visibleWeek: week,
      currentSemesterWeek: currentSemesterWeek,
    );
    if (selected != null && selected != week) {
      onWeekChanged(selected);
    }
  }
}

/// 周每日课时柱状图（本周节数）
class _WeekDailyChart extends StatelessWidget {
  final WeeklyStats stats;

  const _WeekDailyChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final maxSections = stats.dailyStats.fold<int>(
      0,
      (max, s) => s.sectionCount > max ? s.sectionCount : max,
    );
    final activeDays = stats.dailyStats
        .where((s) => s.sectionCount > 0)
        .toList();
    final minSections = activeDays.isEmpty
        ? 0
        : activeDays
              .map((s) => s.sectionCount)
              .reduce((a, b) => a < b ? a : b);

    final weekdayLabels = [
      l10n.weekdayShortMonday,
      l10n.weekdayShortTuesday,
      l10n.weekdayShortWednesday,
      l10n.weekdayShortThursday,
      l10n.weekdayShortFriday,
      l10n.weekdayShortSaturday,
      l10n.weekdayShortSunday,
    ];

    return HyperosControlCard(
      child: HyperosControlCardInset(
        child: SizedBox(
          height: 150,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: (maxSections + 1).toDouble(),
              minY: 0,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${rod.toY.toInt()} ${l10n.statisticsSectionsUnit}',
                      HyperosTypography.listDetail(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  
                ),
                rightTitles: const AxisTitles(
                  
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= weekdayLabels.length) {
                        return const SizedBox.shrink();
                      }
                      final stat = stats.dailyStats[index];
                      final isMax = stat.sectionCount == maxSections && stat.sectionCount > 0;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          weekdayLabels[index],
                          style: HyperosTypography.listDetail(context).copyWith(
                            fontSize: HyperosMiuixTypography.footnote2,
                            // T1 轻强调：轴标签高亮用 w500，避免小字加粗发闷
                            fontWeight: isMax ? FontWeight.w500 : FontWeight.w400,
                            color: isMax
                                ? HyperosColors.primary(context)
                                : HyperosColors.secondaryText(context),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    interval: maxSections > 6 ? null : 1,
                    getTitlesWidget: (value, meta) {
                      if (value != value.roundToDouble()) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        value.toInt().toString(),
                        style: HyperosTypography.listDetail(
                          context,
                        ).copyWith(fontSize: HyperosMiuixTypography.footnote2),
                      );
                    },
                  ),
                ),
              ),
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: HyperosColors.dividerLine(context),
                    strokeWidth: 1,
                  );
                },
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(7, (index) {
                final stat = stats.dailyStats[index];
                final isMax = stat.sectionCount == maxSections && stat.sectionCount > 0;
                final isMin =
                    stat.sectionCount == minSections && stat.sectionCount > 0 && !isMax;
                final barColor = isMax
                    ? HyperosColors.primary(context)
                    : isMin
                    ? HyperosIconColors.teal
                    : HyperosColors.primary(context).withValues(alpha: 0.35);
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: stat.sectionCount.toDouble(),
                      color: barColor,
                      width: 20,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

/// 本周课程列表
class _WeekCourseList extends StatelessWidget {
  final WeeklyStats stats;

  const _WeekCourseList({required this.stats});

  @override
  Widget build(BuildContext context) {
    return HyperosListGroup(
      children: [
        for (var index = 0; index < stats.courseStats.length; index++)
          _WeekCourseTile(
            stat: stats.courseStats[index],
            isLast: index == stats.courseStats.length - 1,
          ),
      ],
    );
  }
}

class _WeekCourseTile extends StatelessWidget {
  final CourseStat stat;
  final bool isLast;

  const _WeekCourseTile({required this.stat, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scope = HyperosListTileScope.maybeOf(context);
    final isRequired = stat.nature == CourseNature.required;

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: HyperosTokens.listRowTwoLineMinHeight,
      ),
      child: Padding(
        padding: HyperosTokens.rowPadding(
          isFirst: scope?.isFirst ?? true,
          isLast: isLast,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          stat.name,
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
                              // T1 轻强调：小号 Tag 用 w500
                              fontWeight: FontWeight.w500,
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
                  if (stat.slots.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: stat.slots.map((slot) {
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
                  '${stat.weeklySections}',
                  // T2 行内数据值：主题色 + w600
                  style: HyperosTypography.listTitle(context).copyWith(
                    fontWeight: FontWeight.w600,
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
