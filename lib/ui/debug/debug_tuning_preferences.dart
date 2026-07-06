import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the debug tuning overlay is visible (non-release builds).
class DebugTuningPreferences extends ChangeNotifier {
  DebugTuningPreferences._();

  static final DebugTuningPreferences instance = DebugTuningPreferences._();

  static const _visibleKey = 'debug_tuning_panel_visible';

  bool _visible = true;
  bool _loaded = false;

  bool get visible => _visible;

  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _visible = prefs.getBool(_visibleKey) ?? true;
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
Future<void> loadDebugTuningPreferencesIfNeeded() async {
  if (kReleaseMode) return;
  await DebugTuningPreferences.instance.load();
}
