import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../models/course.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../utils/hex_color.dart';
import 'course_card.dart';

/// Renders the home week timetable surface for settings previews.
class TimetableWeekPreview extends StatelessWidget {
  const TimetableWeekPreview({
    super.key,
    required this.provider,
    required this.settings,
    required this.week,
    this.height = 360,
  });

  final TimetableProvider provider;
  final TimetableSettings settings;
  final int week;
  final double height;

  static const double _headerHeight = 50;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final backgroundColor = theme.brightness == Brightness.dark
        ? colorScheme.surface
        : parseHexColorOrFallback(
            settings.timetablePageBackgroundColor,
            fallback: colorScheme.surface,
          );
    final showsFloatingButton =
        settings.timetableBackToCurrentWeekButtonStyle ==
        BackToCurrentWeekButtonStyle.floating;
    final bodyHeight = (height - _headerHeight).clamp(0.0, double.infinity);
    final sectionHeight =
        settings.timetableAutoFitSectionHeight && settings.sectionCount > 0
        ? bodyHeight / settings.sectionCount
        : settings.sectionHeight;

    return ColoredBox(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final grid = _buildTimetableGrid(
              context: context,
              availableWidth: constraints.maxWidth,
              week: week,
              sectionHeight: sectionHeight,
            );
            final gridBody = settings.timetableAutoFitSectionHeight
                ? grid
                : SingleChildScrollView(child: grid);

            return SizedBox(
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    children: [
                      _buildWeekDayHeader(
                        context: context,
                        week: week,
                        timeColumnWidth: _resolveTimeColumnWidth(settings),
                      ),
                      SizedBox(
                        height: bodyHeight,
                        child: IgnorePointer(child: gridBody),
                      ),
                    ],
                  ),
                  if (showsFloatingButton)
                    Positioned(
                      right: 8,
                      bottom: 12,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHigh.withValues(
                              alpha: settings
                                  .timetableFloatingBackToCurrentWeekButtonOpacity,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.7,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.my_location_rounded,
                                size: 13,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                l10n.backToCurrentWeekAction,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurface,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWeekDayHeader({
    required BuildContext context,
    required int week,
    required double timeColumnWidth,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final subtleBorder = context.theme.colors.border;
    final visibleDays = _visibleDayNumbers(settings);
    final canReturnToCurrentWeek = _canReturnToCurrentWeek(settings, week);
    final showsInlineBackToCurrentWeek =
        canReturnToCurrentWeek &&
        settings.timetableBackToCurrentWeekButtonStyle ==
            BackToCurrentWeekButtonStyle.inline;

    return Container(
      height: _headerHeight,
      padding: const EdgeInsets.fromLTRB(0, 1, 0, 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: subtleBorder, width: 1)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: timeColumnWidth,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.currentWeekCompact(week),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (showsInlineBackToCurrentWeek)
                  Text(
                    l10n.backToCurrentWeekAction,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 8,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: visibleDays.map((dayOfWeek) {
                final date = _dateForWeekDay(settings, week, dayOfWeek);
                final isToday =
                    date != null && _isSameDate(date, DateTime.now());
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final weekdayColor = isDark
                    ? settings.weekdayBarFontColorDark
                    : settings.weekdayBarFontColorLight;
                final accentColor = isDark
                    ? settings.weekdayBarAccentColorDark
                    : settings.weekdayBarAccentColorLight;
                final labelColor = isToday
                    ? parseHexColorOrFallback(
                        accentColor,
                        fallback: colorScheme.primary,
                      )
                    : parseHexColorOrFallback(
                        weekdayColor,
                        fallback: colorScheme.onSurface,
                      );
                final subLabelColor = isToday
                    ? parseHexColorOrFallback(
                        accentColor,
                        fallback: colorScheme.primary,
                      ).withValues(alpha: 0.78)
                    : parseHexColorOrFallback(
                        weekdayColor,
                        fallback: colorScheme.onSurfaceVariant,
                      ).withValues(alpha: 0.7);

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _weekdayLabel(context, dayOfWeek),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isToday
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: labelColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        date == null
                            ? ''
                            : '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 8.5, color: subLabelColor),
                      ),
                      if (date != null && provider.hasExamOnDate(date))
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: colorScheme.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimetableGrid({
    required BuildContext context,
    required double availableWidth,
    required int week,
    required double sectionHeight,
  }) {
    final visibleDays = _visibleDayNumbers(settings);
    final timeColumnWidth = _resolveTimeColumnWidth(settings);
    final cardInset = _resolveCourseCardInset(settings);
    final dayWidth = (availableWidth - timeColumnWidth) / visibleDays.length;
    final conflictMap = provider.courseConflictMapForWeek(week);
    final courses = _effectiveCourses(context);

    return SizedBox(
      width: availableWidth,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: timeColumnWidth,
            child: Column(
              children: List.generate(settings.sectionCount, (index) {
                final section = settings.sections[index];
                return SizedBox(
                  height: sectionHeight,
                  child: Center(
                    child: _buildSectionTimeCell(
                      context,
                      index + 1,
                      section,
                      sectionHeight,
                    ),
                  ),
                );
              }),
            ),
          ),
          Row(
            children: visibleDays.map((dayOfWeek) {
              final dayCourses = _getCoursesForDay(courses, week, dayOfWeek);
              final displayItems = _buildDayCourseDisplayItems(
                context: context,
                courses: dayCourses,
                week: week,
                conflictMap: conflictMap,
              );
              return SizedBox(
                width: dayWidth,
                child: _buildDayColumn(
                  context: context,
                  week: week,
                  dayOfWeek: dayOfWeek,
                  displayItems: displayItems,
                  sectionHeight: sectionHeight,
                  cardInset: cardInset,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDayColumn({
    required BuildContext context,
    required int week,
    required int dayOfWeek,
    required List<_DayCourseDisplayItem> displayItems,
    required double sectionHeight,
    required double cardInset,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final columnBackground = colorScheme.surfaceContainerLowest.withValues(
      alpha: 0.45,
    );
    final courseCards = <Widget>[];
    final date = _dateForWeekDay(settings, week, dayOfWeek);
    final isDayHoliday = date != null && provider.isHoliday(date);

    for (
      var sectionIndex = 0;
      sectionIndex < settings.sectionCount;
      sectionIndex++
    ) {
      final section = sectionIndex + 1;
      final startingCourses = displayItems
          .where((item) => item.course.startSection == section)
          .toList();

      for (final item in startingCourses) {
        courseCards.add(
          Positioned(
            top: sectionIndex * sectionHeight,
            left: 0,
            right: 0,
            height: item.course.sectionCount * sectionHeight,
            child: Opacity(
              opacity: item.opacity,
              child: CourseCard(
                course: item.course,
                overrideColorHex: _resolveDisplayCourseColor(item),
                compactOverlineText: _resolveCompactOverlineText(context, item),
                topRightBadgeText: _resolveCompactBadgeText(context, item),
                isHoliday: isDayHoliday,
                isSuspended: item.course.isSuspendedInWeek(week),
                isCompact: true,
                showName: settings.courseCardShowName,
                showTeacher: settings.courseCardShowTeacher,
                showLocation: settings.courseCardShowLocation,
                showTime: settings.courseCardShowTime,
                showTimeLabels: settings.courseCardShowTimeLabels,
                showWeeks: settings.courseCardShowWeeks,
                showDescription: settings.courseCardShowDescription,
                verticalAlign: settings.courseCardVerticalAlign,
                horizontalAlign: settings.courseCardHorizontalAlign,
                compactTitleFontSize: settings.courseCardFontSize,
                compactSubtitleFontSize: (settings.courseCardFontSize - 1)
                    .clamp(7.0, 14.0),
                compactVerticalPadding: sectionHeight < 64 ? 4 : 6,
                compactOuterInset: cardInset,
                titleColorHex: Theme.of(context).brightness == Brightness.dark
                    ? settings.courseCardTitleColorDark
                    : settings.courseCardTitleColorLight,
                detailColorHex: Theme.of(context).brightness == Brightness.dark
                    ? settings.courseCardDetailColorDark
                    : settings.courseCardDetailColorLight,
              ),
            ),
          ),
        );
      }
    }

    return Container(
      height: settings.sectionCount * sectionHeight,
      decoration: BoxDecoration(
        color: columnBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(clipBehavior: Clip.antiAlias, children: courseCards),
    );
  }

  Widget _buildSectionTimeCell(
    BuildContext context,
    int sectionNumber,
    SectionTime section,
    double sectionHeight,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeAxisColor = isDark
        ? settings.timeAxisFontColorDark
        : settings.timeAxisFontColorLight;
    final compactTextStyle = TextStyle(
      fontSize: (settings.compactFontSize - 2).clamp(6.0, 10.0),
      color: parseHexColorOrFallback(
        timeAxisColor,
        fallback: Colors.grey.shade600,
      ),
      height: 1.0,
    );

    return SizedBox(
      height: sectionHeight,
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$sectionNumber',
              style: TextStyle(
                fontSize: settings.compactFontSize.clamp(8.0, 11.0),
                fontWeight: FontWeight.bold,
                height: 1.0,
                color: parseHexColorOrFallback(
                  timeAxisColor,
                  fallback: Colors.grey.shade800,
                ),
              ),
            ),
            if (settings.timetableSectionTimeDisplayMode !=
                SectionTimeDisplayMode.hidden)
              Text(section.startTime, style: compactTextStyle),
            if (settings.timetableSectionTimeDisplayMode ==
                SectionTimeDisplayMode.startAndEnd)
              Text(section.endTime, style: compactTextStyle),
          ],
        ),
      ),
    );
  }

  List<Course> _effectiveCourses(BuildContext context) {
    if (provider.courses.isNotEmpty) {
      return provider.courses;
    }
    return _fallbackCourses(context);
  }

  List<Course> _fallbackCourses(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      Course(
        id: 'layout-preview-1',
        name: l10n.sampleCourseAdvancedMath,
        shortName: l10n.sampleCourseAdvancedMath,
        teacher: l10n.sampleTeacherZhang,
        location: 'A101',
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
        color: '#2563EB',
      ),
      Course(
        id: 'layout-preview-2',
        name: l10n.sampleCourseEnglish,
        shortName: l10n.sampleCourseEnglish,
        teacher: l10n.sampleTeacherLi,
        location: 'B203',
        dayOfWeek: 2,
        startSection: 2,
        endSection: 3,
        startTime: '08:55',
        endTime: '10:45',
        color: '#10B981',
      ),
    ];
  }

  List<_DayCourseDisplayItem> _buildDayCourseDisplayItems({
    required BuildContext context,
    required List<Course> courses,
    required int week,
    required Map<String, List<Course>> conflictMap,
  }) {
    return courses
        .where((course) {
          final isCurrentWeekCourse = course.isInWeek(week);
          if (isCurrentWeekCourse) {
            return true;
          }
          if (_hasCurrentWeekOverlap(courses, course, week)) {
            return false;
          }
          return _isPreferredNonCurrentCourse(courses, course, week);
        })
        .map((course) {
          final isCurrentWeekCourse = course.isInWeek(week);
          final isConflicting = conflictMap.containsKey(course.id);
          return _DayCourseDisplayItem(
            course: course,
            isCurrentWeekCourse: isCurrentWeekCourse,
            isConflicting: isConflicting,
            opacity: !isCurrentWeekCourse
                ? 0.62
                : (isConflicting ? settings.timetableConflictCourseOpacity : 1),
          );
        })
        .toList()
      ..sort((left, right) {
        final startCompare = left.course.startSection.compareTo(
          right.course.startSection,
        );
        if (startCompare != 0) {
          return startCompare;
        }
        final leftCurrent = left.isCurrentWeekCourse;
        final rightCurrent = right.isCurrentWeekCourse;
        if (leftCurrent != rightCurrent) {
          return leftCurrent ? 1 : -1;
        }
        final endCompare = left.course.endSection.compareTo(
          right.course.endSection,
        );
        if (endCompare != 0) {
          return endCompare;
        }
        return left.course.id.compareTo(right.course.id);
      });
  }

  String? _resolveDisplayCourseColor(_DayCourseDisplayItem item) {
    if (!item.isCurrentWeekCourse) {
      return '#94A3B8';
    }
    return settings.timetableUseUnifiedCardColor
        ? settings.timetableUnifiedCardColor
        : null;
  }

  String? _resolveCompactOverlineText(
    BuildContext context,
    _DayCourseDisplayItem item,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (!item.isCurrentWeekCourse) {
      return l10n.nonCurrentWeekLabel;
    }
    if (item.isConflicting && settings.showConflictBadgeOnTimetable) {
      return l10n.conflictLabel;
    }
    return null;
  }

  String? _resolveCompactBadgeText(
    BuildContext context,
    _DayCourseDisplayItem item,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (item.isConflicting && settings.showConflictBadgeOnTimetable) {
      return l10n.conflictLabel;
    }
    return null;
  }

  List<Course> _getCoursesForDay(
    List<Course> allCourses,
    int week,
    int dayOfWeek,
  ) {
    return allCourses.where((course) {
      if (course.dayOfWeek != dayOfWeek) {
        return false;
      }
      final isCurrentWeek = course.isInWeek(week);
      if (isCurrentWeek) {
        return true;
      }
      return settings.timetableShowNonCurrentWeekCourses;
    }).toList()..sort((a, b) {
      final startCompare = a.startSection.compareTo(b.startSection);
      if (startCompare != 0) return startCompare;
      final aCurrent = a.isInWeek(week);
      final bCurrent = b.isInWeek(week);
      if (aCurrent != bCurrent) {
        return aCurrent ? 1 : -1;
      }
      final endCompare = a.endSection.compareTo(b.endSection);
      if (endCompare != 0) return endCompare;
      return a.id.compareTo(b.id);
    });
  }

  bool _hasCurrentWeekOverlap(List<Course> courses, Course target, int week) {
    return courses.any(
      (course) =>
          course.id != target.id &&
          course.isInWeek(week) &&
          !(course.endSection < target.startSection ||
              target.endSection < course.startSection),
    );
  }

  bool _isPreferredNonCurrentCourse(
    List<Course> courses,
    Course target,
    int week,
  ) {
    final overlappingNonCurrentCourses =
        courses
            .where(
              (course) =>
                  !course.isInWeek(week) &&
                  !(course.endSection < target.startSection ||
                      target.endSection < course.startSection),
            )
            .toList()
          ..sort((left, right) {
            final leftDistance = _distanceToNearestActiveWeek(left, week);
            final rightDistance = _distanceToNearestActiveWeek(right, week);
            if (leftDistance != rightDistance) {
              return leftDistance.compareTo(rightDistance);
            }
            final startCompare = left.startWeek.compareTo(right.startWeek);
            if (startCompare != 0) {
              return startCompare;
            }
            final endCompare = left.endWeek.compareTo(right.endWeek);
            if (endCompare != 0) {
              return endCompare;
            }
            return left.id.compareTo(right.id);
          });

    return overlappingNonCurrentCourses.isNotEmpty &&
        overlappingNonCurrentCourses.first.id == target.id;
  }

  int _distanceToNearestActiveWeek(Course course, int week) {
    for (var offset = 0; offset <= 60; offset++) {
      final previousWeek = week - offset;
      if (previousWeek >= 1 && course.isInWeek(previousWeek)) {
        return offset;
      }
      final nextWeek = week + offset;
      if (offset > 0 && course.isInWeek(nextWeek)) {
        return offset;
      }
    }
    return 999;
  }

  List<int> _visibleDayNumbers(TimetableSettings settings) {
    return settings.timetableHideWeekends
        ? const [1, 2, 3, 4, 5]
        : const [1, 2, 3, 4, 5, 6, 7];
  }

  double _resolveTimeColumnWidth(TimetableSettings settings) {
    return switch (settings.timetableTimeColumnWidthMode) {
      TimetableTimeColumnWidthMode.narrow => 34,
      TimetableTimeColumnWidthMode.wide => 40,
    };
  }

  double _resolveCourseCardInset(TimetableSettings settings) {
    return settings.timetableCourseCardGap.clamp(0.0, 3.0);
  }

  DateTime? _dateForWeekDay(
    TimetableSettings settings,
    int week,
    int dayOfWeek,
  ) {
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

  int? _resolveCurrentSemesterWeek(TimetableSettings settings) {
    final semesterStart = settings.semesterStartDate;
    if (semesterStart == null) {
      return null;
    }

    final normalizedNow = DateTime.now();
    final normalizedToday = DateTime(
      normalizedNow.year,
      normalizedNow.month,
      normalizedNow.day,
    );
    final normalizedStart = DateTime(
      semesterStart.year,
      semesterStart.month,
      semesterStart.day,
    ).subtract(Duration(days: semesterStart.weekday - 1));
    final resolvedWeek =
        (normalizedToday.difference(normalizedStart).inDays ~/ 7) + 1;
    return resolvedWeek.clamp(1, settings.semesterWeekCount);
  }

  bool _canReturnToCurrentWeek(TimetableSettings settings, int week) {
    final currentSemesterWeek = _resolveCurrentSemesterWeek(settings);
    return currentSemesterWeek != null && currentSemesterWeek != week;
  }

  String _weekdayLabel(BuildContext context, int dayOfWeek) {
    final l10n = AppLocalizations.of(context)!;
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

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}

class _DayCourseDisplayItem {
  const _DayCourseDisplayItem({
    required this.course,
    required this.isCurrentWeekCourse,
    required this.isConflicting,
    required this.opacity,
  });

  final Course course;
  final bool isCurrentWeekCourse;
  final bool isConflicting;
  final double opacity;
}
