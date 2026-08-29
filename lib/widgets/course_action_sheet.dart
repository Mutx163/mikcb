import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../models/course.dart';
import '../models/timetable_settings.dart';
import '../domain/couple_timetable_logic.dart';
import '../providers/timetable_provider.dart';
import '../utils/hex_color.dart';
import '../ui/hyperos/hyperos.dart';
import 'course_note_sheet.dart';

typedef CourseActionHandler = void Function(Course course);

/// Fired when the user asks to arm the system-clock alarm for this course.
typedef CourseAlarmHandler = Future<void> Function(Course course);

class CourseActionPreviewItem {
  const CourseActionPreviewItem({
    required this.course,
    this.isPartnerCourse = false,
    this.coupleKind,
    this.isConflict = false,
  });

  final Course course;
  final bool isPartnerCourse;
  final CoupleCourseKind? coupleKind;
  final bool isConflict;

  bool get isReadOnly => isPartnerCourse;

  bool get isCoupleRelated =>
      coupleKind == CoupleCourseKind.together ||
      coupleKind == CoupleCourseKind.partner;
}

/// Shows the home timetable course action sheet with Forui styling.
Future<void> showCourseActionSheet(
  BuildContext context, {
  required List<CourseActionPreviewItem> previewItems,
  required int week,
  required CourseActionHandler onEdit,
  required CourseActionHandler onReschedule,
  required CourseActionHandler onDelete,
  required CourseActionHandler onSuspend,
  required CourseActionHandler onAddTask,
  CourseAlarmHandler? onSetAlarm,
}) {
  return showHomeHyperosSheet<void>(
    context: context,
    builder: (sheetContext) => CourseActionSheetBody(
      previewItems: previewItems,
      week: week,
      onEdit: onEdit,
      onReschedule: onReschedule,
      onDelete: onDelete,
      onSuspend: onSuspend,
      onAddTask: onAddTask,
      onSetAlarm: onSetAlarm,
    ),
  );
}

class CourseActionSheetBody extends StatefulWidget {
  const CourseActionSheetBody({
    super.key,
    required this.previewItems,
    required this.week,
    required this.onEdit,
    required this.onReschedule,
    required this.onDelete,
    required this.onSuspend,
    required this.onAddTask,
    this.onSetAlarm,
  });

  final List<CourseActionPreviewItem> previewItems;
  final int week;
  final CourseActionHandler onEdit;
  final CourseActionHandler onReschedule;
  final CourseActionHandler onDelete;
  final CourseActionHandler onSuspend;
  final CourseActionHandler onAddTask;
  final CourseAlarmHandler? onSetAlarm;

  @override
  State<CourseActionSheetBody> createState() => _CourseActionSheetBodyState();
}

