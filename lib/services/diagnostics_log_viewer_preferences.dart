import 'package:shared_preferences/shared_preferences.dart';

/// Persists viewer UI preferences for the diagnostics log screen.
class DiagnosticsLogViewerPreferences {
  DiagnosticsLogViewerPreferences._();

  static const _timeSortKey = 'diagnostics_log_time_sort';
  static const ascending = 'ascending';
  static const descending = 'descending';

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
