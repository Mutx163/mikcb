import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../domain/course_session_stats.dart';
import '../providers/timetable_provider.dart';
import '../ui/hyperos/hyperos.dart';
import '../widgets/statistics/session_coverage_card.dart';
import '../widgets/statistics/session_list_card.dart';
import '../widgets/statistics/session_summary_card.dart';

/// 单节课明细统计页（只读）。
///
/// 定位：把「这门课在学期里上了哪几次、每次留下了什么」摊开看。
/// 全部数据都从已有记录推导（课程周次 + 备注 + 作业 + 提醒 + 考试），
/// **不新增任何录入入口** —— 用户不需要为了让统计有数而去填表。
///
/// 为什么不是 `StatisticsAnalysisScreen` 的一个模块：那个壳的每个模块都只吃
/// `(courses, currentWeek, semesterWeekCount)`，且被冻结测试
/// `statistics_analysis_header_inset_test` 按枚举逐个 pump；本页需要「选一门课」
/// 的自有状态，塞进去会让那个测试的裸构造路径渲染不出内容。
class StatisticsSessionScreen extends StatefulWidget {
  const StatisticsSessionScreen({super.key, this.initialCourseName});

  /// 从课程排行点进来时带上课程名；为空则默认第一门课。
  final String? initialCourseName;

  @override
  State<StatisticsSessionScreen> createState() =>
      _StatisticsSessionScreenState();
}

class _StatisticsSessionScreenState extends State<StatisticsSessionScreen> {
  String? _courseName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer<TimetableProvider>(
      builder: (context, provider, _) {
        final groups = provider.courseGroups;
        final names = groups.map((group) => group.name).toList();

        if (names.isEmpty) {
          return HyperosSubpage(
            onBack: () => Navigator.pop(context),
            title: Text(l10n.statisticsSessionTitle),
            child: Center(
              child: HyperosEmptyState(
                icon: Icons.event_note_outlined,
                title: l10n.statisticsNoData,
                subtitle: l10n.statisticsNoDataHint,
              ),
            ),
          );
        }

        // 选中项收敛：外部传入的名字 → 上一次选择 → 第一门课。
        final selected = _resolveSelection(names);
        _courseName = selected;

        final group = groups.firstWhere((item) => item.name == selected);
        final stats = CourseSessionStatsCalculator.build(
          courseName: selected,
          courses: group.courses,
          settings: provider.settings,
          tasks: provider.tasks,
          exams: provider.exams,
          now: DateTime.now(),
          isHoliday: provider.isHoliday,
          startTimeResolver: provider.resolvedCourseStartTime,
          endTimeResolver: provider.resolvedCourseEndTime,
          reminderDateLookup: (courseId, date) =>
              provider.classReminderFor(courseId, date)?.id,
        );

        return HyperosSubpage(
          onBack: () => Navigator.pop(context),
          title: Text(l10n.statisticsSessionTitle),
          child: HyperosListView(
            children: [
              HyperosSettingsBlock(
                title: l10n.statisticsSessionCourseLabel,
                child: HyperosListGroup(
                  children: [
                    HyperosSelectTile<String>(
                      label: l10n.statisticsSessionCourseLabel,
                      value: selected,
                      items: {for (final name in names) name: name},
                      onChanged: (value) {
                        setState(() => _courseName = value);
                      },
                    ),
                  ],
                ),
              ),
              if (!stats.hasCalendar) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    l10n.statisticsSessionNoCalendarHint,
                    style: HyperosTypography.listDetail(
                      context,
                    ).copyWith(color: HyperosColors.secondaryText(context)),
                  ),
                ),
              ],
              const HyperosSectionGap(),
              SessionSummaryCard(stats: stats),
              const HyperosSectionGap(),
              HyperosSettingsBlock(
                title: l10n.statisticsSessionCoverageTitle,
                child: SessionCoverageCard(stats: stats),
              ),
              const HyperosSectionGap(),
              HyperosSettingsBlock(
                title: l10n.statisticsSessionListTitle,
                child: SessionListCard(stats: stats),
              ),
            ],
          ),
        );
      },
    );
  }

  String _resolveSelection(List<String> names) {
    final current = _courseName;
    if (current != null && names.contains(current)) {
      return current;
    }
    final initial = widget.initialCourseName;
    if (initial != null && names.contains(initial)) {
      return initial;
    }
    return names.first;
  }
}
