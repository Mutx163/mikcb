import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/location_time_group.dart';
import 'package:university_timetable/models/schedule_date_rule.dart';
import 'package:university_timetable/models/time_scheme.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/storage_service.dart';

TimetableProfile _profile({List<SectionTime>? sections}) {
  final now = DateTime(2026, 3, 22, 8);
  final defaults = TimetableSettings.defaults();
  return TimetableProfile(
    id: 'profile-b5',
    name: 'B5',
    courses: const [],
    settings: sections == null
        ? defaults
        : defaults.copyWith(sections: List<SectionTime>.from(sections)),
    currentWeek: 1,
    createdAt: now,
    lastUsedAt: now,
  );
}

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
      await storage.getProfiles();
      await storage.saveProfiles([_profile()]);
      final a = _scheme('s-a', 'A');
      final b = _scheme('s-b', 'B');
      await storage.saveTimeSchemes([a, b]);

      final first = await storage.getTimeSchemes();
      expect(first, hasLength(2));
      // Mutate caller-owned list
      first.add(_scheme('s-c', 'C'));
      expect(first, hasLength(3));

      final second = await storage.getTimeSchemes();
      expect(
        second,
        hasLength(2),
        reason: 'cache must be isolated from caller mutation',
      );
      second.first.sections.add(
        const SectionTime(startTime: '09:00', endTime: '09:45'),
      );
      final third = await storage.getTimeSchemes();
      expect(third, hasLength(2));
      expect(third.first.sections, hasLength(1));
      // Mutating third must not affect the cache either.
      third.clear();
      final fourth = await storage.getTimeSchemes();
      expect(fourth, hasLength(2));
    });

    test('getTimeSchemes decoded path also defensive', () async {
      final storage = StorageService();
      await storage.init();
      await storage.getProfiles();
      final a = _scheme('s-x', 'X');
      await storage.saveProfiles([_profile(sections: a.sections)]);
      await storage.saveTimeSchemes([a]);
      // Force reload from disk by resetting caches via prefs swap simulation:
      // resetForTesting clears caches but keep disk; re-init should decode
      final prefs = await SharedPreferences.getInstance();
      final storedProfiles = prefs.getString('timetable_profiles') ?? '';
      final storedActiveProfileId =
          prefs.getString('active_timetable_profile_id') ?? '';
      final storedTimeSchemes = prefs.getString('time_schemes') ?? '';
      // simulate app restart: keep persisted values but clear plugin singleton
      StorageService().resetForTesting();
      // Re-inject same prefs backing (mock keeps values globally)
      // Need to re-set mock values from current prefs snapshot
      // Simpler: just use new StorageService instance after reset
      // SharedPreferences mock retains values, so next getTimeSchemes decodes
      SharedPreferences.setMockInitialValues({
        'timetable_profiles': storedProfiles,
        'active_timetable_profile_id': storedActiveProfileId,
        'time_schemes': storedTimeSchemes,
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
      await storage.getProfiles();
      await storage.saveProfiles([_profile()]);
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
      second.first.keywords.add(const LocationKeyword(pattern: 'B'));
      final third = await storage.getLocationTimeGroups();
      expect(third.first.keywords, hasLength(1));
    });

    test('getScheduleDateRules cache hit is defensive', () async {
      final storage = StorageService();
      await storage.init();
      await storage.getProfiles();
      await storage.saveProfiles([_profile()]);
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

    test(
      'decoded groups and rules skip malformed records individually',
      () async {
        final storage = StorageService();
        await storage.init();
        await storage.getProfiles();
        await storage.saveProfiles([_profile()]);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'location_time_groups',
          jsonEncode([
            _group('g-good', 's-a').toJson(),
            'bad-group',
            {
              'id': 7,
              'name': 'bad',
              'timeSchemeId': 's-a',
              'keywords': [42],
            },
          ]),
        );
        await prefs.setString(
          'schedule_date_rules',
          jsonEncode([
            _rule('r-good', 's-a').toJson(),
            42,
            {
              'id': 'r-bad',
              'name': 'bad',
              'timeSchemeId': 's-a',
              'startDate': null,
              'endDate': '2026-03-10',
            },
          ]),
        );
        storage.resetForTesting();
        final fresh = StorageService();
        await fresh.init();

        final groups = await fresh.getLocationTimeGroups();
        final rules = await fresh.getScheduleDateRules();
        expect(groups.map((item) => item.id), ['g-good']);
        expect(rules.map((item) => item.id), ['r-good']);
      },
    );

    test('mutating returned list does not corrupt subsequent saves', () async {
      final storage = StorageService();
      await storage.init();
      await storage.getProfiles();
      await storage.saveProfiles([_profile()]);
      final g = _group('g1', 's-a');
      await storage.saveLocationTimeGroups([g]);
      final fetched = await storage.getLocationTimeGroups();
      fetched.add(_group('g2', 's-a'));
      // Save should still see only original unless caller explicitly saves
      final again = await storage.getLocationTimeGroups();
      expect(again, hasLength(1));
    });

    test('save snapshots nested collections before caller mutation', () async {
      final storage = StorageService();
      await storage.init();
      await storage.getProfiles();
      await storage.saveProfiles([_profile()]);
      final sections = <SectionTime>[
        const SectionTime(startTime: '08:00', endTime: '08:45'),
      ];
      final keywords = <LocationKeyword>[const LocationKeyword(pattern: 'A')];
      final scheme = TimeScheme(
        id: 's-snapshot',
        name: 'Snapshot',
        sections: sections,
        createdAt: DateTime(2026, 3, 22),
        updatedAt: DateTime(2026, 3, 22),
      );
      final group = LocationTimeGroup(
        id: 'g-snapshot',
        name: 'Snapshot',
        timeSchemeId: 's-snapshot',
        keywords: keywords,
      );
      await storage.saveTimeSchemes([scheme]);
      await storage.saveLocationTimeGroups([group]);
      sections.add(const SectionTime(startTime: '09:00', endTime: '09:45'));
      keywords.add(const LocationKeyword(pattern: 'B'));

      expect((await storage.getTimeSchemes()).single.sections, hasLength(1));
      expect(
        (await storage.getLocationTimeGroups()).single.keywords,
        hasLength(1),
      );
    });
  });
}
