import 'dart:async';
import 'dart:io';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'dart:math' as math;

import 'package:animations/animations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show VelocityTracker, kMinFlingVelocity;
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/app_localizations_extensions.dart';
import 'package:university_timetable/l10n/service_message_localizer.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/course.dart';
import '../models/exam.dart';
import '../models/schedule_item.dart';
import '../models/liquid_glass_tuning.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable/couple_timetable_logic.dart';
import '../providers/timetable_provider.dart';
import '../services/app_update_service.dart';
import '../utils/app_toast.dart';
import '../utils/hex_color.dart';
import '../utils/course_color_palette.dart';
import '../widgets/home_page_region_blur.dart';
import '../utils/home_page_background.dart';
import '../widgets/course_action_sheet.dart';
import '../widgets/course_followup_sheets.dart';
import '../widgets/course_note_sheet.dart';
import '../widgets/course_card.dart';
import '../widgets/course_surface.dart';
import '../widgets/course_card_liquid_glass_host.dart';
import '../widgets/home_top_menu.dart';
import '../widgets/preblurred_wallpaper_glass.dart';
import '../widgets/profile_quick_switch_sheet.dart';
import '../widgets/week_selector_picker_sheet.dart';
import '../widgets/app_boot_branding.dart';
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

  /// Used for flavor-aware boot branding while [TimetableProvider.isLoading].
  final PackageInfo? packageInfo;

  const TimetableScreen({
    super.key,
    this.enableUpdateCheck = true,
    this.enableProgressTimer = true,
    this.packageInfo,
  });

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

/// Per-pointer flick probe for the day pager. One instance per finger, so
/// overlapping touches can't corrupt each other's velocity read. Besides the
/// debug logging, the probe's displacement/duration feeds the rescue velocity
/// consumed by [_DayPagerFlickRescuePhysics] when the framework tracker
/// starves (see that class for the failure mode).
class _DayPagerFlickProbe {
  _DayPagerFlickProbe(this.tracker, this.downTime, this.downPosition)
    : lastTime = downTime;

  final VelocityTracker tracker;
  final Duration downTime;
  final Offset downPosition;
  Duration lastTime;
  int samples = 1;
}

/// Day-pager snap physics with a raw-pointer fallback velocity.
///
/// Failure mode (captured in the `[DayPager]` logs): under frame jank Android
/// delivers batched touch moves once per vsync, so a 50–100ms flick can reach
/// Dart with fewer than the three samples VelocityTracker needs — the drag
/// then ends with zero velocity and the page snaps back even though the
/// finger travelled 100+px. When the incoming velocity is below the fling
/// threshold, this physics re-runs the standard PageScrollPhysics snap with
/// the probe's displacement/duration estimate instead of bouncing back.
///
/// Only effective with `pageSnapping: false`: PageView otherwise wraps its
/// own PageScrollPhysics *outside* whatever physics it is given and this
/// override would never be reached. The snap behaviour itself still comes
/// from the PageScrollPhysics superclass, so nothing else changes.
class _DayPagerFlickRescuePhysics extends PageScrollPhysics {
  const _DayPagerFlickRescuePhysics({
    required this.takeRescueVelocity,
    super.parent,
  });

  /// One-shot supplier of the scroll-space rescue velocity; 0 = none armed.
  final double Function() takeRescueVelocity;

  @override
  _DayPagerFlickRescuePhysics applyTo(ScrollPhysics? ancestor) {
    return _DayPagerFlickRescuePhysics(
      takeRescueVelocity: takeRescueVelocity,
      parent: buildParent(ancestor),
    );
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    var effectiveVelocity = velocity;
    if (velocity.abs() < kMinFlingVelocity) {
      final rescue = takeRescueVelocity();
      if (rescue != 0) {
        if (kDebugMode) {
          debugPrint(
            '[DayPager] rescue: vx=${rescue.toStringAsFixed(1)} '
            '(drag reported ${velocity.toStringAsFixed(1)})',
          );
        }
        effectiveVelocity = rescue;
      }
    }
    return super.createBallisticSimulation(position, effectiveVelocity);
  }
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
  final Set<PageController> _pendingDayViewControllerDisposals = {};
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

  /// 1 Hz heartbeat for day-view progress cards / summary while day view is
  /// open. Deliberately not a setState on this State: only the day pages
  /// rebuild on each tick.
  final ValueNotifier<int> _dayAgendaProgressTick = ValueNotifier<int>(0);

  /// Midpoint preview of the day the pager is heading to. Lets the weekday
  /// header recolour the instant onPageChanged fires, while the full selection
  /// commit still waits for ScrollEnd (_settleDayViewPage). Scoped: only the
  /// header cell row listens.
  final ValueNotifier<(int, int)?> _dayHeaderPreview =
      ValueNotifier<(int, int)?>(null);

  /// Raw-pointer fling meter for the day pager: one probe per finger,
  /// tracking the true displacement/duration the framework tracker loses
  /// when touch batching starves it (see _DayPagerFlickRescuePhysics).
  final Map<int, _DayPagerFlickProbe> _dayPagerFlickProbes =
      <int, _DayPagerFlickProbe>{};

  /// Pending scroll-space rescue velocity, armed on pointer-up and consumed
  /// once by [_dayPagerPhysics] within the same event dispatch.
  double _dayPagerRescueVelocityX = 0;
  DateTime? _dayPagerRescueArmedAt;
  late final _DayPagerFlickRescuePhysics _dayPagerPhysics =
      _DayPagerFlickRescuePhysics(
        takeRescueVelocity: _takeDayPagerRescueVelocity,
        parent: const ClampingScrollPhysics(),
      );
  int? _selectedDayOfWeek;
  int? _selectedWeekForDayView;
  int? _dayViewTransitionSourceWeek;
  int? _dayViewTransitionSourceDayOfWeek;
  double _dayViewAnchorFraction = 0.5;
  bool _isDaySwipeAnimating = false;
  bool _coupleOverlayEnabled = false;
  bool _sharedFreeSegmentsExpanded = false;
  static const int _sharedFreeVisibleSegmentLimit = 2;
  static const Duration _partnerScheduleStaleAfter = Duration(days: 7);

  /// Finger travel (after resistance) required to fire quick import.
  static const double _homePullQuickImportTriggerDistance = 120;

  /// Visual / tracked pull cap; keep above the trigger so the indicator can
  /// overshoot slightly before release.
  static const double _homePullQuickImportMaxDistance = 180;

  /// Pull-down damping so reaching the trigger needs a longer physical stroke.
  /// Collapse (negative delta) stays 1:1 so retracting the pull feels immediate.
  static const double _homePullDownResistance = 0.62;
  double _homePullDragDistance = 0;
  bool _isHomePullQuickImportRunning = false;
  VoidCallback? _homePullQuickImportCancel;
  double? _wallpaperTopLuminance;

  /// Luminance of the wallpaper band the day-view cards sit over. The top
  /// band can be dark while mid-screen is bright (or vice versa), so card ink
  /// must not reuse the chrome sample.
  double? _wallpaperBodyLuminance;
  String? _wallpaperLuminanceSamplePath;
  String? _wallpaperLuminanceRequestedPath;
  bool _wallpaperLuminanceFileExists = false;

  /// Last "custom weekday ink is unreadable" combination already warned about
  /// this session; the persisted twin lives in SharedPreferences.
  String? _weekdayInkWarnedSignature;
  bool _weekdayInkWarningShowing = false;

