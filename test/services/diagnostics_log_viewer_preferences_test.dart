import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/services/diagnostics_log_viewer_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to ascending when unset', () async {
    expect(
      await DiagnosticsLogViewerPreferences.loadTimeSort(),
      DiagnosticsLogViewerPreferences.ascending,
    );
  });

  test('persists descending sort', () async {
    await DiagnosticsLogViewerPreferences.saveTimeSort(
      DiagnosticsLogViewerPreferences.descending,
    );
    expect(
      await DiagnosticsLogViewerPreferences.loadTimeSort(),
      DiagnosticsLogViewerPreferences.descending,
    );
  });

  test('persists ascending sort after descending', () async {
    await DiagnosticsLogViewerPreferences.saveTimeSort(
      DiagnosticsLogViewerPreferences.descending,
    );
    await DiagnosticsLogViewerPreferences.saveTimeSort(
      DiagnosticsLogViewerPreferences.ascending,
    );
    expect(
      await DiagnosticsLogViewerPreferences.loadTimeSort(),
      DiagnosticsLogViewerPreferences.ascending,
    );
  });
}
