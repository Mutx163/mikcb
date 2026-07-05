import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../models/course.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../utils/hex_color.dart';

enum CourseActionType { edit, reschedule, delete }

class CourseActionSelection {
  const CourseActionSelection({required this.course, required this.action});

  final Course course;
  final CourseActionType action;
}

/// Shows the home timetable course action sheet with Forui styling.
Future<CourseActionSelection?> showCourseActionSheet(
  BuildContext context, {
  required List<Course> previewCourses,
  required int week,
  required bool hasConflicts,
  required void Function(Course course) onSuspend,
}) {
  return showFSheet<CourseActionSelection>(
    context: context,
    side: FLayout.btt,
    useSafeArea: true,
    draggable: true,
    builder: (sheetContext) => CourseActionSheetBody(
      previewCourses: previewCourses,
      week: week,
      hasConflicts: hasConflicts,
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
    required this.onSuspend,
  });

  final List<Course> previewCourses;
  final int week;
  final bool hasConflicts;
  final void Function(Course course) onSuspend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.theme.colors;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < previewCourses.length; index++) ...[
                _CourseActionPreviewCard(
                  course: previewCourses[index],
                  week: week,
                  badgeText: hasConflicts ? l10n.conflictLabel : null,
                ),
                const SizedBox(height: 6),
                Text(
                  previewCourses[index].isInWeek(week)
                      ? l10n.courseDialogCurrentWeekHint(week)
                      : l10n.courseDialogNotThisWeekHint(week),
                  style: context.theme.typography.body.xs3.copyWith(
                    color: colors.mutedForeground,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                _CourseActionButtonRow(
                  course: previewCourses[index],
                  week: week,
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
      ),
    );
  }
}

class _CourseActionPreviewCard extends StatelessWidget {
  const _CourseActionPreviewCard({
    required this.course,
    required this.week,
    this.badgeText,
  });

  final Course course;
  final int week;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.theme;
    final colors = theme.colors;
    final typo = theme.typography.body;
    final courseColor = parseHexColorOrFallback(
      course.color,
      fallback: colors.primary,
    );

    return FCard.raw(
      child: Padding(
        key: ValueKey('course-action-card-${course.id}'),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: courseColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: courseColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              course.name,
                              style: typo.sm.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (badgeText != null) ...[
                            const SizedBox(width: 8),
                            FBadge(
                              variant: FBadgeVariant.destructive,
                              child: Text(badgeText!),
                            ),
                          ],
                        ],
                      ),
                      if (course.shortName?.trim().isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            l10n.shortNamePrefix(course.shortName!.trim()),
                            style: typo.xs2.copyWith(
                              color: colors.mutedForeground,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${_weekdayLabel(l10n, course.dayOfWeek)} · 第${course.startSection}-${course.endSection}节 · ${course.startTime}-${course.endTime}',
              style: typo.xs2.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              course.weekDescription,
              style: typo.xs2.copyWith(color: colors.mutedForeground),
            ),
            if (course.teacher.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                l10n.teacherPrefix(course.teacher.trim()),
                style: typo.xs2.copyWith(color: colors.mutedForeground),
              ),
            ],
            if (course.location.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                l10n.locationPrefix(course.location.trim()),
                style: typo.xs2.copyWith(color: colors.mutedForeground),
              ),
            ],
            _CourseStatusChips(course: course, week: week),
          ],
        ),
      ),
    );
  }
}

class _CourseStatusChips extends StatelessWidget {
  const _CourseStatusChips({required this.course, required this.week});

  final Course course;
  final int week;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.theme.colors;
    final typo = context.theme.typography.body;
    final provider = context.read<TimetableProvider>();
    final date = _dateForWeekDay(provider.settings, week, course.dayOfWeek);
    final isDayHoliday = date != null && provider.isHoliday(date);
    final isSuspended = course.isSuspendedInWeek(week);
    final isNonCurrentWeek = !course.isInWeek(week);

