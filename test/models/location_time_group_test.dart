import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/location_time_group.dart';

void main() {
  group('LocationKeywordMatchMode', () {
    test('fromValue roundtrips known modes', () {
      for (final mode in LocationKeywordMatchMode.values) {
        expect(LocationKeywordMatchMode.fromValue(mode.value), mode);
        expect(mode.value, mode.name);
      }
    });

    test('fromValue defaults unknown to prefix', () {
      expect(
        LocationKeywordMatchMode.fromValue('garbage'),
        LocationKeywordMatchMode.prefix,
      );
      expect(
        LocationKeywordMatchMode.fromValue(null),
        LocationKeywordMatchMode.prefix,
      );
    });
  });

  group('LocationKeyword', () {
    test('round-trips json and trims pattern', () {
      final keyword = LocationKeyword.fromJson(const {
        'pattern': '  A主  ',
        'mode': 'contains',
      });

      expect(keyword.pattern, 'A主');
      expect(keyword.mode, LocationKeywordMatchMode.contains);

      final restored = LocationKeyword.fromJson(keyword.toJson());
      expect(restored, keyword);
    });

    test('copyWith and equality', () {
      const original = LocationKeyword(
        pattern: 'A1',
        mode: LocationKeywordMatchMode.prefix,
      );
      final updated = original.copyWith(
        pattern: 'A6',
        mode: LocationKeywordMatchMode.exact,
      );

      expect(updated.pattern, 'A6');
      expect(updated.mode, LocationKeywordMatchMode.exact);
      expect(
        original,
        const LocationKeyword(
          pattern: 'A1',
          mode: LocationKeywordMatchMode.prefix,
        ),
      );
      expect(original == updated, isFalse);
    });
  });

  group('LocationTimeGroup', () {
    test('round-trips json and drops empty keyword patterns', () {
      final original = LocationTimeGroup(
        id: 'group-1',
        name: '  主教学楼  ',
        timeSchemeId: 'scheme-main',
        enabled: false,
        priority: 3,
        keywords: const [
          LocationKeyword(pattern: 'A主', mode: LocationKeywordMatchMode.prefix),
          LocationKeyword(
            pattern: '主教',
            mode: LocationKeywordMatchMode.contains,
          ),
        ],
      );

      final json = original.toJson();
      // Simulate a dirty payload with an empty pattern entry.
      final dirty = Map<String, dynamic>.from(json)
        ..['keywords'] = [
          ...json['keywords'] as List<dynamic>,
          {'pattern': '   ', 'mode': 'exact'},
        ];

      final restored = LocationTimeGroup.fromJson(dirty);

      expect(restored.id, 'group-1');
      expect(restored.name, '主教学楼');
      expect(restored.timeSchemeId, 'scheme-main');
      expect(restored.enabled, isFalse);
      expect(restored.priority, 3);
      expect(restored.keywords, hasLength(2));
      expect(restored.keywords.first.pattern, 'A主');
      expect(restored.keywordSummary, 'A主, 主教');
    });

    test('fromJson defaults and empty keyword summary', () {
      final restored = LocationTimeGroup.fromJson(const {
        'id': null,
        'name': null,
        'timeSchemeId': null,
      });

      expect(restored.id, '');
      expect(restored.name, '');
      expect(restored.timeSchemeId, '');
      expect(restored.enabled, isTrue);
      expect(restored.priority, 0);
      expect(restored.keywords, isEmpty);
      expect(restored.keywordSummary, '');
    });

    test('json string helpers and copyWith', () {
      const original = LocationTimeGroup(
        id: 'group-2',
        name: '实验楼',
        timeSchemeId: 'scheme-lab',
        keywords: [
          LocationKeyword(pattern: 'B1', mode: LocationKeywordMatchMode.exact),
        ],
      );

      final restored = LocationTimeGroup.fromJsonString(
        original.toJsonString(),
      );
      expect(restored.id, original.id);
      expect(restored.keywords.single.mode, LocationKeywordMatchMode.exact);

      final updated = original.copyWith(
        name: '新实验楼',
        priority: 9,
        enabled: false,
      );
      expect(updated.name, '新实验楼');
      expect(updated.priority, 9);
      expect(updated.enabled, isFalse);
      expect(updated.timeSchemeId, original.timeSchemeId);
    });
  });
}
