import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../models/statistics_models.dart';

/// 成就徽章组件（含解锁动效与进度展示；点击弹出详情弹窗）
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
    ).drive(Tween<double>(begin: 0.5, end: 1));
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ).drive(Tween<double>(begin: 0, end: 1));
    if (widget.achievement.isUnlocked) {
      _controller.forward();
    } else {
      // 未达成的勋章不播解锁动效，直接置于动效终点，
      // 否则 FadeTransition 停在 0 会把整个锁定态勋章隐藏成空白。
      _controller.value = 1.0;
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showAchievementDetailSheet(
        context: context,
        achievement: achievement,
      ),
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
                          : accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(
                        AchievementBadge._medalRadius,
                      ),
                      border: unlocked
                          ? null
                          : Border.all(
                              color: accent.withValues(alpha: 0.28),
                              width: 0.5,
                            ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      achievement.icon,
                      size: 20,
                      color: unlocked
                          ? Colors.white
                          : accent.withValues(alpha: 0.55),
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
            // T0：勋章名是标签，回归常规体；锁定态用次级色区分
            style: HyperosTypography.listTitle(context).copyWith(
              fontSize: HyperosMiuixTypography.footnote2,
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
              // T1 轻强调：进度小字用 w500
              style: HyperosTypography.listDetail(context).copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w500,
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

/// 成就详情弹窗（通用组件：任意 [Achievement] 渲染同一套详情布局）
Future<void> showAchievementDetailSheet({
  required BuildContext context,
  required Achievement achievement,
}) {
  final l10n = AppLocalizations.of(context)!;
  final name = _achievementName(l10n, achievement.id);
  final accent = _achievementAccent(achievement.id);
  final description = _achievementDescription(l10n, achievement.id);
  final detail = _achievementDetail(l10n, achievement.id);
  final unlocked = achievement.isUnlocked;

  final progress = achievement.hasProgress
      ? (achievement.progressCurrent! / achievement.progressTarget!)
          .clamp(0.0, 1.0)
      : 0.0;

  return showHyperosSheet<void>(
    context: context,
    builder: (sheetContext) {
      return HyperosSheet(
        title: name,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 勋章大图
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: unlocked
                        ? accent
                        : accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(24),
                    border: unlocked
                        ? null
                        : Border.all(
                            color: accent.withValues(alpha: 0.28),
                            width: 0.5,
                          ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    achievement.icon,
                    size: 40,
                    color: unlocked
                        ? Colors.white
                        : accent.withValues(alpha: 0.55),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // 状态 + 进度
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HyperosTag(
                    label: unlocked
                        ? l10n.statisticsAchievementDone
                        : l10n.statisticsAchievementLocked,
                    backgroundColor: unlocked
                        ? accent.withValues(alpha: 0.14)
                        : HyperosColors.secondaryText(
                            context,
                          ).withValues(alpha: 0.1),
                    textStyle: HyperosTypography.listDetail(context).copyWith(
                      fontSize: HyperosMiuixTypography.footnote2,
                      // T1 轻强调：弹窗状态 Tag 用 w500
                      fontWeight: FontWeight.w500,
                      color: unlocked
                          ? accent
                          : HyperosColors.secondaryText(context),
                    ),
                  ),
                  if (achievement.hasProgress) ...[
                    const SizedBox(width: 10),
                    Text(
                      unlocked
                          ? l10n.statisticsAchievementProgress(
                              achievement.progressCurrent!,
                              achievement.progressTarget!,
                            )
                          : l10n.statisticsAchievementProgress(
                              achievement.progressCurrent!,
                              achievement.progressTarget!,
                            ),
                      style: HyperosTypography.listDetail(context).copyWith(
                        fontSize: HyperosMiuixTypography.footnote2,
                        fontWeight: FontWeight.w500,
                        color: HyperosColors.secondaryText(context),
                      ),
                    ),
                  ],
                ],
              ),
              if (achievement.hasProgress) ...[
                const SizedBox(height: 12),
                HyperosLinearProgress(
                  value: unlocked ? 1.0 : progress,
                ),
              ],
              const SizedBox(height: 16),
              // 一句话描述
              Text(
                description,
                style: HyperosTypography.listTitle(context).copyWith(
                  fontSize: HyperosMiuixTypography.footnote2 + 2,
                  height: 1.45,
                  color: HyperosColors.primaryText(context),
                ),
              ),
              const SizedBox(height: 8),
              // 详细说明
              Text(
                detail,
                style: HyperosTypography.listDetail(context).copyWith(
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              HyperosButton(
                label: l10n.statisticsAchievementDetailConfirm,
                expand: true,
                onPressed: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        ),
      );
    },
  );
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
    'morning_person' => HyperosIconColors.yellow,
    'gap_master' => HyperosIconColors.cyan,
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
    'morning_person' => l10n.statisticsAchievementMorningPersonName,
    'gap_master' => l10n.statisticsAchievementGapMasterName,
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
    'morning_person' => l10n.statisticsAchievementMorningPersonDescription,
    'gap_master' => l10n.statisticsAchievementGapMasterDescription,
    _ => id,
  };
}

String _achievementDetail(AppLocalizations l10n, String id) {
  return switch (id) {
    'early_bird' => l10n.statisticsAchievementEarlyBirdDetail,
    'perfect_attendance' => l10n.statisticsAchievementPerfectAttendanceDetail,
    'weekend_warrior' => l10n.statisticsAchievementWeekendWarriorDetail,
    'class_king' => l10n.statisticsAchievementClassKingDetail,
    'scholar' => l10n.statisticsAchievementScholarDetail,
    'balanced' => l10n.statisticsAchievementBalancedDetail,
    'night_owl' => l10n.statisticsAchievementNightOwlDetail,
    'explorer' => l10n.statisticsAchievementExplorerDetail,
    'full_day_king' => l10n.statisticsAchievementFullDayKingDetail,
    'building_hopper' => l10n.statisticsAchievementBuildingHopperDetail,
    'morning_person' => l10n.statisticsAchievementMorningPersonDetail,
    'gap_master' => l10n.statisticsAchievementGapMasterDetail,
    _ => id,
  };
}

/// 成就徽章网格
class AchievementGrid extends StatelessWidget {
  final List<Achievement> achievements;

  const AchievementGrid({super.key, required this.achievements});

  static const _columns = 4;
  static const _columnSpacing = 12.0;
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
