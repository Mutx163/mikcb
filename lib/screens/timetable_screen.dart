import 'dart:async';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'dart:math' as math;

import 'package:animations/animations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/service_message_localizer.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../models/course.dart';
import '../models/exam.dart';
import '../models/schedule_item.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../services/app_update_service.dart';
import '../utils/app_toast.dart';
import '../utils/hex_color.dart';
import '../ui/hyperos/frosted/home_page_region_blur.dart';
import '../utils/home_page_background.dart';
import '../widgets/course_action_sheet.dart';
import '../widgets/course_followup_sheets.dart';
import '../widgets/course_card.dart';
import '../widgets/home_top_menu.dart';
import '../widgets/profile_quick_switch_sheet.dart';
import '../widgets/week_selector_picker_sheet.dart';
import 'add_course_screen.dart';
import 'add_exam_screen.dart';
import 'add_schedule_item_screen.dart';
import 'about_screen.dart';
import 'course_import_screen.dart';
import 'course_overview_screen.dart';
import 'course_statistics_screen.dart';
import 'exam_list_screen.dart';
import 'support_creator_screen.dart';
import 'timetable_profiles_screen.dart';
import 'timetable_settings_screen.dart';

class TimetableScreen extends StatefulWidget {
  final bool enableUpdateCheck;
  final bool enableProgressTimer;

  const TimetableScreen({
    super.key,
    this.enableUpdateCheck = true,
    this.enableProgressTimer = true,
  });

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const int _minWeek = 1;
  static const double _weekDayHeaderHeight = 40;
  static const double _homeTitleHorizontalNudge = 4;
  static const Duration _weekSlideDuration = Duration(milliseconds: 280);
  static const Duration _dayExpandDuration = Duration(milliseconds: 360);
  static const double _dayViewCardRadius = 20;

  late final PageController _weekPageController;
  late final AnimationController _dayViewExpandController;
  final Map<int, PageController> _dayViewPageControllers = {};
  bool _isSyncingWeekPage = false;
  bool _isSyncingDayViewPage = false;
  int? _pendingSyncedWeek;
  int? _lastObservedWeekPage;
  int? _pendingSettledWeek;
  int? _pendingCommittedWeek;
  bool _isCommittingWeek = false;
  late int _visibleWeek;
  late final ValueNotifier<int> _visibleWeekListenable;
  final GlobalKey _timetableSurfaceKey = GlobalKey();
  final AppUpdateService _updateService = AppUpdateService();
  bool _hasAvailableUpdate = false;
  bool? _lastUpdateCheckIncludePrerelease;
  bool _isCheckingForUpdate = false;
  TimetableProvider? _lastSyncedProvider;
  String? _lastSyncedProfileId;
  Timer? _dayAgendaProgressTimer;
  int? _selectedDayOfWeek;
  int? _selectedWeekForDayView;
  int? _dayViewTransitionSourceWeek;
  int? _dayViewTransitionSourceDayOfWeek;
  double _dayViewAnchorFraction = 0.5;
  bool _isDaySwipeAnimating = false;

