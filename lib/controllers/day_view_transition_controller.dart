import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../domain/day_view_paging.dart';
import '../domain/timetable_layout.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../utils/home_page_background.dart' show controllerPageOrNull;

/// 日视图翻页落点（周次 + 星期）。
///
/// 与 `widgets/timetable/timetable_day_agenda_models.dart` 里的
/// `TimetableDayViewPageTarget` 同形，但本库不依赖 widgets 层：宿主在薄接线上
/// 做一次字段搬运即可。
class DayViewPageTarget {
  const DayViewPageTarget({required this.week, required this.dayOfWeek});

  final int week;
  final int dayOfWeek;
}

/// [DayViewTransitionController] 对宿主 State 的全部依赖。
///
/// 控制器只认这个端口：日 / 周选择、展开动画、persist、周页跳转与重建都由宿主
/// 提供。这样转场状态机（开合 / 翻页 / ScrollEnd 提交 / pager 生命周期）可以
/// 脱离 `timetable_screen.dart` 单独阅读与测试，而状态仍留在 State 里一份。
abstract interface class DayViewTransitionHost {
  /// State 是否仍挂载（`State.mounted`）。
  bool get isMounted;

  /// 日视图当前是否展开（由周次 + 星期两份选择共同决定）。
  bool get isDayView;

  int? get selectedWeekForDayView;
  set selectedWeekForDayView(int? value);

  int? get selectedDayOfWeek;
  set selectedDayOfWeek(int? value);

  /// 首页当前可见周（周 pager 落定的那一周）。
  int get visibleWeek;

  /// 周 pager 是否正被同步动画驱动。
  bool get isSyncingWeekPage;

  /// 日视图整屏滑动转场期间为 true：日 pager 外的 IgnorePointer 读它。
  bool get isDaySwipeAnimating;
  set isDaySwipeAnimating(bool value);

  /// 单次手势只允许一次日切换点击震感的闩锁。
  bool get daySwipeHapticFired;
  set daySwipeHapticFired(bool value);

  double get dayPagerRescueVelocityX;
  set dayPagerRescueVelocityX(double value);

  DateTime? get dayPagerRescueArmedAt;
  set dayPagerRescueArmedAt(DateTime? value);

  /// 日 pager 页中点预览（星期栏高亮用）。
  ValueNotifier<(int, int)?> get dayHeaderPreview;

  /// 日视图锚点展开值（0 = 周视图，1 = 日视图）。
  double get dayViewExpandValue;
  set dayViewExpandValue(double value);

  /// 单页切换动画时长（与周页滑动同一口径）。
  Duration get pageSlideDuration;

  /// 情侣空闲摘要的展开态：展开日视图时收起。
  set sharedFreeSegmentsExpanded(bool value);

  /// 日切换点击震感（受设置里的触觉开关控制）。
  void selectionClick(TimetableSettings settings);

  /// 清掉周视图里可能还挂着的两步式添加标记。
  void clearEmptySlotMarker();

  /// 播展开动画（不等待完成）。
  Future<void> forwardDayViewExpand();

  /// 播收起动画（调用方等待完成）。
  Future<void> reverseDayViewExpand();

  /// 落盘为日视图 + 指定星期。
  void persistDayView({required int dayOfWeek});

  /// 落盘为周视图。
  void persistWeekView();

  /// 周 pager 跳到指定周。
  Future<void> jumpToWeek(
    TimetableProvider provider,
    int week, {
    required bool animatePage,
  });

  /// 在宿主 State 上调用 `setState`，[mutate] 里改字段。
  void setStateMutations(VoidCallback mutate);

  /// 只触发一次重建（`setState(() {})`）。
  void rebuild();
}

/// 日视图转场 / 翻页控制器（2026-10-20 从 `_TimetableScreenState` 搬出）。
///
/// 负责：
/// - 日视图开合（锚点展开动画、选择落定、persist 时序、震感）；
/// - 全局连续日 pager 的翻页：页号 ↔（周次, 星期）、页中点预览、ScrollEnd
///   提交与同帧重试；
/// - pager 的 `PageController` 生命周期（替换、延迟释放、墓碑）；
/// - 星期栏拖动 → pager 的跟手桥接与救援速度取出。
///
/// 行为、动画时长、ScrollEnd 重试次数、震动闩锁与 persist 时机均按原实现
/// 原样保留；所有状态读写经 [host] 端口。
class DayViewTransitionController {
  DayViewTransitionController({required this.host});

