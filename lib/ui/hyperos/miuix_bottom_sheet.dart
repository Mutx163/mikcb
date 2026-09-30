import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

// 诊断标记：弹层开场卡顿的归因（临时件，见 utils/frame_perf_probe.dart）。
import '../../utils/frame_perf_probe.dart';
import 'hyperos_blurred_header.dart';
import 'hyperos_popup_glass.dart';
import 'hyperos_sheet.dart'
    show HyperosFrostedPanelScope, HyperosHostedSheetScope;
import 'liquid/liquid_glass_surface.dart';

/// 面板圆角：直接取上游默认值。
///
/// 注入面拿不到上游那个私有形状（`_TopSquircleBorder`）里的半径，只能用这个常量；
/// 而弹窗本身用默认值，所以写成「引用上游常量」而不是字面量 28，改上游时两边一起走。
const double hyperosMiuixBottomSheetCornerRadius =
    MiuixBottomSheetDefaults.cornerRadius;

/// 玻璃在**底边**往外多铺的逻辑像素（几何外溢，见 [hyperosMiuixBottomSheetSurface]）。
///
/// 底边比其它三条边多铺：底角在裁剪上是**直角**，而材质（含降级用的磨砂 / 实底）
/// 只能画**正圆角** —— 要让材质那个圆心在 `(r − k, H + k − r)` 的圆盖住直角角点
/// `(0, H)`，需要 `√2 × (r − k) ≤ r` → `k ≥ (1 − 1/√2) × r`，r = 28 时 = 8.2，取 **9**。
///
/// 底边铺到 9 是**无代价的**：面板底边就贴在屏幕最下沿，那一圈本来就在屏幕外。
/// 上沿与左右不外溢（材料边界与裁剪同一条线）。
///
/// 2026-09-20：原先上沿那条"贯屏长直边上的浅色线条"是靠给直段做**边缘观感淡出**
/// （`topRunFade`）压掉的；同批把材质的边光从「受光方向性」改成**一圈均匀**之后，
/// 上沿不再比其它三条边亮，那个补丁连同它的 uniform 一起删掉了 —— 留着反而会在
/// 直段与圆角的切点处切出一截接缝（用户报的"暗带在切点处戛然而止"）。
const double hyperosMiuixBottomSheetGlassBottomOverdraw = 9;

/// 请求收起底部弹窗。
///
/// [afterDismiss] 在**退场动画结束、面板真的消失之后**才执行 —— 「先关弹窗、
/// 再开下一个页面 / sheet」默认走它，不要再靠固定延时猜动画时长。
///
/// [immediate] 为 true 时跳过弹簧退场，立即摘掉承载壳和根覆盖层条目，再执行
/// [afterDismiss]。给「点入口就切整页」用：既要保证旧弹层不再压在新页面上，
/// 又不想让用户等完整弹簧收敛（这条路径真机可能等两三秒）。
///
/// 若退场期间已有更新弹窗压上来，旧承载壳不会执行 [afterDismiss]，避免旧动作
/// 越过新弹层；需要结束等待的调用方改接 [onSuperseded]。
typedef MiuixBottomSheetClose =
    void Function({
      VoidCallback? afterDismiss,
      VoidCallback? onSuperseded,
      bool? immediate,
    });

/// [showMiuixBottomSheet] 的 builder：内容 + 收起口子一起拿到。
typedef MiuixBottomSheetBuilder =
    Widget Function(BuildContext context, MiuixBottomSheetClose close);

