import 'package:flutter/material.dart';

/// 宿主页面根级的页面捕获作用域：给锚定弹窗的二级子卡提供「弹窗背后
/// 页面」的同步截图来源（RenderRepaintBoundary.toImageSync）。
///
/// 液态玻璃面的自有采样捕获点在它自己的绘制位置——浮在主面板玻璃上面
/// 的子卡会把主面板玻璃的输出再采样一遍（玻璃叠玻璃，读感浑浊）。把
/// 整页预捕获成 ui.Image 直接喂给子卡玻璃的 shader（LiquidGlass 的
/// captureImage 通道），子卡取到的就是背后的首页内容本身，与一级弹窗
/// 同源。挂在页面根部的捕获边界同时承担整页重绘隔离，代价可忽略。
///
/// 除同步截图外，同一个边界 key 还充当**真折射取样源**：透传给
/// HyperosLiquidGlassSurface.backgroundKey 后，玻璃着色器进入 PATH A
/// 真正做折射位移（否则恒走 PATH B，只剩一圈 rim/fresnel 描边）。
///
/// 单独成文件是为了打断 hyperos_select.dart ↔ hyperos_list_popup.dart
/// 的循环 import —— 二者都需要这份数据。
class PopupPageCaptureScope extends StatefulWidget {
  const PopupPageCaptureScope({super.key, required this.child});

  final Widget child;

  @override
  State<PopupPageCaptureScope> createState() => _PopupPageCaptureScopeState();
}

class _PopupPageCaptureScopeState extends State<PopupPageCaptureScope> {
  final GlobalKey _boundaryKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return PopupPageCaptureData(
      boundaryKey: _boundaryKey,
      child: RepaintBoundary(key: _boundaryKey, child: widget.child),
    );
  }
}

/// [PopupPageCaptureScope] 发布的数据。
class PopupPageCaptureData extends InheritedWidget {
  const PopupPageCaptureData({
    super.key,
    required this.boundaryKey,
    required super.child,
  });

  /// 宿主页面捕获边界的 key（[RepaintBoundary] 根）。
  final GlobalKey boundaryKey;

  /// 解析宿主页面的捕获边界；宿主未挂作用域时返回 null（二级子卡退回
  /// 共享组磨砂底采样）。
  static PopupPageCaptureData? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PopupPageCaptureData>();

  @override
  bool updateShouldNotify(PopupPageCaptureData oldWidget) =>
      boundaryKey != oldWidget.boundaryKey;
}
