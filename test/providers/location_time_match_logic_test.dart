import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/location_time_group.dart';
import 'package:university_timetable/providers/timetable/location_time_match_logic.dart';

LocationTimeGroup _group({
  required String id,
  required String name,
  required String schemeId,
  List<LocationKeyword> keywords = const [],
  bool enabled = true,
  int priority = 0,
}) {
  return LocationTimeGroup(
    id: id,
    name: name,
    timeSchemeId: schemeId,
    enabled: enabled,
    priority: priority,
    keywords: keywords,
  );
}

void main() {
  group('LocationTimeMatchLogic.match', () {
    final mainBuilding = _group(
      id: 'main',
      name: '主教学楼',
      schemeId: 'scheme-main',
      keywords: const [
        LocationKeyword(pattern: 'A主', mode: LocationKeywordMatchMode.prefix),
        LocationKeyword(pattern: '主教', mode: LocationKeywordMatchMode.contains),
      ],
    );
    final otherBuilding = _group(
      id: 'other',
      name: '其他教学楼',
      schemeId: 'scheme-other',
      keywords: const [
        LocationKeyword(pattern: 'A1', mode: LocationKeywordMatchMode.prefix),
        LocationKeyword(pattern: 'A6', mode: LocationKeywordMatchMode.prefix),
        LocationKeyword(pattern: '一教', mode: LocationKeywordMatchMode.contains),
        LocationKeyword(pattern: '六教', mode: LocationKeywordMatchMode.contains),
      ],
    );
    final groups = [mainBuilding, otherBuilding];

    test('returns null for empty location', () {
      expect(LocationTimeMatchLogic.match('', groups), isNull);
      expect(LocationTimeMatchLogic.match('   ', groups), isNull);
      expect(LocationTimeMatchLogic.match(null, groups), isNull);
    });

    test('matches 城科-style main building locations', () {
      final result = LocationTimeMatchLogic.match('A主201', groups);
      expect(result, isNotNull);
      expect(result!.groupId, 'main');
      expect(result.timeSchemeId, 'scheme-main');
      expect(result.matchedKeyword.pattern, 'A主');
    });

    test('matches other building A1 / A6 prefixes', () {
      final a1 = LocationTimeMatchLogic.match('A1062', groups);
      expect(a1?.groupId, 'other');
      expect(a1?.matchedKeyword.pattern, 'A1');

      final a6 = LocationTimeMatchLogic.match('A6106', groups);
      expect(a6?.groupId, 'other');
      expect(a6?.matchedKeyword.pattern, 'A6');
    });

    test('prefers longer keyword over shorter prefix', () {
      final withA10 = [
        _group(
          id: 'a1',
          name: '一教',
          schemeId: 's1',
          keywords: const [
            LocationKeyword(
              pattern: 'A1',
              mode: LocationKeywordMatchMode.prefix,
            ),
          ],
        ),
        _group(
          id: 'a10',
          name: '十教',
          schemeId: 's10',
          keywords: const [
            LocationKeyword(
              pattern: 'A10',
              mode: LocationKeywordMatchMode.prefix,
            ),
          ],
        ),
      ];

      final result = LocationTimeMatchLogic.match('A10xxx', withA10);
      expect(result?.groupId, 'a10');
      expect(result?.timeSchemeId, 's10');
    });

    test('uses higher priority when keyword lengths tie', () {
      final tied = [
        _group(
          id: 'low',
          name: 'Low',
          schemeId: 'low-scheme',
          priority: 1,
          keywords: const [
            LocationKeyword(
              pattern: 'AB',
              mode: LocationKeywordMatchMode.prefix,
            ),
          ],
        ),
        _group(
          id: 'high',
          name: 'High',
          schemeId: 'high-scheme',
          priority: 10,
          keywords: const [
            LocationKeyword(
              pattern: 'AB',
              mode: LocationKeywordMatchMode.prefix,
            ),
          ],
        ),
      ];

      final result = LocationTimeMatchLogic.match('AB101', tied);
      expect(result?.groupId, 'high');
    });

    test('is case-insensitive', () {
      final result = LocationTimeMatchLogic.match('a主201', groups);
      expect(result?.groupId, 'main');
    });

    test('supports exact and contains modes', () {
      final exactGroups = [
        _group(
          id: 'exact',
          name: 'Exact',
          schemeId: 'exact-scheme',
          keywords: const [
            LocationKeyword(
              pattern: 'LAB',
              mode: LocationKeywordMatchMode.exact,
            ),
          ],
        ),
      ];
      expect(
        LocationTimeMatchLogic.match('LAB', exactGroups)?.groupId,
        'exact',
      );
      expect(LocationTimeMatchLogic.match('LAB1', exactGroups), isNull);

      final contains = LocationTimeMatchLogic.match('综合楼一教301', groups);
      expect(contains?.groupId, 'other');
      expect(contains?.matchedKeyword.pattern, '一教');
    });

    test('skips disabled groups and empty scheme ids', () {
      final disabled = [
        mainBuilding.copyWith(enabled: false),
        otherBuilding.copyWith(timeSchemeId: ''),
      ];
      expect(LocationTimeMatchLogic.match('A主201', disabled), isNull);
      expect(LocationTimeMatchLogic.match('A1062', disabled), isNull);
    });

    test('returns null when nothing matches', () {
      expect(LocationTimeMatchLogic.match('体育馆', groups), isNull);
    });
  });

  group('LocationTimeGroup serialization', () {
    test('round-trips json', () {
      final group = LocationTimeGroup(
        id: 'g1',
        name: '其他教学楼',
        timeSchemeId: 'scheme-other',
        enabled: true,
        priority: 2,
        keywords: const [
          LocationKeyword(pattern: 'A1', mode: LocationKeywordMatchMode.prefix),
          LocationKeyword(
            pattern: '六教',
            mode: LocationKeywordMatchMode.contains,
          ),
        ],
      );

      final restored = LocationTimeGroup.fromJson(group.toJson());
      expect(restored.id, group.id);
      expect(restored.name, group.name);
      expect(restored.timeSchemeId, group.timeSchemeId);
      expect(restored.enabled, isTrue);
      expect(restored.priority, 2);
      expect(restored.keywords, hasLength(2));
      expect(restored.keywords.first.pattern, 'A1');
      expect(restored.keywords.last.mode, LocationKeywordMatchMode.contains);
      expect(restored.keywordSummary, 'A1, 六教');
    });
  });
}
