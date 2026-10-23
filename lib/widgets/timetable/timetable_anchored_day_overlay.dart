import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/day_week_morph_layout.dart';
import '../../domain/flight_slot.dart';
import '../../models/timetable_settings.dart';
import '../../ui/hyperos/day_view_expand_motion.dart';
import 'flight_grid_metrics.dart';
import 'timetable_weekday_header.dart';
import 'morph_card_flight_layer.dart';
import 'summary_card_flight.dart';

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
class TimetableAnchoredDayOverlay extends StatefulWidget {
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

  /// 按课程 id 造「正在飞的那张卡」。
  ///
  /// 第三个参数是**当前帧的卡片表面尺寸**：卡内每行字的位置要按真实宽度
  /// 复算（议程卡课名 2 行、信息行省略号都依赖宽度），拿不到宽度就只能近似。
  final Widget Function(
    String courseId,
    double t,
    Size fromSurface,
    Size toSurface,
  )?
  buildFlightCard;

  /// 飞行**终点**：议程卡实测矩形，**全局屏幕坐标**（`localToGlobal` 的结果）。
  ///
  /// 未实测到（首帧前 / 命中不到）的课不会参与飞行 —— 硬猜一个终点会让卡片
  /// 落在错的地方，比不飞更难看。
  final Map<String, Rect> endRects;

  /// 网格节高（与 `domain/timetable_layout.dart` 的 `gridSectionHeight` 同一份）。
  final double sectionHeight;

  /// 周视图设置（只用来复算「星期栏与网格之间的玻璃缝隙」）。
  ///
  /// 起点是「相对网格内容区」算的，而本层的原点在星期栏下方 —— 有壁纸且星期栏
  /// 开了模糊时，周页在两者之间还插了一条 `homePageFrostedRegionSeamOverlap`
  /// （4dp）。不把这条缝隙算进去，起点会整体上移 4dp，卡片第一帧就偏上一截。
  final TimetableSettings settings;

  /// 卡片与格子边缘的间距（`courseCardInset`）。
  final double cardInset;

  /// 摘要卡飞行的两端输入（起点 = 星期栏当日格，终点 = 摘要卡实测矩形）。
  ///
  /// 为 null 时退回旧做法（把面板从上往下裁出一条）。用户口径（2026-10-23）：
  /// 「日视图带叉叉的日期卡片，能不能从顶部星期栏的当日的星期里面，一对一缩放
  /// 出来，效果和课程卡片差不多」—— 所以现在它也是一张**飞行的卡**，
  /// 与课程卡同一套机制、同一条曲线、同起同落。
  final SummaryFlightInput? summaryFlight;

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
    required this.sectionHeight,
    required this.settings,
    required this.cardInset,
    this.summaryFlight,
  });

  @override
  State<TimetableAnchoredDayOverlay> createState() =>
      _TimetableAnchoredDayOverlayState();
}

