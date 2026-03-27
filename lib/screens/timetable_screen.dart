import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../models/course.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../services/app_update_service.dart';
import '../widgets/course_card.dart';
import 'add_course_screen.dart';
import 'about_screen.dart';
import 'course_overview_screen.dart';
import 'feedback_screen.dart';
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
  static const double _headerControlWidth = _timeColumnWidth;
  static const double _timeColumnWidth = 40;
  static const int _minWeek = 1;
  static const Duration _weekSlideDuration = Duration(milliseconds: 280);

  final List<String> _weekDays = const [
    '周一',
    '周二',
    '周三',
    '周四',
    '周五',
    '周六',
    '周日'
  ];

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
            title: const Text('轻屿课表'),
            actions: [
              PopupMenuButton<String>(
                tooltip: '更多',
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
                onSelected: _handleTopMenuAction,
                itemBuilder: (context) {
                  final colorScheme = Theme.of(context).colorScheme;
                  return [
                    if (_hasAvailableUpdate)
                      PopupMenuItem(
                        value: 'update',
                        child: Row(
                          children: [
                            Icon(
                              Icons.system_update_rounded,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '软件有更新',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'profiles',
                      child: Text('课表管理'),
                    ),
                    const PopupMenuItem(
                      value: 'overview',
                      child: Text('课程总览'),
                    ),
                    const PopupMenuItem(
                      value: 'import',
                      child: Text('导入课程'),
                    ),
                    const PopupMenuItem(
                      value: 'settings',
                      child: Text('课表设置'),
                    ),
                    const PopupMenuItem(
                      value: 'feedback',
                      child: Text('问题反馈'),
                    ),
                    const PopupMenuItem(
                      value: 'add',
                      child: Text('添加课程'),
                    ),
                  ];
                },
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

  Widget _buildWeekDayHeader(
    TimetableProvider provider,
    int week,
    TimetableSettings settings,
  ) {
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
            width: _headerControlWidth,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: _showWeekSelector,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    child: Text(
                      '$week周',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                if (canReturnToCurrentWeek) ...[
                  const SizedBox(height: 2),
                  InkWell(
                    onTap: () => _jumpToCurrentWeek(provider),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      child: Text(
                        '回本周',
                        style: TextStyle(
                          fontSize: 8,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
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
                      _weekDays[dayOfWeek - 1],
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
    final dayWidth = (availableWidth - _timeColumnWidth) / visibleDays.length;
    final conflictMap = provider.courseConflictMapForWeek(week);

    return SizedBox(
      key: ValueKey<int>(week),
      width: availableWidth,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _timeColumnWidth,
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
        _buildWeekDayHeader(provider, week, settings),
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
          child: GestureDetector(
            onTap: () => _addCourseAt(dayOfWeek, section),
            child: const SizedBox.expand(),
          ),
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
            left: 2,
            right: 2,
            height: course.sectionCount * sectionHeight - 4,
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
                onTap: () => _editCourse(course),
                compactTitleFontSize: settings.compactFontSize,
                compactSubtitleFontSize:
                    (settings.compactFontSize - 1).clamp(7.0, 14.0),
                compactVerticalPadding: sectionHeight < 64 ? 4 : 6,
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
                        FilledButton.tonalIcon(
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
                            side: BorderSide(
                              color:
                                  colorScheme.primary.withValues(alpha: 0.18),
                            ),
                          ),
                          onPressed: () => Navigator.of(sheetContext)
                              .pop(currentSemesterWeek),
                          icon: const Icon(Icons.my_location_rounded, size: 18),
                          label: const Text('回本周'),
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
    );
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
        const SnackBar(content: Text('请先在课表设置里填写开学日期')),
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

  void _navigateToAddCourse(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/course/create'),
        builder: (context) => const AddCourseScreen(),
      ),
    );
  }

  void _addCourseAt(int dayOfWeek, int section) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/course/create'),
        builder: (context) => AddCourseScreen(
          initialDayOfWeek: dayOfWeek,
          initialStartSection: section,
        ),
      ),
    );
  }

  void _editCourse(Course course) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/course/edit'),
        builder: (context) => AddCourseScreen(course: course),
      ),
    );
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
        _importCalendarFile();
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
      final packageInfo = await PackageInfo.fromPlatform();
      final result = await _updateService.checkForUpdates(
        currentVersion: packageInfo.version,
        includePrerelease: includePrerelease,
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

  Future<void> _importCalendarFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['ics'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法读取所选文件')),
      );
      return;
    }

    if (!mounted) return;
    final replaceExisting = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('导入课程'),
          content: Text('导入 ${file.name} 时，是否替换现有课程？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('追加导入'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('替换现有'),
            ),
          ],
        );
      },
    );

    if (replaceExisting == null || !mounted) {
      return;
    }

    final content = utf8.decode(bytes, allowMalformed: true);
    final provider = context.read<TimetableProvider>();
    final requiredSectionCount =
        provider.previewWakeUpImportRequiredSectionCount(
      content,
      replaceExisting: replaceExisting,
    );
    var sectionCapacityExpanded = false;
    if (requiredSectionCount > provider.settings.sectionCount) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('时间模板节次不足'),
            content: Text(
              '当前课表时间模板只有 ${provider.settings.sectionCount} 节，但导入课表需要到第 $requiredSectionCount 节。是否自动补齐后继续导入？',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('自动补齐并导入'),
              ),
            ],
          );
        },
      );

      if (shouldContinue != true || !mounted) {
        return;
      }

      final ensureMessage =
          await provider.ensureSectionCapacityForImport(requiredSectionCount);
      if (ensureMessage != null) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ensureMessage)),
        );
        return;
      }
      sectionCapacityExpanded = true;
    }

    final importedCount = await provider.importWakeUpCalendar(
      content,
      replaceExisting: replaceExisting,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          importedCount > 0
              ? sectionCapacityExpanded
                  ? '已自动补齐到第 $requiredSectionCount 节，并导入 $importedCount 条课程'
                  : '已导入 $importedCount 条课程'
              : '未识别到可导入课程',
        ),
      ),
    );
  }
}
