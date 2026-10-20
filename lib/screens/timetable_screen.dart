import 'dart:async';
import 'dart:io';
import 'package:flutter_miuix/miuix.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'dart:math' as math;

// OpenContainer 用 vendored 优化版(lib/widgets/open_container.dart):
// 上游在转场每帧重调 openBuilder/closedBuilder,日视图课程详情的
// container transform 变成每帧整页 rebuild(见该文件头注释)。
import 'package:university_timetable/widgets/open_container.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart'
    show
        Drag,
        GestureBinding,
        VelocityTracker,
        kMinFlingVelocity;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/course.dart';
import '../models/exam.dart';
import '../models/schedule_item.dart';
import '../models/timetable_settings.dart';
import '../domain/clock_order.dart';
import '../domain/couple_timetable_logic.dart';
import '../domain/day_course_display_logic.dart';
import '../domain/day_view_paging.dart';
import '../domain/week_calculator.dart';
import '../providers/timetable_provider.dart';
import '../providers/weather_provider.dart';
import '../services/app_update_service.dart';
import '../services/screen_capture_service.dart';
import '../services/support_creator_service.dart';
import '../services/timetable_share_service.dart';
import '../services/widget_launch_router.dart';
import '../widgets/class_reminder_sheet.dart';
import '../utils/app_toast.dart';
import '../utils/hex_color.dart';
import '../utils/course_color_palette.dart';
import '../widgets/home_page_region_blur.dart';
import '../controllers/empty_slot_marker_controller.dart';
import '../controllers/home_pull_controller.dart';
import '../controllers/update_check_controller.dart';
import '../controllers/wallpaper_luminance_controller.dart';
import '../utils/home_page_background.dart';
import '../utils/home_startup_visual_primer.dart';
import '../utils/home_wallpaper_luminance_share.dart';
import '../ui/home/home_chrome_spec.dart';
import '../ui/hyperos/liquid/liquid_glass_surface.dart'
    show LiquidGlassSurface, LiquidGlassSurfaceState;
import '../widgets/course_action_sheet.dart';
import '../widgets/course_note_sheet.dart';
import '../widgets/course_card.dart';
import '../widgets/course_surface.dart';
import '../widgets/course_grid_surface_host.dart';
import '../widgets/course_weather_display.dart';
import '../widgets/day_agenda_info_row.dart';
import '../widgets/day_course_weather_row.dart';
import '../widgets/home_menu_catalog.dart';
import '../widgets/home_top_menu.dart';
import '../widgets/home_top_menu_popup.dart';
import '../widgets/home_update_prompt.dart';
import '../widgets/timetable_home_preview_scope.dart';
import '../widgets/week_selector_picker_sheet.dart';
import '../widgets/timetable/timetable_back_to_current_week_button.dart';
import '../widgets/timetable/timetable_back_to_today_button.dart';
import '../widgets/timetable/timetable_course_action_items.dart';
import '../widgets/timetable/timetable_course_sheet_actions.dart';
import '../widgets/timetable/timetable_week_grid.dart';
import '../widgets/timetable/timetable_section_time_cell.dart';
import '../widgets/timetable/timetable_week_page.dart';
import '../widgets/timetable/timetable_week_page_body.dart';
import '../widgets/timetable/timetable_empty_slot_layer.dart';
import '../widgets/timetable/timetable_day_view_shared_free_summary.dart';
import '../widgets/timetable/timetable_day_column.dart';
import '../widgets/timetable/timetable_anchored_day_overlay.dart';
import '../widgets/timetable/timetable_day_agenda_models.dart';
import '../widgets/timetable/timetable_home_action_button.dart';
import '../widgets/timetable/timetable_day_pager_physics.dart';
import '../widgets/timetable/timetable_home_dock_shell.dart';
import '../widgets/timetable/timetable_home_header.dart';
import '../widgets/timetable/timetable_home_stack.dart';
import '../widgets/timetable/timetable_home_pull_surface.dart';
import '../widgets/timetable/timetable_home_scroll.dart';
import '../widgets/timetable/timetable_glass_dock.dart';
import '../widgets/timetable/timetable_open_only_route.dart';
import '../widgets/timetable/timetable_profile_quick_switch.dart';
import '../widgets/timetable/timetable_top_menu_shell.dart';
import '../widgets/timetable/timetable_weekday_ink_contrast_dialog.dart';
import 'add_course_screen.dart';
import 'add_exam_screen.dart';
import 'add_schedule_item_screen.dart';
import 'add_task_screen.dart';
import 'about_screen.dart';
import 'import/home_pull_quick_import.dart';
import 'timetable_profiles_screen.dart';

part 'timetable_update_download_part.dart';

