import 'package:flutter/widgets.dart';
import 'package:flutter_miuix/miuix.dart';

// 取叶子文件（不是 `hyperos_select.dart`）：后者要用本文件里的
// `hyperosGlassPopupSurface`，直接互 import 会成环。见该文件的说明。
import 'hyperos_popup_glass.dart' show HyperosSelectPopupGlass;

/// 上游 OS4 弹层的**面板材质注入**。
///
/// 上游 `GlassPopupPresenter` 自己构造面板，只暴露 `MiuixGlassPopupVisuals`
/// 的 7 个字段（material / style / stroke / alpha / shadow / containerColor /
/// showStroke），**接不进另一条渲染链路** —— 于是全局「液态玻璃」档下，用玻璃
/// 弹层的首页菜单仍是 OS4 玻璃，与玻璃坞底栏（跟随档位走液态折射）断层。
///
/// 这个函数把面板换成 [HyperosSelectPopupGlass]：弹窗家族自 2026-09-19 起锁成
/// 「**永远液态玻璃的标准档**」（见 `LiquidGlassRole.pinnedChrome`）——用户的全局
/// 材质档位、作用范围开关、模糊总开关都不参与，只剩技术 / 系统门禁能把它摘下来
/// （没有 shader 后端 → 磨砂兜底；平台视图 / 系统降级 → 实底）。
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
/// 依赖上游 `GlassPopupPresenter.surfaceBuilder` —— 这个注入点是**本仓 fork 上的
/// 补丁**，尚未进 pub.dev（锁定来源见 `pubspec.yaml` 的
/// `dependency_overrides.flutter_miuix`，固定到 commit）。补丁进了上游 release 后，
/// 这条 override 与本段说明一起删。
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

/// 居中玻璃对话框（`MiuixGlassDialog`）的注入面：与二级面板**同口径** ——
/// 必须进祖先共享组捕获（`useAncestorGroupCapture: true`）。
///
/// 理由和二级面板同源，只是「压在它下面的那块玻璃」换成了**压暗蒙层**：
/// 对话框的蒙层排在面板之前，不垫共享组捕获的话，液态面会直接采到「页面 + 黑蒙」
/// 的合成结果，玻璃里连蒙一起折进去，读感发灰。捕获点由承载壳
/// （`lib/ui/hyperos/os4_glass_dialog.dart`）注入的 `UndimmedBackdropCapture`
/// 在蒙层之前建立。
///
/// 用它的前提是上游 `scrimUnderlay` 补丁（见 `pubspec.yaml` 的
/// `dependency_overrides.flutter_miuix`）；只传 surfaceBuilder 而不传
/// scrimUnderlay 时，这里会退化成「采到压暗后的页面」。
Widget hyperosGlassDialogSurface(
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
  // ⚠️ 必须开：上游 `MiuixGlassPanel` 的面板默认就带浮影
  // （`v.shadow = MiuixGlassShadows.floating`），注入面把整块面板换掉时把这层
  // 丢了。首页菜单收起时那颗球**就是这块面缩到锚点大小**，常驻球（同样带浮影，
  // 见 [HyperosGlassShadow]）在它之后接管 —— 两侧不一致时，真机上看到的就是
  // "阴影在弹窗收回后一秒突然出现"。
  //
  // 上游那道 `v.stroke` 描边**没有**跟着补：2026-09-19 用户要求组件不再叠描边，
  // 球的边界交给玻璃材质自己交代。
  surfaceShadow: true,
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
