import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../models/course.dart';
import '../models/statistics_models.dart';
import '../models/timetable_profile.dart';
import '../providers/timetable_provider.dart';
import '../services/statistics_service.dart';
import '../services/statistics_share_service.dart';
import '../services/stats_widget_service.dart';
import '../services/weekly_report_service.dart';
import '../widgets/statistics/achievement_badge.dart';
import '../widgets/statistics/data_story_card.dart';
import '../widgets/statistics/daily_chart.dart';
import '../widgets/statistics/nature_ratio.dart';
import '../widgets/statistics/overview_section.dart';
import '../widgets/statistics/profile_compare_card.dart';
import '../widgets/statistics/semester_progress_card.dart';
import '../widgets/statistics/statistics_export_sheet.dart';
import '../widgets/statistics/week_stats_view.dart';
import '../widgets/statistics/weekly_comparison_card.dart';
import '../ui/hyperos/hyperos.dart';
import '../utils/app_toast.dart';
import 'statistics_analysis_screen.dart';

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

        // 同步桌面统计小组件快照（幂等，廉价 JSON；失败静默）
        if (hasData) {
          final weekStatsForWidget = StatisticsService.calculate(
            allCourses: courses,
            week: currentWeek,
          );
          final semesterForWidget = semesterStats;
          final progressForWidget = StatisticsService.calculateSemesterProgress(
            allCourses: courses,
            currentWeek: currentWeek,
            semesterWeekCount: semesterWeekCount,
          );
          final comparisonForWidget = StatisticsService.calculateWeeklyComparison(
            allCourses: courses,
            currentWeek: currentWeek,
            semesterWeekCount: semesterWeekCount,
          );
          StatsWidgetService.syncSnapshot(
            StatsWidgetSnapshot(
              profileName: provider.activeProfile?.name ?? '',
              currentWeek: currentWeek,
              weekSections: weekStatsForWidget.totalSections,
              weekCourseCount: weekStatsForWidget.totalCourses,
              deltaVsLastWeek: comparisonForWidget.deltaVsLastWeek,
              semesterDone: semesterForWidget.totalSections,
              semesterTotal: progressForWidget.sectionsTotal,
              requiredCount: semesterForWidget.natureStats.requiredCount,
              electiveCount: semesterForWidget.natureStats.electiveCount,
              longestStreak: semesterForWidget.longestStreak,
            ),
          );
        }

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
              ? (_semesterView
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
                        header: _buildTabRow(context, l10n),
                        stats: StatisticsService.calculate(
                          allCourses: courses,
                          week: _selectedWeek,
                        ),
                        currentWeek: currentWeek,
                        maxWeek: semesterWeekCount,
                        onWeekChanged: (week) =>
                            setState(() => _selectedWeek = week),
                      ))
              : _buildEmptyState(context, l10n),
        );
      },
    );
  }

  Widget _buildTabRow(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: HyperosTabRow(
        tabs: [
          l10n.statisticsTabSemester,
          l10n.statisticsTabWeek,
        ],
        selectedIndex: _semesterView ? 0 : 1,
        onChanged: (index) => setState(() => _semesterView = index == 0),
      ),
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

    return HyperosListView(
      children: [
        _buildTabRow(context, l10n),
        const HyperosSectionGap(),
        _buildWeeklyReportSection(context, l10n, provider, currentWeek, semesterWeekCount),
        const HyperosSectionGap(),
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
          title: l10n.statisticsNatureRatio,
          child: NatureRatio(stats: semesterStats.natureStats),
        ),
        const HyperosSectionGap(),
        _buildAnalysisEntries(context, l10n),
        ..._buildProfileCompareSections(context, l10n, provider, semesterStats),
      ],
    );
  }

  /// 深度分析入口组（二级页）
  Widget _buildAnalysisEntries(BuildContext context, AppLocalizations l10n) {
    void open(StatisticsAnalysisModule module) {
      Navigator.push(
        context,
        HyperosPageRoute(
          settings: const RouteSettings(name: '/statistics/analysis'),
          builder: (_) => StatisticsAnalysisScreen(module: module),
        ),
      );
    }

    return HyperosSettingsBlock(
      title: l10n.statisticsMoreTitle,
      child: HyperosListGroup(
        children: [
          HyperosListTile(
            icon: Icons.show_chart_rounded,
            iconAccent: HyperosIconColors.blue,
            title: l10n.statisticsTrendTitle,
            onTap: () => open(StatisticsAnalysisModule.trend),
          ),
          HyperosListTile(
            icon: Icons.schedule_rounded,
            iconAccent: HyperosIconColors.cyan,
            title: l10n.statisticsTimeUtilTitle,
            onTap: () => open(StatisticsAnalysisModule.timeUtil),
          ),
          HyperosListTile(
            icon: Icons.location_city_rounded,
            iconAccent: HyperosIconColors.purple,
            title: l10n.statisticsVenueTitle,
            onTap: () => open(StatisticsAnalysisModule.venue),
          ),
          HyperosListTile(
            icon: Icons.school_outlined,
            iconAccent: HyperosIconColors.green,
            title: l10n.statisticsTeacherTitle,
            onTap: () => open(StatisticsAnalysisModule.teacher),
          ),
          HyperosListTile(
            icon: Icons.leaderboard_rounded,
            iconAccent: HyperosIconColors.orange,
            title: l10n.statisticsRankingTitle,
            onTap: () => open(StatisticsAnalysisModule.ranking),
          ),
        ],
      ),
    );
  }

  ProfileCompareEntry _profileCompareEntry(
    TimetableProfile profile,
    int activeTotalSections,
  ) {
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

  /// 课表对比：当前课表 vs 其他课表（profiles）
  List<Widget> _buildProfileCompareSections(
    BuildContext context,
    AppLocalizations l10n,
    TimetableProvider provider,
    SemesterStats semesterStats,
  ) {
    final active = provider.activeProfile;
    final others = provider.profiles
        .where((p) => p.id != active?.id)
        .toList();
    if (others.isEmpty) {
      return const [];
    }

    final entries = <ProfileCompareEntry>[
      ProfileCompareEntry(
        name: active?.name ?? '',
        isActive: true,
        currentWeek: provider.currentWeek,
        totalSections: semesterStats.totalSections,
        totalCourses: semesterStats.totalCourses,
        requiredRatio: semesterStats.natureStats.requiredRatio,
        longestStreak: semesterStats.longestStreak,
      ),
      for (final profile in others)
        _profileCompareEntry(profile, semesterStats.totalSections),
    ];

    return [
      const HyperosSectionGap(),
      HyperosSettingsBlock(
        title: l10n.statisticsCompareTitle,
        child: ProfileCompareCard(entries: entries),
      ),
    ];
  }

  Widget _buildWeeklyReportSection(
    BuildContext context,
    AppLocalizations l10n,
    TimetableProvider provider,
    int currentWeek,
    int semesterWeekCount,
  ) {
    final enabled = provider.settings.weeklyReportEnabled;
    final nextFire = WeeklyReportService.nextFireAt();
    final nextFireLabel = DateFormat.MMMd(l10n.localeName).format(nextFire);
    final nextFireTime =
        '${nextFire.hour.toString().padLeft(2, '0')}:${nextFire.minute.toString().padLeft(2, '0')}';

    return HyperosSettingsBlock(
      title: l10n.weeklyReportTitle,
      child: HyperosSwitchTile(
        icon: Icons.notifications_active_outlined,
        iconAccent: enabled ? HyperosIconColors.orange : HyperosIconColors.blue,
        title: l10n.weeklyReportTitle,
        subtitle: enabled
            ? l10n.weeklyReportNextFire(nextFireLabel, nextFireTime)
            : l10n.weeklyReportDisabledHint,
        value: enabled,
        onChanged: (value) => _setWeeklyReportEnabled(
          context,
          provider,
          value,
          currentWeek,
          semesterWeekCount,
        ),
      ),
    );
  }

  Future<void> _setWeeklyReportEnabled(
    BuildContext context,
    TimetableProvider provider,
    bool enabled,
    int currentWeek,
    int semesterWeekCount,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    await provider.updateSettings(
      provider.settings.copyWith(weeklyReportEnabled: enabled),
    );
    await WeeklyReportService.schedule(
      enabled: enabled,
      l10n: l10n,
      allCourses: provider.courses,
      currentWeek: currentWeek,
      semesterWeekCount: semesterWeekCount,
    );
    if (context.mounted) {
      showAppToast(
        context,
        message: enabled
            ? l10n.weeklyReportEnabledHint
            : l10n.weeklyReportDisabledHint,
      );
    }
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
