import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import 'hyperos_theme.dart';

/// HyperOS circular progress — delegates to [MiuixCircularProgressIndicator].
class HyperosCircularProgress extends StatelessWidget {
  const HyperosCircularProgress({
    super.key,
    this.size = 24,
    this.strokeWidth = 2.5,
  });

  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return MiuixCircularProgressIndicator(
      strokeWidth: strokeWidth,
      size: size,
    );
  }
}

/// HyperOS linear progress — delegates to [MiuixLinearProgressIndicator].
class HyperosLinearProgress extends StatelessWidget {
  const HyperosLinearProgress({super.key, this.value, this.minHeight = 4});

  final double? value;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return MiuixLinearProgressIndicator(progress: value, height: minHeight);
  }
}

/// HyperOS infinite progress — delegates to [MiuixInfiniteProgressIndicator].
///
/// 「一条细圆环 + 一个小圆点沿环内轨道转」，与 [HyperosCircularProgress] 的
/// 「一段圆弧来回扫」是两种长相：前者的转圈感更强（整环都在动、点明确绕行），
/// 后者更像进度条在跳。**不可测进度**的场景（不知道还剩多久、只是要告诉用户
/// 「还在转」）一律用这个。
///
/// ⚠️ 上游没有 `colors` 参数，颜色写死走 `color`（默认 Compose 的 `Color.Gray`
/// `0xFF888888`，**不是** Flutter 的 `Colors.grey`）。要跟页面主色走就自己传。
class HyperosInfiniteProgress extends StatelessWidget {
  const HyperosInfiniteProgress({
    super.key,
    this.color,
    this.size = 20,
    this.strokeWidth = 2,
    this.orbitingDotSize = 2,
  });

  final Color? color;
  final double size;
  final double strokeWidth;
  final double orbitingDotSize;

  @override
  Widget build(BuildContext context) {
    return MiuixInfiniteProgressIndicator(
      color: color ?? HyperosColors.primaryText(context),
      size: size,
      strokeWidth: strokeWidth,
      orbitingDotSize: orbitingDotSize,
    );
  }
}