class _CourseActionSheetBodyState extends State<CourseActionSheetBody> {
  final _scrollController = ScrollController();
  int _selectedIndex = 0;
  bool _relatedExpanded = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _selectCourse(int index) {
    if (index == _selectedIndex) {
      return;
    }
    setState(() {
      _selectedIndex = index;
      _relatedExpanded = false;
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedItem = widget.previewItems[_selectedIndex];
    final otherIndexes = <int>[
      for (var index = 0; index < widget.previewItems.length; index++)
        if (index != _selectedIndex) index,
    ];

    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return HyperosSheetFrame(
      frosted: true,
      maxHeight: maxHeight,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: constraints.maxHeight),
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CourseActionSheetContent(
                    key: ValueKey(
                      'course-action-selected-${selectedItem.course.id}',
                    ),
                    previewItem: selectedItem,
                    week: widget.week,
                    onEdit: widget.onEdit,
                    onReschedule: widget.onReschedule,
                    onDelete: widget.onDelete,
                    onSuspend: widget.onSuspend,
                    onAddTask: widget.onAddTask,
                    onSetAlarm: widget.onSetAlarm,
                  ),
                  if (otherIndexes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _RelatedCoursesPanel(
                      previewItems: widget.previewItems,
                      otherIndexes: otherIndexes,
                      week: widget.week,
                      expanded: _relatedExpanded,
                      onToggleExpanded: () {
                        setState(() => _relatedExpanded = !_relatedExpanded);
                      },
                      onSelect: _selectCourse,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RelatedCoursesPanel extends StatelessWidget {
  const _RelatedCoursesPanel({
    required this.previewItems,
    required this.otherIndexes,
    required this.week,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onSelect,
  });

  final List<CourseActionPreviewItem> previewItems;
  final List<int> otherIndexes;
  final int week;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.theme.colors;
    final typo = context.theme.typography.body;
    final muted = typo.xs2.copyWith(color: colors.mutedForeground);
    final conflictCount = otherIndexes
        .where((index) => previewItems[index].isConflict)
        .length;
    final coupleCount = otherIndexes.length - conflictCount;
    final accent = coupleCount > 0 && conflictCount == 0
        ? parseHexColorOrFallback(
            context.read<TimetableProvider>().coupleColorForKind(
              CoupleCourseKind.together,
            ),
            fallback: colors.primary,
          )
        : colors.destructive;
    final panelIcon = coupleCount > 0 && conflictCount == 0
        ? Icons.favorite_rounded
        : Icons.warning_amber_rounded;
    final previewNames = otherIndexes
        .map((index) => previewItems[index].course.name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    final previewLine = _conflictPreviewLine(previewNames);
    final title = _relatedPanelTitle(
      l10n,
      conflictCount: conflictCount,
      coupleCount: coupleCount,
      totalCount: otherIndexes.length,
    );
    final subtitle = expanded
        ? (coupleCount > 0 && conflictCount == 0
              ? l10n.courseActionCoupleCollapseHint
              : l10n.courseActionConflictCollapseHint)
        : (previewLine ??
              (coupleCount > 0 && conflictCount == 0
                  ? l10n.courseActionCoupleExpandHint
                  : l10n.courseActionConflictExpandHint));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HyperosFrostedSurface(
          borderRadius: BorderRadius.circular(HyperosTokens.controlRadius),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggleExpanded,
              borderRadius: BorderRadius.circular(HyperosTokens.controlRadius),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    Container(
                      width: HyperosTokens.iconBadgeSize,
                      height: HyperosTokens.iconBadgeSize,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(
                          HyperosTokens.iconBadgeRadius,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(panelIcon, size: 17, color: accent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: typo.sm.copyWith(height: 1.25),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: muted.copyWith(height: 1.3),
                            maxLines: expanded ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: colors.mutedForeground,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 8),
          for (
            var itemIndex = 0;
            itemIndex < otherIndexes.length;
            itemIndex++
          ) ...[
            if (itemIndex > 0) const SizedBox(height: 8),
            _RelatedCourseCompactRow(
              previewItem: previewItems[otherIndexes[itemIndex]],
              week: week,
              onTap: () => onSelect(otherIndexes[itemIndex]),
            ),
          ],
        ],
      ],
    );
  }
}

String _relatedPanelTitle(
  AppLocalizations l10n, {
  required int conflictCount,
  required int coupleCount,
  required int totalCount,
}) {
  if (coupleCount > 0 && conflictCount == 0) {
    return l10n.courseActionCoupleRelatedCount(coupleCount);
  }
  if (conflictCount > 0 && coupleCount == 0) {
    return l10n.conflictCountLabel(conflictCount);
  }
  return l10n.courseActionMixedRelatedCount(totalCount);
}

String? _conflictPreviewLine(List<String> names) {
  if (names.isEmpty) {
    return null;
  }
  if (names.length == 1) {
    return names.first;
  }
  if (names.length == 2) {
    return '${names[0]} · ${names[1]}';
  }
  return '${names[0]} · ${names[1]}…';
}

class _RelatedCourseCompactRow extends StatelessWidget {
  const _RelatedCourseCompactRow({
    required this.previewItem,
    required this.week,
    required this.onTap,
  });

  final CourseActionPreviewItem previewItem;
  final int week;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.theme.colors;
    final typo = context.theme.typography.body;
    final course = previewItem.course;
    final courseColor = _previewItemColor(context, previewItem, colors);
    final scheduleLine =
        '${_weekdayLabel(l10n, course.dayOfWeek)} · ${l10n.sectionRangeLabel(course.startSection, course.endSection)} · ${course.startTime}-${course.endTime}';
    final muted = typo.xs2.copyWith(color: colors.mutedForeground);
    final badgeLabel = _previewItemBadgeLabel(l10n, previewItem);

    return HyperosFrostedSurface(
      borderRadius: BorderRadius.circular(HyperosTokens.controlRadius),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(HyperosTokens.controlRadius),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: courseColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              course.name,
                              style: typo.sm.copyWith(height: 1.25),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (badgeLabel != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              badgeLabel,
                              style: typo.xs2.copyWith(color: courseColor),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        scheduleLine,
                        style: muted,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (course.location.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          course.location.trim(),
                          style: muted,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.courseActionConflictSwitchAction,
                  style: typo.xs2.copyWith(color: colors.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Color _previewItemColor(
  BuildContext context,
  CourseActionPreviewItem item,
  FColors colors,
) {
  if (item.coupleKind != null) {
    return parseHexColorOrFallback(
      context.read<TimetableProvider>().coupleColorForKind(item.coupleKind!),
      fallback: colors.primary,
    );
  }
  if (item.isConflict) {
    return colors.destructive;
  }
  return parseHexColorOrFallback(item.course.color, fallback: colors.primary);
}

String? _previewItemBadgeLabel(
  AppLocalizations l10n,
  CourseActionPreviewItem item,
) {
  if (item.isConflict) {
    return l10n.conflictLabel;
  }
  return switch (item.coupleKind) {
    CoupleCourseKind.together => l10n.coupleTimetableLegendTogether,
    CoupleCourseKind.partner => l10n.coupleTimetableLegendPartner,
    CoupleCourseKind.mine => l10n.coupleTimetableLegendMine,
    null => null,
  };
}

class _CourseActionSheetContent extends StatelessWidget {
  const _CourseActionSheetContent({
    super.key,
    required this.previewItem,
    required this.week,
    required this.onEdit,
    required this.onReschedule,
    required this.onDelete,
    required this.onSuspend,
    required this.onAddTask,
    this.onSetAlarm,
  });

  final CourseActionPreviewItem previewItem;
  final int week;
  final CourseActionHandler onEdit;
  final CourseActionHandler onReschedule;
  final CourseActionHandler onDelete;
  final CourseActionHandler onSuspend;
  final CourseActionHandler onAddTask;
  final CourseAlarmHandler? onSetAlarm;

  Course get course => previewItem.course;

  void _closeSheetThen(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  void _closeSheetThenAfterDismiss(BuildContext context, VoidCallback action) {
    final navigator = Navigator.of(context);
    navigator.pop();
    Future<void>.delayed(const Duration(milliseconds: 280), () {
      if (navigator.context.mounted) {
        action();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.theme.colors;
    final typo = context.theme.typography.body;
    final provider = context.watch<TimetableProvider>();
    var course = previewItem.course;
    for (final item in provider.courses) {
      if (item.id == previewItem.course.id) {
        course = item;
        break;
      }
    }
    final courseColor = _previewItemColor(
      context,
      CourseActionPreviewItem(
        course: course,
        isPartnerCourse: previewItem.isPartnerCourse,
        coupleKind: previewItem.coupleKind,
        isConflict: previewItem.isConflict,
      ),
      colors,
    );
    final coupleBadge = _previewItemBadgeLabel(l10n, previewItem);
    final natureLabel = course.courseNature == CourseNature.elective
        ? l10n.courseNatureElective
        : l10n.courseNatureRequired;
    final teacher = course.teacher.trim();
    final location = course.location.trim();
    final description = course.description?.trim();
    // Course intro is shared [description]; fall back to legacy per-entry note.
    final legacyNote = course.note?.trim();
    final courseIntroText = (description != null && description.isNotEmpty)
        ? description
        : ((legacyNote != null && legacyNote.isNotEmpty) ? legacyNote : null);
    final sessionNote = course.sessionNoteForWeek(week);
    final sessionNoteText = sessionNote?.trimmedText;
    final hasHomework = sessionNote?.hasHomework == true;
    final headerDetail = courseIntroText ?? course.weekDescription(l10n);
    final sectionTitle =
        '${_weekdayLabel(l10n, course.dayOfWeek)} · ${l10n.sectionRangeLabel(course.startSection, course.endSection)}';
    final timeSubtitle = _formatTimeTileSubtitle(
      context,
      course: course,
      week: week,
      settings: provider.settings,
    );
    final teacherSubtitle = courseIntroText != null
        ? course.weekDescription(l10n)
        : (course.shortName?.trim().isNotEmpty == true
              ? l10n.shortNamePrefix(course.shortName!.trim())
              : course.weekDescription(l10n));
    final locationSubtitle =
        course.shortName?.trim().isNotEmpty == true && courseIntroText != null
        ? l10n.shortNamePrefix(course.shortName!.trim())
        : course.weekDescription(l10n);
    final canReschedule = !previewItem.isReadOnly && course.isInWeek(week);
    final isSuspended = course.isSuspendedInWeek(week);
    final muted = typo.xs2.copyWith(color: colors.mutedForeground);
    final headerIcon = previewItem.coupleKind == CoupleCourseKind.together
        ? Icons.favorite_rounded
        : previewItem.isPartnerCourse
        ? Icons.person_outline_rounded
        : Icons.menu_book_rounded;
    final noteTitle = _resolveNoteTileTitle(
      l10n: l10n,
      wholeNote: courseIntroText,
      sessionNoteText: sessionNoteText,
      hasHomework: hasHomework,
    );
    final noteSubtitle = _resolveNoteTileSubtitle(
      l10n: l10n,
      wholeNote: courseIntroText,
      sessionNoteText: sessionNoteText,
      hasHomework: hasHomework,
    );
    final linkedTask = provider
        .getTasksForCourse(course.id)
        .where((task) => task.sourceWeek == null || task.sourceWeek == week)
        .firstOrNull;
    final linkedTaskTitle = linkedTask == null
        ? l10n.taskAddFromCourse
        : (linkedTask.title.trim().isEmpty
              ? l10n.taskHomeworkDefaultTitle
              : linkedTask.title.trim());
    final linkedTaskSubtitle = linkedTask == null
        ? l10n.taskListTitle
        : linkedTask.isCompleted
        ? l10n.taskCompletedSection
        : l10n.taskListTitle;

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
              child: Icon(headerIcon, color: courseColor, size: 24),
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
                      Text(course.name, style: typo.sm.copyWith(height: 1.2)),
                      if (!previewItem.isPartnerCourse)
                        Text(natureLabel, style: muted),
                      if (previewItem.isConflict)
                        Text(
                          l10n.conflictLabel,
                          style: typo.xs2.copyWith(color: colors.destructive),
                        ),
                      if (coupleBadge != null)
                        Text(
                          coupleBadge,
                          style: typo.xs2.copyWith(color: courseColor),
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
          trailing: Text('${course.startTime}-${course.endTime}', style: muted),
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
        const SizedBox(height: 8),
        _CourseDetailTile(
          icon: Icons.sticky_note_2_outlined,
          title: noteTitle,
          subtitle: noteSubtitle,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasHomework) ...[
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.assignment_outlined,
                    size: 11,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colors.mutedForeground,
              ),
            ],
          ),
          onTap: () {
            // Only one sheet at a time: close the action sheet, then open notes.
            final hostNavigator = Navigator.of(context);
            final courseSnapshot = course;
            final weekSnapshot = week;
            final isReadOnly = previewItem.isReadOnly;
            hostNavigator.pop();
            // Wait for the action sheet dismiss animation so the two never stack.
            Future<void>.delayed(const Duration(milliseconds: 280), () {
              final hostContext = hostNavigator.context;
              if (!hostContext.mounted) {
                return;
              }
              showCourseNoteSheet(
                hostContext,
                course: courseSnapshot,
                week: weekSnapshot,
                readOnly: isReadOnly,
              );
            });
          },
        ),
        if (!previewItem.isReadOnly) ...[
          const SizedBox(height: 8),
          _CourseDetailTile(
            icon: Icons.assignment_outlined,
            title: linkedTaskTitle,
            subtitle: linkedTaskSubtitle,
            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            onTap: () =>
                _closeSheetThenAfterDismiss(context, () => onAddTask(course)),
          ),
          if (onSetAlarm != null &&
              _isAlarmAvailable(
                settings: provider.settings,
                week: week,
                course: course,
                provider: provider,
              )) ...[
            const SizedBox(height: 8),
            _CourseDetailTile(
              icon: Icons.alarm_outlined,
              title: l10n.classAlarmActionLabel,
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () =>
                  _closeSheetThenAfterDismiss(context, () => onSetAlarm!(course)),
            ),
          ],
        ],
        const SizedBox(height: 12),
        _CourseDetailTile(
          icon: Icons.info_outline_rounded,
          titleWidget: Expanded(
            child: previewItem.isReadOnly
                ? Text(
                    l10n.courseActionPartnerReadOnlyNotice,
                    style: typo.xs2.copyWith(
                      color: colors.mutedForeground,
                      height: 1.45,
                    ),
                  )
                : _CourseActionNoticeText(week: week),
          ),
        ),
        if (!previewItem.isReadOnly) ...[
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
                  bordered: false,
                  expand: true,
                  onPressed: canReschedule
                      ? () =>
                            _closeSheetThen(context, () => onReschedule(course))
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
                  bordered: false,
                  expand: true,
                  onPressed: () =>
                      _closeSheetThen(context, () => onSuspend(course)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: HyperosFrostedSheetButton(
                  key: ValueKey('course-action-delete-${course.id}'),
                  label: l10n.courseActionDeleteSecondary,
                  variant: HyperosFrostedSheetButtonVariant.destructive,
                  expand: true,
                  onPressed: () =>
                      _closeSheetThen(context, () => onDelete(course)),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

String _resolveNoteTileTitle({
  required AppLocalizations l10n,
  required String? wholeNote,
  required String? sessionNoteText,
  required bool hasHomework,
}) {
  if (sessionNoteText != null && sessionNoteText.isNotEmpty) {
    return sessionNoteText;
  }
  if (hasHomework) {
    return l10n.courseNoteHomeworkMarked;
  }
  if (wholeNote != null && wholeNote.isNotEmpty) {
    return wholeNote;
  }
  return l10n.courseNoteAction;
}

String _resolveNoteTileSubtitle({
  required AppLocalizations l10n,
  required String? wholeNote,
  required String? sessionNoteText,
  required bool hasHomework,
}) {
  final hasSession =
      hasHomework || (sessionNoteText != null && sessionNoteText.isNotEmpty);
  final hasWhole = wholeNote != null && wholeNote.isNotEmpty;
  if (hasSession && hasWhole) {
    return l10n.courseNoteTileSubtitleBoth;
  }
  if (hasSession) {
    return l10n.courseNoteTileSubtitleSession;
  }
  if (hasWhole) {
    return l10n.courseNoteTileSubtitleWhole;
  }
  return l10n.courseNoteTileSubtitleEmpty;
}

class _CourseDetailTile extends StatelessWidget {
  const _CourseDetailTile({
    required this.icon,
    this.title,
    this.subtitle,
    this.titleWidget,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String? title;
  final String? subtitle;
  final Widget? titleWidget;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final typo = context.theme.typography.body;
    final colors = context.theme.colors;

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        // Center icon / text / trailing so chevrons sit mid-height on multi-line tiles.
        crossAxisAlignment: CrossAxisAlignment.center,
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
                    style: typo.sm.copyWith(height: 1.25),
                    maxLines: 2,
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );

    return HyperosFrostedSurface(
      borderRadius: BorderRadius.circular(HyperosTokens.controlRadius),
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(
                  HyperosTokens.controlRadius,
                ),
                child: content,
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
            style: TextStyle(color: colors.foreground),
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

bool _isAlarmAvailable({
  required TimetableSettings settings,
  required int week,
  required Course course,
  required TimetableProvider provider,
}) {
  final date = _dateForWeekDay(settings, week, course.dayOfWeek);
  if (date == null) return false;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final courseDate = DateTime(date.year, date.month, date.day);
  if (courseDate.isBefore(today)) return false;
  if (courseDate.isAfter(today)) return true;
  // 当天：已开课的不显示闹钟入口。
  final startText = provider.resolvedCourseStartTime(course);
  if (startText == null) return false;
  final parts = startText.split(':');
  if (parts.length != 2) return false;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return false;
  final startAt = DateTime(now.year, now.month, now.day, hour, minute);
  return now.isBefore(startAt);
}
