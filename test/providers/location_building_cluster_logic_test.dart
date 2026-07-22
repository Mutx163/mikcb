import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/location_time_group.dart';
import 'package:university_timetable/providers/timetable/location_building_cluster_logic.dart';

void main() {
  group('LocationBuildingClusterLogic.suggestKeywordFromLocation', () {
    test('extracts 城科-style prefixes', () {
      expect(
        LocationBuildingClusterLogic.suggestKeywordFromLocation(
          'A主201',
        )?.pattern,
        'A主',
      );
      expect(
        LocationBuildingClusterLogic.suggestKeywordFromLocation(
          'A1062',
        )?.pattern,
        'A1',
      );
      expect(
        LocationBuildingClusterLogic.suggestKeywordFromLocation(
          'A6106',
        )?.pattern,
        'A6',
      );
    });

    test('extracts Chinese teaching-building names', () {
      final keyword = LocationBuildingClusterLogic.suggestKeywordFromLocation(
        '综合楼一教301',
      );
      expect(keyword?.pattern, '一教');
      expect(keyword?.mode, LocationKeywordMatchMode.contains);
    });

    test('extracts A综 before trailing room code D101', () {
      final keyword = LocationBuildingClusterLogic.suggestKeywordFromLocation(
        'A综D101',
      );
      expect(keyword?.pattern, 'A综');
      expect(keyword?.mode, LocationKeywordMatchMode.prefix);
      expect(
        LocationBuildingClusterLogic.suggestKeywordFromLocation(
          'A综合楼201',
        )?.pattern,
        'A综',
      );
    });

    test('returns null for empty / unparseable', () {
      expect(
        LocationBuildingClusterLogic.suggestKeywordFromLocation(''),
        isNull,
      );
      expect(
        LocationBuildingClusterLogic.suggestKeywordFromLocation('体育馆')?.pattern,
        '体育馆',
      );
    });

    test('extracts named Chinese buildings beyond 城科 letter codes', () {
      expect(
        LocationBuildingClusterLogic.suggestKeywordFromLocation(
          '理工楼201',
        )?.pattern,
        '理工楼',
      );
      expect(
        LocationBuildingClusterLogic.suggestKeywordFromLocation(
          '逸夫楼A301',
        )?.pattern,
        '逸夫楼',
      );
      expect(
        LocationBuildingClusterLogic.suggestKeywordFromLocation(
          '东区实验中心3楼',
        )?.pattern,
        '实验中心',
      );
    });

    test('extracts classroom labels and virtual platforms', () {
      expect(
        LocationBuildingClusterLogic.suggestKeywordFromLocation(
          '测试教室',
        )?.pattern,
        '测试教室',
      );
      expect(
        LocationBuildingClusterLogic.suggestKeywordFromLocation(
          '劳动测评平台',
        )?.pattern,
        '劳动测评平台',
      );
      expect(
        LocationBuildingClusterLogic.suggestKeywordFromLocation(
          '在线测评平台',
        )?.pattern,
        '在线测评平台',
      );
    });

    test('does not treat room code after Chinese building as letter block', () {
      expect(
        LocationBuildingClusterLogic.suggestKeywordFromLocation(
          '理工楼A201',
        )?.pattern,
        '理工楼',
      );
    });

    test('extracts English building labels', () {
      expect(
        LocationBuildingClusterLogic.suggestKeywordFromLocation(
          'Science Hall 201',
        )?.pattern,
        'Science Hall',
      );
    });
  });

  group('LocationBuildingClusterLogic.clusterLocations', () {
    test('groups same-building rooms together', () {
      final clusters = LocationBuildingClusterLogic.clusterLocations(const [
        'A主201',
        'A主314',
        'A1062',
        'A1011',
        'A6106',
        'A6201',
      ]);

      final byKey = {
        for (final cluster in clusters) cluster.buildingKey: cluster,
      };
      expect(byKey.keys, containsAll(['A主', 'A1', 'A6']));
      expect(byKey['A主']!.locationCount, 2);
      expect(byKey['A1']!.locationCount, 2);
      expect(byKey['A6']!.locationCount, 2);
      expect(
        byKey['A1']!.suggestedKeyword.mode,
        LocationKeywordMatchMode.prefix,
      );
    });

    test('does not merge A1 with A10 when both present', () {
      final clusters = LocationBuildingClusterLogic.clusterLocations(const [
        'A1062',
        'A10xxx',
      ]);
      final keys = clusters.map((cluster) => cluster.buildingKey).toSet();
      // A10xxx: digits "10xxx" → first digit heuristic may yield A1 for short
      // room tails; A10 with 3-digit-ish remainder uses 2-digit building.
      // Our split: "10xxx" if non-digit after - only digits in group 2.
      // For A10xxx the regex captures letter A and digits 10 only if next is non-digit.
      // Actually A10xxx → group2 = 10 (xxx not digits). length 2 → key A10.
      expect(keys, contains('A1'));
      expect(keys, contains('A10'));
    });

    test('extracts weak gate tags when present', () {
      final clusters = LocationBuildingClusterLogic.clusterLocations(const [
        '西区A1062',
        'A主201南门',
      ]);
      final a1 = clusters.firstWhere((cluster) => cluster.buildingKey == 'A1');
      expect(a1.gateTags, contains('西区'));
      final main = clusters.firstWhere(
        (cluster) => cluster.buildingKey == 'A主',
      );
      expect(main.gateTags, contains('南门'));
    });
  });

  group('LocationBuildingClusterLogic.uncoveredClusters', () {
    test('filters clusters already covered by keywords', () {
      final uncovered = LocationBuildingClusterLogic.uncoveredClusters(
        locations: const ['A1062', 'A主201', 'A6106'],
        existingKeywords: const [
          LocationKeyword(pattern: 'A1', mode: LocationKeywordMatchMode.prefix),
        ],
      );
      final keys = uncovered.map((cluster) => cluster.buildingKey).toSet();
      expect(keys, isNot(contains('A1')));
      expect(keys, contains('A主'));
      expect(keys, contains('A6'));
    });
  });
}
