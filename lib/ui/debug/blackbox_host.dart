import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blackbox/flutter_blackbox.dart';

import 'blackbox_overlay_preferences.dart';

/// Hosts the BlackBox diagnostics overlay in non-release builds.
///
/// Visibility is controlled by the developer setting labelled "Debug UI
/// Overlay". HyperOS layout values use fixed design tokens.
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
