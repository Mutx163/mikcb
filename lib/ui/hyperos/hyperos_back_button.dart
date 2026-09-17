import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

/// 子页左上角的返回键 —— 上游 OS4 那颗**圆形**玻璃图标按钮。
///
/// 用法与上游示例逐字对齐（`flutter_miuix` 的 `example/lib/showcase/os4.dart`
/// 把 `MiuixGlassIconButton` 放进 `MiuixGlassTopAppBar.navigationIcon`，图标用
/// `MiuixIcons.os4.chevronBackward`）：直径 44 的圆、圆角取 `size / 2`、图标 24，
/// 描边与阴影都由上游给，本仓不再自绘一套球。
///
/// ## 为什么不传 `backdrop`
///
/// 上游玻璃的采样源只有两条来路：`GlassBarScope`（玻璃顶栏下发）或显式
/// `backdrop`。本仓两者都取不到 —— 子页顶栏走的是实时 `BackdropFilter`
/// （[HyperosBlurredHeader]，根本不录快照），而 [HyperosGlassBackdropHost] 只挂在
/// **整页级**的根页面上（`HyperosRootPage` / 课表首页），子页是独立路由、不在那棵树
/// 里；`HyperosGlassBackdropRegistry` 的"栈顶"兜底取到的是**被压在下面那一屏**的
/// 快照，用它画玻璃等于让返回键显示上一页的画面。
///
/// 所以这里走上游在"没有采样源"时那条分支：**纯色轮廓 + 描边 + 阴影**，兜底色由
/// 上游按主题明暗给（亮 `#FFFFFF` / 暗 `#2C2C2C`），观感是一颗一眼可辨的实心圆钮，
/// 与子页顶栏那条磨砂带同色系。要让它真的折射，得先给子页顶栏接一路采样源，
/// 那是另一件事（见 `.agents/notes/implemented/feature/2026-09-17-subpage-glass-back-button.md`）。
///
/// ## 尺寸与位置
///
/// - 直径 44 比原先的 [HyperosIconButton]（40）宽 4：折叠顶栏按**实测**导航图标宽度
///   给居中标题让位，所以这 4px 会被自动算进去，不需要动任何 padding。
/// - 顶栏的 `navigationIconPadding` 仍是 16（上游玻璃顶栏用 12 是为了让
///   `padding + 宽度` 与旧的 16 + 40 相等）。本仓沿用 16，图标的视觉左边缘因此
///   右移 2px —— 不接参数、不为它加一条布局分支。
///
/// 没有 tooltip / semantics label：原先那颗 [HyperosIconButton] 也没有，加中文
/// 文案会带出一批 l10n 改动，等真要给无障碍标签时再一起做。
class HyperosBackButton extends StatelessWidget {
  const HyperosBackButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return MiuixGlassIconButton(
      onPressed: onPressed,
      child: MiuixIcon(vector: MiuixIcons.os4.chevronBackward),
    );
  }
}