class _TimetableAnchoredDayOverlayState
    extends State<TimetableAnchoredDayOverlay> {
  /// 本层在屏幕上的原点，**帧后测得**。
  ///
  /// 为什么不能直接在 build 里读：`localToGlobal` 要求祖先链已完成布局，而
  /// `LayoutBuilder` 的 builder 恰好在**这一帧布局还没结束**时写出来 ——
  /// debug 下直接断言 `RenderBox was not laid out`（实测：恢复日视图那条路径
  /// 每次必炸，整块面板都不出来）。
  ///
  /// 所以走帧后回调，量到之后置脏一次。转场期间每帧本来就在重建，多这一次
  /// 只在首帧发生。
  Offset _layerOrigin = Offset.zero;

  @override
  void initState() {
    super.initState();
    _scheduleOriginMeasure();
  }

  @override
  void didUpdateWidget(covariant TimetableAnchoredDayOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 面板内容变了（换日 / 换周），本层位置可能跟着变。
    _scheduleOriginMeasure();
  }

  void _scheduleOriginMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) {
        return;
      }
      final origin = box.localToGlobal(Offset.zero);
      if ((origin.dx - _layerOrigin.dx).abs() < 0.5 &&
          (origin.dy - _layerOrigin.dy).abs() < 0.5) {
        return;
      }
      setState(() => _layerOrigin = origin);
    });
  }

  @override
  Widget build(BuildContext context) {
    final panel = widget.panel;
    final flightCards = widget.flightCards;
    final expandAnimation = widget.expandAnimation;
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
            //
            // 「减少动态效果」时控制器本来就被直接推到 1（见
            // `DayViewExpandMotion.reduceMotion`），这里不需要额外分支；但留一条
            // `disableAnimations` 的兜底：某些系统会把控制器推到一个中途值
            // （例如从恢复态重放），此时按落定处理，避免飞行卡停在半空。
            final settled =
                progress >= 0.999 ||
                (DayViewExpandMotion.reduceMotion(context) &&
                    expandAnimation.isAnimating == false);
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
                : _resolveFlightCards(viewportWidth, _layerOrigin);
            // 摘要卡不再走「露出比例」那条路（2026-10-23）：它自己是一张飞行
            // 卡，起点是星期栏当日格。面板全程高度 0，所以这里也不需要比例。
            // 摘要卡飞行：起点在这一层里算（这里已经知道层宽 / 时间列 / 天数 /
            // 选中下标），终点是调用方实测的屏幕矩形。
            final summaryFlight = widget.summaryFlight;
            final summaryFlightFrame = summaryFlight == null
                ? null
                : lerpSummaryFlight(
                    spec: summaryFlight.specInLayer(
                      layerOrigin: _layerOrigin,
                      startCell: summaryStartCellRect(
                        viewportWidth: viewportWidth,
                        timeColumnWidth: widget.weekTimeColumnWidth,
                        visibleDayCount: widget.visibleDayCount,
                        selectedDayIndex: widget.selectedDayIndex,
                        headerHeight: TimetableWeekdayHeader.height,
                      ),
                    ),
                    t: progress,
                  );

            return IgnorePointer(
              // 只在种子还很小的时候挡住输入（开头的收起尾段）。
              // 等 0.98 会让关闭按钮在大半个开启动画里不可点，widget 测试下
              // 也会 flaky。
              ignoring: progress < 0.05,
              child: Stack(
                fit: StackFit.expand,
                // ⚠️ **必须** `Clip.none`（2026-10-23 审核发现）。
                //
                // 摘要卡的起点在**本层上方**（`top = -星期栏高`，它就是要把自己
                // 压在星期栏那一格上）。`Stack` 默认 `Clip.hardEdge` 会把负区间
                // 那段整块裁掉 —— 于是「从星期格里长出来」的前 40% 在真机上什么
                // 都看不到，卡是凭空出现在层顶的。
                //
                // 为什么测试没抓到：`tester.getRect` 只读布局，不读绘制。布局里
                // 那张卡的位置一直是对的，画的时候才被裁。补的回归证据是
                // `test/domain/summary_card_flight_clip_test.dart`（截像素）。
                clipBehavior: Clip.none,
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

                  // ── 转场中 ─────────────────────────────────────────────
                  //
                  // 1）**摘要卡自己也是一张飞行的卡**（用户 2026-10-23 口径：要从
                  //    顶部星期栏的当日格里一对一缩放出来，效果和课程卡片差不多）。
                  //    起点 = 星期栏当日格，终点 = 摘要卡实测矩形，中间逐帧插值。
                  // 2）面板仍在**树上但不绘制**：飞行终点是议程卡布局完之后量到的
                  //    （`MeasureFlightTarget.performLayout`），面板一旦离开树就永远
                  //    量不到 —— 后果不是「精度差一点」，而是**一张卡都不飞**。
                  //
                  // ⚠️ 不能换成 `Offstage`：`find.byKey` 默认 `skipOffstage: true`，
                  // 面板会被找不着（`glass_dock_wallpaper_repro_test` 当场红）；也
                  // 不能换成 `Opacity(0)`：玻璃进半透明层会塌。用「高度 0 的裁剪」
                  // ——布局照跑、像素一个不画。
                  //
                  // 拿不到摘要卡终点时（首帧）退回「掀开一条」的老几何，好过整块
                  // 面板闪现。
                  if (!settled)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      // ⚠️ 高度必须**显式给**，不能靠 `Align(heightFactor:)`：
                      // `Stack(fit: StackFit.expand)` 给紧约束，而
                      // `RenderPositionedBox` 做的是 `constraints.constrain(
                      // childSize × factor)` —— 紧约束把它拉回满高，裁剪等于没
                      // 发生（实测层高 740 时仍 740，同一门课两份）。
                      // 高度恒 0：转场全程面板**不绘制**。
                      //
                      // 这里曾经在「摘要卡终点还没量到」时退回旧几何（露出
                      // `revealBottom × progress` 一条）。那会在**首帧**同时画出
                      // 面板顶部与飞行课程卡 → 同一门课重影；而首帧正是用户最容易
                      // 看出跳变的一帧。摘要卡现在自己有兜底（拿不到终点就停在
                      // 起点格上），面板没有理由再露。
                      height: 0,
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.topCenter,
                          minHeight: constraints.maxHeight,
                          maxHeight: constraints.maxHeight,
                          child: child ?? const SizedBox.shrink(),
                        ),
                      ),
                    ),

                  // 摘要卡飞行卡（画在面板上方、课程飞行卡下方：它俩不重叠）。
                  if (!settled)
                    if (summaryFlightFrame case final frame?)
                      Positioned.fromRect(
                        rect: frame.rect,
                        child: SummaryFlightCard(
                          frame: frame,
                          settings: widget.settings,
                        ),
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
  ///
  /// ## 坐标系（这里是这一版唯一容易错的地方）
  ///
  /// 三套坐标同时存在，必须一次性换算到「本层局部坐标」：
  ///
  /// - `weekCardRect` 给的是**相对网格内容区**（左上角 0,0，从星期栏下方算起）；
  /// - `endRects` 是 `localToGlobal` 的**全局屏幕坐标**；
  /// - `Positioned.fromRect`（`TimetableCardFlightLayer` 里）吃的是**本层局部**。
  ///
  /// 换算：`本层局部 = 全局 - layerOrigin`；`全局 = 网格局部 + 网格原点`。
  /// 网格原点 = 本层原点 + 星期栏高 + 玻璃缝隙（本层顶在星期栏底下，而网格
  /// 又在缝隙之下）。漏任何一个都会让起点偏移整整一截：
  ///
  /// | 漏掉的部分 | 现象 |
  /// |---|---|
  /// | 减去 `layerOrigin` | 起点偏下「状态栏 + 标题栏」那么多 |
  /// | 加上星期栏 40dp | 起点偏上 40dp |
  /// | 加上玻璃缝隙 4dp | 起点偏上 4dp |
  ///
  /// 终点同理只需减 `layerOrigin`（它本来就是全局的）。
  List<MorphFlightCard> _resolveFlightCards(
      double viewportWidth, Offset layerOrigin) {
    final build = widget.buildFlightCard;
    if (build == null || widget.daySlots.isEmpty || widget.endRects.isEmpty) {
      return const <MorphFlightCard>[];
    }
    final gridWidth = math.max(0, viewportWidth - widget.weekTimeColumnWidth);
    final dayWidth = math.max(
      kMorphMinColumnWidth,
      gridWidth / widget.visibleDayCount,
    );
    // 网格内容区在本层局部坐标里的原点：本层顶在星期栏下方，网格又在
    // 「星期栏 vs 网格」那条玻璃缝隙之下（无壁纸/未开模糊时缝隙为 0）。
    final gridOriginY = flightGridOriginYInLayer(widget.settings);
    final result = <MorphFlightCard>[];
    for (final slot in widget.daySlots) {
      final end = widget.endRects[slot.courseId];
      if (end == null) {
        continue;
      }
      final start = weekCardRect(
        timeColumnWidth: widget.weekTimeColumnWidth,
        dayWidth: dayWidth,
        dayIndex: widget.selectedDayIndex,
        sectionHeight: widget.sectionHeight,
        startSection: slot.startSection,
        endSection: slot.endSection,
        cardInset: widget.cardInset,
      );
      result.add(
        MorphFlightCard(
          courseId: slot.courseId,
          // 起点：网格局部 → 本层局部。
          from: MorphRect(
            left: start.left,
            top: start.top + gridOriginY,
            width: start.width,
            height: start.height,
          ),
          // 注意：`start` 已经是「卡片表面」矩形（`weekCardRect` 内含 inset），
          // 终点 `end` 是议程卡表面的实测矩形，两端同一口径。
          // 终点：全局 → 本层局部。
          to: MorphRect(
            left: end.left - layerOrigin.dx,
            top: end.top - layerOrigin.dy,
            width: end.width,
            height: end.height,
          ),
          builder: (t, fromSurface, toSurface) =>
              build(slot.courseId, t, fromSurface, toSurface),
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
