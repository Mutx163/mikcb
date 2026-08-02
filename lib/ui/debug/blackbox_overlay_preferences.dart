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

  bool _visible = true;
  bool _loaded = false;

  bool get visible => _visible;

  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedVisible = prefs.getBool(_visibleKey);
    final legacyVisible = prefs.getBool(_legacyVisibleKey);
    _visible = savedVisible ?? legacyVisible ?? true;
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
