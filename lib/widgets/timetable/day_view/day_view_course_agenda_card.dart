import 'package:flutter/material.dart';

import '../../../domain/couple_timetable_logic.dart';
import '../../../domain/day_course_display_logic.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/timetable_settings.dart';
import '../../../providers/timetable_provider.dart';
import '../../../utils/hex_color.dart';
import '../../course_note_sheet.dart';
import '../../open_container.dart';
import '../../../screens/add_course_screen.dart';
import '../timetable_day_agenda_models.dart';
import 'day_view_agenda_parts.dart';
import 'day_view_course_agenda_card_variants.dart';
import 'day_view_ink_style.dart';

/// 日视图议程列表里的**课程**卡片（2026-10-20 自 `timetable_day_view_part.dart`
/// 的 `_TimetableScreenState._buildDayAgendaEntry` 课程分支 +
/// `_buildDefaultDayAgendaCard` + `_buildCurrentDayAgendaCard` 搬出）。
///
/// 行为与原实现逐像素一致：未开始/未结束的课走普通卡（`TimetableCourseAgendaDefaultCard`），
/// 正在上的课换成带进度条的变体（`TimetableCourseAgendaProgressCard`）；对方课（情侣
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
        return TimetableCourseAgendaProgressCard(
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
      return TimetableCourseAgendaDefaultCard(
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
