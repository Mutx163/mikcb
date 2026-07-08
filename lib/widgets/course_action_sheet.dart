import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../models/course.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../utils/hex_color.dart';
import '../ui/hyperos/hyperos.dart';

typedef CourseActionHandler = void Function(Course course);

/// Shows the home timetable course action sheet with Forui styling.
Future<void> showCourseActionSheet(
  BuildContext context, {
  required List<Course> previewCourses,
  required int week,
  required bool hasConflicts,
  required CourseActionHandler onEdit,
  required CourseActionHandler onReschedule,
  required CourseActionHandler onDelete,
  required CourseActionHandler onSuspend,
}) {
  return showHomeHyperosSheet<void>(
    context: context,
    builder: (sheetContext) => CourseActionSheetBody(
      previewCourses: previewCourses,
      week: week,
      hasConflicts: hasConflicts,
      onEdit: onEdit,
      onReschedule: onReschedule,
      onDelete: onDelete,
      onSuspend: onSuspend,
    ),
  );
}

class CourseActionSheetBody extends StatelessWidget {
  const CourseActionSheetBody({
    super.key,
    required this.previewCourses,
    required this.week,
    required this.hasConflicts,
    required this.onEdit,
    required this.onReschedule,
    required this.onDelete,
    required this.onSuspend,
  });

  final List<Course> previewCourses;
  final int week;
  final bool hasConflicts;
  final CourseActionHandler onEdit;
  final CourseActionHandler onReschedule;
  final CourseActionHandler onDelete;
  final CourseActionHandler onSuspend;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;

