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
  const StatisticsSessionScreen({super.key});

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
            // 整页非列表 child 必须手动避让毛玻璃标题栏：裸 Center 会把
            // 空态顶进标题栏里（statistics_analysis_header_inset_test 钉过
            // analysis 页的同一类 bug，本页同样适用）。
            child: HyperosBlurredBodyInset(
              child: Center(
                child: HyperosEmptyState(
                  icon: Icons.event_note_outlined,
                  title: l10n.statisticsNoData,
                  subtitle: l10n.statisticsNoDataHint,
                ),
              ),
            ),
          );
        }

        // 选中项收敛：外部传入的名字 → 上一次选择 → 第一门课。
        final selected = _resolveSelection(names);
        _courseName = selected;

        final group = groups.firstWhere((item) => item.name == selected);
        // 提醒键集合一次构建：classReminderFor 是线性扫，每课次查一次
        // 是 O(课次 × 提醒数)；集合交给领域层 O(1) 命中。
        final reminderKeys = <String>{
          for (final entry in provider.settings.classReminders)
            '${entry.courseId}|${entry.date}',
        };
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
          reminderKeys: reminderKeys,
        );

        return HyperosSubpage(
          onBack: () => Navigator.pop(context),
          title: Text(l10n.statisticsSessionTitle),
          child: HyperosListView(
            children: [
              // 课程选择行：不套 HyperosSettingsBlock——区块标题「课程」与
              // 选择行的 label 会同屏念两遍（ics_export_screen 同款做法）。
              HyperosListGroup(
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

  /// 选中项收敛：上一次选择（课程被删时回落第一门）。
  ///
  /// 将来若从课程排行加「看单课明细」入口，这里要补一个外部初始值参数，
  /// 并想清楚它与 [_courseName] 的优先级（外部值应只在首次生效，不能被
  /// 旧选中值顶掉）——目前没有调用方，先不留死参数。
  String _resolveSelection(List<String> names) {
    final current = _courseName;
    if (current != null && names.contains(current)) {
      return current;
    }
    return names.first;
  }
}
