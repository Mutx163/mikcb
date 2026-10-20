import 'dart:async';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart'
    show GestureBinding, VelocityTracker, kMinFlingVelocity;
import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/course.dart';
import '../models/schedule_item.dart';
import '../models/timetable_settings.dart';
import '../domain/clock_order.dart';
import '../domain/couple_timetable_logic.dart';
import '../domain/timetable_layout.dart';
import '../domain/day_course_display_logic.dart';
import '../domain/day_view_paging.dart';
import '../domain/week_calculator.dart';
import '../providers/timetable_provider.dart';
import '../services/screen_capture_service.dart';
import '../services/timetable_share_service.dart';
import '../services/widget_launch_router.dart';
import '../widgets/class_reminder_sheet.dart';
import '../utils/app_toast.dart';
import '../utils/hex_color.dart';
import '../controllers/day_view_transition_controller.dart';
import '../controllers/empty_slot_marker_controller.dart';
import '../controllers/timetable_update_download_controller.dart';
import '../controllers/home_pull_controller.dart';
import '../controllers/home_menu_controller.dart';
import '../controllers/update_check_controller.dart';
import '../controllers/wallpaper_luminance_controller.dart';
import '../controllers/week_pager_controller.dart';
import '../utils/home_page_background.dart';
import '../utils/home_startup_visual_primer.dart';
import '../utils/home_wallpaper_luminance_share.dart';
import '../ui/hyperos/liquid/liquid_glass_surface.dart'
    show LiquidGlassSurface, LiquidGlassSurfaceState;
