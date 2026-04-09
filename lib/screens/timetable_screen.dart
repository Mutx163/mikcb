import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../models/course.dart';
import '../models/timetable_profile.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../services/app_update_service.dart';
import '../widgets/course_card.dart';
import 'add_course_screen.dart';
import 'about_screen.dart';
import 'course_import_screen.dart';
import 'course_overview_screen.dart';
import 'feedback_screen.dart';
import 'support_creator_screen.dart';
import 'timetable_profiles_screen.dart';
import 'timetable_settings_screen.dart';

class TimetableScreen extends StatefulWidget {
  final bool enableUpdateCheck;

  const TimetableScreen({
    super.key,
    this.enableUpdateCheck = true,
  });

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen>
    with WidgetsBindingObserver {
  static const int _minWeek = 1;
  static const Duration _weekSlideDuration = Duration(milliseconds: 280);

  late final PageController _weekPageController;
  bool _isSyncingWeekPage = false;
  int? _pendingSyncedWeek;
  final AppUpdateService _updateService = AppUpdateService();
  bool _hasAvailableUpdate = false;
  bool? _lastUpdateCheckIncludePrerelease;
  bool _isCheckingForUpdate = false;

  Color _colorFromHex(String hexColor, Color fallback) {
    try {
      final normalized = hexColor.replaceFirst('#', '');
      return Color(int.parse('FF$normalized', radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final provider = context.read<TimetableProvider>();
    final initialWeek = provider.currentWeek;
    _weekPageController = PageController(
      initialPage:
          _clampWeek(initialWeek, provider.settings.semesterWeekCount) - 1,
    );
    if (widget.enableUpdateCheck) {
      _checkForAppUpdate(
        includePrerelease: provider.settings.appUpdateIncludePrerelease,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _weekPageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.enableUpdateCheck) {
      _checkForAppUpdate(
        includePrerelease: context
            .read<TimetableProvider>()
            .settings
            .appUpdateIncludePrerelease,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        _scheduleUpdateCheckIfNeeded(provider);
        _syncWeekPageWithProvider(
          provider.currentWeek,
          provider.settings.semesterWeekCount,
        );
        final colorScheme = Theme.of(context).colorScheme;
        final backgroundColor = Theme.of(context).brightness == Brightness.dark
            ? colorScheme.surface
            : _colorFromHex(
                provider.settings.timetablePageBackgroundColor,
                colorScheme.surface,
              );
        return Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: backgroundColor,
          appBar: AppBar(
            backgroundColor: backgroundColor,
            surfaceTintColor: backgroundColor,
            title: _buildProfileSwitcherTrigger(provider),
            actions: [
              IconButton(
                tooltip: l10n.moreTooltip,
                onPressed: _showTopActionsSheet,
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.more_vert_rounded),
                    if (_hasAvailableUpdate)
                      Positioned(
                        right: -1,
                        top: -1,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: backgroundColor,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : MediaQuery.removeViewInsets(
                  context: context,
                  removeBottom: true,
                  child: Container(
                    color: backgroundColor,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return _buildWeekPager(
                            provider,
                            provider.settings,
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );
                        },
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  List<String> _weekdayLabels(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      l10n.weekdayMon,
      l10n.weekdayTue,
      l10n.weekdayWed,
      l10n.weekdayThu,
      l10n.weekdayFri,
      l10n.weekdaySat,
      l10n.weekdaySun,
    ];
  }

  String _weekdayLabel(BuildContext context, int dayOfWeek) {
    final labels = _weekdayLabels(context);
    if (dayOfWeek < 1 || dayOfWeek > labels.length) {
      return dayOfWeek.toString();
    }
    return labels[dayOfWeek - 1];
  }

  Widget _buildProfileSwitcherTrigger(TimetableProvider provider) {
    return switch (provider.settings.homeTitleStyle) {
      HomeTitleStyle.classic => _buildClassicProfileSwitcherTrigger(provider),
      HomeTitleStyle.brand => _buildBrandProfileSwitcherTrigger(provider),
    };
  }

  Widget _buildClassicProfileSwitcherTrigger(TimetableProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      key: const ValueKey('profile_switcher_trigger'),
      onTap: _showProfileQuickSwitchSheet,
      behavior: HitTestBehavior.opaque,
      child: Text(l10n.timetableAppName),
    );
  }

  Widget _buildBrandProfileSwitcherTrigger(TimetableProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activeProfileName = provider.activeProfile?.name.trim();

    return InkWell(
      key: const ValueKey('profile_switcher_trigger'),
      borderRadius: BorderRadius.circular(18),
      onTap: _showProfileQuickSwitchSheet,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.timetableAppName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1.0,
                letterSpacing: 0.2,
              ),
            ),
            Text(
              (activeProfileName == null || activeProfileName.isEmpty)
                  ? l10n.switchProfileHint
                  : activeProfileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekDayHeader(
    TimetableProvider provider,
    int week,
    TimetableSettings settings,
    double timeColumnWidth,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final currentSemesterWeek = _resolveCurrentSemesterWeek(settings);
    final canReturnToCurrentWeek =
        currentSemesterWeek != null && currentSemesterWeek != week;
    final visibleDays = _visibleDayNumbers(settings);

    return Container(
      height: 50,
      padding: const EdgeInsets.fromLTRB(0, 1, 0, 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: timeColumnWidth,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: _showWeekSelector,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 2,
                    ),
                    child: Text(
                      l10n.currentWeekCompact(week),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                if (canReturnToCurrentWeek)
                  SizedBox(
                    height: 10,
                    child: OverflowBox(
                      minWidth: 0,
                      maxWidth: 72,
                      alignment: Alignment.topCenter,
                      child: InkWell(
                        onTap: () => _jumpToCurrentWeek(provider),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          child: Text(
                            l10n.backToCurrentWeekAction,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.visible,
                            style: TextStyle(
                              fontSize: 8,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ...visibleDays.map((dayOfWeek) {
            final date = _dateForWeekDay(settings, week, dayOfWeek);
            final isToday = date != null && _isSameDate(date, DateTime.now());

            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 1),
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isToday ? colorScheme.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _weekdayLabel(context, dayOfWeek),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                        color: isToday
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date == null
                          ? ''
                          : '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 8.5,
                        color: isToday
                            ? colorScheme.primary.withValues(alpha: 0.78)
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimetableGrid(
    TimetableProvider provider,
    TimetableSettings settings,
    double availableWidth,
    int week,
    double sectionHeight,
  ) {
    final visibleDays = _visibleDayNumbers(settings);
    final timeColumnWidth = _resolveTimeColumnWidth(settings);
    final cardInset = _resolveCourseCardInset(settings);
    final dayWidth = (availableWidth - timeColumnWidth) / visibleDays.length;
    final conflictMap = provider.courseConflictMapForWeek(week);

    return SizedBox(
      key: ValueKey<int>(week),
      width: availableWidth,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: timeColumnWidth,
            child: Column(
              children: List.generate(settings.sectionCount, (index) {
                final section = settings.sections[index];
                return Container(
                  height: sectionHeight,
                  alignment: Alignment.center,
                  child: _buildSectionTimeCell(index + 1, section, settings),
                );
              }),
            ),
          ),
          Row(
            children: visibleDays.map((dayOfWeek) {
              final dayCourses = _getCoursesForDay(
                provider.courses,
                week,
                dayOfWeek,
                settings,
              );
              return SizedBox(
                width: dayWidth,
                child: _buildDayColumn(
                  week,
                  dayOfWeek,
                  dayCourses,
                  settings,
                  conflictMap,
                  settings.showConflictBadgeOnTimetable,
                  sectionHeight,
                  cardInset,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekPager(
    TimetableProvider provider,
    TimetableSettings settings,
    double availableWidth,
    double availableHeight,
  ) {
    return PageView.builder(
      controller: _weekPageController,
      itemCount: settings.semesterWeekCount,
      allowImplicitScrolling: true,
      physics: const PageScrollPhysics(parent: ClampingScrollPhysics()),
      onPageChanged: (page) => _handleWeekPageChanged(page, provider),
      itemBuilder: (context, index) {
        final week = index + 1;
        return _buildWeekPage(
          provider,
          settings,
          availableWidth,
          availableHeight,
          week,
        );
      },
    );
  }

  Widget _buildWeekPage(
    TimetableProvider provider,
    TimetableSettings settings,
    double availableWidth,
    double availableHeight,
    int week,
  ) {
    final bodyAvailableHeight =
        (availableHeight - 50).clamp(0.0, double.infinity);
    final sectionHeight =
        settings.timetableAutoFitSectionHeight && settings.sectionCount > 0
            ? bodyAvailableHeight / settings.sectionCount
            : settings.sectionHeight;
    final grid = _buildTimetableGrid(
      provider,
      settings,
      availableWidth,
      week,
      sectionHeight,
    );

    return Column(
      children: [
        _buildWeekDayHeader(
          provider,
          week,
          settings,
          _resolveTimeColumnWidth(settings),
        ),
        Expanded(
          child: settings.timetableAutoFitSectionHeight
              ? grid
              : SingleChildScrollView(
                  key: PageStorageKey<String>('week-scroll-$week'),
                  child: grid,
                ),
        ),
      ],
    );
  }

  Widget _buildDayColumn(
    int week,
    int dayOfWeek,
    List<Course> courses,
    TimetableSettings settings,
    Map<String, List<Course>> conflictMap,
    bool showConflictBadge,
    double sectionHeight,
    double cardInset,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final columnBackground = colorScheme.surfaceContainerLowest.withValues(
      alpha: 0.45,
    );
    final overrideCardColor = settings.timetableUseUnifiedCardColor
        ? settings.timetableUnifiedCardColor
        : null;
    final courseCards = <Widget>[];
    final gridLines = <Widget>[];

    for (var sectionIndex = 0;
        sectionIndex < settings.sectionCount;
        sectionIndex++) {
      final section = sectionIndex + 1;
      final startingCourses = _getCoursesStartingAtSection(courses, section);

      gridLines.add(
        Positioned(
          top: sectionIndex * sectionHeight,
          left: 0,
          right: 0,
          height: sectionHeight,
          child: const SizedBox.expand(),
        ),
      );

      for (final course in startingCourses) {
        final isCurrentWeekCourse = course.isInWeek(week);
        if (!isCurrentWeekCourse &&
            _hasCurrentWeekOverlap(courses, course, week)) {
          continue;
        }
        if (!isCurrentWeekCourse &&
            !_isPreferredNonCurrentCourse(courses, course, week)) {
          continue;
        }
        final isConflicting = conflictMap.containsKey(course.id);
        courseCards.add(
          Positioned(
            top: sectionIndex * sectionHeight,
            left: 0,
            right: 0,
            height: course.sectionCount * sectionHeight,
            child: Opacity(
              opacity: !isCurrentWeekCourse
                  ? 0.62
                  : (isConflicting
                      ? settings.timetableConflictCourseOpacity
                      : 1),
              child: CourseCard(
                course: course,
                overrideColorHex:
                    isCurrentWeekCourse ? overrideCardColor : '#94A3B8',
                compactOverlineText: isCurrentWeekCourse ? null : '非本周',
                topRightBadgeText:
                    isConflicting && showConflictBadge ? '冲突' : null,
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
                onTap: () => _showCourseActions(course, week),
                compactTitleFontSize: settings.courseCardFontSize,
                compactSubtitleFontSize:
                    (settings.courseCardFontSize - 1).clamp(7.0, 14.0),
                compactVerticalPadding: sectionHeight < 64 ? 4 : 6,
                compactOuterInset: cardInset,
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
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: [
          ...gridLines,
          ...courseCards,
        ],
      ),
    );
  }

  Future<void> _showWeekSelector() async {
    final provider = context.read<TimetableProvider>();
    final availableWeeks = provider.settings.availableWeeks;
    final currentSemesterWeek = _resolveCurrentSemesterWeek(provider.settings);
    final selectedWeek = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final mediaQuery = MediaQuery.of(sheetContext);
        final maxSheetHeight = (mediaQuery.size.height -
                mediaQuery.padding.top -
                mediaQuery.padding.bottom -
                40)
            .clamp(260.0, 520.0);
        final maxSheetBodyHeight = (maxSheetHeight - 88).clamp(200.0, 360.0);
        final colorScheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxSheetHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '选择周次',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (currentSemesterWeek != null &&
                          provider.currentWeek != currentSemesterWeek)
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            shape: const StadiumBorder(),
                            backgroundColor:
                                colorScheme.primary.withValues(alpha: 0.12),
                            foregroundColor: colorScheme.primary,
                            minimumSize: const Size(0, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            side: BorderSide(
                              color:
                                  colorScheme.primary.withValues(alpha: 0.18),
                            ),
                          ),
                          onPressed: () => Navigator.of(sheetContext)
                              .pop(currentSemesterWeek),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.my_location_rounded, size: 18),
                              SizedBox(width: 6),
                              Text(
                                '回本周',
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.fade,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '共 ${availableWeeks.length} 周',
                    style: Theme.of(sheetContext).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SizedBox(
                      height: maxSheetBodyHeight,
                      child: GridView.builder(
                        itemCount: availableWeeks.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 2.1,
                        ),
                        itemBuilder: (gridContext, index) {
                          final week = availableWeeks[index];
                          final isCurrentSemesterWeek =
                              week == currentSemesterWeek;
                          final colorScheme = Theme.of(gridContext).colorScheme;
                          return FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              backgroundColor: isCurrentSemesterWeek
                                  ? colorScheme.primary.withValues(alpha: 0.12)
                                  : colorScheme.surfaceContainerLowest,
                              foregroundColor: isCurrentSemesterWeek
                                  ? colorScheme.primary
                                  : colorScheme.onSurface,
                              side: isCurrentSemesterWeek
                                  ? BorderSide(
                                      color: colorScheme.primary
                                          .withValues(alpha: 0.45),
                                    )
                                  : BorderSide(
                                      color: colorScheme.outlineVariant,
                                    ),
                            ),
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(week),
                            child: Text(
                              '第 $week 周',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: isCurrentSemesterWeek
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted || selectedWeek == null) {
      return;
    }

    await _jumpToWeek(provider, selectedWeek);
  }

  List<Course> _getCoursesStartingAtSection(List<Course> courses, int section) {
    return courses.where((course) => course.startSection == section).toList();
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
    final overlappingNonCurrentCourses = courses
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

  List<Course> _getCoursesForDay(
    List<Course> allCourses,
    int week,
    int dayOfWeek,
    TimetableSettings settings,
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
    }).toList()
      ..sort((a, b) {
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

  int _clampWeek(int week, int maxWeek) {
    if (week < _minWeek) return _minWeek;
    if (week > maxWeek) return maxWeek;
    return week;
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
    final week = (normalizedToday.difference(normalizedStart).inDays ~/ 7) + 1;
    return _clampWeek(
      week < 1 ? 1 : week,
      settings.semesterWeekCount,
    );
  }

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  Future<void> _jumpToCurrentWeek(TimetableProvider provider) async {
    if (provider.settings.semesterStartDate == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(AppLocalizations.of(context)!.pleaseSetSemesterStartDate),
        ),
      );
      return;
    }

    await provider.syncCurrentWeekWithSemesterStart();
    if (_weekPageController.hasClients) {
      await _weekPageController.animateToPage(
        provider.currentWeek - 1,
        duration: _weekSlideDuration,
        curve: Curves.easeOutCubic,
      );
    }
    _maybeSelectionClick(provider.settings);
  }

  Future<void> _animateToAdjacentWeek(
    TimetableProvider provider,
    int delta,
  ) async {
    if (_isSyncingWeekPage || !_weekPageController.hasClients) {
      return;
    }

    final targetWeek = _clampWeek(
        provider.currentWeek + delta, provider.settings.semesterWeekCount);
    if (targetWeek == provider.currentWeek) {
      return;
    }

    await _weekPageController.animateToPage(
      targetWeek - 1,
      duration: _weekSlideDuration,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _jumpToWeek(TimetableProvider provider, int week) async {
    if (_isSyncingWeekPage) {
      return;
    }

    final targetWeek = _clampWeek(week, provider.settings.semesterWeekCount);
    if (targetWeek == provider.currentWeek) {
      return;
    }

    final delta = targetWeek - provider.currentWeek;
    if (delta.abs() == 1) {
      await _animateToAdjacentWeek(provider, delta.sign);
      return;
    }

    if (!_weekPageController.hasClients) {
      await provider.setCurrentWeek(targetWeek);
      return;
    }

    await _weekPageController.animateToPage(
      targetWeek - 1,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _handleWeekPageChanged(
    int page,
    TimetableProvider provider,
  ) async {
    if (_isSyncingWeekPage) {
      return;
    }

    final targetWeek =
        _clampWeek(page + 1, provider.settings.semesterWeekCount);
    if (targetWeek == provider.currentWeek) {
      return;
    }

    _isSyncingWeekPage = true;
    try {
      _maybeSelectionClick(provider.settings);
      await provider.setCurrentWeek(targetWeek);
    } finally {
      _isSyncingWeekPage = false;
    }
  }

  void _syncWeekPageWithProvider(int week, int maxWeek) {
    if (_isSyncingWeekPage) {
      return;
    }

    final targetPage = _clampWeek(week, maxWeek) - 1;
    if (_pendingSyncedWeek == targetPage) {
      return;
    }
    _pendingSyncedWeek = targetPage;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingSyncedWeek = null;
      if (!mounted || !_weekPageController.hasClients) {
        return;
      }

      final currentPage =
          _weekPageController.page?.round() ?? _weekPageController.initialPage;
      if (currentPage == targetPage) {
        return;
      }

      _weekPageController.jumpToPage(targetPage);
    });
  }

  Future<void> _navigateToAddCourse(BuildContext context) async {
    await _showAddCourseSheet();
  }

  void _openAddCourseEditor({
    required CourseEditorMode mode,
    int? initialWeek,
    int? initialDayOfWeek,
    int? initialStartSection,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/course/create'),
        builder: (context) => AddCourseScreen(
          mode: mode,
          initialWeek: initialWeek,
          initialDayOfWeek: initialDayOfWeek,
          initialStartSection: initialStartSection,
        ),
      ),
    );
  }

  void _editCourse(Course course) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/course/edit'),
        builder: (context) => AddCourseScreen(
          course: course,
          mode: course.activeWeeks.length == 1
              ? CourseEditorMode.singleLesson
              : CourseEditorMode.recurring,
          initialWeek:
              course.activeWeeks.length == 1 ? course.activeWeeks.first : null,
        ),
      ),
    );
  }

  Future<void> _showAddCourseSheet() async {
    final provider = context.read<TimetableProvider>();
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '添加课程',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '空白课表区域不响应点击。请从这里明确选择是加一节临时课，还是加整学期重复课。',
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _HomeActionButton(
                      icon: Icons.looks_one_rounded,
                      title: '单节课',
                      onTap: () => Navigator.of(sheetContext).pop('single'),
                    ),
                    _HomeActionButton(
                      icon: Icons.view_week_rounded,
                      title: '多节课',
                      onTap: () => Navigator.of(sheetContext).pop('recurring'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }

    switch (selected) {
      case 'single':
        _openAddCourseEditor(
          mode: CourseEditorMode.singleLesson,
          initialWeek: provider.currentWeek,
        );
        break;
      case 'recurring':
        _openAddCourseEditor(
          mode: CourseEditorMode.recurring,
          initialWeek: provider.currentWeek,
        );
        break;
    }
  }

  Future<void> _showCourseActions(Course course, int week) async {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final courseColor = _colorFromHex(course.color, colorScheme.primary);
    final canReschedule = course.isInWeek(week);
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
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
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.menu_book_rounded,
                              color: courseColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  course.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (course.shortName?.trim().isNotEmpty == true)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      l10n.shortNamePrefix(
                                        course.shortName!.trim(),
                                      ),
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '${_weekdayLabel(context, course.dayOfWeek)} · 第${course.startSection}-${course.endSection}节 · ${course.startTime}-${course.endTime}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        course.weekDescription,
                        style: theme.textTheme.bodySmall,
                      ),
                      if (course.teacher.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          l10n.teacherPrefix(course.teacher.trim()),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                      if (course.location.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          l10n.locationPrefix(course.location.trim()),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        canReschedule
                            ? l10n.courseDialogCurrentWeekHint(week)
                            : l10n.courseDialogNotThisWeekHint(week),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _HomeActionButton(
                      icon: Icons.edit_rounded,
                      title: l10n.editActionShort,
                      onTap: () => Navigator.of(sheetContext).pop('edit'),
                    ),
                    _HomeActionButton(
                      icon: Icons.swap_horiz_rounded,
                      title: l10n.rescheduleAction,
                      enabled: canReschedule,
                      onTap: () => Navigator.of(sheetContext).pop('reschedule'),
                    ),
                    _HomeActionButton(
                      icon: Icons.delete_outline_rounded,
                      title: l10n.deleteActionShort,
                      accentColor: theme.colorScheme.error,
                      onTap: () => Navigator.of(sheetContext).pop('delete'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }

    switch (selected) {
      case 'edit':
        _editCourse(course);
        break;
      case 'reschedule':
        await _showRescheduleSheet(course, sourceWeek: week);
        break;
      case 'delete':
        await _showDeleteCourseOptions(course, week);
        break;
    }
  }

  Future<void> _showDeleteCourseOptions(Course course, int week) async {
    final l10n = AppLocalizations.of(context)!;
    final canDeleteOccurrence = course.isInWeek(week);
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.deleteModeTitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.deleteModeSubtitle,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _HomeActionButton(
                      icon: Icons.delete_sweep_rounded,
                      title: l10n.deleteCourseAction,
                      accentColor: theme.colorScheme.error,
                      onTap: () => Navigator.of(sheetContext).pop('course'),
                    ),
                    _HomeActionButton(
                      icon: Icons.remove_circle_outline_rounded,
                      title: l10n.deleteOccurrenceAction,
                      accentColor: theme.colorScheme.error,
                      enabled: canDeleteOccurrence,
                      onTap: () => Navigator.of(sheetContext).pop('occurrence'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  canDeleteOccurrence
                      ? l10n.deleteModeHintCurrentWeek(week)
                      : l10n.deleteModeHintUnavailable(week),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }

    switch (selected) {
      case 'course':
        await _confirmDeleteCourse(course);
        break;
      case 'occurrence':
        await _confirmDeleteOccurrence(course, week);
        break;
    }
  }

  Future<void> _confirmDeleteCourse(Course course) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(dialogContext)!.deleteScheduleTitle),
        content: Text(
          l10n.deleteScheduleConfirmMessage(
            course.name,
            '${course.weekDescription} · ${_weekdayLabel(context, course.dayOfWeek)} 第${course.startSection}-${course.endSection}节',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppLocalizations.of(dialogContext)!.cancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(AppLocalizations.of(dialogContext)!.deleteAction),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await context.read<TimetableProvider>().deleteCourse(course.id);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.deletedCourseMessage(course.name),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteOccurrence(Course course, int sourceWeek) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(dialogContext)!.deleteLessonTitle),
        content: Text(
          l10n.deleteOccurrenceConfirmMessage(
            course.name,
            sourceWeek,
            '${_weekdayLabel(context, course.dayOfWeek)} 第${course.startSection}-${course.endSection}节 · ${course.startTime}-${course.endTime}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppLocalizations.of(dialogContext)!.cancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(AppLocalizations.of(dialogContext)!.deleteAction),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      final changed =
          await context.read<TimetableProvider>().deleteCourseOccurrence(
                courseId: course.id,
                sourceWeek: sourceWeek,
              );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            changed
                ? l10n.occurrenceDeletedMessage(sourceWeek)
                : l10n.noChangesDetected,
          ),
        ),
      );
    } on ArgumentError catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message?.toString() ??
                AppLocalizations.of(context)!.deleteFailed,
          ),
        ),
      );
    }
  }

  Future<void> _showRescheduleSheet(
    Course course, {
    required int sourceWeek,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<TimetableProvider>();
    final settings = provider.settings;
    final weekdayLabels = _weekdayLabels(context);

    final draft = await showModalBottomSheet<_CourseRescheduleDraft>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _CourseRescheduleSheet(
        course: course,
        sourceWeek: sourceWeek,
        settings: settings,
        weekDays: weekdayLabels,
      ),
    );

    if (draft == null) {
      return;
    }

    try {
      final changed = await provider.rescheduleCourseOccurrence(
        courseId: course.id,
        sourceWeek: sourceWeek,
        targetWeek: draft.targetWeek,
        targetDayOfWeek: draft.targetDayOfWeek,
        targetStartSection: draft.targetStartSection,
        targetEndSection: draft.targetEndSection,
        targetLocation: draft.targetLocation,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            changed
                ? '已调到${l10n.weekLabel(draft.targetWeek)} ${_weekdayLabel(context, draft.targetDayOfWeek)} 第${draft.targetStartSection}-${draft.targetEndSection}节'
                : l10n.noChangesDetected,
          ),
        ),
      );
    } on ArgumentError catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message?.toString() ??
                AppLocalizations.of(context)!.rescheduleFailed,
          ),
        ),
      );
    }
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/settings'),
        builder: (context) => const TimetableSettingsScreen(),
      ),
    );
  }

  Widget _buildSectionTimeCell(
    int sectionNumber,
    SectionTime section,
    TimetableSettings settings,
  ) {
    final compactTextStyle = TextStyle(
      fontSize: (settings.compactFontSize - 2).clamp(6.0, 10.0),
      color: Colors.grey.shade600,
      height: 1.05,
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$sectionNumber',
          style: TextStyle(
            fontSize: settings.compactFontSize.clamp(8.0, 11.0),
            fontWeight: FontWeight.bold,
          ),
        ),
        if (settings.timetableSectionTimeDisplayMode !=
            SectionTimeDisplayMode.hidden)
          Text(section.startTime, style: compactTextStyle),
        if (settings.timetableSectionTimeDisplayMode ==
            SectionTimeDisplayMode.startAndEnd)
          Text(section.endTime, style: compactTextStyle),
      ],
    );
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

  void _maybeSelectionClick(TimetableSettings settings) {
    if (!settings.enableHaptics) {
      return;
    }
    HapticFeedback.selectionClick();
  }

  void _openProfiles() {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/profiles'),
        builder: (context) => const TimetableProfilesScreen(),
      ),
    );
  }

  Future<void> _showProfileQuickSwitchSheet() async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<TimetableProvider>();
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colorScheme = theme.colorScheme;
        final activeProfile = provider.activeProfile;
        final profiles = provider.profiles;

        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: colorScheme.primary.withValues(alpha: 0.12),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset(
                            'assets/branding/launcher_icon.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.view_week_rounded,
                                color: colorScheme.primary,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.switchTimetableTitle,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                activeProfile == null
                                    ? l10n.switchTimetableSubtitleEmpty
                                    : l10n.switchTimetableSubtitleCurrent(
                                        activeProfile.name,
                                      ),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var index = 0;
                            index < profiles.length;
                            index++) ...[
                          _ProfileQuickSwitchTile(
                            profile: profiles[index],
                            isActive:
                                profiles[index].id == provider.activeProfileId,
                            onTap: () => Navigator.of(sheetContext)
                                .pop(profiles[index].id),
                          ),
                          if (index != profiles.length - 1)
                            Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                              color: colorScheme.outlineVariant,
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.of(sheetContext).pop('profiles'),
                      icon: const Icon(Icons.view_week_rounded),
                      label: Text(AppLocalizations.of(sheetContext)!
                          .timetableManagement),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }
    if (selected == 'profiles') {
      _openProfiles();
      return;
    }
    if (selected == provider.activeProfileId) {
      return;
    }
    await provider.switchProfile(selected);
    if (!mounted) {
      return;
    }
    _maybeSelectionClick(provider.settings);
  }

  Future<void> _openUpdatePage() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/about/update'),
          builder: (context) => AboutUpdateScreen(packageInfo: packageInfo),
        ),
      );
    });
  }

  void _openSupportCreatorPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/support/creator'),
        builder: (context) => const SupportCreatorScreen(),
      ),
    );
  }

  Future<void> _showTopActionsSheet() async {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final actionTitles = [
      l10n.homeMenuUpdateTitle,
      l10n.homeMenuProfilesTitle,
      l10n.homeMenuOverviewTitle,
      l10n.homeMenuAddCourseTitle,
      l10n.homeMenuImportTitle,
      l10n.homeMenuSettingsTitle,
      l10n.homeMenuCoffeeTitle,
      l10n.homeMenuFeedbackTitle,
    ];
    final reserveTwoLineTitleSpace = actionTitles.any(
      (title) => _homeActionNeedsTwoLines(context, title),
    );
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _HomeActionButton(
                  icon: Icons.system_update_alt_rounded,
                  title: l10n.homeMenuUpdateTitle,
                  badgeText: _hasAvailableUpdate ? l10n.updateLabel : null,
                  accentColor: _hasAvailableUpdate ? colorScheme.primary : null,
                  reserveTwoLineTitleSpace: reserveTwoLineTitleSpace,
                  onTap: () => Navigator.of(sheetContext).pop('update'),
                ),
                _HomeActionButton(
                  icon: Icons.view_week_rounded,
                  title: l10n.homeMenuProfilesTitle,
                  reserveTwoLineTitleSpace: reserveTwoLineTitleSpace,
                  onTap: () => Navigator.of(sheetContext).pop('profiles'),
                ),
                _HomeActionButton(
                  icon: Icons.dashboard_customize_rounded,
                  title: l10n.homeMenuOverviewTitle,
                  reserveTwoLineTitleSpace: reserveTwoLineTitleSpace,
                  onTap: () => Navigator.of(sheetContext).pop('overview'),
                ),
                _HomeActionButton(
                  icon: Icons.add_circle_outline_rounded,
                  title: l10n.homeMenuAddCourseTitle,
                  reserveTwoLineTitleSpace: reserveTwoLineTitleSpace,
                  onTap: () => Navigator.of(sheetContext).pop('add'),
                ),
                _HomeActionButton(
                  icon: Icons.file_upload_outlined,
                  title: l10n.homeMenuImportTitle,
                  reserveTwoLineTitleSpace: reserveTwoLineTitleSpace,
                  onTap: () => Navigator.of(sheetContext).pop('import'),
                ),
                _HomeActionButton(
                  icon: Icons.tune_rounded,
                  title: l10n.homeMenuSettingsTitle,
                  reserveTwoLineTitleSpace: reserveTwoLineTitleSpace,
                  onTap: () => Navigator.of(sheetContext).pop('settings'),
                ),
                _HomeActionButton(
                  icon: Icons.favorite_border_rounded,
                  title: l10n.homeMenuCoffeeTitle,
                  accentColor: colorScheme.secondary,
                  reserveTwoLineTitleSpace: reserveTwoLineTitleSpace,
                  onTap: () => Navigator.of(sheetContext).pop('coffee'),
                ),
                _HomeActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: l10n.homeMenuFeedbackTitle,
                  reserveTwoLineTitleSpace: reserveTwoLineTitleSpace,
                  onTap: () => Navigator.of(sheetContext).pop('feedback'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }
    _handleTopMenuAction(selected);
  }

  void _handleTopMenuAction(String value) {
    switch (value) {
      case 'update':
        _openUpdatePage();
        break;
      case 'profiles':
        _openProfiles();
        break;
      case 'overview':
        Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: '/courses/overview'),
            builder: (context) => const CourseOverviewScreen(),
          ),
        );
        break;
      case 'import':
        _openCourseImportPage();
        break;
      case 'settings':
        _openSettings();
        break;
      case 'feedback':
        Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: '/feedback'),
            builder: (context) => const FeedbackScreen(),
          ),
        );
        break;
      case 'coffee':
        _openSupportCreatorPage();
        break;
      case 'add':
        _navigateToAddCourse(context);
        break;
    }
  }

