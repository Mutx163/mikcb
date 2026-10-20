import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/schedule_item.dart';
import '../../../models/timetable_settings.dart';
import '../../../screens/add_schedule_item_screen.dart';
import '../../../ui/hyperos/hyperos.dart';
import '../../../utils/home_page_background.dart';
import '../../day_agenda_info_row.dart';
import '../../open_container.dart';
import '../timetable_day_agenda_models.dart';
import 'day_view_agenda_parts.dart';
import 'day_view_agenda_surface.dart';
import 'day_view_ink_style.dart';

/// 日视图议程列表里的**日程**卡片。
///
/// 2026-10-20 自 `timetable_day_view_part.dart` 的
/// `_TimetableScreenState._buildScheduleAgendaEntry` +
/// `_buildCurrentScheduleAgendaCard` 搬出：进行中的日程换成带进度条的变体，
/// 其余走普通卡；点卡展开日程编辑页（跨天日程会带上这一次的 occurrenceDate）。
///
/// 墨色与课程卡同源（[dayAgendaAutoInk]）；[baseColor] 是调用方按
/// `item.color` 解析出来的日程色（进度调理也需要它，故由调用方一次算好传入）。
class TimetableDayScheduleAgendaCard extends StatelessWidget {
  final TimetableDayAgendaItem agendaItem;
  final TimetableSettings settings;
  final Color baseColor;
  final TimetableDayAgendaProgressInfo? progressInfo;
  final DayViewInkEnvironment inkEnvironment;

  /// 卡片圆角；正源是 `_TimetableScreenState._dayViewCardRadius`。
  final double radius;

