import 'package:flutter/material.dart';

import '../../domain/day_week_morph_layout.dart';

/// 一张「正在飞的卡」：从周网格里的那个格子矩形，飞到日视图议程里那张卡的矩形。
class MorphFlightCard {
  const MorphFlightCard({
    required this.courseId,
    required this.from,
    required this.to,
    required this.builder,
  });

  /// 稳定标识（课程 id）：两端靠它配对同一张卡。
  final String courseId;

  /// 起点：周网格里那张**卡片表面**的位置与尺寸（已含 `cardInset` 的收缩）。
  final MorphRect from;

  /// 终点：日视图议程卡的**卡片表面**矩形（调用方实测）。
  final MorphRect to;

  /// 卡片本体。
  ///
  /// 参数：进度、**起点的卡片表面尺寸**、**终点的卡片表面尺寸**。
  ///
  /// 为什么给两端尺寸而不是当前帧尺寸：卡内每一行字的位置是「按两端各自的
  /// 真实排版算出来再插值」，两端尺寸是算锚点的输入；如果只给当前帧尺寸，
  /// 锚点就得每帧重算一遍（`TextPainter.layout` × 每帧 × 每卡）。
  final Widget Function(double t, Size fromSurface, Size toSurface) builder;
}

/// 卡片飞行层（2026-10-21 建，2026-10-23 加「当前表面尺寸」参数）。
///
/// ## 为什么是「每张卡自己插值」而不是「整块面板横向拉伸」
///
/// 用户要的观感是：**1、3、5 节有课，就是那三张卡各自放大成议程卡**。把面板
/// 裁成一条窄窗再拉宽，观感是「一张画被撑开」：卡片内容被拉伸、空节次的位置
/// 也没有意义。
///
/// 所以转场主体是**每张卡自己的矩形插值**：起点 = 它在网格里占的格
/// （`weekCardRect`），终点 = 它在议程列表里占的位（调用方实测）。两端排版
/// 完全不同（网格紧凑卡 ↔ 议程卡），但位置与尺寸可以连续，中间那一段读起来
/// 就是「这张卡在长大」。
///
/// ## 与玻璃材质的关系
///
/// 卡片是 `CourseSurface`（玻璃）。这条转场**不在卡片外面套 Opacity**：
/// `BackdropFilter` 在半透明层里采不到身后内容，磨砂会塌成透明（本仓铁律，
/// 见 `CourseSurface` 类注释）。所以「同时出现的其他卡」用 `Visibility` 藏、
/// 不用透明度淡出；卡**内部**的文字可以淡，因为那只是文字。
///
/// ## RepaintBoundary
///
/// 每张飞行卡一个边界：卡内容只在 `t` 变化时重画，外层矩形变化只是图层平移。
class TimetableCardFlightLayer extends StatelessWidget {
  const TimetableCardFlightLayer({
    super.key,
    required this.cards,
    required this.progress,
  });

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
              rect: _toUiRect(lerpMorphRect(card.from, card.to, progress)),
              child: RepaintBoundary(
                child: card.builder(
                  progress,
                  Size(card.from.width, card.from.height),
                  Size(card.to.width, card.to.height),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Rect _toUiRect(MorphRect r) =>
    Rect.fromLTWH(r.left, r.top, r.width, r.height);
