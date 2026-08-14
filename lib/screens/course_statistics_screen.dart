import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../models/course.dart';
import '../models/statistics_models.dart';
import '../providers/timetable_provider.dart';
import '../services/statistics_service.dart';
import '../services/statistics_share_service.dart';
import '../widgets/statistics/achievement_badge.dart';
import '../widgets/statistics/course_ranking.dart';
import '../widgets/statistics/data_story_card.dart';
import '../widgets/statistics/daily_chart.dart';
import '../widgets/statistics/heatmap_card.dart';
import '../widgets/statistics/nature_ratio.dart';
import '../widgets/statistics/overview_section.dart';
import '../widgets/statistics/semester_progress_card.dart';
import '../widgets/statistics/statistics_export_sheet.dart';
import '../widgets/statistics/teacher_stats_card.dart';
import '../widgets/statistics/time_utilization_card.dart';
import '../widgets/statistics/trend_chart.dart';
import '../widgets/statistics/venue_stats_card.dart';
import '../widgets/statistics/week_stats_view.dart';
import '../widgets/statistics/weekly_comparison_card.dart';
import '../ui/hyperos/hyperos.dart';
import 'add_course_screen.dart';

/// 课程统计页面（账单式：学期 / 周 双视图）
class CourseStatisticsScreen extends StatefulWidget {
  const CourseStatisticsScreen({super.key});

  @override
  State<CourseStatisticsScreen> createState() => _CourseStatisticsScreenState();
}

class _CourseStatisticsScreenState extends State<CourseStatisticsScreen> {
  bool _isExporting = false;
  bool _semesterView = true;
  int _selectedWeek = 1;