  final DayViewTransitionHost host;

  /// 全局连续的日 pager：页 = (周次-1) * 可见星期数 + 星期下标。
  PageController? _pageController;

  final Set<PageController> _pendingControllerDisposals = {};

  /// Recently disposed controllers are retained only as short-lived tombstones.
  /// A stale replacement frame can still call [ensurePageController] before the
  /// old render tree detaches; two post-frame hops are enough to cover that
  /// race without growing for the lifetime of the screen.
  final Set<PageController> _disposedControllers = {};

  bool _isSyncingPage = false;
  int? _transitionSourceWeek;
  int? _transitionSourceDayOfWeek;

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

  PageController? get pageController => _pageController;

  /// 日视图"此刻正看着的那一周"：整屏滑动转场中取来源周。
  int? get visibleWeek {
    if (host.isDaySwipeAnimating && _transitionSourceWeek != null) {
      return _transitionSourceWeek;
    }
    return host.selectedWeekForDayView;
  }

  /// 日视图"此刻正看着的那一天"。
  ///
  /// 滑动中用**页中点预览**（`dayHeaderPreview`，与星期栏高亮同源），静止时
  /// 用已落定的选择。必须这么取：日视图滑动期间整屏不 setState（防 ANR），
  /// 只看落定选择的话，按钮要等 ScrollEnd 之后才可能变化。
  (int, int)? visibleDayViewTarget() {
    if (!host.isDayView) {
      return null;
    }
    final preview = host.dayHeaderPreview.value;
    if (preview != null) {
      return preview;
    }
    final week = host.selectedWeekForDayView;
    final day = host.selectedDayOfWeek;
    if (week == null || day == null) {
      return null;
    }
    return (week, day);
  }