/// 上游**通栏底部弹窗**（Miuix `MiuixWindowBottomSheet`）的承载壳。
///
/// ## 为什么用 Window 变体
///
/// 上游的底部弹窗有两个入口：`MiuixOverlayBottomSheet` 画在本仓脚手架的弹层宿主里
/// （要有 `MiuixScaffold` / `MiuixPopupHost`，本仓没有），`MiuixWindowBottomSheet`
/// 自己往**根覆盖层**插一个 `OverlayEntry`（不需要宿主）。两者渲染的是同一份
/// `_hosted`，外观与动效完全一致 —— 本仓用后者。
///
/// ## 为什么需要承载壳
///
/// 上游组件是**声明式**的（常驻 + `show` 切换，退场结束回调 `onDismissFinished`），
/// 而本仓弹层的调用面是**祈使式**的（`await showXxx(...)`，内容里用
/// `Navigator.pop()`）。这里压一条路由（[_MiuixBottomSheetRoute]，**不带挡点击的
/// 屏障**，理由见那个类），页面里常驻一个
/// `MiuixWindowBottomSheet`，对外仍是 `await showMiuixBottomSheet(...)`：
/// 内部照旧可以 `Navigator.pop()`（走本壳的收起口子），返回键由本壳的 `PopScope`
/// 接住（上游自己那个 `PopScope` 在根覆盖层里拿不到 `ModalRoute`，不生效）。
///
/// ## 材质：仍然是我们的液态玻璃
///
/// 面板走 [hyperosMiuixBottomSheetSurface] 注入；弹窗自带的压暗蒙层排在面板**之前**，
/// 所以同时注入 [UndimmedBackdropCapture] 作 `scrimUnderlay` —— 上游据此把覆盖层包进
/// `BackdropGroup`，玻璃以 `grouped` 采到**未压暗的页面**（少了这一步，玻璃会把那层
/// 蒙一起折进去、读感发灰）。蒙层色换成本仓口径（[HyperosBlurredHeader.modalBarrierColor]，
/// 液态玻璃下只有很轻的一层），不用上游 dialog 系的 0.3 / 0.6。
/// 依赖上游 `surfaceBuilder` + `scrimUnderlay` + `dimColor` 三个注入点
/// （本仓 fork 上的补丁，锁定来源见 `pubspec.yaml` 的 `dependency_overrides.flutter_miuix`）。
///
/// ## 顶部那 24dp（把手条）由承载壳统一让开
///
/// 上游把手条**悬浮**在内容之上（`dragHandleOverlaysContent`，见
/// [hyperosMiuixBottomSheetDragHandleHeight]），面板顶部不再被「把手条 24 + 空占位 18」
/// 占满。代价是那 24dp **画得到、点不到**（竖向拖动归把手，面板靠它拖走）。
///
/// 所以承载壳默认给内容加一段顶部留白（[reserveDragHandleStrip]），**别让每个调用方各自
/// 记得**：漏一个就是一个「最上面那颗按钮点不动」的弹窗（本仓真踩过 —— 弹层自测里那个
/// 「关闭」按钮正好落在那 24 里）。自带顶部控件、已经把这 24 排进自己布局的弹窗
/// （材质面板的顶部渐变模糊带）传 `false`。
///
/// ## 底部那截留白：为什么**滚动**的弹窗要把它挪进滚动内容里
///
/// 承载壳默认在内容**外面**垫一层「系统安全区 + [hyperosMiuixBottomSheetContentBottomGap]」。
/// 对**不滚动**的弹窗这是对的：内容就那么高，垫在外面等于给最后一行留出呼吸。
///
/// 但对**能滚动**的弹窗（材质面板是全 App 唯一一个）它是错的：垫在滚动视口**外面**，
/// 视口就会在离屏幕底「安全区 + 16」的地方停住，内容**滚不进去**——那一整截只能是一块
/// 空玻璃。内容多的时候它读起来就是「面板底下多了一块空白板」，也正是设置页面不会有的
/// 那种效果（设置页的列表是一路铺到屏幕底、从小白条底下穿过去的）。
///
/// 所以这类弹窗传 [scrollableBottomGap] = true：承载壳**不再垫底部**，滚动视口一路铺到
/// 屏幕底，让内容从 gesture bar 底下滚过去，由**滚动内容自己**带
/// `padding.bottom = 安全区 + 呼吸`（见 [bottomGapInsetOf]）。这样面板高度不变、最后一项
/// 仍然离小白条足够远，但中间不再有一段永远空的板。
Future<T?> showMiuixBottomSheet<T>({
  required BuildContext context,
  required MiuixBottomSheetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = false,
  Color? barrierColor,
  bool reserveDragHandleStrip = true,
  bool scrollableBottomGap = false,
}) {
  // 诊断标记沿用 `sheet:open`（这个弹窗就是「弹层开场」那一类，改用上游组件不换口径，
  // 历史读数仍然可比）。见 utils/frame_perf_probe.dart。
  FramePerfProbe.mark('sheet:open');
  final barrierActive = ValueNotifier<bool>(true);
  return Navigator.of(context, rootNavigator: useRootNavigator).push<T>(
    _MiuixBottomSheetRoute<T>(
      barrierActive: barrierActive,
      pageBuilder: (dialogContext, animation, secondaryAnimation) =>
          _MiuixBottomSheetPage(
            barrierActive: barrierActive,
            builder: builder,
            barrierDismissible: barrierDismissible,
            barrierColor: barrierColor,
            reserveDragHandleStrip: reserveDragHandleStrip,
            scrollableBottomGap: scrollableBottomGap,
          ),
    ),
  );
}

/// 首页 / 课程那批**贴底通栏弹窗**的入口（原 `hyperos_sheet.dart` 的实现）。
///
/// 2026-09-19 起由[上游底部弹窗][showMiuixBottomSheet]（`MiuixWindowBottomSheet`）承载：
/// 面板材质仍是本仓液态玻璃
/// （承载壳注入），几何、把手、蒙层、弹簧滑入与「只在把手上拖」的关闭手势都归上游。
/// 内容里的 [HyperosSheetFrame] / [HyperosSheet] 不用改 —— 承载壳用
/// [HyperosHostedSheetScope] 告诉它们「面板已经有了」，框自己让位。
///
/// 三个上游表达能力不同、已经去掉的参数（原先也没有调用方在用）：
/// `enableDrag`（上游只有把手可拖，不能整面板拖）、`padForKeyboard`（上游自带键盘
/// 处理）、`chrome`（上游只有通栏形态）。
///
/// ## ⚠️ 弹层开着时**不要**往上层推路由 / 弹层
///
/// 面板是上游 `MiuixWindowBottomSheet` **插进根覆盖层的条目**，而
/// `OverlayState.rearrange` 会把「非路由条目」排在所有路由**之上**
/// （`_insertionIndex(null, null) == _entries.length`）。于是弹层开着时推的任何路由都
/// 落在面板**下面**，被它那层全屏透明屏障挡住点击 —— 真机口径就是
/// 「页面在弹窗背后，什么东西都点不到」（2026-09-20 用户报的「调整壁纸显示位置」
/// 被壁纸弹窗压住，正是这一条）。
///
/// 正确姿势：调用方用 [SheetCloseRef] 把收起口子存下来，要推整页时先
/// `close(afterDismiss: ...)`，**等退场动画真正结束**（那一刻条目已摘掉）再推；
/// 如果用户要的是「点入口就立刻切页」，传 `immediate: true`，让承载壳立即摘掉
/// 根覆盖层条目再执行后续动作。不要靠固定延时猜动画时长。
Future<T?> showHomeHyperosSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool useRootNavigator = false,
  Color? barrierColor,
  SheetCloseRef? closeRef,
  bool reserveDragHandleStrip = true,
  bool scrollableBottomGap = false,
}) {
  return showMiuixBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: isDismissible,
    barrierColor: barrierColor,
    reserveDragHandleStrip: reserveDragHandleStrip,
    scrollableBottomGap: scrollableBottomGap,
    builder: (sheetContext, close) {
      closeRef?.call(close);
      return builder(sheetContext);
    },
  );
}

