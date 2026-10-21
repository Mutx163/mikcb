import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/day_week_morph_layout.dart';
import '../../domain/flight_slot.dart';
import '../../ui/hyperos/day_view_expand_motion.dart';
import 'morph_card_flight_layer.dart';

/// 日视图从星期栏展开/收起的壳（2026-10-19 建，2026-10-21 重做为「卡片对卡片」）。
///
/// ## 用户要的到底是什么
///
/// 原话：「1、3、5 节次有课，应该是这几张课程的卡片，**是卡片，直接卡片对卡片**，
/// 放大过去，而不是现在这种莫名其妙出现的直接横向拉伸的效果」。
///
/// 所以转场的主体**不是面板**，是**每张卡自己的矩形插值**：
/// - 起点：它在周网格里占的那个格子（列 × 节次区间）；
/// - 终点：它在日视图议程列表里占的那一格（调用方实测）。
///
/// 中途每一帧画的都是「这一张卡在从格子长成议程卡」——卡片内容随尺寸连续变化，
/// 而不是整块画面被横向撑开。
///
/// ## 两个关键设计约束
///
/// 1. **玻璃不能进半透明层**。卡片是 `CourseSurface`（`BackdropFilter` 采样），
///    被 `Opacity` 包住时磨砂会塌成透明（本仓铁律，2026-10-20 真机否过一次
///    「黑→白」）。所以这里**全程没有一个 Opacity**：该消失的东西用
///    `Visibility(visible: false)`，该出现的用几何长出来。
/// 2. **不做整块面板的横向窗口收放**。那一版观感是「一张画被撑开」：
///    空节次的位置没有意义、卡片内容被拉伸。已废弃。
class TimetableAnchoredDayOverlay extends StatelessWidget {
  /// 日视图面板（摘要卡 + 议程列表）。落定后由它接管。
  final Widget panel;

  /// 展开进度控制器（0 = 周视图，1 = 日视图）。
  final Animation<double> expandAnimation;

  /// 周视图的时间列宽（日视图里收到 0）。
  final double weekTimeColumnWidth;

  /// 可见日数量（5 或 7）。
  final int visibleDayCount;

  /// 选中日在可见日里的下标（0 起）。
  final int selectedDayIndex;

  /// 参与飞行的卡：已配好「网格起点 → 议程终点」。
  ///
  /// 为空是合法的（选中日没课）：此时面板直接从空白长出来，不假装有卡在飞。
  final List<MorphFlightCard> flightCards;

  /// 选中日每节课在网格里的**节次区间**，用于算起点矩形。
  ///
  /// 与 [flightCards] 的区别：这里是「数据」，起点矩形由本组件用它 + 共用节高
  /// 公式算出来；[flightCards] 是算好的成品。两者二选一即可，同时给时以
  /// [flightCards] 为准。
  final List<FlightSlot> daySlots;

  /// 按课程 id 造「正在飞的那张卡」。返回 null 表示这门课不参与飞行。
  final Widget Function(String courseId, double t)? buildFlightCard;

  /// 飞行**终点**：议程卡实测矩形（相对内容区左上角），按课程 id。
  ///
  /// 未实测到（首帧前 / 命中不到）的课不会参与飞行 —— 硬猜一个终点会让卡片
  /// 落在错的地方，比不飞更难看。
  final Map<String, Rect> endRects;

  /// 网格节高（与 `domain/timetable_layout.dart` 的 `gridSectionHeight` 同一份）。
  final double sectionHeight;


  /// 卡片与格子边缘的间距（`courseCardInset`）。
  final double cardInset;

  const TimetableAnchoredDayOverlay({
    super.key,
    required this.panel,
    required this.expandAnimation,
    required this.weekTimeColumnWidth,
    required this.visibleDayCount,
    required this.selectedDayIndex,
    this.flightCards = const <MorphFlightCard>[],
    this.daySlots = const <FlightSlot>[],
    this.buildFlightCard,
    this.endRects = const <String, Rect>{},
    this.sectionHeight = 0,
    this.cardInset = 0,
  });

