import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../models/statistics_models.dart';
import '../providers/timetable_provider.dart';
import '../services/statistics_service.dart';
import '../services/statistics_share_service.dart';
import '../widgets/statistics/overview_section.dart';
import '../widgets/statistics/achievement_badge.dart';
import '../widgets/statistics/data_story_card.dart';
import '../widgets/statistics/daily_chart.dart';
import '../widgets/statistics/nature_ratio.dart';
import '../widgets/statistics/course_ranking.dart';

/// 课程统计页面（账单式）
class CourseStatisticsScreen extends StatefulWidget {
  const CourseStatisticsScreen({super.key});

  @override
  State<CourseStatisticsScreen> createState() => _CourseStatisticsScreenState();
}

class _CourseStatisticsScreenState extends State<CourseStatisticsScreen> {
  final GlobalKey _shareKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer<TimetableProvider>(
      builder: (context, provider, _) {
        final currentWeek = provider.currentWeek;
        final courses = provider.courses;

        // 计算学期统计
        final semesterStats = StatisticsService.calculateSemester(
          allCourses: courses,
          currentWeek: currentWeek,
        );

        // 计算成就
        final achievements = StatisticsService.calculateAchievements(
          allCourses: courses,
          currentWeek: currentWeek,
        );

        // 生成数据故事
        final stories = StatisticsService.generateDataStories(
          allCourses: courses,
          currentWeek: currentWeek,
        );

        final hasData = courses.isNotEmpty;

        return FScaffold(
          header: FHeader.nested(
            prefixes: [
              FHeaderAction.back(onPress: () => Navigator.pop(context)),
            ],
            title: Text(l10n.statisticsTitle),
            suffixes: hasData
                ? [
                    FHeaderAction(
                      icon: const Icon(Icons.share_rounded),
                      semanticsLabel: l10n.statisticsShareLabel,
                      onPress: () => StatisticsShareService.shareWidgetAsImage(
                        context: context,
                        repaintBoundaryKey: _shareKey,
                        title: l10n.statisticsShareTitle,
                      ),
                    ),
                  ]
                : const [],
          ),
          childPad: false,
          child: Material(
            type: MaterialType.transparency,
            child: hasData
                ? _buildContent(
                    context,
                    semesterStats,
                    achievements,
                    stories,
                    l10n,
                  )
                : _buildEmptyState(context, l10n),
          ),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    SemesterStats semesterStats,
    List<Achievement> achievements,
    List<DataStory> stories,
    AppLocalizations l10n,
  ) {
    final theme = context.theme;

    return RepaintBoundary(
      key: _shareKey,
      child: Container(
        color: theme.colors.background,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            OverviewSection(stats: semesterStats),
            const SizedBox(height: 24),
            _buildSectionTitle(l10n.statisticsAchievementsTitle),
            const SizedBox(height: 12),
            AchievementGrid(achievements: achievements),
            const SizedBox(height: 24),
            if (stories.isNotEmpty) ...[
              _buildSectionTitle(l10n.statisticsStoriesTitle),
              const SizedBox(height: 12),
              DataStoryList(stories: stories),
              const SizedBox(height: 24),
            ],
            _buildSectionTitle(l10n.statisticsDailyDistribution),
            const SizedBox(height: 12),
            DailyChart(dailyAverages: semesterStats.dailyAverages),
            const SizedBox(height: 24),
            _buildSectionTitle(l10n.statisticsNatureRatio),
            const SizedBox(height: 12),
            NatureRatio(stats: semesterStats.natureStats),
            const SizedBox(height: 24),
            _buildSectionTitle(l10n.statisticsRankingTitle),
            const SizedBox(height: 12),
            CourseRanking(courseRanking: semesterStats.courseRanking),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    final theme = context.theme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 64,
              color: theme.colors.mutedForeground.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.statisticsNoData,
              style: theme.typography.body.md.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.statisticsNoDataHint,
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.mutedForeground.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Builder(
      builder: (context) {
        final theme = context.theme;
        return Text(
          title,
          style: theme.typography.body.sm.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colors.mutedForeground,
          ),
        );
      },
    );
  }
}