  bool _isCoupleOverlayActive(TimetableProvider provider) =>
      _coupleOverlayEnabled && provider.hasPartnerBinding;

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
            // Scoped tick: only the day pages listen (see _buildDayViewPanel).
            // A whole-State setState here rebuilt the entire home screen —
            // week pager included — every second while day view was open.
            _dayAgendaProgressTick.value++;
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
    _homePullQuickImportCancel?.call();
    _weekPageController.dispose();
    _dayViewExpandController.dispose();
    _visibleWeekListenable.dispose();
    _dayAgendaProgressTimer?.cancel();
    _dayAgendaProgressTick.dispose();
    _dayHeaderPreview.dispose();
    for (final controller in _dayViewPageControllers.values) {
      controller.dispose();
    }
    for (final controller in _pendingDayViewControllerDisposals) {
      controller.dispose();
    }
    _pendingDayViewControllerDisposals.clear();
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
        _scheduleWallpaperLuminanceSampleIfNeeded(settings);
        // After the sample lands: a hand-picked weekday ink can be invisible
        // over this wallpaper — never silently override it, explain instead.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _maybeWarnWeekdayInkContrast(provider, settings);
          }
        });
        final chromeForeground = _resolveHomeChromeForeground(
          hasBackdrop: hasBackdrop,
          themeForeground: foruiTheme.colors.foreground,
        );
        final chromeMutedForeground = hasBackdrop
            ? homePageChromeMutedForeground(chromeForeground)
            : foruiTheme.colors.mutedForeground;
        final headerTitleStyle = foruiTheme.typography.display.xl.copyWith(
          fontWeight: FontWeight.w400,
          height: 1.1,
          color: chromeForeground,
        );
        const headerHorizontalInset = 8.0;
        const headerTopInset = 0.0;
        final headerBottomInset = headerUsesFrostedChrome ? 0.0 : 2.0;
        final followsWeekPager =
            hasBackdrop && settings.homePageBackdropFollowsWeekPager;
        // Keep the same frosted chrome band in day view. The weekday header
        // already paints a transparent fill when blur is on; without this
        // overlay the title/weekday chrome becomes fully clear over wallpaper.
        final continuousChromeBlur = homePageHasAnyChromeBlur(
          settings,
          hasBackdrop: hasBackdrop,
        );
        // Cards fall back to a plain translucent tint when blur is off, so
        // building the pre-blurred bitmap would decode and Gaussian-blur the
        // whole wallpaper for nothing.
        final backdropBlurOn =
            hasBackdrop && HyperosBlurredHeader.backdropBlurEnabled(context);
        final cardStyle = settings.courseCardSurfaceStyle;
        // Liquid AND gaussian cards both sample the bitmap now — gaussian's
        // live BackdropFilter collapsed to transparent inside the day-view
        // open/close Opacity ramp (see CourseSurface._buildGaussian).
        final useCoursePreblur =
            backdropBlurOn &&
            (cardStyle == CourseCardSurfaceStyle.liquidGlass ||
                cardStyle == CourseCardSurfaceStyle.gaussian);
        // The day-view summary card is drawn from this same bitmap whenever
        // the chrome band has glass — regardless of the course-card style.
        // Without it the card's PreblurredWallpaperAlignedFill paints nothing
        // and the card reads as transparent (bare wash over raw wallpaper).
        final useHomePreblur =
            useCoursePreblur || (backdropBlurOn && continuousChromeBlur);
        final homePreblurSigma = (() {
          final appearance = FrostedAppearanceScope.of(context);
          // Gaussian cards are the dominant consumer when active: give them
          // the exact sigma their live BackdropFilter would have used.
          if (backdropBlurOn && cardStyle == CourseCardSurfaceStyle.gaussian) {
            return HyperosBlurredHeader.blurSigmaOf(context);
          }
          if (useCoursePreblur ||
              appearance.glassMode == FrostedGlassMode.liquidGlass) {
            return ((appearance.liquidGlassTuning ?? LiquidGlassTuning.defaults).blur * 0.45).clamp(2.0, 8.0);
          }
          // Gaussian chrome: match the band's BackdropFilter sigma so the
          // summary card's stand-in frost reads like the band above it.
          return HyperosBlurredHeader.blurSigmaOf(context);
        })();
        Widget homeStack = Stack(
          fit: StackFit.expand,
          children: [
            if (hasBackdrop)
              followsWeekPager
                  ? HomePageSlidingBackdropLayer(
                      controller: _weekPageController,
                      pageCount: settings.semesterWeekCount,
                      settings: settings,
                      isDark: isDark,
                    )
                  : homePageBackdropLayer(settings: settings, isDark: isDark),
            if (hasBackdrop && !statusBarShowsBackdrop)
              HomePageStatusBarBackdropMask(color: pageBackgroundColor),
            // Single continuous glass for title + weekday (no time-column blur).
            // Stays fixed above the sliding wallpaper so chrome text stays sharp
            // while the photo moves as one continuous sheet.
            if (continuousChromeBlur)
              HomePageContinuousChromeFrostedOverlay(
                headerBlurEnabled: settings.homePageHeaderBlurEnabled,
                weekdayBarBlurEnabled: settings.homePageWeekdayBarBlurEnabled,
                includeStatusBar: statusBarShowsBackdrop,
                weekdayBarHeight: _weekDayHeaderHeight,
                wallpaperTopLuminance: _wallpaperTopLuminance,
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
                actionStyle: FHeaderActionStyleDelta.delta(
                  iconStyle: FVariantsDelta.delta([
                    FVariantOperation.all(
                      IconThemeDataDelta.delta(color: chromeForeground),
                    ),
                  ]),
                ),
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
              title: _buildProfileSwitcherTrigger(
                provider,
                foreground: chromeForeground,
                mutedForeground: chromeMutedForeground,
              ),
              suffixes: [
                if (provider.hasPartnerBinding)
                  FHeaderAction(
                    icon: Icon(
                      _isCoupleOverlayActive(provider)
                          ? Icons.favorite_rounded
                          : Icons.favorite_outline_rounded,
                      color: _isCoupleOverlayActive(provider)
                          ? const Color(0xFFE91E63)
                          : chromeForeground,
                    ),
                    semanticsLabel: _isCoupleOverlayActive(provider)
                        ? l10n.coupleTimetableModeDisableTooltip
                        : l10n.coupleTimetableModeEnableTooltip,
                    onPress: () {
                      setState(() {
                        _coupleOverlayEnabled = !_coupleOverlayEnabled;
                        _sharedFreeSegmentsExpanded = false;
                      });
                      _persistCoupleOverlayEnabled(
                        provider,
                        enabled: _coupleOverlayEnabled,
                      );
                    },
                  ),
                FHeaderAction(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(Icons.more_vert_rounded, color: chromeForeground),
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
                    ? ColoredBox(
                        color: AppBootBranding.backgroundColor(isDark: isDark),
                        child: AppBootBranding(
                          appLabel: widget.packageInfo != null
                              ? AppBootBranding.resolveAppLabel(
                                  widget.packageInfo!,
                                  l10n,
                                )
                              : l10n.appTitle,
                          isDark: isDark,
                        ),
                      )
                    : MediaQuery.removeViewInsets(
                        context: context,
                        removeBottom: true,
                        child: Stack(
                          children: [
                            _buildHomePullQuickImportSurface(
                              provider: provider,
                              settings: settings,
                              hasBackdrop: hasBackdrop,
                            ),
                            if (_isHomePullQuickImportRunning ||
                                _homePullDragDistance > 0)
                              _buildHomePullQuickImportIndicator(l10n),
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
        if (useHomePreblur) {
          // Same pre-blur model as the week grid: sample one cached frost
          // bitmap by card screen position. In day view the week pager is
          // locked, so drive repaints from the day agenda pager and treat the
          // wallpaper as screen-fixed (it never follows the day swipe).
          final PageController preblurPageController;
          final bool preblurFollowsPager;
          if (_isDayView) {
            final dayViewWeek = _selectedWeekForDayView ?? provider.currentWeek;
            preblurPageController = _ensureDayViewPageController(
              settings,
              dayViewWeek,
            );
            preblurFollowsPager = false;
          } else {
            preblurPageController = _weekPageController;
            preblurFollowsPager = followsWeekPager;
          }
          return PreblurredWallpaperScope(
            wallpaperPath: resolveHomePageBackdropImagePath(settings),
            blurSigma: homePreblurSigma,
            pageController: preblurPageController,
            followsPager: preblurFollowsPager,
            // The open/close ramp drags cards around without any scrolling;
            // fills must re-sample per frame or the frost rides along frozen.
            repaint: _dayViewExpandController,
            enabled: true,
            child: homeStack,
          );
        }
        return homeStack;
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
    // Keep old controllers alive through the replacement frame. AnimatedBuilder
    // detaches from the old PageController during that rebuild; disposing at
    // the first post-frame callback is still early enough to race didUpdateWidget.
    final oldControllers = _dayViewPageControllers.values.toList();
    _dayViewPageControllers.clear();
    for (final controller in oldControllers) {
      _disposeDayViewControllerAfterReplacement(controller);
    }
    if (settings.timetableHomeViewMode == TimetableHomeViewMode.day) {
      _selectedWeekForDayView = _visibleWeek;
      _selectedDayOfWeek = restoredDayOfWeek;
      _dayViewExpandController.value = 1;
    } else {
      _selectedWeekForDayView = null;
      _selectedDayOfWeek = null;
      _dayViewExpandController.value = 0;
    }
    _coupleOverlayEnabled = settings.coupleTimetableOverlayEnabled;
    _sharedFreeSegmentsExpanded = false;
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
    // Lightweight path: no notifyListeners / live-activity churn. The old
    // updateTimetableSettings route re-broadcast the whole provider on every
    // day switch, rebuilding the home screen a second time mid-animation.
    unawaited(
      provider.persistHomeViewState(mode: mode, dayOfWeek: resolvedDayOfWeek),
    );
  }

  void _persistCoupleOverlayEnabled(
    TimetableProvider provider, {
    required bool enabled,
  }) {
    if (provider.settings.coupleTimetableOverlayEnabled == enabled) {
      return;
    }
    unawaited(
      provider.updateTimetableSettings(
        provider.settings.copyWith(coupleTimetableOverlayEnabled: enabled),
      ),
    );
  }

  bool _isSelectedDay(int week, int dayOfWeek) {
    if (!_isDayView) {
      return false;
    }
    // Mid-swipe the preview leads the committed selection so the header
    // highlight flips at the pager midpoint, not after the spring settles.
    final preview = _dayHeaderPreview.value;
    if (preview != null) {
      return preview.$1 == week && preview.$2 == dayOfWeek;
    }
    return _selectedWeekForDayView == week && _selectedDayOfWeek == dayOfWeek;
  }

  /// Opaque chrome for day-view layers over wallpaper-backed week chrome.
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
    // Collapse the expand controller *before* the overlay mounts so the first
    // painted frame is the small/transparent state. Otherwise a leftover value
    // of 1 (restore / interrupted close / hot reload) makes open look like a
    // hard cut, while close still has a visible reverse animation.
    if (shouldAnimateOpen) {
      _dayViewExpandController.value = 0;
    }
    _dayHeaderPreview.value = null;
    setState(() {
      _selectedWeekForDayView = normalizedWeek;
      _selectedDayOfWeek = dayOfWeek;
      _sharedFreeSegmentsExpanded = false;
    });
    _persistViewState(
      context.read<TimetableProvider>(),
      mode: TimetableHomeViewMode.day,
      dayOfWeek: dayOfWeek,
    );
    _maybeSelectionClick(settings);
    if (shouldAnimateOpen) {
      // Start open animation without awaiting completion (close still awaits
      // reverse). Controller was reset to 0 above so the first frame is small.
      unawaited(_dayViewExpandController.forward());
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
    _dayHeaderPreview.value = null;
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

  void _disposeDayViewControllerAfterReplacement(PageController controller) {
    if (!_pendingDayViewControllerDisposals.add(controller)) {
      return;
    }

    // Two post-frame hops allow the replacement widget tree to build and let
    // AnimatedBuilder detach its listener before the controller is disposed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        if (_pendingDayViewControllerDisposals.remove(controller)) {
          controller.dispose();
        }
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pendingDayViewControllerDisposals.remove(controller)) {
          controller.dispose();
        }
      });
      WidgetsBinding.instance.scheduleFrame();
    });
    WidgetsBinding.instance.scheduleFrame();
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
      _disposeDayViewControllerAfterReplacement(existing);
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

    _disposeDayViewControllerAfterReplacement(existing);
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
    // A live drag / fling owns the pager: selection commit is deferred to
    // ScrollEnd, so a mid-gesture rebuild would read the stale selection here
    // and jumpToPage would yank the fling back to the old page.
    if (controller.position.isScrollingNotifier.value) {
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
    _dayHeaderPreview.value = null;
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
      _dayHeaderPreview.value = null;
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
      if (kDebugMode) {
        debugPrint(
          '[DayPager] pageChanged($page) ignored: '
          'syncing=$_isSyncingDayViewPage animating=$_isDaySwipeAnimating',
        );
      }
      return;
    }
    final target = _dayViewTargetForPage(settings, week, page);
    if (kDebugMode) {
      debugPrint(
        '[DayPager] pageChanged($page) -> week=${target.week} '
        'day=${target.dayOfWeek} boundary=${target.isBoundaryTransition}',
      );
    }
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
    // Midpoint preview: recolour the weekday header the moment the pager
    // crosses a page midpoint (matching the indicator), via the scoped
    // notifier — no full-State rebuild while the fling is still running.
    _dayHeaderPreview.value = (target.week, target.dayOfWeek);
    if (_selectedWeekForDayView == target.week &&
        _selectedDayOfWeek == target.dayOfWeek) {
      return;
    }
    // onPageChanged fires mid-fling (page midpoint crossing). Committing state
    // here rebuilt the whole home screen + persisted settings while the pager
    // was still animating — that was the ~50-frame hitch on every day switch.
    // Same model as the week pager: haptic now, commit on ScrollEnd
    // (_settleDayViewPage).
    _maybeSelectionClick(settings);
  }

  /// Commits the settled day-pager page once the horizontal scroll has fully
  /// stopped, mirroring the week pager's ScrollEnd → finalize model so the
  /// setState + persist never land mid-animation.
  void _settleDayViewPage(
    TimetableProvider provider,
    TimetableSettings settings,
    int week,
  ) {
    if (_isSyncingDayViewPage || _isDaySwipeAnimating) {
      if (kDebugMode) {
        debugPrint(
          '[DayPager] settle skipped: syncing=$_isSyncingDayViewPage '
          'animating=$_isDaySwipeAnimating',
        );
      }
      return;
    }
    final controller = _dayViewPageControllers[week];
    if (controller == null || !controller.hasClients) {
      return;
    }
    final page = controller.page?.round();
    if (page == null) {
      return;
    }
    final target = _dayViewTargetForPage(settings, week, page);
    if (kDebugMode) {
      debugPrint(
        '[DayPager] settle: rawPage=${controller.page?.toStringAsFixed(3)} '
        '-> page=$page week=${target.week} day=${target.dayOfWeek} '
        'boundary=${target.isBoundaryTransition} '
        'alreadySelected=${_selectedWeekForDayView == target.week && _selectedDayOfWeek == target.dayOfWeek}',
      );
    }
    if (target.isBoundaryTransition) {
      // Cross-week landing is owned by _animateDayViewToWeek (onPageChanged).
      return;
    }
    _dayHeaderPreview.value = null;
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
  }

  /// One-shot read of the armed rescue velocity for [_dayPagerPhysics].
  /// Freshness-gated so a stale value can never leak into an unrelated
  /// ballistic (the drag consumes it within the same event dispatch).
  double _takeDayPagerRescueVelocity() {
    final armedAt = _dayPagerRescueArmedAt;
    final vx = _dayPagerRescueVelocityX;
    _dayPagerRescueVelocityX = 0;
    _dayPagerRescueArmedAt = null;
    if (armedAt == null ||
        DateTime.now().difference(armedAt) > const Duration(milliseconds: 90)) {
      return 0;
    }
    return vx;
  }

  /// Schedules wallpaper top-band luminance sampling without sync I/O in build.
  ///
  /// File existence is checked asynchronously; results are cached per path so
  /// rebuilds only re-sample when the backdrop path changes.
  ///
  /// Runs in **both** themes: a light wallpaper under a dark theme needs dark
  /// ink just as much as a dark wallpaper under a light theme does. Gating this
  /// on `isDark` left white-on-white chrome text on light wallpapers.
  void _scheduleWallpaperLuminanceSampleIfNeeded(TimetableSettings settings) {
    final path = resolveHomePageBackdropImagePath(settings);
    if (path == null || path.isEmpty) {
      if (_wallpaperTopLuminance != null ||
          _wallpaperLuminanceSamplePath != null ||
          _wallpaperLuminanceRequestedPath != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          setState(() {
            _wallpaperTopLuminance = null;
            _wallpaperBodyLuminance = null;
            _wallpaperLuminanceSamplePath = null;
            _wallpaperLuminanceRequestedPath = null;
            _wallpaperLuminanceFileExists = false;
          });
        });
      }
      return;
    }
    // Same path already requested: either missing file or sample finished/in-flight.
    if (_wallpaperLuminanceRequestedPath == path &&
        (_wallpaperLuminanceSamplePath == path ||
            !_wallpaperLuminanceFileExists)) {
      return;
    }
    unawaited(_ensureWallpaperLuminanceForPath(path));
  }

  Future<void> _ensureWallpaperLuminanceForPath(String path) async {
    if (_wallpaperLuminanceRequestedPath == path &&
        _wallpaperLuminanceSamplePath == path &&
        _wallpaperTopLuminance != null) {
      return;
    }
    _wallpaperLuminanceRequestedPath = path;
    final fileExists = await File(path).exists();
    if (!mounted || _wallpaperLuminanceRequestedPath != path) {
      return;
    }
    if (!fileExists) {
      if (_wallpaperTopLuminance != null ||
          _wallpaperLuminanceSamplePath != null ||
          _wallpaperLuminanceFileExists) {
        setState(() {
          _wallpaperTopLuminance = null;
          _wallpaperBodyLuminance = null;
          _wallpaperLuminanceSamplePath = null;
          _wallpaperLuminanceFileExists = false;
        });
      }
      return;
    }
    _wallpaperLuminanceFileExists = true;
    _wallpaperLuminanceSamplePath = path;
    await _loadWallpaperTopLuminance(path);
  }

  Future<void> _loadWallpaperTopLuminance(String path) async {
    final bands = await sampleHomePageWallpaperLuminanceBands(path);
    if (!mounted || _wallpaperLuminanceSamplePath != path) {
      return;
    }
    if (_wallpaperTopLuminance == bands?.top &&
        _wallpaperBodyLuminance == bands?.body) {
      return;
    }
    setState(() {
      _wallpaperTopLuminance = bands?.top;
      _wallpaperBodyLuminance = bands?.body;
    });
  }

  /// One-shot heads-up when a hand-picked weekday-bar ink has too little
  /// contrast against the current wallpaper. Custom colours are respected by
  /// design (never auto-flipped), so without this the user only sees the ink
  /// vanish and has no idea why. Offers restoring the default (auto B/W).
  void _maybeWarnWeekdayInkContrast(
    TimetableProvider provider,
    TimetableSettings settings,
  ) {
    final luminance = _wallpaperTopLuminance;
    if (luminance == null || _weekdayInkWarningShowing) {
      return;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!hasHomePageBackdropImage(settings, isDark: isDark)) {
      return;
    }
    final configuredHex = isDark
        ? settings.weekdayBarFontColorDark
        : settings.weekdayBarFontColorLight;
    final defaultHex = isDark
        ? TimetableSettings.defaultWeekdayBarFontColorDark
        : TimetableSettings.defaultWeekdayBarFontColorLight;
    // Default ink already auto-flips with the wallpaper; only a custom pick
    // can go invisible.
    if (homePageInkUsesBuiltInDefault(configuredHex, defaultHex)) {
      return;
    }
    final ink = tryParseHexColor(configuredHex);
    if (ink == null) {
      return;
    }
    final inkLuminance = ink.computeLuminance();
    final hi = math.max(inkLuminance, luminance);
    final lo = math.min(inkLuminance, luminance);
    // ~WCAG ratio against the sampled top band; photos are busy, so anything
    // above 3:1 is left alone — this only catches "nearly invisible".
    if ((hi + 0.05) / (lo + 0.05) >= 3.0) {
      return;
    }
    final signature =
        '$configuredHex|${resolveHomePageBackdropImagePath(settings) ?? ''}|'
        '$isDark';
    if (_weekdayInkWarnedSignature == signature) {
      return;
    }
    _weekdayInkWarnedSignature = signature;
    unawaited(
      _showWeekdayInkContrastDialog(
        provider: provider,
        signature: signature,
        wallpaperIsDark: luminance < 0.45,
        isDarkTheme: isDark,
        defaultHex: defaultHex,
      ),
    );
  }

  Future<void> _showWeekdayInkContrastDialog({
    required TimetableProvider provider,
    required String signature,
    required bool wallpaperIsDark,
    required bool isDarkTheme,
    required String defaultHex,
  }) async {
    const prefsKey = 'weekday_ink_contrast_warned_signature';
    final prefs = await SharedPreferences.getInstance();
    // Same colour + wallpaper + theme was already explained once (persisted):
    // the user chose to keep it, so do not nag on every launch.
    if (prefs.getString(prefsKey) == signature) {
      return;
    }
    if (!mounted || _weekdayInkWarningShowing) {
      return;
    }
    _weekdayInkWarningShowing = true;
    await prefs.setString(prefsKey, signature);
    if (!mounted) {
      _weekdayInkWarningShowing = false;
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    try {
      await showHyperosDialog<void>(
        context: context,
        title: l10n.weekdayInkContrastTitle,
        body: Text(
          wallpaperIsDark
              ? l10n.weekdayInkContrastBodyDark
              : l10n.weekdayInkContrastBodyLight,
        ),
        actions: [
          HyperosDialogAction(
            label: l10n.keepCurrentColorAction,
            onPressed: () => Navigator.pop(context),
          ),
          HyperosDialogAction(
            label: l10n.resetDefaultAction,
            isPrimary: true,
            onPressed: () {
              // Re-read the live settings: they may have changed while the
              // dialog was up, and only this one field should be touched.
              final current = provider.settings;
              unawaited(
                provider.updateSettings(
                  isDarkTheme
                      ? current.copyWith(weekdayBarFontColorDark: defaultHex)
                      : current.copyWith(weekdayBarFontColorLight: defaultHex),
                ),
              );
              Navigator.pop(context);
            },
          ),
        ],
      );
    } finally {
      _weekdayInkWarningShowing = false;
    }
  }

  Color _resolveHomeChromeForeground({
    required bool hasBackdrop,
    required Color themeForeground,
  }) {
    if (!hasBackdrop) {
      return themeForeground;
    }
    return homePageChromeForegroundForLuminance(
      _wallpaperTopLuminance,
      fallback: themeForeground,
    );
  }

  Widget _buildProfileSwitcherTrigger(
    TimetableProvider provider, {
    required Color foreground,
    required Color mutedForeground,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: _homeTitleHorizontalNudge),
      child: switch (provider.settings.homeTitleStyle) {
        HomeTitleStyle.classic => _buildClassicProfileSwitcherTrigger(
          provider,
          foreground: foreground,
        ),
        HomeTitleStyle.brand => _buildBrandProfileSwitcherTrigger(
          provider,
          foreground: foreground,
          mutedForeground: mutedForeground,
        ),
      },
    );
  }

  Widget _buildClassicProfileSwitcherTrigger(
    TimetableProvider provider, {
    required Color foreground,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final foruiTheme = context.theme;
    return GestureDetector(
      key: const ValueKey('profile_switcher_trigger'),
      onTap: _showProfileQuickSwitchSheet,
      behavior: HitTestBehavior.opaque,
      child: Text(
        l10n.timetableAppName,
        style: foruiTheme.typography.display.xl.copyWith(
          fontWeight: FontWeight.w400,
          height: 1.1,
          color: foreground,
        ),
      ),
    );
  }

  Widget _buildBrandProfileSwitcherTrigger(
    TimetableProvider provider, {
    required Color foreground,
    required Color mutedForeground,
  }) {
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
              color: foreground,
            ),
          ),
          Text(
            (activeProfileName == null || activeProfileName.isEmpty)
                ? l10n.switchProfileHint
                : activeProfileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: foruiTheme.typography.body.sm.copyWith(
              color: mutedForeground,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasBackdrop = hasHomePageBackdropImage(settings, isDark: isDark);
    // Week label sits in the weekday chrome band: auto-invert default black/white
    // over a dark wallpaper (same rule as the title logo), keep user custom ink.
    final weekLabelColor = homePageOverWallpaperInk(
      configuredHex: isDark
          ? settings.weekdayBarFontColorDark
          : settings.weekdayBarFontColorLight,
      defaultHex: isDark
          ? TimetableSettings.defaultWeekdayBarFontColorDark
          : TimetableSettings.defaultWeekdayBarFontColorLight,
      themeFallback: colorScheme.onSurface,
      hasBackdrop: hasBackdrop,
      wallpaperLuminance: _wallpaperTopLuminance,
    );
    final weekLabelMutedColor = homePageOverWallpaperMutedInk(weekLabelColor);
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
                    // 时间列偏窄，略向右让周次与节次数字视觉中心对齐。
                    padding: const EdgeInsets.fromLTRB(8, 2, 2, 2),
                    child: Text(
                      l10n.currentWeekCompact(week),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: weekLabelColor,
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
                              color: weekLabelMutedColor,
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
                // Rebuilds on the midpoint preview so the selected-day text
                // recolours mid-swipe without a full-State setState.
                ListenableBuilder(
                  listenable: _dayHeaderPreview,
                  builder: (context, _) => Row(
                    children: visibleDays
                        .map((dayOfWeek) {
                          final date = _dateForWeekDay(
                            settings,
                            week,
                            dayOfWeek,
                          );
                          final isToday =
                              date != null && _isSameDate(date, DateTime.now());
                          final isSelected = _isSelectedDay(week, dayOfWeek);
                          final configuredWeekdayHex = isDark
                              ? settings.weekdayBarFontColorDark
                              : settings.weekdayBarFontColorLight;
                          final configuredAccentHex = isDark
                              ? settings.weekdayBarAccentColorDark
                              : settings.weekdayBarAccentColorLight;
                          // Default weekday ink flips with wallpaper luminance;
                          // user-custom hex is kept. Accent (today/selected) is
                          // never auto-inverted so a custom blue stays blue.
                          final weekdayColor = homePageOverWallpaperInk(
                            configuredHex: configuredWeekdayHex,
                            defaultHex: isDark
                                ? TimetableSettings
                                      .defaultWeekdayBarFontColorDark
                                : TimetableSettings
                                      .defaultWeekdayBarFontColorLight,
                            themeFallback: colorScheme.onSurface,
                            hasBackdrop: hasBackdrop,
                            wallpaperLuminance: _wallpaperTopLuminance,
                          );
                          final accentColor = homePageOverWallpaperAccent(
                            configuredHex: configuredAccentHex,
                            themeFallback: colorScheme.primary,
                          );
                          final labelColor = (isSelected || isToday)
                              ? accentColor
                              : weekdayColor;
                          final subLabelColor = (isSelected || isToday)
                              ? accentColor.withValues(
                                  alpha: isSelected ? 0.9 : 0.78,
                                )
                              : homePageOverWallpaperMutedInk(weekdayColor);
                          final showsTodayMarker = isToday && !isSelected;

                          return Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                key: ValueKey(
                                  'weekday-header-$week-$dayOfWeek',
                                ),
                                borderRadius: BorderRadius.circular(14),
                                onTapDown: (details) => _captureDayViewAnchor(
                                  details.globalPosition,
                                ),
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
                                            ? accentColor.withValues(
                                                alpha: 0.35,
                                              )
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
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectionAccent = homePageOverWallpaperAccent(
      configuredHex: isDark
          ? settings.weekdayBarAccentColorDark
          : settings.weekdayBarAccentColorLight,
      themeFallback: colorScheme.primary,
    );

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
                        // Match weekday accent (custom blue etc.), not raw primary.
                        color: selectionAccent,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: selectionAccent.withValues(alpha: 0.18),
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
    return SizedBox(
      key: ValueKey<int>(week),
      width: availableWidth,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: timeColumnWidth,
            // Chrome blur is painted by HomePageContinuousChromeFrostedOverlay.
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
          _wrapCourseGridLiquidGlassHost(
            settings: settings,
            child: Row(
              children: visibleDays.asMap().entries.map((entry) {
                final dayIndex = entry.key;
                final dayOfWeek = entry.value;
                final dayCourses = _getCoursesForDay(
                  provider.courses,
                  week,
                  dayOfWeek,
                  settings,
                );
                final displayItems = _buildHomeDayDisplayItems(
                  provider: provider,
                  settings: settings,
                  week: week,
                  dayOfWeek: dayOfWeek,
                  myCourses: dayCourses,
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
          ),
        ],
      ),
    );
  }

  Widget _buildHomePullQuickImportSurface({
    required TimetableProvider provider,
    required TimetableSettings settings,
    required bool hasBackdrop,
  }) {
    // Home timetable only: no HyperOS rubber-band. Other pages keep
    // [HyperosScrollBehavior] from [HyperosRootPage].
    Widget surface = ScrollConfiguration(
      behavior: const _TimetableHomeScrollBehavior(),
      child: Padding(
        key: _timetableSurfaceKey,
        padding: EdgeInsets.only(bottom: hasBackdrop ? 0 : 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return _buildWeekPager(
              provider,
              settings,
              constraints.maxWidth,
              constraints.maxHeight,
            );
          },
        ),
      ),
    );

    if (!settings.homePullQuickImportEnabled) {
      return surface;
    }

    // Prefer scroll overscroll (clamping) so left/right week paging stays free.
    surface = NotificationListener<ScrollNotification>(
      onNotification: _handleHomePullScrollNotification,
      child: surface,
    );

    // Auto-fit week grid has no vertical Scrollable; use a vertical-only drag
    // that does not claim the arena until the gesture is clearly vertical.
    if (settings.timetableAutoFitSectionHeight && !_isDayView) {
      surface = _HomePullVerticalDragDetector(
        enabled: !_isHomePullQuickImportRunning,
        onPullUpdate: _updateHomePullDragDistance,
        onPullEnd: _finishHomePullDrag,
        onPullCancel: _cancelHomePullDrag,
        child: surface,
      );
    }

    return surface;
  }

  Widget _buildHomePullQuickImportIndicator(AppLocalizations l10n) {
    final pullProgress =
        (_homePullDragDistance / _homePullQuickImportTriggerDistance).clamp(
          0.0,
          1.0,
        );
    final showLabel =
        _isHomePullQuickImportRunning ||
        _homePullDragDistance >= _homePullQuickImportTriggerDistance * 0.55;
    // Sit just under the weekday (Mon–Sun) row so the bar is not covered.
    const indicatorTopInset = _weekDayHeaderHeight + 8;
    return Positioned(
      top: indicatorTopInset,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: _isHomePullQuickImportRunning
              ? 1
              : (0.35 + pullProgress * 0.65),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    value: _isHomePullQuickImportRunning
                        ? null
                        : math.max(pullProgress, 0.08),
                  ),
                ),
                if (showLabel) ...[
                  const SizedBox(width: 10),
                  Text(
                    l10n.homePullQuickImportFetchingCourses,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                if (_isHomePullQuickImportRunning) ...[
                  const SizedBox(width: 8),
                  Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _cancelHomePullQuickImport,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          l10n.quickImportCancelImportAction,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _updateHomePullDragDistance(double deltaDy) {
    if (_isHomePullQuickImportRunning) {
      return;
    }
    if (deltaDy <= 0 && _homePullDragDistance <= 0) {
      return;
    }
    // Stretch on the way down; collapse without damping so upward motion first
    // puts away the pull UI instead of scrolling the timetable.
    final adjustedDelta = deltaDy > 0
        ? deltaDy * _homePullDownResistance
        : deltaDy;
    final nextDistance = (_homePullDragDistance + adjustedDelta).clamp(
      0.0,
      _homePullQuickImportMaxDistance,
    );
    if (nextDistance == _homePullDragDistance) {
      return;
    }
    setState(() {
      _homePullDragDistance = nextDistance;
    });
  }

  void _finishHomePullDrag() {
    final shouldTrigger =
        _homePullDragDistance >= _homePullQuickImportTriggerDistance;
    if (_homePullDragDistance != 0) {
      setState(() {
        _homePullDragDistance = 0;
      });
    }
    if (shouldTrigger) {
      unawaited(_runHomePullQuickImport());
    }
  }

  void _cancelHomePullDrag() {
    if (_homePullDragDistance == 0) {
      return;
    }
    setState(() {
      _homePullDragDistance = 0;
    });
  }

  /// Clamping overscroll at the top of the week/day vertical scrollables.
  bool _handleHomePullScrollNotification(ScrollNotification notification) {
    if (_isHomePullQuickImportRunning) {
      return false;
    }
    final metrics = notification.metrics;
    if (metrics.axis != Axis.vertical) {
      return false;
    }

    final atTop = metrics.pixels <= metrics.minScrollExtent + 0.5;

    // While the pull affordance is open, upward content scroll retracts it.
    //
    // Deliberately does *not* try to undo the scroll: `ScrollPosition.correctBy`
    // is only valid from the layout pass (`applyContentDimensions`), and calling
    // it from a notification callback trips assertions / causes scroll jitter.
    // Letting the list scroll while the indicator retracts is the safe
    // behaviour, and visually reads the same on device.
    if (_homePullDragDistance > 0 && notification is ScrollUpdateNotification) {
      final scrollDelta = notification.scrollDelta ?? 0.0;
      if (scrollDelta > 0) {
        _updateHomePullDragDistance(-scrollDelta);
        return false;
      }
    }

    if (notification is OverscrollNotification && atTop) {
      // Negative overscroll = past the leading edge (top) while pulling down.
      if (notification.overscroll < 0) {
        _updateHomePullDragDistance(-notification.overscroll);
      } else if (notification.overscroll > 0 && _homePullDragDistance > 0) {
        // Positive overscroll at top while pull is open: treat as retract.
        _updateHomePullDragDistance(-notification.overscroll);
      }
      return false;
    }

    if (notification is ScrollEndNotification && _homePullDragDistance > 0) {
      _finishHomePullDrag();
      return false;
    }

    return false;
  }

  void _cancelHomePullQuickImport() {
    final cancel = _homePullQuickImportCancel;
    if (cancel == null) {
      return;
    }
    cancel();
    if (mounted) {
      setState(() {
        _isHomePullQuickImportRunning = false;
        _homePullQuickImportCancel = null;
      });
    }
  }

  Future<void> _runHomePullQuickImport() async {
    if (_isHomePullQuickImportRunning || !mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isHomePullQuickImportRunning = true;
      _homePullDragDistance = 0;
      _homePullQuickImportCancel = null;
    });
    try {
      await runHomePullWarehouseQuickImport(
        context,
        onNeedsManualAction: () {
          if (!mounted) {
            return;
          }
          showAppLightTip(
            context,
            message: l10n.homePullQuickImportNeedsManualAction,
          );
        },
        onCancelAvailable: (cancel) {
          if (!mounted) {
            return;
          }
          setState(() {
            _homePullQuickImportCancel = cancel;
          });
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _isHomePullQuickImportRunning = false;
          _homePullQuickImportCancel = null;
        });
      }
    }
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
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollEndNotification &&
                notification.metrics.axis == Axis.horizontal) {
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
                // Lets card glass fills align to the wallpaper instance that
                // slides with this page (see PreblurredWallpaperAlignedFill).
                child: PreblurredWallpaperPage(
                  pageIndex: index,
                  child: _buildWeekPage(
                    provider,
                    settings,
                    availableWidth,
                    availableHeight,
                    week,
                  ),
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
        // Swipeable weekday bar: when day view is open, horizontal drags on
        // the weekday bar area switch the day view to the prev/next week.
        if (_shouldShowDayViewOverlay && visibleDayViewWeek != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _weekDayHeaderHeight,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity;
                if (velocity == null || velocity == 0) return;
                final direction = velocity < 0 ? 1 : -1;
                final currentWeek = visibleDayViewWeek;
                final targetWeek = (currentWeek + direction).clamp(
                  1,
                  settings.semesterWeekCount,
                );
                if (targetWeek == currentWeek) return;
                _animateDayViewToWeek(
                  provider,
                  settings,
                  targetWeek,
                  _displayedDayForWeek(targetWeek),
                );
              },
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasBackdrop = hasHomePageBackdropImage(settings, isDark: isDark);
    // Day view keeps the same weekday chrome as the week view: the panel below
    // now shows the wallpaper, so an opaque non-blurred bar would read as a
    // seam across the top of the glass.
    final weekdayChromeBlurEnabled =
        hasBackdrop && settings.homePageWeekdayBarBlurEnabled;
    final chromeGridClearance = weekdayChromeBlurEnabled
        ? homePageFrostedRegionSeamOverlap
        : 0.0;
    final bodyAvailableHeight =
        (availableHeight - _weekDayHeaderHeight - chromeGridClearance).clamp(
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
    final weekdayShowsBackdrop = homePageRegionShowsBackdrop(
      settings,
      HomePageBackgroundScope.weekdayBar,
      isDark: isDark,
    );
    final timeColumnWidth = _resolveTimeColumnWidth(settings);
    final pageChromeFallback = Theme.of(context).colorScheme.surface;
    final weekdayHeader = homePageBackgroundLayer(
      visual: homePageRegionChromeVisual(
        settings: settings,
        isDark: isDark,
        darkFallback: pageChromeFallback,
        region: HomePageBackgroundScope.weekdayBar,
        chromeBlurEnabled: weekdayChromeBlurEnabled,
      ),
      child: _buildWeekDayHeader(
        provider,
        week,
        settings,
        timeColumnWidth,
        hideBottomBorder: weekdayShowsBackdrop || weekdayChromeBlurEnabled,
      ),
    );

    return KeyedSubtree(
      key: ValueKey('week-page-$week'),
      child: Column(
        children: [
          weekdayHeader,
          // Original chrome↔grid clearance (same token as frosted seam overlap).
          // Keeps liquid/gaussian glass from sitting flush on the first course row.
          if (weekdayChromeBlurEnabled)
            const SizedBox(height: homePageFrostedRegionSeamOverlap),
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
            // Explicit clamp: do not inherit HyperOS rubber-band here.
            physics: const ClampingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            child: grid,
          );
    // Drive opacity from the expand controller so open and close share the
    // same curve. A boolean AnimatedOpacity snaps the grid away on open while
    // the panel still grows, which reads as "open has no transition".
    return AnimatedBuilder(
      animation: _dayViewExpandController,
      child: weekGrid,
      builder: (context, child) {
        final gridOpacity = (1.0 - _dayViewExpandController.value).clamp(
          0.0,
          1.0,
        );
        return IgnorePointer(
          ignoring: gridOpacity < 0.02,
          child: Opacity(
            // At 0 RenderOpacity skips painting the subtree, so day-view glass
            // samples wallpaper instead of a ghost grid.
            opacity: gridOpacity,
            child: child,
          ),
        );
      },
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
          // Block only while the shell is still a tiny seed (open start / close
          // end). Waiting for 0.98 left the close button unhittable for most of
          // the open animation and flaky under widget-test pumps.
          ignoring: progress < 0.05,
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
    // Not forced opaque: the panel shows the wallpaper exactly like a week page
    // does, so glass / frosted agenda cards have real content to sample. The
    // week grid underneath is faded to 0 while the day view is up
    // (see _buildWeekPageBody), so nothing shows through but the wallpaper.
    // With no wallpaper this resolver already returns an opaque colour.
    final backgroundVisual = resolveHomePageRegionBackground(
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
                // Same as week grid: default PageView.builder keeps per-page
                // RepaintBoundary so horizontal swipes composite cheaply.
                // Pre-blur fills still repaint via pager markNeedsPaint.
                child: Listener(
                  // Raw-pointer fling meter + rescue arming. Touch batching
                  // under jank starves the framework's VelocityTracker (2–5
                  // samples per 50–100ms flick → zero velocity → snap-back);
                  // the probes keep the true displacement/duration so
                  // _dayPagerPhysics can redo the snap with it.
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (event) {
                    // A new touch invalidates any leftover rescue velocity.
                    _dayPagerRescueVelocityX = 0;
                    _dayPagerRescueArmedAt = null;
                    _dayPagerFlickProbes[event.pointer] = _DayPagerFlickProbe(
                      VelocityTracker.withKind(event.kind)
                        ..addPosition(event.timeStamp, event.position),
                      event.timeStamp,
                      event.position,
                    );
                    if (kDebugMode && _dayPagerFlickProbes.length > 1) {
                      debugPrint(
                        '[DayPager] multi-touch: '
                        'pointers=${_dayPagerFlickProbes.keys.toList()}',
                      );
                    }
                  },
                  onPointerMove: (event) {
                    final probe = _dayPagerFlickProbes[event.pointer];
                    if (probe != null) {
                      probe.tracker.addPosition(
                        event.timeStamp,
                        event.position,
                      );
                      probe.samples++;
                      probe.lastTime = event.timeStamp;
                    }
                  },
                  onPointerUp: (event) {
                    final probe = _dayPagerFlickProbes.remove(event.pointer);
                    if (probe == null) {
                      return;
                    }
                    final path = event.position - probe.downPosition;
                    final pressDuration = event.timeStamp - probe.downTime;
                    final durationMs = pressDuration.inMilliseconds;
                    if (kDebugMode) {
                      final velocity = probe.tracker.getVelocity();
                      final gapMs =
                          (event.timeStamp - probe.lastTime).inMilliseconds;
                      debugPrint(
                        '[DayPager] lift(p${event.pointer}): '
                        'vx=${velocity.pixelsPerSecond.dx.toStringAsFixed(1)} '
                        'dx=${path.dx.toStringAsFixed(1)} '
                        'dur=${durationMs}ms '
                        'samples=${probe.samples} '
                        'gapBeforeUp=${gapMs}ms '
                        'concurrent=${_dayPagerFlickProbes.length} '
                        'minFling=${kMinFlingVelocity.toStringAsFixed(1)}',
                      );
                    }
                    // Arm the rescue: single remaining finger, short and
                    // horizontal-dominant swipes only. The drag recognizer
                    // runs right after this handler and consumes it.
                    if (_dayPagerFlickProbes.isEmpty &&
                        durationMs >= 16 &&
                        durationMs <= 300 &&
                        path.dx.abs() >= 24 &&
                        path.dx.abs() > path.dy.abs()) {
                      final pointerVx =
                          path.dx / (pressDuration.inMicroseconds / 1e6);
                      if (pointerVx.abs() >= kMinFlingVelocity) {
                        // Pointer moving right drags the pager toward the
                        // previous page: scroll velocity is the negation.
                        _dayPagerRescueVelocityX = -pointerVx;
                        _dayPagerRescueArmedAt = DateTime.now();
                      }
                    }
                  },
                  onPointerCancel: (event) {
                    _dayPagerRescueVelocityX = 0;
                    _dayPagerRescueArmedAt = null;
                    final probe = _dayPagerFlickProbes.remove(event.pointer);
                    if (probe != null && kDebugMode) {
                      final durationMs =
                          (event.timeStamp - probe.downTime).inMilliseconds;
                      debugPrint(
                        '[DayPager] CANCEL(p${event.pointer}) after '
                        '${durationMs}ms — gesture stolen '
                        '(system nav / palm rejection?)',
                      );
                    }
                  },
                  child: NotificationListener<ScrollNotification>(
                    // Week-pager settle model: nothing commits until the swipe
                    // has fully stopped (see _settleDayViewPage).
                    onNotification: (notification) {
                      if (notification.metrics.axis != Axis.horizontal) {
                        return false;
                      }
                      if (notification is ScrollStartNotification) {
                        if (kDebugMode) {
                          final metrics = notification.metrics;
                          final page = metrics.viewportDimension == 0
                              ? 0.0
                              : metrics.pixels / metrics.viewportDimension;
                          debugPrint(
                            '[DayPager] start: page=${page.toStringAsFixed(3)} '
                            'drag=${notification.dragDetails != null}',
                          );
                        }
                      } else if (notification is ScrollEndNotification) {
                        if (kDebugMode) {
                          final metrics = notification.metrics;
                          final page = metrics.viewportDimension == 0
                              ? 0.0
                              : metrics.pixels / metrics.viewportDimension;
                          debugPrint(
                            '[DayPager] end: page=${page.toStringAsFixed(3)}',
                          );
                        }
                        _settleDayViewPage(provider, settings, week);
                      }
                      return false;
                    },
                    child: PageView.builder(
                      key: const ValueKey('day-view-swipe-area'),
                      controller: controller,
                      // pageSnapping off on purpose: PageView would otherwise
                      // wrap its own PageScrollPhysics OUTSIDE ours and the
                      // rescue would never run. _dayPagerPhysics IS the snap.
                      physics: _dayPagerPhysics,
                      pageSnapping: false,
                      itemCount: pageCount,
                      // Same as the week pager: keep neighbours pre-built so a
                      // swipe never hits an itemBuilder spike mid-gesture.
                      allowImplicitScrolling: true,
                      onPageChanged: (page) => _handleDayViewPageChanged(
                        provider,
                        settings,
                        week,
                        page,
                      ),
                      itemBuilder: (context, page) {
                        // 1 Hz progress heartbeat rebuilds only this page's
                        // content (ongoing badges / progress), not the State.
                        return ValueListenableBuilder<int>(
                          valueListenable: _dayAgendaProgressTick,
                          builder: (context, _, _) => _buildDayViewPageContent(
                            provider: provider,
                            settings: settings,
                            week: week,
                            page: page,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One day-pager page: summary card + agenda column.
  ///
  /// Extracted from the pager itemBuilder so [_dayAgendaProgressTick] can
  /// rebuild exactly this subtree once a second instead of the whole home
  /// screen (week pager included), which used to drop day-view FPS.
  Widget _buildDayViewPageContent({
    required TimetableProvider provider,
    required TimetableSettings settings,
    required int week,
    required int page,
  }) {
    final target = _dayViewTargetForPage(settings, week, page);
    final selectedDate = _dateForWeekDay(
      settings,
      target.week,
      target.dayOfWeek,
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
    final displayItems = _buildHomeDayDisplayItems(
      provider: provider,
      settings: settings,
      week: target.week,
      dayOfWeek: target.dayOfWeek,
      myCourses: courses,
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
      key: ValueKey('day-content-${target.week}-${target.dayOfWeek}'),
      children: [
        // Keep original side inset / card width; only the
        // surface material matches chrome glass (below).
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _buildDayViewSummary(
            key: isActivePage ? const ValueKey('day-view-summary') : null,
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
            key: ValueKey('day-column-${target.week}-${target.dayOfWeek}'),
            provider: provider,
            settings: settings,
            week: target.week,
            dayOfWeek: target.dayOfWeek,
          ),
        ),
      ],
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
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final selectedDayDate = selectedDate != null
        ? DateTime(selectedDate.year, selectedDate.month, selectedDate.day)
        : null;
    final backToTodayIcon =
        selectedDayDate != null && selectedDayDate.isBefore(normalizedToday)
        ? Icons.arrow_forward_rounded
        : Icons.arrow_back_rounded;

    final isDark = theme.brightness == Brightness.dark;
    final hasBackdrop = hasHomePageBackdropImage(settings, isDark: isDark);
    // Same ink path as weekday chrome (auto-contrast + keep custom hex), but
    // judged from the card-region wallpaper band — the top band can be dark
    // (white chrome ink) while mid-screen is bright: white-on-white here.
    final summaryInk = homePageOverWallpaperInk(
      configuredHex: isDark
          ? settings.weekdayBarFontColorDark
          : settings.weekdayBarFontColorLight,
      defaultHex: isDark
          ? TimetableSettings.defaultWeekdayBarFontColorDark
          : TimetableSettings.defaultWeekdayBarFontColorLight,
      themeFallback: foruiTheme.colors.foreground,
      hasBackdrop: hasBackdrop,
      wallpaperLuminance: _wallpaperBodyLuminance ?? _wallpaperTopLuminance,
    );
    final summaryMutedInk = homePageOverWallpaperMutedInk(summaryInk);
    // With chrome blur on, the summary matches the top chrome band material
    // (real gaussian / liquid glass) instead of the course-card pre-blur
    // fill, so the card and the top bar read as one glass system.
    final useChromeGlass = homePageHasAnyChromeBlur(
      settings,
      hasBackdrop: hasBackdrop,
    );
    final countBadgeColor = hasAgenda
        ? colorScheme.primary.withValues(alpha: 0.14)
        : summaryInk.withValues(alpha: 0.10);
    final countBadgeTextColor = hasAgenda
        ? colorScheme.primary
        : summaryMutedInk;
    return _dayAgendaSurface(
      key: key,
      settings: settings,
      chromeGlass: useChromeGlass,
      // Neutral wash (not a course hue); CourseSurface owns glass vs solid.
      color: foruiTheme.colors.background,
      gradient: LinearGradient(
        colors: [foruiTheme.colors.background, foruiTheme.colors.background],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (isToday)
                        Text(
                          l10n.todayTimetableTitle,
                          style: foruiTheme.typography.body.sm.copyWith(
                            color: summaryMutedInk,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else if (_canNavigateDayViewToToday(settings))
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: const ValueKey('back-to-today-button'),
                            onTap: () async {
                              await _navigateDayViewToToday(provider);
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
                      if (isToday || _canNavigateDayViewToToday(settings))
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '·',
                            style: foruiTheme.typography.body.sm.copyWith(
                              color: summaryMutedInk,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      Text(
                        l10n.weekLabel(week),
                        style: foruiTheme.typography.body.sm.copyWith(
                          color: summaryMutedInk,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
                    foregroundColor: summaryMutedInk,
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
                fontWeight: FontWeight.w400,
                letterSpacing: 0.1,
                height: 1.15,
                color: summaryInk,
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
                      color: summaryInk.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      l10n.scheduleCountSummary(scheduleCount),
                      style: foruiTheme.typography.body.xs2.copyWith(
                        color: summaryMutedInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (firstAgenda != null)
                  Text(
                    '${l10n.classStartsAtLabel(firstAgenda.startTime)} · ${l10n.classEndsAtLabel(lastAgenda!.endTime)}',
                    style: foruiTheme.typography.body.xs2.copyWith(
                      color: summaryMutedInk,
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
            if (_isCoupleOverlayActive(provider)) ...[
              const SizedBox(height: 12),
              _buildDayViewSharedFreeSummary(
                provider: provider,
                settings: settings,
                week: week,
                dayOfWeek: dayOfWeek,
                isToday: isToday,
              ),
            ],
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

  List<SectionTime> _sectionsForSharedFree(
    TimetableProvider provider,
    TimetableSettings settings,
  ) {
    final schemeSections = provider.activeTimeScheme?.sections;
    if (schemeSections != null && schemeSections.isNotEmpty) {
      return schemeSections;
    }
    return settings.sections;
  }

  bool _isPartnerScheduleStale(TimetableProvider provider) {
    final importedAt = provider.partnerBinding?.lastImportedAt;
    if (importedAt == null) {
      return true;
    }
    return DateTime.now().difference(importedAt) > _partnerScheduleStaleAfter;
  }

  List<MinuteInterval> _sharedFreeIntervalsForDayView({
    required TimetableProvider provider,
    required TimetableSettings settings,
    required int week,
    required int dayOfWeek,
  }) {
    final sections = _sectionsForSharedFree(provider, settings);
    return CoupleTimetableLogic.sharedFreeIntervalsForDay(
      myCourses: provider.courses,
      partnerCourses: provider.partnerCourses,
      dayOfWeek: dayOfWeek,
      week: week,
      partnerWeekOffset: provider.partnerWeekOffset,
      sections: sections,
    );
  }

  Widget _buildDayViewSharedFreeSummary({
    required TimetableProvider provider,
    required TimetableSettings settings,
    required int week,
    required int dayOfWeek,
    required bool isToday,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final foruiTheme = context.theme;
    final freeAccent = _colorFromHex(
      CoupleTimetableLogic.freeSlotColorHex,
      foruiTheme.colors.primary,
    );
    final isStale = _isPartnerScheduleStale(provider);
    final title = isToday
        ? l10n.coupleTimetableSharedFreeTitle
        : l10n.coupleTimetableSharedFreeTitleOtherDay;
    final emptyLabel = isToday
        ? l10n.coupleTimetableNoSharedFree
        : l10n.coupleTimetableNoSharedFreeOtherDay;
    final mutedStyle = foruiTheme.typography.body.xs2.copyWith(
      color: foruiTheme.colors.mutedForeground,
      fontWeight: FontWeight.w400,
      height: 1.25,
    );

    final intervals = _sharedFreeIntervalsForDayView(
      provider: provider,
      settings: settings,
      week: week,
      dayOfWeek: dayOfWeek,
    );

    if (intervals.isEmpty) {
      return _buildSharedFreeSummaryShell(
        key: const ValueKey('shared-free-summary-empty'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: foruiTheme.typography.body.sm.copyWith(
                color: foruiTheme.colors.foreground,
                fontWeight: FontWeight.w400,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(emptyLabel, style: mutedStyle),
            if (isStale) ...[
              const SizedBox(height: 4),
              Text(l10n.coupleTimetableSharedFreeStaleHint, style: mutedStyle),
            ],
          ],
        ),
      );
    }

    final visibleLimit = _sharedFreeSegmentsExpanded
        ? intervals.length
        : math.min(_sharedFreeVisibleSegmentLimit, intervals.length);
    final visibleIntervals = intervals.take(visibleLimit).toList();
    final hiddenCount = intervals.length - visibleIntervals.length;

    return _buildSharedFreeSummaryShell(
      key: const ValueKey('shared-free-summary'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: foruiTheme.typography.body.sm.copyWith(
                    color: foruiTheme.colors.foreground,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: freeAccent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  l10n.coupleTimetableSharedFreeMeta(intervals.length),
                  style: foruiTheme.typography.body.xs2.copyWith(
                    color: freeAccent,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final interval in visibleIntervals)
                _buildSharedFreeTimeChip(
                  label: CoupleTimetableLogic.formatMinuteInterval(interval),
                  accent: freeAccent,
                ),
              if (hiddenCount > 0)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const ValueKey('shared-free-expand-button'),
                    onTap: () {
                      setState(() {
                        _sharedFreeSegmentsExpanded = true;
                      });
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: freeAccent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        l10n.coupleTimetableSharedFreeMoreCount(hiddenCount),
                        style: foruiTheme.typography.body.xs.copyWith(
                          color: freeAccent,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (isStale) ...[
            const SizedBox(height: 8),
            Text(l10n.coupleTimetableSharedFreeStaleHint, style: mutedStyle),
          ],
        ],
      ),
    );
  }

  Widget _buildSharedFreeTimeChip({
    required String label,
    required Color accent,
  }) {
    final foruiTheme = context.theme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: foruiTheme.typography.body.xs.copyWith(
          color: accent,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildSharedFreeSummaryShell({
    required Key key,
    required Widget child,
  }) {
    final foruiTheme = context.theme;
    return DecoratedBox(
      key: key,
      decoration: BoxDecoration(
        color: foruiTheme.colors.secondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        // 与摘要卡内其它区块同一套水平节奏，避免再套一层 14 造成左右过空。
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: child,
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

  Widget _buildDayViewEmptyState({
    required int week,
    required TimetableSettings settings,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasBackdrop = hasHomePageBackdropImage(settings, isDark: isDark);
    final colorScheme = Theme.of(context).colorScheme;
    // Same wallpaper auto-contrast as weekday / time-axis chrome: default ink
    // flips black↔white over dark photos; user-custom hex is kept as-is.
    final titleColor = homePageOverWallpaperInk(
      configuredHex: isDark
          ? settings.weekdayBarFontColorDark
          : settings.weekdayBarFontColorLight,
      defaultHex: isDark
          ? TimetableSettings.defaultWeekdayBarFontColorDark
          : TimetableSettings.defaultWeekdayBarFontColorLight,
      themeFallback: colorScheme.onSurface,
      hasBackdrop: hasBackdrop,
      wallpaperLuminance: _wallpaperTopLuminance,
    );
    final subtitleColor = homePageOverWallpaperMutedInk(titleColor);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.dayViewEmptyTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: titleColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.weekLabel(week),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: subtitleColor),
            ),
          ],
        ),
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
    final displayItems = _buildHomeDayDisplayItems(
      provider: provider,
      settings: settings,
      week: week,
      dayOfWeek: dayOfWeek,
      myCourses: courses,
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
    // Same hosting strategy as the week grid (see _wrapCourseGridLiquidGlassHost):
    // with pre-blurred wallpaper, cards sample the cached bitmap and do not need
    // a FakeGlass host; without it, CourseGridGlassHost shares one layer so
    // liquid cards do not each capture the backdrop on their own.
    final agendaList = ListView.separated(
      key: PageStorageKey<String>('day-agenda-$week-$dayOfWeek'),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      physics: const ClampingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      itemCount: agendaItems.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, itemIndex) {
        final item = agendaItems[itemIndex];
        return _buildDayAgendaEntry(week: week, settings: settings, item: item);
      },
    );
    return Builder(
      builder: (context) {
        if (settings.courseCardSurfaceStyle ==
                CourseCardSurfaceStyle.liquidGlass &&
            PreblurredWallpaperScope.maybeOf(context) != null) {
          return agendaList;
        }
        return CourseGridGlassHost(settings: settings, child: agendaList);
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
      child: _buildDayViewEmptyState(week: week, settings: settings),
    );
  }

  /// Day-view card surface honouring [TimetableSettings.courseCardSurfaceStyle].
  ///
  /// Shares [CourseSurface] with the week grid so the two views cannot drift.
  /// The tap target sits *inside* the surface behind a transparent [Material]
  /// so ink ripples paint above the frost rather than on the far page Material
  /// (which is what `Ink(decoration:)` used to buy us on an opaque card).
  Widget _dayAgendaSurface({
    required TimetableSettings settings,
    required Color color,
    required Widget child,
    Key? key,
    Gradient? gradient,
    Border? border,
    List<BoxShadow>? shadow,
    double radius = _dayViewCardRadius,
    VoidCallback? onTap,
    double opacityScale = 1,
    bool chromeGlass = false,
  }) {
    final content = onTap == null
        ? child
        : Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(radius),
              child: child,
            ),
          );
    if (chromeGlass) {
      // Chrome-band LOOK, course-card IMPLEMENTATION: the cached pre-blurred
      // wallpaper sample under the chrome wash colour — a plain drawImageRect
      // + ColoredBox, exactly like the agenda cards below. A live
      // BackdropFilter / liquid glass here had to be swapped out around every
      // pager swipe (per-frame backdrop resampling on the hot path) and the
      // material hop flashed on each swipe; one permanent material can't
      // flicker, and it stays opacity-safe through the open/close ramp.
      return ClipRRect(
        key: key,
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            const Positioned.fill(child: PreblurredWallpaperAlignedFill()),
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: HomePageChromeGlassFill.standInWashColor(
                    context,
                    // Card region, not chrome band: scrim polarity must match
                    // the wallpaper actually behind this card.
                    wallpaperTopLuminance:
                        _wallpaperBodyLuminance ?? _wallpaperTopLuminance,
                  ),
                ),
              ),
            ),
            content,
          ],
        ),
      );
    }
    return CourseSurface(
      key: key,
      style: settings.courseCardSurfaceStyle,
      color: color,
      borderRadius: radius,
      opacityScale: opacityScale,
      solidGradient: gradient,
      border: border,
      outerShadow: shadow,
      child: content,
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
      return _buildScheduleAgendaEntry(item, settings: settings);
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
    final palette = _resolveDayAgendaPalette(
      resolvedColor,
      foregroundHex: courseItem.course.textColor,
      settings: settings,
    );
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
      if (courseItem.coupleKind == CoupleCourseKind.together)
        _buildDayAgendaStatusBadge(
          text: l10n.coupleTimetableLegendTogether,
          textColor: Colors.white,
          backgroundColor: _colorFromHex(
            context.read<TimetableProvider>().coupleColorForKind(
              CoupleCourseKind.together,
            ),
            Colors.purple,
          ),
        ),
      if (courseItem.coupleKind == CoupleCourseKind.partner)
        _buildDayAgendaStatusBadge(
          text: l10n.coupleTimetableLegendPartner,
          textColor: Colors.white,
          backgroundColor: _colorFromHex(
            context.read<TimetableProvider>().coupleColorForKind(
              CoupleCourseKind.partner,
            ),
            Colors.pink,
          ),
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
      if (!courseItem.isPartnerCourse &&
          courseItem.course.hasHomeworkInWeek(week))
        _buildDayAgendaHomeworkDot(),
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
    // Keep frost readable; only a light dim for suspended / conflict states.
    final effectiveOpacity = isSuspended ? 0.84 : courseItem.opacity;

    Future<void> openCourseNotes() {
      return showCourseNoteSheet(
        context,
        course: courseItem.course,
        week: week,
        readOnly: courseItem.isPartnerCourse,
      );
    }

    if (courseItem.isPartnerCourse) {
      void openCoursePreview() {
        _showCourseActions(courseItem.course, week, displayItem: courseItem);
      }

      final partnerCard = progressInfo != null
          ? _buildCurrentDayAgendaCard(
              item: courseItem,
              week: week,
              settings: settings,
              progressInfo: progressInfo,
              l10n: l10n,
              colorScheme: colorScheme,
              ink: palette.foregroundColor,
              openContainer: openCoursePreview,
              onOpenNotes: openCourseNotes,
              opacityScale: effectiveOpacity,
            )
          : _buildDefaultDayAgendaCard(
              item: courseItem,
              week: week,
              settings: settings,
              l10n: l10n,
              palette: palette,
              statusBadges: statusBadges,
              cardDecoration: cardDecoration,
              openContainer: openCoursePreview,
              onOpenNotes: openCourseNotes,
              opacityScale: effectiveOpacity,
            );

      return Material(color: Colors.transparent, child: partnerCard);
    }

    // Released behaviour: tap expands the card into the editor via a container
    // transform. Dimming stays on opacityScale (not an Opacity wrapper) so
    // glass surfaces can still sample the backdrop.
    return OpenContainer<void>(
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
                week: week,
                settings: settings,
                progressInfo: progressInfo,
                l10n: l10n,
                colorScheme: colorScheme,
                ink: palette.foregroundColor,
                openContainer: openContainer,
                onOpenNotes: openCourseNotes,
                opacityScale: effectiveOpacity,
              )
            : _buildDefaultDayAgendaCard(
                item: courseItem,
                week: week,
                settings: settings,
                l10n: l10n,
                palette: palette,
                statusBadges: statusBadges,
                cardDecoration: cardDecoration,
                openContainer: openContainer,
                onOpenNotes: openCourseNotes,
                opacityScale: effectiveOpacity,
              );
        return Material(color: Colors.transparent, child: content);
      },
    );
  }

  Widget _buildDefaultDayAgendaCard({
    required _DayCourseDisplayItem item,
    required int week,
    required TimetableSettings settings,
    required AppLocalizations l10n,
    required _DayAgendaPalette palette,
    required List<Widget> statusBadges,
    required BoxDecoration cardDecoration,
    required VoidCallback openContainer,
    required VoidCallback onOpenNotes,
    double opacityScale = 1,
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
    final sessionNote = item.course.sessionNoteForWeek(week);
    final sessionPreview = sessionNote?.trimmedText;
    final ink = palette.foregroundColor;
    return _dayAgendaSurface(
      settings: settings,
      color: palette.baseColor,
      opacityScale: opacityScale,
      // Reuse the legacy decoration's pieces so `solid` stays pixel-identical.
      gradient: cardDecoration.gradient,
      border: cardDecoration.border as Border?,
      shadow: cardDecoration.boxShadow,
      onTap: openContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
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
                          color: _dayAgendaInkWash(ink, lightAlpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule_rounded, size: 13, color: ink),
                            const SizedBox(width: 5),
                            Text(
                              '${item.course.startTime} - ${item.course.endTime}',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: ink,
                                    fontWeight: FontWeight.w400,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      ...statusBadges,
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                _buildDayAgendaNoteAction(
                  l10n: l10n,
                  ink: ink,
                  onPressed: onOpenNotes,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.course.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                // Auto ink: flips black/white against the wallpaper band
                // behind glass cards (white-on-white mist was unreadable).
                color: ink,
                fontWeight: FontWeight.w400,
                height: 1.10,
              ),
            ),
            const SizedBox(height: 10),
            _buildCurrentDayAgendaInfoRow(
              icon: Icons.person_outline_rounded,
              text: teacherLine,
              ink: ink,
            ),
            const SizedBox(height: 6),
            _buildCurrentDayAgendaInfoRow(
              icon: Icons.location_on_outlined,
              text: locationLine,
              ink: ink,
            ),
            if (sessionPreview != null && sessionPreview.isNotEmpty) ...[
              const SizedBox(height: 6),
              _buildCurrentDayAgendaInfoRow(
                icon: Icons.sticky_note_2_outlined,
                text: sessionPreview,
                ink: ink,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentDayAgendaCard({
    required _DayCourseDisplayItem item,
    required int week,
    required TimetableSettings settings,
    required _DayAgendaProgressInfo progressInfo,
    required AppLocalizations l10n,
    required ColorScheme colorScheme,
    required Color ink,
    required VoidCallback openContainer,
    required VoidCallback onOpenNotes,
    double opacityScale = 1,
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
    final sessionNote = item.course.sessionNoteForWeek(week);
    final sessionPreview = sessionNote?.trimmedText;

    // Over glass the elapsed-progress fill has to stay see-through, or that
    // part of the card turns into a flat opaque block and the frost disappears.
    final progressFill =
        settings.courseCardSurfaceStyle == CourseCardSurfaceStyle.solid
        ? progressInfo.fillColor
        : progressInfo.fillColor.withValues(alpha: 0.55);

    return _dayAgendaSurface(
      settings: settings,
      color: progressInfo.baseColor,
      opacityScale: opacityScale,
      // Flat fill, matching the legacy decoration (this card has no gradient).
      gradient: LinearGradient(
        colors: [progressInfo.baseColor, progressInfo.baseColor],
      ),
      border: Border.all(color: borderColor, width: 1.2),
      shadow: [
        BoxShadow(
          color: progressInfo.fillColor.withValues(alpha: 0.18),
          blurRadius: 18,
          offset: const Offset(0, 4),
        ),
      ],
      onTap: openContainer,
      child: ClipRRect(
        key: ValueKey('day-agenda-progress-card-${item.course.id}'),
        borderRadius: BorderRadius.circular(_dayViewCardRadius),
        child: Stack(
          children: [
            Positioned.fill(
              // Isolated: the animating fill must not invalidate the card's
              // glass surface / text layers on every animation frame.
              child: RepaintBoundary(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    end: progressInfo.progress.clamp(0.0, 1.0),
                  ),
                  // Must stay below the 1 s progress tick, or the tween is
                  // retargeted before it settles and day view animates every
                  // frame forever (see _quantizeDayAgendaProgress).
                  duration: const Duration(milliseconds: 600),
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
                      color: progressFill,
                      borderRadius: BorderRadius.circular(_dayViewCardRadius),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Wrap(
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
                                color: _dayAgendaInkWash(ink, lightAlpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.schedule_rounded,
                                    size: 13,
                                    color: ink,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${item.course.startTime} - ${item.course.endTime}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: ink,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildDayAgendaStatusBadge(
                              text: progressInfo.statusText,
                              textColor: progressInfo.statusTextColor,
                              backgroundColor:
                                  progressInfo.statusBackgroundColor,
                            ),
                            if (item.isConflicting)
                              _buildDayAgendaStatusBadge(
                                text: l10n.conflictLabel,
                                textColor: Colors.white,
                                backgroundColor: colorScheme.error,
                              ),
                            if (!item.isPartnerCourse &&
                                item.course.hasHomeworkInWeek(week))
                              _buildDayAgendaHomeworkDot(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      _buildDayAgendaNoteAction(
                        l10n: l10n,
                        ink: ink,
                        onPressed: onOpenNotes,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.course.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: ink,
                      fontWeight: FontWeight.w400,
                      height: 1.10,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildCurrentDayAgendaInfoRow(
                    icon: Icons.person_outline_rounded,
                    text: teacherLine,
                    ink: ink,
                  ),
                  const SizedBox(height: 6),
                  _buildCurrentDayAgendaInfoRow(
                    icon: Icons.location_on_outlined,
                    text: locationLine,
                    ink: ink,
                  ),
                  if (sessionPreview != null && sessionPreview.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _buildCurrentDayAgendaInfoRow(
                      icon: Icons.sticky_note_2_outlined,
                      text: sessionPreview,
                      ink: ink,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayAgendaHomeworkDot() {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.2),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.assignment_outlined,
        size: 11,
        color: Color(0xFFE05D44),
      ),
    );
  }

  Widget _buildDayAgendaNoteAction({
    required AppLocalizations l10n,
    required Color ink,
    required VoidCallback onPressed,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _dayAgendaInkWash(ink, lightAlpha: 0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: _dayAgendaInkWash(ink, lightAlpha: 0.22),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sticky_note_2_outlined, size: 14, color: ink),
                const SizedBox(width: 5),
                Text(
                  l10n.courseNoteAction,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
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
        return _dayAgendaSurface(
          settings: provider.settings,
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
        );
      },
    );
  }

  Widget _buildScheduleAgendaEntry(
    _DayAgendaItem agendaItem, {
    required TimetableSettings settings,
  }) {
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
    // Same auto black/white as course agenda cards (glass over bright mist).
    final ink = _dayAgendaAutoInk(cardColor, settings: settings);

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
              settings: settings,
              progressInfo: progressInfo,
              l10n: l10n,
              colorScheme: colorScheme,
              ink: ink,
              openContainer: openContainer,
            ),
          );
        }
        return _dayAgendaSurface(
          settings: settings,
          color: cardColor,
          gradient: LinearGradient(colors: [cardColor, cardColor]),
          shadow: [
            BoxShadow(
              color: cardColor.withValues(alpha: 0.20),
              blurRadius: 18,
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
                        color: _dayAgendaInkWash(ink, lightAlpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_note_rounded, size: 13, color: ink),
                          const SizedBox(width: 5),
                          Text(
                            '${agendaItem.startTime} - ${agendaItem.endTime}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildDayAgendaStatusBadge(
                      text: l10n.scheduleBadgeLabel,
                      textColor: ink,
                      backgroundColor: _dayAgendaInkWash(ink, lightAlpha: 0.18),
                    ),
                    if (isCrossDay)
                      _buildDayAgendaStatusBadge(
                        text: l10n.crossDayBadgeLabel,
                        textColor: ink,
                        backgroundColor: _dayAgendaInkWash(
                          ink,
                          lightAlpha: 0.18,
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
                    color: ink,
                    fontWeight: FontWeight.w800,
                    height: 1.10,
                  ),
                ),
                if (hasLocation) ...[
                  const SizedBox(height: 10),
                  _buildCurrentDayAgendaInfoRow(
                    icon: Icons.location_on_outlined,
                    text: l10n.locationPrefix(item.location!.trim()),
                    ink: ink,
                  ),
                ],
                if (hasNote) ...[
                  const SizedBox(height: 6),
                  _buildCurrentDayAgendaInfoRow(
                    icon: Icons.notes_rounded,
                    text: item.note!.trim(),
                    ink: ink,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentScheduleAgendaCard({
    required ScheduleItem item,
    required _DayAgendaItem agendaItem,
    required TimetableSettings settings,
    required _DayAgendaProgressInfo progressInfo,
    required AppLocalizations l10n,
    required ColorScheme colorScheme,
    required Color ink,
    required VoidCallback openContainer,
  }) {
    final theme = Theme.of(context);
    final hasLocation = item.location?.trim().isNotEmpty == true;
    final hasNote = item.note?.trim().isNotEmpty == true;
    final isCrossDay = item.endDate.isAfter(item.startDate);
    // See _buildCurrentDayAgendaCard: the fill must stay see-through on glass.
    final progressFill =
        settings.courseCardSurfaceStyle == CourseCardSurfaceStyle.solid
        ? progressInfo.fillColor
        : progressInfo.fillColor.withValues(alpha: 0.55);

    return _dayAgendaSurface(
      settings: settings,
      color: progressInfo.baseColor,
      // Flat fill, matching the legacy decoration (no gradient here).
      gradient: LinearGradient(
        colors: [progressInfo.baseColor, progressInfo.baseColor],
      ),
      shadow: [
        BoxShadow(
          color: progressInfo.fillColor.withValues(alpha: 0.18),
          blurRadius: 18,
          offset: const Offset(0, 4),
        ),
      ],
      onTap: openContainer,
      child: ClipRRect(
        key: ValueKey('day-agenda-progress-schedule-card-${item.id}'),
        borderRadius: BorderRadius.circular(_dayViewCardRadius),
        child: Stack(
          children: [
            Positioned.fill(
              // Isolated: the animating fill must not invalidate the card's
              // glass surface / text layers on every animation frame.
              child: RepaintBoundary(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    end: progressInfo.progress.clamp(0.0, 1.0),
                  ),
                  // Below the 1 s tick so the tween settles between steps
                  // (see _quantizeDayAgendaProgress).
                  duration: const Duration(milliseconds: 600),
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
                      color: progressFill,
                      borderRadius: BorderRadius.circular(_dayViewCardRadius),
                    ),
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
                          color: _dayAgendaInkWash(ink, lightAlpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.event_note_rounded,
                              size: 13,
                              color: ink,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${agendaItem.startTime} - ${agendaItem.endTime}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: ink,
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
                        textColor: ink,
                        backgroundColor: _dayAgendaInkWash(
                          ink,
                          lightAlpha: 0.18,
                        ),
                      ),
                      if (isCrossDay)
                        _buildDayAgendaStatusBadge(
                          text: l10n.crossDayBadgeLabel,
                          textColor: ink,
                          backgroundColor: _dayAgendaInkWash(
                            ink,
                            lightAlpha: 0.18,
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
                      color: ink,
                      fontWeight: FontWeight.w800,
                      height: 1.10,
                    ),
                  ),
                  if (hasLocation) ...[
                    const SizedBox(height: 10),
                    _buildCurrentDayAgendaInfoRow(
                      icon: Icons.location_on_outlined,
                      text: l10n.locationPrefix(item.location!.trim()),
                      ink: ink,
                    ),
                  ],
                  if (hasNote) ...[
                    const SizedBox(height: 6),
                    _buildCurrentDayAgendaInfoRow(
                      icon: Icons.notes_rounded,
                      text: item.note!.trim(),
                      ink: ink,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentDayAgendaInfoRow({
    required IconData icon,
    required String text,
    required Color ink,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: ink.withValues(alpha: 0.82)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: ink.withValues(alpha: 0.92),
              fontWeight: FontWeight.w400,
              fontSize: 11.5,
              height: 1.15,
            ),
          ),
        ),
      ],
    );
  }

  /// Translucent chip/pill glaze under [ink]-coloured content.
  ///
  /// White ink keeps the legacy white glaze; dark ink flips to a dark glaze —
  /// a white wash under dark text over a bright wallpaper adds no contrast.
  Color _dayAgendaInkWash(Color ink, {required double lightAlpha}) {
    return ink.computeLuminance() > 0.5
        ? Colors.white.withValues(alpha: lightAlpha)
        : Colors.black.withValues(alpha: lightAlpha * 0.55);
  }

  /// Progress snapped to ~0.4% steps (≈1.5 px on a full-width card).
  ///
  /// The raw ratio has sub-second precision, so it used to change on every
  /// 1 s tick and the progress tween was retargeted before it could finish —
  /// day view ended up animating (and re-rasterizing all its glass chrome)
  /// on every frame, forever. Stepping is visually indistinguishable while
  /// letting the tween settle, so no frames are scheduled between steps.
  static double _quantizeDayAgendaProgress(double raw) {
    const steps = 250;
    return ((raw * steps).floorToDouble() / steps).clamp(0.02, 0.98);
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
    final progress = _quantizeDayAgendaProgress(elapsedMinutes / totalMinutes);
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
    final progress = _quantizeDayAgendaProgress(elapsedMinutes / totalMinutes);
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

  _DayAgendaPalette _resolveDayAgendaPalette(
    Color background, {
    String? foregroundHex,
    TimetableSettings? settings,
  }) {
    // Keep pastel import colors light; only a tiny white lift for depth.
    final fillColor = background;
    final baseColor = Color.lerp(fillColor, Colors.white, 0.06) ?? fillColor;
    final foregroundColor =
        foregroundHex == null || foregroundHex.trim().isEmpty
        ? _dayAgendaAutoInk(fillColor, settings: settings)
        : _colorFromHex(foregroundHex, Colors.white);
    return _DayAgendaPalette(
      baseColor: baseColor,
      fillColor: fillColor,
      foregroundColor: foregroundColor,
    );
  }

  /// Default agenda-card ink when the course has no custom text colour.
  ///
  /// Opaque styles keep the legacy white-on-hue. Glass styles show mostly
  /// wallpaper through a ~40% tint, so the ink flips black/white against the
  /// blend of course hue and the wallpaper band behind the cards — a bright
  /// wallpaper region otherwise gives white-on-white.
  Color _dayAgendaAutoInk(Color fill, {TimetableSettings? settings}) {
    if (settings == null) {
      return Colors.white;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = settings.courseCardSurfaceStyle;
    final glassOverWallpaper =
        hasHomePageBackdropImage(settings, isDark: isDark) &&
        (style == CourseCardSurfaceStyle.gaussian ||
            style == CourseCardSurfaceStyle.liquidGlass);
    if (!glassOverWallpaper) {
      return Colors.white;
    }
    final wallpaperLuminance =
        _wallpaperBodyLuminance ?? _wallpaperTopLuminance;
    if (wallpaperLuminance == null) {
      return Colors.white;
    }
    final effectiveLuminance =
        fill.computeLuminance() * 0.5 + wallpaperLuminance * 0.5;
    return homePageChromeForegroundForLuminance(
      effectiveLuminance,
      fallback: Colors.white,
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
          fontWeight: FontWeight.w400,
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
            // Do not wrap CourseCard in Opacity: BackdropFilter / FakeGlass
            // cannot sample behind an opacity layer (blur becomes pure clear).
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
              showHomeworkIndicator:
                  !item.isPartnerCourse && item.course.hasHomeworkInWeek(week),
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
              onTap: () =>
                  _showCourseActions(item.course, week, displayItem: item),
              compactTitleFontSize: settings.courseCardFontSize,
              compactSubtitleFontSize: (settings.courseCardFontSize - 1).clamp(
                7.0,
                14.0,
              ),
              compactVerticalPadding: sectionHeight < 64 ? 4 : 6,
              compactOuterInset: cardInset,
              surfaceStyle: settings.courseCardSurfaceStyle,
              // Dim conflict / non-current via fill alphas, keep frost working.
              surfaceOpacity: item.opacity,
              titleColorHex: resolveCourseCardTitleColorHex(
                courseTextColorHex: item.course.textColor,
                settingsTitleColorLight: settings.courseCardTitleColorLight,
                settingsTitleColorDark: settings.courseCardTitleColorDark,
                isDark: Theme.of(context).brightness == Brightness.dark,
              ),
              detailColorHex: resolveCourseCardDetailColorHex(
                courseTextColorHex: item.course.textColor,
                settingsDetailColorLight: settings.courseCardDetailColorLight,
                settingsDetailColorDark: settings.courseCardDetailColorDark,
                settingsTitleColorLight: settings.courseCardTitleColorLight,
                settingsTitleColorDark: settings.courseCardTitleColorDark,
                isDark: Theme.of(context).brightness == Brightness.dark,
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

  List<_DayCourseDisplayItem> _buildHomeDayDisplayItems({
    required TimetableProvider provider,
    required TimetableSettings settings,
    required int week,
    required int dayOfWeek,
    required List<Course> myCourses,
    Set<String> currentCourseIds = const <String>{},
  }) {
    final conflictMap = provider.courseConflictMapForWeek(week);
    if (!_isCoupleOverlayActive(provider)) {
      return _buildDayCourseDisplayItems(
        courses: myCourses,
        week: week,
        settings: settings,
        conflictMap: conflictMap,
        currentCourseIds: currentCourseIds,
      );
    }

    final partnerWeek = provider.partnerWeekFor(week);
    final partnerCourses = _getCoursesForDay(
      provider.partnerCourses,
      partnerWeek,
      dayOfWeek,
      settings,
    );
    return _buildCoupleDayCourseDisplayItems(
      myCourses: myCourses,
      partnerCourses: partnerCourses,
      week: week,
      partnerWeek: partnerWeek,
      partnerWeekOffset: provider.partnerWeekOffset,
      settings: settings,
      conflictMap: conflictMap,
      currentCourseIds: currentCourseIds,
    );
  }

  List<_DayCourseDisplayItem> _buildCoupleDayCourseDisplayItems({
    required List<Course> myCourses,
    required List<Course> partnerCourses,
    required int week,
    required int partnerWeek,
    required int partnerWeekOffset,
    required TimetableSettings settings,
    required Map<String, List<Course>> conflictMap,
    Set<String> currentCourseIds = const <String>{},
  }) {
    final usedPartnerIds = <String>{};
    final items = <_DayCourseDisplayItem>[];

    for (final course in myCourses) {
      final isCurrentWeekCourse = course.isInWeek(week);
      if (!isCurrentWeekCourse &&
          _hasCurrentWeekOverlap(myCourses, course, week)) {
        continue;
      }
      if (!isCurrentWeekCourse &&
          !_isPreferredNonCurrentCourse(myCourses, course, week)) {
        continue;
      }

      var kind = CoupleCourseKind.mine;
      for (final partner in partnerCourses) {
        if (CoupleTimetableLogic.isTogetherClass(
          course,
          partner,
          week: week,
          partnerWeekOffset: partnerWeekOffset,
        )) {
          kind = CoupleCourseKind.together;
          usedPartnerIds.add(partner.id);
          break;
        }
      }

      items.add(
        _DayCourseDisplayItem(
          course: course,
          isCurrentWeekCourse: isCurrentWeekCourse,
          isConflicting: conflictMap.containsKey(course.id),
          isCurrentCourse: currentCourseIds.contains(course.id),
          opacity: !isCurrentWeekCourse
              ? 0.62
              : (conflictMap.containsKey(course.id)
                    ? settings.timetableConflictCourseOpacity
                    : 1),
          coupleKind: kind,
        ),
      );
    }

    for (final course in partnerCourses) {
      if (usedPartnerIds.contains(course.id)) {
        continue;
      }
      final isCurrentWeekCourse = course.isInWeek(partnerWeek);
      if (!isCurrentWeekCourse &&
          _hasCurrentWeekOverlap(partnerCourses, course, partnerWeek)) {
        continue;
      }
      if (!isCurrentWeekCourse &&
          !_isPreferredNonCurrentCourse(partnerCourses, course, partnerWeek)) {
        continue;
      }

      items.add(
        _DayCourseDisplayItem(
          course: course,
          isCurrentWeekCourse: isCurrentWeekCourse,
          isConflicting: false,
          isCurrentCourse: false,
          opacity: isCurrentWeekCourse ? 1 : 0.62,
          coupleKind: CoupleCourseKind.partner,
          isPartnerCourse: true,
        ),
      );
    }

    return items..sort((left, right) {
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
    if (item.coupleKind != null) {
      return context.read<TimetableProvider>().coupleColorForKind(
        item.coupleKind!,
      );
    }
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
    if (item.coupleKind == CoupleCourseKind.together) {
      return l10n.coupleTimetableLegendTogether;
    }
    if (item.coupleKind == CoupleCourseKind.partner) {
      return l10n.coupleTimetableLegendPartner;
    }
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
    if (item.coupleKind == CoupleCourseKind.together) {
      labels.add(l10n.coupleTimetableLegendTogether);
    }
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

  /// Calendar week of today relative to [TimetableSettings.semesterStartDate].
  ///
  /// Returns null when semester start is unset, before week 1, or **past the
  /// configured [TimetableSettings.semesterWeekCount]** (vacation / after term).
  /// Callers must not invent weeks outside that range — never auto-expand the
  /// semester just to "return to today".
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
    if (week < 1 || week > settings.semesterWeekCount) {
      return null;
    }
    return week;
  }

  /// Whether day-view may show / act on "back to today".
  ///
  /// False when today is outside the configured semester (e.g. already on
  /// vacation after the last teaching week) so we never jump to a wrong
  /// "same weekday last week" or expand semesterWeekCount.
  bool _canNavigateDayViewToToday(TimetableSettings settings) {
    final now = DateTime.now();
    final visibleDays = _visibleDayNumbers(settings);
    if (!visibleDays.contains(now.weekday)) {
      return false;
    }
    return _resolveCurrentSemesterWeek(settings) != null;
  }

  Future<void> _navigateDayViewToToday(TimetableProvider provider) async {
    final now = DateTime.now();
    final settings = provider.settings;
    final currentSemesterWeek = _resolveCurrentSemesterWeek(settings);
    if (!_canNavigateDayViewToToday(settings) || currentSemesterWeek == null) {
      return;
    }
    await _animateDayViewToWeek(
      provider,
      settings,
      currentSemesterWeek,
      now.weekday,
    );
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
    // Do not wrap [HyperosFrostedSurface] in [Opacity]: Flutter's
    // [BackdropFilter] cannot sample content behind an opacity layer, so the
    // button would only show a solid tint and ignore the frosted-blur switch.
    final useBlur = HyperosBlurredHeader.backdropBlurEnabled(context);
    final baseTint = HyperosBlurredHeader.homePageRegionTintColor(
      context,
      withBlur: useBlur,
    );
    final frostedTint = baseTint.withValues(
      alpha: (baseTint.a * buttonOpacity).clamp(0.0, 1.0),
    );
    final contentOpacity = buttonOpacity.clamp(0.0, 1.0);

    return SafeArea(
      minimum: const EdgeInsets.only(right: 20, bottom: 24),
      child: Align(
        alignment: Alignment.bottomRight,
        child: Tooltip(
          message: l10n.backToCurrentWeekAction,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              border: Border.all(
                color: foruiColors.border.withValues(
                  alpha: foruiColors.border.a * contentOpacity,
                ),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha:
                        (theme.brightness == Brightness.dark ? 0.12 : 0.06) *
                        contentOpacity,
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
                tint: frostedTint,
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
                            color: colorScheme.primary.withValues(
                              alpha: colorScheme.primary.a * contentOpacity,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.backToCurrentWeekAction,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface.withValues(
                                alpha: colorScheme.onSurface.a * contentOpacity,
                              ),
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

  /// One shared FakeGlass layer for all course cards on this week page.
  Widget _wrapCourseGridLiquidGlassHost({
    required TimetableSettings settings,
    required Widget child,
  }) {
    if (settings.courseCardSurfaceStyle != CourseCardSurfaceStyle.liquidGlass) {
      return CourseGridGlassHost(settings: settings, child: child);
    }
    // PreblurredWallpaperScope is created *below* this State's own context, so
    // the lookup has to run from a descendant or it always misses and the host
    // gets built even when the cards are sampling the pre-blurred bitmap.
    //
    // This short-circuit is home-page-only: the settings previews have no
    // pre-blurred bitmap (it is aligned to the screen, not to a preview box).
    return Builder(
      builder: (context) {
        // When pre-blurred wallpaper is active, cards sample that bitmap and do
        // not need a FakeGlass host (avoids double frost + scroll cost).
        if (PreblurredWallpaperScope.maybeOf(context) != null) {
          return child;
        }
        return CourseGridGlassHost(settings: settings, child: child);
      },
    );
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

  Future<void> _showCourseActions(
    Course course,
    int week, {
    _DayCourseDisplayItem? displayItem,
  }) async {
    final previewItems = _buildCourseActionPreviewItems(
      course,
      week,
      displayItem: displayItem,
    );
    await showCourseActionSheet(
      context,
      previewItems: previewItems,
      week: week,
      onEdit: _editCourse,
      onReschedule: (target) => _showRescheduleSheet(target, sourceWeek: week),
      onDelete: (target) => _showDeleteCourseOptions(target, week),
      onSuspend: (target) => _showSuspendSheet(target, week),
    );
  }

  List<CourseActionPreviewItem> _buildCourseActionPreviewItems(
    Course course,
    int week, {
    _DayCourseDisplayItem? displayItem,
  }) {
    final provider = context.read<TimetableProvider>();
    final isPartner = displayItem?.isPartnerCourse ?? false;
    final partnerWeekOffset = provider.partnerWeekOffset;
    var coupleKind = displayItem?.coupleKind;
    if (coupleKind == null &&
        !isPartner &&
        _isCoupleOverlayActive(provider) &&
        _findTogetherPartnerCourse(
              course,
              week,
              partnerWeekOffset: partnerWeekOffset,
            ) !=
            null) {
      coupleKind = CoupleCourseKind.together;
    }
    if (coupleKind == null &&
        isPartner &&
        _isCoupleOverlayActive(provider) &&
        provider.courses.any(
          (mine) => CoupleTimetableLogic.isTogetherClass(
            mine,
            course,
            week: week,
            partnerWeekOffset: partnerWeekOffset,
          ),
        )) {
      coupleKind = CoupleCourseKind.together;
    }
    if (coupleKind == null && isPartner && _isCoupleOverlayActive(provider)) {
      coupleKind = CoupleCourseKind.partner;
    }
    final items = <CourseActionPreviewItem>[
      CourseActionPreviewItem(
        course: course,
        isPartnerCourse: isPartner,
        coupleKind: coupleKind,
      ),
    ];

    if (!isPartner) {
      for (final conflict in _conflictsForCourseInWeek(course, week)) {
        if (items.any((item) => item.course.id == conflict.id)) {
          continue;
        }
        items.add(CourseActionPreviewItem(course: conflict, isConflict: true));
      }
    }

    if (!_isCoupleOverlayActive(provider)) {
      return items;
    }

    if (coupleKind == CoupleCourseKind.together) {
      final partner = _findTogetherPartnerCourse(
        course,
        week,
        partnerWeekOffset: partnerWeekOffset,
      );
      if (partner != null &&
          !items.any((item) => item.course.id == partner.id)) {
        items.add(
          CourseActionPreviewItem(
            course: partner,
            isPartnerCourse: true,
            coupleKind: CoupleCourseKind.together,
          ),
        );
      }
      return items;
    }

    if (isPartner) {
      for (final mine in provider.courses) {
        if (CoupleTimetableLogic.isTogetherClass(
              mine,
              course,
              week: week,
              partnerWeekOffset: partnerWeekOffset,
            ) &&
            !items.any((item) => item.course.id == mine.id)) {
          items.add(
            CourseActionPreviewItem(
              course: mine,
              coupleKind: CoupleCourseKind.together,
            ),
          );
          break;
        }
      }
      return items;
    }

    for (final partner in _overlappingPartnerCourses(
      course,
      week,
      partnerWeekOffset: partnerWeekOffset,
    )) {
      if (items.any((item) => item.course.id == partner.id)) {
        continue;
      }
      items.add(
        CourseActionPreviewItem(
          course: partner,
          isPartnerCourse: true,
          coupleKind: CoupleCourseKind.partner,
        ),
      );
    }
    return items;
  }

  Course? _findTogetherPartnerCourse(
    Course mine,
    int week, {
    required int partnerWeekOffset,
  }) {
    final provider = context.read<TimetableProvider>();
    for (final partner in provider.partnerCourses) {
      if (CoupleTimetableLogic.isTogetherClass(
        mine,
        partner,
        week: week,
        partnerWeekOffset: partnerWeekOffset,
      )) {
        return partner;
      }
    }
    return null;
  }

  List<Course> _overlappingPartnerCourses(
    Course mine,
    int week, {
    required int partnerWeekOffset,
  }) {
    final provider = context.read<TimetableProvider>();
    return provider.partnerCourses
        .where(
          (partner) =>
              CoupleTimetableLogic.coursesOverlapForCoupleView(
                mine,
                partner,
                myWeek: week,
                partnerWeekOffset: partnerWeekOffset,
              ) &&
              !CoupleTimetableLogic.isTogetherClass(
                mine,
                partner,
                week: week,
                partnerWeekOffset: partnerWeekOffset,
              ),
        )
        .toList();
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
    final hasBackdrop = hasHomePageBackdropImage(settings, isDark: isDark);
    // Same wallpaper auto-contrast as weekday ink; user-custom time-axis hex
    // is never replaced.
    final timeAxisColor = homePageOverWallpaperInk(
      configuredHex: isDark
          ? settings.timeAxisFontColorDark
          : settings.timeAxisFontColorLight,
      defaultHex: isDark
          ? TimetableSettings.defaultTimeAxisFontColorDark
          : TimetableSettings.defaultTimeAxisFontColorLight,
      themeFallback: isDark ? Colors.white : Colors.grey.shade800,
      hasBackdrop: hasBackdrop,
      wallpaperLuminance: _wallpaperTopLuminance,
    );
    final timeAxisMutedColor = homePageOverWallpaperMutedInk(timeAxisColor);
    final compactTextStyle = TextStyle(
      fontSize: (settings.compactFontSize - 2).clamp(6.0, 10.0),
      color: timeAxisMutedColor,
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
            color: timeAxisColor,
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
                    fontWeight: FontWeight.w400,
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
  final CoupleCourseKind? coupleKind;
  final bool isPartnerCourse;

  const _DayCourseDisplayItem({
    required this.course,
    required this.isCurrentWeekCourse,
    required this.isConflicting,
    required this.isCurrentCourse,
    required this.opacity,
    this.coupleKind,
    this.isPartnerCourse = false,
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

/// Home timetable only: clamping scroll, no HyperOS rubber-band overscroll.
class _TimetableHomeScrollBehavior extends ScrollBehavior {
  const _TimetableHomeScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // No Material stretch / glow — keep the grid hard-edged.
    return child;
  }
}

/// Vertical pull detector that yields to horizontal week paging.
///
/// Claims the gesture arena only after the drag is clearly more vertical than
/// horizontal, so left/right week swipes stay smooth.
class _HomePullVerticalDragDetector extends StatefulWidget {
  const _HomePullVerticalDragDetector({
    required this.child,
    required this.enabled,
    required this.onPullUpdate,
    required this.onPullEnd,
    required this.onPullCancel,
  });

  final Widget child;
  final bool enabled;
  final ValueChanged<double> onPullUpdate;
  final VoidCallback onPullEnd;
  final VoidCallback onPullCancel;

  @override
  State<_HomePullVerticalDragDetector> createState() =>
      _HomePullVerticalDragDetectorState();
}

class _HomePullVerticalDragDetectorState
    extends State<_HomePullVerticalDragDetector> {
  double _accumulatedDx = 0;
  double _accumulatedDy = 0;
  bool _isTrackingVerticalPull = false;

  static const double _axisDecisionDistance = 10;

  void _resetTracking() {
    _accumulatedDx = 0;
    _accumulatedDy = 0;
    _isTrackingVerticalPull = false;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        _resetTracking();
      },
      onPointerMove: (event) {
        final delta = event.delta;
        _accumulatedDx += delta.dx;
        _accumulatedDy += delta.dy;

        if (!_isTrackingVerticalPull) {
          final absDx = _accumulatedDx.abs();
          final absDy = _accumulatedDy.abs();
          if (absDx < _axisDecisionDistance && absDy < _axisDecisionDistance) {
            return;
          }
          // Prefer horizontal week paging when the gesture is not clearly vertical.
          if (absDy <= absDx * 1.15) {
            return;
          }
          _isTrackingVerticalPull = true;
        }

        if (_isTrackingVerticalPull) {
          widget.onPullUpdate(delta.dy);
        }
      },
      onPointerUp: (_) {
        if (_isTrackingVerticalPull) {
          widget.onPullEnd();
        } else {
          widget.onPullCancel();
        }
        _resetTracking();
      },
      onPointerCancel: (_) {
        if (_isTrackingVerticalPull) {
          widget.onPullCancel();
        }
        _resetTracking();
      },
      child: widget.child,
    );
  }
}
