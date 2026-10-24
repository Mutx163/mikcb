import 'package:flutter/widgets.dart';

/// 「卡片对卡片」转场的**飞行终点缓存**（2026-10-21 建，2026-10-23 加代数与重测）。
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
/// ## 代数（generation）：为什么需要它
///
/// 只有 `courseId → Rect` 一张表是不够的：用户滚到议程列表底部关掉日视图、
/// 再开另一天，表里还留着上一轮的位置。开一次转场就 `bump()` 一代，写入带上
/// 当前代数、读取只认当代的值 —— 旧一代自动作废，不需要在某个时机精确 `clear()`
/// （历史 bug：`clear()` 从来没有被调用过，表里一直是上一轮的旧位置）。
///
/// ## 为什么还要 [clear]
///
/// 代数已经保证「旧轮次不会被读到」，[clear] 只是把内存放掉（开关几十次之后
/// 表会攒下几十门课的矩形）。转场结束时调一次即可，**不承担正确性**。
class FlightTargetCache {
  final Map<String, _Entry> _targets = <String, _Entry>{};

  /// 摘要卡「日期标题以下那整块」的 widget（真卡构建出来的那一份）。
  ///
  /// 为什么走缓存而不是参数一路传下来：那一块由**真卡自己**构建（它有全部数据：
  /// 考试、冲突、进行中、情侣空闲…），而转场层在屏幕那一侧构建，拿不到那些数据。
  /// 传一个 widget 比把十几项数据穿透三层要稳。
  ///
  /// **不按代数作废**：它描述的是「这一天长什么样」，换日时真卡会重建并覆盖它；
  /// 同一天重开时沿用旧值正好是对的。清内存走 [clear]。
  Widget? _summaryLower;

  /// 摘要卡（带关闭叉那张）的实测表面矩形，同样按代数的口径走。
  ///
  /// 单独一个字段而不是塞进 [_targets]（用课程 id 当键）：摘要卡不是课程，
  /// 挤进去会让「哪些课量到终点」的判定多出一个永远为真的项。语义分开更安全。
  _Entry? _summary;

  int _generation = 0;

  /// 当前代数（测试用）。
  int get generation => _generation;

  /// 上一代终点的兜底快照（只在一部分换代场景里存在，见 [bump]）。
  Map<String, Rect>? _fallback;

  /// 开新一轮转场：此后读取只认新一轮写入的值。
  ///
  /// [keepFallback] 为真时把当前这一代的值留作**兜底**：新一轮还没量到的 id
  /// 先沿用旧矩形。什么时候需要它（2026-10-24 补）：
  ///
  /// **中途反向**。用户展开到一半再点关闭 → `reverse` 也换代 → 全部终点作废
  /// → 而 `MeasureFlightTarget` 要到下一帧帧后回调才重新上报 → 中间那一帧
  /// `endRects` 全空 ⇒ 一张飞行卡都没有，而面板此刻高度为 0 ⇒ **整屏只剩周
  /// 网格**，闪一下。
  ///
  /// 反向时位置基本没变（刚刚才量过），沿用旧矩形完全够用；正向换日则必须硬作废
  /// （旧位置属于另一天，硬用会让卡片飞向错误的地方）。
  void bump({bool keepFallback = false}) {
    _fallback = keepFallback && _targets.isNotEmpty ? targets : null;
    _generation++;
  }

  /// 本轮已量到的终点（按课程 id）。
  ///
  /// 以**当代**的值为准；当代还没量到的 id 用 [bump] 留下的兜底快照（只有
  /// `keepFallback` 那一轮才有）。跨轮次的旧矩形在正向换日时会被硬作废，不会
  /// 让卡片朝另一天的位置飞过去。
  Map<String, Rect> get targets => {
    ...?_fallback,
    for (final entry in _targets.entries)
      if (entry.value.generation == _generation) entry.key: entry.value.rect,
  };

  /// 写一条测量结果。返回 `true` 表示**当代**值真的变了（调用方据此决定要不要重建）。
  bool record(String courseId, Rect globalRect) {
    final prev = _targets[courseId];
    final sameGeneration = prev != null && prev.generation == _generation;
    if (sameGeneration && _close(prev.rect, globalRect)) {
      return false;
    }
    _targets[courseId] = _Entry(globalRect, _generation);
    return true;
  }

  /// 取某门课的终点：当代优先，其次兜底快照，都没有才 null。
  Rect? operator [](String courseId) {
    final entry = _targets[courseId];
    if (entry != null && entry.generation == _generation) {
      return entry.rect;
    }
    return _fallback?[courseId];
  }

  /// 摘要卡**当代**的实测矩形；没量到（或只有旧代）返回 null。
  Rect? get summary =>
      _summary != null && _summary!.generation == _generation
      ? _summary!.rect
      : null;

  /// 写摘要卡的测量结果。返回 `true` 表示当代值真的变了。
  bool recordSummary(Rect globalRect) {
    final prev = _summary;
    if (prev != null &&
        prev.generation == _generation &&
        _close(prev.rect, globalRect)) {
      return false;
    }
    _summary = _Entry(globalRect, _generation);
    return true;
  }

  /// 记录摘要卡的下半部分（真卡每次构建都会调，幂等）。
  void recordSummaryLower(Widget section) {
    _summaryLower = section;
  }

  /// 摘要卡的下半部分；还没构建过时为 null（飞行卡就不画那一块）。
  Widget? get summaryLower => _summaryLower;

  /// 放掉内存（正确性不依赖它，见类注释）。
  void clear() {
    _targets.clear();
    _fallback = null;
    _summary = null;
    _summaryLower = null;
  }

  static bool _close(Rect a, Rect b) =>
      (a.left - b.left).abs() < 0.5 &&
      (a.top - b.top).abs() < 0.5 &&
      (a.width - b.width).abs() < 0.5 &&
      (a.height - b.height).abs() < 0.5;
}

class _Entry {
  const _Entry(this.rect, this.generation);

  final Rect rect;
  final int generation;
}
