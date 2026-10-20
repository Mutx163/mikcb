import 'package:flutter/foundation.dart';

/// 周网格「长按空白格添加课程」的虚线标记状态（2026-10-20 从
/// `TimetableScreen` State 搬出）。
///
/// 只持有标记位置与拖边缘缩放基准，不碰 UI/导航；显示、清除、缩放的调用方
/// 通过 [onHaptic] 注入触觉反馈。
class EmptySlotMarkerController extends ChangeNotifier {
  int? _week;
  int? _dayOfWeek;
  int? _section;
  int? _endSection;
  bool _resizeIsTopEdge = false;
  int? _resizeBaseStart;
  int? _resizeBaseEnd;
  double _resizeAccum = 0;

  int? get section => _section;
  int? get week => _week;

  /// 虚线框在本列覆盖的节数：没有标记（或标记不在这一天/这一周）返回 0。
  int spanAt(int week, int dayOfWeek) {
    if (_week != week || _dayOfWeek != dayOfWeek) {
      return 0;
    }
    final start = _section;
    if (start == null) {
      return 0;
    }
    final end = _endSection ?? start;
    return end >= start ? end - start + 1 : 0;
  }

  void show(int week, int dayOfWeek, int section) {
    _week = week;
    _dayOfWeek = dayOfWeek;
    _section = section;
    _endSection = section;
    endResize();
    notifyListeners();
  }

  void clear() {
    if (_week == null && _dayOfWeek == null && _section == null) {
      return;
    }
    _week = null;
    _dayOfWeek = null;
    _section = null;
    _endSection = null;
    endResize();
    notifyListeners();
  }

  /// 按下虚线框上/下边缘（[isTopEdge]）时锚定本次缩放的基准框。
  void startResize(bool isTopEdge) {
    final start = _section;
    if (start == null) {
      return;
    }
    _resizeIsTopEdge = isTopEdge;
    _resizeBaseStart = start;
    _resizeBaseEnd = _endSection ?? start;
    _resizeAccum = 0;
  }

  void endResize() {
    _resizeBaseStart = null;
    _resizeBaseEnd = null;
    _resizeAccum = 0;
  }

  /// 拖上/下边缘时按手指位移把虚线框拉长或缩短。
  ///
  /// 位移换算成节数后还要过两道闸：① 不越出第 1 节 ~ 第 [sectionCount] 节，
  /// 且首尾不得交叉（框至少占一节）；② 新纳入的节次不能有课
  /// （[occupiedSections]），遇到第一节有课的格子就停在它前面——收缩方向
  /// 永远放开。
  void resize({
    required double deltaDy,
    required double sectionHeight,
    required int dayOfWeek,
    required int sectionCount,
    required Set<(int, int)> occupiedSections,
    required bool enableHaptics,
    VoidCallback? onHaptic,
  }) {
    final baseStart = _resizeBaseStart;
    final baseEnd = _resizeBaseEnd;
    if (baseStart == null || baseEnd == null) {
      return;
    }
    _resizeAccum += deltaDy;
    final delta = (_resizeAccum / sectionHeight).round();
    var newStart = baseStart;
    var newEnd = baseEnd;
    if (_resizeIsTopEdge) {
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
    if (newStart == _section && newEnd == _endSection) {
      return;
    }
    _section = newStart;
    _endSection = newEnd;
    notifyListeners();
    if (enableHaptics) {
      onHaptic?.call();
    }
  }
}
