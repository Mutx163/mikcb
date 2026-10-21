import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/day_week_morph_layout.dart';

/// 一张「正在飞的卡」：从周网格里的格子矩形，飞到日视图议程里的卡片矩形。
class MorphFlightCard {
  const MorphFlightCard({
    required this.courseId,
    required this.from,
    required this.to,
    required this.builder,
  });

  /// 稳定标识（课程 id）：用来在两端之间配对同一张卡。
  final String courseId;

  /// 起点：周网格里那张卡的位置与尺寸。
  final MorphRect from;

  /// 终点：日视图议程里那张卡的位置与尺寸。
  final MorphRect to;

  /// 卡片本体。**同一个 widget 实例**在飞行全程复用（不要每帧重建）：
  /// 它内部是玻璃卡，重建会重新触发一次表层解析。
  final Widget Function(double t) builder;
}

/// 卡片飞行层（2026-10-21）。
///
/// ## 为什么需要它（以及为什么不能用「面板横向拉伸」）
///
/// 用户要的观感是：**1、3、5 节有课，就是这三张卡各自放大成日视图里的三张
/// 议程卡**。把整个面板裁成一条窄窗再横向拉宽，观感是「一张画被横向撑开」——
/// 卡片内容被拉伸、位置关系也不对（空节次的位置没有意义）。
///
/// 所以转场的主体是**每张卡自己的矩形插值**：起点 = 它在网格里占的格
///（`weekCardRect`），终点 = 它在议程列表里占的位（调用方实测）。
/// 两端排版完全不同（网格紧凑卡 ↔ 议程卡），但**位置与尺寸**可以连续，
/// 中间那一段读起来就是「这张卡在长大」。
///
/// ## 与玻璃材质的关系
///
/// 卡片是 `CourseSurface`（玻璃）。这条转场**全程不套 Opacity**：
/// `BackdropFilter` 在半透明层里采不到身后内容，磨砂会塌成透明（本仓铁律，
/// 见 `CourseSurface` 类注释）。所以「同时出现的其他卡」用 `Visibility` 藏、
/// 不用透明度淡出。
class TimetableCardFlightLayer extends StatelessWidget {
  const TimetableCardFlightLayer({
    super.key,
    required this.cards,
    required this.progress,
  });

  /// 参与飞行的卡（已按课程配对好起止矩形）。
  final List<MorphFlightCard> cards;

  /// 转场进度 0..1（**已过曲线**）。
  final double progress;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      // 飞行中的卡不接点击：点到一张正在动的卡，落点与用户预期不一致。
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (final card in cards)
            Positioned.fromRect(
              // RepaintBoundary：卡内容不变、只是外部矩形每帧在变，有边界时
              // 移动只是图层平移。
              rect: _toUiRect(lerpMorphRect(card.from, card.to, progress)),
              child: RepaintBoundary(child: card.builder(progress)),
            ),
        ],
      ),
    );
  }

  static Rect _toUiRect(MorphRect r) =>
      Rect.fromLTWH(r.left, r.top, r.width, r.height);
}

/// 飞行卡的尺寸随进度变化的辅助：字号/内边距的插值上限。
///
/// 单独抽出来是因为它要被卡片内部（标题字号、行数）复用，两处各写一遍会漂。
double flightTextScale(double t) => math.max(0, t.clamp(0.0, 1.0));