    final chips = <_StatusChipData>[];
    if (isDayHoliday) {
      chips.add(
        _StatusChipData(
          label: l10n.holidayStatusLabel,
          color: Colors.orange.shade700,
          icon: Icons.beach_access_rounded,
        ),
      );
    }
    if (isSuspended) {
      chips.add(
        _StatusChipData(
          label: l10n.suspendedStatusLabel,
          color: colors.destructive,
          icon: Icons.pause_circle_outline_rounded,
        ),
      );
    }
    if (isNonCurrentWeek) {
      chips.add(
        _StatusChipData(
          label: l10n.nonCurrentWeekLabel,
          color: colors.mutedForeground,
          icon: Icons.schedule_outlined,
        ),
      );
    }
    if (course.suspensionDescription != null) {
      chips.add(
        _StatusChipData(
          label: course.suspensionDescription!,
          color: colors.destructive.withValues(alpha: 0.75),
          icon: Icons.info_outline_rounded,
        ),
      );
    }
    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final chip in chips)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: chip.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: chip.color.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(chip.icon, size: 14, color: chip.color),
                  const SizedBox(width: 4),
                  Text(
                    chip.label,
                    style: typo.xs3.copyWith(
                      color: chip.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CourseActionButtonRow extends StatelessWidget {
  const _CourseActionButtonRow({
    required this.course,
    required this.week,
    required this.onSuspend,
  });

  final Course course;
  final int week;
  final void Function(Course course) onSuspend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.theme.colors;
    final canReschedule = course.isInWeek(week);
    final isSuspended = course.isSuspendedInWeek(week);
    final itemWidth = ((MediaQuery.sizeOf(context).width - 32 - 36) / 4).clamp(
      72.0,
      112.0,
    );

    Widget tile({
      required Key key,
      required IconData icon,
      required String title,
      required VoidCallback onTap,
      Color? accentColor,
      bool enabled = true,
    }) {
      return SizedBox(
        width: itemWidth,
        child: _CourseActionTile(
          key: key,
          icon: icon,
          title: title,
          accentColor: accentColor,
          enabled: enabled,
          onTap: onTap,
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        tile(
          key: ValueKey('course-action-edit-${course.id}'),
          icon: Icons.edit_rounded,
          title: l10n.editActionShort,
          onTap: () => Navigator.of(context).pop(
            CourseActionSelection(
              course: course,
              action: CourseActionType.edit,
            ),
          ),
        ),
        tile(
          key: ValueKey('course-action-reschedule-${course.id}'),
          icon: Icons.swap_horiz_rounded,
          title: l10n.rescheduleAction,
          enabled: canReschedule,
          onTap: () => Navigator.of(context).pop(
            CourseActionSelection(
              course: course,
              action: CourseActionType.reschedule,
            ),
          ),
        ),
        tile(
          key: ValueKey('course-action-suspend-${course.id}'),
          icon: isSuspended
              ? Icons.play_circle_outline_rounded
              : Icons.pause_circle_outline_rounded,
          title: isSuspended
              ? l10n.courseActionUnsuspend
              : l10n.courseActionSuspend,
          accentColor: isSuspended ? null : colors.destructive,
          onTap: () {
            Navigator.of(context).pop();
            onSuspend(course);
          },
        ),
        tile(
          key: ValueKey('course-action-delete-${course.id}'),
          icon: Icons.delete_outline_rounded,
          title: l10n.deleteActionShort,
          accentColor: colors.destructive,
          onTap: () => Navigator.of(context).pop(
            CourseActionSelection(
              course: course,
              action: CourseActionType.delete,
            ),
          ),
        ),
      ],
    );
  }
}

class _CourseActionTile extends StatelessWidget {
  const _CourseActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.accentColor,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? accentColor;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typo = context.theme.typography;
    final colorScheme = Theme.of(context).colorScheme;
    final highlightColor = enabled
        ? accentColor ?? colorScheme.primary
        : colors.mutedForeground;

    return FCard.raw(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: highlightColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: highlightColor, size: 20),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: typo.body.xs3.copyWith(
                    fontWeight: FontWeight.w400,
                    height: 1.1,
                    color: enabled ? colors.foreground : colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChipData {
  const _StatusChipData({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;
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
