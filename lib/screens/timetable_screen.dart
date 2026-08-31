import 'dart:async';
import 'dart:io';
import 'package:flutter_miuix/miuix.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:animations/animations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart'
    show Drag, VelocityTracker, kMinFlingVelocity;
import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/service_message_localizer.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/class_reminder.dart';
import '../models/course.dart';
import '../models/exam.dart';
import '../models/schedule_item.dart';
import '../models/liquid_glass_tuning.dart';
import '../models/timetable_settings.dart';
import '../domain/couple_timetable_logic.dart';
import '../providers/timetable_provider.dart';
import '../services/app_update_service.dart';
import '../services/support_creator_service.dart';
import '../services/widget_launch_router.dart';
import '../widgets/class_reminder_sheet.dart';
import '../utils/app_toast.dart';
import '../utils/hex_color.dart';
import '../utils/course_color_palette.dart';
import '../widgets/home_page_region_blur.dart';
import '../utils/home_page_background.dart';
import '../utils/home_startup_visual_primer.dart';
import '../ui/hyperos/frosted/liquid_glass_degradation.dart';
import '../ui/hyperos/liquid/liquid_glass_tokens.dart';
import '../ui/hyperos/liquid/hyperos_liquid_glass_surface.dart'
    show UndimmedBackdropCapture;
