import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

// 诊断标记：弹层开场卡顿的归因（临时件，见 utils/frame_perf_probe.dart）。
import '../../utils/frame_perf_probe.dart';
import 'hyperos_blurred_header.dart';
import 'liquid/liquid_glass_surface.dart';
import 'os4_glass_popup_surface.dart';

/// 请求收起居中玻璃对话框。
///
/// [afterDismiss] 在**退场动画结束、面板真的消失之后**才执行 —— 「先关弹窗、
/// 再开下一个页面 / sheet」一律走它，不要再靠固定延时猜动画时长。
typedef Os4GlassDialogClose = void Function({VoidCallback? afterDismiss});

/// [showOs4GlassDialog] 的 builder：内容 + 收起口子一起拿到。
typedef Os4GlassDialogBuilder =
    Widget Function(BuildContext context, Os4GlassDialogClose close);

/// 上游 OS4 **居中玻璃对话框**（`MiuixGlassDialog`）的承载壳。
///
/// ## 为什么需要这一层
///
/// 上游组件是**声明式**的：它要一直挂载、靠 `visible` 切换进出场，覆盖层经
/// `OverlayPortal(rootOverlay)` 出图，退场结束回调 `onDismissFinished`。
/// 而本仓的弹层调用面是**祈使式**的（`await showXxx(...)`，内容里到处
/// `Navigator.pop()`）。这里压一条**透明屏障**的路由，页面里常驻一个
/// `MiuixGlassDialog`，对外仍然是 `await showOs4GlassDialog(...)` ——
/// 于是内部的 `Navigator.pop()` 照旧可用，返回键由上游的 `LocalHistoryEntry`
/// 接住（它拿到的 `ModalRoute` 就是这条路由）。
///
/// ## 材质：仍然是我们的液态玻璃
///
/// 面板走 [hyperosGlassDialogSurface] 注入，几何、缩放动效（0.86 → 1）、圆角、
/// 遮罩与交互都还是上游的。对话框自带一层压暗蒙层、而蒙层排在面板**之前**，
/// 所以同时注入 [UndimmedBackdropCapture] 作 `scrimUnderlay` —— 上游据此把整个
/// 覆盖层包进 `BackdropGroup`，我们的玻璃以 `grouped` 采到**未压暗的页面**。
/// 少了这一步，玻璃会把那层黑蒙一起折进去（读感发灰）。
/// 依赖上游 `surfaceBuilder` + `scrimUnderlay` 两个注入点（本仓 fork 上的补丁，
/// 锁定来源见 `pubspec.yaml` 的 `dependency_overrides.flutter_miuix`）。
///
/// ## 与 [showHyperosSheet] 的区别
///
/// 位置：**屏幕居中**（面板贴底的是 sheet）。遮罩口径沿用本仓口径
/// （[HyperosBlurredHeader.modalBarrierColor]，液态玻璃下只有很轻的一层），
/// 不取上游 dialog 默认的 0.3 / 0.6 —— 我们的玻璃是按本仓那层轻蒙调的。
Future<T?> showOs4GlassDialog<T>({
  required BuildContext context,
  required Os4GlassDialogBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = false,
  double maxWidth = 420,
  double maxHeightFactor = 0.72,
}) {
  // 诊断标记：原来是 `sheet:open`（课程弹窗走贴底 sheet），换入口后口径跟着换。
  FramePerfProbe.mark('os4Dialog:open');
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    // 蒙层点击由面板自己的遮罩处理（它才是画在玻璃之前的那一层）；路由屏障
    // 只负责挡住下层的点击，不参与关闭，避免两条关闭路径打架。
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        _Os4GlassDialogPage(
          builder: builder,
          barrierDismissible: barrierDismissible,
          maxWidth: maxWidth,
          maxHeightFactor: maxHeightFactor,
        ),
  );
}

class _Os4GlassDialogPage extends StatefulWidget {
  const _Os4GlassDialogPage({
    required this.builder,
    required this.barrierDismissible,
    required this.maxWidth,
    required this.maxHeightFactor,
  });

  final Os4GlassDialogBuilder builder;
  final bool barrierDismissible;
  final double maxWidth;
  final double maxHeightFactor;

  @override
  State<_Os4GlassDialogPage> createState() => _Os4GlassDialogPageState();
}

class _Os4GlassDialogPageState extends State<_Os4GlassDialogPage> {
  /// 面板当前该不该在场：上游靠它驱动进场 / 退场动画。
  bool _visible = true;

  /// 收起时要接着做的事（见 [Os4GlassDialogClose]）。退场只可能走一次，
  /// 这里也就只被消费一次。
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
    // 先摘路由，再跑后续动作：后续动作里常常立刻 push 下一个页面 / sheet，
    // 面板已经彻底消失，两者不会叠在一起。
    Navigator.of(context).pop();
    afterDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    return MiuixGlassDialog(
      visible: _visible,
      // 无蒙层点击语义时给个空实现：上游要求必填，遮罩命中仍然会拦住下层点击。
      onDismissRequest: widget.barrierDismissible
          ? _requestClose
          : () {},
      onDismissFinished: _onDismissFinished,
      sizing: MiuixGlassPopupSizing(
        maxWidth: widget.maxWidth,
        maxHeight: screenHeight * widget.maxHeightFactor,
        safeMargin: 24,
      ),
      surfaceBuilder: hyperosGlassDialogSurface,
      scrimUnderlay: const UndimmedBackdropCapture(),
      scrimAlpha: HyperosBlurredHeader.modalBarrierColor(context).a,
      child: widget.builder(context, _requestClose),
    );
  }
}