/// 收下弹层的收起口子的回调（见 [showHomeHyperosSheet] 的 `closeRef`）。
///
/// ⚠️ 它在**构建期**被调用（每次弹层重建都会来一次），实现方只应把口子存进字段，
/// 不要在回调里 `setState`。
typedef SheetCloseRef = void Function(MiuixBottomSheetClose close);

/// 承载壳用的路由：与 `showGeneralDialog` 造出来的那条只差**屏障不挡点击**。
///
/// 为什么敢去掉这条路障：挡下层点击本来就有两层，而真正干活的是面板自己那层
/// 全屏蒙层（它在根覆盖层里、被 `OverlayState.rearrange` 排在**所有路由之上**）。
/// 路由屏障那层是多余的，可它偏偏**活得最久**：它要等 `Navigator.pop()`
/// （= 退场弹簧数学收敛，实测约 832ms，而面板约 320ms 就滑出屏幕）才消失，于是
/// 「关掉这个弹窗、马上点下一节课」的第二下被它吃掉 —— 实测收起期间页面位置上
/// 命中的最上层就是 `ModalBarrier` 的 `MouseRegion`。
///
/// 无障碍那点能力不受影响：`barrierDismissible: false` 时 `ModalBarrier` 本来就
/// 不挂 dismiss 语义与动作，所以连 `barrierLabel` 也不需要了（`RawDialogRoute`
/// 不强制）。收尾时摘自己这条路由的口径见 `_MiuixBottomSheetPageState`。
class _MiuixBottomSheetRoute<T> extends RawDialogRoute<T> {
  _MiuixBottomSheetRoute({
    required this.barrierActive,
    required super.pageBuilder,
  }) : super(
         barrierDismissible: false,
         barrierColor: Colors.transparent,
         transitionDuration: Duration.zero,
       );

  final ValueNotifier<bool> barrierActive;

  /// 保留 Flutter 路由屏障的无障碍隔离和首帧点击隔离；面板开始退场时
  /// 只关闭它的指针命中，让下层立即可点，不能让读屏语义也随之穿透。
  @override
  Widget buildModalBarrier() {
    return ValueListenableBuilder<bool>(
      valueListenable: barrierActive,
      builder: (context, active, _) => IgnorePointer(
        ignoring: !active,
        child: const ModalBarrier(
          color: Colors.transparent,
          dismissible: false,
        ),
      ),
    );
  }

  @override
  void dispose() {
    barrierActive.dispose();
    super.dispose();
  }
}

class _MiuixBottomSheetPage extends StatefulWidget {
  const _MiuixBottomSheetPage({
    required this.barrierActive,
    required this.builder,
    required this.barrierDismissible,
    this.barrierColor,
    this.reserveDragHandleStrip = true,
    this.scrollableBottomGap = false,
  });

  final ValueNotifier<bool> barrierActive;
  final MiuixBottomSheetBuilder builder;
  final bool barrierDismissible;
  final Color? barrierColor;

  /// 内容是否自带「让开把手条」的顶部留白（见 [showMiuixBottomSheet] 同名参数）。
  final bool reserveDragHandleStrip;

  /// 内容**能滚动**、底部留白改由滚动内容自己带（见 [showMiuixBottomSheet]
  /// 同名参数与那节说明）。
  final bool scrollableBottomGap;

  @override
  State<_MiuixBottomSheetPage> createState() => _MiuixBottomSheetPageState();
}

class _MiuixBottomSheetPageState extends State<_MiuixBottomSheetPage> {
  /// 面板当前该不该在场：上游靠它驱动滑入 / 滑出。
  bool _visible = true;

  /// 收起时要接着做的事。退场期间可以再次 close；每次等待都必须被消费，
  /// 不能因为 visible 已经为 false 就把后来的 afterDismiss 静默丢掉。
  final List<(VoidCallback?, VoidCallback?)> _dismissCallbacks = [];

  bool _popped = false;

  void _requestClose({
    VoidCallback? afterDismiss,
    VoidCallback? onSuperseded,
    bool? immediate,
  }) {
    if (_popped) {
      onSuperseded?.call();
      return;
    }

    // 退场开始就交出路由屏障的指针命中，但保留语义隔离；同时撤掉旧面板焦点，
    // 避免隐藏的输入框继续接收键盘事件。
    if (widget.barrierActive.value) {
      widget.barrierActive.value = false;
    }
    FocusManager.instance.primaryFocus?.unfocus();

    if (afterDismiss != null || onSuperseded != null) {
      _dismissCallbacks.add((afterDismiss, onSuperseded));
    }

    if (immediate == true) {
      _dismissImmediately();
      return;
    }

    if (!_visible) {
      return;
    }
    setState(() => _visible = false);
  }