  Color _colorFromHex(String hexColor, Color fallback) {
    return parseHexColorOrFallback(hexColor, fallback: fallback);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final provider = context.read<TimetableProvider>();
    final initialWeek = provider.currentWeek;
    _visibleWeek = initialWeek;
    _pendingSettledWeek = initialWeek;
    _visibleWeekListenable = ValueNotifier<int>(initialWeek);
    _weekPageController = PageController(
      initialPage:
          _clampWeek(initialWeek, provider.settings.semesterWeekCount) - 1,
    );
    _lastObservedWeekPage = _weekPageController.initialPage;
    _dayViewExpandController = AnimationController(
      vsync: this,
      duration: _dayExpandDuration,
    );
    _dayAgendaProgressTimer = widget.enableProgressTimer
        ? Timer.periodic(const Duration(seconds: 1), (_) {
            if (!mounted || !_isDayView) {
              return;
            }
            setState(() {});
          })
        : null;
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
    _visibleWeekListenable.dispose();
    _dayAgendaProgressTimer?.cancel();
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
      // Force-push the current stage and display settings to the native
      // live-update service.  The native alarm may have fired while the app
      // was backgrounded and started the service with stale snapshot settings;
      // this ensures the correct style is applied as soon as the user returns.
      unawaited(provider.refreshLiveActivityNow());
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
        _syncWeekPageWithProvider(provider.currentWeek, provider.settings);
        final colorScheme = Theme.of(context).colorScheme;
        final foruiTheme = context.theme;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final darkFallback = colorScheme.surface;
        final settings = provider.settings;
        final hasBackdrop = hasHomePageBackdropImage(settings, isDark: isDark);
        final statusBarShowsBackdrop = homePageRegionShowsBackdrop(
          settings,
          HomePageBackgroundScope.statusBar,
          isDark: isDark,
        );
        final timetableShowsBackdrop = homePageRegionShowsBackdrop(
          settings,
          HomePageBackgroundScope.timetable,
          isDark: isDark,
        );
        final pageBackgroundColor = resolveHomePageBackgroundColor(
          settings: settings,
          isDark: isDark,
          darkFallback: darkFallback,
        );
        final headerBackground = resolveHomePageRegionBackground(
          settings: settings,
          isDark: isDark,
          darkFallback: darkFallback,
          region: HomePageBackgroundScope.header,
        );
        final timetableBackground = resolveHomePageRegionBackground(
          settings: settings,
          isDark: isDark,
          darkFallback: darkFallback,
          region: HomePageBackgroundScope.timetable,
        );
        final headerShowsBackdrop = homePageRegionShowsBackdrop(
          settings,
          HomePageBackgroundScope.header,
          isDark: isDark,
        );
        final headerUsesFrostedChrome =
            hasBackdrop &&
            (headerShowsBackdrop || settings.homePageHeaderBlurEnabled);
        final headerBarColor = headerUsesFrostedChrome
            ? Colors.transparent
            : headerBackground.color;
        final scaffoldBackgroundColor = timetableShowsBackdrop
            ? Colors.transparent
            : timetableBackground.color;
        final systemOverlayBackground = statusBarShowsBackdrop
            ? (hasBackdrop
                  ? (headerUsesFrostedChrome
                        ? const Color(0xFF1A1A1A)
                        : Colors.black)
                  : pageBackgroundColor)
            : pageBackgroundColor;
        final headerTitleStyle = foruiTheme.typography.display.xl.copyWith(
          fontWeight: FontWeight.w400,
          height: 1.1,
          color: foruiTheme.colors.foreground,
        );
        const headerHorizontalInset = 8.0;
        const headerTopInset = 0.0;
        final headerBottomInset = headerUsesFrostedChrome ? 0.0 : 2.0;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (hasBackdrop)
              homePageBackdropLayer(settings: settings, isDark: isDark),
            if (hasBackdrop && !statusBarShowsBackdrop)
              HomePageStatusBarBackdropMask(color: pageBackgroundColor),
            HomePageHeaderBlurBand(
              enabled: settings.homePageHeaderBlurEnabled,
              includeStatusBar: statusBarShowsBackdrop,
              extendBottom:
                  settings.homePageWeekdayBarBlurEnabled && hasBackdrop
                  ? homePageFrostedRegionSeamOverlap
                  : 0,
            ),
            HyperosRootPage(
              overlayHeader: false,
              resizeToAvoidBottomInset: false,
              backgroundColor: scaffoldBackgroundColor,
              headerDecoration: BoxDecoration(color: headerBarColor),
              headerStyle: FHeaderStyleDelta.delta(
                decoration: DecorationDelta.boxDelta(color: headerBarColor),
                systemOverlayStyle: HyperosColors.systemOverlayForBackground(
                  systemOverlayBackground,
                ),
                titleTextStyle: TextStyleDelta.value(headerTitleStyle),
                padding: EdgeInsetsGeometryDelta.value(
                  EdgeInsets.fromLTRB(
                    headerHorizontalInset,
                    headerTopInset,
                    headerHorizontalInset,
                    headerBottomInset,
                  ),
                ),
                constraints: const BoxConstraints(minHeight: 44),
              ),
              title: _buildProfileSwitcherTrigger(provider),
              suffixes: [
                FHeaderAction(
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
                                color: headerBarColor.a == 0
                                    ? colorScheme.surface
                                    : headerBarColor,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  semanticsLabel: l10n.moreTooltip,
                  onPress: _showTopActionsSheet,
                ),
              ],
              childPad: false,
              child: Material(
                type: MaterialType.transparency,
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : MediaQuery.removeViewInsets(
                        context: context,
                        removeBottom: true,
                        child: Stack(
                          children: [
                            Padding(
                              key: _timetableSurfaceKey,
                              padding: EdgeInsets.only(
                                bottom: hasBackdrop ? 0 : 8,
                              ),
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
                            ValueListenableBuilder<int>(
                              valueListenable: _visibleWeekListenable,
                              builder: (context, visibleWeek, child) {
                                if (!_shouldShowFloatingBackToCurrentWeekButton(
                                  provider,
                                  provider.settings,
                                  visibleWeek,
                                )) {
                                  return const SizedBox.shrink();
                                }
                                return _buildFloatingBackToCurrentWeekButton(
                                  provider,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
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

  bool get _shouldShowDayViewOverlay =>
      _selectedDayOfWeek != null &&
      (_isDayView || _dayViewExpandController.isAnimating);

  int? get _visibleDayViewWeek {
    if (_isDaySwipeAnimating && _dayViewTransitionSourceWeek != null) {
      return _dayViewTransitionSourceWeek;
    }
    return _selectedWeekForDayView;
  }

  int _resolveStoredDayOfWeek(TimetableSettings settings, int storedDayOfWeek) {
    final visibleDays = _visibleDayNumbers(settings);
    if (visibleDays.contains(storedDayOfWeek)) {
      return storedDayOfWeek;
    }
    return visibleDays.first;
  }

  void _restoreViewStateFromProvider(TimetableProvider provider) {
    final settings = provider.settings;
    _visibleWeek = _clampWeek(provider.currentWeek, settings.semesterWeekCount);
    _pendingSettledWeek = _visibleWeek;
    _pendingCommittedWeek = null;
    _visibleWeekListenable.value = _visibleWeek;
    final restoredDayOfWeek = _resolveStoredDayOfWeek(
      settings,
      settings.timetableLastViewedDayOfWeek,
    );
    _lastSyncedProvider = provider;
    _lastSyncedProfileId = provider.activeProfileId;
    _dayViewTransitionSourceWeek = null;
    _dayViewTransitionSourceDayOfWeek = null;
    _isSyncingDayViewPage = false;
    _isDaySwipeAnimating = false;
    // Defer disposal to after the current frame so that AnimatedBuilder
    // widgets that are still attached to these controllers can detach
    // gracefully during the ongoing build pass.
    final oldControllers = _dayViewPageControllers.values.toList();
    _dayViewPageControllers.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in oldControllers) {
        c.dispose();
      }
    });
    if (settings.timetableHomeViewMode == TimetableHomeViewMode.day) {
      _selectedWeekForDayView = _visibleWeek;
      _selectedDayOfWeek = restoredDayOfWeek;
      _dayViewExpandController.value = 1;
    } else {
      _selectedWeekForDayView = null;
      _selectedDayOfWeek = null;
      _dayViewExpandController.value = 0;
    }
  }

  void _applyVisibleWeek(
    int week, {
    bool rebuild = false,
    bool syncDayView = false,
  }) {
    final shouldSyncDayView = syncDayView && _selectedWeekForDayView != week;
    if (_visibleWeek == week && !shouldSyncDayView) {
      return;
    }
    _visibleWeek = week;
    _visibleWeekListenable.value = week;
    if ((rebuild || shouldSyncDayView) && mounted) {
      setState(() {
        if (shouldSyncDayView) {
          _selectedWeekForDayView = week;
        }
      });
      return;
    }
  }

  bool get _hasPendingLocalWeekTransition =>
      (_pendingSettledWeek != null && _pendingSettledWeek != _visibleWeek) ||
      _pendingCommittedWeek != null ||
      _isCommittingWeek;

  void _syncViewStateIfNeeded(TimetableProvider provider) {
    if (identical(_lastSyncedProvider, provider) &&
        _lastSyncedProfileId == provider.activeProfileId) {
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

  /// Opaque chrome for day-view layers over wallpaper-backed week chrome.
  HomePageBackgroundVisual _opaqueHomePageRegionBackground({
    required TimetableSettings settings,
    required bool isDark,
    required Color darkFallback,
    required int region,
  }) {
    final regionBackground = resolveHomePageRegionBackground(
      settings: settings,
      isDark: isDark,
      darkFallback: darkFallback,
      region: region,
    );
    if (regionBackground.isTransparent) {
      return HomePageBackgroundVisual(
        color: resolveHomePageBackgroundColor(
          settings: settings,
          isDark: isDark,
          darkFallback: darkFallback,
        ),
      );
    }
    return regionBackground;
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
      _dayViewAnchorFraction = (localDx / surfaceBox.size.width).clamp(
        0.1,
        0.9,
      );
    });
  }

  Future<void> _toggleDayView({
    required int week,
    required int dayOfWeek,
    required TimetableSettings settings,
  }) async {
    final normalizedWeek = _clampWeek(week, settings.semesterWeekCount);
    final isSameSelection =
        _isDayView &&
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
    _prepareDayViewPageController(
      settings,
      normalizedWeek,
      dayOfWeek,
      forceRecreate: shouldAnimateOpen,
    );
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
      return _DayViewPageTarget(week: week, dayOfWeek: visibleDays[dayIndex]);
    }

    if (hasNextWeek && page == _dayViewPageCount(settings, week) - 1) {
      return _DayViewPageTarget(
        week: week + 1,
        dayOfWeek: visibleDays.first,
        isBoundaryTransition: true,
      );
    }

    return _DayViewPageTarget(week: week, dayOfWeek: visibleDays.first);
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
    int dayOfWeek, {
    bool forceRecreate = false,
  }) {
    final targetPage = _dayViewPageIndexForDay(settings, week, dayOfWeek);
    final existing = _dayViewPageControllers[week];
    if (forceRecreate && existing != null) {
      // Defer disposal so AnimatedBuilder can detach its listener first.
      WidgetsBinding.instance.addPostFrameCallback((_) => existing.dispose());
      _dayViewPageControllers[week] = PageController(initialPage: targetPage);
      return;
    }
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

    WidgetsBinding.instance.addPostFrameCallback((_) => existing.dispose());
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
    int targetDayOfWeek, {
    bool animateWeekPage = true,
  }) async {
    if (_selectedWeekForDayView == null || _selectedDayOfWeek == null) {
      return;
    }
    final normalizedTargetWeek = _clampWeek(
      targetWeek,
      provider.settings.semesterWeekCount,
    );
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
      if (normalizedTargetWeek == _visibleWeek) {
        await _switchDayWithinWeek(
          settings,
          normalizedTargetWeek,
          targetDayOfWeek,
          animate: false,
        );
      } else {
        await _jumpToWeek(
          provider,
          normalizedTargetWeek,
          animatePage: animateWeekPage,
        );
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
        animateWeekPage: false,
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
    return Padding(
      padding: const EdgeInsets.only(left: _homeTitleHorizontalNudge),
      child: switch (provider.settings.homeTitleStyle) {
        HomeTitleStyle.classic => _buildClassicProfileSwitcherTrigger(provider),
        HomeTitleStyle.brand => _buildBrandProfileSwitcherTrigger(provider),
      },
    );
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
    final foruiTheme = context.theme;
    final activeProfileName = provider.activeProfile?.name.trim();

    return GestureDetector(
      key: const ValueKey('profile_switcher_trigger'),
      onTap: _showProfileQuickSwitchSheet,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.timetableAppName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: foruiTheme.typography.display.lg.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.0,
              letterSpacing: 0.1,
              color: foruiTheme.colors.foreground,
            ),
          ),
          Text(
            (activeProfileName == null || activeProfileName.isEmpty)
                ? l10n.switchProfileHint
                : activeProfileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: foruiTheme.typography.body.sm.copyWith(
              color: foruiTheme.colors.mutedForeground,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekDayHeader(
    TimetableProvider provider,
    int week,
    TimetableSettings settings,
    double timeColumnWidth, {
    bool hideBottomBorder = false,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final subtleBorder = context.theme.colors.border;
    final canReturnToCurrentWeek = _canReturnToCurrentWeek(settings, week);
    final showsInlineBackToCurrentWeek =
        canReturnToCurrentWeek &&
        settings.timetableBackToCurrentWeekButtonStyle ==
            BackToCurrentWeekButtonStyle.inline;
    final visibleDays = _visibleDayNumbers(settings);

    return Container(
      height: _weekDayHeaderHeight,
      padding: EdgeInsets.zero,
      decoration: hideBottomBorder
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: subtleBorder, width: 1)),
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
                if (showsInlineBackToCurrentWeek)
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
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Row(
                  children: visibleDays
                      .map((dayOfWeek) {
                        final date = _dateForWeekDay(settings, week, dayOfWeek);
                        final isToday =
                            date != null && _isSameDate(date, DateTime.now());
                        final isSelected = _isSelectedDay(week, dayOfWeek);
                        final isDark =
                            Theme.of(context).brightness == Brightness.dark;
                        final weekdayColor = isDark
                            ? settings.weekdayBarFontColorDark
                            : settings.weekdayBarFontColorLight;
                        final accentColor = isDark
                            ? settings.weekdayBarAccentColorDark
                            : settings.weekdayBarAccentColorLight;
                        final labelColor = (isSelected || isToday)
                            ? _colorFromHex(accentColor, colorScheme.primary)
                            : _colorFromHex(
                                weekdayColor,
                                colorScheme.onSurface,
                              );
                        final subLabelColor = (isSelected || isToday)
                            ? _colorFromHex(
                                accentColor,
                                colorScheme.primary,
                              ).withValues(alpha: isSelected ? 0.9 : 0.78)
                            : _colorFromHex(
                                weekdayColor,
                                colorScheme.onSurfaceVariant,
                              ).withValues(alpha: 0.7);
                        final showsTodayMarker = isToday && !isSelected;

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
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: showsTodayMarker
                                          ? _colorFromHex(
                                              accentColor,
                                              colorScheme.primary,
                                            ).withValues(alpha: 0.35)
                                          : Colors.transparent,
                                      width: showsTodayMarker ? 2 : 0,
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
                                    if (date != null &&
                                        provider.hasExamOnDate(date))
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
                              ),
                            ),
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
                _buildWeekdaySelectionIndicator(
                  settings: settings,
                  week: week,
                  visibleDays: visibleDays,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdaySelectionIndicator({
    required TimetableSettings settings,
    required int week,
    required List<int> visibleDays,
  }) {
    final controller = _dayViewPageControllers[week];
    if (!_shouldShowDayViewOverlay ||
        _visibleDayViewWeek != week ||
        controller == null ||
        visibleDays.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          if (totalWidth <= 0) {
            return const SizedBox.shrink();
          }
          final slotWidth = totalWidth / visibleDays.length;

          return AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              final rawPage = controller.hasClients
                  ? (controller.page ?? controller.initialPage.toDouble())
                  : controller.initialPage.toDouble();
              final rawDayPosition = rawPage - (week > _minWeek ? 1.0 : 0.0);
              final maxDayIndex = (visibleDays.length - 1).toDouble();
              final clampedDayPosition = rawDayPosition
                  .clamp(0.0, maxDayIndex)
                  .toDouble();
              final overflow = rawDayPosition < 0
                  ? -rawDayPosition
                  : rawDayPosition > maxDayIndex
                  ? rawDayPosition - maxDayIndex
                  : 0.0;
              final fractionalProgress =
                  clampedDayPosition - clampedDayPosition.floorToDouble();
              final betweenDaysProgress =
                  (1 - (2 * (fractionalProgress - 0.5).abs()))
                      .clamp(0.0, 1.0)
                      .toDouble();
              final betweenDaysCurve = Curves.easeInOutCubicEmphasized
                  .transform(betweenDaysProgress);
              final edgeCurve = Curves.easeOutCubic.transform(
                overflow.clamp(0.0, 1.0),
              );
              final morphProgress = math.max(
                betweenDaysCurve * 0.55,
                edgeCurve,
              );
              final baseWidth = math.min(22.0, slotWidth * 0.34);
              final indicatorWidth =
                  baseWidth + (slotWidth * 0.24 * morphProgress);
              final edgeDirection = rawDayPosition < 0
                  ? -1.0
                  : rawDayPosition > maxDayIndex
                  ? 1.0
                  : 0.0;
              final edgePull = slotWidth * 0.10 * edgeCurve * edgeDirection;
              final centeredLeft =
                  slotWidth * clampedDayPosition +
                  ((slotWidth - indicatorWidth) / 2);
              final maxLeft = math.max(0.0, totalWidth - indicatorWidth);
              final indicatorLeft = (centeredLeft + edgePull)
                  .clamp(0.0, maxLeft)
                  .toDouble();
              final indicatorHeight = 3.0 + (1.4 * morphProgress);

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: indicatorLeft,
                    bottom: 0,
                    child: DecoratedBox(
                      key: ValueKey('weekday-selection-indicator-$week'),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.18),
                            blurRadius: 8 + (8 * morphProgress),
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: indicatorWidth,
                        height: indicatorHeight,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasBackdrop = hasHomePageBackdropImage(settings, isDark: isDark);
    final unifiedChromeBlur = homePageUsesUnifiedChromeBlur(
      settings,
      hasBackdrop: hasBackdrop,
    );

    return SizedBox(
      key: ValueKey<int>(week),
      width: availableWidth,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: timeColumnWidth,
            child: HomePageFrostedRegion(
              enabled:
                  !unifiedChromeBlur && settings.homePageTimeColumnBlurEnabled,
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
          ),
          Row(
            children: visibleDays.asMap().entries.map((entry) {
              final dayIndex = entry.key;
              final dayOfWeek = entry.value;
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
                  provider,
                  dayIndex: dayIndex,
                  dayCount: visibleDays.length,
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
    final visibleDayViewWeek = _visibleDayViewWeek;

    return Stack(
      fit: StackFit.expand,
      children: [
        NotificationListener<ScrollEndNotification>(
          onNotification: (notification) {
            final metrics = notification.metrics;
            if (metrics.axis == Axis.horizontal) {
              _finalizeWeekPageSettled(provider);
            }
            return false;
          },
          child: PageView.builder(
            controller: _weekPageController,
            itemCount: settings.semesterWeekCount,
            allowImplicitScrolling: true,
            physics: _isDayView
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(parent: ClampingScrollPhysics()),
            onPageChanged: (page) =>
                _handleWeekPageChanged(page, settings.semesterWeekCount),
            itemBuilder: (context, index) {
              final week = index + 1;
              return RepaintBoundary(
                child: _buildWeekPage(
                  provider,
                  settings,
                  availableWidth,
                  availableHeight,
                  week,
                ),
              );
            },
          ),
        ),
        if (_shouldShowDayViewOverlay && visibleDayViewWeek != null)
          Positioned.fill(
            top: _weekDayHeaderHeight,
            child: _buildAnchoredDayViewOverlay(
              provider: provider,
              settings: settings,
              week: visibleDayViewWeek,
            ),
          ),
      ],
    );
  }

  Widget _buildWeekPage(
    TimetableProvider provider,
    TimetableSettings settings,
    double availableWidth,
    double availableHeight,
    int week,
  ) {
    final bodyAvailableHeight = (availableHeight - _weekDayHeaderHeight).clamp(
      0.0,
      double.infinity,
    );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasBackdrop = hasHomePageBackdropImage(settings, isDark: isDark);
    final unifiedChromeBlur = homePageUsesUnifiedChromeBlur(
      settings,
      hasBackdrop: hasBackdrop,
    );
    final weekdayShowsBackdrop = homePageRegionShowsBackdrop(
      settings,
      HomePageBackgroundScope.weekdayBar,
      isDark: isDark,
    );
    final timeColumnWidth = _resolveTimeColumnWidth(settings);
    final pageChromeFallback = Theme.of(context).colorScheme.surface;
    final isActiveDayViewWeek = _isDayView && week == _selectedWeekForDayView;
    final weekdayHeader = homePageBackgroundLayer(
      visual: isActiveDayViewWeek
          ? _opaqueHomePageRegionBackground(
              settings: settings,
              isDark: isDark,
              darkFallback: pageChromeFallback,
              region: HomePageBackgroundScope.weekdayBar,
            )
          : homePageRegionChromeVisual(
              settings: settings,
              isDark: isDark,
              darkFallback: pageChromeFallback,
              region: HomePageBackgroundScope.weekdayBar,
              chromeBlurEnabled: settings.homePageWeekdayBarBlurEnabled,
            ),
      child: HomePageFrostedRegion(
        enabled:
            !unifiedChromeBlur &&
            settings.homePageWeekdayBarBlurEnabled &&
            !isActiveDayViewWeek,
        overlapTop: settings.homePageHeaderBlurEnabled && hasBackdrop
            ? homePageFrostedRegionSeamOverlap
            : 0,
        child: _buildWeekDayHeader(
          provider,
          week,
          settings,
          timeColumnWidth,
          hideBottomBorder:
              weekdayShowsBackdrop ||
              settings.homePageWeekdayBarBlurEnabled ||
              unifiedChromeBlur,
        ),
      ),
    );

    final pageBody = Column(
      children: [
        weekdayHeader,
        Expanded(
          child: homePageBackgroundLayer(
            visual: resolveHomePageRegionBackground(
              settings: settings,
              isDark: isDark,
              darkFallback: Theme.of(context).colorScheme.surface,
              region: HomePageBackgroundScope.timetable,
            ),
            child: _buildWeekPageBody(
              provider: provider,
              settings: settings,
              week: week,
              grid: grid,
            ),
          ),
        ),
      ],
    );

    final backdropImage = settings.homePageBackdropFollowsWeekPager
        ? homePageBackdropImageWidget(settings: settings, isDark: isDark)
        : null;
    final needsPageStack = backdropImage != null || unifiedChromeBlur;

    if (!needsPageStack) {
      return KeyedSubtree(key: ValueKey('week-page-$week'), child: pageBody);
    }

    return KeyedSubtree(
      key: ValueKey('week-page-$week'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (backdropImage != null) Positioned.fill(child: backdropImage),
          if (unifiedChromeBlur && !isActiveDayViewWeek)
            Positioned.fill(
              child: HomePageUnifiedWeekFrostedOverlay(
                weekdayBarHeight: _weekDayHeaderHeight,
                timeColumnWidth: timeColumnWidth,
                overlapTop: settings.homePageHeaderBlurEnabled
                    ? homePageFrostedRegionSeamOverlap
                    : 0,
              ),
            ),
          pageBody,
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
    return IgnorePointer(
      ignoring: _isDayView,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        opacity: _isDayView ? 0.18 : 1,
        child: weekGrid,
      ),
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
    final panel = _buildDayViewPanel(
      provider: provider,
      settings: settings,
      week: week,
      dayOfWeek: selectedDayOfWeek,
    );

    return AnimatedBuilder(
      animation: _dayViewExpandController,
      child: panel,
      builder: (context, child) {
        final progress = Curves.easeInOutCubicEmphasized.transform(
          _dayViewExpandController.value,
        );
        final widthFactor = 0.18 + (0.82 * progress);
        final heightFactor = math.max(0.04, progress);
        final translateY = (1 - progress) * -24;
        final borderRadius = BorderRadius.circular(28 * (1 - progress));
        final borderColor = Color.lerp(
          colorScheme.outlineVariant,
          Colors.transparent,
          progress,
        )!;
        final shadowAlpha =
            (theme.brightness == Brightness.dark ? 0.08 : 0.06) *
            (1 - progress);

        return IgnorePointer(
          ignoring: progress < 0.98,
          child: Opacity(
            opacity: Curves.easeOutCubic.transform(progress),
            child: ClipRRect(
              borderRadius: borderRadius,
              child: Align(
                alignment: Alignment(_dayViewAnchorAlignmentX, -1),
                widthFactor: widthFactor,
                heightFactor: heightFactor,
                child: Transform.translate(
                  offset: Offset(0, translateY),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(
                            alpha: shadowAlpha,
                          ),
                          blurRadius: 28 * (1 - progress),
                          offset: Offset(0, 12 * (1 - progress)),
                        ),
                      ],
                    ),
                    child: child,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final darkFallback = colorScheme.surface;
    final backgroundVisual = _opaqueHomePageRegionBackground(
      settings: settings,
      isDark: isDark,
      darkFallback: darkFallback,
      region: HomePageBackgroundScope.timetable,
    );
    final controller = _ensureDayViewPageController(settings, week);
    _syncDayViewPageWithSelection(settings, week);
    final pageCount = _dayViewPageCount(settings, week);

    return homePageBackgroundLayer(
      visual: backgroundVisual,
      child: Container(
        key: ValueKey('timetable-day-view-panel-$week'),
        child: Column(
          children: [
            const SizedBox(height: 14),
            SizedBox(key: ValueKey('timetable-day-view-$week-$dayOfWeek')),
            Expanded(
              child: IgnorePointer(
                ignoring: _isDaySwipeAnimating,
                child: PageView.builder(
                  key: const ValueKey('day-view-swipe-area'),
                  controller: controller,
                  physics: const PageScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  itemCount: pageCount,
                  onPageChanged: (page) =>
                      _handleDayViewPageChanged(provider, settings, week, page),
                  itemBuilder: (context, page) {
                    final target = _dayViewTargetForPage(settings, week, page);
                    final selectedDate = _dateForWeekDay(
                      settings,
                      target.week,
                      target.dayOfWeek,
                    );
                    final conflictMap = provider.courseConflictMapForWeek(
                      target.week,
                    );
                    final courses = _getCoursesForDay(
                      provider.courses,
                      target.week,
                      target.dayOfWeek,
                      settings,
                    );
                    final currentCourse =
                        _isSelectedDayToday(
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
                    final currentCourseIds =
                        _isSelectedDayToday(
                          provider: provider,
                          settings: settings,
                          week: target.week,
                          dayOfWeek: target.dayOfWeek,
                        )
                        ? provider
                              .getCoursesInProgress(
                                dayOfWeek: target.dayOfWeek,
                                week: target.week,
                              )
                              .map((course) => course.id)
                              .toSet()
                        : const <String>{};
                    final displayItems = _buildDayCourseDisplayItems(
                      courses: courses,
                      week: target.week,
                      settings: settings,
                      conflictMap: conflictMap,
                      currentCourseIds: currentCourseIds,
                    );
                    final agendaItems = _buildDayAgendaItems(
                      provider: provider,
                      settings: settings,
                      week: target.week,
                      dayOfWeek: target.dayOfWeek,
                      courseItems: displayItems,
                    );
                    final scheduleItems = agendaItems
                        .where((item) => item.isScheduleItem)
                        .map((item) => item.scheduleItem!)
                        .toList(growable: false);
                    final isActivePage =
                        target.week == _selectedWeekForDayView &&
                        target.dayOfWeek == _selectedDayOfWeek;
                    return Column(
                      key: ValueKey(
                        'day-content-${target.week}-${target.dayOfWeek}',
                      ),
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
                            courseItems: displayItems,
                            scheduleItems: scheduleItems,
                            agendaItems: agendaItems,
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
    return dayOfWeek == now.weekday && week == _visibleWeek;
  }

  DateTime _resolveDisplayDateForWeekDay({
    required TimetableProvider provider,
    required TimetableSettings settings,
    required int week,
    required int dayOfWeek,
  }) {
    final resolvedDate = _dateForWeekDay(settings, week, dayOfWeek);
    if (resolvedDate != null) {
      return resolvedDate;
    }

    final now = DateTime.now();
    final normalizedToday = DateTime(now.year, now.month, now.day);
    final dayDelta = (week - _visibleWeek) * 7 + dayOfWeek - now.weekday;
    return normalizedToday.add(Duration(days: dayDelta));
  }

  List<ScheduleItem> _getScheduleItemsForWeekDay({
    required TimetableProvider provider,
    required TimetableSettings settings,
    required int week,
    required int dayOfWeek,
  }) {
    final targetDate = _resolveDisplayDateForWeekDay(
      provider: provider,
      settings: settings,
      week: week,
      dayOfWeek: dayOfWeek,
    );
    return provider.getScheduleItemsForDate(targetDate);
  }

  _DayAgendaItem _buildScheduleAgendaItemForDate({
    required ScheduleItem item,
    required DateTime targetDate,
  }) {
    final normalizedTargetDate = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
    );
    final continuesFromPreviousDay = item.startDate.isBefore(
      normalizedTargetDate,
    );
    final continuesToNextDay = item.endDate.isAfter(normalizedTargetDate);
    return _DayAgendaItem.schedule(
      item,
      startTime: continuesFromPreviousDay ? '00:00' : item.startTime,
      endTime: continuesToNextDay ? '23:59' : item.endTime,
      continuesFromPreviousDay: continuesFromPreviousDay,
      continuesToNextDay: continuesToNextDay,
    );
  }

  List<_DayAgendaItem> _buildDayAgendaItems({
    required TimetableProvider provider,
    required TimetableSettings settings,
    required int week,
    required int dayOfWeek,
    required List<_DayCourseDisplayItem> courseItems,
  }) {
    final targetDate = _resolveDisplayDateForWeekDay(
      provider: provider,
      settings: settings,
      week: week,
      dayOfWeek: dayOfWeek,
    );
    final items = <_DayAgendaItem>[
      ...courseItems.map(_DayAgendaItem.course),
      ..._getScheduleItemsForWeekDay(
        provider: provider,
        settings: settings,
        week: week,
        dayOfWeek: dayOfWeek,
      ).map(
        (item) =>
            _buildScheduleAgendaItemForDate(item: item, targetDate: targetDate),
      ),
      ...provider.exams
          .where((e) => !e.isExpired && _isSameDate(e.dateTime, targetDate))
          .map(_DayAgendaItem.exam),
    ];

    items.sort((left, right) {
      final startCompare = left.startTime.compareTo(right.startTime);
      if (startCompare != 0) {
        return startCompare;
      }
      final endCompare = left.endTime.compareTo(right.endTime);
      if (endCompare != 0) {
        return endCompare;
      }
      final leftType = left.isExam ? 2 : (left.isScheduleItem ? 1 : 0);
      final rightType = right.isExam ? 2 : (right.isScheduleItem ? 1 : 0);
      if (leftType != rightType) {
        return leftType.compareTo(rightType);
      }
      return left.id.compareTo(right.id);
    });
    return items;
  }

  Widget _buildDayViewSummary({
    Key? key,
    required TimetableProvider provider,
    required TimetableSettings settings,
    required int week,
    required int dayOfWeek,
    required DateTime? selectedDate,
    required Course? currentCourse,
    required List<_DayCourseDisplayItem> courseItems,
    required List<ScheduleItem> scheduleItems,
    required List<_DayAgendaItem> agendaItems,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final foruiTheme = context.theme;
    final colorScheme = theme.colorScheme;
    final isToday = _isSelectedDayToday(
      provider: provider,
      settings: settings,
      week: week,
      dayOfWeek: dayOfWeek,
    );
    final courseCount = courseItems.length;
    final scheduleCount = scheduleItems.length;
    final hasAgenda = agendaItems.isNotEmpty;
    final currentWeekItems = courseItems
        .where((item) => item.isCurrentWeekCourse)
        .toList();
    final nonCurrentWeekCourseCount = courseCount - currentWeekItems.length;
    final conflictCount = courseItems
        .where((item) => item.isConflicting)
        .length;
    final firstAgenda = hasAgenda ? agendaItems.first : null;
    final lastAgenda = hasAgenda ? agendaItems.last : null;
    final locale = Localizations.localeOf(context);
    final localeName = locale.countryCode?.isNotEmpty == true
        ? '${locale.languageCode}_${locale.countryCode}'
        : locale.languageCode;
    final dateLabel = selectedDate != null
        ? _formatDayViewSummaryDate(
            selectedDate,
            dayOfWeek: dayOfWeek,
            localeName: localeName,
          )
        : _weekdayLabel(context, dayOfWeek);
    final countBadgeColor = hasAgenda
        ? colorScheme.primary.withValues(alpha: 0.10)
        : colorScheme.surfaceContainerHigh;
    final targetDate =
        selectedDate ??
        _resolveDisplayDateForWeekDay(
          provider: provider,
          settings: settings,
          week: week,
          dayOfWeek: dayOfWeek,
        );
    final dayExams =
        provider.exams
            .where((e) => !e.isExpired && _isSameDate(e.dateTime, targetDate))
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final countBadgeTextColor = hasAgenda
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final selectedDayDate = selectedDate != null
        ? DateTime(selectedDate.year, selectedDate.month, selectedDate.day)
        : null;
    final backToTodayIcon =
        selectedDayDate != null && selectedDayDate.isBefore(normalizedToday)
        ? Icons.arrow_forward_rounded
        : Icons.arrow_back_rounded;

    return DecoratedBox(
      key: key,
      decoration: BoxDecoration(
        color: foruiTheme.colors.background,
        borderRadius: BorderRadius.circular(_dayViewCardRadius),
        border: Border.all(color: foruiTheme.colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (isToday)
                        Text(
                          l10n.todayTimetableTitle,
                          style: foruiTheme.typography.body.sm.copyWith(
                            color: foruiTheme.colors.mutedForeground,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: const ValueKey('back-to-today-button'),
                            onTap: () async {
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
                            borderRadius: BorderRadius.circular(999),
                            child: Ink(
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      backToTodayIcon,
                                      size: 14,
                                      color: colorScheme.onPrimaryContainer,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      l10n.backToTodayAction,
                                      style: foruiTheme.typography.body.xs
                                          .copyWith(
                                            color:
                                                colorScheme.onPrimaryContainer,
                                            fontWeight: FontWeight.w600,
                                            height: 1.1,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '·',
                          style: foruiTheme.typography.body.sm.copyWith(
                            color: foruiTheme.colors.mutedForeground,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        l10n.weekLabel(week),
                        style: foruiTheme.typography.body.sm.copyWith(
                          color: foruiTheme.colors.mutedForeground,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    dateLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: foruiTheme.typography.display.lg.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                      height: 1.15,
                      color: foruiTheme.colors.foreground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: countBadgeColor,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          hasAgenda
                              ? (courseCount > 0
                                    ? l10n.courseCountSummary(courseCount)
                                    : l10n.scheduleCountSummary(scheduleCount))
                              : l10n.courseCountSummary(0),
                          style: foruiTheme.typography.body.xs2.copyWith(
                            color: countBadgeTextColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (scheduleCount > 0 && courseCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            l10n.scheduleCountSummary(scheduleCount),
                            style: foruiTheme.typography.body.xs2.copyWith(
                              color: foruiTheme.colors.mutedForeground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (firstAgenda != null)
                        Text(
                          '${l10n.classStartsAtLabel(firstAgenda.startTime)} · ${l10n.classEndsAtLabel(lastAgenda!.endTime)}',
                          style: foruiTheme.typography.body.xs2.copyWith(
                            color: foruiTheme.colors.mutedForeground,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  if (currentCourse != null ||
                      conflictCount > 0 ||
                      nonCurrentWeekCourseCount > 0 ||
                      dayExams.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (currentCourse != null)
                          _buildDayViewSummaryChip(
                            icon: Icons.bolt_rounded,
                            text:
                                '${l10n.ongoingCourseBadge} · ${currentCourse.name}',
                            accentColor: colorScheme.primary,
                          ),
                        if (conflictCount > 0)
                          _buildDayViewSummaryChip(
                            icon: Icons.warning_amber_rounded,
                            text: l10n.conflictCountLabel(conflictCount),
                            accentColor: colorScheme.error,
                          ),
                        if (nonCurrentWeekCourseCount > 0)
                          _buildDayViewSummaryChip(
                            icon: Icons.visibility_rounded,
                            text:
                                '${l10n.nonCurrentWeekLabel} ${l10n.courseCountSummary(nonCurrentWeekCourseCount)}',
                          ),
                        ...dayExams.map(
                          (exam) => _buildDayViewSummaryChip(
                            icon: Icons.school_outlined,
                            text:
                                '${exam.name} · ${exam.daysUntil == 0 ? l10n.examCountdownToday : l10n.examCountdownDays(exam.daysUntil)}',
                            accentColor: colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              key: const ValueKey('back-to-week-view-button'),
              onPressed: () => _closeDayView(settings),
              icon: const Icon(Icons.close_rounded, size: 18),
              tooltip: l10n.backToWeekViewAction,
              style: IconButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(6),
                minimumSize: const Size(32, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: foruiTheme.colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayViewSummaryChip({
    required IconData icon,
    required String text,
    Color? accentColor,
  }) {
    final foruiTheme = context.theme;
    final resolvedAccent = accentColor ?? foruiTheme.colors.mutedForeground;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: resolvedAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: resolvedAccent),
          const SizedBox(width: 5),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: foruiTheme.typography.body.xs.copyWith(
              color: resolvedAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDayViewSummaryDate(
    DateTime date, {
    required int dayOfWeek,
    required String localeName,
  }) {
    final formattedDate = DateFormat.MMMd(localeName).format(date);
    return '$formattedDate ${_weekdayLabel(context, dayOfWeek)}';
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
    final currentCourseIds =
        _isSelectedDayToday(
          provider: provider,
          settings: settings,
          week: week,
          dayOfWeek: dayOfWeek,
        )
        ? provider
              .getCoursesInProgress(dayOfWeek: dayOfWeek, week: week)
              .map((course) => course.id)
              .toSet()
        : const <String>{};
    final displayItems = _buildDayCourseDisplayItems(
      courses: courses,
      week: week,
      settings: settings,
      conflictMap: provider.courseConflictMapForWeek(week),
      currentCourseIds: currentCourseIds,
    );
    final agendaItems = _buildDayAgendaItems(
      provider: provider,
      settings: settings,
      week: week,
      dayOfWeek: dayOfWeek,
      courseItems: displayItems,
    );
    if (agendaItems.isEmpty) {
      return Padding(
        key: key,
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        child: _buildDayViewEmptyColumn(week: week, settings: settings),
      );
    }
    return ListView.separated(
      key: PageStorageKey<String>('day-agenda-$week-$dayOfWeek'),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      itemCount: agendaItems.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, itemIndex) {
        final item = agendaItems[itemIndex];
        return _buildDayAgendaEntry(week: week, settings: settings, item: item);
      },
    );
  }

  Widget _buildDayViewEmptyColumn({
    required int week,
    required TimetableSettings settings,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: _buildDayViewEmptyState(week: week),
    );
  }

  Widget _buildDayAgendaEntry({
    required int week,
    required TimetableSettings settings,
    required _DayAgendaItem item,
  }) {
    if (item.isExam) {
      return _buildExamAgendaEntry(
        item.exam!,
        provider: context.read<TimetableProvider>(),
      );
    }
    if (item.isScheduleItem) {
      return _buildScheduleAgendaEntry(item);
    }

    final courseItem = item.courseItem!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final colorHex = _resolveDisplayCourseColor(courseItem, settings: settings);
    final resolvedColor = _colorFromHex(
      colorHex ?? courseItem.course.color,
      Colors.blue,
    );
    final palette = _resolveDayAgendaPalette(resolvedColor);
    final onCardColor = palette.foregroundColor;
    final statusBadges = <Widget>[
      if (courseItem.isCurrentCourse)
        _buildDayAgendaStatusBadge(
          text: l10n.ongoingCourseBadge,
          textColor: onCardColor,
          backgroundColor: Colors.white.withValues(alpha: 0.18),
        ),
      if (courseItem.isConflicting && settings.showConflictBadgeOnTimetable)
        _buildDayAgendaStatusBadge(
          text: l10n.conflictLabel,
          textColor: Colors.white,
          backgroundColor: colorScheme.error,
        ),
      if (!courseItem.isCurrentWeekCourse)
        _buildDayAgendaStatusBadge(
          text: l10n.nonCurrentWeekLabel,
          textColor: onCardColor,
          backgroundColor: Colors.white.withValues(alpha: 0.14),
        ),
      if (courseItem.course.isSuspendedInWeek(week))
        _buildDayAgendaStatusBadge(
          text: l10n.suspendedBadgeLabel,
          textColor: Colors.white,
          backgroundColor: Colors.red.shade700,
        ),
    ];
    final cardDecoration = BoxDecoration(
      color: palette.baseColor,
      borderRadius: BorderRadius.circular(_dayViewCardRadius),
      border: courseItem.isConflicting
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
          if (courseItem.isConflicting)
            Color.lerp(palette.fillColor, colorScheme.error, 0.12) ??
                palette.fillColor
          else
            palette.fillColor,
        ],
      ),
      boxShadow: [
        BoxShadow(
          color:
              (courseItem.isConflicting ? colorScheme.error : palette.fillColor)
                  .withValues(alpha: courseItem.isConflicting ? 0.20 : 0.18),
          blurRadius: courseItem.isConflicting ? 18 : 16,
          offset: const Offset(0, 4),
        ),
      ],
    );
    final progressInfo = courseItem.isCurrentCourse
        ? _resolveDayAgendaProgressInfo(courseItem.course, palette: palette)
        : null;

    final isSuspended = courseItem.course.isSuspendedInWeek(week);
    final effectiveOpacity = isSuspended ? 0.4 : courseItem.opacity;

    return Opacity(
      opacity: effectiveOpacity,
      child: OpenContainer<void>(
        key: ValueKey('day-view-edit-card-${courseItem.course.id}'),
        tappable: false,
        transitionType: ContainerTransitionType.fadeThrough,
        transitionDuration: const Duration(milliseconds: 420),
        openColor: theme.scaffoldBackgroundColor,
        closedColor: Colors.transparent,
        closedElevation: 0,
        openElevation: 0,
        closedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_dayViewCardRadius),
        ),
        openShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        openBuilder: (context, _) => ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: AddCourseScreen(
            courseGroup: context.read<TimetableProvider>().courseGroupForCourse(
              courseItem.course,
            ),
            initialCourse: courseItem.course,
          ),
        ),
        closedBuilder: (context, openContainer) {
          final content = progressInfo != null
              ? _buildCurrentDayAgendaCard(
                  item: courseItem,
                  progressInfo: progressInfo,
                  l10n: l10n,
                  colorScheme: colorScheme,
                  openContainer: openContainer,
                )
              : _buildDefaultDayAgendaCard(
                  item: courseItem,
                  settings: settings,
                  l10n: l10n,
                  palette: palette,
                  statusBadges: statusBadges,
                  cardDecoration: cardDecoration,
                  openContainer: openContainer,
                );
          return Material(color: Colors.transparent, child: content);
        },
      ),
    );
  }

  Widget _buildDefaultDayAgendaCard({
    required _DayCourseDisplayItem item,
    required TimetableSettings settings,
    required AppLocalizations l10n,
    required _DayAgendaPalette palette,
    required List<Widget> statusBadges,
    required BoxDecoration cardDecoration,
    required VoidCallback openContainer,
  }) {
    final sectionLabel = l10n.sectionRangeLabel(
      item.course.startSection,
      item.course.endSection,
    );
    final teacherValue = item.course.teacher.trim().isNotEmpty
        ? item.course.teacher.trim()
        : l10n.unknownTeacher;
    final teacherLine = '${l10n.teacherPrefix(teacherValue)} · $sectionLabel';
    final locationValue = item.course.location.trim().isNotEmpty
        ? item.course.location.trim()
        : l10n.unknownLocation;
    final locationLine = l10n.locationPrefix(locationValue);
    return InkWell(
      onTap: openContainer,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: cardDecoration,
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
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${item.course.startTime} - ${item.course.endTime}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                  ...statusBadges,
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.course.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: palette.foregroundColor,
                  fontWeight: FontWeight.w800,
                  height: 1.10,
                ),
              ),
              const SizedBox(height: 10),
              _buildCurrentDayAgendaInfoRow(
                icon: Icons.person_outline_rounded,
                text: teacherLine,
              ),
              const SizedBox(height: 6),
              _buildCurrentDayAgendaInfoRow(
                icon: Icons.location_on_outlined,
                text: locationLine,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentDayAgendaCard({
    required _DayCourseDisplayItem item,
    required _DayAgendaProgressInfo progressInfo,
    required AppLocalizations l10n,
    required ColorScheme colorScheme,
    required VoidCallback openContainer,
  }) {
    final theme = Theme.of(context);
    final sectionLabel = l10n.sectionRangeLabel(
      item.course.startSection,
      item.course.endSection,
    );
    final teacherValue = item.course.teacher.trim().isNotEmpty
        ? item.course.teacher.trim()
        : l10n.unknownTeacher;
    final teacherLine = '${l10n.teacherPrefix(teacherValue)} · $sectionLabel';
    final locationValue = item.course.location.trim().isNotEmpty
        ? item.course.location.trim()
        : l10n.unknownLocation;
    final locationLine = l10n.locationPrefix(locationValue);
    final borderColor = item.isConflicting
        ? colorScheme.error.withValues(alpha: 0.30)
        : Colors.transparent;

    return InkWell(
      onTap: openContainer,
      borderRadius: BorderRadius.circular(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          key: ValueKey('day-agenda-progress-card-${item.course.id}'),
          decoration: BoxDecoration(
            color: progressInfo.baseColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: progressInfo.fillColor.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    end: progressInfo.progress.clamp(0.0, 1.0),
                  ),
                  duration: const Duration(milliseconds: 1100),
                  curve: Curves.linear,
                  builder: (context, animatedProgress, child) {
                    return FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: animatedProgress,
                      child: child,
                    );
                  },
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: progressInfo.fillColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              Padding(
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
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${item.course.startTime} - ${item.course.endTime}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildDayAgendaStatusBadge(
                          text: progressInfo.statusText,
                          textColor: progressInfo.statusTextColor,
                          backgroundColor: progressInfo.statusBackgroundColor,
                        ),
                        if (item.isConflicting)
                          _buildDayAgendaStatusBadge(
                            text: l10n.conflictLabel,
                            textColor: Colors.white,
                            backgroundColor: colorScheme.error,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.course.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.10,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildCurrentDayAgendaInfoRow(
                      icon: Icons.person_outline_rounded,
                      text: teacherLine,
                    ),
                    const SizedBox(height: 6),
                    _buildCurrentDayAgendaInfoRow(
                      icon: Icons.location_on_outlined,
                      text: locationLine,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExamAgendaEntry(
    Exam exam, {
    required TimetableProvider provider,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final course = provider.getCourseForExam(exam);
    final courseName = course?.name ?? '';
    final location = exam.location ?? course?.location ?? '';
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
        borderRadius: BorderRadius.circular(20),
      ),
      openShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      openBuilder: (context, _) => ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: AddExamScreen(exam: exam),
      ),
      closedBuilder: (context, openContainer) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: openContainer,
            borderRadius: BorderRadius.circular(20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.error,
                      Color.lerp(
                            colorScheme.error,
                            colorScheme.errorContainer,
                            0.25,
                          ) ??
                          colorScheme.error,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.error.withValues(alpha: 0.20),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
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
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.school_outlined,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.examBadgeLabel,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
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
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              countdownText,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        exam.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (exam.startTime.isNotEmpty && exam.endTime.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '${exam.startTime} - ${exam.endTime}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.9),
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
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      if (courseName.isNotEmpty)
                        Text(
                          courseName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScheduleAgendaEntry(_DayAgendaItem agendaItem) {
    final item = agendaItem.scheduleItem!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final baseColor = _colorFromHex(item.color, colorScheme.primary);
    final cardColor = Color.lerp(baseColor, Colors.black, 0.10) ?? baseColor;
    final l10n = AppLocalizations.of(context)!;
    final hasLocation = item.location?.trim().isNotEmpty == true;
    final hasNote = item.note?.trim().isNotEmpty == true;
    final isCrossDay = item.endDate.isAfter(item.startDate);
    final progressInfo = _resolveScheduleAgendaProgressInfo(item, baseColor);

    return OpenContainer<void>(
      key: ValueKey('day-view-schedule-card-${item.id}'),
      tappable: false,
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: const Duration(milliseconds: 360),
      openColor: theme.scaffoldBackgroundColor,
      closedColor: Colors.transparent,
      closedElevation: 0,
      openElevation: 0,
      closedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_dayViewCardRadius),
      ),
      openShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      openBuilder: (context, _) => ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: AddScheduleItemScreen(scheduleItem: item),
      ),
      closedBuilder: (context, openContainer) {
        if (progressInfo != null) {
          return Material(
            color: Colors.transparent,
            child: _buildCurrentScheduleAgendaCard(
              item: item,
              agendaItem: agendaItem,
              progressInfo: progressInfo,
              l10n: l10n,
              colorScheme: colorScheme,
              openContainer: openContainer,
            ),
          );
        }
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: openContainer,
            borderRadius: BorderRadius.circular(20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Ink(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: cardColor.withValues(alpha: 0.20),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
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
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.event_note_rounded,
                                  size: 13,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${agendaItem.startTime} - ${agendaItem.endTime}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildDayAgendaStatusBadge(
                            text: l10n.scheduleBadgeLabel,
                            textColor: Colors.white,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.18,
                            ),
                          ),
                          if (isCrossDay)
                            _buildDayAgendaStatusBadge(
                              text: l10n.crossDayBadgeLabel,
                              textColor: Colors.white,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.18,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          height: 1.10,
                        ),
                      ),
                      if (hasLocation) ...[
                        const SizedBox(height: 10),
                        _buildCurrentDayAgendaInfoRow(
                          icon: Icons.location_on_outlined,
                          text: l10n.locationPrefix(item.location!.trim()),
                        ),
                      ],
                      if (hasNote) ...[
                        const SizedBox(height: 6),
                        _buildCurrentDayAgendaInfoRow(
                          icon: Icons.notes_rounded,
                          text: item.note!.trim(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentScheduleAgendaCard({
    required ScheduleItem item,
    required _DayAgendaItem agendaItem,
    required _DayAgendaProgressInfo progressInfo,
    required AppLocalizations l10n,
    required ColorScheme colorScheme,
    required VoidCallback openContainer,
  }) {
    final theme = Theme.of(context);
    final hasLocation = item.location?.trim().isNotEmpty == true;
    final hasNote = item.note?.trim().isNotEmpty == true;
    final isCrossDay = item.endDate.isAfter(item.startDate);

    return InkWell(
      onTap: openContainer,
      borderRadius: BorderRadius.circular(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          key: ValueKey('day-agenda-progress-schedule-card-${item.id}'),
          decoration: BoxDecoration(
            color: progressInfo.baseColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: progressInfo.fillColor.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    end: progressInfo.progress.clamp(0.0, 1.0),
                  ),
                  duration: const Duration(milliseconds: 1100),
                  curve: Curves.linear,
                  builder: (context, animatedProgress, child) {
                    return FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: animatedProgress,
                      child: child,
                    );
                  },
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: progressInfo.fillColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              Padding(
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
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.event_note_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${agendaItem.startTime} - ${agendaItem.endTime}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildDayAgendaStatusBadge(
                          text: progressInfo.statusText,
                          textColor: progressInfo.statusTextColor,
                          backgroundColor: progressInfo.statusBackgroundColor,
                        ),
                        _buildDayAgendaStatusBadge(
                          text: l10n.scheduleBadgeLabel,
                          textColor: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.18),
                        ),
                        if (isCrossDay)
                          _buildDayAgendaStatusBadge(
                            text: l10n.crossDayBadgeLabel,
                            textColor: Colors.white,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.18,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.10,
                      ),
                    ),
                    if (hasLocation) ...[
                      const SizedBox(height: 10),
                      _buildCurrentDayAgendaInfoRow(
                        icon: Icons.location_on_outlined,
                        text: l10n.locationPrefix(item.location!.trim()),
                      ),
                    ],
                    if (hasNote) ...[
                      const SizedBox(height: 6),
                      _buildCurrentDayAgendaInfoRow(
                        icon: Icons.notes_rounded,
                        text: item.note!.trim(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentDayAgendaInfoRow({
    required IconData icon,
    required String text,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.82)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w600,
              fontSize: 11.5,
              height: 1.15,
            ),
          ),
        ),
      ],
    );
  }

  _DayAgendaProgressInfo? _resolveDayAgendaProgressInfo(
    Course course, {
    required _DayAgendaPalette palette,
  }) {
    final now = DateTime.now();
    final startMinutes = _parseDayAgendaClockMinutes(course.startTime);
    final endMinutes = _parseDayAgendaClockMinutes(course.endTime);
    if (startMinutes == null ||
        endMinutes == null ||
        endMinutes <= startMinutes) {
      return null;
    }
    final currentMinutes =
        now.hour * 60 +
        now.minute +
        (now.second / 60) +
        (now.millisecond / 60000);
    if (currentMinutes < startMinutes || currentMinutes >= endMinutes) {
      return null;
    }
    final elapsedMinutes = currentMinutes - startMinutes;
    final totalMinutes = endMinutes - startMinutes;
    final remainingMinutes = math.max(0, (endMinutes - currentMinutes).ceil());
    final progress = (elapsedMinutes / totalMinutes).clamp(0.02, 0.98);
    final isEndingSoon = remainingMinutes <= 10;
    return _DayAgendaProgressInfo(
      progress: progress,
      remainingMinutes: remainingMinutes,
      statusText: isEndingSoon
          ? AppLocalizations.of(
              context,
            )!.dayAgendaEndingSoonStatus(remainingMinutes)
          : AppLocalizations.of(
              context,
            )!.dayAgendaInProgressStatus(remainingMinutes),
      statusBackgroundColor: Colors.white,
      statusTextColor: isEndingSoon
          ? const Color(0xFFE05D44)
          : palette.fillColor,
      baseColor: palette.baseColor,
      fillColor: palette.fillColor,
    );
  }

  _DayAgendaProgressInfo? _resolveScheduleAgendaProgressInfo(
    ScheduleItem item,
    Color background,
  ) {
    final now = DateTime.now();
    final start = _buildScheduleDateTime(item.startDate, item.startTime);
    final end = _buildScheduleDateTime(item.endDate, item.endTime);
    if (start == null || end == null || !end.isAfter(start)) {
      return null;
    }
    if (now.isBefore(start) || !now.isBefore(end)) {
      return null;
    }

    final fillColor = Color.lerp(background, Colors.black, 0.18) ?? background;
    final baseColor = Color.lerp(fillColor, Colors.white, 0.10) ?? fillColor;
    final elapsedMinutes = now.difference(start).inMilliseconds / 60000;
    final totalMinutes = end.difference(start).inMilliseconds / 60000;
    final remainingMinutes = math.max(
      0,
      end.difference(now).inMinutes +
          (end.difference(now).inSeconds % 60 > 0 ? 1 : 0),
    );
    final progress = (elapsedMinutes / totalMinutes).clamp(0.02, 0.98);
    final isEndingSoon = remainingMinutes <= 10;

    return _DayAgendaProgressInfo(
      progress: progress,
      remainingMinutes: remainingMinutes,
      statusText: isEndingSoon
          ? AppLocalizations.of(
              context,
            )!.scheduleAgendaEndingSoonStatus(remainingMinutes)
          : AppLocalizations.of(
              context,
            )!.scheduleAgendaInProgressStatus(remainingMinutes),
      statusBackgroundColor: Colors.white,
      statusTextColor: isEndingSoon ? const Color(0xFFE05D44) : fillColor,
      baseColor: baseColor,
      fillColor: fillColor,
    );
  }

  DateTime? _buildScheduleDateTime(DateTime date, String clock) {
    final minutes = _parseDayAgendaClockMinutes(clock);
    if (minutes == null) {
      return null;
    }
    return DateTime(
      date.year,
      date.month,
      date.day,
      minutes ~/ 60,
      minutes % 60,
    );
  }

  int? _parseDayAgendaClockMinutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    return hour * 60 + minute;
  }

  _DayAgendaPalette _resolveDayAgendaPalette(Color background) {
    final fillColor = Color.lerp(background, Colors.black, 0.22) ?? background;
    final baseColor = Color.lerp(fillColor, Colors.white, 0.12) ?? fillColor;
    return _DayAgendaPalette(
      baseColor: baseColor,
      fillColor: fillColor,
      foregroundColor: Colors.white,
    );
  }

  Widget _buildDayAgendaStatusBadge({
    required String text,
    required Color textColor,
    required Color backgroundColor,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w800,
          fontSize: 10.5,
          height: 1.0,
        ),
      ),
    );
  }

  BorderRadius _groupedDayColumnBorderRadius(
    int dayIndex,
    int dayCount, {
    double radius = 12,
  }) {
    if (dayCount <= 1) {
      return BorderRadius.circular(radius);
    }
    return BorderRadius.only(
      topLeft: dayIndex == 0 ? Radius.circular(radius) : Radius.zero,
      bottomLeft: dayIndex == 0 ? Radius.circular(radius) : Radius.zero,
      topRight: dayIndex == dayCount - 1
          ? Radius.circular(radius)
          : Radius.zero,
      bottomRight: dayIndex == dayCount - 1
          ? Radius.circular(radius)
          : Radius.zero,
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
    TimetableProvider provider, {
    required int dayIndex,
    required int dayCount,
  }) {
    final courseCards = <Widget>[];
    final gridLines = <Widget>[];

    final date = _dateForWeekDay(settings, week, dayOfWeek);
    final isDayHoliday = date != null && provider.isHoliday(date);

    for (
      var sectionIndex = 0;
      sectionIndex < settings.sectionCount;
      sectionIndex++
    ) {
      final section = sectionIndex + 1;
      final startingCourses = _getDisplayItemsStartingAtSection(
        displayItems,
        section,
      );

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
                overrideColorHex: _resolveDisplayCourseColor(
                  item,
                  settings: settings,
                ),
                compactOverlineText: _resolveCompactOverlineText(
                  item,
                  showConflictBadge,
                ),
                topRightBadgeText: _resolveCompactBadgeText(
                  item,
                  showConflictBadge,
                ),
                isHighlighted: item.isCurrentCourse,
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
                onTap: () => _showCourseActions(item.course, week),
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
        borderRadius: _groupedDayColumnBorderRadius(dayIndex, dayCount),
      ),
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: [...gridLines, ...courseCards],
      ),
    );
  }

  Future<void> _showWeekSelector() async {
    final provider = context.read<TimetableProvider>();
    final availableWeeks = provider.settings.availableWeeks;
    final currentSemesterWeek = _resolveCurrentSemesterWeek(provider.settings);
    final selectedWeek = await showWeekSelectorPickerSheet(
      context,
      availableWeeks: availableWeeks,
      visibleWeek: _visibleWeek,
      currentSemesterWeek: currentSemesterWeek,
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
    Set<String> currentCourseIds = const <String>{},
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
            isCurrentCourse: currentCourseIds.contains(course.id),
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
    return _clampWeek(week < 1 ? 1 : week, settings.semesterWeekCount);
  }

  bool _canReturnToCurrentWeek(TimetableSettings settings, int week) {
    final currentSemesterWeek = _resolveCurrentSemesterWeek(settings);
    return currentSemesterWeek != null && currentSemesterWeek != week;
  }

  bool _shouldShowFloatingBackToCurrentWeekButton(
    TimetableProvider provider,
    TimetableSettings settings,
    int visibleWeek,
  ) {
    if (_isDayView) {
      return false;
    }
    if (settings.timetableBackToCurrentWeekButtonStyle !=
        BackToCurrentWeekButtonStyle.floating) {
      return false;
    }
    return _canReturnToCurrentWeek(settings, visibleWeek);
  }

  Widget _buildFloatingBackToCurrentWeekButton(TimetableProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foruiColors = context.theme.colors;
    final buttonOpacity =
        provider.settings.timetableFloatingBackToCurrentWeekButtonOpacity;
    final borderRadius = BorderRadius.circular(18);

    return SafeArea(
      minimum: const EdgeInsets.only(right: 20, bottom: 24),
      child: Align(
        alignment: Alignment.bottomRight,
        child: Tooltip(
          message: l10n.backToCurrentWeekAction,
          child: Opacity(
            opacity: buttonOpacity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                border: Border.all(color: foruiColors.border, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.12 : 0.06,
                    ),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: borderRadius,
                child: HyperosFrostedSurface(
                  borderRadius: borderRadius,
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      key: const ValueKey('back-to-current-week-button'),
                      onTap: () => _jumpToCurrentWeek(provider),
                      borderRadius: borderRadius,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.my_location_rounded,
                              size: 15,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.backToCurrentWeekAction,
                              style: TextStyle(
                                fontSize: 11,
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
                ),
              ),
            ),
          ),
        ),
      ),
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
      showAppToast(
        context,
        message: AppLocalizations.of(context)!.pleaseSetSemesterStartDate,
        kind: AppToastKind.warning,
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

  Future<void> _jumpToWeek(
    TimetableProvider provider,
    int week, {
    bool animatePage = true,
  }) async {
    if (_isSyncingWeekPage) {
      return;
    }

    final targetWeek = _clampWeek(week, provider.settings.semesterWeekCount);
    if (targetWeek == _visibleWeek) {
      return;
    }

    if (!_weekPageController.hasClients) {
      _pendingSettledWeek = targetWeek;
      _pendingCommittedWeek = targetWeek;
      _applyVisibleWeek(
        targetWeek,
        rebuild: _isDayView || provider.settings.semesterStartDate == null,
        syncDayView: _isDayView,
      );
      await _commitPendingWeek(provider);
      return;
    }

    _isSyncingWeekPage = true;
    try {
      if (animatePage) {
        await _weekPageController.animateToPage(
          targetWeek - 1,
          duration: (targetWeek - _visibleWeek).abs() == 1
              ? _weekSlideDuration
              : const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
        );
      } else {
        // Day-view boundary swipes already provide the horizontal motion.
        _weekPageController.jumpToPage(targetWeek - 1);
      }
      _pendingSettledWeek = targetWeek;
    } finally {
      _isSyncingWeekPage = false;
    }

    _finalizeWeekPageSettled(
      provider,
      fallbackWeek: targetWeek,
      syncDayView: _isDayView,
    );
  }

  void _handleWeekPageChanged(int page, int maxWeek) {
    _lastObservedWeekPage = page;
    _pendingSettledWeek = _clampWeek(page + 1, maxWeek);
    _visibleWeekListenable.value = _pendingSettledWeek!;
  }

  void _syncWeekPageWithProvider(int week, TimetableSettings settings) {
    final maxWeek = settings.semesterWeekCount;
    if (_isSyncingWeekPage || _hasPendingLocalWeekTransition) {
      return;
    }

    final targetWeek = _clampWeek(week, maxWeek);
    final targetPage = targetWeek - 1;
    final shouldSyncDayView =
        _isDayView &&
        !_isDaySwipeAnimating &&
        _selectedWeekForDayView != targetWeek;
    final needsVisualSync =
        _visibleWeek != targetWeek ||
        shouldSyncDayView ||
        _lastObservedWeekPage != targetPage;
    if (!needsVisualSync) {
      return;
    }
    if (_pendingSyncedWeek == targetPage) {
      return;
    }
    _pendingSyncedWeek = targetPage;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingSyncedWeek = null;
      if (!mounted || _isSyncingWeekPage || _hasPendingLocalWeekTransition) {
        return;
      }

      final syncDayView =
          _isDayView &&
          !_isDaySwipeAnimating &&
          _selectedWeekForDayView != targetPage + 1;
      _pendingSettledWeek = targetPage + 1;
      _applyVisibleWeek(
        targetPage + 1,
        rebuild: syncDayView || settings.semesterStartDate == null,
        syncDayView: syncDayView,
      );

      if (syncDayView && mounted) {
        setState(() {
          _dayViewTransitionSourceWeek = null;
          _dayViewTransitionSourceDayOfWeek = null;
        });
      }

      if (!_weekPageController.hasClients) {
        return;
      }
      final currentPage =
          _lastObservedWeekPage ?? _weekPageController.initialPage;
      if (currentPage == targetPage) {
        return;
      }

      _lastObservedWeekPage = targetPage;
      _weekPageController.jumpToPage(targetPage);
    });
  }

  int _resolveSettledWeek(TimetableProvider provider, {int? fallbackWeek}) {
    final maxWeek = provider.settings.semesterWeekCount;
    if (_weekPageController.hasClients) {
      final page = _weekPageController.page;
      if (page != null) {
        return _clampWeek(page.round() + 1, maxWeek);
      }
    }
    if (_lastObservedWeekPage != null) {
      return _clampWeek(_lastObservedWeekPage! + 1, maxWeek);
    }
    return _clampWeek(
      fallbackWeek ?? _pendingSettledWeek ?? _visibleWeek,
      maxWeek,
    );
  }

  void _finalizeWeekPageSettled(
    TimetableProvider provider, {
    int? fallbackWeek,
    bool syncDayView = false,
  }) {
    final targetWeek = _resolveSettledWeek(
      provider,
      fallbackWeek: fallbackWeek,
    );
    _pendingSettledWeek = targetWeek;
    _pendingCommittedWeek = targetWeek;
    _applyVisibleWeek(
      targetWeek,
      rebuild: syncDayView || provider.settings.semesterStartDate == null,
      syncDayView: syncDayView,
    );
    unawaited(_commitPendingWeek(provider));
  }

  Future<void> _commitPendingWeek(TimetableProvider provider) async {
    if (_isCommittingWeek) {
      return;
    }
    _isCommittingWeek = true;
    try {
      while (mounted) {
        final targetWeek = _pendingCommittedWeek;
        if (targetWeek == null) {
          return;
        }
        if (targetWeek == provider.currentWeek) {
          _pendingCommittedWeek = null;
          continue;
        }
        _pendingCommittedWeek = null;
        _maybeSelectionClick(provider.settings);
        await provider.setCurrentWeek(targetWeek, notify: false);
      }
    } finally {
      _isCommittingWeek = false;
    }
  }

  Future<void> _navigateToAddCourse(BuildContext context) async {
    await _showAddCourseSheet();
  }

  void _editCourse(Course course) {
    final provider = context.read<TimetableProvider>();
    final group = provider.courseGroupForCourse(course);
    Navigator.push(
      context,
      HyperosPageRoute(
        settings: const RouteSettings(name: '/course/edit'),
        builder: (context) =>
            AddCourseScreen(courseGroup: group, initialCourse: course),
      ),
    );
  }

  DateTime _resolveAddScheduleInitialDate(TimetableProvider provider) {
    if (_isDayView &&
        _selectedWeekForDayView != null &&
        _selectedDayOfWeek != null) {
      return _resolveDisplayDateForWeekDay(
        provider: provider,
        settings: provider.settings,
        week: _selectedWeekForDayView!,
        dayOfWeek: _selectedDayOfWeek!,
      );
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _showAddCourseSheet() async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<TimetableProvider>();
    final initialDayOfWeek = _isDayView && _selectedDayOfWeek != null
        ? _selectedDayOfWeek!
        : DateTime.now().weekday;
    await showHomeHyperosSheet<void>(
      context: context,
      builder: (sheetContext) {
        final itemWidth =
            ((MediaQuery.sizeOf(sheetContext).width - 32 - 24) / 3).clamp(
              96.0,
              120.0,
            );

        return HyperosSheet(
          frosted: true,
          title: l10n.addCourseSheetTitle,
          description: l10n.addCourseSheetSubtitle,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: itemWidth,
                child: _HomeActionPageButton(
                  sheetRoute: ModalRoute.of(sheetContext),
                  icon: Icons.view_week_rounded,
                  title: l10n.addCourseTitle,
                  pageBuilder: (_) => AddCourseScreen(
                    initialWeek: _visibleWeek,
                    initialDayOfWeek: initialDayOfWeek,
                  ),
                ),
              ),
              SizedBox(
                width: itemWidth,
                child: _HomeActionPageButton(
                  sheetRoute: ModalRoute.of(sheetContext),
                  icon: Icons.event_note_rounded,
                  title: l10n.addScheduleAction,
                  pageBuilder: (_) => AddScheduleItemScreen(
                    initialDate: _resolveAddScheduleInitialDate(provider),
                  ),
                ),
              ),
              SizedBox(
                width: itemWidth,
                child: _HomeActionPageButton(
                  sheetRoute: ModalRoute.of(sheetContext),
                  icon: Icons.school_outlined,
                  title: l10n.addExam,
                  pageBuilder: (_) => const AddExamScreen(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCourseActions(Course course, int week) async {
    final conflicts = _conflictsForCourseInWeek(course, week);
    final previewCourses = <Course>[course, ...conflicts];
    await showCourseActionSheet(
      context,
      previewCourses: previewCourses,
      week: week,
      hasConflicts: conflicts.isNotEmpty,
      onEdit: _editCourse,
      onReschedule: (target) => _showRescheduleSheet(target, sourceWeek: week),
      onDelete: (target) => _showDeleteCourseOptions(target, week),
      onSuspend: (target) => _showSuspendSheet(target, week),
    );
  }

  List<Course> _conflictsForCourseInWeek(Course course, int week) {
    final conflictMap = context
        .read<TimetableProvider>()
        .courseConflictMapForWeek(week);
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

  Future<void> _showDeleteCourseOptions(Course course, int week) async {
    final canDeleteOccurrence = course.isInWeek(week);
    final selected = await showCourseDeleteModeSheet(
      context,
      canDeleteOccurrence: canDeleteOccurrence,
      week: week,
    );

    if (!mounted || selected == null) {
      return;
    }

    switch (selected) {
      case CourseDeleteMode.course:
        await _confirmDeleteCourse(course);
      case CourseDeleteMode.occurrence:
        await _confirmDeleteOccurrence(course, week);
    }
  }

  Future<void> _showSuspendSheet(Course course, int week) async {
    final provider = context.read<TimetableProvider>();
    final isSuspended = course.isSuspendedInWeek(week);
    final hasAnySuspended = course.suspendedWeeks?.isNotEmpty ?? false;

    final selected = await showCourseSuspendModeSheet(
      context,
      isSuspendedThisWeek: isSuspended,
      hasAnySuspended: hasAnySuspended,
    );

    if (!mounted || selected == null) {
      return;
    }

    switch (selected) {
      case CourseSuspendMode.thisWeek:
        await provider.toggleCourseSuspension(course.id, week);
      case CourseSuspendMode.allWeeks:
        if (hasAnySuspended) {
          await provider.unsuspendAllWeeks(course.id);
        } else {
          await provider.suspendAllWeeks(course.id);
        }
    }
  }

  Future<void> _confirmDeleteCourse(Course course) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDeleteCourseConfirmDialog(
      context,
      title: l10n.deleteScheduleTitle,
      message: l10n.deleteScheduleConfirmMessage(
        course.name,
        l10n.courseWeekdaySectionSummary(
          course.weekDescription(l10n),
          _weekdayLabel(context, course.dayOfWeek),
          course.startSection,
          course.endSection,
        ),
      ),
    );

    if (!confirmed || !mounted) {
      return;
    }

    await context.read<TimetableProvider>().deleteCourse(course.id);
    if (!mounted) {
      return;
    }
    showAppToast(
      context,
      message: AppLocalizations.of(context)!.deletedCourseMessage(course.name),
      kind: AppToastKind.success,
    );
  }

  Future<void> _confirmDeleteOccurrence(Course course, int sourceWeek) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDeleteOccurrenceConfirmDialog(
      context,
      title: l10n.deleteLessonTitle,
      message: l10n.deleteOccurrenceConfirmMessage(
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
    );

    if (!confirmed || !mounted) {
      return;
    }

    try {
      final changed = await context
          .read<TimetableProvider>()
          .deleteCourseOccurrence(courseId: course.id, sourceWeek: sourceWeek);
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: changed
            ? l10n.occurrenceDeletedMessage(sourceWeek)
            : l10n.noChangesDetected,
        kind: changed ? AppToastKind.success : AppToastKind.info,
      );
    } on ArgumentError catch (error) {
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: error.message != null
            ? localizeServiceMessage(l10n, error.message!)
            : AppLocalizations.of(context)!.deleteFailed,
        kind: AppToastKind.error,
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
    final scheme = provider.resolveCourseTimeScheme(course);
    final sectionTimes = scheme?.sections ?? settings.sections;

    final draft = await showCourseRescheduleSheet(
      context,
      course: course,
      sourceWeek: sourceWeek,
      settings: settings,
      weekDays: weekdayLabels,
      sectionTimes: sectionTimes,
      locationSuggestions: provider.uniqueLocations,
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
      showAppToast(
        context,
        message: changed
            ? l10n.rescheduledToMessage(
                draft.targetWeek,
                _weekdayLabel(context, draft.targetDayOfWeek),
                draft.targetStartSection,
                draft.targetEndSection,
              )
            : l10n.noChangesDetected,
        kind: changed ? AppToastKind.success : AppToastKind.info,
      );
    } on ArgumentError catch (error) {
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: error.message != null
            ? localizeServiceMessage(l10n, error.message!)
            : AppLocalizations.of(context)!.rescheduleFailed,
        kind: AppToastKind.error,
      );
    }
  }

  Widget _buildSectionTimeCell(
    int sectionNumber,
    SectionTime section,
    TimetableSettings settings,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeAxisColor = isDark
        ? settings.timeAxisFontColorDark
        : settings.timeAxisFontColorLight;
    final compactTextStyle = TextStyle(
      fontSize: (settings.compactFontSize - 2).clamp(6.0, 10.0),
      color: _colorFromHex(timeAxisColor, Colors.grey.shade600),
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
            color: _colorFromHex(timeAxisColor, Colors.grey.shade800),
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
    final provider = context.read<TimetableProvider>();
    final selected = await showProfileQuickSwitchSheet(
      context,
      profiles: provider.profiles,
      activeProfileId: provider.activeProfileId,
      onManageTimetables: (buttonContext) {
        _openPopupActionPage(
          buttonContext,
          pageBuilder: (_) => const TimetableProfilesScreen(),
          sheetRoute: ModalRoute.of(buttonContext),
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
    final selected = await showHomeTopMenuSheet(
      context,
      hasAvailableUpdate: _hasAvailableUpdate,
    );

    if (!mounted || selected == null) {
      return;
    }

    // Let the sheet route finish closing before pushing the next page.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) {
      return;
    }

    switch (selected) {
      case HomeTopMenuAction.update:
        await _openTopMenuUpdatePage();
      case HomeTopMenuAction.overview:
        await _openTopMenuPage(const CourseOverviewScreen());
      case HomeTopMenuAction.statistics:
        await _openTopMenuPage(const CourseStatisticsScreen());
      case HomeTopMenuAction.addCourse:
        await _navigateToAddCourse(context);
      case HomeTopMenuAction.exams:
        await _openTopMenuPage(const ExamListScreen());
      case HomeTopMenuAction.importCourses:
        await _openTopMenuPage(const CourseImportScreen());
      case HomeTopMenuAction.settings:
        await _openTopMenuPage(const TimetableSettingsScreen());
      case HomeTopMenuAction.support:
        await _openTopMenuPage(const SupportCreatorScreen());
    }
  }

  Future<void> _openTopMenuPage(Widget page) {
    return Navigator.of(
      context,
    ).push<void>(HyperosPageRoute<void>(builder: (_) => page));
  }

  Future<void> _openTopMenuUpdatePage() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push<void>(
      HyperosPageRoute<void>(
        builder: (_) => AboutUpdateScreen(packageInfo: packageInfo),
      ),
    );
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

  Future<void> _checkForAppUpdate({required bool includePrerelease}) async {
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
                         child: Material(color: backgroundColor, child: child),
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

  const _HomeActionPageButton({
    required this.icon,
    required this.title,
    required this.pageBuilder,
    required this.sheetRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (buttonContext) {
        return _HomeActionButtonBody(
          icon: icon,
          title: title,
          enabled: true,
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
  final bool enabled;

  const _HomeActionButtonBody({
    required this.icon,
    required this.title,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final colors = context.theme.colors;
    final highlightColor = enabled
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return HyperosFrostedSurface(
      borderRadius: HyperosTheme.cardBorderRadius,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: HyperosTheme.cardBorderRadius,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HyperosFrostedSurface(
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                  blurEnabled: false,
                  tint: HyperosBlurredHeader.accentSurfaceTintColor(
                    highlightColor,
                  ),
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: Center(child: Icon(icon, color: highlightColor)),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: enabled ? null : colors.mutedForeground,
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

class _DayAgendaItem {
  final _DayCourseDisplayItem? courseItem;
  final ScheduleItem? scheduleItem;
  final Exam? exam;
  final String startTime;
  final String endTime;
  final bool continuesFromPreviousDay;
  final bool continuesToNextDay;

  const _DayAgendaItem._({
    this.courseItem,
    this.scheduleItem,
    this.exam,
    required this.startTime,
    required this.endTime,
    this.continuesFromPreviousDay = false,
    this.continuesToNextDay = false,
  });

  factory _DayAgendaItem.course(_DayCourseDisplayItem item) {
    return _DayAgendaItem._(
      courseItem: item,
      startTime: item.course.startTime,
      endTime: item.course.endTime,
    );
  }

  factory _DayAgendaItem.schedule(
    ScheduleItem item, {
    required String startTime,
    required String endTime,
    bool continuesFromPreviousDay = false,
    bool continuesToNextDay = false,
  }) {
    return _DayAgendaItem._(
      scheduleItem: item,
      startTime: startTime,
      endTime: endTime,
      continuesFromPreviousDay: continuesFromPreviousDay,
      continuesToNextDay: continuesToNextDay,
    );
  }

  factory _DayAgendaItem.exam(Exam exam) {
    return _DayAgendaItem._(
      exam: exam,
      startTime: exam.startTime,
      endTime: exam.endTime,
    );
  }

  bool get isScheduleItem => scheduleItem != null;
  bool get isExam => exam != null;
  String get id =>
      exam?.id ?? (isScheduleItem ? scheduleItem!.id : courseItem!.course.id);
}

class _DayAgendaProgressInfo {
  final double progress;
  final int remainingMinutes;
  final String statusText;
  final Color statusBackgroundColor;
  final Color statusTextColor;
  final Color baseColor;
  final Color fillColor;

  const _DayAgendaProgressInfo({
    required this.progress,
    required this.remainingMinutes,
    required this.statusText,
    required this.statusBackgroundColor,
    required this.statusTextColor,
    required this.baseColor,
    required this.fillColor,
  });
}

class _DayAgendaPalette {
  final Color baseColor;
  final Color fillColor;
  final Color foregroundColor;

  const _DayAgendaPalette({
    required this.baseColor,
    required this.fillColor,
    required this.foregroundColor,
  });
}