import '../widgets/course_action_sheet.dart';
import '../widgets/course_followup_sheets.dart';
import '../widgets/course_note_sheet.dart';
import '../widgets/course_card.dart';
import '../widgets/course_surface.dart';
import '../widgets/course_grid_surface_host.dart';
import '../widgets/home_menu_catalog.dart';
import '../widgets/home_top_menu.dart';
import '../widgets/home_update_prompt.dart';
import '../widgets/preblurred_wallpaper_glass.dart';
import '../widgets/profile_quick_switch_sheet.dart';
import '../widgets/week_selector_picker_sheet.dart';
import 'add_course_screen.dart';
import 'add_exam_screen.dart';
import 'add_schedule_item_screen.dart';
import 'add_task_screen.dart';
import 'about_screen.dart';
import 'course_import_screen.dart';
import 'timetable_profiles_screen.dart';

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
    with WidgetsBindingObserver, TickerProviderStateMixin {
  static const int _minWeek = 1;
  static const double _weekDayHeaderHeight = 40;
  static const double _homeTitleHorizontalNudge = 4;
  static const Duration _weekSlideDuration = Duration(milliseconds: 280);
  static const Duration _dayExpandDuration = Duration(milliseconds: 360);
  static const double _dayViewCardRadius = 20;

  /// 玻璃坞药丸占用高度：药丸 56 + 底部安全 6（药丸顶到屏幕底的距离）。
  static const double _glassDockPillOccupancy = 62;

  /// 玻璃坞玻璃材质实验开关（用户 A/B 对比用）。
  ///
  /// true = 包原版默认材质：底栏本体 kBottomBarGlassDefaults、拖拽透镜
  /// baseIndicatorSettings（轻微透镜弯曲）、pinch 0.4、expansion 水平12/
  /// 垂直8、质量自适应；右侧浮钮与药丸显式共用这份官方底栏材质——
  /// 包「原版」下两者不传参时内部默认各不相同，会呈现玻璃断层。
  /// 此前自定义的「拉满折射拖拽透镜」在纯色/浅色壁纸上呈四周折射、
  /// 中间全透明的「甜甜圈」观感，故整体回退原版供对比。
  ///
  /// false = 旧的 mikcb 自定义调校（sheetSettingsFor 跟随「液态玻璃调
  /// 校」+ dragLensSettings 拉满折射 + pinch 1.0 + premium/minimal 强制
  /// 档 + 浮钮与药丸统一材质）。用户若不满意原版观感，改回 false 即可
  /// 一键还原；确认满意后可删除 false 分支与本开关。
  static const bool _kStockDockGlass = true;

  late final PageController _weekPageController;
  late final AnimationController _dayViewExpandController;


  /// 日视图锚点展开/收起与设置页拖动转场期间，卡片玻璃 fill 需要每帧
  /// 重采样（壁纸屏幕固定、卡片移动），否则纹理停留在旧位置：
  /// 卡片左半是旧壁纸、右半透明（撕裂）。
  late final Listenable _glassDockCardRepaint;

  /// The single day-view pager: pages are globally continuous across weeks
  /// (globalPage = (week-1)*visibleCount + dayIndex), so crossing a week
  /// boundary is an ordinary page transition on the same Scrollable — the
  /// gesture is never dropped and content follows the finger through the
  /// whole semester.
  PageController? _dayViewPageController;
  final Set<PageController> _pendingDayViewControllerDisposals = {};

  /// Recently disposed controllers are retained only as short-lived tombstones.
  /// A stale replacement frame can still call [_ensureDayViewPageController]
  /// before the old render tree detaches; two post-frame hops are enough to
  /// cover that race without growing for the lifetime of the screen.
  final Set<PageController> _disposedDayViewControllers = {};
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

  /// Anchor for the top-right "more" menu popup (positioned below this key).
  final GlobalKey _topMenuButtonKey = GlobalKey();
  final AppUpdateService _updateService = AppUpdateService();
  final SupportCreatorService _supportCreatorService = SupportCreatorService();
  final HomeUpdatePromptController _updatePromptController =
      HomeUpdatePromptController();
  bool _hasAvailableUpdate = false;
  bool _isUpdatePromptVisible = false;
  bool _hasPresentedUpdatePrompt = false;
  AppUpdateDownloadController? _homeDownloadController;
  StreamSubscription<SystemDownloadProgress>? _systemDownloadSubscription;
  bool? _lastUpdateCheckIncludePrerelease;
  bool _isCheckingForUpdate = false;
  TimetableProvider? _lastSyncedProvider;
  String? _lastSyncedProfileId;
  Timer? _dayAgendaProgressTimer;

  /// Minute-of-day the progress heartbeat last forwarded.
  int _lastProgressMinuteOfDay = -1;

  /// Verbose per-build day-view logging. Off by default: rebuilding all
  /// cached pager pages floods the log otherwise (see the heartbeat below).
  /// Flip temporarily when debugging the day view build pipeline.
  static bool logDayViewBuilds = false;

  /// Heartbeat for day-view ongoing-course badges / summary while day view
  /// is open. Deliberately not a setState on this State: only the day pages
  /// rebuild on each tick.
  ///
  /// Everything those pages render depends on wall-clock time at **minute**
  /// resolution (the provider matches "in progress" via hour*60+minute), so
  /// the 1 s probe only forwards a tick when the minute actually rolled over.
  /// Ticking every second used to rebuild all three cached pager pages with
  /// byte-identical output — log flood plus wasted list-rebuild CPU.
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

  /// 单次手势只允许一次日切换点击震感的闩锁。onPageChanged 在滑过每个页
  /// 中点时都会触发：快速甩动一次跨两页、或甩动后弹簧回弹再越过中点，
  /// 都会连响两次。指针按下 / 星期栏拖动开始时重新武装，settle 提交后也
  /// 重新武装（覆盖纯惯性问题）。
  bool _daySwipeHapticFired = false;
  late final _DayPagerFlickRescuePhysics _dayPagerPhysics =
      _DayPagerFlickRescuePhysics(
        takeRescueVelocity: _takeDayPagerRescueVelocity,
        parent: const ClampingScrollPhysics(),
      );

  /// Live handle bridging weekday-bar drags into the day pager, so the bar
  /// scrubs the pager follow-finger instead of snapping a week on release.
  /// Nulled via the position's onDragCanceled when the pager disposes the
  /// drag activity mid-gesture (e.g. the cross-week boundary handoff swaps
  /// controllers).
  Drag? _weekdayBarDrag;

  /// Bar→pager amplification captured at drag start: the bar spans a whole
  /// week, so sweeping its width must carry the pager across every visible
  /// day (7 pages with weekends shown, 5 without).
  double _weekdayBarDragScale = 1;
  int? _selectedDayOfWeek;
  int? _selectedWeekForDayView;
  int? _dayViewTransitionSourceWeek;
  int? _dayViewTransitionSourceDayOfWeek;
  double _dayViewAnchorFraction = 0.5;
  bool _isDaySwipeAnimating = false;

  /// 底栏点选的内嵌页 id（非 null 时内容区切换为该页，玻璃坞常驻）。
  String? _dockInlinePageId;

  bool _coupleOverlayEnabled = false;
  bool _sharedFreeSegmentsExpanded = false;

  static const int _sharedFreeVisibleSegmentLimit = 2;
  static const Duration _partnerScheduleStaleAfter = Duration(days: 7);

  /// Finger travel (after resistance) required to fire quick import.
  static const double _homePullQuickImportTriggerDistance =
      HyperosHomePullPhysics.triggerDistance;

  /// Visual / tracked pull cap; keep above the trigger so the indicator can
  /// overshoot slightly before release.
  static const double _homePullQuickImportMaxDistance =
      HyperosHomePullPhysics.maxVisualDistance;

  /// Damping range for the cubic curve f(x)=x - x\u00B2 + x\u00B3/3; f(1)\u00B7range = maxVisual.
  static const double _homePullDampingRange = HyperosHomePullPhysics.dampingRange;

  // Raw finger travel (clamped); visual offset = damped(touch/range)*range.
  double _homePullTouchDistance = 0;

  // Visual pull offset (derived from _homePullTouchDistance).
  double _homePullDragDistance = 0;

  // Threshold haptic latch: arm below trigger, fire once above.
  bool _homePullHapticArmed = true;

  // Spring-back (created in initState, disposed there).
  AnimationController? _homePullSettleSpring;
  int _homePullSettleGeneration = 0;
  bool _isHomePullQuickImportRunning = false;
  VoidCallback? _homePullQuickImportCancel;
  double? _wallpaperTopLuminance;

  /// Luminance of the wallpaper band the weekday/date chrome bar sits over.
  /// The status/title strip can be bright while the band below (where the
  /// weekday bar lives) is dark, so the weekday ink must not reuse the top
  /// sample.
  double? _wallpaperWeekdayLuminance;

  /// Luminance of the wallpaper band the day-view cards sit over. The top
  /// band can be dark while mid-screen is bright (or vice versa), so card ink
  /// must not reuse the chrome sample.
  double? _wallpaperBodyLuminance;
  String? _wallpaperLuminanceSampleKey;
  String? _wallpaperLuminanceRequestedKey;
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
    WidgetLaunchRouter.coupleOverlayRequestTick.addListener(
      _onExternalCoupleOverlayRequest,
    );
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
    // 日视图锚点展开/收起期间，卡片玻璃 fill 必须每帧重采样壁纸
    // （否则纹理停在旧屏幕位置，卡片呈现半边模糊半边透明）。
    _glassDockCardRepaint = _dayViewExpandController;
    _dayAgendaProgressTimer = widget.enableProgressTimer
        ? Timer.periodic(const Duration(seconds: 1), (_) {
            if (!mounted || !_isDayView) {
              return;
            }
            // The pages' output cannot change within one minute (ongoing
            // badges resolve time at minute granularity), so skip identical
            // seconds instead of dirtying three cached pager pages.
            final now = DateTime.now();
            final minuteOfDay = now.hour * 60 + now.minute;
            if (minuteOfDay == _lastProgressMinuteOfDay) {
              return;
            }
            _lastProgressMinuteOfDay = minuteOfDay;
            _dayAgendaProgressTick.value++;
          })
        : null;
    _homePullSettleSpring = AnimationController.unbounded(vsync: this)
      ..addListener(_driveHomePullSettle);
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
    WidgetLaunchRouter.coupleOverlayRequestTick.removeListener(
      _onExternalCoupleOverlayRequest,
    );
    _homePullQuickImportCancel?.call();
    _homeDownloadController?.cancel();
    _systemDownloadSubscription?.cancel();
    _updatePromptController.dispose();
    _homePullSettleSpring?.dispose();
    _weekPageController.dispose();
    _dayViewExpandController.dispose();
    _visibleWeekListenable.dispose();
    _dayAgendaProgressTimer?.cancel();
    _dayAgendaProgressTick.dispose();
    _dayHeaderPreview.dispose();
    final dayViewController = _dayViewPageController;
    if (dayViewController != null) {
      dayViewController.dispose();
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
        // 启动预热器若已完成亮度采样，首帧直接采用：标题/状态栏/星期栏的
        // 黑白墨极性第一帧即正确，不出现「按主题兜底再翻面」的闪变。仅在本页
        // 尚未开始采样时生效；异步精确采样照常运行并以同值幂等收敛。
        _seedWallpaperLuminanceFromStartupPrimer(settings);
        final glassDockForm =
            settings.homeNavigationForm == HomeNavigationForm.glassDock;
        final viewportSize = MediaQuery.sizeOf(context);
        final hasBackdrop = hasHomePageBackdropImage(settings);
        final statusBarShowsBackdrop = homePageRegionShowsBackdrop(
          settings,
          HomePageBackgroundScope.statusBar,
        );
        final timetableShowsBackdrop = homePageRegionShowsBackdrop(
          settings,
          HomePageBackgroundScope.timetable,
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
        // The page's own background is transparent over wallpaper, so derive
        // status-bar icon polarity from the sampled top band when available.
        final systemOverlayBackground = resolveHomePageStatusBarBackground(
          pageBackground: pageBackgroundColor,
          statusBarShowsBackdrop: statusBarShowsBackdrop,
          hasBackdrop: hasBackdrop,
          isDark: isDark,
          usesFrostedChrome: headerUsesFrostedChrome,
          wallpaperTopLuminance: _wallpaperTopLuminance,
        );

        _scheduleWallpaperLuminanceSampleIfNeeded(
          settings,
          viewportSize: viewportSize,
        );
        // After the sample lands: a hand-picked weekday ink can be invisible
        // over this wallpaper — never silently override it, explain instead.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _maybeWarnWeekdayInkContrast(provider, settings);
          }
        });
        final chromeForeground = _resolveHomeChromeForeground(
          // Only flip by wallpaper luminance when the header band actually
          // shows the wallpaper / frosted glass; with the scope toggled off it
          // paints the opaque page background and must use the theme ink.
          headerShowsWallpaper: headerUsesFrostedChrome,
          themeForeground: foruiTheme.colors.foreground,
        );
        final chromeMutedForeground = hasBackdrop
            ? homePageChromeMutedForeground(chromeForeground)
            : foruiTheme.colors.mutedForeground;

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
        // Gaussian cards sample the cached bitmap instead of a live
        // BackdropFilter while the day-view shell is animating.
        final useCoursePreblur =
            backdropBlurOn && cardStyle == CourseCardSurfaceStyle.gaussian;
        // The day-view summary card is drawn from this same bitmap whenever
        // the chrome band has glass — regardless of the course-card style.
        // Without it the card's PreblurredWallpaperAlignedFill paints nothing
        // and the card reads as transparent (bare wash over raw wallpaper).
        final useHomePreblur =
            useCoursePreblur || (backdropBlurOn && continuousChromeBlur);
        // 共享纯函数解析，与启动预热器构造同一份 PreblurredWallpaperCache
        // 键位（分支语义与原内联闭包一致）。
        final dockAppearance = FrostedAppearanceScope.of(context);
        final homePreblurSigma = resolveHomePreblurSigma(
          gaussianCardsDrive:
              backdropBlurOn && cardStyle == CourseCardSurfaceStyle.gaussian,
          // 预模糊位图服务的是首页玻璃带/摘要卡，跟随「首页玻璃带」开关。
          liquidGlassChrome:
              dockAppearance.glassMode == FrostedGlassMode.liquidGlass &&
              dockAppearance.liquidGlassHomeChromeEnabled,
          sheetBlurSigma: HyperosBlurredHeader.blurSigmaOf(context),
          liquidGlassTunedBlur:
              (dockAppearance.liquidGlassTuning ?? LiquidGlassTuning.defaults)
                  .blur,
        );
        // 与设置页课表预览完全同构的组采样结构：BackdropGroup 内先放全尺寸
        // UndimmedBackdropCapture（组内首个 filter 缓存整屏壁纸），chrome 玻璃
        // 带采样这份全尺寸背景。此前首页玻璃带只能采样自己 band bounds 的背
        // 景，折射位移在带边被钳制，观感与预览（组内全尺寸采样）不一致。
        Widget homeStack = BackdropGroup(
          child: Stack(
            fit: StackFit.expand,
            children: [
            if (hasBackdrop)
              followsWeekPager
                  ? HomePageSlidingBackdropLayer(
                      controller: _weekPageController,
                      pageCount: settings.semesterWeekCount,
                      settings: settings,
                    )
                  : homePageBackdropLayer(settings: settings),
            if (hasBackdrop && !statusBarShowsBackdrop)
              HomePageStatusBarBackdropMask(color: pageBackgroundColor),
            // 组内首个 grouped filter：缓存未压暗的全屏壁纸供玻璃带采样，
            // 与预览的 UndimmedBackdropCapture 同款、同相对位置。
            if (continuousChromeBlur)
              const Positioned.fill(child: UndimmedBackdropCapture()),
            // Single continuous glass for title + weekday (no time-column blur).
            // Stays fixed above the sliding wallpaper so chrome text stays sharp
            // while the photo moves as one continuous sheet.
            if (continuousChromeBlur)
              HomePageContinuousChromeFrostedOverlay(
                headerBlurEnabled: settings.homePageHeaderBlurEnabled,
                weekdayBarBlurEnabled: settings.homePageWeekdayBarBlurEnabled,
                includeStatusBar: statusBarShowsBackdrop,
                weekdayBarHeight: _weekDayHeaderHeight,
              ),
            HyperosRootPage(
              overlayHeader: false,
              resizeToAvoidBottomInset: false,
              backgroundColor: scaffoldBackgroundColor,
              headerDecoration: BoxDecoration(color: headerBarColor),
              headerPadding: EdgeInsets.fromLTRB(
                8,
                0,
                8,
                headerUsesFrostedChrome ? 0.0 : 2.0,
              ),
              systemOverlayStyle: HyperosColors.systemOverlayForBackground(
                systemOverlayBackground,
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
                KeyedSubtree(
                  key: _topMenuButtonKey,
                  child: FHeaderAction(
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
                                color: HyperosColors.destructive, // 更新红点与危险语义统一色
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
                ),
              ],
              childPad: false,
              child: Padding(
                padding: EdgeInsets.only(
                  // 日课表的列表视口保持全屏：避让改为列表自身的滚动
                  // padding（见 _buildExpandedDayColumnView），滚动中卡片
                  // 连续穿过底部避让带，不在避让边界被硬裁出一条与磨砂
                  // 卡片色差明显的「生壁纸」空带；周课表网格不可滚动，
                  // 避让仍由这里的布局 padding 承担。
                  bottom: glassDockForm && !_isDayView
                      ? 0.0
                      : 0,
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: provider.isLoading
                      // Single-stage: system splash already covers loading;
                      // render matching background to avoid spinner flash
                      // if provider momentarily reports loading post-splash.
                      ? ColoredBox(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF121212)
                              : Colors.white,
                        )
                      : MediaQuery.removeViewInsets(
                          context: context,
                          removeBottom: true,
                          child: Stack(
                            fit: StackFit.expand,
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
            ),
            ],
          ),
        );
        // 玻璃坞形态下课表（含壁纸）与设置页都常驻挂载，用 Offstage 切换：
        // - 设置页的滚动位置与大标题折叠状态不随 Tab 切换丢失（切走再切回，
        //   标题保持离开时的折叠态）；
        // - 壁纸层随 homeStack 常驻，解码缓存不失效，切回课表不黑闪。
        // 玻璃坞导航始终由 [_wrapWithGlassDock] 浮在最上层。
        final Widget dockContent = useHomePreblur
            ? PreblurredWallpaperScope(
                // Same pre-blur model as the week grid: sample one cached
                // frost bitmap by card screen position. In day view the week
                // pager is locked, so drive repaints from the day agenda pager
                // and treat the wallpaper as screen-fixed (it never follows
                // the day swipe).
                wallpaperPath: resolveHomePageBackdropImagePath(settings),
                blurSigma: homePreblurSigma,
                pageController: _isDayView
                    ? _ensureDayViewPageController(settings)
                    : _weekPageController,
                followsPager: _isDayView ? false : followsWeekPager,
                // 锚点展开/收起与设置页拖动转场期间卡片在移动而壁纸
                // 屏幕固定：fill 必须每帧重采样，否则纹理停在旧屏幕位置
                // （卡片半边模糊半边透明）。合并两个动画统一驱动重采样。
                repaint: _glassDockCardRepaint,
                enabled: true,
                child: homeStack,
              )
            : homeStack;
        if (!glassDockForm) {
          return _wrapWithGlassDock(
            dockContent,
            glassDockForm: false,
            settings: settings,
            l10n: l10n,
          );
        }
        // 底栏为可编排快捷区：页面类条目在首页栈内切换（内嵌宿主，
        // 玻璃坞常驻悬浮），仅未登记的流程页才推入新路由。系统返回
        // 优先收回内嵌页而不是退出应用。
        final inlineId = _dockInlinePageId;
        final inlineBuilder = inlineId == null ? null : inlineDockPageFor(inlineId);
        Widget hostedContent = inlineBuilder == null
            ? dockContent
            : Stack(
                fit: StackFit.expand,
                children: [
                  dockContent,
                  // 与旧「设置 Tab」一致：点底栏闪现直切，无滑动转场。
                  Positioned.fill(
                    child: Material(
                      type: MaterialType.transparency,
                      child: Scaffold(
                        backgroundColor:
                            Theme.of(context).scaffoldBackgroundColor,
                        body: HyperosSubpageNoBack(
                          // 玻璃坞满屏悬浮对所有内嵌页生效：注入底部滚动
                          // 余量（与日/周课表同口径），列表末尾可整体滑到
                          // 药丸上方；HyperosListView 自动消费，新增内嵌
                          // 页无须逐页适配。
                          child: GlassDockScrollReliefScope(
                            inset: _glassDockContentScrollInset(settings),
                            child: Builder(builder: inlineBuilder),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
        return PopScope(
          canPop: inlineId == null,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && mounted && _dockInlinePageId != null) {
              setState(() => _dockInlinePageId = null);
            }
          },
          child: _wrapWithGlassDock(
            hostedContent,
            glassDockForm: true,
            settings: settings,
            l10n: l10n,
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
    // Keep the old controller alive through the replacement frame. AnimatedBuilder
    // detaches from the old PageController during that rebuild; disposing at
    // the first post-frame callback is still early enough to race didUpdateWidget.
    final oldController = _dayViewPageController;
    _dayViewPageController = null;
    if (oldController != null) {
      _disposeDayViewControllerAfterReplacement(oldController);
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

  /// 外部入口（TA 课表的桌面卡片点击）请求显示情侣覆盖层：路由器先持久化
  /// 打开覆盖层（覆盖冷启动），再 bump 请求计数；本页只在「本地状态与持久化
  /// 值发散」时单向跟随持久化值，与页内爱心开关（先 setState 后异步持久化）
  /// 不竞态。
  void _onExternalCoupleOverlayRequest() {
    if (!mounted) {
      return;
    }
    final provider = context.read<TimetableProvider>();
    if (!provider.hasPartnerBinding) {
      return;
    }
    final persisted = provider.settings.coupleTimetableOverlayEnabled;
    if (persisted == _coupleOverlayEnabled) {
      return;
    }
    setState(() {
      _coupleOverlayEnabled = persisted;
    });
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
    bool animate = true,
  }) async {
    final normalizedWeek = _clampWeek(week, settings.semesterWeekCount);
    final isSameSelection =
        _isDayView &&
        _selectedWeekForDayView == normalizedWeek &&
        _selectedDayOfWeek == dayOfWeek;
    if (isSameSelection) {
      await _closeDayView(settings, animate: animate);
      return;
    }
    if (_isDayView && _selectedWeekForDayView == normalizedWeek) {
      await _switchDayWithinWeek(settings, normalizedWeek, dayOfWeek);
      return;
    }
    final shouldAnimateOpen = animate && !_isDayView;
    if (!_isDayView) {
      _recreateDayViewPageController(
        settings,
        week: normalizedWeek,
        dayOfWeek: dayOfWeek,
      );
    }
    // Collapse the expand controller *before* the overlay mounts so the first
    // painted frame is the small/transparent state. Otherwise a leftover value
    // of 1 (restore / interrupted close / hot reload) makes open look like a
    // hard cut, while close still has a visible reverse animation. The dock's
    // flash path (shouldAnimateOpen=false) inverts this on purpose: land on 1
    // so the first painted frame is the fully expanded day view.
    if (!_isDayView) {
      _dayViewExpandController.value = shouldAnimateOpen ? 0 : 1;
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

  Future<void> _closeDayView(
    TimetableSettings settings, {
    bool animate = true,
  }) async {
    if (!_isDayView) {
      return;
    }
    _maybeSelectionClick(settings);
    if (_dayViewExpandController.value > 0) {
      if (animate) {
        await _dayViewExpandController.reverse();
        if (!mounted) {
          return;
        }
      } else {
        // 底栏闪现直切：跳过收起动画直接归零，与下方清理同帧生效。
        _dayViewExpandController.value = 0;
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
    // Globally continuous across weeks: no edge pages, crossing a week is a
    // normal one-page transition on the single day pager.
    return (week - 1) * visibleDays.length + dayIndex;
  }

  int _dayViewPageCount(TimetableSettings settings) {
    return _visibleDayNumbers(settings).length * settings.semesterWeekCount;
  }

  _DayViewPageTarget _dayViewTargetForPage(
    TimetableSettings settings,
    int page,
  ) {
    final visibleDays = _visibleDayNumbers(settings);
    final count = visibleDays.length;
    final week = (page ~/ count) + 1;
    return _DayViewPageTarget(week: week, dayOfWeek: visibleDays[page % count]);
  }

  PageController _ensureDayViewPageController(TimetableSettings settings) {
    final existing = _dayViewPageController;
    // Never hand out a controller that is pending disposal: the pre-blur
    // fill (and the PageView) would latch onto it, and once the deferred
    // disposal runs a stale LayoutBuilder rebuild can hit the disposed
    // controller and throw.
    //
    // A client-less controller is NOT stale: several build-pass call sites
    // (pre-blur scope, weekday bar, day panel) resolve the controller before
    // the PageView attaches. Replacing a healthy-but-unattached controller
    // here used to orphan the weekday bar's AnimatedBuilder subscription on
    // the first instance, freezing the bar at the crossing-start frame while
    // the pager kept scrolling.
    if (existing != null &&
        !_pendingDayViewControllerDisposals.contains(existing) &&
        !_disposedDayViewControllers.contains(existing)) {
      return existing;
    }
    final fresh = _createDayViewPageController(settings);
    _dayViewPageController = fresh;
    if (existing != null) {
      // Stale controller (created but never attached, or detached after the
      // day view closed): replace it instead of reusing a dead position.
      _disposeDayViewControllerAfterReplacement(existing);
    }
    return fresh;
  }

  PageController _createDayViewPageController(
    TimetableSettings settings, {
    int? week,
    int? dayOfWeek,
  }) {
    return PageController(
      initialPage: _dayViewPageIndexForDay(
        settings,
        week ?? _selectedWeekForDayView ?? _visibleWeek,
        dayOfWeek ?? _selectedDayOfWeek ?? 1,
      ),
    );
  }

  /// Recreates the single day pager anchored on the given day (used when the
  /// day view opens so the first painted frame lands on the requested day).
  /// The old controller is kept alive for two post-frame hops so the
  /// replacing tree can detach.
  void _recreateDayViewPageController(
    TimetableSettings settings, {
    int? week,
    int? dayOfWeek,
  }) {
    final old = _dayViewPageController;
    _dayViewPageController = _createDayViewPageController(
      settings,
      week: week,
      dayOfWeek: dayOfWeek,
    );
    if (old != null) {
      _disposeDayViewControllerAfterReplacement(old);
    }
  }

  void _rememberDisposedDayViewController(PageController controller) {
    if (!_disposedDayViewControllers.add(controller)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _disposedDayViewControllers.remove(controller);
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _disposedDayViewControllers.remove(controller);
      });
    });
  }

  void _disposeDayViewControllerAfterReplacement(PageController controller) {
    if (!_pendingDayViewControllerDisposals.add(controller)) {
      return;
    }

    // The replacement widget tree builds and detaches over a couple of
    // frames. Disposal waits until nothing can reach the controller any
    // more: the field was swapped (no future build will hand it out) and no
    // live PageView still holds it. The pre-blur fill re-latches its
    // listener in the same build that swaps the field, so this ordering
    // guarantees the listener is detached before dispose — otherwise a
    // stale LayoutBuilder rebuild can hit the disposed controller and throw
    // (a PageController used after being disposed).
    void retryDispose() {
      if (!mounted) {
        if (_pendingDayViewControllerDisposals.remove(controller)) {
          controller.dispose();
        }
        return;
      }
      if (_dayViewPageController == controller || controller.hasClients) {
        if (controller.hasClients) {
          // A PageView still holds this controller: force a rebuild so the
          // next _ensureDayViewPageController swaps in a fresh controller
          // and the old one detaches, then re-check next frame.
          setState(() {});
        }
        _pendingDayViewControllerDisposals.add(controller);
        WidgetsBinding.instance.addPostFrameCallback((_) => retryDispose());
        WidgetsBinding.instance.scheduleFrame();
        return;
      }
      if (_pendingDayViewControllerDisposals.remove(controller)) {
        _rememberDisposedDayViewController(controller);
        controller.dispose();
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        if (_pendingDayViewControllerDisposals.remove(controller)) {
          controller.dispose();
        }
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => retryDispose());
      WidgetsBinding.instance.scheduleFrame();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  int _displayedDayForWeek(int week) {
    if (_dayViewTransitionSourceWeek == week &&
        _dayViewTransitionSourceDayOfWeek != null) {
      return _dayViewTransitionSourceDayOfWeek!;
    }
    return _selectedDayOfWeek ?? 1;
  }

  void _syncDayViewPageWithSelection(TimetableSettings settings) {
    if (_isSyncingDayViewPage || !_isDayView) {
      return;
    }
    if (_dayViewTransitionSourceWeek != null) {
      return;
    }
    final controller = _dayViewPageController;
    if (controller == null || !controller.hasClients) {
      return;
    }
    // A live drag / fling owns the pager: selection commit is deferred to
    // ScrollEnd, so a mid-gesture rebuild would read the stale selection here
    // and jumpToPage would yank the fling back to the old page.
    if (controller.position.isScrollingNotifier.value) {
      return;
    }
    final week = _selectedWeekForDayView ?? _visibleWeek;
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
    final controller = _ensureDayViewPageController(settings);
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
      // Same single pager scrolls to the target day; the week page follows
      // for state consistency (it is faded out while the day view is open).
      await _switchDayWithinWeek(
        settings,
        normalizedTargetWeek,
        targetDayOfWeek,
        animate: animateWeekPage,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _dayViewTransitionSourceWeek = null;
        _dayViewTransitionSourceDayOfWeek = null;
      });
      if (normalizedTargetWeek != _visibleWeek) {
        await _jumpToWeek(
          provider,
          normalizedTargetWeek,
          animatePage: animateWeekPage,
        );
      }
    } finally {
      _isDaySwipeAnimating = false;
      // 日视图滑动区外层的 IgnorePointer 在 build 时读取该标志：上面所有
      // setState 都发生在标志仍为 true 的期间，若此处不复位后再补一次重建，
      // 「回到今天」转场结束后 ignoring:true 会永久滞留，日视图左右滑动
      // 就再也无响应。必须显式重建一帧把指针放行。
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _handleDayViewPageChanged(
    TimetableProvider provider,
    TimetableSettings settings,
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
    final target = _dayViewTargetForPage(settings, page);
    if (kDebugMode) {
      debugPrint(
        '[DayPager] pageChanged($page) -> week=${target.week} '
        'day=${target.dayOfWeek}',
      );
    }
    if (_selectedWeekForDayView == target.week &&
        _selectedDayOfWeek == target.dayOfWeek) {
      return;
    }
    // Midpoint preview: recolour the weekday header the moment the pager
    // crosses a page midpoint (matching the indicator), via the scoped
    // notifier — no full-State rebuild while the fling is still running.
    // Committing the selection here instead (setState + persist + week-page
    // jump) rebuilt the whole home screen on *every* page crossing — a single
    // real-device swipe crosses 30+ pages and each rebuild re-samples the
    // wallpaper blur, which starved the main thread into an ANR. The actual
    // selection commit stays on ScrollEnd (_settleDayViewPage), which now
    // re-checks until the pager is truly stationary.
    _dayHeaderPreview.value = (target.week, target.dayOfWeek);
    // 单次手势只震一次：快速甩动跨两页 / 弹簧回弹再过中点时，onPageChanged
    // 会连发多次，不闩锁就会一次滑动触发两次震动。
    if (!_daySwipeHapticFired) {
      _daySwipeHapticFired = true;
      _maybeSelectionClick(settings);
    }
  }

  /// Commits the settled day-pager page once the horizontal scroll has fully
  /// stopped, mirroring the week pager's ScrollEnd → finalize model so the
  /// setState + persist never land mid-animation. A cross-week landing is an
  /// ordinary page here (the pager is globally continuous), so the week page
  /// follows the committed week for state consistency.
  void _settleDayViewPage(
    TimetableProvider provider,
    TimetableSettings settings,
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
    final controller = _dayViewPageController;
    if (controller == null || !controller.hasClients) {
      return;
    }
    // A ScrollEnd fires at the end of *every* activity, including the frame
    // where a new gesture begins (the previous drag's end is dispatched
    // before this drag's first move). Under fake-async test frames the snap
    // spring can still be running at that point (page=0.9988, not 1.0), so a
    // stale end would commit the old page again and the panel lags the real
    // content by one day. Rather than dropping this commit opportunity
    // entirely (which would lose the fix for consecutive quick swipes),
    // re-check on the next frame until the pager is truly stationary; the
    // commit then lands on the page the content actually shows.
    if (controller.position.isScrollingNotifier.value) {
      _scheduleDayViewSettleRetry(provider, settings);
      return;
    }
    final page = controller.page?.round();
    if (page == null) {
      return;
    }
    final target = _dayViewTargetForPage(settings, page);
    if (kDebugMode) {
      debugPrint(
        '[DayPager] settle: rawPage=${controller.page?.toStringAsFixed(3)} '
        '-> page=$page week=${target.week} day=${target.dayOfWeek} '
        'alreadySelected=${_selectedWeekForDayView == target.week && _selectedDayOfWeek == target.dayOfWeek}',
      );
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
    // 手势收尾：重新武装点击震感，下一次滑动（含纯惯性续滑）可再次触发。
    _daySwipeHapticFired = false;
    if (target.week != _visibleWeek && !_isSyncingWeekPage) {
      unawaited(_jumpToWeek(provider, target.week, animatePage: false));
    }
  }

  /// Re-checks the day pager on the next frame after a ScrollEnd arrived while
  /// the pager was still scrolling (a stale end interleaved with the next
  /// gesture). Once the pager is truly stationary the selection is committed
  /// to the page the content actually shows; if a fresh gesture owns the
  /// pager we wait for its own ScrollEnd instead of polling forever.
  void _scheduleDayViewSettleRetry(
    TimetableProvider provider,
    TimetableSettings settings,
  ) {
    if (!mounted || !_isDayView) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isDayView) {
        return;
      }
      final controller = _dayViewPageController;
      if (controller == null || !controller.hasClients) {
        return;
      }
      if (controller.position.isScrollingNotifier.value) {
        // Still mid-flight (snap spring running, or a new drag already owns
        // the pager): the next ScrollEnd will retry again.
        return;
      }
      _settleDayViewPage(provider, settings);
    });
  }

  /// Weekday-bar drag → day-pager bridge. The bar acts as a visible-day-count
  /// (7x) scrubber over the day pager: bar deltas are amplified and injected
  /// straight into the pager's ScrollPosition, so the content follows the
  /// finger at week-per-bar-width speed while the bar itself moves slowly.
  void _startWeekdayBarDrag(
    TimetableSettings settings,
    DragStartDetails details,
  ) {
    _weekdayBarDrag?.cancel();
    _weekdayBarDrag = null;
    if (_isDaySwipeAnimating) {
      return;
    }
    final controller = _dayViewPageController;
    if (controller == null || !controller.hasClients) {
      return;
    }
    _weekdayBarDragScale = _visibleDayNumbers(settings).length.toDouble();
    // 星期栏刮擦也是一次手势：整段拖动只保留一次日切换点击震感。
    _daySwipeHapticFired = false;
    _weekdayBarDrag = controller.position.drag(details, () {
      _weekdayBarDrag = null;
    });
  }

  void _updateWeekdayBarDrag(DragUpdateDetails details) {
    final drag = _weekdayBarDrag;
    if (drag == null) {
      return;
    }
    final dx =
        (details.primaryDelta ?? details.delta.dx) * _weekdayBarDragScale;
    drag.update(
      DragUpdateDetails(
        sourceTimeStamp: details.sourceTimeStamp,
        delta: Offset(dx, 0),
        primaryDelta: dx,
        globalPosition: details.globalPosition,
        localPosition: details.localPosition,
      ),
    );
  }

  void _endWeekdayBarDrag(DragEndDetails details) {
    final drag = _weekdayBarDrag;
    _weekdayBarDrag = null;
    if (drag == null) {
      return;
    }
    // Release velocity is amplified like the deltas, then the pager's own
    // snap physics (_dayPagerPhysics) settles it — same pipeline as a direct
    // content fling, so midpoint preview / ScrollEnd commit stay intact.
    final vx = details.velocity.pixelsPerSecond.dx * _weekdayBarDragScale;
    drag.end(
      DragEndDetails(
        velocity: Velocity(pixelsPerSecond: Offset(vx, 0)),
        primaryVelocity: vx,
      ),
    );
  }

  void _cancelWeekdayBarDrag() {
    final drag = _weekdayBarDrag;
    _weekdayBarDrag = null;
    drag?.cancel();
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

  /// Schedules wallpaper luminance sampling without sync I/O in build.
  ///
  /// File existence is checked asynchronously; results are cached per path,
  /// viewport and wallpaper alignment so a cover crop change cannot keep using
  /// a sample from an off-screen part of the image.
  /// 采用启动预热器（HomeStartupVisualPrimer）缓存的壁纸亮度带作初值。
  ///
  /// 只在冷启动首帧前的空窗期生效一次：本页任何亮度字段已被赋值或常规
  /// 异步采样已启动（requestedKey 非空）时直接返回，绝不覆盖精确采样结果。
  void _seedWallpaperLuminanceFromStartupPrimer(
    TimetableSettings settings,
  ) {
    if (_wallpaperTopLuminance != null ||
        _wallpaperWeekdayLuminance != null ||
        _wallpaperBodyLuminance != null ||
        _wallpaperLuminanceRequestedKey != null) {
      return;
    }
    final bands = HomeStartupVisualPrimer.seededBandsFor(
      resolveHomePageBackdropImagePath(settings),
    );
    if (bands == null) {
      return;
    }
    _wallpaperTopLuminance = bands.top;
    _wallpaperWeekdayLuminance = bands.weekday;
    _wallpaperBodyLuminance = bands.body;
  }

  void _scheduleWallpaperLuminanceSampleIfNeeded(
    TimetableSettings settings, {
    required Size viewportSize,
  }) {
    final path = resolveHomePageBackdropImagePath(settings);
    if (path == null || path.isEmpty) {
      if (_wallpaperTopLuminance != null ||
          _wallpaperWeekdayLuminance != null ||
          _wallpaperBodyLuminance != null ||
          _wallpaperLuminanceSampleKey != null ||
          _wallpaperLuminanceRequestedKey != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          setState(() {
            _wallpaperTopLuminance = null;
            _wallpaperWeekdayLuminance = null;
            _wallpaperBodyLuminance = null;
            _wallpaperLuminanceSampleKey = null;
            _wallpaperLuminanceRequestedKey = null;
            _wallpaperLuminanceFileExists = false;
          });
        });
      }
      return;
    }
    final key = _wallpaperLuminanceKey(
      path: path,
      viewportSize: viewportSize,
      alignX: settings.homePageWallpaperAlignX,
      alignY: settings.homePageWallpaperAlignY,
    );
    if (_wallpaperLuminanceRequestedKey == key &&
        (_wallpaperLuminanceSampleKey == key ||
            !_wallpaperLuminanceFileExists)) {
      return;
    }
    unawaited(
      _ensureWallpaperLuminanceForPath(
        path,
        viewportSize: viewportSize,
        alignX: settings.homePageWallpaperAlignX,
        alignY: settings.homePageWallpaperAlignY,
        key: key,
      ),
    );
  }

  String _wallpaperLuminanceKey({
    required String path,
    required Size viewportSize,
    required double alignX,
    required double alignY,
  }) {
    return '$path|${viewportSize.width}x${viewportSize.height}|'
        '${alignX.clamp(-1.0, 1.0)}|${alignY.clamp(-1.0, 1.0)}';
  }

  Future<void> _ensureWallpaperLuminanceForPath(
    String path, {
    required Size viewportSize,
    required double alignX,
    required double alignY,
    required String key,
  }) async {
    if (_wallpaperLuminanceRequestedKey == key &&
        _wallpaperLuminanceSampleKey == key &&
        _wallpaperTopLuminance != null) {
      return;
    }
    _wallpaperLuminanceRequestedKey = key;
    final fileExists = await File(path).exists();
    if (!mounted || _wallpaperLuminanceRequestedKey != key) {
      return;
    }
    if (!fileExists) {
      if (_wallpaperTopLuminance != null ||
          _wallpaperWeekdayLuminance != null ||
          _wallpaperBodyLuminance != null ||
          _wallpaperLuminanceSampleKey != null ||
          _wallpaperLuminanceFileExists) {
        setState(() {
          _wallpaperTopLuminance = null;
          _wallpaperWeekdayLuminance = null;
          _wallpaperBodyLuminance = null;
          _wallpaperLuminanceSampleKey = null;
          _wallpaperLuminanceFileExists = false;
        });
      }
      return;
    }
    _wallpaperLuminanceFileExists = true;
    _wallpaperLuminanceSampleKey = key;
    await _loadWallpaperLuminance(
      path,
      viewportSize: viewportSize,
      alignX: alignX,
      alignY: alignY,
      key: key,
    );
  }

  Future<void> _loadWallpaperLuminance(
    String path, {
    required Size viewportSize,
    required double alignX,
    required double alignY,
    required String key,
  }) async {
    final bands = await sampleHomePageWallpaperLuminanceBands(
      path,
      viewportSize: viewportSize,
      alignX: alignX,
      alignY: alignY,
    );
    if (!mounted || _wallpaperLuminanceSampleKey != key) {
      return;
    }
    if (_wallpaperTopLuminance == bands?.top &&
        _wallpaperWeekdayLuminance == bands?.weekday &&
        _wallpaperBodyLuminance == bands?.body) {
      return;
    }
    setState(() {
      _wallpaperTopLuminance = bands?.top;
      _wallpaperWeekdayLuminance = bands?.weekday;
      _wallpaperBodyLuminance = bands?.body;
    });
  }

  /// Luminance used by both weekday rendering and the contrast explainer.
  /// When the weekday glass band is enabled, its scrim follows the header/top
  /// sample, so the warning must judge the same effective backdrop as the UI.
  double? _weekdayInkLuminance(TimetableSettings settings) {
    return settings.homePageWeekdayBarBlurEnabled
        ? _wallpaperTopLuminance
        : _wallpaperWeekdayLuminance ?? _wallpaperTopLuminance;
  }

  /// One-shot heads-up when a hand-picked weekday-bar ink has too little
  /// contrast against the current wallpaper. The ink is temporarily auto-flipped
  /// for readability ([homePageOverWallpaperInk]); this explains why the custom
  /// colour is not showing and offers restoring the default (auto B/W).
  void _maybeWarnWeekdayInkContrast(
    TimetableProvider provider,
    TimetableSettings settings,
  ) {
    // Judge custom ink against the band actually behind the weekday bar, not
    // the status/title strip above it.
    final luminance = _weekdayInkLuminance(settings);
    if (luminance == null || _weekdayInkWarningShowing) {
      return;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!hasHomePageBackdropImage(settings)) {
      return;
    }
    final configuredHex = isDark
        ? settings.weekdayBarFontColorDark
        : settings.weekdayBarFontColorLight;
    final defaultHex = isDark
        ? TimetableSettings.defaultWeekdayBarFontColorDark
        : TimetableSettings.defaultWeekdayBarFontColorLight;
    // Default ink already auto-flips with the wallpaper; only a custom pick
    // can go invisible (and trigger the temporary auto flip).
    if (homePageInkUsesBuiltInDefault(configuredHex, defaultHex)) {
      return;
    }
    final ink = tryParseHexColor(configuredHex);
    if (ink == null) {
      return;
    }
    // ~WCAG ratio against the sampled band; photos are busy, so anything
    // above 3:1 is left alone — this only catches "nearly invisible".
    if (homePageInkHasSufficientContrast(ink, luminance)) {
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
            label: l10n.gotItAction,
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
    required bool headerShowsWallpaper,
    required Color themeForeground,
  }) {
    if (!headerShowsWallpaper) {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasBackdrop = hasHomePageBackdropImage(settings);
    // Opaque/no-wallpaper chrome still needs a separator, but a full 1dp
    // ThemeData outline lands as a dark multi-physical-pixel band on dense
    // Android screens. Keep the wallpaper path's existing border untouched
    // and use the lighter HyperOS divider token only for the fallback.
    final subtleBorder = hasBackdrop
        ? context.theme.colors.border
        : HyperosColors.dividerLine(context);
    final dividerWidth = hasBackdrop ? 1.0 : 0.5;
    // Only flip by wallpaper luminance when this band actually shows the
    // wallpaper / frosted glass; with the scope toggled off it paints the
    // opaque page background and must use the theme / configured ink.
    final weekdayChromeOverWallpaper =
        hasBackdrop &&
        (homePageRegionShowsBackdrop(
              settings,
              HomePageBackgroundScope.weekdayBar,
            ) ||
            settings.homePageWeekdayBarBlurEnabled);
    // Judge ink from the band actually behind the weekday bar, not the
    // status/title strip above it — the two can differ on the same photo.
    // With the weekday glass band on, follow the band's scrim polarity (the
    // scrim derives from the top sample) so ink and wash never fight.
    final weekdayLuminance = settings.homePageWeekdayBarBlurEnabled
        ? _wallpaperTopLuminance
        : _wallpaperWeekdayLuminance ?? _wallpaperTopLuminance;
    // Week label sits in the weekday chrome band: auto-invert default black/white
    // over a dark wallpaper; unreadable custom ink follows the same fallback.
    final weekLabelColor = homePageOverWallpaperInk(
      configuredHex: isDark
          ? settings.weekdayBarFontColorDark
          : settings.weekdayBarFontColorLight,
      defaultHex: isDark
          ? TimetableSettings.defaultWeekdayBarFontColorDark
          : TimetableSettings.defaultWeekdayBarFontColorLight,
      themeFallback: colorScheme.onSurface,
      hasBackdrop: weekdayChromeOverWallpaper,
      wallpaperLuminance: weekdayLuminance,
    );
    final visibleDays = _visibleDayNumbers(settings);

    // Shared full-row builder: week label + back-to-current-week + the seven
    // day slots + the selection indicator — one complete weekday bar row.
    // Week view renders one row per page (it scrolls with that page); day
    // view stacks three consecutive weeks and translates them with the pager
    // so the WHOLE bar slides like the week view's header.
    Widget fullWeekRowFor(int rowWeek, {required bool showExtras}) {
      return Row(
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
                      l10n.currentWeekCompact(rowWeek),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: weekLabelColor,
                      ),
                    ),
                  ),
                ),
                // （内嵌「回本周」小字已移除）
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
                        final date = _dateForWeekDay(
                          settings,
                          rowWeek,
                          dayOfWeek,
                        );
                        final isToday =
                            date != null && _isSameDate(date, DateTime.now());
                        final isSelected = _isSelectedDay(rowWeek, dayOfWeek);
                        final configuredWeekdayHex = isDark
                            ? settings.weekdayBarFontColorDark
                            : settings.weekdayBarFontColorLight;
                        final configuredAccentHex = isDark
                            ? settings.weekdayBarAccentColorDark
                            : settings.weekdayBarAccentColorLight;
                        // Default weekday ink flips with the band behind this
                        // bar; user-custom hex is kept (auto-flipped only when
                        // it would be unreadable). Accent (today/selected) gets
                        // the same readability fallback so the blue "today"
                        // column never vanishes into the photo.
                        final weekdayColor = homePageOverWallpaperInk(
                          configuredHex: configuredWeekdayHex,
                          defaultHex: isDark
                              ? TimetableSettings.defaultWeekdayBarFontColorDark
                              : TimetableSettings
                                    .defaultWeekdayBarFontColorLight,
                          themeFallback: colorScheme.onSurface,
                          hasBackdrop: weekdayChromeOverWallpaper,
                          wallpaperLuminance: weekdayLuminance,
                        );
                        final accentColor = homePageOverWallpaperAccent(
                          configuredHex: configuredAccentHex,
                          themeFallback: colorScheme.primary,
                          hasBackdrop: weekdayChromeOverWallpaper,
                          wallpaperLuminance: weekdayLuminance,
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
                        final hasExamOnDay =
                            date != null && provider.hasExamOnDate(date);

                        return Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: ValueKey(
                                'weekday-header-$rowWeek-$dayOfWeek',
                              ),
                              borderRadius: BorderRadius.circular(14),
                              onTapDown: (details) =>
                                  _captureDayViewAnchor(details.globalPosition),
                              onTap: () => _toggleDayView(
                                week: rowWeek,
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
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: showsTodayMarker
                                          ? accentColor.withValues(alpha: 0.35)
                                          : Colors.transparent,
                                      width: showsTodayMarker ? 2 : 0,
                                    ),
                                  ),
                                ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // 固定 40dp 的星期栏扣掉 3+3 内边距和 0.5
                                    // 分隔线后格子只剩 33.5dp，平铺考试红点会把
                                    // 内容顶到 34dp 溢出；改悬浮层后基础内容恒
                                    // 为 28dp，任何外观模式都有余量。
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                    if (hasExamOnDay)
                                      Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Container(
                                          key: const ValueKey(
                                            'weekday-exam-dot',
                                          ),
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
                if (showExtras)
                  _buildWeekdaySelectionIndicator(
                    settings: settings,
                    week: rowWeek,
                    visibleDays: visibleDays,
                    wallpaperOverChrome: weekdayChromeOverWallpaper,
                    wallpaperLuminance: weekdayLuminance,
                  ),
              ],
            ),
          ),
        ],
      );
    }

    // Current pager page as a continuous double (day view only).
    double dayViewPagerPage() {
      final controller = _dayViewPageController;
      if (controller == null) {
        return 0;
      }
      if (!controller.hasClients) {
        return controller.initialPage.toDouble();
      }
      return controller.page ?? controller.initialPage.toDouble();
    }

    return Container(
      height: _weekDayHeaderHeight,
      padding: EdgeInsets.zero,
      decoration: hideBottomBorder
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(color: subtleBorder, width: dividerWidth),
              ),
            ),
      child: _isDayView && _dayViewPageController != null
          ? AnimatedBuilder(
              animation: _dayViewPageController!,
              builder: (context, _) {
                // The whole bar (week label + day row + indicator) is one row
                // per week. Within a week it stays put (the indicator follows
                // the pager); only during the cross-week transition does the
                // outgoing week slide out and the next week slide in — glued
                // to the pager's position, like the week view's per-page
                // header moving under the finger.
                final rawPage = dayViewPagerPage();
                final count = visibleDays.length;
                final totalWeeks = settings.semesterWeekCount;
                final weekIndex = (rawPage / count).floor().clamp(
                  0,
                  totalWeeks - 1,
                );
                final inWeekPos = rawPage - weekIndex * count;
                final isCrossing = inWeekPos >= count - 1;
                final progress = isCrossing
                    ? (inWeekPos - (count - 1)).clamp(0.0, 1.0)
                    : 0.0;
                final weekRow = weekIndex + 1;
                final nextWeek = weekRow + 1;
                final extrasOnOutgoing = !isCrossing || progress < 0.5;
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final barWidth = constraints.maxWidth;
                    return ClipRect(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (isCrossing)
                            Transform.translate(
                              offset: Offset(-progress * barWidth, 0),
                              child: SizedBox(
                                width: barWidth,
                                child: fullWeekRowFor(
                                  weekRow,
                                  showExtras: extrasOnOutgoing,
                                ),
                              ),
                            ),
                          if (isCrossing)
                            Transform.translate(
                              offset: Offset((1 - progress) * barWidth, 0),
                              child: SizedBox(
                                width: barWidth,
                                child: fullWeekRowFor(
                                  nextWeek,
                                  showExtras: !extrasOnOutgoing,
                                ),
                              ),
                            ),
                          if (!isCrossing)
                            fullWeekRowFor(weekRow, showExtras: true),
                        ],
                      ),
                    );
                  },
                );
              },
            )
          : fullWeekRowFor(week, showExtras: true),
    );
  }

  Widget _buildWeekdaySelectionIndicator({
    required TimetableSettings settings,
    required int week,
    required List<int> visibleDays,
    required bool wallpaperOverChrome,
    required double? wallpaperLuminance,
  }) {
    final controller = _dayViewPageController;
    if (!_shouldShowDayViewOverlay ||
        controller == null ||
        visibleDays.isEmpty) {
      return const SizedBox.shrink();
    }
    // In day view the indicator follows the pager live even mid cross-week
    // (its week argument is the pager's floor week, which briefly differs
    // from the settled selection); in week view it is per-page and only
    // shows on the settled page.
    if (!_isDayView && _visibleDayViewWeek != week) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectionAccent = homePageOverWallpaperAccent(
      configuredHex: isDark
          ? settings.weekdayBarAccentColorDark
          : settings.weekdayBarAccentColorLight,
      themeFallback: colorScheme.primary,
      hasBackdrop: wallpaperOverChrome,
      wallpaperLuminance: wallpaperLuminance,
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
              // Weekday position within the bar's week: the pager is
              // globally continuous, so subtract the week's page offset.
              final rawDayPosition = rawPage - (week - 1) * visibleDays.length;
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
            key: const ValueKey('timetable-time-column'),
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
          _wrapCourseGridSurfaceHost(
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
    // Show label a bit earlier so the pill never looks like a lone spinner.
    final showLabel =
        _isHomePullQuickImportRunning ||
        _homePullDragDistance >= _homePullQuickImportTriggerDistance * 0.45;
    const indicatorTopInset = _weekDayHeaderHeight + 8;
    // Subtle follow — 11px max, eased, not the previous 27px linear slide.
    final followY = () {
      if (_isHomePullQuickImportRunning) return 0.0;
      final d = _homePullDragDistance;
      const cap = 32.0;
      if (d <= cap) return d * 0.34;
      return cap * 0.34 + (d - cap) * 0.06;
    }();
    final eased = Curves.easeOutCubic.transform(pullProgress);
    final scale = _isHomePullQuickImportRunning
        ? 1.0
        : (0.92 + eased * 0.08).clamp(0.92, 1.0);
    // Fade from 0 so the pill doesn't flash at tiny drags.
    final opacity = _isHomePullQuickImportRunning ? 1.0 : eased.clamp(0.0, 1.0);
    // Don't build the pill at all when fully transparent to avoid hit-test.
    if (!_isHomePullQuickImportRunning && pullProgress < 0.02) {
      return const SizedBox.shrink();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: (isDark
                ? HyperosMiuixDarkColors.surfaceContainerHigh
                : HyperosMiuixLightColors.surfaceContainer)
            .withValues(alpha: isDark ? 0.88 : 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: (isDark ? Colors.white : HyperosMiuixLightColors.outline)
              .withValues(alpha: isDark ? 0.10 : 0.14),
          width: 0.6,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.10 : 0.05),
            blurRadius: 36,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: _isHomePullQuickImportRunning
                ? MiuixCircularProgressIndicator(
                    progress: null,
                    size: 16,
                    strokeWidth: 1.9,
                  )
                : MiuixCircularProgressIndicator(
                    progress: pullProgress.clamp(0.0, 1.0),
                    size: 16,
                    strokeWidth: 1.9,
                  ),
          ),
          if (showLabel) ...[
            const SizedBox(width: 10),
            Text(
              l10n.homePullQuickImportFetchingCourses,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: HyperosColors.primaryText(context),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
            ),
          ],
          if (_isHomePullQuickImportRunning) ...[
            const SizedBox(width: 10),
            Container(width: 0.8, height: 14, color: HyperosColors.dividerLine(context)),
            const SizedBox(width: 10),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: _cancelHomePullQuickImport,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    l10n.quickImportCancelImportAction,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: HyperosColors.primary(context),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    // Frosted glass when a wallpaper is behind the grid, otherwise the solid
    // Miuix card above. Keep the blur cheap: single BackdropFilter on the pill
    // only, not the whole page.
    final hasBackdrop = hasHomePageBackdropImage(
      context.read<TimetableProvider>().settings,
    );
    final decoratedPill = hasBackdrop
        ? ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: pill,
            ),
          )
        : pill;

    return Positioned(
      top: indicatorTopInset,
      left: 0,
      right: 0,
      child: Center(
        child: Transform.translate(
          offset: Offset(0, followY),
          child: Transform.scale(
            scale: scale,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              opacity: opacity,
              child: decoratedPill,
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
    final atRest = _homePullDragDistance <= 0.5 && _homePullTouchDistance <= 0.5;
    if (deltaDy <= 0 && atRest) {
      return;
    }
    // Finger takes over from any in-flight settle spring.
    if (_homePullSettleSpring?.isAnimating ?? false) {
      _homePullSettleGeneration++;
      _homePullSettleSpring?.stop(canceled: true);
    }
    if (deltaDy > 0) {
      _homePullTouchDistance = (_homePullTouchDistance + deltaDy).clamp(
        0.0,
        _homePullDampingRange,
      );
    } else {
      // Retract "feels immediate"; keep raw travel 1:1.
      _homePullTouchDistance = (_homePullTouchDistance + deltaDy).clamp(
        0.0,
        _homePullDampingRange,
      );
    }
    final nextVisual = HyperosHomePullPhysics.visualOffset(
      _homePullTouchDistance,
      _homePullDampingRange,
    ).clamp(0.0, _homePullQuickImportMaxDistance);
    final threshold = _homePullQuickImportTriggerDistance;
    final crossedUp =
        _homePullDragDistance < threshold && nextVisual >= threshold;
    final reArmed =
        _homePullDragDistance >= threshold &&
        nextVisual < threshold * 0.88;
    if (reArmed) _homePullHapticArmed = true;
    if (nextVisual == _homePullDragDistance && !crossedUp) {
      return;
    }
    if (crossedUp && _homePullHapticArmed) {
      _homePullHapticArmed = false;
      try {
        final settings = context.read<TimetableProvider>().settings;
        if (settings.enableHaptics) HapticFeedback.selectionClick();
      } catch (_) {}
    }
    setState(() {
      _homePullDragDistance = nextVisual;
    });
  }

  void _finishHomePullDrag() {
    final shouldTrigger =
        _homePullDragDistance >= _homePullQuickImportTriggerDistance;
    _homePullSettleTo(0);
    _homePullHapticArmed = true;
    if (shouldTrigger) {
      unawaited(_runHomePullQuickImport());
    }
  }

  void _cancelHomePullDrag() {
    _homePullSettleTo(0);
    _homePullHapticArmed = true;
  }

  // --- Home pull spring helpers (HyperOS critical-damped, period 0.4s) ---
  void _driveHomePullSettle() {
    final spring = _homePullSettleSpring;
    if (spring == null) return;
    final v = spring.value;
    if (!mounted) return;
    setState(() {
      _homePullDragDistance = v.clamp(0.0, _homePullQuickImportMaxDistance);
      _homePullTouchDistance =
          HyperosHomePullPhysics.touchForOffset(v, _homePullDampingRange)
              .clamp(0.0, _homePullDampingRange);
    });
  }

  void _homePullSettleTo(double target) {
    final spring = _homePullSettleSpring;
    if (spring == null) {
      setState(() {
        _homePullDragDistance = target;
        _homePullTouchDistance =
            HyperosHomePullPhysics.touchForOffset(target, _homePullDampingRange);
      });
      return;
    }
    final generation = ++_homePullSettleGeneration;
    spring.value = _homePullDragDistance;
    final sim = SpringSimulation(
      HyperosHomePullPhysics.spring,
      spring.value,
      target,
      0,
    );
    // ignore: discarded_futures
    spring.animateWith(sim).then((_) {
      if (!mounted || generation != _homePullSettleGeneration) return;
      setState(() {
        _homePullDragDistance = target;
        _homePullTouchDistance =
            HyperosHomePullPhysics.touchForOffset(target, _homePullDampingRange);
      });
    }).catchError((Object _) {});
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
    _homePullSettleGeneration++;
    _homePullSettleSpring?.stop(canceled: true);
    _homePullHapticArmed = true;
    _homePullTouchDistance = 0;
    setState(() {
      _isHomePullQuickImportRunning = true;
      _homePullDragDistance = 0;
      _homePullQuickImportCancel = null;
    });
    try {
      if (context.read<TimetableProvider>().settings.enableHaptics) {
        HapticFeedback.mediumImpact();
      }
    } catch (_) {}
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
            if (notification.metrics.axis == Axis.horizontal) {
              if (notification is ScrollEndNotification) {
                _finalizeWeekPageSettled(provider);
              }
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
            // 日视图是独立页面：从顶部开始，自带星期信息栏，面板在信息栏
            // 之下。玻璃坞点 Tab 与日期栏路径都直接就位（闪现，无横向位移）。
            top: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 日视图自己的星期信息栏（scrubber 视觉由外部手势层覆盖）。
                _buildWeekDayHeader(
                  provider,
                  visibleDayViewWeek,
                  settings,
                  _resolveTimeColumnWidth(settings),
                  hideBottomBorder: true,
                ),
                Expanded(
                  child: _buildAnchoredDayViewOverlay(
                    provider: provider,
                    settings: settings,
                    week: visibleDayViewWeek,
                  ),
                ),
              ],
            ),
          ),
        // Swipeable weekday bar: when day view is open, the bar is a
        // follow-finger scrubber over the day pager — drags are amplified by
        // the visible-day count and injected into the pager position, so one
        // bar-width sweep flies the content across the whole week
        // (see _startWeekdayBarDrag).
        if (_shouldShowDayViewOverlay && visibleDayViewWeek != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _weekDayHeaderHeight,
            child: GestureDetector(
              key: const ValueKey('day-view-weekday-bar-swipe-area'),
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: (details) =>
                  _startWeekdayBarDrag(settings, details),
              onHorizontalDragUpdate: _updateWeekdayBarDrag,
              onHorizontalDragEnd: _endWeekdayBarDrag,
              onHorizontalDragCancel: _cancelWeekdayBarDrag,
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
    final hasBackdrop = hasHomePageBackdropImage(settings);
    // Day view keeps the same weekday chrome as the week view: the panel below
    // now shows the wallpaper, so an opaque non-blurred bar would read as a
    // seam across the top of the glass.
    final weekdayChromeBlurEnabled =
        hasBackdrop && settings.homePageWeekdayBarBlurEnabled;
    final chromeGridClearance = weekdayChromeBlurEnabled
        ? homePageFrostedRegionSeamOverlap
        : 0.0;
    // 自适应节高按完整可用高度计算：玻璃坞满屏悬浮下网格延伸到药丸
    // 底下（层次感）；被遮住的最后几节由 _buildWeekPageBody 的滚动余
    // 量救回——上滑把整段课表完全滑出到药丸上方，下滑再让药丸盖回。
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
    );
    final timeColumnWidth = _resolveTimeColumnWidth(settings);
    final pageChromeFallback = Theme.of(context).colorScheme.surface;
    // Keep the week slot at a fixed height while the day overlay owns the
    // visible header, avoiding duplicate weekday bars during the transition.
    final weekdayHeader = SizedBox(
      height: _weekDayHeaderHeight,
      child: _shouldShowDayViewOverlay
          ? const SizedBox.shrink()
          : homePageBackgroundLayer(
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
                hideBottomBorder:
                    weekdayShowsBackdrop || weekdayChromeBlurEnabled,
              ),
            ),
    );

    return KeyedSubtree(
      key: ValueKey('week-page-$week'),
      child: Column(
        children: [
          weekdayHeader,
          // Original chrome↔grid clearance (same token as frosted seam overlap).
          // Keeps gaussian cards from sitting flush on the first course row.
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
    // 玻璃坞满屏悬浮：网格视口不避让、铺到药丸底下——静止时最后几节
    // 停在药丸后面；给纵向滚动补一段底部余量，上滑把课表整体滑上来、
    // 被遮的课程完全露到药丸上方，下滑再让药丸盖回内容。自适应与非自
    // 适应在此统一（自适应网格同样可滚）。经典形态无坞（余量为 0），
    // 保持原样：自适应恰满视口不滚，非自适应维持原滚动结构。
    final weekGridScrollRelief = _glassDockContentScrollInset(settings);
    final Widget weekGrid;
    if (weekGridScrollRelief > 0) {
      weekGrid = SingleChildScrollView(
        key: PageStorageKey<String>('week-scroll-$week'),
        // Explicit clamp: do not inherit HyperOS rubber-band here.
        physics: const ClampingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: weekGridScrollRelief),
          child: grid,
        ),
      );
    } else if (settings.timetableAutoFitSectionHeight) {
      weekGrid = grid;
    } else {
      weekGrid = SingleChildScrollView(
        key: PageStorageKey<String>('week-scroll-$week'),
        physics: const ClampingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        child: grid,
      );
    }
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
    final controller = _ensureDayViewPageController(settings);
    _syncDayViewPageWithSelection(settings);
    final pageCount = _dayViewPageCount(settings);

    return homePageBackgroundLayer(
      visual: backgroundVisual,
      child: Container(
        key: const ValueKey('timetable-day-view-panel'),
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
                    // 新手势重新允许一次日切换点击震感。
                    _daySwipeHapticFired = false;
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
                      if (notification is ScrollUpdateNotification) {
                        // 拦截 update 继续冒泡：HyperosRootPage 的触边震动
                        // 监听会在学期首/末日到达页边界时再计一次
                        // selectionClick，与上面的页中点点击叠加成一次滑动
                        // 双震动。日切换反馈已在页中点给过，这里就地消费。
                        return true;
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
                        _settleDayViewPage(provider, settings);
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
                      onPageChanged: (page) =>
                          _handleDayViewPageChanged(provider, settings, page),
                      itemBuilder: (context, page) {
                        // 1 Hz progress heartbeat rebuilds only this page's
                        // content (ongoing badges / progress), not the State.
                        return ValueListenableBuilder<int>(
                          valueListenable: _dayAgendaProgressTick,
                          builder: (context, _, _) => _buildDayViewPageContent(
                            provider: provider,
                            settings: settings,
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
    required int page,
  }) {
    final target = _dayViewTargetForPage(settings, page);
    if (logDayViewBuilds) {
      debugPrint(
        '[DayView] build page=$page -> week=${target.week} '
        'day=${target.dayOfWeek}',
      );
    }
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
    if (logDayViewBuilds) {
      debugPrint(
        '[DayView] page=$page items: courses=${displayItems.length} '
        'agenda=${agendaItems.length} schedule=${scheduleItems.length}',
      );
    }
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

  List<ScheduleItemInstance> _getScheduleItemsForWeekDay({
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
    return provider.getScheduleItemInstancesForDate(targetDate);
  }

  _DayAgendaItem _buildScheduleAgendaItemForDate({
    required ScheduleItemInstance instance,
    required DateTime targetDate,
  }) {
    final item = instance.effectiveItem;
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
      instance: instance,
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
        (instance) => _buildScheduleAgendaItemForDate(
          instance: instance,
          targetDate: targetDate,
        ),
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
    final hasBackdrop = hasHomePageBackdropImage(settings);
    final backdropBlurOn =
        hasBackdrop && HyperosBlurredHeader.backdropBlurEnabled(context);
    // 顶栏/信息栏开着玻璃时，摘要卡与顶部铬玻璃带同材质、同墨色极性。
    final matchesChromeBand = homePageHasAnyChromeBlur(
      settings,
      hasBackdrop: hasBackdrop,
    );
    // 课程卡切到「高斯模糊」档且有壁纸时，摘要卡也走铬玻璃亮磨砂材质：
    // CourseSurface 的高斯路径只有 0.42 的弱中性 tint，深色壁纸会直接透出，
    // 让「回到今天 / 关闭 / 日期」整张卡读作发黑的玻璃；铬玻璃 wash 与弹窗
    // 同级（浅色主题约白色 0.68），保证卡片始终偏亮色。
    final useChromeGlass =
        matchesChromeBand ||
        (backdropBlurOn &&
            settings.courseCardSurfaceStyle ==
                CourseCardSurfaceStyle.gaussian);
    // Ink: 与顶部玻璃带同材质时沿用壁纸亮度自动黑白；否则卡面就是主题底色
    // （或亮磨砂），墨色必须跟主题走 —— 按原始壁纸亮度翻白会让白墨落在
    // 亮色卡面上不可读。
    final summaryInk = matchesChromeBand
        ? homePageOverWallpaperInk(
            configuredHex: isDark
                ? settings.weekdayBarFontColorDark
                : settings.weekdayBarFontColorLight,
            defaultHex: isDark
                ? TimetableSettings.defaultWeekdayBarFontColorDark
                : TimetableSettings.defaultWeekdayBarFontColorLight,
            themeFallback: foruiTheme.colors.foreground,
            hasBackdrop: hasBackdrop,
            wallpaperLuminance: _wallpaperBodyLuminance ?? _wallpaperTopLuminance,
          )
        : foruiTheme.colors.foreground;
    final summaryMutedInk = homePageOverWallpaperMutedInk(summaryInk);
    // 课程计数胶囊与「X 节日程」胶囊同款中性墨：跟摘要卡其余文字一样走
    // 壁纸自动黑白，有课与否不再切换主题蓝强调色。
    final countBadgeColor = summaryInk.withValues(alpha: 0.10);
    final countBadgeTextColor = summaryMutedInk;
    return _dayAgendaSurface(
      key: key,
      settings: useChromeGlass ||
              settings.courseCardSurfaceStyle == CourseCardSurfaceStyle.solid
          ? settings
          // 无壁纸/模糊被关掉时高斯档没有可用的磨砂来源，退化为实心亮卡。
          : settings.copyWith(
              courseCardSurfaceStyle: CourseCardSurfaceStyle.solid,
            ),
      chromeGlass: useChromeGlass,
      // Neutral wash (not a course hue); CourseSurface owns glass vs solid.
      color: foruiTheme.colors.background,
      gradient: LinearGradient(
        colors: [foruiTheme.colors.background, foruiTheme.colors.background],
      ),
      // 摘要卡没有课程色填充可依托：无壁纸（纯色页面）时填充色与页面底色
      // 相同，无边框无阴影会整张隐形（下方课程卡靠 hue + outerShadow 保持
      // 边界）。补一套中性细描边 + 柔和投影，几何参数与 agenda 卡片一致，
      // 让两种卡片在纯白底上读作同一个卡片系统。chromeGlass 分支自绘壁纸
      // 采样材质，忽略这两个参数，不受影响。
      border: useChromeGlass
          ? null
          : Border.all(color: summaryInk.withValues(alpha: 0.12)),
      shadow: useChromeGlass
          ? null
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
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
                ink: summaryInk,
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
    // 摘要卡当前材质的墨色极性（玻璃下随壁纸自动黑白）。嵌套的空闲面板
    // 与其中的文字必须跟母卡同极性，而不是主题 onSurface：高斯模糊档下
    // 母卡是亮磨砂玻璃，主题墨色可能与实际卡面对比不足。
    required Color ink,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final foruiTheme = context.theme;
    // #4CAF50 是中明度绿，直接当文字色在透壁纸的浅色卡面上对比不足
    // 2.8:1（亮粉壁纸上更低）。「共 N 段」徽标、时间胶囊与展开按钮的
    // 文字和底洗统一走按母卡墨色极性调出的可读变体（浅卡压暗/深卡提亮）。
    final freeAccent = readableAccentOnCardInk(
      _colorFromHex(
        CoupleTimetableLogic.freeSlotColorHex,
        foruiTheme.colors.primary,
      ),
      ink,
    );
    final isStale = _isPartnerScheduleStale(provider);
    final title = isToday
        ? l10n.coupleTimetableSharedFreeTitle
        : l10n.coupleTimetableSharedFreeTitleOtherDay;
    final emptyLabel = isToday
        ? l10n.coupleTimetableNoSharedFree
        : l10n.coupleTimetableNoSharedFreeOtherDay;
    final mutedStyle = foruiTheme.typography.body.xs2.copyWith(
      color: ink.withValues(alpha: 0.62),
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
        ink: ink,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: foruiTheme.typography.body.sm.copyWith(
                color: ink,
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
      ink: ink,
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
                    color: ink,
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
    required Color ink,
    required Widget child,
  }) {
    return DecoratedBox(
      key: key,
      decoration: BoxDecoration(
        // 摘要卡内的嵌套面板跟随摘要墨色：浅洗底 + 细描边，玻璃/实心、
        // 明暗主题都与母卡同极性。此前误用 colorScheme.secondary（M3 基线
        // 浅色 #625B71 近黑），高斯模糊下整张卡在亮磨砂上读作发黑的一块，
        // 标题墨色（onSurface 近黑）也低于可读下限。
        color: ink.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ink.withValues(alpha: 0.10)),
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
    final hasBackdrop = hasHomePageBackdropImage(settings);
    final colorScheme = Theme.of(context).colorScheme;
    // Same wallpaper auto-contrast as weekday / time-axis chrome: default ink
    // flips black↔white over dark photos; user-custom hex is kept as-is. The
    // empty state sits mid-screen, so judge from the card-region band.
    final titleColor = homePageOverWallpaperInk(
      configuredHex: isDark
          ? settings.weekdayBarFontColorDark
          : settings.weekdayBarFontColorLight,
      defaultHex: isDark
          ? TimetableSettings.defaultWeekdayBarFontColorDark
          : TimetableSettings.defaultWeekdayBarFontColorLight,
      themeFallback: colorScheme.onSurface,
      hasBackdrop: hasBackdrop,
      wallpaperLuminance: _wallpaperBodyLuminance ?? _wallpaperTopLuminance,
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
    // 玻璃坞避让（含底部安全区）：日课表视口全屏，避让以滚动 padding
    // 实现——静止在列表底部时最后一项仍停在玻璃坞上方，滚动中卡片则
    // 连续穿过避让带，不再在边界被硬裁出与磨砂卡片色差明显的空带。
    // 满屏悬浮（overlay）同样取滚动余量（药丸占用兜底）：此前 overlay
    // 余量为 0，下滑到底最后一张卡仍压在药丸后面，无法滑出来看。
    final dockScrollAvoidance = _glassDockContentScrollInset(settings);
    if (agendaItems.isEmpty) {
      return Padding(
        key: key,
        padding: EdgeInsets.fromLTRB(14, 0, 14, 8 + dockScrollAvoidance),
        child: _buildDayViewEmptyColumn(week: week, settings: settings),
      );
    }
    // Gaussian cards sample the cached wallpaper bitmap while the day view
    // moves; the shared host keeps their BackdropFilter capture at grid scope.
    final agendaList = ListView.separated(
      key: PageStorageKey<String>('day-agenda-$week-$dayOfWeek'),
      padding: EdgeInsets.fromLTRB(14, 0, 14, 8 + dockScrollAvoidance),
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
    return CourseGridSurfaceHost(settings: settings, child: agendaList);
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
                  // 与首页 chrome 玻璃带同观感：液态玻璃下只有玻璃本色，
                  // 不再叠加可读性 scrim。
                  color: HomePageChromeGlassFill.standInWashColor(context),
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
      if (logDayViewBuilds) {
        debugPrint('[DayView] build agenda entry: exam id=${item.exam?.id}');
      }
      return _buildExamAgendaEntry(
        item.exam!,
        provider: context.read<TimetableProvider>(),
      );
    }
    if (item.isScheduleItem) {
      if (logDayViewBuilds) {
        debugPrint(
          '[DayView] build agenda entry: schedule id=${item.scheduleItem?.id}',
        );
      }
      return _buildScheduleAgendaEntry(item, settings: settings);
    }

    final courseItem = item.courseItem!;
    if (logDayViewBuilds) {
      debugPrint(
        '[DayView] build agenda entry: course id=${courseItem.course.id} '
        'name=${courseItem.course.name}',
      );
    }
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
            const SizedBox(height: 5.5),
            _buildCurrentDayAgendaInfoRow(
              icon: Icons.location_on_outlined,
              text: locationLine,
              ink: ink,
            ),
            if (sessionPreview != null && sessionPreview.isNotEmpty) ...[
              const SizedBox(height: 5.5),
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
                  const SizedBox(height: 5.5),
                  _buildCurrentDayAgendaInfoRow(
                    icon: Icons.location_on_outlined,
                    text: locationLine,
                    ink: ink,
                  ),
                  if (sessionPreview != null && sessionPreview.isNotEmpty) ...[
                    const SizedBox(height: 5.5),
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
        color: HyperosColors.destructive,
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
    // 高斯模糊档下错误红只有 ~42% tint，亮色壁纸会透成浅粉底，写死的
    // 白墨会洗没；与课程/日程卡一致改用自动黑白墨色。
    final ink = _dayAgendaAutoInk(
      colorScheme.error,
      settings: provider.settings,
    );
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
                        color: _dayAgendaInkWash(ink, lightAlpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.school_outlined, size: 14, color: ink),
                          const SizedBox(width: 4),
                          Text(
                            l10n.examBadgeLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: ink,
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
                        color: _dayAgendaInkWash(ink, lightAlpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        countdownText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  exam.name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 3.5),
                if (exam.startTime.isNotEmpty && exam.endTime.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '${exam.startTime} - ${exam.endTime}',
                      style: TextStyle(
                        fontSize: 13,
                        color: ink.withValues(alpha: 0.9),
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
                        color: ink.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                if (courseName.isNotEmpty)
                  Text(
                    courseName,
                    style: TextStyle(
                      fontSize: 12,
                      color: ink.withValues(alpha: 0.7),
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
    final sourceItem = agendaItem.scheduleInstance?.item ?? item;
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
      key: ValueKey('day-view-schedule-card-${agendaItem.id}'),
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
        child: AddScheduleItemScreen(
          scheduleItem: sourceItem,
          occurrenceDate: agendaItem.scheduleInstance?.occurrenceDate,
        ),
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
                  const SizedBox(height: 5.5),
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
                    const SizedBox(height: 5.5),
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
          ? HyperosColors.destructive
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
      statusTextColor: isEndingSoon ? HyperosColors.destructive : fillColor,
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
    final customInk = foregroundHex == null || foregroundHex.trim().isEmpty
        ? null
        : _colorFromHex(foregroundHex, Colors.white);
    // 自定义字色（导入/LAN 同步携带）在实心卡面上做可读性兜底：与卡色
    // 同色系时（如蓝字配蓝卡）替换为黑白最优墨色。玻璃档按壁纸亮度走玻璃
    // 规则（彩色墨回落自动黑白、中性墨对比度门槛），与 CourseCard 行为
    // 一致；壁纸亮度未知时保留用户选择。
    final showsWallpaper = settings != null &&
        courseCardSurfaceShowsWallpaper(settings.courseCardSurfaceStyle);
    final foregroundColor = customInk == null
        ? _dayAgendaAutoInk(fillColor, settings: settings)
        : resolveReadableCourseCardTitleColor(
            preferred: customInk,
            cardColor: fillColor,
            surfaceShowsWallpaper: showsWallpaper,
            wallpaperLuminance: showsWallpaper
                ? (_wallpaperBodyLuminance ?? _wallpaperTopLuminance)
                : null,
          );
    return _DayAgendaPalette(
      baseColor: baseColor,
      fillColor: fillColor,
      foregroundColor: foregroundColor,
    );
  }

  /// Default agenda-card ink when the course has no custom text colour.
  ///
  /// Opaque styles keep the legacy white-on-hue. The gaussian style shows
  /// mostly wallpaper through a ~40% tint, so the ink flips black/white against
  /// the blend of course hue and the wallpaper band behind the cards — a bright
  /// wallpaper region otherwise gives white-on-white.
  Color _dayAgendaAutoInk(Color fill, {TimetableSettings? settings}) {
    if (settings == null) {
      return Colors.white;
    }
    final glassOverWallpaper = hasHomePageBackdropImage(settings) &&
        settings.courseCardSurfaceStyle == CourseCardSurfaceStyle.gaussian;
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
              // 日课表：这节课（课程×真实日期）已设单节课提醒时，在备注
              // 角标旁亮铃铛；情侣对方的只读课不显示。
              hasReminder: date != null &&
                  !item.isPartnerCourse &&
                  provider.classReminderFor(
                        item.course.id,
                        ClassReminderEntry.formatDate(date),
                      ) !=
                      null,
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
              // 玻璃档自动黑白判定的壁纸带亮度；实体卡忽略。
              wallpaperLuminance:
                  _wallpaperBodyLuminance ?? _wallpaperTopLuminance,
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
    // 「回本周」已收敛为浮钮唯一入口（样式枚举仅存兼容，读取时
    // 一律迁移为 floating），此处不再有接管分支。
    if (settings.timetableBackToCurrentWeekButtonStyle !=
        BackToCurrentWeekButtonStyle.floating) {
      return false;
    }
    return _canReturnToCurrentWeek(settings, visibleWeek);
  }

  /// 玻璃坞形态下「可滚动课表内容」的底部滚动余量（日课表列表、周课
  /// 表纵向滚动）：视口保持原样，余量只加长可滚动区间——静止时内容
  /// 照常铺满，下滑到底后最后一项停在浮动药丸上方，被药丸遮住的课程
  /// 可以滑出来看。按药丸固定占用 + 底部安全区兜底。
  double _glassDockContentScrollInset(TimetableSettings settings) {
    if (settings.homeNavigationForm != HomeNavigationForm.glassDock) {
      return 0;
    }
    return _glassDockPillOccupancy + MediaQuery.viewPaddingOf(context).bottom;
  }

  /// 玻璃坞形态：把底部液态玻璃药丸导航叠加到页面之上。
  ///
  /// 经典形态直接返回原内容，行为与之前完全一致。
  Widget _wrapWithGlassDock(
    Widget child, {
    required bool glassDockForm,
    required TimetableSettings settings,
    required AppLocalizations l10n,
  }) {
    if (!glassDockForm) {
      return child;
    }
    // 浮钮与药丸显式同源材质：stock 实验态传包官方底栏默认，
    // 自定义态走 sheetSettingsFor / frosted 回退（与 bar 内部一致）。
    LiquidGlassSettings? dockBtnSettings;
    GlassQuality? dockBtnQuality;
    if (_kStockDockGlass) {
      dockBtnSettings = MikcbLiquidGlassTokens.stockBottomBarGlass;
      dockBtnQuality = null; // 包原版自适应质量
    } else {
      final dockAppearance = FrostedAppearanceScope.of(context);
      // 「液态玻璃作用范围 → 玻璃坞导航」关闭时圆钮回退磨砂药丸材质。
      final dockUseLiquidGlass =
          dockAppearance.glassMode == FrostedGlassMode.liquidGlass &&
          dockAppearance.liquidGlassDockEnabled &&
          !LiquidGlassDegradation.shouldDegrade(context);
      final dockIsDark = Theme.of(context).brightness == Brightness.dark;
      dockBtnSettings = dockUseLiquidGlass
          ? MikcbLiquidGlassTokens.sheetSettingsFor(
              dockIsDark ? Brightness.dark : Brightness.light,
              tuning: dockAppearance.liquidGlassTuning,
            )
          : LiquidGlassSettings(
              blur: dockAppearance.sheetBlurSigma,
              glassColor: HyperosBlurredHeader.sheetTintColor(
                context,
                withBlur: true,
              ),
            );
      dockBtnQuality =
          dockUseLiquidGlass ? GlassQuality.premium : GlassQuality.minimal;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            // 官方 iOS 26 形态：居中药丸 + 右侧独立圆钮，整组居中。
            // 圆钮固定展开（加课程唯一主动入口，不再随页收起）；
            // 材质经 dockBtnSettings 与药丸显式同源。
            child: Builder(builder: (context) {
                final lum = _dockInlinePageId != null ? null : _wallpaperBodyLuminance; // 内嵌页表态只看主题
                final isDarkTheme =
                    Theme.of(context).brightness == Brightness.dark;
                final ink = (lum != null ? lum < 0.45 : isDarkTheme)
                    ? Colors.white.withValues(alpha: 0.9)
                    : Colors.black.withValues(alpha: 0.75);
                return Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 272),
                        child: _buildGlassDockBar(
                          settings: settings,
                          l10n: l10n,
                        ),
                      ),
                      if (settings.glassDockShowAddButton) ...[
                        const SizedBox(width: 8),
                        _buildDockMergeSlot(
                          ink: ink,
                          l10n: l10n,
                          settings: dockBtnSettings,
                          quality: dockBtnQuality,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),

      ],
    );
  }

  /// 玻璃坞底部导航：周课表 / 日课表 / 设置。
  ///
  /// 使用 liquid_glass_widgets 的 [GlassTabBar.bottom]（iOS 26 官方形态：
  /// 浮动药丸 + 拖拽指示器，自带真实折射 shader 与自适应质量）。
  Widget _buildGlassDockBar({
    required TimetableSettings settings,
    required AppLocalizations l10n,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    // 底栏文字极性分派：课表态跟随壁纸亮度（表面 = 壁纸 + 白玻璃）；
    // 内嵌页表态底栏浮在纯色页面上，只看主题——否则白底设置页会沿用
    // 暗壁纸的浅色墨，白字看不见（自动反色失效的根因）。
    final wallpaperLuminance = _dockInlinePageId != null
        ? null
        : _wallpaperBodyLuminance;
    final barUsesLightInk = wallpaperLuminance != null
        ? wallpaperLuminance < 0.45
        : isDark;
    final unselectedColor = barUsesLightInk
        ? Colors.white.withValues(alpha: 0.62)
        : Colors.black.withValues(alpha: 0.48);
    // 选中色：暗表面用白色；亮表面上浅色主题的 primary 本身偏深可用，
    // 深色主题的 primary 偏浅在亮玻璃上对比度不足 → 切深色墨。
    final selectedColor = barUsesLightInk
        ? Colors.white
        : (isDark && wallpaperLuminance != null && wallpaperLuminance >= 0.45
            ? Colors.black.withValues(alpha: 0.80)
            : colorScheme.primary);
    // 底栏材质（[_kStockDockGlass]=true 时下面全部走包原版默认，此段
    // 仅在实验关闭时参与计算）：
    // - 跟随「高级材质」设置（与弹窗/顶部/卡片统一）：液态玻璃用
    //   sheetSettingsFor（跟随「液态玻璃调校」）+ premium 完整折射；
    // - 标准/高斯：退化为高斯模糊药丸（blur/tint 与弹窗 frosted 一致）。
    final appearance = FrostedAppearanceScope.of(context);
    // 「液态玻璃作用范围 → 玻璃坞导航」关闭时底栏回退磨砂药丸。
    final useLiquidGlass = !_kStockDockGlass &&
        appearance.glassMode == FrostedGlassMode.liquidGlass &&
        appearance.liquidGlassDockEnabled &&
        !LiquidGlassDegradation.shouldDegrade(context);
    // 动态入口列表：底栏最多 5 槽，用户在「首页与导航」自由编排
    // （'day'/'week' 视图动作 + 目录任意条目，含设置页）。
    final dockIds = resolveGlassDockActionIds(settings);
    return GlassTabBar.bottom(
      tabs: [
        for (final id in dockIds) _dockTabForId(id, l10n),
      ],
      selectedIndex: _dockSelectedIndex(dockIds),
      onTabSelected: (index) =>
          _handleDockTap(dockIds[index], settings),
      // 独立圆钮改由坞层「水滴合并槽」渲染（见 _wrapWithGlassDock）：
      // 整颗按钮滑入药丸并被圆形裁切，运动与遮罩都贴合药丸端帽弧度。
      barHeight: 56,
      // —— 玻璃材质实验（[_kStockDockGlass]）：true = 全部取包原版默认，
      // false = 旧的 mikcb 自定义调校。原版各值：
      // - 底栏本体显式传 stockBottomBarGlass（包内 kBottomBarGlassDefaults
      //   的镜像：thickness 30 / blur 3 / 折射率 1.59 / 色散 0.3 / 24% 白，
      //   iOS 26 Apple News/Safari tab bar 校准）。与不传参数等价，但能
      //   同时给到右侧浮钮，消除两者内部默认不同导致的材质断层；
      // - 拖拽透镜 indicatorSettings 不传 → baseIndicatorSettings
      //   （thickness 20 / 折射率 1.10 / 无色散）：轻微透镜弯曲，不会出
      //   现自定义拉满档那种「四周强折射、中间全透明」的甜甜圈观感；
      // - pinch 0.4、expansion 水平12/垂直8、quality 自适应均为构造
      //   默认值（与不传参数完全等价）。
      // 不覆盖官方默认圆角（32）：barBorderRadius 一旦偏离默认值，库会把
      // 独立按钮的形状从原生 LiquidOval 正圆降级成圆角矩形——这正是此前
      // 「添加按钮不圆」的根因。指示器圆角官方默认即 barRadius-4=28。
      indicatorBorderRadius: _kStockDockGlass ? null : 28,
      settings: _kStockDockGlass
          ? MikcbLiquidGlassTokens.stockBottomBarGlass
          : (useLiquidGlass
              ? MikcbLiquidGlassTokens.sheetSettingsFor(
                  isDark ? Brightness.dark : Brightness.light,
                  tuning: appearance.liquidGlassTuning,
                )
              : LiquidGlassSettings(
                  blur: appearance.sheetBlurSigma,
                  glassColor: HyperosBlurredHeader.sheetTintColor(
                    context,
                    withBlur: true,
                  ),
                )),
      indicatorSettings: _kStockDockGlass
          ? null
          : (useLiquidGlass ? MikcbLiquidGlassTokens.dragLensSettings : null),
      indicatorExpansion: _kStockDockGlass
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
          : const EdgeInsets.symmetric(vertical: 8),
      indicatorPinchStrength: useLiquidGlass ? 1.0 : 0.4,
      quality: _kStockDockGlass
          ? null
          : (useLiquidGlass ? GlassQuality.premium : GlassQuality.minimal),
      iconSize: 22,
      labelFontSize: 10,
      horizontalPadding: 6,
      verticalPadding: 6,
      selectedIconColor: selectedColor,
      unselectedIconColor: unselectedColor,
      selectedLabelColor: selectedColor,
      unselectedLabelColor: unselectedColor,
    );
  }

  /// 独立圆钮：与药丸同质的液态玻璃圆钮（56 正圆）。
  ///
  /// 材质与药丸显式同源（_wrapWithGlassDock 传入 stockBottomBarGlass），
  /// useOwnLayer:true + isStationary:true 保证 minimal 回退时仍保留
  /// BackdropFilter 模糊——与药丸 frosted 回退一致，消除“两种材质”断层。
  Widget _buildDockMergeSlot({
    required Color ink,
    required AppLocalizations l10n,
    required LiquidGlassSettings? settings,
    required GlassQuality? quality,
  }) {
    // 材质断层根因：此前此处以 useOwnLayer:false 渲染（LiquidGlass.grouped），
    // 但坞层 Row 树外没有任何 LiquidGlassLayer/BluetoothGroup 祖先，
    // Impeller 下 grouped 在无层时直接回退为固色无玻璃——看起来像一块
    // 实色圆片，与药丸的真液态玻璃完全两种材质。改为 useOwnLayer:true
    // + isStationary:true 后，按钮与药丸共享同质的 stockBottomBarGlass /
    // sheetSettings，且在 minimal/降级路径两侧一致保留 BackdropFilter。
    // 独立圆钮与药丸端帽同圆（56 正圆），外层 SizedBox(56) 与 Row 间距
    // 由调用侧 SizedBox(width:8) 承担，无需 68 高的方形过渡槽及二次
    // ClipRRect 裁切（会把玻璃边缘光切硬）。
    return SizedBox(
      width: 56,
      height: 56,
      child: GlassButton(
        icon: _roundButtonIcon(
          context.read<TimetableProvider>().settings,
        ),
        onTap: () => _handleRoundButtonTap(
          context.read<TimetableProvider>().settings,
        ),
        label: l10n.glassDockExtraButtonSemanticLabel,
        width: 56,
        height: 56,
        iconSize: 22,
        iconColor: ink,
        settings: settings,
        quality: quality,
        useOwnLayer: true,
        isStationary: true,
      ),
    );
  }

  /// 底栏按钮 → GlassTab 视觉配置：视图动作用固定图标，页面条目取目录。
  GlassTab _dockTabForId(String id, AppLocalizations l10n) {
    return GlassTab(
      icon: Icon(glassDockActionIcon(id)),
      label: glassDockActionLabel(l10n, id),
    );
  }

  /// 圆钮图标：用户自选的 Miuix 矢量图标优先；未选时 addCourse 显示
  /// 加号、其余功能显示目录图标。
  Widget _roundButtonIcon(TimetableSettings settings) {
    final customName = settings.glassDockButtonIconName;
    if (customName != null && customName.isNotEmpty) {
      final vector = MiuixIcons.extended.byName(customName);
      if (vector != null) {
        return MiuixIcon(vector: vector);
      }
    }
    final id = settings.glassDockButtonEntryId;
    if (id != 'addCourse' && id.isNotEmpty) {
      final entry = homeMenuEntryById(id);
      if (entry != null) {
        return Icon(entry.icon);
      }
    }
    return const Icon(Icons.add_rounded);
  }

  /// 圆钮点击分发：addCourse/空走添加课程弹层；内嵌注册页在首页栈内
  /// 切换（坞常驻，再点同钮收回）；其余目录条目普通推入。
  void _handleRoundButtonTap(TimetableSettings settings) {
    final id = settings.glassDockButtonEntryId;
    if (id == 'addCourse' || id.isEmpty) {
      unawaited(_showAddCourseSheet());
      return;
    }
    if (inlineDockPageFor(id) != null) {
      setState(() {
        _dockInlinePageId = (_dockInlinePageId == id) ? null : id;
      });
      // 圆钮保留 toggle 收回（Tab 侧再点当前页已改无动作：圆钮无选中态
      // 指示，按钮式「再点撤销」成立）；开/收/换页都是真实切换，给触觉。
      _maybeSelectionClick(settings);
      return;
    }
    final entry = homeMenuEntryById(id);
    if (entry != null) {
      _maybeSelectionClick(settings);
      unawaited(entry.open(context));
    }
  }

  /// 当前所在视图（日/周）在排列中的下标；排列未含该视图时高亮 0，
  /// 避免库断言越界（此时底栏全是页面入口，无「当前页」语义）。
  int _dockSelectedIndex(List<String> ids) {
    final inline = _dockInlinePageId;
    if (inline != null && ids.contains(inline)) {
      return ids.indexOf(inline);
    }
    final current = _isDayView ? kGlassDockActionDay : kGlassDockActionWeek;
    final index = ids.indexOf(current);
    return index >= 0 ? index : 0;
  }

  /// 底栏点击分发：'day'/'week' 闪现直切（animate:false，不播锚点展开/
  /// 收起转场，对齐「点底栏直接就位」的手感，日期栏路径不受影响）并收回
  /// 内嵌页；页面条目走内嵌宿主（坞常驻），未登记的流程页才推入新路由。
  ///
  /// 触觉口径（恢复 3e41ac20）：真实切换（切视图/开页/换页/收页/推路由）
  /// 给一次触觉，重复点击当前 Tab 静音——日/周靠既有守卫；内嵌页再点
  /// 当前页不再翻转收回（与 日/周 同口径，收页走切视图或系统返回）。
  void _handleDockTap(String id, TimetableSettings settings) {
    final leavingInlinePage =
        _dockInlinePageId != null &&
        (id == kGlassDockActionDay || id == kGlassDockActionWeek);
    if (leavingInlinePage) {
      // 从内嵌页点视图切换：先收页再切视图，避免两层状态叠加。
      setState(() => _dockInlinePageId = null);
    }
    switch (id) {
      case kGlassDockActionDay:
        if (_isDayView) {
          // 重复点日 Tab 无动作；从内嵌页收回落回日课表是一次真实切换
          // （落回异视图的路径 _toggleDayView 内部已震，此处只补同视图）。
          if (leavingInlinePage) {
            _maybeSelectionClick(settings);
          }
          return;
        }
        unawaited(
          _toggleDayView(
            week: _visibleWeek,
            dayOfWeek: _resolveStoredDayOfWeek(
              settings,
              settings.timetableLastViewedDayOfWeek,
            ),
            settings: settings,
            animate: false,
          ),
        );
      case kGlassDockActionWeek:
        if (!_isDayView) {
          _persistViewState(
            context.read<TimetableProvider>(),
            mode: TimetableHomeViewMode.week,
          );
          // 重复点周 Tab 无动作；从内嵌页收回落回周课表是一次真实切换。
          if (leavingInlinePage) {
            _maybeSelectionClick(settings);
          }
          return;
        }
        // 闪现收起：_closeDayView 内部完成震动、状态清理与持久化。
        unawaited(_closeDayView(settings, animate: false));
      default:
        // 内嵌优先：注册过的页面在首页栈内切换，玻璃坞保持悬浮；未登记
        // 的走普通推入。再点当前内嵌页与 日/周 Tab 同口径无动作，其余均
        // 是真实切换（开页/换页/推路由），统一在此给触觉反馈。
        if (inlineDockPageFor(id) != null) {
          if (_dockInlinePageId == id) {
            return;
          }
          setState(() => _dockInlinePageId = id);
          _maybeSelectionClick(settings);
          return;
        }
        final entry = homeMenuEntryById(id);
        if (entry != null) {
          _maybeSelectionClick(settings);
          unawaited(entry.open(context));
        }
    }
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
    // 液态玻璃模式下用真折射圆角玻璃，而不是高斯模糊磨砂——
    // 与底栏/独立按钮同一套材质语言。
    final dockAppearance = FrostedAppearanceScope.of(context);
    // 「液态玻璃作用范围 → 玻璃坞导航」关闭时回浮按钮回磨砂圆片。
    final useLiquidGlassMaterial =
        dockAppearance.glassMode == FrostedGlassMode.liquidGlass &&
        dockAppearance.liquidGlassDockEnabled &&
        !LiquidGlassDegradation.shouldDegrade(context);

    final glassDockForm =
        provider.settings.homeNavigationForm == HomeNavigationForm.glassDock;
    // 按钮需始终浮在玻璃坞药丸之上：玻璃坞形态下统一取「内容避让量 +
    // 24 视觉边距」与「药丸占用 + 12 视觉间隙」的较大值——周视图由外层
    // 布局避让垫高、日/设置页视口全屏时按钮自行避让，两种实现下都不被
    // 药丸遮挡；经典形态保持原 24px 边距。
    final double dockBackButtonBottom;
    if (!glassDockForm) {
      dockBackButtonBottom = 24;
    } else {
      dockBackButtonBottom =
          math.max(24, _glassDockPillOccupancy + 12) +
          MediaQuery.viewPaddingOf(context).bottom;
    }
    return SafeArea(
      minimum: EdgeInsets.only(
        right: 20,
        bottom: dockBackButtonBottom,
      ),
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
            child: useLiquidGlassMaterial
                ? GlassButton.custom(
                    onTap: () => _jumpToCurrentWeek(provider),
                    shape: const LiquidRoundedRectangle(borderRadius: 18),
                    settings: MikcbLiquidGlassTokens.sheetSettingsFor(
                      theme.brightness,
                      tuning: dockAppearance.liquidGlassTuning,
                    ),
                    quality: GlassQuality.premium,
                    // 崩溃修复：此钮挂在无任何 LiquidGlassLayer 祖先的裸 Stack 上，
                    // premium + 默认 useOwnLayer:false 会触发 LiquidGlassBlendGroup
                    // 的 renderLink != null 断言。显式自带层；isStationary 与
                    // _buildDockMergeSlot / 包内 BottomBarExtraBtn 对齐，
                    // 保证引擎降级路径仍保留 BackdropFilter 模糊。
                    useOwnLayer: true,
                    isStationary: true,
                    child: Opacity(
                      opacity: contentOpacity,
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
                  )
                : ClipRRect(
                    borderRadius: borderRadius,
                    child: HyperosFrostedSurface(
                      borderRadius: borderRadius,
                      tint: frostedTint,
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          key: const ValueKey(
                            'back-to-current-week-button',
                          ),
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
                                    alpha:
                                    colorScheme.primary.a * contentOpacity,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.backToCurrentWeekAction,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface.withValues(
                                      alpha: colorScheme.onSurface.a *
                                          contentOpacity,
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

  /// One shared backdrop group for gaussian cards on this week page.
  Widget _wrapCourseGridSurfaceHost({
    required TimetableSettings settings,
    required Widget child,
  }) {
    return CourseGridSurfaceHost(settings: settings, child: child);
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
      onAddTask: (target) => _openTaskFromCourse(target, week),
      // 单节课提醒依赖原生精确闹钟调度，其他平台不显示入口。
      onSetAlarm: (!kIsWeb && Platform.isAndroid)
          ? (target) => _openClassReminderSheet(target, week)
          : null,
    );
  }

  Future<void> _openTaskFromCourse(Course course, int week) async {
    final provider = context.read<TimetableProvider>();
    final existing = provider
        .getTasksForCourse(course.id)
        .where((task) => task.sourceWeek == null || task.sourceWeek == week)
        .firstOrNull;
    await Navigator.of(context).push<bool>(
      HyperosPageRoute<bool>(
        builder: (_) => AddTaskScreen(
          task: existing,
          initialCourse: course,
          initialWeek: week,
        ),
      ),
    );
  }

  /// 单节课提醒：打开提醒设置弹层（快捷提前量 / 自定义时间 / 取消）。
  Future<void> _openClassReminderSheet(Course course, int week) {
    return showClassReminderSheet(context, course: course, week: week);
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
    final hasBackdrop = hasHomePageBackdropImage(settings);
    // Same wallpaper auto-contrast as weekday ink; user-custom time-axis hex
    // is never replaced. The time column spans the body band (not the
    // status/title strip), so judge from the card-region sample.
    final timeAxisColor = homePageOverWallpaperInk(
      configuredHex: isDark
          ? settings.timeAxisFontColorDark
          : settings.timeAxisFontColorLight,
      defaultHex: isDark
          ? TimetableSettings.defaultTimeAxisFontColorDark
          : TimetableSettings.defaultTimeAxisFontColorLight,
      themeFallback: isDark ? Colors.white : Colors.grey.shade800,
      hasBackdrop: hasBackdrop,
      wallpaperLuminance: _wallpaperBodyLuminance ?? _wallpaperTopLuminance,
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
      // TA 课表是覆盖层叠加，不是切换对象；switchProfile 对它静默守卫，
      // 列出来只会造成「点了没反应」。
      profiles: provider.profiles
          .where((profile) => !profile.isPartnerImported)
          .toList(growable: false),
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
    // The anchored menu floats over the wallpaper; give its rows the same
    // wallpaper-aware ink as the home chrome (white over dark wallpaper,
    // dark over light) instead of the theme's onSurface color.
    final provider = context.read<TimetableProvider>();
    final settings = provider.settings;
    final hasBackdrop = hasHomePageBackdropImage(settings);
    final headerShowsBackdrop = homePageRegionShowsBackdrop(
      settings,
      HomePageBackgroundScope.header,
    );
    final headerUsesFrostedChrome =
        hasBackdrop &&
        (headerShowsBackdrop || settings.homePageHeaderBlurEnabled);
    final menuForeground = _resolveHomeChromeForeground(
      headerShowsWallpaper: headerUsesFrostedChrome,
      themeForeground: context.theme.colors.foreground,
    );

    // 菜单形态由设置分流：「八宫格」是 v2.0.5.5 已发布版本的底部弹层，
    // 「列表」是当前的锚定弹窗。两种形态共享同一份自定义排列
    // （homeGridMenuActions），统一以入口 id 回传，再经目录分发到
    // 全应用任意二级页面/功能。
    final String? selectedId;
    if (settings.homeMenuStyle == HomeMenuStyle.grid) {
      selectedId = await showHomeTopGridMenuSheet(
        context,
        hasAvailableUpdate: _hasAvailableUpdate,
        entries: resolveHomeGridMenuEntries(settings),
        themeSeedHex: settings.themeSeedColor,
      );
    } else {
      selectedId = await showHomeTopMenuSheet(
        context,
        hasAvailableUpdate: _hasAvailableUpdate,
        entries: resolveHomeGridMenuEntries(settings),
        anchorKey: _topMenuButtonKey,
        foregroundColor: menuForeground,
      );
    }

    if (!mounted || selectedId == null) {
      return;
    }

    // Let the sheet route finish closing before pushing the next page.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) {
      return;
    }

    switch (selectedId) {
      // 这两项依赖首页宿主上下文：添加课程要带日视图选中日期弹层，
      // 更新入口要先做版本检查再进详情页。其余全部走目录分发。
      case 'addCourse':
        await _navigateToAddCourse(context);
      case 'update':
        await _openTopMenuUpdatePage();
      default:
        final entry = homeMenuEntryById(selectedId);
        if (entry != null) {
          await entry.open(context);
        }
    }
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
      _scheduleHomeUpdatePrompt(result);
    } catch (_) {
      // Ignore update check failures on home screen; About page provides details.
    } finally {
      _isCheckingForUpdate = false;
    }
  }

  /// 检测到新版本后在首页弹出更新提醒（受「弹窗提醒」开关控制，
  /// 关闭时保持静默，仅依赖 ⋮ 菜单红点角标）。
  void _scheduleHomeUpdatePrompt(AppUpdateCheckResult result) {
    if (!result.hasUpdate ||
        result.latestRelease == null ||
        _hasPresentedUpdatePrompt ||
        _isUpdatePromptVisible) {
      return;
    }
    final provider = context.read<TimetableProvider>();
    final settings = provider.settings;
    if (!settings.appUpdatePromptEnabled) {
      return;
    }
    final release = result.latestRelease!;
    final channel = AppUpdateDownloadChannelX.fromValue(
      settings.appUpdateDownloadChannel,
    );
    final source = AppUpdateDownloadSourceX.fromValue(
      settings.appUpdateDownloadSource,
    );
    final mirrorPreset = AppUpdateMirrorPresetX.fromValue(
      settings.appUpdateMirrorPreset,
    );
    final mirrorPrefix = resolveAppUpdateMirrorUrlPrefix(
      preset: mirrorPreset,
      customUrlPrefix: settings.appUpdateMirrorUrlPrefix,
    );
    final effectiveDownloadUrl = _updateService.getEffectiveDownloadUrl(
      release: release,
      channel: channel,
      source: source,
      mirrorUrlPrefix: mirrorPrefix,
    );
    final hasDirectDownload =
        effectiveDownloadUrl != null && effectiveDownloadUrl.trim().isNotEmpty;
    final promptDownloadUrl = effectiveDownloadUrl ?? release.releaseUrl;
    if (promptDownloadUrl.trim().isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasPresentedUpdatePrompt || _isUpdatePromptVisible) {
        return;
      }
      // 首页不在栈顶时（例如启动直达二级页）不打断用户。
      if (ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      _hasPresentedUpdatePrompt = true;
      _isUpdatePromptVisible = true;
      unawaited(
        _showHomeUpdatePromptAndTrackState(
          release: release,
          currentVersion: result.currentVersion,
          channel: channel,
          downloadUrl: promptDownloadUrl,
          hasDirectDownload: hasDirectDownload,
        ),
      );
    });
  }

  Future<void> _showHomeUpdatePromptAndTrackState({
    required AppReleaseInfo release,
    required String currentVersion,
    required AppUpdateDownloadChannel channel,
    required String downloadUrl,
    required bool hasDirectDownload,
  }) async {
    try {
      await showHomeUpdatePrompt(
        context,
        release: release,
        currentVersion: currentVersion,
        downloadChannel: channel,
        hasDirectDownload: hasDirectDownload,
        controller: _updatePromptController,
        onDownload: () async {
          if (!hasDirectDownload) {
            await _openUpdateReleasePage(release.releaseUrl);
            return false;
          }
          return _startHomeUpdateDownload(
            release: release,
            channel: channel,
            downloadUrl: downloadUrl,
          );
        },
        onViewRelease: () => _openUpdateReleasePage(release.releaseUrl),
        onCancelDownload: _cancelHomeUpdateDownload,
        onResumeDownload: () => _startHomeUpdateDownload(
          release: release,
          channel: channel,
          downloadUrl: downloadUrl,
        ),
      );
    } finally {
      _isUpdatePromptVisible = false;
    }
  }

  Future<bool> _startHomeUpdateDownload({
    required AppReleaseInfo release,
    required AppUpdateDownloadChannel channel,
    required String downloadUrl,
  }) async {
    if (channel == AppUpdateDownloadChannel.pgyer) {
      await _openUpdateReleasePage(downloadUrl);
      return false;
    }

    final settings = context.read<TimetableProvider>().settings;
    if (settings.appUpdateDownloadChannel ==
        AppUpdateDownloadChannel.pgyer.value) {
      await _openUpdateReleasePage(downloadUrl);
      return false;
    }

    if (_useSystemUpdateDownloader(settings)) {
      final version = release.version.trim().replaceAll(' ', '_');
      final downloadId = await _supportCreatorService.enqueueSystemDownload(
        url: downloadUrl,
        fileName: version.isEmpty ? 'mikcb_update.apk' : 'mikcb_v$version.apk',
        title: AppLocalizations.of(context)!.aboutUpdatePackageTitle,
        description: AppLocalizations.of(
          context,
        )!.aboutUpdatePackageDescription,
      );
      if (downloadId == null) {
        return false;
      }
      final initialProgress = await _supportCreatorService
          .querySystemDownloadProgress(downloadId);
      if (initialProgress != null) {
        _updatePromptController.beginSystemDownload(
          downloadId: downloadId,
          progress: initialProgress,
        );
      }
      _watchSystemUpdateDownload(downloadId);
      return true;
    }

    final controller = AppUpdateDownloadController();
    _homeDownloadController = controller;
    _updatePromptController.beginInAppDownload();
    final mirrorPreset = AppUpdateMirrorPresetX.fromValue(
      settings.appUpdateMirrorPreset,
    );
    final mirrorPrefix = resolveAppUpdateMirrorUrlPrefix(
      preset: mirrorPreset,
      customUrlPrefix: settings.appUpdateMirrorUrlPrefix,
    );
    final error = await _updateService.downloadAndInstallUpdate(
      downloadUrl,
      (downloadedBytes, totalBytes) {
        _updatePromptController.updateInAppProgress(
          downloadedBytes,
          totalBytes,
        );
      },
      controller,
      mirrorUrlPrefix: mirrorPrefix,
    );
    if (!mounted) {
      return true;
    }
    _homeDownloadController = null;
    final wasCancelled = error == AppUpdateService.downloadCancelledMessage;
    _updatePromptController.finishInAppDownload(
      success: error == null,
      cancelled: wasCancelled,
    );
    return true;
  }

  bool _useSystemUpdateDownloader(TimetableSettings settings) {
    return settings.appUpdateUseSystemDownloader;
  }

  void _watchSystemUpdateDownload(int downloadId) {
    unawaited(() async {
      try {
        await for (final progress
            in _supportCreatorService.watchSystemDownloadProgress(downloadId)) {
          if (!mounted) {
            return;
          }
          _updatePromptController.updateSystemDownload(progress);
        }
      } catch (_) {
        // The system queue can briefly disappear while the provider starts;
        // keep the prompt visible and let the next observation recover.
      }
    }());
  }

  void _cancelHomeUpdateDownload() {
    _homeDownloadController?.cancel();
    _updatePromptController.markCancelling();
  }

  Future<void> _openUpdateReleasePage(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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

  const _DayViewPageTarget({required this.week, required this.dayOfWeek});
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
  final ScheduleItemInstance? scheduleInstance;
  final Exam? exam;
  final String startTime;
  final String endTime;
  final bool continuesFromPreviousDay;
  final bool continuesToNextDay;

  const _DayAgendaItem._({
    this.courseItem,
    this.scheduleItem,
    this.scheduleInstance,
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
    ScheduleItemInstance? instance,
    required String startTime,
    required String endTime,
    bool continuesFromPreviousDay = false,
    bool continuesToNextDay = false,
  }) {
    return _DayAgendaItem._(
      scheduleItem: item,
      scheduleInstance: instance,
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
      exam?.id ??
      (isScheduleItem
          ? scheduleInstance?.occurrenceId ?? scheduleItem!.id
          : courseItem!.course.id);
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
