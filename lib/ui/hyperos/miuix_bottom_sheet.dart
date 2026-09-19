import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

// 诊断标记：弹层开场卡顿的归因（临时件，见 utils/frame_perf_probe.dart）。
import '../../utils/frame_perf_probe.dart';
import 'hyperos_blurred_header.dart';
import 'hyperos_popup_glass.dart';
import 'hyperos_sheet.dart' show hyperosEdgeSheetBottomOverdraw;
import 'liquid/liquid_glass_surface.dart';

/// 面板圆角：直接取上游默认值。
///
/// 注入面拿不到上游那个私有形状（`_TopSquircleBorder`）里的半径，只能用这个常量；
/// 而弹窗本身用默认值，所以写成「引用上游常量」而不是字面量 28，改上游时两边一起走。
const double hyperosMiuixBottomSheetCornerRadius =
    MiuixBottomSheetDefaults.cornerRadius;

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
        ),
  );
}

class _MiuixBottomSheetPage extends StatefulWidget {
  const _MiuixBottomSheetPage({
    required this.builder,
    required this.barrierDismissible,
  });

  final MiuixBottomSheetBuilder builder;
  final bool barrierDismissible;

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
        dimColor: HyperosBlurredHeader.modalBarrierColor(context),
        dragHandleColor: Theme.of(context).colorScheme.onSurfaceVariant,
        surfaceBuilder: hyperosMiuixBottomSheetSurface,
        scrimUnderlay: const UndimmedBackdropCapture(),
        content: widget.builder(context, _requestClose),
      ),
    );
  }
}

/// 把上游底部弹窗的实底面板换成**本仓贴底液态玻璃**：上沿两角按
/// [hyperosMiuixBottomSheetCornerRadius] 圆角，底边外溢
/// [hyperosEdgeSheetBottomOverdraw] 像素再被形状裁掉 —— 与 `HyperosSheetFrame`
/// 的 edge 面板同一套做法（否则液态玻璃贴着屏幕底那条直边会露出一道 1px 亮边）。
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
  return ClipPath(
    // 用上游算好的形状裁：上沿两角是它的 squircle 曲线，底边是直边。
    clipper: ShapeBorderClipper(shape: shape),
    child: Stack(
      children: [
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: -hyperosEdgeSheetBottomOverdraw,
          child: HyperosSelectPopupGlass(
            cornerRadius: hyperosMiuixBottomSheetCornerRadius,
            useAncestorGroupCapture: true,
            child: SizedBox.expand(),
          ),
        ),
        child,
      ],
    ),
  );
}
