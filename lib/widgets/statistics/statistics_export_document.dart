import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../models/statistics_export_options.dart';
import '../../models/statistics_models.dart';
import 'achievement_badge.dart';
import 'daily_chart.dart';
import 'data_story_card.dart';
import 'nature_ratio.dart';
import 'overview_section.dart';
import 'statistics_export_brand_footer.dart';
import 'statistics_export_course_ranking.dart';

/// Full export layout: brand header + selected modules + brand footer.
///
/// Uses a non-scrolling [Column] so offscreen capture can measure full height.
class StatisticsExportDocument extends StatelessWidget {
  const StatisticsExportDocument({
    super.key,
    required this.options,
    required this.semesterStats,
    required this.achievements,
    required this.stories,
  });

  final StatisticsExportOptions options;
  final SemesterStats semesterStats;
  final List<Achievement> achievements;
  final List<DataStory> stories;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final modules = options.modules;
    final sections = <Widget>[];

    void appendSection(Widget section) {
      if (sections.isNotEmpty) {
        sections.add(const HyperosSectionGap());
      }
      sections.add(section);
    }

    if (modules.contains(StatisticsExportModule.overview)) {
      appendSection(OverviewSection(stats: semesterStats));
    }

    if (modules.contains(StatisticsExportModule.achievements) &&
        achievements.isNotEmpty) {
      appendSection(
        HyperosSettingsBlock(
          title: l10n.statisticsAchievementsTitle,
          child: AchievementGrid(achievements: achievements),
        ),
      );
    }

    if (modules.contains(StatisticsExportModule.stories) &&
        stories.isNotEmpty) {
      appendSection(
        HyperosSettingsBlock(
          title: l10n.statisticsStoriesTitle,
          child: DataStoryList(stories: stories),
        ),
      );
    }

    if (modules.contains(StatisticsExportModule.dailyDistribution)) {
      appendSection(
        HyperosSettingsBlock(
          title: l10n.statisticsDailyDistribution,
          child: DailyChart(dailyAverages: semesterStats.dailyAverages),
        ),
      );
    }

    if (modules.contains(StatisticsExportModule.natureRatio)) {
      appendSection(
        HyperosSettingsBlock(
          title: l10n.statisticsNatureRatio,
          child: NatureRatio(stats: semesterStats.natureStats),
        ),
      );
    }

    if (modules.contains(StatisticsExportModule.ranking)) {
      appendSection(
        HyperosSettingsBlock(
          title: l10n.statisticsRankingTitle,
          child: StatisticsExportCourseRanking(
            courseRanking: semesterStats.courseRanking,
          ),
        ),
      );
    }

    return ColoredBox(
      color: HyperosColors.scaffoldBackground(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            StatisticsExportBrandBar.header(),
            const SizedBox(height: 10),
            Text(
              l10n.statisticsShareTitle,
              style: HyperosTypography.sheetTitle(context),
            ),
            const SizedBox(height: 12),
            ...sections,
            const SizedBox(height: 12),
            StatisticsExportBrandBar.footer(),
          ],
        ),
      ),
    );
  }
}