  /// 立即摘掉承载壳和窗口层，给「关弹层后立刻切整页」的入口使用。
  ///
  /// 不用固定延时猜面板滑出的时刻：这里直接走 Navigator 的立即移除路径，
  /// 路由 dispose 会同步触发 MiuixWindowBottomSheet 的窗口层清理，随后才跑
  /// 已登记的后续动作。因此调用方可以马上推页，又不会把根覆盖层里的旧面板留在
  /// 新页面上面。
  void _dismissImmediately() {
    final dismissCallbacks = List.of(_dismissCallbacks);
    _dismissCallbacks.clear();
    final route = ModalRoute.of(context);
    if (route == null) {
      _finishDismissCallbacks(dismissCallbacks, superseded: true);
      return;
    }
    final navigator = Navigator.of(context);
    final wasCurrent = route.isCurrent;
    _popped = true;
    navigator.removeRoute(route);
    _finishDismissCallbacks(dismissCallbacks, superseded: !wasCurrent);
  }

  void _onDismissFinished() {
    if (_popped) {
      return;
    }
    _popped = true;
    final dismissCallbacks = List.of(_dismissCallbacks);
    _dismissCallbacks.clear();
    // 摘掉**自己这条**路由，按"上面有没有压别的东西"分两条路：
    //
    // · 上面没压别的（最常见的"关掉就完事"）：照旧 `pop()` —— 与改前一字不差。
    //   观察者拿到的还是 didPop，首页 / 子页的模糊门（`HyperosRouteBlurGate`）靠
    //   它的 didPopNext 在弹窗关掉后重同步毛玻璃；SDK 的 `RouteObserver` 只覆写了
    //   didPop / didPush、**没有 didRemove**，这条路要是改成 removeRoute，那次
    //   重同步会悄悄消失。
    //
    // · 上面已经压了别的路由（收起一开始就把输入还给页面了，用户完全可能在这段
    //   退场动画里立刻点开下一节课 / 另一个弹窗）：这时 `pop()` 摘的是**栈顶**那条
    //   —— 会把刚开的这个弹窗弹掉、自己反而留在栈上，只能 removeRoute 摘自己。
    //   本条路由的转场时长是 0，两条路在"何时消失"上没有区别，只差"摘谁"与
    //   "通知谁"；而这种情形下首页也谈不上"重获可见"（上面还有别的层）。
    //
    // 判断与摘除之间没有 await，单线程事件循环里不会插进别的路由操作。
    final route = ModalRoute.of(context);
    if (route == null) {
      _finishDismissCallbacks(dismissCallbacks, superseded: true);
      return;
    }
    final wasCurrent = route.isCurrent;
    final navigator = Navigator.of(context);
    if (wasCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
    // 先摘路由，再跑后续动作：后续动作常常立刻 push 下一个页面 / sheet，
    // 面板已经彻底消失，两者不会叠在一起。若上面已有新路由，旧动作不能越级执行；
    // 需要结束等待的一方接 onSuperseded，避免 Future 永久挂住。
    _finishDismissCallbacks(dismissCallbacks, superseded: !wasCurrent);
  }

  void _finishDismissCallbacks(
    List<(VoidCallback?, VoidCallback?)> callbacks, {
    required bool superseded,
  }) {
    for (final (afterDismiss, onSuperseded) in callbacks) {
      (superseded ? onSuperseded : afterDismiss)?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _requestClose();
        }
      },
      child: MiuixWindowBottomSheet(
        show: _visible,
        // 圆角用上游默认值（= [hyperosMiuixBottomSheetCornerRadius]，注入面按它画玻璃）。
        onDismissRequest: widget.barrierDismissible ? _requestClose : () {},
        onDismissFinished: _onDismissFinished,
        dimColor:
            widget.barrierColor ??
            HyperosBlurredHeader.modalBarrierColor(context),
        dragHandleColor: Theme.of(context).colorScheme.onSurfaceVariant,
        // 把手条**悬浮**在内容之上（上游 `dragHandleOverlaysContent`，2026-09-27 加）：
        // 面板顶部那 42（把手条 24 + 无标题时的空占位 18）里什么都没有，内容从 42 才开始 ——
        // 顶部空一大块，而且那 42 背后没有内容，画在这截上的顶部渐变模糊永远糊不到东西
        // （用户口径 2026-09-27：「在那个材质页面，这个拉杆底下怎么做都不能显示模糊效果」）。
        // 悬浮之后内容从面板上沿起、能滚到把手底下，模糊才真的有内容可糊。
        //
        // 本仓的弹窗一律不传上游 `title`（标题都是自己画在内容里的），所以「有标题行就
        // 维持原布局」那条分支不会命中。
        dragHandleOverlaysContent: true,
        // 左右内边距拉回本仓口径（上游默认 24，见该常量的说明）。
        insideMargin: const Size(hyperosMiuixBottomSheetInsideMargin, 0),
        surfaceBuilder: hyperosMiuixBottomSheetSurface,
        scrimUnderlay: const UndimmedBackdropCapture(),
        content: HyperosHostedSheetScope(
          // 面板是本仓液态玻璃 → 告诉内容「你站在磨砂面板上」（次要按钮的填充色
          // 靠它保持可读），同时告诉 HyperosSheetFrame「别再画一层面板」。
          child: HyperosFrostedPanelScope(
            child: Padding(
              // 上游面板只按**键盘**（viewInsets）留底部内边距，不管系统手势区 / 导航栏
              // （`MediaQuery.padding.bottom`）—— 不留这一层，最后一行按钮会贴到屏幕
              // 最下沿、被手势条压住（用户口径：「调课停课什么的都到底部屏幕外面去了」）。
              // 口径与改动前的 edge sheet 一致：安全区 + [..ContentBottomGap]。
              // 键盘弹起时 `padding.bottom` 在 Android 上会归零，不会与上游那层叠成双份。
              //
              // 顶部那层是**让开悬浮的把手条**（上游 `dragHandleOverlaysContent`：把手条
              // 浮在内容之上、吸收命中，所以内容顶 24 里的按钮会点不动）。默认由**这里**
              // 统一加，别让每个调用方各自记得 —— 漏一个就是一个「按钮点不动」的弹窗。
              // 自带顶部控件的弹窗（材质面板：顶部渐变模糊带自己把这段高度排掉了）传
              // `reserveDragHandleStrip: false`。
              //
              // 底部那层是系统手势区 + 呼吸。`scrollableBottomGap` 的弹窗**内容能滚动**，
              // 这里垫 0，让视口一路铺到屏幕底、内容从 gesture bar 底下滚过去，改由
              // 滚动内容自己带 [bottomGapInsetOf]（否则那一截永远是一块空玻璃板 ——
              // 见 [showMiuixBottomSheet] 那节说明）。
              padding: EdgeInsets.only(
                top: widget.reserveDragHandleStrip
                    ? hyperosMiuixBottomSheetDragHandleHeight
                    : 0,
                bottom: widget.scrollableBottomGap
                    ? 0
                    : bottomGapInsetOf(context),
              ),
              child: widget.builder(context, _requestClose),
            ),
          ),
        ),
      ),
    );
  }
}

