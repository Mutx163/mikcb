import 'package:flutter/material.dart';

import 'hyperos_miuix_spec.dart';

/// HyperOS circular progress indicator (primary accent).
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark
        ? HyperosMiuixDarkColors.primary
        : HyperosMiuixLightColors.primary;

    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(strokeWidth: strokeWidth, color: color),
    );
  }
}

/// HyperOS linear progress bar (primary on muted track).
class HyperosLinearProgress extends StatelessWidget {
  const HyperosLinearProgress({super.key, this.value, this.minHeight = 4});

  final double? value;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = isDark
        ? HyperosMiuixDarkColors.primary
        : HyperosMiuixLightColors.primary;
    final track = isDark
        ? HyperosMiuixDarkColors.sliderBackground
        : HyperosMiuixLightColors.sliderBackground;

    return SizedBox(
      height: minHeight,
      child: value == null
          ? LinearProgressIndicator(
              minHeight: minHeight,
              color: active,
              backgroundColor: track,
            )
          : LinearProgressIndicator(
              value: value!.clamp(0, 1),
              minHeight: minHeight,
              color: active,
              backgroundColor: track,
            ),
    );
  }
}
