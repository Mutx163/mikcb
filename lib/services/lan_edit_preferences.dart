import 'package:shared_preferences/shared_preferences.dart';

/// Preferences for the LAN edit console.
class LanEditPreferences {
  LanEditPreferences._();

  /// When true, leaving [LanEditScreen] does not stop the HTTP server.
  static const String keepAliveWhenLeavingKey =
      'lan_edit_keep_alive_when_leaving';

  /// Default matches historical behaviour: pop route → stop server.
  static const bool defaultKeepAliveWhenLeaving = false;

  /// In-process cache so [LanEditScreen.dispose] can decide without racing
  /// an unfinished async load.
  static bool? _cachedKeepAliveWhenLeaving;

  /// Last known value (falls back to [defaultKeepAliveWhenLeaving]).
  static bool get keepAliveWhenLeavingCached =>
      _cachedKeepAliveWhenLeaving ?? defaultKeepAliveWhenLeaving;

  /// `null` until [keepAliveWhenLeaving] or [setKeepAliveWhenLeaving] runs.
  static bool? get keepAliveWhenLeavingOrNull => _cachedKeepAliveWhenLeaving;

  static Future<bool> keepAliveWhenLeaving() async {
    if (_cachedKeepAliveWhenLeaving != null) {
      return _cachedKeepAliveWhenLeaving!;
    }
    final preferences = await SharedPreferences.getInstance();
    final value =
        preferences.getBool(keepAliveWhenLeavingKey) ??
        defaultKeepAliveWhenLeaving;
    _cachedKeepAliveWhenLeaving = value;
    return value;
  }

  static Future<void> setKeepAliveWhenLeaving(bool enabled) async {
    _cachedKeepAliveWhenLeaving = enabled;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(keepAliveWhenLeavingKey, enabled);
  }
}
