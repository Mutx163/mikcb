import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/course.dart';
import '../../../models/exam.dart';
import '../../../models/timetable_settings.dart';
import '../../open_container.dart';
import '../timetable_form_pages.dart';
import 'day_view_agenda_surface.dart';
import 'day_view_ink_style.dart';

/// 日视图议程列表里的**考试**卡片。
///
/// 2026-10-20 自 `timetable_day_view_part.dart` 的
/// `_TimetableScreenState._buildExamAgendaEntry` 搬出。墨色仍走与课程/日程卡
/// 一致的口径（[dayAgendaAutoInk]，判据是卡面材质 + 壁纸亮度带）：
///
/// 高斯模糊档下错误红只有 ~42% tint，亮色壁纸会透成浅粉底，写死的
/// 白墨会洗没；与课程/日程卡一致改用自动黑白墨色。
///
/// [linkedCourse] 是这门考试关联的课程（`provider.getCourseForExam`），
/// 没有关联时为 null —— 只影响卡片上是否多出一行课名。
class TimetableDayExamAgendaCard extends StatelessWidget {
  final Exam exam;
  final TimetableSettings settings;
  final Course? linkedCourse;
  final DayViewInkEnvironment inkEnvironment;

  /// 卡片圆角；正源是 `_TimetableScreenState._dayViewCardRadius`。
  final double radius;

  const TimetableDayExamAgendaCard({
    super.key,
    required this.exam,
    required this.settings,
    required this.linkedCourse,
    required this.inkEnvironment,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final ink = dayAgendaAutoInk(
      colorScheme.error,
      settings: settings,
      env: inkEnvironment,
    );
    final courseName = linkedCourse?.name ?? '';
    final location = exam.location ?? linkedCourse?.location ?? '';
    final daysUntil = exam.daysUntil;
    final countdownText = daysUntil == 0
        ? l10n.examCountdownToday
        : l10n.examCountdownDays(daysUntil);

    return OpenContainer<void>(
      key: ValueKey('day-view-exam-card-${exam.id}'),
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
      openBuilder: (context, _) => timetableFormPages.examForm(exam: exam),
      closedBuilder: (context, openContainer) {
        return DayViewAgendaSurface(
          settings: settings,
          radius: radius,
          color: colorScheme.error,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.error,
              Color.lerp(colorScheme.error, colorScheme.errorContainer, 0.25) ??
                  colorScheme.error,
            ],
          ),
          shadow: [
            BoxShadow(
              color: colorScheme.error.withValues(alpha: 0.20),
              blurRadius: 16,
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
                          Icon(Icons.school_outlined, size: 14, color: ink),
                          const SizedBox(width: 4),
                          Text(
                            l10n.examBadgeLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: dayAgendaInkWash(ink, lightAlpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        countdownText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  exam.name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 3.5),
                if (exam.startTime.isNotEmpty && exam.endTime.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '${exam.startTime} - ${exam.endTime}',
                      style: TextStyle(
                        fontSize: 13,
                        color: ink.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (location.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      location,
                      style: TextStyle(
                        fontSize: 13,
                        color: ink.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                if (courseName.isNotEmpty)
                  Text(
                    courseName,
                    style: TextStyle(
                      fontSize: 12,
                      color: ink.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
