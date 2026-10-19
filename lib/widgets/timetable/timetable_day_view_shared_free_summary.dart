import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/couple_timetable_logic.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/hyperos/hyperos.dart';

/// 日视图「情侣共同空闲」摘要卡（2026-10-19 从课表页 State 搬出）。
///
/// 只做展示：空闲区间、是否过期、母卡墨色与强调色、展开态都由调用方算好传进来；
/// 展开动作只回调 [onExpand]，不持有 State。
class TimetableDayViewSharedFreeSummary extends StatelessWidget {
  static const int _visibleSegmentLimit = 2;

  final List<MinuteInterval> intervals;
  final bool isStale;
  final bool isToday;
  final Color ink;
  final Color freeAccent;
  final bool expanded;
  final VoidCallback onExpand;

  const TimetableDayViewSharedFreeSummary({
    super.key,
    required this.intervals,
    required this.isStale,
    required this.isToday,
    required this.ink,
    required this.freeAccent,
    required this.expanded,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final foruiTheme = context.theme;
    final title = isToday
        ? l10n.coupleTimetableSharedFreeTitle
        : l10n.coupleTimetableSharedFreeTitleOtherDay;
    final emptyLabel = isToday
        ? l10n.coupleTimetableNoSharedFree
        : l10n.coupleTimetableNoSharedFreeOtherDay;
    final mutedStyle = foruiTheme.typography.body.xs2.copyWith(
      color: ink.withValues(alpha: 0.62),
      fontWeight: FontWeight.w400,
      height: 1.25,
    );

    if (intervals.isEmpty) {
      return _SharedFreeSummaryShell(
        key: const ValueKey('shared-free-summary-empty'),
        ink: ink,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: foruiTheme.typography.body.sm.copyWith(
                color: ink,
                fontWeight: FontWeight.w400,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(emptyLabel, style: mutedStyle),
            if (isStale) ...[
              const SizedBox(height: 4),
              Text(l10n.coupleTimetableSharedFreeStaleHint, style: mutedStyle),
            ],
          ],
        ),
      );
    }

    final visibleLimit = expanded
        ? intervals.length
        : math.min(_visibleSegmentLimit, intervals.length);
    final visibleIntervals = intervals.take(visibleLimit).toList();
    final hiddenCount = intervals.length - visibleIntervals.length;

    return _SharedFreeSummaryShell(
      key: const ValueKey('shared-free-summary'),
      ink: ink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: foruiTheme.typography.body.sm.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: freeAccent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  l10n.coupleTimetableSharedFreeMeta(intervals.length),
                  style: foruiTheme.typography.body.xs2.copyWith(
                    color: freeAccent,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final interval in visibleIntervals)
                _SharedFreeTimeChip(
                  label: CoupleTimetableLogic.formatMinuteInterval(interval),
                  accent: freeAccent,
                ),
              if (hiddenCount > 0)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const ValueKey('shared-free-expand-button'),
                    onTap: onExpand,
                    borderRadius: BorderRadius.circular(999),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: freeAccent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        l10n.coupleTimetableSharedFreeMoreCount(hiddenCount),
                        style: foruiTheme.typography.body.xs.copyWith(
                          color: freeAccent,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (isStale) ...[
            const SizedBox(height: 8),
            Text(l10n.coupleTimetableSharedFreeStaleHint, style: mutedStyle),
          ],
        ],
      ),
    );
  }
}

class _SharedFreeSummaryShell extends StatelessWidget {
  final Color ink;
  final Widget child;

  const _SharedFreeSummaryShell({
    super.key,
    required this.ink,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        // 摘要卡内的嵌套面板跟随摘要墨色：浅洗底 + 细描边，玻璃/实心、
        // 明暗主题都与母卡同极性。此前误用 colorScheme.secondary（M3 基线
        // 浅色 #625B71 近黑），高斯模糊下整张卡在亮磨砂上读作发黑的一块，
        // 标题墨色（onSurface 近黑）也低于可读下限。
        color: ink.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ink.withValues(alpha: 0.10)),
      ),
      child: Padding(
        // 与摘要卡内其它区块同一套水平节奏，避免再套一层 14 造成左右过空。
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: child,
      ),
    );
  }
}

class _SharedFreeTimeChip extends StatelessWidget {
  final String label;
  final Color accent;

  const _SharedFreeTimeChip({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    final foruiTheme = context.theme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: foruiTheme.typography.body.xs.copyWith(
          color: accent,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
