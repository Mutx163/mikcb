import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../models/course.dart';
import '../models/timetable_settings.dart';
import 'course_field_picker_sheet.dart';
import '../ui/hyperos/hyperos.dart';

enum CourseDeleteMode { course, occurrence }

enum CourseSuspendMode { thisWeek, allWeeks }

class CourseRescheduleDraft {
  const CourseRescheduleDraft({
    required this.targetWeek,
    required this.targetDayOfWeek,
    required this.targetStartSection,
    required this.targetEndSection,
    required this.targetLocation,
  });

  final int targetWeek;
  final int targetDayOfWeek;
  final int targetStartSection;
  final int targetEndSection;
  final String targetLocation;
}

Future<CourseDeleteMode?> showCourseDeleteModeSheet(
  BuildContext context, {
  required bool canDeleteOccurrence,
  required int week,
}) {
  return showHomeHyperosSheet<CourseDeleteMode>(
    context: context,
    builder: (sheetContext) => _CourseDeleteModeSheetBody(
      canDeleteOccurrence: canDeleteOccurrence,
      week: week,
    ),
  );
}

Future<CourseSuspendMode?> showCourseSuspendModeSheet(
  BuildContext context, {
  required bool isSuspendedThisWeek,
  required bool hasAnySuspended,
}) {
  return showHomeHyperosSheet<CourseSuspendMode>(
    context: context,
    builder: (sheetContext) => _CourseSuspendModeSheetBody(
      isSuspendedThisWeek: isSuspendedThisWeek,
      hasAnySuspended: hasAnySuspended,
    ),
  );
}

Future<CourseRescheduleDraft?> showCourseRescheduleSheet(
  BuildContext context, {
  required Course course,
  required int sourceWeek,
  required TimetableSettings settings,
  required List<String> weekDays,
  required List<SectionTime> sectionTimes,
  required List<String> locationSuggestions,
}) {
  return showHomeHyperosSheet<CourseRescheduleDraft>(
    context: context,
    builder: (sheetContext) => _CourseRescheduleSheetBody(
      course: course,
      sourceWeek: sourceWeek,
      settings: settings,
      weekDays: weekDays,
      sectionTimes: sectionTimes,
      locationSuggestions: locationSuggestions,
    ),
  );
}

Future<bool> showDeleteCourseConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showHomeHyperosSheet<bool>(
    context: context,
    builder: (ctx) =>
        _DeleteCourseConfirmSheetBody(title: title, message: message),
  ).then((value) => value ?? false);
}

Future<bool> showDeleteOccurrenceConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDeleteCourseConfirmDialog(context, title: title, message: message);
}

class _CourseDeleteModeSheetBody extends StatelessWidget {
  const _CourseDeleteModeSheetBody({
    required this.canDeleteOccurrence,
    required this.week,
  });

  final bool canDeleteOccurrence;
  final int week;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.theme.colors;

    return _FollowupSheetContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _FollowupSheetHeader(
            icon: Icons.delete_outline_rounded,
            iconColor: colors.destructive,
            title: l10n.deleteModeTitle,
            subtitle: l10n.deleteModeSubtitle,
          ),
          const SizedBox(height: 14),
          _FollowupOptionTile(
            icon: Icons.delete_sweep_outlined,
            title: l10n.deleteCourseAction,
            onTap: () => Navigator.of(context).pop(CourseDeleteMode.course),
          ),
          const SizedBox(height: 8),
          _FollowupOptionTile(
            icon: Icons.remove_circle_outline_rounded,
            title: l10n.deleteOccurrenceAction,
            subtitle: canDeleteOccurrence
                ? l10n.deleteModeHintCurrentWeek(week)
                : l10n.deleteModeHintUnavailable(week),
            enabled: canDeleteOccurrence,
            onTap: canDeleteOccurrence
                ? () => Navigator.of(context).pop(CourseDeleteMode.occurrence)
                : null,
          ),
          const SizedBox(height: 14),
          _FollowupCancelButton(onPress: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }
}

class _CourseSuspendModeSheetBody extends StatelessWidget {
  const _CourseSuspendModeSheetBody({
    required this.isSuspendedThisWeek,
    required this.hasAnySuspended,
  });

  final bool isSuspendedThisWeek;
  final bool hasAnySuspended;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.theme.colors;