/// 内容底部额外留的呼吸（系统安全区之外）。与改动前 edge sheet 的 16 一致。
const double hyperosMiuixBottomSheetContentBottomGap = 16;

/// 底部那截留白的**唯一真源**：系统手势区 + 上面那份呼吸。
///
/// 承载壳自己在内容外面垫它（[showMiuixBottomSheet] 的 `scrollableBottomGap` 为假时）；
/// 内容能滚动的弹窗传 `scrollableBottomGap: true` 改由**滚动内容**带，于是同一个数要从
/// 这里取（加在 `ScrollView.padding` 上，**不是**加在 body 外面 —— 加在外面视口不会延伸，
/// 那一截仍然是空板）。
double bottomGapInsetOf(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom +
    hyperosMiuixBottomSheetContentBottomGap;

/// 面板内容的**左右**内边距（逻辑 px）。
///
/// = [HyperosSheetFrame] 的默认内边距，也就是改动前每个弹层内容的左右内边距：
/// 那时由框自己 `Padding(16)`，内容再自带一份（如壁纸弹窗的行另有 16）。
///
/// ⚠️ **必须显式给**：上游 `MiuixWindowBottomSheet` 的默认 `insideMargin` 是
/// `Size(24, 0)`，而迁到上游承载后 [HyperosSheetFrame] 的内边距在托管模式下被忽略
///（「内边距归外层」），于是左右悄悄从 16 变成 24、整体比改动前宽了 8dp ——
/// 用户口径「弹窗里左右边距留得那么大」（2026-09-20，壁纸弹窗）。这里把它拉回本仓
/// 自己那份口径。上下不设（内容自己管）。
const double hyperosMiuixBottomSheetInsideMargin = 16;

/// 面板顶部那条**把手条**的高度（逻辑 px）。
///
/// = 上游 `MiuixWindowBottomSheet._dragHandle` 那个 `SizedBox(height: 24)`（把手里那颗
/// 45×4 的小条居中，占 10~14）。
///
/// 2026-09-27 起上游把手条**悬浮**在内容之上（`dragHandleOverlaysContent`），不再占面板
/// 高度 —— 面板顶部原先那 42（这 24 + 无标题时的空占位 18）里什么都没有，内容从 42 才有
/// 开始：顶部空一大块，而且那截背后没有内容，画在上面的顶部渐变模糊永远糊不到东西。
///
/// 悬浮的代价：那 24px 变成「画得到、点不到」的一层 —— 竖向拖动归把手（面板靠它拖动、
/// 拖走），所以**任何按钮都不能放在这 24px 里**。承载壳默认给内容加这段留白
/// （`showMiuixBottomSheet` 的 `reserveDragHandleStrip`）；自带顶部控件、已经把这 24 排
/// 进自己布局的弹窗（材质面板的顶部渐变模糊带）传 `false`。
///
/// 它同时是**唯一**的拖动提示，所以模糊带只能盖在它下面、绝不能糊它（糊了就是一块板，
/// 2026-09-26/27 连续三次返工都是这条边界）。
const double hyperosMiuixBottomSheetDragHandleHeight = 24;

/// 这块面板的玻璃**一律不外推采样**（[LiquidGlassSurface.maxRefraction] = 0）。
///
/// 这是**几何适配**、不是材质参数（同返回键圆钮那颗 `maxRefraction: 0`）：材质旋钮仍只从
/// 材质那一个出口出，这里压的只是"边缘朝外推多远"。取 0 的理由与症状见
/// [hyperosMiuixBottomSheetSurface] 的「上沿那条线」一节。
const double hyperosMiuixBottomSheetMaxRefraction = 0;

/// 把上游底部弹窗的实底面板换成**本仓贴底液态玻璃**：上沿两角按
/// [hyperosMiuixBottomSheetCornerRadius] 圆角，上沿与左右**不外溢**（材料边界与裁剪
/// 同一条线），底边往外铺 [hyperosMiuixBottomSheetGlassBottomOverdraw]（9，为了盖住
/// 直角底角）。
///
/// ⚠️ 「材料边界与裁剪线**同一条线**」这件事是**载荷条件**，不只是形状描述：边缘朝外推的
/// 位移会因此读到裁剪区之外（读空）。所以上沿与左右不外溢**必须**配上
/// [hyperosMiuixBottomSheetMaxRefraction]（0）—— 两者是一套，别只改一边。
///
/// ## 轮廓用**和材质同一条曲线**裁
///
/// 上游自己那个形状是私有类 `_TopSquircleBorder`：三次贝塞尔画的角，比同半径正圆
/// 更接近直角；而我们的材质只画正圆角。拿它当裁剪，圆角处两条曲线最大差 **1.35px**，
/// 那一条缝里没有玻璃、透出压暗过的页面 —— 真机上就是「外框一个圆角、里面还有一个
/// 更小的圆角」。所以裁剪改用**材质画的那条曲线**（上沿两角正圆角、底边直边），
/// 「外面裁的」与「材质画的」是同一条线，缝从根上没有了。
/// 代价：面板上沿两角的轮廓与上游那条曲线最多差 1.35px（肉眼看不出来），
/// `shape` 参数因此**不再参与裁剪**（半径仍从 [hyperosMiuixBottomSheetCornerRadius]
/// 出，上游改半径这边跟着走）。
///
/// ## 上沿那条线：材质参数一个都不加，只把**边缘的朝外位移**压到 0
///
/// 材质画在边界上的那一圈在这块面板上有两种读法：**圆角上**是"玻璃的反光边"（用户口径：
/// 圆角位置处理得非常好），**两个上角之间那条贯屏长直边**上是一条线。前后十几轮都在参数上
/// 打转（整圈推走、只推峰值、压折射、给直段做局部淡出、把高光收成发丝），直到 2026-09-20
/// 重新推导边光才把病根找齐：
///
/// 1. **方向性**：均匀口径的边光 alpha 只按"离边多远"算，这边的边光按
///    `dot(法线, 光来向)` 加权 —— 上沿恰好是被照得最亮的那条边（0.87 vs 下沿 0.35，
///    差 2.9 倍），在长直边上就成了一条线。
/// 2. **截面**：均匀口径的边光是「贴边一小段满亮度平台 + 向内 smoothstep 羽化」，这边是
///    「贴边最亮、往里二次衰减」—— 峰值正好压在抗锯齿的半像素过渡带里，圆角上读出锯齿。
///
/// 两条都已从材质层面解决（见两个 `.frag` 的文件头）。原先给直段做的 `topRunFade` 局部
/// 淡出、以及这里一度给长直边加的 `maxRefraction` 折射上限（= 3），**都是补方向性那场病的
/// 药，已同批删掉**。
///
/// ### 第十五轮（2026-09-22）：上沿那条**暗色**线 —— 位移压到 0
///
/// 用户口径：「课程弹窗、外观编辑的材质弹窗等等这些弹窗……改成和设置页面返回键的那个圆
/// 一样的边缘高光，不然现在顶部有暗色线」。
///
/// 成因与返回键圆钮那条暗弧**是同一个引擎行为**（见
/// `.agents/notes/implemented/bug-fix/2026-09-21-subpage-back-button-edge-no-outward-sampling.md`）：
/// 引擎给 backdrop filter 准备背景时，可采范围被掐在「**渲染目标 ∩ 当前裁剪区**」
/// （Impeller `Canvas::GetLocalCoverageLimit → GetSourceCoverage`）。而这块面板外面罩着一层
/// `ClipRRect`（见上一节「轮廓」），**它的上沿与本面板的上沿是同一条线**（上沿刻意不外溢）
/// ⇒ 上沿那一圈像素的朝外位移（标准档 8dp、贴边取峰值）第一步就探出裁剪区、读空，压在
/// 染色底上就是一条暗线。左右下三边没有这个症状：底边往外铺了 9px（裁剪线落在形状之外）、
/// 左右两边的裁剪线落在屏幕之外。
///
/// 修法沿用返回键圆钮那颗的取舍：**边缘不外推采样**（`maxRefraction = 0`，见
/// [hyperosMiuixBottomSheetMaxRefraction]）—— 板内每个像素只取正下方那一个像素，暗线从
/// 结构上不可能出现。
///
/// **这同时解开了 2026-09-20 记下的那个"二选一"**。当时逐轮量下来只看到两个稳定状态：
/// 留着那圈（有边缘反光，上沿会有一条很淡的线）或推光（上沿干净，但边缘没有反光），并断言
/// "没有中间档"。那是因为把**受光高光**与**折射带**当成了一件事：现在只掐掉折射（位移 0），
/// 受光高光**照旧画在贴边那一圈**（`rimBand` 只由"离边多远"算、与位移无关）⇒ 上沿既有
/// 边光、又没有那条线。
///
/// 代价如实记：边缘那圈**透镜感**（把面板外的内容拉进边缘）随之消失，圆角读作"一圈边光的
/// 弧"，而不是"折射出来的厚玻璃角"。这是用户 2026-09-21 为返回键圆钮拍过的同一条取舍，
/// 也是这次点名的口径（"和那个圆一样"）。
///
/// ⚠️ 与右上角菜单弹窗（同属弹窗家族、锁同一档）的差别是**故意的、且只由几何决定**：那是块
/// **有自由周边的浮起卡片**，边缘折射落在画面里、是正常的透镜边（留着）；这块面板的上沿压在
/// **自己那层裁剪线**上，折射在那里只会读空。判据是"这条边外面有没有可采的内容"，不是"哪块
/// 面板更好看" —— 口径仍是"面板不带材质参数"，这次压的是几何。
///
/// 于是现在这块面板**没有任何自己的材质参数**：只提供几何（圆角、底边外溢、折射上限）与
/// [LiquidGlassRole.pinnedChrome] 这个作用域，参数全从材质那一个出口出。这正是
/// `LiquidGlassSurface` 类注释里那条硬规则要的样子 —— 以后要动边缘观感，动材质，
/// 不要再在这块面板上开参数口子。
///
/// ## 底边外溢 9px
///
/// 底边两角在裁剪上是**直角**，材质却是正圆角 —— 不外溢的话两个底角会各缺一小块
/// （`k ≥ (1 − 1/√2) × r` ⇒ 9）。它贴在屏幕最下沿，推出去没有任何代价。降级材质
/// （磨砂 / 实底）与玻璃面共用同一个矩形，所以它们的底角也一起被盖住。
///
/// ## 浮影：与右上角那个菜单弹窗**同源**
///
/// 面板外面衬一层 [HyperosGlassShadow]（数值、单层浮影都跟弹层家族完全一样）。为什么必须
/// 有：用户 2026-09-20 对比右上角菜单弹窗时指出「这块看起来明显不一样」—— 那个弹窗是
/// `surfaceShadow: true`（浮在页面上），而贴底弹窗原来换上来的实底面板从来不带浮影。
/// 少了这层，面板读起来是"贴在页面上的一块"，边缘也就没有"受力"的那种感觉。
///
/// 浮影必须包在 `ClipRRect` **外面**（阴影本来就落在面板轮廓之外，被裁掉就等于没有）；
/// 形状用与面板一致的「上沿两角圆、底边直」。左右与下方贴在屏幕边上，实际只看得到上沿
/// 那条淡淡的暗边 —— 那正是它要交代的"这是浮在页面之上的一层玻璃"。
///
/// 材质分派直接复用弹层族的 [HyperosSelectPopupGlass]（`pinnedChrome` 液态玻璃 +
/// 磨砂 / 实底回落），所以技术 / 系统门禁下的降级路径与其它弹层同源。
/// `useAncestorGroupCapture: true` 是必须的：承载壳注入了 `scrimUnderlay`，
/// 组捕获点建在压暗蒙层之前，玻璃采到的是**未压暗**的页面。
Widget hyperosMiuixBottomSheetSurface(
  BuildContext context,
  ShapeBorder shape,
  Widget child,
) {
  return HyperosGlassShadow.wrap(
    borderRadius: const BorderRadius.vertical(
      top: Radius.circular(hyperosMiuixBottomSheetCornerRadius),
    ),
    child: ClipRRect(
      // 与材质**同一条**曲线（`LiquidGlassSurface.borderRadius` 是同一个常量）：
      // 上沿两角圆、底边直。用上游那条贝塞尔曲线裁会在圆角处差 1.35px（见上）。
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(hyperosMiuixBottomSheetCornerRadius),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: -hyperosMiuixBottomSheetGlassBottomOverdraw,
            child: HyperosSelectPopupGlass(
              cornerRadius: hyperosMiuixBottomSheetCornerRadius,
              useAncestorGroupCapture: true,
              // 上沿与裁剪线同线 ⇒ 朝外位移会读空（见「上沿那条线」第十五轮）：
              // 一律不外推采样，与返回键那颗圆钮同一口径。
              maxRefraction: hyperosMiuixBottomSheetMaxRefraction,
              child: SizedBox.expand(),
            ),
          ),
          child,
          // 上沿 + 两个上角的那条边线，**画在内容与模糊带之上**（见
          // [HyperosSheetTopEdgeHighlight] 的注释：为什么面板轮廓必须永远在最上层）。
          const Positioned.fill(child: HyperosSheetTopEdgeHighlight()),
        ],
      ),
    ),
  );
}

