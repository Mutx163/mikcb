import 'package:flutter/widgets.dart';
import 'package:flutter_miuix/miuix.dart';

/// 全应用共享的 OS4 玻璃采样源（上游 `MiuixLayerBackdrop`）。
///
/// 上游玻璃（`MiuixGlass` / 各类 `MiuixGlass*Popup`）**不自己抓背景**，而是从
/// 一个 [MiuixLayerBackdrop] 取快照；快照由包在**宿主页内容**外侧的
/// `MiuixLayerBackdropCapture` 提供。上游原话：
///
/// > 必须放在 backdrop 捕获子树之外，防止反馈采样
///
/// 两点推论（决定了接入形态）：
/// 1. 捕获子树**不能包含玻璃自身** —— 所以不能做"应用级捕获"，只能"哪个宿主页
///    用玻璃，就用它自己的捕获包住页面内容"，且**弹层必须留在捕获之外**。
/// 2. 弹层按上游契约是「常驻挂载 + 切 `show`」（见 `HomeTopMenuPopup` 与
///    `HyperosSelectPopup`），其 OverlayPortal 把面板画到 Overlay 上，因此
///    "在捕获之外"是天然成立的。
///
/// 同一时刻只应有一个捕获在树上（同时可见的两个宿主会互相覆盖；
/// 本项目不存在该场景）。宿主没包捕获时，上游玻璃自我降级为纯色轮廓，
/// 不会报错 —— 所以这是"要不要模糊/材质"的开关，不是必需前置。
final MiuixLayerBackdrop os4GlassBackdrop = MiuixLayerBackdrop();

/// 包住 OS4 玻璃弹层，隔断它与宿主页之间的滚动手势 / 通知耦合。
///
/// 上游弹层（`GlassPopupPresenter`）自带一个 `SingleChildScrollView` 包住内容，
/// 而 `OverlayPortal` 的 overlay child 在**元素树**上仍挂在调用处（只有绘制被送
/// 到 rootOverlay 的 theater 里），于是那个内部滚动视图：
///
/// 1. **继承宿主页的 [ScrollConfiguration]** —— 本项目的 `HyperosScrollBehavior`
///    给页面里所有滚动视图配 `AlwaysScrollableScrollPhysics` + 橡皮筋，于是弹层
///    内容**没超高也照样能被拖动**：只有两三条选择项的列表，上下拖会来回晃。
/// 2. 它发出的 [ScrollNotification] 会顺着元素树冒泡回宿主页，被
///    `_HyperosBlurredPage` 的滚动监听收下（`handleScroll` /
///    `_syncCollapseInsetDelta` 都按通知里的 `metrics.pixels` 驱动大标题），于是
///    **拖弹层里的列表会把页面的大标题收起成小标题**，而页面本身并没有滚动 ——
///    一个明显对不上的状态。
///
/// 这里两件事一起断掉：换成不带橡皮筋、无光晕的物理（内容真的放不下时仍能正常
/// 滚），并把弹层子树的通知截停，不再冒泡到宿主页。
class HyperosGlassPopupScrollGuard extends StatelessWidget {
  const HyperosGlassPopupScrollGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      // 返回 true = 已处理，通知不再向上冒泡到宿主页。
      onNotification: (_) => true,
      child: ScrollConfiguration(
        behavior: const _GlassPopupScrollBehavior(),
        child: child,
      ),
    );
  }
}

/// 弹层内容自己的滚动物理：能滚才滚，不要页面那套橡皮筋与光晕。
class _GlassPopupScrollBehavior extends ScrollBehavior {
  const _GlassPopupScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
