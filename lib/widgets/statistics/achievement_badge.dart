import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../../models/statistics_models.dart';

/// 成就徽章组件
class AchievementBadge extends StatelessWidget {
  final Achievement achievement;

  const AchievementBadge({super.key, required this.achievement});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.theme;
    final name = _achievementName(l10n, achievement.id);

    return Container(
      decoration: BoxDecoration(
        color: achievement.isUnlocked
            ? theme.colors.primary.withValues(alpha: 0.12)
            : theme.colors.muted,
        borderRadius: BorderRadius.circular(16),
        border: achievement.isUnlocked
            ? null
            : Border.all(color: theme.colors.border.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            achievement.icon,
            size: 24,
            color: achievement.isUnlocked
                ? theme.colors.primary
                : theme.colors.mutedForeground,
          ),
          const SizedBox(height: 4),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.body.xs.copyWith(
              fontWeight: FontWeight.w700,
              color: achievement.isUnlocked
                  ? theme.colors.foreground
                  : theme.colors.mutedForeground,
            ),
          ),
          if (!achievement.isUnlocked) ...[
            const SizedBox(height: 2),
            Icon(
              Icons.lock_outline_rounded,
              size: 12,
              color: theme.colors.mutedForeground.withValues(alpha: 0.5),
            ),
          ],
        ],
      ),
    );
  }
}

String _achievementName(AppLocalizations l10n, String id) {
  return switch (id) {
    'early_bird' => l10n.statisticsAchievementEarlyBirdName,
    'perfect_attendance' => l10n.statisticsAchievementPerfectAttendanceName,
    'weekend_warrior' => l10n.statisticsAchievementWeekendWarriorName,
    'class_king' => l10n.statisticsAchievementClassKingName,
    'scholar' => l10n.statisticsAchievementScholarName,
    'balanced' => l10n.statisticsAchievementBalancedName,
    'night_owl' => l10n.statisticsAchievementNightOwlName,
    'explorer' => l10n.statisticsAchievementExplorerName,
    _ => id,
  };
}

/// 成就徽章网格
class AchievementGrid extends StatelessWidget {
  final List<Achievement> achievements;

  const AchievementGrid({super.key, required this.achievements});

  @override
  Widget build(BuildContext context) {
    if (achievements.isEmpty) {
      return const SizedBox.shrink();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: achievements.length,
      itemBuilder: (context, index) {
        return AchievementBadge(achievement: achievements[index]);
      },
    );
  }
}
