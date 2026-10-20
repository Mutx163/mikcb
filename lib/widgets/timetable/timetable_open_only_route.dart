// 从 timetable_screen.dart 拆出的「只开容器」形变路由（2026-10-19，行为零变化）。

import 'package:flutter/material.dart';

import '../../ui/hyperos/hyperos.dart';
import '../../ui/hyperos/hyperos_motion.dart';
import '../../utils/first_frame_probe.dart';
import '../../utils/frame_perf_probe.dart';

class TimetableOpenOnlyContainerPageRoute<T> extends PageRouteBuilder<T> {
  final Rect sourceRect;
  final WidgetBuilder builder;
  final Color backgroundColor;

  TimetableOpenOnlyContainerPageRoute({
    required this.sourceRect,
    required this.builder,
    required this.backgroundColor,
  }) : super(
         transitionDuration: 420.scaledMs,
         reverseTransitionDuration: Duration.zero,
         opaque: false,
         pageBuilder: (context, animation, secondaryAnimation) =>
             // 首帧拆解采样点（临时诊断件）。
             FirstFrameProbeNode(nodeTag: 'page', child: builder(context)),
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           final size = MediaQuery.of(context).size;
           final sourceCenter = sourceRect.center;
           final screenCenter = Offset(size.width / 2, size.height / 2);
           final alignment = Alignment(
             ((sourceCenter.dx / size.width) * 2).clamp(0.0, 2.0) - 1,
             ((sourceCenter.dy / size.height) * 2).clamp(0.0, 2.0) - 1,
           );
           // `.drive(CurveTween)` 而非 `CurvedAnimation`：后者构造器给 parent 挂
           // 状态监听、只有 dispose() 摘得掉，而这里每帧都跑（同 hyperos_navigation）。
           final curved = animation.drive(
             CurveTween(curve: Curves.easeInOutCubicEmphasized),
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
               final borderRadius = HyperosNavigation.morphRadius(progress, 22);
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
