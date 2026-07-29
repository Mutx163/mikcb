import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blackbox/flutter_blackbox.dart';

import 'debug_tuning_preferences.dart';

/// Hosts [BlackBoxOverlay] in non-release builds when the settings toggle is on.
///
/// Release builds return [child] unchanged (no overlay, no extra tree cost).
class BlackBoxOverlayHost extends StatelessWidget {
  const BlackBoxOverlayHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (kReleaseMode) {
      return child;
    }

    return ListenableBuilder(
      listenable: DebugTuningPreferences.instance,
      builder: (context, _) {
        if (!DebugTuningPreferences.instance.visible) {
          return child;
        }
        return BlackBoxOverlay(child: child);
      },
    );
  }
}
