// 从 timetable_screen.dart 拆出的空位添加标记与虚线框画笔（2026-10-19，行为零变化）。

import 'package:flutter/material.dart';

import '../../utils/home_page_background.dart';

/// 「长按空白格添加课程」的虚线加号标记（两步式交互的第二步目标）。
///
/// 视觉对齐参考截图：圆角虚线框 + 居中加号，尺寸跟随课程卡内缩与节高，
/// 整格可点，点击即打开预填位置的添加课程表单。
///
/// 框覆盖 [span] 节（高 = [span] × [sectionHeight]）：上下各有一条细横杠
/// 提示可拖，纵拖即改首尾节次（回调给外层，外层还要挡住有课的格子）。
class TimetableEmptySlotAddMarker extends StatelessWidget {
  const TimetableEmptySlotAddMarker({
    super.key,
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
      // 供测试定位「两步式添加」的虚线标记（也可按 TimetableEmptySlotAddMarker 类型定位）。
      key: const ValueKey('empty-slot-add-marker'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(inset),
        child: CustomPaint(
          painter: TimetableDashedRRectBorderPainter(
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
          alignment: isTopEdge ? Alignment.topCenter : Alignment.bottomCenter,
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
class TimetableDashedRRectBorderPainter extends CustomPainter {
  TimetableDashedRRectBorderPainter({required this.color, required this.fill});

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
  bool shouldRepaint(covariant TimetableDashedRRectBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.fill != fill;
}
