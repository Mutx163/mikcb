import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../domain/course_session_stats.dart';

/// 课次列表：每次课一行，展示日期、节次、状态与已有记录。
///
/// 这里只**读**现有数据（备注、作业、提醒、考试都从别处来），不提供任何
/// 录入入口 —— 本页的定位是「把已经存在的记录摊开看」，不新增负担。
class SessionListCard extends StatelessWidget {
  const SessionListCard({super.key, required this.stats});

  final CourseSessionStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (stats.isEmpty) {
      return HyperosControlCard(
        child: HyperosControlCardInset(
          child: Text(
            l10n.statisticsSessionEmpty,
            style: HyperosTypography.listDetail(context),
          ),
        ),
      );
    }

    return HyperosListGroup(
      children: [
        for (final session in stats.sessions)
          _SessionRow(session: session, hasCalendar: stats.hasCalendar),
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.hasCalendar});

  final CourseSession session;
  final bool hasCalendar;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scope = HyperosListTileScope.maybeOf(context);
    final secondary = HyperosColors.secondaryText(context);
    final phaseColor = _phaseColor(context, session.phase);

    return Padding(
      padding: HyperosTokens.rowPadding(
        isFirst: scope?.isFirst ?? true,
        isLast: scope?.isLast ?? true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _title(l10n, session, hasCalendar),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HyperosTypography.listTitle(context),
                ),
              ),
              const SizedBox(width: 8),
              // 考试按「本课 + 同一日历日」挂到课次上（领域层已算），
              // 当天有考试是最值得在行上看见的事。
              if (session.examCount > 0) ...[
                HyperosTag(
                  label: l10n.examBadgeLabel,
                  backgroundColor: HyperosIconColors.red.withValues(
                    alpha: 0.12,
                  ),
                  textStyle: HyperosTypography.listDetail(context).copyWith(
                    fontSize: HyperosMiuixTypography.footnote2,
                    fontWeight: FontWeight.w500,
                    color: HyperosIconColors.red,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              HyperosTag(
                label: _phaseLabel(l10n, session.phase),
                backgroundColor: phaseColor.withValues(alpha: 0.12),
                textStyle: HyperosTypography.listDetail(context).copyWith(
                  fontSize: HyperosMiuixTypography.footnote2,
                  fontWeight: FontWeight.w500,
                  color: phaseColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            _subtitle(l10n, session),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: HyperosTypography.listDetail(
              context,
            ).copyWith(color: secondary),
          ),
          if (_noteText(session) != null) ...[
            const SizedBox(height: 4),
            Text(
              _noteText(session)!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: HyperosTypography.listDetail(context),
            ),
          ],
        ],
      ),
    );
  }

  /// 课程名不在这里重复（整页只谈一门课），标题只描述「哪一次」。
  ///
  /// 日期用 DateFormat.MMMd（按当前语言出「9月16日 / Sep 16」），
  /// 与统计设置页的日期行同一习惯；不写死 yyyy-MM-dd。
  String _title(
    AppLocalizations l10n,
    CourseSession session,
    bool hasCalendar,
  ) {
    final date = session.date;
    if (date == null || !hasCalendar) {
      return '${l10n.statisticsWeekSelector(session.week)} · '
          '${_weekdayLabel(l10n, session.dayOfWeek)}';
    }
    final dayLabel = DateFormat.MMMd(l10n.localeName).format(date);
    return '$dayLabel · ${_weekdayLabel(l10n, session.dayOfWeek)}';
  }

  String _subtitle(AppLocalizations l10n, CourseSession session) {
    final parts = <String>[
      l10n.sectionRangeLabel(session.startSection, session.endSection),
    ];
    final start = session.startTime;
    final end = session.endTime;
    if (start != null && end != null) {
      parts.add('$start–$end');
    }
    final location = session.location.trim();
    if (location.isNotEmpty) {
      parts.add(location);
    }
    return parts.join(' · ');
  }

  String? _noteText(CourseSession session) {
    if (session.hasNote) {
      return session.noteText!.trim();
    }
    return null;
  }

  String _phaseLabel(AppLocalizations l10n, CourseSessionPhase phase) {
    return switch (phase) {
      CourseSessionPhase.done => l10n.statisticsSessionPhaseDone,
      CourseSessionPhase.today => l10n.statisticsSessionPhaseToday,
      CourseSessionPhase.upcoming => l10n.statisticsSessionPhaseUpcoming,
      CourseSessionPhase.suspended => l10n.statisticsSessionPhaseSuspended,
      CourseSessionPhase.holiday => l10n.statisticsSessionPhaseHoliday,
      CourseSessionPhase.undated => l10n.statisticsSessionPhaseUndated,
    };
  }

  Color _phaseColor(BuildContext context, CourseSessionPhase phase) {
    return switch (phase) {
      CourseSessionPhase.done => HyperosIconColors.green,
      CourseSessionPhase.today => HyperosColors.primary(context),
      CourseSessionPhase.upcoming => HyperosIconColors.blue,
      CourseSessionPhase.suspended => HyperosIconColors.orange,
      CourseSessionPhase.holiday => HyperosIconColors.purple,
      CourseSessionPhase.undated => HyperosColors.secondaryText(context),
    };
  }

  String _weekdayLabel(AppLocalizations l10n, int dayOfWeek) {
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
}
