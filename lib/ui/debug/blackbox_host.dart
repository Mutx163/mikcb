import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blackbox/flutter_blackbox.dart';

import 'debug_tuning_preferences.dart';

/// Hosts the BlackBox diagnostics overlay in non-release builds.
///
/// Visibility is controlled by the developer setting labelled "Debug UI
/// Overlay". The HyperOS layout sliders remain independent of that setting.
class BlackBoxOverlayHost extends StatelessWidget {
  const BlackBoxOverlayHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (kReleaseMode) {
      return child;
    }
    return ListenableBuilder(
      listenable: BlackBoxOverlayPreferences.instance,
      builder: (context, _) {
        if (!BlackBoxOverlayPreferences.instance.visible) {
          return child;
        }
        return BlackBoxOverlay(child: child);
      },
    );
  }
}
