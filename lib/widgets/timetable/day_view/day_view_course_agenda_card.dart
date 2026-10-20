import 'package:flutter/material.dart';

import '../../../domain/couple_timetable_logic.dart';
import '../../../domain/day_course_display_logic.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/timetable_settings.dart';
import '../../../providers/timetable_provider.dart';
import '../../../ui/hyperos/hyperos.dart';
import '../../../utils/hex_color.dart';
import '../../../utils/home_page_background.dart';
import '../../course_note_sheet.dart';
import '../../day_agenda_info_row.dart';
import '../../day_course_weather_row.dart';
import '../../open_container.dart';
import '../../../screens/add_course_screen.dart';
import '../timetable_day_agenda_models.dart';
import 'day_view_agenda_parts.dart';
import 'day_view_agenda_surface.dart';
import 'day_view_ink_style.dart';

/// 日视图议程列表里的**课程**卡片（2026-10-20 自 `timetable_day_view_part.dart`
/// 的 `_TimetableScreenState._buildDayAgendaEntry` 课程分支 +
/// `_buildDefaultDayAgendaCard` + `_buildCurrentDayAgendaCard` 搬出）。
///
/// 行为与原实现逐像素一致：未开始/未结束的课走普通卡（`_CourseAgendaDefaultCard`），
/// 正在上的课换成带进度条的变体（`_CourseAgendaProgressCard`）；对方课（情侣
/// 课表）没有编辑页，点卡直接开课程操作面板 —— 这两条分支的 tap 语义分别由
/// [onOpenCourseActions] 与容器展开动作承担。
///
/// 颜色/材质判据（调色板、进度信息、卡片圆角、壁纸亮度）都由调用方算好传入，
/// 本组件只按同一套 widget 树摆出来；[provider] 只用于读情侣色与课程分组
/// （与原实现在同一位置按需取值的时机一致）。
///
/// OpenContainer 取的是 **vendored 优化版**（`lib/widgets/open_container.dart`），
/// 不是 pub 上的上游实现：上游在转场每帧重调 openBuilder/closedBuilder，日视图
/// 课程详情的 container transform 会变成每帧整页 rebuild（见该文件头注释）。本文件
/// 与 `day_view_exam_agenda_card.dart` / `day_view_schedule_agenda_card.dart`
/// 都从那里 import，别换回 `package:open_container`。
class TimetableDayCourseAgendaCard extends StatelessWidget {
  final DayCourseDisplayItem item;
  final int week;
  final TimetableSettings settings;

  /// 只用于 `coupleColorForKind` / `courseGroupForCourse`，不做响应式订阅。
  final TimetableProvider provider;

  final TimetableDayAgendaPalette palette;
  final TimetableDayAgendaProgressInfo? progressInfo;
  final DayViewInkEnvironment inkEnvironment;

  /// 卡片圆角；正源是 `_TimetableScreenState._dayViewCardRadius`。
  final double radius;

  /// 这节课所在那一周的日期（天气行用；学期开始日未设置时为 null）。
  final DateTime? courseDate;

  /// 对方课程点击 → State 的课程操作面板（`_showCourseActions`）。
  final VoidCallback onOpenCourseActions;

  const TimetableDayCourseAgendaCard({
    super.key,
    required this.item,
    required this.week,
    required this.settings,
    required this.provider,
    required this.palette,
    required this.progressInfo,
    required this.inkEnvironment,
    required this.radius,
    required this.courseDate,
    required this.onOpenCourseActions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final onCardColor = palette.foregroundColor;
    final statusBadges = <Widget>[
      if (item.isCurrentCourse)
        DayAgendaStatusBadge(
          text: l10n.ongoingCourseBadge,
          textColor: onCardColor,
          backgroundColor: Colors.white.withValues(alpha: 0.18),
        ),
      if (item.isConflicting && settings.showConflictBadgeOnTimetable)
        DayAgendaStatusBadge(
          text: l10n.conflictLabel,
          textColor: Colors.white,
          backgroundColor: colorScheme.error,
        ),
      if (item.coupleKind == CoupleCourseKind.together)
        DayAgendaStatusBadge(
          text: l10n.coupleTimetableLegendTogether,
          textColor: Colors.white,
          backgroundColor: parseHexColorOrFallback(
            provider.coupleColorForKind(CoupleCourseKind.together),
            fallback: Colors.purple,
          ),
        ),
      if (item.coupleKind == CoupleCourseKind.partner)
        DayAgendaStatusBadge(
          text: l10n.coupleTimetableLegendPartner,
          textColor: Colors.white,
          backgroundColor: parseHexColorOrFallback(
            provider.coupleColorForKind(CoupleCourseKind.partner),
            fallback: Colors.pink,
          ),
        ),
      if (!item.isCurrentWeekCourse)
        DayAgendaStatusBadge(
          text: l10n.nonCurrentWeekLabel,
          textColor: onCardColor,
          backgroundColor: Colors.white.withValues(alpha: 0.14),
        ),
      if (item.course.isSuspendedInWeek(week))
        DayAgendaStatusBadge(
          text: l10n.suspendedBadgeLabel,
          textColor: Colors.white,
          backgroundColor: Colors.red.shade700,
        ),
      if (!item.isPartnerCourse && item.course.hasHomeworkInWeek(week))
        const DayAgendaHomeworkDot(),
    ];
    final cardDecoration = BoxDecoration(
      color: palette.baseColor,
      borderRadius: BorderRadius.circular(radius),
      border: item.isConflicting
          ? Border.all(
              color: colorScheme.error.withValues(alpha: 0.30),
              width: 1.4,
            )
          : null,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          palette.baseColor,
          if (item.isConflicting)
            Color.lerp(palette.fillColor, colorScheme.error, 0.12) ??
                palette.fillColor
          else
            palette.fillColor,
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: (item.isConflicting ? colorScheme.error : palette.fillColor)
              .withValues(alpha: item.isConflicting ? 0.20 : 0.18),
          blurRadius: item.isConflicting ? 18 : 16,
          offset: const Offset(0, 4),
        ),
      ],
    );
    final isSuspended = item.course.isSuspendedInWeek(week);
    // Keep frost readable; only a light dim for suspended / conflict states.
    final effectiveOpacity = isSuspended ? 0.84 : item.opacity;
    final progress = progressInfo;

