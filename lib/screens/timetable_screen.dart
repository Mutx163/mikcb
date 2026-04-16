import 'dart:async';
import 'dart:math' as math;

import 'package:animations/animations.dart';
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
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const int _minWeek = 1;
  static const Duration _weekSlideDuration = Duration(milliseconds: 280);
  static const Duration _dayExpandDuration = Duration(milliseconds: 360);

  late final PageController _weekPageController;
  late final AnimationController _dayViewExpandController;
  final Map<int, PageController> _dayViewPageControllers = {};
  bool _isSyncingWeekPage = false;
  bool _isSyncingDayViewPage = false;
  int? _pendingSyncedWeek;
  final GlobalKey _timetableSurfaceKey = GlobalKey();
  final AppUpdateService _updateService = AppUpdateService();
  bool _hasAvailableUpdate = false;
  bool? _lastUpdateCheckIncludePrerelease;
  bool _isCheckingForUpdate = false;
  String? _lastSyncedProfileId;
  int? _selectedDayOfWeek;
  int? _selectedWeekForDayView;
  int? _dayViewTransitionSourceWeek;
  int? _dayViewTransitionSourceDayOfWeek;
  double _dayViewAnchorFraction = 0.5;
  bool _isDaySwipeAnimating = false;

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
    _dayViewExpandController = AnimationController(
      vsync: this,
      duration: _dayExpandDuration,
    );
    _restoreViewStateFromProvider(provider);
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
    _dayViewExpandController.dispose();
    for (final controller in _dayViewPageControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final provider = context.read<TimetableProvider>();
      unawaited(provider.syncTemporalContext());
      if (widget.enableUpdateCheck) {
        _checkForAppUpdate(
          includePrerelease: provider.settings.appUpdateIncludePrerelease,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        _syncViewStateIfNeeded(provider);
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
                      key: _timetableSurfaceKey,
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

  bool get _isDayView =>
      _selectedDayOfWeek != null && _selectedWeekForDayView != null;

  int _resolveStoredDayOfWeek(TimetableSettings settings, int storedDayOfWeek) {
    final visibleDays = _visibleDayNumbers(settings);
    if (visibleDays.contains(storedDayOfWeek)) {
      return storedDayOfWeek;
    }
    return visibleDays.first;
  }

  void _restoreViewStateFromProvider(TimetableProvider provider) {
    final settings = provider.settings;
    final restoredDayOfWeek = _resolveStoredDayOfWeek(
      settings,
      settings.timetableLastViewedDayOfWeek,
    );
    _lastSyncedProfileId = provider.activeProfileId;
    _dayViewTransitionSourceWeek = null;
    _dayViewTransitionSourceDayOfWeek = null;
    _isSyncingDayViewPage = false;
    _isDaySwipeAnimating = false;
    for (final controller in _dayViewPageControllers.values) {
      controller.dispose();
    }
    _dayViewPageControllers.clear();
    if (settings.timetableHomeViewMode == TimetableHomeViewMode.day) {
      _selectedWeekForDayView = provider.currentWeek;
      _selectedDayOfWeek = restoredDayOfWeek;
      _dayViewExpandController.value = 1;
    } else {
      _selectedWeekForDayView = null;
      _selectedDayOfWeek = null;
      _dayViewExpandController.value = 0;
    }
  }

  void _syncViewStateIfNeeded(TimetableProvider provider) {
    if (_lastSyncedProfileId == provider.activeProfileId) {
      return;
    }
    _restoreViewStateFromProvider(provider);
  }

  void _persistViewState(
    TimetableProvider provider, {
    required TimetableHomeViewMode mode,
    int? dayOfWeek,
  }) {
    final resolvedDayOfWeek = _resolveStoredDayOfWeek(
      provider.settings,
      dayOfWeek ??
          _selectedDayOfWeek ??
          provider.settings.timetableLastViewedDayOfWeek,
    );
    if (provider.settings.timetableHomeViewMode == mode &&
        provider.settings.timetableLastViewedDayOfWeek == resolvedDayOfWeek) {
      return;
    }
    unawaited(
      provider.updateTimetableSettings(
        provider.settings.copyWith(
          timetableHomeViewMode: mode,
          timetableLastViewedDayOfWeek: resolvedDayOfWeek,
        ),
      ),
    );
  }

  bool _isSelectedDay(int week, int dayOfWeek) {
    return _isDayView &&
        _selectedWeekForDayView == week &&
        _selectedDayOfWeek == dayOfWeek;
  }

  double get _dayViewAnchorAlignmentX =>
      (_dayViewAnchorFraction * 2).clamp(0.0, 2.0) - 1;

  void _captureDayViewAnchor(Offset globalPosition) {
    final surfaceContext = _timetableSurfaceKey.currentContext;
    final surfaceBox = surfaceContext?.findRenderObject() as RenderBox?;
    if (surfaceBox == null ||
        !surfaceBox.hasSize ||
        surfaceBox.size.width <= 0) {
      return;
    }
    final localDx = surfaceBox.globalToLocal(globalPosition).dx;
    setState(() {
      _dayViewAnchorFraction =
          (localDx / surfaceBox.size.width).clamp(0.1, 0.9);
    });
  }

  Future<void> _toggleDayView({
    required int week,
    required int dayOfWeek,
    required TimetableSettings settings,
  }) async {
    final normalizedWeek = _clampWeek(week, settings.semesterWeekCount);
    final isSameSelection = _isDayView &&
        _selectedWeekForDayView == normalizedWeek &&
        _selectedDayOfWeek == dayOfWeek;
    if (isSameSelection) {
      await _closeDayView(settings);
      return;
    }
    if (_isDayView && _selectedWeekForDayView == normalizedWeek) {
      await _switchDayWithinWeek(settings, normalizedWeek, dayOfWeek);
      return;
    }
    final shouldAnimateOpen = !_isDayView;
    setState(() {
      _selectedWeekForDayView = normalizedWeek;
      _selectedDayOfWeek = dayOfWeek;
    });
    _persistViewState(
      context.read<TimetableProvider>(),
      mode: TimetableHomeViewMode.day,
      dayOfWeek: dayOfWeek,
    );
    _maybeSelectionClick(settings);
    if (shouldAnimateOpen) {
      await _dayViewExpandController.forward(from: 0);
    }
  }

  Future<void> _closeDayView(TimetableSettings settings) async {
    if (!_isDayView) {
      return;
    }
    _maybeSelectionClick(settings);
    if (_dayViewExpandController.value > 0) {
      await _dayViewExpandController.reverse();
      if (!mounted) {
        return;
      }
    }
    setState(() {
      _selectedWeekForDayView = null;
      _selectedDayOfWeek = null;
      _dayViewTransitionSourceWeek = null;
      _dayViewTransitionSourceDayOfWeek = null;
    });
    _persistViewState(
      context.read<TimetableProvider>(),
      mode: TimetableHomeViewMode.week,
    );
  }

  int _dayViewPageIndexForDay(
    TimetableSettings settings,
    int week,
    int dayOfWeek,
  ) {
    final visibleDays = _visibleDayNumbers(settings);
    final dayIndex = math.max(0, visibleDays.indexOf(dayOfWeek));
    final hasPreviousWeek = week > _minWeek;
    return dayIndex + (hasPreviousWeek ? 1 : 0);
  }

  int _dayViewPageCount(TimetableSettings settings, int week) {
    final visibleDays = _visibleDayNumbers(settings).length;
    final hasPreviousWeek = week > _minWeek;
    final hasNextWeek = week < settings.semesterWeekCount;
    return visibleDays + (hasPreviousWeek ? 1 : 0) + (hasNextWeek ? 1 : 0);
  }

  _DayViewPageTarget _dayViewTargetForPage(
    TimetableSettings settings,
    int week,
    int page,
  ) {
    final visibleDays = _visibleDayNumbers(settings);
    final hasPreviousWeek = week > _minWeek;
    final hasNextWeek = week < settings.semesterWeekCount;

    if (hasPreviousWeek && page == 0) {
      return _DayViewPageTarget(
        week: week - 1,
        dayOfWeek: visibleDays.last,
        isBoundaryTransition: true,
      );
    }

    final dayIndex = page - (hasPreviousWeek ? 1 : 0);
    if (dayIndex >= 0 && dayIndex < visibleDays.length) {
      return _DayViewPageTarget(
        week: week,
        dayOfWeek: visibleDays[dayIndex],
      );
    }

    if (hasNextWeek && page == _dayViewPageCount(settings, week) - 1) {
      return _DayViewPageTarget(
        week: week + 1,
        dayOfWeek: visibleDays.first,
        isBoundaryTransition: true,
      );
    }

    return _DayViewPageTarget(
      week: week,
      dayOfWeek: visibleDays.first,
    );
  }

  PageController _ensureDayViewPageController(
    TimetableSettings settings,
    int week,
  ) {
    return _dayViewPageControllers.putIfAbsent(
      week,
      () => PageController(
        initialPage: _dayViewPageIndexForDay(
          settings,
          week,
          _displayedDayForWeek(week),
        ),
      ),
    );
  }

  void _prepareDayViewPageController(
    TimetableSettings settings,
    int week,
    int dayOfWeek,
  ) {
    final targetPage = _dayViewPageIndexForDay(settings, week, dayOfWeek);
    final existing = _dayViewPageControllers[week];
    if (existing == null) {
      _dayViewPageControllers[week] = PageController(initialPage: targetPage);
      return;
    }

    if (existing.hasClients) {
      final currentPage = existing.page?.round() ?? existing.initialPage;
      if (currentPage != targetPage) {
        existing.jumpToPage(targetPage);
      }
      return;
    }

    existing.dispose();
    _dayViewPageControllers[week] = PageController(initialPage: targetPage);
  }

  int _displayedDayForWeek(int week) {
    if (_dayViewTransitionSourceWeek == week &&
        _dayViewTransitionSourceDayOfWeek != null) {
      return _dayViewTransitionSourceDayOfWeek!;
    }
    return _selectedDayOfWeek ?? 1;
  }

  void _syncDayViewPageWithSelection(TimetableSettings settings, int week) {
    if (_isSyncingDayViewPage) {
      return;
    }
    if (_dayViewTransitionSourceWeek == week) {
      return;
    }
    final controller = _dayViewPageControllers[week];
    if (controller == null || !controller.hasClients) {
      return;
    }
    final targetPage = _dayViewPageIndexForDay(
      settings,
      week,
      _displayedDayForWeek(week),
    );
    final currentPage = controller.page?.round() ?? controller.initialPage;
    if (currentPage == targetPage) {
      return;
    }
    controller.jumpToPage(targetPage);
  }

  Future<void> _switchDayWithinWeek(
    TimetableSettings settings,
    int week,
    int dayOfWeek, {
    bool animate = true,
  }) async {
    final controller = _ensureDayViewPageController(settings, week);
    setState(() {
      _selectedWeekForDayView = week;
      _selectedDayOfWeek = dayOfWeek;
    });
    _persistViewState(
      context.read<TimetableProvider>(),
      mode: TimetableHomeViewMode.day,
      dayOfWeek: dayOfWeek,
    );
    _maybeSelectionClick(settings);
    if (!controller.hasClients) {
      return;
    }
    final targetPage = _dayViewPageIndexForDay(settings, week, dayOfWeek);
    final currentPage = controller.page?.round() ?? controller.initialPage;
    if (currentPage == targetPage) {
      return;
    }
    _isSyncingDayViewPage = true;
    try {
      if (animate) {
        await controller.animateToPage(
          targetPage,
          duration: _weekSlideDuration,
          curve: Curves.easeOutCubic,
        );
      } else {
        controller.jumpToPage(targetPage);
      }
    } finally {
      _isSyncingDayViewPage = false;
    }
  }

  Future<void> _animateDayViewToWeek(
    TimetableProvider provider,
    TimetableSettings settings,
    int targetWeek,
    int targetDayOfWeek,
  ) async {
    if (_selectedWeekForDayView == null || _selectedDayOfWeek == null) {
      return;
    }
    final normalizedTargetWeek =
        _clampWeek(targetWeek, provider.settings.semesterWeekCount);
    if (normalizedTargetWeek == _selectedWeekForDayView &&
        targetDayOfWeek == _selectedDayOfWeek) {
      return;
    }

    _isDaySwipeAnimating = true;
    try {
      _prepareDayViewPageController(
        settings,
        normalizedTargetWeek,
        targetDayOfWeek,
      );
      setState(() {
        _dayViewTransitionSourceWeek = _selectedWeekForDayView;
        _dayViewTransitionSourceDayOfWeek = _selectedDayOfWeek;
        _selectedWeekForDayView = normalizedTargetWeek;
        _selectedDayOfWeek = targetDayOfWeek;
      });
      _persistViewState(
        provider,
        mode: TimetableHomeViewMode.day,
        dayOfWeek: targetDayOfWeek,
      );
      if (normalizedTargetWeek == provider.currentWeek) {
        await _switchDayWithinWeek(
          settings,
          normalizedTargetWeek,
          targetDayOfWeek,
          animate: false,
        );
      } else {
        await _jumpToWeek(provider, normalizedTargetWeek);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _dayViewTransitionSourceWeek = null;
        _dayViewTransitionSourceDayOfWeek = null;
      });
    } finally {
      _isDaySwipeAnimating = false;
    }
  }

  Future<void> _handleDayViewPageChanged(
    TimetableProvider provider,
    TimetableSettings settings,
    int week,
    int page,
  ) async {
    if (_isSyncingDayViewPage || _isDaySwipeAnimating) {
      return;
    }
    final target = _dayViewTargetForPage(settings, week, page);
    if (target.isBoundaryTransition) {
      await _animateDayViewToWeek(
        provider,
        settings,
        target.week,
        target.dayOfWeek,
      );
      return;
    }
    if (_selectedWeekForDayView == target.week &&
        _selectedDayOfWeek == target.dayOfWeek) {
      return;
    }
    setState(() {
      _selectedWeekForDayView = target.week;
      _selectedDayOfWeek = target.dayOfWeek;
    });
    _persistViewState(
      provider,
      mode: TimetableHomeViewMode.day,
      dayOfWeek: target.dayOfWeek,
    );
    _maybeSelectionClick(settings);
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
                        key: const ValueKey('back-to-current-week-button'),
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
            final isSelected = _isSelectedDay(week, dayOfWeek);
            final labelColor = (isSelected || isToday)
                ? colorScheme.primary
                : colorScheme.onSurface;
            final subLabelColor = (isSelected || isToday)
                ? colorScheme.primary.withValues(
                    alpha: isSelected ? 0.9 : 0.78,
                  )
                : colorScheme.onSurfaceVariant;

            return Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: ValueKey('weekday-header-$week-$dayOfWeek'),
                  borderRadius: BorderRadius.circular(14),
                  onTapDown: (details) =>
                      _captureDayViewAnchor(details.globalPosition),
                  onTap: () => _toggleDayView(
                    week: week,
                    dayOfWeek: dayOfWeek,
                    settings: settings,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: (isSelected || isToday)
                              ? colorScheme.primary
                              : Colors.transparent,
                          width: isSelected ? 3 : 2,
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
                            fontWeight: isSelected || isToday
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
                          style: TextStyle(
                            fontSize: 8.5,
                            color: subLabelColor,
                          ),
                        ),
                      ],
                    ),
                  ),
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
              final displayItems = _buildDayCourseDisplayItems(
                courses: dayCourses,
                week: week,
                settings: settings,
                conflictMap: conflictMap,
              );
              return SizedBox(
                width: dayWidth,
                child: _buildDayColumn(
                  week,
                  dayOfWeek,
                  displayItems,
                  settings,
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
      physics: _isDayView
          ? const NeverScrollableScrollPhysics()
          : const PageScrollPhysics(parent: ClampingScrollPhysics()),
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
    return KeyedSubtree(
      key: ValueKey('week-page-$week'),
      child: Column(
        children: [
          _buildWeekDayHeader(
            provider,
            week,
            settings,
            _resolveTimeColumnWidth(settings),
          ),
          Expanded(
            child: _buildWeekPageBody(
              provider: provider,
              settings: settings,
              week: week,
              grid: grid,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekPageBody({
    required TimetableProvider provider,
    required TimetableSettings settings,
    required int week,
    required Widget grid,
  }) {
    final weekGrid = settings.timetableAutoFitSectionHeight
        ? grid
        : SingleChildScrollView(
            key: PageStorageKey<String>('week-scroll-$week'),
            child: grid,
          );
    final shouldShowDayView = _selectedDayOfWeek != null &&
        (_isDayView || _dayViewExpandController.isAnimating) &&
        (week == _selectedWeekForDayView ||
            week == _dayViewTransitionSourceWeek);

    if (!shouldShowDayView) {
      return weekGrid;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          ignoring: _isDayView,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            opacity: _isDayView ? 0.18 : 1,
            child: weekGrid,
          ),
        ),
        _buildAnchoredDayViewOverlay(
          provider: provider,
          settings: settings,
          week: week,
        ),
      ],
    );
  }

  Widget _buildAnchoredDayViewOverlay({
    required TimetableProvider provider,
    required TimetableSettings settings,
    required int week,
  }) {
    final selectedDayOfWeek = _displayedDayForWeek(week);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: _dayViewExpandController,
      builder: (context, child) {
        final progress = Curves.easeInOutCubicEmphasized.transform(
          _dayViewExpandController.value,
        );

        // When fully expanded, show the day view directly without constraints
        if (progress > 0.95) {
          return _buildDayViewPanel(
            provider: provider,
            settings: settings,
            week: week,
            dayOfWeek: selectedDayOfWeek,
          );
        }

        final widthFactor = 0.18 + (0.82 * progress);
        final heightFactor = math.max(0.04, progress);
        final translateY = (1 - progress) * -24;

        // When not fully expanded, show the animated floating card
        return IgnorePointer(
          ignoring: progress < 0.98,
          child: Opacity(
            opacity: Curves.easeOutCubic.transform(progress),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Align(
                alignment: Alignment(_dayViewAnchorAlignmentX, -1),
                widthFactor: widthFactor,
                heightFactor: heightFactor,
                child: Transform.translate(
                  offset: Offset(0, translateY),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      border: Border.all(color: colorScheme.outlineVariant),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow
                              .withValues(alpha: 0.08 * (1 - progress)),
                          blurRadius: 28 * (1 - progress),
                          offset: Offset(0, 12 * (1 - progress)),
                        ),
                      ],
                    ),
                    child: _buildDayViewPanel(
                      provider: provider,
                      settings: settings,
                      week: week,
                      dayOfWeek: selectedDayOfWeek,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDayViewPanel({
    required TimetableProvider provider,
    required TimetableSettings settings,
    required int week,
    required int dayOfWeek,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = Theme.of(context).brightness == Brightness.dark
        ? colorScheme.surface
        : _colorFromHex(
            provider.settings.timetablePageBackgroundColor,
            colorScheme.surface,
          );
    final controller = _ensureDayViewPageController(settings, week);
    _syncDayViewPageWithSelection(settings, week);
    final pageCount = _dayViewPageCount(settings, week);

    return Container(
      key: ValueKey('timetable-day-view-panel-$week'),
      color: backgroundColor,
      child: Column(
        children: [
          const SizedBox(height: 14),
          SizedBox(
            key: ValueKey('timetable-day-view-$week-$dayOfWeek'),
          ),
          Expanded(
            child: IgnorePointer(
              ignoring: _isDaySwipeAnimating,
              child: PageView.builder(
                key: const ValueKey('day-view-swipe-area'),
                controller: controller,
                physics:
                    const PageScrollPhysics(parent: ClampingScrollPhysics()),
                itemCount: pageCount,
                onPageChanged: (page) =>
                    _handleDayViewPageChanged(provider, settings, week, page),
                itemBuilder: (context, page) {
                  final target = _dayViewTargetForPage(settings, week, page);
                  final selectedDate =
                      _dateForWeekDay(settings, target.week, target.dayOfWeek);
                  final conflictMap =
                      provider.courseConflictMapForWeek(target.week);
                  final courses = _getCoursesForDay(
                    provider.courses,
                    target.week,
                    target.dayOfWeek,
                    settings,
                  );
                  final currentCourse = _isSelectedDayToday(
                    provider: provider,
                    settings: settings,
                    week: target.week,
                    dayOfWeek: target.dayOfWeek,
                  )
                      ? provider.getCourseInProgress(
                          dayOfWeek: target.dayOfWeek,
                          week: target.week,
                        )
                      : null;
                  final displayItems = _buildDayCourseDisplayItems(
                    courses: courses,
                    week: target.week,
                    settings: settings,
                    conflictMap: conflictMap,
                    currentCourseId: currentCourse?.id,
                  );
                  final isActivePage = target.week == _selectedWeekForDayView &&
                      target.dayOfWeek == _selectedDayOfWeek;
                  return Column(
                    key: ValueKey(
                        'day-content-${target.week}-${target.dayOfWeek}'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: _buildDayViewSummary(
                          key: isActivePage
                              ? const ValueKey('day-view-summary')
                              : null,
                          provider: provider,
                          settings: settings,
                          week: target.week,
                          dayOfWeek: target.dayOfWeek,
                          selectedDate: selectedDate,
                          currentCourse: currentCourse,
                          courseCount: displayItems.length,
                          hasCourses: displayItems.isNotEmpty,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _buildExpandedDayColumnView(
                          key: ValueKey(
                            'day-column-${target.week}-${target.dayOfWeek}',
                          ),
                          provider: provider,
                          settings: settings,
                          week: target.week,
                          dayOfWeek: target.dayOfWeek,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSelectedDayToday({
    required TimetableProvider provider,
    required TimetableSettings settings,
    required int week,
    required int dayOfWeek,
  }) {
    final resolvedDate = _dateForWeekDay(settings, week, dayOfWeek);
    if (resolvedDate != null) {
      return _isSameDate(resolvedDate, DateTime.now());
    }
    final now = DateTime.now();
    return dayOfWeek == now.weekday && week == provider.currentWeek;
  }

  Widget _buildDayViewSummary({
    Key? key,
    required TimetableProvider provider,
    required TimetableSettings settings,
    required int week,
    required int dayOfWeek,
    required DateTime? selectedDate,
    required Course? currentCourse,
    required int courseCount,
    required bool hasCourses,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isToday = _isSelectedDayToday(
      provider: provider,
      settings: settings,
      week: week,
      dayOfWeek: dayOfWeek,
    );
    final summaryText = currentCourse != null
        ? '${l10n.ongoingCourseBadge} · ${currentCourse.name}'
        : hasCourses
            ? l10n.courseCountSummary(courseCount)
            : l10n.dayViewEmptyTitle;

    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              summaryText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: currentCourse != null
                    ? colorScheme.primary
                    : colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (!isToday)
            FilledButton.tonalIcon(
              key: const ValueKey('back-to-today-button'),
              onPressed: () async {
                final now = DateTime.now();
                final visibleDays = _visibleDayNumbers(settings);
                final currentSemesterWeek =
                    _resolveCurrentSemesterWeek(settings);
                if (!visibleDays.contains(now.weekday) ||
                    currentSemesterWeek == null) {
                  return;
                }
                await _animateDayViewToWeek(
                  provider,
                  settings,
                  currentSemesterWeek,
                  now.weekday,
                );
              },
              icon: const Icon(Icons.today_rounded, size: 18),
              label: Text(l10n.backToTodayAction),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: const Size(0, 32),
              ),
            ),
          const SizedBox(width: 6),
          IconButton(
            key: const ValueKey('back-to-week-view-button'),
            onPressed: () => _closeDayView(settings),
            icon: const Icon(Icons.close_rounded, size: 20),
            tooltip: l10n.backToWeekViewAction,
            style: IconButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(8),
              minimumSize: const Size(32, 32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayViewEmptyState({required int week}) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_busy_rounded,
            size: 32,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.dayViewEmptyTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.weekLabel(week),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedDayColumnView({
    required Key key,
    required TimetableProvider provider,
    required TimetableSettings settings,
    required int week,
    required int dayOfWeek,
  }) {
    final courses = _getCoursesForDay(
      provider.courses,
      week,
      dayOfWeek,
      settings,
    );
    final currentCourse = _isSelectedDayToday(
      provider: provider,
      settings: settings,
      week: week,
      dayOfWeek: dayOfWeek,
    )
        ? provider.getCourseInProgress(
            dayOfWeek: dayOfWeek,
            week: week,
          )
        : null;
    final displayItems = _buildDayCourseDisplayItems(
      courses: courses,
      week: week,
      settings: settings,
      conflictMap: provider.courseConflictMapForWeek(week),
      currentCourseId: currentCourse?.id,
    );
    if (displayItems.isEmpty) {
      return Padding(
        key: key,
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        child: _buildDayViewEmptyColumn(
          week: week,
          settings: settings,
        ),
      );
    }
    return ListView.separated(
      key: PageStorageKey<String>('day-agenda-$week-$dayOfWeek'),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      itemCount: displayItems.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, itemIndex) {
        final item = displayItems[itemIndex];
        return _buildDayAgendaEntry(
          week: week,
          settings: settings,
          item: item,
        );
      },
    );
  }

  Widget _buildDayViewEmptyColumn({
    required int week,
    required TimetableSettings settings,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: _buildDayViewEmptyState(week: week),
    );
  }

  Widget _buildDayAgendaEntry({
    required int week,
    required TimetableSettings settings,
    required _DayCourseDisplayItem item,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final colorHex = _resolveDisplayCourseColor(item, settings: settings);
    return SizedBox(
      height: 110,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
              child: SizedBox(
                width: 62,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.course.startTime,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.course.endTime,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppLocalizations.of(context)!.sectionRangeLabel(
                        item.course.startSection,
                        item.course.endSection,
                      ),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                child: OpenContainer<void>(
                  key: ValueKey('day-view-edit-card-${item.course.id}'),
                  tappable: false,
                  transitionType: ContainerTransitionType.fadeThrough,
                  transitionDuration: const Duration(milliseconds: 420),
                  openColor: theme.scaffoldBackgroundColor,
                  closedColor: Colors.transparent,
                  closedElevation: 0,
                  openElevation: 0,
                  closedShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  openShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  openBuilder: (context, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: AddCourseScreen(course: item.course),
                  ),
                  closedBuilder: (context, openContainer) {
                    return Opacity(
                      opacity: item.opacity,
                      child: CourseCard(
                        course: item.course,
                        overrideColorHex: colorHex,
                        compactOverlineText: _resolveCompactOverlineText(
                          item,
                          settings.showConflictBadgeOnTimetable,
                        ),
                        topRightBadgeText: _resolveCompactBadgeText(
                          item,
                          settings.showConflictBadgeOnTimetable,
                        ),
                        isHighlighted: item.isCurrentCourse,
                        isCompact: true,
                        showName: settings.courseCardShowName,
                        showTeacher: settings.courseCardShowTeacher,
                        showLocation: settings.courseCardShowLocation,
                        showTime: false,
                        showTimeLabels: settings.courseCardShowTimeLabels,
                        showWeeks: settings.courseCardShowWeeks,
                        showDescription: settings.courseCardShowDescription,
                        verticalAlign: settings.courseCardVerticalAlign,
                        horizontalAlign: CourseCardHorizontalAlign.left,
                        onTap: openContainer,
                        compactTitleFontSize:
                            (settings.courseCardFontSize + 1).clamp(9.0, 16.0),
                        compactSubtitleFontSize:
                            settings.courseCardFontSize.clamp(8.0, 14.0),
                        compactVerticalPadding: 10,
                        compactOuterInset: 0,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayColumn(
    int week,
    int dayOfWeek,
    List<_DayCourseDisplayItem> displayItems,
    TimetableSettings settings,
    bool showConflictBadge,
    double sectionHeight,
    double cardInset,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final columnBackground = colorScheme.surfaceContainerLowest.withValues(
      alpha: 0.45,
    );
    final courseCards = <Widget>[];
    final gridLines = <Widget>[];

    for (var sectionIndex = 0;
        sectionIndex < settings.sectionCount;
        sectionIndex++) {
      final section = sectionIndex + 1;
      final startingCourses =
          _getDisplayItemsStartingAtSection(displayItems, section);

      gridLines.add(
        Positioned(
          top: sectionIndex * sectionHeight,
          left: 0,
          right: 0,
          height: sectionHeight,
          child: const SizedBox.expand(),
        ),
      );

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
                overrideColorHex:
                    _resolveDisplayCourseColor(item, settings: settings),
                compactOverlineText:
                    _resolveCompactOverlineText(item, showConflictBadge),
                topRightBadgeText:
                    _resolveCompactBadgeText(item, showConflictBadge),
                isHighlighted: item.isCurrentCourse,
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
                onTap: () => _showCourseActions(item.course, week),
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
    final l10n = AppLocalizations.of(context)!;
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
                      Expanded(
                        child: Text(
                          l10n.selectWeekTitle,
                          style: const TextStyle(
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.my_location_rounded, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                l10n.backToCurrentWeekAction,
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
                    l10n.availableWeeksCount(availableWeeks.length),
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
                              l10n.goToWeekLabel(week),
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

  List<_DayCourseDisplayItem> _getDisplayItemsStartingAtSection(
    List<_DayCourseDisplayItem> items,
    int section,
  ) {
    return items.where((item) => item.course.startSection == section).toList();
  }

  List<_DayCourseDisplayItem> _buildDayCourseDisplayItems({
    required List<Course> courses,
    required int week,
    required TimetableSettings settings,
    required Map<String, List<Course>> conflictMap,
    String? currentCourseId,
  }) {
    return courses.where((course) {
      final isCurrentWeekCourse = course.isInWeek(week);
      if (isCurrentWeekCourse) {
        return true;
      }
      if (_hasCurrentWeekOverlap(courses, course, week)) {
        return false;
      }
      return _isPreferredNonCurrentCourse(courses, course, week);
    }).map((course) {
      final isCurrentWeekCourse = course.isInWeek(week);
      final isConflicting = conflictMap.containsKey(course.id);
      return _DayCourseDisplayItem(
        course: course,
        isCurrentWeekCourse: isCurrentWeekCourse,
        isConflicting: isConflicting,
        isCurrentCourse: currentCourseId == course.id,
        opacity: !isCurrentWeekCourse
            ? 0.62
            : (isConflicting ? settings.timetableConflictCourseOpacity : 1),
      );
    }).toList()
      ..sort((left, right) {
        final startCompare =
            left.course.startSection.compareTo(right.course.startSection);
        if (startCompare != 0) {
          return startCompare;
        }
        final leftCurrent = left.isCurrentWeekCourse;
        final rightCurrent = right.isCurrentWeekCourse;
        if (leftCurrent != rightCurrent) {
          return leftCurrent ? 1 : -1;
        }
        final endCompare =
            left.course.endSection.compareTo(right.course.endSection);
        if (endCompare != 0) {
          return endCompare;
        }
        return left.course.id.compareTo(right.course.id);
      });
  }

  String? _resolveDisplayCourseColor(
    _DayCourseDisplayItem item, {
    required TimetableSettings settings,
  }) {
    if (!item.isCurrentWeekCourse) {
      return '#94A3B8';
    }
    return settings.timetableUseUnifiedCardColor
        ? settings.timetableUnifiedCardColor
        : null;
  }

  String? _resolveCompactOverlineText(
    _DayCourseDisplayItem item,
    bool showConflictBadge,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (!item.isCurrentWeekCourse) {
      return l10n.nonCurrentWeekLabel;
    }
    if (item.isConflicting && showConflictBadge) {
      return l10n.conflictLabel;
    }
    return null;
  }

  String? _resolveCompactBadgeText(
    _DayCourseDisplayItem item,
    bool showConflictBadge,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final labels = <String>[];
    if (item.isCurrentCourse) {
      labels.add(l10n.ongoingCourseBadge);
    }
    if (item.isConflicting && showConflictBadge) {
      labels.add(l10n.conflictLabel);
    }
    if (labels.isEmpty) {
      return null;
    }
    return labels.join(' · ');
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

    final currentSemesterWeek = _resolveCurrentSemesterWeek(provider.settings);
    if (currentSemesterWeek == null) {
      return;
    }

    await _jumpToWeek(provider, currentSemesterWeek);
    _maybeSelectionClick(provider.settings);
  }

  Future<void> _jumpToWeek(TimetableProvider provider, int week) async {
    if (_isSyncingWeekPage) {
      return;
    }

    final targetWeek = _clampWeek(week, provider.settings.semesterWeekCount);
    if (targetWeek == provider.currentWeek) {
      return;
    }

    if (!_weekPageController.hasClients) {
      await provider.setCurrentWeek(targetWeek);
      return;
    }

    _isSyncingWeekPage = true;
    try {
      await _weekPageController.animateToPage(
        targetWeek - 1,
        duration: (targetWeek - provider.currentWeek).abs() == 1
            ? _weekSlideDuration
            : const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
      await provider.setCurrentWeek(targetWeek);
    } finally {
      _isSyncingWeekPage = false;
    }
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

    if (_isDayView && _selectedWeekForDayView != targetWeek) {
      setState(() {
        _selectedWeekForDayView = targetWeek;
      });
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
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<TimetableProvider>();
    final initialDayOfWeek = _isDayView && _selectedDayOfWeek != null
        ? _selectedDayOfWeek!
        : DateTime.now().weekday;
    await showModalBottomSheet<void>(
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
                Text(
                  l10n.addCourseSheetTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.addCourseSheetSubtitle,
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _HomeActionPageButton(
                      sheetRoute: ModalRoute.of(sheetContext),
                      icon: Icons.looks_one_rounded,
                      title: l10n.singleLessonLabel,
                      pageBuilder: (_) => AddCourseScreen(
                        mode: CourseEditorMode.singleLesson,
                        initialWeek: provider.currentWeek,
                        initialDayOfWeek: initialDayOfWeek,
                      ),
                    ),
                    _HomeActionPageButton(
                      sheetRoute: ModalRoute.of(sheetContext),
                      icon: Icons.view_week_rounded,
                      title: l10n.recurringLessonLabel,
                      pageBuilder: (_) => AddCourseScreen(
                        mode: CourseEditorMode.recurring,
                        initialWeek: provider.currentWeek,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCourseActions(Course course, int week) async {
    final l10n = AppLocalizations.of(context)!;
    final conflicts = _conflictsForCourseInWeek(course, week);
    final previewCourses = <Course>[course, ...conflicts];
    final selected = await showModalBottomSheet<_CourseActionSelection>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < previewCourses.length; index++) ...[
                  _buildCourseActionPreviewCard(
                    sheetContext,
                    previewCourses[index],
                    badgeText: conflicts.isEmpty ? null : l10n.conflictLabel,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    previewCourses[index].isInWeek(week)
                        ? l10n.courseDialogCurrentWeekHint(week)
                        : l10n.courseDialogNotThisWeekHint(week),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildCourseActionButtons(
                    sheetContext,
                    previewCourses[index],
                    week,
                  ),
                  if (index != previewCourses.length - 1) ...[
                    const SizedBox(height: 20),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }

    switch (selected.action) {
      case _CourseActionType.edit:
        _editCourse(selected.course);
        break;
      case _CourseActionType.reschedule:
        await _showRescheduleSheet(selected.course, sourceWeek: week);
        break;
      case _CourseActionType.delete:
        await _showDeleteCourseOptions(selected.course, week);
        break;
    }
  }

  List<Course> _conflictsForCourseInWeek(Course course, int week) {
    final conflictMap =
        context.read<TimetableProvider>().courseConflictMapForWeek(week);
    final seenIds = <String>{};
    final conflicts = <Course>[];
    for (final conflict in conflictMap[course.id] ?? const <Course>[]) {
      if (conflict.id == course.id || !seenIds.add(conflict.id)) {
        continue;
      }
      conflicts.add(conflict);
    }
    conflicts.sort((left, right) {
      final dayCompare = left.dayOfWeek.compareTo(right.dayOfWeek);
      if (dayCompare != 0) {
        return dayCompare;
      }
      final startCompare = left.startSection.compareTo(right.startSection);
      if (startCompare != 0) {
        return startCompare;
      }
      return left.id.compareTo(right.id);
    });
    return conflicts;
  }

  Widget _buildCourseActionPreviewCard(
    BuildContext context,
    Course course, {
    String? badgeText,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final courseColor = _colorFromHex(course.color, colorScheme.primary);

    return Container(
      key: ValueKey('course-action-card-${course.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant,
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            course.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badgeText,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onErrorContainer,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (course.shortName?.trim().isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          l10n.shortNamePrefix(course.shortName!.trim()),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
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
        ],
      ),
    );
  }

  Widget _buildCourseActionButtons(
    BuildContext context,
    Course course,
    int week,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final canReschedule = course.isInWeek(week);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _HomeActionButton(
          key: ValueKey('course-action-edit-${course.id}'),
          icon: Icons.edit_rounded,
          title: l10n.editActionShort,
          onTap: () => Navigator.of(context).pop(
            _CourseActionSelection(
              course: course,
              action: _CourseActionType.edit,
            ),
          ),
        ),
        _HomeActionButton(
          key: ValueKey('course-action-reschedule-${course.id}'),
          icon: Icons.swap_horiz_rounded,
          title: l10n.rescheduleAction,
          enabled: canReschedule,
          onTap: () => Navigator.of(context).pop(
            _CourseActionSelection(
              course: course,
              action: _CourseActionType.reschedule,
            ),
          ),
        ),
        _HomeActionButton(
          key: ValueKey('course-action-delete-${course.id}'),
          icon: Icons.delete_outline_rounded,
          title: l10n.deleteActionShort,
          accentColor: theme.colorScheme.error,
          onTap: () => Navigator.of(context).pop(
            _CourseActionSelection(
              course: course,
              action: _CourseActionType.delete,
            ),
          ),
        ),
      ],
    );
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
            l10n.courseWeekdaySectionSummary(
              course.weekDescription,
              _weekdayLabel(context, course.dayOfWeek),
              course.startSection,
              course.endSection,
            ),
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
            l10n.weekdaySectionTimeSummary(
              _weekdayLabel(context, course.dayOfWeek),
              course.startSection,
              course.endSection,
              course.startTime,
              course.endTime,
            ),
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
                ? l10n.rescheduledToMessage(
                    draft.targetWeek,
                    _weekdayLabel(context, draft.targetDayOfWeek),
                    draft.targetStartSection,
                    draft.targetEndSection,
                  )
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

  Future<void> _showProfileQuickSwitchSheet() async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<TimetableProvider>();
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final sheetRoute = ModalRoute.of(sheetContext);
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
                    child: Builder(
                      builder: (buttonContext) {
                        return OutlinedButton.icon(
                          onPressed: () => _openPopupActionPage(
                            buttonContext,
                            pageBuilder: (_) => const TimetableProfilesScreen(),
                            sheetRoute: sheetRoute,
                          ),
                          icon: const Icon(Icons.view_week_rounded),
                          label: Text(
                            AppLocalizations.of(sheetContext)!
                                .timetableManagement,
                          ),
                        );
                      },
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
    if (selected == provider.activeProfileId) {
      return;
    }
    await provider.switchProfile(selected);
    if (!mounted) {
      return;
    }
    _maybeSelectionClick(provider.settings);
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
                _HomeActionPageButton(
                  sheetRoute: ModalRoute.of(sheetContext),
                  icon: Icons.system_update_alt_rounded,
                  title: l10n.homeMenuUpdateTitle,
                  badgeText: _hasAvailableUpdate ? l10n.updateLabel : null,
                  accentColor: _hasAvailableUpdate ? colorScheme.primary : null,
                  reserveTwoLineTitleSpace: reserveTwoLineTitleSpace,
                  pageBuilder: (_) => const _TopMenuUpdatePage(),
                ),
                _HomeActionPageButton(
                  sheetRoute: ModalRoute.of(sheetContext),
                  icon: Icons.view_week_rounded,
                  title: l10n.homeMenuProfilesTitle,
                  reserveTwoLineTitleSpace: reserveTwoLineTitleSpace,
                  pageBuilder: (_) => const TimetableProfilesScreen(),
                ),
                _HomeActionPageButton(
                  sheetRoute: ModalRoute.of(sheetContext),
                  icon: Icons.dashboard_customize_rounded,
                  title: l10n.homeMenuOverviewTitle,
                  reserveTwoLineTitleSpace: reserveTwoLineTitleSpace,
                  pageBuilder: (_) => const CourseOverviewScreen(),
                ),
                _HomeActionButton(
                  icon: Icons.add_circle_outline_rounded,
                  title: l10n.homeMenuAddCourseTitle,
                  reserveTwoLineTitleSpace: reserveTwoLineTitleSpace,
                  onTap: () => Navigator.of(sheetContext).pop('add'),
                ),
                _HomeActionPageButton(
                  sheetRoute: ModalRoute.of(sheetContext),
                  icon: Icons.file_upload_outlined,
                  title: l10n.homeMenuImportTitle,
                  reserveTwoLineTitleSpace: reserveTwoLineTitleSpace,
                  pageBuilder: (_) => const CourseImportScreen(),
                ),
                _HomeActionPageButton(
                  sheetRoute: ModalRoute.of(sheetContext),
                  icon: Icons.tune_rounded,
                  title: l10n.homeMenuSettingsTitle,
                  reserveTwoLineTitleSpace: reserveTwoLineTitleSpace,
                  pageBuilder: (_) => const TimetableSettingsScreen(),
                ),
                _HomeActionPageButton(
                  sheetRoute: ModalRoute.of(sheetContext),
                  icon: Icons.favorite_border_rounded,
                  title: l10n.homeMenuCoffeeTitle,
                  accentColor: colorScheme.secondary,
                  reserveTwoLineTitleSpace: reserveTwoLineTitleSpace,
                  pageBuilder: (_) => const SupportCreatorScreen(),
                ),
                _HomeActionPageButton(
                  sheetRoute: ModalRoute.of(sheetContext),
                  icon: Icons.chat_bubble_outline_rounded,
                  title: l10n.homeMenuFeedbackTitle,
                  reserveTwoLineTitleSpace: reserveTwoLineTitleSpace,
                  pageBuilder: (_) => const FeedbackScreen(),
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
    if (selected == 'add') {
      _navigateToAddCourse(context);
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

enum _CourseActionType { edit, reschedule, delete }

class _CourseActionSelection {
  const _CourseActionSelection({
    required this.course,
    required this.action,
  });

  final Course course;
  final _CourseActionType action;
}

class _HomeActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? accentColor;
  final bool enabled;
  final bool reserveTwoLineTitleSpace;

  const _HomeActionButton({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.accentColor,
    this.enabled = true,
    this.reserveTwoLineTitleSpace = false,
  });

  @override
  Widget build(BuildContext context) {
    return _HomeActionButtonBody(
      icon: icon,
      title: title,
      accentColor: accentColor,
      enabled: enabled,
      reserveTwoLineTitleSpace: reserveTwoLineTitleSpace,
      onTap: onTap,
    );
  }
}

void _openPopupActionPage(
  BuildContext buttonContext, {
  required WidgetBuilder pageBuilder,
  required Route<dynamic>? sheetRoute,
}) {
  final renderBox = buttonContext.findRenderObject() as RenderBox?;
  final buttonOffset = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
  final buttonSize = renderBox?.size ?? const Size(80, 80);
  final sourceRect = buttonOffset & buttonSize;
  final navigator = Navigator.of(buttonContext);

  navigator.push(
    _OpenOnlyContainerPageRoute<void>(
      sourceRect: sourceRect,
      builder: pageBuilder,
      backgroundColor: Theme.of(buttonContext).scaffoldBackgroundColor,
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (sheetRoute != null && sheetRoute.isActive) {
      navigator.removeRoute(sheetRoute);
    }
  });
}

class _OpenOnlyContainerPageRoute<T> extends PageRouteBuilder<T> {
  final Rect sourceRect;
  final WidgetBuilder builder;
  final Color backgroundColor;

  _OpenOnlyContainerPageRoute({
    required this.sourceRect,
    required this.builder,
    required this.backgroundColor,
  }) : super(
          transitionDuration: const Duration(milliseconds: 420),
          reverseTransitionDuration: Duration.zero,
          opaque: false,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final size = MediaQuery.of(context).size;
            final sourceCenter = sourceRect.center;
            final screenCenter = Offset(size.width / 2, size.height / 2);
            final alignment = Alignment(
              ((sourceCenter.dx / size.width) * 2).clamp(0.0, 2.0) - 1,
              ((sourceCenter.dy / size.height) * 2).clamp(0.0, 2.0) - 1,
            );
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubicEmphasized,
            );
            return AnimatedBuilder(
              animation: curved,
              child: child,
              builder: (context, child) {
                final progress = curved.value;
                final scale = 0.84 + (0.16 * progress);
                final offset = Offset.lerp(
                  sourceCenter - screenCenter,
                  Offset.zero,
                  progress,
                )!;
                final borderRadius = BorderRadius.lerp(
                  BorderRadius.circular(22),
                  BorderRadius.zero,
                  progress,
                )!;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: backgroundColor.withValues(
                        alpha: Curves.easeOutCubic.transform(progress),
                      ),
                    ),
                    Transform.translate(
                      offset: offset,
                      child: Transform.scale(
                        alignment: alignment,
                        scale: scale,
                        child: ClipRRect(
                          borderRadius: borderRadius,
                          child: Material(
                            color: backgroundColor,
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
}

class _HomeActionPageButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final WidgetBuilder pageBuilder;
  final Route<dynamic>? sheetRoute;
  final String? badgeText;
  final Color? accentColor;
  final bool reserveTwoLineTitleSpace;

  const _HomeActionPageButton({
    required this.icon,
    required this.title,
    required this.pageBuilder,
    required this.sheetRoute,
    this.badgeText,
    this.accentColor,
    this.reserveTwoLineTitleSpace = false,
  });

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (buttonContext) {
        return _HomeActionButtonBody(
          icon: icon,
          title: title,
          badgeText: badgeText,
          accentColor: accentColor,
          enabled: true,
          reserveTwoLineTitleSpace: reserveTwoLineTitleSpace,
          onTap: () => _openPopupActionPage(
            buttonContext,
            pageBuilder: pageBuilder,
            sheetRoute: sheetRoute,
          ),
        );
      },
    );
  }
}

class _HomeActionButtonBody extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? badgeText;
  final Color? accentColor;
  final bool enabled;
  final bool reserveTwoLineTitleSpace;

  const _HomeActionButtonBody({
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
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
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

class _TopMenuUpdatePage extends StatefulWidget {
  const _TopMenuUpdatePage();

  @override
  State<_TopMenuUpdatePage> createState() => _TopMenuUpdatePageState();
}

class _TopMenuUpdatePageState extends State<_TopMenuUpdatePage> {
  late final Future<PackageInfo> _packageInfoFuture =
      PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: _packageInfoFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return AboutUpdateScreen(packageInfo: snapshot.data);
      },
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
    final l10n = AppLocalizations.of(context)!;
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
                      l10n.courseCountSummary(profile.courses.length),
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
                    l10n.currentBadge,
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

class _DayViewPageTarget {
  final int week;
  final int dayOfWeek;
  final bool isBoundaryTransition;

  const _DayViewPageTarget({
    required this.week,
    required this.dayOfWeek,
    this.isBoundaryTransition = false,
  });
}

class _DayCourseDisplayItem {
  final Course course;
  final bool isCurrentWeekCourse;
  final bool isConflicting;
  final bool isCurrentCourse;
  final double opacity;

  const _DayCourseDisplayItem({
    required this.course,
    required this.isCurrentWeekCourse,
    required this.isConflicting,
    required this.isCurrentCourse,
    required this.opacity,
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
