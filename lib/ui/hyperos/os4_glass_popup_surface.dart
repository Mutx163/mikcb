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
Widget hyperosGlassPopupSurface(
  BuildContext context,
  ShapeBorder shape,
  Widget child,
) => HyperosSelectPopupGlass(
  cornerRadius: os4GlassPopupCornerRadiusOf(shape),
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