  Future<void> _handleExport({
    required BuildContext context,
    required SemesterStats semesterStats,
    required List<Achievement> achievements,
    required List<DataStory> stories,
  }) async {
    if (_isExporting) {
      return;
    }

    final options = await showStatisticsExportSheet(
      context: context,
      hasAchievements: achievements.isNotEmpty,
      hasStories: stories.isNotEmpty,
    );
    if (options == null || !context.mounted) {
      return;
    }

    setState(() => _isExporting = true);
    try {
      await StatisticsShareService.exportAndShare(
        context: context,
        options: options,
        semesterStats: semesterStats,
        achievements: achievements,
        stories: stories,
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer<TimetableProvider>(
      builder: (context, provider, _) {
        final currentWeek = provider.currentWeek;
        final semesterWeekCount = provider.settings.semesterWeekCount;
        final courses = provider.courses;

        if (_selectedWeek < 1 || _selectedWeek > semesterWeekCount) {
          _selectedWeek = currentWeek.clamp(1, semesterWeekCount);
        }

        final semesterStats = StatisticsService.calculateSemester(
          allCourses: courses,
          currentWeek: currentWeek,
          semesterWeekCount: semesterWeekCount,
        );

        final achievements = StatisticsService.calculateAchievements(
          allCourses: courses,
          currentWeek: currentWeek,
        );

        final stories = StatisticsService.generateDataStories(
          allCourses: courses,
          currentWeek: currentWeek,
        );

        final hasData = courses.isNotEmpty;

        return HyperosSubpage(
          onBack: () => Navigator.pop(context),
          title: Text(l10n.statisticsTitle),
          suffixes: hasData
              ? [
                  FHeaderAction(
                    icon: _isExporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.ios_share_rounded),
                    semanticsLabel: l10n.statisticsShareLabel,
                    onPress: () {
                      if (_isExporting) {
                        return;
                      }
                      _handleExport(
                        context: context,
                        semesterStats: semesterStats,
                        achievements: achievements,
                        stories: stories,
                      );
                    },
                  ),
                ]
              : const [],
          child: hasData
              ? Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      child: HyperosTabRow(
                        tabs: [
                          l10n.statisticsTabSemester,
                          l10n.statisticsTabWeek,
                        ],
                        selectedIndex: _semesterView ? 0 : 1,
                        onChanged: (index) =>
                            setState(() => _semesterView = index == 0),
                      ),
                    ),
                    Expanded(
                      child: _semesterView
                          ? _buildSemesterContent(
                              context,
                              l10n,
                              provider,
                              currentWeek,
                              semesterWeekCount,
                              courses,
                              semesterStats,
                              achievements,
                              stories,
                            )
                          : WeekStatsView(
                              stats: StatisticsService.calculate(
                                allCourses: courses,
                                week: _selectedWeek,
                              ),
                              currentWeek: currentWeek,
                              maxWeek: semesterWeekCount,
                              onWeekChanged: (week) =>
                                  setState(() => _selectedWeek = week),
                            ),
                    ),
                  ],
                )
              : _buildEmptyState(context, l10n),
        );
      },
    );
  }

  Widget _buildSemesterContent(
    BuildContext context,
    AppLocalizations l10n,
    TimetableProvider provider,
    int currentWeek,
    int semesterWeekCount,
    List<Course> courses,
    SemesterStats semesterStats,
    List<Achievement> achievements,
    List<DataStory> stories,
  ) {
    final trend = StatisticsService.calculateWeeklyTrend(
      allCourses: courses,
      semesterWeekCount: semesterWeekCount,
    );
    final progress = StatisticsService.calculateSemesterProgress(
      allCourses: courses,
      currentWeek: currentWeek,
      semesterWeekCount: semesterWeekCount,
      semesterStartDate: provider.settings.semesterStartDate,
    );
    final comparison = StatisticsService.calculateWeeklyComparison(
      allCourses: courses,
      currentWeek: currentWeek,
      semesterWeekCount: semesterWeekCount,
    );
    final heatmap = StatisticsService.calculateHeatmap(
      allCourses: courses,
      semesterWeekCount: semesterWeekCount,
    );
    final timeUtil = StatisticsService.calculateTimeUtilization(
      allCourses: courses,
      currentWeek: currentWeek,
    );
    final venue = StatisticsService.calculateVenueStats(
      allCourses: courses,
      currentWeek: currentWeek,
    );
    final teachers = StatisticsService.calculateTeacherStats(
      allCourses: courses,
      currentWeek: currentWeek,
    );

    return HyperosListView(
      children: [
        OverviewSection(stats: semesterStats),
        const HyperosSectionGap(),
        SemesterProgressCard(progress: progress),
        const HyperosSectionGap(),
        WeeklyComparisonCard(
          comparison: comparison,
          currentWeek: currentWeek,
        ),
        const HyperosSectionGap(),
        HyperosSettingsBlock(
          title: l10n.statisticsAchievementsTitle,
          child: AchievementGrid(achievements: achievements),
        ),
        if (stories.isNotEmpty) ...[
          const HyperosSectionGap(),
          HyperosSettingsBlock(
            title: l10n.statisticsStoriesTitle,
            child: DataStoryList(stories: stories),
          ),
        ],
        const HyperosSectionGap(),
        HyperosSettingsBlock(
          title: l10n.statisticsDailyDistribution,
          child: DailyChart(dailyAverages: semesterStats.dailyAverages),
        ),
        const HyperosSectionGap(),
        HyperosSettingsBlock(
          title: l10n.statisticsTrendTitle,
          child: TrendChart(trend: trend, currentWeek: currentWeek),
        ),
        const HyperosSectionGap(),
        HyperosSettingsBlock(
          title: l10n.statisticsNatureRatio,
          child: NatureRatio(stats: semesterStats.natureStats),
        ),
        const HyperosSectionGap(),
        HyperosSettingsBlock(
          title: l10n.statisticsHeatmapTitle,
          child: SemesterHeatmapCard(
            heatmap: heatmap,
            currentWeek: currentWeek,
          ),
        ),
        const HyperosSectionGap(),
        HyperosSettingsBlock(
          title: l10n.statisticsTimeUtilTitle,
          child: TimeUtilizationCard(stats: timeUtil),
        ),
        const HyperosSectionGap(),
        HyperosSettingsBlock(
          title: l10n.statisticsVenueTitle,
          child: VenueStatsCard(stats: venue),
        ),
        const HyperosSectionGap(),
        HyperosSettingsBlock(
          title: l10n.statisticsTeacherTitle,
          child: TeacherStatsCard(stats: teachers),
        ),
        const HyperosSectionGap(),
        HyperosSettingsBlock(
          title: l10n.statisticsRankingTitle,
          child: CourseRanking(
            courseRanking: semesterStats.courseRanking,
            onCourseTap: (courseName) =>
                _openCourseEdit(context, courseName),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: HyperosEmptyState(
        icon: Icons.analytics_outlined,
        title: l10n.statisticsNoData,
        subtitle: l10n.statisticsNoDataHint,
      ),
    );
  }
}
