import 'package:flutter/material.dart';

import '../../../domain/day_course_display_logic.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/timetable_settings.dart';
import '../../../ui/hyperos/hyperos.dart';
import '../../../ui/hyperos/hyperos_motion.dart';
import '../../../utils/home_page_background.dart';
import '../../day_agenda_info_row.dart';
import '../../day_course_weather_row.dart';
import '../timetable_day_agenda_models.dart';
import 'day_view_agenda_parts.dart';
import 'day_view_agenda_surface.dart';
import 'day_view_ink_style.dart';

/// 日视图课程卡的“普通/进行时”两变体（2026-10-20 从
/// `day_view_course_agenda_card.dart` 拆出，保持原样）。

class TimetableCourseAgendaDefaultCard extends StatelessWidget {
  final DayCourseDisplayItem item;
  final int week;
  final TimetableSettings settings;
  final double radius;
  final TimetableDayAgendaPalette palette;
  final List<Widget> statusBadges;
  final BoxDecoration cardDecoration;
  final VoidCallback onTap;
  final VoidCallback onOpenNotes;
  final VoidCallback onOpenTask;
  final bool hasTask;
  final double opacityScale;
  final DateTime? courseDate;

  const TimetableCourseAgendaDefaultCard({
    super.key,
    required this.item,
    required this.week,
    required this.settings,
    required this.radius,
    required this.palette,
    required this.statusBadges,
    required this.cardDecoration,
    required this.onTap,
    required this.onOpenNotes,
    required this.onOpenTask,
    this.hasTask = false,
    required this.opacityScale,
    required this.courseDate,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sectionLabel = l10n.sectionRangeLabel(
      item.course.startSection,
      item.course.endSection,
    );
    final teacherValue = item.course.teacher.trim().isNotEmpty
        ? item.course.teacher.trim()
        : l10n.unknownTeacher;
    final teacherLine = '${l10n.teacherPrefix(teacherValue)} · $sectionLabel';
    final locationValue = item.course.location.trim().isNotEmpty
        ? item.course.location.trim()
        : l10n.unknownLocation;
    final locationLine = l10n.locationPrefix(locationValue);
    final sessionNote = item.course.sessionNoteForWeek(week);
    final sessionPreview = sessionNote?.trimmedText;
    final ink = palette.foregroundColor;
    return DayViewAgendaSurface(
      settings: settings,
      radius: radius,
      color: palette.baseColor,
      opacityScale: opacityScale,
      // Reuse the legacy decoration's pieces so `solid` stays pixel-identical.
      gradient: cardDecoration.gradient,
      border: cardDecoration.border as Border?,
      shadow: cardDecoration.boxShadow,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: dayAgendaInkWash(ink, lightAlpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule_rounded, size: 13, color: ink),
                            const SizedBox(width: 5),
                            Text(
                              '${item.course.startTime} - ${item.course.endTime}',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: ink,
                                    fontWeight: FontWeight.w400,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      ...statusBadges,
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                DayAgendaTaskAction(
                  ink: ink,
                  onPressed: onOpenTask,
                  hasTask: hasTask,
                ),
                const SizedBox(width: 6),
                DayAgendaNoteAction(ink: ink, onPressed: onOpenNotes),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.course.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                // Auto ink: flips black/white against the wallpaper band
                // behind glass cards (white-on-white mist was unreadable).
                color: ink,
                fontWeight: FontWeight.w400,
                height: 1.10,
              ),
            ),
            const SizedBox(height: 10),
            DayAgendaInfoRow(
              icon: Icons.person_outline_rounded,
              text: teacherLine,
              ink: ink,
            ),
            const SizedBox(height: 5.5),
            DayAgendaInfoRow(
              icon: Icons.location_on_outlined,
              text: locationLine,
              ink: ink,
            ),
            DayCourseWeatherRow(
              date: courseDate,
              startTime: item.course.startTime,
              endTime: item.course.endTime,
              ink: ink,
              // 天气是「那一天」的属性，只有这节课这一周真的要上才有意义。
              // 非本周的灰卡（单双周错位、还没开课）代表的那一天并不上课，挂上
              // 那天的天气会让人以为当天要带伞；对方课程则是在别的城市，拿本地
              // 天气同样不对。教师、地点是课程属性，与哪一周无关，照常显示。
              visible:
                  settings.weatherShowOnDayCard &&
                  !item.isPartnerCourse &&
                  item.course.isActiveInWeek(week),
              showPhenomenon: settings.weatherShowPhenomenon,
              showTemperature: settings.weatherShowTemperature,
              showProbability: settings.weatherShowProbability,
            ),
            if (sessionPreview != null && sessionPreview.isNotEmpty) ...[
              const SizedBox(height: 5.5),
              DayAgendaInfoRow(
                icon: Icons.sticky_note_2_outlined,
                text: sessionPreview,
                ink: ink,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 正在上的课程议程卡：玻璃卡面下叠一条不透明的进行时进度填充。
class TimetableCourseAgendaProgressCard extends StatelessWidget {
  final DayCourseDisplayItem item;
  final int week;
  final TimetableSettings settings;
  final double radius;
  final TimetableDayAgendaProgressInfo progressInfo;
  final Color ink;
  final VoidCallback onTap;
  final VoidCallback onOpenNotes;
  final VoidCallback onOpenTask;
  final bool hasTask;
  final double opacityScale;
  final DateTime? courseDate;

  const TimetableCourseAgendaProgressCard({
    super.key,
    required this.item,
    required this.week,
    required this.settings,
    required this.radius,
    required this.progressInfo,
    required this.ink,
    required this.onTap,
    required this.onOpenNotes,
    required this.onOpenTask,
    this.hasTask = false,
    required this.opacityScale,
    required this.courseDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = theme.colorScheme;
    final sectionLabel = l10n.sectionRangeLabel(
      item.course.startSection,
      item.course.endSection,
    );
    final teacherValue = item.course.teacher.trim().isNotEmpty
        ? item.course.teacher.trim()
        : l10n.unknownTeacher;
    final teacherLine = '${l10n.teacherPrefix(teacherValue)} · $sectionLabel';
    final locationValue = item.course.location.trim().isNotEmpty
        ? item.course.location.trim()
        : l10n.unknownLocation;
    final locationLine = l10n.locationPrefix(locationValue);
    final borderColor = item.isConflicting
        ? colorScheme.error.withValues(alpha: 0.30)
        : Colors.transparent;
    final sessionNote = item.course.sessionNoteForWeek(week);
    final sessionPreview = sessionNote?.trimmedText;

    // Over glass the elapsed-progress fill has to stay see-through, or that
    // part of the card turns into a flat opaque block and the frost disappears.
    final progressFill =
        effectiveCourseCardSurfaceStyle(
              settings,
              gaussianBlurAvailable: HyperosBlurredHeader.backdropBlurEnabled(
                context,
              ),
            ) ==
            CourseCardSurfaceStyle.solid
        ? progressInfo.fillColor
        : progressInfo.fillColor.withValues(alpha: 0.55);

    return DayViewAgendaSurface(
      settings: settings,
      radius: radius,
      color: progressInfo.baseColor,
      opacityScale: opacityScale,
      // Flat fill, matching the legacy decoration (this card has no gradient).
      gradient: LinearGradient(
        colors: [progressInfo.baseColor, progressInfo.baseColor],
      ),
      border: Border.all(color: borderColor, width: 1.2),
      shadow: [
        BoxShadow(
          color: progressInfo.fillColor.withValues(alpha: 0.18),
          blurRadius: 18,
          offset: const Offset(0, 4),
        ),
      ],
      onTap: onTap,
      child: ClipRRect(
        key: ValueKey('day-agenda-progress-card-${item.course.id}'),
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            Positioned.fill(
              // Isolated: the animating fill must not invalidate the card's
              // glass surface / text layers on every animation frame.
              child: RepaintBoundary(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    end: progressInfo.progress.clamp(0.0, 1.0),
                  ),
                  // Must stay below the 1 s progress tick, or the tween is
                  // retargeted before it settles and day view animates every
                  // frame forever (see _quantizeDayAgendaProgress).
                  duration: 600.scaledMs,
                  builder: (context, animatedProgress, child) {
                    return FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: animatedProgress,
                      child: child,
                    );
                  },
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: progressFill,
                      borderRadius: BorderRadius.circular(radius),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: dayAgendaInkWash(ink, lightAlpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.schedule_rounded,
                                    size: 13,
                                    color: ink,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${item.course.startTime} - ${item.course.endTime}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: ink,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DayAgendaStatusBadge(
                              text: progressInfo.statusText,
                              textColor: progressInfo.statusTextColor,
                              backgroundColor:
                                  progressInfo.statusBackgroundColor,
                            ),
                            if (item.isConflicting)
                              DayAgendaStatusBadge(
                                text: l10n.conflictLabel,
                                textColor: Colors.white,
                                backgroundColor: colorScheme.error,
                              ),
                            if (!item.isPartnerCourse &&
                                item.course.hasHomeworkInWeek(week))
                              const DayAgendaHomeworkDot(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      DayAgendaTaskAction(
                        ink: ink,
                        onPressed: onOpenTask,
                        hasTask: hasTask,
                      ),
                      const SizedBox(width: 6),
                      DayAgendaNoteAction(ink: ink, onPressed: onOpenNotes),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.course.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: ink,
                      fontWeight: FontWeight.w400,
                      height: 1.10,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DayAgendaInfoRow(
                    icon: Icons.person_outline_rounded,
                    text: teacherLine,
                    ink: ink,
                  ),
                  const SizedBox(height: 5.5),
                  DayAgendaInfoRow(
                    icon: Icons.location_on_outlined,
                    text: locationLine,
                    ink: ink,
                  ),
                  DayCourseWeatherRow(
                    date: courseDate,
                    startTime: item.course.startTime,
                    endTime: item.course.endTime,
                    ink: ink,
                    // 同普通课卡：这一周真的上才有天气。判据用 isActiveInWeek
                    // （= 不在停课周 且 在本周上课范围内），一处覆盖两种情况。
                    visible:
                        settings.weatherShowOnDayCard &&
                        !item.isPartnerCourse &&
                        item.course.isActiveInWeek(week),
                    showPhenomenon: settings.weatherShowPhenomenon,
                    showTemperature: settings.weatherShowTemperature,
                    showProbability: settings.weatherShowProbability,
                  ),
                  if (sessionPreview != null && sessionPreview.isNotEmpty) ...[
                    const SizedBox(height: 5.5),
                    DayAgendaInfoRow(
                      icon: Icons.sticky_note_2_outlined,
                      text: sessionPreview,
                      ink: ink,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
