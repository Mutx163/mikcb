import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/location_time_group.dart';
import 'package:university_timetable/domain/location_time_match_logic.dart';

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
        LocationKeyword(pattern: 'A主'),
        LocationKeyword(pattern: '主教', mode: LocationKeywordMatchMode.contains),
      ],
    );
    final otherBuilding = _group(
      id: 'other',
      name: '其他教学楼',
      schemeId: 'scheme-other',
      keywords: const [
        LocationKeyword(pattern: 'A1'),
        LocationKeyword(pattern: 'A6'),
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

    test('collapses whitespace so auto-cluster keywords hit spaced rooms', () {
      // Building cluster normalizes "测试教室 01" → key "测试教室" (no space).
      // Match must collapse spaces too, or 一键应用 leaves live_test_* on auto.
      final classroomGroups = [
        _group(
          id: 'fixture',
          name: '测试教室楼',
          schemeId: 'scheme-fixture',
          keywords: const [
            LocationKeyword(
              pattern: '测试教室',
              mode: LocationKeywordMatchMode.contains,
            ),
          ],
        ),
      ];

      final spaced = LocationTimeMatchLogic.match('测试教室 01', classroomGroups);
      expect(spaced?.groupId, 'fixture');
      expect(spaced?.matchedKeyword.pattern, '测试教室');

      final glued = LocationTimeMatchLogic.match('测试教室24', classroomGroups);
      expect(glued?.groupId, 'fixture');
    });

    test('aligns with cluster punctuation normalization (dot slash paren)', () {
      final dottedMain = [
        _group(
          id: 'main-dot',
          name: '主教学楼',
          schemeId: 'scheme-main',
          keywords: const [
            LocationKeyword(
              pattern: 'A主',
            ),
          ],
        ),
      ];

      // Use explicit code points so the test is independent of editor glyph
      // substitution (U+00B7 middle dot, U+2014 em dash).
      const withMiddleDot = 'A\u00B7\u4e3b201';
      const withEmDash = 'A\u2014\u4e3b201';
      const withParen = 'A\u4e3b\uff08\u4e1c\uff09201';

      expect(
        LocationTimeMatchLogic.normalizeLocation(withMiddleDot),
        'a\u4e3b201',
      );
      expect(
        LocationTimeMatchLogic.match(withMiddleDot, dottedMain)?.groupId,
        'main-dot',
      );
      // Em dash becomes ASCII hyphen (same as cluster); not a free strip.
      expect(
        LocationTimeMatchLogic.normalizeLocation(withEmDash),
        'a-\u4e3b201',
      );
      // Parentheses unwrap content: A主（东）201 → a主东201, still prefix of A主.
      expect(
        LocationTimeMatchLogic.match(withParen, dottedMain)?.groupId,
        'main-dot',
      );
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

  group('LocationTimeMatchLogic keyword exclusivity', () {
    final mainBuilding = _group(
      id: 'main',
      name: '主教学楼',
      schemeId: 'scheme-main',
      keywords: const [
        LocationKeyword(pattern: 'A主'),
      ],
    );
    final otherBuilding = _group(
      id: 'other',
      name: '其他教学楼',
      schemeId: 'scheme-other',
      keywords: const [
        LocationKeyword(pattern: 'A1'),
      ],
    );
    final groups = [mainBuilding, otherBuilding];

    test('patternsOwnedByOtherGroups excludes current group', () {
      final owned = LocationTimeMatchLogic.patternsOwnedByOtherGroups(
        groups,
        excludingGroupId: 'main',
      );
      expect(owned, contains('a1'));
      expect(owned, isNot(contains('a主')));
    });

    test('groupNameOwningPattern reports the owner', () {
      expect(
        LocationTimeMatchLogic.groupNameOwningPattern(groups, 'A主'),
        '主教学楼',
      );
      expect(
        LocationTimeMatchLogic.groupNameOwningPattern(
          groups,
          'A主',
          excludingGroupId: 'main',
        ),
        isNull,
      );
    });

    test('isLocationClaimedByOtherGroups hides claimed classrooms', () {
      expect(
        LocationTimeMatchLogic.isLocationClaimedByOtherGroups(
          'A主201',
          groups,
          excludingGroupId: 'other',
        ),
        isTrue,
      );
      expect(
        LocationTimeMatchLogic.isLocationClaimedByOtherGroups(
          'A主201',
          groups,
          excludingGroupId: 'main',
        ),
        isFalse,
      );
      expect(
        LocationTimeMatchLogic.isLocationClaimedByOtherGroups('体育馆', groups),
        isFalse,
      );
    });

    test('keywordsFromOtherGroups flattens foreign keywords', () {
      final keywords = LocationTimeMatchLogic.keywordsFromOtherGroups(
        groups,
        excludingGroupId: 'main',
      );
      expect(keywords.map((keyword) => keyword.pattern), ['A1']);
    });
  });

  group('LocationTimeGroup serialization', () {
    test('round-trips json', () {
      const group = LocationTimeGroup(
        id: 'g1',
        name: '其他教学楼',
        timeSchemeId: 'scheme-other',
        priority: 2,
        keywords: [
          LocationKeyword(pattern: 'A1'),
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
