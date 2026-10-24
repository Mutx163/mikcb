import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../models/timetable_settings.dart';
import 'flight_grid_metrics.dart';

/// 日视图「卡片对卡片」转场在**课表页 State 侧**的那点胶水（2026-10-21）。
///
/// ## 为什么单独成类
///
/// `timetable_screen.dart` 有行数棘轮（只减不增，见
/// `test/architecture/timetable_screen_size_guard_test.dart`），而这三件事都不属于
/// 课表页的业务：
///
/// 1. 量「课表区域多高」（要 `timetableSurfaceKey` 那个 Padding 的 RenderBox）；
/// 2. 按同一口径算出网格节高（交给飞行起点用）；
/// 3. 判断「哪一天的原卡片该被飞行卡接管」。
///
/// 它们有先后约束（第 2 条依赖第 1 条的量测结果）和监听生命周期（第 3 条要跟着
/// 动画状态置脏），放在能单独读的地方比埋在 State 里稳妥。
///
/// ## 为什么要在转场开始/结束时各置脏一次
///
/// [flightSourceDayToHide] 读的是 `AnimationController.isAnimating`，而课表页的
/// `build` **不听**动画控制器（每帧重建整个首页太贵）。所以只在状态跃迁时
/// 主动重建一次 —— 一次开合总共多两次 build。
class FlightTransitionGlue {
  FlightTransitionGlue({
    required this.expandController,
    required this.surfaceKey,
    required this.rebuild,
  }) {
    expandController.addStatusListener(_onStatus);
  }

  /// 日视图展开进度控制器。
  final AnimationController expandController;

  /// 课表区域（周网格所在的那块）的 key：用来量真实高度。
  final GlobalKey surfaceKey;

  /// 请宿主重建一次（`setState`）。
  final VoidCallback rebuild;

  bool _disposed = false;

  void dispose() {
    _disposed = true;
    expandController.removeStatusListener(_onStatus);
  }

