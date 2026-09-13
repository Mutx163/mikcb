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

/// 按需打开 BlackBox 调试面板。
///
/// trigger 用的是 `BlackBoxTrigger.none()`（见 `lib/blackbox_adapters.dart`），
/// 所以没有常驻悬浮球当入口，改由设置页的「打开调试面板」这一行调用这里。
/// 面板只在打开期间播一次转场动画，关闭后不留下任何持续出帧的动画。
///
/// 浮层默认是关闭的（见 [BlackBoxOverlayPreferences]），而 `BlackBox.open()`
/// 依赖 overlay 在 initState 里注册的回调，未挂载时是 no-op —— 所以这里先
/// 启用浮层，等它挂载并注册完成后再打开面板。
Future<void> openBlackBoxPanel() async {
  if (kReleaseMode) {
    return;
  }
  if (!BlackBoxOverlayPreferences.instance.visible) {
    await BlackBoxOverlayPreferences.instance.setVisible(true);
    // 第一帧挂载 BlackBoxOverlay，第二帧确保 registerOverlayCallbacks 已生效。
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
  }
  BlackBox.open();
}
