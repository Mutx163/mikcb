import 'dart:async';
import 'dart:io';
import 'package:flutter_miuix/miuix.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'dart:ui' as ui;
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
        PointerCancelEvent,
        PointerDownEvent,
        PointerEvent,
        PointerUpEvent,
        VelocityTracker,
        kMinFlingVelocity;
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
import '../domain/day_course_display_logic.dart';
import '../providers/timetable_provider.dart';
import '../providers/weather_provider.dart';
import '../services/app_log_service.dart';
import '../services/app_update_service.dart';
import '../services/screen_capture_service.dart';
import '../services/support_creator_service.dart';
import '../services/timetable_share_service.dart';
import '../services/widget_launch_router.dart';
import '../widgets/class_reminder_sheet.dart';
import '../utils/app_toast.dart';
import '../utils/hex_color.dart';
import '../utils/course_color_palette.dart';
import '../utils/first_frame_probe.dart';
import '../utils/frame_perf_probe.dart';
import '../widgets/home_page_region_blur.dart';
import '../utils/home_page_background.dart';
import '../utils/home_startup_visual_primer.dart';
import '../ui/hyperos/liquid/liquid_glass_surface.dart'
    show LiquidGlassSurface, UndimmedBackdropCapture, narrowSurfaceMaxRefraction;
import '../widgets/course_action_sheet.dart';
import '../widgets/course_followup_sheets.dart';
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
import '../widgets/preblurred_wallpaper_glass.dart';
import '../widgets/profile_quick_switch_sheet.dart';
import '../widgets/timetable_home_preview_scope.dart';
import '../widgets/week_selector_picker_sheet.dart';
import 'add_course_screen.dart';
import 'add_exam_screen.dart';
import 'add_schedule_item_screen.dart';
import 'add_task_screen.dart';
import 'about_screen.dart';
import 'course_import_screen.dart';
import 'timetable_profiles_screen.dart';