  const TimetableDayScheduleAgendaCard({
    super.key,
    required this.agendaItem,
    required this.settings,
    required this.baseColor,
    required this.progressInfo,
    required this.inkEnvironment,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final item = agendaItem.scheduleItem!;
    final sourceItem = agendaItem.scheduleInstance?.item ?? item;
    final theme = Theme.of(context);
    final cardColor = Color.lerp(baseColor, Colors.black, 0.10) ?? baseColor;
    final l10n = AppLocalizations.of(context)!;
    final hasLocation = item.location?.trim().isNotEmpty == true;
    final hasNote = item.note?.trim().isNotEmpty == true;
    final isCrossDay = item.endDate.isAfter(item.startDate);
    final progress = progressInfo;
    // Same auto black/white as course agenda cards (glass over bright mist).
    final ink = dayAgendaAutoInk(cardColor, settings: settings, env: inkEnvironment);

    return OpenContainer<void>(
      key: ValueKey('day-view-schedule-card-${agendaItem.id}'),
      tappable: false,
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: const Duration(milliseconds: 360),
      openColor: theme.scaffoldBackgroundColor,
      closedColor: Colors.transparent,
      closedElevation: 0,
      openElevation: 0,
      closedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      // 放大到整屏后必须是**直角**：`openShape` 用默认直角，`openBuilder` 不再
      // 套同半径 ClipRRect，否则四角留着无人绘制的缺口、透出窗口黑底。
      // 详见 day_view_course_agenda_card.dart 同名说明。
      openBuilder: (context, _) => AddScheduleItemScreen(
        scheduleItem: sourceItem,
        occurrenceDate: agendaItem.scheduleInstance?.occurrenceDate,
      ),
      closedBuilder: (context, openContainer) {
        if (progress != null) {
          return Material(
            color: Colors.transparent,
            child: _ScheduleAgendaProgressCard(
              item: item,
              agendaItem: agendaItem,
              settings: settings,
              radius: radius,
              progressInfo: progress,
              ink: ink,
              onTap: openContainer,
            ),
          );
        }
        return DayViewAgendaSurface(
          settings: settings,
          radius: radius,
          color: cardColor,
          gradient: LinearGradient(colors: [cardColor, cardColor]),
          shadow: [
            BoxShadow(
              color: cardColor.withValues(alpha: 0.20),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
          onTap: openContainer,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
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
                          Icon(Icons.event_note_rounded, size: 13, color: ink),
                          const SizedBox(width: 5),
                          Text(
                            '${agendaItem.startTime} - ${agendaItem.endTime}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DayAgendaStatusBadge(
                      text: l10n.scheduleBadgeLabel,
                      textColor: ink,
                      backgroundColor: dayAgendaInkWash(ink, lightAlpha: 0.18),
                    ),
                    if (isCrossDay)
                      DayAgendaStatusBadge(
                        text: l10n.crossDayBadgeLabel,
                        textColor: ink,
                        backgroundColor: dayAgendaInkWash(
                          ink,
                          lightAlpha: 0.18,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w800,
                    height: 1.10,
                  ),
                ),
                if (hasLocation) ...[
                  const SizedBox(height: 10),
                  DayAgendaInfoRow(
                    icon: Icons.location_on_outlined,
                    text: l10n.locationPrefix(item.location!.trim()),
                    ink: ink,
                  ),
                ],
                if (hasNote) ...[
                  const SizedBox(height: 5.5),
                  DayAgendaInfoRow(
                    icon: Icons.notes_rounded,
                    text: item.note!.trim(),
                    ink: ink,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 正在进行的日程卡：玻璃卡面下叠一条进行时进度填充。
class _ScheduleAgendaProgressCard extends StatelessWidget {
  final ScheduleItem item;
  final TimetableDayAgendaItem agendaItem;
  final TimetableSettings settings;
  final double radius;
  final TimetableDayAgendaProgressInfo progressInfo;
  final Color ink;
  final VoidCallback onTap;

  const _ScheduleAgendaProgressCard({
    required this.item,
    required this.agendaItem,
    required this.settings,
    required this.radius,
    required this.progressInfo,
    required this.ink,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final hasLocation = item.location?.trim().isNotEmpty == true;
    final hasNote = item.note?.trim().isNotEmpty == true;
    final isCrossDay = item.endDate.isAfter(item.startDate);
    // See _CourseAgendaProgressCard: the fill must stay see-through on glass.
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
      // Flat fill, matching the legacy decoration (no gradient here).
      gradient: LinearGradient(
        colors: [progressInfo.baseColor, progressInfo.baseColor],
      ),
      shadow: [
        BoxShadow(
          color: progressInfo.fillColor.withValues(alpha: 0.18),
          blurRadius: 18,
          offset: const Offset(0, 4),
        ),
      ],
      onTap: onTap,
      child: ClipRRect(
        key: ValueKey('day-agenda-progress-schedule-card-${item.id}'),
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
                  // Below the 1 s tick so the tween settles between steps
                  // (see _quantizeDayAgendaProgress).
                  duration: const Duration(milliseconds: 600),
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
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
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
                              Icons.event_note_rounded,
                              size: 13,
                              color: ink,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${agendaItem.startTime} - ${agendaItem.endTime}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DayAgendaStatusBadge(
                        text: progressInfo.statusText,
                        textColor: progressInfo.statusTextColor,
                        backgroundColor: progressInfo.statusBackgroundColor,
                      ),
                      DayAgendaStatusBadge(
                        text: l10n.scheduleBadgeLabel,
                        textColor: ink,
                        backgroundColor: dayAgendaInkWash(
                          ink,
                          lightAlpha: 0.18,
                        ),
                      ),
                      if (isCrossDay)
                        DayAgendaStatusBadge(
                          text: l10n.crossDayBadgeLabel,
                          textColor: ink,
                          backgroundColor: dayAgendaInkWash(
                            ink,
                            lightAlpha: 0.18,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: ink,
                      fontWeight: FontWeight.w800,
                      height: 1.10,
                    ),
                  ),
                  if (hasLocation) ...[
                    const SizedBox(height: 10),
                    DayAgendaInfoRow(
                      icon: Icons.location_on_outlined,
                      text: l10n.locationPrefix(item.location!.trim()),
                      ink: ink,
                    ),
                  ],
                  if (hasNote) ...[
                    const SizedBox(height: 5.5),
                    DayAgendaInfoRow(
                      icon: Icons.notes_rounded,
                      text: item.note!.trim(),
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
