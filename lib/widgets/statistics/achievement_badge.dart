import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../models/statistics_models.dart';

/// 成就徽章组件
class AchievementBadge extends StatelessWidget {
  final Achievement achievement;

  const AchievementBadge({super.key, required this.achievement});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = _achievementName(l10n, achievement.id);
    final accent = _achievementAccent(achievement.id);

    return Container(
      decoration: BoxDecoration(
        color: achievement.isUnlocked
            ? accent.withValues(alpha: 0.12)
            : HyperosColors.secondaryText(context).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: achievement.isUnlocked
            ? null
            : Border.all(color: HyperosTokens.divider),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            achievement.icon,
            size: 22,
            color: achievement.isUnlocked
                ? accent
                : HyperosColors.secondaryText(context),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: HyperosTypography.listDetail(context).copyWith(
              fontSize: HyperosMiuixTypography.footnote2,
              fontWeight: FontWeight.w700,
              color: achievement.isUnlocked
                  ? HyperosColors.primaryText(context)
                  : HyperosColors.secondaryText(context),
            ),
          ),
          const SizedBox(height: 2),
          Icon(
            Icons.lock_outline_rounded,
            size: 12,
            color: achievement.isUnlocked
                ? Colors.transparent
                : HyperosColors.secondaryText(context).withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}

Color _achievementAccent(String id) {
  return switch (id) {
    'early_bird' => HyperosIconColors.orange,
    'perfect_attendance' => HyperosIconColors.green,
    'weekend_warrior' => HyperosIconColors.purple,
    'class_king' => HyperosIconColors.yellow,
    'scholar' => HyperosIconColors.blue,
    'balanced' => HyperosIconColors.teal,
    'night_owl' => HyperosIconColors.indigo,
    'explorer' => HyperosIconColors.cyan,
    _ => HyperosIconColors.blue,
  };
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

    return HyperosControlCard(
      child: HyperosControlCardInset(
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.12,
          ),
          itemCount: achievements.length,
          itemBuilder: (context, index) {
            return AchievementBadge(achievement: achievements[index]);
          },
        ),
      ),
    );
  }
}