part 'timetable_day_view_part.dart';

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
    with WidgetsBindingObserver, TickerProviderStateMixin {
  static const int _minWeek = 1;
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

  /// 两步式「长按空白格添加课程」的标记（可开关，见
  /// [TimetableSettings.longPressEmptySlotToAddCourseEnabled]）：当前处于
  /// 「虚线加号」态的 周次/星期/节次。周次也入列是为了相邻页预渲染
  ///（allowImplicitScrolling）时不在别的周页上误显标记。
  final GlobalKey _timetableSurfaceKey = GlobalKey();

  /// Anchor for the top-right "more" menu popup (positioned below this key).
  final GlobalKey _topMenuButtonKey = GlobalKey();

  /// 底栏那两块液态玻璃面：药丸 + 右侧合并圆钮（同一份材质推导，见
  /// [TimetableGlassDockLayer]）。持有它们是为了在**推路由**时按下按压光斑：缩放
  /// 转场第 0 帧会把整屏烤成快照，光斑被定格就会变成「亮光接缩小动画时闪一下」。
  /// 见 [_pushAfterDockGlowSettled]。
  ///
  /// ⚠️ **两块都要**：它们是各自独立的 [LiquidGlassSurface]、各有各的光斑，而
  /// 圆钮（[_handleRoundButtonTap]）同样会 `entry.open(context)` 推路由。只挂药丸
  /// 的话，用户把圆钮也指到「外观编辑」时那条路原样漏（2026-09-26 自审补上）。
  /// 非液态材质档压根没有光斑，`currentState` 为 null，`?.` 天然跳过。
  final GlobalKey<LiquidGlassSurfaceState> _glassDockKey =
      GlobalKey<LiquidGlassSurfaceState>();
  final GlobalKey<LiquidGlassSurfaceState> _glassDockRoundKey =
      GlobalKey<LiquidGlassSurfaceState>();

  /// 首页「更多」菜单（列表形态）改用上游 flutter_miuix 1.2.0 的 HyperOS 4
  /// 玻璃弹层后的持有物。按上游约定：锚点与材质捕获容器由宿主创建并持有
  ///（[MiuixGlassPopupAnchor.dispose] 在 [dispose] 里释放）；弹层是
  /// 「常驻挂载 + 切 show」的声明式组件，故用 [_homeMenuOpen] 控制显隐。
  final MiuixGlassPopupAnchor _homeMenuAnchor = MiuixGlassPopupAnchor();

  /// 顶栏「更多」「爱心」常驻玻璃球的位置锚（[FHeaderActionBall] 跟随真实
  /// 按钮的透明点击区）。
  final LayerLink _moreBallLink = LayerLink();
  final LayerLink _heartBallLink = LayerLink();

  /// 首页整屏的玻璃采样源。首页自持（而不是让宿主自建）有两个原因：
  /// 1. 首页右上角菜单与首页内容不在同一棵子树里（菜单要在捕获之外，防反馈采样），
  ///    菜单必须拿到**首页这一屏**的 backdrop，而不是"注册表栈顶"（玻璃坞里被盖住的
  ///    内嵌页也会注册，栈顶可能是一屏不绘制的页面 → 快照为空 → 菜单透明）；
  /// 2. 「更多」按钮按下即 `acquire` 预热录帧，抬手打开菜单时快照已就绪，
  ///    弹层首帧就有玻璃（否则展开头一两帧是透明轮廓）。
  final HyperosGlassBackdropController _homeGlass =
      HyperosGlassBackdropController();
  bool _homeGlassHeld = false;
  bool _homeMenuOpen = false;
  final AppUpdateService _updateService = AppUpdateService();
  late final UpdateCheckController _update;
  final SupportCreatorService _supportCreatorService = SupportCreatorService();
  final HomeUpdatePromptController _updatePromptController =
      HomeUpdatePromptController();
  bool _isUpdatePromptVisible = false;
  bool _hasPresentedUpdatePrompt = false;
  AppUpdateDownloadController? _homeDownloadController;
  StreamSubscription<SystemDownloadProgress>? _systemDownloadSubscription;
  bool? _lastUpdateCheckIncludePrerelease;

  /// 截屏检测订阅与节流状态。
  ///
  /// [_screenshotListening] 存的是「当前是否应该监听」，用来跟开关比对；
  /// 真实注册由 [ScreenCaptureService] 负责，平台不支持时它自己空转。
  StreamSubscription<void>? _screenshotSubscription;
  bool _screenshotListening = false;
  DateTime? _lastScreenshotPromptAt;

  /// 连拍截屏不叠提示的最小间隔（略大于提示自身的存活时间）。
  static const Duration _screenshotPromptCooldown = Duration(seconds: 6);

  /// 截屏提示的存活时间。
  ///
  /// 比普通 toast 长得多：这是一句「要不要做点什么」的邀请，2 秒来不及看清
  /// 就消失会显得像误触。官方的截屏通知本来就同时弹了，多停几秒不算打扰。
  static const Duration _screenshotPromptDuration = Duration(seconds: 5);

  /// In-flight update check, used for de-duplication.
  ///
  /// A shared [Future] (instead of a boolean flag) cannot leak: every early
  /// exit still completes the future, so a forgotten manual reset is
  /// impossible no matter how many new early-return branches are added.
  Future<void>? _inflightUpdateCheck;
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
  /// when touch batching starves it (see TimetableDayPagerFlickRescuePhysics).
  final Map<int, TimetableDayPagerFlickProbe> _dayPagerFlickProbes =
      <int, TimetableDayPagerFlickProbe>{};

  /// Pending scroll-space rescue velocity, armed on pointer-up and consumed
  /// once by [_dayPagerPhysics] within the same event dispatch.
  double _dayPagerRescueVelocityX = 0;
  DateTime? _dayPagerRescueArmedAt;

  /// 单次手势只允许一次日切换点击震感的闩锁。onPageChanged 在滑过每个页
  /// 中点时都会触发：快速甩动一次跨两页、或甩动后弹簧回弹再越过中点，
  /// 都会连响两次。指针按下 / 星期栏拖动开始时重新武装，settle 提交后也
  /// 重新武装（覆盖纯惯性问题）。
  bool _daySwipeHapticFired = false;
  late final TimetableDayPagerFlickRescuePhysics _dayPagerPhysics =
      TimetableDayPagerFlickRescuePhysics(
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

  static const Duration _partnerScheduleStaleAfter = Duration(days: 7);

  /// Finger travel (after resistance) required to fire quick import.

  /// Last "custom weekday ink is unreadable" combination already warned about
  /// this session; the persisted twin lives in SharedPreferences.
  String? _weekdayInkWarnedSignature;
  bool _weekdayInkWarningShowing = false;

  bool _isCoupleOverlayActive(TimetableProvider provider) =>
      _coupleOverlayEnabled && provider.hasPartnerBinding;

  /// 「缩尺预览」宿主（「外观编辑」页）注入时非空；正常首页为 null。
  ///
  /// 非空即**预览模式**：日 / 周由外部 notifier 驱动，且不写回访状态、
  /// 不接截屏监听（见 [TimetableHomePreviewScope] 的类注释）。
  TimetableHomePreviewScope? _previewScope;
  bool _previewSyncScheduled = false;

  bool get _isPreview => _previewScope != null;

  /// 预览那份首页里几块纵向滚动体各自的控制器（按 [PageStorageKey] 字符串索引）。
  ///
  /// **只有预览那份需要**：真实首页那份继续用 `ScrollView` 内部的兜底控制器 +
  /// `PageStorage`（本页是最热的屏，不去动它的滚动结构）；而预览那份要按宿主给的
  /// [HomeScrollOffsets] 起步 —— 它的 `PageStorage` 桶属于**编辑页那条路由**，
  /// 与真实首页那份毫无关系，救不了（见 [TimetableHomePreviewScope] 类注释）。
  ///
  /// 按 key 一块一个而不是全局一个：日视图每一天一页、每一页一条列表（同一时刻
  /// 活着三条），一个控制器挂到两个滚动体上会直接触发
  /// 「ScrollController attached to multiple scroll views」断言。
  final Map<String, ScrollController> _previewScrollControllers =
      <String, ScrollController>{};

  /// 日视图某一页那条列表的 key（与它自己的 [PageStorageKey] 同串）。
  static String _dayAgendaScrollKey(int week, int dayOfWeek) =>
      'day-agenda-$week-$dayOfWeek';

  /// 周视图某一页那块网格滚动体的 key。
  static String _weekGridScrollKey(int week) => 'week-scroll-$week';

  /// 预览那份的滚动控制器；真实首页返回 null（照旧走内部兜底控制器）。
  ///
  /// 首次为某个 key 建控制器时取 [HomeScrollOffsets] 里的初值，之后同一个 key
  /// 一直复用同一颗（重建列表时不能换控制器，否则位置与动画状态全丢）。
  ScrollController? _previewControllerFor(String key) {
    if (!_isPreview) {
      return null;
    }
    return _previewScrollControllers.putIfAbsent(
      key,
      () => ScrollController(
        initialScrollOffset: _previewScope?.scrollOffsets[key] ?? 0,
      ),
    );
  }

  /// 把一块纵向滚动体的位置报给「缩尺预览」那份首页（见 [publishHomeScrollOffset]）。
  ///
  /// 只收 `ScrollUpdate` / `ScrollEnd`：**不收 `ScrollMetricsNotification`** ——
  /// 它在滚动体挂上、拿到尺寸时就发，而那时 `PageStorage` 的恢复值可能还没应用
  /// （`applyNewDimensions` 先发通知、后 `restoreScrollOffset`），报上去的是
  /// 「恢复前的 0」，会把真实位置覆盖掉。恢复后紧接着的第一次真实滚动才会报对。
  ///
  /// 预览自己那份不回灌（否则会把真实首页的位置换成预览的），横向的日 / 周翻页
  /// 也不管（那不是纵向位置）。
  Widget _reportHomeScroll(String key, Widget child) {
    if (_isPreview) {
      return child;
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis == Axis.vertical &&
            (notification is ScrollUpdateNotification ||
                notification is ScrollEndNotification)) {
          publishHomeScrollOffset(key, notification.metrics.pixels);
        }
        // 不消费：下拉冻结（见 [TimetableHomePullFreezeScrollPhysics]）等既有监听照旧。
        return false;
      },
      child: child,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = TimetableHomePreviewScope.maybeOf(context);
    if (identical(scope, _previewScope)) {
      return;
    }
    _previewScope?.dayView.removeListener(_onPreviewDayViewChanged);
    _previewScope?.dayOfWeek.removeListener(_onPreviewDayViewChanged);
    _previewScope = scope;
    scope?.dayView.addListener(_onPreviewDayViewChanged);
    scope?.dayOfWeek.addListener(_onPreviewDayViewChanged);
    if (scope != null) {
      _onPreviewDayViewChanged();
    }
  }

  /// 宿主拨了日 / 周之后，把嵌进来的这一份首页同步过去。
  ///
  /// 一律推迟到帧末执行：宿主既可能在点按回调里改 notifier（那时直接 setState
  /// 没问题），也可能在自己的 didChangeDependencies 里改（那是 build 期，
  /// 同步 setState 会直接报错）。统一延后就没有这两种时序要分。
  void _onPreviewDayViewChanged() {
    if (_previewSyncScheduled) {
      return;
    }
    _previewSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _previewSyncScheduled = false;
      final scope = _previewScope;
      if (!mounted || scope == null) {
        return;
      }
      final settings = context.read<TimetableProvider>().settings;
      if (scope.dayView.value) {
        unawaited(
          _toggleDayView(
            week: _visibleWeek,
            // 看哪一天与首页「日课表」Tab 同一条口径：宿主的 notifier 可能停在
            // 一个不显示的日子（周末被关掉时的周日），这里按可见日归一，免得
            // 选择落在看不见的那天上。
            dayOfWeek: _resolveStoredDayOfWeek(settings, scope.dayOfWeek.value),
            settings: settings,
            // 预览不做展开动画：宿主那一帧已经切完了，动画只会让它慢半拍。
            animate: false,
            // 这是「把预览设成日视图」的目标状态，不是一次点按：宿主与预览
            // 本来就该一致，一致时重复下发不能把日视图关掉。
            sameSelectionCloses: false,
          ),
        );
        return;
      }
      unawaited(_closeDayView(settings, animate: false));
    });
  }

  Color _colorFromHex(String hexColor, Color fallback) {
    return parseHexColorOrFallback(hexColor, fallback: fallback);
  }

  late final WallpaperLuminanceController _luminance;

  late final HomePullController _homePull;

  late final EmptySlotMarkerController _emptySlot;

  @override
  void initState() {
    super.initState();
    _emptySlot = EmptySlotMarkerController()
      ..addListener(_handleEmptySlotChanged);
    _update = UpdateCheckController(service: _updateService)
      ..addListener(_handleUpdateChanged);
    _homePull = HomePullController(
      vsync: this,
      onTriggerImport: _runHomePullQuickImport,
      onSelectionHaptic: _homePullSelectionHaptic,
    )..addListener(_handleHomePullChanged);
    _luminance = WallpaperLuminanceController()
      ..addListener(_handleLuminanceChanged);
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
    // 下拉进度的收尾看门狗：全局指针路由（事件先到这里，再走命中派发），
    // 与下拉当前由哪条路驱动无关。见 [_homePullLivePointers]。
    GestureBinding.instance.pointerRouter.addGlobalRoute(
      _homePull.onGlobalPointerEvent,
    );
    _restoreViewStateFromProvider(provider);
    if (widget.enableUpdateCheck) {
      _checkForAppUpdate(
        includePrerelease: provider.settings.appUpdateIncludePrerelease,
      );
    }
  }

  void _handleLuminanceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleEmptySlotChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleUpdateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleHomePullChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _homePullSelectionHaptic() {
    if (!mounted) return;
    if (context.read<TimetableProvider>().settings.enableHaptics) {
      HapticFeedback.selectionClick();
    }
  }

  @override
  void dispose() {
    _previewScope?.dayView.removeListener(_onPreviewDayViewChanged);
    _previewScope?.dayOfWeek.removeListener(_onPreviewDayViewChanged);
    WidgetsBinding.instance.removeObserver(this);
    WidgetLaunchRouter.coupleOverlayRequestTick.removeListener(
      _onExternalCoupleOverlayRequest,
    );
    GestureBinding.instance.pointerRouter.removeGlobalRoute(
      _homePull.onGlobalPointerEvent,
    );
    _homeDownloadController?.cancel();
    _systemDownloadSubscription?.cancel();
    _updatePromptController.dispose();
    _update.removeListener(_handleUpdateChanged);
    _update.dispose();
    _homePull.removeListener(_handleHomePullChanged);
    _homePull.dispose();
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
    for (final controller in _previewScrollControllers.values) {
      controller.dispose();
    }
    _previewScrollControllers.clear();
    // 页面走了就把截屏监听交回去：监听不该比「谁在听」活得久。
    unawaited(_screenshotSubscription?.cancel());
    _screenshotSubscription = null;
    _screenshotListening = false;
    unawaited(ScreenCaptureService.stop());
    _homeMenuAnchor.dispose();
    _homeGlass.dispose();
    _emptySlot.removeListener(_handleEmptySlotChanged);
    _emptySlot.dispose();
    _luminance.removeListener(_handleLuminanceChanged);
    _luminance.dispose();
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
        // 必须在表头与日面板读 `_selectedDayOfWeek` 之前归一（方法注释里有
        // 不改会错在哪三处的说明）。
        _syncDayViewSelectionWithVisibleDays(provider.settings);
        _scheduleUpdateCheckIfNeeded(provider);
        _syncWeekPageWithProvider(provider.currentWeek, provider.settings);
        _syncScreenshotListener(provider.settings);
        final colorScheme = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final darkFallback = colorScheme.surface;
        final settings = provider.settings;
        final viewportSize = MediaQuery.sizeOf(context);
        // 启动预热器 / 本进程里任意一份首页采过的亮度带，只要这一份键对得上就
        // 首帧直接采用：标题/状态栏/星期栏/底栏的黑白墨极性第一帧即正确，不出现
        // 「按主题兜底再翻面」的闪变（缩尺预览那份首页靠的就是这条）。仅在本页
        // 尚未开始采样时生效；异步精确采样照常运行并以同值幂等收敛。
        _luminance.seedFromPrimerOrShare(
          settings,
          viewportSize: viewportSize,
        );
        final chrome = resolveHomeChromeSpec(
          context: context,
          settings: settings,
          isDark: isDark,
          darkFallback: darkFallback,
          wallpaperTopLuminance: _luminance.top,
        );
        final glassDockForm = chrome.glassDockForm;
        final hasBackdrop = chrome.hasBackdrop;
        final chromeForeground = chrome.chromeForeground;
        final chromeMutedForeground = chrome.chromeMutedForeground;
        final chromeDotBorderColor = chrome.chromeDotBorderColor;
        final followsWeekPager = chrome.followsWeekPager;
        final useHomePreblur = chrome.useHomePreblur;
        final homePreblurSigma = chrome.homePreblurSigma;
        final courseCardPreblurSigma = chrome.courseCardPreblurSigma;
        _luminance.schedule(
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
        // 顶栏「更多」「爱心」的常驻玻璃球（[FHeaderActionBall]）。**必须画在
        // 采样宿主之外**（_wrapHomeWithTopMenu 的 Stack 里、Host 的兄弟层）：
        // 页内玻璃的采样快照录自捕获节点的图层，球若长在捕获子树里，它自己的
        // 输出会被烘进下一次采样 —— 打开菜单时按钮被上游隐藏，快照是干净的，
        // 关闭后按钮重绘即触发重采样，球就"变一次材质"并稳定在烘过自己一层
        // 的样子（2026-09-14 真机现象）。图标墨色见 [_chromeActionBallInk]；
        // 「更多」在菜单打开期间让位给弹窗自己的形变球（与真实按钮被
        // `contentHidden` 隐藏的窗口一致，见 ListenableBuilder）。
        final homeChromeBalls = buildTimetableHomeChromeBalls(
          homeMenuAnchor: _homeMenuAnchor,
          moreLink: _moreBallLink,
          heartLink: _heartBallLink,
          hasPartnerBinding: provider.hasPartnerBinding,
          coupleOverlayActive: _isCoupleOverlayActive(provider),
          moreIcon: _buildMoreActionIcon(dotBorderColor: chromeDotBorderColor),
          chromeActionBallInk: _chromeActionBallInk,
        );
        // 与设置页课表预览完全同构的组采样结构：BackdropGroup 内先放全尺寸
        // UndimmedBackdropCapture（组内首个 filter 缓存整屏壁纸），chrome 玻璃
        // 带采样这份全尺寸背景。此前首页玻璃带只能采样自己 band bounds 的背
        // 景，折射位移在带边被钳制，观感与预览（组内全尺寸采样）不一致。
        //
        // ⚠️ 这套结构搭好之后，**带那一侧一直没接上开关**
        // （`HomePageChromeGlassFill.useAncestorBackdropGroup` 默认 false），于是
        // "折射在带边被钳制"照旧发生，并从那条唯一可见的下边读出来：打开磨砂强度后
        // 星期栏底边一条黑线（用户 2026-09-20 实测）。2026-09-20 才把开关接上，
        // 见 `widgets/home_page_region_blur.dart` 的 `HomePageContinuousChromeFrostedOverlay`。
        final Widget homeStack = _buildHomeStackView(
          provider: provider,
          settings: settings,
          l10n: l10n,
          chrome: chrome,
          chromeForeground: chromeForeground,
          chromeMutedForeground: chromeMutedForeground,
          hasBackdrop: hasBackdrop,
          glassDockForm: glassDockForm,
        );

        // 玻璃坞形态下课表（含壁纸）与设置页都常驻挂载，用 Offstage 切换：
        // - 设置页的滚动位置与大标题折叠状态不随 Tab 切换丢失（切走再切回，
        //   标题保持离开时的折叠态）；
        // - 壁纸层随 homeStack 常驻，解码缓存不失效，切回课表不黑闪。
        // 玻璃坞导航始终由 [TimetableGlassDockLayer] 浮在最上层（画在采样宿主之外）。
        return _buildDockShell(
          homeStack: homeStack,
          useHomePreblur: useHomePreblur,
          settings: settings,
          homePreblurSigma: homePreblurSigma,
          courseCardPreblurSigma: courseCardPreblurSigma,
          followsWeekPager: followsWeekPager,
          glassDockForm: glassDockForm,
          homeChromeBalls: homeChromeBalls,
          chromeDotBorderColor: chromeDotBorderColor,
        );
      },
    );
  }

  Widget _buildHomeStackView({
    required TimetableProvider provider,
    required TimetableSettings settings,
    required AppLocalizations l10n,
    required HomeChromeSpec chrome,
    required Color chromeForeground,
    required Color chromeMutedForeground,
    required bool hasBackdrop,
    required bool glassDockForm,
  }) {
    return TimetableHomeStack(
      settings: settings,
      l10n: l10n,
      chrome: chrome,
      weekPageController: _weekPageController,
      title: _buildProfileSwitcherTrigger(
        provider,
        foreground: chromeForeground,
        mutedForeground: chromeMutedForeground,
      ),
      suffixes: buildTimetableHomeHeaderActions(
        l10n: l10n,
        hasPartnerBinding: provider.hasPartnerBinding,
        coupleOverlayActive: _isCoupleOverlayActive(provider),
        heartLink: _heartBallLink,
        moreLink: _moreBallLink,
        homeMenuAnchor: _homeMenuAnchor,
        topMenuButtonKey: _topMenuButtonKey,
        onToggleCoupleOverlay: () {
          setState(() {
            _coupleOverlayEnabled = !_coupleOverlayEnabled;
            _sharedFreeSegmentsExpanded = false;
          });
          _persistCoupleOverlayEnabled(
            provider,
            enabled: _coupleOverlayEnabled,
          );
        },
        onPrewarmGlass: _prewarmHomeGlass,
        onReleaseGlass: _releaseHomeGlassAfterTap,
        onShowTopActions: _showTopActionsSheet,
      ),
      weekSurface: TimetableHomePullSurface(
        settings: settings,
        hasBackdrop: hasBackdrop,
        timetableSurfaceKey: _timetableSurfaceKey,
        isRunning: _homePull.isRunning,
        isDayView: _isDayView,
        glassDockContentScrollInset: _glassDockContentScrollInset(
          settings,
        ),
        onScrollNotification: _homePull.handleScrollNotification,
        onPullUpdate: _homePull.updateDrag,
        onPullEnd: _homePull.finishDrag,
        onPullCancel: _homePull.cancelDrag,
        resetFreeze: _homePull.resetFreeze,
        onPointerMove: _homePull.onPointerMove,
        weekPageController: _weekPageController,
        dayViewPageController: _dayViewPageController,
        visibleDayViewWeek: _visibleDayViewWeek,
        shouldShowDayViewOverlay: _shouldShowDayViewOverlay,
        wallpaperTopLuminance: _luminance.top,
        wallpaperWeekdayLuminance: _luminance.weekday,
        timeColumnWidth: _resolveTimeColumnWidth(settings),
        isSelectedDay: _isSelectedDay,
        hasExamOnDate: provider.hasExamOnDate,
        onShowWeekSelector: _showWeekSelector,
        onDayTapDown: _captureDayViewAnchor,
        onDayTap: (week, dayOfWeek) {
          _toggleDayView(
            week: week,
            dayOfWeek: dayOfWeek,
            settings: settings,
          );
        },
        onFinalizeWeekPageSettled: () =>
            _finalizeWeekPageSettled(provider),
        onHandleWeekPageChanged: (page) =>
            _handleWeekPageChanged(page, settings.semesterWeekCount),
        buildWeekPage: (week, width, height) => TimetableWeekPage(
          settings: settings,
          week: week,
          availableHeight: height,
          wallpaperTopLuminance: _luminance.top,
          wallpaperWeekdayLuminance: _luminance.weekday,
          dayViewPageController: _dayViewPageController,
          isDayView: _isDayView,
          visibleDayViewWeek: _visibleDayViewWeek,
          shouldShowDayViewOverlay: _shouldShowDayViewOverlay,
          isSelectedDay: _isSelectedDay,
          hasExamOnDate: provider.hasExamOnDate,
          onShowWeekSelector: _showWeekSelector,
          onDayTapDown: _captureDayViewAnchor,
          onDayTap: (week, dayOfWeek) {
            _toggleDayView(
              week: week,
              dayOfWeek: dayOfWeek,
              settings: settings,
            );
          },
          timeColumnWidth: _resolveTimeColumnWidth(settings),
          buildGrid: (sectionHeight) {
            final visibleDays = _visibleDayNumbers(settings);
            final timeColumnWidth = _resolveTimeColumnWidth(settings);
            final cardInset = _resolveCourseCardInset(settings);
            final dayColumnCallbacks = TimetableDayColumnCallbacks(
              dateForWeekDay: _dateForWeekDay,
              markerSpanAt: _emptySlot.spanAt,
              markerSection: () => _emptySlot.section,
              buildEmptySlotCell:
                  (
                    week,
                    dayOfWeek,
                    startSection,
                    sectionHeight,
                    cardInset,
                    settings, {
                    required span,
                    required occupiedSections,
                  }) => TimetableEmptySlotCell(
                    controller: _emptySlot,
                    week: week,
                    dayOfWeek: dayOfWeek,
                    startSection: startSection,
                    sectionHeight: sectionHeight,
                    cardInset: cardInset,
                    settings: settings,
                    span: span,
                    occupiedSections: occupiedSections,
                    wallpaperLuminance: _luminance.body ?? _luminance.top,
                    onOpenAddCourse: () => unawaited(
                      _openAddCourseFromEmptySlot(
                        week,
                        dayOfWeek,
                        startSection,
                        startSection + span - 1,
                      ),
                    ),
                  ),
              startingAt: _getDisplayItemsStartingAtSection,
              resolveColor: _resolveDisplayCourseColor,
              overline: _resolveCompactOverlineText,
              badge: _resolveCompactBadgeText,
              weather: (item, date) => _weekCardWeatherDisplay(
                l10n: AppLocalizations.of(context),
                weather: context.watch<WeatherProvider?>(),
                settings: settings,
                course: item.course,
                date: date,
                week: week,
                isPartnerCourse: item.isPartnerCourse,
              ),
              clearMarker: _emptySlot.clear,
              showActions: _showCourseActions,
              border: groupedDayColumnBorderRadius,
              wallpaperBodyLuminance: () => _luminance.body,
              wallpaperTopLuminance: () => _luminance.top,
            );
            return TimetableWeekGrid(
              provider: provider,
              settings: settings,
              week: week,
              availableWidth: width,
              sectionHeight: sectionHeight,
              visibleDays: visibleDays,
              timeColumnWidth: timeColumnWidth,
              cardInset: cardInset,
              buildSectionTimeCell: (index, section, settings) =>
                  TimetableSectionTimeCell(
                    sectionNumber: index,
                    section: section,
                    settings: settings,
                    wallpaperLuminance: _luminance.body ?? _luminance.top,
                  ),
              wrapSurfaceHost: _wrapCourseGridSurfaceHost,
              wrapEmptySlotGesture:
                  ({
                    required settings,
                    required week,
                    required sectionHeight,
                    required dayWidth,
                    required visibleDays,
                    required occupiedSections,
                    required child,
                  }) => TimetableEmptySlotGestureArea(
                    controller: _emptySlot,
                    settings: settings,
                    week: week,
                    sectionHeight: sectionHeight,
                    dayWidth: dayWidth,
                    visibleDays: visibleDays,
                    occupiedSections: occupiedSections,
                    overlayVisible: _shouldShowDayViewOverlay,
                    child: child,
                  ),
              coursesForDay: _getCoursesForDay,
              buildDisplayItems: _buildHomeDayDisplayItems,
                    dayColumnCallbacks: dayColumnCallbacks,
            );
          },
          buildBody: (grid) => _buildWeekPageBody(
            settings: settings,
            week: week,
            grid: grid,
          ),
        ),
        buildAnchoredDayViewOverlay: (week) =>
            _buildAnchoredDayViewOverlay(
              provider: provider,
              settings: settings,
              week: week,
            ),
        onWeekdayBarDragStart: _startWeekdayBarDrag,
        onWeekdayBarDragUpdate: _updateWeekdayBarDrag,
        onWeekdayBarDragEnd: _endWeekdayBarDrag,
        onWeekdayBarDragCancel: _cancelWeekdayBarDrag,
      ),
      isPullRunning: _homePull.isRunning,
      pullDragDistance: _homePull.dragDistance,
      pullTriggerDistance: HomePullController.triggerDistance,
      onPullCancel: _homePull.cancelImport,
      backToCurrentWeek: ValueListenableBuilder<int>(
        valueListenable: _visibleWeekListenable,
        builder: (context, visibleWeek, child) {
          if (!_shouldShowFloatingBackToCurrentWeekButton(
            provider,
            provider.settings,
            visibleWeek,
          )) {
            return const SizedBox.shrink();
          }
          return TimetableBackToCurrentWeekButton(
            settings: provider.settings,
            glassDockPillOccupancy: _glassDockPillOccupancy,
            onJumpToCurrentWeek: () {
              _jumpToCurrentWeek(provider);
            },
          );
        },
      ),
      backToToday: ValueListenableBuilder<(int, int)?>(
        valueListenable: _dayHeaderPreview,
        builder: (context, _, _) {
          if (!_shouldShowFloatingBackToTodayButton(provider)) {
            return const SizedBox.shrink();
          }
          return TimetableBackToTodayButton(
            bottomInset: _backToTodayButtonBottomInset(provider.settings),
            onTap: () {
              unawaited(_navigateDayViewToToday(provider));
            },
          );
        },
      ),
      isDayView: _isDayView,
      glassDockForm: glassDockForm,
      isLoading: provider.isLoading,
    );
  }

  Widget _buildDockShell({
    required Widget homeStack,
    required bool useHomePreblur,
    required TimetableSettings settings,
    required double homePreblurSigma,
    required double? courseCardPreblurSigma,
    required bool followsWeekPager,
    required bool glassDockForm,
    required List<Widget> homeChromeBalls,
    required Color chromeDotBorderColor,
  }) {
    final inlineId = _dockInlinePageId;
    return TimetableHomeDockShell(
      homeStack: homeStack,
      useHomePreblur: useHomePreblur,
      settings: settings,
      homePreblurSigma: homePreblurSigma,
      courseCardPreblurSigma: courseCardPreblurSigma,
      isDayView: _isDayView,
      weekPageController: _weekPageController,
      ensureDayViewPageController: _ensureDayViewPageController,
      followsWeekPager: followsWeekPager,
      repaint: _glassDockCardRepaint,
      glassDockForm: glassDockForm,
      inlinePageBuilder: inlineId == null
          ? null
          : inlineDockPageFor(inlineId),
      glassDockScrollInset: _glassDockContentScrollInset(settings),
      dockLayer: glassDockForm
          ? TimetableGlassDockLayer(
              settings: settings,
              isInlinePage: inlineId != null,
              wallpaperBodyLuminance: _luminance.body,
              selectedIndex: _dockSelectedIndex(
                resolveGlassDockActionIds(settings),
              ),
              roundButtonIcon: _roundButtonIcon(settings),
              onTabSelected: (id) => _handleDockTap(id, settings),
              onRoundButtonTap: () => _handleRoundButtonTap(settings),
              pillKey: _glassDockKey,
              roundKey: _glassDockRoundKey,
            )
          : null,
      wrapHome: (content, {dockLayer}) => _wrapHomeWithTopMenu(
        content,
        settings: settings,
        chromeBalls: homeChromeBalls,
        chromeDotBorderColor: chromeDotBorderColor,
        dockLayer: dockLayer,
      ),
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

  /// 顶栏两个图标按钮（「更多」「爱心」）常驻玻璃球上的墨色。
  ///
  /// **跟球走，不跟壁纸反相**：球是玻璃材质（[FHeaderAction.glassBall]），
  /// 浓淡只跟主题明暗走 —— 浅色主题是奶白球、深色主题是暗球；跟壁纸反相算出来
  /// 的白墨到深壁纸下就是「白图标 + 奶白球」，等于没墨。
  ///
  /// 同一份墨色也喂给首页菜单弹窗的 `anchorContent`：打开/关闭菜单时，图标会在
  /// 「按钮的球」与「弹窗形变那颗球」之间交接，两边不同色会看到一次跳色。
  Color get _chromeActionBallInk => context.theme.colors.foreground;

  /// 「更多」按钮的**可见内容**：图标 + 更新红点。
  ///
  /// 常驻玻璃球与弹窗形变起点（`anchorContent`）**必须共用这一份** —— 两者
  /// 内容不一致时，开合交接的那一瞬就会露出来（红点晚一步出现、整颗球跟着
  /// 重绘一次，读起来是"圆按钮闪一下"，且只在有待更新时可见）。
  ///
  /// [dotBorderColor] 是红点那圈"挖坑"描边色（顶栏带色 / 无带时的主题底色），
  /// 两处必须同色，否则交接瞬间红点那圈边会跳一下。
  Widget _buildMoreActionIcon({required Color dotBorderColor}) =>
      HomeMoreActionIcon(
        ink: _chromeActionBallInk,
        dotBorderColor: dotBorderColor,
        showUpdateDot: _update.hasUpdate,
      );

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
    // 与分页共用同一个归一口径（domain/day_view_paging.dart）。
    return normalizeDayOfWeekForVisibleDays(
      _visibleDayNumbers(settings),
      storedDayOfWeek,
    );
  }

  /// 把日视图的选中日收进"当前可见的那些星期"。
  ///
  /// 「隐藏周末」是在设置页改的，而首页 State 常驻：改完回到首页时
  /// `_selectedDayOfWeek` 可能还是 6/7。页号那边即使归一了（见
  /// `_dayViewPageIndexForDay`），状态这份不归一就会继续错位 ——
  /// `_isSelectedDay` 拿 6/7 比可见的 5 格 → 表头一格都不亮；
  /// `_addCourseInitialDayOfWeek` 把周六预填进「添加课程」→ 存下来的课在
  /// 5 列周视图里根本不显示。
  ///
  /// 必须在 build 顶部、表头与日面板读它之前调用。这里**不** setState：
  /// 本帧就是用归一后的值构建的，且只有真的越界才会发生一次。落盘的
  /// `timetableLastViewedDayOfWeek` 不动 —— 恢复时本来就会过一遍同样口径
  /// （`_resolveStoredDayOfWeek`）。
  void _syncDayViewSelectionWithVisibleDays(TimetableSettings settings) {
    final selected = _selectedDayOfWeek;
    if (!_isDayView || selected == null) {
      return;
    }
    final normalized = normalizeDayOfWeekForVisibleDays(
      _visibleDayNumbers(settings),
      selected,
    );
    if (normalized != selected) {
      _selectedDayOfWeek = normalized;
    }
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
    // 日 / 周一律照持久化的浏览状态恢复 —— 缩尺预览也走这一条：宿主（外观
    // 编辑页）顶部的日 / 周分段就是照这份状态初始化的，两边天生一致，进页
    // 那一帧不会出现「预览先按日视图搭起来、再被同步指令关掉」的闪跳。
    //
    // ⚠️ 这里曾经是 `&& !_isPreview`，想表达「预览永远从周视图起步」。那个
    // 条件**从来没生效过**：`_isPreview` 读的是 `_previewScope`，而它要到
    // didChangeDependencies 才拿得到（initState 里恒为 null）。后果是用户在
    // 日视图进编辑页时，预览先渲染一帧日视图再被关掉 —— 卡片在转场期间显示
    // 首页快照（日视图）、转场一结束跳成周视图（用户 2026-09-20 反馈的
    // 「闪现到周视图」）。现在口径改为「预览跟着首页走」，这条守卫随之作废。
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

  /// 让截屏监听跟着设置开关走。
  ///
  /// 平台不支持（Android 14 以下）时 [ScreenCaptureService.start] 自己会
  /// 空转，这里不再重复判断能力：判断只留一处，免得两边口径漂移。
  void _syncScreenshotListener(TimetableSettings settings) {
    // 预览里不接截屏监听：真首页那一份已经接上了，再来一份等于截一次屏
    // 弹两次提示。
    if (_isPreview) {
      return;
    }
    final shouldListen = settings.screenshotSharePromptEnabled;
    if (shouldListen == _screenshotListening) {
      return;
    }
    _screenshotListening = shouldListen;
    if (shouldListen) {
      _screenshotSubscription ??= ScreenCaptureService.onScreenshot.listen(
        (_) => _onScreenshotDetected(),
      );
      unawaited(ScreenCaptureService.start());
      return;
    }
    unawaited(_screenshotSubscription?.cancel());
    _screenshotSubscription = null;
    unawaited(ScreenCaptureService.stop());
  }

  /// 用户截屏 → 浮一条「要分享干净的课表图吗」的胶囊提示。
  ///
  /// 两道门：本页必须还盖在最上面（去设置页等二级页截图，跟「分享课表图」
  /// 的意图对不上），以及不在冷却期内（连拍截屏不叠提示）。
  void _onScreenshotDetected() {
    if (!mounted || !_screenshotListening) {
      return;
    }
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) {
      return;
    }
    final now = DateTime.now();
    final lastPromptAt = _lastScreenshotPromptAt;
    if (lastPromptAt != null &&
        now.difference(lastPromptAt) < _screenshotPromptCooldown) {
      return;
    }
    _lastScreenshotPromptAt = now;

    final provider = context.read<TimetableProvider>();
    final l10n = AppLocalizations.of(context)!;
    showAppToastWithAction(
      context,
      message: l10n.timetableSharePromptMessage,
      actionLabel: l10n.timetableSharePromptAction,
      duration: _screenshotPromptDuration,
      onAction: () => unawaited(_shareTimetableImage(provider)),
    );
  }

  /// 分享「当前这一屏」的干净课表图。
  ///
  /// 只有这里知道用户正看着哪一周、以及是周视图还是日视图 —— 所以菜单里的
  /// `shareTimetable` 由本页拦截，不走目录条目的通用 open。
  Future<void> _shareTimetableImage(TimetableProvider provider) async {
    if (!mounted) {
      return;
    }
    final settings = provider.settings;
    final isDayView =
        settings.timetableHomeViewMode == TimetableHomeViewMode.day &&
        _isDayView;
    await TimetableShareService.exportAndShare(
      context: context,
      provider: provider,
      settings: settings,
      week: isDayView
          ? (_selectedWeekForDayView ?? _visibleWeek)
          : _visibleWeek,
      dayOfWeek: isDayView ? (_selectedDayOfWeek ?? 1) : null,
    );
  }

  void _persistViewState(
    TimetableProvider provider, {
    required TimetableHomeViewMode mode,
    int? dayOfWeek,
  }) {
    // 缩尺预览里的开合**不算用户浏览过**：宿主在编辑页点一下「日课表」，
    // 退回首页不该变成日视图。
    if (_isPreview) {
      return;
    }
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
      provider
          .updateTimetableSettings(
            provider.settings.copyWith(coupleTimetableOverlayEnabled: enabled),
          )
          // 「先改内存、后异步落盘」是这里的既定乐观语义，但落盘失败不能无声：
          // 契约里的 rethrow 没人接就是未处理异步异常，用户只看到开关自己弹回去。
          .catchError((Object _) {
            if (mounted) {
              showAppToast(
                context,
                message: AppLocalizations.of(context)!.saveFailed,
                kind: AppToastKind.error,
              );
            }
            // 同上：Future<String?> 的 onError 要有返回值。
            return null;
          }),
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

  /// [sameSelectionCloses]：目标与当前选择相同时，要不要按「再点一次」收起。
  ///
  /// 首页那颗按钮与底栏 Tab 传 true（点同一档 = 收起日视图）；**外部（缩尺
  /// 预览）驱动传 false** —— 那边下发的是「要日视图」这个目标状态，不是一次
  /// 点按：宿主的分段按钮与预览状态本来就该一致，一致时重复下发不该把日视图
  /// 关掉（真机表现就是「切过去又自己闪回周视图」）。
  Future<void> _toggleDayView({
    required int week,
    required int dayOfWeek,
    required TimetableSettings settings,
    bool animate = true,
    bool sameSelectionCloses = true,
  }) async {
    final normalizedWeek = _clampWeek(week, settings.semesterWeekCount);
    final isSameSelection =
        _isDayView &&
        _selectedWeekForDayView == normalizedWeek &&
        _selectedDayOfWeek == dayOfWeek;
    if (isSameSelection) {
      if (sameSelectionCloses) {
        await _closeDayView(settings, animate: animate);
      }
      return;
    }
    if (_isDayView && _selectedWeekForDayView == normalizedWeek) {
      await _switchDayWithinWeek(settings, normalizedWeek, dayOfWeek);
      return;
    }
    // 走到这说明是从周视图展开（日视图内不会产生空白格标记，手势层
    // 在展开时是关闭的）：清掉周视图里可能还挂着的两步式添加标记，
    // 否则收起日视图后它会原样重现，绕过「点空白处取消」的规则。
    _emptySlot.clear();
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
    // 原来是 `math.max(0, visibleDays.indexOf(dayOfWeek))`：越界星期（开着
    // 「隐藏周末」而选中日还是 6/7）被静默折成 0，也就是周一那一页，但状态里
    // 仍写着 6 —— 于是同一帧内内容显示周一、表头拿 6 去比 1..5 一格都不亮、
    // 「添加课程」还继续预填周六（5 列周视图里看不见那门课）。口径搬到
    // domain/day_view_paging.dart：先归一星期再算页号，并与逆运算严格互逆。
    return dayViewGlobalPage(
      visibleDays: _visibleDayNumbers(settings),
      week: week,
      dayOfWeek: dayOfWeek,
    );
  }

  int _dayViewPageCount(TimetableSettings settings) {
    return _visibleDayNumbers(settings).length * settings.semesterWeekCount;
  }

  TimetableDayViewPageTarget _dayViewTargetForPage(
    TimetableSettings settings,
    int page,
  ) {
    final target = dayViewTargetForGlobalPage(_visibleDayNumbers(settings), page);
    // 可见日表恒为 1..5 或 1..7，null 分支只是防呆回落。
    return TimetableDayViewPageTarget(
      week: target?.$1 ?? 1,
      dayOfWeek: target?.$2 ?? 1,
    );
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
    // positions.length != 1 → subtree-replacement frame: position/page reads
    // would throw until the outgoing PageView detaches at end-of-frame.
    if (controller == null ||
        !controller.hasClients ||
        controller.positions.length != 1) {
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
    final currentPage =
        controllerPageOrNull(controller)?.round() ?? controller.initialPage;
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
    final currentPage =
        controllerPageOrNull(controller)?.round() ?? controller.initialPage;
    if (currentPage == targetPage) {
      return;
    }
    _isSyncingDayViewPage = true;
    try {
      if (animate && controller.positions.length == 1) {
        await controller.animateToPage(
          targetPage,
          duration: _weekSlideDuration,
          curve: Curves.easeOutCubic,
        );
      } else if (controller.positions.length == 1) {
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
    // 「已经在目标那天」按**画面实际所在**判断（滑动中取页中点预览），不能
    // 只看已落定的选择：手势 / 惯性还没停时选择仍停在上一天，用户此刻点
    // 「回今日」会被这条误判成"已经在今天"而整个调用直接返回——读起来就是
    // 点了没反应，随后惯性照旧把画面带到别的天。
    final liveTarget = _visibleDayViewTarget();
    final liveWeek = liveTarget?.$1 ?? _selectedWeekForDayView;
    final liveDay = liveTarget?.$2 ?? _selectedDayOfWeek;
    if (normalizedTargetWeek == liveWeek && targetDayOfWeek == liveDay) {
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
      // 回滑到已选那天：必须把提前预览撤掉。留着的话预览标记会停在被滑
      // 过去的那一天，而 ScrollEnd 收到「选择没变」时不会重建，星期栏
      // 就永久多亮一格（只能靠「回到今天」之类的整屏重建才消失）。
      // 清空与翻页发生在同一次 setPixels 里：位置通知已经在同一帧把这
      // 条栏标脏，本帧的 build 就会读到 null，高亮随之回到已选那天。
      _dayHeaderPreview.value = null;
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
    if (controller == null ||
        !controller.hasClients ||
        controller.positions.length != 1) {
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
    final page = controllerPageOrNull(controller)?.round();
    if (page == null) {
      return;
    }
    final target = _dayViewTargetForPage(settings, page);
    if (kDebugMode) {
      debugPrint(
        '[DayPager] settle: rawPage=${controllerPageOrNull(controller)?.toStringAsFixed(3)} '
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
      if (controller == null ||
          !controller.hasClients ||
          controller.positions.length != 1) {
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
    if (controller == null ||
        !controller.hasClients ||
        controller.positions.length != 1) {
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
  /// 采用**已经采到过**的壁纸亮度带作初值，不让首帧按主题猜墨色极性。
  ///
  /// 两个来源，按精度优先：
  /// 1. [HomeWallpaperLuminanceShare] —— 本进程里任意一份首页（通常是真首页）
  ///    真的采到过的结果，键是采样缓存键本身。缩尺预览那份首页就是靠它取到
  ///    真首页此刻用的同一份值；
  /// 2. [HomeStartupVisualPrimer] —— 冷启动预热的那一份，只按路径索引（拿不到
  ///    这份首页当前的取景），所以排在后面。
  ///
  /// 只在首帧前的空窗期生效一次：本页任何亮度字段已被赋值或常规异步采样已启动
  /// （requestedKey 非空）时直接返回，绝不覆盖精确采样结果。

  /// 采样缓存 key：`路径|视口宽x高|alignX|alignY|scale`（构造器只有一份，见
  /// `homePageBackdropSampleKey`）。
  ///
  /// scale 这一维不能省：亮度带是按「可见比例 ÷ 倍数」采的
  /// （`home_page_background.dart` 的 `homePageWallpaperVisibleSourceRect`，
  /// 上限 `kWallpaperMaxScale = 4`），取景页双指**原地捏合**只动倍数不动对齐，
  /// 键里没它就不会重采 —— 首页顶栏/星期条/卡片区墨色的极性会停在放大前那一条带上，
  /// 且要等下一次拖动位置或冷启动才纠正。

  /// Luminance used by both weekday rendering and the contrast explainer.
  /// When the weekday glass band is enabled, its scrim follows the header/top
  /// sample, so the warning must judge the same effective backdrop as the UI.

  /// One-shot heads-up when a hand-picked weekday-bar ink has too little
  /// contrast against the current wallpaper. The ink keeps its colour and only
  /// gets its lightness pushed for readability ([homePageOverWallpaperInk]);
  /// this explains the change and offers restoring the default (auto B/W).
  void _maybeWarnWeekdayInkContrast(
    TimetableProvider provider,
    TimetableSettings settings,
  ) {
    // Judge custom ink against the band actually behind the weekday bar, not
    // the status/title strip above it.
    final luminance = _luminance.weekdayInk(settings);
    if (luminance == null || _weekdayInkWarningShowing) {
      return;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!hasHomePageBackdrop(settings)) {
      return;
    }
    // 实体档那条带是不透明实心条，星期栏压根不在壁纸上 ⇒ 这条「对比度不够」的
    // 提醒在实体档下是假的（拿壁纸亮度去判一张实底上的字），别弹。液态 / 磨砂
    // 带在模糊管线不在时同样降级为实心条，也不弹。
    if (!homePageWeekdayBarOverWallpaper(
      settings: settings,
      hasBackdrop: true,
      blurPipelineOn: HyperosBlurredHeader.backdropBlurEnabled(context),
    )) {
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
        '$configuredHex|${homePageBackdropKey(settings) ?? ''}|'
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
    try {
      await showTimetableWeekdayInkContrastDialog(
        context,
        wallpaperIsDark: wallpaperIsDark,
        onResetDefault: () => resetTimetableWeekdayInkToDefault(
          context,
          provider: provider,
          isDarkTheme: isDarkTheme,
          defaultHex: defaultHex,
        ),
      );
    } finally {
      _weekdayInkWarningShowing = false;
    }
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
              height: 1,
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

  /// 首页纵向滚动体统一使用的 physics：下拉开着时冻结（见
  /// [TimetableHomePullFreezeScrollPhysics]）。周课表与日课表都用它，"回拉取消"
  /// 的手感两处一致；runtimeType 恒定，不会中途重建 ScrollPosition。
  ScrollPhysics get _homePullVerticalPhysics => TimetableHomePullFreezeScrollPhysics(
    isFrozen: () => _homePull.isFrozen,
    parent: const AlwaysScrollableScrollPhysics(),
  );




  Future<void> _runHomePullQuickImport() async {
    if (_homePull.isRunning || !mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    _homePull.beginImport();
    // 同步读取 provider：前置 mounted 守卫替代吞异常，避免掩盖
    // unmounted-read 类 bug。
    if (mounted) {
      if (context.read<TimetableProvider>().settings.enableHaptics) {
        HapticFeedback.mediumImpact();
      }
    }
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
          _homePull.setCancel(cancel);
        },
      );
    } finally {
      if (mounted) {
        _homePull.endImport();
      }
    }
  }

  List<DayCourseDisplayItem> _buildHomeDayDisplayItems({
    required TimetableProvider provider,
    required TimetableSettings settings,
    required int week,
    required int dayOfWeek,
    required List<Course> myCourses,
    Set<String> currentCourseIds = const <String>{},
  }) {
    final partnerWeek = provider.partnerWeekFor(week);
    return buildHomeDayDisplayItems(
      myCourses: myCourses,
      week: week,
      settings: settings,
      conflictMap: provider.courseConflictMapForWeek(week),
      coupleOverlayActive: _isCoupleOverlayActive(provider),
      partnerWeek: partnerWeek,
      partnerCourses: _getCoursesForDay(
        provider.partnerCourses,
        partnerWeek,
        dayOfWeek,
        settings,
      ),
      partnerWeekOffset: provider.partnerWeekOffset,
      currentCourseIds: currentCourseIds,
    );
  }

  Widget _buildWeekPageBody({
    required TimetableSettings settings,
    required int week,
    required Widget grid,
  }) {
    final scrollRelief = _glassDockContentScrollInset(settings);
    final scrollKey = _weekGridScrollKey(week);
    return TimetableWeekPageBody(
      grid: grid,
      scrollRelief: scrollRelief,
      autoFit: settings.timetableAutoFitSectionHeight,
      scrollKey: scrollKey,
      controller: _previewControllerFor(scrollKey),
      physics: _homePullVerticalPhysics,
      expandAnimation: _dayViewExpandController,
      reportScroll: _reportHomeScroll,
    );
  }

  Widget _buildAnchoredDayViewOverlay({
    required TimetableProvider provider,
    required TimetableSettings settings,
    required int week,
  }) {
    final selectedDayOfWeek = _displayedDayForWeek(week);
    final panel = _buildDayViewPanel(
      provider: provider,
      settings: settings,
      week: week,
      dayOfWeek: selectedDayOfWeek,
    );
    return TimetableAnchoredDayOverlay(
      panel: panel,
      expandAnimation: _dayViewExpandController,
      anchorAlignmentX: _dayViewAnchorAlignmentX,
    );
  }

  Widget _buildDayViewSharedFreeSummary({
    required TimetableProvider provider,
    required TimetableSettings settings,
    required int week,
    required int dayOfWeek,
    required bool isToday,
    required Color ink,
  }) {
    final foruiTheme = context.theme;
    final freeAccent = readableAccentOnCardInk(
      _colorFromHex(
        CoupleTimetableLogic.freeSlotColorHex,
        foruiTheme.colors.primary,
      ),
      ink,
    );
    return TimetableDayViewSharedFreeSummary(
      intervals: _sharedFreeIntervalsForDayView(
        provider: provider,
        settings: settings,
        week: week,
        dayOfWeek: dayOfWeek,
      ),
      isStale: _isPartnerScheduleStale(provider),
      isToday: isToday,
      ink: ink,
      freeAccent: freeAccent,
      expanded: _sharedFreeSegmentsExpanded,
      onExpand: () {
        setState(() {
          _sharedFreeSegmentsExpanded = true;
        });
      },
    );
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


  /// 周网格课卡上那一行天气；不该显示时返回 null（[CourseCard] 据此不加这一行）。
  ///
  /// 三道闸按「成本从低到高」排：先看开关与课程状态（纯内存判断），都过了才去
  /// 查预报摘要。判据与日视图完全一致：**天气是「那一天」的属性**，只有这节课
  /// 这一周真的要上才有意义；对方课程在别的城市，拿本地天气同样不对。
  ///
  /// 摘要为空但「数据会自己来」时返回**预留的空位**（`CourseWeatherDisplay.reserved`）
  /// 而不是 null：这一格确实该有天气，先按真行占好位置，预报到达时卡片不会长高一格
  /// 把整屏内容顶一下。
  CourseWeatherDisplay? _weekCardWeatherDisplay({
    required AppLocalizations? l10n,
    required WeatherProvider? weather,
    required TimetableSettings settings,
    required Course course,
    required DateTime? date,
    required int week,
    required bool isPartnerCourse,
  }) {
    if (l10n == null ||
        weather == null ||
        date == null ||
        isPartnerCourse ||
        !settings.weatherShowOnWeekCard ||
        !course.isActiveInWeek(week)) {
      return null;
    }
    final display = courseWeatherDisplayFor(
      l10n: l10n,
      summary: weather.summaryForCourse(
        date: date,
        startTime: course.startTime,
        endTime: course.endTime,
      ),
      showPhenomenon: settings.weatherShowPhenomenon,
      showTemperature: settings.weatherShowTemperature,
      showProbability: settings.weatherShowProbability,
      // 周网格的天格太窄（7 天模式下扣掉图标只剩约 27 点，默认字号 8 时约合
      // 三个汉字），写全「现象 · 温度 · 概率」必然折行；折行又会把整张卡缩小。
      // 这里只写一项，详见 `WeatherTextDensity.compact`。
      textDensity: WeatherTextDensity.compact,
    );
    if (display != null) {
      return display;
    }
    return weather.isAwaitingData ? const CourseWeatherDisplay.reserved() : null;
  }

  /// 两步式「长按空白格添加课程」的网格级手势层。
  ///
  /// 为什么挂在整块日列 Row 而不是单格：长按拖动的事件只会派发给赢得
  /// 手势竞技场的那个识别器——挂在单格上，手指移出该格后收不到任何
  /// 更新，无法跟手换格。
  ///
  /// 坐标换算直接用事件自带的 [LongPressStartDetails.localPosition] /
  /// [LongPressMoveUpdateDetails.localPosition]：本 GestureDetector 恰好
  /// 包住日列 Row，其局部坐标即（星期×节次）网格坐标。**不要**给这里挂
  /// GlobalKey 来做 globalToLocal——周 pager `allowImplicitScrolling` 会
  /// 同时保活相邻页，同一 GlobalKey 出现在多棵页面子树上必崩
  ///（Duplicate GlobalKey，2026-09-15 自查抓出）。
  ///
  /// 日视图展开时（[_shouldShowDayViewOverlay]）周页仍在 pager 下层存活，
  /// 遮罩未盖严处的长按会穿透到不可见的周网格上，故此时不启用手势层。
  ///
  /// 行为：长按空白格出现虚线加号标记；不松手拖动时标记跟手移动到
  /// 指针所在空白格（滑过课程卡时保持原格不动）；松手后标记留在原处，
  /// 此时拖标记的上/下边缘可把它拉长到多节（见 [_resizeEmptySlotMarker]），
  /// 点虚线框进表单、点其他空白格取消选择。功能关闭时原样返回 child。

  /// 两步式「长按空白格添加课程」的空白格单元（纯视觉，手势在
  /// [_buildEmptySlotGestureArea]）。
  ///
  /// 功能关闭时保持原空占位（无视觉、事件穿透，行为与旧版完全一致）；
  /// 开启且被标记时显示虚线加号态，点虚线框打开预填了周次/星期/节次的
  /// 添加课程表单，拖虚线框上下边缘可把框拉长到多节。课程卡位于 Stack
  /// 更上层，命中优先，不受影响。
  ///
  /// [span] 由调用方按 [_emptySlotMarkerSpanAt] 传入：0 表示本列没有虚线
  /// 框（返回无尺寸空盒子）。[startSection] 为框的首节次。

  /// 虚线框在本列覆盖的节数：没有标记（或标记不在这一天/这一周）返回 0。



  /// 按下虚线框上/下边缘（[isTopEdge]）时锚定本次缩放的基准框。


  /// 拖上/下边缘时按手指位移把虚线框拉长或缩短。
  ///
  /// 位移换算成节数后还要过两道闸：① 不越出第 1 节 ~ 第 [sectionCount] 节，
  /// 且首尾不得交叉（框至少占一节）；② 新纳入的节次不能有课（[occupiedSections]），
  /// 遇到第一节有课的格子就停在它前面——收缩方向永远放开。

  /// 从虚线加号态进入添加课程表单：位置三要素全部预填（节次范围 = 虚线框
  /// 覆盖的范围），落库复用 [TimetableProvider.addCourse] 现有链路。
  Future<void> _openAddCourseFromEmptySlot(
    int week,
    int dayOfWeek,
    int startSection,
    int endSection,
  ) async {
    _emptySlot.clear();
    await Navigator.of(context).push<void>(
      HyperosPageRoute<void>(
        settings: const RouteSettings(name: '/course/add-from-empty-slot'),
        builder: (_) => AddCourseScreen(
          initialWeek: week,
          initialDayOfWeek: dayOfWeek,
          initialStartSection: startSection,
          initialEndSection: endSection,
        ),
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

  List<DayCourseDisplayItem> _getDisplayItemsStartingAtSection(
    List<DayCourseDisplayItem> items,
    int section,
  ) {
    return items.where((item) => item.course.startSection == section).toList();
  }



  DayCourseDisplayLabels _displayLabels() {
    final l10n = AppLocalizations.of(context)!;
    return DayCourseDisplayLabels(
      nonCurrentWeek: l10n.nonCurrentWeekLabel,
      conflict: l10n.conflictLabel,
      coupleTogether: l10n.coupleTimetableLegendTogether,
      couplePartner: l10n.coupleTimetableLegendPartner,
      ongoingCourse: l10n.ongoingCourseBadge,
    );
  }

  String? _resolveDisplayCourseColor(
    DayCourseDisplayItem item, {
    required TimetableSettings settings,
  }) {
    return resolveDisplayCourseColor(
      item,
      settings: settings,
      coupleColorForKind: (kind) =>
          context.read<TimetableProvider>().coupleColorForKind(kind),
    );
  }

  String? _resolveCompactOverlineText(
    DayCourseDisplayItem item,
    bool showConflictBadge,
  ) {
    return resolveCompactOverlineText(
      item,
      labels: _displayLabels(),
      showConflictBadge: showConflictBadge,
    );
  }

  String? _resolveCompactBadgeText(
    DayCourseDisplayItem item,
    bool showConflictBadge,
  ) {
    return resolveCompactBadgeText(
      item,
      labels: _displayLabels(),
      showConflictBadge: showConflictBadge,
    );
  }

  List<Course> _getCoursesForDay(
    List<Course> allCourses,
    int week,
    int dayOfWeek,
    TimetableSettings settings,
  ) {
    return getCoursesForDay(allCourses, week, dayOfWeek, settings);
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

    return WeekCalculator.addDays(
      normalizedStart,
      (week - 1) * 7 + dayOfWeek - 1,
    );
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
    final week =
        (WeekCalculator.daysBetween(normalizedStart, normalizedToday) ~/ 7) + 1;
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
      if (entry != null && entry.visible()) {
        return Icon(entry.icon);
      }
    }
    return const Icon(Icons.add_rounded);
  }

  /// 圆钮点击分发：addCourse/空走添加弹层；内嵌注册页在首页栈内
  /// 切换（坞常驻，再点同钮收回）；其余目录条目普通推入。
  void _handleRoundButtonTap(TimetableSettings settings) {
    final id = settings.glassDockButtonEntryId;
    if (id == 'addCourse' || id.isEmpty) {
      unawaited(_showAddCourseSheet());
      return;
    }
    final catalogEntry = homeMenuEntryById(id);
    if (catalogEntry?.visible() == true && inlineDockPageFor(id) != null) {
      setState(() {
        _dockInlinePageId = (_dockInlinePageId == id) ? null : id;
      });
      // 圆钮保留 toggle 收回（Tab 侧再点当前页已改无动作：圆钮无选中态
      // 指示，按钮式「再点撤销」成立）；开/收/换页都是真实切换，给触觉。
      _maybeSelectionClick(settings);
      return;
    }
    final entry = homeMenuEntryById(id);
    if (entry != null && entry.visible()) {
      _maybeSelectionClick(settings);
      // 同 [_handleDockTap] 的推路由分支：圆钮是另一块液态玻璃、自带光斑，
      // 也必须先收掉再推（否则光斑照样被快照定格）。
      _pushAfterDockGlowSettled(entry.open);
      return;
    }

    // 旧版本可能保存了已经撤掉的入口 id。图标层会回退成加号，
    // 点击也必须走同一个新增课程回退，不能显示一个无响应按钮。
    unawaited(_showAddCourseSheet());
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
  /// 当前页不再翻转收回（与 日/周 同口径，收页走切视图或圆钮再点）。
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
          _pushAfterDockGlowSettled(entry.open);
        }
    }
  }

  /// 底栏某一格**会推新页面**时：先把玻璃药丸上的按压光斑收掉，下一帧再推。
  ///
  /// 2026-09-25 用户口径：「点击底栏的时候会有亮光，但是亮光对应衔接这个缩小
  /// 动画的时候，就会形成闪一下的样子」。那颗亮光就是药丸的按压光斑（液态玻璃
  /// 的 `pressGlow`）：**进光是瞬时的，抬手后靠 140ms 渐隐**，所以抬手那一刻
  /// 它正好最亮。而缩放转场的**第 0 帧**把整屏烤成快照、之后 400ms 全靠回放这
  /// 张图（活树全程停绘，见 `hyperos_zoom_route.dart` 类注释）——「最亮的那一
  /// 帧」被定格进快照，光斑在整个缩小过程里一直是亮的，落定后活首页交还、
  /// 光斑早已收掉 ⇒ 那一下闪。
  ///
  /// 归零必须**早于**快照那一帧，而重绘要等下一帧，所以推页顺延一帧（16.7ms，
  /// 点击手感上察觉不到）。日/周切换与内嵌页换页**不走这里**：那些是首页内部
  /// 状态，光斑的渐隐就是它跟手的手感，要原样保留。
  void _pushAfterDockGlowSettled(Future<void> Function(BuildContext) open) {
    _glassDockKey.currentState?.releasePressGlowImmediately();
    _glassDockRoundKey.currentState?.releasePressGlowImmediately();
    // ⚠️ **必须显式 `scheduleFrame`**（2026-09-25 实测）：`addPostFrameCallback`
    // 自己**不排帧**，而此刻树上已经没有别的东西会标脏（推页被推迟了、光斑归零
    // 只改渲染对象不重建）⇒ 不会有帧被画出 ⇒ 帧末回调永远不跑，推页永远不发生
    // （首版就栽在这，回归用例直接把它照出来）。先排一帧，回调才有执行时机。
    SchedulerBinding.instance.scheduleFrame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(open(context));
    });
  }

  /// 玻璃坞形态下按钮底边与药丸顶边之间的视觉间隙。
  static const double _backToTodayButtonDockGap = 12;

  /// 列表最后一项与按钮顶边之间的视觉间隙。
  static const double _backToTodayButtonGap = 8;

  /// 经典形态（底栏在页面之外）下按钮距页面底边的边距。
  static const double _backToTodayButtonClassicMargin = 24;

  /// 日视图"此刻正看着的那一天"。
  ///
  /// 滑动中用**页中点预览**（[_dayHeaderPreview]，与星期栏高亮同源），静止时
  /// 用已落定的选择。必须这么取：日视图滑动期间整屏不 setState（防 ANR），
  /// 只看落定选择的话，按钮要等 ScrollEnd 之后才可能变化。
  (int, int)? _visibleDayViewTarget() {
    if (!_isDayView) {
      return null;
    }
    final preview = _dayHeaderPreview.value;
    if (preview != null) {
      return preview;
    }
    final week = _selectedWeekForDayView;
    final day = _selectedDayOfWeek;
    if (week == null || day == null) {
      return null;
    }
    return (week, day);
  }

  /// 日视图底部的「回今日」浮钮该不该出现。
  ///
  /// **与周视图的「回本周」浮钮是两套独立体系**：各有自己的可见性条件、
  /// 文案、动作、位置与配色，也不共用设置项——「回本周」受
  /// [TimetableSettings.timetableBackToCurrentWeekButtonStyle] 与浮态透明度
  /// 控制，这颗只跟着"日视图当前看的不是今天"走。两者之间唯一共用的
  /// 事实是底部导航的物理占用（[_glassDockPillOccupancy]）。
  bool _shouldShowFloatingBackToTodayButton(TimetableProvider provider) {
    final target = _visibleDayViewTarget();
    if (target == null) {
      return false;
    }
    final settings = provider.settings;
    // 今天不在本学期内（假期 / 学期末）或今天那个星期被隐藏时不给入口，
    // 免得点一下跳到"上周同一个星期几"。
    if (!_canNavigateDayViewToToday(settings)) {
      return false;
    }
    return !_isSelectedDayToday(
      provider: provider,
      settings: settings,
      week: target.$1,
      dayOfWeek: target.$2,
    );
  }

  /// 玻璃坞药丸之上 / 经典底栏之上，浮钮距屏幕底部的边距。
  double _backToTodayButtonBottomInset(TimetableSettings settings) {
    if (settings.homeNavigationForm != HomeNavigationForm.glassDock) {
      return _backToTodayButtonClassicMargin;
    }
    return math.max(
          _backToTodayButtonClassicMargin,
          _glassDockPillOccupancy + _backToTodayButtonDockGap,
        ) +
        MediaQuery.viewPaddingOf(context).bottom;
  }

  /// 日课表列表为「回今日」浮钮留出的底部滚动余量。
  ///
  /// 与玻璃坞避让（[_glassDockContentScrollInset]）叠加使用：坞避让负责
  /// "别被药丸盖住"，这里补上"别被浮钮盖住"的那一段（浮钮比药丸高出的
  /// 间隙 + 钮高 + 一个视觉间隙）。钮不显示时返回 0——不为一颗看不见的
  /// 按钮白留一条空白，也不改变今天那天的滚动手感。
  double _backToTodayButtonScrollInset(TimetableProvider provider) {
    if (!_shouldShowFloatingBackToTodayButton(provider)) {
      return 0;
    }
    final buttonTop =
        _backToTodayButtonBottomInset(provider.settings) +
        TimetableBackToTodayButton.height;
    return math.max(
      0,
      buttonTop +
          _backToTodayButtonGap -
          _glassDockContentScrollInset(provider.settings),
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
      if (_weekPageController.positions.length != 1) {
        // Subtree-replacement frame: the outgoing PageView position is still
        // attached, so animateTo/jumpTo (positions.single) would throw.
        // Skip the scroll; the replacement tree already shows the target week.
        _pendingSettledWeek = targetWeek;
      } else if (animatePage) {
        await _weekPageController.animateToPage(
          targetWeek - 1,
          duration: (targetWeek - _visibleWeek).abs() == 1
              ? _weekSlideDuration
              : const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
        );
        _pendingSettledWeek = targetWeek;
      } else {
        // Day-view boundary swipes already provide the horizontal motion.
        _weekPageController.jumpToPage(targetWeek - 1);
        _pendingSettledWeek = targetWeek;
      }
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
    _emptySlot.clear();
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

  /// 将 provider 的当前周次同步到周视图 pager。
  ///
  /// 该方法在 build 中调用（外部周次来源可能在一帧内多次到达），副作用
  /// 通过 post-frame 回调收敛且带三重防重入（[_pendingSyncedWeek]、
  /// [_isSyncingWeekPage]、[_hasPendingLocalWeekTransition]）：同一目标页
  /// 不会重复 jump，本地手势进行中绝不抢页。这是「build 中带副作用」的
  /// 受控例外——迁到 didChangeDependencies 需要区分周次来源并改动
  /// 同步时序，当前实现的行为与守卫已在测试中锚定，保持现状。
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

      if (_weekPageController.positions.length != 1) {
        // Subtree-replacement frame: jumpToPage (positions.single) would
        // throw while the outgoing PageView position is still attached.
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
    final page = controllerPageOrNull(_weekPageController);
    if (page != null) {
      return _clampWeek(page.round() + 1, maxWeek);
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

  /// 添加课程表单的初始星期：日视图跟随选中日，其余跟随今天。
  /// 添加弹层（三宫格）与列表态菜单的二级直开共用同一口径。
  int get _addCourseInitialDayOfWeek => _isDayView && _selectedDayOfWeek != null
      ? _selectedDayOfWeek!
      : DateTime.now().weekday;

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
    final initialDayOfWeek = _addCourseInitialDayOfWeek;
    await showHomeHyperosSheet<void>(
      context: context,
      builder: (sheetContext) {
        final itemWidth =
            ((MediaQuery.sizeOf(sheetContext).width - 32 - 24) / 3).clamp(
              96.0,
              120.0,
            );

        return HyperosSheet(
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
    DayCourseDisplayItem? displayItem,
  }) async {
    final provider = context.read<TimetableProvider>();
    final previewItems = buildTimetableCourseActionPreviewItems(
      provider,
      course,
      week,
      displayItem: displayItem,
      coupleOverlayActive: _isCoupleOverlayActive(provider),
    );
    await showCourseActionSheet(
      context,
      previewItems: previewItems,
      week: week,
      onEdit: _editCourse,
      onReschedule: (target) => showTimetableCourseRescheduleSheet(
        context,
        course: target,
        sourceWeek: week,
        weekdayLabels: _weekdayLabels,
      ),
      onDelete: (target) => showTimetableCourseDeleteOptions(
        context,
        course: target,
        week: week,
        weekdayLabels: _weekdayLabels,
      ),
      onSuspend: (target) =>
          showTimetableCourseSuspendSheet(context, course: target, week: week),
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
    final selected = await showTimetableProfileQuickSwitch(
      context,
      profiles: provider.profiles,
      activeProfileId: provider.activeProfileId,
      popupSourceRect: _popupActionSourceRect,
      // 弹层内容在根 Overlay 上，buttonContext 拿不到原路由 —— 先立即摘掉旧
      // 面板，再用仍然挂载的宿主 context 推管理页（细节见 widget 文件）。
      openManagePage: (hostContext, sourceRect) => _openPopupActionPage(
        hostContext,
        pageBuilder: (_) => const TimetableProfilesScreen(),
        sourceRect: sourceRect,
      ),
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

  /// 首页主体 + 顶栏「更多」弹层。
  ///
  /// 布局与采样源次序（采样宿主、玻璃坞、常驻球、菜单四层的位次与理由）见
  /// [TimetableHomeTopMenuShell]；本方法只把 State 里的状态与回调接上去。
  Widget _wrapHomeWithTopMenu(
    Widget content, {
    required TimetableSettings settings,
    required List<Widget> chromeBalls,
    required Color chromeDotBorderColor,
    Widget? dockLayer,
  }) {
    return TimetableHomeTopMenuShell(
      content: content,
      glassController: _homeGlass,
      showMenu: _homeMenuOpen,
      anchor: _homeMenuAnchor,
      // 形变动效要从按钮位置长出来，故传入按钮内容的**副本**（不含 GlobalKey，
      // 避免与真实按钮抢同一个 key）：与常驻球**共用同一份**可见内容
      // （[_buildMoreActionIcon]，含更新红点与同一墨色）。两者不能有差异：
      // 早先这里只给裸图标，关闭菜单交接那一瞬圆钮会闪一下（2026-09-14 真机反馈）。
      anchorContent: _buildMoreActionIcon(dotBorderColor: chromeDotBorderColor),
      entries: resolveHomeGridMenuEntries(settings),
      hasAvailableUpdate: _update.hasUpdate,
      onDismissRequest: _closeHomeMenuNow,
      onSelected: _dispatchTopMenuSelection,
      onDismissFinished: _noteHomeMenuDismissFinished,
      dockLayer: dockLayer,
      chromeBalls: chromeBalls,
    );
  }

  /// 「更多」按钮按下即预热：采样区快照在帧末录制，早一拍才能保证菜单首帧有玻璃。
  ///
  /// 用 [HyperosGlassBackdropController.holdRecording] 而不是 `acquire()`：
  /// 首页菜单两块面板都走注入面（读"玻璃背后那条带"），整层图没人读 —— 而
  /// `acquire()` 会在**整个开合动画期间每帧录一张全屏**（按 dpr ≈ 6.7MB/帧）。
  void _prewarmHomeGlass() {
    if (_homeGlassHeld) return;
    _homeGlassHeld = true;
    _homeGlass.holdRecording();
  }

  /// 抬手未展开 / 菜单关闭后归还录帧请求（配对 [holdRecording]，避免首页一直录帧）。
  void _releaseHomeGlass() {
    if (!_homeGlassHeld) return;
    _homeGlassHeld = false;
    _homeGlass.releaseRecording();
  }

  /// 「更多」按钮抬手后**帧末**再判要不要归还。
  ///
  /// 不能在抬手当场归还：`Listener.onPointerUp` 早于按钮的 `onPress`，而
  /// `_homeMenuOpen` 是在 `onPress` 里才置 true 的 —— 当场归还就会
  /// arm → release → arm 走一遍，中间那次让首页正文白重录一次、还多排一次
  /// 空转录帧（2026-10-19 日志里 `holds=1 → 0 → 1` 就是这个）。推到帧末，
  /// 这一下 tap 真开了菜单就保持不还。
  ///
  /// 显式 `scheduleFrame()`：指针事件本身不保证排帧，而帧末回调只在有帧时跑，
  /// 漏排一次就等于「这次抬手没归还」，首页会一直录帧。
  void _releaseHomeGlassAfterTap() {
    if (_homeMenuOpen) return;
    WidgetsBinding.instance.scheduleFrame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_homeMenuOpen) _releaseHomeGlass();
    });
  }

  /// 正在等「菜单退场动画走完」的那个信号（见 [_closeHomeMenuAndWait]）。
  ///
  /// 由弹层的 `onDismissFinished` 收口（上游 `GlassPopupPresenter._finish`：面板已
  /// 从覆盖层摘掉、锚点那颗球的图标也交还了）。它比 [kHomeMenuCollapseBudget] 晚
  /// （弹簧要收敛到 0.0015，实测 ≈670ms，而视觉上 ≈240ms 就收完了），所以只当
  /// **提前放行**用（关动效那条路是瞬时的），常态是预算到期继续。
  Completer<void>? _homeMenuDismissed;

  /// 弹层退场结束：唤醒 [_closeHomeMenuAndWait] 里的等待。
  void _noteHomeMenuDismissFinished() {
    final completer = _homeMenuDismissed;
    if (completer == null || completer.isCompleted) {
      return;
    }
    _homeMenuDismissed = null;
    completer.complete();
  }

  /// 立刻收起首页菜单（遮罩点击 / 返回键 / 菜单项执行前的统一收口）。
  void _closeHomeMenuNow() {
    if (_homeMenuOpen) {
      setState(() => _homeMenuOpen = false);
    }
    _releaseHomeGlass();
  }

  Future<void> _showTopActionsSheet() async {
    final provider = context.read<TimetableProvider>();
    final settings = provider.settings;

    // 菜单形态由设置分流：「八宫格」是 v2.0.5.5 已发布版本的底部弹层；
    // 「列表」自 2026-09-13 起改用上游 flutter_miuix OS4 玻璃弹层
    // （HomeTopMenuPopup：形变动效 + 不再逐帧重采整页组捕获）。两种形态
    // 共享同一份自定义排列（homeGridMenuActions），统一以入口 id 回传，
    // 再经 _dispatchTopMenuSelection 分发到全应用任意二级页面/功能。
    if (settings.homeMenuStyle != HomeMenuStyle.grid) {
      _prewarmHomeGlass();
      setState(() => _homeMenuOpen = true);
      return;
    }
    // 八宫格是底部弹层，不吃首页采样源：抬手即归还预热。
    _releaseHomeGlass();

    final selectedId = await showHomeTopGridMenuSheet(
      context,
      hasAvailableUpdate: _update.hasUpdate,
      entries: resolveHomeGridMenuEntries(settings),
      themeSeedHex: settings.themeSeedColor,
    );
    if (selectedId == null) {
      return;
    }
    await _dispatchTopMenuSelection(selectedId);
  }

  /// 顶栏菜单选中项分发：八宫格与列表（OS4 玻璃弹层）两种形态共用入口。
  ///
  /// **时序：菜单先收完，再执行选中项。** 用户 2026-10-19 口径：「先进行收缩，
  /// 收缩完了才弹出新的页面，比如进入设置页面」。以前只有缩放转场那条这么干，
  /// 通用条目走的是「先推页、等新页盖满再收」（那条为的是避开 2026-09-15 真机
  /// 反馈的「菜单先收、页面后盖，中间几帧首页顶栏两颗球闪一下」）。
  ///
  /// 菜单没开着（八宫格底部弹层形态）时不等，行为与从前一致。
  Future<void> _dispatchTopMenuSelection(String selectedId) async {
    if (!mounted) {
      return;
    }
    final provider = context.read<TimetableProvider>();

    // Let the sheet route finish closing before pushing the next page.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) {
      return;
    }

    await _closeHomeMenuAndWait();
    if (!mounted) {
      return;
    }

    await _runTopMenuSelection(selectedId, provider);
  }

  /// 收起首页菜单，并等它**视觉上收完**（缩回锚点那颗球）才返回。
  ///
  /// 用户 2026-10-19 口径：点菜单项之后先收缩、收缩完才弹新页面。所有条目
  /// （推路由 / 弹层 / 分享）统一走这里，[_dispatchTopMenuSelection] 只等它返回。
  ///
  /// 菜单没开着（八宫格底部弹层形态）时立即返回：底部弹层那格是 `Navigator.pop`
  /// 直接摘路由（没有退场动画残留），`_homeMenuOpen` 一直是 false。
  ///
  /// 等待口径 = **菜单视觉收完**，不是弹层动画的数学收敛：
  /// * 面板退场是弹簧（上游 `transformBounds(false)` = folmeSpring 阻尼 .8 /
  ///   response .28s），逐帧实测 200×16ms 测试帧里面板宽从 65px 缩到 12px 用
  ///   15 帧（≈240ms），此后只剩亚像素抖动 —— 12px 的点趴在锚点那颗球上，肉眼
  ///   与「没了」无异。
  /// * 而上游那条 [HomeTopMenuPopup.onDismissFinished] 挂在 `animateGlassTo` 的
  ///   收敛容差（0.0015）上，实测要 **≈670ms** 才回调。照它等 = 凭空加半秒空档。
  /// 所以取 [kHomeMenuCollapseBudget] 作上限，弹层若**先**报退场结束（关动效那条
  ///   路是瞬时的）就立刻走。
  Future<void> _closeHomeMenuAndWait() async {
    // completer 必须**先**挂上再收起：`_closeHomeMenuNow` 只翻 `show`，退场是
    // 弹层在后续帧里跑的，不会同步回调，但先挂可杜绝任何"信号先到、等待后建"。
    final waiting = _homeMenuOpen
        ? (_homeMenuDismissed = Completer<void>())
        : null;
    _closeHomeMenuNow();
    if (waiting == null) {
      return;
    }
    await Future.any<void>([
      waiting.future,
      Future<void>.delayed(kHomeMenuCollapseBudget),
    ]);
    if (identical(_homeMenuDismissed, waiting)) {
      _homeMenuDismissed = null;
    }
    if (!mounted) {
      return;
    }
    // 边缘时序：这 280ms 里用户又点了球、把菜单重开了（收起期第一帧锚点就收回
    // 输入，见上游 fork 的口径）。此时不再等第二遍 —— 直接收掉就继续，绝不能
    // 带着一张张开的菜单去推页面。
    if (_homeMenuOpen) {
      _closeHomeMenuNow();
    }
    // 锚点那颗球的**图标**上游要等退场动画彻底结束才交还
    // （`MiuixGlassAnchor.contentHidden` ← `GlassPopupPresenter._finish`，≈670ms）。
    // 那时转场早就走完，首页（或首页快照）上的「更多」球会是个**没有图标的空球**。
    // 此刻交还正是上游想做的那次视觉交接 —— 弹层自己的形变副本 80ms 就淡完了、
    // 面板也缩成球了 —— 只是不去等那条数学收敛。写已释放的 anchor 会被它自己的
    // `_disposed` 挡掉，这里也先判 mounted。
    if (_homeMenuAnchor.contentHidden) {
      _homeMenuAnchor.contentHidden = false;
    }
  }

  /// 菜单项的实际分发（由 [_dispatchTopMenuSelection] 在**菜单收完之后**调用）。
  ///
  /// id → 动作的映射在 [dispatchTimetableTopMenuSelection]；这里只把首页专属的
  /// 六条启动路径接上（它们要读可见周、日视图选中日期、provider 与分享快照）。
  Future<void> _runTopMenuSelection(
    String selectedId,
    TimetableProvider provider,
  ) async {
    await dispatchTimetableTopMenuSelection(
      context,
      selectedId,
      TimetableTopMenuLaunchers(
        // 列表态菜单走不到这里（父行是展开开关，只回传子项 id）；
        // 八宫格形态与未知 id 兜底仍开三宫格添加弹层。
        openAddCoursePicker: () => _navigateToAddCourse(context),
        openCourseForm: () => Navigator.of(context).push<void>(
          HyperosPageRoute<void>(
            builder: (_) => AddCourseScreen(
              initialWeek: _visibleWeek,
              initialDayOfWeek: _addCourseInitialDayOfWeek,
            ),
          ),
        ),
        openScheduleForm: () => Navigator.of(context).push<void>(
          HyperosPageRoute<void>(
            builder: (_) => AddScheduleItemScreen(
              initialDate: _resolveAddScheduleInitialDate(provider),
            ),
          ),
        ),
        openExamForm: () => Navigator.of(context).push<void>(
          HyperosPageRoute<void>(builder: (_) => const AddExamScreen()),
        ),
        openUpdate: _openTopMenuUpdatePage,
        // 分享要带上「当前可见周」与「当前是周/日视图」，只有本页知道，
        // 所以在这里拦截，不走目录条目的通用 open。
        shareTimetable: () => _shareTimetableImage(provider),
      ),
    );
  }

  Future<void> _runUpdateCheck({required bool includePrerelease}) async {
    final result = await _update.check(
      settings: context.read<TimetableProvider>().settings,
      includePrerelease: includePrerelease,
    );
    if (!mounted || result == null) {
      return;
    }
    _scheduleHomeUpdatePrompt(result);
  }

}

Rect _popupActionSourceRect(BuildContext buttonContext) {
  final renderBox = buttonContext.findRenderObject() as RenderBox?;
  final buttonOffset = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
  final buttonSize = renderBox?.size ?? const Size(80, 80);
  return buttonOffset & buttonSize;
}

void _openPopupActionPage(
  BuildContext context, {
  required WidgetBuilder pageBuilder,
  Rect? sourceRect,
  Route<dynamic>? sheetRoute,
}) {
  final resolvedSourceRect = sourceRect ?? _popupActionSourceRect(context);
  final navigator = Navigator.of(context);

  navigator.push(
    TimetableOpenOnlyContainerPageRoute<void>(
      sourceRect: resolvedSourceRect,
      builder: pageBuilder,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (sheetRoute != null && sheetRoute.isActive) {
      navigator.removeRoute(sheetRoute);
    }
  });
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
        return TimetableHomeActionButtonBody(
          icon: icon,
          title: title,
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
