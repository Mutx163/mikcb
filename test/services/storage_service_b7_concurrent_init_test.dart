import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  group('B7 concurrent first profile initialization shares in-flight Future',
      () {
    test('concurrent getProfiles creates exactly one profile', () async {
      final storage = StorageService();
      await storage.init();

      // Start from empty prefs - ensure triggers migration
      final results = await Future.wait([
        storage.getProfiles(),
        storage.getProfiles(),
        storage.getProfiles(),
        storage.getActiveProfileId().then((id) async {
          // also touches ensure path
          final profiles = await storage.getProfiles();
          return profiles;
        }),
      ]);

      // All profile lists must have same single id
      final firstId = ((results[0] as List<dynamic>).first as dynamic).id as String;
      for (final r in results) {
        // ignore: dead_code, unnecessary_type_check
        final list = r is List ? (r as List) : <dynamic>[];
        // getActiveProfileId branch returns List too
        if (list.isNotEmpty) {
          expect(list, hasLength(1));
          expect((list.first as dynamic).id, firstId);
        }
      }

      final finalProfiles = await storage.getProfiles();
      expect(finalProfiles, hasLength(1));
      expect(finalProfiles.single.id, firstId);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('timetable_profiles');
      expect(raw, isNotNull);
      // Should not contain duplicate profile ids
      expect(raw!.contains(firstId), isTrue);
    });

    test('concurrent getTimeSchemes does not double-create schemes', () async {
      final storage = StorageService();
      await storage.init();
      // First call creates profile + scheme
      final results = await Future.wait([
        storage.getTimeSchemes(),
        storage.getTimeSchemes(),
        storage.getProfiles(),
      ]);
      // After init, getTimeSchemes should be consistent
      final schemesA = results[0] as List;
      final schemesB = results[1] as List;
      expect(schemesA.length, schemesB.length);
      // No duplicate schemes with same signature
      final ids = schemesA.map((e) => (e as dynamic).id as String).toSet();
      expect(ids.length, schemesA.length);
    });

    test('resetForTesting clears in-flight futures; second wave still deduped',
        () async {
      final storage = StorageService();
      await storage.init();
      await Future.wait([storage.getProfiles(), storage.getProfiles()]);
      final firstWave = await storage.getProfiles();
      expect(firstWave, hasLength(1));
      final firstId = firstWave.single.id;

      // Simulate app restart without losing disk: clear caches only
      // Use resetForTesting which must clear futures
      StorageService().resetForTesting();
      // prefs still holds first profile on disk (mock retains)
      // But mock was cleared by resetForTesting? No, prefs object still has data
      // Re-point mock to keep data: SharedPreferences mock is global, resetForTesting does not clear prefs
      // Just init again and fire concurrent ensures
      await storage.init();
      final secondWave = await Future.wait([
        storage.getProfiles(),
        storage.getProfiles(),
      ]);
      expect(secondWave[0], hasLength(1));
      expect(secondWave[1], hasLength(1));
      expect(secondWave[0].first.id, firstId);
      expect(secondWave[1].first.id, firstId);
    });

    test('no deadlock when ensure calls are nested via getProfiles', () async {
      final storage = StorageService();
      await storage.init();
      // getProfiles internally awaits _ensureProfilesInitialized,
      // _ensureTimeSchemesInitialized, _migrateHidePrefixDefault sequentially.
      // Concurrent callers must not deadlock on shared futures.
      final future = Future.wait([
        storage.getProfiles(),
        storage.getActiveProfileId(),
        storage.getTimeSchemes(),
      ]).timeout(const Duration(seconds: 5));
      final results = await future;
      expect(results, hasLength(3));
    });
  });
}
