import 'package:shared_preferences/shared_preferences.dart';

/// Global preference for randomizing course colors during import.
class ImportRandomColorPreferences {
  ImportRandomColorPreferences._();

  static const String preferenceKey = 'import_random_course_colors_enabled';

  /// Default is enabled so new imports get varied colors out of the box.
  static const bool defaultEnabled = true;

  static Future<bool> isEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(preferenceKey) ?? defaultEnabled;
  }

  static Future<void> setEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(preferenceKey, enabled);
  }

  /// Whether import should also assign a readable text color that matches the
  /// randomized card background.
  static const String textColorPreferenceKey =
      'import_random_course_text_color_enabled';

  /// Default off: text-color assignment is opt-in.
  static const bool defaultTextColorEnabled = false;

  static Future<bool> isTextColorEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(textColorPreferenceKey) ??
        defaultTextColorEnabled;
  }

  static Future<void> setTextColorEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(textColorPreferenceKey, enabled);
  }
}