    Future<void> openCourseNotes() {
      return showCourseNoteSheet(
        context,
        course: item.course,
        week: week,
        readOnly: item.isPartnerCourse,
      );
    }

    Widget buildCard(VoidCallback openContainer) {
      if (progress != null) {
        return _CourseAgendaProgressCard(
          item: item,
          week: week,
          settings: settings,
          radius: radius,
          progressInfo: progress,
          ink: palette.foregroundColor,
          onTap: openContainer,
          onOpenNotes: openCourseNotes,
          opacityScale: effectiveOpacity,
          courseDate: courseDate,
        );
      }
      return _CourseAgendaDefaultCard(
        item: item,
        week: week,
        settings: settings,
        radius: radius,
        palette: palette,
        statusBadges: statusBadges,
        cardDecoration: cardDecoration,
        onTap: openContainer,
        onOpenNotes: openCourseNotes,
        opacityScale: effectiveOpacity,
        courseDate: courseDate,
      );
    }

    if (item.isPartnerCourse) {
      return Material(
        color: Colors.transparent,
        child: buildCard(onOpenCourseActions),
      );
    }

    // Released behaviour: tap expands the card into the editor via a container
    // transform. Dimming stays on opacityScale (not an Opacity wrapper) so
    // glass surfaces can still sample the backdrop.
    return OpenContainer<void>(
      key: ValueKey('day-view-edit-card-${item.course.id}'),
      tappable: false,
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: const Duration(milliseconds: 420),
      openColor: theme.scaffoldBackgroundColor,
      closedColor: Colors.transparent,
      closedElevation: 0,
      openElevation: 0,
      closedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      openShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      openBuilder: (context, _) => ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: AddCourseScreen(
          courseGroup: provider.courseGroupForCourse(item.course),
          initialCourse: item.course,
        ),
      ),
      closedBuilder: (context, openContainer) => Material(
        color: Colors.transparent,
        child: buildCard(openContainer),
      ),
    );
  }
}

/// 普通（未在上的）课程议程卡：时间胶囊 + 徽标 + 课名 + 教师/地点/天气/备注。
class _CourseAgendaDefaultCard extends StatelessWidget {
  final DayCourseDisplayItem item;
  final int week;
  final TimetableSettings settings;
  final double radius;
  final TimetableDayAgendaPalette palette;
  final List<Widget> statusBadges;
  final BoxDecoration cardDecoration;
  final VoidCallback onTap;
  final VoidCallback onOpenNotes;
  final double opacityScale;
  final DateTime? courseDate;

  const _CourseAgendaDefaultCard({
    required this.item,
    required this.week,
    required this.settings,
    required this.radius,
    required this.palette,
    required this.statusBadges,
    required this.cardDecoration,
    required this.onTap,
    required this.onOpenNotes,
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
class _CourseAgendaProgressCard extends StatelessWidget {
  final DayCourseDisplayItem item;
  final int week;
  final TimetableSettings settings;
  final double radius;
  final TimetableDayAgendaProgressInfo progressInfo;
  final Color ink;
  final VoidCallback onTap;
  final VoidCallback onOpenNotes;
  final double opacityScale;
  final DateTime? courseDate;

  const _CourseAgendaProgressCard({
    required this.item,
    required this.week,
    required this.settings,
    required this.radius,
    required this.progressInfo,
    required this.ink,
    required this.onTap,
    required this.onOpenNotes,
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
