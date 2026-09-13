import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the Black Box debug UI is visible.
class BlackBoxOverlayPreferences extends ChangeNotifier {
  BlackBoxOverlayPreferences._();

  static final BlackBoxOverlayPreferences instance =
      BlackBoxOverlayPreferences._();

  static const _visibleKey = 'blackbox_overlay_visible';
  // Keep the preference from older builds so an existing choice is not lost.
  static const _legacyVisibleKey = 'debug_tuning_panel_visible';

  // 默认关闭。浮层是调试工具而非日常 UI：挂载它会给整棵树套一层
  // RepaintBoundary + Stack，并常驻若干 store 订阅；在排查发热/掉帧时，
  // 它自己就是最大的噪声源（见 blackbox_adapters.dart 中 trigger 的说明）。
  // 需要时在设置页 → 开发者选项里手动打开。
  bool _visible = false;
  bool _loaded = false;

  bool get visible => _visible;

  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedVisible = prefs.getBool(_visibleKey);
    final legacyVisible = prefs.getBool(_legacyVisibleKey);
    _visible = savedVisible ?? legacyVisible ?? false;
    if (savedVisible == null && legacyVisible != null) {
      await prefs.setBool(_visibleKey, legacyVisible);
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setVisible(bool value) async {
    if (_visible == value) return;
    _visible = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_visibleKey, value);
  }
}

/// No-op in release builds.
Future<void> loadBlackBoxOverlayPreferencesIfNeeded() async {
  if (kReleaseMode) return;
  await BlackBoxOverlayPreferences.instance.load();
}
