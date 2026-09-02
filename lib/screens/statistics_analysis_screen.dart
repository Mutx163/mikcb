import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../models/course.dart';
import '../models/timetable_profile.dart';
import '../providers/timetable_provider.dart';
import '../services/statistics_service.dart';
import '../ui/hyperos/hyperos.dart';
import '../widgets/statistics/course_ranking.dart';
import '../widgets/statistics/profile_compare_card.dart';
import '../widgets/statistics/heatmap_card.dart';
import '../widgets/statistics/teacher_stats_card.dart';
import '../widgets/statistics/time_utilization_card.dart';
import '../widgets/statistics/trend_chart.dart';
import '../widgets/statistics/venue_stats_card.dart';
import 'add_course_screen.dart';

/// 深度分析二级页模块
enum StatisticsAnalysisModule { trend, timeUtil, venue, teacher, ranking, compare }

/// 课程统计深度分析二级页：按 [module] 渲染对应分析模块。
class StatisticsAnalysisScreen extends StatelessWidget {
  final StatisticsAnalysisModule module;

  const StatisticsAnalysisScreen({super.key, required this.module});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer<TimetableProvider>(
      builder: (context, provider, _) {
        final courses = provider.courses;
        final currentWeek = provider.currentWeek;
        final semesterWeekCount = provider.settings.semesterWeekCount;
        final hasData = courses.isNotEmpty;

        return HyperosSubpage(
          onBack: () => Navigator.pop(context),
          title: Text(_moduleTitle(l10n, module)),
          child: hasData
              // 整页列表必须保留 overlay 标题栏顶部 inset（默认 true）：
              // 传 false 会把第一屏内容顶进毛玻璃标题栏。
              ? HyperosListView(
                  children: _buildModuleContent(
                    context,
                    l10n,
                    provider,
                    courses,
                    currentWeek,
                    semesterWeekCount,
                  ),
                )
              : HyperosBlurredBodyInset(
                  child: Center(
                    child: HyperosEmptyState(
                      icon: Icons.analytics_outlined,
                      title: l10n.statisticsNoData,
                      subtitle: l10n.statisticsNoDataHint,
                    ),
                  ),
                ),
        );
      },
    );
  }

  String _moduleTitle(AppLocalizations l10n, StatisticsAnalysisModule module) {
    return switch (module) {
      StatisticsAnalysisModule.trend => l10n.statisticsTrendTitle,
      StatisticsAnalysisModule.timeUtil => l10n.statisticsTimeUtilTitle,
      StatisticsAnalysisModule.venue => l10n.statisticsVenueTitle,
      StatisticsAnalysisModule.teacher => l10n.statisticsTeacherTitle,
      StatisticsAnalysisModule.ranking => l10n.statisticsRankingTitle,
      StatisticsAnalysisModule.compare => l10n.statisticsCompareTitle,
    };
  }

  List<Widget> _buildModuleContent(
    BuildContext context,
    AppLocalizations l10n,
    TimetableProvider provider,
    List<Course> courses,
    int currentWeek,
    int semesterWeekCount,
  ) {
    switch (module) {
      case StatisticsAnalysisModule.trend:
        final trend = StatisticsService.calculateWeeklyTrend(
          allCourses: courses,
          semesterWeekCount: semesterWeekCount,
        );
        final heatmap = StatisticsService.calculateHeatmap(
          allCourses: courses,
          semesterWeekCount: semesterWeekCount,
        );
        return [
          TrendChart(trend: trend, currentWeek: currentWeek),
          const HyperosSectionGap(),
          SemesterHeatmapCard(heatmap: heatmap, currentWeek: currentWeek),
        ];
      case StatisticsAnalysisModule.timeUtil:
        final timeUtil = StatisticsService.calculateTimeUtilization(
          allCourses: courses,
          currentWeek: currentWeek,
        );
        return [TimeUtilizationCard(stats: timeUtil)];
      case StatisticsAnalysisModule.venue:
        final venue = StatisticsService.calculateVenueStats(
          allCourses: courses,
          currentWeek: currentWeek,
        );
        return [VenueStatsCard(stats: venue)];
      case StatisticsAnalysisModule.teacher:
        final teachers = StatisticsService.calculateTeacherStats(
          allCourses: courses,
          currentWeek: currentWeek,
        );
        return [TeacherStatsCard(stats: teachers)];
      case StatisticsAnalysisModule.ranking:
        final semesterStats = StatisticsService.calculateSemester(
          allCourses: courses,
          currentWeek: currentWeek,
          semesterWeekCount: semesterWeekCount,
        );
        return [
          CourseRanking(
            courseRanking: semesterStats.courseRanking,
            onCourseTap: (courseName) =>
                _openCourseEdit(context, courseName),
          ),
        ];
      case StatisticsAnalysisModule.compare:
        final active = provider.activeProfile;
        final others = provider.profiles
            .where((p) => p.id != active?.id)
            .toList();
        final activeStats = StatisticsService.calculateSemester(
          allCourses: courses,
          currentWeek: currentWeek,
          semesterWeekCount: semesterWeekCount,
        );
        return [
          ProfileCompareCard(
            showHeader: false,
            entries: [
              ProfileCompareEntry(
                name: active?.name ?? '',
                isActive: true,
                currentWeek: currentWeek,
                totalSections: activeStats.totalSections,
                totalCourses: activeStats.totalCourses,
                requiredRatio: activeStats.natureStats.requiredRatio,
                longestStreak: activeStats.longestStreak,
              ),
              for (final profile in others)
                _profileCompareEntry(
                  profile,
                  activeTotalSections: activeStats.totalSections,
                ),
            ],
          ),
        ];
    }
  }

  /// 其他课表的对比条目（isActive 恒 false，delta 相对当前课表）
  ProfileCompareEntry _profileCompareEntry(
    TimetableProfile profile, {
    required int activeTotalSections,
  }) {
    final stats = StatisticsService.calculateSemester(
      allCourses: profile.courses,
      currentWeek: profile.currentWeek,
      semesterWeekCount: profile.settings.semesterWeekCount,
    );
    return ProfileCompareEntry(
      name: profile.name,
      isActive: false,
      currentWeek: profile.currentWeek,
      totalSections: stats.totalSections,
      totalCourses: stats.totalCourses,
      requiredRatio: stats.natureStats.requiredRatio,
      longestStreak: stats.longestStreak,
      deltaSections: stats.totalSections - activeTotalSections,
    );
  }

  void _openCourseEdit(BuildContext context, String courseName) {
    final provider = context.read<TimetableProvider>();
    final course = provider.courses
        .where((c) => c.name == courseName)
        .firstOrNull;
    if (course == null) {
      return;
    }
    final group = provider.courseGroupForCourse(course);
    Navigator.push(
      context,
      HyperosPageRoute(
        settings: const RouteSettings(name: '/course/edit'),
        builder: (context) =>
            AddCourseScreen(courseGroup: group, initialCourse: course),
      ),
    );
  }
}
