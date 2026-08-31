import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

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
