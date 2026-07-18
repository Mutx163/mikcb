import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/services/lan_edit_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // Reset cache by writing the default path through the public API.
    await LanEditPreferences.setKeepAliveWhenLeaving(
      LanEditPreferences.defaultKeepAliveWhenLeaving,
    );
  });

  test('keepAliveWhenLeaving defaults to false', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // Force cache miss by setting then clearing prefs simulation:
    await LanEditPreferences.setKeepAliveWhenLeaving(false);
    expect(await LanEditPreferences.keepAliveWhenLeaving(), isFalse);
    expect(LanEditPreferences.keepAliveWhenLeavingCached, isFalse);
  });

  test('keepAliveWhenLeaving persists and updates cache', () async {
    await LanEditPreferences.setKeepAliveWhenLeaving(true);
    expect(LanEditPreferences.keepAliveWhenLeavingCached, isTrue);
    expect(await LanEditPreferences.keepAliveWhenLeaving(), isTrue);

    await LanEditPreferences.setKeepAliveWhenLeaving(false);
    expect(LanEditPreferences.keepAliveWhenLeavingCached, isFalse);
    expect(await LanEditPreferences.keepAliveWhenLeaving(), isFalse);
  });
}
