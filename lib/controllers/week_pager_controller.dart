import 'dart:async';

import 'package:flutter/widgets.dart';

import '../domain/timetable_layout.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../utils/home_page_background.dart' show controllerPageOrNull;

/// [WeekPagerController] 对宿主 State 的全部依赖。
///
/// 控制器只认这个端口：日视图状态、重建、空白格标记清理与震感都由宿主提供。
/// 这样周 pager 的同步 / 落定 / 提交队列可以脱离 `timetable_screen.dart`
/// 单独阅读，而日视图选择等字段仍留在 State 里一份。
abstract interface class WeekPagerHost {
  /// State 是否仍挂载（`State.mounted`）。
  bool get isMounted;

  /// 日视图当前是否展开。
  bool get isDayView;

  /// 日视图整屏滑动转场期间为 true：此时不抢周页。
  bool get isDaySwipeAnimating;

  int? get selectedWeekForDayView;
  set selectedWeekForDayView(int? value);

  /// 只触发一次重建（`setState(() {})`）。
  void rebuild();

  /// 清掉周视图里可能还挂着的两步式添加标记。
  void clearEmptySlotMarker();

  /// 清掉日视图转场的来源周/日（包在宿主的 `setState` 里）。
  void clearDayViewTransitionSource();

  /// 周次切换触感（受设置里的触觉开关控制）。
  void selectionClick(TimetableSettings settings);
}

/// 周 pager / 可见周状态机（2026-10-20 从 `_TimetableScreenState` 搬出）。
///
/// 负责：
/// - 周 `PageController` 与「当前可见周」两份状态的持有与释放；
/// - provider 周次 → pager 的 build 期同步（含 post-frame 收敛与三重防重入）；
/// - 用户翻页的落定（ScrollEnd 收尾）与「待提交周次」队列；
/// - 视口未挂载时的直跳回退。
///
/// 行为、动画时长、提交时序与守卫口径均按原实现原样保留。
class WeekPagerController {
  WeekPagerController({
    required this.host,
    required int initialWeek,
    required int initialPage,
  }) : pageController = PageController(initialPage: initialPage),
       visibleWeek = initialWeek,
       pendingSettledWeek = initialWeek,
       lastObservedWeekPage = initialPage,
       visibleWeekListenable = ValueNotifier<int>(initialWeek);

  /// 周页滑动动画时长（与日视图单页切换同一口径）。
  static const Duration weekSlideDuration = Duration(milliseconds: 280);

  final WeekPagerHost host;

  final PageController pageController;

  /// 首页当前可见周（周 pager 落定的那一周，或直跳后的目标周）。
  int visibleWeek;

  /// 星期栏指示条等「只跟可见周走」的监听口。
  final ValueNotifier<int> visibleWeekListenable;

  /// 周 pager 是否正被同步动画驱动。
  bool isSyncingWeekPage = false;

  /// 已排进 post-frame 的目标页（同一页不重复 jump）。
  int? _pendingSyncedWeek;

  /// 最近一次观察到的 pager 页号（0-based）。
  int? lastObservedWeekPage;

  /// 手势翻页过程中暂定的落定周次。
  int? pendingSettledWeek;

  /// 等待写回 provider 的周次（串行提交队列）。
  int? pendingCommittedWeek;

  bool _isCommittingWeek = false;

  Duration get slideDuration => weekSlideDuration;

  void dispose() {
    pageController.dispose();
    visibleWeekListenable.dispose();
  }

  /// provider / 档案切换时的浏览状态恢复（原 `_restoreViewStateFromProvider`
  /// 里的周次部分）。
  void restore(int currentWeek, int semesterWeekCount) {
    visibleWeek = clampWeek(currentWeek, semesterWeekCount);
    pendingSettledWeek = visibleWeek;
    pendingCommittedWeek = null;
    visibleWeekListenable.value = visibleWeek;
  }

  bool get _hasPendingLocalWeekTransition =>
      (pendingSettledWeek != null && pendingSettledWeek != visibleWeek) ||
      pendingCommittedWeek != null ||
      _isCommittingWeek;

  /// 只改「可见周」并通知监听口；需要时顺带同步日视图选择并重建。
  ///
  /// 原 `_applyVisibleWeek`：`rebuild` 与 `syncDayView` 都是调用方按当前视图
  /// 决定的口径，这里不重新判断。
  void applyVisibleWeek(
    int week, {
    bool rebuild = false,
    bool syncDayView = false,
  }) {
    final shouldSyncDayView = syncDayView && host.selectedWeekForDayView != week;
    if (visibleWeek == week && !shouldSyncDayView) {
      return;
    }
    visibleWeek = week;
    visibleWeekListenable.value = week;
    if ((rebuild || shouldSyncDayView) && host.isMounted) {
      if (shouldSyncDayView) {
        host.selectedWeekForDayView = week;
      }
      host.rebuild();
    }
  }

