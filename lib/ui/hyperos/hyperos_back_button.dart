import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import 'hyperos_blurred_header.dart';

/// 子页左上角的返回键 —— 上游 OS4 那颗**圆形**玻璃图标按钮。
///
/// 用法与上游示例逐字对齐（`flutter_miuix` 的 `example/lib/showcase/os4.dart`
/// 把 `MiuixGlassIconButton` 放进 `MiuixGlassTopAppBar.navigationIcon`，图标用
/// `MiuixIcons.os4.chevronBackward`）：直径 44 的圆、圆角取 `size / 2`、图标 24，
/// 描边与阴影都由上游给，本仓不再自绘一套球。
///
/// ## 圆底只在"内容压到顶栏下面"时出现
///
/// 停在页顶时它是一根光箭头，往下滑到内容钻到顶栏带下面才长出圆底。判据直接复用
/// 顶栏磨砂那一份 [HyperosBlurredHeaderScope.contentUnderHeaderOf]（= `scrollPixels >`
/// 阈值，折叠大标题的页面阈值取大标题展开量），所以圆底与磨砂带**同一时刻**翻面；
/// 翻面是瞬时的 —— 顶栏那条带本身也是瞬时换色（`InspireHeaderBlur` 里没有任何
/// 过渡动画），圆底跟着一起切才读作同一件事。
///
/// 实现上只动上游给的 `surfaceAlpha`（0 关掉整块玻璃表面），**不换 widget**：
/// 图标、44×44 命中区、按压缩放都保持不变，也不会有重挂与图标位移。
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
/// 上游按主题明暗给（亮 `#FFFFFF` / 暗 `#2C2C2C`）。它是实心圆钮，**不是玻璃** ——
/// 要真折射得先给子页顶栏接一路采样源，那是另一件事
/// （见 `.agents/notes/implemented/feature/2026-09-17-subpage-glass-back-button.md`）。
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
    // 只有"内容已经压到顶栏带下面"时才长出圆底；停在页顶就是一根光箭头。
    // 判据直接复用顶栏磨砂那一份（[HyperosBlurredHeaderScope.contentUnderHeaderOf]，
    // 即 `scrollPixels > 阈值`）：圆底与磨砂带同一时刻翻面，读起来是"顶栏活过来"
    // 而不是两个各自为政的开关。它走 InheritedWidget 依赖，翻面时本元素自己重建，
    // 不需要 [HyperosSubpage]（StatelessWidget）跟着重建。
    final contentUnder = HyperosBlurredHeaderScope.contentUnderHeaderOf(context);
    return MiuixGlassIconButton(
      onPressed: onPressed,
      // 用上游给的 `surfaceAlpha` 开关**表面**，而不是换 widget：
      // `surfaceAlpha: 0` 会把材质 alpha 压到 0，`MiuixGlass.paint` 里
      // `cfg.alpha <= 0` 直接早退（填充、描边、阴影、高光一次都不画），
      // 而图标、44×44 命中区、按压缩放全都照旧 —— 也就没有换 widget 带来的
      // 重挂与图标位移。上游玻璃顶栏同步显隐进度用的就是这个入参。
      surfaceAlpha: contentUnder ? 1 : 0,
      child: MiuixIcon(vector: MiuixIcons.os4.chevronBackward),
    );
  }
}
