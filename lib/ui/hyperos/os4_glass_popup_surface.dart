import 'package:flutter/widgets.dart';
import 'package:flutter_miuix/miuix.dart';

// 取叶子文件（不是 `hyperos_select.dart`）：后者要用本文件里的
// `hyperosGlassPopupSurface`，直接互 import 会成环。见该文件的说明。
import 'hyperos_popup_glass.dart'
    show HyperosSelectPopupGlass, HyperosSolidPopupSurface;

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

/// 实底注入面：弹层悬在 **Android 平台视图**（WebView）上方时必须用它。
///
/// 玻璃的背景采集读不到平台视图的纹理，采样结果是一块黑，面板会渲染成黑色方块
/// （`HyperosSolidPopupSurface` 的类注释原话）。与
/// [hyperosGlassPopupSurface] 一样只换材质，几何、动效、锚定仍归上游。
Widget hyperosGlassPopupOpaqueSurface(
  BuildContext context,
  ShapeBorder shape,
  Widget child,
) => HyperosSolidPopupSurface(
  cornerRadius: os4GlassPopupCornerRadiusOf(shape),
  child: child,
);

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

// 底部弹窗（`MiuixOverlayBottomSheet` / `MiuixWindowBottomSheet`）的注入面不在这里：
// 它要的是「贴底、只有上沿两角圆」的玻璃，且拿不到上游形状里的半径，所以连同承载壳
// 一起放在 `miuix_bottom_sheet.dart`（`hyperosMiuixBottomSheetSurface`）。

Widget _os4GlassPopupSurface(
  ShapeBorder shape,
  Widget child, {
  bool useAncestorGroupCapture = false,
}) => HyperosSelectPopupGlass(
  cornerRadius: os4GlassPopupCornerRadiusOf(shape),
  useAncestorGroupCapture: useAncestorGroupCapture,
  surfaceShadow: true,
  child: child,
);

/// **全软件锚定式玻璃菜单的统一宽度口径**（`minWidth` 默认 200，故这是固定 200）。
///
/// 为什么是 200：
/// - 上游默认是 `MiuixGlassPopupSizing(maxWidth: 288)`，而 `MiuixGlassPopupItem`
///   的文字样式 + 箭头 + 内边距比旧实现的手搓条目宽，面板会被顶到接近上限 ——
///   真机上就是"菜单比换实现前胖了一圈"。
/// - 收到 **200** 即回到旧实现的**下界原宽**：旧公式
///   `132 + HyperosMiuixDropdown.popupExtraLeadingWidth` 恰好 = 200，而旧条目
///   更窄、实际宽度一直停在这个下界。
///
/// 单一来源的规矩：**所有锚定式玻璃菜单都传这一份**（首页「更多」主/二级面板、
/// 时间模板页卡片菜单、后续迁移的页面）。`sizing` 是各自独立的入参，某一处
/// 私开一个数字就会读成"这个菜单比那个菜单胖"。
///
/// ⚠️ 首页的主面板与二级面板**必须传同一份**：只给一级会让主面板 200、二级
/// 默认 288，两块宽度对不齐。
const MiuixGlassPopupSizing os4GlassPopupStandardSizing =
    MiuixGlassPopupSizing(maxWidth: 200);

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