  /// 跳到指定周：视口已挂载时走 pager 动画 / 直跳，否则直接改可见周并提交。
  Future<void> jumpToWeek(
    TimetableProvider provider,
    int week, {
    bool animatePage = true,
  }) async {
    if (isSyncingWeekPage) {
      return;
    }

    final targetWeek = clampWeek(week, provider.settings.semesterWeekCount);
    if (targetWeek == visibleWeek) {
      return;
    }

    if (!pageController.hasClients) {
      pendingSettledWeek = targetWeek;
      pendingCommittedWeek = targetWeek;
      applyVisibleWeek(
        targetWeek,
        rebuild: host.isDayView || provider.settings.semesterStartDate == null,
        syncDayView: host.isDayView,
      );
      await commitPendingWeek(provider);
      return;
    }

    isSyncingWeekPage = true;
    try {
      if (pageController.positions.length != 1) {
        // Subtree-replacement frame: the outgoing PageView position is still
        // attached, so animateTo/jumpTo (positions.single) would throw.
        // Skip the scroll; the replacement tree already shows the target week.
        pendingSettledWeek = targetWeek;
      } else if (animatePage) {
        await pageController.animateToPage(
          targetWeek - 1,
          duration: (targetWeek - visibleWeek).abs() == 1
              ? slideDuration
              : const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
        );
        pendingSettledWeek = targetWeek;
      } else {
        // Day-view boundary swipes already provide the horizontal motion.
        pageController.jumpToPage(targetWeek - 1);
        pendingSettledWeek = targetWeek;
      }
    } finally {
      isSyncingWeekPage = false;
    }

    finalizeWeekPageSettled(
      provider,
      fallbackWeek: targetWeek,
      syncDayView: host.isDayView,
    );
  }

  /// pager 页号变化（`onPageChanged`）：先记落定候选，等 ScrollEnd 再提交。
  void handleWeekPageChanged(int page, int maxWeek) {
    host.clearEmptySlotMarker();
    lastObservedWeekPage = page;
    pendingSettledWeek = clampWeek(page + 1, maxWeek);
    visibleWeekListenable.value = pendingSettledWeek!;
  }

  /// 将 provider 的当前周次同步到周视图 pager。
  ///
  /// 该方法在 build 中调用（外部周次来源可能在一帧内多次到达），副作用
  /// 通过 post-frame 回调收敛且带三重防重入（[_pendingSyncedWeek]、
  /// [isSyncingWeekPage]、[_hasPendingLocalWeekTransition]）：同一目标页
  /// 不会重复 jump，本地手势进行中绝不抢页。这是「build 中带副作用」的
  /// 受控例外——迁到 didChangeDependencies 需要区分周次来源并改动
  /// 同步时序，当前实现的行为与守卫已在测试中锚定，保持现状。
  void syncWeekPageWithProvider(int week, TimetableSettings settings) {
    final maxWeek = settings.semesterWeekCount;
    if (isSyncingWeekPage || _hasPendingLocalWeekTransition) {
      return;
    }

    final targetWeek = clampWeek(week, maxWeek);
    final targetPage = targetWeek - 1;
    final shouldSyncDayView =
        host.isDayView &&
        !host.isDaySwipeAnimating &&
        host.selectedWeekForDayView != targetWeek;
    final needsVisualSync =
        visibleWeek != targetWeek ||
        shouldSyncDayView ||
        lastObservedWeekPage != targetPage;
    if (!needsVisualSync) {
      return;
    }
    if (_pendingSyncedWeek == targetPage) {
      return;
    }
    _pendingSyncedWeek = targetPage;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingSyncedWeek = null;
      if (!host.isMounted ||
          isSyncingWeekPage ||
          _hasPendingLocalWeekTransition) {
        return;
      }

      final syncDayView =
          host.isDayView &&
          !host.isDaySwipeAnimating &&
          host.selectedWeekForDayView != targetPage + 1;
      pendingSettledWeek = targetPage + 1;
      applyVisibleWeek(
        targetPage + 1,
        rebuild: syncDayView || settings.semesterStartDate == null,
        syncDayView: syncDayView,
      );

      if (syncDayView && host.isMounted) {
        host.clearDayViewTransitionSource();
      }

      if (pageController.positions.length != 1) {
        // Subtree-replacement frame: jumpToPage (positions.single) would
        // throw while the outgoing PageView position is still attached.
        return;
      }
      final currentPage = lastObservedWeekPage ?? pageController.initialPage;
      if (currentPage == targetPage) {
        return;
      }

      lastObservedWeekPage = targetPage;
      pageController.jumpToPage(targetPage);
    });
  }

  int resolveSettledWeek(TimetableProvider provider, {int? fallbackWeek}) {
    final maxWeek = provider.settings.semesterWeekCount;
    final page = controllerPageOrNull(pageController);
    if (page != null) {
      return clampWeek(page.round() + 1, maxWeek);
    }
    if (lastObservedWeekPage != null) {
      return clampWeek(lastObservedWeekPage! + 1, maxWeek);
    }
    return clampWeek(fallbackWeek ?? pendingSettledWeek ?? visibleWeek, maxWeek);
  }

  /// 翻页收尾（ScrollEnd）：落定可见周并排队写回 provider。
  void finalizeWeekPageSettled(
    TimetableProvider provider, {
    int? fallbackWeek,
    bool syncDayView = false,
  }) {
    final targetWeek = resolveSettledWeek(
      provider,
      fallbackWeek: fallbackWeek,
    );
    pendingSettledWeek = targetWeek;
    pendingCommittedWeek = targetWeek;
    applyVisibleWeek(
      targetWeek,
      rebuild: syncDayView || provider.settings.semesterStartDate == null,
      syncDayView: syncDayView,
    );
    unawaited(commitPendingWeek(provider));
  }

  /// 串行把待提交周次写回 provider（合并同一批内的重复目标）。
  Future<void> commitPendingWeek(TimetableProvider provider) async {
    if (_isCommittingWeek) {
      return;
    }
    _isCommittingWeek = true;
    try {
      while (host.isMounted) {
        final targetWeek = pendingCommittedWeek;
        if (targetWeek == null) {
          return;
        }
        if (targetWeek == provider.currentWeek) {
          pendingCommittedWeek = null;
          continue;
        }
        pendingCommittedWeek = null;
        host.selectionClick(provider.settings);
        await provider.setCurrentWeek(targetWeek, notify: false);
      }
    } finally {
      _isCommittingWeek = false;
    }
  }
}