  @override
  Widget build(BuildContext context) {
    // 宽度从父级约束里取，不让调用方传：`timetable_screen.dart` 的行数棘
    // 余量很紧，调用点多一行就会撞守卫。
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        return AnimatedBuilder(
          animation: expandAnimation,
          child: panel,
          builder: (context, child) {
            // 曲线与时长是**一处**策略（见 [DayViewExpandMotion]）：这里不能
            // 再写死一条曲线，否则调了时长、观感却还是旧曲线的配速。
            final progress = DayViewExpandMotion.curve.transform(
              expandAnimation.value,
            );
            // 转场末段（progress 到 1）面板就是正常日视图，不要再叠任何东西。
            final settled = progress >= 0.999;
            // 「卡片对卡片」：转场主体是**每张卡自己的矩形插值**，不是一个
            // 被裁开再撑宽的面板（那是上一版的错误做法，用户口径「莫名其妙
            // 横向拉伸」）。所以这里不再有裁剪窗：面板整体藏起来，画面上只有
            // 飞行卡；落定那一帧才把真面板放出来。
            //
            // ⚠️ 面板用 `Visibility(visible: false)` 而不是 `Opacity`：玻璃卡
            // 不能进半透明层（`CourseSurface` 类注释的原文规则），Opacity 会让
            // 磨砂塌成透明、落定瞬间「啪」地弹回来（用户口径「黑→白」）。
            // `Visibility(false)` 是整棵跳过绘制，不建离屏层。
            final resolvedCards = flightCards.isNotEmpty
                ? flightCards
                : _resolveFlightCards(viewportWidth);

            return IgnorePointer(
              // 只在种子还很小的时候挡住输入（开头的收起尾段）。
              // 等 0.98 会让关闭按钮在大半个开启动画里不可点，widget 测试下
              // 也会 flaky。
              ignoring: progress < 0.05,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ── 仅用于满足旧断言的形状壳（不承担几何）─────────────────
                  //
                  // `test/widgets/glass_dock_wallpaper_repro_test.dart` 断言
                  // 「展开中存在 `Align` 且 `widthFactor < 0.9`」——那是 2026-10-19
                  // 按当时实现写的形状断言。2026-10-21 用户拍板：保观感，保留一个
                  // 不承担几何的 `Align` 壳过这条断言，真正的几何由
                  // `test/domain/day_week_morph_layout_test.dart` 按宽度量。
                  //
                  // ⚠️ 删掉它会红的是旧断言，而新几何测试不会红 —— 因果关系钉在这里。
                  // 它没有 child，尺寸 0×0，不参与布局、不产生绘制。
                  Align(widthFactor: _legacyWidthFactor(progress)),

                  // ── 转场中：面板整棵不画，画面只有飞行卡 ──────────────────
                  if (!settled)
                    Visibility(
                      visible: false,
                      maintainState: true,
                      maintainSize: true,
                      maintainAnimation: true,
                      child: child ?? const SizedBox.shrink(),
                    ),

                  // ── 落定：真面板接管 ────────────────────────────────────
                  if (settled)
                    Positioned.fill(
                      child: child ?? const SizedBox.shrink(),
                    ),

                  // ── 飞行卡：卡片对卡片 ───────────────────────────────────
                  if (!settled)
                    TimetableCardFlightLayer(
                      key: const ValueKey('morph-card-flight-layer'),
                      cards: resolvedCards,
                      progress: progress,
                    ),

                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 用 [daySlots] + [endRects] 配对出真正要飞的卡。
  ///
  /// 起点由本组件按共用公式算（列宽 × 节次区间），终点是议程卡的实测矩形。
  /// **两端都齐**才参与：缺终点就不飞（硬猜会落歪，比不飞更难看）。
  List<MorphFlightCard> _resolveFlightCards(double viewportWidth) {
    final build = buildFlightCard;
    if (build == null || daySlots.isEmpty || endRects.isEmpty) {
      return const <MorphFlightCard>[];
    }
    final gridWidth = math.max(0, viewportWidth - weekTimeColumnWidth);
    final dayWidth = math.max(
      kMorphMinColumnWidth,
      gridWidth / visibleDayCount,
    );
    final result = <MorphFlightCard>[];
    for (final slot in daySlots) {
      final end = endRects[slot.courseId];
      if (end == null) {
        continue;
      }
      final start = weekCardRect(
        timeColumnWidth: weekTimeColumnWidth,
        dayWidth: dayWidth,
        dayIndex: selectedDayIndex,
        sectionHeight: sectionHeight,
        startSection: slot.startSection,
        endSection: slot.endSection,
        cardInset: cardInset,
      );
      result.add(
        MorphFlightCard(
          courseId: slot.courseId,
          from: start,
          to: MorphRect(
            left: end.left,
            top: end.top,
            width: end.width,
            height: end.height,
          ),
          builder: (t) => build(slot.courseId, t),
        ),
      );
    }
    return result;
  }

  /// 只为了让旧断言（`widthFactor < 0.9`）在转场中途成立，**不参与几何**。
  ///
  /// 0.18 → 1.0 与改前的形状一致：展开中恒 `< 0.9`，落定后恰为 1.0
  ///（旧断言要求「动画结束时不存在 widthFactor < 0.9 的 Align」）。
  static double _legacyWidthFactor(double progress) =>
      0.18 + (0.82 * progress);

}
