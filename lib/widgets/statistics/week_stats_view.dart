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

/// 周统计视图：周选择器 + 概览 + 小结 + 每日分布 + 必修/选修 + 时间利用 + 课程列表
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
        _WeekOverviewCard(stats: stats),
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
                HyperosIconBadge(
                  icon: Icons.calendar_view_week_rounded,
                  accent: HyperosIconColors.blue,
                ),
                const SizedBox(width: HyperosTokens.rowContentGap),
                Expanded(
                  child: Text(
                    l10n.statisticsWeekSelector(week),
                    style: HyperosTypography.listTitle(context).copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
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
                      fontWeight: FontWeight.w600,
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

/// 周概览卡（大数字 + 必修/选修 + 最忙日）
class _WeekOverviewCard extends StatelessWidget {
  final WeeklyStats stats;

  const _WeekOverviewCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dividerColor = HyperosColors.dividerLine(context);

    final busiestDay = stats.busiestDay;
    final busiestDayLabel = busiestDay != null
        ? _weekdayFullLabel(l10n, busiestDay)
        : l10n.statisticsNoData;

    return HyperosControlCard(
      child: Stack(
        children: [
          Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _WeekMetricCell(
                      icon: Icons.schedule_rounded,
                      accent: HyperosIconColors.teal,
                      value: '${stats.totalSections}',
                      label: l10n.statisticsSectionCount,
                    ),
                  ),
                  Expanded(
                    child: _WeekMetricCell(
                      icon: Icons.menu_book_rounded,
                      accent: HyperosIconColors.blue,
                      value: '${stats.totalCourses}',
                      label: l10n.statisticsCourseCount,
                    ),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _WeekMetricCell(
                      icon: Icons.local_fire_department_rounded,
                      accent: HyperosIconColors.orange,
                      value: busiestDayLabel,
                      label: l10n.statisticsWeekBusiestDay,
                    ),
                  ),
                  Expanded(
                    child: _WeekMetricCell(
                      icon: Icons.balance_rounded,
                      accent: HyperosIconColors.purple,
                      value:
                          '${stats.natureStats.requiredCount}:${stats.natureStats.electiveCount}',
                      label: l10n.statisticsNatureRatio,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _WeekOverviewCrosshairPainter(color: dividerColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _weekdayFullLabel(AppLocalizations l10n, int dayOfWeek) {
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

class _WeekOverviewCrosshairPainter extends CustomPainter {
  const _WeekOverviewCrosshairPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke
      ..isAntiAlias = false;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    canvas.drawLine(Offset(centerX, 0), Offset(centerX, size.height), paint);
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), paint);
  }

  @override
  bool shouldRepaint(covariant _WeekOverviewCrosshairPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _WeekMetricCell extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String value;
  final String label;

  const _WeekMetricCell({
    required this.icon,
    required this.accent,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HyperosIconBadge(icon: icon, accent: accent),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: HyperosTypography.listTitle(context).copyWith(
              fontSize: 22,
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
      ),
    );
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
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
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
                            fontWeight: isMax ? FontWeight.w800 : FontWeight.w500,
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
                show: true,
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