/// 面板**上沿与两个上角**的那条边线，画在面板内容（尤其是顶部渐变模糊带）**之上**。
///
/// ## 为什么需要它（2026-09-27 用户口径）
///
/// 「内容滑到弹窗顶部渐变模糊带里时，弹窗左上角右上角的圆角变成平铺，滑回顶部/底部又恢复」
/// （停住不动也复现，所以不是滚动中的临时状态）。
///
/// 机制：顶部那条模糊带是一条**矩形**，它从面板上沿起、满宽铺到面板两边，于是
///
/// * 带子的模糊在**带上边缘是满强度**，而带上边缘正好压在面板顶边上 → 内容一滑进来，
///   就在面板最上沿拉出一条**笔直的线**横贯整个宽度；
/// * 面板玻璃自己的边光（rim）画在**玻璃上**，也就是在带子**下面** → 被带子盖掉。
///
/// 一条贯通的直线 + 没有边光 = 眼睛读到的顶边是直的，角上那两道圆弧就被压平 → 读成方角。
/// 内容不在带子里时模糊糊的是一片均匀玻璃、那条线不显，所以又「恢复正常」。
///
/// ## 为什么是「画在上面」而不是别的解法
///
/// 另一个思路是让带子在顶部两角让开圆角（带子最上面那段左右各收 28）。那样角上确实
/// 交回面板自己的玻璃，但**带子的上沿会在距两边 28px 处齐刷刷断掉**，面板最上沿多出两个
/// 台阶 —— 比现在更难看。
///
/// 边线画在上层没有这两个代价：带子的模糊与渐隐一点没动，角上多出来的是一条本来就该有的
/// 轮廓线（上游面板默认就带描边 —— 本仓把整块面板换掉时把它一起丢了，见
/// `2026-09-16-home-chrome-ball-invisible-on-flat-backdrop`）。
///
/// ## 数值一律取自玻璃自己那份样式
///
/// 颜色 / 强度 / 线宽都走 [LiquidGlassSurface.resolveStyleFor]（`pinnedChrome` 角色、
/// 同一个圆角、同一个亮度），**不另写一套**：边线是这块玻璃的边，写死了就会与玻璃的配方
/// 漂移（深浅两档各调一次玻璃、边线却不动 = 又一次「同一材质两种观感」）。
///
/// 只画上沿与两个上角：左右两条边贴在屏幕边上（通栏弹窗通宽），画出来是两条贴屏边的线；
/// 底边在屏幕外。真正需要它兜住的只有上沿与两个上角。
class HyperosSheetTopEdgeHighlight extends StatelessWidget {
  const HyperosSheetTopEdgeHighlight({super.key});

