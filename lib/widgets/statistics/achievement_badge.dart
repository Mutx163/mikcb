import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../models/statistics_models.dart';

/// 成就徽章组件（含解锁动效与进度展示）
class AchievementBadge extends StatefulWidget {
  final Achievement achievement;

  const AchievementBadge({super.key, required this.achievement});

  static const _medalSize = 36.0;
  static const _medalRadius = 12.0;

  @override
  State<AchievementBadge> createState() => _AchievementBadgeState();
}

class _AchievementBadgeState extends State<AchievementBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late bool _wasUnlocked;

  @override
  void initState() {
    super.initState();
    _wasUnlocked = widget.achievement.isUnlocked;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ).drive(Tween<double>(begin: 0.5, end: 1.0));
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ).drive(Tween<double>(begin: 0, end: 1));
    if (widget.achievement.isUnlocked) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(AchievementBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    final unlocked = widget.achievement.isUnlocked;
    if (unlocked && !_wasUnlocked) {
      _controller.forward(from: 0);
    }
    _wasUnlocked = unlocked;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final achievement = widget.achievement;
    final name = _achievementName(l10n, achievement.id);
    final description = _achievementDescription(l10n, achievement.id);
    final accent = _achievementAccent(achievement.id);
    final unlocked = achievement.isUnlocked;

    final progressLabel = achievement.hasProgress
        ? (unlocked
              ? l10n.statisticsAchievementDone
              : l10n.statisticsAchievementProgress(
                  achievement.progressCurrent!,
                  achievement.progressTarget!,
                ))
        : null;

    return Tooltip(
      message: description,
      waitDuration: const Duration(milliseconds: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: AchievementBadge._medalSize,
                    height: AchievementBadge._medalSize,
                    decoration: BoxDecoration(
                      color: unlocked
                          ? accent
                          : HyperosColors.secondaryText(
                              context,
                            ).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(
                        AchievementBadge._medalRadius,
                      ),
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
            ),
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
          if (progressLabel != null) ...[
            const SizedBox(height: 2),
            Text(
              progressLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: HyperosTypography.listDetail(context).copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.1,
                color: unlocked
                    ? accent
                    : HyperosColors.secondaryText(context).withValues(alpha: 0.8),
              ),
            ),
          ],
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
    'full_day_king' => HyperosIconColors.red,
    'building_hopper' => HyperosIconColors.green,
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
    'full_day_king' => l10n.statisticsAchievementFullDayKingName,
    'building_hopper' => l10n.statisticsAchievementBuildingHopperName,
    _ => id,
  };
}

String _achievementDescription(AppLocalizations l10n, String id) {
  return switch (id) {
    'early_bird' => l10n.statisticsAchievementEarlyBirdDescription,
    'perfect_attendance' => l10n.statisticsAchievementPerfectAttendanceDescription,
    'weekend_warrior' => l10n.statisticsAchievementWeekendWarriorDescription,
    'class_king' => l10n.statisticsAchievementClassKingDescription,
    'scholar' => l10n.statisticsAchievementScholarDescription,
    'balanced' => l10n.statisticsAchievementBalancedDescription,
    'night_owl' => l10n.statisticsAchievementNightOwlDescription,
    'explorer' => l10n.statisticsAchievementExplorerDescription,
    'full_day_king' => l10n.statisticsAchievementFullDayKingDescription,
    'building_hopper' => l10n.statisticsAchievementBuildingHopperDescription,
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
