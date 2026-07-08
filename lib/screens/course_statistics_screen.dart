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
import '../ui/hyperos/hyperos.dart';

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
          semesterWeekCount: provider.settings.semesterWeekCount,
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

        return HyperosSubpage(
          onBack: () => Navigator.pop(context),
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
          child: hasData
              ? _buildContent(
                  context,
                  semesterStats,
                  achievements,
                  stories,
                  l10n,
                )
              : _buildEmptyState(context, l10n),
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
    return RepaintBoundary(
      key: _shareKey,
      child: HyperosListView(
        children: [
          OverviewSection(stats: semesterStats),
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
          HyperosSettingsBlock(
            title: l10n.statisticsRankingTitle,
            child: CourseRanking(courseRanking: semesterStats.courseRanking),
          ),
        ],
      ),
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