    return HyperosSheetFrame(
      frosted: true,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < previewCourses.length; index++) ...[
              _CourseActionSheetContent(
                course: previewCourses[index],
                week: week,
                hasConflict: hasConflicts,
                onEdit: onEdit,
                onReschedule: onReschedule,
                onDelete: onDelete,
                onSuspend: onSuspend,
              ),
              if (index != previewCourses.length - 1) ...[
                const SizedBox(height: 20),
                Divider(color: colors.border, height: 1),
                const SizedBox(height: 20),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _CourseActionSheetContent extends StatelessWidget {
  const _CourseActionSheetContent({
    required this.course,
    required this.week,
    required this.hasConflict,
    required this.onEdit,
    required this.onReschedule,
    required this.onDelete,
    required this.onSuspend,
  });

  final Course course;
  final int week;
  final bool hasConflict;
  final CourseActionHandler onEdit;
  final CourseActionHandler onReschedule;
  final CourseActionHandler onDelete;
  final CourseActionHandler onSuspend;

  void _closeSheetThen(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.theme.colors;
    final typo = context.theme.typography.body;
    final provider = context.read<TimetableProvider>();
    final courseColor = parseHexColorOrFallback(
      course.color,
      fallback: colors.primary,
    );
    final natureLabel = course.courseNature == CourseNature.elective
        ? l10n.courseNatureElective
        : l10n.courseNatureRequired;
    final teacher = course.teacher.trim();
    final location = course.location.trim();
    final description = (course.description ?? course.note)?.trim();
    final headerDetail = description?.isNotEmpty == true
        ? description!
        : course.weekDescription(l10n);
    final sectionTitle =
        '${_weekdayLabel(l10n, course.dayOfWeek)} · ${l10n.sectionRangeLabel(course.startSection, course.endSection)}';
    final timeSubtitle = _formatTimeTileSubtitle(
      context,
      course: course,
      week: week,
      settings: provider.settings,
    );
    final teacherSubtitle = description?.isNotEmpty == true
        ? course.weekDescription(l10n)
        : (course.shortName?.trim().isNotEmpty == true
              ? l10n.shortNamePrefix(course.shortName!.trim())
              : course.weekDescription(l10n));
    final locationSubtitle =
        course.shortName?.trim().isNotEmpty == true &&
            description?.isNotEmpty == true
        ? l10n.shortNamePrefix(course.shortName!.trim())
        : course.weekDescription(l10n);
    final canReschedule = course.isInWeek(week);
    final isSuspended = course.isSuspendedInWeek(week);
    final muted = typo.xs2.copyWith(color: colors.mutedForeground);

    return Column(
      key: ValueKey('course-action-content-${course.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: courseColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.menu_book_rounded,
                color: courseColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        course.name,
                        style: typo.sm.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      Text(
                        natureLabel,
                        style: muted.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (hasConflict)
                        Text(
                          l10n.conflictLabel,
                          style: typo.xs2.copyWith(
                            color: colors.destructive,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${l10n.weekLabel(week)} · $headerDetail',
                    style: muted.copyWith(height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _CourseDetailTile(
          icon: Icons.schedule_outlined,
          title: sectionTitle,
          subtitle: timeSubtitle,
          trailing: Text(
            '${course.startTime}-${course.endTime}',
            style: muted.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        _CourseDetailTile(
          icon: Icons.person_outline_rounded,
          title: teacher.isNotEmpty ? teacher : l10n.unknownTeacher,
          subtitle: teacherSubtitle,
        ),
        const SizedBox(height: 8),
        _CourseDetailTile(
          icon: Icons.location_on_outlined,
          title: location.isNotEmpty ? location : l10n.unknownLocation,
          subtitle: locationSubtitle,
        ),
        const SizedBox(height: 12),
        _CourseDetailTile(
          icon: Icons.info_outline_rounded,
          titleWidget: Expanded(child: _CourseActionNoticeText(week: week)),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: HyperosButton(
            label: l10n.courseActionEditPrimary,
            expand: true,
            onPressed: () => _closeSheetThen(context, () => onEdit(course)),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: HyperosFrostedSheetButton(
                key: ValueKey('course-action-reschedule-${course.id}'),
                label: l10n.courseActionRescheduleSecondary,
                bordered: true,
                expand: true,
                onPressed: canReschedule
                    ? () => _closeSheetThen(context, () => onReschedule(course))
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: HyperosFrostedSheetButton(
                key: ValueKey('course-action-suspend-${course.id}'),
                label: isSuspended
                    ? l10n.courseActionUnsuspend
                    : l10n.courseActionSuspendSecondary,
                bordered: true,
                expand: true,
                onPressed: () =>
                    _closeSheetThen(context, () => onSuspend(course)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: HyperosButton(
                key: ValueKey('course-action-delete-${course.id}'),
                label: l10n.courseActionDeleteSecondary,
                variant: HyperosButtonVariant.destructive,
                expand: true,
                onPressed: () =>
                    _closeSheetThen(context, () => onDelete(course)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CourseDetailTile extends StatelessWidget {
  const _CourseDetailTile({
    required this.icon,
    this.title,
    this.subtitle,
    this.titleWidget,
    this.trailing,
  });

  final IconData icon;
  final String? title;
  final String? subtitle;
  final Widget? titleWidget;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final typo = context.theme.typography.body;
    final colors = context.theme.colors;

    return HyperosFrostedSurface(
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: colors.mutedForeground),
            const SizedBox(width: 10),
            if (titleWidget != null)
              titleWidget!
            else
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title!,
                      style: typo.sm.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: typo.xs2.copyWith(
                          color: colors.mutedForeground,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

class _CourseActionNoticeText extends StatelessWidget {
  const _CourseActionNoticeText({required this.week});

  final int week;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final typo = context.theme.typography.body;
    final colors = context.theme.colors;
    final notice = l10n.courseActionSheetNotice(week);
    final weekToken = week.toString();
    final weekIndex = notice.indexOf(weekToken);
    if (weekIndex == -1) {
      return Text(
        notice,
        style: typo.xs2.copyWith(color: colors.mutedForeground, height: 1.45),
      );
    }

    return Text.rich(
      TextSpan(
        style: typo.xs2.copyWith(color: colors.mutedForeground, height: 1.45),
        children: [
          TextSpan(text: notice.substring(0, weekIndex)),
          TextSpan(
            text: weekToken,
            style: TextStyle(
              color: colors.foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: notice.substring(weekIndex + weekToken.length)),
        ],
      ),
    );
  }
}

String _formatTimeTileSubtitle(
  BuildContext context, {
  required Course course,
  required int week,
  required TimetableSettings settings,
}) {
  final l10n = AppLocalizations.of(context)!;
  final date = _dateForWeekDay(settings, week, course.dayOfWeek);
  final parts = <String>[];

  if (date != null) {
    final localeName = Localizations.localeOf(context).toString();
    parts.add(DateFormat.MMMd(localeName).format(date));
  }

  parts.add(l10n.weekLabel(week));
  if (course.isOddWeek) {
    parts.add(l10n.courseActionOddWeekShort);
  } else if (course.isEvenWeek) {
    parts.add(l10n.courseActionEvenWeekShort);
  }

  return parts.join(' ');
}

String _weekdayLabel(AppLocalizations l10n, int dayOfWeek) {
  final labels = [
    l10n.weekdayMon,
    l10n.weekdayTue,
    l10n.weekdayWed,
    l10n.weekdayThu,
    l10n.weekdayFri,
    l10n.weekdaySat,
    l10n.weekdaySun,
  ];
  if (dayOfWeek < 1 || dayOfWeek > labels.length) {
    return dayOfWeek.toString();
  }
  return labels[dayOfWeek - 1];
}

DateTime? _dateForWeekDay(TimetableSettings settings, int week, int dayOfWeek) {
  final semesterStart = settings.semesterStartDate;
  if (semesterStart == null) {
    return null;
  }

  final normalizedStart = DateTime(
    semesterStart.year,
    semesterStart.month,
    semesterStart.day,
  ).subtract(Duration(days: semesterStart.weekday - 1));

  return normalizedStart.add(Duration(days: (week - 1) * 7 + dayOfWeek - 1));
}
