import 'package:flutter/widgets.dart';
import 'package:flutter_miuix/miuix.dart';

import 'hyperos_select.dart' show HyperosSelectPopupGlass;

/// 上游 OS4 弹层的**面板材质注入**。
///
/// 上游 `GlassPopupPresenter` 自己构造面板，只暴露 `MiuixGlassPopupVisuals`
/// 的 7 个字段（material / style / stroke / alpha / shadow / containerColor /
/// showStroke），**接不进另一条渲染链路** —— 于是全局「液态玻璃」档下，用玻璃
/// 弹层的首页菜单仍是 OS4 玻璃，与玻璃坞底栏（跟随档位走液态折射）断层。
///
/// 这个函数把面板换成 [HyperosSelectPopupGlass]：材质由它按全局玻璃档位分派
/// （液态 → 液态折射面、柔光 → `SoftGlassSurface`、高斯 → `BackdropFilter`、
/// 降级 → 实底），与页内表面同一份口径。
///
/// ⚠️ **几何、形变动效、二级面板、锚定与返回键处理一行都不动** —— 注入的只是
/// 面板材质。首页「更多」菜单的「从按钮形变长出 + 图标渐隐」正是靠这一点保住的，
/// 不要再为了材质去替换上游 presenter。
///
/// 用法：
/// ```dart
/// MiuixGlassTransformPopup(
///   surfaceBuilder: hyperosGlassPopupSurface,
///   ...
/// )
/// ```
///
/// 依赖上游 `GlassPopupPresenter.surfaceBuilder`（flutter_miuix 的
/// `feat/glass-popup-surface-builder` 分支）。
///
/// 用于**一级面板**（直接站在页面上、或锚在按钮上的那一块）。
Widget hyperosGlassPopupSurface(
  BuildContext context,
  ShapeBorder shape,
  Widget child,
) => _os4GlassPopupSurface(shape, child);

/// 二级面板的注入面：与 [hyperosGlassPopupSurface] 只差一件事 ——
/// **垫一层共享组捕获的磨砂底**（`useAncestorGroupCapture`）。
///
/// 二级面板是**浮在另一块玻璃之上**的（首页菜单的二级面板锚点就是一级面板里
/// 那一行，见 `home_top_menu_popup.dart`）。液态玻璃面按绘制顺序采样自己下面的
/// 合成结果，不垫底的话会直接采样到一级面板的玻璃输出 —— 玻璃叠玻璃再折射一遍，
/// 读感浑浊。口径与列表弹窗的二级子卡（`hyperos_list_popup.dart` 的
/// `useAncestorGroupCapture: true`）完全一致，见
/// [HyperosSelectPopupGlass.useAncestorGroupCapture]。
///
/// 只影响液态档：柔光 / 高斯 / 实底三条分支不读这个开关。
Widget hyperosGlassPopupSecondarySurface(
  BuildContext context,
  ShapeBorder shape,
  Widget child,
) => _os4GlassPopupSurface(shape, child, useAncestorGroupCapture: true);

Widget _os4GlassPopupSurface(
  ShapeBorder shape,
  Widget child, {
  bool useAncestorGroupCapture = false,
}) => HyperosSelectPopupGlass(
  cornerRadius: os4GlassPopupCornerRadiusOf(shape),
  useAncestorGroupCapture: useAncestorGroupCapture,
  child: child,
);

/// 从上游弹层几何里读出圆角标量。
///
/// 上游交给我们的是**已经算好的** `MiuixGlassShape` —— `transform` 动效期间
/// 它的圆角每帧都在从「按钮短边一半」lerp 到面板圆角，注入面必须直接用这个值，
/// **不要在调用方按进度重算**，否则注入面与上游面板的几何会错开。
double os4GlassPopupCornerRadiusOf(ShapeBorder shape) {
  // 弹层是四角同径的圆角矩形，取任一角的标量即可 —— 与书写方向无关，
  // 所以这里固定用 LTR 解析（`BorderRadiusGeometry.resolve` 需要方向参数）。
  if (shape is MiuixGlassShape) {
    return shape.resolve(TextDirection.ltr).topLeft.x;
  }
  if (shape is RoundedRectangleBorder) {
    return shape.borderRadius.resolve(TextDirection.ltr).topLeft.x;
  }
  return MiuixGlassPopupDefaults.cornerRadius;
}
