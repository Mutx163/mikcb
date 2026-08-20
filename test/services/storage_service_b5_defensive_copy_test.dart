import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/location_time_group.dart';
import 'package:university_timetable/models/schedule_date_rule.dart';
import 'package:university_timetable/models/time_scheme.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/storage_service.dart';

TimeScheme _scheme(String id, String name) {
  return TimeScheme(
    id: id,
    name: name,
    sections: const [SectionTime(startTime: '08:00', endTime: '08:45')],
    createdAt: DateTime(2026, 3, 22, 8),
    updatedAt: DateTime(2026, 3, 22, 8),
  );
}

LocationTimeGroup _group(String id, String schemeId) {
  return LocationTimeGroup(
    id: id,
    name: 'group-$id',
    timeSchemeId: schemeId,
    keywords: const [LocationKeyword(pattern: 'A')],
  );
}

ScheduleDateRule _rule(String id, String schemeId) {
  return ScheduleDateRule(
    id: id,
    name: 'rule-$id',
    timeSchemeId: schemeId,
    startDate: '2026-03-01',
    endDate: '2026-03-10',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  group('B5 cache-hit getters return defensive copies', () {
    test('getTimeSchemes cache hit is not mutated by caller', () async {
      final storage = StorageService();
      await storage.init();
      // Ensure profile init does not interfere
      await storage.getProfiles();
      final a = _scheme('s-a', 'A');
      final b = _scheme('s-b', 'B');
      await storage.saveTimeSchemes([a, b]);

      final first = await storage.getTimeSchemes();
      expect(first, hasLength(2));
      // Mutate caller-owned list
      first.add(_scheme('s-c', 'C'));
      expect(first, hasLength(3));

      final second = await storage.getTimeSchemes();
      expect(second, hasLength(2),
          reason: 'cache must be isolated from caller mutation');
      // Mutating second must not affect third either
      second.clear();
      final third = await storage.getTimeSchemes();
      expect(third, hasLength(2));
    });

    test('getTimeSchemes decoded path also defensive', () async {
      final storage = StorageService();
      await storage.init();
      await storage.getProfiles();
      final a = _scheme('s-x', 'X');
      await storage.saveTimeSchemes([a]);
      // Force reload from disk by resetting caches via prefs swap simulation:
      // resetForTesting clears caches but keep disk; re-init should decode
      final prefs = await SharedPreferences.getInstance();
      // simulate app restart: keep prefs but clear in-memory caches
      StorageService().resetForTesting();
      // Re-inject same prefs backing (mock keeps values globally)
      // Need to re-set mock values from current prefs snapshot
      // Simpler: just use new StorageService instance after reset
      // SharedPreferences mock retains values, so next getTimeSchemes decodes
      SharedPreferences.setMockInitialValues({
        'timetable_profiles': prefs.getString('timetable_profiles') ?? '',
        'active_timetable_profile_id':
            prefs.getString('active_timetable_profile_id') ?? '',
        'time_schemes': prefs.getString('time_schemes') ?? '',
      });
      // Need fresh prefs instance to see new mock values
      StorageService().resetForTesting();
      final fresh = StorageService();
      await fresh.init();
      final decoded = await fresh.getTimeSchemes();
      expect(decoded, hasLength(1));
      decoded.add(_scheme('s-y', 'Y'));
      final after = await fresh.getTimeSchemes();
      expect(after, hasLength(1));
    });

    test('getLocationTimeGroups cache hit is defensive', () async {
      final storage = StorageService();
      await storage.init();
      final g1 = _group('g1', 's-a');
      final g2 = _group('g2', 's-a');
      await storage.saveLocationTimeGroups([g1, g2]);

      final first = await storage.getLocationTimeGroups();
      expect(first, hasLength(2));
      first.removeAt(0);
      first.add(_group('g3', 's-a'));

      final second = await storage.getLocationTimeGroups();
      expect(second, hasLength(2));
      expect(second.map((e) => e.id), containsAll(['g1', 'g2']));
    });

    test('getScheduleDateRules cache hit is defensive', () async {
      final storage = StorageService();
      await storage.init();
      final r1 = _rule('r1', 's-a');
      final r2 = _rule('r2', 's-a');
      await storage.saveScheduleDateRules([r1, r2]);

      final first = await storage.getScheduleDateRules();
      expect(first, hasLength(2));
      first.clear();
      expect(first, isEmpty);

      final second = await storage.getScheduleDateRules();
      expect(second, hasLength(2));
    });

    test('decoded groups and rules skip malformed records individually', () async {
      final storage = StorageService();
      await storage.init();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('location_time_groups', jsonEncode([
        _group('g-good', 's-a').toJson(),
        'bad-group',
        {'id': 'g-bad-keywords', 'name': 'bad', 'timeSchemeId': 's-a', 'keywords': 7},
      ]));
      await prefs.setString('schedule_date_rules', jsonEncode([
        _rule('r-good', 's-a').toJson(),
        42,
        {'id': 'r-bad', 'name': 'bad', 'timeSchemeId': 's-a', 'startDate': null, 'endDate': '2026-03-10'},
      ]));
      storage.resetForTesting();
      final fresh = StorageService();
      await fresh.init();

      final groups = await fresh.getLocationTimeGroups();
      final rules = await fresh.getScheduleDateRules();
      expect(groups.map((item) => item.id), ['g-good']);
      expect(rules.map((item) => item.id), ['r-good']);
    });

    test('mutating returned list does not corrupt subsequent saves', () async {
      final storage = StorageService();
      await storage.init();
      final g = _group('g1', 's-a');
      await storage.saveLocationTimeGroups([g]);
      final fetched = await storage.getLocationTimeGroups();
      fetched.add(_group('g2', 's-a'));
      // Save should still see only original unless caller explicitly saves
      final again = await storage.getLocationTimeGroups();
      expect(again, hasLength(1));
    });
  });
}
