import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blackbox/flutter_blackbox.dart';

/// Hosts the BlackBox diagnostics overlay in non-release builds.
///
/// This is intentionally separate from [DebugTuningOverlayHost], which owns
/// the HyperOS layout sliders.
class BlackBoxOverlayHost extends StatelessWidget {
  const BlackBoxOverlayHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (kReleaseMode) {
      return child;
    }
    return BlackBoxOverlay(child: child);
  }
}
