import 'package:flutter/widgets.dart';

/// 让"随壁纸亮度采样而定"的极性（衬底 + 墨色）**渐变**，而不是跳变。
///
/// ## 为什么需要它
///
/// 压在壁纸上的玻璃表面（首页 chrome 玻璃带、壁纸位置选择页的悬浮按钮等）要按
/// **壁纸顶部亮度**决定两件事：
///
/// - 衬底色：`HomePageChromeGlassFill.scrimColor`（暗壁纸 → 浅衬底，反之深衬底）；
/// - 墨色：`homePageChromeForegroundForLuminance`（文字 / 描边的明暗）。
///
/// 而那个亮度是**异步采样**出来的（要解码一次壁纸，几十到几百毫秒）。采样落地前
/// 只能按主题明暗猜一个极性，落地后再修正 —— 直接修正就是一次可见跳变：先是一块
/// 浅色实底（浅衬底 + 深字），整块随后变成玻璃（深衬底 + 白字）。真机反馈
/// （2026-09-15）：柔光档进 / 出壁纸位置选择页时，三个悬浮按钮闪一下。
///
/// "猜 → 修正"不可避免（同步拿不到亮度），但**跳变可以变成渐变**：观感从"闪一下"
/// 变成"稳定下来"。首帧不做动画（直接落在传入的极性上），只在极性变化时补一段
/// cross-fade —— 拖动壁纸改对齐后重新采样、极性真的变了时，同样平滑过渡。
class SoftGlassPolarityFade extends StatelessWidget {
  const SoftGlassPolarityFade({
    super.key,
    required this.ink,
    required this.wash,
    required this.builder,
    this.duration = const Duration(milliseconds: 280),
  });

  /// 目标墨色（文字 / 描边）。
  final Color ink;

  /// 目标衬底色。
  final Color wash;

  /// 用当前极性建视图。极性变化时 [ink] / [wash] 会是渐变中的中间值。
  final Widget Function(BuildContext context, Color ink, Color wash) builder;

  /// 渐变时长：长到不会被读成"跳了一下"，短到不像两个状态。
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    // 两层 `TweenAnimationBuilder`：`Tween.begin` 缺省时首帧直接落在 `end` 上
    // （不做动画），之后每次 `end` 变化都从"当前显示值"补一段动画 —— 正是这里
    // 要的行为，不需要自己持有 controller。
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: ink),
      duration: duration,
      builder: (context, inkValue, _) => TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: wash),
        duration: duration,
        builder: (context, washValue, _) =>
            builder(context, inkValue ?? ink, washValue ?? wash),
      ),
    );
  }
}
