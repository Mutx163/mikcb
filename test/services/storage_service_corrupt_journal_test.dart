import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  group('StorageService corrupt settings-mirror journal', () {
    // Regression: an unreadable transaction journal used to throw from _doInit,
    // and because the throw happened before any cleanup the record stayed on
    // disk forever. Every launch then failed and the pending-transaction guard
    // made every settings save fail too, so the user's only way out was
    // "clear app data". A corrupt journal must not be able to do that.
    test('unreadable journal is quarantined instead of bricking init', () async {
      SharedPreferences.setMockInitialValues({
        StorageService.settingsMirrorTransactionKey: '{not valid json',
      });

      final storage = StorageService();
      await storage.init();

      final prefs = await SharedPreferences.getInstance();
      // The bad payload is preserved for inspection, under a backup key...
      final backupKeys = prefs
          .getKeys()
          .where((k) => k.startsWith('${StorageService.settingsMirrorTransactionKey}_corrupt_backup_'))
          .toList();
      expect(backupKeys, hasLength(1));
      expect(prefs.getString(backupKeys.single), '{not valid json');
      // ...and the blocking key is gone, so saves are not rejected any more.
      expect(
        prefs.getString(StorageService.settingsMirrorTransactionKey),
        isNull,
      );
    });

    test('a journal from a newer app version still blocks startup, untouched', () async {
      // Deliberate carve-out, and the reason the corrupt cases above are safe to
      // quarantine: a journal whose version this build does not know must be
      // preserved and must stop the app from booting, because rolling back a
      // format we cannot interpret could put settings into a wrong state. The
      // remedy there is upgrading, not self-healing.
      const raw = '{"version":99,"transactionId":"future","state":"pending"}';
      SharedPreferences.setMockInitialValues({
        StorageService.settingsMirrorTransactionKey: raw,
      });

      final storage = StorageService();
      await expectLater(storage.init(), throwsA(isA<StateError>()));

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(StorageService.settingsMirrorTransactionKey),
        raw,
      );
    });

    test('a settings write succeeds after a corrupt journal was quarantined', () async {
      SharedPreferences.setMockInitialValues({
        StorageService.settingsMirrorTransactionKey: '{not valid json',
      });

      final storage = StorageService();
      await storage.init();

      // This is the user-visible half of the bug: saving settings used to throw
      // "settings_mirror_transaction_already_pending" on every attempt.
      await expectLater(
        storage.saveTimetableSettings(TimetableSettings.defaults()),
        completes,
      );
    });
  });
}
