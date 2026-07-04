import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../../models/statistics_models.dart';

/// 数据故事卡片
class DataStoryCard extends StatelessWidget {
  final DataStory story;

  const DataStoryCard({super.key, required this.story});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = _title(l10n);
    final content = _content(l10n);

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  story.icon,
                  size: 22,
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _buildRichContent(context, content, colorScheme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _title(AppLocalizations l10n) {
    return switch (story.type) {
      StoryType.busiestDay => l10n.statisticsStoryBusiestDayTitle,
      StoryType.lightestDay => l10n.statisticsStoryLightestDayTitle,
      StoryType.favoriteRoom => l10n.statisticsStoryFavoriteRoomTitle,
      StoryType.buildingCount => l10n.statisticsStoryBuildingCountTitle,
      StoryType.timeRange => l10n.statisticsStoryTimeRangeTitle,
    };
  }

  String _content(AppLocalizations l10n) {
    final avg = story.averageSections?.toStringAsFixed(1) ?? '';
    final day = story.dayOfWeek != null
        ? _weekdayFullLabel(l10n, story.dayOfWeek!)
        : '';
    final week = story.weekNumber ?? 0;

    return switch (story.type) {
      StoryType.busiestDay => l10n.statisticsStoryBusiestDayContent(
        week,
        day,
        avg,
      ),
      StoryType.lightestDay => l10n.statisticsStoryLightestDayContent(
        week,
        day,
        avg,
      ),
      StoryType.favoriteRoom => l10n.statisticsStoryFavoriteRoomContent(
        week,
        story.room ?? '',
        story.visitCount ?? 0,
      ),
      StoryType.buildingCount => l10n.statisticsStoryBuildingCountContent(
        week,
        story.buildingCount ?? 0,
      ),
      StoryType.timeRange => l10n.statisticsStoryTimeRangeContent(
        story.earliestTime ?? '',
        story.latestTime ?? '',
      ),
    };
  }

  String _weekdayFullLabel(AppLocalizations l10n, int dayOfWeek) {
    return switch (dayOfWeek) {
      1 => l10n.weekdayMon,
      2 => l10n.weekdayTue,
      3 => l10n.weekdayWed,
      4 => l10n.weekdayThu,
      5 => l10n.weekdayFri,
      6 => l10n.weekdaySat,
      7 => l10n.weekdaySun,
      _ => dayOfWeek.toString(),
    };
  }

  /// 构建富文本内容（加粗 **text** 片段）
  Widget _buildRichContent(
    BuildContext context,
    String content,
    ColorScheme colorScheme,
  ) {
    final theme = Theme.of(context);
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\*\*(.*?)\*\*');
    int lastEnd = 0;

    for (final match in pattern.allMatches(content)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: content.substring(lastEnd, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      );
      lastEnd = match.end;
    }

    if (lastEnd < content.length) {
      spans.add(TextSpan(text: content.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
        children: spans,
      ),
    );
  }
}

/// 数据故事列表
class DataStoryList extends StatelessWidget {
  final List<DataStory> stories;

  const DataStoryList({super.key, required this.stories});

  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: stories
          .map(
            (story) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DataStoryCard(story: story),
            ),
          )
          .toList(),
    );
  }
}
