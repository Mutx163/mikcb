import 'package:shared_preferences/shared_preferences.dart';

/// Persists viewer UI preferences for the diagnostics log screen.
class DiagnosticsLogViewerPreferences {
  DiagnosticsLogViewerPreferences._();

  static const _timeSortKey = 'diagnostics_log_time_sort';
  static const _displayOptionsExpandedKey =
      'diagnostics_log_display_options_expanded';
  static const ascending = 'ascending';
  static const descending = 'descending';

  static Future<bool> loadDisplayOptionsExpanded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_displayOptionsExpandedKey) ?? false;
  }

  static Future<void> saveDisplayOptionsExpanded(bool expanded) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayOptionsExpandedKey, expanded);
  }

  static Future<String> loadTimeSort() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_timeSortKey);
    if (value == descending) {
      return descending;
    }
    return ascending;
  }

  static Future<void> saveTimeSort(String sort) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _timeSortKey,
      sort == descending ? descending : ascending,
    );
  }
}
