import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../hyperos_blurred_header.dart';

/// Cached frosted bitmap + scrim for HyperOS top bars (CFH).
class FrostedHeaderBackground extends StatelessWidget {
  const FrostedHeaderBackground({
    required this.tint,
    required this.child,
    this.blurredImage,
    super.key,
  });

  final ui.Image? blurredImage;
  final Color tint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipRect(
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: tint),
                child: blurredImage == null
                    ? const SizedBox.expand()
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          return RawImage(
                            image: blurredImage,
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            fit: BoxFit.fill,
                            filterQuality: FilterQuality.medium,
                          );
                        },
                      ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

/// Shell matching [HyperosBlurredHeaderShell] API but driven by CFH cache.
class HyperosFrostedHeaderShell extends StatelessWidget {
  const HyperosFrostedHeaderShell({
    required this.child,
    this.blurredImage,
    super.key,
  });

  final Widget child;
  final ui.Image? blurredImage;

  @override
  Widget build(BuildContext context) {
    final scopeBlur = HyperosBlurredHeaderScope.blurEnabledOf(context);
    final useBlur = HyperosBlurredHeader.liveBlurSupported && scopeBlur;
    final tint = HyperosBlurredHeader.tintColor(context, withBlur: useBlur);

    return FrostedHeaderBackground(
      blurredImage: useBlur ? blurredImage : null,
      tint: tint,
      child: child,
    );
  }
}
