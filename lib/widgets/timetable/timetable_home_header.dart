import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/hyperos/hyperos.dart';

/// 首页顶栏「更多」「爱心」的常驻玻璃球（可见图标层）。
///
/// **必须画在采样宿主之外**（由调用方 `_wrapHomeWithTopMenu` 摆进 Stack 的
/// 兄弟层）：页内玻璃的采样快照录自捕获节点的图层，球若长在捕获子树里，它自己
/// 的输出会被烘进下一次采样 —— 打开菜单时按钮被上游隐藏、快照是干净的，关闭后
/// 按钮重绘即触发重采样，球就"变一次材质"并稳定在烘过自己一层的样子。
List<Widget> buildTimetableHomeChromeBalls({
  required MiuixGlassPopupAnchor homeMenuAnchor,
  required LayerLink moreLink,
  required LayerLink heartLink,
  required bool hasPartnerBinding,
  required bool coupleOverlayActive,
  required Widget moreIcon,
  required Color chromeActionBallInk,
}) {
  return [
    ListenableBuilder(
      listenable: homeMenuAnchor,
      builder: (_, _) => FHeaderActionBall(
        link: moreLink,
        visible: !homeMenuAnchor.contentHidden,
        icon: moreIcon,
      ),
    ),
    // 爱心球与爱心按钮同门禁（hasPartnerBinding）：按钮不在树上时 LayerLink
    // 没有 leader，follower 会画在自己的布局位置（Stack 左上角）。
    if (hasPartnerBinding)
      FHeaderActionBall(
        link: heartLink,
        icon: Icon(
          coupleOverlayActive
              ? Icons.favorite_rounded
              : Icons.favorite_outline_rounded,
          color: coupleOverlayActive
              ? const Color(0xFFE91E63)
              : chromeActionBallInk,
        ),
      ),
  ];
}

/// 首页顶栏右侧的透明点击区（爱心 + 更多）。
///
/// 可见图标在 [buildTimetableHomeChromeBalls] 里；这里只留 24×24 的命中区域与
/// 锚点。点按行为、采样预热/释放与爱心态切换全部由调用方注入。
List<Widget> buildTimetableHomeHeaderActions({
  required AppLocalizations l10n,
  required bool hasPartnerBinding,
  required bool coupleOverlayActive,
  required LayerLink heartLink,
  required LayerLink moreLink,
  required MiuixGlassPopupAnchor homeMenuAnchor,
  required GlobalKey topMenuButtonKey,
  required VoidCallback onToggleCoupleOverlay,
  required VoidCallback onPrewarmGlass,
  required VoidCallback onReleaseGlass,
  required VoidCallback onShowTopActions,
}) {
  return [
    if (hasPartnerBinding)
      CompositedTransformTarget(
        link: heartLink,
        // 可见图标（爱心）画到采样宿主之外的常驻玻璃球上，这里只留透明点击区。
        child: FHeaderAction(
          icon: const SizedBox(width: 24, height: 24),
          semanticsLabel: coupleOverlayActive
              ? l10n.coupleTimetableModeDisableTooltip
              : l10n.coupleTimetableModeEnableTooltip,
          onPress: onToggleCoupleOverlay,
        ),
      ),
    // 两颗玻璃球之间的间距：顶栏后缀行是裸 `Row`（无 spacing），两个 40 宽按钮
    // 挨着 = 两颗球边缘相切；换成玻璃后各带描边 / 外阴影，相切读起来就是"贴得
    // 太近"。只在与爱心同时出现时插入，单独一颗时与原来一致。
    if (hasPartnerBinding) const SizedBox(width: 8),
    // 上游形变弹层要求把锚点绑在触发控件上（[MiuixGlassAnchor] 负责挂它自己的
    // GlobalKey）；[topMenuButtonKey] 仍保留，供「八宫格」形态在原位置弹出底部
    // 弹层用。按下即预热首页采样源：图层快照帧末录制，抬手打开菜单时已就绪，
    // 弹层首帧就是玻璃而不是透明轮廓。
    Listener(
      onPointerDown: (_) => onPrewarmGlass(),
      onPointerUp: (_) => onReleaseGlass(),
      onPointerCancel: (_) => onReleaseGlass(),
      child: CompositedTransformTarget(
        link: moreLink,
        child: MiuixGlassAnchor(
          anchor: homeMenuAnchor,
          child: KeyedSubtree(
            key: topMenuButtonKey,
            child: FHeaderAction(
              // 可见图标（含更新红点）画到采样宿主之外的常驻玻璃球上，这里只留
              // 透明点击区。
              icon: const SizedBox(width: 24, height: 24),
              semanticsLabel: l10n.moreTooltip,
              onPress: onShowTopActions,
            ),
          ),
        ),
      ),
    ),
  ];
}