import '../widgets/course_grid_surface_host.dart';
import '../widgets/home_menu_catalog.dart';
import '../widgets/timetable_home_preview_scope.dart';
import '../widgets/timetable/timetable_back_to_today_button.dart';
import '../widgets/timetable/timetable_course_action_flow.dart';
import '../widgets/timetable/timetable_home_page_assembly.dart';
import '../widgets/timetable/timetable_dock_actions.dart';
import '../widgets/timetable/weekday_ink_contrast_guard.dart';
import '../widgets/timetable/timetable_day_view_shared_free_summary.dart';
import '../widgets/timetable/timetable_anchored_day_overlay.dart';
import '../widgets/timetable/timetable_day_agenda_models.dart';
import '../widgets/timetable/day_view/day_view_course_agenda_card.dart';
import '../widgets/timetable/day_view/day_view_empty_state.dart';
import '../widgets/timetable/day_view/day_view_exam_agenda_card.dart';
import '../widgets/timetable/day_view/day_view_ink_style.dart';
import '../widgets/timetable/day_view/day_view_schedule_agenda_card.dart';
import '../widgets/timetable/day_view/day_view_summary_card.dart';
import '../widgets/timetable/about_update_navigation.dart';
import '../widgets/timetable/timetable_add_course_sheet.dart';
import '../widgets/timetable/timetable_home_action_page_button.dart';
import '../widgets/timetable/timetable_day_pager_physics.dart';
import '../widgets/timetable/timetable_home_scroll.dart';
import '../widgets/timetable/timetable_glass_dock.dart';
import '../widgets/timetable/timetable_top_menu_shell.dart';
import 'add_course_screen.dart';
import 'add_exam_screen.dart';
import 'add_schedule_item_screen.dart';
import 'add_task_screen.dart';
import 'home_menu_route_registry.dart';
import 'import/home_pull_quick_import.dart';
import 'timetable_profiles_screen.dart';

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
    with WidgetsBindingObserver, TickerProviderStateMixin
    implements DayViewTransitionHost, WeekPagerHost, HomeMenuHost {
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

  late final AnimationController _dayViewExpandController;

  /// 日视图锚点展开/收起与设置页拖动转场期间，卡片玻璃 fill 需要每帧
  /// 重采样（壁纸屏幕固定、卡片移动），否则纹理停留在旧位置：
  /// 卡片左半是旧壁纸、右半透明（撕裂）。
  late final Listenable _glassDockCardRepaint;

  /// 日视图转场状态机（开合 / 翻页 / pager 生命周期 / 星期栏刮擦）在
  /// `lib/controllers/day_view_transition_controller.dart`；本 State 只通过
  /// [DayViewTransitionHost] 端口提供字段读写与回调。
  late final DayViewTransitionController _dayViewTransition;

  /// 周 pager / 可见周 / 周次提交队列在
  /// `lib/controllers/week_pager_controller.dart`；本 State 只通过
  /// [WeekPagerHost] 端口提供字段读写与回调。
  late final WeekPagerController _weekPager;

  int get _visibleWeek => _weekPager.visibleWeek;

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
  /// 圆钮（[HomeMenuController.handleRoundButtonTap]）同样会 `entry.open(context)`
  /// 推路由。只挂药丸的话，用户把圆钮也指到「外观编辑」时那条路原样漏
  /// （2026-09-26 自审补上）。非液态材质档压根没有光斑，`currentState` 为 null，
  /// `?.` 天然跳过。
  final GlobalKey<LiquidGlassSurfaceState> _glassDockKey =
      GlobalKey<LiquidGlassSurfaceState>();
  final GlobalKey<LiquidGlassSurfaceState> _glassDockRoundKey =
      GlobalKey<LiquidGlassSurfaceState>();

  /// 顶栏「更多」「爱心」常驻玻璃球的位置锚（[FHeaderActionBall] 跟随真实
  /// 按钮的透明点击区）。
  final LayerLink _moreBallLink = LayerLink();
  final LayerLink _heartBallLink = LayerLink();

  /// 顶栏菜单（列表态玻璃弹层 + 八宫格分发 + 圆钮入口）在
  /// `lib/controllers/home_menu_controller.dart`；本 State 只通过
  /// [HomeMenuHost] 端口提供更新红点、锚点内容与选中项执行。
  late final HomeMenuController _homeMenu;

  late final TimetableUpdateDownloadController _updateDownload;
  late final UpdateCheckController _update;

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
        takeRescueVelocity: _dayViewTransition.takeRescueVelocity,
        parent: const ClampingScrollPhysics(),
      );

  int? _selectedDayOfWeek;
  int? _selectedWeekForDayView;
  double _dayViewAnchorFraction = 0.5;
  bool _isDaySwipeAnimating = false;

  // ── DayViewTransitionHost / WeekPagerHost：控制器的宿主端口 ────────────
  //
  // 只做字段读写 / 回调转发，不含业务判断；行为口径全部在两个控制器库里。

  @override
  bool get isMounted => mounted;

  @override
  bool get isDayView => _isDayView;

  @override
  int? get selectedWeekForDayView => _selectedWeekForDayView;

  @override
  set selectedWeekForDayView(int? value) => _selectedWeekForDayView = value;

  @override
  int? get selectedDayOfWeek => _selectedDayOfWeek;

  @override
  set selectedDayOfWeek(int? value) => _selectedDayOfWeek = value;

  @override
  int get visibleWeek => _visibleWeek;

  @override
  bool get isSyncingWeekPage => _weekPager.isSyncingWeekPage;

  @override
  bool get isDaySwipeAnimating => _isDaySwipeAnimating;

  @override
  set isDaySwipeAnimating(bool value) => _isDaySwipeAnimating = value;

  @override
  bool get daySwipeHapticFired => _daySwipeHapticFired;

  @override
  set daySwipeHapticFired(bool value) => _daySwipeHapticFired = value;

  @override
  double get dayPagerRescueVelocityX => _dayPagerRescueVelocityX;

  @override
  set dayPagerRescueVelocityX(double value) => _dayPagerRescueVelocityX = value;

  @override
  DateTime? get dayPagerRescueArmedAt => _dayPagerRescueArmedAt;

  @override
  set dayPagerRescueArmedAt(DateTime? value) => _dayPagerRescueArmedAt = value;

  @override
  ValueNotifier<(int, int)?> get dayHeaderPreview => _dayHeaderPreview;

  @override
  double get dayViewExpandValue => _dayViewExpandController.value;

  @override
  set dayViewExpandValue(double value) =>
      _dayViewExpandController.value = value;

  @override
  Duration get pageSlideDuration => WeekPagerController.weekSlideDuration;

  @override
  set sharedFreeSegmentsExpanded(bool value) =>
      _sharedFreeSegmentsExpanded = value;

  @override
  void selectionClick(TimetableSettings settings) =>
      _maybeSelectionClick(settings);

  @override
  void clearEmptySlotMarker() => _emptySlot.clear();

  @override
  void clearDayViewTransitionSource() =>
      setState(_dayViewTransition.clearTransitionSource);

  @override
  Future<void> forwardDayViewExpand() => _dayViewExpandController.forward();

  @override
  Future<void> reverseDayViewExpand() => _dayViewExpandController.reverse();

  @override
  void persistDayView({required int dayOfWeek}) => _persistViewState(
    context.read<TimetableProvider>(),
    mode: TimetableHomeViewMode.day,
    dayOfWeek: dayOfWeek,
  );

  @override
  void persistWeekView() => _persistViewState(
    context.read<TimetableProvider>(),
    mode: TimetableHomeViewMode.week,
  );

  @override
  Future<void> jumpToWeek(
    TimetableProvider provider,
    int week, {
    required bool animatePage,
  }) => _weekPager.jumpToWeek(provider, week, animatePage: animatePage);

  @override
  void setStateMutations(VoidCallback mutate) => setState(mutate);

  @override
  void rebuild() => setState(() {});

  /// 底栏点选的内嵌页 id（非 null 时内容区切换为该页，玻璃坞常驻）。
  String? _dockInlinePageId;

  bool _coupleOverlayEnabled = false;
  bool _sharedFreeSegmentsExpanded = false;

  static const Duration _partnerScheduleStaleAfter = Duration(days: 7);

  /// Finger travel (after resistance) required to fire quick import.

  /// Last "custom weekday ink is unreadable" combination already warned about
  /// this session; the persisted twin lives in SharedPreferences.

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
          _dayViewTransition.toggle(
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

  late final WeekdayInkContrastGuard _weekdayInkGuard;

  @override
  void initState() {
    super.initState();
    // 页面构造住 screens 层，widgets 目录只认 id（消除反向依赖）；须早于菜单渲染。
    registerHomeMenuRoutes(kHomeMenuRouteRegistry);
    _dayViewTransition = DayViewTransitionController(host: this);
    _homeMenu = HomeMenuController(host: this);
    _weekdayInkGuard = WeekdayInkContrastGuard();
    _emptySlot = EmptySlotMarkerController()
      ..addListener(_handleEmptySlotChanged);
    _updateDownload = TimetableUpdateDownloadController();
    _update = UpdateCheckController(service: _updateDownload.updateService)
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
    _weekPager = WeekPagerController(
      host: this,
      initialWeek: initialWeek,
      initialPage:
          clampWeek(initialWeek, provider.settings.semesterWeekCount) - 1,
    );
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
    _updateDownload.dispose();
    _update.removeListener(_handleUpdateChanged);
    _update.dispose();
    _homePull.removeListener(_handleHomePullChanged);
    _homePull.dispose();
    _weekPager.dispose();
    _dayViewExpandController.dispose();
    _dayAgendaProgressTimer?.cancel();
    _dayAgendaProgressTick.dispose();
    _dayHeaderPreview.dispose();
    _dayViewTransition.dispose();
    for (final controller in _previewScrollControllers.values) {
      controller.dispose();
    }
    _previewScrollControllers.clear();
    // 页面走了就把截屏监听交回去：监听不该比「谁在听」活得久。
    unawaited(_screenshotSubscription?.cancel());
    _screenshotSubscription = null;
    _screenshotListening = false;
    unawaited(ScreenCaptureService.stop());
    _homeMenu.dispose();
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
        _weekPager.syncWeekPageWithProvider(
          provider.currentWeek,
          provider.settings,
        );
        _syncScreenshotListener(provider.settings);
        final settings = provider.settings;
        return buildTimetableHomePage(
          TimetableHomePageInput(
            context: context,
            provider: provider,
            settings: settings,
            l10n: l10n,
            isMounted: () => mounted,
            weekPager: _weekPager,
            dayViewTransition: _dayViewTransition,
            homePull: _homePull,
            emptySlot: _emptySlot,
            luminance: _luminance,
            weekdayInkGuard: _weekdayInkGuard,
            homeMenu: _homeMenu,
            dayViewExpandAnimation: _dayViewExpandController,
            homePullVerticalPhysics: _homePullVerticalPhysics,
            previewControllerFor: _previewControllerFor,
            reportHomeScroll: _reportHomeScroll,
            timetableSurfaceKey: _timetableSurfaceKey,
            topMenuButtonKey: _topMenuButtonKey,
            moreBallLink: _moreBallLink,
            heartBallLink: _heartBallLink,
            glassDockKey: _glassDockKey,
            glassDockRoundKey: _glassDockRoundKey,
            glassDockCardRepaint: _glassDockCardRepaint,
            dockInlinePageId: _dockInlinePageId,
            isDayView: _isDayView,
            hasSelectedDay: _selectedDayOfWeek != null,
            coupleOverlayActive: _isCoupleOverlayActive(provider),
            dayHeaderPreview: _dayHeaderPreview,
            glassDockPillOccupancy: _glassDockPillOccupancy,
            glassDockContentScrollInset: _glassDockContentScrollInset,
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
            openProfileManagePage: (hostContext, sourceRect) =>
                openTimetablePopupActionPage(
                  hostContext,
                  pageBuilder: (_) => const TimetableProfilesScreen(),
                  sourceRect: sourceRect,
                ),
            isSelectedDay: _isSelectedDay,
            onDayTapDown: _captureDayViewAnchor,
            onOpenAddCourse: (week, dayOfWeek, startSection, endSection) =>
                unawaited(
                  _openAddCourseFromEmptySlot(
                    week,
                    dayOfWeek,
                    startSection,
                    endSection,
                  ),
                ),
            buildAnchoredDayViewOverlay: (week) => _buildAnchoredDayViewOverlay(
              provider: provider,
              settings: settings,
              week: week,
            ),
            showCourseActions: _showCourseActions,
            coursesForDay: _getCoursesForDay,
            buildDisplayItems: _buildHomeDayDisplayItems,
            dateForWeekDay: _dateForWeekDay,
            startingAt: _getDisplayItemsStartingAtSection,
            resolveColor: _resolveDisplayCourseColor,
            onDockTap: _handleDockTap,
            buildMoreActionIcon: buildMoreActionIcon,
            shouldShowBackToCurrentWeek:
                _shouldShowFloatingBackToCurrentWeekButton,
            onJumpToCurrentWeek: () => _jumpToCurrentWeek(provider),
            shouldShowBackToToday: _shouldShowFloatingBackToTodayButton,
            backToTodayBottomInset: _backToTodayButtonBottomInset,
            onNavigateToday: () => unawaited(_navigateDayViewToToday(provider)),
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

  /// 「更多」按钮的**可见内容**：图标 + 更新红点。
  ///
  /// 常驻玻璃球与弹窗形变起点（`anchorContent`）**必须共用这一份** —— 两者
  /// 内容不一致时，开合交接的那一瞬就会露出来（红点晚一步出现、整颗球跟着
  /// 重绘一次，读起来是"圆按钮闪一下"，且只在有待更新时可见）。
  ///
  /// [dotBorderColor] 是红点那圈"挖坑"描边色（顶栏带色 / 无带时的主题底色），
  /// 两处必须同色，否则交接瞬间红点那圈边会跳一下。
  @override
  Widget buildMoreActionIcon({required Color dotBorderColor}) =>
      HomeMoreActionIcon(
        ink: context.theme.colors.foreground,
        dotBorderColor: dotBorderColor,
        showUpdateDot: _update.hasUpdate,
      );

  int _resolveStoredDayOfWeek(TimetableSettings settings, int storedDayOfWeek) {
    // 与分页共用同一个归一口径（domain/day_view_paging.dart）。
    return normalizeDayOfWeekForVisibleDays(
      visibleDayNumbers(settings),
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
      visibleDayNumbers(settings),
      selected,
    );
    if (normalized != selected) {
      _selectedDayOfWeek = normalized;
    }
  }

  void _restoreViewStateFromProvider(TimetableProvider provider) {
    final settings = provider.settings;
    _weekPager.restore(provider.currentWeek, settings.semesterWeekCount);
    final restoredDayOfWeek = _resolveStoredDayOfWeek(
      settings,
      settings.timetableLastViewedDayOfWeek,
    );
    _lastSyncedProvider = provider;
    _lastSyncedProfileId = provider.activeProfileId;
    // 转场侧的一次性状态与旧 pager 控制器交给控制器统一按替换路径复位。
    _dayViewTransition.resetForRestore();
    _isDaySwipeAnimating = false;
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

  // ── 日视图转场薄接线 ────────────────────────────────────────────────────
  //
  // 真正的状态机（开合 / 翻页 / ScrollEnd 提交 / pager 生命周期 / 星期栏
  // 刮擦）在 `lib/controllers/day_view_transition_controller.dart`。下面这几个
  // 转发保留原方法名与签名，供同库分片 `timetable_day_view_part.dart` 使用：
  // part 只作零行为搬迁，不因这次拆分改一行。

  Future<void> _closeDayView(
    TimetableSettings settings, {
    bool animate = true,
  }) => _dayViewTransition.close(settings, animate: animate);

  PageController _ensureDayViewPageController(TimetableSettings settings) =>
      _dayViewTransition.ensurePageController(settings);

  void _syncDayViewPageWithSelection(TimetableSettings settings) =>
      _dayViewTransition.syncPageWithSelection(settings);

  int _dayViewPageCount(TimetableSettings settings) =>
      _dayViewTransition.pageCount(settings);

  TimetableDayViewPageTarget _dayViewTargetForPage(
    TimetableSettings settings,
    int page,
  ) {
    final target = _dayViewTransition.targetForPage(settings, page);
    return TimetableDayViewPageTarget(
      week: target.week,
      dayOfWeek: target.dayOfWeek,
    );
  }

  Future<void> _handleDayViewPageChanged(
    TimetableProvider provider,
    TimetableSettings settings,
    int page,
  ) => _dayViewTransition.handlePageChanged(provider, settings, page);

  void _settleDayViewPage(
    TimetableProvider provider,
    TimetableSettings settings,
  ) => _dayViewTransition.settlePage(provider, settings);

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

  Widget _buildAnchoredDayViewOverlay({
    required TimetableProvider provider,
    required TimetableSettings settings,
    required int week,
  }) {
    final selectedDayOfWeek = _dayViewTransition.displayedDayForWeek(week);
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

  List<DayCourseDisplayItem> _getDisplayItemsStartingAtSection(
    List<DayCourseDisplayItem> items,
    int section,
  ) {
    return items.where((item) => item.course.startSection == section).toList();
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

  List<Course> _getCoursesForDay(
    List<Course> allCourses,
    int week,
    int dayOfWeek,
    TimetableSettings settings,
  ) {
    return getCoursesForDay(allCourses, week, dayOfWeek, settings);
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
    final visibleDays = visibleDayNumbers(settings);
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
    await _dayViewTransition.animateToWeek(
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

  /// 底栏点击分发：'day'/'week' 闪现直切（animate:false，不播锚点展开/
  /// 收起转场，对齐「点底栏直接就位」的手感，日期栏路径不受影响）并收回
  /// 内嵌页；页面条目走内嵌宿主（坞常驻），未登记的流程页才推入新路由。
  ///
  /// 触觉口径（恢复 3e41ac20）：真实切换（切视图/开页/换页/收页/推路由）
  /// 给一次触觉，重复点击当前 Tab 静音——日/周靠既有守卫；内嵌页再点
  /// 当前页不再翻转收回（与 日/周 同口径，收页走切视图或圆钮再点）。
  void _handleDockTap(String id, TimetableSettings settings) {
    handleTimetableDockTap(
      id,
      settings,
      TimetableDockActionHost(
        isDayView: _isDayView,
        visibleWeek: _visibleWeek,
        dockInlinePageId: _dockInlinePageId,
        setInlinePageId: (id) => setState(() => _dockInlinePageId = id),
        onSelectionClick: _maybeSelectionClick,
        toggleDayView: _dayViewTransition.toggle,
        closeDayView: _closeDayView,
        resolveStoredDayOfWeek: _resolveStoredDayOfWeek,
        persistWeekView: () => _persistViewState(
          context.read<TimetableProvider>(),
          mode: TimetableHomeViewMode.week,
        ),
        inlineDockPageFor: inlineDockPageFor,
        homeMenuEntryById: homeMenuEntryById,
        pushAfterGlow: _pushAfterDockGlowSettled,
      ),
    );
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
    pushAfterTimetableDockGlowSettled(
      releasePressGlow: () {
        _glassDockKey.currentState?.releasePressGlowImmediately();
        _glassDockRoundKey.currentState?.releasePressGlowImmediately();
      },
      isMounted: () => mounted,
      context: context,
      open: open,
    );
  }

  /// 玻璃坞形态下按钮底边与药丸顶边之间的视觉间隙。
  static const double _backToTodayButtonDockGap = 12;

  /// 列表最后一项与按钮顶边之间的视觉间隙。
  static const double _backToTodayButtonGap = 8;

  /// 经典形态（底栏在页面之外）下按钮距页面底边的边距。
  static const double _backToTodayButtonClassicMargin = 24;

  /// 日视图底部的「回今日」浮钮该不该出现。
  ///
  /// **与周视图的「回本周」浮钮是两套独立体系**：各有自己的可见性条件、
  /// 文案、动作、位置与配色，也不共用设置项——「回本周」受
  /// [TimetableSettings.timetableBackToCurrentWeekButtonStyle] 与浮态透明度
  /// 控制，这颗只跟着"日视图当前看的不是今天"走。两者之间唯一共用的
  /// 事实是底部导航的物理占用（[_glassDockPillOccupancy]）。
  bool _shouldShowFloatingBackToTodayButton(TimetableProvider provider) {
    final target = _dayViewTransition.visibleDayViewTarget();
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

    await _weekPager.jumpToWeek(provider, currentSemesterWeek);
    _maybeSelectionClick(provider.settings);
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

  Future<void> _showAddCourseSheet() {
    final provider = context.read<TimetableProvider>();
    return showTimetableAddCourseSheet(
      context: context,
      initialWeek: _visibleWeek,
      initialDayOfWeek: _addCourseInitialDayOfWeek,
      initialScheduleDate: _resolveAddScheduleInitialDate(provider),
    );
  }
  Future<void> _showCourseActions(
    Course course,
    int week, {
    DayCourseDisplayItem? displayItem,
  }) {
    final provider = context.read<TimetableProvider>();
    return showTimetableCourseActions(
      context,
      provider: provider,
      course: course,
      week: week,
      displayItem: displayItem,
      coupleOverlayActive: _isCoupleOverlayActive(provider),
      weekdayLabels: _weekdayLabels,
      onEdit: _editCourse,
      onAddTask: (target) => _openTaskFromCourse(target, week),
      onSetAlarm: (target) => _openClassReminderSheet(target, week),
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

  void _maybeSelectionClick(TimetableSettings settings) {
    if (!settings.enableHaptics) {
      return;
    }
    HapticFeedback.selectionClick();
  }

  /// 菜单项的实际分发（由 [HomeMenuController.dispatchSelection] 在**菜单收完
  /// 之后**调用）。
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

  // ── HomeMenuHost：顶栏菜单控制器的宿主端口 ──────────────────────────────

  @override
  bool get hasAvailableUpdate => _update.hasUpdate;

  @override
  TimetableSettings get menuSettings =>
      context.read<TimetableProvider>().settings;

  @override
  Future<void> runTopMenuSelection(String selectedId) =>
      _runTopMenuSelection(selectedId, context.read<TimetableProvider>());

  @override
  String? get dockInlinePageId => _dockInlinePageId;

  @override
  set dockInlinePageId(String? value) =>
      setState(() => _dockInlinePageId = value);

  @override
  Future<void> showAddCourseSheet() => _showAddCourseSheet();

  @override
  void pushAfterDockGlowSettled(Future<void> Function(BuildContext) open) =>
      _pushAfterDockGlowSettled(open);

  Future<void> _checkForAppUpdate({required bool includePrerelease}) {
    return _updateDownload.checkForAppUpdate(
      includePrerelease: includePrerelease,
      runCheck: (include) => _update.check(
        settings: context.read<TimetableProvider>().settings,
        includePrerelease: include,
      ),
      onResult: (result) => _updateDownload.scheduleHomeUpdatePrompt(
        context: context,
        settings: context.read<TimetableProvider>().settings,
        result: result,
      ),
      isMounted: () => mounted,
    );
  }

  void _scheduleUpdateCheckIfNeeded(TimetableProvider provider) {
    _updateDownload.scheduleUpdateCheckIfNeeded(
      enabled: widget.enableUpdateCheck,
      provider: provider,
      isMounted: () => mounted,
      check: _checkForAppUpdate,
    );
  }

  Future<void> _openTopMenuUpdatePage() {
    return openTimetableAboutUpdatePage(context);
  }

}