    return _FollowupSheetContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _FollowupSheetHeader(
            icon: isSuspendedThisWeek
                ? Icons.play_circle_outline_rounded
                : Icons.pause_circle_outline_rounded,
            iconColor: colors.foreground,
            title: l10n.suspendSheetTitle,
            subtitle: l10n.suspendSheetSubtitle,
          ),
          const SizedBox(height: 14),
          _FollowupOptionTile(
            icon: isSuspendedThisWeek
                ? Icons.play_circle_outline_rounded
                : Icons.pause_circle_outline_rounded,
            title: isSuspendedThisWeek
                ? l10n.courseActionUnsuspend
                : l10n.suspendThisWeek,
            subtitle: l10n.suspendThisWeekDesc,
            onTap: () => Navigator.of(context).pop(CourseSuspendMode.thisWeek),
          ),
          const SizedBox(height: 8),
          _FollowupOptionTile(
            icon: hasAnySuspended
                ? Icons.play_circle_outline_rounded
                : Icons.pause_circle_filled_outlined,
            title: hasAnySuspended
                ? l10n.unsuspendAllWeeks
                : l10n.suspendAllWeeks,
            subtitle: hasAnySuspended
                ? l10n.unsuspendAllWeeksDesc
                : l10n.suspendAllWeeksDesc,
            onTap: () => Navigator.of(context).pop(CourseSuspendMode.allWeeks),
          ),
          const SizedBox(height: 14),
          _FollowupCancelButton(onPress: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }
}