  /// 这条边线此刻的落笔颜色与线宽（= 玻璃 rim 配方乘上浓度）。
  ///
  /// 抽出来是为了让「边线与玻璃同源」这条能被机械断言，而不是靠注释保证。
  @visibleForTesting
  static ({Color color, double strokeWidth}) resolveEdge(
    BuildContext context,
  ) {
    final style = LiquidGlassSurface.resolveStyleFor(
      appearance: FrostedAppearanceScope.of(context),
      role: LiquidGlassRole.pinnedChrome,
      borderRadius: hyperosMiuixBottomSheetCornerRadius,
      brightness: Theme.of(context).brightness,
    );
    return (
      color: style.rimColor.withValues(alpha: style.rimColor.a * style.rimStrength),
      strokeWidth: style.rimWidth,
    );
  }

  @override
  Widget build(BuildContext context) {
    final edge = resolveEdge(context);
    return IgnorePointer(
      child: CustomPaint(
        painter: HyperosSheetTopEdgePainter(
          color: edge.color,
          strokeWidth: edge.strokeWidth,
          cornerRadius: hyperosMiuixBottomSheetCornerRadius,
        ),
      ),
    );
  }
}

/// [HyperosSheetTopEdgeHighlight] 的笔：只描「上沿 + 两个上角」这一段。
///
/// 公开是为了让路径几何可被断言（[topEdgePath]）；它不该被别的调用方直接使用。
@visibleForTesting
class HyperosSheetTopEdgePainter extends CustomPainter {
  const HyperosSheetTopEdgePainter({
    required this.color,
    required this.strokeWidth,
    required this.cornerRadius,
  });

