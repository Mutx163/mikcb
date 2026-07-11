import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../models/statistics_models.dart';

/// 成就徽章组件
class AchievementBadge extends StatelessWidget {
  final Achievement achievement;

  const AchievementBadge({super.key, required this.achievement});

  static const _medalSize = 36.0;
  static const _medalRadius = 12.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = _achievementName(l10n, achievement.id);
    final accent = _achievementAccent(achievement.id);
    final unlocked = achievement.isUnlocked;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: _medalSize,
              height: _medalSize,
              decoration: BoxDecoration(
                color: unlocked
                    ? accent
                    : HyperosColors.secondaryText(
                        context,
                      ).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(_medalRadius),
                border: unlocked
                    ? null
                    : Border.all(
                        color: HyperosColors.dividerLine(context),
                        width: 0.5,
                      ),
              ),
              alignment: Alignment.center,
              child: Icon(
                achievement.icon,
                size: 20,
                color: unlocked
                    ? Colors.white
                    : HyperosColors.secondaryText(
                        context,
                      ).withValues(alpha: 0.55),
              ),
            ),
            if (!unlocked)
              Positioned(
                right: -3,
                bottom: -3,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: HyperosColors.card(context),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: HyperosColors.dividerLine(context),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.lock_rounded,
                    size: 10,
                    color: HyperosColors.secondaryText(context),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: HyperosTypography.listDetail(context).copyWith(
            fontSize: HyperosMiuixTypography.footnote2,
            fontWeight: FontWeight.w600,
            height: 1.1,
            color: unlocked
                ? HyperosColors.primaryText(context)
                : HyperosColors.secondaryText(context),
          ),
        ),
      ],
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

  static const _columns = 4;
  static const _columnSpacing = 8.0;
  static const _rowSpacing = 12.0;

  @override
  Widget build(BuildContext context) {
    if (achievements.isEmpty) {
      return const SizedBox.shrink();
    }

    return HyperosControlCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth =
              (constraints.maxWidth - _columnSpacing * (_columns - 1)) /
              _columns;

          return Wrap(
            spacing: _columnSpacing,
            runSpacing: _rowSpacing,
            children: [
              for (final achievement in achievements)
                SizedBox(
                  width: itemWidth,
                  child: AchievementBadge(achievement: achievement),
                ),
            ],
          );
        },
      ),
    );
  }
}