/// 玻璃坞底栏实际生效的材质。
///
/// 由**全局材质**+ 「作用范围 → 玻璃坞导航」推导（见
/// [_TimetableScreenState._resolveDockMaterial]），不再有独立的「底栏材质」开关——
/// 否则会出现「全局高斯 + 底栏液态」这类两种玻璃同屏的组合。
enum _DockMaterial { liquid, frosted, solid }

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
  /// 玻璃坞药丸的亮暗极性阈值：壁纸亮度低于此值才用深灰玻璃 + 白墨，
  /// 否则乳白玻璃 + 黑墨（极性决定它的底色与指示器配色，见
  /// [SoftGlassTokens.tint] 与 [SoftGlassPolarity]）。
  ///
  /// 阈值取 0.35 而非通用 chrome 的 0.45，是玻璃坞的偏保守取向：中等亮度
  /// 壁纸配深灰玻璃像一块塑料（截图里浅橄榄壁纸配黑玻璃就是这种情况）。
  static const double _kDockGlassDarkLuminance = 0.35;

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
  int? _emptySlotMarkerWeek;
  int? _emptySlotMarkerDayOfWeek;
  /// 虚线框的起始节次（含）。
  int? _emptySlotMarkerSection;
  /// 虚线框的结束节次（含）。与起始相等时框只占一节；出现虚线框后拖上下
  /// 边缘可把它拉长到多节（见 [_resizeEmptySlotMarker]）。
  int? _emptySlotMarkerEndSection;
  /// 一次缩放拖拽的基准首/末节次。基准必须锚在**按下那一刻**的框上：框随
  /// 手指每变一次，若用它自己当基准，节数换算会漂移（越拖越快/回不去）。
  int? _emptySlotResizeBaseStart;
  int? _emptySlotResizeBaseEnd;
  bool _emptySlotResizeIsTopEdge = false;
  /// 本次缩放拖拽的累计纵向位移（px），除以节高取整即节数增量。
  double _emptySlotResizeAccum = 0;
  final GlobalKey _timetableSurfaceKey = GlobalKey();

  /// Anchor for the top-right "more" menu popup (positioned below this key).
  final GlobalKey _topMenuButtonKey = GlobalKey();

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
  final SupportCreatorService _supportCreatorService = SupportCreatorService();
  final HomeUpdatePromptController _updatePromptController =
      HomeUpdatePromptController();
  bool _hasAvailableUpdate = false;
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
  static const double _homePullDampingRange =
      HyperosHomePullPhysics.dampingRange;

  /// 本次手势（手指按下后的那一次拖拽）起点是否**已经在顶部**。
  ///
  /// 下拉快捷导入的手感口径是「先到顶部，再拉一下」：把列表滚回顶部的那一
  /// 拖不算下拉。否则一次从半路滚到顶的手势，尾巴那点在顶部产生的
  /// overscroll 会被当成下拉（视觉上"刚滚上去就弹出转圈"）。
  /// 由 ScrollStartNotification（dragDetails != null，即真是一次拖拽）写入，
  /// ScrollEnd 清掉；弹道（dragDetails == null）不写，免得松手后的回弹被当成"拉"。
  bool _homePullGestureStartedAtTop = false;

  /// 本次指针位移事件开始时下拉是否还开着（决定这一段位移要不要冻住滚动）。
  ///
  /// 由 [_buildHomePullQuickImportSurface] 的原始指针监听写入 / 清空，
  /// 被 [_HomePullFreezeScrollPhysics] 读取。存在这个"事件开始时"的快照，
  /// 是因为原始监听与滚动体处理的是同一个事件、且有先后顺序：见写入处的说明。
  bool _homePullFrozeScrollForEvent = false;

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

  /// 下拉进度看门狗的**全局指针登记**（见 [_onGlobalPointerEvent]）。
  ///
  /// 为什么需要一张全局表：下拉进度有两条驱动路（无滚动体时的原始拖拽探测器 /
  /// 有滚动体时的"到顶 overscroll 通知"），两条路各自只在**自己看得见的那次
  /// 指针结束**时把进度收回。而"结束"送不到的情形确实存在 —— 手势被系统抢走
  /// （从屏幕顶往下拉出通知栏、边缘返回、切到别的应用）、指针被 cancel、
  /// 页面重建把滚动体整块换掉。进度于是停在半截，那颗药丸是**进度圈**（本来就
  /// 不转）、又没有任何超时兜底，就一直挂在首页上（2026-09-22 真机：下拉的
  /// 转圈一直显示、不转也不消失）。
  ///
  /// 判据刻意**不依赖任何一条具体驱动路**，只依赖"屏幕上还有没有手指"这条
  /// 事实：一根都不剩、而进度还没归零 ⇒ 这一轮手势的收尾丢了，当场收回。
  /// （与首页那颗玻璃球的门控同一条思路：拿上游契约当判据，而不是逐个触发点
  /// 打补丁 —— 新加一条驱动路也不会再漏。）
  final Set<int> _homePullLivePointers = <int>{};

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

  /// 「缩尺预览」宿主（「外观编辑」页）注入时非空；正常首页为 null。
  ///
  /// 非空即**预览模式**：日 / 周由外部 notifier 驱动，且不写回访状态、
  /// 不接截屏监听（见 [TimetableHomePreviewScope] 的类注释）。
  TimetableHomePreviewScope? _previewScope;
  bool _previewSyncScheduled = false;

  bool get _isPreview => _previewScope != null;

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
            dayOfWeek: _resolveStoredDayOfWeek(
              settings,
              scope.dayOfWeek.value,
            ),
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetLaunchRouter.coupleOverlayRequestTick.addListener(
      _onExternalCoupleOverlayRequest,
    );    final provider = context.read<TimetableProvider>();
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
    // 下拉进度的收尾看门狗：全局指针路由（事件先到这里，再走命中派发），
    // 与下拉当前由哪条路驱动无关。见 [_homePullLivePointers]。
    GestureBinding.instance.pointerRouter.addGlobalRoute(
      _onGlobalPointerEvent,
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
    _previewScope?.dayView.removeListener(_onPreviewDayViewChanged);
    _previewScope?.dayOfWeek.removeListener(_onPreviewDayViewChanged);
    WidgetsBinding.instance.removeObserver(this);
    WidgetLaunchRouter.coupleOverlayRequestTick.removeListener(
      _onExternalCoupleOverlayRequest,
    );
    _homePullQuickImportCancel?.call();
    GestureBinding.instance.pointerRouter.removeGlobalRoute(
      _onGlobalPointerEvent,
    );
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
    _homeMenuCloseDelay?.cancel();
    _homeMenuCloseDelay = null;
    // 页面走了就把截屏监听交回去：监听不该比「谁在听」活得久。
    unawaited(_screenshotSubscription?.cancel());
    _screenshotSubscription = null;
    _screenshotListening = false;
    unawaited(ScreenCaptureService.stop());
    _homeMenuAnchor.dispose();
    _homeGlass.dispose();
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
        _syncScreenshotListener(provider.settings);
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
        final hasBackdrop = hasHomePageBackdrop(settings);
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
        // 顶栏「更多」「爱心」的常驻玻璃球（[FHeaderActionBall]）。**必须画在
        // 采样宿主之外**（_wrapHomeWithTopMenu 的 Stack 里、Host 的兄弟层）：
        // 页内玻璃的采样快照录自捕获节点的图层，球若长在捕获子树里，它自己的
        // 输出会被烘进下一次采样 —— 打开菜单时按钮被上游隐藏、快照是干净的，
        // 关闭后按钮重绘即触发重采样，球就"变一次材质"并稳定在烘过自己一层
        // 的样子（2026-09-14 真机现象）。图标墨色见 [_chromeActionBallInk]；
        // 「更多」在菜单打开期间让位给弹窗自己的形变球（与真实按钮被
        // `contentHidden` 隐藏的窗口一致，见 ListenableBuilder）。
        final chromeDotBorderColor = headerBarColor.a == 0
            ? colorScheme.surface
            : headerBarColor;
        final homeChromeBalls = [
          ListenableBuilder(
            listenable: _homeMenuAnchor,
            builder: (_, _) => FHeaderActionBall(
              link: _moreBallLink,
              visible: !_homeMenuAnchor.contentHidden,
              icon: _buildMoreActionIcon(dotBorderColor: chromeDotBorderColor),
            ),
          ),
          // 爱心球与爱心按钮同门禁（hasPartnerBinding）：按钮不在树上时
          // LayerLink 没有 leader，follower 会画在自己的布局位置（Stack 左上角）。
          if (provider.hasPartnerBinding)
            FHeaderActionBall(
              link: _heartBallLink,
              icon: Icon(
                _isCoupleOverlayActive(provider)
                    ? Icons.favorite_rounded
                    : Icons.favorite_outline_rounded,
                color: _isCoupleOverlayActive(provider)
                    ? const Color(0xFFE91E63)
                    : _chromeActionBallInk,
              ),
            ),
        ];
        final followsWeekPager =
            hasBackdrop && settings.homePageBackdropFollowsWeekPager;
        // Keep the same frosted chrome band in day view. The weekday header
        // already paints a transparent fill when blur is on; without this
        // overlay the title/weekday chrome becomes fully clear over wallpaper.
        final continuousChromeBlur = homePageHasAnyChromeBlur(
          settings,
          hasBackdrop: hasBackdrop,
        );
        // Cards fall back to solid when blur is off, so building the
        // pre-blurred bitmap would decode and Gaussian-blur the whole
        // wallpaper for nothing.
        final backdropBlurOn =
            hasBackdrop && HyperosBlurredHeader.backdropBlurEnabled(context);
        // No wallpaper or no blur pipeline (global solid / degraded) ->
        // cards render solid regardless of what the surface-style switch is
        // set to; ink rules follow the same resolution.
        final cardStyle = effectiveCourseCardSurfaceStyle(
          settings,
          gaussianBlurAvailable: backdropBlurOn,
        );
        // Gaussian cards sample the cached bitmap instead of a live
        // BackdropFilter while the day-view shell is animating.
        final useCoursePreblur =
            backdropBlurOn && cardStyle.isGlass;
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
          gaussianCardsDrive: backdropBlurOn && cardStyle.isGlass,
          // 预模糊位图服务的是首页玻璃带/摘要卡。顶栏材质是生效值（follow 已
          // 解析），只有液态档吃液态调参的模糊量；磨砂带（frost）与实体都走
          // 全局模糊强度，与启动预热器同判。
          liquidGlassChrome:
              dockAppearance.homeBandGlassMaterial == 'liquid',
          sheetBlurSigma: HyperosBlurredHeader.blurSigmaOf(context),
          liquidGlassTunedBlur:
              (dockAppearance.liquidGlassTuning ?? LiquidGlassTuning.defaults)
                  .blurSigma,
        );
        // 卡片那张位图走**卡片自己的**磨砂量（液态档才有；其它档退回 0 = 不烤）。
        // 与上面那笔分开算，是本次「卡片独立材质」的核心：一处动不再两处变。
        final courseCardPreblurSigma = resolveCourseCardPreblurSigma(
          cardStyle: cardStyle,
          cardTuning: settings.courseCardGlassTuning,
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
        final Widget homeStack = BackdropGroup(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasBackdrop)
                      // 背景随周次滑动时，克隆多页共用同一张壁纸。
                      followsWeekPager
                          ? HomePageSlidingBackdropLayer(
                              controller: _weekPageController,
                              pageCount: settings.semesterWeekCount,
                              settings: settings,
                            )
                          : homePageBackdropLayer(settings: settings),
                    if (hasBackdrop && !statusBarShowsBackdrop)
                      HomePageStatusBarBackdropMask(
                        color: pageBackgroundColor,
                      ),
                    // 组内首个 grouped filter：缓存未压暗的全屏壁纸供玻璃带
                    // 采样，与预览的 UndimmedBackdropCapture 同款、同相对位置。
                    if (continuousChromeBlur)
                      const Positioned.fill(
                        child: UndimmedBackdropCapture(),
                      ),
                  ],
                ),
              ),
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
                    CompositedTransformTarget(
                      link: _heartBallLink,
                      // 可见图标（爱心）画到采样宿主之外的常驻玻璃球上
                      // （见 [_homeChromeBalls] 与 FHeaderActionBall 的说明），
                      // 这里只留透明点击区。
                      child: FHeaderAction(
                        icon: const SizedBox(width: 24, height: 24),
                        semanticsLabel:
                            _isCoupleOverlayActive(provider)
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
                    ),
                  // 两颗玻璃球之间的间距：顶栏后缀行是裸 `Row`（无 spacing），
                  // 两个 40 宽按钮挨着 = 两颗球边缘相切；换成玻璃后各带描边 /
                  // 外阴影，相切读起来就是"贴得太近"（2026-09-14 真机反馈）。
                  // 只在与爱心同时出现时插入，单独一颗时与原来一致。
                  if (provider.hasPartnerBinding) const SizedBox(width: 8),
                  // 上游形变弹层要求把锚点绑在触发控件上（[MiuixGlassAnchor]
                  // 负责挂它自己的 GlobalKey）；[_topMenuButtonKey] 仍保留，
                  // 供「八宫格」形态在原位置弹出底部弹层用。
                  // 按下即预热首页采样源：图层快照帧末录制，抬手打开菜单时
                  // 已就绪，弹层首帧就是玻璃而不是透明轮廓。
                  Listener(
                    onPointerDown: (_) => _prewarmHomeGlass(),
                    onPointerUp: (_) {
                      if (!_homeMenuOpen) _releaseHomeGlass();
                    },
                    onPointerCancel: (_) {
                      if (!_homeMenuOpen) _releaseHomeGlass();
                    },
                    child: CompositedTransformTarget(
                    link: _moreBallLink,
                    child: MiuixGlassAnchor(
                    anchor: _homeMenuAnchor,
                    child: KeyedSubtree(
                    key: _topMenuButtonKey,
                    child: FHeaderAction(
                      // 可见图标（含更新红点）画到采样宿主之外的常驻玻璃球上
                      // （见 [_homeChromeBalls] 与 FHeaderActionBall 的说明），
                      // 这里只留透明点击区。
                      icon: const SizedBox(width: 24, height: 24),
                      semanticsLabel: l10n.moreTooltip,
                      onPress: _showTopActionsSheet,
                    ),
                  ),
                  ),
                  ),
                  ),
                ],
                child: Padding(
                  padding: EdgeInsets.only(
                    // 日课表的列表视口保持全屏：避让改为列表自身的滚动
                    // padding（见 _buildExpandedDayColumnView），滚动中卡片
                    // 连续穿过底部避让带，不在避让边界被硬裁出一条与磨砂
                    // 卡片色差明显的「生壁纸」空带；周课表网格不可滚动，
                    // 避让仍由这里的布局 padding 承担。
                    bottom: glassDockForm && !_isDayView ? 0.0 : 0,
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: provider.isLoading
                        // Single-stage: system splash already covers loading;
                        // render matching background to avoid spinner flash
                        // if provider momentarily reports loading post-splash.
                        ? ColoredBox(
                            color:
                                Theme.of(context).brightness == Brightness.dark
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
                                // 日视图自己的「回今日」浮钮（底部居中）。与上面
                                // 那颗「回本周」互斥：那颗在日视图一律不显示，
                                // 这颗只在日视图且当前不是今天时出现。
                                //
                                // 绑在 [_dayHeaderPreview] 上做**局部重建**，与
                                // 周视图「回本周」绑 [_visibleWeekListenable] 是
                                // 同一个套路：日视图滑动期间整屏刻意不 setState
                                // （防 ANR），若把可见性算在整屏 build 里，就得等
                                // ScrollEnd 落定后才出现——用户读到的是"过半天才
                                // 弹出来"。页中点预览是滑动中唯一逐页变化的信号。
                                ValueListenableBuilder<(int, int)?>(
                                  valueListenable: _dayHeaderPreview,
                                  builder: (context, _, _) {
                                    if (!_shouldShowFloatingBackToTodayButton(
                                      provider,
                                    )) {
                                      return const SizedBox.shrink();
                                    }
                                    return _buildFloatingBackToTodayButton(
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
        // 玻璃坞导航始终由 [_buildGlassDockLayer] 浮在最上层（画在采样宿主之外）。
        final Widget dockContent = useHomePreblur
            ? PreblurredWallpaperScope(
                // Same pre-blur model as the week grid: sample one cached
                // frost bitmap by card screen position. In day view the week
                // pager is locked, so drive repaints from the day agenda pager
                // and treat the wallpaper as screen-fixed (it never follows
                // the day swipe).
                wallpaperPath: homePageBackdropKey(settings),
                blurSigma: homePreblurSigma,
                // 卡片那份位图（只有卡片是液态档才烤）。同一份路径与对齐值，
                // 只有 sigma 不同 —— 所以两张图不会出现取景错位。
                // 卡片那份的 0 是有效值（清档：出原图），只有 null 才是不烤 ——
                // 所以这里不做 `?? 0` 折算，null 必须原样传下去。
                cardBlurSigma: courseCardPreblurSigma,
                // 卡里的位图必须与屏幕上那张真壁纸**同一套 cover 对齐**：用户
                // 在「壁纸位置」里拖过对齐值之后，居中铺图的副本就会与背景错位
                // （卡内外壁纸接不上），所以这两个值随设置一起传。
                wallpaperAlignX: settings.homePageWallpaperAlignX,
                wallpaperAlignY: settings.homePageWallpaperAlignY,
                wallpaperScale: settings.homePageWallpaperScale,
                pageController: _isDayView
                    ? _ensureDayViewPageController(settings)
                    : _weekPageController,
                followsPager: _isDayView ? false : followsWeekPager,
                // 锚点展开/收起与设置页拖动转场期间卡片在移动而壁纸
                // 屏幕固定：fill 必须每帧重采样，否则纹理停在旧屏幕位置
                // （卡片半边模糊半边透明）。合并两个动画统一驱动重采样。
                repaint: _glassDockCardRepaint,
                child: homeStack,
              )
            : homeStack;
        if (!glassDockForm) {
          return _wrapHomeWithTopMenu(
            dockContent,
            settings: settings,
            chromeBalls: homeChromeBalls,
            chromeDotBorderColor: chromeDotBorderColor,
          );
        }
        // 底栏为可编排快捷区：页面类条目在首页栈内切换（内嵌宿主，
        // 玻璃坞常驻悬浮），仅未登记的流程页才推入新路由。
        final inlineId = _dockInlinePageId;
        final inlineBuilder = inlineId == null
            ? null
            : inlineDockPageFor(inlineId);
        final Widget hostedContent = inlineBuilder == null
            ? dockContent
            : Stack(
                fit: StackFit.expand,
                children: [
                  // 内嵌页是**不透明**的整屏 Scaffold，会把首页完全盖住；但
                  // Stack 的两个孩子每帧都会被绘制，于是内嵌态下首页那一整套
                  // （满屏壁纸铺底 + 玻璃带 backdrop 采样 + 课程卡片）一直在
                  // 白白重画。真机实测（Redmi K80 Ultra / 120Hz 面板）：
                  //   - 内嵌态设置页上下滑动 ≈ 82 fps；
                  //   - 同一页从右上角菜单**单独推路由**打开 ≈ 103 fps。
                  // 两者唯一的结构差别就是这个"看不见但仍在画"的首页。
                  // 用 Visibility(maintainSize) 保留挂载与布局、只去掉绘制
                  // （返回首页仍是闪现直切，几何/滚动位置不受影响），
                  // 并用 TickerMode 停掉被完全遮挡页面的动画节拍
                  //（与"被路由覆盖"时框架的默认行为一致）。
                  TickerMode(
                    enabled: false,
                    child: Visibility(
                      visible: false,
                      maintainState: true,
                      maintainSize: true,
                      maintainAnimation: true,
                      child: dockContent,
                    ),
                  ),
                  // 与旧「设置 Tab」一致：点底栏闪现直切，无滑动转场。
                  Positioned.fill(
                    child: Material(
                      type: MaterialType.transparency,
                      child: Scaffold(
                        backgroundColor: Theme.of(
                          context,
                        ).scaffoldBackgroundColor,
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
        // 系统返回不拦内嵌页：与日/周课表同口径，底栏任意状态（日/周
        // 课表或内嵌页）按返回都直接退出应用（根路由 bubble → 系统退出）。
        // 收回内嵌页走底栏切换（点 日/周 Tab 或其他页面条目）与圆钮再点。
        return _wrapHomeWithTopMenu(
          hostedContent,
          settings: settings,
          chromeBalls: homeChromeBalls,
          chromeDotBorderColor: chromeDotBorderColor,
          // 坞层由 _wrapHomeWithTopMenu 摆到采样宿主**之外**（不自采样），
          // 理由见 _buildGlassDockLayer 的注释。
          dockLayer: _buildGlassDockLayer(settings: settings, l10n: l10n),
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
        showUpdateDot: _hasAvailableUpdate,
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
    _clearEmptySlotMarker();
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
  /// 采用启动预热器（HomeStartupVisualPrimer）缓存的壁纸亮度带作初值。
  ///
  /// 只在冷启动首帧前的空窗期生效一次：本页任何亮度字段已被赋值或常规
  /// 异步采样已启动（requestedKey 非空）时直接返回，绝不覆盖精确采样结果。
  void _seedWallpaperLuminanceFromStartupPrimer(TimetableSettings settings) {
    if (_wallpaperTopLuminance != null ||
        _wallpaperWeekdayLuminance != null ||
        _wallpaperBodyLuminance != null ||
        _wallpaperLuminanceRequestedKey != null) {
      return;
    }
    final bands = HomeStartupVisualPrimer.seededBandsFor(
      homePageBackdropKey(settings),
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
    // 统一用「背景身份键」（背景图绝对路径）做采样缓存 key。
    final path = homePageBackdropKey(settings);
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
    // 本方法在 build 期间被调用，而 _ensureWallpaperLuminanceForPath 首段
    // （existsSync 结果分流）含同步 setState：直接调用会在 build 期把本组件
    // 标脏，触发 "setState() called during build" 异常并中断壁纸亮度采样
    // 链，导致墨色极性停在主题默认色。统一推迟到帧后首跑，天然规避
    // build 期限制，重复进入也由 requestedKey 幂等去重。
    unawaited(
      Future<void>.sync(() {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          _ensureWallpaperLuminanceForPath(
            settings,
            viewportSize: viewportSize,
            alignX: settings.homePageWallpaperAlignX,
            alignY: settings.homePageWallpaperAlignY,
            key: key,
          );
        });
      }),
    );
  }

  /// 采样缓存 key：`路径|视口宽x高|alignX|alignY`。
  ///
  /// 组成字段均为可枚举的有限来源（壁纸路径来自 managed storage、视口来自
  /// MediaQuery、对齐值来自 -1.0~1.0 的滑杆），调用方不会注入意外分隔符。
  /// 用 `|` 分隔足以避免歧义，无需哈希或结构化 key。
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
    TimetableSettings settings, {
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
    // 下面的字段赋值统一收敛到 setState 内：本方法在异步回调中运行，
    // 风格混用（部分在 setState 外、部分在内）会让后续维护者难以判断
    // 哪些赋值会触发重绘，容易漏包导致 UI 与状态脱节。
    _wallpaperLuminanceRequestedKey = key;
    // 背景图文件丢失时清空亮度采样，让顶栏/星期栏墨色回落到主题默认。
    final filePath = resolveHomePageBackdropImagePath(settings);
    final fileExists = filePath == null || filePath.isEmpty
        ? true
        : File(filePath).existsSync();
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
    setState(() {
      _wallpaperLuminanceFileExists = true;
      _wallpaperLuminanceSampleKey = key;
    });
    await _loadWallpaperLuminance(
      settings,
      viewportSize: viewportSize,
      alignX: alignX,
      alignY: alignY,
      key: key,
    );
  }

  Future<void> _loadWallpaperLuminance(
    TimetableSettings settings, {
    required Size viewportSize,
    required double alignX,
    required double alignY,
    required String key,
  }) async {
    final bands = await sampleHomePageBackdropLuminanceBands(
      settings,
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
  /// contrast against the current wallpaper. The ink keeps its colour and only
  /// gets its lightness pushed for readability ([homePageOverWallpaperInk]);
  /// this explains the change and offers restoring the default (auto B/W).
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
    if (!hasHomePageBackdrop(settings)) {
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
    final hasBackdrop = hasHomePageBackdrop(settings);
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
    // over a dark wallpaper; a custom ink keeps its hue, only the lightness moves.
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
                        // bar; a custom hex keeps its colour, only the
                        // lightness moves when it would be unreadable. Accent
                        // (today/selected) obeys the same rule so the "today"
                        // column neither vanishes into the photo nor loses the
                        // colour the user picked.
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
      return controllerPageOrNull(controller) ??
          controller.initialPage.toDouble();
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
              final rawPage =
                  controllerPageOrNull(controller) ??
                  controller.initialPage.toDouble();
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
              final baseWidth = math.min(22, slotWidth * 0.34);
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
              final maxLeft = math.max(0, totalWidth - indicatorWidth);
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
    // （星期几, 节次）已被课程覆盖的集合，供长按拖动判定空白格。
    final occupiedSections = <(int, int)>{};
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
            child: _buildEmptySlotGestureArea(
              settings: settings,
              week: week,
              sectionHeight: sectionHeight,
              dayWidth: dayWidth,
              visibleDays: visibleDays,
              occupiedSections: occupiedSections,
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
                  // 长按拖动换格时判定"某格是否空白"的事实来源：课程覆盖
                  // 的（星期×节次）全集。此处在本 build 内即刻求值。
                  for (final item in displayItems) {
                    for (var s = item.course.startSection;
                        s <= item.course.endSection;
                        s++) {
                      occupiedSections.add((dayOfWeek, s));
                    }
                  }
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
                      occupiedSections: occupiedSections,
                    ),
                  );
                }).toList(),
              ),
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
    //
    // 玻璃坞形态会给周课表注入底部滚动余量（_glassDockContentScrollInset
    // > 0），网格变成可滚动的 SingleChildScrollView——此时若仍挂原始拖拽
    // 探测器，任何竖向下拉都会不计滚动位置地累计下拉进度，「还没滑动到
    // 顶部」就打开下拉 → 提前触发快捷导入（更新）。有余量的场景统一交给
    // 上方的 NotificationListener / OverscrollNotification（自带 atTop
    // 位置判定 + 手势起点是否在顶部的判定，见 _homePullGestureStartedAtTop）。
    // 两种驱动二选一，避免同一段手指位移被计两次：
    // - 无纵向滚动体（自适应周课表 + 经典形态）：探测器自己看原始指针；
    // - 有纵向滚动体：打开仍由上面的 Overscroll 通知驱动（自带 atTop +
    //   手势起点判定），一旦打开，纵向滚动被 [_HomePullFreezeScrollPhysics]
    //   冻住，改由原始指针收放——冻结后不再产生滚动通知，手指上移的"收"
    //   只有这里收得到。此前是"边收边让列表滚"，用户读作"想取消却把页面
    //   滚上去了"。
    if (settings.timetableAutoFitSectionHeight &&
        !_isDayView &&
        _glassDockContentScrollInset(settings) <= 0) {
      surface = _HomePullVerticalDragDetector(
        enabled: !_isHomePullQuickImportRunning,
        onPullUpdate: _updateHomePullDragDistance,
        onPullEnd: _finishHomePullDrag,
        onPullCancel: _cancelHomePullDrag,
        child: surface,
      );
    } else {
      surface = Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _homePullFrozeScrollForEvent = false,
        onPointerUp: (_) => _homePullFrozeScrollForEvent = false,
        onPointerCancel: (_) => _homePullFrozeScrollForEvent = false,
        onPointerMove: (event) {
          // 冻结判定必须用**本事件开始时**的下拉状态：原始指针监听先于滚动体
          // 收到同一事件，用实时值的话，手指上移会先把下拉收到 0，紧接着
          // 滚动体查到的就是"下拉已关"→ 列表照滚（正是要拦的那一下）。
          final open = _homePullDragDistance > 0 || _homePullTouchDistance > 0;
          _homePullFrozeScrollForEvent = open;
          if (!open) {
            return;
          }
          _updateHomePullDragDistance(event.delta.dy);
        },
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
        color:
            (isDark
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
                ? const MiuixCircularProgressIndicator(
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
            Container(
              width: 0.8,
              height: 14,
              color: HyperosColors.dividerLine(context),
            ),
            const SizedBox(width: 10),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: _cancelHomePullQuickImport,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
    final hasBackdrop = hasHomePageBackdrop(
      context.read<TimetableProvider>().settings,
    );
    final decoratedPill = hasBackdrop
        ? ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              // ⚠️ `tileMode: clamp` 必须给：默认 decal 会让模糊结果在离边约 3σ
              // 的带里淡成透明黑，而这张圆角药丸的边是可见的 —— 那一圈会读成
              // 一圈深色描边。同款规则与修法见 `liquid_glass_surface.dart`。
              filter: ui.ImageFilter.blur(
                sigmaX: 14,
                sigmaY: 14,
                tileMode: ui.TileMode.clamp,
              ),
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

  /// 首页纵向滚动体统一使用的 physics：下拉开着时冻结（见
  /// [_HomePullFreezeScrollPhysics]）。周课表与日课表都用它，"回拉取消"
  /// 的手感两处一致；runtimeType 恒定，不会中途重建 ScrollPosition。
  ScrollPhysics get _homePullVerticalPhysics => _HomePullFreezeScrollPhysics(
    isFrozen: () => _homePullFrozeScrollForEvent,
    parent: const AlwaysScrollableScrollPhysics(),
  );

  void _updateHomePullDragDistance(double deltaDy) {
    if (_isHomePullQuickImportRunning) {
      return;
    }
    final atRest =
        _homePullDragDistance <= 0.5 && _homePullTouchDistance <= 0.5;
    if (deltaDy <= 0 && atRest) {
      return;
    }
    // Finger takes over from any in-flight settle spring.
    if (_homePullSettleSpring?.isAnimating ?? false) {
      _homePullSettleGeneration++;
      _homePullSettleSpring?.stop();
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
    const threshold = _homePullQuickImportTriggerDistance;
    final crossedUp =
        _homePullDragDistance < threshold && nextVisual >= threshold;
    final reArmed =
        _homePullDragDistance >= threshold && nextVisual < threshold * 0.88;
    if (reArmed) _homePullHapticArmed = true;
    if (nextVisual == _homePullDragDistance && !crossedUp) {
      return;
    }
    if (crossedUp && _homePullHapticArmed) {
      _homePullHapticArmed = false;
      // 同步读取 provider：Element 已卸载时 context.read 会抛异常，
      // 前置 mounted 守卫替代吞异常，避免掩盖真实的 unmounted-read bug。
      if (mounted) {
        final settings = context.read<TimetableProvider>().settings;
        if (settings.enableHaptics) HapticFeedback.selectionClick();
      }
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

  /// 全局指针登记（[GestureBinding.pointerRouter] 的全局路由：同一事件先到这里，
  /// 再走命中派发）。只做两件事：登记 / 注销指针；最后一根手指离开屏幕时错开
  /// 这一轮派发做一次兜底收回（[_retractOrphanedHomePull]）。
  ///
  /// ⚠️ 兜底必须错开：正常路径的收尾（滚动到顶那条路的 `ScrollEndNotification`
  /// → [_finishHomePullDrag] 里"够阈值就拉课表"的判定）就在同一批**同步**处理里。
  /// 抢在它前面收回会把那次触发吃掉（用户拉到阈值上方抬手，却什么都没发生）。
  /// 微任务排在事件派发结束之后，判定已经走完。
  void _onGlobalPointerEvent(PointerEvent event) {
    if (event is PointerDownEvent) {
      _homePullLivePointers.add(event.pointer);
      return;
    }
    if (event is! PointerUpEvent && event is! PointerCancelEvent) {
      return;
    }
    _homePullLivePointers.remove(event.pointer);
    if (_homePullLivePointers.isNotEmpty) {
      return;
    }
    scheduleMicrotask(_retractOrphanedHomePull);
  }

  /// 看门狗本体：屏上已经没有手指、也不在拉课表，而进度还没归零 ⇒ 这一轮手势
  /// 的收尾丢了，收回。
  ///
  /// 与正常收尾**幂等**：正常路径已经把它拨向 0，这里最多再把弹簧重拨一次
  /// （目标相同），不会打架；真处于"收尾丢了"的状态才是唯一有效的那一次。
  void _retractOrphanedHomePull() {
    if (!mounted || _isHomePullQuickImportRunning) {
      return;
    }
    if (_homePullDragDistance <= 0 && _homePullTouchDistance <= 0) {
      return;
    }
    _homePullSettleTo(0);
  }

  // --- Home pull spring helpers (HyperOS critical-damped, period 0.4s) ---
  void _driveHomePullSettle() {
    final spring = _homePullSettleSpring;
    if (spring == null) return;
    final v = spring.value;
    if (!mounted) return;
    setState(() {
      _homePullDragDistance = v.clamp(0.0, _homePullQuickImportMaxDistance);
      _homePullTouchDistance = HyperosHomePullPhysics.touchForOffset(
        v,
        _homePullDampingRange,
      ).clamp(0.0, _homePullDampingRange);
    });
  }

  void _homePullSettleTo(double target) {
    final spring = _homePullSettleSpring;
    if (spring == null) {
      setState(() {
        _homePullDragDistance = target;
        _homePullTouchDistance = HyperosHomePullPhysics.touchForOffset(
          target,
          _homePullDampingRange,
        );
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
    spring
        .animateWith(sim)
        .then((_) {
          if (!mounted || generation != _homePullSettleGeneration) return;
          setState(() {
            _homePullDragDistance = target;
            _homePullTouchDistance = HyperosHomePullPhysics.touchForOffset(
              target,
              _homePullDampingRange,
            );
          });
        })
        .catchError((Object _) {});
  }

  /// Clamping overscroll at the top of the week/day vertical scrollables.
  ///
  /// 只有「按下时就已经在顶部」的手势才累计下拉
  /// （[_homePullGestureStartedAtTop]）：滚回顶部的那一拖整段不算，
  /// 需要到顶部后再拉一次。见该字段的说明。
  bool _handleHomePullScrollNotification(ScrollNotification notification) {
    if (_isHomePullQuickImportRunning) {
      return false;
    }
    final metrics = notification.metrics;
    if (metrics.axis != Axis.vertical) {
      return false;
    }

    final atTop = metrics.pixels <= metrics.minScrollExtent + 0.5;

    // 手势起点快照：只有"手指按下时就已经在顶部"的这次拖拽才允许累计下拉。
    // 滚回顶部的那一拖（起点在半路）整段都不计，用户要再拉一下才触发。
    if (notification is ScrollStartNotification) {
      _homePullGestureStartedAtTop =
          notification.dragDetails != null && atTop;
      return false;
    }

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

    if (notification is OverscrollNotification &&
        atTop &&
        _homePullGestureStartedAtTop) {
      // Negative overscroll = past the leading edge (top) while pulling down.
      if (notification.overscroll < 0) {
        _updateHomePullDragDistance(-notification.overscroll);
      } else if (notification.overscroll > 0 && _homePullDragDistance > 0) {
        // Positive overscroll at top while pull is open: treat as retract.
        _updateHomePullDragDistance(-notification.overscroll);
      }
      return false;
    }

    if (notification is ScrollEndNotification) {
      _homePullGestureStartedAtTop = false;
      if (_homePullDragDistance > 0) {
        _finishHomePullDrag();
        return false;
      }
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
    _homePullSettleSpring?.stop();
    _homePullHapticArmed = true;
    _homePullTouchDistance = 0;
    setState(() {
      _isHomePullQuickImportRunning = true;
      _homePullDragDistance = 0;
      _homePullQuickImportCancel = null;
    });
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
    final hasBackdrop = hasHomePageBackdrop(settings);
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
        // 下拉开着时冻结纵向滚动（见 _HomePullFreezeScrollPhysics）：
        // 回拉取消只收下拉，不把列表一起滚走。
        physics: _homePullVerticalPhysics,
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
        // 下拉开着时冻结纵向滚动（见 _HomePullFreezeScrollPhysics）：
        // 回拉取消只收下拉，不把列表一起滚走。
        physics: _homePullVerticalPhysics,
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
    required List<DayCourseDisplayItem> courseItems,
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
    required List<DayCourseDisplayItem> courseItems,
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

    final isDark = theme.brightness == Brightness.dark;
    final hasBackdrop = hasHomePageBackdrop(settings);
    final backdropBlurOn =
        hasBackdrop && HyperosBlurredHeader.backdropBlurEnabled(context);
    final courseCardStyle = dayViewContentCardSurfaceStyle(
      settings,
      backdropBlurOn: backdropBlurOn,
    );
    // 摘要卡跟**课程卡**同材质（用户口径 2026-09-22：「日视图顶部的日期卡片……
    // 也要跟日视图的课程卡片是一样的材质，选什么就是什么，不要第二种」）：
    // 材质一律由 CourseSurface 按 effectiveCourseCardSurfaceStyle 出 —— 与下方
    // 议程卡走**同一条路径、同一档、同一份预糊位图、同一套调参**。
    //
    // 这里曾经有一条例外分支（`chromeGlass` 亮磨砂替身：跟顶栏铬玻璃带同款）：
    // 课程卡是玻璃档时给摘要卡贴一块固定的亮色 wash，读作"顶栏同款"而不是
    // "课程卡同款"——用户实测两张卡材质不一致。例外已删除，
    // `homePageHasAnyChromeBlur` 也不再参与这张卡的材质判定。
    //
    // 实体档那条老口径自然仍成立：无壁纸 / 全局模糊关掉时
    // [effectiveCourseCardSurfaceStyle] 就回落实体，摘要卡跟着实底，不会出现
    // 「课程卡实心、顶上的日期卡还透」。
    // Ink: 卡面**真的把壁纸透出来**时才自动黑白；否则卡面是主题底色
    // 的实底，墨色必须跟主题走 —— 按壁纸亮度翻白会让白墨落在亮色卡面上
    // 不可读。判据是**卡实际用的材质**，不是顶栏状态。
    //
    // 自动黑白判的是**卡面**亮度（卡自己的底色 + 壁纸那条带按染色强度混合，
    // 见 [contentCardInkOverWallpaper]），不是裸壁纸亮度：2026-09-22 真机反馈
    // "浅色主题下卡面发白、字也是浅色糊在一起"，就是漏了卡面那层 32%~42% 的
    // 自有底色所致。
    //
    // 壁纸那条带取的是 `_weekdayInkLuminance`（信息栏与顶栏带用的就是它）：
    // 这张卡的墨色本来就是信息栏那套
    //（configuredHex 取的就是 weekdayBarFontColor*）。
    // 早先这里用 body 带（整屏下半部，常含壁纸的深色区），于是出现"带是
    // 浅色、卡片也是亮卡，却按深色壁纸翻成白墨"——白字落在亮卡上读不出来
    // （真机反馈：高斯档下日课表那张日期卡）。
    final glassOverWallpaper = backdropBlurOn && courseCardStyle.isGlass;
    final summaryInk = glassOverWallpaper
        ? contentCardInkOverWallpaper(
            // 判据是**卡面**亮度，不是裸壁纸：卡面上还压着
            // `CourseSurface.washAlpha` 比例的自有底色（就是这里的
            // `foruiTheme.colors.background`）。只看壁纸会在浅色主题下把白字
            // 判到被冲白的卡面上（2026-09-22 真机反馈），详见该函数。
            cardFill: foruiTheme.colors.background,
            washAlpha: CourseSurface.washAlpha(context, courseCardStyle),
            configuredHex: isDark
                ? settings.weekdayBarFontColorDark
                : settings.weekdayBarFontColorLight,
            defaultHex: isDark
                ? TimetableSettings.defaultWeekdayBarFontColorDark
                : TimetableSettings.defaultWeekdayBarFontColorLight,
            themeFallback: foruiTheme.colors.foreground,
            hasBackdrop: hasBackdrop,
            wallpaperLuminance: _weekdayInkLuminance(settings),
          )
        : foruiTheme.colors.foreground;
    final summaryMutedInk = homePageOverWallpaperMutedInk(summaryInk);
    // 课程计数胶囊与「X 节日程」胶囊同款中性墨：跟摘要卡其余文字一样走
    // 壁纸自动黑白，有课与否不再切换主题蓝强调色。
    final countBadgeColor = summaryInk.withValues(alpha: 0.10);
    final countBadgeTextColor = summaryMutedInk;
    return _dayAgendaSurface(
      key: key,
      // 材质全部交给 CourseSurface 按 effectiveCourseCardSurfaceStyle 判
      //（无壁纸 / 全局模糊关掉时它自己回落实体），这里不再覆盖卡片档。
      settings: settings,
      // Neutral wash (not a course hue); CourseSurface owns glass vs solid.
      color: foruiTheme.colors.background,
      gradient: LinearGradient(
        colors: [foruiTheme.colors.background, foruiTheme.colors.background],
      ),
      // 摘要卡没有课程色填充可依托：无壁纸（纯色页面）时填充色与页面底色
      // 相同，无边框无阴影会整张隐形（下方课程卡靠 hue + outerShadow 保持
      // 边界）。补一套中性细描边 + 柔和投影，几何参数与 agenda 卡片一致，
      // 让两种卡片在纯白底上读作同一个卡片系统。
      border: Border.all(color: summaryInk.withValues(alpha: 0.12)),
      shadow: [
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
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // 「回到今天」已挪到日视图底部的悬浮按钮（见
                      // [_buildFloatingBackToTodayButton]）：这张摘要卡只留
                      // 「今天 · 第几周」，不再放可点胶囊，避免两个入口。
                      if (isToday) ...[
                        Text(
                          l10n.todayTimetableTitle,
                          style: foruiTheme.typography.body.sm.copyWith(
                            color: summaryMutedInk,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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
                      ],
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
    final hasBackdrop = hasHomePageBackdrop(settings);
    final colorScheme = Theme.of(context).colorScheme;
    // Same wallpaper auto-contrast as weekday / time-axis chrome: default ink
    // flips black↔white over dark photos; a custom hex keeps its hue and only
    // gets its lightness pushed. The empty state sits mid-screen, so judge
    // from the card-region band.
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
    // 再叠一层「回今日」浮钮的占用：浮钮浮在药丸上方居中，不补这段余量
    // 时滑到底的最后一张卡会被它压住（同底栏遮内容的道理，见
    // [_backToTodayButtonScrollInset]）。
    final todayButtonAvoidance = _backToTodayButtonScrollInset(provider);
    final bottomContentInset = 8 + dockScrollAvoidance + todayButtonAvoidance;
    if (agendaItems.isEmpty) {
      // 空白天同样要能下拉导入：空态本身不是滚动体，外面套一层
      // AlwaysScrollable 的滚动视图，下拉才有着力点（有课那天走的是
      // ListView，两条路都必须能触发）。physics 与有课那天同源，
      // 「下拉开着时冻结」的手感一致。
      return CustomScrollView(
        key: key,
        physics: _homePullVerticalPhysics,
        slivers: [
          // SliverFillRemaining 让空态仍占满视口（内部 Center 照旧居中），
          // 底距留在 child 的 Padding 上——与改动前"Expanded + Padding"的
          // 布局逐像素一致，坞避让那条既有断言（找 bottom = 8 + 药丸占用
          // 的 Padding）也照旧成立。
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 14, bottomContentInset),
              child: _buildDayViewEmptyColumn(week: week, settings: settings),
            ),
          ),
        ],
      );
    }
    // Gaussian cards sample the cached wallpaper bitmap while the day view
    // moves; the shared host keeps their BackdropFilter capture at grid scope.
    final agendaList = ListView.separated(
      key: PageStorageKey<String>('day-agenda-$week-$dayOfWeek'),
      padding: EdgeInsets.fromLTRB(14, 0, 14, bottomContentInset),
      // 下拉开着时冻结纵向滚动（见 _HomePullFreezeScrollPhysics）：
      // 回拉取消只收下拉，不把列表一起滚走。
      physics: _homePullVerticalPhysics,
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

  /// Day-view card surface honouring [TimetableSettings.courseCardSurfaceStyle]
  /// (falling back to solid whenever there is no wallpaper backdrop to blur).
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
    return CourseSurface(
      key: key,
      // Effective style: without a wallpaper or without the blur pipeline
      // (global solid / degraded) the gaussian look has no source to sample,
      // so every agenda card falls back to solid. 与顶部摘要卡**同源**
      // （[dayViewContentCardSurfaceStyle]）：日视图两种内容卡一个材质口径，
      // 见那里的说明。
      style: dayViewContentCardSurfaceStyle(
        settings,
        backdropBlurOn: HyperosBlurredHeader.backdropBlurEnabled(context),
      ),
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
    required DayCourseDisplayItem item,
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
            DayCourseWeatherRow(
              date: _dateForWeekDay(settings, week, item.course.dayOfWeek),
              startTime: item.course.startTime,
              endTime: item.course.endTime,
              ink: ink,
              // 天气是「那一天」的属性，只有这节课这一周真的要上才有意义。
              // 非本周的灰卡（单双周错位、还没开课）代表的那一天并不上课，挂上
              // 那天的天气会让人以为当天要带伞；对方课程则是在别的城市，拿本地
              // 天气同样不对。教师、地点是课程属性，与哪一周无关，照常显示。
              visible:
                  settings.weatherShowOnDayCard &&
                  !item.isPartnerCourse &&
                  item.course.isActiveInWeek(week),
              showPhenomenon: settings.weatherShowPhenomenon,
              showTemperature: settings.weatherShowTemperature,
              showProbability: settings.weatherShowProbability,
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
    required DayCourseDisplayItem item,
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
        effectiveCourseCardSurfaceStyle(
          settings,
          gaussianBlurAvailable: HyperosBlurredHeader.backdropBlurEnabled(
            context,
          ),
        ) ==
        CourseCardSurfaceStyle.solid
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
                  DayCourseWeatherRow(
                    date: _dateForWeekDay(
                      settings,
                      week,
                      item.course.dayOfWeek,
                    ),
                    startTime: item.course.startTime,
                    endTime: item.course.endTime,
                    ink: ink,
                    // 同普通课卡：这一周真的上才有天气。判据用 isActiveInWeek
                    // （= 不在停课周 且 在本周上课范围内），一处覆盖两种情况。
                    visible:
                        settings.weatherShowOnDayCard &&
                        !item.isPartnerCourse &&
                        item.course.isActiveInWeek(week),
                    showPhenomenon: settings.weatherShowPhenomenon,
                    showTemperature: settings.weatherShowTemperature,
                    showProbability: settings.weatherShowProbability,
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
        effectiveCourseCardSurfaceStyle(
          settings,
          gaussianBlurAvailable: HyperosBlurredHeader.backdropBlurEnabled(
            context,
          ),
        ) ==
        CourseCardSurfaceStyle.solid
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

  /// 日视图日程信息行。实现已提到 [DayAgendaInfoRow]（天气行要复用同一套排版），
  /// 这里保留同名同签名的转发，调用点不必改动。
  Widget _buildCurrentDayAgendaInfoRow({
    required IconData icon,
    required String text,
    required Color ink,
  }) {
    return DayAgendaInfoRow(icon: icon, text: text, ink: ink);
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
    final showsWallpaper =
        settings != null &&
        courseCardSurfaceShowsWallpaper(
          effectiveCourseCardSurfaceStyle(
            settings,
            gaussianBlurAvailable: HyperosBlurredHeader.backdropBlurEnabled(
              context,
            ),
          ),
        );
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
    final glassOverWallpaper = effectiveCourseCardSurfaceStyle(
      settings,
      gaussianBlurAvailable: HyperosBlurredHeader.backdropBlurEnabled(context),
    ).isGlass;
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
          height: 1,
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

  /// 周网格课卡上那一行天气；不该显示时返回 null（[CourseCard] 据此不加这一行）。
  ///
  /// 三道闸按「成本从低到高」排：先看开关与课程状态（纯内存判断），都过了才去
  /// 查预报摘要。判据与日视图完全一致：**天气是「那一天」的属性**，只有这节课
  /// 这一周真的要上才有意义；对方课程在别的城市，拿本地天气同样不对。
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
    return courseWeatherDisplayFor(
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
  }

  Widget _buildDayColumn(
    int week,
    int dayOfWeek,
    List<DayCourseDisplayItem> displayItems,
    TimetableSettings settings,
    bool showConflictBadge,
    double sectionHeight,
    double cardInset,
    TimetableProvider provider, {
    required int dayIndex,
    required int dayCount,
    // 本列（星期几）有课的节次全集，虚线框拉长时用它挡住跨越已有课程。
    required Set<(int, int)> occupiedSections,
  }) {
    final courseCards = <Widget>[];
    final gridLines = <Widget>[];

    final date = _dateForWeekDay(settings, week, dayOfWeek);
    final isDayHoliday = date != null && provider.isHoliday(date);

    // 可空查询：没挂天气 provider（大量既有测试、以及天气功能未启用的极端情形）
    // 时返回 null，周网格照常渲染、只是没有天气行。
    final weatherProvider = context.watch<WeatherProvider?>();
    final weatherL10n = AppLocalizations.of(context);

    // 虚线框：整列**只挂一个固定槽位**的 Positioned（top/height 随标记状
    // 态变），不与某个节次格绑定。原因：向上拉长会改 _emptySlotMarkerSection，
    // 若把框挂在"起始格"那个 Positioned 里，每次改起始格就等于把整棵标记子
    // 树挪到另一个父节点——旧 Element 被卸载，它手里那个正在拖拽的手势
    // 识别器随 dispose 注销掉路由，纵拖当场断箭（现象：向上只能拉一格，
    // 向下改的是末节次、框不挪窝所以能一直拉）。固定槽位后无论首尾怎么变，
    // 标记始终是同一个 Element。放在 courseCards 之前＝框永远在课程卡下面。
    final markerSpan = _emptySlotMarkerSpanAt(week, dayOfWeek);
    final markerStart = _emptySlotMarkerSection;
    gridLines.add(
      Positioned(
        key: const ValueKey('empty-slot-add-marker-slot'),
        top: markerSpan > 0 && markerStart != null
            ? (markerStart - 1) * sectionHeight
            : 0,
        left: 0,
        right: 0,
        height: markerSpan > 0 ? sectionHeight * markerSpan : 0,
        child: _buildEmptySlotCell(
          week,
          dayOfWeek,
          markerStart ?? 1,
          sectionHeight,
          cardInset,
          settings,
          span: markerSpan,
          occupiedSections: occupiedSections,
        ),
      ),
    );

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
              hasReminder:
                  date != null &&
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
              weather: _weekCardWeatherDisplay(
                l10n: weatherL10n,
                weather: weatherProvider,
                settings: settings,
                course: item.course,
                date: date,
                week: week,
                isPartnerCourse: item.isPartnerCourse,
              ),
              verticalAlign: settings.courseCardVerticalAlign,
              horizontalAlign: settings.courseCardHorizontalAlign,
              onTap: () {
                _clearEmptySlotMarker();
                _showCourseActions(item.course, week, displayItem: item);
              },
              compactTitleFontSize: settings.courseCardFontSize,
              compactSubtitleFontSize: (settings.courseCardFontSize - 1).clamp(
                7.0,
                14.0,
              ),
              compactVerticalPadding: sectionHeight < 64 ? 4 : 6,
              compactOuterInset: cardInset,
              // 无壁纸或模糊管线不可用（全局实体/系统降级）时统一实体卡
              // （高斯没有可采样背景）；有壁纸且管线可用才按设置。
              surfaceStyle: effectiveCourseCardSurfaceStyle(
                settings,
                gaussianBlurAvailable: HyperosBlurredHeader.backdropBlurEnabled(
                  context,
                ),
              ),
              // wallpaperLuminance 供玻璃档自动黑白判定；实体卡忽略。
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
  Widget _buildEmptySlotGestureArea({
    required TimetableSettings settings,
    required int week,
    required double sectionHeight,
    required double dayWidth,
    required List<int> visibleDays,
    required Set<(int, int)> occupiedSections,
    required Widget child,
  }) {
    if (!settings.longPressEmptySlotToAddCourseEnabled ||
        _shouldShowDayViewOverlay) {
      return child;
    }

    /// 指针局部坐标（相对本手势层 = 日列网格）→ 所在空白格（星期几,
    /// 节次）；越界或格子有课返回 null。
    (int, int)? cellAt(Offset localPosition) {
      if (localPosition.dx < 0 || localPosition.dy < 0) {
        return null;
      }
      final dayIndex = (localPosition.dx / dayWidth)
          .floor()
          .clamp(0, visibleDays.length - 1);
      final sectionIndex = (localPosition.dy / sectionHeight)
          .floor()
          .clamp(0, settings.sectionCount - 1);
      final dayOfWeek = visibleDays[dayIndex];
      final section = sectionIndex + 1;
      if (occupiedSections.contains((dayOfWeek, section))) {
        return null;
      }
      return (dayOfWeek, section);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (details) {
        final cell = cellAt(details.localPosition);
        if (cell == null) {
          return;
        }
        if (settings.enableHaptics) HapticFeedback.mediumImpact();
        _showEmptySlotMarker(week, cell.$1, cell.$2);
      },
      onLongPressMoveUpdate: (details) {
        final cell = cellAt(details.localPosition);
        if (cell == null ||
            (cell.$1 == _emptySlotMarkerDayOfWeek &&
                cell.$2 == _emptySlotMarkerSection)) {
          return;
        }
        if (settings.enableHaptics) HapticFeedback.selectionClick();
        _showEmptySlotMarker(week, cell.$1, cell.$2);
      },
      onTap: _clearEmptySlotMarker,
      child: child,
    );
  }

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
  Widget _buildEmptySlotCell(
    int week,
    int dayOfWeek,
    int startSection,
    double sectionHeight,
    double cardInset,
    TimetableSettings settings, {
    required int span,
    required Set<(int, int)> occupiedSections,
  }) {
    if (!settings.longPressEmptySlotToAddCourseEnabled || span <= 0) {
      return const SizedBox.shrink();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 虚线框墨色与时间轴数字同一套规则（用户自定义色 + 壁纸明暗自动黑白
    // 反转），避免硬编码白/黑在壁纸或深浅色反差下看不见。
    final markerInk = homePageOverWallpaperInk(
      configuredHex: isDark
          ? settings.timeAxisFontColorDark
          : settings.timeAxisFontColorLight,
      defaultHex: isDark
          ? TimetableSettings.defaultTimeAxisFontColorDark
          : TimetableSettings.defaultTimeAxisFontColorLight,
      themeFallback: isDark ? Colors.white : Colors.grey.shade800,
      hasBackdrop: hasHomePageBackdrop(settings),
      wallpaperLuminance: _wallpaperBodyLuminance ?? _wallpaperTopLuminance,
    );
    return _EmptySlotAddMarker(
      sectionHeight: sectionHeight,
      span: span,
      inset: cardInset + 2,
      ink: markerInk,
      onTap: () => _openAddCourseFromEmptySlot(
        week,
        dayOfWeek,
        startSection,
        startSection + span - 1,
      ),
      onResizeStart: _startEmptySlotResize,
      onResizeUpdate: (deltaDy) => _resizeEmptySlotMarker(
        deltaDy: deltaDy,
        sectionHeight: sectionHeight,
        dayOfWeek: dayOfWeek,
        sectionCount: settings.sectionCount,
        occupiedSections: occupiedSections,
        enableHaptics: settings.enableHaptics,
      ),
      onResizeEnd: _endEmptySlotResize,
    );
  }

  /// 虚线框在本列覆盖的节数：没有标记（或标记不在这一天/这一周）返回 0。
  int _emptySlotMarkerSpanAt(int week, int dayOfWeek) {
    if (_emptySlotMarkerWeek != week ||
        _emptySlotMarkerDayOfWeek != dayOfWeek) {
      return 0;
    }
    final start = _emptySlotMarkerSection;
    if (start == null) {
      return 0;
    }
    final end = _emptySlotMarkerEndSection ?? start;
    return end >= start ? end - start + 1 : 0;
  }

  void _showEmptySlotMarker(int week, int dayOfWeek, int section) {
    setState(() {
      _emptySlotMarkerWeek = week;
      _emptySlotMarkerDayOfWeek = dayOfWeek;
      _emptySlotMarkerSection = section;
      _emptySlotMarkerEndSection = section;
      _endEmptySlotResize();
    });
  }

  void _clearEmptySlotMarker() {
    if (_emptySlotMarkerWeek == null &&
        _emptySlotMarkerDayOfWeek == null &&
        _emptySlotMarkerSection == null) {
      return;
    }
    setState(() {
      _emptySlotMarkerWeek = null;
      _emptySlotMarkerDayOfWeek = null;
      _emptySlotMarkerSection = null;
      _emptySlotMarkerEndSection = null;
      _endEmptySlotResize();
    });
  }

  /// 按下虚线框上/下边缘（[isTopEdge]）时锚定本次缩放的基准框。
  void _startEmptySlotResize(bool isTopEdge) {
    final start = _emptySlotMarkerSection;
    if (start == null) {
      return;
    }
    _emptySlotResizeIsTopEdge = isTopEdge;
    _emptySlotResizeBaseStart = start;
    _emptySlotResizeBaseEnd = _emptySlotMarkerEndSection ?? start;
    _emptySlotResizeAccum = 0;
  }

  void _endEmptySlotResize() {
    _emptySlotResizeBaseStart = null;
    _emptySlotResizeBaseEnd = null;
    _emptySlotResizeAccum = 0;
  }

  /// 拖上/下边缘时按手指位移把虚线框拉长或缩短。
  ///
  /// 位移换算成节数后还要过两道闸：① 不越出第 1 节 ~ 第 [sectionCount] 节，
  /// 且首尾不得交叉（框至少占一节）；② 新纳入的节次不能有课（[occupiedSections]），
  /// 遇到第一节有课的格子就停在它前面——收缩方向永远放开。
  void _resizeEmptySlotMarker({
    required double deltaDy,
    required double sectionHeight,
    required int dayOfWeek,
    required int sectionCount,
    required Set<(int, int)> occupiedSections,
    required bool enableHaptics,
  }) {
    final baseStart = _emptySlotResizeBaseStart;
    final baseEnd = _emptySlotResizeBaseEnd;
    if (baseStart == null || baseEnd == null) {
      return;
    }
    _emptySlotResizeAccum += deltaDy;
    final delta = (_emptySlotResizeAccum / sectionHeight).round();
    var newStart = baseStart;
    var newEnd = baseEnd;
    if (_emptySlotResizeIsTopEdge) {
      newStart = (baseStart + delta).clamp(1, baseEnd);
      for (var s = baseStart - 1; s >= newStart; s--) {
        if (occupiedSections.contains((dayOfWeek, s))) {
          newStart = s + 1;
          break;
        }
      }
    } else {
      newEnd = (baseEnd + delta).clamp(baseStart, sectionCount);
      for (var s = baseEnd + 1; s <= newEnd; s++) {
        if (occupiedSections.contains((dayOfWeek, s))) {
          newEnd = s - 1;
          break;
        }
      }
    }
    if (newStart == _emptySlotMarkerSection &&
        newEnd == _emptySlotMarkerEndSection) {
      return;
    }
    setState(() {
      _emptySlotMarkerSection = newStart;
      _emptySlotMarkerEndSection = newEnd;
    });
    if (enableHaptics) HapticFeedback.selectionClick();
  }

  /// 从虚线加号态进入添加课程表单：位置三要素全部预填（节次范围 = 虚线框
  /// 覆盖的范围），落库复用 [TimetableProvider.addCourse] 现有链路。
  Future<void> _openAddCourseFromEmptySlot(
    int week,
    int dayOfWeek,
    int startSection,
    int endSection,
  ) async {
    _clearEmptySlotMarker();
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

  List<DayCourseDisplayItem> _buildHomeDayDisplayItems({
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

  List<DayCourseDisplayItem> _buildCoupleDayCourseDisplayItems({
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
    final items = <DayCourseDisplayItem>[];

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
        DayCourseDisplayItem(
          course: course,
          isCurrentWeekCourse: isCurrentWeekCourse,
          isConflicting: conflictMap.containsKey(course.id),
          isCurrentCourse: currentCourseIds.contains(course.id),
          opacity: courseDisplayOpacity(
            isCurrentWeekCourse: isCurrentWeekCourse,
            isConflicting: conflictMap.containsKey(course.id),
            conflictOpacity: settings.timetableConflictCourseOpacity,
          ),
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
        DayCourseDisplayItem(
          course: course,
          isCurrentWeekCourse: isCurrentWeekCourse,
          opacity: isCurrentWeekCourse ? 1 : kNonCurrentWeekCourseOpacity,
          coupleKind: CoupleCourseKind.partner,
          isPartnerCourse: true,
        ),
      );
    }

    return items..sort(compareDayCourseDisplayItems);
  }

  List<DayCourseDisplayItem> _buildDayCourseDisplayItems({
    required List<Course> courses,
    required int week,
    required TimetableSettings settings,
    required Map<String, List<Course>> conflictMap,
    Set<String> currentCourseIds = const <String>{},
  }) {
    return buildDayCourseDisplayItems(
      courses: courses,
      week: week,
      settings: settings,
      conflictMap: conflictMap,
      currentCourseIds: currentCourseIds,
    );
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

  bool _hasCurrentWeekOverlap(List<Course> courses, Course target, int week) {
    return hasCurrentWeekOverlap(courses, target, week);
  }

  bool _isPreferredNonCurrentCourse(
    List<Course> courses,
    Course target,
    int week,
  ) {
    return isPreferredNonCurrentCourse(courses, target, week);
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
  /// 玻璃坞当前应使用的材质。
  ///
  /// 由**全局材质**（外观编辑 → 材质）+ 「作用范围 → 玻璃坞导航」推导：
  ///
  /// - 实体卡片（模糊总开关关）→ [_DockMaterial.solid]；
  /// - 高斯模糊 → [_DockMaterial.frosted]；
  /// - 液态玻璃 + 作用范围开 → [_DockMaterial.liquid]；
  /// - 液态玻璃但该家族作用范围关（或系统降级）→ [_DockMaterial.solid]。
  ///
  /// 底栏不再有独立的「底栏材质」开关：同一份默认材质驱动所有表面，用户
  /// 不必在两个地方对齐同一种玻璃（历史上「全局高斯 + 底栏液态」这类组合
  /// 就是把开关拆到两处造成的）。
  /// 高级材质关闭时统一走实体卡片而非降低一档高斯：高斯的实时
  /// BackdropFilter 在坞的滑入/合并动画期间采不到稳定背景，药丸会整段
  /// 透明（见 [LiquidGlassDegradation.familyFallsBackToSolid]）。
  _DockMaterial _resolveDockMaterial(BuildContext context) {
    final appearance = FrostedAppearanceScope.of(context);
    final familySolid = LiquidGlassDegradation.familyFallsBackToSolid(
      context,
      advancedFamilyEnabled: appearance.liquidGlassDockEnabled,
    );
    if (isAdvancedGlassMode(appearance.glassMode) && !familySolid) {
      return _DockMaterial.liquid;
    }
    return HyperosBlurredHeader.backdropBlurEnabled(context)
        ? _DockMaterial.frosted
        : _DockMaterial.solid;
  }

  /// 经典形态直接返回原内容，行为与之前完全一致。
  /// 玻璃坞（药丸 + 右侧独立圆钮）那一层的内容。
  ///
  /// ⚠️ **必须画在采样宿主之外** —— 由 [_wrapHomeWithTopMenu] 摆到宿主之外，与
  /// 顶栏那两颗常驻玻璃球同一条规则。坞层原来长在宿主子树的末尾，于是每次录帧
  /// 都把坞层自己的画面烘进采样快照，坞层再拿这张"含自己"的图去算材质：展开 /
  /// 收起内嵌页那几帧里，圆钮的明暗会来回颤几下才收敛（真机反馈：「圆钮展开
  /// 收起之后闪」）。同一机制在 `stable_frosted_surface.dart` 的类注释里有
  /// 完整说明 —— 那条偏差的修法就是"把玻璃移到捕获之外"，这里是其中一块。
  ///
  /// 浮钮与药丸显式同源材质：两者都由同一份全局材质推导
  /// （[_resolveDockMaterial]），避免出现圆钮与药丸两种玻璃的断层。
  /// 三条材质路径共用同一份采样与稳定背景口径（见 `StableFrostedSurface`）。
  Widget _buildGlassDockLayer({
    required TimetableSettings settings,
    required AppLocalizations l10n,
  }) {
    // 圆钮与药丸由**同一个** [_resolveDockMaterial] 分派，材质天然同源
    // （见 [_dockRoundSurface]），不必再各解析一份参数。
    final dockMaterial = _resolveDockMaterial(context);
    // 内嵌页表态只看主题，不跟着壁纸亮度走。
    final lum = _dockInlinePageId != null
        ? null
        : _wallpaperBodyLuminance;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    // 通用底栏墨色判据（chrome 阈值 0.45）。
    // 实体卡片档的药丸/圆钮是不透明**主题色**面（浅色主题≈纯白），
    // 墨色极性必须跟主题走；半透明材质（液态/磨砂）的面 =
    // 壁纸 + 玻璃，继续按壁纸亮度判——否则浅色主题 + 暗壁纸会
    // 出现白底白字。
    final inkIsLight = dockMaterial == _DockMaterial.solid
        ? isDarkTheme
        : (lum != null ? lum < 0.45 : isDarkTheme);
    final ink = inkIsLight
        ? Colors.white.withValues(alpha: 0.9)
        : Colors.black.withValues(alpha: 0.75);
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Align(
        alignment: Alignment.bottomCenter,
        // 官方 iOS 26 形态：居中药丸 + 右侧独立圆钮，整组居中。
        // 圆钮固定展开（加课程唯一主动入口，不再随页收起）；
        // 材质经 dockBtnSettings 与药丸显式同源。
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 272),
              child: _buildGlassDockBar(settings: settings, l10n: l10n),
            ),
            if (settings.glassDockShowAddButton) ...[
              const SizedBox(width: 8),
              _buildDockMergeSlot(
                ink: ink,
                l10n: l10n,
                material: dockMaterial,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 玻璃坞底部导航：周课表 / 日课表 / 设置。
  ///
  /// 四种材质共用同一套底栏实现（[SoftGlassTabBar]：浮动药丸 + 拖拽指示器 +
  /// 弹簧动画），材质差异只由注入的 `surfaceBuilder` 决定（见
  /// [_dockPillSurface]）。
  Widget _buildGlassDockBar({
    required TimetableSettings settings,
    required AppLocalizations l10n,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final appearance = FrostedAppearanceScope.of(context);
    final dockMaterial = _resolveDockMaterial(context);
    // 底栏文字极性分派：课表态跟随壁纸亮度（表面 = 壁纸 + 白玻璃）；
    // 内嵌页表态底栏浮在纯色页面上，只看主题——否则白底设置页会沿用
    // 暗壁纸的浅色墨，白字看不见（自动反色失效的根因）。
    // 实体卡片档例外：药丸是不透明主题色面（浅色主题≈纯白），墨色必须
    // 跟主题走，按壁纸亮度翻白会在暗壁纸上得到白底白字。
    final wallpaperLuminance = _dockInlinePageId != null
        ? null
        : _wallpaperBodyLuminance;
    final barUsesLightInk = dockMaterial == _DockMaterial.solid
        ? isDark
        : (wallpaperLuminance != null
              ? wallpaperLuminance < 0.45
              : isDark);
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
    // 底栏材质：由**全局材质** + 「作用范围 → 玻璃坞导航」推导
    // （[_resolveDockMaterial]，函数开头已解析），与弹窗 / 顶部 / 卡片同一份
    // 材质，不再有独立的「底栏材质」开关。
    // 实体药丸的底：与主题卡面同色、不含模糊。
    final solidDockFill = HyperosColors.surfaceContainer(context);
    // 动态入口列表：底栏最多 5 槽，用户在「首页与导航」自由编排
    // （'day'/'week' 视图动作 + 目录任意条目，含设置页）。
    final dockIds = resolveGlassDockActionIds(settings);
    // 玻璃药丸的布局与极性：
    //
    // 布局用 Stacked（图标上、文字下）：5 槽 + maxWidth 272 时 Horizontal
    // 会把「日课表」挤成一个字。极性阈值只给底栏药丸自己用（决定它的
    // 亮暗与指示器配色）：仅明确暗壁纸才用深灰玻璃，中等亮度壁纸走
    // 乳白+黑墨（截图里浅橄榄壁纸配黑玻璃像一块塑料），故阈值取 0.35
    // 而非通用 chrome 的 0.45。
    final dockGlassDark = wallpaperLuminance != null
        ? wallpaperLuminance < _kDockGlassDarkLuminance
        : isDark;
    final barSelectedInk = selectedColor;
    final barUnselectedInk = unselectedColor;

    // 四种材质共用同一套底栏实现（[SoftGlassTabBar]：拖拽切换、弹簧指示器、
    // 速度拉伸），只有「底」不同——见 [_dockPillSurface]。
    return SoftGlassTabBar(
      tabs: [
        for (final id in dockIds)
          SoftGlassTab(
            icon: Icon(glassDockActionIcon(id)),
            label: glassDockActionLabel(l10n, id),
          ),
      ],
      selectedIndex: _dockSelectedIndex(dockIds),
      onTabSelected: (index) => _handleDockTap(dockIds[index], settings),
      selectedColor: barSelectedInk,
      unselectedColor: barUnselectedInk,
      iconSize: 22,
      blurEnabled: appearance.blurEnabled,
      polarity: dockGlassDark
          ? SoftGlassPolarity.dark
          : SoftGlassPolarity.light,
      surfaceBuilder: (child) => _dockPillSurface(
        material: dockMaterial,
        solidFill: solidDockFill,
        child: child,
      ),
    );
  }

  /// 药丸底材质分派（三种材质共用同一套底栏实现，见 [_buildGlassDockBar]）。
  Widget _dockPillSurface({
    required _DockMaterial material,
    required Color solidFill,
    required Widget child,
  }) {
    const radius = SoftGlassTokens.barHeight / 2;
    return switch (material) {
      _DockMaterial.liquid => LiquidGlassSurface(
        borderRadius: radius,
        // 实时采样（不跟祖先组）：坞层被 [_wrapHomeWithTopMenu] 摆在采样宿主
        // **之外**，拿不到 `homeStack` 那个 `BackdropGroup` —— 原先这里的
        // `grouped: true` 一直是**空转**，观感全靠实时采样（用户口径：药丸的
        // 折射会跟着下面内容变，最好看）。这里不再写它，把"要实时采样"写实：
        // 一旦将来坞层被包进某个组，`true` 会静默把它变成一块壁纸快照底
        // （2026-09-20 两颗悬浮钮踩的就是这个坑）。
        fallbackBuilder: (_) => _frostedDockSurface(radius: radius, child: child),
        child: child,
      ),
      _DockMaterial.frosted => _frostedDockSurface(
        radius: radius,
        child: child,
      ),
      // 实体卡片：不透明主题色面，不含模糊。
      _DockMaterial.solid => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: ColoredBox(color: solidFill, child: child),
      ),
    };
  }

  /// 磨砂底（高斯药丸 / 圆钮共用）：blur 与 tint 都从 scope 出，与弹窗 frosted
  /// 档同参。也是液态玻璃不可用时的回落——仍是玻璃观感，不会突然变实底。
  Widget _frostedDockSurface({
    required double radius,
    required Widget child,
  }) {
    final appearance = FrostedAppearanceScope.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: FrostedHeaderBackground(
        blurEnabled: appearance.blurEnabled,
        blurSigma: appearance.sheetBlurSigma,
        tint: HyperosBlurredHeader.sheetTintColor(context, withBlur: true),
        child: child,
      ),
    );
  }

  /// 独立圆钮：与药丸**同一份材质**的 56 正圆（材质由同一个
  /// [_resolveDockMaterial] 推出，见 [_dockPillSurface]）。
  ///
  /// 历史包袱（勿重犯）：这里曾经走第三方包自己的按钮组件，坞层树外没有它的
  /// 玻璃层祖先时会退化成一块实色圆片，与药丸成为两种材质。现在两条都由本仓的
  /// [LiquidGlassSurface] / 磨砂底渲染，天然同源。
  Widget _buildDockMergeSlot({
    required Color ink,
    required AppLocalizations l10n,
    required _DockMaterial material,
  }) {
    final icon = _roundButtonIcon(context.read<TimetableProvider>().settings);
    void onTap() =>
        _handleRoundButtonTap(context.read<TimetableProvider>().settings);
    final label = l10n.glassDockExtraButtonSemanticLabel;
    // 56 正圆。
    const radius = 28.0;
    final body = Center(
      child: IconTheme.merge(
        data: IconThemeData(color: ink, size: 22),
        child: icon,
      ),
    );
    return SizedBox(
      width: 56,
      height: 56,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: switch (material) {
              _DockMaterial.liquid => LiquidGlassSurface(
                borderRadius: radius,
                // 实时采样，理由同 [_dockPillSurface]（坞层在采样宿主之外）。
                fallbackBuilder: (_) =>
                    _frostedDockSurface(radius: radius, child: body),
                child: body,
              ),
              _DockMaterial.frosted => _frostedDockSurface(
                radius: radius,
                child: body,
              ),
              // 实体卡片：不透明主题色面，不含模糊。
              _DockMaterial.solid => ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: ColoredBox(
                  color: HyperosColors.surfaceContainer(context),
                  child: body,
                ),
              ),
            },
          ),
        ),
      ),
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

  /// 圆钮点击分发：addCourse/空走添加弹层；内嵌注册页在首页栈内
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
          unawaited(entry.open(context));
        }
    }
  }

  /// 「回本周」浮钮的高度（逻辑 px）：图标 15 与字号 11 取大者，加纵向内边距 8×2。
  ///
  /// 与 [_backToTodayButtonHeight] 一样，这个常量是**高度本身**（显式 `SizedBox`），
  /// 不是对内容尺寸的旁注 —— 窄件几何适配（见 [narrowSurfaceMaxRefraction]）要按
  /// 它算折射位移上限，改内边距 / 图标尺寸时这里跟着改，两处不会走偏。
  static const double _backToCurrentWeekButtonHeight = 31;

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

    // 按钮内容（图标 + 文字）。液态 / 磨砂两条材质分支共用它，只有「底」不同
    // ——以前两条分支各写一份内容，改一处文字要改两遍。
    // 透明度整体压在内容层：不能包住整块玻璃，否则 BackdropFilter 采不到后面
    // 的内容（见下方那条注释）。
    Widget chipBody() => Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: const ValueKey('back-to-current-week-button'),
        onTap: () => _jumpToCurrentWeek(provider),
        borderRadius: borderRadius,
        child: Opacity(
          opacity: contentOpacity,
          // 高度显式钉住（= 图标 15 + 内边距 8×2，与内容撑出来的值逐像素相同），
          // 这样窄件几何适配能按常量算，不用去猜内容尺寸。
          child: SizedBox(
            height: _backToCurrentWeekButtonHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
    );

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
      minimum: EdgeInsets.only(right: 20, bottom: dockBackButtonBottom),
      child: Align(
        alignment: Alignment.bottomRight,
        child: Tooltip(
          message: l10n.backToCurrentWeekAction,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              // ⚠️ 液态档不叠描边与投影，理由与「回今日」同一处（那颗钮的注释里
              // 有量出来的数字：描边 + 玻璃的折射带在小胶囊上读成两层圈圈），
              // 见 [_buildFloatingBackToTodayButton]。磨砂档留着 —— 磨砂片自己
              // 不画边。透明度仍按 [contentOpacity] 压在描边上（非液态档才有）。
              border: useLiquidGlassMaterial
                  ? null
                  : Border.all(
                      color: foruiColors.border.withValues(
                        alpha: foruiColors.border.a * contentOpacity,
                      ),
                    ),
              boxShadow: useLiquidGlassMaterial
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha:
                              (theme.brightness == Brightness.dark
                                   ? 0.12
                                   : 0.06) *
                              contentOpacity,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: useLiquidGlassMaterial
                ? LiquidGlassSurface(
                    borderRadius: borderRadius.topLeft.x,
                    // ⚠️ 不跟祖先组采样：组采样拿到的是壁纸快照，背景会变成一块
                    // 逐帧不变、不反映下方内容的底（与「回今日」同一处境，见
                    // [_buildFloatingBackToTodayButton]）。悬浮钮要的是实时采样。
                    //
                    // 窄件几何适配：这颗钮只有 31dp 高，折射作用带占了 47%，不压会
                    // 读成一整圈轮廓（见 [narrowSurfaceMaxRefraction]）。
                    maxRefraction: narrowSurfaceMaxRefraction(
                      _backToCurrentWeekButtonHeight,
                    ),
                    fallbackBuilder: (_) => ClipRRect(
                      borderRadius: borderRadius,
                      child: HyperosFrostedSurface(
                        borderRadius: borderRadius,
                        tint: frostedTint,
                        child: chipBody(),
                      ),
                    ),
                    child: chipBody(),
                  )
                : ClipRRect(
                    borderRadius: borderRadius,
                    child: HyperosFrostedSurface(
                      borderRadius: borderRadius,
                      tint: frostedTint,
                      child: chipBody(),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  /// 日视图底部「回今日」悬浮按钮的几何常量。
  ///
  /// 形状与底栏药丸同族（胶囊，圆角 = 半高），但**比底栏矮一档、窄一圈**：
  /// 高度取底栏 `barHeight: 56` 的约 2/3（38），左右内边距 16，而不是让
  /// 文字悬在大片留白里。高度即成品高度（外层描边画在边界内、不占布局，
  /// 与 `Container` 的行为不同）。
  ///
  /// 列表底部余量（[_backToTodayButtonScrollInset]）与按钮本体共用这些
  /// 常量，避免两边各自写死数字后走偏（钮变高、内容又被遮）。
  static const double _backToTodayButtonHeight = 38;
  static const double _backToTodayButtonRadius = _backToTodayButtonHeight / 2;
  static const double _backToTodayButtonHPadding = 16;
  static const double _backToTodayButtonFontSize = 14;
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
        _backToTodayButtonHeight;
    return math.max(
      0,
      buttonTop +
          _backToTodayButtonGap -
          _glassDockContentScrollInset(provider.settings),
    );
  }

  /// 日视图底部居中的「回今日」浮钮：与底栏同族的胶囊形状、玻璃底 +
  /// **主题色**文字，只有文案没有箭头。
  ///
  /// 配色走全 app 的主题色口径：底色是玻璃，所以"跟随主题色"落在文字上，
  /// 取 [HyperosColors.primary]——即外观里选的 seed 本身（所见即所得），
  /// 未挂 ThemeSeedScope 或深色近黑 seed 时由它自己回落。
  ///
  /// 材质沿用全 app 的玻璃口径（同一份 [FrostedAppearanceScope] 与
  /// [LiquidGlassSurface]），但**不复用**「回本周」那颗的实现：位置
  /// （居中 vs 右下）、文案、动作、可见性条件、配色都不同，两边分开演进。
  Widget _buildFloatingBackToTodayButton(TimetableProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final foruiColors = context.theme.colors;
    final accent = HyperosColors.primary(context);
    final borderRadius = BorderRadius.circular(_backToTodayButtonRadius);
    final dockAppearance = FrostedAppearanceScope.of(context);
    final useLiquidGlassMaterial =
        dockAppearance.glassMode == FrostedGlassMode.liquidGlass &&
        dockAppearance.liquidGlassDockEnabled &&
        !LiquidGlassDegradation.shouldDegrade(context);
    final useBlur = HyperosBlurredHeader.backdropBlurEnabled(context);
    final tint = HyperosBlurredHeader.homePageRegionTintColor(
      context,
      withBlur: useBlur,
    );
    final content = SizedBox(
      // 与底栏药丸同高。外层 DecoratedBox 的 1dp 描边是**画在边界内**的
      // （与 Container 不同，不占布局），所以内容高度就是成品高度。
      height: _backToTodayButtonHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _backToTodayButtonHPadding,
        ),
        // 宽度只让文字撑开（Row 取 min，别用 Center/Align —— 它们会把
        // 可用宽度吃满，胶囊就变成横贯屏幕的一条）。
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.backToTodayAction,
              style: TextStyle(
                fontSize: _backToTodayButtonFontSize,
                fontWeight: FontWeight.w700,
                color: accent,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
    // 磨砂底：既是磨砂档本身，也是液态玻璃不可用时的回落（仍是玻璃观感）。
    Widget frostedChip() => ClipRRect(
      borderRadius: borderRadius,
      child: HyperosFrostedSurface(
        borderRadius: borderRadius,
        tint: tint,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => unawaited(_navigateDayViewToToday(provider)),
            borderRadius: borderRadius,
            child: content,
          ),
        ),
      ),
    );
    final surface = useLiquidGlassMaterial
        ? LiquidGlassSurface(
            borderRadius: _backToTodayButtonRadius,
            // ⚠️ **不跟祖先组采样**（2026-09-20 用户拍板「对齐药丸实时采样」）。
            //
            // 跟组采样时，采样源是组里那张**壁纸快照**（`UndimmedBackdropCapture`
            // 画在页面主体之前，见 `homeStack`），快照的屏幕位置固定 ⇒ 这颗钮的
            // 背景逐帧一模一样，下面课表怎么滚都不变（用户口径「背景永远都是不
            // 变的」）。底栏药丸看着"会变"是因为它在组**外**（坞层被
            // [_wrapHomeWithTopMenu] 摆成采样宿主的兄弟），它那句 `grouped: true`
            // 一直是空转 —— 所以这里显式不给，走实时采样，与药丸的真实行为对齐。
            //
            // 窄件几何适配：这颗钮只有 38dp 高，而折射位移的作用带是绝对值
            // （标准档 14.5dp = 高度的 38%，药丸/圆钮 56dp 上只占 26%），上下两条
            // 带会连成一整圈轮廓。与设置页那条约 40dp 的星期条同一条规矩，见
            // [narrowSurfaceMaxRefraction]。
            maxRefraction: narrowSurfaceMaxRefraction(_backToTodayButtonHeight),
            fallbackBuilder: (_) => frostedChip(),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => unawaited(_navigateDayViewToToday(provider)),
                borderRadius: borderRadius,
                child: content,
              ),
            ),
          )
        : frostedChip();
    return SafeArea(
      minimum: EdgeInsets.only(
        bottom: _backToTodayButtonBottomInset(provider.settings),
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: DecoratedBox(
          // 键挂在这层**外壳**上，两种材质分支（液态 / 磨砂）都能被找到、点到；
          // 挂在分支内部的 InkWell 上时，液态档就没有键了。液态档这层只留圆角
          // （不再描边，见下）。
          key: const ValueKey('back-to-today-button'),
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            // ⚠️ **液态档不叠描边与投影**（2026-09-20 用户拍板）。
            //
            // 同族的底栏药丸 / 坞内圆钮都不画描边，只有玻璃自己的边光。这颗钮
            // 原先两条分支共用一层 1dp 描边，于是小胶囊上出现**两层圈圈**：
            // 外圈 = 这层描边（量出来正好是 1dp 硬线），内圈 = 玻璃的折射/色散带
            // （作用带 14.5dp，占这颗钮高度的 38%），两者相距约 5dp。用户对照的
            // 底栏药丸 / 加课圆钮只有一圈 —— 差的正是这层描边。
            //
            // 磨砂档**必须留着**：`HyperosFrostedSurface` 只是一层模糊 + 水洗，
            // 自己不画边，去掉描边这颗钮就没边界了。
            border: useLiquidGlassMaterial
                ? null
                : Border.all(color: foruiColors.border),
            boxShadow: useLiquidGlassMaterial
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: brightness == Brightness.dark ? 0.12 : 0.06,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: surface,
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
    _clearEmptySlotMarker();
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
    DayCourseDisplayItem? displayItem,
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
            ? localizeServiceMessage(l10n, error.message!.toString())
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
            ? localizeServiceMessage(l10n, error.message!.toString())
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
    final hasBackdrop = hasHomePageBackdrop(settings);
    // Same wallpaper auto-contrast as weekday ink; a custom time-axis hex
    // keeps its hue and only gets its lightness pushed. The time column spans
    // the body band (not the status/title strip), so judge from the
    // card-region sample.
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

  /// 首页主体 + 顶栏「更多」弹层。
  ///
  /// 首页整屏都包在 [HyperosGlassBackdropHost] 里：玻璃坞 / 首页玻璃带 / 分区
  /// 玻璃 / 弹层都从它取的采样源渲染 OS4 玻璃；宿主同时注册进
  /// [HyperosGlassBackdropRegistry]，于是压在首页之上的 sheet / dialog 里的玻璃
  /// 也能采到首页画面（modal 路由看不到首页的 InheritedWidget）。
  ///
  /// 弹层放在宿主**之外**：宿主捕获的是「弹层之下的页面」，正是上游玻璃材质要
  /// 采样的背景，捕获子树不能含玻璃自身（防反馈采样）。弹层内部经 OverlayPortal
  /// 渲染到 Overlay，所以这里的次序只影响它继承到的主题。
  Widget _wrapHomeWithTopMenu(
    Widget content, {
    required TimetableSettings settings,
    required List<Widget> chromeBalls,
    required Color chromeDotBorderColor,
    Widget? dockLayer,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        HyperosGlassBackdropHost(controller: _homeGlass, child: content),
        // ⚠️ 玻璃坞（药丸 + 圆钮）同样画在宿主**之外** —— 与下面那两颗常驻球
        // 同一条规则，理由也一样：宿主捕获的是"玻璃之下的页面"，捕获子树不能含
        // 玻璃自身。坞层原先长在宿主子树末尾，于是每次录帧都把它自己的画面烘进
        // 快照，坞层再拿这张"含自己"的图算材质 —— 展开 / 收起内嵌页那几帧里
        // 圆钮的明暗会颤几下才收敛（真机反馈：「圆钮展开收起之后闪」）。
        //
        // ⚠️ 必须同时用 [HyperosGlassBackdropScope] 把坞层钉在本屏采样源上：
        // 它在宿主之外拿不到宿主下发的 scope，只能靠全局注册表"栈顶"取采样源，
        // 而栈顶会随 push / pop 换人（与常驻球完全同一处境，见下面的说明）。
        if (dockLayer != null)
          Positioned.fill(
            child: HyperosGlassBackdropScope(
              controller: _homeGlass,
              child: dockLayer,
            ),
          ),
        // 常驻玻璃球画在宿主**之外**（不自采样，见 build 里 homeChromeBalls
        // 的说明）；整屏 IgnorePointer 让点击穿透到下面的真实按钮。
        //
        // ⚠️ 必须同时用 [HyperosGlassBackdropScope] **把球钉在本屏采样源上**：
        // 球在宿主之外，拿不到宿主下发的 scope，只能靠全局注册表"栈顶"取采样源
        // —— 而栈顶会随 push / pop 换人（设置页自己的采样源会顶上来），页面回来
        // 后球还绑在别人的（已释放的）采样源上，就只剩半套材质、另一半回落实底
        // （真机反馈："进设置再回来，爱心变成一半一半透明的、一半是实底"）。
        // 与页内玻璃同一个口径：**本屏的玻璃只采本屏的画面**。
        if (chromeBalls.isNotEmpty)
          Positioned.fill(
            child: HyperosGlassBackdropScope(
              controller: _homeGlass,
              child: IgnorePointer(
                child: Stack(children: chromeBalls),
              ),
            ),
          ),
        // ⚠️ 菜单的动画必须**不受"本页是否在前台"影响**：`Overlay` 会给被不透明
        // 路由盖住、但仍 `maintainState` 的那一层整体加 `TickerMode(enabled:
        // false)`（`overlay.dart` 的 `_Theater` 构建），而菜单的动画计时器挂在
        // 本页子树下 —— 于是"点菜单项 → 关菜单 + 跳新页面"同时发生时，收起动画
        // 会被当场静音、**卡在半透明状态**（真机反馈："跳转前那一刻菜单变成
        // 透明的"）。菜单是浮层级的瞬时动画，显式放开 TickerMode。
        TickerMode(
          enabled: true,
          child: HomeTopMenuPopup(
            show: _homeMenuOpen,
            backdrop: _homeGlass.backdrop,
            anchor: _homeMenuAnchor,
            // 形变动效要从按钮位置长出来，故传入按钮内容的**副本**（不含
            // GlobalKey，避免与真实按钮抢同一个 key）：与常驻球**共用同一份**
            // 可见内容（[_buildMoreActionIcon]，含更新红点与同一墨色）。
            //
            // ⚠️ 两者不能有差异：早先这里只给了一个裸图标，红点只画在常驻球上，
            // 于是关闭菜单交接的那一瞬"红点突然出现 + 整颗球跟着重绘一次"，
            // 读起来就是圆按钮闪一下（2026-09-14 真机反馈，仅在有待更新时可见）。
            anchorContent: _buildMoreActionIcon(
              dotBorderColor: chromeDotBorderColor,
            ),
            entries: resolveHomeGridMenuEntries(settings),
            hasAvailableUpdate: _hasAvailableUpdate,
            onDismissRequest: _closeHomeMenuNow,
            onSelected: _dispatchTopMenuSelection,
          ),
        ),
      ],
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

  /// 菜单正在等"新路由盖满首页"的那个定时器（见 [_requestCloseHomeMenu]）。
  Timer? _homeMenuCloseDelay;

  /// 请收首页菜单：**有新路由正在盖上来**时先留着，等它盖满再收；否则立刻收。
  ///
  /// 为什么不能当场收：列表态菜单是浮在首页之上的一层（上游 `OverlayPortal`
  /// 的绘制顺序保证新路由压在菜单之上 —— `overlay.dart` 的 `_TheaterParentData`
  /// 注释原话是"portal 子节点画在所属 entry 之后、下一条 entry 之前，而下一条
  /// entry 可能正是该挡住它的 `ModalRoute`"）。菜单先收掉、新路由又还没铺满，
  /// 中间那一两帧就会露出首页顶栏 —— 圆形按钮与爱心球在那两帧里冒出来闪一下
  /// （真机 2026-09-15 反馈）。等盖满再收，收起动作用户根本看不到。
  ///
  /// 判定分两半：
  /// - **有没有跳页**：看首页那条路由还是不是栈顶（[Route.isCurrent]）。判定推到
  ///   下一帧做 —— push 本身是同步的，但 `isCurrent` 实测要到下一帧才翻假。
  ///   首页还是栈顶 = 这项没跳页（开关、只弹 toast）→ 照旧立刻收。
  /// - **盖没盖满**：按转场时长等（与路由用的是同一个口径）。**不能**等首页的
  ///   `secondaryAnimation`：首页走的是系统默认页路由（MaterialApp 的 home），
  ///   被推上来的是本仓库的 HyperosPageRoute；系统默认路由的 canTransitionTo
  ///   只认自家过渡混入（`page.dart:162`），于是首页的次级动画根本不会动
  ///   （实测恒为 dismissed）—— 这条路上等它等于永远不收菜单。
  void _requestCloseHomeMenu() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _decideCloseHomeMenu();
      }
    });
  }

  void _decideCloseHomeMenu() {
    if (!mounted || !_homeMenuOpen) {
      return;
    }
    if (ModalRoute.of(context)?.isCurrent ?? true) {
      _closeHomeMenuNow();
      return;
    }
    // 新路由正在盖上来：等它铺满整屏再收。多给 3 帧余量，宁可晚收（晚收看不见）
    // 也别早收（早收就露出顶栏那两颗球）。
    _homeMenuCloseDelay?.cancel();
    _homeMenuCloseDelay = Timer(
      HyperosNavigation.transitionDuration + const Duration(milliseconds: 48),
      () {
        _homeMenuCloseDelay = null;
        if (mounted) {
          _closeHomeMenuNow();
        }
      },
    );
  }

  /// 立刻收起首页菜单（遮罩点击 / 返回键 / 判定"这一项不跳页"）。
  void _closeHomeMenuNow() {
    _homeMenuCloseDelay?.cancel();
    _homeMenuCloseDelay = null;
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
      hasAvailableUpdate: _hasAvailableUpdate,
      entries: resolveHomeGridMenuEntries(settings),
      themeSeedHex: settings.themeSeedColor,
    );
    if (selectedId == null) {
      return;
    }
    await _dispatchTopMenuSelection(selectedId);
  }

  /// 顶栏菜单选中项分发：八宫格与列表（OS4 玻璃弹层）两种形态共用入口。
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

    // 同步起跑分支：下面每个分支都是"先同步推路由、再 await 它的结果"，
    // 所以这一句执行完就已经能看出"有没有新路由压上来"，收菜单的时机交给
    // [_requestCloseHomeMenu] —— 先收菜单会把底下的圆按钮/爱心球露出来闪一下。
    // 「软件更新」那项要先做异步版本检查才推页面，由它自己在推页面时请收
    // （见 [_openTopMenuUpdatePage]），这里不能替它收。
    final pending = _runTopMenuSelection(selectedId, provider);
    if (selectedId != 'update') {
      _requestCloseHomeMenu();
    }
    await pending;
  }

  /// 菜单项的实际分发（由 [_dispatchTopMenuSelection] 同步起跑）。
  Future<void> _runTopMenuSelection(
    String selectedId,
    TimetableProvider provider,
  ) async {
    switch (selectedId) {
      // 这两项依赖首页宿主上下文：添加课程要带日视图选中日期弹层，
      // 更新入口要先做版本检查再进详情页。其余全部走目录分发。
      case 'addCourse':
        // 列表态菜单走不到这里（父行是展开开关，只回传子项 id）；
        // 八宫格形态与未知 id 兜底仍开三宫格添加弹层。
        await _navigateToAddCourse(context);
      case kAddCourseSubmenuCourseId:
        await Navigator.of(context).push<void>(
          HyperosPageRoute<void>(
            builder: (_) => AddCourseScreen(
              initialWeek: _visibleWeek,
              initialDayOfWeek: _addCourseInitialDayOfWeek,
            ),
          ),
        );
      case kAddCourseSubmenuScheduleId:
        await Navigator.of(context).push<void>(
          HyperosPageRoute<void>(
            builder: (_) => AddScheduleItemScreen(
              initialDate: _resolveAddScheduleInitialDate(provider),
            ),
          ),
        );
      case kAddCourseSubmenuExamId:
        await Navigator.of(context).push<void>(
          HyperosPageRoute<void>(builder: (_) => const AddExamScreen()),
        );
      case 'update':
        await _openTopMenuUpdatePage();
      case 'shareTimetable':
        // 分享要带上「当前可见周」与「当前是周/日视图」，只有本页知道，
        // 所以在这里拦截，不走目录条目的通用 open。
        await _shareTimetableImage(provider);
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
    // 版本检查做完、页面马上要推上来了：这时候才请收菜单 —— 早一步（检查期间）
    // 收掉，首页顶上那两颗球就会在页面盖上来之前先冒出来闪一下。
    _requestCloseHomeMenu();
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
    // De-dupe by sharing the in-flight future; concurrent callers await the
    // same check instead of racing past a boolean flag.
    final inflight = _inflightUpdateCheck;
    if (inflight != null) {
      await inflight;
      return;
    }
    _lastUpdateCheckIncludePrerelease = includePrerelease;
    final Future<void> check = _runUpdateCheck(
      includePrerelease: includePrerelease,
    );
    _inflightUpdateCheck = check;
    try {
      await check;
    } finally {
      if (identical(_inflightUpdateCheck, check)) {
        _inflightUpdateCheck = null;
      }
    }
  }

  Future<void> _runUpdateCheck({required bool includePrerelease}) async {
    if (!kReleaseMode) {
      if (!mounted) {
        return;
      }
      setState(() {
        _hasAvailableUpdate = true;
      });
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
        return;
      }
      setState(() {
        _hasAvailableUpdate = result.hasUpdate;
      });
      _scheduleHomeUpdatePrompt(result);
    } catch (e, stackTrace) {
      // Ignore update check failures on home screen; About page provides
      // details. Log a warning so a "no update prompt" report has a trace.
      debugPrint('checkForAppUpdate failed: $e');
      unawaited(
        AppLogService.instance.warn(
          'home_update_check_failed',
          e.toString(),
          error: e,
          stackTrace: stackTrace,
        ),
      );
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

    final mirrorPreset = AppUpdateMirrorPresetX.fromValue(
      settings.appUpdateMirrorPreset,
    );
    final mirrorPrefix = resolveAppUpdateMirrorUrlPrefix(
      preset: mirrorPreset,
      customUrlPrefix: settings.appUpdateMirrorUrlPrefix,
    );
    // 下载候选：GitCode 等首选直连失败后自动回退 GitHub 原始直链再试一次；
    // 取消、不受信任地址、无摘要拒装、安装器打开失败不换源重试。
    final candidates = <String>[downloadUrl];
    final githubUrl = release.downloadUrl?.trim() ?? '';
    if (githubUrl.isNotEmpty && githubUrl != downloadUrl) {
      candidates.add(githubUrl);
    }
    var cancelled = false;
    for (var index = 0; index < candidates.length; index++) {
      final candidate = candidates[index];
      final controller = AppUpdateDownloadController();
      _homeDownloadController = controller;
      _updatePromptController.beginInAppDownload();
      final error = await _updateService.downloadAndInstallUpdate(
        candidate,
        _updatePromptController.updateInAppProgress,
        controller,
        mirrorUrlPrefix: mirrorPrefix,
        expectedApkSha256: release.expectedApkSha256,
      );
      if (!mounted) {
        return true;
      }
      _homeDownloadController = null;
      cancelled = error == AppUpdateService.downloadCancelledMessage;
      if (error == null || cancelled) {
        _updatePromptController.finishInAppDownload(
          success: error == null,
          cancelled: cancelled,
        );
        return true;
      }
      final notRetryable =
          error.startsWith('update_download_url_untrusted') ||
          error.startsWith('update_sha256_unverified_install_refused') ||
          error.startsWith('update_open_installer_failed');
      if (notRetryable || index == candidates.length - 1) {
        break;
      }
    }
    _updatePromptController.finishInAppDownload(
      success: false,
      cancelled: cancelled,
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
             // 首帧拆解采样点（临时诊断件）。
             FirstFrameProbeNode(
               nodeTag: 'page',
               child: builder(context),
             ),
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

  /// 转场打点：这条路由没有 route name，用固定标签。
  ///
  /// 它是 `opaque: false` 的 420ms 形变转场，下面那屏（首页）全程照画，因此
  /// 与 `HyperosPageRoute` 那条不透明滑动不是同一份成本账，需要单独读数。
  @override
  TickerFuture didPush() {
    FramePerfProbe.mark('route:push:openOnlyContainer');
    FirstFrameProbe.begin('push:openOnlyContainer');
    return super.didPush();
  }

  @override
  bool didPop(T? result) {
    FramePerfProbe.mark('route:pop:openOnlyContainer');
    return super.didPop(result);
  }
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
  }) : enabled = true;

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

class _DayAgendaItem {
  final DayCourseDisplayItem? courseItem;
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

  factory _DayAgendaItem.course(DayCourseDisplayItem item) {
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

/// 首页纵向滚动体的 physics：下拉开着时把用户位移整个吃掉。
///
/// 「回拉取消」的手感要求：下拉还没收回时手指上移应该是**把下拉收回去**，
/// 而不是让列表跟着滚——两者同时发生，读起来就是"我想取消，页面却被滚上去
/// 了"。所以下拉开着期间 `applyPhysicsToUserOffset` 返回 0（列表冻住），等
/// 下拉收到 0 再恢复 1:1，同一次手势接着滚是自然的。
///
/// 必须**常驻安装**：`Scrollable._shouldUpdatePosition` 按 physics 的
/// runtimeType 判断要不要重建 ScrollPosition，运行中换类型会重建 position
/// 并当场终结手势。这里只让闭包读状态，类型的 runtimeType 恒定不变。
class _HomePullFreezeScrollPhysics extends ClampingScrollPhysics {
  const _HomePullFreezeScrollPhysics({required this.isFrozen, super.parent});

  /// 下拉是否还开着（开着就冻结纵向滚动）。
  final bool Function() isFrozen;

  @override
  _HomePullFreezeScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _HomePullFreezeScrollPhysics(
      isFrozen: isFrozen,
      parent: buildParent(ancestor),
    );
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (isFrozen()) {
      return 0;
    }
    return super.applyPhysicsToUserOffset(position, offset);
  }
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

/// 「长按空白格添加课程」的虚线加号标记（两步式交互的第二步目标）。
///
/// 视觉对齐参考截图：圆角虚线框 + 居中加号，尺寸跟随课程卡内缩与节高，
/// 整格可点，点击即打开预填位置的添加课程表单。
///
/// 框覆盖 [span] 节（高 = [span] × [sectionHeight]）：上下各有一条细横杠
/// 提示可拖，纵拖即改首尾节次（回调给外层，外层还要挡住有课的格子）。
class _EmptySlotAddMarker extends StatelessWidget {
  const _EmptySlotAddMarker({
    required this.sectionHeight,
    required this.span,
    required this.inset,
    required this.ink,
    required this.onTap,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeEnd,
  });

  final double sectionHeight;
  final int span;
  final double inset;
  /// 已按壁纸/深浅色适配好的墨色（外层用 homePageOverWallpaperInk 求得）。
  final Color ink;
  final VoidCallback onTap;
  /// 参数为 true 表示拖的是上边缘，false 为下边缘。
  final ValueChanged<bool> onResizeStart;
  /// 参数为每次纵拖的纵向增量（px）。
  final ValueChanged<double> onResizeUpdate;
  final VoidCallback onResizeEnd;

  @override
  Widget build(BuildContext context) {
    // 虚线与加号走「弱化墨色」（与时间轴副文本同款），填充再淡一档。
    final markerColor = homePageOverWallpaperMutedInk(ink);
    final totalHeight = sectionHeight * span;
    // 单节框很矮时按 1/3 高收窄把手，避免两条把手吃掉整个点击区。
    final handleHeight = (totalHeight / 3).clamp(8.0, 16.0);
    return GestureDetector(
      // 供测试定位「两步式添加」的虚线标记（类是私有的，测不了类型）。
      key: const ValueKey('empty-slot-add-marker'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(inset),
        child: CustomPaint(
          painter: _DashedRRectBorderPainter(
            color: markerColor,
            fill: markerColor.withValues(alpha: 0.08),
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(
                  Icons.add_rounded,
                  size: (sectionHeight * 0.3).clamp(16.0, 26.0),
                  color: markerColor,
                ),
              ),
              _buildResizeHandle(
                key: const ValueKey('empty-slot-add-marker-top-handle'),
                isTopEdge: true,
                height: handleHeight,
                color: markerColor,
              ),
              _buildResizeHandle(
                key: const ValueKey('empty-slot-add-marker-bottom-handle'),
                isTopEdge: false,
                height: handleHeight,
                color: markerColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 上/下边缘的拖拽把手：横杠只作视觉提示，整条区域都收纵拖。
  ///
  /// 把手自己也挂 onTap：纵拖识别器在「没拖动就抬手」时会把自己判负，但
  /// 手势竞技场按命中顺序先问内层，补一个 onTap 才能保住「点把手也能进
  /// 表单」。
  Widget _buildResizeHandle({
    required Key key,
    required bool isTopEdge,
    required double height,
    required Color color,
  }) {
    return Positioned(
      key: key,
      top: isTopEdge ? 0 : null,
      bottom: isTopEdge ? null : 0,
      left: 0,
      right: 0,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onVerticalDragStart: (_) => onResizeStart(isTopEdge),
        onVerticalDragUpdate: (details) => onResizeUpdate(details.delta.dy),
        onVerticalDragEnd: (_) => onResizeEnd(),
        onVerticalDragCancel: onResizeEnd,
        child: Align(
          alignment: isTopEdge
              ? Alignment.topCenter
              : Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(
              top: isTopEdge ? 4 : 0,
              bottom: isTopEdge ? 0 : 4,
            ),
            child: Container(
              width: 26,
              height: 3,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 圆角虚线框 painter：沿 RRect 周长按 dash/gap 逐段绘制。
/// Flutter 内置 [Border] 不支持虚线，这里手绘（无第三方依赖）。
class _DashedRRectBorderPainter extends CustomPainter {
  _DashedRRectBorderPainter({required this.color, required this.fill});

  final Color color;
  final Color fill;

  static const double _radius = 12;
  static const double _strokeWidth = 1.5;
  static const double _dashLength = 4;
  static const double _gapLength = 3.5;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(_radius),
    );
    if (fill.a > 0) {
      canvas.drawRRect(rrect, Paint()..color = fill);
    }
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + _dashLength).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + _gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.fill != fill;
}