  final Color color;
  final double strokeWidth;
  final double cornerRadius;

  /// 上沿 + 两个上角的路径。四分之一圆用三次贝塞尔逼近（k = 0.5523）：面板的圆角是
  /// 上游那条贝塞尔曲线，用 `arcTo` 的正圆去描会在角上差 1.35px（见本文件「轮廓」一节）。
  ///
  /// **关键**：路径必须**往内缩 `strokeWidth/2`**。描边是居中的，若路径落在裁剪框边上，
  /// 外半边会被父级 `ClipRRect` 裁掉，实际只剩 `strokeWidth/2` 可见（rimWidth=1.5 时仅 0.75px）。
  /// 往内让 `strokeWidth/2` 后，完整的 1.5px 全落在裁剪框内，圆角在内容滑过时依然读得出弧度。
  @visibleForTesting
  static Path topEdgePath(Size size, double cornerRadius, double strokeWidth) {
    final r = math.min(cornerRadius, math.min(size.width, size.height) / 2);
    // 往内缩半个线宽，让描边完整落在裁剪框内。
    final inset = strokeWidth / 2;
    final ri = r - inset;
    if (ri <= 0) {
      // 线宽比圆角还大时退回直线（极端情况不该发生，防御性编码）。
      return Path()
        ..moveTo(inset, inset)
        ..lineTo(size.width - inset, inset);
    }
    const k = 0.5523;
    return Path()
      ..moveTo(inset, inset + ri)
      ..cubicTo(inset, inset + ri - ri * k, inset + ri - ri * k, inset, inset + ri, inset)
      ..lineTo(size.width - inset - ri, inset)
      ..cubicTo(size.width - inset - ri + ri * k, inset, size.width - inset, inset + ri - ri * k, size.width - inset, inset + ri);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      topEdgePath(size, cornerRadius, strokeWidth),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(HyperosSheetTopEdgePainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.cornerRadius != cornerRadius;
}