  /// [sameSelectionCloses]：目标与当前选择相同时，要不要按「再点一次」收起。
  ///
  /// 首页那颗按钮与底栏 Tab 传 true（点同一档 = 收起日视图）；**外部（缩尺
  /// 预览）驱动传 false** —— 那边下发的是「要日视图」这个目标状态，不是一次
  /// 点按：宿主的分段按钮与预览状态本来就该一致，一致时重复下发不该把日视图
  /// 关掉（真机表现就是「切过去又自己闪回周视图」）。
  Future<void> toggle({
    required int week,
    required int dayOfWeek,
    required TimetableSettings settings,
    bool animate = true,
    bool sameSelectionCloses = true,
  }) async {
    final normalizedWeek = clampWeek(week, settings.semesterWeekCount);
    final isSameSelection =
        host.isDayView &&
        host.selectedWeekForDayView == normalizedWeek &&
        host.selectedDayOfWeek == dayOfWeek;
    if (isSameSelection) {
      if (sameSelectionCloses) {
        await close(settings, animate: animate);
      }
      return;
    }
    if (host.isDayView && host.selectedWeekForDayView == normalizedWeek) {
      await _switchDayWithinWeek(settings, normalizedWeek, dayOfWeek);
      return;
    }
    // 走到这说明是从周视图展开（日视图内不会产生空白格标记，手势层
    // 在展开时是关闭的）：清掉周视图里可能还挂着的两步式添加标记，
    // 否则收起日视图后它会原样重现，绕过「点空白处取消」的规则。
    host.clearEmptySlotMarker();
    final shouldAnimateOpen = animate && !host.isDayView;
    if (!host.isDayView) {
      _recreatePageController(
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
    if (!host.isDayView) {
      host.dayViewExpandValue = shouldAnimateOpen ? 0 : 1;
    }
    host.dayHeaderPreview.value = null;
    host.setStateMutations(() {
      host.selectedWeekForDayView = normalizedWeek;
      host.selectedDayOfWeek = dayOfWeek;
      host.sharedFreeSegmentsExpanded = false;
    });
    host.persistDayView(dayOfWeek: dayOfWeek);
    host.selectionClick(settings);
    if (shouldAnimateOpen) {
      // Start open animation without awaiting completion (close still awaits
      // reverse). Controller was reset to 0 above so the first frame is small.
      unawaited(host.forwardDayViewExpand());
    }
  }

  Future<void> close(TimetableSettings settings, {bool animate = true}) async {
    if (!host.isDayView) {
      return;
    }
    host.selectionClick(settings);
    if (host.dayViewExpandValue > 0) {
      if (animate) {
        await host.reverseDayViewExpand();
        if (!host.isMounted) {
          return;
        }
      } else {
        // 底栏闪现直切：跳过收起动画直接归零，与下方清理同帧生效。
        host.dayViewExpandValue = 0;
      }
    }
    host.dayHeaderPreview.value = null;
    host.setStateMutations(() {
      host.selectedWeekForDayView = null;
      host.selectedDayOfWeek = null;
      _transitionSourceWeek = null;
      _transitionSourceDayOfWeek = null;
    });
    host.persistWeekView();
  }

  int pageIndexForDay(TimetableSettings settings, int week, int dayOfWeek) {
    // 口径在 domain/day_view_paging.dart：先归一星期再算页号，并与逆运算
    // 严格互逆（越界星期不会静默折成周一页而状态仍写着 6/7）。
    return dayViewGlobalPage(
      visibleDays: visibleDayNumbers(settings),
      week: week,
      dayOfWeek: dayOfWeek,
    );
  }

  int pageCount(TimetableSettings settings) {
    return visibleDayNumbers(settings).length * settings.semesterWeekCount;
  }

  DayViewPageTarget targetForPage(TimetableSettings settings, int page) {
    final target = dayViewTargetForGlobalPage(
      visibleDayNumbers(settings),
      page,
    );
    // 可见日表恒为 1..5 或 1..7，null 分支只是防呆回落。
    return DayViewPageTarget(week: target?.$1 ?? 1, dayOfWeek: target?.$2 ?? 1);
  }

  PageController ensurePageController(TimetableSettings settings) {
    final existing = _pageController;
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
        !_pendingControllerDisposals.contains(existing) &&
        !_disposedControllers.contains(existing)) {
      return existing;
    }
    final fresh = _createPageController(settings);
    _pageController = fresh;
    if (existing != null) {
      // Stale controller (created but never attached, or detached after the
      // day view closed): replace it instead of reusing a dead position.
      _disposeControllerAfterReplacement(existing);
    }
    return fresh;
  }

  PageController _createPageController(
    TimetableSettings settings, {
    int? week,
    int? dayOfWeek,
  }) {
    return PageController(
      initialPage: pageIndexForDay(
        settings,
        week ?? host.selectedWeekForDayView ?? host.visibleWeek,
        dayOfWeek ?? host.selectedDayOfWeek ?? 1,
      ),
    );
  }

  /// Recreates the single day pager anchored on the given day (used when the
  /// day view opens so the first painted frame lands on the requested day).
  /// The old controller is kept alive for two post-frame hops so the
  /// replacing tree can detach.
  void _recreatePageController(
    TimetableSettings settings, {
    int? week,
    int? dayOfWeek,
  }) {
    final old = _pageController;
    _pageController = _createPageController(
      settings,
      week: week,
      dayOfWeek: dayOfWeek,
    );
    if (old != null) {
      _disposeControllerAfterReplacement(old);
    }
  }

  void _rememberDisposedController(PageController controller) {
    if (!_disposedControllers.add(controller)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!host.isMounted) {
        _disposedControllers.remove(controller);
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _disposedControllers.remove(controller);
      });
    });
  }

  void _disposeControllerAfterReplacement(PageController controller) {
    if (!_pendingControllerDisposals.add(controller)) {
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
      if (!host.isMounted) {
        if (_pendingControllerDisposals.remove(controller)) {
          controller.dispose();
        }
        return;
      }
      if (_pageController == controller || controller.hasClients) {
        if (controller.hasClients) {
          // A PageView still holds this controller: force a rebuild so the
          // next ensurePageController swaps in a fresh controller and the
          // old one detaches, then re-check next frame.
          host.rebuild();
        }
        _pendingControllerDisposals.add(controller);
        WidgetsBinding.instance.addPostFrameCallback((_) => retryDispose());
        WidgetsBinding.instance.scheduleFrame();
        return;
      }
      if (_pendingControllerDisposals.remove(controller)) {
        _rememberDisposedController(controller);
        controller.dispose();
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!host.isMounted) {
        if (_pendingControllerDisposals.remove(controller)) {
          controller.dispose();
        }
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => retryDispose());
      WidgetsBinding.instance.scheduleFrame();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  /// 从 provider 恢复浏览状态时重置转场侧的一次性状态：滑动的来源周/日、
  /// 同步闩锁都清掉，旧 pager 控制器按替换路径延迟释放（先留两帧给树解绑）。
  void resetForRestore() {
    _transitionSourceWeek = null;
    _transitionSourceDayOfWeek = null;
    _isSyncingPage = false;
    final oldController = _pageController;
    _pageController = null;
    if (oldController != null) {
      _disposeControllerAfterReplacement(oldController);
    }
  }

  /// 清掉整屏滑动转场的来源周/日（周页被外部同步接管时用）。
  void clearTransitionSource() {
    _transitionSourceWeek = null;
    _transitionSourceDayOfWeek = null;
  }

  int displayedDayForWeek(int week) {
    if (_transitionSourceWeek == week && _transitionSourceDayOfWeek != null) {
      return _transitionSourceDayOfWeek!;
    }
    return host.selectedDayOfWeek ?? 1;
  }

  void syncPageWithSelection(TimetableSettings settings) {
    if (_isSyncingPage || !host.isDayView) {
      return;
    }
    if (_transitionSourceWeek != null) {
      return;
    }
    final controller = _pageController;
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
    final week = host.selectedWeekForDayView ?? host.visibleWeek;
    final targetPage = pageIndexForDay(
      settings,
      week,
      displayedDayForWeek(week),
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
    final controller = ensurePageController(settings);
    host.dayHeaderPreview.value = null;
    host.setStateMutations(() {
      host.selectedWeekForDayView = week;
      host.selectedDayOfWeek = dayOfWeek;
    });
    host.persistDayView(dayOfWeek: dayOfWeek);
    host.selectionClick(settings);
    if (!controller.hasClients) {
      return;
    }
    final targetPage = pageIndexForDay(settings, week, dayOfWeek);
    final currentPage =
        controllerPageOrNull(controller)?.round() ?? controller.initialPage;
    if (currentPage == targetPage) {
      return;
    }
    _isSyncingPage = true;
    try {
      if (animate && controller.positions.length == 1) {
        await controller.animateToPage(
          targetPage,
          duration: host.pageSlideDuration,
          curve: Curves.easeOutCubic,
        );
      } else if (controller.positions.length == 1) {
        controller.jumpToPage(targetPage);
      }
    } finally {
      _isSyncingPage = false;
    }
  }

  Future<void> animateToWeek(
    TimetableProvider provider,
    TimetableSettings settings,
    int targetWeek,
    int targetDayOfWeek, {
    bool animateWeekPage = true,
  }) async {
    if (host.selectedWeekForDayView == null || host.selectedDayOfWeek == null) {
      return;
    }
    final normalizedTargetWeek = clampWeek(
      targetWeek,
      provider.settings.semesterWeekCount,
    );
    // 「已经在目标那天」按**画面实际所在**判断（滑动中取页中点预览），不能
    // 只看已落定的选择：手势 / 惯性还没停时选择仍停在上一天，用户此刻点
    // 「回今日」会被这条误判成"已经在今天"而整个调用直接返回——读起来就是
    // 点了没反应，随后惯性照旧把画面带到别的天。
    final liveTarget = visibleDayViewTarget();
    final liveWeek = liveTarget?.$1 ?? host.selectedWeekForDayView;
    final liveDay = liveTarget?.$2 ?? host.selectedDayOfWeek;
    if (normalizedTargetWeek == liveWeek && targetDayOfWeek == liveDay) {
      return;
    }

    host.isDaySwipeAnimating = true;
    try {
      host.dayHeaderPreview.value = null;
      host.setStateMutations(() {
        _transitionSourceWeek = host.selectedWeekForDayView;
        _transitionSourceDayOfWeek = host.selectedDayOfWeek;
        host.selectedWeekForDayView = normalizedTargetWeek;
        host.selectedDayOfWeek = targetDayOfWeek;
      });
      host.persistDayView(dayOfWeek: targetDayOfWeek);
      // Same single pager scrolls to the target day; the week page follows
      // for state consistency (it is faded out while the day view is open).
      await _switchDayWithinWeek(
        settings,
        normalizedTargetWeek,
        targetDayOfWeek,
        animate: animateWeekPage,
      );
      if (!host.isMounted) {
        return;
      }
      host.setStateMutations(() {
        _transitionSourceWeek = null;
        _transitionSourceDayOfWeek = null;
      });
      if (normalizedTargetWeek != host.visibleWeek) {
        await host.jumpToWeek(
          provider,
          normalizedTargetWeek,
          animatePage: animateWeekPage,
        );
      }
    } finally {
      host.isDaySwipeAnimating = false;
      // 日视图滑动区外层的 IgnorePointer 在 build 时读取该标志：上面所有
      // setState 都发生在标志仍为 true 的期间，若此处不复位后再补一次重建，
      // 「回到今天」转场结束后 ignoring:true 会永久滞留，日视图左右滑动
      // 就再也无响应。必须显式重建一帧把指针放行。
      if (host.isMounted) {
        host.rebuild();
      }
    }
  }

  Future<void> handlePageChanged(
    TimetableProvider provider,
    TimetableSettings settings,
    int page,
  ) async {
    if (_isSyncingPage || host.isDaySwipeAnimating) {
      if (kDebugMode) {
        debugPrint(
          '[DayPager] pageChanged($page) ignored: '
          'syncing=$_isSyncingPage animating=${host.isDaySwipeAnimating}',
        );
      }
      return;
    }
    final target = targetForPage(settings, page);
    if (kDebugMode) {
      debugPrint(
        '[DayPager] pageChanged($page) -> week=${target.week} '
        'day=${target.dayOfWeek}',
      );
    }
    if (host.selectedWeekForDayView == target.week &&
        host.selectedDayOfWeek == target.dayOfWeek) {
      // 回滑到已选那天：必须把提前预览撤掉。留着的话预览标记会停在被滑
      // 过去的那一天，而 ScrollEnd 收到「选择没变」时不会重建，星期栏
      // 就永久多亮一格（只能靠「回到今天」之类的整屏重建才消失）。
      // 清空与翻页发生在同一次 setPixels 里：位置通知已经在同一帧把这
      // 条栏标脏，本帧的 build 就会读到 null，高亮随之回到已选那天。
      host.dayHeaderPreview.value = null;
      return;
    }
    // Midpoint preview: recolour the weekday header the moment the pager
    // crosses a page midpoint (matching the indicator), via the scoped
    // notifier — no full-State rebuild while the fling is still running.
    // Committing the selection here instead (setState + persist + week-page
    // jump) rebuilt the whole home screen on *every* page crossing — a single
    // real-device swipe crosses 30+ pages and each rebuild re-samples the
    // wallpaper blur, which starved the main thread into an ANR. The actual
    // selection commit stays on ScrollEnd (settlePage), which now re-checks
    // until the pager is truly stationary.
    host.dayHeaderPreview.value = (target.week, target.dayOfWeek);
    // 单次手势只震一次：快速甩动跨两页 / 弹簧回弹再过中点时，onPageChanged
    // 会连发多次，不闩锁就会一次滑动触发两次震动。
    if (!host.daySwipeHapticFired) {
      host.daySwipeHapticFired = true;
      host.selectionClick(settings);
    }
  }

  /// Commits the settled day-pager page once the horizontal scroll has fully
  /// stopped, mirroring the week pager's ScrollEnd → finalize model so the
  /// setState + persist never land mid-animation. A cross-week landing is an
  /// ordinary page here (the pager is globally continuous), so the week page
  /// follows the committed week for state consistency.
  void settlePage(TimetableProvider provider, TimetableSettings settings) {
    if (_isSyncingPage || host.isDaySwipeAnimating) {
      if (kDebugMode) {
        debugPrint(
          '[DayPager] settle skipped: syncing=$_isSyncingPage '
          'animating=${host.isDaySwipeAnimating}',
        );
      }
      return;
    }
    final controller = _pageController;
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
      _scheduleSettleRetry(provider, settings);
      return;
    }
    final page = controllerPageOrNull(controller)?.round();
    if (page == null) {
      return;
    }
    final target = targetForPage(settings, page);
    if (kDebugMode) {
      debugPrint(
        '[DayPager] settle: rawPage=${controllerPageOrNull(controller)?.toStringAsFixed(3)} '
        '-> page=$page week=${target.week} day=${target.dayOfWeek} '
        'alreadySelected=${host.selectedWeekForDayView == target.week && host.selectedDayOfWeek == target.dayOfWeek}',
      );
    }
    host.dayHeaderPreview.value = null;
    if (host.selectedWeekForDayView == target.week &&
        host.selectedDayOfWeek == target.dayOfWeek) {
      return;
    }
    host.setStateMutations(() {
      host.selectedWeekForDayView = target.week;
      host.selectedDayOfWeek = target.dayOfWeek;
    });
    host.persistDayView(dayOfWeek: target.dayOfWeek);
    // 手势收尾：重新武装点击震感，下一次滑动（含纯惯性续滑）可再次触发。
    host.daySwipeHapticFired = false;
    if (target.week != host.visibleWeek && !host.isSyncingWeekPage) {
      unawaited(host.jumpToWeek(provider, target.week, animatePage: false));
    }
  }

  /// Re-checks the day pager on the next frame after a ScrollEnd arrived while
  /// the pager was still scrolling (a stale end interleaved with the next
  /// gesture). Once the pager is truly stationary the selection is committed
  /// to the page the content actually shows; if a fresh gesture owns the
  /// pager we wait for its own ScrollEnd instead of polling forever.
  void _scheduleSettleRetry(
    TimetableProvider provider,
    TimetableSettings settings,
  ) {
    if (!host.isMounted || !host.isDayView) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!host.isMounted || !host.isDayView) {
        return;
      }
      final controller = _pageController;
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
      settlePage(provider, settings);
    });
  }

  /// Weekday-bar drag → day-pager bridge. The bar acts as a visible-day-count
  /// (7x) scrubber over the day pager: bar deltas are amplified and injected
  /// straight into the pager's ScrollPosition, so the content follows the
  /// finger at week-per-bar-width speed while the bar itself moves slowly.
  void startWeekdayBarDrag(
    TimetableSettings settings,
    DragStartDetails details,
  ) {
    _weekdayBarDrag?.cancel();
    _weekdayBarDrag = null;
    if (host.isDaySwipeAnimating) {
      return;
    }
    final controller = _pageController;
    if (controller == null ||
        !controller.hasClients ||
        controller.positions.length != 1) {
      return;
    }
    _weekdayBarDragScale = visibleDayNumbers(settings).length.toDouble();
    // 星期栏刮擦也是一次手势：整段拖动只保留一次日切换点击震感。
    host.daySwipeHapticFired = false;
    _weekdayBarDrag = controller.position.drag(details, () {
      _weekdayBarDrag = null;
    });
  }

  void updateWeekdayBarDrag(DragUpdateDetails details) {
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

  void endWeekdayBarDrag(DragEndDetails details) {
    final drag = _weekdayBarDrag;
    _weekdayBarDrag = null;
    if (drag == null) {
      return;
    }
    // Release velocity is amplified like the deltas, then the pager's own
    // snap physics settles it — same pipeline as a direct content fling, so
    // midpoint preview / ScrollEnd commit stay intact.
    final vx = details.velocity.pixelsPerSecond.dx * _weekdayBarDragScale;
    drag.end(
      DragEndDetails(
        velocity: Velocity(pixelsPerSecond: Offset(vx, 0)),
        primaryVelocity: vx,
      ),
    );
  }

  void cancelWeekdayBarDrag() {
    final drag = _weekdayBarDrag;
    _weekdayBarDrag = null;
    drag?.cancel();
  }

  /// One-shot read of the armed rescue velocity for the day pager physics.
  /// Freshness-gated so a stale value can never leak into an unrelated
  /// ballistic (the drag consumes it within the same event dispatch).
  double takeRescueVelocity() {
    final armedAt = host.dayPagerRescueArmedAt;
    final vx = host.dayPagerRescueVelocityX;
    host.dayPagerRescueVelocityX = 0;
    host.dayPagerRescueArmedAt = null;
    if (armedAt == null ||
        DateTime.now().difference(armedAt) > const Duration(milliseconds: 90)) {
      return 0;
    }
    return vx;
  }

  /// Releases the pager controller and anything still waiting for deferred
  /// disposal. Called from the host's `dispose`.
  void dispose() {
    final controller = _pageController;
    _pageController = null;
    controller?.dispose();
    for (final pending in _pendingControllerDisposals) {
      pending.dispose();
    }
    _pendingControllerDisposals.clear();
  }
}