  void _scheduleUpdateCheckIfNeeded(TimetableProvider provider) {
    if (!widget.enableUpdateCheck) {
      return;
    }
    final includePrerelease = provider.settings.appUpdateIncludePrerelease;
    if (_lastUpdateCheckIncludePrerelease == includePrerelease) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _checkForAppUpdate(includePrerelease: includePrerelease);
    });
  }

  Future<void> _checkForAppUpdate({
    required bool includePrerelease,
  }) async {
    if (_isCheckingForUpdate) {
      return;
    }
    _isCheckingForUpdate = true;
    _lastUpdateCheckIncludePrerelease = includePrerelease;
    if (!kReleaseMode) {
      if (!mounted) {
        _isCheckingForUpdate = false;
        return;
      }
      setState(() {
        _hasAvailableUpdate = true;
      });
      _isCheckingForUpdate = false;
      return;
    }

    try {
      final settings = context.read<TimetableProvider>().settings;
      final downloadSource = AppUpdateDownloadSourceX.fromValue(
        settings.appUpdateDownloadSource,
      );
      final mirrorPreset = AppUpdateMirrorPresetX.fromValue(
        settings.appUpdateMirrorPreset,
      );
      final effectiveMirrorUrlPrefix = resolveAppUpdateMirrorUrlPrefix(
        preset: mirrorPreset,
        customUrlPrefix: settings.appUpdateMirrorUrlPrefix,
      );
      final packageInfo = await PackageInfo.fromPlatform();
      final result = await _updateService.checkForUpdates(
        currentVersion: packageInfo.version,
        includePrerelease: includePrerelease,
        preferredSource: downloadSource,
        mirrorUrlPrefix: effectiveMirrorUrlPrefix,
      );
      if (!mounted) {
        _isCheckingForUpdate = false;
        return;
      }
      setState(() {
        _hasAvailableUpdate = result.hasUpdate;
      });
    } catch (_) {
      // Ignore update check failures on home screen; About page provides details.
    } finally {
      _isCheckingForUpdate = false;
    }
  }

  Future<void> _openCourseImportPage() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/courses/import'),
        builder: (context) => const CourseImportScreen(),
      ),
    );
  }

  bool _homeActionNeedsTwoLines(BuildContext context, String title) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w700,
      height: 1.25,
    );
    final width = ((MediaQuery.of(context).size.width - 32 - 36) / 4).clamp(
      72.0,
      112.0,
    );
    final textPainter = TextPainter(
      text: TextSpan(text: title, style: style),
      maxLines: 2,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: width - 16);
    return textPainter.computeLineMetrics().length > 1;
  }
}