class _DeleteCourseConfirmSheetBody extends StatelessWidget {
  const _DeleteCourseConfirmSheetBody({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.theme.colors;
    final typo = context.theme.typography.body;

    return _FollowupSheetContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _FollowupSheetHeader(
            icon: Icons.delete_outline_rounded,
            iconColor: colors.destructive,
            title: title,
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: colors.muted.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message,
              style: typo.xs2.copyWith(
                color: colors.mutedForeground,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: HyperosButton(
                  label: l10n.cancelAction,
                  variant: HyperosButtonVariant.secondary,
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: HyperosButton(
                  label: l10n.deleteAction,
                  variant: HyperosButtonVariant.destructive,
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CourseRescheduleSheetBody extends StatefulWidget {
  const _CourseRescheduleSheetBody({
    required this.course,
    required this.sourceWeek,
    required this.settings,
    required this.weekDays,
    required this.sectionTimes,
    required this.locationSuggestions,
  });

  final Course course;
  final int sourceWeek;
  final TimetableSettings settings;
  final List<String> weekDays;
  final List<SectionTime> sectionTimes;
  final List<String> locationSuggestions;

  @override
  State<_CourseRescheduleSheetBody> createState() =>
      _CourseRescheduleSheetBodyState();
}

class _CourseRescheduleSheetBodyState
    extends State<_CourseRescheduleSheetBody> {
  late int _targetWeek;
  late int _targetDayOfWeek;
  late int _targetStartSection;
  late int _targetEndSection;
  late final TextEditingController _locationController;

  List<int> get _availableWeeks => widget.settings.availableWeeks;

  List<int> get _sectionNumbers =>
      List.generate(widget.settings.sectionCount, (index) => index + 1);

  @override
  void initState() {
    super.initState();
    _targetWeek = widget.sourceWeek;
    _targetDayOfWeek = widget.course.dayOfWeek;
    _targetStartSection = widget.course.startSection;
    _targetEndSection = widget.course.endSection;
    _locationController = TextEditingController(text: widget.course.location);
    _locationController.addListener(_handleLocationChanged);
  }

  void _handleLocationChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _locationController.removeListener(_handleLocationChanged);
    _locationController.dispose();
    super.dispose();
  }

  String _weekdayLabel(int dayOfWeek) {
    if (dayOfWeek < 1 || dayOfWeek > widget.weekDays.length) {
      return dayOfWeek.toString();
    }
    return widget.weekDays[dayOfWeek - 1];
  }

  String? _timeRangeForSections(int startSection, int endSection) {
    final sections = widget.sectionTimes;
    final startIndex = startSection - 1;
    final endIndex = endSection - 1;
    if (startIndex < 0 ||
        endIndex < 0 ||
        startIndex >= sections.length ||
        endIndex >= sections.length ||
        startSection > endSection) {
      return null;
    }
    return '${sections[startIndex].startTime}-${sections[endIndex].endTime}';
  }

  String _occurrenceLine({
    required AppLocalizations l10n,
    required int week,
    required int dayOfWeek,
    required int startSection,
    required int endSection,
    required String startTime,
    required String endTime,
  }) {
    final resolvedTime =
        _timeRangeForSections(startSection, endSection) ??
        '$startTime-$endTime';
    return '${l10n.weekLabel(week)} · ${_weekdayLabel(dayOfWeek)} · '
        '${l10n.sectionLabel(startSection)}-${l10n.sectionLabel(endSection)} · '
        '$resolvedTime';
  }

  bool get _hasChanges {
    final location = _locationController.text.trim();
    return widget.sourceWeek != _targetWeek ||
        widget.course.dayOfWeek != _targetDayOfWeek ||
        widget.course.startSection != _targetStartSection ||
        widget.course.endSection != _targetEndSection ||
        widget.course.location.trim() != location;
  }

  void _shiftWeek(int delta) {
    final weeks = _availableWeeks;
    final index = weeks.indexOf(_targetWeek);
    if (index == -1) {
      return;
    }
    final nextIndex = index + delta;
    if (nextIndex < 0 || nextIndex >= weeks.length) {
      return;
    }
    setState(() => _targetWeek = weeks[nextIndex]);
  }

  void _showLocationPicker() {
    final l10n = AppLocalizations.of(context)!;
    showCourseFieldPickerSheet(
      context,
      title: l10n.selectLocationTitle,
      suggestions: widget.locationSuggestions,
      controller: _locationController,
      onConfirmed: _handleLocationChanged,
    );
  }

  Widget _buildCompactSelectField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final theme = context.theme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.colors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: theme.typography.body.sm,
                    children: [
                      TextSpan(
                        text: '$label ',
                        style: TextStyle(color: theme.colors.mutedForeground),
                      ),
                      TextSpan(text: value),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: theme.colors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickInt({
    required String title,
    required Map<String, int> items,
    required int current,
    required ValueChanged<int> onSelected,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await showHyperosSelectSheet<int>(
      context: context,
      title: title,
      items: items,
      currentValue: current,
      cancelLabel: l10n.cancelAction,
    );
    if (!mounted || selected == null || selected == current) {
      return;
    }
    onSelected(selected);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.theme.colors;
    final typo = context.theme.typography.body;
    final weekIndex = _availableWeeks.indexOf(_targetWeek);
    final canDecrementWeek = weekIndex > 0;
    final canIncrementWeek =
        weekIndex != -1 && weekIndex < _availableWeeks.length - 1;
    final targetTimeRange = _timeRangeForSections(
      _targetStartSection,
      _targetEndSection,
    );
    final locationText = _locationController.text.trim();
    final sourceLine = _occurrenceLine(
      l10n: l10n,
      week: widget.sourceWeek,
      dayOfWeek: widget.course.dayOfWeek,
      startSection: widget.course.startSection,
      endSection: widget.course.endSection,
      startTime: widget.course.startTime,
      endTime: widget.course.endTime,
    );
    final targetLine = _occurrenceLine(
      l10n: l10n,
      week: _targetWeek,
      dayOfWeek: _targetDayOfWeek,
      startSection: _targetStartSection,
      endSection: _targetEndSection,
      startTime: widget.course.startTime,
      endTime: widget.course.endTime,
    );

    return _RescheduleSheetScaffold(
      actions: Row(
        children: [
          Expanded(
            child: HyperosButton(
              label: l10n.cancelAction,
              variant: HyperosButtonVariant.secondary,
              expand: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: HyperosButton(
              label: l10n.confirmRescheduleAction,
              expand: true,
              onPressed: _hasChanges
                  ? () {
                      Navigator.of(context).pop(
                        CourseRescheduleDraft(
                          targetWeek: _targetWeek,
                          targetDayOfWeek: _targetDayOfWeek,
                          targetStartSection: _targetStartSection,
                          targetEndSection: _targetEndSection,
                          targetLocation: _locationController.text,
                        ),
                      );
                    }
                  : null,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.rescheduleCurrentOccurrenceTitle,
            style: typo.lg.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.rescheduleCurrentOccurrenceSubtitle(widget.sourceWeek),
            style: typo.xs2.copyWith(
              color: colors.mutedForeground,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${l10n.currentBadge}：$sourceLine',
            style: typo.xs2.copyWith(
              color: colors.mutedForeground,
              height: 1.35,
            ),
          ),
          if (widget.course.location.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              l10n.locationPrefix(widget.course.location.trim()),
              style: typo.xs2.copyWith(color: colors.mutedForeground),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              _RescheduleStepButton(
                icon: Icons.remove_rounded,
                enabled: canDecrementWeek,
                onPress: () => _shiftWeek(-1),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactSelectField(
                  label: l10n.rescheduleTargetWeekLabel,
                  value: l10n.weekLabel(_targetWeek),
                  onTap: () => _pickInt(
                    title: l10n.rescheduleTargetWeekLabel,
                    items: {
                      for (final week in _availableWeeks)
                        l10n.weekLabel(week): week,
                    },
                    current: _targetWeek,
                    onSelected: (value) => setState(() => _targetWeek = value),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _RescheduleStepButton(
                icon: Icons.add_rounded,
                enabled: canIncrementWeek,
                onPress: () => _shiftWeek(1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var index = 0; index < widget.weekDays.length; index++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _WeekdayChoiceChip(
                      label: widget.weekDays[index],
                      selected: _targetDayOfWeek == index + 1,
                      onSelected: () =>
                          setState(() => _targetDayOfWeek = index + 1),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildCompactSelectField(
                  label: l10n.startSectionLabel,
                  value: l10n.sectionLabel(_targetStartSection),
                  onTap: () => _pickInt(
                    title: l10n.startSectionLabel,
                    items: {
                      for (final section in _sectionNumbers)
                        l10n.sectionLabel(section): section,
                    },
                    current: _targetStartSection,
                    onSelected: (value) {
                      setState(() {
                        _targetStartSection = value;
                        if (_targetEndSection < _targetStartSection) {
                          _targetEndSection = _targetStartSection;
                        }
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactSelectField(
                  label: l10n.endSectionLabel,
                  value: l10n.sectionLabel(_targetEndSection),
                  onTap: () => _pickInt(
                    title: l10n.endSectionLabel,
                    items: {
                      for (final section in _sectionNumbers.where(
                        (value) => value >= _targetStartSection,
                      ))
                        l10n.sectionLabel(section): section,
                    },
                    current: _targetEndSection,
                    onSelected: (value) {
                      setState(() => _targetEndSection = value);
                    },
                  ),
                ),
              ),
            ],
          ),
          if (targetTimeRange != null) ...[
            const SizedBox(height: 4),
            Text(
              targetTimeRange,
              style: typo.xs2.copyWith(color: colors.mutedForeground),
            ),
          ],
          const SizedBox(height: 8),
          CourseFieldPickerTile(
            label: l10n.locationLabel,
            value: locationText.isEmpty ? l10n.manualInputLabel : locationText,
            icon: Icons.location_on_outlined,
            isPlaceholder: locationText.isEmpty,
            onPress: _showLocationPicker,
          ),
          if (_hasChanges) ...[
            const SizedBox(height: 10),
            Text(
              '→ $targetLine',
              style: typo.sm.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            if (locationText.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                l10n.locationPrefix(locationText),
                style: typo.xs2.copyWith(color: colors.primary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _RescheduleSheetScaffold extends StatelessWidget {
  const _RescheduleSheetScaffold({required this.child, required this.actions});

  final Widget child;
  final Widget actions;

  static const _footerHeight = 48.0;
  static const _footerGap = 12.0;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return HyperosSheetFrame(
      frosted: true,
      maxHeight: maxHeight,
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: constraints.maxHeight),
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.only(
                    bottom: _footerHeight + _footerGap,
                  ),
                  child: child,
                ),
                Positioned(left: 0, right: 0, bottom: 0, child: actions),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RescheduleStepButton extends StatelessWidget {
  const _RescheduleStepButton({
    required this.icon,
    required this.enabled,
    required this.onPress,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    return HyperosIconButton(
      icon: icon,
      iconSize: 18,
      onPressed: enabled ? onPress : null,
    );
  }
}

class _WeekdayChoiceChip extends StatelessWidget {
  const _WeekdayChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typo = context.theme.typography.body;
    final colorScheme = Theme.of(context).colorScheme;
    final highlight = selected ? colorScheme.primary : colors.foreground;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? highlight.withValues(alpha: 0.14)
                : colors.muted.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? highlight.withValues(alpha: 0.45)
                  : colors.border,
            ),
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: typo.xs2.copyWith(
                color: highlight,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FollowupSheetContainer extends StatelessWidget {
  const _FollowupSheetContainer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return HyperosSheetFrame(
      frosted: true,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: child,
    );
  }
}

class _FollowupSheetHeader extends StatelessWidget {
  const _FollowupSheetHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typo = context.theme.typography.body;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: typo.sm.copyWith(fontWeight: FontWeight.w700)),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: typo.xs2.copyWith(
                    color: colors.mutedForeground,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FollowupOptionTile extends StatelessWidget {
  const _FollowupOptionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typo = context.theme.typography.body;
    final tileBg = colors.muted.withValues(alpha: 0.35);
    final foreground = enabled ? colors.foreground : colors.mutedForeground;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: tileBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: typo.sm.copyWith(
                          fontWeight: FontWeight.w600,
                          color: foreground,
                          height: 1.25,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: typo.xs2.copyWith(
                            color: colors.mutedForeground,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: enabled
                      ? colors.mutedForeground
                      : colors.mutedForeground.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FollowupCancelButton extends StatelessWidget {
  const _FollowupCancelButton({required this.onPress});

  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SizedBox(
      width: double.infinity,
      child: HyperosButton(
        label: l10n.cancelAction,
        variant: HyperosButtonVariant.secondary,
        expand: true,
        onPressed: onPress,
      ),
    );
  }
}