  /// 课表区域（周网格所在的那块）的真实高度。
  ///
  /// 必须从这里取，**不能**用 `MediaQuery.sizeOf(context).height`：后者是整屏
  /// 高度，比课表区域多出「状态栏 + 标题栏」，用它算自适应节高会偏大，于是飞行
  /// 起点的高度全错（实测起点只有 1px，卡片像从星期栏那条线上冒出来）。
  ///
  /// [fallback] 由宿主给（拿不到尺寸时回落到整屏高）。
  double surfaceHeight({required double fallback}) {
    final box = surfaceKey.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize && box.size.height > 0) {
      return box.size.height;
    }
    return fallback;
  }

  /// 网格节高 —— 与周页 `TimetableWeekPage` 交给网格的必须是同一个数。
  ///
  /// 口径收口在 [flightGridSectionHeight]（那边把「玻璃缝隙」也算进去了）。
  double gridSectionHeight({
    required TimetableSettings settings,
    required double fallbackHeight,
  }) {
    return flightGridSectionHeight(
      settings: settings,
      surfaceHeight: surfaceHeight(fallback: fallbackHeight),
    );
  }

  /// 转场途中「哪些课程卡该交给飞行卡」——返回要**藏掉原卡**的课程 id 集合。
  ///
  /// 为什么要藏：飞行卡在两端与真实卡片逐像素同位置（起点 = 网格卡、终点 =
  /// 议程卡）。原位置那张网格小卡若照旧画着，同一张课就有两份 —— 用户口径
  /// 「动画和卡片不是一对一缩放的」，主要指这个重影。
  ///
  /// ## 两条「不该藏」的判据（都是真机上会看见的毛病）
  ///
  /// 1. **转场没在跑**（`isAnimating` 之外：周视图静止、日视图停住）：网格该照常显示。
  /// 2. **这门课还没量到飞行终点**：飞行卡只在两端矩形都齐时才飞（缺终点硬猜
  ///    会落歪），此时若把原卡藏掉，这门课会在画面里**凭空消失**、落定后又出现。
  ///
  /// 第 2 条不是理论风险：议程列表是 `SliverList`，只构建可视范围内的项。
  /// 一天 8 门课时，屏幕外的几门在开场那一刻根本量不到终点 —— 而旧实现是
  /// **按整天藏**（`hideCourseCards: day == selectedDay`），于是那几门课直接消失。
  ///
  /// 所以这里按**每门课**给答案，不是按天。
  Set<String>? flightCardsToHide(Iterable<String> courseIdsOnDay) {
    if (!expandController.isAnimating) {
      return null;
    }
    final hidden = <String>{
      for (final id in courseIdsOnDay)
        if (hasFlightTargetFor(id)) id,
    };
    return hidden.isEmpty ? null : hidden;
  }

  /// 要交给飞行卡的课程 id（空集合 = 都不藏）。
  ///
  /// [week] / [day] 为 null（周视图 / 没有选中日）时一律不藏。[courseIds] 是当前
  /// 那一天的全部课程 id —— 逐个问 [hasFlightTargetFor]，只有量到终点的才藏。
  Set<String> hiddenCourseIds({
    required int? week,
    required int? day,
    required Iterable<String> courseIds,
  }) {
    if (week == null || day == null) {
      return const <String>{};
    }
    return flightCardsToHide(courseIds) ?? const <String>{};
  }

  /// 这门课本轮是否量到了飞行终点。
  ///
  /// 由宿主注入（读 `FlightTargetCache`）；默认 `false` —— 拿不到信息时**不藏**，
  /// 宁可重影一帧，也不要整门课消失。
  bool Function(String courseId) hasFlightTargetFor = (_) => false;

  /// 新一轮转场开始（**升空与收起都算**）：通知宿主 bump 终点代数。
  ///
  /// 为什么挂在 status 上而不是挂在点击处：点击 → 状态来不及更新（面板还没
  /// 布局，量不到终点），而状态跃迁就发生在「面板即将布局」那一刻。
  ///
  /// ⚠️ **必须连 `reverse` 一起 bump**（2026-10-23 审核发现）。
  ///
  /// 旧实现只认 `forward`：关闭转场沿用的是「打开那一轮」的终点代数。而
  /// `MeasureFlightTarget` 在「尺寸没变 + 代数没变」时会**直接早退**（位置漂移
  /// 不触发重量，这是为了别在滚动时每帧重建首页）。两件事叠起来的后果：
  ///
  /// 用户在日视图里**滚动过议程列表**（终点位置早已改变）再关闭 → 缓存里还是
  /// 打开那一刻的旧矩形 → 卡片朝一个空位置飞。而且因为代数没变，重测也被早退
  /// 挡掉，连"下一帧自己好起来"的机会都没有。
  ///
  /// 收起时 bump 一次，代价是重测一遍终点（每张卡一次布局读矩形），换来的是
  /// 关闭动画落点正确。
  void Function()? onTransitionStart;

  void _onStatus(AnimationStatus status) {
    if (_disposed) {
      return;
    }
    // 起飞与收起都开新代数：上一轮的终点全部作废。
    //
    // - `forward`：换日后再开，旧位置不能复用（原有逻辑）。
    // - `reverse`：日视图里可能滚动过，终点位置已经变了（2026-10-23 补）。
    //
    // `completed` / `dismissed` 不动代数：那时转场已经结束，没有飞行卡要落点。
    if (status == AnimationStatus.forward ||
        status == AnimationStatus.reverse) {
      onTransitionStart?.call();
    }
    // 四个状态都算「跃迁」：forward/reverse 是转场开始，completed/dismissed
    // 是结束。只在跃迁时重建，所以一次开合只多两次 build。
    _rebuildSafely();
  }

  /// 请宿主重建，但**避开 build 期**。
  ///
  /// ## 为什么不能直接 `rebuild()`
  ///
  /// 转场状态会在 **build 期**变化：`_restoreViewStateFromProvider`（切课表 /
  /// 冷启动恢复）在 `Consumer<TimetableProvider>` 的 builder 里直接写
  /// `_dayViewExpandController.value`。控制器状态一变就通知状态监听器 ——
  /// 于是我们在 build 期同步 `setState`，Flutter 直接抛：
  ///
  /// > setState() or markNeedsBuild() called during build.
  /// > This TimetableScreen widget cannot be marked as needing to build…
  ///
  /// 实测：`timetable_switcher_test` 的「switching profiles restores each
  /// profile timetable view state」两处必抛（切课表时恢复日视图 → value 0→1）。
  ///
  /// 推迟到帧后回调即可：这一次重建只用于「藏起原卡片 / 恢复原卡片」，晚一帧
  /// 没有观感代价 —— 起飞那一帧飞行卡与真卡逐像素重合，藏不藏看不出来。
  void _rebuildSafely() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) {
          rebuild();
        }
      });
      return;
    }
    rebuild();
  }
}
