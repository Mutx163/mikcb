import 'dart:ui' show Rect;

/// 「卡片对卡片」转场的**飞行终点缓存**（2026-10-21）。
///
/// ## 为什么是一个可变缓存、而不是 State 字段
///
/// 飞行终点 = 议程卡在屏幕上的真实矩形。它只能在议程卡**布局完成之后**才量得
/// 到，而转场从点击那一刻就开始了 —— 也就是说终点和转场是「先有鸡还是先有蛋」：
/// 量到终点时要重建一次界面，但转场期间每帧本来就在由 `AnimationController`
/// 驱动重建。
///
/// 所以这里用一个**不触发重建**的普通可变容器承接：
///
/// - `MeasureFlightTarget` 量到之后**直接写进来**（不 setState）；
/// - 转场壳每帧读它（此时已经有了值）。
///
/// 如果写的时候调 `setState`，同一帧会多跑一遍 build，而结果要到下一帧才用得上。
///
/// 抽成独立文件而不是 State 私有字段：`timetable_screen.dart` 与
/// `timetable_day_view_part.dart` 一起构成一个**行数棘轮**（只减不增），
/// 而这段逻辑既不属于课表页的业务，也不属于日视图的排版。
class FlightTargetCache {
  final Map<String, Rect> _targets = <String, Rect>{};

  /// 本轮转场已量到的终点（按课程 id）。
  Map<String, Rect> get targets => Map<String, Rect>.of(_targets);

  /// 写一条测量结果。
  void record(String courseId, Rect globalRect) {
    _targets[courseId] = globalRect;
  }

  /// 取某门课的终点；没量到返回 null（调用方应跳过这张卡的飞行）。
  Rect? operator [](String courseId) => _targets[courseId];

  /// 清空：每次转场开始时调用，避免用上一轮的旧位置。
  ///
  /// 不清的后果很具体：换了选中日之后，新那天的课若还没量到，就会拿「同 id
  /// 课程上一次的屏幕位置」当终点——那张卡会朝一个早已不存在的位置飞过去。
  void clear() => _targets.clear();
}