class _HomeActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? badgeText;
  final Color? accentColor;
  final bool enabled;
  final bool reserveTwoLineTitleSpace;

  const _HomeActionButton({
    required this.icon,
    required this.title,
    required this.onTap,
    this.badgeText,
    this.accentColor,
    this.enabled = true,
    this.reserveTwoLineTitleSpace = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final highlightColor = enabled
        ? accentColor ?? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    final width = ((MediaQuery.of(context).size.width - 32 - 36) / 4).clamp(
      72.0,
      112.0,
    );
    return SizedBox(
      width: width,
      child: Material(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: highlightColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: highlightColor),
                    ),
                    if ((badgeText ?? '').isNotEmpty)
                      Positioned(
                        right: -8,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: highlightColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badgeText!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (reserveTwoLineTitleSpace)
                  SizedBox(
                    height: 34,
                    child: Center(
                      child: Text(
                        title,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: enabled ? null : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: enabled ? null : colorScheme.onSurfaceVariant,
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

class _ProfileQuickSwitchTile extends StatelessWidget {
  final TimetableProfile profile;
  final bool isActive;
  final VoidCallback onTap;

  const _ProfileQuickSwitchTile({
    required this.profile,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accentColor =
        isActive ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: isActive ? 0.14 : 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isActive ? Icons.check_circle_rounded : Icons.layers_rounded,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${profile.courses.length} 门课',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '当前',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseRescheduleDraft {
  final int targetWeek;
  final int targetDayOfWeek;
  final int targetStartSection;
  final int targetEndSection;
  final String targetLocation;

  const _CourseRescheduleDraft({
    required this.targetWeek,
    required this.targetDayOfWeek,
    required this.targetStartSection,
    required this.targetEndSection,
    required this.targetLocation,
  });
}

class _CourseRescheduleSheet extends StatefulWidget {
  final Course course;
  final int sourceWeek;
  final TimetableSettings settings;
  final List<String> weekDays;

  const _CourseRescheduleSheet({
    required this.course,
    required this.sourceWeek,
    required this.settings,
    required this.weekDays,
  });

  @override
  State<_CourseRescheduleSheet> createState() => _CourseRescheduleSheetState();
}

class _CourseRescheduleSheetState extends State<_CourseRescheduleSheet> {
  late int _targetWeek;
  late int _targetDayOfWeek;
  late int _targetStartSection;
  late int _targetEndSection;
  late final TextEditingController _locationController;

  @override
  void initState() {
    super.initState();
    _targetWeek = widget.sourceWeek;
    _targetDayOfWeek = widget.course.dayOfWeek;
    _targetStartSection = widget.course.startSection;
    _targetEndSection = widget.course.endSection;
    _locationController = TextEditingController(text: widget.course.location);
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sectionNumbers =
        List.generate(widget.settings.sectionCount, (index) => index + 1);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.rescheduleCurrentOccurrenceTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.rescheduleCurrentOccurrenceSubtitle(widget.sourceWeek),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _targetWeek,
              decoration: InputDecoration(
                labelText: l10n.rescheduleTargetWeekLabel,
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_month_rounded),
              ),
              items: widget.settings.availableWeeks
                  .map(
                    (week) => DropdownMenuItem(
                      value: week,
                      child:
                          Text(AppLocalizations.of(context)!.weekLabel(week)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _targetWeek = value;
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _targetDayOfWeek,
              decoration: InputDecoration(
                labelText: l10n.weekdayFieldLabel,
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.event_available_rounded),
              ),
              items: List.generate(
                widget.weekDays.length,
                (index) => DropdownMenuItem(
                  value: index + 1,
                  child: Text(widget.weekDays[index]),
                ),
              ),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _targetDayOfWeek = value;
                });
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _targetStartSection,
                    decoration: InputDecoration(
                      labelText: l10n.startSectionFieldLabel,
                      border: const OutlineInputBorder(),
                    ),
                    items: sectionNumbers
                        .map(
                          (section) => DropdownMenuItem(
                            value: section,
                            child: Text(AppLocalizations.of(context)!
                                .sectionLabel(section)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _targetStartSection = value;
                        if (_targetEndSection < _targetStartSection) {
                          _targetEndSection = _targetStartSection;
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _targetEndSection,
                    decoration: InputDecoration(
                      labelText: l10n.endSectionFieldLabel,
                      border: const OutlineInputBorder(),
                    ),
                    items: sectionNumbers
                        .where((section) => section >= _targetStartSection)
                        .map(
                          (section) => DropdownMenuItem(
                            value: section,
                            child: Text(AppLocalizations.of(context)!
                                .sectionLabel(section)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _targetEndSection = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: l10n.courseLocationFieldLabel,
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.cancelAction),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        _CourseRescheduleDraft(
                          targetWeek: _targetWeek,
                          targetDayOfWeek: _targetDayOfWeek,
                          targetStartSection: _targetStartSection,
                          targetEndSection: _targetEndSection,
                          targetLocation: _locationController.text,
                        ),
                      );
                    },
                    child: Text(l10n.confirmRescheduleAction),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
