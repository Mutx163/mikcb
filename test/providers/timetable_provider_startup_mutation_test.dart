import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/storage_service.dart';

class _DelayedStartupMigrationStorage extends StorageService {
  _DelayedStartupMigrationStorage() : super.forTesting();

  final Completer<void> migrationStarted = Completer<void>();
  final Completer<bool> migrationResult = Completer<bool>();

  @override
  Future<bool> hasMigratedAppLogsDefault() {
    if (!migrationStarted.isCompleted) {
      migrationStarted.complete();
    }
    return migrationResult.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'external mutation waits for startup migration before taking gate',
    () async {
      final storage = _DelayedStartupMigrationStorage();
      addTearDown(() {
        if (!storage.migrationResult.isCompleted) {
          storage.migrationResult.complete(false);
        }
      });
      final provider = TimetableProvider(
        storageService: storage,
        autoInitialize: false,
        enableLiveActivitySync: false,
      );

      await provider.initialize();
      await storage.migrationStarted.future;
      var actionEntered = false;
      final mutation = provider.runMutationExclusive(() async {
        actionEntered = true;
      });
      await Future<void>.delayed(Duration.zero);

      expect(actionEntered, isFalse);
      storage.migrationResult.complete(false);
      await mutation;
      expect(actionEntered, isTrue);
    },
  );
}
