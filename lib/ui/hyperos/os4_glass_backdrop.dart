import 'package:flutter/widgets.dart';
import 'package:flutter_miuix/miuix.dart';

/// 全应用共享的 OS4 玻璃采样源（上游 `MiuixLayerBackdrop`）——**仅作最后兜底**。
///
/// 上游玻璃（`MiuixGlass` / 各类 `MiuixGlass*Popup`）**不自己抓背景**，而是从
/// 一个 [MiuixLayerBackdrop] 取快照。正常路径下快照由**屏级宿主**
/// （`HyperosGlassBackdropHost` + 其 `HyperosLayerBackdropCapture`）提供，
/// 弹层则通过 `HyperosGlassBackdropRegistry` 取到"压在它下面那一屏"的采样源。
///
/// ## 这个全局兜底为什么基本等于"没有玻璃"
///
/// `os4GlassBackdrop` **没有任何捕获者** —— 项目里没有任何 `Capture` 往它写快照。
/// 所以一旦某个玻璃走到"屏级宿主取不到"这条路（例如不在任何
/// `HyperosGlassBackdropHost` 子树里的页面弹层），它会拿到 null 快照，上游于是
/// 走"纯色轮廓 + 可绘制高光"的降级分支 —— 也就是**实底**。
///
/// 换句话说：**这不是"应用级捕获"，只是"别崩"的兜底**。改用它的地方要先确认
/// 自己真的取不到屏级采样源；能取到就该取。
///
/// ## ⚠️ 上游契约与当前实现的偏差
///
/// 上游原话：
///
/// > 必须放在 backdrop 捕获子树之外，防止反馈采样。
///
/// 本项目**尚未满足**这一条：宿主把捕获节点包在整页外面，而页内玻璃就在那棵
/// 子树里，于是玻璃采到的窄带含它自己上一帧的合成结果（滚动 / 转场的拖影来源）。
/// 弹层因为被 `OverlayPortal` 画到 Overlay 上，**天然在捕获之外**，不受影响。
///
/// 详见 `stable_frosted_surface.dart` 类注释里的「已知偏差」一节。
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
