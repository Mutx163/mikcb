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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                    colorScheme,
                  )
                : _buildEmptyState(context, l10n, colorScheme),
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
    ColorScheme colorScheme,
  ) {
    return RepaintBoundary(
      key: _shareKey,
      child: Container(
        color: colorScheme.surface,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // 1. 学期总览（大数字）
            OverviewSection(stats: semesterStats),
            const SizedBox(height: 24),

            // 2. 成就徽章
            _buildSectionTitle(l10n.statisticsAchievementsTitle, colorScheme),
            const SizedBox(height: 12),
            AchievementGrid(achievements: achievements),
            const SizedBox(height: 24),

            // 3. 数据故事
            if (stories.isNotEmpty) ...[
              _buildSectionTitle(l10n.statisticsStoriesTitle, colorScheme),
              const SizedBox(height: 12),
              DataStoryList(stories: stories),
              const SizedBox(height: 24),
            ],

            // 4. 每日分布
            _buildSectionTitle(l10n.statisticsDailyDistribution, colorScheme),
            const SizedBox(height: 12),
            DailyChart(dailyAverages: semesterStats.dailyAverages),
            const SizedBox(height: 24),

            // 5. 必修/选修比例
            _buildSectionTitle(l10n.statisticsNatureRatio, colorScheme),
            const SizedBox(height: 12),
            NatureRatio(stats: semesterStats.natureStats),
            const SizedBox(height: 24),

            // 6. 课程排行
            _buildSectionTitle(l10n.statisticsRankingTitle, colorScheme),
            const SizedBox(height: 12),
            CourseRanking(courseRanking: semesterStats.courseRanking),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.statisticsNoData,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.statisticsNoDataHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ColorScheme colorScheme) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
          ),
        );
      },
    );
  }
}
