import 'package:flutter/material.dart';

import 'hyperos_theme.dart';

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
    final color = HyperosColors.primary(context);

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
    final active = HyperosColors.primary(context);
    final track = HyperosColors.sliderBackground(context);

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
