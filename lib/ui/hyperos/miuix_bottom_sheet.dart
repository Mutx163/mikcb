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
/// 再开下一个页面 / sheet」一律走它，不要再靠固定延时猜动画时长。
typedef MiuixBottomSheetClose = void Function({VoidCallback? afterDismiss});

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
/// `Navigator.pop()`）。这里压一条透明屏障的路由，页面里常驻一个
/// `MiuixWindowBottomSheet`，对外仍是 `await showMiuixBottomSheet(...)`：
/// 内部照旧可以 `Navigator.pop()`，返回键由本壳的 `PopScope` 接住（上游自己那个
/// `PopScope` 在根覆盖层里拿不到 `ModalRoute`，不生效）。
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
Future<T?> showMiuixBottomSheet<T>({
  required BuildContext context,
  required MiuixBottomSheetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = false,
  Color? barrierColor,
}) {
  // 诊断标记沿用 `sheet:open`（这个弹窗就是「弹层开场」那一类，改用上游组件不换口径，
  // 历史读数仍然可比）。见 utils/frame_perf_probe.dart。
  FramePerfProbe.mark('sheet:open');
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    // 蒙层点击由面板自己那层遮罩处理（它才是画在玻璃之前的那一层）；路由屏障只
    // 负责挡住下层点击，不参与关闭，避免两条关闭路径打架。
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        _MiuixBottomSheetPage(
          builder: builder,
          barrierDismissible: barrierDismissible,
          barrierColor: barrierColor,
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
Future<T?> showHomeHyperosSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool useRootNavigator = false,
  Color? barrierColor,
}) {
  return showMiuixBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: isDismissible,
    barrierColor: barrierColor,
    builder: (sheetContext, close) => builder(sheetContext),
  );
}

class _MiuixBottomSheetPage extends StatefulWidget {
  const _MiuixBottomSheetPage({
    required this.builder,
    required this.barrierDismissible,
    this.barrierColor,
  });

  final MiuixBottomSheetBuilder builder;
  final bool barrierDismissible;
  final Color? barrierColor;

  @override
  State<_MiuixBottomSheetPage> createState() => _MiuixBottomSheetPageState();
}

class _MiuixBottomSheetPageState extends State<_MiuixBottomSheetPage> {
  /// 面板当前该不该在场：上游靠它驱动滑入 / 滑出。
  bool _visible = true;

  /// 收起时要接着做的事（见 [MiuixBottomSheetClose]），退场只走一次，也就只被消费一次。
  VoidCallback? _afterDismiss;

  bool _popped = false;

  void _requestClose({VoidCallback? afterDismiss}) {
    if (!_visible) {
      return;
    }
    _afterDismiss = afterDismiss;
    setState(() => _visible = false);
  }

  void _onDismissFinished() {
    if (_popped) {
      return;
    }
    _popped = true;
    final afterDismiss = _afterDismiss;
    _afterDismiss = null;
    // 先摘路由，再跑后续动作：后续动作常常立刻 push 下一个页面 / sheet，
    // 面板已经彻底消失，两者不会叠在一起。
    Navigator.of(context).pop();
    afterDismiss?.call();
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
              padding: EdgeInsets.only(
                bottom:
                    MediaQuery.paddingOf(context).bottom +
                    hyperosMiuixBottomSheetContentBottomGap,
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

/// 把上游底部弹窗的实底面板换成**本仓贴底液态玻璃**：上沿两角按
/// [hyperosMiuixBottomSheetCornerRadius] 圆角，上沿与左右**不外溢**（材料边界与裁剪
/// 同一条线），底边往外铺 [hyperosMiuixBottomSheetGlassBottomOverdraw]（9，为了盖住
/// 直角底角）。
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
/// ## 上沿那条线：**全部交给材质，这块面板不再自带任何材质参数**
///
/// 材质画在边界上的那一圈在这块面板上有两种读法：**圆角上**是"玻璃的反光边"（用户口径：
/// 圆角位置处理得非常好），**两个上角之间那条贯屏长直边**上是一条线（用户口径：顶部有
/// 浅色线条）。前后十几轮都在参数上打转（整圈推走、只推峰值、压折射、给直段做局部
/// 淡出、把高光收成发丝），直到 2026-09-20 重新推导边光才把病根找齐：
///
/// 1. **方向性**：均匀口径的边光 alpha 只按"离边多远"算，这边的边光按
///    `dot(法线, 光来向)` 加权 —— 上沿恰好是被照得最亮的那条边（0.87 vs 下沿 0.35，
///    差 2.9 倍），在长直边上就成了一条线。
/// 2. **截面**：均匀口径的边光是「贴边一小段满亮度平台 + 向内 smoothstep 羽化」，这边是
///    「贴边最亮、往里二次衰减」—— 峰值正好压在抗锯齿的半像素过渡带里，圆角上读出锯齿。
///
/// 两条都已从材质层面解决（见两个 `.frag` 的文件头）。原先给直段做的 `topRunFade` 局部
/// 淡出、以及这里一度给长直边加的 `maxRefraction` 折射上限，**都是补方向性那场病的药，
/// 已同批删掉** —— 留着会让这块面板与右上角那个菜单弹窗（同属弹窗家族、锁同一档）的
/// 边缘观感分叉，而用户的口径是「**和右上角卡片观感一致**」。
///
/// 于是现在这块面板**没有任何自己的材质参数**：只提供几何（圆角、底边外溢）与
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
              child: SizedBox.expand(),
            ),
          ),
          child,
        ],
      ),
    ),
  );
}
